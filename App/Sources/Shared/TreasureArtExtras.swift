import SwiftUI

// MARK: - Extra treasure drawings (25 shop treasures across all 13 games)
//
// Each drawing stands on (0, 0) and goes up into negative y, matching `TreasureArt`.

extension TreasureArt {
    // MARK: Garden — Lotus lantern (연등)

    static let lotusSize = CGSize(width: 116, height: 116)

    static func lotusLantern(_ g: GraphicsContext) {
        g.fill(
            oval(0, -64, 52, 48),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE99A).opacity(0.75), Color(hex: 0xFFD4EC).opacity(0.32), .clear]),
                center: CGPoint(x: 0, y: -64),
                startRadius: 6,
                endRadius: 52
            )
        )
        let padLine = StorybookArt.outline(for: 0x7ED1A0)
        blob(g, oval(0, -8, 46, 9), Color(hex: 0x8FE0B0), padLine, 2.6)
        g.fill(oval(-10, -10, 22, 3.5), with: .color(.white.opacity(0.42)))
        blob(g, rrect(-22, -18, 44, 10, 5), gold, goldLine, 2.2)

        func petal(_ angle: Double, _ w: CGFloat, _ h: CGFloat, _ yBase: CGFloat, _ fill: Color, _ stroke: Color) {
            var c = g
            c.translateBy(x: 0, y: yBase)
            c.rotate(by: .degrees(angle))
            var p = Path()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addCurve(to: CGPoint(x: 0, y: -h), control1: CGPoint(x: -w, y: -h * 0.25), control2: CGPoint(x: -w * 0.72, y: -h * 0.78))
            p.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: w * 0.72, y: -h * 0.78), control2: CGPoint(x: w, y: -h * 0.25))
            p.closeSubpath()
            blob(c, p, fill, stroke, 2.4)
            c.fill(oval(-w * 0.16, -h * 0.56, w * 0.18, h * 0.2), with: .color(.white.opacity(0.42)))
        }

        let roseLine = StorybookArt.outline(for: 0xFF8CB8)
        let blushLine = StorybookArt.outline(for: 0xFFAEC9)

        var flame = Path()
        flame.move(to: CGPoint(x: 0, y: -62))
        flame.addCurve(to: CGPoint(x: 0, y: -106), control1: CGPoint(x: -16, y: -74), control2: CGPoint(x: -11, y: -94))
        flame.addCurve(to: CGPoint(x: 0, y: -62), control1: CGPoint(x: 11, y: -94), control2: CGPoint(x: 16, y: -74))
        flame.closeSubpath()
        blob(g, flame, Color(hex: 0xFFCE4A), goldLine, 2.4)
        var core = Path()
        core.move(to: CGPoint(x: 0, y: -68))
        core.addCurve(to: CGPoint(x: 0, y: -94), control1: CGPoint(x: -7, y: -75), control2: CGPoint(x: -5, y: -88))
        core.addCurve(to: CGPoint(x: 0, y: -68), control1: CGPoint(x: 5, y: -88), control2: CGPoint(x: 7, y: -75))
        core.closeSubpath()
        g.fill(core, with: .color(Color(hex: 0xFFFBE6)))

        petal(-44, 20, 56, -16, Color(hex: 0xFF9AC2), roseLine)
        petal(44, 20, 56, -16, Color(hex: 0xFF9AC2), roseLine)
        petal(-22, 22, 62, -16, Color(hex: 0xFFB3CF), blushLine)
        petal(22, 22, 62, -16, Color(hex: 0xFFB3CF), blushLine)
        petal(0, 23, 60, -14, Color(hex: 0xFFD4E5), blushLine)
        petal(-32, 16, 40, -12, Color(hex: 0xFFE3EE), blushLine)
        petal(32, 16, 40, -12, Color(hex: 0xFFE3EE), blushLine)

        for bx in [-14.0, 0.0, 14.0] as [CGFloat] {
            blob(g, oval(bx, -13, 3.6, 3.6), lemon, goldLine, 1.6)
        }
        twinkle(g, -40, -90, 5.5)
        twinkle(g, 42, -88, 4.5)
        twinkle(g, 0, -112, 4.2, .white)
    }

    // MARK: Aquarium — Koi pond bridge

    static let koiBridgeSize = CGSize(width: 148, height: 96)

    static func koiBridge(_ g: GraphicsContext) {
        let aquaLine = StorybookArt.outline(for: 0x7ED8EC)
        let red = Color(hex: 0xFF6E82)
        let redLine = StorybookArt.outline(for: 0xE6526A)

        blob(g, oval(0, -8, 66, 8), Color(hex: 0xB8F2FF), aquaLine, 2.2)
        let ripples: [(CGFloat, CGFloat, CGFloat)] = [(-24, -7, 16), (16, -9, 18), (-4, -4, 12)]
        for (rx, ry, rw) in ripples {
            var rip = Path()
            rip.move(to: CGPoint(x: rx - rw / 2, y: ry))
            rip.addQuadCurve(to: CGPoint(x: rx + rw / 2, y: ry), control: CGPoint(x: rx, y: ry - 2.5))
            strokePath(g, rip, .white.opacity(0.85), 2)
        }

        var koi = Path()
        koi.move(to: CGPoint(x: -16, y: -13))
        koi.addQuadCurve(to: CGPoint(x: 12, y: -15), control: CGPoint(x: -2, y: -24))
        koi.addQuadCurve(to: CGPoint(x: -16, y: -13), control: CGPoint(x: -2, y: -8))
        koi.closeSubpath()
        blob(g, koi, peach, StorybookArt.outline(for: 0xF2996B), 1.8)
        blob(g, poly([CGPoint(x: -15, y: -13), CGPoint(x: -23, y: -19), CGPoint(x: -22, y: -8)]), Color(hex: 0xFF8AA8), redLine, 1.6)

        var deck = Path()
        deck.move(to: CGPoint(x: -64, y: -12))
        deck.addQuadCurve(to: CGPoint(x: 64, y: -12), control: CGPoint(x: 0, y: -74))
        deck.addLine(to: CGPoint(x: 64, y: -24))
        deck.addQuadCurve(to: CGPoint(x: -64, y: -24), control: CGPoint(x: 0, y: -88))
        deck.closeSubpath()
        blob(g, deck, Color(hex: 0xFFE5BD), StorybookArt.outline(for: 0xD8A26A), 2.6)

        var redTrim = Path()
        redTrim.move(to: CGPoint(x: -63, y: -16))
        redTrim.addQuadCurve(to: CGPoint(x: 63, y: -16), control: CGPoint(x: 0, y: -78))
        strokePath(g, redTrim, redLine, 9)
        strokePath(g, redTrim, red, 5)

        let postXs: [CGFloat] = [-54, -27, 0, 27, 54]
        func deckY(_ x: CGFloat) -> CGFloat {
            let u = (x + 64) / 128
            return -24 + (-64) * 2 * u * (1 - u)
        }

        var midRail = Path()
        midRail.move(to: CGPoint(x: -54, y: deckY(-54) - 12))
        midRail.addQuadCurve(to: CGPoint(x: 54, y: deckY(54) - 12), control: CGPoint(x: 0, y: -90))
        strokePath(g, midRail, redLine, 7)
        strokePath(g, midRail, Color(hex: 0xFF98A8), 3.6)

        var topRail = Path()
        topRail.move(to: CGPoint(x: -54, y: deckY(-54) - 24))
        topRail.addQuadCurve(to: CGPoint(x: 54, y: deckY(54) - 24), control: CGPoint(x: 0, y: -102))
        strokePath(g, topRail, redLine, 9)
        strokePath(g, topRail, red, 5)

        for x in postXs {
            let y0 = deckY(x)
            let yTop = y0 - 27
            blob(g, rrect(x - 3.5, yTop, 7, 29, 3), red, redLine, 2.2)
            blob(g, oval(x, yTop - 3, 5.2, 5.8), gold, goldLine, 2)
            g.fill(oval(x - 1.5, yTop - 4.5, 1.8, 1.6), with: .color(.white.opacity(0.75)))
        }

        aquaBubble(g, cx: -58, cy: -66, r: 5)
        aquaBubble(g, cx: 58, cy: -70, r: 4.4)
        aquaBubble(g, cx: 38, cy: -84, r: 3.4)
    }

    // MARK: Dress Up — Royal Hanbok jokduri crown (족두리)

    static let hanbokCrownSize = CGSize(width: 124, height: 104)

    static func hanbokCrown(_ g: GraphicsContext) {
        let silkLine = StorybookArt.outline(for: 0xFF8FB8)
        let plum = Color(hex: 0x674A82)
        let plumLine = StorybookArt.outline(for: 0x52386B)
        let pearlYs: [CGFloat] = [-20, -12, -4.5]

        for side in [-1.0, 1.0] as [CGFloat] {
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: side * 34, y: -26))
            ribbon.addQuadCurve(to: CGPoint(x: side * 48, y: -6), control: CGPoint(x: side * 48, y: -20))
            strokePath(g, ribbon, silkLine, 8)
            strokePath(g, ribbon, pink, 4.5)
            for (k, py) in pearlYs.enumerated() {
                let px = side * (42 + CGFloat(k) * 3.5)
                blob(g, oval(px, py, 3.6, 3.6), Color(hex: 0xFFF7FA), StorybookArt.outline(for: 0xE6B8CE), 1.6)
            }
        }

        let body = Path { p in
            p.move(to: CGPoint(x: -36, y: -20))
            p.addCurve(to: CGPoint(x: -28, y: -70), control1: CGPoint(x: -44, y: -42), control2: CGPoint(x: -38, y: -64))
            p.addQuadCurve(to: CGPoint(x: 28, y: -70), control: CGPoint(x: 0, y: -80))
            p.addCurve(to: CGPoint(x: 36, y: -20), control1: CGPoint(x: 38, y: -64), control2: CGPoint(x: 44, y: -42))
            p.addQuadCurve(to: CGPoint(x: -36, y: -20), control: CGPoint(x: 0, y: -10))
            p.closeSubpath()
        }
        blob(g, body, plum, plumLine, 3)
        g.fill(oval(-14, -52, 11, 14), with: .color(Color(hex: 0x8F6FB0).opacity(0.65)))

        var band = Path()
        band.move(to: CGPoint(x: -39, y: -22))
        band.addQuadCurve(to: CGPoint(x: 39, y: -22), control: CGPoint(x: 0, y: -11))
        strokePath(g, band, goldLine, 12)
        strokePath(g, band, gold, 7.5)

        for side in [-1.0, 1.0] as [CGFloat] {
            var leaf = Path()
            leaf.move(to: CGPoint(x: side * 8, y: -74))
            leaf.addQuadCurve(to: CGPoint(x: side * 28, y: -86), control: CGPoint(x: side * 24, y: -70))
            leaf.addQuadCurve(to: CGPoint(x: side * 8, y: -74), control: CGPoint(x: side * 14, y: -88))
            leaf.closeSubpath()
            blob(g, leaf, mint, StorybookArt.outline(for: 0x7ED4B4), 2)
        }
        blossom(g, cx: 0, cy: -80, r: 14, petal: Color(hex: 0xFFA6C8), stroke: silkLine)

        let gems: [(CGFloat, CGFloat, CGFloat, Color, UInt32)] = [
            (0, -46, 8, pink, 0xFF7FA8),
            (-20, -42, 6, sky, 0x82C0FF),
            (20, -42, 6, mint, 0x82DCB8),
            (-24, -19, 4.5, lemon, 0xFFCF4A),
            (0, -16, 5.2, Color(hex: 0xFF7CA8), 0xE85888),
            (24, -19, 4.5, lilac, 0xB89EFF),
        ]
        for (gx, gy, gr, c, hex) in gems {
            blob(g, oval(gx, gy, gr, gr), c, StorybookArt.outline(for: hex), 2)
            g.fill(oval(gx - gr * 0.3, gy - gr * 0.32, gr * 0.3, gr * 0.24), with: .color(.white.opacity(0.8)))
        }
        twinkle(g, -42, -84, 5)
        twinkle(g, 42, -86, 4.5)
        twinkle(g, 0, -99, 4.5)
    }

    // MARK: Dress Up — Winged heart-crystal fairy wand

    static let fairyWandSize = CGSize(width: 112, height: 132)

    static func fairyWand(_ g: GraphicsContext) {
        g.fill(
            oval(0, -90, 44, 38),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFD9F2).opacity(0.8), .clear]),
                center: CGPoint(x: 0, y: -90),
                startRadius: 4,
                endRadius: 44
            )
        )

        let wingSkyLine = StorybookArt.outline(for: 0x8CC8FF)
        let wingLilacLine = StorybookArt.outline(for: 0xC4A8FF)
        for side in [-1.0, 1.0] as [CGFloat] {
            var upper = Path()
            upper.move(to: CGPoint(x: side * 8, y: -90))
            upper.addCurve(to: CGPoint(x: side * 50, y: -102), control1: CGPoint(x: side * 24, y: -118), control2: CGPoint(x: side * 52, y: -116))
            upper.addCurve(to: CGPoint(x: side * 12, y: -80), control1: CGPoint(x: side * 48, y: -84), control2: CGPoint(x: side * 26, y: -78))
            upper.closeSubpath()
            blob(g, upper, Color(hex: 0xC6ECFF), wingSkyLine, 2.4)
            g.fill(oval(side * 30, -98, 9, 4.5), with: .color(.white.opacity(0.65)))

            var lower = Path()
            lower.move(to: CGPoint(x: side * 10, y: -82))
            lower.addCurve(to: CGPoint(x: side * 38, y: -68), control1: CGPoint(x: side * 32, y: -84), control2: CGPoint(x: side * 44, y: -76))
            lower.addCurve(to: CGPoint(x: side * 8, y: -70), control1: CGPoint(x: side * 32, y: -58), control2: CGPoint(x: side * 18, y: -62))
            lower.closeSubpath()
            blob(g, lower, Color(hex: 0xE2D0FF), wingLilacLine, 2.2)
        }

        blob(g, rrect(-4.5, -72, 9, 64, 4.5), Color(hex: 0xF4E6FF), line, 2.4)
        for sy in stride(from: CGFloat(-60), through: -20, by: 14) {
            var wrap = Path()
            wrap.move(to: CGPoint(x: -4, y: sy))
            wrap.addLine(to: CGPoint(x: 4, y: sy + 5))
            strokePath(g, wrap, gold, 2.2)
        }
        blob(g, starPath(cx: 0, cy: -8, outer: 9, inner: 4.5), gold, goldLine, 2)

        let pinkLine = StorybookArt.outline(for: 0xFF8FB8)
        for side in [-1.0, 1.0] as [CGFloat] {
            var tail = Path()
            tail.move(to: CGPoint(x: side * 4, y: -64))
            tail.addQuadCurve(to: CGPoint(x: side * 18, y: -38), control: CGPoint(x: side * 16, y: -52))
            strokePath(g, tail, pinkLine, 7)
            strokePath(g, tail, pink, 3.8)
        }
        ribbonBow(g, cx: 0, cy: -66, scale: 0.9, fill: pink, stroke: pinkLine)

        let tiara = poly([
            CGPoint(x: -12, y: -108), CGPoint(x: -14, y: -120), CGPoint(x: -5, y: -114),
            CGPoint(x: 0, y: -124), CGPoint(x: 5, y: -114), CGPoint(x: 14, y: -120), CGPoint(x: 12, y: -108),
        ])
        blob(g, tiara, gold, goldLine, 2.2)

        blob(g, heartPath(cx: 0, cy: -90, size: 44), gold, goldLine, 2.6)
        let gem = heartPath(cx: 0, cy: -90, size: 34)
        blob(g, gem, Color(hex: 0xFF7FB4), StorybookArt.outline(for: 0xEE5C98), 2.2)
        g.fill(oval(-6, -96, 6, 4), with: .color(.white.opacity(0.65)))
        twinkle(g, -40, -118, 5)
        twinkle(g, 42, -116, 4.5)
        twinkle(g, 0, -129, 4)
    }

    // MARK: Fairies — Sparkling heart-crystal chandelier

    static let chandelierSize = CGSize(width: 126, height: 126)

    static func chandelier(_ g: GraphicsContext) {
        g.fill(
            oval(0, -68, 56, 48),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF2B8).opacity(0.75), Color(hex: 0xFFD9EE).opacity(0.28), .clear]),
                center: CGPoint(x: 0, y: -68),
                startRadius: 6,
                endRadius: 56
            )
        )

        blob(g, oval(0, -120, 12, 5), gold, goldLine, 2.2)
        for cy in [-112.0, -104.0] as [CGFloat] {
            blob(g, oval(0, cy, 3.2, 4.5), gold, goldLine, 1.8)
        }

        for side in [-1.0, 1.0] as [CGFloat] {
            var arm = Path()
            arm.move(to: CGPoint(x: 0, y: -56))
            arm.addCurve(
                to: CGPoint(x: side * 44, y: -66),
                control1: CGPoint(x: side * 18, y: -38),
                control2: CGPoint(x: side * 44, y: -48)
            )
            strokePath(g, arm, goldLine, 8)
            strokePath(g, arm, gold, 4.5)

            var drape = Path()
            drape.move(to: CGPoint(x: 0, y: -88))
            drape.addQuadCurve(to: CGPoint(x: side * 42, y: -64), control: CGPoint(x: side * 16, y: -62))
            strokePath(g, drape, Color(hex: 0xF5B8D8), 2)
            for t in [0.28, 0.52, 0.76] as [CGFloat] {
                let u = 1 - t
                let px = u * u * 0 + 2 * u * t * (side * 16) + t * t * (side * 42)
                let py = u * u * (-88) + 2 * u * t * (-62) + t * t * (-64)
                blob(g, oval(px, py, 3.4, 3.4), Color(hex: 0xFFF0F8), StorybookArt.outline(for: 0xE6A6C8), 1.4)
            }
        }

        blob(g, rrect(-4, -98, 8, 56, 4), gold, goldLine, 2.2)
        blob(g, oval(0, -68, 9, 10), Color(hex: 0xFFE3F4), StorybookArt.outline(for: 0xF09BC8), 2.2)
        g.fill(oval(-2.5, -71, 3, 2.5), with: .color(.white.opacity(0.8)))

        let candles: [(CGFloat, CGFloat)] = [(-44, -68), (0, -76), (44, -68)]
        for (cx, cy) in candles {
            blob(g, oval(cx, cy + 2, 11, 4.5), gold, goldLine, 2)
            blob(g, rrect(cx - 5, cy - 16, 10, 18, 4), Color(hex: 0xFFF7FA), StorybookArt.outline(for: 0xE6B2CE), 2)
            var fl = Path()
            fl.move(to: CGPoint(x: cx, y: cy - 17))
            fl.addCurve(to: CGPoint(x: cx, y: cy - 31), control1: CGPoint(x: cx - 6, y: cy - 21), control2: CGPoint(x: cx - 4, y: cy - 28))
            fl.addCurve(to: CGPoint(x: cx, y: cy - 17), control1: CGPoint(x: cx + 4, y: cy - 28), control2: CGPoint(x: cx + 6, y: cy - 21))
            fl.closeSubpath()
            blob(g, fl, lemon, goldLine, 1.8)
        }

        let drops: [(CGFloat, CGFloat, CGFloat, CGFloat, Color, UInt32)] = [
            (-44, -62, -40, 20, sky, 0x86C4FF),
            (44, -62, -40, 20, lilac, 0xB89EFF),
            (0, -42, -16, 28, pink, 0xFF7EB4),
        ]
        for (dx, yTop, yHeart, sz, col, hex) in drops {
            var cord = Path()
            cord.move(to: CGPoint(x: dx, y: yTop))
            cord.addLine(to: CGPoint(x: dx, y: yHeart - sz * 0.3))
            strokePath(g, cord, goldLine, 2)
            blob(g, heartPath(cx: dx, cy: yHeart, size: sz), col, StorybookArt.outline(for: hex), 2.2)
            g.fill(oval(dx - sz * 0.16, yHeart - sz * 0.18, sz * 0.14, sz * 0.1), with: .color(.white.opacity(0.65)))
        }
        twinkle(g, -54, -96, 5)
        twinkle(g, 54, -94, 4.5)
        twinkle(g, -22, -112, 4)
        twinkle(g, 24, -110, 4)
    }

    // MARK: Fairies — Pastel cloud-and-star miniature carousel

    static let carouselSize = CGSize(width: 132, height: 134)

    static func carousel(_ g: GraphicsContext) {
        let pinkLine = StorybookArt.outline(for: 0xFF8FB8)

        blob(g, rrect(-54, -12, 108, 12, 6), gold, goldLine, 2.5)
        blob(g, rrect(-48, -22, 96, 12, 5), Color(hex: 0xFFE6F0), pinkLine, 2.4)
        for sx in [-30.0, 0.0, 30.0] as [CGFloat] {
            g.fill(starPath(cx: sx, cy: -16, outer: 4.5, inner: 2.2), with: .color(gold))
        }

        blob(g, rrect(-8, -90, 16, 68, 4), Color(hex: 0xEFE4FF), line, 2.4)
        for py in stride(from: CGFloat(-82), through: -30, by: 14) {
            var stripe = Path()
            stripe.move(to: CGPoint(x: -7, y: py))
            stripe.addLine(to: CGPoint(x: 7, y: py + 6))
            strokePath(g, stripe, pink, 3)
        }
        for px in [-38.0, 38.0] as [CGFloat] {
            var pole = Path()
            pole.move(to: CGPoint(x: px, y: -88))
            pole.addLine(to: CGPoint(x: px, y: -22))
            strokePath(g, pole, goldLine, 5.5)
            strokePath(g, pole, gold, 2.8)
        }

        let cloudSeats: [(CGFloat, CGFloat, Color, UInt32)] = [
            (-38, -52, Color(hex: 0xE6F6FF), 0x98D2FF),
            (38, -44, Color(hex: 0xFFEAF4), 0xFF9EC6),
        ]
        let cloudPuffs: [(CGFloat, CGFloat, CGFloat)] = [(-11, 2, 8.5), (0, -4, 11), (11, 2, 8.5), (0, 4, 9)]
        for (cx, cy, tint, outlineHex) in cloudSeats {
            let rim = StorybookArt.outline(for: outlineHex)
            var cloud = Path()
            for (dx, dy, r) in cloudPuffs {
                cloud.addEllipse(in: CGRect(x: cx + dx - r, y: cy + dy - r, width: r * 2, height: r * 2))
            }
            g.stroke(cloud, with: .color(rim), lineWidth: 4.5)
            g.fill(cloud, with: .color(tint))
            g.fill(starPath(cx: cx, cy: cy + 1, outer: 5.5, inner: 2.6), with: .color(gold))
        }
        let moon = Path { p in
            p.move(to: CGPoint(x: -13, y: -48))
            p.addCurve(to: CGPoint(x: 15, y: -48), control1: CGPoint(x: -8, y: -26), control2: CGPoint(x: 10, y: -26))
            p.addCurve(to: CGPoint(x: -13, y: -48), control1: CGPoint(x: 6, y: -38), control2: CGPoint(x: -6, y: -38))
            p.closeSubpath()
        }
        blob(g, moon, lemon, goldLine, 2.2)

        let canopy = Path { p in
            p.move(to: CGPoint(x: -58, y: -88))
            p.addCurve(to: CGPoint(x: 0, y: -116), control1: CGPoint(x: -44, y: -108), control2: CGPoint(x: -16, y: -116))
            p.addCurve(to: CGPoint(x: 58, y: -88), control1: CGPoint(x: 16, y: -116), control2: CGPoint(x: 44, y: -108))
            p.closeSubpath()
        }
        blob(g, canopy, Color(hex: 0xFFF5FA), pinkLine, 2.8)
        let panels: [(CGFloat, CGFloat, Color)] = [
            (-56, -34, pink), (-14, 14, lilac), (34, 56, sky),
        ]
        for (x0, x1, col) in panels {
            var panel = Path()
            panel.move(to: CGPoint(x: 0, y: -115))
            panel.addLine(to: CGPoint(x: x0, y: -88))
            panel.addLine(to: CGPoint(x: x1, y: -88))
            panel.closeSubpath()
            g.fill(panel, with: .color(col.opacity(0.85)))
        }
        strokePath(g, canopy, pinkLine, 2.8)

        for i in 0..<6 {
            let sx = -47.5 + CGFloat(i) * 19
            blob(g, oval(sx, -86, 10, 6.5), i % 2 == 0 ? lemon : Color(hex: 0xFFB8D4), goldLine, 2)
        }
        blob(g, starPath(cx: 0, cy: -124, outer: 10, inner: 4.8), gold, goldLine, 2.2)
        twinkle(g, -52, -114, 5)
        twinkle(g, 52, -112, 4.5)
    }

    // MARK: Fairies — Celadon Hanbok tea set (청자 다기)

    static let hanbokTeaSize = CGSize(width: 136, height: 96)

    static func hanbokTea(_ g: GraphicsContext) {
        let trayLine = StorybookArt.outline(for: 0xE2B484)
        let celadon = Color(hex: 0xB8E8D6)
        let celadonShade = Color(hex: 0x98D6C0)
        let celadonLine = StorybookArt.outline(for: 0x7EC4AC)

        blob(g, oval(0, -8, 62, 8), Color(hex: 0xF7D7B2), trayLine, 2.6)
        g.fill(oval(0, -10, 50, 3.5), with: .color(.white.opacity(0.42)))

        var spout = Path()
        spout.move(to: CGPoint(x: -44, y: -32))
        spout.addCurve(to: CGPoint(x: -60, y: -56), control1: CGPoint(x: -58, y: -34), control2: CGPoint(x: -54, y: -50))
        strokePath(g, spout, celadonLine, 12)
        strokePath(g, spout, celadon, 7)

        var handle = Path()
        handle.move(to: CGPoint(x: -4, y: -50))
        handle.addCurve(to: CGPoint(x: -4, y: -24), control1: CGPoint(x: 16, y: -52), control2: CGPoint(x: 16, y: -24))
        strokePath(g, handle, celadonLine, 10)
        strokePath(g, handle, celadon, 5.5)

        blob(g, oval(-24, -36, 25, 22), celadon, celadonLine, 2.8)
        g.fill(oval(-24, -22, 18, 6), with: .color(celadonShade.opacity(0.75)))
        g.fill(oval(-34, -44, 7, 5), with: .color(.white.opacity(0.6)))
        blob(g, rrect(-36, -16, 24, 6, 3), celadonShade, celadonLine, 2.2)

        blob(g, oval(-24, -58, 16, 6.5), celadon, celadonLine, 2.4)
        blob(g, oval(-24, -67, 5.5, 5.5), gold, goldLine, 2)
        blossom(g, cx: -24, cy: -36, r: 9.5, petal: .white, stroke: celadonLine, center: pink)

        blob(g, oval(38, -14, 18, 5), Color(hex: 0xDCF5EC), celadonLine, 2.2)
        var cupHandle = Path()
        cupHandle.move(to: CGPoint(x: 49, y: -30))
        cupHandle.addCurve(to: CGPoint(x: 49, y: -18), control1: CGPoint(x: 59, y: -30), control2: CGPoint(x: 59, y: -18))
        strokePath(g, cupHandle, celadonLine, 6.5)
        strokePath(g, cupHandle, celadon, 3.4)

        var cup = Path()
        cup.move(to: CGPoint(x: 24, y: -36))
        cup.addLine(to: CGPoint(x: 52, y: -36))
        cup.addCurve(to: CGPoint(x: 38, y: -14), control1: CGPoint(x: 52, y: -20), control2: CGPoint(x: 46, y: -14))
        cup.addCurve(to: CGPoint(x: 24, y: -36), control1: CGPoint(x: 30, y: -14), control2: CGPoint(x: 24, y: -20))
        cup.closeSubpath()
        blob(g, cup, celadon, celadonLine, 2.4)
        g.fill(oval(38, -36, 13, 3.5), with: .color(Color(hex: 0xFFE6A8)))
        g.fill(oval(31, -28, 3.5, 3), with: .color(.white.opacity(0.6)))

        for sx in [34.0, 44.0] as [CGFloat] {
            var steam = Path()
            steam.move(to: CGPoint(x: sx, y: -44))
            steam.addCurve(to: CGPoint(x: sx + 2, y: -66), control1: CGPoint(x: sx - 6, y: -52), control2: CGPoint(x: sx + 8, y: -58))
            strokePath(g, steam, .white.opacity(0.85), 3)
        }

        blob(g, oval(8, -11, 13, 4), gold, goldLine, 1.8)
        blossom(g, cx: 8, cy: -16, r: 8, petal: Color(hex: 0xFFB8D4), stroke: StorybookArt.outline(for: 0xFF8FB8), center: lemon)

        twinkle(g, -24, -84, 5)
        twinkle(g, 46, -78, 4.2)
    }

    // MARK: Spa — Golden citrus yuzu bath bomb

    static let yuzuBombSize = CGSize(width: 112, height: 112)

    static func yuzuBomb(_ g: GraphicsContext) {
        let foamLine = StorybookArt.outline(for: 0xB4DDF8)
        let yuzuLine = StorybookArt.outline(for: 0xF2B82E)
        let leafLine = StorybookArt.outline(for: 0x6EC888)

        var foam = Path()
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-36, -10, 10), (-18, -13, 12), (0, -10, 13), (18, -13, 12), (36, -10, 10)]
        for (fx, fy, fr) in puffs {
            foam.addEllipse(in: CGRect(x: fx - fr, y: fy - fr, width: fr * 2, height: fr * 2))
        }
        g.stroke(foam, with: .color(foamLine), lineWidth: 4.5)
        g.fill(foam, with: .color(Color(hex: 0xF4FAFF)))

        blob(g, oval(0, -49, 36, 35), Color(hex: 0xFFDC5E), yuzuLine, 3)

        var swirl = Path()
        swirl.move(to: CGPoint(x: -33, y: -40))
        swirl.addCurve(to: CGPoint(x: 33, y: -42), control1: CGPoint(x: -10, y: -30), control2: CGPoint(x: 12, y: -52))
        strokePath(g, swirl, Color(hex: 0xFFB5D2).opacity(0.85), 7)
        strokePath(g, swirl, .white.opacity(0.55), 2.5)

        g.fill(oval(-14, -66, 11, 7), with: .color(.white.opacity(0.55)))
        let dimples: [(CGFloat, CGFloat)] = [(-22, -54), (22, -56), (16, -28), (-18, -28)]
        for (dx, dy) in dimples {
            g.fill(oval(dx, dy, 2.2, 2.2), with: .color(yuzuLine.opacity(0.35)))
        }

        for ex in [-11.0, 11.0] as [CGFloat] {
            var eye = Path()
            eye.move(to: CGPoint(x: ex - 4.5, y: -52))
            eye.addQuadCurve(to: CGPoint(x: ex + 4.5, y: -52), control: CGPoint(x: ex, y: -57.5))
            strokePath(g, eye, Theme.ink, 2.6)
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -5, y: -46))
        smile.addQuadCurve(to: CGPoint(x: 5, y: -46), control: CGPoint(x: 0, y: -41))
        strokePath(g, smile, Theme.ink, 2.2)
        g.fill(oval(-18, -46, 5, 3), with: .color(pink.opacity(0.55)))
        g.fill(oval(18, -46, 5, 3), with: .color(pink.opacity(0.55)))

        var leaf = Path()
        leaf.move(to: CGPoint(x: 2, y: -82))
        leaf.addQuadCurve(to: CGPoint(x: 28, y: -98), control: CGPoint(x: 14, y: -102))
        leaf.addQuadCurve(to: CGPoint(x: 2, y: -82), control: CGPoint(x: 22, y: -80))
        leaf.closeSubpath()
        blob(g, leaf, Color(hex: 0x86DF9E), leafLine, 2.4)
        blossom(g, cx: -6, cy: -88, r: 9.5, petal: .white, stroke: StorybookArt.outline(for: 0xFFD45A), center: gold)

        aquaBubble(g, cx: -38, cy: -74, r: 5.5)
        aquaBubble(g, cx: 40, cy: -72, r: 4.8)
        twinkle(g, -28, -98, 5)
        twinkle(g, 36, -98, 4.5)
    }

    // MARK: Spa — Crowned golden pastel rubber ducky

    static let goldenDuckSize = CGSize(width: 122, height: 114)

    static func goldenDuck(_ g: GraphicsContext) {
        let duckGold = Color(hex: 0xFFD654)
        let duckShade = Color(hex: 0xF5BE38)
        let duckLine = StorybookArt.outline(for: 0xE6A428)
        let billLine = StorybookArt.outline(for: 0xFF8B58)

        blob(g, oval(0, -8, 52, 8), Color(hex: 0xC6F2FF), StorybookArt.outline(for: 0x7ED8EC), 2.2)

        let body = Path { p in
            p.move(to: CGPoint(x: -48, y: -54))
            p.addCurve(to: CGPoint(x: -10, y: -48), control1: CGPoint(x: -36, y: -56), control2: CGPoint(x: -24, y: -44))
            p.addCurve(to: CGPoint(x: 38, y: -32), control1: CGPoint(x: 16, y: -54), control2: CGPoint(x: 42, y: -46))
            p.addCurve(to: CGPoint(x: -8, y: -10), control1: CGPoint(x: 38, y: -14), control2: CGPoint(x: 16, y: -10))
            p.addCurve(to: CGPoint(x: -48, y: -54), control1: CGPoint(x: -38, y: -10), control2: CGPoint(x: -50, y: -34))
            p.closeSubpath()
        }
        blob(g, body, duckGold, duckLine, 3)
        g.fill(oval(-8, -19, 28, 7), with: .color(duckShade.opacity(0.65)))

        var wing = Path()
        wing.move(to: CGPoint(x: -28, y: -36))
        wing.addCurve(to: CGPoint(x: 12, y: -34), control1: CGPoint(x: -16, y: -46), control2: CGPoint(x: 4, y: -44))
        wing.addCurve(to: CGPoint(x: -28, y: -36), control1: CGPoint(x: 14, y: -20), control2: CGPoint(x: -16, y: -18))
        wing.closeSubpath()
        blob(g, wing, Color(hex: 0xFFE378), duckLine, 2.4)
        g.fill(oval(-8, -36, 9, 3.5), with: .color(.white.opacity(0.55)))

        blob(g, oval(18, -68, 24, 22), duckGold, duckLine, 3)
        g.fill(oval(8, -79, 9, 5.5), with: .color(.white.opacity(0.55)))

        blob(g, oval(43, -64, 12, 7.5), Color(hex: 0xFFA56E), billLine, 2.5)
        var billSmile = Path()
        billSmile.move(to: CGPoint(x: 36, y: -64))
        billSmile.addQuadCurve(to: CGPoint(x: 50, y: -64), control: CGPoint(x: 43, y: -60))
        strokePath(g, billSmile, billLine, 2)

        g.fill(oval(26, -72, 4.4, 4.8), with: .color(Theme.ink))
        g.fill(oval(24.5, -74, 1.8, 1.8), with: .color(.white))
        g.fill(oval(22, -62, 5.5, 3.4), with: .color(pink.opacity(0.55)))

        var crownCtx = g
        crownCtx.translateBy(x: 14, y: -88)
        crownCtx.rotate(by: .degrees(-10))
        let crown = poly([
            CGPoint(x: -14, y: 0), CGPoint(x: -17, y: -18), CGPoint(x: -7, y: -10),
            CGPoint(x: 0, y: -22), CGPoint(x: 7, y: -10), CGPoint(x: 17, y: -18), CGPoint(x: 14, y: 0),
        ])
        blob(crownCtx, crown, Color(hex: 0xFFE370), goldLine, 2.4)
        blob(crownCtx, oval(0, -8, 4.2, 4.2), pink, StorybookArt.outline(for: 0xFF7CA8), 1.6)
        for px in [-17.0, 0.0, 17.0] as [CGFloat] {
            let py: CGFloat = px == 0 ? -22 : -18
            blob(crownCtx, oval(px, py, 3, 3), .white, goldLine, 1.5)
        }

        aquaBubble(g, cx: -46, cy: -74, r: 5)
        twinkle(g, -36, -94, 5)
        twinkle(g, 46, -96, 4.5)
    }

    // MARK: Potion Lab — Lilac/pink starlight heart cauldron

    static let heartCauldronSize = CGSize(width: 124, height: 122)

    static func heartCauldron(_ g: GraphicsContext) {
        let pot = Color(hex: 0xC6A2FF)
        let potShade = Color(hex: 0xAD86F0)
        let potLine = StorybookArt.outline(for: 0x9C72E6)

        g.fill(
            oval(0, -88, 46, 32),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFC6EB).opacity(0.75), Color(hex: 0xB8F5E6).opacity(0.35), .clear]),
                center: CGPoint(x: 0, y: -88),
                startRadius: 4,
                endRadius: 46
            )
        )

        for fx in [-24.0, 24.0] as [CGFloat] {
            blob(g, oval(fx, -8, 10, 7), potShade, potLine, 2.6)
        }

        for side in [-1.0, 1.0] as [CGFloat] {
            let ring = oval(side * 45, -48, 9, 9)
            g.stroke(ring, with: .color(goldLine), lineWidth: 7)
            g.stroke(ring, with: .color(gold), lineWidth: 3.5)
        }

        let bubbles: [(CGFloat, CGFloat, CGFloat, Color, UInt32)] = [
            (-24, -80, 12, pink, 0xFF8FB8),
            (22, -78, 11, mint, 0x88DEC4),
            (-6, -86, 14, Color(hex: 0xFFB8E2), 0xF08AC8),
            (10, -84, 11, sky, 0x8CC8FF),
            (-16, -104, 6, Color(hex: 0xFFD4EC), 0xF08AC8),
            (18, -102, 5.2, mint, 0x88DEC4),
        ]
        for (bx, by, br, col, hex) in bubbles {
            blob(g, oval(bx, by, br, br), col, StorybookArt.outline(for: hex), 2.2)
            g.fill(oval(bx - br * 0.3, by - br * 0.32, br * 0.3, br * 0.22), with: .color(.white.opacity(0.75)))
        }

        blob(g, oval(0, -42, 43, 34), pot, potLine, 3)
        g.fill(oval(0, -20, 32, 10), with: .color(potShade.opacity(0.65)))
        g.fill(oval(-22, -52, 9, 13), with: .color(.white.opacity(0.45)))

        blob(g, rrect(-42, -76, 84, 14, 7), Color(hex: 0xD8BEFF), potLine, 2.8)
        blob(g, rrect(-36, -65, 72, 6, 3), gold, goldLine, 1.8)

        blob(g, heartPath(cx: 0, cy: -39, size: 34), gold, goldLine, 2.4)
        blob(g, heartPath(cx: 0, cy: -39, size: 26), Color(hex: 0xFF6EA8), StorybookArt.outline(for: 0xE64B88), 2)
        g.fill(oval(-4.5, -43, 4.5, 3), with: .color(.white.opacity(0.7)))

        twinkle(g, 0, -114, 6)
        twinkle(g, -36, -98, 4.5)
        twinkle(g, 36, -96, 4.5)
    }

    // MARK: Potion Lab — Pearl-handled star fairy ladle

    static let fairyLadleSize = CGSize(width: 112, height: 128)

    static func fairyLadle(_ g: GraphicsContext) {
        let ladleLine = StorybookArt.outline(for: 0xB89CF2)
        let pinkLine = StorybookArt.outline(for: 0xFF8FB8)

        g.fill(
            oval(30, -104, 28, 28),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF29C).opacity(0.85), .clear]),
                center: CGPoint(x: 30, y: -104),
                startRadius: 3,
                endRadius: 28
            )
        )

        var handle = Path()
        handle.move(to: CGPoint(x: -6, y: -32))
        handle.addLine(to: CGPoint(x: 28, y: -96))
        strokePath(g, handle, ladleLine, 11)
        strokePath(g, handle, Color(hex: 0xFFF5FC), 6.5)

        for t in [0.3, 0.55, 0.78] as [CGFloat] {
            let px = -6 + 34 * t
            let py = -32 - 64 * t
            blob(g, oval(px, py, 5, 5), Color(hex: 0xFFE6F4), pinkLine, 1.8)
            g.fill(oval(px - 1.5, py - 1.5, 1.6, 1.4), with: .color(.white))
        }
        ribbonBow(g, cx: 9, cy: -60, scale: 0.78, fill: pink, stroke: pinkLine)

        var bowl = Path()
        bowl.move(to: CGPoint(x: -48, y: -26))
        bowl.addCurve(to: CGPoint(x: 10, y: -26), control1: CGPoint(x: -44, y: 2), control2: CGPoint(x: 6, y: 2))
        bowl.closeSubpath()
        blob(g, bowl, lilac, ladleLine, 2.8)
        g.fill(oval(-28, -14, 9, 4.5), with: .color(.white.opacity(0.45)))

        blob(g, oval(-19, -26, 29, 9), gold, goldLine, 2.2)
        g.fill(oval(-19, -26, 24, 6), with: .color(mint))
        g.fill(oval(-16, -26, 14, 3.5), with: .color(Color(hex: 0xFFB8E2).opacity(0.85)))
        g.fill(oval(-26, -27, 6, 2), with: .color(.white.opacity(0.8)))

        blob(g, oval(-34, -46, 5, 5), Color(hex: 0xFFB8E2), pinkLine, 1.8)
        blob(g, oval(-18, -56, 4, 4), mint, StorybookArt.outline(for: 0x86DCC2), 1.6)

        blob(g, starPath(cx: 30, cy: -104, outer: 18, inner: 8.5), gold, goldLine, 2.6)
        g.fill(starPath(cx: 30, cy: -104, outer: 10, inner: 4.8), with: .color(Color(hex: 0xFFF7C2)))
        twinkle(g, 8, -116, 5)
        twinkle(g, 48, -86, 4.5)
        twinkle(g, -40, -64, 4.5)
    }

    // MARK: Bakery — Golden smiling bungeoppang (붕어빵)

    static let goldenBungeoSize = CGSize(width: 136, height: 96)

    static func goldenBungeo(_ g: GraphicsContext) {
        let crust = Color(hex: 0xF7BE56)
        let crustLight = Color(hex: 0xFFD980)
        let crustLine = StorybookArt.outline(for: 0xD9962C)
        let glazeLine = StorybookArt.outline(for: 0xFF82B0)

        blob(g, oval(0, -8, 56, 7.5), Color(hex: 0xFFE6F0), StorybookArt.outline(for: 0xF2A6C4), 2.2)

        blob(g, oval(4, -71, 20, 9), crust, crustLine, 2.6)
        blob(g, oval(4, -17, 15, 7), crust, crustLine, 2.4)

        let tail = Path { p in
            p.move(to: CGPoint(x: -34, y: -44))
            p.addCurve(to: CGPoint(x: -60, y: -66), control1: CGPoint(x: -44, y: -58), control2: CGPoint(x: -54, y: -66))
            p.addQuadCurve(to: CGPoint(x: -50, y: -44), control: CGPoint(x: -62, y: -50))
            p.addQuadCurve(to: CGPoint(x: -60, y: -22), control: CGPoint(x: -62, y: -38))
            p.addCurve(to: CGPoint(x: -34, y: -44), control1: CGPoint(x: -54, y: -22), control2: CGPoint(x: -44, y: -30))
            p.closeSubpath()
        }
        blob(g, tail, crust, crustLine, 2.8)

        blob(g, oval(10, -44, 48, 28), crust, crustLine, 3)
        g.fill(oval(10, -49, 38, 17), with: .color(crustLight.opacity(0.65)))

        for gx in [-16.0, -4.0, 8.0] as [CGFloat] {
            var v = Path()
            v.move(to: CGPoint(x: gx, y: -54))
            v.addLine(to: CGPoint(x: gx, y: -28))
            strokePath(g, v, crustLine.opacity(0.45), 2)
        }
        for gy in [-46.0, -36.0] as [CGFloat] {
            var h = Path()
            h.move(to: CGPoint(x: -22, y: gy))
            h.addLine(to: CGPoint(x: 14, y: gy))
            strokePath(g, h, crustLine.opacity(0.45), 2)
        }

        var glaze = Path()
        glaze.move(to: CGPoint(x: -24, y: -60))
        glaze.addQuadCurve(to: CGPoint(x: 34, y: -62), control: CGPoint(x: 6, y: -76))
        glaze.addCurve(to: CGPoint(x: 18, y: -52), control1: CGPoint(x: 30, y: -52), control2: CGPoint(x: 24, y: -58))
        glaze.addCurve(to: CGPoint(x: 0, y: -50), control1: CGPoint(x: 12, y: -44), control2: CGPoint(x: 6, y: -54))
        glaze.addCurve(to: CGPoint(x: -24, y: -60), control1: CGPoint(x: -8, y: -44), control2: CGPoint(x: -18, y: -50))
        glaze.closeSubpath()
        blob(g, glaze, Color(hex: 0xFF9EC6), glazeLine, 2.2)

        let sprinkles: [(CGFloat, CGFloat, Color)] = [(-10, -61, lemon), (4, -64, mint), (18, -60, sky), (-2, -56, .white)]
        for (sx, sy, col) in sprinkles {
            g.fill(rrect(sx - 3, sy - 1.5, 6, 3, 1.5), with: .color(col))
        }

        var eye = Path()
        eye.move(to: CGPoint(x: 30, y: -49))
        eye.addQuadCurve(to: CGPoint(x: 39, y: -49), control: CGPoint(x: 34.5, y: -54.5))
        strokePath(g, eye, Theme.ink, 2.6)
        g.fill(oval(36, -42, 4.5, 2.8), with: .color(pink.opacity(0.65)))
        var mouth = Path()
        mouth.move(to: CGPoint(x: 44, y: -43))
        mouth.addQuadCurve(to: CGPoint(x: 53, y: -45), control: CGPoint(x: 49, y: -39))
        strokePath(g, mouth, crustLine, 2.4)

        twinkle(g, -42, -82, 5)
        twinkle(g, 46, -84, 4.5)
        twinkle(g, 8, -88, 4)
    }

    // MARK: Bakery — Golden jeweled strawberry tiara crown

    static let strawberryCrownSize = CGSize(width: 128, height: 104)

    static func strawberryCrown(_ g: GraphicsContext) {
        let berryRed = Color(hex: 0xF03858)
        let berryLine = StorybookArt.outline(for: 0xC82442)
        let leafGreen = Color(hex: 0x6FD488)
        let leafLine = StorybookArt.outline(for: 0x48A860)

        g.fill(
            oval(0, -52, 56, 40),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF3A8).opacity(0.72), Color(hex: 0xFFD4EC).opacity(0.3), .clear]),
                center: CGPoint(x: 0, y: -52),
                startRadius: 6,
                endRadius: 56
            )
        )

        // Velvet pastel cushion under the tiara
        blob(g, oval(0, -10, 52, 9), Color(hex: 0xFFE6F0), StorybookArt.outline(for: 0xF2A6C4), 2.2)

        // Curved golden filigree tiara crown
        let crown = Path { p in
            p.move(to: CGPoint(x: -46, y: -16))
            p.addLine(to: CGPoint(x: -52, y: -62))
            p.addQuadCurve(to: CGPoint(x: -22, y: -42), control: CGPoint(x: -36, y: -38))
            p.addLine(to: CGPoint(x: 0, y: -84))
            p.addLine(to: CGPoint(x: 22, y: -42))
            p.addQuadCurve(to: CGPoint(x: 52, y: -62), control: CGPoint(x: 36, y: -38))
            p.addLine(to: CGPoint(x: 46, y: -16))
            p.addQuadCurve(to: CGPoint(x: -46, y: -16), control: CGPoint(x: 0, y: -6))
            p.closeSubpath()
        }
        g.fill(
            crown,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF5B2), gold, Color(hex: 0xE59B20)]),
                startPoint: CGPoint(x: -48, y: -84),
                endPoint: CGPoint(x: 48, y: -10)
            )
        )
        strokePath(g, crown, goldLine, 3)

        // Scalloped golden headband rim
        var band = Path()
        band.move(to: CGPoint(x: -48, y: -18))
        band.addQuadCurve(to: CGPoint(x: 48, y: -18), control: CGPoint(x: 0, y: -7))
        strokePath(g, band, goldLine, 12)
        strokePath(g, band, Color(hex: 0xFFE582), 7.5)

        // Pearl finial tips
        for (px, py) in [(-52.0, -64.0), (0.0, -86.0), (52.0, -64.0)] as [(CGFloat, CGFloat)] {
            blob(g, oval(px, py, 6, 6), Color(hex: 0xFFFDF8), goldLine, 2.2)
            g.fill(oval(px - 1.8, py - 1.8, 2, 1.6), with: .color(.white))
        }

        // Flanking emerald mint leaves behind the centerpiece berry jewel
        for side in [-1.0, 1.0] as [CGFloat] {
            var leaf = Path()
            leaf.move(to: CGPoint(x: side * 8, y: -56))
            leaf.addQuadCurve(to: CGPoint(x: side * 26, y: -66), control: CGPoint(x: side * 14, y: -69))
            leaf.addQuadCurve(to: CGPoint(x: side * 8, y: -56), control: CGPoint(x: side * 22, y: -53))
            leaf.closeSubpath()
            blob(g, leaf, leafGreen, leafLine, 2)
        }

        // Centerpiece plump ruby strawberry jewel
        let berry = Path { p in
            p.move(to: CGPoint(x: 0, y: -60))
            p.addCurve(to: CGPoint(x: 16, y: -40), control1: CGPoint(x: 11, y: -58), control2: CGPoint(x: 18, y: -48))
            p.addCurve(to: CGPoint(x: 0, y: -26), control1: CGPoint(x: 14, y: -30), control2: CGPoint(x: 6, y: -26))
            p.addCurve(to: CGPoint(x: -16, y: -40), control1: CGPoint(x: -6, y: -26), control2: CGPoint(x: -14, y: -30))
            p.addCurve(to: CGPoint(x: 0, y: -60), control1: CGPoint(x: -18, y: -48), control2: CGPoint(x: -11, y: -58))
            p.closeSubpath()
        }
        blob(g, berry, berryRed, berryLine, 2.6)
        g.fill(oval(-5, -49, 4.5, 3), with: .color(.white.opacity(0.78)))
        for (sx, sy) in [(-6.0, -39.0), (6.0, -39.0), (0.0, -33.0), (0.0, -45.0)] as [(CGFloat, CGFloat)] {
            g.fill(oval(sx, sy, 1.6, 2.2), with: .color(lemon))
        }

        // Side pink gems & headband pearls
        for gx in [-28.0, 28.0] as [CGFloat] {
            blob(g, oval(gx, -30, 6.5, 6.5), pink, StorybookArt.outline(for: 0xFF7CA8), 2)
            g.fill(oval(gx - 2, -32, 2.2, 1.6), with: .color(.white.opacity(0.8)))
        }
        for bx in [-34.0, -17.0, 17.0, 34.0] as [CGFloat] {
            blob(g, oval(bx, -14 + abs(bx) * 0.08, 3.6, 3.6), .white, goldLine, 1.5)
        }

        twinkle(g, -46, -86, 5.5)
        twinkle(g, 48, -84, 5)
        twinkle(g, 0, -98, 4.5, .white)
    }

    // MARK: Ice Cream — Sparkly pastel rainbow unicorn-horn waffle cone

    static let unicornConeSize = CGSize(width: 116, height: 138)

    static func unicornCone(_ g: GraphicsContext) {
        let coneTan = Color(hex: 0xF0B870)
        let coneLine = StorybookArt.outline(for: 0xD48E40)
        let pinkLine = StorybookArt.outline(for: 0xFF8FB8)

        g.fill(
            oval(0, -82, 48, 44),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE6F4).opacity(0.75), Color(hex: 0xD8F6FF).opacity(0.32), .clear]),
                center: CGPoint(x: 0, y: -82),
                startRadius: 6,
                endRadius: 48
            )
        )

        // Pastel rainbow-washed waffle cone standing on tip at (0, -4)
        let cone = Path { p in
            p.move(to: CGPoint(x: -28, y: -62))
            p.addLine(to: CGPoint(x: 28, y: -62))
            p.addQuadCurve(to: CGPoint(x: 0, y: -4), control: CGPoint(x: 16, y: -26))
            p.addQuadCurve(to: CGPoint(x: -28, y: -62), control: CGPoint(x: -16, y: -26))
            p.closeSubpath()
        }
        g.fill(
            cone,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFD2E6), Color(hex: 0xFFE8A6), Color(hex: 0xB8F0DC), Color(hex: 0xC6E4FF)]),
                startPoint: CGPoint(x: -26, y: -62),
                endPoint: CGPoint(x: 22, y: -8)
            )
        )
        var gridClip = g
        gridClip.clip(to: cone)
        var grid = Path()
        for k in -3...3 {
            let x = CGFloat(k) * 14
            grid.move(to: CGPoint(x: x - 24, y: -64)); grid.addLine(to: CGPoint(x: x + 28, y: -2))
            grid.move(to: CGPoint(x: x + 28, y: -64)); grid.addLine(to: CGPoint(x: x - 24, y: -2))
        }
        gridClip.stroke(grid, with: .color(coneLine.opacity(0.42)), lineWidth: 2)
        strokePath(g, cone, coneLine, 2.8)
        blob(g, rrect(-31, -67, 62, 10, 5), coneTan, coneLine, 2.4)

        // Cute pastel unicorn ears tucked behind the ice cream swirls
        for side in [-1.0, 1.0] as [CGFloat] {
            let ear = poly([CGPoint(x: side * 14, y: -92), CGPoint(x: side * 34, y: -116), CGPoint(x: side * 26, y: -82)])
            blob(g, ear, Color(hex: 0xFFFDFB), line, 2.4)
            let inner = poly([CGPoint(x: side * 17, y: -93), CGPoint(x: side * 29, y: -109), CGPoint(x: side * 24, y: -87)])
            g.fill(inner, with: .color(pink))
        }

        // Sparkling spiraled golden unicorn horn rising from the top scoop
        let horn = poly([CGPoint(x: -11, y: -98), CGPoint(x: 0, y: -134), CGPoint(x: 11, y: -98)])
        g.fill(
            horn,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF5B2), gold, Color(hex: 0xE59B20)]),
                startPoint: CGPoint(x: 0, y: -134),
                endPoint: CGPoint(x: 0, y: -98)
            )
        )
        strokePath(g, horn, goldLine, 2.5)
        for k in 1...3 {
            let f = CGFloat(k) / 4
            let y = -98 - 36 * f
            let hw = 10 * (1 - f)
            var ridge = Path()
            ridge.move(to: CGPoint(x: -hw, y: y + 2))
            ridge.addLine(to: CGPoint(x: hw, y: y - 2))
            strokePath(g, ridge, goldLine.opacity(0.7), 1.8)
        }

        // Swirled pastel scoops (mint + strawberry + lilac cloud)
        blob(g, oval(-13, -72, 19, 15), mint, StorybookArt.outline(for: 0x86DCC2), 2.5)
        blob(g, oval(13, -72, 19, 15), sky, StorybookArt.outline(for: 0x88C4F2), 2.5)
        blob(g, oval(0, -86, 23, 18), Color(hex: 0xFFB4D2), pinkLine, 2.6)
        g.fill(oval(-8, -93, 8, 4.5), with: .color(.white.opacity(0.68)))

        // Star sprinkles on the scoops & rim
        let stars: [(CGFloat, CGFloat, CGFloat, Color)] = [
            (-16, -74, 5.2, lemon),
            (15, -72, 5.0, pink),
            (0, -88, 5.8, lemon),
            (-18, -62, 4.5, sky),
            (18, -62, 4.5, lilac),
        ]
        for (sx, sy, sr, col) in stars {
            blob(g, starPath(cx: sx, cy: sy, outer: sr, inner: sr * 0.46), col, goldLine.opacity(0.75), 1.2)
        }

        twinkle(g, -40, -112, 5.5)
        twinkle(g, 40, -108, 5)
        twinkle(g, 0, -135, 4.5, .white)
    }

    // MARK: Ice Cream — Pastel rainbow shaved-snow bingsu (빙수)

    static let rainbowBingsuSize = CGSize(width: 126, height: 124)

    static func rainbowBingsu(_ g: GraphicsContext) {
        let bowlLine = StorybookArt.outline(for: 0xE6A8C8)
        let snowLine = StorybookArt.outline(for: 0xC4B4F2)

        var spoonCtx = g
        spoonCtx.translateBy(x: 32, y: -76)
        spoonCtx.rotate(by: .degrees(32))
        blob(spoonCtx, rrect(-4, -36, 8, 44, 4), Color(hex: 0xFFF3FA), line, 2.2)
        for (i, col) in [pink, lemon, mint, sky].enumerated() {
            spoonCtx.fill(rrect(-3, -30 + CGFloat(i) * 7, 6, 5, 2), with: .color(col))
        }
        blob(spoonCtx, oval(0, -37, 6, 4.5), gold, goldLine, 1.8)

        let dome = Path { p in
            p.move(to: CGPoint(x: -44, y: -42))
            p.addCurve(to: CGPoint(x: 0, y: -98), control1: CGPoint(x: -44, y: -78), control2: CGPoint(x: -22, y: -98))
            p.addCurve(to: CGPoint(x: 44, y: -42), control1: CGPoint(x: 22, y: -98), control2: CGPoint(x: 44, y: -78))
            p.closeSubpath()
        }
        g.fill(
            dome,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFB0D4), Color(hex: 0xFFE89E), Color(hex: 0xB4F0DC), Color(hex: 0xB8E2FF)]),
                startPoint: CGPoint(x: 0, y: -98),
                endPoint: CGPoint(x: 0, y: -42)
            )
        )
        strokePath(g, dome, snowLine, 2.8)

        var drizzle = Path()
        drizzle.move(to: CGPoint(x: -22, y: -76))
        drizzle.addCurve(to: CGPoint(x: 22, y: -76), control1: CGPoint(x: -14, y: -98), control2: CGPoint(x: 14, y: -98))
        drizzle.addCurve(to: CGPoint(x: 8, y: -66), control1: CGPoint(x: 18, y: -62), control2: CGPoint(x: 12, y: -72))
        drizzle.addCurve(to: CGPoint(x: -8, y: -68), control1: CGPoint(x: 3, y: -58), control2: CGPoint(x: -3, y: -60))
        drizzle.addCurve(to: CGPoint(x: -22, y: -76), control1: CGPoint(x: -14, y: -74), control2: CGPoint(x: -18, y: -64))
        drizzle.closeSubpath()
        blob(g, drizzle, Color(hex: 0xFFFDF8), StorybookArt.outline(for: 0xF0D8BE), 2)

        let mochi: [(CGFloat, Color, UInt32)] = [
            (-32, pink, 0xFF8FB8), (-16, mint, 0x8AE0C4),
            (0, lemon, 0xFFE38A), (16, lilac, 0xC9B6FF), (32, peach, 0xFFC09F),
        ]
        for (mx, col, hex) in mochi {
            blob(g, oval(mx, -42, 7, 5.5), col, StorybookArt.outline(for: hex), 2)
        }

        blob(g, rrect(-22, -10, 44, 9, 4.5), gold, goldLine, 2.2)
        blob(g, rrect(-10, -18, 20, 10, 4), Color(hex: 0xFFF2F8), bowlLine, 2.2)
        var bowl = Path()
        bowl.move(to: CGPoint(x: -44, y: -40))
        bowl.addLine(to: CGPoint(x: 44, y: -40))
        bowl.addCurve(to: CGPoint(x: 0, y: -14), control1: CGPoint(x: 40, y: -20), control2: CGPoint(x: 20, y: -14))
        bowl.addCurve(to: CGPoint(x: -44, y: -40), control1: CGPoint(x: -20, y: -14), control2: CGPoint(x: -40, y: -20))
        bowl.closeSubpath()
        blob(g, bowl, Color(hex: 0xFFF8FC), bowlLine, 2.8)
        var rim = Path()
        rim.move(to: CGPoint(x: -44, y: -39))
        rim.addLine(to: CGPoint(x: 44, y: -39))
        strokePath(g, rim, goldLine, 6)
        strokePath(g, rim, gold, 3)

        let crown = poly([
            CGPoint(x: -13, y: -96), CGPoint(x: -15, y: -112), CGPoint(x: -6, y: -105),
            CGPoint(x: 0, y: -116), CGPoint(x: 6, y: -105), CGPoint(x: 15, y: -112), CGPoint(x: 13, y: -96),
        ])
        blob(g, crown, gold, goldLine, 2.2)
        blob(g, oval(0, -102, 3.6, 3.6), pink, StorybookArt.outline(for: 0xFF7CA8), 1.5)

        twinkle(g, -44, -98, 5)
        twinkle(g, 48, -110, 4.5)
    }

    // MARK: Pizza — Pastel-tiled wood-fired golden oven

    static let goldOvenSize = CGSize(width: 136, height: 116)

    static func goldOven(_ g: GraphicsContext) {
        let domeLine = StorybookArt.outline(for: 0xE6A4C2)

        blob(g, rrect(18, -100, 18, 28, 5), Color(hex: 0xFFB8CE), domeLine, 2.5)
        blob(g, rrect(15, -104, 24, 7, 3.5), gold, goldLine, 2)
        g.fill(heartPath(cx: 27, cy: -110, size: 12), with: .color(.white.opacity(0.92)))

        let dome = Path { p in
            p.move(to: CGPoint(x: -54, y: -14))
            p.addCurve(to: CGPoint(x: 0, y: -94), control1: CGPoint(x: -56, y: -68), control2: CGPoint(x: -32, y: -94))
            p.addCurve(to: CGPoint(x: 54, y: -14), control1: CGPoint(x: 32, y: -94), control2: CGPoint(x: 56, y: -68))
            p.closeSubpath()
        }
        blob(g, dome, Color(hex: 0xFFF3F8), domeLine, 3)

        let tiles: [(CGFloat, CGFloat, Color)] = [
            (-32, -32, pink), (-38, -48, peach), (-26, -66, lemon), (-8, -78, mint),
            (12, -78, sky), (28, -66, lilac), (38, -48, pink), (32, -32, mint),
            (-16, -54, sky), (16, -54, peach), (0, -68, pink),
        ]
        for (tx, ty, col) in tiles {
            blob(g, rrect(tx - 6.5, ty - 5, 13, 10, 3), col, domeLine.opacity(0.55), 1.6)
        }

        let outerArch = Path { p in
            p.move(to: CGPoint(x: -30, y: -14))
            p.addLine(to: CGPoint(x: -30, y: -38))
            p.addArc(center: CGPoint(x: 0, y: -38), radius: 30, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: CGPoint(x: 30, y: -14))
            p.closeSubpath()
        }
        blob(g, outerArch, gold, goldLine, 2.6)

        let innerArch = Path { p in
            p.move(to: CGPoint(x: -22, y: -14))
            p.addLine(to: CGPoint(x: -22, y: -38))
            p.addArc(center: CGPoint(x: 0, y: -38), radius: 22, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: CGPoint(x: 22, y: -14))
            p.closeSubpath()
        }
        blob(g, innerArch, Color(hex: 0x5B3858), StorybookArt.outline(for: 0x4A2B48), 2.2)

        var flame = Path()
        flame.move(to: CGPoint(x: -11, y: -16))
        flame.addCurve(to: CGPoint(x: 0, y: -46), control1: CGPoint(x: -16, y: -28), control2: CGPoint(x: -8, y: -38))
        flame.addCurve(to: CGPoint(x: 11, y: -16), control1: CGPoint(x: 8, y: -38), control2: CGPoint(x: 16, y: -28))
        flame.closeSubpath()
        g.fill(flame, with: .color(Color(hex: 0xFF9C52)))
        var flameIn = Path()
        flameIn.move(to: CGPoint(x: -6, y: -16))
        flameIn.addCurve(to: CGPoint(x: 0, y: -36), control1: CGPoint(x: -8, y: -24), control2: CGPoint(x: -4, y: -30))
        flameIn.addCurve(to: CGPoint(x: 6, y: -16), control1: CGPoint(x: 4, y: -30), control2: CGPoint(x: 8, y: -24))
        flameIn.closeSubpath()
        g.fill(flameIn, with: .color(lemon))

        blob(g, rrect(-60, -14, 120, 13, 6), Color(hex: 0xFFE6C8), StorybookArt.outline(for: 0xDFA878), 2.8)
        blob(g, starPath(cx: 0, cy: -66, outer: 7.5, inner: 3.6), lemon, goldLine, 1.8)
        twinkle(g, -48, -86, 5)
        twinkle(g, 52, -88, 4.5)
    }

    // MARK: Pizza — Rainbow-handle star pizza cutter

    static let starCutterSize = CGSize(width: 120, height: 124)

    static func starCutter(_ g: GraphicsContext) {
        let steelLine = StorybookArt.outline(for: 0xB8B8D8)

        let wx: CGFloat = -16, wy: CGFloat = -30
        blob(g, oval(wx, wy, 28, 28), Color(hex: 0xF0F2FC), steelLine, 3)
        g.stroke(oval(wx, wy, 21, 21), with: .color(steelLine.opacity(0.5)), lineWidth: 2)
        var gleam = Path()
        gleam.addArc(center: CGPoint(x: wx, y: wy), radius: 22, startAngle: .degrees(200), endAngle: .degrees(255), clockwise: false)
        strokePath(g, gleam, .white, 3.5)

        var arm = Path()
        arm.move(to: CGPoint(x: wx, y: wy))
        arm.addLine(to: CGPoint(x: 12, y: -62))
        strokePath(g, arm, goldLine, 14)
        strokePath(g, arm, gold, 8.5)

        var hCtx = g
        hCtx.translateBy(x: 24, y: -82)
        hCtx.rotate(by: .degrees(38))
        let handleShape = rrect(-11, -34, 22, 58, 11)
        hCtx.fill(handleShape, with: .color(.white))
        let bands = [pink, peach, lemon, mint, sky, lilac]
        for (i, col) in bands.enumerated() {
            let y0 = -28 + CGFloat(i) * 8.5
            hCtx.fill(rrect(-9.5, y0, 19, 8.5, 2), with: .color(col))
        }
        hCtx.fill(rrect(-6.5, -28, 4.5, 48, 2.2), with: .color(.white.opacity(0.45)))
        hCtx.stroke(handleShape, with: .color(line), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
        blob(hCtx, rrect(-12, 18, 24, 8, 4), gold, goldLine, 2.2)
        hCtx.stroke(oval(0, -39, 6.5, 6.5), with: .color(goldLine), lineWidth: 5)
        hCtx.stroke(oval(0, -39, 6.5, 6.5), with: .color(gold), lineWidth: 2.5)

        blob(g, starPath(cx: wx, cy: wy, outer: 14, inner: 6.8), gold, goldLine, 2.4)
        g.fill(oval(wx, wy, 3.8, 3.8), with: .color(Color(hex: 0xFFF8CC)))

        twinkle(g, -46, -56, 5)
        twinkle(g, 46, -68, 4.5)
        twinkle(g, 2, -112, 4.5)
    }

    // MARK: Coloring — Golden crown & heart-gem sticker stamp

    static let starStampSize = CGSize(width: 110, height: 124)

    static func starStamp(_ g: GraphicsContext) {
        let mintLine = StorybookArt.outline(for: 0x80D4B8)
        let pinkLine = StorybookArt.outline(for: 0xFF8FB8)

        blob(g, rrect(-34, -9, 68, 8, 4), gold, goldLine, 2.4)

        blob(g, rrect(-40, -30, 80, 23, 11), mint, mintLine, 3)
        g.fill(rrect(-32, -26, 64, 6, 3), with: .color(.white.opacity(0.5)))
        for sx in [-22.0, 0.0, 22.0] as [CGFloat] {
            g.fill(starPath(cx: sx, cy: -16, outer: 4.5, inner: 2.2), with: .color(.white.opacity(0.85)))
        }

        let stem = Path { p in
            p.move(to: CGPoint(x: -18, y: -30))
            p.addCurve(to: CGPoint(x: -14, y: -74), control1: CGPoint(x: -10, y: -46), control2: CGPoint(x: -10, y: -60))
            p.addLine(to: CGPoint(x: 14, y: -74))
            p.addCurve(to: CGPoint(x: 18, y: -30), control1: CGPoint(x: 10, y: -60), control2: CGPoint(x: 10, y: -46))
            p.closeSubpath()
        }
        blob(g, stem, lilac, line, 2.8)
        g.fill(oval(-6, -52, 4, 14), with: .color(.white.opacity(0.45)))

        ribbonBow(g, cx: 0, cy: -52, scale: 0.9, fill: pink, stroke: pinkLine)

        let crown = poly([
            CGPoint(x: -28, y: -74), CGPoint(x: -34, y: -106), CGPoint(x: -14, y: -92),
            CGPoint(x: 0, y: -112), CGPoint(x: 14, y: -92), CGPoint(x: 34, y: -106), CGPoint(x: 28, y: -74),
        ])
        blob(g, crown, gold, goldLine, 2.8)
        let pearls: [(CGFloat, CGFloat)] = [(-34, -106), (0, -112), (34, -106)]
        for (px, py) in pearls {
            blob(g, oval(px, py, 4.5, 4.5), .white, goldLine, 2)
        }
        blob(g, heartPath(cx: 0, cy: -86, size: 22), Color(hex: 0xFF6FA8), StorybookArt.outline(for: 0xE64D88), 2.2)
        g.fill(oval(-3.5, -89, 3.4, 2.2), with: .color(.white.opacity(0.75)))

        twinkle(g, -42, -88, 5)
        twinkle(g, 42, -92, 4.5)
        twinkle(g, 0, -120, 4.5)
    }

    // MARK: Coloring — Pastel starlight rainbow paintbrush

    static let rainbowBrushSize = CGSize(width: 122, height: 128)

    static func rainbowBrush(_ g: GraphicsContext) {
        for (i, col) in [pink, lemon, mint, sky].enumerated() {
            let r = 36 + CGFloat(i) * 5.5
            var swish = Path()
            swish.addArc(center: CGPoint(x: 16, y: -76), radius: r, startAngle: .degrees(195), endAngle: .degrees(290), clockwise: false)
            strokePath(g, swish, col.opacity(0.72), 4.5)
        }

        var b = g
        b.translateBy(x: 0, y: -62)
        b.rotate(by: .degrees(38))

        let handle = Path { p in
            p.move(to: CGPoint(x: -7.5, y: -14))
            p.addLine(to: CGPoint(x: 7.5, y: -14))
            p.addCurve(to: CGPoint(x: 0, y: 68), control1: CGPoint(x: 8, y: 24), control2: CGPoint(x: 5, y: 66))
            p.addCurve(to: CGPoint(x: -7.5, y: -14), control1: CGPoint(x: -5, y: 66), control2: CGPoint(x: -8, y: 24))
            p.closeSubpath()
        }
        b.fill(
            handle,
            with: .linearGradient(
                Gradient(colors: [pink, peach, lemon, mint, sky, lilac]),
                startPoint: CGPoint(x: 0, y: -14),
                endPoint: CGPoint(x: 0, y: 66)
            )
        )
        b.fill(rrect(-4, -10, 3, 62, 1.5), with: .color(.white.opacity(0.45)))
        strokePath(b, handle, line, 2.8)

        blob(b, rrect(-9.5, -34, 19, 22, 4), gold, goldLine, 2.6)
        b.fill(starPath(cx: 0, cy: -23, outer: 5.5, inner: 2.6), with: .color(.white.opacity(0.9)))

        let bristles = Path { p in
            p.move(to: CGPoint(x: -9, y: -34))
            p.addCurve(to: CGPoint(x: 0, y: -72), control1: CGPoint(x: -18, y: -50), control2: CGPoint(x: -8, y: -64))
            p.addCurve(to: CGPoint(x: 9, y: -34), control1: CGPoint(x: 8, y: -64), control2: CGPoint(x: 18, y: -50))
            p.closeSubpath()
        }
        b.fill(
            bristles,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFF7CB2), lemon, mint, Color(hex: 0xFFF2DC)]),
                startPoint: CGPoint(x: 0, y: -72),
                endPoint: CGPoint(x: 0, y: -34)
            )
        )
        b.fill(oval(-5, -50, 3.5, 7), with: .color(.white.opacity(0.55)))
        strokePath(b, bristles, StorybookArt.outline(for: 0xFF8FB8), 2.8)

        blob(g, oval(48, -96, 5.5, 5.5), pink, StorybookArt.outline(for: 0xFF7CA8), 1.8)
        blob(g, oval(44, -74, 4.5, 4.5), sky, StorybookArt.outline(for: 0x82C0FF), 1.8)
        twinkle(g, -34, -84, 5.5)
        twinkle(g, 18, -118, 5)
    }

    // MARK: Pet Vet — Pink stethoscope with faceted heart gem chestpiece

    static let heartScopeSize = CGSize(width: 124, height: 118)

    static func heartScope(_ g: GraphicsContext) {
        let pinkLine = StorybookArt.outline(for: 0xFF7CA8)
        let metalLine = StorybookArt.outline(for: 0xB8AED8)
        let mintLine = StorybookArt.outline(for: 0x7ED4B8)

        var arms = Path()
        arms.move(to: CGPoint(x: -40, y: -102))
        arms.addCurve(to: CGPoint(x: -18, y: -62), control1: CGPoint(x: -44, y: -74), control2: CGPoint(x: -28, y: -62))
        arms.addCurve(to: CGPoint(x: 4, y: -102), control1: CGPoint(x: -8, y: -62), control2: CGPoint(x: 8, y: -74))
        strokePath(g, arms, metalLine, 10)
        strokePath(g, arms, Color(hex: 0xEFEAFF), 5.5)

        let earTips: [(CGFloat, CGFloat)] = [(-40, -103), (4, -103)]
        for (ex, ey) in earTips {
            blob(g, oval(ex, ey, 7.5, 6), mint, mintLine, 2.2)
            g.fill(oval(ex - 2, ey - 2, 2.5, 1.8), with: .color(.white.opacity(0.75)))
        }

        var tube = Path()
        tube.move(to: CGPoint(x: -18, y: -62))
        tube.addCurve(to: CGPoint(x: -18, y: -14), control1: CGPoint(x: -20, y: -32), control2: CGPoint(x: -36, y: -14))
        tube.addCurve(to: CGPoint(x: 34, y: -42), control1: CGPoint(x: 4, y: -14), control2: CGPoint(x: 32, y: -14))
        strokePath(g, tube, pinkLine, 13)
        strokePath(g, tube, pink, 8)

        blob(g, rrect(-23, -67, 10, 9, 4), gold, goldLine, 2)

        blob(g, oval(34, -46, 22, 22), gold, goldLine, 2.8)
        blob(g, oval(34, -46, 17, 17), Color(hex: 0xFFF2F8), pinkLine, 2)
        blob(g, heartPath(cx: 34, cy: -45, size: 26), Color(hex: 0xFF6EA8), StorybookArt.outline(for: 0xE64B88), 2.2)
        g.fill(oval(30, -49, 4, 2.6), with: .color(.white.opacity(0.75)))

        twinkle(g, 46, -78, 5.5)
        twinkle(g, -18, -110, 4.5)
        g.fill(heartPath(cx: 30, cy: -86, size: 12), with: .color(pink.opacity(0.85)))
    }

    // MARK: Pet Vet — Pastel polka-dot ribbon bow bandage

    static let bowBandageSize = CGSize(width: 136, height: 94)

    static func bowBandage(_ g: GraphicsContext) {
        let pinkLine = StorybookArt.outline(for: 0xFF88B4)

        var b = g
        b.translateBy(x: 0, y: -36)
        b.rotate(by: .degrees(-6))
        let strip = rrect(-60, -22, 120, 44, 22)
        blob(b, strip, Color(hex: 0xFFD9E8), pinkLine, 3)

        let dots: [(CGFloat, CGFloat, Color)] = [
            (-44, -9, lemon), (-32, 8, mint), (-48, 8, sky), (-28, -10, lilac),
            (30, -10, lemon), (46, -8, sky), (34, 9, lilac), (48, 8, mint),
        ]
        for (dx, dy, col) in dots {
            b.fill(oval(dx, dy, 4.8, 4.8), with: .color(col))
        }

        blob(b, rrect(-20, -18, 40, 36, 9), Color(hex: 0xFFFDF8), StorybookArt.outline(for: 0xE8C2D4), 2.2)
        for gx in [-10.0, 0.0, 10.0] as [CGFloat] {
            for gy in [-8.0, 0.0, 8.0] as [CGFloat] {
                b.fill(oval(gx, gy, 1.7, 1.7), with: .color(Color(hex: 0xE6B6CC)))
            }
        }

        for side in [-1.0, 1.0] as [CGFloat] {
            var tail = Path()
            tail.move(to: CGPoint(x: side * 5, y: -56))
            tail.addQuadCurve(to: CGPoint(x: side * 20, y: -38), control: CGPoint(x: side * 16, y: -48))
            strokePath(g, tail, pinkLine, 7.5)
            strokePath(g, tail, Color(hex: 0xFF7CA8), 4)
        }
        ribbonBow(g, cx: 0, cy: -62, scale: 1.25, fill: Color(hex: 0xFF82B0), stroke: pinkLine)

        g.fill(heartPath(cx: -44, cy: -74, size: 13), with: .color(pink))
        g.fill(heartPath(cx: 46, cy: -76, size: 11), with: .color(lilac))
        twinkle(g, 0, -88, 5)
    }

    // MARK: Salon — Royal silk daenggi hair ribbon (왕실 댕기)

    static let royalDaenggiSize = CGSize(width: 112, height: 130)

    static func royalDaenggi(_ g: GraphicsContext) {
        let crimson = Color(hex: 0xEE5884)
        let crimsonLight = Color(hex: 0xFF7EA6)
        let crimsonLine = StorybookArt.outline(for: 0xCC3664)
        let gemYs: [CGFloat] = [-66, -42]

        for (side, fill) in [(-1.0, crimsonLight), (1.0, crimson)] as [(CGFloat, Color)] {
            let xInner = side * 4
            let xOuter = side * 28
            let xTip = side * 34
            let tail = Path { p in
                p.move(to: CGPoint(x: xInner, y: -92))
                p.addLine(to: CGPoint(x: xOuter * 0.72, y: -92))
                p.addCurve(
                    to: CGPoint(x: xTip, y: -12),
                    control1: CGPoint(x: xOuter, y: -64),
                    control2: CGPoint(x: xTip * 1.04, y: -34)
                )
                p.addLine(to: CGPoint(x: side * 19, y: -22))
                p.addLine(to: CGPoint(x: side * 7, y: -8))
                p.addCurve(
                    to: CGPoint(x: xInner, y: -92),
                    control1: CGPoint(x: side * 6, y: -36),
                    control2: CGPoint(x: xInner, y: -64)
                )
                p.closeSubpath()
            }
            blob(g, tail, fill, crimsonLine, 2.8)

            for (k, gy) in gemYs.enumerated() {
                let gx = side * (16 + CGFloat(k) * 3)
                blossom(g, cx: gx, cy: gy, r: 6.2, petal: gold, stroke: goldLine, center: Color(hex: 0xFFF7C2))
            }
            blob(g, oval(side * 19, -15, 3.8, 3.8), Color(hex: 0xFFF6FA), goldLine, 1.6)
        }

        ribbonBow(g, cx: 0, cy: -96, scale: 1.32, fill: crimsonLight, stroke: crimsonLine)
        blossom(g, cx: 0, cy: -96, r: 12, petal: gold, stroke: goldLine, center: .white)

        twinkle(g, -42, -114, 5)
        twinkle(g, 42, -112, 4.5)
        twinkle(g, 0, -124, 4.5)
    }

    // MARK: Salon — Pastel pink star-nozzle hair dryer

    static let starDryerSize = CGSize(width: 134, height: 114)

    static func starDryer(_ g: GraphicsContext) {
        let pinkLine = StorybookArt.outline(for: 0xFF7CA8)

        for (i, col) in [pink, lemon, mint, sky].enumerated() {
            let y0 = -84 + CGFloat(i) * 9.5
            var breeze = Path()
            breeze.move(to: CGPoint(x: 34, y: y0))
            breeze.addCurve(
                to: CGPoint(x: 62, y: y0 - 8 + CGFloat(i) * 4),
                control1: CGPoint(x: 44, y: y0 - 7),
                control2: CGPoint(x: 52, y: y0 + 7)
            )
            strokePath(g, breeze, col, 4)
        }

        let handle = Path { p in
            p.move(to: CGPoint(x: -28, y: -50))
            p.addLine(to: CGPoint(x: -8, y: -50))
            p.addCurve(to: CGPoint(x: -14, y: -6), control1: CGPoint(x: -8, y: -28), control2: CGPoint(x: -8, y: -12))
            p.addQuadCurve(to: CGPoint(x: -34, y: -6), control: CGPoint(x: -24, y: 0))
            p.addCurve(to: CGPoint(x: -28, y: -50), control1: CGPoint(x: -36, y: -20), control2: CGPoint(x: -32, y: -36))
            p.closeSubpath()
        }
        blob(g, handle, Color(hex: 0xFFA2C6), pinkLine, 2.8)
        blob(g, oval(-11, -34, 4, 4), mint, StorybookArt.outline(for: 0x7ED4B8), 1.6)
        blob(g, oval(-12, -22, 4, 4), lemon, goldLine, 1.6)

        let nozzle = poly([
            CGPoint(x: 12, y: -82), CGPoint(x: 32, y: -90), CGPoint(x: 28, y: -76),
            CGPoint(x: 36, y: -68), CGPoint(x: 28, y: -60), CGPoint(x: 32, y: -48), CGPoint(x: 12, y: -56),
        ])
        blob(g, nozzle, gold, goldLine, 2.6)

        let barrel = Path { p in
            p.move(to: CGPoint(x: -44, y: -92))
            p.addQuadCurve(to: CGPoint(x: 16, y: -82), control: CGPoint(x: -12, y: -96))
            p.addLine(to: CGPoint(x: 16, y: -54))
            p.addQuadCurve(to: CGPoint(x: -44, y: -46), control: CGPoint(x: -12, y: -42))
            p.addCurve(to: CGPoint(x: -44, y: -92), control1: CGPoint(x: -60, y: -52), control2: CGPoint(x: -60, y: -86))
            p.closeSubpath()
        }
        blob(g, barrel, Color(hex: 0xFF9AC0), pinkLine, 3)
        g.fill(oval(-18, -82, 18, 5.5), with: .color(.white.opacity(0.5)))

        blob(g, oval(-48, -69, 9, 17), lilac, line, 2.4)
        blob(g, starPath(cx: -14, cy: -68, outer: 11, inner: 5.2), gold, goldLine, 2)

        twinkle(g, 48, -100, 5.5)
        twinkle(g, 58, -50, 4.5)
        twinkle(g, -46, -98, 4)
    }

    // MARK: Tidy Up — Fairy-dusted golden sparkle whisk broom

    static let starBroomSize = CGSize(width: 118, height: 128)

    static func starBroom(_ g: GraphicsContext) {
        let strawLine = StorybookArt.outline(for: 0xDFA636)
        let mintLine = StorybookArt.outline(for: 0x7ED4B8)
        let pinkLine = StorybookArt.outline(for: 0xFF8FB8)

        g.fill(
            oval(-4, -30, 48, 30),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF2AA).opacity(0.72), .clear]),
                center: CGPoint(x: -4, y: -30),
                startRadius: 4,
                endRadius: 48
            )
        )

        var handle = Path()
        handle.move(to: CGPoint(x: 0, y: -54))
        handle.addLine(to: CGPoint(x: 18, y: -116))
        strokePath(g, handle, mintLine, 14)
        strokePath(g, handle, mint, 9)

        g.stroke(oval(21, -121, 5.5, 5.5), with: .color(goldLine), lineWidth: 4.5)
        g.stroke(oval(21, -121, 5.5, 5.5), with: .color(gold), lineWidth: 2)
        blob(g, starPath(cx: 34, cy: -102, outer: 10, inner: 4.8), gold, goldLine, 2)

        let bristles = Path { p in
            p.move(to: CGPoint(x: -12, y: -54))
            p.addLine(to: CGPoint(x: 12, y: -54))
            p.addCurve(to: CGPoint(x: 38, y: -8), control1: CGPoint(x: 24, y: -40), control2: CGPoint(x: 36, y: -24))
            p.addQuadCurve(to: CGPoint(x: 18, y: -4), control: CGPoint(x: 30, y: 0))
            p.addQuadCurve(to: CGPoint(x: 0, y: -3), control: CGPoint(x: 9, y: 1))
            p.addQuadCurve(to: CGPoint(x: -18, y: -4), control: CGPoint(x: -9, y: 1))
            p.addQuadCurve(to: CGPoint(x: -38, y: -8), control: CGPoint(x: -30, y: 0))
            p.addCurve(to: CGPoint(x: -12, y: -54), control1: CGPoint(x: -36, y: -24), control2: CGPoint(x: -24, y: -40))
            p.closeSubpath()
        }
        blob(g, bristles, Color(hex: 0xFFE282), strawLine, 2.8)
        for sx in [-18.0, -7.0, 5.0, 17.0] as [CGFloat] {
            var straw = Path()
            straw.move(to: CGPoint(x: sx * 0.35, y: -50))
            straw.addQuadCurve(to: CGPoint(x: sx * 1.35, y: -7), control: CGPoint(x: sx * 0.9, y: -28))
            strokePath(g, straw, strawLine.opacity(0.55), 2)
        }

        blob(g, rrect(-16, -60, 32, 11, 5), lilac, line, 2.4)
        ribbonBow(g, cx: 0, cy: -56, scale: 0.95, fill: pink, stroke: pinkLine)

        twinkle(g, -42, -36, 5.5)
        twinkle(g, 44, -44, 5)
        twinkle(g, -22, -88, 5)
        twinkle(g, 44, -76, 4)
    }

    // MARK: Tidy Up — Pastel teddy bear wearing a colorful Hanbok (한복 곰돌이)

    static let plushBearSize = CGSize(width: 118, height: 124)

    static func plushBear(_ g: GraphicsContext) {
        let fur = Color(hex: 0xF9DFC0)
        let furLine = StorybookArt.outline(for: 0xD9A978)
        let chima = Color(hex: 0xFFA2C2)
        let chimaLine = StorybookArt.outline(for: 0xEE78A2)
        let jeogori = Color(hex: 0xA8DCFF)
        let jeogoriLine = StorybookArt.outline(for: 0x76B8EE)

        for side in [-1.0, 1.0] as [CGFloat] {
            blob(g, oval(side * 25, -12, 13, 10), fur, furLine, 2.6)
            g.fill(oval(side * 25, -11, 7, 5), with: .color(Color(hex: 0xFFD2E2)))
        }

        let skirt = Path { p in
            p.move(to: CGPoint(x: -20, y: -52))
            p.addLine(to: CGPoint(x: 20, y: -52))
            p.addCurve(to: CGPoint(x: 36, y: -12), control1: CGPoint(x: 34, y: -40), control2: CGPoint(x: 40, y: -22))
            p.addQuadCurve(to: CGPoint(x: -36, y: -12), control: CGPoint(x: 0, y: -3))
            p.addCurve(to: CGPoint(x: -20, y: -52), control1: CGPoint(x: -40, y: -22), control2: CGPoint(x: -34, y: -40))
            p.closeSubpath()
        }
        blob(g, skirt, chima, chimaLine, 2.8)
        for px in [-14.0, 0.0, 14.0] as [CGFloat] {
            var pleat = Path()
            pleat.move(to: CGPoint(x: px * 0.65, y: -46))
            pleat.addQuadCurve(to: CGPoint(x: px * 1.25, y: -12), control: CGPoint(x: px * 1.0, y: -28))
            strokePath(g, pleat, chimaLine.opacity(0.45), 1.8)
        }
        for hx in [-22.0, -8.0, 8.0, 22.0] as [CGFloat] {
            g.fill(oval(hx, -14, 2.6, 2.6), with: .color(lemon))
        }

        for side in [-1.0, 1.0] as [CGFloat] {
            var arm = g
            arm.translateBy(x: side * 24, y: -56)
            arm.rotate(by: .degrees(side * 26))
            let sleeve = rrect(-9, -6, 18, 22, 8)
            arm.fill(sleeve, with: .color(jeogori))
            let stripes = [pink, lemon, mint]
            for (i, col) in stripes.enumerated() {
                arm.fill(rrect(-7.5, 1 + CGFloat(i) * 4.5, 15, 4.5, 1.5), with: .color(col))
            }
            strokePath(arm, sleeve, jeogoriLine, 2.4)
            blob(arm, oval(0, 18, 7, 6.5), fur, furLine, 2.4)
        }

        blob(g, rrect(-22, -68, 44, 22, 10), jeogori, jeogoriLine, 2.6)
        var collar = Path()
        collar.move(to: CGPoint(x: -11, y: -67))
        collar.addLine(to: CGPoint(x: 0, y: -55))
        collar.addLine(to: CGPoint(x: 11, y: -67))
        strokePath(g, collar, .white, 5.5)
        var tie = Path()
        tie.move(to: CGPoint(x: 4, y: -54))
        tie.addQuadCurve(to: CGPoint(x: 11, y: -34), control: CGPoint(x: 12, y: -44))
        strokePath(g, tie, chimaLine, 6)
        strokePath(g, tie, Color(hex: 0xFF7CA8), 3)
        blob(g, oval(3, -55, 5, 4), Color(hex: 0xFF7CA8), chimaLine, 1.8)

        for side in [-1.0, 1.0] as [CGFloat] {
            blob(g, oval(side * 21, -108, 10.5, 10.5), fur, furLine, 2.6)
            g.fill(oval(side * 21, -108, 5.5, 5.5), with: .color(Color(hex: 0xFFD2E2)))
        }
        blob(g, oval(0, -88, 27, 24), fur, furLine, 3)
        g.fill(oval(-9, -98, 8, 5), with: .color(.white.opacity(0.45)))

        blob(g, oval(0, -81, 11, 8.5), Color(hex: 0xFFF7EC), furLine.opacity(0.6), 1.6)
        for ex in [-10.0, 10.0] as [CGFloat] {
            g.fill(oval(ex, -90, 3.4, 3.8), with: .color(Theme.ink))
            g.fill(oval(ex - 1.2, -91.5, 1.3, 1.3), with: .color(.white))
        }
        g.fill(oval(0, -84, 3.6, 2.6), with: .color(Theme.ink))
        var smile = Path()
        smile.move(to: CGPoint(x: -4.5, y: -79))
        smile.addQuadCurve(to: CGPoint(x: 4.5, y: -79), control: CGPoint(x: 0, y: -74.5))
        strokePath(g, smile, Theme.ink, 2)
        g.fill(oval(-16, -83, 4.8, 3), with: .color(pink.opacity(0.55)))
        g.fill(oval(16, -83, 4.8, 3), with: .color(pink.opacity(0.55)))

        twinkle(g, -40, -106, 4.8)
        twinkle(g, 40, -108, 4.8)
    }
}
