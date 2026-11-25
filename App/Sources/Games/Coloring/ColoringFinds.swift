import SwiftUI

enum ColoringFind: String, CaseIterable {
    case firstMasterpiece
    case glitterArtist
    case rainbowPainter
    case colorMixer
    case stickerStar
    case watercolorDream

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
        case .firstMasterpiece:
            drawFirstMasterpiece(g)
        case .glitterArtist:
            drawGlitterArtist(g)
        case .rainbowPainter:
            drawRainbowPainter(g)
        case .colorMixer:
            drawColorMixer(g)
        case .stickerStar:
            drawStickerStar(g)
        case .watercolorDream:
            drawWatercolorDream(g)
        }
    }

    private func drawFirstMasterpiece(_ g: GraphicsContext) {
        let woodStroke = StorybookArt.outline(for: 0xD69D66)
        let woodFill = StorybookArt.color(0xEBB986)

        // Easel legs behind canvas
        let legSpecs: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: -34), CGPoint(x: -22, y: 38)),
            (CGPoint(x: 0, y: -34), CGPoint(x: 22, y: 38)),
            (CGPoint(x: 0, y: -36), CGPoint(x: 0, y: 34)),
        ]
        for (a, b) in legSpecs {
            var leg = Path()
            leg.move(to: a)
            leg.addLine(to: b)
            g.stroke(leg, with: .color(woodStroke), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
            g.stroke(leg, with: .color(woodFill), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        }

        // Golden framed painting
        let frameRect = CGRect(x: -28, y: -26, width: 56, height: 42)
        let frame = Path(roundedRect: frameRect, cornerRadius: 9)
        StorybookArt.fillAndStroke(
            g,
            frame,
            fill: StorybookArt.color(0xFFE07A),
            stroke: StorybookArt.outline(for: 0xE5AA38),
            width: 3.4
        )
        let canvasRect = frameRect.insetBy(dx: 5.5, dy: 5.5)
        let canvas = Path(roundedRect: canvasRect, cornerRadius: 5)
        StorybookArt.fillAndStroke(
            g,
            canvas,
            fill: StorybookArt.color(0xFFFDF8),
            stroke: StorybookArt.outline(for: 0xE5AA38),
            width: 1.8
        )

        // Mini rainbow + heart painted inside the frame
        var art = g
        art.clip(to: canvas)
        let bands: [(CGFloat, UInt32)] = [(20, 0xFF8FB8), (15.5, 0xFFE07D), (11, 0x8CE3C4), (6.5, 0x8EC8FF)]
        for (rad, hex) in bands {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: 12), radius: rad, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
            art.stroke(arc, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 4.8, lineCap: .round))
        }
        StorybookArt.heart(art, at: CGPoint(x: 0, y: 4), size: 11, color: Theme.pink)

        // Wooden ledge
        let ledge = Path(roundedRect: CGRect(x: -31, y: 14, width: 62, height: 8), cornerRadius: 4)
        StorybookArt.fillAndStroke(g, ledge, fill: woodFill, stroke: woodStroke, width: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: -22, y: -23, width: 20, height: 4), opacity: 0.65)

        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -28), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -22), radius: 6.5, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: 26), radius: 5.5, color: Theme.sky)
    }

    private func drawGlitterArtist(_ g: GraphicsContext) {
        // Glitter ribbon swirl squeezed out
        var ribbon = Path()
        ribbon.move(to: CGPoint(x: -30, y: 26))
        ribbon.addCurve(to: CGPoint(x: 4, y: 16), control1: CGPoint(x: -22, y: 8), control2: CGPoint(x: -8, y: 34))
        ribbon.addCurve(to: CGPoint(x: 32, y: 24), control1: CGPoint(x: 14, y: 2), control2: CGPoint(x: 24, y: 32))
        g.stroke(ribbon, with: .color(StorybookArt.outline(for: 0xC49BFF)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        g.stroke(ribbon, with: .color(StorybookArt.color(0xDFC2FF)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        g.stroke(ribbon, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

        // Tilted glitter glue bottle
        var bottle = g
        bottle.translateBy(x: 2, y: -8)
        bottle.rotate(by: .degrees(-34))

        var tip = Path()
        tip.move(to: CGPoint(x: -5, y: 14))
        tip.addLine(to: CGPoint(x: 0, y: 29))
        tip.addLine(to: CGPoint(x: 5, y: 14))
        tip.closeSubpath()
        StorybookArt.fillAndStroke(bottle, tip, fill: StorybookArt.color(0xFFF6FC), stroke: StorybookArt.outline(for: 0xC9B6FF), width: 2.4)

        let cap = Path(roundedRect: CGRect(x: -9, y: 8, width: 18, height: 8), cornerRadius: 3)
        StorybookArt.fillAndStroke(bottle, cap, fill: StorybookArt.color(0xFFE07D), stroke: StorybookArt.outline(for: 0xE5AA38), width: 2.4)

        let body = Path(roundedRect: CGRect(x: -14, y: -25, width: 28, height: 35), cornerRadius: 11)
        StorybookArt.fillAndStroke(bottle, body, fill: StorybookArt.color(0xFF9AC9), stroke: StorybookArt.outline(for: 0xF06BA8), width: 3.2)

        // Inner glitter speckles on tube
        let specks: [(CGFloat, CGFloat, Color)] = [
            (-5, -14, .white), (4, -17, Theme.lemon), (6, -6, .white),
            (-6, -2, Theme.lemon), (1, -9, Theme.sky), (-2, 2, .white),
        ]
        for (sx, sy, col) in specks {
            StorybookArt.sparkle(bottle, at: CGPoint(x: sx, y: sy), radius: 4, color: col)
        }
        StorybookArt.highlight(bottle, in: CGRect(x: -10, y: -21, width: 6, height: 22), opacity: 0.45)

        // Surrounding twinkling stars
        StorybookArt.sparkle(g, at: CGPoint(x: -28, y: -22), radius: 8.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 31, y: -24), radius: 7, color: Theme.sky)
        StorybookArt.sparkle(g, at: CGPoint(x: -16, y: 20), radius: 6, color: .white)
        StorybookArt.sparkle(g, at: CGPoint(x: 18, y: 14), radius: 6, color: Theme.lemon)
    }

    private func drawRainbowPainter(_ g: GraphicsContext) {
        let bands: [(CGFloat, UInt32)] = [
            (32, 0xFF7FA8),
            (26.5, 0xFFB078),
            (21, 0xFFE378),
            (15.5, 0x8AE3BD),
            (10, 0x82C4FF),
        ]
        let center = CGPoint(x: 0, y: 18)

        // Outer soft contour behind rainbow
        var outerArc = Path()
        outerArc.addArc(center: center, radius: 32, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
        g.stroke(outerArc, with: .color(StorybookArt.outline(for: 0xFF7FA8)), style: StrokeStyle(lineWidth: 11, lineCap: .round))

        for (r, hex) in bands {
            var arc = Path()
            arc.addArc(center: center, radius: r, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 6.4, lineCap: .round))
        }

        // Fluffy clouds at both ends
        for side in [-1.0, 1.0] {
            let cx = CGFloat(side) * 24
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [
                (cx - 8, 22, 8.5), (cx, 17, 10.5), (cx + 8, 22, 8.5),
            ]
            for (px, py, pr) in puffs {
                g.stroke(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                         with: .color(StorybookArt.outline(for: 0xA8D4FF)), lineWidth: 5)
            }
            for (px, py, pr) in puffs {
                g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(.white))
            }
        }

        // Little paintbrush sweeping across the top
        var brush = g
        brush.translateBy(x: 16, y: -16)
        brush.rotate(by: .degrees(-38))
        let handle = Path(roundedRect: CGRect(x: 0, y: -4.5, width: 26, height: 9), cornerRadius: 4.5)
        StorybookArt.fillAndStroke(brush, handle, fill: StorybookArt.color(0xFF9AC9), stroke: StorybookArt.outline(for: 0xFF7EA8), width: 2.5)
        let ferrule = Path(roundedRect: CGRect(x: -7, y: -5, width: 9, height: 10), cornerRadius: 2.5)
        StorybookArt.fillAndStroke(brush, ferrule, fill: StorybookArt.color(0xFFE49C), stroke: StorybookArt.outline(for: 0xE5AA38), width: 2.2)
        var tip = Path()
        tip.move(to: CGPoint(x: -7, y: -5))
        tip.addQuadCurve(to: CGPoint(x: -20, y: 0), control: CGPoint(x: -14, y: -6))
        tip.addQuadCurve(to: CGPoint(x: -7, y: 5), control: CGPoint(x: -14, y: 6))
        tip.closeSubpath()
        StorybookArt.fillAndStroke(brush, tip, fill: StorybookArt.color(0x9ED4FF), stroke: StorybookArt.outline(for: 0x6AAEE8), width: 2.2)

        StorybookArt.sparkle(g, at: CGPoint(x: -28, y: -24), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -32), radius: 6, color: .white)
    }

    private func drawColorMixer(_ g: GraphicsContext) {
        var palette = Path()
        palette.move(to: CGPoint(x: -35, y: 2))
        palette.addCurve(to: CGPoint(x: -2, y: -33), control1: CGPoint(x: -35, y: -22), control2: CGPoint(x: -22, y: -33))
        palette.addCurve(to: CGPoint(x: 36, y: -6), control1: CGPoint(x: 20, y: -33), control2: CGPoint(x: 36, y: -22))
        palette.addCurve(to: CGPoint(x: 20, y: 12), control1: CGPoint(x: 36, y: 6), control2: CGPoint(x: 28, y: 10))
        palette.addCurve(to: CGPoint(x: 28, y: 29), control1: CGPoint(x: 13, y: 15), control2: CGPoint(x: 34, y: 20))
        palette.addCurve(to: CGPoint(x: -4, y: 36), control1: CGPoint(x: 22, y: 37), control2: CGPoint(x: 8, y: 36))
        palette.addCurve(to: CGPoint(x: -35, y: 2), control1: CGPoint(x: -24, y: 36), control2: CGPoint(x: -35, y: 22))
        palette.closeSubpath()

        StorybookArt.fillAndStroke(
            g,
            palette,
            fill: StorybookArt.color(0xFBF0DF),
            stroke: StorybookArt.outline(for: 0xE6C39A),
            width: 3.4
        )
        StorybookArt.highlight(g, in: CGRect(x: -24, y: -26, width: 22, height: 7), opacity: 0.65)

        // Thumb hole
        let hole = Path(ellipseIn: CGRect(x: -18, y: 13, width: 13, height: 10))
        StorybookArt.fillAndStroke(g, hole, fill: StorybookArt.color(0xE8DCFF), stroke: StorybookArt.outline(for: 0xE6C39A), width: 2.2)

        // Surrounding pure paint drops
        let drops: [(CGFloat, CGFloat, UInt32)] = [
            (-21, -2, 0xFF7AA8), (-13, -18, 0xFFE070), (6, -21, 0x7EC8FF), (21, -11, 0xC59CFF),
        ]
        for (x, y, hex) in drops {
            let r = CGRect(x: x - 6.5, y: y - 5.5, width: 13, height: 11)
            StorybookArt.shape(g, Path(ellipseIn: r), hex: hex, width: 2)
            StorybookArt.highlight(g, in: CGRect(x: x - 3.5, y: y - 3.5, width: 4, height: 2.5), opacity: 0.7)
        }

        // Swirled mixed paint puddle in the center
        let swirlRect = CGRect(x: -10, y: -8, width: 24, height: 21)
        let swirl = Path(ellipseIn: swirlRect)
        let grad = Gradient(colors: [
            StorybookArt.color(0xFF8FB8),
            StorybookArt.color(0xFFE38A),
            StorybookArt.color(0x9FE3CF),
            StorybookArt.color(0x9CCBFF),
            StorybookArt.color(0xC9B6FF),
            StorybookArt.color(0xFF8FB8),
        ])
        g.fill(swirl, with: .conicGradient(grad, center: CGPoint(x: 2, y: 2.5), angle: .degrees(20)))
        g.stroke(swirl, with: .color(StorybookArt.outline(for: 0xFF8FB8)), lineWidth: 2.4)
        StorybookArt.highlight(g, in: CGRect(x: -4, y: -4, width: 8, height: 4.5), opacity: 0.7)

        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -26), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: 24), radius: 6, color: Theme.pink)
    }

    private func drawStickerStar(_ g: GraphicsContext) {
        // Plump rounded 5-point star
        var star = Path()
        let outerR: CGFloat = 35
        let innerR: CGFloat = 17.5
        for i in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r + 2)
            if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()

        StorybookArt.fillAndStroke(
            g,
            star,
            fill: StorybookArt.color(0xFFE16B),
            stroke: StorybookArt.outline(for: 0xE6A732),
            width: 3.6
        )
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -16, width: 14, height: 8), opacity: 0.65)

        // Cute smiling face
        for side in [-1.0, 1.0] {
            let ex = CGFloat(side) * 8.5
            g.fill(Path(ellipseIn: CGRect(x: ex - 3, y: -4, width: 6, height: 7)), with: .color(Theme.ink))
            g.fill(Path(ellipseIn: CGRect(x: ex - 1.2, y: -3, width: 2.2, height: 2.2)), with: .color(.white))
            g.fill(Path(ellipseIn: CGRect(x: ex - 5.5, y: 4.5, width: 9, height: 5)), with: .color(Theme.pink.opacity(0.65)))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -4.5, y: 5.5))
        smile.addQuadCurve(to: CGPoint(x: 4.5, y: 5.5), control: CGPoint(x: 0, y: 11.5))
        g.stroke(smile, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Folded sticker peel-up accent at bottom-right tip
        var peel = Path()
        peel.move(to: CGPoint(x: 13, y: 24))
        peel.addLine(to: CGPoint(x: 24, y: 16))
        peel.addLine(to: CGPoint(x: 21, y: 31))
        peel.closeSubpath()
        StorybookArt.fillAndStroke(g, peel, fill: .white, stroke: StorybookArt.outline(for: 0xE6A732), width: 2)

        StorybookArt.heart(g, at: CGPoint(x: -30, y: -22), size: 12, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 31, y: -22), radius: 7, color: Theme.sky)
    }

    private func drawWatercolorDream(_ g: GraphicsContext) {
        // Soft layered watercolor cloud washes
        let washes: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (-16, 4, 21, 0xFF9AC9),
            (15, 6, 20, 0x8FD0FF),
            (0, -10, 21, 0xFFE68A),
            (-2, 12, 18, 0xC9B6FF),
        ]
        for (x, y, r, hex) in washes {
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            g.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [StorybookArt.color(hex, alpha: 0.85), StorybookArt.color(hex, alpha: 0.4)]),
                center: CGPoint(x: x, y: y),
                startRadius: 2,
                endRadius: r
            ))
            g.stroke(Path(ellipseIn: rect), with: .color(StorybookArt.outline(for: hex).opacity(0.45)), lineWidth: 2.2)
        }

        // Cute droplets
        let drops: [(CGFloat, CGFloat, UInt32)] = [(-28, -22, 0xFF8FB8), (28, -20, 0x8FD0FF), (30, 22, 0x9FE3CF)]
        for (x, y, hex) in drops {
            var d = Path()
            d.move(to: CGPoint(x: x, y: y - 7))
            d.addQuadCurve(to: CGPoint(x: x + 5.5, y: y + 2), control: CGPoint(x: x + 6, y: y - 1))
            d.addArc(center: CGPoint(x: x, y: y + 2), radius: 5.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            d.addQuadCurve(to: CGPoint(x: x, y: y - 7), control: CGPoint(x: x - 6, y: y - 1))
            d.closeSubpath()
            StorybookArt.shape(g, d, hex: hex, width: 2)
        }

        // Pointed watercolor brush across center
        var b = g
        b.translateBy(x: 4, y: 2)
        b.rotate(by: .degrees(-42))
        let handle = Path(roundedRect: CGRect(x: -2, y: -4.5, width: 32, height: 9), cornerRadius: 4.5)
        StorybookArt.fillAndStroke(b, handle, fill: StorybookArt.color(0x98D2FF), stroke: StorybookArt.outline(for: 0x62A8E5), width: 2.6)
        let ferrule = Path(roundedRect: CGRect(x: -10, y: -5, width: 10, height: 10), cornerRadius: 2.5)
        StorybookArt.fillAndStroke(b, ferrule, fill: StorybookArt.color(0xFFE6A0), stroke: StorybookArt.outline(for: 0xE5AA38), width: 2.4)
        var bristles = Path()
        bristles.move(to: CGPoint(x: -10, y: -5.5))
        bristles.addCurve(to: CGPoint(x: -26, y: 0), control1: CGPoint(x: -17, y: -7.5), control2: CGPoint(x: -22, y: -3))
        bristles.addCurve(to: CGPoint(x: -10, y: 5.5), control1: CGPoint(x: -22, y: 3), control2: CGPoint(x: -17, y: 7.5))
        bristles.closeSubpath()
        StorybookArt.fillAndStroke(b, bristles, fill: StorybookArt.color(0xFF8FB8), stroke: StorybookArt.outline(for: 0xE56092), width: 2.5)
        StorybookArt.highlight(b, in: CGRect(x: 4, y: -2.5, width: 16, height: 3), opacity: 0.6)

        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -33), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -30, y: 25), radius: 6, color: .white)
    }
}
