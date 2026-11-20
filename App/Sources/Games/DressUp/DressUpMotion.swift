import SwiftUI

// MARK: - Dress Up: a doll that moves like she's wearing real clothes
//
// The stage doll is drawn every frame. Skirts, dresses and capes swing from the waist (or shoulders)
// like fabric: the hem trails behind the waist, flares out when she hops and settles back. Long
// hair swings from below the chin. Fairy wings flutter. Satin catches a moving sheen, and sparkly
// things (crowns, wands, glitter, gems, pearls, star dresses) twinkle in place. Swipe across her
// and her skirt and hair swish the way your finger went. Some scenes are alive too: stars twinkle
// at night, snow falls, bubbles rise under the sea, petals and leaves drift down.
//
// Fabric is bent by cutting the item into thin horizontal bands and sliding each band sideways
// (a skew that is zero at the waist, so nothing tears), with a little extra width toward the hem.

/// A damped spring: `x` chases a target.
struct DollSpring {
    var x = 0.0
    var v = 0.0
    mutating func step(to target: Double, k: Double, damping: Double, dt: Double) {
        v += ((target - x) * k - v * damping) * dt
        x += v * dt
    }
}

final class DollMotion {
    /// Skirt lean at the waist (`a`) and at the hem (`b`, which trails behind `a`), as sideways
    /// offset per unit of fabric length.
    var skirtA = DollSpring(), skirtB = DollSpring()
    var hairA = DollSpring(), hairB = DollSpring()
    /// How much the hem widens (0 = hangs straight).
    var flare = DollSpring()
    private var last: Double?
    private var lastDrag: (p: CGPoint, t: Double)?
    var windy = false

    /// A hop: the skirt puffs out and swings a little.
    func hop() {
        flare.v += 2.6
        let side = Bool.random() ? 1.0 : -1.0
        skirtA.v += 0.35 * side
        hairA.v += 0.25 * side
    }

    /// Something new went on: a small swish.
    func swish() {
        let side = Bool.random() ? 1.0 : -1.0
        skirtA.v += 0.5 * side
        hairA.v += 0.3 * side
        flare.v += 0.8
    }

    /// Her finger is sweeping across the doll at `p` (screen points).
    func drag(_ p: CGPoint) {
        let t = Date().timeIntervalSinceReferenceDate
        if let l = lastDrag, t - l.t > 0.001, t - l.t < 0.2 {
            let vx = Double(p.x - l.p.x) / (t - l.t)
            skirtA.v += max(-0.5, min(0.5, vx * 0.00022))
            hairA.v += max(-0.4, min(0.4, vx * 0.00016))
        }
        lastDrag = (p, t)
    }

    func endDrag() { lastDrag = nil }

    // MARK: Dancing

    /// A little dance: 0 sway, 1 hop-hop, 2 twirl, 3 wiggle. Lasts `danceLength` seconds.
    private(set) var dance: (start: Double, style: Int)?
    static let danceLength = 4.8

    func startDance(at t: Double) {
        let style = ((dance?.style ?? -1) + 1 + Int.random(in: 0...2)) % 4
        dance = (t, style)
        flare.v += 2
    }

    var dancing: Bool { dance != nil }

    /// Sideways shift, lift, lean (degrees) and mirror (1 ... -1) at time `t`.
    func danceMove(_ t: Double) -> (dx: CGFloat, dy: CGFloat, lean: Double, flip: CGFloat) {
        guard let d = dance else { return (0, 0, 0, 1) }
        let u = t - d.start
        if u > Self.danceLength { dance = nil; return (0, 0, 0, 1) }
        let fade = max(0, min(1, u * 3, (Self.danceLength - u) * 3))
        let beat = u * 2 * .pi * 1.25
        switch d.style {
        case 0:
            return (CGFloat(18 * sin(beat / 2) * fade), CGFloat(-8 * abs(sin(beat)) * fade), 7 * sin(beat / 2) * fade, 1)
        case 1:
            return (CGFloat(10 * sin(beat / 2) * fade), CGFloat(-46 * abs(sin(beat)) * fade), 3 * sin(beat) * fade, 1)
        case 2:
            let spin = cos(min(1, max(0, (u - 1) / 1.6)) * 4 * .pi)
            return (0, CGFloat(-18 * abs(sin(beat)) * fade), 0, CGFloat(spin))
        default:
            return (CGFloat(14 * sin(beat * 1.5) * fade), CGFloat(-6 * abs(sin(beat * 1.5)) * fade), 4 * sin(beat * 1.5) * fade, 1)
        }
    }

    func step(to t: Double) {
        let dt = min(0.05, max(0, t - (last ?? t)))
        last = t
        guard dt > 0 else { return }
        let gust = windy ? 2.2 : 1.0
        var breeze = (0.010 * sin(t * 1.1) + 0.005 * sin(t * 2.3 + 1)) * gust
        if let d = dance {
            // her skirt swings with the music
            breeze += 0.13 * sin((t - d.start) * .pi * 1.25)
        }
        // small steps keep the springs steady even if a frame comes late
        let n = Int(ceil(dt / 0.008))
        let h = dt / Double(n)
        for _ in 0..<n {
            skirtA.step(to: breeze, k: 55, damping: 4.2, dt: h)
            skirtB.step(to: skirtA.x, k: 38, damping: 3.6, dt: h)
            hairA.step(to: breeze * 0.7, k: 42, damping: 4.0, dt: h)
            hairB.step(to: hairA.x, k: 26, damping: 3.2, dt: h)
            flare.step(to: 0.012 * sin(t * 1.7), k: 110, damping: 7, dt: h)
        }
        skirtA.x = max(-0.22, min(0.22, skirtA.x))
        skirtB.x = max(-0.3, min(0.3, skirtB.x))
        hairA.x = max(-0.16, min(0.16, hairA.x))
        hairB.x = max(-0.22, min(0.22, hairB.x))
        flare.x = max(-0.06, min(0.3, flare.x))
    }
}

/// How one kind of item bends.
private struct Sway {
    let pivot: CGFloat
    let length: CGFloat
    let a: Double
    let b: Double
    let flare: Double

    /// Sideways offset at height `y`.
    func offset(_ y: CGFloat) -> CGFloat {
        let d = max(0, y - pivot)
        let u = d / length
        return d * CGFloat(a) + d * u * CGFloat(b - a)
    }

    func scale(_ y: CGFloat) -> CGFloat { 1 + CGFloat(flare) * max(0, y - pivot) / length }

    func move(_ p: CGPoint) -> CGPoint {
        CGPoint(x: 300 + (p.x - 300) * scale(p.y) + offset(p.y), y: p.y)
    }
}

enum LiveDollPainter {
    static let sparkly: Set<String> = [
        "h_crown", "h_tiara", "h_starcrown", "h_halo", "h_unicorn", "p_wand", "d_magic", "d_star", "d_gown", "d_mermaid",
        "d_ballerina", "d_princess", "sh_glitter", "mk_glitter", "mk_gems", "er_pearl", "er_star", "er_drop", "n_pearls",
        "n_star", "n_heart", "w_fairy", "w_angel", "w_butterfly", "g_star", "p_bubbles",
    ]
    /// Bottoms with legs in them don't swing.
    static let stiff: Set<String> = ["b_shorts", "b_pants", "b_leggings", "b_overalls"]
    static let wings: Set<String> = ["w_fairy", "w_angel", "w_butterfly", "w_bat"]
    static let satin: Set<String> = ["dress", "bottom"]

    private static var points: [String: [CGPoint]] = [:]
    private static var fabric: [String: (Path, CGRect)] = [:]

    private static func sway(for item: ArtItem, _ m: DollMotion) -> Sway? {
        switch item.category {
        case "dress":
            return Sway(pivot: 518, length: 200, a: m.skirtA.x, b: m.skirtB.x, flare: m.flare.x)
        case "bottom" where !stiff.contains(item.id):
            return Sway(pivot: 518, length: 180, a: m.skirtA.x, b: m.skirtB.x, flare: m.flare.x)
        case "outer" where item.id == "o_cape", "back" where item.id == "w_cape":
            return Sway(pivot: 450, length: 300, a: m.skirtA.x * 0.7, b: m.skirtB.x * 0.8, flare: m.flare.x * 0.5)
        case "hairBack":
            return Sway(pivot: 432, length: 300, a: m.hairA.x, b: m.hairB.x, flare: m.flare.x * 0.25)
        default:
            return nil
        }
    }

    /// Paints the whole doll, alive, at time `t`.
    static func paint(_ look: Look, _ expression: Expression, motion m: DollMotion, t: Double, box: CGRect,
                      in ctx: inout GraphicsContext, size: CGSize) {
        let art = DressUpArt.shared
        ArtPainter.fit(&ctx, box: box, into: size)
        // a breath: she grows a touch taller and back, from the feet
        var g = ctx
        let breath = 1 + 0.005 * CGFloat(sin(t * 2.1))
        let mv = m.danceMove(t)
        g.translateBy(x: 300 + mv.dx, y: 730 + mv.dy)
        if mv.lean != 0 { g.rotate(by: .degrees(mv.lean)) }
        g.scaleBy(x: mv.flip, y: breath)
        g.translateBy(x: -300, y: -730)

        for (layer, p, item) in DollPainter.layers(look, expression, art: art) {
            let extras: (GraphicsContext) -> Void = { c in
                if satin.contains(item.category) && !stiff.contains(item.id) { sheen(item, layer, p, t: t, in: c) }
                if sparkly.contains(item.id) { twinkles(item, t: t, in: c) }
            }
            if let s = sway(for: item, m) {
                drawSwaying(layer.shapes, p, s, in: g, extras: extras)
            } else if wings.contains(item.id) {
                var w = g
                let speed = item.id == "w_butterfly" ? 7.0 : 4.5
                let flap = CGFloat(sin(t * speed))
                w.translateBy(x: 300, y: 470)
                w.scaleBy(x: 1 + 0.06 * flap, y: 1 - 0.015 * flap)
                w.translateBy(x: -300, y: -470 - 3 * flap)
                ArtPainter.draw(layer.shapes, p, in: w)
                extras(w)
            } else {
                ArtPainter.draw(layer.shapes, p, in: g)
                extras(g)
            }
        }
        if let pet = look.pet {
            // her pet breathes too, and blinks now and then
            var pose = PetPose()
            pose.squash = 1 + 0.012 * CGFloat(sin(t * 2.6 + 1))
            pose.flap = CGFloat(sin(t * 5))
            pose.time = t
            if (t + 0.7).truncatingRemainder(dividingBy: 4.3) < 0.14 { pose.eyes = "blink" }
            if expression == .happy { pose.eyes = "happy"; pose.mouth = "grin" }
            var pc = ctx
            if m.dancing {
                // her pet dances along: bouncing a beat behind her
                let mv = m.danceMove(t - 0.18)
                pc.translateBy(x: -mv.dx * 0.6, y: mv.dy * 0.7)
                pose.squash = 1 + 0.08 * CGFloat(sin(t * 2 * .pi * 2.5))
                pose.tilt = -mv.lean * 1.4
                pose.eyes = "happy"; pose.mouth = "grin"
            }
            PetPainter.drawCompanion(pet, pose: pose, in: pc)
        }
    }

    /// Draws `shapes` bent by `s`: untouched above the pivot, in sliding bands below it.
    private static func drawSwaying(_ shapes: [ArtShape], _ p: PaintSet, _ s: Sway, in ctx: GraphicsContext,
                                    extras: (GraphicsContext) -> Void) {
        let bottom = shapes.reduce(s.pivot) { max($0, $1.bounds.maxY + $1.width) }
        var top = ctx
        top.clip(to: Path(CGRect(x: -1000, y: -1000, width: 3000, height: s.pivot + 1000.5)))
        let above = shapes.filter { $0.bounds.minY - $0.width < s.pivot }
        ArtPainter.draw(above, p, in: top)
        extras(top)
        guard bottom > s.pivot + 1 else { return }
        let bands = max(4, min(14, Int((bottom - s.pivot) / 16)))
        let h = (bottom - s.pivot) / CGFloat(bands)
        for j in 0..<bands {
            let y0 = s.pivot + CGFloat(j) * h
            let y1 = y0 + h
            let o0 = s.offset(y0), o1 = s.offset(y1)
            let k = (o1 - o0) / h
            let sc = s.scale((y0 + y1) / 2)
            var g = ctx
            g.clip(to: Path(CGRect(x: -1000, y: y0, width: 3000, height: h + 0.6)))
            g.concatenate(CGAffineTransform(a: sc, b: 0, c: k, d: 1, tx: 300 - 300 * sc + o0 - k * y0, ty: 0))
            let inBand = shapes.filter { $0.bounds.maxY + $0.width >= y0 && $0.bounds.minY - $0.width <= y1 }
            ArtPainter.draw(inBand, p, in: g)
            extras(g)
        }
    }

    /// A soft band of light that slides across satin every few seconds.
    private static func sheen(_ item: ArtItem, _ layer: ArtLayer, _ p: PaintSet, t: Double, in ctx: GraphicsContext) {
        let key = "\(item.id).\(layer.z)"
        let entry: (Path, CGRect)
        if let e = fabric[key] {
            entry = e
        } else {
            var path = Path()
            for s in layer.shapes {
                if case .slot(.main, .base)? = s.fill { path.addPath(s.path) }
            }
            entry = (path, path.isEmpty ? .null : path.boundingRect)
            fabric[key] = entry
        }
        let (path, b) = entry
        guard !path.isEmpty, b.width > 10 else { return }
        let period = 5.0
        let seed = Double(abs(item.id.hashValue % 100)) / 100
        let k = ((t / period) + seed).truncatingRemainder(dividingBy: 1)
        guard k < 0.45 else { return }
        let u = CGFloat(k / 0.45)
        let x = b.minX - 120 + (b.width + 240) * u
        var g = ctx
        g.clip(to: path)
        g.blendMode = .plusLighter
        g.fill(Path(b.insetBy(dx: -40, dy: -40)), with: .linearGradient(
            Gradient(stops: [.init(color: .white.opacity(0), location: 0), .init(color: .white.opacity(0.28), location: 0.5),
                             .init(color: .white.opacity(0), location: 1)]),
            startPoint: CGPoint(x: x - 46, y: b.minY), endPoint: CGPoint(x: x + 46, y: b.minY + 36)))
    }

    /// Points inside the item where twinkles can appear.
    private static func spots(_ item: ArtItem) -> [CGPoint] {
        if let p = points[item.id] { return p }
        var fills: [Path] = []
        var box = CGRect.null
        for L in item.layers {
            for s in L.shapes where s.fill != nil || s.gradient != nil {
                fills.append(s.path)
                box = box.union(s.bounds)
            }
        }
        var out: [CGPoint] = []
        if !box.isNull && box.width > 0 && box.height > 0 {
            let step = max(6, sqrt(box.width * box.height / 90))
            var y = box.minY + step / 2
            var row = 0
            while y < box.maxY {
                var x = box.minX + step / 2 + (row % 2 == 0 ? 0 : step / 2)
                while x < box.maxX {
                    let q = CGPoint(x: x, y: y)
                    if fills.contains(where: { $0.contains(q) }) { out.append(q) }
                    x += step
                }
                y += step
                row += 1
            }
        }
        // shuffle the same way every time so twinkles hop around the item, not along it
        var g = SeededGenerator(seed: UInt64(abs(item.id.hashValue)))
        out.shuffle(using: &g)
        points[item.id] = out
        return out
    }

    private static func twinkles(_ item: ArtItem, t: Double, in ctx: GraphicsContext) {
        let list = spots(item)
        guard !list.isEmpty else { return }
        let count = min(list.count, item.category == "dress" ? 5 : 3)
        for k in 0..<count {
            let period = 1.3 + Double(k) * 0.37
            let phase = t / period + Double(k) * 0.61
            let cycle = Int(floor(phase))
            let u = phase - floor(phase)
            guard u < 0.6 else { continue }
            let life = sin(u / 0.6 * .pi)
            let q = list[abs(cycle &* 7 &+ k &* 13) % list.count]
            let r = CGFloat(5 + 5 * life) * (item.category == "dress" ? 1.2 : 1)
            var g = ctx
            g.translateBy(x: q.x, y: q.y)
            g.blendMode = .plusLighter
            let glow = r * 2.2
            g.fill(Path(ellipseIn: CGRect(x: -glow, y: -glow, width: glow * 2, height: glow * 2)),
                   with: .radialGradient(Gradient(colors: [.white.opacity(0.55 * life), .white.opacity(0)]),
                                         center: .zero, startRadius: 0, endRadius: glow))
            g.rotate(by: .degrees(u * 90))
            g.fill(Twinkle().path(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(.white.opacity(life)))
        }
    }
}

/// A tiny repeatable random generator (for twinkle spots).
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// The doll on the stage: drawn every frame so her clothes and hair can move.
struct LiveDollView: View {
    let look: Look
    var expression: Expression = .normal
    let box: CGRect
    let motion: DollMotion
    var windy = false

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                motion.windy = windy
                motion.step(to: t)
                var c = ctx
                LiveDollPainter.paint(look, expression, motion: motion, t: t, box: box, in: &c, size: size)
            }
        }
    }
}

// MARK: - Living scenes

/// Moving things in front of a scene: twinkling stars, falling snow, rising bubbles, drifting petals.
struct SceneLife: View {
    let bg: String

    private enum Kind { case stars, snow, bubbles, petals, leaves, none }
    private var kind: Kind {
        switch bg {
        case "bg_night", "bg_space", "bg_castle", "bg_stage", "bg_rainbow", "bg_candy": return .stars
        case "bg_snow": return .snow
        case "bg_sea", "bg_beach": return .bubbles
        case "bg_garden", "bg_park", "bg_sunset": return .petals
        case "bg_forest": return .leaves
        default: return .none
        }
    }

    var body: some View {
        if kind == .none {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                Canvas { ctx, size in draw(ctx, size: size, t: tl.date.timeIntervalSinceReferenceDate) }
            }
            .allowsHitTesting(false)
        }
    }

    private func rand(_ i: Int, _ salt: Int) -> CGFloat {
        var g = SeededGenerator(seed: UInt64(i &* 977 &+ salt &* 31 &+ 5))
        return CGFloat(Double(g.next() % 10_000) / 10_000)
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        switch kind {
        case .stars:
            let n = 26
            for i in 0..<n {
                let period = 1.6 + Double(rand(i, 1)) * 2.4
                let u = (t / period + Double(rand(i, 2))).truncatingRemainder(dividingBy: 1)
                let life = max(0, sin(u * .pi * 2)) // on half the time
                guard life > 0.02 else { continue }
                let x = rand(i, 3) * size.width
                let y = rand(i, 4) * size.height * (bg == "bg_space" || bg == "bg_night" ? 0.9 : 0.55)
                let r = (5 + rand(i, 5) * 9) * CGFloat(0.4 + 0.6 * life)
                var g = ctx
                g.translateBy(x: x, y: y)
                g.blendMode = .plusLighter
                let col: Color = i % 3 == 0 ? Color(hex: 0xFFF3B0) : .white
                g.fill(Path(ellipseIn: CGRect(x: -r * 2, y: -r * 2, width: r * 4, height: r * 4)),
                       with: .radialGradient(Gradient(colors: [col.opacity(0.5 * life), col.opacity(0)]), center: .zero, startRadius: 0, endRadius: r * 2))
                g.rotate(by: .degrees(t * 40 + Double(i) * 20))
                g.fill(Twinkle().path(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(col.opacity(life)))
            }
        case .snow:
            for i in 0..<70 {
                let speed = 30 + rand(i, 1) * 50
                let r = 2 + rand(i, 2) * 5
                let y = (rand(i, 3) * (size.height + 40) + CGFloat(t) * speed).truncatingRemainder(dividingBy: size.height + 40) - 20
                let x = rand(i, 4) * size.width + CGFloat(sin(t * 0.8 + Double(i))) * 18
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.9)))
            }
        case .bubbles:
            for i in 0..<16 {
                let speed = 40 + rand(i, 1) * 50
                let r = 5 + rand(i, 2) * 12
                let h = size.height + 60
                let y = h - (rand(i, 3) * h + CGFloat(t) * speed).truncatingRemainder(dividingBy: h) - 30
                let x = rand(i, 4) * size.width + CGFloat(sin(t * 1.6 + Double(i))) * 12
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.12)))
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)), lineWidth: 1.6)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.55, y: y - r * 0.6, width: r * 0.42, height: r * 0.3)), with: .color(.white.opacity(0.9)))
            }
        case .petals, .leaves:
            let leaves = kind == .leaves
            for i in 0..<(leaves ? 12 : 14) {
                let speed = 26 + rand(i, 1) * 34
                let h = size.height + 60
                let y = (rand(i, 3) * h + CGFloat(t) * speed).truncatingRemainder(dividingBy: h) - 30
                let x = (rand(i, 4) * size.width + CGFloat(t) * 14 + CGFloat(sin(t * 0.9 + Double(i))) * 40)
                    .truncatingRemainder(dividingBy: size.width + 40) - 20
                let s = 7 + rand(i, 2) * 6
                var g = ctx
                g.translateBy(x: x, y: y)
                g.rotate(by: .degrees(t * 60 * (i % 2 == 0 ? 1 : -1) + Double(i) * 33))
                // the flutter: it turns edge-on and back as it falls
                g.scaleBy(x: CGFloat(abs(cos(t * 2 + Double(i)))) * 0.8 + 0.2, y: 1)
                let petal = Path(ellipseIn: CGRect(x: -s, y: -s * 0.55, width: s * 2, height: s * 1.1))
                let col: Color = leaves ? [Color(hex: 0xF0A14A), Color(hex: 0xE2693E), Color(hex: 0x9CC55A)][i % 3]
                                        : [Color(hex: 0xFFC4DA), Color(hex: 0xFFFFFF), Color(hex: 0xFFE08A)][i % 3]
                g.fill(petal, with: .color(col.opacity(0.9)))
            }
        case .none:
            break
        }
    }
}

/// A burst of sparkles that really twinkle: they fly out turning, flaring and dimming. New `.id` to replay.
struct TwinkleBurst: View {
    var colors: [Color] = [.white, Theme.lemon, Theme.pink]
    var count = 14
    var radius: CGFloat = 180
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let age = tl.date.timeIntervalSince(start)
                guard age < 1.1 else { return }
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<count {
                    let a = Double(i) / Double(count) * 2 * .pi + Double(i % 3) * 0.2
                    let k = 1 - pow(1 - min(1, age / 0.9), 3)
                    let d = radius * CGFloat(k) * (0.7 + 0.15 * CGFloat(i % 3))
                    let flicker = 0.6 + 0.4 * abs(sin(age * 18 + Double(i)))
                    let fade = max(0, 1 - age / 1.1)
                    let r = CGFloat(9 + (i % 3) * 4) * CGFloat(flicker) * CGFloat(0.5 + fade * 0.6)
                    var g = ctx
                    g.translateBy(x: c.x + CGFloat(cos(a)) * d, y: c.y + CGFloat(sin(a)) * d)
                    g.opacity = fade
                    let col = colors[i % colors.count]
                    g.fill(Path(ellipseIn: CGRect(x: -r * 1.8, y: -r * 1.8, width: r * 3.6, height: r * 3.6)),
                           with: .radialGradient(Gradient(colors: [col.opacity(0.5), col.opacity(0)]), center: .zero, startRadius: 0, endRadius: r * 1.8))
                    g.rotate(by: .degrees(age * 220 + Double(i) * 25))
                    g.fill(Twinkle().path(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)), with: .color(col))
                }
            }
        }
        .frame(width: radius * 2 + 80, height: radius * 2 + 80)
        .allowsHitTesting(false)
    }
}
