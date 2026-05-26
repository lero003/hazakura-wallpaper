import Foundation

public enum EffectSettingsLoadSource: String, Sendable {
    case current
    case legacy
    case defaults
}

public struct EffectSettingsLoadResult: Equatable, Sendable {
    public let settings: EffectSettings
    public let source: EffectSettingsLoadSource

    public init(settings: EffectSettings, source: EffectSettingsLoadSource) {
        self.settings = settings
        self.source = source
    }
}

public struct EffectSettingsStore {
    public static let defaultKey = "settings"

    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = EffectSettingsStore.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> EffectSettings {
        loadResult(fallbackLegacySettingsURLs: []).settings
    }

    public func load(fallbackLegacySettingsURLs urls: [URL]) -> EffectSettings {
        loadResult(fallbackLegacySettingsURLs: urls).settings
    }

    public func loadResult(fallbackLegacySettingsURLs urls: [URL]) -> EffectSettingsLoadResult {
        let hasPersistedValue = defaults.object(forKey: key) != nil

        if let data = defaults.data(forKey: key),
           let settings = try? JSONDecoder().decode(EffectSettings.self, from: data) {
            return EffectSettingsLoadResult(settings: settings, source: .current)
        }

        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let settings = try? JSONDecoder().decode(EffectSettings.self, from: data)
            else {
                continue
            }

            save(settings)
            return EffectSettingsLoadResult(settings: settings, source: .legacy)
        }

        let settings = EffectSettings.default
        if hasPersistedValue {
            save(settings)
        }
        return EffectSettingsLoadResult(settings: settings, source: .defaults)
    }

    public func save(_ settings: EffectSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    public func reset() {
        save(.default)
    }
}
