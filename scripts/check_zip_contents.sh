#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP_PATH="${1:-$ROOT_DIR/dist/Hazakura Wallpaper.zip}"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
REPORT_DIR="$ROOT_DIR/dist/release-evidence"
REPORT_PATH="$REPORT_DIR/zip-contents.txt"

cd "$ROOT_DIR"

if [[ ! -s "$ZIP_PATH" ]]; then
  echo "Missing ZIP archive: $ZIP_PATH" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

if ! command -v zipinfo >/dev/null 2>&1; then
  echo "Missing zipinfo; cannot verify ZIP contents." >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"
TEMP_REPORT="$(mktemp "$REPORT_DIR/zip-contents.XXXXXX")"
ZIP_LIST="$(mktemp "$REPORT_DIR/zip-contents-list.XXXXXX")"
VERIFY_DIR=""

cleanup() {
  rm -f "$TEMP_REPORT" "$ZIP_LIST"
  if [[ -n "$VERIFY_DIR" ]]; then
    rm -rf "$VERIFY_DIR"
  fi
}
trap cleanup EXIT

zipinfo -1 "$ZIP_PATH" >"$ZIP_LIST"

for required_entry in \
  "Hazakura Wallpaper.app/" \
  "Hazakura Wallpaper.app/Contents/Info.plist" \
  "Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" \
  "Hazakura Wallpaper.app/Contents/Resources/icon.icns" \
  "Hazakura Wallpaper.app/Contents/Resources/icon.png"; do
  if ! grep -Fxq "$required_entry" "$ZIP_LIST"; then
    echo "ZIP is missing required entry: $required_entry" >&2
    exit 1
  fi
done

if grep -Eq '(^|/)__MACOSX(/|$)|(^|/)\._|(^|/)\.DS_Store$' "$ZIP_LIST"; then
  echo "ZIP contains macOS metadata sidecar entries." >&2
  grep -E '(^|/)__MACOSX(/|$)|(^|/)\._|(^|/)\.DS_Store$' "$ZIP_LIST" >&2
  exit 1
fi

if grep -Ev '^Hazakura Wallpaper\.app(/|$)' "$ZIP_LIST" >/dev/null; then
  echo "ZIP contains entries outside Hazakura Wallpaper.app." >&2
  grep -Ev '^Hazakura Wallpaper\.app(/|$)' "$ZIP_LIST" >&2
  exit 1
fi

if grep -Eq '(^|/)(Package\.swift|Package\.resolved|Sources|Tests|scripts|script|docs|README\.md|PROJECT_NOTES\.md|HANDOFF\.md|package(-lock)?\.json|node_modules|src-tauri|docs/legacy-tauri|SakuraSky\.xcodeproj)(/|$)' "$ZIP_LIST"; then
  echo "ZIP contains source, script, docs, dependency, Xcode project, or legacy Tauri entries." >&2
  grep -E '(^|/)(Package\.swift|Package\.resolved|Sources|Tests|scripts|script|docs|README\.md|PROJECT_NOTES\.md|HANDOFF\.md|package(-lock)?\.json|node_modules|src-tauri|docs/legacy-tauri|SakuraSky\.xcodeproj)(/|$)' "$ZIP_LIST" >&2
  exit 1
fi

development_metadata_pattern='(^|/)(\.git|\.github|\.codex|\.build|\.xcode-derived|\.swiftpm|\.vscode|\.idea|habitat-report|DerivedData|dist|xcuserdata)(/|$)|(^|/)\.env[^/]*(/|$)|(^|/)\.npmrc$|(^|/)[^/]+\.xcuserstate$|(^|/)[^/]+\.xcworkspace(/|$)|(^|/)[^/]+\.dSYM(/|$)|(^|/)(npm-debug|yarn-error|pnpm-debug)\.log$'
if grep -Eq "$development_metadata_pattern" "$ZIP_LIST"; then
  echo "ZIP contains development metadata, editor, local environment, debug-symbol, or build-output entries." >&2
  grep -E "$development_metadata_pattern" "$ZIP_LIST" >&2
  exit 1
fi

allowed_app_entry_pattern='^Hazakura Wallpaper\.app/?$|^Hazakura Wallpaper\.app/Contents/?$|^Hazakura Wallpaper\.app/Contents/Info\.plist$|^Hazakura Wallpaper\.app/Contents/PkgInfo$|^Hazakura Wallpaper\.app/Contents/MacOS/?$|^Hazakura Wallpaper\.app/Contents/MacOS/HazakuraWallpaper$|^Hazakura Wallpaper\.app/Contents/Resources/?$|^Hazakura Wallpaper\.app/Contents/Resources/icon\.(icns|png)$|^Hazakura Wallpaper\.app/Contents/_CodeSignature/?$|^Hazakura Wallpaper\.app/Contents/_CodeSignature/CodeResources$'
if grep -Ev "$allowed_app_entry_pattern" "$ZIP_LIST" >/dev/null; then
  echo "ZIP contains unexpected app bundle entries." >&2
  grep -Ev "$allowed_app_entry_pattern" "$ZIP_LIST" >&2
  exit 1
fi

entry_count="$(wc -l <"$ZIP_LIST" | tr -d ' ')"
zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"

if [[ -z "$app_cdhash" ]]; then
  echo "Could not read app CDHash: $APP_PATH" >&2
  exit 1
fi

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-zip-contents.XXXXXX")"
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
EXTRACTED_APP="$VERIFY_DIR/Hazakura Wallpaper.app"
test -x "$EXTRACTED_APP/Contents/MacOS/HazakuraWallpaper"
plutil -lint "$EXTRACTED_APP/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP" >/dev/null

extracted_app_cdhash="$(codesign -dvvv "$EXTRACTED_APP" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"
if [[ -z "$extracted_app_cdhash" ]]; then
  echo "Could not read extracted app CDHash: $EXTRACTED_APP" >&2
  exit 1
fi

if [[ "$extracted_app_cdhash" != "$app_cdhash" ]]; then
  echo "ZIP app CDHash does not match the current dist app." >&2
  echo "current: $app_cdhash" >&2
  echo "zip: $extracted_app_cdhash" >&2
  exit 1
fi

if ! diff -qr "$APP_PATH" "$EXTRACTED_APP" >/dev/null; then
  echo "ZIP app contents do not match the current dist app." >&2
  diff -qr "$APP_PATH" "$EXTRACTED_APP" >&2 || true
  exit 1
fi

{
  echo "ZIP content checks passed."
  echo "ZIP SHA-256: $zip_sha"
  echo "Current app CDHash: $app_cdhash"
  echo "Extracted app CDHash: $extracted_app_cdhash"
  echo "Extracted app matches current dist app."
  echo "Entry count: $entry_count"
  echo "No __MACOSX, AppleDouble, or .DS_Store entries found."
  echo "No entries outside Hazakura Wallpaper.app found."
  echo "No source, script, docs, dependency, Xcode project, or legacy Tauri entries found."
  echo "No development metadata, editor, local environment, debug-symbol, or build-output entries found."
  echo "No unexpected app bundle entries found."
  echo "Required entries:"
  echo "- Hazakura Wallpaper.app/"
  echo "- Hazakura Wallpaper.app/Contents/Info.plist"
  echo "- Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper"
  echo "- Hazakura Wallpaper.app/Contents/Resources/icon.icns"
  echo "- Hazakura Wallpaper.app/Contents/Resources/icon.png"
} >"$TEMP_REPORT"

mv "$TEMP_REPORT" "$REPORT_PATH"
cat "$REPORT_PATH"
