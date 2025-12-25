import Foundation
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()
    
    private var bgmPlayer: AVAudioPlayer?
    private var soundEffectPlayers: [String: AVAudioPlayer] = [:]
    
    private var isBGMEnabled = true
    private var isSoundEffectEnabled = true
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - BGM
    
    func playBGM(_ filename: String, loop: Bool = true) {
        guard isBGMEnabled else { return }
        
        stopBGM()
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("BGM file not found: \(filename)")
            return
        }
        
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = loop ? -1 : 0
            bgmPlayer?.volume = 0.3
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
            print("Playing BGM: \(filename)")
        } catch {
            print("Failed to play BGM: \(error)")
        }
    }
    
    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }
    
    func pauseBGM() {
        bgmPlayer?.pause()
    }
    
    func resumeBGM() {
        guard isBGMEnabled else { return }
        bgmPlayer?.play()
    }
    
    func setBGMVolume(_ volume: Float) {
        bgmPlayer?.volume = max(0.0, min(1.0, volume))
    }
    
    // MARK: - Sound Effects
    
    func playSoundEffect(_ filename: String, volume: Float = 0.5) {
        guard isSoundEffectEnabled else { return }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil) else {
            print("Sound effect file not found: \(filename)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = max(0.0, min(1.0, volume))
            player.prepareToPlay()
            player.play()
            
            // 複数の効果音を同時に鳴らせるように保持
            soundEffectPlayers[filename] = player
            
            // 再生終了後にクリーンアップ
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self] in
                self?.soundEffectPlayers.removeValue(forKey: filename)
            }
        } catch {
            print("Failed to play sound effect: \(error)")
        }
    }
    
    // MARK: - Settings
    
    func setBGMEnabled(_ enabled: Bool) {
        isBGMEnabled = enabled
        if !enabled {
            stopBGM()
        }
    }
    
    func setSoundEffectEnabled(_ enabled: Bool) {
        isSoundEffectEnabled = enabled
    }
    
    func setAllAudioEnabled(_ enabled: Bool) {
        setBGMEnabled(enabled)
        setSoundEffectEnabled(enabled)
    }
}
