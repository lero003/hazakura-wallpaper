#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

CHECK_PATHS=("$@")
if [[ "${#CHECK_PATHS[@]}" -eq 0 ]]; then
  CHECK_PATHS=(Sources Tests)
fi

for path in "${CHECK_PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing Swift safety check path: $path" >&2
    exit 1
  fi
done

if rg -n \
  -e 'fatalError\s*\(' \
  -e 'preconditionFailure\s*\(' \
  -e 'try!' \
  -e 'as!' \
  -e '[[:alnum:]_)\]]!' \
  -e '!\.' \
  -e '!\[' \
  -e '!\(' \
  -e 'nonisolated\s*\(\s*unsafe\s*\)' \
  -e '@unchecked\s+Sendable' \
  "${CHECK_PATHS[@]}"; then
  echo "Swift safety check failed: remove crash-only, force-unwrapped, or unchecked constructs before release." >&2
  exit 1
fi

echo "Swift safety checks passed."
