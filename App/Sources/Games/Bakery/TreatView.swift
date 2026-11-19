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

    /// - frostReveal: while she spreads cake frosting, only this part of the frosting shows.
    /// - ages: seconds since each topping landed, for the little drop-and-bounce.
    static func draw(_ t: Treat, in ctx: GraphicsContext, frostReveal: Path? = nil, plate: Bool = true,
                     ages: [UUID: Double] = [:], hidden: UUID? = nil) {
        switch t.kind {
        case .cake:
            if plate { art.draw("plate", in: ctx) }
            let n = max(1, min(3, t.tiers))
            for i in 0..<n {
                art.draw("cake_body\(i)", flavor(t.flavor).color, in: ctx)
                if let fr = t.frosting {
                    if let reveal = frostReveal {
                        var g = ctx
                        g.clip(to: reveal)
                        art.draw("cake_frost\(i)", frosting(fr), in: g)
                    } else {
                        art.draw("cake_frost\(i)", frosting(fr), in: ctx)
                    }
                }
            }
        case .cupcake:
            if plate { art.draw("plate", in: ctx) }
            art.draw("liner", liner(t.liner), in: ctx)
            art.draw("cupcake_top", flavor(t.flavor).color, in: ctx)
            if let fr = t.frosting, t.frostStage > 0 {
                art.draw("frost_\(t.frostStyle)\(min(3, t.frostStage))", frosting(fr), in: ctx)
            }
        case .iceCream:
            var shadow = ctx
            shadow.opacity = 0.18
            shadow.fill(Path(ellipseIn: CGRect(x: 230, y: 576, width: 140, height: 22)), with: .color(Theme.ink))
            art.draw("cone_\(t.cone)", liner(t.liner), in: ctx)
            for (k, s) in t.scoops.prefix(4).enumerated() {
                let p = CGPoint(x: 300, y: art.scoopY0 - CGFloat(k) * art.scoopDY)
                let fl = flavor(s)
                art.draw("scoop", fl.color, at: p, in: ctx)
                if fl.chips == 1 { art.draw("scoop_chips", fl.color, at: p, in: ctx) }
                if fl.chips == 2 { art.draw("scoop_bits", fl.color, at: p, in: ctx) }
            }
            if let sc = t.sauce, !t.scoops.isEmpty {
                let p = CGPoint(x: 300, y: art.scoopY0 - CGFloat(min(4, t.scoops.count) - 1) * art.scoopDY)
                art.draw("sauce", sauce(sc), at: p, in: ctx)
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
        case .iceCream: return art.scoopY0 - CGFloat(max(0, min(4, t.scoops.count) - 1)) * art.scoopDY - 90
        }
    }
}

/// A treat as a view, fitted into its frame.
struct TreatView: View {
    let treat: Treat
    var plate = true
    /// 0...3 bites taken out of it.
    var bites = 0

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            BakeryArt.fit(&g, box: Box.stage, into: size)
            if bites == 0 {
                TreatPainter.draw(treat, in: g, plate: plate)
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
