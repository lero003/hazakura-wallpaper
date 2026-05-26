#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/HazakuraWallpaper"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
MEMORY_LOG="$EVIDENCE_DIR/unsigned-memory-check.txt"
OPERATOR=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/record_unsigned_memory_check.sh --operator "Operator Name"

Run this in a normal macOS user session after preparing the unsigned release
candidate. It runs `leaks --atExit` against the distributable app bundle's
executable path in smoke mode and records the result against the current bundle
ID, version, build, architectures, CDHash, and ZIP SHA-256.
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
  echo "Refusing to record unsigned memory check without --operator." >&2
  usage >&2
  exit 2
fi

if [[ "$OPERATOR" =~ [[:cntrl:]] || ! "$OPERATOR" =~ [^[:space:]] ]]; then
  echo "Refusing to record unsigned memory check with an empty or multi-line --operator value." >&2
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

if ! command -v leaks >/dev/null 2>&1; then
  echo "Missing leaks tool; install Xcode command line tools and run this in a normal macOS user session." >&2
  exit 1
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

smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-memory-check.XXXXXX")"
cleanup() {
  rm -rf "$smoke_dir"
}
trap cleanup EXIT

leaks_stdout="$smoke_dir/leaks.stdout"
leaks_stderr="$smoke_dir/leaks.stderr"
if ! HAZAKURA_WALLPAPER_SMOKE_EXIT_AFTER=1 SAKURA_SKY_SMOKE_EXIT_AFTER=1 MallocStackLogging=1 leaks --atExit -- "$APP_EXECUTABLE" >"$leaks_stdout" 2>"$leaks_stderr"; then
  echo "leaks --atExit failed or reported leaks; canonical memory evidence was not written." >&2
  echo "stdout: $leaks_stdout" >&2
  echo "stderr: $leaks_stderr" >&2
  sed -n '1,120p' "$leaks_stdout" >&2
  sed -n '1,120p' "$leaks_stderr" >&2
  exit 1
fi

if grep -Eh '[[:space:]][1-9][0-9]* leaks? for [1-9][0-9]* total leaked bytes\.?([[:space:]]|$)' "$leaks_stdout" "$leaks_stderr" >/dev/null; then
  echo "leaks --atExit reported leaked bytes; canonical memory evidence was not written." >&2
  echo "stdout: $leaks_stdout" >&2
  echo "stderr: $leaks_stderr" >&2
  sed -n '1,120p' "$leaks_stdout" >&2
  sed -n '1,120p' "$leaks_stderr" >&2
  exit 1
fi

mkdir -p "$EVIDENCE_DIR"
TEMP_REPORT="$(mktemp "$EVIDENCE_DIR/unsigned-memory-check.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"; cleanup' EXIT
{
  echo "Unsigned memory check passed: yes"
  echo "Bundle ID: $bundle_identifier"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "Architectures: $mach_o_architectures"
  echo "CDHash: $app_cdhash"
  echo "ZIP SHA-256: $zip_sha"
  echo "Checked at: $created_at"
  echo "Operator: $OPERATOR"
  echo "Checked executable: dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper"
  echo "Checked command: ./scripts/record_unsigned_memory_check.sh --operator <operator>"
  echo "Tool: leaks --atExit"
  echo "MallocStackLogging: enabled"
  echo "Smoke exit after seconds: 1"
  echo "Leaks exit code: 0"
  echo "Leaks result: no leaks reported by leaks --atExit"
} >"$TEMP_REPORT"

mv "$TEMP_REPORT" "$MEMORY_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
run_release_evidence_check
cat "$MEMORY_LOG"
