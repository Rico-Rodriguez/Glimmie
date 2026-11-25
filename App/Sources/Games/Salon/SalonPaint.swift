import SwiftUI

// MARK: - Drawing the hair, the client and the salon chair
//
// Every lock is drawn as a filled ribbon around its points (smoothed with Catmull-Rom), with a
// color-derived outline and a light streak, the same flat look as the Dress Up art. Curls are a wave
// along the ribbon, frizz is a little fixed noise, wet hair is darker and shinier. A dyed lock is
// filled with a gradient through the color of each of its points.

enum HairPainter {
    // MARK: Colors

    static func wetColor(_ c: RGB, _ wet: CGFloat) -> RGB {
        wet <= 0.01 ? c : c.mix(Shades.deep(c), Double(wet) * 0.45)
    }

    // MARK: Ribbons

    private static func catmull(_ p0: HairV, _ p1: HairV, _ p2: HairV, _ p3: HairV, _ t: CGFloat) -> HairV {
        let t2 = t * t
        let t3 = t2 * t
        let a = p1 * 2
        let b = (p2 - p0) * t
        let c1: HairV = p0 * 2 - p1 * 5
        let c2: HairV = p2 * 4 - p3
        let d1: HairV = p1 * 3 - p0
        let d2: HairV = p3 - p2 * 3
        let c: HairV = (c1 + c2) * t2
        let d: HairV = (d1 + d2) * t3
        let ab: HairV = a + b
        return (ab + c + d) * 0.5
    }

    /// The center line of a lock, with curls and frizz.
    static func centerline(_ nodes: [HairV], pinned: Int, curl: (Int) -> CGFloat, tangle: CGFloat, jitter: [CGFloat],
                           phase: CGFloat) -> [HairV] {
        let n = nodes.count
        guard n >= 2 else { return nodes }
        var out: [HairV] = []
        out.reserveCapacity(n * 3 + 1)
        var arc: CGFloat = 0
        var last = nodes[0]
        let sub = 3
        for i in 0..<(n - 1) {
            let p0 = nodes[max(0, i - 1)]
            let p1 = nodes[i]
            let p2 = nodes[i + 1]
            let p3 = nodes[min(n - 1, i + 2)]
            let tan = (p2 - p1).unit
            let c0 = curl(i)
            let c1 = curl(i + 1)
            let j0 = jitter.indices.contains(i) ? jitter[i] : 0
            let j1 = jitter.indices.contains(i + 1) ? jitter[i + 1] : 0
            // frizz is a slow, uneven wave (not per-point noise), easing in past the scalp
            let f0: CGFloat = i >= pinned ? min(1, CGFloat(i - pinned + 1) / 3) : 0
            let f1: CGFloat = i + 1 >= pinned ? min(1, CGFloat(i + 2 - pinned) / 3) : 0
            for k in 0..<sub {
                let t = CGFloat(k) / CGFloat(sub)
                let b = catmull(p0, p1, p2, p3, t)
                arc += b.dist(last)
                last = b
                let c = c0 + (c1 - c0) * t
                let jit = j0 + (j1 - j0) * t
                let f = f0 + (f1 - f0) * t
                let wave = c * 10 * sin(phase + arc * 0.2)
                let frizz = tangle * f * (2.6 * sin(phase * 3.1 + arc * 0.32) * (0.6 + 0.4 * sin(phase * 1.7 + arc * 0.09))
                    + 0.6 * jit)
                out.append(b + tan.perp * (wave + frizz))
            }
        }
        let tipTan = (nodes[n - 1] - nodes[n - 2]).unit
        let cEnd = curl(n - 1)
        arc += nodes[n - 1].dist(last)
        out.append(nodes[n - 1] + tipTan.perp * (cEnd * 10 * sin(phase + arc * 0.2)))
        return out
    }

    /// A ribbon around `line`: full width, narrowing at the tip (and at the root for front locks).
    static func ribbon(_ line: [HairV], width: CGFloat, rootTaper: Bool, pointy: Bool = false) -> Path {
        var path = Path()
        let m = line.count
        guard m >= 2 else { return path }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        left.reserveCapacity(m)
        right.reserveCapacity(m)
        for k in 0..<m {
            let a = line[max(0, k - 1)]
            let b = line[min(m - 1, k + 1)]
            let nrm = (b - a).unit.perp
            let u = CGFloat(k) / CGFloat(m - 1)
            var w = width * 0.5
            // bangs end in soft points, longer locks in round ends
            let t0: CGFloat = pointy ? 0.3 : 0.55
            let tipW: CGFloat = pointy ? 0.12 : 0.22
            if u > t0 { w *= max(tipW, 1 - (u - t0) / (1 - t0) * (1 - tipW)) }
            if rootTaper && u < 0.15 { w *= 0.55 + 0.45 * (u / 0.15) }
            left.append((line[k] + nrm * w).cg)
            right.append((line[k] - nrm * w).cg)
        }
        path.move(to: left[0])
        path.addLines(left)
        let tipDir = (line[m - 1] - line[m - 2]).unit
        path.addQuadCurve(to: right[m - 1], control: (line[m - 1] + tipDir * (width * 0.12)).cg)
        path.addLines(right.reversed())
        path.closeSubpath()
        return path
    }

    static func streak(_ line: [HairV], width: CGFloat, from u0: CGFloat, to u1: CGFloat) -> Path {
        var path = Path()
        let m = line.count
        guard m >= 3 else { return path }
        let a = Int(CGFloat(m - 1) * u0)
        let b = max(a + 1, Int(CGFloat(m - 1) * u1))
        for k in a...min(b, m - 1) {
            let pa = line[max(0, k - 1)]
            let pb = line[min(m - 1, k + 1)]
            let nrm = (pb - pa).unit.perp
            let q = (line[k] - nrm * (width * 0.22)).cg
            if k == a { path.move(to: q) } else { path.addLine(to: q) }
        }
        return path
    }

    /// The shading for a lock: one color, or a gradient through its points' colors.
    static func shading(_ nodes: [HairV], colors: [RGB], wet: CGFloat, darker: Bool) -> GraphicsContext.Shading {
        func tone(_ c: RGB) -> RGB {
            let w = wetColor(c, wet)
            return darker ? Shades.shade(w) : w
        }
        let n = nodes.count
        let first = colors[0]
        var uniform = true
        for i in 1..<min(n, colors.count) where abs(colors[i].r - first.r) + abs(colors[i].g - first.g) + abs(colors[i].b - first.b) > 0.02 {
            uniform = false
            break
        }
        if uniform || n < 2 { return .color(tone(first).color) }
        let a = nodes[0]
        let axis = nodes[n - 1] - a
        let l2 = max(1, axis.dot(axis))
        var stops: [Gradient.Stop] = []
        var lastLoc: CGFloat = 0
        for i in 0..<min(n, colors.count) {
            let loc = max(lastLoc, min(1, (nodes[i] - a).dot(axis) / l2))
            lastLoc = loc
            stops.append(Gradient.Stop(color: tone(colors[i]).color, location: loc))
        }
        return .linearGradient(Gradient(stops: stops), startPoint: a.cg, endPoint: nodes[n - 1].cg)
    }

    static func outlineColor(_ colors: [RGB], _ wet: CGFloat) -> Color {
        let n = colors.count
        let c = n > 0 ? colors[min(n - 1, 2)] : RGB(0.4, 0.3, 0.2)
        return Shades.outline(wetColor(c, wet)).color
    }

    /// A lock ready to paint.
    struct Lock {
        var line: [HairV]
        var width: CGFloat
        var fill: GraphicsContext.Shading
        var outline: Color
        var light: Color
        var lightAlpha: Double
        var gloss: CGFloat
        var rootTaper: Bool
        var shape: Path
        var shade: Color
    }

    static func lock(nodes: [HairV], pinned: Int, colors: [RGB], curl: (Int) -> CGFloat, tangle: CGFloat,
                     jitter: [CGFloat], phase: CGFloat, width: CGFloat, wet: CGFloat, gloss: CGFloat,
                     darker: Bool, rootTaper: Bool, pointy: Bool = false) -> Lock? {
        guard nodes.count >= 2, !colors.isEmpty else { return nil }
        let line = centerline(nodes, pinned: pinned, curl: curl, tangle: tangle, jitter: jitter, phase: phase)
        let w = width * (1 - 0.14 * wet)
        let mid = wetColor(colors[min(colors.count - 1, max(0, pinned))], wet)
        let lightBase = colors[min(colors.count - 1, max(0, pinned))]
        return Lock(line: line, width: w, fill: shading(nodes, colors: colors, wet: wet, darker: darker),
                    outline: outlineColor(colors, wet), light: Shades.light(wetColor(lightBase, wet)).color,
                    lightAlpha: min(1, (darker ? 0.25 : 0.5) + 0.35 * Double(gloss) + 0.25 * Double(wet)),
                    gloss: gloss, rootTaper: rootTaper, shape: ribbon(line, width: w, rootTaper: rootTaper, pointy: pointy),
                    shade: Shades.deep(mid).color)
    }

    /// Paints locks as one head of hair: every outline first, then every fill on top, so the dark line
    /// only shows around the outside of the hair and between locks, like the Dress Up hair, then a little
    /// strand texture and the shine.
    static func paint(_ locks: [Lock], cap: (path: Path, color: Color, outline: Color)? = nil, in ctx: GraphicsContext) {
        let edge = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        if let cap { ctx.stroke(cap.path, with: .color(cap.outline), style: edge) }
        for l in locks { ctx.stroke(l.shape, with: .color(l.outline), style: edge) }
        if let cap { ctx.fill(cap.path, with: .color(cap.color)) }
        for l in locks {
            ctx.fill(l.shape, with: l.fill)
            // a soft shadow down one side of each section, clipped to it, so every lock reads as a
            // rounded clump of hair instead of a flat ribbon
            var g = ctx
            g.clip(to: l.shape)
            g.opacity = 0.2
            g.stroke(offsetLine(l.line, by: l.width * 0.4, from: 0, to: 1), with: .color(l.shade),
                     style: StrokeStyle(lineWidth: l.width * 0.3, lineCap: .round, lineJoin: .round))
        }
        // one fine strand line down every other section
        var tex = ctx
        tex.opacity = 0.3
        let thin = StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
        for (i, l) in locks.enumerated() where i % 2 == 0 {
            tex.stroke(offsetLine(l.line, by: l.width * 0.05, from: 0.3, to: 0.75), with: .color(l.outline), style: thin)
        }
        // shine only where hair is wet or freshly straightened (the crown has its own shine)
        for l in locks where l.lightAlpha > 0.56 {
            var g = ctx
            g.opacity = min(1, (l.lightAlpha - 0.5) * 1.4)
            g.stroke(streak(l.line, width: l.width, from: l.rootTaper ? 0.12 : 0.04, to: 0.45 + 0.2 * l.gloss),
                     with: .color(l.light), style: StrokeStyle(lineWidth: 2.6 + 2 * l.gloss, lineCap: .round, lineJoin: .round))
        }
    }

    static func offsetLine(_ line: [HairV], by off: CGFloat, from u0: CGFloat, to u1: CGFloat) -> Path {
        var path = Path()
        let m = line.count
        guard m >= 3 else { return path }
        let a = Int(CGFloat(m - 1) * u0)
        let b = max(a + 1, Int(CGFloat(m - 1) * u1))
        for k in a...min(b, m - 1) {
            let nrm = (line[min(m - 1, k + 1)] - line[max(0, k - 1)]).unit.perp
            let q = (line[k] + nrm * off).cg
            if k == a { path.move(to: q) } else { path.addLine(to: q) }
        }
        return path
    }

    /// Locks are drawn much wider than they are simulated, so neighbours overlap into one full head of
    /// hair: the physics moves sections, the drawing shows volume.
    static func volume(_ kind: HairStrand.Kind) -> CGFloat {
        switch kind {
        case .back, .nape: return 1.75
        case .side: return 1.6
        case .fringe: return 1.7
        }
    }

    static func lock(_ s: HairStrand, darker: Bool, end: Int? = nil) -> Lock? {
        let n = min(s.p.count, (end ?? s.p.count - 1) + 1)
        return lock(nodes: Array(s.p.prefix(n)), pinned: s.pinned, colors: Array(s.color.prefix(n)), curl: { s.curlNow($0) },
             tangle: s.tangle, jitter: s.jitter, phase: s.phase, width: s.width * volume(s.kind), wet: s.wet,
             gloss: s.gloss, darker: darker, rootTaper: s.front, pointy: s.kind == .fringe)
    }

    // MARK: Fine strands
    //
    // The locks of the simulation are guides that are never drawn themselves. Between every two
    // neighbouring guides a few fine strands are drawn, blended between the two, over a slightly darker
    // under-layer, so the hair reads as one soft mass of real hair. Where two guides move apart (a pull,
    // a scrunchie, wet hair) the strands between them slide to one side or the other, so the hair parts
    // into clumps instead of stretching between them.

    /// Strands drawn between two neighbouring guides.
    static let perPair = 5
    static let strandWidth: CGFloat = 3.1

    private struct StrandSeed { let f: CGFloat; let len: CGFloat; let tone: Double; let frizz: CGFloat }

    private static let seeds: [StrandSeed] = {
        var g = SeededGenerator(seed: 77)
        return (0..<(perPair * 80)).map { i in
            StrandSeed(f: (CGFloat(i % perPair) + CGFloat(Double.random(in: 0..<1, using: &g))) / CGFloat(perPair),
                       len: CGFloat(Double.random(in: 0..<1, using: &g)), tone: Double.random(in: -1...1, using: &g),
                       frizz: CGFloat(Double.random(in: 0..<6.28, using: &g)))
        }
    }()

    /// Paths grouped by color, so a whole head of strands is a handful of strokes.
    private struct Buckets {
        var paths: [UInt32: Path] = [:]
        var colors: [UInt32: RGB] = [:]
        mutating func add(_ p: Path, _ c: RGB) {
            func q(_ v: Double) -> UInt32 { UInt32(max(0, min(31, (v * 31).rounded()))) }
            let key = (q(c.r) << 10) | (q(c.g) << 5) | q(c.b)
            paths[key, default: Path()].addPath(p)
            if colors[key] == nil { colors[key] = c }
        }
        func stroke(_ ctx: GraphicsContext, width: CGFloat) {
            let st = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            for (k, p) in paths { ctx.stroke(p, with: .color(colors[k]!.color), style: st) }
        }
    }

    /// How far a lock is drawn (braids and buns end at their scrunchie).
    private static func drawnCount(_ sim: HairSim, _ i: Int) -> Int {
        let s = sim.strands[i]
        return min(s.p.count, (sim.drawnEnd(i) ?? s.p.count - 1) + 1)
    }

    /// Neighbouring guides, in the order they sit around her head.
    private static func pairs(_ sim: HairSim, front: Bool) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        let n = sim.strands.count
        guard n > 1 else { return out }
        for i in 0..<(n - 1) {
            let a = sim.strands[i], b = sim.strands[i + 1]
            guard a.front == b.front else { continue }
            let depth = (a.depth + b.depth) / 2
            if (depth >= 0) == front { out.append((i, i + 1)) }
        }
        return out
    }

    /// The fine strands of one side of her head (behind it, or in front of it).
    static func drawStrands(_ sim: HairSim, front: Bool, in ctx: GraphicsContext) {
        let list = pairs(sim, front: front)
        guard !list.isEmpty else { return }
        var under = Path()
        var underColor = RGB(0, 0, 0)
        var underN = 0.0
        var hair = Buckets()
        var shine = Buckets()
        var seedIndex = 0
        for (ia, ib) in list {
            let A = sim.strands[ia], B = sim.strands[ib]
            let nA = drawnCount(sim, ia), nB = drawnCount(sim, ib)
            let m = min(nA, nB)
            guard m >= 2 else { continue }
            // parted or wet: the strands bunch up toward the nearer guide
            var sep: CGFloat = 0
            for k in [max(1, m / 2), m - 1] {
                let d = H3(A.p[k], A.z[k]) - H3(B.p[k], B.z[k])
                sep = max(sep, d.len / max(8, (A.width + B.width) * 0.5))
            }
            let wet = (A.wet + B.wet) / 2
            let clump = max(smooth(1.5, 2.7, sep), wet * 0.75)
            if clump < 0.45 {
                var poly = Path()
                poly.move(to: A.p[0].cg)
                for k in 1..<max(2, nA - 1) { poly.addLine(to: A.p[k].cg) }
                for k in stride(from: max(1, nB - 2), through: 0, by: -1) { poly.addLine(to: B.p[k].cg) }
                poly.closeSubpath()
                under.addPath(poly)
                let c = A.color[min(A.color.count - 1, max(0, m / 2))]
                underColor = RGB(underColor.r + c.r, underColor.g + c.g, underColor.b + c.b)
                underN += 1
            }
            let gloss = (A.gloss + B.gloss) / 2
            let tangle = (A.tangle + B.tangle) / 2
            for _ in 0..<perPair {
                let sd = seeds[seedIndex % seeds.count]
                seedIndex += 1
                var f = sd.f
                if clump > 0 {
                    let side: CGFloat = f < 0.5 ? 0 : 1
                    f += (side + (f - side) * 0.35 - f) * clump
                }
                let pts = strand(A, B, nA, nB, f: f, trim: sd.len * (A.front ? 0.8 : 1.4))
                guard pts.count >= 2 else { continue }
                let line = wavy(pts, A, B, f: f, tangle: tangle, seed: sd.frizz)
                let count = line.count
                // a strand is three short paths, so dyed ends and roots keep their own colors
                let thirds = [0, count / 3, (count * 2) / 3, count - 1]
                for t in 0..<3 {
                    let lo = thirds[t], hi = max(thirds[t] + 1, thirds[t + 1])
                    guard hi < count else { continue }
                    let k = min(m - 1, Int(CGFloat(lo + hi) / 2 / CGFloat(count) * CGFloat(pts.count)))
                    var c = A.color[min(A.color.count - 1, k)].mix(B.color[min(B.color.count - 1, k)], Double(f))
                    c = wetColor(c, wet)
                    if !front { c = c.mix(Shades.deep(c), 0.22) }
                    c = sd.tone > 0 ? c.mix(Shades.light(c), sd.tone * 0.22) : c.mix(Shades.deep(c), -sd.tone * 0.3)
                    hair.add(path(line, lo, hi), c)
                }
                // the shine: the same short stretch of every strand, so together they make one soft band
                let u0: CGFloat = front ? 0.12 : 0.4, u1: CGFloat = front ? 0.3 - 0.04 * wet : 0.52
                let s0 = Int(CGFloat(count - 1) * u0), s1 = Int(CGFloat(count - 1) * u1)
                if s1 > s0 + 1 {
                    let k = min(m - 1, s0)
                    let base = wetColor(A.color[min(A.color.count - 1, k)].mix(B.color[min(B.color.count - 1, k)], Double(f)), wet)
                    let amount = (front ? 0.45 : 0.25) + 0.25 * Double(gloss) + 0.2 * Double(wet) + sd.tone * 0.08
                    shine.add(path(line, s0, s1), base.mix(Shades.white, min(0.85, amount)))
                }
            }
        }
        if underN > 0 {
            let k = 1 / underN
            let c = wetColor(RGB(underColor.r * k, underColor.g * k, underColor.b * k), sim.strands.map(\.wet).reduce(0, +) / CGFloat(max(1, sim.strands.count)))
            if !front {
                ctx.stroke(under, with: .color(Shades.outline(c).color), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            }
            let fill = Shades.deep(c).mix(c, 0.45)
            ctx.fill(under, with: .color(fill.color))
            ctx.stroke(under, with: .color(fill.color), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        hair.stroke(ctx, width: strandWidth)
        shine.stroke(ctx, width: strandWidth * 0.9)
    }

    private static func smooth(_ e0: CGFloat, _ e1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - e0) / (e1 - e0)))
        return t * t * (3 - 2 * t)
    }

    /// One fine strand f of the way from guide A to guide B, its length blended between theirs (so a
    /// slanted cut stays slanted), `trim` points short of that so the ends feather.
    private static func strand(_ A: HairStrand, _ B: HairStrand, _ nA: Int, _ nB: Int, f: CGFloat, trim: CGFloat) -> [HairV] {
        let m = min(nA, nB)
        var L = CGFloat(nA - 1) + CGFloat(nB - nA) * f - trim
        L = max(1, L)
        let longer = nA > nB ? A : B
        func at(_ k: Int) -> HairV {
            if k < m { return A.p[k].mix(B.p[k], f) }
            let base = A.p[m - 1].mix(B.p[m - 1], f)
            return base + (longer.p[min(k, longer.p.count - 1)] - longer.p[m - 1])
        }
        let whole = Int(L)
        let top = max(nA, nB) - 1
        var out: [HairV] = []
        out.reserveCapacity(whole + 2)
        for k in 0...min(whole, top) { out.append(at(k)) }
        let fr = L - CGFloat(whole)
        if fr > 0.05, whole + 1 <= top { out.append(at(whole).mix(at(whole + 1), fr)) }
        return out
    }

    /// Curls and frizz on a strand: a wave along it (in step with its neighbours), and for tangled
    /// hair a little uneven wiggle of its own.
    private static func wavy(_ pts: [HairV], _ A: HairStrand, _ B: HairStrand, f: CGFloat, tangle: CGFloat, seed: CGFloat) -> [HairV] {
        let n = pts.count
        let phase = A.phase + (B.phase - A.phase) * f
        let P = min(A.pinned, B.pinned)
        var out: [HairV] = []
        out.reserveCapacity(n)
        var arc: CGFloat = 0
        for i in 0..<n {
            if i > 0 { arc += pts[i].dist(pts[i - 1]) }
            let tan = (pts[min(n - 1, i + 1)] - pts[max(0, i - 1)]).unit
            let c = i < A.p.count && i < B.p.count ? A.curlNow(i) + (B.curlNow(i) - A.curlNow(i)) * f : A.curlNow(min(i, A.p.count - 1))
            let ease = i >= P ? min(1, CGFloat(i - P + 1) / 3) : 0
            let wave = c * 9 * sin(phase + arc * 0.2)
            let s1: CGFloat = sin(seed + arc * 0.33)
            let s2: CGFloat = 0.6 + 0.4 * sin(seed * 1.7 + arc * 0.08)
            let frizz: CGFloat = tangle * ease * 2.4 * s1 * s2
            out.append(pts[i] + tan.perp * (wave + frizz))
        }
        return out
    }

    /// A smooth path through points lo...hi.
    private static func path(_ line: [HairV], _ lo: Int, _ hi: Int) -> Path {
        var p = Path()
        guard hi > lo, hi < line.count else { return p }
        p.move(to: line[lo].cg)
        if hi - lo == 1 { p.addLine(to: line[hi].cg); return p }
        for i in (lo + 1)..<hi {
            let mid = line[i].mix(line[i + 1], 0.5)
            p.addQuadCurve(to: mid.cg, control: line[i].cg)
        }
        p.addLine(to: line[hi].cg)
        return p
    }

    /// Cut hair: a little bunch of fine strands.
    static func draw(_ piece: HairPiece, in ctx: GraphicsContext) {
        var g = ctx
        if piece.age > 30 { g.opacity = max(0, 1 - (piece.age - 30) / 6) }
        let n = piece.p.count
        guard n >= 2 else { return }
        let dir = (piece.p[n - 1] - piece.p[0]).unit.perp
        var b = Buckets()
        for j in 0..<6 {
            let off = (CGFloat(j) / 5 - 0.5) * piece.width * 0.9
            let keep = max(2, n - (j % 3))
            var line: [HairV] = []
            for k in 0..<keep {
                let a: CGFloat = piece.phase + CGFloat(k) * 0.9 + CGFloat(j)
                line.append(piece.p[k] + dir * (off + sin(a) * 1.2))
            }
            var c = wetColor(piece.color[min(piece.color.count - 1, n / 2)], piece.wet)
            c = j % 2 == 0 ? c.mix(Shades.deep(c), 0.2) : c.mix(Shades.light(c), 0.1)
            b.add(path(line, 0, line.count - 1), c)
        }
        b.stroke(g, width: strandWidth * 0.9)
    }

    // MARK: Layers

    /// The hair behind the middle of her head (drawn before her head).
    static func drawBack(_ sim: HairSim, in ctx: GraphicsContext) {
        for t in sim.ties where t.z < 0 { drawStyle(t, sim, in: ctx) }
        drawStrands(sim, front: false, in: ctx)
    }

    /// The scalp on the side of her head facing us, then the hair in front.
    static func drawFront(_ sim: HairSim, in ctx: GraphicsContext) {
        drawScalp(sim, in: ctx)
        drawStrands(sim, front: true, in: ctx)
        for t in sim.ties where t.z >= 0 { drawStyle(t, sim, in: ctx) }
        let avg = average(sim)
        // the part, while she faces us
        let facing = cos(sim.yaw)
        if facing > 0.5 {
            var part = Path()
            let x = 300 + sin(sim.yaw) * 30
            part.move(to: CGPoint(x: x, y: 150))
            part.addQuadCurve(to: CGPoint(x: x, y: 172), control: CGPoint(x: x + 2, y: 160))
            var g = ctx
            g.opacity = Double((facing - 0.5) * 2) * 0.6
            g.stroke(part, with: .color(Shades.deep(avg).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    static func average(_ sim: HairSim) -> RGB {
        var r = 0.0, g = 0.0, b = 0.0
        var wet: CGFloat = 0
        for s in sim.strands {
            let c = s.color[min(2, s.color.count - 1)]
            r += c.r; g += c.g; b += c.b
            wet += s.wet
        }
        let k = 1.0 / Double(max(1, sim.strands.count))
        return wetColor(RGB(r * k, g * k, b * k), wet / CGFloat(max(1, sim.strands.count)))
    }

    /// The scalp: the rooted part of every lock on the side of her head facing us, as one thick band of
    /// its color with an outline, so her head is covered from every side and the hairline shows.
    static func drawScalp(_ sim: HairSim, in ctx: GraphicsContext) {
        var bands: [(Path, Color, Color)] = []
        for s in sim.strands {
            var path = Path()
            var open = false
            for i in 1..<s.pinned {
                guard s.restZ[i - 1] + s.restZ[i] > -10 else { open = false; continue }
                if !open { path.move(to: s.rest[i - 1].cg); open = true }
                path.addLine(to: s.rest[i].cg)
            }
            guard !path.isEmpty else { continue }
            let c = wetColor(s.color[min(2, s.color.count - 1)], s.wet)
            bands.append((path, c.color, Shades.outline(c).color))
        }
        let edge = StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round)
        let fill = StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round)
        for b in bands { ctx.stroke(b.0, with: .color(b.2), style: edge) }
        for b in bands { ctx.stroke(b.0, with: .color(b.1), style: fill) }
    }

    /// A braid or a bun at a scrunchie (a ponytail is just its locks).
    static func drawStyle(_ t: HairTie, _ sim: HairSim, in ctx: GraphicsContext) {
        guard t.style != .pony, let first = t.members.first, first.strand < sim.strands.count else { return }
        let s = sim.strands[first.strand]
        let base = wetColor(s.color[min(s.color.count - 1, first.node)], s.wet)
        let col = base.color
        let out = Shades.outline(base).color
        let deep = Shades.deep(base).color
        switch t.style {
        case .bun:
            let r = min(58, 16 + CGFloat(sim.hairBelow(t)).squareRoot() * 4.2)
            let away = (t.at - SalonBody.center).unit
            let c = t.at + away * (r * 0.55)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect), with: .color(out), lineWidth: 5)
            ctx.fill(Path(ellipseIn: rect), with: .color(col))
            var g = ctx
            g.opacity = 0.35
            for k in 0..<3 {
                var arc = Path()
                arc.addArc(center: c.cg, radius: r * (0.3 + CGFloat(k) * 0.22), startAngle: .radians(Double(k)),
                           endAngle: .radians(Double(k) + 3.6), clockwise: false)
                g.stroke(arc, with: .color(deep), lineWidth: 2.5)
            }
            var sh = ctx
            sh.opacity = 0.5
            sh.stroke(Path { p in
                p.addArc(center: c.cg, radius: r * 0.7, startAngle: .radians(3.6), endAngle: .radians(4.5), clockwise: false)
            }, with: .color(Shades.light(base).color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        case .braid:
            let chain = sim.braidChain(t)
            guard chain.count >= 2 else { return }
            var line: [HairV] = []
            for i in 0..<(chain.count - 1) {
                for k in 0..<4 { line.append(chain[i].mix(chain[i + 1], CGFloat(k) / 4)) }
            }
            line.append(chain[chain.count - 1])
            let w0 = min(48, 24 + CGFloat(t.members.count) * 1.1)
            let lobe: CGFloat = 15
            var stops: [Int] = []
            var acc: CGFloat = 0
            for k in 1..<line.count {
                acc += line[k].dist(line[k - 1])
                if acc >= lobe { acc = 0; stops.append(k) }
            }
            var shapes: [Path] = []
            for (j, k) in stops.enumerated() {
                let tn = (line[min(line.count - 1, k + 1)] - line[max(0, k - 3)]).unit
                let side: CGFloat = j % 2 == 0 ? -1 : 1
                let u = CGFloat(k) / CGFloat(line.count - 1)
                let w = w0 * (1 - 0.5 * u)
                let c = line[k] + tn.perp * (side * w * 0.18)
                let e = Path(ellipseIn: CGRect(x: -lobe, y: -w * 0.45, width: lobe * 2, height: w * 0.9))
                let a = atan2(tn.y, tn.x) + side * 0.5
                shapes.append(e.applying(CGAffineTransform(rotationAngle: a).concatenating(CGAffineTransform(translationX: c.x, y: c.y))))
            }
            for p in shapes { ctx.stroke(p, with: .color(out), lineWidth: 5) }
            for p in shapes {
                ctx.fill(p, with: .color(col))
                var g = ctx
                g.opacity = 0.4
                g.stroke(p, with: .color(deep), lineWidth: 2)
            }
            // a little tuft at the end
            let end = chain[chain.count - 1]
            let dir = (end - chain[chain.count - 2]).unit
            var tuft = Path()
            tuft.move(to: (end + dir.perp * 9).cg)
            tuft.addQuadCurve(to: (end + dir * 30).cg, control: (end + dir * 14 + dir.perp * 10).cg)
            tuft.addQuadCurve(to: (end - dir.perp * 9).cg, control: (end + dir * 14 - dir.perp * 10).cg)
            tuft.closeSubpath()
            ctx.stroke(tuft, with: .color(out), lineWidth: 4)
            ctx.fill(tuft, with: .color(col))
            var g = ctx
            g.translateBy(x: end.x, y: end.y)
            g.scaleBy(x: 0.6, y: 0.6)
            ClipPainter.drawScrunchie(color: t.color, in: g)
        case .pony:
            break
        }
    }

    private static var cachedCap: Path?

    static func capPath() -> Path {
        if let c = cachedCap { return c }
        var p = Path()
        let n = 24
        for i in 0...n {
            let s = -1 + 2 * CGFloat(i) / CGFloat(n)
            let q = SalonBody.hairline(s).cg
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        let h = SalonBody.hairline(1)
        let thR = atan2((h.x - SalonBody.center.x) / SalonBody.rx, (SalonBody.center.y - h.y) / SalonBody.ry)
        let m = 30
        for i in 0...m {
            let th = thR - 2 * thR * CGFloat(i) / CGFloat(m)
            p.addLine(to: SalonBody.head(th, 1.03).cg)
        }
        p.closeSubpath()
        cachedCap = p
        return p
    }

    // MARK: Foam, glitter

    static func drawFoam(_ sim: HairSim, in ctx: GraphicsContext) {
        guard !sim.foam.isEmpty else { return }
        var pts: [(CGPoint, CGFloat)] = []
        pts.reserveCapacity(sim.foam.count)
        for b in sim.foam {
            guard let at = sim.position(b.strand, b.node), sim.visible(b.strand, b.node) else { continue }
            pts.append(((at + b.off).cg, b.r))
        }
        var rim = Path()
        var body = Path()
        var shade = Path()
        var shine = Path()
        for (c, r) in pts {
            rim.addEllipse(in: CGRect(x: c.x - r - 2.2, y: c.y - r - 2.2, width: (r + 2.2) * 2, height: (r + 2.2) * 2))
            body.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            shade.addEllipse(in: CGRect(x: c.x - r * 0.75, y: c.y - r * 0.1, width: r * 1.5, height: r * 1.0))
            shine.addEllipse(in: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.6, width: r * 0.45, height: r * 0.4))
        }
        ctx.fill(rim, with: .color(Color(hex: 0xB8CFE6)))
        ctx.fill(body, with: .color(.white))
        var s = ctx
        s.opacity = 0.35
        s.fill(shade, with: .color(Color(hex: 0xD6E6F5)))
        ctx.fill(shine, with: .color(.white))
    }

    static func drawFlakes(_ sim: HairSim, t: Double, in ctx: GraphicsContext) {
        for f in sim.flakes {
            guard let at = sim.position(f.strand, f.node), sim.visible(f.strand, f.node) else { continue }
            let c = (at + f.off).cg
            let tw = 0.55 + 0.45 * sin(t * 5 + Double(f.phase))
            let r = f.size * CGFloat(0.7 + 0.5 * tw)
            var g = ctx
            g.opacity = 0.65 + 0.35 * tw
            if tw > 0.8 {
                g.fill(Twinkle().path(in: CGRect(x: c.x - r * 1.8, y: c.y - r * 1.8, width: r * 3.6, height: r * 3.6)),
                       with: .color(f.color.mix(Shades.white, 0.5).color))
            } else {
                g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.6, y: c.y - r * 0.6, width: r * 1.2, height: r * 1.2)), with: .color(f.color.color))
            }
        }
    }
}

// MARK: - The client

enum ClientPainter {
    private static var cache: [String: [(ArtLayer, PaintSet, ArtItem)]] = [:]

    static func layers(_ look: Look, _ e: Expression) -> [(ArtLayer, PaintSet, ArtItem)] {
        let key = "\(look.id.uuidString)-\(look.picks["hat"] ?? "")-\(e)"
        if let c = cache[key] { return c }
        if cache.count > 24 { cache.removeAll() }
        let l = DollPainter.layers(look, e)
        cache[key] = l
        return l
    }

    /// Layers in z range `z`. Back hat parts are z 8, the face 20-45, brows 56, hats 60.
    static func draw(_ look: Look, _ e: Expression, z: ClosedRange<Int>, in ctx: GraphicsContext) {
        for (layer, p, item) in layers(look, e) where z.contains(layer.z) {
            if item.id == "body" || item.id == "under" { continue }
            ArtPainter.draw(layer.shapes, p, in: ctx)
        }
    }

    /// Her, turned by `yaw`: her head keeps its round shape, her eyes, nose, mouth and brows slide around
    /// it and narrow (and are gone when she has her back to us), her shoulders and clothes narrow.
    static func drawTurned(_ look: Look, _ e: Expression, z: ClosedRange<Int>, yaw: CGFloat, in ctx: GraphicsContext) {
        let c = cos(yaw)
        let sn = sin(yaw)
        var face = ctx
        face.clip(to: Path(ellipseIn: CGRect(x: 300 - SalonBody.rx - 6, y: 287 - SalonBody.ry - 6,
                                             width: SalonBody.rx * 2 + 12, height: SalonBody.ry * 2 + 12)))
        face.opacity = Double(max(0, min(1, (c - 0.12) / 0.25)))
        face.translateBy(x: 300 + sn * 118, y: 0)
        face.scaleBy(x: max(0.01, c), y: 1)
        face.translateBy(x: -300, y: 0)
        var body = ctx
        let sx = SalonBody.bodyScale(yaw)
        body.translateBy(x: 300, y: 0)
        body.scaleBy(x: sx, y: 1)
        body.translateBy(x: -300, y: 0)
        var hat = ctx
        hat.translateBy(x: 300 + sn * 20, y: 0)
        hat.scaleBy(x: max(0.75, abs(c)), y: 1)
        hat.translateBy(x: -300, y: 0)
        for (layer, p, item) in layers(look, e) where z.contains(layer.z) {
            if item.id == "body" || item.id == "under" { continue }
            switch item.category {
            case "face":
                ArtPainter.draw(layer.shapes, p, in: ctx)
            case "hat":
                if layer.z < 10 && c < 0 { continue }
                ArtPainter.draw(layer.shapes, p, in: hat)
            case "eyes", "special", "mouth", "nose", "cheeks", "makeup", "glasses", "brows", "earrings":
                if c > 0.12 { ArtPainter.draw(layer.shapes, p, in: face) }
            default:
                ArtPainter.draw(layer.shapes, p, in: body)
            }
        }
    }
}

// MARK: - Chair and cape

enum SalonFurniture {
    static func drawChairBack(yaw: CGFloat = 0, in base: GraphicsContext) {
        let facing = cos(yaw)
        let sx = SalonBody.bodyScale(yaw)
        var ctx = base
        ctx.translateBy(x: 300, y: 0)
        ctx.scaleBy(x: sx, y: 1)
        ctx.translateBy(x: -300, y: 0)

        let chairOutline = Color(hex: 0x6C4F9C)

        // Chrome swivel collar grounding the seat cushion onto the hydraulic pole at every angle
        let collar = Path(roundedRect: CGRect(x: 256, y: 694, width: 88, height: 18), cornerRadius: 9)
        ctx.fill(collar, with: .linearGradient(Gradient(colors: [Color(hex: 0xEEF2FA), Color(hex: 0xAEB6C8)]),
                                               startPoint: CGPoint(x: 0, y: 694), endPoint: CGPoint(x: 0, y: 712)))
        ctx.stroke(collar, with: .color(Color(hex: 0x7C8299)), lineWidth: 3)

        // Curved plush swivel backrest (slightly sculpted when viewed from the side/back so hair shines)
        let topY: CGFloat = facing >= 0 ? 412 : 430
        let backRect = CGRect(x: 138, y: topY, width: 324, height: 706 - topY)
        let back = Path(roundedRect: backRect, cornerRadius: 74, style: .continuous)
        let topCol = facing >= 0 ? Color(hex: 0xC6A6F2) : Color(hex: 0xB898E8)
        let botCol = facing >= 0 ? Color(hex: 0x9C7AD8) : Color(hex: 0x8B6AC9)
        ctx.fill(back, with: .linearGradient(Gradient(colors: [topCol, botCol]),
                                             startPoint: CGPoint(x: 0, y: topY), endPoint: CGPoint(x: 0, y: 706)))
        ctx.stroke(back, with: .color(chairOutline), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))

        // Rounded swivel armrests on left and right edges
        for side in [-1.0, 1.0] {
            let ax: CGFloat = side < 0 ? 118 : 444
            let arm = Path(roundedRect: CGRect(x: ax, y: 554, width: 38, height: 124), cornerRadius: 19, style: .continuous)
            ctx.fill(arm, with: .linearGradient(Gradient(colors: [Color(hex: 0xD4B8FA), Color(hex: 0xA482DF)]),
                                                startPoint: CGPoint(x: ax, y: 554), endPoint: CGPoint(x: ax + 38, y: 678)))
            ctx.stroke(arm, with: .color(chairOutline), lineWidth: 4)
        }

        // Grounded curved seat cushion base
        let seat = Path(roundedRect: CGRect(x: 134, y: 660, width: 332, height: 48), cornerRadius: 24, style: .continuous)
        ctx.fill(seat, with: .linearGradient(Gradient(colors: [Color(hex: 0xB492E8), Color(hex: 0x8F6ECA)]),
                                             startPoint: CGPoint(x: 0, y: 660), endPoint: CGPoint(x: 0, y: 708)))
        ctx.stroke(seat, with: .color(chairOutline), lineWidth: 4.2)

        if facing > 0.05 {
            var front = ctx
            front.opacity = Double(min(1, facing * 1.4))
            // Tufted velvet buttons on the interior backrest
            for row in 0..<3 {
                for col in 0..<4 {
                    let x = 178 + CGFloat(col) * 82 + (row % 2 == 0 ? 0 : 41)
                    guard x < 440 else { continue }
                    let y = 462 + CGFloat(row) * 70
                    front.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)), with: .color(Color(hex: 0x7F5FB8)))
                }
            }
            var sheen = front
            sheen.opacity = front.opacity * 0.35
            sheen.fill(Path(roundedRect: CGRect(x: 162, y: 426, width: 120, height: 24), cornerRadius: 12), with: .color(.white))
        } else if facing < -0.05 {
            var shell = ctx
            shell.opacity = Double(min(1, -facing * 1.4))
            // Sculpted curved rear trim rail + dainty golden salon emblem
            let inset = Path(roundedRect: CGRect(x: 160, y: topY + 20, width: 280, height: 210), cornerRadius: 56, style: .continuous)
            shell.stroke(inset, with: .color(Color(hex: 0xE2CEFA, alpha: 0.55)), style: StrokeStyle(lineWidth: 3.5))
            let crest = Path(ellipseIn: CGRect(x: 280, y: topY + 46, width: 40, height: 28))
            StorybookArt.fillAndStroke(shell, crest, fill: Color(hex: 0xFFE38A), stroke: StorybookArt.outline(for: 0xD89A3C), width: 2.8)
            StorybookArt.heart(shell, at: CGPoint(x: 300, y: topY + 60), size: 12, color: Theme.pink)
        }
    }

    static func drawChairBase(in ctx: GraphicsContext) {
        let pole = Path(roundedRect: CGRect(x: 284, y: 700, width: 32, height: 46), cornerRadius: 8)
        ctx.fill(pole, with: .linearGradient(Gradient(colors: [Color(hex: 0xE9EDF5), Color(hex: 0x9EA6BA), Color(hex: 0xE9EDF5)]),
                                             startPoint: CGPoint(x: 284, y: 0), endPoint: CGPoint(x: 316, y: 0)))
        ctx.stroke(pole, with: .color(Color(hex: 0x7C8299)), style: StrokeStyle(lineWidth: 3))
        let foot = Path(ellipseIn: CGRect(x: 214, y: 736, width: 172, height: 26))
        ctx.fill(foot, with: .linearGradient(Gradient(colors: [Color(hex: 0xF4F6FB), Color(hex: 0xA7AEC2)]),
                                             startPoint: CGPoint(x: 0, y: 736), endPoint: CGPoint(x: 0, y: 762)))
        ctx.stroke(foot, with: .color(Color(hex: 0x7C8299)), style: StrokeStyle(lineWidth: 3))
    }

    private static var capeCache: Path?

    static func capePath() -> Path {
        if let c = capeCache { return c }
        var top: [CGPoint] = []
        var x: CGFloat = 98
        while x <= 502 {
            if let y = SalonBody.capeTop(x) { top.append(CGPoint(x: x, y: y)) }
            x += 4
        }
        var p = Path()
        guard let first = top.first, let last = top.last else { return p }
        p.move(to: CGPoint(x: first.x, y: SalonBody.capeBottom))
        p.addLines(top)
        p.addLine(to: CGPoint(x: last.x, y: SalonBody.capeBottom))
        // a soft wavy hem
        let w = last.x - first.x
        let waves = 7
        for i in 0..<waves {
            let x0 = last.x - w * CGFloat(i) / CGFloat(waves)
            let x1 = last.x - w * CGFloat(i + 1) / CGFloat(waves)
            p.addQuadCurve(to: CGPoint(x: x1, y: SalonBody.capeBottom),
                           control: CGPoint(x: (x0 + x1) / 2, y: SalonBody.capeBottom + 12))
        }
        p.closeSubpath()
        capeCache = p
        return p
    }

    static func drawCape(color: RGB, yaw: CGFloat = 0, in base: GraphicsContext) {
        var ctx = base
        ctx.translateBy(x: 300, y: 0)
        ctx.scaleBy(x: SalonBody.bodyScale(yaw), y: 1)
        ctx.translateBy(x: -300, y: 0)
        let cape = capePath()
        ctx.fill(cape, with: .linearGradient(Gradient(colors: [color.color, Shades.shade(color).color]),
                                             startPoint: CGPoint(x: 0, y: 436), endPoint: CGPoint(x: 0, y: 730)))
        // little polka dots
        var dots = ctx
        dots.clip(to: cape)
        dots.opacity = 0.55
        var d = Path()
        var row = 0
        var y: CGFloat = 450
        while y < 740 {
            var x: CGFloat = row % 2 == 0 ? 90 : 112
            while x < 520 {
                d.addEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                x += 44
            }
            y += 34
            row += 1
        }
        dots.fill(d, with: .color(Shades.light(color).color))
        // folds
        var folds = ctx
        folds.clip(to: cape)
        folds.opacity = 0.35
        for fx in [-120.0, -60.0, 60.0, 120.0] {
            var f = Path()
            let x0 = 300 + CGFloat(fx) * 0.35
            f.move(to: CGPoint(x: x0, y: 470))
            f.addQuadCurve(to: CGPoint(x: 300 + CGFloat(fx) * 1.3, y: 724), control: CGPoint(x: 300 + CGFloat(fx) * 0.75, y: 600))
            folds.stroke(f, with: .color(Shades.deep(color).color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        ctx.stroke(cape, with: .color(Shades.outline(color).color), style: StrokeStyle(lineWidth: 4.5, lineJoin: .round))
        // collar with a snap
        let collar = Path(roundedRect: CGRect(x: 262, y: 426, width: 76, height: 20), cornerRadius: 10)
        ctx.fill(collar, with: .color(.white))
        ctx.stroke(collar, with: .color(Shades.outline(color).color), style: StrokeStyle(lineWidth: 3.5))
        ctx.fill(Path(ellipseIn: CGRect(x: 294, y: 430, width: 12, height: 12)), with: .color(Color(hex: 0xFFD66E)))
    }
}

// MARK: - Clips, bows and scrunchies

enum ClipPainter {
    static func clipColor(_ i: Int) -> RGB {
        let cloth = DressUpArt.shared.cloth
        return cloth.isEmpty ? RGB(1, 0.6, 0.75) : cloth[min(max(0, i), cloth.count - 1)]
    }

    private static func fo(_ ctx: GraphicsContext, _ p: Path, _ c: RGB, _ w: CGFloat = 2.6) {
        ctx.fill(p, with: .color(c.color))
        ctx.stroke(p, with: .color(Shades.outline(c).color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    static func heart(_ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: s * 0.9))
        p.addCurve(to: CGPoint(x: -s, y: -s * 0.2), control1: CGPoint(x: -s * 0.25, y: s * 0.65), control2: CGPoint(x: -s, y: s * 0.25))
        p.addCurve(to: CGPoint(x: 0, y: -s * 0.45), control1: CGPoint(x: -s, y: -s * 0.75), control2: CGPoint(x: -s * 0.4, y: -s * 0.9))
        p.addCurve(to: CGPoint(x: s, y: -s * 0.2), control1: CGPoint(x: s * 0.4, y: -s * 0.9), control2: CGPoint(x: s, y: -s * 0.75))
        p.addCurve(to: CGPoint(x: 0, y: s * 0.9), control1: CGPoint(x: s, y: s * 0.25), control2: CGPoint(x: s * 0.25, y: s * 0.65))
        p.closeSubpath()
        return p
    }

    static func star(_ r: CGFloat, points: Int = 5, inner: CGFloat = 0.48) -> Path {
        var p = Path()
        for i in 0..<(points * 2) {
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let rr = i % 2 == 0 ? r : r * inner
            let q = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    /// Draws a clip centered at the origin of `ctx` (about 50 units across).
    static func draw(_ kind: HairClip.Kind, color ci: Int, in ctx: GraphicsContext) {
        let c = clipColor(ci)
        switch kind {
        case .bow, .ribbon:
            let big: CGFloat = kind == .ribbon ? 1.15 : 1
            var l = Path()
            l.move(to: .zero)
            l.addCurve(to: CGPoint(x: -24 * big, y: -15), control1: CGPoint(x: -8, y: -12), control2: CGPoint(x: -20 * big, y: -22))
            l.addCurve(to: CGPoint(x: -24 * big, y: 15), control1: CGPoint(x: -30 * big, y: -6), control2: CGPoint(x: -30 * big, y: 8))
            l.addCurve(to: .zero, control1: CGPoint(x: -18 * big, y: 20), control2: CGPoint(x: -8, y: 12))
            l.closeSubpath()
            let r = l.applying(CGAffineTransform(scaleX: -1, y: 1))
            if kind == .ribbon {
                var tails = Path()
                tails.move(to: CGPoint(x: -3, y: 4))
                tails.addLine(to: CGPoint(x: -14, y: 34))
                tails.addLine(to: CGPoint(x: -4, y: 30))
                tails.addLine(to: CGPoint(x: 2, y: 36))
                tails.addLine(to: CGPoint(x: 4, y: 4))
                tails.closeSubpath()
                fo(ctx, tails, Shades.shade(c))
                fo(ctx, tails.applying(CGAffineTransform(scaleX: -1, y: 1)), Shades.shade(c))
            }
            fo(ctx, l, c)
            fo(ctx, r, c)
            var g = ctx
            g.opacity = 0.6
            g.fill(Path(ellipseIn: CGRect(x: -22, y: -12, width: 9, height: 6)), with: .color(Shades.light(c).color))
            g.fill(Path(ellipseIn: CGRect(x: 13, y: -12, width: 9, height: 6)), with: .color(Shades.light(c).color))
            fo(ctx, Path(roundedRect: CGRect(x: -7, y: -8, width: 14, height: 16), cornerRadius: 6), Shades.shade(c))
        case .flower, .daisy:
            let petal = kind == .daisy ? RGB(1, 1, 1) : c
            let mid = kind == .daisy ? RGB(1, 0.84, 0.3) : RGB(1, 0.92, 0.55)
            let n = kind == .daisy ? 8 : 5
            for i in 0..<n {
                let a = CGFloat(i) / CGFloat(n) * 2 * .pi
                let pr: CGFloat = kind == .daisy ? 7 : 10
                let dist: CGFloat = kind == .daisy ? 13 : 11
                let rect = CGRect(x: cos(a) * dist - pr, y: sin(a) * dist - pr, width: pr * 2, height: pr * 2)
                fo(ctx, Path(ellipseIn: rect), petal, 2.2)
            }
            fo(ctx, Path(ellipseIn: CGRect(x: -8, y: -8, width: 16, height: 16)), mid, 2.2)
        case .star:
            fo(ctx, star(19).applying(CGAffineTransform(translationX: 0, y: 1)), c)
            var g = ctx
            g.opacity = 0.7
            g.fill(Path(ellipseIn: CGRect(x: -7, y: -9, width: 6, height: 5)), with: .color(Shades.light(c).color))
        case .heart:
            fo(ctx, heart(17), c)
            var g = ctx
            g.opacity = 0.7
            g.fill(Path(ellipseIn: CGRect(x: -11, y: -8, width: 7, height: 5)), with: .color(Shades.light(c).color))
        case .butterfly:
            var w = Path()
            w.move(to: .zero)
            w.addCurve(to: CGPoint(x: -24, y: -14), control1: CGPoint(x: -6, y: -22), control2: CGPoint(x: -20, y: -26))
            w.addCurve(to: CGPoint(x: -4, y: 2), control1: CGPoint(x: -28, y: -2), control2: CGPoint(x: -14, y: 2))
            w.addCurve(to: CGPoint(x: -16, y: 18), control1: CGPoint(x: -18, y: 4), control2: CGPoint(x: -24, y: 14))
            w.addCurve(to: .zero, control1: CGPoint(x: -8, y: 22), control2: CGPoint(x: -2, y: 12))
            w.closeSubpath()
            fo(ctx, w, c)
            fo(ctx, w.applying(CGAffineTransform(scaleX: -1, y: 1)), c)
            var g = ctx
            g.opacity = 0.7
            g.fill(Path(ellipseIn: CGRect(x: -17, y: -12, width: 7, height: 7)), with: .color(Shades.light(c).color))
            g.fill(Path(ellipseIn: CGRect(x: 10, y: -12, width: 7, height: 7)), with: .color(Shades.light(c).color))
            fo(ctx, Path(roundedRect: CGRect(x: -3, y: -12, width: 6, height: 26), cornerRadius: 3), Shades.deep(c), 2)
        case .pearl:
            for i in 0..<3 {
                let x = CGFloat(i - 1) * 13
                let pr = CGRect(x: x - 6.5, y: -6.5 + abs(CGFloat(i - 1)) * 3, width: 13, height: 13)
                fo(ctx, Path(ellipseIn: pr), RGB(1, 0.98, 0.97), 2)
                ctx.fill(Path(ellipseIn: CGRect(x: pr.minX + 3, y: pr.minY + 2.5, width: 4, height: 3.5)), with: .color(.white))
            }
        case .leaf:
            var l = Path()
            l.move(to: CGPoint(x: -16, y: 6))
            l.addQuadCurve(to: CGPoint(x: 16, y: -6), control: CGPoint(x: -4, y: -16))
            l.addQuadCurve(to: CGPoint(x: -16, y: 6), control: CGPoint(x: 6, y: 14))
            l.closeSubpath()
            let g = RGB(0.48, 0.74, 0.38)
            fo(ctx, l, g, 2)
            var v = Path()
            v.move(to: CGPoint(x: -14, y: 5))
            v.addLine(to: CGPoint(x: 13, y: -5))
            ctx.stroke(v, with: .color(Shades.outline(g).color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        case .twig:
            var t = Path()
            t.move(to: CGPoint(x: -18, y: 4))
            t.addLine(to: CGPoint(x: 18, y: -4))
            t.move(to: CGPoint(x: 2, y: 0))
            t.addLine(to: CGPoint(x: 10, y: -11))
            let b = RGB(0.55, 0.38, 0.25)
            ctx.stroke(t, with: .color(Shades.outline(b).color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            ctx.stroke(t, with: .color(b.color), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }
    }

    static func drawScrunchie(color ci: Int, in ctx: GraphicsContext) {
        let c = clipColor(ci)
        let n = 9
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let rect = CGRect(x: cos(a) * 14 - 9, y: sin(a) * 8 - 8, width: 18, height: 16)
            fo(ctx, Path(ellipseIn: rect), i % 2 == 0 ? c : Shades.shade(c), 2.2)
        }
        var g = ctx
        g.opacity = 0.6
        g.fill(Path(ellipseIn: CGRect(x: -12, y: -10, width: 8, height: 5)), with: .color(Shades.light(c).color))
    }

    static func drawTieCues(_ sim: HairSim, t: Double, in ctx: GraphicsContext) {
        guard !sim.ties.isEmpty else { return }
        let pulse = 0.5 + 0.5 * sin(t * 4.2)
        let r: CGFloat = 27 + CGFloat(pulse) * 4.5
        for tie in sim.ties where SalonBody.visible(tie.at, tie.z, squash: sim.squash) {
            let c = tie.at.cg
            let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.82, width: r * 2, height: r * 1.64))
            ctx.stroke(
                ring,
                with: .color(Theme.lemon.opacity(0.45 + 0.35 * pulse)),
                style: StrokeStyle(lineWidth: 2.8, lineCap: .round, dash: [7, 7])
            )
            let ang = t * 1.9
            for k in 0..<2 {
                let a = ang + Double(k) * .pi
                let sx = c.x + CGFloat(cos(a)) * (r + 2)
                let sy = c.y + CGFloat(sin(a)) * (r * 0.82 + 2)
                StorybookArt.sparkle(ctx, at: CGPoint(x: sx, y: sy), radius: 5.5 + CGFloat(pulse) * 2, color: k == 0 ? Theme.lemon : .white, opacity: 0.9)
            }
        }
    }

    static func drawAll(_ sim: HairSim, in ctx: GraphicsContext) {
        for t in sim.ties where SalonBody.visible(t.at, t.z, squash: sim.squash) {
            var g = ctx
            g.translateBy(x: t.at.x, y: t.at.y)
            drawScrunchie(color: t.color, in: g)
        }
        for c in sim.clips {
            guard let at = sim.clipPosition(c), sim.visible(c.strand, c.node) else { continue }
            var g = ctx
            g.translateBy(x: at.x, y: at.y)
            var swing: CGFloat = 0
            if c.strand < sim.strands.count, c.node >= sim.strands[c.strand].pinned, c.node > 0 {
                let s = sim.strands[c.strand]
                let d = s.p[c.node] - s.p[c.node - 1]
                swing = atan2(-d.x, d.y) * 0.6
            }
            g.rotate(by: .radians(Double(c.tilt + swing)))
            draw(c.kind, color: c.color, in: g)
        }
    }
}
