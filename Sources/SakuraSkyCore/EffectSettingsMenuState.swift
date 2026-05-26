public struct EffectSettingsMenuState: Equatable, Sendable {
    public let pauseTitle: String
    public let nightBackgroundTitle: String
    public let selectedMode: EffectMode
    public let selectedIntensity: EffectIntensity

    public init(settings: EffectSettings) {
        self.pauseTitle = settings.isPaused ? "再開" : "停止"
        self.nightBackgroundTitle = settings.showsNightBackground ? "夜桜背景を隠す" : "夜桜背景を表示"
        self.selectedMode = settings.mode
        self.selectedIntensity = settings.intensity
    }

    public func isSelected(_ mode: EffectMode) -> Bool {
        mode == selectedMode
    }

    public func isSelected(_ intensity: EffectIntensity) -> Bool {
        intensity == selectedIntensity
    }
}
