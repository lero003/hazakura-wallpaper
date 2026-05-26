#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "Missing rg; cannot scan publishable source files." >&2
  exit 1
fi

publish_files=()
scan_scope_label="publishable files"
if [[ "$#" -gt 0 ]]; then
  scan_scope_label="explicit files"
  for path in "$@"; do
    if [[ ! -e "$path" && ! -L "$path" ]]; then
      echo "Public source hygiene failed: explicit check path is missing: $path" >&2
      exit 1
    fi
    publish_files+=("$path")
  done
else
  if ! command -v git >/dev/null 2>&1; then
    echo "Missing git; cannot determine publishable source files." >&2
    exit 1
  fi

  while IFS= read -r -d '' path; do
    if [[ ! -e "$path" && ! -L "$path" ]]; then
      continue
    fi
    publish_files+=("$path")
  done < <(git ls-files -z --cached --others --exclude-standard)
fi

if [[ "${#publish_files[@]}" -eq 0 ]]; then
  echo "Public source hygiene failed: no publishable source files were found." >&2
  exit 1
fi

content_scan_files=()
for path in "${publish_files[@]}"; do
  case "$path" in
    scripts/check_public_source_hygiene.sh)
      ;;
    scripts/check_public_git_history_hygiene.sh)
      ;;
    scripts/check_github_release_notes.sh)
      ;;
    scripts/check_public_artifact_hygiene.sh)
      ;;
    *)
      content_scan_files+=("$path")
      ;;
  esac
done

failures=0

report_failure() {
  local title="$1"
  local body="$2"

  failures=$((failures + 1))
  echo "Public source hygiene failed: $title" >&2
  echo "$body" >&2
}

suspect_paths=()
for path in "${publish_files[@]}"; do
  case "$path" in
    .codex/*|dist/*|node_modules/*|.build/*|.swiftpm/*|.xcode-derived/*|DerivedData/*|*/DerivedData/*|xcuserdata/*|*/xcuserdata/*|*.xcuserdatad|*.xcuserdatad/*|*.xcresult/*|*.xcarchive|*.xcarchive/*|*.app|*.app/*|*.dSYM|*.dSYM/*)
      suspect_paths+=("$path")
      ;;
    .DS_Store|*/.DS_Store|*.bak|*.dmg|*.zip|*.pkg|*.tar|*.tar.gz|*.tgz|*.env|*.env.*|*.pem|*.p12|*.pfx|*.key|*.mobileprovision|*.cer|*.cert|*.crt|*.der|*.xcuserstate|*.xccheckout|*.xcscmblueprint|*.moved-aside|.npmrc|.netrc|id_rsa|id_dsa|id_ecdsa|id_ed25519|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519)
      suspect_paths+=("$path")
      ;;
  esac
done

if [[ "${#suspect_paths[@]}" -gt 0 ]]; then
  report_failure \
    "publishable source includes local, generated, backup, or credential-like paths." \
    "$(printf '%s\n' "${suspect_paths[@]}" | sed 's/^/- /')"
fi

local_path_matches=""
if [[ "${#content_scan_files[@]}" -gt 0 ]]; then
  local_path_matches="$(
    printf '%s\0' "${content_scan_files[@]}" |
      xargs -0 rg -n --color never \
        '(/Users/|/private/(tmp|var/folders)/|/var/folders/|keisetsu)' \
        -- 2>/dev/null || true
  )"
fi
if [[ -n "$local_path_matches" ]]; then
  report_failure \
    "publishable source contains local absolute paths or the local username." \
    "$local_path_matches"
fi

secret_marker_matches=""
if [[ "${#content_scan_files[@]}" -gt 0 ]]; then
  secret_marker_matches="$(
    printf '%s\0' "${content_scan_files[@]}" |
      xargs -0 rg -l --color never \
        '(BEGIN (RSA|DSA|EC|OPENSSH|PRIVATE) KEY|PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}|gh[pousr]_[A-Za-z0-9_]{20,}|-----BEGIN CERTIFICATE-----)' \
        -- 2>/dev/null || true
  )"
fi
if [[ -n "$secret_marker_matches" ]]; then
  report_failure \
    "publishable source contains private-key, certificate, or token-like markers." \
    "$secret_marker_matches"
fi

notary_value_matches=""
if [[ "${#content_scan_files[@]}" -gt 0 ]]; then
  notary_value_matches="$(
    printf '%s\0' "${content_scan_files[@]}" |
      xargs -0 rg -n --color never \
        '(NOTARYTOOL_PASSWORD[[:space:]]*=[[:space:]]*[^[:space:]<]|--apple-id[[:space:]]+[^[:space:]<]|--password[[:space:]]+[^[:space:]<]|--team-id[[:space:]]+[^[:space:]<])' \
        -- 2>/dev/null || true
  )"
fi
if [[ -n "$notary_value_matches" ]]; then
  report_failure \
    "publishable source appears to contain explicit notarytool credential values or CLI credential arguments." \
    "$notary_value_matches"
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Public source hygiene checks passed."
echo "Scanned $scan_scope_label: ${#publish_files[@]}"
