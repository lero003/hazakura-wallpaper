import CoreGraphics
import Foundation
import SakuraSkyCore
@testable import SakuraSkyRenderer
import Testing

@MainActor
@Test(arguments: EffectMode.allCases)
func rendererProducesVisiblePixelsForEveryMode(_ mode: EffectMode) {
    let visiblePixels = SakuraRenderSmoke.nonTransparentPixelCount(mode: mode)

    #expect(visiblePixels > 0)
}

@MainActor
@Test func deterministicSceneSeedProducesStableRenderSmoke() {
    let first = SakuraScene.withDeterministicRandomSeed(42) {
        SakuraRenderSmoke.nonTransparentPixelCount(
            mode: .hazakura,
            intensity: .play,
            showsNightBackground: true
        )
    }
    let second = SakuraScene.withDeterministicRandomSeed(42) {
        SakuraRenderSmoke.nonTransparentPixelCount(
            mode: .hazakura,
            intensity: .play,
            showsNightBackground: true
        )
    }

    #expect(first > 0)
    #expect(first == second)
}

@MainActor
@Test func deterministicRandomSeedRestoresOuterScopeAfterNesting() {
    let control = SakuraScene.withDeterministicRandomSeed(7) {
        (
            Random.double(0...1),
            Random.double(0...1)
        )
    }
    let nested = SakuraScene.withDeterministicRandomSeed(7) {
        let first = Random.double(0...1)
        _ = SakuraScene.withDeterministicRandomSeed(99) {
            (
                Random.double(0...1),
                Random.double(0...1)
            )
        }
        return (
            first,
            Random.double(0...1)
        )
    }

    #expect(control.0 == nested.0)
    #expect(control.1 == nested.1)
}

@MainActor
@Test func nightBackgroundProducesDenseCoverage() {
    let visiblePixels = SakuraRenderSmoke.nonTransparentPixelCount(
        mode: .sakura,
        showsNightBackground: true,
        size: CGSize(width: 120, height: 90)
    )

    #expect(visiblePixels > 9_000)
}

@MainActor
@Test func glowRenderingUsesProvidedGradientColors() throws {
    let redPixel = try centerPixelForGlow(colors: [
        RGBAColor(255, 0, 0, 1).cgColor,
        RGBAColor(255, 0, 0, 0).cgColor
    ])
    let bluePixel = try centerPixelForGlow(colors: [
        RGBAColor(0, 0, 255, 1).cgColor,
        RGBAColor(0, 0, 255, 0).cgColor
    ])

    #expect(redPixel.red > redPixel.blue * 2)
    #expect(bluePixel.blue > bluePixel.red * 2)
}

@MainActor
@Test func glowImageCacheReusesNormalizedAlphaStops() throws {
    resetGlowImageCacheForTesting()
    let first = makeGlowLayerSprite(
        center: .zero,
        radius: 12,
        colors: [
            RGBAColor(255, 250, 178, 0.76).cgColor,
            RGBAColor(204, 245, 105, 0.2).cgColor,
            RGBAColor(204, 245, 105, 0).cgColor
        ],
        locations: [0, 0.58, 1]
    )
    let firstCount = glowImageCacheEntryCountForTesting()
    let second = makeGlowLayerSprite(
        center: .zero,
        radius: 12,
        colors: [
            RGBAColor(255, 250, 178, 0.38).cgColor,
            RGBAColor(204, 245, 105, 0.1).cgColor,
            RGBAColor(204, 245, 105, 0).cgColor
        ],
        locations: [0, 0.58, 1]
    )
    let secondCount = glowImageCacheEntryCountForTesting()

    #expect(first != nil)
    #expect(second != nil)
    #expect(firstCount == 1)
    #expect(secondCount == firstCount)
}

@MainActor
@Test func fixedGlowImageSpecReusesCachedImageAcrossOpacityChanges() throws {
    resetGlowImageCacheForTesting()
    let spec = try #require(SakuraGlowImageSpec(
        colors: [
            RGBAColor(226, 255, 159, 1).cgColor,
            RGBAColor(122, 214, 112, 0.5).cgColor,
            RGBAColor(122, 214, 112, 0).cgColor
        ],
        locations: [0, 0.45, 1]
    ))

    let first = makeGlowLayerSprite(
        center: .zero,
        radius: 20,
        opacity: 0.18,
        spec: spec
    )
    let firstCount = glowImageCacheEntryCountForTesting()
    let second = makeGlowLayerSprite(
        center: .zero,
        radius: 20,
        opacity: 0.42,
        spec: spec
    )
    let secondCount = glowImageCacheEntryCountForTesting()
    let dynamicEquivalent = makeGlowLayerSprite(
        center: .zero,
        radius: 20,
        colors: [
            RGBAColor(226, 255, 159, 0.42).cgColor,
            RGBAColor(122, 214, 112, 0.21).cgColor,
            RGBAColor(122, 214, 112, 0).cgColor
        ],
        locations: [0, 0.45, 1]
    )
    let dynamicCount = glowImageCacheEntryCountForTesting()

    #expect(first != nil)
    #expect(second != nil)
    #expect(dynamicEquivalent != nil)
    #expect(firstCount == 1)
    #expect(secondCount == firstCount)
    #expect(dynamicCount == firstCount)
    #expect(dynamicEquivalent?.opacity == second?.opacity)
}

@MainActor
@Test func firstSmallSakuraRenderKeepsEnoughParticlesInFrame() {
    let visiblePixels = SakuraScene.withDeterministicRandomSeed(42) {
        SakuraRenderSmoke.nonTransparentPixelCount(
            mode: .sakura,
            intensity: .normal,
            size: CGSize(width: 180, height: 120)
        )
    }

    #expect(visiblePixels > 300)
}

@MainActor
@Test func layerBackedGlowPathIsLimitedToGlowHeavyModes() throws {
    let size = CGSize(width: 180, height: 120)
    let bounds = CGRect(origin: .zero, size: size)
    let context = try #require(makeBitmapContext(size: size))

    let magicResult = SakuraScene.withDeterministicRandomSeed(42) {
        let scene = SakuraScene()
        scene.resize(to: size)
        let sprites = scene.updateAndDrawLayerBacked(
            in: context,
            bounds: bounds,
            time: 1,
            settings: EffectSettings(mode: .magic, intensity: .normal)
        ) ?? []
        return (sprites, scene.diagnostics)
    }
    context.clear(bounds)
    let fireflyResult = SakuraScene.withDeterministicRandomSeed(42) {
        let scene = SakuraScene()
        scene.resize(to: size)
        let sprites = scene.updateAndDrawLayerBacked(
            in: context,
            bounds: bounds,
            time: 1,
            settings: EffectSettings(mode: .firefly, intensity: .normal)
        ) ?? []
        return (sprites, scene.diagnostics)
    }
    context.clear(bounds)
    let sakuraSprites = SakuraScene.withDeterministicRandomSeed(42) {
        let scene = SakuraScene()
        scene.resize(to: size)
        return scene.updateAndDrawLayerBacked(
            in: context,
            bounds: bounds,
            time: 1,
            settings: EffectSettings(mode: .sakura, intensity: .normal)
        )
    }

    let expectedMagicSprites = ParticleBudget.visibleCount(
        baseCount: 180,
        availableCount: magicResult.1.magicLightCount,
        intensity: .normal
    ) * 2
    let expectedFireflySprites = ParticleBudget.visibleCount(
        baseCount: 118,
        availableCount: fireflyResult.1.fireflyCount,
        intensity: .normal
    ) * 2

    #expect(magicResult.0.count == expectedMagicSprites)
    #expect(fireflyResult.0.count == expectedFireflySprites)
    #expect(sakuraSprites == nil)
}

@MainActor
@Test(arguments: [EffectMode.magic, EffectMode.firefly])
func coreGraphicsFallbackKeepsGlowHeavyModesVisible(_ mode: EffectMode) {
    let visiblePixels = SakuraScene.withDeterministicRandomSeed(42) {
        SakuraRenderSmoke.nonTransparentPixelCount(
            mode: mode,
            intensity: .play,
            size: CGSize(width: 180, height: 120),
            time: 1
        )
    }

    #expect(visiblePixels > 120)
}

@MainActor
@Test func sparkRendererReusesRayPathsBetweenFrames() throws {
    resetSparkRayPathCacheForTesting()
    let scene = SakuraScene()
    let size = CGSize(width: 240, height: 160)
    let bounds = CGRect(origin: .zero, size: size)
    let context = try #require(makeBitmapContext(size: size))
    let settings = EffectSettings(mode: .spark, intensity: .play)

    SakuraScene.withDeterministicRandomSeed(42) {
        scene.resize(to: size)
    }

    scene.updateAndDraw(in: context, bounds: bounds, time: 1, settings: settings)
    let firstFrameEntryCount = sparkRayPathCacheEntryCountForTesting()
    context.clear(bounds)
    scene.updateAndDraw(in: context, bounds: bounds, time: 1 + (1 / 30), settings: settings)
    let secondFrameEntryCount = sparkRayPathCacheEntryCountForTesting()

    #expect(firstFrameEntryCount > 0)
    #expect(secondFrameEntryCount == firstFrameEntryCount)
}

@MainActor
@Test func sceneKeepsFixedParticleStorageAcrossLongRenderLoop() throws {
    let scene = SakuraScene()
    let size = CGSize(width: 96, height: 64)
    let bounds = CGRect(origin: .zero, size: size)
    let context = try #require(makeBitmapContext(size: size))

    scene.resize(to: size)
    let diagnosticsAfterResize = scene.diagnostics

    for frame in 0..<360 {
        let mode = EffectMode.allCases[frame % EffectMode.allCases.count]
        let settings = EffectSettings(
            showsNightBackground: frame.isMultiple(of: 2),
            mode: mode,
            intensity: frame.isMultiple(of: 3) ? .play : .normal
        )
        scene.updatePointer(
            CGPoint(
                x: CGFloat(frame % Int(size.width)),
                y: CGFloat((frame * 7) % Int(size.height))
            ),
            isActive: !frame.isMultiple(of: 5),
            bounds: bounds
        )
        context.clear(bounds)
        scene.updateAndDraw(
            in: context,
            bounds: bounds,
            time: TimeInterval(frame) / 30.0,
            settings: settings
        )
    }

    #expect(scene.diagnostics.matchesExpectedParticleStorage)
    #expect(scene.diagnostics == diagnosticsAfterResize)
}

@MainActor
@Test func sceneIgnoresInvalidResizeWithoutResettingParticleStorage() {
    let scene = SakuraScene()
    scene.resize(to: CGSize(width: 120, height: 80))
    let validDiagnostics = scene.diagnostics

    scene.resize(to: .zero)
    scene.resize(to: CGSize(width: -1, height: 80))
    scene.resize(to: CGSize(width: 120, height: -1))

    #expect(scene.diagnostics == validDiagnostics)
    #expect(scene.diagnostics.matchesExpectedParticleStorage)
}

@MainActor
@Test func sceneIgnoresInvalidDrawBoundsWithoutMutatingStorage() throws {
    let scene = SakuraScene()
    let size = CGSize(width: 120, height: 80)
    let context = try #require(makeBitmapContext(size: size))

    scene.resize(to: size)
    let validDiagnostics = scene.diagnostics
    let invalidBounds = [
        CGRect(x: 0, y: 0, width: 0, height: 80),
        CGRect(x: 0, y: 0, width: 120, height: 0),
        CGRect(x: 0, y: 0, width: -1, height: 80),
        CGRect(x: 0, y: 0, width: 120, height: -1),
        CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 80),
        CGRect(x: 0, y: 0, width: 120, height: CGFloat.nan)
    ]

    for bounds in invalidBounds {
        scene.updatePointer(
            CGPoint(x: bounds.midX, y: bounds.midY),
            isActive: true,
            bounds: bounds
        )
        scene.updateAndDraw(
            in: context,
            bounds: bounds,
            time: 1,
            settings: EffectSettings(mode: .hazakura, intensity: .play)
        )
    }

    #expect(scene.diagnostics == validDiagnostics)
    #expect(scene.diagnostics.matchesExpectedParticleStorage)
}

@Test func legacyOrbitPhaseUsesRequestAnimationFrameMilliseconds() {
    let phase = AnimationClock.legacyOrbitPhase(time: 2.5, orbitSpeed: 0.002, phase: 0.4)
    let verticalPhase = AnimationClock.legacyOrbitPhase(
        time: 2.5,
        orbitSpeed: 0.002,
        speedMultiplier: 0.82,
        phase: 0.4
    )

    #expect(abs(phase - 5.4) < 0.000_001)
    #expect(abs(verticalPhase - 4.5) < 0.000_001)
}

private func makeBitmapContext(size: CGSize) -> CGContext? {
    let width = Int(size.width.rounded(.down))
    let height = Int(size.height.rounded(.down))
    guard width > 0, height > 0 else { return nil }

    return CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

@MainActor private func centerPixelForGlow(colors: [CGColor]) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
    let size = CGSize(width: 24, height: 24)
    let width = Int(size.width)
    let height = Int(size.height)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let bytesPerRow = width * 4

    try pixels.withUnsafeMutableBytes { rawBuffer in
        let context = try #require(CGContext(
            data: rawBuffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        context.drawGlow(
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            radius: 10,
            colors: colors,
            locations: [0, 1]
        )
    }

    let centerIndex = ((height / 2) * bytesPerRow) + (width / 2) * 4
    return (
        red: pixels[centerIndex],
        green: pixels[centerIndex + 1],
        blue: pixels[centerIndex + 2],
        alpha: pixels[centerIndex + 3]
    )
}
