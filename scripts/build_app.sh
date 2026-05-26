#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Hazakura Wallpaper"
SWIFT_EXECUTABLE_NAME="HazakuraWallpaper"
BUNDLE_EXECUTABLE_NAME="$SWIFT_EXECUTABLE_NAME"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
XCODE_ARCHS="${XCODE_ARCHS:-arm64 x86_64}"
case "$CONFIGURATION" in
  release|Release)
    XCODE_CONFIGURATION="Release"
    SWIFT_CONFIGURATION="release"
    ;;
  debug|Debug)
    XCODE_CONFIGURATION="Debug"
    SWIFT_CONFIGURATION="debug"
    ;;
  *)
    XCODE_CONFIGURATION="$CONFIGURATION"
    SWIFT_CONFIGURATION="$CONFIGURATION"
    ;;
esac
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DERIVED_DATA_DIR="$ROOT_DIR/.xcode-derived"
XCODE_APP_DIR="$DERIVED_DATA_DIR/Build/Products/$XCODE_CONFIGURATION/$APP_NAME.app"
LOCK_PARENT="$ROOT_DIR/.build"
LOCK_DIR="$LOCK_PARENT/build_app.lock"

cd "$ROOT_DIR"

mkdir -p "$LOCK_PARENT"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another build_app.sh process is already preparing the app bundle." >&2
  echo "Wait for it to finish before running this script again." >&2
  exit 1
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

if [[ -d "SakuraSky.xcodeproj" && "${HAZAKURA_WALLPAPER_USE_SWIFTPM_BUNDLE:-${SAKURA_SKY_USE_SWIFTPM_BUNDLE:-0}}" != "1" ]]; then
  xcodebuild \
    -quiet \
    -project SakuraSky.xcodeproj \
    -scheme "$APP_NAME" \
    -configuration "$XCODE_CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    build \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
    ARCHS="$XCODE_ARCHS" \
    ONLY_ACTIVE_ARCH=NO >&2

  rm -rf "$APP_DIR"
  mkdir -p "$ROOT_DIR/dist"
  ditto "$XCODE_APP_DIR" "$APP_DIR"

  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$APP_DIR" 2>/dev/null || true
  fi

  test -x "$APP_DIR/Contents/MacOS/$BUNDLE_EXECUTABLE_NAME"
  plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null

  if command -v codesign >/dev/null 2>&1; then
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
      codesign --force --sign - --options runtime "$APP_DIR" >/dev/null 2>&1
    else
      codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP_DIR" >/dev/null 2>&1
    fi
  fi

  echo "$APP_DIR"
  exit 0
fi

swift build --disable-sandbox -c "$SWIFT_CONFIGURATION" --product "$SWIFT_EXECUTABLE_NAME" >&2

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/$SWIFT_CONFIGURATION/$SWIFT_EXECUTABLE_NAME" "$MACOS_DIR/$BUNDLE_EXECUTABLE_NAME"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if [[ ! -s "Resources/icon.icns" ]]; then
  echo "Missing Swift-owned app icon asset: Resources/icon.icns" >&2
  exit 1
fi
cp "Resources/icon.icns" "$RESOURCES_DIR/icon.icns"

if [[ ! -s "Resources/icon.png" ]]; then
  echo "Missing Swift-owned status icon asset: Resources/icon.png" >&2
  exit 1
fi
cp "Resources/icon.png" "$RESOURCES_DIR/icon.png"

chmod +x "$MACOS_DIR/$BUNDLE_EXECUTABLE_NAME"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_DIR" 2>/dev/null || true
fi

if command -v codesign >/dev/null 2>&1; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - --options runtime "$APP_DIR" >/dev/null 2>&1
  else
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP_DIR" >/dev/null 2>&1
  fi
fi

echo "$APP_DIR"
