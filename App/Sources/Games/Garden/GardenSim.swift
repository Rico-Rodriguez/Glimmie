import SwiftUI

// MARK: - The garden, simulated
//
// The soil is a height field: one surface height per 4-point column across the bed (`h`), plus how wet each column is
// (`wet`). The shovel carves the columns down to its blade and carries what it took as a load; a flick throws the load
// as clods that fly, bounce and settle back into the field where they land, so no soil is ever made or lost. Loose soil
// slides until no slope is steeper than it can hold (wet soil holds steeper walls).
//
// Water is particles. A drop that reaches the surface soaks into its column; wetness spreads sideways, sinks in
// (drawn as a darker soak line under the surface), dries in the sun, and pools into flat puddles in hollows.
// Plants only grow while their soil is damp, and drink it as they grow. Every plant and weed is a damped spring
// that the wind, rain, water and her finger push on.

enum GardenTool: Equatable {
    case shovel
    case can
    case seeds(PlantKind)
    case decor(DecorKind)
}

enum GPart {
    case water, splash, clod, seed, rain, petal, leaf, sparkle, dust, ripple
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
    /// Soil a clod carries (column points), put back into the field where it settles.
    var mass: CGFloat = 0
    var seed: PlantKind?
    var bounces = 0
    /// Rain outside the bed lands on the lawn at this height.
    var groundY: CGFloat = 0
    var resting = false
}

enum GFlyerKind {
    case crop(PlantKind, Int)
    case weed(Int)
    case uprooted(Plant)
    case decor(DecorKind)
}

/// Something thrown along a ballistic arc: picked crops land in the basket, pulled weeds tumble away.
struct GFlyer {
    var kind: GFlyerKind
    var p0: CGPoint
    var v0: CGVector
    var start: Double
    var dur: Double
    var spin: CGFloat
    var toBasket: Bool

    static let gravity: CGFloat = 1500

    func pos(_ t: Double) -> CGPoint {
        let s = CGFloat(t - start)
        return CGPoint(x: p0.x + v0.dx * s, y: p0.y + v0.dy * s + 0.5 * GFlyer.gravity * s * s)
    }

    /// The launch speed that lands at `to` after `dur` seconds.
    static func aim(from: CGPoint, to: CGPoint, dur: Double) -> CGVector {
        let T = CGFloat(dur)
        return CGVector(dx: (to.x - from.x) / T, dy: (to.y - from.y - 0.5 * gravity * T * T) / T)
    }
}

struct GPlot {
    var plant: Plant?
    var bend: CGFloat = 0
    var bendV: CGFloat = 0
    var pop: CGFloat = 0
    var popV: CGFloat = 0
    /// Seconds the soil has been too dry to grow.
    var dry: CGFloat = 0
    var digWork: CGFloat = 0
    var fillUntil: Double = 0
    /// Carrot being pulled up (0...1).
    var pull: CGFloat = 0
    var pullV: CGFloat = 0
    var held = false
    var sad = false
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

    // Soil
    var h: [CGFloat]
    var wet: [CGFloat]
    // Things in the garden
    var plots: [GPlot]
    var weeds: [GWeed] = []
    var decor: [GDecor] = []
    var particles: [GParticle] = []
    var flyers: [GFlyer] = []
    var butterflies: [GButterfly] = []
    var bee: GBee?
    var ladybug: GLadybug
    var worm: GWorm
    var fireflies: [GFirefly] = []
    var basket: [String] = []
    var basketBounce: CGFloat = 0
    var basketBounceV: CGFloat = 0

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
    private var nextWeed: Double = 16
    private var nextLeaf: Double = 0
    private var rainAcc: CGFloat = 0
    private var waterAcc: CGFloat = 0
    private var nextDecorID = 1

    // The carried tool
    var tool: GardenTool?
    var toolP = CGPoint.zero
    var finger = CGPoint.zero
    var toolV = CGVector.zero
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var load: CGFloat = 0
    var flow: CGFloat = 0
    private var lastToolP = CGPoint.zero
    private var seedTimer: CGFloat = 0
    private var digSound: Double = 0
    /// A tool flying back to its place on the dock.
    var returning: (tool: GardenTool, from: CGPoint, to: CGPoint, start: Double, tilt: CGFloat)?

    // The bare hand
    private enum Grab {
        case weed(Int)
        case carrot(Int)
        case decor(Int)
    }
    private var grab: Grab?
    private var grabStart = CGPoint.zero
    private var handP = CGPoint.zero
    private var handLast = CGPoint.zero
    var handV = CGVector.zero
    var handDown = false

    /// Screenshot mode: never saves over her garden.
    var demo = false

    // MARK: Setup

    init(save: GardenSave? = GardenStorage.load()) {
        let n = GGeo.columns
        var hh = [CGFloat](repeating: GGeo.soilY, count: n)
        for i in 0..<n {
            let a = sin(CGFloat(i) * 0.21) * 1.2
            let b = sin(CGFloat(i) * 0.07 + 1.3) * 1.5
            hh[i] = GGeo.soilY + a + b
        }
        h = hh
        wet = [CGFloat](repeating: 0.06, count: n)
        plots = [GPlot](repeating: GPlot(), count: GGeo.plotX.count)
        ladybug = GLadybug(x: 330, dir: 1, p: CGPoint(x: 330, y: GGeo.soilY))
        worm = GWorm(x: 520, depth: 80, dir: 1)
        if let s = save, s.soil.count == n, s.wet.count == n {
            restore(s)
        } else {
            starterGarden()
        }
        for i in 0..<2 { spawnButterfly(i, fromEdge: false) }
    }

    private func starterGarden() {
        plots[0].plant = Plant(kind: .sunflower, growth: 0.22, left: 0, variant: 0)
        plots[2].plant = Plant(kind: .tomato, growth: 0.5, left: 0, variant: 0)
        plots[4].plant = Plant(kind: .tulip, growth: 1, left: 1, variant: 0)
        carveHole(plot: 1)
        for i in 0..<GGeo.columns {
            let x = GGeo.colX(i)
            if abs(x - GGeo.plotX[4]) < 60 { wet[i] = 0.4 }
        }
        weeds = [GWeed(x: 356, growth: 0.8, seed: 3), GWeed(x: 662, growth: 0.55, seed: 8)]
        addDecor(.pinwheel, x: 214, falling: false)
        addDecor(.birdbath, x: 812, falling: false)
    }

    private func restore(_ s: GardenSave) {
        h = s.soil.map { CGFloat($0) }
        wet = s.wet.map { CGFloat($0) }
        for i in 0..<min(plots.count, s.plots.count) { plots[i].plant = s.plots[i] }
        weeds = s.weeds.map { GWeed(x: CGFloat($0.x), growth: CGFloat($0.growth), seed: $0.seed) }
        for d in s.decor {
            addDecor(d.kind, x: CGFloat(d.x), falling: false)
            decor[decor.count - 1].water = CGFloat(d.water)
        }
        basket = s.basket
        weather = s.weather
        rain = weather == .rain ? 1 : 0
        night = weather == .night ? 1 : 0
        wind = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        cloud = weather == .rain ? 1 : (weather == .wind ? 0.4 : 0.12)
    }

    func makeSave() -> GardenSave {
        GardenSave(plots: plots.map { $0.plant },
                   soil: h.map { Double($0) },
                   wet: wet.map { Double($0) },
                   weeds: weeds.map { WeedSave(x: Double($0.x), growth: Double($0.growth), seed: $0.seed) },
                   decor: decor.map { DecorSave(kind: $0.kind, x: Double($0.x), water: Double($0.water)) },
                   basket: Array(basket.suffix(40)),
                   weather: weather)
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

    func depth(plot: Int) -> CGFloat {
        let c = GGeo.column(GGeo.plotX[plot])
        var deepest: CGFloat = -100
        for i in max(0, c - 3)...min(GGeo.columns - 1, c + 3) { deepest = max(deepest, h[i] - GGeo.soilY) }
        return deepest
    }

    func hasHole(plot: Int) -> Bool { plots[plot].plant == nil && depth(plot: plot) > 14 }

    var totalSoil: CGFloat { h.reduce(0) { $0 + (GGeo.bedBottom - $1) } }

    /// Digs a ready hole at a plot with mounds beside it (used for the starting garden and tests).
    func carveHole(plot: Int) {
        let cx = GGeo.plotX[plot]
        var moved: CGFloat = 0
        for i in 0..<GGeo.columns {
            let d = (GGeo.colX(i) - cx) / 18
            let dh = 26 * exp(-d * d)
            if dh > 0.2 { h[i] += dh; moved += dh }
        }
        for side in [-1.0, 1.0] {
            let mx = cx + CGFloat(side) * 44
            var wsum: CGFloat = 0
            var ws = [CGFloat](repeating: 0, count: GGeo.columns)
            for i in 0..<GGeo.columns {
                let d = (GGeo.colX(i) - mx) / 14
                ws[i] = exp(-d * d)
                wsum += ws[i]
            }
            for i in 0..<GGeo.columns { h[i] -= moved * 0.5 * ws[i] / max(wsum, 0.001) }
        }
    }

    /// Puts soil (column points) back around x.
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
        stepBasket(dt)
        stepSound()
        if time - lastSave > 20 { lastSave = time; save() }
    }

    // MARK: Weather

    func setWeather(_ w: Weather) {
        guard w != weather else { return }
        if weather == .rain && (w == .sun || w == .wind) { rainbowAt = time }
        weather = w
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
        let k = min(1, dt * 0.9)
        rain += (rainT - rain) * k
        night += (nightT - night) * k
        wind += (windT - wind) * k
        cloud += (cloudT - cloud) * k
        let t = CGFloat(time)
        let gust = 0.65 + 0.35 * sin(t * 0.9) + 0.18 * sin(t * 2.3 + 1)
        windNow = wind * gust + 0.03 * sin(t * 0.7)
        cloudDrift += dt * (6 + wind * 70)

        // Rain falls across the whole sky.
        rainAcc += rain * 300 * dt
        while rainAcc >= 1 {
            rainAcc -= 1
            let x = CGFloat.random(in: -140...1164)
            let drop = GParticle(kind: .rain, p: CGPoint(x: x, y: CGFloat.random(in: -60 ... -10)),
                                 v: CGVector(dx: windNow * 260 + 30, dy: CGFloat.random(in: 1000...1250)),
                                 life: 2, size: CGFloat.random(in: 1.2...2.2), color: GRGB(0xDDEBFA),
                                 groundY: CGFloat.random(in: 470...560))
            particles.append(drop)
        }
        // Leaves blow through on windy days.
        if wind > 0.4 && time > nextLeaf {
            nextLeaf = time + Double.random(in: 0.25...0.9) / Double(wind)
            let colors = [GRGB(0x9CCB5A), GRGB(0xE8B44A), GRGB(0xE07B39), GRGB(0x6FB04B)]
            let leaf = GParticle(kind: .leaf, p: CGPoint(x: -120, y: CGFloat.random(in: 120...520)),
                                 v: CGVector(dx: 260, dy: 0), life: 9, size: CGFloat.random(in: 9...14),
                                 color: colors.randomElement() ?? colors[0], rot: CGFloat.random(in: 0...6),
                                 spin: CGFloat.random(in: -4...4))
            particles.append(leaf)
        }
    }

    // MARK: Tools

    func pickUp(_ t: GardenTool, at p: CGPoint) {
        tool = t
        finger = p
        toolP = p
        lastToolP = p
        toolV = .zero
        tilt = 0
        tiltV = 0
        load = 0
        digSound = 0
        returning = nil
        for i in plots.indices { plots[i].digWork = 0 }
        switch t {
        case .shovel: GardenSound.shared.play(.plunk, volume: 0.5)
        case .can: GardenSound.shared.play(.splash, volume: 0.4)
        case .seeds: GardenSound.shared.play(.seeds, volume: 0.6)
        case .decor: GardenSound.shared.play(.plunk, volume: 0.5)
        }
    }

    func carry(to p: CGPoint) { finger = p }

    /// Lets go of the carried tool. `home` is where it flies back to.
    func release(home: CGPoint) {
        guard let t = tool else { return }
        if load > 1 { dropLoad(throwV: CGVector(dx: toolV.dx * 0.3, dy: 0)) }
        if case .decor(let k) = t, toolP.y < 700 {
            let d = addDecor(k, x: toolP.x, falling: true)
            decor[d].y = min(toolP.y + k.size.height * 0.5, decor[d].baseY)
            Sound.shared.play(.whoosh, volume: 0.5)
        } else {
            returning = (t, toolP, home, time, tilt)
        }
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
        let overGarden = toolP.y < 712 && toolP.x > 20 && toolP.x < 1004

        var target: CGFloat = 0
        switch t {
        case .can: target = overGarden ? 0.95 - toolV.dx * 0.0004 : 0
        case .shovel: target = max(-0.5, min(0.5, toolV.dx * 0.0009))
        case .seeds: target = overGarden ? 2.25 + sin(CGFloat(time) * 9) * 0.12 : 0
        case .decor: target = max(-0.4, min(0.4, toolV.dx * 0.0012))
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

    /// Where the watering can's sprinkler head is, and the way the water leaves it.
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
        waterAcc += flow * 190 * dt
        let perp = CGVector(dx: -dir.dy, dy: dir.dx)
        while waterAcc >= 1 {
            waterAcc -= 1
            let speed = CGFloat.random(in: 170...260)
            let spread = CGFloat.random(in: -1...1)
            let j = CGFloat.random(in: -7...7)
            let v = CGVector(dx: dir.dx * speed + perp.dx * spread * 70 + toolV.dx * 0.3,
                             dy: dir.dy * speed + perp.dy * spread * 70 + toolV.dy * 0.3)
            let drop = GParticle(kind: .water, p: CGPoint(x: spout.x + perp.dx * j, y: spout.y + perp.dy * j), v: v,
                                 life: 3, size: CGFloat.random(in: 2.2...3.8), color: GRGB(0xBFE3FF))
            particles.append(drop)
        }
    }

    /// The shovel blade's tip is the touch point. Soil above the tip within the blade's width comes away onto the blade.
    private func dig(_ dt: CGFloat, from prev: CGPoint) {
        let tip = toolP
        let moved = hypot(tip.x - prev.x, tip.y - prev.y)
        if GGeo.inBed(tip.x) {
            let surf = surface(tip.x)
            if tip.y > surf - 2 {
                let c = GGeo.column(tip.x)
                var took: CGFloat = 0
                let floor = GGeo.soilY + GGeo.maxDepth
                let tipY = min(tip.y, floor)
                for i in max(0, c - 6)...min(GGeo.columns - 1, c + 6) {
                    let d = CGFloat(i - c) / 5.5
                    let w = exp(-d * d * 1.4)
                    let want = (tipY - 3 * d * d) - h[i]
                    if want > 0 {
                        let dh = min(want, 7 * w)
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
                    for _ in 0..<Int(min(4, took / 30)) {
                        let dust = GParticle(kind: .dust, p: CGPoint(x: tip.x + CGFloat.random(in: -16...16), y: surf),
                                             v: CGVector(dx: CGFloat.random(in: -40...40), dy: CGFloat.random(in: -60 ... -20)),
                                             life: 0.7, size: CGFloat.random(in: 8...14), color: GRGB(0xB08660))
                        particles.append(dust)
                    }
                }
                // Too much on the blade spills off the sides.
                if load > 1100 {
                    let spill = load - 1100
                    load = 1100
                    deposit(spill * 0.5, at: tip.x - 30)
                    deposit(spill * 0.5, at: tip.x + 30)
                }
                // A weed in the way pops out.
                if let wi = weeds.firstIndex(where: { abs($0.x - tip.x) < 18 }) { popWeed(wi, v: CGVector(dx: toolV.dx * 0.4, dy: -620)) }
                // Digging hard at a plant lifts it out.
                for i in plots.indices where plots[i].plant != nil {
                    if abs(GGeo.plotX[i] - tip.x) < 20 {
                        plots[i].digWork += moved
                        plots[i].bendV += (tip.x - prev.x) * 0.02
                        if plots[i].digWork > 160 { uproot(i) }
                    }
                }
            } else if load > 1 && tip.y < surf - 12 && toolV.dy < -240 {
                // A flick up and out: throw the soil.
                dropLoad(throwV: CGVector(dx: toolV.dx * 0.55, dy: toolV.dy * 0.6))
                GardenSound.shared.play(.toss, volume: 0.7)
            }
        } else if load > 1 && toolV.dy < -240 {
            dropLoad(throwV: CGVector(dx: toolV.dx * 0.55, dy: toolV.dy * 0.6))
            GardenSound.shared.play(.toss, volume: 0.7)
        }
    }

    /// The soil on the blade leaves as clods.
    private func dropLoad(throwV: CGVector) {
        let n = max(3, min(18, Int(load / 50)))
        let each = load / CGFloat(n)
        let browns = [GRGB(0x8A5A36), GRGB(0x7A4E2E), GRGB(0x9C6A42), GRGB(0x6B4428)]
        for k in 0..<n {
            let jx = CGFloat.random(in: -14...14)
            let v = CGVector(dx: throwV.dx + CGFloat.random(in: -120...120), dy: throwV.dy + CGFloat.random(in: -140...40))
            let clod = GParticle(kind: .clod, p: CGPoint(x: toolP.x + jx, y: toolP.y - 18 - CGFloat(k % 3) * 4), v: v,
                                 life: 6, size: CGFloat.random(in: 4...8.5), color: browns[k % browns.count],
                                 rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -9...9), mass: each)
            particles.append(clod)
        }
        load = 0
    }

    private func sow(_ dt: CGFloat, kind: PlantKind) {
        guard tilt > 1.5 else { return }
        seedTimer -= dt
        if seedTimer > 0 { return }
        seedTimer = 0.13
        let a = tilt
        let local = CGPoint(x: 0, y: -46)
        let p = CGPoint(x: toolP.x + local.x * cos(a) - local.y * sin(a), y: toolP.y + local.x * sin(a) + local.y * cos(a))
        let s = GParticle(kind: .seed, p: p, v: CGVector(dx: toolV.dx * 0.2 + CGFloat.random(in: -40...40), dy: CGFloat.random(in: 0...60)),
                          life: 5, size: kind == .pumpkin ? 5 : (kind == .sunflower ? 4.4 : 3.2), color: kind.seedColor,
                          rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -8...8), seed: kind)
        particles.append(s)
        if Int(time * 7.7) % 3 == 0 { GardenSound.shared.play(.seeds, volume: 0.35, gap: 0.25) }
    }

    // MARK: Planting

    func plant(_ kind: PlantKind, plot i: Int) {
        guard plots[i].plant == nil else { return }
        plots[i].plant = Plant(kind: kind, growth: 0.02, left: 0, variant: Int.random(in: 0..<6))
        plots[i].fillUntil = time + 0.9
        plots[i].dry = 0
        plots[i].pop = 0
        plots[i].popV = 5
        GardenSound.shared.play(.pat, volume: 0.8)
        let x = GGeo.plotX[i]
        for _ in 0..<8 {
            let dust = GParticle(kind: .dust, p: CGPoint(x: x + CGFloat.random(in: -30...30), y: surface(x) - 4),
                                 v: CGVector(dx: CGFloat.random(in: -70...70), dy: CGFloat.random(in: -70 ... -20)),
                                 life: 0.9, size: CGFloat.random(in: 10...18), color: GRGB(0xB58C66))
            particles.append(dust)
        }
        sparkle(at: CGPoint(x: x, y: GGeo.soilY - 20), count: 6)
    }

    private func uproot(_ i: Int) {
        guard let p = plots[i].plant else { return }
        plots[i].plant = nil
        plots[i].digWork = 0
        plots[i].pull = 0
        let base = CGPoint(x: GGeo.plotX[i], y: surface(GGeo.plotX[i]))
        let side: CGFloat = base.x < 512 ? -1 : 1
        flyers.append(GFlyer(kind: .uprooted(p), p0: base, v0: CGVector(dx: side * 260, dy: -700), start: time, dur: 1.4,
                             spin: side * 5, toBasket: false))
        GardenSound.shared.play(.pluck)
        burstSoil(at: base, n: 8)
    }

    // MARK: Soil

    private func stepSoil(_ dt: CGFloat) {
        let n = GGeo.columns
        // Loose soil slides until the slope is one it can hold. Wet soil holds steeper walls.
        for _ in 0..<2 {
            for i in 0..<(n - 1) {
                let d = h[i + 1] - h[i]
                let hold = 5 + 3 * min(wet[i], wet[i + 1])
                let ad = abs(d)
                if ad > hold {
                    let t = (ad - hold) * 0.25
                    if d > 0 { h[i] += t; h[i + 1] -= t } else { h[i] -= t; h[i + 1] += t }
                }
            }
        }
        // Freshly planted holes fill back in and get patted flat.
        for i in plots.indices where time < plots[i].fillUntil {
            let c = GGeo.column(GGeo.plotX[i])
            let lo = max(1, c - 16)
            let hi = min(n - 2, c + 16)
            var next = h
            let k = min(0.45, 14 * dt)
            for j in lo...hi { next[j] = h[j] + k * ((h[j - 1] + h[j + 1]) * 0.5 - h[j]) }
            h = next
            if plots[i].fillUntil - time < Double(dt) * 1.5 {
                for j in max(0, c - 7)...min(n - 1, c + 7) where h[j] > GGeo.soilY + 3 { h[j] = GGeo.soilY + 3 }
            }
        }
        for i in 0..<n { h[i] = max(GGeo.soilY - 46, min(GGeo.soilY + GGeo.maxDepth, h[i])) }

        // Water spreads sideways and dries in the sun.
        let sunny = (1 - cloud) * (1 - night)
        let dry = (0.004 + 0.014 * sunny) * (1 - rain)
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
        let c = GGeo.column(x)
        wet[c] = min(1.15, wet[c] + amount)
        if c > 0 { wet[c - 1] = min(1.15, wet[c - 1] + amount * 0.5) }
        if c < GGeo.columns - 1 { wet[c + 1] = min(1.15, wet[c + 1] + amount * 0.5) }
    }

    // MARK: Plants

    static let stages: [Double] = [0.12, 0.3, 0.55, 0.8, 1.0]

    /// The top of a plant (where its flower or head is), after sway.
    func head(plot i: Int) -> CGPoint? {
        guard let p = plots[i].plant else { return nil }
        let base = CGPoint(x: GGeo.plotX[i], y: surface(GGeo.plotX[i]))
        let hgt = GardenPlants.stemHeight(p)
        let b = plots[i].bend
        return CGPoint(x: base.x + sin(b) * hgt, y: base.y - cos(b) * hgt)
    }

    func bloomed(_ i: Int) -> Bool {
        guard let p = plots[i].plant else { return false }
        return p.kind.isFlower && p.growth >= 0.95
    }

    private func stepPlants(_ dt: CGFloat) {
        let t = CGFloat(time)
        for i in plots.indices {
            guard var p = plots[i].plant else {
                plots[i].bend *= 0.9
                continue
            }
            let x = GGeo.plotX[i]
            let moist = wetAt(x, span: 5)
            let weedy = weeds.contains { abs($0.x - x) < 80 && $0.growth > 0.3 }
            plots[i].sad = weedy
            if p.growth < 1 {
                if moist > 0.1 {
                    var rate: Double = 1.0 / 26
                    if weather == .sun { rate *= 1.35 }
                    if weather == .night { rate *= 0.7 }
                    if weedy { rate *= 0.5 }
                    let before = p.growth
                    p.growth = min(1, p.growth + rate * Double(dt))
                    plots[i].dry = 0
                    let c = GGeo.column(x)
                    for j in max(0, c - 6)...min(GGeo.columns - 1, c + 6) { wet[j] = max(0, wet[j] - 0.016 * dt) }
                    for s in GardenSim.stages where before < s && p.growth >= s {
                        plots[i].popV += 7
                        let top = CGPoint(x: x, y: surface(x) - GardenPlants.stemHeight(p) - 10)
                        if s >= 1 {
                            p.left = p.kind.crop
                            sparkle(at: top, count: 12)
                            GardenSound.shared.play(.grow, volume: 0.9)
                            Sound.shared.play(.sparkle, volume: 0.4)
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

            // Sway: a damped spring the wind leans on.
            let hgt = max(30, GardenPlants.stemHeight(p))
            let k = 30 + 2600 / hgt
            let droop: CGFloat = (plots[i].dry > 1.5 ? 0.12 : 0) + (plots[i].sad ? 0.06 : 0)
            let rest = windNow * 0.34 + sin(t * 1.7 + CGFloat(i)) * 0.025 + droop * (i % 2 == 0 ? 1 : -1)
            var f = (rest - plots[i].bend) * k - plots[i].bendV * 3.4
            if rain > 0.2 { f += CGFloat.random(in: -1...1) * rain * 9 }
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
            weeds[i].growth = min(1, weeds[i].growth + dt / 16)
            let rest = windNow * 0.4 + sin(t * 2.1 + CGFloat(weeds[i].seed)) * 0.03
            weeds[i].bendV += ((rest - weeds[i].bend) * 70 - weeds[i].bendV * 4) * dt
            weeds[i].bend += weeds[i].bendV * dt
            if !weeds[i].held {
                weeds[i].pullV += (-170 * weeds[i].pull - 12 * weeds[i].pullV) * dt
                weeds[i].pull += weeds[i].pullV * dt
            }
        }
        if time > nextWeed {
            nextWeed = time + Double.random(in: 24...40)
            guard weeds.count < 4 else { return }
            for _ in 0..<12 {
                let x = CGFloat.random(in: (GGeo.bedLeft + 24)...(GGeo.bedRight - 24))
                let nearPlot = GGeo.plotX.contains { abs($0 - x) < 34 }
                let nearWeed = weeds.contains { abs($0.x - x) < 50 }
                if !nearPlot && !nearWeed {
                    weeds.append(GWeed(x: x, growth: 0.02, seed: Int.random(in: 0..<1000)))
                    GardenSound.shared.play(.grow, volume: 0.25)
                    break
                }
            }
        }
    }

    private func popWeed(_ i: Int, v: CGVector) {
        let w = weeds.remove(at: i)
        let base = CGPoint(x: w.x, y: surface(w.x))
        flyers.append(GFlyer(kind: .weed(w.seed), p0: CGPoint(x: base.x, y: base.y - 10), v0: v, start: time, dur: 1.6,
                             spin: v.dx >= 0 ? 6 : -6, toBasket: false))
        GardenSound.shared.play(.pluck)
        Sound.shared.tap()
        burstSoil(at: base, n: 7)
        // A small hollow where the root came out.
        let c = GGeo.column(w.x)
        for j in max(0, c - 2)...min(GGeo.columns - 1, c + 2) { h[j] += 3 }
        sparkle(at: CGPoint(x: base.x, y: base.y - 30), count: 6)
    }

    private func burstSoil(at p: CGPoint, n: Int) {
        let browns = [GRGB(0x8A5A36), GRGB(0x7A4E2E), GRGB(0x9C6A42)]
        for k in 0..<n {
            let clod = GParticle(kind: .clod, p: CGPoint(x: p.x + CGFloat.random(in: -10...10), y: p.y - 4),
                                 v: CGVector(dx: CGFloat.random(in: -220...220), dy: CGFloat.random(in: -520 ... -220)),
                                 life: 4, size: CGFloat.random(in: 3...6), color: browns[k % 3], rot: CGFloat.random(in: 0...6),
                                 spin: CGFloat.random(in: -9...9), mass: 0)
            particles.append(clod)
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
                let push = windNow * 300 + 20
                q.v.dx += (push - q.v.dx) * dt * 1.2
                q.v.dy += (70 + flutter - q.v.dy) * dt * 1.6
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
                let ground = GGeo.inBed(q.p.x) ? surface(q.p.x) : GGeo.yardY + 20
                if q.p.y > ground {
                    q.p.y = ground
                    q.v = .zero
                    q.spin = 0
                }
                if q.p.x > 1200 { continue }
            case .sparkle:
                q.v.dy += 60 * dt
                q.v.dx *= (1 - dt * 2)
                q.v.dy *= (1 - dt * 2)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
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
        if keep.count > 1800 { keep.removeFirst(keep.count - 1800) }
        particles = keep
    }

    /// A falling drop meets a birdbath, a plant or the ground. Returns true when it is used up.
    private func hitWater(_ q: inout GParticle) -> Bool {
        // Birdbaths catch water.
        for i in decor.indices where decor[i].kind == .birdbath && !decor[i].held {
            let top = decor[i].y - 70
            if abs(q.p.x - decor[i].x) < 44 && q.p.y > top && q.p.y < top + 20 {
                decor[i].water = min(1, decor[i].water + (q.kind == .rain ? 0.004 : 0.01))
                if Int.random(in: 0..<5) == 0 { ripple(at: CGPoint(x: q.p.x, y: top + 4), small: true) }
                return true
            }
        }
        // Drops tap the leaves they fall through.
        if q.kind == .water {
            for i in plots.indices {
                guard let p = plots[i].plant else { continue }
                let x = GGeo.plotX[i]
                let top = surface(x) - GardenPlants.stemHeight(p)
                if abs(q.p.x - x) < p.kind.reach * 0.6 && q.p.y > top && q.p.y < top + 40 {
                    plots[i].bendV += q.v.dx * 0.0006 + CGFloat.random(in: -0.02...0.02)
                }
            }
        }
        if GGeo.inBed(q.p.x) {
            let s = surface(q.p.x)
            if q.p.y >= s {
                water(at: q.p.x, amount: q.kind == .rain ? 0.03 : 0.011)
                let c = GGeo.column(q.p.x)
                let puddle = wet[c] > 0.85
                if puddle && Int.random(in: 0..<(q.kind == .rain ? 6 : 3)) == 0 {
                    ripple(at: CGPoint(x: q.p.x, y: s - 1), small: q.kind == .rain)
                }
                splash(at: CGPoint(x: q.p.x, y: s - 1), v: q.v, n: q.kind == .rain ? (Int.random(in: 0..<3) == 0 ? 1 : 0) : (Int.random(in: 0..<2)))
                // A water drop may nudge the worm out.
                return true
            }
        } else {
            let ground = q.kind == .rain ? q.groundY : GGeo.lawnY + 10
            if q.p.y >= ground {
                splash(at: CGPoint(x: q.p.x, y: ground), v: q.v, n: Int.random(in: 0..<3) == 0 ? 1 : 0)
                return true
            }
            // Water landing on the bed's wooden rims runs off.
            if q.p.y > 1000 { return true }
        }
        return false
    }

    private func splash(at p: CGPoint, v: CGVector, n: Int) {
        guard n > 0 else { return }
        for _ in 0..<n {
            let s = GParticle(kind: .splash, p: p,
                              v: CGVector(dx: v.dx * 0.15 + CGFloat.random(in: -90...90), dy: -CGFloat.random(in: 110...260)),
                              life: 0.35, size: CGFloat.random(in: 1.2...2.2), color: GRGB(0xD6EEFF))
            particles.append(s)
        }
    }

    private func ripple(at p: CGPoint, small: Bool) {
        particles.append(GParticle(kind: .ripple, p: p, v: .zero, life: small ? 0.45 : 0.7, size: small ? 2 : 3,
                                   color: GRGB(0xFFFFFF)))
    }

    /// A clod or seed reaches the ground. Returns true when it is used up.
    private func landSolid(_ q: inout GParticle) -> Bool {
        let ground: CGFloat = GGeo.inBed(q.p.x) ? surface(q.p.x) - q.size * 0.4 : GGeo.lawnY + 4
        guard q.p.y >= ground else { return false }
        q.p.y = ground
        let speed = hypot(q.v.dx, q.v.dy)
        if q.kind == .seed, let k = q.seed, GGeo.inBed(q.p.x) {
            if let i = GGeo.plotX.firstIndex(where: { abs($0 - q.p.x) < 26 }), hasHole(plot: i) {
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
                // A hard landing breaks off a crumb.
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
                particles.append(GParticle(kind: .dust, p: q.p, v: CGVector(dx: 0, dy: -12), life: 0.5, size: q.size * 1.6,
                                           color: GRGB(0xA27A55)))
            }
            if GGeo.inBed(q.p.x) { return true }
            q.resting = true
            q.life = q.age + 1.2
            return false
        }
        q.resting = true
        q.v = .zero
        q.life = q.age + 1.4
        return false
    }

    func sparkle(at p: CGPoint, count: Int) {
        let colors = [GRGB(0xFFFFFF), GRGB(0xFFE38A), GRGB(0xFFB3CF)]
        for k in 0..<count {
            let a = CGFloat(k) / CGFloat(max(1, count)) * 2 * .pi + CGFloat.random(in: -0.3...0.3)
            let sp = CGFloat.random(in: 90...190)
            particles.append(GParticle(kind: .sparkle, p: p, v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 40), life: 0.8,
                                       size: CGFloat.random(in: 7...13), color: colors[k % 3], rot: 0,
                                       spin: CGFloat.random(in: -3...3)))
        }
    }

    // MARK: Flyers and the basket

    private func stepFlyers() {
        var keep: [GFlyer] = []
        for f in flyers {
            if time - f.start < f.dur {
                keep.append(f)
                continue
            }
            if f.toBasket, case .crop(let k, let v) = f.kind {
                basket.append("\(k.rawValue):\(v)")
                if basket.count > 60 { basket.removeFirst(basket.count - 60) }
                basketBounceV += 9
                GardenSound.shared.play(.basket, volume: 0.9)
                Sound.shared.play(.ding, volume: 0.35)
                sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 30), count: 6)
            }
        }
        flyers = keep
    }

    private func stepBasket(_ dt: CGFloat) {
        basketBounceV += (-160 * basketBounce - 10 * basketBounceV) * dt
        basketBounce += basketBounceV * dt
    }

    private func harvest(_ i: Int) {
        guard var p = plots[i].plant, p.growth >= 1, p.left > 0 else { return }
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
        case .pumpkin: from = CGPoint(x: base.x + 26, y: base.y - 28)
        case .carrot: from = CGPoint(x: base.x, y: base.y + 10)
        default: break
        }
        p.left -= 1
        let dur = 0.75 + Double(abs(GGeo.basket.x - from.x)) / 2400
        flyers.append(GFlyer(kind: .crop(p.kind, p.variant), p0: from,
                             v0: GFlyer.aim(from: from, to: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 20), dur: dur),
                             start: time, dur: dur, spin: CGFloat.random(in: -7...7), toBasket: true))
        GardenSound.shared.play(.pluck, volume: 0.8)
        Sound.shared.tap()
        plots[i].bendV += CGFloat.random(in: -1.5...1.5)
        plots[i].popV += 4
        if p.kind.isFlower {
            petals(at: from, color: p.kind.bloom(p.variant), n: 5)
        }
        if p.left <= 0 {
            switch p.kind {
            case .carrot:
                plots[i].plant = nil
                plots[i].pull = 0
                burstSoil(at: base, n: 9)
                let c = GGeo.column(x)
                for j in max(0, c - 4)...min(GGeo.columns - 1, c + 4) { h[j] += 5 }
                return
            case .pumpkin: p.growth = 0.62
            default: p.growth = 0.8
            }
            p.left = 0
        }
        plots[i].plant = p
    }

    private func petals(at p: CGPoint, color: GRGB, n: Int) {
        for _ in 0..<n {
            particles.append(GParticle(kind: .petal, p: p, v: CGVector(dx: CGFloat.random(in: -80...80), dy: CGFloat.random(in: -120 ... -30)),
                                       life: 3.5, size: CGFloat.random(in: 6...9), color: color, rot: CGFloat.random(in: 0...6),
                                       spin: CGFloat.random(in: -5...5)))
        }
    }

    // MARK: The bare hand

    func handBegan(_ p: CGPoint) {
        handDown = true
        handP = p
        handLast = p
        handV = .zero
        grabStart = p
        grab = nil
        // Decorations first (they stand in front of the fence).
        if let d = decorHit(p) {
            grab = .decor(d)
            decor[d].held = true
            decor[d].poke = time
            GardenSound.shared.play(.plunk, volume: 0.4)
            return
        }
        if let w = weeds.indices.min(by: { abs(weeds[$0].x - p.x) < abs(weeds[$1].x - p.x) }) {
            let base = surface(weeds[w].x)
            let tall = 30 + 50 * weeds[w].growth
            if abs(weeds[w].x - p.x) < 34 && p.y > base - tall - 16 && p.y < base + 26 {
                grab = .weed(w)
                weeds[w].held = true
                GardenSound.shared.play(.pluck, volume: 0.25, gap: 0.2)
                return
            }
        }
        for i in plots.indices {
            guard let pl = plots[i].plant, pl.kind == .carrot, pl.growth >= 1 else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            if abs(x - p.x) < 44 && p.y > base - 110 && p.y < base + 40 {
                grab = .carrot(i)
                plots[i].held = true
                return
            }
        }
    }

    func handMoved(_ p: CGPoint, dt: CGFloat = 1.0 / 60) {
        let vx = (p.x - handLast.x) / max(dt, 0.001)
        let vy = (p.y - handLast.y) / max(dt, 0.001)
        handV = CGVector(dx: vx, dy: vy)
        handLast = handP
        handP = p
        switch grab {
        case .weed(let w)?:
            guard w < weeds.count else { grab = nil; return }
            let up = max(0, grabStart.y - p.y)
            weeds[w].pull = up / 120
            weeds[w].bend = max(-0.6, min(0.6, (p.x - grabStart.x) / 160))
            if weeds[w].pull >= 1 {
                grab = nil
                popWeed(w, v: CGVector(dx: (p.x - grabStart.x) * 2 + CGFloat.random(in: -80...80), dy: -760))
            } else if Int(up) % 24 == 0 && up > 4 {
                GardenSound.shared.play(.pluck, volume: 0.15, gap: 0.15)
            }
        case .carrot(let i)?:
            let up = max(0, grabStart.y - p.y)
            plots[i].pull = up / 110
            plots[i].bend = max(-0.5, min(0.5, (p.x - grabStart.x) / 180))
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
        case nil:
            brush(from: handLast, to: p)
        }
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        handDown = false
        switch grab {
        case .weed(let w)?:
            if w < weeds.count { weeds[w].held = false }
        case .carrot(let i)?:
            plots[i].held = false
        case .decor(let d)?:
            if d < decor.count {
                decor[d].held = false
                if tap {
                    decor[d].y = decor[d].baseY
                    pokeDecor(d)
                } else if p.y > 724 {
                    removeDecor(d)
                } else {
                    decor[d].baseY = max(500, min(532, p.y + decor[d].kind.size.height * 0.45))
                    decor[d].y = min(decor[d].y, decor[d].baseY)
                }
            }
        case nil:
            if tap { tapAt(p) }
        }
        grab = nil
    }

    /// A finger brushing through the garden pushes plants, startles bugs.
    private func brush(from a: CGPoint, to b: CGPoint) {
        let dx = b.x - a.x
        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            let top = base - GardenPlants.stemHeight(pl) - 30
            if abs(b.x - x) < pl.kind.reach + 10 && b.y > top && b.y < base + 4 {
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
        // The basket
        if hypot(p.x - GGeo.basket.x, p.y - (GGeo.basket.y - 10)) < 70 {
            basketBounceV += 12
            GardenSound.shared.play(.basket, volume: 0.7)
            sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 40), count: 8)
            return
        }
        // Bugs
        for i in butterflies.indices where hypot(butterflies[i].p.x - p.x, butterflies[i].p.y - p.y) < 56 {
            flee(i, from: CGPoint(x: p.x, y: p.y + 20))
            sparkle(at: butterflies[i].p, count: 5)
            return
        }
        if let b = bee, hypot(b.p.x - p.x, b.p.y - p.y) < 50 {
            scareBugs(near: p, radius: 60)
            return
        }
        if hypot(ladybug.p.x - p.x, ladybug.p.y - p.y) < 40 {
            ladybugTakeOff()
            return
        }
        let wormHead = CGPoint(x: worm.x, y: surface(worm.x) + worm.depth * (1 - worm.peek) - 14 * worm.peek)
        if hypot(wormHead.x - p.x, wormHead.y - p.y) < 50 {
            worm.wiggle = time
            GardenSound.shared.play(.squeak, volume: 0.8)
            return
        }
        // Ripe things get picked.
        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            let top = base - GardenPlants.stemHeight(pl) - 40
            guard abs(p.x - x) < pl.kind.reach + 14 && p.y > top && p.y < base + 50 else { continue }
            if pl.growth >= 1 && pl.left > 0 {
                harvest(i)
            } else {
                plots[i].popV += 5
                plots[i].bendV += (p.x < x ? 1.2 : -1.2)
                GardenSound.shared.play(.rustle, volume: 0.6)
                if plots[i].dry > 1.5 {
                    // Thirsty: the drop above it bounces.
                    Sound.shared.play(.boing, volume: 0.3)
                }
            }
            return
        }
        // A pat on the soil.
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

    // MARK: Decorations

    @discardableResult
    func addDecor(_ k: DecorKind, x: CGFloat, falling: Bool) -> Int {
        if decor.count >= 14 { removeDecor(0) }
        var d = GDecor(id: nextDecorID, kind: k, x: max(GGeo.yardMinX, min(GGeo.yardMaxX, x)), y: GGeo.yardY)
        nextDecorID += 1
        d.baseY = GGeo.yardY + CGFloat(nextDecorID % 3) * 6
        d.y = falling ? d.baseY - 120 : d.baseY
        decor.append(d)
        return decor.count - 1
    }

    func removeDecor(_ i: Int) {
        guard i < decor.count else { return }
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
            decor[i].vy = -420
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
        let p = fromEdge ? CGPoint(x: left ? -50 : 1074, y: CGFloat.random(in: 150...360))
                         : CGPoint(x: CGFloat.random(in: 200...820), y: CGFloat.random(in: 160...360))
        butterflies.append(GButterfly(p: p, v: CGVector(dx: left ? 80 : -80, dy: 0),
                                      target: CGPoint(x: CGFloat.random(in: 200...820), y: CGFloat.random(in: 160...360)),
                                      phase: CGFloat.random(in: 0...6), look: Int.random(in: 0..<5)))
    }

    private func ladybugTakeOff() {
        ladybug.flying = true
        ladybug.v = CGVector(dx: CGFloat.random(in: -1...1) * 180, dy: -330)
        GardenSound.shared.play(.flutter, volume: 0.5)
    }

    private func stepCritters(_ dt: CGFloat) {
        let t = CGFloat(time)
        let outside = rain < 0.35 && night < 0.5
        let blooms = plots.indices.filter { bloomed($0) }

        // Butterflies
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
                        b.perchUntil = -Double(pi) - 1  // remembers which flower it is heading for
                    } else {
                        b.target = CGPoint(x: CGFloat.random(in: 90...934), y: CGFloat.random(in: 130...430))
                        b.perchUntil = 0
                    }
                }
                // Heading for a flower: follow it as it sways.
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

        // A bee visits the flowers on fair days.
        if outside && !blooms.isEmpty && weather != .rain {
            if bee == nil && Int.random(in: 0..<240) == 0 {
                bee = GBee(p: CGPoint(x: 1080, y: 220), v: CGVector(dx: -120, dy: 0), target: CGPoint(x: 700, y: 260))
            }
        } else if var b = bee, !b.leaving {
            b.leaving = true
            b.perch = nil
            b.target = CGPoint(x: 1200, y: 120)
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
                        b.target = CGPoint(x: CGFloat.random(in: 120...900), y: CGFloat.random(in: 200...440))
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
            bee = (b.leaving && (b.p.x > 1150 || b.p.x < -120)) ? nil : b
        }

        // The ladybug walks along the soil, and flies when startled.
        if ladybug.flying {
            ladybug.open = min(1, ladybug.open + dt * 8)
            ladybug.v.dy += 420 * dt
            let toward = (512 - ladybug.p.x) * 0.25
            ladybug.v.dx += (toward - ladybug.v.dx * 0.2) * dt
            ladybug.p.x += ladybug.v.dx * dt
            ladybug.p.y += ladybug.v.dy * dt
            ladybug.p.y = min(ladybug.p.y, 900)
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

        // The worm tunnels under the glass, and peeks out when the soil is wet.
        worm.phase += dt * 3
        if worm.peek > 0.01 || time < worm.peekUntil {
            let up: CGFloat = time < worm.peekUntil ? 1 : 0
            worm.peek += (up - worm.peek) * min(1, dt * 3)
        } else {
            worm.x += worm.dir * 9 * dt
            worm.depth = 70 + 30 * sin(t * 0.13 + 1)
            if worm.x < GGeo.bedLeft + 40 { worm.dir = 1 }
            if worm.x > GGeo.bedRight - 40 { worm.dir = -1 }
            if time > worm.nextPeek {
                worm.nextPeek = time + Double.random(in: 8...16)
                if wetAt(worm.x, span: 6) > 0.45 || rain > 0.5 {
                    worm.peekUntil = time + Double.random(in: 3...5)
                    if rain < 0.5 { GardenSound.shared.play(.squeak, volume: 0.4) }
                }
            }
        }

        // Fireflies at night.
        let wantFlies = night > 0.4 ? 12 : 0
        if fireflies.count < wantFlies && Int.random(in: 0..<20) == 0 {
            fireflies.append(GFirefly(p: CGPoint(x: CGFloat.random(in: 60...960), y: CGFloat.random(in: 380...560)),
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
            f.p.y = max(160, min(600, f.p.y))
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

/// garden.json in Application Support/Games/garden/.
enum GardenStorage {
    static func load() -> GardenSave? { GameStorage.load(GardenSave.self, game: GardenSim.gameID, file: "garden.json") }
    static func save(_ s: GardenSave) { GameStorage.save(s, game: GardenSim.gameID, file: "garden.json") }
}
