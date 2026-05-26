#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW_DIR="${1:-$ROOT_DIR/dist/previews}"
REPORT_DIR="$ROOT_DIR/dist/release-evidence"
REPORT_PATH="$REPORT_DIR/preview-artifacts.txt"

mkdir -p "$REPORT_DIR"
TEMP_REPORT="$(mktemp "$REPORT_DIR/preview-artifacts.XXXXXX")"
TEMP_BITMAP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-preview-content.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"; rm -rf "$TEMP_BITMAP_DIR"' EXIT

if ! command -v sips >/dev/null 2>&1; then
  echo "Missing sips; cannot verify preview dimensions." >&2
  exit 1
fi

check_preview() {
  local name="$1"
  local expected_width="$2"
  local expected_height="$3"
  local minimum_visible_pixels="$4"
  local minimum_color_channels="$5"
  local path="$PREVIEW_DIR/$name"

  if [[ ! -s "$path" ]]; then
    echo "Missing preview artifact: $path" >&2
    exit 1
  fi

  if ! file "$path" | grep -q "PNG image data"; then
    echo "Preview is not a PNG: $path" >&2
    exit 1
  fi

  local width
  local height
  width="$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ { print $2; exit }')"
  height="$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ { print $2; exit }')"

  if [[ "$width" != "$expected_width" || "$height" != "$expected_height" ]]; then
    echo "Preview $name has ${width}x${height}; expected ${expected_width}x${expected_height}." >&2
    exit 1
  fi

  local bitmap_path="$TEMP_BITMAP_DIR/$name.bmp"
  sips -s format bmp "$path" --out "$bitmap_path" >/dev/null

  local content_counts
  local visible_pixels
  local color_channels
  content_counts="$(od -An -tu1 -v -j 138 "$bitmap_path" | awk '
    {
      for (i = 1; i <= NF; i += 1) {
        channel = byte_count % 4
        if (channel == 3 && $i > 0) {
          visible_pixels += 1
        } else if (channel < 3 && $i > 0) {
          color_channels += 1
        }
        byte_count += 1
      }
    }
    END {
      print visible_pixels + 0, color_channels + 0
    }
  ')"
  visible_pixels="${content_counts%% *}"
  color_channels="${content_counts##* }"

  if (( visible_pixels < minimum_visible_pixels || color_channels < minimum_color_channels )); then
    echo "Preview $name has too little visible content: ${visible_pixels} visible alpha pixels and ${color_channels} nonzero color channels." >&2
    echo "Expected at least ${minimum_visible_pixels} visible alpha pixels and ${minimum_color_channels} nonzero color channels." >&2
    exit 1
  fi

  echo "- dist/previews/$name: ${width}x${height}; visible alpha pixels: $visible_pixels; nonzero color channels: $color_channels"
}

check_preview_diversity() {
  local sha_list="$TEMP_BITMAP_DIR/preview-shas.txt"
  local duplicate_sha
  local name
  local sha

  : >"$sha_list"

  for name in "$@"; do
    sha="$(shasum -a 256 "$PREVIEW_DIR/$name" | awk '{ print $1 }')"
    echo "$sha dist/previews/$name" >>"$sha_list"
  done

  duplicate_sha="$(awk '
    {
      count[$1] += 1
    }
    END {
      for (sha in count) {
        if (count[sha] > 1) {
          print sha
          exit
        }
      }
    }
  ' "$sha_list")"

  if [[ -n "$duplicate_sha" ]]; then
    echo "Preview visual diversity failed: more than one generated preview has SHA-256 $duplicate_sha." >&2
    awk -v duplicate_sha="$duplicate_sha" '$1 == duplicate_sha { print "- " $2 }' "$sha_list" >&2
    exit 1
  fi

  echo "Preview visual diversity checks passed."
  while read -r sha path; do
    echo "- $path: $sha"
  done <"$sha_list"
}

{
  echo "Preview artifact checks passed."
  check_preview "sakura.png" 960 540 5000 10000
  check_preview "magic.png" 960 540 5000 10000
  check_preview "spark.png" 960 540 5000 10000
  check_preview "hazakura.png" 960 540 5000 10000
  check_preview "breeze.png" 960 540 5000 10000
  check_preview "firefly.png" 960 540 5000 10000
  check_preview "night-sakura.png" 960 540 100000 100000
  check_preview "qa-matrix-day.png" 1440 1824 100000 100000
  check_preview "qa-matrix-night.png" 1440 1824 100000 100000
  check_preview_diversity \
    "sakura.png" \
    "magic.png" \
    "spark.png" \
    "hazakura.png" \
    "breeze.png" \
    "firefly.png" \
    "night-sakura.png" \
    "qa-matrix-day.png" \
    "qa-matrix-night.png"
} >"$TEMP_REPORT"

mv "$TEMP_REPORT" "$REPORT_PATH"
cat "$REPORT_PATH"
