import CoreGraphics
import Foundation
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif

public enum SakuraRenderSmoke {
    @MainActor
    public static func nonTransparentPixelCount(
        mode: EffectMode,
        intensity: EffectIntensity = .normal,
        showsNightBackground: Bool = false,
        size: CGSize = CGSize(width: 360, height: 240),
        time: TimeInterval = 1.2
    ) -> Int {
        let width = Int(size.width.rounded(.down))
        let height = Int(size.height.rounded(.down))
        guard width > 0, height > 0 else { return 0 }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bytesPerRow = width * 4
        let settings = EffectSettings(
            isPaused: false,
            showsNightBackground: showsNightBackground,
            mode: mode,
            intensity: intensity
        )

        pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else {
                return
            }

            let scene = SakuraScene()
            let bounds = CGRect(origin: .zero, size: size)
            scene.resize(to: size)
            scene.updatePointer(CGPoint(x: size.width * 0.5, y: size.height * 0.5), isActive: true, bounds: bounds)
            scene.updateAndDraw(in: context, bounds: bounds, time: time, settings: settings)
        }

        return stride(from: 3, to: pixels.count, by: 4).reduce(into: 0) { count, alphaIndex in
            if pixels[alphaIndex] > 0 {
                count += 1
            }
        }
    }
}
