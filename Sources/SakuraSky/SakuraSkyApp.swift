import AppKit
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif

@main
@MainActor
final class SakuraSkyApp {
    private static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        scheduleSmokeExitIfNeeded()
        app.run()
    }

    private static func scheduleSmokeExitIfNeeded() {
        guard let configuration = SmokeExitConfiguration() else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.delay) {
            NSApp.terminate(nil)
        }
    }
}
