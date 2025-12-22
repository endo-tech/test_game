import SpriteKit
import AVFoundation

class OpeningScene: SKScene {
    private var submitLabel: SKLabelNode!
    private var viewLabel: SKLabelNode!
    private var feedbackLabel: SKLabelNode?
    private var leaderboardNodes: [SKLabelNode] = []
    private var closeLabel: SKLabelNode?
    private var videoNode: SKVideoNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupVideoBackground()

        // Start button with animation
        let start = SKLabelNode(text: "ゲームスタート")
        start.name = "start"
        start.fontName = "Helvetica-Bold"
        start.fontSize = 22
        start.fontColor = UIColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1.0)
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

        // Submit score button
        submitLabel = SKLabelNode(text: "スコアを送信")
        submitLabel.name = "submit"
        submitLabel.fontName = "Helvetica"
        submitLabel.fontSize = 18
        submitLabel.fontColor = .systemBlue
        submitLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.42)
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
        viewLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.37)
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
        lbl.position = CGPoint(x: size.width / 2, y: size.height * 0.34)
        lbl.alpha = 0.0
        addChild(lbl)
        feedbackLabel = lbl
        lbl.run(SKAction.sequence([SKAction.fadeIn(withDuration: 0.2), SKAction.wait(forDuration: 2.0), SKAction.fadeOut(withDuration: 0.3), SKAction.removeFromParent()]))
    }

    private func showLeaderboard(_ entries: [RankingEntry]) {
        // clear existing
        for n in leaderboardNodes { n.removeFromParent() }
        leaderboardNodes.removeAll()
        closeLabel?.removeFromParent()

        let startY = size.height * 0.28
        var y = startY
        var index = 1
        for e in entries {
            let text = "\(index). \(e.name ?? "Player") - \(e.score)"
            let lbl = SKLabelNode(text: text)
            lbl.fontName = "Helvetica"
            lbl.fontSize = 16
            lbl.fontColor = .black
            lbl.position = CGPoint(x: size.width / 2, y: y)
            addChild(lbl)
            leaderboardNodes.append(lbl)
            y -= 26
            index += 1
        }

        let close = SKLabelNode(text: "Close")
        close.name = "close"
        close.fontName = "Helvetica-Bold"
        close.fontSize = 16
        close.fontColor = .systemBlue
        close.position = CGPoint(x: size.width / 2, y: y - 10)
        addChild(close)
        closeLabel = close
    }

    // touch handling
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        let nodesAt = nodes(at: p)
        if nodesAt.contains(where: { $0.name == "start" }) {
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
                if !AdMobManager.shared.isReady {
                    self.showFeedback("広告を読み込んでいます...")
                    AdMobManager.shared.loadRewardedAd()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if AdMobManager.shared.isReady {
                            self.showAdAndSubmitScore(viewController: viewController, score: last, username: username)
                        } else {
                            self.showFeedback("広告の読み込みに失敗しました")
                        }
                    }
                } else {
                    self.showAdAndSubmitScore(viewController: viewController, score: last, username: username)
                }
            }
            return
        }

        if nodesAt.contains(where: { $0.name == "view" }) {
            RankingsManager.shared.setup { err in
                if let e = err {
                    print("Auth error: \(e)")
                    DispatchQueue.main.async { self.showFeedback("Auth failed") }
                    return
                }
                RankingsManager.shared.fetchTop(limit: 10) { entries, err in
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
            return
        }

        if nodesAt.contains(where: { $0.name == "close" }) {
            for n in leaderboardNodes { n.removeFromParent() }
            leaderboardNodes.removeAll()
            closeLabel?.removeFromParent()
            closeLabel = nil
            return
        }

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
        RankingsManager.shared.setup { [weak self] err in
            guard let self = self else { return }
            
            if let e = err {
                print("Auth error: \(e)")
                DispatchQueue.main.async {
                    self.showFeedback("認証に失敗しました")
                }
                return
            }
            
            RankingsManager.shared.submitScore(score, name: username) { e in
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
