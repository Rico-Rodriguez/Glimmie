import AVFoundation
import SwiftUI
import UIKit

// MARK: - Tidy Up (a game in the drawer)
//
// A cozy put-things-away game. Each level is a piece of furniture (a fridge, a bookshelf, a cutlery drawer,
// a closet, toy cubbies, a sock drawer, a backpack, a pencil case, a pantry, a fruit crate...) and a moving
// box that tosses its things onto the floor. She drags each thing to the spot it fits: soft ghost shapes
// show where, colored ghosts mean "this color goes here", and stacks fill from the bottom. Things fall,
// bounce, roll and rest on each other (TidyWorld.swift), swing as she carries them, get pulled into a
// slot when close, and land with a squash, a click that matches what they're made of and a sparkle.
// 24 levels, all open. Calm music loops while she plays (button to turn it off). No words, no voice.
//
// Sounds and music: tools/tidy/sounds.py -> App/Resources/Games/Tidy/*.wav, calm.m4a.

enum TidyGame {
    static let id = "tidy"
    static let entry = GameEntry(
        id: id,
        title: "Tidy Up",
        tint: Color(hex: 0xC9B6FF),
        icon: { AnyView(TidyTileIcon()) },
        play: { exit in AnyView(TidyGameView(exit: exit)) },
        stickers: TidyFind.stickers
    )
}

// MARK: - Saves

final class TidyStore: ObservableObject {
    struct Save: Codable {
        var done: [String]
        var music: Bool
    }

    @Published var done: Set<String> = []
    @Published var music = true

    init() {
        if let s = GameStorage.load(Save.self, game: TidyGame.id, file: "progress.json") {
            done = Set(s.done)
            music = s.music
        }
    }

    func save() {
        GameStorage.save(Save(done: done.sorted(), music: music), game: TidyGame.id, file: "progress.json")
    }
}

// MARK: - Sounds

enum TidySFX: String, CaseIterable {
    case pickup, boop, pop, whoosh, chime, clink, tink, tok, thud, click, pat, plunk
}

/// Tidy Up's own effects and music, from App/Resources/Games/Tidy. Effects can be pitched (`rate`)
/// so a run of things put away climbs up a little scale.
final class TidySound {
    static let shared = TidySound()
    private let queue = DispatchQueue(label: "glimmie.tidy.sound", qos: .userInitiated)
    private var players: [TidySFX: [AVAudioPlayer]] = [:]
    private var music: AVAudioPlayer?
    private var light: UIImpactFeedbackGenerator?
    private var soft: UIImpactFeedbackGenerator?
    private var rigid: UIImpactFeedbackGenerator?
    private var note: UINotificationFeedbackGenerator?

    private init() {
        _ = Sound.shared // sets up the audio session
    }

    static func url(for s: TidySFX) -> URL? {
        GameFiles.url(s.rawValue, "caf", game: "Tidy") ?? GameFiles.url(s.rawValue, "wav", game: "Tidy")
    }

    func play(_ s: TidySFX, volume: Float = 1, rate: Float = 1) {
        queue.async {
            let pool: [AVAudioPlayer]
            if let existing = self.players[s] {
                pool = existing
            } else if let url = Self.url(for: s) {
                let created: [AVAudioPlayer] = (0..<4).compactMap { _ in
                    let p = try? AVAudioPlayer(contentsOf: url)
                    p?.enableRate = true
                    p?.prepareToPlay()
                    return p
                }
                self.players[s] = created
                pool = created
            } else {
                self.players[s] = []
                return
            }
            guard !pool.isEmpty else { return }
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = volume
            p.rate = max(0.5, min(2, rate))
            p.currentTime = 0
            p.play()
        }
    }

    /// The sound of a thing landing, by what it's made of.
    func place(_ m: TidyMaterial, volume: Float = 0.85, rate: Float = 1) {
        let s: TidySFX
        switch m {
        case .ceramic, .glass: s = .clink
        case .metal: s = .tink
        case .wood: s = .tok
        case .plush: s = .thud
        case .plastic: s = .click
        case .paper: s = .pat
        case .food: s = .plunk
        }
        play(s, volume: volume, rate: rate)
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let fire = {
            switch style {
            case .soft:
                let g = self.soft ?? UIImpactFeedbackGenerator(style: .soft)
                if self.soft == nil { self.soft = g }
                g.impactOccurred()
                g.prepare()
            case .rigid:
                let g = self.rigid ?? UIImpactFeedbackGenerator(style: .rigid)
                if self.rigid == nil { self.rigid = g }
                g.impactOccurred(intensity: 0.8)
                g.prepare()
            default:
                let g = self.light ?? UIImpactFeedbackGenerator(style: .light)
                if self.light == nil { self.light = g }
                g.impactOccurred()
                g.prepare()
            }
        }
        if Thread.isMainThread { fire() } else { DispatchQueue.main.async(execute: fire) }
    }

    func success() {
        let fire = {
            let g = self.note ?? UINotificationFeedbackGenerator()
            if self.note == nil { self.note = g }
            g.notificationOccurred(.success)
            g.prepare()
        }
        if Thread.isMainThread { fire() } else { DispatchQueue.main.async(execute: fire) }
    }

    func startMusic() {
        queue.async {
            if self.music == nil,
               let url = GameFiles.url("calm", "caf", game: "Tidy") ?? GameFiles.url("calm", "m4a", game: "Tidy") {
                self.music = try? AVAudioPlayer(contentsOf: url)
                self.music?.numberOfLoops = -1
                self.music?.prepareToPlay()
            }
            guard let m = self.music else { return }
            if !m.isPlaying {
                m.volume = 0
                m.play()
            }
            m.setVolume(0.42, fadeDuration: 1.5)
        }
    }

    func stopMusic() {
        queue.async {
            guard let m = self.music, m.isPlaying else { return }
            m.setVolume(0, fadeDuration: 0.6)
            self.queue.asyncAfter(deadline: .now() + 0.65) { [weak m] in
                if let m = m, m.volume < 0.05 { m.pause() }
            }
        }
    }
}

// MARK: - Full-bleed room wallpaper backdrop

private struct TidyRoomBackdrop: View {
    let scene: TidyScene

    var body: some View {
        Canvas { ctx, size in
            let map = GameStageMap(size: size)
            var g = ctx
            g.scaleBy(x: map.scale, y: map.scale)
            let logical = CGSize(width: size.width / map.scale, height: size.height / map.scale)
            let floorY = (map.origin.y / map.scale) + (GameChromeLayout.height - 22)
            TidySceneArt.room(scene, g, size: logical, floorY: floorY)
        }
    }
}

// MARK: - Root

private enum TidySession: Equatable {
    case standard(index: Int, round: Int)
    case shuffled(roomIndex: Int, seed: UInt64)

    var roomIndex: Int {
        switch self {
        case .standard(let index, _): return index
        case .shuffled(let roomIndex, _): return roomIndex
        }
    }

    var isInitialRound: Bool {
        if case .standard(_, let round) = self { return round == 0 }
        return false
    }

    var level: TidyLevel {
        switch self {
        case .standard(let index, _): return TidyLevels.all[index]
        case .shuffled(let roomIndex, let seed): return TidyLevels.shuffled(roomIndex: roomIndex, seed: seed)
        }
    }

    var viewID: String {
        switch self {
        case .standard(let index, let round): return "std-\(index)-\(round)"
        case .shuffled(let roomIndex, let seed): return "shuf-\(roomIndex)-\(seed)"
        }
    }
}

struct TidyGameView: View {
    let exit: () -> Void
    @StateObject private var store = TidyStore()
    @State private var session: TidySession?
    @State private var shuffleCounter: UInt64 = 1

    var body: some View {
        ZStack {
            if let active = session {
                let roomIdx = active.roomIndex
                TidyPlayView(
                    level: active.level,
                    roomIndex: roomIdx,
                    allowDemoPrefill: active.isInitialRound,
                    store: store,
                    next: { advance(from: active) },
                    levels: { withAnimation(.easeInOut(duration: 0.35)) { session = nil } },
                    replay: { replayCurrent(active) },
                    shuffle: { startShuffle(roomIndex: roomIdx) },
                    exit: exit
                )
                .id(active.viewID)
                .transition(.opacity)
            } else {
                TidyLevelPicker(
                    store: store,
                    exit: exit,
                    open: { go(to: $0) },
                    openShuffle: { startRandomClearedShuffle() }
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            applyLaunchArguments()
            if store.music { TidySound.shared.startMusic() }
        }
        .onDisappear {
            store.save()
            TidySound.shared.stopMusic()
        }
    }

    private func go(to i: Int) {
        TidySound.shared.play(.whoosh, volume: 0.5)
        withAnimation(.easeInOut(duration: 0.35)) { session = .standard(index: i, round: 0) }
    }

    private func nextSeed() -> UInt64 {
        shuffleCounter &+= 1
        return UInt64.random(in: 1...UInt64.max) ^ (shuffleCounter &* 0x9E37_79B9_7F4A_7C15)
    }

    private func startShuffle(roomIndex: Int) {
        TidySound.shared.play(.whoosh, volume: 0.5)
        let seed = nextSeed()
        withAnimation(.easeInOut(duration: 0.35)) {
            session = .shuffled(roomIndex: roomIndex, seed: seed)
        }
    }

    private func startRandomClearedShuffle() {
        let cleared = TidyLevels.all.indices.filter { store.done.contains(TidyLevels.all[$0].id) }
        let pick = cleared.randomElement() ?? Int.random(in: 0..<TidyLevels.all.count)
        startShuffle(roomIndex: pick)
    }

    private func replayCurrent(_ active: TidySession) {
        switch active {
        case .standard(let index, let round):
            session = .standard(index: index, round: round + 1)
        case .shuffled(let roomIndex, _):
            session = .shuffled(roomIndex: roomIndex, seed: nextSeed())
        }
    }

    private func advance(from active: TidySession) {
        switch active {
        case .standard(let index, _):
            if index + 1 < TidyLevels.all.count {
                go(to: index + 1)
            } else {
                // Past level 24: seamlessly enter endless bonus clutter shuffles!
                startShuffle(roomIndex: Int.random(in: 0..<TidyLevels.all.count))
            }
        case .shuffled(let roomIndex, _):
            startShuffle(roomIndex: (roomIndex + 1) % TidyLevels.all.count)
        }
    }

    /// Simulator screenshot hooks: -tidyLevel <n> opens a level (-tidyPrefill <k>, -tidyHold in TidyPlayView).
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tidyLevel"), i + 1 < args.count, let n = Int(args[i + 1]), TidyLevels.all.indices.contains(n) {
            session = .standard(index: n, round: 0)
        }
        if args.contains("-tidyDemoDone") {
            for l in TidyLevels.all.prefix(9) { store.done.insert(l.id) }
        }
    }
}

// MARK: - Level picker (two pictorial tabs: Rooms 1-12 & Rooms 13-24 + star bar)

private enum TidyPickerPage: Int, CaseIterable {
    case cozy = 0
    case sparkle = 1

    var range: Range<Int> {
        switch self {
        case .cozy: return 0..<12
        case .sparkle: return 12..<24
        }
    }

    var symbol: String {
        switch self {
        case .cozy: return "house.fill"
        case .sparkle: return "sparkles"
        }
    }
}

struct TidyLevelPicker: View {
    @ObservedObject var store: TidyStore
    let exit: () -> Void
    let open: (Int) -> Void
    let openShuffle: () -> Void

    @State private var page: TidyPickerPage = .cozy
    @State private var showBook = false
    @State private var shuffleBob = false

    private var nextUp: Int { TidyLevels.all.firstIndex { !store.done.contains($0.id) } ?? 0 }
    private var allCleared: Bool { TidyLevels.all.allSatisfy { store.done.contains($0.id) } }

    var body: some View {
        ZStack {
            GameStage(background: {
                TidyRoomBackdrop(scene: .bookshelf)
            }) {
                ZStack {
                    VStack(spacing: 0) {
                        Spacer(minLength: 108)
                        let indices = Array(page.range)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(216), spacing: 22), count: 4),
                            spacing: 22
                        ) {
                            ForEach(indices, id: \.self) { i in
                                let level = TidyLevels.all[i]
                                TidyLevelCard(
                                    level: level,
                                    done: store.done.contains(level.id),
                                    glow: i == nextUp
                                ) {
                                    Sound.shared.tap()
                                    open(i)
                                }
                            }
                        }
                        .id(page)
                        .transition(.opacity)
                        Spacer(minLength: 28)
                    }
                    .padding(.horizontal, 28)

                    GameTopBar(
                        gameID: TidyGame.id,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: exit,
                        onStickerBook: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        center: {
                            pickerSwitcherBar
                        },
                        trailing: {
                            HStack(spacing: 12) {
                                if !store.done.isEmpty {
                                    RoundButton(
                                        symbol: "die.face.5.fill",
                                        tint: Color(hex: 0xFFB84D),
                                        size: GameChromeLayout.buttonSize
                                    ) {
                                        Sound.shared.play(.sparkle, volume: 0.5)
                                        Sound.shared.tap()
                                        openShuffle()
                                    }
                                    .scaleEffect(allCleared && shuffleBob ? 1.09 : 1)
                                    .accessibilityLabel("Bonus Shuffle Room")
                                }
                                TidyMusicButton(store: store, size: GameChromeLayout.buttonSize)
                            }
                        }
                    )

                    StickerToast(game: TidyGame.id, target: GameChromeLayout.stickerTarget)
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coinPurse(game: TidyGame.id)
            }

            if showBook {
                StickerBookView(game: TidyGame.id) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            let cozyDone = TidyPickerPage.cozy.range.allSatisfy { store.done.contains(TidyLevels.all[$0].id) }
            if cozyDone { page = .sparkle }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shuffleBob = true
            }
        }
    }

    private var pickerSwitcherBar: some View {
        let pageLevels = Array(TidyLevels.all[page.range])
        return GameTrayCard(cornerRadius: 28, paddingH: 12, paddingV: 7) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(TidyPickerPage.allCases, id: \.self) { tab in
                        let selected = page == tab
                        Button {
                            guard page != tab else { return }
                            Sound.shared.play(.pop, volume: 0.55)
                            Sound.shared.tap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                page = tab
                            }
                        } label: {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(selected ? .white : Theme.ink.opacity(0.6))
                                .frame(width: 52, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(selected ? Theme.pink : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selected ? Theme.pink : Theme.blush, lineWidth: 2)
                                )
                        }
                        .buttonStyle(Squish())
                    }
                }

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.blush)
                    .frame(width: 3, height: 32)

                HStack(spacing: 3) {
                    ForEach(pageLevels) { lvl in
                        let lit = store.done.contains(lvl.id)
                        Image(systemName: lit ? "star.fill" : "star")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(lit ? Theme.lemon : Theme.ink.opacity(0.22))
                            .shadow(color: lit ? Theme.ink.opacity(0.28) : .clear, radius: 1, y: 1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.85)))
            }
        }
    }
}

private struct TidyLevelCard: View {
    let level: TidyLevel
    let done: Bool
    let glow: Bool
    let tap: () -> Void
    @State private var bob = false

    var body: some View {
        Button(action: tap) {
            ZStack(alignment: .topTrailing) {
                Canvas { ctx, size in
                    let k = min(size.width / TidyScene.size.width, size.height / TidyScene.size.height)
                    var c = ctx
                    c.translateBy(x: (size.width - TidyScene.size.width * k) / 2,
                                  y: (size.height - TidyScene.size.height * k) / 2)
                    c.scaleBy(x: k, y: k)
                    TidyRenderer.thumbnail(level, filled: done, c)
                }
                .frame(width: 216, height: 172)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.cream.opacity(0.9)))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(glow ? Theme.pink : .white, lineWidth: glow ? 5.5 : 4.5))
                .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 6)
                if done {
                    Image(systemName: "star.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.lemon)
                        .shadow(color: Theme.ink.opacity(0.35), radius: 0, y: 2)
                        .padding(9)
                        .background(Circle().fill(.white))
                        .overlay(Circle().stroke(Theme.blush, lineWidth: 2.5))
                        .offset(x: 9, y: -9)
                }
            }
            .scaleEffect(glow && bob ? 1.04 : 1)
        }
        .buttonStyle(Squish())
        .onAppear {
            if glow { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { bob = true } }
        }
    }
}

struct TidyMusicButton: View {
    @ObservedObject var store: TidyStore
    var size: CGFloat = GameChromeLayout.buttonSize

    var body: some View {
        RoundButton(symbol: store.music ? "music.note" : "speaker.slash.fill", tint: Color(hex: 0xA77DEB), size: size) {
            store.music.toggle()
            store.save()
            Sound.shared.tap()
            if store.music { TidySound.shared.startMusic() } else { TidySound.shared.stopMusic() }
        }
    }
}

// MARK: - Playing a level

struct TidyPlayView: View {
    let roomIndex: Int
    @ObservedObject var store: TidyStore
    let next: () -> Void
    let levels: () -> Void
    let replay: () -> Void
    let shuffle: () -> Void
    let exit: () -> Void
    @StateObject private var world: TidyWorld
    @State private var touching = false
    @State private var showDone = false
    @State private var showBook = false
    @State private var confirmReset = false
    @State private var resetArmedAt = Date.distantPast
    @State private var resetPulse = false

    private var canShuffleRoom: Bool {
        world.level.isShuffle || store.done.contains(TidyLevels.all[roomIndex].id)
    }

    init(level: TidyLevel, roomIndex: Int, allowDemoPrefill: Bool, store: TidyStore,
         next: @escaping () -> Void, levels: @escaping () -> Void,
         replay: @escaping () -> Void, shuffle: @escaping () -> Void, exit: @escaping () -> Void) {
        self.roomIndex = roomIndex
        self.store = store
        self.next = next
        self.levels = levels
        self.replay = replay
        self.shuffle = shuffle
        self.exit = exit
        let args = ProcessInfo.processInfo.arguments
        var prefill = 0
        if allowDemoPrefill, let i = args.firstIndex(of: "-tidyPrefill"), i + 1 < args.count, let n = Int(args[i + 1]) { prefill = n }
        let w = TidyWorld(level: level, prefill: prefill)
        w.size = CGSize(width: GameChromeLayout.width, height: GameChromeLayout.height)
        _world = StateObject(wrappedValue: w)
    }

    var body: some View {
        ZStack {
            GameStage(background: {
                TidyRoomBackdrop(scene: world.level.scene)
            }) {
                ZStack {
                    Canvas { ctx, size in
                        var c = ctx
                        c.translateBy(x: (size.width - TidyScene.size.width) / 2, y: 92)
                        TidySceneArt.back(world.level.scene, c)
                    }
                    .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                    .allowsHitTesting(false)

                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: showBook)) { tl in
                        Canvas { ctx, _ in
                            let _ = tl.date
                            TidyRenderer.draw(world, ctx)
                        }
                        .onChange(of: tl.date) { date in
                            world.step(to: date)
                        }
                    }
                    .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if !touching { touching = true; world.touchDown(v.location) } else { world.touchMoved(v.location) }
                            }
                            .onEnded { v in
                                touching = false
                                world.touchUp(v.location)
                            }
                    )

                    GameTopBar(
                        gameID: TidyGame.id,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: exit,
                        onStickerBook: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        trailing: {
                            HStack(spacing: 12) {
                                RoundButton(symbol: "square.grid.2x2.fill", tint: Color(hex: 0xA77DEB), size: GameChromeLayout.buttonSize) {
                                    Sound.shared.tap()
                                    levels()
                                }
                                if canShuffleRoom {
                                    RoundButton(symbol: "die.face.5.fill", tint: Color(hex: 0xFFB84D), size: GameChromeLayout.buttonSize) {
                                        Sound.shared.play(.sparkle, volume: 0.5)
                                        Sound.shared.tap()
                                        shuffle()
                                    }
                                    .accessibilityLabel("Shuffle Room")
                                }
                                protectedResetButton
                                TidyMusicButton(store: store, size: GameChromeLayout.buttonSize)
                            }
                        }
                    )

                    StickerToast(game: TidyGame.id, target: GameChromeLayout.stickerTarget)

                    if showDone {
                        doneButtons.transition(.scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coinPurse(game: TidyGame.id)
            }

            if showBook {
                StickerBookView(game: TidyGame.id) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .onChange(of: world.complete) { done in
            if done {
                if !world.level.isShuffle {
                    store.done.insert(world.level.id)
                    store.save()
                }
                if store.done.count >= 6 {
                    StickerBook.shared.find(game: TidyGame.id, id: TidyFind.tidyChampion.rawValue)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if world.complete { withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { showDone = true } }
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { showDone = false }
            }
        }
        .onAppear {
            world.size = CGSize(width: GameChromeLayout.width, height: GameChromeLayout.height)
            demoHold()
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                resetPulse = true
            }
        }
    }

    private var protectedResetButton: some View {
        let size = GameChromeLayout.buttonSize
        return Button {
            handleResetTap()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(confirmReset ? .white : Color(hex: 0x4CC3C0))
                .frame(width: size, height: size)
                .background(Circle().fill(confirmReset ? Theme.pink : Color.white))
                .overlay(Circle().stroke(confirmReset ? Color.white : Color(hex: 0x4CC3C0).opacity(0.35), lineWidth: 4.5))
                .shadow(color: (confirmReset ? Theme.pink : Theme.ink).opacity(0.28), radius: confirmReset ? 9 : 6, y: 4)
        }
        .buttonStyle(Squish())
        .scaleEffect(confirmReset && resetPulse ? 1.12 : 1)
        .accessibilityLabel(confirmReset ? "Confirm Reset" : "Reset")
    }

    private func handleResetTap() {
        if world.placedCount == 0 || confirmReset {
            confirmReset = false
            Sound.shared.tap()
            replay()
            return
        }
        let armed = Date()
        resetArmedAt = armed
        Sound.shared.play(.tap, volume: 0.6)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
            confirmReset = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if resetArmedAt == armed {
                withAnimation(.easeOut(duration: 0.2)) {
                    confirmReset = false
                }
            }
        }
    }

    private var doneButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 34) {
                RoundButton(symbol: "arrow.counterclockwise", tint: Color(hex: 0x4CC3C0), size: 96) {
                    Sound.shared.tap()
                    replay()
                }
                RoundButton(symbol: "die.face.5.fill", tint: Color(hex: 0xFFB84D), size: 96) {
                    Sound.shared.play(.sparkle, volume: 0.5)
                    Sound.shared.tap()
                    shuffle()
                }
                .accessibilityLabel("Shuffle Bonus Clutter")
                Button {
                    Sound.shared.tap()
                    next()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 150, height: 150)
                        .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xFF9FC8), Theme.pink], startPoint: .top, endPoint: .bottom)))
                        .overlay(Circle().stroke(.white, lineWidth: 8))
                        .shadow(color: Theme.ink.opacity(0.3), radius: 10, y: 8)
                }
                .buttonStyle(Squish())
                RoundButton(symbol: "square.grid.2x2.fill", tint: Color(hex: 0xA77DEB), size: 96) {
                    Sound.shared.tap()
                    levels()
                }
            }
            .padding(.bottom, 50)
        }
    }

    /// -tidyHold: after the pile lands, lift one item and hold it next to its slot (screenshots).
    private func demoHold() {
        guard ProcessInfo.processInfo.arguments.contains("-tidyHold") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            guard let b = world.bodies.first(where: { $0.state == .loose }), let s = world.eligible(for: b).first else { return }
            world.touchDown(b.pos.pt)
            let p = world.slotPos(s) + TVec(70, 60)
            world.touchMoved(world.finger(toHold: b, at: p.pt))
        }
    }
}

// MARK: - Drawing a level

enum TidyRenderer {
    static func draw(_ w: TidyWorld, _ ctx: GraphicsContext) {
        let o = w.origin
        let scene = w.level.scene
        // The moving box bounces a little each time it tosses something out.
        var bc = ctx
        let br = w.boxRect
        bc.translateBy(x: br.midX, y: br.maxY)
        bc.scaleBy(x: 1 + 0.05 * w.boxKick, y: 1 - 0.08 * w.boxKick)
        bc.translateBy(x: -br.midX, y: -br.maxY)
        softShadow(ctx, CGPoint(x: br.midX, y: br.maxY), width: br.width * 1.15, height: 18, alpha: 0.25)
        TidySceneArt.movingBox(bc, br, open: 1)

        if TidyWorld.hasPlushBear {
            let bearPos = CGPoint(x: w.size.width - 90, y: w.floorY - 4)
            let cheer: Double
            if w.isDone {
                cheer = 0.72 + 0.28 * sin(w.time * 6.5)
            } else if w.lastPlace >= 0 && w.time - w.lastPlace < 1.15 {
                cheer = sin((w.time - w.lastPlace) / 1.15 * .pi)
            } else {
                cheer = 0
            }
            softShadow(ctx, CGPoint(x: bearPos.x, y: bearPos.y + 1), width: 76, height: 14, alpha: 0.24)
            TidySceneArt.hanbokPlushBear(ctx, at: bearPos, time: w.time, cheer: cheer)
        }

        var sc = ctx
        sc.translateBy(x: o.x, y: o.y)
        // Ghosts of the empty slots.
        let heldBody = w.held.map { w.bodies[$0] }
        let wanted = heldBody.map { Set(w.eligible(for: $0)) } ?? []
        for i in w.level.slots.indices where w.filled[i] == nil {
            let s = w.level.slots[i]
            let open = w.isOpen(i)
            let pulse = 0.5 + 0.5 * sin(w.time * 5)
            var alpha = s.strict ? 0.5 : 0.2
            var scale: CGFloat = 1
            var glow = false
            if wanted.contains(i) { alpha += 0.18 * pulse; scale = 1 + 0.03 * CGFloat(pulse) }
            if w.hover == i { alpha = 0.75; scale = 1.06; glow = true }
            if let h = w.hint, h.slot == i, w.time - h.at < 2.5 { alpha += 0.35 * pulse; scale = 1 + 0.08 * CGFloat(pulse); glow = pulse > 0.5 }
            if !open { alpha *= 0.42 }
            ghost(sc, s, alpha: alpha, scale: scale, glow: glow, lockedStack: !open && s.stack != nil)
            if w.isActiveStackBase(i) {
                drawStackBaseCue(sc, slot: s, time: w.time, highlighted: wanted.contains(i) || w.hover == i)
            }
        }
        // Things already put away (and things about to land), then the furniture's front.
        let inPlace = w.bodies.filter { b in
            b.state == .placed || (b.state == .snapping && b.slot.map { (w.slotPos($0) - b.pos).len < 36 } == true)
        }.sorted { ($0.slot ?? 0) < ($1.slot ?? 0) }
        for b in inPlace {
            if !scene.topDown, let s = b.slot {
                let sl = w.level.slots[s]
                let ext = abs(sin(sl.rot)) * b.size.width + abs(cos(sl.rot)) * b.size.height
                let wid = abs(cos(sl.rot)) * b.size.width + abs(sin(sl.rot)) * b.size.height
                softShadow(ctx, CGPoint(x: b.pos.x, y: b.pos.y + ext / 2), width: wid * 1.05, height: 9, alpha: 0.22)
            }
            item(ctx, b, topDown: scene.topDown)
        }
        TidySceneArt.front(scene, sc)
        for r in w.rings {
            let t = CGFloat((w.time - r.born) / 0.6)
            let rad = r.size * 0.45 + 70 * t
            let p = Path(ellipseIn: CGRect(x: r.pos.x - rad, y: r.pos.y - rad, width: rad * 2, height: rad * 2))
            ctx.stroke(p, with: .color(r.color.color(Double(1 - t) * 0.9)), lineWidth: 6 * (1 - t) + 1)
        }
        // Loose things on the floor, with shadows that shrink as they fly up.
        let loose = w.bodies.filter { $0.state == .loose }.sorted { $0.z < $1.z }
        for b in loose {
            var low: CGFloat = -1e9
            for c in b.circles { low = max(low, b.world(c).y + c.r) }
            let hf = max(0, min(1, (w.floorY - low) / 320))
            softShadow(ctx, CGPoint(x: b.pos.x, y: w.floorY - 2), width: b.bound * 1.7 * (1 - hf * 0.45), height: 14, alpha: 0.26 * Double(1 - hf * 0.8))
        }
        for b in loose { item(ctx, b, topDown: false) }
        for b in w.bodies where b.state == .snapping && !inPlace.contains(where: { $0.id == b.id }) { item(ctx, b, topDown: false) }
        if let h = heldBody { item(ctx, h, topDown: false) }
        particles(w, ctx)
    }

    /// One item at its body's place, with squash and its lifted drop shadow.
    static func item(_ ctx: GraphicsContext, _ b: TidyBody, topDown: Bool) {
        var c = ctx
        let lifted = b.lift > 0.02
        if lifted {
            c.addFilter(.shadow(color: Color(hex: 0x3A2248, alpha: 0.28 * Double(b.lift)), radius: 3 + 9 * b.lift, x: 6 * b.lift, y: 10 + 18 * b.lift))
        } else if topDown && b.state == .placed {
            c.addFilter(.shadow(color: Color(hex: 0x3A2248, alpha: 0.22), radius: 3, x: 2, y: 4))
        }
        c.drawLayer { l in
            l.translateBy(x: b.pos.x, y: b.pos.y)
            l.rotate(by: .radians(Double(b.angle)))
            let grow = 1 + 0.1 * b.lift
            let sq = max(-0.35, min(0.35, b.squash))
            let half = b.size.height / 2
            l.translateBy(x: 0, y: half)
            l.scaleBy(x: (1 - sq * 0.55) * grow, y: (1 + sq) * grow)
            l.translateBy(x: 0, y: -half)
            TidyArt.draw(b.kind, color: b.color, in: l)
        }
    }

    /// The see-through shape of what goes in a slot. Strict slots preserve a crisp white emblem cue over the tint;
    /// locked upper stack slots show a clear dotted outline.
    static func ghost(_ ctx: GraphicsContext, _ s: TidySlot, alpha: Double, scale: CGFloat, glow: Bool, lockedStack: Bool = false) {
        let tint: Color = s.strict ? TidyPalette.c(s.color).mix(.white, 0.15).color : TRGB.ink.color
        let big = CGRect(x: -200, y: -200, width: 400, height: 400)
        if glow {
            var g = ctx
            g.translateBy(x: s.pos.x, y: s.pos.y)
            g.rotate(by: .radians(Double(s.rot)))
            g.scaleBy(x: scale * 1.14, y: scale * 1.14)
            g.opacity = 0.7
            g.addFilter(.blur(radius: 6))
            g.drawLayer { l in
                TidyArt.draw(s.kind, color: s.color, in: l)
                l.blendMode = .sourceAtop
                l.fill(Path(big), with: .color(.white))
            }
        }
        var c = ctx
        c.translateBy(x: s.pos.x, y: s.pos.y)
        c.rotate(by: .radians(Double(s.rot)))
        c.scaleBy(x: scale, y: scale)
        c.opacity = min(1, alpha)
        c.drawLayer { l in
            TidyArt.draw(s.kind, color: s.color, in: l)
            l.blendMode = .sourceAtop
            l.fill(Path(big), with: .color(tint))
        }
        if s.strict {
            let emblemSize = min(22, min(s.kind.size.width, s.kind.size.height) * 0.58)
            var e = ctx
            e.translateBy(x: s.pos.x, y: s.pos.y)
            e.rotate(by: .radians(Double(s.rot)))
            e.scaleBy(x: scale, y: scale)
            e.opacity = min(1, alpha + 0.35)
            TPaint.emblem(e, s.color, at: CGPoint(x: 0, y: 1.2), size: emblemSize, color: TRGB.ink.color(0.22))
            TPaint.emblem(e, s.color, at: .zero, size: emblemSize, color: .white.opacity(0.95))
        }
        if lockedStack {
            var d = ctx
            d.translateBy(x: s.pos.x, y: s.pos.y)
            d.rotate(by: .radians(Double(s.rot)))
            let sz = s.kind.size
            let box = CGRect(x: -sz.width / 2 - 2, y: -sz.height / 2 - 2, width: sz.width + 4, height: sz.height + 4)
            let corner = min(10, min(sz.width, sz.height) * 0.35)
            d.stroke(
                Path(roundedRect: box, cornerRadius: corner),
                with: .color(TRGB.ink.color(0.3)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
            )
        }
    }

    /// Subtle animated upward chevron & pulse showing the active bottom-most open slot of a stack.
    private static func drawStackBaseCue(_ ctx: GraphicsContext, slot s: TidySlot, time: Double, highlighted: Bool) {
        let bob = CGFloat(sin(time * 4.6)) * 3.5
        let pulse = 0.55 + 0.45 * sin(time * 4.6)
        let cy = s.pos.y + bob
        var chevron = Path()
        chevron.move(to: CGPoint(x: s.pos.x - 10, y: cy + 3))
        chevron.addLine(to: CGPoint(x: s.pos.x, y: cy - 6))
        chevron.addLine(to: CGPoint(x: s.pos.x + 10, y: cy + 3))

        let alpha = highlighted ? 0.95 : (0.5 + 0.35 * pulse)
        ctx.stroke(
            chevron,
            with: .color(.white.opacity(alpha)),
            style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)
        )
        ctx.stroke(
            chevron,
            with: .color(Theme.pink.opacity(alpha)),
            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
        )
    }

    static func softShadow(_ ctx: GraphicsContext, _ center: CGPoint, width: CGFloat, height: CGFloat, alpha: Double) {
        guard width > 1 else { return }
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: 1, y: height / width)
        let r = width / 2
        c.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: width, height: width)),
               with: .radialGradient(Gradient(stops: [
                   .init(color: Color(hex: 0x3A2248, alpha: alpha), location: 0),
                   .init(color: Color(hex: 0x3A2248, alpha: alpha * 0.6), location: 0.55),
                   .init(color: Color(hex: 0x3A2248, alpha: 0), location: 1),
               ]), center: .zero, startRadius: 0, endRadius: r))
    }

    static func particles(_ w: TidyWorld, _ ctx: GraphicsContext) {
        for p in w.particles {
            let t = CGFloat((w.time - p.born) / p.life)
            switch p.kind {
            case .sparkle:
                let s = p.size * (1 - t * 0.7)
                var c = ctx
                c.translateBy(x: p.pos.x, y: p.pos.y)
                c.rotate(by: .radians(Double(p.rot)))
                c.opacity = Double(1 - t)
                c.fill(Twinkle().path(in: CGRect(x: -s / 2, y: -s / 2, width: s, height: s)), with: .color(p.color.color))
            case .puff:
                let r = p.size * (0.6 + t)
                ctx.fill(Path(ellipseIn: CGRect(x: p.pos.x - r, y: p.pos.y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(Double(0.55 * (1 - t)))))
            case .confetti:
                var c = ctx
                c.translateBy(x: p.pos.x, y: p.pos.y)
                c.rotate(by: .radians(Double(p.rot)))
                c.scaleBy(x: max(0.15, abs(cos(p.rot * 1.7))), y: 1)
                c.opacity = Double(min(1, (1 - t) * 3))
                let r = CGRect(x: -p.size / 2, y: -p.size * 0.32, width: p.size, height: p.size * 0.64)
                c.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(p.color.color))
            }
        }
    }

    /// A level card: the furniture, with everything in place if she finished it, or the ghost shapes if not.
    static func thumbnail(_ level: TidyLevel, filled: Bool, _ ctx: GraphicsContext) {
        TidySceneArt.back(level.scene, ctx)
        for s in level.slots {
            if filled {
                var c = ctx
                c.translateBy(x: s.pos.x, y: s.pos.y)
                c.rotate(by: .radians(Double(s.rot)))
                TidyArt.draw(s.kind, color: s.color, in: c)
            } else {
                ghost(ctx, s, alpha: s.strict ? 0.55 : 0.28, scale: 1, glow: false)
            }
        }
        TidySceneArt.front(level.scene, ctx)
    }
}

// MARK: - Drawer tile

private struct TidyTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 300
            var c = ctx
            c.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 300 * k) / 2)
            c.scaleBy(x: k, y: k)
            // A little shelf with books and a plant, and the moving box + teddy below.
            TidySceneArt.plank(c, 20, 150, 260, 18, TidySceneArt.wood)
            let things: [(TidyKind, CGFloat, Int, CGFloat)] = [
                (.book, 52, 0, 0), (.book, 88, 2, 0), (.book, 124, 5, 0), (.book, 164, 7, 0.22),
                (.plant, 236, 3, 0),
            ]
            for (kind, x, col, rot) in things {
                var d = c
                let s = kind.size
                let h = abs(sin(rot)) * s.width + abs(cos(rot)) * s.height
                d.translateBy(x: x, y: 150 - h / 2)
                d.rotate(by: .radians(Double(rot)))
                TidyArt.draw(kind, color: col, in: d)
            }
            TidySceneArt.movingBox(c, CGRect(x: 36, y: 194, width: 130, height: 90), open: 1)
            var m = c
            m.translateBy(x: 226, y: 244)
            m.rotate(by: .radians(-0.18))
            m.scaleBy(x: 1.22, y: 1.22)
            TidyArt.draw(.teddy, color: 7, in: m)
        }
    }
}
