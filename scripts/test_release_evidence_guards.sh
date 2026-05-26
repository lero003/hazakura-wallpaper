#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
MANIFEST_PATH="$EVIDENCE_DIR/RELEASE_MANIFEST.md"
SHA_PATH="$ROOT_DIR/dist/SHA256SUMS"
PREVIEW_DETERMINISM="$EVIDENCE_DIR/preview-determinism.txt"
NOTES_PATH="$EVIDENCE_DIR/GITHUB_RELEASE_DRAFT.md"
FINAL_ZIP_VERIFY_LOG="$EVIDENCE_DIR/final-zip-verify.log"
NOTARY_LOG="$EVIDENCE_DIR/notarytool-submit.log"
NOTARY_FAILED_LOG="$EVIDENCE_DIR/notarytool-submit.failed.log"
STAPLER_FAILED_LOG="$EVIDENCE_DIR/stapler.failed.log"
SPCTL_AFTER_NOTARIZATION_FAILED="$EVIDENCE_DIR/spctl-after-notarization.failed.txt"
FINAL_ZIP_VERIFY_FAILED_LOG="$EVIDENCE_DIR/final-zip-verify.failed.log"
BUNDLE_OPEN_LOG="$EVIDENCE_DIR/bundle-open-verified.txt"
VISUAL_QA_LOG="$EVIDENCE_DIR/visual-qa-accepted.txt"
UNSIGNED_BUNDLE_OPEN_LOG="$EVIDENCE_DIR/unsigned-bundle-open-verified.txt"
UNSIGNED_VISUAL_QA_LOG="$EVIDENCE_DIR/unsigned-visual-qa-accepted.txt"
UNSIGNED_MEMORY_LOG="$EVIDENCE_DIR/unsigned-memory-check.txt"
GUARD_TESTS_LOG="$EVIDENCE_DIR/release-evidence-guard-tests.txt"
ICON_INFO="$EVIDENCE_DIR/icon-info.txt"
ICON_INFO_BACKUP="$EVIDENCE_DIR/icon-info.guard-backup"
SHA_BACKUP="$EVIDENCE_DIR/SHA256SUMS.guard-backup"
PREVIEW_DETERMINISM_BACKUP="$EVIDENCE_DIR/preview-determinism.guard-backup"
NOTES_BACKUP="$EVIDENCE_DIR/GITHUB_RELEASE_DRAFT.guard-backup"
FAIL_STDOUT="${TMPDIR:-/tmp}/hazakura-wallpaper-release-evidence-guard-test.$$.stdout"
FAIL_STDERR="${TMPDIR:-/tmp}/hazakura-wallpaper-release-evidence-guard-test.$$.stderr"

cd "$ROOT_DIR"

for path in "$APP_PATH" "$ZIP_PATH" "$MANIFEST_PATH"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing release candidate artifact required for guard tests: $path" >&2
    exit 1
  fi
done

expect_release_evidence_failure() {
  local label="$1"
  local expected_error="$2"
  local rc=0

  "$ROOT_DIR/scripts/check_release_evidence.sh" >"$FAIL_STDOUT" 2>"$FAIL_STDERR" || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "Release evidence guard test unexpectedly passed: $label" >&2
    cat "$FAIL_STDOUT" >&2
    exit 1
  fi

  if ! grep -Fq "$expected_error" "$FAIL_STDERR"; then
    echo "Release evidence guard test failed with the wrong error: $label" >&2
    cat "$FAIL_STDERR" >&2
    exit 1
  fi
}

expect_command_failure() {
  local label="$1"
  local expected_error="$2"
  shift 2
  local rc=0

  "$@" >"$FAIL_STDOUT" 2>"$FAIL_STDERR" || rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "Release evidence guard command unexpectedly passed: $label" >&2
    cat "$FAIL_STDOUT" >&2
    exit 1
  fi

  if ! grep -Fq "$expected_error" "$FAIL_STDERR"; then
    echo "Release evidence guard command failed with the wrong error: $label" >&2
    cat "$FAIL_STDERR" >&2
    exit 1
  fi
}

expect_swift_safety_failure() {
  local label="$1"
  local fixture_dir

  fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-swift-safety.XXXXXX")"
  mkdir -p "$fixture_dir/Sources"
  {
    echo "let unsafeValue: String? = nil"
    echo "_ = unsafeValue!"
  } >"$fixture_dir/Sources/Unsafe.swift"

  expect_command_failure \
    "$label" \
    "Swift safety check failed: remove crash-only, force-unwrapped, or unchecked constructs before release." \
    "$ROOT_DIR/scripts/check_swift_safety.sh" "$fixture_dir/Sources"

  rm -rf "$fixture_dir"
}

expect_public_source_hygiene_failure() {
  local label="$1"
  local expected_error="$2"
  local fixture_name="$3"
  local fixture_content="$4"
  local fixture_dir
  local fixture_path
  local rc=0

  fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-public-source-hygiene.XXXXXX")"
  fixture_path="$fixture_dir/$fixture_name"
  printf '%s\n' "$fixture_content" >"$fixture_path"

  "$ROOT_DIR/scripts/check_public_source_hygiene.sh" "$fixture_path" >"$FAIL_STDOUT" 2>"$FAIL_STDERR" || rc=$?
  rm -rf "$fixture_dir"

  if [[ "$rc" -eq 0 ]]; then
    echo "Release evidence guard command unexpectedly passed: $label" >&2
    cat "$FAIL_STDOUT" >&2
    exit 1
  fi

  if ! grep -Fq "$expected_error" "$FAIL_STDERR"; then
    echo "Release evidence guard command failed with the wrong error: $label" >&2
    cat "$FAIL_STDERR" >&2
    exit 1
  fi
}

expect_privacy_security_boundary_failure() {
  local label="$1"
  local fixture_dir

  fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-privacy-boundary.XXXXXX")"
  mkdir -p "$fixture_dir/Sources"
  {
    echo "import Foundation"
    echo "let request = URLRequest(url: URL(string: \"https://example.invalid\")!)"
    echo "_ = request"
  } >"$fixture_dir/Sources/NetworkClient.swift"

  expect_command_failure \
    "$label" \
    "Privacy/security boundary check failed: runtime source must not introduce network clients, web views, or background network APIs." \
    "$ROOT_DIR/scripts/check_privacy_security_boundaries.sh" "$fixture_dir/Sources"

  rm -rf "$fixture_dir"
}

expect_preview_artifact_failure() {
  local label="$1"
  local expected_error="$2"
  local fixture_dir
  local preview
  local rc=0

  fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-preview-artifacts.XXXXXX")"
  for preview in \
    sakura.png \
    magic.png \
    spark.png \
    hazakura.png \
    breeze.png \
    firefly.png \
    night-sakura.png \
    qa-matrix-day.png \
    qa-matrix-night.png; do
    cp "$ROOT_DIR/dist/previews/$preview" "$fixture_dir/$preview"
  done

  cp "$ROOT_DIR/dist/previews/sakura.png" "$fixture_dir/magic.png"

  "$ROOT_DIR/scripts/check_preview_artifacts.sh" "$fixture_dir" >"$FAIL_STDOUT" 2>"$FAIL_STDERR" || rc=$?
  rm -rf "$fixture_dir"

  if [[ "$rc" -eq 0 ]]; then
    echo "Release evidence guard command unexpectedly passed: $label" >&2
    cat "$FAIL_STDOUT" >&2
    exit 1
  fi

  if ! grep -Fq "$expected_error" "$FAIL_STDERR"; then
    echo "Release evidence guard command failed with the wrong error: $label" >&2
    cat "$FAIL_STDERR" >&2
    exit 1
  fi
}

expect_script_contains() {
  local label="$1"
  local path="$2"
  local expected_text="$3"

  if ! grep -Fq -- "$expected_text" "$path"; then
    echo "Release evidence guard script check failed: $label" >&2
    echo "Missing expected text in $path: $expected_text" >&2
    exit 1
  fi
}

expect_script_contains \
  "guard diagnostics stay outside canonical release evidence" \
  "$ROOT_DIR/scripts/test_release_evidence_guards.sh" \
  'FAIL_STDOUT="${TMPDIR:-/tmp}/hazakura-wallpaper-release-evidence-guard-test.$$.stdout"'

expect_script_contains \
  "ZIP packaging removes pre-rename local artifacts" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'rm -rf "$LEGACY_APP_PATH" "$LEGACY_ZIP_PATH"'

expect_script_contains \
  "Swift safety check supports targeted fixture paths" \
  "$ROOT_DIR/scripts/check_swift_safety.sh" \
  'CHECK_PATHS=("$@")'

expect_script_contains \
  "public source hygiene supports targeted fixture paths" \
  "$ROOT_DIR/scripts/check_public_source_hygiene.sh" \
  'if [[ "$#" -gt 0 ]]; then'

expect_script_contains \
  "public source hygiene labels targeted fixture scans" \
  "$ROOT_DIR/scripts/check_public_source_hygiene.sh" \
  'scan_scope_label="explicit files"'

expect_script_contains \
  "gitignore excludes local environment files before public source publication" \
  "$ROOT_DIR/.gitignore" \
  ".env.*"

expect_script_contains \
  "gitignore excludes private key material before public source publication" \
  "$ROOT_DIR/.gitignore" \
  "*.pem"

expect_script_contains \
  "gitignore excludes Apple signing archives before public source publication" \
  "$ROOT_DIR/.gitignore" \
  "*.p12"

expect_script_contains \
  "public source hygiene skips content scans when there are no content files" \
  "$ROOT_DIR/scripts/check_public_source_hygiene.sh" \
  'if [[ "${#content_scan_files[@]}" -gt 0 ]]; then'

expect_script_contains \
  "public source hygiene excludes Git history hygiene guard patterns" \
  "$ROOT_DIR/scripts/check_public_source_hygiene.sh" \
  "scripts/check_public_git_history_hygiene.sh"

expect_script_contains \
  "release verification checks script executable bits" \
  "$ROOT_DIR/scripts/verify_release.sh" \
  '"$ROOT_DIR/scripts/check_script_executable_bits.sh" >/dev/null'

expect_script_contains \
  "release verification checks text normalization" \
  "$ROOT_DIR/scripts/verify_release.sh" \
  '"$ROOT_DIR/scripts/check_text_normalization.sh" >/dev/null'

expect_script_contains \
  "release verification checks legacy Tauri boundary" \
  "$ROOT_DIR/scripts/verify_release.sh" \
  '"$ROOT_DIR/scripts/check_legacy_tauri_boundary.sh" >/dev/null'

expect_script_contains \
  "release verification checks public Git history hygiene" \
  "$ROOT_DIR/scripts/verify_release.sh" \
  '"$ROOT_DIR/scripts/check_public_git_history_hygiene.sh" >/dev/null'

expect_script_contains \
  "CI checks script executable bits before running release gates" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "./scripts/check_script_executable_bits.sh"

expect_script_contains \
  "CI checks text normalization before running release gates" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "./scripts/check_text_normalization.sh"

expect_script_contains \
  "CI checks legacy Tauri boundary before running release gates" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "./scripts/check_legacy_tauri_boundary.sh"

expect_script_contains \
  "CI checks out full history for public Git history hygiene" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "fetch-depth: 0"

expect_script_contains \
  "CI checks public Git history hygiene before running release gates" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "./scripts/check_public_git_history_hygiene.sh"

expect_swift_safety_failure \
  "Swift safety rejects force unwraps"

expect_public_source_hygiene_failure \
  "public source hygiene rejects local absolute paths" \
  "publishable source contains local absolute paths or the local username" \
  "public-source-hygiene.fixture" \
  "Local developer path: /"'Users'"/example/Library/Secrets"

expect_public_source_hygiene_failure \
  "public source hygiene rejects root release archives" \
  "publishable source includes local, generated, backup, or credential-like paths." \
  "Hazakura Wallpaper.zip" \
  "release archive fixture"

expect_public_source_hygiene_failure \
  "public source hygiene rejects Xcode user state files" \
  "publishable source includes local, generated, backup, or credential-like paths." \
  "UserInterfaceState.xcuserstate" \
  "xcode user state fixture"

expect_privacy_security_boundary_failure \
  "privacy/security boundary rejects network clients"

expect_preview_artifact_failure \
  "preview artifact check rejects duplicate preview output" \
  "Preview visual diversity failed"

expect_script_contains \
  "release verification runs privacy/security boundary checks" \
  "$ROOT_DIR/scripts/verify_release.sh" \
  '"$ROOT_DIR/scripts/check_privacy_security_boundaries.sh" >/dev/null'

expect_script_contains \
  "publish readiness runs privacy/security boundary checks" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  '"$ROOT_DIR/scripts/check_privacy_security_boundaries.sh" >/dev/null'

expect_script_contains \
  "publish readiness runs public Git history hygiene" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  '"$ROOT_DIR/scripts/check_public_git_history_hygiene.sh" >/dev/null'

expect_script_contains \
  "public repository docs mention Git history hygiene" \
  "$ROOT_DIR/scripts/check_public_repository_docs.sh" \
  'require_contains README.md "public Git history hygiene"'

expect_script_contains \
  "public repository docs reject old public product name" \
  "$ROOT_DIR/scripts/check_public_repository_docs.sh" \
  'must not mention old public product name'

expect_command_failure \
  "share readiness requires DMG and normal-session evidence" \
  "Share readiness failed:" \
  "$ROOT_DIR/scripts/check_share_readiness.sh"

expect_command_failure \
  "share evidence requires DMG and normal-session evidence" \
  "Share readiness failed:" \
  "$ROOT_DIR/scripts/check_share_evidence_ready.sh"

expect_command_failure \
  "unsigned share finalizer requires explicit human acceptance" \
  "Refusing to finalize unsigned share without --operator, --reviewer, --accepted, and --checklist-complete." \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh"

expect_script_contains \
  "unsigned share finalizer creates DMG before recording evidence" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  'SAKURA_SKY_PACKAGE_EXISTING_APP=1 "$ROOT_DIR/scripts/package_dmg.sh"'

expect_script_contains \
  "unsigned share finalizer supports public package-existing alias" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  'HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1'

expect_script_contains \
  "unsigned share finalizer runs strict normal-session preflight" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/check_unsigned_share_prerequisites.sh" --strict-normal-session >/dev/null'

expect_script_contains \
  "workflow aliases include unsigned share preflight" \
  "$ROOT_DIR/scripts/check_workflow_aliases.sh" \
  'require_script "share:preflight" "./scripts/check_unsigned_share_prerequisites.sh"'

expect_script_contains \
  "workflow aliases include strict unsigned share preflight" \
  "$ROOT_DIR/scripts/check_workflow_aliases.sh" \
  'require_script "share:preflight:strict" "./scripts/check_unsigned_share_prerequisites.sh --strict-normal-session"'

expect_script_contains \
  "workflow aliases keep npm dependency-free" \
  "$ROOT_DIR/scripts/check_workflow_aliases.sh" \
  'require_absent_package_key "dependencies"'

expect_script_contains \
  "workflow aliases reject dev dependency installs" \
  "$ROOT_DIR/scripts/check_workflow_aliases.sh" \
  'require_absent_package_key "devDependencies"'

expect_script_contains \
  "release metadata keeps Xcode development team empty" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Xcode DEVELOPMENT_TEAM must stay empty across configurations"

expect_script_contains \
  "release metadata rejects committed provisioning profiles" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Xcode project must not commit provisioning profiles or a concrete development team."

expect_script_contains \
  "release metadata requires shared Xcode scheme" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Hazakura Wallpaper.xcscheme"

expect_script_contains \
  "gitattributes normalizes Xcode shared schemes" \
  "$ROOT_DIR/.gitattributes" \
  "*.xcscheme text eol=lf"

expect_script_contains \
  "CI runs strict unsigned share preflight" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "npm run share:preflight:strict"

expect_script_contains \
  "CI packages unsigned DMG artifact" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh"

expect_script_contains \
  "CI uploads DMG release candidate" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "dist/Hazakura Wallpaper.dmg"

expect_script_contains \
  "CI uploads DMG evidence" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "dist/release-evidence/dmg-info.txt"

expect_script_contains \
  "CI checks release draft after DMG packaging" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "./scripts/check_github_release_notes.sh"

expect_script_contains \
  "GitHub release draft points to share readiness gate" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh" \
  'require_contains "npm run share:check"'

expect_script_contains \
  "GitHub release draft Ready status requires share readiness" \
  "$ROOT_DIR/scripts/write_github_release_notes.sh" \
  '"$ROOT_DIR/scripts/check_share_evidence_ready.sh" >/dev/null 2>&1'

expect_script_contains \
  "share readiness uses the share-evidence gate" \
  "$ROOT_DIR/scripts/check_share_readiness.sh" \
  '"$ROOT_DIR/scripts/check_share_evidence_ready.sh"'

expect_script_contains \
  "share evidence validates release evidence first" \
  "$ROOT_DIR/scripts/check_share_evidence_ready.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1'

expect_script_contains \
  "share evidence accepts final or unsigned bundle-open evidence" \
  "$ROOT_DIR/scripts/check_share_evidence_ready.sh" \
  '[[ ! -s "$BUNDLE_OPEN_LOG" && ! -s "$UNSIGNED_BUNDLE_OPEN_LOG" ]]'

expect_script_contains \
  "share evidence accepts final or unsigned visual QA evidence" \
  "$ROOT_DIR/scripts/check_share_evidence_ready.sh" \
  '[[ ! -s "$VISUAL_QA_LOG" && ! -s "$UNSIGNED_VISUAL_QA_LOG" ]]'

expect_script_contains \
  "share evidence requires unsigned leaks memory evidence" \
  "$ROOT_DIR/scripts/check_share_evidence_ready.sh" \
  'require_file "$UNSIGNED_MEMORY_LOG" "normal-session leaks memory evidence"'

expect_script_contains \
  "GitHub release notes reject premature Ready status" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh" \
  "GitHub release notes must not claim Ready to share before share evidence exists"

expect_script_contains \
  "GitHub release notes allow final or unsigned bundle-open evidence" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh" \
  '[[ ! -s "$BUNDLE_OPEN" && ! -s "$UNSIGNED_BUNDLE_OPEN" ]]'

expect_script_contains \
  "GitHub release notes allow final or unsigned visual QA evidence" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh" \
  '[[ ! -s "$VISUAL_QA" && ! -s "$UNSIGNED_VISUAL_QA" ]]'

expect_script_contains \
  "GitHub release notes require release-candidate warning before ready" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh" \
  "Normal-session DMG, bundle-open, leaks memory, and human visual QA evidence are still required before handing the artifact to users."

expect_script_contains \
  "GitHub release notes reject old public product name" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh" \
  "GitHub release notes must not mention old public product name"

expect_script_contains \
  "GitHub release notes require exactly one status line" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh" \
  "GitHub release notes must contain exactly one status line"

expect_script_contains \
  "CI share gate rejects missing DMG after packaging" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "share readiness still reports missing DMG output after CI DMG packaging"

expect_script_contains \
  "CI share gate expects bundle-open evidence after DMG packaging" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "normal-session bundle-open evidence"

expect_script_contains \
  "CI share gate expects visual QA evidence after DMG packaging" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "human visual QA evidence"

expect_script_contains \
  "CI share gate expects leaks evidence after DMG packaging" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "normal-session leaks memory evidence"

expect_script_contains \
  "manifest requires DMG before strict share gate" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "DMG creation in a normal macOS session before the strict share gate."

expect_script_contains \
  "CI uploads public-safe release draft evidence" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "dist/release-evidence/GITHUB_RELEASE_DRAFT.md"

expect_script_contains \
  "CI release candidate artifact retention is bounded" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "retention-days: 14"

expect_script_contains \
  "CI release candidate artifact upload fails on missing files" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "if-no-files-found: error"

expect_script_contains \
  "public artifact hygiene guards bounded CI artifact retention" \
  "$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" \
  "CI release-candidate artifacts must use a bounded retention period."

expect_script_contains \
  "public artifact hygiene guards missing-file upload failures" \
  "$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" \
  "CI release-candidate artifacts must fail when expected artifacts are missing."

expect_script_contains \
  "public artifact hygiene guards strict CI share preflight" \
  "$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" \
  "CI must run the strict unsigned share preflight before uploading release-candidate artifacts."

expect_script_contains \
  "public artifact hygiene rejects non-strict CI share preflight" \
  "$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" \
  "CI must not use the non-strict share preflight for release-candidate artifacts."

expect_script_contains \
  "CI checks public artifact hygiene" \
  "$ROOT_DIR/.github/workflows/ci.yml" \
  "./scripts/check_public_artifact_hygiene.sh"

if grep -Fq "dist/release-evidence/**" "$ROOT_DIR/.github/workflows/ci.yml"; then
  echo "Release evidence guard script check failed: CI must not upload raw release evidence wildcard paths." >&2
  exit 1
fi

expect_script_contains \
  "public artifact hygiene rejects local-path evidence uploads" \
  "$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" \
  "CI must not upload local-path-bearing release evidence"

for local_path_evidence in \
  "dist/release-evidence/icon-info.txt" \
  "dist/release-evidence/codesign-info.txt" \
  "dist/release-evidence/spctl.txt" \
  "dist/release-evidence/macho-build.txt"
do
  if grep -Fq "$local_path_evidence" "$ROOT_DIR/.github/workflows/ci.yml"; then
    echo "Release evidence guard script check failed: CI uploads local-path-bearing release evidence: $local_path_evidence" >&2
    exit 1
  fi
done

expect_script_contains \
  "unsigned share preflight checks temporary DMG mount support" \
  "$ROOT_DIR/scripts/check_unsigned_share_prerequisites.sh" \
  'hdiutil attach -readonly -nobrowse -mountpoint "$PROBE_MOUNT_DIR" "$probe_dmg"'

expect_script_contains \
  "unsigned share preflight suppresses nested release evidence diagnostics" \
  "$ROOT_DIR/scripts/check_unsigned_share_prerequisites.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1'

expect_script_contains \
  "unsigned share preflight reruns release evidence diagnostics on failure" \
  "$ROOT_DIR/scripts/check_unsigned_share_prerequisites.sh" \
  "Unsigned share prerequisites failed: release evidence did not pass; showing diagnostics."

expect_script_contains \
  "unsigned share preflight suppresses nested publish readiness diagnostics" \
  "$ROOT_DIR/scripts/check_unsigned_share_prerequisites.sh" \
  '"$ROOT_DIR/scripts/check_publish_readiness.sh" >/dev/null 2>&1'

expect_script_contains \
  "unsigned share preflight reruns publish readiness diagnostics on failure" \
  "$ROOT_DIR/scripts/check_unsigned_share_prerequisites.sh" \
  "Unsigned share prerequisites failed: publish readiness did not pass; showing diagnostics."

expect_script_contains \
  "unsigned share finalizer records memory evidence" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/record_unsigned_memory_check.sh" --operator "$OPERATOR"'

expect_script_contains \
  "unsigned share finalizer records bundle-open before memory evidence" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/record_unsigned_bundle_open_verification.sh" --operator "$OPERATOR"'

expect_script_contains \
  "unsigned share finalizer records visual QA evidence" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/record_unsigned_visual_qa_acceptance.sh" --accepted --checklist-complete --reviewer "$REVIEWER"'

expect_script_contains \
  "unsigned share finalizer cleans partial evidence on failure" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  "cleanup_partial_evidence"

expect_script_contains \
  "unsigned share finalizer preserves pre-existing bundle-open evidence on failure" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  'HAD_UNSIGNED_BUNDLE_OPEN_LOG=1'

expect_script_contains \
  "unsigned share finalizer tracks pre-existing DMG on failure" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  'HAD_DMG_PATH=1'

expect_script_contains \
  "unsigned share finalizer tracks pre-existing DMG evidence on failure" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  'HAD_DMG_INFO=1'

expect_script_contains \
  "unsigned share finalizer removes newly-created DMG on failure" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  'rm -f "$DMG_PATH"'

expect_script_contains \
  "unsigned share finalizer removes newly-created DMG evidence on failure" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  'rm -f "$DMG_INFO"'

expect_script_contains \
  "unsigned share finalizer refreshes manifest after partial evidence cleanup" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null 2>&1 || true'

expect_script_contains \
  "unsigned share finalizer refreshes release evidence after partial evidence cleanup" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1 || true'

expect_script_contains \
  "unsigned share finalizer ends with share readiness gate" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/check_share_readiness.sh"'

expect_script_contains \
  "unsigned share finalizer suppresses successful nested publish readiness diagnostics" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  '"$ROOT_DIR/scripts/check_publish_readiness.sh" >/dev/null 2>&1'

expect_script_contains \
  "unsigned share finalizer reruns publish readiness diagnostics on failure" \
  "$ROOT_DIR/scripts/finalize_unsigned_share.sh" \
  "Publish readiness check failed; showing diagnostics."

expect_script_contains \
  "release evidence checks bundle-open timestamp provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_utc_timestamp_evidence_field "$BUNDLE_OPEN_LOG" "Verified at"'

expect_script_contains \
  "release evidence checks unsigned bundle-open provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$UNSIGNED_BUNDLE_OPEN_LOG" "Unsigned bundle open verified" "yes"'

expect_script_contains \
  "release evidence checks unsigned visual QA provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$UNSIGNED_VISUAL_QA_LOG" "Unsigned visual QA accepted" "yes"'

expect_script_contains \
  "release evidence checks unsigned memory provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Unsigned memory check passed" "yes"'

expect_script_contains \
  "release evidence checks unsigned leaks exit code" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Leaks exit code" "0"'

expect_script_contains \
  "release evidence checks unsigned no-leaks result" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$UNSIGNED_MEMORY_LOG" "Leaks result" "no leaks reported by leaks --atExit"'

expect_script_contains \
  "unsigned memory recorder rejects leaked-byte output" \
  "$ROOT_DIR/scripts/record_unsigned_memory_check.sh" \
  "leaks --atExit reported leaked bytes"

expect_script_contains \
  "unsigned memory recorder checks the distributable bundle executable path" \
  "$ROOT_DIR/scripts/record_unsigned_memory_check.sh" \
  'leaks --atExit -- "$APP_EXECUTABLE"'

expect_script_contains \
  "unsigned memory recorder suppresses successful nested release evidence diagnostics" \
  "$ROOT_DIR/scripts/record_unsigned_memory_check.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1'

expect_script_contains \
  "unsigned bundle-open recorder suppresses successful nested release evidence diagnostics" \
  "$ROOT_DIR/scripts/record_unsigned_bundle_open_verification.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1'

expect_script_contains \
  "unsigned visual QA recorder suppresses successful nested release evidence diagnostics" \
  "$ROOT_DIR/scripts/record_unsigned_visual_qa_acceptance.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1'

expect_script_contains \
  "unsigned evidence recorders rerun release evidence diagnostics on failure" \
  "$ROOT_DIR/scripts/record_unsigned_memory_check.sh" \
  "Release evidence check failed; showing diagnostics."

expect_script_contains \
  "release evidence requires renderer memory smoke" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$RENDERER_MEMORY_SMOKE" "Renderer memory smoke passed" "yes"'

expect_script_contains \
  "release verification runs renderer memory smoke" \
  "$ROOT_DIR/scripts/verify_release.sh" \
  '"$ROOT_DIR/scripts/check_renderer_memory_smoke.sh" >/dev/null'

expect_script_contains \
  "release verification runs app lifecycle safety" \
  "$ROOT_DIR/scripts/verify_release.sh" \
  '"$ROOT_DIR/scripts/check_app_lifecycle_safety.sh" >/dev/null'

expect_script_contains \
  "publish readiness checks public repository docs" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  '"$ROOT_DIR/scripts/check_public_repository_docs.sh" >/dev/null'

expect_script_contains \
  "publish readiness checks GitHub release draft" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  '"$ROOT_DIR/scripts/check_github_release_notes.sh" >/dev/null'

expect_script_contains \
  "GitHub release draft share probe uses share-evidence gate" \
  "$ROOT_DIR/scripts/write_github_release_notes.sh" \
  '"$ROOT_DIR/scripts/check_share_evidence_ready.sh" >/dev/null 2>&1'

expect_script_contains \
  "publish readiness checks public artifact hygiene" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  '"$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" >/dev/null'

expect_script_contains \
  "release candidate writes GitHub release draft" \
  "$ROOT_DIR/scripts/prepare_release_candidate.sh" \
  '"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null'

expect_script_contains \
  "release candidate checks public artifact hygiene before success" \
  "$ROOT_DIR/scripts/prepare_release_candidate.sh" \
  '"$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" >/dev/null'

expect_script_contains \
  "release evidence requires unique human evidence fields" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "read_unique_evidence_field"

expect_script_contains \
  "release evidence requires unique checksum fields" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "read_unique_checksum_field"

expect_script_contains \
  "release evidence requires unique preview determinism fields" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "read_unique_preview_determinism_sha"

expect_script_contains \
  "release evidence rejects duplicate human evidence fields" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "evidence must contain exactly one field"

expect_script_contains \
  "release evidence checks bundle-open operator provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_single_line_nonblank_evidence_field "$BUNDLE_OPEN_LOG" "Operator"'

expect_script_contains \
  "release evidence checks bundle-open bundle ID provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Bundle ID" "$actual_bundle_id"'

expect_script_contains \
  "release evidence checks bundle-open CDHash provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "CDHash" "$actual_cdhash"'

expect_script_contains \
  "release evidence checks bundle-open recording command" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified command" "./scripts/record_bundle_open_verification.sh --operator <operator>"'

expect_script_contains \
  "release evidence checks bundle-open executable provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper"'

expect_script_contains \
  "release evidence checks anchored bundle-open process match" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified process match" "anchored executable path"'

expect_script_contains \
  "release evidence checks visual QA timestamp provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_utc_timestamp_evidence_field "$VISUAL_QA_LOG" "Accepted at"'

expect_script_contains \
  "release evidence checks visual QA reviewer provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_single_line_nonblank_evidence_field "$VISUAL_QA_LOG" "Reviewer"'

expect_script_contains \
  "release evidence checks visual QA bundle ID provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Bundle ID" "$actual_bundle_id"'

expect_script_contains \
  "release evidence checks visual QA CDHash provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "CDHash" "$actual_cdhash"'

expect_script_contains \
  "release evidence checks visual QA recording command" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Accepted command" "./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>"'

expect_script_contains \
  "release evidence checks visual QA checklist checksum" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist SHA-256" "$release_qa_sha"'

expect_script_contains \
  "release evidence checks visual QA checklist completion" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist completed" "yes"'

expect_script_contains \
  "publish readiness checks bundle-open timestamp provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_utc_timestamp_evidence_field "$BUNDLE_OPEN_LOG" "Verified at"'

expect_script_contains \
  "publish readiness requires unique human evidence fields" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "read_unique_evidence_field"

expect_script_contains \
  "publish readiness rejects duplicate human evidence fields" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "evidence must contain exactly one field"

expect_script_contains \
  "publish readiness checks bundle-open operator provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_single_line_nonblank_evidence_field "$BUNDLE_OPEN_LOG" "Operator"'

expect_script_contains \
  "publish readiness checks bundle-open bundle ID provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Bundle ID" "$bundle_identifier"'

expect_script_contains \
  "publish readiness checks bundle-open CDHash provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "CDHash" "$app_cdhash"'

expect_script_contains \
  "publish readiness checks bundle-open recording command" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified command" "./scripts/record_bundle_open_verification.sh --operator <operator>"'

expect_script_contains \
  "publish readiness checks bundle-open executable provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified executable" "dist/Hazakura Wallpaper.app/Contents/MacOS/HazakuraWallpaper"'

expect_script_contains \
  "publish readiness checks anchored bundle-open process match" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$BUNDLE_OPEN_LOG" "Verified process match" "anchored executable path"'

expect_script_contains \
  "publish readiness checks visual QA timestamp provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_utc_timestamp_evidence_field "$VISUAL_QA_LOG" "Accepted at"'

expect_script_contains \
  "publish readiness checks visual QA reviewer provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_single_line_nonblank_evidence_field "$VISUAL_QA_LOG" "Reviewer"'

expect_script_contains \
  "publish readiness checks visual QA bundle ID provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Bundle ID" "$bundle_identifier"'

expect_script_contains \
  "publish readiness checks visual QA CDHash provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "CDHash" "$app_cdhash"'

expect_script_contains \
  "publish readiness checks visual QA recording command" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Accepted command" "./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>"'

expect_script_contains \
  "publish readiness checks visual QA checklist checksum" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist SHA-256" "$release_qa_sha"'

expect_script_contains \
  "publish readiness checks visual QA checklist completion" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$VISUAL_QA_LOG" "Checklist completed" "yes"'

expect_script_contains \
  "publish readiness requires release evidence blocker report to be clear" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "release evidence report still lists publish-readiness blockers"

expect_script_contains \
  "manifest requires successful stapler evidence for final ZIP verified" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "has_unique_matching_line \"\$STAPLER_LOG\" '^The (staple and )?validate action worked![[:space:]]*$'"

expect_script_contains \
  "manifest requires strict notary accepted evidence for final ZIP verified" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "has_unique_matching_line \"\$NOTARY_LOG\" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$'"

expect_script_contains \
  "manifest ties notary evidence to submitted app CDHash" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Submitted app CDHash" "$app_cdhash"'

expect_script_contains \
  "manifest requires submitted notary UTC timestamp" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_utc_timestamp_evidence_field "$path" "Submitted at"'

expect_script_contains \
  "manifest requires submitted notary SHA-256 format" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "has_sha256_evidence_field"

expect_script_contains \
  "manifest requires submitted notary command provenance" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Submitted command" "xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>"'

expect_script_contains \
  "manifest requires exact submitted notary fields" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "has_exact_evidence_field"

expect_script_contains \
  "manifest requires unique human evidence fields before listing final evidence" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "if (count != 1)"

expect_script_contains \
  "release evidence requires strict notary accepted evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "require_unique_matching_line \"\$NOTARY_LOG\" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$'"

expect_script_contains \
  "release evidence ties notary evidence to submitted app CDHash" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$NOTARY_LOG" "Submitted app CDHash" "$actual_cdhash"'

expect_script_contains \
  "release evidence requires submitted notary UTC timestamp" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_utc_timestamp_evidence_field "$NOTARY_LOG" "Submitted at"'

expect_script_contains \
  "release evidence requires submitted notary SHA-256 format" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_sha256_evidence_field "$NOTARY_LOG" "Submitted ZIP SHA-256"'

expect_script_contains \
  "release evidence requires submitted notary command provenance" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$NOTARY_LOG" "Submitted command" "xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>"'

expect_script_contains \
  "release evidence requires exact submitted notary fields" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$NOTARY_LOG" "Submitted bundle ID"'

expect_script_contains \
  "publish readiness requires strict notary accepted evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "require_unique_matching_line \"\$NOTARY_LOG\" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$'"

expect_script_contains \
  "publish readiness ties notary evidence to submitted app CDHash" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$NOTARY_LOG" "Submitted app CDHash" "$app_cdhash"'

expect_script_contains \
  "publish readiness requires submitted notary UTC timestamp" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_utc_timestamp_evidence_field "$NOTARY_LOG" "Submitted at"'

expect_script_contains \
  "publish readiness requires submitted notary SHA-256 format" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_sha256_evidence_field "$NOTARY_LOG" "Submitted ZIP SHA-256"'

expect_script_contains \
  "publish readiness requires submitted notary command provenance" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$NOTARY_LOG" "Submitted command" "xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>"'

expect_script_contains \
  "publish readiness requires exact submitted notary fields" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$NOTARY_LOG" "Submitted bundle ID"'

expect_script_contains \
  "notarization script requires strict notary accepted evidence" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  "has_unique_matching_line \"\$NOTARY_ATTEMPT_LOG\" '^[[:space:]]*status:[[:space:]]+Accepted[[:space:]]*$'"

expect_script_contains \
  "notarization script records submitted app CDHash evidence" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'echo "Submitted app CDHash: $submitted_app_cdhash"'

expect_script_contains \
  "notarization script records submitted ZIP SHA evidence" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'echo "Submitted ZIP SHA-256: $submitted_zip_sha"'

expect_script_contains \
  "notarization script records submitted UTC timestamp evidence" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'echo "Submitted at: $submitted_at"'

expect_script_contains \
  "notarization script records submitted command evidence without profile name" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'echo "Submitted command: xcrun notarytool submit dist/Hazakura Wallpaper.zip --wait --keychain-profile <profile>"'

expect_script_contains \
  "notarization script stages notary evidence before canonical promotion" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'NOTARY_ATTEMPT_LOG="$EVIDENCE_DIR/notarytool-submit.attempt.log"'

expect_script_contains \
  "notarization script keeps failed notary evidence out of canonical path" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'NOTARY_FAILED_LOG="$EVIDENCE_DIR/notarytool-submit.failed.log"'

expect_script_contains \
  "notarization script promotes notary evidence only after final ZIP verification" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'mv "$NOTARY_ATTEMPT_LOG" "$NOTARY_LOG"'

expect_script_contains \
  "notarization script promotes final ZIP verification only after success" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'mv "$FINAL_ZIP_VERIFY_ATTEMPT_LOG" "$FINAL_ZIP_VERIFY_LOG"'

expect_script_contains \
  "notarization script stages final ZIP before canonical promotion" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'TEMP_FINAL_ZIP="$(mktemp "$ROOT_DIR/dist/Hazakura Wallpaper.final.zip.XXXXXX")"'

expect_script_contains \
  "notarization script verifies staged final ZIP" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'ditto -x -k "$TEMP_FINAL_ZIP" "$VERIFY_DIR"'

expect_script_contains \
  "notarization script requires unique final ZIP stapler evidence before promotion" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  "has_unique_matching_line \"\$FINAL_ZIP_VERIFY_ATTEMPT_LOG\" '^The (staple and )?validate action worked![[:space:]]*$'"

expect_script_contains \
  "notarization script requires unique final ZIP success marker before promotion" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  "has_unique_matching_line \"\$FINAL_ZIP_VERIFY_ATTEMPT_LOG\" '^Final notarized ZIP verification passed\\.$'"

expect_script_contains \
  "notarization script requires unique final ZIP codesign validity before promotion" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  "has_unique_matching_line \"\$FINAL_ZIP_VERIFY_ATTEMPT_LOG\" '^[^:]+:[[:space:]]+valid on disk$'"

expect_script_contains \
  "notarization script requires unique final ZIP Gatekeeper evidence before promotion" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  "has_unique_matching_line \"\$FINAL_ZIP_VERIFY_ATTEMPT_LOG\" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'"

expect_script_contains \
  "notarization script promotes final ZIP only after verification" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'mv "$TEMP_FINAL_ZIP" "$ZIP_PATH"'

expect_script_contains \
  "notarization script removes incomplete final ZIP evidence on failure" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  '"$ZIP_CONTENTS"'

expect_script_contains \
  "notarization script removes canonical final evidence on incomplete final ZIP path" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  '"$NOTARY_LOG"'

expect_script_contains \
  "notarization script removes human final evidence on incomplete final ZIP path" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  '"$EVIDENCE_DIR/bundle-open-verified.txt"'

expect_script_contains \
  "ZIP packaging removes failed notarization attempt evidence" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'notarytool-submit.failed.log'

expect_script_contains \
  "ZIP packaging stages archive before canonical promotion" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'TEMP_ZIP="$(mktemp "$ROOT_DIR/dist/Hazakura Wallpaper.zip.XXXXXX")"'

expect_script_contains \
  "ZIP packaging promotes archive only after content validation" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'mv "$TEMP_ZIP" "$ZIP_PATH"'

expect_script_contains \
  "ZIP packaging suppresses successful ZIP content diagnostics" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  '"$ROOT_DIR/scripts/check_zip_contents.sh" "$zip_path" >/dev/null 2>&1'

expect_script_contains \
  "ZIP packaging reruns ZIP content diagnostics on failure" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  "ZIP content validation failed; showing diagnostics."

expect_script_contains \
  "ZIP packaging removes incomplete evidence on failure" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  "ZIP content validation failed; removed incomplete ZIP release evidence."

expect_script_contains \
  "ZIP packaging removes stale GitHub release draft before rewriting" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  '"$EVIDENCE_DIR/GITHUB_RELEASE_DRAFT.md"'

expect_script_contains \
  "ZIP packaging removes GitHub release draft on incomplete package failure" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  '"$ZIP_CONTENTS" "$NOTES_PATH"'

expect_script_contains \
  "ZIP packaging removes stale release evidence check before rewriting" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  '"$EVIDENCE_DIR/release-evidence-check.txt"'

expect_script_contains \
  "ZIP packaging removes release evidence check on incomplete package failure" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  '"$NOTES_PATH" "$RELEASE_EVIDENCE_CHECK"'

expect_script_contains \
  "ZIP packaging regenerates release evidence check before release draft" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'run_release_evidence_check'

expect_script_contains \
  "ZIP packaging reruns release evidence diagnostics on failure" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  "Release evidence check failed after ZIP packaging; showing diagnostics."

expect_script_contains \
  "release evidence rejects stale notarization attempt evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Stale notarization attempt evidence exists outside canonical final evidence"

expect_script_contains \
  "publish readiness rejects stale notarization attempt evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "Publish readiness failed: stale notarization attempt evidence exists outside canonical final evidence"

expect_script_contains \
  "notarization script uses notarytool keychain profile" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  '--keychain-profile "$NOTARYTOOL_PROFILE"'

expect_script_contains \
  "notarization script rejects non-Developer ID signing identities before build work" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  '"${SIGN_IDENTITY:-}" != Developer\ ID\ Application:*'

expect_script_contains \
  "notarization script rejects explicit password env credentials" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  "Explicit Apple ID/password notarization environment variables are not accepted"

expect_command_failure \
  "non-Developer ID signing identity is rejected before build work" \
  "SIGN_IDENTITY must be a Developer ID Application identity." \
  env \
    SIGN_IDENTITY="Apple Development: Example Team (TEAMID)" \
    NOTARYTOOL_PROFILE="profile-name" \
    "$ROOT_DIR/scripts/notarize_release_zip.sh"

expect_script_contains \
  "publish readiness rejects explicit password env credentials" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "explicit Apple ID/password notarization environment variables are not accepted"

expect_command_failure \
  "explicit notary Apple ID env is rejected before build work" \
  "Explicit Apple ID/password notarization environment variables are not accepted" \
  env \
    SIGN_IDENTITY="Developer ID Application: Example Team (TEAMID)" \
    NOTARYTOOL_PROFILE="profile-name" \
    NOTARYTOOL_APPLE_ID="apple-id@example.invalid" \
    "$ROOT_DIR/scripts/notarize_release_zip.sh"

expect_command_failure \
  "publish readiness rejects explicit notary Apple ID env in notarization-required mode" \
  "Publish readiness failed: explicit Apple ID/password notarization environment variables are not accepted" \
  env \
    SAKURA_SKY_REQUIRE_NOTARIZATION=1 \
    NOTARYTOOL_APPLE_ID="apple-id@example.invalid" \
    "$ROOT_DIR/scripts/check_publish_readiness.sh"

expect_script_contains \
  "release evidence requires strict stapler success evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "require_unique_matching_line \"\$STAPLER_LOG\" '^The (staple and )?validate action worked![[:space:]]*$'"

expect_script_contains \
  "publish readiness requires strict stapler success evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "require_unique_matching_line \"\$STAPLER_LOG\" '^The (staple and )?validate action worked![[:space:]]*$'"

expect_script_contains \
  "manifest requires accepted Gatekeeper evidence for final ZIP verified" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "has_unique_matching_line \"\$SPCTL_AFTER_NOTARIZATION\" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'"

expect_script_contains \
  "release evidence requires strict accepted Gatekeeper evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "require_unique_matching_line \"\$SPCTL_AFTER_NOTARIZATION\" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'"

expect_script_contains \
  "publish readiness requires strict accepted Gatekeeper evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  "require_unique_matching_line \"\$SPCTL_AFTER_NOTARIZATION\" '^[^:]+:[[:space:]]+accepted[[:space:]]*$'"

expect_script_contains \
  "ZIP content check compares extracted app with current app" \
  "$ROOT_DIR/scripts/check_zip_contents.sh" \
  'diff -qr "$APP_PATH" "$EXTRACTED_APP"'

expect_script_contains \
  "release evidence reruns live ZIP content check" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  '"$ROOT_DIR/scripts/check_zip_contents.sh" "$ZIP_PATH" >/dev/null'

expect_script_contains \
  "ZIP content check rejects development metadata" \
  "$ROOT_DIR/scripts/check_zip_contents.sh" \
  "ZIP contains development metadata, editor, local environment, debug-symbol, or build-output entries."

expect_script_contains \
  "release evidence requires development metadata exclusion evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "No development metadata, editor, local environment, debug-symbol, or build-output entries found."

expect_script_contains \
  "ZIP content check rejects unexpected app bundle entries" \
  "$ROOT_DIR/scripts/check_zip_contents.sh" \
  "ZIP contains unexpected app bundle entries."

expect_script_contains \
  "release evidence requires unexpected app bundle exclusion evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "No unexpected app bundle entries found."

expect_script_contains \
  "release evidence requires extracted app CDHash evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  '"Extracted app CDHash: $actual_cdhash"'

expect_script_contains \
  "manifest requires final ZIP bundle ID evidence" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Bundle ID" "$bundle_identifier"'

expect_script_contains \
  "manifest requires final ZIP archive evidence" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Verified archive" "dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "manifest requires final ZIP architecture evidence" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Architectures" "$mach_o_architectures"'

expect_script_contains \
  "manifest requires bundle-open and visual QA bundle ID evidence before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Bundle ID" "$bundle_identifier"'

expect_script_contains \
  "manifest requires bundle-open and visual QA architecture evidence before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Architectures" "$mach_o_architectures"'

expect_script_contains \
  "manifest requires bundle-open and visual QA CDHash evidence before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "CDHash" "$app_cdhash"'

expect_script_contains \
  "manifest requires bundle-open recorder command before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Verified command" "./scripts/record_bundle_open_verification.sh --operator <operator>"'

expect_script_contains \
  "manifest requires bundle-open timestamp provenance before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_utc_timestamp_evidence_field "$path" "Verified at"'

expect_script_contains \
  "manifest requires bundle-open operator provenance before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_single_line_nonblank_evidence_field "$path" "Operator"'

expect_script_contains \
  "manifest requires visual QA checklist completion before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Checklist completed" "yes"'

expect_script_contains \
  "manifest requires visual QA checklist checksum before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_exact_evidence_field "$path" "Checklist SHA-256" "$release_qa_sha"'

expect_script_contains \
  "manifest requires visual QA timestamp provenance before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_utc_timestamp_evidence_field "$path" "Accepted at"'

expect_script_contains \
  "manifest requires visual QA reviewer provenance before listing" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'has_single_line_nonblank_evidence_field "$path" "Reviewer"'

expect_script_contains \
  "release evidence requires final ZIP CDHash evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "CDHash" "$actual_cdhash"'

expect_script_contains \
  "release evidence requires final ZIP archive evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Verified archive" "dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "release evidence requires final ZIP architecture evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Architectures" "$actual_mach_o_architectures"'

expect_script_contains \
  "publish readiness requires final ZIP architecture evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Architectures" "$mach_o_architectures"'

expect_script_contains \
  "publish readiness requires final ZIP CDHash evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "CDHash" "$app_cdhash"'

expect_script_contains \
  "publish readiness requires final ZIP archive evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_exact_evidence_field "$FINAL_ZIP_VERIFY_LOG" "Verified archive" "dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "bundle-open recorder requires unique final ZIP archive evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'require_exact_final_zip_field "Verified archive" "dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "bundle-open recorder requires unique final ZIP success line" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'require_unique_final_zip_line "Final notarized ZIP verification passed."'

expect_script_contains \
  "visual QA recorder requires unique final ZIP archive evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'require_exact_final_zip_field "Verified archive" "dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "visual QA recorder requires unique final ZIP success line" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'require_unique_final_zip_line "Final notarized ZIP verification passed."'

expect_script_contains \
  "manifest requires final ZIP codesign evidence" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "has_unique_matching_line \"\$path\" '^[^:]+:[[:space:]]+valid on disk$'"

expect_script_contains \
  "release evidence requires final ZIP success marker" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '"'"'^Final notarized ZIP verification passed\.$'"'"

expect_script_contains \
  "publish readiness requires final ZIP codesign validity" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '"'"'^[^:]+:[[:space:]]+valid on disk$'"'"

expect_script_contains \
  "release evidence requires final ZIP stapler evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '"'"'^The (staple and )?validate action worked![[:space:]]*$'"'"

expect_script_contains \
  "publish readiness requires final ZIP Gatekeeper evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh" \
  'require_unique_matching_line "$FINAL_ZIP_VERIFY_LOG" '"'"'^[^:]+:[[:space:]]+accepted[[:space:]]*$'"'"

expect_script_contains \
  "distribution readiness rejects unexpected entitlements" \
  "$ROOT_DIR/scripts/check_distribution_readiness.sh" \
  "Distribution app must not include entitlements; unexpected entitlements were found"

expect_script_contains \
  "distribution readiness pins development region" \
  "$ROOT_DIR/scripts/check_distribution_readiness.sh" \
  'require_equal "CFBundleDevelopmentRegion" "$development_region" "ja"'

expect_script_contains \
  "distribution readiness pins info dictionary version" \
  "$ROOT_DIR/scripts/check_distribution_readiness.sh" \
  'require_equal "CFBundleInfoDictionaryVersion" "$info_dictionary_version" "6.0"'

expect_script_contains \
  "distribution readiness pins app icon key" \
  "$ROOT_DIR/scripts/check_distribution_readiness.sh" \
  'require_equal "CFBundleIconFile" "$icon_file" "icon"'

expect_script_contains \
  "distribution readiness supports no-write evidence mode" \
  "$ROOT_DIR/scripts/check_distribution_readiness.sh" \
  'SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE'

expect_script_contains \
  "release candidate uses no-write evidence mode for extracted app validation" \
  "$ROOT_DIR/scripts/prepare_release_candidate.sh" \
  'SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE=0 "$ROOT_DIR/scripts/check_distribution_readiness.sh" "$EXTRACTED_APP"'

expect_script_contains \
  "release candidate supports public no-write evidence alias" \
  "$ROOT_DIR/scripts/prepare_release_candidate.sh" \
  'HAZAKURA_WALLPAPER_WRITE_DISTRIBUTION_EVIDENCE=0'

expect_script_contains \
  "release manifest records entitlement state" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'echo "- Entitlements: $entitlements"'

expect_script_contains \
  "release evidence requires no entitlements" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  '"- Entitlements: none"'

expect_script_contains \
  "manifest lists codesign evidence" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "dist/release-evidence/codesign-info.txt"

expect_script_contains \
  "ZIP packaging removes stale top-level signing evidence" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'dist/codesign-info.txt'

expect_script_contains \
  "ZIP packaging removes stale DMG artifact" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'dist/Hazakura Wallpaper.dmg'

expect_script_contains \
  "ZIP packaging removes stale DMG evidence" \
  "$ROOT_DIR/scripts/package_zip.sh" \
  'dmg-info.txt'

expect_script_contains \
  "DMG packaging uses existing app mode" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'SAKURA_SKY_PACKAGE_EXISTING_APP'

expect_script_contains \
  "DMG packaging supports public package-existing alias" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP'

expect_script_contains \
  "DMG packaging validates app without canonical evidence writes" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'run_distribution_readiness_check "$APP_PATH"'

expect_script_contains \
  "DMG packaging verifies disk image" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'hdiutil verify "$DMG_PATH"'

expect_script_contains \
  "DMG packaging suppresses successful hdiutil create output" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$DMG_PATH" >/dev/null'

expect_script_contains \
  "DMG packaging mounts image for app identity verification" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$DMG_PATH"'

expect_script_contains \
  "DMG packaging validates mounted app without canonical evidence writes" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'run_distribution_readiness_check "$MOUNTED_APP_PATH"'

expect_script_contains \
  "DMG packaging writes evidence" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'DMG checks passed.'

expect_script_contains \
  "DMG packaging refreshes release manifest" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null'

expect_script_contains \
  "manifest records DMG SHA when present" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'echo "- DMG SHA-256: $dmg_sha"'

expect_script_contains \
  "manifest includes DMG in checksum list when present" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'echo "$dmg_sha  dist/Hazakura Wallpaper.dmg"'

expect_script_contains \
  "release evidence checks DMG evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$DMG_INFO" "DMG SHA-256" "$actual_dmg_sha" "DMG"'

expect_script_contains \
  "release evidence checks unique DMG success evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "require_unique_matching_line \"\$DMG_INFO\" '^DMG checks passed\\.\$' \"DMG\""

expect_script_contains \
  "release evidence checks mounted DMG app identity" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'require_exact_evidence_field "$DMG_INFO" "Mounted CDHash" "$actual_cdhash" "DMG"'

expect_script_contains \
  "release evidence rejects stale DMG evidence without DMG" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "DMG evidence or checksum exists, but dist/Hazakura Wallpaper.dmg is missing."

expect_script_contains \
  "release evidence rejects stale top-level signing evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Stale top-level signing evidence exists outside dist/release-evidence"

expect_script_contains \
  "release evidence requires signing evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Signing evidence missing required line containing"

expect_script_contains \
  "release evidence requires empty entitlements evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Entitlements evidence must be empty because the public app has no entitlements."

expect_script_contains \
  "release evidence requires Mach-O evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Mach-O evidence missing required line containing"

expect_script_contains \
  "distribution readiness requires universal app architectures" \
  "$ROOT_DIR/scripts/check_distribution_readiness.sh" \
  "Release app must be universal for public distribution"

expect_script_contains \
  "build app requests Universal Xcode architectures" \
  "$ROOT_DIR/scripts/build_app.sh" \
  'XCODE_ARCHS="${XCODE_ARCHS:-arm64 x86_64}"'

expect_script_contains \
  "release metadata requires Release standard architectures" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  'Xcode Release configurations must use ARCHS = "$(ARCHS_STANDARD)" for Universal public builds.'

expect_script_contains \
  "release metadata requires Release all architectures" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Xcode Release configurations must set ONLY_ACTIVE_ARCH = NO for Universal public builds."

expect_script_contains \
  "release metadata pins public executable name" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "CFBundleExecutable must be HazakuraWallpaper for the public app bundle."

expect_script_contains \
  "release metadata pins SwiftPM public executable product" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  'Package.swift must expose the public executable product as HazakuraWallpaper'

expect_script_contains \
  "release metadata pins SwiftPM package name" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Package.swift package name must be hazakura-wallpaper"

expect_script_contains \
  "release metadata pins package.json package name" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "package.json name must be hazakura-wallpaper"

expect_script_contains \
  "release metadata reads app target Sources build phase" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Xcode app target Sources build phase is missing."

expect_script_contains \
  "release metadata checks Xcode distributable Swift source membership" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Xcode project is missing distributable Swift source files:"

expect_script_contains \
  "release metadata rejects duplicate distributable Swift basenames" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Distributable Swift source files must have unique basenames for Xcode membership checks:"

expect_script_contains \
  "release metadata rejects unexpected Xcode Swift sources" \
  "$ROOT_DIR/scripts/check_release_metadata.sh" \
  "Xcode project includes Swift source files outside the distributable app source set:"

expect_script_contains \
  "release evidence requires current Gatekeeper evidence path" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Gatekeeper evidence does not refer to the current app path"

expect_script_contains \
  "release evidence requires Gatekeeper assessment result" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Gatekeeper evidence does not contain an assessment result."

expect_script_contains \
  "release evidence report records final notarized ZIP state" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'echo "Final notarized ZIP verified: $manifest_final_zip_verified"'

expect_script_contains \
  "release evidence report records pre-final evidence absence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  'echo "Final-only evidence: absent"'

expect_script_contains \
  "manifest always lists release evidence check report" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  'echo "- dist/release-evidence/release-evidence-check.txt"'

expect_script_contains \
  "manifest recommends missing bundle-open verification as an external check" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "Normal-session bundle-open verification is recommended before sharing."

expect_script_contains \
  "manifest recommends missing visual QA acceptance as an external check" \
  "$ROOT_DIR/scripts/write_release_manifest.sh" \
  "Human visual pass for all modes and intensity levels is recommended before sharing."

expect_script_contains \
  "release evidence requires manifest-listed release evidence check report" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "- dist/release-evidence/release-evidence-check.txt"

expect_script_contains \
  "release evidence report lists publish readiness blockers" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Publish readiness blockers from release evidence:"

expect_script_contains \
  "release evidence report recommends bundle-open check" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Normal-session bundle-open verification remains recommended before sharing."

expect_script_contains \
  "release evidence report recommends visual QA" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Human visual QA remains recommended before sharing."

expect_script_contains \
  "preview artifact check records visible alpha pixels" \
  "$ROOT_DIR/scripts/check_preview_artifacts.sh" \
  "visible alpha pixels:"

expect_script_contains \
  "preview artifact check records nonzero color channels" \
  "$ROOT_DIR/scripts/check_preview_artifacts.sh" \
  "nonzero color channels:"

expect_script_contains \
  "preview artifact check rejects duplicate preview output" \
  "$ROOT_DIR/scripts/check_preview_artifacts.sh" \
  "Preview visual diversity failed"

expect_script_contains \
  "release evidence requires preview visual diversity evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Preview visual diversity checks passed."

expect_script_contains \
  "release evidence requires preview content evidence" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "Preview content evidence missing required line containing visible alpha pixels and nonzero color channels:"

expect_script_contains \
  "release evidence checks preview content per preview line" \
  "$ROOT_DIR/scripts/check_release_evidence.sh" \
  "require_preview_content_line"

expect_script_contains \
  "notarization script records final ZIP CDHash evidence" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'echo "CDHash: $(codesign -dvvv "$EXTRACTED_APP"'

expect_script_contains \
  "notarization script records final ZIP archive evidence" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'echo "Verified archive: dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "notarization script records final ZIP architecture evidence" \
  "$ROOT_DIR/scripts/notarize_release_zip.sh" \
  'echo "Architectures: $(lipo -archs "$EXTRACTED_APP/Contents/MacOS/HazakuraWallpaper")"'

expect_script_contains \
  "DMG packaging refreshes ZIP after default rebuild" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'SAKURA_SKY_PACKAGE_EXISTING_APP=1 "$ROOT_DIR/scripts/package_zip.sh" >/dev/null'

expect_script_contains \
  "DMG packaging leaves release evidence consistent" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'run_release_evidence_check'

expect_script_contains \
  "DMG packaging checks release draft after DMG evidence" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'run_github_release_notes_check'

expect_script_contains \
  "DMG packaging suppresses successful nested distribution diagnostics" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$ROOT_DIR/scripts/check_distribution_readiness.sh" "$app_path" >/dev/null 2>&1'

expect_script_contains \
  "DMG packaging reruns distribution diagnostics on failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  "Distribution readiness failed for app:"

expect_script_contains \
  "DMG packaging suppresses successful nested release evidence diagnostics" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1'

expect_script_contains \
  "DMG packaging reruns release evidence diagnostics on failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  "Release evidence check failed after DMG packaging; showing diagnostics."

expect_script_contains \
  "DMG packaging suppresses successful nested release draft diagnostics" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$ROOT_DIR/scripts/check_github_release_notes.sh" >/dev/null 2>&1'

expect_script_contains \
  "DMG packaging reruns release draft diagnostics on failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  "GitHub release draft check failed after DMG packaging; showing diagnostics."

expect_script_contains \
  "DMG packaging removes inconsistent artifact on release evidence failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'DMG release evidence failed; removed DMG and DMG evidence for the inconsistent artifact.'

expect_script_contains \
  "DMG packaging removes inconsistent artifact on release draft failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'DMG GitHub release draft check failed; removed DMG and DMG evidence for the inconsistent artifact.'

expect_script_contains \
  "DMG packaging cleanup removes stale DMG evidence" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  'rm -f "$DMG_PATH" "$DMG_INFO"'

expect_script_contains \
  "DMG packaging cleanup refreshes manifest after failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null 2>&1 || true'

expect_script_contains \
  "DMG packaging cleanup refreshes release evidence after failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1 || true'

expect_script_contains \
  "DMG packaging cleanup refreshes release draft after failure" \
  "$ROOT_DIR/scripts/package_dmg.sh" \
  '"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null 2>&1 || true'

expect_script_contains \
  "bundle-open recorder anchors the actual executable process" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  '/usr/bin/pgrep -f "$APP_EXECUTABLE_PATTERN"'

expect_script_contains \
  "bundle-open recorder supports public settle-seconds alias" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'HAZAKURA_WALLPAPER_BUNDLE_OPEN_SETTLE_SECONDS'

expect_script_contains \
  "bundle-open recorder writes bundle ID evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'echo "Bundle ID: $bundle_identifier"'

expect_script_contains \
  "bundle-open recorder writes architecture evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'echo "Architectures: $mach_o_architectures"'

expect_script_contains \
  "bundle-open recorder writes timestamp evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'echo "Verified at: $created_at"'

expect_script_contains \
  "bundle-open recorder uses UTC timestamp format" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  "date -u '+%Y-%m-%dT%H:%M:%SZ'"

expect_script_contains \
  "bundle-open recorder writes CDHash evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'echo "CDHash: $app_cdhash"'

expect_script_contains \
  "bundle-open recorder requires final ZIP bundle ID evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'require_exact_final_zip_field "Bundle ID" "$bundle_identifier"'

expect_script_contains \
  "bundle-open recorder requires final ZIP archive evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'require_exact_final_zip_field "Verified archive" "dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "bundle-open recorder requires final ZIP architecture evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'require_exact_final_zip_field "Architectures" "$mach_o_architectures"'

expect_script_contains \
  "bundle-open recorder requires final ZIP CDHash evidence" \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" \
  'require_exact_final_zip_field "CDHash" "$app_cdhash"'

expect_script_contains \
  "visual QA recorder writes bundle ID evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'echo "Bundle ID: $bundle_identifier"'

expect_script_contains \
  "visual QA recorder writes architecture evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'echo "Architectures: $mach_o_architectures"'

expect_script_contains \
  "visual QA recorder writes timestamp evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'echo "Accepted at: $created_at"'

expect_script_contains \
  "visual QA recorder uses UTC timestamp format" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  "date -u '+%Y-%m-%dT%H:%M:%SZ'"

expect_script_contains \
  "visual QA recorder writes CDHash evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'echo "CDHash: $app_cdhash"'

expect_script_contains \
  "visual QA recorder writes checklist checksum evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'echo "Checklist SHA-256: $qa_checklist_sha"'

expect_script_contains \
  "visual QA recorder writes checklist completion evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'echo "Checklist completed: yes"'

expect_script_contains \
  "visual QA recorder requires explicit checklist-complete flag" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  "Refusing to record visual QA without --checklist-complete."

expect_script_contains \
  "visual QA recorder requires final ZIP bundle ID evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'require_exact_final_zip_field "Bundle ID" "$bundle_identifier"'

expect_script_contains \
  "visual QA recorder requires final ZIP archive evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'require_exact_final_zip_field "Verified archive" "dist/Hazakura Wallpaper.zip"'

expect_script_contains \
  "visual QA recorder requires final ZIP architecture evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'require_exact_final_zip_field "Architectures" "$mach_o_architectures"'

expect_script_contains \
  "visual QA recorder requires final ZIP CDHash evidence" \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" \
  'require_exact_final_zip_field "CDHash" "$app_cdhash"'

expect_command_failure \
  "blank bundle-open operator" \
  "Refusing to record bundle-open verification with an empty or multi-line --operator value." \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" --operator "   "

expect_command_failure \
  "multi-line bundle-open operator" \
  "Refusing to record bundle-open verification with an empty or multi-line --operator value." \
  "$ROOT_DIR/scripts/record_bundle_open_verification.sh" --operator $'Operator\nName'

expect_command_failure \
  "blank visual QA reviewer" \
  "Refusing to record visual QA with an empty or multi-line --reviewer value." \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" --dry-run --accepted --checklist-complete --reviewer "   "

expect_command_failure \
  "multi-line visual QA reviewer" \
  "Refusing to record visual QA with an empty or multi-line --reviewer value." \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" --dry-run --accepted --checklist-complete --reviewer $'Reviewer\nName'

expect_command_failure \
  "visual QA checklist-complete flag is required" \
  "Refusing to record visual QA without --checklist-complete." \
  "$ROOT_DIR/scripts/record_visual_qa_acceptance.sh" --dry-run --accepted --reviewer "QA Reviewer"

"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null

manifest_final_zip_verified="$(awk -F': ' '/^- Final notarized ZIP verified:/ { print $2; exit }' "$MANIFEST_PATH")"
if [[ "$manifest_final_zip_verified" != "no" ]]; then
  echo "Release evidence guard tests are pre-final checks; refusing to run after final notarized ZIP verification is complete." >&2
  exit 2
fi

cleanup() {
  if [[ -f "$ICON_INFO_BACKUP" ]]; then
    cp "$ICON_INFO_BACKUP" "$ICON_INFO"
    rm -f "$ICON_INFO_BACKUP"
  fi
  if [[ -f "$SHA_BACKUP" ]]; then
    cp "$SHA_BACKUP" "$SHA_PATH"
    rm -f "$SHA_BACKUP"
  fi
  if [[ -f "$PREVIEW_DETERMINISM_BACKUP" ]]; then
    cp "$PREVIEW_DETERMINISM_BACKUP" "$PREVIEW_DETERMINISM"
    rm -f "$PREVIEW_DETERMINISM_BACKUP"
  fi
  if [[ -f "$NOTES_BACKUP" ]]; then
    cp "$NOTES_BACKUP" "$NOTES_PATH"
    rm -f "$NOTES_BACKUP"
  fi

  rm -f \
    "$FINAL_ZIP_VERIFY_LOG" \
    "$NOTARY_LOG" \
    "$NOTARY_FAILED_LOG" \
    "$STAPLER_FAILED_LOG" \
    "$SPCTL_AFTER_NOTARIZATION_FAILED" \
    "$FINAL_ZIP_VERIFY_FAILED_LOG" \
    "$BUNDLE_OPEN_LOG" \
    "$VISUAL_QA_LOG" \
    "$UNSIGNED_BUNDLE_OPEN_LOG" \
    "$UNSIGNED_VISUAL_QA_LOG" \
    "$UNSIGNED_MEMORY_LOG" \
    "$FAIL_STDOUT" \
    "$FAIL_STDERR"
  "$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
}
trap cleanup EXIT

zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
bundle_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
mach_o_architectures="$(lipo -archs "$APP_PATH/Contents/MacOS/HazakuraWallpaper")"
app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"

if [[ -z "$bundle_identifier" || -z "$mach_o_architectures" || -z "$app_cdhash" ]]; then
  echo "Could not read current app identity, architectures, or CDHash for release evidence guard tests." >&2
  exit 1
fi

cp "$ICON_INFO" "$ICON_INFO_BACKUP"
cp "$SHA_PATH" "$SHA_BACKUP"
cp "$PREVIEW_DETERMINISM" "$PREVIEW_DETERMINISM_BACKUP"
cp "$NOTES_PATH" "$NOTES_BACKUP"

{
  cat "$NOTES_BACKUP"
  echo "Status: Ready to share"
} >"$NOTES_PATH"
expect_command_failure \
  "GitHub release notes reject mixed status lines" \
  "GitHub release notes must contain exactly one status line" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh"

awk '{
  if ($0 ~ /^# Hazakura Wallpaper .* Release Candidate$/) {
    sub(/ Release Candidate$/, "")
  }
  if ($0 == "Status: Release candidate") {
    print "Status: Ready to share"
  } else {
    print
  }
}' "$NOTES_BACKUP" >"$NOTES_PATH"
expect_command_failure \
  "GitHub release notes reject premature ready status" \
  "GitHub release notes must not claim Ready to share before share evidence exists" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh"

awk -v version="$bundle_version" '{
  if ($0 == "# Hazakura Wallpaper " version " Release Candidate") {
    print "# Hazakura Wallpaper " version
  } else {
    print
  }
}' "$NOTES_BACKUP" >"$NOTES_PATH"
expect_command_failure \
  "GitHub release notes reject candidate status without candidate title" \
  "GitHub release notes must contain exact line: # Hazakura Wallpaper $bundle_version Release Candidate" \
  "$ROOT_DIR/scripts/check_github_release_notes.sh"

cp "$NOTES_BACKUP" "$NOTES_PATH"

awk '/  dist\/Hazakura Wallpaper\.zip$/ { print; exit }' "$SHA_BACKUP" >>"$SHA_PATH"
expect_release_evidence_failure \
  "duplicate ZIP checksum evidence" \
  "SHA256SUMS must contain exactly one checksum for dist/Hazakura Wallpaper.zip."
cp "$SHA_BACKUP" "$SHA_PATH"
rm -f "$SHA_BACKUP"

awk '/^- dist\/previews\/sakura\.png:/ { print; exit }' "$PREVIEW_DETERMINISM_BACKUP" >>"$PREVIEW_DETERMINISM"
expect_release_evidence_failure \
  "duplicate preview determinism evidence" \
  "Preview determinism evidence must contain exactly one checksum for dist/previews/sakura.png."
cp "$PREVIEW_DETERMINISM_BACKUP" "$PREVIEW_DETERMINISM"
rm -f "$PREVIEW_DETERMINISM_BACKUP"

{
  echo "Icon checks passed."
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "CDHash: stale-icon-cdhash"
  echo "App icon: Contents/Resources/icon.icns"
  echo "Mac OS X icon"
  echo "Status icon: Contents/Resources/icon.png"
  echo "PNG image data"
  echo "Status icon dimensions: 1024x1024"
} >"$ICON_INFO"
expect_release_evidence_failure \
  "stale icon evidence" \
  "Icon evidence missing required line containing: CDHash: $app_cdhash"
cleanup
trap cleanup EXIT

printf '\n- dist/release-evidence/final-zip-verify.log\n' >>"$MANIFEST_PATH"
expect_release_evidence_failure \
  "premature final-only manifest listing" \
  "Manifest lists final-only evidence before final notarized ZIP verification is complete"

"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "Final notarized ZIP verification passed."
  echo "Final ZIP SHA-256: $zip_sha"
} >"$FINAL_ZIP_VERIFY_LOG"
expect_release_evidence_failure \
  "premature final ZIP verification log" \
  "Final-only evidence exists before final notarized ZIP verification is complete"

rm -f "$FINAL_ZIP_VERIFY_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "status: Accepted"
} >"$NOTARY_LOG"
expect_release_evidence_failure \
  "premature notary evidence" \
  "Final-only evidence exists before final notarized ZIP verification is complete"

rm -f "$NOTARY_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "status: Invalid"
} >"$NOTARY_FAILED_LOG"
expect_release_evidence_failure \
  "stale failed notary attempt evidence" \
  "Stale notarization attempt evidence exists outside canonical final evidence"

expect_command_failure \
  "publish readiness rejects stale failed notary attempt evidence" \
  "Publish readiness failed: stale notarization attempt evidence exists outside canonical final evidence" \
  "$ROOT_DIR/scripts/check_publish_readiness.sh"

rm -f "$NOTARY_FAILED_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "Bundle open verified: yes"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "ZIP SHA-256: $zip_sha"
} >"$BUNDLE_OPEN_LOG"
expect_release_evidence_failure \
  "premature bundle-open evidence" \
  "Final-only evidence exists before final notarized ZIP verification is complete"

rm -f "$BUNDLE_OPEN_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "Visual QA accepted: yes"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "ZIP SHA-256: $zip_sha"
} >"$VISUAL_QA_LOG"
expect_release_evidence_failure \
  "premature visual QA evidence" \
  "Final-only evidence exists before final notarized ZIP verification is complete"

rm -f "$VISUAL_QA_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "Unsigned bundle open verified: yes"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "ZIP SHA-256: $zip_sha"
} >"$UNSIGNED_BUNDLE_OPEN_LOG"
expect_release_evidence_failure \
  "incomplete unsigned bundle-open evidence" \
  "Unsigned bundle-open verification evidence must contain exactly one field: Bundle ID"

rm -f "$UNSIGNED_BUNDLE_OPEN_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "Unsigned memory check passed: yes"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "ZIP SHA-256: $zip_sha"
} >"$UNSIGNED_MEMORY_LOG"
expect_release_evidence_failure \
  "incomplete unsigned memory evidence" \
  "Unsigned memory check evidence must contain exactly one field: Bundle ID"

rm -f "$UNSIGNED_MEMORY_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
{
  echo "Unsigned visual QA accepted: yes"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "ZIP SHA-256: $zip_sha"
} >"$UNSIGNED_VISUAL_QA_LOG"
expect_release_evidence_failure \
  "incomplete unsigned visual QA evidence" \
  "Unsigned visual QA acceptance evidence must contain exactly one field: Bundle ID"

cleanup
trap - EXIT
"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null

checked_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TEMP_GUARD_REPORT="$(mktemp "$EVIDENCE_DIR/release-evidence-guard-tests.XXXXXX")"
{
  echo "Release evidence guard tests passed: yes"
  echo "Bundle ID: $bundle_identifier"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "Architectures: $mach_o_architectures"
  echo "CDHash: $app_cdhash"
  echo "ZIP SHA-256: $zip_sha"
  echo "Checked at: $checked_at"
  echo "Checked command: ./scripts/test_release_evidence_guards.sh"
  echo "Duplicate preview fixture rejection: passed"
} >"$TEMP_GUARD_REPORT"
mv "$TEMP_GUARD_REPORT" "$GUARD_TESTS_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null

echo "Release evidence guard tests passed."
