#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
DMG_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.dmg"
MANIFEST_PATH="$ROOT_DIR/dist/release-evidence/RELEASE_MANIFEST.md"
SHA_PATH="$ROOT_DIR/dist/SHA256SUMS"
RELEASE_EVIDENCE_CHECK="$ROOT_DIR/dist/release-evidence/release-evidence-check.txt"
NOTES_PATH="$ROOT_DIR/dist/release-evidence/GITHUB_RELEASE_DRAFT.md"
DMG_INFO="$ROOT_DIR/dist/release-evidence/dmg-info.txt"
GUARD_TESTS="$ROOT_DIR/dist/release-evidence/release-evidence-guard-tests.txt"
UNSIGNED_BUNDLE_OPEN="$ROOT_DIR/dist/release-evidence/unsigned-bundle-open-verified.txt"
UNSIGNED_VISUAL_QA="$ROOT_DIR/dist/release-evidence/unsigned-visual-qa-accepted.txt"
UNSIGNED_MEMORY="$ROOT_DIR/dist/release-evidence/unsigned-memory-check.txt"

cd "$ROOT_DIR"

for path in "$APP_PATH" "$ZIP_PATH" "$MANIFEST_PATH" "$SHA_PATH" "$RELEASE_EVIDENCE_CHECK"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing release artifact or evidence required for GitHub release notes: $path" >&2
    exit 1
  fi
done

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
manifest_zip_sha="$(awk -F': ' '/^- ZIP SHA-256:/ { print $2; exit }' "$MANIFEST_PATH")"
signature="$(awk -F': ' '/^- Code signature:/ { print $2; exit }' "$MANIFEST_PATH")"
final_notarized="$(awk -F': ' '/^- Final notarized ZIP verified:/ { print $2; exit }' "$MANIFEST_PATH")"
dmg_sha=""
share_status="Release candidate"
share_detail="Normal-session DMG, bundle-open, leaks memory, and human visual QA evidence are still required before handing the artifact to users. Run npm run share:preflight:strict from a normal macOS user session before starting the final unsigned share path."
release_title="Hazakura Wallpaper $version Release Candidate"

if [[ "$zip_sha" != "$manifest_zip_sha" ]]; then
  echo "ZIP SHA mismatch between current ZIP and release manifest." >&2
  exit 1
fi

if [[ -f "$DMG_PATH" ]]; then
  dmg_sha="$(shasum -a 256 "$DMG_PATH" | awk '{ print $1 }')"
fi

if "$ROOT_DIR/scripts/check_share_evidence_ready.sh" >/dev/null 2>&1; then
  share_status="Ready to share"
  share_detail="DMG, LaunchServices bundle-open, leaks memory, human visual QA evidence, and the share readiness gate are passing for this artifact."
  release_title="Hazakura Wallpaper $version"
fi

mkdir -p "$(dirname "$NOTES_PATH")"
TEMP_NOTES="$(mktemp "$ROOT_DIR/dist/release-evidence/GITHUB_RELEASE_DRAFT.XXXXXX")"
trap 'rm -f "$TEMP_NOTES"' EXIT

{
  echo "# $release_title"
  echo
  echo "Build: $build"
  echo "Bundle ID: $bundle_id"
  echo "Status: $share_status"
  echo
  echo "$share_detail"
  echo
  echo "## Assets"
  echo
  echo "- Hazakura Wallpaper.zip"
  echo "  - SHA-256: $zip_sha"
  if [[ -n "$dmg_sha" ]]; then
    echo "- Hazakura Wallpaper.dmg"
    echo "  - SHA-256: $dmg_sha"
  else
    echo "- Hazakura Wallpaper.dmg"
    echo "  - Not included in this candidate yet. Create it in a normal macOS session with:"
    echo "    \`HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh\`"
  fi
  echo
  echo "## Install"
  echo
  echo "See \`docs/INSTALL.md\` for DMG, ZIP, source build, Gatekeeper bypass, and uninstall instructions."
  echo
  echo "This build may be ad-hoc signed. On other Macs, Gatekeeper may require Control-click Open or System Settings > Privacy & Security > Open Anyway."
  echo
  echo "## Verification"
  echo
  echo "- Publish gate: \`./scripts/check_publish_readiness.sh\`"
  echo "- Share preflight: \`npm run share:preflight:strict\`"
  echo "- One-shot share finalizer: \`npm run share:unsigned -- --operator \"Operator Name\" --reviewer \"Reviewer Name\" --accepted --checklist-complete\`"
  echo "- Share readiness gate: \`npm run share:check\`"
  echo "- Release evidence: \`dist/release-evidence/RELEASE_MANIFEST.md\`"
  if [[ -s "$GUARD_TESTS" ]]; then
    echo "- Guard tests: \`dist/release-evidence/release-evidence-guard-tests.txt\`"
  fi
  echo "- Checksums: \`dist/SHA256SUMS\`"
  echo
  echo "Code signature: $signature"
  echo "Final notarized ZIP verified: $final_notarized"
  echo
  echo "## Privacy And Security"
  echo
  echo "See \`PRIVACY.md\` for local data and logging behavior."
  echo "See \`SECURITY.md\` for supported distribution and reporting guidance."
} >"$TEMP_NOTES"

mv "$TEMP_NOTES" "$NOTES_PATH"
trap - EXIT

echo "$NOTES_PATH"
