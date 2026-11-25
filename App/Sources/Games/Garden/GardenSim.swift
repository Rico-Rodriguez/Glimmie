import SwiftUI

enum GardenTool: Equatable {
    case shovel
    case can
    case seeds(PlantKind)
    case decor(DecorKind)
}

enum GPart {
    case water, splash, clod, seed, rain, petal, leaf, sparkle, dust, ripple, heart
}

struct GParticle {
    var kind: GPart
    var p: CGPoint
    var v: CGVector
    var age: CGFloat = 0
    var life: CGFloat
    var size: CGFloat
    var color: GRGB
    var rot: CGFloat = 0
    var spin: CGFloat = 0
    var mass: CGFloat = 0
    var seed: PlantKind?
    var bounces = 0
    var groundY: CGFloat = 0
    var resting = false
}

enum GFlyerKind {
    case crop(PlantKind, Int, Bool)
    case flowerToVase(PlantKind, Int)
    case flyingSeed(PlantKind, Int)
    case weed(Int)
    case uprooted(Plant)
}

struct GFlyer {
    var kind: GFlyerKind
    var p0: CGPoint
    var v0: CGVector
    var start: Double
    var dur: Double
    var spin: CGFloat
    var toBasket: Bool
    var toVase: Bool = false

    static let gravity: CGFloat = 1500

    func pos(_ t: Double) -> CGPoint {
        let s = CGFloat(t - start)
        return CGPoint(x: p0.x + v0.dx * s, y: p0.y + v0.dy * s + 0.5 * GFlyer.gravity * s * s)
    }

    static func aim(from: CGPoint, to: CGPoint, dur: Double) -> CGVector {
        let T = CGFloat(dur)
        return CGVector(dx: (to.x - from.x) / T, dy: (to.y - from.y - 0.5 * gravity * T * T) / T)
    }
}

struct SurprisePop {
    var surprise: BuriedSurprise
    var origin: CGPoint
    var start: Double
    var dur: Double = 1.3
}

struct GPlot {
    var state: GardenPlotState = .empty(surprise: .coins)
    var surpriseReady = true
    var surpriseResetAt: Double = 0
    var moundPop: CGFloat = 0
    var moundPopV: CGFloat = 0
    var bend: CGFloat = 0
    var bendV: CGFloat = 0
    var pop: CGFloat = 0
    var popV: CGFloat = 0
    var dry: CGFloat = 0
    var digWork: CGFloat = 0
    var waterPulse: CGFloat = 0
    var fillUntil: Double = 0
    var pull: CGFloat = 0
    var pullV: CGFloat = 0
    var held = false
    var sad = false

    var plant: Plant? {
        get {
            switch state {
            case .empty: return nil
            case .growing(let p), .ripe(let p): return p
            }
        }
        set {
            if let p = newValue {
                state = p.growth >= 1 ? .ripe(p) : .growing(p)
            } else {
                if case .empty = state { return }
                state = .empty(surprise: BuriedSurprise.random())
                surpriseReady = true
            }
        }
    }

    var surprise: BuriedSurprise? {
        if case .empty(let s) = state { return s }
        return nil
    }
}

struct GWeed {
    var x: CGFloat
    var growth: CGFloat
    var seed: Int
    var bend: CGFloat = 0
    var bendV: CGFloat = 0
    var pull: CGFloat = 0
    var pullV: CGFloat = 0
    var held = false
}

struct GDecor {
    var id: Int
    var kind: DecorKind
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat = 0
    var baseY: CGFloat = GGeo.yardY
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var spin: CGFloat = 0
    var spinV: CGFloat = 0
    var water: CGFloat = 0
    var held = false
    var poke: Double = -10
    var lit = true
}

struct GButterfly {
    var p: CGPoint
    var v: CGVector
    var target: CGPoint
    var perch: Int?
    var perchUntil: Double = 0
    var nextThink: Double = 0
    var phase: CGFloat
    var look: Int
    var leaving = false
}

struct GBee {
    var p: CGPoint
    var v: CGVector
    var target: CGPoint
    var perch: Int?
    var perchUntil: Double = 0
    var nextThink: Double = 0
    var phase: CGFloat = 0
    var leaving = false
}

struct GLadybug {
    var x: CGFloat
    var dir: CGFloat
    var flying = false
    var p: CGPoint
    var v = CGVector.zero
    var open: CGFloat = 0
    var nextTurn: Double = 4
    var walk: CGFloat = 0
}

struct GWorm {
    var x: CGFloat
    var depth: CGFloat
    var dir: CGFloat
    var phase: CGFloat = 0
    var peek: CGFloat = 0
    var peekUntil: Double = 0
    var nextPeek: Double = 12
    var wiggle: Double = -10
}

struct GFirefly {
    var p: CGPoint
    var v: CGVector
    var phase: CGFloat
}

final class GardenSim {
    static let gameID = "garden"
    static let gravity: CGFloat = 1700
    static let maxBouquet = 6

    // Soil height & wetness fields
    var h: [CGFloat]
    var wet: [CGFloat]

    // World entities
    var plots: [GPlot]
    var weeds: [GWeed] = []
    var decor: [GDecor] = []
    var particles: [GParticle] = []
    var flyers: [GFlyer] = []
    var surprisePops: [SurprisePop] = []
    var butterflies: [GButterfly] = []
    var bee: GBee?
    var ladybug: GLadybug
    var worm: GWorm
    var fireflies: [GFirefly] = []
    var visitors: [GVisitor] = []
    var nextVisit: Double = 7

    var basket: [String] = []
    var basketBounce: CGFloat = 0
    var basketBounceV: CGFloat = 0

    var bouquet: [BouquetFlower] = []
    var vaseBounce: CGFloat = 0
    var vaseBounceV: CGFloat = 0

    // Weather
    var weather: Weather = .sun
    var rain: CGFloat = 0
    var wind: CGFloat = 0.08
    var night: CGFloat = 0
    var cloud: CGFloat = 0.12
    var rainbowAt: Double = -100
    var windNow: CGFloat = 0
    var cloudDrift: CGFloat = 0

    // Time
    var time: Double = 0
    private var last: Date?
    private var lastSave: Double = 0
    private var nextWeed: Double = 18
    private var nextLeaf: Double = 0
    private var rainAcc: CGFloat = 0
    private var waterAcc: CGFloat = 0
    private var nextDecorID = 1

    // Carried tool
    var tool: GardenTool?
    var toolP = CGPoint.zero
    var hold = CGPoint.zero
    var finger = CGPoint.zero
    var toolV = CGVector.zero
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var load: CGFloat = 0
    var flow: CGFloat = 0
    var autoShovelActive = false
    private var lastToolP = CGPoint.zero
    private var seedTimer: CGFloat = 0
    private var digSound: Double = 0
    private var weedClearGraceUntil: Double = -10
    var returning: (tool: GardenTool, from: CGPoint, to: CGPoint, start: Double, tilt: CGFloat)?

    // Bare hand
    private enum Grab {
        case weed(Int)
        case carrot(Int)
        case decor(Int)
        case basketFeed
    }
    private var pickedThisStroke = Set<Int>()
    private var grab: Grab?
    private var grabStart = CGPoint.zero
    private var handP = CGPoint.zero
    private var handLast = CGPoint.zero
    var handV = CGVector.zero
    var handDown = false

    var isDraggingDecor: Bool {
        if case .decor? = grab { return true }
        if case .decor? = tool { return true }
        return false
    }
    var overReturnBadge = false

    func isOverReturnBadge(_ p: CGPoint) -> Bool {
        hypot(p.x - GGeo.returnBadge.x, p.y - GGeo.returnBadge.y) < 76
    }

    /// Screenshot / test mode: prevents overwriting persisted garden.json.
    var demo = false

    // MARK: Setup

    init(save: GardenSave? = GardenStorage.load()) {
        let n = GGeo.columns
        h = GardenSim.flatSoil(count: n)
        wet = [CGFloat](repeating: 0.06, count: n)
        let starterSurprises: [BuriedSurprise] = [.worm, .mysteryBulb, .ladybug, .coins, .worm, .coins]
        plots = GGeo.plotX.indices.map { i in
            GPlot(state: .empty(surprise: starterSurprises[i % starterSurprises.count]))
        }
        ladybug = GLadybug(x: 310, dir: 1, p: CGPoint(x: 310, y: GGeo.soilY))
        worm = GWorm(x: 470, depth: 52, dir: 1)
        if let s = save {
            restore(s)
        } else {
            starterGarden()
        }
        for i in 0..<2 { spawnButterfly(i, fromEdge: false) }
    }

    private static func flatSoil(count n: Int) -> [CGFloat] {
        (0..<n).map { i -> CGFloat in
            let fi = CGFloat(i)
            let waveA: CGFloat = sin(fi * 0.21) * 1.1
            let waveB: CGFloat = sin(fi * 0.07 + 1.3) * 1.2
            return GGeo.soilY + waveA + waveB
        }
    }

    private func starterGarden() {
        plots[0].plant = Plant(kind: .sunflower, growth: 0.35, left: 0, variant: 0)
        plots[2].plant = Plant(kind: .tomato, growth: 0.65, left: 0, variant: 0)
        plots[4].plant = Plant(kind: .tulip, growth: 1, left: 1, variant: 0)
        for i in 0..<GGeo.columns {
            let x = GGeo.colX(i)
            if abs(x - GGeo.plotX[4]) < 56 { wet[i] = 0.55 }
        }
        weeds = [GWeed(x: 308, growth: 0.85, seed: 3), GWeed(x: 564, growth: 0.65, seed: 8)]
        addDecor(.pinwheel, x: 196, falling: false)
        addDecor(.birdbath, x: 724, falling: false)
    }

    private func restore(_ s: GardenSave) {
        let n = GGeo.columns
        // Resample soil and wetness cleanly so legacy 224-column saves migrate without losing crops.
        if s.soil.count == n {
            let avg = s.soil.reduce(0, +) / Double(n)
            h = s.soil.map { val in
                let offset = CGFloat(val - avg)
                return max(GGeo.soilY - 22, min(GGeo.soilY + GGeo.maxDepth, GGeo.soilY + offset))
            }
        } else {
            h = GardenSim.flatSoil(count: n)
        }
        if s.wet.count == n {
            wet = s.wet.map { max(0, min(1.15, CGFloat($0))) }
        } else if !s.wet.isEmpty {
            wet = (0..<n).map { i in
                let idx = min(s.wet.count - 1, Int(Double(i) / Double(n) * Double(s.wet.count)))
                return max(0, min(1.15, CGFloat(s.wet[idx])))
            }
        }
        for i in 0..<min(plots.count, s.plots.count) {
            plots[i].plant = s.plots[i]
        }
        weeds = s.weeds.map { w in
            let x = max(GGeo.bedLeft + 18, min(GGeo.bedRight - 18, CGFloat(w.x)))
            return GWeed(x: x, growth: CGFloat(w.growth), seed: w.seed)
        }
        decor = []
        for d in s.decor {
            let idx = addDecor(d.kind, x: CGFloat(d.x), falling: false)
            decor[idx].water = CGFloat(d.water)
        }
        basket = Array(s.basket.suffix(60))
        bouquet = Array((s.bouquet ?? []).suffix(GardenSim.maxBouquet))
        weather = s.weather
        rain = weather == .rain ? 1 : 0
        night = weather == .night ? 1 : 0
        wind = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        cloud = weather == .rain ? 1 : (weather == .wind ? 0.45 : 0.12)
    }

    func makeSave() -> GardenSave {
        GardenSave(
            plots: plots.map { $0.plant },
            soil: h.map { Double($0) },
            wet: wet.map { Double($0) },
            weeds: weeds.map { WeedSave(x: Double($0.x), growth: Double($0.growth), seed: $0.seed) },
            decor: decor.map { DecorSave(kind: $0.kind, x: Double($0.x), water: Double($0.water)) },
            basket: Array(basket.suffix(40)),
            weather: weather,
            bouquet: bouquet.isEmpty ? nil : Array(bouquet.suffix(GardenSim.maxBouquet))
        )
    }

    func save() {
        guard !demo else { return }
        GardenStorage.save(makeSave())
    }

    // MARK: Soil helpers

    func surface(_ x: CGFloat) -> CGFloat {
        let f = (x - GGeo.bedLeft) / GGeo.col - 0.5
        let i0 = max(0, min(GGeo.columns - 1, Int(f.rounded(.down))))
        let i1 = min(GGeo.columns - 1, i0 + 1)
        let k = max(0, min(1, f - CGFloat(i0)))
        return h[i0] + (h[i1] - h[i0]) * k
    }

    func wetAt(_ x: CGFloat, span: Int = 4) -> CGFloat {
        let c = GGeo.column(x)
        var s: CGFloat = 0
        var n: CGFloat = 0
        for i in max(0, c - span)...min(GGeo.columns - 1, c + span) {
            s += wet[i]
            n += 1
        }
        return n > 0 ? s / n : 0
    }

    var totalSoil: CGFloat { h.reduce(0) { $0 + (GGeo.bedBottom - $1) } }

    private func deposit(_ mass: CGFloat, at x: CGFloat) {
        let c = GGeo.column(x)
        let lo = max(0, c - 2)
        let hi = min(GGeo.columns - 1, c + 2)
        guard lo <= hi else { return }
        let weights: [CGFloat] = [0.15, 0.25, 0.3, 0.2, 0.1]
        var wsum: CGFloat = 0
        for i in lo...hi { wsum += weights[i - c + 2] }
        for i in lo...hi { h[i] -= mass / GGeo.col * weights[i - c + 2] / wsum }
    }

    // MARK: Frame

    func step(_ now: Date) {
        let raw = last.map { now.timeIntervalSince($0) } ?? 1.0 / 60
        last = now
        step(dt: CGFloat(min(max(raw, 0), 1.0 / 30)))
    }

    func step(dt: CGFloat) {
        guard dt > 0 else { return }
        time += Double(dt)
        stepWeather(dt)
        stepTool(dt)
        stepSoil(dt)
        stepPlants(dt)
        stepWeeds(dt)
        stepParticles(dt)
        stepFlyers()
        stepDecor(dt)
        stepCritters(dt)
        stepFinds(dt)
        stepProps(dt)
        stepSound()
        if time - lastSave > 20 { lastSave = time; save() }
    }

    // MARK: Weather

    func setWeather(_ w: Weather) {
        guard w != weather else { return }
        if weather == .rain && (w == .sun || w == .wind) { rainbowAt = time }
        weather = w
        if w == .rain { fulfillRainVisitors() }
    }

    var rainbow: CGFloat {
        let t = CGFloat(time - rainbowAt)
        if t < 0 || t > 16 { return 0 }
        return min(gdEase(t / 2.5), gdEase((16 - t) / 3))
    }

    private func stepWeather(_ dt: CGFloat) {
        let rainT: CGFloat = weather == .rain ? 1 : 0
        let nightT: CGFloat = weather == .night ? 1 : 0
        let windT: CGFloat = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        let cloudT: CGFloat = weather == .rain ? 1 : (weather == .wind ? 0.45 : 0.12)
        let k = min(1, dt * 1.1)
        rain += (rainT - rain) * k
        night += (nightT - night) * k
        wind += (windT - wind) * k
        cloud += (cloudT - cloud) * k
        let t = CGFloat(time)
        let gust = 0.65 + 0.35 * sin(t * 0.9) + 0.18 * sin(t * 2.3 + 1)
        windNow = wind * gust + 0.03 * sin(t * 0.7)
        cloudDrift += dt * (6 + wind * 70)

        rainAcc += rain * 260 * dt
        while rainAcc >= 1 {
            rainAcc -= 1
            let x = CGFloat.random(in: -80...1104)
            let drop = GParticle(kind: .rain, p: CGPoint(x: x, y: CGFloat.random(in: -40 ... -6)),
                                 v: CGVector(dx: windNow * 240 + 25, dy: CGFloat.random(in: 980...1220)),
                                 life: 1.8, size: CGFloat.random(in: 1.2...2.2), color: GRGB(0xDDEBFA),
                                 groundY: CGFloat.random(in: 480...620))
            particles.append(drop)
        }
        if wind > 0.4 && time > nextLeaf {
            nextLeaf = time + Double.random(in: 0.25...0.85) / Double(wind)
            let colors = [GRGB(0x9CCB5A), GRGB(0xE8B44A), GRGB(0xE07B39), GRGB(0x6FB04B)]
            let leaf = GParticle(kind: .leaf, p: CGPoint(x: -60, y: CGFloat.random(in: 110...480)),
                                 v: CGVector(dx: 260, dy: 0), life: 8, size: CGFloat.random(in: 9...14),
                                 color: colors.randomElement() ?? colors[0], rot: CGFloat.random(in: 0...6),
                                 spin: CGFloat.random(in: -4...4))
            particles.append(leaf)
        }
    }

    // MARK: Tools

    func pickUp(_ t: GardenTool, at p: CGPoint) {
        tool = t
        finger = p
        hold = p
        toolP = p
        lastToolP = p
        toolV = .zero
        tilt = 0
        tiltV = 0
        load = 0
        autoShovelActive = false
        digSound = 0
        weedClearGraceUntil = -10
        returning = nil
        overReturnBadge = false
        for i in plots.indices { plots[i].digWork = 0 }
        switch t {
        case .shovel: GardenSound.shared.play(.plunk, volume: 0.5)
        case .can: GardenSound.shared.play(.splash, volume: 0.4)
        case .seeds: GardenSound.shared.play(.seeds, volume: 0.6)
        case .decor: GardenSound.shared.play(.plunk, volume: 0.5)
        }
    }

    func carry(to p: CGPoint, hand h: CGPoint? = nil) {
        finger = p
        hold = h ?? p
        if case .decor? = tool {
            overReturnBadge = isOverReturnBadge(hold) || isOverReturnBadge(p)
        }
    }

    func release(home: CGPoint) {
        guard let t = tool else { return }
        if load > 1 { dropLoad(throwV: CGVector(dx: toolV.dx * 0.3, dy: 0)) }
        switch t {
        case .decor(let k):
            if isOverReturnBadge(hold) || isOverReturnBadge(toolP) {
                Sound.shared.play(.whoosh, volume: 0.5)
            } else {
                let d = addDecor(k, x: toolP.x, falling: true)
                decor[d].y = min(toolP.y + k.size.height * 0.45, decor[d].baseY)
                Sound.shared.play(.whoosh, volume: 0.5)
            }
        case .seeds(let k):
            // Dropping a seed packet over an empty plot plants it immediately.
            if toolP.y < GGeo.bedBottom + 50,
               let idx = GGeo.plotX.indices.min(by: { abs(GGeo.plotX[$0] - toolP.x) < abs(GGeo.plotX[$1] - toolP.x) }),
               abs(GGeo.plotX[idx] - toolP.x) < 60,
               plots[idx].plant == nil {
                plant(k, plot: idx)
            }
            returning = (t, toolP, home, time, tilt)
        case .shovel, .can:
            returning = (t, toolP, home, time, tilt)
        }
        overReturnBadge = false
        autoShovelActive = false
        tool = nil
        flow = 0
    }

    private func stepTool(_ dt: CGFloat) {
        guard let t = tool else { return }
        let prev = toolP
        let follow = min(1, dt * 30)
        toolP.x += (finger.x - toolP.x) * follow
        toolP.y += (finger.y - toolP.y) * follow
        let vx = (toolP.x - prev.x) / dt
        let vy = (toolP.y - prev.y) / dt
        toolV.dx += (vx - toolV.dx) * min(1, dt * 18)
        toolV.dy += (vy - toolV.dy) * min(1, dt * 18)
        let overGarden = toolP.y < GGeo.bedBottom + 36 && toolP.x > 20 && toolP.x < 1004

        var target: CGFloat = 0
        switch t {
        case .can: target = overGarden ? 0.95 - toolV.dx * 0.0004 : 0
        case .shovel: target = max(-0.5, min(0.5, toolV.dx * 0.0009))
        case .seeds: target = overGarden ? 2.25 + sin(CGFloat(time) * 9) * 0.12 : 0
        case .decor: target = max(-0.38, min(0.38, toolV.dx * 0.0012))
        }
        tiltV += ((target - tilt) * 140 - tiltV * 15) * dt
        tilt += tiltV * dt

        switch t {
        case .can: pour(dt)
        case .shovel: dig(dt, from: prev)
        case .seeds(let k): sow(dt, kind: k)
        case .decor: break
        }
        lastToolP = toolP
    }

    func canSpout() -> (CGPoint, CGVector) {
        let a = -tilt
        let local = CGPoint(x: -112, y: -6)
        let dir0 = CGVector(dx: -0.85, dy: -0.52)
        let c = cos(a)
        let s = sin(a)
        let p = CGPoint(x: toolP.x + local.x * c - local.y * s, y: toolP.y + local.x * s + local.y * c)
        let d = CGVector(dx: dir0.dx * c - dir0.dy * s, dy: dir0.dx * s + dir0.dy * c)
        return (p, d)
    }

    private func pour(_ dt: CGFloat) {
        flow = gdClamp((tilt - 0.35) / 0.45)
        guard flow > 0 else { return }
        let (spout, dir) = canSpout()
        waterAcc += flow * 400 * dt
        let perp = CGVector(dx: -dir.dy, dy: dir.dx)
        while waterAcc >= 1 {
            waterAcc -= 1
            let speed = CGFloat.random(in: 170...255)
            let spread = CGFloat.random(in: -1...1)
            let j = CGFloat.random(in: -7...7) * FingerLift.spread
            let v = CGVector(dx: dir.dx * speed + perp.dx * spread * 66 * FingerLift.spread + toolV.dx * 0.3,
                             dy: dir.dy * speed + perp.dy * spread * 66 * FingerLift.spread + toolV.dy * 0.3)
            let drop = GParticle(kind: .water, p: CGPoint(x: spout.x + perp.dx * j, y: spout.y + perp.dy * j), v: v,
                                 life: 2.8, size: CGFloat.random(in: 3...5), color: GRGB(0xBFE3FF))
            particles.append(drop)
        }
    }

    // MARK: Fun Shovel Job

    private func dig(_ dt: CGFloat, from prev: CGPoint) {
        let tip = toolP
        let moved = hypot(tip.x - prev.x, tip.y - prev.y)
        if GGeo.inBed(tip.x) {
            let surf = surface(tip.x)
            // Always prioritize clearing weeds before any plot uproot, with a brief post-weed grace window.
            if tip.y > surf - 36,
               let wi = weeds.indices.min(by: { abs(weeds[$0].x - tip.x) < abs(weeds[$1].x - tip.x) }),
               abs(weeds[wi].x - tip.x) < 36 * FingerLift.spread {
                popWeed(wi, v: CGVector(dx: toolV.dx * 0.35 + CGFloat.random(in: -90...90), dy: -620))
                weedClearGraceUntil = time + 0.6
                for k in plots.indices { plots[k].digWork = 0 }
            }
            let weedNearby = weeds.contains { abs($0.x - tip.x) < 56 }
            if tip.y > surf - 8 {
                let c = GGeo.column(tip.x)
                var took: CGFloat = 0
                let floor = GGeo.soilY + GGeo.maxDepth
                let tipY = min(tip.y, floor)
                let reach = Int((5 * FingerLift.spread).rounded())
                for i in max(0, c - reach)...min(GGeo.columns - 1, c + reach) {
                    let d = CGFloat(i - c) / (5.0 * FingerLift.spread)
                    let w = exp(-d * d * 1.4)
                    let want = (tipY - 2.5 * d * d) - h[i]
                    if want > 0 {
                        let dh = min(want, 6 * w)
                        h[i] += dh
                        took += dh * GGeo.col
                    }
                }
                if took > 0 {
                    load += took
                    if time - digSound > 0.16 {
                        digSound = time
                        GardenSound.shared.play(.dig, volume: 0.7)
                        Sound.shared.tap()
                    }
                    for _ in 0..<Int(min(4, took / 24)) {
                        particles.append(GParticle(kind: .dust,
                                                   p: CGPoint(x: tip.x + CGFloat.random(in: -16...16) * FingerLift.spread, y: surf),
                                                   v: CGVector(dx: CGFloat.random(in: -40...40), dy: CGFloat.random(in: -60 ... -20)),
                                                   life: 0.7, size: CGFloat.random(in: 8...14), color: GRGB(0xB08660)))
                    }
                }
                if load > 900 {
                    let spill = load - 900
                    load = 900
                    deposit(spill * 0.5, at: tip.x - 28)
                    deposit(spill * 0.5, at: tip.x + 28)
                }
                for i in plots.indices {
                    let dx = abs(GGeo.plotX[i] - tip.x)
                    if plots[i].plant != nil && !autoShovelActive {
                        if !weedNearby && time >= weedClearGraceUntil && dx < 22 {
                            plots[i].digWork += max(moved, dt * 45)
                            plots[i].bendV += (tip.x - prev.x) * 0.025
                            if plots[i].digWork >= 28 {
                                uproot(i)
                            }
                        } else {
                            plots[i].digWork = max(0, plots[i].digWork - dt * 50)
                        }
                    } else if plots[i].plant == nil && plots[i].surpriseReady && dx < 38 {
                        plots[i].digWork += max(moved, dt * 60)
                        if plots[i].digWork >= 10 {
                            unearthSurprise(plot: i)
                        }
                    }
                }
            } else if load > 1 && tip.y < surf - 14 && toolV.dy < -240 {
                dropLoad(throwV: CGVector(dx: toolV.dx * 0.55, dy: toolV.dy * 0.6))
                GardenSound.shared.play(.toss, volume: 0.7)
            }
        } else if load > 1 && toolV.dy < -240 {
            dropLoad(throwV: CGVector(dx: toolV.dx * 0.55, dy: toolV.dy * 0.6))
            GardenSound.shared.play(.toss, volume: 0.7)
        }
    }

    @discardableResult
    func unearthSurprise(plot i: Int) -> BuriedSurprise? {
        guard plots.indices.contains(i) else { return nil }
        guard case .empty(let surprise) = plots[i].state, plots[i].surpriseReady else { return nil }
        plots[i].surpriseReady = false
        plots[i].surpriseResetAt = time + 5.0
        plots[i].digWork = 0
        plots[i].moundPopV += 10
        let x = GGeo.plotX[i]
        let surf = surface(x)
        let origin = CGPoint(x: x, y: surf - 16)
        burstSoil(at: CGPoint(x: x, y: surf), n: 9)
        sparkle(at: origin, count: 12)
        GardenSound.shared.play(.dig, volume: 0.8)
        Sound.shared.play(.sparkle, volume: 0.55)
        Sound.shared.tap()
        surprisePops.append(SurprisePop(surprise: surprise, origin: origin, start: time))
        switch surprise {
        case .worm:
            worm.x = x
            worm.peek = 0.45
            worm.peekUntil = time + 4.5
            worm.wiggle = time
            GardenSound.shared.play(.squeak, volume: 0.85)
            heartBurst(at: CGPoint(x: x, y: surf - 26), count: 4)
        case .ladybug:
            ladybug.x = x
            ladybug.p = CGPoint(x: x, y: surf - 8)
            ladybugTakeOff()
        case .coins:
            earnCoins(2, from: CGPoint(x: x, y: surf - 24))
        case .mysteryBulb:
            let kind = PlantKind.allCases.randomElement() ?? .tulip
            let rareVariant = Plant.specialVariant + Int.random(in: 0..<6)
            plant(kind, plot: i, forcedVariant: rareVariant)
            GardenSound.shared.play(.grow, volume: 0.85)
        }
        return surprise
    }

    func bestShovelTarget() -> CGPoint {
        if let w = weeds.first {
            return CGPoint(x: w.x, y: surface(w.x) + 4)
        }
        if let i = plots.indices.first(where: { plots[$0].plant == nil && plots[$0].surpriseReady }) {
            let x = GGeo.plotX[i]
            return CGPoint(x: x, y: surface(x) + 10)
        }
        if let i = plots.indices.first(where: { plots[$0].plant == nil }) {
            let x = GGeo.plotX[i]
            return CGPoint(x: x, y: surface(x) + 10)
        }
        return CGPoint(x: 436, y: GGeo.soilY + 6)
    }

    func bestWaterTarget() -> CGPoint {
        let growing = plots.indices.filter {
            guard let p = plots[$0].plant else { return false }
            return p.growth < 1
        }
        if let thirstiest = growing.max(by: { a, b in
            if abs(plots[a].dry - plots[b].dry) > 0.25 { return plots[a].dry < plots[b].dry }
            return wetAt(GGeo.plotX[a]) > wetAt(GGeo.plotX[b])
        }) {
            let x = GGeo.plotX[thirstiest]
            return CGPoint(x: x, y: surface(x) - 34)
        }
        if let pumpkinIdx = plots.indices.first(where: {
            guard let p = plots[$0].plant else { return false }
            return p.kind == .pumpkin && p.growth >= 1 && p.left > 0 && !p.giant
        }) {
            let x = GGeo.plotX[pumpkinIdx]
            return CGPoint(x: x, y: surface(x) - 34)
        }
        return CGPoint(x: GGeo.plotX[2], y: GGeo.soilY - 34)
    }

    /// Single-tap dock action for the shovel (pops weed or digs buried surprise, never uproots planted flowers).
    func autoShovel(at spot: CGPoint) {
        if let wi = weeds.indices.min(by: { abs(weeds[$0].x - spot.x) < abs(weeds[$1].x - spot.x) }),
           abs(weeds[wi].x - spot.x) < 56 {
            popWeed(wi, v: CGVector(dx: CGFloat.random(in: -90...90), dy: -620))
            return
        }
        if let i = plots.indices.min(by: { abs(GGeo.plotX[$0] - spot.x) < abs(GGeo.plotX[$1] - spot.x) }),
           abs(GGeo.plotX[i] - spot.x) < 60,
           plots[i].plant == nil {
            if plots[i].surpriseReady {
                unearthSurprise(plot: i)
            } else {
                let x = GGeo.plotX[i]
                plots[i].moundPopV += 6
                burstSoil(at: CGPoint(x: x, y: surface(x)), n: 6)
                GardenSound.shared.play(.dig, volume: 0.7)
            }
        }
    }

    private func dropLoad(throwV: CGVector) {
        let n = max(3, min(14, Int(load / 50)))
        let each = load / CGFloat(n)
        let browns = [GRGB(0x8A5A36), GRGB(0x7A4E2E), GRGB(0x9C6A42), GRGB(0x6B4428)]
        for k in 0..<n {
            let jx = CGFloat.random(in: -14...14)
            let v = CGVector(dx: throwV.dx + CGFloat.random(in: -110...110), dy: throwV.dy + CGFloat.random(in: -130...40))
            let clod = GParticle(kind: .clod, p: CGPoint(x: toolP.x + jx, y: toolP.y - 18 - CGFloat(k % 3) * 4), v: v,
                                 life: 5, size: CGFloat.random(in: 4...8), color: browns[k % browns.count],
                                 rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -9...9), mass: each)
            particles.append(clod)
        }
        load = 0
    }

    private func sow(_ dt: CGFloat, kind: PlantKind) {
        guard tilt > 1.5 else { return }
        seedTimer -= dt
        if seedTimer > 0 { return }
        seedTimer = 0.12
        let a = tilt
        let local = CGPoint(x: 0, y: -46)
        let p = CGPoint(x: toolP.x + local.x * cos(a) - local.y * sin(a), y: toolP.y + local.x * sin(a) + local.y * cos(a))
        let s = GParticle(kind: .seed, p: p, v: CGVector(dx: toolV.dx * 0.2 + CGFloat.random(in: -36...36), dy: CGFloat.random(in: 0...60)),
                          life: 4, size: kind == .pumpkin ? 5 : (kind == .sunflower ? 4.4 : 3.2), color: kind.seedColor,
                          rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -8...8), seed: kind)
        particles.append(s)
        if Int(time * 7.7) % 3 == 0 { GardenSound.shared.play(.seeds, volume: 0.35, gap: 0.25) }
    }

    // MARK: Zero-Friction Planting & Watering

    func plant(_ kind: PlantKind, plot i: Int, forcedVariant: Int? = nil) {
        guard plots.indices.contains(i), plots[i].plant == nil else { return }
        let p = Plant(kind: kind, growth: 0.08, left: 0, variant: forcedVariant ?? GardenSim.rollVariant())
        plots[i].state = .growing(p)
        plots[i].fillUntil = time + 0.65
        plots[i].dry = 0
        plots[i].waterPulse = 0
        plots[i].digWork = 0
        plots[i].pop = 0
        plots[i].popV = 8
        plots[i].moundPopV += 9
        GardenSound.shared.play(.pat, volume: 0.8)
        let x = GGeo.plotX[i]
        for _ in 0..<8 {
            particles.append(GParticle(kind: .dust, p: CGPoint(x: x + CGFloat.random(in: -26...26), y: surface(x) - 4),
                                       v: CGVector(dx: CGFloat.random(in: -70...70), dy: CGFloat.random(in: -70 ... -20)),
                                       life: 0.85, size: CGFloat.random(in: 10...17), color: GRGB(0xB58C66)))
        }
        sparkle(at: CGPoint(x: x, y: surface(x) - 20), count: 7)
    }

    /// Tapping a seed packet in the tray arcs a seed directly into the nearest open plot.
    @discardableResult
    func tossSeed(_ kind: PlantKind, from start: CGPoint) -> Int? {
        let reserved = Set(flyers.compactMap { flyer -> Int? in
            if case .flyingSeed(_, let idx) = flyer.kind { return idx }
            return nil
        })
        let open = plots.indices.filter { plots[$0].plant == nil && !reserved.contains($0) }
        guard let targetIdx = open.min(by: { abs(GGeo.plotX[$0] - start.x) < abs(GGeo.plotX[$1] - start.x) }) else {
            for i in plots.indices { plots[i].popV += 2.5 }
            Sound.shared.play(.boing, volume: 0.3)
            return nil
        }
        let x = GGeo.plotX[targetIdx]
        let dest = CGPoint(x: x, y: surface(x) - 4)
        let dur = 0.34
        flyers.append(GFlyer(kind: .flyingSeed(kind, targetIdx),
                             p0: start,
                             v0: GFlyer.aim(from: start, to: dest, dur: dur),
                             start: time, dur: dur, spin: 8, toBasket: false))
        GardenSound.shared.play(.seeds, volume: 0.7)
        Sound.shared.tap()
        return targetIdx
    }

    func sowRow(_ kind: PlantKind, from a: CGPoint, to b: CGPoint) {
        for i in plots.indices where plots[i].plant == nil {
            let x = GGeo.plotX[i]
            let dx = b.x - a.x
            let t = abs(dx) < 1 ? 1 : min(1, max(0, (x - a.x) / dx))
            let px = a.x + dx * t, py = a.y + (b.y - a.y) * t
            guard abs(px - x) < 62, abs(py - surface(x)) < 90 else { continue }
            plant(kind, plot: i)
            waterBed(at: x, amount: 0.28)
        }
    }

    private func waterBed(at x: CGFloat, amount: CGFloat) {
        for offset in -5...5 {
            water(at: x + CGFloat(offset) * GGeo.col, amount: amount)
        }
    }

    func waterPlant(at point: CGPoint) {
        guard GGeo.inBed(point.x) else { return }
        guard let plot = plots.indices.min(by: { abs(GGeo.plotX[$0] - point.x) < abs(GGeo.plotX[$1] - point.x) }) else { return }
        let x = GGeo.plotX[plot]
        let ground = surface(x)
        let top = head(plot: plot)?.y ?? ground
        guard point.y >= top - 90, point.y <= ground + 90 else { return }
        waterBed(at: x, amount: 0.65)
        plots[plot].popV += 4
        plots[plot].moundPopV += 4
        for _ in 0..<14 {
            particles.append(GParticle(kind: .water, p: CGPoint(x: x + CGFloat.random(in: -22...22), y: top - 52),
                                       v: CGVector(dx: CGFloat.random(in: -20...20), dy: 180), life: 1.8, size: 3.4, color: GRGB(0x8AD8FF)))
        }
        GardenSound.shared.play(.splash, volume: 0.6, gap: 0.1)
        fulfillRainVisitors()
    }

    func uproot(_ i: Int) {
        guard plots.indices.contains(i), let p = plots[i].plant else { return }
        plots[i].state = .empty(surprise: BuriedSurprise.random())
        plots[i].surpriseReady = false
        plots[i].surpriseResetAt = time + 4.0
        plots[i].digWork = 0
        plots[i].pull = 0
        plots[i].waterPulse = 0
        let base = CGPoint(x: GGeo.plotX[i], y: surface(GGeo.plotX[i]))
        let side: CGFloat = base.x < 440 ? -1 : 1
        flyers.append(GFlyer(kind: .uprooted(p), p0: base, v0: CGVector(dx: side * 240, dy: -660), start: time, dur: 1.3,
                             spin: side * 5, toBasket: false))
        GardenSound.shared.play(.pluck)
        burstSoil(at: base, n: 8)
    }

    // MARK: Soil

    private func stepSoil(_ dt: CGFloat) {
        let n = GGeo.columns
        for _ in 0..<2 {
            for i in 0..<(n - 1) {
                let d = h[i + 1] - h[i]
                let hold = 4.5 + 2.5 * min(wet[i], wet[i + 1])
                let ad = abs(d)
                if ad > hold {
                    let t = (ad - hold) * 0.25
                    if d > 0 { h[i] += t; h[i + 1] -= t } else { h[i] -= t; h[i + 1] += t }
                }
            }
        }
        for i in plots.indices where time < plots[i].fillUntil {
            let c = GGeo.column(GGeo.plotX[i])
            let lo = max(1, c - 14)
            let hi = min(n - 2, c + 14)
            var next = h
            let k = min(0.45, 14 * dt)
            for j in lo...hi { next[j] = h[j] + k * ((h[j - 1] + h[j + 1]) * 0.5 - h[j]) }
            h = next
            if plots[i].fillUntil - time < Double(dt) * 1.5 {
                for j in max(0, c - 6)...min(n - 1, c + 6) where h[j] > GGeo.soilY + 2 { h[j] = GGeo.soilY + 2 }
            }
        }
        for i in 0..<n { h[i] = max(GGeo.soilY - 22, min(GGeo.soilY + GGeo.maxDepth, h[i])) }

        let sunny = (1 - cloud) * (1 - night)
        let dry = (0.004 + 0.012 * sunny) * (1 - rain)
        var w = wet
        let D = min(0.4, 5 * dt)
        for i in 0..<n {
            let l = wet[max(0, i - 1)]
            let r = wet[min(n - 1, i + 1)]
            w[i] = wet[i] + D * (l + r - 2 * wet[i]) - dry * dt
            w[i] = max(0, min(1.15, w[i]))
        }
        wet = w
    }

    func water(at x: CGFloat, amount: CGFloat) {
        guard GGeo.inBed(x) else { return }
        let c = max(0, min(wet.count - 1, GGeo.column(x)))
        wet[c] = min(1.15, wet[c] + amount)
        if c > 0 { wet[c - 1] = min(1.15, wet[c - 1] + amount * 0.5) }
        if c < GGeo.columns - 1 { wet[c + 1] = min(1.15, wet[c + 1] + amount * 0.5) }

        // Watering a ripe pumpkin once more puffs it into a comical giant prize pumpkin.
        for i in plots.indices where abs(GGeo.plotX[i] - x) < 48 {
            if var p = plots[i].plant, p.kind == .pumpkin, p.growth >= 1, p.left > 0, !p.giant {
                plots[i].waterPulse += amount * 0.5
                if plots[i].waterPulse >= 0.45 {
                    p.giant = true
                    plots[i].state = .ripe(p)
                    plots[i].waterPulse = 0
                    plots[i].popV += 14
                    let center = CGPoint(x: GGeo.plotX[i] + 12, y: surface(GGeo.plotX[i]) - 42)
                    sparkle(at: center, count: 16)
                    Sound.shared.play(.boing, volume: 0.75)
                    Sound.shared.play(.sparkle, volume: 0.55)
                    GardenSound.shared.play(.grow, volume: 0.9)
                    discover(.giantPumpkin, at: center)
                }
            }
        }
    }

    // MARK: Plants (~4 second brisk growth)

    static let stages: [Double] = [0.25, 0.5, 0.75, 1.0]

    func head(plot i: Int) -> CGPoint? {
        guard plots.indices.contains(i), let p = plots[i].plant else { return nil }
        let base = CGPoint(x: GGeo.plotX[i], y: surface(GGeo.plotX[i]))
        let hgt = GardenPlants.stemHeight(p)
        let b = plots[i].bend
        return CGPoint(x: base.x + sin(b) * hgt, y: base.y - cos(b) * hgt)
    }

    func bloomed(_ i: Int) -> Bool {
        guard plots.indices.contains(i), let p = plots[i].plant else { return false }
        return p.kind.isFlower && p.growth >= 0.95
    }

    private func stepPlants(_ dt: CGFloat) {
        let t = CGFloat(time)
        for i in plots.indices {
            plots[i].moundPopV += (-160 * plots[i].moundPop - 11 * plots[i].moundPopV) * dt
            plots[i].moundPop += plots[i].moundPopV * dt
            if plots[i].plant == nil {
                plots[i].bend *= 0.9
                if !plots[i].surpriseReady && time >= plots[i].surpriseResetAt {
                    plots[i].state = .empty(surprise: BuriedSurprise.random())
                    plots[i].surpriseReady = true
                }
                continue
            }
            guard var p = plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let moist = wetAt(x, span: 5)
            let weedy = weeds.contains { abs($0.x - x) < 74 && $0.growth > 0.3 }
            plots[i].sad = weedy
            if p.growth < 1 {
                if moist > 0.1 {
                    var rate: Double = 0.25
                    if weather == .sun { rate *= 1.15 }
                    if weather == .night { rate *= 0.85 }
                    if weedy { rate *= 0.65 }
                    let before = p.growth
                    p.growth = min(1, p.growth + rate * Double(dt))
                    plots[i].dry = 0
                    let c = GGeo.column(x)
                    for j in max(0, c - 6)...min(GGeo.columns - 1, c + 6) {
                        wet[j] = max(0, wet[j] - 0.014 * dt)
                    }
                    for s in GardenSim.stages where before < s && p.growth >= s {
                        plots[i].popV += 8
                        let top = CGPoint(x: x, y: surface(x) - GardenPlants.stemHeight(p) - 10)
                        if s >= 1 {
                            p.left = p.kind.crop
                            plots[i].waterPulse = 0
                            sparkle(at: top, count: 14)
                            GardenSound.shared.play(.grow, volume: 0.9)
                            Sound.shared.play(.sparkle, volume: 0.45)
                        } else {
                            sparkle(at: top, count: 5)
                            GardenSound.shared.play(.grow, volume: 0.5)
                        }
                    }
                } else {
                    plots[i].dry += dt
                }
            } else {
                plots[i].dry = 0
            }
            plots[i].plant = p

            let hgt = max(30, GardenPlants.stemHeight(p))
            let k = 30 + 2400 / hgt
            let droop: CGFloat = (plots[i].dry > 1.5 ? 0.14 : 0) + (plots[i].sad ? 0.05 : 0)
            let rest = windNow * 0.34 + sin(t * 1.7 + CGFloat(i)) * 0.025 + droop * (i % 2 == 0 ? 1 : -1)
            var f = (rest - plots[i].bend) * k - plots[i].bendV * 3.4
            if rain > 0.2 { f += CGFloat.random(in: -1...1) * rain * 8 }
            plots[i].bendV += f * dt
            plots[i].bend += plots[i].bendV * dt
            plots[i].bend = max(-1.0, min(1.0, plots[i].bend))
            plots[i].popV += (-110 * plots[i].pop - 9 * plots[i].popV) * dt
            plots[i].pop += plots[i].popV * dt
            if !plots[i].held {
                plots[i].pullV += (-150 * plots[i].pull - 13 * plots[i].pullV) * dt
                plots[i].pull += plots[i].pullV * dt
            }
        }
    }

    // MARK: Weeds

    private func stepWeeds(_ dt: CGFloat) {
        let t = CGFloat(time)
        for i in weeds.indices {
            weeds[i].growth = min(1, weeds[i].growth + dt / 14)
            let rest = windNow * 0.4 + sin(t * 2.1 + CGFloat(weeds[i].seed)) * 0.03
            weeds[i].bendV += ((rest - weeds[i].bend) * 70 - weeds[i].bendV * 4) * dt
            weeds[i].bend += weeds[i].bendV * dt
            if !weeds[i].held {
                weeds[i].pullV += (-170 * weeds[i].pull - 12 * weeds[i].pullV) * dt
                weeds[i].pull += weeds[i].pullV * dt
            }
        }
        if time > nextWeed {
            nextWeed = time + Double.random(in: 22...36)
            guard weeds.count < 3 else { return }
            for _ in 0..<12 {
                let x = CGFloat.random(in: (GGeo.bedLeft + 24)...(GGeo.bedRight - 24))
                let nearPlot = GGeo.plotX.contains { abs($0 - x) < 34 }
                let nearWeed = weeds.contains { abs($0.x - x) < 52 }
                if !nearPlot && !nearWeed {
                    weeds.append(GWeed(x: x, growth: 0.05, seed: Int.random(in: 0..<1000)))
                    GardenSound.shared.play(.grow, volume: 0.25)
                    break
                }
            }
        }
    }

    private func popWeed(_ i: Int, v: CGVector) {
        let w = weeds.remove(at: i)
        let base = CGPoint(x: w.x, y: surface(w.x))
        flyers.append(GFlyer(kind: .weed(w.seed), p0: CGPoint(x: base.x, y: base.y - 10), v0: v, start: time, dur: 1.5,
                             spin: v.dx >= 0 ? 6 : -6, toBasket: false))
        GardenSound.shared.play(.pluck)
        Sound.shared.tap()
        burstSoil(at: base, n: 7)
        let c = GGeo.column(w.x)
        for j in max(0, c - 2)...min(GGeo.columns - 1, c + 2) { h[j] += 2 }
        sparkle(at: CGPoint(x: base.x, y: base.y - 26), count: 7)
    }

    private func burstSoil(at p: CGPoint, n: Int) {
        let browns = [GRGB(0x8A5A36), GRGB(0x7A4E2E), GRGB(0x9C6A42)]
        for k in 0..<n {
            particles.append(GParticle(kind: .clod, p: CGPoint(x: p.x + CGFloat.random(in: -10...10), y: p.y - 4),
                                       v: CGVector(dx: CGFloat.random(in: -210...210), dy: CGFloat.random(in: -480 ... -200)),
                                       life: 3.5, size: CGFloat.random(in: 3...6), color: browns[k % 3], rot: CGFloat.random(in: 0...6),
                                       spin: CGFloat.random(in: -9...9), mass: 0))
        }
    }

    // MARK: Particles

    private func stepParticles(_ dt: CGFloat) {
        let g = GardenSim.gravity
        var keep: [GParticle] = []
        keep.reserveCapacity(particles.count)
        for var q in particles {
            q.age += dt
            if q.age > q.life { continue }
            switch q.kind {
            case .water, .rain:
                q.v.dy += g * dt
                q.v.dx += windNow * (q.kind == .rain ? 40 : 30) * dt
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                if hitWater(&q) { continue }
            case .splash:
                q.v.dy += g * dt
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            case .clod, .seed:
                if q.resting {
                    if q.kind == .seed && q.age > q.life - 1 { q.size *= 0.98 }
                } else {
                    q.v.dy += g * dt
                    q.p.x += q.v.dx * dt
                    q.p.y += q.v.dy * dt
                    q.rot += q.spin * dt
                    if landSolid(&q) { continue }
                }
            case .petal, .leaf:
                let t = CGFloat(time)
                let flutter = sin(t * 5 + q.rot * 3) * 40
                let push = windNow * 280 + 20
                q.v.dx += (push - q.v.dx) * dt * 1.2
                q.v.dy += (70 + flutter - q.v.dy) * dt * 1.6
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
                let ground = GGeo.inBed(q.p.x) ? surface(q.p.x) : GGeo.lawnY + 20
                if q.p.y > ground {
                    q.p.y = ground
                    q.v = .zero
                    q.spin = 0
                }
                if q.p.x > 1160 { continue }
            case .sparkle:
                q.v.dy += 60 * dt
                q.v.dx *= (1 - dt * 2)
                q.v.dy *= (1 - dt * 2)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
            case .heart:
                q.v.dx += sin(CGFloat(time) * 5 + q.rot) * 45 * dt
                q.v.dx *= (1 - dt * 1.6)
                q.v.dy += (-110 - q.v.dy) * dt * 1.8
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            case .dust:
                q.v.dx *= (1 - dt * 3)
                q.v.dy *= (1 - dt * 3)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.size += dt * 14
            case .ripple:
                q.size += dt * 26
            }
            keep.append(q)
        }
        if keep.count > 1600 { keep.removeFirst(keep.count - 1600) }
        particles = keep
    }

    private func hitWater(_ q: inout GParticle) -> Bool {
        for i in decor.indices where decor[i].kind == .birdbath && !decor[i].held {
            let top = decor[i].y - 70
            if abs(q.p.x - decor[i].x) < 44 && q.p.y > top && q.p.y < top + 20 {
                decor[i].water = min(1, decor[i].water + (q.kind == .rain ? 0.005 : 0.012))
                if Int.random(in: 0..<5) == 0 { ripple(at: CGPoint(x: q.p.x, y: top + 4), small: true) }
                return true
            }
        }
        if q.kind == .water {
            for i in plots.indices {
                guard let p = plots[i].plant else { continue }
                let x = GGeo.plotX[i]
                let top = surface(x) - GardenPlants.stemHeight(p)
                if abs(q.p.x - x) < p.kind.reach * 0.6 && q.p.y > top && q.p.y < top + 44 {
                    plots[i].bendV += q.v.dx * 0.0006 + CGFloat.random(in: -0.02...0.02)
                }
            }
        }
        if GGeo.inBed(q.p.x) {
            let s = surface(q.p.x)
            if q.p.y >= s {
                water(at: q.p.x, amount: q.kind == .rain ? 0.032 : 0.015)
                let c = GGeo.column(q.p.x)
                let puddle = c >= 0 && c < wet.count && wet[c] > 0.85
                if puddle && Int.random(in: 0..<(q.kind == .rain ? 6 : 3)) == 0 {
                    ripple(at: CGPoint(x: q.p.x, y: s - 1), small: q.kind == .rain)
                }
                splash(at: CGPoint(x: q.p.x, y: s - 1), v: q.v, n: q.kind == .rain ? (Int.random(in: 0..<3) == 0 ? 1 : 0) : Int.random(in: 0..<2))
                if q.kind == .water { fulfillRainVisitors() }
                return true
            }
        } else {
            let ground = q.kind == .rain ? q.groundY : GGeo.lawnY + 10
            if q.p.y >= ground {
                splash(at: CGPoint(x: q.p.x, y: ground), v: q.v, n: Int.random(in: 0..<3) == 0 ? 1 : 0)
                return true
            }
            if q.p.y > 900 { return true }
        }
        return false
    }

    private func splash(at p: CGPoint, v: CGVector, n: Int) {
        guard n > 0 else { return }
        for _ in 0..<n {
            particles.append(GParticle(kind: .splash, p: p,
                                       v: CGVector(dx: v.dx * 0.15 + CGFloat.random(in: -85...85), dy: -CGFloat.random(in: 100...240)),
                                       life: 0.35, size: CGFloat.random(in: 1.2...2.2), color: GRGB(0xD6EEFF)))
        }
    }

    private func ripple(at p: CGPoint, small: Bool) {
        particles.append(GParticle(kind: .ripple, p: p, v: .zero, life: small ? 0.45 : 0.7, size: small ? 2 : 3, color: GRGB(0xFFFFFF)))
    }

    private func landSolid(_ q: inout GParticle) -> Bool {
        let ground: CGFloat = GGeo.inBed(q.p.x) ? surface(q.p.x) - q.size * 0.4 : GGeo.lawnY + 4
        guard q.p.y >= ground else { return false }
        q.p.y = ground
        let speed = hypot(q.v.dx, q.v.dy)
        if q.kind == .seed, let k = q.seed, GGeo.inBed(q.p.x) {
            if let i = GGeo.plotX.indices.min(by: { abs(GGeo.plotX[$0] - q.p.x) < abs(GGeo.plotX[$1] - q.p.x) }),
               abs(GGeo.plotX[i] - q.p.x) < 48,
               plots[i].plant == nil {
                plant(k, plot: i)
                return true
            }
        }
        if speed > 240 && q.bounces < 2 {
            q.bounces += 1
            q.v.dy = -q.v.dy * 0.28
            q.v.dx *= 0.55
            q.spin *= 0.5
            if q.kind == .clod && speed > 500 && q.size > 5 {
                var crumb = q
                crumb.size *= 0.55
                crumb.mass *= 0.3
                q.mass *= 0.7
                crumb.v = CGVector(dx: -q.v.dx + CGFloat.random(in: -60...60), dy: q.v.dy * 0.8)
                particles.append(crumb)
            }
            return false
        }
        if q.kind == .clod {
            if GGeo.inBed(q.p.x) { deposit(q.mass, at: q.p.x) }
            if Int.random(in: 0..<2) == 0 {
                particles.append(GParticle(kind: .dust, p: q.p, v: CGVector(dx: 0, dy: -12), life: 0.5, size: q.size * 1.6, color: GRGB(0xA27A55)))
            }
            if GGeo.inBed(q.p.x) { return true }
            q.resting = true
            q.life = q.age + 1.1
            return false
        }
        q.resting = true
        q.v = .zero
        q.life = q.age + 1.2
        return false
    }

    func sparkle(at p: CGPoint, count: Int) {
        let colors = [GRGB(0xFFFFFF), GRGB(0xFFE38A), GRGB(0xFFB3CF)]
        for k in 0..<count {
            let a = CGFloat(k) / CGFloat(max(1, count)) * 2 * .pi + CGFloat.random(in: -0.3...0.3)
            let sp = CGFloat.random(in: 85...180)
            particles.append(GParticle(kind: .sparkle, p: p, v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 35), life: 0.8,
                                       size: CGFloat.random(in: 7...13), color: colors[k % 3], rot: 0,
                                       spin: CGFloat.random(in: -3...3)))
        }
    }

    func heartBurst(at p: CGPoint, count: Int) {
        let colors = [GRGB(0xFF7CA8), GRGB(0xFF9EC2), GRGB(0xFFB3CF)]
        for k in 0..<count {
            let dx = (CGFloat(k) - CGFloat(count - 1) / 2) * 28 + CGFloat.random(in: -14...14)
            particles.append(GParticle(kind: .heart,
                                       p: CGPoint(x: p.x + CGFloat.random(in: -14...14), y: p.y),
                                       v: CGVector(dx: dx, dy: CGFloat.random(in: -160 ... -90)),
                                       life: 1.15, size: CGFloat.random(in: 14...20),
                                       color: colors[k % colors.count], rot: CGFloat.random(in: 0...6)))
        }
    }

    // MARK: Flyers, basket, vase & surprise pops

    private func stepFlyers() {
        var keep: [GFlyer] = []
        for f in flyers {
            if time - f.start < f.dur {
                keep.append(f)
                continue
            }
            if case .flyingSeed(let kind, let idx) = f.kind {
                plant(kind, plot: idx)
            }
            if f.toBasket {
                basketBounceV += 9
                GardenSound.shared.play(.basket, volume: 0.9)
                Sound.shared.play(.ding, volume: 0.35)
                sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 30), count: 6)
            }
            if f.toVase {
                vaseBounceV += 10
                GardenSound.shared.play(.basket, volume: 0.7)
                Sound.shared.play(.ding, volume: 0.4)
                sparkle(at: CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 68), count: 8)
            }
        }
        flyers = keep
    }

    private func stepProps(_ dt: CGFloat) {
        basketBounceV += (-160 * basketBounce - 10 * basketBounceV) * dt
        basketBounce += basketBounceV * dt
        vaseBounceV += (-170 * vaseBounce - 10 * vaseBounceV) * dt
        vaseBounce += vaseBounceV * dt
        surprisePops.removeAll { time - $0.start >= $0.dur }
    }

    func harvest(_ i: Int) {
        guard plots.indices.contains(i), var p = plots[i].plant, p.growth >= 1, p.left > 0 else { return }
        let x = GGeo.plotX[i]
        let base = CGPoint(x: x, y: surface(x))
        var from = head(plot: i) ?? base
        switch p.kind {
        case .tomato:
            let spots = GardenPlants.tomatoSpots
            let s = spots[(p.kind.crop - p.left) % spots.count]
            from = CGPoint(x: base.x + s.x, y: base.y - s.y)
        case .strawberry:
            let s = GardenPlants.berrySpots[(p.kind.crop - p.left) % GardenPlants.berrySpots.count]
            from = CGPoint(x: base.x + s.x, y: base.y - s.y)
        case .pumpkin:
            from = CGPoint(x: base.x + 12, y: base.y - (p.giant ? 42 : 28))
        case .carrot:
            from = CGPoint(x: base.x, y: base.y + 8)
        default: break
        }
        let wasGiant = p.giant
        basket.append("\(p.kind.rawValue):\(p.variant)")
        if basket.count > 60 { basket.removeFirst(basket.count - 60) }
        p.left -= 1

        if p.kind.isFlower {
            bouquet.append(BouquetFlower(kind: p.kind, variant: p.variant))
            if bouquet.count > GardenSim.maxBouquet {
                bouquet.removeFirst(bouquet.count - GardenSim.maxBouquet)
            }
            let target = CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 64)
            let dur = 0.62 + Double(abs(target.x - from.x)) / 2400
            flyers.append(GFlyer(kind: .flowerToVase(p.kind, p.variant), p0: from,
                                 v0: GFlyer.aim(from: from, to: target, dur: dur),
                                 start: time, dur: dur, spin: CGFloat.random(in: -5...5),
                                 toBasket: false, toVase: true))
            petals(at: from, color: p.kind.bloom(p.variant), n: 6)
        } else {
            let target = CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 20)
            let dur = 0.65 + Double(abs(target.x - from.x)) / 2400
            flyers.append(GFlyer(kind: .crop(p.kind, p.variant, wasGiant), p0: from,
                                 v0: GFlyer.aim(from: from, to: target, dur: dur),
                                 start: time, dur: dur, spin: CGFloat.random(in: -6...6),
                                 toBasket: true, toVase: false))
            if wasGiant {
                sparkle(at: from, count: 16)
                Sound.shared.play(.sparkle, volume: 0.6)
            }
        }

        GardenSound.shared.play(.pluck, volume: 0.8)
        Sound.shared.tap()
        plots[i].bendV += CGFloat.random(in: -1.5...1.5)
        plots[i].popV += 5
        fulfillMatchingVisitors(harvested: p.kind)

        if p.left <= 0 {
            switch p.kind {
            case .carrot:
                plots[i].state = .empty(surprise: BuriedSurprise.random())
                plots[i].surpriseReady = true
                plots[i].pull = 0
                burstSoil(at: base, n: 9)
                let c = GGeo.column(x)
                for j in max(0, c - 4)...min(GGeo.columns - 1, c + 4) { h[j] += 4 }
                return
            case .pumpkin:
                p.growth = 0.55
                p.giant = false
                plots[i].waterPulse = 0
            default:
                p.growth = 0.65
            }
            p.left = 0
        }
        plots[i].plant = p
    }

    private func petals(at p: CGPoint, color: GRGB, n: Int) {
        for _ in 0..<n {
            particles.append(GParticle(kind: .petal, p: p, v: CGVector(dx: CGFloat.random(in: -80...80), dy: CGFloat.random(in: -120 ... -30)),
                                       life: 3.2, size: CGFloat.random(in: 6...9), color: color, rot: CGFloat.random(in: 0...6),
                                       spin: CGFloat.random(in: -5...5)))
        }
    }

    // MARK: Bare hand (foreground plants/weeds/carrots always beat background decor)

    func plantHit(_ p: CGPoint) -> Int? {
        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            let top = base - GardenPlants.stemHeight(pl) - 38
            if abs(p.x - x) < pl.kind.reach + 14 && p.y > top && p.y < base + 42 {
                return i
            }
        }
        return nil
    }

    private func blockingPlantHit(_ p: CGPoint) -> Int? {
        guard let i = plantHit(p), let pl = plots[i].plant else { return nil }
        if pl.growth >= 1 && pl.left > 0 { return i }
        if abs(p.x - GGeo.plotX[i]) < 26 { return i }
        return nil
    }

    func handBegan(_ p: CGPoint) {
        pickedThisStroke.removeAll(keepingCapacity: true)
        handDown = true
        handP = p
        handLast = p
        handV = .zero
        grabStart = p
        grab = nil
        overReturnBadge = false

        // 1. Weeds have top foreground priority.
        if let w = weeds.indices.min(by: { abs(weeds[$0].x - p.x) < abs(weeds[$1].x - p.x) }) {
            let base = surface(weeds[w].x)
            let tall = 30 + 50 * weeds[w].growth
            if abs(weeds[w].x - p.x) < 38 && p.y > base - tall - 18 && p.y < base + 26 {
                grab = .weed(w)
                weeds[w].held = true
                GardenSound.shared.play(.pluck, volume: 0.25, gap: 0.2)
                return
            }
        }
        // 2. Ripe carrots grab for elastic pull-up harvest.
        for i in plots.indices {
            guard let pl = plots[i].plant, pl.kind == .carrot, pl.growth >= 1 else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            if abs(x - p.x) < 48 && p.y > base - 105 && p.y < base + 42 {
                grab = .carrot(i)
                plots[i].held = true
                return
            }
        }
        // 2b. Dragging harvest from basket to a visitor.
        if hypot(p.x - GGeo.basket.x, p.y - (GGeo.basket.y - 10)) < 62 {
            if !basket.isEmpty {
                grab = .basketFeed
                basketBounceV += 6
            }
            return
        }
        // 3. Foreground ripe plants, plant stems, visitors, and bouquet vase beat background decor,
        // while short decor peeking beside a growing plant remains reachable.
        if blockingPlantHit(p) != nil
            || visitorHit(p) != nil
            || hypot(p.x - GGeo.vase.x, p.y - (GGeo.vase.y - 48)) < 64 {
            return
        }
        // 4. Background lawn decorations.
        if let d = decorHit(p) {
            grab = .decor(d)
            decor[d].held = true
            decor[d].poke = time
            overReturnBadge = isOverReturnBadge(p)
            GardenSound.shared.play(.plunk, volume: 0.4)
        }
    }

    func handMoved(_ p: CGPoint, dt: CGFloat = 1.0 / 60) {
        let vx = (p.x - handP.x) / max(dt, 0.001)
        let vy = (p.y - handP.y) / max(dt, 0.001)
        handV = CGVector(dx: vx, dy: vy)
        handLast = handP
        handP = p
        switch grab {
        case .weed(let w)?:
            guard w < weeds.count else { grab = nil; return }
            let up = max(0, grabStart.y - p.y)
            weeds[w].pull = up / 95
            weeds[w].bend = max(-0.6, min(0.6, (p.x - grabStart.x) / 150))
            if weeds[w].pull >= 1 {
                grab = nil
                popWeed(w, v: CGVector(dx: (p.x - grabStart.x) * 2 + CGFloat.random(in: -80...80), dy: -740))
            } else if Int(up) % 24 == 0 && up > 4 {
                GardenSound.shared.play(.pluck, volume: 0.15, gap: 0.15)
            }
        case .carrot(let i)?:
            let up = max(0, grabStart.y - p.y)
            plots[i].pull = up / 80
            plots[i].bend = max(-0.5, min(0.5, (p.x - grabStart.x) / 160))
            if plots[i].pull >= 1 {
                plots[i].held = false
                grab = nil
                harvest(i)
            }
        case .decor(let d)?:
            guard d < decor.count else { grab = nil; return }
            let k = decor[d].kind
            decor[d].x = max(GGeo.yardMinX, min(GGeo.yardMaxX, p.x))
            decor[d].y = p.y + k.size.height * 0.45
            decor[d].vy = 0
            decor[d].tiltV += (p.x - handLast.x) * 0.05
            overReturnBadge = isOverReturnBadge(p)
        case .basketFeed?:
            break
        case nil:
            brush(from: handLast, to: p)
        }
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        handDown = false
        switch grab {
        case .weed(let w)?:
            if w < weeds.count {
                let pulled = weeds[w].pull >= 0.75
                weeds[w].held = false
                if pulled {
                    popWeed(w, v: CGVector(dx: (p.x - grabStart.x) * 2, dy: -700))
                }
            }
        case .carrot(let i)?:
            let pulled = plots[i].pull >= 0.72
            plots[i].held = false
            if pulled {
                harvest(i)
            } else if tap {
                plots[i].pullV += 6
                plots[i].popV += 5
                GardenSound.shared.play(.rustle, volume: 0.65)
                Sound.shared.play(.boing, volume: 0.3)
            }
        case .decor(let d)?:
            if d < decor.count {
                decor[d].held = false
                if tap {
                    decor[d].y = decor[d].baseY
                    pokeDecor(d)
                } else if isOverReturnBadge(p) {
                    removeDecor(d)
                } else {
                    decor[d].baseY = max(484, min(504, p.y + decor[d].kind.size.height * 0.45))
                    decor[d].y = min(decor[d].y, decor[d].baseY)
                }
            }
            overReturnBadge = false
        case .basketFeed?:
            if tap {
                basketBounceV += 12
                GardenSound.shared.play(.basket, volume: 0.75)
                Sound.shared.tap()
                sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 40), count: 8)
            } else {
                _ = feedVisitorFromBasket(at: p)
            }
        case nil:
            if tap { tapAt(p) }
        }
        grab = nil
    }

    private func brush(from a: CGPoint, to b: CGPoint) {
        let dx = b.x - a.x
        let sweep = abs(b.x - grabStart.x) > 22
        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            let top = base - GardenPlants.stemHeight(pl) - 32
            if sweep && pl.kind != .carrot && pl.growth >= 1 && pl.left > 0 && !pickedThisStroke.contains(i) {
                let t = abs(dx) > 1 ? min(1, max(0, (x - a.x) / dx)) : 1
                let y = a.y + (b.y - a.y) * t
                if abs(a.x + dx * t - x) < pl.kind.reach + 6 && y >= top && y <= base + 10 {
                    pickedThisStroke.insert(i)
                    harvest(i)
                }
            }
            if abs(b.x - x) < pl.kind.reach + 10 && b.y > top && b.y < base + 6 {
                let leverage = (base - b.y) / max(40, base - top)
                plots[i].bendV += dx * 0.05 * (0.4 + leverage)
                if bloomed(i) && abs(dx) > 14 && Int.random(in: 0..<4) == 0, let hd = head(plot: i) {
                    petals(at: hd, color: pl.kind.bloom(pl.variant), n: 1)
                }
                if abs(dx) > 6 { GardenSound.shared.play(.rustle, volume: 0.5, gap: 0.22) }
            }
        }
        for i in weeds.indices {
            let base = surface(weeds[i].x)
            if abs(b.x - weeds[i].x) < 30 && b.y > base - 80 && b.y < base + 4 {
                weeds[i].bendV += dx * 0.06
            }
        }
        scareBugs(near: b, radius: 70)
    }

    private func scareBugs(near p: CGPoint, radius: CGFloat) {
        for i in butterflies.indices where hypot(butterflies[i].p.x - p.x, butterflies[i].p.y - p.y) < radius {
            flee(i, from: p)
        }
        if var b = bee, hypot(b.p.x - p.x, b.p.y - p.y) < radius {
            b.perch = nil
            b.v = CGVector(dx: (b.p.x - p.x) * 6, dy: -200)
            b.nextThink = time + 0.8
            bee = b
            GardenSound.shared.play(.buzz, volume: 0.6, gap: 0.4)
        }
        if !ladybug.flying && abs(ladybug.p.x - p.x) < radius * 0.6 && abs(ladybug.p.y - p.y) < radius * 0.6 {
            ladybugTakeOff()
        }
    }

    private func flee(_ i: Int, from p: CGPoint) {
        let b = butterflies[i]
        let dx = b.p.x - p.x
        let dy = b.p.y - p.y
        let d = max(1, hypot(dx, dy))
        butterflies[i].perch = nil
        butterflies[i].v = CGVector(dx: dx / d * 260, dy: min(-120, dy / d * 260))
        butterflies[i].target = CGPoint(x: CGFloat.random(in: 100...924), y: CGFloat.random(in: 120...300))
        butterflies[i].nextThink = time + 2
        GardenSound.shared.play(.flutter, volume: 0.6, gap: 0.3)
    }

    private func tapAt(_ p: CGPoint) {
        // Woven harvest basket
        if hypot(p.x - GGeo.basket.x, p.y - (GGeo.basket.y - 10)) < 62 {
            basketBounceV += 12
            GardenSound.shared.play(.basket, volume: 0.75)
            Sound.shared.tap()
            sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 40), count: 8)
            return
        }
        // Bouquet vase on cedar bench
        if hypot(p.x - GGeo.vase.x, p.y - (GGeo.vase.y - 48)) < 64 {
            vaseBounceV += 12
            Sound.shared.play(.ding, volume: 0.5)
            Sound.shared.tap()
            sparkle(at: CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 72), count: 8)
            if let last = bouquet.last {
                petals(at: CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 78), color: last.kind.bloom(last.variant), n: 5)
            }
            return
        }
        if tapVisitor(p) { return }
        for i in butterflies.indices where hypot(butterflies[i].p.x - p.x, butterflies[i].p.y - p.y) < 56 {
            flee(i, from: CGPoint(x: p.x, y: p.y + 20))
            sparkle(at: butterflies[i].p, count: 5)
            return
        }
        if let b = bee, hypot(b.p.x - p.x, b.p.y - p.y) < 50 {
            scareBugs(near: p, radius: 60)
            return
        }
        if hypot(ladybug.p.x - p.x, ladybug.p.y - p.y) < 42 {
            ladybugTakeOff()
            return
        }
        let wormHead = CGPoint(x: worm.x, y: surface(worm.x) + worm.depth * (1 - worm.peek) - 14 * worm.peek)
        if hypot(wormHead.x - p.x, wormHead.y - p.y) < 50 {
            worm.wiggle = time
            GardenSound.shared.play(.squeak, volume: 0.8)
            return
        }
        if let i = plantHit(p), let pl = plots[i].plant {
            let x = GGeo.plotX[i]
            if pl.growth >= 1 && pl.left > 0 && !pl.kind.pulled {
                harvest(i)
            } else {
                plots[i].popV += 6
                plots[i].bendV += (p.x < x ? 1.2 : -1.2)
                GardenSound.shared.play(.rustle, volume: 0.6)
                if plots[i].dry > 1.5 {
                    Sound.shared.play(.boing, volume: 0.3)
                }
            }
            return
        }
        if GGeo.inBed(p.x) && abs(p.y - surface(p.x)) < 50 {
            let s = surface(p.x)
            for _ in 0..<5 {
                particles.append(GParticle(kind: .dust, p: CGPoint(x: p.x + CGFloat.random(in: -14...14), y: s),
                                           v: CGVector(dx: CGFloat.random(in: -50...50), dy: CGFloat.random(in: -60 ... -20)),
                                           life: 0.6, size: CGFloat.random(in: 7...12), color: GRGB(0xB08660)))
            }
            GardenSound.shared.play(.pat, volume: 0.5)
        }
    }

    // MARK: Safe Decorations

    @discardableResult
    func placeDecorOnFreeSpot(_ k: DecorKind) -> Int {
        // Open gap slots sit between plot stems and beside the cedar bed so short decor never hides behind tall plants.
        let candidates: [CGFloat] = [180, 308, 436, 564, 692, 856, 928, 72, 212, 340, 468, 596, 724, 892]
        let bestX = candidates.max { a, b in
            scoreDecorSpot(a, for: k) < scoreDecorSpot(b, for: k)
        } ?? 856
        let idx = addDecor(k, x: bestX, falling: true)
        Sound.shared.play(.pop, volume: 0.6)
        Sound.shared.tap()
        return idx
    }

    private func scoreDecorSpot(_ x: CGFloat, for k: DecorKind) -> CGFloat {
        let decorClear = min(150, decor.map { abs($0.x - x) }.min() ?? 150)
        var plantPenalty: CGFloat = 0
        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let dx = abs(GGeo.plotX[i] - x)
            let span = pl.kind.reach + 14
            if dx < span {
                let tallPlant = pl.kind.height >= k.size.height
                plantPenalty += tallPlant ? 240 : 120
            }
        }
        return decorClear - plantPenalty
    }

    @discardableResult
    func addDecor(_ k: DecorKind, x: CGFloat, falling: Bool) -> Int {
        if decor.count >= 14 { removeDecor(0) }
        var d = GDecor(id: nextDecorID, kind: k, x: max(GGeo.yardMinX, min(GGeo.yardMaxX, x)), y: GGeo.yardY)
        nextDecorID += 1
        d.baseY = GGeo.yardY + CGFloat(nextDecorID % 3) * 4 - 4
        d.y = falling ? d.baseY - 110 : d.baseY
        decor.append(d)
        return decor.count - 1
    }

    func removeDecor(_ i: Int) {
        guard decor.indices.contains(i) else { return }
        let d = decor.remove(at: i)
        for _ in 0..<10 {
            particles.append(GParticle(kind: .dust, p: CGPoint(x: d.x + CGFloat.random(in: -30...30), y: d.y - CGFloat.random(in: 0...60)),
                                       v: CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: -60...0)), life: 0.6,
                                       size: CGFloat.random(in: 12...20), color: GRGB(0xFFFFFF)))
        }
        Sound.shared.play(.whoosh, volume: 0.5)
    }

    func decorHit(_ p: CGPoint) -> Int? {
        for i in decor.indices.reversed() {
            let d = decor[i]
            let s = d.kind.size
            if abs(p.x - d.x) < s.width * 0.6 && p.y < d.y + 12 && p.y > d.y - s.height - 10 { return i }
        }
        return nil
    }

    private func pokeDecor(_ i: Int) {
        decor[i].poke = time
        decor[i].squashV -= 6
        switch decor[i].kind {
        case .pinwheel:
            decor[i].spinV += 22
            Sound.shared.play(.whoosh, volume: 0.4)
        case .lantern:
            decor[i].lit.toggle()
            Sound.shared.play(.sparkle, volume: 0.4)
        case .birdhouse:
            GardenSound.shared.play(.chirp, volume: 0.9)
        case .bunny:
            decor[i].vy = -400
            Sound.shared.play(.boing, volume: 0.5)
        case .mushroom:
            decor[i].squashV -= 6
            Sound.shared.play(.boing, volume: 0.5)
        case .birdbath:
            decor[i].tiltV += 3
            for _ in 0..<5 {
                splash(at: CGPoint(x: decor[i].x + CGFloat.random(in: -30...30), y: decor[i].y - 72),
                       v: .zero, n: decor[i].water > 0.1 ? 1 : 0)
            }
            GardenSound.shared.play(.splash, volume: decor[i].water > 0.1 ? 0.6 : 0.2)
        case .flamingo, .flag:
            decor[i].tiltV += 4
            Sound.shared.play(.boing, volume: 0.4)
        case .crystal, .rainbow, .unicorn:
            decor[i].tiltV += 3
            Sound.shared.play(.sparkle, volume: 0.5)
        case .lotus:
            decor[i].tiltV += 2.6
            sparkle(at: CGPoint(x: decor[i].x, y: decor[i].y - 68), count: 8)
            Sound.shared.play(.sparkle, volume: 0.55)
        }
    }

    private func stepDecor(_ dt: CGFloat) {
        for i in decor.indices {
            if !decor[i].held {
                if decor[i].y < decor[i].baseY || decor[i].vy < 0 {
                    decor[i].vy += GardenSim.gravity * dt
                    decor[i].y += decor[i].vy * dt
                    if decor[i].y >= decor[i].baseY {
                        decor[i].y = decor[i].baseY
                        if decor[i].vy > 200 {
                            decor[i].squashV -= decor[i].vy * 0.012
                            GardenSound.shared.play(.plunk, volume: Float(min(1, decor[i].vy / 900)))
                            for _ in 0..<4 {
                                particles.append(GParticle(kind: .dust, p: CGPoint(x: decor[i].x + CGFloat.random(in: -26...26), y: decor[i].y),
                                                           v: CGVector(dx: CGFloat.random(in: -50...50), dy: -20), life: 0.5,
                                                           size: CGFloat.random(in: 8...12), color: GRGB(0xCFE8B8)))
                            }
                        }
                        decor[i].vy = decor[i].vy > 260 ? -decor[i].vy * 0.2 : 0
                    }
                }
            }
            decor[i].squashV += (-240 * decor[i].squash - 11 * decor[i].squashV) * dt
            decor[i].squash += decor[i].squashV * dt
            let lean = decor[i].kind == .flag || decor[i].kind == .flamingo ? windNow * 0.12 : 0
            decor[i].tiltV += ((lean - decor[i].tilt) * 90 - decor[i].tiltV * 6) * dt
            decor[i].tilt += decor[i].tiltV * dt
            let spinRest = 1.2 + windNow * 16
            decor[i].spinV += (spinRest - decor[i].spinV) * dt * 0.8
            decor[i].spin += decor[i].spinV * dt
            if decor[i].kind == .birdbath {
                let sunny = (1 - cloud) * (1 - night)
                decor[i].water = max(0, decor[i].water - 0.004 * sunny * dt)
            }
        }
    }

    // MARK: Bugs

    private func spawnButterfly(_ k: Int, fromEdge: Bool) {
        let left = Bool.random()
        let p = fromEdge ? CGPoint(x: left ? -50 : 1074, y: CGFloat.random(in: 140...340))
                         : CGPoint(x: CGFloat.random(in: 180...800), y: CGFloat.random(in: 150...340))
        butterflies.append(GButterfly(p: p, v: CGVector(dx: left ? 80 : -80, dy: 0),
                                      target: CGPoint(x: CGFloat.random(in: 180...800), y: CGFloat.random(in: 150...340)),
                                      phase: CGFloat.random(in: 0...6), look: Int.random(in: 0..<5)))
    }

    func ladybugTakeOff() {
        ladybug.flying = true
        ladybug.v = CGVector(dx: CGFloat.random(in: -1...1) * 180, dy: -320)
        GardenSound.shared.play(.flutter, volume: 0.5)
    }

    private func stepCritters(_ dt: CGFloat) {
        let t = CGFloat(time)
        let outside = rain < 0.35 && night < 0.5
        let blooms = plots.indices.filter { bloomed($0) }

        let want = outside ? 2 + min(2, blooms.count) : 0
        if butterflies.filter({ !$0.leaving }).count < want && Int.random(in: 0..<200) == 0 {
            spawnButterfly(butterflies.count, fromEdge: true)
        }
        var live = butterflies.filter { !$0.leaving }.count
        for i in butterflies.indices where live > want && !butterflies[i].leaving {
            butterflies[i].leaving = true
            butterflies[i].perch = nil
            butterflies[i].target = CGPoint(x: butterflies[i].p.x < 512 ? -120 : 1144, y: 140)
            live -= 1
        }
        for i in butterflies.indices {
            var b = butterflies[i]
            if let pi = b.perch {
                if let hd = head(plot: pi), bloomed(pi), time < b.perchUntil {
                    b.p = CGPoint(x: hd.x, y: hd.y - 6)
                    b.phase += dt * 2.2
                } else {
                    b.perch = nil
                    b.v = CGVector(dx: CGFloat.random(in: -60...60), dy: -140)
                    b.nextThink = time + 1.5
                }
            } else {
                b.phase += dt * 21
                if !b.leaving && time > b.nextThink {
                    b.nextThink = time + Double.random(in: 2...4)
                    let free = blooms.filter { pi in !butterflies.contains { $0.perch == pi } }
                    if let pi = free.randomElement(), Int.random(in: 0..<10) < 6, let hd = head(plot: pi) {
                        b.target = hd
                        b.perch = nil
                        b.perchUntil = -Double(pi) - 1
                    } else {
                        b.target = CGPoint(x: CGFloat.random(in: 90...910), y: CGFloat.random(in: 120...400))
                        b.perchUntil = 0
                    }
                }
                if b.perchUntil < 0 {
                    let pi = Int(-b.perchUntil - 1)
                    if pi < plots.count, bloomed(pi), let hd = head(plot: pi) {
                        b.target = hd
                        if hypot(hd.x - b.p.x, hd.y - b.p.y) < 16 {
                            b.perch = pi
                            b.perchUntil = time + Double.random(in: 3...6)
                        }
                    } else {
                        b.perchUntil = 0
                    }
                }
                let dx = b.target.x - b.p.x
                let dy = b.target.y - b.p.y
                let d = max(1, hypot(dx, dy))
                let speed: CGFloat = b.leaving ? 200 : min(140, d * 1.5 + 30)
                let ax = (dx / d * speed - b.v.dx) * 1.8
                let ay = (dy / d * speed - b.v.dy) * 1.8 + sin(t * 6 + CGFloat(i) * 2) * 160
                b.v.dx += (ax + windNow * 90) * dt
                b.v.dy += ay * dt
                b.p.x += b.v.dx * dt
                b.p.y += b.v.dy * dt
            }
            butterflies[i] = b
        }
        butterflies.removeAll { $0.leaving && ($0.p.x < -100 || $0.p.x > 1124) }

        if outside && !blooms.isEmpty && weather != .rain {
            if bee == nil && Int.random(in: 0..<240) == 0 {
                bee = GBee(p: CGPoint(x: 1080, y: 210), v: CGVector(dx: -120, dy: 0), target: CGPoint(x: 680, y: 250))
            }
        } else if var b = bee, !b.leaving {
            b.leaving = true
            b.perch = nil
            b.target = CGPoint(x: 1180, y: 120)
            bee = b
        }
        if var b = bee {
            b.phase += dt * 60
            if let pi = b.perch {
                if let hd = head(plot: pi), bloomed(pi), time < b.perchUntil {
                    b.p = CGPoint(x: hd.x + 4, y: hd.y - 10)
                } else {
                    b.perch = nil
                    b.nextThink = time
                }
            } else {
                if !b.leaving && time > b.nextThink {
                    b.nextThink = time + Double.random(in: 1.5...3)
                    if let pi = blooms.randomElement(), let hd = head(plot: pi), Bool.random() {
                        b.target = hd
                        b.perchUntil = -Double(pi) - 1
                    } else {
                        b.target = CGPoint(x: CGFloat.random(in: 120...860), y: CGFloat.random(in: 180...410))
                        b.perchUntil = 0
                    }
                }
                if b.perchUntil < 0 {
                    let pi = Int(-b.perchUntil - 1)
                    if pi < plots.count, let hd = head(plot: pi), bloomed(pi) {
                        b.target = hd
                        if hypot(hd.x - b.p.x, hd.y - b.p.y) < 14 {
                            b.perch = pi
                            b.perchUntil = time + Double.random(in: 1.2...2.4)
                        }
                    }
                }
                let dx = b.target.x - b.p.x
                let dy = b.target.y - b.p.y
                let d = max(1, hypot(dx, dy))
                let speed: CGFloat = min(260, d * 2.4 + 40)
                b.v.dx += ((dx / d * speed - b.v.dx) * 3 + sin(t * 13) * 140) * dt
                b.v.dy += ((dy / d * speed - b.v.dy) * 3 + cos(t * 11) * 140) * dt
                b.p.x += b.v.dx * dt
                b.p.y += b.v.dy * dt
            }
            bee = (b.leaving && (b.p.x > 1140 || b.p.x < -120)) ? nil : b
        }

        if ladybug.flying {
            ladybug.open = min(1, ladybug.open + dt * 8)
            ladybug.v.dy += 420 * dt
            let toward = (436 - ladybug.p.x) * 0.28
            ladybug.v.dx += (toward - ladybug.v.dx * 0.2) * dt
            ladybug.p.x += ladybug.v.dx * dt
            ladybug.p.y += ladybug.v.dy * dt
            ladybug.p.y = min(ladybug.p.y, 700)
            if ladybug.v.dy > 0 && GGeo.inBed(ladybug.p.x) && ladybug.p.y >= surface(ladybug.p.x) - 4 {
                ladybug.flying = false
                ladybug.x = ladybug.p.x
                ladybug.dir = ladybug.v.dx >= 0 ? 1 : -1
                ladybug.v = .zero
            }
        } else {
            ladybug.open = max(0, ladybug.open - dt * 5)
            if time > ladybug.nextTurn {
                ladybug.nextTurn = time + Double.random(in: 3...8)
                if Bool.random() { ladybug.dir = -ladybug.dir }
            }
            let speed: CGFloat = rain > 0.5 ? 0 : 16
            ladybug.x += ladybug.dir * speed * dt
            if ladybug.x < GGeo.bedLeft + 14 { ladybug.x = GGeo.bedLeft + 14; ladybug.dir = 1 }
            if ladybug.x > GGeo.bedRight - 14 { ladybug.x = GGeo.bedRight - 14; ladybug.dir = -1 }
            ladybug.walk += dt * speed
            ladybug.p = CGPoint(x: ladybug.x, y: surface(ladybug.x) - 4)
        }

        worm.phase += dt * 3
        if worm.peek > 0.01 || time < worm.peekUntil {
            let up: CGFloat = time < worm.peekUntil ? 1 : 0
            worm.peek += (up - worm.peek) * min(1, dt * 3.5)
        } else {
            worm.x += worm.dir * 9 * dt
            worm.depth = 44 + 16 * sin(t * 0.13 + 1)
            if worm.x < GGeo.bedLeft + 38 { worm.dir = 1 }
            if worm.x > GGeo.bedRight - 38 { worm.dir = -1 }
            if time > worm.nextPeek {
                worm.nextPeek = time + Double.random(in: 8...16)
                if wetAt(worm.x, span: 6) > 0.45 || rain > 0.5 {
                    worm.peekUntil = time + Double.random(in: 3...5)
                    if rain < 0.5 { GardenSound.shared.play(.squeak, volume: 0.4) }
                }
            }
        }

        let wantFlies = night > 0.4 ? 12 : 0
        if fireflies.count < wantFlies && Int.random(in: 0..<20) == 0 {
            fireflies.append(GFirefly(p: CGPoint(x: CGFloat.random(in: 60...960), y: CGFloat.random(in: 240...540)),
                                      v: .zero, phase: CGFloat.random(in: 0...6)))
        }
        if fireflies.count > wantFlies && Int.random(in: 0..<30) == 0 { fireflies.removeFirst() }
        for i in fireflies.indices {
            var f = fireflies[i]
            f.phase += dt
            let ax = sin(f.phase * 0.9 + CGFloat(i)) * 40 + (handDown ? (handP.x - f.p.x) * 0.15 : 0)
            let ay = cos(f.phase * 0.7 + CGFloat(i) * 2) * 30 + (handDown ? (handP.y - f.p.y) * 0.15 : 0)
            f.v.dx += (ax - f.v.dx * 0.6) * dt
            f.v.dy += (ay - f.v.dy * 0.6) * dt
            f.p.x += f.v.dx * dt
            f.p.y += f.v.dy * dt
            f.p.y = max(130, min(580, f.p.y))
            f.p.x = max(20, min(1004, f.p.x))
            fireflies[i] = f
        }
    }

    // MARK: Sound loops

    private func stepSound() {
        let s = GardenSound.shared
        s.setLoop(.water, volume: Float(flow) * 0.75)
        s.setLoop(.rain, volume: Float(rain) * 0.55)
        s.setLoop(.wind, volume: Float(max(0, wind - 0.1)) * 0.5)
        s.setLoop(.crickets, volume: Float(night) * 0.35)
        var buzz: Float = 0
        if let b = bee, b.perch == nil { buzz = 0.25 }
        s.setLoop(.buzz, volume: buzz)
    }
}

enum GardenStorage {
    static func load() -> GardenSave? { GameStorage.load(GardenSave.self, game: GardenSim.gameID, file: "garden.json") }
    static func save(_ s: GardenSave) { GameStorage.save(s, game: GardenSim.gameID, file: "garden.json") }
}
