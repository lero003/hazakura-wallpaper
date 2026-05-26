#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.app"
ZIP_PATH="$ROOT_DIR/dist/Hazakura Wallpaper.zip"
STRICT_NORMAL_SESSION=0
PROBE_DIR=""
PROBE_MOUNT_DIR=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/check_unsigned_share_prerequisites.sh
  ./scripts/check_unsigned_share_prerequisites.sh --strict-normal-session

Checks that the current unsigned release candidate exists and that local tools
needed by the normal-session share path are available. With --strict-normal-session,
it also creates, verifies, mounts, and detaches a tiny temporary DMG so hdiutil
problems are reported before the real share flow starts.
USAGE
}

cleanup() {
  if [[ -n "$PROBE_MOUNT_DIR" && -d "$PROBE_MOUNT_DIR" ]]; then
    hdiutil detach "$PROBE_MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  if [[ -n "$PROBE_DIR" && -d "$PROBE_DIR" ]]; then
    rm -rf "$PROBE_DIR"
  fi
}

run_release_evidence_check() {
  if ! "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null 2>&1; then
    echo "Unsigned share prerequisites failed: release evidence did not pass; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_release_evidence.sh" >/dev/null
  fi
}

run_publish_readiness_check() {
  if ! "$ROOT_DIR/scripts/check_publish_readiness.sh" >/dev/null 2>&1; then
    echo "Unsigned share prerequisites failed: publish readiness did not pass; showing diagnostics." >&2
    "$ROOT_DIR/scripts/check_publish_readiness.sh" >/dev/null
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict-normal-session)
      STRICT_NORMAL_SESSION=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

missing_tools=()
for tool in hdiutil leaks open osascript codesign shasum awk; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing_tools+=("$tool")
  fi
done

if [[ "${#missing_tools[@]}" -gt 0 ]]; then
  echo "Unsigned share prerequisites failed: missing required tool(s): ${missing_tools[*]}" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Unsigned share prerequisites failed: missing app bundle: dist/Hazakura Wallpaper.app" >&2
  echo "Run npm run release:candidate before the visual pass." >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "Unsigned share prerequisites failed: missing ZIP archive: dist/Hazakura Wallpaper.zip" >&2
  echo "Run npm run release:candidate before the visual pass." >&2
  exit 1
fi

run_release_evidence_check
run_publish_readiness_check

if [[ "$STRICT_NORMAL_SESSION" == "1" ]]; then
  PROBE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-share-preflight.XXXXXX")"
  PROBE_MOUNT_DIR="$PROBE_DIR/mount"
  probe_source_dir="$PROBE_DIR/source"
  probe_dmg="$PROBE_DIR/preflight.dmg"

  mkdir -p "$PROBE_MOUNT_DIR" "$probe_source_dir"
  printf 'Hazakura Wallpaper unsigned share preflight\n' >"$probe_source_dir/README.txt"

  if ! hdiutil create -quiet -volname "Hazakura Wallpaper Preflight" -srcfolder "$probe_source_dir" -ov -format UDZO "$probe_dmg"; then
    echo "Unsigned share prerequisites failed: hdiutil could not create a temporary DMG in this session." >&2
    echo "Run the share path from a normal macOS user session." >&2
    exit 1
  fi

  if ! hdiutil verify "$probe_dmg" >/dev/null; then
    echo "Unsigned share prerequisites failed: hdiutil could not verify a temporary DMG in this session." >&2
    exit 1
  fi

  if ! hdiutil attach -readonly -nobrowse -mountpoint "$PROBE_MOUNT_DIR" "$probe_dmg" >/dev/null; then
    echo "Unsigned share prerequisites failed: hdiutil could not mount a temporary DMG in this session." >&2
    echo "Run the share path from a normal macOS user session." >&2
    exit 1
  fi

  if [[ ! -f "$PROBE_MOUNT_DIR/README.txt" ]]; then
    echo "Unsigned share prerequisites failed: temporary DMG mounted without expected contents." >&2
    exit 1
  fi

  if ! hdiutil detach "$PROBE_MOUNT_DIR" >/dev/null; then
    echo "Unsigned share prerequisites failed: hdiutil could not detach a temporary DMG cleanly." >&2
    exit 1
  fi
  PROBE_MOUNT_DIR=""
fi

zip_sha="$(shasum -a 256 "$ZIP_PATH" | awk '{ print $1 }')"
echo "Unsigned share prerequisites passed."
echo "App: dist/Hazakura Wallpaper.app"
echo "ZIP SHA-256: $zip_sha"
if [[ "$STRICT_NORMAL_SESSION" == "1" ]]; then
  echo "Temporary DMG create/verify/mount/detach: passed"
else
  echo "Temporary DMG probe: skipped"
fi
