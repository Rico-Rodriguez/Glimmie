import AVFoundation
import SwiftUI

enum GardenGame {
    static let entry = GameEntry(
        id: GardenSim.gameID,
        title: "Garden",
        tint: Color(hex: 0xA8E07A),
        icon: { AnyView(GardenTileIcon()) },
        play: { exit in AnyView(GardenView(exit: exit)) },
        stickers: GardenFind.stickers
    )
}

private struct GardenTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = min(size.width, size.height) / 300
            g.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 300 * k) / 2)
            g.scaleBy(x: k, y: k)

            var mound = Path()
            mound.move(to: CGPoint(x: -10, y: 310))
            mound.addQuadCurve(to: CGPoint(x: 310, y: 310), control: CGPoint(x: 150, y: 194))
            mound.closeSubpath()
            StorybookArt.fillAndStroke(
                g, mound,
                fill: StorybookArt.color(0x9A6A43),
                stroke: StorybookArt.outline(for: 0x9A6A43),
                width: 6
            )

            let sun = Plant(kind: .sunflower, growth: 1, left: 1, variant: 0)
            var sg = g
            sg.translateBy(x: 108, y: 256)
            sg.scaleBy(x: 0.82, y: 0.82)
            GardenPlants.draw(sg, plant: sun, base: .zero, bend: -0.06, pop: 0, pull: 0, time: 0, droop: false)

            var cg = g
            cg.translateBy(x: 224, y: 176)
            cg.rotate(by: .radians(-0.22))
            cg.scaleBy(x: 0.78, y: 0.78)
            GardenPainter.can(cg)

            StorybookArt.sparkle(g, at: CGPoint(x: 244, y: 66), radius: 18, color: Theme.lemon, opacity: 0.95)
            StorybookArt.sparkle(g, at: CGPoint(x: 56, y: 74), radius: 12, color: .white, opacity: 0.9)
        }
    }
}

// MARK: - Sounds

enum GardenSFX: String, CaseIterable {
    case dig, toss, pat, seeds, water, splash, pluck, grow, basket, buzz, chirp, rain, wind, crickets, plunk, squeak, flutter, rustle
}

final class GardenSound {
    static let shared = GardenSound()
    private var players: [GardenSFX: [AVAudioPlayer]] = [:]
    private var loops: [GardenSFX: AVAudioPlayer] = [:]
    private var last: [GardenSFX: Date] = [:]
    static let looping: Set<GardenSFX> = [.water, .rain, .wind, .crickets, .buzz]

    private init() {
        _ = Sound.shared
        for s in GardenSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "Garden") else { continue }
            if GardenSound.looping.contains(s) {
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.numberOfLoops = -1
                p?.volume = 0
                p?.prepareToPlay()
                loops[s] = p
            } else {
                players[s] = (0..<3).compactMap { _ in
                    let p = try? AVAudioPlayer(contentsOf: url)
                    p?.prepareToPlay()
                    return p
                }
            }
        }
    }

    // Audio playback stays off the render thread so AVAudioPlayer seeks never stall a frame.
    private let queue = DispatchQueue(label: "garden.sound", qos: .userInitiated)
    private var loopLevel: [GardenSFX: Float] = [:]
    private var loopSent: [GardenSFX: Float] = [:]

    func play(_ s: GardenSFX, volume: Float = 0.9, gap: Double = 0) {
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

    func setLoop(_ s: GardenSFX, volume: Float) {
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

// MARK: - Dock & Screen

enum GardenTray: Equatable {
    case seeds, decor
}

enum GardenDockMode: Equatable {
    case hand
    case tray(GardenTray)
}

private enum DockSlot: String, CaseIterable {
    case shovel, can, seeds, decor

    var homePoint: CGPoint {
        switch self {
        case .shovel: return CGPoint(x: 371, y: GGeo.dockY)
        case .can: return CGPoint(x: 465, y: GGeo.dockY)
        case .seeds: return CGPoint(x: 559, y: GGeo.dockY)
        case .decor: return CGPoint(x: 653, y: GGeo.dockY)
        }
    }
}

private struct GardenDockIcon: View {
    let slot: DockSlot
    let hidden: Bool

    var body: some View {
        if !hidden {
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                switch slot {
                case .shovel:
                    g.rotate(by: .radians(0.5))
                    g.scaleBy(x: 0.34, y: 0.34)
                    g.translateBy(x: 0, y: 94)
                    GardenPainter.shovel(g, load: 0)
                case .can:
                    g.scaleBy(x: 0.4, y: 0.4)
                    g.translateBy(x: 28, y: -50)
                    GardenPainter.can(g)
                case .seeds:
                    var a = g
                    a.translateBy(x: -10, y: 2)
                    a.rotate(by: .radians(-0.2))
                    a.scaleBy(x: 0.56, y: 0.56)
                    GardenPainter.packet(a, kind: .tulip)
                    var b = g
                    b.translateBy(x: 11, y: 4)
                    b.rotate(by: .radians(0.18))
                    b.scaleBy(x: 0.56, y: 0.56)
                    GardenPainter.packet(b, kind: .sunflower)
                case .decor:
                    var a = g
                    a.translateBy(x: -14, y: 31)
                    a.scaleBy(x: 0.39, y: 0.39)
                    GardenDecorPainter.draw(a, GDecor(id: 0, kind: .pinwheel, x: 0, y: 0, spin: 0.4, held: true), time: 0, night: 0, wind: 0)
                    var b = g
                    b.translateBy(x: 15, y: 30)
                    b.scaleBy(x: 0.48, y: 0.48)
                    GardenDecorPainter.draw(b, GDecor(id: 0, kind: .mushroom, x: 0, y: 0, held: true), time: 0, night: 0, wind: 0)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

final class GardenHandState {
    var lastAt = Date()
    var startAt = Date()
    var active = false
}

struct GardenView: View {
    let exit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var sim = GardenSim()
    @State private var dockMode: GardenDockMode = .hand
    @State private var weather: Weather = .sun
    @State private var carrying: String?
    @State private var hidden: String?
    @State private var hand = GardenHandState()
    @State private var started = false
    @State private var auto = AutoTool()
    @State private var book = false
    @State private var showReturnBadge = false
    @State private var overReturnBadge = false

    var body: some View {
        GameStage {
            GeometryReader { geo in
                let map = GameStageMap(size: geo.size)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: book)) { _ in
                    Canvas(opaque: true) { ctx, _ in
                        GardenPainter.drawBackdrop(ctx, map: map, sim: sim)
                    }
                }
            }
            .allowsHitTesting(false)
        } content: {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: book)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        GardenPainter.drawWorld(ctx, sim: sim)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture)

                GameTopBar(
                    gameID: GardenSim.gameID,
                    showStickerBook: true,
                    showCoins: true,
                    onExit: {
                        auto.cancel()
                        sim.save()
                        GardenSound.shared.stopLoops()
                        exit()
                    },
                    onStickerBook: {
                        auto.cancel()
                        GardenSound.shared.stopLoops()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            book = true
                        }
                    },
                    trailing: { weatherBar }
                )

                if case .tray(let activeTray) = dockMode {
                    trayBar(activeTray)
                        .position(x: 512, y: GGeo.trayY)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                TimelineView(.animation(minimumInterval: 0.3, paused: book)) { _ in
                    dockBar(hint: dockMode == .hand && sim.tool == nil ? suggested : nil)
                }
                .position(x: 512, y: GGeo.dockY)

                if showReturnBadge {
                    ReturnDropBadge(hovered: overReturnBadge)
                        .position(GGeo.returnBadge)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                }

                StickerToast(game: GardenSim.gameID, target: GameChromeLayout.stickerTarget)
            }
            .coordinateSpace(name: "garden")
            .coinPurse(game: GardenSim.gameID)
        }
        .ignoresSafeArea()
        .overlay {
            if book {
                StickerBookView(game: GardenSim.gameID) {
                    withAnimation(.easeOut(duration: 0.2)) { book = false }
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: start)
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                auto.cancel()
                sim.save()
                GardenSound.shared.stopLoops()
            }
        }
        .onDisappear {
            auto.cancel()
            sim.save()
            GardenSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = GardenSound.shared
        weather = sim.weather
        applyLaunchArguments()
    }

    // MARK: Direct World Hand Gesture

    private var handGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("garden"))
            .onChanged { v in
                let p = v.location
                let now = Date()
                if !hand.active {
                    if auto.running { auto.cancel() }
                    if dockMode != .hand {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            dockMode = .hand
                        }
                    }
                    hand.active = true
                    hand.startAt = now
                    hand.lastAt = now
                    sim.handBegan(p)
                } else {
                    let dt = CGFloat(max(1.0 / 120, now.timeIntervalSince(hand.lastAt)))
                    hand.lastAt = now
                    sim.handMoved(p, dt: dt)
                }
                syncReturnBadge()
            }
            .onEnded { v in
                let p = v.location
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y)
                let tap = moved < 14 && Date().timeIntervalSince(hand.startAt) < 0.45
                sim.handEnded(p, tap: tap)
                hand.active = false
                syncReturnBadge()
            }
    }

    private func syncReturnBadge() {
        let show = sim.isDraggingDecor
        let over = sim.overReturnBadge
        if show != showReturnBadge {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                showReturnBadge = show
            }
        }
        if over != overReturnBadge {
            overReturnBadge = over
        }
    }

    // MARK: Weather Top-Bar Controls

    private var weatherBar: some View {
        HStack(spacing: 10) {
            ForEach(Weather.allCases, id: \.self) { w in
                let active = weather == w
                RoundButton(symbol: w.symbol, tint: w.tint, size: GameChromeLayout.buttonSize) {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    weather = w
                    sim.setWeather(w)
                }
                .overlay(
                    Circle()
                        .stroke(Theme.pink, lineWidth: 4.5)
                        .shadow(color: Theme.pink.opacity(0.6), radius: 7)
                        .opacity(active ? 1 : 0)
                )
                .scaleEffect(active ? 1.07 : 0.96)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: weather)
                .accessibilityLabel(w.rawValue.capitalized)
            }
        }
    }

    // MARK: Bottom Dock

    private var suggested: DockSlot? {
        if sim.plots.contains(where: { $0.plant != nil && $0.dry > 1.5 && ($0.plant?.growth ?? 1) < 1 }) {
            return .can
        }
        if sim.plots.allSatisfy({ $0.plant == nil }) {
            return .seeds
        }
        if !sim.weeds.isEmpty {
            return .shovel
        }
        return nil
    }

    private func dockBar(hint: DockSlot?) -> some View {
        GameTrayCard(cornerRadius: 32, paddingH: 14, paddingV: 10) {
            HStack(spacing: 12) {
                ForEach(DockSlot.allCases, id: \.rawValue) { slot in
                    let selected = (dockMode == .tray(.seeds) && slot == .seeds)
                        || (dockMode == .tray(.decor) && slot == .decor)
                    GameDockTile(
                        size: 82,
                        selected: selected,
                        pulsing: hint == slot && hidden != slot.rawValue
                    ) {
                        GardenDockIcon(slot: slot, hidden: hidden == slot.rawValue)
                    }
                    .opacity(hidden == slot.rawValue ? 0.35 : 1)
                    .contentShape(Rectangle())
                    .gesture(dockGesture(slot))
                    .accessibilityLabel(slot.rawValue.capitalized)
                }
            }
        }
    }

    private func dockGesture(_ slot: DockSlot) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("garden"))
            .onChanged { v in
                switch slot {
                case .seeds, .decor:
                    return
                case .shovel, .can:
                    if auto.running { auto.cancel() }
                    guard carrying != nil || !ToolTap.isTap(v.translation) else { return }
                    if dockMode != .hand { dockMode = .hand }
                    useTool(slot, v.location)
                }
            }
            .onEnded { v in
                switch slot {
                case .seeds, .decor:
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    auto.cancel()
                    let want: GardenTray = slot == .seeds ? .seeds : .decor
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                        dockMode = dockMode == .tray(want) ? .hand : .tray(want)
                    }
                case .shovel, .can:
                    if carrying != nil {
                        endTool(slot)
                        return
                    }
                    if dockMode != .hand {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            dockMode = .hand
                        }
                    }
                    if ToolTap.isTap(v.translation) {
                        Sound.shared.tap()
                        Sound.shared.play(.pop, volume: 0.6)
                        runAutoTool(slot)
                    }
                }
            }
    }

    private func useTool(_ slot: DockSlot, _ p: CGPoint) {
        if carrying == nil {
            carrying = slot.rawValue
            hidden = slot.rawValue
            Sound.shared.tap()
            sim.pickUp(slot == .shovel ? .shovel : .can, at: p)
        }
        if let tl = sim.tool {
            sim.carry(to: GardenView.lifted(p, tl), hand: p)
        }
    }

    private func endTool(_ slot: DockSlot) {
        sim.release(home: slot.homePoint)
        finishCarry(slot.rawValue)
    }

    private func runAutoTool(_ slot: DockSlot) {
        guard slot == .shovel || slot == .can else { return }
        if slot == .shovel {
            let target = sim.bestShovelTarget()
            let fingerSpot = FingerLift.finger(for: target, lift: GardenView.lift(.shovel), bottom: GameChromeLayout.height, width: GameChromeLayout.width)
            auto.run(from: slot.homePoint, to: fingerSpot, step: { p in
                if carrying == nil {
                    carrying = slot.rawValue
                    hidden = slot.rawValue
                    sim.pickUp(.shovel, at: p)
                    sim.autoShovelActive = true
                }
                if let tl = sim.tool {
                    sim.carry(to: GardenView.lifted(p, tl), hand: p)
                }
            }, end: { _ in
                sim.autoShovel(at: target)
                endTool(.shovel)
            })
        } else {
            let target = sim.bestWaterTarget()
            let pourPos = CGPoint(x: min(940, target.x + 84), y: max(220, target.y - 68))
            let fingerSpot = FingerLift.finger(for: pourPos, lift: GardenView.lift(.can), bottom: GameChromeLayout.height, width: GameChromeLayout.width)
            auto.run(from: slot.homePoint, to: fingerSpot, step: { p in
                useTool(.can, p)
            }, end: { _ in
                sim.waterPlant(at: target)
                endTool(.can)
            })
        }
    }

    static func lifted(_ p: CGPoint, _ tool: GardenTool) -> CGPoint {
        FingerLift.point(p, lift: lift(tool), bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }

    static func lift(_ tool: GardenTool) -> CGFloat {
        switch tool {
        case .shovel: return FingerLift.tool
        case .can: return FingerLift.carry(below: 106)
        case .seeds: return FingerLift.carry(below: 45)
        case .decor(let k): return FingerLift.carry(below: k.size.height * 0.5)
        }
    }

    private func finishCarry(_ key: String) {
        carrying = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            if carrying != key && hidden == key { hidden = nil }
        }
    }

    // MARK: Expandable Single-Row Horizontal Tray

    private func trayBar(_ t: GardenTray) -> some View {
        let count = t == .seeds ? PlantKind.allCases.count : DecorKind.available.count
        let maxScrollWidth: CGFloat = t == .seeds ? 656 : 736
        return GameTrayCard(cornerRadius: 28, paddingH: 12, paddingV: 8) {
            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<count, id: \.self) { i in
                            trayTile(t, index: i, count: count)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxWidth: min(maxScrollWidth, CGFloat(count) * 82))
                .frame(height: 76)

                Button {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.55)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        dockMode = .hand
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.pink))
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: Theme.ink.opacity(0.18), radius: 4, y: 2)
                }
                .buttonStyle(Squish())
                .accessibilityLabel("Close")
            }
        }
        .opacity(carrying?.hasPrefix("tray") == true ? 0.25 : 1)
    }

    private func trayTile(_ t: GardenTray, index i: Int, count: Int) -> some View {
        let key = "tray\(t == .seeds ? "S" : "D")\(i)"
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack {
            shape.fill(.white)
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                if t == .seeds {
                    g.scaleBy(x: 0.72, y: 0.72)
                    GardenPainter.packet(g, kind: PlantKind.allCases[i])
                } else {
                    let k = DecorKind.available[i]
                    let s = min(0.46, 58 / k.size.height)
                    g.translateBy(x: 0, y: k.size.height * s * 0.5)
                    g.scaleBy(x: s, y: s)
                    GardenDecorPainter.draw(g, GDecor(id: 0, kind: k, x: 0, y: 0, spin: 0.4, held: true), time: 0, night: 0, wind: 0)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: 72, height: 74)
        .clipShape(shape)
        .overlay(shape.stroke(Theme.blush, lineWidth: 2))
        .opacity(hidden == key ? 0.25 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if t == .seeds {
                let kind = PlantKind.allCases[i]
                let approxX = 512 + (CGFloat(i) - CGFloat(count - 1) / 2) * 82
                sim.tossSeed(kind, from: CGPoint(x: max(180, min(840, approxX)), y: GGeo.trayY - 24))
            } else {
                let kind = DecorKind.available[i]
                sim.placeDecorOnFreeSpot(kind)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .named("garden"))
                .onChanged { v in
                    // Require an upward pull when the tray scrolls horizontally so scrolling never spawns items accidentally.
                    let pullOut = v.translation.height < -14 || (count <= 8 && !ToolTap.isTap(v.translation))
                    guard carrying != nil || pullOut else { return }
                    let p = v.location
                    if carrying == nil {
                        carrying = key
                        hidden = key
                        Sound.shared.tap()
                        let tool: GardenTool = t == .seeds ? .seeds(PlantKind.allCases[i]) : .decor(DecorKind.available[i])
                        sim.pickUp(tool, at: p)
                    }
                    if let tl = sim.tool {
                        sim.carry(to: GardenView.lifted(p, tl), hand: p)
                    }
                    syncReturnBadge()
                }
                .onEnded { _ in
                    guard carrying == key else { return }
                    sim.release(home: t == .seeds ? DockSlot.seeds.homePoint : DockSlot.decor.homePoint)
                    carrying = nil
                    hidden = nil
                    syncReturnBadge()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                        dockMode = .hand
                    }
                }
        )
    }

    // MARK: Screenshot hooks

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-gardenDemo") || args.contains("-gardenWeather") || args.contains("-gardenTool") {
            sim.demo = true
            Coins.shared.demo = true
            StickerBook.shared.demo = true
        }
        if args.contains("-gardenDemo") { sim.showcase() }
        if let i = args.firstIndex(of: "-gardenWeather"), i + 1 < args.count, let w = Weather(rawValue: args[i + 1]) {
            weather = w
            sim.setWeather(w)
            sim.settleWeather()
        }
        if let i = args.firstIndex(of: "-gardenTool"), i + 1 < args.count {
            switch args[i + 1] {
            case "can":
                sim.pickUp(.can, at: CGPoint(x: 440, y: 380))
                hidden = DockSlot.can.rawValue
            case "shovel":
                sim.pickUp(.shovel, at: CGPoint(x: 500, y: 470))
                sim.load = 420
                hidden = DockSlot.shovel.rawValue
            default:
                sim.pickUp(.seeds(.sunflower), at: CGPoint(x: 500, y: 430))
            }
        }
    }
}

extension GardenSim {
    func showcase() {
        demo = true
        for i in h.indices { h[i] = GGeo.soilY + sin(CGFloat(i) * 0.21) * 1.1 }
        let kinds: [(PlantKind, Double, Int, Bool)] = [
            (.sunflower, 1, 1, false),
            (.tulip, 1, 1, false),
            (.tomato, 1, 4, false),
            (.carrot, 1, 1, false),
            (.strawberry, 1, 3, false),
            (.pumpkin, 1, 1, true),
        ]
        for (i, k) in kinds.enumerated() {
            plots[i].plant = Plant(kind: k.0, growth: k.1, left: k.2, variant: i, giant: k.3)
        }
        for i in 0..<GGeo.columns {
            let x = GGeo.colX(i)
            wet[i] = x > 320 && x < 560 ? 0.75 : 0.25
        }
        weeds = [GWeed(x: 308, growth: 1, seed: 2)]
        decor = []
        addDecor(.pinwheel, x: 180, falling: false)
        addDecor(.birdhouse, x: 460, falling: false)
        addDecor(.flamingo, x: 640, falling: false)
        addDecor(.lantern, x: 860, falling: false)
        addDecor(.mushroom, x: 90, falling: false)
        decor[1].poke = time
        bouquet = [
            BouquetFlower(kind: .sunflower, variant: 0),
            BouquetFlower(kind: .tulip, variant: 0),
            BouquetFlower(kind: .lavender, variant: 0),
            BouquetFlower(kind: .daisy, variant: 1),
        ]
        basket = ["tomato:0", "strawberry:0", "carrot:0", "daisy:1", "tomato:0", "pumpkin:0", "tulip:2"]
    }

    func settleWeather() {
        rain = weather == .rain ? 1 : 0
        night = weather == .night ? 1 : 0
        wind = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        cloud = weather == .rain ? 1 : (weather == .wind ? 0.45 : 0.12)
    }
}
