import AVFoundation
import SwiftUI

enum SpaGame {
    static let entry = GameEntry(
        id: SpaSim.gameID,
        title: "Bubble Spa",
        tint: Color(hex: 0x9CDCF2),
        icon: { AnyView(SpaTileIcon()) },
        play: { exit in AnyView(SpaView(exit: exit)) },
        stickers: SpaFind.stickers
    )
}

// MARK: - Drawer tile icon (StorybookArt warm outlines & shine)

private struct SpaTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = min(size.width, size.height) / 300
            g.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 300 * k) / 2)
            g.scaleBy(x: k, y: k)

            let goldOutline = StorybookArt.outline(for: 0xD89A3C)
            let tubOutline = StorybookArt.outline(for: 0xF0ACC6)

            // Golden lion-paw claw feet
            for fx in [CGFloat(78), 222] {
                let foot = Path(roundedRect: CGRect(x: fx - 20, y: 242, width: 40, height: 28), cornerRadius: 12)
                StorybookArt.fillAndStroke(g, foot, fill: StorybookArt.color(0xF6C768), stroke: goldOutline, width: 5)
            }

            // Fluffy 3D foam mounds spilling out of the tub
            var blobs: [(CGPoint, CGFloat)] = []
            for q in 0..<15 {
                let bx = 54 + CGFloat(q) * 13.5 + (shash(q) - 0.5) * 8
                let by = 152 - shash(q + 20) * 30
                blobs.append((CGPoint(x: bx, y: by), 18 + shash(q + 40) * 14))
            }
            SpaPainter.foamBlobs(g, blobs, color: RGB(1, 1, 1))

            // Cheerful yellow rubber ducky peeking out of the bubbles
            var d = g
            d.translateBy(x: 196, y: 118)
            d.scaleBy(x: 1.12, y: 1.12)
            ThingPainter.duck(d, body: RGB(hex: "#FFD84A"), scale: 1)

            // Pastel cream-pink scalloped clawfoot tub body
            let tub = SpaPainter.tubShape(CGRect(x: 34, y: 152, width: 232, height: 104), top: 10, bottom: 46)
            g.fill(
                tub,
                with: .linearGradient(
                    Gradient(colors: [StorybookArt.color(0xFFF6FA), StorybookArt.color(0xFBD8E7), StorybookArt.color(0xF3BDD3)]),
                    startPoint: CGPoint(x: 0, y: 152),
                    endPoint: CGPoint(x: 0, y: 256)
                )
            )
            g.stroke(tub, with: .color(tubOutline), lineWidth: 7)

            // Scalloped rolled lip + porcelain shine
            let lip = Path(roundedRect: CGRect(x: 24, y: 146, width: 252, height: 22), cornerRadius: 11)
            StorybookArt.fillAndStroke(g, lip, fill: StorybookArt.color(0xFFF9FC), stroke: tubOutline, width: 5.5)
            StorybookArt.highlight(g, in: CGRect(x: 44, y: 151, width: 110, height: 7), opacity: 0.85)
            StorybookArt.heart(g, at: CGPoint(x: 150, y: 208), size: 32, color: Theme.pink.opacity(0.85))

            // Iridescent floating rainbow bubbles + sparkles
            let film = Gradient(colors: [
                Color(hex: 0xFF9ECF), Color(hex: 0xFFE38A), Color(hex: 0x9FF0D8),
                Color(hex: 0x8FC6FF), Color(hex: 0xC9A6FF), Color(hex: 0xFF9ECF),
            ])
            let tileBubbles: [(CGFloat, CGFloat, CGFloat)] = [(82, 74, 29), (144, 44, 18), (54, 36, 12)]
            for (x, y, r) in tileBubbles {
                let c = CGPoint(x: x, y: y)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                g.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.28)))
                g.stroke(Path(ellipseIn: rect), with: .conicGradient(film, center: c), lineWidth: 5)
                StorybookArt.highlight(g, in: CGRect(x: x - r * 0.58, y: y - r * 0.62, width: r * 0.52, height: r * 0.3), opacity: 0.92)
            }
            StorybookArt.sparkle(g, at: CGPoint(x: 248, y: 58), radius: 14, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: 114, y: 26), radius: 9, color: .white)
        }
    }
}

// MARK: - Sounds

enum SpaSFX: String, CaseIterable {
    case running, drain, fizz, shower, scrub
    case splash, bigsplash, plop, drip, pop, blow, squeak, squeak2, toot, spout, glug, squish, slosh, turn, plug, chime
}

final class SpaSound {
    static let shared = SpaSound()
    private var players: [SpaSFX: [AVAudioPlayer]] = [:]
    private var loops: [SpaSFX: AVAudioPlayer] = [:]
    private var last: [SpaSFX: Date] = [:]
    static let looping: Set<SpaSFX> = [.running, .drain, .fizz, .shower, .scrub]
    private let queue = DispatchQueue(label: "spa.sound", qos: .userInitiated)
    private var loopLevel: [SpaSFX: Float] = [:]
    private var loopSent: [SpaSFX: Float] = [:]

    private init() {
        _ = Sound.shared
        for s in SpaSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "Spa") else { continue }
            if SpaSound.looping.contains(s) {
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.numberOfLoops = -1
                p?.volume = 0
                p?.prepareToPlay()
                loops[s] = p
            } else {
                players[s] = (0..<4).compactMap { _ in
                    let p = try? AVAudioPlayer(contentsOf: url)
                    p?.prepareToPlay()
                    return p
                }
            }
        }
    }

    func play(_ s: SpaSFX, volume: Float = 0.9, gap: Double = 0) {
        let now = Date()
        if gap > 0, let t = last[s], now.timeIntervalSince(t) < gap { return }
        last[s] = now
        guard let pool = players[s], !pool.isEmpty else { return }
        queue.async {
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = volume
            p.currentTime = 0
            p.play()
        }
    }

    func setLoop(_ s: SpaSFX, volume: Float) {
        guard let p = loops[s] else { return }
        let old = loopLevel[s] ?? 0
        let v = old + (volume - old) * 0.15
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
        for s in loops.keys {
            loopLevel[s] = 0
            loopSent[s] = 0
        }
        let all = Array(loops.values)
        queue.async {
            for p in all {
                p.pause()
                p.volume = 0
            }
        }
    }
}

// MARK: - Bottom dock item model

private enum SpaDockItem: Identifiable, Equatable {
    case bomb(BombKind)
    case soap
    case sponge(FoamTint)
    case shower
    case mask(MaskKind)
    case cucumbers
    case towel
    case mist
    case toy(ToyKind)
    case wand

    var id: String {
        switch self {
        case .bomb(let k): return "bomb_\(k.rawValue)"
        case .soap: return "soap"
        case .sponge(let t): return "sponge_\(t.rawValue)"
        case .shower: return "shower"
        case .mask(let m): return "mask_\(m.rawValue)"
        case .cucumbers: return "cucumbers"
        case .towel: return "towel"
        case .mist: return "mist"
        case .toy(let t): return "toy_\(t.rawValue)"
        case .wand: return "wand"
        }
    }

    static func items(for category: SpaCategory) -> [SpaDockItem] {
        switch category {
        case .fizz:
            return BombKind.allCases.map { .bomb($0) } + [.soap]
        case .wash:
            return FoamTint.allCases.map { .sponge($0) } + [.shower]
        case .pamper:
            return MaskKind.allCases.map { .mask($0) } + [.cucumbers, .towel, .mist]
        case .toys:
            return ToyKind.allCases.map { .toy($0) } + [.wand]
        }
    }

    var tool: SpaTool? {
        switch self {
        case .soap: return .soap
        case .sponge(let t): return .sponge(t)
        case .shower: return .shower
        case .mask(let m): return .mask(m)
        case .cucumbers: return .cucumbers
        case .towel: return .towel
        case .mist: return .mist
        case .wand: return .wand
        case .bomb, .toy: return nil
        }
    }

    var thing: ThingKind? {
        switch self {
        case .bomb(let k): return .bomb(k)
        case .toy(let t): return .toy(t)
        default: return nil
        }
    }

    func drawIcon(in g: GraphicsContext) {
        var c = g
        switch self {
        case .bomb(let k):
            c.scaleBy(x: 0.92, y: 0.92)
            ThingPainter.bomb(c, k, fizz: 1, fizzing: false, time: 0.3)
        case .soap:
            c.scaleBy(x: 0.52, y: 0.52)
            c.translateBy(x: 0, y: 6)
            ToolPainter.soapBottle(c)
        case .sponge(let t):
            c.scaleBy(x: 0.56, y: 0.56)
            c.translateBy(x: 0, y: 6)
            ToolPainter.sponge(c, tint: t, foam: 0.9, t: 0)
        case .shower:
            c.scaleBy(x: 0.64, y: 0.64)
            SpaIconPainter.drawShowerIcon(c)
        case .mask(let k):
            c.scaleBy(x: 0.84, y: 0.84)
            c.translateBy(x: 0, y: 3)
            SpaIconPainter.drawMaskJar(c, kind: k)
        case .cucumbers:
            var l = c; l.translateBy(x: -13, y: 2); ToolPainter.cucumber(l, r: 16)
            var r = c; r.translateBy(x: 13, y: -2); ToolPainter.cucumber(r, r: 16)
        case .towel:
            c.scaleBy(x: 0.48, y: 0.48)
            ToolPainter.towel(c)
        case .mist:
            c.scaleBy(x: 0.64, y: 0.64)
            c.translateBy(x: 0, y: 4)
            ToolPainter.mistBottle(c)
        case .toy(let k):
            let s = min(0.76, 32 / max(k.half.width, k.half.height))
            c.scaleBy(x: s, y: s)
            var th = SThing(id: 0, kind: .toy(k), p: .zero)
            th.facing = 1
            ThingPainter.draw(c, th, time: 0)
        case .wand:
            c.scaleBy(x: 0.56, y: 0.56)
            ToolPainter.wand(c, tip: CGPoint(x: -10, y: -12), finger: CGPoint(x: 42, y: 48), v: .zero, t: 0.5)
        }
    }
}

private final class SpaHandState {
    var lastAt = Date()
    var startAt = Date()
    var active = false
}

// MARK: - Main Bubble Spa view

struct SpaView: View {
    let exit: () -> Void

    @State private var sim = SpaSim()
    @State private var category: SpaCategory = .fizz
    @State private var carryingID: String?
    @State private var hand = SpaHandState()
    @State private var started = false
    @State private var showBook = false

    var body: some View {
        ZStack {
            GameStage(background: { SpaBackdropView() }) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                        Canvas { ctx, _ in
                            sim.step(tl.date)
                            SpaPainter.draw(ctx, sim: sim)
                        }
                    }
                    .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                    .contentShape(Rectangle())
                    .gesture(sceneGesture)

                    wishBubbleOverlay

                    bottomDock
                        .position(x: GameChromeLayout.width / 2, y: GameChromeLayout.dockY)

                    GameTopBar(
                        gameID: SpaSim.gameID,
                        showStickerBook: true,
                        showCoins: true,
                        onExit: {
                            SpaSound.shared.stopLoops()
                            exit()
                        },
                        onStickerBook: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showBook = true
                            }
                        },
                        trailing: {
                            RoundButton(symbol: "arrow.counterclockwise", tint: Theme.sky, size: GameChromeLayout.buttonSize) {
                                Sound.shared.play(.whoosh, volume: 0.6)
                                Sound.shared.tap()
                                sim.resetBath()
                            }
                            .accessibilityLabel("Fresh Bath")
                        }
                    )

                    StickerToast(game: SpaSim.gameID, target: GameChromeLayout.stickerTarget)
                }
                .frame(width: GameChromeLayout.width, height: GameChromeLayout.height)
                .coordinateSpace(name: "spa")
                .coinPurse(game: SpaSim.gameID)
            }

            if showBook {
                StickerBookView(game: SpaSim.gameID) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showBook = false
                    }
                }
                .transition(.opacity)
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onDisappear {
            SpaSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = SpaSound.shared
        if ProcessInfo.processInfo.arguments.contains("-spaDemo") {
            applyLaunchArguments()
        } else {
            sim.prepareWarmBath()
        }
    }

    // MARK: - Optional Pictorial Spa Wish Bubble

    private var wishBubbleOverlay: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            let celebrating = sim.time < sim.wishCelebrateUntil
            let wish = sim.activeWish
            Button {
                Sound.shared.play(.pop, volume: 0.55)
                Sound.shared.tap()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    category = wish.category
                }
            } label: {
                PictorialWishBubble(size: 86) {
                    Canvas { ctx, size in
                        var g = ctx
                        g.translateBy(x: size.width / 2, y: size.height / 2)
                        if celebrating {
                            StorybookArt.heart(g, at: .zero, size: 38, color: Theme.pink)
                            StorybookArt.sparkle(g, at: CGPoint(x: -18, y: -16), radius: 8, color: Theme.lemon)
                            StorybookArt.sparkle(g, at: CGPoint(x: 20, y: 14), radius: 7, color: Theme.lemon)
                        } else {
                            SpaIconPainter.drawWish(wish, in: g)
                        }
                    }
                }
            }
            .buttonStyle(Squish())
            .position(SGeo.wishBubbleCenter)
        }
    }

    // MARK: - Unified Bottom Dock (4 Category Tabs + Active Items)

    private var bottomDock: some View {
        let items = SpaDockItem.items(for: category)
        let tileSize: CGFloat = items.count >= 7 ? 72 : 76
        let itemSpacing: CGFloat = items.count >= 7 ? 9 : 12

        return GameTrayCard(cornerRadius: 34, paddingH: 14, paddingV: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(SpaCategory.allCases) { tab in
                        let isSelected = category == tab
                        Button {
                            guard category != tab else { return }
                            Sound.shared.play(.pop, volume: 0.55)
                            Sound.shared.tap()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                category = tab
                            }
                        } label: {
                            GameDockTile(
                                size: 62,
                                selected: isSelected,
                                tint: isSelected ? Theme.blush.opacity(0.65) : .white,
                                cornerRadius: 20
                            ) {
                                Canvas { ctx, size in
                                    var g = ctx
                                    g.translateBy(x: size.width / 2, y: size.height / 2)
                                    SpaIconPainter.drawCategory(tab, in: g)
                                }
                                .allowsHitTesting(false)
                            }
                        }
                        .buttonStyle(Squish())
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.blush.opacity(0.32))
                )

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Theme.blush)
                    .frame(width: 3, height: 54)

                HStack(spacing: itemSpacing) {
                    ForEach(items) { item in
                        dockTile(item, size: tileSize)
                    }
                }
                .id(category)
                .transition(.opacity)
            }
        }
    }

    private func dockTile(_ item: SpaDockItem, size: CGFloat) -> some View {
        let isHidden = carryingID == item.id
        return GameDockTile(size: size, selected: false, tint: .white, cornerRadius: 22) {
            if !isHidden {
                Canvas { ctx, sz in
                    var g = ctx
                    g.translateBy(x: sz.width / 2, y: sz.height / 2)
                    item.drawIcon(in: g)
                }
                .allowsHitTesting(false)
            }
        }
        .opacity(isHidden ? 0.35 : 1)
        .contentShape(Rectangle())
        .gesture(dockItemGesture(item))
    }

    // MARK: - Gestures (Both Drag AND 1-Tap on Every Item!)

    private func dockItemGesture(_ item: SpaDockItem) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("spa"))
            .onChanged { v in
                let p = v.location
                let moved = hypot(v.translation.width, v.translation.height)
                if carryingID == nil {
                    guard moved >= 12 else { return }
                    carryingID = item.id
                    Sound.shared.tap()
                    if let thing = item.thing {
                        let id = sim.spawnThing(thing, at: p, held: true)
                        sim.hand = .thing(id)
                        sim.handP = p
                    } else if let tool = item.tool {
                        sim.pickUp(tool, finger: p, lifted: Self.lifted(p, tool))
                    }
                }
                if let tool = item.tool {
                    sim.carry(finger: p, lifted: Self.lifted(p, tool))
                } else {
                    sim.handMoved(p, dt: 1.0 / 60)
                }
            }
            .onEnded { v in
                let p = v.location
                if carryingID == nil {
                    performOneTap(item)
                    Sound.shared.tap()
                    return
                }
                if item.tool != nil {
                    sim.release()
                } else {
                    sim.handEnded(p, tap: false)
                }
                carryingID = nil
            }
    }

    private func performOneTap(_ item: SpaDockItem) {
        switch item {
        case .bomb(let k):
            sim.dropIn(.bomb(k))
        case .soap:
            sim.squirtBubbleBath()
        case .sponge(let tint):
            sim.applyNextFoamStyle(tint: tint)
        case .shower:
            sim.triggerQuickShower()
        case .mask(let kind):
            sim.applyFullMask(kind)
        case .cucumbers:
            sim.toggleCucumbers()
        case .towel:
            sim.applyCozyTowel()
        case .mist:
            sim.spritzMistBurst()
        case .toy(let k):
            sim.dropIn(.toy(k))
        case .wand:
            sim.blowWandBurst()
        }
    }

    private var sceneGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("spa"))
            .onChanged { v in
                let p = v.location
                let now = Date()
                if !hand.active {
                    hand.active = true
                    hand.startAt = now
                    hand.lastAt = now
                    sim.handBegan(p)
                } else {
                    let dt = CGFloat(max(1.0 / 120, now.timeIntervalSince(hand.lastAt)))
                    hand.lastAt = now
                    sim.handMoved(p, dt: dt)
                }
            }
            .onEnded { v in
                let p = v.location
                let moved = hypot(v.translation.width, v.translation.height)
                let tap = moved < 14 && Date().timeIntervalSince(hand.startAt) < 0.45
                sim.handEnded(p, tap: tap)
                hand.active = false
            }
    }

    static func lifted(_ p: CGPoint, _ tool: SpaTool) -> CGPoint {
        FingerLift.point(p, lift: lift(tool), bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }

    static func lift(_ tool: SpaTool) -> CGFloat {
        switch tool {
        case .wand, .mask: return FingerLift.tool
        case .shower: return FingerLift.pour
        case .sponge, .towel: return FingerLift.grip
        case .soap, .mist: return FingerLift.carry(below: 50)
        case .cucumbers: return FingerLift.item
        }
    }

    // MARK: - Screenshot hooks

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-spaDemo"), i + 1 < args.count else { return }
        sim.showcase(args[i + 1])
    }
}

extension SpaSim {
    /// Sets up a bath in progress for screenshots and tests.
    func showcase(_ what: String) {
        quiet = true
        demo = true
        prepareWarmBath()
        for k in fog.indices { fog[k] = 0.78 }
        _ = spawnThing(.toy(.boat), at: CGPoint(x: 690, y: level - 16), held: false)
        switch what {
        case "bomb":
            _ = spawnThing(.bomb(.galaxy), at: CGPoint(x: 520, y: level + 28), held: false)
            if let j = things.indices.last { things[j].wetFor = 2; things[j].fizz = 0.7 }
            for _ in 0..<180 { step(dt: 1.0 / 60) }
        case "mask":
            applyFullMask(.strawberry)
            putCucumbersOn()
        case "foam":
            applyNextFoamStyle(tint: .cloud)
        case "wand":
            blowWandBurst()
            pickUp(.wand, finger: CGPoint(x: 680, y: 460), lifted: CGPoint(x: 640, y: 360))
        case "towel":
            applyCozyTowel()
        default:
            tapOn = true
            flow = 1
            handleTurn = 1
            for _ in 0..<120 { step(dt: 1.0 / 60) }
        }
        for _ in 0..<24 { step(dt: 1.0 / 60) }
    }
}
