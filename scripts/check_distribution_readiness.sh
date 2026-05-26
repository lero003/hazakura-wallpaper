#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/dist/Hazakura Wallpaper.app}"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/HazakuraWallpaper"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
CANONICAL_REPORT_DIR="$ROOT_DIR/dist/release-evidence"
WRITE_EVIDENCE="${HAZAKURA_WALLPAPER_WRITE_DISTRIBUTION_EVIDENCE:-${SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE:-1}}"
REPORT_DIR="$CANONICAL_REPORT_DIR"
SIGNING_INFO="$REPORT_DIR/codesign-info.txt"
ENTITLEMENTS="$REPORT_DIR/entitlements.plist"
SPCTL_INFO="$REPORT_DIR/spctl.txt"
MACHO_INFO="$REPORT_DIR/macho-build.txt"
ICON_INFO="$REPORT_DIR/icon-info.txt"
TEMP_REPORT_DIR=""

case "$WRITE_EVIDENCE" in
  0)
    TEMP_REPORT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-distribution-evidence.XXXXXX")"
    REPORT_DIR="$TEMP_REPORT_DIR"
    SIGNING_INFO="$REPORT_DIR/codesign-info.txt"
    ENTITLEMENTS="$REPORT_DIR/entitlements.plist"
    SPCTL_INFO="$REPORT_DIR/spctl.txt"
    MACHO_INFO="$REPORT_DIR/macho-build.txt"
    ICON_INFO="$REPORT_DIR/icon-info.txt"
    trap 'rm -rf "$TEMP_REPORT_DIR"' EXIT
    ;;
  1)
    mkdir -p "$REPORT_DIR"
    ;;
  *)
    echo "HAZAKURA_WALLPAPER_WRITE_DISTRIBUTION_EVIDENCE must be 0 or 1, got '$WRITE_EVIDENCE'." >&2
    exit 2
    ;;
esac

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

plutil -lint "$INFO_PLIST" >/dev/null
test -x "$APP_EXECUTABLE"
app_executable_file_info="$(file "$APP_EXECUTABLE")"
if [[ "$app_executable_file_info" != *"Mach-O 64-bit executable"* &&
  "$app_executable_file_info" != *"Mach-O universal binary"* ]]; then
  echo "App executable must be a Mach-O executable, got: $app_executable_file_info" >&2
  exit 1
fi

if ! command -v vtool >/dev/null 2>&1; then
  echo "Missing vtool; cannot verify Mach-O build metadata." >&2
  exit 1
fi

if ! command -v lipo >/dev/null 2>&1; then
  echo "Missing lipo; cannot verify Mach-O architectures." >&2
  exit 1
fi

bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
bundle_display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$INFO_PLIST")"
bundle_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$INFO_PLIST")"
bundle_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
development_region="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDevelopmentRegion' "$INFO_PLIST")"
info_dictionary_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleInfoDictionaryVersion' "$INFO_PLIST")"
minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
app_category="$(/usr/libexec/PlistBuddy -c 'Print :LSApplicationCategoryType' "$INFO_PLIST")"
package_type="$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$INFO_PLIST")"
supported_platform="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleSupportedPlatforms:0' "$INFO_PLIST")"
principal_class="$(/usr/libexec/PlistBuddy -c 'Print :NSPrincipalClass' "$INFO_PLIST")"
ui_element="$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$INFO_PLIST")"
high_resolution_capable="$(/usr/libexec/PlistBuddy -c 'Print :NSHighResolutionCapable' "$INFO_PLIST")"
copyright="$(/usr/libexec/PlistBuddy -c 'Print :NSHumanReadableCopyright' "$INFO_PLIST")"
icon_file="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$INFO_PLIST")"
icon_base="${icon_file%.icns}"
icon_icns="$APP_PATH/Contents/Resources/$icon_base.icns"
status_icon_png="$APP_PATH/Contents/Resources/icon.png"

require_equal() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "$label must be '$expected', got '$actual'." >&2
    exit 1
  fi
}

require_non_empty() {
  local label="$1"
  local actual="$2"

  if [[ -z "$actual" ]]; then
    echo "$label must not be empty." >&2
    exit 1
  fi
}

require_equal "CFBundleIdentifier" "$bundle_identifier" "com.hazakuralab.hazakurawallpaper"
require_equal "CFBundleDisplayName" "$bundle_display_name" "Hazakura Wallpaper"
require_equal "CFBundleName" "$bundle_name" "Hazakura Wallpaper"
require_equal "CFBundleExecutable" "$bundle_executable" "HazakuraWallpaper"
require_equal "CFBundleDevelopmentRegion" "$development_region" "ja"
require_equal "CFBundleInfoDictionaryVersion" "$info_dictionary_version" "6.0"
require_equal "CFBundleIconFile" "$icon_file" "icon"
require_equal "LSApplicationCategoryType" "$app_category" "public.app-category.utilities"
require_equal "CFBundlePackageType" "$package_type" "APPL"
require_equal "CFBundleSupportedPlatforms[0]" "$supported_platform" "MacOSX"
require_equal "NSPrincipalClass" "$principal_class" "NSApplication"
require_equal "LSUIElement" "$ui_element" "true"
require_equal "NSHighResolutionCapable" "$high_resolution_capable" "true"
if [[ "$copyright" != Copyright*"2026 Hazakura Lab." ]]; then
  echo "NSHumanReadableCopyright must identify Hazakura Lab and 2026, got '$copyright'." >&2
  exit 1
fi
require_non_empty "CFBundleShortVersionString" "$bundle_version"
require_non_empty "CFBundleVersion" "$build_number"
require_non_empty "LSMinimumSystemVersion" "$minimum_system"
require_non_empty "CFBundleIconFile" "$icon_base"
if [[ ! -s "$icon_icns" ]]; then
  echo "Missing icon resource: Contents/Resources/$icon_base.icns" >&2
  exit 1
fi
if ! file "$icon_icns" | grep -q "Mac OS X icon"; then
  echo "Icon resource is not a valid macOS icon file: Contents/Resources/$icon_base.icns" >&2
  exit 1
fi
if [[ ! -s "$status_icon_png" ]]; then
  echo "Missing status icon PNG resource: Contents/Resources/icon.png" >&2
  exit 1
fi
if ! file "$status_icon_png" | grep -q "PNG image data"; then
  echo "Status icon resource is not a PNG: Contents/Resources/icon.png" >&2
  exit 1
fi
if ! command -v sips >/dev/null 2>&1; then
  echo "Missing sips; cannot verify icon dimensions." >&2
  exit 1
fi
icon_png_width="$(sips -g pixelWidth "$status_icon_png" 2>/dev/null | awk '/pixelWidth:/ { print $2; exit }')"
icon_png_height="$(sips -g pixelHeight "$status_icon_png" 2>/dev/null | awk '/pixelHeight:/ { print $2; exit }')"
if [[ "$icon_png_width" != "1024" || "$icon_png_height" != "1024" ]]; then
  echo "Status icon PNG must be 1024x1024, got ${icon_png_width:-unknown}x${icon_png_height:-unknown}." >&2
  exit 1
fi

mach_o_architectures="$(lipo -archs "$APP_EXECUTABLE")"
if [[ " $mach_o_architectures " != *" arm64 "* ||
  " $mach_o_architectures " != *" x86_64 "* ]]; then
  echo "Release app must be universal for public distribution; expected arm64 and x86_64, got '$mach_o_architectures'." >&2
  exit 1
fi

{
  echo "Architectures: $mach_o_architectures"
  vtool -show-build "$APP_EXECUTABLE"
} >"$MACHO_INFO"
mach_o_platform="$(awk '$1 == "platform" { print $2; exit }' "$MACHO_INFO")"
mach_o_minimum_system="$(awk '$1 == "minos" { print $2; exit }' "$MACHO_INFO")"
mach_o_sdk="$(awk '$1 == "sdk" { print $2; exit }' "$MACHO_INFO")"

if [[ "$mach_o_platform" != "MACOS" ]]; then
  echo "Expected Mach-O platform MACOS, got '$mach_o_platform'." >&2
  exit 1
fi

if [[ "$mach_o_minimum_system" != "$minimum_system" ]]; then
  echo "Info.plist LSMinimumSystemVersion ($minimum_system) does not match Mach-O minos ($mach_o_minimum_system)." >&2
  exit 1
fi

[[ -n "$mach_o_sdk" ]]

codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null
codesign -dvvv "$APP_PATH" >"$SIGNING_INFO" 2>&1
grep -q "flags=.*runtime" "$SIGNING_INFO"
app_cdhash="$(awk -F= '/^CDHash=/{ print $2; exit }' "$SIGNING_INFO")"
require_non_empty "CDHash" "$app_cdhash"

{
  echo "Icon checks passed."
  echo "Version: $bundle_version"
  echo "Build: $build_number"
  echo "CDHash: $app_cdhash"
  echo "App icon: Contents/Resources/$icon_base.icns"
  file "$icon_icns"
  echo "Status icon: Contents/Resources/icon.png"
  file "$status_icon_png"
  echo "Status icon dimensions: ${icon_png_width}x${icon_png_height}"
} >"$ICON_INFO"

codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS" 2>/dev/null || true
if grep -q "com.apple.security.get-task-allow" "$ENTITLEMENTS"; then
  echo "Distribution app must not include get-task-allow entitlement." >&2
  exit 1
fi
if [[ -s "$ENTITLEMENTS" ]]; then
  echo "Distribution app must not include entitlements; unexpected entitlements were found in $ENTITLEMENTS." >&2
  exit 1
fi

spctl -a -vv --type execute "$APP_PATH" >"$SPCTL_INFO" 2>&1 || true

signature_state="ad-hoc"
if grep -q "Authority=Developer ID Application" "$SIGNING_INFO"; then
  signature_state="developer-id"
fi

echo "Distribution readiness checks passed."
echo "App: $APP_PATH"
echo "Bundle ID: $bundle_identifier"
echo "Display Name: $bundle_display_name"
echo "Version: $bundle_version"
echo "Build: $build_number"
echo "Development Region: $development_region"
echo "Info Dictionary Version: $info_dictionary_version"
echo "Minimum macOS: $minimum_system"
echo "Category: $app_category"
echo "Mach-O architectures: $mach_o_architectures"
echo "Mach-O minimum macOS: $mach_o_minimum_system"
echo "Mach-O SDK: $mach_o_sdk"
echo "Menu bar only: yes"
echo "Icon: $icon_base.icns"
echo "Status Icon PNG: ${icon_png_width}x${icon_png_height}"
echo "Entitlements: none"
echo "Signing: $signature_state"
if [[ "$WRITE_EVIDENCE" == "1" ]]; then
  echo "Evidence: dist/release-evidence"
else
  echo "Evidence: no-write"
fi

if [[ "$signature_state" != "developer-id" ]]; then
  echo "Notarization-ready signing: no"
  echo "Reason: app is not signed with a Developer ID Application identity."
  if [[ "${HAZAKURA_WALLPAPER_REQUIRE_DEVELOPER_ID:-${SAKURA_SKY_REQUIRE_DEVELOPER_ID:-0}}" == "1" ]]; then
    exit 1
  fi
else
  if ! grep -q "^Timestamp=" "$SIGNING_INFO"; then
    echo "Developer ID app must include a secure timestamp." >&2
    exit 1
  fi
  echo "Notarization-ready signing: yes"
fi
