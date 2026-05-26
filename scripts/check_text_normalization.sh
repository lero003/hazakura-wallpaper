#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "Missing git; cannot determine publishable text files." >&2
  exit 1
fi

failures=0

report_failure() {
  local message="$1"
  failures=$((failures + 1))
  echo "Text normalization check failed: $message" >&2
}

text_files=()
while IFS= read -r -d '' path; do
  if [[ ! -e "$path" && ! -L "$path" ]]; then
    continue
  fi

  case "$path" in
    *.icns|*.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.dmg|*.app/*|*.dSYM/*)
      continue
      ;;
  esac

  if [[ -f "$path" ]]; then
    text_files+=("$path")
  fi
done < <(git ls-files -z --cached --others --exclude-standard)

if [[ "${#text_files[@]}" -eq 0 ]]; then
  report_failure "no publishable text files were found."
fi

cr_matches="$(
  printf '%s\0' "${text_files[@]}" |
    xargs -0 grep -Il $'\r' -- 2>/dev/null || true
)"
if [[ -n "$cr_matches" ]]; then
  report_failure "publishable text files contain CR or CRLF line endings."
  printf '%s\n' "$cr_matches" | sed 's/^/- /' >&2
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Text normalization checks passed."
echo "Scanned publishable text files: ${#text_files[@]}"
