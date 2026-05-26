import Foundation
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif

@MainActor
final class SettingsStore {
    var settings: EffectSettings {
        didSet {
            persistedStore.save(settings)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        key: String = EffectSettingsStore.defaultKey,
        legacySettingsURLs: [URL] = SettingsStore.defaultLegacySettingsURLs()
    ) {
        self.persistedStore = EffectSettingsStore(defaults: defaults, key: key)
        let loadResult = persistedStore.loadResult(fallbackLegacySettingsURLs: legacySettingsURLs)
        self.settings = loadResult.settings
        AppLoggers.settings.info("Loaded settings source: \(loadResult.source.rawValue, privacy: .public)")
    }

    func reset() {
        settings = .default
        AppLoggers.settings.info("Reset settings to defaults")
    }

    private let persistedStore: EffectSettingsStore

    private static func defaultLegacySettingsURLs(
        fileManager: FileManager = .default
    ) -> [URL] {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return []
        }

        return [
            applicationSupport
                .appendingPathComponent("com.sakurasky", isDirectory: true)
                .appendingPathComponent("settings.json"),
            applicationSupport
                .appendingPathComponent("Hazakura Wallpaper", isDirectory: true)
                .appendingPathComponent("settings.json")
        ]
    }
}
