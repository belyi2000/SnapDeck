import AppKit
import ApplicationServices
import Combine

@MainActor
public final class PermissionManager: ObservableObject {
    @Published public private(set) var accessibilityGranted: Bool
    @Published public private(set) var inputMonitoringGranted: Bool
    @Published public private(set) var screenRecordingGranted: Bool
    @Published public private(set) var eventTapRunning = false

    public var onAccessibilityChanged: ((Bool) -> Void)?
    public var onInputMonitoringChanged: ((Bool) -> Void)?
    public var onScreenRecordingChanged: ((Bool) -> Void)?

    private var pollTimer: Timer?
    private var lastAccessibilityValue: Bool
    private var lastInputMonitoringValue: Bool
    private var lastScreenRecordingValue: Bool

    public init() {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted
        lastAccessibilityValue = trusted
        let inputMonitoring = CGPreflightListenEventAccess()
        inputMonitoringGranted = inputMonitoring
        lastInputMonitoringValue = inputMonitoring
        let screenRecording = CGPreflightScreenCaptureAccess()
        screenRecordingGranted = screenRecording
        lastScreenRecordingValue = screenRecording
    }

    deinit {
        pollTimer?.invalidate()
    }

    public func startMonitoring() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    public func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    public func refresh() {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted
        let inputMonitoring = CGPreflightListenEventAccess()
        inputMonitoringGranted = inputMonitoring
        let screenRecording = CGPreflightScreenCaptureAccess()
        screenRecordingGranted = screenRecording

        if trusted != lastAccessibilityValue {
            lastAccessibilityValue = trusted
            DeckLog.permissions.info("Accessibility permission changed: \(trusted, privacy: .public)")
            onAccessibilityChanged?(trusted)
        }
        if inputMonitoring != lastInputMonitoringValue {
            lastInputMonitoringValue = inputMonitoring
            DeckLog.permissions.info("Input Monitoring permission changed: \(inputMonitoring, privacy: .public)")
            onInputMonitoringChanged?(inputMonitoring)
        }
        if screenRecording != lastScreenRecordingValue {
            lastScreenRecordingValue = screenRecording
            DeckLog.permissions.info("Screen Recording permission changed: \(screenRecording, privacy: .public)")
            onScreenRecordingChanged?(screenRecording)
        }
    }

    public func setEventTapRunning(_ running: Bool) {
        guard eventTapRunning != running else { return }
        eventTapRunning = running
    }

    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    public func requestInputMonitoringPermission() {
        _ = CGRequestListenEventAccess()
        refresh()
    }

    public func requestScreenRecordingPermission() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    public func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    public func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
