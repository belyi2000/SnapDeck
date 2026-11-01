import AppKit
import SnapDeckCore

@MainActor
final class SnapCoordinator {
    var onPermissionRequired: (() -> Void)?

    private let windows: AccessibilityWindowService
    private let settings: AppSettings
    private let permissions: PermissionManager
    private let preview: SnapPreviewController
    private let assist: SnapAssistController
    private let groupStore: SnapGroupStore
    private let snapStates: SnapStateStore
    private let history = WindowFrameHistory.shared
    private var assistGeneration = 0

    init(
        windows: AccessibilityWindowService,
        settings: AppSettings,
        permissions: PermissionManager,
        preview: SnapPreviewController,
        assist: SnapAssistController,
        groupStore: SnapGroupStore,
        snapStates: SnapStateStore
    ) {
        self.windows = windows
        self.settings = settings
        self.permissions = permissions
        self.preview = preview
        self.assist = assist
        self.groupStore = groupStore
        self.snapStates = snapStates
    }

    // MARK: - Commands

    func perform(_ command: WindowCommand) {
        guard settings.isEnabled else { return }
        guard permissions.accessibilityGranted else {
            onPermissionRequired?()
            return
        }

        hideOverlays()

        if let preset = command.tilingPreset {
            tileAll(using: preset)
            return
        }

        if command == .nextDisplay || command == .previousDisplay {
            moveFocusedWindow(toNextDisplay: command == .nextDisplay)
            return
        }

        guard let window = windows.focusedWindow(),
              let screen = windows.screen(for: window.frame)
        else {
            return
        }

        if command == .restore {
            restore(window: window, on: screen)
            return
        }

        guard let zone = command.snapZone else { return }
        snap(window: window, to: zone, on: screen, restoreFrame: nil, showAssist: true)
    }

    /// A state-aware maximize used by the 3-finger-up gesture. A second swipe
    /// restores the previous frame; a native fullscreen window exits fullscreen.
    func toggleMaximizeGesture() {
        guard settings.isEnabled else { return }
        guard permissions.accessibilityGranted else {
            onPermissionRequired?()
            return
        }

        hideOverlays()
        guard let window = windows.focusedWindow(allowFullScreen: true) else {
            return
        }
        let currentFrame = windows.frame(of: window) ?? window.frame

        if window.isFullScreen {
            _ = windows.setFullScreen(false, for: window)
            snapStates.remove(windowID: window.id)
            groupStore.removeGroups(involving: window.id)
            return
        }

        if windows.isWindowMaximized(window) {
            if let state = snapStates.state(for: window, currentFrame: currentFrame),
               state.zone == .maximize {
                _ = windows.setFrame(state.originalFrame, for: window)
                snapStates.remove(windowID: window.id)
                groupStore.removeGroups(involving: window.id)
                return
            }

            if let frame = history.popFrame(for: window.id) {
                _ = windows.setFrame(frame, for: window)
                snapStates.remove(windowID: window.id)
                groupStore.removeGroups(involving: window.id)
            }
            return
        }

        guard let screen = windows.screen(for: currentFrame) else { return }
        snap(
            window: window,
            to: .maximize,
            on: screen,
            restoreFrame: nil,
            showAssist: false
        )
    }

    // MARK: - Dragging

    func showDragPreview(_ target: DragSnapTarget?) {
        guard let target, settings.showTargetPreview else {
            preview.hide()
            return
        }
        preview.show(zone: target.zone, frame: target.previewFrame, on: target.screen)
    }

    func commitDrag(window: WindowInfo, target: DragSnapTarget, originalFrame: CGRect) {
        guard settings.isEnabled, settings.edgeSnapEnabled else { return }
        guard permissions.accessibilityGranted else { return }
        hideOverlays()
        snap(
            window: window,
            to: target.zone,
            on: target.screen,
            restoreFrame: originalFrame,
            showAssist: true
        )
    }

    func handleGlobalMouseDown(_ point: CGPoint) {
        if assist.isVisible {
            assist.dismissIfClickOutside(point)
        } else {
            // Cancel a delayed Snap Assist presentation if the user has
            // already clicked somewhere else.
            assistGeneration += 1
        }
    }

    func hideOverlays() {
        assistGeneration += 1
        preview.hide()
        assist.dismiss()
    }

    // MARK: - Snapping

    private func snap(
        window: WindowInfo,
        to zone: SnapZone,
        on screen: NSScreen,
        restoreFrame: CGRect?,
        showAssist: Bool
    ) {
        let target = zone.rect(in: screen.visibleFrame, gap: settings.gap)
        let current = restoreFrame ?? windows.frame(of: window) ?? window.frame
        if !rectanglesAreClose(current, target) {
            history.record(current, for: window.id)
        }

        let moved = windows.setFrame(target, for: window)
        guard moved else { return }

        snapStates.record(
            window: window,
            before: current,
            after: target,
            zone: zone,
            screen: screen
        )

        let existingGroup = groupStore.recordSnap(
            window: window,
            zone: zone,
            screen: screen,
            gap: settings.gap
        )
        guard existingGroup == nil else {
            // The opposite half already belongs to a known snapped window.
            // The pair is complete, so Snap Assist would be redundant.
            return
        }

        guard showAssist, zone.assistZone != nil else { return }
        if settings.autoFillOtherHalf {
            if !autoFillOtherHalf(source: window, zone: zone, screen: screen) {
                presentSnapAssist(source: window, zone: zone, screen: screen)
            }
        } else if settings.snapAssistEnabled {
            presentSnapAssist(source: window, zone: zone, screen: screen)
        }
    }

    private func presentSnapAssist(source: WindowInfo, zone: SnapZone, screen: NSScreen) {
        guard settings.snapAssistEnabled,
              let freeZone = zone.assistZone
        else {
            return
        }

        assistGeneration += 1
        let generation = assistGeneration
        let freeRect = freeZone.rect(in: screen.visibleFrame, gap: settings.gap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in
            guard let self, self.assistGeneration == generation else { return }
            var candidates = self.windows.visibleWindows(
                excludingIDs: [source.id],
                on: screen
            )
            if candidates.isEmpty {
                // No visible windows to offer. Fall back to minimized windows
                // from all displays; selecting one will unminimize and place it.
                candidates = self.windows.minimizedWindows(
                    excludingIDs: [source.id]
                )
            }
            guard !candidates.isEmpty else { return }

            self.assist.present(
                in: freeRect,
                on: screen,
                candidates: Array(candidates.prefix(6)),
                onSelect: { [weak self] selected in
                    guard let self else { return }
                    let before = self.windows.frame(of: selected) ?? selected.frame
                    self.history.record(before, for: selected.id)

                    if selected.isMinimized {
                        // Give the unminimize animation time to settle; otherwise
                        // the app can restore its old frame after our AX resize.
                        self.windows.activate(selected)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                            guard let self else { return }
                            guard self.windows.setFrame(freeRect, for: selected) else { return }
                            self.recordAssistPlacement(
                                window: selected,
                                before: before,
                                after: freeRect,
                                zone: freeZone,
                                screen: screen
                            )
                        }
                    } else {
                        if self.windows.setFrame(freeRect, for: selected) {
                            self.recordAssistPlacement(
                                window: selected,
                                before: before,
                                after: freeRect,
                                zone: freeZone,
                                screen: screen
                            )
                        }
                        self.windows.activate(selected)
                    }
                }
            )
        }
    }

    private func recordAssistPlacement(
        window: WindowInfo,
        before: CGRect,
        after: CGRect,
        zone: SnapZone,
        screen: NSScreen
    ) {
        snapStates.record(
            window: window,
            before: before,
            after: after,
            zone: zone,
            screen: screen
        )
        groupStore.recordSnap(
            window: window,
            zone: zone,
            screen: screen,
            gap: settings.gap
        )
    }

    @discardableResult
    private func autoFillOtherHalf(source: WindowInfo, zone: SnapZone, screen: NSScreen) -> Bool {
        guard let freeZone = zone.assistZone else { return false }
        let freeRect = freeZone.rect(in: screen.visibleFrame, gap: settings.gap)
        let candidates = windows.visibleWindows(excludingIDs: [source.id], on: screen)
        guard let candidate = candidates.first else { return false }

        let before = windows.frame(of: candidate) ?? candidate.frame
        history.record(before, for: candidate.id)
        let moved = windows.setFrame(freeRect, for: candidate)
        if moved {
            snapStates.record(
                window: candidate,
                before: before,
                after: freeRect,
                zone: freeZone,
                screen: screen
            )
            groupStore.recordSnap(
                window: candidate,
                zone: freeZone,
                screen: screen,
                gap: settings.gap
            )
        }
        return moved
    }

    private func restore(window: WindowInfo, on screen: NSScreen) {
        groupStore.removeGroups(involving: window.id)
        snapStates.remove(windowID: window.id)
        if let frame = history.popFrame(for: window.id) {
            _ = windows.setFrame(frame, for: window)
            return
        }

        let target = SnapZone.center.rect(in: screen.visibleFrame, gap: settings.gap)
        history.record(window.frame, for: window.id)
        _ = windows.setFrame(target, for: window)
    }

    private func moveFocusedWindow(toNextDisplay next: Bool) {
        guard let window = windows.focusedWindow(),
              let currentScreen = windows.screen(for: window.frame)
        else {
            return
        }
        let targetScreen = next
            ? windows.nextScreen(after: currentScreen)
            : windows.previousScreen(before: currentScreen)
        guard let targetScreen else { return }

        let target = ScreenGeometry.mappedRect(
            window.frame,
            from: currentScreen.visibleFrame,
            to: targetScreen.visibleFrame
        )
        groupStore.removeGroups(involving: window.id)
        snapStates.remove(windowID: window.id)
        history.record(window.frame, for: window.id)
        _ = windows.setFrame(target, for: window)
    }

    // MARK: - Multi-window layouts

    private func tileAll(using preset: TilingPreset) {
        let focused = windows.focusedWindow()
        let targetScreen = focused.flatMap { windows.screen(for: $0.frame) }
            ?? windows.screen(containing: NSEvent.mouseLocation)
        guard let screen = targetScreen else { return }

        var candidates = windows.visibleWindows(on: screen)
        let readingOrder: (WindowInfo, WindowInfo) -> Bool = { lhs, rhs in
            if abs(lhs.frame.minX - rhs.frame.minX) > 2 {
                return lhs.frame.minX < rhs.frame.minX
            }
            return lhs.frame.maxY > rhs.frame.maxY
        }

        // The focused window takes the primary slot; the rest follow their
        // current visual order from left to right, top to bottom.
        if let focused, let index = candidates.firstIndex(where: { $0.id == focused.id }) {
            candidates.remove(at: index)
            let rest = candidates.sorted(by: readingOrder)
            candidates = [focused] + rest
        } else {
            candidates.sort(by: readingOrder)
        }

        guard !candidates.isEmpty else { return }
        groupStore.removeAll()
        snapStates.removeAll()
        let frames = preset.frames(
            count: candidates.count,
            in: screen.visibleFrame,
            gap: settings.gap
        )

        for (window, frame) in zip(candidates, frames) {
            history.record(window.frame, for: window.id)
            _ = windows.setFrame(frame, for: window)
        }
    }

    private func rectanglesAreClose(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) <= 1
            && abs(lhs.minY - rhs.minY) <= 1
            && abs(lhs.width - rhs.width) <= 2
            && abs(lhs.height - rhs.height) <= 2
    }
}
