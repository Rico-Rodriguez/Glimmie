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
        play: { exit in AnyView(PizzaView(exit: exit)) },
        stickers: PizzaFind.stickers
    )
}

private struct PizzaTileIcon: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = min(size.width, size.height) / 300
            g.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 300 * k) / 2)
            g.scaleBy(x: k, y: k)
            g.translateBy(x: 138, y: 162)

            let R: CGFloat = 110
            let crustOutline = StorybookArt.outline(for: 0xDF9644)
            let whole = Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2))

            var rest = Path()
            rest.move(to: .zero)
            rest.addArc(center: .zero, radius: R + 8, startAngle: .degrees(-18), endAngle: .degrees(288), clockwise: false)
            rest.closeSubpath()

            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addArc(center: .zero, radius: R + 8, startAngle: .degrees(288), endAngle: .degrees(342), clockwise: false)
            wedge.closeSubpath()

            func drawPie(_ target: GraphicsContext) {
                // Shaded golden puffed crust
                target.fill(
                    whole,
                    with: .radialGradient(
                        Gradient(colors: [StorybookArt.color(0xF6C77E), StorybookArt.color(0xE89F4E), StorybookArt.color(0xD27F34)]),
                        center: CGPoint(x: -28, y: -34),
                        startRadius: 10,
                        endRadius: R * 1.15
                    )
                )
                target.stroke(whole, with: .color(crustOutline), lineWidth: 7)

                // Soft inner crust ridge highlight & wood-fired leopard blisters
                let ridge = Path(ellipseIn: CGRect(x: -R + 9, y: -R + 9, width: (R - 9) * 2, height: (R - 9) * 2))
                target.stroke(ridge, with: .color(StorybookArt.color(0xFFF0C4).opacity(0.45)), lineWidth: 4.5)
                let blisters: [(CGFloat, CGFloat, CGFloat)] = [(-86, -42, 6), (-52, 82, 5.5), (56, 78, 6), (86, -24, 5), (-18, -96, 5)]
                for (bx, by, br) in blisters {
                    target.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br * 0.7, width: br * 2, height: br * 1.4)),
                                with: .color(StorybookArt.color(0x8C431C, alpha: 0.42)))
                }

                // Glossy tomato sauce
                let sauceR = R - 17
                let saucePath = Path(ellipseIn: CGRect(x: -sauceR, y: -sauceR, width: sauceR * 2, height: sauceR * 2))
                target.fill(
                    saucePath,
                    with: .radialGradient(
                        Gradient(colors: [StorybookArt.color(0xE84B35), StorybookArt.color(0xC72C1A)]),
                        center: CGPoint(x: -18, y: -20),
                        startRadius: 6,
                        endRadius: sauceR * 1.15
                    )
                )

                // Melted wavy mozzarella layer with glossy sheen
                var cheesePts: [CGPoint] = []
                for i in 0..<20 {
                    let a = Double(i) / 20 * 2 * .pi
                    let rr = (R - 25) * (0.94 + 0.06 * CGFloat(sin(Double(i) * 2.3)))
                    cheesePts.append(CGPoint(x: CGFloat(cos(a)) * rr, y: CGFloat(sin(a)) * rr))
                }
                let cheesePath = PizzaPainter.smoothClosed(cheesePts)
                target.fill(
                    cheesePath,
                    with: .radialGradient(
                        Gradient(colors: [StorybookArt.color(0xFFF3A8), StorybookArt.color(0xFFE06E), StorybookArt.color(0xF2BA43)]),
                        center: CGPoint(x: -24, y: -26),
                        startRadius: 6,
                        endRadius: R
                    )
                )
                target.stroke(cheesePath, with: .color(StorybookArt.outline(for: 0xF2BA43).opacity(0.65)), lineWidth: 2.5)
                StorybookArt.highlight(target, in: CGRect(x: -54, y: -62, width: 42, height: 18), opacity: 0.45)

                // Cupped baked pepperoni slices
                let peps: [(CGFloat, CGFloat)] = [(-44, -30), (34, 42), (-36, 48), (12, -56), (52, -26), (-4, 8)]
                for (i, (px, py)) in peps.enumerated() {
                    var tg = target
                    tg.translateBy(x: px, y: py)
                    tg.scaleBy(x: 0.96, y: 0.96)
                    PizzaPainter.topping(tg, .pepperoni, seed: i + 1, bake: 0.78)
                }

                // Fresh basil leaves
                let basils: [(CGFloat, CGFloat, Double)] = [(-16, -24, -22), (24, 6, 38), (-14, 58, 18)]
                for (i, (bx, by, rot)) in basils.enumerated() {
                    var bg = target
                    bg.translateBy(x: bx, y: by)
                    bg.rotate(by: .degrees(rot))
                    bg.scaleBy(x: 0.78, y: 0.78)
                    PizzaPainter.topping(bg, .basil, seed: i + 3, bake: 0.25)
                }
            }

            // Soft drop shadow under the main pie
            var shadowBase = g
            shadowBase.clip(to: rest)
            shadowBase.fill(whole.offsetBy(dx: 5, dy: 10), with: .color(Theme.ink.opacity(0.22)))

            // Main pie
            var mainPie = g
            mainPie.clip(to: rest)
            drawPie(mainPie)

            // Stretchy melted cheese strings bridging to the lifted slice
            let liftOff = CGPoint(x: 28, y: -24)
            for (angDeg, d, w) in [(289.0, 46.0, 6.0), (291.0, 74.0, 4.8), (340.0, 48.0, 5.5), (338.0, 76.0, 4.2)] {
                let rad = angDeg * .pi / 180
                let p0 = CGPoint(x: CGFloat(cos(rad) * d), y: CGFloat(sin(rad) * d))
                let p1 = CGPoint(x: p0.x + liftOff.x, y: p0.y + liftOff.y)
                var str = Path()
                str.move(to: p0)
                str.addQuadCurve(to: p1, control: CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2 + 8))
                g.stroke(str, with: .color(StorybookArt.outline(for: 0xF2BA43)), style: StrokeStyle(lineWidth: CGFloat(w) + 2.5, lineCap: .round))
                g.stroke(str, with: .color(StorybookArt.color(0xFFE680)), style: StrokeStyle(lineWidth: CGFloat(w), lineCap: .round))
            }

            // Lifted cheesy slice with warm shadow and crisp cut edges
            var sShadow = g
            sShadow.translateBy(x: liftOff.x + 6, y: liftOff.y + 13)
            sShadow.clip(to: wedge)
            sShadow.fill(whole, with: .color(Theme.ink.opacity(0.22)))

            var lifted = g
            lifted.translateBy(x: liftOff.x, y: liftOff.y)
            lifted.clip(to: wedge)
            drawPie(lifted)

            var cutOutline = g
            cutOutline.translateBy(x: liftOff.x, y: liftOff.y)
            var sliceEdge = Path()
            sliceEdge.move(to: .zero)
            sliceEdge.addArc(center: .zero, radius: R, startAngle: .degrees(288), endAngle: .degrees(342), clockwise: false)
            sliceEdge.closeSubpath()
            cutOutline.stroke(sliceEdge, with: .color(crustOutline), style: StrokeStyle(lineWidth: 5, lineJoin: .round))

            // Storybook sparkles
            StorybookArt.sparkle(g, at: CGPoint(x: -98, y: -96), radius: 13, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: 112, y: -96), radius: 11, color: .white)
            StorybookArt.sparkle(g, at: CGPoint(x: 114, y: 66), radius: 9, color: Theme.lemon)
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
    private static let maxPoolSize = 3

    private var players: [PizzaSFX: [AVAudioPlayer]] = [:]
    private var loops: [PizzaSFX: AVAudioPlayer] = [:]
    private var missing: Set<PizzaSFX> = []
    private var last: [PizzaSFX: Date] = [:]
    private var loopLevel: [PizzaSFX: Float] = [:]
    private var loopSent: [PizzaSFX: Float] = [:]
    /// Starting and fading AVAudioPlayers can stall, so it happens here, never on the frame being drawn.
    private let queue = DispatchQueue(label: "pizza.sound", qos: .userInitiated)

    static func url(for s: PizzaSFX) -> URL? {
        GameFiles.url(s.rawValue, "caf", game: "Pizza") ?? GameFiles.url(s.rawValue, "wav", game: "Pizza")
    }

    private init() {
        _ = Sound.shared // sets up the audio session
    }

    func play(_ s: PizzaSFX, volume: Float = 0.9, gap: Double = 0) {
        queue.async {
            let now = Date()
            if gap > 0, let t = self.last[s], now.timeIntervalSince(t) < gap { return }
            self.last[s] = now
            guard let p = self.player(for: s) else { return }
            p.volume = volume
            p.currentTime = 0
            p.play()
        }
    }

    /// Fades a looping sound toward `volume` (called every frame; only reaches the player when it changes enough).
    func setLoop(_ s: PizzaSFX, volume: Float) {
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
        loopLevel.removeAll()
        loopSent.removeAll()
        queue.async {
            for p in self.loops.values {
                p.pause()
                p.volume = 0
            }
        }
    }

    private func player(for s: PizzaSFX) -> AVAudioPlayer? {
        guard !missing.contains(s) else { return nil }
        let pool = players[s] ?? []
        if let idle = pool.first(where: { !$0.isPlaying }) { return idle }
        if pool.count < Self.maxPoolSize {
            if let url = Self.url(for: s), let created = try? AVAudioPlayer(contentsOf: url) {
                created.prepareToPlay()
                players[s] = pool + [created]
                return created
            }
            if pool.isEmpty { missing.insert(s) }
        }
        return pool.max(by: { $0.currentTime < $1.currentTime }) ?? pool.first
    }

    private func loopPlayer(for s: PizzaSFX) -> AVAudioPlayer? {
        if let existing = loops[s] { return existing }
        guard !missing.contains(s) else { return nil }
        guard let url = Self.url(for: s), let created = try? AVAudioPlayer(contentsOf: url) else {
            missing.insert(s)
            return nil
        }
        created.numberOfLoops = -1
        created.volume = 0
        created.prepareToPlay()
        loops[s] = created
        return created
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
            return CGPoint(x: 70 + CGFloat(i % 2) * 96, y: 200 + CGFloat(i / 2) * 98)
        }
    }
}

/// One button in the tool dock, wrapped in Glimmie's shared `GameDockTile` chrome.
private struct PizzaDockPlate: View, Equatable {
    let slot: PizzaSlot
    let wanted: Bool
    let big: Bool

    var body: some View {
        let side: CGFloat = big ? 148 : 84
        return GameDockTile(size: side, selected: wanted, tint: .white, cornerRadius: big ? 32 : 24) {
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2)
                switch slot {
                case .ladle:
                    let pot = Path(roundedRect: CGRect(x: -50, y: -6, width: 100, height: 56), cornerRadius: 16)
                    g.fill(pot, with: .linearGradient(Gradient(colors: [RGB(0.9, 0.9, 0.93).color, RGB(0.6, 0.62, 0.66).color]),
                                                      startPoint: CGPoint(x: -50, y: 0), endPoint: CGPoint(x: 50, y: 0)))
                    g.fill(Path(ellipseIn: CGRect(x: -50, y: -20, width: 100, height: 30)), with: .color(RGB(0.5, 0.52, 0.56).color))
                    g.fill(Path(ellipseIn: CGRect(x: -44, y: -16, width: 88, height: 22)), with: .color(RGB(0.78, 0.18, 0.1).color))
                    g.fill(Path(ellipseIn: CGRect(x: -28, y: -14, width: 25, height: 8)), with: .color(.white.opacity(0.35)))
                    var lg = g
                    lg.translateBy(x: 6, y: -6)
                    lg.rotate(by: .degrees(200))
                    lg.scaleBy(x: 0.41, y: 0.41)
                    lg.translateBy(x: 0, y: -40)
                    PizzaPainter.ladle(lg, load: 0)
                case .cheese:
                    g.scaleBy(x: 0.92, y: 0.92)
                    PizzaPainter.cheeseBowl(g)
                case .cutter:
                    g.rotate(by: .degrees(35))
                    g.scaleBy(x: 0.48, y: 0.48)
                    g.translateBy(x: 0, y: -70)
                    PizzaPainter.cutter(g, spin: 0.3)
                case .topping(let k):
                    for (i, o) in [CGPoint(x: -13, y: 9), CGPoint(x: 13, y: 7), CGPoint(x: 0, y: -9)].enumerated() {
                        var tg = g
                        tg.translateBy(x: o.x, y: o.y)
                        tg.rotate(by: .degrees(Double(i) * 50))
                        tg.scaleBy(x: 0.76, y: 0.76)
                        PizzaPainter.topping(tg, k, seed: i * 13 + 2, bake: 0)
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if wanted {
                Image(systemName: "heart.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.pink)
                    .padding(5)
                    .background(Circle().fill(.white))
                    .overlay(Circle().stroke(Theme.blush, lineWidth: 2))
                    .offset(x: 7, y: -7)
            }
        }
    }
}

/// A picture for each step in the bar at the top.
private struct StepIcon: View, Equatable {
    let step: PizzaStep

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let scale = min(size.width, size.height) / 60
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: scale, y: scale)
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
        .frame(width: 46, height: 46)
        .allowsHitTesting(false)
    }
}

/// Pulsing golden ring around the oven step icon when a player tries serving raw empty dough.
private struct PizzaOvenNudgeRing: View {
    let sim: PizzaSim

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { tl in
            let nudging = sim.time - sim.ovenNudgeAt < 2.2
            if nudging {
                let pulse = CGFloat(1.08 + 0.08 * sin(tl.date.timeIntervalSinceReferenceDate * 10))
                Circle()
                    .stroke(Color(hex: 0xFFA52C), lineWidth: 5)
                    .frame(width: 64, height: 64)
                    .scaleEffect(pulse)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Smoothly animated next/new-pizza button (polling scoped strictly to this leaf).
private struct PizzaDynamicNextButton: View {
    let sim: PizzaSim
    let step: PizzaStep
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            PizzaNextButton(step: step, ready: sim.ready(step), bakeProgress: sim.bake, action: action)
        }
    }
}

private struct PizzaNextButton: View {
    let step: PizzaStep
    let ready: Bool
    let bakeProgress: Double
    let action: () -> Void

    @State private var bounceUp = false

    var body: some View {
        let last = step == .slice
        Button(action: action) {
            ZStack {
                Circle().fill(ready ? Theme.pink : Color.white)
                if step == .bake {
                    Circle()
                        .trim(from: 0, to: CGFloat(bakeProgress))
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
        .offset(y: ready && bounceUp ? -11 : 0)
        .onAppear { syncBounce(ready) }
        .onChange(of: ready) { isReady in syncBounce(isReady) }
    }

    private func syncBounce(_ isReady: Bool) {
        if isReady {
            bounceUp = false
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                bounceUp = true
            }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                bounceUp = false
            }
        }
    }
}

private struct PizzaDynamicHeartsBadge: View {
    let sim: PizzaSim

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            PizzaHeartsBadge(hearts: sim.save.hearts)
        }
    }
}

private struct PizzaHeartsBadge: View {
    let hearts: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color(hex: 0xF45C9A))
            Text("\(hearts)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(height: GameChromeLayout.buttonSize)
        .background(Capsule().fill(.white))
        .overlay(Capsule().stroke(Theme.blush, lineWidth: 5))
        .shadow(color: Theme.ink.opacity(0.22), radius: 6, y: 4)
        .allowsHitTesting(false)
    }
}

private enum PizzaCueKind: Equatable {
    case knead, flatten, toss, stoke
}

/// Scoped periodic check for pictorial idle hints without redrawing the dock or chrome.
private struct PizzaDynamicCueOverlay: View {
    let sim: PizzaSim
    let hand: PizzaHand

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            if let cue = activeCue {
                PizzaPictorialCue(kind: cue)
            }
        }
    }

    private var activeCue: PizzaCueKind? {
        guard !hand.active, !sim.hold else { return nil }
        let idle = Date().timeIntervalSince(hand.idleSince)
        switch sim.stage {
        case .dough:
            if sim.ball {
                if sim.kneads >= PGeo.knead && idle > 1.2 { return .flatten }
                if sim.kneads < PGeo.knead && idle > 2.2 { return .knead }
            } else if sim.tossStart == nil && sim.meanR < 185 && idle > 2.4 {
                return .toss
            }
        case .bake:
            if sim.bake < 0.96 && idle > 2.2 { return .stoke }
        default:
            break
        }
        return nil
    }
}

/// Smooth pictorial hints (zero text) when idle on knead, flatten, dough toss, or oven stoke.
private struct PizzaPictorialCue: View {
    let kind: PizzaCueKind
    @State private var animate = false

    var body: some View {
        Group {
            switch kind {
            case .knead:
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 6, y: 3)
                    .scaleEffect(animate ? 0.9 : 1.08)
                    .offset(y: animate ? 8 : -6)
                    .position(x: PGeo.center.x + 38, y: PGeo.center.y + 68)
            case .flatten:
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 7)
                        .frame(width: 170, height: 170)
                        .scaleEffect(animate ? 1.32 : 0.88)
                        .opacity(animate ? 0.15 : 0.9)
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.ink.opacity(0.35), radius: 6, y: 3)
                        .scaleEffect(animate ? 0.88 : 1.08)
                }
                .position(PGeo.center)
            case .toss:
                VStack(spacing: -8) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white.opacity(0.92))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(Theme.lemon.opacity(0.95))
                }
                .shadow(color: Theme.ink.opacity(0.35), radius: 5, y: 3)
                .offset(y: animate ? -26 : 12)
                .opacity(animate ? 0.25 : 0.95)
                .position(x: PGeo.center.x, y: PGeo.center.y - 34)
            case .stoke:
                ZStack {
                    Circle()
                        .stroke(Theme.lemon, lineWidth: 7)
                        .frame(width: 108, height: 108)
                        .scaleEffect(animate ? 1.28 : 0.86)
                        .opacity(animate ? 0.12 : 0.88)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFE378))
                        .shadow(color: Color(hex: 0xFF6A2A).opacity(0.6), radius: 6)
                        .scaleEffect(animate ? 1.15 : 0.92)
                }
                .position(x: 315, y: 308)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            animate = false
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: kind == .knead)) {
                animate = true
            }
        }
        .id(kind)
    }
}

struct PizzaView: View {
    let exit: () -> Void

    @State private var sim = PizzaSim()
    @State private var grids = PizzaGrids()
    @State private var hand = PizzaHand()
    @State private var uiStage: PizzaStep = .dough
    @State private var uiWants: [ToppingKind] = []
    @State private var carrying: PizzaSlot?
    @State private var showStickers = false
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

                controls(map)
                    .frame(width: 1024, height: 834)
                    .coinPurse(game: PizzaSim.gameID)
                    .scaleEffect(map.s)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                if showStickers {
                    StickerBookView(game: PizzaSim.gameID) {
                        withAnimation(.spring(response: 0.35)) { showStickers = false }
                    }
                    .transition(.opacity)
                    .zIndex(5)
                }
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
        sim.onAutoNewPizza = {
            syncUIState()
        }
        applyLaunchArguments()
        syncUIState()
    }

    private func syncUIState() {
        uiStage = sim.stage
        uiWants = sim.order.wants
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

    private func controls(_ map: GMap) -> some View {
        ZStack {
            GameTopBar(
                gameID: PizzaSim.gameID,
                showStickerBook: true,
                showCoins: true,
                onExit: exit,
                onStickerBook: {
                    withAnimation(.spring(response: 0.35)) { showStickers = true }
                },
                center: {
                    stepBar(uiStage)
                },
                trailing: {
                    PizzaDynamicHeartsBadge(sim: sim)
                }
            )
            dock(uiStage, map)
            PizzaDynamicNextButton(sim: sim, step: uiStage) {
                Sound.shared.tap()
                if uiStage == .slice {
                    sim.newPizza()
                } else if let n = PizzaStep(rawValue: uiStage.rawValue + 1) {
                    Sound.shared.play(.pop, volume: 0.6)
                    sim.go(n)
                }
                syncUIState()
            }
            .position(x: 938, y: 752)
            PizzaDynamicCueOverlay(sim: sim, hand: hand)
            StickerToast(game: PizzaSim.gameID, target: GameChromeLayout.stickerTarget)
        }
        .frame(width: 1024, height: 834)
    }

    private func stepBar(_ current: PizzaStep) -> some View {
        GameTrayCard(cornerRadius: 30, paddingH: 8, paddingV: 5) {
            HStack(spacing: 6) {
                ForEach(PizzaStep.allCases, id: \.self) { s in
                    Button {
                        Sound.shared.tap()
                        Sound.shared.play(.pop, volume: 0.6)
                        sim.go(s)
                        syncUIState()
                    } label: {
                        StepIcon(step: s)
                            .equatable()
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(.white))
                            .overlay(Circle().stroke(current == s ? Theme.pink : Theme.blush.opacity(0.6), lineWidth: current == s ? 5 : 2.5))
                            .overlay {
                                if s == .bake {
                                    PizzaOvenNudgeRing(sim: sim)
                                }
                            }
                            .scaleEffect(current == s ? 1.08 : 0.92)
                            .shadow(color: Theme.ink.opacity(0.16), radius: 4, y: 3)
                            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: current)
                    }
                    .buttonStyle(Squish())
                }
            }
        }
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
        let currentSlots = slots(step)
        return ZStack {
            if step == .toppings {
                GameTrayCard(cornerRadius: 34, paddingH: 0, paddingV: 0) {
                    Color.clear.frame(width: 210, height: 516)
                }
                .position(x: 118, y: 396)
                .allowsHitTesting(false)
            } else if !currentSlots.isEmpty {
                GameTrayCard(cornerRadius: 40, paddingH: 0, paddingV: 0) {
                    Color.clear.frame(width: 174, height: 174)
                }
                .position(x: 112, y: 470)
                .allowsHitTesting(false)
            }

            ForEach(currentSlots, id: \.self) { slot in
                PizzaDockPlate(slot: slot, wanted: slot.kind.map { uiWants.contains($0) } ?? false, big: slot.kind == nil)
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
