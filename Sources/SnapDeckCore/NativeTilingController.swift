import AppKit
import Foundation

public enum NativeTilingStatus: Equatable, Sendable {
    case disabled
    case enabled
    case unknown

    public var isLikelyActive: Bool {
        self != .disabled
    }
}

/// macOS 15+ has its own drag-to-tile preview. SnapDeck cannot remove that
/// preview with public APIs, but it can turn the system feature off through the
/// same WindowManager preferences that System Settings uses. This is opt-in from
/// the settings window so the app never changes system behavior silently.
public enum NativeTilingController {
    private static let domain = "com.apple.WindowManager" as CFString
    private static let edgeDragKey = "enableTilingByEdgeDrag" as CFString
    private static let topDragKey = "enableTopTilingByEdgeDrag" as CFString

    public static func status() -> NativeTilingStatus {
        let edge = CFPreferencesCopyAppValue(edgeDragKey, domain) as? Bool
        let top = CFPreferencesCopyAppValue(topDragKey, domain) as? Bool

        if edge == false && top == false {
            return .disabled
        }
        if edge == true || top == true {
            return .enabled
        }
        // Both keys are absent on a fresh account. macOS enables drag-to-tile
        // by default, so this is not a reliable "off" signal.
        return .unknown
    }

    @discardableResult
    public static func disableEdgeTiling() -> Bool {
        CFPreferencesSetAppValue(edgeDragKey, kCFBooleanFalse, domain)
        CFPreferencesSetAppValue(topDragKey, kCFBooleanFalse, domain)
        let synchronized = CFPreferencesAppSynchronize(domain)

        // WindowManager may be reading its preferences live; nudge the
        // distributed preferences service and let it decide how to reload.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDistributedCenter(),
            CFNotificationName("com.apple.WindowManager.tilingPreferencesChanged" as CFString),
            nil,
            nil,
            true
        )
        DeckLog.app.info("Native edge tiling disabled: \(synchronized, privacy: .public)")
        return synchronized
    }

    public static func openNativeTilingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
