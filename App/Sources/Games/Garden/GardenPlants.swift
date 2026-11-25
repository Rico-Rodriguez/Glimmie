import SwiftUI

enum GardenPlants {
    static let leafGreen = GRGB(0x5DAE47)
    static let stemGreen = GRGB(0x4E9A3A)
    static let olive = GRGB(0x7DA83A)

    static let tomatoSpots: [CGPoint] = [
        CGPoint(x: -26, y: 100),
        CGPoint(x: 24, y: 128),
        CGPoint(x: -18, y: 150),
    ]
    static let berrySpots: [CGPoint] = [
        CGPoint(x: -32, y: 16),
        CGPoint(x: 30, y: 20),
        CGPoint(x: 2, y: 26),
    ]

    static func stemHeight(_ p: Plant) -> CGFloat {
        let g = CGFloat(p.growth)
        let sprout = 16 * gdClamp(g / 0.12)
        let targetH = p.hybrid?.height ?? p.kind.height
        let main = targetH * gdEase((g - 0.06) / 0.74)
        return max(sprout, main)
    }

    // MARK: Geometry helpers

    static func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let x = u * u * a.x + 2 * u * t * c.x + t * t * b.x
        let y = u * u * a.y + 2 * u * t * c.y + t * t * b.y
        return CGPoint(x: x, y: y)
    }

    static func crescentMoonPath(center c: CGPoint, radius r: CGFloat) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: c.x + x * r, y: c.y + y * r)
        }
        var p = Path()
        p.move(to: pt(-0.087, -0.996))
        p.addCurve(to: pt(-0.866, 0.500), control1: pt(-0.816, -0.932), control2: pt(-1.232, -0.133))
        p.addCurve(to: pt(0.819, 0.574), control1: pt(-0.500, 1.133), control2: pt(0.400, 1.173))
        p.addCurve(to: pt(-0.339, 0.195), control1: pt(0.393, 0.762), control2: pt(-0.106, 0.599))
        p.addCurve(to: pt(-0.087, -0.996), control1: pt(-0.572, -0.208), control2: pt(-0.463, -0.721))
        p.closeSubpath()
        return p
    }

    struct Stem {
        var base: CGPoint
        var ctrl: CGPoint
        var top: CGPoint

        func at(_ t: CGFloat) -> CGPoint { GardenPlants.quad(base, ctrl, top, t) }

        func angle(_ t: CGFloat) -> CGFloat {
            let a = at(max(0, t - 0.02))
            let b = at(min(1, t + 0.02))
            return atan2(b.y - a.y, b.x - a.x)
        }
    }

    static func stem(base: CGPoint, height: CGFloat, bend: CGFloat) -> Stem {
        let top = CGPoint(x: base.x + sin(bend) * height, y: base.y - cos(bend) * height)
        let ctrl = CGPoint(x: base.x + sin(bend * 0.32) * height * 0.5, y: base.y - height * 0.56)
        return Stem(base: base, ctrl: ctrl, top: top)
    }

    static func drawStem(_ ctx: GraphicsContext, _ s: Stem, width: CGFloat, color: GRGB = stemGreen) {
        var p = Path()
        p.move(to: s.base)
        p.addQuadCurve(to: s.top, control: s.ctrl)
        let round = StrokeStyle(lineWidth: width + 2.6, lineCap: .round, lineJoin: .round)
        ctx.stroke(p, with: .color(color.shade(-0.44).color), style: round)
        ctx.stroke(p, with: .color(color.color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        var hl = Path()
        hl.move(to: CGPoint(x: s.base.x - width * 0.22, y: s.base.y))
        hl.addQuadCurve(to: CGPoint(x: s.top.x - width * 0.22, y: s.top.y), control: CGPoint(x: s.ctrl.x - width * 0.22, y: s.ctrl.y))
        ctx.stroke(hl, with: .color(color.shade(0.35).color(0.7)), style: StrokeStyle(lineWidth: max(1, width * 0.28), lineCap: .round))
    }

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
        let grad = Gradient(colors: [color.shade(-0.26).color, color.shade(0.14).color])
        g.fill(path, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: length, y: -width * 0.3)))
        g.stroke(path, with: .color(color.shade(-0.46).color(0.9)), lineWidth: 1.4)
        var rib = Path()
        rib.move(to: CGPoint(x: 2, y: 0))
        rib.addQuadCurve(to: CGPoint(x: length * 0.86, y: curl * 0.8), control: CGPoint(x: length * 0.5, y: -width * 0.12))
        g.stroke(rib, with: .color(color.shade(-0.35).color(0.55)), lineWidth: 1)
        guard length > 20 else { return }
        var shine = Path()
        shine.move(to: CGPoint(x: length * 0.2, y: -width * 0.25))
        shine.addQuadCurve(to: CGPoint(x: length * 0.62, y: -width * 0.32), control: CGPoint(x: length * 0.4, y: -width * 0.55))
        g.stroke(shine, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    static func shadow(_ ctx: GraphicsContext, at p: CGPoint, width: CGFloat) {
        let r = CGRect(x: p.x - width / 2, y: p.y - 4, width: width, height: 9)
        ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [Color.black.opacity(0.2), Color.black.opacity(0)]),
                                                         center: p, startRadius: 0, endRadius: width / 2))
    }

    // MARK: Whole plants (above the soil)

    static func draw(_ ctx: GraphicsContext, plant: Plant, base: CGPoint, bend: CGFloat, pop: CGFloat,
                     pull: CGFloat, time: CGFloat, droop: Bool) {
        var g = ctx
        let droopY: CGFloat = droop ? 0.90 : 1.0
        let droopX: CGFloat = droop ? 1.04 : 1.0
        let sY = (1 + pop * 0.045) * droopY
        let sX = (1 + pop * 0.02) * droopX
        g.translateBy(x: base.x, y: base.y)
        g.scaleBy(x: sX, y: sY)
        g.translateBy(x: -base.x, y: -base.y)
        shadow(g, at: base, width: 18 + plant.effectiveReach * CGFloat(plant.growth))
        let lift = CGPoint(x: base.x, y: base.y - pull * 42)
        // Thirsty droop softly leans the stem and bows the leaves downward.
        let sagDir: CGFloat = bend >= 0 ? 1 : -1
        let bendEff = max(-0.95, min(0.95, bend + (droop ? sagDir * 0.24 : 0)))
        let leafSag: CGFloat = droop ? 0.34 : 0
        if let hybrid = plant.hybrid {
            drawHybrid(g, hybrid: hybrid, plant: plant, base: lift, bend: bendEff, time: time, leafSag: leafSag)
            return
        }
        switch plant.kind {
        case .sunflower: sunflower(g, plant, lift, bendEff, time, leafSag: leafSag)
        case .tulip: tulip(g, plant, lift, bendEff, leafSag: leafSag)
        case .daisy: daisy(g, plant, lift, bendEff, leafSag: leafSag)
        case .lavender: lavender(g, plant, lift, bendEff, leafSag: leafSag)
        case .carrot: carrotTop(g, plant, lift, bendEff, pull: pull, leafSag: leafSag)
        case .tomato: tomato(g, plant, lift, bendEff, leafSag: leafSag)
        case .strawberry: strawberry(g, plant, lift, bendEff, leafSag: leafSag)
        case .pumpkin: pumpkin(g, plant, lift, bendEff, time: time, leafSag: leafSag)
        }
    }

    private static func sprout(_ ctx: GraphicsContext, _ st: Stem, _ g: CGFloat, leafSag: CGFloat) {
        let k = gdEase((g - 0.02) / 0.1)
        guard k > 0 else { return }
        drawStem(ctx, st, width: 3.0)
        let leftA: CGFloat = 0.48 - .pi - leafSag
        let rightA: CGFloat = -0.48 + leafSag
        leaf(ctx, at: st.top, angle: leftA, length: 13 * k, width: 6 * k, color: GRGB(0x8CCB5A), curl: 2 + leafSag * 5)
        leaf(ctx, at: st.top, angle: rightA, length: 13 * k, width: 6 * k, color: GRGB(0x8CCB5A), curl: -2 - leafSag * 5)
    }

    private static func sunflower(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        let st = stem(base: base, height: hgt, bend: bend)
        if g < 0.15 { sprout(ctx, st, g, leafSag: leafSag); return }
        drawStem(ctx, st, width: 3.2 + 4.8 * gdEase(g / 0.8))
        let spots: [CGFloat] = [0.22, 0.38, 0.54, 0.70, 0.82]
        for (j, t) in spots.enumerated() {
            let k = gdEase((g - 0.14 - CGFloat(j) * 0.08) / 0.24)
            if k <= 0 { continue }
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            let a = st.angle(t) + side * (1.35 + leafSag)
            let len = (48 - CGFloat(j) * 4) * k
            leaf(ctx, at: st.at(t), angle: a, length: len, width: len * 0.45, color: GRGB(0x5BA642), curl: side * (4 + leafSag * 10))
        }
        let budK = gdEase((g - 0.72) / 0.16)
        let open = gdEase((g - 0.86) / 0.14)
        guard budK > 0 else { return }
        sunflowerHead(ctx, at: st.top, angle: bend * 0.65, budK: budK, open: open, petal: p.kind.bloom(p.variant), time: time)
    }

    static func sunflowerHead(_ ctx: GraphicsContext, at top: CGPoint, angle: CGFloat, budK: CGFloat, open: CGFloat,
                              petal: GRGB, time: CGFloat) {
        var hg = ctx
        hg.translateBy(x: top.x, y: top.y)
        hg.rotate(by: .radians(Double(angle)))
        let sepR: CGFloat = 8 + 11 * budK
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
            let r0 = 9 + 9 * open
            let wid = 3 + 5.5 * open
            for ring in 0..<2 {
                let n = 18
                let len = (11 + 24 * open) * (ring == 0 ? 1 : 0.86)
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
                let grad = Gradient(colors: [c.shade(-0.18).color, c.shade(0.18).color])
                hg.fill(petals, with: .radialGradient(grad, center: .zero, startRadius: r0, endRadius: r0 + len))
                hg.stroke(petals, with: .color(c.shade(-0.42).color(0.75)), lineWidth: 1.2)
            }
        }
        let diskR: CGFloat = 8 + 14 * max(budK * 0.5, open)
        let disk = Path(ellipseIn: CGRect(x: -diskR, y: -diskR, width: diskR * 2, height: diskR * 2))
        let dg = Gradient(colors: [GRGB(0x7A4A22).color, GRGB(0x4A2C14).color, GRGB(0x2E1B0E).color])
        hg.fill(disk, with: .radialGradient(dg, center: CGPoint(x: -diskR * 0.25, y: -diskR * 0.3), startRadius: 0, endRadius: diskR * 1.1))
        hg.stroke(disk, with: .color(GRGB(0x3D210E).color(0.8)), lineWidth: 1.4)
        if open > 0.2 {
            var seeds = Path()
            for i in 0..<42 {
                let r = diskR * 0.9 * sqrt(CGFloat(i) / 42)
                let a = CGFloat(i) * 2.39996
                seeds.addEllipse(in: CGRect(x: cos(a) * r - 1.2, y: sin(a) * r - 1.2, width: 2.4, height: 2.4))
            }
            hg.fill(seeds, with: .color(GRGB(0xA0703A).color(0.75 * Double(open))))
        }
        StorybookArt.highlight(hg, in: CGRect(x: -diskR * 0.55, y: -diskR * 0.68, width: diskR * 0.65, height: diskR * 0.42), opacity: 0.16)
    }

    static func tulipPetal(_ ctx: GraphicsContext, at p: CGPoint, angle: CGFloat, height: CGFloat, width: CGFloat, color: GRGB) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(angle)))
        var path = Path()
        path.move(to: .zero)
        path.addCurve(to: CGPoint(x: 0, y: -height), control1: CGPoint(x: width, y: -height * 0.12), control2: CGPoint(x: width * 0.85, y: -height * 0.92))
        path.addCurve(to: .zero, control1: CGPoint(x: -width * 0.85, y: -height * 0.92), control2: CGPoint(x: -width, y: -height * 0.12))
        let grad = Gradient(colors: [color.shade(-0.26).color, color.color, color.shade(0.24).color])
        g.fill(path, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: width * 0.3, y: -height)))
        g.stroke(path, with: .color(color.shade(-0.46).color(0.78)), lineWidth: 1.4)
        var shine = Path()
        shine.move(to: CGPoint(x: -width * 0.35, y: -height * 0.25))
        shine.addQuadCurve(to: CGPoint(x: -width * 0.2, y: -height * 0.8), control: CGPoint(x: -width * 0.55, y: -height * 0.55))
        g.stroke(shine, with: .color(.white.opacity(0.38)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private static func tulip(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        let st = stem(base: base, height: hgt, bend: bend)
        if g < 0.15 { sprout(ctx, st, g, leafSag: leafSag); return }
        let lk = gdEase((g - 0.12) / 0.38)
        leaf(ctx, at: CGPoint(x: base.x - 2, y: base.y), angle: -.pi / 2 - 0.42 - leafSag + bend * 0.6, length: 72 * lk, width: 12 * lk,
             color: GRGB(0x6DAF5A), curl: -(8 + leafSag * 14) * lk)
        drawStem(ctx, st, width: 4.2)
        leaf(ctx, at: CGPoint(x: base.x + 2, y: base.y), angle: -.pi / 2 + 0.38 + leafSag + bend * 0.6, length: 64 * lk, width: 11 * lk,
             color: GRGB(0x63A852), curl: (8 + leafSag * 14) * lk)
        let budK = gdEase((g - 0.72) / 0.16)
        let open = gdEase((g - 0.86) / 0.14)
        guard budK > 0 else { return }
        let c = p.kind.bloom(p.variant)
        let hh = 16 + 24 * budK
        let ww = 8 + 12 * budK
        let a = bend * 0.85
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
            pg.fill(pp, with: .linearGradient(Gradient(colors: [color.shade(-0.1).color, color.color]),
                                              startPoint: CGPoint(x: 4 * size, y: 0), endPoint: CGPoint(x: 4 * size + len, y: 0)))
            pg.stroke(pp, with: .color(color.shade(-0.36).color(0.65)), lineWidth: 1.0)
        }
        let cr = (5 + 2.5 * open) * size
        let cg = Gradient(colors: [GRGB(0xFFE066).color, GRGB(0xF2A900).color])
        g.fill(Path(ellipseIn: CGRect(x: -cr, y: -cr, width: cr * 2, height: cr * 2)),
               with: .radialGradient(cg, center: CGPoint(x: -cr * 0.3, y: -cr * 0.3), startRadius: 0, endRadius: cr * 1.2))
        g.stroke(Path(ellipseIn: CGRect(x: -cr, y: -cr, width: cr * 2, height: cr * 2)),
                 with: .color(GRGB(0xC28208).color(0.6)), lineWidth: 1.0)
    }

    private static func daisy(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.15 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g, leafSag: leafSag); return }
        let offs: [CGFloat] = [-0.3 - leafSag * 0.35, 0.04, 0.32 + leafSag * 0.35]
        let hs: [CGFloat] = [0.78, 1, 0.86]
        let open = gdEase((g - 0.84) / 0.16)
        let budK = gdEase((g - 0.70) / 0.16)
        let c = p.kind.bloom(p.variant)
        for j in 0..<3 {
            let st = stem(base: CGPoint(x: base.x + CGFloat(j - 1) * 4, y: base.y), height: hgt * hs[j], bend: bend * (0.9 + CGFloat(j) * 0.1) + offs[j])
            drawStem(ctx, st, width: 2.6)
            let lk = gdEase((g - 0.2) / 0.3)
            leaf(ctx, at: st.at(0.35), angle: st.angle(0.35) + (j == 0 ? -1.1 - leafSag : 1.1 + leafSag), length: 22 * lk, width: 7 * lk, color: GRGB(0x66AE4C))
            if budK > 0 {
                daisyHead(ctx, at: st.top, open: open, color: c, size: 0.5 + 0.55 * budK, spin: CGFloat(j) * 0.4 + bend)
            }
        }
        let lk = gdEase((g - 0.14) / 0.3)
        leaf(ctx, at: base, angle: -.pi + 0.35 - leafSag * 0.5, length: 26 * lk, width: 8 * lk, color: GRGB(0x5EA845))
        leaf(ctx, at: base, angle: -0.35 + leafSag * 0.5, length: 24 * lk, width: 8 * lk, color: GRGB(0x5EA845))
    }

    private static func lavender(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.15 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g, leafSag: leafSag); return }
        let offs: [CGFloat] = [-0.36 - leafSag * 0.3, -0.17 - leafSag * 0.15, 0, 0.17 + leafSag * 0.15, 0.36 + leafSag * 0.3]
        let hs: [CGFloat] = [0.78, 0.92, 1, 0.9, 0.76]
        let spikeK = gdEase((g - 0.56) / 0.3)
        let bloomK = gdEase((g - 0.82) / 0.18)
        let purple = p.kind.bloom(p.variant)
        let lk = gdEase((g - 0.14) / 0.3)
        for j in [0, 4, 1, 3] {
            leaf(ctx, at: base, angle: -.pi / 2 + offs[j] * 2.5, length: 28 * lk, width: 4 * lk, color: GRGB(0x8DAE84))
        }
        var deep = Path()
        var pale = Path()
        var glint = Path()
        for j in 0..<5 {
            let st = stem(base: base, height: hgt * hs[j], bend: bend * (0.8 + CGFloat(j) * 0.08) + offs[j])
            drawStem(ctx, st, width: 2.2, color: GRGB(0x7E9F6E))
            guard spikeK > 0 else { continue }
            for b in 0..<9 {
                let t = 0.6 + CGFloat(b) * 0.045
                let q = st.at(min(1, t))
                let r = (2.1 + 2.2 * spikeK) * (1 - CGFloat(b) * 0.04)
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
            ctx.fill(deep, with: .color(GRGB(0x9DB08A).mix(purple.shade(-0.12), k).color))
            ctx.fill(pale, with: .color(GRGB(0x9DB08A).mix(purple.shade(0.08), k).color))
            if bloomK > 0 { ctx.fill(glint, with: .color(.white.opacity(0.28 * Double(bloomK)))) }
        }
    }

    private static func carrotTop(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, pull: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.15 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g, leafSag: leafSag); return }
        if pull > 0.02 { carrotRoot(ctx, p, base: base) }
        let fronds: [CGFloat] = [-0.55 - leafSag * 0.35, -0.3 - leafSag * 0.2, -0.1, 0.12, 0.34 + leafSag * 0.2, 0.58 + leafSag * 0.35]
        let fh: [CGFloat] = [0.7, 0.9, 1, 0.95, 0.85, 0.68]
        for (j, o) in fronds.enumerated() {
            let st = stem(base: base, height: hgt * fh[j], bend: bend + o)
            drawStem(ctx, st, width: 1.9, color: GRGB(0x5E9F3A))
            for b in 0..<6 {
                let t = 0.35 + CGFloat(b) * 0.11
                let q = st.at(t)
                let a = st.angle(t)
                let len = 9 * (1 - CGFloat(b) * 0.08) * gdEase((g - 0.18) / 0.38)
                for side in [-1.0, 1.0] {
                    let aa = a + CGFloat(side) * 0.9
                    var lp = Path()
                    lp.move(to: q)
                    lp.addLine(to: CGPoint(x: q.x + cos(aa) * len, y: q.y + sin(aa) * len))
                    ctx.stroke(lp, with: .color(GRGB(0x6DB548).color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
        }
        let ripe = gdEase((g - 0.82) / 0.18)
        if ripe > 0 && pull <= 0.02 {
            let w = 11 + 11 * ripe
            let r = CGRect(x: base.x - w / 2, y: base.y - 6 * ripe, width: w, height: 10 * ripe + 2)
            ctx.fill(Path(ellipseIn: r), with: .color(p.kind.bloom(p.variant).color))
            ctx.stroke(Path(ellipseIn: r), with: .color(p.kind.bloom(p.variant).shade(-0.4).color(0.6)), lineWidth: 1.2)
            StorybookArt.highlight(ctx, in: r.insetBy(dx: w * 0.25, dy: 1).offsetBy(dx: -2, dy: -1), opacity: 0.35)
        }
    }

    static func carrotRoot(_ ctx: GraphicsContext, _ p: Plant, base: CGPoint) {
        let g = gdEase(CGFloat(p.growth))
        let len = 14 + 54 * g
        let w = 5 + 16 * g
        carrotShape(ctx, top: base, length: len, width: w, angle: 0, tint: p.kind.bloom(p.variant))
    }

    static func carrotShape(_ ctx: GraphicsContext, top: CGPoint, length len: CGFloat, width w: CGFloat, angle: CGFloat, tint: GRGB? = nil) {
        var g = ctx
        g.translateBy(x: top.x, y: top.y)
        g.rotate(by: .radians(Double(angle)))
        var path = Path()
        path.move(to: CGPoint(x: -w / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: 0, y: -w * 0.35))
        path.addCurve(to: CGPoint(x: 0, y: len), control1: CGPoint(x: w * 0.5, y: len * 0.4), control2: CGPoint(x: w * 0.1, y: len * 0.85))
        path.addCurve(to: CGPoint(x: -w / 2, y: 0), control1: CGPoint(x: -w * 0.1, y: len * 0.85), control2: CGPoint(x: -w * 0.5, y: len * 0.4))
        let grad = tint.map { Gradient(colors: [$0.shade(0.2).color, $0.color, $0.shade(-0.3).color]) }
            ?? Gradient(colors: [GRGB(0xFFA24A).color, GRGB(0xF07A1A).color, GRGB(0xC85A10).color])
        g.fill(path, with: .linearGradient(grad, startPoint: CGPoint(x: -w / 2, y: 0), endPoint: CGPoint(x: w / 2, y: 0)))
        g.stroke(path, with: .color((tint?.shade(-0.48) ?? GRGB(0xA8480C)).color(0.75)), lineWidth: 1.4)
        for k in 1..<6 {
            let y = len * CGFloat(k) / 7
            let half = w * 0.5 * (1 - CGFloat(k) / 7.5) * 0.8
            var ring = Path()
            ring.move(to: CGPoint(x: -half, y: y))
            ring.addQuadCurve(to: CGPoint(x: half * 0.3, y: y + 1.5), control: CGPoint(x: -half * 0.3, y: y + 2.5))
            g.stroke(ring, with: .color((tint?.shade(-0.4) ?? GRGB(0xB05410)).color(0.45)), lineWidth: 1)
        }
        StorybookArt.highlight(g, in: CGRect(x: -w * 0.32, y: len * 0.08, width: w * 0.18, height: len * 0.45), opacity: 0.28)
    }

    static func tomatoFruit(_ ctx: GraphicsContext, at p: CGPoint, r: CGFloat, ripe: CGFloat, tint: GRGB? = nil) {
        let green = GRGB(0x86C04A)
        let orange = GRGB(0xF6A23A)
        let red = tint ?? GRGB(0xEE3A2C)
        let c = ripe < 0.5 ? green.mix(orange, ripe * 2) : orange.mix(red, (ripe - 0.5) * 2)
        let rect = CGRect(x: p.x - r * 1.06, y: p.y - r, width: r * 2.12, height: r * 1.95)
        let grad = Gradient(colors: [c.shade(0.3).color, c.color, c.shade(-0.32).color])
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(grad, center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.4),
                                                              startRadius: 0, endRadius: r * 1.5))
        ctx.stroke(Path(ellipseIn: rect), with: .color(c.shade(-0.46).color(0.72)), lineWidth: 1.4)
        StorybookArt.highlight(ctx, in: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.7, width: r * 0.5, height: r * 0.32), opacity: 0.55)
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

    private static func tomato(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        let stake = CGRect(x: base.x + 12, y: base.y - 200, width: 7, height: 204)
        ctx.fill(Path(roundedRect: stake, cornerRadius: 3),
                 with: .linearGradient(Gradient(colors: [GRGB(0xD7A86E).color, GRGB(0xA87444).color]),
                                       startPoint: CGPoint(x: stake.minX, y: 0), endPoint: CGPoint(x: stake.maxX, y: 0)))
        ctx.stroke(Path(roundedRect: stake, cornerRadius: 3), with: .color(StorybookArt.outline(for: 0xA87444)), lineWidth: 1.2)
        let st = stem(base: base, height: hgt, bend: bend * 0.6)
        if g < 0.15 { sprout(ctx, st, g, leafSag: leafSag); return }
        drawStem(ctx, st, width: 3 + 3 * gdEase(g / 0.8), color: GRGB(0x5C9A3C))
        for t in [0.35, 0.65, 0.9] as [CGFloat] where t * hgt > 28 {
            let q = st.at(t)
            var tie = Path()
            tie.move(to: q)
            tie.addLine(to: CGPoint(x: base.x + 15, y: q.y + 2))
            ctx.stroke(tie, with: .color(GRGB(0xEFE3C2).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        let spots: [CGFloat] = [0.18, 0.3, 0.44, 0.56, 0.7, 0.84]
        for (j, t) in spots.enumerated() {
            let k = gdEase((g - 0.14 - CGFloat(j) * 0.07) / 0.22)
            if k <= 0 { continue }
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            let q = st.at(t)
            let a = side < 0 ? CGFloat.pi + 0.45 - leafSag : -0.45 + leafSag
            let len = 36 * k
            let tip = CGPoint(x: q.x + cos(a) * len, y: q.y + sin(a) * len)
            var stalk = Path()
            stalk.move(to: q)
            stalk.addLine(to: tip)
            ctx.stroke(stalk, with: .color(GRGB(0x5C9A3C).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            for b in 0..<3 {
                let bt = 0.4 + CGFloat(b) * 0.3
                let bp = CGPoint(x: q.x + cos(a) * len * bt, y: q.y + sin(a) * len * bt)
                leaf(ctx, at: bp, angle: a - 0.9, length: 14 * k, width: 6.5 * k, color: GRGB(0x5FA445))
                leaf(ctx, at: bp, angle: a + 0.9, length: 14 * k, width: 6.5 * k, color: GRGB(0x569C3E))
            }
            leaf(ctx, at: tip, angle: a, length: 15 * k, width: 7.5 * k, color: GRGB(0x5FA445))
        }
        let flowerK = gdEase((g - 0.58) / 0.1) * (1 - gdEase((g - 0.8) / 0.06))
        let fruitK = gdEase((g - 0.74) / 0.18)
        let ripe = gdEase((g - 0.88) / 0.12)
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
                tomatoFruit(ctx, at: fp, r: 4.5 + 8.5 * fruitK, ripe: ripe, tint: p.kind.bloom(p.variant))
            }
        }
    }

    static func strawberryFruit(_ ctx: GraphicsContext, at p: CGPoint, r: CGFloat, ripe: CGFloat, angle: CGFloat = 0, tint: GRGB? = nil, specialSeeds: Bool = false) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(angle)))
        let c = GRGB(0xE9F2C8).mix(tint ?? GRGB(0xE8263F), ripe)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -r * 0.7))
        path.addCurve(to: CGPoint(x: 0, y: r * 1.25), control1: CGPoint(x: r * 1.4, y: -r * 0.9), control2: CGPoint(x: r * 0.7, y: r * 0.9))
        path.addCurve(to: CGPoint(x: 0, y: -r * 0.7), control1: CGPoint(x: -r * 0.7, y: r * 0.9), control2: CGPoint(x: -r * 1.4, y: -r * 0.9))
        let grad = Gradient(colors: [c.shade(0.28).color, c.color, c.shade(-0.32).color])
        g.fill(path, with: .radialGradient(grad, center: CGPoint(x: -r * 0.3, y: -r * 0.2), startRadius: 0, endRadius: r * 1.6))
        g.stroke(path, with: .color(c.shade(-0.46).color(0.7)), lineWidth: 1.2)
        let seedColor = specialSeeds ? GRGB(0xFFE9A0).mix(GRGB(0xE8263F), ripe) : GRGB(0xFFE9A0).mix(GRGB(0xF6D35B), ripe)
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
        StorybookArt.highlight(g, in: CGRect(x: -r * 0.6, y: -r * 0.3, width: r * 0.4, height: r * 0.28), opacity: 0.48)
    }

    private static func trifoliate(_ ctx: GraphicsContext, at p: CGPoint, angle: CGFloat, size: CGFloat) {
        for o in [-0.75, 0, 0.75] as [CGFloat] {
            leaf(ctx, at: p, angle: angle + o, length: 20 * size, width: 11 * size, color: o == 0 ? GRGB(0x4FA03E) : GRGB(0x479535))
        }
    }

    private static func strawberry(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.15 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g, leafSag: leafSag); return }
        let fruitK = gdEase((g - 0.74) / 0.18)
        let ripe = gdEase((g - 0.88) / 0.12)
        let picked = g >= 1 ? p.kind.crop - p.left : 0
        for (j, s) in berrySpots.enumerated() where fruitK > 0 && j >= picked {
            let fp = CGPoint(x: base.x + s.x + bend * 10, y: base.y - s.y + 8)
            var vine = Path()
            vine.move(to: CGPoint(x: base.x, y: base.y - 20))
            vine.addQuadCurve(to: CGPoint(x: fp.x, y: fp.y - 6), control: CGPoint(x: fp.x * 0.6 + base.x * 0.4, y: base.y - 44))
            ctx.stroke(vine, with: .color(GRGB(0x5C9A3C).color), lineWidth: 1.6)
            strawberryFruit(ctx, at: fp, r: 3.5 + 7 * fruitK, ripe: ripe, angle: s.x > 0 ? -0.25 : 0.25, tint: p.kind.bloom(p.variant), specialSeeds: p.isSpecial)
        }
        let angles: [CGFloat] = [-1.0 - leafSag * 0.3, -0.42 - leafSag * 0.2, 0.12, 0.62 + leafSag * 0.2, 1.05 + leafSag * 0.3]
        let hs: [CGFloat] = [0.66, 0.94, 1, 0.86, 0.6]
        let lk = gdEase((g - 0.14) / 0.38)
        for j in 0..<5 {
            let st = stem(base: base, height: hgt * hs[j], bend: bend + angles[j])
            drawStem(ctx, st, width: 1.9, color: GRGB(0x6AA548))
            if lk > 0 { trifoliate(ctx, at: st.top, angle: st.angle(1), size: 0.55 + 0.45 * lk) }
        }
        let flowerK = gdEase((g - 0.56) / 0.1) * (1 - gdEase((g - 0.78) / 0.06))
        if flowerK > 0 {
            for j in 0..<2 {
                let fp = CGPoint(x: base.x + (j == 0 ? -22 : 24) + bend * 14, y: base.y - hgt * 0.75)
                daisyHead(ctx, at: fp, open: 0.6, color: GRGB(0xFFFFFF), size: 0.55 * flowerK, spin: 0.3)
            }
        }
    }

    static func pumpkinFruit(_ ctx: GraphicsContext, at p: CGPoint, w: CGFloat, ripe: CGFloat, tint: GRGB? = nil, prizeGlow: Bool = false) {
        let c = GRGB(0x77A63E).mix(tint ?? GRGB(0xF78A1E), ripe)
        let hgt = w * 0.74
        if prizeGlow {
            let glowR = w * 0.75
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - glowR, y: p.y - hgt * 0.52 - glowR * 0.75, width: glowR * 2, height: glowR * 1.5)),
                with: .radialGradient(
                    Gradient(colors: [Theme.lemon.opacity(0.42), Theme.lemon.opacity(0)]),
                    center: CGPoint(x: p.x, y: p.y - hgt * 0.52),
                    startRadius: w * 0.2,
                    endRadius: glowR
                )
            )
        }
        let lobes: [CGFloat] = [-0.36, 0.36, -0.14, 0.14, 0]
        let widths: [CGFloat] = [0.5, 0.5, 0.52, 0.52, 0.46]
        for (k, o) in lobes.enumerated() {
            let lw = w * widths[k]
            let rect = CGRect(x: p.x + o * w - lw / 2, y: p.y - hgt, width: lw, height: hgt)
            let shade = k < 2 ? -0.22 : (k < 4 ? -0.08 : 0.06)
            let lc = c.shade(shade)
            let grad = Gradient(colors: [lc.shade(0.25).color, lc.color, lc.shade(-0.28).color])
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(grad, center: CGPoint(x: rect.midX - lw * 0.15, y: rect.minY + hgt * 0.3),
                                                                  startRadius: 0, endRadius: hgt * 0.9))
            ctx.stroke(Path(ellipseIn: rect), with: .color(c.shade(-0.46).color(0.72)), lineWidth: 1.4)
        }
        StorybookArt.highlight(ctx, in: CGRect(x: p.x - w * 0.14, y: p.y - hgt * 0.86, width: w * 0.14, height: hgt * 0.3), opacity: 0.36)
        var st = Path()
        st.move(to: CGPoint(x: p.x - 2, y: p.y - hgt + 3))
        st.addQuadCurve(to: CGPoint(x: p.x + w * 0.1, y: p.y - hgt - w * 0.16), control: CGPoint(x: p.x - 3, y: p.y - hgt - w * 0.12))
        ctx.stroke(st, with: .color(GRGB(0x6B7A35).color), style: StrokeStyle(lineWidth: max(2.4, w * 0.08), lineCap: .round))
        if prizeGlow {
            StorybookArt.sparkle(ctx, at: CGPoint(x: p.x - w * 0.36, y: p.y - hgt * 0.95), radius: 9, color: Theme.lemon, opacity: 0.95)
            StorybookArt.sparkle(ctx, at: CGPoint(x: p.x + w * 0.38, y: p.y - hgt * 0.78), radius: 7, color: .white, opacity: 0.9)
        }
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
        let grad = Gradient(colors: [color.shade(0.15).color, color.color, color.shade(-0.28).color])
        g.fill(path, with: .radialGradient(grad, center: CGPoint(x: -r * 0.3, y: -r * 0.3), startRadius: 0, endRadius: r * 1.3))
        g.stroke(path, with: .color(color.shade(-0.46).color(0.75)), lineWidth: 1.3)
        for i in 0..<5 {
            let a = CGFloat(i) / 5 * 2 * .pi + 0.6
            var v = Path()
            v.move(to: .zero)
            v.addLine(to: CGPoint(x: cos(a) * r * 0.75, y: sin(a) * r * 0.65))
            g.stroke(v, with: .color(color.shade(-0.35).color(0.5)), lineWidth: 1)
        }
    }

    private static func pumpkin(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, time: CGFloat, leafSag: CGFloat) {
        let g = CGFloat(p.growth)
        let hgt = stemHeight(p)
        if g < 0.15 { sprout(ctx, stem(base: base, height: hgt, bend: bend), g, leafSag: leafSag); return }
        let vk = gdEase((g - 0.14) / 0.48)
        for side in [-1.0, 1.0] as [CGFloat] {
            let len = (36 + 52 * vk) * (side < 0 ? 1 : 0.85)
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
                tendril.addLine(to: CGPoint(x: tx + side * (CGFloat(k) * 1.1 + cos(a) * r), y: base.y - 10 + sin(a) * r))
            }
            ctx.stroke(tendril, with: .color(GRGB(0x7DB54F).color), lineWidth: 1.2)
        }
        let leaves: [(CGFloat, CGFloat, CGFloat)] = [(-0.55 - leafSag * 0.3, 0.92, 24), (0.42 + leafSag * 0.3, 0.72, 21), (-0.12, 0.98, 27), (0.85 + leafSag * 0.3, 0.52, 18)]
        for (j, l) in leaves.enumerated() {
            let lk = gdEase((g - 0.14 - CGFloat(j) * 0.08) / 0.3)
            if lk <= 0 { continue }
            let st = stem(base: base, height: hgt * l.1, bend: bend + l.0)
            drawStem(ctx, st, width: 2.2, color: GRGB(0x6AA548))
            lobedLeaf(ctx, at: st.top, r: l.2 * lk, angle: bend * 0.5 + CGFloat(j), color: GRGB(0x58A043))
        }
        let flowerK = gdEase((g - 0.48) / 0.1) * (1 - gdEase((g - 0.72) / 0.06))
        if flowerK > 0 {
            daisyHead(ctx, at: CGPoint(x: base.x - 28, y: base.y - 18), open: 0.5, color: GRGB(0xFFC233), size: 0.85 * flowerK, spin: 0)
        }
        let fruitK = gdEase((g - 0.66) / 0.28)
        let ripe = gdEase((g - 0.86) / 0.14)
        if fruitK > 0 && !(g >= 1 && p.left == 0) {
            let giantScale: CGFloat = p.giant ? (1.52 + 0.03 * sin(time * 4)) : 1.0
            let w = (14 + 54 * fruitK) * giantScale
            pumpkinFruit(ctx, at: CGPoint(x: base.x + 12, y: base.y + 2), w: w, ripe: ripe, tint: p.kind.bloom(p.variant), prizeGlow: p.giant)
        }
    }

    // MARK: Under the soil

    static func drawRoots(_ ctx: GraphicsContext, plant: Plant, base: CGPoint, pull: CGFloat, seed: Int) {
        let g = CGFloat(plant.growth)
        let b = CGPoint(x: base.x, y: base.y - pull * 42)
        if g < 0.2 {
            let k = 1 - gdEase((g - 0.12) / 0.08)
            let sc = plant.kind.seedColor
            let r = CGRect(x: b.x - 4, y: b.y + 10, width: 8, height: 5.5)
            ctx.fill(Path(ellipseIn: r), with: .color(sc.color(Double(k))))
        }
        let n = plant.kind == .carrot ? 3 : 5
        let len = 10 + 52 * gdEase(g / 0.9)
        for i in 0..<n {
            let a = (CGFloat(i) / CGFloat(max(1, n - 1)) - 0.5) * 2.0
            var p = Path()
            p.move(to: CGPoint(x: b.x, y: b.y + 4))
            let end = CGPoint(x: b.x + a * len * 0.6, y: b.y + len * (0.7 + gdRand(i, seed) * 0.3))
            let ctrl = CGPoint(x: b.x + a * len * 0.1 + (gdRand(i, seed + 1) - 0.5) * 14, y: b.y + len * 0.5)
            p.addQuadCurve(to: end, control: ctrl)
            ctx.stroke(p, with: .color(GRGB(0xEFDDB8).color(0.8)), style: StrokeStyle(lineWidth: 1.6 - CGFloat(i % 2) * 0.5, lineCap: .round))
            for k in 1..<4 {
                let q = quad(CGPoint(x: b.x, y: b.y + 4), ctrl, end, CGFloat(k) / 4)
                var hair = Path()
                hair.move(to: q)
                hair.addLine(to: CGPoint(x: q.x + (gdRand(k, i + seed) - 0.5) * 10, y: q.y + 5))
                ctx.stroke(hair, with: .color(GRGB(0xEFDDB8).color(0.5)), lineWidth: 0.7)
            }
        }
        if plant.kind == .carrot && pull <= 0.02 && g >= 0.15 { carrotRoot(ctx, plant, base: b) }
    }

    // MARK: Weeds

    static func drawWeed(_ ctx: GraphicsContext, weed w: GWeed, base: CGPoint, time: CGFloat) {
        let g = gdEase(w.growth)
        var c = ctx
        let lift = w.pull * 24
        c.translateBy(x: base.x, y: base.y - lift)
        c.scaleBy(x: 1 - w.pull * 0.12, y: 1 + w.pull * 0.45)
        if w.pull > 0.02 {
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
            let len = (12 + 28 * g) * (1 - CGFloat(i / 2) * 0.15)
            jaggedLeaf(c, angle: a, length: len, width: 6 + 4 * g)
        }
        if g > 0.75 {
            let k = gdEase((g - 0.75) / 0.25)
            let top = CGPoint(x: sin(w.bend) * 36 * k, y: -36 * k)
            var st = Path()
            st.move(to: .zero)
            st.addQuadCurve(to: top, control: CGPoint(x: 0, y: -18 * k))
            c.stroke(st, with: .color(GRGB(0x7FA645).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            if w.seed % 2 == 0 {
                daisyHead(c, at: top, open: 1, color: GRGB(0xFFD21F), size: 0.48 * k, spin: time * 0.1)
            } else {
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
        g.stroke(p, with: .color(olive.shade(-0.48).color(0.75)), lineWidth: 1.1)
    }

    static func drawWeedRoot(_ ctx: GraphicsContext, weed w: GWeed, base: CGPoint) {
        guard w.pull <= 0.02 else { return }
        let g = gdEase(w.growth)
        var root = Path()
        root.move(to: base)
        root.addQuadCurve(to: CGPoint(x: base.x + 3, y: base.y + 18 + 26 * g), control: CGPoint(x: base.x - 5, y: base.y + 14))
        ctx.stroke(root, with: .color(GRGB(0xD9C29A).color(0.85)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    // MARK: Hybrid Super-Blooms

    static func drawHybrid(
        _ ctx: GraphicsContext,
        hybrid: HybridKind,
        plant p: Plant,
        base: CGPoint,
        bend: CGFloat,
        time: CGFloat,
        leafSag: CGFloat
    ) {
        switch hybrid {
        case .starlightRose:
            starlightRose(ctx, p, base, bend, time, leafSag: leafSag)
        case .cottonSunflower:
            cottonSunflower(ctx, p, base, bend, time, leafSag: leafSag)
        case .moonberryTulip:
            moonberryTulip(ctx, p, base, bend, time, leafSag: leafSag)
        case .rainbowLavender:
            rainbowLavender(ctx, p, base, bend, time, leafSag: leafSag)
        case .crystalPumpkin:
            crystalPumpkin(ctx, p, base, bend, time, leafSag: leafSag)
        case .sparkleBerryVine:
            sparkleBerryVine(ctx, p, base, bend, time, leafSag: leafSag)
        }
    }

    private static func starlightRoseHead(_ ctx: GraphicsContext, at top: CGPoint, angle: CGFloat, scale: CGFloat, time: CGFloat) {
        var g = ctx
        g.translateBy(x: top.x, y: top.y)
        g.rotate(by: .radians(Double(angle)))
        g.scaleBy(x: scale, y: scale)

        let pulse = 0.92 + 0.08 * sin(time * 3.4)
        g.fill(
            Path(ellipseIn: CGRect(x: -44, y: -44, width: 88, height: 88)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE38A, alpha: 0.45 * Double(pulse)), Color(hex: 0xFF88BE, alpha: 0.22), Color(hex: 0xFF88BE, alpha: 0)]),
                center: .zero, startRadius: 6, endRadius: 44
            )
        )

        // Outer star-pointed shimmering pink-gold petals
        for i in 0..<7 {
            var pg = g
            pg.rotate(by: .radians(Double(CGFloat(i) / 7 * 2 * .pi) + Double(sin(time * 1.4 + CGFloat(i)) * 0.03)))
            var petal = Path()
            petal.move(to: .zero)
            petal.addCurve(to: CGPoint(x: 0, y: -35), control1: CGPoint(x: 18, y: -10), control2: CGPoint(x: 14, y: -27))
            petal.addCurve(to: .zero, control1: CGPoint(x: -14, y: -27), control2: CGPoint(x: -18, y: -10))
            petal.closeSubpath()
            let grad = Gradient(colors: [Color(hex: 0xFF5FA2), Color(hex: 0xFF9AC8), Color(hex: 0xFFE58A)])
            pg.fill(petal, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: 0, y: -35)))
            pg.stroke(petal, with: .color(StorybookArt.outline(for: 0xFF6BA8)), lineWidth: 1.5)
        }

        // Inner swirling rose cup
        for i in 0..<5 {
            var pg = g
            pg.rotate(by: .radians(Double(CGFloat(i) / 5 * 2 * .pi + 0.35)))
            var inner = Path()
            inner.move(to: .zero)
            inner.addCurve(to: CGPoint(x: 0, y: -21), control1: CGPoint(x: 13, y: -5), control2: CGPoint(x: 11, y: -18))
            inner.addCurve(to: .zero, control1: CGPoint(x: -11, y: -18), control2: CGPoint(x: -13, y: -5))
            inner.closeSubpath()
            let grad = Gradient(colors: [Color(hex: 0xFF85B8), Color(hex: 0xFFE8A4)])
            pg.fill(inner, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: 0, y: -21)))
            pg.stroke(inner, with: .color(StorybookArt.outline(for: 0xFF9AC8)), lineWidth: 1.3)
        }

        // Golden starlight center jewel
        let core = Path(ellipseIn: CGRect(x: -8.5, y: -8.5, width: 17, height: 17))
        StorybookArt.fillAndStroke(g, core, fill: Color(hex: 0xFFF3A8), stroke: StorybookArt.outline(for: 0xFFC93C), width: 1.8)
        StorybookArt.sparkle(g, at: .zero, radius: 9.5 * pulse, color: .white, opacity: 0.96)
        StorybookArt.sparkle(g, at: CGPoint(x: -22, y: -20), radius: 5.5 * pulse, color: Theme.lemon, opacity: 0.9)
        StorybookArt.sparkle(g, at: CGPoint(x: 24, y: -14), radius: 4.8 * pulse, color: .white, opacity: 0.9)
    }

    private static func starlightRose(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat, leafSag: CGFloat) {
        let hgt = stemHeight(p)
        let st = stem(base: base, height: hgt, bend: bend)
        drawStem(ctx, st, width: 4.4, color: GRGB(0x418E4F))
        for (j, t) in ([0.28, 0.56, 0.76] as [CGFloat]).enumerated() {
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            leaf(ctx, at: st.at(t), angle: st.angle(t) + side * (1.2 + leafSag), length: 34 - CGFloat(j) * 4, width: 13, color: GRGB(0x3F9654), curl: side * 5)
        }
        let open = gdEase((CGFloat(p.growth) - 0.5) / 0.5)
        starlightRoseHead(ctx, at: st.top, angle: bend * 0.7, scale: 0.65 + 0.45 * open, time: time)
    }

    private static func cottonSunflowerHead(_ ctx: GraphicsContext, at top: CGPoint, angle: CGFloat, scale: CGFloat, time: CGFloat) {
        var g = ctx
        g.translateBy(x: top.x, y: top.y)
        g.rotate(by: .radians(Double(angle)))
        g.scaleBy(x: scale, y: scale)

        let pastelHexes: [UInt32] = [0xFFA8D6, 0xFFC59E, 0xFFF099, 0xA8F0D6, 0xA6D8FF, 0xD3B8FF]
        let ringCount = 12
        let haloR: CGFloat = 26
        for i in 0..<ringCount {
            let a = CGFloat(i) / CGFloat(ringCount) * 2 * .pi + sin(time * 1.1 + CGFloat(i)) * 0.04
            let cx = cos(a) * haloR
            let cy = sin(a) * haloR
            let pr: CGFloat = 13.5 + (i % 2 == 0 ? 2.0 : 0)
            let hex = pastelHexes[i % pastelHexes.count]
            let puff = Path(ellipseIn: CGRect(x: cx - pr, y: cy - pr, width: pr * 2, height: pr * 2))
            g.fill(
                puff,
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.95), StorybookArt.color(hex)]),
                    center: CGPoint(x: cx - 3, y: cy - 3), startRadius: 1, endRadius: pr * 1.2
                )
            )
            g.stroke(puff, with: .color(StorybookArt.outline(for: hex, factor: 0.74).opacity(0.7)), lineWidth: 1.5)
        }
        // Soft creamy cotton inner wreath
        let innerWreath = Path(ellipseIn: CGRect(x: -22, y: -22, width: 44, height: 44))
        g.fill(innerWreath, with: .color(Color(hex: 0xFFF9EE, alpha: 0.9)))

        // Happy warm golden-caramel center with cute rosy cheeks
        let diskR: CGFloat = 17.5
        let disk = Path(ellipseIn: CGRect(x: -diskR, y: -diskR, width: diskR * 2, height: diskR * 2))
        g.fill(
            disk,
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE38A), Color(hex: 0xF5B54A), Color(hex: 0xD68830)]),
                center: CGPoint(x: -5, y: -5), startRadius: 0, endRadius: diskR * 1.2
            )
        )
        g.stroke(disk, with: .color(StorybookArt.outline(for: 0xD68830)), lineWidth: 1.8)
        for sx in [-5.5, 5.5] as [CGFloat] {
            g.fill(Path(ellipseIn: CGRect(x: sx - 1.8, y: -4.2, width: 3.6, height: 4.2)), with: .color(Color(hex: 0x4A2E20)))
            g.fill(Path(ellipseIn: CGRect(x: sx - 0.6, y: -3.8, width: 1.4, height: 1.4)), with: .color(.white))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -4, y: 3))
        smile.addQuadCurve(to: CGPoint(x: 4, y: 3), control: CGPoint(x: 0, y: 7.5))
        g.stroke(smile, with: .color(Color(hex: 0x6A3A20)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        g.fill(Path(ellipseIn: CGRect(x: -11.5, y: 0.5, width: 5, height: 3.2)), with: .color(Theme.pink.opacity(0.65)))
        g.fill(Path(ellipseIn: CGRect(x: 6.5, y: 0.5, width: 5, height: 3.2)), with: .color(Theme.pink.opacity(0.65)))
        StorybookArt.sparkle(g, at: CGPoint(x: -26, y: -26), radius: 5.5, color: .white, opacity: 0.95)
        StorybookArt.sparkle(g, at: CGPoint(x: 28, y: -18), radius: 5, color: Theme.lemon, opacity: 0.92)
    }

    private static func cottonSunflower(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat, leafSag: CGFloat) {
        let hgt = stemHeight(p)
        let st = stem(base: base, height: hgt, bend: bend)
        drawStem(ctx, st, width: 7.4, color: GRGB(0x5EB676))
        for (j, t) in ([0.24, 0.44, 0.64, 0.80] as [CGFloat]).enumerated() {
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            let a = st.angle(t) + side * (1.3 + leafSag)
            leaf(ctx, at: st.at(t), angle: a, length: 44 - CGFloat(j) * 4, width: 19, color: GRGB(0x69C286), curl: side * 6)
        }
        cottonSunflowerHead(ctx, at: st.top, angle: bend * 0.55, scale: 1.05, time: time)
    }

    private static func moonberryTulipHead(_ ctx: GraphicsContext, at top: CGPoint, angle: CGFloat, scale: CGFloat, time: CGFloat) {
        var g = ctx
        g.translateBy(x: top.x, y: top.y)
        g.rotate(by: .radians(Double(angle)))
        g.scaleBy(x: scale, y: scale)

        let glowR: CGFloat = 38
        g.fill(
            Path(ellipseIn: CGRect(x: -glowR, y: -glowR - 14, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xC69CFF, alpha: 0.48), Color(hex: 0x7A4BE8, alpha: 0)]),
                center: CGPoint(x: 0, y: -16), startRadius: 4, endRadius: glowR
            )
        )

        let violet = GRGB(0x8852E8)
        let berry = GRGB(0xC854B8)
        tulipPetal(g, at: .zero, angle: 0, height: 42, width: 20, color: violet.shade(-0.14))
        tulipPetal(g, at: .zero, angle: -0.34, height: 39, width: 17, color: berry)
        tulipPetal(g, at: .zero, angle: 0.34, height: 39, width: 17, color: violet.shade(0.14))

        let moon = crescentMoonPath(center: CGPoint(x: 0, y: -25), radius: 8)
        g.fill(moon, with: .color(Color(hex: 0xFFF4B2)))

        // Dripping starlight dew drops
        let dropBob = sin(time * 3.2) * 3
        for (dx, dy) in [(-18.0, -8.0), (18.0, -6.0), (0.0, 4.0)] as [(CGFloat, CGFloat)] {
            let dp = CGPoint(x: dx, y: dy + dropBob * (dx == 0 ? 1 : -0.7))
            var drop = Path()
            drop.move(to: CGPoint(x: dp.x, y: dp.y - 6))
            drop.addCurve(to: CGPoint(x: dp.x, y: dp.y + 5), control1: CGPoint(x: dp.x + 5, y: dp.y), control2: CGPoint(x: dp.x + 5, y: dp.y + 5))
            drop.addCurve(to: CGPoint(x: dp.x, y: dp.y - 6), control1: CGPoint(x: dp.x - 5, y: dp.y + 5), control2: CGPoint(x: dp.x - 5, y: dp.y))
            g.fill(drop, with: .color(Color(hex: 0xE6F6FF, alpha: 0.92)))
            StorybookArt.sparkle(g, at: dp, radius: 4.5, color: Theme.lemon, opacity: 0.95)
        }
    }

    private static func moonberryTulip(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat, leafSag: CGFloat) {
        let hgt = stemHeight(p)
        let st = stem(base: base, height: hgt, bend: bend)
        leaf(ctx, at: CGPoint(x: base.x - 2, y: base.y), angle: -.pi / 2 - 0.42 - leafSag + bend * 0.5, length: 74, width: 13, color: GRGB(0x529A7C), curl: -9)
        drawStem(ctx, st, width: 4.5, color: GRGB(0x4E8E78))
        leaf(ctx, at: CGPoint(x: base.x + 2, y: base.y), angle: -.pi / 2 + 0.4 + leafSag + bend * 0.5, length: 68, width: 12, color: GRGB(0x4B8B72), curl: 9)
        moonberryTulipHead(ctx, at: st.top, angle: bend * 0.75, scale: 1.05, time: time)
    }

    private static func rainbowLavender(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat, leafSag: CGFloat) {
        let hgt = stemHeight(p)
        let offs: [CGFloat] = [-0.36, -0.18, 0, 0.18, 0.36]
        let hs: [CGFloat] = [0.78, 0.92, 1.0, 0.92, 0.78]
        let prism: [GRGB] = [
            GRGB(0xFF7CA8), GRGB(0xFFB36B), GRGB(0xFFE36E), GRGB(0x7FE3A8),
            GRGB(0x78C8FF), GRGB(0xB398FF), GRGB(0xF098FF)
        ]

        // Soft miniature shimmering rainbow arc hovering above the prism stalks
        let arcCenter = CGPoint(x: base.x + sin(bend) * hgt * 0.8, y: base.y - hgt * 0.88)
        let arcAlpha = 0.55 + 0.18 * Double(sin(time * 2.6))
        for (k, col) in prism.prefix(5).enumerated() {
            let rad: CGFloat = 42 - CGFloat(k) * 4.5
            var arc = Path()
            arc.addArc(center: arcCenter, radius: rad, startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
            ctx.stroke(arc, with: .color(col.color(arcAlpha)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
        }

        for j in [0, 4, 1, 3] {
            leaf(ctx, at: base, angle: -.pi / 2 + offs[j] * 2.4, length: 30, width: 4.8, color: GRGB(0x7EC0A2))
        }
        for j in 0..<5 {
            let st = stem(base: base, height: hgt * hs[j], bend: bend * 0.85 + offs[j] + (j < 2 ? -leafSag * 0.2 : leafSag * 0.2))
            drawStem(ctx, st, width: 2.5, color: GRGB(0x6FA888))
            for b in 0..<8 {
                let t = 0.55 + CGFloat(b) * 0.056
                let q = st.at(min(1, t))
                let r = (4.6 - CGFloat(b) * 0.24)
                let col = prism[(b + j) % prism.count]
                for side in [-1.0, 1.0] as [CGFloat] {
                    let cx = q.x + side * r * 0.58
                    let bud = Path(ellipseIn: CGRect(x: cx - r, y: q.y - r, width: r * 2, height: r * 2.15))
                    ctx.fill(bud, with: .color(col.color))
                    ctx.stroke(bud, with: .color(col.shade(-0.38).color(0.55)), lineWidth: 0.9)
                }
            }
        }
        StorybookArt.sparkle(ctx, at: CGPoint(x: arcCenter.x - 28, y: arcCenter.y - 26), radius: 6, color: .white, opacity: 0.95)
        StorybookArt.sparkle(ctx, at: CGPoint(x: arcCenter.x + 26, y: arcCenter.y - 28), radius: 5.5, color: Theme.lemon, opacity: 0.92)
    }

    private static func crystalPumpkinCarriage(_ ctx: GraphicsContext, at p: CGPoint, w: CGFloat, time: CGFloat) {
        let hgt = w * 0.78
        let pulse = 0.9 + 0.1 * sin(time * 3.5)

        // Magical icy fairy aura
        let glowR = w * 0.78
        ctx.fill(
            Path(ellipseIn: CGRect(x: p.x - glowR, y: p.y - hgt * 0.55 - glowR * 0.7, width: glowR * 2, height: glowR * 1.4)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xB8F0FF, alpha: 0.45 * Double(pulse)), Color(hex: 0xD8C6FF, alpha: 0.22), Color(hex: 0xD8C6FF, alpha: 0)]),
                center: CGPoint(x: p.x, y: p.y - hgt * 0.52), startRadius: 6, endRadius: glowR
            )
        )

        // Ornate golden fairytale carriage wheels beneath the crystal pumpkin
        for side in [-1.0, 1.0] as [CGFloat] {
            let wc = CGPoint(x: p.x + side * w * 0.34, y: p.y - w * 0.08)
            let wr = w * 0.19
            let wheel = Path(ellipseIn: CGRect(x: wc.x - wr, y: wc.y - wr, width: wr * 2, height: wr * 2))
            ctx.stroke(wheel, with: .color(Color(hex: 0xF4BE42)), lineWidth: max(2.2, w * 0.04))
            ctx.stroke(wheel, with: .color(StorybookArt.outline(for: 0xF4BE42).opacity(0.65)), lineWidth: 1.0)
            for k in 0..<4 {
                let a = CGFloat(k) * .pi / 4 + time * 0.4
                var sp = Path()
                sp.move(to: CGPoint(x: wc.x - cos(a) * wr, y: wc.y - sin(a) * wr))
                sp.addLine(to: CGPoint(x: wc.x + cos(a) * wr, y: wc.y + sin(a) * wr))
                ctx.stroke(sp, with: .color(Color(hex: 0xFFE38A)), lineWidth: 1.4)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: wc.x - 3, y: wc.y - 3, width: 6, height: 6)), with: .color(Color(hex: 0xFFF3B8)))
        }

        // Faceted crystalline sky-blue & pearl-lavender pumpkin lobes
        let lobes: [CGFloat] = [-0.36, 0.36, -0.15, 0.15, 0]
        let widths: [CGFloat] = [0.48, 0.48, 0.50, 0.50, 0.45]
        let crystalCols: [GRGB] = [GRGB(0x90DCFF), GRGB(0xB8C6FF), GRGB(0xB0ECFF), GRGB(0xD8CCFF), GRGB(0xDCF8FF)]
        for (k, o) in lobes.enumerated() {
            let lw = w * widths[k]
            let rect = CGRect(x: p.x + o * w - lw / 2, y: p.y - hgt - w * 0.06, width: lw, height: hgt)
            let lc = crystalCols[k]
            let grad = Gradient(colors: [.white.opacity(0.92), lc.color(0.92), lc.shade(-0.18).color(0.95)])
            ctx.fill(Path(ellipseIn: rect), with: .linearGradient(grad, startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0x62A8E0, alpha: 0.85)), lineWidth: 1.5)
        }

        // Golden carriage arched window
        let win = Path(roundedRect: CGRect(x: p.x - w * 0.13, y: p.y - hgt * 0.72 - w * 0.06, width: w * 0.26, height: hgt * 0.42), cornerRadius: w * 0.13)
        StorybookArt.fillAndStroke(ctx, win, fill: Color(hex: 0xFFF8D6, alpha: 0.95), stroke: Color(hex: 0xF2B830), width: 2.2)

        // Golden fairytale crown finial on top
        let crownY = p.y - hgt - w * 0.05
        var tiara = Path()
        tiara.move(to: CGPoint(x: p.x - w * 0.16, y: crownY + 2))
        tiara.addLine(to: CGPoint(x: p.x - w * 0.19, y: crownY - w * 0.14))
        tiara.addLine(to: CGPoint(x: p.x - w * 0.06, y: crownY - w * 0.06))
        tiara.addLine(to: CGPoint(x: p.x, y: crownY - w * 0.21))
        tiara.addLine(to: CGPoint(x: p.x + w * 0.06, y: crownY - w * 0.06))
        tiara.addLine(to: CGPoint(x: p.x + w * 0.19, y: crownY - w * 0.14))
        tiara.addLine(to: CGPoint(x: p.x + w * 0.16, y: crownY + 2))
        tiara.closeSubpath()
        StorybookArt.shape(ctx, tiara, hex: 0xFFD95A, width: 1.8)

        StorybookArt.sparkle(ctx, at: CGPoint(x: p.x - w * 0.36, y: p.y - hgt - 2), radius: 7.5 * pulse, color: .white, opacity: 0.96)
        StorybookArt.sparkle(ctx, at: CGPoint(x: p.x + w * 0.34, y: p.y - hgt * 0.78), radius: 6 * pulse, color: Theme.lemon, opacity: 0.95)
    }

    private static func crystalPumpkin(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat, leafSag: CGFloat) {
        let hgt = stemHeight(p)
        let leaves: [(CGFloat, CGFloat, CGFloat)] = [(-0.55 - leafSag * 0.3, 0.92, 23), (0.45 + leafSag * 0.3, 0.74, 20), (-0.12, 0.98, 25)]
        for (j, l) in leaves.enumerated() {
            let st = stem(base: base, height: hgt * l.1, bend: bend + l.0)
            drawStem(ctx, st, width: 2.2, color: GRGB(0x69B8A4))
            lobedLeaf(ctx, at: st.top, r: l.2, angle: bend * 0.5 + CGFloat(j), color: GRGB(0x6AC2B2))
        }
        if !(p.growth >= 1 && p.left == 0) {
            let w: CGFloat = 76 * (p.giant ? 1.24 : 1.0)
            crystalPumpkinCarriage(ctx, at: CGPoint(x: base.x + 8, y: base.y + 4), w: w, time: time)
        }
    }

    private static func goldenHeartBerry(_ ctx: GraphicsContext, at p: CGPoint, size: CGFloat, time: CGFloat) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        let r = size
        var heart = Path()
        heart.move(to: CGPoint(x: 0, y: -r * 0.35))
        heart.addCurve(to: CGPoint(x: r, y: -r * 0.2), control1: CGPoint(x: r * 0.35, y: -r * 1.15), control2: CGPoint(x: r * 1.1, y: -r * 0.85))
        heart.addCurve(to: CGPoint(x: 0, y: r * 1.05), control1: CGPoint(x: r * 0.95, y: r * 0.4), control2: CGPoint(x: r * 0.32, y: r * 0.72))
        heart.addCurve(to: CGPoint(x: -r, y: -r * 0.2), control1: CGPoint(x: -r * 0.32, y: r * 0.72), control2: CGPoint(x: -r * 0.95, y: r * 0.4))
        heart.addCurve(to: CGPoint(x: 0, y: -r * 0.35), control1: CGPoint(x: -r * 1.1, y: -r * 0.85), control2: CGPoint(x: -r * 0.35, y: -r * 1.15))
        heart.closeSubpath()

        let grad = Gradient(colors: [Color(hex: 0xFFF4B8), Color(hex: 0xFFD052), Color(hex: 0xFF7FA8)])
        g.fill(heart, with: .radialGradient(grad, center: CGPoint(x: -r * 0.28, y: -r * 0.32), startRadius: 1, endRadius: r * 1.5))
        g.stroke(heart, with: .color(StorybookArt.outline(for: 0xE68646)), lineWidth: 1.5)
        StorybookArt.highlight(g, in: CGRect(x: -r * 0.56, y: -r * 0.55, width: r * 0.36, height: r * 0.28), opacity: 0.7)

        // Starry leaf cap
        var cap = Path()
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * 2 * .pi
            let rr = i % 2 == 0 ? r * 0.62 : r * 0.22
            let pt = CGPoint(x: cos(a) * rr, y: -r * 0.68 + sin(a) * rr * 0.35)
            if i == 0 { cap.move(to: pt) } else { cap.addLine(to: pt) }
        }
        cap.closeSubpath()
        g.fill(cap, with: .color(GRGB(0x52B256).color))
        let tw = 0.7 + 0.3 * sin(time * 4 + p.x)
        StorybookArt.sparkle(g, at: CGPoint(x: r * 0.55, y: -r * 0.55), radius: r * 0.45 * tw, color: .white, opacity: 0.95)
    }

    private static func sparkleBerryVine(_ ctx: GraphicsContext, _ p: Plant, _ base: CGPoint, _ bend: CGFloat, _ time: CGFloat, leafSag: CGFloat) {
        let hgt = stemHeight(p)
        let stake = CGRect(x: base.x + 12, y: base.y - 188, width: 7, height: 192)
        StorybookArt.shape(ctx, Path(roundedRect: stake, cornerRadius: 3), hex: 0xE2B67A, width: 1.4)
        let st = stem(base: base, height: hgt, bend: bend * 0.6)
        drawStem(ctx, st, width: 4.5, color: GRGB(0x4EA854))

        for (j, t) in ([0.22, 0.42, 0.62, 0.80] as [CGFloat]).enumerated() {
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            let q = st.at(t)
            leaf(ctx, at: q, angle: (side < 0 ? .pi + 0.4 - leafSag : -0.4 + leafSag), length: 30, width: 13, color: GRGB(0x52B45C), curl: side * 5)
        }

        let vineSpots: [CGPoint] = [
            CGPoint(x: -26, y: 126),
            CGPoint(x: 24, y: 98),
            CGPoint(x: -14, y: 66),
        ]
        let picked = p.growth >= 1 ? max(0, HybridKind.sparkleBerryVine.crop - p.left) : 0
        for (j, s) in vineSpots.enumerated() where j >= picked {
            let fp = CGPoint(x: base.x + s.x + sin(bend) * s.y, y: base.y - s.y)
            var tendril = Path()
            tendril.move(to: CGPoint(x: base.x + sin(bend) * s.y * 0.6, y: fp.y - 16))
            tendril.addQuadCurve(to: CGPoint(x: fp.x, y: fp.y - 8), control: CGPoint(x: fp.x, y: fp.y - 18))
            ctx.stroke(tendril, with: .color(GRGB(0x52B256).color), lineWidth: 1.8)
            goldenHeartBerry(ctx, at: fp, size: 15, time: time + CGFloat(j))
        }
    }

    static func drawHybridIcon(_ ctx: GraphicsContext, hybrid: HybridKind, at p: CGPoint, size s: CGFloat, rot: CGFloat = 0, time: CGFloat = 0) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(rot)))
        g.scaleBy(x: s, y: s)
        switch hybrid {
        case .starlightRose:
            starlightRoseHead(g, at: .zero, angle: 0, scale: 0.72, time: time)
        case .cottonSunflower:
            cottonSunflowerHead(g, at: .zero, angle: 0, scale: 0.64, time: time)
        case .moonberryTulip:
            moonberryTulipHead(g, at: CGPoint(x: 0, y: 18), angle: 0, scale: 0.85, time: time)
        case .rainbowLavender:
            let prism: [GRGB] = [GRGB(0xFF7CA8), GRGB(0xFFB36B), GRGB(0xFFE36E), GRGB(0x7FE3A8), GRGB(0x78C8FF), GRGB(0xB398FF)]
            for (k, col) in prism.prefix(4).enumerated() {
                var arc = Path()
                arc.addArc(center: CGPoint(x: 0, y: -4), radius: 24 - CGFloat(k) * 3.5, startAngle: .degrees(205), endAngle: .degrees(335), clockwise: false)
                g.stroke(arc, with: .color(col.color(0.85)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            }
            for b in 0..<6 {
                let y = 10 - CGFloat(b) * 5.2
                let r: CGFloat = 4.2 - CGFloat(b) * 0.25
                let col = prism[b % prism.count]
                for side in [-1.0, 1.0] as [CGFloat] {
                    g.fill(Path(ellipseIn: CGRect(x: side * r * 0.55 - r, y: y - r, width: r * 2, height: r * 2.1)), with: .color(col.color))
                }
            }
            var st = Path()
            st.move(to: CGPoint(x: 0, y: 12))
            st.addLine(to: CGPoint(x: 0, y: 24))
            g.stroke(st, with: .color(GRGB(0x6FA888).color), lineWidth: 2.2)
        case .crystalPumpkin:
            crystalPumpkinCarriage(g, at: CGPoint(x: 0, y: 18), w: 46, time: time)
        case .sparkleBerryVine:
            goldenHeartBerry(g, at: CGPoint(x: 0, y: 2), size: 17, time: time)
        }
    }

    // MARK: Picked crops & bouquet flowers

    static func drawBouquetStem(
        _ ctx: GraphicsContext,
        kind: PlantKind,
        variant: Int,
        angle: CGFloat,
        stemLength: CGFloat,
        hybrid: HybridKind? = nil,
        time: CGFloat = 0
    ) {
        var g = ctx
        g.rotate(by: .radians(Double(angle)))
        let st = stem(base: .zero, height: stemLength, bend: angle * 0.18)
        drawStem(g, st, width: 3.2, color: stemGreen)
        leaf(g, at: st.at(0.45), angle: -.pi / 2 + (angle >= 0 ? 0.65 : -0.65), length: 18, width: 6, color: leafGreen)
        let head = st.top
        if let hybrid {
            drawHybridIcon(g, hybrid: hybrid, at: head, size: 0.72, rot: 0, time: time)
            return
        }
        switch kind {
        case .sunflower:
            var hg = g
            hg.translateBy(x: head.x, y: head.y)
            hg.scaleBy(x: 0.56, y: 0.56)
            sunflowerHead(hg, at: .zero, angle: 0, budK: 1, open: 1, petal: kind.bloom(variant), time: 0)
        case .tulip:
            let c = kind.bloom(variant)
            tulipPetal(g, at: head, angle: 0, height: 28, width: 14, color: c.shade(-0.18))
            tulipPetal(g, at: head, angle: -0.28, height: 26, width: 12, color: c)
            tulipPetal(g, at: head, angle: 0.28, height: 26, width: 12, color: c.shade(0.05))
        case .daisy:
            daisyHead(g, at: head, open: 1, color: kind.bloom(variant), size: 0.92, spin: angle)
        case .lavender:
            drawCrop(g, kind: .lavender, variant: variant, at: CGPoint(x: head.x, y: head.y + 6), size: 0.9, rot: 0)
        default:
            drawCrop(g, kind: kind, variant: variant, at: head, size: 0.72, rot: 0)
        }
    }

    static func drawCrop(_ ctx: GraphicsContext, kind: PlantKind, variant: Int, at p: CGPoint, size s: CGFloat, rot: CGFloat, giant: Bool = false) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .radians(Double(rot)))
        let isSpecial = variant >= Plant.specialVariant
        let col = kind.bloom(variant)
        switch kind {
        case .tomato:
            tomatoFruit(g, at: .zero, r: 13 * s, ripe: 1, tint: col)
        case .strawberry:
            strawberryFruit(g, at: .zero, r: 11 * s, ripe: 1, tint: col, specialSeeds: isSpecial)
        case .pumpkin:
            let gScale: CGFloat = giant ? 1.32 : 1
            pumpkinFruit(g, at: CGPoint(x: 0, y: 20 * s * gScale), w: 48 * s * gScale, ripe: 1, tint: col, prizeGlow: giant)
        case .carrot:
            for o in [-0.4, 0, 0.4] as [CGFloat] {
                leaf(g, at: CGPoint(x: 0, y: -18 * s), angle: -.pi / 2 + o, length: 18 * s, width: 4 * s, color: GRGB(0x6DB548))
            }
            carrotShape(g, top: CGPoint(x: 0, y: -18 * s), length: 46 * s, width: 15 * s, angle: 0, tint: col)
        case .sunflower:
            var hg = g
            hg.scaleBy(x: s * 0.62, y: s * 0.62)
            sunflowerHead(hg, at: .zero, angle: 0, budK: 1, open: 1, petal: col, time: 0)
        case .tulip:
            tulipPetal(g, at: CGPoint(x: 0, y: 14 * s), angle: 0, height: 34 * s, width: 18 * s, color: col.shade(-0.18))
            tulipPetal(g, at: CGPoint(x: 0, y: 14 * s), angle: -0.3, height: 32 * s, width: 15 * s, color: col)
            tulipPetal(g, at: CGPoint(x: 0, y: 14 * s), angle: 0.3, height: 32 * s, width: 15 * s, color: col.shade(0.04))
        case .daisy:
            daisyHead(g, at: .zero, open: 1, color: col, size: 1.1 * s, spin: 0)
        case .lavender:
            for b in 0..<7 {
                let y = -CGFloat(b) * 5 * s
                let r = 3.6 * s * (1 - CGFloat(b) * 0.06)
                for side in [-1.0, 1.0] as [CGFloat] {
                    g.fill(Path(ellipseIn: CGRect(x: side * r * 0.5 - r, y: y - r, width: r * 2, height: r * 2.2)),
                           with: .color(col.shade(b % 2 == 0 ? -0.1 : 0.08).color))
                }
            }
            var st = Path()
            st.move(to: CGPoint(x: 0, y: 2))
            st.addLine(to: CGPoint(x: 0, y: 20 * s))
            g.stroke(st, with: .color(GRGB(0x7E9F6E).color), lineWidth: 2)
        }
    }

    static func drawHarvestItem(_ ctx: GraphicsContext, item: HarvestItem, at p: CGPoint, size s: CGFloat, rot: CGFloat = 0, time: CGFloat = 0) {
        switch item.source {
        case .plant(let kind, let variant, let isGiant):
            drawCrop(ctx, kind: kind, variant: variant, at: p, size: s, rot: rot, giant: isGiant)
        case .hybrid(let hybrid, let isGiant):
            let scale = s * (isGiant ? 1.16 : 1.0)
            if isGiant {
                let r = 28 * scale
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Theme.lemon.opacity(0.45), Theme.lemon.opacity(0)]),
                        center: p,
                        startRadius: 4,
                        endRadius: r
                    )
                )
            }
            drawHybridIcon(ctx, hybrid: hybrid, at: p, size: scale, rot: rot, time: time)
        }
    }

    static func drawBouquetItem(_ ctx: GraphicsContext, item: HarvestItem, angle: CGFloat, stemLength: CGFloat, time: CGFloat = 0) {
        switch item.source {
        case .plant(let kind, let variant, _):
            drawBouquetStem(ctx, kind: kind, variant: variant, angle: angle, stemLength: stemLength, hybrid: nil, time: time)
        case .hybrid(let hybrid, _):
            drawBouquetStem(ctx, kind: hybrid.parents.0, variant: 0, angle: angle, stemLength: stemLength, hybrid: hybrid, time: time)
        }
    }

    static func drawRequirement(_ ctx: GraphicsContext, requirement: HarvestRequirement, at p: CGPoint, size s: CGFloat, time: CGFloat = 0) {
        switch requirement {
        case .species(let kind):
            let scale: CGFloat = kind == .pumpkin ? 0.56 * s : 0.78 * s
            drawCrop(ctx, kind: kind, variant: 0, at: p, size: scale, rot: kind == .carrot ? 0.3 : 0)
        case .anyFlower:
            drawCrop(ctx, kind: .daisy, variant: 1, at: CGPoint(x: p.x - 6 * s, y: p.y + 3 * s), size: 0.62 * s, rot: -0.2)
            drawCrop(ctx, kind: .tulip, variant: 0, at: CGPoint(x: p.x + 7 * s, y: p.y - 2 * s), size: 0.64 * s, rot: 0.2)
        case .anyFruitOrVeggie:
            drawCrop(ctx, kind: .strawberry, variant: 0, at: CGPoint(x: p.x - 7 * s, y: p.y + 3 * s), size: 0.72 * s, rot: -0.18)
            drawCrop(ctx, kind: .tomato, variant: 0, at: CGPoint(x: p.x + 8 * s, y: p.y - 1 * s), size: 0.64 * s, rot: 0)
        case .anyHybrid:
            drawHybridIcon(ctx, hybrid: .starlightRose, at: p, size: 0.72 * s, rot: 0, time: time)
            StorybookArt.sparkle(ctx, at: CGPoint(x: p.x + 12 * s, y: p.y - 12 * s), radius: 5 * s, color: Theme.lemon, opacity: 0.95)
        }
    }
}
