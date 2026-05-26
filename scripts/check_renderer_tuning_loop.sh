#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW_DIR="$ROOT_DIR/dist/previews"
RUN_APP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/check_renderer_tuning_loop.sh [--full] [--preview-dir <path>]

Runs the renderer tuning loop:
  - Swift tests
  - deterministic preview generation
  - preview artifact/content checks
  - preview determinism checks
  - renderer memory smoke
  - git diff whitespace checks

Options:
  --full                Also build dist/Hazakura Wallpaper.app.
  --preview-dir <path>  Write the first preview pass to a custom directory.
  -h, --help            Show this help.

Renderer memory smoke can be tuned with:
  HAZAKURA_WALLPAPER_MEMORY_SMOKE_FRAMES
  HAZAKURA_WALLPAPER_MEMORY_SMOKE_WIDTH
  HAZAKURA_WALLPAPER_MEMORY_SMOKE_HEIGHT
  HAZAKURA_WALLPAPER_MEMORY_SMOKE_MAX_RSS_BYTES
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)
      RUN_APP_BUILD=1
      shift
      ;;
    --preview-dir)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "--preview-dir requires a path." >&2
        exit 2
      fi
      PREVIEW_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT_DIR"

run_step() {
  local label="$1"
  shift
  echo
  echo "==> $label"
  "$@"
}

echo "Renderer tuning loop started."
echo "Preview directory: $PREVIEW_DIR"
if [[ "$RUN_APP_BUILD" == "1" ]]; then
  echo "App build: enabled"
else
  echo "App build: skipped; pass --full before release-style handoff."
fi

run_step "Swift tests" swift test --disable-sandbox
run_step "Render previews" "$ROOT_DIR/scripts/render_previews.sh" "$PREVIEW_DIR"
run_step "Check preview artifacts" "$ROOT_DIR/scripts/check_preview_artifacts.sh" "$PREVIEW_DIR"
run_step "Check preview determinism" "$ROOT_DIR/scripts/check_preview_determinism.sh"
run_step "Renderer memory smoke" "$ROOT_DIR/scripts/check_renderer_memory_smoke.sh"

if [[ "$RUN_APP_BUILD" == "1" ]]; then
  run_step "Build distributable app" "$ROOT_DIR/scripts/build_app.sh"
fi

run_step "Git diff whitespace" git diff --check

echo
echo "Renderer tuning loop passed."
