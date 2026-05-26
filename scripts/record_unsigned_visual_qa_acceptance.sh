#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
QA_CHECKLIST="$ROOT_DIR/docs/RELEASE_QA.md"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
VISUAL_QA_LOG="$EVIDENCE_DIR/unsigned-visual-qa-accepted.txt"
DRY_RUN=0
ACCEPTED=0
CHECKLIST_COMPLETE=0
REVIEWER=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/record_unsigned_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer "Reviewer Name"
  ./scripts/record_unsigned_visual_qa_acceptance.sh --dry-run --accepted --checklist-complete --reviewer "Reviewer Name"

Run this after a human completes docs/RELEASE_QA.md for the unsigned GitHub/DMG
release candidate. It records app identity, CDHash, ZIP SHA-256, and checklist
SHA-256 so visual acceptance stays tied to the exact artifact reviewed.
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

if [[ "$ACCEPTED" != "1" || "$CHECKLIST_COMPLETE" != "1" || -z "$REVIEWER" ]]; then
  echo "Refusing to record unsigned visual QA without --accepted, --checklist-complete, and --reviewer." >&2
  usage >&2
  exit 2
fi

if [[ "$REVIEWER" =~ [[:cntrl:]] || ! "$REVIEWER" =~ [^[:space:]] ]]; then
  echo "Refusing to record unsigned visual QA with an empty or multi-line --reviewer value." >&2
  usage >&2
  exit 2
fi

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
  echo "Unsigned visual QA accepted: yes"
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
  echo "Accepted command: ./scripts/record_unsigned_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer <reviewer>"
}

run_release_evidence_check() {
  if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
    echo "Release evidence check failed; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
  fi
}

if [[ "$DRY_RUN" == "1" ]]; then
  write_report
  exit 0
fi

run_release_evidence_check
mkdir -p "$EVIDENCE_DIR"
TEMP_REPORT="$(mktemp "$EVIDENCE_DIR/unsigned-visual-qa-accepted.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"' EXIT
write_report >"$TEMP_REPORT"
mv "$TEMP_REPORT" "$VISUAL_QA_LOG"
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
run_release_evidence_check
cat "$VISUAL_QA_LOG"
