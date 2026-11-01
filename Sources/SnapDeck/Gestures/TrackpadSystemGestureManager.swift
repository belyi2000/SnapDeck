import Foundation
import SnapDeckCore

/// Disables the built-in trackpad swipes that collide with SnapDeck's
/// three/four-finger window gestures. Originals are snapshotted so the user can
/// restore the exact previous setup.
enum TrackpadSystemGestureManager {
    private static let trackpadDomains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    ]
    private static let dockDomain = "com.apple.dock"
    private static let backupKey = "snapdeck.nativeTrackpadGestures.backup"
    private static let missing = Int.min

    private static let swipeKeys = [
        "TrackpadThreeFingerVertSwipeGesture",
        "TrackpadFourFingerVertSwipeGesture",
        "TrackpadThreeFingerHorizSwipeGesture",
        "TrackpadFourFingerHorizSwipeGesture"
    ]
    private static let dockKeys = [
        "showMissionControlGestureEnabled",
        "showAppExposeGestureEnabled"
    ]

    static var hasBackup: Bool {
        !(storedBackup().isEmpty)
    }

    static var isThreeFingerDragEnabled: Bool {
        for domain in trackpadDomains {
            if let value = readInt(domain: domain, key: "TrackpadThreeFingerDrag"), value != 0 {
                return true
            }
        }
        return false
    }

    /// True only when a stored system setting is actually enabled. Missing keys
    /// are treated as neutral so a normal launch does not restart the Dock on
    /// every run; the explicit setup pass still writes the full set.
    static func nativeSwipesStillEnabled() -> Bool {
        for domain in trackpadDomains {
            for key in swipeKeys {
                if let value = readInt(domain: domain, key: key), value != 0 {
                    return true
                }
            }
        }
        if readBool(domain: dockDomain, key: "showMissionControlGestureEnabled") == true {
            return true
        }
        if readBool(domain: dockDomain, key: "showAppExposeGestureEnabled") == true {
            return true
        }
        return false
    }

    /// Returns true when at least one native swipe is still enabled (or when
    /// the setting is absent and therefore uses the macOS default).
    static func hasActiveConflicts() -> Bool {
        for domain in trackpadDomains {
            for key in swipeKeys {
                if let value = readInt(domain: domain, key: key) {
                    if value != 0 { return true }
                } else {
                    return true
                }
            }
        }
        if readBool(domain: dockDomain, key: "showMissionControlGestureEnabled") != false {
            return true
        }
        if readBool(domain: dockDomain, key: "showAppExposeGestureEnabled") != false {
            return true
        }
        return false
    }

    @discardableResult
    static func disableConflicts() -> Bool {
        var backup = storedBackup()
        for domain in trackpadDomains {
            for key in swipeKeys where backup[backupKey(domain: domain, key: key)] == nil {
                backup[backupKey(domain: domain, key: key)] =
                    readInt(domain: domain, key: key) ?? missing
            }
        }
        for key in dockKeys where backup[backupKey(domain: dockDomain, key: key)] == nil {
            backup[backupKey(domain: dockDomain, key: key)] =
                (readBool(domain: dockDomain, key: key) ?? true) ? 1 : 0
        }
        UserDefaults.standard.set(backup, forKey: backupKey)

        var success = true
        for domain in trackpadDomains {
            for key in swipeKeys {
                success = writeInt(domain: domain, key: key, value: 0) && success
            }
        }
        for key in dockKeys {
            success = writeBool(domain: dockDomain, key: key, value: false) && success
        }

        // Read back once. CFPreferences can report success while another
        // process still owns a cached value; the UI should not claim the
        // native gestures are off unless the values really are off.
        for domain in trackpadDomains {
            for key in swipeKeys where readInt(domain: domain, key: key) != 0 {
                success = false
            }
        }
        for key in dockKeys where readBool(domain: dockDomain, key: key) != false {
            success = false
        }

        restartDock()
        DeckLog.gestures.info(
            "System trackpad gestures disabled: \(success, privacy: .public)"
        )
        return success
    }

    @discardableResult
    static func restoreSystemGestures() -> Bool {
        let backup = storedBackup()
        guard !backup.isEmpty else { return true }

        for domain in trackpadDomains {
            for key in swipeKeys {
                let value = backup[backupKey(domain: domain, key: key)] ?? missing
                if value == missing {
                    deleteValue(domain: domain, key: key)
                } else {
                    _ = writeInt(domain: domain, key: key, value: value)
                }
            }
        }
        for key in dockKeys {
            let value = backup[backupKey(domain: dockDomain, key: key)]
            if let value {
                _ = writeBool(domain: dockDomain, key: key, value: value != 0)
            } else {
                deleteValue(domain: dockDomain, key: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: backupKey)
        restartDock()
        DeckLog.gestures.info("System trackpad gestures restored")
        return true
    }

    // MARK: - Preferences

    private static func backupKey(domain: String, key: String) -> String {
        "\(domain)|\(key)"
    }

    private static func storedBackup() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: backupKey) as? [String: Int]) ?? [:]
    }

    private static func readInt(domain: String, key: String) -> Int? {
        let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString)
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private static func readBool(domain: String, key: String) -> Bool? {
        readInt(domain: domain, key: key).map { $0 != 0 }
    }

    @discardableResult
    private static func writeInt(domain: String, key: String, value: Int) -> Bool {
        CFPreferencesSetAppValue(
            key as CFString,
            NSNumber(value: value),
            domain as CFString
        )
        return CFPreferencesAppSynchronize(domain as CFString)
    }

    @discardableResult
    private static func writeBool(domain: String, key: String, value: Bool) -> Bool {
        CFPreferencesSetAppValue(
            key as CFString,
            value ? kCFBooleanTrue : kCFBooleanFalse,
            domain as CFString
        )
        return CFPreferencesAppSynchronize(domain as CFString)
    }

    private static func deleteValue(domain: String, key: String) {
        CFPreferencesSetAppValue(key as CFString, nil, domain as CFString)
        _ = CFPreferencesAppSynchronize(domain as CFString)
    }

    private static func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            DeckLog.gestures.error("Could not restart Dock: \(error.localizedDescription, privacy: .public)")
        }
    }
}
