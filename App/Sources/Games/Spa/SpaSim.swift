import SwiftUI

// MARK: - The bath, simulated
//
// The tub is a clear glass bath seen from the side, so everything that happens in the water shows.
//
// Water: how deep it is (`vol`, in points) plus a wave on top: one height and speed per 5 pt column (`h`, `hv`)
// stepped with the wave equation at 120 Hz. The waves travel faster in deep water, bounce off the glass ends and die
// away slowly. The tap pours a falling stream that churns the surface where it lands; pulling the plug drains it with a
// swirl over the plug hole.
//
// Foam: a thickness per column (`foam`) with its own color (`foamTint`). Bubble bath soap in the water only foams when
// the water is churned (the tap's stream, her hand, a fizzing bath bomb), the way real bubble bath does. Thick foam
// slumps sideways, breathes out the odd soap bubble and slowly fades.
//
// Things (`SThing`: toys and bath bombs) float by buoyancy: the deeper part of them under the surface pushes them up,
// so a light duck rides high and a bath bomb sinks and then bobs up as it starts to fizz. The surface's slope tips and
// pushes them, they push the water back, and whatever falls in fast throws up a splash. Drops, soap bubbles, underwater
// air bubbles, bath-bomb color clouds, glitter and steam are particles.
//
// Her: the Dress Up girl (her current look) sits on the tub's seat. A face mask is painted on a grid over her face and
// dries (lighter, then cracking); cucumber slices close her eyes; drops and suds sit on her until the towel takes them.
// The mirror steams up while the bath is warm and her finger wipes it clear.

enum SGeo {
    /// The inside of the tub.
    static let tubL: CGFloat = 96
    static let tubR: CGFloat = 836
    static let tubBottom: CGFloat = 768
    /// The glass lip along the top of the tub.
    static let lipY: CGFloat = 512
    /// The water stops here (an overflow drain keeps it from spilling).
    static let fullY: CGFloat = 528
    static var maxDepth: CGFloat { tubBottom - fullY }
    static let columns = 148
    static let colW: CGFloat = 5
    /// The bathroom floor in front of the tub.
    static let floorY: CGFloat = 812
    static let spout = CGPoint(x: 786, y: 420)
    static let handle = CGPoint(x: 744, y: 334)
    static let plugRing = CGPoint(x: 812, y: 506)
    static let drain = CGPoint(x: 772, y: 766)
    static let seat = CGRect(x: 196, y: 660, width: 268, height: 108)
    static let mirror = CGRect(x: 478, y: 78, width: 210, height: 230)
    static let fogCols = 21
    static let fogRows = 23

    // Her: the Dress Up doll (600 x 900 art) scaled down, shoulders just under the full water line.
    static let dollScale: CGFloat = 0.78
    static let dollOrigin = CGPoint(x: 330 - 300 * 0.78, y: 536 - 470 * 0.78)
    /// Her body, where floating things bump into her (design space).
    static let bodyL: CGFloat = 250
    static let bodyR: CGFloat = 410
    static let chinY: CGFloat = 500

    // Her face, in doll coordinates.
    static let headC = CGPoint(x: 300, y: 290)
    static let headRX: CGFloat = 140
    static let headRY: CGFloat = 134
    static let eyes = [CGPoint(x: 246, y: 334), CGPoint(x: 354, y: 334)]
    static let mouth = CGPoint(x: 300, y: 389)
    /// The face mask grid over her face (doll coordinates).
    static let maskRect = CGRect(x: 158, y: 196, width: 284, height: 232)
    static let maskCols = 20
    static let maskRows = 16

    static func colX(_ i: Int) -> CGFloat { tubL + (CGFloat(i) + 0.5) * colW }
    static func col(_ x: CGFloat) -> Int { max(0, min(columns - 1, Int((x - tubL) / colW))) }
    static func toDoll(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - dollOrigin.x) / dollScale, y: (p.y - dollOrigin.y) / dollScale)
    }
    static func fromDoll(_ d: CGPoint) -> CGPoint {
        CGPoint(x: dollOrigin.x + d.x * dollScale, y: dollOrigin.y + d.y * dollScale)
    }
    /// Inside her head (doll coordinates), grown by `pad`.
    static func inHead(_ d: CGPoint, pad: CGFloat = 0) -> Bool {
        let x = (d.x - headC.x) / (headRX + pad), y = (d.y - headC.y) / (headRY + pad)
        return x * x + y * y < 1
    }
    /// On her face or her shoulders, where a sponge, towel or drop can touch her (doll coordinates).
    static func onHer(_ d: CGPoint, pad: CGFloat = 0) -> Bool {
        if inHead(d, pad: pad) { return true }
        return d.x > 196 - pad && d.x < 404 + pad && d.y > 400 && d.y < 560
    }
    static var inside: CGRect { CGRect(x: tubL, y: lipY, width: tubR - tubL, height: tubBottom - lipY) }
}

// MARK: Kinds

enum ToyKind: String, CaseIterable {
    case duck, duckling, boat, whale, turtle, cucumber

    static var tray: [ToyKind] { [.duck, .duckling, .boat, .whale, .turtle] }

    var half: CGSize {
        switch self {
        case .duck: return CGSize(width: 44, height: 38)
        case .duckling: return CGSize(width: 30, height: 26)
        case .boat: return CGSize(width: 50, height: 46)
        case .whale: return CGSize(width: 54, height: 34)
        case .turtle: return CGSize(width: 44, height: 24)
        case .cucumber: return CGSize(width: 22, height: 8)
        }
    }

    /// The part of it that sits under water when floating still (over 1 sinks).
    var density: CGFloat {
        switch self {
        case .duck, .duckling: return 0.42
        case .boat: return 0.3
        case .whale: return 0.5
        case .turtle: return 0.62
        case .cucumber: return 0.7
        }
    }
}

enum BombKind: String, CaseIterable {
    case rose, lavender, ocean, sunshine, mint, rainbow

    var color: RGB {
        switch self {
        case .rose: return RGB(hex: "#FF7FB0")
        case .lavender: return RGB(hex: "#B497FF")
        case .ocean: return RGB(hex: "#5EC2FF")
        case .sunshine: return RGB(hex: "#FFC93C")
        case .mint: return RGB(hex: "#5FD9A8")
        case .rainbow: return RGB(hex: "#FF8FB8")
        }
    }

    var glitter: Bool { self == .sunshine || self == .rainbow || self == .lavender }

    /// The color it fizzes out right now (the rainbow one goes round the rainbow).
    func dye(_ t: Double) -> RGB {
        guard self == .rainbow else { return color }
        let hues = ["#FF6F91", "#FFB347", "#FFE066", "#6EE7A0", "#5EC2FF", "#B497FF"].map { RGB(hex: $0) }
        let u = (t * 0.45).truncatingRemainder(dividingBy: 1) * Double(hues.count)
        let i = Int(u) % hues.count
        return hues[i].mix(hues[(i + 1) % hues.count], u - floor(u))
    }
}

enum MaskKind: Int, CaseIterable {
    case clay, berry, glacier, honey

    var color: RGB {
        switch self {
        case .clay: return RGB(hex: "#9CCB86")
        case .berry: return RGB(hex: "#F7A1BE")
        case .glacier: return RGB(hex: "#A6D4F2")
        case .honey: return RGB(hex: "#F4CB6A")
        }
    }
}

enum SpaTool: Equatable {
    case soap, wand, sponge, shower, towel, mask(MaskKind), cucumber
}

enum ThingKind: Equatable {
    case toy(ToyKind)
    case bomb(BombKind)
}

// MARK: State

struct SThing {
    var id: Int
    var kind: ThingKind
    var p: CGPoint
    var v: CGVector = .zero
    var a: CGFloat = 0
    var av: CGFloat = 0
    var held = false
    var target: CGPoint = .zero
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    /// Bath bombs: how much is left (1 ... 0).
    var fizz: CGFloat = 1
    var wetFor: CGFloat = 0
    var wasIn = false
    var facing: CGFloat = 1
    var dive: CGFloat = 0

    var half: CGSize {
        switch kind {
        case .toy(let k): return k.half
        case .bomb: let r = 30 * (0.3 + 0.7 * sqrt(max(0, fizz))); return CGSize(width: r, height: r)
        }
    }

    var density: CGFloat {
        switch kind {
        case .toy(let k): return k == .turtle && dive > 0 ? 1.4 : k.density
        case .bomb: return wetFor > 0.5 ? 0.82 : 1.5
        }
    }

    var isBomb: Bool { if case .bomb = kind { return true } else { return false } }
}

enum DropKind { case water, soap, spray }

struct SDrop {
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var kind: DropKind = .water
    var age: CGFloat = 0
}

/// A bubble of air under water, rising.
struct SAir {
    var p: CGPoint
    var r: CGFloat
    var phase: CGFloat
    var vx: CGFloat = 0
}

/// A soap bubble in the air.
struct SBubble {
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var age: CGFloat = 0
    var life: CGFloat
    var phase: CGFloat
}

/// A billow of bath-bomb color spreading under water.
struct SPuff {
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var a: CGFloat
    var color: RGB
    var age: CGFloat = 0
}

struct SGlitter {
    var p: CGPoint
    var v: CGVector
    var color: RGB
    var phase: CGFloat
    var age: CGFloat = 0
    var settled = false
}

struct SPuddle {
    var x: CGFloat
    var r: CGFloat
    var a: CGFloat
}

struct SSteam {
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var age: CGFloat = 0
    var life: CGFloat
}

/// A popped bubble's ring, or a little burst of sparkles.
struct SPop {
    var p: CGPoint
    var r: CGFloat
    var age: CGFloat = 0
    var sparkle = false
}

/// A drop of water sitting on her skin (doll coordinates).
struct SBead {
    var d: CGPoint
    var r: CGFloat
    var vy: CGFloat = 0
}

/// A blob of suds on her hair or shoulders (doll coordinates).
struct SSud {
    var d: CGPoint
    var r: CGFloat
    var phase: CGFloat
}

enum HandMode: Equatable {
    case none, swish, wipe, girl, thing(Int), pop
}

final class SpaSim {
    static let gameID = "spa"

    var time: Double = 0
    private var last: Date?
    /// Screenshot hooks and tests: no sound.
    var quiet = false

    // water
    var vol: CGFloat = 0
    var h = [CGFloat](repeating: 0, count: SGeo.columns)
    var hv = [CGFloat](repeating: 0, count: SGeo.columns)
    var foam = [CGFloat](repeating: 0, count: SGeo.columns)
    var foamTint = [RGB](repeating: RGB(1, 1, 1), count: SGeo.columns)
    var tint = [RGB](repeating: RGB(1, 1, 1), count: SGeo.columns)
    var tintA = [CGFloat](repeating: 0, count: SGeo.columns)
    var soap: CGFloat = 0
    var tapOn = false
    var flow: CGFloat = 0
    var handleTurn: CGFloat = 0
    var plugOut = false
    var drainFlow: CGFloat = 0
    var warm: CGFloat = 0
    var fog = [CGFloat](repeating: 0, count: SGeo.fogCols * SGeo.fogRows)

    // particles
    var things: [SThing] = []
    var drops: [SDrop] = []
    var air: [SAir] = []
    var bubbles: [SBubble] = []
    var puffs: [SPuff] = []
    var glitter: [SGlitter] = []
    var puddles: [SPuddle] = []
    var steam: [SSteam] = []
    var pops: [SPop] = []
    private var nextID = 1

    // her
    var look: Look
    private(set) var layers: [Expression: [(ArtLayer, PaintSet, ArtItem)]] = [:]
    var maskCov = [CGFloat](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
    var maskKind = [Int](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
    var maskDry = [CGFloat](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
    var cucumbers = [false, false]
    var beads: [SBead] = []
    var suds: [SSud] = []
    var happyUntil: Double = 0
    var blinkAt: Double = 2
    var bob: CGFloat = 0
    var bobV: CGFloat = 0
    /// Was she wet or sudsy (so drying her off all the way gets a chime)?
    var neededDrying = false

    // what she is holding
    var tool: SpaTool?
    var toolP: CGPoint = .zero
    var toolTarget: CGPoint = .zero
    var toolFinger: CGPoint = .zero
    var toolV: CGVector = .zero
    var toolAngle: CGFloat = 0
    var wandFilm: CGFloat = 1
    var spongeWet: CGFloat = 0
    var spongeFoam: CGFloat = 0
    var towelWet: CGFloat = 0
    private var rubbing: CGFloat = 0
    private var emitCarry: CGFloat = 0

    // her bare finger
    var hand: HandMode = .none
    var handP: CGPoint = .zero
    var handV: CGVector = .zero
    private var swishSound: Double = 0

    init(look: Look? = nil) {
        let base = look ?? SpaSim.herLook()
        self.look = SpaSim.bathLook(base)
        for e in [Expression.normal, .blink, .happy] { layers[e] = DollPainter.layers(self.look, e) }
    }

    /// Her current Dress Up look (or the starter look).
    static func herLook() -> Look {
        (GameStorage.load(Look.self, game: LookStore.game, file: "current.json") ?? .starter).sanitized()
    }

    /// Just her: face, hair and makeup, no clothes or hats in the bath.
    static func bathLook(_ l: Look) -> Look {
        var b = l
        let keep: Set<String> = ["face", "eyes", "brows", "mouth", "nose", "cheeks", "makeup", "earrings", "hairBack", "hairFront"]
        b.picks = l.picks.filter { keep.contains($0.key) }
        b.pet = nil
        b.stickers = []
        return b
    }

    // MARK: Water queries

    var level: CGFloat { SGeo.tubBottom - vol }
    var hasWater: Bool { vol > 1.5 }
    var soapiness: CGFloat { vol > 4 ? min(1, soap / max(30, vol) * 120) : 0 }

    func surfaceY(_ x: CGFloat) -> CGFloat {
        let fx = (x - SGeo.tubL) / SGeo.colW - 0.5
        let i0 = max(0, min(SGeo.columns - 1, Int(floor(fx))))
        let i1 = min(SGeo.columns - 1, i0 + 1)
        let t = max(0, min(1, fx - CGFloat(i0)))
        return level + h[i0] * (1 - t) + h[i1] * t
    }

    func slope(_ x: CGFloat) -> CGFloat { (surfaceY(x + 7) - surfaceY(x - 7)) / 14 }

    func inTub(_ p: CGPoint) -> Bool { p.x > SGeo.tubL && p.x < SGeo.tubR && p.y > SGeo.lipY - 4 && p.y < SGeo.tubBottom + 2 }

    func underWater(_ p: CGPoint) -> Bool { hasWater && inTub(p) && p.y > surfaceY(p.x) }

    /// Pushes the surface down (positive) or up around x.
    func disturb(_ x: CGFloat, _ impulse: CGFloat, width: CGFloat = 12) {
        guard hasWater, x > SGeo.tubL - 10, x < SGeo.tubR + 10 else { return }
        let c = SGeo.col(x)
        let n = Int(width / SGeo.colW * 2.5) + 1
        for i in max(0, c - n)...min(SGeo.columns - 1, c + n) {
            let d = (SGeo.colX(i) - x) / width
            hv[i] += impulse * exp(-d * d * 0.5)
        }
    }

    var totalFoam: CGFloat { foam.reduce(0, +) }
    var maskCoverage: CGFloat { maskCov.reduce(0, +) / CGFloat(maskCov.count) }

    // MARK: Taps, plug

    func toggleTap() {
        tapOn.toggle()
        play(.turn, 0.7)
    }

    func togglePlug() {
        plugOut.toggle()
        play(.plug, 0.8)
    }

    // MARK: Stepping

    func step(_ date: Date) {
        let dt = last.map { min(1.0 / 20, max(0, date.timeIntervalSince($0))) } ?? 1.0 / 60
        last = date
        step(dt: dt)
    }

    func step(dt: Double) {
        guard dt > 0 else { return }
        time += dt
        let d = CGFloat(dt)
        stepTool(d)
        stepWaterLevel(d)
        let n = max(1, Int(ceil(dt * 120)))
        for _ in 0..<n { stepWaves(d / CGFloat(n)) }
        stepStream(d)
        stepFoam(d)
        stepThings(d)
        stepDrops(d)
        stepAir(d)
        stepBubbles(d)
        stepPuffs(d)
        stepSteam(d)
        stepHer(d)
        sounds()
    }

    private func stepWaterLevel(_ d: CGFloat) {
        flow += ((tapOn ? 1 : 0) - flow) * min(1, d * 3.5)
        handleTurn += ((tapOn ? 1 : 0) - handleTurn) * min(1, d * 8)
        let drainTarget: CGFloat = plugOut && vol > 0.01 ? 1 : 0
        drainFlow += (drainTarget - drainFlow) * min(1, d * 3)
        let before = vol
        if flow > 0.01 && vol < SGeo.maxDepth { vol = min(SGeo.maxDepth, vol + flow * 17 * d) }
        if drainFlow > 0.01 {
            vol = max(0, vol - drainFlow * (6 + 18 * sqrt(max(0, vol) / SGeo.maxDepth)) * d)
        }
        if vol < before && before > 0 {
            soap *= vol / before
        }
        if vol <= 0.01 {
            vol = 0
            soap = 0
            for i in 0..<SGeo.columns {
                tintA[i] *= max(0, 1 - d * 0.8)
                h[i] = 0
                hv[i] = 0
            }
        }
        warm = max(0, min(1, warm + flow * d * 0.12 - d * 0.0025))
        if vol < 10 { warm = max(0, warm - d * 0.05) }
    }

    private func stepWaves(_ d: CGFloat) {
        let N = SGeo.columns
        guard hasWater else { return }
        // waves are quicker in deep water (like real shallow-water waves), kept under the stable speed
        let c = min(290, 120 + 170 * sqrt(vol / SGeo.maxDepth))
        let k = c * c / (SGeo.colW * SGeo.colW)
        let damp: CGFloat = vol < 12 ? 6 : 0.55
        var acc = [CGFloat](repeating: 0, count: N)
        for i in 0..<N {
            let l = h[max(0, i - 1)], r = h[min(N - 1, i + 1)]
            acc[i] = k * (l + r - 2 * h[i])
        }
        var sum: CGFloat = 0
        for i in 0..<N {
            hv[i] += acc[i] * d
            hv[i] *= max(0, 1 - damp * d)
            h[i] += hv[i] * d
            h[i] = max(-40, min(min(40, vol), h[i]))
            sum += h[i]
        }
        // the waves move water about but never make or lose any
        let mean = sum / CGFloat(N)
        for i in 0..<N { h[i] -= mean }
    }

    var streamLanding: CGPoint {
        let top = SGeo.spout.y
        let bottom = hasWater ? surfaceY(SGeo.spout.x - 10) : SGeo.tubBottom
        let fall = max(1, bottom - top)
        let t = sqrt(2 * fall / 1500)
        return CGPoint(x: SGeo.spout.x - 34 * t * flow, y: bottom)
    }

    private func stepStream(_ d: CGFloat) {
        guard flow > 0.03 else { return }
        let land = streamLanding
        if hasWater {
            // the stream punches the surface down and churns it
            disturb(land.x + CGFloat.random(in: -6...6), flow * 900 * d * CGFloat.random(in: 0.4...1.6), width: 9)
            // it drags air down with it
            if CGFloat.random(in: 0...1) < flow * d * 70 {
                let depth = min(vol * 0.8, CGFloat.random(in: 8...70) * flow)
                air.append(SAir(p: CGPoint(x: land.x + CGFloat.random(in: -14...14), y: land.y + depth),
                                r: CGFloat.random(in: 1.5...5.5), phase: CGFloat.random(in: 0...6)))
            }
            // bubble bath foams up where the stream churns it
            let s = soapiness
            if s > 0.01 {
                let c = SGeo.col(land.x)
                for i in max(0, c - 4)...min(SGeo.columns - 1, c + 4) {
                    addFoam(i, s * flow * d * 1.6 * (1 - CGFloat(abs(i - c)) / 5), tint: nil)
                }
                if foam[c] > 0.8 && CGFloat.random(in: 0...1) < d * 1.5 * s {
                    spawnBubble(at: CGPoint(x: land.x + CGFloat.random(in: -30...30), y: land.y - foam[c] * 20),
                                v: CGVector(dx: CGFloat.random(in: -30...30), dy: CGFloat.random(in: -70 ... -30)))
                }
            }
        }
        // a little spray where it lands
        if CGFloat.random(in: 0...1) < flow * d * (hasWater ? 14 : 40) {
            drops.append(SDrop(p: CGPoint(x: land.x, y: land.y - 3),
                               v: CGVector(dx: CGFloat.random(in: -160...160), dy: CGFloat.random(in: -320 ... -90)),
                               r: CGFloat.random(in: 1.5...3), kind: .spray))
        }
    }

    func addFoam(_ i: Int, _ amount: CGFloat, tint: RGB?) {
        guard amount > 0, i >= 0, i < SGeo.columns else { return }
        let old = foam[i]
        foam[i] = min(2.6, old + amount)
        let t = tint ?? RGB(1, 1, 1)
        let k = amount / max(0.001, old + amount)
        foamTint[i] = foamTint[i].mix(t, Double(min(1, k)))
    }

    private func stepFoam(_ d: CGFloat) {
        let N = SGeo.columns
        // thick foam slumps sideways
        var flux = [CGFloat](repeating: 0, count: N)
        for i in 0..<(N - 1) {
            let g = foam[i] - foam[i + 1]
            let m = abs(g) > 0.18 ? (g - 0.18 * (g > 0 ? 1 : -1)) * 1.6 : g * 0.12
            flux[i] = m * d
        }
        for i in 0..<(N - 1) {
            let f = flux[i]
            if f > 0 {
                let t = foamTint[i]
                foam[i] -= f
                foam[i + 1] += f
                foamTint[i + 1] = foamTint[i + 1].mix(t, Double(min(1, f / max(0.01, foam[i + 1]))))
            } else if f < 0 {
                let t = foamTint[i + 1]
                foam[i + 1] += f
                foam[i] -= f
                foamTint[i] = foamTint[i].mix(t, Double(min(1, -f / max(0.01, foam[i]))))
            }
        }
        // the drain swirl pulls the foam toward the plug hole
        if drainFlow > 0.05 && hasWater {
            let c = SGeo.col(SGeo.drain.x)
            for i in 0..<N where i != c {
                let dir = i < c ? 1 : -1
                let m = foam[i] * min(1, d * 0.5 * drainFlow)
                foam[i] -= m
                foam[i + dir] += m
            }
            foam[c] *= max(0, 1 - d * 0.6 * drainFlow)
        }
        let decay: CGFloat = hasWater ? 0.004 : 0.12
        for i in 0..<N {
            foam[i] = max(0, foam[i] * (1 - decay * d) - 0.0004 * d)
            // the odd soap bubble floats up off thick foam
            if foam[i] > 1.1 && hasWater && CGFloat.random(in: 0...1) < d * 0.012 * foam[i] {
                spawnBubble(at: CGPoint(x: SGeo.colX(i), y: surfaceY(SGeo.colX(i)) - foam[i] * 22),
                            v: CGVector(dx: CGFloat.random(in: -15...15), dy: CGFloat.random(in: -50 ... -20)))
            }
        }
        // color in the water spreads out
        var nt = tintA
        for i in 0..<N {
            let l = tintA[max(0, i - 1)], r = tintA[min(N - 1, i + 1)]
            nt[i] = tintA[i] + (l + r - 2 * tintA[i]) * min(0.45, d * 9)
        }
        for i in 1..<(N - 1) where nt[i] > 0.01 {
            let mixK = Double(min(0.5, d * 6))
            tint[i] = tint[i].mix(tint[i - 1].mix(tint[i + 1], 0.5), mixK * 0.5)
        }
        tintA = nt
    }

    // MARK: Things

    func spawnThing(_ kind: ThingKind, at p: CGPoint, held: Bool) -> Int {
        let toys = things.filter { !$0.isBomb }
        if case .toy = kind, toys.count >= 10, let old = toys.first(where: { !$0.held }) {
            things.removeAll { $0.id == old.id }
        }
        let id = nextID
        nextID += 1
        var t = SThing(id: id, kind: kind, p: p)
        t.held = held
        t.target = p
        t.facing = Bool.random() ? 1 : -1
        things.append(t)
        return id
    }

    /// A tap on a tray thing drops one in from above.
    func dropIn(_ kind: ThingKind) {
        let x = CGFloat.random(in: 520...760)
        let id = spawnThing(kind, at: CGPoint(x: x, y: 250), held: false)
        if let i = things.firstIndex(where: { $0.id == id }) { things[i].v = CGVector(dx: CGFloat.random(in: -40...40), dy: 60) }
    }

    func thingIndex(_ id: Int) -> Int? { things.firstIndex { $0.id == id } }

    private func bottom(at x: CGFloat) -> CGFloat {
        x > SGeo.seat.minX && x < SGeo.seat.maxX ? SGeo.seat.minY : SGeo.tubBottom
    }

    private func stepThings(_ d: CGFloat) {
        let g: CGFloat = 1500
        for i in things.indices {
            var t = things[i]
            let hw = t.half.width, hh = t.half.height
            if t.held {
                let old = t.p
                let k = min(1, d * 22)
                t.p = CGPoint(x: t.p.x + (t.target.x - t.p.x) * k, y: t.p.y + (t.target.y - t.p.y) * k)
                t.v = CGVector(dx: (t.p.x - old.x) / d, dy: (t.p.y - old.y) / d)
                if abs(t.v.dx) > 40 { t.facing = t.v.dx > 0 ? 1 : -1 }
                let swing = max(-0.5, min(0.5, -t.v.dx * 0.0007))
                t.av += (swing - t.a) * 60 * d - t.av * 8 * d
                t.a += t.av * d
                t.wasIn = underWater(CGPoint(x: t.p.x, y: t.p.y + hh * 0.5))
                things[i] = t
                continue
            }
            t.v.dy += g * d
            let inside = t.p.x > SGeo.tubL - 4 && t.p.x < SGeo.tubR + 4 && t.p.y + hh > SGeo.lipY - 6
            var sub: CGFloat = 0
            if inside && hasWater {
                let surf = surfaceY(t.p.x)
                sub = max(0, min(1, (t.p.y + hh - surf) / (2 * hh)))
                if sub > 0 {
                    t.v.dy -= g * sub / t.density * d
                    let drag = 1 - min(0.9, sub * 2.6 * d)
                    t.v.dx *= drag
                    t.v.dy *= 1 - min(0.9, sub * 3.4 * d)
                    // the surface's slope pushes it along and tips it
                    let s = slope(t.p.x)
                    t.v.dx -= s * g * 0.45 * sub * d
                    let tilt = atan(s) * 0.9
                    t.av += (tilt - t.a) * 40 * d * sub
                    // the plug hole swirl pulls it in
                    if drainFlow > 0.05 { t.v.dx += (SGeo.drain.x - t.p.x) * 0.6 * drainFlow * d }
                    // fizzing bombs scoot about
                    if t.isBomb && t.fizz > 0 && t.wetFor > 0.5 {
                        t.v.dx += CGFloat.random(in: -500...500) * d
                        t.av += CGFloat.random(in: -8...8) * d
                    }
                    // it pushes the water as it bobs
                    let c = SGeo.col(t.p.x)
                    let w = Int(hw / SGeo.colW)
                    for j in max(0, c - w)...min(SGeo.columns - 1, c + w) {
                        hv[j] += (t.v.dy - hv[j]) * 0.015 * sub
                    }
                    // landing in the water
                    if !t.wasIn && t.v.dy > 160 {
                        splash(at: CGPoint(x: t.p.x, y: surf), speed: t.v.dy, size: hw)
                    }
                }
            }
            let nowIn = sub > 0.05
            if nowIn && t.isBomb { t.wetFor += d }
            t.wasIn = nowIn
            t.av -= t.a * (sub > 0 ? 0 : 10) * d
            t.av *= max(0, 1 - 5 * d)
            t.a += t.av * d
            if abs(t.v.dx) > 25 { t.facing = t.v.dx > 0 ? 1 : -1 }
            t.p.x += t.v.dx * d
            t.p.y += t.v.dy * d
            if t.dive > 0 { t.dive -= d }
            // inside the tub: glass ends, her, the seat and the floor of the tub
            if inside {
                if t.p.x - hw < SGeo.tubL { t.p.x = SGeo.tubL + hw; t.v.dx = abs(t.v.dx) * 0.4 }
                if t.p.x + hw > SGeo.tubR { t.p.x = SGeo.tubR - hw; t.v.dx = -abs(t.v.dx) * 0.4 }
                if t.p.y + hh > SGeo.chinY && t.p.x + hw > SGeo.bodyL && t.p.x - hw < SGeo.bodyR && t.p.y > SGeo.lipY - 20 {
                    if t.p.x < (SGeo.bodyL + SGeo.bodyR) / 2 {
                        t.p.x = SGeo.bodyL - hw
                        t.v.dx = -abs(t.v.dx) * 0.3 - 10
                    } else {
                        t.p.x = SGeo.bodyR + hw
                        t.v.dx = abs(t.v.dx) * 0.3 + 10
                    }
                }
                let b = bottom(at: t.p.x)
                if t.p.y + hh > b {
                    t.p.y = b - hh
                    if t.v.dy > 200 && !hasWater { play(.plop, 0.3, gap: 0.1) }
                    t.v.dy = -abs(t.v.dy) * 0.25
                    t.v.dx *= max(0, 1 - 6 * d)
                    t.av -= t.a * 20 * d
                }
            } else {
                // outside: bump off the outside of the glass, land on the bathroom floor
                if t.p.y + hh > SGeo.lipY + 10 {
                    if t.p.x < SGeo.tubL && t.p.x + hw > SGeo.tubL - 16 { t.p.x = SGeo.tubL - 16 - hw; t.v.dx = -abs(t.v.dx) * 0.4 }
                    if t.p.x > SGeo.tubR && t.p.x - hw < SGeo.tubR + 16 { t.p.x = SGeo.tubR + 16 + hw; t.v.dx = abs(t.v.dx) * 0.4 }
                }
                if t.p.y + hh > SGeo.floorY {
                    t.p.y = SGeo.floorY - hh
                    if t.v.dy > 250 { play(.plop, 0.25, gap: 0.1) }
                    t.v.dy = -abs(t.v.dy) * 0.3
                    t.v.dx *= max(0, 1 - 5 * d)
                    t.av -= t.a * 20 * d
                }
                t.p.x = max(hw, min(1024 - hw, t.p.x))
            }
            // squash spring (taps, landings)
            t.squashV += (-t.squash * 260 - t.squashV * 12) * d
            t.squash += t.squashV * d
            // bath bombs fizz away
            if case .bomb(let k) = t.kind, t.wetFor > 0.3, t.fizz > 0 {
                fizz(&t, k, d)
            }
            things[i] = t
        }
        things.removeAll { $0.isBomb && $0.fizz <= 0 }
        // things bump into each other
        if things.count > 1 {
            for i in 0..<(things.count - 1) {
                for j in (i + 1)..<things.count {
                    let a = things[i], b = things[j]
                    let ra = max(a.half.width, a.half.height) * 0.82, rb = max(b.half.width, b.half.height) * 0.82
                    let dx = b.p.x - a.p.x, dy = b.p.y - a.p.y
                    let dist = hypot(dx, dy)
                    let overlap = ra + rb - dist
                    guard overlap > 0, dist > 0.01 else { continue }
                    let nx = dx / dist, ny = dy / dist
                    let pa: CGFloat = a.held ? 0 : (b.held ? 1 : 0.5)
                    let pb: CGFloat = 1 - pa
                    if !a.held { things[i].p.x -= nx * overlap * pa; things[i].p.y -= ny * overlap * pa }
                    if !b.held { things[j].p.x += nx * overlap * pb; things[j].p.y += ny * overlap * pb }
                    let rv = (b.v.dx - a.v.dx) * nx + (b.v.dy - a.v.dy) * ny
                    if rv < 0 {
                        let imp = -rv * 0.6
                        if !a.held { things[i].v.dx -= nx * imp * pa * 2; things[i].v.dy -= ny * imp * pa * 2 }
                        if !b.held { things[j].v.dx += nx * imp * pb * 2; things[j].v.dy += ny * imp * pb * 2 }
                        if imp > 140 { play(.squeak2, 0.15, gap: 0.3) }
                    }
                }
            }
        }
    }

    private func fizz(_ t: inout SThing, _ k: BombKind, _ d: CGFloat) {
        let under = underWater(t.p)
        t.fizz -= d / 11
        let r = t.half.width
        let col = k.dye(time)
        // a curtain of tiny bubbles
        let n = Int(d * 90 * (0.4 + t.fizz)) + (CGFloat.random(in: 0...1) < 0.5 ? 1 : 0)
        for _ in 0..<n {
            let a = CGFloat.random(in: 0 ... (2 * .pi))
            let p = CGPoint(x: t.p.x + cos(a) * r, y: t.p.y + sin(a) * r)
            if underWater(p) { air.append(SAir(p: p, r: CGFloat.random(in: 1...2.6), phase: a, vx: cos(a) * 20)) }
        }
        // color billows out and dyes the bath
        if under || t.wasIn {
            if CGFloat.random(in: 0...1) < d * 9 {
                puffs.append(SPuff(p: CGPoint(x: t.p.x + CGFloat.random(in: -r...r), y: t.p.y + CGFloat.random(in: 0...r)),
                                   v: CGVector(dx: CGFloat.random(in: -50...50), dy: CGFloat.random(in: -10...45)),
                                   r: r * CGFloat.random(in: 0.6...1.1), a: 0.5, color: col))
            }
            let c = SGeo.col(t.p.x)
            for i in max(0, c - 3)...min(SGeo.columns - 1, c + 3) {
                let add = d * 0.16 * (1 - CGFloat(abs(i - c)) / 4)
                tint[i] = tint[i].mix(col, Double(min(1, add / max(0.02, tintA[i] + add)) * 1.5))
                tintA[i] = min(0.95, tintA[i] + add)
                addFoam(i, d * 0.35 * (1 - CGFloat(abs(i - c)) / 4), tint: col)
            }
        }
        if k.glitter && CGFloat.random(in: 0...1) < d * 26 {
            let a = CGFloat.random(in: 0 ... (2 * .pi))
            let gold = RGB(hex: "#FFF2A8")
            glitter.append(SGlitter(p: CGPoint(x: t.p.x + cos(a) * r, y: t.p.y + sin(a) * r),
                                    v: CGVector(dx: cos(a) * 30, dy: sin(a) * 20 - 10),
                                    color: k == .sunshine ? gold : col.mix(RGB(1, 1, 1), 0.4), phase: a))
        }
        if t.fizz <= 0 {
            pops.append(SPop(p: t.p, r: 40, sparkle: true))
            play(.chime, 0.25, gap: 0.5)
        }
    }

    // MARK: Splashes and drops

    func splash(at p: CGPoint, speed: CGFloat, size: CGFloat) {
        let power = min(1.6, speed * size / 30000)
        disturb(p.x, speed * size / 140, width: max(10, size * 0.7))
        let n = Int(6 + power * 26)
        for _ in 0..<n {
            let side: CGFloat = Bool.random() ? 1 : -1
            drops.append(SDrop(p: CGPoint(x: p.x + side * CGFloat.random(in: 0...size), y: p.y - 2),
                               v: CGVector(dx: side * CGFloat.random(in: 40...260) * (0.5 + power),
                                           dy: -CGFloat.random(in: 160...520) * (0.5 + power * 0.7)),
                               r: CGFloat.random(in: 1.8...4.2)))
        }
        for _ in 0..<Int(4 + power * 14) {
            air.append(SAir(p: CGPoint(x: p.x + CGFloat.random(in: -size...size), y: p.y + CGFloat.random(in: 6...(20 + size))),
                            r: CGFloat.random(in: 1.5...5), phase: CGFloat.random(in: 0...6)))
        }
        if soapiness > 0.05 {
            let c = SGeo.col(p.x)
            for i in max(0, c - 5)...min(SGeo.columns - 1, c + 5) { addFoam(i, 0.05 * power * soapiness, tint: nil) }
        }
        if power > 0.6 { play(.bigsplash, 0.8, gap: 0.15) } else { play(.splash, 0.3 + Float(power) * 0.6, gap: 0.08) }
    }

    private func stepDrops(_ d: CGFloat) {
        var keep: [SDrop] = []
        keep.reserveCapacity(drops.count)
        for var dr in drops {
            let wasInTubX = dr.p.x > SGeo.tubL && dr.p.x < SGeo.tubR
            dr.v.dy += 1500 * d
            dr.p.x += dr.v.dx * d
            dr.p.y += dr.v.dy * d
            dr.age += d
            let nowInTubX = dr.p.x > SGeo.tubL && dr.p.x < SGeo.tubR
            // the glass walls stop drops below the lip
            if wasInTubX != nowInTubX && dr.p.y > SGeo.lipY {
                dr.v.dx = -dr.v.dx * 0.3
                dr.p.x = wasInTubX ? (dr.p.x <= SGeo.tubL ? SGeo.tubL + 1 : SGeo.tubR - 1)
                                   : (dr.p.x >= SGeo.tubR ? SGeo.tubR + 17 : SGeo.tubL - 17)
            }
            if dr.p.y < -40 || dr.p.x < -40 || dr.p.x > 1064 || dr.age > 6 { continue }
            // onto her face or shoulders
            if dr.v.dy > 0 {
                let dd = SGeo.toDoll(dr.p)
                if SGeo.onHer(dd) && !SGeo.inHead(dd, pad: -6) == false || (SGeo.onHer(dd) && dd.y > 400) {
                    if CGFloat.random(in: 0...1) < 0.35 { addBead(dd) }
                    if dr.kind == .water || dr.kind == .spray { rinse(at: dd, amount: 0.05) }
                    if CGFloat.random(in: 0...1) < 0.6 { continue }
                }
            }
            if nowInTubX && dr.p.y > SGeo.lipY - 2 {
                if hasWater && dr.p.y > surfaceY(dr.p.x) {
                    disturb(dr.p.x, dr.r * dr.v.dy * 0.05, width: 6)
                    if dr.kind == .soap {
                        soap += 0.55
                        let c = SGeo.col(dr.p.x)
                        for i in max(0, c - 2)...min(SGeo.columns - 1, c + 2) { addFoam(i, 0.025, tint: nil) }
                        puffs.append(SPuff(p: CGPoint(x: dr.p.x, y: dr.p.y + 8), v: CGVector(dx: CGFloat.random(in: -20...20), dy: 35),
                                           r: 10, a: 0.35, color: RGB(hex: "#FFB0D0")))
                        play(.drip, 0.3, gap: 0.12)
                    } else {
                        if dr.r > 3 && CGFloat.random(in: 0...1) < 0.3 { play(.drip, 0.18, gap: 0.09) }
                        if foam[SGeo.col(dr.p.x)] > 0.1 { foam[SGeo.col(dr.p.x)] *= 0.995 }
                    }
                    continue
                }
                if dr.p.y > bottom(at: dr.p.x) {
                    if dr.kind == .soap { soap += 0.55 }
                    continue
                }
            }
            if !nowInTubX && dr.p.y > SGeo.floorY - 2 {
                addPuddle(dr.p.x, dr.r)
                continue
            }
            // shower water and splashes knock floating things about
            keep.append(dr)
        }
        drops = keep
        for i in puddles.indices { puddles[i].a -= d * 0.012 }
        puddles.removeAll { $0.a <= 0 }
    }

    private func addPuddle(_ x: CGFloat, _ r: CGFloat) {
        if let i = puddles.firstIndex(where: { abs($0.x - x) < $0.r * 0.8 + 6 }) {
            puddles[i].r = min(90, puddles[i].r + r * 0.25)
            puddles[i].a = min(1, puddles[i].a + 0.04)
        } else if puddles.count < 14 {
            puddles.append(SPuddle(x: x, r: 6 + r, a: 0.5))
        }
    }

    private func stepAir(_ d: CGFloat) {
        var keep: [SAir] = []
        keep.reserveCapacity(air.count)
        for var b in air {
            b.phase += d * 9
            let rise = 45 + b.r * 22
            b.p.y -= rise * d
            b.vx *= max(0, 1 - d * 3)
            b.p.x += (sin(b.phase) * b.r * 6 + b.vx) * d
            guard inTub(b.p), hasWater else { continue }
            let surf = surfaceY(b.p.x)
            if b.p.y <= surf + b.r * 0.5 {
                disturb(b.p.x, -b.r * 4, width: 5)
                if soapiness > 0.05 { addFoam(SGeo.col(b.p.x), 0.004 * b.r * soapiness, tint: nil) }
                continue
            }
            keep.append(b)
        }
        if keep.count > 500 { keep.removeFirst(keep.count - 500) }
        air = keep
    }

    // MARK: Soap bubbles

    func spawnBubble(at p: CGPoint, v: CGVector, r: CGFloat? = nil) {
        guard bubbles.count < 60 else { return }
        bubbles.append(SBubble(p: p, v: v, r: r ?? CGFloat.random(in: 10...30), life: CGFloat.random(in: 6...14),
                               phase: CGFloat.random(in: 0 ... (2 * .pi))))
    }

    func popBubble(_ i: Int, loud: Bool = true) {
        let b = bubbles[i]
        pops.append(SPop(p: b.p, r: b.r))
        for _ in 0..<Int(3 + b.r / 6) {
            let a = CGFloat.random(in: 0 ... (2 * .pi))
            drops.append(SDrop(p: CGPoint(x: b.p.x + cos(a) * b.r, y: b.p.y + sin(a) * b.r),
                               v: CGVector(dx: cos(a) * 120, dy: sin(a) * 120 - 60), r: 1.2, kind: .spray))
        }
        bubbles.remove(at: i)
        if loud { play(.pop, 0.75, gap: 0.03) }
    }

    private func stepBubbles(_ d: CGFloat) {
        var i = bubbles.count - 1
        while i >= 0 {
            var b = bubbles[i]
            b.age += d
            b.phase += d * 0.8
            // they drift up a little, wander in the air and are blown about by her hand
            b.v.dy -= 9 * d
            b.v.dx += sin(CGFloat(time) * 0.9 + b.phase * 3) * 14 * d
            if hand != .none {
                let dx = b.p.x - handP.x, dy = b.p.y - handP.y
                let dist = hypot(dx, dy)
                if dist < 120 { b.v.dx += handV.dx * 0.5 * d * (1 - dist / 120); b.v.dy += handV.dy * 0.5 * d * (1 - dist / 120) }
            }
            b.v.dx *= max(0, 1 - 0.9 * d)
            b.v.dy *= max(0, 1 - 0.9 * d)
            b.p.x += b.v.dx * d
            b.p.y += b.v.dy * d
            bubbles[i] = b
            var pop = b.age > b.life || b.p.y < b.r || b.p.x < b.r || b.p.x > 1024 - b.r || b.p.y > SGeo.floorY
            // bubbles that touch bare water burst; on foam they sit a while
            if !pop && hasWater && inTub(b.p) && b.p.y + b.r > surfaceY(b.p.x) {
                let f = foam[SGeo.col(b.p.x)]
                if f < 0.3 { pop = true } else { bubbles[i].v.dy = min(bubbles[i].v.dy, -4); bubbles[i].p.y = surfaceY(b.p.x) - b.r }
            }
            // and on her face
            if !pop {
                let dd = SGeo.toDoll(b.p)
                if SGeo.inHead(dd, pad: b.r / SGeo.dollScale * 0.6) && b.age > 0.8 {
                    pop = true
                    addBead(SGeo.toDoll(CGPoint(x: b.p.x, y: b.p.y)))
                }
            }
            if pop { popBubble(i, loud: b.age < b.life + 1) }
            i -= 1
        }
        for j in pops.indices { pops[j].age += d }
        pops.removeAll { $0.age > ($0.sparkle ? 0.9 : 0.22) }
    }

    // MARK: Color clouds, glitter, steam

    private func stepPuffs(_ d: CGFloat) {
        for i in puffs.indices {
            var p = puffs[i]
            p.age += d
            p.r += d * (26 + p.r * 0.25)
            p.a *= max(0, 1 - d * 0.32)
            p.v.dx *= max(0, 1 - d * 0.9)
            p.v.dy *= max(0, 1 - d * 0.9)
            p.p.x += p.v.dx * d + sin(CGFloat(time) * 0.7 + CGFloat(i)) * 6 * d
            p.p.y += p.v.dy * d
            p.p.x = max(SGeo.tubL + 10, min(SGeo.tubR - 10, p.p.x))
            p.p.y = min(SGeo.tubBottom - 10, max(level + 10, p.p.y))
            puffs[i] = p
        }
        puffs.removeAll { $0.a < 0.02 || !hasWater }
        if puffs.count > 70 { puffs.removeFirst(puffs.count - 70) }
        for i in glitter.indices {
            var gl = glitter[i]
            gl.age += d
            gl.phase += d * 5
            if !gl.settled {
                gl.v.dx *= max(0, 1 - d * 2)
                gl.v.dy += (14 - gl.v.dy) * min(1, d * 2)
                gl.p.x += (gl.v.dx + sin(gl.phase) * 8) * d
                gl.p.y += gl.v.dy * d
                let b = bottom(at: gl.p.x) - 3
                if gl.p.y > b { gl.p.y = b; gl.settled = true }
                if !underWater(gl.p) && gl.p.y < level { gl.p.y = level + 2 }
            }
            glitter[i] = gl
        }
        glitter.removeAll { !hasWater || $0.age > 40 }
        if glitter.count > 260 { glitter.removeFirst(glitter.count - 260) }
        if vol > 0.5 {
            for i in 0..<SGeo.columns { tintA[i] = max(0, tintA[i] - d * 0.0015) }
        }
    }

    private func stepSteam(_ d: CGFloat) {
        if hasWater && warm > 0.05 && CGFloat.random(in: 0...1) < d * 4 * warm {
            let x = CGFloat.random(in: (SGeo.tubL + 30)...(SGeo.tubR - 30))
            steam.append(SSteam(p: CGPoint(x: x, y: surfaceY(x) - 10), v: CGVector(dx: CGFloat.random(in: -8...8), dy: -CGFloat.random(in: 16...30)),
                                r: CGFloat.random(in: 18...34), life: CGFloat.random(in: 4...7)))
        }
        for i in steam.indices {
            steam[i].age += d
            steam[i].r += d * 9
            steam[i].p.x += (steam[i].v.dx + sin(CGFloat(time) * 0.6 + CGFloat(i)) * 6) * d
            steam[i].p.y += steam[i].v.dy * d
        }
        steam.removeAll { $0.age > $0.life }
        // the mirror steams up while the bath is warm, and clears slowly when it isn't
        let grow = warm * (hasWater ? 0.035 : 0.01)
        for i in fog.indices {
            let r = i / SGeo.fogCols
            let toward: CGFloat = 0.92 - CGFloat(r) * 0.008
            if grow > 0.001 { fog[i] += (toward - fog[i]) * grow * d } else { fog[i] = max(0, fog[i] - d * 0.004) }
        }
    }

    // MARK: Her

    func expression() -> Expression {
        if cucumbers[0] && cucumbers[1] { return .blink }
        if time < happyUntil { return .happy }
        if time > blinkAt && time < blinkAt + 0.14 { return .blink }
        return .normal
    }

    func giggle() {
        happyUntil = time + 1.4
        bobV -= 70
        // she splashes with both hands
        if hasWater {
            for x in [SGeo.bodyL - 20, SGeo.bodyR + 20] {
                let s = surfaceY(x)
                disturb(x, 220, width: 14)
                for _ in 0..<10 {
                    let side: CGFloat = x < 330 ? -1 : 1
                    drops.append(SDrop(p: CGPoint(x: x, y: s - 2), v: CGVector(dx: side * CGFloat.random(in: 30...200), dy: -CGFloat.random(in: 200...480)),
                                       r: CGFloat.random(in: 1.8...3.6)))
                }
            }
            play(.slosh, 0.6, gap: 0.2)
        } else {
            play(.squeak2, 0.25, gap: 0.2)
        }
        pops.append(SPop(p: SGeo.fromDoll(CGPoint(x: 300, y: 200)), r: 30, sparkle: true))
    }

    func addBead(_ d: CGPoint) {
        guard SGeo.onHer(d), beads.count < 46 else { return }
        beads.append(SBead(d: d, r: CGFloat.random(in: 4...8)))
        neededDrying = true
    }

    func addSud(_ d: CGPoint, r: CGFloat) {
        guard SGeo.onHer(d, pad: 24), suds.count < 70 else { return }
        suds.append(SSud(d: d, r: r, phase: CGFloat.random(in: 0...6)))
        neededDrying = true
    }

    /// Water washing over her (doll coordinates): it rinses suds and mask off and leaves drops.
    func rinse(at d: CGPoint, amount: CGFloat) {
        let before = suds.count
        suds.removeAll { hypot($0.d.x - d.x, $0.d.y - d.y) < 40 && CGFloat.random(in: 0...1) < amount * 6 }
        if suds.count < before { for _ in 0..<(before - suds.count) { addBead(CGPoint(x: d.x + CGFloat.random(in: -20...20), y: d.y)) } }
        wipeMask(at: d, radius: 34, amount: amount * 0.8)
    }

    /// Paints face mask at a doll point.
    func paintMask(at d: CGPoint, kind: MaskKind, amount: CGFloat) {
        for (i, c) in maskCells(near: d, radius: 36) {
            let w = 1 - c
            if maskCov[i] < 0.4 { maskKind[i] = kind.rawValue }
            else if maskKind[i] != kind.rawValue { maskKind[i] = kind.rawValue }
            maskCov[i] = min(1, maskCov[i] + amount * w)
            maskDry[i] *= 0.6
        }
    }

    func wipeMask(at d: CGPoint, radius: CGFloat, amount: CGFloat) {
        for (i, c) in maskCells(near: d, radius: radius) {
            maskCov[i] = max(0, maskCov[i] - amount * (1 - c * 0.5))
        }
    }

    /// Mask cells near a doll point, with how far in (0 at the middle, 1 at the edge).
    private func maskCells(near d: CGPoint, radius: CGFloat) -> [(Int, CGFloat)] {
        let r = SGeo.maskRect
        let cw = r.width / CGFloat(SGeo.maskCols), ch = r.height / CGFloat(SGeo.maskRows)
        var out: [(Int, CGFloat)] = []
        let c0 = max(0, Int((d.x - radius - r.minX) / cw)), c1 = min(SGeo.maskCols - 1, Int((d.x + radius - r.minX) / cw))
        let r0 = max(0, Int((d.y - radius - r.minY) / ch)), r1 = min(SGeo.maskRows - 1, Int((d.y + radius - r.minY) / ch))
        guard c0 <= c1, r0 <= r1 else { return [] }
        for row in r0...r1 {
            for col in c0...c1 {
                let cx = r.minX + (CGFloat(col) + 0.5) * cw, cy = r.minY + (CGFloat(row) + 0.5) * ch
                let dist = hypot(cx - d.x, cy - d.y)
                if dist < radius && SGeo.inHead(CGPoint(x: cx, y: cy), pad: -4) { out.append((row * SGeo.maskCols + col, dist / radius)) }
            }
        }
        return out
    }

    func maskCellCenter(_ i: Int) -> CGPoint {
        let r = SGeo.maskRect
        let cw = r.width / CGFloat(SGeo.maskCols), ch = r.height / CGFloat(SGeo.maskRows)
        return CGPoint(x: r.minX + (CGFloat(i % SGeo.maskCols) + 0.5) * cw, y: r.minY + (CGFloat(i / SGeo.maskCols) + 0.5) * ch)
    }

    /// Takes a cucumber slice off her eye: it flips off into the bath (or onto the floor).
    func removeCucumber(_ e: Int) {
        guard cucumbers[e] else { return }
        cucumbers[e] = false
        let p = SGeo.fromDoll(SGeo.eyes[e])
        let id = spawnThing(.toy(.cucumber), at: p, held: false)
        if let i = thingIndex(id) { things[i].v = CGVector(dx: e == 0 ? -160 : 160, dy: -380); things[i].av = e == 0 ? -9 : 9 }
        play(.pop, 0.5)
        happyUntil = time + 0.8
    }

    func placeCucumber(at p: CGPoint) -> Bool {
        let d = SGeo.toDoll(p)
        let order = SGeo.eyes.indices.sorted { hypot(SGeo.eyes[$0].x - d.x, SGeo.eyes[$0].y - d.y) < hypot(SGeo.eyes[$1].x - d.x, SGeo.eyes[$1].y - d.y) }
        for e in order where !cucumbers[e] && hypot(SGeo.eyes[e].x - d.x, SGeo.eyes[e].y - d.y) < 95 {
            cucumbers[e] = true
            play(.squish, 0.5)
            if cucumbers[0] && cucumbers[1] { pops.append(SPop(p: SGeo.fromDoll(CGPoint(x: 300, y: 240)), r: 26, sparkle: true)) }
            return true
        }
        return false
    }

    private func stepHer(_ d: CGFloat) {
        if time > blinkAt + 0.14 { blinkAt = time + Double.random(in: 2.5...5.5) }
        bobV += (-bob * 220 - bobV * 9) * d
        bob += bobV * d
        // drops run slowly down her skin and drip off her chin into the bath
        for i in beads.indices {
            beads[i].vy += (12 + beads[i].r * 2 - beads[i].vy) * d * 0.8
            beads[i].d.y += beads[i].vy * d * (CGFloat.random(in: 0...1) < 0.3 ? 2.5 : 0.4)
        }
        let dripped = beads.filter { $0.d.y > 560 || (!SGeo.onHer($0.d) && $0.d.y > 420) }
        for b in dripped {
            let p = SGeo.fromDoll(b.d)
            drops.append(SDrop(p: p, v: CGVector(dx: 0, dy: 30), r: b.r * 0.5))
        }
        beads.removeAll { $0.d.y > 560 || (!SGeo.onHer($0.d) && $0.d.y > 420) }
        // the warm bath water keeps her shoulders wet and soaks suds under the water line
        let waterDoll = SGeo.toDoll(CGPoint(x: 330, y: level)).y
        suds.removeAll { $0.d.y > waterDoll + 6 && hasWater }
        // a face mask dries (lighter, then it cracks) unless it's being wetted
        for i in maskCov.indices where maskCov[i] > 0.05 {
            maskDry[i] = min(1, maskDry[i] + d / 9)
        }
        // all dry and clean again after being wet: a happy chime
        if neededDrying && beads.isEmpty && suds.isEmpty && tool == .towel {
            neededDrying = false
            happyUntil = time + 1.6
            pops.append(SPop(p: SGeo.fromDoll(CGPoint(x: 300, y: 300)), r: 60, sparkle: true))
            play(.chime, 0.6)
        }
    }

    // MARK: Her bare finger

    func handBegan(_ p: CGPoint) {
        handP = p
        handV = .zero
        hand = .none
        // pop a bubble
        if let i = bubbles.indices.reversed().first(where: { hypot(bubbles[$0].p.x - p.x, bubbles[$0].p.y - p.y) < bubbles[$0].r + 16 }) {
            popBubble(i)
            hand = .pop
            return
        }
        // pick up a toy or a bath bomb (topmost first)
        if let i = things.indices.reversed().first(where: {
            let t = things[$0]
            return abs(t.p.x - p.x) < t.half.width + 18 && abs(t.p.y - p.y) < t.half.height + 22
        }) {
            things[i].held = true
            things[i].target = things[i].p
            hand = .thing(things[i].id)
            Sound.shared.tap()
            return
        }
        // the tap handle or the spout
        if hypot(p.x - SGeo.handle.x, p.y - SGeo.handle.y) < 60 || hypot(p.x - SGeo.spout.x, p.y - (SGeo.spout.y - 20)) < 44 {
            toggleTap()
            return
        }
        // the plug chain
        if plugHit(p) {
            togglePlug()
            return
        }
        // a cucumber slice on her eye
        let dd = SGeo.toDoll(p)
        for e in 0..<2 where cucumbers[e] && hypot(SGeo.eyes[e].x - dd.x, SGeo.eyes[e].y - dd.y) < 70 {
            removeCucumber(e)
            return
        }
        if SGeo.mirror.insetBy(dx: -6, dy: -6).contains(p) {
            hand = .wipe
            wipe(p)
            return
        }
        if SGeo.inHead(dd, pad: 10) {
            hand = .girl
            return
        }
        if inTub(p) && (!hasWater || p.y > surfaceY(p.x) - 40) {
            hand = .swish
            return
        }
        hand = .none
    }

    func plugHit(_ p: CGPoint) -> Bool {
        let a = SGeo.plugRing
        let b = plugOut ? CGPoint(x: SGeo.plugRing.x - 26, y: SGeo.plugRing.y + 120) : SGeo.drain
        let t = max(0, min(1, ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / max(1, pow(b.x - a.x, 2) + pow(b.y - a.y, 2))))
        let q = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        return hypot(p.x - q.x, p.y - q.y) < 34
    }

    func handMoved(_ p: CGPoint, dt: CGFloat) {
        let v = CGVector(dx: (p.x - handP.x) / dt, dy: (p.y - handP.y) / dt)
        handV = CGVector(dx: handV.dx * 0.5 + v.dx * 0.5, dy: handV.dy * 0.5 + v.dy * 0.5)
        let prev = handP
        handP = p
        // swiping across bubbles pops them
        if let i = bubbles.indices.reversed().first(where: { hypot(bubbles[$0].p.x - p.x, bubbles[$0].p.y - p.y) < bubbles[$0].r + 8 }) {
            popBubble(i)
        }
        switch hand {
        case .thing(let id):
            if let i = thingIndex(id) {
                let hh = things[i].half.height
                things[i].target = FingerLift.point(p, lift: FingerLift.carry(below: hh), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
            }
        case .wipe:
            let steps = max(1, Int(hypot(p.x - prev.x, p.y - prev.y) / 6))
            for k in 0...steps { wipe(CGPoint(x: prev.x + (p.x - prev.x) * CGFloat(k) / CGFloat(steps), y: prev.y + (p.y - prev.y) * CGFloat(k) / CGFloat(steps))) }
        case .swish, .girl, .none, .pop:
            if hand == .girl && !SGeo.inHead(SGeo.toDoll(p), pad: 30) && inTub(p) { hand = .swish }
            if hand == .none && inTub(p) && hasWater && p.y > surfaceY(p.x) - 20 { hand = .swish }
            if hand == .swish { swish(p, v: handV, dt: dt) }
        }
    }

    private func swish(_ p: CGPoint, v: CGVector, dt: CGFloat) {
        guard hasWater, inTub(p) else { return }
        let surf = surfaceY(p.x)
        guard p.y > surf - 24 else { return }
        let speed = hypot(v.dx, v.dy)
        let c = SGeo.col(p.x)
        // her hand pushes the water: up ahead of it, down behind it
        let dir: Int = v.dx > 0 ? 1 : -1
        let push = max(-1, min(1, v.dx / 900))
        for k in -4...4 {
            let i = c + k
            guard i >= 0, i < SGeo.columns else { continue }
            let w = 1 - CGFloat(abs(k)) / 5
            hv[i] += (k * dir > 0 ? -1 : 1) * abs(push) * 90 * w
            hv[i] += v.dy * 0.04 * w
        }
        // it drags the foam along
        let move = min(0.6, abs(v.dx) * dt * 0.012)
        for k in -3...3 {
            let i = c + k, j = c + k + dir
            guard i >= 0, i < SGeo.columns, j >= 0, j < SGeo.columns else { continue }
            let m = foam[i] * move
            foam[i] -= m
            foam[j] += m
            foamTint[j] = foamTint[j].mix(foamTint[i], Double(min(1, m / max(0.01, foam[j]))))
        }
        // and whips up bubble bath
        let s = soapiness
        if s > 0.02 {
            for k in -3...3 { addFoam(c + k, s * min(1.5, speed / 600) * dt * 1.1, tint: nil) }
        }
        // a trail of air bubbles under water
        if p.y > surf + 8 && speed > 120 && CGFloat.random(in: 0...1) < min(1, speed * dt / 18) {
            air.append(SAir(p: CGPoint(x: p.x + CGFloat.random(in: -8...8), y: p.y + CGFloat.random(in: -4...6)),
                            r: CGFloat.random(in: 1.5...4.5), phase: CGFloat.random(in: 0...6)))
        }
        // a fast swipe near the top flicks water out
        if speed > 700 && abs(p.y - surf) < 30 && CGFloat.random(in: 0...1) < min(1, speed * dt / 30) {
            drops.append(SDrop(p: CGPoint(x: p.x, y: surf - 4), v: CGVector(dx: v.dx * 0.5 + CGFloat.random(in: -60...60), dy: -CGFloat.random(in: 200...200 + speed * 0.3)),
                               r: CGFloat.random(in: 1.6...3.8)))
        }
        if speed > 300 && time > swishSound {
            swishSound = time + 0.45
            play(.slosh, min(0.8, Float(speed) / 2000 + 0.2))
        }
    }

    private func wipe(_ p: CGPoint) {
        let m = SGeo.mirror
        let cw = m.width / CGFloat(SGeo.fogCols), ch = m.height / CGFloat(SGeo.fogRows)
        for r in 0..<SGeo.fogRows {
            for c in 0..<SGeo.fogCols {
                let cx = m.minX + (CGFloat(c) + 0.5) * cw, cy = m.minY + (CGFloat(r) + 0.5) * ch
                let dist = hypot(cx - p.x, cy - p.y)
                if dist < 24 { fog[r * SGeo.fogCols + c] *= dist < 15 ? 0 : 0.4 }
            }
        }
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        switch hand {
        case .thing(let id):
            if let i = thingIndex(id) {
                things[i].held = false
                var v = things[i].v
                let sp = hypot(v.dx, v.dy)
                if sp > 1600 { v = CGVector(dx: v.dx / sp * 1600, dy: v.dy / sp * 1600) }
                things[i].v = v
                if tap { tapThing(i) }
            }
        case .girl:
            if tap { giggle() }
        default:
            break
        }
        hand = .none
        handV = .zero
    }

    /// A tap on a toy: it squeaks and hops (the whale blows a fountain, the boat toots, the turtle dives).
    func tapThing(_ i: Int) {
        things[i].squashV -= 9
        guard case .toy(let k) = things[i].kind else { return }
        happyUntil = max(happyUntil, time + 0.8)
        switch k {
        case .duck, .duckling:
            things[i].v.dy -= 220
            play(k == .duck ? .squeak : .squeak2, 0.8)
        case .boat:
            things[i].v.dx += things[i].facing * 140
            play(.toot, 0.7)
        case .whale:
            let top = CGPoint(x: things[i].p.x + things[i].facing * 6, y: things[i].p.y - things[i].half.height)
            for _ in 0..<36 {
                drops.append(SDrop(p: top, v: CGVector(dx: CGFloat.random(in: -90...90), dy: -CGFloat.random(in: 380...640)), r: CGFloat.random(in: 1.8...3.6)))
            }
            play(.spout, 0.8)
        case .turtle:
            things[i].dive = 1.2
            play(.plop, 0.7)
        case .cucumber:
            things[i].v.dy -= 160
            play(.plop, 0.4)
        }
    }

    // MARK: Tools

    func pickUp(_ t: SpaTool, finger: CGPoint, lifted: CGPoint) {
        tool = t
        toolFinger = finger
        toolP = finger
        toolTarget = lifted
        toolV = .zero
        toolAngle = 0
        rubbing = 0
        if t == .wand { wandFilm = 1 }
        if t == .towel { towelWet = 0 }
    }

    func carry(finger: CGPoint, lifted: CGPoint) {
        toolFinger = finger
        toolTarget = lifted
    }

    func release() {
        if tool == .cucumber {
            if !placeCucumber(at: toolP) {
                let id = spawnThing(.toy(.cucumber), at: toolP, held: false)
                if let i = thingIndex(id) { things[i].v = toolV }
            }
        }
        tool = nil
    }

    private func stepTool(_ d: CGFloat) {
        guard let t = tool else { return }
        let old = toolP
        let k = min(1, d * 26)
        toolP = CGPoint(x: toolP.x + (toolTarget.x - toolP.x) * k, y: toolP.y + (toolTarget.y - toolP.y) * k)
        let v = CGVector(dx: (toolP.x - old.x) / d, dy: (toolP.y - old.y) / d)
        toolV = CGVector(dx: toolV.dx * 0.6 + v.dx * 0.4, dy: toolV.dy * 0.6 + v.dy * 0.4)
        let speed = hypot(toolV.dx, toolV.dy)
        let wet = underWater(toolP)
        rubbing = max(0, rubbing - d * 3)
        switch t {
        case .soap:
            // tips over the tub and pours a ribbon of bubble bath
            let overTub = toolP.x > SGeo.tubL + 10 && toolP.x < SGeo.tubR - 10 && toolP.y < (hasWater ? level : SGeo.tubBottom) - 40
            let want: CGFloat = overTub ? 2.2 : 0.15 * max(-1, min(1, -toolV.dx / 600))
            toolAngle += (want - toolAngle) * min(1, d * 7)
            if toolAngle > 1.6 {
                emitCarry += d * 34
                while emitCarry >= 1 {
                    emitCarry -= 1
                    let nozzle = soapNozzle
                    drops.append(SDrop(p: nozzle, v: CGVector(dx: CGFloat.random(in: -10...10) + toolV.dx * 0.2, dy: 60), r: CGFloat.random(in: 3...4.6), kind: .soap))
                }
                play(.glug, 0.5, gap: 0.6)
            }
        case .wand:
            let ring = toolP
            if wet {
                if wandFilm < 0.5 { play(.plop, 0.4, gap: 0.4) }
                wandFilm = 1
            } else if wandFilm > 0.04 && speed > 140 {
                emitCarry += speed * d / 46
                while emitCarry >= 1 {
                    emitCarry -= 1
                    let r = max(8, min(38, 3400 / max(90, speed) + CGFloat.random(in: -4...6)))
                    let dir = CGVector(dx: toolV.dx / max(1, speed), dy: toolV.dy / max(1, speed))
                    spawnBubble(at: CGPoint(x: ring.x + dir.dx * (24 + r), y: ring.y + dir.dy * (24 + r)),
                                v: CGVector(dx: toolV.dx * 0.32 + CGFloat.random(in: -20...20), dy: toolV.dy * 0.32 - 20), r: r)
                    wandFilm -= 0.035
                    play(.blow, 0.45, gap: 0.18)
                }
            } else {
                emitCarry = 0
            }
        case .sponge:
            if wet {
                spongeWet = min(1, spongeWet + d * 3)
                let f = foam[SGeo.col(toolP.x)]
                spongeFoam = min(1, spongeFoam + d * (soapiness * 1.2 + min(1, f) * 0.6))
                if speed > 100 {
                    disturb(toolP.x, toolV.dy * 0.02, width: 16)
                    if CGFloat.random(in: 0...1) < speed * d / 30 {
                        air.append(SAir(p: CGPoint(x: toolP.x + CGFloat.random(in: -30...30), y: toolP.y - 10), r: CGFloat.random(in: 1.5...4), phase: 0))
                    }
                    if soapiness > 0.02 { addFoam(SGeo.col(toolP.x), soapiness * d * 0.5, tint: nil) }
                }
            } else {
                // a wet sponge drips
                if spongeWet > 0.05 && CGFloat.random(in: 0...1) < d * 22 * spongeWet {
                    drops.append(SDrop(p: CGPoint(x: toolP.x + CGFloat.random(in: -28...28), y: toolP.y + 26), v: CGVector(dx: 0, dy: 40), r: CGFloat.random(in: 1.6...3)))
                    spongeWet = max(0, spongeWet - 0.012)
                }
                let dd = SGeo.toDoll(toolP)
                if SGeo.onHer(dd, pad: 20) && speed > 60 {
                    rubbing = 1
                    if spongeFoam > 0.05 && CGFloat.random(in: 0...1) < speed * d / 16 {
                        addSud(CGPoint(x: dd.x + CGFloat.random(in: -34...34), y: dd.y + CGFloat.random(in: -24...24)), r: CGFloat.random(in: 9...20))
                        spongeFoam = max(0, spongeFoam - 0.02)
                    }
                    if spongeWet > 0.1 && CGFloat.random(in: 0...1) < speed * d / 60 { addBead(CGPoint(x: dd.x + CGFloat.random(in: -30...30), y: dd.y)) }
                    wipeMask(at: dd, radius: 46, amount: speed * d * 0.004)
                }
            }
        case .shower:
            emitCarry += d * 110
            while emitCarry >= 1 {
                emitCarry -= 1
                let a = CGFloat.random(in: -0.35...0.35) + 0.12
                let sp = CGFloat.random(in: 420...560)
                let o = CGFloat.random(in: -18...18)
                drops.append(SDrop(p: CGPoint(x: toolP.x + o, y: toolP.y + 16), v: CGVector(dx: sin(a) * sp, dy: cos(a) * sp), r: CGFloat.random(in: 1.3...2.4), kind: .spray))
            }
            // the spray rinses her and splashes floating things
            let below = CGPoint(x: toolP.x, y: toolP.y + 60)
            let dd = SGeo.toDoll(below)
            if SGeo.onHer(dd, pad: 30) {
                rinse(at: dd, amount: d * 3)
                wipeMask(at: dd, radius: 60, amount: d * 1.4)
            }
            for i in things.indices where !things[i].held && abs(things[i].p.x - toolP.x) < 50 && things[i].p.y > toolP.y {
                things[i].v.dy += 260 * d
                things[i].v.dx += (things[i].p.x - toolP.x) * 3 * d
            }
        case .towel:
            let dd = SGeo.toDoll(toolP)
            if SGeo.onHer(dd, pad: 26) && speed > 50 {
                rubbing = 1
                let before = beads.count + suds.count
                beads.removeAll { hypot($0.d.x - dd.x, $0.d.y - dd.y) < 70 }
                suds.removeAll { hypot($0.d.x - dd.x, $0.d.y - dd.y) < 64 && CGFloat.random(in: 0...1) < d * 10 }
                if beads.count + suds.count < before { towelWet = min(1, towelWet + 0.03) }
                wipeMask(at: dd, radius: 50, amount: speed * d * 0.0016)
            }
            // mop up puddles on the floor
            if toolP.y > SGeo.floorY - 70 {
                for i in puddles.indices where abs(puddles[i].x - toolP.x) < puddles[i].r + 50 && speed > 40 {
                    puddles[i].a -= d * 1.2
                    towelWet = min(1, towelWet + d * 0.2)
                    rubbing = 1
                }
            }
            if wet { towelWet = 1 }
            if towelWet > 0.6 && !wet && CGFloat.random(in: 0...1) < d * 8 * towelWet {
                drops.append(SDrop(p: CGPoint(x: toolP.x + CGFloat.random(in: -40...40), y: toolP.y + 30), v: CGVector(dx: 0, dy: 30), r: 2.4))
            }
        case .mask(let mk):
            let dd = SGeo.toDoll(toolP)
            if SGeo.inHead(dd, pad: -6) {
                paintMask(at: dd, kind: mk, amount: min(1, d * 4 + speed * d * 0.006))
                if speed > 40 { rubbing = 0.7; play(.squish, 0.35, gap: 0.35) }
            }
        case .cucumber:
            break
        }
    }

    /// Where the bubble bath comes out of the tipped bottle.
    var soapNozzle: CGPoint {
        CGPoint(x: toolP.x + sin(toolAngle) * 62, y: toolP.y - cos(toolAngle) * 62)
    }

    // MARK: Sound

    private func play(_ s: SpaSFX, _ v: Float, gap: Double = 0) {
        guard !quiet else { return }
        SpaSound.shared.play(s, volume: v, gap: gap)
    }

    private func sounds() {
        guard !quiet else { return }
        let s = SpaSound.shared
        s.setLoop(.running, volume: Float(flow) * 0.7)
        s.setLoop(.drain, volume: Float(drainFlow) * (vol > 0.5 ? 0.55 : 0))
        let fizzing = things.reduce(CGFloat(0)) { $0 + ($1.isBomb && $1.wetFor > 0.3 ? 0.5 + $1.fizz * 0.5 : 0) }
        s.setLoop(.fizz, volume: Float(min(1, fizzing)) * 0.55)
        s.setLoop(.shower, volume: tool == .shower ? 0.55 : 0)
        s.setLoop(.scrub, volume: Float(rubbing) * 0.5)
    }
}
