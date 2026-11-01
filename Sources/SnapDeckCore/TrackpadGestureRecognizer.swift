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
    /// A 4-finger right swipe has to travel farther than a normal snap before
    /// it is allowed to quit the frontmost app.
    public var longCloseDistance: Float

    private struct Session {
        let fingers: Int
        let startX: Float
        let startY: Float
        let startSpread: Float
        let startTime: Double
        var invalid: Bool
        var waitingForLongClose: Bool
    }

    private var session: Session?
    private var fired = false
    private var blockedUntilLift = false

    public init(sensitivity: Float = 1.0) {
        self.sensitivity = min(max(sensitivity, 0.55), 1.8)
        axisDominance = 1.35
        spreadTolerance = 0.07
        longCloseDistance = 0.20
    }

    public mutating func reset() {
        session = nil
        fired = false
        blockedUntilLift = false
    }

    public mutating func process(_ frame: TrackpadTouchFrame) -> TrackpadWindowAction? {
        guard frame.count >= 3 else {
            reset()
            return nil
        }
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
            // Once a 4-finger right gesture has entered the long-close lane,
            // it can only finish as a close. Curving into another direction
            // must not minimize or restore anything.
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
            // A clear diagonal is not a window swipe. Once it is large enough,
            // stop interpreting this touch session altogether.
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

    public var currentFingerCount: Int {
        session?.fingers ?? 0
    }
}
