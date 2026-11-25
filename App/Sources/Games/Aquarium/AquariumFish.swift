import SwiftUI

// MARK: - Fish, drawn
//
// Every fish is drawn facing right around the middle of its body, nose at +length/2. The body outline is sampled along
// its length and bends with the tail beat (the rear swings most, the head a little the other way), so a swimming fish
// flexes instead of sliding. Bands and stripes follow the same outline, so they bend with it. Outlines are a deeper
// shade of the fish's own color, never black, like the other games.

private let aqInk = ARGB(0x2A2238)

struct AquaBody {
    private struct ProfileKey: Hashable {
        let aMilli: Int
        let bMilli: Int

        init(_ a: CGFloat, _ b: CGFloat) {
            aMilli = Int((a * 1000).rounded())
            bMilli = Int((b * 1000).rounded())
        }
    }

    private struct Profile {
        let peak: CGFloat
        let shapes: [CGFloat]
    }

    private static let sampleCount = 14

    /// Precomputed normalized body-profile tables for every fish species so 60 FPS draws run zero `pow()` calls.
    private static let cachedProfiles: [ProfileKey: Profile] = {
        let pairs: [(CGFloat, CGFloat)] = [
            (0.8, 0.55),
            (0.85, 0.5),
            (0.9, 0.6),
            (1.05, 0.95),
            (0.8, 0.5),
            (0.9, 0.55),
            (0.75, 0.6),
            (0.65, 0.7),
            (0.78, 0.58),
        ]
        var map: [ProfileKey: Profile] = [:]
        for (a, b) in pairs {
            map[ProfileKey(a, b)] = buildProfile(a: a, b: b)
        }
        return map
    }()

    private static let unitBall: [CGFloat] = {
        (0...sampleCount).map { k in
            let uu = CGFloat(k) / CGFloat(sampleCount)
            let d = 2 * uu - 1
            return sqrt(max(0, 1 - d * d))
        }
    }()

    private static func buildProfile(a: CGFloat, b: CGFloat) -> Profile {
        let uPeak = a / max(0.0001, a + b)
        let peak = max(0.0001, pow(uPeak, a) * pow(1 - uPeak, b))
        var shapes: [CGFloat] = []
        shapes.reserveCapacity(sampleCount + 1)
        for k in 0...sampleCount {
            let uu = CGFloat(k) / CGFloat(sampleCount)
            shapes.append(0.2 * (1 - uu) + 0.8 * pow(uu, a) * pow(1 - uu, b) / peak)
        }
        return Profile(peak: peak, shapes: shapes)
    }

    static func hasCachedProfile(a: CGFloat, b: CGFloat) -> Bool {
        cachedProfiles[ProfileKey(a, b)] != nil
    }

    let L: CGFloat
    let H: CGFloat
    /// Profile exponents: how quickly it fills out behind the head (a) and rounds off at the nose (b).
    let a: CGFloat
    let b: CGFloat
    let bend: CGFloat
    let belly: CGFloat
    /// 0 ... 1: blends the outline toward a ball (the puffer).
    let round: CGFloat
    let peak: CGFloat
    let outlinePath: Path

    private let halfSamples: [CGFloat]

    init(
        L: CGFloat,
        H: CGFloat,
        a: CGFloat = 0.8,
        b: CGFloat = 0.55,
        bend: CGFloat = 0,
        belly: CGFloat = 0.94,
        round: CGFloat = 0
    ) {
        self.L = L
        self.H = H
        self.a = a
        self.b = b
        self.bend = bend
        self.belly = belly
        self.round = round

        let profile = Self.cachedProfiles[ProfileKey(a, b)] ?? Self.buildProfile(a: a, b: b)
        self.peak = profile.peak

        let n = Self.sampleCount
        let halfH = H * 0.5
        let halfL = L * 0.5
        var samples: [CGFloat] = []
        samples.reserveCapacity(n + 1)
        if round > 0 {
            for k in 0...n {
                let normal = halfH * profile.shapes[k]
                let ball = Self.unitBall[k] * halfL
                samples.append(normal + (ball - normal) * round)
            }
        } else {
            for k in 0...n {
                samples.append(halfH * profile.shapes[k])
            }
        }
        self.halfSamples = samples

        var pts: [CGPoint] = []
        pts.reserveCapacity(n * 2 + 1)
        let invN = 1 / CGFloat(n)
        for k in 0...n {
            let u = CGFloat(k) * invN
            let px = -halfL + u * L
            let w = 1 - u
            let py = bend * L * (0.22 * w * w - 0.035)
            pts.append(CGPoint(x: px, y: py - samples[k]))
        }
        for k in stride(from: n - 1, through: 1, by: -1) {
            let u = CGFloat(k) * invN
            let px = -halfL + u * L
            let w = 1 - u
            let py = bend * L * (0.22 * w * w - 0.035)
            pts.append(CGPoint(x: px, y: py + samples[k] * belly))
        }
        let cy0 = bend * L * (0.22 - 0.035)
        pts.append(CGPoint(x: -halfL, y: cy0 + samples[0] * belly))
        self.outlinePath = AquaShape.smoothClosed(pts)
    }

    var outline: Path { outlinePath }

    func x(_ u: CGFloat) -> CGFloat { -L / 2 + u * L }

    func half(_ u: CGFloat) -> CGFloat {
        let uu = max(0, min(1, u))
        let scaled = uu * CGFloat(Self.sampleCount)
        let i0 = min(Self.sampleCount, Int(scaled))
        let i1 = min(Self.sampleCount, i0 + 1)
        let frac = scaled - CGFloat(i0)
        return halfSamples[i0] + (halfSamples[i1] - halfSamples[i0]) * frac
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
        case .axolotl:
            switch v {
            case 1: return FishColors(body: ARGB(0xFFB899), belly: ARGB(0xFFE7D8), fin: ARGB(0xFF7961), finEdge: ARGB(0xFFD6C4), finAlpha: 0.88)
            case 2: return FishColors(body: ARGB(0xCDB8FF), belly: ARGB(0xF0E8FF), fin: ARGB(0x88E2C8), finEdge: ARGB(0xD8FFF2), finAlpha: 0.88)
            default: return FishColors(body: ARGB(0xFFA6CA), belly: ARGB(0xFFE0EE), fin: ARGB(0xFF5D96), finEdge: ARGB(0xFFC2DC), finAlpha: 0.9)
            }
        case .seaBunny:
            switch v {
            case 1: return FishColors(body: ARGB(0xFFF2C8), belly: ARGB(0xFFFBF0), fin: ARGB(0x6D4838), finEdge: ARGB(0xFFF4D4), finAlpha: 0.95)
            case 2: return FishColors(body: ARGB(0xE6FFF4), belly: ARGB(0xFFFFFF), fin: ARGB(0x3F5E5B), finEdge: ARGB(0xD2F7E9), finAlpha: 0.95)
            default: return FishColors(body: ARGB(0xFFFBF5), belly: ARGB(0xFFFFFF), fin: ARGB(0x3D2E48), finEdge: ARGB(0xF7ECF5), finAlpha: 0.95)
            }
        case .narwhal:
            switch v {
            case 1: return FishColors(body: ARGB(0xC5A8FF), belly: ARGB(0xF3EBFF), fin: ARGB(0xAE88F5), finEdge: ARGB(0xFFE28A), finAlpha: 0.92)
            case 2: return FishColors(body: ARGB(0x7FE3D6), belly: ARGB(0xE6FFFA), fin: ARGB(0x5ECBC0), finEdge: ARGB(0xFFE28A), finAlpha: 0.92)
            default: return FishColors(body: ARGB(0x90CCFF), belly: ARGB(0xE8F6FF), fin: ARGB(0x6EB4F5), finEdge: ARGB(0xFFE28A), finAlpha: 0.92)
            }
        }
    }

    /// Draws a fish where it is in the tank.
    static func draw(_ ctx: GraphicsContext, _ f: AquaFish, time: CGFloat, pitch: CGFloat) {
        var g = ctx
        let side: CGFloat = f.facing < 0 ? -1 : 1
        let flipAge = CGFloat(Double(time) - f.flipStart)
        let flipDur: CGFloat = 0.85
        let flipU: CGFloat = flipAge >= 0 && flipAge < flipDur ? flipAge / flipDur : 0
        let flipSpin: CGFloat = flipU > 0 ? side * aqEase(flipU) * 2 * .pi : 0
        let flipPop: CGFloat = flipU > 0 ? 1 + 0.16 * sin(flipU * .pi) : 1
        let flipArcY: CGFloat = flipU > 0 ? -16 * sin(flipU * .pi) : 0

        g.translateBy(x: f.p.x, y: f.p.y + flipArcY)
        var sx = f.facing
        if abs(sx) < 0.14 { sx = 0.14 * side }
        let since = CGFloat(Double(time) - f.happy)
        let wiggle = since >= 0 && since < 0.9 ? sin(since * 26) * 0.18 * (1 - since / 0.9) : 0
        g.rotate(by: .radians(Double(pitch * side + wiggle + flipSpin)))
        let s = f.scale * flipPop
        g.scaleBy(x: sx * s, y: s)
        let sleeping: Bool
        if case .sleeping = f.activity {
            sleeping = true
        } else {
            sleeping = false
        }
        drawLocal(
            g,
            kind: f.kind,
            variant: f.variant,
            phase: f.phase,
            amp: f.amp,
            gulp: f.gulp,
            puff: f.puff,
            time: time,
            turning: 1 - abs(sx),
            baby: f.growthStage == 0,
            sleeping: sleeping
        )

        if Double(time) < f.stardustUntil {
            let remain = aqClamp(CGFloat((f.stardustUntil - Double(time)) / 1.2))
            let rad = max(f.kind.length, f.kind.height) * 0.55 * s
            for k in 0..<3 {
                let a = time * 2.8 + CGFloat(k) * 2.1 + CGFloat(f.id)
                let pt = CGPoint(x: f.p.x + cos(a) * rad, y: f.p.y + flipArcY + sin(a * 1.2) * rad * 0.65)
                let sp = (4.5 + 2.5 * sin(time * 7 + CGFloat(k))) * remain
                StorybookArt.sparkle(ctx, at: pt, radius: sp, color: k == 1 ? .white : Theme.lemon, opacity: Double(0.9 * remain))
            }
        } else if f.grewUp && f.growthStage >= 2 {
            let rad = max(f.kind.length, f.kind.height) * 0.48 * s
            let a = time * 1.4 + CGFloat(f.id) * 1.7
            let pt = CGPoint(x: f.p.x + cos(a) * rad, y: f.p.y - rad * 0.45 + sin(a) * 6)
            StorybookArt.sparkle(ctx, at: pt, radius: 4 + 1.5 * sin(time * 4 + CGFloat(f.id)), color: Theme.lemon, opacity: 0.72)
        }
    }

    /// Playful upright snack crumb bubble floating above a fish that is ready for flakes.
    static func drawCrumbBubble(_ ctx: GraphicsContext, for f: AquaFish, time: CGFloat) {
        let cue = aqEase(f.hungryCue)
        guard cue > 0.04 else { return }
        let bob = sin(time * 3.2 + CGFloat(f.id)) * 3
        let side: CGFloat = f.facing < 0 ? -1 : 1
        let cx = max(AGeo.left + 34, min(AGeo.right - 34, f.p.x + side * (f.kind.length * 0.24 * f.scale + 12)))
        let cy = max(AGeo.waterY + 28, f.p.y - f.kind.height * 0.55 * f.scale - 28 + bob)
        let sc = 0.62 * (0.72 + 0.28 * cue)
        let tailOffset = CGPoint(
            x: (f.p.x + side * f.kind.length * 0.3 * f.scale - cx) / max(0.01, sc),
            y: (f.p.y - f.kind.height * 0.15 * f.scale - cy) / max(0.01, sc)
        )

        var g = ctx
        g.opacity = Double(cue)
        g.translateBy(x: cx, y: cy)
        g.scaleBy(x: sc, y: sc)
        StorybookArt.thoughtBubble(g, center: .zero, radius: 28, tailToward: tailOffset)

        let flakes: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (-9, -4, -0.35, 0xFF7B54),
            (8, -6, 0.42, 0xFFC94A),
            (0, 8, -0.15, 0x6BCB7A),
        ]
        for (dx, dy, rot, hex) in flakes {
            var fc = g
            fc.translateBy(x: dx, y: dy)
            fc.rotate(by: .radians(Double(rot)))
            let p = Path(roundedRect: CGRect(x: -7, y: -4.2, width: 14, height: 8.4), cornerRadius: 3.5)
            StorybookArt.shape(fc, p, hex: hex, width: 2.0)
        }
    }

    /// The fish in its own space, facing right. `turning` (0 ... 1) dims the far fins while it turns.
    static func drawLocal(
        _ g: GraphicsContext,
        kind: FishKind,
        variant: Int,
        phase: CGFloat,
        amp: CGFloat,
        gulp: CGFloat,
        puff: CGFloat,
        time: CGFloat,
        turning: CGFloat = 0,
        baby: Bool = false,
        sleeping: Bool = false
    ) {
        let c = colors(kind, variant)
        switch kind {
        case .goldfish: goldfish(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .clownfish: clownfish(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .angelfish: angelfish(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .tetra: tetra(g, c, phase, amp, gulp, baby: baby, sleeping: sleeping)
        case .puffer: puffer(g, c, phase, amp, gulp, puff, time, baby: baby, sleeping: sleeping)
        case .betta: betta(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .guppy: guppy(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .seahorse: seahorse(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .axolotl: axolotl(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .seaBunny: seaBunny(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        case .narwhal: narwhal(g, c, phase, amp, gulp, time, baby: baby, sleeping: sleeping)
        }
    }

    // MARK: Shared parts

    private static func fillFin(_ g: GraphicsContext, _ p: Path, _ c: FishColors, rays: Path? = nil) {
        g.fill(p, with: .color(c.fin.color(c.finAlpha)))
        if let r = rays { g.stroke(r, with: .color(c.fin.shade(-0.3).color(0.35)), lineWidth: 0.8) }
        g.stroke(p, with: .color(c.fin.shade(-0.35).color(0.55)), lineWidth: 1)
    }

    private static func fillBody(_ g: GraphicsContext, _ b: AquaBody, _ c: FishColors) {
        g.fill(b.outlinePath, with: .linearGradient(Gradient(colors: [c.body.shade(-0.14).color, c.body.color, c.belly.color]),
                                                    startPoint: CGPoint(x: 0, y: -b.H / 2), endPoint: CGPoint(x: 0, y: b.H / 2)))
    }

    private static func outlineBody(_ g: GraphicsContext, _ b: AquaBody, _ c: FishColors) {
        g.stroke(b.outlinePath, with: .color(c.body.shade(-0.45).color(0.7)), lineWidth: 1.2)
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

    private static func eye(
        _ g: GraphicsContext,
        _ b: AquaBody,
        at u: CGFloat = 0.84,
        f: CGFloat = -0.22,
        size: CGFloat? = nil,
        iris: ARGB? = nil,
        baby: Bool = false,
        sleeping: Bool = false
    ) {
        let c = b.at(u, f)
        let baseR = size ?? max(2.4, b.H * 0.12)
        let r = baby ? baseR * 1.38 : baseR
        if sleeping {
            var lid = Path()
            lid.move(to: CGPoint(x: c.x - r * 0.78, y: c.y - r * 0.05))
            lid.addQuadCurve(to: CGPoint(x: c.x + r * 0.78, y: c.y - r * 0.05), control: CGPoint(x: c.x, y: c.y + r * 0.72))
            g.stroke(lid, with: .color(aqInk.color(0.84)), style: StrokeStyle(lineWidth: max(1.4, r * 0.34), lineCap: .round))
            if baby {
                let blush = CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.95)
                g.fill(Path(ellipseIn: CGRect(x: blush.x - r * 0.6, y: blush.y - r * 0.3, width: r * 1.2, height: r * 0.6)),
                       with: .color(ARGB(0xFF8DB8).color(0.45)))
            }
            return
        }
        g.fill(AquaShape.circle(c, r), with: .color(.white))
        if let ir = iris { g.fill(AquaShape.circle(CGPoint(x: c.x + r * 0.12, y: c.y), r * 0.78), with: .color(ir.color)) }
        g.fill(AquaShape.circle(CGPoint(x: c.x + r * 0.16, y: c.y + r * 0.02), r * (baby ? 0.68 : 0.58)), with: .color(aqInk.color))
        g.fill(AquaShape.circle(CGPoint(x: c.x + r * 0.34, y: c.y - r * 0.3), r * (baby ? 0.3 : 0.22)), with: .color(.white))
        if baby {
            g.fill(AquaShape.circle(CGPoint(x: c.x - r * 0.18, y: c.y + r * 0.26), r * 0.16), with: .color(.white.opacity(0.9)))
            let blush = CGPoint(x: c.x - r * 0.3, y: c.y + r * 1.05)
            g.fill(Path(ellipseIn: CGRect(x: blush.x - r * 0.65, y: blush.y - r * 0.34, width: r * 1.3, height: r * 0.68)),
                   with: .color(ARGB(0xFF8DB8).color(0.5)))
        }
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

    private static func goldfish(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 70, H: 46, a: 0.85, b: 0.5, bend: sin(phase) * amp * 0.5)
        let tg = tailContext(g, b, phase: phase, amp: amp)
        let tp = flowing(48, 34, phase: phase, waves: 3)
        fillFin(tg, tp, c, rays: tailRays(48, 34, count: 7))
        fillFin(g, b.fin(0.1, 0.28, height: 16, sweep: 10, belly: true, ripple: sin(phase * 0.8) * 0.12), c)
        fillFin(g, b.fin(0.25, 0.62, height: 20, sweep: 16, belly: false, ripple: sin(phase * 0.6 + 1) * 0.1), c)
        fillFin(g, b.fin(0.52, 0.62, height: 13, sweep: 8, belly: true, ripple: sin(phase) * 0.15), c)
        fillBody(g, b, c)
        if c.body == ARGB(0xFFF4EA) {
            g.fill(b.strip(0.1, 0.9, -1.05, -0.15), with: .color(ARGB(0xF0523A).color(0.92)))
            g.fill(b.band(0.8, 1.0), with: .color(ARGB(0xF0523A).color(0.85)))
        }
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
        eye(g, b, size: 6, iris: ARGB(0xFFD86B), baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: gulp)
    }

    private static func clownfish(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 60, H: 32, a: 0.9, b: 0.6, bend: sin(phase) * amp * 0.55)
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
        for (u0, u1) in [(0.7, 0.8), (0.38, 0.5), (0.03, 0.1)] as [(CGFloat, CGFloat)] {
            let band = b.band(u0, u1)
            g.fill(band, with: .color(.white))
            g.stroke(band, with: .color(c.finEdge.color(0.8)), lineWidth: 1.4)
        }
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase, len: 11, at: 0.6)
        eye(g, b, at: 0.86, size: 4.4, iris: ARGB(0xFFB15C), baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: gulp)
    }

    private static func angelfish(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 52, H: 58, a: 1.05, b: 0.95, bend: sin(phase) * amp * 0.35)
        let tg = tailContext(g, b, phase: phase, amp: amp * 0.7)
        let tp = tail(28, 20, notch: 0.45, round: false, ripple: 1.2, phase: phase)
        fillFin(tg, tp, c, rays: tailRays(28, 20, count: 6))
        let wave = sin(phase * 0.5) * 0.06
        fillFin(g, b.fin(0.18, 0.6, height: 44, sweep: 30, belly: false, ripple: wave), c, rays: nil)
        fillFin(g, b.fin(0.18, 0.6, height: 42, sweep: 30, belly: true, ripple: -wave), c, rays: nil)
        var streamers = Path()
        let s0 = b.at(0.62, 0.95)
        streamers.move(to: s0)
        streamers.addQuadCurve(to: CGPoint(x: s0.x - 22, y: s0.y + 40 + sin(phase * 0.8) * 4), control: CGPoint(x: s0.x + 2, y: s0.y + 24))
        g.stroke(streamers, with: .color(c.fin.shade(-0.2).color(0.8)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        fillBody(g, b, c)
        g.fill(b.strip(0.55, 1, -1.02, -0.2), with: .color(ARGB(0xF6D978).color(0.5)))
        for (u0, u1) in [(0.2, 0.3), (0.5, 0.6), (0.8, 0.86)] as [(CGFloat, CGFloat)] {
            g.fill(b.band(u0, u1), with: .color(ARGB(0x4C465C).color(0.72)))
        }
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase, len: 10, at: 0.64)
        eye(g, b, at: 0.83, f: -0.18, size: 4.6, iris: ARGB(0xE0503C), baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: gulp)
    }

    private static func tetra(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 30, H: 12, a: 0.8, b: 0.5, bend: sin(phase) * amp * 0.6)
        let tg = tailContext(g, b, phase: phase, amp: amp)
        fillFin(tg, tail(11, 7, notch: 0.5, round: false, ripple: 0.4, phase: phase), c)
        fillFin(g, b.fin(0.42, 0.55, height: 5, sweep: 3, belly: false), c)
        fillFin(g, b.fin(0.15, 0.35, height: 4, sweep: 2, belly: true), c)
        fillBody(g, b, c)
        neon(g, b)
        g.stroke(b.outlinePath, with: .color(c.body.shade(-0.4).color(0.5)), lineWidth: 0.7)
        eye(g, b, at: 0.86, f: -0.15, size: 2.6, iris: ARGB(0x7FC8FF), baby: baby, sleeping: sleeping)
    }

    /// The neon tetra's stripes (drawn again glowing at night).
    static func neon(_ g: GraphicsContext, _ b: AquaBody) {
        g.fill(b.strip(0.0, 0.5, 0.1, 0.92), with: .color(ARGB(0xFF3B5C).color(0.95)))
        g.fill(b.strip(0.12, 0.92, -0.5, -0.02), with: .linearGradient(Gradient(colors: [ARGB(0x2FD7FF).color, ARGB(0x3E8BFF).color]),
                                                                          startPoint: CGPoint(x: b.x(0.1), y: 0), endPoint: CGPoint(x: b.x(0.92), y: 0)))
    }

    static func tetraBody(phase: CGFloat, amp: CGFloat) -> AquaBody {
        AquaBody(L: 30, H: 12, a: 0.8, b: 0.5, bend: sin(phase) * amp * 0.6)
    }

    private static func puffer(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ puff: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let p = max(0, min(1.1, puff))
        let b = AquaBody(L: 52 * (1 + 0.18 * p), H: 42, a: 0.9, b: 0.55, bend: sin(phase) * amp * 0.3 * (1 - p), round: min(1, p))
        let tg = tailContext(g, b, phase: phase * 1.4, amp: amp)
        fillFin(tg, tail(14, 10, notch: 0, round: true, ripple: 1, phase: phase), c)
        fillFin(g, b.fin(0.2, 0.36, height: 8, sweep: 4, belly: false, ripple: sin(phase * 2) * 0.3), c)
        fillFin(g, b.fin(0.18, 0.32, height: 7, sweep: 4, belly: true, ripple: sin(phase * 2 + 1) * 0.3), c)
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
        eye(g, b, at: 0.8, f: -0.32, size: 7, iris: ARGB(0x5ED1B8), baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: max(gulp, p * 0.6))
    }

    private static func betta(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 50, H: 22, a: 0.8, b: 0.55, bend: sin(phase) * amp * 0.4)
        let grad = Gradient(colors: [c.fin.color(0.9), c.finEdge.color(0.65)])
        let tg = tailContext(g, b, phase: phase * 0.6, amp: amp * 0.6)
        let tp = flowing(52, 40, phase: t * 1.6, waves: 4, droop: 0.4)
        tg.fill(tp, with: .radialGradient(grad, center: .zero, startRadius: 4, endRadius: 52))
        tg.stroke(tailRays(52, 40, count: 9), with: .color(c.fin.shade(-0.3).color(0.25)), lineWidth: 0.8)
        let w = sin(t * 1.6) * 0.08
        let dorsal = b.fin(0.15, 0.55, height: 22, sweep: 24, belly: false, ripple: w)
        let anal = b.fin(0.0, 0.6, height: 30, sweep: 26, belly: true, ripple: -w)
        for p in [anal, dorsal] {
            g.fill(p, with: .linearGradient(grad, startPoint: b.at(0.4, 0), endPoint: CGPoint(x: b.x(0) - 20, y: 30)))
            g.stroke(p, with: .color(c.fin.shade(-0.3).color(0.4)), lineWidth: 0.8)
        }
        fillBody(g, b, c)
        g.fill(b.strip(0.2, 0.8, -0.6, 0.1), with: .color(ARGB(0x9EE8FF).color(0.18)))
        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase * 1.4, len: 9, at: 0.66)
        eye(g, b, at: 0.85, size: 3.8, iris: ARGB(0xFFB15C), baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: gulp)
    }

    private static func guppy(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 32, H: 13, a: 0.8, b: 0.5, bend: sin(phase) * amp * 0.6)
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
        g.stroke(b.outlinePath, with: .color(c.body.shade(-0.4).color(0.55)), lineWidth: 0.8)
        eye(g, b, at: 0.85, f: -0.15, size: 2.8, baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: gulp)
    }

    /// Upright, snout to the right, curled tail below; the little back fin flutters fast.
    private static func seahorse(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let bob = sin(t * 1.4 + phase * 0.05) * 1.2
        var h = g
        h.translateBy(x: 0, y: bob)
        var tailPath = Path()
        tailPath.move(to: CGPoint(x: -4, y: 18))
        tailPath.addCurve(to: CGPoint(x: 2, y: 40), control1: CGPoint(x: -8, y: 28), control2: CGPoint(x: -6, y: 38))
        tailPath.addCurve(to: CGPoint(x: 9, y: 33), control1: CGPoint(x: 7, y: 43), control2: CGPoint(x: 11, y: 38))
        tailPath.addQuadCurve(to: CGPoint(x: 4, y: 31), control: CGPoint(x: 7, y: 29))
        h.stroke(tailPath, with: .color(c.body.shade(-0.35).color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        h.stroke(tailPath, with: .color(c.body.color), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
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
        let pts: [CGPoint] = [
            CGPoint(x: -2, y: -36), CGPoint(x: -9, y: -31), CGPoint(x: -9, y: -20), CGPoint(x: -12, y: -6),
            CGPoint(x: -11, y: 8), CGPoint(x: -6, y: 18), CGPoint(x: -1, y: 22), CGPoint(x: 6, y: 16),
            CGPoint(x: 11, y: 4), CGPoint(x: 11, y: -8), CGPoint(x: 6, y: -18), CGPoint(x: 7, y: -24),
            CGPoint(x: 6, y: -32),
        ]
        let body = AquaShape.smoothClosed(pts)
        h.fill(body, with: .linearGradient(Gradient(colors: [c.body.shade(-0.1).color, c.body.color, c.belly.color]),
                                           startPoint: CGPoint(x: -12, y: 0), endPoint: CGPoint(x: 12, y: 0)))
        let snout = Path(roundedRect: CGRect(x: 3, y: -30.5, width: 20, height: 6), cornerRadius: 3)
        h.fill(snout, with: .color(c.body.color))
        h.stroke(snout, with: .color(c.body.shade(-0.4).color(0.6)), lineWidth: 1)
        if gulp > 0.1 { h.fill(AquaShape.circle(CGPoint(x: 23, y: -27.5), 2 * gulp), with: .color(ARGB(0x8A3A5A).color(0.8))) }
        var rings = Path()
        for k in 0..<6 {
            let y = -12 + CGFloat(k) * 5.5
            rings.move(to: CGPoint(x: -9, y: y))
            rings.addQuadCurve(to: CGPoint(x: 10 - CGFloat(k) * 1.2, y: y + 1), control: CGPoint(x: 1, y: y + 3))
        }
        h.stroke(rings, with: .color(c.body.shade(-0.3).color(0.4)), lineWidth: 1)
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
        let e = CGPoint(x: 1, y: -27)
        let er: CGFloat = baby ? 5.6 : 4.2
        if sleeping {
            var lid = Path()
            lid.move(to: CGPoint(x: e.x - er * 0.72, y: e.y))
            lid.addQuadCurve(to: CGPoint(x: e.x + er * 0.72, y: e.y), control: CGPoint(x: e.x, y: e.y + er * 0.65))
            h.stroke(lid, with: .color(aqInk.color(0.84)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        } else {
            h.fill(AquaShape.circle(e, er), with: .color(.white))
            h.fill(AquaShape.circle(CGPoint(x: e.x + 0.8, y: e.y), er * 0.65), with: .color(aqInk.color))
            h.fill(AquaShape.circle(CGPoint(x: e.x + er * 0.38, y: e.y - er * 0.28), er * 0.26), with: .color(.white))
        }
    }

    // MARK: Hatchable Reef Baby Species

    /// Smiling pastel axolotl with frilly swaying pink gill branches and long translucent tail fin.
    private static func axolotl(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 62, H: 28, a: 0.75, b: 0.6, bend: sin(phase) * amp * 0.55)

        // Long salamander tail with translucent ribbon crest
        let tg = tailContext(g, b, phase: phase, amp: amp)
        var crest = Path()
        let wave = sin(phase * 1.4) * 4
        crest.move(to: CGPoint(x: 10, y: -8))
        crest.addQuadCurve(to: CGPoint(x: -36, y: wave), control: CGPoint(x: -16, y: -18 + wave * 0.5))
        crest.addQuadCurve(to: CGPoint(x: 10, y: 8), control: CGPoint(x: -16, y: 16 + wave * 0.5))
        crest.closeSubpath()
        tg.fill(crest, with: .color(c.finEdge.color(0.75)))
        tg.stroke(crest, with: .color(c.fin.shade(-0.2).color(0.65)), lineWidth: 1.2)

        var tailCore = Path()
        tailCore.move(to: CGPoint(x: 4, y: -4.5))
        tailCore.addQuadCurve(to: CGPoint(x: -30, y: wave), control: CGPoint(x: -14, y: -5 + wave * 0.4))
        tailCore.addQuadCurve(to: CGPoint(x: 4, y: 4.5), control: CGPoint(x: -14, y: 5 + wave * 0.4))
        tailCore.closeSubpath()
        tg.fill(tailCore, with: .color(c.body.color))

        // Tiny paddling legs underneath
        for (u, lag) in [(0.24, 0.0), (0.64, 2.2)] as [(CGFloat, CGFloat)] {
            let hip = b.at(u, 0.82)
            let kick = sin(phase * 1.2 + lag) * 3.5
            var leg = Path()
            leg.move(to: hip)
            leg.addQuadCurve(to: CGPoint(x: hip.x - 4 + kick, y: hip.y + 9), control: CGPoint(x: hip.x - 1, y: hip.y + 6))
            g.stroke(leg, with: .color(c.body.shade(-0.3).color), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
            g.stroke(leg, with: .color(c.body.color), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        }

        // Far-side peeking frilly gill stalks behind head
        let gillRoot = b.at(0.70, -0.58)
        for k in 0..<3 {
            let ang = -2.25 + CGFloat(k) * 0.45 + sin(t * 3 + CGFloat(k)) * 0.09
            let len: CGFloat = 14 + CGFloat(k == 1 ? 2 : 0)
            let tip = CGPoint(x: gillRoot.x + cos(ang) * len, y: gillRoot.y + sin(ang) * len)
            var stalk = Path()
            stalk.move(to: gillRoot)
            stalk.addQuadCurve(to: tip, control: CGPoint(x: (gillRoot.x + tip.x) * 0.5 - 2, y: (gillRoot.y + tip.y) * 0.5 - 3))
            g.stroke(stalk, with: .color(c.fin.shade(-0.15).color(0.95)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            g.stroke(stalk, with: .color(c.fin.color(0.95)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }

        fillBody(g, b, c)
        outlineBody(g, b, c)

        // Foreground fluffy feathered frilly gills (signature axolotl look!)
        let frontRoot = b.at(0.68, -0.15)
        for k in 0..<3 {
            let ang = -2.4 + CGFloat(k) * 0.46 + sin(t * 3.2 + CGFloat(k) * 1.1) * 0.1
            let len: CGFloat = 15 + CGFloat(k == 1 ? 2.5 : 0)
            let tip = CGPoint(x: frontRoot.x + cos(ang) * len, y: frontRoot.y + sin(ang) * len)
            var branch = Path()
            branch.move(to: frontRoot)
            branch.addQuadCurve(to: tip, control: CGPoint(x: (frontRoot.x + tip.x) * 0.5 - 2, y: (frontRoot.y + tip.y) * 0.5 - 2))
            g.stroke(branch, with: .color(c.fin.shade(-0.25).color), style: StrokeStyle(lineWidth: 4.6, lineCap: .round))
            g.stroke(branch, with: .color(c.fin.color), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
            for f in [0.45, 0.72, 0.95] as [CGFloat] {
                let fx = frontRoot.x + (tip.x - frontRoot.x) * f
                let fy = frontRoot.y + (tip.y - frontRoot.y) * f
                g.fill(AquaShape.circle(CGPoint(x: fx, y: fy), 2.5), with: .color(c.fin.shade(0.15).color))
            }
        }

        // Cute wide axolotl smile & rosy cheek
        let cheek = b.at(0.84, 0.25)
        g.fill(Path(ellipseIn: CGRect(x: cheek.x - 4.5, y: cheek.y - 2.6, width: 9, height: 5.2)), with: .color(c.fin.color(0.45)))
        eye(g, b, at: 0.85, f: -0.22, size: 4.8, baby: baby, sleeping: sleeping)
        let n = b.at(0.97, 0.14)
        if gulp > 0.08 {
            mouth(g, b, c, gulp: gulp)
        } else {
            var smile = Path()
            smile.move(to: CGPoint(x: n.x - 10, y: n.y - 0.5))
            smile.addQuadCurve(to: CGPoint(x: n.x, y: n.y - 1.5), control: CGPoint(x: n.x - 4.5, y: n.y + 4.5))
            g.stroke(smile, with: .color(c.body.shade(-0.55).color(0.85)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    /// Fluffy white-and-polka-dot sea bunny slug with dark-tipped bunny ears and tiny flower tail tuft.
    private static func seaBunny(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 44, H: 25, a: 0.65, b: 0.7, bend: sin(phase) * amp * 0.22, belly: 0.78)

        // Fluffy flower-tuft tail gill rosette at the rear
        let tailRoot = b.at(0.08, -0.35)
        for k in 0..<5 {
            let a = -CGFloat.pi * 0.75 + CGFloat(k) * 0.52 + sin(t * 3 + CGFloat(k)) * 0.08
            let pt = CGPoint(x: tailRoot.x + cos(a) * 6.5, y: tailRoot.y + sin(a) * 6.5)
            g.fill(AquaShape.circle(pt, 3.3), with: .color(c.fin.color(0.82)))
            g.fill(AquaShape.circle(pt, 1.8), with: .color(c.body.color))
        }

        // Two bouncy bunny-ear rhinophores on the head
        let earSway = sin(phase * 0.9 + t * 2) * 1.8
        for (idx, u) in ([0.76, 0.85] as [CGFloat]).enumerated() {
            let base = b.at(u, -0.78)
            let tip = CGPoint(x: base.x - (idx == 0 ? 5 : 1) + earSway, y: base.y - 13.5)
            var ear = Path()
            ear.move(to: CGPoint(x: base.x - 2.6, y: base.y + 1))
            ear.addQuadCurve(to: tip, control: CGPoint(x: base.x - 5.5, y: base.y - 8))
            ear.addQuadCurve(to: CGPoint(x: base.x + 2.6, y: base.y + 1), control: CGPoint(x: base.x + 2.5, y: base.y - 7))
            ear.closeSubpath()
            g.fill(ear, with: .color(c.body.color))
            g.stroke(ear, with: .color(c.fin.color(0.75)), lineWidth: 1.3)
            g.fill(AquaShape.circle(CGPoint(x: tip.x + 0.3, y: tip.y + 2.6), 2.8), with: .color(c.fin.color(0.95)))
        }

        fillBody(g, b, c)
        // Soft fluffy polka dots on the cozy plush body
        var spots = Path()
        let dotCoords: [(CGFloat, CGFloat, CGFloat)] = [
            (0.24, -0.32, 2.3), (0.38, -0.56, 2.0), (0.50, -0.18, 2.5),
            (0.62, -0.48, 1.9), (0.34, 0.14, 1.8), (0.56, 0.20, 2.1),
            (0.18, 0.04, 1.7),
        ]
        for (u, f, r) in dotCoords {
            let pt = b.at(u, f)
            spots.addEllipse(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2))
        }
        g.fill(spots, with: .color(c.fin.color(0.88)))
        outlineBody(g, b, c)

        // Rosy blush & shiny baby eye
        let blush = b.at(0.86, 0.25)
        g.fill(Path(ellipseIn: CGRect(x: blush.x - 3.6, y: blush.y - 2.1, width: 7.2, height: 4.2)), with: .color(ARGB(0xFF9AC0).color(0.55)))
        eye(g, b, at: 0.87, f: -0.14, size: 3.4, baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: gulp)
    }

    /// Pastel unicorn whale with a gleaming spiral golden horn and graceful flukes.
    private static func narwhal(_ g: GraphicsContext, _ c: FishColors, _ phase: CGFloat, _ amp: CGFloat, _ gulp: CGFloat, _ t: CGFloat, baby: Bool, sleeping: Bool) {
        let b = AquaBody(L: 70, H: 34, a: 0.78, b: 0.58, bend: sin(phase) * amp * 0.45)

        // Graceful sweeping whale tail flukes
        let tg = tailContext(g, b, phase: phase, amp: amp)
        let tp = tail(24, 18, notch: 0.42, round: false, ripple: 1.5, phase: phase)
        fillFin(tg, tp, c)

        fillBody(g, b, c)

        // Soft cream whale belly curve
        g.fill(b.strip(0.18, 0.94, 0.22, 1.0), with: .color(c.belly.color(0.85)))

        // Pastel dappled narwhal spots along the back
        var dapples = Path()
        for (u, f, r) in [(0.26, -0.48, 2.8), (0.40, -0.62, 2.2), (0.52, -0.45, 3.0), (0.64, -0.58, 2.0)] as [(CGFloat, CGFloat, CGFloat)] {
            let pt = b.at(u, f)
            dapples.addEllipse(in: CGRect(x: pt.x - r, y: pt.y - r * 0.8, width: r * 2, height: r * 1.6))
        }
        g.fill(dapples, with: .color(.white.opacity(0.42)))

        outlineBody(g, b, c)
        pectoral(g, b, c, phase: phase, len: 13, at: 0.58)

        // Gleaming spiral golden unicorn horn!
        let hornBase = b.at(0.95, -0.34)
        let hornLen: CGFloat = baby ? 20 : 26
        let hornTip = CGPoint(x: hornBase.x + hornLen, y: hornBase.y - 6.5)
        var horn = Path()
        horn.move(to: CGPoint(x: hornBase.x - 1, y: hornBase.y - 3.6))
        horn.addLine(to: hornTip)
        horn.addLine(to: CGPoint(x: hornBase.x - 1, y: hornBase.y + 3.2))
        horn.closeSubpath()
        g.fill(
            horn,
            with: .linearGradient(
                Gradient(colors: [ARGB(0xFFF6BE).color, ARGB(0xFFD152).color, ARGB(0xF5A82E).color]),
                startPoint: hornBase,
                endPoint: hornTip
            )
        )
        g.stroke(horn, with: .color(ARGB(0xB87A14).color(0.8)), lineWidth: 1.1)
        var spiral = Path()
        for k in 1...3 {
            let f = CGFloat(k) / 4
            let sx = hornBase.x + hornLen * f
            let sy = hornBase.y - 6.5 * f
            let halfH = 3.2 * (1 - f)
            spiral.move(to: CGPoint(x: sx - 1.5, y: sy - halfH))
            spiral.addLine(to: CGPoint(x: sx + 1.5, y: sy + halfH))
        }
        g.stroke(spiral, with: .color(ARGB(0xC98818).color(0.7)), lineWidth: 1.0)
        let glint = 3.2 + sin(t * 5) * 1.1
        StorybookArt.sparkle(g, at: hornTip, radius: glint, color: .white, opacity: 0.92)

        let blush = b.at(0.82, 0.22)
        g.fill(Path(ellipseIn: CGRect(x: blush.x - 4, y: blush.y - 2.2, width: 8, height: 4.4)), with: .color(ARGB(0xFF9AC4).color(0.5)))
        eye(g, b, at: 0.84, f: -0.15, size: 4.6, iris: ARGB(0x6BA6FF), baby: baby, sleeping: sleeping)
        mouth(g, b, c, gulp: gulp)
    }
}
