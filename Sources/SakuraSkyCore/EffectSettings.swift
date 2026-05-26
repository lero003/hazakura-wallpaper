import Foundation

public enum EffectMode: String, CaseIterable, Codable, Sendable {
    case sakura
    case magic
    case spark
    case hazakura
    case breeze
    case firefly

    public var displayName: String {
        switch self {
        case .sakura:
            "SAKURA"
        case .magic:
            "Magic"
        case .spark:
            "Spark"
        case .hazakura:
            "Hazakura"
        case .breeze:
            "Breeze"
        case .firefly:
            "Hotaru"
        }
    }
}

public enum EffectIntensity: String, CaseIterable, Codable, Sendable {
    case quiet
    case normal
    case play

    public var displayName: String {
        switch self {
        case .quiet:
            "控えめ"
        case .normal:
            "標準"
        case .play:
            "遊びすぎ"
        }
    }

    public var particleScale: Double {
        switch self {
        case .quiet:
            0.48
        case .normal:
            1.0
        case .play:
            1.58
        }
    }

    public var alphaScale: Double {
        switch self {
        case .quiet:
            0.58
        case .normal:
            1.0
        case .play:
            1.18
        }
    }

    public var repelScale: Double {
        switch self {
        case .quiet:
            0.56
        case .normal:
            1.0
        case .play:
            1.36
        }
    }

    public var sizeScale: Double {
        switch self {
        case .quiet:
            0.82
        case .normal:
            1.0
        case .play:
            1.12
        }
    }

    public var speedScale: Double {
        switch self {
        case .quiet:
            0.78
        case .normal:
            1.0
        case .play:
            1.18
        }
    }
}

public struct EffectSettings: Codable, Equatable, Sendable {
    public var isPaused: Bool
    public var showsNightBackground: Bool
    public var mode: EffectMode
    public var intensity: EffectIntensity

    public init(
        isPaused: Bool = false,
        showsNightBackground: Bool = false,
        mode: EffectMode = .sakura,
        intensity: EffectIntensity = .normal
    ) {
        self.isPaused = isPaused
        self.showsNightBackground = showsNightBackground
        self.mode = mode
        self.intensity = intensity
    }

    private enum CodingKeys: String, CodingKey {
        case showsNightBackground
        case night
        case mode
        case intensity
        case focus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currentNightBackground = Self.decodeBool(from: container, forKey: .showsNightBackground)
        let legacyNightBackground = Self.decodeBool(from: container, forKey: .night)

        self.isPaused = false
        self.showsNightBackground = currentNightBackground ?? legacyNightBackground ?? false
        self.mode = Self.decodeMode(from: container)
        self.intensity = Self.decodeIntensity(from: container)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showsNightBackground, forKey: .showsNightBackground)
        try container.encode(mode, forKey: .mode)
        try container.encode(intensity, forKey: .intensity)
    }

    private static func decodeBool(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Bool? {
        try? container.decodeIfPresent(Bool.self, forKey: key)
    }

    private static func decodeMode(from container: KeyedDecodingContainer<CodingKeys>) -> EffectMode {
        guard let rawValue = try? container.decodeIfPresent(String.self, forKey: .mode) else {
            return .sakura
        }
        return EffectMode(rawValue: rawValue) ?? .sakura
    }

    private static func decodeIntensity(from container: KeyedDecodingContainer<CodingKeys>) -> EffectIntensity {
        let rawValue = (try? container.decodeIfPresent(String.self, forKey: .intensity))
            ?? (try? container.decodeIfPresent(String.self, forKey: .focus))
        guard let rawValue else {
            return .normal
        }
        return EffectIntensity(rawValue: rawValue) ?? .normal
    }
}

public extension EffectSettings {
    static let `default` = EffectSettings()

    var shouldAnimateOverlay: Bool {
        !isPaused
    }

    func renderingSettings(reducesMotion: Bool) -> EffectSettings {
        guard reducesMotion, intensity != .quiet else {
            return self
        }

        var settings = self
        settings.intensity = .quiet
        return settings
    }
}
