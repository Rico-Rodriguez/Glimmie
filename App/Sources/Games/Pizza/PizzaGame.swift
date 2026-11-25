import AVFoundation
import SwiftUI

// MARK: - Pizza (3-stage tactile kitchen)

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

                let ridge = Path(ellipseIn: CGRect(x: -R + 9, y: -R + 9, width: (R - 9) * 2, height: (R - 9) * 2))
                target.stroke(ridge, with: .color(StorybookArt.color(0xFFF0C4).opacity(0.45)), lineWidth: 4.5)
                let blisters: [(CGFloat, CGFloat, CGFloat)] = [(-86, -42, 6), (-52, 82, 5.5), (56, 78, 6), (86, -24, 5), (-18, -96, 5)]
                for (bx, by, br) in blisters {
                    target.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br * 0.7, width: br * 2, height: br * 1.4)),
                                with: .color(StorybookArt.color(0x8C431C, alpha: 0.42)))
                }

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

                let peps: [(CGFloat, CGFloat)] = [(-44, -30), (34, 42), (-36, 48), (12, -56), (52, -26), (-4, 8)]
                for (i, (px, py)) in peps.enumerated() {
                    var tg = target
                    tg.translateBy(x: px, y: py)
                    tg.scaleBy(x: 0.96, y: 0.96)
                    PizzaPainter.topping(tg, .pepperoni, seed: i + 1, bake: 0.78)
                }

                let basils: [(CGFloat, CGFloat, Double)] = [(-16, -24, -22), (24, 6, 38), (-14, 58, 18)]
                for (i, (bx, by, rot)) in basils.enumerated() {
                    var bg = target
                    bg.translateBy(x: bx, y: by)
                    bg.rotate(by: .degrees(rot))
                    bg.scaleBy(x: 0.78, y: 0.78)
                    PizzaPainter.topping(bg, .basil, seed: i + 3, bake: 0.25)
                }
            }

            var shadowBase = g
            shadowBase.clip(to: rest)
            shadowBase.fill(whole.offsetBy(dx: 5, dy: 10), with: .color(Theme.ink.opacity(0.22)))

            var mainPie = g
            mainPie.clip(to: rest)
            drawPie(mainPie)

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

            StorybookArt.sparkle(g, at: CGPoint(x: -98, y: -96), radius: 13, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: 112, y: -96), radius: 11, color: .white)
            StorybookArt.sparkle(g, at: CGPoint(x: 114, y: 66), radius: 9, color: Theme.lemon)
        }
    }
}

// MARK: - Sounds (20 bundled .caf/.wav cues)

enum PizzaSFX: String, CaseIterable {
    case knead, slap, toss, stretch, glop, spread, sprinkle, plop, oven, fire, sizzle, bubble, ding, crunch, roll
    case stretchy, snap, nom, yay, whoosh
}

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
    private let queue = DispatchQueue(label: "pizza.sound", qos: .userInitiated)

    static func url(for s: PizzaSFX) -> URL? {
        GameFiles.url(s.rawValue, "caf", game: "Pizza") ?? GameFiles.url(s.rawValue, "wav", game: "Pizza")
    }

    private init() {
        _ = Sound.shared
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

// MARK: - Gesture State & Stage Chrome Components

final class PizzaHand {
    var lastAt = Date()
    var startAt = Date()
    var active = false
    var idleSince = Date()
    var dockStart = Date()
}

/// 3-stage pictorial breadcrumb in the top center (Dough -> Prep -> Oven/Feast).
private enum StagePill: Int, CaseIterable {
    case dough, prep, bakeFeast

    var targetStep: PizzaStep {
        switch self {
        case .dough: return .dough
        case .prep: return .prep
        case .bakeFeast: return .bake
        }
    }

    func matches(_ step: PizzaStep) -> Bool {
        switch self {
        case .dough: return step == .dough
        case .prep: return step == .prep
        case .bakeFeast: return step == .bake || step == .slice
        }
    }
}

private struct StagePillIcon: View, Equatable {
    let pill: StagePill
    let isSlice: Bool

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let scale = min(size.width, size.height) / 56
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: scale, y: scale)
            switch pill {
            case .dough:
                g.rotate(by: .degrees(-26))
                g.scaleBy(x: 0.22, y: 0.22)
                PizzaPainter.rollingPin(g, spin: 0)
            case .prep:
                let pie = Path(ellipseIn: CGRect(x: -20, y: -20, width: 40, height: 40))
                g.fill(pie, with: .color(Color(hex: 0xE8A050)))
                g.fill(Path(ellipseIn: CGRect(x: -15, y: -15, width: 30, height: 30)), with: .color(Color(hex: 0xDC3C26)))
                g.fill(Path(ellipseIn: CGRect(x: -12, y: -12, width: 24, height: 24)), with: .color(Color(hex: 0xFFE27A)))
                for (px, py) in [(CGFloat(-5), CGFloat(-4)), (CGFloat(5), CGFloat(3)), (CGFloat(-2), CGFloat(6))] {
                    g.fill(Path(ellipseIn: CGRect(x: px - 4, y: py - 4, width: 8, height: 8)), with: .color(Color(hex: 0xD23626)))
                }
            case .bakeFeast:
                if isSlice {
                    g.rotate(by: .degrees(30))
                    g.scaleBy(x: 0.28, y: 0.28)
                    g.translateBy(x: 0, y: -56)
                    PizzaPainter.cutter(g, spin: 0.2)
                } else {
                    var fl = Path()
                    fl.move(to: CGPoint(x: 0, y: -22))
                    fl.addCurve(to: CGPoint(x: 0, y: 20), control1: CGPoint(x: 23, y: -2), control2: CGPoint(x: 20, y: 20))
                    fl.addCurve(to: CGPoint(x: 0, y: -22), control1: CGPoint(x: -20, y: 20), control2: CGPoint(x: -16, y: -6))
                    g.fill(fl, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD24A), Color(hex: 0xFF6A2A)]),
                                                     startPoint: CGPoint(x: 0, y: -22), endPoint: CGPoint(x: 0, y: 20)))
                    g.fill(Path(ellipseIn: CGRect(x: -6, y: 2, width: 12, height: 16)), with: .color(Color(hex: 0xFFF2A8)))
                }
            }
        }
        .frame(width: 44, height: 44)
        .allowsHitTesting(false)
    }
}

private struct PizzaOvenNudgeRing: View {
    let sim: PizzaSim

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { tl in
            if sim.time - sim.ovenNudgeAt < 2.2 {
                let pulse = CGFloat(1.08 + 0.08 * sin(tl.date.timeIntervalSinceReferenceDate * 10))
                Circle()
                    .stroke(Color(hex: 0xFFA52C), lineWidth: 5)
                    .frame(width: 62, height: 62)
                    .scaleEffect(pulse)
                    .allowsHitTesting(false)
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

/// Right-side contextual action button: Next (dough), Slide-to-Oven Peel (prep), Pull-Out Peel + golden progress ring (bake), New Pizza (served).
private struct PizzaDynamicActionButton: View {
    let sim: PizzaSim
    let stage: PizzaStep
    let onAction: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { _ in
            PizzaActionButtonView(
                stage: stage,
                ready: sim.ready(stage),
                canPullEarly: sim.canPullFromOven,
                bakeProgress: sim.bake,
                served: sim.stars != nil,
                onAction: onAction
            )
        }
    }
}

private struct PizzaActionButtonView: View {
    let stage: PizzaStep
    let ready: Bool
    let canPullEarly: Bool
    let bakeProgress: Double
    let served: Bool
    let onAction: () -> Void

    @State private var bounceUp = false
    @State private var dragShift: CGFloat = 0
    @State private var pressingPrep = false

    var body: some View {
        if stage == .slice && !served {
            EmptyView()
        } else {
            let highlighted = ready || (stage == .bake && canPullEarly) || (stage == .slice && served)
            let fillColor: Color = {
                switch stage {
                case .dough: return ready ? Color(hex: 0x4EC978) : Color.white
                case .prep: return ready ? Color(hex: 0xFF8B42) : Color(hex: 0xFFF4E6)
                case .bake: return ready ? Color(hex: 0xFF9F2E) : (canPullEarly ? Color(hex: 0xFFF0D4) : Color.white)
                case .slice: return Theme.pink
                }
            }()

            let badge = ZStack {
                Circle().fill(fillColor)
                if stage == .bake {
                    Circle()
                        .stroke(Color(hex: 0xFFE3B3), lineWidth: 9)
                        .padding(6)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0.02, min(1, bakeProgress))))
                        .stroke(Color(hex: 0xFFA520), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(6)
                }
                iconContent
            }
            .frame(width: 118, height: 118)
            .overlay(Circle().stroke(.white, lineWidth: 6))
            .shadow(color: Theme.ink.opacity(highlighted ? 0.3 : 0.2), radius: highlighted ? 10 : 6, y: 5)

            Group {
                if stage == .prep {
                    // Unified tap OR slide-right gesture guarantees single fire with tactile squish
                    badge
                        .scaleEffect(pressingPrep ? 0.91 : 1)
                        .animation(.spring(response: 0.24, dampingFraction: 0.62), value: pressingPrep)
                        .contentShape(Circle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    pressingPrep = true
                                    dragShift = max(0, min(44, v.translation.width))
                                }
                                .onEnded { v in
                                    pressingPrep = false
                                    let slid = v.translation.width >= 30
                                    let tapped = hypot(v.translation.width, v.translation.height) < 36
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                                        dragShift = 0
                                    }
                                    if slid || tapped { onAction() }
                                }
                        )
                } else {
                    Button(action: onAction) {
                        badge
                    }
                    .buttonStyle(Squish())
                }
            }
            .offset(x: dragShift, y: highlighted && bounceUp ? -10 : 0)
            .onAppear { syncBounce(highlighted) }
            .onChange(of: highlighted) { isOn in syncBounce(isOn) }
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        switch stage {
        case .dough:
            Image(systemName: "arrow.right")
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(ready ? Color.white : Theme.pink)
        case .prep:
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2 + 2)
                g.scaleBy(x: 0.92, y: 0.92)
                PizzaPainter.peelIcon(g, flame: true)
            }
            .allowsHitTesting(false)
        case .bake:
            Canvas { ctx, size in
                var g = ctx
                g.translateBy(x: size.width / 2, y: size.height / 2 + 2)
                g.scaleBy(x: 0.85, y: 0.85)
                PizzaPainter.peelIcon(g, flame: false)
            }
            .allowsHitTesting(false)
        case .slice:
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 46, weight: .heavy))
                .foregroundStyle(.white)
        }
    }

    private func syncBounce(_ isOn: Bool) {
        if isOn {
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

private enum PizzaCueKind: Equatable {
    case rollDough, paintSauce, stokeFire, pullBaked, swipeCut, serveSlice
}

private struct PizzaDynamicCueOverlay: View {
    let sim: PizzaSim
    let hand: PizzaHand

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.22)) { _ in
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
            if (sim.ball || sim.rollProgress < 0.72) && sim.tossStart == nil && idle > 1.8 {
                return .rollDough
            }
        case .prep:
            if sim.prepTab == .sauces && sim.sauceCoverage < 0.15 && idle > 2.6 {
                return .paintSauce
            }
        case .bake:
            if sim.bake >= 0.98 && idle > 0.9 { return .pullBaked }
            if sim.bake < 0.92 && idle > 1.8 { return .stokeFire }
        case .slice:
            if sim.cuts.isEmpty && (idle > 1.4 || sim.time - sim.cutterNudgeAt < 2.2) {
                return .swipeCut
            }
            if !sim.cuts.isEmpty && sim.stars == nil && sim.lifted == nil && idle > 2.2 {
                return .serveSlice
            }
        }
        return nil
    }
}

/// Zero-text pictorial idle cues.
private struct PizzaPictorialCue: View {
    let kind: PizzaCueKind
    @State private var animate = false

    var body: some View {
        Group {
            switch kind {
            case .rollDough:
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 6, y: 3)
                    .offset(x: animate ? 62 : -62, y: animate ? -22 : 22)
                    .position(PGeo.center)
            case .paintSauce:
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.ink.opacity(0.35), radius: 6, y: 3)
                    .offset(x: animate ? 72 : -72, y: animate ? -36 : 36)
                    .position(PGeo.center)
            case .stokeFire:
                ZStack {
                    Circle()
                        .stroke(Theme.lemon, lineWidth: 7)
                        .frame(width: 106, height: 106)
                        .scaleEffect(animate ? 1.28 : 0.86)
                        .opacity(animate ? 0.12 : 0.88)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFE378))
                        .shadow(color: Color(hex: 0xFF6A2A).opacity(0.6), radius: 6)
                        .scaleEffect(animate ? 1.15 : 0.92)
                }
                .position(x: 315, y: 308)
            case .pullBaked:
                ZStack {
                    Circle()
                        .stroke(Theme.lemon, lineWidth: 7)
                        .frame(width: 148, height: 148)
                        .scaleEffect(animate ? 1.26 : 0.88)
                        .opacity(animate ? 0.14 : 0.9)
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.ink.opacity(0.4), radius: 6, y: 3)
                }
                .position(PGeo.ovenCenter)
            case .swipeCut:
                ZStack {
                    Capsule()
                        .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [12, 12]))
                        .frame(width: 260, height: 2)
                        .rotationEffect(.degrees(-25))
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.ink.opacity(0.38), radius: 6, y: 3)
                        .offset(x: animate ? 96 : -96, y: animate ? -46 : 46)
                }
                .position(PGeo.center)
            case .serveSlice:
                HStack(spacing: -6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(.white.opacity(0.92))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(Theme.lemon)
                }
                .shadow(color: Theme.ink.opacity(0.35), radius: 5, y: 3)
                .offset(x: animate ? 34 : -14, y: animate ? -20 : 8)
                .opacity(animate ? 0.25 : 0.95)
                .position(x: PGeo.center.x + 150, y: PGeo.center.y - 70)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            animate = false
            let bounce = kind == .rollDough || kind == .paintSauce || kind == .stokeFire
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: bounce)) {
                animate = true
            }
        }
        .id(kind)
    }
}

// MARK: - Main Screen

struct PizzaView: View {
    let exit: () -> Void

    @State private var sim = PizzaSim()
    @State private var grids = PizzaGrids()
    @State private var hand = PizzaHand()

    @State private var uiStage: PizzaStep = .dough
    @State private var uiShape: CrustShape = .round
    @State private var uiPrepTab: PrepTab = .sauces
    @State private var uiSauce: SauceKind = .tomato
    @State private var uiCheese: CheeseKind = .mozzarella
    @State private var uiTopping: ToppingKind = .pepperoni
    @State private var uiSliceMode: SliceMode = .cut
    @State private var uiHasCuts = false
    @State private var uiWants: [ToppingKind] = []
    @State private var draggingTopping: ToppingKind?
    @State private var showStickers = false
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            let map = GMap(size: geo.size)
            ZStack {
                Canvas(opaque: true) { ctx, _ in
                    PizzaPainter.drawCounter(ctx, map: map)
                }
                .allowsHitTesting(false)

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
        .defersSystemGestures(on: .bottom)
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
        sim.onStateChange = {
            DispatchQueue.main.async { syncUIState() }
        }
        applyLaunchArguments()
        syncUIState()
    }

    private func syncUIState() {
        uiStage = sim.stage
        uiShape = sim.crustShape
        uiPrepTab = sim.prepTab
        uiSauce = sim.selectedSauce
        uiCheese = sim.selectedCheese
        uiTopping = sim.selectedTopping
        uiSliceMode = sim.sliceMode
        uiHasCuts = !sim.cuts.isEmpty
        uiWants = sim.order.wants
    }

    // MARK: Direct Canvas Hand Gesture

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
                    syncUIState()
                } else {
                    let dt = CGFloat(max(1.0 / 120, now.timeIntervalSince(hand.lastAt)))
                    hand.lastAt = now
                    sim.handMoved(p, dt: dt)
                }
            }
            .onEnded { v in
                let p = map.design(v.location)
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                let tap = moved < 16 && Date().timeIntervalSince(hand.startAt) < 0.45
                sim.handEnded(p, tap: tap)
                hand.active = false
                hand.idleSince = Date()
                syncUIState()
            }
    }

    // MARK: Controls Overlay

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
                    stageBreadcrumb(uiStage)
                },
                trailing: {
                    PizzaDynamicHeartsBadge(sim: sim)
                }
            )

            // Lifted Bottom Interactive Dock (y = 740, clear of Home Indicator)
            bottomDock(map)
                .position(x: 512, y: PGeo.dockY)

            // Right Contextual Action Button (Next / Slide-to-Oven Peel / Pull-Out Peel / New Pizza)
            PizzaDynamicActionButton(sim: sim, stage: uiStage) {
                Sound.shared.tap()
                switch uiStage {
                case .dough:
                    Sound.shared.play(.pop, volume: 0.6)
                    sim.go(.prep)
                case .prep:
                    Sound.shared.play(.pop, volume: 0.6)
                    sim.go(.bake)
                case .bake:
                    sim.pullFromOven()
                case .slice:
                    sim.newPizza()
                }
                syncUIState()
            }
            .position(PGeo.actionButton)

            PizzaDynamicCueOverlay(sim: sim, hand: hand)
            StickerToast(game: PizzaSim.gameID, target: GameChromeLayout.stickerTarget)
        }
        .frame(width: 1024, height: 834)
    }

    /// Compact 3-stage pictorial pill bar (Dough • Prep • Oven/Feast).
    private func stageBreadcrumb(_ current: PizzaStep) -> some View {
        GameTrayCard(cornerRadius: 28, paddingH: 8, paddingV: 5) {
            HStack(spacing: 8) {
                ForEach(StagePill.allCases, id: \.self) { pill in
                    let active = pill.matches(current)
                    Button {
                        Sound.shared.tap()
                        Sound.shared.play(.pop, volume: 0.55)
                        if pill == .bakeFeast && current == .bake && sim.canPullFromOven {
                            sim.go(.slice)
                        } else if !active {
                            sim.go(pill.targetStep)
                        }
                        syncUIState()
                    } label: {
                        StagePillIcon(pill: pill, isSlice: current == .slice)
                            .equatable()
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(.white))
                            .overlay(Circle().stroke(active ? Theme.pink : Theme.blush.opacity(0.65), lineWidth: active ? 4.5 : 2.5))
                            .overlay {
                                if pill == .bakeFeast {
                                    PizzaOvenNudgeRing(sim: sim)
                                }
                            }
                            .scaleEffect(active ? 1.07 : 0.94)
                            .shadow(color: Theme.ink.opacity(0.14), radius: 4, y: 3)
                            .animation(.spring(response: 0.32, dampingFraction: 0.65), value: current)
                    }
                    .buttonStyle(Squish())
                }
            }
        }
    }

    // MARK: Lifted Bottom Dock (y = 740)

    @ViewBuilder
    private func bottomDock(_ map: GMap) -> some View {
        switch uiStage {
        case .dough:
            doughDock()
        case .prep:
            prepDock(map)
        case .bake:
            bakeDock()
        case .slice:
            sliceDock()
        }
    }

    private func doughDock() -> some View {
        GameTrayCard(cornerRadius: 30, paddingH: 14, paddingV: 10) {
            HStack(spacing: 12) {
                ForEach(CrustShape.allCases, id: \.self) { shape in
                    Button {
                        Sound.shared.tap()
                        sim.setCrustShape(shape)
                        syncUIState()
                    } label: {
                        GameDockTile(size: 76, selected: uiShape == shape, tint: .white, cornerRadius: 22) {
                            Canvas { ctx, size in
                                var g = ctx
                                g.translateBy(x: size.width / 2, y: size.height / 2)
                                PizzaPainter.crustShapeIcon(g, shape: shape, radius: 26)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(Squish())
                }

                Capsule()
                    .fill(Theme.blush)
                    .frame(width: 3, height: 54)

                // Optional celebratory air-toss button
                Button {
                    Sound.shared.tap()
                    sim.triggerToss()
                    syncUIState()
                } label: {
                    GameDockTile(size: 76, selected: false, tint: Color(hex: 0xFFF5D8), cornerRadius: 22) {
                        ZStack {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(Theme.pink)
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: 0xF5A822))
                                .offset(x: 20, y: -20)
                        }
                    }
                }
                .buttonStyle(Squish())
            }
        }
    }

    private func prepDock(_ map: GMap) -> some View {
        GameTrayCard(cornerRadius: 30, paddingH: 12, paddingV: 9) {
            HStack(spacing: 10) {
                // 3 snappy pictorial tabs: Sauces • Cheeses • Toppings
                HStack(spacing: 6) {
                    ForEach(PrepTab.allCases, id: \.self) { tab in
                        let selected = uiPrepTab == tab
                        Button {
                            Sound.shared.tap()
                            Sound.shared.play(.pop, volume: 0.5)
                            sim.prepTab = tab
                            syncUIState()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(selected ? Theme.pink : Color.white)
                                prepTabIcon(tab)
                            }
                            .frame(width: 58, height: 72)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(selected ? Color.white : Theme.blush, lineWidth: selected ? 3.5 : 2.5)
                            )
                            .shadow(color: Theme.ink.opacity(selected ? 0.2 : 0.1), radius: 4, y: 2)
                            .scaleEffect(selected ? 1.05 : 0.96)
                            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: uiPrepTab)
                        }
                        .buttonStyle(Squish())
                    }
                }

                Capsule()
                    .fill(Theme.blush)
                    .frame(width: 3, height: 56)

                switch uiPrepTab {
                case .sauces:
                    saucesStrip()
                case .cheeses:
                    cheesesStrip()
                case .toppings:
                    toppingsStrip(map)
                }
            }
        }
    }

    private func prepTabIcon(_ tab: PrepTab) -> some View {
        Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            switch tab {
            case .sauces:
                g.scaleBy(x: 0.68, y: 0.68)
                g.translateBy(x: 0, y: 4)
                PizzaPainter.sauceBowl(g, kind: uiSauce)
            case .cheeses:
                g.scaleBy(x: 0.38, y: 0.38)
                PizzaPainter.cheeseBowl(g, kind: uiCheese)
            case .toppings:
                g.scaleBy(x: 0.85, y: 0.85)
                PizzaPainter.topping(g, uiTopping, seed: 3, bake: 0)
            }
        }
        .frame(width: 48, height: 56)
        .allowsHitTesting(false)
    }

    private func saucesStrip() -> some View {
        HStack(spacing: 12) {
            ForEach(SauceKind.allCases, id: \.self) { kind in
                Button {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.5)
                    sim.selectSauce(kind)
                    syncUIState()
                } label: {
                    GameDockTile(size: 74, selected: uiSauce == kind, tint: .white, cornerRadius: 22) {
                        Canvas { ctx, size in
                            var g = ctx
                            g.translateBy(x: size.width / 2, y: size.height / 2 + 4)
                            g.scaleBy(x: 0.92, y: 0.92)
                            PizzaPainter.sauceBowl(g, kind: kind)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .buttonStyle(Squish())
            }

            // 1-tap Swirl-Fill mini button
            Button {
                Sound.shared.tap()
                sim.swirlFillSauce()
                syncUIState()
            } label: {
                GameDockTile(size: 74, selected: false, tint: Color(hex: 0xFFF3D6), cornerRadius: 22) {
                    Canvas { ctx, size in
                        var g = ctx
                        g.translateBy(x: size.width / 2, y: size.height / 2)
                        let col = PizzaPainter.sauceColors(for: uiSauce)
                        var spiral = Path()
                        for step in 0...44 {
                            let u = CGFloat(step) / 44
                            let a = u * 3.8 * .pi
                            let rad = 24 * (1 - u * 0.86)
                            let pt = CGPoint(x: cos(a) * rad, y: sin(a) * rad)
                            if step == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
                        }
                        g.stroke(spiral, with: .color(col.deep), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        g.stroke(spiral, with: .color(col.light), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                        StorybookArt.sparkle(g, at: CGPoint(x: 20, y: -20), radius: 8, color: Color(hex: 0xFFA822))
                    }
                    .allowsHitTesting(false)
                }
            }
            .buttonStyle(Squish())
        }
    }

    private func cheesesStrip() -> some View {
        HStack(spacing: 14) {
            ForEach(CheeseKind.allCases, id: \.self) { kind in
                Button {
                    Sound.shared.tap()
                    Sound.shared.play(.pop, volume: 0.5)
                    sim.selectCheese(kind)
                    syncUIState()
                } label: {
                    GameDockTile(size: 74, selected: uiCheese == kind, tint: .white, cornerRadius: 22) {
                        Canvas { ctx, size in
                            var g = ctx
                            g.translateBy(x: size.width / 2, y: size.height / 2)
                            g.scaleBy(x: 0.48, y: 0.48)
                            PizzaPainter.cheeseBowl(g, kind: kind)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .buttonStyle(Squish())
            }

            // 1-tap Cheese Sprinkle Burst button
            Button {
                Sound.shared.tap()
                sim.sprinkleBurstCheese()
                syncUIState()
            } label: {
                GameDockTile(size: 74, selected: false, tint: Color(hex: 0xFFF5D2), cornerRadius: 22) {
                    ZStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color(hex: 0xF0A41C))
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Theme.pink)
                            .offset(y: 22)
                    }
                }
            }
            .buttonStyle(Squish())
        }
    }

    private func toppingsStrip(_ map: GMap) -> some View {
        HStack(spacing: 6) {
            ForEach(ToppingKind.allCases, id: \.self) { kind in
                let isSelected = uiTopping == kind
                let wanted = uiWants.contains(kind)
                GameDockTile(size: 66, selected: isSelected, tint: .white, cornerRadius: 19) {
                    Canvas { ctx, size in
                        var g = ctx
                        g.translateBy(x: size.width / 2, y: size.height / 2)
                        for (i, o) in [CGPoint(x: -10, y: 8), CGPoint(x: 10, y: 6), CGPoint(x: 0, y: -7)].enumerated() {
                            var tg = g
                            tg.translateBy(x: o.x, y: o.y)
                            tg.rotate(by: .degrees(Double(i) * 48))
                            tg.scaleBy(x: 0.62, y: 0.62)
                            PizzaPainter.topping(tg, kind, seed: i * 13 + 2, bake: 0)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    if wanted {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.pink)
                            .padding(4)
                            .background(Circle().fill(.white))
                            .overlay(Circle().stroke(Theme.blush, lineWidth: 2))
                            .offset(x: 6, y: -6)
                            .allowsHitTesting(false)
                    }
                }
                .gesture(toppingTileGesture(kind, map))
            }
        }
    }

    /// Tap selects `kind` (never auto-drops!); dragging carries a live topping straight onto the pizza.
    private func toppingTileGesture(_ kind: ToppingKind, _ map: GMap) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("pizza"))
            .onChanged { v in
                let p = map.design(v.location)
                hand.idleSince = Date()
                if draggingTopping == nil {
                    draggingTopping = kind
                    hand.dockStart = Date()
                    Sound.shared.tap()
                    sim.selectTopping(kind)
                    syncUIState()
                }
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                if moved >= 14 {
                    if sim.tool == nil {
                        sim.pickUp(.topping(kind), finger: p)
                    }
                    sim.carry(p)
                }
            }
            .onEnded { v in
                let moved = hypot(v.location.x - v.startLocation.x, v.location.y - v.startLocation.y) / map.s
                if moved >= 14 && sim.tool != nil {
                    sim.release()
                } else {
                    Sound.shared.play(.pop, volume: 0.5)
                    sim.tool = nil
                    sim.selectTopping(kind)
                }
                draggingTopping = nil
                syncUIState()
            }
    }

    private func bakeDock() -> some View {
        GameTrayCard(cornerRadius: 30, paddingH: 14, paddingV: 10) {
            Button {
                Sound.shared.tap()
                sim.stoke()
            } label: {
                GameDockTile(size: 76, selected: false, pulsing: true, tint: Color(hex: 0xFFF0D4), cornerRadius: 22) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFF6B24))
                }
            }
            .buttonStyle(Squish())
        }
    }

    private func sliceDock() -> some View {
        GameTrayCard(cornerRadius: 30, paddingH: 14, paddingV: 10) {
            HStack(spacing: 14) {
                // 1-tap Quick-Slice Pizza Wheel (honors pizza/starCutter treasure!)
                Button {
                    Sound.shared.tap()
                    sim.sliceMode = .cut
                    sim.quickSlice()
                    syncUIState()
                } label: {
                    GameDockTile(size: 78, selected: uiSliceMode == .cut, pulsing: !uiHasCuts, tint: .white, cornerRadius: 22) {
                        Canvas { ctx, size in
                            var g = ctx
                            g.translateBy(x: size.width / 2, y: size.height / 2)
                            g.rotate(by: .degrees(34))
                            g.scaleBy(x: 0.34, y: 0.34)
                            g.translateBy(x: 0, y: -62)
                            PizzaPainter.cutter(g, spin: 0.25)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .buttonStyle(Squish())

                // Pull-a-Slice Serve Mode button (highlights once pizza has at least 1 cut!)
                if uiHasCuts {
                    Button {
                        Sound.shared.tap()
                        Sound.shared.play(.pop, volume: 0.5)
                        sim.sliceMode = .serve
                        syncUIState()
                    } label: {
                        GameDockTile(size: 78, selected: uiSliceMode == .serve, pulsing: uiSliceMode == .cut, tint: Color(hex: 0xFFF4DC), cornerRadius: 22) {
                            Canvas { ctx, size in
                                var g = ctx
                                g.translateBy(x: size.width / 2, y: size.height / 2 + 4)
                                var slice = Path()
                                slice.move(to: CGPoint(x: 0, y: 20))
                                slice.addLine(to: CGPoint(x: -20, y: -14))
                                slice.addQuadCurve(to: CGPoint(x: 20, y: -14), control: CGPoint(x: 0, y: -23))
                                slice.closeSubpath()
                                StorybookArt.fillAndStroke(g, slice, fill: Color(hex: 0xFFE06E), stroke: StorybookArt.outline(for: 0xDE943B), width: 2.6)
                                var crust = Path()
                                crust.move(to: CGPoint(x: -21, y: -14))
                                crust.addQuadCurve(to: CGPoint(x: 21, y: -14), control: CGPoint(x: 0, y: -23))
                                g.stroke(crust, with: .color(Color(hex: 0xE69A48)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
                                g.fill(Path(ellipseIn: CGRect(x: -6, y: -9, width: 9, height: 9)), with: .color(Color(hex: 0xD83A28)))
                                g.fill(Path(ellipseIn: CGRect(x: 3, y: -2, width: 8, height: 8)), with: .color(Color(hex: 0xD83A28)))
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .buttonStyle(Squish())
                }
            }
        }
    }

    // MARK: Screenshot Hooks

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-pizzaDemo"), i + 1 < args.count {
            sim.demoSetup(args[i + 1])
        }
    }
}
