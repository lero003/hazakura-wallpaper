#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/dist/release-evidence"
REPORT_PATH="$REPORT_DIR/preview-determinism.txt"

cd "$ROOT_DIR"

mkdir -p "$REPORT_DIR"
TEMP_REPORT="$(mktemp "$REPORT_DIR/preview-determinism.XXXXXX")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-preview-determinism.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"; rm -rf "$WORK_DIR"' EXIT

FIRST_DIR="$WORK_DIR/first"
SECOND_DIR="$WORK_DIR/second"
mkdir -p "$FIRST_DIR" "$SECOND_DIR"

"$ROOT_DIR/scripts/render_previews.sh" "$FIRST_DIR" >/dev/null
"$ROOT_DIR/scripts/render_previews.sh" "$SECOND_DIR" >/dev/null

expected_previews=(
  "sakura.png"
  "magic.png"
  "spark.png"
  "hazakura.png"
  "breeze.png"
  "firefly.png"
  "night-sakura.png"
  "qa-matrix-day.png"
  "qa-matrix-night.png"
)

{
  echo "Preview determinism checks passed."
  for preview in "${expected_previews[@]}"; do
    first_path="$FIRST_DIR/$preview"
    second_path="$SECOND_DIR/$preview"

    if [[ ! -s "$first_path" || ! -s "$second_path" ]]; then
      echo "Missing preview artifact while checking determinism: $preview" >&2
      exit 1
    fi

    first_sha="$(shasum -a 256 "$first_path" | awk '{ print $1 }')"
    second_sha="$(shasum -a 256 "$second_path" | awk '{ print $1 }')"

    if [[ "$first_sha" != "$second_sha" ]]; then
      echo "Preview $preview is not deterministic between runs." >&2
      echo "first:  $first_sha" >&2
      echo "second: $second_sha" >&2
      exit 1
    fi

    echo "- dist/previews/$preview: $first_sha"
  done
} >"$TEMP_REPORT"

mv "$TEMP_REPORT" "$REPORT_PATH"
cat "$REPORT_PATH"
