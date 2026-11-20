import SwiftUI

// MARK: - Plant painters
//
// Every plant is drawn from its growth (0...1), its sway angle and its pop (a springy scale when it reaches a new
// stage). Stems are quadratic curves that bend from the base, so the whole plant leans and the top moves most.
// Leaves are lit from the upper left: a darker base, a lighter tip, a midrib, a thin outline in a deeper green.
// Roots and carrots are drawn separately, under the soil, where the glass front of the bed shows them.

enum GardenPlants {
    static let leafGreen = GRGB(0x5DAE47)
    static let stemGreen = GRGB(0x4E9A3A)
    static let olive = GRGB(0x7DA83A)

    /// Tomato positions: x offset from the stem, height above the soil (at full height).
    static let tomatoSpots: [CGPoint] = [CGPoint(x: -28, y: 118), CGPoint(x: 24, y: 150), CGPoint(x: -20, y: 176), CGPoint(x: 28, y: 92)]
    static let berrySpots: [CGPoint] = [CGPoint(x: -36, y: 16), CGPoint(x: 32, y: 20), CGPoint(x: 4, y: 26)]

    static func stemHeight(_ p: Plant) -> CGFloat {
        let g = CGFloat(p.growth)
        let sprout = 12 * gdClamp(g / 0.12)
        let main = p.kind.height * gdEase((g - 0.08) / 0.72)
        return max(sprout, main)
    }

    // MARK: Geometry helpers

    static func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u * u * a.x + 2 * u * t * c.x + t * t * b.x
        let y = u * u * a.y + 2 * u * t * c.y + t * t * b.y
        return CGPoint(x: x, y: y)
    }

    struct Stem {
        var base: CGPoint
        var ctrl: CGPoint
        var top: CGPoint
        func at(_ t: CGFloat) -> CGPoint { GardenPlants.quad(base, ctrl, top, t) }
        /// Direction of the stem at t, as an angle (0 points right, -pi/2 points up).
        func angle(_ t: CGFloat) -> CGFloat {
            let a = at(max(0, t - 0.02))
            let b = at(min(1, t + 0.02))
            return atan2(b.y - a.y, b.x - a.x)
        }
    }

    static func stem(base: CGPoint, height: CGFloat, bend: CGFloat) -> Stem {
        let top = CGPoint(x: base.x + sin(bend) * height, y: base.y - cos(bend) * height)
        let ctrl = CGPoint(x: base.x + sin(bend * 0.3) * height * 0.5, y: base.y - height * 0.56)
        return Stem(base: base, ctrl: ctrl, top: top)
    }

    static func drawStem(_ ctx: GraphicsContext, _ s: Stem, width: CGFloat, color: GRGB = stemGreen) {
        var p = Path()
        p.move(to: s.base)
        p.addQuadCurve(to: s.top, control: s.ctrl)
        let round = StrokeStyle(lineWidth: width + 2.4, lineCap: .round, lineJoin: .round)
        ctx.stroke(p, with: .color(color.shade(-0.45).color), style: round)
        ctx.stroke(p, with: .color(color.color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        var hl = Path()
        hl.move(to: CGPoint(x: s.base.x - width * 0.22, y: s.base.y))
        hl.addQuadCurve(to: CGPoint(x: s.top.x - width * 0.22, y: s.top.y), control: CGPoint(x: s.ctrl.x - width * 0.22, y: s.ctrl.y))
        ctx.stroke(hl, with: .color(color.shade(0.35).color(0.7)), style: StrokeStyle(lineWidth: max(1, width * 0.28), lineCap: .round))
    }

    /// A pointed leaf from `p`, pointing along `angle`.
    static func leaf(_ ctx: GraphicsContext, at p: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat,
                     color: GRGB = leafGreen, curl: CGFloat = 0) {
        guard length > 1 else { return }
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(angle)))
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: length, y: curl), control: CGPoint(x: length * 0.42, y: -width))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.52, y: width * 0.9 + curl * 0.5))
        let grad = Gradient(colors: [color.shade(-0.28).color, color.shade(0.14).color])
        g.fill(path, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: length, y: -width * 0.3)))
        g.stroke(path, with: .color(color.shade(-0.5).color(0.85)), lineWidth: 1.1)
        var rib = Path()
        rib.move(to: CGPoint(x: 2, y: 0))
        rib.addQuadCurve(to: CGPoint(x: length * 0.86, y: curl * 0.8), control: CGPoint(x: length * 0.5, y: -width * 0.12))
        g.stroke(rib, with: .color(color.shade(-0.35).color(0.55)), lineWidth: 1)
        // A glint of light on the upper half, on leaves big enough to see it.
        guard length > 20 else { return }
        var shine = Path()
        shine.move(to: CGPoint(x: length * 0.2, y: -width * 0.25))
        shine.addQuadCurve(to: CGPoint(x: length * 0.62, y: -width * 0.32), control: CGPoint(x: length * 0.4, y: -width * 0.55))
        g.stroke(shine, with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    static func shadow(_ ctx: GraphicsContext, at p: CGPoint, width: CGFloat) {
        let r = CGRect(x: p.x - width / 2, y: p.y - 4, width: width, height: 9)
        ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [Color.black.opacity(0.22), Color.black.opacity(0)]),
                                                         center: p, startRadius: 0, endRadius: width / 2))
    }

    // MARK: Whole plants (above the soil)

    static func draw(_ ctx: GraphicsContext, plant: Plant, base: CGPoint, bend: CGFloat, pop: CGFloat,
                     pull: CGFloat, time: CGFloat, droop: Bool) {
        var g = ctx
        let s = 1 + pop * 0.045
        g.translateBy(x: base.x, y: base.y)
        g.scaleBy(x: 1 + pop * 0.02, y: s)
        g.translateBy(x: -base.x, y: -base.y)
        shadow(g, at: base, width: 18 + plant.kind.reach * CGFloat(plant.growth))
        let lift = CGPoint(x: base.x, y: base.y - pull * 44)
        switch plant.kind {
        case .sunflower: sunflower(g, plant, lift, bend, time)
        case .tulip: tulip(g, plant, lift, bend)
        case .daisy: daisy(g, plant, lift, bend)
        case .lavender: lavender(g, plant, lift, bend, time)
        case .carrot: carrotTop(g, plant, lift, bend, pull: pull)
        case .tomato: tomato(g, plant, lift, bend)
        case .strawberry: strawberry(g, plant, lift, bend)
        case .pumpkin: pumpkin(g, plant, lift, bend)
        }
        _ = droop
    }

    /// Two seed leaves on a tiny sprout.
    private static func sprout(_ ctx: GraphicsContext, _ st: Stem, _ g: CGFloat) {
        let k = gdEase((g - 0.03) / 0.1)
        guard k > 0 else { return }
        drawStem(ctx, st, width: 2.6)
        let leftA: CGFloat = 0.5 - .pi
        let rightA: CGFloat = -0.5
        leaf(ctx, at: st.top, angle: leftA, length: 11 * k, width: 5 * k, color: GRGB(0x8CCB5A), curl: 2)
        leaf(ctx, at: st.top, angle: rightA, length: 11 * k, width: 5 * k, color: GRGB(0x8CCB5A), curl: -2)
    }

    private static func sunflower(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        let st = stem(base: base, height: hgt, bend: bend)
        if g < 0.14 { sprout(ctx, st, g); return }
        drawStem(ctx, st, width: 3 + 5 * gdEase(g / 0.8))
        let spots: [CGFloat] = [0.2, 0.36, 0.52, 0.68, 0.82]
        for (j, t) in spots.enumerated() {
            let k = gdEase((g - 0.14 - CGFloat(j) * 0.09) / 0.25)
            if k <= 0 { continue }
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            let a = st.angle(t) + side * 1.2 + side * 0.25
            let len = (56 - CGFloat(j) * 5) * k
            leaf(ctx, at: st.at(t), angle: a, length: len, width: len * 0.45, color: GRGB(0x5BA642), curl: side * 4)
        }
        let budK = gdEase((g - 0.78) / 0.12)
        let open = gdEase((g - 0.9) / 0.1)
        guard budK > 0 else { return }
        sunflowerHead(ctx, at: st.top, angle: bend * 0.6, budK: budK, open: open, petal: p.kind.bloom(p.variant), time: time)
    }

    static func sunflowerHead(_ ctx: GraphicsContext, at top: CGPoint, angle: CGFloat, budK: CGFloat, open: CGFloat,
                              petal: GRGB, time: CGFloat) {
        var hg = ctx
        hg.translateBy(x: top.x, y: top.y)
        hg.rotate(by: .radians(Double(angle)))
        // Green back of the head, with pointed sepals.
        let sepR: CGFloat = 8 + 12 * budK
        var sep = Path()
        for i in 0..<14 {
            let a = CGFloat(i) / 14 * 2 * .pi
            let r = i % 2 == 0 ? sepR * 1.25 : sepR * 0.9
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r * 0.92)
            if i == 0 { sep.move(to: pt) } else { sep.addLine(to: pt) }
        }
        sep.closeSubpath()
        hg.fill(sep, with: .color(GRGB(0x4F8F35).color))
        if open > 0 {
            // Each ring of petals is one path, shaded from base to tip by a single radial gradient.
            let r0 = 10 + 10 * open
            let wid = 3 + 6 * open
            for ring in 0..<2 {
                let n = 20
                let len = (12 + 28 * open) * (ring == 0 ? 1 : 0.86)
                var petals = Path()
                for i in 0..<n {
                    let a = (CGFloat(i) + CGFloat(ring) * 0.5) / CGFloat(n) * 2 * .pi + sin(time * 0.8 + CGFloat(i)) * 0.015
                    var pp = Path()
                    pp.move(to: CGPoint(x: r0, y: 0))
                    pp.addQuadCurve(to: CGPoint(x: r0 + len, y: 0), control: CGPoint(x: r0 + len * 0.5, y: -wid))
                    pp.addQuadCurve(to: CGPoint(x: r0, y: 0), control: CGPoint(x: r0 + len * 0.5, y: wid))
                    petals.addPath(pp, transform: CGAffineTransform(rotationAngle: a))
                }
                let c = ring == 0 ? petal.shade(-0.12) : petal
                let grad = Gradient(colors: [c.shade(-0.2).color, c.shade(0.18).color])
                hg.fill(petals, with: .radialGradient(grad, center: .zero, startRadius: r0, endRadius: r0 + len))
                hg.stroke(petals, with: .color(c.shade(-0.4).color(0.5)), lineWidth: 0.8)
            }
        }
        let diskR: CGFloat = 8 + 16 * max(budK * 0.5, open)
        let disk = Path(ellipseIn: CGRect(x: -diskR, y: -diskR, width: diskR * 2, height: diskR * 2))
        let dg = Gradient(colors: [GRGB(0x7A4A22).color, GRGB(0x4A2C14).color, GRGB(0x2E1B0E).color])
        hg.fill(disk, with: .radialGradient(dg, center: CGPoint(x: -diskR * 0.25, y: -diskR * 0.3), startRadius: 0, endRadius: diskR * 1.1))
        if open > 0.2 {
            // Seeds in a golden-angle spiral.
            var seeds = Path()
            for i in 0..<46 {
                let r = diskR * 0.92 * sqrt(CGFloat(i) / 46)
                let a = CGFloat(i) * 2.39996
                seeds.addEllipse(in: CGRect(x: cos(a) * r - 1.2, y: sin(a) * r - 1.2, width: 2.4, height: 2.4))
            }
            hg.fill(seeds, with: .color(GRGB(0xA0703A).color(0.75 * Double(open))))
        }
        hg.fill(Path(ellipseIn: CGRect(x: -diskR * 0.55, y: -diskR * 0.7, width: diskR * 0.7, height: diskR * 0.45)),
                with: .color(.white.opacity(0.12)))
    }

    static func tulipPetal(_ ctx: GraphicsContext, at p: CGPoint, angle: CGFloat, height: CGFloat, width: CGFloat, color: GRGB) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(angle)))
        var path = Path()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: 0, y: -height), control1: CGPoint(x: width, y: -height * 0.12), control2: CGPoint(x: width * 0.85, y: -height * 0.92))
        path.addCurve(to: .zero, control1: CGPoint(x: -width * 0.85, y: -height * 0.92), control2: CGPoint(x: -width, y: -height * 0.12))
        let grad = Gradient(colors: [color.shade(-0.3).color, color.color, color.shade(0.25).color])
        g.fill(path, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: width * 0.3, y: -height)))
        g.stroke(path, with: .color(color.shade(-0.5).color(0.6)), lineWidth: 1)
        var shine = Path()
        shine.move(to: CGPoint(x: -width * 0.35, y: -height * 0.25))
        shine.addQuadCurve(to: CGPoint(x: -width * 0.2, y: -height * 0.8), control: CGPoint(x: -width * 0.55, y: -height * 0.55))
        g.stroke(shine, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private static func tulip(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        let st = stem(base: base, height: hgt, bend: bend)
        if g < 0.14 { sprout(ctx, st, g); return }
        let lk = gdEase((g - 0.12) / 0.4)
        leaf(ctx, at: CGPoint(x: base.x - 2, y: base.y), angle: -.pi / 2 - 0.42 + bend * 0.6, length: 78 * lk, width: 13 * lk,
             color: GRGB(0x6DAF5A), curl: -8 * lk)
        drawStem(ctx, st, width: 4.2)
        leaf(ctx, at: CGPoint(x: base.x + 2, y: base.y), angle: -.pi / 2 + 0.38 + bend * 0.6, length: 70 * lk, width: 12 * lk,
             color: GRGB(0x63A852), curl: 8 * lk)
        let budK = gdEase((g - 0.76) / 0.14)
        let open = gdEase((g - 0.9) / 0.1)
        guard budK > 0 else { return }
        let c = p.kind.bloom(p.variant)
        let hh = 16 + 26 * budK
        let ww = 8 + 13 * budK
        let a = bend * 0.8
        let top = st.top
        tulipPetal(ctx, at: top, angle: a, height: hh * 1.02, width: ww * 1.15, color: c.shade(-0.18))
        tulipPetal(ctx, at: top, angle: a - 0.08 - open * 0.32, height: hh, width: ww, color: c)
        tulipPetal(ctx, at: top, angle: a + 0.08 + open * 0.32, height: hh, width: ww, color: c.shade(0.04))
    }

    static func daisyHead(_ ctx: GraphicsContext, at p: CGPoint, open: CGFloat, color: GRGB, size: CGFloat, spin: CGFloat) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(spin)))
        if open < 0.05 {
            g.fill(Path(ellipseIn: CGRect(x: -5 * size, y: -5 * size, width: 10 * size, height: 10 * size)), with: .color(GRGB(0x6BAA44).color))
            return
        }
        let n = 14
        let len = (5 + 13 * open) * size
        for i in 0..<n {
            var pg = g
            pg.rotate(by: .radians(Double(CGFloat(i) / CGFloat(n) * 2 * .pi)))
            let r = CGRect(x: 4 * size, y: -3.2 * size, width: len, height: 6.4 * size)
            let pp = Path(roundedRect: r, cornerRadius: 3.2 * size)
            pg.fill(pp, with: .linearGradient(Gradient(colors: [color.shade(-0.12).color, color.color]),
                                              startPoint: CGPoint(x: 4 * size, y: 0), endPoint: CGPoint(x: 4 * size + len, y: 0)))
            pg.stroke(pp, with: .color(color.shade(-0.35).color(0.45)), lineWidth: 0.7)
        }
        let cr = (5 + 2.5 * open) * size
        let cg = Gradient(colors: [GRGB(0xFFE066).color, GRGB(0xF2A900).color])
        g.fill(Path(ellipseIn: CGRect(x: -cr, y: -cr, width: cr * 2, height: cr * 2)),
               with: .radialGradient(cg, center: CGPoint(x: -cr * 0.3, y: -cr * 0.3), startRadius: 0, endRadius: cr * 1.2))
    }

    private static func daisy(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.14 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g); return }
        let offs: [CGFloat] = [-0.3, 0.04, 0.32]
        let hs: [CGFloat] = [0.78, 1, 0.86]
        let open = gdEase((g - 0.88) / 0.12)
        let budK = gdEase((g - 0.74) / 0.14)
        let c = p.kind.bloom(p.variant)
        for j in 0..<3 {
            let st = stem(base: CGPoint(x: base.x + CGFloat(j - 1) * 4, y: base.y), height: hgt * hs[j], bend: bend * (0.9 + CGFloat(j) * 0.1) + offs[j])
            drawStem(ctx, st, width: 2.6)
            let lk = gdEase((g - 0.2) / 0.3)
            leaf(ctx, at: st.at(0.35), angle: st.angle(0.35) + (j == 0 ? -1.1 : 1.1), length: 22 * lk, width: 7 * lk, color: GRGB(0x66AE4C))
            if budK > 0 {
                daisyHead(ctx, at: st.top, open: open, color: c, size: 0.5 + 0.55 * budK, spin: CGFloat(j) * 0.4 + bend)
            }
        }
        let lk = gdEase((g - 0.14) / 0.3)
        leaf(ctx, at: base, angle: -.pi + 0.35, length: 26 * lk, width: 8 * lk, color: GRGB(0x5EA845))
        leaf(ctx, at: base, angle: -0.35, length: 24 * lk, width: 8 * lk, color: GRGB(0x5EA845))
    }

    private static func lavender(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.14 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g); return }
        let offs: [CGFloat] = [-0.36, -0.17, 0, 0.17, 0.36]
        let hs: [CGFloat] = [0.78, 0.92, 1, 0.9, 0.76]
        let spikeK = gdEase((g - 0.6) / 0.3)
        let bloomK = gdEase((g - 0.85) / 0.15)
        let purple = p.kind.bloom(p.variant)
        let lk = gdEase((g - 0.14) / 0.3)
        for j in [0, 4, 1, 3] {
            leaf(ctx, at: base, angle: -.pi / 2 + offs[j] * 2.6, length: 30 * lk, width: 4 * lk, color: GRGB(0x8DAE84))
        }
        // Every bud of one shade goes into one path, so a whole plant is three fills however many spikes it has.
        var deep = Path()
        var pale = Path()
        var glint = Path()
        for j in 0..<5 {
            let st = stem(base: base, height: hgt * hs[j], bend: bend * (0.8 + CGFloat(j) * 0.08) + offs[j])
            drawStem(ctx, st, width: 2, color: GRGB(0x7E9F6E))
            guard spikeK > 0 else { continue }
            for b in 0..<9 {
                let t = 0.62 + CGFloat(b) * 0.045
                let q = st.at(min(1, t))
                let r = (2 + 2.2 * spikeK) * (1 - CGFloat(b) * 0.04)
                for side in [-1.0, 1.0] {
                    let cx = q.x + CGFloat(side) * r * 0.55
                    let bud = CGRect(x: cx - r, y: q.y - r, width: r * 2, height: r * 2.2)
                    if b % 2 == 0 { deep.addEllipse(in: bud) } else { pale.addEllipse(in: bud) }
                }
                glint.addEllipse(in: CGRect(x: q.x - r * 0.9, y: q.y - r * 0.9, width: r * 0.7, height: r * 0.6))
            }
        }
        if spikeK > 0 {
            let k = bloomK * 0.9 + 0.1
            ctx.fill(deep, with: .color(GRGB(0x9DB08A).mix(purple.shade(-0.1), k).color))
            ctx.fill(pale, with: .color(GRGB(0x9DB08A).mix(purple.shade(0.08), k).color))
            if bloomK > 0 { ctx.fill(glint, with: .color(.white.opacity(0.25 * Double(bloomK)))) }
        }
        _ = time
    }

    private static func carrotTop(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, pull: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.14 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g); return }
        if pull > 0.02 { carrotRoot(ctx, p, base: base) }
        let fronds: [CGFloat] = [-0.55, -0.3, -0.1, 0.12, 0.34, 0.58]
        let fh: [CGFloat] = [0.7, 0.9, 1, 0.95, 0.85, 0.68]
        for (j, o) in fronds.enumerated() {
            let st = stem(base: base, height: hgt * fh[j], bend: bend + o)
            drawStem(ctx, st, width: 1.8, color: GRGB(0x5E9F3A))
            // Feathery leaflets along each frond.
            for b in 0..<6 {
                let t = 0.35 + CGFloat(b) * 0.11
                let q = st.at(t)
                let a = st.angle(t)
                let len = 9 * (1 - CGFloat(b) * 0.08) * gdEase((g - 0.18) / 0.4)
                for side in [-1.0, 1.0] {
                    let aa = a + CGFloat(side) * 0.9
                    var lp = Path()
                    lp.move(to: q)
                    lp.addLine(to: CGPoint(x: q.x + cos(aa) * len, y: q.y + sin(aa) * len))
                    ctx.stroke(lp, with: .color(GRGB(0x6DB548).color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
        }
        // Orange shoulders peek out of the soil when it is ready.
        let ripe = gdEase((g - 0.85) / 0.15)
        if ripe > 0 && pull <= 0.02 {
            let w = 10 + 10 * ripe
            let r = CGRect(x: base.x - w / 2, y: base.y - 5 * ripe, width: w, height: 9 * ripe + 2)
            ctx.fill(Path(ellipseIn: r), with: .color(GRGB(0xFF8A2A).color))
            ctx.fill(Path(ellipseIn: r.insetBy(dx: w * 0.25, dy: 1).offsetBy(dx: -2, dy: -1)), with: .color(.white.opacity(0.3)))
        }
    }

    /// The carrot itself: a tapered orange root with rings.
    static func carrotRoot(_ ctx: GraphicsContext, _ p: Plant, base: CGPoint) {
        let g = gdEase(CGFloat(p.growth))
        let len = 14 + 66 * g
        let w = 4 + 16 * g
        carrotShape(ctx, top: base, length: len, width: w, angle: 0)
    }

    static func carrotShape(_ ctx: GraphicsContext, top: CGPoint, length len: CGFloat, width w: CGFloat, angle: CGFloat) {
        var g = ctx
        g.translateBy(x: top.x, y: top.y)
        g.rotate(by: .radians(Double(angle)))
        var path = Path()
        path.move(to: CGPoint(x: -w / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: 0, y: -w * 0.35))
        path.addCurve(to: CGPoint(x: 0, y: len), control1: CGPoint(x: w * 0.5, y: len * 0.4), control2: CGPoint(x: w * 0.1, y: len * 0.85))
        path.addCurve(to: CGPoint(x: -w / 2, y: 0), control1: CGPoint(x: -w * 0.1, y: len * 0.85), control2: CGPoint(x: -w * 0.5, y: len * 0.4))
        let grad = Gradient(colors: [GRGB(0xFFA24A).color, GRGB(0xF07A1A).color, GRGB(0xC85A10).color])
        g.fill(path, with: .linearGradient(grad, startPoint: CGPoint(x: -w / 2, y: 0), endPoint: CGPoint(x: w / 2, y: 0)))
        g.stroke(path, with: .color(GRGB(0xA8480C).color(0.6)), lineWidth: 1)
        for k in 1..<6 {
            let y = len * CGFloat(k) / 7
            let half = w * 0.5 * (1 - CGFloat(k) / 7.5) * 0.8
            var ring = Path()
            ring.move(to: CGPoint(x: -half, y: y))
            ring.addQuadCurve(to: CGPoint(x: half * 0.3, y: y + 1.5), control: CGPoint(x: -half * 0.3, y: y + 2.5))
            g.stroke(ring, with: .color(GRGB(0xB05410).color(0.45)), lineWidth: 1)
        }
        g.fill(Path(ellipseIn: CGRect(x: -w * 0.32, y: len * 0.08, width: w * 0.18, height: len * 0.45)), with: .color(.white.opacity(0.22)))
    }

    static func tomatoFruit(_ ctx: GraphicsContext, at p: CGPoint, r: CGFloat, ripe: CGFloat) {
        let green = GRGB(0x86C04A)
        let orange = GRGB(0xF6A23A)
        let red = GRGB(0xEE3A2C)
        let c = ripe < 0.5 ? green.mix(orange, ripe * 2) : orange.mix(red, (ripe - 0.5) * 2)
        let rect = CGRect(x: p.x - r * 1.06, y: p.y - r, width: r * 2.12, height: r * 1.95)
        let grad = Gradient(colors: [c.shade(0.3).color, c.color, c.shade(-0.35).color])
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(grad, center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.4),
                                                              startRadius: 0, endRadius: r * 1.5))
        ctx.stroke(Path(ellipseIn: rect), with: .color(c.shade(-0.5).color(0.5)), lineWidth: 1)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.7, width: r * 0.5, height: r * 0.32)), with: .color(.white.opacity(0.55)))
        var cal = Path()
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * 2 * .pi
            let rr = i % 2 == 0 ? r * 0.55 : r * 0.18
            let pt = CGPoint(x: p.x + cos(a) * rr, y: p.y - r * 0.92 + sin(a) * rr * 0.45)
            if i == 0 { cal.move(to: pt) } else { cal.addLine(to: pt) }
        }
        cal.closeSubpath()
        ctx.fill(cal, with: .color(GRGB(0x4E8F35).color))
    }

    private static func tomato(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        // The stake goes in with the seed.
        let stake = CGRect(x: base.x + 13, y: base.y - 232, width: 7, height: 236)
        ctx.fill(Path(roundedRect: stake, cornerRadius: 3),
                 with: .linearGradient(Gradient(colors: [GRGB(0xD7A86E).color, GRGB(0xA87444).color]),
                                       startPoint: CGPoint(x: stake.minX, y: 0), endPoint: CGPoint(x: stake.maxX, y: 0)))
        let st = stem(base: base, height: hgt, bend: bend * 0.6)
        if g < 0.14 { sprout(ctx, st, g); return }
        drawStem(ctx, st, width: 3 + 3 * gdEase(g / 0.8), color: GRGB(0x5C9A3C))
        // Ties to the stake.
        for t in [0.35, 0.65, 0.9] as [CGFloat] where t * hgt > 30 {
            let q = st.at(t)
            var tie = Path()
            tie.move(to: q)
            tie.addLine(to: CGPoint(x: base.x + 16, y: q.y + 2))
            ctx.stroke(tie, with: .color(GRGB(0xEFE3C2).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        // Compound leaves.
        let spots: [CGFloat] = [0.18, 0.3, 0.44, 0.56, 0.7, 0.84]
        for (j, t) in spots.enumerated() {
            let k = gdEase((g - 0.14 - CGFloat(j) * 0.07) / 0.22)
            if k <= 0 { continue }
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            let q = st.at(t)
            let a = side < 0 ? CGFloat.pi + 0.45 : -0.45
            let len = 40 * k
            let tip = CGPoint(x: q.x + cos(a) * len, y: q.y + sin(a) * len)
            var stalk = Path()
            stalk.move(to: q)
            stalk.addLine(to: tip)
            ctx.stroke(stalk, with: .color(GRGB(0x5C9A3C).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            for b in 0..<3 {
                let bt = 0.4 + CGFloat(b) * 0.3
                let bp = CGPoint(x: q.x + cos(a) * len * bt, y: q.y + sin(a) * len * bt)
                leaf(ctx, at: bp, angle: a - 0.9, length: 15 * k, width: 7 * k, color: GRGB(0x5FA445))
                leaf(ctx, at: bp, angle: a + 0.9, length: 15 * k, width: 7 * k, color: GRGB(0x569C3E))
            }
            leaf(ctx, at: tip, angle: a, length: 16 * k, width: 8 * k, color: GRGB(0x5FA445))
        }
        // Little yellow flowers, then fruit.
        let flowerK = gdEase((g - 0.62) / 0.1) * (1 - gdEase((g - 0.82) / 0.06))
        let fruitK = gdEase((g - 0.78) / 0.16)
        let ripe = gdEase((g - 0.9) / 0.1)
        let scale = hgt / p.kind.height
        let picked = g >= 1 ? p.kind.crop - p.left : 0
        for (j, s) in tomatoSpots.enumerated() {
            let hang = CGPoint(x: base.x + s.x * 0.5 + sin(bend) * s.y * scale, y: base.y - s.y * scale + 8)
            if flowerK > 0 {
                daisyHead(ctx, at: CGPoint(x: base.x + s.x + sin(bend) * s.y * scale, y: base.y - s.y * scale), open: 0.7,
                          color: GRGB(0xFFD43B), size: 0.45 * flowerK, spin: CGFloat(j))
            }
            if fruitK > 0 && j >= picked {
                let fp = CGPoint(x: base.x + s.x + sin(bend) * s.y * scale, y: base.y - s.y * scale + 14)
                var vine = Path()
                vine.move(to: hang)
                vine.addQuadCurve(to: CGPoint(x: fp.x, y: fp.y - 8), control: CGPoint(x: fp.x, y: hang.y))
                ctx.stroke(vine, with: .color(GRGB(0x5C9A3C).color), lineWidth: 1.6)
                tomatoFruit(ctx, at: fp, r: 4 + 9 * fruitK, ripe: ripe)
            }
        }
    }

    static func strawberryFruit(_ ctx: GraphicsContext, at p: CGPoint, r: CGFloat, ripe: CGFloat, angle: CGFloat = 0) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(angle)))
        let c = GRGB(0xE9F2C8).mix(GRGB(0xE8263F), ripe)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -r * 0.7))
        path.addCurve(to: CGPoint(x: 0, y: r * 1.25), control1: CGPoint(x: r * 1.4, y: -r * 0.9), control2: CGPoint(x: r * 0.7, y: r * 0.9))
        path.addCurve(to: CGPoint(x: 0, y: -r * 0.7), control1: CGPoint(x: -r * 0.7, y: r * 0.9), control2: CGPoint(x: -r * 1.4, y: -r * 0.9))
        let grad = Gradient(colors: [c.shade(0.28).color, c.color, c.shade(-0.35).color])
        g.fill(path, with: .radialGradient(grad, center: CGPoint(x: -r * 0.3, y: -r * 0.2), startRadius: 0, endRadius: r * 1.6))
        g.stroke(path, with: .color(c.shade(-0.5).color(0.45)), lineWidth: 0.8)
        let seedColor = GRGB(0xFFE9A0).mix(GRGB(0xF6D35B), ripe)
        for i in 0..<9 {
            let sx = (gdRand(i, 3) - 0.5) * r * 1.2
            let sy = (gdRand(i, 7) - 0.25) * r * 1.3
            g.fill(Path(ellipseIn: CGRect(x: sx - 0.8, y: sy - 1.1, width: 1.6, height: 2.2)), with: .color(seedColor.color))
        }
        var cap = Path()
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * 2 * .pi
            let rr = i % 2 == 0 ? r * 0.75 : r * 0.25
            let pt = CGPoint(x: cos(a) * rr, y: -r * 0.66 + sin(a) * rr * 0.4)
            if i == 0 { cap.move(to: pt) } else { cap.addLine(to: pt) }
        }
        cap.closeSubpath()
        g.fill(cap, with: .color(GRGB(0x4E9A3A).color))
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.6, y: -r * 0.3, width: r * 0.4, height: r * 0.28)), with: .color(.white.opacity(0.45)))
    }

    private static func trifoliate(_ ctx: GraphicsContext, at p: CGPoint, angle: CGFloat, size: CGFloat) {
        for o in [-0.75, 0, 0.75] as [CGFloat] {
            leaf(ctx, at: p, angle: angle + o, length: 20 * size, width: 11 * size, color: o == 0 ? GRGB(0x4FA03E) : GRGB(0x479535))
        }
    }

    private static func strawberry(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.14 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g); return }
        let fruitK = gdEase((g - 0.78) / 0.16)
        let ripe = gdEase((g - 0.9) / 0.1)
        let picked = g >= 1 ? p.kind.crop - p.left : 0
        // Berries hang low, behind the leaves.
        for (j, s) in berrySpots.enumerated() where fruitK > 0 && j >= picked {
            let fp = CGPoint(x: base.x + s.x + bend * 10, y: base.y - s.y + 8)
            var vine = Path()
            vine.move(to: CGPoint(x: base.x, y: base.y - 20))
            vine.addQuadCurve(to: CGPoint(x: fp.x, y: fp.y - 6), control: CGPoint(x: fp.x * 0.6 + base.x * 0.4, y: base.y - 44))
            ctx.stroke(vine, with: .color(GRGB(0x5C9A3C).color), lineWidth: 1.6)
            strawberryFruit(ctx, at: fp, r: 3 + 7 * fruitK, ripe: ripe, angle: s.x > 0 ? -0.25 : 0.25)
        }
        let angles: [CGFloat] = [-1.0, -0.42, 0.12, 0.62, 1.05]
        let hs: [CGFloat] = [0.66, 0.94, 1, 0.86, 0.6]
        let lk = gdEase((g - 0.14) / 0.4)
        for j in 0..<5 {
            let st = stem(base: base, height: hgt * hs[j], bend: bend + angles[j])
            drawStem(ctx, st, width: 1.8, color: GRGB(0x6AA548))
            if lk > 0 { trifoliate(ctx, at: st.top, angle: st.angle(1), size: 0.55 + 0.45 * lk) }
        }
        let flowerK = gdEase((g - 0.6) / 0.1) * (1 - gdEase((g - 0.82) / 0.06))
        if flowerK > 0 {
            for j in 0..<2 {
                let fp = CGPoint(x: base.x + (j == 0 ? -22 : 24) + bend * 14, y: base.y - hgt * 0.75)
                daisyHead(ctx, at: fp, open: 0.6, color: GRGB(0xFFFFFF), size: 0.55 * flowerK, spin: 0.3)
            }
        }
    }

    static func pumpkinFruit(_ ctx: GraphicsContext, at p: CGPoint, w: CGFloat, ripe: CGFloat) {
        let c = GRGB(0x77A63E).mix(GRGB(0xF78A1E), ripe)
        let hgt = w * 0.74
        let lobes: [CGFloat] = [-0.36, 0.36, -0.14, 0.14, 0]
        let widths: [CGFloat] = [0.5, 0.5, 0.52, 0.52, 0.46]
        for (k, o) in lobes.enumerated() {
            let lw = w * widths[k]
            let rect = CGRect(x: p.x + o * w - lw / 2, y: p.y - hgt, width: lw, height: hgt)
            let shade = k < 2 ? -0.22 : (k < 4 ? -0.08 : 0.06)
            let lc = c.shade(shade)
            let grad = Gradient(colors: [lc.shade(0.25).color, lc.color, lc.shade(-0.3).color])
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(grad, center: CGPoint(x: rect.midX - lw * 0.15, y: rect.minY + hgt * 0.3),
                                                                  startRadius: 0, endRadius: hgt * 0.9))
            ctx.stroke(Path(ellipseIn: rect), with: .color(c.shade(-0.5).color(0.45)), lineWidth: 1)
        }
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - w * 0.12, y: p.y - hgt * 0.86, width: w * 0.12, height: hgt * 0.3)), with: .color(.white.opacity(0.3)))
        var st = Path()
        st.move(to: CGPoint(x: p.x - 2, y: p.y - hgt + 3))
        st.addQuadCurve(to: CGPoint(x: p.x + w * 0.1, y: p.y - hgt - w * 0.16), control: CGPoint(x: p.x - 3, y: p.y - hgt - w * 0.12))
        ctx.stroke(st, with: .color(GRGB(0x6B7A35).color), style: StrokeStyle(lineWidth: max(2, w * 0.08), lineCap: .round))
    }

    static func lobedLeaf(_ ctx: GraphicsContext, at p: CGPoint, r: CGFloat, angle: CGFloat, color: GRGB) {
        guard r > 1 else { return }
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(angle)))
        var path = Path()
        let n = 5
        for i in 0...n * 2 {
            let a = CGFloat(i) / CGFloat(n * 2) * 2 * .pi
            let rr = i % 2 == 0 ? r : r * 0.72
            let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr * 0.86)
            if i == 0 { path.move(to: pt) } else {
                let mid = CGFloat(i) - 0.5
                let ma = mid / CGFloat(n * 2) * 2 * .pi
                path.addQuadCurve(to: pt, control: CGPoint(x: cos(ma) * rr * 1.12, y: sin(ma) * rr * 0.96))
            }
        }
        path.closeSubpath()
        let grad = Gradient(colors: [color.shade(0.15).color, color.color, color.shade(-0.3).color])
        g.fill(path, with: .radialGradient(grad, center: CGPoint(x: -r * 0.3, y: -r * 0.3), startRadius: 0, endRadius: r * 1.3))
        g.stroke(path, with: .color(color.shade(-0.5).color(0.7)), lineWidth: 1.1)
        for i in 0..<5 {
            let a = CGFloat(i) / 5 * 2 * .pi + 0.6
            var v = Path()
            v.move(to: .zero)
            v.addLine(to: CGPoint(x: cos(a) * r * 0.75, y: sin(a) * r * 0.65))
            g.stroke(v, with: .color(color.shade(-0.35).color(0.5)), lineWidth: 1)
        }
    }

    private static func pumpkin(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.14 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g); return }
        let vk = gdEase((g - 0.14) / 0.5)
        // Vines creep along the soil both ways, with curly tendrils.
        for side in [-1.0, 1.0] as [CGFloat] {
            let len = (40 + 70 * vk) * (side < 0 ? 1 : 0.8)
            var v = Path()
            v.move(to: CGPoint(x: base.x, y: base.y - 3))
            v.addQuadCurve(to: CGPoint(x: base.x + side * len, y: base.y - 4), control: CGPoint(x: base.x + side * len * 0.5, y: base.y - 14))
            ctx.stroke(v, with: .color(GRGB(0x5C9A3C).color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            var tendril = Path()
            let tx = base.x + side * len
            tendril.move(to: CGPoint(x: tx, y: base.y - 4))
            for k in 1...10 {
                let a = CGFloat(k) * 0.9
                let r = 7 - CGFloat(k) * 0.5
                tendril.addLine(to: CGPoint(x: tx + side * (CGFloat(k) * 1.2 + cos(a) * r), y: base.y - 10 + sin(a) * r))
            }
            ctx.stroke(tendril, with: .color(GRGB(0x7DB54F).color), lineWidth: 1.2)
        }
        let fruitK = gdEase((g - 0.7) / 0.26)
        let ripe = gdEase((g - 0.88) / 0.12)
        if fruitK > 0 && !(g >= 1 && p.left == 0) {
            pumpkinFruit(ctx, at: CGPoint(x: base.x + 26, y: base.y + 2), w: 12 + 62 * fruitK, ripe: ripe)
        }
        let leaves: [(CGFloat, CGFloat, CGFloat)] = [(-0.5, 0.95, 26), (0.4, 0.75, 22), (-0.1, 1, 30), (0.9, 0.5, 19)]
        for (j, l) in leaves.enumerated() {
            let lk = gdEase((g - 0.14 - CGFloat(j) * 0.08) / 0.3)
            if lk <= 0 { continue }
            let st = stem(base: base, height: hgt * l.1, bend: bend + l.0)
            drawStem(ctx, st, width: 2.2, color: GRGB(0x6AA548))
            lobedLeaf(ctx, at: st.top, r: l.2 * lk, angle: bend * 0.5 + CGFloat(j), color: GRGB(0x58A043))
        }
        let flowerK = gdEase((g - 0.5) / 0.1) * (1 - gdEase((g - 0.74) / 0.06))
        if flowerK > 0 {
            daisyHead(ctx, at: CGPoint(x: base.x - 30, y: base.y - 18), open: 0.5, color: GRGB(0xFFC233), size: 0.9 * flowerK, spin: 0)
        }
    }

    // MARK: Under the soil

    static func drawRoots(_ ctx: GraphicsContext, plant: Plant, base: CGPoint, pull: CGFloat, seed: Int) {
        let g = CGFloat(plant.growth)
        let b = CGPoint(x: base.x, y: base.y - pull * 44)
        if g < 0.2 {
            let k = 1 - gdEase((g - 0.12) / 0.08)
            let sc = plant.kind.seedColor
            let r = CGRect(x: b.x - 4, y: b.y + 10, width: 8, height: 5.5)
            ctx.fill(Path(ellipseIn: r), with: .color(sc.color(Double(k))))
        }
        let n = plant.kind == .carrot ? 3 : 5
        let len = 10 + 70 * gdEase(g / 0.9)
        for i in 0..<n {
            let a = (CGFloat(i) / CGFloat(max(1, n - 1)) - 0.5) * 2.0
            var p = Path()
            p.move(to: CGPoint(x: b.x, y: b.y + 4))
            let end = CGPoint(x: b.x + a * len * 0.6, y: b.y + len * (0.7 + gdRand(i, seed) * 0.3))
            let ctrl = CGPoint(x: b.x + a * len * 0.1 + (gdRand(i, seed + 1) - 0.5) * 14, y: b.y + len * 0.5)
            p.addQuadCurve(to: end, control: ctrl)
            ctx.stroke(p, with: .color(GRGB(0xEFDDB8).color(0.8)), style: StrokeStyle(lineWidth: 1.6 - CGFloat(i % 2) * 0.5, lineCap: .round))
            // Root hairs.
            for k in 1..<4 {
                let q = quad(CGPoint(x: b.x, y: b.y + 4), ctrl, end, CGFloat(k) / 4)
                var hair = Path()
                hair.move(to: q)
                hair.addLine(to: CGPoint(x: q.x + (gdRand(k, i + seed) - 0.5) * 10, y: q.y + 5))
                ctx.stroke(hair, with: .color(GRGB(0xEFDDB8).color(0.5)), lineWidth: 0.7)
            }
        }
        if plant.kind == .carrot && pull <= 0.02 && g >= 0.14 { carrotRoot(ctx, plant, base: b) }
    }

    // MARK: Weeds

    static func drawWeed(_ ctx: GraphicsContext, weed w: GWeed, base: CGPoint, time: CGFloat) {
        let g = gdEase(w.growth)
        var c = ctx
        let lift = w.pull * 24
        c.translateBy(x: base.x, y: base.y - lift)
        c.scaleBy(x: 1 - w.pull * 0.12, y: 1 + w.pull * 0.45)
        if w.pull > 0.02 {
            // The root comes up with it.
            var root = Path()
            root.move(to: .zero)
            root.addQuadCurve(to: CGPoint(x: 3, y: 18 + 16 * g), control: CGPoint(x: -4, y: 10))
            c.stroke(root, with: .color(GRGB(0xD9C29A).color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        shadow(c, at: .zero, width: 22 + 20 * g)
        let n = 6
        for i in 0..<n {
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            let spread = 0.2 + CGFloat(i / 2) * 0.32
            let a = -CGFloat.pi / 2 + side * spread + w.bend * 0.8
            let len = (12 + 30 * g) * (1 - CGFloat(i / 2) * 0.15)
            jaggedLeaf(c, angle: a, length: len, width: 6 + 4 * g)
        }
        if g > 0.75 {
            let k = gdEase((g - 0.75) / 0.25)
            let top = CGPoint(x: sin(w.bend) * 38 * k, y: -38 * k)
            var st = Path()
            st.move(to: .zero)
            st.addQuadCurve(to: top, control: CGPoint(x: 0, y: -20 * k))
            c.stroke(st, with: .color(GRGB(0x7FA645).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            if w.seed % 2 == 0 {
                daisyHead(c, at: top, open: 1, color: GRGB(0xFFD21F), size: 0.5 * k, spin: time * 0.1)
            } else {
                // A seed puff.
                for i in 0..<16 {
                    let a = CGFloat(i) / 16 * 2 * .pi
                    var s = Path()
                    s.move(to: top)
                    s.addLine(to: CGPoint(x: top.x + cos(a) * 9 * k, y: top.y + sin(a) * 9 * k))
                    c.stroke(s, with: .color(.white.opacity(0.9)), lineWidth: 0.8)
                    c.fill(Path(ellipseIn: CGRect(x: top.x + cos(a) * 9 * k - 1.2, y: top.y + sin(a) * 9 * k - 1.2, width: 2.4, height: 2.4)),
                           with: .color(.white))
                }
            }
        }
    }

    private static func jaggedLeaf(_ ctx: GraphicsContext, angle: CGFloat, length: CGFloat, width: CGFloat) {
        var g = ctx
        g.rotate(by: .radians(Double(angle)))
        var p = Path()
        p.move(to: .zero)
        let teeth = 4
        for i in 1...teeth {
            let x = length * CGFloat(i) / CGFloat(teeth)
            let w = width * (1 - CGFloat(i) / CGFloat(teeth + 1))
            p.addLine(to: CGPoint(x: x - length * 0.12, y: -w))
            p.addLine(to: CGPoint(x: x, y: -w * 0.35))
        }
        p.addLine(to: CGPoint(x: length, y: 0))
        for i in (1...teeth).reversed() {
            let x = length * CGFloat(i) / CGFloat(teeth)
            let w = width * (1 - CGFloat(i) / CGFloat(teeth + 1))
            p.addLine(to: CGPoint(x: x, y: w * 0.35))
            p.addLine(to: CGPoint(x: x - length * 0.12, y: w))
        }
        p.closeSubpath()
        let grad = Gradient(colors: [olive.shade(-0.3).color, olive.shade(0.1).color])
        g.fill(p, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: length, y: 0)))
        g.stroke(p, with: .color(olive.shade(-0.5).color(0.7)), lineWidth: 0.9)
    }

    static func drawWeedRoot(_ ctx: GraphicsContext, weed w: GWeed, base: CGPoint) {
        guard w.pull <= 0.02 else { return }
        let g = gdEase(w.growth)
        var root = Path()
        root.move(to: base)
        root.addQuadCurve(to: CGPoint(x: base.x + 3, y: base.y + 18 + 30 * g), control: CGPoint(x: base.x - 5, y: base.y + 14))
        ctx.stroke(root, with: .color(GRGB(0xD9C29A).color(0.85)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    // MARK: Picked things (flying to the basket, and in it)

    static func drawCrop(_ ctx: GraphicsContext, kind: PlantKind, variant: Int, at p: CGPoint, size s: CGFloat, rot: CGFloat) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(rot)))
        switch kind {
        case .tomato: tomatoFruit(g, at: .zero, r: 13 * s, ripe: 1)
        case .strawberry: strawberryFruit(g, at: .zero, r: 11 * s, ripe: 1)
        case .pumpkin: pumpkinFruit(g, at: CGPoint(x: 0, y: 20 * s), w: 48 * s, ripe: 1)
        case .carrot:
            for o in [-0.4, 0, 0.4] as [CGFloat] {
                leaf(g, at: CGPoint(x: 0, y: -18 * s), angle: -.pi / 2 + o, length: 18 * s, width: 4 * s, color: GRGB(0x6DB548))
            }
            carrotShape(g, top: CGPoint(x: 0, y: -18 * s), length: 46 * s, width: 15 * s, angle: 0)
        case .sunflower:
            var hg = g
            hg.scaleBy(x: s * 0.62, y: s * 0.62)
            sunflowerHead(hg, at: .zero, angle: 0, budK: 1, open: 1, petal: kind.bloom(variant), time: 0)
        case .tulip:
            let c = kind.bloom(variant)
            tulipPetal(g, at: CGPoint(x: 0, y: 14 * s), angle: 0, height: 34 * s, width: 18 * s, color: c.shade(-0.18))
            tulipPetal(g, at: CGPoint(x: 0, y: 14 * s), angle: -0.3, height: 32 * s, width: 15 * s, color: c)
            tulipPetal(g, at: CGPoint(x: 0, y: 14 * s), angle: 0.3, height: 32 * s, width: 15 * s, color: c.shade(0.04))
        case .daisy:
            daisyHead(g, at: .zero, open: 1, color: kind.bloom(variant), size: 1.1 * s, spin: 0)
        case .lavender:
            for b in 0..<7 {
                let y = -CGFloat(b) * 5 * s
                let r = 3.6 * s * (1 - CGFloat(b) * 0.06)
                for side in [-1.0, 1.0] as [CGFloat] {
                    g.fill(Path(ellipseIn: CGRect(x: side * r * 0.5 - r, y: y - r, width: r * 2, height: r * 2.2)),
                           with: .color(kind.bloom(variant).shade(b % 2 == 0 ? -0.1 : 0.08).color))
                }
            }
            var st = Path()
            st.move(to: CGPoint(x: 0, y: 2))
            st.addLine(to: CGPoint(x: 0, y: 20 * s))
            g.stroke(st, with: .color(GRGB(0x7E9F6E).color), lineWidth: 2)
        }
    }
}
