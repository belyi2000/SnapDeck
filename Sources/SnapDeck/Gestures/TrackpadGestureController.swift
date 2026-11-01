import AppKit
import Combine
import SnapDeckCore

@MainActor
final class TrackpadGestureController: ObservableObject {
    var onAction: ((TrackpadWindowAction) -> Void)?

    @Published private(set) var isRunning = false
    @Published private(set) var deviceAvailable = MultitouchBridge.isAvailable
    @Published private(set) var suppressionRunning = false
    @Published private(set) var systemGesturesManaged = TrackpadSystemGestureManager.hasBackup
    @Published private(set) var threeFingerDragEnabled = TrackpadSystemGestureManager.isThreeFingerDragEnabled
    @Published private(set) var liveFingerCount = 0
    @Published private(set) var lastAction: TrackpadWindowAction?
    @Published private(set) var lastError: String?

    private let settings: AppSettings
    private let permissions: PermissionManager
    private let bridge = MultitouchBridge()
    private let activity = TouchActivityState()
    private let suppressor: TrackpadEventSuppressor
    private var recognizer = TrackpadSwipeRecognizer()

    init(settings: AppSettings, permissions: PermissionManager) {
        self.settings = settings
        self.permissions = permissions
        self.suppressor = TrackpadEventSuppressor(activity: activity)
        self.recognizer.sensitivity = Float(settings.trackpadGestureSensitivity)
    }

    func startIfEnabled() {
        guard settings.trackpadGesturesEnabled else { return }

        // A previous build may not have known about a newly supported gesture
        // (for example 4-finger horizontal close). Re-apply the setup when a
        // native swipe has reappeared, preserving the original backup.
        if permissions.accessibilityGranted,
           TrackpadSystemGestureManager.hasBackup,
           TrackpadSystemGestureManager.nativeSwipesStillEnabled() {
            _ = TrackpadSystemGestureManager.disableConflicts()
            systemGesturesManaged = true
        }
        start()
    }

    func refreshStatus() {
        deviceAvailable = MultitouchBridge.isAvailable
        systemGesturesManaged = TrackpadSystemGestureManager.hasBackup
        threeFingerDragEnabled = TrackpadSystemGestureManager.isThreeFingerDragEnabled
    }

    @discardableResult
    func start() -> Bool {
        guard settings.trackpadGesturesEnabled else { return false }
        guard permissions.accessibilityGranted else {
            lastError = "Сначала выдайте Accessibility"
            return false
        }
        guard !isRunning else { return true }

        refreshStatus()
        let touchActivity = activity
        let started = bridge.start { [weak self] frame in
            touchActivity.update(count: frame.count)
            DispatchQueue.main.async {
                self?.handle(frame)
            }
        }

        guard started else {
            isRunning = false
            lastError = bridge.lastError ?? "Не удалось запустить MultitouchSupport"
            return false
        }

        suppressionRunning = suppressor.start()
        isRunning = true
        lastError = suppressionRunning ? nil : "Не удалось включить подавление событий трекпада"
        DeckLog.gestures.info("Trackpad gestures started")
        return true
    }

    func stop() {
        bridge.stop()
        suppressor.stop()
        recognizer.reset()
        liveFingerCount = 0
        suppressionRunning = false
        isRunning = false
        DeckLog.gestures.info("Trackpad gestures stopped")
    }

    /// Called from the Trackpad settings when the user explicitly accepts the
    /// system-gesture takeover.
    @discardableResult
    func enableWithSystemSetup() -> Bool {
        guard permissions.accessibilityGranted else {
            lastError = "Сначала выдайте Accessibility"
            return false
        }

        refreshStatus()

        // Start the touch device first. If the hardware or the suppression tap
        // is unavailable, do not disable macOS gestures for a feature that
        // cannot run.
        settings.trackpadGesturesEnabled = true
        guard start(), suppressionRunning else {
            stop()
            settings.trackpadGesturesEnabled = false
            return false
        }

        let configured = TrackpadSystemGestureManager.disableConflicts()
        systemGesturesManaged = configured && TrackpadSystemGestureManager.hasBackup
        if !configured {
            lastError = "Не удалось отключить все конфликтующие системные свайпы"
        }
        return true
    }

    func disableAndRestoreSystemGestures() {
        stop()
        settings.trackpadGesturesEnabled = false
        _ = TrackpadSystemGestureManager.restoreSystemGestures()
        systemGesturesManaged = false
        threeFingerDragEnabled = TrackpadSystemGestureManager.isThreeFingerDragEnabled
    }



    private func handle(_ frame: TrackpadTouchFrame) {
        liveFingerCount = frame.count
        recognizer.sensitivity = Float(settings.trackpadGestureSensitivity)
        guard let action = recognizer.process(frame),
              settings.isEnabled
        else {
            return
        }

        lastAction = action
        let haptic = NSHapticFeedbackManager.defaultPerformer
        haptic.perform(.alignment, performanceTime: .now)
        onAction?(action)
    }
}
