import Foundation

public enum ParticleBudget {
    public static func storageCount(baseCount: Int) -> Int {
        max(0, scaledCount(baseCount: baseCount, intensity: .play))
    }

    public static func visibleCount(baseCount: Int, availableCount: Int, intensity: EffectIntensity) -> Int {
        max(0, min(availableCount, scaledCount(baseCount: baseCount, intensity: intensity)))
    }

    private static func scaledCount(baseCount: Int, intensity: EffectIntensity) -> Int {
        guard baseCount > 0 else { return 0 }
        return Int((Double(baseCount) * intensity.particleScale).rounded(.up))
    }
}
