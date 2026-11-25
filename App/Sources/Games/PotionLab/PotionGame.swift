import AVFoundation
import SwiftUI

// MARK: - Game Entry & Storybook Tile Icon

enum PotionGame {
    static let entry = GameEntry(
        id: PotionSim.gameID,
        title: "Potions",
        tint: Color(hex: 0xC9A6FF),
        icon: { AnyView(PotionTileIcon()) },
        play: { exit in AnyView(PotionLabView(exit: exit)) },
        stickers: PotionFind.stickers
    )
}

private struct PotionTileIcon: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000))
                var g = ctx
                let k = min(size.width, size.height) / 300
                g.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 300 * k) / 2)
                g.scaleBy(x: k, y: k)

                // Soft magical aura behind the flask.
                g.fill(
                    Path(ellipseIn: CGRect(x: 44, y: 58, width: 212, height: 212)),
                    with: .radialGradient(
                        Gradient(colors: [Color(hex: 0xFFB8E8).opacity(0.65), Color(hex: 0xC9A6FF).opacity(0.25), .clear]),
                        center: CGPoint(x: 150, y: 164),
                        startRadius: 20,
                        endRadius: 106
                    )
                )

                // Storybook round magic flask with warm tinted outline.
                let wobble = sin(t * 1.4) * 0.06
                var f = g
                f.translateBy(x: 150, y: 170)
                f.rotate(by: .radians(Double(wobble)))

                let bulb = Path(ellipseIn: CGRect(x: -74, y: -56, width: 148, height: 146))
                let neck = Path(roundedRect: CGRect(x: -26, y: -112, width: 52, height: 68), cornerRadius: 12)
                let lip = Path(roundedRect: CGRect(x: -36, y: -120, width: 72, height: 18), cornerRadius: 9)
                let cork = Path(roundedRect: CGRect(x: -20, y: -144, width: 40, height: 30), cornerRadius: 8)

                // Wooden cork & glass silhouette.
                StorybookArt.shape(f, cork, hex: 0xD29A6A, width: 5)
                StorybookArt.fillAndStroke(f, neck, fill: Color(hex: 0xF8F2FF).opacity(0.88), stroke: StorybookArt.outline(for: 0xB898F0), width: 6)
                StorybookArt.fillAndStroke(f, bulb, fill: Color(hex: 0xF8F2FF).opacity(0.9), stroke: StorybookArt.outline(for: 0xB898F0), width: 6)

                // Luminous pink-to-lilac swirling magic brew inside.
                var inner = f
                inner.clip(to: Path(ellipseIn: CGRect(x: -66, y: -48, width: 132, height: 130)))
                var wave = Path()
                wave.move(to: CGPoint(x: -72, y: -6))
                for x in stride(from: CGFloat(-72), through: 72, by: 8) {
                    let y = -6 + sin(x * 0.08 + t * 3.2) * 5
                    wave.addLine(to: CGPoint(x: x, y: y))
                }
                wave.addLine(to: CGPoint(x: 72, y: 92))
                wave.addLine(to: CGPoint(x: -72, y: 92))
                wave.closeSubpath()
                inner.fill(
                    wave,
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFF78C2), Color(hex: 0xC678FF), Color(hex: 0x7E68F4)]),
                        startPoint: CGPoint(x: 0, y: -10),
                        endPoint: CGPoint(x: 0, y: 84)
                    )
                )
                StorybookArt.sparkle(inner, at: CGPoint(x: 18, y: 24), radius: 16, color: Theme.lemon, opacity: 0.95)
                StorybookArt.sparkle(inner, at: CGPoint(x: -24, y: 42), radius: 10, color: .white, opacity: 0.9)

                // Glossy crescent highlight & glass rim lip.
                StorybookArt.highlight(f, in: CGRect(x: -50, y: -28, width: 22, height: 54), opacity: 0.58)
                StorybookArt.fillAndStroke(f, lip, fill: Color(hex: 0xFAF6FF), stroke: StorybookArt.outline(for: 0xB898F0), width: 5)

                // Gently rising soap bubbles & outer sparkles.
                for i in 0..<3 {
                    let prog = ((t * 0.42 + CGFloat(i) * 0.34).truncatingRemainder(dividingBy: 1))
                    let bx = 150 + sin(t * 2.6 + CGFloat(i) * 2) * 20 + CGFloat(i - 1) * 18
                    let by = 66 - prog * 54
                    let r: CGFloat = 7 + CGFloat(i % 2) * 4
                    let rect = CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)
                    g.fill(Path(ellipseIn: rect), with: .color(.white.opacity(Double(1 - prog) * 0.35)))
                    g.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(Double(1 - prog) * 0.92)), lineWidth: 2.5)
                }
                StorybookArt.sparkle(g, at: CGPoint(x: 224, y: 86), radius: 15 * (0.85 + 0.15 * sin(t * 4)), color: Theme.lemon)
                StorybookArt.sparkle(g, at: CGPoint(x: 72, y: 112), radius: 11 * (0.85 + 0.15 * cos(t * 3.5)), color: .white)
            }
        }
    }
}

// MARK: - Bundled Potion Lab Audio

enum PotionSFX: String, CaseIterable {
    case glug, splash, plop, drip, tink, clink, cork, pop, bloop, fizz, frost, chime, magic, poof, heart, boing, hiccup
    case shakeOff, yawn, shake, knob, click, whoosh, gurgle, fill, tap
    case boil, sizzle, fire, stir
}

final class PotionSound {
    static let shared = PotionSound()
    static let looping: Set<PotionSFX> = [.boil, .sizzle, .fire, .stir]
    private var players: [PotionSFX: [AVAudioPlayer]] = [:]
    private var loops: [PotionSFX: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "potion.sound", qos: .userInitiated)
    private var loopLevel: [PotionSFX: Float] = [:]
    private var loopSent: [PotionSFX: Float] = [:]

    private init() {
        _ = Sound.shared
        for s in PotionSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "PotionLab") else { continue }
            if PotionSound.looping.contains(s) {
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.numberOfLoops = -1
                p?.volume = 0
                p?.prepareToPlay()
                loops[s] = p
            } else {
                players[s] = (0..<3).compactMap { _ in
                    let p = try? AVAudioPlayer(contentsOf: url)
                    p?.enableRate = true
                    p?.prepareToPlay()
                    return p
                }
            }
        }
    }

    func play(_ s: PotionSFX, volume: Float = 0.85) {
        guard let pool = players[s], !pool.isEmpty else { return }
        let v = volume * Float.random(in: 0.82...1.0)
        let watery: Set<PotionSFX> = [.plop, .drip, .pop, .bloop, .splash, .glug, .tink, .clink]
        let rate: Float = watery.contains(s) ? Float.random(in: 0.88...1.14) : 1
        queue.async {
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = v
            p.rate = rate
            p.currentTime = 0
            p.play()
        }
    }

    func setLoop(_ s: PotionSFX, volume: Float) {
        guard let p = loops[s] else { return }
        let old = loopLevel[s] ?? 0
        let v = old + (volume - old) * 0.12
        loopLevel[s] = v
        let sent = loopSent[s] ?? 0
        let on = v > 0.01
        guard abs(v - sent) > 0.01 || (on != (sent > 0.01)) else { return }
        loopSent[s] = on ? v : 0
        queue.async {
            p.volume = on ? v : 0
            if on {
                if !p.isPlaying { p.play() }
            } else if p.isPlaying {
                p.pause()
            }
        }
    }

    func stopLoops() {
        for s in loops.keys { loopLevel[s] = 0; loopSent[s] = 0 }
        let all = Array(loops.values)
        queue.async {
            for p in all {
                p.pause()
                p.volume = 0
            }
        }
    }
}

// MARK: - Stage Gesture Tracking

private enum StageTouch {
    case none
    case stir
    case dial
    case valve
    case creature
    case standBottle(Int)
}

private final class StageHand {
    var active = false
    var grab: StageTouch = .none
    var start = CGPoint.zero
    var lastCreatureTapAt: Date = .distantPast
}

// MARK: - Main Potion Lab Screen

struct PotionLabView: View {
    let exit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var sim = PotionSim()
    @State private var liquid = PotionLiquid()
    @State private var hand = StageHand()
    @State private var started = false
    @State private var showStickerBook = false
    @State private var showSpellbook = false
    @State private var draggedDockKind: PIngredient? = nil
    @State private var bottlePulse = false

    var body: some View {
        ZStack {
            GameStage {
                PotionBackdropView(moonlit: sim.moonlit)
            } content: {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: showStickerBook || showSpellbook)) { tl in
                        Canvas { ctx, _ in
                            sim.step(tl.date)
                            playSounds()
                            PotionPainter.drawStage(ctx, sim: sim, liquid: liquid)
                        }
                    }
                    .frame(width: PotionGeometry.stageWidth, height: PotionGeometry.stageHeight)
                    .contentShape(Rectangle())
                    .gesture(stageGesture)

                    creatureControls
                    bottleFillButton
                    ingredientDock

                    GameTopBar(
                        gameID: PotionSim.gameID,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: {
                            sim.save()
                            PotionSound.shared.stopLoops()
                            exit()
                        },
                        onStickerBook: {
                            PotionSound.shared.stopLoops()
                            withAnimation(.easeOut(duration: 0.2)) { showStickerBook = true }
                        },
                        trailing: {
                            RoundButton(symbol: "sparkles", tint: Theme.lilac, size: GameChromeLayout.buttonSize) {
                                Sound.shared.play(.sparkle, volume: 0.65)
                                Sound.shared.tap()
                                PotionSound.shared.stopLoops()
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                                    showSpellbook = true
                                }
                            }
                            .accessibilityLabel("Spellbook")
                            RoundButton(
                                symbol: sim.moonlit ? "moon.stars.fill" : "sun.max.fill",
                                tint: sim.moonlit ? Theme.lilac : Theme.lemon,
                                size: GameChromeLayout.buttonSize
                            ) {
                                Sound.shared.tap()
                                sim.toggleMoonlit()
                            }
                            .accessibilityLabel(sim.moonlit ? "Moonlight" : "Daylight")
                        }
                    )

                    StickerToast(game: PotionSim.gameID, target: GameChromeLayout.stickerTarget)
                }
                .coordinateSpace(name: "potionStage")
                .coinPurse(game: PotionSim.gameID)
            }

            if showSpellbook {
                PotionSpellbookView {
                    Sound.shared.play(.flip, volume: 0.6)
                    withAnimation(.easeOut(duration: 0.2)) { showSpellbook = false }
                }
                .transition(.opacity)
                .zIndex(8)
            }

            if showStickerBook {
                StickerBookView(game: PotionSim.gameID) {
                    withAnimation(.easeOut(duration: 0.2)) { showStickerBook = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                sim.save()
                PotionSound.shared.stopLoops()
            }
        }
        .onDisappear {
            sim.save()
            PotionSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = PotionSound.shared
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            bottlePulse = true
        }
        applyLaunchArguments()
    }

    private func playSounds() {
        let snd = PotionSound.shared
        for c in sim.cues {
            snd.play(c, volume: c == .glug ? 0.62 : 0.84)
        }
        sim.cues.removeAll(keepingCapacity: true)

        for note in sim.harpNotes {
            Sound.shared.play(note, volume: 0.52)
        }
        sim.harpNotes.removeAll(keepingCapacity: true)

        snd.setLoop(.fire, volume: sim.burner == .off ? 0 : (sim.burner == .boil ? 0.34 : 0.16))
        snd.setLoop(.boil, volume: sim.burner == .boil ? Float(sim.boiling) * 0.65 : 0)
        snd.setLoop(.stir, volume: Float(min(1, sim.stirSpeed / 580)) * 0.62)
    }

    // MARK: Creature Switcher & Water Reset

    private var creatureControls: some View {
        ZStack {
            // 4-icon Creature Switcher strip right below the plush cushion.
            HStack(spacing: 10) {
                ForEach(LabCreature.allCases) { kind in
                    let selected = sim.creature == kind
                    Button {
                        Sound.shared.tap()
                        sim.selectCreature(kind)
                    } label: {
                        ZStack {
                            Circle().fill(kind.badgeTint.opacity(0.92))
                            PetThumb(pet: kind.petLook, box: CGRect(x: 86, y: 58, width: 428, height: 420))
                                .padding(4)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(selected ? Theme.pink : .white, lineWidth: selected ? 4.5 : 3))
                        .shadow(color: Theme.ink.opacity(selected ? 0.28 : 0.14), radius: selected ? 6 : 3, y: 2)
                        .scaleEffect(selected ? 1.12 : 1)
                        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: selected)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel(kind.rawValue.capitalized)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.cream.opacity(0.94)))
            .overlay(Capsule().stroke(Theme.blush, lineWidth: 3))
            .shadow(color: Theme.ink.opacity(0.16), radius: 7, y: 4)
            .position(PotionGeometry.creatureSwitcherCenter)

            // Sparkling Water Drop Reset button beside the cushion.
            Button {
                Sound.shared.tap()
                sim.resetCreatureEffects()
            } label: {
                ZStack {
                    Circle().fill(sim.hasActiveEffect ? Color(hex: 0x76DCFF) : Color.white.opacity(0.92))
                    Image(systemName: "drop.fill")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(sim.hasActiveEffect ? .white : Color(hex: 0x56BFE8))
                }
                .frame(width: 54, height: 54)
                .overlay(Circle().stroke(.white, lineWidth: 4))
                .shadow(color: Theme.ink.opacity(0.2), radius: 5, y: 3)
                .scaleEffect(sim.hasActiveEffect && bottlePulse ? 1.08 : 1.0)
            }
            .buttonStyle(Squish())
            .accessibilityLabel("Splash Clean")
            .position(PotionGeometry.waterResetCenter)
        }
    }

    // MARK: Bottle-Fill Sparkle Button

    @ViewBuilder
    private var bottleFillButton: some View {
        if sim.canBottle {
            Button {
                Sound.shared.tap()
                sim.bottleCurrentBrew()
            } label: {
                ZStack {
                    Circle().fill(Theme.cream)
                    Canvas { ctx, size in
                        let (mc, _) = sim.meanColor()
                        let col = sim.rare?.color ?? mc
                        let preview = PotionBottle(
                            id: 0,
                            r: col.r,
                            g: col.g,
                            b: col.b,
                            fill: 0.85,
                            shape: (sim.rare?.shape ?? .round).rawValue,
                            kind: sim.rare?.rawValue,
                            magic: [:],
                            glow: 0.35,
                            sparkle: 0.7
                        )
                        PotionBottlePainter.draw(
                            ctx,
                            bottle: preview,
                            center: CGPoint(x: size.width / 2, y: size.height / 2 + 4),
                            angle: 0,
                            scale: 0.36,
                            time: 0.5
                        )
                        StorybookArt.sparkle(ctx, at: CGPoint(x: size.width - 14, y: 15), radius: 8, color: Theme.lemon)
                    }
                }
                .frame(width: 66, height: 66)
                .overlay(Circle().stroke(Theme.pink, lineWidth: 4.5))
                .shadow(color: Theme.ink.opacity(0.24), radius: 7, y: 4)
                .scaleEffect(bottlePulse ? 1.07 : 0.98)
            }
            .buttonStyle(Squish())
            .accessibilityLabel("Bottle Potion")
            .position(PotionGeometry.bottleFillCenter)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: Unified Bottom Ingredient Dock

    private var ingredientDock: some View {
        GameTrayCard(cornerRadius: 32, paddingH: 18, paddingV: 10) {
            HStack(spacing: 12) {
                ForEach(PIngredient.allCases) { kind in
                    let count = sim.ingredients[kind] ?? 0
                    let isDragging = draggedDockKind == kind
                    GameDockTile(
                        size: 82,
                        selected: count > 0 || isDragging,
                        tint: kind.tileTint,
                        cornerRadius: 24
                    ) {
                        ZStack(alignment: .bottom) {
                            IngredientIconView(kind: kind)
                                .padding(10)
                            if count > 0 {
                                HStack(spacing: 4) {
                                    ForEach(0..<min(3, count), id: \.self) { _ in
                                        Circle()
                                            .fill(Theme.pink)
                                            .frame(width: 7, height: 7)
                                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                    }
                                }
                                .padding(.bottom, 5)
                            }
                        }
                    }
                    .opacity(isDragging ? 0.45 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("potionStage"))
                            .onChanged { value in
                                let moved = hypot(value.translation.width, value.translation.height)
                                if moved > 14 && value.location.y < 712 {
                                    draggedDockKind = kind
                                    let lifted = FingerLift.point(value.location, lift: 74, bottom: PotionGeometry.stageHeight, width: PotionGeometry.stageWidth)
                                    sim.draggedIngredient = (kind, lifted)
                                }
                            }
                            .onEnded { value in
                                let moved = hypot(value.translation.width, value.translation.height)
                                let origin = sim.draggedIngredient?.pos ?? PotionGeometry.dockSlotCenter(kind.dockIndex)
                                draggedDockKind = nil
                                sim.draggedIngredient = nil

                                // Tap OR drag upward toward the cauldron adds a guaranteed integer scoop!
                                if moved <= 18 || value.location.y < 695 {
                                    Sound.shared.tap()
                                    sim.addIngredient(kind, from: origin)
                                }
                            }
                    )
                    .accessibilityLabel(kind.accessibilityName)
                }
            }
        }
        .position(x: PotionGeometry.stageWidth / 2, y: PotionGeometry.dockY)
    }

    // MARK: Interactive Stage Gesture (Direct Stir, Dial, Valve, Tasting Stand, Creature)

    private var stageGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("potionStage"))
            .onChanged { value in
                let p = value.location
                if !hand.active {
                    hand.active = true
                    hand.start = p
                    hand.grab = hitTestStage(p)
                    switch hand.grab {
                    case .stir:
                        sim.beginStir(at: p)
                    case .dial, .valve, .creature:
                        Sound.shared.tap()
                    case .standBottle:
                        Sound.shared.tap()
                    case .none:
                        break
                    }
                    return
                }
                let moved = hypot(p.x - hand.start.x, p.y - hand.start.y)
                switch hand.grab {
                case .stir:
                    sim.moveStir(to: p)
                case .standBottle(let idx):
                    if moved > 10 {
                        let lifted = FingerLift.point(p, lift: 68, bottom: PotionGeometry.stageHeight, width: PotionGeometry.stageWidth)
                        let tilt: CGFloat = lifted.x < 390 ? -1.35 : 0
                        sim.draggedStandBottle = (idx, lifted, tilt)
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                let p = value.location
                let moved = hypot(p.x - hand.start.x, p.y - hand.start.y)
                switch hand.grab {
                case .stir:
                    sim.endStir()
                case .dial:
                    sim.cycleBurner()
                case .valve:
                    sim.toggleDrain()
                case .creature:
                    if moved < 24 {
                        let now = Date()
                        if now.timeIntervalSince(hand.lastCreatureTapAt) < 0.38 {
                            hand.lastCreatureTapAt = .distantPast
                            sim.resetCreatureEffects()
                        } else {
                            hand.lastCreatureTapAt = now
                            sim.tapCreature()
                        }
                    }
                case .standBottle(let idx):
                    let dropPos = sim.draggedStandBottle?.pos ?? p
                    sim.draggedStandBottle = nil
                    if moved <= 16 {
                        sim.serveBottle(at: idx)
                    } else if p.x < 420 || PotionGeometry.creatureDropZone.contains(dropPos) {
                        sim.serveBottle(at: idx, from: dropPos)
                    } else if let b = sim.stand[safe: idx] {
                        let home = PotionGeometry.standSlots[min(idx, PotionGeometry.standSlots.count - 1)]
                        sim.flyers.append(PFlyer(from: dropPos, to: home, bottle: b, standIndex: idx, spin: 0))
                    }
                case .none:
                    break
                }
                hand.active = false
                hand.grab = .none
            }
    }

    private func hitTestStage(_ p: CGPoint) -> StageTouch {
        if PotionGeometry.dialHit(p) { return .dial }
        if PotionGeometry.valveHit(p) { return .valve }
        if let idx = PotionGeometry.standSlotHit(p), sim.stand.indices.contains(idx) {
            return .standBottle(idx)
        }
        if PotionGeometry.insideCauldronTouch(p) { return .stir }
        if PotionGeometry.creatureDropZone.contains(p) { return .creature }
        return .none
    }

    // MARK: Screenshot Demo Hook

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-potionDemo") else { return }
        let mode = i + 1 < args.count ? args[i + 1] : "mix"
        StickerBook.shared.demo = true
        Coins.shared.demo = true
        sim.showcase(mode)
        if mode == "spellbook" || mode == "hint" {
            showSpellbook = true
        }
    }
}

private extension PIngredient {
    var accessibilityName: String {
        switch self {
        case .fairyRose: return "Fairy Rose"
        case .mermaidWave: return "Mermaid Wave"
        case .starGlitter: return "Star Glitter"
        case .rainbowMane: return "Rainbow Mane"
        case .frostFlake: return "Frost Flake"
        case .bubbleBerry: return "Bubble Berry"
        case .dragonChili: return "Dragon Chili"
        case .sleepyLavender: return "Sleepy Lavender"
        }
    }
}

// MARK: - Spoiler-Free Picture Spellbook Overlay (Zero English Prose)

struct PotionSpellbookView: View {
    let close: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            DesignCanvas {
                GameTrayCard(cornerRadius: 40, paddingH: 26, paddingV: 24) {
                    VStack(spacing: 14) {
                        // Purely pictorial star progress bar (10 stars, filled for discovered potions).
                        HStack(spacing: 8) {
                            ForEach(PotionKind.allCases) { kind in
                                let found = StickerBook.shared.has(game: PotionSim.gameID, id: kind.rawValue)
                                Image(systemName: found ? "star.fill" : "star")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(found ? Theme.lemon : Theme.ink.opacity(0.2))
                                    .shadow(color: found ? Theme.ink.opacity(0.22) : .clear, radius: 1, y: 1)
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(PotionKind.allCases) { kind in
                                PotionRecipeCard(kind: kind)
                            }
                        }
                    }
                    .frame(width: 840)
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 62, height: 62)
                            .background(Circle().fill(Theme.pink))
                            .overlay(Circle().stroke(.white, lineWidth: 5))
                            .shadow(color: Theme.ink.opacity(0.25), radius: 5, y: 3)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel("Close")
                    .offset(x: 18, y: -18)
                }
            }
        }
    }
}

private struct PotionRecipeCard: View {
    let kind: PotionKind

    var body: some View {
        let found = StickerBook.shared.has(game: PotionSim.gameID, id: kind.rawValue)
        let recipe = kind.recipe

        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { idx, ing in
                    if idx > 0 {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Theme.ink.opacity(0.45))
                    }
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ing.tileTint)
                        IngredientIconView(kind: ing)
                            .padding(4)
                    }
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.blush, lineWidth: 2))
                }

                if recipe.requiresBoil {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.45))
                    ZStack {
                        Circle().fill(Color(hex: 0xFFE8D4))
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFF6B3D))
                    }
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(Color(hex: 0xFFB888), lineWidth: 2))
                }

                if recipe.requiresMoonlit {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.ink.opacity(0.45))
                    ZStack {
                        Circle().fill(Color(hex: 0x2F245C))
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Theme.lemon)
                    }
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(Theme.lilac, lineWidth: 2))
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.ink.opacity(0.42))

            // Spoiler-free: unfound shows a uniform lavender mystery silhouette; found shows the gleaming bottle!
            TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !found)) { tl in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000))
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2 + 4)
                    if found {
                        let bottle = PotionBottle(
                            id: 9,
                            r: kind.color.r,
                            g: kind.color.g,
                            b: kind.color.b,
                            fill: 0.86,
                            shape: kind.shape.rawValue,
                            kind: kind.rawValue,
                            magic: [:],
                            glow: Double(kind.glow),
                            sparkle: Double(kind.sparkle)
                        )
                        PotionBottlePainter.draw(ctx, bottle: bottle, center: center, angle: sin(t * 1.4) * 0.05, scale: 0.52, time: t)
                    } else {
                        PotionBottlePainter.mysterySilhouette(ctx, shape: kind.shape, center: center, scale: 0.52, time: t)
                    }
                }
            }
            .frame(width: 72, height: 82)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(height: 94)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(found ? Color.white : Color.white.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(found ? Theme.lemon : Theme.blush, lineWidth: found ? 3.5 : 2.5)
        )
    }
}
