import AVFoundation
import UIKit

/// Short sound effects from App/Resources/Sounds. There is no spoken voice in the app on purpose:
/// never add system text-to-speech. If a game needs a voice, ship recorded audio files.
enum SFX: String, CaseIterable {
    case pop, ding, sparkle, crack, fanfare, whoosh, tap, boing, hatch
    case note1, note2, note3, note4, catchIt = "catch", bubble, flip, cheer
    case coin, till
}

final class Sound {
    static let shared = Sound()

    private var players: [SFX: [AVAudioPlayer]] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
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

    func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
