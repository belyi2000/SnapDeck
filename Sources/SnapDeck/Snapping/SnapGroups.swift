import AppKit
import SnapDeckCore

enum SplitAxis {
    case vertical
    case horizontal
}

struct SnapGroup: Identifiable {
    let id: UUID
    let axis: SplitAxis
    let gap: CGFloat
    let firstWindow: WindowInfo
    let secondWindow: WindowInfo
    let firstZone: SnapZone
    let secondZone: SnapZone
    var firstFrame: CGRect
    var secondFrame: CGRect

    var windowIDs: Set<String> {
        [firstWindow.id, secondWindow.id]
    }
}

extension NSScreen {
    var snapDisplayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

/// Tracks windows that were snapped to complementary halves. The group is
/// deliberately conservative: it is created only when SnapDeck itself snapped
/// both windows and their visible frames are truly adjacent.
@MainActor
final class SnapGroupStore {
    private struct KnownSnap {
        let window: WindowInfo
        let zone: SnapZone
        let screenID: CGDirectDisplayID
        let timestamp: Date
    }

    private let windows: AccessibilityWindowService
    private var knownSnaps: [String: KnownSnap] = [:]
    private(set) var groups: [SnapGroup] = []

    var onChange: (([SnapGroup]) -> Void)?

    init(windows: AccessibilityWindowService) {
        self.windows = windows
    }

    @discardableResult
    func recordSnap(
        window: WindowInfo,
        zone: SnapZone,
        screen: NSScreen,
        gap: CGFloat
    ) -> SnapGroup? {
        removeGroups(involving: window.id, notify: false)

        guard let frame = windows.frame(of: window),
              !windows.isMinimized(window.element)
        else {
            notifyIfNeeded()
            return nil
        }

        guard zone.complementaryHalf != nil else {
            knownSnaps[window.id] = KnownSnap(
                window: window,
                zone: zone,
                screenID: screen.snapDisplayID,
                timestamp: Date()
            )
            notifyIfNeeded()
            return nil
        }

        knownSnaps[window.id] = KnownSnap(
            window: window,
            zone: zone,
            screenID: screen.snapDisplayID,
            timestamp: Date()
        )

        let candidates = knownSnaps.values
            .filter {
                $0.window.id != window.id
                    && $0.screenID == screen.snapDisplayID
                    && $0.zone == zone.complementaryHalf
            }
            .sorted { $0.timestamp > $1.timestamp }

        for candidate in candidates {
            guard let otherFrame = windows.frame(of: candidate.window),
                  !windows.isMinimized(candidate.window.element),
                  SplitGeometry.areAdjacentHalves(
                    frame,
                    otherFrame,
                    firstZone: zone,
                    secondZone: candidate.zone,
                    gap: gap
                  )
            else {
                continue
            }

            let group = makeGroup(
                firstWindow: window,
                firstZone: zone,
                firstFrame: frame,
                secondWindow: candidate.window,
                secondZone: candidate.zone,
                secondFrame: otherFrame,
                gap: gap
            )
            groups.append(group)
            notifyIfNeeded()
            return group
        }

        notifyIfNeeded()
        return nil
    }

    func updateFrames(
        groupID: UUID,
        firstFrame: CGRect,
        secondFrame: CGRect,
        notify: Bool = false
    ) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }
        groups[index].firstFrame = firstFrame
        groups[index].secondFrame = secondFrame
        if notify {
            notifyIfNeeded()
        }
    }

    func validate() {
        var changed = false
        groups.removeAll { group in
            guard let first = windows.frame(of: group.firstWindow),
                  let second = windows.frame(of: group.secondWindow),
                  !windows.isMinimized(group.firstWindow.element),
                  !windows.isMinimized(group.secondWindow.element)
            else {
                changed = true
                return true
            }

            let framesStillMatch = Self.framesAreClose(first, group.firstFrame)
                && Self.framesAreClose(second, group.secondFrame)
            if !framesStillMatch {
                changed = true
            }
            return !framesStillMatch
        }

        if changed {
            notifyIfNeeded()
        }
    }

    func removeGroups(involving windowID: String) {
        removeGroups(involving: windowID, notify: true)
    }

    func removeAll() {
        knownSnaps.removeAll()
        guard !groups.isEmpty else { return }
        groups.removeAll()
        onChange?([])
    }

    private func removeGroups(involving windowID: String, notify: Bool) {
        let before = groups.count
        groups.removeAll { $0.windowIDs.contains(windowID) }
        knownSnaps[windowID] = nil
        if notify && groups.count != before {
            onChange?(groups)
        }
    }

    private func makeGroup(
        firstWindow: WindowInfo,
        firstZone: SnapZone,
        firstFrame: CGRect,
        secondWindow: WindowInfo,
        secondZone: SnapZone,
        secondFrame: CGRect,
        gap: CGFloat
    ) -> SnapGroup {
        let axis: SplitAxis
        if firstZone == .leftHalf || firstZone == .rightHalf {
            axis = .vertical
        } else {
            axis = .horizontal
        }

        // Normalize visual order: left-to-right or top-to-bottom.
        let firstIsFirst: Bool
        switch axis {
        case .vertical:
            firstIsFirst = firstFrame.minX <= secondFrame.minX
        case .horizontal:
            firstIsFirst = firstFrame.maxY >= secondFrame.maxY
        }

        return SnapGroup(
            id: UUID(),
            axis: axis,
            gap: gap,
            firstWindow: firstIsFirst ? firstWindow : secondWindow,
            secondWindow: firstIsFirst ? secondWindow : firstWindow,
            firstZone: firstIsFirst ? firstZone : secondZone,
            secondZone: firstIsFirst ? secondZone : firstZone,
            firstFrame: firstIsFirst ? firstFrame : secondFrame,
            secondFrame: firstIsFirst ? secondFrame : firstFrame
        )
    }

    private static func framesAreClose(_ first: CGRect, _ second: CGRect) -> Bool {
        abs(first.minX - second.minX) <= 2
            && abs(first.minY - second.minY) <= 2
            && abs(first.width - second.width) <= 3
            && abs(first.height - second.height) <= 3
    }

    private func notifyIfNeeded() {
        onChange?(groups)
    }
}
