import Foundation

public struct AppAboutInformation: Equatable, Sendable {
    public let appName: String
    public let versionLine: String
    public let organizationLine: String
    public let descriptionLine: String
    public let copyrightLine: String

    public init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        let infoDictionary = infoDictionary ?? [:]
        self.appName = Self.firstStringOrFallback(
            in: infoDictionary,
            keys: ["CFBundleDisplayName", "CFBundleName"],
            fallback: "Hazakura Wallpaper"
        )

        let version = Self.firstString(in: infoDictionary, keys: ["CFBundleShortVersionString"])
        let build = Self.firstString(in: infoDictionary, keys: ["CFBundleVersion"])
        if let version, let build {
            self.versionLine = "Version \(version) (Build \(build))"
        } else if let version {
            self.versionLine = "Version \(version)"
        } else {
            self.versionLine = "Version unavailable"
        }

        self.organizationLine = "葉桜ラボ - とことんAIで遊ぶ研究所"
        self.descriptionLine = "AIで遊ぶ、小さなデスクトップ演出アプリです。"
        self.copyrightLine = Self.firstStringOrFallback(
            in: infoDictionary,
            keys: ["NSHumanReadableCopyright"],
            fallback: "Copyright 2026 Hazakura Lab."
        )
    }

    public var informativeText: String {
        [
            versionLine,
            organizationLine,
            descriptionLine,
            copyrightLine
        ].joined(separator: "\n")
    }

    private static func firstStringOrFallback(
        in infoDictionary: [String: Any],
        keys: [String],
        fallback: String
    ) -> String {
        firstString(in: infoDictionary, keys: keys) ?? fallback
    }

    private static func firstString(
        in infoDictionary: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            guard let value = infoDictionary[key] as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}
