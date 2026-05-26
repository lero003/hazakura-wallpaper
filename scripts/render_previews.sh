#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/dist/previews}"

cd "$ROOT_DIR"

swift run --disable-sandbox SakuraSkyPreview --output "$OUTPUT_DIR"
