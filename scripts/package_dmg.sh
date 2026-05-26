#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"
STAGING_DIR="$ROOT_DIR/dist/dmg-staging"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
DMG_INFO="$EVIDENCE_DIR/dmg-info.txt"
MOUNT_DIR=""
TEMP_REPORT=""
DMG_VERIFIED=0

cleanup() {
  if [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
    rm -rf "$MOUNT_DIR"
  fi
  rm -rf "$STAGING_DIR"
  if [[ "$DMG_VERIFIED" != "1" ]]; then
    rm -f "$DMG_PATH" "$DMG_INFO"
    if [[ -d "$APP_PATH" && -f "$ROOT_DIR/dist/Hazakura Wallpaper.zip" ]]; then
      "$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null 2>&1 || true
      "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1 || true
      "$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n "$TEMP_REPORT" ]]; then
    rm -f "$TEMP_REPORT"
  fi
}

run_distribution_readiness_check() {
  local app_path="$1"
  if ! HAZAKURA_WALLPAPER_WRITE_DISTRIBUTION_EVIDENCE=0 SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE=0 "$ROOT_DIR/scripts/check_distribution_readiness.sh" "$app_path" >/dev/null 2>&1; then
    echo "Distribution readiness failed for app: $app_path" >&2
    HAZAKURA_WALLPAPER_WRITE_DISTRIBUTION_EVIDENCE=0 SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE=0 "$ROOT_DIR/scripts/check_distribution_readiness.sh" "$app_path" >/dev/null
  fi
}

run_release_evidence_check() {
  if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
    echo "Release evidence check failed after DMG packaging; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
  fi
}

run_github_release_notes_check() {
  if ! "$ROOT_DIR/scripts/check_github_release_notes.sh" >/dev/null 2>&1; then
    echo "GitHub release draft check failed after DMG packaging; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_github_release_notes.sh" >/dev/null
  fi
}

trap cleanup EXIT

cd "$ROOT_DIR"

mkdir -p "$EVIDENCE_DIR"

if [[ "${HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP:-${SAKURA_SKY_PACKAGE_EXISTING_APP:-0}}" == "1" ]]; then
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Cannot package existing app because it is missing: $APP_PATH" >&2
    exit 1
  fi
else
  "$ROOT_DIR/scripts/build_app.sh" >/dev/null
  HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 SAKURA_SKY_PACKAGE_EXISTING_APP=1 "$ROOT_DIR/scripts/package_zip.sh" >/dev/null
fi

run_distribution_readiness_check "$APP_PATH"

bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
bundle_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"

if [[ -z "$app_cdhash" ]]; then
  echo "Could not read app CDHash: $APP_PATH" >&2
  exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_PATH" "$DMG_INFO"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/Hazakura Wallpaper.app"

if ! hdiutil create \
  -volname "Hazakura Wallpaper" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null; then
  echo "DMG creation failed. In restricted shells, use ./scripts/package_zip.sh for a local distributable archive." >&2
  exit 1
fi

if ! hdiutil verify "$DMG_PATH" >/dev/null; then
  rm -f "$DMG_PATH"
  echo "DMG verification failed." >&2
  exit 1
fi

MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-dmg-mount.XXXXXX")"
if ! hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$DMG_PATH" >/dev/null; then
  echo "DMG mount verification failed." >&2
  exit 1
fi

MOUNTED_APP_PATH="$MOUNT_DIR/Hazakura Wallpaper.app"
if [[ ! -d "$MOUNTED_APP_PATH" ]]; then
  echo "DMG mount verification failed because the app bundle is missing from the mounted image." >&2
  exit 1
fi

if ! run_distribution_readiness_check "$MOUNTED_APP_PATH"; then
  echo "DMG mount verification failed because the mounted app did not pass distribution readiness." >&2
  exit 1
fi

mounted_bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$MOUNTED_APP_PATH/Contents/Info.plist")"
mounted_bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNTED_APP_PATH/Contents/Info.plist")"
mounted_bundle_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$MOUNTED_APP_PATH/Contents/Info.plist")"
mounted_app_cdhash="$(codesign -dvvv "$MOUNTED_APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"

if [[ "$mounted_bundle_identifier" != "$bundle_identifier" ||
  "$mounted_bundle_version" != "$bundle_version" ||
  "$mounted_bundle_build" != "$bundle_build" ||
  "$mounted_app_cdhash" != "$app_cdhash" ]]; then
  echo "DMG mount verification failed because the mounted app identity does not match the source app." >&2
  exit 1
fi

if ! hdiutil detach "$MOUNT_DIR" >/dev/null; then
  echo "DMG mount verification failed because the mounted image could not be detached cleanly." >&2
  exit 1
fi
rm -rf "$MOUNT_DIR"
MOUNT_DIR=""

dmg_sha="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"
TEMP_REPORT="$(mktemp "$EVIDENCE_DIR/dmg-info.XXXXXX")"
{
  echo "DMG checks passed."
  echo "DMG: dist/Hazakura Wallpaper.dmg"
  echo "DMG SHA-256: $dmg_sha"
  echo "Volume name: Hazakura Wallpaper"
  echo "Format: UDZO"
  echo "Source app: dist/Hazakura Wallpaper.app"
  echo "Bundle ID: $bundle_identifier"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "CDHash: $app_cdhash"
  echo "hdiutil verify: passed"
  echo "hdiutil attach: passed"
  echo "Mounted app: Hazakura Wallpaper.app"
  echo "Mounted bundle ID: $mounted_bundle_identifier"
  echo "Mounted version: $mounted_bundle_version"
  echo "Mounted build: $mounted_bundle_build"
  echo "Mounted CDHash: $mounted_app_cdhash"
} >"$TEMP_REPORT"
mv "$TEMP_REPORT" "$DMG_INFO"
TEMP_REPORT=""

"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
if ! run_release_evidence_check; then
  rm -f "$DMG_PATH" "$DMG_INFO"
  "$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
  "$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
  echo "DMG release evidence failed; removed DMG and DMG evidence for the inconsistent artifact." >&2
  exit 1
fi
if ! run_github_release_notes_check; then
  rm -f "$DMG_PATH" "$DMG_INFO"
  "$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
  "$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
  echo "DMG GitHub release draft check failed; removed DMG and DMG evidence for the inconsistent artifact." >&2
  exit 1
fi

DMG_VERIFIED=1
echo "$DMG_PATH"
