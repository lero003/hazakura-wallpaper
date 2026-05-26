#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANVAS="$ROOT_DIR/Sources/SakuraSky/SakuraCanvasView.swift"
OVERLAY="$ROOT_DIR/Sources/SakuraSky/OverlayController.swift"
WINDOW="$ROOT_DIR/Sources/SakuraSky/SakuraOverlayWindow.swift"
STATUS="$ROOT_DIR/Sources/SakuraSky/StatusBarController.swift"
APP_DELEGATE="$ROOT_DIR/Sources/SakuraSky/AppDelegate.swift"

cd "$ROOT_DIR"

for path in "$CANVAS" "$OVERLAY" "$WINDOW" "$STATUS" "$APP_DELEGATE"; do
  if [[ ! -s "$path" ]]; then
    echo "Missing app lifecycle safety source: $path" >&2
    exit 1
  fi
done

require_contains() {
  local path="$1"
  local text="$2"
  if ! grep -Fq "$text" "$path"; then
    echo "Lifecycle safety check failed: '$path' must contain: $text" >&2
    exit 1
  fi
}

require_absent() {
  local path="$1"
  local pattern="$2"
  local rc=0
  rg -n --color never "$pattern" "$path" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    echo "Lifecycle safety check failed: '$path' contains forbidden pattern: $pattern" >&2
    exit 1
  fi
  if [[ "$rc" -ne 1 ]]; then
    echo "Lifecycle safety check failed while scanning '$path' for forbidden pattern: $pattern" >&2
    exit 1
  fi
}

require_contains "$CANVAS" "Timer(timeInterval: interval, repeats: true) { [weak self] _ in"
require_contains "$CANVAS" "displayTimer?.invalidate()"
require_contains "$CANVAS" "displayTimer = nil"
require_contains "$CANVAS" "func prepareForClose()"
require_contains "$CANVAS" "private func updateDisplayTimer()"
require_contains "$CANVAS" "guard settings.shouldAnimateOverlay else"
require_contains "$CANVAS" "stopObservingAccessibilityDisplayOptions()"
require_contains "$CANVAS" "deinit {"
require_contains "$CANVAS" "MainActor.assumeIsolated"
require_contains "$CANVAS" "prepareForClose()"
require_contains "$CANVAS" "override func viewWillMove(toWindow newWindow: NSWindow?)"
require_contains "$CANVAS" "NotificationCenter.default.removeObserver("

require_contains "$OVERLAY" "Timer(timeInterval: interval, repeats: true) { [weak self] _ in"
require_contains "$OVERLAY" "deinit {"
require_contains "$OVERLAY" "MainActor.assumeIsolated"
require_contains "$OVERLAY" "stop()"
require_contains "$OVERLAY" "cursorTimer?.invalidate()"
require_contains "$OVERLAY" "cursorTimer = nil"
require_contains "$OVERLAY" "NotificationCenter.default.removeObserver(screenObserver)"
require_contains "$OVERLAY" "NotificationCenter.default.removeObserver(accessibilityObserver)"
require_contains "$OVERLAY" ") { [weak self] _ in"
require_contains "$OVERLAY" "window.canvasView.prepareForClose()"
require_contains "$OVERLAY" "oldWindow.canvasView.prepareForClose()"

require_contains "$WINDOW" "canvasView.prepareForClose()"

require_contains "$STATUS" "deinit {"
require_contains "$STATUS" "MainActor.assumeIsolated"
require_contains "$STATUS" "stop()"
require_contains "$STATUS" "guard !isStopped else { return }"
require_contains "$STATUS" "NSStatusBar.system.removeStatusItem(statusItem)"

require_contains "$APP_DELEGATE" "overlayController = nil"
require_contains "$APP_DELEGATE" "statusController = nil"

require_absent "$ROOT_DIR/Sources/SakuraSky" 'Timer[.]scheduledTimer'

echo "App lifecycle safety checks passed."
