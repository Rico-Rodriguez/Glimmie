import AVFoundation
import UIKit

enum SFX: String, CaseIterable {
    case pop, ding, sparkle, crack, fanfare, whoosh, tap, boing, hatch
    case note1, note2, note3, note4, catchIt = "catch", bubble, flip, cheer
}

/// Short synthesized sound effects (App/Resources/Sounds) + a friendly voice.
final class Sound {
    static let shared = Sound()

    private var players: [SFX: [AVAudioPlayer]] = [:]
    private let voice = AVSpeechSynthesizer()
    private lazy var voiceChoice: AVSpeechSynthesisVoice? = {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        // Prefer an enhanced/premium voice when one is installed, else the default en-US voice.
        if let best = english.filter({ $0.language == "en-US" }).max(by: { $0.quality.rawValue < $1.quality.rawValue }),
           best.quality != .default { return best }
        return AVSpeechSynthesisVoice(language: "en-US") ?? english.first
    }()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for s in SFX.allCases {
            guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav") else { continue }
            players[s] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    func play(_ s: SFX, volume: Float = 1) {
        guard let pool = players[s] else { return }
        let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }

    func say(_ text: String, interrupt: Bool = true) {
        if interrupt, voice.isSpeaking { voice.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = voiceChoice
        u.rate = 0.42
        u.pitchMultiplier = 1.25
        u.preUtteranceDelay = 0.05
        voice.speak(u)
    }

    func tapHaptic() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
