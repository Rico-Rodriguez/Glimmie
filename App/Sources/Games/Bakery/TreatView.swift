import SwiftUI

// MARK: - Drawing a treat
//
// Every treat lives on a 600 x 600 stage (plate bottom near y 532). TreatPainter draws it into a
// GraphicsContext that is already in stage coordinates.

enum TreatPainter {
    static var art: BakeryArt { BakeryArt.shared }

    static func flavor(_ i: Int) -> Flavor { BakeryPalette.flavors[clamp(i, BakeryPalette.flavors.count)] }
    static func frosting(_ i: Int) -> RGB { BakeryPalette.frostings[clamp(i, BakeryPalette.frostings.count)] }
    static func liner(_ i: Int) -> RGB { BakeryPalette.liners[clamp(i, BakeryPalette.liners.count)] }
    static func candy(_ i: Int) -> RGB { BakeryPalette.candy[clamp(i, BakeryPalette.candy.count)] }
    static func sauce(_ i: Int) -> RGB { BakeryPalette.sauces[clamp(i, BakeryPalette.sauces.count)] }
    static func clamp(_ i: Int, _ n: Int) -> Int { max(0, min(n - 1, i)) }

    /// - frostMask: while she spreads cake or bungeoppang frosting, only the frosting under these spatula
    ///   strokes shows (`maskFade` fades the rest in once it's spread).
    /// - pipe: 0...1 of the next cupcake ring being piped around.
    /// - sauceReveal: 0...1 of the ice cream sauce running down from the top.
    /// - ages: seconds since each topping landed, for the little drop-and-bounce.
    static func draw(_ t: Treat, in ctx: GraphicsContext, frostMask: [[CGPoint]]? = nil, maskFade: Double = 0,
                     pipe: CGFloat = 0, sauceReveal: CGFloat = 1, plate: Bool = true,
                     ages: [UUID: Double] = [:], hidden: UUID? = nil) {
        switch t.kind {
        case .cake:
            if plate { art.draw("plate", in: ctx) }
            let n = max(1, min(3, t.tiers))
            let strokes = t.swooshPoints
            for i in 0..<n {
                art.draw("cake_body\(i)", flavor(t.flavor).color, in: ctx)
                if let fr = t.frosting {
                    drawFrosting(tier: i, color: frosting(fr), mask: frostMask, fade: maskFade, swoosh: strokes, in: ctx)
                }
            }
            if t.freshCreamCrown == true, let fr = t.frosting {
                let alpha = frostMask == nil ? 1.0 : maskFade
                if alpha > 0.02 {
                    var cg = ctx
                    cg.opacity = alpha
                    drawKoreanStrawberryCreamCrown(tiers: n, color: frosting(fr), in: cg)
                }
            }
        case .cupcake:
            if plate { art.draw("plate", in: ctx) }
            art.draw("liner", liner(t.liner), in: ctx)
            art.draw("cupcake_top", baked(flavor(t.flavor).color, 1), in: ctx)
            if let fr = t.frosting, t.frostStage > 0 {
                art.draw("frost_\(t.frostStyle)\(min(3, t.frostStage))", frosting(fr), in: ctx)
            }
            if let fr = t.frosting, pipe > 0, t.frostStage < 3 {
                let next = t.frostStage + 1
                var g = ctx
                g.clip(to: Piping.wedge(style: t.frostStyle, stage: next, f: pipe))
                art.draw("frost_\(t.frostStyle)\(next)", frosting(fr), in: g)
            }
        case .bungeoppang:
            if plate { art.draw("plate", in: ctx) }
            BungeoppangArt.draw(t, frostMask: frostMask, maskFade: maskFade, in: ctx)
        case .iceCream:
            var shadow = ctx
            shadow.opacity = 0.18
            shadow.fill(Path(ellipseIn: CGRect(x: 230, y: 576, width: 140, height: 22)), with: .color(Theme.ink))
            art.draw("cone_\(t.cone)", liner(t.liner), in: ctx)
            for (k, s) in t.scoops.prefix(4).enumerated() {
                let p = CGPoint(x: 300, y: art.scoopY0 - CGFloat(k) * art.scoopDY)
                let flavors = BakeryPalette.scoopFlavors
                let fl = flavors[clamp(s, flavors.count)]
                art.draw("scoop", fl.color, at: p, in: ctx)
                if fl.chips == 1 { art.draw("scoop_chips", fl.color, at: p, in: ctx) }
                if fl.chips == 2 { art.draw("scoop_bits", fl.color, at: p, in: ctx) }
            }
            if let sc = t.sauce, !t.scoops.isEmpty, sauceReveal > 0 {
                let p = CGPoint(x: 300, y: art.scoopY0 - CGFloat(min(4, t.scoops.count) - 1) * art.scoopDY)
                var g = ctx
                if sauceReveal < 1 {
                    // the sauce runs down from the top of the scoop
                    g.clip(to: Path(CGRect(x: p.x - 130, y: p.y - 104, width: 260, height: 162 * sauceReveal)))
                }
                art.draw("sauce", sauce(sc), at: p, in: g)
            }
        }
        for tp in t.toppings where tp.id != hidden {
            var s = CGFloat(tp.scale)
            var y = CGFloat(tp.y)
            if let age = ages[tp.id], age < 0.8 {
                let a = CGFloat(age)
                if a < 0.18 { y -= 140 * pow(1 - a / 0.18, 2) }
                s *= 1 + 0.3 * sin(min(1, a / 0.6) * .pi * 3) * exp(-a * 5)
            }
            art.draw(tp.sprite, candy(tp.color), at: CGPoint(x: CGFloat(tp.x), y: y), scale: s, rotation: tp.rot, in: ctx)
        }
    }

    // MARK: Korean Strawberry Fresh-Cream Cake

    static let strawberryCrownTreasureID = "bakery/strawberryCrown"
    static var hasStrawberryCrown: Bool { Coins.shared.owns(strawberryCrownTreasureID) }

    private static func drawKoreanStrawberryCreamCrown(tiers n: Int, color: RGB, in ctx: GraphicsContext) {
        // Fluffy fresh whipped cream tint (stays airy white-pastel even with colored frosting picks)
        let cream = color.mix(RGB(1, 1, 1), 0.55)
        let creamOutline = Shades.outline(cream).color.opacity(0.65)
        let creamShade = Shades.shade(cream).color.opacity(0.35)

        for i in 0..<n {
            let g = art.tiers[i]
            // Fresh sliced strawberries peeking along the middle fresh-cream sponge seam
            let seamY = (g.t + g.b) * 0.5 + g.ry * 0.55
            let peekCount = i == 0 ? 5 : i == 1 ? 4 : 3
            for k in 0..<peekCount {
                let u = CGFloat(k + 1) / CGFloat(peekCount + 1)
                let a = CGFloat.pi * (0.14 + 0.72 * u)
                let sx = 300 + cos(a) * g.hw * 0.84
                let sy = seamY + sin(a) * g.ry * 0.42
                drawSlicedStrawberry(in: ctx, at: CGPoint(x: sx, y: sy), scale: i == 0 ? 0.62 : 0.54, tilt: Double((u - 0.5) * 18))
            }

            // Fluffy whipped cream rosettes ringing the top edge
            let puffCount = i == 0 ? 11 : i == 1 ? 9 : 7
            let puffR: CGFloat = i == 0 ? 18 : i == 1 ? 16 : 14
            for k in 0..<puffCount {
                let u = CGFloat(k) / CGFloat(max(1, puffCount - 1))
                let a = CGFloat.pi * (0.06 + 0.88 * u)
                let px = 300 + cos(a) * (g.hw - 8)
                let py = g.t + sin(a) * (g.ry - 2) - 4
                let base = Path(ellipseIn: CGRect(x: px - puffR, y: py - puffR * 0.76, width: puffR * 2, height: puffR * 1.52))
                ctx.fill(base, with: .color(cream.color))
                ctx.stroke(base, with: .color(creamOutline), lineWidth: 2.8)
                var peak = Path()
                peak.move(to: CGPoint(x: px - puffR * 0.55, y: py - puffR * 0.1))
                peak.addCurve(to: CGPoint(x: px + puffR * 0.55, y: py - puffR * 0.1),
                              control1: CGPoint(x: px - puffR * 0.3, y: py - puffR * 1.15),
                              control2: CGPoint(x: px + puffR * 0.45, y: py - puffR * 1.05))
                peak.closeSubpath()
                ctx.fill(peak, with: .color(cream.color))
                ctx.stroke(peak, with: .color(creamShade), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                StorybookArt.highlight(ctx, in: CGRect(x: px - puffR * 0.45, y: py - puffR * 0.52, width: puffR * 0.55, height: puffR * 0.35), opacity: 0.8)
            }
        }

        // Crown of glossy sliced strawberries nestled in cream puffs on the topmost tier
        let top = art.tiers[n - 1]
        let crownCount = n == 1 ? 6 : 5
        for k in 0..<crownCount {
            let a = CGFloat(k) / CGFloat(crownCount) * 2 * .pi - .pi / 2
            let rx = top.hw * 0.64
            let ry = top.ry * 0.62
            let p = CGPoint(x: 300 + cos(a) * rx, y: top.t - 10 + sin(a) * ry)
            drawSlicedStrawberry(in: ctx, at: p, scale: n == 3 ? 0.78 : 0.92, tilt: Double(cos(a) * 16))
        }
        // Tiny mint sprigs accenting the strawberry crown
        for side in [-1.0, 1.0] as [CGFloat] {
            var leaf = Path()
            let lx = 300 + side * top.hw * 0.34
            let ly = top.t - 18
            leaf.move(to: CGPoint(x: lx, y: ly + 6))
            leaf.addQuadCurve(to: CGPoint(x: lx + side * 22, y: ly - 10), control: CGPoint(x: lx + side * 6, y: ly - 12))
            leaf.addQuadCurve(to: CGPoint(x: lx, y: ly + 6), control: CGPoint(x: lx + side * 18, y: ly + 6))
            leaf.closeSubpath()
            StorybookArt.fillAndStroke(ctx, leaf, fill: StorybookArt.color(0x63C978), stroke: StorybookArt.outline(for: 0x45A85C), width: 2.2)
        }

        if hasStrawberryCrown {
            drawStrawberryTiaraCrown(at: CGPoint(x: 300, y: top.t - 26), scale: n == 3 ? 0.86 : 1.0, in: ctx)
        }
    }

    private static func drawStrawberryTiaraCrown(at center: CGPoint, scale: CGFloat, in ctx: GraphicsContext) {
        let goldOutline = StorybookArt.outline(for: 0xD9961E)

        var g = ctx
        g.translateBy(x: center.x, y: center.y)
        g.scaleBy(x: scale, y: scale)

        // Warm golden starlight halo behind the jeweled berry tiara
        g.fill(
            Path(ellipseIn: CGRect(x: -54, y: -52, width: 108, height: 68)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF3A8, alpha: 0.62), Color(hex: 0xFFCF4A, alpha: 0)]),
                center: CGPoint(x: 0, y: -18),
                startRadius: 4,
                endRadius: 52
            )
        )

        // Delicate curved golden filigree tiara crown
        var tiara = Path()
        tiara.move(to: CGPoint(x: -36, y: 2))
        tiara.addLine(to: CGPoint(x: -40, y: -22))
        tiara.addQuadCurve(to: CGPoint(x: -16, y: -10), control: CGPoint(x: -28, y: -8))
        tiara.addLine(to: CGPoint(x: 0, y: -38))
        tiara.addLine(to: CGPoint(x: 16, y: -10))
        tiara.addQuadCurve(to: CGPoint(x: 40, y: -22), control: CGPoint(x: 28, y: -8))
        tiara.addLine(to: CGPoint(x: 36, y: 2))
        tiara.addQuadCurve(to: CGPoint(x: -36, y: 2), control: CGPoint(x: 0, y: 10))
        tiara.closeSubpath()
        g.fill(
            tiara,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF5B2), Color(hex: 0xFFCF4A), Color(hex: 0xE59B20)]),
                startPoint: CGPoint(x: -36, y: -38),
                endPoint: CGPoint(x: 36, y: 10)
            )
        )
        g.stroke(tiara, with: .color(goldOutline), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))

        // Pearl tips + ruby berry gem centerpiece
        for (px, py) in [(-40.0, -24.0), (0.0, -40.0), (40.0, -24.0)] as [(CGFloat, CGFloat)] {
            StorybookArt.fillAndStroke(
                g,
                Path(ellipseIn: CGRect(x: px - 4.5, y: py - 4.5, width: 9, height: 9)),
                fill: Color(hex: 0xFFFDF8),
                stroke: goldOutline,
                width: 1.8
            )
        }
        drawSlicedStrawberry(in: g, at: CGPoint(x: 0, y: -12), scale: 0.56, tilt: 0)

        for gx in [-22.0, 22.0] as [CGFloat] {
            StorybookArt.fillAndStroke(
                g,
                Path(ellipseIn: CGRect(x: gx - 4.5, y: -8, width: 9, height: 9)),
                fill: Theme.pink,
                stroke: goldOutline,
                width: 1.6
            )
        }

        // Sparkling golden star glints around the tiara
        StorybookArt.sparkle(g, at: CGPoint(x: -44, y: -36), radius: 10, color: Color(hex: 0xFFF29C), opacity: 0.95)
        StorybookArt.sparkle(g, at: CGPoint(x: 44, y: -34), radius: 9, color: .white, opacity: 0.92)
        StorybookArt.sparkle(g, at: CGPoint(x: 18, y: -44), radius: 7.5, color: Theme.pink, opacity: 0.9)
    }

    static func drawSlicedStrawberry(in ctx: GraphicsContext, at c: CGPoint, scale: CGFloat, tilt: Double) {
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        g.rotate(by: .degrees(tilt))
        g.scaleBy(x: scale, y: scale)

        // Plump glossy ruby strawberry half
        var berry = Path()
        berry.move(to: CGPoint(x: 0, y: -22))
        berry.addCurve(to: CGPoint(x: 20, y: 2), control1: CGPoint(x: 13, y: -20), control2: CGPoint(x: 22, y: -8))
        berry.addCurve(to: CGPoint(x: 0, y: 18), control1: CGPoint(x: 18, y: 14), control2: CGPoint(x: 8, y: 19))
        berry.addCurve(to: CGPoint(x: -20, y: 2), control1: CGPoint(x: -8, y: 19), control2: CGPoint(x: -18, y: 14))
        berry.addCurve(to: CGPoint(x: 0, y: -22), control1: CGPoint(x: -22, y: -8), control2: CGPoint(x: -13, y: -20))
        berry.closeSubpath()

        g.fill(berry, with: .radialGradient(
            Gradient(colors: [StorybookArt.color(0xFF5D78), StorybookArt.color(0xE82D4E), StorybookArt.color(0xC21D3D)]),
            center: CGPoint(x: -5, y: -6), startRadius: 2, endRadius: 26
        ))
        g.stroke(berry, with: .color(StorybookArt.outline(for: 0xC21D3D)), lineWidth: 2.8)

        // Fresh pale-pink strawberry slice heart inside
        var heart = Path()
        heart.move(to: CGPoint(x: 0, y: -11))
        heart.addCurve(to: CGPoint(x: 9, y: 2), control1: CGPoint(x: 6, y: -9), control2: CGPoint(x: 10, y: -3))
        heart.addCurve(to: CGPoint(x: 0, y: 11), control1: CGPoint(x: 8, y: 8), control2: CGPoint(x: 3, y: 11))
        heart.addCurve(to: CGPoint(x: -9, y: 2), control1: CGPoint(x: -3, y: 11), control2: CGPoint(x: -8, y: 8))
        heart.addCurve(to: CGPoint(x: 0, y: -11), control1: CGPoint(x: -10, y: -3), control2: CGPoint(x: -6, y: -9))
        heart.closeSubpath()
        g.fill(heart, with: .color(StorybookArt.color(0xFFD9E2).opacity(0.92)))
        g.fill(Path(ellipseIn: CGRect(x: -4, y: -3, width: 8, height: 9)), with: .color(.white.opacity(0.85)))

        // Tiny golden seeds
        for (sx, sy) in [(-11.0, -4.0), (11.0, -4.0), (-12.0, 6.0), (12.0, 6.0), (0.0, 14.0)] as [(CGFloat, CGFloat)] {
            g.fill(Path(ellipseIn: CGRect(x: sx - 1.5, y: sy - 2, width: 3, height: 4)), with: .color(StorybookArt.color(0xFFE690)))
        }
        // Glossy jelly highlight
        StorybookArt.highlight(g, in: CGRect(x: -12, y: -14, width: 8, height: 5), opacity: 0.78)
    }

    // MARK: Frosting

    /// How wide the spatula spreads (stage units): well past her fingertip.
    static let spreadBrush: CGFloat = 68

    /// Cake baked a touch golden (cupcake tops; 0 = raw batter color, 1 = out of the oven).
    static func baked(_ c: RGB, _ k: CGFloat) -> RGB { c.mix(RGB(hex: "#C9803F"), 0.16 * Double(k)) }

    static func polyline(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: f)
        if pts.count == 1 { p.addLine(to: CGPoint(x: f.x + 0.5, y: f.y)) }
        for q in pts.dropFirst() { p.addLine(to: q) }
        return p
    }

    static func drawFrosting(tier i: Int, color: RGB, mask: [[CGPoint]]?, fade: Double, swoosh: [[CGPoint]], in ctx: GraphicsContext) {
        let name = "cake_frost\(i)"
        if let m = mask, fade < 1 {
            if fade > 0 {
                var f = ctx
                f.opacity = fade
                art.draw(name, color, in: f)
            }
            ctx.drawLayer { l in
                let style = StrokeStyle(lineWidth: spreadBrush * 2, lineCap: .round, lineJoin: .round)
                for s in m { l.stroke(polyline(s), with: .color(.black), style: style) }
                l.blendMode = .sourceIn
                l.drawLayer { inner in art.draw(name, color, in: inner) }
            }
        } else {
            art.draw(name, color, in: ctx)
        }
        guard !swoosh.isEmpty, let main = art.sprites[name]?.first?.path else { return }
        var c = ctx
        c.clip(to: main)
        drawSwooshTexture(swoosh, color, in: c)
    }

    /// The ridges and shine a spatula leaves in soft frosting.
    static func drawSwooshTexture(_ strokes: [[CGPoint]], _ color: RGB, in ctx: GraphicsContext) {
        let r = spreadBrush
        let shade = Shades.shade(color).color
        let light = Shades.light(color).color
        let round = StrokeStyle(lineWidth: 2 * r - 8, lineCap: .round, lineJoin: .round)
        for s in strokes where s.count > 1 {
            let line = polyline(s)
            var e = ctx
            e.opacity = 0.3
            e.stroke(line.strokedPath(round), with: .color(shade), lineWidth: 2.5)
            e.opacity = 0.22
            e.stroke(line.applying(CGAffineTransform(translationX: 0, y: r * 0.42)), with: .color(shade),
                     style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            e.opacity = 0.5
            e.stroke(line.applying(CGAffineTransform(translationX: -2, y: -r * 0.3)), with: .color(light),
                     style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: Where toppings go

    /// A random spot on the treat's top for a new topping.
    static func randomSpot(on t: Treat) -> CGPoint {
        let r = CGFloat.random(in: 0...1), a = CGFloat.random(in: 0...(2 * .pi))
        switch t.kind {
        case .cake:
            let n = max(1, min(3, t.tiers))
            let i = n == 1 || Int.random(in: 0..<3) > 0 ? n - 1 : Int.random(in: 0..<(n - 1))
            let g = art.tiers[i]
            if i == n - 1 {
                let k = sqrt(r) * 0.78
                return CGPoint(x: 300 + cos(a) * g.hw * k, y: g.t - 8 + sin(a) * g.ry * k)
            }
            // a lower tier: its front ledge
            let upper = art.tiers[i + 1]
            let ang = CGFloat.random(in: 0.25...(CGFloat.pi - 0.25))
            let rad = (upper.hw + g.hw) / 2
            return CGPoint(x: 300 + cos(ang) * rad, y: g.t - 6 + sin(ang) * g.ry * 0.9)
        case .cupcake:
            let top: CGFloat = t.frostStage == 0 ? 352 : [352, 340, 296, 256][min(3, t.frostStage)]
            let hw: CGFloat = t.frostStage == 0 ? 90 : [90, 110, 86, 62][min(3, t.frostStage)]
            let k = sqrt(r)
            return CGPoint(x: 300 + cos(a) * hw * k, y: top + 18 + sin(a) * 30 * k)
        case .bungeoppang:
            let k = sqrt(r)
            return CGPoint(x: 300 + cos(a) * 120 * k, y: 392 + sin(a) * 56 * k)
        case .iceCream:
            if t.scoops.isEmpty { return CGPoint(x: 300 + cos(a) * 80 * r, y: 404) }
            let cy = art.scoopY0 - CGFloat(min(4, t.scoops.count) - 1) * art.scoopDY
            let k = sqrt(r)
            return CGPoint(x: 300 + cos(a) * 66 * k, y: cy - 40 + sin(a) * 34 * k)
        }
    }

    /// The topmost point of the treat (for bites and sparkles).
    static func topY(_ t: Treat) -> CGFloat {
        switch t.kind {
        case .cake: return art.tiers[max(0, min(2, t.tiers - 1))].t - 30
        case .cupcake: return t.frostStage >= 3 ? 220 : 300
        case .bungeoppang: return 282
        case .iceCream: return art.scoopY0 - CGFloat(max(0, min(4, t.scoops.count) - 1)) * art.scoopDY - 90
        }
    }
}

// MARK: - Bungeoppang (Korean Fish-Shaped Waffle Pastry) Art

enum BungeoppangArt {
    static let goldenTreasureID = "bakery/goldenBungeo"
    static var hasGoldenMold: Bool { Coins.shared.owns(goldenTreasureID) }

    /// Fish waffle silhouette in 600 x 600 stage space (centered near 300, 396).
    static func bodyPath() -> Path {
        var p = Path()
        // Smiling snout on the left
        p.move(to: CGPoint(x: 112, y: 398))
        // Upper head & plump arched back
        p.addCurve(to: CGPoint(x: 268, y: 300), control1: CGPoint(x: 122, y: 334), control2: CGPoint(x: 192, y: 298))
        p.addCurve(to: CGPoint(x: 404, y: 368), control1: CGPoint(x: 334, y: 302), control2: CGPoint(x: 376, y: 334))
        // Scalloped 3-lobe fanned tail fin
        p.addCurve(to: CGPoint(x: 484, y: 322), control1: CGPoint(x: 432, y: 344), control2: CGPoint(x: 468, y: 306))
        p.addCurve(to: CGPoint(x: 472, y: 396), control1: CGPoint(x: 496, y: 342), control2: CGPoint(x: 486, y: 374))
        p.addCurve(to: CGPoint(x: 482, y: 466), control1: CGPoint(x: 490, y: 422), control2: CGPoint(x: 494, y: 450))
        p.addCurve(to: CGPoint(x: 404, y: 426), control1: CGPoint(x: 464, y: 482), control2: CGPoint(x: 432, y: 452))
        // Rounded plump belly returning to smiling open mouth edge
        p.addCurve(to: CGPoint(x: 256, y: 492), control1: CGPoint(x: 372, y: 464), control2: CGPoint(x: 320, y: 494))
        p.addCurve(to: CGPoint(x: 124, y: 432), control1: CGPoint(x: 192, y: 490), control2: CGPoint(x: 142, y: 466))
        p.addQuadCurve(to: CGPoint(x: 112, y: 398), control: CGPoint(x: 108, y: 416))
        p.closeSubpath()
        return p
    }

    /// Scalloped upper-back glaze / cream dip region on the Bungeoppang.
    static func glazePath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 204, y: 318))
        p.addCurve(to: CGPoint(x: 396, y: 356), control1: CGPoint(x: 274, y: 292), control2: CGPoint(x: 352, y: 306))
        p.addCurve(to: CGPoint(x: 414, y: 390), control1: CGPoint(x: 412, y: 366), control2: CGPoint(x: 420, y: 378))
        // Scalloped glossy drips across the fish scales
        p.addQuadCurve(to: CGPoint(x: 374, y: 392), control: CGPoint(x: 396, y: 426))
        p.addQuadCurve(to: CGPoint(x: 332, y: 386), control: CGPoint(x: 354, y: 438))
        p.addQuadCurve(to: CGPoint(x: 286, y: 382), control: CGPoint(x: 310, y: 426))
        p.addQuadCurve(to: CGPoint(x: 242, y: 380), control: CGPoint(x: 264, y: 432))
        p.addQuadCurve(to: CGPoint(x: 202, y: 356), control: CGPoint(x: 214, y: 404))
        p.addQuadCurve(to: CGPoint(x: 204, y: 318), control: CGPoint(x: 192, y: 334))
        p.closeSubpath()
        return p
    }

    static func draw(_ t: Treat, frostMask: [[CGPoint]]? = nil, maskFade: Double = 0, in ctx: GraphicsContext) {
        let flavorRGB = TreatPainter.flavor(t.flavor).color
        // Warm golden waffle crust infused gently with batter flavor
        let golden = RGB(hex: "#F2A94B").mix(flavorRGB, 0.24)
        let lightGold = golden.mix(RGB(hex: "#FFF0B8"), 0.52)
        let deepGold = golden.mix(RGB(hex: "#B5621E"), 0.45)
        let outline = Shades.outline(deepGold).color

        let body = bodyPath()

        // Soft drop shadow on the plate
        ctx.fill(Path(ellipseIn: CGRect(x: 142, y: 484, width: 320, height: 34)), with: .color(Theme.ink.opacity(0.14)))

        // Dorsal scalloped crest fin behind back
        var dorsal = Path()
        dorsal.move(to: CGPoint(x: 222, y: 310))
        dorsal.addQuadCurve(to: CGPoint(x: 268, y: 296), control: CGPoint(x: 242, y: 274))
        dorsal.addQuadCurve(to: CGPoint(x: 314, y: 306), control: CGPoint(x: 294, y: 272))
        dorsal.addQuadCurve(to: CGPoint(x: 358, y: 330), control: CGPoint(x: 344, y: 288))
        dorsal.addLine(to: CGPoint(x: 222, y: 326))
        dorsal.closeSubpath()
        ctx.fill(dorsal, with: .color(golden.mix(RGB(hex: "#D68232"), 0.28).color))
        ctx.stroke(dorsal, with: .color(outline), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))

        // Cute ventral belly fin
        var ventral = Path()
        ventral.move(to: CGPoint(x: 294, y: 484))
        ventral.addQuadCurve(to: CGPoint(x: 356, y: 472), control: CGPoint(x: 332, y: 514))
        ventral.addLine(to: CGPoint(x: 348, y: 460))
        ventral.closeSubpath()
        ctx.fill(ventral, with: .color(golden.mix(RGB(hex: "#D68232"), 0.25).color))
        ctx.stroke(ventral, with: .color(outline), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

        // Crisp outer lacy waffle flange framing the fish (signature Korean street bungeoppang!)
        ctx.stroke(body, with: .color(outline), style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
        ctx.stroke(body, with: .color(lightGold.color), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))

        // Plump golden fish body
        ctx.fill(body, with: .radialGradient(
            Gradient(colors: [lightGold.color, golden.color, deepGold.color]),
            center: CGPoint(x: 240, y: 350), startRadius: 18, endRadius: 240
        ))

        // Crisp waffle diamond grid ridges clipped inside the torso
        var clipped = ctx
        clipped.clip(to: body)
        var waffleClip = clipped
        waffleClip.clip(to: Path(ellipseIn: CGRect(x: 204, y: 318, width: 202, height: 158)))
        var grid = Path()
        for k in -6...8 {
            let x = 210 + CGFloat(k) * 28
            grid.move(to: CGPoint(x: x - 90, y: 300))
            grid.addLine(to: CGPoint(x: x + 90, y: 500))
            grid.move(to: CGPoint(x: x + 90, y: 300))
            grid.addLine(to: CGPoint(x: x - 90, y: 500))
        }
        waffleClip.stroke(grid, with: .color(deepGold.color.opacity(0.45)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        waffleClip.stroke(grid.offsetBy(dx: -2, dy: -2), with: .color(lightGold.color.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // Tail fin ribs
        var ribs = Path()
        for (ty, ey) in [(378.0, 344.0), (396.0, 396.0), (414.0, 446.0)] as [(CGFloat, CGFloat)] {
            ribs.move(to: CGPoint(x: 414, y: ty))
            ribs.addLine(to: CGPoint(x: 468, y: ey))
        }
        clipped.stroke(ribs, with: .color(deepGold.color.opacity(0.65)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        // Warm glossy shine on upper head & back
        StorybookArt.highlight(clipped, in: CGRect(x: 146, y: 326, width: 92, height: 24), opacity: 0.42)

        // Crisp main outline
        ctx.stroke(body, with: .color(outline), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

        // Scalloped gill ridge separating head from waffle torso
        var gill = Path()
        gill.move(to: CGPoint(x: 208, y: 332))
        gill.addQuadCurve(to: CGPoint(x: 204, y: 462), control: CGPoint(x: 234, y: 396))
        ctx.stroke(gill, with: .color(deepGold.color.opacity(0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        ctx.stroke(gill.offsetBy(dx: -3, dy: 0), with: .color(lightGold.color.opacity(0.7)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

        // Sweet peeking filling at the open smiling mouth & cozy belly seam!
        drawFillingPeek(t.bungeoppangFilling, in: ctx)

        // Smiling kawaii fish face (happy eye arc + rosy cheek)
        var eye = Path()
        eye.move(to: CGPoint(x: 152, y: 382))
        eye.addQuadCurve(to: CGPoint(x: 180, y: 382), control: CGPoint(x: 166, y: 364))
        ctx.stroke(eye, with: .color(StorybookArt.color(0x5E3122)), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: 168, y: 394, width: 26, height: 15)), with: .color(Theme.pink.opacity(0.48)))
        StorybookArt.highlight(ctx, in: CGRect(x: 174, y: 397, width: 8, height: 4), opacity: 0.55)

        // Optional glaze / frosting spread in Step 3
        if let fr = t.frosting {
            drawBungeoppangGlaze(color: TreatPainter.frosting(fr), mask: frostMask, fade: maskFade, swoosh: t.swooshPoints, in: ctx)
        }

        if hasGoldenMold {
            drawGoldenCrownShimmer(in: ctx)
        }
    }

    private static func drawGoldenCrownShimmer(in ctx: GraphicsContext) {
        let goldOutline = StorybookArt.outline(for: 0xD9961E)

        // Subtle golden starlight halo behind the miniature crown
        ctx.fill(
            Path(ellipseIn: CGRect(x: 138, y: 274, width: 92, height: 64)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF3A8, alpha: 0.55), Color(hex: 0xFFCF4A, alpha: 0)]),
                center: CGPoint(x: 184, y: 306),
                startRadius: 4,
                endRadius: 46
            )
        )

        // Tiny royal golden crown perched on the Bungeoppang's head
        var c = ctx
        c.translateBy(x: 184, y: 316)
        c.rotate(by: .degrees(-14))

        var crown = Path()
        crown.move(to: CGPoint(x: -22, y: 6))
        crown.addLine(to: CGPoint(x: -26, y: -15))
        crown.addLine(to: CGPoint(x: -10, y: -4))
        crown.addLine(to: CGPoint(x: 0, y: -24))
        crown.addLine(to: CGPoint(x: 10, y: -4))
        crown.addLine(to: CGPoint(x: 26, y: -15))
        crown.addLine(to: CGPoint(x: 22, y: 6))
        crown.closeSubpath()
        c.fill(
            crown,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF4AD), Color(hex: 0xFFCF4A), Color(hex: 0xE59B20)]),
                startPoint: CGPoint(x: -22, y: -24),
                endPoint: CGPoint(x: 22, y: 12)
            )
        )
        c.stroke(crown, with: .color(goldOutline), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))

        let band = Path(roundedRect: CGRect(x: -23, y: 2, width: 46, height: 10), cornerRadius: 5)
        StorybookArt.fillAndStroke(c, band, fill: Color(hex: 0xFFE582), stroke: goldOutline, width: 2.6)

        for (px, py) in [(-26.0, -17.0), (0.0, -26.0), (26.0, -17.0)] as [(CGFloat, CGFloat)] {
            StorybookArt.fillAndStroke(
                c,
                Path(ellipseIn: CGRect(x: px - 4, y: py - 4, width: 8, height: 8)),
                fill: Color(hex: 0xFFFDF8),
                stroke: goldOutline,
                width: 1.8
            )
        }
        StorybookArt.heart(c, at: CGPoint(x: 0, y: -2), size: 10, color: Theme.pink)
        StorybookArt.highlight(c, in: CGRect(x: -14, y: 4, width: 14, height: 3.5), opacity: 0.72)

        // Delicate golden starlight sparkles shimmering around the fish pastry
        StorybookArt.sparkle(ctx, at: CGPoint(x: 148, y: 292), radius: 11, color: Color(hex: 0xFFF29C), opacity: 0.95)
        StorybookArt.sparkle(ctx, at: CGPoint(x: 218, y: 280), radius: 8.5, color: .white, opacity: 0.92)
        StorybookArt.sparkle(ctx, at: CGPoint(x: 458, y: 318), radius: 10, color: Color(hex: 0xFFE47A), opacity: 0.9)
        StorybookArt.sparkle(ctx, at: CGPoint(x: 342, y: 292), radius: 7, color: .white, opacity: 0.85)
    }

    private static func drawFillingPeek(_ filling: BungeoppangFilling, in ctx: GraphicsContext) {
        let fillC = StorybookArt.color(filling.fillHex)
        let accentC = StorybookArt.color(filling.accentHex)
        let strokeC = StorybookArt.outline(for: filling.fillHex)

        // Cozy peek of warm filling right at the smiling mouth opening
        var mouthFill = Path()
        mouthFill.move(to: CGPoint(x: 120, y: 414))
        mouthFill.addCurve(to: CGPoint(x: 174, y: 432), control1: CGPoint(x: 138, y: 404), control2: CGPoint(x: 166, y: 414))
        mouthFill.addCurve(to: CGPoint(x: 132, y: 454), control1: CGPoint(x: 176, y: 448), control2: CGPoint(x: 152, y: 458))
        mouthFill.addQuadCurve(to: CGPoint(x: 120, y: 414), control: CGPoint(x: 112, y: 436))
        mouthFill.closeSubpath()

        StorybookArt.fillAndStroke(ctx, mouthFill, fill: fillC, stroke: strokeC, width: 3.6)

        // Secondary yummy filling peek peeking from the golden belly seam
        var bellyPeek = Path()
        bellyPeek.move(to: CGPoint(x: 238, y: 472))
        bellyPeek.addCurve(to: CGPoint(x: 318, y: 470), control1: CGPoint(x: 262, y: 454), control2: CGPoint(x: 298, y: 456))
        bellyPeek.addCurve(to: CGPoint(x: 238, y: 472), control1: CGPoint(x: 304, y: 492), control2: CGPoint(x: 256, y: 492))
        bellyPeek.closeSubpath()
        StorybookArt.fillAndStroke(ctx, bellyPeek, fill: fillC, stroke: strokeC, width: 3.2)

        // Authentic texture accents inside the filling (whole azuki beans, vanilla specks, berry seeds...)
        let spots: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (138, 428, 7, 5), (154, 434, 6.5, 4.8), (144, 442, 6, 4.5),
            (262, 472, 7.5, 5), (284, 474, 7, 4.8), (298, 469, 6, 4.2),
        ]
        for (sx, sy, rw, rh) in spots {
            let dotW = filling == .redBean ? rw : rw * 0.5
            let dotH = filling == .redBean ? rh : rh * 0.5
            ctx.fill(Path(ellipseIn: CGRect(x: sx - dotW / 2, y: sy - dotH / 2, width: dotW, height: dotH)), with: .color(accentC.opacity(0.85)))
            if filling == .redBean {
                ctx.fill(Path(ellipseIn: CGRect(x: sx - dotW * 0.28, y: sy - dotH * 0.3, width: 2.4, height: 1.6)), with: .color(.white.opacity(0.6)))
            }
        }
        StorybookArt.highlight(ctx, in: CGRect(x: 132, y: 419, width: 16, height: 6), opacity: 0.52)
        StorybookArt.highlight(ctx, in: CGRect(x: 256, y: 463, width: 22, height: 6), opacity: 0.45)
    }

    private static func drawBungeoppangGlaze(color: RGB, mask: [[CGPoint]]?, fade: Double, swoosh: [[CGPoint]], in ctx: GraphicsContext) {
        let path = glazePath()
        let paintGlaze: (GraphicsContext) -> Void = { g in
            g.fill(path, with: .linearGradient(
                Gradient(colors: [Shades.light(color).color, color.color, Shades.shade(color).color]),
                startPoint: CGPoint(x: 220, y: 300), endPoint: CGPoint(x: 380, y: 420)
            ))
            g.stroke(path, with: .color(Shades.outline(color).color), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            StorybookArt.highlight(g, in: CGRect(x: 244, y: 318, width: 76, height: 14), opacity: 0.65)
            for dx in [242.0, 290.0, 336.0, 378.0] as [CGFloat] {
                StorybookArt.highlight(g, in: CGRect(x: dx - 4, y: 382, width: 7, height: 9), opacity: 0.55)
            }
        }

        if let m = mask, fade < 1 {
            if fade > 0 {
                var f = ctx
                f.opacity = fade
                paintGlaze(f)
            }
            ctx.drawLayer { l in
                let style = StrokeStyle(lineWidth: TreatPainter.spreadBrush * 2, lineCap: .round, lineJoin: .round)
                for s in m { l.stroke(TreatPainter.polyline(s), with: .color(.black), style: style) }
                l.blendMode = .sourceIn
                l.drawLayer { inner in paintGlaze(inner) }
            }
        } else {
            paintGlaze(ctx)
        }
        if !swoosh.isEmpty {
            var c = ctx
            c.clip(to: path)
            TreatPainter.drawSwooshTexture(swoosh, color, in: c)
        }
    }

    /// Cute porcelain bowl filled with a Bungeoppang filling (used in BakeStepView chooser).
    static func drawFillingBowl(_ g: GraphicsContext, filling: BungeoppangFilling) {
        let fillC = StorybookArt.color(filling.fillHex)
        let accentC = StorybookArt.color(filling.accentHex)
        let fillOutline = StorybookArt.outline(for: filling.fillHex)

        // Creamy mound of filling rising out of the bowl
        let mound = Path(ellipseIn: CGRect(x: -28, y: -22, width: 56, height: 34))
        StorybookArt.fillAndStroke(g, mound, fill: fillC, stroke: fillOutline, width: 2.6)
        for (dx, dy) in [(-12.0, -8.0), (0.0, -13.0), (12.0, -7.0), (-5.0, -2.0), (8.0, -1.0)] as [(CGFloat, CGFloat)] {
            let r: CGFloat = filling == .redBean ? 4.2 : 2.3
            g.fill(Path(ellipseIn: CGRect(x: dx - r, y: dy - r * 0.75, width: r * 2, height: r * 1.5)), with: .color(accentC.opacity(0.85)))
        }
        StorybookArt.highlight(g, in: CGRect(x: -17, y: -17, width: 16, height: 7), opacity: 0.55)

        // Little pastel ceramic bowl
        var bowl = Path()
        bowl.move(to: CGPoint(x: -32, y: -4))
        bowl.addLine(to: CGPoint(x: 32, y: -4))
        bowl.addQuadCurve(to: CGPoint(x: 20, y: 24), control: CGPoint(x: 32, y: 16))
        bowl.addLine(to: CGPoint(x: -20, y: 24))
        bowl.addQuadCurve(to: CGPoint(x: -32, y: -4), control: CGPoint(x: -32, y: 16))
        bowl.closeSubpath()
        StorybookArt.fillAndStroke(g, bowl, fill: StorybookArt.color(0xFFF7F2), stroke: StorybookArt.outline(for: 0xE6C0CE), width: 2.8)
        let band = Path(roundedRect: CGRect(x: -28, y: 4, width: 56, height: 7), cornerRadius: 3.5)
        g.fill(band, with: .color(Theme.blush))
    }
}

/// A treat as a view, fitted into its frame.
struct TreatView: View {
    let treat: Treat
    var plate = true
    /// 0...3 bites taken out of it.
    var bites = 0
    /// The part of the 600 x 600 stage to show.
    var box = Box.stage
    var pipe: CGFloat = 0
    var sauceReveal: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            BakeryArt.fit(&g, box: box, into: size)
            if bites == 0 {
                TreatPainter.draw(treat, in: g, pipe: pipe, sauceReveal: sauceReveal, plate: plate)
            } else {
                let t = treat
                let b = bites
                let p = plate
                g.drawLayer { l in
                    TreatPainter.draw(t, in: l, plate: p)
                    l.blendMode = .destinationOut
                    l.fill(BiteMarks.path(for: t, bites: b), with: .color(.black))
                }
            }
        }
    }
}

enum BiteMarks {
    /// Round bites taken from the top-right of the treat, growing with each bite.
    static func path(for t: Treat, bites: Int) -> Path {
        var p = Path()
        let top = TreatPainter.topY(t)
        let bottom: CGFloat = t.kind == .iceCream ? 600 : 520
        let h = bottom - top
        let steps: [[(CGFloat, CGFloat, CGFloat)]] = [
            [(0.78, 0.05, 0.22), (0.62, -0.02, 0.16)],
            [(0.5, 0.18, 0.26), (0.3, 0.05, 0.2), (0.82, 0.38, 0.24)],
            [(0.2, 0.4, 0.3), (0.55, 0.6, 0.34), (0.85, 0.75, 0.3), (0.3, 0.8, 0.3), (0.6, 0.95, 0.3)],
        ]
        for k in 0..<min(3, bites) {
            for (fx, fy, fr) in steps[k] {
                let r = fr * h
                let c = CGPoint(x: 150 + fx * 320, y: top + fy * h)
                p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            }
        }
        return p
    }
}

// MARK: - Piping a cupcake ring

enum Piping {
    /// The ring each frosting stage adds: center y, half width, half height (stage units).
    static func ring(style: String, stage: Int) -> (cy: CGFloat, hw: CGFloat, hh: CGFloat) {
        let k = max(1, min(3, stage)) - 1
        let cloud: [(CGFloat, CGFloat, CGFloat)] = [(392, 112, 22), (326, 76, 20), (262, 34, 26)]
        let swirl: [(CGFloat, CGFloat, CGFloat)] = [(392, 140, 30), (336, 108, 26), (286, 72, 22)]
        let heights: [CGFloat] = [52, 84, 112]
        switch style {
        case "cloud":
            let v = cloud[k]
            return (v.0, v.1, v.2)
        case "dome":
            let h = heights[k]
            return (410 - h * 0.45, 132, max(20, h * 0.4))
        default:
            let v = swirl[k]
            return (v.0, v.1, v.2)
        }
    }

    /// The angle the nozzle has reached: it starts on the left and goes around the front first.
    static func angle(_ f: CGFloat) -> CGFloat { .pi - 2 * .pi * max(0, min(1, f)) }

    /// The part of the next ring piped so far: a pie slice swept around the ring's center.
    static func wedge(style: String, stage: Int, f: CGFloat) -> Path {
        let r = ring(style: style, stage: stage)
        let c = CGPoint(x: 300, y: r.cy)
        var p = Path()
        p.move(to: c)
        let m = 48
        for j in 0...m {
            let a = angle(f * CGFloat(j) / CGFloat(m))
            p.addLine(to: CGPoint(x: c.x + cos(a) * 420, y: c.y + sin(a) * 420))
        }
        p.closeSubpath()
        return p
    }

    /// Where the nozzle is (stage units).
    static func nozzle(style: String, stage: Int, f: CGFloat) -> CGPoint {
        let r = ring(style: style, stage: stage)
        let a = angle(f)
        return CGPoint(x: 300 + cos(a) * r.hw * 0.92, y: r.cy + sin(a) * r.hh - 6)
    }
}
