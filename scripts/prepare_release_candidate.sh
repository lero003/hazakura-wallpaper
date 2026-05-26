#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
PREVIEW_DIR="$ROOT_DIR/dist/previews"
MANIFEST_PATH="$ROOT_DIR/dist/release-evidence/RELEASE_MANIFEST.md"
SHA_PATH="$ROOT_DIR/dist/SHA256SUMS"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/verify_release.sh"
"$ROOT_DIR/scripts/package_zip.sh" >/dev/null

"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
"$ROOT_DIR/scripts/check_github_release_notes.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_evidence.sh"
"$ROOT_DIR/scripts/test_release_evidence_guards.sh" >/dev/null

VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-release-candidate.XXXXXX")"
ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"

EXTRACTED_APP="$VERIFY_DIR/Hazakura Wallpaper.app"
test -x "$EXTRACTED_APP/Contents/MacOS/HazakuraWallpaper"
plutil -lint "$EXTRACTED_APP/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$EXTRACTED_APP"
HAZAKURA_WALLPAPER_WRITE_DISTRIBUTION_EVIDENCE=0 SAKURA_SKY_WRITE_DISTRIBUTION_EVIDENCE=0 "$ROOT_DIR/scripts/check_distribution_readiness.sh" "$EXTRACTED_APP"
"$ROOT_DIR/scripts/check_preview_artifacts.sh" "$PREVIEW_DIR" >/dev/null
"$ROOT_DIR/scripts/check_distribution_readiness.sh" "$ROOT_DIR/dist/Hazakura Wallpaper.app" >/dev/null
"$ROOT_DIR/scripts/write_release_manifest.sh" >/dev/null
"$ROOT_DIR/scripts/write_github_release_notes.sh" >/dev/null
"$ROOT_DIR/scripts/check_github_release_notes.sh" >/dev/null
"$ROOT_DIR/scripts/check_public_artifact_hygiene.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null

echo "Release candidate prepared."
echo "ZIP: $ZIP_PATH"
echo "SHA256SUMS: $SHA_PATH"
echo "Manifest: $MANIFEST_PATH"
echo "GitHub release draft: $ROOT_DIR/dist/release-evidence/GITHUB_RELEASE_DRAFT.md"
echo "Archive verification directory: $VERIFY_DIR"
