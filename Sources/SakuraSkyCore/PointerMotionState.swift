import CoreGraphics

public struct PointerMotionState: Equatable {
    public private(set) var point: CGPoint
    public private(set) var previousPoint: CGPoint
    public private(set) var velocity: CGVector
    public private(set) var isActive: Bool
    public private(set) var windX: CGFloat
    public private(set) var windY: CGFloat

    public init(
        point: CGPoint = CGPoint(x: 720, y: 450),
        previousPoint: CGPoint = CGPoint(x: 720, y: 450),
        velocity: CGVector = .zero,
        isActive: Bool = false,
        windX: CGFloat = 0.55,
        windY: CGFloat = 0.32
    ) {
        self.point = point
        self.previousPoint = previousPoint
        self.velocity = velocity
        self.isActive = isActive
        self.windX = windX
        self.windY = windY
    }

    public mutating func update(point: CGPoint, isActive: Bool, bounds: CGRect) {
        let wasActive = self.isActive
        previousPoint = wasActive ? self.point : point
        self.point = point
        self.isActive = isActive

        guard isActive else {
            velocity = .zero
            windX = 0.55
            windY = 0.32
            return
        }

        velocity = wasActive
            ? CGVector(dx: point.x - previousPoint.x, dy: point.y - previousPoint.y)
            : .zero

        let nx = ((point.x - bounds.minX) / max(1, bounds.width) - 0.5) * 2
        let ny = ((point.y - bounds.minY) / max(1, bounds.height) - 0.5) * 2
        windX = 0.55 + nx * 1.7
        windY = 0.32 - ny * 0.95
    }
}
