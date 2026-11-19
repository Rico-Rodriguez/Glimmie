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
        play: { exit in AnyView(TidyGameView(exit: exit)) }
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
    private var players: [TidySFX: [AVAudioPlayer]] = [:]
    private var music: AVAudioPlayer?
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let note = UINotificationFeedbackGenerator()

    private init() {
        _ = Sound.shared // sets up the audio session
        for s in TidySFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "Tidy") else { continue }
            players[s] = (0..<4).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.enableRate = true
                p?.prepareToPlay()
                return p
            }
        }
        light.prepare(); soft.prepare(); rigid.prepare()
    }

    func play(_ s: TidySFX, volume: Float = 1, rate: Float = 1) {
        guard let pool = players[s], !pool.isEmpty else { return }
        let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        p.volume = volume
        p.rate = max(0.5, min(2, rate))
        p.currentTime = 0
        p.play()
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
        switch style {
        case .soft: soft.impactOccurred()
        case .rigid: rigid.impactOccurred(intensity: 0.8)
        default: light.impactOccurred()
        }
    }

    func success() { note.notificationOccurred(.success) }

    func startMusic() {
        if music == nil, let url = GameFiles.url("calm", "m4a", game: "Tidy") {
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.prepareToPlay()
        }
        guard let m = music else { return }
        if !m.isPlaying {
            m.volume = 0
            m.play()
        }
        m.setVolume(0.42, fadeDuration: 1.5)
    }

    func stopMusic() {
        guard let m = music, m.isPlaying else { return }
        m.setVolume(0, fadeDuration: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak m] in
            if let m = m, m.volume < 0.05 { m.pause() }
        }
    }
}

// MARK: - Root

struct TidyGameView: View {
    let exit: () -> Void
    @StateObject private var store = TidyStore()
    @State private var playing: Int?
    @State private var round = 0

    var body: some View {
        ZStack {
            if let i = playing {
                TidyPlayView(index: i, store: store, round: round,
                             next: { go(to: (i + 1) % TidyLevels.all.count) },
                             levels: { withAnimation(.easeInOut(duration: 0.35)) { playing = nil } },
                             replay: { round += 1 },
                             exit: exit)
                    .id("\(i)-\(round)")
                    .transition(.opacity)
            } else {
                TidyLevelPicker(store: store, exit: exit) { go(to: $0) }
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
        withAnimation(.easeInOut(duration: 0.35)) { playing = i }
    }

    /// Simulator screenshot hooks: -tidyLevel <n> opens a level (-tidyPrefill <k>, -tidyHold in TidyPlayView).
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tidyLevel"), i + 1 < args.count, let n = Int(args[i + 1]), TidyLevels.all.indices.contains(n) {
            playing = n
        }
        if args.contains("-tidyDemoDone") {
            for l in TidyLevels.all.prefix(9) { store.done.insert(l.id) }
        }
    }
}

// MARK: - Level picker

struct TidyLevelPicker: View {
    @ObservedObject var store: TidyStore
    let exit: () -> Void
    let open: (Int) -> Void

    private var nextUp: Int { TidyLevels.all.firstIndex { !store.done.contains($0.id) } ?? 0 }

    var body: some View {
        ZStack {
            DesignCanvas {
                ZStack(alignment: .top) {
                    Canvas { ctx, size in
                        TidySceneArt.room(.bookshelf, ctx, size: size, floorY: size.height - 22)
                    }
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(212), spacing: 26), count: 4), spacing: 26) {
                            ForEach(TidyLevels.all.indices, id: \.self) { i in
                                TidyLevelCard(level: TidyLevels.all[i], done: store.done.contains(TidyLevels.all[i].id), glow: i == nextUp) {
                                    Sound.shared.tap()
                                    open(i)
                                }
                            }
                        }
                        .padding(.top, 116)
                        .padding(.bottom, 40)
                    }
                    HStack {
                        HomeButton(action: exit)
                        Spacer()
                        TidyMusicButton(store: store)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
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
                    let k = size.width / TidyScene.size.width
                    var c = ctx
                    c.translateBy(x: 0, y: (size.height - TidyScene.size.height * k) / 2)
                    c.scaleBy(x: k, y: k)
                    TidyRenderer.thumbnail(level, filled: done, c)
                }
                .frame(width: 212, height: 150)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white.opacity(0.75)))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(glow ? Theme.pink : .white, lineWidth: glow ? 6 : 5))
                .shadow(color: Theme.ink.opacity(0.18), radius: 8, y: 6)
                if done {
                    Image(systemName: "star.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Theme.lemon)
                        .shadow(color: Theme.ink.opacity(0.35), radius: 0, y: 2)
                        .padding(10)
                        .background(Circle().fill(.white))
                        .offset(x: 10, y: -10)
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
    var body: some View {
        RoundButton(symbol: store.music ? "music.note" : "speaker.slash.fill", tint: Color(hex: 0xA77DEB)) {
            store.music.toggle()
            store.save()
            Sound.shared.tap()
            if store.music { TidySound.shared.startMusic() } else { TidySound.shared.stopMusic() }
        }
    }
}

// MARK: - Playing a level

struct TidyPlayView: View {
    let index: Int
    @ObservedObject var store: TidyStore
    let next: () -> Void
    let levels: () -> Void
    let replay: () -> Void
    let exit: () -> Void
    @StateObject private var world: TidyWorld
    @State private var touching = false
    @State private var showDone = false

    init(index: Int, store: TidyStore, round: Int, next: @escaping () -> Void, levels: @escaping () -> Void,
         replay: @escaping () -> Void, exit: @escaping () -> Void) {
        self.index = index
        self.store = store
        self.next = next
        self.levels = levels
        self.replay = replay
        self.exit = exit
        let args = ProcessInfo.processInfo.arguments
        var prefill = 0
        if round == 0, let i = args.firstIndex(of: "-tidyPrefill"), i + 1 < args.count, let n = Int(args[i + 1]) { prefill = n }
        _world = StateObject(wrappedValue: TidyWorld(level: TidyLevels.all[index], prefill: prefill))
    }

    var body: some View {
        DesignCanvas {
            ZStack {
                Canvas { ctx, size in
                    TidySceneArt.room(world.level.scene, ctx, size: size, floorY: size.height - 22)
                    var c = ctx
                    c.translateBy(x: (size.width - TidyScene.size.width) / 2, y: 92)
                    TidySceneArt.back(world.level.scene, c)
                }
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        world.size = size
                        world.step(to: tl.date)
                        TidyRenderer.draw(world, ctx)
                    }
                }
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
                topBar
                if showDone { doneButtons.transition(.scale(scale: 0.3).combined(with: .opacity)) }
            }
        }
        .onChange(of: world.complete) { done in
            if done {
                store.done.insert(world.level.id)
                store.save()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if world.complete { withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { showDone = true } }
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { showDone = false }
            }
        }
        .onAppear(perform: demoHold)
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 18) {
                HomeButton(action: exit)
                RoundButton(symbol: "square.grid.2x2.fill", tint: Color(hex: 0xA77DEB)) {
                    Sound.shared.tap()
                    levels()
                }
                Spacer()
                RoundButton(symbol: "arrow.counterclockwise", tint: Color(hex: 0x4CC3C0)) {
                    Sound.shared.tap()
                    replay()
                }
                TidyMusicButton(store: store)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            Spacer()
        }
    }

    private var doneButtons: some View {
        VStack {
            Spacer()
            HStack(spacing: 40) {
                RoundButton(symbol: "arrow.counterclockwise", tint: Color(hex: 0x4CC3C0), size: 96) {
                    Sound.shared.tap()
                    replay()
                }
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
            world.touchMoved(p.pt)
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

        var sc = ctx
        sc.translateBy(x: o.x, y: o.y)
        // Ghosts of the empty slots.
        let heldBody = w.held.map { w.bodies[$0] }
        let wanted = heldBody.map { Set(w.eligible(for: $0)) } ?? []
        for i in w.level.slots.indices where w.filled[i] == nil {
            let s = w.level.slots[i]
            let pulse = 0.5 + 0.5 * sin(w.time * 5)
            var alpha = s.strict ? 0.5 : 0.2
            var scale: CGFloat = 1
            var glow = false
            if wanted.contains(i) { alpha += 0.18 * pulse; scale = 1 + 0.03 * CGFloat(pulse) }
            if w.hover == i { alpha = 0.75; scale = 1.06; glow = true }
            if let h = w.hint, h.slot == i, w.time - h.at < 2.5 { alpha += 0.35 * pulse; scale = 1 + 0.08 * CGFloat(pulse); glow = pulse > 0.5 }
            if !w.isOpen(i) { alpha *= 0.5 }
            ghost(sc, s, alpha: alpha, scale: scale, glow: glow)
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

    /// The see-through shape of what goes in a slot. Strict slots show the color they want.
    static func ghost(_ ctx: GraphicsContext, _ s: TidySlot, alpha: Double, scale: CGFloat, glow: Bool) {
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
                // Paper flipping over as it falls.
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
            c.scaleBy(x: k, y: k)
            // A little shelf with books, a plant and a mug, and the moving box below.
            TidySceneArt.plank(c, 20, 150, 260, 18, TidySceneArt.wood)
            let things: [(TidyKind, CGFloat, Int, CGFloat)] = [(.book, 52, 0, 0), (.book, 88, 2, 0), (.book, 124, 5, 0), (.book, 164, 7, 0.22),
                                                               (.plant, 236, 3, 0)]
            for (kind, x, col, rot) in things {
                var d = c
                let s = kind.size
                let h = abs(sin(rot)) * s.width + abs(cos(rot)) * s.height
                d.translateBy(x: x, y: 150 - h / 2)
                d.rotate(by: .radians(Double(rot)))
                TidyArt.draw(kind, color: col, in: d)
            }
            TidySceneArt.movingBox(c, CGRect(x: 40, y: 200, width: 130, height: 90), open: 1)
            var m = c
            m.translateBy(x: 228, y: 258)
            m.rotate(by: .radians(-0.2))
            m.scaleBy(x: 1.3, y: 1.3)
            TidyArt.draw(.teddy, color: 7, in: m)
        }
    }
}
