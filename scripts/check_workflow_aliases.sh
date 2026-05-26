#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_JSON="$ROOT_DIR/package.json"

cd "$ROOT_DIR"

if [[ ! -s "$PACKAGE_JSON" ]]; then
  echo "Missing package.json." >&2
  exit 1
fi

script_value() {
  local script_name="$1"
  plutil -extract "scripts.$script_name" raw "$PACKAGE_JSON" 2>/dev/null || true
}

require_script() {
  local script_name="$1"
  local expected="$2"
  local actual
  actual="$(script_value "$script_name")"
  if [[ "$actual" != "$expected" ]]; then
    echo "package.json script '$script_name' must be '$expected', got '${actual:-<missing>}'." >&2
    exit 1
  fi
}

require_absent_package_key() {
  local key="$1"
  if plutil -extract "$key" raw "$PACKAGE_JSON" >/dev/null 2>&1; then
    echo "package.json must not define '$key'; npm is only a convenience alias layer for checked-in scripts." >&2
    exit 1
  fi
}

require_absent_package_key "dependencies"
require_absent_package_key "devDependencies"
require_absent_package_key "optionalDependencies"

require_script "build" "./scripts/build_app.sh"
require_script "dev" "./script/build_and_run.sh"
require_script "preview" "./scripts/render_previews.sh"
require_script "renderer:tune" "./scripts/check_renderer_tuning_loop.sh"
require_script "verify" "./scripts/verify_release.sh"
require_script "release:candidate" "./scripts/prepare_release_candidate.sh"
require_script "share:preflight" "./scripts/check_unsigned_share_prerequisites.sh"
require_script "share:preflight:strict" "./scripts/check_unsigned_share_prerequisites.sh --strict-normal-session"
require_script "share:check" "./scripts/check_share_readiness.sh"
require_script "share:unsigned" "./scripts/finalize_unsigned_share.sh"

for normal_script in build dev preview "renderer:tune" verify "release:candidate" "share:preflight" "share:preflight:strict" "share:check" "share:unsigned"; do
  value="$(script_value "$normal_script")"
  if [[ "$value" == *tauri* ]]; then
    echo "package.json script '$normal_script' must not call Tauri for the Swift public workflow." >&2
    exit 1
  fi
done

echo "Workflow alias checks passed."
