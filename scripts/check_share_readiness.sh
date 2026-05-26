#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"

cd "$ROOT_DIR"

if ! "$ROOT_DIR/scripts/check_publish_readiness.sh" >/dev/null 2>&1; then
  echo "Share readiness failed: publish readiness did not pass." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
  echo "Share readiness failed: release evidence did not pass." >&2
  exit 1
fi

"$ROOT_DIR/scripts/check_share_evidence_ready.sh"

zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
dmg_sha="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"

echo "Share readiness checks passed."
echo "App: dist/Hazakura Wallpaper.app"
echo "ZIP SHA-256: $zip_sha"
echo "DMG SHA-256: $dmg_sha"
echo "Version: $bundle_version"
echo "Gatekeeper: unsigned distribution may require right-click Open or System Settings > Privacy & Security > Open Anyway."
