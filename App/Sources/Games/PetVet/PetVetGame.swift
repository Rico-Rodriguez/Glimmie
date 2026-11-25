import AVFoundation
import SwiftUI

// MARK: - Pet Vet (a game in the drawer)
//
// Cute animal patients wait in the waiting room with silly problems (mud, thorns, a scrape, a cold,
// a toothache, bugs, an itchy rash, a tummy ache, a sore foot, leaves in their fur). She picks one,
// then drags tools from the shelves onto them to heal them, and pampers them with treats, bows,
// sparkle spray and a tickle feather. Faces react to everything. All 16 patients and 20 tools are
// open from the start. No voice: sounds are tones made by tools/petvet/make_sounds.py.

enum PetVetGame {
    static let id = "petvet"
    static let healRewardCoins = 5

    static let entry = GameEntry(
        id: id,
        title: "Pet Vet",
        tint: Color(hex: 0x9FE3CF),
        icon: { AnyView(PetVetTileIcon()) },
        play: { exit in AnyView(PetVetView(exit: exit)) },
        stickers: PetVetFind.stickers
    )
}

private struct PetVetTileIcon: View {
    var body: some View {
        ZStack {
            VetPatientPicture(animal: "puppy", face: .wow,
                              stickers: [VetSticker(prop: "bandage", x: 410, y: 205, scale: 0.9, rotation: 10),
                                         VetSticker(prop: "bow0", x: 300, y: 150, scale: 0.9)])
                .padding(-8)
            VetToolPicture(tool: .stethoscope)
                .frame(width: 110, height: 110)
                .rotationEffect(.degrees(-14))
                .offset(x: 92, y: 84)
        }
    }
}

// MARK: - Sounds

enum VetSFX: String, CaseIterable {
    case scrub, splash, pluck, squeak, heartbeat, sneeze, nom, giggle, spray, sticker
    case zip, brr, beep, healed, hop, ouch, swish, bugjump
}

/// Pet Vet's own effects, from App/Resources/Games/PetVet. Shared effects still go through `Sound`.
final class VetSound {
    static let shared = VetSound()
    private var players: [VetSFX: [AVAudioPlayer]] = [:]
    private var last: [String: Date] = [:]

    private init() {
        _ = Sound.shared // sets up the audio session
        for s in VetSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "PetVet") else { continue }
            players[s] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    func play(_ s: VetSFX, volume: Float = 0.9, gap: Double = 0) {
        if gap > 0 {
            let now = Date()
            if let t = last[s.rawValue], now.timeIntervalSince(t) < gap { return }
            last[s.rawValue] = now
        }
        guard let pool = players[s], !pool.isEmpty else { return }
        let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }

    /// A shared effect, throttled.
    func play(_ s: SFX, volume: Float = 0.8, gap: Double) {
        let now = Date()
        if let t = last["shared." + s.rawValue], now.timeIntervalSince(t) < gap { return }
        last["shared." + s.rawValue] = now
        Sound.shared.play(s, volume: volume)
    }
}

// MARK: - The clinic (saved state)

final class VetClinic: ObservableObject {
    @Published private(set) var save: VetClinicSave
    let animals: [String]
    private let persist: Bool

    init() {
        let art = VetArt.shared
        animals = art.order
        persist = true
        var s = GameStorage.load(VetClinicSave.self, game: PetVetGame.id, file: "clinic.json") ?? VetClinicSave()
        for a in art.order where s.visits[a] == nil { s.visits[a] = VetVisit.random(animal: a) }
        save = s
    }

    init(save: VetClinicSave, animals: [String] = VetArt.shared.order, persist: Bool = false) {
        self.save = save
        self.animals = animals
        self.persist = persist
    }

    func visit(_ animal: String) -> VetVisit { save.visits[animal] ?? VetVisit(animal: animal, spots: []) }
    func stickers(_ animal: String) -> [VetSticker] { save.stickers[animal] ?? [] }
    func healedCount(_ animal: String) -> Int { save.healed[animal] ?? 0 }
    var totalHealed: Int { save.healed.values.reduce(0, +) }

    /// Ensures a patient has an initialized visit without re-sickening an already-healed patient.
    func checkIn(_ animal: String) {
        if save.visits[animal] == nil || visit(animal).spots.isEmpty {
            save.visits[animal] = VetVisit.random(animal: animal)
            save.stickers[animal] = stickers(animal).filter { $0.prop.hasPrefix("bow") }
            store()
        }
    }

    /// Explicitly starts a fresh checkup with new ailments; keeps bows and removes old bandages/casts.
    @discardableResult
    func startNewVisit(for animal: String) -> VetVisit {
        let fresh = VetVisit.random(animal: animal)
        save.visits[animal] = fresh
        save.stickers[animal] = stickers(animal).filter { $0.prop.hasPrefix("bow") }
        store()
        return fresh
    }

    func update(_ v: VetVisit) { save.visits[v.animal] = v }

    func setStickers(_ list: [VetSticker], for animal: String) {
        save.stickers[animal] = Array(list.suffix(12))
        store()
    }

    func recordHealed(_ animal: String) {
        save.healed[animal, default: 0] += 1
        store()
    }

    @discardableResult
    func completeVisit(for animal: String, visit: VetVisit, coinOrigin: CGPoint = CGPoint(x: 512, y: 360)) -> Int {
        update(visit)
        recordHealed(animal)
        let reward = PetVetGame.healRewardCoins
        Coins.shared.earn(reward, game: PetVetGame.id, from: coinOrigin)
        let finds = PetVetFind.visitUnlocks(
            for: visit,
            totalHealed: totalHealed,
            uniqueHealed: save.healed.count
        )
        for find in finds {
            unlock(find)
        }
        return reward
    }

    func unlock(_ find: PetVetFind) {
        StickerBook.shared.find(game: PetVetGame.id, id: find.rawValue)
    }

    func store() {
        guard persist else { return }
        GameStorage.save(save, game: PetVetGame.id, file: "clinic.json")
    }
}

// MARK: - Root

struct PetVetView: View {
    let exit: () -> Void
    @StateObject private var clinic = VetClinic()
    @State private var patient: String? = PetVetView.launchPatient
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            if let p = patient {
                VetExamView(clinic: clinic, animal: p, onExit: exit, onBack: { go(nil) })
                    .id(p)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            } else {
                VetLobbyView(clinic: clinic, onExit: exit, onPick: { go($0) })
                    .transition(.opacity)
            }
        }
        .background(Color(hex: 0xE7F7F1).ignoresSafeArea())
        .onAppear {
            _ = VetSound.shared
            if let p = patient { clinic.checkIn(p) }
        }
        .onChange(of: phase) { p in if p != .active { clinic.store() } }
    }

    private func go(_ p: String?) {
        if let p { clinic.checkIn(p) } else { clinic.store() }
        withAnimation(.easeInOut(duration: 0.35)) { patient = p }
    }

    /// `-vetPatient <animal>` opens that patient straight away (used for simulator screenshots).
    static var launchPatient: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-vetPatient"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
