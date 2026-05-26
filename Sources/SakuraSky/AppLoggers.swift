import Foundation
import OSLog

enum AppLoggers {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.hazakuralab.hazakurawallpaper"

    static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
    static let settings = Logger(subsystem: subsystem, category: "Settings")
    static let overlay = Logger(subsystem: subsystem, category: "Overlay")
    static let menu = Logger(subsystem: subsystem, category: "MenuBar")
}
