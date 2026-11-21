import SwiftUI

// MARK: - Potion Lab simulation
//
// The potion is a small 2D fluid (`PotionSim.fluidStep`, 48 x 60 cells of 8 pt inside the flask): velocity, a
// pigment field (premultiplied color plus amount, so colors mix like dye and water thins them) and a density field
// (heavy liquids sink and make layers, light ones float). Pouring pushes the liquid down where the stream lands,
// the stirring paddle drags it along, bubbles push it up, and the swirls are kept lively with a little vorticity
// confinement. The surface is a row of springs (waves) over a level set by the volume and the flask's shape.
// Around it: stream drops, things shaken in that float, sink, fizz and dissolve, bubbles, glitter that swirls like
// a snow globe and settles, foam, steam, cold fog, and the unicorn that gets potions poured on her.

struct PDrop {
    var p: CGPoint
    var v: CGVector
    var color: RGB
    /// Pigment per unit of liquid.
    var conc: Float
    var density: Float
    var vol: CGFloat
    var r: CGFloat
    /// Which pour it belongs to (drops of one pour are drawn as one stream), or -1 for a lone drop.
    var stream: Int
    /// The ingredient it is, or nil for a bottled potion (then `potion` holds its magic).
    var ing: PIngredient?
    var potion: Int?
    /// A splash from the potion itself: falls back in without changing it.
    var splash = false
    var onGlass = false
}

struct PBubble {
    var p: CGPoint
    var r: CGFloat
    var phase: CGFloat
    /// Fizzy bubbles make foam when they pop.
    var fizzy: Bool
}

struct PGlitter {
    var p: CGPoint
    var color: RGB
    var size: CGFloat
    var phase: CGFloat
}

enum PPieceState { case air, liquid, table }

struct PPiece {
    var kind: PIngredient
    var p: CGPoint
    var v: CGVector
    var ang: CGFloat
    var spin: CGFloat
    var state: PPieceState = .air
    var dissolve: CGFloat = 0
    var age: CGFloat = 0
    var seed: Int
    var trail: [CGPoint] = []
    var burstAt: CGFloat = 2.5
}

enum PMoteKind { case steam, fog, sparkle, smoke, heart, snow, soap, zz, flash, drip }

struct PMote {
    var p: CGPoint
    var v: CGVector
    var life: CGFloat = 0
    var max: CGFloat
    var kind: PMoteKind
    var color: RGB
    var size: CGFloat
    var spin: CGFloat = 0
}

struct PPuddle {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var color: RGB
    var a: CGFloat
}

/// A bottle flying somewhere by itself: a corked potion to its rack spot, an empty one back to the crate.
struct PFlyer {
    var from: CGPoint
    var to: CGPoint
    var t: CGFloat = 0
    var bottle: PotionBottle?
    var rackIndex: Int?
    var spin: CGFloat
    /// An ingredient going back to its shelf.
    var ing: PIngredient? = nil
}

enum PHeld: Equatable {
    case ingredient(PIngredient)
    case rack(Int)
    case empty
    case spoon
}

struct PUnicorn {
    var tint = RGB(1, 1, 1)
    var tintAmt: CGFloat = 0
    var rainbow: CGFloat = 0
    var glitter: CGFloat = 0
    var float: CGFloat = 0
    var floatY: CGFloat = 0
    var floatV: CGFloat = 0
    var hiccup: CGFloat = 0
    var hicAt: CGFloat = 0
    var hicKick: CGFloat = 0
    var sleepy: CGFloat = 0
    var glow: CGFloat = 0
    var frost: CGFloat = 0
    var love: CGFloat = 0
    var wet: CGFloat = 0
    var shake: CGFloat = 0
    var hop: CGFloat = 0
    var hopV: CGFloat = 0
    var giggle: CGFloat = 0
    var look = CGPoint(x: 512, y: 420)
    var blink: CGFloat = 3
    /// What the current pour on her is made of, before it starts working.
    var got: [PMagic: CGFloat] = [:]
    var gotKind: PotionKind?
    var gotVol: CGFloat = 0
    var gotColor = RGB(1, 1, 1)
    var lastHit: CGFloat = -10
}

final class PotionSim {
    static let gameID = "potionlab"
    static let NX = PotionGeometry.NX, NY = PotionGeometry.NY

    var demo = false
    /// Screenshot helpers: keep the held bottle full, stir by itself.
    var demoKeepFull = false
    var demoStir = false
    var time: Double = 0
    private var lastDate: Date?
    private var rng = SeededRandom(Int.random(in: 0..<1_000_000))

    // MARK: Fluid
    let solid: [Bool]
    var liquid: [Bool]
    var u: [Float], v: [Float]
    var dr: [Float], dg: [Float], db: [Float], da: [Float]
    var rho: [Float]
    private var t0: [Float], t1: [Float], t2: [Float], t3: [Float], t4: [Float], t5: [Float]
    private var pr: [Float], dv: [Float], curl: [Float]
    /// Bumped whenever the pigment changes, for the painter's picture of it.
    var version = 0

    var volume: CGFloat
    var level: CGFloat
    var waveH = [CGFloat](repeating: 0, count: PotionGeometry.NX)
    var waveV = [CGFloat](repeating: 0, count: PotionGeometry.NX)
    var foam = [CGFloat](repeating: 0, count: PotionGeometry.NX)
    /// How fast the potion swirls around (it dips in the middle like a whirlpool).
    var swirl: CGFloat = 0

    // MARK: Heat, light, what's in it
    var heat = 0
    var temp: CGFloat = 0.25
    var lightsOn = true
    var night: CGFloat = 0
    var doses: [PIngredient: CGFloat] = [:]
    var boilTime: CGFloat = 0
    var boiling: CGFloat { max(0, min(1, (temp - 0.62) / 0.3)) }
    var draining = false
    var bucketFill: CGFloat = 0
    var bucketColor = RGB(0.86, 0.95, 1)

    // MARK: Things
    var drops: [PDrop] = []
    var bubbles: [PBubble] = []
    var glitter: [PGlitter] = []
    var pieces: [PPiece] = []
    var motes: [PMote] = []
    var puddles: [PPuddle] = []
    var flyers: [PFlyer] = []
    private var streamID = 1
    private var heldStream = 0

    // MARK: What she holds
    var held: PHeld?
    var hand = CGPoint.zero
    var heldPos = CGPoint.zero
    var heldVel = CGVector.zero
    var heldTilt: CGFloat = 0
    var heldFill: CGFloat = 1
    var shakeEnergy: CGFloat = 0
    var lastShakeAt: CGFloat = 0
    /// The empty bottle being dipped: how full it is and the color it took in.
    var dipFill: CGFloat = 0
    var dipColor = RGB(1, 1, 1)
    var dipMagic: [PIngredient: CGFloat] = [:]
    var dipInside = false
    var shelfFill: [PIngredient: CGFloat] = [:]

    // The stirring paddle: its blade, where it rests in the flask, and whether she holds it.
    static let spoonRest = CGPoint(x: 462, y: 560)
    var spoon = PotionSim.spoonRest
    var spoonVel = CGVector.zero
    var spoonHeld = false
    var spoonTarget = PotionSim.spoonRest
    var stirSpeed: CGFloat = 0

    var rack: [PotionBottle] = []
    var nextID = 1
    var made = 0
    var uni = PUnicorn()

    /// The rare potion the flask holds right now (it twinkles and turns its color), and how far it has turned.
    var rare: PotionKind?
    var turn: CGFloat = 0
    var flash: CGFloat = 0
    private var rareCheckAt: Double = 0

    /// Sound cues for this frame, played by the view.
    var cues: [PotionSFX] = []
    private var cueAt: [PotionSFX: Double] = [:]

    static let rackMax = 11
    static func rackSpot(_ i: Int) -> CGPoint { CGPoint(x: 92 + CGFloat(i) * 84, y: PotionGeometry.rackY) }
    static let rackScale: CGFloat = 0.62
    static let heldScale: CGFloat = 0.9
    /// An ingredient bottle holds this much liquid.
    static let bottleVol: CGFloat = 9000

    init(save: PotionSave? = GameStorage.load(PotionSave.self, game: PotionSim.gameID, file: "potionlab.json")) {
        let n = PotionSim.NX * PotionSim.NY
        var s = [Bool](repeating: true, count: n)
        for j in 0..<PotionSim.NY {
            for i in 0..<PotionSim.NX where PotionGeometry.inside(PotionGeometry.cellCenter(i, j), pad: 1) { s[j * PotionSim.NX + i] = false }
        }
        solid = s
        liquid = [Bool](repeating: false, count: n)
        let z = [Float](repeating: 0, count: n)
        u = z; v = z; dr = z; dg = z; db = z; da = z; rho = z
        t0 = z; t1 = z; t2 = z; t3 = z; t4 = z; t5 = z; pr = z; dv = z; curl = z
        volume = PotionGeometry.capacity * 0.48
        level = PotionGeometry.level(for: volume)
        for i in PIngredient.allCases { shelfFill[i] = 1 }
        if let sv = save {
            rack = Array(sv.bottles.prefix(PotionSim.rackMax))
            nextID = sv.nextID
            volume = max(0, min(PotionGeometry.capacity * 0.96, CGFloat(sv.volume)))
            lightsOn = sv.lightsOn
            night = lightsOn ? 0 : 1
            heat = max(0, min(3, sv.heat))
            made = sv.made
            for (k, d) in sv.doses {
                if let ing = PIngredient.allCases.first(where: { $0.key == k }) { doses[ing] = CGFloat(d) }
            }
            for k in 0..<n where !solid[k] {
                dr[k] = Float(sv.pr); dg[k] = Float(sv.pg); db[k] = Float(sv.pb); da[k] = Float(sv.pa)
            }
            level = PotionGeometry.level(for: volume)
        }
        updateLiquid()
    }

    func save() {
        guard !demo else { return }
        var sum: [Double] = [0, 0, 0, 0]
        var cnt = 0
        for k in liquid.indices where liquid[k] {
            sum[0] += Double(dr[k]); sum[1] += Double(dg[k]); sum[2] += Double(db[k]); sum[3] += Double(da[k])
            cnt += 1
        }
        let c = Double(max(1, cnt))
        var d: [String: Double] = [:]
        for (k, x) in doses where x > 0.01 { d[k.key] = Double(x) }
        let s = PotionSave(bottles: rack, nextID: nextID, volume: Double(volume), pr: sum[0] / c, pg: sum[1] / c,
                           pb: sum[2] / c, pa: sum[3] / c, doses: d, lightsOn: lightsOn, heat: heat, made: made)
        GameStorage.save(s, game: PotionSim.gameID, file: "potionlab.json")
    }

    // MARK: Helpers

    @inline(__always) static func idx(_ i: Int, _ j: Int) -> Int { j * NX + i }

    func rand() -> CGFloat { CGFloat(rng.unit()) }
    func rand(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * rand() }

    func cue(_ s: PotionSFX, gap: Double = 0.06) {
        if let t = cueAt[s], time - t < gap { return }
        cueAt[s] = time
        cues.append(s)
    }

    /// The surface's height at x (with its waves and the whirlpool dip).
    func surfaceY(_ x: CGFloat) -> CGFloat {
        let f = (x - PotionGeometry.gx0) / PotionGeometry.cell - 0.5
        let i = max(0, min(PotionSim.NX - 1, Int(f.rounded(.down))))
        let i1 = min(PotionSim.NX - 1, i + 1)
        let k = max(0, min(1, f - CGFloat(i)))
        let h = waveH[i] * (1 - k) + waveH[i1] * k
        let hwid = max(20, PotionGeometry.halfWidth(at: level))
        let dx = (x - PotionGeometry.C.x) / hwid
        let dip = swirl * max(0, 1 - dx * dx) - swirl * 0.33
        return level + h + dip - foamLift(i)
    }

    private func foamLift(_ i: Int) -> CGFloat { 0 }

    func inLiquid(_ p: CGPoint) -> Bool { PotionGeometry.inside(p) && p.y > surfaceY(p.x) }

    /// The grid position of a point (cell units, cell centers at whole numbers).
    @inline(__always) func gridPos(_ p: CGPoint) -> (Float, Float) {
        (Float((p.x - PotionGeometry.gx0) / PotionGeometry.cell - 0.5), Float((p.y - PotionGeometry.gy0) / PotionGeometry.cell - 0.5))
    }

    func cellIndex(_ p: CGPoint) -> Int? {
        let i = Int((p.x - PotionGeometry.gx0) / PotionGeometry.cell), j = Int((p.y - PotionGeometry.gy0) / PotionGeometry.cell)
        guard i >= 0, j >= 0, i < PotionSim.NX, j < PotionSim.NY else { return nil }
        return PotionSim.idx(i, j)
    }

    @inline(__always) func sample(_ f: [Float], _ x: Float, _ y: Float) -> Float {
        let NX = PotionSim.NX, NY = PotionSim.NY
        let fx = max(0, min(Float(NX - 1) - 0.001, x)), fy = max(0, min(Float(NY - 1) - 0.001, y))
        let i0 = Int(fx), j0 = Int(fy)
        let tx = fx - Float(i0), ty = fy - Float(j0)
        let a = f[j0 * NX + i0], b = f[j0 * NX + i0 + 1]
        let c = f[(j0 + 1) * NX + i0], d = f[(j0 + 1) * NX + i0 + 1]
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    }

    /// The liquid's flow at p, in points per second.
    func flow(_ p: CGPoint) -> CGVector {
        let (x, y) = gridPos(p)
        return CGVector(dx: CGFloat(sample(u, x, y)), dy: CGFloat(sample(v, x, y)))
    }

    /// The potion's color and how strong it is at p.
    func colorAt(_ p: CGPoint) -> (RGB, CGFloat) {
        let (x, y) = gridPos(p)
        let a = sample(da, x, y)
        guard a > 0.002 else { return (PIngredient.water.color, 0) }
        let c = RGB(Double(sample(dr, x, y) / a), Double(sample(dg, x, y) / a), Double(sample(db, x, y) / a))
        return (c, CGFloat(a))
    }

    /// The whole potion's mixed color and strength.
    func meanColor() -> (RGB, CGFloat) {
        var r: Float = 0, g: Float = 0, b: Float = 0, a: Float = 0
        var n = 0
        for k in liquid.indices where liquid[k] {
            r += dr[k]; g += dg[k]; b += db[k]; a += da[k]; n += 1
        }
        guard n > 0, a > 0.001 else { return (PIngredient.water.color, 0) }
        return (RGB(Double(r / a), Double(g / a), Double(b / a)), CGFloat(a / Float(n)))
    }

    /// Adds pigment around p (a soft spot about two cells wide).
    func inject(_ p: CGPoint, color: RGB, amount: Float, density: Float = 0, radius: CGFloat = 1.2) {
        let (gx, gy) = gridPos(p)
        let rr = Float(radius)
        let i0 = max(0, Int(gx - rr - 1)), i1 = min(PotionSim.NX - 1, Int(gx + rr + 1))
        let j0 = max(0, Int(gy - rr - 1)), j1 = min(PotionSim.NY - 1, Int(gy + rr + 1))
        guard i0 <= i1, j0 <= j1 else { return }
        var wsum: Float = 0
        for j in j0...j1 {
            for i in i0...i1 where !solid[PotionSim.idx(i, j)] {
                let dx = Float(i) - gx, dy = Float(j) - gy
                wsum += max(0, 1 - (dx * dx + dy * dy) / (rr * rr + 0.5))
            }
        }
        guard wsum > 0 else { return }
        let cr = Float(color.r), cg = Float(color.g), cb = Float(color.b)
        for j in j0...j1 {
            for i in i0...i1 {
                let k = PotionSim.idx(i, j)
                guard !solid[k] else { continue }
                let dx = Float(i) - gx, dy = Float(j) - gy
                let w = max(0, 1 - (dx * dx + dy * dy) / (rr * rr + 0.5)) / wsum
                guard w > 0 else { continue }
                dr[k] += cr * amount * w
                dg[k] += cg * amount * w
                db[k] += cb * amount * w
                da[k] += amount * w
                rho[k] += density * w
            }
        }
        version += 1
    }

    /// Pushes the liquid around p.
    func push(_ p: CGPoint, _ f: CGVector, radius: CGFloat) {
        let (gx, gy) = gridPos(p)
        let rr = Float(radius / PotionGeometry.cell)
        let i0 = max(0, Int(gx - rr)), i1 = min(PotionSim.NX - 1, Int(gx + rr) + 1)
        let j0 = max(0, Int(gy - rr)), j1 = min(PotionSim.NY - 1, Int(gy + rr) + 1)
        guard i0 <= i1, j0 <= j1 else { return }
        for j in j0...j1 {
            for i in i0...i1 {
                let k = PotionSim.idx(i, j)
                guard liquid[k] else { continue }
                let dx = Float(i) - gx, dy = Float(j) - gy
                let w = max(0, 1 - (dx * dx + dy * dy) / (rr * rr))
                u[k] += Float(f.dx) * w
                v[k] += Float(f.dy) * w
            }
        }
    }

    /// Liquid came in: everything already there is thinned a little (the potion gets bigger, not stronger).
    private func dilute(adding dV: CGFloat) {
        guard dV > 0 else { return }
        let k = Float(volume / max(1, volume + dV))
        for i in da.indices where !solid[i] {
            dr[i] *= k; dg[i] *= k; db[i] *= k; da[i] *= k; rho[i] *= k
        }
    }

    /// Pours liquid in at p (where a drop landed).
    func addLiquid(at p: CGPoint, vol: CGFloat, color: RGB, conc: Float, density: Float, v vin: CGVector) {
        let room = PotionGeometry.capacity - volume
        let dV = min(vol, max(0, room))
        if vol > dV { overflow(vol - dV, color: color) }
        guard dV > 0 else { return }
        dilute(adding: dV)
        volume += dV
        // the new liquid's pigment, spread over the cells it lands in (one cell holds cell*cell of liquid)
        let cells = Float(dV / (PotionGeometry.cell * PotionGeometry.cell))
        let q = CGPoint(x: p.x, y: max(p.y, level + 6))
        inject(q, color: color, amount: conc * cells, density: density * cells, radius: 1.6)
        push(q, CGVector(dx: vin.dx * 0.05, dy: min(260, vin.dy * 0.1)), radius: 18)
    }

    /// Too full: it runs over the rim and down the outside of the glass.
    private func overflow(_ vol: CGFloat, color: RGB) {
        let side: CGFloat = rand() < 0.5 ? -1 : 1
        let x = PotionGeometry.C.x + side * (PotionGeometry.hw + PotionGeometry.glass + 2)
        drops.append(PDrop(p: CGPoint(x: x, y: PotionGeometry.rimY - 2), v: CGVector(dx: side * 30, dy: 10), color: color, conc: 1,
                           density: 0, vol: vol, r: 4, stream: -1, ing: nil, potion: nil, splash: true, onGlass: true))
    }

    func updateLiquid() {
        level = PotionGeometry.level(for: volume)
        let NX = PotionSim.NX
        for j in 0..<PotionSim.NY {
            let y = PotionGeometry.gy0 + (CGFloat(j) + 0.5) * PotionGeometry.cell
            for i in 0..<NX {
                let k = j * NX + i
                liquid[k] = !solid[k] && y > level + 2
            }
        }
    }

    // MARK: - Step

    func step(_ date: Date) {
        let dt = lastDate.map { min(0.05, max(0, date.timeIntervalSince($0))) } ?? 1.0 / 60
        lastDate = date
        var left = dt
        while left > 0.0005 {
            let h = min(1.0 / 60, left)
            step(dt: h)
            left -= h
        }
    }

    func step(dt: Double) {
        let d = CGFloat(dt)
        time += dt
        night += ((lightsOn ? 0 : 1) - night) * min(1, d * 2.5)
        stepHeat(d)
        for ing in PIngredient.allCases where held != .ingredient(ing) {
            shelfFill[ing] = min(1, (shelfFill[ing] ?? 1) + d * 0.25)
        }
        stepHeld(d)
        stepSpoon(d)
        stepDrain(d)
        updateLiquid()
        fluidForces(d)
        fluidStep(Float(d))
        stepDrops(d)
        stepPieces(d)
        stepBubbles(d)
        stepGlitter(d)
        stepMotes(d)
        stepWaves(d)
        stepFlyers(d)
        stepUnicorn(d)
        stepRare(d)
        for i in puddles.indices { puddles[i].a -= d * 0.05 }
        puddles.removeAll { $0.a <= 0 }
        flash = max(0, flash - d * 1.5)
    }

    // MARK: Heat

    private func stepHeat(_ d: CGFloat) {
        let target: CGFloat = 0.22 + CGFloat(heat) * 0.27
        let rate: CGFloat = volume > 1 ? 0.12 * (1 + 30000 / max(8000, volume)) * 0.5 : 1
        temp += (target - temp) * min(1, d * rate)
        if boiling > 0.2 && volume > 1 {
            if (doses[.dragon] ?? 0) > PIngredient.dragon.need { boilTime += d }
            // bubbles come up from the bottom, more the hotter it is
            let n = boiling * 26 * d
            var k = n
            while k > 0 {
                if rand() < k {
                    let x = PotionGeometry.C.x + rand(-110, 110)
                    let y = PotionGeometry.bottomY - 10 - rand(0, 18)
                    let p = CGPoint(x: x, y: y)
                    if PotionGeometry.inside(p, pad: 4) && inLiquid(p) {
                        bubbles.append(PBubble(p: p, r: rand(2, 4 + 5 * boiling), phase: rand(0, 6), fizzy: false))
                    }
                }
                k -= 1
            }
        }
        // steam off a hot potion
        if temp > 0.55 && volume > 1 && rand() < (temp - 0.5) * d * 30 {
            let (c, a) = meanColor()
            let x = PotionGeometry.C.x + rand(-PotionGeometry.hw * 0.8, PotionGeometry.hw * 0.8)
            motes.append(PMote(p: CGPoint(x: x, y: max(PotionGeometry.rimY, surfaceY(x)) - 4), v: CGVector(dx: rand(-10, 10), dy: rand(-60, -36)),
                               max: rand(1.6, 2.6), kind: .steam, color: RGB(1, 1, 1).mix(c, Double(min(0.5, a))), size: rand(14, 24)))
        }
    }

    func setHeat(_ h: Int) {
        heat = max(0, min(3, h))
        cue(.knob)
        if heat > 0 { cue(.whoosh, gap: 0.3) }
    }

    func setLights(_ on: Bool) {
        lightsOn = on
        cue(.click)
    }

    // MARK: Drain

    func toggleDrain() {
        draining.toggle()
        cue(.click)
        if draining && volume > 1 { cue(.gurgle) }
    }

    private func stepDrain(_ d: CGFloat) {
        guard draining else { return }
        guard volume > 1 else {
            volume = 0
            draining = false
            for k in da.indices { dr[k] = 0; dg[k] = 0; db[k] = 0; da[k] = 0; rho[k] = 0; u[k] = 0; v[k] = 0 }
            doses = [:]
            boilTime = 0
            glitter.removeAll()
            pieces.removeAll { $0.state == .liquid }
            version += 1
            return
        }
        let rate: CGFloat = 9000 + volume * 0.25
        let dV = min(volume, rate * d)
        let f = dV / volume
        // the color that runs out is the color down at the valve
        let (c, a) = colorAt(CGPoint(x: PotionGeometry.C.x + 40, y: PotionGeometry.bottomY - 14))
        volume -= dV
        for (k, x) in doses { doses[k] = x * (1 - f) }
        if rand() < f * 40 && !glitter.isEmpty { glitter.removeFirst(min(glitter.count, Int(f * CGFloat(glitter.count)) + 1)) }
        // it swirls toward the valve
        push(CGPoint(x: PotionGeometry.C.x + 40, y: PotionGeometry.bottomY - 20), CGVector(dx: 30, dy: 40), radius: 40)
        bucketFill = min(1, bucketFill + dV / 60000)
        bucketColor = bucketColor.mix(c.mix(PIngredient.water.color, Double(max(0, 1 - a * 2))), Double(min(1, f * 4)))
        // the stream out of the pipe into the bucket
        let m = PotionGeometry.drainMouth
        drops.append(PDrop(p: CGPoint(x: m.x + rand(-2, 2), y: m.y - 6), v: CGVector(dx: 0, dy: 60), color: c.mix(PIngredient.water.color, Double(max(0, 1 - a * 2))),
                           conc: 0, density: 0, vol: 0, r: 5, stream: 0, ing: nil, potion: nil, splash: true, onGlass: true))
        cue(.glug, gap: 0.5)
    }

    // MARK: - Holding things

    /// Where she can pour into: over the flask's mouth.
    static func overMouth(_ p: CGPoint) -> Bool { abs(p.x - PotionGeometry.C.x) < PotionGeometry.hw + 60 && p.y < PotionGeometry.rimY + 20 }
    static func overUnicorn(_ p: CGPoint) -> Bool {
        let b = PotionGeometry.unicornBox
        return p.x > b.minX - 40 && p.x < b.maxX + 40 && p.y < b.minY + 40
    }

    func pickUp(_ h: PHeld, finger: CGPoint, at p: CGPoint) {
        held = h
        hand = finger
        heldPos = p
        lastHeld = p
        heldVel = .zero
        heldTilt = 0
        shakeEnergy = 0
        switch h {
        case .ingredient(let ing):
            heldFill = shelfFill[ing] ?? 1
            cue(ing.isLiquid ? .clink : .shake)
        case .rack(let i):
            heldFill = CGFloat(rack[safe: i]?.fill ?? 0)
            cue(.clink)
        case .empty:
            dipFill = 0
            dipColor = RGB(1, 1, 1)
            dipMagic = [:]
            dipInside = false
            lastRawY = p.y
            cue(.clink)
        case .spoon:
            spoonHeld = true
            cue(.tap)
        }
        heldStream = streamID
        streamID += 1
    }

    /// She moves what she holds: `p` is where it goes (already lifted off her finger), `finger` her finger.
    func carry(to p: CGPoint, finger: CGPoint) {
        hand = finger
        switch held {
        case .spoon:
            spoonTarget = p
        case .empty:
            heldPos = constrainDip(p)
        default:
            heldPos = p
        }
    }

    /// An empty bottle can only get into the flask through its mouth, and can't go through the glass.
    private func constrainDip(_ p: CGPoint) -> CGPoint {
        let s = PotionSim.heldScale
        let halfW = 40 * s, bottom = PBottleShape.bottomY * s, top = PBottleShape.mouthY * s
        var q = p
        let bottomY = q.y + bottom
        if dipInside {
            // inside: keep the bottle within the glass
            q.y = min(q.y, PotionGeometry.bottomY - 4 - bottom)
            let y0 = max(PotionGeometry.rimY + 1, q.y + top), y1 = q.y + bottom
            var allowed: CGFloat = 999
            var y = y0
            while y <= y1 {
                allowed = min(allowed, PotionGeometry.halfWidth(at: y) - halfW - 3)
                y += 8
            }
            allowed = max(0, allowed)
            q.x = max(PotionGeometry.C.x - allowed, min(PotionGeometry.C.x + allowed, q.x))
            if bottomY < PotionGeometry.rimY - 4 { dipInside = false }
        } else {
            let lineUp = abs(q.x - PotionGeometry.C.x) < PotionGeometry.hw - halfW - 2
            if bottomY > PotionGeometry.rimY - 6 {
                // it only goes in when she brings it down from above the mouth
                if lineUp && lastRawY + bottom <= PotionGeometry.rimY + 30 {
                    dipInside = true
                    cue(.clink, gap: 0.3)
                } else if abs(q.x - PotionGeometry.C.x) < PotionGeometry.R + PotionGeometry.glass + halfW && bottomY < PotionGeometry.bottomY + 40 {
                    // over the glass but not lined up with the mouth: it rests on the rim / beside it
                    if abs(q.x - PotionGeometry.C.x) < PotionGeometry.hw + PotionGeometry.glass + halfW {
                        q.y = min(q.y, PotionGeometry.rimY - 8 - bottom)
                    } else if q.y + bottom > PotionGeometry.rimY {
                        // to the side of the flask: keep outside its round body
                        let dx = q.x - PotionGeometry.C.x, dy = q.y - PotionGeometry.C.y
                        let dist = hypot(dx, dy)
                        let need = PotionGeometry.R + PotionGeometry.glass + halfW + 4
                        if dist < need && dist > 1 {
                            q.x = PotionGeometry.C.x + dx / dist * need
                            q.y = PotionGeometry.C.y + dy / dist * need
                        }
                    }
                }
            }
        }
        lastRawY = p.y
        return q
    }
    private var lastRawY: CGFloat = 0

    func release() {
        guard let h = held else { return }
        switch h {
        case .spoon:
            spoonHeld = false
        case .ingredient(let ing):
            shelfFill[ing] = heldFill
            flyers.append(PFlyer(from: heldPos, to: CGPoint(x: ing.shelfSpot.x, y: ing.shelfSpot.y - 62), bottle: nil, rackIndex: nil, spin: heldTilt, ing: ing))
        case .rack(let i):
            if heldFill < 0.03 {
                // it's empty: poof
                if i < rack.count { rack.remove(at: i) }
                sparkleBurst(at: heldPos, color: RGB(1, 1, 1), n: 10)
                cue(.poof)
            } else if i < rack.count {
                rack[i].fill = Double(heldFill)
                flyers.append(PFlyer(from: heldPos, to: PotionSim.rackFly(i), bottle: rack[i], rackIndex: i, spin: heldTilt))
            }
        case .empty:
            finishDip()
        }
        held = nil
        heldTilt = 0
    }

    var hiddenRack: Set<Int> {
        var s = Set<Int>()
        if case .rack(let i) = held { s.insert(i) }
        for f in flyers { if let i = f.rackIndex { s.insert(i) } }
        return s
    }
    var hiddenIngredient: Set<Int> {
        var s = Set<Int>()
        if case .ingredient(let ing) = held { s.insert(ing.rawValue) }
        for f in flyers { if let ing = f.ing { s.insert(ing.rawValue) } }
        return s
    }
    static func rackFly(_ i: Int) -> CGPoint {
        let s = rackSpot(i)
        return CGPoint(x: s.x, y: s.y - PBottleShape.bottomY * rackScale)
    }

    private func finishDip() {
        if dipFill > 0.2 {
            cork()
        } else {
            flyers.append(PFlyer(from: heldPos, to: CGPoint(x: PotionGeometry.crate.midX, y: PotionGeometry.crate.minY - 10), bottle: nil, rackIndex: nil, spin: 0))
        }
        dipInside = false
    }

    /// A filled bottle gets its cork, and flies to the rack. If the potion was a rare one, it turns into its bottle.
    private func cork() {
        var mag: [String: Double] = [:]
        var total: CGFloat = 0
        for (ing, x) in dipMagic { total += x; if let m = ing.magic { mag[m.rawValue, default: 0] += Double(x) } }
        if total > 0 { for (k, x) in mag { mag[k] = min(1, x / Double(total) * 1.4) } }
        let kind = rare
        var color = dipColor
        var shape = [PBottleShape.round, .tall, .round, .drop][Int(rand() * 3.99)].rawValue
        var glow = Double(flaskGlow)
        var sparkle = Double(min(1, CGFloat(glitter.count) / 160))
        if let k = kind {
            color = k.color
            shape = k.shape.rawValue
            glow = Double(k.glow)
            sparkle = Double(k.sparkle)
        }
        let b = PotionBottle(id: nextID, r: color.r, g: color.g, b: color.b, fill: Double(min(1, dipFill)), shape: shape,
                             kind: kind?.rawValue, magic: mag, glow: glow, sparkle: sparkle)
        nextID += 1
        made += 1
        if rack.count >= PotionSim.rackMax { rack.removeFirst() }
        rack.append(b)
        let i = rack.count - 1
        flyers.append(PFlyer(from: heldPos, to: PotionSim.rackFly(i), bottle: b, rackIndex: i, spin: 0))
        cue(.cork)
        sparkleBurst(at: CGPoint(x: heldPos.x, y: heldPos.y - 50), color: kind?.color ?? color, n: kind == nil ? 8 : 18)
        if let k = kind {
            cue(.magic)
            if !demo { StickerBook.shared.find(game: PotionSim.gameID, id: k.rawValue) }
        } else {
            cue(.chime)
        }
        save()
    }

    func sparkleBurst(at p: CGPoint, color: RGB, n: Int) {
        for k in 0..<n {
            let a = CGFloat(k) / CGFloat(n) * 2 * .pi + rand(0, 0.4)
            let s = rand(60, 180)
            motes.append(PMote(p: p, v: CGVector(dx: cos(a) * s, dy: sin(a) * s - 40), max: rand(0.6, 1.1), kind: .sparkle,
                               color: k % 3 == 0 ? RGB(1, 1, 1) : color.mix(RGB(1, 1, 1), 0.3), size: rand(8, 15)))
        }
    }

    private func stepHeld(_ d: CGFloat) {
        guard let h = held else { return }
        // how she moves it (smoothed), for shaking and splashing
        if h != .spoon {
            let vx = (heldPos.x - lastHeld.x) / max(d, 0.001), vy = (heldPos.y - lastHeld.y) / max(d, 0.001)
            let k = min(1, d * 14)
            let nv = CGVector(dx: heldVel.dx + (vx - heldVel.dx) * k, dy: heldVel.dy + (vy - heldVel.dy) * k)
            shakeEnergy += abs(nv.dx - heldVel.dx) + abs(nv.dy - heldVel.dy)
            shakeEnergy *= max(0, 1 - d * 3)
            heldVel = nv
        }
        lastHeld = heldPos
        if demoKeepFull { heldFill = max(heldFill, 0.75) }
        switch h {
        case .ingredient(let ing):
            if ing.isLiquid { pourBottle(d, color: ing.color, conc: ing.strength, density: ing.density, ing: ing, potion: nil, shape: shapeFor(ing)) }
            else { shakeJar(d, ing) }
        case .rack(let i):
            guard let b = rack[safe: i] else { return }
            pourBottle(d, color: b.color, conc: 1, density: 0, ing: nil, potion: i, shape: b.bottleShape)
        case .empty:
            dipBottle(d)
        case .spoon:
            break
        }
    }
    private var lastHeld = CGPoint.zero

    func shapeFor(_ ing: PIngredient) -> PBottleShape { PotionSimShapes.shape(ing) }

    /// A bottle tips over the flask (or the unicorn) and pours once its liquid reaches the mouth.
    private func pourBottle(_ d: CGFloat, color: RGB, conc: Float, density: Float, ing: PIngredient?, potion: Int?, shape: PBottleShape) {
        let overFlask = PotionSim.overMouth(heldPos)
        let overUnicorn = PotionSim.overUnicorn(heldPos)
        let over = overFlask || overUnicorn
        // tip toward the middle of what it's over
        let targetX = overUnicorn ? PotionGeometry.unicornBox.midX : PotionGeometry.C.x
        let side: CGFloat = heldPos.x > targetX + 14 ? -1 : 1
        let want: CGFloat = over ? side * 2.1 : 0
        heldTilt += (want - heldTilt) * min(1, d * (over ? 3.2 : 6))
        let s = PotionSim.heldScale
        let poly = PPoly.transform(shape.outline, at: heldPos, angle: heldTilt, scale: s)
        let lvl = PPoly.level(poly, fill: heldFill)
        let ca = cos(heldTilt), sa = sin(heldTilt)
        let mouth = CGPoint(x: heldPos.x - PBottleShape.mouthY * s * sa, y: heldPos.y + PBottleShape.mouthY * s * ca)
        let depth = mouth.y - lvl + 3
        guard heldFill > 0.001, depth > 0, abs(heldTilt) > 1.2 else { return }
        // glug glug: the flow pulses as air gets back in
        let pulse = 0.7 + 0.3 * sin(CGFloat(time) * 16)
        let q = min(0.9, 0.18 * sqrt(depth)) * pulse
        let dFill = min(heldFill, q * d)
        heldFill -= dFill
        let vol = dFill * (potion != nil ? PotionSim.bottleVol * 0.7 : PotionSim.bottleVol)
        let dir = CGVector(dx: sa, dy: -ca)
        let speed = 50 + 60 * sqrt(depth)
        let r = 3 + 5 * min(1, q / 0.5)
        var flow = CGVector(dx: dir.dx * speed + heldVel.dx * 0.3, dy: dir.dy * speed + heldVel.dy * 0.3)
        if overFlask {
            // Keep a tipped stream aimed down the neck. A sideways launch from a bottle over the rim
            // otherwise hits the far wall before it reaches the bowl, even with the lip centered.
            let across = (targetX - mouth.x) * 3.6 + heldVel.dx * 0.12
            flow = CGVector(dx: max(-150, min(150, across)), dy: max(70, flow.dy))
        }
        drops.append(PDrop(p: mouth, v: flow,
                           color: color, conc: conc, density: density, vol: vol, r: r, stream: heldStream, ing: ing, potion: potion))
        cue(.glug, gap: 0.22)
    }

    /// A jar is turned over above the flask; shaking it drops pieces out.
    private func shakeJar(_ d: CGFloat, _ ing: PIngredient) {
        let over = PotionSim.overMouth(heldPos)
        let want: CGFloat = over ? 2.7 : 0
        heldTilt += (want - heldTilt) * min(1, d * 5)
        guard heldTilt > 2.2 else { return }
        let since = CGFloat(time) - lastShakeAt
        let gap: CGFloat = ing == .hair ? 1.1 : 0.5
        if (shakeEnergy > 220 && since > 0.12) || since > gap * 1.6 {
            guard ing != .hair || since > gap else { return }
            lastShakeAt = CGFloat(time)
            shakeEnergy *= 0.4
            let s = PotionSim.heldScale
            let mouth = CGPoint(x: heldPos.x - PBottleShape.mouthY * s * sin(heldTilt), y: heldPos.y + PBottleShape.mouthY * s * cos(heldTilt))
            let n = ing == .hair ? 1 : (since < 0.3 ? 2 : 1)
            for _ in 0..<n { addPiece(ing, at: CGPoint(x: mouth.x + rand(-10, 10), y: mouth.y + 4), v: CGVector(dx: heldVel.dx * 0.3 + rand(-30, 30), dy: 80)) }
            cue(.shake, gap: 0.12)
        }
    }

    func addPiece(_ ing: PIngredient, at p: CGPoint, v: CGVector) {
        var pc = PPiece(kind: ing, p: p, v: v, ang: rand(0, 6.28), spin: rand(-4, 4), seed: Int(rand() * 1000))
        pc.burstAt = rand(1.8, 3.2)
        if pieces.count > 60 { pieces.removeFirst() }
        pieces.append(pc)
    }

    /// The empty bottle in the potion: it fills (bubbles glug out of its mouth) with the potion around its mouth.
    private func dipBottle(_ d: CGFloat) {
        guard dipInside, volume > 1 else { return }
        let s = PotionSim.heldScale
        let mouth = CGPoint(x: heldPos.x, y: heldPos.y + PBottleShape.mouthY * s)
        let surf = surfaceY(mouth.x)
        let depth = mouth.y - surf
        guard depth > 0, dipFill < 1 else { return }
        let q = min(0.85, 0.12 * sqrt(depth) + 0.15)
        let dF = min(1 - dipFill, q * d)
        let vol = dF * PotionSim.bottleVol * 0.7
        guard vol < volume else { return }
        let (c, a) = colorAt(CGPoint(x: mouth.x, y: mouth.y + 6))
        let shown = c.mix(PIngredient.water.color, Double(max(0, 1 - a * 1.6)))
        dipColor = dipFill < 0.01 ? shown : dipColor.mix(shown, Double(dF / max(0.01, dipFill + dF)))
        let f = vol / volume
        for (k, x) in doses {
            let take = x * f
            doses[k] = x - take
            dipMagic[k, default: 0] += take
        }
        volume -= vol
        dipFill += dF
        // the liquid rushes into the mouth; air bubbles out
        push(mouth, CGVector(dx: (heldPos.x - mouth.x) * 0.1, dy: 20), radius: 20)
        if rand() < d * 22 {
            bubbles.append(PBubble(p: CGPoint(x: mouth.x + rand(-4, 4), y: mouth.y - 2), r: rand(3, 7), phase: rand(0, 6), fizzy: false))
        }
        cue(.fill, gap: 0.3)
        if dipFill >= 1 { cue(.clink, gap: 0.5) }
    }

    // MARK: - The stirring paddle

    private func stepSpoon(_ d: CGFloat) {
        let old = spoon
        if demoStir {
            spoonTarget = CGPoint(x: PotionGeometry.C.x + cos(CGFloat(time) * 3) * 100, y: PotionGeometry.C.y + 40 + sin(CGFloat(time) * 3) * 60)
        }
        if spoonHeld {
            // the blade follows her (it can't leave the glass)
            var t = spoonTarget
            if !PotionGeometry.inside(t, pad: 14) {
                // pull it back inside along the line to the middle
                let c = CGPoint(x: PotionGeometry.C.x, y: max(PotionGeometry.rimY + 30, min(PotionGeometry.C.y, t.y)))
                for _ in 0..<20 {
                    t = CGPoint(x: t.x + (c.x - t.x) * 0.15, y: t.y + (c.y - t.y) * 0.15)
                    if PotionGeometry.inside(t, pad: 14) { break }
                }
            }
            spoon = CGPoint(x: spoon.x + (t.x - spoon.x) * min(1, d * 22), y: spoon.y + (t.y - spoon.y) * min(1, d * 22))
        } else {
            // it slides back to lean on the side of the flask
            spoon = CGPoint(x: spoon.x + (PotionSim.spoonRest.x - spoon.x) * min(1, d * 2.5),
                            y: spoon.y + (PotionSim.spoonRest.y - spoon.y) * min(1, d * 2.5))
        }
        let nv = CGVector(dx: (spoon.x - old.x) / max(d, 0.001), dy: (spoon.y - old.y) / max(d, 0.001))
        spoonVel = CGVector(dx: spoonVel.dx + (nv.dx - spoonVel.dx) * min(1, d * 20), dy: spoonVel.dy + (nv.dy - spoonVel.dy) * min(1, d * 20))
        let speed = hypot(spoonVel.dx, spoonVel.dy)
        let wet = inLiquid(spoon)
        stirSpeed += ((wet ? speed : 0) - stirSpeed) * min(1, d * 8)
        guard wet else { return }
        // the blade drags the potion along
        let r = 26 * FingerLift.spread
        let k: CGFloat = min(1, d * 9)
        let (gx, gy) = gridPos(spoon)
        let rr = Float(r / PotionGeometry.cell)
        let i0 = max(0, Int(gx - rr)), i1 = min(PotionSim.NX - 1, Int(gx + rr) + 1)
        let j0 = max(0, Int(gy - rr)), j1 = min(PotionSim.NY - 1, Int(gy + rr) + 1)
        if i0 <= i1 && j0 <= j1 {
            for j in j0...j1 {
                for i in i0...i1 {
                    let c = PotionSim.idx(i, j)
                    guard liquid[c] else { continue }
                    let dx = Float(i) - gx, dy = Float(j) - gy
                    let w = max(0, 1 - (dx * dx + dy * dy) / (rr * rr)) * Float(k)
                    u[c] += (Float(spoonVel.dx) - u[c]) * w
                    v[c] += (Float(spoonVel.dy) - v[c]) * w
                }
            }
        }
        // near the top it makes waves, fast near the top it splashes
        let depth = spoon.y - surfaceY(spoon.x)
        if depth < 50 {
            let col = Int((spoon.x - PotionGeometry.gx0) / PotionGeometry.cell)
            if col >= 0 && col < PotionSim.NX { waveV[col] += spoonVel.dy * 0.004 + abs(spoonVel.dx) * 0.0015 * (50 - depth) / 50 }
            if speed > 700 && depth < 24 && rand() < d * 14 {
                let (c, a) = colorAt(spoon)
                let up = CGVector(dx: spoonVel.dx * 0.3 + rand(-60, 60), dy: -rand(160, 320))
                drops.append(PDrop(p: CGPoint(x: spoon.x, y: surfaceY(spoon.x) - 2), v: up, color: c.mix(PIngredient.water.color, Double(max(0, 1 - a * 2))),
                                   conc: 0, density: 0, vol: 0, r: rand(2, 4), stream: -1, ing: nil, potion: nil, splash: true))
            }
        }
        if speed > 500 && rand() < d * speed / 200 {
            bubbles.append(PBubble(p: CGPoint(x: spoon.x + rand(-10, 10), y: spoon.y + rand(-10, 10)), r: rand(1.5, 3), phase: rand(0, 6), fizzy: false))
        }
    }

    // MARK: - Fluid

    private func fluidForces(_ d: CGFloat) {
        let NX = PotionSim.NX, NY = PotionSim.NY
        // buoyancy: heavier than average sinks
        var mean: Float = 0
        var n = 0
        for k in rho.indices where liquid[k] { mean += rho[k]; n += 1 }
        guard n > 0 else { return }
        mean /= Float(n)
        let g = Float(d) * 900
        let heatStir = Float(boiling) * 30
        for j in 0..<NY {
            for i in 0..<NX {
                let k = j * NX + i
                guard liquid[k] else { continue }
                // the share of heavy stuff in this cell, relative to its pigment (so thin and thick mix alike)
                let excess = (rho[k] - mean) / (0.6 + da[k] * 0.2 + abs(mean))
                v[k] += g * max(-0.6, min(0.6, excess)) * 0.1
                if heatStir > 0 {
                    // boiling stirs it: warm plumes rise in the middle, come down at the sides
                    let x = Float(i) / Float(NX - 1) - 0.5
                    v[k] -= Float(d) * heatStir * (cos(x * 6.28 + Float(time) * 0.7) * 1.2)
                }
            }
        }
    }

    func fluidStep(_ dt: Float) {
        let NX = PotionSim.NX, NY = PotionSim.NY
        let n = NX * NY
        // velocities outside the liquid are zero (walls)
        for k in 0..<n where !liquid[k] { u[k] = 0; v[k] = 0 }

        // vorticity confinement: keep the little swirls alive
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                curl[k] = liquid[k] ? 0.5 * ((v[k + 1] - v[k - 1]) - (u[k + NX] - u[k - NX])) : 0
            }
        }
        let eps: Float = 1.6
        for j in 2..<(NY - 2) {
            for i in 2..<(NX - 2) {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let gx = abs(curl[k + 1]) - abs(curl[k - 1])
                let gy = abs(curl[k + NX]) - abs(curl[k - NX])
                let len = sqrt(gx * gx + gy * gy) + 1e-5
                let w = curl[k]
                u[k] += dt * eps * (gy / len) * w
                v[k] -= dt * eps * (gx / len) * w
            }
        }

        // carry the velocity along itself
        t0 = u
        t1 = v
        let s = dt / Float(PotionGeometry.cell)
        for j in 0..<NY {
            for i in 0..<NX {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let x = Float(i) - s * t0[k], y = Float(j) - s * t1[k]
                u[k] = sample(t0, x, y) * 0.994
                v[k] = sample(t1, x, y) * 0.994
            }
        }
        for k in 0..<n where !liquid[k] { u[k] = 0; v[k] = 0 }

        // make it flow without squeezing (pressure projection)
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                dv[k] = liquid[k] ? -0.5 * (u[k + 1] - u[k - 1] + v[k + NX] - v[k - NX]) : 0
            }
        }
        for _ in 0..<18 {
            for j in 1..<(NY - 1) {
                for i in 1..<(NX - 1) {
                    let k = j * NX + i
                    guard liquid[k] else { continue }
                    let pc = pr[k]
                    let a = liquid[k - 1] ? pr[k - 1] : pc
                    let b = liquid[k + 1] ? pr[k + 1] : pc
                    let c = liquid[k - NX] ? pr[k - NX] : pc
                    let e = liquid[k + NX] ? pr[k + NX] : pc
                    pr[k] = (dv[k] + a + b + c + e) * 0.25
                }
            }
        }
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let pc = pr[k]
                let a = liquid[k - 1] ? pr[k - 1] : pc
                let b = liquid[k + 1] ? pr[k + 1] : pc
                let c = liquid[k - NX] ? pr[k - NX] : pc
                let e = liquid[k + NX] ? pr[k + NX] : pc
                u[k] -= 0.5 * (b - a)
                v[k] -= 0.5 * (e - c)
                // never let it get wild
                u[k] = max(-900, min(900, u[k]))
                v[k] = max(-900, min(900, v[k]))
            }
        }

        // the pigment: copy it a cell out past the liquid's edge so the edges don't fade, then carry it along
        extend(&dr); extend(&dg); extend(&db); extend(&da); extend(&rho)
        t0 = dr; t1 = dg; t2 = db; t3 = da; t4 = rho
        let diff: Float = 0.012 + Float(temp) * 0.012
        for j in 0..<NY {
            for i in 0..<NX {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let x = Float(i) - s * u[k], y = Float(j) - s * v[k]
                dr[k] = sample(t0, x, y)
                dg[k] = sample(t1, x, y)
                db[k] = sample(t2, x, y)
                da[k] = sample(t3, x, y)
                rho[k] = sample(t4, x, y)
            }
        }
        // a little blending with the neighbours: colors marble first, then slowly mix
        t5 = da
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                guard liquid[k] else { continue }
                var cnt: Float = 0
                var ar: Float = 0, ag: Float = 0, ab: Float = 0, aa: Float = 0, ah: Float = 0
                for o in [k - 1, k + 1, k - NX, k + NX] where liquid[o] {
                    ar += dr[o]; ag += dg[o]; ab += db[o]; aa += da[o]; ah += rho[o]; cnt += 1
                }
                guard cnt > 0 else { continue }
                let w = diff
                dr[k] += (ar / cnt - dr[k]) * w
                dg[k] += (ag / cnt - dg[k]) * w
                db[k] += (ab / cnt - db[k]) * w
                da[k] += (aa / cnt - da[k]) * w
                rho[k] += (ah / cnt - rho[k]) * w
            }
        }
        for k in 0..<n where liquid[k] {
            if da[k] < 0 { da[k] = 0 }
            if dr[k] < 0 { dr[k] = 0 }
            if dg[k] < 0 { dg[k] = 0 }
            if db[k] < 0 { db[k] = 0 }
        }
        // the cells above the surface hold the color of the top of the liquid, so a rising surface keeps it
        for i in 0..<NX {
            var top = -1
            for j in 0..<NY where liquid[j * NX + i] { top = j; break }
            guard top > 0 else { continue }
            let src = top * NX + i
            for j in 0..<top {
                let k = j * NX + i
                if solid[k] { continue }
                dr[k] = dr[src]; dg[k] = dg[src]; db[k] = db[src]; da[k] = da[src]; rho[k] = rho[src]
            }
        }
        // how much it swirls (for the whirlpool dip in the surface)
        var spin: Float = 0
        var cnt: Float = 0
        for k in 0..<n where liquid[k] { spin += abs(u[k]); cnt += 1 }
        let sw = CGFloat(cnt > 0 ? spin / cnt : 0)
        swirl += (min(26, sw * 0.12) - swirl) * 0.05
        version += 1
    }

    /// Copies values into the cells just outside the liquid from their liquid neighbours.
    private func extend(_ f: inout [Float]) {
        let NX = PotionSim.NX, NY = PotionSim.NY
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                guard !liquid[k] && solid[k] else { continue }
                var s: Float = 0, c: Float = 0
                if liquid[k - 1] { s += f[k - 1]; c += 1 }
                if liquid[k + 1] { s += f[k + 1]; c += 1 }
                if liquid[k - NX] { s += f[k - NX]; c += 1 }
                if liquid[k + NX] { s += f[k + NX]; c += 1 }
                if c > 0 { f[k] = s / c }
            }
        }
    }

    // MARK: - Drops (pours and splashes)

    private func stepDrops(_ d: CGFloat) {
        var keep: [PDrop] = []
        keep.reserveCapacity(drops.count)
        for dp0 in drops {
            var dp = dp0
            dp.v.dy += 1500 * d
            dp.p.x += dp.v.dx * d
            dp.p.y += dp.v.dy * d
            if dp.stream == 0 {
                // the drain stream: into the bucket
                if dp.p.y > PotionGeometry.bucket.minY + 24 - bucketFill * 30 {
                    if rand() < 0.3 { cue(.drip, gap: 0.25) }
                    continue
                }
                keep.append(dp)
                continue
            }
            if !dp.onGlass && PotionGeometry.inside(dp.p) {
                if dp.p.y > surfaceY(dp.p.x) {
                    landInPotion(dp)
                    continue
                }
            } else if !dp.onGlass && PotionGeometry.insideOuter(dp.p) {
                // it hit the glass from outside: it runs down the side
                dp.onGlass = true
                dp.v = CGVector(dx: dp.p.x < PotionGeometry.C.x ? -20 : 20, dy: 40)
                cue(.drip, gap: 0.2)
            }
            if dp.onGlass && PotionGeometry.insideOuter(dp.p, pad: 2) {
                // slide down the outside of the glass
                let dx = dp.p.x - PotionGeometry.C.x, dy = dp.p.y - PotionGeometry.C.y
                let dist = max(1, hypot(dx, dy))
                if dp.p.y > PotionGeometry.joinY {
                    dp.p = CGPoint(x: PotionGeometry.C.x + dx / dist * (PotionGeometry.R + PotionGeometry.glass + 3), y: PotionGeometry.C.y + dy / dist * (PotionGeometry.R + PotionGeometry.glass + 3))
                } else {
                    dp.p.x = PotionGeometry.C.x + (dx < 0 ? -1 : 1) * (PotionGeometry.hw + PotionGeometry.glass + 3)
                }
                dp.v.dy = min(dp.v.dy, 120)
                if dp.p.y > PotionGeometry.C.y + PotionGeometry.R * 0.85 { dp.v.dx = 0; dp.onGlass = false; dp.p.y += 4 }
            }
            if PotionGeometry.unicornBox.contains(dp.p) && !dp.splash && dp.p.y > PotionGeometry.unicornBox.minY + 10 {
                unicornGets(dp)
                continue
            }
            let floorY: CGFloat = dp.p.x > PotionGeometry.bucket.minX && dp.p.x < PotionGeometry.bucket.maxX ? PotionGeometry.bucket.minY + 20 : PotionGeometry.tableY
            if dp.p.y >= floorY {
                if dp.r >= 3 || dp.vol > 0 { landOnTable(dp) }
                continue
            }
            if dp.p.y > 900 || dp.p.x < -300 || dp.p.x > 1400 { continue }
            keep.append(dp)
        }
        drops = keep
        if drops.count > 900 { drops.removeFirst(drops.count - 900) }
    }

    private func landInPotion(_ dp: PDrop) {
        let col = Int((dp.p.x - PotionGeometry.gx0) / PotionGeometry.cell)
        if col >= 0 && col < PotionSim.NX {
            waveV[col] += min(3, dp.v.dy * 0.0016 * (dp.splash ? 0.4 : 1) * (0.5 + dp.r / 6))
        }
        if dp.splash { return }
        var dens = dp.density
        var color = dp.color
        var conc = dp.conc
        if let i = dp.potion, let b = rack[safe: i] {
            // a bottled potion poured back in: its magic comes too
            color = b.color
            conc = 1
            dens = 0
            for (m, x) in b.magic {
                if let ing = PIngredient.allCases.first(where: { $0.magic?.rawValue == m && $0 != .water }) {
                    doses[ing, default: 0] += CGFloat(x) * dp.vol / 4000
                }
            }
            if let k = b.potion { for ing in k.recipe { doses[ing, default: 0] += dp.vol / 8000 } }
        } else if let ing = dp.ing, ing != .water {
            doses[ing, default: 0] += dp.vol / 4000
            if ing == .dragon { temp = min(1, temp + dp.vol / 220000) }
            if ing == .night, rand() < dp.vol / 900 { addGlitter(at: dp.p, color: RGB(1, 1, 1), size: rand(1.2, 2.2)) }
            if ing == .moon, rand() < dp.vol / 2400 { addGlitter(at: dp.p, color: RGB(0.95, 0.9, 1), size: rand(1.5, 2.5)) }
        }
        addLiquid(at: dp.p, vol: dp.vol, color: color, conc: conc, density: dens, v: dp.v)
        // a fast stream pulls air down with it
        if dp.r > 4 && rand() < 0.35 {
            bubbles.append(PBubble(p: CGPoint(x: dp.p.x + rand(-8, 8), y: max(dp.p.y, level) + rand(6, 30)), r: rand(1.5, 4), phase: rand(0, 6), fizzy: false))
        }
        if dp.r > 5 && rand() < 0.12 {
            drops.append(PDrop(p: CGPoint(x: dp.p.x, y: surfaceY(dp.p.x) - 2), v: CGVector(dx: rand(-90, 90), dy: -rand(100, 220)), color: color,
                               conc: 0, density: 0, vol: 0, r: rand(1.5, 3), stream: -1, ing: nil, potion: nil, splash: true))
        }
        cue(.splash, gap: 0.35)
    }

    private func landOnTable(_ dp: PDrop) {
        let y: CGFloat = dp.p.x > PotionGeometry.bucket.minX && dp.p.x < PotionGeometry.bucket.maxX ? PotionGeometry.bucket.minY + 20 : PotionGeometry.tableY
        if dp.p.x > PotionGeometry.bucket.minX && dp.p.x < PotionGeometry.bucket.maxX { return }
        if let i = puddles.firstIndex(where: { abs($0.x - dp.p.x) < $0.w * 0.6 && abs($0.y - y) < 4 }) {
            puddles[i].w = min(110, puddles[i].w + dp.vol / 300 + 0.5)
            puddles[i].color = puddles[i].color.mix(dp.color, 0.1)
            puddles[i].a = min(1, puddles[i].a + 0.05)
        } else if puddles.count < 14 {
            puddles.append(PPuddle(x: dp.p.x, y: y, w: 14 + dp.vol / 300, color: dp.color, a: 0.8))
        }
        if rand() < 0.3 { cue(.drip, gap: 0.2) }
    }

    // MARK: - Pieces

    private func stepPieces(_ d: CGFloat) {
        var keep: [PPiece] = []
        for pc0 in pieces {
            var pc = pc0
            pc.age += d
            pc.ang += pc.spin * d
            switch pc.state {
            case .air:
                pc.v.dy += 1400 * d
                pc.p.x += pc.v.dx * d
                pc.p.y += pc.v.dy * d
                if PotionGeometry.inside(pc.p, pad: 4) {
                    if pc.p.y > surfaceY(pc.p.x) {
                        pc.state = .liquid
                        let col = Int((pc.p.x - PotionGeometry.gx0) / PotionGeometry.cell)
                        if col >= 0 && col < PotionSim.NX { waveV[col] += min(2.4, pc.v.dy * 0.003) }
                        pc.v = CGVector(dx: pc.v.dx * 0.3, dy: pc.v.dy * 0.25)
                        cue(.plop, gap: 0.08)
                        for _ in 0..<2 { bubbles.append(PBubble(p: CGPoint(x: pc.p.x + rand(-6, 6), y: pc.p.y + rand(4, 12)), r: rand(1.5, 3), phase: rand(0, 6), fizzy: false)) }
                    }
                } else if PotionGeometry.insideOuter(pc.p, pad: 6) {
                    // bounced off the rim or the glass: it falls off to the side
                    let side: CGFloat = pc.p.x < PotionGeometry.C.x ? -1 : 1
                    pc.v = CGVector(dx: side * rand(60, 140), dy: -abs(pc.v.dy) * 0.3)
                    pc.p.x += side * 4
                    cue(.tink, gap: 0.1)
                }
                if pc.p.y > PotionGeometry.tableY - 6 {
                    pc.p.y = PotionGeometry.tableY - 6
                    pc.state = .table
                    pc.v = .zero
                    pc.age = 0
                    cue(.tink, gap: 0.1)
                }
                if pc.p.y > 900 { continue }
            case .liquid:
                stepPieceInLiquid(&pc, d)
                if pc.dissolve >= 1 {
                    doses[pc.kind, default: 0] += 1
                    continue
                }
            case .table:
                if pc.age > 7 { continue }
            }
            if pc.kind == .hair {
                pc.trail.insert(pc.p, at: 0)
                if pc.trail.count > 14 { pc.trail.removeLast() }
            }
            keep.append(pc)
        }
        pieces = keep
    }

    private func stepPieceInLiquid(_ pc: inout PPiece, _ d: CGFloat) {
        let fl = flow(pc.p)
        // floats (petals, frost, lavender), sinks slowly (stars, hair), or sinks (berries)
        let buoy: CGFloat
        switch pc.kind {
        case .petals, .lavender: buoy = -260
        case .frost: buoy = -200
        case .berries: buoy = 220
        case .stars: buoy = 90
        default: buoy = 40
        }
        pc.v.dx += (fl.dx - pc.v.dx) * min(1, d * 4)
        pc.v.dy += (fl.dy - pc.v.dy) * min(1, d * 4) + buoy * d
        pc.v.dy = max(-120, min(140, pc.v.dy))
        pc.p.x += pc.v.dx * d
        pc.p.y += pc.v.dy * d
        let surf = surfaceY(pc.p.x)
        if pc.p.y < surf + 3 {
            pc.p.y = surf + 3
            pc.v.dy = max(0, pc.v.dy)
        }
        if !PotionGeometry.inside(pc.p, pad: 6) {
            // back inside, sliding along the glass
            let c = CGPoint(x: PotionGeometry.C.x, y: min(PotionGeometry.C.y, max(level + 10, pc.p.y)))
            for _ in 0..<12 {
                pc.p = CGPoint(x: pc.p.x + (c.x - pc.p.x) * 0.1, y: pc.p.y + (c.y - pc.p.y) * 0.1)
                if PotionGeometry.inside(pc.p, pad: 6) { break }
            }
            pc.v.dx *= -0.3
            pc.v.dy *= 0.5
        }
        // dissolving: faster when hot or stirred
        let base: CGFloat
        switch pc.kind {
        case .stars: base = 0.25
        case .petals: base = 0.12
        case .berries: base = 0.05
        case .frost: base = 0.45
        case .hair: base = 0.16
        default: base = 0.14
        }
        let rate = base * (1 + temp * 1.6 + min(1.5, stirSpeed / 500))
        let dd = rate * d
        pc.dissolve = min(1, pc.dissolve + dd)
        let amount = Float(dd) * 6
        switch pc.kind {
        case .stars:
            inject(pc.p, color: PIngredient.stars.color, amount: amount * 0.8)
            if rand() < d * 22 { bubbles.append(PBubble(p: pc.p, r: rand(1, 2.4), phase: rand(0, 6), fizzy: true)) }
            if rand() < d * 26 { addGlitter(at: pc.p, color: RGB(hex: "#FFE27A"), size: rand(1.4, 2.6)) }
            if rand() < d * 2 { cue(.fizz, gap: 0.5) }
        case .petals:
            inject(pc.p, color: PIngredient.petals.color, amount: amount * 0.7)
        case .berries:
            if pc.age > pc.burstAt {
                // pop! a burst of bubbles and blue
                pc.dissolve = 1
                inject(pc.p, color: PIngredient.berries.color, amount: 6, radius: 2.2)
                for _ in 0..<18 { bubbles.append(PBubble(p: CGPoint(x: pc.p.x + rand(-10, 10), y: pc.p.y + rand(-10, 10)), r: rand(1.5, 5), phase: rand(0, 6), fizzy: true)) }
                push(pc.p, CGVector(dx: 0, dy: -80), radius: 30)
                cue(.bloop)
                cue(.fizz, gap: 0.4)
            }
        case .frost:
            inject(pc.p, color: PIngredient.frost.color, amount: amount * 0.5)
            temp = max(0, temp - dd * 0.35)
            if rand() < d * 10 {
                motes.append(PMote(p: CGPoint(x: PotionGeometry.C.x + rand(-60, 60), y: max(PotionGeometry.rimY, surfaceY(pc.p.x)) - 6), v: CGVector(dx: rand(-20, 20), dy: rand(-30, -8)),
                                   max: rand(2.5, 4), kind: .fog, color: RGB(0.9, 0.97, 1), size: rand(18, 30)))
            }
            if rand() < d * 3 { cue(.frost, gap: 0.6) }
        case .hair:
            let hue = (CGFloat(time) * 0.35 + CGFloat(pc.seed) * 0.1).truncatingRemainder(dividingBy: 1)
            inject(pc.p, color: PotionSim.hue(hue), amount: amount * 0.9)
            if rand() < d * 16 { addGlitter(at: pc.p, color: PotionSim.hue(hue).mix(RGB(1, 1, 1), 0.3), size: rand(1.4, 2.4)) }
        case .lavender:
            inject(pc.p, color: PIngredient.lavender.color, amount: amount * 0.6)
            if rand() < d * 1.5 {
                motes.append(PMote(p: CGPoint(x: pc.p.x, y: PotionGeometry.rimY - 10), v: CGVector(dx: rand(-10, 10), dy: -30), max: 2.2, kind: .zz,
                                   color: RGB(hex: "#B9A0FF"), size: 14))
            }
        default:
            break
        }
    }

    static func hue(_ h: CGFloat) -> RGB {
        let x = Double(h.truncatingRemainder(dividingBy: 1)) * 6
        let i = Int(x) % 6, f = x - Double(Int(x))
        let q = 1 - f
        let base: RGB
        switch i {
        case 0: base = RGB(1, f, 0)
        case 1: base = RGB(q, 1, 0)
        case 2: base = RGB(0, 1, f)
        case 3: base = RGB(0, q, 1)
        case 4: base = RGB(f, 0, 1)
        default: base = RGB(1, 0, q)
        }
        // soft, candy rainbow
        return base.mix(RGB(1, 1, 1), 0.28)
    }

    // MARK: - Bubbles, glitter, foam

    private func addGlitter(at p: CGPoint, color: RGB, size: CGFloat) {
        if glitter.count > 520 { glitter.removeFirst(glitter.count - 520) }
        glitter.append(PGlitter(p: p, color: color, size: size, phase: rand(0, 6.28)))
    }

    private func stepBubbles(_ d: CGFloat) {
        var keep: [PBubble] = []
        keep.reserveCapacity(bubbles.count)
        for b0 in bubbles {
            var b = b0
            b.phase += d * 9
            let fl = flow(b.p)
            let rise = 40 + b.r * 16
            b.p.x += (fl.dx * 0.6 + sin(b.phase) * b.r * 3) * d
            b.p.y += (fl.dy * 0.4 - rise) * d
            if let k = cellIndex(b.p), liquid[k] { v[k] -= Float(b.r * 6 * d * 60) * 0.04 }
            if !PotionGeometry.inside(b.p, pad: b.r) {
                b.p.x += (PotionGeometry.C.x - b.p.x) * 0.08
            }
            let surf = surfaceY(b.p.x)
            if b.p.y <= surf + b.r * 0.5 {
                // pop at the top
                let col = Int((b.p.x - PotionGeometry.gx0) / PotionGeometry.cell)
                if col >= 0 && col < PotionSim.NX {
                    waveV[col] -= b.r * 0.05
                    if b.fizzy || boiling > 0.6 && (doses[.berries] ?? 0) + (doses[.mermaid] ?? 0) > 1 { foam[col] = min(70, foam[col] + b.r * 1.4) }
                }
                if b.r > 3 && rand() < 0.4 { cue(.pop, gap: 0.05) }
                if b.fizzy && rand() < 0.12 {
                    motes.append(PMote(p: CGPoint(x: b.p.x, y: surf - 4), v: CGVector(dx: rand(-30, 30), dy: rand(-90, -40)), max: rand(0.4, 0.8),
                                       kind: .sparkle, color: RGB(1, 1, 1), size: rand(4, 8)))
                }
                continue
            }
            keep.append(b)
        }
        bubbles = keep
        if bubbles.count > 360 { bubbles.removeFirst(bubbles.count - 360) }
        // fizzing makes a fizzy sound
        let fizzy = bubbles.filter { $0.fizzy }.count
        fizzLevel += (min(1, CGFloat(fizzy) / 40) - fizzLevel) * min(1, d * 4)
    }
    var fizzLevel: CGFloat = 0

    private func stepGlitter(_ d: CGFloat) {
        guard !glitter.isEmpty else { return }
        let bottom = PotionGeometry.bottomY
        for i in glitter.indices {
            var g = glitter[i]
            g.phase += d * 3
            let fl = flow(g.p)
            g.p.x += fl.dx * d
            g.p.y += (fl.dy + 9) * d
            if !PotionGeometry.inside(g.p, pad: 3) {
                // settle on the bottom / slide back in
                let c = CGPoint(x: PotionGeometry.C.x, y: min(PotionGeometry.C.y, g.p.y))
                g.p = CGPoint(x: g.p.x + (c.x - g.p.x) * 0.05, y: min(bottom - 4, g.p.y + (c.y - g.p.y) * 0.05))
            }
            let s = surfaceY(g.p.x) + 3
            if g.p.y < s { g.p.y = s }
            glitter[i] = g
        }
    }

    // MARK: - Motes (steam, fog, sparkles...)

    private func stepMotes(_ d: CGFloat) {
        var keep: [PMote] = []
        keep.reserveCapacity(motes.count)
        for m0 in motes {
            var m = m0
            m.life += d
            if m.life >= m.max { continue }
            switch m.kind {
            case .steam:
                m.v.dy -= 10 * d
                m.v.dx += sin(CGFloat(time) * 2 + m.p.y * 0.05) * 20 * d
                m.size += d * 16
            case .fog:
                // cold fog is heavy: it spills over the rim and rolls down the glass to the table
                m.v.dy += 30 * d
                m.size += d * 10
                if PotionGeometry.insideOuter(m.p, pad: 4) && m.p.y > PotionGeometry.rimY {
                    let side: CGFloat = m.p.x < PotionGeometry.C.x ? -1 : 1
                    m.v.dx += side * 60 * d
                    if PotionGeometry.inside(m.p) { m.v.dy = min(m.v.dy, -4) }
                }
                if m.p.y > PotionGeometry.tableY - 10 { m.p.y = PotionGeometry.tableY - 10; m.v.dy = 0; m.v.dx *= 1 - d }
            case .sparkle:
                m.v.dy += 60 * d
                m.v.dx *= 1 - d * 1.5
            case .smoke:
                m.v.dy -= 20 * d
                m.size += d * 30
            case .heart:
                m.v.dx = sin(CGFloat(time) * 3 + m.spin) * 30
            case .snow:
                m.v.dx = sin(CGFloat(time) * 2 + m.spin) * 16
            case .soap:
                m.v.dx = sin(CGFloat(time) * 1.4 + m.spin) * 20
                m.v.dy = max(-40, m.v.dy - 4 * d)
            case .zz:
                m.v.dx = sin(CGFloat(time) * 2 + m.spin) * 14
            case .flash:
                m.size += d * 500
            case .drip:
                m.v.dy += 800 * d
                if m.p.y > PotionGeometry.tableY { continue }
            }
            m.p.x += m.v.dx * d
            m.p.y += m.v.dy * d
            keep.append(m)
        }
        motes = keep
        if motes.count > 320 { motes.removeFirst(motes.count - 320) }
    }

    // MARK: - Waves and foam

    private func stepWaves(_ d: CGFloat) {
        let NX = PotionSim.NX
        let hwid = PotionGeometry.halfWidth(at: level)
        var active = [Bool](repeating: false, count: NX)
        var sum: CGFloat = 0
        var n: CGFloat = 0
        for i in 0..<NX {
            let x = PotionGeometry.gx0 + (CGFloat(i) + 0.5) * PotionGeometry.cell
            active[i] = abs(x - PotionGeometry.C.x) < hwid - 2 && volume > 1
            if active[i] { sum += waveH[i]; n += 1 }
        }
        let mean = n > 0 ? sum / n : 0
        let k = d * 60
        let boil = boiling
        for i in 0..<NX {
            guard active[i] else { waveH[i] = 0; waveV[i] = 0; foam[i] *= 0.9; continue }
            let l = i > 0 && active[i - 1] ? waveH[i - 1] : waveH[i]
            let r = i < NX - 1 && active[i + 1] ? waveH[i + 1] : waveH[i]
            waveV[i] += (0.3 * (l + r - 2 * waveH[i]) - 0.004 * (waveH[i] - mean)) * k
            waveV[i] *= pow(0.982, k)
            if boil > 0 && rand() < boil * d * 8 { waveV[i] += rand(-0.6, 0.6) * boil }
        }
        for i in 0..<NX where active[i] {
            waveH[i] += waveV[i] * k
            waveH[i] = max(-30, min(30, waveH[i] - mean * 0.02))
        }
        // foam: spreads out, slowly fades, and runs over the rim if it piles up too high
        var f2 = foam
        for i in 0..<NX where active[i] {
            let l = i > 0 && active[i - 1] ? foam[i - 1] : foam[i]
            let r = i < NX - 1 && active[i + 1] ? foam[i + 1] : foam[i]
            f2[i] = foam[i] + 0.06 * (l + r - 2 * foam[i]) * k
            f2[i] *= pow(0.9975, k)
            let top = level + waveH[i] - f2[i]
            if top < PotionGeometry.rimY - 6 && f2[i] > 4 {
                let spill = min(f2[i] * 0.3, 3 * k)
                f2[i] -= spill
                if rand() < 0.3 {
                    let side: CGFloat = i < NX / 2 ? -1 : 1
                    let (c, _) = meanColor()
                    motes.append(PMote(p: CGPoint(x: PotionGeometry.C.x + side * (PotionGeometry.hw + PotionGeometry.glass), y: PotionGeometry.rimY - 4), v: CGVector(dx: side * 20, dy: 20),
                                       max: 3, kind: .drip, color: RGB(1, 1, 1).mix(c, 0.35), size: rand(8, 14)))
                    cue(.fizz, gap: 0.6)
                }
            }
        }
        foam = f2
        // a fizzy potion sends little soap bubbles floating up
        let foamTotal = foam.reduce(0, +)
        if foamTotal > 300 && rand() < d * min(6, foamTotal / 300) {
            let x = PotionGeometry.C.x + rand(-60, 60)
            motes.append(PMote(p: CGPoint(x: x, y: surfaceY(x) - 30), v: CGVector(dx: rand(-20, 20), dy: rand(-50, -25)), max: rand(3, 5), kind: .soap,
                               color: RGB(1, 1, 1), size: rand(8, 16), spin: rand(0, 6)))
        }
    }

    // MARK: - Flyers

    private func stepFlyers(_ d: CGFloat) {
        var keep: [PFlyer] = []
        for f0 in flyers {
            var f = f0
            f.t += d / 0.55
            if f.t >= 1 {
                cue(.clink, gap: 0.1)
                continue
            }
            keep.append(f)
        }
        flyers = keep
    }

    static func flyerPos(_ f: PFlyer) -> (CGPoint, CGFloat) {
        let e = f.t * f.t * (3 - 2 * f.t)
        let p = CGPoint(x: f.from.x + (f.to.x - f.from.x) * e, y: f.from.y + (f.to.y - f.from.y) * e - 90 * sin(e * .pi))
        return (p, f.spin * (1 - e))
    }

    // MARK: - The unicorn

    private func unicornGets(_ dp: PDrop) {
        uni.gotVol += max(dp.vol, 30)
        uni.lastHit = CGFloat(time)
        uni.gotColor = uni.gotVol < 60 ? dp.color : uni.gotColor.mix(dp.color, 0.08)
        if let i = dp.potion, let b = rack[safe: i] {
            uni.gotKind = b.potion
            for (m, x) in b.magic { if let mm = PMagic(rawValue: m) { uni.got[mm, default: 0] += CGFloat(x) * dp.vol } }
            if let k = b.potion { uni.got[k.magic, default: 0] += dp.vol * 2 }
            uni.gotColor = b.color
        } else if let ing = dp.ing {
            if let m = ing.magic { uni.got[m, default: 0] += dp.vol } else { uni.wet += dp.vol / 2500 }
        }
        if rand() < 0.3 { cue(.drip, gap: 0.15) }
        // drops run off her
        if rand() < 0.2 {
            motes.append(PMote(p: CGPoint(x: dp.p.x + rand(-20, 20), y: dp.p.y + 20), v: CGVector(dx: rand(-40, 40), dy: 40), max: 1.2, kind: .drip,
                               color: dp.color, size: rand(5, 8)))
        }
    }

    /// The potion on her starts working once she's had a good splash.
    private func applyToUnicorn() {
        let total = uni.got.values.reduce(0, +)
        let c = uni.gotColor
        if uni.gotKind != nil || total > 400 {
            uni.tint = uni.tintAmt > 0.05 ? uni.tint.mix(c, 0.6) : c
            uni.tintAmt = min(0.85, uni.tintAmt + 0.6)
        }
        let best = uni.got.sorted { $0.value > $1.value }
        for (m, x) in best.prefix(2) where x > total * 0.25 || uni.gotKind != nil {
            switch m {
            case .love:
                uni.love = 9
                cue(.heart)
            case .bubble:
                if uni.float <= 0 { uni.floatV = -20 }
                uni.float = 8
                cue(.boing)
                if !demo { StickerBook.shared.find(game: PotionSim.gameID, id: "floatingUnicorn") }
            case .fire:
                uni.hiccup = 7
                uni.hicAt = 0.4
            case .glow:
                uni.glow = 14
                cue(.chime)
            case .sparkle:
                uni.glitter = 18
                cue(.chime)
            case .frost:
                uni.frost = 8
                cue(.frost)
            case .rainbow:
                uni.rainbow = 20
                cue(.magic)
                if !demo { StickerBook.shared.find(game: PotionSim.gameID, id: "rainbowUnicorn") }
            case .sleepy:
                uni.sleepy = 9
            }
        }
        if uni.gotKind == .golden { uni.glitter = 18; uni.glow = 12 }
        if uni.gotKind == .galaxy { uni.glow = 10 }
        uni.got = [:]
        uni.gotKind = nil
        uni.gotVol = 0
        uni.hop = 0.01
        uni.hopV = -260
        sparkleBurst(at: CGPoint(x: PotionGeometry.unicornBox.midX, y: PotionGeometry.unicornBox.minY + 40), color: c, n: 10)
        cue(.poof)
    }

    func tapUnicorn() {
        guard uni.hop == 0 else { return }
        uni.hop = 0.01
        uni.hopV = -300
        uni.giggle = 1.2
        cue(.boing)
        if uni.sleepy > 0 { uni.sleepy = 0 }
        for k in 0..<3 {
            motes.append(PMote(p: CGPoint(x: PotionGeometry.unicornBox.midX + rand(-30, 30), y: PotionGeometry.unicornBox.minY + 30), v: CGVector(dx: rand(-20, 20), dy: -60 - CGFloat(k) * 10),
                               max: 1.6, kind: .heart, color: RGB(hex: "#FF7FB0"), size: 14, spin: rand(0, 6)))
        }
    }

    private func stepUnicorn(_ d: CGFloat) {
        if uni.gotVol > 0 && CGFloat(time) - uni.lastHit > 0.45 {
            if uni.gotVol > 500 || uni.gotKind != nil { applyToUnicorn() } else { uni.got = [:]; uni.gotVol = 0 }
        }
        // water: she shakes it off
        if uni.wet > 0.6 && uni.shake <= 0 && CGFloat(time) - uni.lastHit > 0.4 {
            uni.shake = 1.1
            uni.wet = 0
            uni.tintAmt *= 0.5
            cue(.shakeOff)
            for _ in 0..<16 {
                let a = rand(0, 6.28)
                motes.append(PMote(p: CGPoint(x: PotionGeometry.unicornBox.midX + cos(a) * 60, y: PotionGeometry.unicornBox.midY + sin(a) * 50), v: CGVector(dx: cos(a) * 220, dy: sin(a) * 120 - 80),
                                   max: 1, kind: .drip, color: PIngredient.water.color, size: rand(4, 7)))
            }
        }
        uni.shake = max(0, uni.shake - d)
        uni.tintAmt = max(0, uni.tintAmt - d * 0.012)
        uni.rainbow = max(0, uni.rainbow - d)
        uni.glitter = max(0, uni.glitter - d)
        uni.glow = max(0, uni.glow - d)
        uni.love = max(0, uni.love - d)
        uni.frost = max(0, uni.frost - d)
        uni.sleepy = max(0, uni.sleepy - d)
        uni.giggle = max(0, uni.giggle - d)
        uni.blink -= d
        if uni.blink < -0.14 { uni.blink = rand(2, 5) }
        // floating in a bubble
        if uni.float > 0 {
            uni.float -= d
            let target: CGFloat = -130 + sin(CGFloat(time) * 1.6) * 12
            uni.floatV += (target - uni.floatY) * 4 * d
            uni.floatV *= 1 - d * 1.5
            uni.floatY += uni.floatV * d
            if uni.float <= 0 {
                cue(.pop)
                sparkleBurst(at: CGPoint(x: PotionGeometry.unicornBox.midX, y: PotionGeometry.unicornBox.midY + uni.floatY), color: RGB(0.8, 0.95, 1), n: 10)
            }
        } else if uni.floatY < 0 {
            uni.floatV += 1400 * d
            uni.floatY += uni.floatV * d
            if uni.floatY >= 0 { uni.floatY = 0; uni.floatV = 0; uni.hop = 0.01; uni.hopV = -120; cue(.boing) }
        }
        // hops
        if uni.hop != 0 {
            uni.hopV += 1600 * d
            uni.hop += uni.hopV * d
            if uni.hop >= 0 { uni.hop = 0; uni.hopV = 0 }
        }
        // hiccups: a little jump and a puff of warm smoke
        if uni.hiccup > 0 {
            uni.hiccup -= d
            uni.hicAt -= d
            if uni.hicAt <= 0 {
                uni.hicAt = rand(0.9, 1.5)
                uni.hicKick = 1
                uni.hop = 0.01
                uni.hopV = -170
                cue(.hiccup)
                let mouth = unicornMouth
                for k in 0..<4 {
                    motes.append(PMote(p: mouth, v: CGVector(dx: 70 + CGFloat(k) * 14, dy: -50 - CGFloat(k) * 12), max: 1.3, kind: .smoke,
                                       color: k % 2 == 0 ? RGB(hex: "#FFB37A") : RGB(hex: "#FF8AA8"), size: 10))
                }
            }
        }
        uni.hicKick = max(0, uni.hicKick - d * 4)
        if uni.love > 0 && rand() < d * 2.4 {
            motes.append(PMote(p: CGPoint(x: PotionGeometry.unicornBox.midX + rand(-50, 50), y: PotionGeometry.unicornBox.minY + 40 + uni.floatY), v: CGVector(dx: 0, dy: -50),
                               max: 2, kind: .heart, color: RGB(hex: "#FF6FA6"), size: rand(12, 18), spin: rand(0, 6)))
            cue(.heart, gap: 1.6)
        }
        if uni.frost > 0 && rand() < d * 6 {
            motes.append(PMote(p: CGPoint(x: PotionGeometry.unicornBox.midX + rand(-80, 80), y: PotionGeometry.unicornBox.minY - 10), v: CGVector(dx: 0, dy: 40),
                               max: 2.4, kind: .snow, color: RGB(1, 1, 1), size: rand(6, 11), spin: rand(0, 6)))
        }
        if uni.sleepy > 0 && rand() < d * 0.9 {
            motes.append(PMote(p: CGPoint(x: unicornMouth.x + 30, y: unicornMouth.y - 60), v: CGVector(dx: 10, dy: -30), max: 2.4, kind: .zz,
                               color: RGB(hex: "#9C86FF"), size: rand(14, 20), spin: rand(0, 6)))
            cue(.yawn, gap: 3)
        }
        // she watches what's going on
        var target = CGPoint(x: PotionGeometry.C.x, y: level + 40)
        if held != nil { target = held == .spoon ? spoon : heldPos }
        uni.look = CGPoint(x: uni.look.x + (target.x - uni.look.x) * min(1, d * 4), y: uni.look.y + (target.y - uni.look.y) * min(1, d * 4))
    }

    var unicornMouth: CGPoint {
        CGPoint(x: PotionGeometry.unicornFeet.x + 40, y: PotionGeometry.unicornFeet.y - 150 + uni.floatY + uni.hop)
    }

    // MARK: - Rare potions

    var flaskGlow: CGFloat {
        if let r = rare { return r.glow * min(1, turn + 0.3) }
        let moonGlow: CGFloat = (doses[.moon] ?? 0) * 0.35
        let dragonGlow: CGFloat = (doses[.dragon] ?? 0) * 0.18
        let starGlow: CGFloat = (doses[.stars] ?? 0) * 0.08
        return min(0.9, (moonGlow + dragonGlow + starGlow) * 0.5)
    }

    func has(_ i: PIngredient) -> Bool { (doses[i] ?? 0) >= i.need }

    /// Which rare potion the flask holds, if any. The more particular combos come first.
    func rareKind() -> PotionKind? {
        guard volume > 2000 else { return nil }
        let distinct = PIngredient.allCases.filter { $0 != .water && has($0) }.count
        if distinct >= 7 { return .wild }
        let liquids: [PIngredient] = [.nectar, .mermaid, .dragon, .moon, .night]
        if has(.hair) && liquids.filter({ has($0) }).count >= 3 { return .rainbow }
        if has(.stars) && has(.dragon) && has(.moon) { return .golden }
        if has(.night) && has(.stars) { return .galaxy }
        if has(.dragon) && boilTime > 2.5 { return .dragon }
        if has(.lavender) && has(.moon) { return .dream }
        if has(.moon) && night > 0.7 { return .moonlight }
        if has(.frost) && (has(.mermaid) || has(.moon)) { return .frost }
        if has(.nectar) && has(.petals) { return .love }
        if has(.mermaid) && has(.berries) { return .mermaid }
        return nil
    }

    private func stepRare(_ d: CGFloat) {
        if time > rareCheckAt {
            rareCheckAt = time + 0.4
            let k = rareKind()
            if k != rare {
                rare = k
                turn = 0
                if k != nil {
                    // the magic moment: it flashes and starts turning its new color
                    flash = 1
                    cue(.magic)
                    motes.append(PMote(p: CGPoint(x: PotionGeometry.C.x, y: max(level, PotionGeometry.joinY) + 60), v: .zero, max: 0.6, kind: .flash,
                                       color: k!.color.mix(RGB(1, 1, 1), 0.4), size: 40))
                    sparkleBurst(at: CGPoint(x: PotionGeometry.C.x, y: PotionGeometry.rimY - 20), color: k!.color, n: 16)
                }
            }
        }
        guard let k = rare, volume > 1 else { return }
        turn = min(1, turn + d / 2.4)
        let NX = PotionSim.NX
        let rate = Float(min(1, d * 1.2))
        for j in 0..<PotionSim.NY {
            for i in 0..<NX {
                let c = j * NX + i
                guard liquid[c] else { continue }
                var want = k.color
                if k == .rainbow {
                    // rainbow bands, top to bottom, that come back however much she stirs
                    want = PotionSim.hue(CGFloat(j) / CGFloat(PotionSim.NY) * 1.4 + 0.02 * CGFloat(i))
                } else if k == .wild {
                    want = PotionSim.hue(CGFloat(time) * 0.12 + CGFloat(i + j) * 0.012)
                } else if k == .galaxy {
                    want = k.color.mix(RGB(hex: "#C43FD6"), Double(0.5 + 0.5 * sin(Float(i) * 0.4 + Float(j) * 0.3 + Float(time) * 0.6)))
                }
                let a = max(da[c], 0.9)
                dr[c] += (Float(want.r) * a - dr[c]) * rate
                dg[c] += (Float(want.g) * a - dg[c]) * rate
                db[c] += (Float(want.b) * a - db[c]) * rate
                da[c] += (a - da[c]) * rate
            }
        }
        // its special touch
        switch k {
        case .galaxy, .golden:
            if glitter.count < 260 && rand() < d * 30 {
                let x = PotionGeometry.C.x + rand(-120, 120)
                addGlitter(at: CGPoint(x: x, y: rand(max(level, PotionGeometry.rimY) + 10, PotionGeometry.bottomY - 20)), color: k == .golden ? RGB(hex: "#FFE38A") : RGB(1, 1, 1), size: rand(1.4, 2.8))
            }
        case .love:
            if rand() < d * 1.6 {
                motes.append(PMote(p: CGPoint(x: PotionGeometry.C.x + rand(-50, 50), y: PotionGeometry.rimY - 10), v: CGVector(dx: 0, dy: -46), max: 2.4, kind: .heart,
                                   color: RGB(hex: "#FF6FA6"), size: rand(12, 18), spin: rand(0, 6)))
            }
        case .frost:
            if rand() < d * 4 {
                motes.append(PMote(p: CGPoint(x: PotionGeometry.C.x + rand(-60, 60), y: PotionGeometry.rimY - 4), v: CGVector(dx: rand(-20, 20), dy: rand(-20, 0)), max: rand(2.5, 4),
                                   kind: .fog, color: RGB(0.92, 0.98, 1), size: rand(18, 28)))
            }
        case .mermaid:
            if rand() < d * 5 {
                bubbles.append(PBubble(p: CGPoint(x: PotionGeometry.C.x + rand(-100, 100), y: PotionGeometry.bottomY - 20), r: rand(2, 5), phase: rand(0, 6), fizzy: true))
            }
        case .dragon:
            if rand() < d * 3 {
                motes.append(PMote(p: CGPoint(x: PotionGeometry.C.x + rand(-40, 40), y: PotionGeometry.rimY - 6), v: CGVector(dx: rand(-20, 20), dy: -70), max: 1.6, kind: .sparkle,
                                   color: RGB(hex: "#FFB347"), size: rand(6, 10)))
            }
        case .dream:
            if rand() < d * 0.8 {
                motes.append(PMote(p: CGPoint(x: PotionGeometry.C.x + rand(-40, 40), y: PotionGeometry.rimY - 10), v: CGVector(dx: 8, dy: -30), max: 2.6, kind: .zz,
                                   color: RGB(hex: "#B9A0FF"), size: rand(14, 20), spin: rand(0, 6)))
            }
        case .wild:
            if rand() < d * 6 {
                bubbles.append(PBubble(p: CGPoint(x: PotionGeometry.C.x + rand(-100, 100), y: PotionGeometry.bottomY - 20), r: rand(2, 6), phase: rand(0, 6), fizzy: true))
            }
        default:
            break
        }
    }

    /// A rare potion she hasn't found yet, for the hint card (or any, once she has them all).
    func hint(after last: PotionKind?) -> PotionKind {
        let all = PotionKind.allCases
        let missing = all.filter { !StickerBook.shared.has(game: PotionSim.gameID, id: $0.rawValue) }
        let pool = missing.isEmpty ? all : missing
        if let l = last, let i = pool.firstIndex(of: l) { return pool[(i + 1) % pool.count] }
        return pool[0]
    }
}
