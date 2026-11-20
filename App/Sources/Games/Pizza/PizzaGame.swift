import AVFoundation
import SwiftUI

// MARK: - Pizza (a game in the drawer)
//
// A pizza kitchen. An animal customer shows the pizza they'd love on a picture card. She kneads a shaggy dough ball
// smooth with her hands, flattens it and stretches it out (it springs back a little, like real dough; a quick flick
// up tosses it spinning in the air), ladles sauce on and spreads it with the back of the ladle, shakes grated cheese
// over it, puts toppings on, and slides it into a wood-fired oven where the cheese melts, bubbles and browns and the
// crust turns golden. Then she rolls the pizza wheel across it to cut slices and taps a slice: it lifts away with
// stretchy cheese and the customer eats it. Every step is open at any time; nothing to read, no voice.
//
// Code: PizzaSim (simulation), PizzaPaint (drawing), this file (screen, controls, sounds).
// Sounds: tools/pizza/sounds.py -> App/Resources/Games/Pizza/*.wav. Saves: pizza.json (hearts and pizzas served).

enum PizzaGame {
    static let entry = GameEntry(
        id: PizzaSim.gameID,
        title: "Pizza",
        tint: Color(hex: 0xFFB26B),
        icon: { AnyView(PizzaTileIcon()) },
        play: { exit in AnyView(PizzaView(exit: exit)) }
    )
}

private struct PizzaTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = size.width / 300
            g.scaleBy(x: k, y: k)
            g.translateBy(x: 140, y: 160)
            let R: CGFloat = 112
            let whole = Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2))
            var rest = Path()
            rest.move(to: .zero)
            rest.addArc(center: .zero, radius: R + 4, startAngle: .degrees(-20), endAngle: .degrees(290), clockwise: false)
            rest.closeSubpath()
            func pie(_ g: GraphicsContext) {
                g.fill(whole, with: .color(RGB(0.9, 0.62, 0.32).color))
                g.fill(Path(ellipseIn: CGRect(x: -R + 16, y: -R + 16, width: R * 2 - 32, height: R * 2 - 32)), with: .color(RGB(0.82, 0.22, 0.12).color))
                g.fill(Path(ellipseIn: CGRect(x: -R + 24, y: -R + 24, width: R * 2 - 48, height: R * 2 - 48)), with: .color(RGB(1.0, 0.85, 0.44).color))
                for (i, p) in [CGPoint(x: -40, y: -30), CGPoint(x: 30, y: 40), CGPoint(x: -36, y: 46), CGPoint(x: 10, y: -58), CGPoint(x: 52, y: -32)].enumerated() {
                    var tg = g
                    tg.translateBy(x: p.x, y: p.y)
                    tg.scaleBy(x: 1.05, y: 1.05)
                    PizzaPainter.topping(tg, .pepperoni, seed: i, bake: 0.8)
                }
                var bg = g
                bg.translateBy(x: -2, y: 4)
                bg.rotate(by: .degrees(30))
                PizzaPainter.topping(bg, .basil, seed: 1, bake: 0.2)
            }
            var a = g
            a.clip(to: rest)
            pie(a)
            // one slice pulled out
            var s = g
            s.translateBy(x: 26, y: -22)
            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addArc(center: .zero, radius: R + 4, startAngle: .degrees(290), endAngle: .degrees(340), clockwise: false)
            wedge.closeSubpath()
            s.clip(to: wedge)
            pie(s)
        }
    }
}

// MARK: - Sounds

enum PizzaSFX: String, CaseIterable {
    case knead, slap, toss, stretch, glop, spread, sprinkle, plop, oven, fire, sizzle, bubble, ding, crunch, roll
    case stretchy, snap, nom, yay, whoosh
}

/// The pizza kitchen's effects and its looping sounds, from App/Resources/Games/Pizza.
final class PizzaSound {
    static let shared = PizzaSound()
    static let looping: Set<PizzaSFX> = [.spread, .sprinkle, .fire, .sizzle, .roll]
    private var players: [PizzaSFX: [AVAudioPlayer]] = [:]
    private var loops: [PizzaSFX: AVAudioPlayer] = [:]
    private var last: [PizzaSFX: Date] = [:]
    private var loopLevel: [PizzaSFX: Float] = [:]
    private var loopSent: [PizzaSFX: Float] = [:]
    /// Starting and fading AVAudioPlayers can stall, so it happens here, never on the frame being drawn.
    private let queue = DispatchQueue(label: "pizza.sound", qos: .userInitiated)

    private init() {
        _ = Sound.shared // sets up the audio session
        for s in PizzaSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "Pizza") else { continue }
            if PizzaSound.looping.contains(s) {
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

    func play(_ s: PizzaSFX, volume: Float = 0.9, gap: Double = 0) {
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

    /// Fades a looping sound toward `volume` (called every frame; only reaches the player when it changes enough).
    func setLoop(_ s: PizzaSFX, volume: Float) {
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

final class PizzaHand {
    var lastAt = Date()
    var startAt = Date()
    var active = false
    var idleSince = Date()
    var dockStart = Date()
}

private enum PizzaSlot: Hashable {
    case ladle, cheese, cutter
    case topping(ToppingKind)

    var tool: PizzaTool {
        switch self {
        case .ladle: return .ladle
        case .cheese: return .cheese
        case .cutter: return .cutter
        case .topping(let k): return .topping(k)
        }
    }

    var kind: ToppingKind? {
        if case .topping(let k) = self { return k }
        return nil
    }

    var spot: CGPoint {
        switch self {
        case .ladle, .cheese, .cutter: return CGPoint(x: 112, y: 470)
        case .topping(let k):
            let i = ToppingKind.allCases.firstIndex(of: k) ?? 0
            return CGPoint(x: 70 + CGFloat(i % 2) * 96, y: 236 + CGFloat(i / 2) * 104)
        }
    }
}

/// One button in the tool dock. It only redraws when what it shows changes.
private struct PizzaDockPlate: View, Equatable {
    let slot: PizzaSlot
    let wanted: Bool
    let big: Bool

    var body: some View {
        let side: CGFloat = big ? 150 : 88
        return ZStack {
            RoundedRectangle(cornerRadius: big ? 36 : 24, style: .continuous)
                .fill(.white.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: big ? 36 : 24, style: .continuous)
                    .stroke(wanted ? Theme.pink : Color.white, lineWidth: wanted ? 5 : 4))
                .shadow(color: Theme.ink.opacity(0.22), radius: 7, y: 5)
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                switch slot {
                case .ladle:
                    // a pot of sauce with the ladle in it
                    let pot = Path(roundedRect: CGRect(x: -52, y: -6, width: 104, height: 58), cornerRadius: 16)
                    g.fill(pot, with: .linearGradient(Gradient(colors: [RGB(0.9, 0.9, 0.93).color, RGB(0.6, 0.62, 0.66).color]),
                                                      startPoint: CGPoint(x: -52, y: 0), endPoint: CGPoint(x: 52, y: 0)))
                    g.fill(Path(ellipseIn: CGRect(x: -52, y: -20, width: 104, height: 30)), with: .color(RGB(0.5, 0.52, 0.56).color))
                    g.fill(Path(ellipseIn: CGRect(x: -46, y: -16, width: 92, height: 22)), with: .color(RGB(0.78, 0.18, 0.1).color))
                    g.fill(Path(ellipseIn: CGRect(x: -30, y: -14, width: 26, height: 8)), with: .color(.white.opacity(0.35)))
                    var lg = g
                    lg.translateBy(x: 6, y: -6)
                    lg.rotate(by: .degrees(200))
                    lg.scaleBy(x: 0.42, y: 0.42)
                    lg.translateBy(x: 0, y: -40)
                    PizzaPainter.ladle(lg, load: 0)
                case .cheese:
                    g.scaleBy(x: 0.95, y: 0.95)
                    PizzaPainter.cheeseBowl(g)
                case .cutter:
                    g.rotate(by: .degrees(35))
                    g.scaleBy(x: 0.5, y: 0.5)
                    g.translateBy(x: 0, y: -70)
                    PizzaPainter.cutter(g, spin: 0.3)
                case .topping(let k):
                    // a little pile of them
                    for (i, o) in [CGPoint(x: -14, y: 10), CGPoint(x: 14, y: 8), CGPoint(x: 0, y: -10)].enumerated() {
                        var tg = g
                        tg.translateBy(x: o.x, y: o.y)
                        tg.rotate(by: .degrees(Double(i) * 50))
                        tg.scaleBy(x: 0.8, y: 0.8)
                        PizzaPainter.topping(tg, k, seed: i * 13 + 2, bake: 0)
                    }
                }
            }
            .allowsHitTesting(false)
            if wanted {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.pink)
                    .padding(5)
                    .background(Circle().fill(.white))
                    .offset(x: side / 2 - 8, y: -side / 2 + 8)
            }
        }
        .frame(width: side, height: side)
    }
}

/// A picture for each step in the bar at the top.
private struct StepIcon: View, Equatable {
    let step: PizzaStep

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            switch step {
            case .dough:
                let b = Path(ellipseIn: CGRect(x: -22, y: -18, width: 44, height: 38))
                g.fill(b, with: .radialGradient(Gradient(colors: [RGB(1, 0.97, 0.88).color, RGB(0.9, 0.78, 0.58).color]),
                                                center: CGPoint(x: -8, y: -8), startRadius: 1, endRadius: 30))
                g.stroke(b, with: .color(RGB(0.72, 0.57, 0.38).color), lineWidth: 2)
            case .sauce:
                g.scaleBy(x: 0.3, y: 0.3)
                g.rotate(by: .degrees(-30))
                g.translateBy(x: 0, y: -50)
                PizzaPainter.ladle(g, load: 1)
            case .cheese:
                g.scaleBy(x: 0.36, y: 0.36)
                PizzaPainter.cheeseBowl(g)
            case .toppings:
                g.scaleBy(x: 0.9, y: 0.9)
                PizzaPainter.topping(g, .pepperoni, seed: 1, bake: 0)
            case .bake:
                var fl = Path()
                fl.move(to: CGPoint(x: 0, y: -24))
                fl.addCurve(to: CGPoint(x: 0, y: 22), control1: CGPoint(x: 26, y: -2), control2: CGPoint(x: 22, y: 22))
                fl.addCurve(to: CGPoint(x: 0, y: -24), control1: CGPoint(x: -22, y: 22), control2: CGPoint(x: -18, y: -6))
                g.fill(fl, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD24A), Color(hex: 0xFF6A2A)]),
                                                 startPoint: CGPoint(x: 0, y: -24), endPoint: CGPoint(x: 0, y: 22)))
                g.fill(Path(ellipseIn: CGRect(x: -7, y: 2, width: 14, height: 18)), with: .color(Color(hex: 0xFFF2A8)))
            case .slice:
                g.rotate(by: .degrees(30))
                g.scaleBy(x: 0.3, y: 0.3)
                g.translateBy(x: 0, y: -60)
                PizzaPainter.cutter(g, spin: 0)
            }
        }
        .frame(width: 60, height: 60)
        .allowsHitTesting(false)
    }
}

struct PizzaView: View {
    let exit: () -> Void

    @State private var sim = PizzaSim()
    @State private var grids = PizzaGrids()
    @State private var hand = PizzaHand()
    @State private var carrying: PizzaSlot?
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            let map = GMap(size: geo.size)
            ZStack {
                // the counter and board don't move: drawn once
                Canvas(opaque: true) { ctx, _ in
                    PizzaPainter.drawCounter(ctx, map: map)
                }
                .allowsHitTesting(false)
                // everything that moves, capped at 60 fps so 120 Hz screens don't double the work
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
                    Canvas { ctx, _ in
                        sim.step(tl.date)
                        PizzaPainter.draw(ctx, map: map, sim: sim, grids: grids)
                    }
                }
                .contentShape(Rectangle())
                .gesture(handGesture(map))

                TimelineView(.periodic(from: .now, by: 0.1)) { tl in
                    controls(map, time: tl.date.timeIntervalSinceReferenceDate)
                }
                .frame(width: 1024, height: 834)
                .scaleEffect(map.s)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .coordinateSpace(name: "pizza")
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onDisappear {
            sim.persist()
            PizzaSound.shared.stopLoops()
        }
    }

    private func start() {
        guard !started else { return }
        started = true
        _ = PizzaSound.shared
        applyLaunchArguments()
    }

    // MARK: Hand

    private func handGesture(_ map: GMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("pizza"))
            .onChanged { v in
                let p = map.design(v.location)
                let now = Date()
                hand.idleSince = now
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
                hand.idleSince = Date()
            }
    }

    // MARK: Controls

    private func controls(_ map: GMap, time: Double) -> some View {
        let step = sim.stage
        let ready = sim.ready(step)
        let bounce: CGFloat = ready ? CGFloat(abs(sin(time * 4))) * -12 : 0
        let idle = Date().timeIntervalSince(hand.idleSince)
        return ZStack {
            HomeButton(action: exit)
                .position(x: 62, y: 60)
            stepBar(step)
                .position(x: 470, y: 60)
            dock(step, map)
            nextButton(step, ready: ready)
                .offset(y: bounce)
                .position(x: 938, y: 752)
            if step == .dough && sim.ball && idle > 2.5 && !hand.active {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 6, y: 3)
                    .scaleEffect(1 + 0.12 * CGFloat(sin(time * 5)))
                    .position(x: PGeo.center.x + 40, y: PGeo.center.y + 70)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 1024, height: 834)
    }

    private func stepBar(_ current: PizzaStep) -> some View {
        HStack(spacing: 10) {
            ForEach(PizzaStep.allCases, id: \.self) { s in
                Button {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.6)
                    sim.go(s)
                } label: {
                    StepIcon(step: s)
                        .equatable()
                        .frame(width: 70, height: 70)
                        .background(Circle().fill(.white))
                        .overlay(Circle().stroke(current == s ? Theme.pink : Color.white.opacity(0.7), lineWidth: current == s ? 6 : 3))
                        .scaleEffect(current == s ? 1.1 : 0.92)
                        .shadow(color: Theme.ink.opacity(0.2), radius: 6, y: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: current)
                }
                .buttonStyle(Squish())
            }
        }
    }

    private func nextButton(_ step: PizzaStep, ready: Bool) -> some View {
        let last = step == .slice
        return Button {
            Sound.shared.tap()
            if last {
                sim.newPizza()
            } else if let n = PizzaStep(rawValue: step.rawValue + 1) {
                Sound.shared.play(.pop, volume: 0.6)
                sim.go(n)
            }
        } label: {
            ZStack {
                Circle().fill(ready ? Theme.pink : Color.white)
                if step == .bake {
                    // how baked it is, as a ring that fills
                    Circle()
                        .trim(from: 0, to: CGFloat(sim.bake))
                        .stroke(Color(hex: 0xFFB23D), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(6)
                }
                Image(systemName: last ? "arrow.counterclockwise" : "arrow.right")
                    .font(.system(size: 46, weight: .heavy))
                    .foregroundStyle(ready ? Color.white : Theme.pink)
            }
            .frame(width: 112, height: 112)
            .overlay(Circle().stroke(.white, lineWidth: 6))
            .shadow(color: Theme.ink.opacity(0.28), radius: 8, y: 5)
        }
        .buttonStyle(Squish())
    }

    private func slots(_ step: PizzaStep) -> [PizzaSlot] {
        switch step {
        case .sauce: return [.ladle]
        case .cheese: return [.cheese]
        case .toppings: return ToppingKind.allCases.map { PizzaSlot.topping($0) }
        case .slice: return [.cutter]
        default: return []
        }
    }

    private func dock(_ step: PizzaStep, _ map: GMap) -> some View {
        ZStack {
            ForEach(slots(step), id: \.self) { slot in
                PizzaDockPlate(slot: slot, wanted: slot.kind.map { sim.order.wants.contains($0) } ?? false, big: slot.kind == nil)
                    .equatable()
                    .opacity(carrying == slot && slot.kind == nil ? 0.35 : 1)
                    .position(slot.spot)
                    .gesture(dockGesture(slot, map))
            }
        }
    }

    private func dockGesture(_ slot: PizzaSlot, _ map: GMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("pizza"))
            .onChanged { v in
                let p = map.design(v.location)
                hand.idleSince = Date()
                if carrying == nil {
                    carrying = slot
                    hand.dockStart = Date()
                    Sound.shared.tap()
                    sim.pickUp(slot.tool, finger: p)
                }
                sim.carry(p)
            }
            .onEnded { v in
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                let tap = moved < 14 && Date().timeIntervalSince(hand.dockStart) < 0.45
                if tap {
                    sim.tool = nil
                    sim.tapTool(slot.tool, from: slot.spot)
                } else {
                    sim.release()
                }
                carrying = nil
            }
    }

    // MARK: Screenshot hooks

    /// -pizzaDemo <knead | stretch | toss | sauce | cheese | toppings | bake | baked | slice | serve>
    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-pizzaDemo"), i + 1 < args.count {
            sim.demoSetup(args[i + 1])
        }
    }
}
