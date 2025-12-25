import SpriteKit

extension SKLabelNode {
    /// ボタンスタイルの背景を追加
    func addButtonBackground(color: UIColor, padding: CGFloat = 15, cornerRadius: CGFloat = 10) {
        // テキストのサイズを計算
        let textWidth = self.frame.width
        let textHeight = self.frame.height
        
        // 背景の矩形を作成
        let backgroundSize = CGSize(width: textWidth + padding * 2, height: textHeight + padding * 1.5)
        let background = SKShapeNode(rectOf: backgroundSize, cornerRadius: cornerRadius)
        background.fillColor = color
        background.strokeColor = .white
        background.lineWidth = 2
        background.zPosition = -1
        background.name = "buttonBackground"
        
        // 既存の背景があれば削除
        self.children.filter { $0.name == "buttonBackground" }.forEach { $0.removeFromParent() }
        
        self.addChild(background)
    }
    
    /// ボタンスタイル（色指定版）
    static func createButton(text: String, fontSize: CGFloat, color: UIColor, backgroundColor: UIColor) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "Helvetica-Bold"
        button.fontSize = fontSize
        button.fontColor = .white
        button.horizontalAlignmentMode = .center
        button.addButtonBackground(color: backgroundColor)
        return button
    }
}
