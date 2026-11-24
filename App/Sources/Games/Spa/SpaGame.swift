import AVFoundation
import SwiftUI

// MARK: - Bubble Spa (a game in the drawer)
//
// A clear glass bathtub in a pink tiled bathroom, with her (the Dress Up girl, in her own face and hair) sitting in it.
// She turns the tap to fill it, squirts in bubble bath (it only foams up when the water is churned: under the tap or by
// swishing her hand), drops in bath bombs that sink, bob up, fizz, spin and dye the water, floats rubber ducks, a boat,
// a whale that blows a fountain and a turtle that dives, blows soap bubbles with a wand and pops them, washes with a
// sponge and the shower, paints on a face mask that dries and cracks, puts cucumber slices on her eyes, dries her with a
// towel, mops the floor, draws in the steamed-up mirror and pulls the plug to watch it all swirl away. No words, no
// voice, nothing to lose.
//
// Code: SpaSim (the simulation), SpaPaint (drawing), this file (screen and controls).
// Sounds: tools/spa/sounds.py -> App/Resources/Games/Spa/*.wav. Nothing is saved: every bath starts fresh.

enum SpaGame {
    static let entry = GameEntry(
        id: SpaSim.gameID,
        title: "Bubble Spa",
        tint: Color(hex: 0x9CDCF2),
        icon: { AnyView(SpaTileIcon()) },
        play: { exit in AnyView(SpaView(exit: exit)) }
    )
}

private struct SpaTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = size.width / 300
            g.scaleBy(x: k, y: k)
            // a tub full of foam with a duck
            let tub = SpaPainter.tubShape(CGRect(x: 30, y: 150, width: 240, height: 120), top: 10, bottom: 50)
            g.fill(tub, with: .linearGradient(Gradient(colors: [Color(hex: 0xBFEFFF), Color(hex: 0x5EC2E6)]), startPoint: CGPoint(x: 0, y: 150), endPoint: CGPoint(x: 0, y: 270)))
            g.stroke(tub, with: .color(.white), lineWidth: 8)
            var blobs: [(CGPoint, CGFloat)] = []
            for q in 0..<16 {
                blobs.append((CGPoint(x: 44 + CGFloat(q) * 14 + (shash(q) - 0.5) * 8, y: 150 - shash(q + 20) * 30), 16 + shash(q + 40) * 14))
            }
            SpaPainter.foamBlobs(g, blobs, color: RGB(1, 1, 1))
            var d = g
            d.translateBy(x: 196, y: 112)
            d.scaleBy(x: 1.2, y: 1.2)
            ThingPainter.duck(d, body: RGB(hex: "#FFD84A"), scale: 1)
            let film = Gradient(colors: [Color(hex: 0xFF9ECF), Color(hex: 0xFFE38A), Color(hex: 0x9FF0D8), Color(hex: 0x8FC6FF), Color(hex: 0xFF9ECF)])
            for (x, y, r) in [(80.0, 70.0, 30.0), (140.0, 40.0, 18.0), (60.0, 20.0, 12.0)] {
                let c = CGPoint(x: x, y: y)
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                g.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.25)))
                g.stroke(Path(ellipseIn: rect), with: .conicGradient(film, center: c), lineWidth: 4)
                g.fill(Path(ellipseIn: CGRect(x: x - r * 0.6, y: y - r * 0.6, width: r * 0.5, height: r * 0.3)), with: .color(.white))
            }
        }
    }
}

// MARK: - Sounds

enum SpaSFX: String, CaseIterable {
    case running, drain, fizz, shower, scrub
    case splash, bigsplash, plop, drip, pop, blow, squeak, squeak2, toot, spout, glug, squish, slosh, turn, plug, chime
}

/// The spa's own effects and its looping water sounds, from App/Resources/Games/Spa.
final class SpaSound {
    static let shared = SpaSound()
    private var players: [SpaSFX: [AVAudioPlayer]] = [:]
    private var loops: [SpaSFX: AVAudioPlayer] = [:]
    private var last: [SpaSFX: Date] = [:]
    static let looping: Set<SpaSFX> = [.running, .drain, .fizz, .shower, .scrub]
    /// Starting and fading players can stall for milliseconds, so it happens here, never on the frame being drawn.
    private let queue = DispatchQueue(label: "spa.sound", qos: .userInitiated)
    private var loopLevel: [SpaSFX: Float] = [:]
    private var loopSent: [SpaSFX: Float] = [:]

    private init() {
        _ = Sound.shared // sets up the audio session
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

    /// Fades a looping sound toward `volume`; it pauses when silent.
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

// MARK: - The screen

private enum SpaTray { case bombs, toys, masks }

private enum CaddySlot: String, CaseIterable {
    case soap, bombs, toys, wand, sponge, masks, shower, towel

    var spot: CGPoint {
        let i = CGFloat(CaddySlot.allCases.firstIndex(of: self) ?? 0)
        return CGPoint(x: 950, y: 94 + i * 94)
    }

    var tool: SpaTool? {
        switch self {
        case .soap: return .soap
        case .wand: return .wand
        case .sponge: return .sponge
        case .shower: return .shower
        case .towel: return .towel
        default: return nil
        }
    }
}

private extension SMap {
    // Wide phones have room beside the tub for four rows of paired tools.
    func caddySpot(_ slot: CaddySlot) -> CGPoint {
        guard wideCaddy, let i = CaddySlot.allCases.firstIndex(of: slot) else { return slot.spot }
        return CGPoint(x: 952 + CGFloat(i % 2) * 108, y: 244 + CGFloat(i / 2) * 114)
    }
}

/// One caddy button. It only redraws when what it shows changes.
private struct CaddyPlate: View, Equatable {
    let slot: CaddySlot
    let open: Bool
    let iconHidden: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(open ? Theme.pink : Color.white, lineWidth: 5))
                .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
            if !iconHidden {
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    SpaIcons.draw(slot, in: g)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: 86, height: 86)
    }
}

private enum SpaIcons {
    static func draw(_ slot: CaddySlot, in g: GraphicsContext) {
        var c = g
        switch slot {
        case .soap:
            c.scaleBy(x: 0.55, y: 0.55); c.translateBy(x: 0, y: 6)
            ToolPainter.soapBottle(c)
        case .bombs:
            var a = c; a.translateBy(x: -12, y: 8); a.scaleBy(x: 0.7, y: 0.7)
            ThingPainter.bomb(a, .rose, fizz: 1, fizzing: false, time: 0)
            var b = c; b.translateBy(x: 14, y: -10); b.scaleBy(x: 0.6, y: 0.6)
            ThingPainter.bomb(b, .ocean, fizz: 1, fizzing: false, time: 0)
        case .toys:
            c.translateBy(x: -4, y: 8); c.scaleBy(x: 0.62, y: 0.62)
            ThingPainter.duck(c, body: RGB(hex: "#FFD84A"), scale: 1)
        case .wand:
            ToolPainter.wand(c, tip: CGPoint(x: -10, y: -12), finger: CGPoint(x: 40, y: 50), film: 1, v: .zero, t: 0)
        case .sponge:
            c.scaleBy(x: 0.68, y: 0.68)
            ToolPainter.sponge(c, wet: 0, foam: 0.4, t: 0)
        case .masks:
            var j = c; j.translateBy(x: 10, y: 10)
            let jar = Path(roundedRect: CGRect(x: -22, y: -14, width: 44, height: 32), cornerRadius: 10)
            j.fill(jar, with: .color(MaskKind.clay.color.c()))
            j.stroke(jar, with: .color(Shades.outline(MaskKind.clay.color).c()), lineWidth: 2.5)
            j.fill(Path(roundedRect: CGRect(x: -24, y: -22, width: 48, height: 12), cornerRadius: 5), with: .color(.white))
            var k = c; k.translateBy(x: -18, y: -16)
            ToolPainter.cucumber(k, r: 15)
        case .shower:
            c.scaleBy(x: 0.7, y: 0.7)
            let chrome = Gradient(colors: [.white, Color(hex: 0xBFCCD9), Color(hex: 0x8FA0B3)])
            var h = Path(); h.move(to: CGPoint(x: 0, y: -4)); h.addLine(to: CGPoint(x: 36, y: 34))
            c.stroke(h, with: .linearGradient(chrome, startPoint: .zero, endPoint: CGPoint(x: 30, y: 30)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            let face = CGRect(x: -36, y: -26, width: 60, height: 28)
            c.fill(Path(ellipseIn: face), with: .linearGradient(chrome, startPoint: CGPoint(x: face.minX, y: face.minY), endPoint: CGPoint(x: face.maxX, y: face.maxY)))
            for q in 0..<5 {
                var d = Path(); d.move(to: CGPoint(x: -26 + CGFloat(q) * 10, y: 8)); d.addLine(to: CGPoint(x: -30 + CGFloat(q) * 10, y: 24))
                c.stroke(d, with: .color(Color(hex: 0x8FD0FF)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        case .towel:
            c.scaleBy(x: 0.55, y: 0.55)
            ToolPainter.towel(c, wet: 0)
        }
    }
}

final class SpaHandState {
    var lastPaint = CGPoint.zero
    var lastAt = Date()
    var startAt = Date()
    var active = false
}

struct SpaView: View {
    let exit: () -> Void

    @State private var sim = SpaSim()
    @State private var styling = !ProcessInfo.processInfo.arguments.contains("-spaDemo")
    @State private var rinseFoam = false
    @State private var paint: BombKind?
    @State private var tray: SpaTray?
    @State private var carrying: String?
    @State private var hidden: String?
    @State private var hand = SpaHandState()
    @State private var started = false
    /// The caddy tool she tapped: a tap on the bath makes it do that spot (see `ToolTap`).
    @State private var picked: CaddySlot?
    @State private var auto = AutoTool()

    var body: some View {
        GeometryReader { geo in
            let map = SMap(size: geo.size, styling: styling)
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { _ in
                    Canvas(opaque: true) { ctx, _ in SpaPainter.drawBackdrop(ctx, map: map) }
                }
                .allowsHitTesting(false)
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        SpaPainter.draw(ctx, map: map, sim: sim)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture(map))

                if let pk = picked {
                    ToolTapLayer(space: "spa",
                                 onDrag: { loc in
                                     if auto.running { auto.cancel() }
                                     useTool(pk, map.design(loc))
                                 },
                                 onEnd: { _ in endTool(pk) },
                                 onTap: { loc in autoDo(pk, map.design(loc), map) })
                }

                let controlWidth: CGFloat = map.wideCaddy ? 1130 : 1024
                Group {
                    if styling { mirrorControls }
                    else { controls(map) }
                }
                    .frame(width: controlWidth, height: 834)
                    .scaleEffect(map.ui)
                    .position(x: geo.size.width / 2 + (controlWidth - 1024) * map.ui / 2, y: geo.size.height / 2)
            }
            .coordinateSpace(name: "spa")
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onDisappear {
            auto.cancel()
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
            sim.vol = SGeo.maxDepth * 0.78
            sim.soap = 20
            sim.sculpture.begin(CGPoint(x: 228,y: 199))
            sim.sculpture.move(CGPoint(x: 201,y: 168))
            sim.sculpture.advance(0.02)
            sim.sculpture.held = nil
            sim.spawnThing(.toy(.duck), at: CGPoint(x: 510, y: sim.level - 18), held: false)
            sim.spawnThing(.toy(.boat), at: CGPoint(x: 680, y: sim.level - 12), held: false)
        }
    }

    // MARK: Her finger

    private func handGesture(_ map: SMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("spa"))
            .onChanged { v in
                let p = map.design(v.location)
                let now = Date()
                if !hand.active {
                    hand.active = true
                    hand.startAt = now
                    hand.lastAt = now
                    if tray != nil { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tray = nil } }
                    if styling {
                        let point = SGeo.toDoll(p)
                        if hypot(point.x-300,point.y-359) < 23 && !rinseFoam {
                            sim.sculpture.shake(); sim.giggle()
                        } else {
                            sim.sculpture.begin(point)
                            if rinseFoam { sim.pickUp(.shower, finger: p, lifted: CGPoint(x:p.x,y:p.y-57)) }
                            else { SpaSound.shared.play(.squish, volume: 0.45, gap: 0.12) }
                        }
                        return
                    }
                    sim.handBegan(p)
                    if let paint, sim.hand == .swish { sim.paintWater(p, dye: paint) }
                    hand.lastPaint = p
                } else {
                    let dt = CGFloat(max(1.0 / 120, now.timeIntervalSince(hand.lastAt)))
                    hand.lastAt = now
                    if styling {
                        sim.sculpture.move(SGeo.toDoll(p))
                        if rinseFoam { sim.carry(finger: p, lifted: CGPoint(x:p.x,y:p.y-57)) }
                        return
                    }
                    sim.handMoved(p, dt: dt)
                    if let paint, sim.hand == .swish {
                        let dx = p.x - hand.lastPaint.x, dy = p.y - hand.lastPaint.y
                        let distance = hypot(dx, dy)
                        if distance >= 14 {
                            let steps = min(16, Int(distance / 14))
                            for step in 1...steps {
                                let fraction = CGFloat(step) / CGFloat(steps)
                                sim.paintWater(CGPoint(x: hand.lastPaint.x + dx * fraction,
                                                       y: hand.lastPaint.y + dy * fraction), dye: paint)
                            }
                            hand.lastPaint = p
                        }
                    } else {
                        hand.lastPaint = p
                    }
                }
            }
            .onEnded { v in
                let p = map.design(v.location)
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                let tap = moved < 14 && Date().timeIntervalSince(hand.startAt) < 0.45
                if styling {
                    sim.sculpture.held = nil
                    if rinseFoam { sim.release() }
                } else { sim.handEnded(p, tap: tap) }
                hand.active = false
            }
    }

    // MARK: Controls

    private func controls(_ map: SMap) -> some View {
        ZStack {
            HomeButton(action: exit)
                .position(x: 62, y: 60)
            TimelineView(.periodic(from: .now, by: 0.2)) { _ in activityPrompt }
                .position(x: map.wideCaddy ? 865 : 512, y: 46)
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                let hint = paint == nil && !sim.starRound && picked == nil && sim.tool == nil && tray == nil && carrying == nil ? suggested : nil
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: hint == nil)) { tl in
                    caddy(map, hint: hint, time: tl.date.timeIntervalSinceReferenceDate)
                }
            }
            Button {
                auto.cancel()
                picked = nil; tray = nil
                sim.release()
                styling = true
            } label: {
                Image(systemName: "bubbles.and.sparkles.fill").font(.title)
                    .frame(width:62,height:62).background(.white,in: Circle())
            }.position(x: 153,y: 60).accessibilityLabel("Style bubble hair")
            paintPalette.position(x: map.wideCaddy ? 958 : 500, y: map.wideCaddy ? 708 : 795)
            if let t = tray {
                trayView(t, map)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var mirrorControls: some View {
        ZStack {
            HomeButton(action: exit).position(x: 63, y: 60)
            PlayPrompt(title: "Bath toys", actionSymbol: "arrow.right", action: {
                sim.sculpture.held = nil
                sim.release()
                styling = false
            }) { Image(systemName: "bathtub.fill") }
            .position(x: 854, y: 59)
            VStack(spacing: 14) {
                ForEach([BombKind.rose, .sunshine, .ocean, .mint], id: \.rawValue) { dye in
                    Button {
                        paint = dye
                        rinseFoam = false
                        sim.sculpture.rinsing = false
                        sim.sculpture.tint = dye.color
                        SpaSound.shared.play(.plop, volume: 0.5)
                    } label: {
                        Canvas { g, size in
                            let c = CGPoint(x:size.width/2,y:size.height/2)
                            SpaPainter.foamBlobs(g, [(c,20),(CGPoint(x:c.x-16,y:c.y+5),12),(CGPoint(x:c.x+15,y:c.y+8),13)], color:dye.color)
                        }.frame(width: 72,height: 64)
                        .background(paint == dye && !rinseFoam ? Theme.lemon : .white, in: Capsule())
                    }.accessibilityLabel("\(dye.rawValue) foam")
                }
                Button {
                    rinseFoam.toggle()
                    sim.sculpture.rinsing = rinseFoam
                } label: {
                    Image(systemName: "shower.fill").font(.system(size: 34))
                        .frame(width:72,height:64).background(rinseFoam ? Theme.sky : .white,in: Capsule())
                }.accessibilityLabel("Rinse the foam")
            }.buttonStyle(Squish()).position(x: 945, y: 437)
        }
    }

    private var paintPalette: some View {
        HStack(spacing: 3) {
            Image(systemName: "paintpalette.fill").foregroundStyle(Theme.ink)
            ForEach([BombKind.rose, .sunshine, .ocean, .mint], id: \.rawValue) { dye in
                Button {
                    auto.cancel()
                    picked = nil
                    tray = nil
                    sim.stopStarRound()
                    paint = paint == dye ? nil : dye
                    Sound.shared.tap()
                } label: {
                    Circle().fill(dye.color.c())
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .overlay {
                            if paint == dye { Image(systemName: "checkmark").foregroundStyle(Theme.ink) }
                        }
                        .frame(width: 42, height: 42)
                        .frame(width: 62, height: 64)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dye.rawValue) bath crayon")
            }
        }
        .font(.system(size: 24, weight: .bold))
        .padding(.horizontal, 14)
        .background(.regularMaterial, in: Capsule())
    }

    /// What would be fun next: it bounces gently.
    private var suggested: CaddySlot? {
        guard sim.vol > 60 else { return nil }   // the tap handle glows first
        if sim.soap < 1 { return .soap }
        if sim.things.isEmpty { return .toys }
        return nil
    }

    @ViewBuilder private var activityPrompt: some View {
        if let tool = picked {
            PlayPrompt(title: "\(tool.rawValue.capitalized) - Tap a spot", actionSymbol: "xmark", action: {
                auto.cancel()
                picked = nil
            }) { Image(systemName: "hand.tap.fill").font(.title) }
            .accessibilityHint("Put the tool away")
        } else if paint != nil {
            PlayPrompt(title: "Draw in the water", actionSymbol: "xmark", action: { paint = nil }) {
                Image(systemName: "scribble.variable").font(.title)
            }
        } else {
            let active = sim.starRound
            let title = active ? "Pop the stars  \(sim.starsPopped)/\(SpaSim.starGoal)"
                : (sim.starsPopped == SpaSim.starGoal ? "Rainbow bath! Play again" : "Star bubbles")
            PlayPrompt(title: title, actionSymbol: active ? "xmark" : "play.fill", action: {
                auto.cancel()
                tray = nil
                if sim.starRound { sim.stopStarRound() } else { sim.startStarRound() }
            }) { Image(systemName: "sparkles").font(.title).foregroundStyle(.purple) }
        }
    }

    private func caddy(_ map: SMap, hint: CaddySlot?, time: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(hex: 0xFFFFFF, alpha: 0.45))
                .frame(width: map.wideCaddy ? 218 : 108, height: map.wideCaddy ? 466 : 770)
                .position(x: map.wideCaddy ? 1006 : 950, y: map.wideCaddy ? 415 : 423)
            ForEach(CaddySlot.allCases, id: \.rawValue) { slot in
                let bounce: CGFloat = hint == slot ? CGFloat(abs(sin(time * 4))) * -12 : 0
                let open = (tray == .bombs && slot == .bombs) || (tray == .toys && slot == .toys) || (tray == .masks && slot == .masks)
                CaddyPlate(slot: slot, open: open, iconHidden: hidden == slot.rawValue)
                    .equatable()
                    .frame(width: map.wideCaddy ? 104 : 86, height: map.wideCaddy ? 108 : 86)
                    .opacity(hidden == slot.rawValue ? 0.35 : 1)
                    .picked(picked == slot && hidden != slot.rawValue, corner: 30)
                    .offset(x: bounce)
                    .contentShape(Rectangle())
                    .gesture(caddyGesture(slot, map))
                    .accessibilityLabel(slot.rawValue.capitalized)
                    .position(map.caddySpot(slot))
            }
        }
    }

    private func caddyGesture(_ slot: CaddySlot, _ map: SMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("spa"))
            .onChanged { v in
                paint = nil
                guard slot.tool != nil else { return }
                if auto.running { auto.cancel() }
                guard !ToolTap.isTap(v.translation) else { return }
                if carrying == nil {
                    picked = nil
                    sim.stopStarRound()
                }
                useTool(slot, map.design(v.location))
            }
            .onEnded { v in
                if slot.tool == nil {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    auto.cancel()
                    picked = nil
                    sim.stopStarRound()
                    let want: SpaTray = slot == .bombs ? .bombs : (slot == .toys ? .toys : .masks)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { tray = tray == want ? nil : want }
                    return
                }
                if carrying != nil { endTool(slot) }
                // a tap on the caddy picks the tool (or puts it down)
                if ToolTap.isTap(v.translation) {
                    sim.stopStarRound()
                    tray = nil
                    picked = picked == slot ? nil : slot
                    Sound.shared.play(.pop, volume: 0.6)
                }
            }
    }

    /// The caddy tool in her hand at p (design space): picked up first if it isn't yet.
    private func useTool(_ slot: CaddySlot, _ p: CGPoint) {
        guard let tool = slot.tool else { return }
        if carrying == nil {
            carrying = slot.rawValue
            hidden = slot.rawValue
            if tray != nil { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tray = nil } }
            Sound.shared.tap()
            sim.pickUp(tool, finger: p, lifted: SpaView.lifted(p, tool))
        }
        sim.carry(finger: p, lifted: SpaView.lifted(p, tool))
    }

    private func endTool(_ slot: CaddySlot) {
        sim.release()
        finishCarry(slot.rawValue)
    }

    /// The picked tool flies out of the caddy and does the spot she tapped by itself.
    private func autoDo(_ slot: CaddySlot, _ spot: CGPoint, _ map: SMap) {
        guard let tool = slot.tool else { return }
        let f = FingerLift.finger(for: spot, lift: SpaView.lift(tool), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
        auto.run(from: map.fromUI(map.caddySpot(slot)), to: f, step: { useTool(slot, $0) }, end: { _ in endTool(slot) })
    }

    /// Where a held tool goes for her finger at p (design space), so her finger never covers what it works on.
    static func lifted(_ p: CGPoint, _ tool: SpaTool) -> CGPoint {
        FingerLift.point(p, lift: lift(tool), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
    }

    static func lift(_ tool: SpaTool) -> CGFloat {
        let lift: CGFloat
        switch tool {
        case .wand, .mask: lift = FingerLift.tool                 // the ring, the brush tip
        case .shower: lift = FingerLift.pour                      // it rains down onto what's below it
        case .sponge, .towel: lift = FingerLift.grip              // held by a corner, up and to the left of her finger
        case .soap: lift = FingerLift.carry(below: 50)
        case .cucumber: lift = FingerLift.item
        }
        return lift
    }

    private func finishCarry(_ key: String) {
        carrying = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if carrying != key && hidden == key { hidden = nil }
        }
    }

    // MARK: Trays

    private func trayCount(_ t: SpaTray) -> Int {
        switch t {
        case .bombs: return BombKind.allCases.count
        case .toys: return ToyKind.tray.count
        case .masks: return MaskKind.allCases.count + 1
        }
    }

    private func trayY(_ t: SpaTray, _ map: SMap) -> CGFloat {
        let slot: CaddySlot = t == .bombs ? .bombs : (t == .toys ? .toys : .masks)
        return map.caddySpot(slot).y
    }

    private func trayView(_ t: SpaTray, _ map: SMap) -> some View {
        let n = trayCount(t)
        let w = CGFloat(n) * 98 + 24
        let y = trayY(t, map)
        return ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Theme.pink.opacity(0.5), lineWidth: 4))
                .shadow(color: Theme.ink.opacity(0.25), radius: 10, y: 6)
                .frame(width: w, height: 112)
                .position(x: 890 - w / 2, y: y)
            ForEach(0..<n, id: \.self) { i in
                trayItem(t, i, map)
                    .position(x: 890 - w + 12 + 49 + CGFloat(i) * 98, y: y)
            }
        }
        .opacity(carrying?.hasPrefix("tray") == true ? 0.3 : 1)
    }

    private func trayItem(_ t: SpaTray, _ i: Int, _ map: SMap) -> some View {
        let key = "tray\(i)"
        return Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            switch t {
            case .bombs:
                g.scaleBy(x: 1.15, y: 1.15)
                ThingPainter.bomb(g, BombKind.allCases[i], fizz: 1, fizzing: false, time: 0)
            case .toys:
                let k = ToyKind.tray[i]
                let s = min(1, 40 / max(k.half.width, k.half.height))
                g.scaleBy(x: s, y: s)
                var th = SThing(id: 0, kind: .toy(k), p: .zero)
                th.facing = 1
                ThingPainter.draw(g, th, time: 0)
            case .masks:
                if i < MaskKind.allCases.count {
                    let k = MaskKind.allCases[i]
                    let jar = Path(roundedRect: CGRect(x: -30, y: -16, width: 60, height: 44), cornerRadius: 14)
                    g.fill(jar, with: .color(.white))
                    g.stroke(jar, with: .color(Color(hex: 0xE9C9D6)), lineWidth: 3)
                    g.fill(Path(ellipseIn: CGRect(x: -26, y: -26, width: 52, height: 24)), with: .color(k.color.c()))
                    g.stroke(Path(ellipseIn: CGRect(x: -26, y: -26, width: 52, height: 24)), with: .color(Shades.outline(k.color).c()), lineWidth: 2)
                    g.fill(Path(ellipseIn: CGRect(x: -14, y: -22, width: 14, height: 6)), with: .color(.white.opacity(0.6)))
                } else {
                    ToolPainter.cucumber(g, r: 30)
                }
            }
        }
        .frame(width: 92, height: 100)
        .opacity(hidden == key ? 0.25 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("spa"))
                .onChanged { v in
                    let p = map.design(v.location)
                    let moved = hypot(v.translation.width, v.translation.height) / map.s
                    if carrying == nil {
                        // toys and bath bombs come out once she starts dragging; a tap drops one in
                        if (t == .bombs || t == .toys) && moved < 10 { return }
                        carrying = key
                        hidden = key
                        Sound.shared.tap()
                        switch t {
                        case .bombs, .toys:
                            let kind: ThingKind = t == .bombs ? .bomb(BombKind.allCases[i]) : .toy(ToyKind.tray[i])
                            let id = sim.spawnThing(kind, at: p, held: true)
                            sim.hand = .thing(id)
                            sim.handP = p
                        case .masks:
                            let tool: SpaTool = i < MaskKind.allCases.count ? .mask(MaskKind.allCases[i]) : .cucumber
                            sim.pickUp(tool, finger: p, lifted: SpaView.lifted(p, tool))
                        }
                    }
                    if t == .masks, let tool = sim.tool {
                        sim.carry(finger: p, lifted: SpaView.lifted(p, tool))
                    } else {
                        sim.handMoved(p, dt: 1.0 / 60)
                    }
                }
                .onEnded { v in
                    let p = map.design(v.location)
                    if carrying == nil {
                        if t == .bombs { sim.dropIn(.bomb(BombKind.allCases[i])) }
                        if t == .toys { sim.dropIn(.toy(ToyKind.tray[i])) }
                        Sound.shared.tap()
                        tray = nil
                        return
                    }
                    if t == .masks { sim.release() } else { sim.handEnded(p, tap: false) }
                    carrying = nil
                    hidden = nil
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tray = nil }
                }
        )
    }

    // MARK: Screenshot hooks

    /// -spaDemo full | foam | bomb | mask | wand | towel (a bath in progress, nothing saved, no sound).
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
        vol = SGeo.maxDepth * 0.85
        warm = 1
        for k in fog.indices { fog[k] = 0.8 }
        soap = 60
        for c in 0..<SGeo.columns {
            let x = SGeo.colX(c)
            foam[c] = max(0, 1.4 - abs(x - 600) / 260) + (x < 250 ? 0.6 : 0)
        }
        _ = spawnThing(.toy(.duck), at: CGPoint(x: 560, y: level - 20), held: false)
        _ = spawnThing(.toy(.duckling), at: CGPoint(x: 640, y: level - 20), held: false)
        _ = spawnThing(.toy(.boat), at: CGPoint(x: 730, y: level - 20), held: false)
        switch what {
        case "bomb":
            _ = spawnThing(.bomb(.lavender), at: CGPoint(x: 500, y: level + 40), held: false)
            if let j = things.indices.last { things[j].wetFor = 2; things[j].fizz = 0.7 }
            for _ in 0..<240 { step(dt: 1.0 / 60) }
        case "mask":
            for k in maskCov.indices where SGeo.inHead(maskCellCenter(k), pad: -10) {
                maskCov[k] = 1
                maskKind[k] = MaskKind.clay.rawValue
                maskDry[k] = maskCellCenter(k).y < 300 ? 0.9 : 0.2
            }
            cucumbers = [true, true]
        case "wand":
            for k in 0..<10 {
                spawnBubble(at: CGPoint(x: 420 + CGFloat(k) * 40, y: 220 + CGFloat(k % 3) * 60), v: .zero, r: 14 + CGFloat(k % 4) * 8)
            }
            pickUp(.wand, finger: CGPoint(x: 700, y: 520), lifted: CGPoint(x: 680, y: 400))
        case "towel":
            for k in 0..<12 { addBead(CGPoint(x: 220 + CGFloat(k) * 14, y: 300 + CGFloat(k % 4) * 30)) }
            for k in 0..<10 { addSud(CGPoint(x: 190 + CGFloat(k) * 24, y: 170 + CGFloat(k % 3) * 14), r: 14) }
            pickUp(.towel, finger: CGPoint(x: 520, y: 520), lifted: CGPoint(x: 470, y: 420))
        default:
            tapOn = true
            flow = 1
            handleTurn = 1
            for _ in 0..<120 { step(dt: 1.0 / 60) }
        }
        for _ in 0..<30 { step(dt: 1.0 / 60) }
    }
}
