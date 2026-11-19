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

    @State private var added: [String] = []
    @State private var flying: String?
    @State private var flyAt = CGPoint.zero
    @State private var flySpin = 0.0
    @State private var picked = false
    @State private var stir: CGFloat = 0
    @State private var lastDrag: CGPoint?
    @State private var spoon: CGPoint?
    @State private var wobble = false
    @State private var burst = 0
    @State private var swishAcc: CGFloat = 0
    @State private var hint = false

    private var progress: CGFloat { min(1, stir / 2600) }
    private var allIn: Bool { added.count == MixStepView.ingredients.count }

    var body: some View {
        ZStack {
            BowlView(added: added, flavor: picked ? treat.flavor : nil, progress: progress, swirl: stir)
                .frame(width: bowlSize.width, height: bowlSize.height)
                .contentShape(Rectangle())
                .gesture(stirGesture)
                .scaleEffect(wobble ? 1.05 : 1)
                .position(bowlCenter)

            if allIn && picked && !done && spoon == nil {
                WoodSpoon()
                    .scaleEffect(0.9)
                    .offset(x: hint ? 90 : -90, y: hint ? -60 : -110)
                    .position(bowlCenter)
                    .opacity(0.9)
                    .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { hint = true } }
            }
            if let s = spoon { WoodSpoon().position(x: s.x + 20, y: s.y - 30) }
            if burst > 0 { SparkleBurst(count: 16, radius: 260).id(burst).position(x: bowlCenter.x, y: bowlCenter.y - 80) }

            if !allIn {
                ForEach(Array(MixStepView.ingredients.enumerated()), id: \.offset) { i, name in
                    if !added.contains(name) && flying != name {
                        PickPlate(selected: false, size: 118, tap: { drop(name, from: MixStepView.slots[i]) }) {
                            Sprite(name, box: Box.thing).padding(8)
                        }
                        .position(MixStepView.slots[i])
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            } else {
                ForEach(0..<BakeryPalette.flavors.count, id: \.self) { i in
                    PickPlate(selected: picked && treat.flavor == i, size: 96, tap: { pick(i) }) {
                        FlavorJar(sprite: "bottle", flavor: i).padding(6)
                    }
                    .position(gridSpot(i, cols: 4, x0: 660, y0: 250, dx: 108, dy: 150))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            if let f = flying {
                Sprite(f, box: Box.thing)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(flySpin))
                    .position(flyAt)
                    .allowsHitTesting(false)
            }
        }
    }

    private var stirGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard allIn && picked else { return }
                let p = v.location
                spoon = CGPoint(x: bowlCenter.x - bowlSize.width / 2 + p.x, y: bowlCenter.y - bowlSize.height / 2 + p.y)
                if let l = lastDrag {
                    let d = hypot(p.x - l.x, p.y - l.y)
                    stir += d
                    swishAcc += d
                    if swishAcc > 280 {
                        swishAcc = 0
                        BakerySound.shared.play(.swish, volume: 0.8)
                        Sound.shared.tap()
                    }
                    if progress >= 1 && !done { finish() }
                }
                lastDrag = p
            }
            .onEnded { _ in lastDrag = nil; spoon = nil }
    }

    private func drop(_ name: String, from p: CGPoint) {
        guard flying == nil else { return }
        Sound.shared.play(.pop, volume: 0.7)
        Sound.shared.tap()
        flying = name
        flyAt = p
        flySpin = 0
        withAnimation(.easeIn(duration: 0.45)) {
            flyAt = CGPoint(x: bowlCenter.x + CGFloat.random(in: -40...40), y: bowlCenter.y - 130)
            flySpin = name == "eggs" ? -50 : -25
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            flying = nil
            withAnimation(.spring(response: 0.3)) { added.append(name) }
            if name == "eggs" { Sound.shared.play(.crack, volume: 0.8) }
            BakerySound.shared.play(.plop)
            bounceOnce($wobble)
            if added.count == MixStepView.ingredients.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Sound.shared.play(.sparkle, volume: 0.7) }
            }
        }
    }

    private func pick(_ i: Int) {
        Sound.shared.tap()
        BakerySound.shared.play(.pour, volume: 0.7)
        withAnimation(.easeInOut(duration: 0.4)) {
            treat.flavor = i
            picked = true
        }
        bounceOnce($wobble)
        if done { burst += 1 }
    }

    private func finish() {
        withAnimation(.spring()) { done = true }
        burst += 1
        BakerySound.shared.play(.magic)
        Sound.shared.play(.sparkle, volume: 0.8)
    }
}

struct BowlView: View {
    let added: [String]
    let flavor: Int?
    let progress: CGFloat
    let swirl: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            BakeryArt.fit(&g, box: Box.bowl, into: size)
            let art = BakeryArt.shared
            art.draw("bowl_back", in: g)
            if !added.isEmpty {
                let base = RGB(hex: "#FFF6E8")
                var col = base
                if let f = flavor { col = base.mix(BakeryPalette.flavors[f].color, 0.35 + 0.65 * Double(progress)) }
                var b = g
                b.opacity = 0.35 + 0.65 * Double(added.count) / 5
                art.draw("batter", col, in: b)
                var l = g
                l.opacity = Double(1 - progress)
                for a in added { art.draw("lump_\(a)", in: l) }
                if progress > 0 && progress < 1 {
                    var sp = Path()
                    for k in 0...48 {
                        let t = CGFloat(k) / 48
                        let a = t * 4 * .pi + swirl * 0.012
                        let r = 16 + t * 124
                        let pt = CGPoint(x: 200 + cos(a) * r, y: 120 + sin(a) * r * 0.2)
                        if k == 0 { sp.move(to: pt) } else { sp.addLine(to: pt) }
                    }
                    g.stroke(sp, with: .color(Shades.shade(col).color.opacity(0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
            }
            art.draw("bowl_front", in: g)
        }
    }
}

// MARK: - Pour and bake

struct BakeStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool

    private enum Phase { case choose, pour, ready, baking, done }
    @State private var phase: Phase = .choose
    @State private var tilt = false
    @State private var pouring = false
    @State private var fill: CGFloat = 0
    @State private var bowlGone = false
    @State private var panPos = CGPoint(x: 800, y: 650)
    @State private var panScale: CGFloat = 1
    @State private var panHidden = false
    @State private var rise: CGFloat = 0
    @State private var dial = 0.0
    @State private var glow = false
    @State private var burst = 0
    @State private var nudge = false
    @State private var steam = false

    private let ovenC = CGPoint(x: 320, y: 500)
    private let windowC = CGPoint(x: 320, y: 540)
    private let panSpot = CGPoint(x: 800, y: 650)

    var body: some View {
        ZStack {
            Sprite("oven", box: Box.oven)
                .frame(width: 480, height: 460)
                .position(ovenC)
            if !panHidden {
                PanView(treat: treat, fill: fill, rise: rise)
                    .frame(width: 300, height: 190)
                    .scaleEffect(panScale)
                    .position(panPos)
            }
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFB35C), Color(hex: 0xFF6F5C)], startPoint: .top, endPoint: .bottom))
                .frame(width: 320, height: 200)
                .opacity(phase == .baking ? (glow ? 0.5 : 0.25) : 0)
                .position(windowC)
                .allowsHitTesting(false)
            Sprite("oven_glass", box: Box.oven)
                .frame(width: 480, height: 460)
                .position(ovenC)
                .allowsHitTesting(false)
            Sprite("dial", box: Box.oven)
                .frame(width: 480, height: 460)
                .rotationEffect(.degrees(dial), anchor: UnitPoint(x: 240.0 / 480, y: 64.0 / 460))
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
            case .pour: pourBowl
            default: EmptyView()
            }

            if phase == .done {
                ZStack {
                    TreatView(treat: treat)
                        .frame(width: 430, height: 430)
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(Color.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .offset(x: CGFloat(i - 1) * 60, y: steam ? -260 : -120)
                            .opacity(steam ? 0 : 0.9)
                            .animation(.easeOut(duration: 1.6).delay(Double(i) * 0.25).repeatForever(autoreverses: false), value: steam)
                    }
                    SparkleBurst(count: 16, radius: 240).id(burst)
                }
                .position(x: 790, y: 480)
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .onAppear { steam = true }
            }
        }
    }

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
                .position(gridSpot(i, cols: 3, x0: 690, y0: 230, dx: 118, dy: 118))
            }
        }
    }

    private var pourBowl: some View {
        ZStack {
            if pouring {
                Capsule()
                    .fill(BakeryPalette.flavors[treat.flavor].color.color)
                    .overlay(Capsule().stroke(Shades.outline(BakeryPalette.flavors[treat.flavor].color).color, lineWidth: 3))
                    .frame(width: 30, height: 150)
                    .position(x: panSpot.x - 10, y: panSpot.y - 120)
                    .transition(.opacity)
            }
            if !bowlGone {
                BowlView(added: MixStepView.ingredients, flavor: treat.flavor, progress: 1, swirl: 0)
                    .frame(width: 300, height: 225)
                    .rotationEffect(.degrees(tilt ? -48 : 0), anchor: .bottomLeading)
                    .position(x: panSpot.x + 70, y: panSpot.y - 250)
                    .onTapGesture(perform: pour)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private func chooseTiers(_ n: Int) {
        Sound.shared.play(.pop)
        Sound.shared.tap()
        treat.tiers = n
        withAnimation(.spring(response: 0.4)) { phase = .pour }
    }

    private func chooseLiner(_ i: Int) {
        Sound.shared.play(.pop)
        Sound.shared.tap()
        treat.liner = i
        withAnimation(.spring(response: 0.4)) { phase = .pour }
    }

    private func pour() {
        guard phase == .pour, !pouring, fill == 0 else { return }
        Sound.shared.tap()
        BakerySound.shared.play(.pour)
        withAnimation(.easeInOut(duration: 0.35)) { tilt = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.15)) { pouring = true }
            withAnimation(.easeInOut(duration: 1.3)) { fill = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.2)) { pouring = false }
            withAnimation(.easeInOut(duration: 0.3)) { tilt = false }
            BakerySound.shared.play(.plop)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeIn(duration: 0.35)) { bowlGone = true }
            Sound.shared.play(.whoosh, volume: 0.6)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                panPos = CGPoint(x: windowC.x, y: windowC.y + 10)
                panScale = 0.85
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) {
            withAnimation(.spring()) { phase = .ready }
        }
    }

    private func bake() {
        phase = .baking
        Sound.shared.tap()
        Sound.shared.play(.boing, volume: 0.5)
        BakerySound.shared.play(.oven, volume: 0.8)
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { glow = true }
        withAnimation(.linear(duration: 3.6)) { dial = 360; rise = 1 }
        for k in 0..<12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(k) * 0.3) { BakerySound.shared.play(.tick, volume: 0.7) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { BakerySound.shared.play(.oven, volume: 0.6) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            Sound.shared.play(.ding)
            BakerySound.shared.play(.magic, volume: 0.8)
            Sound.shared.tap()
            withAnimation(.easeOut(duration: 0.3)) { glow = false; panHidden = true }
            burst += 1
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { phase = .done; done = true }
        }
    }
}

/// The pan (cake) or paper liner (cupcake) with batter that fills and rises.
struct PanView: View {
    let treat: Treat
    let fill: CGFloat
    let rise: CGFloat

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            BakeryArt.fit(&g, box: CGRect(x: 0, y: 0, width: 300, height: 190), into: size)
            let art = BakeryArt.shared
            let flavor = BakeryPalette.flavors[max(0, min(BakeryPalette.flavors.count - 1, treat.flavor))].color
            if treat.kind == .cake {
                var p = g
                p.translateBy(x: 0, y: 40)
                art.draw("pan", in: p)
                let rim: CGFloat = 110
                if fill > 0 {
                    let r = CGRect(x: 150 - 128 * fill, y: rim - 26 * fill, width: 256 * fill, height: 52 * fill)
                    g.fill(Path(ellipseIn: r), with: .color(flavor.color))
                }
                if rise > 0 {
                    var d = g
                    d.clip(to: Path(CGRect(x: 0, y: 0, width: 300, height: rim + 2)))
                    let h = 26 + rise * 64
                    let r = CGRect(x: 22, y: rim - h, width: 256, height: h * 2)
                    d.fill(Path(ellipseIn: r), with: .color(Shades.shade(flavor).mix(flavor, Double(rise)).color))
                    d.stroke(Path(ellipseIn: r), with: .color(Shades.outline(flavor).color), lineWidth: 4)
                    d.fill(Path(ellipseIn: CGRect(x: 70, y: rim - h + 12, width: 60, height: 14)), with: .color(.white.opacity(0.35)))
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
                    let r = CGRect(x: 300 - 120 * fill, y: top - 12 * fill, width: 240 * fill, height: 24 * fill)
                    s.fill(Path(ellipseIn: r), with: .color(flavor.color))
                }
                if rise > 0 {
                    var d = s
                    d.translateBy(x: 0, y: top)
                    d.scaleBy(x: 1, y: max(0.05, rise))
                    d.translateBy(x: 0, y: -top)
                    art.draw("cupcake_top", flavor, in: d)
                }
                art.draw("liner", BakeryPalette.liners[max(0, min(BakeryPalette.liners.count - 1, treat.liner))], in: s)
            }
        }
    }
}

// MARK: - Frost

struct FrostStepView: View {
    @Binding var treat: Treat
    @Binding var done: Bool

    @State private var strokes: [CGPoint] = []
    @State private var covered = Set<Int>()
    @State private var full = false
    @State private var bag: CGPoint?
    @State private var squish = false
    @State private var burst = 0
    @State private var squeezeAcc: CGFloat = 0
    @State private var samples: [CGPoint] = []
    @State private var hint = false

    private static let brush: CGFloat = 52

    var body: some View {
        ZStack {
            if treat.kind == .cake { cakeStage } else { cupcakeStage }
            if burst > 0 { SparkleBurst(count: 16, radius: 260).id(burst).position(x: KStage.center.x, y: KStage.center.y - 60) }
            if let b = bag {
                Sprite("pipingbag", color: TreatPainter.frosting(treat.frosting ?? 0), box: Box.thing)
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-20))
                    .position(x: b.x + 40, y: b.y - 70)
                    .allowsHitTesting(false)
            } else if !done {
                Sprite("pipingbag", color: TreatPainter.frosting(treat.frosting ?? 0), box: Box.thing)
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-20))
                    .offset(x: hint ? 70 : -70, y: hint ? -10 : 10)
                    .position(x: KStage.center.x + 40, y: KStage.center.y - 190)
                    .opacity(0.9)
                    .allowsHitTesting(false)
                    .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { hint = true } }
            }
            picker
        }
        .onAppear {
            if treat.frosting == nil { treat.frosting = 2 }
            if treat.kind == .cake { samples = FrostStepView.makeSamples(tiers: treat.tiers) }
            if treat.kind == .cupcake && treat.frostStage > 0 { done = true }
        }
    }

    private var cakeStage: some View {
        let reveal: Path? = full ? nil : revealPath
        let t = treat
        return Canvas { ctx, size in
            var g = ctx
            BakeryArt.fit(&g, box: Box.stage, into: size)
            TreatPainter.draw(t, in: g, frostReveal: reveal)
        }
        .frame(width: KStage.size, height: KStage.size)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in spread(at: v.location) }
            .onEnded { _ in bag = nil })
        .scaleEffect(x: squish ? 1.04 : 1, y: squish ? 0.96 : 1, anchor: .bottom)
        .position(KStage.center)
    }

    private var cupcakeStage: some View {
        TreatView(treat: treat)
            .frame(width: KStage.size, height: KStage.size)
            .contentShape(Rectangle())
            .onTapGesture { squeeze() }
            .scaleEffect(x: squish ? 1.07 : 1, y: squish ? 0.93 : 1, anchor: .bottom)
            .position(KStage.center)
    }

    private var revealPath: Path {
        var p = Path()
        let r = FrostStepView.brush
        for s in strokes { p.addEllipse(in: CGRect(x: s.x - r, y: s.y - r, width: r * 2, height: r * 2)) }
        return p
    }

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
        guard !full else { return }
        bag = CGPoint(x: KStage.center.x - KStage.size / 2 + loc.x, y: KStage.center.y - KStage.size / 2 + loc.y)
        let p = CGPoint(x: loc.x / KStage.k, y: loc.y / KStage.k)
        if let l = strokes.last {
            let d = hypot(p.x - l.x, p.y - l.y)
            guard d > 9 else { return }
            squeezeAcc += d
        }
        strokes.append(p)
        let r = FrostStepView.brush
        for (i, s) in samples.enumerated() where !covered.contains(i) {
            if hypot(s.x - p.x, s.y - p.y) < r { covered.insert(i) }
        }
        if squeezeAcc > 220 {
            squeezeAcc = 0
            BakerySound.shared.play(.squeeze, volume: 0.6)
            Sound.shared.tap()
        }
        if !samples.isEmpty && Double(covered.count) / Double(samples.count) > 0.72 {
            full = true
            bag = nil
            burst += 1
            BakerySound.shared.play(.magic)
            Sound.shared.play(.sparkle, volume: 0.8)
            bounceOnce($squish)
            withAnimation(.spring()) { done = true }
        }
    }

    private func squeeze() {
        guard treat.frostStage < 3 else {
            Sound.shared.play(.boing, volume: 0.5)
            bounceOnce($squish)
            return
        }
        BakerySound.shared.play(.squeeze)
        Sound.shared.tap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { treat.frostStage += 1 }
        bounceOnce($squish)
        if treat.frostStage == 3 {
            burst += 1
            Sound.shared.play(.sparkle, volume: 0.8)
        }
        withAnimation(.spring()) { done = true }
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

    var body: some View {
        ZStack {
            StageTreat(treat: treat, bounce: bounce)
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
        .onAppear { done = true }
    }

    private func pick(_ i: Int?) {
        Sound.shared.tap()
        if i != nil { BakerySound.shared.play(.drizzle) } else { Sound.shared.play(.whoosh, volume: 0.5) }
        withAnimation(.spring(response: 0.3)) { treat.sauce = i }
        bounceOnce($bounce)
        if i != nil { burst += 1 }
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
