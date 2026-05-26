#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
RELEASE_QA_DOC="$ROOT_DIR/docs/RELEASE_QA.md"
MANIFEST_PATH="$ROOT_DIR/dist/release-evidence/RELEASE_MANIFEST.md"
RELEASE_EVIDENCE_CHECK="$ROOT_DIR/dist/release-evidence/release-evidence-check.txt"
GUARD_TESTS_LOG="$ROOT_DIR/dist/release-evidence/release-evidence-guard-tests.txt"
FINAL_ZIP_VERIFY_LOG="$ROOT_DIR/dist/release-evidence/final-zip-verify.log"
NOTARY_LOG="$ROOT_DIR/dist/release-evidence/notarytool-submit.log"
STAPLER_LOG="$ROOT_DIR/dist/release-evidence/stapler.log"
SPCTL_AFTER_NOTARIZATION="$ROOT_DIR/dist/release-evidence/spctl-after-notarization.txt"
BUNDLE_OPEN_LOG="$ROOT_DIR/dist/release-evidence/bundle-open-verified.txt"
VISUAL_QA_LOG="$ROOT_DIR/dist/release-evidence/visual-qa-accepted.txt"
STALE_NOTARIZATION_ATTEMPT_EVIDENCE=(
  "$ROOT_DIR/dist/release-evidence/notarytool-submit.attempt.log"
  "$ROOT_DIR/dist/release-evidence/notarytool-submit.failed.log"
  "$ROOT_DIR/dist/release-evidence/stapler.attempt.log"
  "$ROOT_DIR/dist/release-evidence/stapler.failed.log"
  "$ROOT_DIR/dist/release-evidence/spctl-after-notarization.attempt.txt"
  "$ROOT_DIR/dist/release-evidence/spctl-after-notarization.failed.txt"
  "$ROOT_DIR/dist/release-evidence/final-zip-verify.attempt.log"
  "$ROOT_DIR/dist/release-evidence/final-zip-verify.failed.log"
)

cd "$ROOT_DIR"

REQUIRE_NOTARIZATION="${HAZAKURA_WALLPAPER_REQUIRE_NOTARIZATION:-${SAKURA_SKY_REQUIRE_NOTARIZATION:-0}}"
case "$REQUIRE_NOTARIZATION" in
  0|1) ;;
  *)
    echo "HAZAKURA_WALLPAPER_REQUIRE_NOTARIZATION must be 0 or 1, got '$REQUIRE_NOTARIZATION'." >&2
    exit 2
    ;;
esac

legacy_notary_environment=()
for variable_name in NOTARYTOOL_APPLE_ID NOTARYTOOL_TEAM_ID NOTARYTOOL_PASSWORD; do
  if [[ -n "${!variable_name:-}" ]]; then
    legacy_notary_environment+=("$variable_name")
  fi
done

for stale_path in "${STALE_NOTARIZATION_ATTEMPT_EVIDENCE[@]}"; do
  if [[ -e "$stale_path" ]]; then
    echo "Publish readiness failed: stale notarization attempt evidence exists outside canonical final evidence: $stale_path" >&2
    exit 1
  fi
done

if [[ "$REQUIRE_NOTARIZATION" == "1" && "${#legacy_notary_environment[@]}" -gt 0 ]]; then
  echo "Publish readiness failed: explicit Apple ID/password notarization environment variables are not accepted: ${legacy_notary_environment[*]}." >&2
  echo "Use NOTARYTOOL_PROFILE with a stored notarytool keychain profile." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_public_repository_docs.sh" >/dev/null; then
  echo "Publish readiness failed: public repository documentation is incomplete." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_public_source_hygiene.sh" >/dev/null; then
  echo "Publish readiness failed: source hygiene checks found local paths, generated files, or credential-like material." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_public_git_history_hygiene.sh" >/dev/null; then
  echo "Publish readiness failed: Git history hygiene checks found local paths or credential-like material." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_privacy_security_boundaries.sh" >/dev/null; then
  echo "Publish readiness failed: app privacy/security boundaries changed." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null; then
  echo "Publish readiness failed: release evidence is incomplete or inconsistent." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_github_release_notes.sh" >/dev/null; then
  echo "Publish readiness failed: GitHub release notes draft is missing or stale." >&2
  exit 1
fi

if ! "$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" >/dev/null; then
  echo "Publish readiness failed: public release artifacts contain local paths, raw evidence, or credential-like material." >&2
  exit 1
fi

if ! HAZAKURA_WALLPAPER_WRITE_DISTRIBUTION_EVIDENCE=0 SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE=0 "$ROOT_DIR/scripts/check_distribution_readiness.sh" "$APP_PATH" >/dev/null 2>&1; then
  echo "Publish readiness failed: app distribution metadata is incomplete or inconsistent." >&2
  exit 1
fi

actual_zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
if [[ ! -s "$RELEASE_QA_DOC" ]]; then
  echo "Publish readiness failed: missing release QA checklist: docs/RELEASE_QA.md" >&2
  exit 1
fi
release_qa_sha="$(shasum -a 256 "$RELEASE_QA_DOC" | awk '{ print $1 }')"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
bundle_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"
mach_o_architectures="$(lipo -archs "$APP_PATH/Contents/MacOS/HazakuraWallpaper")"

require_manifest_line() {
  local line="$1"
  if ! grep -Fq -- "$line" "$MANIFEST_PATH"; then
    echo "Publish readiness failed: manifest missing '$line'." >&2
    exit 1
  fi
}

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

require_single_line_nonblank_evidence_field() {
  local path="$1"
  local label="$2"
  local description="$3"
  local value

  if ! value="$(read_unique_evidence_field "$path" "$label")"; then
    echo "Publish readiness failed: $description evidence must contain exactly one field: $label." >&2
    exit 1
  fi

  if [[ "$value" =~ [[:cntrl:]] || ! "$value" =~ [^[:space:]] ]]; then
    echo "Publish readiness failed: $description evidence has an empty or multi-line field: $label." >&2
    exit 1
  fi
}

require_utc_timestamp_evidence_field() {
  local path="$1"
  local label="$2"
  local description="$3"
  local value

  if ! value="$(read_unique_evidence_field "$path" "$label")"; then
    echo "Publish readiness failed: $description evidence must contain exactly one field: $label." >&2
    exit 1
  fi

  if [[ ! "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "Publish readiness failed: $description evidence has an invalid UTC timestamp field: $label." >&2
    exit 1
  fi
}

require_sha256_evidence_field() {
  local path="$1"
  local label="$2"
  local description="$3"
  local value

  if ! value="$(read_unique_evidence_field "$path" "$label")"; then
    echo "Publish readiness failed: $description evidence must contain exactly one field: $label." >&2
    exit 1
  fi

  if [[ ! "$value" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Publish readiness failed: $description evidence has an invalid SHA-256 field: $label." >&2
    exit 1
  fi
}

require_exact_evidence_field() {
  local path="$1"
  local label="$2"
  local expected="$3"
  local description="$4"
  local value

  if ! value="$(read_unique_evidence_field "$path" "$label")"; then
    echo "Publish readiness failed: $description evidence must contain exactly one field: $label." >&2
    exit 1
  fi

  if [[ "$value" != "$expected" ]]; then
    echo "Publish readiness failed: $description evidence has an unexpected field value for $label." >&2
    echo "expected: $expected" >&2
    echo "actual: $value" >&2
    exit 1
  fi
}

require_unique_matching_line() {
  local path="$1"
  local pattern="$2"
  local description="$3"
  local count

  count="$(grep -Eic "$pattern" "$path" || true)"
  if [[ "$count" != "1" ]]; then
    echo "Publish readiness failed: $description evidence must contain exactly one matching line for: $pattern." >&2
    exit 1
  fi
}

require_manifest_line "- ZIP SHA-256: $actual_zip_sha"
require_manifest_line "- dist/release-evidence/release-evidence-guard-tests.txt"

if [[ ! -s "$GUARD_TESTS_LOG" ]]; then
  echo "Publish readiness failed: missing release evidence guard test evidence: dist/release-evidence/release-evidence-guard-tests.txt." >&2
  exit 1
fi

require_exact_evidence_field "$GUARD_TESTS_LOG" "Release evidence guard tests passed" "yes" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "Bundle ID" "$bundle_identifier" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "Version" "$bundle_version" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "Build" "$bundle_build" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "Architectures" "$mach_o_architectures" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "CDHash" "$app_cdhash" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "ZIP SHA-256" "$actual_zip_sha" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "Checked command" "./scripts/test_release_evidence_guards.sh" "release evidence guard tests"
require_exact_evidence_field "$GUARD_TESTS_LOG" "Duplicate preview fixture rejection" "passed" "release evidence guard tests"
require_utc_timestamp_evidence_field "$GUARD_TESTS_LOG" "Checked at" "release evidence guard tests"

if ! grep -Fq -- "- none from release evidence; run ./scripts/check_publish_readiness.sh" "$RELEASE_EVIDENCE_CHECK"; then
  echo "Publish readiness failed: release evidence report still lists publish-readiness blockers." >&2
  exit 1
fi

if [[ "$REQUIRE_NOTARIZATION" == "0" ]]; then
  require_manifest_line "- App: dist/Hazakura Wallpaper.app"
  require_manifest_line "- ZIP: dist/Hazakura Wallpaper.zip"
  echo "Publish readiness checks passed for unsigned GitHub/DMG distribution."
  echo "App: dist/Hazakura Wallpaper.app"
  echo "ZIP SHA-256: $actual_zip_sha"
  echo "Version: $bundle_version"
  echo "Gatekeeper: users on other Macs may need right-click Open or System Settings > Privacy & Security > Open Anyway."
  exit 0
fi

if ! HAZAKURA_WALLPAPER_REQUIRE_DEVELOPER_ID=1 SAKURA_SKY_REQUIRE_DEVELOPER_ID=1 "$ROOT_DIR/scripts/check_distribution_readiness.sh" "$APP_PATH" >/dev/null 2>&1; then
  echo "Publish readiness failed: app is not signed with a notarization-ready Developer ID Application identity." >&2
  exit 1
fi

require_manifest_line "- Code signature: Developer ID Application"
require_manifest_line "- Final notarized ZIP verified: yes"

for path in \
  "$NOTARY_LOG" \
  "$STAPLER_LOG" \
  "$SPCTL_AFTER_NOTARIZATION" \
  "$FINAL_ZIP_VERIFY_LOG"; do
  if [[ ! -s "$path" ]]; then
    echo "Publish readiness failed: missing required notarization evidence: $path" >&2
    exit 1
  fi
done

require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Verified archive" "dist/Hazakura Wallpaper.zip" "final ZIP verification"
require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Final ZIP SHA-256" "$actual_zip_sha" "final ZIP verification"
require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Bundle ID" "$bundle_identifier" "final ZIP verification"
require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Version" "$bundle_version" "final ZIP verification"
require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Build" "$bundle_build" "final ZIP verification"
require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Architectures" "$mach_o_architectures" "final ZIP verification"
require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "CDHash" "$app_cdhash" "final ZIP verification"

require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^Final notarized ZIP verification passed\.$' "final ZIP verification"
require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^[^:]+:[[:space:]]+valid on disk$' "final ZIP verification"
require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^[^:]+:[[:space:]]+satisfies its Designated Requirement$' "final ZIP verification"
require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^The (staple and )?validate action worked![[:space:]]*$' "final ZIP verification"
require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^[^:]+:[[:space:]]+accepted[[:space:]]*$' "final ZIP verification"

require_unique_matching_line "$NOTARY_LOG" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$' "notarytool"

require_exact_evidence_field "$NOTARY_LOG" "Submitted archive" "dist/Hazakura Wallpaper.zip" "notarytool submission"
require_sha256_evidence_field "$NOTARY_LOG" "Submitted ZIP SHA-256" "notarytool submission"
require_utc_timestamp_evidence_field "$NOTARY_LOG" "Submitted at" "notarytool submission"
require_exact_evidence_field "$NOTARY_LOG" "Submitted bundle ID" "$bundle_identifier" "notarytool submission"
require_exact_evidence_field "$NOTARY_LOG" "Submitted version" "$bundle_version" "notarytool submission"
require_exact_evidence_field "$NOTARY_LOG" "Submitted build" "$bundle_build" "notarytool submission"
require_exact_evidence_field "$NOTARY_LOG" "Submitted architectures" "$mach_o_architectures" "notarytool submission"
require_exact_evidence_field "$NOTARY_LOG" "Submitted app CDHash" "$app_cdhash" "notarytool submission"
require_exact_evidence_field "$NOTARY_LOG" "Submitted command" "xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>" "notarytool submission"

require_unique_matching_line "$STAPLER_LOG" '^The (staple and )?validate action worked![[:space:]]*$' "stapler"

require_unique_matching_line "$SPCTL_AFTER_NOTARIZATION" '^[^:]+:[[:space:]]+accepted[[:space:]]*$' "Gatekeeper"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "Publish readiness failed: xcrun is required for stapler validation." >&2
  exit 1
fi

if ! xcrun stapler validate "$APP_PATH" >/dev/null 2>&1; then
  echo "Publish readiness failed: stapler validation failed for the current app." >&2
  exit 1
fi

if ! spctl -a -vv --type execute "$APP_PATH" >/dev/null 2>&1; then
  echo "Publish readiness failed: Gatekeeper assessment failed for the current app." >&2
  exit 1
fi

if [[ ! -s "$BUNDLE_OPEN_LOG" ]]; then
  echo "Publish readiness failed: missing normal-session bundle-open verification: $BUNDLE_OPEN_LOG" >&2
  exit 1
fi

require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Bundle open verified" "yes" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Bundle ID" "$bundle_identifier" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Version" "$bundle_version" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Build" "$bundle_build" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Architectures" "$mach_o_architectures" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "CDHash" "$app_cdhash" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "ZIP SHA-256" "$actual_zip_sha" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified app" "dist/Hazakura Wallpaper.app" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified process match" "anchored executable path" "bundle-open verification"
require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified command" "./scripts/record_bundle_open_verification.sh --operator <operator>" "bundle-open verification"
require_utc_timestamp_evidence_field "$BUNDLE_OPEN_LOG" "Verified at" "bundle-open verification"
require_single_line_nonblank_evidence_field "$BUNDLE_OPEN_LOG" "Operator" "bundle-open verification"

if [[ ! -s "$VISUAL_QA_LOG" ]]; then
  echo "Publish readiness failed: missing human visual QA acceptance: $VISUAL_QA_LOG" >&2
  exit 1
fi

require_exact_evidence_field "$VISUAL_QA_LOG" "Visual QA accepted" "yes" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Bundle ID" "$bundle_identifier" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Version" "$bundle_version" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Build" "$bundle_build" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Architectures" "$mach_o_architectures" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "CDHash" "$app_cdhash" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "ZIP SHA-256" "$actual_zip_sha" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist" "docs/RELEASE_QA.md" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist completed" "yes" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist SHA-256" "$release_qa_sha" "visual QA acceptance"
require_exact_evidence_field "$VISUAL_QA_LOG" "Accepted command" "./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>" "visual QA acceptance"
require_utc_timestamp_evidence_field "$VISUAL_QA_LOG" "Accepted at" "visual QA acceptance"
require_single_line_nonblank_evidence_field "$VISUAL_QA_LOG" "Reviewer" "visual QA acceptance"

if ! grep -Fq -- "- none from release evidence; run ./scripts/check_publish_readiness.sh" "$RELEASE_EVIDENCE_CHECK"; then
  echo "Publish readiness failed: release evidence report still lists publish-readiness blockers." >&2
  exit 1
fi

echo "Publish readiness checks passed."
echo "App: dist/Hazakura Wallpaper.app"
echo "ZIP SHA-256: $actual_zip_sha"
echo "Version: $bundle_version"
