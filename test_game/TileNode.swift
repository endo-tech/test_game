import SpriteKit

final class TileNode: SKNode {
    private let shapeNode: SKShapeNode
    private(set) var tile: Tile
    private var currentSize: CGFloat

    // simple cache for CGPath per shape+size to avoid recreating paths repeatedly
    private static var pathCache: [String: CGPath] = [:]

    init(tile: Tile, size: CGFloat) {
        self.tile = tile
        self.currentSize = size
        let path = TileNode.path(for: tile.type.shape, size: size)
        shapeNode = SKShapeNode(path: path)
        super.init()

        shapeNode.fillColor = tile.type.color
        shapeNode.strokeColor = UIColor.black
        shapeNode.lineWidth = 2.0
        shapeNode.position = .zero
        shapeNode.zPosition = 0
        addChild(shapeNode)
        // center the node (we will position this TileNode at board cell center)
        self.name = "tile"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(tile: Tile, size: CGFloat) {
        self.tile = tile
        shapeNode.fillColor = tile.type.color
        if size != currentSize {
            currentSize = size
            shapeNode.path = TileNode.path(for: tile.type.shape, size: size)
        }
    }

    func selectHighlighted(_ on: Bool) {
        if on {
            shapeNode.strokeColor = UIColor.white
            shapeNode.lineWidth = 4.0
            let scale = SKAction.scale(to: 1.08, duration: 0.08)
            shapeNode.run(scale)
        } else {
            shapeNode.strokeColor = UIColor.black
            shapeNode.lineWidth = 2.0
            let scale = SKAction.scale(to: 1.0, duration: 0.08)
            shapeNode.run(scale)
        }
    }

    // MARK: - Path cache
    private static func path(for shape: ShapeType, size: CGFloat) -> CGPath {
        let key = "\(shape)-\(size)"
        if let p = pathCache[key] { return p }

        let s = size * 0.9 // inner padding
        let path: CGPath
        switch shape {
        case .circle:
            let rect = CGRect(x: -s/2, y: -s/2, width: s, height: s)
            path = UIBezierPath(ovalIn: rect).cgPath
        case .square:
            let rect = CGRect(x: -s/2, y: -s/2, width: s, height: s)
            path = UIBezierPath(rect: rect).cgPath
        case .triangle:
            let h = s * sqrt(3) / 2.0
            let p = CGMutablePath()
            // points centered at origin: top, bottom-left, bottom-right
            p.move(to: CGPoint(x: 0, y: h * 2.0/3.0))
            p.addLine(to: CGPoint(x: -s/2, y: -h/3.0))
            p.addLine(to: CGPoint(x: s/2, y: -h/3.0))
            p.closeSubpath()
            path = p
        }

        pathCache[key] = path
        return path
    }
}
