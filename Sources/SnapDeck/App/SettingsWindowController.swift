import AppKit
import SnapDeckCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings
    private let permissions: PermissionManager
    private let trackpad: TrackpadGestureController
    private let onRestartMonitoring: () -> Void

    init(
        settings: AppSettings,
        permissions: PermissionManager,
        trackpad: TrackpadGestureController,
        onRestartMonitoring: @escaping () -> Void
    ) {
        self.settings = settings
        self.permissions = permissions
        self.trackpad = trackpad
        self.onRestartMonitoring = onRestartMonitoring

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SnapDeck"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 560)
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.center()

        super.init(window: window)

        let root = SettingsView(
            settings: settings,
            permissions: permissions,
            trackpad: trackpad,
            onRestartMonitoring: onRestartMonitoring,
            initialSection: Self.launchSection()
        )
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.setFrameAutosaveName("SnapDeck.SettingsWindow")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        permissions.refresh()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private static func launchSection() -> SettingsSection {
        for argument in CommandLine.arguments where argument.hasPrefix("--settings-tab=") {
            let value = String(argument.dropFirst("--settings-tab=".count))
            if let section = SettingsSection(rawValue: value) {
                return section
            }
        }
        return .general
    }
}
