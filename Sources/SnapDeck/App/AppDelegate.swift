import AppKit
import SnapDeckCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let permissions = PermissionManager()
    private let windows = AccessibilityWindowService.shared
    private let hotKeys = HotKeyManager()
    private let updates = UpdateController()

    private let preview = SnapPreviewController()
    private let assist = SnapAssistController()
    private let snapStates = SnapStateStore()
    private var groupStore: SnapGroupStore!
    private var splitterController: SnapSplitterController!
    private var coordinator: SnapCoordinator!
    private var edgeMonitor: EdgeSnapMonitor!
    private var statusBar: StatusBarController!
    private var settingsWindow: SettingsWindowController?
    private lazy var trackpad = TrackpadGestureController(
        settings: settings,
        permissions: permissions
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()

        groupStore = SnapGroupStore(windows: windows)
        coordinator = SnapCoordinator(
            windows: windows,
            settings: settings,
            permissions: permissions,
            preview: preview,
            assist: assist,
            groupStore: groupStore,
            snapStates: snapStates
        )
        splitterController = SnapSplitterController(
            store: groupStore,
            windows: windows,
            settings: settings,
            snapStates: snapStates
        )
        coordinator.onPermissionRequired = { [weak self] in
            self?.openPermissionSettings()
        }

        edgeMonitor = EdgeSnapMonitor(
            windows: windows,
            settings: settings,
            snapStates: snapStates
        )
        edgeMonitor.onPreviewChanged = { [weak self] target in
            self?.coordinator.showDragPreview(target)
        }
        edgeMonitor.onCommit = { [weak self] window, target, originalFrame in
            self?.coordinator.commitDrag(
                window: window,
                target: target,
                originalFrame: originalFrame
            )
        }
        edgeMonitor.onMouseDown = { [weak self] point in
            self?.coordinator.handleGlobalMouseDown(point)
        }

        hotKeys.onAction = { [weak self] command in
            self?.coordinator.perform(command)
        }
        hotKeys.registerDefaults()

        trackpad.onAction = { [weak self] action in
            guard let self, self.settings.isEnabled else { return }
            switch action {
            case .snapLeft:
                self.coordinator.perform(.leftHalf)
            case .snapRight:
                self.coordinator.perform(.rightHalf)
            case .maximize:
                if self.settings.trackpadUpToggleEnabled {
                    self.coordinator.toggleMaximizeGesture()
                } else {
                    self.coordinator.perform(.maximize)
                }
            case .minimizeFocused:
                _ = self.windows.minimizeFocusedWindow()
            case .minimizeAll:
                _ = self.windows.minimizeAllWindows()
            case .restoreAll:
                _ = self.windows.restoreAllWindows()
            case .closeApplication:
                _ = self.windows.closeFrontmostApplication()
            }
        }

        statusBar = StatusBarController(
            settings: settings,
            permissions: permissions,
            coordinator: coordinator,
            openSettings: { [weak self] in
                self?.openSettings()
            },
            checkForUpdates: { [weak self] in
                self?.updates.checkForUpdates(nil)
            },
            quit: {
                NSApp.terminate(nil)
            }
        )

        permissions.onAccessibilityChanged = { [weak self] granted in
            guard let self else { return }
            if granted {
                self.startEdgeMonitor()
                self.trackpad.startIfEnabled()
            } else {
                self.stopEdgeMonitor()
                self.coordinator.hideOverlays()
                self.groupStore.removeAll()
                self.snapStates.removeAll()
                self.trackpad.stop()
            }
        }
        permissions.onInputMonitoringChanged = { [weak self] granted in
            guard let self, self.permissions.accessibilityGranted else { return }
            if granted {
                self.startEdgeMonitor()
            } else {
                self.stopEdgeMonitor()
            }
        }
        permissions.startMonitoring()
        permissions.refresh()

        if permissions.accessibilityGranted {
            startEdgeMonitor()
            trackpad.startIfEnabled()
        }

        let hasLaunched = UserDefaults.standard.bool(forKey: "snapdeck.hasLaunched")
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: "snapdeck.hasLaunched")
        }
        if !hasLaunched || CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.openSettings()
            }
        }
        // Used by release tests and automation: launch with --check-for-updates.
        if CommandLine.arguments.contains("--check-for-updates") {
            DispatchQueue.main.async { [weak self] in
                self?.updates.checkForUpdates(nil)
            }
        }
        // Automation hooks for verifying the LaunchAgent without UI clicks.
        if CommandLine.arguments.contains("--enable-autostart") {
            settings.setLaunchAtLogin(true)
        }
        if CommandLine.arguments.contains("--disable-autostart") {
            settings.setLaunchAtLogin(false)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissions.refresh()
        if permissions.accessibilityGranted {
            if edgeMonitor != nil, !edgeMonitor.isRunning {
                startEdgeMonitor()
            }
            trackpad.startIfEnabled()
        }
        trackpad.refreshStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissions.stopMonitoring()
        edgeMonitor?.stop()
        groupStore?.removeAll()
        splitterController?.stop()
        snapStates.removeAll()
        trackpad.stop()
        permissions.setEventTapRunning(false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func startEdgeMonitor() {
        guard permissions.accessibilityGranted else {
            permissions.setEventTapRunning(false)
            return
        }
        let started = edgeMonitor.start()
        permissions.setEventTapRunning(started)
        if !started {
            DeckLog.window.error("Edge monitor is unavailable. Input Monitoring may be missing.")
        }
    }

    private func stopEdgeMonitor() {
        edgeMonitor?.stop()
        permissions.setEventTapRunning(false)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(
                settings: settings,
                permissions: permissions,
                trackpad: trackpad,
                onRestartMonitoring: { [weak self] in
                    guard let self else { return }
                    self.stopEdgeMonitor()
                    self.startEdgeMonitor()
                }
            )
        }
        settingsWindow?.show()
    }

    private func openPermissionSettings() {
        openSettings()
        permissions.requestAccessibilityPermission()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "SnapDeck")

        let aboutItem = NSMenuItem(
            title: "О SnapDeck",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(aboutItem)

        let settingsItem = NSMenuItem(
            title: "Настройки…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(settingsItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Выйти из SnapDeck",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }
}
