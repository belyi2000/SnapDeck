import AppKit
import SnapDeckCore

struct SnappedWindowState {
    let originalFrame: CGRect
    var snappedFrame: CGRect
    let zone: SnapZone
    let screenID: CGDirectDisplayID
}

/// Remembers the size a window had before SnapDeck pinned it to an edge. When
/// the window is dragged away again, EdgeSnapMonitor restores this frame.
@MainActor
final class SnapStateStore {
    private var states: [String: SnappedWindowState] = [:]

    func record(
        window: WindowInfo,
        before: CGRect,
        after: CGRect,
        zone: SnapZone,
        screen: NSScreen
    ) {
        let existing = states[window.id]
        let original: CGRect

        if let existing, framesAreClose(before, existing.snappedFrame, tolerance: 8) {
            original = existing.originalFrame
        } else {
            original = before
        }

        guard original.width > 40, original.height > 40 else { return }
        states[window.id] = SnappedWindowState(
            originalFrame: original,
            snappedFrame: after,
            zone: zone,
            screenID: screen.snapDisplayID
        )
    }

    func state(for window: WindowInfo, currentFrame: CGRect) -> SnappedWindowState? {
        guard let state = states[window.id] else { return nil }
        guard framesAreClose(currentFrame, state.snappedFrame, tolerance: 8) else {
            states[window.id] = nil
            return nil
        }
        return state
    }

    func updateSnappedFrame(windowID: String, frame: CGRect) {
        guard var state = states[windowID] else { return }
        state.snappedFrame = frame
        states[windowID] = state
    }

    func remove(windowID: String) {
        states[windowID] = nil
    }

    func removeAll() {
        states.removeAll()
    }

    private func framesAreClose(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
