import CoreGraphics
import Darwin
import Foundation
import SakuraSkyCore
import SakuraSkyRenderer

@main
enum SakuraSkyMemorySmoke {
    private static let frameCount = positiveIntegerEnvironment(
        "HAZAKURA_WALLPAPER_MEMORY_SMOKE_FRAMES",
        legacyKey: "SAKURA_SKY_MEMORY_SMOKE_FRAMES",
        defaultValue: 300
    )
    private static let width = positiveIntegerEnvironment(
        "HAZAKURA_WALLPAPER_MEMORY_SMOKE_WIDTH",
        legacyKey: "SAKURA_SKY_MEMORY_SMOKE_WIDTH",
        defaultValue: 320
    )
    private static let height = positiveIntegerEnvironment(
        "HAZAKURA_WALLPAPER_MEMORY_SMOKE_HEIGHT",
        legacyKey: "SAKURA_SKY_MEMORY_SMOKE_HEIGHT",
        defaultValue: 180
    )
    private static let maximumResidentBytes = positiveIntegerEnvironment(
        "HAZAKURA_WALLPAPER_MEMORY_SMOKE_MAX_RSS_BYTES",
        legacyKey: "SAKURA_SKY_MEMORY_SMOKE_MAX_RSS_BYTES",
        defaultValue: 256 * 1_024 * 1_024
    )

    @MainActor
    static func main() {
        let result = renderFrames()

        print("Renderer memory smoke passed: yes")
        print("Frames: \(frameCount)")
        print("Canvas: \(width)x\(height)")
        print("Rendered modes: \(EffectMode.allCases.map { $0.rawValue }.joined(separator: ","))")
        print("Visible pixel samples: \(result.visiblePixelSamples)")
        print("Max resident set size bytes: \(result.maxResidentBytes)")
        print("Max resident set size limit bytes: \(maximumResidentBytes)")

        if result.visiblePixelSamples <= 0 {
            FileHandle.standardError.write(Data("Renderer memory smoke produced no visible pixels.\n".utf8))
            exit(1)
        }

        if result.maxResidentBytes > maximumResidentBytes {
            FileHandle.standardError.write(
                Data("Renderer memory smoke exceeded max resident set size limit.\n".utf8)
            )
            exit(1)
        }
    }

    @MainActor
    private static func renderFrames() -> SmokeResult {
        let size = CGSize(width: width, height: height)
        let bounds = CGRect(origin: .zero, size: size)
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var visiblePixelSamples = 0
        let scenes = EffectMode.allCases.map { _ in SakuraScene() }

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

            for scene in scenes {
                scene.resize(to: size)
                scene.updatePointer(
                    CGPoint(x: size.width * 0.5, y: size.height * 0.45),
                    isActive: true,
                    bounds: bounds
                )
            }

            for frame in 0..<frameCount {
                let time = TimeInterval(frame) / 30.0
                for modeIndex in EffectMode.allCases.indices {
                    let mode = EffectMode.allCases[modeIndex]
                    for byteIndex in rawBuffer.indices {
                        rawBuffer[byteIndex] = 0
                    }
                    context.clear(bounds)
                    let settings = EffectSettings(
                        isPaused: false,
                        showsNightBackground: mode == .sakura && frame.isMultiple(of: 2),
                        mode: mode,
                        intensity: frame.isMultiple(of: 3) ? .play : .normal
                    )
                    scenes[modeIndex].updateAndDraw(
                        in: context,
                        bounds: bounds,
                        time: time,
                        settings: settings
                    )
                    visiblePixelSamples += alphaPixelSampleCount(rawBuffer)
                }
            }
        }

        return SmokeResult(
            visiblePixelSamples: visiblePixelSamples,
            maxResidentBytes: maxResidentSetSizeBytes()
        )
    }

    private static func alphaPixelSampleCount(_ pixels: UnsafeMutableRawBufferPointer) -> Int {
        stride(from: 3, to: pixels.count, by: 4).reduce(into: 0) { count, alphaIndex in
            if pixels[alphaIndex] > 0 {
                count += 1
            }
        }
    }

    private static func maxResidentSetSizeBytes() -> Int {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            return 0
        }

        return Int(usage.ru_maxrss)
    }

    private static func positiveIntegerEnvironment(_ key: String, legacyKey: String, defaultValue: Int) -> Int {
        let environment = ProcessInfo.processInfo.environment
        guard let rawValue = environment[key] ?? environment[legacyKey],
              let value = Int(rawValue),
              value > 0
        else {
            return defaultValue
        }
        return value
    }

    private struct SmokeResult {
        let visiblePixelSamples: Int
        let maxResidentBytes: Int
    }
}
