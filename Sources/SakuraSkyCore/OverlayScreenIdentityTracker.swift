public struct OverlayScreenIdentityTracker: Equatable, Sendable {
    private var currentIDs: [String]

    public init(currentIDs: [String] = []) {
        self.currentIDs = currentIDs
    }

    public var currentScreenIDs: [String] {
        currentIDs
    }

    public mutating func shouldRebuild(for nextIDs: [String]) -> Bool {
        guard nextIDs != currentIDs else { return false }
        currentIDs = nextIDs
        return true
    }

    public mutating func reset() {
        currentIDs = []
    }
}
