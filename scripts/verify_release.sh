#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
PREVIEW_DIR="$ROOT_DIR/dist/previews"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/HazakuraWallpaper"

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/check_workflow_aliases.sh" >/dev/null
"$ROOT_DIR/scripts/check_script_executable_bits.sh" >/dev/null
"$ROOT_DIR/scripts/check_text_normalization.sh" >/dev/null
"$ROOT_DIR/scripts/check_legacy_tauri_boundary.sh" >/dev/null
"$ROOT_DIR/scripts/check_public_git_history_hygiene.sh" >/dev/null
"$ROOT_DIR/scripts/check_swift_safety.sh" >/dev/null
"$ROOT_DIR/scripts/check_privacy_security_boundaries.sh" >/dev/null
"$ROOT_DIR/scripts/check_app_lifecycle_safety.sh" >/dev/null
"$ROOT_DIR/scripts/check_swift_asset_boundaries.sh" >/dev/null
"$ROOT_DIR/scripts/check_release_metadata.sh" >/dev/null
swift test --disable-sandbox
"$ROOT_DIR/scripts/check_renderer_memory_smoke.sh" >/dev/null

"$ROOT_DIR/scripts/build_app.sh" >/dev/null

"$ROOT_DIR/scripts/check_distribution_readiness.sh" "$APP_PATH"

"$ROOT_DIR/script/build_and_run.sh" --verify
"$ROOT_DIR/scripts/render_previews.sh" "$PREVIEW_DIR" >/dev/null
"$ROOT_DIR/scripts/check_preview_artifacts.sh" "$PREVIEW_DIR" >/dev/null
"$ROOT_DIR/scripts/check_preview_determinism.sh" >/dev/null

echo "Release verification passed."
echo "App: $APP_PATH"
echo "Previews: $PREVIEW_DIR"
