//
//  AdMobManager.swift
//  test_game
//
//  Created on 2025/12/17.
//

import UIKit
import GoogleMobileAds

@MainActor
class AdMobManager: NSObject {
    static let shared = AdMobManager()
    
    private var rewardedAd: RewardedAd?
    private var interstitialAd: InterstitialAd?
    private var completionHandler: ((Bool) -> Void)?
    
    // テスト用広告ユニットID
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313" // テスト用リワード広告ID
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // テスト用インタースティシャル広告ID
    
    // ゲーム回数カウント
    private var gameCount: Int {
        get { UserDefaults.standard.integer(forKey: "gameCount") }
        set { UserDefaults.standard.set(newValue, forKey: "gameCount") }
    }
    
    private override init() {
        super.init()
    }
    
    // AdMob初期化
    func initialize() {
        MobileAds.shared.start { status in
            print("AdMob initialized: \(status.adapterStatusesByClassName)")
        }
        // 両方の広告を事前読み込み
        loadRewardedAd()
        loadInterstitialAd()
    }
    
    // リワード広告を読み込む
    func loadRewardedAd() {
        let request = Request()
        RewardedAd.load(with: rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded ad: \(error.localizedDescription)")
                self?.rewardedAd = nil
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            print("Rewarded ad loaded successfully")
        }
    }
    
    // インタースティシャル広告を読み込む
    func loadInterstitialAd() {
        let request = Request()
        InterstitialAd.load(with: interstitialAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
                self?.interstitialAd = nil
                return
            }
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            print("Interstitial ad loaded successfully")
        }
    }
    
    // ゲーム終了時に呼び出す（3回に1回広告を表示）
    func onGameEnd(from viewController: UIViewController, completion: @escaping () -> Void) {
        gameCount += 1
        
        // 3ゲームごとに広告を表示
        if gameCount % 3 == 0 {
            showInterstitialAd(from: viewController, completion: completion)
        } else {
            completion()
        }
    }
    
    // インタースティシャル広告を表示
    private func showInterstitialAd(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let interstitialAd = interstitialAd else {
            print("Interstitial ad is not ready")
            completion()
            // 次回用に新しい広告を読み込む
            loadInterstitialAd()
            return
        }
        
        self.completionHandler = { _ in
            completion()
        }
        
        interstitialAd.present(from: viewController)
    }
    
    // リワード広告を表示
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        self.completionHandler = completion
        
        guard let rewardedAd = rewardedAd else {
            print("Rewarded ad is not ready")
            completion(false)
            return
        }
        
        rewardedAd.present(from: viewController) { [weak self] in
            print("User earned reward")
            self?.completionHandler?(true)
            self?.completionHandler = nil
            // 次回用に新しい広告を読み込む
            self?.loadRewardedAd()
        }
    }
    
    // 広告が読み込み済みかチェック
    var isReady: Bool {
        return rewardedAd != nil
    }
}

// MARK: - FullScreenContentDelegate
extension AdMobManager: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Failed to present ad: \(error.localizedDescription)")
        completionHandler?(false)
        completionHandler = nil
        // 次回用に新しい広告を読み込む
        loadRewardedAd()
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will present full screen content")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad did dismiss full screen content")
        // ユーザーが報酬を受け取らずに閉じた場合
        if completionHandler != nil {
            completionHandler?(false)
            completionHandler = nil
        }
        // 次回用に新しい広告を読み込む
        loadRewardedAd()
    }
}
