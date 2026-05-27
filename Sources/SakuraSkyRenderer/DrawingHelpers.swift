import CoreGraphics

let deviceRGB: CGColorSpace = CGColorSpaceCreateDeviceRGB()

private let petalRenderScale: CGFloat = 128
private let glowRenderScale: CGFloat = 128
private let maximumGlowCacheEntries = 96

@MainActor private let petalPath: CGPath = {
    let w: CGFloat = 0.48
    let h: CGFloat = 0.9
    let path = CGMutablePath()
    path.move(to: CGPoint(x: -w * 0.14, y: -h * 0.52))
    path.addCurve(to: CGPoint(x: -w * 0.78, y: h * 0.24), control1: CGPoint(x: -w * 0.72, y: -h * 0.46), control2: CGPoint(x: -w * 1.02, y: -h * 0.04))
    path.addCurve(to: CGPoint(x: 0, y: h * 0.54), control1: CGPoint(x: -w * 0.5, y: h * 0.58), control2: CGPoint(x: -w * 0.08, y: h * 0.62))
    path.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.24), control1: CGPoint(x: w * 0.08, y: h * 0.62), control2: CGPoint(x: w * 0.5, y: h * 0.58))
    path.addCurve(to: CGPoint(x: w * 0.14, y: -h * 0.52), control1: CGPoint(x: w * 1.02, y: -h * 0.04), control2: CGPoint(x: w * 0.72, y: -h * 0.46))
    path.addQuadCurve(to: CGPoint(x: -w * 0.14, y: -h * 0.52), control: CGPoint(x: 0, y: -h * 0.36))
    path.closeSubpath()
    return path.copy() ?? path
}()

@MainActor private var petalImageCache: [String: CGImage] = [:]
@MainActor private var petalGradientCache: [String: CGGradient] = [:]
@MainActor private var glowImageCache: [GlowImageCacheKey: CGImage] = [:]
@MainActor private var glowImageCacheOrder: [GlowImageCacheKey] = []

@MainActor func resetGlowImageCacheForTesting() {
    glowImageCache.removeAll(keepingCapacity: true)
    glowImageCacheOrder.removeAll(keepingCapacity: true)
}

@MainActor func glowImageCacheEntryCountForTesting() -> Int {
    glowImageCache.count
}

public struct SakuraGlowLayerSprite {
    public let image: CGImage
    public let opacity: CGFloat
    public let frame: CGRect
}

@MainActor private func cachedPetalGradient(color: RGBAColor) -> CGGradient? {
    let key = "\(color.red):\(color.green):\(color.blue)"
    if let cached = petalGradientCache[key] { return cached }
    let dark = color.darkened(red: 38, green: 56, blue: 42).withAlpha(0.7).cgColor
    let fillColors: [CGColor] = [
        RGBAColor(255, 255, 255, 0.96).cgColor,
        color.withAlpha(0.9).cgColor,
        dark
    ]
    guard let gradient = CGGradient(colorsSpace: deviceRGB, colors: fillColors as CFArray, locations: [0, 0.34, 1]) else { return nil }
    petalGradientCache[key] = gradient
    return gradient
}

@MainActor private func makePetalImage(color: RGBAColor) -> CGImage? {
    guard let ctx = CGContext(data: nil, width: Int(petalRenderScale), height: Int(petalRenderScale), bitsPerComponent: 8, bytesPerRow: 0, space: deviceRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.translateBy(x: petalRenderScale / 2, y: petalRenderScale / 2)
    ctx.scaleBy(x: petalRenderScale, y: petalRenderScale)
    ctx.addPath(petalPath)
    ctx.clip()
    if let gradient = cachedPetalGradient(color: color) {
        ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 0, y: 0.18), startRadius: 0, endCenter: .zero, endRadius: 0.72, options: [])
    }
    ctx.resetClip()
    ctx.setStrokeColor(RGBAColor(255, 255, 255, 0.42).cgColor)
    ctx.setLineWidth(petalRenderScale * 0.025)
    ctx.move(to: CGPoint(x: 0, y: 0.414))
    ctx.addQuadCurve(to: CGPoint(x: -0.0192, y: -0.252), control: CGPoint(x: -0.048, y: 0))
    ctx.strokePath()
    return ctx.makeImage()
}

@MainActor func petalImage(for color: RGBAColor) -> CGImage? {
    let key = "\(color.red):\(color.green):\(color.blue)"
    if let cached = petalImageCache[key] { return cached }
    if let image = makePetalImage(color: color) {
        petalImageCache[key] = image
        return image
    }
    return nil
}

struct RGBAColor {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red / 255
        self.green = green / 255
        self.blue = blue / 255
        self.alpha = alpha
    }

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    func withAlpha(_ alpha: CGFloat) -> RGBAColor {
        RGBAColor(red * 255, green * 255, blue * 255, alpha)
    }

    func darkened(red deltaRed: CGFloat, green deltaGreen: CGFloat, blue deltaBlue: CGFloat) -> RGBAColor {
        RGBAColor(max(0, red * 255 - deltaRed), max(0, green * 255 - deltaGreen), max(0, blue * 255 - deltaBlue), alpha)
    }
}

enum SakuraPalette {
    static let petals = [
        RGBAColor(255, 246, 248),
        RGBAColor(255, 230, 238),
        RGBAColor(255, 211, 226),
        RGBAColor(255, 190, 213),
        RGBAColor(248, 158, 190),
        RGBAColor(237, 128, 173)
    ]
    static let hazakura = [
        RGBAColor(232, 88, 122),
        RGBAColor(247, 135, 154),
        RGBAColor(255, 224, 230),
        RGBAColor(90, 158, 95),
        RGBAColor(61, 122, 65),
        RGBAColor(144, 198, 149)
    ]
    static let breeze = [
        RGBAColor(246, 252, 255),
        RGBAColor(218, 241, 255),
        RGBAColor(185, 224, 248),
        RGBAColor(255, 236, 242),
        RGBAColor(226, 236, 210)
    ]
}

extension CGContext {
    @MainActor func drawGlow(center: CGPoint, radius: CGFloat, colors: [CGColor], locations: [CGFloat]) {
        guard let sprite = makeGlowLayerSprite(
            center: center,
            radius: radius,
            colors: colors,
            locations: locations
        )
        else { return }

        saveGState()
        translateBy(x: sprite.frame.midX, y: sprite.frame.midY)
        let drawScale = sprite.frame.width / glowRenderScale
        scaleBy(x: drawScale, y: drawScale)
        setAlpha(sprite.opacity)
        let rect = CGRect(
            x: -glowRenderScale / 2,
            y: -glowRenderScale / 2,
            width: glowRenderScale,
            height: glowRenderScale
        )
        draw(sprite.image, in: rect)
        restoreGState()
    }

    @MainActor func drawPetal(center: CGPoint, size: CGFloat, rotation: CGFloat, alpha: CGFloat, color: RGBAColor, flip: CGFloat) {
        guard let image = petalImage(for: color) else { return }
        saveGState()
        translateBy(x: center.x, y: center.y)
        rotate(by: rotation)
        let drawScale = size / petalRenderScale
        scaleBy(x: drawScale * flip, y: drawScale)
        setAlpha(alpha)
        let r = CGRect(x: -petalRenderScale / 2, y: -petalRenderScale / 2, width: petalRenderScale, height: petalRenderScale)
        draw(image, in: r)
        restoreGState()
    }
}

@MainActor public func makeGlowLayerSprite(
    center: CGPoint,
    radius: CGFloat,
    colors: [CGColor],
    locations: [CGFloat]
) -> SakuraGlowLayerSprite? {
    let opacity = glowOpacity(for: colors)
    guard radius > 0,
          opacity > 0.01,
          !colors.isEmpty,
          colors.count == locations.count,
          let colorStops = normalizedGlowColorStops(colors: colors, opacity: opacity, locations: locations),
          let image = cachedGlowImage(colors: colorStops.colors, locations: locations, cacheKey: colorStops.cacheKey)
    else { return nil }

    let diameter = radius * 2
    return SakuraGlowLayerSprite(
        image: image,
        opacity: opacity,
        frame: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: diameter,
            height: diameter
        )
    )
}

@MainActor private func cachedGlowImage(colors: [CGColor], locations: [CGFloat], cacheKey: GlowImageCacheKey) -> CGImage? {
    if let cached = glowImageCache[cacheKey] {
        return cached
    }

    guard let image = makeGlowImage(colors: colors, locations: locations) else {
        return nil
    }

    glowImageCache[cacheKey] = image
    glowImageCacheOrder.append(cacheKey)
    while glowImageCacheOrder.count > maximumGlowCacheEntries {
        let removedKey = glowImageCacheOrder.removeFirst()
        glowImageCache.removeValue(forKey: removedKey)
    }
    return image
}

private func makeGlowImage(colors: [CGColor], locations: [CGFloat]) -> CGImage? {
    let size = Int(glowRenderScale)
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: deviceRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ),
          let gradient = CGGradient(
            colorsSpace: deviceRGB,
            colors: colors as CFArray,
            locations: locations
          )
    else { return nil }

    let center = CGPoint(x: glowRenderScale / 2, y: glowRenderScale / 2)
    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: glowRenderScale / 2,
        options: []
    )
    return context.makeImage()
}

private struct GlowImageCacheKey: Hashable {
    var stops: [GlowImageColorStop]
}

private struct GlowImageColorStop: Hashable {
    var location: Int
    var red: Int
    var green: Int
    var blue: Int
    var alpha: Int
}

private func normalizedGlowColorStops(
    colors: [CGColor],
    opacity: CGFloat,
    locations: [CGFloat]
) -> (colors: [CGColor], cacheKey: GlowImageCacheKey)? {
    guard opacity > 0, colors.count == locations.count else { return nil }

    var normalizedColors: [CGColor] = []
    normalizedColors.reserveCapacity(colors.count)
    var stops: [GlowImageColorStop] = []
    stops.reserveCapacity(colors.count)

    for (color, location) in zip(colors, locations) {
        let rgba = normalizedRGBAComponents(for: color, opacity: opacity)
        normalizedColors.append(CGColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha))
        stops.append(GlowImageColorStop(
            location: Int((location * 1_000).rounded()),
            red: quantizedColorComponent(rgba.red),
            green: quantizedColorComponent(rgba.green),
            blue: quantizedColorComponent(rgba.blue),
            alpha: quantizedColorComponent(rgba.alpha)
        ))
    }

    return (normalizedColors, GlowImageCacheKey(stops: stops))
}

private func normalizedRGBAComponents(for color: CGColor, opacity: CGFloat) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
    let converted = color.converted(to: deviceRGB, intent: .defaultIntent, options: nil) ?? color
    let components = converted.components ?? []
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    if components.count >= 3 {
        red = components[0]
        green = components[1]
        blue = components[2]
    } else {
        let gray = components.first ?? 0
        red = gray
        green = gray
        blue = gray
    }

    return (
        red: min(1, max(0, red)),
        green: min(1, max(0, green)),
        blue: min(1, max(0, blue)),
        alpha: min(1, max(0, color.alpha / opacity))
    )
}

private func quantizedColorComponent(_ value: CGFloat) -> Int {
    let clamped = min(1, max(0, value))
    return Int((clamped * 255 / 8).rounded()) * 8
}

private func glowOpacity(for colors: [CGColor]) -> CGFloat {
    colors.reduce(CGFloat.zero) { opacity, color in
        max(opacity, color.alpha)
    }
}

func cgColor(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> CGColor {
    let h = hue - floor(hue)
    let sector = h * 6
    let index = floor(sector)
    let fraction = sector - index
    let p = brightness * (1 - saturation)
    let q = brightness * (1 - saturation * fraction)
    let t = brightness * (1 - saturation * (1 - fraction))
    let components: (CGFloat, CGFloat, CGFloat) = switch Int(index) % 6 {
    case 0: (brightness, t, p)
    case 1: (q, brightness, p)
    case 2: (p, brightness, t)
    case 3: (p, q, brightness)
    case 4: (t, p, brightness)
    default: (brightness, p, q)
    }
    return CGColor(red: components.0, green: components.1, blue: components.2, alpha: alpha)
}
