import SwiftUI

enum SpaFind: String, CaseIterable {
    case rainbowBath
    case bubbleCrown
    case sneezeGiggle
    case cucumberZen
    case strawberryMask
    case whaleFountain
    case starPopper
    case cozyWrap

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
        case .rainbowBath:
            drawRainbowBath(g)
        case .bubbleCrown:
            drawBubbleCrown(g)
        case .sneezeGiggle:
            drawSneezeGiggle(g)
        case .cucumberZen:
            drawCucumberZen(g)
        case .strawberryMask:
            drawStrawberryMask(g)
        case .whaleFountain:
            drawWhaleFountain(g)
        case .starPopper:
            drawStarPopper(g)
        case .cozyWrap:
            drawCozyWrap(g)
        }
    }

    private func drawRainbowBath(_ g: GraphicsContext) {
        let r: CGFloat = 29
        let sphere = Path(ellipseIn: CGRect(x: -r, y: -r + 4, width: r * 2, height: r * 2))
        let rainbow = Gradient(colors: [
            StorybookArt.color(0xFF7FB3),
            StorybookArt.color(0xFFC86B),
            StorybookArt.color(0xFFE885),
            StorybookArt.color(0x88E5B8),
            StorybookArt.color(0x7EC8FF),
            StorybookArt.color(0xC39BFF),
            StorybookArt.color(0xFF7FB3),
        ])
        g.fill(sphere, with: .conicGradient(rainbow, center: CGPoint(x: 0, y: 4), angle: .degrees(-35)))
        g.stroke(sphere, with: .color(StorybookArt.outline(for: 0xFF8FB8)), lineWidth: 3.5)

        let band = Path(roundedRect: CGRect(x: -r + 2, y: -1, width: (r - 2) * 2, height: 10), cornerRadius: 5)
        var clipped = g
        clipped.clip(to: sphere)
        clipped.fill(band, with: .color(.white.opacity(0.45)))

        StorybookArt.highlight(g, in: CGRect(x: -17, y: -17, width: 16, height: 10), opacity: 0.72)

        let bubbles: [(CGFloat, CGFloat, CGFloat)] = [(-24, -24, 8), (24, -20, 10), (14, -34, 6)]
        for (x, y, br) in bubbles {
            let b = Path(ellipseIn: CGRect(x: x - br, y: y - br, width: br * 2, height: br * 2))
            StorybookArt.fillAndStroke(g, b, fill: StorybookArt.color(0xE8F8FF, alpha: 0.9), stroke: StorybookArt.outline(for: 0x8FD0FF), width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: x - br * 0.5, y: y - br * 0.6, width: br * 0.55, height: br * 0.35), opacity: 0.85)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -29, y: 20), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 31, y: 12), radius: 6, color: Theme.pink)
    }

    private func drawBubbleCrown(_ g: GraphicsContext) {
        let band = Path(roundedRect: CGRect(x: -32, y: 8, width: 64, height: 18), cornerRadius: 9)
        StorybookArt.fillAndStroke(
            g,
            band,
            fill: StorybookArt.color(0xFFD76A),
            stroke: StorybookArt.outline(for: 0xE6A93B),
            width: 3.2
        )
        StorybookArt.highlight(g, in: CGRect(x: -24, y: 11, width: 24, height: 5), opacity: 0.6)

        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-24, -2, 13), (24, -2, 13),
            (-12, -14, 15), (12, -14, 15),
            (0, -22, 17),
        ]
        for (px, py, pr) in puffs {
            let p = Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
            g.stroke(p, with: .color(StorybookArt.outline(for: 0xB8DCFF)), lineWidth: 6)
        }
        for (px, py, pr) in puffs {
            let p = Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
            g.fill(p, with: .radialGradient(
                Gradient(colors: [.white, StorybookArt.color(0xE6F4FF)]),
                center: CGPoint(x: px - pr * 0.3, y: py - pr * 0.35),
                startRadius: 1,
                endRadius: pr * 1.3
            ))
            StorybookArt.highlight(g, in: CGRect(x: px - pr * 0.55, y: py - pr * 0.65, width: pr * 0.55, height: pr * 0.35), opacity: 0.9)
        }

        StorybookArt.heart(g, at: CGPoint(x: 0, y: 17), size: 12, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -38), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -18), radius: 6, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 35, y: -16), radius: 6, color: Theme.sky)
    }

    private func drawSneezeGiggle(_ g: GraphicsContext) {
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-18, 6, 16), (0, -4, 21), (18, 6, 16), (-8, 15, 14), (10, 15, 14),
        ]
        for (px, py, pr) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                     with: .color(StorybookArt.outline(for: 0xFFBCD8)), lineWidth: 6.5)
        }
        for (px, py, pr) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                   with: .color(StorybookArt.color(0xFFF6FA)))
        }
        // Happy squinting sneeze face on the foam puff
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side) * 11
            var eye = Path()
            eye.move(to: CGPoint(x: sx - 5, y: 1))
            eye.addLine(to: CGPoint(x: sx, y: 4))
            eye.addLine(to: CGPoint(x: sx + 5, y: 1))
            g.stroke(eye, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
            g.fill(Path(ellipseIn: CGRect(x: sx - 5.5, y: 7, width: 11, height: 6)), with: .color(Theme.pink.opacity(0.6)))
        }
        let mouth = Path(ellipseIn: CGRect(x: -5, y: 9, width: 10, height: 9))
        StorybookArt.fillAndStroke(g, mouth, fill: Theme.pink, stroke: Theme.ink, width: 2.2)

        // Bursting sneeze bubbles
        let burst: [(CGFloat, CGFloat, CGFloat)] = [(-30, -20, 8), (0, -34, 9), (29, -22, 7.5), (34, -4, 5.5)]
        for (bx, by, br) in burst {
            let bp = Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2))
            StorybookArt.fillAndStroke(g, bp, fill: StorybookArt.color(0xD8F2FF), stroke: StorybookArt.outline(for: 0x8ACBFF), width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: bx - br * 0.5, y: by - br * 0.55, width: br * 0.5, height: br * 0.35), opacity: 0.85)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: 20), radius: 6.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: 20), radius: 6.5, color: Theme.lemon)
    }

    private func drawCucumberZen(_ g: GraphicsContext) {
        let centers: [(CGFloat, CGFloat)] = [(-18, 2), (18, -2)]
        for (cx, cy) in centers {
            var c = g
            c.translateBy(x: cx, y: cy)
            let r: CGFloat = 22
            StorybookArt.fillAndStroke(
                c,
                Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)),
                fill: StorybookArt.color(0x52B363),
                stroke: StorybookArt.outline(for: 0x3E9A4E),
                width: 3
            )
            c.fill(Path(ellipseIn: CGRect(x: -r * 0.8, y: -r * 0.8, width: r * 1.6, height: r * 1.6)),
                   with: .color(StorybookArt.color(0xC6F2A6)))
            c.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.55, width: r * 1.1, height: r * 1.1)),
                   with: .color(StorybookArt.color(0xEEFAD2)))
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * 2 * .pi
                let sx = cos(a) * r * 0.34, sy = sin(a) * r * 0.34
                c.fill(Path(ellipseIn: CGRect(x: sx - 2, y: sy - 3, width: 4, height: 6)),
                       with: .color(StorybookArt.color(0x9FD47E)))
            }
            StorybookArt.highlight(c, in: CGRect(x: -r * 0.55, y: -r * 0.62, width: r * 0.5, height: r * 0.28), opacity: 0.7)
        }
        // Gentle peaceful smile underneath
        var smile = Path()
        smile.move(to: CGPoint(x: -10, y: 28))
        smile.addQuadCurve(to: CGPoint(x: 10, y: 28), control: CGPoint(x: 0, y: 37))
        g.stroke(smile, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -32), radius: 8, color: Theme.lemon)
        StorybookArt.heart(g, at: CGPoint(x: -33, y: -24), size: 12, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: 24), radius: 6, color: Theme.mint)
    }

    private func drawStrawberryMask(_ g: GraphicsContext) {
        let jar = Path(roundedRect: CGRect(x: -28, y: -6, width: 56, height: 38), cornerRadius: 15)
        StorybookArt.fillAndStroke(
            g,
            jar,
            fill: StorybookArt.color(0xFFF6FA),
            stroke: StorybookArt.outline(for: 0xF0A8C4),
            width: 3.2
        )
        let cream = Path(ellipseIn: CGRect(x: -25, y: -22, width: 50, height: 26))
        StorybookArt.fillAndStroke(
            g,
            cream,
            fill: StorybookArt.color(0xFF9AC0),
            stroke: StorybookArt.outline(for: 0xFF7CA8),
            width: 3
        )
        let swirl = Path(ellipseIn: CGRect(x: -13, y: -30, width: 26, height: 15))
        StorybookArt.fillAndStroke(
            g,
            swirl,
            fill: StorybookArt.color(0xFFB5D2),
            stroke: StorybookArt.outline(for: 0xFF7CA8),
            width: 2.5
        )
        StorybookArt.highlight(g, in: CGRect(x: -15, y: -17, width: 14, height: 6), opacity: 0.7)

        // Cute strawberry badge on the jar front
        var berry = Path()
        berry.move(to: CGPoint(x: 0, y: 24))
        berry.addCurve(to: CGPoint(x: -12, y: 8), control1: CGPoint(x: -10, y: 22), control2: CGPoint(x: -14, y: 14))
        berry.addCurve(to: CGPoint(x: 0, y: 3), control1: CGPoint(x: -10, y: 2), control2: CGPoint(x: -4, y: 3))
        berry.addCurve(to: CGPoint(x: 12, y: 8), control1: CGPoint(x: 4, y: 3), control2: CGPoint(x: 10, y: 2))
        berry.addCurve(to: CGPoint(x: 0, y: 24), control1: CGPoint(x: 14, y: 14), control2: CGPoint(x: 10, y: 22))
        berry.closeSubpath()
        StorybookArt.fillAndStroke(g, berry, fill: StorybookArt.color(0xFF6B8A), stroke: StorybookArt.outline(for: 0xE64B6D), width: 2.4)

        var leaf = Path()
        leaf.move(to: CGPoint(x: -8, y: 4))
        leaf.addLine(to: CGPoint(x: 0, y: -1))
        leaf.addLine(to: CGPoint(x: 8, y: 4))
        leaf.addLine(to: CGPoint(x: 0, y: 7))
        leaf.closeSubpath()
        g.fill(leaf, with: .color(StorybookArt.color(0x68C779)))

        for (sx, sy) in [(-4.0, 11.0), (4.0, 11.0), (0.0, 16.0)] {
            g.fill(Path(ellipseIn: CGRect(x: sx - 1.3, y: sy - 1.8, width: 2.6, height: 3.6)), with: .color(Theme.lemon))
        }
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -18), radius: 5.5, color: Theme.pink)
    }

    private func drawWhaleFountain(_ g: GraphicsContext) {
        // Fountain arcs
        for side in [-1.0, 1.0] {
            var arc = Path()
            arc.move(to: CGPoint(x: 2, y: -4))
            arc.addQuadCurve(to: CGPoint(x: CGFloat(side) * 24, y: -26), control: CGPoint(x: CGFloat(side) * 8, y: -40))
            g.stroke(arc, with: .color(StorybookArt.color(0x7FD6FF)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            g.stroke(arc, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            let drop = Path(ellipseIn: CGRect(x: CGFloat(side) * 25 - 4.5, y: -26, width: 9, height: 11))
            StorybookArt.fillAndStroke(g, drop, fill: StorybookArt.color(0xA6E4FF), stroke: StorybookArt.outline(for: 0x6BBDF0), width: 2)
        }
        StorybookArt.heart(g, at: CGPoint(x: 2, y: -38), size: 12, color: Theme.pink)

        var w = g
        w.translateBy(x: 4, y: 14)
        w.scaleBy(x: 0.68, y: 0.68)
        ThingPainter.whale(w)
    }

    private func drawStarPopper(_ g: GraphicsContext) {
        let r: CGFloat = 34
        let rect = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
        let film = Gradient(colors: [
            StorybookArt.color(0xFF9ECF),
            StorybookArt.color(0xFFE38A),
            StorybookArt.color(0x9FF0D8),
            StorybookArt.color(0x8FC6FF),
            StorybookArt.color(0xC9A6FF),
            StorybookArt.color(0xFF9ECF),
        ])
        g.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [StorybookArt.color(0xC59EFF, alpha: 0.25), StorybookArt.color(0x9769DF, alpha: 0.55)]),
            center: .zero,
            startRadius: 4,
            endRadius: r
        ))
        g.stroke(Path(ellipseIn: rect), with: .conicGradient(film, center: .zero, angle: .degrees(30)), lineWidth: 5)
        StorybookArt.highlight(g, in: CGRect(x: -22, y: -23, width: 16, height: 10), opacity: 0.85)

        var star = Path()
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let rr: CGFloat = k.isMultiple(of: 2) ? 20 : 9.5
            let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            star,
            fill: StorybookArt.color(0xFFE378),
            stroke: StorybookArt.outline(for: 0xE6A93B),
            width: 2.8
        )
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -28), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -35, y: 24), radius: 6, color: Theme.pink)
    }

    private func drawCozyWrap(_ g: GraphicsContext) {
        let base = Path(roundedRect: CGRect(x: -33, y: -14, width: 66, height: 42), cornerRadius: 14)
        StorybookArt.fillAndStroke(
            g,
            base,
            fill: StorybookArt.color(0xFFB3CF),
            stroke: StorybookArt.outline(for: 0xF084AE),
            width: 3.4
        )
        let fold = Path(roundedRect: CGRect(x: -35, y: -22, width: 70, height: 22), cornerRadius: 11)
        StorybookArt.fillAndStroke(
            g,
            fold,
            fill: StorybookArt.color(0xFFD0E2),
            stroke: StorybookArt.outline(for: 0xF084AE),
            width: 3.2
        )
        g.fill(Path(CGRect(x: -31, y: 12, width: 62, height: 6)), with: .color(.white.opacity(0.85)))
        StorybookArt.highlight(g, in: CGRect(x: -24, y: -18, width: 22, height: 6), opacity: 0.7)

        // Ribbon bow on top
        for side in [-1.0, 1.0] {
            let loop = Path(ellipseIn: CGRect(x: side < 0 ? -19 : 3, y: -33, width: 16, height: 12))
            StorybookArt.fillAndStroke(g, loop, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 2.4)
        }
        let knot = Path(ellipseIn: CGRect(x: -6, y: -31, width: 12, height: 10))
        StorybookArt.fillAndStroke(g, knot, fill: StorybookArt.color(0xFFD15C), stroke: StorybookArt.outline(for: 0xE6A93B), width: 2.4)

        StorybookArt.heart(g, at: CGPoint(x: -28, y: -32), size: 13, color: Theme.pink)
        StorybookArt.heart(g, at: CGPoint(x: 30, y: -26), size: 11, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 33, y: 24), radius: 6, color: Theme.lemon)
    }
}
