import Foundation

public struct TrackpadTouchFrame: Sendable {
    public let count: Int
    public let x: Float
    public let y: Float
    public let spread: Float
    public let timestamp: Double

    public init(count: Int, x: Float, y: Float, spread: Float, timestamp: Double) {
        self.count = count
        self.x = x
        self.y = y
        self.spread = spread
        self.timestamp = timestamp
    }
}

public enum TrackpadWindowAction: String, Sendable, Equatable {
    case snapLeft
    case snapRight
    case maximize
    case minimizeFocused
    case minimizeAll
    case restoreAll
    case closeApplication
}

/// Recognizes deliberate cardinal swipes. It deliberately avoids taps and
/// continuous scrolling: one contact session can fire at most one action.
public struct TrackpadSwipeRecognizer: Sendable {
    public var sensitivity: Float
    public var axisDominance: Float
    public var spreadTolerance: Float
    /// A close gesture has to travel farther than a normal snap before it is
    /// allowed to quit the frontmost app. Shared by 4-finger and 2-finger close.
    public var longCloseDistance: Float
    public var closeApplicationEnabled: Bool
    public var twoFingerCloseEnabled: Bool

    public private(set) var suppressTwoFingerScroll = false

    private struct Session {
        let fingers: Int
        let startX: Float
        let startY: Float
        let startSpread: Float
        let startTime: Double
        var invalid: Bool
        var waitingForLongClose: Bool
    }

    private struct TwoFingerSession {
        let startX: Float
        let startY: Float
        let startSpread: Float
        let startTime: Double
    }

    private var session: Session?
    private var fired = false
    private var blockedUntilLift = false

    private var twoFingerSession: TwoFingerSession?
    private var twoFingerFired = false
    private var blockTwoFingerUntilLift = false

    public init(sensitivity: Float = 1.0) {
        self.sensitivity = min(max(sensitivity, 0.55), 1.8)
        axisDominance = 1.35
        spreadTolerance = 0.07
        longCloseDistance = 0.20
        closeApplicationEnabled = true
        twoFingerCloseEnabled = false
    }

    public mutating func reset() {
        session = nil
        fired = false
        blockedUntilLift = false
        twoFingerSession = nil
        twoFingerFired = false
        blockTwoFingerUntilLift = false
        suppressTwoFingerScroll = false
    }

    public mutating func process(_ frame: TrackpadTouchFrame) -> TrackpadWindowAction? {
        if frame.count == 2 {
            return processTwoFinger(frame)
        }

        if frame.count == 0 {
            reset()
            return nil
        }

        if frame.count == 1 {
            // Keep the "no two-finger close" lock until the pad is completely
            // empty. A single finger may still be left over from a 3/4-finger
            // gesture, and adding one more must not start a close.
            session = nil
            fired = false
            blockedUntilLift = false
            twoFingerSession = nil
            twoFingerFired = false
            suppressTwoFingerScroll = false
            return nil
        }

        // A three/four-finger gesture owns the pad now. Do not let the fingers
        // that remain during its lift turn into a two-finger close afterwards.
        suppressTwoFingerScroll = false
        twoFingerSession = nil
        twoFingerFired = false
        blockTwoFingerUntilLift = true

        guard frame.count <= 4 else {
            session = nil
            blockedUntilLift = true
            return nil
        }

        if blockedUntilLift {
            return nil
        }

        if let current = session, current.fingers != frame.count {
            if fired {
                blockedUntilLift = true
                session = nil
                return nil
            }
            if frame.count == 4 {
                session = Session(
                    fingers: 4,
                    startX: frame.x,
                    startY: frame.y,
                    startSpread: frame.spread,
                    startTime: frame.timestamp,
                    invalid: false,
                    waitingForLongClose: false
                )
                return nil
            }
            // A fourth finger lifted: do not interpret the remainder as a
            // different gesture, and wait for a clean new touch session.
            blockedUntilLift = true
            session = nil
            return nil
        }

        if session == nil {
            session = Session(
                fingers: frame.count,
                startX: frame.x,
                startY: frame.y,
                startSpread: frame.spread,
                startTime: frame.timestamp,
                invalid: false,
                waitingForLongClose: false
            )
            return nil
        }

        guard var current = session else { return nil }
        let dx = frame.x - current.startX
        let dy = frame.y - current.startY
        let movement = sqrt(dx * dx + dy * dy)
        let spreadDelta = abs(frame.spread - current.startSpread)

        if spreadDelta > spreadTolerance {
            current.invalid = true
            session = current
        }

        if fired {
            return nil
        }

        let threshold = 0.052 / max(sensitivity, 0.55)
        guard movement >= threshold else {
            session = current
            return nil
        }

        if current.invalid {
            blockedUntilLift = true
            return nil
        }

        let absX = abs(dx)
        let absY = abs(dy)
        let action: TrackpadWindowAction?

        if current.waitingForLongClose {
            guard dx > 0, absX > absY * axisDominance,
                  absX >= longCloseDistance
            else {
                session = current
                return nil
            }
            fired = true
            return .closeApplication
        }

        if absX > absY * axisDominance, absX > threshold {
            if current.fingers == 4 {
                if dx > 0 {
                    guard closeApplicationEnabled else {
                        blockedUntilLift = true
                        session = nil
                        return nil
                    }
                    // Right is a two-stage gesture. A normal swipe does not
                    // fire; only a deliberate long continuation quits the app.
                    guard absX >= longCloseDistance else {
                        current.waitingForLongClose = true
                        session = current
                        return nil
                    }
                    action = .closeApplication
                } else {
                    // Left is intentionally unassigned. Do not let the same
                    // touch session later turn into a shortcut.
                    blockedUntilLift = true
                    session = nil
                    return nil
                }
            } else {
                action = dx < 0 ? .snapLeft : .snapRight
            }
        } else if absY > absX * axisDominance, absY > threshold {
            if current.fingers == 4 {
                action = dy > 0 ? .restoreAll : .minimizeAll
            } else {
                action = dy > 0 ? .maximize : .minimizeFocused
            }
        } else {
            if movement > 0.14 {
                blockedUntilLift = true
            }
            session = current
            return nil
        }

        guard let action else {
            blockedUntilLift = true
            session = nil
            return nil
        }

        fired = true
        return action
    }

    private mutating func processTwoFinger(_ frame: TrackpadTouchFrame) -> TrackpadWindowAction? {
        guard twoFingerCloseEnabled, closeApplicationEnabled else {
            suppressTwoFingerScroll = false
            twoFingerSession = nil
            return nil
        }
        guard !blockTwoFingerUntilLift else {
            suppressTwoFingerScroll = false
            return nil
        }
        guard !twoFingerFired else { return nil }

        if twoFingerSession == nil {
            twoFingerSession = TwoFingerSession(
                startX: frame.x,
                startY: frame.y,
                startSpread: frame.spread,
                startTime: frame.timestamp
            )
            suppressTwoFingerScroll = false
            return nil
        }

        guard let current = twoFingerSession else { return nil }
        let dx = frame.x - current.startX
        let dy = frame.y - current.startY
        let movement = sqrt(dx * dx + dy * dy)
        let spreadDelta = abs(frame.spread - current.startSpread)

        guard movement >= 0.018, spreadDelta <= spreadTolerance else {
            suppressTwoFingerScroll = false
            return nil
        }

        let absX = abs(dx)
        let absY = abs(dy)
        guard dx > 0, absX > absY * axisDominance else {
            suppressTwoFingerScroll = false
            return nil
        }

        // Suppress app scrolling while the candidate is clearly a long
        // horizontal right gesture. The first few frames can still reach the
        // app; the option is opt-in and the UI explains that trade-off.
        suppressTwoFingerScroll = true

        guard absX >= longCloseDistance else {
            return nil
        }
        twoFingerFired = true
        return .closeApplication
    }

    public var currentFingerCount: Int {
        session?.fingers ?? (twoFingerSession != nil ? 2 : 0)
    }
}
