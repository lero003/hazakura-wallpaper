import CoreGraphics
import Foundation
import Testing
@testable import SakuraSkyCore

@Test func defaultSettingsMatchCurrentProductBehavior() {
    let settings = EffectSettings.default

    #expect(settings.isPaused == false)
    #expect(settings.showsNightBackground == false)
    #expect(settings.mode == .sakura)
    #expect(settings.intensity == .normal)
}

@Test func particleBudgetIsClampedToAvailableParticles() {
    #expect(ParticleBudget.visibleCount(total: 100, intensity: .quiet) == 48)
    #expect(ParticleBudget.visibleCount(total: 100, intensity: .normal) == 100)
    #expect(ParticleBudget.visibleCount(total: 100, intensity: .play) == 100)
}

@Test func pauseStateIsNotPersistedAcrossLaunches() throws {
    let encoded = try JSONEncoder().encode(EffectSettings(
        isPaused: true,
        showsNightBackground: true,
        mode: .hazakura,
        intensity: .play
    ))
    let decoded = try JSONDecoder().decode(EffectSettings.self, from: encoded)

    #expect(decoded.isPaused == false)
    #expect(decoded.showsNightBackground == true)
    #expect(decoded.mode == .hazakura)
    #expect(decoded.intensity == .play)
}

@Test func persistedSettingsRoundTripDropsTransientPauseState() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")

    store.save(EffectSettings(
        isPaused: true,
        showsNightBackground: true,
        mode: .magic,
        intensity: .play
    ))

    let loaded = store.load()

    #expect(loaded.isPaused == false)
    #expect(loaded.showsNightBackground == true)
    #expect(loaded.mode == .magic)
    #expect(loaded.intensity == .play)
}

@Test func corruptedPersistedSettingsFallBackToDefaults() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    defaults.defaults.set(Data("not-json".utf8), forKey: "settings")

    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")

    #expect(store.load() == .default)
}

@Test func corruptedPersistedSettingsAreRepairedToDefaults() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    defaults.defaults.set(Data("not-json".utf8), forKey: "settings")

    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")
    let loadResult = store.loadResult(fallbackLegacySettingsURLs: [])

    #expect(loadResult == EffectSettingsLoadResult(settings: .default, source: .defaults))
    #expect(store.load() == .default)
}

@Test func nonDataPersistedSettingsAreRepairedToDefaults() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    defaults.defaults.set("not-data", forKey: "settings")

    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")
    let loadResult = store.loadResult(fallbackLegacySettingsURLs: [])

    #expect(loadResult == EffectSettingsLoadResult(settings: .default, source: .defaults))
    #expect(store.load() == .default)
}

@Test func partiallyInvalidPersistedSettingsKeepValidFields() throws {
    let json = """
    {
      "showsNightBackground": "broken",
      "night": true,
      "mode": "unknown",
      "intensity": "play"
    }
    """
    let decoded = try JSONDecoder().decode(EffectSettings.self, from: Data(json.utf8))

    #expect(decoded.isPaused == false)
    #expect(decoded.showsNightBackground == true)
    #expect(decoded.mode == .sakura)
    #expect(decoded.intensity == .play)
}

@Test func invalidNightBackgroundFallsBackWithoutDroppingOtherSettings() throws {
    let json = """
    {
      "showsNightBackground": "yes",
      "night": "also-broken",
      "mode": "magic",
      "intensity": "quiet"
    }
    """
    let decoded = try JSONDecoder().decode(EffectSettings.self, from: Data(json.utf8))

    #expect(decoded.isPaused == false)
    #expect(decoded.showsNightBackground == false)
    #expect(decoded.mode == .magic)
    #expect(decoded.intensity == .quiet)
}

@Test func legacyTauriSettingKeysAreAccepted() throws {
    let json = """
    {
      "night": true,
      "mode": "hazakura",
      "focus": "quiet"
    }
    """
    let decoded = try JSONDecoder().decode(EffectSettings.self, from: Data(json.utf8))

    #expect(decoded.isPaused == false)
    #expect(decoded.showsNightBackground == true)
    #expect(decoded.mode == .hazakura)
    #expect(decoded.intensity == .quiet)
}

@Test func legacyTauriSettingsFileMigratesWhenUserDefaultsAreEmpty() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    let legacyFile = try temporaryLegacySettingsFile("""
    {
      "night": true,
      "mode": "spark",
      "focus": "play"
    }
    """)
    defer { try? FileManager.default.removeItem(at: legacyFile.deletingLastPathComponent()) }

    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")
    let loadResult = store.loadResult(fallbackLegacySettingsURLs: [legacyFile])

    #expect(loadResult == EffectSettingsLoadResult(settings: EffectSettings(
        showsNightBackground: true,
        mode: .spark,
        intensity: .play
    ), source: .legacy))
    #expect(store.load() == loadResult.settings)
}

@Test func legacyTauriSettingsFileMigratesWhenCurrentSettingsAreUnreadable() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    defaults.defaults.set(Data("not-json".utf8), forKey: "settings")
    let legacyFile = try temporaryLegacySettingsFile("""
    {
      "night": true,
      "mode": "hazakura",
      "focus": "quiet"
    }
    """)
    defer { try? FileManager.default.removeItem(at: legacyFile.deletingLastPathComponent()) }

    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")
    let loadResult = store.loadResult(fallbackLegacySettingsURLs: [legacyFile])

    #expect(loadResult == EffectSettingsLoadResult(settings: EffectSettings(
        showsNightBackground: true,
        mode: .hazakura,
        intensity: .quiet
    ), source: .legacy))
    #expect(store.load() == loadResult.settings)
}

@Test func currentUserDefaultsSettingsWinOverLegacyTauriFile() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    let legacyFile = try temporaryLegacySettingsFile("""
    {
      "night": true,
      "mode": "spark",
      "focus": "play"
    }
    """)
    defer { try? FileManager.default.removeItem(at: legacyFile.deletingLastPathComponent()) }

    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")
    store.save(EffectSettings(
        showsNightBackground: false,
        mode: .magic,
        intensity: .quiet
    ))

    #expect(store.loadResult(fallbackLegacySettingsURLs: [legacyFile]) == EffectSettingsLoadResult(settings: EffectSettings(
        showsNightBackground: false,
        mode: .magic,
        intensity: .quiet
    ), source: .current))
}

@Test func defaultSettingsReportDefaultLoadSourceWhenNoSettingsExist() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }

    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")

    #expect(store.loadResult(fallbackLegacySettingsURLs: []) == EffectSettingsLoadResult(
        settings: .default,
        source: .defaults
    ))
    #expect(defaults.defaults.object(forKey: "settings") == nil)
}

@Test func resetPersistsDefaultSettings() throws {
    let defaults = try temporaryDefaults()
    defer { defaults.defaults.removePersistentDomain(forName: defaults.suiteName) }
    let store = EffectSettingsStore(defaults: defaults.defaults, key: "settings")

    store.save(EffectSettings(
        showsNightBackground: true,
        mode: .spark,
        intensity: .quiet
    ))
    store.reset()

    #expect(store.load() == .default)
}

@Test func settingsCommandsMatchStatusMenuActions() {
    let settings = EffectSettings.default
        .applying(.togglePause)
        .applying(.toggleNightBackground)
        .applying(.selectMode(.spark))
        .applying(.selectIntensity(.play))

    #expect(settings.isPaused == true)
    #expect(settings.showsNightBackground == true)
    #expect(settings.mode == .spark)
    #expect(settings.intensity == .play)
    #expect(settings.applying(.reset) == .default)
}

@Test func pausedSettingsDisableOverlayAnimationWork() {
    #expect(EffectSettings.default.shouldAnimateOverlay)
    #expect(!EffectSettings(isPaused: true).shouldAnimateOverlay)
}

@Test func reduceMotionRenderingKeepsSavedSettingsButClampsIntensity() {
    let savedSettings = EffectSettings(
        isPaused: false,
        showsNightBackground: true,
        mode: .magic,
        intensity: .play
    )
    let renderingSettings = savedSettings.renderingSettings(reducesMotion: true)

    #expect(renderingSettings == EffectSettings(
        showsNightBackground: true,
        mode: .magic,
        intensity: .quiet
    ))
    #expect(savedSettings.intensity == .play)
}

@Test func normalRenderingUsesSavedIntensity() {
    let savedSettings = EffectSettings(mode: .spark, intensity: .play)

    #expect(savedSettings.renderingSettings(reducesMotion: false) == savedSettings)
}

@Test func menuStateReflectsCurrentSettings() {
    let running = EffectSettingsMenuState(settings: .default)

    #expect(running.pauseTitle == "停止")
    #expect(running.nightBackgroundTitle == "夜桜背景を表示")
    #expect(running.isSelected(EffectMode.sakura))
    #expect(running.isSelected(EffectIntensity.normal))

    let pausedNight = EffectSettingsMenuState(settings: EffectSettings(
        isPaused: true,
        showsNightBackground: true,
        mode: .hazakura,
        intensity: .quiet
    ))

    #expect(pausedNight.pauseTitle == "再開")
    #expect(pausedNight.nightBackgroundTitle == "夜桜背景を隠す")
    #expect(pausedNight.isSelected(EffectMode.hazakura))
    #expect(pausedNight.isSelected(EffectIntensity.quiet))
    #expect(!pausedNight.isSelected(EffectMode.sakura))
    #expect(!pausedNight.isSelected(EffectIntensity.play))
}

@Test func aboutInformationUsesBundleMetadata() {
    let information = AppAboutInformation(infoDictionary: [
        "CFBundleDisplayName": "Hazakura Wallpaper",
        "CFBundleShortVersionString": "1.2.3",
        "CFBundleVersion": "45",
        "NSHumanReadableCopyright": "Copyright © 2026 Hazakura Lab."
    ])

    #expect(information.appName == "Hazakura Wallpaper")
    #expect(information.versionLine == "Version 1.2.3 (Build 45)")
    #expect(information.informativeText.contains("葉桜ラボ - とことんAIで遊ぶ研究所"))
    #expect(information.informativeText.contains("Copyright © 2026 Hazakura Lab."))
}

@Test func aboutInformationFallsBackWhenBundleMetadataIsMissing() {
    let information = AppAboutInformation(infoDictionary: [:])

    #expect(information.appName == "Hazakura Wallpaper")
    #expect(information.versionLine == "Version unavailable")
    #expect(information.copyrightLine == "Copyright 2026 Hazakura Lab.")
}

@Test func labSiteLinkUsesPublicHazakuraLabURL() throws {
    let url = try #require(AppExternalLinks.labSiteURL)

    #expect(url.scheme == "https")
    #expect(url.host() == "hazakuralab.pages.dev")
    #expect(url.path() == "")
    #expect(AppExternalLinks.labSiteURLString == url.absoluteString)
}

@Test func smokeExitConfigurationReadsValidDelay() throws {
    let configuration = try #require(SmokeExitConfiguration(environment: [
        SmokeExitConfiguration.environmentKey: "0.25"
    ]))

    #expect(configuration.delay == 0.25)
}

@Test func smokeExitConfigurationReadsLegacyDelayAlias() throws {
    let configuration = try #require(SmokeExitConfiguration(environment: [
        SmokeExitConfiguration.legacyEnvironmentKey: "0.3"
    ]))

    #expect(configuration.delay == 0.3)
}

@Test func smokeExitConfigurationClampsTinyDelay() throws {
    let configuration = try #require(SmokeExitConfiguration(environment: [
        SmokeExitConfiguration.environmentKey: "0"
    ]))

    #expect(configuration.delay == SmokeExitConfiguration.minimumDelay)
}

@Test func smokeExitConfigurationIgnoresMissingOrInvalidDelay() {
    #expect(SmokeExitConfiguration(environment: [:]) == nil)
    #expect(SmokeExitConfiguration(environment: [
        SmokeExitConfiguration.environmentKey: "not-a-number"
    ]) == nil)
}

@Test func overlayTimingConfigurationUsesExpectedRuntimeCadence() {
    let timing = OverlayTimingConfiguration.default

    #expect(timing.displayFrameInterval == 1.0 / 30.0)
    #expect(timing.cursorSampleInterval == 1.0 / 20.0)
    #expect(timing.displayFrameInterval(reducesMotion: true) == 1.0 / 15.0)
    #expect(timing.cursorSampleInterval(reducesMotion: true) == 1.0 / 15.0)
}

@Test func overlayTimingConfigurationClampsInvalidFrequencies() {
    let timing = OverlayTimingConfiguration(
        displayFramesPerSecond: 0,
        cursorSamplesPerSecond: -12,
        reducedMotionDisplayFramesPerSecond: 0,
        reducedMotionCursorSamplesPerSecond: -24
    )

    #expect(timing.displayFrameInterval == 1.0)
    #expect(timing.cursorSampleInterval == 1.0)
    #expect(timing.displayFrameInterval(reducesMotion: true) == 1.0)
    #expect(timing.cursorSampleInterval(reducesMotion: true) == 1.0)
}

@Test func inactivePointerMotionUsesStableDefaultWind() {
    var pointer = PointerMotionState()

    pointer.update(
        point: CGPoint(x: 180, y: 120),
        isActive: true,
        bounds: CGRect(x: 0, y: 0, width: 360, height: 240)
    )
    pointer.update(
        point: CGPoint(x: -2_400, y: 900),
        isActive: false,
        bounds: CGRect(x: 0, y: 0, width: 360, height: 240)
    )

    #expect(pointer.isActive == false)
    #expect(pointer.velocity == .zero)
    #expect(pointer.windX == 0.55)
    #expect(pointer.windY == 0.32)
}

@Test func pointerMotionDoesNotCarryInactiveJumpVelocityIntoNextActiveSample() {
    var pointer = PointerMotionState()
    let bounds = CGRect(x: 0, y: 0, width: 360, height: 240)

    pointer.update(point: CGPoint(x: 100, y: 100), isActive: true, bounds: bounds)
    pointer.update(point: CGPoint(x: -1_000, y: 600), isActive: false, bounds: bounds)
    pointer.update(point: CGPoint(x: 150, y: 140), isActive: true, bounds: bounds)

    #expect(pointer.isActive)
    #expect(pointer.velocity == .zero)
}

@Test func overlayWindowContentFrameUsesLocalCoordinatesForOffsetScreens() {
    let screenFrame = CGRect(x: -1_920, y: 120, width: 1_920, height: 1_080)

    #expect(OverlayWindowGeometry.contentFrame(for: screenFrame) == CGRect(
        x: 0,
        y: 0,
        width: 1_920,
        height: 1_080
    ))
}

@Test func overlayScreenIdentityTrackerResetsBetweenStopAndRestart() {
    var tracker = OverlayScreenIdentityTracker()
    let firstStartNeedsRebuild = tracker.shouldRebuild(for: ["main:0:0:1440:900"])
    let unchangedScreenSetNeedsRebuild = tracker.shouldRebuild(for: ["main:0:0:1440:900"])

    #expect(firstStartNeedsRebuild)
    #expect(!unchangedScreenSetNeedsRebuild)

    tracker.reset()
    #expect(tracker.currentScreenIDs.isEmpty)

    let restartNeedsRebuild = tracker.shouldRebuild(for: ["main:0:0:1440:900"])
    #expect(restartNeedsRebuild)
}

@Test func overlayScreenIdentityTrackerRebuildsWhenScreenSetChanges() {
    var tracker = OverlayScreenIdentityTracker()
    let firstScreenSetNeedsRebuild = tracker.shouldRebuild(for: ["main:0:0:1440:900"])
    let changedScreenSetNeedsRebuild = tracker.shouldRebuild(for: [
        "main:0:0:1440:900",
        "side:-1920:0:1920:1080"
    ])
    let unchangedScreenSetNeedsRebuild = tracker.shouldRebuild(for: [
        "main:0:0:1440:900",
        "side:-1920:0:1920:1080"
    ])

    #expect(firstScreenSetNeedsRebuild)
    #expect(changedScreenSetNeedsRebuild)
    #expect(!unchangedScreenSetNeedsRebuild)
}

@Test func overlayWindowPointerPositionMapsGlobalMouseToLocalContentCoordinates() {
    let screenFrame = CGRect(x: -1_920, y: 120, width: 1_920, height: 1_080)
    let mouseLocation = CGPoint(x: -1_820, y: 1_000)

    #expect(OverlayWindowGeometry.localPointerPosition(
        mouseLocation: mouseLocation,
        screenFrame: screenFrame
    ) == CGPoint(x: 100, y: 200))
}

private func temporaryDefaults(
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "com.hazakuralab.hazakurawallpaper.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName), sourceLocation: sourceLocation)
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
}

private func temporaryLegacySettingsFile(
    _ contents: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("hazakura-wallpaper-legacy-settings-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let url = directory.appendingPathComponent("settings.json")
    try Data(contents.utf8).write(to: url)
    return url
}
