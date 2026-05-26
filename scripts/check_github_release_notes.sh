#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"
NOTES_PATH="$ROOT_DIR/dist/release-evidence/GITHUB_RELEASE_DRAFT.md"
GUARD_TESTS="$ROOT_DIR/dist/release-evidence/release-evidence-guard-tests.txt"
DMG_INFO="$ROOT_DIR/dist/release-evidence/dmg-info.txt"
BUNDLE_OPEN="$ROOT_DIR/dist/release-evidence/bundle-open-verified.txt"
VISUAL_QA="$ROOT_DIR/dist/release-evidence/visual-qa-accepted.txt"
UNSIGNED_BUNDLE_OPEN="$ROOT_DIR/dist/release-evidence/unsigned-bundle-open-verified.txt"
UNSIGNED_VISUAL_QA="$ROOT_DIR/dist/release-evidence/unsigned-visual-qa-accepted.txt"
UNSIGNED_MEMORY="$ROOT_DIR/dist/release-evidence/unsigned-memory-check.txt"

cd "$ROOT_DIR"

for path in "$APP_PATH" "$ZIP_PATH" "$NOTES_PATH"; do
  if [[ ! -s "$path" ]]; then
    echo "Missing GitHub release notes input or output: $path" >&2
    exit 1
  fi
done

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
status_line_count="$(grep -Fxc "Status: Ready to share" "$NOTES_PATH" || true)"
candidate_status_count="$(grep -Fxc "Status: Release candidate" "$NOTES_PATH" || true)"
total_status_count=$((status_line_count + candidate_status_count))

require_contains() {
  local text="$1"
  if ! grep -Fq "$text" "$NOTES_PATH"; then
    echo "GitHub release notes must contain: $text" >&2
    exit 1
  fi
}

require_absent() {
  local text="$1"
  if grep -Fq "$text" "$NOTES_PATH"; then
    echo "GitHub release notes must not mention old public product name: $text" >&2
    exit 1
  fi
}

require_exact_line() {
  local text="$1"
  if ! grep -Fxq "$text" "$NOTES_PATH"; then
    echo "GitHub release notes must contain exact line: $text" >&2
    exit 1
  fi
}

require_no_exact_line() {
  local text="$1"
  if grep -Fxq "$text" "$NOTES_PATH"; then
    echo "GitHub release notes must not contain exact line: $text" >&2
    exit 1
  fi
}

require_contains "Hazakura Wallpaper $version"
require_contains "Build: $build"
require_contains "Bundle ID: $bundle_id"
require_contains "Hazakura Wallpaper.zip"
require_contains "SHA-256: $zip_sha"
require_contains "docs/INSTALL.md"
require_contains "Gatekeeper"
require_contains "./scripts/check_publish_readiness.sh"
require_contains "npm run share:preflight:strict"
require_contains "npm run share:unsigned"
require_contains "npm run share:check"
require_contains "PRIVACY.md"
require_contains "SECURITY.md"
require_absent "Sakura Sky"

if [[ "$total_status_count" -ne 1 ]]; then
  echo "GitHub release notes must contain exactly one status line: Status: Release candidate or Status: Ready to share." >&2
  exit 1
fi

if [[ "$status_line_count" -gt 0 ]]; then
  require_exact_line "# Hazakura Wallpaper $version"
  require_no_exact_line "# Hazakura Wallpaper $version Release Candidate"
  for path in "$DMG_PATH" "$DMG_INFO" "$UNSIGNED_MEMORY"; do
    if [[ ! -s "$path" ]]; then
      echo "GitHub release notes must not claim Ready to share before share evidence exists: $path" >&2
      exit 1
    fi
  done
  if [[ ! -s "$BUNDLE_OPEN" && ! -s "$UNSIGNED_BUNDLE_OPEN" ]]; then
    echo "GitHub release notes must not claim Ready to share before bundle-open evidence exists." >&2
    exit 1
  fi
  if [[ ! -s "$VISUAL_QA" && ! -s "$UNSIGNED_VISUAL_QA" ]]; then
    echo "GitHub release notes must not claim Ready to share before visual QA evidence exists." >&2
    exit 1
  fi
  if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null; then
    echo "GitHub release notes must not claim Ready to share while release evidence is inconsistent." >&2
    exit 1
  fi
  require_contains "share readiness gate are passing for this artifact."
else
  require_exact_line "# Hazakura Wallpaper $version Release Candidate"
  require_no_exact_line "# Hazakura Wallpaper $version"
  require_contains "Normal-session DMG, bundle-open, leaks memory, and human visual QA evidence are still required before handing the artifact to users."
  require_contains "Run npm run share:preflight:strict from a normal macOS user session before starting the final unsigned share path."
fi

if [[ -s "$GUARD_TESTS" ]]; then
  require_contains "dist/release-evidence/release-evidence-guard-tests.txt"
fi

if [[ -f "$DMG_PATH" ]]; then
  dmg_sha="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"
  require_contains "Hazakura Wallpaper.dmg"
  require_contains "SHA-256: $dmg_sha"
fi

if rg -n --color never '(/Users/|/private/(tmp|var/folders)/|/var/folders/|keisetsu)' "$NOTES_PATH"; then
  echo "GitHub release notes contain local paths or local username." >&2
  exit 1
fi

echo "GitHub release notes checks passed."
