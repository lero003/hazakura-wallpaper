#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Hazakura Wallpaper"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/HazakuraWallpaper"
APP_EXECUTABLE_PATTERN=""
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
MANIFEST_PATH="$EVIDENCE_DIR/RELEASE_MANIFEST.md"
FINAL_ZIP_VERIFY_LOG="$EVIDENCE_DIR/final-zip-verify.log"
BUNDLE_OPEN_LOG="$EVIDENCE_DIR/bundle-open-verified.txt"
OPERATOR=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/record_bundle_open_verification.sh --operator "Operator Name"

Run this in a normal macOS user session after the current ZIP and release
evidence have been generated. It opens the existing dist/Hazakura Wallpaper.app without
rebuilding, then records the app bundle ID, version, build, CDHash, and ZIP
SHA-256 so publish readiness can prove the bundle-open check belongs to the
exact notarized final artifact being uploaded.
The operator value should identify the human who ran the normal-session launch
check.
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
  echo "Refusing to record bundle-open verification without --operator." >&2
  usage >&2
  exit 2
fi

if [[ "$OPERATOR" =~ [[:cntrl:]] || ! "$OPERATOR" =~ [^[:space:]] ]]; then
  echo "Refusing to record bundle-open verification with an empty or multi-line --operator value." >&2
  usage >&2
  exit 2
fi

read_unique_evidence_field() {
  local path="$1"
  local label="$2"

  awk -v label="$label" '
    index($0, label ": ") == 1 {
      count += 1
      if (count == 1) {
        value = substr($0, length(label) + 3)
      }
    }
    END {
      if (count != 1) {
        exit 1
      }
      print value
    }
  ' "$path"
}

require_exact_final_zip_field() {
  local label="$1"
  local expected="$2"
  local value

  if ! value="$(read_unique_evidence_field "$FINAL_ZIP_VERIFY_LOG" "$label")"; then
    echo "Refusing to record bundle-open verification because final ZIP verification must contain exactly one field: $label" >&2
    exit 1
  fi

  if [[ "$value" != "$expected" ]]; then
    echo "Refusing to record bundle-open verification because final ZIP verification has an unexpected field value for $label." >&2
    echo "expected: $expected" >&2
    echo "actual: $value" >&2
    exit 1
  fi
}

require_unique_final_zip_line() {
  local expected_line="$1"
  local count

  count="$(grep -Fxc "$expected_line" "$FINAL_ZIP_VERIFY_LOG" || true)"
  if [[ "$count" != "1" ]]; then
    echo "Refusing to record bundle-open verification because final ZIP verification must contain exactly one line: $expected_line" >&2
    exit 1
  fi
}

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  echo "Missing executable app binary: $APP_EXECUTABLE" >&2
  exit 1
fi

escaped_app_executable="$(awk 'BEGIN {
  value = ARGV[1]
  ARGV[1] = ""
  gsub(/[][\\.^$*+?{}()|]/, "\\\\&", value)
  print value
}' "$APP_EXECUTABLE")"
APP_EXECUTABLE_PATTERN="^${escaped_app_executable}([[:space:]]|$)"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing ZIP archive: $ZIP_PATH" >&2
  exit 1
fi

settle_seconds="${HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS:-${SAKURA_SKY_BUNDLE_OPEN_SETTLE_SECONDS:-1}}"

if [[ ! "$settle_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "Invalid HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS='$settle_seconds'; expected a positive number." >&2
  exit 2
fi

if ! awk -v value="$settle_seconds" 'BEGIN { exit !(value > 0) }'; then
  echo "Invalid HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS='$settle_seconds'; expected a positive number." >&2
  exit 2
fi

"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null

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

if ! grep -Fq -- "- Final notarized ZIP verified: yes" "$MANIFEST_PATH"; then
  echo "Refusing to record bundle-open verification before final notarized ZIP verification is complete." >&2
  exit 1
fi

if [[ ! -s "$FINAL_ZIP_VERIFY_LOG" ]]; then
  echo "Refusing to record bundle-open verification because final ZIP verification does not prove the current ZIP." >&2
  exit 1
fi

require_unique_final_zip_line "Final notarized ZIP verification passed."
require_exact_final_zip_field "Verified archive" "dist/Hazakura Wallpaper.zip"
require_exact_final_zip_field "Final ZIP SHA-256" "$zip_sha"
require_exact_final_zip_field "Bundle ID" "$bundle_identifier"
require_exact_final_zip_field "Version" "$bundle_version"
require_exact_final_zip_field "Build" "$bundle_build"
require_exact_final_zip_field "Architectures" "$mach_o_architectures"
require_exact_final_zip_field "CDHash" "$app_cdhash"

/usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
sleep 0.3

if ! /usr/bin/open -n "$APP_PATH"; then
  echo "$APP_NAME app bundle launch smoke failed." >&2
  exit 1
fi

sleep "$settle_seconds"

if ! /usr/bin/osascript -e "application \"$APP_NAME\" is running" | grep -Fxq "true"; then
  echo "$APP_NAME app bundle did not remain running after LaunchServices opened it." >&2
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  exit 1
fi

running_processes="$(/usr/bin/pgrep -f "$APP_EXECUTABLE_PATTERN" || true)"
if [[ -z "$running_processes" ]]; then
  echo "$APP_NAME executable process was not found after LaunchServices opened the app." >&2
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  exit 1
fi

/usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true

mkdir -p "$EVIDENCE_DIR"
TEMP_REPORT="$(mktemp "$EVIDENCE_DIR/bundle-open-verified.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"' EXIT
{
  echo "Bundle open verified: yes"
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
  echo "Verified command: ./scripts/record_bundle_open_verification.sh --operator <operator>"
} >"$TEMP_REPORT"

mv "$TEMP_REPORT" "$BUNDLE_OPEN_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
cat "$BUNDLE_OPEN_LOG"
