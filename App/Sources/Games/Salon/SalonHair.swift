import CoreGraphics
import Foundation

// MARK: - Salon hair: real strands with physics
//
// Her client's hair is 70 guide locks in 3D around her head. Each lock is a chain of points 14 units
// apart (Dress Up doll coordinates, 600 x 900, so the Dress Up face art lines up; z points out of the
// screen toward her, 0 through the middle of her head). The first points of a lock lie on the scalp and
// turn with her head; the rest is free hair, simulated with Verlet integration and position-based
// constraints (several passes a step, both ends of a segment giving way, so it never whips and comes to
// a standstill): gravity, damping, fixed segment lengths, a little shape near the roots only, and
// collisions with her head (an ellipsoid), her face, her shoulders and the cape.
//
// The guides themselves are never drawn: `HairPainter` draws fine strands blended between every two
// neighbouring guides, so what she sees is one soft head of real-looking hair.
//
// x and y of every point are where it is on screen, so every tool works on what she sees. When she
// turns the chair (`yaw`), the scalp points rotate around her head and the free hair swings after them.
//
//   back locks   run from her crown down the back of her head
//   side locks   frame her face and drape over the cape in front
//   fringe locks the bangs
//
// Everything a tool does is a change to the locks: the iron glides points along (and smooths tangles), the
// scissors cut a chain where a stroke crosses it and the cut end becomes a `HairPiece` that falls
// with its own physics, water makes hair heavy, dark and limp, the dryer blows a cone of wind, the
// curling iron raises a per-point curl (curls also shorten the chain, so curled hair springs up),
// the straightener takes it away, dye mixes the color of each point it touches, and the grow potion
// adds points at the tips. A scrunchie gathers the locks around it to one spot: a ponytail, which a
// tap turns into a braid (the hair below it is pulled into one rope) or a bun. A clip or bow holds its
// bit of hair where it was clipped.

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

/// A 3D point or direction for the hair (z out of the screen).
struct H3 {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) { self.x = x; self.y = y; self.z = z }
    init(_ v: HairV, _ z: CGFloat) { x = v.x; y = v.y; self.z = z }

    var xy: HairV { HairV(x, y) }
    var len: CGFloat { (x * x + y * y + z * z).squareRoot() }
    var unit: H3 {
        let l = len
        return l > 0.00001 ? H3(x / l, y / l, z / l) : H3(0, 1, 0)
    }
    static func + (a: H3, b: H3) -> H3 { H3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: H3, b: H3) -> H3 { H3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (a: H3, k: CGFloat) -> H3 { H3(a.x * k, a.y * k, a.z * k) }
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

    /// Her shoulders and the cape look narrower as she turns sideways.
    static func bodyScale(_ yaw: CGFloat) -> CGFloat { 0.6 + 0.4 * abs(cos(yaw)) }
    /// How far her shoulders reach in front of and behind the middle of her head.
    static let bodyDepth: CGFloat = 70

    /// A point on her scalp in head-local coordinates (relative to the head center, facing front):
    /// polar angle from the top of her head, longitude from her nose toward screen right.
    static func sphere(_ polar: CGFloat, _ lon: CGFloat, _ k: CGFloat = 1) -> H3 {
        H3(rx * k * sin(polar) * sin(lon), -ry * k * cos(polar), rx * k * sin(polar) * cos(lon))
    }

    /// How far in front of the middle of her head the front of the scalp is at screen point (x, y), facing front.
    static func frontZ(_ x: CGFloat, _ y: CGFloat, _ k: CGFloat = 1) -> CGFloat {
        let ex = (x - center.x) / rx
        let ey = (y - center.y) / ry
        return rx * max(0, k * k - ex * ex - ey * ey).squareRoot()
    }

    /// Head-local to screen (and depth), with her turned by `yaw`.
    static func toWorld(_ l: H3, _ yaw: CGFloat) -> H3 {
        let c = cos(yaw), s = sin(yaw)
        return H3(center.x + l.x * c + l.z * s, center.y + l.y, -l.x * s + l.z * c)
    }

    static func toLocal(_ w: H3, _ yaw: CGFloat) -> H3 {
        let c = cos(yaw), s = sin(yaw)
        let x = w.x - center.x
        return H3(x * c - w.z * s, w.y - center.y, x * s + w.z * c)
    }

    static func rotate(_ d: H3, _ yaw: CGFloat) -> H3 {
        let c = cos(yaw), s = sin(yaw)
        return H3(d.x * c + d.z * s, d.y, -d.x * s + d.z * c)
    }

    /// Pushes a 3D point out of the ellipsoid around her head scaled by `k`.
    static func pushOutOfHead(_ p: inout HairV, _ z: inout CGFloat, k: CGFloat) {
        let ex = (p.x - center.x) / (rx * k)
        let ey = (p.y - center.y) / (ry * k)
        let ez = z / (rx * k)
        let r2 = ex * ex + ey * ey + ez * ez
        guard r2 < 1, r2 > 0.000001 else { return }
        let r = r2.squareRoot()
        p = HairV(center.x + ex / r * rx * k, center.y + ey / r * ry * k)
        z = ez / r * rx * k
    }

    /// Keeps a 3D point out of her shoulders: onto the cape (sliding down its slope), or in front of or
    /// behind her, whichever is nearer. Also the floor.
    static func pushOutOfBody(_ p: inout HairV, _ z: inout CGFloat, squash: CGFloat) {
        if let top = capeTop(p.x, squash: squash), p.y > top, p.y < capeBottom + 30, abs(z) < bodyDepth {
            let m = capeSlope(p.x, squash: squash)
            let depth = p.y - top
            let k = 1 / (1 + m * m)
            if depth * k < bodyDepth - abs(z) {
                p.y -= depth * k
                p.x += m * depth * k
            } else {
                z = z < 0 ? -bodyDepth : bodyDepth
            }
        }
        if p.y > floorY { p.y = floorY }
    }

    /// Side locks frame her face: in her own (turned) frame they stay outside it, easing out from their
    /// root over the first 60 points so they are never shoved sideways.
    static func keepOffFace(_ p: inout HairV, _ z: inout CGFloat, root: H3, yaw: CGFloat) {
        let l = toLocal(H3(p, z), yaw)
        guard l.z > -20 else { return }
        let side: CGFloat = root.x < 0 ? -1 : 1
        let ey = max(-1, min(0, l.y / ry))
        let edge = side * rx * (1 - ey * ey).squareRoot()
        let u = max(0, min(1, (l.y - root.y) / 60))
        let w = u * u * (3 - 2 * u)
        let limit = root.x + (edge - root.x) * w
        var x = l.x
        if side < 0, x > limit { x = limit }
        if side > 0, x < limit { x = limit }
        guard x != l.x else { return }
        let back = toWorld(H3(x, l.y, l.z), yaw)
        p = back.xy
        z = back.z
    }

    /// Whether hair at this screen point and depth can be seen (not hidden behind her head or shoulders).
    static func visible(_ p: HairV, _ z: CGFloat, squash: CGFloat = 1) -> Bool {
        if z > -30 { return true }
        let ex = (p.x - center.x) / rx
        let ey = (p.y - center.y) / ry
        if ex * ex + ey * ey < 1 { return false }
        if let top = capeTop(p.x, squash: squash), p.y > top - 10 { return false }
        return true
    }

    /// The top of the salon cape at x, or nil where there is no cape.
    static func capeTop(_ x: CGFloat, squash: CGFloat = 1) -> CGFloat? {
        let d = abs(x - 300) / squash
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

    static func capeSlope(_ x: CGFloat, squash: CGFloat = 1) -> CGFloat {
        let d = abs(x - 300) / squash
        let s: CGFloat = (d <= 34 ? 0 : (d <= 100 ? 0.6 : 2.4)) / squash
        return x < 300 ? -s : s
    }

    /// Keeps `p` on top of the cape (sliding along its slope) and above the floor. Returns true on contact.
    @discardableResult
    static func pushOutOfCape(_ p: inout HairV, squash: CGFloat = 1) -> Bool {
        var hit = false
        if let top = capeTop(p.x, squash: squash), p.y > top, p.y < capeBottom + 30 {
            let m = capeSlope(p.x, squash: squash)
            let depth = p.y - top
            let k = 1 / (1 + m * m)
            p.y -= depth * k
            p.x += m * depth * k
            hit = true
        }
        if p.y > floorY { p.y = floorY; hit = true }
        return hit
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
    /// The scalp part, root first, in head-local coordinates. These points only move when she turns.
    let restL: [H3]
    /// Which way the free hair leaves the scalp, head-local.
    let dirL: H3
    /// The scalp part and the direction where they are now (screen x, y and depth z).
    var rest: [HairV]
    var restZ: [CGFloat]
    var dir: H3
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
    /// Depth of each point (and where it was last step).
    var z: [CGFloat]
    var oz: [CGFloat]
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
    /// Average depth: locks behind the middle of her head are drawn behind her.
    var depth: CGFloat {
        var t: CGFloat = 0
        for v in z { t += v }
        return t / CGFloat(max(1, z.count))
    }

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
    /// Where a clip holds its bit of hair (clips and bows hold hair in place; leaves and twigs just ride along).
    var hx: CGFloat?
    var hy: CGFloat?

    var holds: Bool { kind != .leaf && kind != .twig }
}

/// A scrunchie: every lock gathered into it is held at one point, which turns with her head.
struct HairTie {
    enum Style: String, Codable, CaseIterable {
        case pony, braid, bun
        var next: Style { Style.allCases[(Style.allCases.firstIndex(of: self)! + 1) % Style.allCases.count] }
    }
    struct Member { let strand: Int; let node: Int; let off: HairV }
    var at: HairV
    var z: CGFloat
    /// Where it sits on her head, head-local.
    var local: H3
    var color: Int
    var members: [Member]
    var style: Style = .pony
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
    /// How far she is turned around (0 facing us, pi her back to us).
    var yaw: CGFloat = 0
    var squash: CGFloat { SalonBody.bodyScale(yaw) }
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

        // back locks: from her crown down the back of her head to the nape, and to above her ears at the sides
        let backCount = 40
        for i in 0..<backCount {
            let u = (CGFloat(i) + 0.5) / CGFloat(backCount)
            let lon = CGFloat.pi * (0.5 + u) + rand(-0.02, 0.02)
            let a = min(1, abs(lon - .pi) / (.pi / 2))
            let end = 2.1 - 0.62 * pow(a, 1.4) + rand(-0.05, 0.05)
            let start = 0.16 + rand(0, 0.06)
            var path: [H3] = []
            for k in 0...30 {
                let t = CGFloat(k) / 30
                path.append(SalonBody.sphere(start + (end - start) * t, lon))
            }
            let rest = HairSim.resample3(path, HairSim.seg)
            let dir = H3(sin(lon) * 0.35, 1, cos(lon) * 0.35).unit
            out.append(makeStrand(.back, rest: rest, dir: dir, free: L + Int(rand(-1.5, 1.5)),
                                  width: rand(22, 27), base: base, order: u, phase: CGFloat(i) * 0.45))
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
            var path: [H3] = []
            let steps = 30
            for k in 0...steps {
                let t = CGFloat(k) / CGFloat(steps)
                let th = th0 + (thS - th0) * pow(t, 0.85)
                let rho = rho0 + (rhoS - rho0) * pow(t, 1.7)
                let q = SalonBody.head(th, rho)
                path.append(H3(q.x - SalonBody.center.x, q.y - SalonBody.center.y, SalonBody.frontZ(q.x, q.y)))
            }
            let rest = HairSim.resample3(path, HairSim.seg)
            let fringe = abs(s) < 0.62
            let kind: HairStrand.Kind = fringe ? .fringe : .side
            let side: CGFloat = s < 0 ? -1 : 1
            let dir = fringe ? H3(s * 0.45, 1, 0.25).unit : H3(side * 0.55, 1, 0.1).unit
            // bangs stop above her eyebrows (they can still be grown longer in the salon)
            let browRoom = max(1, Int((284 - (rest[rest.count - 1].y + SalonBody.center.y)) / HairSim.seg))
            let free = fringe ? min(recipe.fringe + Int(rand(-1, 1.4)), browRoom) : L + 1 + Int(rand(-1.5, 1.5))
            out.append(makeStrand(kind, rest: rest, dir: dir, free: max(1, free), width: rand(20, 25), base: base,
                                  order: 2 - abs(s), phase: 1 + CGFloat(i) * 0.45))
        }
        strands = out
        boxes = Array(repeating: .zero, count: out.count)
    }

    private func makeStrand(_ kind: HairStrand.Kind, rest restL: [H3], dir dirL: H3, free: Int, width: CGFloat,
                            base: RGB, order: CGFloat, phase: CGFloat) -> HairStrand {
        let n = restL.count + HairSim.maxFree
        // every lock is a slightly different shade, like real hair
        let v = Double(rand(-0.06, 0.06))
        let natural = RGB(min(1, max(0, base.r * (1 + v))), min(1, max(0, base.g * (1 + v))), min(1, max(0, base.b * (1 + v))))
        let jitter = (0..<n).map { _ in rand(-1, 1) }
        let world = restL.map { SalonBody.toWorld($0, yaw) }
        let dir = SalonBody.rotate(dirL, yaw)
        var p = world.map(\.xy)
        var z = world.map(\.z)
        let last = world[world.count - 1]
        let count = min(HairSim.maxFree, max(1, free))
        for k in 1...count {
            let q = last + dir * (HairSim.seg * CGFloat(k))
            p.append(q.xy)
            z.append(q.z)
        }
        var s = HairStrand(kind: kind, restL: restL, dirL: dirL, rest: world.map(\.xy), restZ: world.map(\.z), dir: dir,
                           width: width, phase: phase, natural: natural,
                           jitter: jitter, order: order, p: p, o: p, z: z, oz: z,
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

    /// The same in 3D.
    static func resample3(_ path: [H3], _ step: CGFloat) -> [H3] {
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
        if let last = path.last, let o = out.last, (o - last).len > step * 0.35 { out.append(last) }
        if out.count < 2, let last = path.last { out.append(last + H3(0, 1, 0)) }
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
        updateRoots()
        for i in strands.indices { integrate(&strands[i], h) }
        // position-based constraints, several passes: every segment back to its length (both ends give
        // way, so nothing whips), then out of her head, face and shoulders. It settles to a standstill.
        let sq = squash
        var held = Array(repeating: [Int](), count: strands.count)
        for t in ties {
            for m in t.members where m.strand < strands.count { held[m.strand].append(m.node) }
        }
        for c in clips where c.hx != nil && c.strand < strands.count && c.node >= strands[c.strand].pinned
            && c.node < strands[c.strand].p.count {
            held[c.strand].append(c.node)
        }
        for i in strands.indices { HairSim.shape(&strands[i]) }
        for pass in 0..<HairSim.passes {
            applyTies()
            applyClips()
            let last = pass == HairSim.passes - 1
            for i in strands.indices { HairSim.constrain(&strands[i], held: held[i], yaw: yaw, squash: sq, last: last) }
        }
        for i in strands.indices { boxes[i] = HairSim.box(strands[i]) }
        stepPieces(hd)
        stepFoam(h)
    }

    /// Puts the scalp points (and scrunchies) where her turned head has them now.
    private func updateRoots() {
        if rootsYaw == yaw { return }
        rootsYaw = yaw
        for i in strands.indices {
            let w = strands[i].restL.map { SalonBody.toWorld($0, yaw) }
            strands[i].rest = w.map(\.xy)
            strands[i].restZ = w.map(\.z)
            strands[i].dir = SalonBody.rotate(strands[i].dirL, yaw)
        }
        for t in ties.indices {
            let w = SalonBody.toWorld(ties[t].local, yaw)
            ties[t].at = w.xy
            ties[t].z = w.z
        }
    }

    private var rootsYaw: CGFloat = 0

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
            s.z[i] = s.restZ[i]
            s.oz[i] = s.restZ[i]
        }
        let damp: CGFloat = 0.986 - 0.025 * s.wet
        let g = HairV(0, HairSim.gravity * (1 + 0.45 * s.wet) * h * h)
        let w = dryer
        let sq = squash
        for i in P..<s.p.count {
            let cur = s.p[i]
            let cz = s.z[i]
            var v = (cur - s.o[i]) * damp
            var vz = (cz - s.oz[i]) * damp
            var vl = (v.x * v.x + v.y * v.y + vz * vz).squareRoot()
            if vl > 26 {
                v = v * (26 / vl)
                vz *= 26 / vl
                vl = 26
            }
            // hair resting on the cape or the floor grips it: slow creeping stops dead
            var resting = false
            if let top = SalonBody.capeTop(cur.x, squash: sq), cur.y > top - 2, abs(cz) < SalonBody.bodyDepth + 2 {
                v = v * 0.86
                vz *= 0.86
                vl *= 0.86
                resting = true
            }
            if cur.y > SalonBody.floorY - 1 { v = v * 0.6; vz *= 0.6; vl *= 0.6; resting = true }
            // and hair that has all but stopped stops, so a long lock can't keep up a faint sway forever
            if (resting && vl < 0.35) || vl < 0.04 { v = .zero; vz = 0 }
            s.o[i] = cur
            s.oz[i] = cz
            var a = g
            if let w { a += windAccel(cur, w) * (h * h) }
            s.p[i] = cur + v + a
            s.z[i] = cz + vz
        }
    }

    static let passes = 6

    /// The hairdo's shape lives only near the roots: the first few points lean the way the lock leaves the
    /// scalp (the bangs a little further, curls springier). Everything below just hangs.
    private static func shape(_ s: inout HairStrand) {
        let P = s.pinned
        let n = s.p.count
        guard n > P else { return }
        let limp = 1 - 0.55 * s.wet
        let keep: [CGFloat] = s.kind == .fringe ? [0.45, 0.3, 0.18, 0.1, 0.05] : [0.4, 0.2, 0.08]
        for i in P..<n {
            let j = i - P
            let k = ((j < keep.count ? keep[j] : 0) + 0.12 * s.curlNow(i)) * limp
            guard k > 0.001 else { continue }
            let a = H3(s.p[i - 1], s.z[i - 1])
            let before = i >= 2 ? H3(s.p[i - 2], s.z[i - 2]) : a - s.dir
            let d = j == 0 ? s.dir : ((a - before).unit + s.dir).unit
            let target = a + d * s.segLen(i)
            let cur = H3(s.p[i], s.z[i])
            let q = cur + (target - cur) * k
            s.p[i] = q.xy
            s.z[i] = q.z
        }
    }

    /// One pass over a lock: each segment back to its length (the scalp and a scrunchie's point don't
    /// move), then each point out of her head, face and shoulders. On the last pass a point pushed out of
    /// her head brings its previous position along with friction, so lying on her head never turns into
    /// sliding or bouncing.
    private static func constrain(_ s: inout HairStrand, held: [Int], yaw: CGFloat, squash: CGFloat, last: Bool) {
        let P = s.pinned
        let n = s.p.count
        guard n > P else { return }
        for i in P..<n {
            let fa = i - 1 < P || held.contains(i - 1)
            let fb = held.contains(i)
            if fa && fb { continue }
            let a = H3(s.p[i - 1], s.z[i - 1])
            let b = H3(s.p[i], s.z[i])
            let d = b - a
            let l = d.len
            guard l > 0.0001 else { continue }
            let corr = d * ((l - s.segLen(i)) / l)
            let wa: CGFloat = fa ? 0 : (fb ? 1 : 0.5)
            if !fa {
                let na = a + corr * wa
                s.p[i - 1] = na.xy
                s.z[i - 1] = na.z
            }
            if !fb {
                let nb = b - corr * (1 - wa)
                s.p[i] = nb.xy
                s.z[i] = nb.z
            }
        }
        let root = s.restL[P - 1]
        let headK: CGFloat = s.kind == .back ? 1.035 : 1.02
        for i in P..<n where !held.contains(i) {
            // collisions ease in over the first points, whose roots are on the scalp itself
            let ramp = min(1, CGFloat(i - P + 1) / 4)
            var xy = s.p[i]
            var z = s.z[i]
            let inX = xy, inZ = z
            SalonBody.pushOutOfHead(&xy, &z, k: headK * ramp)
            if last, xy != inX || z != inZ {
                let ox = s.o[i] + (xy - inX), oz = s.oz[i] + (z - inZ)
                s.o[i] = ox + (xy - ox) * 0.35
                s.oz[i] = oz + (z - oz) * 0.35
            }
            if s.kind == .side { SalonBody.keepOffFace(&xy, &z, root: root, yaw: yaw) }
            SalonBody.pushOutOfBody(&xy, &z, squash: squash)
            xy.x = max(-300, min(900, xy.x))
            s.p[i] = xy
            s.z[i] = z
        }
    }

    /// A clip keeps its bit of hair exactly where it was clipped.
    private func applyClips() {
        for c in clips {
            guard let x = c.hx, let y = c.hy, c.strand < strands.count, c.node >= strands[c.strand].pinned,
                  c.node < strands[c.strand].p.count else { continue }
            strands[c.strand].p[c.node] = HairV(x, y)
        }
    }

    private func applyTies() {
        for t in ties {
            for m in t.members where m.strand < strands.count {
                let P = strands[m.strand].pinned
                guard m.node >= P, m.node < strands[m.strand].p.count else { continue }
                let end = H3(t.at + m.off, t.z)
                strands[m.strand].p[m.node] = end.xy
                strands[m.strand].z[m.node] = end.z
                // the hair between her scalp and the scrunchie is swept smoothly up to it
                let root = H3(strands[m.strand].rest[P - 1], strands[m.strand].restZ[P - 1])
                let span = CGFloat(m.node - P + 1)
                for j in P..<m.node {
                    let u = CGFloat(j - P + 1) / span
                    let line = root + (end - root) * u
                    var xy = line.xy
                    var z = line.z
                    SalonBody.pushOutOfHead(&xy, &z, k: 1.04)
                    strands[m.strand].p[j] = strands[m.strand].p[j].mix(xy, 0.7)
                    strands[m.strand].z[j] += (z - strands[m.strand].z[j]) * 0.7
                }
            }
            guard t.style != .pony else { continue }
            // braids and buns: the hair below the scrunchie is pulled together into one rope
            var longest = 0
            for m in t.members where m.strand < strands.count { longest = max(longest, strands[m.strand].p.count - 1 - m.node) }
            guard longest > 0 else { continue }
            let pull: CGFloat = t.style == .bun ? 1 : 0.85
            for k in 1...longest {
                var sum = H3(0, 0, 0)
                var c: CGFloat = 0
                for m in t.members where m.strand < strands.count && m.node + k < strands[m.strand].p.count {
                    sum = sum + H3(strands[m.strand].p[m.node + k], strands[m.strand].z[m.node + k])
                    c += 1
                }
                guard c > 0 else { continue }
                let avg = sum * (1 / c)
                for m in t.members where m.strand < strands.count && m.node + k < strands[m.strand].p.count {
                    let j = m.node + k
                    strands[m.strand].p[j] = strands[m.strand].p[j].mix(avg.xy, pull)
                    strands[m.strand].z[j] += (avg.z - strands[m.strand].z[j]) * pull
                }
            }
        }
    }

    /// The rope of a braid: the middle of its locks, from the scrunchie down, while enough of them reach.
    func braidChain(_ t: HairTie) -> [HairV] {
        var chain = [t.at]
        var longest = 0
        for m in t.members where m.strand < strands.count { longest = max(longest, strands[m.strand].p.count - 1 - m.node) }
        guard longest > 0 else { return chain }
        let need = max(1, CGFloat(t.members.count) * 0.35)
        for k in 1...longest {
            var sum = HairV.zero
            var c: CGFloat = 0
            for m in t.members where m.strand < strands.count && m.node + k < strands[m.strand].p.count {
                sum += strands[m.strand].p[m.node + k]
                c += 1
            }
            guard c >= need else { break }
            chain.append(sum * (1 / c))
        }
        return chain
    }

    /// How much hair is below a scrunchie (for the size of a bun).
    func hairBelow(_ t: HairTie) -> Int {
        var n = 0
        for m in t.members where m.strand < strands.count { n += max(0, strands[m.strand].p.count - m.node) }
        return n
    }

    /// For drawing: locks in a braid or bun end at their scrunchie (the rest is drawn as the braid or bun).
    func drawnEnd(_ strand: Int) -> Int? {
        for t in ties where t.style != .pony {
            for m in t.members where m.strand == strand { return m.node }
        }
        return nil
    }

    /// Switches the scrunchie near q to its next style. Returns the new style, or nil if there is none there.
    func restyle(near q: HairV) -> HairTie.Style? {
        guard let i = ties.indices.min(by: { ties[$0].at.dist(q) < ties[$1].at.dist(q) }),
              ties[i].at.dist(q) < 44, SalonBody.visible(ties[i].at, ties[i].z) else { return nil }
        ties[i].style = ties[i].style.next
        return ties[i].style
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
                if let top = SalonBody.capeTop(cur.x, squash: squash), cur.y > top - 2, cur.y < SalonBody.capeBottom { v = v * 0.93 }
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
                    if pieces[k].front { SalonBody.pushOutOfCape(&q, squash: squash) } else if q.y > SalonBody.floorY { q.y = SalonBody.floorY }
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

    /// Whether point `node` of lock `strand` can be seen from where we look at her.
    func visible(_ strand: Int, _ node: Int) -> Bool {
        guard strand >= 0, strand < strands.count, node >= 0, node < strands[strand].p.count else { return false }
        return SalonBody.visible(strands[strand].p[node], strands[strand].z[node], squash: squash)
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
            for (i, p) in s.p.enumerated() where SalonBody.visible(p, s.z[i], squash: squash) {
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
            for i in (P + 1)..<n where HairSim.intersects(a, b, s.p[i - 1], s.p[i])
                && SalonBody.visible(s.p[i], s.z[i], squash: squash) {
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
                              jitter: Array(s.jitter[range]), tangle: s.tangle, wet: s.wet, front: s.z[c] > -30)
        let push = kick * rand(0.4, 1.2) + HairV(rand(-0.6, 0.6), rand(-1.2, -0.2))
        for i in piece.o.indices { piece.o[i] = piece.o[i] - push * (CGFloat(i) / CGFloat(max(1, piece.o.count)) + 0.3) }
        pieces.append(piece)
        strands[si].p.removeLast(n - c)
        strands[si].o.removeLast(n - c)
        strands[si].z.removeLast(n - c)
        strands[si].oz.removeLast(n - c)
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
                let d = n >= 2 ? (tip - t.p[n - 2]).unit : t.dir.xy.unit
                let np = tip + d * (HairSim.seg * 0.6)
                strands[si].p.append(np)
                strands[si].o.append(np)
                strands[si].z.append(t.z[n - 1])
                strands[si].oz.append(t.z[n - 1])
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
                if d < radius, SalonBody.visible(strands[si].p[i], strands[si].z[i], squash: squash) { body(si, i, 1 - d / radius) }
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
        var c = HairClip(kind: kind, color: color, strand: hit.strand, node: hit.node, dx: q.x - at.x, dy: q.y - at.y,
                         tilt: rand(-0.35, 0.35))
        // a clip on free hair holds it right there (so she can clip her bangs or a section aside)
        if c.holds && hit.node >= strands[hit.strand].pinned {
            c.hx = at.x
            c.hy = at.y
        }
        clips.append(c)
        return true
    }

    func clipPosition(_ c: HairClip) -> HairV? {
        position(c.strand, c.node).map { $0 + HairV(c.dx, c.dy) }
    }

    /// Ties a scrunchie at q: every lock on this side of her head that passes close by, or is rooted near
    /// enough and long enough to reach, is gathered into it. Returns false if too little hair is there.
    func tie(at q: HairV, color: Int, style: HairTie.Style = .pony) -> Bool {
        var members: [HairTie.Member] = []
        var depth: CGFloat = 0
        let sideTie = abs(q.x - SalonBody.center.x) > 60
        for (si, s) in strands.enumerated() {
            if ties.contains(where: { t in t.members.contains { m in m.strand == si } }) { continue }
            let P = s.pinned
            let root = s.rest[P - 1]
            guard s.restZ[P - 1] > -40 else { continue }
            // a pigtail only takes hair from its own side
            if sideTie && (root.x - SalonBody.center.x) * (q.x - SalonBody.center.x) < -400 { continue }
            var best: (Int, CGFloat)?
            for i in P..<s.p.count where s.z[i] > -40 {
                let d = s.p[i].dist(q)
                if d < 78 && d < (best?.1 ?? .greatestFiniteMagnitude) { best = (i, d) }
            }
            if best == nil {
                let reach = root.dist(q)
                let k = max(1, Int((reach / HairSim.seg).rounded()))
                if reach < (sideTie ? 170 : 210), s.free > k { best = (P + k - 1, 0) }
            }
            if let b = best {
                let a = rand(0, 6.28)
                let r = rand(3, 13)
                members.append(HairTie.Member(strand: si, node: b.0, off: HairV(cos(a) * r, sin(a) * r * 0.6)))
                depth += max(0, s.z[b.0])
            }
        }
        guard members.count >= 3 else { return false }
        let z = depth / CGFloat(members.count) + 10
        ties.append(HairTie(at: q, z: z, local: SalonBody.toLocal(H3(q, z), yaw), color: color, members: members, style: style))
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
        /// Their depths.
        var zs: [Int16]?
    }

    struct TieSave: Codable {
        var x: Double
        var y: Double
        var color: Int
        var style: HairTie.Style?
    }

    /// 3 is the 3D head of hair; older saves had a different set of locks and only keep their recipe.
    static let layout = 3

    struct Save: Codable {
        var recipe: HairRecipe
        var strands: [StrandSave]
        var clips: [HairClip]
        var ties: [TieSave]
        var layout: Int?
        var yaw: Double?
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
            var zs: [Int16]?
            if positions {
                pts = s.p.dropFirst(s.pinned).flatMap { [HairSim.q16($0.x), HairSim.q16($0.y)] }
                zs = s.z.dropFirst(s.pinned).map { HairSim.q16($0) }
            }
            return StrandSave(n: s.free, colors: colors, curls: curls, wet: Double(s.wet), tangle: Double(s.tangle),
                              gloss: Double(s.gloss), pts: pts, zs: zs)
        }
        return Save(recipe: recipe, strands: ss, clips: clips,
                    ties: ties.map { TieSave(x: Double($0.at.x), y: Double($0.at.y), color: $0.color, style: $0.style) },
                    layout: HairSim.layout, yaw: Double(yaw))
    }

    /// Rebuilds hair from a save. Positions come back if saved, otherwise the hair is settled again.
    convenience init(save: Save, palette: [RGB], settle: Bool = true) {
        self.init(recipe: save.recipe, palette: palette)
        guard save.layout == HairSim.layout else {
            if settle { self.settle(seconds: 2) }
            return
        }
        yaw = CGFloat(save.yaw ?? 0)
        updateRoots()
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
            var z = Array(s.restZ)
            let last = H3(s.rest[P - 1], s.restZ[P - 1])
            if let pts = ss.pts, pts.count >= n * 2 {
                for j in 0..<n {
                    p.append(HairV(CGFloat(pts[j * 2]), CGFloat(pts[j * 2 + 1])))
                    z.append(ss.zs.map { $0.indices.contains(j) ? CGFloat($0[j]) : last.z } ?? last.z)
                }
                hadPositions = true
            } else {
                for j in 1...n {
                    let q = last + s.dir * (HairSim.seg * CGFloat(j))
                    p.append(q.xy)
                    z.append(q.z)
                }
            }
            s.p = p
            s.o = p
            s.z = z
            s.oz = z
            s.wet = CGFloat(max(0, min(1, ss.wet)))
            s.tangle = CGFloat(max(0, min(1, ss.tangle)))
            s.gloss = CGFloat(max(0, min(1, ss.gloss)))
            strands[si] = s
        }
        boxes = strands.map(HairSim.box)
        clips = save.clips.filter { $0.strand < strands.count && $0.node < strands[$0.strand].p.count }
        for t in save.ties { _ = tie(at: HairV(CGFloat(t.x), CGFloat(t.y)), color: t.color, style: t.style ?? .pony) }
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
