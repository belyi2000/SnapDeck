import AppKit
import SnapDeckCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let permissions: PermissionManager
    private let coordinator: SnapCoordinator
    private let openSettings: () -> Void
    private let checkForUpdates: () -> Void
    private let quit: () -> Void

    private let menu = NSMenu()

    init(
        settings: AppSettings,
        permissions: PermissionManager,
        coordinator: SnapCoordinator,
        openSettings: @escaping () -> Void,
        checkForUpdates: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.settings = settings
        self.permissions = permissions
        self.coordinator = coordinator
        self.openSettings = openSettings
        self.checkForUpdates = checkForUpdates
        self.quit = quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "rectangle.split.2x1",
                accessibilityDescription: "SnapDeck"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "SnapDeck — управление окнами"
        }

        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        permissions.refresh()
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let statusTitle: String
        if !permissions.accessibilityGranted {
            statusTitle = "SnapDeck · нужен Accessibility"
        } else if settings.isEnabled {
            statusTitle = "SnapDeck · активно"
        } else {
            statusTitle = "SnapDeck · пауза"
        }
        let header = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if !permissions.accessibilityGranted {
            let permissionItem = NSMenuItem(
                title: "Разрешить Accessibility…",
                action: #selector(grantAccessibility),
                keyEquivalent: ""
            )
            permissionItem.target = self
            menu.addItem(permissionItem)
            menu.addItem(.separator())
        }

        let enabledItem = NSMenuItem(
            title: "Включить SnapDeck",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let edgeItem = NSMenuItem(
            title: "Прилипание к краям",
            action: #selector(toggleEdgeSnap),
            keyEquivalent: ""
        )
        edgeItem.target = self
        edgeItem.state = settings.edgeSnapEnabled ? .on : .off
        menu.addItem(edgeItem)

        let assistItem = NSMenuItem(
            title: "Snap Assist",
            action: #selector(toggleSnapAssist),
            keyEquivalent: ""
        )
        assistItem.target = self
        assistItem.state = settings.snapAssistEnabled ? .on : .off
        menu.addItem(assistItem)
        menu.addItem(.separator())

        let singleMenu = NSMenu()
        singleMenu.addItem(commandItem(.leftHalf, shortcut: "⌃⌥←", key: leftArrowKey))
        singleMenu.addItem(commandItem(.rightHalf, shortcut: "⌃⌥→", key: rightArrowKey))
        singleMenu.addItem(.separator())
        singleMenu.addItem(commandItem(.maximize, shortcut: "⌃⌥↑", key: upArrowKey))
        singleMenu.addItem(commandItem(.center, shortcut: "⌃⌥C", key: "c", modifiers: [.control, .option]))
        singleMenu.addItem(.separator())
        singleMenu.addItem(commandItem(.topLeft, shortcut: "⌃⌥U", key: "u", modifiers: [.control, .option]))
        singleMenu.addItem(commandItem(.topRight, shortcut: "⌃⌥I", key: "i", modifiers: [.control, .option]))
        singleMenu.addItem(commandItem(.bottomLeft, shortcut: "⌃⌥J", key: "j", modifiers: [.control, .option]))
        singleMenu.addItem(commandItem(.bottomRight, shortcut: "⌃⌥K", key: "k", modifiers: [.control, .option]))
        singleMenu.addItem(.separator())
        singleMenu.addItem(commandItem(.restore, shortcut: "⌃⌥↓", key: downArrowKey))

        let singleItem = NSMenuItem(title: "Прижать окно", action: nil, keyEquivalent: "")
        singleItem.submenu = singleMenu
        menu.addItem(singleItem)

        let layoutMenu = NSMenu()
        for preset in TilingPreset.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(tileWindows(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            layoutMenu.addItem(item)
        }
        let layoutItem = NSMenuItem(title: "Разложить все окна", action: nil, keyEquivalent: "")
        layoutItem.submenu = layoutMenu
        menu.addItem(layoutItem)

        let displayMenu = NSMenu()
        displayMenu.addItem(commandItem(.previousDisplay, shortcut: "⌃⌥⇧←", key: leftArrowKey, modifiers: [.control, .option, .shift]))
        displayMenu.addItem(commandItem(.nextDisplay, shortcut: "⌃⌥⇧→", key: rightArrowKey, modifiers: [.control, .option, .shift]))
        let displayItem = NSMenuItem(title: "Переместить на дисплей", action: nil, keyEquivalent: "")
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Настройки…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        if !permissions.accessibilityGranted {
            let accessItem = NSMenuItem(
                title: "Доступ Accessibility: не выдан",
                action: #selector(grantAccessibility),
                keyEquivalent: ""
            )
            accessItem.target = self
            menu.addItem(accessItem)
        } else {
            let accessItem = NSMenuItem(
                title: "Доступ Accessibility: выдан",
                action: nil,
                keyEquivalent: ""
            )
            accessItem.state = .on
            accessItem.isEnabled = false
            menu.addItem(accessItem)

            if !permissions.eventTapRunning {
                let monitorItem = NSMenuItem(
                    title: "Перетаскивание не отслеживается — открыть доступ",
                    action: #selector(showSettings),
                    keyEquivalent: ""
                )
                monitorItem.target = self
                menu.addItem(monitorItem)
            }
        }

        menu.addItem(.separator())

        let updatesItem = NSMenuItem(
            title: "Проверить обновления…",
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        updatesItem.target = self
        menu.addItem(updatesItem)

        let aboutItem = NSMenuItem(
            title: "О SnapDeck",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Выйти", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)
    }

    private func commandItem(
        _ command: WindowCommand,
        shortcut: String,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.control, .option]
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: command.title,
            action: #selector(performCommand(_:)),
            keyEquivalent: key
        )
        item.target = self
        item.representedObject = command.rawValue
        item.keyEquivalentModifierMask = modifiers
        item.toolTip = shortcut
        return item
    }

    private var leftArrowKey: String { "←" }
    private var rightArrowKey: String { "→" }
    private var upArrowKey: String { "↑" }
    private var downArrowKey: String { "↓" }

    @objc private func performCommand(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let command = WindowCommand(rawValue: rawValue)
        else {
            return
        }
        coordinator.perform(command)
    }

    @objc private func tileWindows(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let preset = TilingPreset(rawValue: rawValue)
        else {
            return
        }
        let command: WindowCommand?
        switch preset {
        case .twoColumns: command = .tileTwoColumns
        case .threeColumns: command = .tileThreeColumns
        case .grid: command = .tileGrid
        case .mainLeftStack: command = .tileMainLeftStack
        case .mainTopRow: command = .tileMainTopRow
        case .cascade: command = .tileCascade
        }
        if let command {
            coordinator.perform(command)
        }
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        if !settings.isEnabled {
            coordinator.hideOverlays()
        }
    }

    @objc private func toggleEdgeSnap() {
        settings.edgeSnapEnabled.toggle()
        if !settings.edgeSnapEnabled {
            coordinator.hideOverlays()
        }
    }

    @objc private func toggleSnapAssist() {
        settings.snapAssistEnabled.toggle()
    }

    @objc private func grantAccessibility() {
        permissions.requestAccessibilityPermission()
        permissions.openAccessibilitySettings()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdatesAction() {
        checkForUpdates()
    }

    @objc private func quitApp() {
        quit()
    }
}
