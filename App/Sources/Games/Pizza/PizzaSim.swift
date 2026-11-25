import CoreGraphics
import Foundation

// MARK: - Pizza kitchen simulation

enum PizzaStep: Int, CaseIterable {
    case dough, prep, bake, slice
}

enum CrustShape: String, CaseIterable, Codable {
    case round, heart, star, kitty

    static let profiles: [CrustShape: [CGFloat]] = {
        var out: [CrustShape: [CGFloat]] = [:]
        for shape in CrustShape.allCases {
            out[shape] = buildProfile(shape)
        }
        return out
    }()

    var profile: [CGFloat] {
        Self.profiles[self] ?? [CGFloat](repeating: 1, count: PizzaSim.n)
    }

    private static func wrapPi(_ a: Double) -> Double {
        var x = a
        while x > .pi { x -= 2 * .pi }
        while x < -.pi { x += 2 * .pi }
        return x
    }

    private static func buildProfile(_ shape: CrustShape) -> [CGFloat] {
        let n = PizzaSim.n
        switch shape {
        case .round:
            return (0..<n).map { i in
                let a = Double(i) / Double(n) * 2 * .pi
                return 0.99 + 0.012 * CGFloat(sin(a * 3 + 0.4))
            }
        case .heart:
            var samples: [(Double, CGFloat)] = []
            samples.reserveCapacity(720)
            var maxH: CGFloat = 0.001
            for k in 0..<720 {
                let t = Double(k) / 720.0 * 2 * .pi
                let s = sin(t)
                let x = CGFloat(16.5 * s * s * s)
                let y = CGFloat(-(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) - 2.2)
                var ang = atan2(Double(y), Double(x))
                if ang < 0 { ang += 2 * .pi }
                let dist = hypot(x, y)
                maxH = max(maxH, dist)
                samples.append((ang, dist))
            }
            samples.sort { $0.0 < $1.0 }
            let count = samples.count
            return (0..<n).map { i in
                let a = Double(i) / Double(n) * 2 * .pi
                var hi = 0
                var lo = count - 1
                for idx in 0..<count {
                    if samples[idx].0 >= a {
                        hi = idx
                        lo = (idx + count - 1) % count
                        break
                    }
                }
                let a0 = samples[lo].0
                var a1 = samples[hi].0
                if a1 < a0 { a1 += 2 * .pi }
                let aa = a < a0 ? a + 2 * .pi : a
                let u = CGFloat((aa - a0) / max(1e-6, a1 - a0))
                let norm = (samples[lo].1 + (samples[hi].1 - samples[lo].1) * u) / maxH
                return 0.16 + 0.86 * norm
            }
        case .star:
            return (0..<n).map { i in
                let a = Double(i) / Double(n) * 2 * .pi
                let w = cos(5 * (a + .pi / 2))
                return CGFloat(0.70 + 0.32 * pow(max(0.0, (w + 1) * 0.5), 1.35))
            }
        case .kitty:
            return (0..<n).map { i in
                let a = Double(i) / Double(n) * 2 * .pi
                let base = 0.82 + 0.045 * cos(2 * a)
                let dL = abs(wrapPi(a - (-.pi / 2 - 0.62)))
                let dR = abs(wrapPi(a - (-.pi / 2 + 0.62)))
                let ears = 0.25 * exp(-(dL * dL) / (2 * 0.18 * 0.18)) + 0.25 * exp(-(dR * dR) / (2 * 0.18 * 0.18))
                return CGFloat(base + ears)
            }
        }
    }
}

enum SauceKind: String, CaseIterable, Codable {
    case tomato, garlicWhite, goguma

    var paletteID: UInt8 {
        switch self {
        case .tomato: return 1
        case .garlicWhite: return 2
        case .goguma: return 3
        }
    }
}

enum CheeseKind: String, CaseIterable, Codable {
    case mozzarella, cornCheese
}

enum PrepTab: Int, CaseIterable {
    case sauces, cheeses, toppings
}

enum SliceMode: Equatable {
    case cut, serve
}

enum ToppingKind: String, CaseIterable, Codable {
    case pepperoni, mushroom, olive, pepper, pineapple, basil, tomato, ham, goguma, cornCheese
}

enum PizzaTool: Equatable {
    case rollingPin
    case sauceBrush(SauceKind)
    case cheeseShaker(CheeseKind)
    case topping(ToppingKind)
    case cutter
}

/// Geometry in the 1024 x 834 design space.
enum PGeo {
    static let center = CGPoint(x: 430, y: 408)
    static let maxR: CGFloat = 218
    static let rim: CGFloat = 18
    static let half: CGFloat = 240
    static let grid = 96
    static var cell: CGFloat { half * 2 / CGFloat(grid) }
    static let customer = CGPoint(x: 882, y: 214)
    static let mouth = CGPoint(x: 882, y: 242)
    static let card = CGPoint(x: 882, y: 424)
    static let actionButton = CGPoint(x: 882, y: 598)
    static let dockY: CGFloat = 740
    static let designWidth: CGFloat = 1024
    static let designHeight: CGFloat = 834
    static let ovenCenter = CGPoint(x: 512, y: 600)
    static let ovenSquash: CGFloat = 0.5
    static let ovenScale: CGFloat = 0.92
    static let bakeTime: Double = 3.5
}

struct RollingPinState {
    var dragging = false
    var pos = PGeo.center
    var angle: Double = -0.35
    var spin: Double = 0
    var sweepStart: Double?
    var sweepFrom = PGeo.center
    var sweepTo = PGeo.center
    var sweepAngle: Double = -0.35
    var sweepCount = 0
    static let sweepDuration: Double = 0.34

    func pose(at time: Double) -> (pos: CGPoint, angle: Double, spin: Double, opacity: Double)? {
        if dragging {
            return (pos, angle, spin, 1)
        }
        guard let t0 = sweepStart else { return nil }
        let u = (time - t0) / Self.sweepDuration
        guard u >= 0 && u < 1 else { return nil }
        let e = u * u * (3 - 2 * u)
        let px = sweepFrom.x + (sweepTo.x - sweepFrom.x) * CGFloat(e)
        let py = sweepFrom.y + (sweepTo.y - sweepFrom.y) * CGFloat(e)
        let fade = u < 0.15 ? u / 0.15 : (u > 0.78 ? (1 - u) / 0.22 : 1)
        return (CGPoint(x: px, y: py), sweepAngle, u * 10, max(0, min(1, fade)))
    }
}

struct PizzaTopping {
    var kind: ToppingKind
    var x: CGFloat
    var y: CGFloat
    var rot: Double
    var scale: CGFloat
    var seed: Int
    var born: Double
    var from: CGPoint?
}

struct CheeseShred {
    var x: CGFloat, y: CGFloat, z: CGFloat
    var vx: CGFloat, vy: CGFloat, vz: CGFloat
    var ang: Double
    var len: CGFloat
    var curl: CGFloat
    var tone: CGFloat
    var corn: Bool = false
}

enum PizzaPuffKind { case flour, steam, crumb, heart, aroma, smoke }

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
    var at: CGPoint
    var breakAt: CGFloat
    var broke: Double?
    var width: CGFloat
}

struct DraggedSlice {
    var a0: Double
    var a1: Double
    var startFinger: CGPoint
    var offset: CGPoint
    var strings: [CheeseString]
}

struct LiftedSlice {
    var a0: Double
    var a1: Double
    var start: Double
    var startOffset: CGPoint = .zero
    var strings: [CheeseString]
    static let duration: Double = 1.05
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

    static let enough = 2

    func has(_ k: ToppingKind, _ toppings: [PizzaTopping]) -> Bool {
        toppings.filter { $0.kind == k }.count >= PizzaOrder.enough
    }

    func stars(_ toppings: [PizzaTopping]) -> Int {
        let n = wants.filter { has($0, toppings) }.count
        return n == wants.count ? 3 : n > 0 ? 2 : 1
    }
}

struct PizzaSave: Codable {
    var hearts = 0
    var pizzas = 0
}

private enum SliceGestureKind {
    case none, undecided, cutting, draggingSlice
}

final class PizzaSim {
    static let gameID = "pizza"
    static let n = 96

    // time
    private(set) var time: Double = 0
    private var lastDate: Date?
    var demo = false
    var hold = false

    // order and customer
    var order: PizzaOrder
    var stars: Int?
    var paidThisPizza = false
    var happyUntil: Double = 0
    var chewUntil: Double = 0
    var wiggleAt: Double = -10
    var ovenNudgeAt: Double = -10
    var cutterNudgeAt: Double = -10
    var onAutoNewPizza: (() -> Void)?
    var onStateChange: (() -> Void)?
    var save = PizzaSave()

    var stage: PizzaStep = .dough
    var crustShape: CrustShape = .round
    var prepTab: PrepTab = .sauces
    var selectedSauce: SauceKind = .tomato
    var selectedCheese: CheeseKind = .mozzarella
    var selectedTopping: ToppingKind = .pepperoni
    var sliceMode: SliceMode = .cut

    // MARK: dough
    var ball = true
    var rollProgress: CGFloat = 0
    var rollPin = RollingPinState()
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var ballShift = CGPoint.zero
    var pressing = false
    var r = [CGFloat](repeating: 106, count: PizzaSim.n)
    var rest = [CGFloat](repeating: 106, count: PizzaSim.n)
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
    private var doughGestureActive = false
    private var prepGestureActive = false
    private var draggingToppingIndex: Int?
    private var sliceGestureKind: SliceGestureKind = .none

    // MARK: sauce and cheese
    var sauce: [Float]
    var saucePalette: [UInt8]
    var cheese: [Float]
    var browned: [Float]
    var cheeseKind: CheeseKind = .mozzarella
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

    // MARK: oven
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
    var draggedSlice: DraggedSlice?
    private var newPizzaAt: Double?

    // MARK: held tool
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
        let initialOrder = PizzaOrder.random(customer: Int.random(in: 0..<PizzaOrder.customers.count))
        order = initialOrder
        selectedTopping = initialOrder.wants.first ?? .pepperoni
        let g = PGeo.grid
        sauce = [Float](repeating: 0, count: g * g)
        saucePalette = [UInt8](repeating: 0, count: g * g)
        cheese = [Float](repeating: 0, count: g * g)
        browned = [Float](repeating: 0, count: g * g)
        var lr = SeededRandom(5)
        lumps = (0..<PizzaSim.n).map { _ in CGFloat(lr.unit()) }
        for _ in 0..<6 { lumps = PizzaSim.smoothed(lumps, 0.5) }
        let lo = lumps.min() ?? 0, hi = lumps.max() ?? 1
        lumps = lumps.map { ($0 - lo) / max(0.001, hi - lo) * 2 - 1 }
        if load, let s = GameStorage.load(PizzaSave.self, game: PizzaSim.gameID, file: "pizza.json") { save = s }
    }

    func persist() {
        guard !demo else { return }
        GameStorage.save(save, game: PizzaSim.gameID, file: "pizza.json")
    }

    private func notifyStateChange() {
        onStateChange?()
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
        if time - coverageAt > 0.18 {
            coverageAt = time
            sauceCoverage = coverage(sauce, above: 0.14)
            cheeseCoverage = coverage(cheese, above: 0.14)
        }
        if let t = newPizzaAt, time >= t {
            newPizzaAt = nil
            newPizza()
            let cb = onAutoNewPizza
            DispatchQueue.main.async { cb?() }
        }
        stepSounds()
    }

    // MARK: - Dough & Crust Shapes

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

    var ballRadius: CGFloat { 106 }

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

    /// Computes target contour radii for the current `crustShape` and `rollProgress`.
    private func syncDoughTargets(impulse: CGFloat = 0) {
        let baseR: CGFloat = 112 + (PGeo.maxR - 112) * max(0, min(1, rollProgress))
        let prof = crustShape.profile
        let lumpScale: CGFloat = crustShape == .round ? 2.6 : 1.0
        for i in 0..<PizzaSim.n {
            let target = min(PGeo.maxR + 12, max(78, baseR * prof[i] + lumps[i] * lumpScale))
            rest[i] = target
            if impulse != 0 { rv[i] += impulse }
        }
    }

    private func stepDough(_ dt: CGFloat) {
        if let t0 = rollPin.sweepStart, time - t0 >= RollingPinState.sweepDuration {
            rollPin.sweepStart = nil
        }
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
            spin += Double(dt) * 8 * max(0.2, 1 - (time - t0) / tossDuration)
            if time - t0 >= tossDuration { land() }
        }
        let n = PizzaSim.n
        for i in 0..<n {
            let acc = 190 * (rest[i] - r[i]) - 14 * rv[i]
            rv[i] += acc * dt
            r[i] += rv[i] * dt
        }
        r = PizzaSim.smoothed(r, min(1, 3.2 * dt))
        for i in 0..<n {
            r[i] = max(72, min(PGeo.maxR + 14, r[i]))
        }
    }

    let tossDuration: Double = 0.95

    var tossHeight: CGFloat {
        guard let t0 = tossStart else { return 0 }
        return CGFloat(sin(.pi * min(1, (time - t0) / tossDuration)))
    }

    func flatten(initialProgress: CGFloat = 0.36) {
        guard ball else { return }
        ball = false
        rollProgress = max(rollProgress, min(1, initialProgress))
        let prof = crustShape.profile
        for i in 0..<PizzaSim.n {
            r[i] = ballRadius * (0.94 + 0.06 * prof[i])
            rv[i] = 110
        }
        syncDoughTargets()
        flattenAt = time
        PizzaSound.shared.play(.slap, volume: 0.78)
        flourPuff(at: PGeo.center, count: 12, spread: 120)
        notifyStateChange()
    }

    /// Tapping anywhere on the dough sweeps the cartoon rolling pin across it and expands cleanly in 2-3 taps.
    func rollTap(at p: CGPoint) {
        guard tossStart == nil else { return }
        let wasBall = ball
        let stepGain: CGFloat = 0.38
        if ball {
            flatten(initialProgress: stepGain)
        } else {
            rollProgress = min(1, rollProgress + stepGain)
            syncDoughTargets(impulse: 85)
        }
        let sweepAngles: [Double] = [-0.45, 0.42, -0.12, 0.72]
        let a = sweepAngles[rollPin.sweepCount % sweepAngles.count]
        rollPin.sweepCount += 1
        let span = max(125, meanR * 0.82)
        let dir = CGPoint(x: CGFloat(cos(a)), y: CGFloat(sin(a)))
        rollPin.sweepFrom = CGPoint(x: PGeo.center.x - dir.x * span, y: PGeo.center.y - dir.y * span)
        rollPin.sweepTo = CGPoint(x: PGeo.center.x + dir.x * span, y: PGeo.center.y + dir.y * span)
        rollPin.sweepAngle = a + .pi / 2
        rollPin.sweepStart = time

        if wasBall {
            PizzaSound.shared.play(.knead, volume: 0.8)
        } else {
            PizzaSound.shared.play(.stretch, volume: 0.75, gap: 0.14)
        }
        if rollProgress >= 0.72 && rollProgress - stepGain < 0.72 {
            Sound.shared.play(.sparkle, volume: 0.55)
        }
        flourPuff(at: p, count: 8, spread: 64)
        notifyStateChange()
    }

    /// Swiping across the dough rolls the wooden pin directly under her finger and expands smoothly without snap-back.
    func rollDrag(from a: CGPoint, to b: CGPoint) {
        guard tossStart == nil else { return }
        let dx = b.x - a.x, dy = b.y - a.y
        let dist = hypot(dx, dy)
        guard dist > 0.5 else { return }
        if ball {
            flatten(initialProgress: 0.24)
        }
        let before = rollProgress
        rollProgress = min(1, rollProgress + dist / 330)
        syncDoughTargets(impulse: min(45, dist * 1.4))

        rollPin.dragging = true
        rollPin.pos = b
        rollPin.angle = atan2(Double(dy), Double(dx)) + .pi / 2
        rollPin.spin += Double(dist) * 0.08
        if dist > 6 {
            PizzaSound.shared.play(.stretch, volume: 0.55, gap: 0.22)
            if rng.unit() < 0.45 {
                flourPuff(at: b, count: 2, spread: 32)
            }
        }
        if before < 0.72 && rollProgress >= 0.72 {
            Sound.shared.play(.sparkle, volume: 0.55)
            notifyStateChange()
        }
    }

    /// Morphs the crust silhouette into Round, Heart, Star, or Kitty Ears with a springy boing and flour cloud.
    func setCrustShape(_ shape: CrustShape) {
        crustShape = shape
        if ball {
            ball = false
            rollProgress = max(rollProgress, 0.85)
            let prof = shape.profile
            for i in 0..<PizzaSim.n {
                r[i] = ballRadius * (0.9 + 0.1 * prof[i])
            }
            flattenAt = time
        } else {
            rollProgress = max(rollProgress, 0.76)
        }
        syncDoughTargets(impulse: 95)
        Sound.shared.play(.boing, volume: 0.78)
        flourPuff(at: PGeo.center, count: 16, spread: meanR * 0.9)
        notifyStateChange()
    }

    /// Optional celebratory spinning air toss!
    func triggerToss() {
        guard tossStart == nil else { return }
        if ball {
            flatten(initialProgress: 0.85)
        } else {
            rollProgress = max(rollProgress, 0.82)
            syncDoughTargets()
        }
        rollPin.dragging = false
        rollPin.sweepStart = nil
        tossStart = time
        PizzaSound.shared.play(.toss, volume: 0.9)
        flourPuff(at: PGeo.center, count: 14, spread: meanR)
        notifyStateChange()
    }

    private func land() {
        tossStart = nil
        rollProgress = 1.0
        syncDoughTargets(impulse: 120)
        for i in 0..<PizzaSim.n {
            r[i] = max(78, rest[i] - 12)
        }
        dimples.removeAll()
        PizzaSound.shared.play(.slap)
        Sound.shared.play(.sparkle, volume: 0.55)
        flourPuff(at: PGeo.center, count: 16, spread: meanR + 20)
        if !demo {
            StickerBook.shared.find(game: PizzaSim.gameID, id: PizzaFind.doughTosser.rawValue)
        }
        notifyStateChange()
    }

    // MARK: - Direct Touch Handling

    func handBegan(_ p: CGPoint) {
        handStart = p
        handLast = p
        handVel = .zero
        handMovedFar = false
        doughGestureActive = false
        prepGestureActive = false
        draggingToppingIndex = nil
        sliceGestureKind = .none

        if hypot(p.x - PGeo.customer.x, p.y - PGeo.customer.y) < 100 {
            tickle()
            return
        }

        switch stage {
        case .dough:
            guard tossStart == nil else { return }
            let reach = max(meanR + 68, 175)
            guard hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < reach else { return }
            doughGestureActive = true
            pressing = true
            if ball {
                PizzaSound.shared.play(.knead, volume: 0.7)
                flourPuff(at: p, count: 5, spread: 36)
            }

        case .prep:
            let reach = max(meanR + 48, 220)
            guard hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < reach else { return }
            if ball { flatten(initialProgress: 1.0) }
            prepGestureActive = true
            switch prepTab {
            case .sauces:
                tool = .sauceBrush(selectedSauce)
                finger = p
                tip = p
                toolLast = p
                toolDown = onDough(p, inset: 4)
                paintSauceStroke(from: p, to: p, kind: selectedSauce)
                PizzaSound.shared.play(.glop, volume: 0.65, gap: 0.2)
            case .cheeses:
                tool = .cheeseShaker(selectedCheese)
                finger = p
                tip = p
                toolLast = p
                toolDown = true
                cheeseKind = selectedCheese
                showerCheese(from: p, to: p, kind: selectedCheese, burst: 26)
                PizzaSound.shared.play(.sprinkle, volume: 0.65, gap: 0.25)
            case .toppings:
                let clamped = clampedInsideDough(p, inset: PGeo.rim + 12)
                place(selectedTopping, at: clamped, from: nil)
                draggingToppingIndex = toppings.count - 1
            }

        case .bake:
            if canPullFromOven && onOvenPizza(p) {
                go(.slice)
                return
            }
            stoke()

        case .slice:
            let reach = meanR + 75
            guard hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < reach else { return }
            if cuts.isEmpty {
                sliceGestureKind = .cutting
                tool = .cutter
                finger = p
                tip = p
                toolLast = p
                toolDown = onDough(p, inset: -16)
                stroke = [p]
            } else if sliceMode == .serve, lifted == nil, draggedSlice == nil, slice(at: p) != nil {
                beginSliceDrag(at: p)
            } else {
                sliceGestureKind = .undecided
            }
        }
    }

    func handMoved(_ p: CGPoint, dt: CGFloat) {
        let prev = handLast
        let d = CGPoint(x: p.x - prev.x, y: p.y - prev.y)
        handLast = p
        let k = min(1, dt * 18)
        handVel.x += (d.x / max(dt, 1.0 / 240) - handVel.x) * k
        handVel.y += (d.y / max(dt, 1.0 / 240) - handVel.y) * k
        if hypot(p.x - handStart.x, p.y - handStart.y) > 14 { handMovedFar = true }

        // If carrying a topping dragged directly from the bottom bar
        if case .topping? = tool {
            carry(p)
            return
        }

        switch stage {
        case .dough:
            guard doughGestureActive else { return }
            if hypot(p.x - handStart.x, p.y - handStart.y) > 12 {
                rollDrag(from: prev, to: p)
            } else if ball {
                ballShift.x = max(-28, min(28, ballShift.x + d.x * 0.35))
                ballShift.y = max(-28, min(28, ballShift.y + d.y * 0.35))
            }

        case .prep:
            guard prepGestureActive else { return }
            let speed = hypot(d.x, d.y) / max(dt, 1.0 / 240)
            switch prepTab {
            case .sauces:
                finger = p
                tip = p
                toolLast = p
                toolDown = onDough(p, inset: -8)
                paintSauceStroke(from: prev, to: p, kind: selectedSauce)
                spreadSpeed += (min(1, speed / 450) - spreadSpeed) * min(1, dt * 12)
            case .cheeses:
                finger = p
                tip = p
                toolLast = p
                toolDown = hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < PGeo.maxR + 65
                showerCheese(from: prev, to: p, kind: selectedCheese, burst: 0)
                sprinkleRate = min(1, 0.35 + speed / 600)
            case .toppings:
                if let idx = draggingToppingIndex, idx < toppings.count {
                    let clamped = clampedInsideDough(p, inset: PGeo.rim + 10)
                    toppings[idx].x = clamped.x
                    toppings[idx].y = clamped.y
                }
            }

        case .bake:
            break

        case .slice:
            switch sliceGestureKind {
            case .undecided:
                if hypot(p.x - handStart.x, p.y - handStart.y) >= 18 {
                    // Pulling outward past the rim toward the customer window starts a live cheese pull!
                    let movingRightTowardCustomer = (p.x - handStart.x) > 22 && handStart.x > PGeo.center.x - 10 && p.x > PGeo.center.x + meanR * 0.45
                    if movingRightTowardCustomer && slice(at: handStart) != nil && lifted == nil && !isUnbakedEmptyDough {
                        beginSliceDrag(at: handStart)
                        updateSliceDrag(to: p)
                    } else {
                        sliceGestureKind = .cutting
                        tool = .cutter
                        finger = p
                        tip = p
                        toolLast = p
                        toolDown = true
                        stroke = [handStart, p]
                    }
                }
            case .cutting:
                finger = p
                tip = p
                toolLast = p
                toolDown = hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < meanR + 75
                if let last = stroke.last {
                    let dd = hypot(p.x - last.x, p.y - last.y)
                    if dd > 3 {
                        stroke.append(p)
                        wheel += Double(dd) / 22
                    }
                } else {
                    stroke.append(p)
                }
                let speed = hypot(d.x, d.y) / max(dt, 1.0 / 240)
                spreadSpeed += (min(1, speed / 400) - spreadSpeed) * min(1, dt * 10)
            case .draggingSlice:
                updateSliceDrag(to: p)
            case .none:
                break
            }
        }
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        if case .topping? = tool {
            release()
            return
        }

        switch stage {
        case .dough:
            let wasActive = doughGestureActive
            doughGestureActive = false
            pressing = false
            rollPin.dragging = false
            guard wasActive else { return }
            if handVel.y < -820 && abs(handVel.x) < abs(handVel.y) && tossStart == nil {
                triggerToss()
                return
            }
            if tap || !handMovedFar {
                rollTap(at: p)
            } else {
                notifyStateChange()
            }

        case .prep:
            prepGestureActive = false
            draggingToppingIndex = nil
            if prepTab == .sauces || prepTab == .cheeses {
                tool = nil
                toolDown = false
                spreadSpeed = 0
                sprinkleRate = 0
                coverageAt = -1
            }
            notifyStateChange()

        case .bake:
            break

        case .slice:
            switch sliceGestureKind {
            case .cutting:
                if let last = stroke.last, hypot(p.x - last.x, p.y - last.y) > 2 {
                    stroke.append(p)
                }
                finishCut()
                tool = nil
                toolDown = false
                spreadSpeed = 0
                if cuts.isEmpty && (tap || !handMovedFar) {
                    wiggleAt = time
                    cutterNudgeAt = time
                    Sound.shared.play(.boing, volume: 0.45)
                }
            case .draggingSlice:
                finishSliceDrag()
            case .undecided:
                if !cuts.isEmpty {
                    serveSlice(at: p)
                } else {
                    wiggleAt = time
                    cutterNudgeAt = time
                    Sound.shared.play(.boing, volume: 0.45)
                }
            case .none:
                break
            }
            sliceGestureKind = .none
            notifyStateChange()
        }
    }

    private func clampedInsideDough(_ p: CGPoint, inset: CGFloat) -> CGPoint {
        let a = angle(of: p)
        let maxD = max(24, edge(a) - inset)
        let d = hypot(p.x - PGeo.center.x, p.y - PGeo.center.y)
        guard d > maxD else { return p }
        return CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * maxD, y: PGeo.center.y + CGFloat(sin(a)) * maxD)
    }

    // MARK: - Tools (dock drag-and-drop for toppings + test/demo hooks)

    func pickUp(_ t: PizzaTool, finger p: CGPoint) {
        tool = t
        finger = p
        tip = p
        liftK = 0
        toolLast = p
        toolDown = false
        stroke = []
        if case .topping(let k) = t {
            selectedTopping = k
            prepTab = .toppings
        }
        if case .sauceBrush(let s) = t {
            selectedSauce = s
            ladleLoad = 1
        }
        if case .cheeseShaker(let c) = t {
            selectedCheese = c
            cheeseKind = c
        }
    }

    func lift(for t: PizzaTool) -> CGFloat {
        switch t {
        case .rollingPin: return 0
        case .sauceBrush, .cutter: return FingerLift.tool
        case .cheeseShaker: return FingerLift.carry(below: 60)
        case .topping: return FingerLift.item
        }
    }

    func carry(_ p: CGPoint) {
        finger = p
        guard let t = tool else { return }
        let l = FingerLift.point(p, lift: lift(for: t), top: 0, bottom: PGeo.designHeight, width: PGeo.designWidth)
        tip = CGPoint(x: p.x + (l.x - p.x) * liftK, y: p.y + (l.y - p.y) * liftK)
    }

    func release() {
        guard let t = tool else { return }
        switch t {
        case .cutter:
            finishCut()
        case .topping(let k):
            if !ball && onDough(tip, inset: 8) && stage != .bake {
                place(k, at: clampedInsideDough(tip, inset: PGeo.rim + 8), from: nil)
            } else {
                flourPuff(at: tip, count: 3, spread: 16)
                PizzaSound.shared.play(.whoosh, volume: 0.4)
            }
        default:
            break
        }
        tool = nil
        toolDown = false
        notifyStateChange()
    }

    func selectSauce(_ kind: SauceKind) {
        selectedSauce = kind
        prepTab = .sauces
        if ball { flatten(initialProgress: 1.0) }
        notifyStateChange()
    }

    func selectCheese(_ kind: CheeseKind) {
        selectedCheese = kind
        cheeseKind = kind
        prepTab = .cheeses
        if ball { flatten(initialProgress: 1.0) }
        notifyStateChange()
    }

    func selectTopping(_ kind: ToppingKind) {
        selectedTopping = kind
        prepTab = .toppings
        if ball { flatten(initialProgress: 1.0) }
        notifyStateChange()
    }

    func randomSpot(_ frac: CGFloat) -> CGPoint {
        let a = rng.unit() * 2 * .pi
        let edgeR = max(30, edge(a) - PGeo.rim)
        let d = CGFloat(sqrt(rng.unit())) * edgeR * frac
        return CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * d, y: PGeo.center.y + CGFloat(sin(a)) * d)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { PizzaSound.shared.play(.plop, volume: 0.7) }
        }
        if order.wants.contains(k) { happyUntil = time + 1.2 }
        notifyStateChange()
    }

    private func stepTool(_ dt: CGFloat) {
        guard let t = tool else {
            if !prepGestureActive && sliceGestureKind != .cutting {
                spreadSpeed = 0
                sprinkleRate = 0
            }
            return
        }
        if case .topping = t {
            if liftK < 1 {
                liftK = min(1, liftK + dt / 0.14)
                carry(finger)
            }
            toolDown = !ball && onDough(tip, inset: 8)
        } else if !prepGestureActive && sliceGestureKind != .cutting {
            // Support direct programmatic holdTool(...) calls in demos/tests
            if liftK < 1 {
                liftK = min(1, liftK + dt / 0.16)
                carry(finger)
            }
            switch t {
            case .sauceBrush(let kind):
                toolDown = !ball && onDough(tip, inset: 4) && liftK > 0.85
                if toolDown {
                    paintSauceStroke(from: toolLast, to: tip, kind: kind)
                }
            case .cheeseShaker(let kind):
                toolDown = hypot(tip.x - PGeo.center.x, tip.y - PGeo.center.y) < PGeo.maxR + 40 && liftK > 0.85
                if toolDown {
                    let rate: CGFloat = 130
                    sprinkleRate = 0.85
                    var count = rate * dt
                    while count > 0 {
                        if CGFloat(rng.unit()) < count {
                            emitShred(at: tip, spread: 40, z: 0.5, corn: kind == .cornCheese)
                        }
                        count -= 1
                    }
                }
            default:
                break
            }
            toolLast = tip
        }
    }

    // MARK: - Sauce (speed-independent lush brush + 1-tap Swirl-Fill + gentle leveling)

    @inline(__always) func gridIndex(_ x: Int, _ y: Int) -> Int { y * PGeo.grid + x }

    func cellCenter(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: PGeo.center.x - PGeo.half + (CGFloat(x) + 0.5) * PGeo.cell,
                y: PGeo.center.y - PGeo.half + (CGFloat(y) + 0.5) * PGeo.cell)
    }

    func inSauceArea(_ p: CGPoint, inset: CGFloat = PGeo.rim) -> Bool { !ball && onDough(p, inset: inset) }

    /// Paints a lush glossy sauce ribbon along `a -> b` regardless of drag speed (zero fast-drag drop-off).
    func paintSauceStroke(from a: CGPoint, to b: CGPoint, kind: SauceKind? = nil) {
        guard !ball else { return }
        let sauceType = kind ?? selectedSauce
        let palette = sauceType.paletteID
        let dist = hypot(b.x - a.x, b.y - a.y)
        let steps = max(1, Int(ceil(dist / 14)))
        let g = PGeo.grid
        let c = PGeo.cell
        let ox = PGeo.center.x - PGeo.half
        let oy = PGeo.center.y - PGeo.half
        let brushRadius: CGFloat = 46
        let radCells = Int(ceil(brushRadius / c))
        let sigma: Float = 24
        var changed = false

        for s in 0...steps {
            let u = steps == 0 ? CGFloat(1) : CGFloat(s) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
            let cx = Int((p.x - ox) / c)
            let cy = Int((p.y - oy) / c)
            let x0 = max(0, cx - radCells), x1 = min(g - 1, cx + radCells)
            let y0 = max(0, cy - radCells), y1 = min(g - 1, cy + radCells)
            guard x0 <= x1, y0 <= y1 else { continue }
            for y in y0...y1 {
                for x in x0...x1 {
                    let q = cellCenter(x, y)
                    guard inSauceArea(q) else { continue }
                    let d2 = Float((q.x - p.x) * (q.x - p.x) + (q.y - p.y) * (q.y - p.y))
                    let w = exp(-d2 / (2 * sigma * sigma))
                    guard w > 0.08 else { continue }
                    let i = gridIndex(x, y)
                    let target = min(1.05, max(sauce[i], 0.72 * w) + 0.16 * w)
                    if target > sauce[i] || saucePalette[i] != palette {
                        sauce[i] = min(1.05, target)
                        saucePalette[i] = palette
                        changed = true
                    }
                }
            }
        }
        if changed {
            sauceVersion &+= 1
            sauceFlowing = true
            sauceCoverage = coverage(sauce, above: 0.14)
        }
    }

    /// 1-tap Swirl-Fill button: coats the entire pie inside the crust rim in one lush spiral flourish.
    func swirlFillSauce(_ kind: SauceKind? = nil) {
        if ball { flatten(initialProgress: 1.0) }
        let sauceType = kind ?? selectedSauce
        selectedSauce = sauceType
        let palette = sauceType.paletteID
        let g = PGeo.grid
        for y in 0..<g {
            for x in 0..<g {
                let p = cellCenter(x, y)
                guard inSauceArea(p) else { continue }
                let dx = p.x - PGeo.center.x, dy = p.y - PGeo.center.y
                let ang = atan2(Double(dy), Double(dx))
                let dist = Double(hypot(dx, dy))
                let swirl = 0.68 + 0.18 * sin(dist * 0.13 - ang * 2.0) + 0.08 * cos(Double(x) * 0.28)
                let i = gridIndex(x, y)
                sauce[i] = Float(max(0.35, min(1.0, swirl)))
                saucePalette[i] = palette
            }
        }
        sauceVersion &+= 1
        sauceFlowing = true
        sauceCoverage = coverage(sauce, above: 0.14)
        PizzaSound.shared.play(.glop, volume: 0.85)
        Sound.shared.play(.sparkle, volume: 0.45)
        notifyStateChange()
    }

    func pour(at p: CGPoint, amount: Float, kind: SauceKind? = nil) {
        let sauceType = kind ?? selectedSauce
        let palette = sauceType.paletteID
        let g = PGeo.grid, c = PGeo.cell
        let cx = Int((p.x - (PGeo.center.x - PGeo.half)) / c)
        let cy = Int((p.y - (PGeo.center.y - PGeo.half)) / c)
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
        for (i, w) in weights {
            sauce[i] += amount * w / total * 20
            saucePalette[i] = palette
        }
        sauceVersion &+= 1
        sauceFlowing = true
    }

    func spread(at p: CGPoint, by d: CGPoint) {
        let g = PGeo.grid, c = PGeo.cell
        let dl = hypot(d.x, d.y)
        let k = dl > 12 ? 12 / dl : 1
        let dx = d.x * k, dy = d.y * k
        let ox = PGeo.center.x - PGeo.half, oy = PGeo.center.y - PGeo.half
        let cx = Int((p.x - ox) / c), cy = Int((p.y - oy) / c)
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
                guard a > PizzaSim.sauceFilm else { continue }
                let q = cellCenter(x, y)
                let dist = hypot(q.x - p.x, q.y - p.y)
                let w = Float(max(0, 1 - dist / radPt))
                guard w > 0 else { continue }
                let m = (a - PizzaSim.sauceFilm) * 0.5 * w
                let dirX = (q.x - p.x) / max(1, dist), dirY = (q.y - p.y) / max(1, dist)
                let push = 8 * (1 - dist / radPt) + 2
                let tx = q.x + dx + dirX * push, ty = q.y + dy + dirY * push
                guard inSauceArea(CGPoint(x: tx, y: ty)) else { continue }
                out[i] -= m
                deposit(&out, x: tx, y: ty, m)
                let txIdx = max(0, min(g - 1, Int((tx - ox) / c)))
                let tyIdx = max(0, min(g - 1, Int((ty - oy) / c)))
                if saucePalette[i] != 0 {
                    saucePalette[gridIndex(txIdx, tyIdx)] = saucePalette[i]
                }
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
    static let sauceLevel: Float = 0.35
    var sauceFlowing = false

    func flowSauce() {
        guard sauceFlowing, !ball else { return }
        let g = PGeo.grid
        var mask = [Bool](repeating: false, count: g * g)
        for y in 0..<g {
            for x in 0..<g {
                mask[gridIndex(x, y)] = inSauceArea(cellCenter(x, y))
            }
        }
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
                        let f = 0.65 * (e - ej) / 4
                        out[i] -= f
                        out[j] += f
                        if saucePalette[j] == 0 { saucePalette[j] = saucePalette[i] }
                        any = true
                    }
                }
            }
        }
        sauce = out
        sauceVersion &+= 1
        if !any { sauceFlowing = false }
    }

    func deposit(_ grid: inout [Float], x: CGFloat, y: CGFloat, _ m: Float) {
        let g = PGeo.grid, c = PGeo.cell
        let fx = (x - (PGeo.center.x - PGeo.half)) / c - 0.5
        let fy = (y - (PGeo.center.y - PGeo.half)) / c - 0.5
        let ix = Int(floor(fx)), iy = Int(floor(fy))
        let tx = Float(fx - CGFloat(ix)), ty = Float(fy - CGFloat(iy))
        let parts: [(Int, Int, Float)] = [
            (ix, iy, (1 - tx) * (1 - ty)),
            (ix + 1, iy, tx * (1 - ty)),
            (ix, iy + 1, (1 - tx) * ty),
            (ix + 1, iy + 1, tx * ty)
        ]
        var lost: Float = 0
        for (px, py, w) in parts {
            if px >= 0, py >= 0, px < g, py < g {
                grid[gridIndex(px, py)] += m * w
            } else {
                lost += m * w
            }
        }
        if lost > 0 {
            let cx = min(g - 1, max(0, ix)), cy = min(g - 1, max(0, iy))
            grid[gridIndex(cx, cy)] += lost
        }
    }

    var totalSauce: Float { sauce.reduce(0, +) }

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

    // MARK: - Cheese (generous instant shower + 1-tap burst + Mozzarella & Corn-Cheese)

    func emitShred(at p: CGPoint, spread: CGFloat, z: CGFloat, push: CGPoint = .zero, corn: Bool = false) {
        guard falling.count < 520 else { return }
        let a = rng.unit() * 2 * .pi
        let d = CGFloat(sqrt(rng.unit())) * spread
        falling.append(CheeseShred(
            x: p.x + CGFloat(cos(a)) * d,
            y: p.y + CGFloat(sin(a)) * d,
            z: z,
            vx: CGFloat(rng.unit() - 0.5) * 65 + push.x * 2.5,
            vy: CGFloat(rng.unit() - 0.5) * 65 + push.y * 2.5,
            vz: -1.1,
            ang: rng.unit() * .pi,
            len: 14 + CGFloat(rng.unit()) * 13,
            curl: CGFloat(rng.unit() - 0.5) * 0.9,
            tone: CGFloat(rng.unit()),
            corn: corn
        ))
    }

    /// Direct swipe shower across the pizza so 1-2 swipes coat > 60% quickly.
    func showerCheese(from a: CGPoint, to b: CGPoint, kind: CheeseKind? = nil, burst: Int = 0) {
        guard !ball else { return }
        let kindToUse = kind ?? selectedCheese
        cheeseKind = kindToUse
        let isCorn = kindToUse == .cornCheese
        let dist = hypot(b.x - a.x, b.y - a.y)
        let steps = max(1, Int(ceil(dist / 16)))
        let perStep = burst > 0 ? burst : 15
        let push = CGPoint(x: (b.x - a.x) * 0.15, y: (b.y - a.y) * 0.15)
        for s in 0..<steps {
            let u = steps == 1 ? CGFloat(1) : CGFloat(s + 1) / CGFloat(steps)
            let p = CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
            for _ in 0..<perStep {
                emitShred(at: p, spread: 74, z: 0.2 + CGFloat(rng.unit()) * 0.35, push: push, corn: isCorn)
            }
        }
    }

    /// 1-tap Cheese Sprinkle Burst button: generously covers the pie in fluffy shreds!
    func sprinkleBurstCheese(_ kind: CheeseKind? = nil) {
        if ball { flatten(initialProgress: 1.0) }
        let kindToUse = kind ?? selectedCheese
        selectedCheese = kindToUse
        cheeseKind = kindToUse
        let isCorn = kindToUse == .cornCheese
        for _ in 0..<180 {
            let p = randomSpot(0.94)
            emitShred(at: p, spread: 14, z: 0.15 + CGFloat(rng.unit()) * 0.45, corn: isCorn)
        }
        PizzaSound.shared.play(.sprinkle, volume: 0.8)
        notifyStateChange()
    }

    private func depositCheeseFootprint(at x: CGFloat, y: CGFloat) {
        let g = PGeo.grid
        let c = PGeo.cell
        let ox = PGeo.center.x - PGeo.half
        let oy = PGeo.center.y - PGeo.half
        let cx = Int((x - ox) / c)
        let cy = Int((y - oy) / c)
        let rad = 4
        let sigma: Float = 11
        let x0 = max(0, cx - rad), x1 = min(g - 1, cx + rad)
        let y0 = max(0, cy - rad), y1 = min(g - 1, cy + rad)
        guard x0 <= x1, y0 <= y1 else { return }
        for gy in y0...y1 {
            for gx in x0...x1 {
                let q = cellCenter(gx, gy)
                guard inSauceArea(q, inset: 6) else { continue }
                let d2 = Float((q.x - x) * (q.x - x) + (q.y - y) * (q.y - y))
                let w = exp(-d2 / (2 * sigma * sigma))
                guard w >= 0.12 else { continue }
                let i = gridIndex(gx, gy)
                cheese[i] = min(1.2, cheese[i] + 0.36 * w)
            }
        }
    }

    private func stepShreds(_ dt: CGFloat) {
        guard !falling.isEmpty else { return }
        var keep: [CheeseShred] = []
        keep.reserveCapacity(falling.count)
        var any = false
        for var s in falling {
            s.vz -= 28 * dt
            s.z += s.vz * dt
            s.x += s.vx * dt
            s.y += s.vy * dt
            s.vx *= 1 - min(1, dt * 3.5)
            s.vy *= 1 - min(1, dt * 3.5)
            s.ang += Double(s.curl) * Double(dt) * 6
            if s.z <= 0 {
                let p = CGPoint(x: s.x, y: s.y)
                if !ball && onDough(p, inset: 6) && stage != .bake {
                    shredLayer.add(s, center: PGeo.center, half: PGeo.half)
                    depositCheeseFootprint(at: s.x, y: s.y)
                    landed += 1
                    any = true
                }
                continue
            }
            keep.append(s)
        }
        falling = keep
        if any {
            cheeseVersion &+= 1
            cheeseCoverage = coverage(cheese, above: 0.14)
        }
    }

    // MARK: - The Wood-Fired Oven (3.5s brisk bake!)

    var melt: Double { smooth(0.08, 0.52, bake) }
    var brown: Double { smooth(0.40, 1.0, bake) }
    var canPullFromOven: Bool { bake >= 0.45 }

    func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    func onOvenPizza(_ p: CGPoint) -> Bool {
        let dx = (p.x - PGeo.ovenCenter.x) / PGeo.ovenScale
        let dy = (p.y - PGeo.ovenCenter.y) / (PGeo.ovenScale * PGeo.ovenSquash)
        return hypot(dx, dy) < max(meanR * 1.05, 190)
    }

    func enterOven() {
        guard !inOven else { return }
        if ball { flatten(initialProgress: 1.0) }
        tool = nil
        toolDown = false
        inOven = true
        falling = []
        PizzaSound.shared.play(.oven)
    }

    func leaveOven() {
        guard inOven else { return }
        inOven = false
        outAt = time
        PizzaSound.shared.play(.oven, volume: 0.65)
    }

    func pullFromOven() {
        guard stage == .bake else { return }
        if canPullFromOven {
            go(.slice)
        } else {
            stoke()
        }
    }

    func stoke() {
        flare = min(1.8, flare + 1.2)
        PizzaSound.shared.play(.whoosh, volume: 0.65)
        for _ in 0..<28 { spawnFlame(big: true) }
    }

    private func stepOven(_ dt: Double) {
        let want: Double = inOven ? 1 : 0
        ovenSlide += (want - ovenSlide) * min(1, dt * 7.5)
        if abs(want - ovenSlide) < 0.002 { ovenSlide = want }
        flare = max(0, flare - dt * 1.1)
        let fireOn = ovenSlide > 0.01
        if fireOn {
            var count = (58 + 85 * flare) * dt
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
                f.vy -= CGFloat(dt) * (f.spark ? 45 : 65)
                keep.append(f)
            }
            flames = keep
        }
        guard inOven, ovenSlide > 0.72 else { stepBubbles(dt); return }
        let before = bake
        if !hold { bake = min(1, bake + dt / PGeo.bakeTime * (1 + flare * 0.9)) }
        if melt > 0.02 && melt < 0.999 { flowCheese(Float(dt) * Float(melt) * 2.2) }
        if bake > 0.22 && bake < 1 {
            var count = 24 * dt * melt
            while count > 0 {
                if rng.unit() < count { spawnBubble() }
                count -= 1
            }
        }
        // Rising warm aroma hearts inside the oven as it turns golden
        if bake > 0.30 && !hold && rng.unit() < (2.6 + bake * 2.2) * dt {
            let ax = PGeo.ovenCenter.x + CGFloat(rng.unit() - 0.5) * 260
            let ay = PGeo.ovenCenter.y - 30 + CGFloat(rng.unit() - 0.5) * 40
            puffs.append(PizzaPuff(kind: .aroma, x: ax, y: ay, vx: CGFloat(rng.unit() - 0.5) * 18,
                                   vy: -62 - CGFloat(rng.unit()) * 28, r: 10 + CGFloat(rng.unit()) * 6,
                                   age: 0, life: 1.5 + rng.unit() * 0.5, seed: rng.int(1000)))
        }
        if before < 1 && bake >= 1 && !dinged {
            dinged = true
            PizzaSound.shared.play(.ding)
            Sound.shared.play(.sparkle, volume: 0.65)
            if !demo {
                StickerBook.shared.find(game: PizzaSim.gameID, id: PizzaFind.woodFiredChef.rawValue)
            }
            notifyStateChange()
        }
        stepBubbles(dt)
    }

    private func spawnFlame(big: Bool) {
        guard flames.count < 260 else { return }
        let spark = !big && rng.unit() < 0.14
        let x = 230 + CGFloat(rng.unit()) * 170
        flames.append(OvenFlame(
            x: x,
            y: 330 - CGFloat(rng.unit()) * 14,
            vx: CGFloat(rng.unit() - 0.5) * 32,
            vy: spark ? -155 - CGFloat(rng.unit()) * 120 : -75 - CGFloat(rng.unit()) * 70 - (big ? 85 : 0),
            age: 0,
            life: spark ? 1.4 : 0.55 + rng.unit() * 0.5 + (big ? 0.3 : 0),
            size: spark ? 2.8 : (24 + CGFloat(rng.unit()) * 22) * (big ? 1.45 : 1),
            spark: spark
        ))
    }

    private func spawnBubble() {
        guard bubbles.count < 70 else { return }
        let p = randomSpot(0.9)
        let g = PGeo.grid
        let fx = Int((p.x - (PGeo.center.x - PGeo.half)) / PGeo.cell)
        let fy = Int((p.y - (PGeo.center.y - PGeo.half)) / PGeo.cell)
        guard fx >= 0, fy >= 0, fx < g, fy < g, cheese[gridIndex(fx, fy)] > 0.22 else { return }
        bubbles.append(CheeseBubble(
            x: p.x - PGeo.center.x,
            y: p.y - PGeo.center.y,
            age: 0,
            life: 0.45 + rng.unit() * 0.55,
            size: 4.5 + CGFloat(rng.unit()) * 7.5
        ))
    }

    private func stepBubbles(_ dt: Double) {
        guard !bubbles.isEmpty else { return }
        var keep: [CheeseBubble] = []
        for var b in bubbles {
            b.age += dt
            if b.age >= b.life {
                let p = CGPoint(x: PGeo.center.x + b.x, y: PGeo.center.y + b.y)
                deposit(&browned, x: p.x, y: p.y, Float(b.size) * 0.14)
                cheeseVersion &+= 1
                PizzaSound.shared.play(.bubble, volume: 0.28, gap: 0.08)
                continue
            }
            keep.append(b)
        }
        bubbles = keep
    }

    private func flowCheese(_ k: Float) {
        let g = PGeo.grid
        var out = cheese
        let kk = min(0.2, k)
        for y in 1..<(g - 1) {
            for x in 1..<(g - 1) {
                let i = gridIndex(x, y)
                let c = cheese[i]
                let lap = cheese[i - 1] + cheese[i + 1] + cheese[i - g] + cheese[i + g] - 4 * c
                if c > 0.02 || lap > 0 { out[i] = c + kk * lap }
            }
        }
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

    // MARK: - Slicing & Gooey Cheese-Pull Serving

    func angleDiff(_ a: Double, _ b: Double) -> Double {
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
        for _ in 0..<10 {
            let d = CGFloat(rng.unit() * 2 - 1) * meanR
            puffs.append(PizzaPuff(
                kind: .crumb,
                x: PGeo.center.x + CGFloat(cos(t)) * d,
                y: PGeo.center.y + CGFloat(sin(t)) * d,
                vx: CGFloat(rng.unit() - 0.5) * 130,
                vy: -45 - CGFloat(rng.unit()) * 85,
                r: 2 + CGFloat(rng.unit()) * 2.5,
                age: 0,
                life: 0.52,
                seed: rng.int(1000)
            ))
        }
        notifyStateChange()
        return true
    }

    /// 1-tap Quick-Slice button for little hands.
    @discardableResult
    func quickSlice() -> Bool {
        guard !ball, !inOven else { return false }
        let options: [Double] = [0, .pi / 2, .pi / 4, 3 * .pi / 4, .pi / 8, 5 * .pi / 8, 3 * .pi / 8, 7 * .pi / 8]
        guard let a = options.first(where: { o in !cuts.contains(where: { abs(angleDiff($0, o)) < 0.15 }) }) else { return false }
        let added = addCut(a)
        if added {
            groove = (
                [
                    CGPoint(x: PGeo.center.x - CGFloat(cos(a)) * meanR, y: PGeo.center.y - CGFloat(sin(a)) * meanR),
                    CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * meanR, y: PGeo.center.y + CGFloat(sin(a)) * meanR)
                ],
                time
            )
        }
        return added
    }

    /// Distance from `p` to line segment `a...b`.
    private func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0.001 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        let proj = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
        return hypot(p.x - proj.x, p.y - proj.y)
    }

    /// Forgiving cut detection: any stroke >= 90pt crossing near the pizza snaps a crisp slice cut.
    func finishCut() {
        let pts = stroke
        stroke = []
        guard pts.count >= 2, let a = pts.first, let b = pts.last else { return }
        groove = (pts, time)
        let len = hypot(b.x - a.x, b.y - a.y)
        guard len >= 90 else { return }
        let dist = distanceToSegment(PGeo.center, a, b)
        guard dist < meanR * 0.72 else { return }
        addCut(atan2(Double(b.y - a.y), Double(b.x - a.x)))
    }

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
        guard hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < meanR + 18 else { return nil }
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

    var isUnbakedEmptyDough: Bool {
        bake < 0.25 && totalSauce < 0.5 && landed == 0 && toppings.isEmpty
    }

    var canServe: Bool {
        !cuts.isEmpty && !ball && !inOven && !isUnbakedEmptyDough
    }

    private func makeCheeseStrings(for s: (Double, Double)) -> [CheeseString] {
        guard melt > 0.1 || landed > 0 || bake > 0.2 else { return [] }
        let edges = s.1 - s.0 < 2 * .pi - 0.01 ? [s.0, s.1] : []
        var strings: [CheeseString] = []
        for a in edges {
            let edgeR = edge(a)
            for k in 0..<5 {
                let d = edgeR * (0.18 + 0.16 * CGFloat(k)) + CGFloat(rng.unit()) * 8
                strings.append(CheeseString(
                    at: CGPoint(x: CGFloat(cos(a)) * d, y: CGFloat(sin(a)) * d),
                    breakAt: 105 + CGFloat(rng.unit()) * 150,
                    broke: nil,
                    width: 3.0 + CGFloat(rng.unit()) * 3.4
                ))
            }
        }
        return strings
    }

    private func beginSliceDrag(at p: CGPoint) {
        guard !cuts.isEmpty, lifted == nil, draggedSlice == nil, let s = slice(at: p) else { return }
        if isUnbakedEmptyDough {
            wiggleAt = time
            ovenNudgeAt = time
            Sound.shared.play(.boing, volume: 0.5)
            return
        }
        let strings = makeCheeseStrings(for: s)
        draggedSlice = DraggedSlice(a0: s.0, a1: s.1, startFinger: p, offset: .zero, strings: strings)
        sliceGestureKind = .draggingSlice
        PizzaSound.shared.play(strings.isEmpty ? .whoosh : .stretchy, volume: 0.85)
    }

    private func updateSliceDrag(to p: CGPoint) {
        guard var ds = draggedSlice else { return }
        ds.offset = CGPoint(x: p.x - ds.startFinger.x, y: p.y - ds.startFinger.y)
        let mid = (ds.a0 + ds.a1) / 2
        let cx = CGFloat(cos(mid)) * meanR * 0.52
        let cy = CGFloat(sin(mid)) * meanR * 0.52
        for i in ds.strings.indices where ds.strings[i].broke == nil {
            let st = ds.strings[i]
            let stretch = hypot(ds.offset.x + (st.at.x - cx) * 0.08, ds.offset.y + (st.at.y - cy) * 0.08)
            if stretch > st.breakAt {
                ds.strings[i].broke = time
                PizzaSound.shared.play(.snap, volume: 0.38, gap: 0.05)
            }
        }
        draggedSlice = ds
    }

    private func finishSliceDrag() {
        guard let ds = draggedSlice else { return }
        draggedSlice = nil
        launchServe(slice: (ds.a0, ds.a1), startOffset: ds.offset, existingStrings: ds.strings)
    }

    func serveSlice(at p: CGPoint) {
        guard lifted == nil, draggedSlice == nil, !ball, !inOven else { return }
        // Never allow serving an uncut pie!
        guard !cuts.isEmpty else {
            wiggleAt = time
            cutterNudgeAt = time
            Sound.shared.play(.boing, volume: 0.5)
            return
        }
        guard let s = slice(at: p) else {
            if hypot(p.x - PGeo.center.x, p.y - PGeo.center.y) < meanR { wiggleAt = time }
            return
        }
        if isUnbakedEmptyDough {
            wiggleAt = time
            ovenNudgeAt = time
            Sound.shared.play(.boing, volume: 0.5)
            return
        }
        launchServe(slice: s, startOffset: .zero, existingStrings: nil)
    }

    private func launchServe(slice s: (Double, Double), startOffset: CGPoint, existingStrings: [CheeseString]?) {
        let strings = existingStrings ?? makeCheeseStrings(for: s)
        lifted = LiftedSlice(a0: s.0, a1: s.1, start: time, startOffset: startOffset, strings: strings)
        if existingStrings == nil {
            PizzaSound.shared.play(strings.isEmpty ? .whoosh : .stretchy, volume: 0.85)
        }
        if stars == nil {
            let st = order.stars(toppings)
            stars = st
            save.hearts += st
            save.pizzas += 1
            persist()
            if !paidThisPizza {
                paidThisPizza = true
                Coins.shared.earn(Coins.reward(stars: st), game: PizzaSim.gameID,
                                  from: CGPoint(x: PGeo.customer.x, y: PGeo.customer.y + 40))
            }
            if !demo {
                StickerBook.shared.find(game: PizzaSim.gameID, id: PizzaFind.firstPizza.rawValue)
                if st == 3 {
                    StickerBook.shared.find(game: PizzaSim.gameID, id: PizzaFind.threeStarPizzaiolo.rawValue)
                }
                if save.pizzas >= 3 || Set(toppings.map { $0.kind }).count >= 3 {
                    StickerBook.shared.find(game: PizzaSim.gameID, id: PizzaFind.masterChef.rawValue)
                }
            }
        }
        if !demo && !strings.isEmpty {
            StickerBook.shared.find(game: PizzaSim.gameID, id: PizzaFind.cheesePull.rawValue)
        }
        notifyStateChange()
    }

    func liftedPose() -> (u: Double, dx: CGFloat, dy: CGFloat, scale: CGFloat, cx: CGFloat, cy: CGFloat)? {
        guard let l = lifted else { return nil }
        let u = min(1, (time - l.start) / LiftedSlice.duration)
        let mid = (l.a0 + l.a1) / 2
        let whole = l.a1 - l.a0 > 6
        let cx = whole ? 0 : CGFloat(cos(mid)) * meanR * 0.52
        let cy = whole ? 0 : CGFloat(sin(mid)) * meanR * 0.52
        let hasDragStart = hypot(l.startOffset.x, l.startOffset.y) > 25
        let pullSplit = hasDragStart ? 0.14 : 0.44
        let pull = min(1, u / pullSplit)
        let fly = max(0, (u - pullSplit) / (1 - pullSplit))
        let e = fly * fly * (3 - 2 * fly)
        let pullOut: CGFloat = hasDragStart ? 18 : 74
        let ox = l.startOffset.x + (whole ? 0 : CGFloat(cos(mid)) * CGFloat(pull) * pullOut)
        let oy = l.startOffset.y + (whole ? 0 : CGFloat(sin(mid)) * CGFloat(pull) * pullOut) - CGFloat(pull) * 22
        let target = CGPoint(x: PGeo.mouth.x - PGeo.center.x - cx, y: PGeo.mouth.y - PGeo.center.y - cy)
        let dx = ox + (target.x - ox) * CGFloat(e)
        let dy = oy + (target.y - oy) * CGFloat(e) - CGFloat(sin(.pi * e)) * 68
        let scale = (1 + 0.08 * CGFloat(pull)) * (1 - 0.72 * CGFloat(e))
        return (u, dx, dy, scale, cx, cy)
    }

    func draggedPose() -> (u: Double, dx: CGFloat, dy: CGFloat, scale: CGFloat, cx: CGFloat, cy: CGFloat)? {
        guard let ds = draggedSlice else { return nil }
        let mid = (ds.a0 + ds.a1) / 2
        let cx = CGFloat(cos(mid)) * meanR * 0.52
        let cy = CGFloat(sin(mid)) * meanR * 0.52
        return (0.25, ds.offset.x, ds.offset.y - 16, 1.08, cx, cy)
    }

    private func stepSlice(_ dt: Double) {
        if hold, lifted != nil { lifted?.start = time - LiftedSlice.duration * 0.36 }
        guard var l = lifted, let pose = liftedPose() else { return }
        for i in l.strings.indices where l.strings[i].broke == nil {
            let s = l.strings[i]
            let stretch = hypot(pose.dx + (s.at.x - pose.cx) * (pose.scale - 1),
                                pose.dy + (s.at.y - pose.cy) * (pose.scale - 1))
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
            for k in 0..<6 {
                puffs.append(PizzaPuff(
                    kind: .heart,
                    x: PGeo.customer.x + CGFloat(k - 2) * 22,
                    y: PGeo.customer.y - 56,
                    vx: CGFloat(k - 2) * 14,
                    vy: -72 - CGFloat(rng.unit()) * 42,
                    r: 14,
                    age: -Double(k) * 0.07,
                    life: 1.4,
                    seed: k
                ))
            }
            if allEaten {
                PizzaSound.shared.play(.yay)
                Sound.shared.play(.fanfare, volume: 0.5)
                if !paidThisPizza {
                    paidThisPizza = true
                    Coins.shared.earn(Coins.reward(stars: stars ?? 1), game: PizzaSim.gameID,
                                      from: CGPoint(x: PGeo.customer.x, y: PGeo.customer.y + 40))
                }
                newPizzaAt = time + 2.8
            }
            notifyStateChange()
        }
    }

    func tickle() {
        happyUntil = time + 1
        wiggleAt = time
        Sound.shared.play(.boing, volume: 0.5)
    }

    // MARK: - Fresh Pizza & Stage Flow

    func newPizza() {
        var next = Int.random(in: 0..<PizzaOrder.customers.count)
        if next == order.customer { next = (next + 1) % PizzaOrder.customers.count }
        order = PizzaOrder.random(customer: next)
        reset()
        Sound.shared.play(.pop, volume: 0.6)
        notifyStateChange()
    }

    func reset() {
        stars = nil
        paidThisPizza = false
        stage = .dough
        crustShape = .round
        prepTab = .sauces
        selectedSauce = .tomato
        selectedCheese = .mozzarella
        cheeseKind = .mozzarella
        selectedTopping = order.wants.first ?? .pepperoni
        sliceMode = .cut
        ball = true
        rollProgress = 0
        rollPin = RollingPinState()
        squash = 0
        squashV = 0
        ballShift = .zero
        r = [CGFloat](repeating: 106, count: PizzaSim.n)
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
        saucePalette = [UInt8](repeating: 0, count: g * g)
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
        draggedSlice = nil
        tool = nil
        toolDown = false
        sauceCoverage = 0
        cheeseCoverage = 0
        outAt = -100
        ovenNudgeAt = -10
        cutterNudgeAt = -10
        newPizzaAt = nil
    }

    func go(_ s: PizzaStep) {
        guard s != stage else { return }
        tool = nil
        toolDown = false
        rollPin.dragging = false
        draggedSlice = nil
        if s != .dough && ball {
            flatten(initialProgress: 1.0)
        } else if s != .dough && rollProgress < 0.85 {
            rollProgress = 1.0
            syncDoughTargets()
        }
        if stage == .bake { leaveOven() }
        stage = s
        if s == .bake { enterOven() }
        if s == .slice { sliceMode = .cut }
        notifyStateChange()
    }

    func ready(_ s: PizzaStep) -> Bool {
        switch s {
        case .dough:
            return !ball && rollProgress >= 0.72 && tossStart == nil
        case .prep:
            let hasBase = sauceCoverage > 0.3 || cheeseCoverage > 0.3 || !toppings.isEmpty
            let matchesOrder = order.wants.isEmpty ? toppings.count >= 3 : order.wants.allSatisfy { order.has($0, toppings) }
            return hasBase && matchesOrder
        case .bake:
            return bake >= 1.0
        case .slice:
            return stars != nil
        }
    }

    // MARK: - Puffs, Steam, Aroma Hearts

    func flourPuff(at p: CGPoint, count: Int, spread: CGFloat) {
        for _ in 0..<count {
            let a = rng.unit() * 2 * .pi
            let d = CGFloat(rng.unit()) * spread
            let x = p.x + CGFloat(cos(a)) * d, y = p.y + CGFloat(sin(a)) * d
            puffs.append(PizzaPuff(
                kind: .flour,
                x: x, y: y,
                vx: CGFloat(cos(a)) * 42,
                vy: CGFloat(sin(a)) * 42 - 10,
                r: 8 + CGFloat(rng.unit()) * 12,
                age: 0,
                life: 0.65 + rng.unit() * 0.45,
                seed: rng.int(1000)
            ))
        }
    }

    private func stepPuffs(_ dt: Double) {
        let hot = time - outAt
        if !inOven && bake > 0.35 && hot < 14 && stage != .bake {
            let rate = 9 * (1 - hot / 14)
            if rng.unit() < rate * dt {
                let p = randomSpot(0.8)
                puffs.append(PizzaPuff(
                    kind: .steam,
                    x: p.x, y: p.y,
                    vx: CGFloat(rng.unit() - 0.5) * 10,
                    vy: -30 - CGFloat(rng.unit()) * 20,
                    r: 16 + CGFloat(rng.unit()) * 14,
                    age: 0,
                    life: 2 + rng.unit(),
                    seed: rng.int(1000)
                ))
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
            case .aroma:
                p.vx += CGFloat(sin(time * 3.2 + Double(p.seed))) * d * 24
            case .smoke:
                p.r += d * 20
            }
            keep.append(p)
        }
        puffs = keep
    }

    // MARK: - Looping Audio

    private func stepSounds() {
        let s = PizzaSound.shared
        let paintingSauce: Bool
        if case .sauceBrush? = tool, toolDown { paintingSauce = true } else { paintingSauce = false }
        let shakingCheese: Bool
        if case .cheeseShaker? = tool, toolDown { shakingCheese = true } else { shakingCheese = false }
        let rollingCutter = tool == .cutter && toolDown
        s.setLoop(.spread, volume: paintingSauce ? Float(0.18 + 0.55 * spreadSpeed) : 0)
        s.setLoop(.sprinkle, volume: shakingCheese ? Float(0.22 + 0.5 * sprinkleRate) : 0)
        s.setLoop(.roll, volume: rollingCutter ? Float(0.18 + 0.65 * spreadSpeed) : 0)
        s.setLoop(.fire, volume: Float(ovenSlide * (0.55 + 0.35 * min(1, flare))))
        let sizzle = inOven ? melt * 0.8 : max(0, 1 - (time - outAt) / 6) * 0.4 * (bake > 0.3 ? 1 : 0)
        s.setLoop(.sizzle, volume: Float(sizzle))
    }
}

// MARK: - Cheese Shreds Bitmap Layer

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
        // soft shadow, shred body, cream highlight
        c.addPath(path)
        c.setStrokeColor(CGColor(red: 0.45, green: 0.3, blue: 0.1, alpha: 0.22))
        c.setLineWidth(6.4)
        c.saveGState()
        c.translateBy(x: 0.8, y: 1.6)
        c.strokePath()
        c.restoreGState()

        c.addPath(path)
        if s.corn {
            c.setStrokeColor(CGColor(red: 0.96 - 0.03 * t, green: 0.86 - 0.04 * t, blue: 0.56 - 0.08 * t, alpha: 1))
        } else {
            c.setStrokeColor(CGColor(red: 0.93 - 0.04 * t, green: 0.78 - 0.05 * t, blue: 0.38 - 0.08 * t, alpha: 1))
        }
        c.setLineWidth(5.2)
        c.strokePath()

        c.addPath(path)
        if s.corn {
            c.setStrokeColor(CGColor(red: 1.0, green: 0.97 - 0.02 * t, blue: 0.78 - 0.06 * t, alpha: 1))
        } else {
            c.setStrokeColor(CGColor(red: 1.0, green: 0.93 - 0.03 * t, blue: 0.6 - 0.1 * t, alpha: 1))
        }
        c.setLineWidth(3.2)
        c.strokePath()

        c.saveGState()
        c.translateBy(x: -0.7, y: -0.9)
        c.addPath(path)
        c.setStrokeColor(CGColor(red: 1, green: 0.99, blue: 0.88, alpha: 0.85))
        c.setLineWidth(1.1)
        c.strokePath()
        c.restoreGState()

        // Korean corn-cheese golden corn kernel + parsley fleck
        if s.corn && t > 0.58 {
            c.saveGState()
            c.translateBy(x: x + nx * 0.5, y: y + ny * 0.5)
            c.rotate(by: CGFloat(s.ang))
            let kernel = CGRect(x: -4.2, y: -3.2, width: 8.4, height: 6.4)
            let kp = CGPath(roundedRect: kernel, cornerWidth: 2.8, cornerHeight: 2.8, transform: nil)
            c.addPath(kp)
            c.setFillColor(CGColor(red: 1.0, green: 0.84, blue: 0.15, alpha: 1))
            c.fillPath()
            c.addPath(kp)
            c.setStrokeColor(CGColor(red: 0.82, green: 0.56, blue: 0.08, alpha: 0.9))
            c.setLineWidth(1.2)
            c.strokePath()
            c.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.65))
            c.fillEllipse(in: CGRect(x: -2.2, y: -2.0, width: 3.0, height: 1.7))
            if t > 0.86 {
                c.setFillColor(CGColor(red: 0.22, green: 0.62, blue: 0.22, alpha: 0.95))
                c.fill(CGRect(x: 4.5, y: -1.5, width: 3.2, height: 2.2))
            }
            c.restoreGState()
        }
        version += 1
    }

    var image: CGImage? {
        if cachedVersion != version {
            cached = ctx?.makeImage()
            cachedVersion = version
        }
        return cached
    }
}

// MARK: - Demo & Test Helpers

extension PizzaSim {
    func holdTool(_ t: PizzaTool, at target: CGPoint) {
        let f = FingerLift.finger(for: target, lift: lift(for: t), top: 0, bottom: PGeo.designHeight, width: PGeo.designWidth)
        pickUp(t, finger: f)
        liftK = 1
        carry(f)
        toolLast = tip
    }

    func demoDisc(_ radius: CGFloat, shape: CrustShape = .round) {
        ball = false
        crustShape = shape
        rollProgress = min(1, max(0, (radius - 112) / (PGeo.maxR - 112)))
        let prof = shape.profile
        for i in 0..<PizzaSim.n {
            r[i] = min(PGeo.maxR + 12, radius * prof[i] + lumps[i] * 2)
            rest[i] = r[i]
            rv[i] = 0
        }
    }

    func demoSauce(_ kind: SauceKind = .tomato) {
        swirlFillSauce(kind)
    }

    func demoCheese(_ count: Int, kind: CheeseKind = .mozzarella) {
        cheeseKind = kind
        selectedCheese = kind
        let isCorn = kind == .cornCheese
        for _ in 0..<count {
            let p = randomSpot(0.95)
            let s = CheeseShred(
                x: p.x, y: p.y, z: 0,
                vx: 0, vy: 0, vz: 0,
                ang: rng.unit() * .pi,
                len: 14 + CGFloat(rng.unit()) * 13,
                curl: CGFloat(rng.unit() - 0.5) * 0.9,
                tone: CGFloat(rng.unit()),
                corn: isCorn
            )
            shredLayer.add(s, center: PGeo.center, half: PGeo.half)
            depositCheeseFootprint(at: p.x, y: p.y)
            landed += 1
        }
        cheeseVersion &+= 1
        cheeseCoverage = coverage(cheese, above: 0.14)
    }

    func demoToppings() {
        let wanted = order.wants
        let kinds: [ToppingKind] = wanted + [.pepperoni, .basil, .mushroom].filter { !wanted.contains($0) }
        for (j, k) in kinds.prefix(3).enumerated() {
            for i in 0..<5 {
                let a = Double(i) / 5 * 2 * .pi + Double(j) * 0.7
                let d = CGFloat(56 + j * 48)
                place(k, at: CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * d, y: PGeo.center.y + CGFloat(sin(a)) * d), from: nil)
            }
        }
        for i in toppings.indices { toppings[i].born = -10 }
    }

    func demoSetup(_ name: String) {
        demo = true
        Coins.shared.demo = true
        hold = true
        order = PizzaOrder.random(customer: 3, seed: 21)
        selectedTopping = order.wants.first ?? .pepperoni
        switch name {
        case "knead", "dough":
            stage = .dough
            pressing = true
            squash = 0.45
        case "stretch", "heart":
            stage = .dough
            demoDisc(204, shape: name == "heart" ? .heart : .round)
            rollPin.dragging = true
            rollPin.pos = CGPoint(x: PGeo.center.x + 28, y: PGeo.center.y - 14)
            rollPin.angle = 0.3
        case "toss":
            stage = .dough
            demoDisc(200)
            tossStart = time - 0.45
        case "sauce":
            stage = .prep
            prepTab = .sauces
            demoDisc(216)
            demoSauce(.tomato)
        case "cheese":
            stage = .prep
            prepTab = .cheeses
            demoDisc(216)
            demoSauce(.tomato)
            demoCheese(280, kind: .mozzarella)
        case "toppings", "prep":
            stage = .prep
            prepTab = .toppings
            demoDisc(216)
            demoSauce(.tomato)
            demoCheese(360)
            demoToppings()
        case "bake", "baked", "slice", "serve":
            demoDisc(216)
            demoSauce(.tomato)
            demoCheese(360)
            demoToppings()
            if name == "bake" {
                stage = .bake
                bake = 0.62
                inOven = true
                ovenSlide = 1
                for _ in 0..<45 { step(dt: 1.0 / 60) }
            } else {
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
                        let d = -R + CGFloat(k) * R * 0.08
                        return CGPoint(x: PGeo.center.x + CGFloat(cos(a)) * d, y: PGeo.center.y + CGFloat(sin(a)) * d)
                    }
                    tool = .cutter
                    finger = pts.last ?? PGeo.center
                    tip = finger
                    stroke = pts
                }
                if name == "serve" {
                    for a in [0, Double.pi / 4, Double.pi / 2, 3 * Double.pi / 4] { addCut(a) }
                    let s = slices[1]
                    let mid = (s.0 + s.1) / 2
                    serveSlice(at: CGPoint(x: PGeo.center.x + CGFloat(cos(mid)) * 110, y: PGeo.center.y + CGFloat(sin(mid)) * 110))
                }
            }
        default:
            break
        }
    }
}
