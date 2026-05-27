import AppKit
import QuartzCore
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
    private let glowLayerCompositor = GlowLayerCompositor()

    override var isFlipped: Bool { true }

    init(frame: NSRect, settings: EffectSettings) {
        self.settings = settings
        super.init(frame: frame)
        setupGlowLayerCompositor()
        observeAccessibilityDisplayOptions()
        updateDisplayTimer()
    }

    required init?(coder: NSCoder) {
        self.settings = .default
        super.init(coder: coder)
        setupGlowLayerCompositor()
        observeAccessibilityDisplayOptions()
        updateDisplayTimer()
    }

    deinit {
        MainActor.assumeIsolated {
            prepareForClose()
        }
    }

    func apply(settings: EffectSettings) {
        let wasPaused = self.settings.isPaused
        self.settings = settings

        if settings.isPaused, !wasPaused {
            pausedAt = CACurrentMediaTime() - startTime
            stopDisplayTimer()
        } else if !settings.isPaused, wasPaused {
            startTime = CACurrentMediaTime() - pausedAt
        }

        updateDisplayTimer()
        glowLayerCompositor.hide()
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

    func prepareForClose() {
        stopDisplayTimer()
        stopObservingAccessibilityDisplayOptions()
        glowLayerCompositor.removeFromSuperlayer()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.backgroundColor = .clear
        setupGlowLayerCompositor()
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
        glowLayerCompositor.resize(to: bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        autoreleasepool {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            context.clear(bounds)

            guard settings.shouldAnimateOverlay else {
                glowLayerCompositor.hide()
                return
            }

            let time = CACurrentMediaTime() - startTime
            let renderingSettings = settings.renderingSettings(reducesMotion: reducesMotion)
            if let sprites = scene.updateAndDrawLayerBacked(
                in: context,
                bounds: bounds,
                time: time,
                settings: renderingSettings
            ) {
                glowLayerCompositor.apply(
                    sprites: sprites,
                    in: bounds,
                    contentsScale: window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
                )
            } else {
                glowLayerCompositor.hide()
                scene.updateAndDraw(in: context, bounds: bounds, time: time, settings: renderingSettings)
            }
        }
    }

    private func setupGlowLayerCompositor() {
        wantsLayer = true
        guard let layer else { return }
        layer.masksToBounds = false
        glowLayerCompositor.attach(to: layer, bounds: bounds)
    }

    private func startDisplayTimer() {
        let interval = timing.displayFrameInterval(reducesMotion: reducesMotion)
        guard displayTimer == nil || displayTimerInterval != interval else { return }
        stopDisplayTimer()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.needsDisplay = true
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
        displayTimerInterval = interval
    }

    private func updateDisplayTimer() {
        guard settings.shouldAnimateOverlay else {
            stopDisplayTimer()
            return
        }

        startDisplayTimer()
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
        updateDisplayTimer()
        needsDisplay = true
    }
}

private final class GlowLayerCompositor {
    private let containerLayer = CALayer()
    private var spriteLayers: [CALayer] = []
    private weak var hostLayer: CALayer?

    init() {
        containerLayer.masksToBounds = false
        containerLayer.isGeometryFlipped = true
        containerLayer.isHidden = true
    }

    func attach(to layer: CALayer, bounds: CGRect) {
        guard containerLayer.superlayer !== layer else {
            resize(to: bounds)
            return
        }

        containerLayer.removeFromSuperlayer()
        layer.addSublayer(containerLayer)
        hostLayer = layer
        resize(to: bounds)
    }

    func resize(to bounds: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        containerLayer.frame = bounds
        CATransaction.commit()
    }

    func apply(sprites: [SakuraGlowLayerSprite], in bounds: CGRect, contentsScale: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        containerLayer.frame = bounds
        containerLayer.isHidden = sprites.isEmpty

        while spriteLayers.count < sprites.count {
            let layer = makeSpriteLayer()
            spriteLayers.append(layer)
            containerLayer.addSublayer(layer)
        }

        for index in sprites.indices {
            let sprite = sprites[index]
            let layer = spriteLayers[index]
            layer.isHidden = false
            layer.frame = sprite.frame
            layer.opacity = Float(sprite.opacity)
            layer.contentsScale = contentsScale
            layer.contents = sprite.image
        }

        if sprites.count < spriteLayers.count {
            for index in sprites.count..<spriteLayers.count {
                spriteLayers[index].isHidden = true
            }
        }

        CATransaction.commit()
    }

    func hide() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        containerLayer.isHidden = true
        CATransaction.commit()
    }

    func removeFromSuperlayer() {
        containerLayer.removeFromSuperlayer()
        hostLayer = nil
    }

    private func makeSpriteLayer() -> CALayer {
        let layer = CALayer()
        layer.masksToBounds = false
        layer.contentsGravity = .resize
        layer.minificationFilter = .linear
        layer.magnificationFilter = .linear
        layer.compositingFilter = "plusLighterBlendMode"
        return layer
    }
}
