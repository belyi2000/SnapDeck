import AppKit
import Combine
import SnapDeckCore

@MainActor
final class SnapSplitterController {
    private let store: SnapGroupStore
    private let windows: AccessibilityWindowService
    private let settings: AppSettings
    private let snapStates: SnapStateStore

    private var panels: [UUID: SplitterPanel] = [:]
    private var timer: Timer?
    private var settingsCancellable: AnyCancellable?
    private var dragState: DragState?

    private struct DragState {
        let groupID: UUID
        let axis: SplitAxis
        let gap: CGFloat
        let startMouse: CGPoint
        let startFirst: CGRect
        let startSecond: CGRect
    }

    init(
        store: SnapGroupStore,
        windows: AccessibilityWindowService,
        settings: AppSettings,
        snapStates: SnapStateStore
    ) {
        self.store = store
        self.windows = windows
        self.settings = settings
        self.snapStates = snapStates

        store.onChange = { [weak self] groups in
            self?.sync(groups)
        }
        settingsCancellable = settings.$linkedResizeEnabled
            .combineLatest(settings.$isEnabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] linkedResize, appEnabled in
                guard let self else { return }
                if linkedResize && appEnabled {
                    self.sync(self.store.groups)
                } else {
                    self.hideAll()
                }
            }

        timer = Timer.scheduledTimer(withTimeInterval: 1.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        store.onChange = nil
        hideAll()
    }

    private func tick() {
        guard settings.linkedResizeEnabled, settings.isEnabled else {
            hideAll()
            return
        }
        guard dragState == nil else { return }
        store.validate()
        sync(store.groups)
    }

    private func sync(_ groups: [SnapGroup]) {
        guard settings.linkedResizeEnabled, settings.isEnabled, dragState == nil else { return }

        let liveIDs = Set(groups.map(\.id))
        for (id, panel) in panels where !liveIDs.contains(id) {
            panel.orderOut(nil)
            panels[id] = nil
        }

        for group in groups {
            guard let frame = splitterFrame(for: group) else {
                panels[group.id]?.orderOut(nil)
                panels[group.id] = nil
                continue
            }

            if let panel = panels[group.id] {
                panel.setFrame(frame, display: true)
            } else {
                let panel = makePanel(for: group)
                panel.setFrame(frame, display: true)
                panel.orderFrontRegardless()
                panels[group.id] = panel
            }
        }
    }

    private func makePanel(for group: SnapGroup) -> SplitterPanel {
        let view = SplitterHandleView(axis: group.axis)
        view.onBegin = { [weak self] in
            self?.beginDrag(groupID: group.id)
        }
        view.onDrag = { [weak self] point in
            self?.drag(to: point)
        }
        view.onEnd = { [weak self] in
            self?.endDrag()
        }

        let panel = SplitterPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.contentView = view
        return panel
    }

    private func splitterFrame(for group: SnapGroup) -> CGRect? {
        let thickness: CGFloat = 20
        switch group.axis {
        case .vertical:
            let centerX = (group.firstFrame.maxX + group.secondFrame.minX) / 2
            let minY = min(group.firstFrame.minY, group.secondFrame.minY)
            let maxY = max(group.firstFrame.maxY, group.secondFrame.maxY)
            guard maxY - minY > 50 else { return nil }
            return CGRect(x: centerX - thickness / 2, y: minY, width: thickness, height: maxY - minY)
        case .horizontal:
            let centerY = (group.firstFrame.minY + group.secondFrame.maxY) / 2
            let minX = min(group.firstFrame.minX, group.secondFrame.minX)
            let maxX = max(group.firstFrame.maxX, group.secondFrame.maxX)
            guard maxX - minX > 50 else { return nil }
            return CGRect(x: minX, y: centerY - thickness / 2, width: maxX - minX, height: thickness)
        }
    }

    private func beginDrag(groupID: UUID) {
        guard settings.linkedResizeEnabled,
              let group = store.groups.first(where: { $0.id == groupID }),
              let first = windows.frame(of: group.firstWindow),
              let second = windows.frame(of: group.secondWindow)
        else {
            return
        }

        dragState = DragState(
            groupID: groupID,
            axis: group.axis,
            gap: group.gap,
            startMouse: NSEvent.mouseLocation,
            startFirst: first,
            startSecond: second
        )
    }

    private func drag(to point: CGPoint) {
        guard let state = dragState,
              let group = store.groups.first(where: { $0.id == state.groupID })
        else {
            endDrag()
            return
        }

        let frames = resizedFrames(for: state, mouse: point)
        windows.setFrame(frames.first, for: group.firstWindow, verify: false)
        windows.setFrame(frames.second, for: group.secondWindow, verify: false)
        snapStates.updateSnappedFrame(windowID: group.firstWindow.id, frame: frames.first)
        snapStates.updateSnappedFrame(windowID: group.secondWindow.id, frame: frames.second)
        store.updateFrames(
            groupID: state.groupID,
            firstFrame: frames.first,
            secondFrame: frames.second
        )

        if let panel = panels[state.groupID],
           let updatedGroup = store.groups.first(where: { $0.id == state.groupID }),
           let frame = splitterFrame(for: updatedGroup) {
            panel.setFrame(frame, display: true)
        }
    }

    private func endDrag() {
        guard dragState != nil else { return }
        dragState = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.store.validate()
            self?.sync(self?.store.groups ?? [])
        }
    }

    private func resizedFrames(for state: DragState, mouse: CGPoint) -> (first: CGRect, second: CGRect) {
        let minWidth: CGFloat = 200
        let minHeight: CGFloat = 140

        switch state.axis {
        case .vertical:
            let startBoundary = (state.startFirst.maxX + state.startSecond.minX) / 2
            let proposed = startBoundary + (mouse.x - state.startMouse.x)
            return SplitGeometry.verticalFrames(
                first: state.startFirst,
                second: state.startSecond,
                gap: state.gap,
                proposedBoundary: proposed,
                minWidth: minWidth
            )
        case .horizontal:
            let startBoundary = (state.startFirst.minY + state.startSecond.maxY) / 2
            let proposed = startBoundary + (mouse.y - state.startMouse.y)
            return SplitGeometry.horizontalFrames(
                first: state.startFirst,
                second: state.startSecond,
                gap: state.gap,
                proposedBoundary: proposed,
                minHeight: minHeight
            )
        }
    }

    private func hideAll() {
        for panel in panels.values {
            panel.orderOut(nil)
        }
        panels.removeAll()
        dragState = nil
    }
}

private final class SplitterPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class SplitterHandleView: NSView {
    let axis: SplitAxis
    var onBegin: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onEnd: (() -> Void)?

    private var hovered = false
    private var trackingAreaReference: NSTrackingArea?

    init(axis: SplitAxis) {
        self.axis = axis
        super.init(frame: .zero)
        toolTip = "Потяните, чтобы изменить размер двух окон"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func resetCursorRects() {
        addCursorRect(
            bounds,
            cursor: axis == .vertical ? .resizeLeftRight : .resizeUpDown
        )
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        onBegin?()
    }

    override func mouseDragged(with event: NSEvent) {
        onDrag?(NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        onEnd?()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Twice the previous length, with a slightly thicker body. The finish
        // is neutral glass rather than the system accent, so it never turns red.
        let length: CGFloat = 112
        let thickness: CGFloat = 7
        let pillRect: CGRect
        switch axis {
        case .vertical:
            pillRect = CGRect(
                x: bounds.midX - thickness / 2,
                y: bounds.midY - length / 2,
                width: thickness,
                height: length
            )
        case .horizontal:
            pillRect = CGRect(
                x: bounds.midX - length / 2,
                y: bounds.midY - thickness / 2,
                width: length,
                height: thickness
            )
        }

        let path = NSBezierPath(
            roundedRect: pillRect,
            xRadius: thickness / 2,
            yRadius: thickness / 2
        )
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        context.saveGState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(isDark ? 0.35 : 0.14)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()

        NSColor.windowBackgroundColor
            .withAlphaComponent(hovered ? 0.94 : 0.72)
            .setFill()
        path.fill()
        context.restoreGState()

        let highlight = NSGradient(colors: [
            NSColor.white.withAlphaComponent(isDark ? 0.30 : 0.55),
            NSColor.white.withAlphaComponent(0.03),
            NSColor.black.withAlphaComponent(isDark ? 0.10 : 0.05)
        ])
        highlight?.draw(in: path, angle: -90)

        NSColor.white
            .withAlphaComponent(hovered ? (isDark ? 0.48 : 0.85) : (isDark ? 0.26 : 0.55))
            .setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}
