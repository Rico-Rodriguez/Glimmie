import SwiftUI

// MARK: - Pour and bake
//
// Press and hold the bowl: it tips over the pan and a thick ribbon of batter runs out, folding onto itself
// in the pan before it levels out. Let go and the stream thins and breaks. In the oven the batter rises
// into a dome, bubbles, browns and cracks a little on top, with the coils glowing and heat shimmering.

/// Press-and-hold pouring: how long batter has run, and how far the bowl is tipped.
final class PourFlow {
    /// Seconds of pouring that fill the pan.
    static let fullTime = 2.4
    /// The bowl tips this long before the batter starts to run.
    static let delay = 0.2

    var acc: Double = 0
    var pressAt: Date?
    var releasedAt: Date?
    var flows: [(start: Date, end: Date?)] = []
    private var tiltFrom: CGFloat = 0
    private var tiltTo: CGFloat = 0
    private var tiltAt = Date.distantPast

    func press(_ now: Date) {
        guard pressAt == nil else { return }
        tiltFrom = tilt(now)
        tiltTo = 1
        tiltAt = now
        pressAt = now
        releasedAt = nil
        flows.append((now.addingTimeInterval(PourFlow.delay), nil))
    }

    func release(_ now: Date) {
        guard let p = pressAt else { return }
        let fs = p.addingTimeInterval(PourFlow.delay)
        acc += max(0, now.timeIntervalSince(fs))
        if let last = flows.indices.last { flows[last].end = max(now, fs) }
        pressAt = nil
        releasedAt = now
        tiltFrom = tilt(now)
        tiltTo = 0
        tiltAt = now
    }

    func seconds(_ now: Date) -> Double {
        var s = acc
        if let p = pressAt { s += max(0, now.timeIntervalSince(p) - PourFlow.delay) }
        return s
    }

    func level(_ now: Date) -> CGFloat { CGFloat(min(1, seconds(now) / PourFlow.fullTime)) }

    func tilt(_ now: Date) -> CGFloat {
        let k = fxEase(now.timeIntervalSince(tiltAt) / 0.28)
        return tiltFrom + (tiltTo - tiltFrom) * k
    }

    func flowing(at t: Date) -> Bool {
        flows.contains { t >= $0.start && t <= ($0.end ?? .distantFuture) }
    }

    /// Where the falling batter lands, relative to the pan's middle: it wanders as the bowl wobbles.
    static func wander(_ t: Date) -> CGFloat {
        let s = t.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
        return CGFloat(sin(s * 2.3)) * 46 + CGFloat(sin(s * 5.9)) * 14
    }
}

struct BakeStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool

    private enum Phase { case choose, pour, ready, baking, done }
    @State private var phase: Phase = .choose
    @State private var flow = PourFlow()
    @State private var pourToken = 0
    @State private var everPressed = false
    @State private var bowlInAt = Date.distantPast
    @State private var bowlOutAt: Date?
    @State private var panPos = CGPoint(x: 800, y: 650)
    @State private var panScale: CGFloat = 1
    @State private var panHidden = false
    @State private var bakeAt: Date?
    @State private var doneAt: Date?
    @State private var burst = 0
    @State private var nudge = false
    @State private var frozenAt: Date?

    static let bakeTime = 4.6
    private let ovenC = CGPoint(x: 320, y: 500)
    private let windowC = CGPoint(x: 320, y: 540)
    private let panSpot = CGPoint(x: 800, y: 650)
    /// The bowl's pouring lip (design points); the bowl tips around it.
    private let lip = CGPoint(x: 790, y: 384)

    private var animating: Bool { phase == .pour || phase == .baking || phase == .done }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !animating)) { tl in
            scene(frozenAt ?? tl.date)
        }
        .onAppear(perform: demo)
    }

    @ViewBuilder private func scene(_ now: Date) -> some View {
        let rise = riseAt(now)
        let brown = brownAt(now)
        ZStack {
            Sprite("oven", box: Box.oven)
                .frame(width: 480, height: 460)
                .position(ovenC)
            if !panHidden {
                PanView(treat: treat, fill: flow.level(now), rise: rise, bake: brown, time: now.timeIntervalSince(bowlInAt))
                    .frame(width: 300, height: 190)
                    .scaleEffect(panScale)
                    .position(panPos)
            }
            if phase == .baking {
                OvenHeat(t: now.timeIntervalSince(bakeAt ?? now))
                    .frame(width: 320, height: 200)
                    .blendMode(.screen)
                    .position(windowC)
                    .allowsHitTesting(false)
            }
            Sprite("oven_glass", box: Box.oven)
                .frame(width: 480, height: 460)
                .position(ovenC)
                .allowsHitTesting(false)
            Sprite("dial", box: Box.oven)
                .frame(width: 480, height: 460)
                .rotationEffect(.degrees(dialAt(now)), anchor: UnitPoint(x: 240.0 / 480, y: 64.0 / 460))
                .position(ovenC)
                .allowsHitTesting(false)
            if phase == .ready {
                Circle().stroke(Color.white, lineWidth: 8)
                    .frame(width: 90, height: 90)
                    .scaleEffect(nudge ? 1.25 : 0.9)
                    .opacity(nudge ? 0.2 : 0.95)
                    .position(x: ovenC.x, y: ovenC.y - 230 + 64)
                    .allowsHitTesting(false)
                    .onAppear { withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) { nudge = true } }
            }
            Color.clear
                .frame(width: 480, height: 460)
                .contentShape(Rectangle())
                .onTapGesture { if phase == .ready { bake() } }
                .position(ovenC)

            switch phase {
            case .choose: chooser
            case .pour: pourScene(now)
            default: EmptyView()
            }

            if phase == .done {
                doneView(now)
            }
        }
    }

    // MARK: Choosing the pan

    @ViewBuilder private var chooser: some View {
        if treat.kind == .cake {
            ForEach(1...3, id: \.self) { n in
                PickPlate(selected: false, size: 170, tap: { chooseTiers(n) }) {
                    TreatView(treat: { var t = Treat(kind: .cake); t.flavor = treat.flavor; t.tiers = n; return t }(), plate: false)
                        .padding(16)
                }
                .position(x: n == 2 ? 900 : 720, y: CGFloat(170 + n * 160) - (n == 2 ? 80 : 0))
            }
        } else {
            ForEach(0..<BakeryPalette.liners.count, id: \.self) { i in
                PickPlate(selected: false, size: 96, tap: { chooseLiner(i) }) {
                    Sprite("liner", color: BakeryPalette.liners[i], box: CGRect(x: 160, y: 404, width: 280, height: 140))
                        .padding(10)
                }
                .position(gridSpotBake(i))
            }
        }
    }

    private func gridSpotBake(_ i: Int) -> CGPoint {
        CGPoint(x: 690 + CGFloat(i % 3) * 118, y: 230 + CGFloat(i / 3) * 118)
    }

    private func chooseTiers(_ n: Int) {
        Sound.shared.play(.pop)
        Sound.shared.tap()
        treat.tiers = n
        startPourPhase()
    }

    private func chooseLiner(_ i: Int) {
        Sound.shared.play(.pop)
        Sound.shared.tap()
        treat.liner = i
        startPourPhase()
    }

    private func startPourPhase() {
        bowlInAt = Date()
        Sound.shared.play(.whoosh, volume: 0.5)
        withAnimation(.spring(response: 0.4)) { phase = .pour }
    }

    // MARK: Pouring

    private var batterColor: RGB { TreatPainter.flavor(treat.flavor).color.mix(RGB(1, 1, 1), 0.1) }

    /// The batter surface in the pan (design points) at a fill level.
    private func panSurface(_ level: CGFloat) -> (c: CGPoint, rx: CGFloat, ry: CGFloat) {
        let spread = min(1, max(0.12, level / 0.45))
        if treat.kind == .cake {
            return (CGPoint(x: panPos.x, y: panPos.y - 95 + PanView.cakeSurfaceY(level)), 128 * spread, 26 * spread)
        }
        return (CGPoint(x: panPos.x, y: panPos.y - 95 + PanView.linerSurfaceY(level)), 118 * spread, 12 * spread)
    }

    private func pourScene(_ now: Date) -> some View {
        ZStack {
            Canvas { ctx, _ in drawPour(ctx, now) }
                .frame(width: 1024, height: 834)
                .position(x: 512, y: 417)
                .allowsHitTesting(false)
            if !everPressed {
                Circle().stroke(Color.white, lineWidth: 8)
                    .frame(width: 170, height: 170)
                    .scaleEffect(nudge ? 1.2 : 0.85)
                    .opacity(nudge ? 0.15 : 0.9)
                    .position(x: 660, y: 400)
                    .allowsHitTesting(false)
                    .onAppear { withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) { nudge = true } }
            }
            Color.clear
                .frame(width: 440, height: 560)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in startPour() }
                    .onEnded { _ in endPour() })
                .position(x: 760, y: 470)
        }
    }

    private func drawPour(_ ctx: GraphicsContext, _ now: Date) {
        let art = BakeryArt.shared
        let tilt = flow.tilt(now)
        let level = flow.level(now)
        let inK = fxEase(now.timeIntervalSince(bowlInAt) / 0.5)
        var off = CGSize(width: (1 - inK) * 420, height: 0)
        var alpha = 1.0
        if let o = bowlOutAt {
            let k = fxEase(now.timeIntervalSince(o) / 0.45)
            off.width += k * 420
            off.height -= k * 140
            alpha = Double(1 - k)
        }
        let surf = panSurface(level)
        let col = batterColor

        // ribbons of batter folding onto the surface, slowly leveling out
        if level > 0 {
            var fc = ctx
            fc.clip(to: Path(ellipseIn: CGRect(x: surf.c.x - surf.rx, y: surf.c.y - surf.ry, width: surf.rx * 2, height: surf.ry * 2)))
            let spreadK = surf.rx / (treat.kind == .cake ? 128 : 118)
            let steps = 40
            var prev: CGPoint?
            for j in 0...steps {
                let tau = now.addingTimeInterval(-1.6 + 1.6 * Double(j) / Double(steps))
                guard flow.flowing(at: tau.addingTimeInterval(-0.25)) else { prev = nil; continue }
                let x = surf.c.x + PourFlow.wander(tau) * spreadK * (treat.kind == .cake ? 1 : 0.7)
                let y = surf.c.y + CGFloat(sin(tau.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000) * 3.1)) * surf.ry * 0.35
                let p = CGPoint(x: x, y: y)
                if let q = prev {
                    let fade = Double(j) / Double(steps)
                    var seg = Path()
                    seg.move(to: q)
                    seg.addLine(to: p)
                    var s = fc
                    s.opacity = 0.55 * fade
                    s.stroke(seg.applying(CGAffineTransform(translationX: 0, y: 3)), with: .color(Shades.shade(col).color),
                             style: StrokeStyle(lineWidth: 17, lineCap: .round))
                    s.opacity = fade
                    s.stroke(seg, with: .color(col.color), style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    s.opacity = 0.6 * fade
                    s.stroke(seg.applying(CGAffineTransform(translationX: -1, y: -3)), with: .color(Shades.light(col).color),
                             style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                prev = p
            }
        }

        // the stream: thick and slow, it narrows as it falls and breaks off when the pour stops
        let mouth = CGPoint(x: lip.x + off.width + 4, y: lip.y + off.height + 4)
        if let fs = flow.flows.last?.start, now > fs {
            var stopped: Double?
            if let e = flow.flows.last?.end { stopped = now.timeIntervalSince(e) }
            let g: CGFloat = 900
            let v0: CGFloat = 20
            let d = max(1, surf.c.y - mouth.y)
            let tFall = (-v0 + sqrt(v0 * v0 + 2 * g * d)) / g
            let target = surf.c.x + PourFlow.wander(now) * (treat.kind == .cake ? 1 : 0.7)
            let vx = (target - mouth.x) / max(0.1, tFall)
            if (stopped ?? 0) < 1.2,
               let s = LiquidStream(mouth: mouth, floorY: surf.c.y, vx: vx, width: 26, v0: v0, age: now.timeIntervalSince(fs),
                                    stopped: stopped, phase: now.timeIntervalSince(bowlInAt) * 0.5, gravity: g, wobble: 0.8) {
                s.draw(in: ctx, color: col)
                if s.reachesFloor {
                    // the little heap where it lands
                    let lp = s.land
                    let heap = Path(ellipseIn: CGRect(x: lp.x - 20, y: lp.y - 9, width: 40, height: 15))
                    ctx.fill(heap, with: .color(col.color))
                    var o = ctx
                    o.opacity = 0.5
                    o.stroke(heap, with: .color(Shades.outline(col).color), lineWidth: 2)
                }
            }
        }

        // the bowl, tipping around its lip
        var b = ctx
        b.opacity = alpha
        b.translateBy(x: lip.x + off.width, y: lip.y + off.height)
        b.rotate(by: .degrees(Double(52 * tilt)))
        b.scaleBy(x: 0.75, y: 0.75)
        b.translateBy(x: -372, y: -112)
        art.draw("bowl_back", in: b)
        let left = max(0.15, 1 - 0.8 * level)
        var bt = b
        bt.translateBy(x: 200 + 90 * tilt * (1 - left * 0.5), y: 120)
        bt.scaleBy(x: left, y: left)
        bt.translateBy(x: -200, y: -120)
        art.draw("batter", col, in: bt)
        if tilt > 0.4 {
            // batter sliding over the lip
            var tongue = Path()
            tongue.move(to: CGPoint(x: 300, y: 112))
            tongue.addQuadCurve(to: CGPoint(x: 376, y: 116), control: CGPoint(x: 350, y: 96))
            tongue.addQuadCurve(to: CGPoint(x: 300, y: 128), control: CGPoint(x: 350, y: 132))
            tongue.closeSubpath()
            var tg = b
            tg.opacity = alpha * Double(min(1, (tilt - 0.4) / 0.4))
            tg.fill(tongue, with: .color(col.color))
        }
        art.draw("bowl_front", in: b)
    }

    private func startPour() {
        guard phase == .pour, bowlOutAt == nil, flow.pressAt == nil, flow.level(Date()) < 1 else { return }
        let now = Date()
        flow.press(now)
        everPressed = true
        pourToken += 1
        let token = pourToken
        Sound.shared.tap()
        BakerySound.shared.play(.batter)
        loopSound(token)
        let remaining = (1 - Double(flow.level(now))) * PourFlow.fullTime + PourFlow.delay
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
            guard token == pourToken, flow.pressAt != nil else { return }
            stopFlow()
        }
    }

    private func endPour() {
        guard let p = flow.pressAt else { return }
        let token = pourToken
        // a quick tap still pours a good glug
        let wait = p.addingTimeInterval(0.8).timeIntervalSinceNow
        if wait > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { if token == pourToken { stopFlow() } }
        } else {
            stopFlow()
        }
    }

    private func stopFlow() {
        guard flow.pressAt != nil else { return }
        let now = Date()
        flow.release(now)
        pourToken += 1
        BakerySound.shared.play(.plop, volume: 0.6)
        if flow.level(now) >= 0.999 { poured() }
    }

    private func loopSound(_ token: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            guard token == pourToken, flow.pressAt != nil else { return }
            BakerySound.shared.play(.batter, volume: 0.8)
            loopSound(token)
        }
    }

    private func poured() {
        guard bowlOutAt == nil else { return }
        Sound.shared.play(.sparkle, volume: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            bowlOutAt = Date()
            Sound.shared.play(.whoosh, volume: 0.6)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.35)) {
                panPos = CGPoint(x: windowC.x, y: windowC.y + 10)
                panScale = 0.85
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.spring()) { phase = .ready }
            }
        }
    }

    // MARK: Baking

    private func riseAt(_ now: Date) -> CGFloat {
        guard let b = bakeAt else { return phase == .done ? 1 : 0 }
        let x = now.timeIntervalSince(b) / BakeStepView.bakeTime
        return fxEase((x - 0.06) / 0.78)
    }

    private func brownAt(_ now: Date) -> CGFloat {
        guard let b = bakeAt else { return phase == .done ? 1 : 0 }
        let x = now.timeIntervalSince(b) / BakeStepView.bakeTime
        return fxEase((x - 0.35) / 0.6)
    }

    private func dialAt(_ now: Date) -> Double {
        guard let b = bakeAt else { return 0 }
        return 360 * fxClamp(now.timeIntervalSince(b) / BakeStepView.bakeTime)
    }

    private func bake() {
        guard phase == .ready else { return }
        bakeAt = Date()
        phase = .baking
        Sound.shared.tap()
        Sound.shared.play(.boing, volume: 0.5)
        BakerySound.shared.play(.oven, volume: 0.8)
        let ticks = Int(BakeStepView.bakeTime / 0.3)
        for k in 0..<ticks {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.3) { BakerySound.shared.play(.tick, volume: 0.6) }
        }
        for t in [1.3, 2.8] {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                BakerySound.shared.play(.oven, volume: 0.6)
                BakerySound.shared.play(.sizzle, volume: 0.7)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + BakeStepView.bakeTime + 0.2) {
            Sound.shared.play(.ding)
            BakerySound.shared.play(.magic, volume: 0.8)
            Sound.shared.tap()
            withAnimation(.easeOut(duration: 0.3)) { panHidden = true }
            burst += 1
            doneAt = Date()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { phase = .done; done = true }
        }
    }

    private func doneView(_ now: Date) -> some View {
        let age = now.timeIntervalSince(doneAt ?? now)
        let top = TreatPainter.topY(treat) * 430 / 600 - 215
        return ZStack {
            TreatView(treat: treat)
                .frame(width: 430, height: 430)
            SteamWisps(t: age)
                .frame(width: 280, height: 240)
                .offset(y: top - 110)
                .allowsHitTesting(false)
            SparkleBurst(count: 16, radius: 240).id(burst)
        }
        .position(x: 790, y: 480)
        .transition(.scale(scale: 0.2).combined(with: .opacity))
    }

    /// Screenshot hooks (-bakeryDemo pourpan | bake).
    private func demo() {
        switch KitchenDemo.mode {
        case "pourpan":
            phase = .pour
            let now = Date()
            bowlInAt = now.addingTimeInterval(-2)
            everPressed = true
            flow.press(now)
            frozenAt = now.addingTimeInterval(1.35)
        case "bake":
            flow.acc = PourFlow.fullTime
            panPos = CGPoint(x: windowC.x, y: windowC.y + 10)
            panScale = 0.85
            let now = Date()
            bakeAt = now
            phase = .baking
            frozenAt = now.addingTimeInterval(BakeStepView.bakeTime * 0.78)
        default:
            break
        }
    }
}

/// The pan (cake) or paper liner (cupcake) with batter that pours in, rises and bakes golden.
struct PanView: View {
    let treat: Treat
    let fill: CGFloat
    let rise: CGFloat
    var bake: CGFloat = 0
    var time: Double = 0

    /// The batter surface's y in the pan view (300 x 190) as it fills.
    static func cakeSurfaceY(_ level: CGFloat) -> CGFloat { 113 - 6 * level }
    static func linerSurfaceY(_ level: CGFloat) -> CGFloat { 80 - 4 * level }

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            BakeryArt.fit(&g, box: CGRect(x: 0, y: 0, width: 300, height: 190), into: size)
            PanView.paint(treat, fill: fill, rise: rise, bake: bake, time: time, in: g)
        }
    }

    static func paint(_ treat: Treat, fill: CGFloat, rise: CGFloat, bake: CGFloat, time: Double, in g: GraphicsContext) {
        let art = BakeryArt.shared
        let flavor = TreatPainter.flavor(treat.flavor).color
        let raw = flavor.mix(RGB(1, 1, 1), 0.1)
        let spread = min(1, max(0.12, fill / 0.45))
        if treat.kind == .cake {
            var p = g
            p.translateBy(x: 0, y: 40)
            art.draw("pan", in: p)
            let rim: CGFloat = 110
            if fill > 0 {
                let cy = cakeSurfaceY(fill)
                let rx = 128 * spread, ry = 26 * spread
                let H = ry + rise * 62
                var shape = Path()
                let n = 28
                for k in 0...n {
                    // the near half of the surface...
                    let a = CGFloat.pi * (1 - CGFloat(k) / CGFloat(n))
                    let pt = CGPoint(x: 150 + rx * cos(a), y: cy + ry * sin(a))
                    if k == 0 { shape.move(to: pt) } else { shape.addLine(to: pt) }
                }
                for k in 1...n {
                    // ...and the dome rising above it
                    let a = -CGFloat.pi * CGFloat(k) / CGFloat(n)
                    shape.addLine(to: CGPoint(x: 150 + rx * cos(a), y: cy + H * sin(a)))
                }
                shape.closeSubpath()
                let top = raw.mix(flavor.mix(RGB(hex: "#C9803F"), 0.32), Double(bake))
                let edge = raw.mix(flavor.mix(RGB(hex: "#9C5A2A"), 0.45), Double(bake))
                g.fill(shape, with: .radialGradient(Gradient(colors: [top.color, edge.color]),
                                                    center: CGPoint(x: 132, y: cy - H * 0.55), startRadius: 4, endRadius: rx * 1.15))
                g.stroke(shape, with: .color(Shades.outline(edge).color), lineWidth: 3.5)
                // wet batter shines; the shine dulls as it bakes
                var sh = g
                sh.opacity = 0.2 + 0.5 * Double(1 - bake)
                sh.fill(Path(ellipseIn: CGRect(x: 150 - rx * 0.62, y: cy - H * 0.62 - 4, width: rx * 0.5, height: 7 + H * 0.12)),
                        with: .color(Shades.light(top).color))
                drawBubbles(center: CGPoint(x: 150, y: cy - H * 0.45), rx: rx * 0.7, ry: H * 0.3, rise: rise, bake: bake,
                            time: time, color: top, in: g)
                drawCracks(center: CGPoint(x: 150, y: cy - H * 0.82), w: rx, bake: bake, color: top, in: g)
            }
            var arc = Path()
            arc.addArc(center: .zero, radius: 1, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            g.stroke(arc.applying(CGAffineTransform(a: 140, b: 0, c: 0, d: 30, tx: 150, ty: rim)),
                     with: .color(Shades.outline(RGB(hex: "#C9C6D9")).color), lineWidth: 6)
        } else {
            var s = g
            s.translateBy(x: -150, y: -340)
            let top: CGFloat = 418
            if fill > 0 {
                let cy = linerSurfaceY(fill) + 340
                let r = CGRect(x: 300 - 118 * spread, y: cy - 12 * spread, width: 236 * spread, height: 24 * spread)
                s.fill(Path(ellipseIn: r), with: .color(raw.color))
                var o = s
                o.opacity = 0.6
                o.stroke(Path(ellipseIn: r), with: .color(Shades.outline(raw).color), lineWidth: 2.5)
                o.opacity = 0.5 * Double(1 - rise)
                o.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.18, y: r.minY + 3, width: r.width * 0.3, height: 5)),
                       with: .color(Shades.light(raw).color))
            }
            if rise > 0 {
                var d = s
                d.translateBy(x: 0, y: top)
                d.scaleBy(x: 1, y: max(0.05, rise))
                d.translateBy(x: 0, y: -top)
                let col = raw.mix(TreatPainter.baked(flavor, 1), Double(bake))
                art.draw("cupcake_top", col, in: d)
                drawBubbles(center: CGPoint(x: 300, y: top - 50 * rise), rx: 70, ry: 18 * rise, rise: rise, bake: bake,
                            time: time, color: col, in: s)
                drawCracks(center: CGPoint(x: 300, y: top - 82 * rise), w: 70, bake: bake, color: col, in: s)
            }
            art.draw("liner", TreatPainter.liner(treat.liner), in: s)
        }
    }

    /// Little bubbles rising and popping in the batter as it starts to bake.
    static func drawBubbles(center: CGPoint, rx: CGFloat, ry: CGFloat, rise: CGFloat, bake: CGFloat, time: Double,
                            color: RGB, in g: GraphicsContext) {
        guard rise > 0.03, bake < 0.8 else { return }
        let strength = Double(min(1, rise / 0.15)) * Double(1 - bake / 0.8)
        for k in 0..<8 {
            let ph = (time * 0.9 + Double(k) * 0.29).truncatingRemainder(dividingBy: 1)
            let x = center.x + (fxRand(k, 61) - 0.5) * 2 * rx
            let y = center.y + (fxRand(k, 62) - 0.5) * 2 * ry
            let r = 1.5 + 4 * CGFloat(ph)
            let c = Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.7, width: 2 * r, height: 1.4 * r))
            var b = g
            b.opacity = (1 - ph) * 0.8 * strength
            b.fill(c, with: .color(Shades.light(color).color))
            b.stroke(c, with: .color(Shades.shade(color).color), lineWidth: 1.2)
        }
    }

    /// The crust splits a little on top at the end of baking.
    static func drawCracks(center: CGPoint, w: CGFloat, bake: CGFloat, color: RGB, in g: GraphicsContext) {
        guard bake > 0.55 else { return }
        var c = g
        c.opacity = Double(min(1, (bake - 0.55) / 0.35)) * 0.7
        let spots: [(CGFloat, CGFloat, CGFloat)] = [(-0.35, 4, 1), (0.05, -2, -1), (0.4, 5, 1)]
        for (dx, dy, dir) in spots {
            let x = center.x + dx * w
            let y = center.y + dy
            var p = Path()
            p.move(to: CGPoint(x: x - 14, y: y))
            p.addLine(to: CGPoint(x: x - 5, y: y - 3 * dir))
            p.addLine(to: CGPoint(x: x + 3, y: y + 2 * dir))
            p.addLine(to: CGPoint(x: x + 14, y: y - 2 * dir))
            c.stroke(p, with: .color(Shades.deep(color).color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Inside the oven while it bakes: warm light, glowing coils, heat shimmer. Drawn with a screen blend.
struct OvenHeat: View {
    let t: Double

    var body: some View {
        let time = t
        return Canvas { ctx, size in OvenHeat.paint(ctx, size: size, t: time) }
    }

    static func paint(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        do {
            let rect = CGRect(origin: .zero, size: size)
            var g = ctx
            g.clip(to: RoundedRectangle(cornerRadius: 22, style: .continuous).path(in: rect))
            let warm = Double(fxEase(t / 0.9))
            let f1: Double = sin(t * 9)
            let f2: Double = sin(t * 3.7)
            let flicker: Double = 0.85 + 0.15 * f1 * f2
            var w = g
            w.opacity = warm * 0.45 * flicker
            w.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0xFF8A3D), Color(hex: 0x7A2E1E), Color(hex: 0xFF9A4A)]),
                                                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            for y in [CGFloat(12), size.height - 12] {
                var coil = Path()
                let n = 36
                for k in 0...n {
                    let x = 16 + (size.width - 32) * CGFloat(k) / CGFloat(n)
                    let yy = y + CGFloat(k % 2 == 0 ? -4 : 4)
                    if k == 0 { coil.move(to: CGPoint(x: x, y: yy)) } else { coil.addLine(to: CGPoint(x: x, y: yy)) }
                }
                var glow = g
                glow.addFilter(.blur(radius: 7))
                glow.opacity = warm * 0.8 * flicker
                glow.stroke(coil, with: .color(Color(hex: 0xFF6A2A)), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                var core = g
                core.opacity = 0.3 + 0.7 * warm
                core.stroke(coil, with: .color(Color(hex: 0xFFC46A)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            for k in 0..<5 {
                var p = Path()
                let x0 = size.width * (0.14 + 0.18 * CGFloat(k))
                let n = 24
                for j in 0...n {
                    let u = CGFloat(j) / CGFloat(n)
                    let y = size.height * (1 - u)
                    let wave: Double = sin(Double(y) * 0.06 - t * 5 + Double(k) * 1.3)
                    let amp: CGFloat = 3 + 6 * u
                    let x: CGFloat = x0 + CGFloat(wave) * amp
                    if j == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
                var s = g
                s.opacity = 0.14 * warm
                s.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
    }
}

/// Soft wisps of steam curling up off a fresh bake.
struct SteamWisps: View {
    let t: Double

    var body: some View {
        let time = t
        return Canvas { ctx, size in SteamWisps.paint(ctx, size: size, t: time) }
    }

    static func paint(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        do {
            var g = ctx
            g.addFilter(.blur(radius: 4))
            let fadeIn = Double(fxEase(t / 0.5))
            let overall: Double = fadeIn * max(0.35, 1 - t / 10)
            for k in 0..<4 {
                let period = 2.4
                let ph = (t + Double(k) * 0.6).truncatingRemainder(dividingBy: period) / period
                let x0 = size.width * (0.2 + 0.2 * CGFloat(k))
                var p = Path()
                let n = 18
                for j in 0...n {
                    let u = CGFloat(j) / CGFloat(n)
                    let y: CGFloat = size.height * (1 - u) - CGFloat(ph) * 60
                    let wave: Double = sin(Double(u) * 5 + t * 2.2 + Double(k) * 1.7)
                    let amp: CGFloat = 4 + 16 * u
                    let x: CGFloat = x0 + CGFloat(wave) * amp
                    if j == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
                var w = g
                let lift: Double = sin(ph * Double.pi)
                w.opacity = 0.85 * lift * overall
                w.stroke(p, with: .linearGradient(Gradient(colors: [.white.opacity(0), .white, .white.opacity(0)]),
                                                 startPoint: CGPoint(x: x0, y: size.height), endPoint: CGPoint(x: x0, y: 0)),
                         style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
