#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

require_file() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    echo "Missing required public repository document: $path" >&2
    exit 1
  fi
}

require_contains() {
  local path="$1"
  local text="$2"
  if ! grep -Fq "$text" "$path"; then
    echo "Public repository document '$path' must mention: $text" >&2
    exit 1
  fi
}

require_no_exact_line() {
  local path="$1"
  local text="$2"
  if grep -Fxq "$text" "$path"; then
    echo "Public repository document '$path' must not contain exact line: $text" >&2
    exit 1
  fi
}

require_absent() {
  local path="$1"
  local text="$2"
  if grep -Fq "$text" "$path"; then
    echo "Public repository document '$path' must not mention old public product name: $text" >&2
    exit 1
  fi
}

require_file README.md
require_file CHANGELOG.md
require_file CONTRIBUTING.md
require_file SECURITY.md
require_file PRIVACY.md
require_file .gitattributes
require_file docs/INSTALL.md
require_file docs/RELEASE_QA.md

require_contains README.md "SECURITY.md"
require_contains README.md "PRIVACY.md"
require_contains README.md "docs/INSTALL.md"
require_contains README.md "CHANGELOG.md"
require_contains README.md "CONTRIBUTING.md"
require_contains README.md "hazakura-wallpaper"
require_contains README.md "privacy/security boundaries"
require_contains README.md "script executable bits"
require_contains README.md "text line-ending normalization"
require_contains README.md "legacy Tauri source boundaries"
require_contains README.md "release archives"
require_contains README.md "public artifact hygiene"
require_contains README.md "public Git history hygiene"
require_contains README.md "release-candidate artifact retention limited to 14 days"
require_contains README.md "generated DMG"
require_contains README.md "Local-path-bearing evidence"
require_contains README.md 'shared `Hazakura Wallpaper` scheme'
require_contains README.md "HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh"
require_contains README.md "mounts it read-only"
require_contains README.md "GitHub Release draft"
require_contains README.md "Node/npm is optional"
require_contains README.md "npm run share:preflight"
require_contains README.md "npm run share:preflight:strict"
require_no_exact_line README.md "npm run share:preflight"
require_contains README.md "./scripts/check_share_readiness.sh"
require_contains README.md "does not rebuild the app or ZIP"
require_contains README.md "No open-source license has been selected yet."
require_absent README.md "Sakura Sky"

require_contains CHANGELOG.md "## Unreleased"
require_contains CHANGELOG.md "## 1.0.0 - Pending"
require_contains CHANGELOG.md "Hazakura Wallpaper"
require_contains CHANGELOG.md "normal-session release evidence"
require_contains CHANGELOG.md "Gatekeeper"

require_contains CONTRIBUTING.md "npm run release:candidate"
require_contains CONTRIBUTING.md "Node/npm is optional"
require_contains CONTRIBUTING.md "./scripts/check_script_executable_bits.sh"
require_contains CONTRIBUTING.md "./scripts/check_text_normalization.sh"
require_contains CONTRIBUTING.md "./scripts/check_legacy_tauri_boundary.sh"
require_contains CONTRIBUTING.md "./scripts/check_publish_readiness.sh"
require_contains CONTRIBUTING.md "./scripts/check_privacy_security_boundaries.sh"
require_contains CONTRIBUTING.md "./scripts/check_public_artifact_hygiene.sh"
require_contains CONTRIBUTING.md "./scripts/check_public_git_history_hygiene.sh"
require_contains CONTRIBUTING.md "npm run share:unsigned"
require_contains CONTRIBUTING.md "npm run share:preflight"
require_contains CONTRIBUTING.md "npm run share:preflight:strict"
require_contains CONTRIBUTING.md "does not rebuild the app or ZIP"
require_contains CONTRIBUTING.md "Do not commit signing certificates"
require_contains CONTRIBUTING.md "NOTARYTOOL_PROFILE"

require_contains SECURITY.md "Supported Distribution"
require_contains SECURITY.md "Do not include secrets"
require_contains SECURITY.md "unexpected network clients"
require_contains SECURITY.md "./scripts/check_publish_readiness.sh"
require_contains SECURITY.md "npm run share:unsigned"
require_contains SECURITY.md "check_unsigned_share_prerequisites.sh --strict-normal-session"
require_contains SECURITY.md "does not rebuild the app or ZIP"
require_absent SECURITY.md "Sakura Sky"

require_contains PRIVACY.md "does not collect analytics"
require_contains PRIVACY.md "local settings"
require_contains PRIVACY.md "does not make background network requests"
require_contains PRIVACY.md "unified logs"
require_absent PRIVACY.md "Sakura Sky"

require_contains docs/INSTALL.md "Install From DMG"
require_contains docs/INSTALL.md "Install From ZIP"
require_contains docs/INSTALL.md "Build From Source"
require_contains docs/INSTALL.md "hazakura-wallpaper"
require_contains docs/INSTALL.md "Node/npm is optional"
require_contains docs/INSTALL.md 'shared `Hazakura Wallpaper` scheme'
require_contains docs/INSTALL.md "./scripts/prepare_release_candidate.sh"
require_contains docs/INSTALL.md "Gatekeeper"
require_contains docs/INSTALL.md "defaults delete com.hazakuralab.hazakurawallpaper"
require_absent docs/INSTALL.md "Sakura Sky"

require_contains docs/RELEASE_QA.md "Unsigned GitHub / DMG Distribution"
require_contains docs/RELEASE_QA.md "generated DMG"
require_contains docs/RELEASE_QA.md "HAZAKURA_WALLPAPER_PACKAGE_EXISTING_APP=1 ./scripts/package_dmg.sh"
require_contains docs/RELEASE_QA.md "before running the strict share gate"
require_contains docs/RELEASE_QA.md "mounts it read-only"
require_contains docs/RELEASE_QA.md "npm run share:preflight"
require_contains docs/RELEASE_QA.md "npm run share:preflight:strict"
require_no_exact_line docs/RELEASE_QA.md "npm run share:preflight"
require_contains docs/RELEASE_QA.md "./scripts/check_share_readiness.sh"
require_contains docs/RELEASE_QA.md "does not rebuild the app or ZIP"
require_absent docs/RELEASE_QA.md "Sakura Sky"

echo "Public repository documentation checks passed."
