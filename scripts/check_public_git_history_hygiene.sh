#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "Missing git; cannot scan public Git history." >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "Missing rg; cannot scan public Git history." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Public Git history hygiene failed: not inside a Git worktree." >&2
  exit 1
fi

revisions=()
while IFS= read -r revision; do
  revisions+=("$revision")
done < <(git rev-list --all)

if [[ "${#revisions[@]}" -eq 0 ]]; then
  echo "Public Git history hygiene checks passed."
  echo "Scanned commits: 0"
  exit 0
fi

failures=0

report_failure() {
  local title="$1"
  local body="$2"

  failures=$((failures + 1))
  echo "Public Git history hygiene failed: $title" >&2
  echo "$body" >&2
}

excluded_pathspecs=(
  .
  ':(exclude)scripts/check_public_git_history_hygiene.sh'
  ':(exclude)scripts/check_public_source_hygiene.sh'
  ':(exclude)scripts/check_public_artifact_hygiene.sh'
  ':(exclude)scripts/check_github_release_notes.sh'
  ':(exclude)scripts/test_release_evidence_guards.sh'
)

scan_history_blobs() {
  local pattern="$1"

  git grep -I -l -E "$pattern" "${revisions[@]}" -- "${excluded_pathspecs[@]}" 2>/dev/null || true
}

scan_commit_messages() {
  local pattern="$1"
  local matches=()
  local commit

  for commit in "${revisions[@]}"; do
    if git log -1 --format=%B "$commit" | rg -q "$pattern"; then
      matches+=("$commit")
    fi
  done

  if [[ "${#matches[@]}" -gt 0 ]]; then
    printf '%s\n' "${matches[@]}"
  fi
}

history_paths="$(git log --all --name-only --format= | sed '/^$/d' | sort -u)"

credential_path_matches="$(
  printf '%s\n' "$history_paths" |
    rg -n --color never '(^|/)(\.env(\..*)?|\.npmrc|\.netrc|id_rsa|id_dsa|id_ecdsa|id_ed25519)$|(\.pem|\.p12|\.p8|\.pfx|\.key|\.mobileprovision|\.cer|\.cert|\.crt|\.der)$' \
      || true
)"
if [[ -n "$credential_path_matches" ]]; then
  report_failure \
    "Git history contains credential-like file paths." \
    "$credential_path_matches"
fi

local_path_pattern='(/Users/|/private/(tmp|var/folders)/|/var/folders/|keisetsu)'
local_path_blob_matches="$(scan_history_blobs "$local_path_pattern")"
if [[ -n "$local_path_blob_matches" ]]; then
  report_failure \
    "Git history contains local absolute paths or the local username in tracked file content." \
    "$local_path_blob_matches"
fi

local_path_commit_matches="$(scan_commit_messages "$local_path_pattern")"
if [[ -n "$local_path_commit_matches" ]]; then
  report_failure \
    "Git history contains local absolute paths or the local username in commit messages." \
    "$local_path_commit_matches"
fi

secret_marker_pattern='(BEGIN (RSA|DSA|EC|OPENSSH|PRIVATE) KEY|PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}|gh[pousr]_[A-Za-z0-9_]{20,}|-----BEGIN CERTIFICATE-----)'
secret_blob_matches="$(scan_history_blobs "$secret_marker_pattern")"
if [[ -n "$secret_blob_matches" ]]; then
  report_failure \
    "Git history contains private-key, certificate, or token-like markers in tracked file content." \
    "$secret_blob_matches"
fi

secret_commit_matches="$(scan_commit_messages "$secret_marker_pattern")"
if [[ -n "$secret_commit_matches" ]]; then
  report_failure \
    "Git history contains private-key, certificate, or token-like markers in commit messages." \
    "$secret_commit_matches"
fi

notary_value_pattern='(NOTARYTOOL_PASSWORD[[:space:]]*=[[:space:]]*[^[:space:]<]|--apple-id[[:space:]]+[^[:space:]<]|--password[[:space:]]+[^[:space:]<]|--team-id[[:space:]]+[^[:space:]<])'
notary_blob_matches="$(scan_history_blobs "$notary_value_pattern")"
if [[ -n "$notary_blob_matches" ]]; then
  report_failure \
    "Git history appears to contain explicit notarytool credential values or CLI credential arguments." \
    "$notary_blob_matches"
fi

notary_commit_matches="$(scan_commit_messages "$notary_value_pattern")"
if [[ -n "$notary_commit_matches" ]]; then
  report_failure \
    "Git history appears to contain explicit notarytool credential values or CLI credential arguments in commit messages." \
    "$notary_commit_matches"
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

echo "Public Git history hygiene checks passed."
echo "Scanned commits: ${#revisions[@]}"
