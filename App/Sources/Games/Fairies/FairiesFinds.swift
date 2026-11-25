import SwiftUI

enum FairiesFind: String, CaseIterable {
    case firstFairy
    case wandMagic
    case musicChime
    case compactParty
    case rainbowCollection
    case silkFairy

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
        case .firstFairy:
            drawFirstFairy(g)
        case .wandMagic:
            drawWandMagic(g)
        case .musicChime:
            drawMusicChime(g)
        case .compactParty:
            drawCompactParty(g)
        case .rainbowCollection:
            drawRainbowCollection(g)
        case .silkFairy:
            drawSilkFairy(g)
        }
    }

    private func drawFirstFairy(_ g: GraphicsContext) {
        let halo = FairiesArt.heartPath(center: CGPoint(x: 0, y: 2), size: 78)
        StorybookArt.fillAndStroke(
            g,
            halo,
            fill: StorybookArt.color(0xFFE6F3),
            stroke: StorybookArt.outline(for: 0xFFA2CE),
            width: 3.2
        )
        var fc = g
        fc.translateBy(x: 0, y: 5)
        FairiesArt.drawFairy(fc, kind: .heart, mood: .giggle, accessory: nil, time: 0.3, scale: 0.84, blinkSeed: 0)
        StorybookArt.sparkle(g, at: CGPoint(x: -31, y: -26), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -22), radius: 6, color: Theme.pink)
        StorybookArt.heart(g, at: CGPoint(x: 28, y: 26), size: 12, color: Theme.pink)
    }

    private func drawWandMagic(_ g: GraphicsContext) {
        var c = g
        c.rotate(by: .radians(-0.68))

        // Wand handle
        var stick = Path()
        stick.move(to: CGPoint(x: 0, y: 36))
        stick.addLine(to: CGPoint(x: 0, y: -4))
        c.stroke(stick, with: .color(StorybookArt.outline(for: 0xFF8FB8)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        c.stroke(stick, with: .color(StorybookArt.color(0xFFD6E9)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))

        let pommel = Path(ellipseIn: CGRect(x: -6.5, y: 30, width: 13, height: 13))
        StorybookArt.fillAndStroke(c, pommel, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xDF9E2C), width: 2.2)

        // Mini pearl wings
        for side in [-1.0, 1.0] as [CGFloat] {
            var wing = Path()
            wing.move(to: CGPoint(x: side * 6, y: -2))
            wing.addCurve(to: CGPoint(x: side * 24, y: -14), control1: CGPoint(x: side * 18, y: 2), control2: CGPoint(x: side * 26, y: -4))
            wing.addCurve(to: CGPoint(x: side * 6, y: -10), control1: CGPoint(x: side * 18, y: -20), control2: CGPoint(x: side * 10, y: -14))
            wing.closeSubpath()
            StorybookArt.fillAndStroke(c, wing, fill: .white, stroke: StorybookArt.outline(for: 0xCFA8F2), width: 2.2)
        }

        // Golden bezel & heart jewel
        let bezel = FairiesArt.heartPath(center: CGPoint(x: 0, y: -14), size: 34)
        StorybookArt.fillAndStroke(c, bezel, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xDF9E2C), width: 2.8)
        let gem = FairiesArt.heartPath(center: CGPoint(x: 0, y: -14), size: 22)
        StorybookArt.fillAndStroke(c, gem, fill: StorybookArt.color(0xFF66A8), stroke: StorybookArt.outline(for: 0xDA4888), width: 2)
        StorybookArt.highlight(c, in: CGRect(x: -7, y: -20, width: 6, height: 4), opacity: 0.85)

        // Rainbow magic trail sparkles around wand
        StorybookArt.sparkle(g, at: CGPoint(x: -28, y: -24), radius: 8.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 24, y: -28), radius: 7, color: Theme.sky)
        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: 12), radius: 6.5, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 30, y: 16), radius: 6.5, color: Theme.mint)
    }

    private func drawMusicChime(_ g: GraphicsContext) {
        // Blossom arch bar
        var arch = Path()
        arch.move(to: CGPoint(x: -34, y: -22))
        arch.addQuadCurve(to: CGPoint(x: 34, y: -22), control: CGPoint(x: 0, y: -36))
        g.stroke(arch, with: .color(StorybookArt.color(0x7AC78C)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        let bells: [(CGFloat, CGFloat, UInt32)] = [
            (-22, 6, 0xFFA2CE),
            (0, -2, 0xFFE27D),
            (22, 6, 0x99E6D8),
        ]
        for (bx, by, hex) in bells {
            var cord = Path()
            cord.move(to: CGPoint(x: bx, y: -24))
            cord.addLine(to: CGPoint(x: bx, y: by - 10))
            g.stroke(cord, with: .color(StorybookArt.color(0xE6AD42)), lineWidth: 2.2)

            var bell = Path()
            bell.move(to: CGPoint(x: bx - 10, y: by + 10))
            bell.addCurve(to: CGPoint(x: bx, y: by - 12), control1: CGPoint(x: bx - 11, y: by - 2), control2: CGPoint(x: bx - 6, y: by - 12))
            bell.addCurve(to: CGPoint(x: bx + 10, y: by + 10), control1: CGPoint(x: bx + 6, y: by - 12), control2: CGPoint(x: bx + 11, y: by - 2))
            bell.closeSubpath()
            StorybookArt.fillAndStroke(g, bell, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.4)
            StorybookArt.sparkle(g, at: CGPoint(x: bx, y: by + 18), radius: 5.5, color: Theme.lemon)
        }

        // Floating music notes
        for (nx, ny, hex) in [(-32.0, -4.0, UInt32(0xFF8FB8)), (32.0, -10.0, UInt32(0x9CCBFF))] {
            let dot = Path(ellipseIn: CGRect(x: nx - 4, y: ny, width: 7.5, height: 6))
            g.fill(dot, with: .color(StorybookArt.color(hex)))
            var stem = Path()
            stem.move(to: CGPoint(x: nx + 3, y: ny + 2))
            stem.addLine(to: CGPoint(x: nx + 3, y: ny - 9))
            stem.addQuadCurve(to: CGPoint(x: nx + 9, y: ny - 5), control: CGPoint(x: nx + 8, y: ny - 10))
            g.stroke(stem, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private func drawCompactParty(_ g: GraphicsContext) {
        let outer = FairiesArt.heartPath(center: CGPoint(x: 0, y: 4), size: 80)
        StorybookArt.fillAndStroke(g, outer, fill: StorybookArt.color(0xFFA6D6), stroke: StorybookArt.outline(for: 0xE6A436), width: 3.4)
        let inner = FairiesArt.heartPath(center: CGPoint(x: 0, y: 4), size: 62)
        StorybookArt.fillAndStroke(g, inner, fill: StorybookArt.color(0xFFF6FA), stroke: Theme.lemon, width: 2.4)

        // Three tiny joyful fairy silhouettes partying inside the heart compact
        let trio: [(FairyKind, CGPoint)] = [
            (.star, CGPoint(x: -16, y: -2)),
            (.melody, CGPoint(x: 16, y: -2)),
            (.heart, CGPoint(x: 0, y: 12)),
        ]
        for (kind, pos) in trio {
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            FairiesArt.drawFairy(fc, kind: kind, mood: .celebrate, accessory: nil, time: 0.4, scale: 0.44, blinkSeed: 0)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -28), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 33, y: -26), radius: 7, color: Theme.lemon)
    }

    private func drawRainbowCollection(_ g: GraphicsContext) {
        let bands: [(CGFloat, UInt32)] = [
            (36, 0xFF8FB8),
            (30, 0xFFC09F),
            (24, 0xFFE38A),
            (18, 0x9FE3CF),
            (12, 0x9CCBFF),
        ]
        for (r, hex) in bands {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: 18), radius: r, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        }

        // Fluffy clouds anchoring the rainbow
        for sx in [-28.0, 28.0] as [CGFloat] {
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-8, 2, 10), (0, -3, 12), (8, 2, 10)]
            for (dx, dy, r) in puffs {
                g.stroke(Path(ellipseIn: CGRect(x: sx + dx - r, y: 20 + dy - r, width: r * 2, height: r * 2)), with: .color(StorybookArt.outline(for: 0xB8DCFF)), lineWidth: 4.5)
            }
            for (dx, dy, r) in puffs {
                g.fill(Path(ellipseIn: CGRect(x: sx + dx - r, y: 20 + dy - r, width: r * 2, height: r * 2)), with: .color(.white))
            }
        }

        // Sparkling fairy crown & heart gem
        var crown = g
        crown.translateBy(x: 0, y: 10)
        FairiesArt.drawAccessoryIcon(crown, accessory: .crown)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -32), radius: 8, color: Theme.lemon)
        StorybookArt.heart(g, at: CGPoint(x: -24, y: -24), size: 12, color: Theme.pink)
        StorybookArt.heart(g, at: CGPoint(x: 24, y: -24), size: 12, color: Theme.lilac)
    }

    private func drawSilkFairy(_ g: GraphicsContext) {
        let medallion = Path(ellipseIn: CGRect(x: -36, y: -36, width: 72, height: 72))
        StorybookArt.fillAndStroke(
            g,
            medallion,
            fill: StorybookArt.color(0xE8FBF4),
            stroke: StorybookArt.outline(for: 0x9EE3CB),
            width: 3.4
        )
        let innerRing = Path(ellipseIn: CGRect(x: -30, y: -30, width: 60, height: 60))
        g.stroke(innerRing, with: .color(Theme.lemon), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

        var fc = g
        fc.translateBy(x: 0, y: 6)
        FairiesArt.drawFairy(fc, kind: .silk, mood: .happy, accessory: .daenggiRibbon, time: 0.25, scale: 0.88, blinkSeed: 0)

        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -26), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: 24), radius: 6.5, color: Theme.pink)
    }
}
