import AppKit
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif
#if canImport(SakuraSkyRenderer)
import SakuraSkyRenderer
#endif

@MainActor
final class SakuraCanvasView: NSView {
    private var settings: EffectSettings
    private var scene = SakuraScene()
    private var displayTimer: Timer?
    private var displayTimerInterval: TimeInterval?
    private var isObservingAccessibilityDisplayOptions = false
    private var reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    private var startTime = CACurrentMediaTime()
    private var pausedAt: TimeInterval = 0
    private let timing = OverlayTimingConfiguration.default

    override var isFlipped: Bool { true }

    init(frame: NSRect, settings: EffectSettings) {
        self.settings = settings
        super.init(frame: frame)
        wantsLayer = true
        layer?.isOpaque = false
        observeAccessibilityDisplayOptions()
        if settings.shouldAnimateOverlay {
            startDisplayTimer()
        }
    }

    required init?(coder: NSCoder) {
        self.settings = .default
        super.init(coder: coder)
        wantsLayer = true
        layer?.isOpaque = false
        observeAccessibilityDisplayOptions()
        startDisplayTimer()
    }

    func apply(settings: EffectSettings) {
        let wasPaused = self.settings.isPaused
        self.settings = settings

        if settings.isPaused, !wasPaused {
            pausedAt = CACurrentMediaTime() - startTime
            stopDisplayTimer()
        } else if !settings.isPaused, wasPaused {
            startTime = CACurrentMediaTime() - pausedAt
            startDisplayTimer()
        }

        needsDisplay = true
    }

    func updatePointer(_ point: CGPoint, isActive: Bool) {
        scene.updatePointer(point, isActive: isActive, bounds: bounds)
    }

    func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
        displayTimerInterval = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.backgroundColor = .clear
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            stopDisplayTimer()
            stopObservingAccessibilityDisplayOptions()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        scene.resize(to: newSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        autoreleasepool {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.clear(bounds)

            guard settings.shouldAnimateOverlay else { return }

            let time = CACurrentMediaTime() - startTime
            let renderingSettings = settings.renderingSettings(reducesMotion: reducesMotion)
            scene.updateAndDraw(in: context, bounds: bounds, time: time, settings: renderingSettings)
        }
    }

    private func startDisplayTimer() {
        let interval = timing.displayFrameInterval(reducesMotion: reducesMotion)
        guard displayTimer == nil || displayTimerInterval != interval else { return }
        stopDisplayTimer()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
        displayTimerInterval = interval
    }

    private func observeAccessibilityDisplayOptions() {
        guard !isObservingAccessibilityDisplayOptions else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityDisplayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        isObservingAccessibilityDisplayOptions = true
    }

    private func stopObservingAccessibilityDisplayOptions() {
        guard isObservingAccessibilityDisplayOptions else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
        isObservingAccessibilityDisplayOptions = false
    }

    @objc private func accessibilityDisplayOptionsChanged() {
        reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if settings.shouldAnimateOverlay {
            startDisplayTimer()
        }
        needsDisplay = true
    }
}
