import SwiftUI

// MARK: - Hands-on ingredients
//
// She picks each ingredient up herself and puts it in the bowl:
// - flour: hold the bag over the bowl and it tips; shake it like a sifter and more flour (and dust) falls,
// - sugar: hold the jar over the bowl and the grains patter out,
// - milk: hold the carton over the bowl and it pours in a stream until the bowl has enough,
// - eggs: knock the egg on the rim (drag it down onto the rim, or drop it there and tap it). The first knock
//   cracks the shell, the second breaks it open and the egg falls in. Two eggs.
// - butter: drag it over the bowl and let go: it drops in with a plop.
// A pouring ingredient fills a ring around its plate; when it's full the container goes back and gets a tick.
//
// Everything here is in the bowl's art coordinates (Box.bowl, like `BowlSim`), and it feeds `BowlSim` with the
// same blobs, pool growth and bowl wobbles a scripted pour would.

final class HandsOnBowl {
    struct Grain {
        let born: Date
        let p0: CGPoint
        let vx: CGFloat
        let vy: CGFloat
        let landY: CGFloat
        let flour: Bool
        let seed: Int
    }

    struct Stream {
        let start: Date
        var end: Date?
        var mouth: CGPoint
    }

    struct BrokenEgg {
        let at: Date
        let center: CGPoint
    }

    struct ButterDrop {
        let at: Date
        let from: CGPoint
    }

    enum Knock { case none, knock, crack }

    static let eggs = 2
    /// Fills per second while pouring (a little more when shaking the flour).
    static let pourRate = 0.72
    static let rimRX: CGFloat = 172
    static let rimRY: CGFloat = 44
    static let rimCY: CGFloat = 112

    /// What's in her hand, if anything.
    var holding: Ingredient?
    /// The held container's center.
    var hand = CGPoint.zero
    var angle: Double = 0
    var pouring = false
    var amount: [Ingredient: Double] = [:]
    var eggsCracked = 0
    var knocks = 0
    var knockAt = Date.distantPast
    /// The egg was let go on the rim: it waits there to be tapped.
    var parked = false
    var finished: Set<Ingredient> = []

    var grains: [Grain] = []
    var streams: [Stream] = []
    var broken: [BrokenEgg] = []
    var butter: [ButterDrop] = []

    private var speed: CGFloat = 0
    private var lastMove: (p: CGPoint, t: Date)?
    private var lastStep: Date?
    private var depositAcc: Double = 0
    private var thudAcc: Double = 0
    private var pressedIn = false
    private var seed = 0

    // MARK: Geometry

    /// The top edge of the far rim at x (where an egg gets knocked).
    static func rimY(_ x: CGFloat) -> CGFloat {
        let u = (x - 200) / rimRX
        return rimCY - rimRY * sqrt(max(0, 1 - u * u))
    }

    static func tilt(_ w: Ingredient) -> Double {
        switch w {
        case .flour: return -118
        case .sugar: return -112
        case .milk: return -104
        default: return 0
        }
    }

    static func mouth(_ w: Ingredient, center: CGPoint, angle: Double) -> CGPoint {
        let local: CGPoint
        switch w {
        case .flour: local = CGPoint(x: 80, y: 30)
        case .sugar: local = CGPoint(x: 80, y: 34)
        case .milk: local = CGPoint(x: 80, y: 18)
        default: local = CGPoint(x: 80, y: 16)
        }
        let s = PourEvent.scale
        let dx = (local.x - 80) * s, dy = (local.y - 80) * s
        let a = CGFloat(angle * .pi / 180)
        return CGPoint(x: center.x + dx * cos(a) - dy * sin(a), y: center.y + dx * sin(a) + dy * cos(a))
    }

    var mouth: CGPoint { holding.map { HandsOnBowl.mouth($0, center: hand, angle: angle) } ?? hand }

    /// Is the held thing above the bowl (close enough to go in)?
    func overBowl() -> Bool {
        guard let w = holding else { return false }
        switch w {
        case .flour, .sugar, .milk:
            // judged by where it would pour from, at full tilt
            let m = HandsOnBowl.mouth(w, center: hand, angle: HandsOnBowl.tilt(w))
            return abs(m.x - 200) < 150 && m.y < BowlGeo.center.y - 6 && m.y > -260
        default:
            return abs(hand.x - 200) < 165 && hand.y < BowlGeo.center.y + 20 && hand.y > -240
        }
    }

    func progress(_ w: Ingredient) -> Double {
        if finished.contains(w) { return 1 }
        if w == .eggs { return Double(eggsCracked) / Double(HandsOnBowl.eggs) }
        return min(1, amount[w] ?? 0)
    }

    // MARK: Hands

    func grab(_ w: Ingredient, at p: CGPoint, now: Date) {
        if holding != w { angle = 0; knocks = 0 }
        holding = w
        parked = false
        hand = held(p, w)
        lastMove = (hand, now)
        pressedIn = false
    }

    /// How far above her finger a held thing sits, in bowl units (the mix step draws the bowl at 1.4x):
    /// the shared `FingerLift.item`, so her finger doesn't hide the jar, the egg or the rim.
    static let lift: CGFloat = FingerLift.item / 1.4

    /// Where the container sits for a finger at p (she holds it from below, so the finger doesn't hide it).
    private func held(_ p: CGPoint, _ w: Ingredient) -> CGPoint {
        CGPoint(x: p.x, y: p.y - HandsOnBowl.lift)
    }

    /// Moves the held thing. An egg can't go through the rim: pushing it down onto the rim knocks it.
    @discardableResult
    func move(to p: CGPoint, now: Date) -> Knock {
        guard let w = holding else { return .none }
        var q = held(p, w)
        if let l = lastMove {
            let dt = max(1.0 / 240, now.timeIntervalSince(l.t))
            let v = hypot(q.x - l.p.x, q.y - l.p.y) / CGFloat(dt)
            speed = speed * 0.7 + v * 0.3
        }
        lastMove = (q, now)
        var result = Knock.none
        if w == .eggs, abs(q.x - 200) < HandsOnBowl.rimRX - 20 {
            let rest = HandsOnBowl.rimY(q.x) - 26
            if q.y > rest {
                if !pressedIn && q.y > rest + 8 && hand.y < rest + 2 {
                    pressedIn = true
                    result = knock(now)
                    if result == .crack { return result }
                }
                q.y = rest
            } else if q.y < rest - 6 {
                pressedIn = false
            }
        }
        hand = q
        return result
    }

    /// The finger lifts. Returns true when the thing went into the bowl (or stays on the rim).
    @discardableResult
    func release(now: Date) -> Bool {
        guard let w = holding else { return false }
        endStream(now)
        pouring = false
        switch w {
        case .butter where overBowl():
            butter.append(ButterDrop(at: now, from: hand))
            let land = PourEvent.fallTime(from: hand.y, to: BowlGeo.center.y - 8)
            var b = Blob(p: clampUV(BowlGeo.uv(CGPoint(x: hand.x, y: BowlGeo.center.y - 4))), r: 0.17,
                         raw: RGB(hex: "#FFE27A"), born: now.addingTimeInterval(land))
            b.cube = true
            b.seed = nextSeed()
            sim?.blobs.append(b)
            sim?.thuds.append(now.addingTimeInterval(land))
            finished.insert(.butter)
            holding = nil
            return true
        case .eggs where abs(hand.x - 200) < HandsOnBowl.rimRX - 20 && hand.y >= HandsOnBowl.rimY(hand.x) - 40:
            // let go on the rim: it sits there, waiting to be tapped
            hand.y = HandsOnBowl.rimY(hand.x) - 26
            parked = true
            return true
        default:
            holding = nil
            parked = false
            return false
        }
    }

    /// Is the parked egg under the finger?
    func touchesParkedEgg(_ p: CGPoint) -> Bool {
        parked && holding == .eggs && hypot(p.x - hand.x, p.y - hand.y) < 60
    }

    /// One knock of the held egg on the rim.
    @discardableResult
    func knock(_ now: Date) -> Knock {
        guard holding == .eggs else { return .none }
        knocks += 1
        knockAt = now
        guard knocks >= 2 else { return .knock }
        // it breaks open: the shell comes apart and the egg falls in
        broken.append(BrokenEgg(at: now, center: hand))
        let fall = 0.12 + PourEvent.fallTime(from: hand.y + 14, to: BowlGeo.center.y)
        let land = now.addingTimeInterval(fall)
        let p = clampUV(BowlGeo.uv(CGPoint(x: hand.x, y: BowlGeo.center.y + CGFloat(eggsCracked) * 6 - 4)))
        sim?.blobs.append(Blob(p: p, r: 0.2, raw: RGB(hex: "#FFFCF2"), born: land, seed: nextSeed()))
        var y = Blob(p: CGPoint(x: p.x + 0.02, y: p.y - 0.06), r: 0.072, raw: RGB(hex: "#FFB627"), born: land)
        y.yolk = true
        y.seed = nextSeed()
        sim?.blobs.append(y)
        sim?.growth.append((land, 0.45, 0.2))
        sim?.thuds.append(land)
        eggsCracked += 1
        knocks = 0
        holding = nil
        parked = false
        if eggsCracked >= HandsOnBowl.eggs { finished.insert(.eggs) }
        return .crack
    }

    // MARK: Time

    weak var sim: BowlSim?

    /// Runs the pour for the time since the last step. Returns the ingredients that just got full.
    func step(_ now: Date) -> [Ingredient] {
        let dt = min(0.1, max(0, now.timeIntervalSince(lastStep ?? now)))
        lastStep = now
        speed *= CGFloat(exp(-dt * 4))
        grains.removeAll { now.timeIntervalSince($0.born) > 2.5 }
        streams.removeAll { s in s.end.map { now.timeIntervalSince($0) > 1.5 } ?? false }
        broken.removeAll { now.timeIntervalSince($0.at) > 2 }
        butter.removeAll { now.timeIntervalSince($0.at) > 2 }

        guard let w = holding, w == .flour || w == .sugar || w == .milk else { return [] }
        let over = overBowl()
        let target = over ? HandsOnBowl.tilt(w) : 0
        angle += (target - angle) * min(1, dt * 10)
        let tipped = over && abs(angle - target) < 30
        if tipped != pouring {
            pouring = tipped
            if tipped && w == .milk { streams.append(Stream(start: now, end: nil, mouth: mouth)) }
            if !tipped { endStream(now) }
        }
        guard pouring, dt > 0 else { return [] }

        var rate = HandsOnBowl.pourRate
        if w == .flour { rate = 0.5 + min(0.9, Double(speed) / 700) }   // sift it: shaking pours more
        if w == .sugar { rate = 0.7 + min(0.3, Double(speed) / 1400) }
        let before = amount[w] ?? 0
        let add = min(rate * dt, 1 - before)
        amount[w] = before + add
        let m = mouth
        if w == .milk, let i = streams.indices.last { streams[i].mouth = m }

        switch w {
        case .flour, .sugar:
            let n = Int((add * (w == .flour ? 190 : 150)).rounded(.up))
            for _ in 0..<n {
                seed += 1
                let s = seed
                let born = now.addingTimeInterval(-Double(fxRand(s, 1)) * dt)
                let jitter = w == .flour ? (fxRand(s, 7) - 0.5) * (8 + min(30, speed / 30)) : (fxRand(s, 7) - 0.5) * 8
                grains.append(Grain(born: born, p0: CGPoint(x: m.x + jitter, y: m.y), vx: -60 + 70 * fxRand(s, 5),
                                    vy: 20 + 40 * fxRand(s, 6), landY: BowlGeo.center.y - 4 + (fxRand(s, 8) - 0.5) * 22,
                                    flour: w == .flour, seed: s))
            }
            depositAcc += add
            while depositAcc > 0.12 {
                depositAcc -= 0.12
                let k = nextSeed()
                let L = BowlGeo.uv(CGPoint(x: m.x - 16, y: BowlGeo.center.y + 2))
                let p = clampUV(CGPoint(x: L.x + (fxRand(k, 1) - 0.5) * 0.3, y: L.y + (fxRand(k, 2) - 0.5) * 0.6))
                let fall = PourEvent.fallTime(from: m.y, to: BowlGeo.center.y, v0: 30)
                var b = Blob(p: p, r: 0.09 + 0.06 * fxRand(k, 3), raw: w == .flour ? RGB(hex: "#FFFFFF") : RGB(hex: "#FFFDF4"),
                             born: now.addingTimeInterval(fall))
                b.grainy = w == .sugar
                b.seed = k
                sim?.blobs.append(b)
            }
        default:
            let fall = PourEvent.fallTime(from: m.y, to: BowlGeo.center.y, v0: 30)
            sim?.growth.append((now.addingTimeInterval(fall), 0.35, CGFloat(add) * 0.86))
        }
        thudAcc += add
        if thudAcc > 0.3 {
            thudAcc = 0
            sim?.thuds.append(now.addingTimeInterval(0.2))
        }

        if (amount[w] ?? 0) >= 0.999 {
            finished.insert(w)
            endStream(now)
            pouring = false
            holding = nil
            return [w]
        }
        return []
    }

    private func endStream(_ now: Date) {
        if let i = streams.indices.last, streams[i].end == nil { streams[i].end = now }
    }

    private func nextSeed() -> Int { seed += 1; return seed * 7 + 3 }

    private func clampUV(_ p: CGPoint) -> CGPoint {
        let len = hypot(p.x, p.y)
        return len > 0.8 ? CGPoint(x: p.x * 0.8 / len, y: p.y * 0.8 / len) : p
    }

    // MARK: Drawing

    func draw(in g: GraphicsContext, now: Date) {
        drawGrains(g, now)
        drawStreams(g, now)
        drawBroken(g, now)
        drawButterDrops(g, now)
        drawHeld(g, now)
    }

    private func drawGrains(_ g: GraphicsContext, _ now: Date) {
        let G = BowlGeo.gravity
        for gr in grains {
            let tau = now.timeIntervalSince(gr.born)
            guard tau > 0 else { continue }
            let tl = PourEvent.fallTime(from: gr.p0.y, to: gr.landY, v0: gr.vy)
            let x = gr.p0.x + gr.vx * CGFloat(min(tau, tl))
            if tau < tl {
                let y = gr.p0.y + gr.vy * CGFloat(tau) + 0.5 * G * CGFloat(tau * tau)
                if gr.flour {
                    let s = 2.2 + 2.6 * fxRand(gr.seed, 9)
                    g.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s)), with: .color(.white.opacity(0.95)))
                } else {
                    let s = 1.6 + 1.6 * fxRand(gr.seed, 9)
                    let glint = gr.seed % 9 == 0 && sin(tau * 40 + Double(gr.seed)) > 0.3
                    let r = Path(CGRect(x: -s, y: -s, width: 2 * s, height: 2 * s))
                        .applying(CGAffineTransform(rotationAngle: CGFloat(gr.seed) + CGFloat(tau) * 12))
                        .applying(CGAffineTransform(translationX: x, y: y))
                    g.fill(r, with: .color(glint ? .white : RGB(hex: "#F4EEF8").color))
                    g.stroke(r, with: .color(RGB(hex: "#CFC3DD").color), lineWidth: 0.8)
                }
            } else if gr.flour && gr.seed % 4 == 0 {
                // a puff of flour dust where it lands, drifting up and out
                let a = tau - tl
                if a < 0.8 {
                    let k = CGFloat(a / 0.8)
                    let rr = 6 + 30 * k
                    var pg = g
                    pg.opacity = Double(0.38 * (1 - k))
                    pg.fill(Path(ellipseIn: CGRect(x: x - rr + 10 * (fxRand(gr.seed, 4) - 0.5) * k, y: gr.landY - rr * 0.7 - 26 * k,
                                                   width: rr * 2, height: rr * 1.4)), with: .color(.white))
                }
            }
        }
    }

    private func drawStreams(_ g: GraphicsContext, _ now: Date) {
        let col = RGB(hex: "#FDFCFF")
        for s in streams {
            let age = now.timeIntervalSince(s.start)
            let stopped = s.end.map { now.timeIntervalSince($0) }
            guard let ls = LiquidStream(mouth: s.mouth, floorY: BowlGeo.center.y + 2, vx: -26, width: 15, v0: 30,
                                        age: age, stopped: stopped, phase: age) else { continue }
            ls.draw(in: g, color: col)
            if ls.reachesFloor {
                ls.drawSplash(in: g, color: col, time: age, big: true)
                // rings spreading on the surface where it lands
                let L = BowlGeo.uv(ls.land)
                for k in 0..<3 {
                    let ph = (age + Double(k) * 0.33).truncatingRemainder(dividingBy: 1.0)
                    let rr = CGFloat(0.05 + 0.3 * ph)
                    let ring = Path(ellipseIn: CGRect(x: L.x - rr, y: L.y - rr * 1.4, width: rr * 2, height: rr * 2.8))
                        .applying(BowlGeo.plane)
                    var rg = g
                    rg.opacity = (1 - ph) * 0.6
                    rg.stroke(ring, with: .color(.white), lineWidth: 2.5)
                }
            }
        }
    }

    static func eggPath() -> Path { Path(ellipseIn: CGRect(x: -20, y: -27, width: 40, height: 54)) }

    private func drawEgg(_ g: GraphicsContext, at c: CGPoint, cracks: Int, now: Date) {
        let shell = RGB(hex: "#FFF8EC")
        let edge = RGB(hex: "#D9C6B4").color
        let since = now.timeIntervalSince(knockAt)
        let jolt = since < 0.3 ? CGFloat(sin(since * 40) * exp(-since * 10)) * 5 : 0
        var e = g
        e.translateBy(x: c.x, y: c.y - jolt)
        e.rotate(by: .degrees(-10 + Double(jolt) * 2))
        e.fill(HandsOnBowl.eggPath(), with: .color(shell.color))
        e.stroke(HandsOnBowl.eggPath(), with: .color(edge), lineWidth: 3)
        e.fill(Path(ellipseIn: CGRect(x: -12, y: -18, width: 8, height: 14)), with: .color(.white))
        if cracks > 0 {
            // a zigzag crack across the bottom of the shell
            var z = Path()
            z.move(to: CGPoint(x: -17, y: 10))
            z.addLine(to: CGPoint(x: -8, y: 4))
            z.addLine(to: CGPoint(x: -2, y: 12))
            z.addLine(to: CGPoint(x: 6, y: 3))
            z.addLine(to: CGPoint(x: 12, y: 10))
            z.addLine(to: CGPoint(x: 18, y: 6))
            e.stroke(z, with: .color(RGB(hex: "#A88E78").color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            if since < 0.35 {
                // a few shell flecks jump off
                for k in 0..<4 {
                    let a = CGFloat(since)
                    let vx = (CGFloat(k) - 1.5) * 60
                    let px = vx * a, py = 14 - 120 * a + 0.5 * BowlGeo.gravity * a * a
                    e.fill(Path(CGRect(x: px - 2, y: py - 2, width: 4, height: 4)), with: .color(shell.color))
                }
            }
        }
    }

    private func drawBroken(_ g: GraphicsContext, _ now: Date) {
        let shell = RGB(hex: "#FFF8EC")
        let edge = RGB(hex: "#D9C6B4").color
        for b in broken {
            let a = now.timeIntervalSince(b.at)
            guard a >= 0 else { continue }
            let center = b.center
            if a < 0.7 {
                let open = fxEase(a / 0.25)
                for side in [-1.0, 1.0] {
                    var h = g
                    h.opacity = Double(1 - fxEase((a - 0.4) / 0.3))
                    h.translateBy(x: center.x + CGFloat(side) * (4 + 20 * open), y: center.y - 4 * open)
                    h.rotate(by: .degrees(side * Double(70 * open)))
                    var half = Path()
                    let sx = CGFloat(side)
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
            // the egg slides out: clear white stretching around a bright yolk
            let drop = a - 0.12
            let y0 = center.y + 14
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

    static func drawButterBlock(_ g: GraphicsContext, at c: CGPoint, rot: Double, squash: CGFloat = 0) {
        var b = g
        b.translateBy(x: c.x, y: c.y)
        b.rotate(by: .degrees(rot))
        b.scaleBy(x: 1 + squash, y: 1 - squash)
        let block = RoundedRectangle(cornerRadius: 6, style: .continuous).path(in: CGRect(x: -34, y: -17, width: 68, height: 34))
        b.fill(block, with: .color(RGB(hex: "#FFE27A").color))
        b.stroke(block, with: .color(RGB(hex: "#D6A84A").color), lineWidth: 3)
        b.fill(RoundedRectangle(cornerRadius: 4, style: .continuous).path(in: CGRect(x: -30, y: -14, width: 60, height: 9)),
               with: .color(RGB(hex: "#FFF4B8").color))
    }

    private func drawButterDrops(_ g: GraphicsContext, _ now: Date) {
        for d in butter {
            let t = now.timeIntervalSince(d.at)
            let landY = BowlGeo.center.y - 8
            let tl = PourEvent.fallTime(from: d.from.y, to: landY)
            guard t >= 0, t < tl else { continue }
            let y = d.from.y + 0.5 * BowlGeo.gravity * CGFloat(t * t)
            HandsOnBowl.drawButterBlock(g, at: CGPoint(x: d.from.x - 10 * CGFloat(t / tl), y: y), rot: -20 * t / tl)
        }
    }

    private func drawHeld(_ g: GraphicsContext, _ now: Date) {
        guard let w = holding else { return }
        switch w {
        case .eggs:
            drawEgg(g, at: hand, cracks: knocks, now: now)
        case .butter:
            let wig = sin(now.timeIntervalSinceReferenceDate * 9) * 3
            HandsOnBowl.drawButterBlock(g, at: hand, rot: wig)
        case .flour, .sugar, .milk:
            var c = g
            c.translateBy(x: hand.x, y: hand.y)
            var a = angle
            if pouring && w == .flour { a += sin(now.timeIntervalSinceReferenceDate * 26) * 4 }
            if pouring && w == .sugar { a += sin(now.timeIntervalSinceReferenceDate * 20) * 3 }
            c.rotate(by: .degrees(a))
            c.scaleBy(x: PourEvent.scale, y: PourEvent.scale)
            c.translateBy(x: -80, y: -80)
            BakeryArt.shared.draw(w.rawValue, in: c)
            if pouring && w == .flour {
                // a soft column of powder falling from the bag
                let m = mouth
                var col = Path()
                col.move(to: CGPoint(x: m.x - 7, y: m.y))
                col.addLine(to: CGPoint(x: m.x + 7, y: m.y))
                col.addLine(to: CGPoint(x: m.x - 2, y: BowlGeo.center.y - 4))
                col.addLine(to: CGPoint(x: m.x - 30, y: BowlGeo.center.y - 4))
                col.closeSubpath()
                var cg = g
                cg.opacity = 0.3
                cg.fill(col, with: .color(.white))
            }
        case .flavor:
            break
        }
    }
}
