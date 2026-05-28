import CoreGraphics
import Foundation
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif

@MainActor private let maximumSparkRayPathCacheEntries = 512
@MainActor private var sparkRayPathCache: [SparkRayPathCacheKey: CGPath] = [:]
@MainActor private var sparkRayPathCacheOrder: [SparkRayPathCacheKey] = []

@MainActor func resetSparkRayPathCacheForTesting() {
    sparkRayPathCache.removeAll(keepingCapacity: true)
    sparkRayPathCacheOrder.removeAll(keepingCapacity: true)
}

@MainActor func sparkRayPathCacheEntryCountForTesting() -> Int {
    sparkRayPathCache.count
}

@MainActor
public final class SakuraScene {
    private var boundsSize: CGSize = .zero
    private var resetGeneration = 0
    private var pointer = PointerMotionState()
    private var sakuraParticles: [DriftParticle] = []
    private var hazakuraParticles: [DriftParticle] = []
    private var breezeParticles: [DriftParticle] = []
    private var magicLights: [MagicLight] = []
    private var fireflies: [Firefly] = []
    private var sparkLines: [SparkLine] = []
    private var sparkles: [Sparkle] = []
    private var trees: [SakuraTree] = []

    private enum BaseParticleCount {
        static let sakura = 122
        static let hazakura = 124
        static let breeze = 136
        static let magic = 180
        static let firefly = 118
        static let spark = 108
    }

    public init() {
        reset(size: CGSize(width: 1440, height: 900))
    }

    public static func withDeterministicRandomSeed<T>(_ seed: UInt64, _ body: () throws -> T) rethrows -> T {
        try Random.withSeed(seed, body)
    }

    public func resize(to size: CGSize) {
        guard Self.isRenderableSize(size) else { return }
        guard size != boundsSize else { return }
        reset(size: size)
    }

    public func updatePointer(_ point: CGPoint, isActive: Bool, bounds: CGRect) {
        guard Self.isRenderableSize(bounds.size) else { return }
        pointer.update(point: point, isActive: isActive, bounds: bounds)
    }

    public func updateAndDraw(in context: CGContext, bounds: CGRect, time: TimeInterval, settings: EffectSettings) {
        guard Self.isRenderableSize(bounds.size) else { return }

        if bounds.size != boundsSize {
            resize(to: bounds.size)
        }

        drawBackdrop(in: context, bounds: bounds, time: time, settings: settings)

        switch settings.mode {
        case .sakura:
            drawParticles(
                &sakuraParticles,
                baseCount: BaseParticleCount.sakura,
                in: context,
                bounds: bounds,
                time: time,
                settings: settings
            )
        case .hazakura:
            drawParticles(
                &hazakuraParticles,
                baseCount: BaseParticleCount.hazakura,
                in: context,
                bounds: bounds,
                time: time,
                settings: settings
            )
        case .breeze:
            drawParticles(
                &breezeParticles,
                baseCount: BaseParticleCount.breeze,
                in: context,
                bounds: bounds,
                time: time,
                settings: settings
            )
        case .magic:
            drawMagic(in: context, bounds: bounds, time: time, settings: settings)
        case .firefly:
            drawFireflies(in: context, bounds: bounds, time: time, settings: settings)
        case .spark:
            drawSparks(in: context, bounds: bounds, time: time, settings: settings)
        }
    }

    public func updateAndDrawLayerBacked(
        in context: CGContext,
        bounds: CGRect,
        time: TimeInterval,
        settings: EffectSettings
    ) -> [SakuraGlowLayerSprite]? {
        guard Self.isRenderableSize(bounds.size) else { return nil }
        guard settings.mode == .magic || settings.mode == .firefly else { return nil }

        if bounds.size != boundsSize {
            resize(to: bounds.size)
        }

        drawBackdrop(in: context, bounds: bounds, time: time, settings: settings)

        switch settings.mode {
        case .magic:
            return updateMagicLayerSprites(bounds: bounds, time: time, settings: settings)
        case .firefly:
            return updateFireflyLayerSprites(bounds: bounds, time: time, settings: settings)
        case .sakura, .hazakura, .breeze, .spark:
            return nil
        }
    }

    var diagnostics: SakuraSceneDiagnostics {
        SakuraSceneDiagnostics(
            boundsSize: boundsSize,
            resetGeneration: resetGeneration,
            sakuraParticleCount: sakuraParticles.count,
            hazakuraParticleCount: hazakuraParticles.count,
            breezeParticleCount: breezeParticles.count,
            magicLightCount: magicLights.count,
            fireflyCount: fireflies.count,
            sparkLineCount: sparkLines.count,
            sparkleCount: sparkles.count,
            treeCount: trees.count
        )
    }

    private static func isRenderableSize(_ size: CGSize) -> Bool {
        size.width.isFinite &&
            size.height.isFinite &&
            size.width > 0 &&
            size.height > 0
    }

    private func reset(size: CGSize) {
        resetGeneration += 1
        boundsSize = size
        let bounds = CGRect(origin: .zero, size: size)
        let sakuraCount = ParticleBudget.storageCount(baseCount: BaseParticleCount.sakura)
        let hazakuraCount = ParticleBudget.storageCount(baseCount: BaseParticleCount.hazakura)
        let breezeCount = ParticleBudget.storageCount(baseCount: BaseParticleCount.breeze)
        let magicCount = ParticleBudget.storageCount(baseCount: BaseParticleCount.magic)
        let fireflyCount = ParticleBudget.storageCount(baseCount: BaseParticleCount.firefly)
        let sparkCount = ParticleBudget.storageCount(baseCount: BaseParticleCount.spark)

        sakuraParticles = (0..<sakuraCount).map { _ in DriftParticle(style: .sakura, initial: true, bounds: bounds) }
        hazakuraParticles = (0..<hazakuraCount).map { _ in DriftParticle(style: .hazakura, initial: true, bounds: bounds) }
        breezeParticles = (0..<breezeCount).map { _ in DriftParticle(style: .breeze, initial: true, bounds: bounds) }
        magicLights = (0..<magicCount).map { _ in MagicLight(initial: true, bounds: bounds) }
        fireflies = (0..<fireflyCount).map { _ in Firefly(initial: true, bounds: bounds) }
        sparkLines = (0..<sparkCount).map { _ in SparkLine(initial: true, bounds: bounds) }
        sparkles = (0..<58).map { _ in Sparkle(initial: true, bounds: bounds) }
        trees = [.init(side: .left), .init(side: .right)]
    }

    private func drawParticles(
        _ particles: inout [DriftParticle],
        baseCount: Int,
        in context: CGContext,
        bounds: CGRect,
        time: TimeInterval,
        settings: EffectSettings
    ) {
        let visibleCount = ParticleBudget.visibleCount(
            baseCount: baseCount,
            availableCount: particles.count,
            intensity: settings.intensity
        )
        guard visibleCount > 0 else { return }

        for index in 0..<visibleCount {
            particles[index].update(time: time, pointer: pointer, bounds: bounds, settings: settings)
            particles[index].draw(in: context, settings: settings)
        }
    }

    private func drawBackdrop(in context: CGContext, bounds: CGRect, time: TimeInterval, settings: EffectSettings) {
        drawBackground(context, bounds: bounds, time: time, settings: settings)
        if settings.showsNightBackground {
            for tree in trees {
                tree.draw(in: context, bounds: bounds)
            }
        }

        for index in sparkles.indices {
            sparkles[index].update(time: time, pointer: pointer, bounds: bounds, settings: settings)
            sparkles[index].draw(in: context, settings: settings)
        }
    }

    private func drawMagic(in context: CGContext, bounds: CGRect, time: TimeInterval, settings: EffectSettings) {
        let visibleCount = ParticleBudget.visibleCount(
            baseCount: BaseParticleCount.magic,
            availableCount: magicLights.count,
            intensity: settings.intensity
        )
        guard visibleCount > 0 else { return }

        for index in 0..<visibleCount {
            magicLights[index].update(time: time, pointer: pointer, bounds: bounds, settings: settings)
            magicLights[index].draw(in: context, time: time, settings: settings)
        }
    }

    private func updateMagicLayerSprites(
        bounds: CGRect,
        time: TimeInterval,
        settings: EffectSettings
    ) -> [SakuraGlowLayerSprite] {
        let visibleCount = ParticleBudget.visibleCount(
            baseCount: BaseParticleCount.magic,
            availableCount: magicLights.count,
            intensity: settings.intensity
        )
        guard visibleCount > 0 else { return [] }

        var sprites: [SakuraGlowLayerSprite] = []
        sprites.reserveCapacity(visibleCount * 2)
        for index in 0..<visibleCount {
            magicLights[index].update(time: time, pointer: pointer, bounds: bounds, settings: settings)
            magicLights[index].appendLayerSprites(to: &sprites, time: time, settings: settings)
        }
        return sprites
    }

    private func drawFireflies(in context: CGContext, bounds: CGRect, time: TimeInterval, settings: EffectSettings) {
        let visibleCount = ParticleBudget.visibleCount(
            baseCount: BaseParticleCount.firefly,
            availableCount: fireflies.count,
            intensity: settings.intensity
        )
        guard visibleCount > 0 else { return }

        for index in 0..<visibleCount {
            fireflies[index].update(time: time, pointer: pointer, bounds: bounds, settings: settings)
            fireflies[index].draw(in: context, time: time, settings: settings)
        }
    }

    private func updateFireflyLayerSprites(
        bounds: CGRect,
        time: TimeInterval,
        settings: EffectSettings
    ) -> [SakuraGlowLayerSprite] {
        let visibleCount = ParticleBudget.visibleCount(
            baseCount: BaseParticleCount.firefly,
            availableCount: fireflies.count,
            intensity: settings.intensity
        )
        guard visibleCount > 0 else { return [] }

        var sprites: [SakuraGlowLayerSprite] = []
        sprites.reserveCapacity(visibleCount * 2)
        for index in 0..<visibleCount {
            fireflies[index].update(time: time, pointer: pointer, bounds: bounds, settings: settings)
            fireflies[index].appendLayerSprites(to: &sprites, time: time, settings: settings)
        }
        return sprites
    }

    private func drawSparks(in context: CGContext, bounds: CGRect, time: TimeInterval, settings: EffectSettings) {
        let visibleCount = ParticleBudget.visibleCount(
            baseCount: BaseParticleCount.spark,
            availableCount: sparkLines.count,
            intensity: settings.intensity
        )
        guard visibleCount > 0 else { return }

        for index in 0..<visibleCount {
            sparkLines[index].update(time: time, pointer: pointer, bounds: bounds, settings: settings)
            sparkLines[index].draw(in: context, time: time, settings: settings)
        }
    }

    private func drawBackground(_ context: CGContext, bounds: CGRect, time: TimeInterval, settings: EffectSettings) {
        guard settings.showsNightBackground else { return }

        let colors = [
            RGBAColor(18, 7, 24, 0.84).cgColor,
            RGBAColor(35, 14, 36, 0.74).cgColor,
            RGBAColor(5, 5, 12, 0.88).cgColor
        ]
        if let gradient = CGGradient(
            colorsSpace: deviceRGB,
            colors: colors as CFArray,
            locations: [0, 0.46, 1]
        ) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: bounds.midX, y: bounds.minY),
                end: CGPoint(x: bounds.midX, y: bounds.maxY),
                options: []
            )
        }

        let moon = CGPoint(
            x: bounds.width * 0.8 + CGFloat(sin(time * 0.08)) * 18,
            y: bounds.height * 0.18
        )
        context.drawGlow(
            center: moon,
            radius: 170,
            colors: [
                RGBAColor(255, 238, 225, 0.18).cgColor,
                RGBAColor(255, 210, 222, 0.08).cgColor,
                RGBAColor(255, 210, 222, 0).cgColor
            ],
            locations: [0, 0.28, 1]
        )
    }
}

struct SakuraSceneDiagnostics: Equatable {
    var boundsSize: CGSize
    var resetGeneration: Int
    var sakuraParticleCount: Int
    var hazakuraParticleCount: Int
    var breezeParticleCount: Int
    var magicLightCount: Int
    var fireflyCount: Int
    var sparkLineCount: Int
    var sparkleCount: Int
    var treeCount: Int

    static let expectedParticleStorage = SakuraSceneDiagnostics(
        boundsSize: .zero,
        resetGeneration: 0,
        sakuraParticleCount: 193,
        hazakuraParticleCount: 196,
        breezeParticleCount: 215,
        magicLightCount: 285,
        fireflyCount: 187,
        sparkLineCount: 171,
        sparkleCount: 58,
        treeCount: 2
    )

    var matchesExpectedParticleStorage: Bool {
        sakuraParticleCount == Self.expectedParticleStorage.sakuraParticleCount &&
            hazakuraParticleCount == Self.expectedParticleStorage.hazakuraParticleCount &&
            breezeParticleCount == Self.expectedParticleStorage.breezeParticleCount &&
            magicLightCount == Self.expectedParticleStorage.magicLightCount &&
            fireflyCount == Self.expectedParticleStorage.fireflyCount &&
            sparkLineCount == Self.expectedParticleStorage.sparkLineCount &&
            sparkleCount == Self.expectedParticleStorage.sparkleCount &&
            treeCount == Self.expectedParticleStorage.treeCount
    }
}

private protocol Particle {
    mutating func update(time: TimeInterval, pointer: PointerMotionState, bounds: CGRect, settings: EffectSettings)
    @MainActor func draw(in context: CGContext, settings: EffectSettings)
}

enum AnimationClock {
    static func legacyOrbitPhase(
        time: TimeInterval,
        orbitSpeed: CGFloat,
        speedMultiplier: CGFloat = 1,
        phase: CGFloat
    ) -> CGFloat {
        // The original canvas renderer fed requestAnimationFrame milliseconds into orbitSpeed.
        CGFloat(time) * 1_000 * orbitSpeed * speedMultiplier + phase
    }
}

private enum DriftStyle {
    case sakura
    case hazakura
    case breeze
}

private struct DriftParticle: Particle {
    var style: DriftStyle
    var x: CGFloat = 0
    var y: CGFloat = 0
    var size: CGFloat = 10
    var phase: CGFloat = 0
    var orbit: CGFloat = 0
    var orbitSpeed: CGFloat = 0
    var velocity = CGVector.zero
    var spin: CGFloat = 0
    var rotation: CGFloat = 0
    var alpha: CGFloat = 1
    var color = SakuraPalette.petals[0]
    var isFlower = false
    var isLeaf = false
    var flip: CGFloat = 1

    init(style: DriftStyle, initial: Bool, bounds: CGRect) {
        self.style = style
        reset(initial: initial, bounds: bounds)
    }

    mutating func reset(initial: Bool = false, bounds: CGRect) {
        x = Random.cgFloat((-bounds.width * 0.12)...(bounds.width * 1.08))
        y = initial ? Random.cgFloat((-bounds.height * 0.2)...(bounds.height * 1.05)) : Random.cgFloat((-120)...(-20))
        size = Random.cgFloat(7...18)
        phase = Random.cgFloat(0...(CGFloat.pi * 2))
        orbit = Random.cgFloat(6...34)
        orbitSpeed = Random.cgFloat(0.001...0.003)
        velocity = CGVector(dx: Random.cgFloat((-0.12)...0.16), dy: Random.cgFloat(0.14...0.72))
        spin = Random.cgFloat((-0.012)...0.012)
        rotation = Random.cgFloat(0...(CGFloat.pi * 2))
        alpha = Random.cgFloat(0.36...0.78)
        isFlower = Random.bool(probability: 0.34)
        isLeaf = false
        color = Random.element(in: SakuraPalette.petals) ?? SakuraPalette.petals[0]
        flip = Random.bool() ? -1 : 1

        if style == .hazakura {
            color = Random.element(in: SakuraPalette.hazakura) ?? SakuraPalette.hazakura[0]
            isFlower = Random.bool(probability: 0.22)
            isLeaf = color.green > color.red
            alpha = isLeaf ? Random.cgFloat(0.26...0.58) : Random.cgFloat(0.28...0.68)
            size = isLeaf ? Random.cgFloat(5...13) : Random.cgFloat(6...16)
        } else if style == .breeze {
            color = Random.element(in: SakuraPalette.breeze) ?? SakuraPalette.breeze[0]
            isFlower = false
            isLeaf = Random.bool(probability: 0.46)
            alpha = Random.cgFloat(0.22...0.55)
            size = Random.cgFloat(4.8...14)
            orbit = Random.cgFloat(22...72)
            orbitSpeed = Random.cgFloat(0.0018...0.0046)
            velocity = CGVector(dx: Random.cgFloat(0.34...1.15), dy: Random.cgFloat((-0.04)...0.38))
        }
    }

    mutating func update(time: TimeInterval, pointer: PointerMotionState, bounds: CGRect, settings: EffectSettings) {
        applyRepel(pointer: pointer, radius: isFlower ? 104 : 118, strength: isFlower ? 4.8 : 6.2, settings: settings)
        let orbitPhase = AnimationClock.legacyOrbitPhase(time: time, orbitSpeed: orbitSpeed, phase: phase)
        let verticalPhase = AnimationClock.legacyOrbitPhase(time: time, orbitSpeed: orbitSpeed, speedMultiplier: 0.82, phase: phase)
        let drift = sin(orbitPhase) * orbit
        x += (velocity.dx + drift * 0.018 + pointer.windX * 0.28) * settings.intensity.speedScale
        y += (velocity.dy + cos(verticalPhase) * 0.18 + pointer.windY * 0.2) * settings.intensity.speedScale
        rotation += spin + velocity.dx * 0.01

        if y > bounds.height + 80 || x < -120 || x > bounds.width + 140 {
            reset(bounds: bounds)
        }
    }

    @MainActor func draw(in context: CGContext, settings: EffectSettings) {
        let scaledSize = size * settings.intensity.sizeScale
        let scaledAlpha = alpha * settings.intensity.alphaScale

        if isLeaf {
            drawLeaf(in: context, size: scaledSize, alpha: scaledAlpha)
        } else if isFlower {
            drawFlower(in: context, size: scaledSize * 1.22, alpha: scaledAlpha * 0.74)
        } else {
            context.drawPetal(center: CGPoint(x: x, y: y), size: scaledSize, rotation: rotation, alpha: scaledAlpha, color: color, flip: flip)
        }
    }

    private mutating func applyRepel(pointer: PointerMotionState, radius: CGFloat, strength: CGFloat, settings: EffectSettings) {
        guard pointer.isActive else { return }
        let dx = x - pointer.point.x
        let dy = y - pointer.point.y
        let distanceSquared = dx * dx + dy * dy
        let radiusSquared = radius * radius
        guard distanceSquared < radiusSquared, distanceSquared > 0.01 else { return }

        let distance = sqrt(distanceSquared)
        let force = pow(1 - distance / radius, 2) * strength * settings.intensity.repelScale
        let nx = dx / distance
        let ny = dy / distance
        velocity.dx += nx * force + pointer.velocity.dx * 0.035
        velocity.dy += ny * force + pointer.velocity.dy * 0.035
        spin += force * 0.012 * (nx >= 0 ? 1 : -1)
    }

    @MainActor private func drawFlower(in context: CGContext, size: CGFloat, alpha: CGFloat) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        for index in 0..<5 {
            context.saveGState()
            context.rotate(by: CGFloat(index) * CGFloat.pi * 2 / 5)
            context.drawPetal(center: CGPoint(x: 0, y: -size * 0.36), size: size * 0.62, rotation: 0, alpha: alpha, color: color, flip: 1)
            context.restoreGState()
        }
        context.drawGlow(
            center: .zero,
            radius: size * 0.26,
            colors: [RGBAColor(224, 91, 137, 0.58).cgColor, RGBAColor(224, 91, 137, 0).cgColor],
            locations: [0, 1]
        )
        context.restoreGState()
    }

    private func drawLeaf(in context: CGContext, size: CGFloat, alpha: CGFloat) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        context.setAlpha(alpha)
        context.setFillColor(color.withAlpha(0.58).cgColor)
        context.fillEllipse(in: CGRect(x: -size * 0.28, y: -size * 0.62, width: size * 0.56, height: size * 1.24))
        context.setAlpha(alpha * 0.45)
        context.setStrokeColor(RGBAColor(245, 255, 236, 0.42).cgColor)
        context.setLineWidth(1.1)
        context.move(to: CGPoint(x: 0, y: -size * 0.44))
        context.addLine(to: CGPoint(x: 0, y: size * 0.44))
        context.strokePath()
        context.restoreGState()
    }
}

private struct Sparkle: Particle {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var size: CGFloat = 1
    var phase: CGFloat = 0
    var drift = CGVector.zero
    var maxAlpha: CGFloat = 0
    var alpha: CGFloat = 0

    init(initial: Bool, bounds: CGRect) {
        reset(initial: initial, bounds: bounds)
    }

    mutating func reset(initial: Bool = false, bounds: CGRect) {
        x = Random.cgFloat(0...max(1, bounds.width))
        y = initial ? Random.cgFloat(0...max(1, bounds.height)) : Random.cgFloat((bounds.height * 0.2)...(bounds.height + 80))
        size = Random.cgFloat(0.7...2.4)
        phase = Random.cgFloat(0...(CGFloat.pi * 2))
        drift = CGVector(dx: Random.cgFloat((-0.12)...0.25), dy: Random.cgFloat((-0.32)...(-0.06)))
        maxAlpha = Random.cgFloat(0.1...0.38)
    }

    mutating func update(time: TimeInterval, pointer: PointerMotionState, bounds: CGRect, settings: EffectSettings) {
        x += drift.dx + pointer.windX * 0.03
        y += drift.dy
        alpha = ((sin(CGFloat(time) * 2 + phase) + 1) / 2) * maxAlpha

        if y < -20 || x < -20 || x > bounds.width + 20 {
            reset(bounds: bounds)
        }
    }

    func draw(in context: CGContext, settings: EffectSettings) {
        guard settings.showsNightBackground, alpha > 0.02 else { return }
        context.drawGlow(
            center: CGPoint(x: x, y: y),
            radius: size * 3.4,
            colors: [RGBAColor(255, 244, 248, 0.64 * alpha).cgColor, RGBAColor(255, 244, 248, 0).cgColor],
            locations: [0, 1]
        )
    }
}

private struct MagicLight {
    private static func outerGlowSpec(hue: CGFloat) -> SakuraGlowImageSpec? {
        SakuraGlowImageSpec(
            colors: [
                cgColor(hue: hue / 360, saturation: 0.96, brightness: 0.88, alpha: 1),
                cgColor(hue: (hue + 24) / 360, saturation: 0.92, brightness: 0.72, alpha: 0.11 / 0.34),
                cgColor(hue: hue / 360, saturation: 0.96, brightness: 0.6, alpha: 0)
            ],
            locations: [0, 0.42, 1]
        )
    }

    private static func innerGlowSpec(hue: CGFloat) -> SakuraGlowImageSpec? {
        SakuraGlowImageSpec(
            colors: [
                cgColor(hue: (hue + 8) / 360, saturation: 1, brightness: 0.94, alpha: 1),
                cgColor(hue: hue / 360, saturation: 1, brightness: 0.82, alpha: 0.22 / 0.68),
                cgColor(hue: hue / 360, saturation: 1, brightness: 0.7, alpha: 0)
            ],
            locations: [0, 0.62, 1]
        )
    }

    var x: CGFloat = 0
    var y: CGFloat = 0
    var size: CGFloat = 2
    var phase: CGFloat = 0
    var orbit: CGFloat = 0
    var orbitSpeed: CGFloat = 0
    var velocity = CGVector.zero
    var spin: CGFloat = 0
    var alpha: CGFloat = 0
    var hue: CGFloat = 300
    private var outerGlowSpec: SakuraGlowImageSpec?
    private var innerGlowSpec: SakuraGlowImageSpec?

    init(initial: Bool, bounds: CGRect) {
        reset(initial: initial, bounds: bounds)
    }

    mutating func reset(initial: Bool = false, bounds: CGRect) {
        x = Random.cgFloat((-bounds.width * 0.1)...(bounds.width * 1.1))
        y = initial ? Random.cgFloat(0...max(1, bounds.height)) : Random.cgFloat((bounds.height + 20)...(bounds.height + 180))
        size = Random.cgFloat(2.2...8)
        phase = Random.cgFloat(0...(CGFloat.pi * 2))
        orbit = Random.cgFloat(8...42)
        orbitSpeed = Random.cgFloat(0.0012...0.0038)
        velocity = CGVector(dx: Random.cgFloat((-0.2)...0.2), dy: Random.cgFloat((-0.9)...(-0.28)))
        spin = Random.cgFloat((-0.02)...0.02)
        alpha = Random.cgFloat(0.22...0.58)
        hue = Random.cgFloat(292...334)
        outerGlowSpec = Self.outerGlowSpec(hue: hue)
        innerGlowSpec = Self.innerGlowSpec(hue: hue)
    }

    mutating func update(time: TimeInterval, pointer: PointerMotionState, bounds: CGRect, settings: EffectSettings) {
        applyRepel(pointer: pointer, radius: 122, strength: 5.2, settings: settings)
        let orbitPhase = AnimationClock.legacyOrbitPhase(time: time, orbitSpeed: orbitSpeed, phase: phase)
        let verticalPhase = AnimationClock.legacyOrbitPhase(time: time, orbitSpeed: orbitSpeed, speedMultiplier: 0.8, phase: phase)
        let drift = sin(orbitPhase) * orbit
        x += (velocity.dx + drift * 0.018 + pointer.windX * 0.08) * settings.intensity.speedScale
        y += (velocity.dy + cos(verticalPhase) * 0.18 + pointer.windY * 0.04) * settings.intensity.speedScale
        spin += sin(CGFloat(time) * 0.7 + phase) * 0.0009

        if y < -80 || x < -140 || x > bounds.width + 140 {
            reset(bounds: bounds)
        }
    }

    @MainActor func draw(in context: CGContext, time: TimeInterval, settings: EffectSettings) {
        context.saveGState()
        context.setBlendMode(.plusLighter)
        forEachLayerSprite(time: time, settings: settings) { sprite in
            context.saveGState()
            context.setAlpha(sprite.opacity)
            context.draw(sprite.image, in: sprite.frame)
            context.restoreGState()
        }
        context.restoreGState()
    }

    @MainActor func appendLayerSprites(
        to sprites: inout [SakuraGlowLayerSprite],
        time: TimeInterval,
        settings: EffectSettings
    ) {
        forEachLayerSprite(time: time, settings: settings) { sprite in
            sprites.append(sprite)
        }
    }

    @MainActor private func forEachLayerSprite(
        time: TimeInterval,
        settings: EffectSettings,
        _ body: (SakuraGlowLayerSprite) -> Void
    ) {
        let twinkle = 0.72 + sin(CGFloat(time) * 4 + phase) * 0.28
        let drawAlpha = alpha * twinkle * settings.intensity.alphaScale
        let orbitPhase = AnimationClock.legacyOrbitPhase(time: time, orbitSpeed: orbitSpeed, phase: phase)
        let point = CGPoint(
            x: x + sin(orbitPhase) * orbit * 0.24,
            y: y + cos(orbitPhase) * orbit * 0.12
        )
        let drawSize = size * settings.intensity.sizeScale

        let outer = outerGlowSpec.flatMap { spec in
            makeGlowLayerSprite(
                center: point,
                radius: drawSize * 5.2,
                opacity: 0.34 * drawAlpha,
                spec: spec
            )
        }
        if let outer {
            body(outer)
        }
        let inner = innerGlowSpec.flatMap { spec in
            makeGlowLayerSprite(
                center: point,
                radius: drawSize * 1.7,
                opacity: 0.68 * drawAlpha,
                spec: spec
            )
        }
        if let inner {
            body(inner)
        }
    }

    private mutating func applyRepel(pointer: PointerMotionState, radius: CGFloat, strength: CGFloat, settings: EffectSettings) {
        guard pointer.isActive else { return }
        let dx = x - pointer.point.x
        let dy = y - pointer.point.y
        let distanceSquared = dx * dx + dy * dy
        guard distanceSquared < radius * radius, distanceSquared > 0.01 else { return }
        let distance = sqrt(distanceSquared)
        let force = pow(1 - distance / radius, 2) * strength * settings.intensity.repelScale
        velocity.dx += dx / distance * force + pointer.velocity.dx * 0.035
        velocity.dy += dy / distance * force + pointer.velocity.dy * 0.035
    }
}

private struct Firefly {
    private static let outerGlowSpec = SakuraGlowImageSpec(
        colors: [
            RGBAColor(226, 255, 159, 1).cgColor,
            RGBAColor(122, 214, 112, 0.5).cgColor,
            RGBAColor(122, 214, 112, 0).cgColor
        ],
        locations: [0, 0.45, 1]
    )
    private static let innerGlowSpec = SakuraGlowImageSpec(
        colors: [
            RGBAColor(255, 250, 178, 1).cgColor,
            RGBAColor(204, 245, 105, 0.2 / 0.76).cgColor,
            RGBAColor(204, 245, 105, 0).cgColor
        ],
        locations: [0, 0.58, 1]
    )

    var x: CGFloat = 0
    var y: CGFloat = 0
    var size: CGFloat = 0
    var phase: CGFloat = 0
    var orbit: CGFloat = 0
    var orbitSpeed: CGFloat = 0
    var velocity = CGVector.zero
    var alpha: CGFloat = 0

    init(initial: Bool, bounds: CGRect) {
        reset(initial: initial, bounds: bounds)
    }

    mutating func reset(initial: Bool = false, bounds: CGRect) {
        x = initial ? Random.cgFloat(0...max(1, bounds.width)) : Random.cgFloat((-80)...(-20))
        y = Random.cgFloat((bounds.height * 0.18)...max(bounds.height * 0.92, 1))
        size = Random.cgFloat(2.8...7.4)
        phase = Random.cgFloat(0...(CGFloat.pi * 2))
        orbit = Random.cgFloat(16...62)
        orbitSpeed = Random.cgFloat(0.0008...0.0022)
        velocity = CGVector(dx: Random.cgFloat(0.18...0.72), dy: Random.cgFloat((-0.18)...0.18))
        alpha = Random.cgFloat(0.18...0.62)
    }

    mutating func update(time: TimeInterval, pointer: PointerMotionState, bounds: CGRect, settings: EffectSettings) {
        applyRepel(pointer: pointer, radius: 120, strength: 4.2, settings: settings)
        let orbitPhase = AnimationClock.legacyOrbitPhase(time: time, orbitSpeed: orbitSpeed, phase: phase)
        x += (velocity.dx + sin(orbitPhase) * 0.16 + pointer.windX * 0.06) * settings.intensity.speedScale
        y += (velocity.dy + cos(orbitPhase * 0.7) * 0.15 + pointer.windY * 0.03) * settings.intensity.speedScale

        if x > bounds.width + 90 || y < -60 || y > bounds.height + 70 {
            reset(bounds: bounds)
        }
    }

    @MainActor func draw(in context: CGContext, time: TimeInterval, settings: EffectSettings) {
        context.saveGState()
        context.setBlendMode(.plusLighter)
        forEachLayerSprite(time: time, settings: settings) { sprite in
            context.saveGState()
            context.setAlpha(sprite.opacity)
            context.draw(sprite.image, in: sprite.frame)
            context.restoreGState()
        }
        context.restoreGState()
    }

    @MainActor func appendLayerSprites(
        to sprites: inout [SakuraGlowLayerSprite],
        time: TimeInterval,
        settings: EffectSettings
    ) {
        forEachLayerSprite(time: time, settings: settings) { sprite in
            sprites.append(sprite)
        }
    }

    @MainActor private func forEachLayerSprite(
        time: TimeInterval,
        settings: EffectSettings,
        _ body: (SakuraGlowLayerSprite) -> Void
    ) {
        let twinkle = max(0.18, 0.66 + sin(CGFloat(time) * 3.4 + phase) * 0.34)
        let drawAlpha = alpha * twinkle * settings.intensity.alphaScale
        let drawSize = size * settings.intensity.sizeScale
        let point = CGPoint(x: x, y: y)

        if let outerGlowSpec = Self.outerGlowSpec,
           let outer = makeGlowLayerSprite(
            center: point,
            radius: drawSize * 7.2,
            opacity: 0.28 * drawAlpha,
            spec: outerGlowSpec
        ) {
            body(outer)
        }
        if let innerGlowSpec = Self.innerGlowSpec,
           let inner = makeGlowLayerSprite(
            center: point,
            radius: drawSize * 2.1,
            opacity: 0.76 * drawAlpha,
            spec: innerGlowSpec
        ) {
            body(inner)
        }
    }

    private mutating func applyRepel(pointer: PointerMotionState, radius: CGFloat, strength: CGFloat, settings: EffectSettings) {
        guard pointer.isActive else { return }
        let dx = x - pointer.point.x
        let dy = y - pointer.point.y
        let distanceSquared = dx * dx + dy * dy
        guard distanceSquared < radius * radius, distanceSquared > 0.01 else { return }
        let distance = sqrt(distanceSquared)
        let force = pow(1 - distance / radius, 2) * strength * settings.intensity.repelScale
        velocity.dx += dx / distance * force + pointer.velocity.dx * 0.025
        velocity.dy += dy / distance * force + pointer.velocity.dy * 0.025
    }
}

private struct SparkLine {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var length: CGFloat = 0
    var size: CGFloat = 0
    var phase: CGFloat = 0
    var velocity = CGVector.zero
    var rotation: CGFloat = 0
    var spin: CGFloat = 0
    var alpha: CGFloat = 0
    var hue: CGFloat = 300

    init(initial: Bool, bounds: CGRect) {
        reset(initial: initial, bounds: bounds)
    }

    mutating func reset(initial: Bool = false, bounds: CGRect) {
        x = Random.cgFloat((-bounds.width * 0.08)...(bounds.width * 1.08))
        y = initial ? Random.cgFloat(0...max(1, bounds.height)) : Random.cgFloat((bounds.height + 40)...(bounds.height + 180))
        length = Random.cgFloat(14...58)
        size = Random.cgFloat(1.4...3.8)
        phase = Random.cgFloat(0...(CGFloat.pi * 2))
        velocity = CGVector(dx: Random.cgFloat((-0.32)...0.34), dy: Random.cgFloat((-1.15)...(-0.32)))
        rotation = Random.cgFloat(0...(CGFloat.pi * 2))
        spin = Random.cgFloat((-0.018)...0.018)
        alpha = Random.cgFloat(0.34...0.82)
        hue = Random.cgFloat(292...344)
    }

    mutating func update(time: TimeInterval, pointer: PointerMotionState, bounds: CGRect, settings: EffectSettings) {
        applyRepel(pointer: pointer, radius: 126, strength: 6.5, settings: settings)
        x += (velocity.dx + pointer.windX * 0.12 + sin(CGFloat(time) + phase) * 0.18) * settings.intensity.speedScale
        y += (velocity.dy + pointer.windY * 0.05) * settings.intensity.speedScale
        rotation += spin

        if y < -90 || x < -140 || x > bounds.width + 140 {
            reset(bounds: bounds)
        }
    }

    @MainActor func draw(in context: CGContext, time: TimeInterval, settings: EffectSettings) {
        let twinkle = 0.74 + sin(CGFloat(time) * 5 + phase) * 0.26
        let scale = settings.intensity.sizeScale
        let drawLength = length * scale
        let core = size * scale * 1.8
        let drawAlpha = alpha * twinkle * settings.intensity.alphaScale

        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        context.setBlendMode(.plusLighter)

        for axis in 0..<4 {
            let rayLength = drawLength * (axis.isMultiple(of: 2) ? 1 : 0.68)
            let rayWidth = core * (axis.isMultiple(of: 2) ? 0.75 : 0.58)
            context.saveGState()
            context.rotate(by: CGFloat(axis) * CGFloat.pi * 0.5)
            context.setAlpha(drawAlpha * (axis.isMultiple(of: 2) ? 0.52 : 0.34))
            context.setFillColor(cgColor(hue: (hue + 18) / 360, saturation: 1, brightness: 0.94, alpha: 1))
            context.addPath(cachedSparkRayPath(rayLength: rayLength, rayWidth: rayWidth))
            context.fillPath()
            context.restoreGState()
        }

        context.setAlpha(drawAlpha * 0.72)
        context.setFillColor(cgColor(hue: (hue + 20) / 360, saturation: 1, brightness: 0.96, alpha: 1))
        context.fillEllipse(in: CGRect(x: -core * 1.15, y: -core * 1.15, width: core * 2.3, height: core * 2.3))
        context.restoreGState()
    }

    private mutating func applyRepel(pointer: PointerMotionState, radius: CGFloat, strength: CGFloat, settings: EffectSettings) {
        guard pointer.isActive else { return }
        let dx = x - pointer.point.x
        let dy = y - pointer.point.y
        let distanceSquared = dx * dx + dy * dy
        guard distanceSquared < radius * radius, distanceSquared > 0.01 else { return }
        let distance = sqrt(distanceSquared)
        let force = pow(1 - distance / radius, 2) * strength * settings.intensity.repelScale
        velocity.dx += dx / distance * force + pointer.velocity.dx * 0.035
        velocity.dy += dy / distance * force + pointer.velocity.dy * 0.035
    }
}

private struct SparkRayPathCacheKey: Hashable {
    var lengthBitPattern: UInt64
    var widthBitPattern: UInt64

    init(rayLength: CGFloat, rayWidth: CGFloat) {
        lengthBitPattern = Double(rayLength).bitPattern
        widthBitPattern = Double(rayWidth).bitPattern
    }
}

@MainActor private func cachedSparkRayPath(rayLength: CGFloat, rayWidth: CGFloat) -> CGPath {
    let key = SparkRayPathCacheKey(rayLength: rayLength, rayWidth: rayWidth)
    if let cached = sparkRayPathCache[key] {
        return cached
    }

    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: -rayWidth))
    path.addQuadCurve(
        to: CGPoint(x: rayLength, y: 0),
        control: CGPoint(x: rayLength * 0.52, y: -rayWidth * 0.4)
    )
    path.addQuadCurve(
        to: CGPoint(x: 0, y: rayWidth),
        control: CGPoint(x: rayLength * 0.52, y: rayWidth * 0.4)
    )
    path.addQuadCurve(to: .zero, control: CGPoint(x: rayLength * 0.1, y: rayWidth * 0.18))
    path.addQuadCurve(
        to: CGPoint(x: 0, y: -rayWidth),
        control: CGPoint(x: rayLength * 0.1, y: -rayWidth * 0.18)
    )
    let immutablePath = path.copy() ?? path
    sparkRayPathCache[key] = immutablePath
    sparkRayPathCacheOrder.append(key)
    while sparkRayPathCacheOrder.count > maximumSparkRayPathCacheEntries {
        let removedKey = sparkRayPathCacheOrder.removeFirst()
        sparkRayPathCache.removeValue(forKey: removedKey)
    }
    return immutablePath
}

private struct SakuraTree {
    enum Side {
        case left
        case right
    }

    struct Branch {
        var startY: CGFloat
        var length: CGFloat
        var angle: CGFloat
        var width: CGFloat
        var curve: CGFloat
    }

    struct Flower {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var color: RGBAColor
        var alpha: CGFloat
    }

    var side: Side
    var branches: [Branch]
    var flowers: [Flower]

    init(side: Side) {
        self.side = side
        self.branches = (0..<(side == .left ? 11 : 13)).map { _ in
            Branch(
                startY: Random.cgFloat((-110)...(-20)),
                length: Random.cgFloat(80...230),
                angle: -CGFloat.pi / 2 + Random.cgFloat((-0.56)...0.56),
                width: Random.cgFloat(2...5.2),
                curve: Random.cgFloat((-0.65)...0.65)
            )
        }
        self.flowers = (0..<76).map { _ in
            Flower(
                x: Random.cgFloat((-135)...135),
                y: Random.cgFloat((-286)...(-44)),
                size: Random.cgFloat(7...20),
                color: Random.element(in: SakuraPalette.petals) ?? SakuraPalette.petals[0],
                alpha: Random.cgFloat(0.16...0.38)
            )
        }
    }

    @MainActor func draw(in context: CGContext, bounds: CGRect) {
        let baseX = side == .left ? -34 : bounds.width + 34
        let direction: CGFloat = side == .left ? 1 : -1

        context.saveGState()
        context.translateBy(x: baseX, y: bounds.height + 12)
        context.scaleBy(x: direction, y: 1)
        context.setStrokeColor(RGBAColor(30, 15, 24, 0.9).cgColor)
        context.setLineCap(.round)
        context.setLineWidth(10)
        context.move(to: .zero)
        context.addQuadCurve(to: CGPoint(x: 2, y: -246), control: CGPoint(x: 14, y: -118))
        context.strokePath()

        for branch in branches {
            context.setLineWidth(branch.width)
            context.move(to: CGPoint(x: 0, y: branch.startY))
            let endX = cos(branch.angle) * branch.length + branch.curve * 62
            let endY = branch.startY + sin(branch.angle) * branch.length
            context.addQuadCurve(
                to: CGPoint(x: endX, y: endY),
                control: CGPoint(x: branch.curve * 46, y: branch.startY - branch.length * 0.5)
            )
            context.strokePath()
        }

        for flower in flowers {
            context.drawGlow(
                center: CGPoint(x: flower.x, y: flower.y),
                radius: flower.size,
                colors: [
                    flower.color.withAlpha(flower.alpha).cgColor,
                    flower.color.withAlpha(flower.alpha * 0.32).cgColor,
                    flower.color.withAlpha(0).cgColor
                ],
                locations: [0, 0.72, 1]
            )
        }

        context.restoreGState()
    }
}
