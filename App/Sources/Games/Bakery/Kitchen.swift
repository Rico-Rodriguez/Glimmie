import SwiftUI
import UIKit

// MARK: - The kitchen: one screen per step
//
// Cakes and cupcakes: mix -> bake -> frost -> decorate. Ice cream: cone -> scoops -> sauce -> decorate.
// Every step lays itself out in a fixed 1024 x 834 design frame (DesignCanvas scales it to the screen).
// The treat stage (600 x 600 art units) sits on the left at `KStage.center`, 560 points square.

enum KStage {
    static let center = CGPoint(x: 340, y: 486)
    static let size: CGFloat = 560
    static var k: CGFloat { size / 600 }
    /// Stage art coordinates -> design coordinates.
    static func design(_ p: CGPoint) -> CGPoint {
        CGPoint(x: center.x - size / 2 + p.x * k, y: center.y - size / 2 + p.y * k)
    }
}

enum BakeStep {
    case mix, bake, frost, cone, scoops, sauce, decorate

    var icon: (String, CGRect) {
        switch self {
        case .mix: return ("eggs", Box.thing)
        case .bake: return ("oven", Box.oven)
        case .frost: return ("pipingbag", Box.thing)
        case .cone: return ("cone_waffle", CGRect(x: 180, y: 390, width: 240, height: 210))
        case .scoops: return ("tub", Box.thing)
        case .sauce: return ("saucebottle", Box.thing)
        case .decorate: return ("top_cherry", Box.topping)
        }
    }
}

struct KitchenView: View {
    @Binding var treat: Treat
    let startStep: Int
    let onDone: (Treat) -> Void
    let onShop: () -> Void

    @State private var step = 0
    @State private var canNext = false
    @State private var pulse = false

    private var steps: [BakeStep] {
        treat.kind == .iceCream ? [.cone, .scoops, .sauce, .decorate] : [.mix, .bake, .frost, .decorate]
    }

    var body: some View {
        ZStack {
            KitchenBackground()
            DesignCanvas {
                ZStack {
                    stepView
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    topBar
                }
                .frame(width: 1024, height: 834)
            }
        }
        .onAppear {
            step = max(0, min(startStep, steps.count - 1))
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    @ViewBuilder private var stepView: some View {
        switch steps[step] {
        case .mix: MixStepView(treat: $treat, done: $canNext)
        case .bake: BakeStepView(treat: $treat, done: $canNext)
        case .frost: FrostStepView(treat: $treat, done: $canNext)
        case .cone: ConeStepView(treat: $treat, done: $canNext)
        case .scoops: ScoopStepView(treat: $treat, done: $canNext)
        case .sauce: SauceStepView(treat: $treat, done: $canNext)
        case .decorate: DecorateStepView(treat: $treat, done: $canNext)
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            HomeButton(action: onShop)
            Spacer()
            HStack(spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                    Sprite(s.icon.0, box: s.icon.1)
                        .padding(9)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(i == step ? Color.white : Color.white.opacity(0.55)))
                        .overlay(Circle().stroke(i < step ? Theme.mint : i == step ? Theme.pink : Color.clear, lineWidth: 5))
                        .scaleEffect(i == step ? 1.15 : 0.9)
                        .opacity(i <= step ? 1 : 0.6)
                }
            }
            Spacer()
            Button(action: next) {
                Image(systemName: step == steps.count - 1 ? "bell.fill" : "arrow.right")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 92)
                    .background(Circle().fill(Color(hex: 0x6CCB8B)))
                    .overlay(Circle().stroke(.white, lineWidth: 6))
                    .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
                    .scaleEffect(pulse ? 1.08 : 0.96)
            }
            .buttonStyle(Squish())
            .opacity(canNext ? 1 : 0)
            .scaleEffect(canNext ? 1 : 0.3)
            .animation(.spring(response: 0.4, dampingFraction: 0.55), value: canNext)
            .allowsHitTesting(canNext)
        }
        .padding(.horizontal, 26)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 20)
    }

    private func next() {
        guard canNext else { return }
        Sound.shared.tap()
        if step == steps.count - 1 {
            Sound.shared.play(.fanfare, volume: 0.6)
            onDone(treat)
            return
        }
        Sound.shared.play(.whoosh, volume: 0.6)
        canNext = false
        withAnimation(.easeInOut(duration: 0.4)) { step += 1 }
    }
}

// MARK: - Shared bits

/// The treat on its stage, drawn at `KStage`.
struct StageTreat: View {
    let treat: Treat
    var bounce = false
    var body: some View {
        TreatView(treat: treat)
            .frame(width: KStage.size, height: KStage.size)
            .scaleEffect(x: bounce ? 1.06 : 1, y: bounce ? 0.94 : 1, anchor: .bottom)
            .position(KStage.center)
    }
}

/// A round pick button with a white plate behind it.
struct PickPlate<Content: View>: View {
    let selected: Bool
    var size: CGFloat = 104
    let tap: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: tap) {
            content()
                .frame(width: size, height: size)
                .background(Circle().fill(.white))
                .overlay(Circle().stroke(selected ? Theme.pink : Theme.blush, lineWidth: selected ? 7 : 4))
                .shadow(color: Theme.ink.opacity(0.18), radius: 5, y: 4)
                .scaleEffect(selected ? 1.1 : 1)
        }
        .buttonStyle(Squish())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
    }
}

private func bounceOnce(_ flag: Binding<Bool>) {
    withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { flag.wrappedValue = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { flag.wrappedValue = false }
    }
}

/// A grid of pick spots on the right side: `cols` columns starting at (x0, y0).
private func gridSpot(_ i: Int, cols: Int, x0: CGFloat, y0: CGFloat, dx: CGFloat, dy: CGFloat) -> CGPoint {
    CGPoint(x: x0 + CGFloat(i % cols) * dx, y: y0 + CGFloat(i / cols) * dy)
}

/// A bottle (batter flavors) or tub (ice cream) with the flavor's fruit on its label.
struct FlavorJar: View {
    let sprite: String
    let flavor: Int
    var body: some View {
        let f = BakeryPalette.flavors[flavor]
        GeometryReader { geo in
            let s = geo.size.width / 160
            ZStack {
                Sprite(sprite, color: f.color, box: Box.thing)
                Sprite(f.icon, color: f.color, box: Box.topping)
                    .frame(width: 50 * s, height: 50 * s)
                    .position(x: 80 * s, y: (sprite == "tub" ? 112 : 104) * s)
            }
        }
    }
}

struct WoodSpoon: View {
    var body: some View {
        ZStack {
            Capsule().fill(Color(hex: 0xE9B07A)).overlay(Capsule().stroke(Color(hex: 0x9B6B52), lineWidth: 4))
                .frame(width: 22, height: 170).offset(y: -90)
            Ellipse().fill(Color(hex: 0xF2C28A)).overlay(Ellipse().stroke(Color(hex: 0x9B6B52), lineWidth: 4))
                .frame(width: 60, height: 80)
            Ellipse().fill(Color.white.opacity(0.4)).frame(width: 14, height: 30).offset(x: -12, y: -8)
        }
        .rotationEffect(.degrees(24))
        .allowsHitTesting(false)
    }
}

// MARK: - Mix and stir

struct MixStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool

    static let ingredients = ["flour", "sugar", "eggs", "milk", "butter"]
    static let slots = [CGPoint(x: 700, y: 290), CGPoint(x: 830, y: 290), CGPoint(x: 960, y: 290),
                        CGPoint(x: 765, y: 450), CGPoint(x: 895, y: 450)]
    private let bowlCenter = CGPoint(x: 340, y: 530)
    private let bowlSize = CGSize(width: 560, height: 420)
    /// Bowl art units -> design points.
    private static let k: CGFloat = 1.4

    @State private var sim = BowlSim()
    @State private var added: [String] = []
    @State private var queued: Set<String> = []
    @State private var gone: Set<String> = []
    @State private var picked = false
    @State private var stirring = false
    @State private var stirDistance: CGFloat = 0
    @State private var burst = 0
    @State private var swishAcc: CGFloat = 0
    @State private var hint = false
    @State private var frozenAt: Date?

    private var allIn: Bool { added.count == MixStepView.ingredients.count }
    private var bowlOrigin: CGPoint { CGPoint(x: bowlCenter.x - bowlSize.width / 2, y: bowlCenter.y - bowlSize.height / 2) }

    private func toBowl(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - bowlOrigin.x) / MixStepView.k, y: (p.y - bowlOrigin.y) / MixStepView.k)
    }

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                let now = frozenAt ?? tl.date
                Canvas { ctx, _ in
                    var g = ctx
                    g.translateBy(x: bowlOrigin.x, y: bowlOrigin.y)
                    g.scaleBy(x: MixStepView.k, y: MixStepView.k)
                    sim.draw(in: g, now: now)
                }
            }
            .frame(width: 1024, height: 834)
            .position(x: 512, y: 417)
            .allowsHitTesting(false)

            Color.clear
                .frame(width: bowlSize.width, height: bowlSize.height + 80)
                .contentShape(Rectangle())
                .gesture(stirGesture)
                .position(x: bowlCenter.x, y: bowlCenter.y - 40)

            if allIn && picked && !done && !stirring {
                WoodSpoon()
                    .scaleEffect(0.9)
                    .offset(x: hint ? 90 : -90, y: hint ? -60 : -110)
                    .position(bowlCenter)
                    .opacity(0.9)
                    .allowsHitTesting(false)
                    .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { hint = true } }
            }
            if burst > 0 { SparkleBurst(count: 16, radius: 260).id(burst).position(x: bowlCenter.x, y: bowlCenter.y - 80) }

            if !allIn {
                ForEach(Array(MixStepView.ingredients.enumerated()), id: \.offset) { i, name in
                    if !gone.contains(name) {
                        PickPlate(selected: false, size: 118, tap: { drop(name, at: i) }) {
                            Sprite(name, box: Box.thing).padding(8)
                        }
                        .opacity(queued.contains(name) ? 0.55 : 1)
                        .position(MixStepView.slots[i])
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            } else {
                ForEach(0..<BakeryPalette.flavors.count, id: \.self) { i in
                    PickPlate(selected: picked && treat.flavor == i, size: 96, tap: { pick(i) }) {
                        FlavorJar(sprite: "bottle", flavor: i).padding(6)
                    }
                    .position(flavorSpot(i))
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear(perform: demo)
    }

    private func flavorSpot(_ i: Int) -> CGPoint { gridSpot(i, cols: 4, x0: 660, y0: 250, dx: 108, dy: 150) }

    private var stirGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard allIn && picked else { return }
                let b = toBowl(CGPoint(x: bowlCenter.x - bowlSize.width / 2 + v.location.x,
                                       y: bowlCenter.y - 40 - (bowlSize.height + 80) / 2 + v.location.y))
                var q = CGPoint(x: (b.x - 200) / 152, y: (b.y - 125) / 75)
                let len = hypot(q.x, q.y)
                if len > 0.9 { q.x *= 0.9 / len; q.y *= 0.9 / len }
                let d = sim.stir(to: q, at: Date())
                if !stirring { stirring = true }
                stirDistance += d
                swishAcc += d
                if swishAcc > 1.3 {
                    swishAcc = 0
                    BakerySound.shared.play(.swish, volume: 0.8)
                    Sound.shared.tap()
                }
                if !done && (sim.progress >= 0.96 || stirDistance > 16) { finish() }
            }
            .onEnded { _ in
                sim.endStir()
                stirring = false
            }
    }

    private func drop(_ name: String, at i: Int) {
        guard !queued.contains(name), let what = Ingredient(rawValue: name) else { return }
        Sound.shared.play(.pop, volume: 0.7)
        Sound.shared.tap()
        queued.insert(name)
        let ev = sim.pour(what, from: toBowl(MixStepView.slots[i]))
        let lead = max(0, ev.start.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + lead) {
            withAnimation(.easeOut(duration: 0.12)) { _ = gone.insert(name) }
        }
        sounds(for: ev, lead: lead)
        DispatchQueue.main.asyncAfter(deadline: .now() + lead + ev.pourEnd + 0.15) {
            withAnimation(.spring(response: 0.3)) { added.append(name) }
            if added.count == MixStepView.ingredients.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { Sound.shared.play(.sparkle, volume: 0.7) }
            }
        }
    }

    private func sounds(for ev: PourEvent, lead: Double) {
        func at(_ t: Double, _ f: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + lead + t, execute: f)
        }
        at(0) { Sound.shared.play(.whoosh, volume: 0.35) }
        let ps = ev.pourStart
        switch ev.what {
        case .flour:
            at(ps + 0.05) { BakerySound.shared.play(.shake, volume: 0.45) }
            at(ps + 0.3) { BakerySound.shared.play(.poof, volume: 0.9) }
            at(ps + 0.8) { BakerySound.shared.play(.poof, volume: 0.6) }
        case .sugar:
            at(ps + 0.1) { BakerySound.shared.play(.grains) }
        case .milk:
            at(ps) { BakerySound.shared.play(.glug) }
        case .flavor:
            at(ps) { BakerySound.shared.play(.drizzle, volume: 0.8) }
            at(ps + 0.45) { BakerySound.shared.play(.drizzle, volume: 0.6) }
        case .eggs:
            let fall = PourEvent.fallTime(from: PourEvent.eggY + 14, to: BowlGeo.center.y)
            for k in 0..<2 {
                at(ev.crackTime(k)) { Sound.shared.play(.crack, volume: 0.9) }
                at(ev.crackTime(k) + 0.12 + fall) { BakerySound.shared.play(.plop, volume: 0.8) }
            }
        case .butter:
            let fall = PourEvent.fallTime(from: ev.hover.y, to: BowlGeo.center.y - 8)
            at(ps + fall) { BakerySound.shared.play(.plop) }
        }
    }

    private func pick(_ i: Int) {
        Sound.shared.tap()
        guard !(picked && treat.flavor == i) else {
            Sound.shared.play(.boing, volume: 0.4)
            return
        }
        let ev = sim.pour(.flavor, flavor: i, from: toBowl(flavorSpot(i)))
        sim.setTarget(BakeryPalette.flavors[i].color)
        sounds(for: ev, lead: max(0, ev.start.timeIntervalSinceNow))
        withAnimation(.easeInOut(duration: 0.4)) {
            treat.flavor = i
            picked = true
        }
        if done { burst += 1 }
    }

    private func finish() {
        sim.finish()
        withAnimation(.spring()) { done = true }
        burst += 1
        BakerySound.shared.play(.magic)
        Sound.shared.play(.sparkle, volume: 0.8)
    }

    /// Screenshot hooks (-bakeryDemo stir | pour).
    private func demo() {
        switch KitchenDemo.mode {
        case "stir":
            treat.flavor = 2
            sim.prefill([.milk, .eggs, .flour, .sugar, .butter, .flavor], flavor: treat.flavor)
            sim.setTarget(BakeryPalette.flavors[treat.flavor].color)
            added = MixStepView.ingredients
            picked = true
            stirring = true
            let t0 = Date()
            for k in 0..<60 {
                let a = Double(k) * 0.16
                let r = 0.25 + 0.35 * abs(sin(Double(k) * 0.05))
                sim.stir(to: CGPoint(x: cos(a) * r, y: sin(a) * r), at: t0.addingTimeInterval(Double(k) * 0.008))
            }
        case "pour":
            sim.prefill([.milk, .eggs])
            let ev = sim.pour(.flour, from: toBowl(MixStepView.slots[0]))
            added = ["milk", "eggs"]
            gone = ["milk", "eggs", "flour"]
            queued = gone
            frozenAt = ev.start.addingTimeInterval(1.15)
        default:
            break
        }
    }
}

/// Screenshot hooks: `-bakeryDemo <name>` freezes a kitchen step mid-action.
enum KitchenDemo {
    static let mode: String = {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-bakeryDemo"), i + 1 < a.count { return a[i + 1] }
        return ""
    }()
}

// MARK: - Frost

struct FrostStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool

    /// Spatula strokes this time (stage units): only the frosting under them shows until it's spread.
    @State private var strokes: [[CGPoint]] = []
    @State private var dragging = false
    @State private var covered = Set<Int>()
    @State private var full = false
    @State private var fullAt: Date?
    @State private var fading = false
    @State private var tool: CGPoint?
    @State private var squish = false
    @State private var burst = 0
    @State private var smearAcc: CGFloat = 0
    @State private var samples: [CGPoint] = []
    @State private var hint = false
    @State private var pipeAt: Date?
    @State private var frozenPipe: CGFloat?
    @State private var holding = false
    @State private var pipeToken = 0

    private static let brush = TreatPainter.spreadBrush
    private static let pipeTime = 0.8
    private static let maxSwooshNumbers = 2400

    private var coverage: CGFloat {
        samples.isEmpty ? 0 : min(1, CGFloat(covered.count) / CGFloat(samples.count) / 0.72)
    }

    var body: some View {
        ZStack {
            if treat.kind == .cake { cakeStage } else { cupcakeStage }
            if burst > 0 { SparkleBurst(count: 16, radius: 260).id(burst).position(x: KStage.center.x, y: KStage.center.y - 60) }
            if treat.kind == .cake { spatula }
            picker
        }
        .onAppear {
            if treat.frosting == nil { treat.frosting = 2 }
            if treat.kind == .cake {
                samples = FrostStepView.makeSamples(tiers: treat.tiers)
                if !(treat.swoosh ?? []).isEmpty { full = true; done = true }
            }
            if treat.kind == .cupcake && treat.frostStage > 0 { done = true }
            demo()
        }
    }

    // MARK: Cake: spread it with a spatula

    private var cakeStage: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !fading)) { tl in
            let t = treat
            let fade: Double = full ? (fading ? Double(fxEase(tl.date.timeIntervalSince(fullAt ?? tl.date) / 0.6)) : 1) : 0
            let mask: [[CGPoint]]? = fade >= 1 ? nil : strokes
            let dollop = full ? 0 : 1 - coverage
            Canvas { ctx, size in
                var g = ctx
                BakeryArt.fit(&g, box: Box.stage, into: size)
                TreatPainter.draw(t, in: g, frostMask: mask, maskFade: fade)
                if dollop > 0.03, let fr = t.frosting {
                    FrostStepView.drawDollop(on: t, k: dollop, color: TreatPainter.frosting(fr), in: g)
                }
            }
        }
        .frame(width: KStage.size, height: KStage.size)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in spread(at: v.location) }
            .onEnded { _ in dragging = false; tool = nil })
        .scaleEffect(x: squish ? 1.04 : 1, y: squish ? 0.96 : 1, anchor: .bottom)
        .position(KStage.center)
    }

    @ViewBuilder private var spatula: some View {
        let load = full ? 0.15 : max(0.15, 1 - coverage)
        if let p = tool {
            Spatula(load: load, color: TreatPainter.frosting(treat.frosting ?? 0))
                .frame(width: 220, height: 220)
                .position(x: p.x + 60, y: p.y - 60)
                .allowsHitTesting(false)
        } else if !done {
            let n = max(1, min(3, treat.tiers))
            let top = KStage.design(CGPoint(x: 300, y: BakeryArt.shared.tiers[n - 1].t))
            Spatula(load: 1, color: TreatPainter.frosting(treat.frosting ?? 0))
                .frame(width: 220, height: 220)
                .offset(x: hint ? 80 : -60, y: hint ? -6 : 8)
                .position(x: top.x + 60, y: top.y - 70)
                .opacity(0.92)
                .allowsHitTesting(false)
                .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { hint = true } }
        }
    }

    static func makeSamples(tiers: Int) -> [CGPoint] {
        var out: [CGPoint] = []
        let art = BakeryArt.shared
        for i in 0..<max(1, min(3, tiers)) {
            guard let shape = art.sprites["cake_frost\(i)"]?.first else { continue }
            let b = shape.bounds
            var y = b.minY + 8
            while y < b.maxY {
                var x = b.minX + 8
                while x < b.maxX {
                    let p = CGPoint(x: x, y: y)
                    if shape.path.contains(p) { out.append(p) }
                    x += 22
                }
                y += 22
            }
        }
        return out
    }

    private func spread(at loc: CGPoint) {
        tool = CGPoint(x: KStage.center.x - KStage.size / 2 + loc.x, y: KStage.center.y - KStage.size / 2 + loc.y)
        let p = CGPoint(x: loc.x / KStage.k, y: loc.y / KStage.k)
        if !dragging {
            dragging = true
            strokes.append([p])
            record(p, newStroke: true)
        } else {
            guard let l = strokes.last?.last else { return }
            let d = hypot(p.x - l.x, p.y - l.y)
            guard d > 9 else { return }
            strokes[strokes.count - 1].append(p)
            record(p, newStroke: false)
            smearAcc += d
            if smearAcc > 200 {
                smearAcc = 0
                BakerySound.shared.play(.smear, volume: 0.8)
                Sound.shared.tap()
            }
        }
        guard !full else { return }
        let r = FrostStepView.brush
        for (i, s) in samples.enumerated() where !covered.contains(i) {
            if hypot(s.x - p.x, s.y - p.y) < r { covered.insert(i) }
        }
        if !samples.isEmpty && Double(covered.count) / Double(samples.count) > 0.72 { completeSpread() }
    }

    /// Keeps the spatula marks in the treat, so they stay on the cake after this step.
    private func record(_ p: CGPoint, newStroke: Bool) {
        var sw = treat.swoosh ?? []
        let used = sw.reduce(0) { $0 + $1.count }
        guard used < FrostStepView.maxSwooshNumbers else { return }
        if newStroke || sw.isEmpty { sw.append([]) }
        sw[sw.count - 1] += [Int(p.x.rounded()), Int(p.y.rounded())]
        treat.swoosh = sw
    }

    private func completeSpread() {
        full = true
        fullAt = Date()
        fading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { fading = false }
        burst += 1
        BakerySound.shared.play(.magic)
        Sound.shared.play(.sparkle, volume: 0.8)
        bounceOnce($squish)
        withAnimation(.spring()) { done = true }
    }

    /// The big blob of frosting dropped on top, getting smaller as it's spread out.
    static func drawDollop(on t: Treat, k: CGFloat, color: RGB, in g: GraphicsContext) {
        let n = max(1, min(3, t.tiers))
        let tier = BakeryArt.shared.tiers[n - 1]
        let s = 0.3 + 0.7 * k
        var d = g
        d.translateBy(x: 300 + 10 * (1 - k), y: tier.t - 4)
        d.scaleBy(x: s * min(1, tier.hw / 110), y: s)
        var blob = Path()
        blob.move(to: CGPoint(x: -62, y: 6))
        blob.addCurve(to: CGPoint(x: -30, y: -30), control1: CGPoint(x: -72, y: -14), control2: CGPoint(x: -52, y: -30))
        blob.addCurve(to: CGPoint(x: 4, y: -60), control1: CGPoint(x: -24, y: -50), control2: CGPoint(x: -10, y: -62))
        blob.addCurve(to: CGPoint(x: 34, y: -28), control1: CGPoint(x: 22, y: -58), control2: CGPoint(x: 30, y: -42))
        blob.addCurve(to: CGPoint(x: 62, y: 6), control1: CGPoint(x: 56, y: -28), control2: CGPoint(x: 72, y: -10))
        blob.addCurve(to: CGPoint(x: -62, y: 6), control1: CGPoint(x: 40, y: 22), control2: CGPoint(x: -40, y: 22))
        blob.closeSubpath()
        d.fill(blob, with: .color(color.color))
        d.stroke(blob, with: .color(Shades.outline(color).color), lineWidth: 4)
        var fold = Path()
        fold.move(to: CGPoint(x: -46, y: -4))
        fold.addQuadCurve(to: CGPoint(x: 42, y: -8), control: CGPoint(x: 0, y: 10))
        fold.move(to: CGPoint(x: -24, y: -32))
        fold.addQuadCurve(to: CGPoint(x: 24, y: -30), control: CGPoint(x: 2, y: -20))
        d.stroke(fold, with: .color(Shades.shade(color).color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        var shine = d
        shine.opacity = 0.65
        shine.fill(Path(ellipseIn: CGRect(x: -36, y: -40, width: 18, height: 9)), with: .color(.white))
        shine.fill(Path(ellipseIn: CGRect(x: -6, y: -56, width: 9, height: 6)), with: .color(.white))
    }

    // MARK: Cupcake: hold to pipe rings around

    private var cupcakeStage: some View {
        TimelineView(.animation(minimumInterval: nil, paused: pipeAt == nil)) { tl in
            let f: CGFloat = frozenPipe ?? (pipeAt.map { CGFloat(min(1, tl.date.timeIntervalSince($0) / FrostStepView.pipeTime)) } ?? 0)
            let piping = pipeAt != nil && treat.frostStage < 3
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
            ZStack {
                TreatView(treat: treat, pipe: piping ? f : 0)
                    .frame(width: KStage.size, height: KStage.size)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !holding {
                                holding = true
                                if pipeAt == nil { pipeRing() }
                            }
                        }
                        .onEnded { _ in holding = false })
                    .scaleEffect(x: squish ? 1.07 : 1, y: squish ? 0.93 : 1, anchor: .bottom)
                    .position(KStage.center)
                if piping {
                    let n = KStage.design(Piping.nozzle(style: treat.frostStyle, stage: treat.frostStage + 1, f: f))
                    let sq = CGFloat(sin(t * 18))
                    Sprite("pipingbag", color: TreatPainter.frosting(treat.frosting ?? 0), box: Box.thing)
                        .frame(width: 150, height: 150)
                        .scaleEffect(x: 1 + 0.05 * sq, y: 1 - 0.04 * sq)
                        .rotationEffect(.degrees(-20))
                        .position(x: n.x + 30, y: n.y - 72)
                        .allowsHitTesting(false)
                } else if !done || (holding && treat.frostStage >= 3) {
                    Sprite("pipingbag", color: TreatPainter.frosting(treat.frosting ?? 0), box: Box.thing)
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-20))
                        .offset(x: hint ? 70 : -70, y: hint ? -10 : 10)
                        .position(x: KStage.center.x + 40, y: KStage.center.y - 190)
                        .opacity(0.9)
                        .allowsHitTesting(false)
                        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { hint = true } }
                }
            }
        }
    }

    private func pipeRing() {
        guard treat.frostStage < 3 else {
            Sound.shared.play(.boing, volume: 0.5)
            bounceOnce($squish)
            return
        }
        pipeAt = Date()
        pipeToken += 1
        let token = pipeToken
        BakerySound.shared.play(.squeeze)
        Sound.shared.tap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if token == pipeToken { BakerySound.shared.play(.squeeze, volume: 0.7) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + FrostStepView.pipeTime) {
            guard token == pipeToken else { return }
            treat.frostStage += 1
            pipeAt = nil
            bounceOnce($squish)
            if treat.frostStage == 3 {
                burst += 1
                Sound.shared.play(.sparkle, volume: 0.8)
            }
            withAnimation(.spring()) { done = true }
            if holding && treat.frostStage < 3 { pipeRing() }
        }
    }

    // MARK: Picking

    @ViewBuilder private var picker: some View {
        if treat.kind == .cupcake {
            ForEach(Array(BakeryPalette.frostStyles.enumerated()), id: \.offset) { i, style in
                PickPlate(selected: treat.frostStyle == style, size: 110, tap: { pickStyle(style) }) {
                    TreatView(treat: { var t = treat; t.frostStyle = style; t.frostStage = 3; t.toppings = []; return t }(), plate: false)
                        .padding(8)
                }
                .position(x: 720 + CGFloat(i) * 122, y: 190)
            }
        }
        let y0: CGFloat = treat.kind == .cupcake ? 330 : 240
        ForEach(0..<BakeryPalette.frostings.count, id: \.self) { i in
            PickPlate(selected: treat.frosting == i, size: 92, tap: { pickColor(i) }) {
                Sprite("top_cream", color: BakeryPalette.frostings[i], box: Box.topping).padding(10)
            }
            .position(gridSpot(i, cols: 3, x0: 720, y0: y0, dx: 122, dy: 112))
        }
    }

    private func pickColor(_ i: Int) {
        Sound.shared.play(.pop, volume: 0.7)
        Sound.shared.tap()
        withAnimation(.easeInOut(duration: 0.25)) { treat.frosting = i }
        if full || treat.frostStage > 0 { burst += 1 }
    }

    private func pickStyle(_ s: String) {
        Sound.shared.play(.pop, volume: 0.7)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.3)) { treat.frostStyle = s }
        if treat.frostStage > 0 { bounceOnce($squish) }
    }

    /// Screenshot hooks (-bakeryDemo spread | pipe).
    private func demo() {
        switch KitchenDemo.mode {
        case "spread" where treat.kind == .cake:
            let n = max(1, min(3, treat.tiers))
            let k = KStage.k
            for i in (0..<n).reversed() {
                let g = BakeryArt.shared.tiers[i]
                for row in 0..<3 {
                    let y = g.t - g.ry * 0.5 + CGFloat(row) * (g.b - g.t + g.ry) / 3
                    dragging = false
                    let steps = 9
                    for s in 0...steps {
                        let x = 300 - g.hw * 0.95 + 1.9 * g.hw * CGFloat(s) / CGFloat(steps)
                        let wob = CGFloat(sin(Double(s) * 1.3 + Double(row))) * 8
                        if row == 2 && s > 5 { break }
                        spread(at: CGPoint(x: x * k, y: (y + wob) * k))
                    }
                }
            }
            dragging = false
        case "pipe" where treat.kind == .cupcake:
            treat.frostStage = 1
            pipeAt = Date()
            frozenPipe = 0.62
        default:
            break
        }
    }
}

/// An offset spatula with frosting on its blade. The tip (where the finger is) is at (50, 170) of 220 x 220.
struct Spatula: View {
    /// How much frosting is on the blade, 0...1.
    let load: CGFloat
    let color: RGB

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.scaleBy(x: size.width / 220, y: size.height / 220)
            // the wooden handle
            var h = Path()
            h.move(to: CGPoint(x: 132, y: 88))
            h.addLine(to: CGPoint(x: 196, y: 24))
            g.stroke(h, with: .color(Color(hex: 0x8A5A3A)), style: StrokeStyle(lineWidth: 26, lineCap: .round))
            g.stroke(h, with: .color(Color(hex: 0xD49A66)), style: StrokeStyle(lineWidth: 19, lineCap: .round))
            var hs = Path()
            hs.move(to: CGPoint(x: 146, y: 70))
            hs.addLine(to: CGPoint(x: 186, y: 30))
            g.stroke(hs, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            // the metal blade
            var b = g
            b.translateBy(x: 86, y: 134)
            b.rotate(by: .degrees(-45))
            let blade = RoundedRectangle(cornerRadius: 15, style: .continuous).path(in: CGRect(x: -58, y: -17, width: 110, height: 34))
            b.fill(blade, with: .linearGradient(Gradient(colors: [Color(hex: 0xF5F8FC), Color(hex: 0xC3CCD8), Color(hex: 0xE3E8EF)]),
                                               startPoint: CGPoint(x: 0, y: -17), endPoint: CGPoint(x: 0, y: 17)))
            b.stroke(blade, with: .color(Color(hex: 0x7D8796)), lineWidth: 3)
            var shine = Path()
            shine.move(to: CGPoint(x: -44, y: -8))
            shine.addLine(to: CGPoint(x: 38, y: -8))
            b.stroke(shine, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            // the ferrule where blade meets handle
            b.fill(RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: 50, y: -12, width: 14, height: 24)), with: .color(Color(hex: 0xB9C1CC)))
            b.stroke(RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: 50, y: -12, width: 14, height: 24)), with: .color(Color(hex: 0x7D8796)), lineWidth: 2.5)
            // frosting on the blade
            if load > 0.05 {
                let w = 22 + 46 * load
                var f = Path()
                f.move(to: CGPoint(x: -56, y: 4))
                f.addCurve(to: CGPoint(x: -56 + w, y: 2), control1: CGPoint(x: -50, y: -14 - 10 * load), control2: CGPoint(x: -56 + w * 0.7, y: -12 - 8 * load))
                f.addCurve(to: CGPoint(x: -56, y: 4), control1: CGPoint(x: -56 + w * 0.6, y: 18), control2: CGPoint(x: -40, y: 16))
                f.closeSubpath()
                b.fill(f, with: .color(color.color))
                b.stroke(f, with: .color(Shades.outline(color).color), lineWidth: 2.5)
                b.fill(Path(ellipseIn: CGRect(x: -48, y: -8 - 4 * load, width: 12, height: 6)), with: .color(.white.opacity(0.7)))
            }
        }
    }
}

// MARK: - Ice cream: cone, scoops, sauce

struct ConeStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool
    @State private var bounce = false
    @State private var burst = 0

    var body: some View {
        ZStack {
            StageTreat(treat: treat, bounce: bounce)
            SparkleBurst(count: 12, radius: 200).id(burst).position(KStage.design(CGPoint(x: 300, y: 480)))
            ForEach(Array(BakeryPalette.cones.enumerated()), id: \.offset) { i, c in
                PickPlate(selected: treat.cone == c, size: 120, tap: { pick(c) }) {
                    Sprite("cone_\(c)", color: TreatPainter.liner(treat.liner), box: CGRect(x: 180, y: 386, width: 240, height: 214))
                        .padding(12)
                }
                .position(gridSpot(i, cols: 3, x0: 710, y0: 230, dx: 138, dy: 150))
            }
            if treat.cone == "cup" {
                ForEach(0..<BakeryPalette.liners.count, id: \.self) { i in
                    PickPlate(selected: treat.liner == i, size: 58, tap: { pickCup(i) }) {
                        Circle().fill(BakeryPalette.liners[i].color).padding(8)
                    }
                    .position(gridSpot(i, cols: 5, x0: 700, y0: 560, dx: 70, dy: 76))
                }
                .transition(.opacity)
            }
        }
        .onAppear { done = true }
    }

    private func pick(_ c: String) {
        Sound.shared.play(.pop)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.3)) { treat.cone = c }
        bounceOnce($bounce)
        burst += 1
    }

    private func pickCup(_ i: Int) {
        Sound.shared.play(.pop, volume: 0.7)
        Sound.shared.tap()
        treat.liner = i
        bounceOnce($bounce)
    }
}

struct ScoopStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool
    @State private var flying: Int?
    @State private var flyAt = CGPoint.zero
    @State private var bounce = false
    @State private var burst = 0

    private func spot(_ i: Int) -> CGPoint { gridSpot(i, cols: 4, x0: 660, y0: 250, dx: 108, dy: 150) }

    var body: some View {
        ZStack {
            StageTreat(treat: treat, bounce: bounce)
            SparkleBurst(count: 10, radius: 180).id(burst).position(KStage.design(CGPoint(x: 300, y: topY)))
            ForEach(0..<BakeryPalette.flavors.count, id: \.self) { i in
                PickPlate(selected: false, size: 96, tap: { scoop(i) }) {
                    FlavorJar(sprite: "tub", flavor: i).padding(6)
                }
                .opacity(treat.scoops.count >= 4 ? 0.55 : 1)
                .position(spot(i))
            }
            if !treat.scoops.isEmpty {
                RoundButton(symbol: "arrow.uturn.backward", tint: Color(hex: 0x9B79E0)) { undo() }
                    .position(x: 560, y: 160)
                    .transition(.scale)
            }
            if let f = flying {
                Sprite("scoop", color: BakeryPalette.flavors[f].color, box: CGRect(x: -110, y: -100, width: 220, height: 150))
                    .frame(width: 205, height: 140)
                    .position(flyAt)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { if !treat.scoops.isEmpty { done = true } }
    }

    private var topY: CGFloat {
        BakeryArt.shared.scoopY0 - CGFloat(max(0, treat.scoops.count - 1)) * BakeryArt.shared.scoopDY - 40
    }

    private func scoop(_ i: Int) {
        guard flying == nil else { return }
        guard treat.scoops.count < 4 else {
            Sound.shared.play(.boing, volume: 0.5)
            bounceOnce($bounce)
            return
        }
        Sound.shared.play(.pop, volume: 0.7)
        Sound.shared.tap()
        let art = BakeryArt.shared
        let target = KStage.design(CGPoint(x: 300, y: art.scoopY0 - CGFloat(treat.scoops.count) * art.scoopDY - 12))
        flying = i
        flyAt = spot(i)
        withAnimation(.easeIn(duration: 0.4)) { flyAt = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            flying = nil
            treat.scoops.append(i)
            BakerySound.shared.play(.scoop)
            BakerySound.shared.play(.freeze, volume: 0.5)
            bounceOnce($bounce)
            burst += 1
            withAnimation(.spring()) { done = true }
        }
    }

    private func undo() {
        guard !treat.scoops.isEmpty else { return }
        Sound.shared.play(.whoosh, volume: 0.6)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.3)) {
            _ = treat.scoops.removeLast()
            treat.toppings = []
        }
        if treat.scoops.isEmpty { done = false }
    }
}

struct SauceStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool
    @State private var bounce = false
    @State private var burst = 0
    @State private var pourAt: Date?
    @State private var frozenAge: Double?

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: nil, paused: pourAt == nil)) { tl in
                let age = frozenAge ?? (pourAt.map { tl.date.timeIntervalSince($0) } ?? 10)
                let reveal = fxEase((age - 0.45) / 1.0)
                ZStack {
                    TreatView(treat: treat, sauceReveal: reveal)
                        .frame(width: KStage.size, height: KStage.size)
                        .scaleEffect(x: bounce ? 1.06 : 1, y: bounce ? 0.94 : 1, anchor: .bottom)
                        .position(KStage.center)
                    if age < 1.7, let sc = treat.sauce {
                        let t = treat
                        Canvas { ctx, _ in SauceStepView.drawBottle(ctx, treat: t, age: age, color: TreatPainter.sauce(sc)) }
                            .frame(width: 1024, height: 834)
                            .position(x: 512, y: 417)
                            .allowsHitTesting(false)
                    }
                }
            }
            SparkleBurst(count: 12, radius: 200).id(burst).position(KStage.design(CGPoint(x: 300, y: 200)))
            ForEach(0..<BakeryPalette.sauces.count, id: \.self) { i in
                PickPlate(selected: treat.sauce == i, size: 116, tap: { pick(i) }) {
                    Sprite("saucebottle", color: BakeryPalette.sauces[i], box: Box.thing).padding(10)
                }
                .position(gridSpot(i, cols: 3, x0: 720, y0: 260, dx: 136, dy: 160))
            }
            PickPlate(selected: treat.sauce == nil, size: 90, tap: { pick(nil) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Theme.pink)
            }
            .position(x: 856, y: 600)
        }
        .onAppear {
            done = true
            if KitchenDemo.mode == "sauce" {
                if treat.sauce == nil { treat.sauce = 0 }
                pourAt = Date()
                frozenAge = 0.95
            }
        }
    }

    /// The squeeze bottle flies over, turns upside down and zig-zags sauce over the top scoop.
    static func drawBottle(_ ctx: GraphicsContext, treat: Treat, age: Double, color: RGB) {
        let art = BakeryArt.shared
        let n = max(1, min(4, treat.scoops.count))
        let topStage = CGPoint(x: 300, y: art.scoopY0 - CGFloat(n - 1) * art.scoopDY - 88)
        let top = KStage.design(topStage)
        let hover = CGPoint(x: top.x + 40, y: top.y - 170)
        var center = hover
        var angle = 160.0
        var alpha = 1.0
        if age < 0.3 {
            let k = fxEase(age / 0.3)
            center = CGPoint(x: hover.x + (1 - k) * 260, y: hover.y - (1 - k) * 60)
            angle = 160 * Double(k)
        } else if age < 1.25 {
            center.x += CGFloat(sin((age - 0.3) * 13)) * 34
        } else {
            let k = fxEase((age - 1.25) / 0.4)
            center = CGPoint(x: hover.x + k * 220, y: hover.y - k * 80)
            angle = 160 * Double(1 - k)
            alpha = Double(1 - k)
        }
        let s: CGFloat = 0.85
        let a = CGFloat(angle * .pi / 180)
        let dx: CGFloat = 0, dy: CGFloat = (6 - 80) * s
        let nozzle = CGPoint(x: center.x + dx * cos(a) - dy * sin(a), y: center.y + dx * sin(a) + dy * cos(a))
        if age > 0.3 {
            let stopped: Double? = age > 1.25 ? age - 1.25 : nil
            if let st = LiquidStream(mouth: nozzle, floorY: top.y + 6, vx: 0, width: 9, v0: 80, age: age - 0.3,
                                     stopped: stopped, phase: age, wobble: 1) {
                st.draw(in: ctx, color: color)
            }
        }
        var g = ctx
        g.opacity = alpha
        g.translateBy(x: center.x, y: center.y)
        g.rotate(by: .degrees(angle))
        g.scaleBy(x: s, y: s)
        g.translateBy(x: -80, y: -80)
        // squeezed in the middle while it pours
        if age > 0.3 && age < 1.25 {
            let sq = CGFloat(0.06 + 0.03 * sin(age * 20))
            g.translateBy(x: 80, y: 96)
            g.scaleBy(x: 1 - sq, y: 1)
            g.translateBy(x: -80, y: -96)
        }
        art.draw("saucebottle", color, in: g)
    }

    private func pick(_ i: Int?) {
        Sound.shared.tap()
        withAnimation(.spring(response: 0.3)) { treat.sauce = i }
        guard i != nil else {
            Sound.shared.play(.whoosh, volume: 0.5)
            pourAt = nil
            bounceOnce($bounce)
            return
        }
        pourAt = Date()
        Sound.shared.play(.whoosh, volume: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { BakerySound.shared.play(.squeeze, volume: 0.6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { BakerySound.shared.play(.drizzle) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { BakerySound.shared.play(.drizzle, volume: 0.7) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            bounceOnce($bounce)
            burst += 1
        }
    }
}

// MARK: - Decorate

struct DecorateStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool

    @State private var tray = 0
    /// nil = a surprise color for every topping
    @State private var colorPick: Int?
    @State private var born: [UUID: Date] = [:]
    @State private var grabbed: UUID?
    @State private var grabDelta = CGSize.zero
    @State private var dragStart: CGPoint?
    @State private var selected = "top_strawberry"
    @State private var history: [[UUID]] = []
    @State private var bounce = false
    @State private var shaker = false
    @State private var shakerAt = CGPoint.zero

    private static let maxToppings = 220

    var body: some View {
        ZStack {
            stage
            if shaker {
                Sprite("shaker", color: Theme.pink.rgbApprox, box: Box.thing)
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(160))
                    .position(shakerAt)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
            trayPanel
                .position(x: 850, y: 486)
        }
        .onAppear { done = true }
    }

    // MARK: Stage

    private var stage: some View {
        let t = treat
        let ages = born
        let hide = grabbed
        return TimelineView(.animation) { tl in
            Canvas { ctx, size in
                var g = ctx
                BakeryArt.fit(&g, box: Box.stage, into: size)
                let now = tl.date
                var a: [UUID: Double] = [:]
                for (k, v) in ages { a[k] = now.timeIntervalSince(v) }
                TreatPainter.draw(t, in: g, ages: a, hidden: hide)
                if let id = hide, let tp = t.toppings.first(where: { $0.id == id }) {
                    // the grabbed topping, a little bigger, on top
                    BakeryArt.shared.draw(tp.sprite, TreatPainter.candy(tp.color), at: CGPoint(x: tp.x, y: tp.y),
                                          scale: CGFloat(tp.scale) * 1.15, rotation: tp.rot, in: g)
                }
            }
        }
        .frame(width: KStage.size, height: KStage.size)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged(dragChanged)
            .onEnded(dragEnded))
        .scaleEffect(x: bounce ? 1.03 : 1, y: bounce ? 0.97 : 1, anchor: .bottom)
        .position(KStage.center)
    }

    private func stagePoint(_ loc: CGPoint) -> CGPoint { CGPoint(x: loc.x / KStage.k, y: loc.y / KStage.k) }

    private func dragChanged(_ v: DragGesture.Value) {
        let p = stagePoint(v.location)
        if dragStart == nil {
            dragStart = p
            if let hit = hitTest(p), let tp = treat.toppings.first(where: { $0.id == hit }) {
                grabbed = hit
                grabDelta = CGSize(width: tp.x - p.x, height: tp.y - p.y)
                Sound.shared.play(.tap, volume: 0.8)
                Sound.shared.tap()
            }
        }
        if let id = grabbed, let i = treat.toppings.firstIndex(where: { $0.id == id }) {
            treat.toppings[i].x = Double(p.x + grabDelta.width)
            treat.toppings[i].y = Double(p.y + grabDelta.height)
        }
    }

    private func dragEnded(_ v: DragGesture.Value) {
        let p = stagePoint(v.location)
        let moved = hypot(v.translation.width, v.translation.height) > 12
        if let id = grabbed {
            if p.x < -10 || p.x > 610 || p.y < -10 || p.y > 610 {
                treat.toppings.removeAll { $0.id == id }
                Sound.shared.play(.whoosh, volume: 0.6)
            } else if !moved {
                Sound.shared.play(.boing, volume: 0.5)
                born[id] = Date().addingTimeInterval(-0.18)
            } else {
                BakerySound.shared.play(.plop, volume: 0.6)
            }
        } else if !moved {
            if selected.hasPrefix("bit_") {
                scatter(selected, around: p, radius: 60, count: 10)
            } else {
                place(selected, at: p)
            }
        }
        grabbed = nil
        dragStart = nil
    }

    private func hitTest(_ p: CGPoint) -> UUID? {
        for tp in treat.toppings.reversed() {
            let r: CGFloat = (tp.sprite.hasPrefix("bit_") ? 22 : 46) * CGFloat(tp.scale)
            if hypot(CGFloat(tp.x) - p.x, CGFloat(tp.y) - p.y) < r { return tp.id }
        }
        return nil
    }

    // MARK: Adding

    private func colorFor(_ sprite: String) -> Int {
        if let c = colorPick { return c }
        return Int.random(in: 0..<BakeryPalette.candy.count)
    }

    private func place(_ sprite: String, at p: CGPoint) {
        guard treat.toppings.count < DecorateStepView.maxToppings else { return }
        let upright = ["top_candle", "top_cane", "top_lollipop", "top_horn", "top_crown", "top_wafer"].contains(sprite)
        let tp = PlacedTopping(sprite: sprite, x: Double(p.x), y: Double(p.y),
                               rot: upright ? Double.random(in: -6...6) : Double.random(in: -18...18),
                               scale: Double.random(in: 0.92...1.05), color: colorFor(sprite))
        treat.toppings.append(tp)
        born[tp.id] = Date()
        history.append([tp.id])
        Sound.shared.play(.pop, volume: 0.8)
        Sound.shared.tap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { bounceOnce($bounce) }
        tidyBorn()
    }

    private func scatter(_ sprite: String, around center: CGPoint?, radius: CGFloat, count: Int) {
        var ids: [UUID] = []
        for _ in 0..<count {
            guard treat.toppings.count < DecorateStepView.maxToppings else { break }
            var p: CGPoint
            if let c = center {
                let a = CGFloat.random(in: 0...(2 * .pi)), r = radius * sqrt(CGFloat.random(in: 0...1))
                p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r * 0.6)
            } else {
                p = TreatPainter.randomSpot(on: treat)
            }
            let tp = PlacedTopping(sprite: sprite, x: Double(p.x), y: Double(p.y), rot: Double.random(in: 0...360),
                                   scale: Double.random(in: 0.85...1.15),
                                   color: sprite == "bit_curl" ? 0 : colorFor(sprite))
            treat.toppings.append(tp)
            born[tp.id] = Date().addingTimeInterval(-Double.random(in: 0...0.12))
            ids.append(tp.id)
        }
        guard !ids.isEmpty else { return }
        history.append(ids)
        BakerySound.shared.play(.shake)
        Sound.shared.tap()
        shakerAt = KStage.design(CGPoint(x: (center?.x ?? 300) + 30, y: (center?.y ?? TreatPainter.topY(treat)) - 120))
        withAnimation(.spring(response: 0.25)) { shaker = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation(.easeOut(duration: 0.2)) { shaker = false } }
        tidyBorn()
    }

    private func tidyBorn() {
        let now = Date()
        born = born.filter { now.timeIntervalSince($0.value) < 1.5 }
    }

    private func tapTray(_ item: String) {
        if item.hasPrefix("*") {
            selected = "bit_" + item.dropFirst()
            scatter(selected, around: nil, radius: 0, count: 20)
        } else {
            selected = "top_" + item
            place(selected, at: TreatPainter.randomSpot(on: treat))
        }
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        Sound.shared.play(.whoosh, volume: 0.6)
        Sound.shared.tap()
        let set = Set(last)
        withAnimation(.easeOut(duration: 0.2)) { treat.toppings.removeAll { set.contains($0.id) } }
    }

    private func clearAll() {
        guard !treat.toppings.isEmpty else { return }
        Sound.shared.play(.whoosh)
        Sound.shared.tap()
        withAnimation(.easeOut(duration: 0.2)) { treat.toppings = [] }
        history = []
        bounceOnce($bounce)
    }

    // MARK: Tray

    private var trayPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(BakeryPalette.trays.enumerated()), id: \.offset) { i, t in
                    Button {
                        Sound.shared.play(.flip, volume: 0.7)
                        Sound.shared.tap()
                        tray = i
                    } label: {
                        Group {
                            if t.icon.hasPrefix("bit_") { BitsIcon(sprite: t.icon) } else { Sprite(t.icon, color: BakeryPalette.candy[0], box: Box.topping) }
                        }
                        .padding(9)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(tray == i ? Theme.blush : Color(hex: 0xFFF7F2)))
                        .overlay(Circle().stroke(tray == i ? Theme.pink : .clear, lineWidth: 4))
                    }
                    .buttonStyle(Squish())
                }
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(86), spacing: 10), count: 3), spacing: 10) {
                    ForEach(BakeryPalette.trays[min(tray, BakeryPalette.trays.count - 1)].items, id: \.self) { item in
                        let sprite = item.hasPrefix("*") ? "bit_" + item.dropFirst() : "top_" + item
                        Button { tapTray(item) } label: {
                            Group {
                                if item.hasPrefix("*") { BitsIcon(sprite: sprite) }
                                else { Sprite(sprite, color: BakeryPalette.candy[colorPick ?? 0], box: Box.topping) }
                            }
                            .padding(10)
                            .frame(width: 86, height: 86)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(hex: 0xFFF7F2)))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(selected == sprite ? Theme.pink : Theme.blush, lineWidth: selected == sprite ? 5 : 3))
                        }
                        .buttonStyle(Squish())
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(height: 400)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 7), spacing: 6) {
                Button { Sound.shared.play(.sparkle, volume: 0.5); colorPick = nil } label: {
                    Circle()
                        .fill(AngularGradient(colors: [Theme.pink, Theme.lemon, Theme.mint, Theme.sky, Theme.lilac, Theme.pink], center: .center))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(colorPick == nil ? Theme.ink : .white, lineWidth: 3))
                }
                ForEach(0..<BakeryPalette.candy.count, id: \.self) { i in
                    Button { Sound.shared.play(.tap); colorPick = i } label: {
                        Circle().fill(BakeryPalette.candy[i].color)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(colorPick == i ? Theme.ink : Theme.blush, lineWidth: 3))
                    }
                }
            }
            HStack(spacing: 20) {
                RoundButton(symbol: "arrow.uturn.backward", tint: Color(hex: 0x9B79E0), size: 64) { undo() }
                RoundButton(symbol: "trash.fill", tint: Color(hex: 0xF45C9A), size: 64) { clearAll() }
            }
        }
        .padding(16)
        .frame(width: 330, height: 690)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Color.white.opacity(0.94)))
        .shadow(color: Theme.ink.opacity(0.18), radius: 12, y: 6)
    }
}

/// A little cluster of sprinkles for the tray.
struct BitsIcon: View {
    let sprite: String
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            BakeryArt.fit(&g, box: CGRect(x: -40, y: -40, width: 80, height: 80), into: size)
            let spots: [(CGFloat, CGFloat, Double)] = [(-22, -18, 20), (8, -24, 110), (24, 2, 60), (-6, 2, 150),
                                                        (-26, 16, 80), (10, 22, 30), (28, -22, 170), (-12, -30, 45)]
            for (i, s) in spots.enumerated() {
                BakeryArt.shared.draw(sprite, BakeryPalette.candy[(i * 5) % BakeryPalette.candy.count],
                                      at: CGPoint(x: s.0, y: s.1), scale: 1.2, rotation: s.2, in: g)
            }
        }
    }
}

extension Color {
    /// Rough RGB for tinting a sprite with a theme color.
    var rgbApprox: RGB {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        u.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGB(Double(r), Double(g), Double(b))
    }
}
