import Foundation

public struct OverlayTimingConfiguration: Equatable, Sendable {
    public static let `default` = OverlayTimingConfiguration(
        displayFramesPerSecond: 30,
        cursorSamplesPerSecond: 20,
        reducedMotionDisplayFramesPerSecond: 15,
        reducedMotionCursorSamplesPerSecond: 15
    )

    public let displayFramesPerSecond: Double
    public let cursorSamplesPerSecond: Double
    public let reducedMotionDisplayFramesPerSecond: Double
    public let reducedMotionCursorSamplesPerSecond: Double

    public init(
        displayFramesPerSecond: Double,
        cursorSamplesPerSecond: Double,
        reducedMotionDisplayFramesPerSecond: Double = 24,
        reducedMotionCursorSamplesPerSecond: Double = 24
    ) {
        self.displayFramesPerSecond = displayFramesPerSecond
        self.cursorSamplesPerSecond = cursorSamplesPerSecond
        self.reducedMotionDisplayFramesPerSecond = reducedMotionDisplayFramesPerSecond
        self.reducedMotionCursorSamplesPerSecond = reducedMotionCursorSamplesPerSecond
    }

    public var displayFrameInterval: TimeInterval {
        displayFrameInterval(reducesMotion: false)
    }

    public var cursorSampleInterval: TimeInterval {
        cursorSampleInterval(reducesMotion: false)
    }

    public func displayFrameInterval(reducesMotion: Bool) -> TimeInterval {
        interval(for: reducesMotion ? reducedMotionDisplayFramesPerSecond : displayFramesPerSecond)
    }

    public func cursorSampleInterval(reducesMotion: Bool) -> TimeInterval {
        interval(for: reducesMotion ? reducedMotionCursorSamplesPerSecond : cursorSamplesPerSecond)
    }

    private func interval(for frequency: Double) -> TimeInterval {
        1.0 / max(1, frequency)
    }
}
