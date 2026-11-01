import AppKit
import ApplicationServices

/// All window manipulation goes through the public Accessibility API.
/// No private window-server calls are used here, which keeps this part of the
/// app predictable across macOS updates.
public final class AccessibilityWindowService {
    public static let shared = AccessibilityWindowService()

    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let fullScreenAttribute = "AXFullScreen"

    public init() {}

    // MARK: - Focused window

    public func focusedWindow() -> WindowInfo? {
        let systemWide = AXUIElementCreateSystemWide()

        if let focusedApp = elementAttribute(systemWide, kAXFocusedApplicationAttribute),
           let window = elementAttribute(focusedApp, kAXFocusedWindowAttribute),
           let info = makeWindowInfo(for: window) {
            return info
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ownPID
        else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = elementAttribute(axApp, kAXFocusedWindowAttribute) else {
            return nil
        }
        return makeWindowInfo(for: window, knownApplication: app)
    }

    // MARK: - Hit testing and dragging

    /// The pointer is in Cocoa coordinates. This returns a standard window only
    /// when the click started in its title bar, so content drags are never
    /// interpreted as window snaps.
    public func windowForDragging(at cocoaPoint: CGPoint) -> WindowInfo? {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
        let axPoint = ScreenGeometry.axPoint(fromCocoa: cocoaPoint, primaryHeight: primaryHeight)
        let systemWide = AXUIElementCreateSystemWide()

        var hitElement: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(axPoint.x),
            Float(axPoint.y),
            &hitElement
        )

        if error == .success, let hitElement {
            var current: AXUIElement? = hitElement
            for _ in 0..<20 {
                guard let element = current else { break }
                if stringAttribute(element, kAXRoleAttribute) == kAXWindowRole,
                   let info = makeWindowInfo(for: element),
                   isPointInTitleBar(cocoaPoint, windowFrame: info.frame) {
                    return info
                }
                current = elementAttribute(element, kAXParentAttribute)
            }
        }

        guard let frontWindow = focusedWindow(),
              ScreenGeometry.contains(frontWindow.frame, point: cocoaPoint),
              isPointInTitleBar(cocoaPoint, windowFrame: frontWindow.frame)
        else {
            return nil
        }
        return frontWindow
    }

    public func isPointInTitleBar(_ point: CGPoint, windowFrame: CGRect) -> Bool {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return false }
        guard point.x >= windowFrame.minX, point.x <= windowFrame.maxX else { return false }
        let titleBarHeight = min(52, max(24, windowFrame.height * 0.35))
        return point.y >= windowFrame.maxY - titleBarHeight && point.y <= windowFrame.maxY + 6
    }

    // MARK: - Window discovery

    public func visibleWindows(
        excludingIDs: Set<String> = [],
        on screen: NSScreen? = nil
    ) -> [WindowInfo] {
        let ownPID = self.ownPID
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        let applications = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular
                    && !$0.isHidden
                    && $0.processIdentifier != ownPID
            }
            .sorted { lhs, rhs in
                if lhs.processIdentifier == frontPID { return true }
                if rhs.processIdentifier == frontPID { return false }
                return (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
            }

        var result: [WindowInfo] = []
        for application in applications {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.25)
            guard let windows = elementArrayAttribute(appElement, kAXWindowsAttribute) else {
                continue
            }

            for window in windows {
                guard let info = makeWindowInfo(for: window, knownApplication: application) else {
                    continue
                }
                if excludingIDs.contains(info.id) { continue }
                if let screen {
                    guard let windowScreen = self.screen(for: info.frame), windowScreen === screen else {
                        continue
                    }
                }
                result.append(info)
            }
        }

        return result
    }

    /// A fallback list for Snap Assist when the free half has no on-screen
    /// candidates. Minimized windows have no usable screen placement, so this
    /// method intentionally searches all displays.
    public func minimizedWindows(excludingIDs: Set<String> = []) -> [WindowInfo] {
        let ownPID = self.ownPID
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        let applications = NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular
                    && $0.processIdentifier != ownPID
            }
            .sorted { lhs, rhs in
                if lhs.processIdentifier == frontPID { return true }
                if rhs.processIdentifier == frontPID { return false }
                return (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
            }

        var result: [WindowInfo] = []
        for application in applications {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.25)
            guard let windows = elementArrayAttribute(appElement, kAXWindowsAttribute) else {
                continue
            }

            for window in windows {
                guard isMinimized(window) else { continue }
                guard let info = makeWindowInfo(
                    for: window,
                    knownApplication: application,
                    allowMinimized: true
                ) else {
                    continue
                }
                if excludingIDs.contains(info.id) { continue }
                result.append(info)
            }
        }
        return result
    }

    // MARK: - Frame access

    public func frame(of window: WindowInfo) -> CGRect? {
        frame(of: window.element)
    }

    public func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = axValueAttribute(element, kAXPositionAttribute),
              let sizeValue = axValueAttribute(element, kAXSizeAttribute),
              let primaryHeight = NSScreen.screens.first?.frame.height
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &size),
              size.width > 1,
              size.height > 1
        else {
            return nil
        }

        return ScreenGeometry.cocoaRect(
            fromAX: CGRect(origin: point, size: size),
            primaryHeight: primaryHeight
        )
    }

    @discardableResult
    public func setFrame(
        _ cocoaRect: CGRect,
        for window: WindowInfo,
        verify: Bool = true
    ) -> Bool {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return false }

        let target = CGRect(
            x: cocoaRect.minX.rounded(),
            y: cocoaRect.minY.rounded(),
            width: max(120, cocoaRect.width.rounded()),
            height: max(80, cocoaRect.height.rounded())
        )
        let axRect = ScreenGeometry.axRect(fromCocoa: target, primaryHeight: primaryHeight)
        var origin = axRect.origin
        var size = axRect.size

        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return false
        }

        // Size first: windows constrained by the current screen edge can move
        // themselves back when resized after positioning. Applying both twice
        // also handles clients that adjust one value as a side effect.
        let sizeResult = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sizeValue)
        let positionResult = AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, positionValue)
        let finalSizeResult = AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sizeValue)

        guard verify else {
            return sizeResult == .success
                || positionResult == .success
                || finalSizeResult == .success
        }

        guard let result = frame(of: window.element) else { return false }
        let isCloseEnough = abs(result.minX - target.minX) <= 2
            && abs(result.minY - target.minY) <= 2
            && abs(result.width - target.width) <= 3
            && abs(result.height - target.height) <= 3
        if !isCloseEnough {
            DeckLog.window.debug(
                "Window \(window.displayTitle, privacy: .public) did not reach requested frame. Requested \(String(describing: target), privacy: .public), got \(String(describing: result), privacy: .public)"
            )
        }
        return isCloseEnough
    }

    @discardableResult
    public func move(window: WindowInfo, to screen: NSScreen) -> Bool {
        guard let currentScreen = self.screen(for: window.frame) else { return false }
        let target = ScreenGeometry.mappedRect(
            window.frame,
            from: currentScreen.visibleFrame,
            to: screen.visibleFrame
        )
        return setFrame(target, for: window)
    }

    // MARK: - Activation

    public func unminimize(_ window: WindowInfo) {
        if isMinimized(window.element) {
            _ = AXUIElementSetAttributeValue(
                window.element,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
        }
        if window.application.isHidden {
            window.application.unhide()
        }
    }

    public func activate(_ window: WindowInfo) {
        unminimize(window)
        window.application.activate(options: [.activateAllWindows])
        _ = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    @discardableResult
    public func minimizeFocusedWindow() -> Bool {
        guard let window = focusedWindow() else { return false }
        return setMinimized(true, element: window.element)
    }

    @discardableResult
    public func minimizeAllWindows() -> Int {
        var minimizedCount = 0
        for window in visibleWindows() {
            if setMinimized(true, element: window.element) {
                minimizedCount += 1
            }
        }
        return minimizedCount
    }

    @discardableResult
    public func restoreAllWindows() -> Int {
        let windows = minimizedWindows()
        var restoredCount = 0
        for window in windows {
            unminimize(window)
            restoredCount += 1
        }
        if let first = windows.first {
            first.application.activate(options: [.activateAllWindows])
        }
        return restoredCount
    }

    @discardableResult
    public func closeFrontmostApplication() -> Bool {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ownPID,
              application.bundleIdentifier != "com.apple.finder",
              application.activationPolicy == .regular
        else {
            return false
        }
        return application.terminate()
    }

    @discardableResult
    private func setMinimized(_ minimized: Bool, element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(
            element,
            kAXMinimizedAttribute as CFString,
            minimized ? kCFBooleanTrue : kCFBooleanFalse
        ) == .success
    }

    // MARK: - Screen helpers

    public func screen(for frame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = ScreenGeometry.screenIndex(
            withLargestIntersection: frame,
            in: screens.map(\.frame)
        ) else {
            return nil
        }
        return screens[index]
    }

    public func screen(containing cocoaPoint: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = ScreenGeometry.screenIndex(
            containing: cocoaPoint,
            in: screens.map(\.frame)
        ) else {
            return nil
        }
        return screens[index]
    }

    public func nextScreen(after screen: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let index = screens.firstIndex(where: { $0 === screen })
        else {
            return nil
        }
        return screens[(index + 1) % screens.count]
    }

    public func previousScreen(before screen: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let index = screens.firstIndex(where: { $0 === screen })
        else {
            return nil
        }
        return screens[(index - 1 + screens.count) % screens.count]
    }

    // MARK: - AX helpers

    public func isMinimized(_ element: AXUIElement) -> Bool {
        boolAttribute(element, kAXMinimizedAttribute) ?? false
    }

    public func isFullScreen(_ element: AXUIElement) -> Bool {
        boolAttribute(element, fullScreenAttribute) ?? false
    }

    private func makeWindowInfo(
        for element: AXUIElement,
        knownApplication: NSRunningApplication? = nil,
        allowMinimized: Bool = false
    ) -> WindowInfo? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid != ownPID else { return nil }

        guard let application = knownApplication ?? NSRunningApplication(processIdentifier: pid) else {
            return nil
        }

        guard stringAttribute(element, kAXRoleAttribute) == kAXWindowRole else {
            return nil
        }
        let subrole = stringAttribute(element, kAXSubroleAttribute)
        guard subrole == kAXStandardWindowSubrole else {
            return nil
        }

        let minimized = isMinimized(element)
        guard allowMinimized || !minimized else { return nil }
        guard !isFullScreen(element) else { return nil }
        guard let frame = frame(of: element) else { return nil }

        let title = stringAttribute(element, kAXTitleAttribute) ?? ""
        return WindowInfo(
            element: element,
            application: application,
            title: title,
            frame: frame,
            isMinimized: minimized
        )
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        copyAttribute(element, attribute) as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        (copyAttribute(element, attribute) as? NSNumber)?.boolValue
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func axValueAttribute(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let value = copyAttribute(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        return unsafeBitCast(value, to: AXValue.self)
    }

    private func elementArrayAttribute(
        _ element: AXUIElement,
        _ attribute: String
    ) -> [AXUIElement]? {
        guard let value = copyAttribute(element, attribute),
              CFGetTypeID(value) == CFArrayGetTypeID()
        else {
            return nil
        }
        let array = unsafeBitCast(value, to: CFArray.self)
        return (0..<CFArrayGetCount(array)).map { index in
            unsafeBitCast(CFArrayGetValueAtIndex(array, index), to: AXUIElement.self)
        }
    }
}
