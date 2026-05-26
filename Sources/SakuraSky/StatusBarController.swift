import AppKit
#if canImport(SakuraSkyCore)
import SakuraSkyCore
#endif

@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var settings: EffectSettings
    private let onUpdate: (EffectSettings) -> Void
    private let onReset: () -> Void

    private let pauseItem = NSMenuItem()
    private let nightItem = NSMenuItem()
    private var modeItems: [EffectMode: NSMenuItem] = [:]
    private var intensityItems: [EffectIntensity: NSMenuItem] = [:]
    private var isStopped = false

    init(
        settings: EffectSettings,
        onUpdate: @escaping (EffectSettings) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.settings = settings
        self.onUpdate = onUpdate
        self.onReset = onReset
        super.init()
        configureStatusItem()
        configureMenu()
        refresh(settings: settings)
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func refresh(settings: EffectSettings) {
        self.settings = settings
        let menuState = EffectSettingsMenuState(settings: settings)
        pauseItem.title = menuState.pauseTitle
        nightItem.title = menuState.nightBackgroundTitle

        for (mode, item) in modeItems {
            item.state = menuState.isSelected(mode) ? .on : .off
        }

        for (intensity, item) in intensityItems {
            item.state = menuState.isSelected(intensity) ? .on : .off
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.toolTip = "Hazakura Wallpaper by 葉桜ラボ"
        button.setAccessibilityLabel("Hazakura Wallpaper")
        button.setAccessibilityHelp("Open Hazakura Wallpaper controls")

        if let image = IconLoader.statusIcon() {
            image.isTemplate = true
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Hazakura Wallpaper")
        }

        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.autoenablesItems = false
        menu.addItem(disabledItem("葉桜ラボ - とことんAIで遊ぶ研究所"))
        menu.addItem(.separator())
        menu.addItem(disabledItem("操作"))

        pauseItem.target = self
        pauseItem.action = #selector(togglePause)
        menu.addItem(pauseItem)

        nightItem.target = self
        nightItem.action = #selector(toggleNight)
        menu.addItem(nightItem)

        menu.addItem(.separator())
        menu.addItem(disabledItem("モードを選択"))

        for mode in EffectMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            modeItems[mode] = item
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(disabledItem("演出の強さ"))

        for intensity in EffectIntensity.allCases {
            let item = NSMenuItem(title: intensity.displayName, action: #selector(selectIntensity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = intensity.rawValue
            intensityItems[intensity] = item
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "設定を初期化", action: #selector(resetSettings), keyEquivalent: ""))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "葉桜ラボを開く", action: #selector(openLab), keyEquivalent: ""))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "このアプリについて", action: #selector(showAbout), keyEquivalent: ""))
        menu.items.last?.target = self
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func update(_ mutate: (inout EffectSettings) -> Void) {
        mutate(&settings)
        refresh(settings: settings)
        onUpdate(settings)
    }

    @objc private func togglePause() {
        AppLoggers.menu.info("Menu action: toggle pause")
        update { $0.apply(.togglePause) }
    }

    @objc private func toggleNight() {
        AppLoggers.menu.info("Menu action: toggle night background")
        update { $0.apply(.toggleNightBackground) }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = EffectMode(rawValue: rawValue)
        else { return }
        AppLoggers.menu.info("Menu action: select mode \(mode.rawValue, privacy: .public)")
        update { $0.apply(.selectMode(mode)) }
    }

    @objc private func selectIntensity(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let intensity = EffectIntensity(rawValue: rawValue)
        else { return }
        AppLoggers.menu.info("Menu action: select intensity \(intensity.rawValue, privacy: .public)")
        update { $0.apply(.selectIntensity(intensity)) }
    }

    @objc private func resetSettings() {
        AppLoggers.menu.info("Menu action: reset settings")
        onReset()
        refresh(settings: .default)
    }

    @objc private func openLab() {
        guard let url = AppExternalLinks.labSiteURL else { return }
        AppLoggers.menu.info("Menu action: open lab site")
        if !NSWorkspace.shared.open(url) {
            AppLoggers.menu.error("Failed to open lab site")
        }
    }

    @objc private func showAbout() {
        AppLoggers.menu.info("Menu action: show about")
        let aboutInformation = AppAboutInformation()
        let alert = NSAlert()
        alert.messageText = aboutInformation.appName
        alert.informativeText = aboutInformation.informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }

    @objc private func quit() {
        AppLoggers.menu.info("Menu action: quit")
        NSApp.terminate(nil)
    }
}
