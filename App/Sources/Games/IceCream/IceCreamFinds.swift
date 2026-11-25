import SwiftUI

enum IceCreamFind: String, CaseIterable {
    case scoopMaster
    case swirlStar
    case smoothiePop
    case bingsuSnow
    case rainbowSundae
    case happyParlor

    static var stickers: [Sticker] {
        allCases.map { find in
            Sticker(id: find.rawValue) { ctx, _ in
                find.drawSticker(ctx)
            }
        }
    }

    static func earned(for build: ICBuild, stars: Int, totalServed: Int) -> [IceCreamFind] {
        var unlocked: [IceCreamFind] = []
        switch build.kind {
        case .scoops:
            unlocked.append(.scoopMaster)
        case .soft:
            unlocked.append(.swirlStar)
        case .smoothie:
            unlocked.append(.smoothiePop)
        case .bingsu:
            unlocked.append(.bingsuSnow)
        }
        let multiFlavorScoops = Set(build.scoops.map(\.flavor)).count >= 2
        let toppingCount = ICTopping.allCases.filter { build.has($0) }.count
        if multiFlavorScoops || build.has(.sprinkles) || toppingCount >= 2 {
            unlocked.append(.rainbowSundae)
        }
        if stars >= 3 || totalServed >= 3 {
            unlocked.append(.happyParlor)
        }
        return unlocked
    }

    /// Drawn centered in a 100x100 square (-50...50).
    func drawSticker(_ g: GraphicsContext) {
        switch self {
        case .scoopMaster:
            drawScoopMaster(g)
        case .swirlStar:
            drawSwirlStar(g)
        case .smoothiePop:
            drawSmoothiePop(g)
        case .bingsuSnow:
            drawBingsuSnow(g)
        case .rainbowSundae:
            drawRainbowSundae(g)
        case .happyParlor:
            drawHappyParlor(g)
        }
    }

    private func drawScoopMaster(_ g: GraphicsContext) {
        var cone = Path()
        cone.move(to: CGPoint(x: -17, y: 4))
        cone.addLine(to: CGPoint(x: 17, y: 4))
        cone.addQuadCurve(to: CGPoint(x: 0, y: 41), control: CGPoint(x: 10, y: 28))
        cone.addQuadCurve(to: CGPoint(x: -17, y: 4), control: CGPoint(x: -10, y: 28))
        cone.closeSubpath()
        StorybookArt.fillAndStroke(g, cone, fill: StorybookArt.color(0xF0B870), stroke: StorybookArt.outline(for: 0xD69347), width: 3)
        var grid = Path()
        grid.move(to: CGPoint(x: -11, y: 7)); grid.addLine(to: CGPoint(x: 7, y: 24))
        grid.move(to: CGPoint(x: 11, y: 7)); grid.addLine(to: CGPoint(x: -7, y: 24))
        g.stroke(grid, with: .color(StorybookArt.outline(for: 0xD69347).opacity(0.65)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        var wafer = Path()
        wafer.move(to: CGPoint(x: 10, y: -10))
        wafer.addLine(to: CGPoint(x: 28, y: -32))
        g.stroke(wafer, with: .color(StorybookArt.outline(for: 0xD9964A)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        g.stroke(wafer, with: .color(StorybookArt.color(0xF5C882)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        let scoops: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (0, -4, 18, 0xA8E8CF),
            (0, -19, 16, 0xFF9EC4),
            (0, -32, 13, 0xFFF2C8),
        ]
        for (sx, sy, sr, hex) in scoops {
            let p = Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr * 0.82, width: sr * 2, height: sr * 1.64))
            StorybookArt.fillAndStroke(g, p, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.8)
            StorybookArt.highlight(g, in: CGRect(x: sx - sr * 0.55, y: sy - sr * 0.52, width: sr * 0.55, height: sr * 0.34), opacity: 0.65)
        }

        let cherry = Path(ellipseIn: CGRect(x: -5.5, y: -44, width: 11, height: 11))
        StorybookArt.fillAndStroke(g, cherry, fill: StorybookArt.color(0xF25474), stroke: StorybookArt.outline(for: 0xD13657), width: 2.2)
        StorybookArt.highlight(g, in: CGRect(x: -3, y: -42, width: 3.5, height: 2.5), opacity: 0.85)
        StorybookArt.sparkle(g, at: CGPoint(x: -31, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 31, y: 12), radius: 6, color: Theme.sky)
    }

    private func drawSwirlStar(_ g: GraphicsContext) {
        var cone = Path()
        cone.move(to: CGPoint(x: -18, y: 8))
        cone.addLine(to: CGPoint(x: 18, y: 8))
        cone.addQuadCurve(to: CGPoint(x: 0, y: 42), control: CGPoint(x: 10, y: 30))
        cone.addQuadCurve(to: CGPoint(x: -18, y: 8), control: CGPoint(x: -10, y: 30))
        cone.closeSubpath()
        StorybookArt.fillAndStroke(g, cone, fill: StorybookArt.color(0xE8AC66), stroke: StorybookArt.outline(for: 0xC6843D), width: 2.8)
        let rim = Path(roundedRect: CGRect(x: -20, y: 4, width: 40, height: 7), cornerRadius: 3.5)
        StorybookArt.fillAndStroke(g, rim, fill: StorybookArt.color(0x7A4428), stroke: StorybookArt.outline(for: 0x5B2E16), width: 2.2)

        let bands: [(CGRect, UInt32)] = [
            (CGRect(x: -24, y: -6, width: 48, height: 16), 0xFFF4D6),
            (CGRect(x: -19, y: -17, width: 38, height: 14), 0xFFB8D4),
            (CGRect(x: -14, y: -27, width: 28, height: 12.5), 0xFFF6DE),
        ]
        for (rect, hex) in bands {
            let p = Path(ellipseIn: rect)
            StorybookArt.fillAndStroke(g, p, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.5)
            StorybookArt.highlight(
                g,
                in: CGRect(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.22, width: rect.width * 0.34, height: rect.height * 0.28),
                opacity: 0.72
            )
        }
        var curl = Path()
        curl.move(to: CGPoint(x: -8, y: -25))
        curl.addCurve(to: CGPoint(x: 9, y: -25), control1: CGPoint(x: -6, y: -40), control2: CGPoint(x: 7, y: -40))
        curl.closeSubpath()
        StorybookArt.fillAndStroke(g, curl, fill: StorybookArt.color(0xFFC2DC), stroke: StorybookArt.outline(for: 0xF08AB5), width: 2.3)

        drawStar(g, at: CGPoint(x: 0, y: -39), radius: 10.5, fill: 0xFFE378, outline: 0xD99622)
        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -16), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -18), radius: 6.5, color: Theme.pink)
    }

    private func drawSmoothiePop(_ g: GraphicsContext) {
        var straw = Path()
        straw.move(to: CGPoint(x: 5, y: 10))
        straw.addLine(to: CGPoint(x: 20, y: -40))
        g.stroke(straw, with: .color(StorybookArt.outline(for: 0xFF7FA8)), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))
        g.stroke(straw, with: .color(.white), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        g.stroke(straw, with: .color(StorybookArt.color(0xFF7FA8)), style: StrokeStyle(lineWidth: 5.5, lineCap: .butt, dash: [5, 5]))

        var glass = Path()
        glass.move(to: CGPoint(x: -22, y: -14))
        glass.addLine(to: CGPoint(x: 22, y: -14))
        glass.addLine(to: CGPoint(x: 16, y: 34))
        glass.addQuadCurve(to: CGPoint(x: -16, y: 34), control: CGPoint(x: 0, y: 40))
        glass.closeSubpath()

        var inside = g
        inside.clip(to: glass)
        inside.fill(Path(CGRect(x: -24, y: -14, width: 48, height: 56)), with: .linearGradient(
            Gradient(colors: [StorybookArt.color(0xFF8EB8), StorybookArt.color(0xFFB870), StorybookArt.color(0xFFE07D)]),
            startPoint: CGPoint(x: 0, y: -12),
            endPoint: CGPoint(x: 0, y: 36)
        ))

        g.stroke(glass, with: .color(StorybookArt.outline(for: 0x9CD0EC)), lineWidth: 3.4)
        StorybookArt.highlight(g, in: CGRect(x: -16, y: -6, width: 6, height: 30), opacity: 0.55)

        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-13, -15, 10), (13, -15, 10), (0, -21, 13)]
        let creamOutline = StorybookArt.outline(for: 0xE6D8E8)
        for (px, py, pr) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(creamOutline), lineWidth: 5.5)
        }
        for (px, py, pr) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(.white))
        }

        drawStar(g, at: CGPoint(x: 0, y: 12), radius: 11, fill: 0xFFE378, outline: 0xD99622)
        StorybookArt.sparkle(g, at: CGPoint(x: -31, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -8), radius: 6, color: Theme.pink)
    }

    private func drawBingsuSnow(_ g: GraphicsContext) {
        var spoon = Path()
        spoon.move(to: CGPoint(x: 10, y: -8))
        spoon.addLine(to: CGPoint(x: 32, y: -36))
        g.stroke(spoon, with: .color(StorybookArt.outline(for: 0xFFA6C8)), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
        g.stroke(spoon, with: .color(StorybookArt.color(0xFFC2DA)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        var snow = Path()
        snow.move(to: CGPoint(x: -31, y: 6))
        snow.addCurve(to: CGPoint(x: 0, y: -34), control1: CGPoint(x: -32, y: -16), control2: CGPoint(x: -16, y: -34))
        snow.addCurve(to: CGPoint(x: 31, y: 6), control1: CGPoint(x: 16, y: -34), control2: CGPoint(x: 32, y: -16))
        snow.closeSubpath()
        g.fill(
            snow,
            with: .radialGradient(
                Gradient(colors: [.white, StorybookArt.color(0xF6FAFF), StorybookArt.color(0xDCEAF6)]),
                center: CGPoint(x: -10, y: -18),
                startRadius: 2,
                endRadius: 42
            )
        )
        g.stroke(snow, with: .color(StorybookArt.outline(for: 0xB8D4E8)), lineWidth: 2.8)

        var drizzle = Path()
        drizzle.move(to: CGPoint(x: -18, y: -10))
        drizzle.addQuadCurve(to: CGPoint(x: -6, y: -14), control: CGPoint(x: -12, y: -2))
        drizzle.addQuadCurve(to: CGPoint(x: 6, y: -12), control: CGPoint(x: 0, y: -22))
        drizzle.addQuadCurve(to: CGPoint(x: 18, y: -8), control: CGPoint(x: 12, y: -2))
        g.stroke(drizzle, with: .color(StorybookArt.color(0xFFF3CE)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        let bean = Path(ellipseIn: CGRect(x: -12, y: -35, width: 24, height: 15))
        StorybookArt.fillAndStroke(g, bean, fill: StorybookArt.color(0x7A3242), stroke: StorybookArt.outline(for: 0x561E2B), width: 2.2)
        StorybookArt.highlight(g, in: CGRect(x: -6, y: -32, width: 6, height: 3.5), opacity: 0.45)

        let mango = Path(roundedRect: CGRect(x: -24, y: -14, width: 12, height: 11), cornerRadius: 3)
        StorybookArt.fillAndStroke(g, mango, fill: StorybookArt.color(0xFFB838), stroke: StorybookArt.outline(for: 0xD88318), width: 1.8)
        let berry = Path(ellipseIn: CGRect(x: 11, y: -15, width: 13, height: 12))
        StorybookArt.fillAndStroke(g, berry, fill: StorybookArt.color(0xF04564), stroke: StorybookArt.outline(for: 0xB82542), width: 1.8)

        let foot = Path(roundedRect: CGRect(x: -15, y: 29, width: 30, height: 9), cornerRadius: 4.5)
        StorybookArt.fillAndStroke(g, foot, fill: StorybookArt.color(0x88D4C2), stroke: StorybookArt.outline(for: 0x5EA897), width: 2.4)
        var bowl = Path()
        bowl.move(to: CGPoint(x: -35, y: 4))
        bowl.addLine(to: CGPoint(x: 35, y: 4))
        bowl.addCurve(to: CGPoint(x: -35, y: 4), control1: CGPoint(x: 30, y: 36), control2: CGPoint(x: -30, y: 36))
        bowl.closeSubpath()
        StorybookArt.fillAndStroke(g, bowl, fill: StorybookArt.color(0xA6E6D6), stroke: StorybookArt.outline(for: 0x5EA897), width: 2.8)
        let rim = Path(roundedRect: CGRect(x: -37, y: 0, width: 74, height: 8), cornerRadius: 4)
        StorybookArt.fillAndStroke(g, rim, fill: StorybookArt.color(0xC6F2E7), stroke: StorybookArt.outline(for: 0x5EA897), width: 2.2)
        StorybookArt.highlight(g, in: CGRect(x: -24, y: 12, width: 14, height: 5), opacity: 0.5)

        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -22), radius: 7, color: Theme.sky)
        StorybookArt.sparkle(g, at: CGPoint(x: 35, y: -6), radius: 6, color: Theme.lemon)
    }

    private func drawRainbowSundae(_ g: GraphicsContext) {
        // Pastel rainbow scoops tucked into a striped sundae cup
        let scoops: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (-14, -4, 15, 0x9FE3CF),
            (14, -4, 15, 0xFFE38A),
            (0, -17, 16, 0xFF9EC4),
        ]
        for (sx, sy, sr, hex) in scoops {
            let p = Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr * 0.85, width: sr * 2, height: sr * 1.7))
            StorybookArt.fillAndStroke(g, p, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.6)
            StorybookArt.highlight(g, in: CGRect(x: sx - sr * 0.5, y: sy - sr * 0.5, width: sr * 0.5, height: sr * 0.3), opacity: 0.65)
        }

        // Whipped cream rosette + ruby cherry
        let whip = Path(ellipseIn: CGRect(x: -11, y: -33, width: 22, height: 13))
        StorybookArt.fillAndStroke(g, whip, fill: .white, stroke: StorybookArt.outline(for: 0xE6D8E8), width: 2.2)
        let cherry = Path(ellipseIn: CGRect(x: -5.5, y: -42, width: 11, height: 11))
        StorybookArt.fillAndStroke(g, cherry, fill: StorybookArt.color(0xF25474), stroke: StorybookArt.outline(for: 0xD13657), width: 2.1)
        StorybookArt.highlight(g, in: CGRect(x: -3, y: -40, width: 3.5, height: 2.4), opacity: 0.85)

        // Sundae glass cup
        let foot = Path(ellipseIn: CGRect(x: -18, y: 31, width: 36, height: 9))
        StorybookArt.fillAndStroke(g, foot, fill: StorybookArt.color(0xFFD6E6), stroke: StorybookArt.outline(for: 0xF08AB5), width: 2.4)
        let stem = Path(roundedRect: CGRect(x: -5.5, y: 21, width: 11, height: 14), cornerRadius: 4)
        StorybookArt.fillAndStroke(g, stem, fill: StorybookArt.color(0xFFEAF2), stroke: StorybookArt.outline(for: 0xF08AB5), width: 2.2)
        var cup = Path()
        cup.move(to: CGPoint(x: -31, y: 2))
        cup.addLine(to: CGPoint(x: 31, y: 2))
        cup.addCurve(to: CGPoint(x: 0, y: 26), control1: CGPoint(x: 28, y: 22), control2: CGPoint(x: 14, y: 26))
        cup.addCurve(to: CGPoint(x: -31, y: 2), control1: CGPoint(x: -14, y: 26), control2: CGPoint(x: -28, y: 22))
        cup.closeSubpath()
        StorybookArt.fillAndStroke(g, cup, fill: StorybookArt.color(0xFFF7FA), stroke: StorybookArt.outline(for: 0xF08AB5), width: 2.8)
        let stripe = Path(roundedRect: CGRect(x: -26, y: 6, width: 52, height: 6), cornerRadius: 3)
        g.fill(stripe, with: .color(StorybookArt.color(0xC9B6FF)))

        // Rainbow sprinkles
        let dots: [(CGFloat, CGFloat, UInt32)] = [(-16, -8, 0xFF6FA8), (15, -7, 0x6CCBF2), (-6, -20, 0xFFE38A), (7, -18, 0x9FE3CF)]
        for (dx, dy, hex) in dots {
            g.fill(Path(roundedRect: CGRect(x: dx - 3, y: dy - 1.4, width: 6, height: 2.8), cornerRadius: 1.4), with: .color(StorybookArt.color(hex)))
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -18), radius: 6.5, color: Theme.mint)
    }

    private func drawHappyParlor(_ g: GraphicsContext) {
        // Cozy pastel parlor shopfront badge with striped awning and heart
        let body = Path(roundedRect: CGRect(x: -30, y: -10, width: 60, height: 42), cornerRadius: 10)
        StorybookArt.fillAndStroke(g, body, fill: StorybookArt.color(0xFFF8F2), stroke: StorybookArt.outline(for: 0xD8B4C8), width: 2.8)

        let window = Path(roundedRect: CGRect(x: -21, y: 2, width: 42, height: 22), cornerRadius: 7)
        StorybookArt.fillAndStroke(g, window, fill: StorybookArt.color(0xCBEFFF), stroke: StorybookArt.outline(for: 0x8CC8EC), width: 2.2)
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 13), size: 18, color: Theme.pink)

        // Scalloped mint-and-pink striped parlor awning
        let scallops = 5
        let w: CGFloat = 70 / CGFloat(scallops)
        for i in 0..<scallops {
            let x0 = -35 + CGFloat(i) * w
            let hex: UInt32 = i.isMultiple(of: 2) ? 0xFF9EC4 : 0x9FE3CF
            var tab = Path()
            tab.move(to: CGPoint(x: x0, y: -22))
            tab.addLine(to: CGPoint(x: x0 + w, y: -22))
            tab.addLine(to: CGPoint(x: x0 + w, y: -8))
            tab.addQuadCurve(to: CGPoint(x: x0, y: -8), control: CGPoint(x: x0 + w / 2, y: 1))
            tab.closeSubpath()
            StorybookArt.fillAndStroke(g, tab, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.2)
        }

        // Three shining golden stars over the parlor roof
        drawStar(g, at: CGPoint(x: -22, y: -33), radius: 7.5, fill: 0xFFE378, outline: 0xD99622)
        drawStar(g, at: CGPoint(x: 0, y: -39), radius: 9.5, fill: 0xFFE378, outline: 0xD99622)
        drawStar(g, at: CGPoint(x: 22, y: -33), radius: 7.5, fill: 0xFFE378, outline: 0xD99622)
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
