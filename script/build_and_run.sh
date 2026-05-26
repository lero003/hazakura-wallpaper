#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Hazakura Wallpaper"
EXECUTABLE_NAME="HazakuraWallpaper"
VERIFY=false
STREAM_LOGS=false
STREAM_TELEMETRY=false

for arg in "$@"; do
  case "$arg" in
    --verify)
      VERIFY=true
      ;;
    --logs)
      STREAM_LOGS=true
      ;;
    --telemetry)
      STREAM_TELEMETRY=true
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

SMOKE_TIMEOUT_SECONDS="${HAZAKURA_WALLPAPER_EXECUTABLE_SMOKE_TIMEOUT:-${SAKURA_SKY_EXECUTABLE_SMOKE_TIMEOUT:-5}}"
if [[ "$VERIFY" == true ]]; then
  if [[ -z "$SMOKE_TIMEOUT_SECONDS" || "$SMOKE_TIMEOUT_SECONDS" =~ [^0-9] || "$SMOKE_TIMEOUT_SECONDS" -lt 1 ]]; then
    echo "Invalid HAZAKURA_WALLPAPER_EXECUTABLE_SMOKE_TIMEOUT='$SMOKE_TIMEOUT_SECONDS'; expected a positive integer." >&2
    exit 2
  fi
fi

/usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
sleep 0.3

APP_PATH="$("$ROOT_DIR/scripts/build_app.sh")"

stream_logs() {
  local predicate="$1"
  echo "Streaming logs. Press Ctrl-C to stop." >&2
  /usr/bin/log stream --style compact --info --predicate "$predicate"
}

if [[ "$VERIFY" == true ]]; then
  if ! /usr/bin/open -n "$APP_PATH"; then
    if [[ "${HAZAKURA_WALLPAPER_REQUIRE_BUNDLE_OPEN:-${SAKURA_SKY_REQUIRE_BUNDLE_OPEN:-0}}" == "1" ]]; then
      echo "$APP_NAME app bundle launch smoke failed." >&2
      exit 1
    fi
    echo "$APP_NAME app bundle launch smoke could not be confirmed in this shell; continuing with bundle executable smoke." >&2
  else
    sleep 0.5
    /usr/bin/osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    echo "$APP_NAME app bundle launch smoke passed."
  fi

  bundle_executable="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
  if [[ ! -x "$bundle_executable" ]]; then
    echo "$APP_NAME app bundle executable is missing or not executable: $bundle_executable" >&2
    exit 1
  fi

  smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/hazakura-wallpaper-executable-smoke.XXXXXX")"
  cleanup_smoke_dir() {
    rm -rf "$smoke_dir"
  }
  trap cleanup_smoke_dir EXIT
  smoke_executable="$smoke_dir/$EXECUTABLE_NAME"
  cp "$bundle_executable" "$smoke_executable"
  chmod +x "$smoke_executable"

  if ! HAZAKURA_WALLPAPER_SMOKE_EXIT_AFTER=0.2 SAKURA_SKY_SMOKE_EXIT_AFTER=0.2 perl -e 'my $timeout = shift @ARGV; alarm $timeout; exec @ARGV; die "exec failed: $!\n";' "$SMOKE_TIMEOUT_SECONDS" "$smoke_executable"; then
    echo "$APP_NAME bundle executable smoke launch failed or timed out after ${SMOKE_TIMEOUT_SECONDS}s." >&2
    exit 1
  fi
  echo "$APP_NAME bundle executable smoke launch passed."
  exit 0
fi

if [[ "$STREAM_TELEMETRY" == true || "$STREAM_LOGS" == true ]]; then
  if ! /usr/bin/open -n "$APP_PATH"; then
    echo "$APP_NAME app bundle launch failed; cannot stream logs for the running app." >&2
    exit 1
  fi

  if [[ "$STREAM_TELEMETRY" == true ]]; then
    stream_logs 'subsystem == "com.hazakuralab.hazakurawallpaper"'
  else
    stream_logs 'process == "HazakuraWallpaper"'
  fi
  exit 0
fi

if ! /usr/bin/open -n "$APP_PATH"; then
  echo "LaunchServices could not open the app; falling back to direct executable launch." >&2
  swift build --disable-sandbox -c release --product "$EXECUTABLE_NAME" >&2
  "$ROOT_DIR/.build/release/$EXECUTABLE_NAME" &
fi
