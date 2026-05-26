import AppKit
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif

@MainActor
final class SakuraOverlayWindow: NSWindow {
    let canvasView: SakuraCanvasView

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        canvasView = SakuraCanvasView(frame: .zero, settings: .default)
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
    }

    init(screen: NSScreen, settings: EffectSettings) {
        let frame = OverlayWindowGeometry.contentFrame(for: screen.frame)
        canvasView = SakuraCanvasView(frame: frame, settings: settings)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = false
        level = .screenSaver
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]

        canvasView.autoresizingMask = [.width, .height]
        contentView = canvasView
        setFrame(screen.frame, display: true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func close() {
        canvasView.prepareForClose()
        super.close()
    }
}
