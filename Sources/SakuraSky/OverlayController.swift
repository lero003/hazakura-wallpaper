import AppKit
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif

@MainActor
final class OverlayController {
    private var settings: EffectSettings
    private var windows: [SakuraOverlayWindow] = []
    private var cursorTimer: Timer?
    private var cursorTimerInterval: TimeInterval?
    private var screenObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?
    private var isRunning = false
    private var isRebuilding = false
    private var screenIdentityTracker = OverlayScreenIdentityTracker()
    private let timing = OverlayTimingConfiguration.default

    init(settings: EffectSettings) {
        self.settings = settings
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        AppLoggers.overlay.info("Starting overlay controller")
        rebuildWindows()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildWindows()
            }
        }
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateCursorTimer()
            }
        }
        updateCursorTimer()
    }

    func stop() {
        guard isRunning || cursorTimer != nil || screenObserver != nil || accessibilityObserver != nil || !windows.isEmpty else { return }
        AppLoggers.overlay.info("Stopping overlay controller")
        isRunning = false
        screenIdentityTracker.reset()
        cursorTimer?.invalidate()
        cursorTimer = nil
        cursorTimerInterval = nil

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }

        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
            self.accessibilityObserver = nil
        }

        for window in windows {
            window.canvasView.prepareForClose()
            window.close()
        }
        windows.removeAll()
    }

    func apply(settings: EffectSettings) {
        self.settings = settings
        AppLoggers.overlay.info("Applying settings to overlay")
        for window in windows {
            window.canvasView.apply(settings: settings)
        }
        updateCursorTimer()
    }

    private func screenIdentity() -> [String] {
        NSScreen.screens.map { screen in
            let f = screen.frame
            return "\(f.origin.x):\(f.origin.y):\(f.size.width):\(f.size.height)"
        }
    }

    private func rebuildWindows() {
        guard isRunning, !isRebuilding else { return }

        let nextIDs = screenIdentity()
        guard screenIdentityTracker.shouldRebuild(for: nextIDs) else { return }

        isRebuilding = true
        defer { isRebuilding = false }

        let oldWindows = windows
        windows = []

        let newWindows = NSScreen.screens.map { screen in
            SakuraOverlayWindow(screen: screen, settings: settings)
        }

        windows = newWindows

        let hadObserver = screenObserver != nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }

        for window in newWindows {
            window.orderFrontRegardless()
        }

        if hadObserver {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.rebuildWindows()
                }
            }
        }

        for oldWindow in oldWindows {
            oldWindow.canvasView.prepareForClose()
            oldWindow.close()
        }

        AppLoggers.overlay.info("Rebuilt overlay windows: \(self.windows.count, privacy: .public)")
    }

    private func updateCursor() {
        guard isRunning else { return }

        let point = NSEvent.mouseLocation
        for window in windows {
            let frame = window.frame
            let local = OverlayWindowGeometry.localPointerPosition(
                mouseLocation: point,
                screenFrame: frame
            )
            window.canvasView.updatePointer(local, isActive: frame.contains(point))
        }
    }

    private func updateCursorTimer() {
        guard isRunning, settings.shouldAnimateOverlay else {
            cursorTimer?.invalidate()
            cursorTimer = nil
            cursorTimerInterval = nil
            return
        }

        let interval = timing.cursorSampleInterval(
            reducesMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        guard cursorTimer == nil || cursorTimerInterval != interval else { return }
        cursorTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCursor()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorTimer = timer
        cursorTimerInterval = interval
    }
}
