#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
SHA_PATH="$ROOT_DIR/dist/SHA256SUMS"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
MANIFEST_PATH="$EVIDENCE_DIR/RELEASE_MANIFEST.md"
ZIP_CONTENTS="$EVIDENCE_DIR/zip-contents.txt"
NOTES_PATH="$EVIDENCE_DIR/GITHUB_RELEASE_DRAFT.md"
RELEASE_EVIDENCE_CHECK="$EVIDENCE_DIR/release-evidence-check.txt"
LEGACY_APP_PATH="$ROOT_DIR/dist/Sakura Sky.app"
LEGACY_ZIP_PATH="$ROOT_DIR/dist/Sakura Sky.zip"
TEMP_ZIP=""
PACKAGE_SUCCEEDED=0

cleanup() {
  if [[ -n "$TEMP_ZIP" ]]; then
    rm -f "$TEMP_ZIP"
  fi

  if [[ "$PACKAGE_SUCCEEDED" != "1" ]]; then
    rm -f "$ZIP_PATH" "$SHA_PATH" "$MANIFEST_PATH" "$ZIP_CONTENTS" "$NOTES_PATH" "$RELEASE_EVIDENCE_CHECK"
  fi
}

run_zip_contents_check() {
  local zip_path="$1"
  if ! "$ROOT_DIR/scripts/check_zip_contents.sh" "$zip_path" >/dev/null 2>&1; then
    echo "ZIP content validation failed; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_zip_contents.sh" "$zip_path" >/dev/null
  fi
}

run_release_evidence_check() {
  if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
    echo "Release evidence check failed after ZIP packaging; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

mkdir -p "$ROOT_DIR/dist"
# Remove pre-rename local artifacts so manual sharing cannot pick up the old app name.
rm -rf "$LEGACY_APP_PATH" "$LEGACY_ZIP_PATH"

mkdir -p "$EVIDENCE_DIR"
rm -f \
  "$ROOT_DIR/dist/codesign-entitlements.plist" \
  "$ROOT_DIR/dist/codesign-info.txt" \
  "$ROOT_DIR/dist/Hazakura Wallpaper.dmg" \
  "$EVIDENCE_DIR/dmg-info.txt" \
  "$EVIDENCE_DIR/final-zip-verify.log" \
  "$EVIDENCE_DIR/final-zip-verify.attempt.log" \
  "$EVIDENCE_DIR/final-zip-verify.failed.log" \
  "$EVIDENCE_DIR/notarytool-submit.log" \
  "$EVIDENCE_DIR/notarytool-submit.attempt.log" \
  "$EVIDENCE_DIR/notarytool-submit.failed.log" \
  "$EVIDENCE_DIR/spctl-after-notarization.txt" \
  "$EVIDENCE_DIR/spctl-after-notarization.attempt.txt" \
  "$EVIDENCE_DIR/spctl-after-notarization.failed.txt" \
  "$EVIDENCE_DIR/stapler.log" \
  "$EVIDENCE_DIR/stapler.attempt.log" \
  "$EVIDENCE_DIR/stapler.failed.log" \
  "$EVIDENCE_DIR/release-evidence-guard-tests.txt" \
  "$EVIDENCE_DIR/GITHUB_RELEASE_DRAFT.md" \
  "$EVIDENCE_DIR/release-evidence-check.txt" \
  "$EVIDENCE_DIR/bundle-open-verified.txt" \
  "$EVIDENCE_DIR/visual-qa-accepted.txt" \
  "$EVIDENCE_DIR/unsigned-bundle-open-verified.txt" \
  "$EVIDENCE_DIR/unsigned-visual-qa-accepted.txt" \
  "$EVIDENCE_DIR/unsigned-memory-check.txt"

if [[ "${HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP:-${SAKURA_SKY_PACKAGE_EXISTING_APP:-0}}" == "1" ]]; then
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Cannot package existing app because it is missing: $APP_PATH" >&2
    exit 1
  fi
else
  "$ROOT_DIR/scripts/build_app.sh" >/dev/null
fi

rm -f "$ZIP_PATH"
TEMP_ZIP="$(mktemp "$ROOT_DIR/dist/Hazakura Wallpaper.zip.XXXXXX")"
rm -f "$TEMP_ZIP"
(
  cd "$ROOT_DIR/dist"
  ditto -c -k --norsrc --keepParent "Hazakura Wallpaper.app" "$TEMP_ZIP"
)

if ! run_zip_contents_check "$TEMP_ZIP"; then
  echo "ZIP content validation failed; removed incomplete ZIP release evidence." >&2
  exit 1
fi

mv "$TEMP_ZIP" "$ZIP_PATH"
TEMP_ZIP=""
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
run_release_evidence_check
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
PACKAGE_SUCCEEDED=1

echo "$ZIP_PATH"
