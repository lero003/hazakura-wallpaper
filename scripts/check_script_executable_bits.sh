#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

missing=()
while IFS= read -r -d '' path; do
  if [[ ! -x "$path" ]]; then
    missing+=("$path")
  fi
done < <(find scripts script -type f -name '*.sh' -print0 | sort -z)

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "Script executable-bit check failed: shell scripts must be executable for GitHub/source-build workflows." >&2
  printf '%s\n' "${missing[@]}" | sed 's/^/- /' >&2
  exit 1
fi

echo "Script executable-bit checks passed."
