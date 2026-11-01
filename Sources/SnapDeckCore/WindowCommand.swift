import Foundation

public enum WindowCommand: String, CaseIterable, Identifiable, Sendable {
    case leftHalf
    case rightHalf
    case maximize
    case restore
    case center
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case nextDisplay
    case previousDisplay
    case tileTwoColumns
    case tileThreeColumns
    case tileGrid
    case tileMainLeftStack
    case tileMainTopRow
    case tileCascade

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .leftHalf: "Прижать влево"
        case .rightHalf: "Прижать вправо"
        case .maximize: "Развернуть"
        case .restore: "Вернуть размер"
        case .center: "По центру"
        case .topLeft: "В левый верхний угол"
        case .topRight: "В правый верхний угол"
        case .bottomLeft: "В левый нижний угол"
        case .bottomRight: "В правый нижний угол"
        case .nextDisplay: "На следующий дисплей"
        case .previousDisplay: "На предыдущий дисплей"
        case .tileTwoColumns: "Разложить: две колонки"
        case .tileThreeColumns: "Разложить: три колонки"
        case .tileGrid: "Разложить: сетка"
        case .tileMainLeftStack: "Разложить: главное + стек"
        case .tileMainTopRow: "Разложить: главное сверху"
        case .tileCascade: "Разложить: каскад"
        }
    }

    public var shortcutHint: String? {
        switch self {
        case .leftHalf: "⌃⌥←"
        case .rightHalf: "⌃⌥→"
        case .maximize: "⌃⌥↑"
        case .restore: "⌃⌥↓"
        case .center: "⌃⌥C"
        case .topLeft: "⌃⌥U"
        case .topRight: "⌃⌥I"
        case .bottomLeft: "⌃⌥J"
        case .bottomRight: "⌃⌥K"
        case .nextDisplay: "⌃⌥⇧→"
        case .previousDisplay: "⌃⌥⇧←"
        case .tileTwoColumns: nil
        case .tileThreeColumns: nil
        case .tileGrid: nil
        case .tileMainLeftStack: nil
        case .tileMainTopRow: nil
        case .tileCascade: nil
        }
    }

    public var snapZone: SnapZone? {
        switch self {
        case .leftHalf: .leftHalf
        case .rightHalf: .rightHalf
        case .maximize: .maximize
        case .center: .center
        case .topLeft: .topLeft
        case .topRight: .topRight
        case .bottomLeft: .bottomLeft
        case .bottomRight: .bottomRight
        default: nil
        }
    }

    public var tilingPreset: TilingPreset? {
        switch self {
        case .tileTwoColumns: .twoColumns
        case .tileThreeColumns: .threeColumns
        case .tileGrid: .grid
        case .tileMainLeftStack: .mainLeftStack
        case .tileMainTopRow: .mainTopRow
        case .tileCascade: .cascade
        default: nil
        }
    }
}
