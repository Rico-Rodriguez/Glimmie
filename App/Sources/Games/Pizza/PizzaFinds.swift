import SwiftUI

enum PizzaFind: String, CaseIterable {
    case firstPizza
    case doughTosser
    case woodFiredChef
    case cheesePull
    case threeStarPizzaiolo
    case masterChef

    static var stickers: [Sticker] {
        allCases.map { find in
            Sticker(id: find.rawValue) { ctx, _ in
                find.drawSticker(ctx)
            }
        }
    }

    /// Drawn centered in a 100x100 square (-50...50).
    func drawSticker(_ g: GraphicsContext) {
        switch self {
        case .firstPizza:
            drawFirstPizza(g)
        case .doughTosser:
            drawDoughTosser(g)
        case .woodFiredChef:
            drawWoodFiredChef(g)
        case .cheesePull:
            drawCheesePull(g)
        case .threeStarPizzaiolo:
            drawThreeStarPizzaiolo(g)
        case .masterChef:
            drawMasterChef(g)
        }
    }

    private func drawFirstPizza(_ g: GraphicsContext) {
        // Golden wedge body
        var slice = Path()
        slice.move(to: CGPoint(x: 0, y: 36))
        slice.addLine(to: CGPoint(x: -31, y: -22))
        slice.addQuadCurve(to: CGPoint(x: 31, y: -22), control: CGPoint(x: 0, y: -34))
        slice.closeSubpath()

        var sauce = Path()
        sauce.move(to: CGPoint(x: 0, y: 30))
        sauce.addLine(to: CGPoint(x: -24, y: -16))
        sauce.addQuadCurve(to: CGPoint(x: 24, y: -16), control: CGPoint(x: 0, y: -24))
        sauce.closeSubpath()

        StorybookArt.fillAndStroke(g, slice, fill: StorybookArt.color(0xFFE07D), stroke: StorybookArt.outline(for: 0xDE943B), width: 3.2)
        g.fill(sauce, with: .color(StorybookArt.color(0xDE4832)))

        var cheese = Path()
        cheese.move(to: CGPoint(x: 0, y: 27))
        cheese.addLine(to: CGPoint(x: -20, y: -13))
        cheese.addQuadCurve(to: CGPoint(x: 20, y: -13), control: CGPoint(x: 0, y: -20))
        cheese.closeSubpath()
        g.fill(
            cheese,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFF099), StorybookArt.color(0xFFD25A)]),
                startPoint: CGPoint(x: 0, y: -18),
                endPoint: CGPoint(x: 0, y: 27)
            )
        )

        // Puffed golden crust arc across top
        var crust = Path()
        crust.move(to: CGPoint(x: -33, y: -22))
        crust.addQuadCurve(to: CGPoint(x: 33, y: -22), control: CGPoint(x: 0, y: -35))
        g.stroke(crust, with: .color(StorybookArt.outline(for: 0xDF9644)), style: StrokeStyle(lineWidth: 13.5, lineCap: .round))
        g.stroke(crust, with: .color(StorybookArt.color(0xEBA454)), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
        g.stroke(crust.offsetBy(dx: 0, dy: -2), with: .color(StorybookArt.color(0xFBE0A8).opacity(0.6)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Cupped pepperoni & basil leaf
        for (px, py, pr) in [(-9.0, -7.0, 6.5), (9.0, -3.0, 6.0), (-1.0, 11.0, 5.5)] {
            let pep = Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
            StorybookArt.fillAndStroke(g, pep, fill: StorybookArt.color(0xD94132), stroke: StorybookArt.outline(for: 0xB5281C), width: 2)
            StorybookArt.highlight(g, in: CGRect(x: px - pr * 0.45, y: py - pr * 0.5, width: pr * 0.65, height: pr * 0.35), opacity: 0.55)
        }
        var leaf = Path()
        leaf.move(to: CGPoint(x: 2, y: -15))
        leaf.addQuadCurve(to: CGPoint(x: 11, y: -4), control: CGPoint(x: 12, y: -13))
        leaf.addQuadCurve(to: CGPoint(x: 2, y: -15), control: CGPoint(x: 1, y: -6))
        StorybookArt.fillAndStroke(g, leaf, fill: StorybookArt.color(0x52B35A), stroke: StorybookArt.outline(for: 0x3A8C40), width: 1.8)

        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: 12), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 33, y: 6), radius: 6, color: Theme.pink)
    }

    private func drawDoughTosser(_ g: GraphicsContext) {
        // Motion swirl arcs underneath spinning dough
        for (y, w, a) in [(24.0, 26.0, 0.55), (34.0, 18.0, 0.4)] {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: CGFloat(y)), radius: CGFloat(w), startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(0x9CCBFF, alpha: a)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }

        // Spinning airy pizza dough disc tilted in midair
        var discCtx = g
        discCtx.translateBy(x: 0, y: -6)
        discCtx.rotate(by: .degrees(-12))
        let outer = Path(ellipseIn: CGRect(x: -35, y: -17, width: 70, height: 34))
        discCtx.fill(
            outer,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFFF9E6), StorybookArt.color(0xF2DBAE), StorybookArt.color(0xDFBC82)]),
                center: CGPoint(x: -10, y: -6),
                startRadius: 2,
                endRadius: 40
            )
        )
        discCtx.stroke(outer, with: .color(StorybookArt.outline(for: 0xDFB87E)), lineWidth: 3.4)
        let inner = Path(ellipseIn: CGRect(x: -24, y: -10, width: 48, height: 20))
        discCtx.stroke(inner, with: .color(StorybookArt.outline(for: 0xDFB87E, factor: 0.82).opacity(0.45)), lineWidth: 2.2)
        StorybookArt.highlight(discCtx, in: CGRect(x: -22, y: -11, width: 20, height: 6), opacity: 0.7)

        // Spin whoosh lines & flour puffs
        var whoosh = Path()
        whoosh.addArc(center: CGPoint(x: 0, y: -8), radius: 39, startAngle: .degrees(-160), endAngle: .degrees(-105), clockwise: false)
        whoosh.addArc(center: CGPoint(x: 0, y: -4), radius: 39, startAngle: .degrees(15), endAngle: .degrees(68), clockwise: false)
        g.stroke(whoosh, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

        for (fx, fy, fr) in [(-24.0, 14.0, 5.5), (26.0, -24.0, 5.0), (-29.0, -26.0, 4.0)] {
            g.fill(Path(ellipseIn: CGRect(x: fx - fr, y: fy - fr, width: fr * 2, height: fr * 2)), with: .color(.white.opacity(0.85)))
        }
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -28), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: 20), radius: 6, color: Theme.pink)
    }

    private func drawWoodFiredChef(_ g: GraphicsContext) {
        // Domed terracotta brick oven
        var dome = Path()
        dome.move(to: CGPoint(x: -34, y: 30))
        dome.addLine(to: CGPoint(x: -34, y: 4))
        dome.addArc(center: CGPoint(x: 0, y: 4), radius: 34, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.addLine(to: CGPoint(x: 34, y: 30))
        dome.closeSubpath()
        g.fill(
            dome,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xE88D67), StorybookArt.color(0xCC6445)]),
                startPoint: CGPoint(x: 0, y: -30),
                endPoint: CGPoint(x: 0, y: 30)
            )
        )
        g.stroke(dome, with: .color(StorybookArt.outline(for: 0xCC6445)), lineWidth: 3.4)

        // Stone base hearth
        let hearth = Path(roundedRect: CGRect(x: -38, y: 24, width: 76, height: 12), cornerRadius: 5)
        StorybookArt.fillAndStroke(g, hearth, fill: StorybookArt.color(0xE8D4BE), stroke: StorybookArt.outline(for: 0xC9AD91), width: 2.8)

        // Glowing arched firebox
        var arch = Path()
        arch.move(to: CGPoint(x: -21, y: 25))
        arch.addLine(to: CGPoint(x: -21, y: 8))
        arch.addArc(center: CGPoint(x: 0, y: 8), radius: 21, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        arch.addLine(to: CGPoint(x: 21, y: 25))
        arch.closeSubpath()
        g.fill(
            arch,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFF9F3D), StorybookArt.color(0x8C2D19), StorybookArt.color(0x45150D)]),
                center: CGPoint(x: 0, y: 18),
                startRadius: 2,
                endRadius: 28
            )
        )
        g.stroke(arch, with: .color(StorybookArt.color(0xF6DEC8)), lineWidth: 3.2)

        // Cheerful crackling flames inside
        var flame = Path()
        flame.move(to: CGPoint(x: 0, y: -7))
        flame.addCurve(to: CGPoint(x: 11, y: 22), control1: CGPoint(x: 13, y: 2), control2: CGPoint(x: 14, y: 16))
        flame.addLine(to: CGPoint(x: -11, y: 22))
        flame.addCurve(to: CGPoint(x: 0, y: -7), control1: CGPoint(x: -14, y: 16), control2: CGPoint(x: -13, y: 2))
        flame.closeSubpath()
        g.fill(flame, with: .linearGradient(
            Gradient(colors: [StorybookArt.color(0xFFE570), StorybookArt.color(0xFF7B2B)]),
            startPoint: CGPoint(x: 0, y: -6),
            endPoint: CGPoint(x: 0, y: 22)
        ))
        g.fill(Path(ellipseIn: CGRect(x: -5, y: 9, width: 10, height: 12)), with: .color(StorybookArt.color(0xFFF6BE)))

        StorybookArt.sparkle(g, at: CGPoint(x: -31, y: -28), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -24), radius: 6, color: Theme.pink)
    }

    private func drawCheesePull(_ g: GraphicsContext) {
        // Base pizza half resting at bottom
        var base = Path()
        base.move(to: CGPoint(x: -34, y: 26))
        base.addQuadCurve(to: CGPoint(x: 34, y: 26), control: CGPoint(x: 0, y: 12))
        base.addQuadCurve(to: CGPoint(x: -34, y: 26), control: CGPoint(x: 0, y: 40))
        base.closeSubpath()
        StorybookArt.fillAndStroke(g, base, fill: StorybookArt.color(0xE89F52), stroke: StorybookArt.outline(for: 0xCE8234), width: 2.8)

        // Long stretchy golden cheese strands pulling upward
        for (x0, x1, w) in [(-15.0, -11.0, 5.5), (-3.0, 0.0, 6.5), (9.0, 12.0, 5.0), (19.0, 17.0, 3.8)] {
            var strand = Path()
            strand.move(to: CGPoint(x: CGFloat(x0), y: 22))
            strand.addQuadCurve(to: CGPoint(x: CGFloat(x1), y: -6), control: CGPoint(x: CGFloat((x0 + x1) / 2) + 3, y: 9))
            g.stroke(strand, with: .color(StorybookArt.outline(for: 0xF5B942)), style: StrokeStyle(lineWidth: CGFloat(w) + 2.4, lineCap: .round))
            g.stroke(strand, with: .color(StorybookArt.color(0xFFE073)), style: StrokeStyle(lineWidth: CGFloat(w), lineCap: .round))
        }

        // Lifted cheesy slice floating above
        var lifted = g
        lifted.translateBy(x: 2, y: -22)
        lifted.rotate(by: .degrees(-8))
        var wedge = Path()
        wedge.move(to: CGPoint(x: -28, y: 10))
        wedge.addLine(to: CGPoint(x: 24, y: 14))
        wedge.addLine(to: CGPoint(x: 16, y: -16))
        wedge.addQuadCurve(to: CGPoint(x: -28, y: 10), control: CGPoint(x: -10, y: -14))
        wedge.closeSubpath()
        StorybookArt.fillAndStroke(lifted, wedge, fill: StorybookArt.color(0xFFD85E), stroke: StorybookArt.outline(for: 0xD88F32), width: 2.8)
        let pep = Path(ellipseIn: CGRect(x: -6, y: -5, width: 12, height: 10))
        StorybookArt.fillAndStroke(lifted, pep, fill: StorybookArt.color(0xD94132), stroke: StorybookArt.outline(for: 0xB5281C), width: 2)
        StorybookArt.highlight(lifted, in: CGRect(x: -14, y: 1, width: 10, height: 4), opacity: 0.7)

        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -14), radius: 6, color: Theme.pink)
    }

    private func drawThreeStarPizzaiolo(_ g: GraphicsContext) {
        // Puffy chef toque
        let toqueOutline = StorybookArt.outline(for: 0xE6D8EC)
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-20, -2, 15), (20, -2, 15), (-9, -14, 17), (9, -14, 17), (0, -18, 17)]
        for (px, py, pr) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(toqueOutline), lineWidth: 6.2)
        }
        for (px, py, pr) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(StorybookArt.color(0xFFFDFB)))
        }

        // Hat band with cheerful Italian tricolor stripe
        let band = Path(roundedRect: CGRect(x: -25, y: 7, width: 50, height: 23), cornerRadius: 8)
        StorybookArt.fillAndStroke(g, band, fill: StorybookArt.color(0xFFF9F4), stroke: toqueOutline, width: 3)
        g.fill(Path(roundedRect: CGRect(x: -23, y: 16, width: 15, height: 9), cornerRadius: 3), with: .color(StorybookArt.color(0x52B864)))
        g.fill(Path(roundedRect: CGRect(x: -8, y: 16, width: 16, height: 9), cornerRadius: 2), with: .color(.white))
        g.fill(Path(roundedRect: CGRect(x: 8, y: 16, width: 15, height: 9), cornerRadius: 3), with: .color(StorybookArt.color(0xEB5757)))

        for (sx, sy, sr) in [(-25.0, -28.0, 9.0), (0.0, -37.0, 11.5), (25.0, -28.0, 9.0)] {
            drawStar(g, at: CGPoint(x: CGFloat(sx), y: CGFloat(sy)), radius: CGFloat(sr), fill: 0xFFE06B, outline: 0xD99622)
        }
    }

    private func drawMasterChef(_ g: GraphicsContext) {
        // Golden ribbon tails
        for side in [-1.0, 1.0] {
            var tail = Path()
            let s = CGFloat(side)
            tail.move(to: CGPoint(x: s * 6, y: 16))
            tail.addLine(to: CGPoint(x: s * 22, y: 40))
            tail.addLine(to: CGPoint(x: s * 10, y: 35))
            tail.addLine(to: CGPoint(x: s * 2, y: 42))
            tail.closeSubpath()
            StorybookArt.fillAndStroke(g, tail, fill: StorybookArt.color(0xFF7B9C), stroke: StorybookArt.outline(for: 0xE2567A), width: 2.4)
        }

        // Wooden pizza peel medal with mini supreme pizza
        let medal = Path(ellipseIn: CGRect(x: -29, y: -27, width: 58, height: 58))
        StorybookArt.fillAndStroke(g, medal, fill: StorybookArt.color(0xFFE073), stroke: StorybookArt.outline(for: 0xD99622), width: 3.4)
        let inner = Path(ellipseIn: CGRect(x: -22, y: -20, width: 44, height: 44))
        StorybookArt.fillAndStroke(g, inner, fill: StorybookArt.color(0xE89F52), stroke: StorybookArt.outline(for: 0xC97D32), width: 2.4)
        g.fill(Path(ellipseIn: CGRect(x: -17, y: -15, width: 34, height: 34)), with: .color(StorybookArt.color(0xDE4832)))
        g.fill(Path(ellipseIn: CGRect(x: -14, y: -12, width: 28, height: 28)), with: .color(StorybookArt.color(0xFFE580)))

        for (px, py) in [(-6.0, -4.0), (6.0, -3.0), (0.0, 6.0)] {
            g.fill(Path(ellipseIn: CGRect(x: px - 4, y: py - 4, width: 8, height: 8)), with: .color(StorybookArt.color(0xD94132)))
        }
        g.fill(Path(ellipseIn: CGRect(x: -2, y: -2, width: 6, height: 4)), with: .color(StorybookArt.color(0x52B864)))

        // Tiny golden crown on top of the medal
        var crown = Path()
        crown.move(to: CGPoint(x: -14, y: -24))
        crown.addLine(to: CGPoint(x: -16, y: -38))
        crown.addLine(to: CGPoint(x: -6, y: -31))
        crown.addLine(to: CGPoint(x: 0, y: -41))
        crown.addLine(to: CGPoint(x: 6, y: -31))
        crown.addLine(to: CGPoint(x: 16, y: -38))
        crown.addLine(to: CGPoint(x: 14, y: -24))
        crown.closeSubpath()
        StorybookArt.fillAndStroke(g, crown, fill: StorybookArt.color(0xFFE378), stroke: StorybookArt.outline(for: 0xD99622), width: 2.2)

        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 35, y: -18), radius: 6, color: Theme.pink)
    }

    private func drawStar(_ g: GraphicsContext, at center: CGPoint, radius: CGFloat, fill: UInt32, outline: UInt32) {
        var star = Path()
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let rr = k.isMultiple(of: 2) ? radius : radius * 0.48
            let pt = CGPoint(x: center.x + cos(a) * rr, y: center.y + sin(a) * rr)
            if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        StorybookArt.fillAndStroke(g, star, fill: StorybookArt.color(fill), stroke: StorybookArt.outline(for: outline), width: 2.2)
    }
}
