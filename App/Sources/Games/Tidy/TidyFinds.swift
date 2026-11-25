import SwiftUI

enum TidyFind: String, CaseIterable {
    case firstRoom
    case kitchenWhiz
    case cozyCloset
    case toyMaster
    case colorSorter
    case tidyChampion

    static var stickers: [Sticker] {
        allCases.map { find in
            Sticker(id: find.rawValue) { ctx, _ in
                find.drawSticker(ctx)
            }
        }
    }

    /// Stickers unlocked upon completing `level` (with optional completed count for `tidyChampion`).
    static func unlocks(for level: TidyLevel, completedCount: Int = 1) -> [TidyFind] {
        var found: [TidyFind] = [.firstRoom]
        switch level.scene {
        case .fridge, .cupboard, .drawer, .pantry, .crate:
            found.append(.kitchenWhiz)
        case .closet, .socks, .bathroom, .backpack:
            found.append(.cozyCloset)
        case .toys, .bookshelf:
            found.append(.toyMaster)
        case .pencilCase:
            break
        }
        if level.slots.contains(where: \.strict) {
            found.append(.colorSorter)
        }
        if completedCount >= 6 {
            found.append(.tidyChampion)
        }
        return found
    }

    /// Drawn centered in a 100x100 square (-50...50).
    func drawSticker(_ g: GraphicsContext) {
        switch self {
        case .firstRoom:
            drawFirstRoom(g)
        case .kitchenWhiz:
            drawKitchenWhiz(g)
        case .cozyCloset:
            drawCozyCloset(g)
        case .toyMaster:
            drawToyMaster(g)
        case .colorSorter:
            drawColorSorter(g)
        case .tidyChampion:
            drawTidyChampion(g)
        }
    }

    private func drawFirstRoom(_ g: GraphicsContext) {
        // Open cardboard moving box with sparkles & golden star popping out
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var flap = Path()
            flap.move(to: CGPoint(x: s * 28, y: -4))
            flap.addLine(to: CGPoint(x: s * 40, y: -16))
            flap.addLine(to: CGPoint(x: s * 22, y: -20))
            flap.addLine(to: CGPoint(x: s * 10, y: -6))
            flap.closeSubpath()
            StorybookArt.fillAndStroke(
                g,
                flap,
                fill: StorybookArt.color(0xEBC18D),
                stroke: StorybookArt.outline(for: 0xC99053),
                width: 2.8
            )
        }

        let box = Path(roundedRect: CGRect(x: -28, y: -6, width: 56, height: 38), cornerRadius: 8)
        StorybookArt.fillAndStroke(
            g,
            box,
            fill: StorybookArt.color(0xDFAD74),
            stroke: StorybookArt.outline(for: 0xC0864B),
            width: 3.2
        )
        let tape = Path(CGRect(x: -6, y: -4, width: 12, height: 34))
        g.fill(tape, with: .color(StorybookArt.color(0xF6DFB7, alpha: 0.9)))
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 14), size: 18, color: Theme.pink)

        let star = starPath(center: CGPoint(x: 0, y: -22), outer: 18, inner: 9)
        StorybookArt.fillAndStroke(
            g,
            star,
            fill: StorybookArt.color(0xFFE378),
            stroke: StorybookArt.outline(for: 0xE0A52B),
            width: 2.8
        )
        StorybookArt.sparkle(g, at: CGPoint(x: -30, y: -30), radius: 7, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 31, y: -28), radius: 7.5, color: Theme.mint)
    }

    private func drawKitchenWhiz(_ g: GraphicsContext) {
        // Neat stack of pastel-rimmed china plates
        let plateColors: [UInt32] = [0x9CCBFF, 0xFF8FB8, 0x9FE3CF]
        for i in 0..<3 {
            let y: CGFloat = 22 - CGFloat(i) * 10
            let plate = Path(ellipseIn: CGRect(x: -32, y: y - 7, width: 64, height: 14))
            StorybookArt.fillAndStroke(
                g,
                plate,
                fill: StorybookArt.color(0xFFFDF9),
                stroke: StorybookArt.outline(for: 0xC8B7A6),
                width: 2.6
            )
            let rim = Path(ellipseIn: CGRect(x: -25, y: y - 4, width: 50, height: 8))
            g.stroke(rim, with: .color(StorybookArt.color(plateColors[i])), lineWidth: 2.4)
        }

        // Cute polka-dot pastel mug perched on top
        let handle = Path(ellipseIn: CGRect(x: 11, y: -24, width: 16, height: 18))
        g.stroke(handle, with: .color(StorybookArt.outline(for: 0xFF8FB8)), lineWidth: 7)
        g.stroke(handle, with: .color(StorybookArt.color(0xFFA6C8)), lineWidth: 3.5)

        let mug = Path(roundedRect: CGRect(x: -18, y: -30, width: 34, height: 32), cornerRadius: 7)
        StorybookArt.fillAndStroke(
            g,
            mug,
            fill: StorybookArt.color(0xFFA6C8),
            stroke: StorybookArt.outline(for: 0xE6749E),
            width: 3
        )
        StorybookArt.heart(g, at: CGPoint(x: -1, y: -14), size: 15, color: .white)
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -26, width: 5, height: 16), opacity: 0.55)

        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -24), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -8), radius: 7, color: Theme.sky)
    }

    private func drawCozyCloset(_ g: GraphicsContext) {
        // Golden hanger hook
        var hook = Path()
        hook.move(to: CGPoint(x: 0, y: -20))
        hook.addLine(to: CGPoint(x: 0, y: -28))
        hook.addCurve(to: CGPoint(x: -7, y: -35), control1: CGPoint(x: 0, y: -35), control2: CGPoint(x: -6, y: -37))
        g.stroke(hook, with: .color(StorybookArt.outline(for: 0xD89A3C)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        var bar = Path()
        bar.move(to: CGPoint(x: 0, y: -21))
        bar.addLine(to: CGPoint(x: 24, y: -10))
        bar.addLine(to: CGPoint(x: -24, y: -10))
        bar.closeSubpath()
        g.stroke(bar, with: .color(StorybookArt.color(0xE8B468)), style: StrokeStyle(lineWidth: 4, lineJoin: .round))

        // Pastel pink shirt
        var shirt = Path()
        shirt.move(to: CGPoint(x: -9, y: -15))
        shirt.addLine(to: CGPoint(x: -32, y: -5))
        shirt.addLine(to: CGPoint(x: -36, y: 12))
        shirt.addLine(to: CGPoint(x: -22, y: 16))
        shirt.addLine(to: CGPoint(x: -20, y: 7))
        shirt.addLine(to: CGPoint(x: -20, y: 34))
        shirt.addLine(to: CGPoint(x: 20, y: 34))
        shirt.addLine(to: CGPoint(x: 20, y: 7))
        shirt.addLine(to: CGPoint(x: 22, y: 16))
        shirt.addLine(to: CGPoint(x: 36, y: 12))
        shirt.addLine(to: CGPoint(x: 32, y: -5))
        shirt.addLine(to: CGPoint(x: 9, y: -15))
        shirt.addQuadCurve(to: CGPoint(x: -9, y: -15), control: CGPoint(x: 0, y: -5))
        shirt.closeSubpath()

        StorybookArt.fillAndStroke(
            g,
            shirt,
            fill: StorybookArt.color(0xFFB3D1),
            stroke: StorybookArt.outline(for: 0xE6749E),
            width: 3.2
        )
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 12), size: 18, color: .white)
        StorybookArt.highlight(g, in: CGRect(x: -16, y: -6, width: 6, height: 18), opacity: 0.45)

        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -26), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -24), radius: 7.5, color: Theme.lilac)
    }

    private func drawToyMaster(_ g: GraphicsContext) {
        // Pyramid of 3 pastel blocks
        let blocks: [(CGFloat, CGFloat, UInt32, Int)] = [
            (-16, 18, 0xFF8FB8, 1),
            (16, 18, 0x8AC7FF, 2),
            (0, -10, 0x9FE3CF, 0),
        ]
        for (bx, by, hex, emblem) in blocks {
            let rect = CGRect(x: bx - 15, y: by - 15, width: 30, height: 30)
            StorybookArt.fillAndStroke(
                g,
                Path(roundedRect: rect, cornerRadius: 7),
                fill: StorybookArt.color(hex),
                stroke: StorybookArt.outline(for: hex),
                width: 3
            )
            let inner = rect.insetBy(dx: 5, dy: 5)
            g.fill(Path(roundedRect: inner, cornerRadius: 4), with: .color(.white.opacity(0.32)))
            TPaint.emblem(g, emblem, at: CGPoint(x: bx, y: by), size: 13, color: .white)
        }

        // Smiling golden star perched on top
        let star = starPath(center: CGPoint(x: 0, y: -31), outer: 13, inner: 6.5)
        StorybookArt.fillAndStroke(
            g,
            star,
            fill: Theme.lemon,
            stroke: StorybookArt.outline(for: 0xDDA63B),
            width: 2.5
        )
        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 33, y: -22), radius: 6.5, color: Theme.pink)
    }

    private func drawColorSorter(_ g: GraphicsContext) {
        // Joyful rainbow fan of pastel crayons
        let hexes: [UInt32] = [0xFF7D78, 0xFFAF66, 0xFFE066, 0x82D682, 0x7EC4FF, 0xC29EFF]
        let count = hexes.count
        for (i, hex) in hexes.enumerated() {
            let angle = -0.58 + Double(i) * (1.16 / Double(count - 1))
            var c = g
            c.translateBy(x: 0, y: 24)
            c.rotate(by: .radians(angle))
            var tip = Path()
            tip.move(to: CGPoint(x: -5.5, y: -44))
            tip.addLine(to: CGPoint(x: 0, y: -56))
            tip.addLine(to: CGPoint(x: 5.5, y: -44))
            tip.closeSubpath()
            StorybookArt.fillAndStroke(c, tip, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.2)

            let body = Path(roundedRect: CGRect(x: -6.5, y: -44, width: 13, height: 42), cornerRadius: 3)
            StorybookArt.fillAndStroke(c, body, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.4)
            c.fill(Path(CGRect(x: -5.5, y: -36, width: 11, height: 4)), with: .color(.white.opacity(0.65)))
            c.fill(Path(CGRect(x: -5.5, y: -14, width: 11, height: 4)), with: .color(.white.opacity(0.65)))
        }

        // Soft cloud base tying the rainbow together
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-18, 22, 11), (0, 19, 14), (18, 22, 11)]
        for (px, py, pr) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                     with: .color(Theme.blush), lineWidth: 5)
        }
        for (px, py, pr) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(.white))
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -20), radius: 7.5, color: Theme.pink)
    }

    private func drawTidyChampion(_ g: GraphicsContext) {
        // Trophy handles
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let handle = Path(ellipseIn: CGRect(x: s < 0 ? -34 : 16, y: -22, width: 18, height: 24))
            g.stroke(handle, with: .color(StorybookArt.outline(for: 0xDDA63B)), lineWidth: 8.5)
            g.stroke(handle, with: .color(StorybookArt.color(0xFFE074)), lineWidth: 4)
        }

        // Trophy cup
        var cup = Path()
        cup.move(to: CGPoint(x: -24, y: -28))
        cup.addLine(to: CGPoint(x: 24, y: -28))
        cup.addCurve(to: CGPoint(x: 8, y: 10), control1: CGPoint(x: 24, y: -4), control2: CGPoint(x: 16, y: 8))
        cup.addLine(to: CGPoint(x: -8, y: 10))
        cup.addCurve(to: CGPoint(x: -24, y: -28), control1: CGPoint(x: -16, y: 8), control2: CGPoint(x: -24, y: -4))
        cup.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            cup,
            fill: StorybookArt.color(0xFFE074),
            stroke: StorybookArt.outline(for: 0xD99E2B),
            width: 3.4
        )
        StorybookArt.highlight(g, in: CGRect(x: -17, y: -22, width: 7, height: 18), opacity: 0.65)

        // Stem & pedestal
        let stem = Path(roundedRect: CGRect(x: -5, y: 9, width: 10, height: 15), cornerRadius: 3)
        StorybookArt.fillAndStroke(g, stem, fill: StorybookArt.color(0xF6C758), stroke: StorybookArt.outline(for: 0xD99E2B), width: 2.8)
        let base = Path(roundedRect: CGRect(x: -22, y: 22, width: 44, height: 14), cornerRadius: 6)
        StorybookArt.fillAndStroke(g, base, fill: StorybookArt.color(0xC9B6FF), stroke: StorybookArt.outline(for: 0x977EDB), width: 3)

        StorybookArt.heart(g, at: CGPoint(x: 0, y: -11), size: 20, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: -31, y: -32), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -30), radius: 8, color: Theme.mint)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -38), radius: 7, color: Theme.pink)
    }

    private func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        var p = Path()
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let r = k.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
