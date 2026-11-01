import Foundation

/// Multi-window layouts used by the "Arrange" menu.
public enum TilingPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case twoColumns
    case threeColumns
    case grid
    case mainLeftStack
    case mainTopRow
    case cascade

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .twoColumns: "Две колонки"
        case .threeColumns: "Три колонки"
        case .grid: "Сетка"
        case .mainLeftStack: "Главное окно + стек"
        case .mainTopRow: "Главное окно сверху"
        case .cascade: "Каскад"
        }
    }

    public var symbolName: String {
        switch self {
        case .twoColumns: "rectangle.split.2x1"
        case .threeColumns: "rectangle.split.3x1"
        case .grid: "square.grid.2x2"
        case .mainLeftStack: "sidebar.left"
        case .mainTopRow: "rectangle.topthird.inset.filled"
        case .cascade: "rectangle.on.rectangle"
        }
    }

    /// Returns one destination per window, in top-left reading order.
    public func frames(
        count: Int,
        in visibleFrame: CGRect,
        gap: CGFloat = 0
    ) -> [CGRect] {
        guard count > 0, visibleFrame.width > 0, visibleFrame.height > 0 else { return [] }

        let maximumGap = min(visibleFrame.width, visibleFrame.height) / 5
        let spacing = max(0, min(gap, maximumGap))
        let outer = visibleFrame.insetBy(dx: spacing, dy: spacing)

        guard count > 1 else {
            return [outer]
        }

        switch self {
        case .twoColumns:
            return balancedColumns(in: outer, count: count, columnCount: 2, gap: spacing)
        case .threeColumns:
            return balancedColumns(in: outer, count: count, columnCount: min(3, count), gap: spacing)
        case .grid:
            let columns = Int(ceil(sqrt(Double(count))))
            return grid(in: outer, count: count, columns: columns, gap: spacing)
        case .mainLeftStack:
            return mainLeftStack(in: outer, count: count, gap: spacing)
        case .mainTopRow:
            return mainTopRow(in: outer, count: count, gap: spacing)
        case .cascade:
            return cascade(in: outer, count: count, gap: spacing)
        }
    }

    private func balancedColumns(
        in frame: CGRect,
        count: Int,
        columnCount: Int,
        gap: CGFloat
    ) -> [CGRect] {
        let columnFrames = Self.columns(in: frame, count: columnCount, gap: gap)
        var remaining = count
        var result: [CGRect] = []

        for index in 0..<columnCount {
            let remainingColumns = columnCount - index
            let items = Int(ceil(Double(remaining) / Double(remainingColumns)))
            guard items > 0 else { continue }
            let rows = Self.rows(in: columnFrames[index], count: items, gap: gap)
            result.append(contentsOf: rows)
            remaining -= items
        }
        return result
    }

    private func grid(
        in frame: CGRect,
        count: Int,
        columns: Int,
        gap: CGFloat
    ) -> [CGRect] {
        let rowsCount = Int(ceil(Double(count) / Double(columns)))
        let rowFrames = Self.rows(in: frame, count: rowsCount, gap: gap)
        var result: [CGRect] = []

        for row in 0..<rowsCount {
            let rowItemCount = min(columns, count - result.count)
            let cells = Self.columns(in: rowFrames[row], count: rowItemCount, gap: gap)
            result.append(contentsOf: cells)
        }
        return result
    }

    private func mainLeftStack(in frame: CGRect, count: Int, gap: CGFloat) -> [CGRect] {
        let mainWidth = (frame.width - gap) * 0.62
        let main = CGRect(x: frame.minX, y: frame.minY, width: mainWidth, height: frame.height)
        let side = CGRect(
            x: frame.minX + mainWidth + gap,
            y: frame.minY,
            width: frame.width - mainWidth - gap,
            height: frame.height
        )
        var result = [main]
        result.append(contentsOf: Self.rows(in: side, count: count - 1, gap: gap))
        return result
    }

    private func mainTopRow(in frame: CGRect, count: Int, gap: CGFloat) -> [CGRect] {
        let mainHeight = (frame.height - gap) * 0.6
        let main = CGRect(
            x: frame.minX,
            y: frame.maxY - mainHeight,
            width: frame.width,
            height: mainHeight
        )
        let bottom = CGRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width,
            height: frame.height - mainHeight - gap
        )
        var result = [main]
        result.append(contentsOf: Self.columns(in: bottom, count: count - 1, gap: gap))
        return result
    }

    private func cascade(in frame: CGRect, count: Int, gap: CGFloat) -> [CGRect] {
        let width = frame.width * 0.72
        let height = frame.height * 0.78
        let step = max(18, min(34, frame.width * 0.028))
        let visibleSteps = 5
        return (0..<count).map { index in
            let slot = index % visibleSteps
            let x = min(frame.minX + CGFloat(slot) * step, frame.maxX - width)
            let y = max(frame.maxY - height - CGFloat(slot) * step, frame.minY)
            return CGRect(x: x, y: y, width: width, height: height)
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
