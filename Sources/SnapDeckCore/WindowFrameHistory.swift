import Foundation

/// Remembers a few previous frames per window so "Restore" feels like Undo
/// rather than a fixed "center window" command.
public final class WindowFrameHistory {
    public static let shared = WindowFrameHistory()

    private var frames: [String: [CGRect]] = [:]
    private let limitPerWindow = 6

    public init() {}

    public func record(_ frame: CGRect, for windowID: String) {
        guard frame.width > 1, frame.height > 1 else { return }
        var stack = frames[windowID] ?? []
        if let last = stack.last, last.equalTo(frame, tolerance: 1) {
            return
        }
        stack.append(frame)
        if stack.count > limitPerWindow {
            stack.removeFirst(stack.count - limitPerWindow)
        }
        frames[windowID] = stack
    }

    public func popFrame(for windowID: String) -> CGRect? {
        guard var stack = frames[windowID], let frame = stack.popLast() else {
            return nil
        }
        if stack.isEmpty {
            frames[windowID] = nil
        } else {
            frames[windowID] = stack
        }
        return frame
    }

    public func peekFrame(for windowID: String) -> CGRect? {
        frames[windowID]?.last
    }

    public func forget(windowID: String) {
        frames[windowID] = nil
    }

    public func removeAll() {
        frames.removeAll()
    }
}

private extension CGRect {
    func equalTo(_ other: CGRect, tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}
