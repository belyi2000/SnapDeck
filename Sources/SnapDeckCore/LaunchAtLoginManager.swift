import Foundation

/// Writes a user LaunchAgent instead of relying on SMAppService. This works for
/// a locally built/ad-hoc app outside /Applications and launches the exact app
/// bundle through LaunchServices at login.
public enum LaunchAtLoginManager: Sendable {
    static let label = "com.dmitry.snapdeck.login"

    /// Pure plist body used by the LaunchAgent. Exposed for checks and for
    /// callers that need to show exactly what will be written.
    public static func agentPropertyList(applicationPath: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", applicationPath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua"
        ]
    }

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: false)
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static var applicationBundleURL: URL? {
        let url = Bundle.main.bundleURL
        return url.pathExtension == "app" ? url : nil
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let app = applicationBundleURL else {
                throw LaunchAtLoginError.notAnAppBundle
            }

            let directory = plistURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let plist = agentPropertyList(applicationPath: app.path)
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .xml,
                options: 0
            )
            try data.write(to: plistURL, options: .atomic)
            setFilePermissions()
        } else {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
        }
    }

    private static func setFilePermissions() {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: plistURL.path
        )
    }
}

enum LaunchAtLoginError: LocalizedError {
    case notAnAppBundle

    var errorDescription: String? {
        switch self {
        case .notAnAppBundle:
            return "Автозапуск доступен только для собранного SnapDeck.app, а не для запуска из Xcode/SwiftPM."
        }
    }
}
