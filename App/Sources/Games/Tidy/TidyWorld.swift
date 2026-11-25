import SwiftUI
import UIKit

// MARK: - Tidy Up physics and play
//
// One `TidyWorld` per level. It runs a small rigid-body simulation for the loose items on the floor
// (gravity, bouncing, rolling, friction, items resting on each other), the item under her finger
// (follows with a little lag, swings like it's hanging from her fingers, gets pulled toward a slot
// it fits), and the snap into place (an under-damped spring, then a squash on landing that ripples
// into the neighbors). All in design points (DesignCanvas: 834 high, at least 1024 wide).
//
// Each item is a chain of circles along its long side, so a pencil rolls like a pencil and a book
// tips over. Contacts are solved with impulses (normal + Coulomb friction) and a little position
// correction, in 240 Hz substeps.

struct TVec {
    var x: CGFloat
    var y: CGFloat
    init(_ x: CGFloat, _ y: CGFloat) { self.x = x; self.y = y }
    init(_ p: CGPoint) { x = p.x; y = p.y }
    static let zero = TVec(0, 0)
    var pt: CGPoint { CGPoint(x: x, y: y) }
    var len: CGFloat { (x * x + y * y).squareRoot() }
    static func + (a: TVec, b: TVec) -> TVec { TVec(a.x + b.x, a.y + b.y) }
    static func - (a: TVec, b: TVec) -> TVec { TVec(a.x - b.x, a.y - b.y) }
    static func * (a: TVec, k: CGFloat) -> TVec { TVec(a.x * k, a.y * k) }
    static func += (a: inout TVec, b: TVec) { a = a + b }
    static func -= (a: inout TVec, b: TVec) { a = a - b }
    func dot(_ o: TVec) -> CGFloat { x * o.x + y * o.y }
    /// 2D cross product (z of a x b).
    func cross(_ o: TVec) -> CGFloat { x * o.y - y * o.x }
    func rotated(_ a: CGFloat) -> TVec {
        let c = cos(a), s = sin(a)
        return TVec(x * c - y * s, x * s + y * c)
    }
}

struct TCircle {
    let c: TVec
    let r: CGFloat
}

enum TidyBodyState { case waiting, loose, held, snapping, placed }

final class TidyBody {
    let id: Int
    let kind: TidyKind
    let color: Int
    let size: CGSize
    let circles: [TCircle]
    let bound: CGFloat
    let invMass: CGFloat
    let invInertia: CGFloat

    var pos = TVec.zero
    var vel = TVec.zero
    var angle: CGFloat = 0
    var spin: CGFloat = 0
    /// 0 resting, 1 lifted by a finger (bigger, higher shadow).
    var lift: CGFloat = 0
    var squash: CGFloat = 0
    var squashVel: CGFloat = 0
    var state = TidyBodyState.waiting
    var slot: Int?
    var spawnAt: Double = 0
    var lastSound: Double = -10
    var z = 0
    var onFloor = false

    init(id: Int, kind: TidyKind, color: Int) {
        self.id = id
        self.kind = kind
        self.color = color
        let s = kind.size
        size = s
        let long = max(s.width, s.height), short = min(s.width, s.height)
        let n = max(1, Int((long / short).rounded()))
        var cs: [TCircle] = []
        if n == 1 {
            cs.append(TCircle(c: .zero, r: (s.width + s.height) / 4 * 0.94))
        } else {
            let r = short / 2
            let span = long / 2 - r
            for i in 0..<n {
                let t = -span + 2 * span * CGFloat(i) / CGFloat(n - 1)
                cs.append(TCircle(c: s.width > s.height ? TVec(t, 0) : TVec(0, t), r: r))
            }
        }
        circles = cs
        bound = long / 2 + 2
        let m = max(0.4, s.width * s.height / 3000)
        invMass = 1 / m
        invInertia = 1 / (m * (s.width * s.width + s.height * s.height) / 12)
    }

    func world(_ c: TCircle) -> TVec { pos + c.c.rotated(angle) }

    /// Is the design-space point on this item (with a forgiving margin for small things)?
    func contains(_ p: TVec) -> Bool {
        let local = (p - pos).rotated(-angle)
        let mx = max(16, (64 - size.width) / 2), my = max(16, (64 - size.height) / 2)
        return abs(local.x) <= size.width / 2 + mx && abs(local.y) <= size.height / 2 + my
    }
}

struct TidyParticle {
    enum Kind { case sparkle, puff, confetti }
    var kind: Kind
    var pos: TVec
    var vel: TVec
    var born: Double
    var life: Double
    var size: CGFloat
    var color: TRGB
    var rot: CGFloat
    var spin: CGFloat
}

struct TidyRing {
    var pos: TVec
    var born: Double
    var color: TRGB
    var size: CGFloat
}

final class TidyWorld: ObservableObject {
    let level: TidyLevel
    @Published private(set) var complete = false
    /// Every slot is filled and the celebration has started (`complete` follows it on the next run loop).
    private(set) var isDone = false

    private(set) var bodies: [TidyBody] = []
    /// Which body fills each slot.
    private(set) var filled: [Int?]
    private(set) var particles: [TidyParticle] = []
    private(set) var rings: [TidyRing] = []
    private(set) var time: Double = 0
    private(set) var boxKick: CGFloat = 0
    private(set) var held: Int?
    /// The slot the held item would drop into right now.
    private(set) var hover: Int?
    private(set) var hint: (body: Int, slot: Int, at: Double)?
    private(set) var celebrateAt: Double?

    var size = CGSize(width: 1024, height: 834)
    private var lastDate: Date?
    private var finger = TVec.zero
    private var grab = TVec.zero
    private var touchStart: Double = 0
    private var lastAction: Double = 0
    private var combo = 0
    private(set) var lastPlace: Double = -10
    private var zCounter = 0
    private var heldVel = TVec.zero
    private var didReward = false
    private var launchRNG: TidySeededRNG?

    static let gravity: CGFloat = 2300
    static let sub: Double = 1.0 / 240
    /// Unified snap & hover magnet radius so fast flick drops always match glowing slots.
    static let snapRadius: CGFloat = 120
    static let completionRewardCoins = 4
    static let starBroomTreasureID = "tidy/starBroom"
    static let plushBearTreasureID = "tidy/plushBear"
    static var hasStarBroom: Bool { Coins.shared.owns(starBroomTreasureID) }
    static var hasPlushBear: Bool { Coins.shared.owns(plushBearTreasureID) }

    var floorY: CGFloat { size.height - 22 }
    var origin: TVec { TVec((size.width - TidyScene.size.width) / 2, 92) }
    var boxRect: CGRect { CGRect(x: 18, y: floorY - 118, width: 150, height: 118) }
    var placedCount: Int { filled.compactMap { $0 }.count }

    init(level: TidyLevel, prefill: Int = 0) {
        self.level = level
        filled = Array(repeating: nil, count: level.slots.count)
        // One item per slot, shuffled so the pile comes out of the box mixed up.
        var order = Array(level.slots.indices)
        if let seed = level.scatterSeed {
            var rng = TidySeededRNG(seed: seed ^ 0xA24B_AED4_963E_E407)
            order.shuffle(using: &rng)
            launchRNG = rng
        } else {
            var rng = SystemRandomNumberGenerator()
            order.shuffle(using: &rng)
        }
        for (n, i) in order.enumerated() {
            let s = level.slots[i]
            let b = TidyBody(id: bodies.count, kind: s.kind, color: s.color)
            b.spawnAt = 0.35 + Double(n) * 0.13
            bodies.append(b)
        }
        if prefill > 0 { placeSome(prefill) }
    }

    func slotPos(_ i: Int) -> TVec { origin + TVec(level.slots[i].pos) }

    // MARK: Rules

    func fits(_ b: TidyBody, _ i: Int) -> Bool {
        let s = level.slots[i]
        return s.kind == b.kind && (!s.strict || s.color == b.color)
    }

    /// Open: empty, and (in a stack) everything lower in the stack is already filled.
    func isOpen(_ i: Int) -> Bool {
        guard filled[i] == nil else { return false }
        let s = level.slots[i]
        guard let g = s.stack else { return true }
        for (j, o) in level.slots.enumerated() where j != i && o.stack == g && o.pos.y > s.pos.y + 8 {
            if filled[j] == nil { return false }
        }
        return true
    }

    /// True when slot `i` is the active bottom-most open slot of a multi-item stack with upper slots still waiting.
    func isActiveStackBase(_ i: Int) -> Bool {
        guard isOpen(i), let g = level.slots[i].stack else { return false }
        let y = level.slots[i].pos.y
        return level.slots.enumerated().contains { j, o in
            j != i && o.stack == g && filled[j] == nil && o.pos.y < y - 8
        }
    }

    /// A placed item can be lifted out unless something in its stack sits on top of it.
    func canLift(_ i: Int) -> Bool {
        let s = level.slots[i]
        guard let g = s.stack else { return true }
        for (j, o) in level.slots.enumerated() where j != i && o.stack == g && o.pos.y < s.pos.y - 8 {
            if filled[j] != nil { return false }
        }
        return true
    }

    func eligible(for b: TidyBody) -> [Int] {
        level.slots.indices.filter { isOpen($0) && fits(b, $0) }
    }

    private func nearestSlot(for b: TidyBody, within r: CGFloat) -> Int? {
        var best: Int?
        var bestD = r
        for i in eligible(for: b) {
            let d = (slotPos(i) - b.pos).len
            if d < bestD { bestD = d; best = i }
        }
        return best
    }

    /// Detects a near-miss drop on a wrong-color `strict` slot or a locked upper `stack` slot,
    /// returning the open slot that `b` actually belongs in so we can highlight it.
    private func rejectedHintSlot(for b: TidyBody, within r: CGFloat) -> Int? {
        var nearWrong: Int?
        var bestD = r
        for i in level.slots.indices where filled[i] == nil && level.slots[i].kind == b.kind {
            if isOpen(i) && fits(b, i) { continue }
            let d = (slotPos(i) - b.pos).len
            if d < bestD {
                bestD = d
                nearWrong = i
            }
        }
        guard let rejected = nearWrong else { return nil }
        let slot = level.slots[rejected]
        if let stackGroup = slot.stack, !isOpen(rejected) {
            if let base = level.slots.indices.first(where: {
                isOpen($0) && level.slots[$0].stack == stackGroup && fits(b, $0)
            }) {
                return base
            }
        }
        return eligible(for: b).first
    }

    // MARK: Touch

    func touchDown(_ p: CGPoint) {
        let v = TVec(p)
        finger = v
        touchStart = time
        lastAction = time
        hint = nil
        guard held == nil, let b = pick(v) else { return }
        if let s = b.slot {
            filled[s] = nil
            b.slot = nil
            if isDone { isDone = false; complete = false; celebrateAt = nil }
        }
        b.state = .held
        b.onFloor = false
        held = b.id
        grab = b.pos - carried(b, finger: v)
        heldVel = .zero
        zCounter += 1
        b.z = zCounter
        b.squashVel += 3
        TidySound.shared.play(.pickup, volume: 0.7, rate: Float(1.15 - min(0.3, b.size.height / 600)))
        TidySound.shared.haptic(.light)
    }

    func touchMoved(_ p: CGPoint) {
        finger = TVec(p)
        lastAction = time
    }

    func touchUp(_ p: CGPoint) {
        finger = TVec(p)
        lastAction = time
        guard let h = held else { return }
        held = nil
        let b = bodies[h]
        let near = hover ?? nearestSlot(for: b, within: Self.snapRadius)
        hover = nil
        if let s = near, isOpen(s), fits(b, s) {
            b.state = .snapping
            b.slot = s
            filled[s] = b.id
            b.vel = b.vel * 0.4
            TidySound.shared.play(.whoosh, volume: 0.25, rate: 1.3)
        } else {
            b.state = .loose
            var v = heldVel
            let sp = v.len
            if sp > 2600 { v = v * (2600 / sp) }
            b.vel = v
            b.spin += v.x * 0.002
            if let guideSlot = rejectedHintSlot(for: b, within: Self.snapRadius) {
                hint = (b.id, guideSlot, time)
                b.squashVel += 2.6
                TidySound.shared.play(.boop, volume: 0.45, rate: 0.92)
                TidySound.shared.haptic(.soft)
                let col = TidyPalette.c(b.color).light
                rings.append(TidyRing(pos: slotPos(guideSlot), born: time, color: col, size: max(b.size.width, b.size.height)))
            }
        }
    }

    private func pick(_ p: TVec) -> TidyBody? {
        let snapping = bodies.filter { $0.state == .snapping }
        let loose = bodies.filter { $0.state == .loose }.sorted { $0.z > $1.z }
        let placed = bodies.filter { $0.state == .placed }.sorted { ($0.slot ?? 0) > ($1.slot ?? 0) }
        for b in snapping + loose where b.contains(p) { return b }
        for b in placed where b.contains(p) {
            if let s = b.slot, canLift(s) { return b }
        }
        return nil
    }

    // MARK: Time

    func step(to date: Date) {
        guard let last = lastDate else { lastDate = date; return }
        var dt = date.timeIntervalSince(last)
        lastDate = date
        if dt <= 0 { return }
        dt = min(dt, 1.0 / 20)
        var left = dt
        while left > 1e-6 {
            let h = min(Self.sub, left)
            advance(h)
            left -= h
        }
        frameUpdate(dt)
    }

    /// Runs the world forward without a screen (tests, demos).
    func simulate(seconds: Double) {
        var t = 0.0
        while t < seconds {
            advance(Self.sub)
            t += Self.sub
            if Int(t * 240) % 4 == 0 { frameUpdate(Self.sub * 4) }
        }
    }

    private func advance(_ dt: Double) {
        time += dt
        let fdt = CGFloat(dt)
        for b in bodies where b.state == .waiting && time >= b.spawnAt { launch(b) }
        for b in bodies {
            switch b.state {
            case .waiting: break
            case .loose: integrateLoose(b, fdt)
            case .held: integrateHeld(b, fdt)
            case .snapping: integrateSnap(b, fdt)
            case .placed: integratePlaced(b, fdt)
            }
            // Squash and stretch spring.
            b.squashVel += (-b.squash * 900 - b.squashVel * 16) * fdt
            b.squash += b.squashVel * fdt
        }
        solveContacts(fdt)
        for b in bodies where b.state == .loose {
            b.pos += b.vel * fdt
            b.angle += b.spin * fdt
        }
    }

    private func launch(_ b: TidyBody) {
        b.state = .loose
        let r = boxRect
        if var rng = launchRNG {
            let ox = CGFloat(Double.random(in: -20...20, using: &rng))
            let vx = CGFloat(Double.random(in: 240...910, using: &rng))
            let vy = CGFloat(Double.random(in: -1260 ... -840, using: &rng))
            let ang = CGFloat(Double.random(in: -0.7...0.7, using: &rng))
            let sp = CGFloat(Double.random(in: -8...8, using: &rng))
            launchRNG = rng
            b.pos = TVec(r.midX + ox, r.minY - b.bound * 0.5)
            b.vel = TVec(vx, vy)
            b.angle = ang
            b.spin = sp
        } else {
            b.pos = TVec(r.midX + CGFloat.random(in: -20...20), r.minY - b.bound * 0.5)
            b.vel = TVec(CGFloat.random(in: 260...880), CGFloat.random(in: -1250 ... -850))
            b.angle = CGFloat.random(in: -0.6...0.6)
            b.spin = CGFloat.random(in: -7...7)
        }
        zCounter += 1
        b.z = zCounter
        boxKick = 1
        TidySound.shared.play(.pop, volume: 0.45, rate: Float.random(in: 0.9...1.25))
        for k in 0..<5 {
            addPuff(TVec(r.midX + CGFloat(k * 14 - 28), r.minY + 4), big: false)
        }
    }

    private func integrateLoose(_ b: TidyBody, _ dt: CGFloat) {
        b.vel.y += Self.gravity * dt
        b.vel = b.vel * (1 - 0.12 * dt)
        b.spin *= (1 - 0.9 * dt)
        b.lift = max(0, b.lift - dt * 6)
    }

    func lift(for b: TidyBody) -> CGFloat { FingerLift.carry(below: b.size.height * 0.5) }

    private func carried(_ b: TidyBody, finger f: TVec) -> TVec {
        TVec(FingerLift.point(f.pt, lift: lift(for: b), top: 0, bottom: size.height, width: size.width))
    }

    func finger(toHold b: TidyBody, at p: CGPoint) -> CGPoint {
        FingerLift.finger(for: p, lift: lift(for: b), top: 0, bottom: size.height, width: size.width)
    }

    private func integrateHeld(_ b: TidyBody, _ dt: CGFloat) {
        grab = grab * (1 - min(1, dt * 7))
        var target = carried(b, finger: finger) + grab
        var baseRot: CGFloat = 0
        hover = nearestSlot(for: b, within: Self.snapRadius)
        if let s = hover {
            let sp = slotPos(s)
            let d = (sp - b.pos).len
            let k = max(0, 1 - d / Self.snapRadius)
            target = target + (sp - target) * (0.38 * k)
            baseRot = level.slots[s].rot * min(1, k * 1.6)
        }
        let old = b.pos
        b.pos = b.pos + (target - b.pos) * min(1, dt * 30)
        let inst = (b.pos - old) * (1 / dt)
        heldVel = heldVel * 0.85 + inst * 0.15
        b.vel = heldVel
        let tilt = max(-0.5, min(0.5, heldVel.x * 0.00045))
        let goal = baseRot + tilt
        b.spin += (shortest(goal - b.angle) * 170 - b.spin * 17) * dt
        b.angle += b.spin * dt
        b.lift = min(1, b.lift + dt * 9)
    }

    private func integrateSnap(_ b: TidyBody, _ dt: CGFloat) {
        guard let s = b.slot else { b.state = .loose; return }
        let sp = slotPos(s)
        let acc = (sp - b.pos) * 520 - b.vel * 34
        b.vel += acc * dt
        b.pos += b.vel * dt
        let rot = level.slots[s].rot
        b.spin += (shortest(rot - b.angle) * 520 - b.spin * 34) * dt
        b.angle += b.spin * dt
        b.lift = max(0, b.lift - dt * 5)
        if (sp - b.pos).len < 2.5 && b.vel.len < 60 {
            land(b, s)
        }
    }

    private func integratePlaced(_ b: TidyBody, _ dt: CGFloat) {
        guard let s = b.slot else { return }
        b.pos = slotPos(s)
        b.angle = level.slots[s].rot
        b.vel = .zero
        b.spin = 0
        b.lift = 0
    }

    private func land(_ b: TidyBody, _ s: Int) {
        b.state = .placed
        b.pos = slotPos(s)
        b.angle = level.slots[s].rot
        b.squashVel -= 5.5
        combo = time - lastPlace < 5 ? combo + 1 : 0
        lastPlace = time
        let rate = Float(0.92 + 0.045 * Double(min(combo, 9)))
        TidySound.shared.place(b.kind.material, rate: rate)
        TidySound.shared.haptic(b.kind.material == .plush ? .soft : .rigid)
        for o in bodies where o.state == .placed && o.id != b.id {
            let d = (o.pos - b.pos).len
            if d < 160 { o.squashVel -= 2.2 * (1 - d / 160) }
        }
        let c = TidyPalette.c(b.color)
        rings.append(TidyRing(pos: b.pos, born: time, color: c.light, size: max(b.size.width, b.size.height)))
        let sparkColors: [TRGB] = [TRGB(0xFFE38A), TRGB.white, c.light]
        for k in 0..<9 {
            let a = Double(k) / 9 * 2 * Double.pi + Double.random(in: -0.2...0.2)
            let sp = CGFloat.random(in: 160...300)
            let v = TVec(CGFloat(cos(a)) * sp, CGFloat(sin(a)) * sp - 80)
            particles.append(TidyParticle(kind: .sparkle, pos: b.pos, vel: v, born: time, life: Double.random(in: 0.45...0.75),
                                          size: CGFloat.random(in: 9...16), color: sparkColors[k % 3], rot: 0,
                                          spin: CGFloat.random(in: -6...6)))
        }
        if Self.hasStarBroom {
            rings.append(TidyRing(pos: b.pos, born: time, color: TRGB(0xFFD559), size: max(b.size.width, b.size.height) * 1.25))
            let starlight: [TRGB] = [TRGB(0xFFCF4A), TRGB(0xFFF3A8), TRGB.white, TRGB(0xFFE07D)]
            for k in 0..<10 {
                let a = (Double(k) + 0.5) / 10 * 2 * Double.pi + Double.random(in: -0.18...0.18)
                let sp = CGFloat.random(in: 190...340)
                let v = TVec(CGFloat(cos(a)) * sp, CGFloat(sin(a)) * sp - 110)
                particles.append(TidyParticle(kind: .sparkle, pos: b.pos, vel: v, born: time, life: Double.random(in: 0.6...0.95),
                                              size: CGFloat.random(in: 12...20), color: starlight[k % starlight.count],
                                              rot: CGFloat.random(in: 0...(.pi)), spin: CGFloat.random(in: -7...7)))
            }
        }
        if filled.allSatisfy({ $0 != nil }) && bodies.allSatisfy({ $0.state == .placed || $0.id == b.id }) {
            celebrateAt = time + 0.25
        }
    }

    // MARK: Contacts

    @discardableResult
    private func resolve(_ a: TidyBody, _ b: TidyBody?, point: TVec, n: TVec, pen: CGFloat) -> CGFloat {
        let invMa = a.invMass, invIa = a.invInertia
        let invMb = b?.invMass ?? 0, invIb = b?.invInertia ?? 0
        let ra = point - a.pos
        let rb = b.map { point - $0.pos } ?? .zero
        let total = invMa + invMb
        let corr = max(0, pen - 0.4) * 0.6 / total
        a.pos += n * (corr * invMa)
        if let b = b { b.pos -= n * (corr * invMb) }

        let va = a.vel + TVec(-a.spin * ra.y, a.spin * ra.x)
        let vb = b.map { $0.vel + TVec(-$0.spin * rb.y, $0.spin * rb.x) } ?? .zero
        let rel = va - vb
        let vn = rel.dot(n)
        if vn >= 0 { return 0 }
        let raN = ra.cross(n), rbN = rb.cross(n)
        let k = invMa + invMb + raN * raN * invIa + rbN * rbN * invIb
        let e: CGFloat = vn < -320 ? 0.28 : 0
        let j = -(1 + e) * vn / k
        a.vel += n * (j * invMa)
        a.spin += raN * j * invIa
        if let b = b {
            b.vel -= n * (j * invMb)
            b.spin -= rbN * j * invIb
        }
        var t = rel - n * vn
        let tl = t.len
        if tl > 1e-4 {
            t = t * (1 / tl)
            let raT = ra.cross(t), rbT = rb.cross(t)
            let kt = invMa + invMb + raT * raT * invIa + rbT * rbT * invIb
            var jt = -rel.dot(t) / kt
            let mu: CGFloat = 0.55
            jt = max(-mu * j, min(mu * j, jt))
            a.vel += t * (jt * invMa)
            a.spin += raT * jt * invIa
            if let b = b {
                b.vel -= t * (jt * invMb)
                b.spin -= rbT * jt * invIb
            }
        }
        return j / max(0.001, invMa + invMb)
    }

    private func solveContacts(_ dt: CGFloat) {
        let loose = bodies.filter { $0.state == .loose }
        if loose.isEmpty { return }
        let box = boxRect
        for _ in 0..<2 {
            for b in loose {
                b.onFloor = false
                var hit: CGFloat = 0
                for c in b.circles {
                    let w = b.world(c)
                    if w.y + c.r > floorY {
                        hit = max(hit, resolve(b, nil, point: TVec(w.x, floorY), n: TVec(0, -1), pen: w.y + c.r - floorY))
                        b.onFloor = true
                    }
                    if w.x - c.r < 0 { resolve(b, nil, point: TVec(0, w.y), n: TVec(1, 0), pen: c.r - w.x) }
                    if w.x + c.r > size.width { resolve(b, nil, point: TVec(size.width, w.y), n: TVec(-1, 0), pen: w.x + c.r - size.width) }
                    let q = TVec(max(box.minX, min(box.maxX, w.x)), max(box.minY, min(box.maxY, w.y)))
                    let d = w - q
                    let dl = d.len
                    if dl < c.r {
                        if dl > 0.01 {
                            hit = max(hit, resolve(b, nil, point: q, n: d * (1 / dl), pen: c.r - dl))
                        } else {
                            resolve(b, nil, point: TVec(w.x, box.minY), n: TVec(0, -1), pen: w.y - box.minY + c.r)
                        }
                        b.onFloor = true
                    }
                }
                bump(b, hit)
            }
            for i in 0..<loose.count {
                let a = loose[i]
                for j in (i + 1)..<loose.count {
                    let b = loose[j]
                    if (a.pos - b.pos).len > a.bound + b.bound { continue }
                    var hit: CGFloat = 0
                    for ca in a.circles {
                        let wa = a.world(ca)
                        for cb in b.circles {
                            let wb = b.world(cb)
                            let d = wa - wb
                            let dl = d.len
                            if dl >= ca.r + cb.r { continue }
                            let n = dl > 0.01 ? d * (1 / dl) : TVec(0, -1)
                            let pen = ca.r + cb.r - dl
                            hit = max(hit, resolve(a, b, point: wb + n * (cb.r - pen / 2), n: n, pen: pen))
                        }
                    }
                    if hit > 0 { bump(a, hit * 0.7) }
                }
            }
        }
        for b in loose where b.onFloor {
            b.spin *= (1 - 2.5 * dt)
            b.vel.x *= (1 - 1.2 * dt)
        }
    }

    private func bump(_ b: TidyBody, _ impulse: CGFloat) {
        guard impulse > 260, time - b.lastSound > 0.12 else { return }
        b.lastSound = time
        let v = Float(min(1, (impulse - 260) / 1200))
        TidySound.shared.place(b.kind.material, volume: 0.15 + 0.4 * v, rate: Float.random(in: 0.8...1.0))
        if impulse > 700 { addPuff(TVec(b.pos.x, min(floorY, b.pos.y + b.bound * 0.6)), big: true) }
    }

    private func addPuff(_ p: TVec, big: Bool) {
        for _ in 0..<(big ? 4 : 1) {
            particles.append(TidyParticle(kind: .puff, pos: p + TVec(CGFloat.random(in: -14...14), 0),
                                          vel: TVec(CGFloat.random(in: -90...90), CGFloat.random(in: -70 ... -20)),
                                          born: time, life: Double.random(in: 0.4...0.7), size: CGFloat.random(in: 10...20),
                                          color: TRGB(0xFFFFFF), rot: 0, spin: 0))
        }
    }

    // MARK: Per-frame (effects, hints, celebration)

    private func frameUpdate(_ dt: Double) {
        let fdt = CGFloat(dt)
        boxKick = max(0, boxKick - fdt * 4)
        for i in particles.indices {
            var p = particles[i]
            switch p.kind {
            case .sparkle:
                p.vel.y += 380 * fdt
                p.vel = p.vel * (1 - 2.2 * fdt)
            case .puff:
                p.vel = p.vel * (1 - 3 * fdt)
            case .confetti:
                p.vel.y += 520 * fdt
                p.vel = p.vel * (1 - 1.6 * fdt)
                p.vel.x += CGFloat(sin((time - p.born) * 9 + Double(p.size))) * 260 * fdt
            }
            p.pos += p.vel * fdt
            p.rot += p.spin * fdt
            particles[i] = p
        }
        particles.removeAll { time - $0.born > $0.life }
        rings.removeAll { time - $0.born > 0.6 }

        if let c = celebrateAt, time >= c, !isDone {
            celebrate()
        }
        // A hint after a quiet while: a loose item hops and its slot glows.
        if !isDone && held == nil && time - lastAction > 8 && (hint == nil || time - (hint?.at ?? 0) > 6) {
            if let b = bodies.filter({ $0.state == .loose && $0.onFloor }).randomElement(), let s = eligible(for: b).first {
                hint = (b.id, s, time)
                b.vel.y -= 520
                b.spin += CGFloat.random(in: -3...3)
                b.squashVel += 4
                TidySound.shared.play(.boop, volume: 0.5, rate: 1.2)
            }
        }
    }

    private func celebrate() {
        isDone = true
        celebrateAt = nil
        if !didReward {
            didReward = true
            Coins.shared.earn(Self.completionRewardCoins, game: TidyGame.id, from: CGPoint(x: 512, y: 380))
            for find in TidyFind.unlocks(for: level) {
                StickerBook.shared.find(game: TidyGame.id, id: find.rawValue)
            }
        }
        DispatchQueue.main.async { [weak self] in self?.complete = self?.isDone ?? false }
        TidySound.shared.play(.chime, volume: 0.9)
        TidySound.shared.success()
        let sorted = bodies.sorted { $0.pos.x < $1.pos.x }
        for (i, b) in sorted.enumerated() {
            let delay = Double(i) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, b.state == .placed else { return }
                b.squashVel += 6
                self.particles.append(TidyParticle(kind: .sparkle, pos: b.pos + TVec(0, -b.size.height * 0.5), vel: TVec(0, -160),
                                                   born: self.time, life: 0.7, size: 16, color: TRGB(0xFFE38A), rot: 0, spin: 3))
            }
        }
        let colors = TidyPalette.colors
        for k in 0..<110 {
            let x = CGFloat.random(in: 0...size.width)
            particles.append(TidyParticle(kind: .confetti, pos: TVec(x, CGFloat.random(in: -120 ... -10)),
                                          vel: TVec(CGFloat.random(in: -120...120), CGFloat.random(in: 40...260)),
                                          born: time, life: Double.random(in: 2.4...3.6), size: CGFloat.random(in: 8...14),
                                          color: colors[k % 8], rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -9...9)))
        }
    }

    // MARK: Demo helpers

    /// Puts the first `n` items straight into their slots (screenshots and tests).
    func placeSome(_ n: Int) {
        var done = 0
        for b in bodies where done < n {
            guard let s = eligible(for: b).first else { continue }
            filled[s] = b.id
            b.slot = s
            b.state = .placed
            b.pos = slotPos(s)
            b.angle = level.slots[s].rot
            done += 1
        }
    }

    /// Tests: drop a body into a slot through the same path a finger uses.
    func testDrop(_ b: TidyBody, at p: CGPoint) {
        touchDown(b.pos.pt)
        if held == b.id {
            let f = finger(toHold: b, at: p)
            touchMoved(f)
            for _ in 0..<60 { advance(Self.sub) }
            touchUp(f)
        }
    }
}

private func shortest(_ a: CGFloat) -> CGFloat {
    var x = a.truncatingRemainder(dividingBy: 2 * .pi)
    if x > .pi { x -= 2 * .pi }
    if x < -.pi { x += 2 * .pi }
    return x
}
