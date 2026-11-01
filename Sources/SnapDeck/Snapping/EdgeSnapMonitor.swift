import AppKit
import ApplicationServices
import SnapDeckCore

struct DragSnapTarget {
    let zone: SnapZone
    let screen: NSScreen
    let previewFrame: CGRect
}

/// Observes the global mouse stream while a title bar is being dragged.
/// It is a listen-only event tap: the app never consumes or rewrites events.
@MainActor
final class EdgeSnapMonitor {
    var onPreviewChanged: ((DragSnapTarget?) -> Void)?
    var onCommit: ((WindowInfo, DragSnapTarget, CGRect) -> Void)?
    var onMouseDown: ((CGPoint) -> Void)?

    private let windows: AccessibilityWindowService
    private let settings: AppSettings
    private let snapStates: SnapStateStore
    private let detector = EdgeDetector(
        threshold: 11,
        cornerThreshold: 58,
        topThreshold: 28
    )

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var session: DragSession?

    var isRunning: Bool { eventTap != nil }

    private struct DragSession {
        let window: WindowInfo
        var startFrame: CGRect
        let startPoint: CGPoint
        var hasMoved: Bool
        var target: DragSnapTarget?
        var restoreState: SnappedWindowState?
        var didRestore: Bool
        var previousZone: SnapZone?
        var hasLeftPreviousZone: Bool
    }

    init(
        windows: AccessibilityWindowService,
        settings: AppSettings,
        snapStates: SnapStateStore
    ) {
        self.windows = windows
        self.settings = settings
        self.snapStates = snapStates
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: edgeSnapEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DeckLog.window.error("Could not create mouse event tap")
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        DeckLog.window.info("Edge snap monitor started")
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        session = nil
        onPreviewChanged?(nil)
        DeckLog.window.info("Edge snap monitor stopped")
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            DeckLog.window.error("Mouse event tap was disabled by the system and has been re-enabled")
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged:
            handleMouseDragged(event)
        case .leftMouseUp:
            handleMouseUp()
        default:
            break
        }
    }

    private func handleMouseDown(_ event: CGEvent) {
        let point = cocoaPoint(for: event)
        onMouseDown?(point)
        session = nil
        onPreviewChanged?(nil)

        guard settings.isEnabled, settings.edgeSnapEnabled else { return }
        guard let window = windows.windowForDragging(at: point) else { return }
        guard let frame = windows.frame(of: window) else { return }

        let restoreState = snapStates.state(for: window, currentFrame: frame)
        session = DragSession(
            window: window,
            startFrame: frame,
            startPoint: point,
            hasMoved: false,
            target: nil,
            restoreState: restoreState,
            didRestore: false,
            previousZone: restoreState?.zone,
            hasLeftPreviousZone: restoreState == nil
        )
    }

    private func handleMouseDragged(_ event: CGEvent) {
        guard settings.isEnabled, settings.edgeSnapEnabled, var session else {
            return
        }

        let point = cocoaPoint(for: event)
        if !session.hasMoved {
            let dx = point.x - session.startPoint.x
            let dy = point.y - session.startPoint.y
            guard dx * dx + dy * dy >= 100 else { return }
            session.hasMoved = true
        }

        // A window that SnapDeck had pinned to an edge returns to its previous
        // size as soon as the drag really starts — the same feel as Windows.
        if let state = session.restoreState, !session.didRestore {
            let restored = restoredFrame(for: session, state: state, at: point)
            if windows.setFrame(restored, for: session.window) {
                snapStates.remove(windowID: session.window.id)
                session.startFrame = restored
                session.restoreState = nil
                session.didRestore = true
                session.hasLeftPreviousZone = false
            }
        }

        guard let screen = windows.screen(containing: point)
                ?? windows.screen(for: session.startFrame)
        else {
            session.target = nil
            self.session = session
            onPreviewChanged?(nil)
            return
        }

        // The visible top edge is below the menu bar. Treat the whole menu bar
        // and a small band below it as the top snap edge, while still using
        // the physical screen edges for the left/right/bottom sides.
        let topEdge = screen.visibleFrame.maxY
        let detectionFrame = ScreenGeometry.edgeDetectionFrame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        )
        let detectionPoint = CGPoint(x: point.x, y: min(point.y, topEdge))
        var zone = detector.zone(for: detectionPoint, in: detectionFrame)

        // Do not instantly re-snap to the edge the window just came from. The
        // user has to leave that edge (or move to a different zone) first.
        if let previousZone = session.previousZone, !session.hasLeftPreviousZone {
            if zone == nil || zone != previousZone {
                session.hasLeftPreviousZone = true
            } else {
                zone = nil
            }
        }

        guard let zone else {
            if session.target != nil {
                session.target = nil
                self.session = session
                onPreviewChanged?(nil)
            } else {
                self.session = session
            }
            return
        }

        let previewFrame = zone.rect(in: screen.visibleFrame, gap: settings.gap)
        let target = DragSnapTarget(zone: zone, screen: screen, previewFrame: previewFrame)
        let changed = session.target?.zone != zone || session.target?.screen !== screen
        session.target = target
        self.session = session

        if changed, settings.showTargetPreview {
            onPreviewChanged?(target)
        }
    }

    private func restoredFrame(
        for session: DragSession,
        state: SnappedWindowState,
        at point: CGPoint
    ) -> CGRect {
        let screen = windows.screen(containing: point)
            ?? windows.screen(for: state.originalFrame)
        return UnsnapGeometry.restoredFrame(
            snappedFrame: state.snappedFrame,
            originalFrame: state.originalFrame,
            dragStart: session.startPoint,
            currentPoint: point,
            visibleFrame: screen?.visibleFrame
        )
    }

    private func handleMouseUp() {
        guard let session else { return }
        self.session = nil
        onPreviewChanged?(nil)

        var startFrame = session.startFrame

        // Fallback for clients that ignored the frame change during the drag:
        // make sure a detached window is still returned to its old size.
        if session.target == nil,
           session.hasMoved,
           let state = session.restoreState,
           !session.didRestore {
            let restored = restoredFrame(
                for: session,
                state: state,
                at: NSEvent.mouseLocation
            )
            if windows.setFrame(restored, for: session.window) {
                snapStates.remove(windowID: session.window.id)
                startFrame = restored
            }
        }

        guard let target = session.target,
              settings.isEnabled,
              settings.edgeSnapEnabled
        else {
            return
        }

        onCommit?(session.window, target, startFrame)
    }

    private func cocoaPoint(for event: CGEvent) -> CGPoint {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: event.location.x, y: primaryHeight - event.location.y)
    }
}

private let edgeSnapEventCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let monitor = Unmanaged<EdgeSnapMonitor>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated {
        monitor.handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}
