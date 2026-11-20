import CoreGraphics
import Foundation

// MARK: - Salon hair: real strands with physics
//
// Her client's hair is about 70 locks. Each lock is a chain of points 14 units apart (Dress Up doll
// coordinates, 600 x 900, so the Dress Up face art lines up). The first points of a lock lie on the
// scalp and never move; the rest is free hair, simulated with Verlet integration and position-based
// constraints (Müller et al.): gravity, damping, fixed segment lengths, a little stiffness that keeps
// the shape near the roots, and collisions with her head, face and the salon cape.
//
//   back locks   hang behind her head (drawn before the face)
//   nape locks   fill in behind her neck
//   side locks   frame her face and drape over the cape in front
//   fringe locks the bangs
//
// Everything a tool does is a change to the locks: the comb drags points (and smooths tangles), the
// scissors cut a chain where a stroke crosses it and the cut end becomes a `HairPiece` that falls
// with its own physics, water makes hair heavy, dark and limp, the dryer blows a cone of wind, the
// curling iron raises a per-point curl (curls also shorten the chain, so curled hair springs up),
// the straightener takes it away, dye mixes the color of each point it touches, and the grow potion
// adds points at the tips. A scrunchie pins every lock that passes near it to one spot: ponytails.

/// A 2D vector for the hair simulation (its own type so its operators never clash with another game's).
struct HairV: Equatable {
    var x: CGFloat
    var y: CGFloat

    init(_ x: CGFloat, _ y: CGFloat) { self.x = x; self.y = y }
    init(_ p: CGPoint) { x = p.x; y = p.y }

    static let zero = HairV(0, 0)
    var cg: CGPoint { CGPoint(x: x, y: y) }
    var len: CGFloat { (x * x + y * y).squareRoot() }
    var unit: HairV {
        let l = len
        return l > 0.00001 ? HairV(x / l, y / l) : HairV(0, 1)
    }
    var perp: HairV { HairV(-y, x) }
    func dot(_ o: HairV) -> CGFloat { x * o.x + y * o.y }
    func dist(_ o: HairV) -> CGFloat { (self - o).len }

    static func + (a: HairV, b: HairV) -> HairV { HairV(a.x + b.x, a.y + b.y) }
    static func - (a: HairV, b: HairV) -> HairV { HairV(a.x - b.x, a.y - b.y) }
    static func * (a: HairV, k: CGFloat) -> HairV { HairV(a.x * k, a.y * k) }
    static func += (a: inout HairV, b: HairV) { a = a + b }
    static func -= (a: inout HairV, b: HairV) { a = a - b }

    func mix(_ o: HairV, _ t: CGFloat) -> HairV { HairV(x + (o.x - x) * t, y + (o.y - y) * t) }

    /// Distance from this point to the segment a-b.
    func distToSegment(_ a: HairV, _ b: HairV) -> CGFloat {
        let ab = b - a
        let l2 = ab.dot(ab)
        if l2 < 0.0001 { return dist(a) }
        let t = max(0, min(1, (self - a).dot(ab) / l2))
        return dist(a + ab * t)
    }
}

/// Where her head, face, cape and the floor are, in doll coordinates.
enum SalonBody {
    static let center = HairV(300, 287)
    static let rx: CGFloat = 142
    static let ry: CGFloat = 137
    static let floorY: CGFloat = 752
    static let capeBottom: CGFloat = 720

    /// A point on a scaled copy of the head outline. theta 0 is the top of her head, positive is screen right.
    static func head(_ theta: CGFloat, _ rho: CGFloat) -> HairV {
        HairV(center.x + rx * rho * sin(theta), center.y - ry * rho * cos(theta))
    }

    /// The front hairline, s from -1 (screen-left temple) over the forehead to 1.
    static func hairline(_ s: CGFloat) -> HairV {
        let a = abs(s)
        return HairV(300 + 128 * s, 232 + 70 * a * a * a)
    }

    /// The top of the salon cape at x, or nil where there is no cape.
    static func capeTop(_ x: CGFloat) -> CGFloat? {
        let d = abs(x - 300)
        let y: CGFloat
        if d <= 34 {
            y = 436
        } else if d <= 100 {
            y = 436 + (d - 34) * 0.6
        } else {
            y = 475.6 + (d - 100) * 2.4
        }
        return y < capeBottom ? y : nil
    }

    static func capeSlope(_ x: CGFloat) -> CGFloat {
        let d = abs(x - 300)
        let s: CGFloat = d <= 34 ? 0 : (d <= 100 ? 0.6 : 2.4)
        return x < 300 ? -s : s
    }

    /// Pushes `p` out of the ellipse around her head scaled by `k`. Returns true if it moved.
    @discardableResult
    static func pushOutOfHead(_ p: inout HairV, k: CGFloat) -> Bool {
        let ex = (p.x - center.x) / (rx * k)
        let ey = (p.y - center.y) / (ry * k)
        let r2 = ex * ex + ey * ey
        guard r2 < 1, r2 > 0.000001 else { return false }
        let r = r2.squareRoot()
        p = HairV(center.x + ex / r * rx * k, center.y + ey / r * ry * k)
        return true
    }

    /// Keeps `p` on top of the cape (sliding along its slope) and above the floor. Returns true on contact.
    @discardableResult
    static func pushOutOfCape(_ p: inout HairV) -> Bool {
        var hit = false
        if let top = capeTop(p.x), p.y > top, p.y < capeBottom + 30 {
            let m = capeSlope(p.x)
            let depth = p.y - top
            let k = 1 / (1 + m * m)
            p.y -= depth * k
            p.x += m * depth * k
            hit = true
        }
        if p.y > floorY { p.y = floorY; hit = true }
        return hit
    }

    /// Keeps a side lock from swinging in across her face. The wall starts at the lock's own root and
    /// eases out to the edge of her face over the first 60 points, so the lock is never shoved sideways.
    static func keepOffFace(_ p: inout HairV, root: HairV) {
        let side: CGFloat = root.x < center.x ? -1 : 1
        let ey = max(-1, min(0, (p.y - center.y) / ry))
        let edge = center.x + side * rx * (1 - ey * ey).squareRoot()
        let u = max(0, min(1, (p.y - root.y) / 60))
        let w = u * u * (3 - 2 * u)
        let limit = root.x + (edge - root.x) * w
        if side < 0, p.x > limit { p.x = limit }
        if side > 0, p.x < limit { p.x = limit }
    }

    static func onFace(_ p: HairV) -> Bool {
        let ex = (p.x - center.x) / (rx * 0.92)
        let ey = (p.y - center.y) / (ry * 0.92)
        return ex * ex + ey * ey < 1 && p.y > 230
    }
}

// MARK: - A lock of hair

struct HairStrand {
    enum Kind: Int { case back, nape, side, fringe }

    let kind: Kind
    /// The scalp part, root first. These points never move.
    let rest: [HairV]
    /// Which way the free hair leaves the scalp.
    let dir: HairV
    let width: CGFloat
    let phase: CGFloat
    /// Her own hair color for this lock (regrown hair comes in this color).
    let natural: RGB
    /// Fixed noise per point, -1...1, for frizz.
    let jitter: [CGFloat]
    /// Draw order inside its layer.
    let order: CGFloat

    var p: [HairV]
    var o: [HairV]
    /// One color and curl per point, for the longest the lock can grow (so `count` can change freely).
    var color: [RGB]
    var curl: [CGFloat]
    var wet: CGFloat = 0
    var tangle: CGFloat = 0
    var gloss: CGFloat = 0
    var growth: CGFloat = 0

    var pinned: Int { rest.count }
    var maxNodes: Int { rest.count + HairSim.maxFree }
    var free: Int { p.count - rest.count }
    var front: Bool { kind == .side || kind == .fringe }
    var tip: HairV { p[p.count - 1] }

    /// How curly point i looks and behaves now (water relaxes curls until the hair dries).
    func curlNow(_ i: Int) -> CGFloat {
        guard i >= pinned else { return 0 }
        let ramp = min(1, CGFloat(i - pinned + 1) / 2.5)
        return curl[i] * (1 - 0.7 * wet) * ramp
    }

    func segLen(_ i: Int) -> CGFloat { HairSim.seg * (1 - 0.4 * curlNow(i)) }
}

/// A cut-off piece of hair, falling and then lying where it landed.
struct HairPiece {
    var p: [HairV]
    var o: [HairV]
    var color: [RGB]
    var curl: [CGFloat]
    let width: CGFloat
    let phase: CGFloat
    let jitter: [CGFloat]
    let tangle: CGFloat
    let wet: CGFloat
    var still: Double = 0
    var asleep = false
    var age: Double = 0
    /// Cut hair lands in front of everything; pieces from behind her head fade in from behind.
    let front: Bool
}

/// Something stuck in her hair: a clip, a bow, or a leaf from the park.
struct HairClip: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case bow, flower, star, heart, butterfly, pearl, daisy, ribbon, leaf, twig
    }
    var kind: Kind
    var color: Int
    var strand: Int
    var node: Int
    var dx: CGFloat
    var dy: CGFloat
    var tilt: CGFloat = 0
}

/// A scrunchie: every lock that passed near it is held at one point.
struct HairTie {
    struct Member { let strand: Int; let node: Int; let off: HairV }
    var at: HairV
    var color: Int
    var members: [Member]
}

/// A shampoo bubble riding on a point of a lock.
struct HairBubble {
    var strand: Int
    var node: Int
    var off: HairV
    var r: CGFloat
    var target: CGFloat
}

/// A glitter flake stuck to the hair.
struct HairFlake {
    var strand: Int
    var node: Int
    var off: HairV
    var color: RGB
    var phase: CGFloat
    var size: CGFloat
}

/// What the client's hair looks like when she walks in.
struct HairRecipe: Codable, Equatable {
    var seed: UInt64
    /// Index into the Dress Up hair palette.
    var color: Int
    /// 0 short, 1 shoulder, 2 long, 3 very long.
    var length: Int
    /// Points of free bangs.
    var fringe: Int
    var curl: Double
    var tangle: Double

    static func random<G: RandomNumberGenerator>(using g: inout G) -> HairRecipe {
        let natural = [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3, 4]
        let fancy = [8, 9, 10, 11, 12, 13, 14, 15, 16]
        let color = Double.random(in: 0..<1, using: &g) < 0.25 ? fancy.randomElement(using: &g)! : natural.randomElement(using: &g)!
        let curlRoll = Double.random(in: 0..<1, using: &g)
        return HairRecipe(seed: UInt64.random(in: 1...UInt64(UInt32.max), using: &g),
                          color: color,
                          length: [1, 2, 2, 3, 3, 2].randomElement(using: &g)!,
                          fringe: Int.random(in: 3...6, using: &g),
                          curl: curlRoll < 0.22 ? Double.random(in: 0.65...1, using: &g) : (curlRoll < 0.4 ? 0.35 : 0),
                          tangle: Double.random(in: 0.55...1, using: &g))
    }
}

// MARK: - The simulation

final class HairSim {
    static let seg: CGFloat = 14
    static let maxFree = 30
    static let maxPieces = 150
    static let maxFoam = 520
    static let maxFlakes = 700
    static let gravity: CGFloat = 1500

    private(set) var recipe: HairRecipe
    var strands: [HairStrand] = []
    var pieces: [HairPiece] = []
    var ties: [HairTie] = []
    var clips: [HairClip] = []
    var foam: [HairBubble] = []
    var flakes: [HairFlake] = []
    /// The blow dryer, while it is on: where the nozzle is and which way it blows.
    var dryer: (at: HairV, dir: HairV)?
    /// Bounding box of each lock, refreshed every step (for water drops).
    private(set) var boxes: [CGRect] = []
    /// Things that fell off the hair during the last step (clips, leaves, bubbles); the effects layer picks them up.
    var dropped: [(clip: HairClip?, at: HairV, vel: HairV, bubble: CGFloat)] = []

    private var rng: SeededGenerator

    init(recipe: HairRecipe, palette: [RGB]) {
        self.recipe = recipe
        rng = SeededGenerator(seed: recipe.seed)
        build(palette: palette)
    }

    // MARK: Building a head of hair

    private func rand(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        CGFloat(Double.random(in: Double(a)...Double(b), using: &rng))
    }

    private func build(palette: [RGB]) {
        let base = palette.isEmpty ? RGB(0.42, 0.27, 0.22) : palette[min(max(recipe.color, 0), palette.count - 1)]
        var out: [HairStrand] = []
        let lengths: [Int] = [3, 9, 17, 24]
        let L = lengths[min(max(recipe.length, 0), 3)]

        // back locks, rooted over the top of her head and lying along the outline down to her ears
        let backCount = 34
        for i in 0..<backCount {
            let u = (CGFloat(i) + 0.5) / CGFloat(backCount)
            let phi = -1.72 + 3.44 * u + rand(-0.03, 0.03)
            let side: CGFloat = phi < 0 ? -1 : 1
            let endPhi = side * rand(1.38, 1.78)
            let endRho = rand(1.0, 1.09)
            var path: [HairV] = [SalonBody.head(phi, 0.9)]
            let steps = 24
            for k in 0...steps {
                let t = CGFloat(k) / CGFloat(steps)
                let th = abs(phi) < abs(endPhi) ? phi + (endPhi - phi) * t : phi
                let rho = 1.02 + (endRho - 1.02) * t
                path.append(SalonBody.head(th, rho))
            }
            let rest = HairSim.resample(path, HairSim.seg)
            let dir = HairV(side * rand(0.15, 0.55), 1).unit
            out.append(makeStrand(.back, rest: rest, dir: dir, free: L + Int(rand(-1.5, 1.5)),
                                  width: rand(22, 27), base: base, order: 1 - abs(phi) / 2))
        }
        // nape: behind her neck, only seen between her jaw and the cape
        for i in 0..<9 {
            let x = 222 + CGFloat(i) * 19.5
            let rest = [HairV(x, 352), HairV(x, 366)]
            out.append(makeStrand(.nape, rest: rest, dir: HairV((x - 300) * 0.004, 1).unit,
                                  free: max(2, L - 6 + Int(rand(-1, 1))), width: rand(24, 28), base: base, order: -1))
        }
        // front locks: from the part over the scalp to the hairline, then bangs or face-framing locks
        let frontCount = 30
        for i in 0..<frontCount {
            let s0 = -1 + 2 * (CGFloat(i) + 0.5) / CGFloat(frontCount)
            let s = max(-1, min(1, s0 + rand(-0.015, 0.015)))
            let h = SalonBody.hairline(s)
            let ex = (h.x - SalonBody.center.x) / SalonBody.rx
            let ey = (SalonBody.center.y - h.y) / SalonBody.ry
            let rhoS = (ex * ex + ey * ey).squareRoot()
            let thS = atan2(ex, ey)
            let th0 = s * 0.12
            let rho0: CGFloat = 0.965
            var path: [HairV] = []
            let steps = 30
            for k in 0...steps {
                let t = CGFloat(k) / CGFloat(steps)
                let th = th0 + (thS - th0) * pow(t, 0.85)
                let rho = rho0 + (rhoS - rho0) * pow(t, 1.7)
                path.append(SalonBody.head(th, rho))
            }
            let rest = HairSim.resample(path, HairSim.seg)
            let fringe = abs(s) < 0.62
            let kind: HairStrand.Kind = fringe ? .fringe : .side
            let side: CGFloat = s < 0 ? -1 : 1
            let dir = fringe ? HairV(s * 0.45, 1).unit : HairV(side * 0.55, 1).unit
            // bangs stop above her eyebrows (they can still be grown longer in the salon)
            let browRoom = max(1, Int((284 - rest[rest.count - 1].y) / HairSim.seg))
            let free = fringe ? min(recipe.fringe + Int(rand(-1, 1.4)), browRoom) : L + 1 + Int(rand(-1.5, 1.5))
            out.append(makeStrand(kind, rest: rest, dir: dir, free: max(1, free), width: rand(20, 25), base: base,
                                  order: 2 - abs(s)))
        }
        strands = out
        boxes = Array(repeating: .zero, count: out.count)
    }

    private func makeStrand(_ kind: HairStrand.Kind, rest: [HairV], dir: HairV, free: Int, width: CGFloat,
                            base: RGB, order: CGFloat) -> HairStrand {
        let n = rest.count + HairSim.maxFree
        // every lock is a slightly different shade, like real hair
        let v = Double(rand(-0.06, 0.06))
        let natural = RGB(min(1, max(0, base.r * (1 + v))), min(1, max(0, base.g * (1 + v))), min(1, max(0, base.b * (1 + v))))
        let jitter = (0..<n).map { _ in rand(-1, 1) }
        var p = rest
        let last = rest[rest.count - 1]
        let count = min(HairSim.maxFree, max(1, free))
        for k in 1...count { p.append(last + dir * (HairSim.seg * CGFloat(k))) }
        var s = HairStrand(kind: kind, rest: rest, dir: dir, width: width, phase: rand(0, 6.28), natural: natural,
                           jitter: jitter, order: order, p: p, o: p,
                           color: Array(repeating: natural, count: n),
                           curl: Array(repeating: CGFloat(recipe.curl), count: n))
        s.tangle = CGFloat(recipe.tangle) * rand(0.6, 1.1)
        return s
    }

    /// Points along `path` every `step` units (always keeps the first and last).
    static func resample(_ path: [HairV], _ step: CGFloat) -> [HairV] {
        guard var prev = path.first else { return [] }
        var out = [prev]
        var carry: CGFloat = 0
        for q in path.dropFirst() {
            var seg = q - prev
            var l = seg.len
            while carry + l >= step {
                let t = (step - carry) / max(l, 0.0001)
                let np = prev + seg * t
                out.append(np)
                prev = np
                seg = q - prev
                l = seg.len
                carry = 0
            }
            carry += l
            prev = q
        }
        if let last = path.last, let o = out.last, o.dist(last) > step * 0.35 { out.append(last) }
        if out.count < 2, let last = path.last { out.append(last + HairV(0, 1)) }
        return out
    }

    /// Lets the hair fall into place (used when a client sits down or a photo is opened).
    func settle(seconds: Double = 2) {
        let n = Int(seconds * 120)
        for _ in 0..<n { step(1.0 / 120) }
    }

    // MARK: Stepping

    /// Advances the hair by `dt` seconds (small steps, so it stays stable).
    func advance(_ dt: Double) {
        let d = min(dt, 1.0 / 20)
        let n = max(1, Int(ceil(d / (1.0 / 120))))
        let h = d / Double(n)
        for _ in 0..<n { step(h) }
    }

    func step(_ hd: Double) {
        let h = CGFloat(hd)
        for i in strands.indices { integrate(&strands[i], h) }
        if moved.count != strands.count { moved = Array(repeating: [], count: strands.count) }
        for i in strands.indices {
            moved[i].removeAll(keepingCapacity: true)
            moved[i].append(contentsOf: repeatElement(HairV.zero, count: strands[i].p.count))
        }
        for _ in 0..<2 {
            for i in strands.indices { HairSim.constrain(&strands[i], moved: &moved[i]) }
            applyTies()
        }
        // follow-the-leader damping: pulling a point after its parent must not throw the parent around,
        // or the lock picks up energy every frame and never comes to rest
        for i in strands.indices {
            let n = strands[i].p.count
            guard n > strands[i].pinned + 1 else { continue }
            for k in strands[i].pinned..<(n - 1) { strands[i].o[k] += moved[i][k + 1] * 0.9 }
        }
        for i in strands.indices { boxes[i] = HairSim.box(strands[i]) }
        stepPieces(hd)
        stepFoam(h)
    }

    /// Scratch space for `step`: how far the constraints moved each point this step.
    private var moved: [[HairV]] = []

    private func windAccel(_ p: HairV, _ w: (at: HairV, dir: HairV)) -> HairV {
        let r = p - w.at
        let along = r.dot(w.dir)
        guard along > 0, along < 430 else { return .zero }
        let side = r - w.dir * along
        let perp = side.len
        let cone = 26 + along * 0.45
        guard perp < cone else { return .zero }
        let f = (1 - along / 430) * (1 - perp / cone)
        let gust = 0.7 + 0.6 * CGFloat(Double.random(in: 0..<1, using: &rng))
        let flutter = w.dir.perp * (CGFloat(Double.random(in: -1..<1, using: &rng)) * 2600 * f)
        return w.dir * (6400 * f * gust) + side.unit * (1500 * f) + flutter
    }

    private func integrate(_ s: inout HairStrand, _ h: CGFloat) {
        let P = s.pinned
        for i in 0..<P {
            s.p[i] = s.rest[i]
            s.o[i] = s.rest[i]
        }
        let damp: CGFloat = 0.986 - 0.025 * s.wet
        let g = HairV(0, HairSim.gravity * (1 + 0.45 * s.wet) * h * h)
        let w = dryer
        for i in P..<s.p.count {
            let cur = s.p[i]
            var v = (cur - s.o[i]) * damp
            let vl = v.len
            if vl > 26 { v = v * (26 / vl) }
            if let top = SalonBody.capeTop(cur.x), s.front, cur.y > top - 2 { v = v * 0.86 }
            if cur.y > SalonBody.floorY - 1 { v = v * 0.6 }
            s.o[i] = cur
            var a = g
            if let w { a += windAccel(cur, w) * (h * h) }
            s.p[i] = cur + v + a
        }
    }

    /// Follow-the-leader: each point is bent toward the lock's shape, put back exactly one segment from
    /// its parent, then kept out of her head, face and cape. Parents are never moved by their children,
    /// so nothing fights and the hair settles to a standstill.
    private static func constrain(_ s: inout HairStrand, moved: inout [HairV]) {
        let P = s.pinned
        let n = s.p.count
        guard n > P else { return }
        let wetLimp = 1 - 0.45 * s.wet
        let root = s.rest[P - 1]
        for i in P..<n {
            let a = s.p[i - 1]
            let before = i >= 2 ? s.p[i - 2] : a - s.dir
            var d = (a - before).unit
            let t = CGFloat(i - P) / CGFloat(HairSim.maxFree)
            let keep: CGFloat = s.kind == .fringe ? 0.6 : 0.45
            let shapeK = keep * (1 - t) * (1 - t) * wetLimp
            d = (d * (1 - shapeK) + s.dir * shapeK).unit
            let L = s.segLen(i)
            let target = a + d * L
            let c = s.curlNow(i)
            let bend = (0.1 + 0.24 * c + (s.kind == .fringe ? 0.12 : 0)) * wetLimp
            var q = s.p[i] + (target - s.p[i]) * bend
            // collisions ease in over the first points of a back lock, whose root is inside the outline
            let ramp = min(1, CGFloat(i - P + 1) / 5)
            for _ in 0..<2 {
                let dq = q - a
                let l = dq.len
                q = l > 0.0001 ? a + dq * (L / l) : a + d * L
                switch s.kind {
                case .back:
                    SalonBody.pushOutOfHead(&q, k: 1.035 * ramp)
                case .side:
                    SalonBody.keepOffFace(&q, root: root)
                    SalonBody.pushOutOfCape(&q)
                case .fringe:
                    SalonBody.pushOutOfCape(&q)
                case .nape:
                    break
                }
                if q.y > SalonBody.floorY { q.y = SalonBody.floorY }
                q.x = max(-300, min(900, q.x))
            }
            if i < moved.count { moved[i] += q - s.p[i] }
            s.p[i] = q
        }
    }

    private func applyTies() {
        for t in ties {
            for m in t.members where m.strand < strands.count {
                let s = strands[m.strand]
                guard m.node >= s.pinned, m.node < s.p.count else { continue }
                strands[m.strand].p[m.node] = t.at + m.off
            }
        }
    }

    private static func box(_ s: HairStrand) -> CGRect {
        var minX = CGFloat.greatestFiniteMagnitude, minY = minX
        var maxX = -minX, maxY = -minX
        for q in s.p {
            minX = min(minX, q.x); maxX = max(maxX, q.x)
            minY = min(minY, q.y); maxY = max(maxY, q.y)
        }
        let pad = s.width * 0.6 + 4
        return CGRect(x: minX - pad, y: minY - pad, width: maxX - minX + pad * 2, height: maxY - minY + pad * 2)
    }

    // MARK: Cut pieces

    private func stepPieces(_ hd: Double) {
        let h = CGFloat(hd)
        let g = HairV(0, HairSim.gravity * 0.9 * h * h)
        for k in pieces.indices {
            pieces[k].age += hd
            if pieces[k].asleep { continue }
            var fastest: CGFloat = 0
            let n = pieces[k].p.count
            for i in 0..<n {
                let cur = pieces[k].p[i]
                var v = (cur - pieces[k].o[i]) * 0.99
                if cur.y >= SalonBody.floorY - 0.5 { v = HairV(v.x * 0.55, v.y) }
                if let top = SalonBody.capeTop(cur.x), cur.y > top - 2, cur.y < SalonBody.capeBottom { v = v * 0.93 }
                fastest = max(fastest, v.len)
                pieces[k].o[i] = cur
                pieces[k].p[i] = cur + v + g
            }
            for _ in 0..<2 {
                for i in 1..<max(1, n) {
                    let a = pieces[k].p[i - 1]
                    let b = pieces[k].p[i]
                    let d = b - a
                    let l = d.len
                    let L = HairSim.seg * (1 - 0.4 * pieces[k].curl[i] * (1 - 0.7 * pieces[k].wet))
                    guard l > 0.0001 else { continue }
                    let corr = d * ((l - L) / l * 0.5)
                    pieces[k].p[i - 1] = a + corr
                    pieces[k].p[i] = b - corr
                }
                for i in 0..<n {
                    var q = pieces[k].p[i]
                    if pieces[k].front { SalonBody.pushOutOfCape(&q) } else if q.y > SalonBody.floorY { q.y = SalonBody.floorY }
                    pieces[k].p[i] = q
                }
            }
            if fastest < 0.12 {
                pieces[k].still += hd
                if pieces[k].still > 0.7 { pieces[k].asleep = true }
            } else {
                pieces[k].still = 0
            }
        }
        if pieces.count > HairSim.maxPieces { pieces.removeFirst(pieces.count - HairSim.maxPieces) }
    }

    // MARK: Foam

    private func stepFoam(_ h: CGFloat) {
        guard !foam.isEmpty else { return }
        var keep: [HairBubble] = []
        keep.reserveCapacity(foam.count)
        for var b in foam {
            guard b.strand < strands.count, b.node < strands[b.strand].p.count else {
                dropped.append((nil, HairV(0, 0), HairV(0, 0), b.r))
                continue
            }
            b.r += (b.target - b.r) * min(1, h * 8)
            keep.append(b)
        }
        foam = keep
    }

    func position(_ strand: Int, _ node: Int) -> HairV? {
        guard strand >= 0, strand < strands.count, node >= 0, node < strands[strand].p.count else { return nil }
        return strands[strand].p[node]
    }

    /// The point of hair nearest to `q`, within `radius`.
    func nearestNode(_ q: HairV, radius: CGFloat, frontOnly: Bool = false) -> (strand: Int, node: Int, d: CGFloat)? {
        var best: (Int, Int, CGFloat)?
        for (si, s) in strands.enumerated() {
            if frontOnly && !s.front { continue }
            guard boxes.indices.contains(si), boxes[si].insetBy(dx: -radius, dy: -radius).contains(q.cg) else { continue }
            for (i, p) in s.p.enumerated() {
                let d = p.dist(q)
                if d < radius && d < (best?.2 ?? .greatestFiniteMagnitude) { best = (si, i, d) }
            }
        }
        return best.map { (strand: $0.0, node: $0.1, d: $0.2) }
    }

    // MARK: Tools

    /// The comb (or her finger) moves from a to b. Returns how many locks it caught.
    @discardableResult
    func comb(from a: HairV, to b: HairV, radius: CGFloat, detangle: CGFloat) -> Int {
        let mv = b - a
        guard mv.len > 0.3 else { return 0 }
        var caught = 0
        for si in strands.indices {
            let P = strands[si].pinned
            var hit = false
            for i in P..<strands[si].p.count {
                let q = strands[si].p[i]
                let d = q.distToSegment(a, b)
                guard d < radius else { continue }
                let f = 1 - d / radius
                strands[si].p[i] = q + mv * (0.6 * f)
                hit = true
            }
            if hit {
                caught += 1
                strands[si].tangle = max(0, strands[si].tangle - detangle)
            }
        }
        if detangle > 0 { knockLoose(near: b, radius: radius + 10, chance: 0.12) }
        return caught
    }

    /// Leaves and twigs fall out when the comb, towel or water gets them.
    func knockLoose(near q: HairV, radius: CGFloat, chance: Double) {
        var keep: [HairClip] = []
        for c in clips {
            if (c.kind == .leaf || c.kind == .twig), let at = position(c.strand, c.node), at.dist(q) < radius,
               Double.random(in: 0..<1, using: &rng) < chance {
                dropped.append((c, at + HairV(c.dx, c.dy), HairV(rand(-2, 2), rand(-3, 0)), 0))
            } else {
                keep.append(c)
            }
        }
        clips = keep
    }

    /// The scissors close along a-b. Returns the points where hair was cut.
    func cut(from a: HairV, to b: HairV) -> [HairV] {
        var cuts: [HairV] = []
        for si in strands.indices {
            let s = strands[si]
            let P = s.pinned
            let n = s.p.count
            guard n - P >= 2 else { continue }
            var at: Int?
            for i in (P + 1)..<n where HairSim.intersects(a, b, s.p[i - 1], s.p[i]) {
                at = i
                break
            }
            guard let c = at else { continue }
            cuts.append(s.p[c])
            detach(si, from: c, kick: (b - a).unit)
        }
        return cuts
    }

    private func detach(_ si: Int, from c: Int, kick: HairV) {
        let s = strands[si]
        let n = s.p.count
        let range = (c - 1)..<n
        var piece = HairPiece(p: Array(s.p[range]), o: Array(s.o[range]), color: Array(s.color[range]),
                              curl: Array(s.curl[range]), width: s.width * 0.92, phase: s.phase,
                              jitter: Array(s.jitter[range]), tangle: s.tangle, wet: s.wet, front: s.front)
        let push = kick * rand(0.4, 1.2) + HairV(rand(-0.6, 0.6), rand(-1.2, -0.2))
        for i in piece.o.indices { piece.o[i] = piece.o[i] - push * (CGFloat(i) / CGFloat(max(1, piece.o.count)) + 0.3) }
        pieces.append(piece)
        strands[si].p.removeLast(n - c)
        strands[si].o.removeLast(n - c)
        strands[si].growth = 0

        // whatever was on the cut part falls with it
        var keep: [HairClip] = []
        for cl in clips {
            if cl.strand == si && cl.node >= c, cl.node < n {
                dropped.append((cl, s.p[cl.node] + HairV(cl.dx, cl.dy), s.p[cl.node] - s.o[cl.node], 0))
            } else {
                keep.append(cl)
            }
        }
        clips = keep
        flakes.removeAll { $0.strand == si && $0.node >= c }
        for t in ties.indices { ties[t].members.removeAll { $0.strand == si && $0.node >= c } }
        dropTiesWithoutHair()
    }

    func dropTiesWithoutHair() {
        ties.removeAll { $0.members.count < 2 }
    }

    static func intersects(_ a: HairV, _ b: HairV, _ c: HairV, _ d: HairV) -> Bool {
        func cross(_ u: HairV, _ v: HairV) -> CGFloat { u.x * v.y - u.y * v.x }
        let r = b - a, s = d - c
        let den = cross(r, s)
        guard abs(den) > 0.0001 else { return false }
        let t = cross(c - a, s) / den
        let u = cross(c - a, r) / den
        return t >= 0 && t <= 1 && u >= 0 && u <= 1
    }

    /// The grow potion: locks near q get longer. Returns true if any grew.
    func grow(near q: HairV, radius: CGFloat, dt: CGFloat) -> Bool {
        var any = false
        for si in strands.indices where strands[si].free < HairSim.maxFree {
            let s = strands[si]
            guard s.p.contains(where: { $0.dist(q) < radius }) else { continue }
            strands[si].growth += dt * 9
            while strands[si].growth >= 1 && strands[si].free < HairSim.maxFree {
                strands[si].growth -= 1
                let t = strands[si]
                let n = t.p.count
                let tip = t.p[n - 1]
                let d = n >= 2 ? (tip - t.p[n - 2]).unit : t.dir
                let np = tip + d * (HairSim.seg * 0.6)
                strands[si].p.append(np)
                strands[si].o.append(np)
                strands[si].color[n] = t.natural
                strands[si].curl[n] = t.curl[n - 1]
                any = true
            }
        }
        return any
    }

    /// Points within `radius` of q, with how close they are (1 at q, 0 at the edge).
    func touch(_ q: HairV, radius: CGFloat, freeOnly: Bool, _ body: (Int, Int, CGFloat) -> Void) {
        for si in strands.indices {
            guard boxes[si].insetBy(dx: -radius, dy: -radius).contains(q.cg) else { continue }
            let start = freeOnly ? strands[si].pinned : 0
            for i in start..<strands[si].p.count {
                let d = strands[si].p[i].dist(q)
                if d < radius { body(si, i, 1 - d / radius) }
            }
        }
    }

    func curlUp(_ q: HairV, dt: CGFloat) -> Int {
        var n = 0
        touch(q, radius: 34, freeOnly: true) { si, i, f in
            strands[si].curl[i] = min(1, strands[si].curl[i] + dt * 2.6 * (0.4 + f))
            strands[si].wet = max(0, strands[si].wet - dt * 0.4)
            n += 1
        }
        return n
    }

    func straighten(_ q: HairV, dt: CGFloat) -> Int {
        var n = 0
        touch(q, radius: 38, freeOnly: true) { si, i, f in
            strands[si].curl[i] = max(0, strands[si].curl[i] - dt * 3.2 * (0.4 + f))
            strands[si].tangle = max(0, strands[si].tangle - dt * 1.5)
            strands[si].gloss = min(1, strands[si].gloss + dt * 1.2)
            strands[si].wet = max(0, strands[si].wet - dt * 0.4)
            n += 1
        }
        return n
    }

    func dye(_ q: HairV, dt: CGFloat, color: (HairV) -> RGB) -> Int {
        var n = 0
        touch(q, radius: 38, freeOnly: false) { si, i, f in
            let c = color(strands[si].p[i])
            let k = Double(min(1, dt * 7 * (0.3 + f)))
            strands[si].color[i] = strands[si].color[i].mix(c, k)
            n += 1
        }
        return n
    }

    func towel(_ q: HairV, dt: CGFloat) -> Int {
        var touched = Set<Int>()
        touch(q, radius: 56, freeOnly: true) { si, i, f in
            touched.insert(si)
            strands[si].p[i] += HairV(rand(-2.5, 2.5), rand(-2.5, 2.5)) * f
        }
        for si in touched {
            strands[si].wet = max(0, strands[si].wet - dt * 1.4)
            strands[si].tangle = min(1, strands[si].tangle + dt * 0.25)
        }
        let before = foam.count
        foam.removeAll { b in position(b.strand, b.node).map { ($0 + b.off).dist(q) < 60 } ?? true }
        if foam.count < before { dropped.append((nil, q, HairV(0, 0), CGFloat(before - foam.count))) }
        knockLoose(near: q, radius: 60, chance: 0.05)
        return touched.count
    }

    func makeWet(_ si: Int, _ amount: CGFloat) {
        guard strands.indices.contains(si) else { return }
        strands[si].wet = min(1, strands[si].wet + amount)
    }

    /// Shampoo: bubbles grow on the hair under q. Returns how many bubbles were added.
    func lather(_ q: HairV, dt: CGFloat) -> Int {
        var added = 0
        var grew = 0
        for k in foam.indices {
            guard let at = position(foam[k].strand, foam[k].node) else { continue }
            if (at + foam[k].off).dist(q) < 46 {
                foam[k].target = min(17, foam[k].target + dt * 9)
                grew += 1
            }
        }
        guard foam.count < HairSim.maxFoam else { return 0 }
        var spots: [(Int, Int)] = []
        touch(q, radius: 50, freeOnly: false) { si, i, _ in spots.append((si, i)) }
        guard !spots.isEmpty else { return 0 }
        let tries = grew > 30 ? 1 : 3
        for _ in 0..<tries {
            let (si, i) = spots[Int.random(in: 0..<spots.count, using: &rng)]
            let w = strands[si].width * 0.6
            foam.append(HairBubble(strand: si, node: i, off: HairV(rand(-w, w), rand(-w, w)), r: 1.5, target: rand(6, 13)))
            added += 1
        }
        return added
    }

    /// Water washes foam away near q. Returns how much foam came off.
    func rinse(_ q: HairV, radius: CGFloat) -> Int {
        var off = 0
        var keep: [HairBubble] = []
        for b in foam {
            if let at = position(b.strand, b.node), (at + b.off).dist(q) < radius + b.r, Double.random(in: 0..<1, using: &rng) < 0.35 {
                dropped.append((nil, at + b.off, HairV(0, 0), b.r))
                off += 1
            } else {
                keep.append(b)
            }
        }
        foam = keep
        knockLoose(near: q, radius: radius, chance: 0.02)
        return off
    }

    func sprinkleGlitter(_ q: HairV, color: RGB) -> Int {
        guard flakes.count < HairSim.maxFlakes else { return 0 }
        var spots: [(Int, Int)] = []
        touch(q, radius: 48, freeOnly: false) { si, i, _ in spots.append((si, i)) }
        guard !spots.isEmpty else { return 0 }
        for _ in 0..<2 {
            let (si, i) = spots[Int.random(in: 0..<spots.count, using: &rng)]
            let w = strands[si].width * 0.5
            flakes.append(HairFlake(strand: si, node: i, off: HairV(rand(-w, w), rand(-w, w)), color: color,
                                    phase: rand(0, 6.28), size: rand(2.2, 4.4)))
        }
        return 2
    }

    // MARK: Clips and scrunchies

    /// Puts a clip on the hair at q. Returns false if there is no hair there.
    func attach(_ kind: HairClip.Kind, color: Int, at q: HairV) -> Bool {
        guard let hit = nearestNode(q, radius: 46) else { return false }
        let at = strands[hit.strand].p[hit.node]
        clips.append(HairClip(kind: kind, color: color, strand: hit.strand, node: hit.node, dx: q.x - at.x, dy: q.y - at.y,
                              tilt: rand(-0.35, 0.35)))
        return true
    }

    func clipPosition(_ c: HairClip) -> HairV? {
        position(c.strand, c.node).map { $0 + HairV(c.dx, c.dy) }
    }

    /// Ties a scrunchie at q around every lock that passes close by. Returns false if too little hair is there.
    func tie(at q: HairV, color: Int) -> Bool {
        var members: [HairTie.Member] = []
        for (si, s) in strands.enumerated() {
            if ties.contains(where: { t in t.members.contains { m in m.strand == si } }) { continue }
            var best: (Int, CGFloat)?
            for i in s.pinned..<s.p.count {
                let d = s.p[i].dist(q)
                if d < 78 && d < (best?.1 ?? .greatestFiniteMagnitude) { best = (i, d) }
            }
            if let b = best {
                let a = rand(0, 6.28)
                let r = rand(0, 9)
                members.append(HairTie.Member(strand: si, node: b.0, off: HairV(cos(a) * r, sin(a) * r * 0.6)))
            }
        }
        guard members.count >= 3 else { return false }
        ties.append(HairTie(at: q, color: color, members: members))
        return true
    }

    // MARK: Saving

    struct StrandSave: Codable {
        /// Free points.
        var n: Int
        /// Run-length colors: count, 0xRRGGBB, count, 0xRRGGBB...
        var colors: [UInt32]
        /// Run-length curl in 1/20ths: count, value...
        var curls: [Int]
        var wet: Double
        var tangle: Double
        var gloss: Double
        /// Free point positions, x and y, rounded (photos only).
        var pts: [Int16]?
    }

    struct TieSave: Codable {
        var x: Double
        var y: Double
        var color: Int
    }

    struct Save: Codable {
        var recipe: HairRecipe
        var strands: [StrandSave]
        var clips: [HairClip]
        var ties: [TieSave]
    }

    func save(positions: Bool) -> Save {
        let ss: [StrandSave] = strands.map { s in
            var colors: [UInt32] = []
            var curls: [Int] = []
            for c in s.color {
                let hex = HairSim.hex(c)
                if colors.count >= 2 && colors[colors.count - 1] == hex { colors[colors.count - 2] += 1 } else { colors += [1, hex] }
            }
            for c in s.curl {
                let q = Int((c * 20).rounded())
                if curls.count >= 2 && curls[curls.count - 1] == q { curls[curls.count - 2] += 1 } else { curls += [1, q] }
            }
            var pts: [Int16]?
            if positions {
                pts = s.p.dropFirst(s.pinned).flatMap { [HairSim.q16($0.x), HairSim.q16($0.y)] }
            }
            return StrandSave(n: s.free, colors: colors, curls: curls, wet: Double(s.wet), tangle: Double(s.tangle),
                              gloss: Double(s.gloss), pts: pts)
        }
        return Save(recipe: recipe, strands: ss, clips: clips,
                    ties: ties.map { TieSave(x: Double($0.at.x), y: Double($0.at.y), color: $0.color) })
    }

    /// Rebuilds hair from a save. Positions come back if saved, otherwise the hair is settled again.
    convenience init(save: Save, palette: [RGB], settle: Bool = true) {
        self.init(recipe: save.recipe, palette: palette)
        var hadPositions = false
        for (si, ss) in save.strands.enumerated() where si < strands.count {
            var s = strands[si]
            let P = s.pinned
            let n = min(HairSim.maxFree, max(1, ss.n))
            var colors: [RGB] = []
            var k = 0
            while k + 1 < ss.colors.count {
                let run = Int(ss.colors[k])
                let c = HairSim.rgb(ss.colors[k + 1])
                colors += Array(repeating: c, count: max(0, min(run, 400)))
                k += 2
            }
            var curls: [CGFloat] = []
            k = 0
            while k + 1 < ss.curls.count {
                curls += Array(repeating: CGFloat(ss.curls[k + 1]) / 20, count: max(0, min(ss.curls[k], 400)))
                k += 2
            }
            for i in 0..<s.maxNodes {
                if i < colors.count { s.color[i] = colors[i] }
                if i < curls.count { s.curl[i] = max(0, min(1, curls[i])) }
            }
            var p = Array(s.rest)
            let last = s.rest[P - 1]
            if let pts = ss.pts, pts.count >= n * 2 {
                for j in 0..<n { p.append(HairV(CGFloat(pts[j * 2]), CGFloat(pts[j * 2 + 1]))) }
                hadPositions = true
            } else {
                for j in 1...n { p.append(last + s.dir * (HairSim.seg * CGFloat(j))) }
            }
            s.p = p
            s.o = p
            s.wet = CGFloat(max(0, min(1, ss.wet)))
            s.tangle = CGFloat(max(0, min(1, ss.tangle)))
            s.gloss = CGFloat(max(0, min(1, ss.gloss)))
            strands[si] = s
        }
        boxes = strands.map(HairSim.box)
        clips = save.clips.filter { $0.strand < strands.count && $0.node < strands[$0.strand].p.count }
        for t in save.ties { _ = tie(at: HairV(CGFloat(t.x), CGFloat(t.y)), color: t.color) }
        if settle && !hadPositions { self.settle(seconds: 2) }
    }

    static func q16(_ v: CGFloat) -> Int16 { Int16(max(-30000, min(30000, v.rounded()))) }

    static func hex(_ c: RGB) -> UInt32 {
        func b(_ v: Double) -> UInt32 { UInt32(max(0, min(255, (v * 255).rounded()))) }
        return (b(c.r) << 16) | (b(c.g) << 8) | b(c.b)
    }

    static func rgb(_ v: UInt32) -> RGB {
        RGB(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }
}
