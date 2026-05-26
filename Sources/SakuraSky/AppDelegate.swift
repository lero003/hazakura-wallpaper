import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var overlayController: OverlayController?
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLoggers.lifecycle.info("Application did finish launching")
        let overlayController = OverlayController(settings: settingsStore.settings)
        let statusController = StatusBarController(
            settings: settingsStore.settings,
            onUpdate: { [weak self] settings in
                self?.settingsStore.settings = settings
                self?.overlayController?.apply(settings: settings)
            },
            onReset: { [weak self] in
                self?.settingsStore.reset()
                guard let settings = self?.settingsStore.settings else { return }
                self?.overlayController?.apply(settings: settings)
            }
        )

        self.overlayController = overlayController
        self.statusController = statusController

        overlayController.start()
        statusController.refresh(settings: settingsStore.settings)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLoggers.lifecycle.info("Application will terminate")
        overlayController?.stop()
        statusController?.stop()
        overlayController = nil
        statusController = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
