import CoreGraphics
import Foundation

// MARK: - Pizza kitchen simulation
//
// Everything that moves on the pizza lives here, stepped every frame by the view (no SwiftUI state):
//
// - Dough: a shaggy ball she kneads with presses (each one folds it smoother), then a disc whose edge is 96 springy
//   radii. Pushing near the edge stretches it out; the dough remembers part of the stretch and springs back the rest
//   (gluten), and neighbouring radii pull together like a skin. A fast upward flick tosses it: it spins in the air and
//   lands bigger and rounder.
// - Sauce: a grid of amounts. The ladle pours where it's held still and the back of the ladle pushes the sauce along the
//   way it moves (mass is kept, a test checks), leveling it as it goes. It stops at the rim.
// - Cheese: shreds fall from the bowl with gravity and land where they fall (drawn into a bitmap, `ShredLayer`), and
//   each adds cheese to a second grid that melts, flows, bubbles and browns in the oven.
// - Toppings are placed pieces that plop down; pepperoni cups and gets glossy, basil wilts.
// - The oven bakes over ~9 s: the crust turns golden with charred spots, the cheese melts.
// - The cutter's cuts snap to lines through the middle; tapping a slice lifts it out with stretchy cheese strings and
//   the customer eats it.

enum PizzaStep: Int, CaseIterable {
    case dough, sauce, cheese, toppings, bake, slice
}

enum ToppingKind: String, CaseIterable, Codable {
    case pepperoni, mushroom, olive, pepper, pineapple, basil, tomato, ham
}

enum PizzaTool: Equatable {
    case ladle, cheese, cutter
    case topping(ToppingKind)
}

/// Geometry, in the 1024 x 834 design space.
enum PGeo {
    static let center = CGPoint(x: 476, y: 478)
    static let maxR: CGFloat = 228
    static let rim: CGFloat = 18
    /// The square the sauce and cheese grids cover, around the center.
    static let half: CGFloat = 240
    static let grid = 96
    static var cell: CGFloat { half * 2 / CGFloat(grid) }
    static let customer = CGPoint(x: 900, y: 236)
    static let mouth = CGPoint(x: 900, y: 262)
    static let card = CGPoint(x: 900, y: 452)
    static let designWidth: CGFloat = 1024
    static let designHeight: CGFloat = 834
    /// Where the pizza sits on the oven floor (the oven scene draws it squashed for perspective).
    static let ovenCenter = CGPoint(x: 512, y: 600)
    static let ovenSquash: CGFloat = 0.5
    static let ovenScale: CGFloat = 0.92
    static let knead = 6
    static let bakeTime: Double = 9
}

struct PizzaTopping {
    var kind: ToppingKind
    var x: CGFloat
    var y: CGFloat
    var rot: Double
    var scale: CGFloat
    var seed: Int
    var born: Double
    /// Where it flew in from (a tap on the tray), for the little arc.
    var from: CGPoint?
}

struct CheeseShred {
    var x: CGFloat, y: CGFloat, z: CGFloat
    var vx: CGFloat, vy: CGFloat, vz: CGFloat
    var ang: Double
    var len: CGFloat
    var curl: CGFloat
    var tone: CGFloat
}

enum PizzaPuffKind { case flour, steam, crumb, heart, smoke }

struct PizzaPuff {
    var kind: PizzaPuffKind
    var x: CGFloat, y: CGFloat
    var vx: CGFloat, vy: CGFloat
    var r: CGFloat
    var age: Double
    var life: Double
    var seed: Int
}

struct CheeseBubble {
    var x: CGFloat, y: CGFloat
    var age: Double
    var life: Double
    var size: CGFloat
}

struct OvenFlame {
    var x: CGFloat, y: CGFloat
    var vx: CGFloat, vy: CGFloat
    var age: Double
    var life: Double
    var size: CGFloat
    var spark: Bool
}

struct CheeseString {
    /// Where it hangs from on the pizza and on the lifted slice (pizza space, before the slice moves).
    var at: CGPoint
    var breakAt: CGFloat
    var broke: Double?
    var width: CGFloat
}

struct LiftedSlice {
    var a0: Double
    var a1: Double
    var start: Double
    var strings: [CheeseString]
    static let duration: Double = 1.35
}

struct PizzaOrder: Equatable {
    var customer: Int
    var wants: [ToppingKind]

    static let customers = ["bunny", "kitty", "bear", "puppy", "panda", "fox", "piggy", "frog"]

    static func random(customer: Int, seed: Int = Int.random(in: 0..<1_000_000)) -> PizzaOrder {
        var r = SeededRandom(seed)
        var kinds = ToppingKind.allCases
        var wants: [ToppingKind] = []
        let n = 1 + r.int(2)
        for _ in 0..<n {
            let i = r.int(kinds.count)
            wants.append(kinds.remove(at: i))
        }
        return PizzaOrder(customer: customer, wants: wants)
    }

    /// Enough of one wanted topping to count (a single piece is easy to miss on a big pizza).
    static let enough = 2

    func has(_ k: ToppingKind, _ toppings: [PizzaTopping]) -> Bool {
        toppings.filter { $0.kind == k }.count >= PizzaOrder.enough
    }

    /// Gentle stars: 3 when every wanted topping is on, 2 for some, and always at least 1.
    func stars(_ toppings: [PizzaTopping]) -> Int {
        let n = wants.filter { has($0, toppings) }.count
        return n == wants.count ? 3 : n > 0 ? 2 : 1
    }
}

struct PizzaSave: Codable {
    var hearts = 0
    var pizzas = 0
}

final class PizzaSim {
    static let gameID = "pizza"
    static let n = 96

    // time
    private(set) var time: Double = 0
    private var lastDate: Date?
    var demo = false
    /// Screenshot hooks: keeps a moment still (the bake, a toss in the air, a slice being lifted).
    var hold = false

    // the order and the customer
    var order = PizzaOrder.random(customer: Int.random(in: 0..<PizzaOrder.customers.count))
    var stars: Int?
    var happyUntil: Double = 0
    var chewUntil: Double = 0
    var wiggleAt: Double = -10
    var save = PizzaSave()

    var stage: PizzaStep = .dough

    // MARK: dough
    var ball = true
    var kneads = 0
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var ballShift = CGPoint.zero
    var pressing = false
    var r = [CGFloat](repeating: 100, count: PizzaSim.n)
    var rest = [CGFloat](repeating: 100, count: PizzaSim.n)
    var rv = [CGFloat](repeating: 0, count: PizzaSim.n)
    var lumps: [CGFloat]
    var dimples: [CGPoint] = []
    var flattenAt: Double = -10
    var tossStart: Double?
    var spin: Double = 0
    private var handVel = CGPoint.zero
    private var handStart = CGPoint.zero
    private var handLast = CGPoint.zero
    private var handMovedFar = false

    // MARK: sauce and cheese
    var sauce: [Float]
    var cheese: [Float]
    var browned: [Float]
    var sauceVersion = 0
    var cheeseVersion = 0
    let shredLayer = ShredLayer()
    var falling: [CheeseShred] = []
    var landed = 0
    var sauceCoverage: Double = 0
    var cheeseCoverage: Double = 0
    private var coverageAt: Double = 0
    private var sprinkleRate: CGFloat = 0
    private var spreadSpeed: CGFloat = 0

    // MARK: toppings
    var toppings: [PizzaTopping] = []

    // MARK: the oven
    var bake: Double = 0
    var inOven = false
    var ovenSlide: Double = 0
    var bubbles: [CheeseBubble] = []
    var flames: [OvenFlame] = []
    var flare: Double = 0
    var outAt: Double = -100
    private var dinged = false

    // MARK: slicing and serving
    var cuts: [Double] = []
    var stroke: [CGPoint] = []
    var groove: (pts: [CGPoint], at: Double)?
    var eaten: [(Double, Double)] = []
    var lifted: LiftedSlice?
    private var newPizzaAt: Double?

    // MARK: the held tool
    var tool: PizzaTool?
    var finger = CGPoint.zero
    var tip = CGPoint.zero
    var toolDown = false
    var ladleLoad: CGFloat = 1
    var wheel: Double = 0
    var liftK: CGFloat = 0
    var toolLast = CGPoint.zero

    var puffs: [PizzaPuff] = []
    var rng = SeededRandom(Int.random(in: 0..<1_000_000))

    init(load: Bool = true) {
        let g = PGeo.grid
        sauce = [Float](repeating: 0, count: g * g)
        cheese = [Float](repeating: 0, count: g * g)
        browned = [Float](repeating: 0, count: g * g)
        var lr = SeededRandom(5)
        lumps = (0..<PizzaSim.n).map { _ in CGFloat(lr.unit()) }
        // smooth the lumps into a few big bumps
        for _ in 0..<6 { lumps = PizzaSim.smoothed(lumps, 0.5) }
        let lo = lumps.min() ?? 0, hi = lumps.max() ?? 1
        lumps = lumps.map { ($0 - lo) / max(0.001, hi - lo) * 2 - 1 }
        if load, let s = GameStorage.load(PizzaSave.self, game: PizzaSim.gameID, file: "pizza.json") { save = s }
    }

    func persist() {
        guard !demo else { return }
        GameStorage.save(save, game: PizzaSim.gameID, file: "pizza.json")
    }

    // MARK: - Stepping

    func step(_ now: Date) {
        let dt = lastDate.map { min(1.0 / 30, max(0, now.timeIntervalSince($0))) } ?? 1.0 / 60
        lastDate = now
        step(dt: dt)
    }

    func step(dt: Double) {
        time += dt
        let d = CGFloat(dt)
        stepDough(d)
        stepTool(d)
        stepShreds(d)
        flowSauce()
        stepOven(dt)
        stepSlice(dt)
        stepPuffs(dt)
        if time - coverageAt > 0.25 {
            coverageAt = time
            sauceCoverage = coverage(sauce, above: 0.14)
            cheeseCoverage = coverage(cheese, above: 0.16)
        }
        if let t = newPizzaAt, time >= t { newPizzaAt = nil; newPizza() }
        stepSounds()
    }

    // MARK: - Dough

    /// The dough's edge distance from the center at angle `a` (radians).
    func edge(_ a: Double) -> CGFloat {
        if ball { return ballRadius }
        let n = PizzaSim.n
        var u = a / (2 * .pi)
        u -= floor(u)
        let f = u * Double(n)
        let i = Int(f) % n
        let j = (i + 1) % n
        let t = CGFloat(f - floor(f))
        return r[i] * (1 - t) + r[j] * t
    }

    var ballRadius: CGFloat { 104 }

    var meanR: CGFloat { ball ? ballRadius : r.reduce(0, +) / CGFloat(PizzaSim.n) }

    func angle(of p: CGPoint) -> Double {
        let a = atan2(Double(p.y - PGeo.center.y), Double(p.x - PGeo.center.x))
        return a < 0 ? a + 2 * .pi : a
    }

    func onDough(_ p: CGPoint, inset: CGFloat = 0) -> Bool {
        let d = hypot(p.x - PGeo.center.x, p.y - PGeo.center.y)
        return d < edge(angle(of: p)) - inset
    }

    static func smoothed(_ v: [CGFloat], _ k: CGFloat) -> [CGFloat] {
        let n = v.count
        var out = v
        for i in 0..<n {
            let avg = (v[(i + n - 1) % n] + v[(i + 1) % n]) * 0.5
            out[i] = v[i] + (avg - v[i]) * k
        }
        return out
    }

    private func stepDough(_ dt: CGFloat) {
        if ball {
            let target: CGFloat = pressing ? 1 : 0
            squashV += (240 * (target - squash) - 15 * squashV) * dt
            squash += squashV * dt
            if !pressing {
                ballShift.x -= ballShift.x * min(1, dt * 9)
                ballShift.y -= ballShift.y * min(1, dt * 9)
            }
            return
        }
        if hold, tossStart != nil { tossStart = time - 0.45 }
        if let t0 = tossStart {
            spin += Double(dt) * 7 * max(0.2, 1 - (time - t0) / tossDuration)
            if time - t0 >= tossDuration { land() }
        }
        let n = PizzaSim.n
        for i in 0..<n {
            let acc = 150 * (rest[i] - r[i]) - 11 * rv[i]
            rv[i] += acc * dt
            r[i] += rv[i] * dt
        }
        r = PizzaSim.smoothed(r, min(1, 5 * dt))
        rest = PizzaSim.smoothed(rest, min(1, 4 * dt))
        for i in 0..<n {
            r[i] = max(70, min(PGeo.maxR + 6, r[i]))
            rest[i] = max(70, min(PGeo.maxR, rest[i]))
        }
    }

    let tossDuration: Double = 1.05

    /// How high the tossed dough is (0 on the board, 1 at the top).
    var tossHeight: CGFloat {
        guard let t0 = tossStart else { return 0 }
        return CGFloat(sin(.pi * min(1, (time - t0) / tossDuration)))
    }

    /// Turns the kneaded ball into a disc.
    func flatten() {
        guard ball else { return }
        ball = false
        kneads = max(kneads, PGeo.knead)
        for i in 0..<PizzaSim.n {
            let lump = lumps[i] * 4
            r[i] = ballRadius + lump
            rest[i] = 128 + lump
            rv[i] = 90
        }
        flattenAt = time
        PizzaSound.shared.play(.slap, volume: 0.8)
        flourPuff(at: PGeo.center, count: 10, spread: 120)
    }

    private func land() {
        tossStart = nil
        let avg = meanR
        for i in 0..<PizzaSim.n {
            rest[i] = min(PGeo.maxR, rest[i] + (avg - rest[i]) * 0.6 + 16)
            r[i] = rest[i] - 14
            rv[i] = 120
        }
        dimples.removeAll()
        PizzaSound.shared.play(.slap)
        flourPuff(at: PGeo.center, count: 14, spread: avg + 20)
    }

    func handBegan(_ p: CGPoint) {
        handStart = p
        handLast = p
        handVel = .zero
        handMovedFar = false
        if hypot(p.x - PGeo.customer.x, p.y - PGeo.customer.y) < 100 {
            tickle()
            return
        }
        switch stage {
        case .dough:
            guard tossStart == nil else { return }
            if ball {
                guard hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < ballRadius + 50 else { return }
                if kneads >= PGeo.knead { flatten(); return }
                pressing = true
                PizzaSound.shared.play(.knead, volume: 0.8)
                flourPuff(at: p, count: 5, spread: 40)
            } else if onDough(p, inset: -40) {
                pressing = true
            }
        case .toppings:
            // pick a placed topping back up
            if let i = toppings.lastIndex(where: { hypot($0.x - p.x, $0.y - p.y) < 30 * $0.scale }) {
                let t = toppings.remove(at: i)
                pickUp(.topping(t.kind), finger: p)
                PizzaSound.shared.play(.plop, volume: 0.4)
            }
        case .bake:
            stoke()
        case .slice:
            serveSlice(at: p)
        default:
            break
        }
    }

    func handMoved(_ p: CGPoint, dt: CGFloat) {
        let d = CGPoint(x: p.x - handLast.x, y: p.y - handLast.y)
        handLast = p
        let k = min(1, dt * 18)
        handVel.x += (d.x / max(dt, 1.0 / 240) - handVel.x) * k
        handVel.y += (d.y / max(dt, 1.0 / 240) - handVel.y) * k
        if hypot(p.x - handStart.x, p.y - handStart.y) > 14 { handMovedFar = true }
        if case .topping? = tool { carry(p); return }
        guard stage == .dough, pressing else { return }
        if ball {
            ballShift.x = max(-34, min(34, ballShift.x + d.x * 0.3))
            ballShift.y = max(-34, min(34, ballShift.y + d.y * 0.3))
            return
        }
        stretch(at: p, by: d)
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        if case .topping? = tool { release(); return }
        guard stage == .dough else { return }
        if ball && pressing {
            pressing = false
            kneads += 1
            // a fold: the lumps turn over and get smaller
            let old = lumps
            let n = PizzaSim.n
            lumps = (0..<n).map { old[($0 + n / 3) % n] * 0.82 }
            PizzaSound.shared.play(kneads >= PGeo.knead ? .slap : .knead, volume: 0.7)
            if kneads == PGeo.knead { Sound.shared.play(.sparkle, volume: 0.5) }
            return
        }
        if pressing {
            pressing = false
            // a quick upward flick tosses it
            if handVel.y < -900 && abs(handVel.x) < abs(handVel.y) && tossStart == nil && onDough(handStart, inset: -30) {
                tossStart = time
                PizzaSound.shared.play(.toss)
                return
            }
            if tap && !handMovedFar && onDough(p) {
                if dimples.count > 40 { dimples.removeFirst() }
                dimples.append(CGPoint(x: p.x - PGeo.center.x, y: p.y - PGeo.center.y))
                PizzaSound.shared.play(.knead, volume: 0.35)
            }
        }
    }

    /// Fingers pushing the dough outward near `p`, moved by `d`.
    func stretch(at p: CGPoint, by d: CGPoint) {
        guard tossStart == nil else { return }
        let n = PizzaSim.n
        let len = hypot(d.x, d.y)
        guard len > 0.2 else { return }
        let dc = CGPoint(x: min(30, max(-30, d.x)), y: min(30, max(-30, d.y)))
        var gain: CGFloat = 0
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi
            let u = CGPoint(x: CGFloat(cos(a)), y: CGFloat(sin(a)))
            let e = CGPoint(x: PGeo.center.x + u.x * r[i], y: PGeo.center.y + u.y * r[i])
            let dist2 = (p.x - e.x) * (p.x - e.x) + (p.y - e.y) * (p.y - e.y)
            let w = exp(-dist2 / (2 * 85 * 85))
            guard w > 0.01 else { continue }
            let push = dc.x * u.x + dc.y * u.y
            let amount = push > 0 ? push * w : push * w * 0.25
            // bigger dough is thinner and harder to stretch further
            let room = max(0, 1 - (r[i] - 120) / (PGeo.maxR - 110))
            let s = amount * (push > 0 ? (0.35 + 0.65 * room) : 1)
            r[i] += s
            rest[i] += s * 0.6     // it keeps part of the stretch and springs back the rest
            gain += s
        }
        if gain > 0.5 { PizzaSound.shared.play(.stretch, volume: 0.45, gap: 0.32) }
    }

    // MARK: - Tools

    func pickUp(_ t: PizzaTool, finger p: CGPoint) {
        tool = t
        finger = p
        tip = p
        liftK = 0
        toolLast = p
        toolDown = false
        stroke = []
        if t == .ladle { ladleLoad = 1 }
    }

    /// How far above her finger each tool works (see `FingerLift`): the ladle and the wheel at her fingertip.
    func lift(for t: PizzaTool) -> CGFloat {
        switch t {
        case .ladle, .cutter: return FingerLift.tool
        case .cheese: return FingerLift.carry(below: 60)
        case .topping: return FingerLift.item
        }
    }

    func carry(_ p: CGPoint) {
        finger = p
        guard let t = tool else { return }
        let l = FingerLift.point(p, lift: lift(for: t), top: 0, bottom: PGeo.designHeight, width: PGeo.designWidth)
        tip = CGPoint(x: p.x + (l.x - p.x) * liftK, y: p.y + (l.y - p.y) * liftK)
    }

    /// Drops whatever she is holding.
    func release() {
        guard let t = tool else { return }
        switch t {
        case .cutter:
            finishCut()
        case .topping(let k):
            if !ball && onDough(tip, inset: 10) && stage != .bake {
                place(k, at: tip, from: nil)
            } else {
                flourPuff(at: tip, count: 3, spread: 16)
                PizzaSound.shared.play(.whoosh, volume: 0.4)
            }
        default:
            break
        }
        tool = nil
        toolDown = false
    }

    /// A tap on a tool in the dock: it does a helpful amount by itself.
    func tapTool(_ t: PizzaTool, from: CGPoint) {
        guard !ball else { flatten(); return }
        switch t {
        case .ladle:
            for _ in 0..<4 {
                let p = randomSpot(0.55)
                pour(at: p, amount: 6)
            }
            PizzaSound.shared.play(.glop)
        case .cheese:
            for _ in 0..<70 {
                let p = randomSpot(0.85)
                emitShred(at: p, spread: 6, z: CGFloat(rng.unit()) * 0.8 + 0.2)
            }
            PizzaSound.shared.play(.sprinkle, volume: 0.6)
        case .cutter:
            let options: [Double] = [0, .pi / 2, .pi / 4, 3 * .pi / 4, .pi / 8, 5 * .pi / 8, 3 * .pi / 8, 7 * .pi / 8]
            if let a = options.first(where: { o in !cuts.contains { abs(angleDiff($0, o)) < 0.15 } }) {
                addCut(a)
                groove = ([CGPoint(x: PGeo.center.x - CGFloat(cos(a)) * meanR, y: PGeo.center.y - CGFloat(sin(a)) * meanR),
                           CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * meanR, y: PGeo.center.y + CGFloat(sin(a)) * meanR)], time)
            }
        case .topping(let k):
            place(k, at: bestSpot(), from: from)
        }
    }

    func randomSpot(_ frac: CGFloat) -> CGPoint {
        let a = rng.unit() * 2 * .pi
        let d = CGFloat(sqrt(rng.unit())) * (meanR - PGeo.rim) * frac
        return CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * d, y: PGeo.center.y + CGFloat(sin(a)) * d)
    }

    /// A free spot for a topping: the one of a few tries farthest from the others.
    private func bestSpot() -> CGPoint {
        var best = randomSpot(0.82)
        var bestD: CGFloat = -1
        for _ in 0..<14 {
            let p = randomSpot(0.82)
            let d = toppings.map { hypot($0.x - p.x, $0.y - p.y) }.min() ?? 999
            if d > bestD { bestD = d; best = p }
        }
        return best
    }

    func place(_ k: ToppingKind, at p: CGPoint, from: CGPoint?) {
        if toppings.count >= 90 { toppings.removeFirst() }
        let seed = rng.int(10_000)
        let rot = rng.unit() * 360
        toppings.append(PizzaTopping(kind: k, x: p.x, y: p.y, rot: rot, scale: 0.92 + CGFloat(rng.unit()) * 0.16,
                                      seed: seed, born: time, from: from))
        if from == nil {
            PizzaSound.shared.play(.plop, volume: 0.8)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { PizzaSound.shared.play(.plop, volume: 0.7) }
        }
        if order.wants.contains(k) { happyUntil = time + 1.2 }
    }

    private func stepTool(_ dt: CGFloat) {
        guard let t = tool else { spreadSpeed = 0; sprinkleRate = 0; return }
        if liftK < 1 {
            liftK = min(1, liftK + dt / 0.16)
            carry(finger)
        }
        let move = CGPoint(x: tip.x - toolLast.x, y: tip.y - toolLast.y)
        let speed = hypot(move.x, move.y) / max(dt, 1.0 / 240)
        toolLast = tip
        switch t {
        case .ladle:
            toolDown = !ball && onDough(tip, inset: 4) && liftK > 0.9
            guard toolDown else { spreadSpeed = 0; return }
            if ladleLoad > 0 && speed < 260 {
                let pourNow = min(ladleLoad, dt * 0.9)
                ladleLoad -= pourNow
                pour(at: tip, amount: Float(pourNow) * 22)
                if pourNow > 0 { PizzaSound.shared.play(.glop, volume: 0.55, gap: 0.6) }
            }
            if hypot(move.x, move.y) > 0.3 { spread(at: tip, by: move) }
            spreadSpeed += (min(1, speed / 500) - spreadSpeed) * min(1, dt * 10)
        case .cheese:
            toolDown = hypot(tip.x - PGeo.center.x, tip.y - PGeo.center.y) < PGeo.maxR + 40 && liftK > 0.9
            guard toolDown else { sprinkleRate = 0; return }
            // a steady trickle, more when she shakes the bowl
            let rate = min(140, 22 + speed * 0.16)
            sprinkleRate = rate / 140
            var count = rate * dt
            while count > 0 {
                if CGFloat(rng.unit()) < count { emitShred(at: tip, spread: 22, z: 1, push: move) }
                count -= 1
            }
        case .cutter:
            let on = !ball && onDough(tip, inset: -6) && liftK > 0.9
            if on {
                if let last = stroke.last {
                    let dd = hypot(tip.x - last.x, tip.y - last.y)
                    if dd > 3 { stroke.append(tip); wheel += Double(dd) / 22 }
                } else {
                    stroke.append(tip)
                }
                spreadSpeed += (min(1, speed / 400) - spreadSpeed) * min(1, dt * 10)
            } else {
                spreadSpeed = 0
                if toolDown { finishCut() }   // rolled off the edge: that's one cut
            }
            toolDown = on
        case .topping:
            toolDown = !ball && onDough(tip, inset: 10)
        }
    }

    // MARK: - Sauce

    @inline(__always) func gridIndex(_ x: Int, _ y: Int) -> Int { y * PGeo.grid + x }

    /// The grid cell center for column/row.
    func cellCenter(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: PGeo.center.x - PGeo.half + (CGFloat(x) + 0.5) * PGeo.cell,
                y: PGeo.center.y - PGeo.half + (CGFloat(y) + 0.5) * PGeo.cell)
    }

    /// Is this cell on the dough, inside the rim?
    func inSauceArea(_ p: CGPoint, inset: CGFloat = PGeo.rim) -> Bool { !ball && onDough(p, inset: inset) }

    func pour(at p: CGPoint, amount: Float) {
        let g = PGeo.grid, c = PGeo.cell
        let cx = Int((p.x - (PGeo.center.x - PGeo.half)) / c), cy = Int((p.y - (PGeo.center.y - PGeo.half)) / c)
        // a puddle wider than her fingertip (see `FingerLift.spread`)
        let rad = Int((5 * FingerLift.spread).rounded())
        let sigma = Float(11 * FingerLift.spread)
        guard cx + rad >= 0, cy + rad >= 0, cx - rad < g, cy - rad < g else { return }
        var weights: [(Int, Float)] = []
        var total: Float = 0
        for y in max(0, cy - rad)...min(g - 1, cy + rad) {
            for x in max(0, cx - rad)...min(g - 1, cx + rad) {
                let q = cellCenter(x, y)
                guard inSauceArea(q) else { continue }
                let d2 = Float((q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y))
                let w = exp(-d2 / (2 * sigma * sigma))
                if w < 0.02 { continue }
                weights.append((gridIndex(x, y), w))
                total += w
            }
        }
        guard total > 0 else { return }
        // a ladle pours a puddle: amount is the height in the middle, spread over the weights
        for (i, w) in weights { sauce[i] += amount * w / total * 20 }
        sauceVersion &+= 1
        sauceFlowing = true
    }

    /// The back of the ladle pushing sauce along `d`.
    func spread(at p: CGPoint, by d: CGPoint) {
        let g = PGeo.grid, c = PGeo.cell
        let dl = hypot(d.x, d.y)
        let k = dl > 12 ? 12 / dl : 1
        let dx = d.x * k, dy = d.y * k
        let ox = PGeo.center.x - PGeo.half, oy = PGeo.center.y - PGeo.half
        let cx = Int((p.x - ox) / c), cy = Int((p.y - oy) / c)
        // the back of the ladle is wider than her fingertip (see `FingerLift.spread`)
        let rad = Int((7 * FingerLift.spread).rounded())
        let radPt = CGFloat(rad) * c
        var out = sauce
        var moved = false
        let y0 = max(0, cy - rad), y1 = min(g - 1, cy + rad)
        let x0 = max(0, cx - rad), x1 = min(g - 1, cx + rad)
        guard y0 <= y1, x0 <= x1 else { return }
        for y in y0...y1 {
            for x in x0...x1 {
                let i = gridIndex(x, y)
                let a = sauce[i]
                // the ladle leaves a thin film behind and pushes the rest along and out to its sides
                guard a > PizzaSim.sauceFilm else { continue }
                let q = cellCenter(x, y)
                let dist = hypot(q.x - p.x, q.y - p.y)
                let w = Float(max(0, 1 - dist / radPt))
                guard w > 0 else { continue }
                let m = (a - PizzaSim.sauceFilm) * 0.5 * w
                let ox = (q.x - p.x) / max(1, dist), oy = (q.y - p.y) / max(1, dist)
                let push = 8 * (1 - dist / radPt) + 2
                let tx = q.x + dx + ox * push, ty = q.y + dy + oy * push
                guard inSauceArea(CGPoint(x: tx, y: ty)) else { continue }
                out[i] -= m
                deposit(&out, x: tx, y: ty, m)
                moved = true
            }
        }
        if moved {
            sauce = out
            sauceVersion &+= 1
            sauceFlowing = true
        }
    }

    static let sauceFilm: Float = 0.15
    /// Above this the sauce is thick enough to slump and flow out by itself.
    static let sauceLevel: Float = 0.3
    var sauceFlowing = false

    /// Thick sauce slumps outward until it's level (mass is kept; it stops at the rim).
    func flowSauce() {
        guard sauceFlowing, !ball else { return }
        let g = PGeo.grid
        var mask = [Bool](repeating: false, count: g * g)
        for y in 0..<g { for x in 0..<g { mask[gridIndex(x, y)] = inSauceArea(cellCenter(x, y)) } }
        var out = sauce
        var any = false
        let lv = PizzaSim.sauceLevel
        for y in 1..<(g - 1) {
            for x in 1..<(g - 1) {
                let i = gridIndex(x, y)
                let e = sauce[i] - lv
                guard e > 0.002 else { continue }
                for k in 0..<4 {
                    let j = k == 0 ? i - 1 : k == 1 ? i + 1 : k == 2 ? i - g : i + g
                    guard mask[j] else { continue }
                    let ej = max(0, sauce[j] - lv)
                    if e > ej {
                        let f = 0.7 * (e - ej) / 4
                        out[i] -= f
                        out[j] += f
                        any = true
                    }
                }
            }
        }
        sauce = out
        sauceVersion &+= 1
        if !any { sauceFlowing = false }
    }

    /// Adds `m` at a point, shared bilinearly between the four nearest cells.
    func deposit(_ grid: inout [Float], x: CGFloat, y: CGFloat, _ m: Float) {
        let g = PGeo.grid, c = PGeo.cell
        let fx = (x - (PGeo.center.x - PGeo.half)) / c - 0.5
        let fy = (y - (PGeo.center.y - PGeo.half)) / c - 0.5
        let ix = Int(floor(fx)), iy = Int(floor(fy))
        let tx = Float(fx - CGFloat(ix)), ty = Float(fy - CGFloat(iy))
        let parts: [(Int, Int, Float)] = [(ix, iy, (1 - tx) * (1 - ty)), (ix + 1, iy, tx * (1 - ty)),
                                          (ix, iy + 1, (1 - tx) * ty), (ix + 1, iy + 1, tx * ty)]
        var lost: Float = 0
        for (x, y, w) in parts {
            if x >= 0, y >= 0, x < g, y < g { grid[gridIndex(x, y)] += m * w } else { lost += m * w }
        }
        if lost > 0 {
            let cx = min(g - 1, max(0, ix)), cy = min(g - 1, max(0, iy))
            grid[gridIndex(cx, cy)] += lost
        }
    }

    var totalSauce: Float { sauce.reduce(0, +) }

    /// The share of the area inside the rim that is covered.
    func coverage(_ grid: [Float], above: Float) -> Double {
        guard !ball else { return 0 }
        var inside = 0, covered = 0
        let g = PGeo.grid
        for y in stride(from: 0, to: g, by: 2) {
            for x in stride(from: 0, to: g, by: 2) {
                guard inSauceArea(cellCenter(x, y), inset: PGeo.rim + 6) else { continue }
                inside += 1
                if grid[gridIndex(x, y)] > above { covered += 1 }
            }
        }
        return inside == 0 ? 0 : Double(covered) / Double(inside)
    }

    // MARK: - Cheese

    func emitShred(at p: CGPoint, spread: CGFloat, z: CGFloat, push: CGPoint = .zero) {
        guard falling.count < 400 else { return }
        let a = rng.unit() * 2 * .pi
        let d = CGFloat(sqrt(rng.unit())) * spread
        falling.append(CheeseShred(x: p.x + CGFloat(cos(a)) * d, y: p.y + CGFloat(sin(a)) * d, z: z,
                             vx: CGFloat(rng.unit() - 0.5) * 70 + push.x * 4, vy: CGFloat(rng.unit() - 0.5) * 70 + push.y * 4,
                             vz: -0.5, ang: rng.unit() * .pi, len: 13 + CGFloat(rng.unit()) * 13,
                             curl: CGFloat(rng.unit() - 0.5) * 0.9, tone: CGFloat(rng.unit())))
    }

    private func stepShreds(_ dt: CGFloat) {
        guard !falling.isEmpty else { return }
        var keep: [CheeseShred] = []
        keep.reserveCapacity(falling.count)
        var any = false
        for var s in falling {
            s.vz -= 15 * dt
            s.z += s.vz * dt
            s.x += s.vx * dt
            s.y += s.vy * dt
            s.vx *= 1 - min(1, dt * 3)
            s.vy *= 1 - min(1, dt * 3)
            s.ang += Double(s.curl) * Double(dt) * 6
            if s.z <= 0 {
                let p = CGPoint(x: s.x, y: s.y)
                if !ball && onDough(p, inset: 4) && stage != .bake {
                    shredLayer.add(s, center: PGeo.center, half: PGeo.half)
                    deposit(&cheese, x: s.x, y: s.y, 0.16)
                    landed += 1
                    any = true
                }
                continue
            }
            keep.append(s)
        }
        falling = keep
        if any { cheeseVersion &+= 1 }
    }

    // MARK: - The oven

    var melt: Double { smooth(0.12, 0.55, bake) }
    var brown: Double { smooth(0.45, 1.0, bake) }

    func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    func enterOven() {
        guard !inOven else { return }
        if ball { flatten() }
        tool = nil
        inOven = true
        falling = []
        PizzaSound.shared.play(.oven)
    }

    func leaveOven() {
        guard inOven else { return }
        inOven = false
        outAt = time
        PizzaSound.shared.play(.oven, volume: 0.6)
    }

    func stoke() {
        flare = 1
        PizzaSound.shared.play(.whoosh, volume: 0.6)
        for _ in 0..<26 { spawnFlame(big: true) }
    }

    private func stepOven(_ dt: Double) {
        let want: Double = inOven ? 1 : 0
        ovenSlide += (want - ovenSlide) * min(1, dt * 4.5)
        if abs(want - ovenSlide) < 0.002 { ovenSlide = want }
        flare = max(0, flare - dt * 1.2)
        let fireOn = ovenSlide > 0.01
        if fireOn {
            var count = (55 + 80 * flare) * dt
            while count > 0 {
                if rng.unit() < count { spawnFlame(big: false) }
                count -= 1
            }
        }
        if !flames.isEmpty {
            var keep: [OvenFlame] = []
            keep.reserveCapacity(flames.count)
            for var f in flames {
                f.age += dt
                guard f.age < f.life else { continue }
                let sway = CGFloat(sin(time * 5 + Double(f.x) * 0.05)) * 26
                f.vx += (sway - f.vx) * CGFloat(min(1, dt * 3))
                f.x += f.vx * CGFloat(dt)
                f.y += f.vy * CGFloat(dt)
                f.vy -= CGFloat(dt) * (f.spark ? 40 : 60)
                keep.append(f)
            }
            flames = keep
        }
        guard inOven, ovenSlide > 0.85 else { stepBubbles(dt); return }
        let before = bake
        if !hold { bake = min(1, bake + dt / PGeo.bakeTime * (1 + flare)) }
        // melting cheese flows a little
        if melt > 0.02 && melt < 0.999 { flowCheese(Float(dt) * Float(melt) * 1.6) }
        if bake > 0.25 && bake < 1 {
            var count = 16 * dt * melt
            while count > 0 {
                if rng.unit() < count { spawnBubble() }
                count -= 1
            }
        }
        if before < 1 && bake >= 1 && !dinged {
            dinged = true
            PizzaSound.shared.play(.ding)
            Sound.shared.play(.sparkle, volume: 0.6)
        }
        stepBubbles(dt)
    }

    private func spawnFlame(big: Bool) {
        guard flames.count < 260 else { return }
        let spark = !big && rng.unit() < 0.1
        let x = 230 + CGFloat(rng.unit()) * 170
        flames.append(OvenFlame(x: x, y: 330 - CGFloat(rng.unit()) * 14, vx: CGFloat(rng.unit() - 0.5) * 30,
                            vy: spark ? -150 - CGFloat(rng.unit()) * 120 : -70 - CGFloat(rng.unit()) * 70 - (big ? 80 : 0),
                            age: 0, life: spark ? 1.4 : 0.55 + rng.unit() * 0.5 + (big ? 0.3 : 0),
                            size: spark ? 2.5 : (24 + CGFloat(rng.unit()) * 22) * (big ? 1.4 : 1), spark: spark))
    }

    private func spawnBubble() {
        guard bubbles.count < 70 else { return }
        let p = randomSpot(0.9)
        let g = PGeo.grid
        let fx = Int((p.x - (PGeo.center.x - PGeo.half)) / PGeo.cell), fy = Int((p.y - (PGeo.center.y - PGeo.half)) / PGeo.cell)
        guard fx >= 0, fy >= 0, fx < g, fy < g, cheese[gridIndex(fx, fy)] > 0.25 else { return }
        bubbles.append(CheeseBubble(x: p.x - PGeo.center.x, y: p.y - PGeo.center.y, age: 0, life: 0.6 + rng.unit() * 0.9,
                              size: 4 + CGFloat(rng.unit()) * 7))
    }

    private func stepBubbles(_ dt: Double) {
        guard !bubbles.isEmpty else { return }
        var keep: [CheeseBubble] = []
        for var b in bubbles {
            b.age += dt
            if b.age >= b.life {
                // a popped bubble leaves a browned spot
                let p = CGPoint(x: PGeo.center.x + b.x, y: PGeo.center.y + b.y)
                deposit(&browned, x: p.x, y: p.y, Float(b.size) * 0.12)
                cheeseVersion &+= 1
                PizzaSound.shared.play(.bubble, volume: 0.25, gap: 0.09)
                continue
            }
            keep.append(b)
        }
        bubbles = keep
    }

    /// Melting cheese spreads out from where it's thick.
    private func flowCheese(_ k: Float) {
        let g = PGeo.grid
        var out = cheese
        let kk = min(0.2, k)
        for y in 1..<(g - 1) {
            for x in 1..<(g - 1) {
                let i = gridIndex(x, y)
                let c = cheese[i]
                let lap = cheese[i - 1] + cheese[i + 1] + cheese[i - g] + cheese[i + g] - 4 * c
                // only cheese that's there flows, and it flows downhill
                if c > 0.02 || lap > 0 { out[i] = c + kk * lap }
            }
        }
        // keep it on the dough
        for y in 0..<g {
            for x in 0..<g {
                let i = gridIndex(x, y)
                if out[i] > 0 && !inSauceArea(cellCenter(x, y), inset: 6) { out[i] *= 0.9 }
                if out[i] < 0 { out[i] = 0 }
            }
        }
        cheese = out
        cheeseVersion &+= 1
    }

    // MARK: - Slicing and serving

    func angleDiff(_ a: Double, _ b: Double) -> Double {
        // cuts are lines: 0 and pi are the same cut
        var d = (a - b).truncatingRemainder(dividingBy: .pi)
        if d > .pi / 2 { d -= .pi }
        if d < -.pi / 2 { d += .pi }
        return d
    }

    @discardableResult
    func addCut(_ a: Double) -> Bool {
        var t = a.truncatingRemainder(dividingBy: .pi)
        if t < 0 { t += .pi }
        guard cuts.count < 8, !cuts.contains(where: { abs(angleDiff($0, t)) < 0.14 }) else { return false }
        cuts.append(t)
        PizzaSound.shared.play(.crunch)
        for _ in 0..<8 {
            let d = CGFloat(rng.unit() * 2 - 1) * meanR
            puffs.append(PizzaPuff(kind: .crumb, x: PGeo.center.x + CGFloat(cos(t)) * d, y: PGeo.center.y + CGFloat(sin(t)) * d,
                              vx: CGFloat(rng.unit() - 0.5) * 120, vy: -40 - CGFloat(rng.unit()) * 80, r: 2 + CGFloat(rng.unit()) * 2,
                              age: 0, life: 0.5, seed: rng.int(1000)))
        }
        return true
    }

    /// Turns the cutter's path into a cut, if it went across the pizza near the middle.
    func finishCut() {
        let pts = stroke
        stroke = []
        guard pts.count >= 2, let a = pts.first, let b = pts.last else { return }
        groove = (pts, time)
        let len = hypot(b.x - a.x, b.y - a.y)
        guard len > meanR * 0.85 else { return }
        // distance from the middle to the line through a and b
        let nx = -(b.y - a.y) / len, ny = (b.x - a.x) / len
        let dist = abs((PGeo.center.x - a.x) * nx + (PGeo.center.y - a.y) * ny)
        guard dist < meanR * 0.5 else { return }
        addCut(atan2(Double(b.y - a.y), Double(b.x - a.x)))
    }

    /// The slices as angle ranges (a0 < a1, in 0 ..< 4pi), or the whole pizza.
    var slices: [(Double, Double)] {
        guard !cuts.isEmpty else { return [(0, 2 * .pi)] }
        var angles = cuts.flatMap { [$0, $0 + .pi] }
        angles.sort()
        var out: [(Double, Double)] = []
        for i in 0..<angles.count {
            let a0 = angles[i]
            let a1 = i + 1 < angles.count ? angles[i + 1] : angles[0] + 2 * .pi
            out.append((a0, a1))
        }
        return out
    }

    func isEaten(_ a: Double) -> Bool {
        for (e0, e1) in eaten {
            for k in [-2.0, 0.0, 2.0] {
                let x = a + k * .pi
                if x > e0 && x < e1 { return true }
            }
        }
        return false
    }

    func slice(at p: CGPoint) -> (Double, Double)? {
        guard hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < meanR + 10 else { return nil }
        let a = angle(of: p)
        for s in slices {
            for k in [0.0, 2.0] {
                let x = a + k * .pi
                if x >= s.0 && x < s.1 { return isEaten((s.0 + s.1) / 2) ? nil : s }
            }
        }
        return nil
    }

    var allEaten: Bool { slices.allSatisfy { isEaten(($0.0 + $0.1) / 2) } }

    func serveSlice(at p: CGPoint) {
        guard lifted == nil, !ball, !inOven, let s = slice(at: p) else {
            if !ball && slice(at: p) == nil && hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < meanR { wiggleAt = time }
            return
        }
        var strings: [CheeseString] = []
        if melt > 0.2 || landed > 0 {
            let edges = s.1 - s.0 < 2 * .pi - 0.01 ? [s.0, s.1] : []
            for a in edges {
                for k in 0..<4 {
                    let d = meanR * (0.25 + 0.18 * CGFloat(k)) + CGFloat(rng.unit()) * 10
                    strings.append(CheeseString(at: CGPoint(x: CGFloat(cos(a)) * d, y: CGFloat(sin(a)) * d),
                                                breakAt: 40 + CGFloat(rng.unit()) * 130, broke: nil,
                                                width: 2 + CGFloat(rng.unit()) * 3))
                }
            }
        }
        lifted = LiftedSlice(a0: s.0, a1: s.1, start: time, strings: strings)
        PizzaSound.shared.play(strings.isEmpty ? .whoosh : .stretchy, volume: 0.8)
        if stars == nil {
            let st = order.stars(toppings)
            stars = st
            save.hearts += st
            save.pizzas += 1
            persist()
        }
    }

    /// How far a lifted slice has gone (0 ... 1) and where it is: its offset from the pizza and its scale.
    func liftedPose() -> (u: Double, dx: CGFloat, dy: CGFloat, scale: CGFloat, cx: CGFloat, cy: CGFloat)? {
        guard let l = lifted else { return nil }
        let u = min(1, (time - l.start) / LiftedSlice.duration)
        let mid = (l.a0 + l.a1) / 2
        let whole = l.a1 - l.a0 > 6
        let cx = whole ? 0 : CGFloat(cos(mid)) * meanR * 0.55
        let cy = whole ? 0 : CGFloat(sin(mid)) * meanR * 0.55
        // first it lifts and slides out a little (the cheese stretches), then it flies to the customer
        let pull = min(1, u / 0.38)
        let fly = max(0, (u - 0.38) / 0.62)
        let e = fly * fly * (3 - 2 * fly)
        let out = CGFloat(pull) * 46
        let ox = whole ? 0 : CGFloat(cos(mid)) * out
        let oy = (whole ? 0 : CGFloat(sin(mid)) * out) - CGFloat(pull) * 18
        let target = CGPoint(x: PGeo.mouth.x - PGeo.center.x - cx, y: PGeo.mouth.y - PGeo.center.y - cy)
        let dx = ox + (target.x - ox) * CGFloat(e)
        let dy = oy + (target.y - oy) * CGFloat(e) - CGFloat(sin(.pi * e)) * 60
        let scale = (1 + 0.06 * CGFloat(pull)) * (1 - 0.72 * CGFloat(e))
        return (u, dx, dy, scale, cx, cy)
    }

    private func stepSlice(_ dt: Double) {
        if hold, lifted != nil { lifted?.start = time - LiftedSlice.duration * 0.3 }
        guard var l = lifted, let pose = liftedPose() else { return }
        // cheese strings snap when stretched too far
        for i in l.strings.indices where l.strings[i].broke == nil {
            let s = l.strings[i]
            let stretch = hypot(pose.dx + (s.at.x - pose.cx) * (pose.scale - 1), pose.dy + (s.at.y - pose.cy) * (pose.scale - 1))
            if stretch > s.breakAt {
                l.strings[i].broke = time
                PizzaSound.shared.play(.snap, volume: 0.35, gap: 0.05)
            }
        }
        lifted = l
        if pose.u >= 1 {
            eaten.append((l.a0, l.a1))
            lifted = nil
            chewUntil = time + 1.3
            happyUntil = time + 2.2
            PizzaSound.shared.play(.nom)
            for k in 0..<5 {
                puffs.append(PizzaPuff(kind: .heart, x: PGeo.customer.x + CGFloat(k - 2) * 24, y: PGeo.customer.y - 60,
                                  vx: CGFloat(k - 2) * 14, vy: -70 - CGFloat(rng.unit()) * 40, r: 14, age: -Double(k) * 0.08,
                                  life: 1.4, seed: k))
            }
            if allEaten {
                PizzaSound.shared.play(.yay)
                Sound.shared.play(.fanfare, volume: 0.5)
                newPizzaAt = time + 2.6
            }
        }
    }

    func tickle() {
        happyUntil = time + 1
        wiggleAt = time
        Sound.shared.play(.boing, volume: 0.5)
    }

    // MARK: - A fresh pizza

    func newPizza() {
        var next = Int.random(in: 0..<PizzaOrder.customers.count)
        if next == order.customer { next = (next + 1) % PizzaOrder.customers.count }
        order = PizzaOrder.random(customer: next)
        reset()
        Sound.shared.play(.pop, volume: 0.6)
    }

    func reset() {
        stars = nil
        stage = .dough
        ball = true
        kneads = 0
        squash = 0
        r = [CGFloat](repeating: 100, count: PizzaSim.n)
        rest = r
        rv = [CGFloat](repeating: 0, count: PizzaSim.n)
        var lr = SeededRandom(rng.int(100_000))
        lumps = (0..<PizzaSim.n).map { _ in CGFloat(lr.unit()) }
        for _ in 0..<6 { lumps = PizzaSim.smoothed(lumps, 0.5) }
        let lo = lumps.min() ?? 0, hi = lumps.max() ?? 1
        lumps = lumps.map { ($0 - lo) / max(0.001, hi - lo) * 2 - 1 }
        dimples = []
        tossStart = nil
        let g = PGeo.grid
        sauce = [Float](repeating: 0, count: g * g)
        cheese = [Float](repeating: 0, count: g * g)
        browned = [Float](repeating: 0, count: g * g)
        sauceVersion &+= 1
        cheeseVersion &+= 1
        shredLayer.clear()
        falling = []
        landed = 0
        toppings = []
        bake = 0
        inOven = false
        bubbles = []
        dinged = false
        cuts = []
        stroke = []
        groove = nil
        eaten = []
        lifted = nil
        tool = nil
        sauceCoverage = 0
        cheeseCoverage = 0
        outAt = -100
    }

    /// Moves to a step (nothing is locked: any step at any time).
    func go(_ s: PizzaStep) {
        guard s != stage else { return }
        tool = nil
        if s != .dough && ball { flatten() }
        if stage == .bake { leaveOven() }
        stage = s
        if s == .bake { enterOven() }
    }

    /// Is this step done enough that the next one should be suggested?
    func ready(_ s: PizzaStep) -> Bool {
        switch s {
        case .dough: return !ball && meanR > 180 && tossStart == nil
        case .sauce: return sauceCoverage > 0.55
        case .cheese: return cheeseCoverage > 0.5
        case .toppings: return toppings.count >= 5
        case .bake: return bake >= 1
        case .slice: return stars != nil
        }
    }

    // MARK: - Puffs, steam, hearts

    func flourPuff(at p: CGPoint, count: Int, spread: CGFloat) {
        for _ in 0..<count {
            let a = rng.unit() * 2 * .pi
            let d = CGFloat(rng.unit()) * spread
            let x = p.x + CGFloat(cos(a)) * d, y = p.y + CGFloat(sin(a)) * d
            puffs.append(PizzaPuff(kind: .flour, x: x, y: y, vx: CGFloat(cos(a)) * 40, vy: CGFloat(sin(a)) * 40 - 10,
                              r: 8 + CGFloat(rng.unit()) * 12, age: 0, life: 0.7 + rng.unit() * 0.5, seed: rng.int(1000)))
        }
    }

    private func stepPuffs(_ dt: Double) {
        // steam off a hot pizza
        let hot = time - outAt
        if !inOven && bake > 0.35 && hot < 14 && stage != .bake {
            let rate = 9 * (1 - hot / 14)
            if rng.unit() < rate * dt {
                let p = randomSpot(0.8)
                puffs.append(PizzaPuff(kind: .steam, x: p.x, y: p.y, vx: CGFloat(rng.unit() - 0.5) * 10, vy: -30 - CGFloat(rng.unit()) * 20,
                                  r: 16 + CGFloat(rng.unit()) * 14, age: 0, life: 2 + rng.unit(), seed: rng.int(1000)))
            }
        }
        guard !puffs.isEmpty else { return }
        var keep: [PizzaPuff] = []
        keep.reserveCapacity(puffs.count)
        let d = CGFloat(dt)
        for var p in puffs {
            p.age += dt
            guard p.age < p.life else { continue }
            if p.age < 0 { keep.append(p); continue }
            p.x += p.vx * d
            p.y += p.vy * d
            switch p.kind {
            case .flour:
                p.vx *= 1 - min(1, d * 4)
                p.vy *= 1 - min(1, d * 4)
                p.r += d * 18
            case .steam:
                p.vx += CGFloat(sin(time * 2 + Double(p.seed))) * d * 14
                p.r += d * 14
            case .crumb:
                p.vy += d * 400
            case .heart:
                p.vy *= 1 - min(1, d * 0.8)
            case .smoke:
                p.r += d * 20
            }
            keep.append(p)
        }
        puffs = keep
    }

    // MARK: - Sounds that follow what's happening

    private func stepSounds() {
        let s = PizzaSound.shared
        let ladleSpreading = tool == .ladle && toolDown
        s.setLoop(.spread, volume: ladleSpreading ? Float(0.15 + 0.6 * spreadSpeed) : 0)
        s.setLoop(.sprinkle, volume: tool == .cheese && toolDown ? Float(0.2 + 0.5 * sprinkleRate) : 0)
        s.setLoop(.roll, volume: tool == .cutter && toolDown ? Float(0.15 + 0.7 * spreadSpeed) : 0)
        s.setLoop(.fire, volume: Float(ovenSlide * (0.55 + 0.35 * flare)))
        let sizzle = inOven ? melt * 0.8 : max(0, 1 - (time - outAt) / 6) * 0.4 * (bake > 0.3 ? 1 : 0)
        s.setLoop(.sizzle, volume: Float(sizzle))
    }
}

// MARK: - Cheese shreds drawn into a bitmap as they land

/// A bitmap of the shreds lying on the pizza (pizza space: the 480 pt square around the center, at 2x).
/// Shreds are drawn in once when they land, so a thousand of them cost nothing to show.
final class ShredLayer {
    static let scale: CGFloat = 2
    static let side = 480
    private let ctx: CGContext?
    private(set) var version = 0
    private var cached: CGImage?
    private var cachedVersion = -1

    init() {
        let px = Int(CGFloat(ShredLayer.side) * ShredLayer.scale)
        ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.translateBy(x: 0, y: CGFloat(px))
        ctx?.scaleBy(x: ShredLayer.scale, y: -ShredLayer.scale)
        ctx?.setLineCap(.round)
        ctx?.setLineJoin(.round)
    }

    func clear() {
        guard let c = ctx else { return }
        c.saveGState()
        c.setBlendMode(.copy)
        c.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
        c.fill(CGRect(x: 0, y: 0, width: ShredLayer.side, height: ShredLayer.side))
        c.restoreGState()
        version += 1
    }

    func add(_ s: CheeseShred, center: CGPoint, half: CGFloat) {
        guard let c = ctx else { return }
        let x = s.x - (center.x - half), y = s.y - (center.y - half)
        let dx = CGFloat(cos(s.ang)) * s.len / 2, dy = CGFloat(sin(s.ang)) * s.len / 2
        let nx = -dy * s.curl, ny = dx * s.curl
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x - dx, y: y - dy))
        path.addQuadCurve(to: CGPoint(x: x + dx, y: y + dy), control: CGPoint(x: x + nx, y: y + ny))
        let t = s.tone
        // a soft shadow, the shred, its lit top
        c.addPath(path)
        c.setStrokeColor(CGColor(red: 0.45, green: 0.3, blue: 0.1, alpha: 0.22))
        c.setLineWidth(6.4)
        c.saveGState()
        c.translateBy(x: 0.8, y: 1.6)
        c.strokePath()
        c.restoreGState()
        c.addPath(path)
        c.setStrokeColor(CGColor(red: 0.93 - 0.04 * t, green: 0.78 - 0.05 * t, blue: 0.38 - 0.08 * t, alpha: 1))
        c.setLineWidth(5.2)
        c.strokePath()
        c.addPath(path)
        c.setStrokeColor(CGColor(red: 1.0, green: 0.93 - 0.03 * t, blue: 0.6 - 0.1 * t, alpha: 1))
        c.setLineWidth(3.2)
        c.strokePath()
        c.saveGState()
        c.translateBy(x: -0.7, y: -0.9)
        c.addPath(path)
        c.setStrokeColor(CGColor(red: 1, green: 0.99, blue: 0.86, alpha: 0.85))
        c.setLineWidth(1.1)
        c.strokePath()
        c.restoreGState()
        version += 1
    }

    /// The current picture (made again at most when something new landed).
    var image: CGImage? {
        if cachedVersion != version {
            cached = ctx?.makeImage()
            cachedVersion = version
        }
        return cached
    }
}

// MARK: - Screenshot hooks

extension PizzaSim {
    /// Holds a tool still with its tip at `target`, as if her finger were under it.
    func holdTool(_ t: PizzaTool, at target: CGPoint) {
        let f = FingerLift.finger(for: target, lift: lift(for: t), top: 0, bottom: PGeo.designHeight, width: PGeo.designWidth)
        pickUp(t, finger: f)
        liftK = 1
        carry(f)
        toolLast = tip
    }

    /// A stretched-out disc of dough.
    func demoDisc(_ radius: CGFloat) {
        ball = false
        kneads = PGeo.knead
        for i in 0..<PizzaSim.n {
            r[i] = radius + lumps[i] * 3
            rest[i] = r[i]
            rv[i] = 0
        }
    }

    func demoSauce() {
        let g = PGeo.grid
        for y in 0..<g {
            for x in 0..<g {
                let p = cellCenter(x, y)
                guard inSauceArea(p) else { continue }
                let v = 0.62 + 0.25 * sin(Double(x) * 0.31) * cos(Double(y) * 0.27) + 0.12 * sin(Double(x + y) * 0.9)
                sauce[gridIndex(x, y)] = Float(v)
            }
        }
        sauceVersion &+= 1
        sauceCoverage = coverage(sauce, above: 0.14)
    }

    func demoCheese(_ count: Int) {
        for _ in 0..<count {
            let p = randomSpot(0.97)
            let s = CheeseShred(x: p.x, y: p.y, z: 0, vx: 0, vy: 0, vz: 0, ang: rng.unit() * .pi, len: 13 + CGFloat(rng.unit()) * 13,
                          curl: CGFloat(rng.unit() - 0.5) * 0.9, tone: CGFloat(rng.unit()))
            shredLayer.add(s, center: PGeo.center, half: PGeo.half)
            deposit(&cheese, x: p.x, y: p.y, 0.16)
            landed += 1
        }
        cheeseVersion &+= 1
        cheeseCoverage = coverage(cheese, above: 0.16)
    }

    func demoToppings() {
        let wanted = order.wants
        let kinds: [ToppingKind] = wanted + [.pepperoni, .basil, .mushroom].filter { !wanted.contains($0) }
        for (j, k) in kinds.prefix(3).enumerated() {
            for i in 0..<5 {
                let a = Double(i) / 5 * 2 * .pi + Double(j) * 0.7
                let d = CGFloat(60 + j * 52)
                place(k, at: CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * d, y: PGeo.center.y + CGFloat(sin(a)) * d), from: nil)
            }
        }
        for i in toppings.indices { toppings[i].born = -10 }
    }

    func demoSetup(_ name: String) {
        demo = true
        hold = true
        order = PizzaOrder.random(customer: 3, seed: 21)
        switch name {
        case "knead":
            kneads = 3
            pressing = true
            squash = 0.7
        case "stretch":
            demoDisc(176)
            dimples = [CGPoint(x: -40, y: -30), CGPoint(x: 30, y: 20), CGPoint(x: -10, y: 60), CGPoint(x: 70, y: -50)]
        case "toss":
            demoDisc(200)
            tossStart = time - 0.45
        case "sauce":
            stage = .sauce
            demoDisc(222)
            demoSauce()
            for y in 0..<PGeo.grid { for x in 0..<PGeo.grid where cellCenter(x, y).x > PGeo.center.x + 60 && cellCenter(x, y).y > PGeo.center.y - 30 { sauce[gridIndex(x, y)] = 0 } }
            pour(at: CGPoint(x: PGeo.center.x + 90, y: PGeo.center.y + 40), amount: 3)
            holdTool(.ladle, at: CGPoint(x: PGeo.center.x + 92, y: PGeo.center.y + 40))
            ladleLoad = 0.6
        case "cheese":
            stage = .cheese
            demoDisc(222)
            demoSauce()
            demoCheese(520)
            holdTool(.cheese, at: CGPoint(x: PGeo.center.x + 70, y: PGeo.center.y - 40))
        case "toppings":
            stage = .toppings
            demoDisc(222)
            demoSauce()
            demoCheese(900)
            demoToppings()
            holdTool(.topping(order.wants[0]), at: CGPoint(x: PGeo.center.x + 120, y: PGeo.center.y - 90))
        case "bake", "baked", "slice", "serve":
            demoDisc(222)
            demoSauce()
            demoCheese(900)
            demoToppings()
            if name == "bake" {
                stage = .bake
                bake = 0.62
                inOven = true
                ovenSlide = 1
                for _ in 0..<60 { step(dt: 1.0 / 60) }
            } else {
                bake = 1
                // let the melt flow and brown
                inOven = true
                ovenSlide = 1
                bake = 0.3
                hold = false
                for _ in 0..<Int(PGeo.bakeTime * 60) { step(dt: 1.0 / 60) }
                bake = 1
                hold = true
                inOven = false
                ovenSlide = 0
                flames = []
                outAt = time
                stage = .slice
                if name == "slice" {
                    addCut(0)
                    addCut(.pi / 2)
                    let a = 3 * Double.pi / 4
                    let R = meanR
                    let pts: [CGPoint] = (0..<20).map { k in
                        let d = -R + CGFloat(k) * R * 0.07
                        return CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * d, y: PGeo.center.y + CGFloat(sin(a)) * d)
                    }
                    holdTool(.cutter, at: pts.last ?? PGeo.center)
                    stroke = pts
                }
                if name == "serve" {
                    for a in [0, Double.pi / 4, Double.pi / 2, 3 * Double.pi / 4] { addCut(a) }
                    let s = slices[1]
                    let mid = (s.0 + s.1) / 2
                    serveSlice(at: CGPoint(x: PGeo.center.x + CGFloat(cos(mid)) * 120, y: PGeo.center.y + CGFloat(sin(mid)) * 120))
                }
            }
        default:
            break
        }
    }
}
