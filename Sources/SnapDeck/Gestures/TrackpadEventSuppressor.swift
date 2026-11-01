import AppKit
import CoreGraphics
import SnapDeckCore

/// Swallows scroll/gesture events while three or four fingers are on the pad.
/// Raw touches come from MultitouchSupport before the system gesture pipeline;
/// this tap is the second half of the same guard. It is only a listener for
/// normal pointer events and never modifies them.
@MainActor
final class TrackpadEventSuppressor {
    private let activity: TouchActivityState
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var context: SuppressorContext?

    var isRunning: Bool { eventTap != nil }

    init(activity: TouchActivityState) {
        self.activity = activity
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let gestureMask = UInt64(NSEvent.EventTypeMask.gesture.rawValue)
        let mask: CGEventMask =
            (1 << CGEventType.scrollWheel.rawValue) | gestureMask

        let context = SuppressorContext(activity: activity)
        let unmanagedContext = Unmanaged.passUnretained(context)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: trackpadSuppressionCallback,
            userInfo: unmanagedContext.toOpaque()
        ) else {
            DeckLog.gestures.error("Could not create trackpad suppression tap")
            return false
        }

        context.tap = tap
        self.context = context
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        DeckLog.gestures.info("Trackpad event suppression started")
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
        eventTap = nil
        runLoopSource = nil
        context = nil
        activity.update(count: 0)
    }
}

/// Thread-safe bridge between the MultitouchSupport callback thread and the
/// main-thread event tap.
final class TouchActivityState: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var twoFingerSuppression = false

    func update(count: Int) {
        lock.lock()
        self.count = count
        lock.unlock()
    }

    func setTwoFingerSuppression(_ active: Bool) {
        lock.lock()
        twoFingerSuppression = active
        lock.unlock()
    }

    var isSuppressing: Bool {
        lock.lock()
        let value = count >= 3 || twoFingerSuppression
        lock.unlock()
        return value
    }
}

private final class SuppressorContext {
    let activity: TouchActivityState
    var tap: CFMachPort?

    init(activity: TouchActivityState) {
        self.activity = activity
    }
}

private let trackpadSuppressionCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let context = Unmanaged<SuppressorContext>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = context.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    let isGestureEvent = type.rawValue == NSEvent.EventType.gesture.rawValue
    if context.activity.isSuppressing,
       type == .scrollWheel || isGestureEvent {
        return nil
    }
    return Unmanaged.passUnretained(event)
}
