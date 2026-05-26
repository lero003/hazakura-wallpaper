#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "Missing git; cannot inspect public legacy Tauri boundaries." >&2
  exit 1
fi

publish_files=()
while IFS= read -r -d '' path; do
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    continue
  fi
  publish_files+=("$path")
done < <(git ls-files -z --cached --others --exclude-standard)

unexpected=()
for path in "${publish_files[@]}"; do
  case "$path" in
    docs/legacy-tauri/*)
      ;;
    src/*|src-tauri/*|*/tauri.conf.json|*/Cargo.toml|*/Cargo.lock)
      unexpected+=("$path")
      ;;
  esac
done

if [[ "${#unexpected[@]}" -gt 0 ]]; then
  echo "Legacy Tauri boundary check failed: legacy Tauri sources must stay only under docs/legacy-tauri/." >&2
  printf '%s\n' "${unexpected[@]}" | sed 's/^/- /' >&2
  exit 1
fi

if [[ ! -d docs/legacy-tauri ]]; then
  echo "Legacy Tauri boundary check failed: missing docs/legacy-tauri migration reference." >&2
  exit 1
fi

echo "Legacy Tauri boundary checks passed."
