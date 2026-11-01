import Foundation
import os

public enum DeckLog {
    public static let subsystem = "com.dmitry.snapdeck"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let window = Logger(subsystem: subsystem, category: "window")
    public static let gestures = Logger(subsystem: subsystem, category: "gestures")
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")

    public static func debug(_ message: String, category: Logger = app) {
        category.debug("\(message, privacy: .public)")
    }
}
