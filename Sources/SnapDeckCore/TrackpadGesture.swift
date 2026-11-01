import Foundation

/// Gesture vocabulary reserved for the next iteration. The window engine is
/// already command-based, so a raw-touch source only needs to emit one of these
/// values and the same SnapCoordinator path will be used.
public enum TrackpadGesture: String, CaseIterable, Codable, Sendable {
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case swipeTopLeft
    case swipeTopRight
    case swipeBottomLeft
    case swipeBottomRight
    case pinchIn
    case pinchOut

    public var fingers: Int {
        switch self {
        case .pinchIn, .pinchOut: 4
        default: 3
        }
    }

    public var command: WindowCommand? {
        switch self {
        case .swipeLeft: .leftHalf
        case .swipeRight: .rightHalf
        case .swipeUp: .maximize
        case .swipeDown: .restore
        case .swipeTopLeft: .topLeft
        case .swipeTopRight: .topRight
        case .swipeBottomLeft: .bottomLeft
        case .swipeBottomRight: .bottomRight
        case .pinchIn, .pinchOut: nil
        }
    }

    public var title: String {
        switch self {
        case .swipeLeft: "Три пальца влево"
        case .swipeRight: "Три пальца вправо"
        case .swipeUp: "Три пальца вверх"
        case .swipeDown: "Три пальца вниз"
        case .swipeTopLeft: "Три пальца влево-вверх"
        case .swipeTopRight: "Три пальца вправо-вверх"
        case .swipeBottomLeft: "Три пальца влево-вниз"
        case .swipeBottomRight: "Три пальца вправо-вниз"
        case .pinchIn: "Четыре пальца: сжать"
        case .pinchOut: "Четыре пальца: развести"
        }
    }

    public var actionTitle: String {
        switch self {
        case .pinchIn: "Показать сетку раскладок"
        case .pinchOut: "Показать сетку раскладок"
        default: command?.title ?? "—"
        }
    }
}
