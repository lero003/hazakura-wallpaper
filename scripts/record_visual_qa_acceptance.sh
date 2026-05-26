#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
QA_CHECKLIST="$ROOT_DIR/docs/RELEASE_QA.md"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
MANIFEST_PATH="$EVIDENCE_DIR/RELEASE_MANIFEST.md"
FINAL_ZIP_VERIFY_LOG="$EVIDENCE_DIR/final-zip-verify.log"
VISUAL_QA_LOG="$EVIDENCE_DIR/visual-qa-accepted.txt"
DRY_RUN=0
ACCEPTED=0
CHECKLIST_COMPLETE=0
REVIEWER=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer "Reviewer Name"
  ./scripts/record_visual_qa_acceptance.sh --dry-run --accepted --checklist-complete --reviewer "Reviewer Name"

Run this only after a human has completed docs/RELEASE_QA.md for the final ZIP.
It records the current app bundle ID, version, build, CDHash, and ZIP SHA-256
plus the release QA checklist checksum, so publish readiness can prove the
visual QA acceptance belongs to the exact artifact and checklist being uploaded.
Writing the evidence requires the current ZIP to be the notarized final ZIP.
Use --dry-run to preview the evidence format before notarization is complete.
The --checklist-complete flag is an explicit human assertion that every
applicable item in docs/RELEASE_QA.md was reviewed before acceptance.
The reviewer value should identify the human who completed the checklist.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --accepted)
      ACCEPTED=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --checklist-complete)
      CHECKLIST_COMPLETE=1
      ;;
    --reviewer)
      shift
      if [[ $# -eq 0 || -z "${1:-}" ]]; then
        echo "--reviewer requires a non-empty value." >&2
        usage >&2
        exit 2
      fi
      REVIEWER="$1"
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

if [[ "$ACCEPTED" != "1" ]]; then
  echo "Refusing to record visual QA without --accepted." >&2
  usage >&2
  exit 2
fi

if [[ "$CHECKLIST_COMPLETE" != "1" ]]; then
  echo "Refusing to record visual QA without --checklist-complete." >&2
  usage >&2
  exit 2
fi

if [[ -z "$REVIEWER" ]]; then
  echo "Refusing to record visual QA without --reviewer." >&2
  usage >&2
  exit 2
fi

if [[ "$REVIEWER" =~ [[:cntrl:]] || ! "$REVIEWER" =~ [^[:space:]] ]]; then
  echo "Refusing to record visual QA with an empty or multi-line --reviewer value." >&2
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
    echo "Refusing to record visual QA because final ZIP verification must contain exactly one field: $label" >&2
    exit 1
  fi

  if [[ "$value" != "$expected" ]]; then
    echo "Refusing to record visual QA because final ZIP verification has an unexpected field value for $label." >&2
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
    echo "Refusing to record visual QA because final ZIP verification must contain exactly one line: $expected_line" >&2
    exit 1
  fi
}

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Missing ZIP archive: $ZIP_PATH" >&2
  exit 1
fi

if [[ ! -s "$QA_CHECKLIST" ]]; then
  echo "Missing release QA checklist: $QA_CHECKLIST" >&2
  exit 1
fi

bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
bundle_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
app_cdhash="$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F= '/^CDHash=/{ print $2; exit }')"
mach_o_architectures="$(lipo -archs "$APP_PATH/Contents/MacOS/HazakuraWallpaper")"
zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
qa_checklist_sha="$(shasum -a 256 "$QA_CHECKLIST" | awk '{ print $1 }')"
created_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

if [[ -z "$app_cdhash" || -z "$mach_o_architectures" ]]; then
  echo "Could not read app CDHash or Mach-O architectures: $APP_PATH" >&2
  exit 1
fi

write_report() {
  echo "Visual QA accepted: yes"
  echo "Bundle ID: $bundle_identifier"
  echo "Version: $bundle_version"
  echo "Build: $bundle_build"
  echo "Architectures: $mach_o_architectures"
  echo "CDHash: $app_cdhash"
  echo "ZIP SHA-256: $zip_sha"
  echo "Accepted at: $created_at"
  echo "Reviewer: $REVIEWER"
  echo "Checklist: docs/RELEASE_QA.md"
  echo "Checklist completed: yes"
  echo "Checklist SHA-256: $qa_checklist_sha"
  echo "Accepted command: ./scripts/record_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>"
}

if [[ "$DRY_RUN" == "1" ]]; then
  write_report
  exit 0
fi

"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null

if ! grep -Fq -- "- Final notarized ZIP verified: yes" "$MANIFEST_PATH"; then
  echo "Refusing to record visual QA before final notarized ZIP verification is complete." >&2
  exit 1
fi

if [[ ! -s "$FINAL_ZIP_VERIFY_LOG" ]]; then
  echo "Refusing to record visual QA because final ZIP verification does not prove the current ZIP." >&2
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

mkdir -p "$EVIDENCE_DIR"
TEMP_REPORT="$(mktemp "$EVIDENCE_DIR/visual-qa-accepted.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"' EXIT
write_report >"$TEMP_REPORT"
mv "$TEMP_REPORT" "$VISUAL_QA_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
cat "$VISUAL_QA_LOG"
