import AVFoundation
import UIKit

/// Short sound effects from App/Resources/Sounds. There is no spoken voice in the app on purpose:
/// never add system text-to-speech. If a game needs a voice, ship recorded audio files.
enum SFX: String, CaseIterable {
    case pop, ding, sparkle, crack, fanfare, whoosh, tap, boing
    case note1, note2, note3, note4, bubble, flip, cheer
    case coin, till
}

final class Sound {
    static let shared = Sound()
    private static let maxPoolSize = 3

    private let queue = DispatchQueue(label: "glimmie.sound", qos: .userInitiated)
    private var players: [SFX: [AVAudioPlayer]] = [:]
    private var missing: Set<SFX> = []
    private var haptics: UIImpactFeedbackGenerator?

    static func url(for s: SFX) -> URL? {
        Bundle.main.url(forResource: s.rawValue, withExtension: "caf")
            ?? Bundle.main.url(forResource: s.rawValue, withExtension: "wav")
    }

    private init() {
        queue.async {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    func play(_ s: SFX, volume: Float = 1) {
        queue.async {
            guard let p = self.player(for: s) else { return }
            p.volume = volume
            p.currentTime = 0
            p.play()
        }
    }

    private func player(for s: SFX) -> AVAudioPlayer? {
        guard !missing.contains(s) else { return nil }
        let pool = players[s] ?? []
        if let idle = pool.first(where: { !$0.isPlaying }) { return idle }
        if pool.count < Self.maxPoolSize {
            if let created = makePlayer(for: s) {
                players[s] = pool + [created]
                return created
            }
            if pool.isEmpty { missing.insert(s) }
        }
        return pool.max(by: { $0.currentTime < $1.currentTime }) ?? pool.first
    }

    private func makePlayer(for s: SFX) -> AVAudioPlayer? {
        guard let url = Self.url(for: s),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    func tap() {
        if Thread.isMainThread {
            triggerTap()
        } else {
            DispatchQueue.main.async { self.triggerTap() }
        }
    }

    private func triggerTap() {
        let gen = haptics ?? UIImpactFeedbackGenerator(style: .soft)
        if haptics == nil { haptics = gen }
        gen.impactOccurred()
        gen.prepare()
    }
}
