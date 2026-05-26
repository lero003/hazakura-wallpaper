import CoreGraphics

let deviceRGB: CGColorSpace = CGColorSpaceCreateDeviceRGB()

private let petalRenderScale: CGFloat = 128
private let glowImageSize: Int = 128

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

private let glowImage: CGImage? = {
    guard let ctx = CGContext(data: nil, width: glowImageSize, height: glowImageSize, bitsPerComponent: 8, bytesPerRow: 0, space: deviceRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let cx = CGFloat(glowImageSize) / 2
    let colors: [CGColor] = [
        RGBAColor(255, 255, 255, 1).cgColor,
        RGBAColor(255, 255, 255, 0).cgColor
    ]
    if let gradient = CGGradient(colorsSpace: deviceRGB, colors: colors as CFArray, locations: [0, 1]) {
        ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: cx, y: cx), startRadius: 0, endCenter: CGPoint(x: cx, y: cx), endRadius: cx, options: [])
    }
    return ctx.makeImage()
}()

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
    func drawGlow(center: CGPoint, radius: CGFloat, colors: [CGColor], locations: [CGFloat]) {
        guard let firstColor = colors.first, let image = glowImage else { return }
        let alpha = firstColor.alpha
        guard alpha > 0.01 else { return }
        saveGState()
        translateBy(x: center.x, y: center.y)
        let s = radius * 2 / CGFloat(glowImageSize)
        scaleBy(x: s, y: s)
        setAlpha(alpha * 0.6)
        let r = CGRect(x: -CGFloat(glowImageSize) / 2, y: -CGFloat(glowImageSize) / 2, width: CGFloat(glowImageSize), height: CGFloat(glowImageSize))
        draw(image, in: r)
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
