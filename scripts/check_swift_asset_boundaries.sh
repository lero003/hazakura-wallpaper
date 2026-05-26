#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

for asset in Resources/icon.icns Resources/icon.png; do
  if [[ ! -s "$asset" ]]; then
    echo "Missing Swift-owned public app asset: $asset" >&2
    exit 1
  fi
done

checked_paths=(
  Package.swift
  Sources
  SakuraSky.xcodeproj
  scripts/build_app.sh
)

if rg -n 'src-tauri/icons' "${checked_paths[@]}"; then
  echo "Swift public build paths must not fall back to legacy Tauri icon assets." >&2
  exit 1
fi

if rg -n 'docs/legacy-tauri/src-tauri' "${checked_paths[@]}"; then
  echo "Swift public build paths must not reference archived legacy Tauri assets." >&2
  exit 1
fi

echo "Swift asset boundary checks passed."
