#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"
RELEASE_QA_DOC="$ROOT_DIR/docs/RELEASE_QA.md"
PREVIEW_DIR="$ROOT_DIR/dist/previews"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
MANIFEST_PATH="$EVIDENCE_DIR/RELEASE_MANIFEST.md"
SHA_PATH="$ROOT_DIR/dist/SHA256SUMS"
FINAL_ZIP_VERIFY_LOG="$EVIDENCE_DIR/final-zip-verify.log"
RELEASE_EVIDENCE_CHECK="$EVIDENCE_DIR/release-evidence-check.txt"
SIGNING_INFO="$EVIDENCE_DIR/codesign-info.txt"
ENTITLEMENTS="$EVIDENCE_DIR/entitlements.plist"
SPCTL_INFO="$EVIDENCE_DIR/spctl.txt"
MACHO_INFO="$EVIDENCE_DIR/macho-build.txt"
DMG_INFO="$EVIDENCE_DIR/dmg-info.txt"
RENDERER_MEMORY_SMOKE="$EVIDENCE_DIR/renderer-memory-smoke.txt"
GUARD_TESTS_LOG="$EVIDENCE_DIR/release-evidence-guard-tests.txt"
BUNDLE_OPEN_LOG="$EVIDENCE_DIR/bundle-open-verified.txt"
VISUAL_QA_LOG="$EVIDENCE_DIR/visual-qa-accepted.txt"
UNSIGNED_BUNDLE_OPEN_LOG="$EVIDENCE_DIR/unsigned-bundle-open-verified.txt"
UNSIGNED_VISUAL_QA_LOG="$EVIDENCE_DIR/unsigned-visual-qa-accepted.txt"
UNSIGNED_MEMORY_LOG="$EVIDENCE_DIR/unsigned-memory-check.txt"
NOTARY_LOG="$EVIDENCE_DIR/notarytool-submit.log"
STAPLER_LOG="$EVIDENCE_DIR/stapler.log"
SPCTL_AFTER_NOTARIZATION="$EVIDENCE_DIR/spctl-after-notarization.txt"

mkdir -p "$EVIDENCE_DIR"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing ZIP archive: $ZIP_PATH" >&2
  exit 1
fi

TEMP_MANIFEST="$(mktemp "$EVIDENCE_DIR/RELEASE_MANIFEST.XXXXXX")"
TEMP_SHA="$(mktemp "$ROOT_DIR/dist/SHA256SUMS.XXXXXX")"
trap 'rm -f "$TEMP_MANIFEST" "$TEMP_SHA"' EXIT

created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_PATH/Contents/Info.plist")"
mach_o_info="$(vtool -show-build "$APP_PATH/Contents/MacOS/HazakuraWallpaper")"
mach_o_architectures="$(lipo -archs "$APP_PATH/Contents/MacOS/HazakuraWallpaper")"
mach_o_minimum_system="$(awk '$1 == "minos" { print $2; exit }' <<<"$mach_o_info")"
mach_o_sdk="$(awk '$1 == "sdk" { print $2; exit }' <<<"$mach_o_info")"
zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
dmg_sha=""
if [[ -f "$DMG_PATH" ]]; then
  dmg_sha="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
fi
release_qa_sha=""
if [[ -f "$RELEASE_QA_DOC" ]]; then
  release_qa_sha="$(shasum -a 256 "$RELEASE_QA_DOC" | awk '{ print $1 }')"
fi
app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{print $2; exit}')"
entitlements="present"
if [[ -z "$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)" ]]; then
  entitlements="none"
fi
signature="ad-hoc"
if codesign -dvvv "$APP_PATH" 2>&1 | grep -q "Authority=Developer ID Application"; then
  signature="Developer ID Application"
fi
preview_artifacts_log="$EVIDENCE_DIR/preview-artifacts.txt"
preview_determinism_log="$EVIDENCE_DIR/preview-determinism.txt"
zip_contents_log="$EVIDENCE_DIR/zip-contents.txt"
icon_info_log="$EVIDENCE_DIR/icon-info.txt"

evidence_matches_current_build() {
  local path="$1"

  [[ -s "$path" ]] &&
    has_exact_evidence_field "$path" "Bundle ID" "$bundle_identifier" &&
    has_exact_evidence_field "$path" "Version" "$bundle_version" &&
    has_exact_evidence_field "$path" "Build" "$build_number" &&
    has_exact_evidence_field "$path" "Architectures" "$mach_o_architectures" &&
    has_exact_evidence_field "$path" "CDHash" "$app_cdhash" &&
    has_exact_evidence_field "$path" "ZIP SHA-256" "$zip_sha"
}

has_single_line_nonblank_evidence_field() {
  local path="$1"
  local label="$2"
  local value

  if ! value="$(awk -v label="$label" '
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
  ' "$path")"; then
    return 1
  fi

  [[ ! "$value" =~ [[:cntrl:]] && "$value" =~ [^[:space:]] ]]
}

has_utc_timestamp_evidence_field() {
  local path="$1"
  local label="$2"
  local value

  if ! value="$(awk -v label="$label" '
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
  ' "$path")"; then
    return 1
  fi

  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

has_exact_evidence_field() {
  local path="$1"
  local label="$2"
  local expected="$3"
  local value

  if ! value="$(awk -v label="$label" '
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
  ' "$path")"; then
    return 1
  fi

  [[ "$value" == "$expected" ]]
}

has_sha256_evidence_field() {
  local path="$1"
  local label="$2"
  local value

  if ! value="$(awk -v label="$label" '
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
  ' "$path")"; then
    return 1
  fi

  [[ "$value" =~ ^[0-9a-f]{64}$ ]]
}

has_unique_matching_line() {
  local path="$1"
  local pattern="$2"
  local count

  count="$(grep -Eic "$pattern" "$path" || true)"
  [[ "$count" == "1" ]]
}

notary_submission_evidence_matches_current_build() {
  local path="$1"

  [[ -s "$path" ]] &&
    has_exact_evidence_field "$path" "Submitted archive" "dist/Hazakura Wallpaper.zip" &&
    has_sha256_evidence_field "$path" "Submitted ZIP SHA-256" &&
    has_utc_timestamp_evidence_field "$path" "Submitted at" &&
    has_exact_evidence_field "$path" "Submitted bundle ID" "$bundle_identifier" &&
    has_exact_evidence_field "$path" "Submitted version" "$bundle_version" &&
    has_exact_evidence_field "$path" "Submitted build" "$build_number" &&
    has_exact_evidence_field "$path" "Submitted architectures" "$mach_o_architectures" &&
    has_exact_evidence_field "$path" "Submitted app CDHash" "$app_cdhash" &&
    has_exact_evidence_field "$path" "Submitted command" "xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>"
}

final_zip_verification_evidence_matches_current_build() {
  local path="$1"

  [[ -s "$path" ]] &&
    has_exact_evidence_field "$path" "Verified archive" "dist/Hazakura Wallpaper.zip" &&
    has_exact_evidence_field "$path" "Final ZIP SHA-256" "$zip_sha" &&
    has_exact_evidence_field "$path" "Bundle ID" "$bundle_identifier" &&
    has_exact_evidence_field "$path" "Version" "$bundle_version" &&
    has_exact_evidence_field "$path" "Build" "$build_number" &&
    has_exact_evidence_field "$path" "Architectures" "$mach_o_architectures" &&
    has_exact_evidence_field "$path" "CDHash" "$app_cdhash" &&
    has_unique_matching_line "$path" '^Final notarized ZIP verification passed\.$' &&
    has_unique_matching_line "$path" '^[^:]+:[[:space:]]+valid on disk$' &&
    has_unique_matching_line "$path" '^[^:]+:[[:space:]]+satisfies its Designated Requirement$' &&
    has_unique_matching_line "$path" '^The (staple and )?validate action worked![[:space:]]*$' &&
    has_unique_matching_line "$path" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'
}

final_zip_verified="no"
if final_zip_verification_evidence_matches_current_build "$FINAL_ZIP_VERIFY_LOG" &&
  [[ "$signature" == "Developer ID Application" ]] &&
  notary_submission_evidence_matches_current_build "$NOTARY_LOG" &&
  has_unique_matching_line "$NOTARY_LOG" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$' &&
  [[ -s "$STAPLER_LOG" ]] &&
  has_unique_matching_line "$STAPLER_LOG" '^The (staple and )?validate action worked![[:space:]]*$' &&
  [[ -s "$SPCTL_AFTER_NOTARIZATION" ]] &&
  has_unique_matching_line "$SPCTL_AFTER_NOTARIZATION" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'; then
  final_zip_verified="yes"
fi

bundle_open_evidence_matches_current_build() {
  local path="$1"

  evidence_matches_current_build "$path" &&
    has_exact_evidence_field "$path" "Bundle open verified" "yes" &&
    has_exact_evidence_field "$path" "Verified app" "dist/Hazakura Wallpaper.app" &&
    has_exact_evidence_field "$path" "Verified executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" &&
    has_exact_evidence_field "$path" "Verified process match" "anchored executable path" &&
    has_exact_evidence_field "$path" "Verified command" "./scripts/record_bundle_open_verification.sh --operator <operator>" &&
    has_utc_timestamp_evidence_field "$path" "Verified at" &&
    has_single_line_nonblank_evidence_field "$path" "Operator"
}

visual_qa_evidence_matches_current_build() {
  local path="$1"

  [[ -n "$release_qa_sha" ]] &&
    evidence_matches_current_build "$path" &&
    has_exact_evidence_field "$path" "Visual QA accepted" "yes" &&
    has_exact_evidence_field "$path" "Checklist" "docs/RELEASE_QA.md" &&
    has_exact_evidence_field "$path" "Checklist completed" "yes" &&
    has_exact_evidence_field "$path" "Checklist SHA-256" "$release_qa_sha" &&
    has_exact_evidence_field "$path" "Accepted command" "./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>" &&
    has_utc_timestamp_evidence_field "$path" "Accepted at" &&
    has_single_line_nonblank_evidence_field "$path" "Reviewer"
}

unsigned_bundle_open_evidence_matches_current_build() {
  local path="$1"

  evidence_matches_current_build "$path" &&
    has_exact_evidence_field "$path" "Unsigned bundle open verified" "yes" &&
    has_exact_evidence_field "$path" "Verified app" "dist/Hazakura Wallpaper.app" &&
    has_exact_evidence_field "$path" "Verified executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" &&
    has_exact_evidence_field "$path" "Verified process match" "anchored executable path" &&
    has_exact_evidence_field "$path" "Verified command" "./scripts/record_unsigned_bundle_open_verification.sh --operator <operator>" &&
    has_utc_timestamp_evidence_field "$path" "Verified at" &&
    has_single_line_nonblank_evidence_field "$path" "Operator"
}

unsigned_visual_qa_evidence_matches_current_build() {
  local path="$1"

  [[ -n "$release_qa_sha" ]] &&
    evidence_matches_current_build "$path" &&
    has_exact_evidence_field "$path" "Unsigned visual QA accepted" "yes" &&
    has_exact_evidence_field "$path" "Checklist" "docs/RELEASE_QA.md" &&
    has_exact_evidence_field "$path" "Checklist completed" "yes" &&
    has_exact_evidence_field "$path" "Checklist SHA-256" "$release_qa_sha" &&
    has_exact_evidence_field "$path" "Accepted command" "./scripts/record_unsigned_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>" &&
    has_utc_timestamp_evidence_field "$path" "Accepted at" &&
    has_single_line_nonblank_evidence_field "$path" "Reviewer"
}

unsigned_memory_evidence_matches_current_build() {
  local path="$1"

  evidence_matches_current_build "$path" &&
    has_exact_evidence_field "$path" "Unsigned memory check passed" "yes" &&
    has_exact_evidence_field "$path" "Checked executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" &&
    has_exact_evidence_field "$path" "Checked command" "./scripts/record_unsigned_memory_check.sh --operator <operator>" &&
    has_exact_evidence_field "$path" "Tool" "leaks --atExit" &&
    has_exact_evidence_field "$path" "MallocStackLogging" "enabled" &&
    has_exact_evidence_field "$path" "Smoke exit after seconds" "1" &&
    has_exact_evidence_field "$path" "Leaks exit code" "0" &&
    has_exact_evidence_field "$path" "Leaks result" "no leaks reported by leaks --atExit" &&
    has_utc_timestamp_evidence_field "$path" "Checked at" &&
    has_single_line_nonblank_evidence_field "$path" "Operator"
}

guard_tests_evidence_matches_current_build() {
  local path="$1"

  evidence_matches_current_build "$path" &&
    has_exact_evidence_field "$path" "Release evidence guard tests passed" "yes" &&
    has_exact_evidence_field "$path" "Checked command" "./scripts/test_release_evidence_guards.sh" &&
    has_exact_evidence_field "$path" "Duplicate preview fixture rejection" "passed" &&
    has_utc_timestamp_evidence_field "$path" "Checked at"
}

bundle_open_verified="no"
if [[ "$final_zip_verified" == "yes" ]] && bundle_open_evidence_matches_current_build "$BUNDLE_OPEN_LOG"; then
  bundle_open_verified="yes"
fi

visual_qa_accepted="no"
if [[ "$final_zip_verified" == "yes" ]] && visual_qa_evidence_matches_current_build "$VISUAL_QA_LOG"; then
  visual_qa_accepted="yes"
fi

unsigned_bundle_open_verified="no"
if unsigned_bundle_open_evidence_matches_current_build "$UNSIGNED_BUNDLE_OPEN_LOG"; then
  unsigned_bundle_open_verified="yes"
fi

unsigned_visual_qa_accepted="no"
if unsigned_visual_qa_evidence_matches_current_build "$UNSIGNED_VISUAL_QA_LOG"; then
  unsigned_visual_qa_accepted="yes"
fi

unsigned_memory_checked="no"
if unsigned_memory_evidence_matches_current_build "$UNSIGNED_MEMORY_LOG"; then
  unsigned_memory_checked="yes"
fi

normal_session_bundle_open_verified="$bundle_open_verified"
if [[ "$unsigned_bundle_open_verified" == "yes" ]]; then
  normal_session_bundle_open_verified="yes"
fi

human_visual_qa_accepted="$visual_qa_accepted"
if [[ "$unsigned_visual_qa_accepted" == "yes" ]]; then
  human_visual_qa_accepted="yes"
fi

{
  echo "# Hazakura Wallpaper Release Manifest"
  echo
  echo "- Created: $created_at"
  echo "- Bundle ID: $bundle_identifier"
  echo "- Version: $bundle_version"
  echo "- Build: $build_number"
  echo "- Minimum macOS: $minimum_system"
  echo "- Mach-O architectures: $mach_o_architectures"
  echo "- Mach-O minimum macOS: $mach_o_minimum_system"
  echo "- Mach-O SDK: $mach_o_sdk"
  echo "- App: dist/Hazakura Wallpaper.app"
  echo "- ZIP: dist/Hazakura Wallpaper.zip"
  echo "- ZIP SHA-256: $zip_sha"
  if [[ -n "$dmg_sha" ]]; then
    echo "- DMG: dist/Hazakura Wallpaper.dmg"
    echo "- DMG SHA-256: $dmg_sha"
  fi
  echo "- Code signature: $signature"
  echo "- Entitlements: $entitlements"
  echo "- Final notarized ZIP verified: $final_zip_verified"
  echo "- CDHash: $app_cdhash"
  echo
  echo "## Preview Artifacts"
  for preview in sakura magic spark hazakura breeze firefly night-sakura qa-matrix-day qa-matrix-night; do
    if [[ -f "$PREVIEW_DIR/$preview.png" ]]; then
      echo "- dist/previews/$preview.png"
    fi
  done
  echo
  echo "## Release Evidence"
  if [[ "$final_zip_verified" == "yes" ]]; then
    echo "- dist/release-evidence/notarytool-submit.log"
    echo "- dist/release-evidence/stapler.log"
    echo "- dist/release-evidence/spctl-after-notarization.txt"
    echo "- dist/release-evidence/final-zip-verify.log"
  fi
  if [[ -f "$preview_artifacts_log" ]]; then
    echo "- dist/release-evidence/preview-artifacts.txt"
  fi
  if [[ -f "$preview_determinism_log" ]]; then
    echo "- dist/release-evidence/preview-determinism.txt"
  fi
  if [[ -f "$zip_contents_log" ]]; then
    echo "- dist/release-evidence/zip-contents.txt"
  fi
  if [[ -f "$icon_info_log" ]]; then
    echo "- dist/release-evidence/icon-info.txt"
  fi
  if [[ -f "$SIGNING_INFO" ]]; then
    echo "- dist/release-evidence/codesign-info.txt"
  fi
  if [[ -f "$ENTITLEMENTS" ]]; then
    echo "- dist/release-evidence/entitlements.plist"
  fi
  if [[ -f "$SPCTL_INFO" ]]; then
    echo "- dist/release-evidence/spctl.txt"
  fi
  if [[ -f "$MACHO_INFO" ]]; then
    echo "- dist/release-evidence/macho-build.txt"
  fi
  if [[ -f "$RENDERER_MEMORY_SMOKE" ]]; then
    echo "- dist/release-evidence/renderer-memory-smoke.txt"
  fi
  if [[ -f "$DMG_INFO" ]]; then
    echo "- dist/release-evidence/dmg-info.txt"
  fi
  if [[ "$bundle_open_verified" == "yes" ]]; then
    echo "- dist/release-evidence/bundle-open-verified.txt"
  fi
  if [[ "$visual_qa_accepted" == "yes" ]]; then
    echo "- dist/release-evidence/visual-qa-accepted.txt"
  fi
  if [[ "$unsigned_bundle_open_verified" == "yes" ]]; then
    echo "- dist/release-evidence/unsigned-bundle-open-verified.txt"
  fi
  if [[ "$unsigned_visual_qa_accepted" == "yes" ]]; then
    echo "- dist/release-evidence/unsigned-visual-qa-accepted.txt"
  fi
  if [[ "$unsigned_memory_checked" == "yes" ]]; then
    echo "- dist/release-evidence/unsigned-memory-check.txt"
  fi
  if guard_tests_evidence_matches_current_build "$GUARD_TESTS_LOG"; then
    echo "- dist/release-evidence/release-evidence-guard-tests.txt"
  fi
  echo "- dist/release-evidence/release-evidence-check.txt"
  echo
  echo "## Required External Checks"
  if [[ "$signature" != "Developer ID Application" ]]; then
    echo "- Unsigned distribution: document Gatekeeper bypass for other Macs."
  fi
  if [[ "$final_zip_verified" != "yes" ]]; then
    echo "- Notarization is optional for the GitHub/DMG distribution path; use it only for frictionless public download."
  fi
  if [[ "$normal_session_bundle_open_verified" != "yes" ]]; then
    echo "- Normal-session bundle-open verification is recommended before sharing."
  fi
  if [[ "$human_visual_qa_accepted" != "yes" ]]; then
    echo "- Human visual pass for all modes and intensity levels is recommended before sharing."
  fi
  if [[ "$unsigned_memory_checked" != "yes" ]]; then
    echo "- Normal-session leaks memory check is recommended before sharing."
  fi
  echo "- DMG creation in a normal macOS session before the strict share gate."
} >"$TEMP_MANIFEST"

{
  echo "$zip_sha  dist/Hazakura Wallpaper.zip"
  if [[ -n "$dmg_sha" ]]; then
    echo "$dmg_sha  dist/Hazakura Wallpaper.dmg"
  fi
  for preview in "$PREVIEW_DIR"/*.png; do
    if [[ -f "$preview" ]]; then
      preview_name="$(basename "$preview")"
      preview_sha="$(shasum -a 256 "$preview" | awk '{print $1}')"
      echo "$preview_sha  dist/previews/$preview_name"
    fi
  done
} >"$TEMP_SHA"

mv "$TEMP_MANIFEST" "$MANIFEST_PATH"
mv "$TEMP_SHA" "$SHA_PATH"

echo "$MANIFEST_PATH"
