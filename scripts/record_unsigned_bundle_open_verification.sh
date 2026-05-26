#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Hazakura Wallpaper"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/HazakuraWallpaper"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
BUNDLE_OPEN_LOG="$EVIDENCE_DIR/unsigned-bundle-open-verified.txt"
OPERATOR=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/record_unsigned_bundle_open_verification.sh --operator "Operator Name"

Run this in a normal macOS user session after the unsigned GitHub/DMG release
candidate has been generated. It opens the existing dist/Hazakura Wallpaper.app
without rebuilding, then records app identity, CDHash, architectures, and ZIP
SHA-256 so the check stays tied to the exact artifact being shared.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --operator)
      shift
      if [[ $# -eq 0 || -z "${1:-}" ]]; then
        echo "--operator requires a non-empty value." >&2
        usage >&2
        exit 2
      fi
      OPERATOR="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -z "$OPERATOR" ]]; then
  echo "Refusing to record unsigned bundle-open verification without --operator." >&2
  usage >&2
  exit 2
fi

if [[ "$OPERATOR" =~ [[:cntrl:]] || ! "$OPERATOR" =~ [^[:space:]] ]]; then
  echo "Refusing to record unsigned bundle-open verification with an empty or multi-line --operator value." >&2
  usage >&2
  exit 2
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  echo "Missing executable app binary: $APP_EXECUTABLE" >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing ZIP archive: $ZIP_PATH" >&2
  exit 1
fi

settle_seconds="${HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS:-${SAKURA_SKY_BUNDLE_OPEN_SETTLE_SECONDS:-1}}"
if [[ ! "$settle_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]] ||
  ! awk -v value="$settle_seconds" 'BEGIN { exit !(value > 0) }'; then
  echo "Invalid HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS='$settle_seconds'; expected a positive number." >&2
  exit 2
fi

run_release_evidence_check() {
  if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
    echo "Release evidence check failed; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
  fi
}

run_release_evidence_check

bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
bundle_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"
mach_o_architectures="$(lipo -archs "$APP_EXECUTABLE")"
zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ -z "$app_cdhash" || -z "$mach_o_architectures" ]]; then
  echo "Could not read app CDHash or Mach-O architectures: $APP_PATH" >&2
  exit 1
fi

escaped_app_executable="$(awk 'BEGIN {
  value = ARGV[1]
  ARGV[1] = ""
  gsub(/[][\\.^$*+?{}()|]/, "\\\\&", value)
  print value
}' "$APP_EXECUTABLE")"
app_executable_pattern="^${escaped_app_executable}([[:space:]]|$)"

/usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
sleep 0.3

if ! /usr/bin/open -n "$APP_PATH"; then
  echo "$APP_NAME app bundle launch failed." >&2
  exit 1
fi

sleep "$settle_seconds"

if ! /usr/bin/osascript -e "application \"$APP_NAME\" is running" | grep -Fxq "true"; then
  echo "$APP_NAME app bundle did not remain running after LaunchServices opened it." >&2
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  exit 1
fi

running_processes="$(/usr/bin/pgrep -f "$app_executable_pattern" || true)"
if [[ -z "$running_processes" ]]; then
  echo "$APP_NAME executable process was not found after LaunchServices opened the app." >&2
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  exit 1
fi

/usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true

mkdir -p "$EVIDENCE_DIR"
TEMP_REPORT="$(mktemp "$EVIDENCE_DIR/unsigned-bundle-open-verified.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"' EXIT
{
  echo "Unsigned bundle open verified: yes"
  echo "Bundle ID: $bundle_identifier"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "Architectures: $mach_o_architectures"
  echo "CDHash: $app_cdhash"
  echo "ZIP SHA-256: $zip_sha"
  echo "Verified at: $created_at"
  echo "Operator: $OPERATOR"
  echo "Verified app: dist/Hazakura Wallpaper.app"
  echo "Verified executable: dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper"
  echo "Verified process match: anchored executable path"
  echo "Verified command: ./scripts/record_unsigned_bundle_open_verification.sh --operator <operator>"
} >"$TEMP_REPORT"

mv "$TEMP_REPORT" "$BUNDLE_OPEN_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
run_release_evidence_check
cat "$BUNDLE_OPEN_LOG"
