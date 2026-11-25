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
    private var missingLoops: Set<GardenSFX> = []
    private var last: [GardenSFX: Date] = [:]
    static let looping: Set<GardenSFX> = [.water, .rain, .wind, .crickets, .buzz]

    private init() {
        _ = Sound.shared
    }

    // Audio playback stays off the render thread so AVAudioPlayer seeks never stall a frame.
    private let queue = DispatchQueue(label: "garden.sound", qos: .userInitiated)
    private var loopLevel: [GardenSFX: Float] = [:]
    private var loopSent: [GardenSFX: Float] = [:]

    private func audioURL(for s: GardenSFX) -> URL? {
        GameFiles.url(s.rawValue, "caf", game: "Garden")
            ?? GameFiles.url(s.rawValue, "wav", game: "Garden")
    }

    private func playerPool(for s: GardenSFX) -> [AVAudioPlayer] {
        if let existing = players[s] { return existing }
        guard let url = audioURL(for: s) else {
            players[s] = []
            return []
        }
        let pool: [AVAudioPlayer] = (0..<3).compactMap { _ in
            let p = try? AVAudioPlayer(contentsOf: url)
            p?.prepareToPlay()
            return p
        }
        players[s] = pool
        return pool
    }

    private func loopPlayer(for s: GardenSFX) -> AVAudioPlayer? {
        if let existing = loops[s] { return existing }
        if missingLoops.contains(s) { return nil }
        guard let url = audioURL(for: s), let p = try? AVAudioPlayer(contentsOf: url) else {
            missingLoops.insert(s)
            return nil
        }
        p.numberOfLoops = -1
        p.volume = 0
        p.prepareToPlay()
        loops[s] = p
        return p
    }

    func play(_ s: GardenSFX, volume: Float = 0.9, gap: Double = 0) {
        let now = Date()
        queue.async {
            if gap > 0, let t = self.last[s], now.timeIntervalSince(t) < gap { return }
            self.last[s] = now
            let pool = self.playerPool(for: s)
            guard !pool.isEmpty else { return }
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = volume
            p.currentTime = 0
            p.play()
        }
    }

    func setLoop(_ s: GardenSFX, volume: Float) {
        guard GardenSound.looping.contains(s) else { return }
        let old = loopLevel[s] ?? 0
        let v = old + (volume - old) * 0.15
        loopLevel[s] = v
        let sent = loopSent[s] ?? 0
        let on = v > 0.01
        guard abs(v - sent) > 0.01 || (on != (sent > 0.01)) else { return }
        loopSent[s] = on ? v : 0
        queue.async {
            if on {
                guard let p = self.loopPlayer(for: s) else { return }
                p.volume = v
                if !p.isPlaying { p.play() }
            } else if let p = self.loops[s] {
                p.volume = 0
                if p.isPlaying { p.pause() }
            }
        }
    }

    func stopLoops() {
        for s in GardenSound.looping {
            loopLevel[s] = 0
            loopSent[s] = 0
        }
        queue.async {
            for p in self.loops.values {
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

    var hint: GardenDockHint {
        switch self {
        case .shovel: return .shovel
        case .can: return .can
        case .seeds: return .seeds
        case .decor: return .decor
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
    var autoCancelled = false
}

struct GardenView: View {
    let exit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var sim: GardenSim
    @State private var ui: GardenUIState
    @State private var dockMode: GardenDockMode = .hand
    @State private var carrying: String?
    @State private var hidden: String?
    @State private var draggedStockID: UUID?
    @State private var hand = GardenHandState()
    @State private var started = false
    @State private var auto = AutoTool()
    @State private var showBook = false
    @State private var showAlmanac = false

    init(exit: @escaping () -> Void) {
        self.exit = exit
        let initialSim = GardenSim()
        _sim = State(initialValue: initialSim)
        _ui = State(initialValue: initialSim.currentUIState())
    }

    private var canvasPaused: Bool { showBook || showAlmanac || scenePhase != .active }

    var body: some View {
        GameStage {
            GeometryReader { geo in
                let map = GameStageMap(size: geo.size)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: canvasPaused)) { _ in
                    Canvas(opaque: true) { ctx, _ in
                        GardenPainter.drawBackdrop(ctx, map: map, sim: sim)
                    }
                }
            }
            .allowsHitTesting(false)
        } content: {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: canvasPaused)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        GardenPainter.drawScene(ctx, sim: sim)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture)

                GameTopBar(
                    gameID: GardenSim.gameID,
                    showStickerBook: true,
                    showCoins: true,
                    onExit: {
                        cancelAutoTool()
                        cancelActiveStockDrag()
                        sim.onUIStateChange = nil
                        sim.save()
                        GardenSound.shared.stopLoops()
                        exit()
                    },
                    onStickerBook: {
                        cancelAutoTool()
                        cancelActiveStockDrag()
                        GardenSound.shared.stopLoops()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            showBook = true
                        }
                    },
                    center: { topCenterCluster },
                    trailing: { weatherBar }
                )

                if ui.station == .bed {
                    if case .tray(let activeTray) = dockMode {
                        trayBar(activeTray)
                            .position(x: 512, y: GGeo.trayY)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    dockBar(hint: dockMode == .hand ? ui.suggestedHint : nil)
                        .position(x: 512, y: GGeo.dockY)

                    if ui.showReturnBadge {
                        ReturnDropBadge(hovered: ui.overReturnBadge)
                            .position(GGeo.returnBadge)
                            .allowsHitTesting(false)
                            .transition(.scale.combined(with: .opacity))
                    }
                } else {
                    farmstandStockShelf
                        .position(x: 512, y: GGeo.dockY)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                StickerToast(game: GardenSim.gameID, target: GameChromeLayout.stickerTarget)
            }
            .coordinateSpace(name: "garden")
            .coinPurse(game: GardenSim.gameID)
        }
        .ignoresSafeArea()
        .defersSystemGestures(on: .bottom)
        .overlay {
            if showBook {
                StickerBookView(game: GardenSim.gameID) {
                    withAnimation(.easeOut(duration: 0.2)) { showBook = false }
                }
                .transition(.opacity)
            } else if showAlmanac {
                HybridAlmanacView(discovered: ui.discoveredHybrids) {
                    withAnimation(.easeOut(duration: 0.2)) { showAlmanac = false }
                }
                .transition(.opacity)
            }
        }
        .onAppear(perform: start)
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                cancelAutoTool()
                cancelActiveStockDrag()
                sim.save()
                GardenSound.shared.stopLoops()
            }
        }
        .onDisappear {
            cancelAutoTool()
            cancelActiveStockDrag()
            sim.onUIStateChange = nil
            sim.save()
            GardenSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = GardenSound.shared
        sim.onUIStateChange = { next in
            ui = next
        }
        applyLaunchArguments()
        ui = sim.currentUIState()
    }

    private func cancelAutoTool() {
        guard auto.running else { return }
        hand.autoCancelled = true
        auto.cancel()
        hand.autoCancelled = false
    }

    private func cancelActiveStockDrag() {
        sim.cancelStockItemDrag()
        draggedStockID = nil
    }

    // MARK: Direct World Hand Gesture

    private var handGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("garden"))
            .onChanged { v in
                let p = v.location
                let now = Date()
                if !hand.active {
                    if auto.running { cancelAutoTool() }
                    if dockMode != .hand {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            dockMode = .hand
                        }
                    }
                    hand.active = true
                    hand.startAt = now
                    hand.lastAt = now
                    sim.handleSceneDragChanged(p, startLocation: v.startLocation, dt: 1.0 / 60)
                } else {
                    let dt = CGFloat(max(1.0 / 120, now.timeIntervalSince(hand.lastAt)))
                    hand.lastAt = now
                    sim.handleSceneDragChanged(p, startLocation: v.startLocation, dt: dt)
                }
            }
            .onEnded { v in
                let dur = Date().timeIntervalSince(hand.startAt)
                sim.handleSceneDragEnded(v.location, startLocation: v.startLocation, duration: dur)
                hand.active = false
            }
    }

    // MARK: Top Bar Cluster (Station Toggle, Pictorial Order Pill, Hybrid Almanac)

    private var topCenterCluster: some View {
        HStack(spacing: 8) {
            stationTogglePill
            if let order = ui.activeOrder {
                orderPreviewPill(order)
            }
            hybridAlmanacButton
        }
    }

    private var stationTogglePill: some View {
        HStack(spacing: 4) {
            stationTabButton(.bed)
            stationTabButton(.farmstand)
        }
        .padding(5)
        .background(Capsule().fill(Theme.cream.opacity(0.96)))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 3))
        .shadow(color: Theme.ink.opacity(0.16), radius: 5, y: 3)
    }

    private func stationTabButton(_ target: GardenStation) -> some View {
        let active = ui.station == target
        let readyBadge = target == .farmstand && ui.station == .bed && ui.orderReadyInInventory
        return Button {
            cancelAutoTool()
            cancelActiveStockDrag()
            dockMode = .hand
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                sim.setStation(target)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(active ? (target == .bed ? Color(hex: 0x7ED87E) : Theme.pink) : .white)
                StationIconView(station: target, active: active)
                    .frame(width: 28, height: 28)
            }
            .frame(width: 44, height: 44)
            .overlay(Circle().stroke(active ? .white : Theme.blush, lineWidth: active ? 2.5 : 1.5))
            .overlay(alignment: .topTrailing) {
                if readyBadge {
                    ZStack {
                        Circle().fill(Theme.lemon)
                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(Squish())
        .accessibilityLabel(target == .bed ? "Garden Bed" : "Farmstand")
    }

    private func orderPreviewPill(_ order: FarmstandOrder) -> some View {
        var rawPool = ui.inventory + (sim.activeDraft?.items ?? [])
        if let dragged = ui.draggedStockItem, !rawPool.contains(where: { $0.id == dragged.id }) {
            rawPool.append(dragged)
        }
        let pool = rawPool.filter { order.kind.accepts($0) }
        let previewMatch = FarmstandMatcher.match(requirements: order.requirements, items: pool)
        let activeMatches = ui.station == .farmstand ? ui.draftMatchedSlots : previewMatch.slotMatched
        return Button {
            cancelAutoTool()
            cancelActiveStockDrag()
            dockMode = .hand
            if ui.station != .farmstand {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    sim.setStation(.farmstand)
                }
            } else {
                Sound.shared.tap()
                sim.playVisitorSound(order.customer)
            }
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(Theme.cream)
                    Canvas { ctx, size in
                        var g = ctx
                        g.translateBy(x: size.width / 2, y: size.height * 0.78)
                        let s: CGFloat = order.customer == .hummingbird ? 0.42 : 0.36
                        g.scaleBy(x: s, y: s)
                        GardenVisitorPainter.draw(g, GVisitor(kind: order.customer, p: .zero, facing: 1, seed: 1), time: 0, night: 0)
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Theme.blush, lineWidth: 2))

                ForEach(Array(order.requirements.enumerated()), id: \.offset) { idx, req in
                    let done = idx < activeMatches.count && activeMatches[idx]
                    ZStack {
                        Circle()
                            .fill(done ? Color(hex: 0xE6FFF1) : .white)
                        Canvas { ctx, size in
                            GardenPlants.drawRequirement(
                                ctx,
                                requirement: req,
                                at: CGPoint(x: size.width / 2, y: size.height / 2),
                                size: 0.56,
                                time: 0
                            )
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(done ? Color(hex: 0x3CC48A) : Theme.blush, lineWidth: done ? 2.5 : 1.5))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.cream.opacity(0.96)))
            .overlay(
                Capsule()
                    .stroke(ui.orderReadyInInventory ? Theme.lemon : Theme.blush, lineWidth: ui.orderReadyInInventory ? 3.5 : 2.8)
            )
            .shadow(color: Theme.ink.opacity(0.16), radius: 5, y: 3)
        }
        .buttonStyle(Squish())
        .accessibilityLabel("Farmstand Order")
    }

    private var hybridAlmanacButton: some View {
        let discovered = Set(ui.discoveredHybrids)
        let recent = ui.hasRecentHybridDiscovery
        return Button {
            Sound.shared.play(.flip, volume: 0.65)
            Sound.shared.tap()
            cancelAutoTool()
            cancelActiveStockDrag()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                showAlmanac = true
            }
        } label: {
            ZStack {
                Circle().fill(Theme.cream)
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let ringR: CGFloat = 15
                    for (idx, h) in HybridKind.allCases.enumerated() {
                        let a = CGFloat(idx) / 6 * 2 * .pi - .pi / 2
                        let pt = CGPoint(x: c.x + cos(a) * ringR, y: c.y + sin(a) * ringR)
                        let found = discovered.contains(h)
                        let dot = Path(ellipseIn: CGRect(x: pt.x - 5.2, y: pt.y - 5.2, width: 10.4, height: 10.4))
                        ctx.fill(dot, with: .color(found ? h.primaryColor.color : Theme.blush.opacity(0.65)))
                        ctx.stroke(dot, with: .color(.white), lineWidth: 1.2)
                    }
                    StorybookArt.sparkle(ctx, at: c, radius: 7.5, color: Theme.lemon, opacity: 0.95)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 52, height: 52)
            .overlay(
                Circle()
                    .stroke(recent ? Theme.lemon : Theme.blush, lineWidth: recent ? 4 : 3)
                    .shadow(color: recent ? Theme.lemon.opacity(0.75) : .clear, radius: 6)
            )
            .shadow(color: Theme.ink.opacity(0.16), radius: 5, y: 3)
            .scaleEffect(recent ? 1.06 : 1.0)
        }
        .buttonStyle(Squish())
        .accessibilityLabel("Hybrids")
    }

    private var weatherBar: some View {
        let btnSize: CGFloat = 50
        return HStack(spacing: 6) {
            Button {
                Sound.shared.tap()
                Sound.shared.play(.pop, volume: 0.6)
                sim.cycleSeason()
            } label: {
                ZStack {
                    Circle().fill(.white)
                    SeasonButtonIcon(season: ui.season)
                        .frame(width: btnSize * 0.66, height: btnSize * 0.66)
                }
                .frame(width: btnSize, height: btnSize)
                .overlay(Circle().stroke(ui.season.tint, lineWidth: 3.8))
                .shadow(color: Theme.ink.opacity(0.18), radius: 5, y: 3)
            }
            .buttonStyle(Squish())
            .accessibilityLabel(ui.season.rawValue.capitalized)

            ForEach(Weather.allCases, id: \.self) { w in
                let active = ui.weather == w
                RoundButton(symbol: w.symbol, tint: w.tint, size: btnSize) {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    sim.setWeather(w)
                }
                .overlay(
                    Circle()
                        .stroke(Theme.pink, lineWidth: 3.8)
                        .shadow(color: Theme.pink.opacity(0.55), radius: 6)
                        .opacity(active ? 1 : 0)
                )
                .scaleEffect(active ? 1.05 : 0.96)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: ui.weather)
                .accessibilityLabel(w.rawValue.capitalized)
            }
        }
    }

    // MARK: Bed Bottom Dock

    private func dockBar(hint: GardenDockHint?) -> some View {
        GameTrayCard(cornerRadius: 32, paddingH: 14, paddingV: 10) {
            HStack(spacing: 12) {
                ForEach(DockSlot.allCases, id: \.rawValue) { slot in
                    let selected = (dockMode == .tray(.seeds) && slot == .seeds)
                        || (dockMode == .tray(.decor) && slot == .decor)
                    GameDockTile(
                        size: 82,
                        selected: selected,
                        pulsing: hint == slot.hint && hidden != slot.rawValue
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
                    if auto.running { cancelAutoTool() }
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
                    cancelAutoTool()
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
        }
        sim.handleDockToolDragChanged(slot == .shovel ? .shovel : .can, finger: p)
    }

    private func endTool(_ slot: DockSlot) {
        sim.handleDockToolDragEnded(home: slot.homePoint)
        finishCarry(slot.rawValue)
    }

    private func runAutoTool(_ slot: DockSlot) {
        guard slot == .shovel || slot == .can else { return }
        cancelAutoTool()
        hand.autoCancelled = false
        if slot == .shovel {
            let target = sim.bestShovelTarget()
            let fingerSpot = GardenSim.fingerPoint(for: target, lift: GardenSim.lift(for: .shovel))
            auto.run(from: slot.homePoint, to: fingerSpot, step: { p in
                if carrying == nil {
                    carrying = slot.rawValue
                    hidden = slot.rawValue
                    sim.pickUp(.shovel, at: p)
                    sim.autoShovelActive = true
                }
                sim.handleDockToolDragChanged(.shovel, finger: p)
            }, end: { _ in
                if !hand.autoCancelled {
                    sim.autoShovel(at: target)
                }
                endTool(.shovel)
            })
        } else {
            let target = sim.bestWaterTarget()
            let pourPos = CGPoint(x: min(940, target.x + 84), y: max(220, target.y - 68))
            let fingerSpot = GardenSim.fingerPoint(for: pourPos, lift: GardenSim.lift(for: .can))
            auto.run(from: slot.homePoint, to: fingerSpot, step: { p in
                useTool(.can, p)
            }, end: { _ in
                if !hand.autoCancelled {
                    sim.waterPlant(at: target)
                }
                endTool(.can)
            })
        }
    }

    private func finishCarry(_ key: String) {
        carrying = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            if carrying != key && hidden == key { hidden = nil }
        }
    }

    // MARK: Bed Expandable Tray

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
                .scrollDisabled(carrying != nil)

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
            DragGesture(minimumDistance: 10, coordinateSpace: .named("garden"))
                .onChanged { v in
                    let pullOut = v.translation.height < -12 && abs(v.translation.height) >= abs(v.translation.width) * 0.55
                    guard carrying != nil || pullOut else { return }
                    let p = v.location
                    let tool: GardenTool = t == .seeds ? .seeds(PlantKind.allCases[i]) : .decor(DecorKind.available[i])
                    if carrying == nil {
                        carrying = key
                        hidden = key
                        Sound.shared.tap()
                    }
                    sim.handleDockToolDragChanged(tool, finger: p)
                }
                .onEnded { _ in
                    guard carrying == key else { return }
                    sim.handleDockToolDragEnded(home: t == .seeds ? DockSlot.seeds.homePoint : DockSlot.decor.homePoint)
                    carrying = nil
                    hidden = nil
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                        dockMode = .hand
                    }
                }
        )
    }

    // MARK: Farmstand Stock Shelf

    private var farmstandStockShelf: some View {
        let order = ui.activeOrder
        var shelfPool = ui.inventory
        if let dragged = ui.draggedStockItem, !shelfPool.contains(where: { $0.id == dragged.id }) {
            shelfPool.append(dragged)
        }
        let sortedItems = shelfPool.sorted { a, b in
            let aOk = order?.kind.accepts(a) ?? true
            let bOk = order?.kind.accepts(b) ?? true
            if aOk != bOk { return aOk }
            if a.isGiant != b.isGiant { return a.isGiant }
            return a.id.uuidString < b.id.uuidString
        }
        let hasAccepted = sortedItems.contains { order?.kind.accepts($0) ?? true }

        return GameTrayCard(cornerRadius: 30, paddingH: 14, paddingV: 10) {
            HStack(spacing: 12) {
                if !hasAccepted {
                    goGrowShortcutTile
                }

                if !sortedItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(sortedItems) { item in
                                let accepted = order?.kind.accepts(item) ?? true
                                farmstandStockTile(item, accepted: accepted)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: 680)
                    .frame(height: 82)
                    .scrollDisabled(draggedStockID != nil)
                }

                if ui.draftItemCount > 0 && !ui.isCelebrating {
                    Button {
                        Sound.shared.play(.whoosh, volume: 0.5)
                        Sound.shared.tap()
                        cancelActiveStockDrag()
                        sim.clearDraft()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Theme.peach))
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(color: Theme.ink.opacity(0.18), radius: 4, y: 2)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel("Return Items")
                }

                if hasAccepted {
                    goGrowShortcutTile
                }
            }
        }
    }

    private var goGrowShortcutTile: some View {
        Button {
            cancelActiveStockDrag()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                sim.setStation(.bed)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: 0xE8F9DF))
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    g.scaleBy(x: 0.62, y: 0.62)
                    GardenPainter.packet(g, kind: .tulip)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 76, height: 78)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: 0x7ED87E), lineWidth: 3))
            .shadow(color: Theme.ink.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(Squish())
        .accessibilityLabel("Back to Garden")
    }

    private func farmstandStockTile(_ item: HarvestItem, accepted: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let isDragging = draggedStockID == item.id || ui.draggedStockItem?.id == item.id
        return ZStack {
            shape.fill(accepted ? .white : Theme.cream.opacity(0.75))
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2 + 2)
                GardenPlants.drawHarvestItem(ctx, item: item, at: center, size: item.isGiant ? 0.85 : 0.92, rot: 0, time: 0)
            }
            .allowsHitTesting(false)
        }
        .frame(width: 76, height: 78)
        .clipShape(shape)
        .overlay(
            shape.stroke(
                item.isGiant ? Theme.lemon : (accepted ? Theme.pink.opacity(0.65) : Theme.blush),
                lineWidth: item.isGiant ? 3.5 : 2.5
            )
        )
        .opacity(isDragging ? 0.28 : (accepted ? 1.0 : 0.42))
        .contentShape(Rectangle())
        .onTapGesture {
            guard draggedStockID == nil else { return }
            _ = sim.addStockItemToDraft(item.id)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .named("garden"))
                .onChanged { v in
                    let pullOut = v.translation.height < -10 && abs(v.translation.height) >= abs(v.translation.width) * 0.5
                    guard draggedStockID != nil || pullOut else { return }
                    if draggedStockID == nil {
                        if sim.beginStockItemDrag(item.id, finger: v.location) {
                            draggedStockID = item.id
                        }
                    } else if draggedStockID == item.id {
                        sim.moveStockItemDrag(finger: v.location)
                    }
                }
                .onEnded { v in
                    guard draggedStockID == item.id else { return }
                    sim.endStockItemDrag(finger: v.location)
                    draggedStockID = nil
                }
        )
    }

    // MARK: Screenshot hooks

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-gardenDemo") || args.contains("-gardenWeather") || args.contains("-gardenTool") || args.contains("-gardenFarmstand") {
            sim.demo = true
            Coins.shared.demo = true
            StickerBook.shared.demo = true
        }
        if args.contains("-gardenDemo") { sim.showcase() }
        if args.contains("-gardenFarmstand") {
            sim.showcase()
            sim.setStation(.farmstand)
        }
        if let i = args.firstIndex(of: "-gardenWeather"), i + 1 < args.count, let w = Weather(rawValue: args[i + 1]) {
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
        let kinds: [(PlantKind, Int, Bool)] = [
            (.sunflower, 1, false),
            (.tulip, 1, false),
            (.tomato, 3, false),
            (.carrot, 1, false),
            (.strawberry, 3, false),
            (.pumpkin, 1, true),
        ]
        for (i, k) in kinds.enumerated() {
            plots[i].stage = .ripe(RipePlant(kind: k.0, variant: i, yieldLeft: k.1, isGiant: k.2))
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
        inventory = [
            HarvestItem(source: .plant(kind: .tomato, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .strawberry, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .carrot, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .pumpkin, variant: 0, isGiant: true)),
            HarvestItem(source: .plant(kind: .sunflower, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .tulip, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .lavender, variant: 0, isGiant: false)),
            HarvestItem(source: .plant(kind: .daisy, variant: 1, isGiant: false)),
        ]
        markUIStateDirty()
    }

    func settleWeather() {
        rain = weather == .rain ? 1 : 0
        night = weather == .night ? 1 : 0
        wind = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        cloud = weather == .rain ? 1 : (weather == .wind ? 0.45 : 0.12)
    }
}

// MARK: - Pictorial Station Icon, Season Icon & Wordless Hybrid Almanac

private struct StationIconView: View {
    let station: GardenStation
    let active: Bool

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            switch station {
            case .bed:
                GardenPlants.drawCrop(g, kind: .tulip, variant: 0, at: CGPoint(x: 0, y: 1), size: 0.48, rot: 0)
            case .farmstand:
                let top = Path(roundedRect: CGRect(x: -11, y: -10, width: 22, height: 8), cornerRadius: 3)
                StorybookArt.fillAndStroke(g, top, fill: active ? .white : Theme.pink, stroke: StorybookArt.outline(for: 0xFF8FB8), width: 1.5)
                let box = Path(roundedRect: CGRect(x: -9, y: -1, width: 18, height: 11), cornerRadius: 2.5)
                StorybookArt.fillAndStroke(g, box, fill: active ? Theme.lemon : Color(hex: 0xE6B07A), stroke: StorybookArt.outline(for: 0xC6884E), width: 1.5)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SeasonButtonIcon: View {
    let season: GardenSeason

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let r = min(size.width, size.height) * 0.5
            g.translateBy(x: size.width / 2, y: size.height / 2)
            switch season {
            case .spring:
                for i in 0..<5 {
                    var pg = g
                    pg.rotate(by: .radians(Double(i) * 2 * .pi / 5))
                    let pet = Path(ellipseIn: CGRect(x: -r * 0.26, y: -r * 0.88, width: r * 0.52, height: r * 0.72))
                    StorybookArt.fillAndStroke(pg, pet, fill: Color(hex: 0xFFB0CE), stroke: StorybookArt.outline(for: 0xFF8FB8), width: 1.4)
                }
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.22, y: -r * 0.22, width: r * 0.44, height: r * 0.44)), with: .color(Theme.lemon))
            case .summer:
                for i in 0..<4 {
                    var pg = g
                    pg.rotate(by: .radians(Double(i) * .pi / 2 + .pi / 4))
                    let leaf = Path(ellipseIn: CGRect(x: -r * 0.28, y: -r * 0.84, width: r * 0.56, height: r * 0.68))
                    StorybookArt.fillAndStroke(pg, leaf, fill: Color(hex: 0x68CE62), stroke: StorybookArt.outline(for: 0x4EA648), width: 1.4)
                }
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.24, y: -r * 0.24, width: r * 0.48, height: r * 0.48)), with: .color(Color(hex: 0xFFD94A)))
            case .autumn:
                var leaf = Path()
                leaf.move(to: CGPoint(x: 0, y: -r * 0.88))
                leaf.addLine(to: CGPoint(x: r * 0.24, y: -r * 0.36))
                leaf.addLine(to: CGPoint(x: r * 0.82, y: -r * 0.42))
                leaf.addLine(to: CGPoint(x: r * 0.42, y: r * 0.02))
                leaf.addLine(to: CGPoint(x: r * 0.66, y: r * 0.46))
                leaf.addLine(to: CGPoint(x: r * 0.12, y: r * 0.36))
                leaf.addLine(to: CGPoint(x: 0, y: r * 0.86))
                leaf.addLine(to: CGPoint(x: -r * 0.12, y: r * 0.36))
                leaf.addLine(to: CGPoint(x: -r * 0.66, y: r * 0.46))
                leaf.addLine(to: CGPoint(x: -r * 0.42, y: r * 0.02))
                leaf.addLine(to: CGPoint(x: -r * 0.82, y: -r * 0.42))
                leaf.addLine(to: CGPoint(x: -r * 0.24, y: -r * 0.36))
                leaf.closeSubpath()
                StorybookArt.shape(g, leaf, hex: 0xF08B36, width: 1.6)
            case .winter:
                for i in 0..<6 {
                    var sg = g
                    sg.rotate(by: .radians(Double(i) * .pi / 3))
                    var arm = Path()
                    arm.move(to: .zero)
                    arm.addLine(to: CGPoint(x: 0, y: -r * 0.84))
                    arm.move(to: CGPoint(x: -r * 0.22, y: -r * 0.62))
                    arm.addLine(to: CGPoint(x: 0, y: -r * 0.46))
                    arm.addLine(to: CGPoint(x: r * 0.22, y: -r * 0.62))
                    sg.stroke(arm, with: .color(Color(hex: 0x58B4F2)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                }
                g.fill(Path(ellipseIn: CGRect(x: -r * 0.16, y: -r * 0.16, width: r * 0.32, height: r * 0.32)), with: .color(Color(hex: 0xB8E6FF)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct HybridAlmanacView: View {
    let discovered: [HybridKind]
    let close: () -> Void

    @State private var shown = false
    @State private var pokedHybrid: HybridKind?

    var body: some View {
        let foundSet = Set(discovered)
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: shut)
            DesignCanvas {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        ForEach(HybridKind.allCases, id: \.self) { h in
                            let has = foundSet.contains(h)
                            Image(systemName: has ? "star.fill" : "star")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(has ? Theme.lemon : Theme.ink.opacity(0.2))
                                .shadow(color: has ? Theme.ink.opacity(0.22) : .clear, radius: 1, y: 1)
                        }
                    }
                    .padding(.top, 24)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(HybridKind.allCases, id: \.self) { h in
                            recipeCard(h, found: foundSet.contains(h))
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 26)
                }
                .frame(width: 780, height: 550)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 42, style: .continuous).stroke(.white, lineWidth: 8))
                .shadow(color: Theme.ink.opacity(0.32), radius: 18, y: 10)
                .overlay(alignment: .topTrailing) {
                    Button(action: shut) {
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
                    .offset(x: 16, y: -16)
                }
                .scaleEffect(shown ? 1 : 0.86)
                .opacity(shown ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                shown = true
            }
        }
    }

    private func recipeCard(_ h: HybridKind, found: Bool) -> some View {
        let (parentA, parentB) = h.parents
        let active = pokedHybrid == h
        return Button {
            Sound.shared.play(found ? .sparkle : .tap, volume: 0.55)
            Sound.shared.tap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                pokedHybrid = h
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if pokedHybrid == h {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        pokedHybrid = nil
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                parentIcon(parentA)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.pink)
                parentIcon(parentB)
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Theme.lilac)
                ZStack {
                    Circle()
                        .fill(found ? Color(hex: 0xFFFBF0) : Theme.blush.opacity(0.32))
                        .overlay(Circle().stroke(found ? Theme.lemon : Theme.blush, lineWidth: found ? 3.5 : 2))
                    Canvas { ctx, size in
                        var g = ctx
                        g.translateBy(x: size.width / 2, y: size.height / 2)
                        if found {
                            GardenPlants.drawHybridIcon(g, hybrid: h, at: .zero, size: 1.0, rot: 0, time: 0.4)
                        } else {
                            g.opacity = 0.24
                            GardenPlants.drawHybridIcon(g, hybrid: h, at: .zero, size: 0.92, rot: 0, time: 0)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: 86, height: 86)
                .scaleEffect(active ? 1.12 : 1.0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 126, maxHeight: 126)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(found ? Theme.lemon : Theme.blush, lineWidth: found ? 4 : 2.5)
            )
            .shadow(color: Theme.ink.opacity(0.1), radius: 6, y: 3)
        }
        .buttonStyle(Squish())
    }

    private func parentIcon(_ kind: PlantKind) -> some View {
        ZStack {
            Circle()
                .fill(Theme.cream)
                .overlay(Circle().stroke(Theme.blush, lineWidth: 2))
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                GardenPlants.drawCrop(g, kind: kind, variant: 0, at: .zero, size: kind == .pumpkin ? 0.68 : 0.92, rot: 0)
            }
            .allowsHitTesting(false)
        }
        .frame(width: 64, height: 64)
    }

    private func shut() {
        Sound.shared.play(.flip, volume: 0.6)
        close()
    }
}
