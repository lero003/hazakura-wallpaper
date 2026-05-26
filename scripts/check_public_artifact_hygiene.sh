#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_PATH="$ROOT_DIR/.github/workflows/ci.yml"

cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "Missing rg; cannot scan public release artifacts." >&2
  exit 1
fi

required_public_artifacts=(
  "dist/Hazakura Wallpaper.zip"
  "dist/SHA256SUMS"
  "dist/release-evidence/GITHUB_RELEASE_DRAFT.md"
  "dist/release-evidence/RELEASE_MANIFEST.md"
  "dist/release-evidence/entitlements.plist"
  "dist/release-evidence/preview-artifacts.txt"
  "dist/release-evidence/preview-determinism.txt"
  "dist/release-evidence/release-evidence-check.txt"
  "dist/release-evidence/release-evidence-guard-tests.txt"
  "dist/release-evidence/renderer-memory-smoke.txt"
  "dist/release-evidence/zip-contents.txt"
)

text_public_artifacts=(
  "dist/SHA256SUMS"
  "dist/release-evidence/GITHUB_RELEASE_DRAFT.md"
  "dist/release-evidence/RELEASE_MANIFEST.md"
  "dist/release-evidence/entitlements.plist"
  "dist/release-evidence/preview-artifacts.txt"
  "dist/release-evidence/preview-determinism.txt"
  "dist/release-evidence/release-evidence-check.txt"
  "dist/release-evidence/release-evidence-guard-tests.txt"
  "dist/release-evidence/renderer-memory-smoke.txt"
  "dist/release-evidence/zip-contents.txt"
)

optional_public_artifacts=(
  "dist/Hazakura Wallpaper.dmg"
)

optional_text_public_artifacts=(
  "dist/release-evidence/dmg-info.txt"
)

forbidden_ci_artifact_paths=(
  "dist/release-evidence/icon-info.txt"
  "dist/release-evidence/codesign-info.txt"
  "dist/release-evidence/spctl.txt"
  "dist/release-evidence/macho-build.txt"
)

for path in "${required_public_artifacts[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Public artifact hygiene failed: missing public artifact: $path" >&2
    exit 1
  fi
  if [[ "$path" != "dist/release-evidence/entitlements.plist" && ! -s "$path" ]]; then
    echo "Public artifact hygiene failed: empty public artifact: $path" >&2
    exit 1
  fi
done

for path in "${optional_public_artifacts[@]}"; do
  if [[ -e "$path" && ! -s "$path" ]]; then
    echo "Public artifact hygiene failed: empty optional public artifact: $path" >&2
    exit 1
  fi
done

for path in "${optional_text_public_artifacts[@]}"; do
  if [[ -e "$path" ]]; then
    if [[ ! -s "$path" ]]; then
      echo "Public artifact hygiene failed: empty optional public artifact: $path" >&2
      exit 1
    fi
    text_public_artifacts+=("$path")
  fi
done

if [[ ! -s "$WORKFLOW_PATH" ]]; then
  echo "Public artifact hygiene failed: missing CI workflow: .github/workflows/ci.yml" >&2
  exit 1
fi

if grep -Fq "dist/release-evidence/**" "$WORKFLOW_PATH"; then
  echo "Public artifact hygiene failed: CI must not upload raw release evidence wildcard paths." >&2
  exit 1
fi

for path in "${forbidden_ci_artifact_paths[@]}"; do
  if grep -Fq "$path" "$WORKFLOW_PATH"; then
    echo "Public artifact hygiene failed: CI must not upload local-path-bearing release evidence: $path" >&2
    exit 1
  fi
done

if ! grep -Fq "retention-days: 14" "$WORKFLOW_PATH"; then
  echo "Public artifact hygiene failed: CI release-candidate artifacts must use a bounded retention period." >&2
  exit 1
fi

if ! grep -Fq "if-no-files-found: error" "$WORKFLOW_PATH"; then
  echo "Public artifact hygiene failed: CI release-candidate artifacts must fail when expected artifacts are missing." >&2
  exit 1
fi

if ! grep -Fq "npm run share:preflight:strict" "$WORKFLOW_PATH"; then
  echo "Public artifact hygiene failed: CI must run the strict unsigned share preflight before uploading release-candidate artifacts." >&2
  exit 1
fi

if grep -Fxq "        run: npm run share:preflight" "$WORKFLOW_PATH"; then
  echo "Public artifact hygiene failed: CI must not use the non-strict share preflight for release-candidate artifacts." >&2
  exit 1
fi

if grep -Fq "dist/Hazakura Wallpaper.dmg" "$WORKFLOW_PATH" &&
  ! grep -Fq "dist/release-evidence/dmg-info.txt" "$WORKFLOW_PATH"; then
  echo "Public artifact hygiene failed: CI DMG uploads must include matching dmg-info evidence." >&2
  exit 1
fi

local_path_matches="$(
  printf '%s\0' "${text_public_artifacts[@]}" |
    xargs -0 rg -n --color never \
      '(/Users/|/private/(tmp|var/folders)/|/var/folders/|keisetsu)' \
      -- 2>/dev/null || true
)"
if [[ -n "$local_path_matches" ]]; then
  echo "Public artifact hygiene failed: public artifacts contain local absolute paths or the local username." >&2
  echo "$local_path_matches" >&2
  exit 1
fi

secret_marker_matches="$(
  printf '%s\0' "${text_public_artifacts[@]}" |
    xargs -0 rg -l --color never \
      '(BEGIN (RSA|DSA|EC|OPENSSH|PRIVATE) KEY|PRIVATE KEY|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,}|gh[pousr]_[A-Za-z0-9_]{20,}|-----BEGIN CERTIFICATE-----)' \
      -- 2>/dev/null || true
)"
if [[ -n "$secret_marker_matches" ]]; then
  echo "Public artifact hygiene failed: public artifacts contain private-key, certificate, or token-like markers." >&2
  echo "$secret_marker_matches" >&2
  exit 1
fi

notary_value_matches="$(
  printf '%s\0' "${text_public_artifacts[@]}" |
    xargs -0 rg -n --color never \
      '(NOTARYTOOL_PASSWORD[[:space:]]*=[[:space:]]*[^[:space:]<]|--apple-id[[:space:]]+[^[:space:]<]|--password[[:space:]]+[^[:space:]<]|--team-id[[:space:]]+[^[:space:]<])' \
      -- 2>/dev/null || true
)"
if [[ -n "$notary_value_matches" ]]; then
  echo "Public artifact hygiene failed: public artifacts appear to contain explicit notarytool credential values or CLI credential arguments." >&2
  echo "$notary_value_matches" >&2
  exit 1
fi

echo "Public artifact hygiene checks passed."
