import Combine
import Foundation

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published public var edgeSnapEnabled: Bool {
        didSet { defaults.set(edgeSnapEnabled, forKey: Keys.edgeSnapEnabled) }
    }

    @Published public var snapAssistEnabled: Bool {
        didSet { defaults.set(snapAssistEnabled, forKey: Keys.snapAssistEnabled) }
    }

    @Published public var autoFillOtherHalf: Bool {
        didSet { defaults.set(autoFillOtherHalf, forKey: Keys.autoFillOtherHalf) }
    }

    @Published public var showTargetPreview: Bool {
        didSet { defaults.set(showTargetPreview, forKey: Keys.showTargetPreview) }
    }

    @Published public var linkedResizeEnabled: Bool {
        didSet { defaults.set(linkedResizeEnabled, forKey: Keys.linkedResizeEnabled) }
    }

    @Published public var trackpadGesturesEnabled: Bool {
        didSet { defaults.set(trackpadGesturesEnabled, forKey: Keys.trackpadGesturesEnabled) }
    }

    @Published public var trackpadGestureSensitivity: Double {
        didSet { defaults.set(trackpadGestureSensitivity, forKey: Keys.trackpadGestureSensitivity) }
    }

    @Published public var trackpadUpToggleEnabled: Bool {
        didSet { defaults.set(trackpadUpToggleEnabled, forKey: Keys.trackpadUpToggleEnabled) }
    }

    @Published public var closeApplicationGestureEnabled: Bool {
        didSet { defaults.set(closeApplicationGestureEnabled, forKey: Keys.closeApplicationGestureEnabled) }
    }

    @Published public var closeWithTwoFingers: Bool {
        didSet { defaults.set(closeWithTwoFingers, forKey: Keys.closeWithTwoFingers) }
    }

    @Published public var closeSwipeDistance: Double {
        didSet {
            defaults.set(
                min(max(closeSwipeDistance, 0.10), 0.40),
                forKey: Keys.closeSwipeDistance
            )
        }
    }

    @Published public var gap: Double {
        didSet { defaults.set(min(max(gap, 0), 24), forKey: Keys.gap) }
    }

    @Published public private(set) var launchAtLogin: Bool
    @Published public private(set) var launchAtLoginError: String?

    private let defaults: UserDefaults

    private enum Keys {
        static let isEnabled = "snapdeck.isEnabled"
        static let edgeSnapEnabled = "snapdeck.edgeSnapEnabled"
        static let snapAssistEnabled = "snapdeck.snapAssistEnabled"
        static let autoFillOtherHalf = "snapdeck.autoFillOtherHalf"
        static let showTargetPreview = "snapdeck.showTargetPreview"
        static let linkedResizeEnabled = "snapdeck.linkedResizeEnabled"
        static let trackpadGesturesEnabled = "snapdeck.trackpadGesturesEnabled"
        static let trackpadGestureSensitivity = "snapdeck.trackpadGestureSensitivity"
        static let trackpadUpToggleEnabled = "snapdeck.trackpadUpToggleEnabled"
        static let closeApplicationGestureEnabled = "snapdeck.closeApplicationGestureEnabled"
        static let closeWithTwoFingers = "snapdeck.closeWithTwoFingers"
        static let closeSwipeDistance = "snapdeck.closeSwipeDistance"
        static let gap = "snapdeck.gap"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        edgeSnapEnabled = defaults.object(forKey: Keys.edgeSnapEnabled) as? Bool ?? true
        snapAssistEnabled = defaults.object(forKey: Keys.snapAssistEnabled) as? Bool ?? true
        autoFillOtherHalf = defaults.object(forKey: Keys.autoFillOtherHalf) as? Bool ?? false
        showTargetPreview = defaults.object(forKey: Keys.showTargetPreview) as? Bool ?? true
        linkedResizeEnabled = defaults.object(forKey: Keys.linkedResizeEnabled) as? Bool ?? true
        trackpadGesturesEnabled = defaults.object(forKey: Keys.trackpadGesturesEnabled) as? Bool ?? false
        trackpadGestureSensitivity = defaults.object(forKey: Keys.trackpadGestureSensitivity) as? Double ?? 1.0
        trackpadUpToggleEnabled = defaults.object(forKey: Keys.trackpadUpToggleEnabled) as? Bool ?? true
        closeApplicationGestureEnabled = defaults.object(forKey: Keys.closeApplicationGestureEnabled) as? Bool ?? true
        closeWithTwoFingers = defaults.object(forKey: Keys.closeWithTwoFingers) as? Bool ?? false
        closeSwipeDistance = defaults.object(forKey: Keys.closeSwipeDistance) as? Double ?? 0.20
        gap = defaults.object(forKey: Keys.gap) as? Double ?? 6
        launchAtLogin = LaunchAtLoginManager.isEnabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLogin = LaunchAtLoginManager.isEnabled
        } catch {
            launchAtLogin = LaunchAtLoginManager.isEnabled
            launchAtLoginError = error.localizedDescription
            DeckLog.app.error("Unable to update login item: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func refreshLaunchAtLoginStatus() {
        launchAtLogin = LaunchAtLoginManager.isEnabled
    }
}
