import SwiftUI

// MARK: - The mixing bowl, simulated
//
// Ingredients pour out of their containers: flour as a powdery stream that piles up and puffs, sugar as
// glinting grains, eggs that crack and drop their yolks, milk as a liquid stream that rings the surface,
// butter that plops and squashes. Each one lands as soft blobs on the batter surface. The spoon drags,
// stretches and splits those blobs, so the colors marble into each other until the batter is one color.
//
// Everything is in the bowl's art coordinates (Box.bowl, 400 x 300). The batter surface is the ellipse
// centered at (200, 120) with radii 152 x 32; blobs live on it in "surface units" (the unit disk).

/// A stable pseudo-random number in 0..<1 for (i, salt).
func fxRand(_ i: Int, _ salt: Int) -> CGFloat {
    var x = UInt64(bitPattern: Int64((i &* 73_856_093) ^ (salt &* 19_349_663))) &+ 0x9E37_79B9_7F4A_7C15
    x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
    x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
    x ^= x >> 31
    return CGFloat(x % 100_000) / 100_000
}

/// 0...1 clamped smoothstep.
func fxEase(_ t: Double) -> CGFloat {
    let x = max(0, min(1, t))
    return CGFloat(x * x * (3 - 2 * x))
}

func fxClamp(_ t: Double) -> Double { max(0, min(1, t)) }

enum BowlGeo {
    static let center = CGPoint(x: 200, y: 120)
    static let rx: CGFloat = 152
    static let ry: CGFloat = 32
    static func art(_ uv: CGPoint) -> CGPoint { CGPoint(x: center.x + uv.x * rx, y: center.y + uv.y * ry) }
    static func uv(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - center.x) / rx, y: (p.y - center.y) / ry) }
    static let plane = CGAffineTransform(a: rx, b: 0, c: 0, d: ry, tx: center.x, ty: center.y)
    static let gravity: CGFloat = 1500
}

enum Ingredient: String {
    case flour, sugar, eggs, milk, butter, flavor
}

/// One pour: a container flies over the bowl, tips, empties and leaves.
struct PourEvent {
    let what: Ingredient
    let flavor: Int
    let start: Date
    /// Where the container comes from (bowl art coordinates).
    let from: CGPoint

    static let tIn = 0.4
    static let tTilt = 0.3
    static let tOut = 0.4

    var pourTime: Double {
        switch what {
        case .flour: return 1.1
        case .sugar: return 1.0
        case .milk: return 1.1
        case .flavor: return 0.9
        case .eggs: return 1.3
        case .butter: return 0.55
        }
    }
    var pourStart: Double { PourEvent.tIn + PourEvent.tTilt }
    var pourEnd: Double { pourStart + pourTime }
    var duration: Double { pourEnd + PourEvent.tOut }

    var hover: CGPoint {
        switch what {
        case .flour: return CGPoint(x: 286, y: -66)
        case .sugar: return CGPoint(x: 280, y: -58)
        case .milk: return CGPoint(x: 292, y: -72)
        case .flavor: return CGPoint(x: 284, y: -66)
        case .eggs, .butter: return CGPoint(x: 210, y: -46)
        }
    }
    var tilt: Double {
        switch what {
        case .flour: return -118
        case .sugar: return -112
        case .milk: return -104
        case .flavor: return -124
        case .eggs, .butter: return 0
        }
    }
    /// The container's opening, in its 160 x 160 sprite box.
    var mouthLocal: CGPoint {
        switch what {
        case .flour: return CGPoint(x: 80, y: 30)
        case .sugar: return CGPoint(x: 80, y: 34)
        case .milk: return CGPoint(x: 80, y: 18)
        default: return CGPoint(x: 80, y: 16)
        }
    }
    static let scale: CGFloat = 0.72

    struct Pose {
        var center: CGPoint
        var angle: Double
        var scale: CGFloat
        var opacity: Double
    }

    /// Where the container is `t` seconds after the pour started.
    func pose(_ t: Double) -> Pose {
        let s = PourEvent.scale
        if t < PourEvent.tIn {
            let k = fxEase(t / PourEvent.tIn)
            let c = CGPoint(x: from.x + (hover.x - from.x) * k, y: from.y + (hover.y - from.y) * k - 40 * sin(k * .pi))
            return Pose(center: c, angle: 0, scale: s * (0.7 + 0.3 * k), opacity: 1)
        }
        if t < pourStart {
            let k = fxEase((t - PourEvent.tIn) / PourEvent.tTilt)
            return Pose(center: hover, angle: tilt * Double(k), scale: s, opacity: 1)
        }
        if t < pourEnd {
            var a = tilt
            if what == .flour { a += sin(t * 26) * 5 }
            if what == .sugar { a += sin(t * 20) * 4 }
            if what == .milk || what == .flavor { a += sin(t * 3) * 3 }
            return Pose(center: hover, angle: a, scale: s, opacity: 1)
        }
        let k = fxEase((t - pourEnd) / PourEvent.tOut)
        let c = CGPoint(x: hover.x + 70 * k, y: hover.y - 90 * k)
        return Pose(center: c, angle: tilt * Double(1 - k), scale: s * (1 - 0.3 * k), opacity: Double(1 - k))
    }

    func mouth(_ p: Pose) -> CGPoint {
        let m = mouthLocal
        let dx = (m.x - 80) * p.scale, dy = (m.y - 80) * p.scale
        let a = CGFloat(p.angle * .pi / 180)
        return CGPoint(x: p.center.x + dx * cos(a) - dy * sin(a), y: p.center.y + dx * sin(a) + dy * cos(a))
    }

    /// Where the stream or grains land on the surface (bowl art coordinates), roughly.
    var landing: CGPoint {
        let m = mouth(pose(pourStart + 0.2))
        return CGPoint(x: m.x - 14, y: BowlGeo.center.y + 2)
    }

    /// Egg x positions over the bowl.
    static let eggX: [CGFloat] = [176, 240]
    static let eggY: CGFloat = -40
    func crackTime(_ k: Int) -> Double { pourStart + Double(k) * 0.6 }
    static func fallTime(from y0: CGFloat, to y1: CGFloat, v0: CGFloat = 0) -> Double {
        let g = BowlGeo.gravity
        let d = max(0, y1 - y0)
        return Double((-v0 + sqrt(v0 * v0 + 2 * g * d)) / g)
    }
}

/// A soft blob of something on the batter surface, in surface units.
struct Blob {
    var p: CGPoint
    var r: CGFloat
    var raw: RGB
    var born: Date
    var mix: Double = 0
    var cube = false
    var yolk = false
    var grainy = false
    var stretch = CGVector.zero
    var stretchAt = Date.distantPast
    var seed = 0
}

final class BowlSim {
    static let cream = RGB(hex: "#FFF6E8")

    var blobs: [Blob] = []
    var pours: [PourEvent] = []
    var growth: [(start: Date, dur: Double, amount: CGFloat)] = []
    var thuds: [Date] = []
    var target: RGB?
    var poolRaw = BowlSim.cream
    var trail: [(p: CGPoint, t: Date)] = []
    var spoon: CGPoint?
    var finishedAt: Date?
    var busyUntil = Date.distantPast
    private var seedCounter = 0

    // MARK: Adding things

    /// Queues a pour and returns its start time.
    @discardableResult
    func pour(_ what: Ingredient, flavor: Int = 0, from: CGPoint) -> PourEvent {
        let now = Date()
        let start = max(now, busyUntil)
        let ev = PourEvent(what: what, flavor: flavor, start: start, from: from)
        pours.append(ev)
        busyUntil = start.addingTimeInterval(ev.pourEnd + 0.05)
        pours.removeAll { now.timeIntervalSince($0.start) > $0.duration + 1 }
        deposit(ev)
        return ev
    }

    /// Puts ingredients in as if they were poured long ago (for screenshots).
    func prefill(_ items: [Ingredient], flavor: Int = 0) {
        let past = Date().addingTimeInterval(-30)
        for w in items {
            let ev = PourEvent(what: w, flavor: flavor, start: past, from: CGPoint(x: 600, y: 0))
            deposit(ev)
        }
        thuds = []
    }

    private func nextSeed() -> Int { seedCounter += 1; return seedCounter }

    private func at(_ ev: PourEvent, _ t: Double) -> Date { ev.start.addingTimeInterval(t) }

    private func deposit(_ ev: PourEvent) {
        let L = BowlGeo.uv(ev.landing)
        let seed = nextSeed() * 31
        switch ev.what {
        case .flour, .sugar:
            let n = ev.what == .flour ? 8 : 6
            for k in 0..<n {
                let j = fxRand(k, seed)
                let j2 = fxRand(k, seed + 1)
                let p = CGPoint(x: L.x + (j - 0.5) * 0.26, y: L.y + (j2 - 0.5) * 0.5)
                let t = ev.pourStart + 0.3 + ev.pourTime * Double(k) / Double(n)
                let col = ev.what == .flour ? RGB(hex: "#FFFFFF") : RGB(hex: "#FFFDF4")
                var b = Blob(p: p, r: 0.09 + 0.06 * fxRand(k, seed + 2), raw: col, born: at(ev, t))
                b.grainy = ev.what == .sugar
                b.seed = seed + k
                blobs.append(b)
            }
            thuds.append(at(ev, ev.pourStart + 0.45))
        case .eggs:
            for k in 0..<2 {
                let x = PourEvent.eggX[k]
                let land = ev.crackTime(k) + 0.12 + PourEvent.fallTime(from: PourEvent.eggY + 14, to: BowlGeo.center.y)
                let p = BowlGeo.uv(CGPoint(x: x, y: BowlGeo.center.y + CGFloat(k) * 6 - 4))
                blobs.append(Blob(p: p, r: 0.2, raw: RGB(hex: "#FFFCF2"), born: at(ev, land), seed: seed + k))
                var y = Blob(p: CGPoint(x: p.x + 0.02, y: p.y - 0.06), r: 0.072, raw: RGB(hex: "#FFB627"), born: at(ev, land))
                y.yolk = true
                y.seed = seed + 10 + k
                blobs.append(y)
                growth.append((at(ev, land), 0.45, 0.2))
                thuds.append(at(ev, land))
            }
        case .milk:
            growth.append((at(ev, ev.pourStart + 0.25), ev.pourTime, 0.86))
            thuds.append(at(ev, ev.pourStart + 0.3))
        case .butter:
            let land = ev.pourStart + PourEvent.fallTime(from: ev.hover.y, to: BowlGeo.center.y - 8)
            var b = Blob(p: CGPoint(x: 0, y: -0.1), r: 0.17, raw: RGB(hex: "#FFE27A"), born: at(ev, land))
            b.cube = true
            b.seed = seed
            blobs.append(b)
            thuds.append(at(ev, land))
        case .flavor:
            let f = BakeryPalette.flavors[max(0, min(BakeryPalette.flavors.count - 1, ev.flavor))].color
            let raw = Shades.deep(f).mix(f, 0.45)
            let n = 14
            for k in 0..<n {
                let a = CGFloat(k) * 1.9
                let rr = 0.04 + 0.26 * CGFloat(k) / CGFloat(n)
                let p = CGPoint(x: L.x * 0.6 + cos(a) * rr, y: L.y + sin(a) * rr * 1.4)
                let t = ev.pourStart + 0.25 + ev.pourTime * 0.85 * Double(k) / Double(n)
                var b = Blob(p: p, r: 0.06 + 0.035 * fxRand(k, seed), raw: raw, born: at(ev, t))
                b.seed = seed + k
                blobs.append(b)
            }
        }
    }

    /// The batter's goal color (the flavor) arrives; everything starts blending toward it.
    func setTarget(_ c: RGB, now: Date = Date()) {
        if target != nil {
            // re-flavoring after mixing: what's in the bowl now becomes the starting point
            poolRaw = poolColor(now)
            for i in blobs.indices {
                blobs[i].raw = color(of: blobs[i], now)
                blobs[i].mix = 0
            }
            finishedAt = nil
        }
        target = c
    }

    // MARK: State

    func poolRadius(_ now: Date) -> CGFloat {
        var r: CGFloat = 0
        for g in growth {
            let k = fxEase(now.timeIntervalSince(g.start) / g.dur)
            r += g.amount * k
        }
        return min(1, r)
    }

    /// How mixed the bowl is, 0...1.
    var progress: Double {
        if finishedAt != nil { return 1 }
        var w = 0.0, m = 0.0
        for b in blobs {
            let ww = Double(b.r * b.r)
            w += ww
            m += ww * b.mix
        }
        return w > 0 ? m / w : (target == nil ? 0 : 1)
    }

    func effectiveMix(_ b: Blob, _ now: Date) -> Double {
        guard let f = finishedAt else { return b.mix }
        return max(b.mix, Double(fxEase(now.timeIntervalSince(f) / 0.6)))
    }

    func color(of b: Blob, _ now: Date) -> RGB {
        b.raw.mix(target ?? BowlSim.cream, effectiveMix(b, now))
    }

    func poolColor(_ now: Date) -> RGB {
        guard let t = target else { return poolRaw }
        var k = pow(progress, 0.85)
        if let f = finishedAt { k = max(k, Double(fxEase(now.timeIntervalSince(f) / 0.6))) }
        return poolRaw.mix(t, k)
    }

    // MARK: Stirring

    /// Moves the spoon to `q` (surface units). Returns how far it moved.
    @discardableResult
    func stir(to q: CGPoint, at now: Date) -> CGFloat {
        defer { spoon = q }
        trail.append((q, now))
        trail.removeAll { now.timeIntervalSince($0.t) > 0.9 }
        if trail.count > 70 { trail.removeFirst(trail.count - 70) }
        guard let s = spoon else { return 0 }
        let dv = CGVector(dx: q.x - s.x, dy: q.y - s.y)
        let d = hypot(dv.dx, dv.dy)
        guard d > 0.001 else { return 0 }
        var extra: [Blob] = []
        let full = poolRadius(now) > 0.97
        for i in blobs.indices {
            var b = blobs[i]
            guard b.born <= now else { continue }
            b.mix = min(1, b.mix + Double(d) * 0.075)
            let dist = hypot(b.p.x - q.x, (b.p.y - q.y) * 0.8)
            let reach: CGFloat = 0.3 + b.r * 0.6
            if dist < reach {
                let f = pow(1 - dist / reach, 1.5)
                let drag: CGFloat = b.cube ? 0.5 : 0.85
                b.p.x += dv.dx * f * drag
                b.p.y += dv.dy * f * drag
                let keep = CGFloat(exp(-now.timeIntervalSince(b.stretchAt) / 0.5))
                b.stretch = CGVector(dx: b.stretch.dx * keep + dv.dx * f * 3, dy: b.stretch.dy * keep + dv.dy * f * 3)
                b.stretchAt = now
                b.mix = min(1, b.mix + Double(d * f) * (b.cube ? 0.55 : 0.9))
                if b.cube && b.mix > 0.3 { b.cube = false }
                if b.yolk && b.mix > 0.2 { b.yolk = false }
                let sl = hypot(b.stretch.dx, b.stretch.dy)
                if !b.cube && sl > 0.45 && b.r > 0.032 && blobs.count + extra.count < 260 {
                    // a streak pulls apart into two ribbons: that's the marbling
                    let ux = b.stretch.dx / sl, uy = b.stretch.dy / sl
                    b.r *= 0.74
                    var c = b
                    c.seed = nextSeed()
                    b.p.x -= ux * b.r * 0.9; b.p.y -= uy * b.r * 0.9
                    c.p.x += ux * c.r * 0.9 - uy * c.r * 0.3; c.p.y += uy * c.r * 0.9 + ux * c.r * 0.3
                    b.stretch = CGVector(dx: b.stretch.dx * 0.45, dy: b.stretch.dy * 0.45)
                    c.stretch = b.stretch
                    extra.append(c)
                }
            }
            let maxR = 0.95 - b.r * 0.5
            let len = hypot(b.p.x, b.p.y)
            if len > maxR { b.p.x *= maxR / len; b.p.y *= maxR / len }
            blobs[i] = b
        }
        blobs += extra
        if full { blobs.removeAll { $0.mix >= 0.995 && $0.born <= now } }
        return d
    }

    func endStir() {
        spoon = nil
    }

    func finish(_ now: Date = Date()) {
        if finishedAt == nil { finishedAt = now }
    }

    // MARK: Drawing

    func draw(in ctx: GraphicsContext, now: Date) {
        let art = BakeryArt.shared
        var g = ctx
        // the bowl jiggles a little when something lands in it
        var wob: CGFloat = 0
        for t in thuds {
            let a = now.timeIntervalSince(t)
            if a > 0 && a < 0.8 { wob += CGFloat(sin(a * 22) * exp(-a * 6)) * 0.035 }
        }
        if wob != 0 {
            g.translateBy(x: 200, y: 284)
            g.scaleBy(x: 1 + wob, y: 1 - wob)
            g.translateBy(x: -200, y: -284)
        }
        art.draw("bowl_back", in: g)
        drawSurface(g, now)
        art.draw("bowl_front", in: g)
        drawSpoonHandle(g, now)
        for ev in pours {
            let t = now.timeIntervalSince(ev.start)
            guard t >= 0, t < ev.duration + 0.8 else { continue }
            drawPour(ev, t: t, in: g)
        }
    }

    private func drawSurface(_ g: GraphicsContext, _ now: Date) {
        let R = poolRadius(now)
        let pc = poolColor(now)
        if R > 0.01 {
            let rect = CGRect(x: BowlGeo.center.x - BowlGeo.rx * R, y: BowlGeo.center.y - BowlGeo.ry * R,
                              width: 2 * BowlGeo.rx * R, height: 2 * BowlGeo.ry * R)
            g.fill(Path(ellipseIn: rect), with: .color(pc.color))
            var o = g
            o.opacity = 0.7
            o.stroke(Path(ellipseIn: rect), with: .color(Shades.outline(pc).color), lineWidth: 3)
            var hl = g
            hl.opacity = 0.55
            let hr = CGRect(x: 200 - 92 * R, y: 104, width: 64 * R, height: 11 * R)
            hl.fill(Path(ellipseIn: hr), with: .color(Shades.light(pc).color))
        }
        // rings where liquid lands
        for ev in pours where ev.what == .milk || ev.what == .flavor {
            let t = now.timeIntervalSince(ev.start) - ev.pourStart - 0.2
            guard t > 0, t < ev.pourTime + 0.8 else { continue }
            let L = BowlGeo.uv(ev.landing)
            for k in 0..<3 {
                let ph = (t + Double(k) * 0.33).truncatingRemainder(dividingBy: 1.0)
                if t - ph > ev.pourTime { continue }
                let rr = CGFloat(0.05 + 0.3 * ph)
                let ring = Path(ellipseIn: CGRect(x: L.x - rr, y: L.y - rr * 1.4, width: rr * 2, height: rr * 2.8)).applying(BowlGeo.plane)
                var rg = g
                rg.opacity = (1 - ph) * 0.7
                rg.stroke(ring, with: .color(Shades.light(pc).color), lineWidth: 2.5)
                rg.opacity = (1 - ph) * 0.3
                rg.stroke(ring.applying(CGAffineTransform(translationX: 0, y: 2.5)), with: .color(Shades.shade(pc).color), lineWidth: 2)
            }
        }
        for b in blobs where b.born <= now {
            drawBlob(b, g, now)
        }
        drawFurrow(g, now, pc)
    }

    private func drawBlob(_ b: Blob, _ g: GraphicsContext, _ now: Date) {
        let age = now.timeIntervalSince(b.born)
        var grow = fxEase(age / 0.3)
        if b.yolk { grow *= 1 + CGFloat(sin(age * 17) * exp(-age * 3.5)) * 0.18 }
        let r = b.r * max(0.05, grow)
        let col = color(of: b, now)
        let mix = effectiveMix(b, now)
        let dry = 1 - mix
        let c = BowlGeo.art(b.p)
        if b.cube {
            // a pat of butter: corners soften as it's worked in
            let w = r * BowlGeo.rx * 2.6, h = r * BowlGeo.rx * 1.3
            let squash = 1 + CGFloat(sin(age * 20) * exp(-age * 7)) * 0.25
            let rect = CGRect(x: c.x - w / 2 * squash, y: c.y - h / squash + 6, width: w * squash, height: h / squash)
            let corner = 6 + CGFloat(min(1, mix / 0.3)) * (rect.height / 2 - 6)
            let rr = RoundedRectangle(cornerRadius: corner, style: .continuous).path(in: rect)
            g.fill(rr, with: .color(col.color))
            g.stroke(rr, with: .color(Shades.outline(col).color), lineWidth: 3)
            let top = RoundedRectangle(cornerRadius: 5, style: .continuous)
                .path(in: CGRect(x: rect.minX + 4, y: rect.minY + 3, width: rect.width - 8, height: rect.height * 0.32))
            g.fill(top, with: .color(Shades.light(col).color.opacity(0.9)))
            return
        }
        let keep = CGFloat(exp(-now.timeIntervalSince(b.stretchAt) / 0.5))
        let sx = b.stretch.dx * keep, sy = b.stretch.dy * keep
        let sl = hypot(sx, sy)
        let ang = sl > 0.001 ? atan2(sy, sx) : 0
        let a = r * (1 + min(2.2, sl * 1.4))
        let bb = r / (1 + min(0.6, sl * 0.4))
        // the blob lies on the surface; mounds of dry flour or sugar stand up a bit
        let height: CGFloat = 1.25 + 0.5 * CGFloat(dry)
        let shape = Path(ellipseIn: CGRect(x: -a, y: -bb, width: 2 * a, height: 2 * bb))
            .applying(CGAffineTransform(rotationAngle: ang))
            .applying(CGAffineTransform(translationX: b.p.x, y: b.p.y))
            .applying(CGAffineTransform(a: BowlGeo.rx, b: 0, c: 0, d: BowlGeo.ry * height, tx: BowlGeo.center.x, ty: BowlGeo.center.y + BowlGeo.ry * b.p.y * (1 - height)))
        g.fill(shape, with: .color(col.color))
        if dry > 0.02 {
            var e = g
            e.opacity = 0.45 * dry
            e.stroke(shape, with: .color(Shades.shade(col).color), lineWidth: 2)
            e.opacity = 0.55 * dry
            let hl = CGRect(x: c.x - a * BowlGeo.rx * 0.55, y: c.y - bb * BowlGeo.ry * height * 0.75,
                            width: a * BowlGeo.rx * 0.6, height: bb * BowlGeo.ry * height * 0.55)
            e.fill(Path(ellipseIn: hl), with: .color(b.yolk ? RGB(hex: "#FFF1B0").color : Color.white))
            if b.grainy {
                e.opacity = 0.8 * dry
                for k in 0..<6 {
                    let gx = c.x + (fxRand(k, b.seed) - 0.5) * a * BowlGeo.rx * 1.4
                    let gy = c.y + (fxRand(k, b.seed + 7) - 0.6) * bb * BowlGeo.ry * 1.6
                    e.fill(Path(CGRect(x: gx, y: gy, width: 3, height: 3)), with: .color(RGB(hex: "#E2D8EE").color))
                }
            }
        }
    }

    private func drawFurrow(_ g: GraphicsContext, _ now: Date, _ pc: RGB) {
        guard trail.count > 1 else { return }
        for i in 1..<trail.count {
            let a = trail[i - 1], b = trail[i]
            let age = now.timeIntervalSince(b.t)
            guard age < 0.9 else { continue }
            let k = 1 - age / 0.9
            let p0 = BowlGeo.art(a.p), p1 = BowlGeo.art(b.p)
            var seg = Path()
            seg.move(to: p0)
            seg.addLine(to: p1)
            var s = g
            s.opacity = 0.5 * k
            s.stroke(seg, with: .color(Shades.shade(pc).color), style: StrokeStyle(lineWidth: CGFloat(4 + 9 * k), lineCap: .round))
            s.opacity = 0.6 * k
            s.stroke(seg.applying(CGAffineTransform(translationX: 0, y: -3.5)), with: .color(Shades.light(pc).color),
                     style: StrokeStyle(lineWidth: CGFloat(2 + 3 * k), lineCap: .round))
        }
    }

    private func drawSpoonHandle(_ g: GraphicsContext, _ now: Date) {
        guard let s = spoon else { return }
        let e = BowlGeo.art(s)
        let pc = poolColor(now)
        // the batter hugging the spoon where it goes in
        var m = g
        m.opacity = 0.55
        m.fill(Path(ellipseIn: CGRect(x: e.x - 22, y: e.y - 6, width: 44, height: 13)), with: .color(Shades.shade(pc).color))
        m.opacity = 0.9
        var lip = Path()
        lip.addArc(center: CGPoint(x: e.x, y: e.y), radius: 1, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        m.stroke(lip.applying(CGAffineTransform(translationX: -e.x, y: -e.y)).applying(CGAffineTransform(scaleX: 20, y: 6))
                    .applying(CGAffineTransform(translationX: e.x, y: e.y)), with: .color(Shades.light(pc).color), lineWidth: 3)
        // the handle
        let top = CGPoint(x: e.x + 70, y: e.y - 150)
        var h = Path()
        h.move(to: CGPoint(x: e.x, y: e.y - 2))
        h.addLine(to: top)
        g.stroke(h, with: .color(Color(hex: 0x9B6B52)), style: StrokeStyle(lineWidth: 20, lineCap: .round))
        g.stroke(h, with: .color(Color(hex: 0xE9B07A)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        var shine = Path()
        shine.move(to: CGPoint(x: e.x + 18, y: e.y - 44))
        shine.addLine(to: CGPoint(x: e.x + 56, y: e.y - 126))
        g.stroke(shine, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        // a little batter clinging to the spoon
        var cl = Path()
        cl.move(to: CGPoint(x: e.x - 4, y: e.y - 4))
        cl.addLine(to: CGPoint(x: e.x + 9, y: e.y - 24))
        g.stroke(cl, with: .color(pc.color), style: StrokeStyle(lineWidth: 12, lineCap: .round))
    }

    // MARK: Pours

    private func drawPour(_ ev: PourEvent, t: Double, in g: GraphicsContext) {
        switch ev.what {
        case .flour, .sugar: drawGrains(ev, t: t, in: g)
        case .milk, .flavor: drawLiquid(ev, t: t, in: g)
        case .eggs: drawEggs(ev, t: t, in: g)
        case .butter: drawButter(ev, t: t, in: g)
        }
    }

    private func drawContainer(_ ev: PourEvent, t: Double, in g: GraphicsContext) {
        guard t < ev.duration else { return }
        let p = ev.pose(t)
        var c = g
        c.opacity = p.opacity
        c.translateBy(x: p.center.x, y: p.center.y)
        c.rotate(by: .degrees(p.angle))
        c.scaleBy(x: p.scale, y: p.scale)
        c.translateBy(x: -80, y: -80)
        let art = BakeryArt.shared
        switch ev.what {
        case .flavor:
            let f = BakeryPalette.flavors[max(0, min(BakeryPalette.flavors.count - 1, ev.flavor))]
            art.draw("bottle", f.color, in: c)
            art.draw(f.icon, f.color, at: CGPoint(x: 80, y: 104), scale: 0.5, in: c)
        default:
            art.draw(ev.what.rawValue, in: c)
        }
    }

    private func drawGrains(_ ev: PourEvent, t: Double, in g: GraphicsContext) {
        let flour = ev.what == .flour
        let n = flour ? 170 : 140
        let span = ev.pourTime - 0.1
        let floorY = BowlGeo.center.y - 4
        // a soft column of falling powder behind the grains
        if flour, t > ev.pourStart, t < ev.pourEnd + 0.3 {
            let m = ev.mouth(ev.pose(min(t, ev.pourEnd)))
            let k = min(1, (t - ev.pourStart) / 0.15) * (t > ev.pourEnd ? max(0, 1 - (t - ev.pourEnd) / 0.3) : 1)
            var col = Path()
            col.move(to: CGPoint(x: m.x - 7, y: m.y))
            col.addLine(to: CGPoint(x: m.x + 7, y: m.y))
            col.addLine(to: CGPoint(x: m.x - 2, y: floorY))
            col.addLine(to: CGPoint(x: m.x - 26, y: floorY))
            col.closeSubpath()
            var cg = g
            cg.opacity = 0.35 * k
            cg.fill(col, with: .color(.white))
        }
        for i in 0..<n {
            let te = ev.pourStart + span * Double(i) / Double(n) + Double(fxRand(i, 3)) * 0.03
            let tau = t - te
            guard tau > 0 else { continue }
            let p0 = ev.mouth(ev.pose(te))
            let vx = -60 + 70 * fxRand(i, 5)
            let vy = 20 + 40 * fxRand(i, 6)
            let jx = (fxRand(i, 7) - 0.5) * 10
            let landY = floorY + (fxRand(i, 8) - 0.5) * 22
            let tl = PourEvent.fallTime(from: p0.y, to: landY, v0: vy)
            let x = p0.x + jx + vx * CGFloat(min(tau, tl))
            if tau < tl {
                let y = p0.y + vy * CGFloat(tau) + 0.5 * BowlGeo.gravity * CGFloat(tau * tau)
                if flour {
                    let s = 2.2 + 2.6 * fxRand(i, 9)
                    g.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s)), with: .color(.white.opacity(0.95)))
                } else {
                    let s = 1.6 + 1.6 * fxRand(i, 9)
                    let glint = i % 9 == 0 && sin(tau * 40 + Double(i)) > 0.3
                    let r = Path(CGRect(x: -s, y: -s, width: 2 * s, height: 2 * s))
                        .applying(CGAffineTransform(rotationAngle: CGFloat(i) + CGFloat(tau) * 12))
                        .applying(CGAffineTransform(translationX: x, y: y))
                    g.fill(r, with: .color(glint ? .white : RGB(hex: "#F4EEF8").color))
                    g.stroke(r, with: .color(RGB(hex: "#CFC3DD").color), lineWidth: 0.8)
                    if glint {
                        var sp = Path()
                        sp.move(to: CGPoint(x: x - 5, y: y)); sp.addLine(to: CGPoint(x: x + 5, y: y))
                        sp.move(to: CGPoint(x: x, y: y - 5)); sp.addLine(to: CGPoint(x: x, y: y + 5))
                        g.stroke(sp, with: .color(.white), lineWidth: 1.4)
                    }
                }
            } else if flour && i % 5 == 0 {
                // a little puff of flour dust where it lands
                let a = tau - tl
                if a < 0.55 {
                    let k = CGFloat(a / 0.55)
                    let rr = 5 + 24 * k
                    var pg = g
                    pg.opacity = Double(0.4 * (1 - k))
                    pg.fill(Path(ellipseIn: CGRect(x: x - rr, y: landY - rr * 0.7 - 16 * k, width: rr * 2, height: rr * 1.4)), with: .color(.white))
                }
            }
        }
        drawContainer(ev, t: t, in: g)
    }

    private func drawLiquid(_ ev: PourEvent, t: Double, in g: GraphicsContext) {
        let col: RGB
        if ev.what == .milk {
            col = RGB(hex: "#FDFCFF")
        } else {
            col = BakeryPalette.flavors[max(0, min(BakeryPalette.flavors.count - 1, ev.flavor))].color
        }
        let flowStart = ev.pourStart + 0.02
        if t > flowStart {
            let stopped: Double? = t > ev.pourEnd ? t - ev.pourEnd : nil
            let m = ev.mouth(ev.pose(min(t, ev.pourEnd)))
            let wide: CGFloat = ev.what == .milk ? 15 : 10
            if let s = LiquidStream(mouth: m, floorY: BowlGeo.center.y + 2, vx: -26, width: wide, v0: 30,
                                    age: t - flowStart, stopped: stopped, phase: t) {
                s.draw(in: g, color: col)
                if s.reachesFloor {
                    s.drawSplash(in: g, color: col, time: t, big: ev.what == .milk)
                }
            }
        }
        drawContainer(ev, t: t, in: g)
    }

    private func drawEggs(_ ev: PourEvent, t: Double, in g: GraphicsContext) {
        let shell = RGB(hex: "#FFF8EC")
        let edge = RGB(hex: "#D9C6B4").color
        for k in 0..<2 {
            let hx = PourEvent.eggX[k], hy = PourEvent.eggY
            let tc = ev.crackTime(k)
            let center: CGPoint
            if t < PourEvent.tIn {
                let q = fxEase(t / PourEvent.tIn)
                center = CGPoint(x: ev.from.x + (hx - ev.from.x) * q, y: ev.from.y + (hy - ev.from.y) * q - 50 * sin(q * .pi))
            } else {
                center = CGPoint(x: hx, y: hy)
            }
            if t < tc {
                // a tap on the rim before it cracks
                let tap = t > tc - 0.25 ? CGFloat(sin((t - tc) * 40)) * 4 : 0
                var e = g
                e.translateBy(x: center.x, y: center.y + tap)
                e.rotate(by: .degrees(Double(k == 0 ? -12 : 12)))
                let r = Path(ellipseIn: CGRect(x: -20, y: -27, width: 40, height: 54))
                e.fill(r, with: .color(shell.color))
                e.stroke(r, with: .color(edge), lineWidth: 3)
                e.fill(Path(ellipseIn: CGRect(x: -12, y: -18, width: 8, height: 14)), with: .color(.white))
                continue
            }
            let a = t - tc
            // two shell halves come apart, then fade away
            if a < 0.7 {
                let open = fxEase(a / 0.25)
                for side in [-1.0, 1.0] {
                    var h = g
                    h.opacity = Double(1 - fxEase((a - 0.4) / 0.3))
                    h.translateBy(x: center.x + CGFloat(side) * (4 + 20 * open), y: center.y - 4 * open)
                    h.rotate(by: .degrees(side * Double(70 * open)))
                    var half = Path()
                    let sx: CGFloat = CGFloat(side)
                    half.move(to: CGPoint(x: 0, y: -27))
                    half.addCurve(to: CGPoint(x: 0, y: 27), control1: CGPoint(x: 27 * sx, y: -27), control2: CGPoint(x: 27 * sx, y: 27))
                    half.addLine(to: CGPoint(x: -3 * sx, y: 14))
                    half.addLine(to: CGPoint(x: 4 * sx, y: 4))
                    half.addLine(to: CGPoint(x: -3 * sx, y: -6))
                    half.addLine(to: CGPoint(x: 4 * sx, y: -16))
                    half.closeSubpath()
                    h.fill(half, with: .color(shell.color))
                    h.stroke(half, with: .color(edge), lineWidth: 2.5)
                }
            }
            // the egg falls out: clear white stretching around a bright yolk
            let drop = a - 0.12
            let y0 = hy + 14
            let tl = PourEvent.fallTime(from: y0, to: BowlGeo.center.y)
            if drop > 0 && drop < tl {
                let y = y0 + 0.5 * BowlGeo.gravity * CGFloat(drop * drop)
                let v = BowlGeo.gravity * CGFloat(drop)
                let st = 1 + min(1.2, v / 900)
                var w = g
                w.opacity = 0.85
                w.fill(Path(ellipseIn: CGRect(x: center.x - 18 / st, y: y - 18 * st, width: 36 / st, height: 30 * st)),
                       with: .color(RGB(hex: "#FFFCF2").color))
                w.opacity = 1
                w.fill(Path(ellipseIn: CGRect(x: center.x - 10, y: y - 6 * st, width: 20, height: 18)), with: .color(RGB(hex: "#FFB627").color))
                w.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: y - 4 * st, width: 6, height: 5)), with: .color(.white.opacity(0.8)))
            }
        }
    }

    private func drawButter(_ ev: PourEvent, t: Double, in g: GraphicsContext) {
        var center: CGPoint
        if t < PourEvent.tIn {
            let q = fxEase(t / PourEvent.tIn)
            center = CGPoint(x: ev.from.x + (ev.hover.x - ev.from.x) * q, y: ev.from.y + (ev.hover.y - ev.from.y) * q - 40 * sin(q * .pi))
        } else {
            center = ev.hover
        }
        let landY = BowlGeo.center.y - 8
        let tl = PourEvent.fallTime(from: ev.hover.y, to: landY)
        let fall = t - ev.pourStart
        if fall > tl { return }
        var rot = 0.0
        if fall > 0 {
            center.y = ev.hover.y + 0.5 * BowlGeo.gravity * CGFloat(fall * fall)
            center.x -= 10 * CGFloat(fall / tl)
            rot = -20 * fall / tl
        }
        var b = g
        b.translateBy(x: center.x, y: center.y)
        b.rotate(by: .degrees(rot))
        let y = RGB(hex: "#FFE27A")
        let block = RoundedRectangle(cornerRadius: 6, style: .continuous).path(in: CGRect(x: -34, y: -17, width: 68, height: 34))
        b.fill(block, with: .color(y.color))
        b.stroke(block, with: .color(RGB(hex: "#D6A84A").color), lineWidth: 3)
        b.fill(RoundedRectangle(cornerRadius: 4, style: .continuous).path(in: CGRect(x: -30, y: -14, width: 60, height: 9)),
               with: .color(RGB(hex: "#FFF4B8").color))
    }
}

// MARK: - A falling stream of liquid

/// A stream pouring from `mouth` down to `floorY`: it thins as it speeds up, wobbles a little, and when the
/// pour stops its tail falls away after the head.
struct LiquidStream {
    let left: [CGPoint]
    let right: [CGPoint]
    let center: [CGPoint]
    let widths: [CGFloat]
    let reachesFloor: Bool
    let land: CGPoint
    let headDrop: Bool

    init?(mouth: CGPoint, floorY: CGFloat, vx: CGFloat, width: CGFloat, v0: CGFloat, age: Double, stopped: Double?,
          phase: Double, gravity: CGFloat = BowlGeo.gravity, wobble: CGFloat = 1.4) {
        let g = gravity
        let a = CGFloat(max(0, age))
        let head = min(floorY, mouth.y + v0 * a + 0.5 * g * a * a)
        var tail = mouth.y
        if let s = stopped {
            let ss = CGFloat(s)
            tail = mouth.y + v0 * ss + 0.5 * g * ss * ss
        }
        guard tail < floorY - 1, head > tail + 1 else { return nil }
        func xAt(_ y: CGFloat) -> CGFloat {
            let d = max(0, y - mouth.y)
            let tt = (-v0 + sqrt(v0 * v0 + 2 * g * d)) / g
            return mouth.x + vx * tt
        }
        var l: [CGPoint] = [], r: [CGPoint] = [], c: [CGPoint] = [], w: [CGFloat] = []
        let n = 16
        for k in 0...n {
            let y = tail + (head - tail) * CGFloat(k) / CGFloat(n)
            let fd = y - mouth.y
            let ww = width * max(0.42, 1 / sqrt(1 + fd / 50))
            let ox = CGFloat(sin(Double(y) * 0.07 - phase * 14)) * wobble * min(1, fd / 40)
            let x = xAt(y) + ox
            c.append(CGPoint(x: x, y: y))
            l.append(CGPoint(x: x - ww / 2, y: y))
            r.append(CGPoint(x: x + ww / 2, y: y))
            w.append(ww)
        }
        left = l; right = r; center = c; widths = w
        reachesFloor = head >= floorY - 0.5
        land = CGPoint(x: xAt(floorY), y: floorY)
        headDrop = !reachesFloor
    }

    var path: Path {
        var p = Path()
        p.move(to: left[0])
        for q in left.dropFirst() { p.addLine(to: q) }
        for q in right.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        // rounded ends
        if let h = center.last, let hw = widths.last {
            p.addEllipse(in: CGRect(x: h.x - hw / 2, y: h.y - hw / 2, width: hw, height: hw * (headDrop ? 1.3 : 1)))
        }
        if let t = center.first, let tw = widths.first {
            p.addEllipse(in: CGRect(x: t.x - tw / 2, y: t.y - tw / 2, width: tw, height: tw))
        }
        return p
    }

    func draw(in g: GraphicsContext, color: RGB, outline: Bool = true) {
        let p = path
        g.fill(p, with: .color(color.color))
        if outline {
            var o = g
            o.opacity = 0.65
            o.stroke(p, with: .color(Shades.outline(color).color), lineWidth: 2.2)
        }
        // a highlight running down the stream
        var hl = Path()
        for (k, q) in center.enumerated() {
            let pt = CGPoint(x: q.x - widths[k] * 0.22, y: q.y)
            if k == 0 { hl.move(to: pt) } else { hl.addLine(to: pt) }
        }
        var h = g
        h.opacity = 0.7
        h.stroke(hl, with: .color(Shades.light(color).color.opacity(0.9)),
                 style: StrokeStyle(lineWidth: max(1.5, (widths.first ?? 8) * 0.16), lineCap: .round))
    }

    /// Droplets kicking up where the stream hits.
    func drawSplash(in g: GraphicsContext, color: RGB, time: Double, big: Bool) {
        let lp = land
        g.fill(Path(ellipseIn: CGRect(x: lp.x - 14, y: lp.y - 5, width: 28, height: 10)), with: .color(color.color))
        let count = big ? 7 : 4
        for k in 0..<count {
            let period = 0.32
            let lt = (time + Double(k) * 0.047).truncatingRemainder(dividingBy: period)
            let side: CGFloat = k % 2 == 0 ? -1 : 1
            let vx = side * (30 + 50 * fxRand(k, 41))
            let vy = 110 + 90 * fxRand(k, 42)
            let ltc = CGFloat(lt)
            let x = lp.x + vx * ltc
            let y = lp.y - vy * ltc + 0.5 * BowlGeo.gravity * ltc * ltc
            guard y <= lp.y else { continue }
            let s: CGFloat = big ? 3 : 2.4
            g.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s)), with: .color(color.color))
            g.stroke(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s)), with: .color(Shades.outline(color).color.opacity(0.4)), lineWidth: 1)
        }
    }
}
