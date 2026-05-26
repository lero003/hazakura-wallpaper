#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$ROOT_DIR/dist/release-evidence"
EVIDENCE_PATH="$EVIDENCE_DIR/renderer-memory-smoke.txt"

cd "$ROOT_DIR"
mkdir -p "$EVIDENCE_DIR"

validate_positive_integer_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -n "$value" && ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "$name must be a positive integer when set." >&2
    exit 2
  fi
}

validate_positive_integer_env SAKURA_SKY_MEMORY_SMOKE_FRAMES
validate_positive_integer_env SAKURA_SKY_MEMORY_SMOKE_WIDTH
validate_positive_integer_env SAKURA_SKY_MEMORY_SMOKE_HEIGHT
validate_positive_integer_env SAKURA_SKY_MEMORY_SMOKE_MAX_RSS_BYTES
validate_positive_integer_env HAZAKURA_WALLPAPER_MEMORY_SMOKE_FRAMES
validate_positive_integer_env HAZAKURA_WALLPAPER_MEMORY_SMOKE_WIDTH
validate_positive_integer_env HAZAKURA_WALLPAPER_MEMORY_SMOKE_HEIGHT
validate_positive_integer_env HAZAKURA_WALLPAPER_MEMORY_SMOKE_MAX_RSS_BYTES

swift build --disable-sandbox -c release --product SakuraSkyMemorySmoke >/dev/null

TEMP_REPORT="$(mktemp "$EVIDENCE_DIR/renderer-memory-smoke.XXXXXX")"
trap 'rm -f "$TEMP_REPORT"' EXIT

"$ROOT_DIR/.build/release/SakuraSkyMemorySmoke" >"$TEMP_REPORT"

if ! grep -Fq "Renderer memory smoke passed: yes" "$TEMP_REPORT"; then
  echo "Renderer memory smoke did not report success." >&2
  cat "$TEMP_REPORT" >&2
  exit 1
fi

mv "$TEMP_REPORT" "$EVIDENCE_PATH"
trap - EXIT

cat "$EVIDENCE_PATH"
