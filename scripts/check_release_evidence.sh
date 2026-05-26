#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"
RELEASE_QA_DOC="$ROOT_DIR/docs/RELEASE_QA.md"
SHA_PATH="$ROOT_DIR/dist/SHA256SUMS"
MANIFEST_PATH="$ROOT_DIR/dist/release-evidence/RELEASE_MANIFEST.md"
PREVIEW_ARTIFACTS="$ROOT_DIR/dist/release-evidence/preview-artifacts.txt"
PREVIEW_DETERMINISM="$ROOT_DIR/dist/release-evidence/preview-determinism.txt"
ZIP_CONTENTS="$ROOT_DIR/dist/release-evidence/zip-contents.txt"
ICON_INFO="$ROOT_DIR/dist/release-evidence/icon-info.txt"
SIGNING_INFO="$ROOT_DIR/dist/release-evidence/codesign-info.txt"
ENTITLEMENTS="$ROOT_DIR/dist/release-evidence/entitlements.plist"
SPCTL_INFO="$ROOT_DIR/dist/release-evidence/spctl.txt"
MACHO_INFO="$ROOT_DIR/dist/release-evidence/macho-build.txt"
DMG_INFO="$ROOT_DIR/dist/release-evidence/dmg-info.txt"
RENDERER_MEMORY_SMOKE="$ROOT_DIR/dist/release-evidence/renderer-memory-smoke.txt"
GUARD_TESTS_LOG="$ROOT_DIR/dist/release-evidence/release-evidence-guard-tests.txt"
REPORT_PATH="$ROOT_DIR/dist/release-evidence/release-evidence-check.txt"
FINAL_ZIP_VERIFY_LOG="$ROOT_DIR/dist/release-evidence/final-zip-verify.log"
NOTARY_LOG="$ROOT_DIR/dist/release-evidence/notarytool-submit.log"
STAPLER_LOG="$ROOT_DIR/dist/release-evidence/stapler.log"
SPCTL_AFTER_NOTARIZATION="$ROOT_DIR/dist/release-evidence/spctl-after-notarization.txt"
BUNDLE_OPEN_LOG="$ROOT_DIR/dist/release-evidence/bundle-open-verified.txt"
VISUAL_QA_LOG="$ROOT_DIR/dist/release-evidence/visual-qa-accepted.txt"
UNSIGNED_BUNDLE_OPEN_LOG="$ROOT_DIR/dist/release-evidence/unsigned-bundle-open-verified.txt"
UNSIGNED_VISUAL_QA_LOG="$ROOT_DIR/dist/release-evidence/unsigned-visual-qa-accepted.txt"
UNSIGNED_MEMORY_LOG="$ROOT_DIR/dist/release-evidence/unsigned-memory-check.txt"
STALE_TOP_LEVEL_SIGNING_INFO="$ROOT_DIR/dist/codesign-info.txt"
STALE_TOP_LEVEL_ENTITLEMENTS="$ROOT_DIR/dist/codesign-entitlements.plist"
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
mkdir -p "$ROOT_DIR/dist/release-evidence"
TEMP_REPORT="$(mktemp "$ROOT_DIR/dist/release-evidence/release-evidence-check.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"' EXIT

for stale_path in "$STALE_TOP_LEVEL_SIGNING_INFO" "$STALE_TOP_LEVEL_ENTITLEMENTS"; do
  if [[ -e "$stale_path" ]]; then
    echo "Stale top-level signing evidence exists outside dist/release-evidence: $stale_path" >&2
    exit 1
  fi
done

for stale_path in "${STALE_NOTARIZATION_ATTEMPT_EVIDENCE[@]}"; do
  if [[ -e "$stale_path" ]]; then
    echo "Stale notarization attempt evidence exists outside canonical final evidence: $stale_path" >&2
    exit 1
  fi
done

for path in "$ZIP_PATH" "$SHA_PATH" "$MANIFEST_PATH" "$PREVIEW_ARTIFACTS" "$PREVIEW_DETERMINISM" "$ZIP_CONTENTS" "$ICON_INFO" "$SIGNING_INFO" "$SPCTL_INFO" "$MACHO_INFO" "$RENDERER_MEMORY_SMOKE"; do
  if [[ ! -s "$path" ]]; then
    echo "Missing release evidence: $path" >&2
    exit 1
  fi
done

if [[ ! -e "$ENTITLEMENTS" ]]; then
  echo "Missing release evidence: $ENTITLEMENTS" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

"$ROOT_DIR/scripts/check_zip_contents.sh" "$ZIP_PATH" >/dev/null

manifest_bundle_id="$(awk -F': ' '/^- Bundle ID:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_version="$(awk -F': ' '/^- Version:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_build="$(awk -F': ' '/^- Build:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_mach_o_architectures="$(awk -F': ' '/^- Mach-O architectures:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_cdhash="$(awk -F': ' '/^- CDHash:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_signature="$(awk -F': ' '/^- Code signature:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_entitlements="$(awk -F': ' '/^- Entitlements:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_zip_sha="$(awk -F': ' '/^- ZIP SHA-256:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_dmg_sha="$(awk -F': ' '/^- DMG SHA-256:/ { print $2; exit }' "$MANIFEST_PATH")"
manifest_final_zip_verified="$(awk -F': ' '/^- Final notarized ZIP verified:/ { print $2; exit }' "$MANIFEST_PATH")"
actual_zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
actual_dmg_sha=""
if [[ -f "$DMG_PATH" ]]; then
  actual_dmg_sha="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"
fi
release_qa_sha=""
if [[ -f "$RELEASE_QA_DOC" ]]; then
  release_qa_sha="$(shasum -a 256 "$RELEASE_QA_DOC" | awk '{ print $1 }')"
fi
actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
actual_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"
actual_mach_o_architectures="$(lipo -archs "$APP_PATH/Contents/MacOS/HazakuraWallpaper")"
actual_signature="ad-hoc"
if codesign -dvvv "$APP_PATH" 2>&1 | grep -q "Authority=Developer ID Application"; then
  actual_signature="Developer ID Application"
fi

if [[ -z "$manifest_zip_sha" ]]; then
  echo "Could not read ZIP SHA from manifest." >&2
  exit 1
fi

if [[ -z "$manifest_bundle_id" || -z "$manifest_version" || -z "$manifest_build" || -z "$manifest_mach_o_architectures" || -z "$manifest_cdhash" || -z "$manifest_signature" || -z "$manifest_entitlements" || -z "$actual_cdhash" || -z "$actual_mach_o_architectures" ]]; then
  echo "Could not read app identity, signature, or CDHash from manifest or app bundle." >&2
  exit 1
fi

actual_entitlements="present"
if [[ -z "$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)" ]]; then
  actual_entitlements="none"
fi

if [[ "$manifest_final_zip_verified" != "yes" && "$manifest_final_zip_verified" != "no" ]]; then
  echo "Manifest Final notarized ZIP verified must be 'yes' or 'no', got '$manifest_final_zip_verified'." >&2
  exit 1
fi

manifest_lists_evidence() {
  local evidence_path="$1"
  grep -Fq -- "- dist/release-evidence/$evidence_path" "$MANIFEST_PATH"
}

read_unique_checksum_field() {
  local artifact_path="$1"

  awk -v artifact_path="$artifact_path" '
    substr($0, 67) == artifact_path {
      count += 1
      if (count == 1) {
        value = $1
      }
    }
    END {
      if (count != 1) {
        exit 1
      }
      print value
    }
  ' "$SHA_PATH"
}

read_unique_preview_determinism_sha() {
  local preview_path="$1"

  awk -F': ' -v preview_path="$preview_path" '
    $1 == "- " preview_path {
      count += 1
      if (count == 1) {
        value = $2
      }
    }
    END {
      if (count != 1) {
        exit 1
      }
      print value
    }
  ' "$PREVIEW_DETERMINISM"
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
    echo "$description evidence must contain exactly one field: $label" >&2
    exit 1
  fi

  if [[ "$value" =~ [[:cntrl:]] || ! "$value" =~ [^[:space:]] ]]; then
    echo "$description evidence has an empty or multi-line field: $label" >&2
    exit 1
  fi
}

require_utc_timestamp_evidence_field() {
  local path="$1"
  local label="$2"
  local description="$3"
  local value

  if ! value="$(read_unique_evidence_field "$path" "$label")"; then
    echo "$description evidence must contain exactly one field: $label" >&2
    exit 1
  fi

  if [[ ! "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "$description evidence has an invalid UTC timestamp field: $label" >&2
    exit 1
  fi
}

require_sha256_evidence_field() {
  local path="$1"
  local label="$2"
  local description="$3"
  local value

  if ! value="$(read_unique_evidence_field "$path" "$label")"; then
    echo "$description evidence must contain exactly one field: $label" >&2
    exit 1
  fi

  if [[ ! "$value" =~ ^[0-9a-f]{64}$ ]]; then
    echo "$description evidence has an invalid SHA-256 field: $label" >&2
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
    echo "$description evidence must contain exactly one field: $label" >&2
    exit 1
  fi

  if [[ "$value" != "$expected" ]]; then
    echo "$description evidence has an unexpected field value for $label." >&2
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
    echo "$description evidence must contain exactly one matching line for: $pattern" >&2
    exit 1
  fi
}

if ! sha_file_zip_sha="$(read_unique_checksum_field "dist/Hazakura Wallpaper.zip")"; then
  echo "SHA256SUMS must contain exactly one checksum for dist/Hazakura Wallpaper.zip." >&2
  exit 1
fi
sha_file_dmg_sha=""
if [[ -f "$DMG_PATH" ]] || awk 'substr($0, 67) == "dist/Hazakura Wallpaper.dmg" { found = 1 } END { exit found ? 0 : 1 }' "$SHA_PATH"; then
  if ! sha_file_dmg_sha="$(read_unique_checksum_field "dist/Hazakura Wallpaper.dmg")"; then
    echo "SHA256SUMS must contain exactly one checksum for dist/Hazakura Wallpaper.dmg when DMG evidence is present." >&2
    exit 1
  fi
fi

if [[ "$manifest_bundle_id" != "$actual_bundle_id" ||
  "$manifest_version" != "$actual_version" ||
  "$manifest_build" != "$actual_build" ||
  "$manifest_mach_o_architectures" != "$actual_mach_o_architectures" ||
  "$manifest_cdhash" != "$actual_cdhash" ||
  "$manifest_signature" != "$actual_signature" ||
  "$manifest_entitlements" != "$actual_entitlements" ]]; then
  echo "App identity, architectures, signature, entitlements, or CDHash mismatch between manifest and current app bundle." >&2
  echo "manifest Bundle ID/Version/Build/Architectures/Signature/Entitlements/CDHash: $manifest_bundle_id / $manifest_version / $manifest_build / $manifest_mach_o_architectures / $manifest_signature / $manifest_entitlements / $manifest_cdhash" >&2
  echo "actual   Bundle ID/Version/Build/Architectures/Signature/Entitlements/CDHash: $actual_bundle_id / $actual_version / $actual_build / $actual_mach_o_architectures / $actual_signature / $actual_entitlements / $actual_cdhash" >&2
  exit 1
fi

if [[ " $actual_mach_o_architectures " != *" arm64 "* ||
  " $actual_mach_o_architectures " != *" x86_64 "* ]]; then
  echo "Current app must be universal for public distribution; expected arm64 and x86_64, got '$actual_mach_o_architectures'." >&2
  exit 1
fi

if [[ "$actual_entitlements" != "none" ]]; then
  echo "Current app bundle contains unexpected entitlements." >&2
  exit 1
fi

if [[ "$manifest_zip_sha" != "$sha_file_zip_sha" || "$manifest_zip_sha" != "$actual_zip_sha" ]]; then
  echo "ZIP SHA mismatch between manifest, SHA256SUMS, and actual ZIP." >&2
  echo "manifest: $manifest_zip_sha" >&2
  echo "SHA256SUMS: $sha_file_zip_sha" >&2
  echo "actual: $actual_zip_sha" >&2
  exit 1
fi

if [[ -n "$actual_dmg_sha" ]]; then
  if [[ -z "$manifest_dmg_sha" || -z "$sha_file_dmg_sha" ]]; then
    echo "DMG exists, but manifest or SHA256SUMS does not record its SHA." >&2
    exit 1
  fi

  if [[ "$manifest_dmg_sha" != "$sha_file_dmg_sha" || "$manifest_dmg_sha" != "$actual_dmg_sha" ]]; then
    echo "DMG SHA mismatch between manifest, SHA256SUMS, and actual DMG." >&2
    echo "manifest: $manifest_dmg_sha" >&2
    echo "SHA256SUMS: $sha_file_dmg_sha" >&2
    echo "actual: $actual_dmg_sha" >&2
    exit 1
  fi

  if [[ ! -s "$DMG_INFO" ]]; then
    echo "DMG exists, but DMG evidence is missing: $DMG_INFO" >&2
    exit 1
  fi

  if ! manifest_lists_evidence "dmg-info.txt"; then
    echo "DMG evidence exists, but the manifest does not list it." >&2
    exit 1
  fi
else
  manifest_lists_dmg_info=0
  if manifest_lists_evidence "dmg-info.txt"; then
    manifest_lists_dmg_info=1
  fi

  if [[ -n "$manifest_dmg_sha" || -n "$sha_file_dmg_sha" || -e "$DMG_INFO" || "$manifest_lists_dmg_info" == "1" ]]; then
    echo "DMG evidence or checksum exists, but dist/Hazakura Wallpaper.dmg is missing." >&2
    exit 1
  fi
fi

shasum -a 256 -c "$SHA_PATH" >/dev/null

if [[ "$manifest_final_zip_verified" == "yes" ]]; then
  for evidence_path in \
    "notarytool-submit.log" \
    "stapler.log" \
    "spctl-after-notarization.txt" \
    "final-zip-verify.log"; do
    if ! manifest_lists_evidence "$evidence_path"; then
      echo "Manifest says final ZIP is verified, but is missing final notarization evidence listing: dist/release-evidence/$evidence_path" >&2
      exit 1
    fi
  done

  if [[ "$actual_signature" != "Developer ID Application" ]]; then
    echo "Manifest says final ZIP is verified, but the current app is not signed with Developer ID Application." >&2
    exit 1
  fi

  if [[ ! -s "$FINAL_ZIP_VERIFY_LOG" ]]; then
    echo "Manifest says final ZIP is verified, but final ZIP verification log is missing." >&2
    exit 1
  fi

  require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Verified archive" "dist/Hazakura Wallpaper.zip" "Final ZIP verification"
  require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Final ZIP SHA-256" "$actual_zip_sha" "Final ZIP verification"
  require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Bundle ID" "$actual_bundle_id" "Final ZIP verification"
  require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Version" "$actual_version" "Final ZIP verification"
  require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Build" "$actual_build" "Final ZIP verification"
  require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Architectures" "$actual_mach_o_architectures" "Final ZIP verification"
  require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "CDHash" "$actual_cdhash" "Final ZIP verification"

  require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^Final notarized ZIP verification passed\.$' "Final ZIP verification"
  require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^[^:]+:[[:space:]]+valid on disk$' "Final ZIP verification"
  require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^[^:]+:[[:space:]]+satisfies its Designated Requirement$' "Final ZIP verification"
  require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^The (staple and )?validate action worked![[:space:]]*$' "Final ZIP verification"
  require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '^[^:]+:[[:space:]]+accepted[[:space:]]*$' "Final ZIP verification"

  for path in "$NOTARY_LOG" "$STAPLER_LOG" "$SPCTL_AFTER_NOTARIZATION"; do
    if [[ ! -s "$path" ]]; then
      echo "Manifest says final ZIP is verified, but notarization evidence is missing: $path" >&2
      exit 1
    fi
  done

  require_exact_evidence_field "$NOTARY_LOG" "Submitted archive" "dist/Hazakura Wallpaper.zip" "Notary submission"
  require_sha256_evidence_field "$NOTARY_LOG" "Submitted ZIP SHA-256" "Notary submission"
  require_utc_timestamp_evidence_field "$NOTARY_LOG" "Submitted at" "Notary submission"
  require_exact_evidence_field "$NOTARY_LOG" "Submitted bundle ID" "$actual_bundle_id" "Notary submission"
  require_exact_evidence_field "$NOTARY_LOG" "Submitted version" "$actual_version" "Notary submission"
  require_exact_evidence_field "$NOTARY_LOG" "Submitted build" "$actual_build" "Notary submission"
  require_exact_evidence_field "$NOTARY_LOG" "Submitted architectures" "$actual_mach_o_architectures" "Notary submission"
  require_exact_evidence_field "$NOTARY_LOG" "Submitted app CDHash" "$actual_cdhash" "Notary submission"
  require_exact_evidence_field "$NOTARY_LOG" "Submitted command" "xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>" "Notary submission"

  require_unique_matching_line "$NOTARY_LOG" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$' "Notarization"

  require_unique_matching_line "$STAPLER_LOG" '^The (staple and )?validate action worked![[:space:]]*$' "Stapler"

  require_unique_matching_line "$SPCTL_AFTER_NOTARIZATION" '^[^:]+:[[:space:]]+accepted[[:space:]]*$' "Gatekeeper"
else
  for evidence_path in \
    "notarytool-submit.log" \
    "stapler.log" \
    "spctl-after-notarization.txt" \
    "final-zip-verify.log" \
    "bundle-open-verified.txt" \
    "visual-qa-accepted.txt"; do
    if manifest_lists_evidence "$evidence_path"; then
      echo "Manifest lists final-only evidence before final notarized ZIP verification is complete: dist/release-evidence/$evidence_path" >&2
      exit 1
    fi

    if [[ -e "$ROOT_DIR/dist/release-evidence/$evidence_path" ]]; then
      echo "Final-only evidence exists before final notarized ZIP verification is complete: dist/release-evidence/$evidence_path" >&2
      exit 1
    fi
  done
fi

if [[ -e "$BUNDLE_OPEN_LOG" ]]; then
  if [[ "$manifest_final_zip_verified" != "yes" ]]; then
    echo "Bundle-open verification evidence exists before final notarized ZIP verification is complete." >&2
    exit 1
  fi

  if [[ ! -s "$BUNDLE_OPEN_LOG" ]]; then
    echo "Bundle-open verification evidence does not match the current build." >&2
    exit 1
  fi

  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Bundle open verified" "yes" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Bundle ID" "$actual_bundle_id" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Version" "$actual_version" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Build" "$actual_build" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Architectures" "$actual_mach_o_architectures" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "CDHash" "$actual_cdhash" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "ZIP SHA-256" "$actual_zip_sha" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified app" "dist/Hazakura Wallpaper.app" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified process match" "anchored executable path" "Bundle-open verification"
  require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified command" "./scripts/record_bundle_open_verification.sh --operator <operator>" "Bundle-open verification"
  require_utc_timestamp_evidence_field "$BUNDLE_OPEN_LOG" "Verified at" "Bundle-open verification"
  require_single_line_nonblank_evidence_field "$BUNDLE_OPEN_LOG" "Operator" "Bundle-open verification"

  if ! manifest_lists_evidence "bundle-open-verified.txt"; then
    echo "Bundle-open verification evidence is valid, but the manifest does not list it." >&2
    exit 1
  fi
fi

if [[ -e "$VISUAL_QA_LOG" ]]; then
  if [[ "$manifest_final_zip_verified" != "yes" ]]; then
    echo "Visual QA acceptance evidence exists before final notarized ZIP verification is complete." >&2
    exit 1
  fi

  if [[ -z "$release_qa_sha" ]]; then
    echo "Visual QA acceptance evidence exists, but docs/RELEASE_QA.md is missing." >&2
    exit 1
  fi

  if [[ ! -s "$VISUAL_QA_LOG" ]]; then
    echo "Visual QA acceptance evidence does not match the current build." >&2
    exit 1
  fi

  require_exact_evidence_field "$VISUAL_QA_LOG" "Visual QA accepted" "yes" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Bundle ID" "$actual_bundle_id" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Version" "$actual_version" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Build" "$actual_build" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Architectures" "$actual_mach_o_architectures" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "CDHash" "$actual_cdhash" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "ZIP SHA-256" "$actual_zip_sha" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist" "docs/RELEASE_QA.md" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist completed" "yes" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist SHA-256" "$release_qa_sha" "Visual QA acceptance"
  require_exact_evidence_field "$VISUAL_QA_LOG" "Accepted command" "./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>" "Visual QA acceptance"
  require_utc_timestamp_evidence_field "$VISUAL_QA_LOG" "Accepted at" "Visual QA acceptance"
  require_single_line_nonblank_evidence_field "$VISUAL_QA_LOG" "Reviewer" "Visual QA acceptance"

  if ! manifest_lists_evidence "visual-qa-accepted.txt"; then
    echo "Visual QA acceptance evidence is valid, but the manifest does not list it." >&2
    exit 1
  fi
fi

if [[ -e "$UNSIGNED_BUNDLE_OPEN_LOG" ]]; then
  if [[ ! -s "$UNSIGNED_BUNDLE_OPEN_LOG" ]]; then
    echo "Unsigned bundle-open verification evidence is empty." >&2
    exit 1
  fi

  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Unsigned bundle open verified" "yes" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Bundle ID" "$actual_bundle_id" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Version" "$actual_version" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Build" "$actual_build" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Architectures" "$actual_mach_o_architectures" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "CDHash" "$actual_cdhash" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "ZIP SHA-256" "$actual_zip_sha" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Verified app" "dist/Hazakura Wallpaper.app" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Verified executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Verified process match" "anchored executable path" "Unsigned bundle-open verification"
  require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Verified command" "./scripts/record_unsigned_bundle_open_verification.sh --operator <operator>" "Unsigned bundle-open verification"
  require_utc_timestamp_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Verified at" "Unsigned bundle-open verification"
  require_single_line_nonblank_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Operator" "Unsigned bundle-open verification"

  if ! manifest_lists_evidence "unsigned-bundle-open-verified.txt"; then
    echo "Unsigned bundle-open verification evidence is valid, but the manifest does not list it." >&2
    exit 1
  fi
fi

if [[ -e "$UNSIGNED_VISUAL_QA_LOG" ]]; then
  if [[ -z "$release_qa_sha" ]]; then
    echo "Unsigned visual QA acceptance evidence exists, but docs/RELEASE_QA.md is missing." >&2
    exit 1
  fi

  if [[ ! -s "$UNSIGNED_VISUAL_QA_LOG" ]]; then
    echo "Unsigned visual QA acceptance evidence is empty." >&2
    exit 1
  fi

  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Unsigned visual QA accepted" "yes" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Bundle ID" "$actual_bundle_id" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Version" "$actual_version" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Build" "$actual_build" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Architectures" "$actual_mach_o_architectures" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "CDHash" "$actual_cdhash" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "ZIP SHA-256" "$actual_zip_sha" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Checklist" "docs/RELEASE_QA.md" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Checklist completed" "yes" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Checklist SHA-256" "$release_qa_sha" "Unsigned visual QA acceptance"
  require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Accepted command" "./scripts/record_unsigned_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>" "Unsigned visual QA acceptance"
  require_utc_timestamp_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Accepted at" "Unsigned visual QA acceptance"
  require_single_line_nonblank_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Reviewer" "Unsigned visual QA acceptance"

  if ! manifest_lists_evidence "unsigned-visual-qa-accepted.txt"; then
    echo "Unsigned visual QA acceptance evidence is valid, but the manifest does not list it." >&2
    exit 1
  fi
fi

if [[ -e "$UNSIGNED_MEMORY_LOG" ]]; then
  if [[ ! -s "$UNSIGNED_MEMORY_LOG" ]]; then
    echo "Unsigned memory check evidence is empty." >&2
    exit 1
  fi

  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Unsigned memory check passed" "yes" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Bundle ID" "$actual_bundle_id" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Version" "$actual_version" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Build" "$actual_build" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Architectures" "$actual_mach_o_architectures" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "CDHash" "$actual_cdhash" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "ZIP SHA-256" "$actual_zip_sha" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Checked executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Checked command" "./scripts/record_unsigned_memory_check.sh --operator <operator>" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Tool" "leaks --atExit" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "MallocStackLogging" "enabled" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Smoke exit after seconds" "1" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Leaks exit code" "0" "Unsigned memory check"
  require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Leaks result" "no leaks reported by leaks --atExit" "Unsigned memory check"
  require_utc_timestamp_evidence_field "$UNSIGNED_MEMORY_LOG" "Checked at" "Unsigned memory check"
  require_single_line_nonblank_evidence_field "$UNSIGNED_MEMORY_LOG" "Operator" "Unsigned memory check"

  if ! manifest_lists_evidence "unsigned-memory-check.txt"; then
    echo "Unsigned memory check evidence is valid, but the manifest does not list it." >&2
    exit 1
  fi
fi

if [[ -e "$GUARD_TESTS_LOG" ]]; then
  if [[ ! -s "$GUARD_TESTS_LOG" ]]; then
    echo "Release evidence guard test evidence is empty." >&2
    exit 1
  fi

  require_exact_evidence_field "$GUARD_TESTS_LOG" "Release evidence guard tests passed" "yes" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "Bundle ID" "$actual_bundle_id" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "Version" "$actual_version" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "Build" "$actual_build" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "Architectures" "$actual_mach_o_architectures" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "CDHash" "$actual_cdhash" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "ZIP SHA-256" "$actual_zip_sha" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "Checked command" "./scripts/test_release_evidence_guards.sh" "Release evidence guard tests"
  require_exact_evidence_field "$GUARD_TESTS_LOG" "Duplicate preview fixture rejection" "passed" "Release evidence guard tests"
  require_utc_timestamp_evidence_field "$GUARD_TESTS_LOG" "Checked at" "Release evidence guard tests"

  if ! manifest_lists_evidence "release-evidence-guard-tests.txt"; then
    echo "Release evidence guard test evidence is valid, but the manifest does not list it." >&2
    exit 1
  fi
fi

required_manifest_lines=(
  "- Minimum macOS: 14.0"
  "- Mach-O architectures: "
  "- Mach-O minimum macOS: 14.0"
  "- Mach-O SDK: "
  "- Code signature: "
  "- Entitlements: none"
  "- Final notarized ZIP verified: "
  "- dist/release-evidence/preview-artifacts.txt"
  "- dist/release-evidence/preview-determinism.txt"
  "- dist/release-evidence/zip-contents.txt"
  "- dist/release-evidence/icon-info.txt"
  "- dist/release-evidence/codesign-info.txt"
  "- dist/release-evidence/entitlements.plist"
  "- dist/release-evidence/spctl.txt"
  "- dist/release-evidence/macho-build.txt"
  "- dist/release-evidence/renderer-memory-smoke.txt"
  "- dist/release-evidence/release-evidence-check.txt"
)

for line in "${required_manifest_lines[@]}"; do
  if ! grep -Fq -- "$line" "$MANIFEST_PATH"; then
    echo "Release manifest missing required evidence line containing: $line" >&2
    exit 1
  fi
done

require_positive_integer_evidence_field() {
  local path="$1"
  local label="$2"
  local description="$3"
  local value

  if ! value="$(read_unique_evidence_field "$path" "$label")"; then
    echo "$description evidence must contain exactly one field: $label" >&2
    exit 1
  fi

  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$description evidence has a non-positive integer field: $label" >&2
    exit 1
  fi

  echo "$value"
}

require_exact_evidence_field "$RENDERER_MEMORY_SMOKE" "Renderer memory smoke passed" "yes" "Renderer memory smoke"
require_exact_evidence_field "$RENDERER_MEMORY_SMOKE" "Rendered modes" "sakura,magic,spark,hazakura,breeze,firefly" "Renderer memory smoke"
renderer_memory_frames="$(require_positive_integer_evidence_field "$RENDERER_MEMORY_SMOKE" "Frames" "Renderer memory smoke")"
renderer_memory_visible_samples="$(require_positive_integer_evidence_field "$RENDERER_MEMORY_SMOKE" "Visible pixel samples" "Renderer memory smoke")"
renderer_memory_max_rss="$(require_positive_integer_evidence_field "$RENDERER_MEMORY_SMOKE" "Max resident set size bytes" "Renderer memory smoke")"
renderer_memory_max_rss_limit="$(require_positive_integer_evidence_field "$RENDERER_MEMORY_SMOKE" "Max resident set size limit bytes" "Renderer memory smoke")"
require_unique_matching_line "$RENDERER_MEMORY_SMOKE" '^Canvas: [1-9][0-9]*x[1-9][0-9]*$' "Renderer memory smoke"
if (( renderer_memory_frames < 60 )); then
  echo "Renderer memory smoke must render at least 60 frames, got $renderer_memory_frames." >&2
  exit 1
fi
if (( renderer_memory_visible_samples <= 0 )); then
  echo "Renderer memory smoke must record visible pixels." >&2
  exit 1
fi
if (( renderer_memory_max_rss > renderer_memory_max_rss_limit )); then
  echo "Renderer memory smoke exceeded its resident memory limit." >&2
  exit 1
fi

required_signing_info_lines=(
  "Identifier=$actual_bundle_id"
  "CDHash=$actual_cdhash"
  "flags="
  "runtime"
)

for line in "${required_signing_info_lines[@]}"; do
  if ! grep -Fq -- "$line" "$SIGNING_INFO"; then
    echo "Signing evidence missing required line containing: $line" >&2
    exit 1
  fi
done

if [[ "$actual_signature" == "Developer ID Application" ]]; then
  if ! grep -Fq "Authority=Developer ID Application" "$SIGNING_INFO"; then
    echo "Signing evidence does not show Developer ID Application authority." >&2
    exit 1
  fi
else
  if ! grep -Fq "Signature=adhoc" "$SIGNING_INFO"; then
    echo "Signing evidence does not show ad-hoc signature." >&2
    exit 1
  fi
fi

if [[ -s "$ENTITLEMENTS" ]]; then
  echo "Entitlements evidence must be empty because the public app has no entitlements." >&2
  exit 1
fi

if ! grep -Fq "$APP_PATH:" "$SPCTL_INFO"; then
  echo "Gatekeeper evidence does not refer to the current app path: $APP_PATH" >&2
  exit 1
fi

if ! grep -Eiq ':[[:space:]]+(accepted|rejected|internal error)' "$SPCTL_INFO"; then
  echo "Gatekeeper evidence does not contain an assessment result." >&2
  exit 1
fi

required_macho_info_lines=(
  "Architectures: "
  "platform MACOS"
  "minos 14.0"
  "sdk "
)

for line in "${required_macho_info_lines[@]}"; do
  if ! grep -Fq -- "$line" "$MACHO_INFO"; then
    echo "Mach-O evidence missing required line containing: $line" >&2
    exit 1
  fi
done

if ! grep -Fq "arm64" "$MACHO_INFO" || ! grep -Fq "x86_64" "$MACHO_INFO"; then
  echo "Mach-O evidence must include both arm64 and x86_64 architectures." >&2
  exit 1
fi

required_zip_content_lines=(
  "ZIP content checks passed."
  "ZIP SHA-256: $actual_zip_sha"
  "Current app CDHash: $actual_cdhash"
  "Extracted app CDHash: $actual_cdhash"
  "Extracted app matches current dist app."
  "No __MACOSX, AppleDouble, or .DS_Store entries found."
  "No entries outside Hazakura Wallpaper.app found."
  "No source, script, docs, dependency, Xcode project, or legacy Tauri entries found."
  "No development metadata, editor, local environment, debug-symbol, or build-output entries found."
  "No unexpected app bundle entries found."
  "Hazakura Wallpaper.app/Contents/Info.plist"
  "Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper"
  "Hazakura Wallpaper.app/Contents/Resources/icon.icns"
  "Hazakura Wallpaper.app/Contents/Resources/icon.png"
)

for line in "${required_zip_content_lines[@]}"; do
  if ! grep -Fq -- "$line" "$ZIP_CONTENTS"; then
    echo "ZIP content evidence missing required line containing: $line" >&2
    exit 1
  fi
done

required_icon_info_lines=(
  "Icon checks passed."
  "Version: $actual_version"
  "Build: $actual_build"
  "CDHash: $actual_cdhash"
  "App icon: Contents/Resources/icon.icns"
  "Mac OS X icon"
  "Status icon: Contents/Resources/icon.png"
  "PNG image data"
  "Status icon dimensions: 1024x1024"
)

for line in "${required_icon_info_lines[@]}"; do
  if ! grep -Fq -- "$line" "$ICON_INFO"; then
    echo "Icon evidence missing required line containing: $line" >&2
    exit 1
  fi
done

required_preview_lines=(
  "Preview artifact checks passed."
  "dist/previews/sakura.png: 960x540"
  "dist/previews/magic.png: 960x540"
  "dist/previews/spark.png: 960x540"
  "dist/previews/hazakura.png: 960x540"
  "dist/previews/breeze.png: 960x540"
  "dist/previews/firefly.png: 960x540"
  "dist/previews/night-sakura.png: 960x540"
  "dist/previews/qa-matrix-day.png: 1440x1824"
  "dist/previews/qa-matrix-night.png: 1440x1824"
)

for line in "${required_preview_lines[@]}"; do
  if ! grep -Fq -- "$line" "$PREVIEW_ARTIFACTS"; then
    echo "Preview evidence missing required line containing: $line" >&2
    exit 1
  fi
done

require_preview_content_line() {
  local preview_line="$1"
  if ! grep -F -- "$preview_line" "$PREVIEW_ARTIFACTS" | grep -Fq -- "; nonzero color channels: "; then
    echo "Preview content evidence missing required line containing visible alpha pixels and nonzero color channels: $preview_line" >&2
    exit 1
  fi
}

require_preview_content_line "dist/previews/sakura.png: 960x540; visible alpha pixels: "
require_preview_content_line "dist/previews/magic.png: 960x540; visible alpha pixels: "
require_preview_content_line "dist/previews/spark.png: 960x540; visible alpha pixels: "
require_preview_content_line "dist/previews/hazakura.png: 960x540; visible alpha pixels: "
require_preview_content_line "dist/previews/breeze.png: 960x540; visible alpha pixels: "
require_preview_content_line "dist/previews/firefly.png: 960x540; visible alpha pixels: "
require_preview_content_line "dist/previews/night-sakura.png: 960x540; visible alpha pixels: "
require_preview_content_line "dist/previews/qa-matrix-day.png: 1440x1824; visible alpha pixels: "
require_preview_content_line "dist/previews/qa-matrix-night.png: 1440x1824; visible alpha pixels: "

if ! grep -Fq -- "Preview visual diversity checks passed." "$PREVIEW_ARTIFACTS"; then
  echo "Preview artifact evidence is missing visual diversity checks." >&2
  exit 1
fi

required_preview_determinism_lines=(
  "Preview determinism checks passed."
  "dist/previews/sakura.png: "
  "dist/previews/magic.png: "
  "dist/previews/spark.png: "
  "dist/previews/hazakura.png: "
  "dist/previews/breeze.png: "
  "dist/previews/firefly.png: "
  "dist/previews/night-sakura.png: "
  "dist/previews/qa-matrix-day.png: "
  "dist/previews/qa-matrix-night.png: "
)

for line in "${required_preview_determinism_lines[@]}"; do
  if ! grep -Fq -- "$line" "$PREVIEW_DETERMINISM"; then
    echo "Preview determinism evidence missing required line containing: $line" >&2
    exit 1
  fi
done

for preview in sakura magic spark hazakura breeze firefly night-sakura qa-matrix-day qa-matrix-night; do
  preview_path="dist/previews/$preview.png"
  if ! sha_file_preview_sha="$(read_unique_checksum_field "$preview_path")"; then
    echo "SHA256SUMS must contain exactly one checksum for $preview_path." >&2
    exit 1
  fi
  if ! determinism_preview_sha="$(read_unique_preview_determinism_sha "$preview_path")"; then
    echo "Preview determinism evidence must contain exactly one checksum for $preview_path." >&2
    exit 1
  fi

  if [[ ! "$determinism_preview_sha" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Preview determinism evidence contains an invalid SHA-256 for $preview_path." >&2
    exit 1
  fi

  if [[ "$sha_file_preview_sha" != "$determinism_preview_sha" ]]; then
    echo "Preview determinism evidence does not match SHA256SUMS for $preview_path." >&2
    echo "SHA256SUMS: $sha_file_preview_sha" >&2
    echo "determinism: $determinism_preview_sha" >&2
    exit 1
  fi
done

if [[ -n "$actual_dmg_sha" ]]; then
  require_unique_matching_line "$DMG_INFO" '^DMG checks passed\.$' "DMG"
  require_exact_evidence_field "$DMG_INFO" "DMG" "dist/Hazakura Wallpaper.dmg" "DMG"
  require_exact_evidence_field "$DMG_INFO" "DMG SHA-256" "$actual_dmg_sha" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Volume name" "Hazakura Wallpaper" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Format" "UDZO" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Source app" "dist/Hazakura Wallpaper.app" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Bundle ID" "$actual_bundle_id" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Version" "$actual_version" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Build" "$actual_build" "DMG"
  require_exact_evidence_field "$DMG_INFO" "CDHash" "$actual_cdhash" "DMG"
  require_exact_evidence_field "$DMG_INFO" "hdiutil verify" "passed" "DMG"
  require_exact_evidence_field "$DMG_INFO" "hdiutil attach" "passed" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Mounted app" "Hazakura Wallpaper.app" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Mounted bundle ID" "$actual_bundle_id" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Mounted version" "$actual_version" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Mounted build" "$actual_build" "DMG"
  require_exact_evidence_field "$DMG_INFO" "Mounted CDHash" "$actual_cdhash" "DMG"
fi

{
  echo "Release evidence checks passed."
  echo "ZIP SHA-256: $actual_zip_sha"
  echo "Code signature: $actual_signature"
  echo "App CDHash: $actual_cdhash"
  echo "Manifest: dist/release-evidence/RELEASE_MANIFEST.md"
  echo "Checksums: dist/SHA256SUMS"
  echo "Preview evidence: dist/release-evidence/preview-artifacts.txt"
  echo "Preview determinism: dist/release-evidence/preview-determinism.txt"
  echo "ZIP contents: dist/release-evidence/zip-contents.txt"
  if [[ -n "$actual_dmg_sha" ]]; then
    echo "DMG: dist/Hazakura Wallpaper.dmg"
    echo "DMG evidence: dist/release-evidence/dmg-info.txt"
  fi
  echo "Icon evidence: dist/release-evidence/icon-info.txt"
  echo "Signing evidence: dist/release-evidence/codesign-info.txt"
  echo "Entitlements evidence: dist/release-evidence/entitlements.plist"
  echo "Gatekeeper evidence: dist/release-evidence/spctl.txt"
  echo "Mach-O evidence: dist/release-evidence/macho-build.txt"
  echo "Renderer memory smoke: dist/release-evidence/renderer-memory-smoke.txt"
  echo "Final notarized ZIP verified: $manifest_final_zip_verified"
  if [[ "$manifest_final_zip_verified" == "yes" ]]; then
    echo "Notarization evidence: dist/release-evidence/notarytool-submit.log"
    echo "Stapler evidence: dist/release-evidence/stapler.log"
    echo "Post-notarization Gatekeeper evidence: dist/release-evidence/spctl-after-notarization.txt"
    echo "Final ZIP verification: dist/release-evidence/final-zip-verify.log"
  else
    echo "Final-only evidence: absent"
  fi
  if [[ -s "$BUNDLE_OPEN_LOG" ]]; then
    echo "Bundle open evidence: dist/release-evidence/bundle-open-verified.txt"
  fi
  if [[ -s "$VISUAL_QA_LOG" ]]; then
    echo "Visual QA evidence: dist/release-evidence/visual-qa-accepted.txt"
  fi
  if [[ -s "$UNSIGNED_BUNDLE_OPEN_LOG" ]]; then
    echo "Unsigned bundle open evidence: dist/release-evidence/unsigned-bundle-open-verified.txt"
  fi
  if [[ -s "$UNSIGNED_VISUAL_QA_LOG" ]]; then
    echo "Unsigned visual QA evidence: dist/release-evidence/unsigned-visual-qa-accepted.txt"
  fi
  if [[ -s "$UNSIGNED_MEMORY_LOG" ]]; then
    echo "Unsigned memory evidence: dist/release-evidence/unsigned-memory-check.txt"
  fi
  echo "Publish readiness blockers from release evidence:"
  echo "- none from release evidence; run ./scripts/check_publish_readiness.sh"
  echo "Unsigned distribution notes:"
  if [[ "$actual_signature" != "Developer ID Application" ]]; then
    echo "- Code signature is ad-hoc; Gatekeeper bypass may be required on other Macs."
  fi
  if [[ "$manifest_final_zip_verified" != "yes" ]]; then
    echo "- Notarization is not required for the unsigned GitHub/DMG distribution path."
  fi
  if [[ ! -s "$BUNDLE_OPEN_LOG" && ! -s "$UNSIGNED_BUNDLE_OPEN_LOG" ]]; then
    echo "- Normal-session bundle-open verification remains recommended before sharing."
  fi
  if [[ ! -s "$VISUAL_QA_LOG" && ! -s "$UNSIGNED_VISUAL_QA_LOG" ]]; then
    echo "- Human visual QA remains recommended before sharing."
  fi
  if [[ ! -s "$UNSIGNED_MEMORY_LOG" ]]; then
    echo "- Normal-session leaks memory check remains recommended before sharing."
  fi
} >"$TEMP_REPORT"

mv "$TEMP_REPORT" "$REPORT_PATH"
cat "$REPORT_PATH"
