//
//  GameScene.swift
//  test_game
//
//  Created by 遠藤貴憲 on 2025/12/12.
//

import SpriteKit

class GameScene: SKScene {
    private var scoreLabel: SKLabelNode!
    private var timeLabel: SKLabelNode!
    private var gameOverLabel: SKLabelNode!
    private var comboLabel: SKLabelNode!
    private var finalScoreLabel: SKLabelNode!
    private var submitButton: SKLabelNode!
    private var retryButton: SKLabelNode!
    private var backToMenuButton: SKLabelNode!
    private var pauseButton: SKLabelNode!
    private var isGamePaused = false // 一時停止状態

    // board model
    private var board: Board = Board(rows: 8, cols: 8)
    private var nodeMap: [Position: TileNode] = [:]

    // layout
    private var tileSize: CGFloat = 40
    private var boardOrigin: CGPoint = .zero // top-left origin

    // touch handling
    private var touchStartPos: Position?
    private var isAnimating = false
    private var inputEnabled = true

    // timeout game-over
    private var initialTime: TimeInterval = 10.0 // 難易度による制限時間
    private var timeRemaining: TimeInterval = 10.0
    private var countdownActive: Bool = true
    private var lastUpdateTime: TimeInterval? = nil
    private var isGameOver: Bool = false
    private var gameOverUIVisible: Bool = false
    
    // 広告リトライ機能
    private var retryButton2: SKLabelNode? // タイムアップ時のリトライボタン
    private var showedContinueOption = false // 継続オプションを表示したかどうか
    private var continueUsedToday: Int {
        get {
            let key = "continueUsedToday_\(getCurrentDateString())"
            return UserDefaults.standard.integer(forKey: key)
        }
        set {
            let key = "continueUsedToday_\(getCurrentDateString())"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // combo system
    private var comboCount: Int = 0
    private var comboTimer: TimeInterval = 0.0
    private let comboTimeout: TimeInterval = 1.5 // コンボが途切れるまでの時間

    // debugging: verify model/node consistency
    private func debugBoardState(_ stage: String) {
        let rows = board.rows
        let cols = board.cols
        var nilCount = 0
        var tileCount = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if board[r, c] == nil { nilCount += 1 } else { tileCount += 1 }
            }
        }

        let nodeCount = nodeMap.count

        // detect duplicate node instances mapped to multiple positions
        var seen = Set<ObjectIdentifier>()
        var duplicates: [String] = []
        var posMismatch: [String] = []
        for (pos, node) in nodeMap {
            let id = ObjectIdentifier(node)
            if seen.contains(id) {
                duplicates.append("(\(pos.row),\(pos.col))")
            } else {
                seen.insert(id)
            }
            // verify node position roughly matches model position
            let expected = positionFor(row: pos.row, col: pos.col)
            let dx = expected.x - node.position.x
            let dy = expected.y - node.position.y
            if sqrt(dx*dx + dy*dy) > 2.0 {
                posMismatch.append("(\(pos.row),\(pos.col)) -> node at {\(node.position.x),\(node.position.y)} expected {\(expected.x),\(expected.y)}")
            }
        }

        print("[BOARD DEBUG] \(stage) nilCells=\(nilCount) tileCount=\(tileCount) nodeCount=\(nodeCount) duplicates=\(duplicates) posMismatch=\(posMismatch)")
    }

    private func validateBoardInvariant(_ stage: String) {
        let rows = board.rows
        let cols = board.cols
        var tileCount = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if board[r, c] != nil { tileCount += 1 }
            }
        }
        let nodeCount = nodeMap.count
        if tileCount != nodeCount {
            print("[BOARD ASSERT] Mismatch at \(stage): modelTiles=\(tileCount) nodeCount=\(nodeCount)")
            assertionFailure("Board/model/nodeMap count mismatch")
        }
    }

    override func didMove(to view: SKView) {
        backgroundColor = .white

        // 難易度設定を取得（デフォルトは10秒）
        let difficulty = UserDefaults.standard.integer(forKey: "selectedDifficulty")
        initialTime = TimeInterval(difficulty > 0 ? difficulty : 10)
        timeRemaining = initialTime
        
        // 最後にプレイした難易度を保存（ランキング送信時に使用）
        UserDefaults.standard.set(Int(initialTime), forKey: "lastPlayedDifficulty")
        
        // BGMを再生
        AudioManager.shared.playBGM("Short_mistery_001.mp3")

        setupBackground()
        setupScoreLabel()
        setupTimeLabel()
        setupPauseButton()
        setupGameOverLabel()
        setupComboLabel()
        setupGameOverUI()
        layoutBoardArea()
        renderBoard()
        // start countdown immediately
        countdownActive = true
        
        // リワード広告を事前読み込み
        AdMobManager.shared.loadRewardedAd()
    }

    private func setupBackground() {
        // Background image
        let bg = SKSpriteNode(imageNamed: "background_color_basic")
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.size = CGSize(width: size.width, height: size.height)
        bg.zPosition = -200
        addChild(bg)
    }

    private func setupTimeLabel() {
        timeLabel = SKLabelNode(text: "Time: 10.0")
        timeLabel.fontName = "Helvetica-Bold"
        timeLabel.fontSize = 32
        timeLabel.fontColor = .black
        timeLabel.horizontalAlignmentMode = .center
        timeLabel.position = CGPoint(x: size.width / 2, y: size.height - 100)
        timeLabel.zPosition = 1000
        addChild(timeLabel)
    }
    
    private func setupPauseButton() {
        pauseButton = SKLabelNode(text: "⏸️")
        pauseButton.name = "pause"
        pauseButton.fontName = "Helvetica-Bold"
        pauseButton.fontSize = 32
        pauseButton.horizontalAlignmentMode = .right
        pauseButton.position = CGPoint(x: size.width - 20, y: size.height - 100)
        pauseButton.zPosition = 1000
        addChild(pauseButton)
    }

    private func setupGameOverLabel() {
        gameOverLabel = SKLabelNode(text: "TIME UP")
        gameOverLabel.fontName = "Helvetica-Bold"
        gameOverLabel.fontSize = 32
        gameOverLabel.fontColor = .red
        gameOverLabel.horizontalAlignmentMode = .center
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.17) // 盤面の下に配置
        gameOverLabel.alpha = 0.0
        gameOverLabel.zPosition = 2000
        addChild(gameOverLabel)
    }
    
    private func setupComboLabel() {
        comboLabel = SKLabelNode(text: "")
        comboLabel.fontName = "Helvetica-Bold"
        comboLabel.fontSize = 40
        comboLabel.fontColor = UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0) // オレンジ色
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.position = CGPoint(x: size.width / 2, y: 100)
        comboLabel.alpha = 0.0
        comboLabel.zPosition = 1500
        addChild(comboLabel)
    }
    
    private func setupGameOverUI() {
        // 最終スコア表示（画面中央に配置）
        finalScoreLabel = SKLabelNode(text: "")
        finalScoreLabel.fontName = "Helvetica-Bold"
        finalScoreLabel.fontSize = 28
        finalScoreLabel.fontColor = .white
        finalScoreLabel.horizontalAlignmentMode = .center
        finalScoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.60) // 盤面の下に配置
        finalScoreLabel.alpha = 0.0
        finalScoreLabel.zPosition = 2001
        addChild(finalScoreLabel)
        
        // スコア送信ボタン（盤面の下、コンパクトに配置）
        submitButton = SKLabelNode(text: "スコアをランキングに反映")
        submitButton.name = "submitScore"
        submitButton.fontName = "Helvetica-Bold"
        submitButton.fontSize = 16
        submitButton.fontColor = .systemYellow
        submitButton.horizontalAlignmentMode = .center
        submitButton.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        submitButton.alpha = 0.0
        submitButton.zPosition = 2001
        addChild(submitButton)
        
        // リトライボタン（コンパクトに配置）
        retryButton = SKLabelNode(text: "リトライ")
        retryButton.name = "retry"
        retryButton.fontName = "Helvetica-Bold"
        retryButton.fontSize = 18
        retryButton.fontColor = .systemGreen
        retryButton.horizontalAlignmentMode = .center
        retryButton.position = CGPoint(x: size.width / 2, y: size.height * 0.08)
        retryButton.alpha = 0.0
        retryButton.zPosition = 2001
        addChild(retryButton)
        
        // トップページへ戻るボタン（コンパクトに配置）
        backToMenuButton = SKLabelNode(text: "トップページへ戻る")
        backToMenuButton.name = "backToMenu"
        backToMenuButton.fontName = "Helvetica-Bold"
        backToMenuButton.fontSize = 18
        backToMenuButton.fontColor = .white
        backToMenuButton.horizontalAlignmentMode = .center
        backToMenuButton.position = CGPoint(x: size.width / 2, y: size.height * 0.04)
        backToMenuButton.alpha = 0.0
        backToMenuButton.zPosition = 2001
        addChild(backToMenuButton)
    }

    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "Helvetica-Bold"
        scoreLabel.fontSize = 32
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.83) // Timeと被らない位置
        scoreLabel.zPosition = 1500
        addChild(scoreLabel)
    }

    private func layoutBoardArea() {
        let margin: CGFloat = 20
        let availableWidth = size.width - margin * 2
        tileSize = min(availableWidth / CGFloat(board.cols), (size.height - 200) / CGFloat(board.rows))
        let boardWidth = tileSize * CGFloat(board.cols)
        // set boardOrigin as top-left corner
        boardOrigin = CGPoint(x: (size.width - boardWidth) / 2, y: size.height * 0.75)
        
        // Add board area background (darker gradient behind tiles)
        let boardHeight = tileSize * CGFloat(board.rows)
        let boardRect = CGRect(x: boardOrigin.x, y: boardOrigin.y - boardHeight, width: boardWidth, height: boardHeight)
        let boardBg = SKShapeNode(rect: boardRect, cornerRadius: 8)
        boardBg.fillColor = UIColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0) // dark blue
        boardBg.strokeColor = UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
        boardBg.lineWidth = 2
        boardBg.zPosition = -100
        addChild(boardBg)
    }

    private func positionFor(row: Int, col: Int) -> CGPoint {
        let x = boardOrigin.x + CGFloat(col) * tileSize + tileSize / 2
        let y = boardOrigin.y - CGFloat(row) * tileSize - tileSize / 2
        return CGPoint(x: x, y: y)
    }

    private func positionForTouch(_ point: CGPoint) -> Position? {
        let relativeX = point.x - boardOrigin.x
        let relativeY = boardOrigin.y - point.y
        let col = Int(relativeX / tileSize)
        let row = Int(relativeY / tileSize)
        guard row >= 0 && row < board.rows && col >= 0 && col < board.cols else { return nil }
        return Position(row: row, col: col)
    }

    private func renderBoard() {
        // clear existing
        for (_, n) in nodeMap { n.removeFromParent() }
        nodeMap.removeAll()

        for r in 0..<board.rows {
            for c in 0..<board.cols {
                if let tile = board[r, c] {
                    let node = TileNode(tile: tile, size: tileSize)
                    node.position = positionFor(row: r, col: c)
                    addChild(node)
                    nodeMap[Position(row: r, col: c)] = node
                }
            }
        }
    }

    // MARK: - touch handlers
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        
        // 一時停止ボタンの処理
        if !isGameOver && nodes(at: p).contains(where: { $0.name == "pause" }) {
            handlePause()
            return
        }
        
        // ゲームオーバー時のボタン処理
        if gameOverUIVisible {
            if nodes(at: p).contains(where: { $0.name == "watchAdToContinue" }) {
                handleWatchAdToContinue()
                return
            }
            if nodes(at: p).contains(where: { $0.name == "endGame" }) {
                // 継続画面をクリアしてゲームオーバー画面へ
                clearContinueUI()
                showGameOverUI()
                return
            }
            if nodes(at: p).contains(where: { $0.name == "submitScore" }) {
                handleSubmitScore()
                return
            }
            if nodes(at: p).contains(where: { $0.name == "retry" }) {
                handleRetry()
                return
            }
            if nodes(at: p).contains(where: { $0.name == "backToMenu" }) {
                handleBackToMenu()
                return
            }
        }
        
        guard inputEnabled else { return }
        if let node = nodes(at: p).first(where: { $0.name == "restart" }) {
            restartGame()
            return
        }
        touchStartPos = positionForTouch(p)
        select(at: touchStartPos)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, !isAnimating, let start = touchStartPos, let t = touches.first else { return }
        let loc = t.location(in: self)
        guard let current = positionForTouch(loc) else { return }
        if current == start { return }
        if Board.areAdjacent(start, current) {
            touchStartPos = nil
            deselectAll()
            attemptSwap(from: start, to: current)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartPos = nil
        deselectAll()
    }

    // MARK: - swap logic
    private func attemptSwap(from: Position, to: Position) {
        guard inputEnabled, !isAnimating else { return }
        guard let nodeA = nodeMap[from], let nodeB = nodeMap[to] else { return }

        isAnimating = true
        let posA = nodeA.position
        let posB = nodeB.position
        let duration: TimeInterval = 0.18

        // raise z to ensure visibility during swap
        nodeA.zPosition = 100
        nodeB.zPosition = 100

        // do not update nodeMap yet; wait until swap is confirmed

        let moveA = SKAction.move(to: posB, duration: duration)
        let moveB = SKAction.move(to: posA, duration: duration)
        
        // スライド音を再生
        AudioManager.shared.playSoundEffect("決定ボタンを押す50.mp3", volume: 0.4)
        
        nodeA.run(moveA)
        nodeB.run(moveB) {
            // update model
            self.board.swap(from: from, to: to)
            self.debugBoardState("swap直後")
            let matches = MatchFinder.findMatches(in: self.board.grid)
            if matches.isEmpty {
                // revert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    self.board.swap(from: from, to: to)
                    let mvA = SKAction.move(to: posA, duration: duration)
                    let mvB = SKAction.move(to: posB, duration: duration)
                    nodeA.run(mvA)
                    nodeB.run(mvB) {
                        nodeA.zPosition = 0
                        nodeB.zPosition = 0
                        self.isAnimating = false
                        self.debugBoardState("swapリバート完了")
                        self.validateBoardInvariant("swapリバート完了")
                    }
                    // revert optimistic mapping
                    self.nodeMap[from] = nodeA
                    self.nodeMap[to] = nodeB
                }
            } else {
                // keep swap and handle matches (removal, collapse, refill, chain)
                nodeA.zPosition = 0
                nodeB.zPosition = 0
                // update nodeMap mapping now that swap is confirmed
                self.nodeMap[from] = nodeB
                self.nodeMap[to] = nodeA
                self.debugBoardState("swap確定後")
                self.validateBoardInvariant("swap確定後")
                // start processing matches
                self.handleMatchesLoop(initialMatches: matches)
            }
        }
    }

    // score
    private var score: Int = 0

    private func handleMatchesLoop(initialMatches: Set<Position>) {
        let matches = initialMatches
        // コンボカウント増加
        comboCount += 1
        comboTimer = comboTimeout
        
        processMatches(matches: matches) {
            // before checking for new matches, log state
            self.debugBoardState("連鎖チェック直前")
            // after processing this round, check for new matches
            let newMatches = MatchFinder.findMatches(in: self.board.grid)
            if newMatches.isEmpty {
                // done with chain
                self.isAnimating = false
                // コンボ表示
                if self.comboCount > 1 {
                    self.showCombo()
                }
            } else {
                // continue chain
                self.handleMatchesLoop(initialMatches: newMatches)
            }
        }
    }

    private func processMatches(matches: Set<Position>, completion: @escaping ()->Void) {
        guard !matches.isEmpty else { completion(); return }
        
        // パズルが消える音を再生
        AudioManager.shared.playSoundEffect("ペタッ.mp3", volume: 0.6)

        // scoring with combo multiplier
        let removed = matches.count
        var baseScore = removed * 10
        if removed >= 4 { baseScore += (removed - 3) * 10 }
        
        // コンボボーナス計算
        let comboMultiplier: Double
        switch comboCount {
        case 1:
            comboMultiplier = 1.0
        case 2:
            comboMultiplier = 1.5
        case 3:
            comboMultiplier = 2.0
        default:
            comboMultiplier = 1.0 + Double(comboCount) * 0.5
        }
        
        let gained = Int(Double(baseScore) * comboMultiplier)
        score += gained
        scoreLabel.text = "Score: \(formatNumber(score))"

        // collect nodes to remove and clear their nodeMap entries
        var removingNodes: [(pos: Position, node: SKNode)] = []
        for pos in matches {
            if let node = nodeMap[pos] {
                removingNodes.append((pos, node))
                // remove mapping now; model will be cleared next
                nodeMap[pos] = nil
            }
        }

        // Update model first (remove tiles) then compute collapse/refill moves
        _ = board.remove(positions: matches)
        // log after model removal
        self.debugBoardState("消去直後 (モデル更新)")

        // compute moves (this updates model to final post-collapse state)
        let moves = board.collapseAndRefill()
        self.debugBoardState("落下（モデル計算）直後")

        // animate removed nodes first, then animate moves and refill
        let removeAction = SKAction.group([SKAction.scale(to: 0.1, duration: 0.18), SKAction.fadeOut(withDuration: 0.18)])
        var remaining = removingNodes.count
        if remaining == 0 {
            // no nodes to remove visually -> directly animate moves
            self.animateMoves(moves: moves, completion: completion)
            return
        }

        for item in removingNodes {
            let node = item.node
            node.run(removeAction) {
                node.removeFromParent()
                remaining -= 1
                if remaining == 0 {
                    // after removal animations, reset timer (a successful clear happened)
                    self.resetTimer()
                    // after removal animations, animate collapse/refill
                    self.animateMoves(moves: moves, completion: completion)
                }
            }
        }
    }

    // Animate the moves computed by Board.collapseAndRefill()
    private func animateMoves(moves: [(from: Position, to: Position, tile: Tile)], completion: @escaping ()->Void) {
        var pending = moves.count
        if pending == 0 { completion(); return }

        // Reserve destination nodes: map mv.to -> existing node (mv.from)
        var reserved: [Position: TileNode] = [:]
        var newTiles: [Position: Tile] = [:]

        for mv in moves {
            if mv.from.row == mv.to.row && mv.from.col == mv.to.col {
                // new tile to create
                newTiles[mv.to] = mv.tile
            } else {
                if let node = nodeMap[mv.from] {
                    reserved[mv.to] = node
                    nodeMap[mv.from] = nil
                } else {
                    // missing node, treat destination as new tile
                    newTiles[mv.to] = mv.tile
                }
            }
        }

        // Now animate: moving reserved nodes, and spawning new ones
        for mv in moves {
            if let node = reserved[mv.to] {
                let target = positionFor(row: mv.to.row, col: mv.to.col)
                node.zPosition = 20
                node.run(SKAction.move(to: target, duration: 0.18)) {
                    node.zPosition = 0
                    self.nodeMap[mv.to] = node
                    pending -= 1
                    if pending == 0 {
                        self.debugBoardState("補充直後")
                        self.validateBoardInvariant("補充直後")
                        completion()
                    }
                }
            } else if let tile = newTiles[mv.to] {
                let startRow = max(0, mv.to.row - 1)
                let startPos = positionFor(row: startRow, col: mv.to.col)
                let node = TileNode(tile: tile, size: tileSize)
                node.position = startPos
                node.alpha = 0.0
                node.zPosition = 50
                addChild(node)
                let target = positionFor(row: mv.to.row, col: mv.to.col)
                let seq = SKAction.sequence([SKAction.fadeIn(withDuration: 0.05), SKAction.move(to: target, duration: 0.18)])
                node.run(seq) {
                    node.zPosition = 0
                    self.nodeMap[mv.to] = node
                    pending -= 1
                    if pending == 0 {
                        self.debugBoardState("補充直後")
                        self.validateBoardInvariant("補充直後")
                        completion()
                    }
                }
            } else {
                // fallback: create node at destination
                let node = TileNode(tile: mv.tile, size: tileSize)
                node.position = positionFor(row: mv.to.row, col: mv.to.col)
                node.zPosition = 0
                addChild(node)
                self.nodeMap[mv.to] = node
                pending -= 1
                if pending == 0 {
                    self.debugBoardState("補充直後")
                    self.validateBoardInvariant("補充直後")
                    completion()
                }
            }
        }
    }

    // restart
    private func restartGame() {
        board = Board(rows: board.rows, cols: board.cols)
        renderBoard()
    }

    // selection highlight helpers
    private func deselectAll() {
        for (_, node) in nodeMap {
            node.selectHighlighted(false)
        }
    }

    private func select(at pos: Position?) {
        deselectAll()
        guard let p = pos, let node = nodeMap[p] else { return }
        node.selectHighlighted(true)
    }

    // MARK: - Combo Display
    private func showCombo() {
        comboLabel.text = "\(comboCount)コンボ!"
        comboLabel.alpha = 0.0
        comboLabel.setScale(0.5)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
        let wait = SKAction.wait(forDuration: 0.8)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        
        let sequence = SKAction.sequence([
            SKAction.group([fadeIn, scaleUp]),
            wait,
            scaleDown,
            fadeOut
        ])
        
        comboLabel.run(sequence)
    }
    
    // MARK: - Timer / Game Over
    private func resetTimer() {
        timeRemaining = initialTime
        countdownActive = true
        updateTimeLabel()
    }

    private func updateTimeLabel() {
        let t = max(0.0, timeRemaining)
        timeLabel.text = String(format: "Time: %.1f", t)
    }

    private func triggerGameOver() {
        guard !isGameOver else { return }
        isGameOver = true
        countdownActive = false
        inputEnabled = false
        isAnimating = true

        // save last score to UserDefaults
        UserDefaults.standard.set(self.score, forKey: "lastScore")
        
        // 広告リトライが利用可能かチェック
        if continueUsedToday < 3 {
            // 広告視聴で継続のオプションを表示
            showContinueOption()
        } else {
            // 通常のゲームオーバー
            showGameOverUI()
        }
    }
    
    private func showContinueOption() {
        showedContinueOption = true // 継続オプション表示フラグを立てる
        // タイムアップメッセージ
        let timeUpLabel = SKLabelNode(text: "TIME UP!")
        timeUpLabel.fontName = "Helvetica-Bold"
        timeUpLabel.fontSize = 40
        timeUpLabel.fontColor = .red
        timeUpLabel.horizontalAlignmentMode = .center
        timeUpLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.24) // もう少し上に配置
        timeUpLabel.alpha = 0.0
        timeUpLabel.zPosition = 2000
        addChild(timeUpLabel)
        timeUpLabel.run(SKAction.fadeIn(withDuration: 0.5))
        
        // 継続ボタン（上に配置）
        retryButton2 = SKLabelNode(text: "広告を見て継続")
        retryButton2?.name = "watchAdToContinue"
        retryButton2?.fontName = "Helvetica-Bold"
        retryButton2?.fontSize = 18
        retryButton2?.fontColor = .systemGreen
        retryButton2?.horizontalAlignmentMode = .center
        retryButton2?.position = CGPoint(x: size.width / 2, y: size.height * 0.19)
        retryButton2?.alpha = 0.0
        retryButton2?.zPosition = 2001
        if let btn = retryButton2 {
            addChild(btn)
        }
        
        // 残り回数表示（下に配置）
        let remainingLabel = SKLabelNode(text: "今日の残り回数: \(3 - continueUsedToday)/3")
        remainingLabel.fontName = "Helvetica"
        remainingLabel.fontSize = 14
        remainingLabel.fontColor = .white
        remainingLabel.horizontalAlignmentMode = .center
        remainingLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.15)
        remainingLabel.alpha = 0.0
        remainingLabel.zPosition = 2001
        addChild(remainingLabel)
        
        // 終了ボタン（コンパクトに）
        let endButton = SKLabelNode(text: "終了")
        endButton.name = "endGame"
        endButton.fontName = "Helvetica-Bold"
        endButton.fontSize = 18
        endButton.fontColor = .systemRed
        endButton.horizontalAlignmentMode = .center
        endButton.position = CGPoint(x: size.width / 2, y: size.height * 0.08)
        endButton.alpha = 0.0
        endButton.zPosition = 2001
        addChild(endButton)
        
        // フェードイン
        let fadeIn = SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.5)
        ])
        remainingLabel.run(fadeIn)
        retryButton2?.run(fadeIn)
        endButton.run(fadeIn)
        
        gameOverUIVisible = true
    }
    
    private func showGameOverUI() {
        gameOverUIVisible = true

        // show GAME OVER label (fade in)
        gameOverLabel.alpha = 0.0
        let fade = SKAction.fadeIn(withDuration: 1.0)
        gameOverLabel.run(fade)
        
        // 最終スコア表示（カンマ区切り）
        finalScoreLabel.text = "Final Score: \(formatNumber(score))"
        finalScoreLabel.alpha = 0.0
        let fadeScore = SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.5)
        ])
        finalScoreLabel.run(fadeScore)
        
        // ボタン表示
        let buttonFade = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeIn(withDuration: 0.5)
        ])
        submitButton.run(buttonFade)
        retryButton.run(buttonFade)
        backToMenuButton.run(buttonFade)
        
        // インタースティシャル広告を表示（継続画面から来た場合は表示しない）
        if !showedContinueOption {
            if let viewController = self.view?.window?.rootViewController {
                AdMobManager.shared.onGameEnd(from: viewController) {
                    print("Ad completed or skipped")
                }
            }
        }
    }
    
    // MARK: - Game Over Button Handlers
    private func handleWatchAdToContinue() {
        guard let viewController = self.view?.window?.rootViewController else { return }
        
        // 広告を1本視聴
        AdMobManager.shared.showRewardedAd(from: viewController) { [weak self] success in
            guard let self = self else { return }
            
            if !success {
                DispatchQueue.main.async {
                    self.showSubmitFeedback("広告視聴が必要です")
                }
                return
            }
            
            // 広告視聴成功 - ゲーム継続
            DispatchQueue.main.async {
                print("[Continue] Ad watched successfully, continuing game...")
                
                // カウントを増やす
                self.continueUsedToday += 1
                print("[Continue] Continue count: \(self.continueUsedToday)/3")
                
                // UIをクリア
                self.clearContinueUI()
                
                // ゲーム状態をリセット
                self.isGameOver = false
                self.gameOverUIVisible = false
                self.countdownActive = true
                self.inputEnabled = true
                self.isAnimating = false
                
                // タイマーをリセット
                self.timeRemaining = self.initialTime
                self.updateTimeLabel()
                
                // スコアラベルを再表示
                self.scoreLabel.alpha = 1.0
                
                self.showSubmitFeedback("プレイを継続します！")
                print("[Continue] Game resumed successfully")
            }
        }
    }
    
    private func clearContinueUI() {
        // 継続画面のUI要素を削除
        for node in children {
            if node.name == "watchAdToContinue" || node.name == "endGame" ||
               (node is SKLabelNode && (node as! SKLabelNode).text?.contains("TIME UP") == true) ||
               (node is SKLabelNode && (node as! SKLabelNode).text?.contains("広告を1本視聴") == true) ||
               (node is SKLabelNode && (node as! SKLabelNode).text?.contains("今日の残り回数") == true) {
                node.removeFromParent()
            }
        }
        // ゲームオーバーラベルも非表示に
        gameOverLabel?.alpha = 0.0
        retryButton2 = nil
        print("[ClearUI] Continue UI cleared")
    }
    
    private func handleSubmitScore() {
        guard let viewController = self.view?.window?.rootViewController else { return }
        
        promptForUsername { [weak self] username in
            guard let self = self, let username = username else { return }
            
            if !AdMobManager.shared.isReady {
                self.showSubmitFeedback("広告を読み込んでいます...")
                AdMobManager.shared.loadRewardedAd()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if AdMobManager.shared.isReady {
                        self.showAdAndSubmitScore(viewController: viewController, score: self.score, username: username)
                    } else {
                        self.showSubmitFeedback("広告の読み込みに失敗しました")
                    }
                }
            } else {
                self.showAdAndSubmitScore(viewController: viewController, score: self.score, username: username)
            }
        }
    }
    
    private func handleRetry() {
        let scene = GameScene(size: size)
        scene.scaleMode = .aspectFill
        view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.4))
    }
    
    private func handlePause() {
        guard !isGamePaused && !isGameOver else { return }
        
        isGamePaused = true
        countdownActive = false // タイマーを停止
        isAnimating = true // 操作を無効化
        
        // BGMを一時停止
        AudioManager.shared.pauseBGM()
        
        guard let viewController = self.view?.window?.rootViewController else {
            // ViewControllerが取得できない場合は再開
            resumeGame()
            return
        }
        
        // インタースティシャル広告を表示
        AdMobManager.shared.showPauseAd(from: viewController) { [weak self] in
            DispatchQueue.main.async {
                self?.resumeGame()
            }
        }
    }
    
    private func resumeGame() {
        isGamePaused = false
        countdownActive = true // タイマー再開
        isAnimating = false // 操作を有効化
        
        // BGMを再開
        AudioManager.shared.resumeBGM()
        
        print("Game resumed after pause")
    }
    
    private func handleBackToMenu() {
        // BGMを停止してからメニューへ
        AudioManager.shared.stopBGM()
        let scene = OpeningScene(size: size)
        scene.scaleMode = .aspectFill
        view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.4))
    }
    
    private func promptForUsername(completion: @escaping (String?) -> Void) {
        guard let viewController = self.view?.window?.rootViewController else {
            completion(nil)
            return
        }
        
        let alert = UIAlertController(title: "ランキング登録", message: "名前を入力してください", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "名前"
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in
            completion(nil)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            let name = alert.textFields?.first?.text ?? "Player"
            completion(name.isEmpty ? "Player" : name)
        })
        viewController.present(alert, animated: true)
    }
    
    private func showAdAndSubmitScore(viewController: UIViewController, score: Int, username: String) {
        AdMobManager.shared.showRewardedAd(from: viewController) { [weak self] success in
            guard let self = self else { return }
            if success {
                RankingsManager.shared.setup { err in
                    if let e = err {
                        print("Auth error: \(e)")
                        DispatchQueue.main.async {
                            self.showSubmitFeedback("認証に失敗しました")
                        }
                        return
                    }
                    // 現在の難易度を取得（UserDefaultsから）
                    let difficulty = UserDefaults.standard.integer(forKey: "lastPlayedDifficulty")
                    print("[Ranking] Submitting score: \(score), difficulty: \(difficulty)")
                    RankingsManager.shared.submitScore(score, difficulty: difficulty, name: username) { err in
                        DispatchQueue.main.async {
                            if let e = err {
                                print("Submit error: \(e)")
                                self.showSubmitFeedback("送信に失敗しました")
                            } else {
                                self.showSubmitFeedback("スコアを送信しました！")
                            }
                        }
                    }
                }
            } else {
                self.showSubmitFeedback("広告視聴がキャンセルされました")
            }
        }
    }
    
    private func showSubmitFeedback(_ text: String) {
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "Helvetica"
        lbl.fontSize = 18
        lbl.fontColor = .white
        lbl.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
        lbl.alpha = 0.0
        lbl.zPosition = 2002
        addChild(lbl)
        let seq = SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.2),
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ])
        lbl.run(seq)
    }
    
    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    override func update(_ currentTime: TimeInterval) {
        // delta time
        if lastUpdateTime == nil { lastUpdateTime = currentTime }
        let dt = currentTime - (lastUpdateTime ?? currentTime)
        lastUpdateTime = currentTime

        guard countdownActive, !isGameOver else { return }

        // countdown progresses regardless of isAnimating per requirements
        timeRemaining -= dt
        if timeRemaining <= 0 {
            timeRemaining = 0
            updateTimeLabel()
            triggerGameOver()
        } else {
            updateTimeLabel()
        }
        
        // コンボタイマーの更新
        if comboTimer > 0 {
            comboTimer -= dt
            if comboTimer <= 0 {
                // コンボリセット
                comboCount = 0
                comboTimer = 0.0
            }
        }
    }
}
