import SwiftUI

// MARK: - Fish, drawn
//
// Every fish is drawn facing right around the middle of its body, nose at +length/2. The body outline is sampled along
// its length and bends with the tail beat (the rear swings most, the head a little the other way), so a swimming fish
// flexes instead of sliding. Bands and stripes follow the same outline, so they bend with it. Outlines are a deeper
// shade of the fish's own color, never black, like the other games.

private let aqInk = ARGB(0x2A2238)

struct AquaBody {
    let L: CGFloat
    let H: CGFloat
    /// Profile exponents: how quickly it fills out behind the head (a) and rounds off at the nose (b).
    var a: CGFloat = 0.8
    var b: CGFloat = 0.55
    var bend: CGFloat = 0
    var belly: CGFloat = 0.94
    /// 0 ... 1: blends the outline toward a ball (the puffer).
    var round: CGFloat = 0

    private var peak: CGFloat {
        let u = a / (a + b)
        return pow(u, a) * pow(1 - u, b)
    }

    func x(_ u: CGFloat) -> CGFloat { -L / 2 + u * L }

    func half(_ u: CGFloat) -> CGFloat {
        let uu = max(0, min(1, u))
        let shape = 0.2 * (1 - uu) + 0.8 * pow(uu, a) * pow(1 - uu, b) / peak
        let normal = H / 2 * shape
        guard round > 0 else { return normal }
        let ball = sqrt(max(0, 1 - pow(2 * uu - 1, 2))) * L * 0.5
        return normal + (ball - normal) * round
    }

    func cy(_ u: CGFloat) -> CGFloat {
        let w = 1 - u
        return bend * L * (0.22 * w * w - 0.035)
    }

    func top(_ u: CGFloat) -> CGPoint { CGPoint(x: x(u), y: cy(u) - half(u)) }
    func bottom(_ u: CGFloat) -> CGPoint { CGPoint(x: x(u), y: cy(u) + half(u) * belly) }
    /// A point inside the body: f = -1 on the top edge, 0 on the middle line, 1 on the belly.
    func at(_ u: CGFloat, _ f: CGFloat) -> CGPoint {
        CGPoint(x: x(u), y: cy(u) + half(u) * (f < 0 ? f : f * belly))
    }

    var outline: Path {
        var pts: [CGPoint] = []
        let n = 14
        for k in 0...n { pts.append(top(CGFloat(k) / CGFloat(n))) }
        for k in stride(from: n - 1, through: 1, by: -1) { pts.append(bottom(CGFloat(k) / CGFloat(n))) }
        pts.append(bottom(0))
        return AquaShape.smoothClosed(pts)
    }

    /// A band across the body from u0 to u1, following the outline.
    func band(_ u0: CGFloat, _ u1: CGFloat) -> Path {
        var pts: [CGPoint] = []
        let n = 4
        for k in 0...n { pts.append(at(u0 + (u1 - u0) * CGFloat(k) / CGFloat(n), -1.02)) }
        for k in stride(from: n, through: 0, by: -1) { pts.append(at(u0 + (u1 - u0) * CGFloat(k) / CGFloat(n), 1.02)) }
        return AquaShape.smoothClosed(pts)
    }

    /// A stripe along the body from u0 to u1, between heights f0 and f1 (-1 top ... 1 belly).
    func strip(_ u0: CGFloat, _ u1: CGFloat, _ f0: CGFloat, _ f1: CGFloat) -> Path {
        var pts: [CGPoint] = []
        let n = 8
        for k in 0...n { pts.append(at(u0 + (u1 - u0) * CGFloat(k) / CGFloat(n), f0)) }
        for k in stride(from: n, through: 0, by: -1) { pts.append(at(u0 + (u1 - u0) * CGFloat(k) / CGFloat(n), f1)) }
        return AquaShape.smoothClosed(pts)
    }

    /// A fin standing on the top edge (up < 0) or hanging from the belly (up > 0), swept back toward the tail.
    func fin(_ u0: CGFloat, _ u1: CGFloat, height: CGFloat, sweep: CGFloat, belly under: Bool, ripple: CGFloat = 0) -> Path {
        let front = under ? bottom(u1) : top(u1)
        let back = under ? bottom(u0) : top(u0)
        let s: CGFloat = under ? 1 : -1
        let tip = CGPoint(x: back.x - sweep, y: back.y + s * height * (1 + ripple))
        var p = Path()
        p.move(to: CGPoint(x: front.x, y: front.y - s * 2))
        p.addQuadCurve(to: tip, control: CGPoint(x: front.x - (front.x - tip.x) * 0.35, y: front.y + s * height * 0.95))
        p.addQuadCurve(to: CGPoint(x: back.x, y: back.y - s * 2), control: CGPoint(x: tip.x + 4, y: (tip.y + back.y) / 2))
        p.closeSubpath()
        return p
    }
}

enum AquaShape {
    /// A smooth closed curve through the middles of the edges of a polygon.
    static func smoothClosed(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard pts.count > 2 else { return p }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        p.move(to: mid(pts[pts.count - 1], pts[0]))
        for i in 0..<pts.count {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            p.addQuadCurve(to: mid(a, b), control: a)
        }
        p.closeSubpath()
        return p
    }

    /// A smooth open curve through points.
    static func smoothOpen(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard pts.count > 1 else { return p }
        p.move(to: pts[0])
        if pts.count == 2 { p.addLine(to: pts[1]); return p }
        for i in 1..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            p.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: a)
        }
        p.addLine(to: pts[pts.count - 1])
        return p
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func heart(_ c: CGPoint, _ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + s * 0.45))
        p.addCurve(to: CGPoint(x: c.x - s * 0.5, y: c.y - s * 0.12), control1: CGPoint(x: c.x - s * 0.2, y: c.y + s * 0.25),
                   control2: CGPoint(x: c.x - s * 0.5, y: c.y + s * 0.1))
        p.addArc(center: CGPoint(x: c.x - s * 0.25, y: c.y - s * 0.15), radius: s * 0.26, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: c.x + s * 0.25, y: c.y - s * 0.15), radius: s * 0.26, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.45), control1: CGPoint(x: c.x + s * 0.5, y: c.y + s * 0.1),
                   control2: CGPoint(x: c.x + s * 0.2, y: c.y + s * 0.25))
        p.closeSubpath()
        return p
    }
}

/// What a fish looks like (per kind and colorway).
struct FishColors {
    var body: ARGB
    var belly: ARGB
    var fin: ARGB
    var finEdge: ARGB
    var finAlpha: Double = 0.82
}

enum AquaFishPainter {
    static func colors(_ k: FishKind, _ v: Int) -> FishColors {
        if v >= AquaRare.variant { return AquaRare.colors(k) }
        switch k {
        case .goldfish:
            switch v {
            case 1: return FishColors(body: ARGB(0xFFF4EA), belly: ARGB(0xFFFFFF), fin: ARGB(0xFFE9DC), finEdge: ARGB(0xFF9A7A), finAlpha: 0.7)
            case 2: return FishColors(body: ARGB(0xFFC531), belly: ARGB(0xFFE9A0), fin: ARGB(0xFFD45C), finEdge: ARGB(0xFFF1B8), finAlpha: 0.75)
            default: return FishColors(body: ARGB(0xFF8A2B), belly: ARGB(0xFFD08A), fin: ARGB(0xFF9A45), finEdge: ARGB(0xFFD3A0), finAlpha: 0.75)
            }
        case .clownfish:
            return FishColors(body: ARGB(0xFF7A1F), belly: ARGB(0xFFA552), fin: ARGB(0xFF8A2E), finEdge: ARGB(0x3B2A35), finAlpha: 0.95)
        case .angelfish:
            return FishColors(body: ARGB(0xEEF0F2), belly: ARGB(0xFFFFFF), fin: ARGB(0xF3E9C4), finEdge: ARGB(0xFFFFFF), finAlpha: 0.7)
        case .tetra:
            return FishColors(body: ARGB(0xC6D2DE), belly: ARGB(0xE9EEF2), fin: ARGB(0xE4ECF2), finEdge: ARGB(0xFFFFFF), finAlpha: 0.45)
        case .puffer:
            return FishColors(body: ARGB(0xEBCB6A), belly: ARGB(0xFFF6DC), fin: ARGB(0xF2DA8A), finEdge: ARGB(0xFFF1C2), finAlpha: 0.7)
        case .betta:
            switch v {
            case 1: return FishColors(body: ARGB(0xE8344E), belly: ARGB(0xFF6E7E), fin: ARGB(0xFF4F6A), finEdge: ARGB(0xFFB3C1), finAlpha: 0.85)
            case 2: return FishColors(body: ARGB(0x3A7BEA), belly: ARGB(0x6FA6FF), fin: ARGB(0x4F8DF5), finEdge: ARGB(0xB9E0FF), finAlpha: 0.85)
            default: return FishColors(body: ARGB(0x7A4BE0), belly: ARGB(0xA07CF0), fin: ARGB(0x9B5CF0), finEdge: ARGB(0xFFA3DD), finAlpha: 0.85)
            }
        case .guppy:
            switch v {
            case 1: return FishColors(body: ARGB(0xB8C4CA), belly: ARGB(0xE6ECEE), fin: ARGB(0x46A6FF), finEdge: ARGB(0x9BE8FF), finAlpha: 0.88)
            case 2: return FishColors(body: ARGB(0xB8C4CA), belly: ARGB(0xE6ECEE), fin: ARGB(0xFF5FA2), finEdge: ARGB(0xFFD15C), finAlpha: 0.88)
            default: return FishColors(body: ARGB(0xB8C4CA), belly: ARGB(0xE6ECEE), fin: ARGB(0xFF8A3D), finEdge: ARGB(0xFFE066), finAlpha: 0.88)
            }
        case .seahorse:
            switch v {
            case 1: return FishColors(body: ARGB(0xFF8C7A), belly: ARGB(0xFFC2B4), fin: ARGB(0xFFD9CF), finEdge: ARGB(0xFFFFFF), finAlpha: 0.7)
            case 2: return FishColors(body: ARGB(0xB9A2FF), belly: ARGB(0xDCD0FF), fin: ARGB(0xEAE2FF), finEdge: ARGB(0xFFFFFF), finAlpha: 0.7)
            default: return FishColors(body: ARGB(0xFFC94A), belly: ARGB(0xFFE7A0), fin: ARGB(0xFFF0C4), finEdge: ARGB(0xFFFFFF), finAlpha: 0.7)
            }
        }
    }

    /// Draws a fish where it is in the tank.
    static func draw(_ ctx: GraphicsContext, _ f: AquaFish, time: CGFloat, pitch: CGFloat) {
        var g = ctx
        g.translateBy(x: f.p.x, y: f.p.y)
        let side: CGFloat = f.facing < 0 ? -1 : 1
        var sx = f.facing
        if abs(sx) < 0.14 { sx = 0.14 * side }
        // a happy wiggle after a tap
        let since = CGFloat(Double(time) - f.happy)
        let wiggle = since < 0.9 ? sin(since * 26) * 0.18 * (1 - since / 0.9) : 0
        g.rotate(by: .radians(Double(pitch * side + wiggle)))
        let s = f.scale
        g.scaleBy(x: sx * s, y: s)
        drawLocal(g, kind: f.kind, variant: f.variant, phase: f.phase, amp: f.amp, gulp: f.gulp, puff: f.puff, time: time, turning: 1 - abs(sx))
    }

    /// The fish in its own space, facing right. `turning` (0 ... 1) dims the far fins while it turns.
    static func drawLocal(_ g: GraphicsContext, kind: FishKind, variant: Int, phase: CGFloat, amp: CGFloat, gulp: CGFloat,
                          puff: CGFloat, time: CGFloat, turning: CGFloat = 0) {
        let c = colors(kind, variant)
        switch kind {
        case .goldfish: goldfish(g, c, phase, amp, gulp, time)
        case .clownfish: clownfish(g, c, phase, amp, gulp, time)
        case .angelfish: angelfish(g, c, phase, amp, gulp, time)
        case .tetra: tetra(g, c, phase, amp, gulp)
        case .puffer: puffer(g, c, phase, amp, gulp, puff, time)
        case .betta: betta(g, c, phase, amp, gulp, time)
        case .guppy: guppy(g, c, phase, amp, gulp, time)
        case .seahorse: seahorse(g, c, phase, amp, gulp, time)
        }
    }

    // MARK: Shared parts

    private static func fillFin(_ g: GraphicsContext, _ p: Path, _ c: FishColors, rays: Path? = nil) {
        g.fill(p, with: .color(c.fin.color(c.finAlpha)))
        if let r = rays { g.stroke(r, with: .color(c.fin.shade(-0.3).color(0.35)), lineWidth: 0.8) }
        g.stroke(p, with: .color(c.fin.shade(-0.35).color(0.55)), lineWidth: 1)
    }

    private static func fillBody(_ g: GraphicsContext, _ b: AquaBody, _ c: FishColors) {
        let path = b.outline
        g.fill(path, with: .linearGradient(Gradient(colors: [c.body.shade(-0.14).color, c.body.color, c.belly.color]),
                                           startPoint: CGPoint(x: 0, y: -b.H / 2), endPoint: CGPoint(x: 0, y: b.H / 2)))
    }

    private static func outlineBody(_ g: GraphicsContext, _ b: AquaBody, _ c: FishColors) {
        g.stroke(b.outline, with: .color(c.body.shade(-0.45).color(0.7)), lineWidth: 1.2)
        // a soft sheen along the back
        var sheen = Path()
        sheen.move(to: b.at(0.3, -0.72))
        sheen.addQuadCurve(to: b.at(0.8, -0.6), control: b.at(0.58, -0.95))
        g.stroke(sheen, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: max(1.5, b.H * 0.07), lineCap: .round))
    }

    private static func gill(_ g: GraphicsContext, _ b: AquaBody, _ c: FishColors, at u: CGFloat = 0.7) {
        var p = Path()
        p.move(to: b.at(u + 0.02, -0.6))
        p.addQuadCurve(to: b.at(u + 0.02, 0.6), control: b.at(u - 0.06, 0))
        g.stroke(p, with: .color(c.body.shade(-0.35).color(0.45)), lineWidth: 1)
    }

    private static func eye(_ g: GraphicsContext, _ b: AquaBody, at u: CGFloat = 0.84, f: CGFloat = -0.22, size: CGFloat? = nil, iris: ARGB? = nil) {
        let c = b.at(u, f)
        let r = size ?? max(2.4, b.H * 0.12)
        g.fill(AquaShape.circle(c, r), with: .color(.white))
        if let ir = iris { g.fill(AquaShape.circle(CGPoint(x: c.x + r * 0.12, y: c.y), r * 0.78), with: .color(ir.color)) }
        g.fill(AquaShape.circle(CGPoint(x: c.x + r * 0.18, y: c.y + r * 0.02), r * 0.58), with: .color(aqInk.color))
        g.fill(AquaShape.circle(CGPoint(x: c.x + r * 0.38, y: c.y - r * 0.3), r * 0.22), with: .color(.white))
        g.stroke(AquaShape.circle(c, r), with: .color(aqInk.color(0.35)), lineWidth: 0.6)
    }

    private static func mouth(_ g: GraphicsContext, _ b: AquaBody, _ c: FishColors, gulp: CGFloat) {
        let n = b.at(0.985, 0.12)
        if gulp > 0.05 {
            let r = max(1.6, b.H * 0.09) * (0.5 + 0.6 * gulp)
            g.fill(Path(ellipseIn: CGRect(x: n.x - r * 0.8, y: n.y - r, width: r * 1.6, height: r * 2)), with: .color(ARGB(0x8A3A5A).color(0.9)))
        } else {
            var m = Path()
            m.move(to: CGPoint(x: n.x - b.H * 0.12, y: n.y + 0.5))
            m.addQuadCurve(to: CGPoint(x: n.x, y: n.y), control: CGPoint(x: n.x - b.H * 0.05, y: n.y + b.H * 0.06))
            g.stroke(m, with: .color(c.body.shade(-0.5).color(0.8)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    /// A pectoral fin on the side of the body, rowing.
    private static func pectoral(_ g: GraphicsContext, _ b: AquaBody, _ c: FishColors, phase: CGFloat, len: CGFloat, at u: CGFloat = 0.62) {
        let base = b.at(u, 0.25)
        let a = 0.5 + sin(phase * 1.3) * 0.35
        var p = Path()
        p.move(to: base)
        let tip = CGPoint(x: base.x - cos(a) * len, y: base.y + sin(a) * len)
        p.addQuadCurve(to: tip, control: CGPoint(x: base.x - len * 0.2, y: base.y + len * 0.7))
        p.addQuadCurve(to: base, control: CGPoint(x: base.x - len * 0.75, y: base.y - len * 0.05))
        p.closeSubpath()
        g.fill(p, with: .color(c.fin.color(c.finAlpha * 0.85)))
        g.stroke(p, with: .color(c.fin.shade(-0.35).color(0.45)), lineWidth: 0.8)
    }

    /// The tail, in a context moved to the tail's root and turned with the beat.
    private static func tailContext(_ g: GraphicsContext, _ b: AquaBody, phase: CGFloat, amp: CGFloat) -> GraphicsContext {
        var t = g
        let root = CGPoint(x: b.x(0) + 2, y: b.cy(0))
        t.translateBy(x: root.x, y: root.y)
        t.rotate(by: .radians(Double(sin(phase - 1.0) * amp * 1.5)))
        return t
    }

    /// Fan, fork or round tail; `spread` is half its height.
    private static func tail(_ len: CGFloat, _ spread: CGFloat, notch: CGFloat, round: Bool, ripple: CGFloat, phase: CGFloat) -> Path {
        var p = Path()
        let r0 = spread * 0.18
        p.move(to: CGPoint(x: 2, y: -r0))
        let w1 = sin(phase * 1.7) * ripple, w2 = sin(phase * 1.7 + 1.4) * ripple
        if round {
            p.addCurve(to: CGPoint(x: -len, y: w1), control1: CGPoint(x: -len * 0.35, y: -spread * 1.2),
                       control2: CGPoint(x: -len * 1.05, y: -spread * 0.9 + w1))
            p.addCurve(to: CGPoint(x: 2, y: r0), control1: CGPoint(x: -len * 1.05, y: spread * 0.9 + w2),
                       control2: CGPoint(x: -len * 0.35, y: spread * 1.2))
        } else {
            p.addQuadCurve(to: CGPoint(x: -len, y: -spread + w1), control: CGPoint(x: -len * 0.45, y: -spread * 0.55))
            p.addQuadCurve(to: CGPoint(x: -len * (1 - notch), y: (w1 + w2) * 0.5), control: CGPoint(x: -len * 0.85, y: -spread * 0.35 + w1))
            p.addQuadCurve(to: CGPoint(x: -len, y: spread + w2), control: CGPoint(x: -len * 0.85, y: spread * 0.35 + w2))
            p.addQuadCurve(to: CGPoint(x: 2, y: r0), control: CGPoint(x: -len * 0.45, y: spread * 0.55))
        }
        p.closeSubpath()
        return p
    }

    private static func tailRays(_ len: CGFloat, _ spread: CGFloat, count: Int) -> Path {
        var p = Path()
        for k in 0..<count {
            let f = CGFloat(k) / CGFloat(max(1, count - 1)) * 2 - 1
            p.move(to: CGPoint(x: 0, y: f * spread * 0.15))
            p.addLine(to: CGPoint(x: -len * 0.9, y: f * spread * 0.85))
        }
        return p
    }

    /// A long flowing fin edge, waving (betta and guppy tails).
    private static func flowing(_ len: CGFloat, _ spread: CGFloat, phase: CGFloat, waves: Int, droop: CGFloat = 0) -> Path {
        var pts: [CGPoint] = [CGPoint(x: 4, y: -spread * 0.14)]
        let n = 12
        for k in 0...n {
            let a = -1 + 2 * CGFloat(k) / CGFloat(n)
            let wave = sin(CGFloat(k) * CGFloat(waves) * 0.9 + phase * 2) * len * 0.06
            let r = len * (0.92 + 0.08 * cos(a * .pi / 2)) + wave
            pts.append(CGPoint(x: -r * cos(a * 0.9), y: a * spread + droop * len * (1 - abs(a)) * 0.3 + r * sin(a * 0.9) * 0.2))
        }
        pts.append(CGPoint(x: 4, y: spread * 0.14))
        return AquaShape.smoothClosed(pts)
    }

    // MARK: Kinds

    private static func goldfish(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat) {
        var b = AquaBody(L: 70, H: 46)
        b.a = 0.85; b.b = 0.5
        b.bend = sin(phase) * amp * 0.5
        // a double fan tail, flowing
        let tg = tailContext(g, b, phase: phase, amp: amp)
        let tp = flowing(48, 34, phase: phase, waves: 3)
        fillFin(tg, tp, c, rays: tailRays(48, 34, count: 7))
        // fins below and on the back
        fillFin(g, b.fin(0.1, 0.28, height: 16, sweep: 10, belly: true, ripple: sin(phase * 0.8) * 0.12), c)
        fillFin(g, b.fin(0.25, 0.62, height: 20, sweep: 16, belly: false, ripple: sin(phase * 0.6 + 1) * 0.1), c)
        fillFin(g, b.fin(0.52, 0.62, height: 13, sweep: 8, belly: true, ripple: sin(phase) * 0.15), c)
        fillBody(g, b, c)
        if c.body == ARGB(0xFFF4EA) {
            // the red-and-white one: a red saddle
            g.fill(b.strip(0.1, 0.9, -1.05, -0.15), with: .color(ARGB(0xF0523A).color(0.92)))
            g.fill(b.band(0.8, 1.0), with: .color(ARGB(0xF0523A).color(0.85)))
        }
        // scales: a few soft arcs
        var scales = Path()
        for row in 0..<3 {
            for k in 0..<5 {
                let u = 0.15 + CGFloat(k) * 0.11 + CGFloat(row % 2) * 0.055
                let p = b.at(u, -0.55 + CGFloat(row) * 0.5)
                scales.move(to: CGPoint(x: p.x + 3, y: p.y - 4))
                scales.addQuadCurve(to: CGPoint(x: p.x + 3, y: p.y + 4), control: CGPoint(x: p.x - 3, y: p.y))
            }
        }
        g.stroke(scales, with: .color(c.body.shade(-0.3).color(0.3)), lineWidth: 0.9)
        gill(g, b, c)
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase, len: 15)
        eye(g, b, size: 6, iris: ARGB(0xFFD86B))
        mouth(g, b, c, gulp: gulp)
    }

    private static func clownfish(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat) {
        var b = AquaBody(L: 60, H: 32)
        b.a = 0.9; b.b = 0.6
        b.bend = sin(phase) * amp * 0.55
        let tg = tailContext(g, b, phase: phase, amp: amp)
        let tp = tail(20, 15, notch: 0, round: true, ripple: 1.5, phase: phase)
        fillFin(tg, tp, c)
        tg.stroke(tp, with: .color(c.finEdge.color(0.85)), lineWidth: 1.8)
        let dorsal = b.fin(0.2, 0.62, height: 11, sweep: 6, belly: false, ripple: sin(phase * 0.7) * 0.1)
        let anal = b.fin(0.12, 0.32, height: 9, sweep: 5, belly: true)
        for p in [dorsal, anal] {
            fillFin(g, p, c)
            g.stroke(p, with: .color(c.finEdge.color(0.85)), lineWidth: 1.6)
        }
        fillBody(g, b, c)
        // three white bands, edged dark
        for (u0, u1) in [(0.7, 0.8), (0.38, 0.5), (0.03, 0.1)] as [(CGFloat, CGFloat)] {
            let band = b.band(u0, u1)
            g.fill(band, with: .color(.white))
            g.stroke(band, with: .color(c.finEdge.color(0.8)), lineWidth: 1.4)
        }
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase, len: 11, at: 0.6)
        eye(g, b, at: 0.86, size: 4.4, iris: ARGB(0xFFB15C))
        mouth(g, b, c, gulp: gulp)
    }

    private static func angelfish(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat) {
        var b = AquaBody(L: 52, H: 58)
        b.a = 1.05; b.b = 0.95
        b.bend = sin(phase) * amp * 0.35
        let tg = tailContext(g, b, phase: phase, amp: amp * 0.7)
        let tp = tail(28, 20, notch: 0.45, round: false, ripple: 1.2, phase: phase)
        fillFin(tg, tp, c, rays: tailRays(28, 20, count: 6))
        // tall swept fins above and below, and long streamers
        let wave = sin(phase * 0.5) * 0.06
        fillFin(g, b.fin(0.18, 0.6, height: 44, sweep: 30, belly: false, ripple: wave), c, rays: nil)
        fillFin(g, b.fin(0.18, 0.6, height: 42, sweep: 30, belly: true, ripple: -wave), c, rays: nil)
        var streamers = Path()
        let s0 = b.at(0.62, 0.95)
        streamers.move(to: s0)
        streamers.addQuadCurve(to: CGPoint(x: s0.x - 22, y: s0.y + 40 + sin(phase * 0.8) * 4), control: CGPoint(x: s0.x + 2, y: s0.y + 24))
        g.stroke(streamers, with: .color(c.fin.shade(-0.2).color(0.8)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        fillBody(g, b, c)
        // a golden blush on the head and dark bars, a little see-through
        g.fill(b.strip(0.55, 1, -1.02, -0.2), with: .color(ARGB(0xF6D978).color(0.5)))
        for (u0, u1) in [(0.2, 0.3), (0.5, 0.6), (0.8, 0.86)] as [(CGFloat, CGFloat)] {
            g.fill(b.band(u0, u1), with: .color(ARGB(0x4C465C).color(0.72)))
        }
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase, len: 10, at: 0.64)
        eye(g, b, at: 0.83, f: -0.18, size: 4.6, iris: ARGB(0xE0503C))
        mouth(g, b, c, gulp: gulp)
    }

    private static func tetra(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat) {
        var b = AquaBody(L: 30, H: 12)
        b.a = 0.8; b.b = 0.5
        b.bend = sin(phase) * amp * 0.6
        let tg = tailContext(g, b, phase: phase, amp: amp)
        fillFin(tg, tail(11, 7, notch: 0.5, round: false, ripple: 0.4, phase: phase), c)
        fillFin(g, b.fin(0.42, 0.55, height: 5, sweep: 3, belly: false), c)
        fillFin(g, b.fin(0.15, 0.35, height: 4, sweep: 2, belly: true), c)
        fillBody(g, b, c)
        neon(g, b)
        g.stroke(b.outline, with: .color(c.body.shade(-0.4).color(0.5)), lineWidth: 0.7)
        eye(g, b, at: 0.86, f: -0.15, size: 2.6, iris: ARGB(0x7FC8FF))
    }

    /// The neon tetra's stripes (drawn again glowing at night).
    static func neon(_ g: GraphicsContext, _ b: AquaBody) {
        g.fill(b.strip(0.0, 0.5, 0.1, 0.92), with: .color(ARGB(0xFF3B5C).color(0.95)))
        g.fill(b.strip(0.12, 0.92, -0.5, -0.02), with: .linearGradient(Gradient(colors: [ARGB(0x2FD7FF).color, ARGB(0x3E8BFF).color]),
                                                                          startPoint: CGPoint(x: b.x(0.1), y: 0), endPoint: CGPoint(x: b.x(0.92), y: 0)))
    }

    static func tetraBody(phase: CGFloat, amp: CGFloat) -> AquaBody {
        var b = AquaBody(L: 30, H: 12)
        b.a = 0.8; b.b = 0.5
        b.bend = sin(phase) * amp * 0.6
        return b
    }

    private static func puffer(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ puff: CGFloat, _ t: CGFloat) {
        let p = max(0, min(1.1, puff))
        var b = AquaBody(L: 52 * (1 + 0.18 * p), H: 42)
        b.a = 0.9; b.b = 0.55
        b.round = min(1, p)
        b.bend = sin(phase) * amp * 0.3 * (1 - p)
        let tg = tailContext(g, b, phase: phase * 1.4, amp: amp)
        fillFin(tg, tail(14, 10, notch: 0, round: true, ripple: 1, phase: phase), c)
        fillFin(g, b.fin(0.2, 0.36, height: 8, sweep: 4, belly: false, ripple: sin(phase * 2) * 0.3), c)
        fillFin(g, b.fin(0.18, 0.32, height: 7, sweep: 4, belly: true, ripple: sin(phase * 2 + 1) * 0.3), c)
        // spines stand up as it puffs
        if p > 0.15 {
            var spikes = Path()
            for k in 0..<22 {
                let a = CGFloat(k) / 22 * 2 * .pi
                let r = b.L * 0.5
                let o = CGPoint(x: cos(a) * r * 0.98, y: sin(a) * r * 0.98)
                let len = 6 * p
                spikes.move(to: CGPoint(x: o.x + cos(a + 1.5) * 1.6, y: o.y + sin(a + 1.5) * 1.6))
                spikes.addLine(to: CGPoint(x: o.x + cos(a) * len, y: o.y + sin(a) * len))
                spikes.addLine(to: CGPoint(x: o.x + cos(a - 1.5) * 1.6, y: o.y + sin(a - 1.5) * 1.6))
                spikes.closeSubpath()
            }
            g.fill(spikes, with: .color(c.body.shade(-0.25).color(Double(min(1, p * 1.5)))))
        }
        fillBody(g, b, c)
        // brown spots on its back
        var spots = Path()
        for k in 0..<9 {
            let u = 0.18 + CGFloat(k % 5) * 0.14
            let f: CGFloat = k < 5 ? -0.55 : -0.2
            let q = b.at(u, f)
            let r: CGFloat = 2.2 + CGFloat(k % 3) * 0.7
            spots.addEllipse(in: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2))
        }
        g.fill(spots, with: .color(ARGB(0x9A7032).color(0.6)))
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase * 2.2, len: 10, at: 0.62)
        eye(g, b, at: 0.8, f: -0.32, size: 7, iris: ARGB(0x5ED1B8))
        mouth(g, b, c, gulp: max(gulp, p * 0.6))
    }

    private static func betta(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat) {
        var b = AquaBody(L: 50, H: 22)
        b.a = 0.8; b.b = 0.55
        b.bend = sin(phase) * amp * 0.4
        let grad = Gradient(colors: [c.fin.color(0.9), c.finEdge.color(0.65)])
        // the big flowing veil tail
        let tg = tailContext(g, b, phase: phase * 0.6, amp: amp * 0.6)
        let tp = flowing(52, 40, phase: t * 1.6, waves: 4, droop: 0.4)
        tg.fill(tp, with: .radialGradient(grad, center: .zero, startRadius: 4, endRadius: 52))
        tg.stroke(tailRays(52, 40, count: 9), with: .color(c.fin.shade(-0.3).color(0.25)), lineWidth: 0.8)
        // long fins above and a curtain below
        let w = sin(t * 1.6) * 0.08
        let dorsal = b.fin(0.15, 0.55, height: 22, sweep: 24, belly: false, ripple: w)
        let anal = b.fin(0.0, 0.6, height: 30, sweep: 26, belly: true, ripple: -w)
        for p in [anal, dorsal] {
            g.fill(p, with: .linearGradient(grad, startPoint: b.at(0.4, 0), endPoint: CGPoint(x: b.x(0) - 20, y: 30)))
            g.stroke(p, with: .color(c.fin.shade(-0.3).color(0.4)), lineWidth: 0.8)
        }
        fillBody(g, b, c)
        // an iridescent shimmer
        g.fill(b.strip(0.2, 0.8, -0.6, 0.1), with: .color(ARGB(0x9EE8FF).color(0.18)))
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase * 1.4, len: 9, at: 0.66)
        eye(g, b, at: 0.85, size: 3.8, iris: ARGB(0xFFB15C))
        mouth(g, b, c, gulp: gulp)
    }

    private static func guppy(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat) {
        var b = AquaBody(L: 32, H: 13)
        b.a = 0.8; b.b = 0.5
        b.bend = sin(phase) * amp * 0.6
        let tg = tailContext(g, b, phase: phase, amp: amp * 0.9)
        let tp = flowing(30, 18, phase: phase, waves: 2)
        tg.fill(tp, with: .linearGradient(Gradient(colors: [c.fin.color(0.95), c.finEdge.color(0.9)]),
                                          startPoint: .zero, endPoint: CGPoint(x: -30, y: 0)))
        var dots = Path()
        for k in 0..<6 {
            let q = CGPoint(x: -8 - CGFloat(k % 3) * 7, y: CGFloat(k / 3) * 9 - 5)
            dots.addEllipse(in: CGRect(x: q.x - 1.6, y: q.y - 1.6, width: 3.2, height: 3.2))
        }
        tg.fill(dots, with: .color(aqInk.color(0.4)))
        fillFin(g, b.fin(0.3, 0.5, height: 8, sweep: 8, belly: false), FishColors(body: c.fin, belly: c.fin, fin: c.fin, finEdge: c.finEdge, finAlpha: 0.85))
        fillBody(g, b, c)
        g.fill(b.strip(0.05, 0.45, -0.3, 0.6), with: .color(c.fin.color(0.45)))
        g.stroke(b.outline, with: .color(c.body.shade(-0.4).color(0.55)), lineWidth: 0.8)
        eye(g, b, at: 0.85, f: -0.15, size: 2.8)
        mouth(g, b, c, gulp: gulp)
    }

    /// Upright, snout to the right, curled tail below; the little back fin flutters fast.
    private static func seahorse(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat) {
        let bob = sin(t * 1.4 + phase * 0.05) * 1.2
        var h = g
        h.translateBy(x: 0, y: bob)
        // the curled tail
        var tailPath = Path()
        tailPath.move(to: CGPoint(x: -4, y: 18))
        tailPath.addCurve(to: CGPoint(x: 2, y: 40), control1: CGPoint(x: -8, y: 28), control2: CGPoint(x: -6, y: 38))
        tailPath.addCurve(to: CGPoint(x: 9, y: 33), control1: CGPoint(x: 7, y: 43), control2: CGPoint(x: 11, y: 38))
        tailPath.addQuadCurve(to: CGPoint(x: 4, y: 31), control: CGPoint(x: 7, y: 29))
        h.stroke(tailPath, with: .color(c.body.shade(-0.35).color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        h.stroke(tailPath, with: .color(c.body.color), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        // the back fin
        let flutter = sin(phase) * 3
        var fin = Path()
        fin.move(to: CGPoint(x: -11, y: -6))
        fin.addQuadCurve(to: CGPoint(x: -11, y: 12), control: CGPoint(x: -24 - flutter, y: 3))
        fin.closeSubpath()
        h.fill(fin, with: .color(c.fin.color(c.finAlpha)))
        var rays = Path()
        for k in 0..<4 {
            let y = -4 + CGFloat(k) * 5
            rays.move(to: CGPoint(x: -11, y: y))
            rays.addLine(to: CGPoint(x: -19 - flutter * 0.8, y: y + 1))
        }
        h.stroke(rays, with: .color(c.fin.shade(-0.3).color(0.4)), lineWidth: 0.7)
        // body
        let pts: [CGPoint] = [
            CGPoint(x: -2, y: -36), CGPoint(x: -9, y: -31), CGPoint(x: -9, y: -20), CGPoint(x: -12, y: -6),
            CGPoint(x: -11, y: 8), CGPoint(x: -6, y: 18), CGPoint(x: -1, y: 22), CGPoint(x: 6, y: 16),
            CGPoint(x: 11, y: 4), CGPoint(x: 11, y: -8), CGPoint(x: 6, y: -18), CGPoint(x: 7, y: -24),
            CGPoint(x: 6, y: -32),
        ]
        let body = AquaShape.smoothClosed(pts)
        h.fill(body, with: .linearGradient(Gradient(colors: [c.body.shade(-0.1).color, c.body.color, c.belly.color]),
                                           startPoint: CGPoint(x: -12, y: 0), endPoint: CGPoint(x: 12, y: 0)))
        // snout
        let snout = Path(roundedRect: CGRect(x: 3, y: -30.5, width: 20, height: 6), cornerRadius: 3)
        h.fill(snout, with: .color(c.body.color))
        h.stroke(snout, with: .color(c.body.shade(-0.4).color(0.6)), lineWidth: 1)
        if gulp > 0.1 { h.fill(AquaShape.circle(CGPoint(x: 23, y: -27.5), 2 * gulp), with: .color(ARGB(0x8A3A5A).color(0.8))) }
        // belly rings
        var rings = Path()
        for k in 0..<6 {
            let y = -12 + CGFloat(k) * 5.5
            rings.move(to: CGPoint(x: -9, y: y))
            rings.addQuadCurve(to: CGPoint(x: 10 - CGFloat(k) * 1.2, y: y + 1), control: CGPoint(x: 1, y: y + 3))
        }
        h.stroke(rings, with: .color(c.body.shade(-0.3).color(0.4)), lineWidth: 1)
        // crown bumps
        var crown = Path()
        for k in 0..<3 {
            crown.addEllipse(in: CGRect(x: -5 + CGFloat(k) * 3.5, y: -40 + CGFloat(k), width: 3.5, height: 4))
        }
        h.fill(crown, with: .color(c.body.shade(-0.1).color))
        h.stroke(body, with: .color(c.body.shade(-0.45).color(0.7)), lineWidth: 1.2)
        var sheen = Path()
        sheen.move(to: CGPoint(x: 6, y: -10))
        sheen.addQuadCurve(to: CGPoint(x: 6, y: 10), control: CGPoint(x: 10, y: 0))
        h.stroke(sheen, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        // eye
        let e = CGPoint(x: 1, y: -27)
        h.fill(AquaShape.circle(e, 4.2), with: .color(.white))
        h.fill(AquaShape.circle(CGPoint(x: e.x + 0.8, y: e.y), 2.6), with: .color(aqInk.color))
        h.fill(AquaShape.circle(CGPoint(x: e.x + 1.8, y: e.y - 1.2), 1), with: .color(.white))
    }
}
