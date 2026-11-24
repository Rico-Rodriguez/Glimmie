import AVFoundation
import SwiftUI

// MARK: - Garden (a game in the drawer)
//
// A glass-fronted garden bed in a back yard. She carries tools off the dock at the bottom: the shovel digs real holes
// (the soil comes away on the blade and a flick throws it), seed packets shake seeds out that drop into the holes,
// the watering can pours a stream that soaks dark into the soil and pools into puddles. Plants grow while their soil
// is damp, sway in the wind and spring back when she brushes them; she taps ripe things to pick them into the basket
// and pulls carrots and weeds up by hand. Butterflies and a bee visit the flowers, a ladybug walks the soil, a worm
// tunnels behind the glass. Sun, rain, wind or a firefly night at a tap. Decorations go on the lawn behind the bed.
// Everything is open, nothing to read, no voice.
//
// Code: GardenSim (the simulation), GardenScene + GardenPlants (drawing), this file (screen and controls).
// Sounds: tools/garden/sounds.py -> App/Resources/Games/Garden/*.wav. Saves: garden.json.

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
            let k = size.width / 300
            g.scaleBy(x: k, y: k)
            var mound = Path()
            mound.move(to: CGPoint(x: -10, y: 310))
            mound.addQuadCurve(to: CGPoint(x: 310, y: 310), control: CGPoint(x: 150, y: 196))
            mound.closeSubpath()
            g.fill(mound, with: .linearGradient(Gradient(colors: [GRGB(0x9A6A43).color, GRGB(0x5E3C26).color]),
                                                startPoint: CGPoint(x: 0, y: 240), endPoint: CGPoint(x: 0, y: 310)))
            let sun = Plant(kind: .sunflower, growth: 1, left: 1, variant: 0)
            var sg = g
            sg.translateBy(x: 118, y: 258)
            sg.scaleBy(x: 0.72, y: 0.72)
            GardenPlants.draw(sg, plant: sun, base: .zero, bend: -0.08, pop: 0, pull: 0, time: 0, droop: false)
            let tulip = Plant(kind: .tulip, growth: 1, left: 1, variant: 0)
            var tg = g
            tg.translateBy(x: 212, y: 262)
            tg.scaleBy(x: 0.95, y: 0.95)
            GardenPlants.draw(tg, plant: tulip, base: .zero, bend: 0.12, pop: 0, pull: 0, time: 0, droop: false)
            GardenScenePreview.butterfly(g, at: CGPoint(x: 230, y: 70), look: 0)
        }
    }
}

enum GardenScenePreview {
    static func butterfly(_ g: GraphicsContext, at p: CGPoint, look: Int) {
        GardenPainter.butterfly(g, at: p, phase: 1.2, perched: true, facing: -1, look: look, scale: 1.6)
    }
}

// MARK: - Sounds

enum GardenSFX: String, CaseIterable {
    case dig, toss, pat, seeds, water, splash, pluck, grow, basket, buzz, chirp, rain, wind, crickets, plunk, squeak, flutter, rustle
}

/// The garden's own effects and its looping weather sounds, from App/Resources/Games/Garden.
final class GardenSound {
    static let shared = GardenSound()
    private var players: [GardenSFX: [AVAudioPlayer]] = [:]
    private var loops: [GardenSFX: AVAudioPlayer] = [:]
    private var last: [GardenSFX: Date] = [:]
    static let looping: Set<GardenSFX> = [.water, .rain, .wind, .crickets, .buzz]

    private init() {
        _ = Sound.shared // sets up the audio session
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

    /// Starting, seeking and fading AVAudioPlayers can stall for milliseconds, so it all happens on this queue,
    /// never on the frame that is drawing.
    private let queue = DispatchQueue(label: "garden.sound", qos: .userInitiated)
    /// The volume each loop was last set to, kept here so a frame never has to ask the player.
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

    /// Fades a looping sound toward `volume`; it pauses when silent. Called every frame, but only reaches the
    /// player when the level has moved enough to hear.
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

// MARK: - The screen

private enum GardenTray { case seeds, decor }

private enum DockSlot: String {
    case shovel, can, seeds, decor

    func spot(_ map: GMap) -> CGPoint {
        if map.sideDock {
            let slots: [DockSlot] = [.shovel, .can, .seeds, .decor]
            let row = slots.firstIndex(of: self) ?? 0
            return CGPoint(x: 44, y: 242 + CGFloat(row) * 126)
        }
        switch self {
        case .shovel: return CGPoint(x: 150, y: GGeo.dockY)
        case .can: return CGPoint(x: 274, y: GGeo.dockY)
        case .seeds: return CGPoint(x: 398, y: GGeo.dockY)
        case .decor: return CGPoint(x: 522, y: GGeo.dockY)
        }
    }
}

/// One tool button in the dock. It only redraws when what it shows changes, so bouncing it is just a move.
private struct GardenDockPlate: View, Equatable {
    let slot: DockSlot
    let open: Bool
    let iconHidden: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(open ? Theme.pink : Color.white, lineWidth: 5))
                .shadow(color: Theme.ink.opacity(0.22), radius: 7, y: 5)
            if !iconHidden {
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    switch slot {
                    case .shovel:
                        g.rotate(by: .radians(0.5))
                        g.scaleBy(x: 0.42, y: 0.42)
                        g.translateBy(x: 0, y: 96)
                        GardenPainter.shovel(g, load: 0)
                    case .can:
                        g.scaleBy(x: 0.5, y: 0.5)
                        g.translateBy(x: 30, y: -50)
                        GardenPainter.can(g)
                    case .seeds:
                        var a = g
                        a.translateBy(x: -12, y: 2)
                        a.rotate(by: .radians(-0.2))
                        a.scaleBy(x: 0.72, y: 0.72)
                        GardenPainter.packet(a, kind: .tulip)
                        var b = g
                        b.translateBy(x: 14, y: 4)
                        b.rotate(by: .radians(0.18))
                        b.scaleBy(x: 0.72, y: 0.72)
                        GardenPainter.packet(b, kind: .sunflower)
                    case .decor:
                        var a = g
                        a.translateBy(x: -16, y: 40)
                        a.scaleBy(x: 0.5, y: 0.5)
                        GardenDecorPainter.draw(a, GDecor(id: 0, kind: .pinwheel, x: 0, y: 0, spin: 0.4, held: true), time: 0, night: 0, wind: 0)
                        var b = g
                        b.translateBy(x: 18, y: 38)
                        b.scaleBy(x: 0.6, y: 0.6)
                        GardenDecorPainter.draw(b, GDecor(id: 0, kind: .mushroom, x: 0, y: 0, held: true), time: 0, night: 0, wind: 0)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: 108, height: 108)
    }
}

final class GardenHandState {
    var sowingFrom: CGPoint?
    var lastAt = Date()
    var startAt = Date()
    var active = false
}

struct GardenView: View {
    let exit: () -> Void

    @State private var sim = GardenSim()
    @State private var tray: GardenTray?
    @State private var weather: Weather = .sun
    @State private var carrying: String?
    @State private var hidden: String?
    /// Touch bookkeeping lives outside SwiftUI state so a drag does not rebuild the view on every move.
    @State private var hand = GardenHandState()
    @State private var started = false
    /// The shovel or can she tapped on the dock: a tap on the garden makes it do that spot (see `ToolTap`).
    @State private var picked: DockSlot?
    @State private var auto = AutoTool()
    @State private var book = false
    @State private var packet: PlantKind?
    @State private var printing = false

    var body: some View {
        GeometryReader { geo in
            // the scene is zoomed in so the bed fills the screen; the buttons stay their usual size
            let map = GMap.garden(size: geo.size)
            ZStack {
                // The sky, hills, fence and lawns change slowly, so they redraw at 30 fps in their own layer.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: printing)) { _ in
                    Canvas(opaque: true) { ctx, _ in
                        GardenPainter.drawBackdrop(ctx, map: map, sim: sim)
                    }
                }
                .allowsHitTesting(false)
                // Everything that moves, capped at 60 fps so 120 Hz screens do not double the work.
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: printing)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        GardenPainter.draw(ctx, map: map, sim: sim, planting: packet != nil)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture(map))

                if let kind = packet {
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("garden"))
                            .onChanged { value in
                                let point = map.design(value.location)
                                sim.sowRow(kind, from: hand.sowingFrom ?? map.design(value.startLocation), to: point)
                                hand.sowingFrom = point
                            }
                            .onEnded { _ in hand.sowingFrom = nil })
                } else if let pk = picked {
                    ToolTapLayer(space: "garden",
                                 onDrag: { loc in
                                     if auto.running { auto.cancel() }
                                     useTool(pk, map.design(loc))
                                 },
                                 onEnd: { _ in endTool(pk, map) },
                                 onTap: { loc in autoDo(pk, map.design(loc), map) })
                }

                controls(map)
                    .frame(width: 1024, height: 834)
                    .scaleEffect(map.ui)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                Button {
                    auto.cancel()
                    printing = true
                } label: {
                    VStack(spacing: 0) {
                        Color.clear
                        Text("Make a print").font(.system(size: 17 * map.s, weight: .bold, design: .rounded))
                            .foregroundStyle(.white).padding(.horizontal, 7)
                            .background(Color(hex: 0x476849), in: Capsule())
                    }
                    .frame(width: 145 * map.s, height: 92 * map.s)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open basket and make a garden print")
                .position(x: map.ox + GGeo.basket.x * map.s, y: map.oy + (GGeo.basket.y - 10) * map.s)

                if printing {
                    GardenPrintView(sim: sim) { printing = false }
                        .padding(.horizontal, geo.safeAreaInsets.leading + 8)
                        .background(Color(hex: 0xDAE4C9))
                        .zIndex(2)
                }
                if book {
                    StickerBookView(game: GardenSim.gameID) { withAnimation(.easeOut(duration: 0.2)) { book = false } }
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .coordinateSpace(name: "garden")
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
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

    static let bookSpot = CGPoint(x: 152, y: 60)

    // MARK: Hand

    private func handGesture(_ map: GMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("garden"))
            .onChanged { v in
                let p = map.design(v.location)
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
                let p = map.design(v.location)
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                let tap = moved < 14 && Date().timeIntervalSince(hand.startAt) < 0.45
                sim.handEnded(p, tap: tap)
                hand.active = false
            }
    }

    // MARK: Controls

    private func controls(_ map: GMap) -> some View {
        ZStack {
            HomeButton(action: exit)
                .position(x: 62, y: 60)
            StickerBookButton(game: GardenSim.gameID) { book = true }
                .position(x: GardenView.bookSpot.x, y: GardenView.bookSpot.y)
            if packet != nil || picked != nil {
                let title = packet?.rawValue.capitalized ?? (picked == .can ? "Water a plant" : "Dig the soil")
                PlayPrompt(title: title, actionSymbol: "xmark", action: {
                    auto.cancel()
                    packet = nil
                    picked = nil
                    hand.sowingFrom = nil
                }) {
                    if let packet {
                        Canvas { ctx, size in
                            var g = ctx
                            g.translateBy(x: size.width / 2, y: size.height / 2)
                            g.scaleBy(x: 0.48, y: 0.48)
                            GardenPainter.packet(g, kind: packet)
                        }
                    } else { Image(systemName: "hand.tap.fill") }
                }
                .position(x: 420, y: 60)
            }
            weatherBar
                .position(x: 812, y: 60)
            // Which tool to suggest is checked a few times a second; the bounce itself runs at the display's
            // rate and pauses when nothing is suggested.
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                let hint = picked == nil && packet == nil && sim.tool == nil && tray == nil ? suggested : nil
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: hint == nil)) { tl in
                    dock(map, hint: hint, time: tl.date.timeIntervalSinceReferenceDate)
                }
            }
            if let t = tray {
                trayView(t, map)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            StickerToast(game: GardenSim.gameID, target: GardenView.bookSpot)
        }
    }

    private var weatherBar: some View {
        HStack(spacing: 14) {
            ForEach(Weather.allCases, id: \.self) { w in
                Button {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    weather = w
                    sim.setWeather(w)
                } label: {
                    Image(systemName: w.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(w.tint)
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(.white))
                        .overlay(Circle().stroke(weather == w ? w.tint : Color.white.opacity(0.6), lineWidth: weather == w ? 6 : 3))
                        .scaleEffect(weather == w ? 1.1 : 0.94)
                        .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: weather)
                }
                .buttonStyle(Squish())
            }
        }
    }

    /// Which tool would help right now: it bounces gently.
    private var suggested: DockSlot? {
        let thirsty = sim.plots.contains { $0.plant != nil && $0.dry > 2 && ($0.plant?.growth ?? 1) < 1 }
        if thirsty { return .can }
        let holes = sim.plots.indices.contains { sim.hasHole(plot: $0) }
        if holes { return .seeds }
        let empty = sim.plots.allSatisfy { $0.plant == nil }
        return empty ? .shovel : nil
    }

    private func dock(_ map: GMap, hint: DockSlot?, time: Double) -> some View {
        ZStack {
            ForEach([DockSlot.shovel, .can, .seeds, .decor], id: \.rawValue) { slot in
                let bounce: CGFloat = hint == slot ? CGFloat(abs(sin(time * 4))) * -14 : 0
                let open = (tray == .seeds && slot == .seeds) || (tray == .decor && slot == .decor)
                GardenDockPlate(slot: slot, open: open, iconHidden: hidden == slot.rawValue)
                    .equatable()
                    .opacity(hidden == slot.rawValue ? 0.35 : 1)
                    .picked(picked == slot && hidden != slot.rawValue, corner: 30)
                    .offset(y: bounce)
                    .contentShape(Rectangle())
                    .gesture(dockGesture(slot, map))
                    .accessibilityLabel(slot.rawValue.capitalized)
                    .position(slot.spot(map))
            }
        }
    }

    private func dockGesture(_ slot: DockSlot, _ map: GMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("garden"))
            .onChanged { v in
                let p = map.design(v.location)
                switch slot {
                case .seeds, .decor:
                    return
                case .shovel, .can:
                    if auto.running { auto.cancel() }
                    guard carrying != nil || !ToolTap.isTap(v.translation) else { return }
                    packet = nil
                    picked = nil
                    useTool(slot, p)
                }
            }
            .onEnded { v in
                switch slot {
                case .seeds, .decor:
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    auto.cancel()
                    picked = nil
                    packet = nil
                    hand.sowingFrom = nil
                    let want: GardenTray = slot == .seeds ? .seeds : .decor
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { tray = tray == want ? nil : want }
                case .shovel, .can:
                    if carrying != nil {
                        endTool(slot, map)
                        return
                    }
                    packet = nil
                    tray = nil
                    // a tap on the dock picks the tool (or puts it down)
                    if ToolTap.isTap(v.translation) {
                        picked = picked == slot ? nil : slot
                        Sound.shared.play(.pop, volume: 0.6)
                    }
                }
            }
    }

    /// The shovel or can in her hand at p (design space): picked up first if it isn't yet.
    private func useTool(_ slot: DockSlot, _ p: CGPoint) {
        if carrying == nil {
            carrying = slot.rawValue
            hidden = slot.rawValue
            tray = nil
            Sound.shared.tap()
            sim.pickUp(slot == .shovel ? .shovel : .can, at: p)
        }
        // she holds the shovel by its shaft with the blade out ahead, the can hangs below her finger (see `FingerLift`)
        if let tl = sim.tool { sim.carry(to: GardenView.lifted(p, tl), hand: p) }
    }

    private func endTool(_ slot: DockSlot, _ map: GMap) {
        sim.release(home: map.fromUI(slot.spot(map)))
        finishCarry(slot.rawValue)
    }

    /// The picked tool flies off the dock and does the spot she tapped by itself: the shovel digs there,
    /// the can waters it from above.
    private func autoDo(_ slot: DockSlot, _ spot: CGPoint, _ map: GMap) {
        guard slot == .shovel || slot == .can else { return }
        if slot == .can { sim.waterPlant(at: spot); return }
        let tool = GardenTool.shovel
        let target = CGPoint(x: spot.x, y: spot.y + 10)
        let f = FingerLift.finger(for: target, lift: GardenView.lift(tool), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
        auto.run(from: map.fromUI(slot.spot(map)), to: f, step: { useTool(slot, $0) }, end: { _ in endTool(slot, map) })
    }

    /// Where a carried tool goes for her finger at p (design space). Each tool is drawn around a
    /// different point, so each is lifted until the part that hangs lowest still clears her finger.
    static func lifted(_ p: CGPoint, _ tool: GardenTool) -> CGPoint {
        FingerLift.point(p, lift: lift(tool), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
    }

    static func lift(_ tool: GardenTool) -> CGFloat {
        let lift: CGFloat
        switch tool {
        case .shovel: lift = 110                                               // her hand on the shaft, the blade out ahead
        case .can: lift = FingerLift.carry(below: 106)                         // a pourer: the can hangs below its handle
        case .seeds: lift = FingerLift.carry(below: 45)
        case .decor(let k): lift = FingerLift.carry(below: k.size.height * 0.5)
        }
        return lift
    }

    private func finishCarry(_ key: String) {
        carrying = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            if carrying != key && hidden == key { hidden = nil }
        }
    }

    // MARK: Trays

    private func trayView(_ t: GardenTray, _ map: GMap) -> some View {
        let count = t == .seeds ? PlantKind.allCases.count : DecorKind.available.count
        // one row of up to 8; with bought extras the tray grows a second row (the extras sit in the bottom one)
        let perRow = min(count, 8)
        let rows = (count + perRow - 1) / perRow
        let rowH: CGFloat = 128
        let top: CGFloat = 640 - CGFloat(rows - 1) * rowH
        return ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Theme.pink.opacity(0.5), lineWidth: 4))
                .shadow(color: Theme.ink.opacity(0.25), radius: 10, y: 6)
                .frame(width: CGFloat(perRow) * 104 + 30, height: 140 + CGFloat(rows - 1) * rowH)
                .position(x: 512, y: 640 - CGFloat(rows - 1) * rowH / 2)
            ForEach(0..<count, id: \.self) { i in
                let col = i % perRow, row = i / perRow
                let inRow = row == rows - 1 ? count - row * perRow : perRow
                trayItem(t, i, map)
                    .position(x: 512 + (CGFloat(col) - CGFloat(inRow - 1) / 2) * 104, y: top + CGFloat(row) * rowH)
            }
        }
        .opacity(carrying?.hasPrefix("tray") == true ? 0.3 : 1)
    }

    private func trayItem(_ t: GardenTray, _ i: Int, _ map: GMap) -> some View {
        let key = "tray\(i)"
        return Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            if t == .seeds {
                g.scaleBy(x: 1.1, y: 1.1)
                GardenPainter.packet(g, kind: PlantKind.allCases[i])
            } else {
                let k = DecorKind.available[i]
                let s = min(0.62, 100 / k.size.height)
                g.translateBy(x: 0, y: k.size.height * s * 0.5)
                g.scaleBy(x: s, y: s)
                GardenDecorPainter.draw(g, GDecor(id: 0, kind: k, x: 0, y: 0, spin: 0.4, held: true), time: 0, night: 0, wind: 0)
            }
        }
        .frame(width: 96, height: 120)
        .opacity(hidden == key ? 0.25 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("garden"))
                .onChanged { v in
                    guard carrying != nil || !ToolTap.isTap(v.translation) else { return }
                    let p = map.design(v.location)
                    if carrying == nil {
                        carrying = key
                        hidden = key
                        Sound.shared.tap()
                        let tool: GardenTool = t == .seeds ? .seeds(PlantKind.allCases[i]) : .decor(DecorKind.available[i])
                        sim.pickUp(tool, at: p)
                    }
                    if let tl = sim.tool { sim.carry(to: GardenView.lifted(p, tl), hand: p) }
                }
                .onEnded { value in
                    if carrying == nil {
                        if t == .seeds {
                            packet = PlantKind.allCases[i]
                            hand.sowingFrom = nil
                        } else {
                            sim.addDecor(DecorKind.available[i], x: map.design(value.location).x, falling: true)
                        }
                        Sound.shared.tap()
                    } else {
                        sim.release(home: map.fromUI(t == .seeds ? DockSlot.seeds.spot(map) : DockSlot.decor.spot(map)))
                    }
                    carrying = nil
                    hidden = nil
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tray = nil }
                }
        )
    }

    // MARK: Screenshot hooks

    /// -gardenDemo (a full garden, nothing saved), -gardenWeather <sun|rain|wind|night>,
    /// -gardenTool <can|shovel|seeds> (a tool held still over the bed).
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-gardenDemo") { sim.showcase() }
        if let i = args.firstIndex(of: "-gardenWeather"), i + 1 < args.count, let w = Weather(rawValue: args[i + 1]) {
            sim.demo = true
            weather = w
            sim.setWeather(w)
            sim.settleWeather()
        }
        if let i = args.firstIndex(of: "-gardenTool"), i + 1 < args.count {
            sim.demo = true
            switch args[i + 1] {
            case "can":
                sim.pickUp(.can, at: CGPoint(x: 420, y: 400))
                hidden = DockSlot.can.rawValue
            case "shovel":
                sim.carveHole(plot: 3)
                sim.pickUp(.shovel, at: CGPoint(x: 600, y: 470))
                sim.load = 600
                hidden = DockSlot.shovel.rawValue
            default:
                sim.carveHole(plot: 3)
                sim.pickUp(.seeds(.sunflower), at: CGPoint(x: 600, y: 440))
            }
        }
    }
}

extension GardenSim {
    /// Fills the garden for screenshots: something at every stage, decorations, bugs.
    func showcase() {
        demo = true
        for i in h.indices { h[i] = GGeo.soilY + sin(CGFloat(i) * 0.21) * 1.2 }
        let kinds: [(PlantKind, Double, Int)] = [(.sunflower, 1, 1), (.tulip, 1, 1), (.tomato, 1, 4), (.carrot, 0.7, 0), (.strawberry, 1, 3), (.pumpkin, 1, 1)]
        for (i, k) in kinds.enumerated() {
            plots[i].plant = Plant(kind: k.0, growth: k.1, left: k.2, variant: i)
        }
        for i in 0..<GGeo.columns {
            let x = GGeo.colX(i)
            wet[i] = x > 380 && x < 640 ? 0.75 : 0.25
        }
        weeds = [GWeed(x: 360, growth: 1, seed: 2)]
        decor = []
        addDecor(.pinwheel, x: 210, falling: false)
        addDecor(.birdhouse, x: 520, falling: false)
        addDecor(.flamingo, x: 690, falling: false)
        addDecor(.lantern, x: 940, falling: false)
        addDecor(.mushroom, x: 70, falling: false)
        decor[1].poke = time
        basket = ["tomato:0", "strawberry:0", "carrot:0", "daisy:1", "tomato:0", "pumpkin:0", "tulip:2"]
    }

    /// Jumps the sky straight to the chosen weather (for screenshots).
    func settleWeather() {
        rain = weather == .rain ? 1 : 0
        night = weather == .night ? 1 : 0
        wind = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        cloud = weather == .rain ? 1 : (weather == .wind ? 0.45 : 0.12)
    }
}
