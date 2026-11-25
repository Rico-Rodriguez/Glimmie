import SwiftUI

enum BakeryFind: String, CaseIterable {
    case firstBake
    case cakeArtist
    case cupcakeStar
    case bungeoppang
    case koreanStrawberryCake
    case fiveStarBaker

    static var stickers: [Sticker] {
        allCases.map { find in
            Sticker(id: find.rawValue) { ctx, _ in
                find.drawSticker(ctx)
            }
        }
    }

    static func earned(for treat: Treat, stars: Int, totalServed: Int) -> [BakeryFind] {
        var unlocked: [BakeryFind] = [.firstBake]
        switch treat.kind {
        case .cake:
            unlocked.append(.cakeArtist)
            if treat.freshCreamCrown == true || treat.toppings.contains(where: { $0.sprite == "top_strawberry" }) {
                unlocked.append(.koreanStrawberryCake)
            }
        case .cupcake:
            unlocked.append(.cupcakeStar)
        case .bungeoppang:
            unlocked.append(.bungeoppang)
        case .iceCream:
            break
        }
        if stars >= 3 || totalServed >= 5 {
            unlocked.append(.fiveStarBaker)
        }
        return unlocked
    }

    /// Drawn centered in a 100x100 square (-50...50).
    func drawSticker(_ g: GraphicsContext) {
        switch self {
        case .firstBake:
            drawFirstBake(g)
        case .cakeArtist:
            drawCakeArtist(g)
        case .cupcakeStar:
            drawCupcakeStar(g)
        case .bungeoppang:
            drawBungeoppang(g)
        case .koreanStrawberryCake:
            drawKoreanStrawberryCake(g)
        case .fiveStarBaker:
            drawFiveStarBaker(g)
        }
    }

    private func drawFirstBake(_ g: GraphicsContext) {
        // Pastel rainbow frosting swirl meringue
        let bands: [(CGRect, UInt32)] = [
            (CGRect(x: -34, y: 10, width: 68, height: 22), 0xC9B6FF),
            (CGRect(x: -30, y: -2, width: 60, height: 20), 0x9CCBFF),
            (CGRect(x: -25, y: -13, width: 50, height: 18), 0x9FE3CF),
            (CGRect(x: -19, y: -23, width: 38, height: 16), 0xFFE38A),
            (CGRect(x: -13, y: -32, width: 26, height: 14), 0xFF8FB8),
        ]
        for (rect, hex) in bands {
            let p = Path(ellipseIn: rect)
            StorybookArt.fillAndStroke(g, p, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.8)
            StorybookArt.highlight(
                g,
                in: CGRect(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.2, width: rect.width * 0.34, height: rect.height * 0.28),
                opacity: 0.65
            )
        }
        var curl = Path()
        curl.move(to: CGPoint(x: -6, y: -30))
        curl.addCurve(to: CGPoint(x: 8, y: -30), control1: CGPoint(x: -4, y: -44), control2: CGPoint(x: 6, y: -42))
        curl.closeSubpath()
        StorybookArt.fillAndStroke(g, curl, fill: StorybookArt.color(0xFF9EC4), stroke: StorybookArt.outline(for: 0xFF8FB8), width: 2.4)

        StorybookArt.sparkle(g, at: CGPoint(x: -35, y: -20), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -18), radius: 7, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -43), radius: 6, color: Theme.sky)
    }

    private func drawCakeArtist(_ g: GraphicsContext) {
        let plate = Path(ellipseIn: CGRect(x: -36, y: 28, width: 72, height: 14))
        StorybookArt.fillAndStroke(g, plate, fill: StorybookArt.color(0xFFF9F4), stroke: StorybookArt.outline(for: 0xE6C8D6), width: 2.8)

        let tiers: [(CGRect, UInt32, UInt32)] = [
            (CGRect(x: -31, y: 12, width: 62, height: 21), 0xFFB8D2, 0xFFF2C9),
            (CGRect(x: -23, y: -8, width: 46, height: 20), 0xAEE8D4, 0xFFD9E6),
            (CGRect(x: -15, y: -26, width: 30, height: 18), 0xFFE38A, 0xFF9EC4),
        ]
        for (rect, bodyHex, dripHex) in tiers {
            let body = Path(roundedRect: rect, cornerRadius: 7)
            StorybookArt.fillAndStroke(g, body, fill: StorybookArt.color(bodyHex), stroke: StorybookArt.outline(for: bodyHex), width: 2.6)
            let drip = Path(roundedRect: CGRect(x: rect.minX + 1, y: rect.minY, width: rect.width - 2, height: 7), cornerRadius: 4)
            g.fill(drip, with: .color(StorybookArt.color(dripHex)))
            StorybookArt.highlight(g, in: CGRect(x: rect.minX + 5, y: rect.minY + 2, width: rect.width * 0.35, height: 3.5), opacity: 0.7)
        }

        let candle = Path(roundedRect: CGRect(x: -3.5, y: -38, width: 7, height: 13), cornerRadius: 2.5)
        StorybookArt.fillAndStroke(g, candle, fill: StorybookArt.color(0x9CCBFF), stroke: StorybookArt.outline(for: 0x6AA6EE), width: 2)
        var flame = Path()
        flame.move(to: CGPoint(x: 0, y: -47))
        flame.addCurve(to: CGPoint(x: 0, y: -37), control1: CGPoint(x: 7, y: -42), control2: CGPoint(x: 5, y: -37))
        flame.addCurve(to: CGPoint(x: 0, y: -47), control1: CGPoint(x: -5, y: -37), control2: CGPoint(x: -7, y: -42))
        StorybookArt.fillAndStroke(g, flame, fill: StorybookArt.color(0xFFD559), stroke: StorybookArt.outline(for: 0xF08A2E), width: 1.8)

        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -24), radius: 6.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -20), radius: 6.5, color: Theme.pink)
    }

    private func drawCupcakeStar(_ g: GraphicsContext) {
        var cup = Path()
        cup.move(to: CGPoint(x: -24, y: 6))
        cup.addLine(to: CGPoint(x: 24, y: 6))
        cup.addLine(to: CGPoint(x: 18, y: 34))
        cup.addQuadCurve(to: CGPoint(x: -18, y: 34), control: CGPoint(x: 0, y: 39))
        cup.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            cup,
            fill: StorybookArt.color(0xFF9EC4),
            stroke: StorybookArt.outline(for: 0xF078A8),
            width: 3
        )
        var pleats = Path()
        for dx in [-11.0, 0.0, 11.0] {
            pleats.move(to: CGPoint(x: CGFloat(dx), y: 9))
            pleats.addLine(to: CGPoint(x: CGFloat(dx) * 0.78, y: 33))
        }
        g.stroke(pleats, with: .color(StorybookArt.outline(for: 0xFF9EC4, factor: 0.78).opacity(0.65)),
                 style: StrokeStyle(lineWidth: 2, lineCap: .round))

        let baseSwirl = Path(ellipseIn: CGRect(x: -28, y: -10, width: 56, height: 24))
        StorybookArt.fillAndStroke(g, baseSwirl, fill: StorybookArt.color(0xFFD2E4), stroke: StorybookArt.outline(for: 0xF09BC0), width: 3)
        let midSwirl = Path(ellipseIn: CGRect(x: -21, y: -22, width: 42, height: 20))
        StorybookArt.fillAndStroke(g, midSwirl, fill: StorybookArt.color(0xFFB4D2), stroke: StorybookArt.outline(for: 0xF08AB5), width: 2.8)
        var peak = Path()
        peak.move(to: CGPoint(x: -12, y: -16))
        peak.addCurve(to: CGPoint(x: 12, y: -16), control1: CGPoint(x: -10, y: -34), control2: CGPoint(x: 6, y: -34))
        peak.closeSubpath()
        StorybookArt.fillAndStroke(g, peak, fill: StorybookArt.color(0xFFC5DC), stroke: StorybookArt.outline(for: 0xF08AB5), width: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: -17, y: -5, width: 14, height: 6), opacity: 0.72)

        drawStar(g, at: CGPoint(x: 0, y: -34), radius: 10.5, fill: 0xFFE378, outline: 0xD99622)

        let sprinkles: [(CGFloat, CGFloat, UInt32)] = [(-14, 1, 0xFFE38A), (4, -12, 0x9FE3CF), (14, 0, 0x9CCBFF), (-5, -16, 0xFFE38A)]
        for (sx, sy, hex) in sprinkles {
            g.fill(Path(roundedRect: CGRect(x: sx - 3, y: sy - 1.5, width: 6, height: 3), cornerRadius: 1.5), with: .color(StorybookArt.color(hex)))
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 33, y: -14), radius: 6, color: Theme.pink)
    }

    private func drawBungeoppang(_ g: GraphicsContext) {
        var fish = g
        fish.rotate(by: .degrees(-10))

        var flange = Path()
        flange.move(to: CGPoint(x: -38, y: 0))
        flange.addCurve(to: CGPoint(x: 15, y: -26), control1: CGPoint(x: -33, y: -24), control2: CGPoint(x: -4, y: -33))
        flange.addQuadCurve(to: CGPoint(x: 41, y: -15), control: CGPoint(x: 27, y: -10))
        flange.addQuadCurve(to: CGPoint(x: 34, y: 0), control: CGPoint(x: 40, y: -5))
        flange.addQuadCurve(to: CGPoint(x: 41, y: 15), control: CGPoint(x: 40, y: 5))
        flange.addQuadCurve(to: CGPoint(x: 15, y: 26), control: CGPoint(x: 27, y: 10))
        flange.addCurve(to: CGPoint(x: -38, y: 0), control1: CGPoint(x: -4, y: 33), control2: CGPoint(x: -33, y: 24))
        flange.closeSubpath()
        StorybookArt.fillAndStroke(
            fish,
            flange,
            fill: StorybookArt.color(0xF6C775),
            stroke: StorybookArt.outline(for: 0xC88034),
            width: 2.8
        )

        var body = Path()
        body.move(to: CGPoint(x: -34, y: 0))
        body.addCurve(to: CGPoint(x: 13, y: -22), control1: CGPoint(x: -28, y: -20), control2: CGPoint(x: -3, y: -27))
        body.addQuadCurve(to: CGPoint(x: 36, y: -12), control: CGPoint(x: 24, y: -8))
        body.addQuadCurve(to: CGPoint(x: 30, y: 0), control: CGPoint(x: 35, y: -4))
        body.addQuadCurve(to: CGPoint(x: 36, y: 12), control: CGPoint(x: 35, y: 4))
        body.addQuadCurve(to: CGPoint(x: 13, y: 22), control: CGPoint(x: 24, y: 8))
        body.addCurve(to: CGPoint(x: -34, y: 0), control1: CGPoint(x: -3, y: 27), control2: CGPoint(x: -28, y: 20))
        body.closeSubpath()
        fish.fill(
            body,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFFE29B), StorybookArt.color(0xEAA349), StorybookArt.color(0xC97A2E)]),
                center: CGPoint(x: -10, y: -9),
                startRadius: 2,
                endRadius: 42
            )
        )

        var grid = fish
        grid.clip(to: body)
        var lines = Path()
        for k in -2...4 {
            let x = CGFloat(k) * 10 - 6
            lines.move(to: CGPoint(x: x - 14, y: -24))
            lines.addLine(to: CGPoint(x: x + 16, y: 24))
            lines.move(to: CGPoint(x: x + 16, y: -24))
            lines.addLine(to: CGPoint(x: x - 14, y: 24))
        }
        grid.stroke(lines, with: .color(StorybookArt.outline(for: 0xB86A22).opacity(0.45)), lineWidth: 1.8)
        fish.stroke(body, with: .color(StorybookArt.outline(for: 0xB86A22)), lineWidth: 2.6)

        let mouth = Path(ellipseIn: CGRect(x: -34, y: -3.5, width: 8, height: 7))
        StorybookArt.fillAndStroke(fish, mouth, fill: StorybookArt.color(0x7A3242), stroke: StorybookArt.outline(for: 0x5A202D), width: 1.8)
        var eye = Path()
        eye.addArc(center: CGPoint(x: -18, y: -4), radius: 4.2, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        fish.stroke(eye, with: .color(StorybookArt.outline(for: 0x7A421A)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        fish.fill(Path(ellipseIn: CGRect(x: -23, y: 1, width: 8, height: 5)), with: .color(StorybookArt.color(0xFF91B4, alpha: 0.65)))
        StorybookArt.highlight(fish, in: CGRect(x: -14, y: -16, width: 16, height: 6), opacity: 0.55)

        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -26), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 33, y: -24), radius: 6, color: Theme.pink)
    }

    private func drawKoreanStrawberryCake(_ g: GraphicsContext) {
        let creamOutline = StorybookArt.outline(for: 0xE6C8D6)
        let berryOutline = StorybookArt.outline(for: 0xC82442)

        // Delicate scalloped cake plate
        let plate = Path(ellipseIn: CGRect(x: -38, y: 26, width: 76, height: 14))
        StorybookArt.fillAndStroke(g, plate, fill: StorybookArt.color(0xFFF6FA), stroke: creamOutline, width: 2.6)

        // Fluffy white fresh-cream sponge body
        let body = Path(roundedRect: CGRect(x: -31, y: -14, width: 62, height: 44), cornerRadius: 11)
        StorybookArt.fillAndStroke(g, body, fill: StorybookArt.color(0xFFFDFB), stroke: creamOutline, width: 2.8)
        StorybookArt.highlight(g, in: CGRect(x: -24, y: -8, width: 14, height: 28), opacity: 0.8)

        // Pale blush cream seam + sliced ruby strawberries peeking out across the middle
        let seam = Path(roundedRect: CGRect(x: -30, y: 5, width: 60, height: 10), cornerRadius: 4)
        g.fill(seam, with: .color(StorybookArt.color(0xFFEAF2)))
        for sx in [-19.0, 0.0, 19.0] as [CGFloat] {
            let slice = Path(ellipseIn: CGRect(x: sx - 7.5, y: 4, width: 15, height: 12))
            StorybookArt.fillAndStroke(g, slice, fill: StorybookArt.color(0xEE3558), stroke: berryOutline, width: 1.8)
            g.fill(Path(ellipseIn: CGRect(x: sx - 3.5, y: 6.5, width: 7, height: 6.5)), with: .color(StorybookArt.color(0xFFE0E8)))
        }

        // Fluffy whipped-cream rosette ring across top edge
        for px in [-24.0, -12.0, 0.0, 12.0, 24.0] as [CGFloat] {
            let puff = Path(ellipseIn: CGRect(x: px - 8.5, y: -22, width: 17, height: 14))
            StorybookArt.fillAndStroke(g, puff, fill: .white, stroke: creamOutline, width: 2.2)
        }

        // Twin mint sprigs flanking the fresh strawberry crown
        for side in [-1.0, 1.0] as [CGFloat] {
            var leaf = Path()
            leaf.move(to: CGPoint(x: side * 8, y: -22))
            leaf.addQuadCurve(to: CGPoint(x: side * 24, y: -32), control: CGPoint(x: side * 12, y: -34))
            leaf.addQuadCurve(to: CGPoint(x: side * 8, y: -22), control: CGPoint(x: side * 20, y: -20))
            leaf.closeSubpath()
            StorybookArt.fillAndStroke(g, leaf, fill: StorybookArt.color(0x63C978), stroke: StorybookArt.outline(for: 0x45A85C), width: 1.8)
        }

        // Plump ruby strawberry crown perched on top
        let crownBerries: [(CGFloat, CGFloat, CGFloat)] = [(-13, -24, 9.5), (13, -24, 9.5), (0, -30, 11.5)]
        for (bx, by, br) in crownBerries {
            var berry = Path()
            berry.move(to: CGPoint(x: bx, y: by - br))
            berry.addCurve(to: CGPoint(x: bx, y: by + br * 0.85), control1: CGPoint(x: bx + br * 1.1, y: by - br * 0.4), control2: CGPoint(x: bx + br * 0.9, y: by + br * 0.75))
            berry.addCurve(to: CGPoint(x: bx, y: by - br), control1: CGPoint(x: bx - br * 0.9, y: by + br * 0.75), control2: CGPoint(x: bx - br * 1.1, y: by - br * 0.4))
            berry.closeSubpath()
            StorybookArt.fillAndStroke(g, berry, fill: StorybookArt.color(0xF03858), stroke: berryOutline, width: 2)
            StorybookArt.highlight(g, in: CGRect(x: bx - br * 0.45, y: by - br * 0.45, width: br * 0.45, height: br * 0.3), opacity: 0.78)
        }

        StorybookArt.sparkle(g, at: CGPoint(x: -35, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 35, y: -20), radius: 6.5, color: Theme.pink)
    }

    private func drawFiveStarBaker(_ g: GraphicsContext) {
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-21, -2, 15), (21, -2, 15), (-10, -14, 17), (10, -14, 17), (0, -18, 18),
        ]
        let toqueOutline = StorybookArt.outline(for: 0xE6D8EC)
        for (px, py, pr) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                     with: .color(toqueOutline), lineWidth: 6.5)
        }
        for (px, py, pr) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                   with: .color(StorybookArt.color(0xFFFDFB)))
        }
        StorybookArt.highlight(g, in: CGRect(x: -16, y: -24, width: 16, height: 8), opacity: 0.85)

        let band = Path(roundedRect: CGRect(x: -26, y: 6, width: 52, height: 24), cornerRadius: 8)
        StorybookArt.fillAndStroke(g, band, fill: StorybookArt.color(0xFFF9F4), stroke: toqueOutline, width: 3.2)
        let ribbon = Path(roundedRect: CGRect(x: -25, y: 17, width: 50, height: 10), cornerRadius: 4)
        StorybookArt.fillAndStroke(g, ribbon, fill: StorybookArt.color(0xFF9EC4), stroke: StorybookArt.outline(for: 0xE876A4), width: 2.2)

        let stars: [(CGFloat, CGFloat, CGFloat)] = [(-26, -28, 9), (0, -37, 11.5), (26, -28, 9)]
        for (sx, sy, sr) in stars {
            drawStar(g, at: CGPoint(x: sx, y: sy), radius: sr, fill: 0xFFE06B, outline: 0xD99622)
        }
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 22), size: 10, color: .white)
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
