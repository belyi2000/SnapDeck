import Foundation

/// A destination for a single window inside a screen's usable area.
public enum SnapZone: String, CaseIterable, Codable, Identifiable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case firstThird
    case centerThird
    case lastThird
    case firstTwoThirds
    case lastTwoThirds
    case maximize
    case center

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .leftHalf: "Левая половина"
        case .rightHalf: "Правая половина"
        case .topHalf: "Верхняя половина"
        case .bottomHalf: "Нижняя половина"
        case .topLeft: "Левый верхний угол"
        case .topRight: "Правый верхний угол"
        case .bottomLeft: "Левый нижний угол"
        case .bottomRight: "Правый нижний угол"
        case .firstThird: "Левая треть"
        case .centerThird: "Центральная треть"
        case .lastThird: "Правая треть"
        case .firstTwoThirds: "Левые две трети"
        case .lastTwoThirds: "Правые две трети"
        case .maximize: "На весь экран"
        case .center: "По центру"
        }
    }

    public var shortTitle: String {
        switch self {
        case .leftHalf: "Слева"
        case .rightHalf: "Справа"
        case .topHalf: "Сверху"
        case .bottomHalf: "Снизу"
        case .topLeft: "Слева сверху"
        case .topRight: "Справа сверху"
        case .bottomLeft: "Слева снизу"
        case .bottomRight: "Справа снизу"
        case .firstThird: "1/3 слева"
        case .centerThird: "1/3 центр"
        case .lastThird: "1/3 справа"
        case .firstTwoThirds: "2/3 слева"
        case .lastTwoThirds: "2/3 справа"
        case .maximize: "Весь экран"
        case .center: "Центр"
        }
    }

    public var symbolName: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .topHalf: "rectangle.tophalf.filled"
        case .bottomHalf: "rectangle.bottomhalf.filled"
        case .topLeft: "rectangle.inset.topleft.filled"
        case .topRight: "rectangle.inset.topright.filled"
        case .bottomLeft: "rectangle.inset.bottomleft.filled"
        case .bottomRight: "rectangle.inset.bottomright.filled"
        case .firstThird: "rectangle.split.3x1"
        case .centerThird: "rectangle.split.3x1"
        case .lastThird: "rectangle.split.3x1"
        case .firstTwoThirds: "rectangle.split.3x1"
        case .lastTwoThirds: "rectangle.split.3x1"
        case .maximize: "arrow.up.left.and.arrow.down.right"
        case .center: "rectangle.center.inset.filled"
        }
    }

    /// The opposite half, used to form a linked two-window group.
    public var complementaryHalf: SnapZone? {
        switch self {
        case .leftHalf: .rightHalf
        case .rightHalf: .leftHalf
        case .topHalf: .bottomHalf
        case .bottomHalf: .topHalf
        default: nil
        }
    }

    /// The second pane that Snap Assist should offer after this snap.
    /// Thirds and full-screen layouts intentionally return nil: a window picker
    /// in a very narrow pane would be harder to use than the normal switcher.
    public var assistZone: SnapZone? {
        switch self {
        case .leftHalf, .topLeft, .bottomLeft:
            .rightHalf
        case .rightHalf, .topRight, .bottomRight:
            .leftHalf
        case .topHalf:
            .bottomHalf
        case .bottomHalf:
            .topHalf
        default:
            nil
        }
    }

    /// Converts AX/CoreGraphics coordinates (origin at the top-left of the primary
    /// display) into Cocoa screen coordinates (origin at the bottom-left).
    public static func cocoaRect(fromAX rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func axRect(fromCocoa rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Computes the destination in Cocoa screen coordinates.
    ///
    /// `gap` is the space between a window and the screen edge, and also the
    /// space between adjacent windows.
    public func rect(in visibleFrame: CGRect, gap: CGFloat = 0) -> CGRect {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return visibleFrame }

        let maximumGap = min(visibleFrame.width, visibleFrame.height) / 5
        let spacing = max(0, min(gap, maximumGap))
        let outer = visibleFrame.insetBy(dx: spacing, dy: spacing)

        switch self {
        case .leftHalf:
            return Self.columns(in: outer, count: 2, gap: spacing)[0]
        case .rightHalf:
            return Self.columns(in: outer, count: 2, gap: spacing)[1]
        case .topHalf:
            return Self.rows(in: outer, count: 2, gap: spacing)[0]
        case .bottomHalf:
            return Self.rows(in: outer, count: 2, gap: spacing)[1]
        case .topLeft:
            return Self.rows(in: Self.columns(in: outer, count: 2, gap: spacing)[0], count: 2, gap: spacing)[0]
        case .topRight:
            return Self.rows(in: Self.columns(in: outer, count: 2, gap: spacing)[1], count: 2, gap: spacing)[0]
        case .bottomLeft:
            return Self.rows(in: Self.columns(in: outer, count: 2, gap: spacing)[0], count: 2, gap: spacing)[1]
        case .bottomRight:
            return Self.rows(in: Self.columns(in: outer, count: 2, gap: spacing)[1], count: 2, gap: spacing)[1]
        case .firstThird:
            return Self.columns(in: outer, count: 3, gap: spacing)[0]
        case .centerThird:
            return Self.columns(in: outer, count: 3, gap: spacing)[1]
        case .lastThird:
            return Self.columns(in: outer, count: 3, gap: spacing)[2]
        case .firstTwoThirds:
            let columns = Self.columns(in: outer, count: 3, gap: spacing)
            return columns[0].union(columns[1])
        case .lastTwoThirds:
            let columns = Self.columns(in: outer, count: 3, gap: spacing)
            return columns[1].union(columns[2])
        case .maximize:
            return outer
        case .center:
            let width = outer.width * 0.72
            let height = outer.height * 0.82
            return CGRect(
                x: outer.midX - width / 2,
                y: outer.midY - height / 2,
                width: width,
                height: height
            )
        }
    }

    private static func columns(in rect: CGRect, count: Int, gap: CGFloat) -> [CGRect] {
        guard count > 1 else { return [rect] }
        let width = (rect.width - gap * CGFloat(count - 1)) / CGFloat(count)
        return (0..<count).map { index in
            CGRect(
                x: rect.minX + CGFloat(index) * (width + gap),
                y: rect.minY,
                width: width,
                height: rect.height
            )
        }
    }

    private static func rows(in rect: CGRect, count: Int, gap: CGFloat) -> [CGRect] {
        guard count > 1 else { return [rect] }
        let height = (rect.height - gap * CGFloat(count - 1)) / CGFloat(count)
        return (0..<count).map { index in
            CGRect(
                x: rect.minX,
                y: rect.maxY - CGFloat(index + 1) * height - CGFloat(index) * gap,
                width: rect.width,
                height: height
            )
        }
    }
}
