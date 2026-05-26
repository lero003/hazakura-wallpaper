import Foundation

public enum ParticleBudget {
    public static func visibleCount(total: Int, intensity: EffectIntensity) -> Int {
        max(0, min(total, Int((Double(total) * intensity.particleScale).rounded(.up))))
    }
}
