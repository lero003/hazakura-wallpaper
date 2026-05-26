#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"
DMG_INFO="$EVIDENCE_DIR/dmg-info.txt"
UNSIGNED_BUNDLE_OPEN_LOG="$EVIDENCE_DIR/unsigned-bundle-open-verified.txt"
UNSIGNED_MEMORY_LOG="$EVIDENCE_DIR/unsigned-memory-check.txt"
UNSIGNED_VISUAL_QA_LOG="$EVIDENCE_DIR/unsigned-visual-qa-accepted.txt"
OPERATOR=""
REVIEWER=""
ACCEPTED=0
CHECKLIST_COMPLETE=0
CLEANUP_ON_FAILURE=0
FINALIZE_SUCCEEDED=0
HAD_UNSIGNED_BUNDLE_OPEN_LOG=0
HAD_UNSIGNED_MEMORY_LOG=0
HAD_UNSIGNED_VISUAL_QA_LOG=0
HAD_DMG_PATH=0
HAD_DMG_INFO=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/finalize_unsigned_share.sh --operator "Operator Name" --reviewer "Reviewer Name" --accepted --checklist-complete

Run this in a normal macOS user session after `npm run release:candidate` has
prepared the unsigned release candidate and a human completes docs/RELEASE_QA.md
against the current dist/Hazakura Wallpaper.app. It does not rebuild the app or
ZIP. It validates the existing candidate, creates the DMG from that candidate,
records LaunchServices bundle-open evidence, records leaks memory evidence,
records human visual QA acceptance, then runs the strict share-readiness gate.
USAGE
}

cleanup_partial_evidence() {
  if [[ "$CLEANUP_ON_FAILURE" != "1" || "$FINALIZE_SUCCEEDED" == "1" ]]; then
    return
  fi

  if [[ "$HAD_UNSIGNED_BUNDLE_OPEN_LOG" != "1" ]]; then
    rm -f "$UNSIGNED_BUNDLE_OPEN_LOG"
  fi
  if [[ "$HAD_UNSIGNED_MEMORY_LOG" != "1" ]]; then
    rm -f "$UNSIGNED_MEMORY_LOG"
  fi
  if [[ "$HAD_UNSIGNED_VISUAL_QA_LOG" != "1" ]]; then
    rm -f "$UNSIGNED_VISUAL_QA_LOG"
  fi
  if [[ "$HAD_DMG_PATH" != "1" ]]; then
    rm -f "$DMG_PATH"
  fi
  if [[ "$HAD_DMG_INFO" != "1" ]]; then
    rm -f "$DMG_INFO"
  fi

  if [[ -d "$ROOT_DIR/dist/Hazakura Wallpaper.app" && -f "$ROOT_DIR/dist/Hazakura Wallpaper.zip" ]]; then
    "$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null 2>&1 || true
    "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1 || true
    "$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null 2>&1 || true
  fi
}

run_publish_readiness_check() {
  if ! "$ROOT_DIR/scripts/check_publish_readiness.sh" >/dev/null 2>&1; then
    echo "Publish readiness check failed; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_publish_readiness.sh" >/dev/null
  fi
}

run_release_evidence_check() {
  if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
    echo "Release evidence check failed; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
  fi
}

trap cleanup_partial_evidence EXIT

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
    --reviewer)
      shift
      if [[ $# -eq 0 || -z "${1:-}" ]]; then
        echo "--reviewer requires a non-empty value." >&2
        usage >&2
        exit 2
      fi
      REVIEWER="$1"
      ;;
    --accepted)
      ACCEPTED=1
      ;;
    --checklist-complete)
      CHECKLIST_COMPLETE=1
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

if [[ -z "$OPERATOR" || -z "$REVIEWER" || "$ACCEPTED" != "1" || "$CHECKLIST_COMPLETE" != "1" ]]; then
  echo "Refusing to finalize unsigned share without --operator, --reviewer, --accepted, and --checklist-complete." >&2
  usage >&2
  exit 2
fi

if [[ "$OPERATOR" =~ [[:cntrl:]] || ! "$OPERATOR" =~ [^[:space:]] ]]; then
  echo "Refusing to finalize unsigned share with an empty or multi-line --operator value." >&2
  usage >&2
  exit 2
fi

if [[ "$REVIEWER" =~ [[:cntrl:]] || ! "$REVIEWER" =~ [^[:space:]] ]]; then
  echo "Refusing to finalize unsigned share with an empty or multi-line --reviewer value." >&2
  usage >&2
  exit 2
fi

cd "$ROOT_DIR"

if [[ -s "$UNSIGNED_BUNDLE_OPEN_LOG" ]]; then
  HAD_UNSIGNED_BUNDLE_OPEN_LOG=1
fi
if [[ -s "$UNSIGNED_MEMORY_LOG" ]]; then
  HAD_UNSIGNED_MEMORY_LOG=1
fi
if [[ -s "$UNSIGNED_VISUAL_QA_LOG" ]]; then
  HAD_UNSIGNED_VISUAL_QA_LOG=1
fi
if [[ -s "$DMG_PATH" ]]; then
  HAD_DMG_PATH=1
fi
if [[ -s "$DMG_INFO" ]]; then
  HAD_DMG_INFO=1
fi
CLEANUP_ON_FAILURE=1

"$ROOT_DIR/scripts/check_unsigned_share_prerequisites.sh" --strict-normal-session >/dev/null
run_publish_readiness_check
run_release_evidence_check
HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 SAKURA_SKY_PACKAGE_EXISTING_APP=1 "$ROOT_DIR/scripts/package_dmg.sh"
"$ROOT_DIR/scripts/record_unsigned_bundle_open_verification.sh" --operator "$OPERATOR"
"$ROOT_DIR/scripts/record_unsigned_memory_check.sh" --operator "$OPERATOR"
"$ROOT_DIR/scripts/record_unsigned_visual_qa_acceptance.sh" --accepted --checklist-complete --reviewer "$REVIEWER"
"$ROOT_DIR/scripts/check_share_readiness.sh"
FINALIZE_SUCCEEDED=1
