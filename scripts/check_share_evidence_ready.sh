#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
DMG_INFO="$EVIDENCE_DIR/dmg-info.txt"
BUNDLE_OPEN_LOG="$EVIDENCE_DIR/bundle-open-verified.txt"
VISUAL_QA_LOG="$EVIDENCE_DIR/visual-qa-accepted.txt"
UNSIGNED_BUNDLE_OPEN_LOG="$EVIDENCE_DIR/unsigned-bundle-open-verified.txt"
UNSIGNED_VISUAL_QA_LOG="$EVIDENCE_DIR/unsigned-visual-qa-accepted.txt"
UNSIGNED_MEMORY_LOG="$EVIDENCE_DIR/unsigned-memory-check.txt"

cd "$ROOT_DIR"

if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
  echo "Share evidence failed: release evidence did not pass." >&2
  exit 1
fi

missing=()

require_file() {
  local path="$1"
  local description="$2"
  local command_hint="$3"

  if [[ ! -s "$path" ]]; then
    missing+=("$description: $command_hint")
  fi
}

if [[ ! -d "$APP_PATH" ]]; then
  missing+=("app bundle: run ./scripts/prepare_release_candidate.sh")
fi

require_file "$ZIP_PATH" "ZIP artifact" "run ./scripts/prepare_release_candidate.sh"
require_file "$DMG_PATH" "DMG artifact" "run HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh in a normal macOS session"
require_file "$DMG_INFO" "DMG evidence" "run HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh in a normal macOS session"

if [[ ! -s "$BUNDLE_OPEN_LOG" && ! -s "$UNSIGNED_BUNDLE_OPEN_LOG" ]]; then
  missing+=("normal-session bundle-open evidence: run ./scripts/record_unsigned_bundle_open_verification.sh --operator \"Operator Name\"")
fi

if [[ ! -s "$VISUAL_QA_LOG" && ! -s "$UNSIGNED_VISUAL_QA_LOG" ]]; then
  missing+=("human visual QA evidence: run ./scripts/record_unsigned_visual_qa_acceptance.sh --accepted --checklist-complete --reviewer \"Reviewer Name\"")
fi

require_file "$UNSIGNED_MEMORY_LOG" "normal-session leaks memory evidence" "run ./scripts/record_unsigned_memory_check.sh --operator \"Operator Name\" in a normal macOS session"

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "Share readiness failed: the artifact is not ready to hand to users yet." >&2
  printf -- '- %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "Share evidence checks passed."
