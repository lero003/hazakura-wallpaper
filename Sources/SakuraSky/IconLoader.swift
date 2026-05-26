import AppKit

enum IconLoader {
    static func statusIcon() -> NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "icon", withExtension: "png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/icon.png"),
            URL(fileURLWithPath: CommandLine.arguments.first ?? "")
                .deletingLastPathComponent()
                .appendingPathComponent("../Resources/icon.png")
                .standardizedFileURL
        ].compactMap { $0 }

        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let image = NSImage(contentsOf: url) {
                image.size = NSSize(width: 18, height: 18)
                return image
            }
        }

        return nil
    }
}
