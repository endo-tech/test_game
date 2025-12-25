import SpriteKit
import AVFoundation

class OpeningScene: SKScene {
    private var submitLabel: SKLabelNode!
    private var viewLabel: SKLabelNode!
    private var feedbackLabel: SKLabelNode?
    private var leaderboardNodes: [SKLabelNode] = []
    private var closeLabel: SKLabelNode?
    private var videoNode: SKVideoNode?
    private var difficultyLabels: [SKLabelNode] = []
    private var selectedDifficulty: Int = 10 // デフォルトは10秒（中級）
    
    // ランキング表示用
    private var rankingOverlay: SKShapeNode?
    private var rankingDifficultyButtons: [SKLabelNode] = []
    private var currentRankingDifficulty: Int = 10
    
    // 難易度選択関連
    private var difficultyDisplayLabel: SKLabelNode?
    private var leftArrow: SKLabelNode?
    private var rightArrow: SKLabelNode?
    private let difficulties = [13, 10, 7, 5] // 秒数の配列（初級、中級、上級、プロ）
    private var currentDifficultyIndex: Int = 1 // デフォルトは中級（10秒）

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupVideoBackground()
        
        // BGMを再生
        AudioManager.shared.playBGM("Short60_ゆったりDIY_01.mp3")
        
        // 保存された難易度を読み込む
        selectedDifficulty = UserDefaults.standard.integer(forKey: "selectedDifficulty")
        if selectedDifficulty == 0 {
            selectedDifficulty = 10 // デフォルト
        }
        // 配列内のインデックスを設定
        if let index = difficulties.firstIndex(of: selectedDifficulty) {
            currentDifficultyIndex = index
        }

        // Start button with animation
        let start = SKLabelNode(text: "ゲームスタート")
        start.name = "start"
        start.fontName = "Helvetica-Bold"
        start.fontSize = 32
        start.fontColor = UIColor(red: 0.0, green: 0.8, blue: 0.2, alpha: 1.0)
        start.position = CGPoint(x: size.width / 2, y: size.height * 0.50)
        start.alpha = 0
        addChild(start)
        start.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
        
        // Floating animation for start button
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 8, duration: 1.0),
            SKAction.moveBy(x: 0, y: -8, duration: 1.0)
        ])
        start.run(SKAction.wait(forDuration: 0.8)) {
            start.run(SKAction.repeatForever(float))
        }
        
        // 難易度選択UI（スライダー形式）
        setupDifficultySlider()

        // Submit score button
        submitLabel = SKLabelNode(text: "スコアをランキングに反映")
        submitLabel.name = "submit"
        submitLabel.fontName = "Helvetica"
        submitLabel.fontSize = 18
        submitLabel.fontColor = .systemBlue
        submitLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        submitLabel.alpha = 0
        addChild(submitLabel)
        submitLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.5)
        ]))

        // View leaderboard button
        viewLabel = SKLabelNode(text: "ランキングを見る")
        viewLabel.name = "view"
        viewLabel.fontName = "Helvetica"
        viewLabel.fontSize = 18
        viewLabel.fontColor = .systemBlue
        viewLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.17)
        viewLabel.alpha = 0
        addChild(viewLabel)
        viewLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.7),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
    }

    // helper to show temporary feedback
    private func showFeedback(_ text: String) {
        feedbackLabel?.removeFromParent()
        let lbl = SKLabelNode(text: text)
        lbl.fontName = "Helvetica"
        lbl.fontSize = 16
        lbl.fontColor = .darkGray
        lbl.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        lbl.alpha = 0.0
        addChild(lbl)
        feedbackLabel = lbl
        lbl.run(SKAction.sequence([SKAction.fadeIn(withDuration: 0.2), SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 0.3), SKAction.removeFromParent()]))
    }
    
    // MARK: - Difficulty Selector (Swipe Style)
    private func setupDifficultySlider() {
        // タイトル「難易度選択」
        let titleLabel = SKLabelNode(text: "難易度選択")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 20
        titleLabel.fontColor = .black
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.38)
        titleLabel.alpha = 0
        addChild(titleLabel)
        titleLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
        
        let centerY = size.height * 0.33
        
        // 左矢印
        let leftArrowLabel = SKLabelNode(text: "◀")
        leftArrowLabel.name = "leftArrow"
        leftArrowLabel.fontName = "Helvetica-Bold"
        leftArrowLabel.fontSize = 32
        leftArrowLabel.fontColor = .black
        leftArrowLabel.position = CGPoint(x: size.width * 0.25, y: centerY)
        leftArrowLabel.alpha = 0
        addChild(leftArrowLabel)
        leftArrow = leftArrowLabel
        
        // 中央の難易度表示
        let diffLabel = SKLabelNode(text: getDifficultyName(difficulties[currentDifficultyIndex]))
        diffLabel.name = "difficultyDisplay"
        diffLabel.fontName = "Helvetica-Bold"
        diffLabel.fontSize = 28
        diffLabel.fontColor = .black
        diffLabel.horizontalAlignmentMode = .center
        diffLabel.position = CGPoint(x: size.width / 2, y: centerY)
        diffLabel.alpha = 0
        addChild(diffLabel)
        difficultyDisplayLabel = diffLabel
        
        // 右矢印
        let rightArrowLabel = SKLabelNode(text: "▶")
        rightArrowLabel.name = "rightArrow"
        rightArrowLabel.fontName = "Helvetica-Bold"
        rightArrowLabel.fontSize = 32
        rightArrowLabel.fontColor = .black
        rightArrowLabel.position = CGPoint(x: size.width * 0.75, y: centerY)
        rightArrowLabel.alpha = 0
        addChild(rightArrowLabel)
        rightArrow = rightArrowLabel
        
        // アニメーション
        leftArrowLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.3)
        ]))
        diffLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.3)
        ]))
        rightArrowLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.3)
        ]))
        
        // 矢印の有効/無効を更新
        updateArrowVisibility()
    }
    
    private func getDifficultyName(_ seconds: Int) -> String {
        switch seconds {
        case 5: return "プロ"
        case 7: return "上級"
        case 10: return "中級"
        case 13: return "初級"
        default: return "\(seconds)秒"
        }
    }
    
    private func updateArrowVisibility() {
        // 左端にいる場合は左矢印を薄く、右端にいる場合は右矢印を薄く
        leftArrow?.alpha = (currentDifficultyIndex > 0) ? 1.0 : 0.3
        rightArrow?.alpha = (currentDifficultyIndex < difficulties.count - 1) ? 1.0 : 0.3
    }
    
    private func changeDifficulty(direction: Int) {
        let newIndex = currentDifficultyIndex + direction
        guard newIndex >= 0 && newIndex < difficulties.count else { return }
        
        currentDifficultyIndex = newIndex
        selectedDifficulty = difficulties[currentDifficultyIndex]
        UserDefaults.standard.set(selectedDifficulty, forKey: "selectedDifficulty")
        
        // アニメーションで更新
        if let label = difficultyDisplayLabel {
            let direction = CGFloat(direction)
            let slideOut = SKAction.group([
                SKAction.moveBy(x: -direction * 50, y: 0, duration: 0.15),
                SKAction.fadeOut(withDuration: 0.15)
            ])
            let updateText = SKAction.run {
                label.text = self.getDifficultyName(self.selectedDifficulty)
                label.position.x = self.size.width / 2 + direction * 50
            }
            let slideIn = SKAction.group([
                SKAction.moveBy(x: -direction * 50, y: 0, duration: 0.15),
                SKAction.fadeIn(withDuration: 0.15)
            ])
            
            label.run(SKAction.sequence([slideOut, updateText, slideIn]))
        }
        
        updateArrowVisibility()
    }

    private func updateDifficultySelection() {
        // スワイプ形式では不要
    }

    private func showLeaderboard(_ entries: [RankingEntry]) {
        // 既存のランキング要素をクリア
        for n in leaderboardNodes { n.removeFromParent() }
        leaderboardNodes.removeAll()
        closeLabel?.removeFromParent()
        rankingOverlay?.removeFromParent()
        for btn in rankingDifficultyButtons { btn.removeFromParent() }
        rankingDifficultyButtons.removeAll()
        
        // 他のUI要素を隠す
        hideMainUI()
        
        // 半透明の背景オーバーレイ
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.fillColor = UIColor(white: 0, alpha: 0.85)
        overlay.strokeColor = .clear
        overlay.zPosition = 1000
        addChild(overlay)
        rankingOverlay = overlay
        
        // ランキングタイトル
        let titleLabel = SKLabelNode(text: "ランキング")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        titleLabel.zPosition = 1001
        addChild(titleLabel)
        leaderboardNodes.append(titleLabel)
        
        // 難易度選択ボタン（横並び）
        let diffButtonY = size.height * 0.78
        let buttonWidth: CGFloat = 70
        let buttonSpacing: CGFloat = 10
        let totalWidth = buttonWidth * 4 + buttonSpacing * 3
        let startX = (size.width - totalWidth) / 2
        
        let diffOptions = [(13, "初級"), (10, "中級"), (7, "上級"), (5, "プロ")]
        for (index, (diff, name)) in diffOptions.enumerated() {
            let button = SKLabelNode(text: name)
            button.name = "rankDiff_\(diff)"
            button.fontName = "Helvetica-Bold"
            button.fontSize = 16
            button.fontColor = (diff == currentRankingDifficulty) ? .systemYellow : .lightGray
            button.horizontalAlignmentMode = .center
            button.position = CGPoint(x: startX + buttonWidth / 2 + CGFloat(index) * (buttonWidth + buttonSpacing), y: diffButtonY)
            button.zPosition = 1001
            addChild(button)
            rankingDifficultyButtons.append(button)
        }
        
        // ランキングリスト
        let startY = size.height * 0.68
        var y = startY
        var index = 1
        
        if entries.isEmpty {
            let emptyLabel = SKLabelNode(text: "まだランキングがありません")
            emptyLabel.fontName = "Helvetica"
            emptyLabel.fontSize = 18
            emptyLabel.fontColor = .lightGray
            emptyLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            emptyLabel.zPosition = 1001
            addChild(emptyLabel)
            leaderboardNodes.append(emptyLabel)
        } else {
            for e in entries {
                let formattedScore = formatNumber(e.score)
                let text = "\(index). \(e.name ?? "Player") - \(formattedScore)"
                let lbl = SKLabelNode(text: text)
                lbl.fontName = "Helvetica"
                lbl.fontSize = 18
                lbl.fontColor = .white
                lbl.position = CGPoint(x: size.width / 2, y: y)
                lbl.zPosition = 1001
                addChild(lbl)
                leaderboardNodes.append(lbl)
                y -= 32
                index += 1
            }
        }
        
        // Closeボタン
        let close = SKLabelNode(text: "閉じる")
        close.name = "close"
        close.fontName = "Helvetica-Bold"
        close.fontSize = 22
        close.fontColor = .systemRed
        close.position = CGPoint(x: size.width / 2, y: size.height * 0.10)
        close.zPosition = 1001
        addChild(close)
        closeLabel = close
    }
    
    private func hideMainUI() {
        // メインUI要素を非表示
        childNode(withName: "start")?.alpha = 0
        submitLabel?.alpha = 0
        viewLabel?.alpha = 0
        difficultyDisplayLabel?.alpha = 0
        leftArrow?.alpha = 0
        rightArrow?.alpha = 0
        enumerateChildNodes(withName: "//*") { node, _ in
            if node.name == "difficultyDisplay" || node.name?.contains("Arrow") == true {
                node.alpha = 0
            }
        }
    }
    
    private func showMainUI() {
        // メインUI要素を再表示
        childNode(withName: "start")?.alpha = 1.0
        submitLabel?.alpha = 1.0
        viewLabel?.alpha = 1.0
        difficultyDisplayLabel?.alpha = 1.0
        leftArrow?.alpha = (currentDifficultyIndex > 0) ? 1.0 : 0.3
        rightArrow?.alpha = (currentDifficultyIndex < difficulties.count - 1) ? 1.0 : 0.3
        enumerateChildNodes(withName: "//*") { node, _ in
            if node.name == "difficultyDisplay" || node.name?.contains("Arrow") == true {
                if node.name == "leftArrow" {
                    node.alpha = (self.currentDifficultyIndex > 0) ? 1.0 : 0.3
                } else if node.name == "rightArrow" {
                    node.alpha = (self.currentDifficultyIndex < self.difficulties.count - 1) ? 1.0 : 0.3
                } else {
                    node.alpha = 1.0
                }
            }
        }
    }
    
    private func closeLeaderboard() {
        for n in leaderboardNodes { n.removeFromParent() }
        leaderboardNodes.removeAll()
        closeLabel?.removeFromParent()
        closeLabel = nil
        rankingOverlay?.removeFromParent()
        rankingOverlay = nil
        for btn in rankingDifficultyButtons { btn.removeFromParent() }
        rankingDifficultyButtons.removeAll()
        
        // メインUIを再表示
        showMainUI()
    }
    
    private func fetchAndShowRanking(difficulty: Int) {
        RankingsManager.shared.setup { [weak self] err in
            guard let self = self else { return }
            if let e = err {
                print("Auth error: \(e)")
                DispatchQueue.main.async { self.showFeedback("Auth failed") }
                return
            }
            RankingsManager.shared.fetchTop(difficulty: difficulty, limit: 10) { entries, err in
                DispatchQueue.main.async {
                    if let e = err {
                        self.showFeedback("Fetch failed")
                        print("fetch error: \(e)")
                    } else {
                        self.showLeaderboard(entries ?? [])
                    }
                }
            }
        }
    }
    
    private func updateRankingDifficultyButtons() {
        for button in rankingDifficultyButtons {
            if let name = button.name, name.hasPrefix("rankDiff_") {
                let diffStr = name.replacingOccurrences(of: "rankDiff_", with: "")
                if let diff = Int(diffStr) {
                    button.fontColor = (diff == currentRankingDifficulty) ? .systemYellow : .lightGray
                }
            }
        }
    }

    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }

    // touch handling
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        let nodesAt = nodes(at: p)
        
        // 左矢印タップ
        if nodesAt.contains(where: { $0.name == "leftArrow" }) {
            if currentDifficultyIndex > 0 {
                changeDifficulty(direction: -1)
            }
            return
        }
        
        // 右矢印タップ
        if nodesAt.contains(where: { $0.name == "rightArrow" }) {
            if currentDifficultyIndex < difficulties.count - 1 {
                changeDifficulty(direction: 1)
            }
            return
        }
        
        // ランキング難易度切り替え
        for node in nodesAt {
            if let name = node.name, name.hasPrefix("rankDiff_") {
                let diffStr = name.replacingOccurrences(of: "rankDiff_", with: "")
                if let diff = Int(diffStr) {
                    currentRankingDifficulty = diff
                    updateRankingDifficultyButtons()
                    fetchAndShowRanking(difficulty: diff)
                }
                return
            }
        }
        
        if nodesAt.contains(where: { $0.name == "start" }) {
            // BGMを停止してからゲーム画面へ
            AudioManager.shared.stopBGM()
            let scene = GameScene(size: size)
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.4))
            return
        }

        if nodesAt.contains(where: { $0.name == "submit" }) {
            // submit last score from UserDefaults
            let last = UserDefaults.standard.integer(forKey: "lastScore")
            if last == 0 {
                showFeedback("No score to submit")
                return
            }
            
            // ユーザーネームを取得または入力
            self.promptForUsername { [weak self] username in
                guard let self = self, let username = username else {
                    self?.showFeedback("名前が入力されていません")
                    return
                }
                
                // リワード広告を表示
                guard let viewController = self.view?.window?.rootViewController else {
                    self.showFeedback("エラーが発生しました")
                    return
                }
                
                // 広告が準備できていない場合は読み込んで少し待つ
                self.showAdAndSubmitScore(viewController: viewController, score: last, username: username)
            }
            return
        }

        if nodesAt.contains(where: { $0.name == "view" }) {
            // 現在選択中の難易度のランキングを表示
            currentRankingDifficulty = selectedDifficulty
            fetchAndShowRanking(difficulty: selectedDifficulty)
            return
        }

        if nodesAt.contains(where: { $0.name == "close" }) {
            closeLeaderboard()
            return
        }

        // debug dot

        // debug dot
        if let t = touches.first {
            let p = t.location(in: self)
            let dot = SKShapeNode(circleOfRadius: 8)
            dot.fillColor = .darkGray
            dot.strokeColor = .clear
            dot.position = p
            dot.zPosition = 1000
            addChild(dot)
            dot.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.35), SKAction.removeFromParent()]))
        }
    }

    // MARK: - Username Management
    private func promptForUsername(completion: @escaping (String?) -> Void) {
        // 既存のユーザーネームを確認
        let savedUsername = UserDefaults.standard.string(forKey: "username")
        
        guard let viewController = self.view?.window?.rootViewController else {
            completion(nil)
            return
        }
        
        let alert = UIAlertController(
            title: "ユーザーネーム",
            message: savedUsername != nil ? "現在: \(savedUsername!)\n変更する場合は新しい名前を入力してください" : "ランキングに表示される名前を入力してください",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "名前を入力"
            textField.text = savedUsername
        }
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in
            completion(nil)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            if let username = alert.textFields?.first?.text, !username.isEmpty {
                // 保存
                UserDefaults.standard.set(username, forKey: "username")
                completion(username)
            } else if let saved = savedUsername {
                // 既存の名前を使用
                completion(saved)
            } else {
                completion(nil)
            }
        })
        
        viewController.present(alert, animated: true)
    }
    
    private func showAdAndSubmitScore(viewController: UIViewController, score: Int, username: String) {
        AdMobManager.shared.showRewardedAd(from: viewController) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                // 広告視聴完了、スコアを送信
                self.submitScore(score, username: username)
            } else {
                // 広告視聴失敗またはキャンセル
                DispatchQueue.main.async {
                    self.showFeedback("広告の視聴が必要です")
                }
            }
        }
    }
    
    private func submitScore(_ score: Int, username: String) {
        // 最後にプレイした難易度を取得
        let lastDifficulty = UserDefaults.standard.integer(forKey: "lastPlayedDifficulty")
        let difficulty = (lastDifficulty > 0) ? lastDifficulty : selectedDifficulty
        
        RankingsManager.shared.setup { [weak self] err in
            guard let self = self else { return }
            
            if let e = err {
                print("Auth error: \(e)")
                DispatchQueue.main.async {
                    self.showFeedback("認証に失敗しました")
                }
                return
            }
            
            RankingsManager.shared.submitScore(score, difficulty: difficulty, name: username) { e in
                DispatchQueue.main.async {
                    if let e = e {
                        self.showFeedback("送信に失敗しました")
                        print("submit error: \(e)")
                    } else {
                        self.showFeedback("スコアを送信しました！")
                        // スコアをクリア
                        UserDefaults.standard.set(0, forKey: "lastScore")
                    }
                }
            }
        }
    }

    private func setupVideoBackground() {
        guard let videoURL = Bundle.main.url(forResource: "pazzlegame_opening2", withExtension: "mp4") else {
            print("[OpeningScene] Video file not found, using fallback background")
            setupFallbackBackground()
            return
        }
        
        let player = AVPlayer(url: videoURL)
        videoNode = SKVideoNode(avPlayer: player)
        guard let video = videoNode else { return }
        
        video.size = CGSize(width: size.width, height: size.height)
        video.position = CGPoint(x: size.width / 2, y: size.height / 2)
        video.zPosition = -200
        addChild(video)
        video.play()
        
        // Loop video
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil) { [weak player] _ in
            player?.seek(to: CMTime.zero)
            player?.play()
        }
    }
    
    private func setupFallbackBackground() {
        // Fallback gradient background if video fails
        let gradientPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let bgGradient = SKShapeNode(path: gradientPath.cgPath)
        bgGradient.fillColor = UIColor(red: 0.88, green: 0.93, blue: 1.0, alpha: 1.0)
        bgGradient.strokeColor = .clear
        bgGradient.zPosition = -200
        bgGradient.blendMode = .replace
        addChild(bgGradient)
    }
}
