import AVFoundation
import SwiftUI

// MARK: - Aquarium (a game in the drawer)
//
// A glass fish tank on a wooden cabinet. She carries tools off the dock: the food shaker, turned over and shaken above
// the water, drops flakes that float, soak and flutter down while the fish race up to gulp them; the sponge rubs the
// algae off the glass (it grows back slowly, and the snail grazes on it); the net scoops a fish up (let it go in the
// water, or lift it out onto the cabinet to send it home). Bags of fish pour new friends in with a splash, and
// decorations sink through the water and thump into the sand. Tap a fish and it wiggles (the puffer puffs up), tap the
// glass and they dart off and come back to look, rest a finger on the glass and they gather round it, drag along the
// surface to make waves, pop bubbles, open the treasure chest. The lamp turns day or night; the pump makes bubbles.
// Everything is open, nothing to read, no voice.
//
// Code: AquariumSim (the simulation), AquariumScene + AquariumFish + AquariumDecor (drawing), this file (screen).
// Sounds: tools/aquarium/sounds.py -> App/Resources/Games/Aquarium/*.wav. Saves: aquarium.json.

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
                let k = size.width / 300
                g.scaleBy(x: k, y: k)
                var sand = Path()
                sand.move(to: CGPoint(x: -10, y: 310))
                sand.addQuadCurve(to: CGPoint(x: 310, y: 310), control: CGPoint(x: 150, y: 222))
                sand.closeSubpath()
                g.fill(sand, with: .color(ARGB(0xF4E0B6).color))
                var sw = g
                sw.translateBy(x: 62, y: 300)
                sw.scaleBy(x: 0.55, y: 0.55)
                AquaDecorPainter.seaweed(sw, t: t, sway: 0, seed: 1)
                var f = g
                f.translateBy(x: 160, y: 140 + sin(t * 1.3) * 6)
                f.scaleBy(x: 1.9, y: 1.9)
                AquaFishPainter.drawLocal(f, kind: .goldfish, variant: 0, phase: t * 6, amp: 0.25, gulp: 0, puff: 0, time: t)
                var bubbles = Path()
                for i in 0..<4 {
                    let y = 120 - (t * 40 + CGFloat(i) * 50).truncatingRemainder(dividingBy: 200)
                    let r = 6 + CGFloat(i % 2) * 4
                    bubbles.addEllipse(in: CGRect(x: 250 + sin(t * 3 + CGFloat(i)) * 4 - r, y: y + 80 - r, width: r * 2, height: r * 2))
                }
                g.stroke(bubbles, with: .color(.white.opacity(0.9)), lineWidth: 3)
            }
        }
    }
}

// MARK: - Sounds

enum AquaSFX: String, CaseIterable {
    case bloop, pop, plop, splash, splish, gulp, squeak, tink, thud, shake, puff, swish, chime, blub, creak, bag, pick, click, boing
    case hum, pump
}

/// The aquarium's own effects and its looping hum and pump, from App/Resources/Games/Aquarium.
final class AquaSound {
    static let shared = AquaSound()
    static let looping: Set<AquaSFX> = [.hum, .pump]
    private var players: [AquaSFX: [AVAudioPlayer]] = [:]
    private var loops: [AquaSFX: AVAudioPlayer] = [:]
    private var last: [AquaSFX: Date] = [:]
    /// Starting and fading players can stall for milliseconds, so it all happens on this queue, never on a drawing frame.
    private let queue = DispatchQueue(label: "aquarium.sound", qos: .userInitiated)
    private var loopLevel: [AquaSFX: Float] = [:]
    private var loopSent: [AquaSFX: Float] = [:]

    private init() {
        _ = Sound.shared // sets up the audio session
        for s in AquaSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "Aquarium") else { continue }
            if AquaSound.looping.contains(s) {
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

    func play(_ s: AquaSFX, volume: Float = 0.9, gap: Double = 0) {
        let now = Date()
        if gap > 0, let t = last[s], now.timeIntervalSince(t) < gap { return }
        last[s] = now
        guard let pool = players[s], !pool.isEmpty else { return }
        // a little pitch-free variety: each play a touch louder or softer
        let v = volume * Float.random(in: 0.85...1)
        queue.async {
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = v
            p.currentTime = 0
            p.play()
        }
    }

    /// Fades a looping sound toward `volume`; it pauses when silent. Only reaches the player when the level moved.
    func setLoop(_ s: AquaSFX, volume: Float) {
        guard let p = loops[s] else { return }
        let old = loopLevel[s] ?? 0
        let v = old + (volume - old) * 0.08
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

private enum AquaTray { case fish, decor }

private enum AquaSlot: String, CaseIterable {
    case food, sponge, net, fish, decor

    func spot(_ map: AMap) -> CGPoint {
        let i = CGFloat(AquaSlot.allCases.firstIndex(of: self) ?? 0)
        if map.sideDock { return CGPoint(x: 1120, y: 164 + i * 132) }
        return CGPoint(x: 264 + i * 124, y: AGeo.dockY)
    }
}

/// One tool button on the dock. It only redraws when what it shows changes, so bouncing it is just a move.
private struct AquaDockPlate: View, Equatable {
    let slot: AquaSlot
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
                    case .food:
                        g.translateBy(x: 0, y: -32)
                        g.scaleBy(x: 0.72, y: 0.72)
                        AquaDecorPainter.shaker(g)
                    case .sponge:
                        g.rotate(by: .radians(-0.2))
                        g.scaleBy(x: 0.9, y: 0.9)
                        AquaDecorPainter.sponge(g)
                    case .net:
                        g.rotate(by: .radians(0.6))
                        g.translateBy(x: 0, y: -40)
                        g.scaleBy(x: 0.58, y: 0.58)
                        AquaDecorPainter.netFront(g)
                    case .fish:
                        g.scaleBy(x: 0.9, y: 0.9)
                        AquaDecorPainter.bag(g, kind: .goldfish, time: 0)
                    case .decor:
                        var a = g
                        a.translateBy(x: -10, y: 36)
                        a.scaleBy(x: 0.4, y: 0.4)
                        AquaDecorPainter.castle(a)
                        var b = g
                        b.translateBy(x: 28, y: 38)
                        b.scaleBy(x: 0.6, y: 0.6)
                        AquaDecorPainter.shell(b)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: 108, height: 108)
    }
}

final class AquaHandState {
    var lastAt = Date()
    var startAt = Date()
    var active = false
}

struct AquariumView: View {
    let exit: () -> Void

    @State private var sim = AquariumSim()
    @State private var tray: AquaTray?
    @State private var lightsOn = true
    @State private var pump = true
    @State private var carrying: String?
    @State private var hidden: String?
    /// Touch bookkeeping lives outside SwiftUI state so a drag does not rebuild the view on every move.
    @State private var hand = AquaHandState()
    @State private var started = false
    /// The food, sponge or net she tapped on the dock: a tap on the tank makes it do that spot (see `ToolTap`).
    @State private var picked: AquaSlot?
    @State private var auto = AutoTool()
    @State private var book = false
    static let bookSpot = CGPoint(x: 150, y: 46)

    var body: some View {
        GeometryReader { geo in
            // the tank is zoomed in to fill the screen; the buttons stay their usual size
            let map = AMap.tank(size: geo.size)
            ZStack {
                // The room, the back of the tank and the sand change slowly: 30 fps in their own layer.
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                    Canvas(opaque: true) { ctx, _ in
                        AquaPainter.drawBackdrop(ctx, map: map, sim: sim)
                    }
                }
                .allowsHitTesting(false)
                // Everything that moves, capped at 60 fps so 120 Hz screens do not double the work.
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        AquaPainter.draw(ctx, map: map, sim: sim)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture(map))

                if let pk = picked {
                    ToolTapLayer(space: "aquarium",
                                 onDrag: { loc in
                                     if auto.running { auto.cancel() }
                                     useTool(pk, map.design(loc))
                                 },
                                 onEnd: { _ in endTool(pk, map) },
                                 onTap: { loc in autoDo(pk, map.design(loc), map) })
                }

                let controlWidth: CGFloat = map.sideDock ? 1180 : 1024
                controls(map)
                    .frame(width: controlWidth, height: 834)
                    .scaleEffect(map.ui)
                    .position(x: map.uox + controlWidth * map.ui / 2, y: geo.size.height / 2)

                if book {
                    StickerBookView(game: AquariumSim.gameID) { withAnimation(.easeOut(duration: 0.2)) { book = false } }
                        .transition(.opacity)
                        .zIndex(2)
                }
            }
            .coordinateSpace(name: "aquarium")
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onDisappear {
            auto.cancel()
            sim.save()
            AquaSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = AquaSound.shared
        lightsOn = sim.lightsOn
        pump = sim.pump
        applyLaunchArguments()
        sim.openReef()
    }

    // MARK: Hand

    private func handGesture(_ map: AMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("aquarium"))
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

    private func controls(_ map: AMap) -> some View {
        ZStack {
            HomeButton(action: exit)
                .position(x: 62, y: 46)
            StickerBookButton(game: AquariumSim.gameID) { book = true }
                .position(x: AquariumView.bookSpot.x, y: AquariumView.bookSpot.y)
            HStack(spacing: 16) {
                toggle(symbol: lightsOn ? "sun.max.fill" : "moon.stars.fill", tint: lightsOn ? Color(hex: 0xFFB83D) : Color(hex: 0x7A7AF0), on: true) {
                    lightsOn.toggle()
                    sim.setLights(lightsOn)
                }
                toggle(symbol: "bubbles.and.sparkles.fill", tint: Color(hex: 0x3FA9E0), on: pump) {
                    pump.toggle()
                    sim.setPump(pump)
                }
            }
            .position(x: 880, y: 46)
            // Which tool to suggest is checked a few times a second; the bounce itself runs only while one is suggested.
            TimelineView(.periodic(from: .now, by: 0.2)) { _ in activityPrompt }
                .position(x: 512, y: 46)
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                let hint = sim.huntKind == nil && picked == nil && sim.tool == nil && tray == nil ? suggested : nil
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: hint == nil)) { tl in
                    dock(map, hint: hint, time: tl.date.timeIntervalSinceReferenceDate)
                }
            }
            if let t = tray {
                trayView(t, map)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            StickerToast(game: AquariumSim.gameID, target: AquariumView.bookSpot)
        }
    }

    @ViewBuilder private var activityPrompt: some View {
        if let tool = picked {
            let title = tool == .food ? "Tap to sprinkle" : (tool == .net ? "Tap or sweep a fish" : "Rub the glass")
            PlayPrompt(title: title, actionSymbol: "xmark", action: {
                auto.cancel()
                picked = nil
            }) { Image(systemName: "hand.tap.fill").font(.title) }
            .accessibilityHint("Put the tool away")
        } else if let kind = sim.huntKind {
            PlayPrompt(title: "Find this fish  \(sim.fishFound)/\(AquariumSim.huntGoal)", actionSymbol: "xmark",
                       action: { sim.stopFishHunt() }) {
                Canvas { ctx, size in
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    let scale = min(0.72, 46 / max(kind.length + kind.tailLength, kind.height))
                    g.scaleBy(x: scale, y: scale)
                    let variant = sim.fish.first { $0.kind == kind && !$0.caught }?.variant ?? 0
                    AquaFishPainter.drawLocal(g, kind: kind, variant: variant, phase: 0, amp: 0.2, gulp: 0, puff: 0, time: 0)
                }
            }
            .accessibilityLabel("Find the \(kind.rawValue), \(sim.fishFound) of \(AquariumSim.huntGoal) found")
        } else {
            let title = sim.fishFound == AquariumSim.huntGoal ? "Feeding time! Play again" : "Fish hunt"
            PlayPrompt(title: title, actionSymbol: "play.fill", action: {
                auto.cancel()
                tray = nil
                sim.startFishHunt()
            }) { Image(systemName: "magnifyingglass").font(.title) }
            .disabled(sim.fish.isEmpty)
        }
    }

    private func toggle(symbol: String, tint: Color, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Sound.shared.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 66, height: 66)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(on ? tint : Color.white.opacity(0.6), lineWidth: on ? 5 : 3))
                .opacity(on ? 1 : 0.6)
                .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
        }
        .buttonStyle(Squish())
    }

    /// Which tool would help right now: it bounces gently.
    private var suggested: AquaSlot? {
        if sim.dirtiness > 0.3 { return .sponge }
        if sim.time - sim.lastFed > 50 { return .food }
        return nil
    }

    private func dock(_ map: AMap, hint: AquaSlot?, time: Double) -> some View {
        ZStack {
            ForEach(AquaSlot.allCases, id: \.rawValue) { slot in
                let bounce: CGFloat = hint == slot ? CGFloat(abs(sin(time * 4))) * -14 : 0
                let open = (tray == .fish && slot == .fish) || (tray == .decor && slot == .decor)
                AquaDockPlate(slot: slot, open: open, iconHidden: hidden == slot.rawValue)
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

    private func dockGesture(_ slot: AquaSlot, _ map: AMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("aquarium"))
            .onChanged { v in
                let p = map.design(v.location)
                switch slot {
                case .fish, .decor:
                    return
                case .food, .sponge, .net:
                    if auto.running { auto.cancel() }
                    guard !ToolTap.isTap(v.translation) else { return }
                    if carrying == nil {
                        picked = nil
                        sim.stopFishHunt()
                    }
                    useTool(slot, p)
                }
            }
            .onEnded { v in
                switch slot {
                case .fish, .decor:
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    auto.cancel()
                    picked = nil
                    sim.stopFishHunt()
                    let want: AquaTray = slot == .fish ? .fish : .decor
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { tray = tray == want ? nil : want }
                case .food, .sponge, .net:
                    if carrying != nil { endTool(slot, map) }
                    // a tap on the dock picks the tool (or puts it down)
                    if ToolTap.isTap(v.translation) {
                        sim.stopFishHunt()
                        tray = nil
                        picked = picked == slot ? nil : slot
                        Sound.shared.play(.pop, volume: 0.6)
                    }
                }
            }
    }

    private func tool(for slot: AquaSlot) -> AquaTool {
        slot == .food ? .food : (slot == .sponge ? .sponge : .net)
    }

    /// The food, sponge or net in her hand at p (design space): picked up first if it isn't yet.
    private func useTool(_ slot: AquaSlot, _ p: CGPoint) {
        if carrying == nil {
            carrying = slot.rawValue
            hidden = slot.rawValue
            tray = nil
            Sound.shared.tap()
            sim.pickUp(tool(for: slot), at: p)
        }
        // she holds the net by its grip and the sponge by a corner, the food is shaken from above (see `FingerLift`)
        if let tl = sim.tool { sim.carry(to: AquariumView.lifted(p, tl), hand: p) }
    }

    private func endTool(_ slot: AquaSlot, _ map: AMap) {
        sim.release(home: map.fromUI(slot.spot(map)))
        finishCarry(slot.rawValue)
    }

    /// The picked tool flies off the dock and does the spot she tapped by itself.
    private func autoDo(_ slot: AquaSlot, _ spot: CGPoint, _ map: AMap) {
        guard slot == .food || slot == .sponge || slot == .net else { return }
        if slot == .food {
            sim.feed(at: spot)
            return
        }
        if slot == .net {
            guard AGeo.tank.contains(spot) else { return }
            // Start the scoop on the fish while it is still under the tap.
            auto.run(from: spot, to: spot, step: { p in
                let x = max(AGeo.left + 1, min(AGeo.right - 1, p.x))
                let y = max(AGeo.waterY, min(AGeo.bottomY - 1, p.y))
                useTool(slot, CGPoint(x: x, y: y))
            }, end: { _ in endTool(slot, map) })
            return
        }
        let f = FingerLift.finger(for: spot, lift: AquariumView.lift(tool(for: slot)), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
        auto.run(from: map.fromUI(slot.spot(map)), to: f, step: { useTool(slot, $0) }, end: { _ in endTool(slot, map) })
    }

    /// Where a carried thing goes for her finger at p (design space). Things drawn around their middle are lifted
    /// until their lowest part still clears her finger.
    static func lifted(_ p: CGPoint, _ tool: AquaTool) -> CGPoint {
        if tool == .food, AGeo.tank.contains(p) {
            return CGPoint(x: p.x, y: AGeo.waterY - 16)
        }
        return FingerLift.point(p, lift: lift(tool), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
    }

    static func lift(_ tool: AquaTool) -> CGFloat {
        let lift: CGFloat
        switch tool {
        case .net: lift = 0
        case .sponge: lift = FingerLift.grip                   // her finger at its corner, the sponge up and to the left
        case .food: lift = FingerLift.pour
        case .fish: lift = FingerLift.carry(below: 50)
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

    private func trayView(_ t: AquaTray, _ map: AMap) -> some View {
        let count = t == .fish ? FishKind.allCases.count : AquaDecorKind.available.count
        let perRow = t == .fish ? count : 6
        let rows = (count + perRow - 1) / perRow
        let rowH: CGFloat = 116
        let midY: CGFloat = 630 - CGFloat(rows - 1) * rowH * 0.5
        return ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).stroke(Theme.pink.opacity(0.5), lineWidth: 4))
                .shadow(color: Theme.ink.opacity(0.25), radius: 10, y: 6)
                .frame(width: CGFloat(perRow) * 108 + 30, height: CGFloat(rows) * rowH + 24)
                .position(x: 512, y: midY + CGFloat(rows - 1) * rowH * 0.5)
            ForEach(0..<count, id: \.self) { i in
                let col = i % perRow, row = i / perRow
                trayItem(t, i, map)
                    .position(x: 512 + (CGFloat(col) - CGFloat(perRow - 1) / 2) * 108, y: midY + CGFloat(row) * rowH)
            }
        }
        .opacity(carrying?.hasPrefix("tray") == true ? 0.3 : 1)
    }

    private func trayItem(_ t: AquaTray, _ i: Int, _ map: AMap) -> some View {
        let key = "tray\(i)"
        return Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            if t == .fish {
                let k = FishKind.allCases[i]
                let s = min(1.3, 76 / (k.length + k.tailLength))
                if k == .seahorse {
                    g.scaleBy(x: 1.05, y: 1.05)
                } else {
                    g.translateBy(x: k.tailLength * s * 0.35, y: 0)
                    g.scaleBy(x: s, y: s)
                }
                AquaFishPainter.drawLocal(g, kind: k, variant: 0, phase: 1, amp: 0.2, gulp: 0, puff: 0, time: 0)
            } else {
                let k = AquaDecorKind.available[i]
                let s = min(0.9, 92 / max(k.size.height, k.size.width))
                g.translateBy(x: 0, y: k.size.height * s * 0.5)
                g.scaleBy(x: s, y: s)
                AquaDecorPainter.drawKind(g, k, time: 0, sway: 0, open: 0, seed: 1)
            }
        }
        .frame(width: 100, height: 104)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(t == .fish ? Color(hex: 0xD8F3FF) : Color(hex: 0xFFF4E2)))
        .opacity(hidden == key ? 0.25 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("aquarium"))
                .onChanged { v in
                    guard !ToolTap.isTap(v.translation) else { return }
                    let p = map.design(v.location)
                    if carrying == nil {
                        carrying = key
                        hidden = key
                        Sound.shared.tap()
                        let tool: AquaTool = t == .fish ? .fish(FishKind.allCases[i]) : .decor(AquaDecorKind.available[i])
                        sim.pickUp(tool, at: p)
                    }
                    if let tl = sim.tool { sim.carry(to: AquariumView.lifted(p, tl), hand: p) }
                }
                .onEnded { v in
                    if carrying == nil {
                        let x = map.design(v.startLocation).x
                        if t == .fish { sim.addFish(FishKind.allCases[i], x: x, y: AGeo.waterY - 18) }
                        else { sim.addDecor(AquaDecorKind.available[i], x: x, falling: true, y: AGeo.waterY) }
                        Sound.shared.tap()
                    } else {
                        sim.release(home: map.fromUI(t == .fish ? AquaSlot.fish.spot(map) : AquaSlot.decor.spot(map)))
                    }
                    carrying = nil
                    hidden = nil
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { tray = nil }
                }
        )
    }

    // MARK: Screenshot hooks

    /// -aquaDemo (a busy tank, nothing saved), -aquaNight, -aquaTool <food|sponge|net> (a tool held still),
    /// -aquaTray <fish|decor>.
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-aquaDemo") { sim.showcase() }
        if args.contains("-aquaNight") {
            sim.demo = true
            lightsOn = false
            sim.lightsOn = false
            sim.night = 1
        }
        if let i = args.firstIndex(of: "-aquaTray"), i + 1 < args.count {
            tray = args[i + 1] == "decor" ? .decor : .fish
        }
        if let i = args.firstIndex(of: "-aquaTool"), i + 1 < args.count {
            sim.demo = true
            switch args[i + 1] {
            case "sponge":
                sim.pickUp(.sponge, at: CGPoint(x: 300, y: 520))
                sim.carry(to: CGPoint(x: 300, y: 400), hand: CGPoint(x: 300, y: 520))
                hidden = AquaSlot.sponge.rawValue
            case "net":
                sim.pickUp(.net, at: CGPoint(x: 560, y: 560))
                sim.carry(to: CGPoint(x: 560, y: 440), hand: CGPoint(x: 600, y: 560))
                hidden = AquaSlot.net.rawValue
            default:
                sim.pickUp(.food, at: CGPoint(x: 520, y: 210))
                sim.carry(to: CGPoint(x: 520, y: 100), hand: CGPoint(x: 520, y: 220))
                sim.shake = 1.5
                hidden = AquaSlot.food.rawValue
            }
        }
    }
}

extension AquariumSim {
    /// Fills the tank for screenshots: lots of fish, decorations, food on its way down, a half-cleaned glass.
    func showcase() {
        demo = true
        fish = []
        decor = []
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
        for i in fish.indices { fish[i].dir = i % 2 == 0 ? 1 : -1; fish[i].facing = fish[i].dir; fish[i].z = 0.4 + CGFloat(i % 4) * 0.15 }
        for k in 0..<14 {
            addFlake(at: CGPoint(x: 460 + CGFloat(k) * 9, y: AGeo.waterY + 30 + CGFloat(k * 7 % 60)), v: .zero)
            food[food.count - 1].state = .sinking
        }
        for r in 0..<AGeo.algaeRows {
            for c in 0..<AGeo.algaeCols {
                let i = r * AGeo.algaeCols + c
                algae[i] = c > 30 ? aqClamp(0.35 + aqRand(i, 9) * 0.6) : 0
            }
        }
        for k in 0..<30 {
            addBubble(CGPoint(x: 470 + CGFloat.random(in: -10...10), y: 600 - CGFloat(k) * 15), r: CGFloat.random(in: 2...5))
        }
    }
}
