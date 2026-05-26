import Foundation

public struct SmokeExitConfiguration: Equatable, Sendable {
    public static let environmentKey = "HAZAKURA_WALLPAPER_SMOKE_EXIT_AFTER"
    public static let legacyEnvironmentKey = "SAKURA_SKY_SMOKE_EXIT_AFTER"
    public static let minimumDelay: TimeInterval = 0.1

    public let delay: TimeInterval

    public init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let rawValue = environment[Self.environmentKey] ?? environment[Self.legacyEnvironmentKey],
              let parsedDelay = Double(rawValue)
        else {
            return nil
        }

        self.delay = max(Self.minimumDelay, parsedDelay)
    }
}
