public enum EffectSettingsCommand: Equatable, Sendable {
    case togglePause
    case toggleNightBackground
    case selectMode(EffectMode)
    case selectIntensity(EffectIntensity)
    case reset
}

public extension EffectSettings {
    func applying(_ command: EffectSettingsCommand) -> EffectSettings {
        var settings = self
        settings.apply(command)
        return settings
    }

    mutating func apply(_ command: EffectSettingsCommand) {
        switch command {
        case .togglePause:
            isPaused.toggle()
        case .toggleNightBackground:
            showsNightBackground.toggle()
        case .selectMode(let mode):
            self.mode = mode
        case .selectIntensity(let intensity):
            self.intensity = intensity
        case .reset:
            self = .default
        }
    }
}
