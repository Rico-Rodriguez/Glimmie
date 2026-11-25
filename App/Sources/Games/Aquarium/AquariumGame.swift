import AVFoundation
import SwiftUI

enum AquariumGame {
    static let entry = GameEntry(
        id: AquariumSim.gameID,
        title: "Aquarium",
        tint: Color(hex: 0x7FD3F2),
        icon: { AnyView(AquariumTileIcon()) },
        play: { exit in AnyView(AquariumView(exit: exit)) },
        stickers: AquaFind.stickers
    )
}

private struct AquariumTileIcon: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000))
                var g = ctx
                let k = min(size.width, size.height) / 300
                g.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 300 * k) / 2)
                g.scaleBy(x: k, y: k)

                // Soft luminous water shimmer behind the fish.
                g.fill(
                    Path(ellipseIn: CGRect(x: 34, y: 24, width: 232, height: 196)),
                    with: .radialGradient(
                        Gradient(colors: [Color(hex: 0xD8F8FF).opacity(0.45), .clear]),
                        center: CGPoint(x: 150, y: 112),
                        startRadius: 12,
                        endRadius: 116
                    )
                )

                var sand = Path()
                sand.move(to: CGPoint(x: -10, y: 310))
                sand.addQuadCurve(to: CGPoint(x: 310, y: 310), control: CGPoint(x: 150, y: 214))
                sand.closeSubpath()
                StorybookArt.fillAndStroke(
                    g, sand,
                    fill: StorybookArt.color(0xF5E0B4),
                    stroke: StorybookArt.outline(for: 0xE2C182),
                    width: 6
                )
                StorybookArt.highlight(g, in: CGRect(x: 92, y: 258, width: 116, height: 12), opacity: 0.36)

                var sw = g
                sw.translateBy(x: 64, y: 294)
                sw.scaleBy(x: 0.56, y: 0.56)
                AquaDecorPainter.seaweed(sw, t: t, sway: 0, seed: 1)

                var sh = g
                sh.translateBy(x: 234, y: 288)
                sh.scaleBy(x: 0.56, y: 0.56)
                AquaDecorPainter.shell(sh)

                var f = g
                f.translateBy(x: 156, y: 140 + sin(t * 1.3) * 6)
                f.scaleBy(x: 1.88, y: 1.88)
                AquaFishPainter.drawLocal(f, kind: .goldfish, variant: 0, phase: t * 6, amp: 0.25, gulp: 0, puff: 0, time: t)

                for i in 0..<4 {
                    let y = 200 - (t * 40 + CGFloat(i) * 50).truncatingRemainder(dividingBy: 185)
                    let x = 244 + sin(t * 3 + CGFloat(i) * 1.4) * 6 - CGFloat(i % 2) * 12
                    let r: CGFloat = 8 + CGFloat(i % 2) * 4.5
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    g.fill(Path(ellipseIn: rect), with: .color(StorybookArt.color(0xD8F8FF, alpha: 0.42)))
                    g.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.92)), lineWidth: 3)
                    StorybookArt.highlight(g, in: CGRect(x: x - r * 0.55, y: y - r * 0.58, width: r * 0.52, height: r * 0.34), opacity: 0.92)
                }

                StorybookArt.sparkle(g, at: CGPoint(x: 232, y: 64), radius: 15 * (0.85 + 0.15 * sin(t * 3.8)), color: Theme.lemon)
                StorybookArt.sparkle(g, at: CGPoint(x: 68, y: 82), radius: 10 * (0.85 + 0.15 * cos(t * 3.2)), color: .white)
            }
        }
    }
}

// MARK: - Sounds

enum AquaSFX: String, CaseIterable {
    case bloop, pop, plop, splash, splish, gulp, squeak, tink, thud, shake, puff, swish, chime, blub, creak, bag, pick, click, boing
    case hum, pump
}

final class AquaSound {
    static let shared = AquaSound()
    static let looping: Set<AquaSFX> = [.hum, .pump]
    private static let maxPoolSize = 2

    private var players: [AquaSFX: [AVAudioPlayer]] = [:]
    private var loops: [AquaSFX: AVAudioPlayer] = [:]
    private var missing: Set<AquaSFX> = []
    private var last: [AquaSFX: TimeInterval] = [:]
    private var recentSeeks: [TimeInterval] = []
    private let queue = DispatchQueue(label: "aquarium.sound", qos: .userInitiated)
    private let loopLock = NSLock()
    private var loopLevel: [AquaSFX: Float] = [:]
    private var loopSent: [AquaSFX: Float] = [:]

    private init() {
        _ = Sound.shared
    }

    static func minimumGap(for s: AquaSFX) -> Double {
        switch s {
        case .chime: return 0.25
        case .plop: return 0.14
        case .gulp: return 0.14
        case .bloop: return 0.16
        case .pop: return 0.14
        case .shake: return 0.14
        default: return 0.05
        }
    }

    private func soundURL(for s: AquaSFX) -> URL? {
        GameFiles.url(s.rawValue, "caf", game: "Aquarium")
            ?? GameFiles.url(s.rawValue, "wav", game: "Aquarium")
    }

    private func makePlayer(for s: AquaSFX) -> AVAudioPlayer? {
        guard !missing.contains(s), let url = soundURL(for: s),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            missing.insert(s)
            return nil
        }
        player.prepareToPlay()
        return player
    }

    /// Lazily pre-warms only the 4 feeding cues (1 player each) on the audio queue so first feed has zero init hitch.
    func prewarmFeedingCues() {
        queue.async {
            for cue in [AquaSFX.shake, .plop, .gulp, .bloop] {
                if self.players[cue] == nil, let player = self.makePlayer(for: cue) {
                    self.players[cue] = [player]
                }
            }
        }
    }

    private func playerForPlay(_ s: AquaSFX) -> AVAudioPlayer? {
        guard !missing.contains(s) else { return nil }
        let pool = players[s] ?? []
        if let idle = pool.first(where: { !$0.isPlaying }) { return idle }
        if pool.count < Self.maxPoolSize {
            if let created = makePlayer(for: s) {
                players[s] = pool + [created]
                return created
            }
        }
        if let oldest = pool.max(by: { $0.currentTime < $1.currentTime }), oldest.currentTime > 0.08 {
            return oldest
        }
        return nil
    }

    private func ensureLoop(for s: AquaSFX) -> AVAudioPlayer? {
        if let existing = loops[s] { return existing }
        guard !missing.contains(s), let url = soundURL(for: s),
              let p = try? AVAudioPlayer(contentsOf: url) else {
            missing.insert(s)
            return nil
        }
        p.numberOfLoops = -1
        p.volume = 0
        p.prepareToPlay()
        loops[s] = p
        return p
    }

    func play(_ s: AquaSFX, volume: Float = 0.9, gap: Double = 0) {
        let minGap = max(gap, Self.minimumGap(for: s))
        let v = volume * Float.random(in: 0.85...1)
        queue.async {
            let now = ProcessInfo.processInfo.systemUptime
            if let prev = self.last[s], now - prev < minGap { return }
            self.recentSeeks.removeAll { now - $0 > 0.15 }
            if self.recentSeeks.count >= 4 && s != .chime { return }
            guard let p = self.playerForPlay(s) else { return }
            self.last[s] = now
            self.recentSeeks.append(now)
            p.volume = v
            p.currentTime = 0
            p.play()
        }
    }

    func setLoop(_ s: AquaSFX, volume: Float) {
        loopLock.lock()
        let old = loopLevel[s] ?? 0
        let v = old + (volume - old) * 0.08
        loopLevel[s] = v
        let sent = loopSent[s] ?? 0
        let on = v > 0.01
        let shouldDispatch = abs(v - sent) > 0.01 || (on != (sent > 0.01))
        if shouldDispatch {
            loopSent[s] = on ? v : 0
        }
        loopLock.unlock()
        guard shouldDispatch else { return }
        queue.async {
            if on {
                guard let p = self.ensureLoop(for: s) else { return }
                p.volume = v
                if !p.isPlaying { p.play() }
            } else if let p = self.loops[s] {
                p.volume = 0
                if p.isPlaying { p.pause() }
            }
        }
    }

    func stopLoops() {
        loopLock.lock()
        for s in AquaSound.looping {
            loopLevel[s] = 0
            loopSent[s] = 0
        }
        loopLock.unlock()
        queue.async {
            for p in self.loops.values {
                p.pause()
                p.volume = 0
            }
        }
    }
}

// MARK: - Dock & Catalog Model

private enum AquaCatalogTab: Equatable { case fish, decor }

private enum AquaSlot: String, CaseIterable {
    case food, wiper, hoop, sub, net, drawer

    var spot: CGPoint {
        let i = CGFloat(AquaSlot.allCases.firstIndex(of: self) ?? 0)
        return CGPoint(x: 314 + i * 92, y: GameChromeLayout.dockY)
    }

    var tileTint: Color {
        switch self {
        case .food: return Color(hex: 0xFFF5E6)
        case .wiper: return Color(hex: 0xE6FAF8)
        case .hoop: return Color(hex: 0xEEF4FF)
        case .sub: return Color(hex: 0xFFF7D6)
        case .net: return Color(hex: 0xEBFAF2)
        case .drawer: return Color(hex: 0xFFF0F6)
        }
    }

    var tool: AquaTool? {
        switch self {
        case .food: return .food
        case .wiper: return .wiper
        case .hoop: return .hoop
        case .sub: return nil
        case .net: return .net
        case .drawer: return nil
        }
    }

    var accessibilityName: String {
        switch self {
        case .food: return "Fish Food"
        case .wiper: return "Glass Wiper"
        case .hoop: return "Bubble Hoop"
        case .sub: return "Yellow Submarine"
        case .net: return "Fish Net"
        case .drawer: return "Fish and Decor"
        }
    }
}

private struct AquaSlotIcon: View {
    let slot: AquaSlot
    let treatMode: AquaTreatMode

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            switch slot {
            case .food:
                g.translateBy(x: 0, y: -26)
                g.scaleBy(x: 0.62, y: 0.62)
                AquaDecorPainter.shaker(g, mode: treatMode)
            case .wiper:
                g.rotate(by: .radians(-0.18))
                g.scaleBy(x: 0.72, y: 0.72)
                AquaDecorPainter.wiper(g)
            case .hoop:
                g.scaleBy(x: 0.95, y: 0.95)
                AquaDecorPainter.hoopIcon(g, time: 0.4)
            case .sub:
                AquaDecorPainter.submarineIcon(g)
            case .net:
                g.rotate(by: .radians(0.55))
                g.translateBy(x: 0, y: -32)
                g.scaleBy(x: 0.46, y: 0.46)
                AquaDecorPainter.netFront(g)
            case .drawer:
                AquaDecorPainter.catalogIcon(g, time: 0.5)
            }
        }
        .allowsHitTesting(false)
    }
}

final class AquaHandState {
    var lastAt = Date()
    var startAt = Date()
    var active = false
}

// MARK: - Aquarium View

struct AquariumView: View {
    let exit: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var sim = AquariumSim()
    @State private var drawerOpen = false
    @State private var catalogTab: AquaCatalogTab = .fish
    @State private var lightsOn = true
    @State private var pump = true
    @State private var carrying: String?
    @State private var hidden: String?
    @State private var hand = AquaHandState()
    @State private var started = false
    @State private var book = false
    @State private var hasHungryFish = false
    @State private var hasDirtyGlass = false
    @State private var showReturnZone = false
    @State private var hoveringReturnZone = false
    @State private var subActive = false
    @State private var treatMode: AquaTreatMode = .flakes

    var body: some View {
        ZStack {
            GameStage {
                AquariumRoomBackdrop(lightsOn: lightsOn)
            } content: {
                ZStack {
                    // Cached static tank backdrop (cabinet, sand, 90 pebbles, 240 grains) rendered once via Metal texture.
                    AquaStaticTankBackdrop(isNight: false)
                    AquaStaticTankBackdrop(isNight: true)
                        .opacity(lightsOn ? 0 : 1)
                        .animation(.easeInOut(duration: 0.65), value: lightsOn)

                    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: book || scenePhase != .active)) { tl in
                        Canvas { ctx, _ in
                            sim.step(tl.date)
                            AquaPainter.draw(ctx, sim: sim)
                            sim.schedulePostFrameFlush()
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(handGesture)

                    topBar

                    dockLayer

                    if drawerOpen {
                        catalogDrawer
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    returnZoneOverlay

                    StickerToast(game: AquariumSim.gameID, target: GameChromeLayout.stickerTarget)
                }
                .coordinateSpace(name: "aquarium")
                .coinPurse(game: AquariumSim.gameID)
            }

            if book {
                StickerBookView(game: AquariumSim.gameID) {
                    withAnimation(.easeOut(duration: 0.2)) { book = false }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .ignoresSafeArea()
        .defersSystemGestures(on: .bottom)
        .onAppear(perform: start)
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                sim.save()
                AquaSound.shared.stopLoops()
            }
        }
        .onDisappear {
            sim.onUIStateChange = nil
            sim.save()
            AquaSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        AquaSound.shared.prewarmFeedingCues()
        lightsOn = sim.lightsOn
        pump = sim.pump
        hasHungryFish = sim.anyHungry
        hasDirtyGlass = sim.dirtiness > 0.3
        subActive = sim.submarine.active
        treatMode = sim.treatMode
        sim.onUIStateChange = { state in
            if hasHungryFish != state.hasHungryFish { hasHungryFish = state.hasHungryFish }
            if hasDirtyGlass != state.hasDirtyGlass { hasDirtyGlass = state.hasDirtyGlass }
            if showReturnZone != state.isCarryingReturnable {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    showReturnZone = state.isCarryingReturnable
                }
            }
            if hoveringReturnZone != state.isHoveringReturnZone {
                hoveringReturnZone = state.isHoveringReturnZone
            }
            if subActive != state.submarineActive { subActive = state.submarineActive }
            if treatMode != state.treatMode { treatMode = state.treatMode }
        }
        applyLaunchArguments()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        GameTopBar(
            gameID: AquariumSim.gameID,
            showStickerBook: true,
            showCoins: true,
            onExit: {
                sim.save()
                AquaSound.shared.stopLoops()
                exit()
            },
            onStickerBook: {
                AquaSound.shared.stopLoops()
                withAnimation(.easeOut(duration: 0.2)) { book = true }
            },
            trailing: {
                HStack(spacing: 12) {
                    AquaDayNightButton(lightsOn: lightsOn, size: GameChromeLayout.buttonSize) {
                        Sound.shared.tap()
                        lightsOn.toggle()
                        sim.setLights(lightsOn)
                    }

                    RoundButton(
                        symbol: "bubbles.and.sparkles.fill",
                        tint: pump ? Color(hex: 0x3FA9E0) : Theme.ink.opacity(0.35),
                        size: GameChromeLayout.buttonSize
                    ) {
                        Sound.shared.tap()
                        pump.toggle()
                        sim.setPump(pump)
                    }
                    .opacity(pump ? 1 : 0.72)
                    .accessibilityLabel(pump ? "Bubbler On" : "Bubbler Off")
                }
            }
        )
    }

    // MARK: - Bottom Dock

    private var dockLayer: some View {
        let canPulse = carrying == nil && !drawerOpen && !subActive && !book
        let foodPulse = canPulse && hasHungryFish
        let wiperPulse = canPulse && !foodPulse && hasDirtyGlass

        return GameTrayCard(cornerRadius: 30, paddingH: 14, paddingV: 10) {
            HStack(spacing: 10) {
                Button {
                    Sound.shared.tap()
                    sim.toggleTreatMode()
                    treatMode = sim.treatMode
                } label: {
                    ZStack {
                        Circle()
                            .fill(treatMode == .pearls ? Color(hex: 0xEDE6FF) : Color(hex: 0xFFF3DE))
                        Canvas { ctx, size in
                            var g = ctx
                            g.translateBy(x: size.width / 2, y: size.height / 2)
                            AquaDecorPainter.treatToggleIcon(g, mode: treatMode, time: 0)
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(treatMode == .pearls ? Theme.lilac : Theme.peach, lineWidth: 3))
                    .shadow(color: Theme.ink.opacity(0.14), radius: 4, y: 2)
                }
                .buttonStyle(Squish())
                .accessibilityLabel(treatMode == .pearls ? "Pearl Pellets" : "Rainbow Flakes")

                ForEach(AquaSlot.allCases, id: \.rawValue) { slot in
                    let isHidden = hidden == slot.rawValue
                    let pulsing = (slot == .food && foodPulse) || (slot == .wiper && wiperPulse)
                    let selected = (slot == .drawer && drawerOpen) || (slot == .sub && subActive)
                    GameDockTile(
                        size: 82,
                        selected: selected,
                        pulsing: pulsing,
                        tint: slot == .food && treatMode == .pearls ? Color(hex: 0xEFEAFF) : slot.tileTint,
                        cornerRadius: 22
                    ) {
                        if !isHidden {
                            AquaSlotIcon(slot: slot, treatMode: treatMode)
                        }
                    }
                    .opacity(isHidden ? 0.32 : 1)
                    .contentShape(Rectangle())
                    .gesture(dockGesture(slot))
                    .accessibilityLabel(slot.accessibilityName)
                }
            }
        }
        .position(x: 512, y: GameChromeLayout.dockY)
    }

    private func dockGesture(_ slot: AquaSlot) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("aquarium"))
            .onChanged { v in
                if slot == .sub {
                    guard !ToolTap.isTap(v.translation) else { return }
                    if drawerOpen {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drawerOpen = false }
                    }
                    sim.steerSubmarineFromFinger(v.location)
                    subActive = sim.submarine.active
                    return
                }
                guard slot.tool != nil else { return }
                guard !ToolTap.isTap(v.translation) else { return }
                useTool(slot, v.location)
            }
            .onEnded { v in
                switch slot {
                case .drawer:
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
                        drawerOpen.toggle()
                    }
                case .sub:
                    if ToolTap.isTap(v.translation) {
                        Sound.shared.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drawerOpen = false }
                        sim.toggleSubmarine()
                        subActive = sim.submarine.active
                    }
                case .food, .wiper, .hoop, .net:
                    if carrying != nil {
                        endTool(slot)
                    } else if ToolTap.isTap(v.translation) {
                        Sound.shared.tap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drawerOpen = false }
                        switch slot {
                        case .food: sim.tapDockFood(from: slot.spot)
                        case .wiper: sim.tapDockWiper(from: slot.spot)
                        case .hoop: sim.tapDockHoop()
                        case .net: sim.tapDockNet(from: slot.spot)
                        case .sub, .drawer: break
                        }
                    }
                }
            }
    }

    private func useTool(_ slot: AquaSlot, _ p: CGPoint) {
        guard let tool = slot.tool else { return }
        if carrying == nil {
            carrying = slot.rawValue
            hidden = slot.rawValue
            if drawerOpen {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drawerOpen = false }
            }
            Sound.shared.tap()
            sim.pickUp(tool, at: AquariumView.lifted(p, tool))
        }
        if let tl = sim.tool {
            sim.carry(to: AquariumView.lifted(p, tl), hand: p)
        }
    }

    private func endTool(_ slot: AquaSlot) {
        sim.release(home: slot.spot)
        finishCarry(slot.rawValue)
    }

    private func finishCarry(_ key: String) {
        carrying = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            if carrying != key && hidden == key { hidden = nil }
        }
    }

    // MARK: - Single-Row Catalog Drawer

    private var catalogDrawer: some View {
        let fishList = FishKind.classicCases
        let decorList = AquaDecorKind.available
        let itemCount = catalogTab == .fish ? fishList.count + 1 : decorList.count
        let overflows = itemCount * 92 > 572

        return GameTrayCard(cornerRadius: 28, paddingH: 14, paddingV: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    catalogTabButton(.fish)
                    catalogTabButton(.decor)
                }

                Capsule()
                    .fill(Theme.blush)
                    .frame(width: 3, height: 64)

                ScrollViewReader { proxy in
                    HStack(spacing: 4) {
                        if overflows {
                            drawerChevron(systemName: "chevron.left") {
                                Sound.shared.tap()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    proxy.scrollTo(0, anchor: .leading)
                                }
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                if catalogTab == .fish {
                                    catalogEggTile(key: "egg_0")
                                        .id(0)
                                    ForEach(Array(fishList.enumerated()), id: \.offset) { idx, kind in
                                        catalogFishTile(kind, key: "fish_\(idx)")
                                            .id(idx + 1)
                                    }
                                } else {
                                    ForEach(Array(decorList.enumerated()), id: \.offset) { idx, kind in
                                        catalogDecorTile(kind, key: "decor_\(idx)")
                                            .id(idx)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 2)
                        }
                        .frame(maxWidth: overflows ? 572 : 632, maxHeight: 88)
                        .scrollDisabled(carrying != nil)

                        if overflows {
                            drawerChevron(systemName: "chevron.right") {
                                Sound.shared.tap()
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    proxy.scrollTo(max(0, itemCount - 1), anchor: .trailing)
                                }
                            }
                        }
                    }
                }

                Button {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.5)
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { drawerOpen = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Theme.pink))
                        .overlay(Circle().stroke(.white, lineWidth: 3.5))
                        .shadow(color: Theme.ink.opacity(0.18), radius: 5, y: 3)
                }
                .buttonStyle(Squish())
                .accessibilityLabel("Close")
            }
        }
        .position(x: 512, y: AGeo.drawerY)
        .opacity(carrying?.hasPrefix("cat_") == true ? 0.25 : 1)
    }

    private func drawerChevron(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.pink)
                .frame(width: 26, height: 64)
                .background(
                    Capsule()
                        .fill(Theme.blush.opacity(0.38))
                )
        }
        .buttonStyle(Squish())
    }

    private func catalogTabButton(_ tab: AquaCatalogTab) -> some View {
        let selected = catalogTab == tab
        return Button {
            Sound.shared.tap()
            Sound.shared.play(.pop, volume: 0.5)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { catalogTab = tab }
        } label: {
            GameDockTile(
                size: 68,
                selected: selected,
                tint: tab == .fish ? Color(hex: 0xDCF4FF) : Color(hex: 0xFFF2DE),
                cornerRadius: 20
            ) {
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    if tab == .fish {
                        g.scaleBy(x: 0.56, y: 0.56)
                        AquaDecorPainter.bag(g, kind: .goldfish, time: 0)
                    } else {
                        var c = g
                        c.translateBy(x: -6, y: 24)
                        c.scaleBy(x: 0.27, y: 0.27)
                        AquaDecorPainter.castle(c)
                        var s = g
                        s.translateBy(x: 16, y: 24)
                        s.scaleBy(x: 0.42, y: 0.42)
                        AquaDecorPainter.shell(s)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .buttonStyle(Squish())
        .accessibilityLabel(tab == .fish ? "Fish" : "Decorations")
    }

    private func catalogEggTile(key: String) -> some View {
        let dragKey = "cat_\(key)"
        return RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(hex: 0xFFF3F8))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.lemon, lineWidth: 3.5))
            .overlay {
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2 + 24)
                    g.scaleBy(x: 1.05, y: 1.05)
                    AquaDecorPainter.egg(g, palette: .pinkSpeckle, taps: 0, time: 0.5)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 82, height: 82)
            .opacity(hidden == dragKey ? 0.25 : 1)
            .contentShape(Rectangle())
            .accessibilityLabel("Mystery Reef Egg")
            .onTapGesture {
                Sound.shared.tap()
                let x = CGFloat.random(in: 220...800)
                _ = sim.dropEgg(at: x, y: AGeo.waterY - 12)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .named("aquarium"))
                    .onChanged { v in
                        if carrying == nil {
                            guard v.translation.height < -10, abs(v.translation.height) >= abs(v.translation.width) * 0.45 else { return }
                            carrying = dragKey
                            hidden = dragKey
                            Sound.shared.tap()
                            let tool = AquaTool.egg
                            sim.pickUp(tool, at: AquariumView.lifted(v.location, tool))
                        }
                        guard carrying == dragKey, let tl = sim.tool else { return }
                        sim.carry(to: AquariumView.lifted(v.location, tl), hand: v.location)
                    }
                    .onEnded { _ in
                        guard carrying == dragKey else { return }
                        sim.release(home: AquaSlot.drawer.spot)
                        carrying = nil
                        hidden = nil
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drawerOpen = false }
                    }
            )
    }

    private func catalogFishTile(_ kind: FishKind, key: String) -> some View {
        let dragKey = "cat_\(key)"
        return RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(hex: 0xDCF4FF))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.blush, lineWidth: 2.5))
            .overlay {
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    let s = min(1.12, 66 / (kind.length + kind.tailLength))
                    if kind == .seahorse {
                        g.scaleBy(x: 0.9, y: 0.9)
                    } else {
                        g.translateBy(x: kind.tailLength * s * 0.34, y: 0)
                        g.scaleBy(x: s, y: s)
                    }
                    AquaFishPainter.drawLocal(g, kind: kind, variant: 0, phase: 1, amp: 0.2, gulp: 0, puff: 0, time: 0)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 82, height: 82)
            .opacity(hidden == dragKey ? 0.25 : 1)
            .contentShape(Rectangle())
            .accessibilityLabel(kind.rawValue.capitalized)
            .onTapGesture {
                Sound.shared.tap()
                let x = CGFloat.random(in: 220...800)
                sim.addFish(kind, x: x, y: AGeo.waterY - 18)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .named("aquarium"))
                    .onChanged { v in
                        if carrying == nil {
                            guard v.translation.height < -10, abs(v.translation.height) >= abs(v.translation.width) * 0.45 else { return }
                            carrying = dragKey
                            hidden = dragKey
                            Sound.shared.tap()
                            let tool = AquaTool.fish(kind)
                            sim.pickUp(tool, at: AquariumView.lifted(v.location, tool))
                        }
                        guard carrying == dragKey, let tl = sim.tool else { return }
                        sim.carry(to: AquariumView.lifted(v.location, tl), hand: v.location)
                    }
                    .onEnded { _ in
                        guard carrying == dragKey else { return }
                        sim.release(home: AquaSlot.drawer.spot)
                        carrying = nil
                        hidden = nil
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drawerOpen = false }
                    }
            )
    }

    private func catalogDecorTile(_ kind: AquaDecorKind, key: String) -> some View {
        let dragKey = "cat_\(key)"
        let isTreasure = kind.treasure != nil
        return RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isTreasure ? Color(hex: 0xFFF5D8) : Color(hex: 0xFFF4E4))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isTreasure ? Theme.lemon : Theme.blush, lineWidth: isTreasure ? 3.5 : 2.5))
            .overlay {
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    let s = min(0.78, 72 / max(kind.size.height, kind.size.width))
                    g.translateBy(x: 0, y: kind.size.height * s * 0.5)
                    g.scaleBy(x: s, y: s)
                    AquaDecorPainter.drawKind(g, kind, time: 0, sway: 0, open: 0, seed: 1)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 82, height: 82)
            .opacity(hidden == dragKey ? 0.25 : 1)
            .contentShape(Rectangle())
            .accessibilityLabel(kind.rawValue.capitalized)
            .onTapGesture {
                Sound.shared.tap()
                let x = CGFloat.random(in: 170...850)
                sim.addDecor(kind, x: x, falling: true, y: AGeo.waterY)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .named("aquarium"))
                    .onChanged { v in
                        if carrying == nil {
                            guard v.translation.height < -10, abs(v.translation.height) >= abs(v.translation.width) * 0.45 else { return }
                            carrying = dragKey
                            hidden = dragKey
                            Sound.shared.tap()
                            let tool = AquaTool.decor(kind)
                            sim.pickUp(tool, at: AquariumView.lifted(v.location, tool))
                        }
                        guard carrying == dragKey, let tl = sim.tool else { return }
                        sim.carry(to: AquariumView.lifted(v.location, tl), hand: v.location)
                    }
                    .onEnded { _ in
                        guard carrying == dragKey else { return }
                        sim.release(home: AquaSlot.drawer.spot)
                        carrying = nil
                        hidden = nil
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drawerOpen = false }
                    }
            )
    }

    // MARK: - Explicit Return Zone Overlay

    @ViewBuilder
    private var returnZoneOverlay: some View {
        if showReturnZone {
            ReturnDropBadge(hovered: hoveringReturnZone)
                .position(AGeo.returnBadgeCenter)
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    // MARK: - Direct Hand Gesture

    private var handGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("aquarium"))
            .onChanged { v in
                let p = v.location
                let now = Date()
                if !hand.active {
                    hand.active = true
                    hand.startAt = now
                    hand.lastAt = now
                    if drawerOpen {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drawerOpen = false }
                    }
                    sim.handBegan(p)
                } else {
                    let dt = CGFloat(max(1.0 / 120, now.timeIntervalSince(hand.lastAt)))
                    hand.lastAt = now
                    sim.handMoved(p, dt: dt)
                }
            }
            .onEnded { v in
                let p = v.location
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y)
                let tap = moved < 14 && Date().timeIntervalSince(hand.startAt) < 0.45
                sim.handEnded(p, tap: tap)
                hand.active = false
            }
    }

    // MARK: - FingerLift Mapping

    static func lifted(_ p: CGPoint, _ tool: AquaTool) -> CGPoint {
        FingerLift.point(p, lift: lift(tool), top: AGeo.rimY - 30, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }

    static func lift(_ tool: AquaTool) -> CGFloat {
        switch tool {
        case .net: return FingerLift.tool
        case .wiper: return FingerLift.grip
        case .food: return FingerLift.pour
        case .hoop: return FingerLift.tool
        case .egg: return FingerLift.carry(below: 32)
        case .fish: return FingerLift.carry(below: 50)
        case .decor(let k): return FingerLift.carry(below: k.size.height * 0.5)
        }
    }

    // MARK: - Launch Arguments

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-aquaDemo") || args.contains("-aquaNight") || args.contains("-aquaTray") || args.contains("-aquaTool") {
            sim.demo = true
            Coins.shared.demo = true
            StickerBook.shared.demo = true
        }
        if args.contains("-aquaDemo") {
            sim.showcase()
        }
        if args.contains("-aquaNight") {
            lightsOn = false
            sim.lightsOn = false
            sim.night = 1
        }
        if let i = args.firstIndex(of: "-aquaTray"), i + 1 < args.count {
            drawerOpen = true
            catalogTab = args[i + 1] == "decor" ? .decor : .fish
        }
        if let i = args.firstIndex(of: "-aquaTool"), i + 1 < args.count {
            switch args[i + 1] {
            case "wiper":
                sim.pickUp(.wiper, at: CGPoint(x: 260, y: 440))
                sim.carry(to: CGPoint(x: 260, y: 440), hand: CGPoint(x: 286, y: 504))
                hidden = AquaSlot.wiper.rawValue
            case "hoop":
                sim.pickUp(.hoop, at: CGPoint(x: 520, y: 360))
                sim.carry(to: CGPoint(x: 520, y: 360), hand: CGPoint(x: 560, y: 456))
                hidden = AquaSlot.hoop.rawValue
            case "net":
                sim.pickUp(.net, at: CGPoint(x: 560, y: 420))
                sim.carry(to: CGPoint(x: 560, y: 420), hand: CGPoint(x: 600, y: 516))
                hidden = AquaSlot.net.rawValue
            default:
                sim.pickUp(.food, at: CGPoint(x: 520, y: 120))
                sim.carry(to: CGPoint(x: 520, y: 120), hand: CGPoint(x: 566, y: 230))
                sim.shake = 1.5
                hidden = AquaSlot.food.rawValue
            }
        }
    }
}

private struct AquaDayNightButton: View {
    let lightsOn: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill((lightsOn ? Theme.lemon : Theme.lilac).opacity(0.45))
                    .frame(width: size + 12, height: size + 12)
                    .blur(radius: 4)

                ZStack {
                    // Split day/night circle so kids immediately discover Night Mode from the top bar.
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: lightsOn
                                    ? [Color(hex: 0xFFC84A), Color(hex: 0xF5A623)]
                                    : [Color(hex: 0x6C5CE7), Color(hex: 0x4834B8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Canvas { ctx, sz in
                        var corner = Path()
                        corner.move(to: CGPoint(x: sz.width * 0.22, y: sz.height))
                        corner.addLine(to: CGPoint(x: sz.width, y: sz.height * 0.22))
                        corner.addLine(to: CGPoint(x: sz.width, y: sz.height))
                        corner.closeSubpath()
                        ctx.fill(
                            corner,
                            with: .color(lightsOn ? Color(hex: 0x5A48C8).opacity(0.92) : Color(hex: 0xFFB833).opacity(0.92))
                        )
                    }
                    .clipShape(Circle())

                    Image(systemName: lightsOn ? "sun.max.fill" : "moon.stars.fill")
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: -size * 0.13, y: -size * 0.12)

                    Image(systemName: lightsOn ? "moon.stars.fill" : "sun.max.fill")
                        .font(.system(size: size * 0.23, weight: .bold))
                        .foregroundStyle(lightsOn ? Color(hex: 0xFFF2A8) : .white)
                        .offset(x: size * 0.20, y: size * 0.19)
                }
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white, lineWidth: 3.5))
                .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 3)
            }
        }
        .buttonStyle(Squish())
        .accessibilityLabel(lightsOn ? "Tank Lights On" : "Tank Lights Off")
    }
}

extension AquariumSim {
    func showcase() {
        demo = true
        fish = []
        decor = []
        hoops = []
        eggs = []
        addDecor(.seaweed, x: 110)
        addDecor(.castle, x: 270)
        addDecor(.diver, x: 420)
        addDecor(.grass, x: 520)
        addDecor(.chest, x: 620)
        addDecor(.ship, x: 790)
        addDecor(.anemone, x: 930)
        addDecor(.coral, x: 360)
        addDecor(.starfish, x: 690)
        addDecor(.shell, x: 180)
        addDecor(.bubbler, x: 470)
        let kinds: [(FishKind, Int, CGPoint)] = [
            (.goldfish, 0, CGPoint(x: 300, y: 260)), (.goldfish, 1, CGPoint(x: 720, y: 330)), (.clownfish, 0, CGPoint(x: 520, y: 420)),
            (.angelfish, 0, CGPoint(x: 820, y: 230)), (.puffer, 0, CGPoint(x: 230, y: 500)), (.betta, 0, CGPoint(x: 600, y: 210)),
            (.seahorse, 0, CGPoint(x: 120, y: 420)), (.guppy, 1, CGPoint(x: 420, y: 300)), (.guppy, 2, CGPoint(x: 450, y: 320)),
        ]
        for (k, v, p) in kinds { spawn(k, variant: v, at: p) }
        for j in 0..<6 { spawn(.tetra, variant: 0, at: CGPoint(x: 640 + CGFloat(j % 3) * 26, y: 470 + CGFloat(j / 3) * 18)) }
        for i in fish.indices {
            fish[i].dir = i % 2 == 0 ? 1 : -1
            fish[i].facing = fish[i].dir
            fish[i].z = 0.4 + CGFloat(i % 4) * 0.15
        }
        spawnBubbleHoop(at: CGPoint(x: 512, y: 340))
        _ = dropEgg(at: 392, y: AGeo.sand(392), species: .narwhal)
        spawn(.axolotl, variant: 0, at: CGPoint(x: 340, y: 520), growthStage: 0)
        for k in 0..<12 {
            addFlake(at: CGPoint(x: 460 + CGFloat(k) * 9, y: AGeo.waterY + 30 + CGFloat(k * 7 % 60)), v: .zero)
            food[food.count - 1].state = .sinking
        }
        moss = AquaMossPatch.makeDefault(opacities: [0, 0, 0, 0, 0, 0.25, 0.62, 0.55, 0.4, 0.22])
        for k in 0..<28 {
            addBubble(CGPoint(x: 470 + CGFloat.random(in: -10...10), y: 600 - CGFloat(k) * 15), r: CGFloat.random(in: 2...5))
        }
        resolveSandLayout()
    }
}
