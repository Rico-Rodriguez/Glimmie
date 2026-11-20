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
            let frizzK: CGFloat = i + 1 >= pinned ? 6.5 : 1.5
            for k in 0..<sub {
                let t = CGFloat(k) / CGFloat(sub)
                let b = catmull(p0, p1, p2, p3, t)
                arc += b.dist(last)
                last = b
                let c = c0 + (c1 - c0) * t
                let jit = j0 + (j1 - j0) * t
                let wave = c * 11 * sin(phase + arc * 0.21)
                let frizz = tangle * frizzK * jit
                out.append(b + tan.perp * (wave + frizz))
            }
        }
        let tipTan = (nodes[n - 1] - nodes[n - 2]).unit
        let cEnd = curl(n - 1)
        arc += nodes[n - 1].dist(last)
        out.append(nodes[n - 1] + tipTan.perp * (cEnd * 11 * sin(phase + arc * 0.21)))
        return out
    }

    /// A ribbon around `line`: full width, narrowing at the tip (and at the root for front locks).
    static func ribbon(_ line: [HairV], width: CGFloat, rootTaper: Bool) -> Path {
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
            if u > 0.62 { w *= max(0.1, 1 - (u - 0.62) / 0.38 * 0.9) }
            if rootTaper && u < 0.2 { w *= 0.3 + 0.7 * (u / 0.2) }
            left.append((line[k] + nrm * w).cg)
            right.append((line[k] - nrm * w).cg)
        }
        path.move(to: left[0])
        path.addLines(left)
        path.addLine(to: line[m - 1].cg)
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

    /// One lock, fully drawn.
    static func drawLock(nodes: [HairV], pinned: Int, colors: [RGB], curl: (Int) -> CGFloat, tangle: CGFloat,
                         jitter: [CGFloat], phase: CGFloat, width: CGFloat, wet: CGFloat, gloss: CGFloat,
                         darker: Bool, rootTaper: Bool, in ctx: GraphicsContext) {
        guard nodes.count >= 2 else { return }
        let line = centerline(nodes, pinned: pinned, curl: curl, tangle: tangle, jitter: jitter, phase: phase)
        let w = width * (1 - 0.14 * wet)
        let shape = ribbon(line, width: w, rootTaper: rootTaper)
        ctx.fill(shape, with: shading(nodes, colors: colors, wet: wet, darker: darker))
        ctx.stroke(shape, with: .color(outlineColor(colors, wet)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        let lightBase = colors[min(colors.count - 1, max(0, pinned))]
        let light = Shades.light(wetColor(lightBase, wet)).color
        let alpha = (darker ? 0.25 : 0.5) + 0.35 * Double(gloss) + 0.25 * Double(wet)
        var g = ctx
        g.opacity = min(1, alpha)
        g.stroke(streak(line, width: w, from: rootTaper ? 0.12 : 0.04, to: 0.5 + 0.2 * gloss),
                 with: .color(light), style: StrokeStyle(lineWidth: 2.6 + 2 * gloss, lineCap: .round, lineJoin: .round))
    }

    static func draw(_ s: HairStrand, darker: Bool, in ctx: GraphicsContext) {
        drawLock(nodes: s.p, pinned: s.pinned, colors: Array(s.color.prefix(s.p.count)), curl: { s.curlNow($0) },
                 tangle: s.tangle, jitter: s.jitter, phase: s.phase, width: s.width, wet: s.wet, gloss: s.gloss,
                 darker: darker, rootTaper: s.front, in: ctx)
    }

    static func draw(_ piece: HairPiece, in ctx: GraphicsContext) {
        var g = ctx
        if piece.age > 30 { g.opacity = max(0, 1 - (piece.age - 30) / 6) }
        let curl = piece.curl
        let wet = piece.wet
        drawLock(nodes: piece.p, pinned: 1, colors: piece.color,
                 curl: { i in i < curl.count ? curl[i] * (1 - 0.7 * wet) : 0 },
                 tangle: piece.tangle, jitter: piece.jitter, phase: piece.phase, width: piece.width, wet: piece.wet,
                 gloss: 0, darker: false, rootTaper: false, in: g)
    }

    // MARK: Layers

    /// Back and nape locks (behind her head).
    static func drawBack(_ sim: HairSim, in ctx: GraphicsContext) {
        let back = sim.strands.filter { !$0.front }.sorted { $0.order < $1.order }
        for s in back { draw(s, darker: true, in: ctx) }
    }

    /// The scalp under the front locks, the front locks, and the shine.
    static func drawFront(_ sim: HairSim, in ctx: GraphicsContext) {
        let front = sim.strands.filter { $0.front }
        guard !front.isEmpty else { return }
        // the cap: average of the colors near the roots
        var r = 0.0, g = 0.0, b = 0.0
        var wet: CGFloat = 0
        for s in front {
            let c = s.color[min(2, s.color.count - 1)]
            r += c.r; g += c.g; b += c.b
            wet += s.wet
        }
        let k = 1.0 / Double(front.count)
        let avg = wetColor(RGB(r * k, g * k, b * k), wet / CGFloat(front.count))
        let cap = capPath()
        ctx.fill(cap, with: .color(avg.color))
        ctx.stroke(cap, with: .color(Shades.outline(avg).color), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        for s in front.sorted(by: { $0.order < $1.order }) { draw(s, darker: false, in: ctx) }
        // the part
        var part = Path()
        part.move(to: CGPoint(x: 300, y: 150))
        part.addQuadCurve(to: CGPoint(x: 300, y: 176), control: CGPoint(x: 302, y: 162))
        ctx.stroke(part, with: .color(Shades.outline(avg).color.opacity(0.7)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        // a ring of shine across the crown, in dashes like the Dress Up hair
        var sh = ctx
        sh.opacity = 0.6
        let light = Shades.light(avg).color
        var th: CGFloat = -0.78
        while th < 0.74 {
            var d = Path()
            let a = SalonBody.head(th, 0.8)
            let m = SalonBody.head(th + 0.08, 0.81)
            let e = SalonBody.head(th + 0.16, 0.8)
            d.move(to: a.cg)
            d.addQuadCurve(to: e.cg, control: m.cg)
            sh.stroke(d, with: .color(light), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            th += 0.25
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
            guard let at = sim.position(b.strand, b.node) else { continue }
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
            guard let at = sim.position(f.strand, f.node) else { continue }
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
}

// MARK: - Chair and cape

enum SalonFurniture {
    static func drawChairBack(in ctx: GraphicsContext) {
        let back = Path(roundedRect: CGRect(x: 138, y: 412, width: 324, height: 300), cornerRadius: 70, style: .continuous)
        ctx.fill(back, with: .linearGradient(Gradient(colors: [Color(hex: 0xC4A3F0), Color(hex: 0x9C7AD8)]),
                                             startPoint: CGPoint(x: 0, y: 412), endPoint: CGPoint(x: 0, y: 712)))
        ctx.stroke(back, with: .color(Color(hex: 0x6C4F9C)), style: StrokeStyle(lineWidth: 4.5))
        // tufted buttons
        for row in 0..<3 {
            for col in 0..<4 {
                let x = 178 + CGFloat(col) * 82 + (row % 2 == 0 ? 0 : 41)
                guard x < 440 else { continue }
                let y = 462 + CGFloat(row) * 70
                ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)), with: .color(Color(hex: 0x7F5FB8)))
            }
        }
        var sheen = ctx
        sheen.opacity = 0.35
        sheen.fill(Path(roundedRect: CGRect(x: 160, y: 426, width: 120, height: 24), cornerRadius: 12), with: .color(.white))
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

    static func drawCape(color: RGB, in ctx: GraphicsContext) {
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

    static func drawAll(_ sim: HairSim, in ctx: GraphicsContext) {
        for t in sim.ties {
            var g = ctx
            g.translateBy(x: t.at.x, y: t.at.y)
            drawScrunchie(color: t.color, in: g)
        }
        for c in sim.clips {
            guard let at = sim.clipPosition(c) else { continue }
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
