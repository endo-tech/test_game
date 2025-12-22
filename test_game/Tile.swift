import UIKit

enum ShapeType {
    case circle
    case triangle
    case square
}

enum TileType: Int, CaseIterable {
    case daikon = 0
    case tamago
    case konnyaku
    case chikuwa
    case hanpen
    case shirataki

    var color: UIColor {
        switch self {
        case .daikon: return UIColor.systemGreen
        case .tamago: return UIColor.systemYellow
        case .konnyaku: return UIColor.systemPurple
        case .chikuwa: return UIColor.systemOrange
        case .hanpen: return UIColor.systemPink
        case .shirataki: return UIColor.systemTeal
        }
    }

    // assign a shape for each tile type so the model knows the appearance
    var shape: ShapeType {
        switch self {
        case .daikon: return .circle
        case .tamago: return .triangle
        case .konnyaku: return .square
        case .chikuwa: return .circle
        case .hanpen: return .triangle
        case .shirataki: return .square
        }
    }

    static func random(excluding excluded: [TileType] = []) -> TileType {
        let options = TileType.allCases.filter { !excluded.contains($0) }
        return options.randomElement() ?? TileType.allCases.randomElement()!
    }
}

struct Tile {
    var type: TileType
}
