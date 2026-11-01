import AppKit
import ApplicationServices

public struct WindowInfo {
    public let element: AXUIElement
    public let application: NSRunningApplication
    public let title: String
    public let frame: CGRect
    public let isMinimized: Bool
    public let isFullScreen: Bool

    public var pid: pid_t { application.processIdentifier }
    public var appName: String { application.localizedName ?? "Приложение" }
    public var icon: NSImage? { application.icon }
    public var id: String { "\(pid):\(CFHash(element))" }

    public init(
        element: AXUIElement,
        application: NSRunningApplication,
        title: String,
        frame: CGRect,
        isMinimized: Bool = false,
        isFullScreen: Bool = false
    ) {
        self.element = element
        self.application = application
        self.title = title
        self.frame = frame
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }
}
