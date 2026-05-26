#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
SHA_PATH="$ROOT_DIR/dist/SHA256SUMS"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
MANIFEST_PATH="$EVIDENCE_DIR/RELEASE_MANIFEST.md"
ZIP_CONTENTS="$EVIDENCE_DIR/zip-contents.txt"
NOTARY_LOG="$EVIDENCE_DIR/notarytool-submit.log"
STAPLER_LOG="$EVIDENCE_DIR/stapler.log"
SPCTL_AFTER_NOTARIZATION="$EVIDENCE_DIR/spctl-after-notarization.txt"
FINAL_ZIP_VERIFY_LOG="$EVIDENCE_DIR/final-zip-verify.log"
NOTARY_ATTEMPT_LOG="$EVIDENCE_DIR/notarytool-submit.attempt.log"
STAPLER_ATTEMPT_LOG="$EVIDENCE_DIR/stapler.attempt.log"
SPCTL_AFTER_NOTARIZATION_ATTEMPT="$EVIDENCE_DIR/spctl-after-notarization.attempt.txt"
FINAL_ZIP_VERIFY_ATTEMPT_LOG="$EVIDENCE_DIR/final-zip-verify.attempt.log"
NOTARY_FAILED_LOG="$EVIDENCE_DIR/notarytool-submit.failed.log"
STAPLER_FAILED_LOG="$EVIDENCE_DIR/stapler.failed.log"
SPCTL_AFTER_NOTARIZATION_FAILED="$EVIDENCE_DIR/spctl-after-notarization.failed.txt"
FINAL_ZIP_VERIFY_FAILED_LOG="$EVIDENCE_DIR/final-zip-verify.failed.log"
VERIFY_DIR=""
TEMP_FINAL_ZIP=""
FINAL_ZIP_PACKAGE_STARTED=0
FINAL_ZIP_PACKAGE_SUCCEEDED=0

cleanup() {
  rm -f \
    "$NOTARY_ATTEMPT_LOG" \
    "$STAPLER_ATTEMPT_LOG" \
    "$SPCTL_AFTER_NOTARIZATION_ATTEMPT" \
    "$FINAL_ZIP_VERIFY_ATTEMPT_LOG"

  if [[ -n "$TEMP_FINAL_ZIP" ]]; then
    rm -f "$TEMP_FINAL_ZIP"
  fi

  if [[ "$FINAL_ZIP_PACKAGE_STARTED" == "1" && "$FINAL_ZIP_PACKAGE_SUCCEEDED" != "1" ]]; then
    rm -f \
      "$ZIP_PATH" \
      "$SHA_PATH" \
      "$MANIFEST_PATH" \
      "$ZIP_CONTENTS" \
      "$NOTARY_LOG" \
      "$STAPLER_LOG" \
      "$SPCTL_AFTER_NOTARIZATION" \
      "$FINAL_ZIP_VERIFY_LOG" \
      "$EVIDENCE_DIR/bundle-open-verified.txt" \
      "$EVIDENCE_DIR/visual-qa-accepted.txt"
  fi

  if [[ -n "$VERIFY_DIR" ]]; then
    rm -rf "$VERIFY_DIR"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Usage:
  SIGN_IDENTITY="Developer ID Application: Team Name (TEAMID)" \
  NOTARYTOOL_PROFILE="profile-name" \
  ./scripts/notarize_release_zip.sh

This script builds and checks a Developer ID signed app, verifies preview
determinism, creates a ZIP from that checked app for notarytool, requires
Accepted status, staples the accepted ticket to the app, validates Gatekeeper,
and recreates the final ZIP plus release evidence.

NOTARYTOOL_PROFILE must name a notarytool keychain profile. Explicit Apple ID
and password environment variables are intentionally not accepted, so secrets
are not passed through command arguments.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "${SIGN_IDENTITY:-}" || "${SIGN_IDENTITY:-}" == "-" || "${SIGN_IDENTITY:-}" != Developer\ ID\ Application:* ]]; then
  echo "SIGN_IDENTITY must be a Developer ID Application identity." >&2
  usage >&2
  exit 1
fi

legacy_notary_environment=()
for variable_name in NOTARYTOOL_APPLE_ID NOTARYTOOL_TEAM_ID NOTARYTOOL_PASSWORD; do
  if [[ -n "${!variable_name:-}" ]]; then
    legacy_notary_environment+=("$variable_name")
  fi
done

if [[ "${#legacy_notary_environment[@]}" -gt 0 ]]; then
  echo "Explicit Apple ID/password notarization environment variables are not accepted: ${legacy_notary_environment[*]}." >&2
  echo "Use NOTARYTOOL_PROFILE with a stored notarytool keychain profile." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required for notarytool and stapler." >&2
  exit 1
fi

if [[ -z "${NOTARYTOOL_PROFILE:-}" ]]; then
  echo "NOTARYTOOL_PROFILE must name a notarytool keychain profile." >&2
  usage >&2
  exit 1
fi

has_unique_matching_line() {
  local path="$1"
  local pattern="$2"
  local count

  count="$(grep -Eic "$pattern" "$path" || true)"
  [[ "$count" == "1" ]]
}

mkdir -p "$EVIDENCE_DIR"
rm -f \
  "$NOTARY_ATTEMPT_LOG" \
  "$STAPLER_ATTEMPT_LOG" \
  "$SPCTL_AFTER_NOTARIZATION_ATTEMPT" \
  "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" \
  "$NOTARY_FAILED_LOG" \
  "$STAPLER_FAILED_LOG" \
  "$SPCTL_AFTER_NOTARIZATION_FAILED" \
  "$FINAL_ZIP_VERIFY_FAILED_LOG"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null
HAZAKURA_WALLPAPER_REQUIRE_DEVELOPER_ID=1 SAKURA_SKY_REQUIRE_DEVELOPER_ID=1 "$ROOT_DIR/scripts/check_distribution_readiness.sh" "$APP_PATH"
"$ROOT_DIR/scripts/render_previews.sh" "$ROOT_DIR/dist/previews" >/dev/null
"$ROOT_DIR/scripts/check_preview_artifacts.sh" "$ROOT_DIR/dist/previews" >/dev/null
"$ROOT_DIR/scripts/check_preview_determinism.sh" >/dev/null
HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 SAKURA_SKY_PACKAGE_EXISTING_APP=1 "$ROOT_DIR/scripts/package_zip.sh" >/dev/null

submitted_bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
submitted_bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
submitted_build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
submitted_mach_o_architectures="$(lipo -archs "$APP_PATH/Contents/MacOS/HazakuraWallpaper")"
submitted_app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"
submitted_zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
submitted_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ -z "$submitted_app_cdhash" || -z "$submitted_mach_o_architectures" ]]; then
  echo "Could not read submitted app CDHash or architectures before notarization." >&2
  exit 1
fi

if ! {
  echo "Submitted archive: dist/Hazakura Wallpaper.zip"
  echo "Submitted ZIP SHA-256: $submitted_zip_sha"
  echo "Submitted at: $submitted_at"
  echo "Submitted bundle ID: $submitted_bundle_identifier"
  echo "Submitted version: $submitted_bundle_version"
  echo "Submitted build: $submitted_build_number"
  echo "Submitted architectures: $submitted_mach_o_architectures"
  echo "Submitted app CDHash: $submitted_app_cdhash"
  echo "Submitted command: xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>"
  xcrun notarytool submit "$ZIP_PATH" --wait --keychain-profile "$NOTARYTOOL_PROFILE"
} >"$NOTARY_ATTEMPT_LOG" 2>&1; then
  mv "$NOTARY_ATTEMPT_LOG" "$NOTARY_FAILED_LOG"
  echo "Notarization submission failed. Inspect $NOTARY_FAILED_LOG." >&2
  exit 1
fi

if ! has_unique_matching_line "$NOTARY_ATTEMPT_LOG" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$'; then
  mv "$NOTARY_ATTEMPT_LOG" "$NOTARY_FAILED_LOG"
  echo "Notarization did not report exactly one Accepted status. Inspect $NOTARY_FAILED_LOG." >&2
  exit 1
fi

if ! xcrun stapler staple "$APP_PATH" >"$STAPLER_ATTEMPT_LOG" 2>&1; then
  mv "$STAPLER_ATTEMPT_LOG" "$STAPLER_FAILED_LOG"
  echo "Stapling failed. Inspect $STAPLER_FAILED_LOG." >&2
  exit 1
fi

if ! xcrun stapler validate "$APP_PATH" >>"$STAPLER_ATTEMPT_LOG" 2>&1; then
  mv "$STAPLER_ATTEMPT_LOG" "$STAPLER_FAILED_LOG"
  echo "Stapler validation failed. Inspect $STAPLER_FAILED_LOG." >&2
  exit 1
fi

if ! has_unique_matching_line "$STAPLER_ATTEMPT_LOG" '^The (staple and )?validate action worked![[:space:]]*$'; then
  mv "$STAPLER_ATTEMPT_LOG" "$STAPLER_FAILED_LOG"
  echo "Stapler evidence did not report exactly one successful validation. Inspect $STAPLER_FAILED_LOG." >&2
  exit 1
fi

if ! spctl -a -vv --type execute "$APP_PATH" >"$SPCTL_AFTER_NOTARIZATION_ATTEMPT" 2>&1; then
  mv "$SPCTL_AFTER_NOTARIZATION_ATTEMPT" "$SPCTL_AFTER_NOTARIZATION_FAILED"
  echo "Gatekeeper assessment failed. Inspect $SPCTL_AFTER_NOTARIZATION_FAILED." >&2
  exit 1
fi

if ! has_unique_matching_line "$SPCTL_AFTER_NOTARIZATION_ATTEMPT" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'; then
  mv "$SPCTL_AFTER_NOTARIZATION_ATTEMPT" "$SPCTL_AFTER_NOTARIZATION_FAILED"
  echo "Gatekeeper evidence did not report exactly one accepted assessment. Inspect $SPCTL_AFTER_NOTARIZATION_FAILED." >&2
  exit 1
fi

rm -f \
  "$EVIDENCE_DIR/bundle-open-verified.txt" \
  "$EVIDENCE_DIR/visual-qa-accepted.txt"
FINAL_ZIP_PACKAGE_STARTED=1
TEMP_FINAL_ZIP="$(mktemp "$ROOT_DIR/dist/Hazakura Wallpaper.final.zip.XXXXXX")"
rm -f "$TEMP_FINAL_ZIP"
(
  cd "$ROOT_DIR/dist"
  ditto -c -k --norsrc --keepParent "Hazakura Wallpaper.app" "$TEMP_FINAL_ZIP"
)

"$ROOT_DIR/scripts/check_zip_contents.sh" "$TEMP_FINAL_ZIP" >/dev/null
final_zip_sha="$(shasum -a 256 "$TEMP_FINAL_ZIP" | awk '{ print $1 }')"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-notarized-zip.XXXXXX")"
if ! {
  echo "Verifying final notarized ZIP: $ZIP_PATH"
  echo "Verified archive: dist/Hazakura Wallpaper.zip"
  echo "Final ZIP SHA-256: $final_zip_sha"
  ditto -x -k "$TEMP_FINAL_ZIP" "$VERIFY_DIR"
  EXTRACTED_APP="$VERIFY_DIR/Hazakura Wallpaper.app"
  test -x "$EXTRACTED_APP/Contents/MacOS/HazakuraWallpaper"
  plutil -lint "$EXTRACTED_APP/Contents/Info.plist"
  echo "Bundle ID: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXTRACTED_APP/Contents/Info.plist")"
  echo "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$EXTRACTED_APP/Contents/Info.plist")"
  echo "Build: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$EXTRACTED_APP/Contents/Info.plist")"
  echo "Architectures: $(lipo -archs "$EXTRACTED_APP/Contents/MacOS/HazakuraWallpaper")"
  codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP"
  echo "CDHash: $(codesign -dvvv "$EXTRACTED_APP" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"
  xcrun stapler validate "$EXTRACTED_APP"
  spctl -a -vv --type execute "$EXTRACTED_APP"
  echo "Final notarized ZIP verification passed."
} >"$FINAL_ZIP_VERIFY_ATTEMPT_LOG" 2>&1; then
  mv "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" "$FINAL_ZIP_VERIFY_FAILED_LOG"
  echo "Final ZIP verification failed. Inspect $FINAL_ZIP_VERIFY_FAILED_LOG." >&2
  exit 1
fi

if ! has_unique_matching_line "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" '^Final notarized ZIP verification passed\.$' ||
  ! has_unique_matching_line "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" '^[^:]+:[[:space:]]+valid on disk$' ||
  ! has_unique_matching_line "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" '^[^:]+:[[:space:]]+satisfies its Designated Requirement$' ||
  ! has_unique_matching_line "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" '^The (staple and )?validate action worked![[:space:]]*$' ||
  ! has_unique_matching_line "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'; then
  mv "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" "$FINAL_ZIP_VERIFY_FAILED_LOG"
  echo "Final ZIP verification evidence did not report exactly one success marker, codesign validity, stapler validation, and Gatekeeper acceptance. Inspect $FINAL_ZIP_VERIFY_FAILED_LOG." >&2
  exit 1
fi

mv "$TEMP_FINAL_ZIP" "$ZIP_PATH"
TEMP_FINAL_ZIP=""
mv "$NOTARY_ATTEMPT_LOG" "$NOTARY_LOG"
mv "$STAPLER_ATTEMPT_LOG" "$STAPLER_LOG"
mv "$SPCTL_AFTER_NOTARIZATION_ATTEMPT" "$SPCTL_AFTER_NOTARIZATION"
mv "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" "$FINAL_ZIP_VERIFY_LOG"

"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
FINAL_ZIP_PACKAGE_SUCCEEDED=1

echo "Notarized release ZIP created: $ZIP_PATH"
echo "Evidence: $EVIDENCE_DIR"
