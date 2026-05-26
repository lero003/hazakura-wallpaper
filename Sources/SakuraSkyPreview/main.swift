import CoreGraphics
import CoreText
import Foundation
import ImageIO
import SakuraSkyCore
import SakuraSkyRenderer
import UniformTypeIdentifiers

@main
struct SakuraSkyPreviewTool {
    private static let previewSeed: UInt64 = 0x5A4B_5552_415F_534B

    @MainActor
    static func main() throws {
        try SakuraScene.withDeterministicRandomSeed(previewSeed) {
            let outputDirectory = outputDirectoryURL()
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

            for mode in EffectMode.allCases {
                try renderPreview(
                    mode: mode,
                    showsNightBackground: false,
                    outputURL: outputDirectory.appendingPathComponent("\(mode.rawValue).png")
                )
            }

            try renderPreview(
                mode: .sakura,
                showsNightBackground: true,
                outputURL: outputDirectory.appendingPathComponent("night-sakura.png")
            )

            try renderMatrixPreview(
                showsNightBackground: false,
                outputURL: outputDirectory.appendingPathComponent("qa-matrix-day.png")
            )

            try renderMatrixPreview(
                showsNightBackground: true,
                outputURL: outputDirectory.appendingPathComponent("qa-matrix-night.png")
            )

            print(outputDirectory.path)
        }
    }

    private static func outputDirectoryURL() -> URL {
        if let index = CommandLine.arguments.firstIndex(of: "--output"),
           CommandLine.arguments.indices.contains(index + 1) {
            return URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        }

        return URL(fileURLWithPath: "dist/previews", isDirectory: true)
    }

    @MainActor
    private static func renderPreview(mode: EffectMode, showsNightBackground: Bool, outputURL: URL) throws {
        let width = 960
        let height = 540
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        try pixels.withUnsafeMutableBytes { rawBuffer in
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
                throw PreviewError.contextCreationFailed
            }

            let scene = SakuraScene()
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            let settings = EffectSettings(
                isPaused: false,
                showsNightBackground: showsNightBackground,
                mode: mode,
                intensity: .play
            )

            scene.resize(to: bounds.size)
            scene.updatePointer(CGPoint(x: bounds.midX, y: bounds.midY), isActive: true, bounds: bounds)

            context.clear(bounds)
            scene.updateAndDraw(in: context, bounds: bounds, time: 1.2, settings: settings)

            guard let image = context.makeImage(),
                  let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
            else {
                throw PreviewError.imageCreationFailed
            }

            CGImageDestinationAddImage(destination, image, nil)
            if !CGImageDestinationFinalize(destination) {
                throw PreviewError.writeFailed(outputURL.path)
            }
        }
    }

    @MainActor
    private static func renderMatrixPreview(showsNightBackground: Bool, outputURL: URL) throws {
        let tileWidth: CGFloat = 480
        let tileHeight: CGFloat = 270
        let headerHeight: CGFloat = 34
        let columns = EffectIntensity.allCases.count
        let rows = EffectMode.allCases.count
        let width = Int(tileWidth) * columns
        let height = Int(tileHeight + headerHeight) * rows
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        try pixels.withUnsafeMutableBytes { rawBuffer in
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
                throw PreviewError.contextCreationFailed
            }

            context.setFillColor(CGColor(gray: 0.055, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            for (row, mode) in EffectMode.allCases.enumerated() {
                for (column, intensity) in EffectIntensity.allCases.enumerated() {
                    let visualRow = rows - 1 - row
                    let origin = CGPoint(
                        x: CGFloat(column) * tileWidth,
                        y: CGFloat(visualRow) * (tileHeight + headerHeight)
                    )
                    let header = CGRect(x: origin.x, y: origin.y, width: tileWidth, height: headerHeight)
                    let tile = CGRect(x: origin.x, y: origin.y + headerHeight, width: tileWidth, height: tileHeight)
                    let title = "\(mode.displayName) / \(intensity.rawValue) / \(showsNightBackground ? "night" : "day")"

                    context.setFillColor(CGColor(gray: 0.02, alpha: 1))
                    context.fill(header)
                    drawLabel(title, in: header.insetBy(dx: 12, dy: 8), context: context)
                    renderMatrixTile(
                        mode: mode,
                        intensity: intensity,
                        showsNightBackground: showsNightBackground,
                        tile: tile,
                        context: context
                    )
                }
            }

            guard let image = context.makeImage(),
                  let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)
            else {
                throw PreviewError.imageCreationFailed
            }

            CGImageDestinationAddImage(destination, image, nil)
            if !CGImageDestinationFinalize(destination) {
                throw PreviewError.writeFailed(outputURL.path)
            }
        }
    }

    @MainActor
    private static func renderMatrixTile(
        mode: EffectMode,
        intensity: EffectIntensity,
        showsNightBackground: Bool,
        tile: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.clip(to: tile)
        context.translateBy(x: tile.minX, y: tile.minY)

        let localBounds = CGRect(origin: .zero, size: tile.size)
        if !showsNightBackground {
            context.setFillColor(CGColor(red: 0.075, green: 0.085, blue: 0.1, alpha: 1))
            context.fill(localBounds)
        }

        let scene = SakuraScene()
        let settings = EffectSettings(
            isPaused: false,
            showsNightBackground: showsNightBackground,
            mode: mode,
            intensity: intensity
        )

        scene.resize(to: localBounds.size)
        scene.updatePointer(CGPoint(x: localBounds.midX, y: localBounds.midY), isActive: true, bounds: localBounds)
        scene.updateAndDraw(in: context, bounds: localBounds, time: 1.2, settings: settings)

        context.setStrokeColor(CGColor(gray: 1, alpha: 0.16))
        context.stroke(localBounds.insetBy(dx: 0.5, dy: 0.5), width: 1)
        context.restoreGState()
    }

    private static func drawLabel(_ text: String, in rect: CGRect, context: CGContext) {
        guard let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 14, nil) as CTFont? else { return }
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(gray: 1, alpha: 0.92)
        ]
        guard let attributed = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary),
              let line = CTLineCreateWithAttributedString(attributed) as CTLine?
        else {
            return
        }

        context.saveGState()
        context.textPosition = CGPoint(x: rect.minX, y: rect.minY + 13)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

enum PreviewError: Error, CustomStringConvertible {
    case contextCreationFailed
    case imageCreationFailed
    case writeFailed(String)

    var description: String {
        switch self {
        case .contextCreationFailed:
            "Could not create preview bitmap context."
        case .imageCreationFailed:
            "Could not create preview image."
        case let .writeFailed(path):
            "Could not write preview image: \(path)"
        }
    }
}
