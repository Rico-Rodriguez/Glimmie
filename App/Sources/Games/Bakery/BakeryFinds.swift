import SwiftUI

enum BakeryFind: String, CaseIterable {
    case firstTreat
    case threeStarBaker
    case rainbowFrost
    case tallCake
    case iceCreamPro
    case smoothieStar
    case bungeoppang
    case bingsu

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
        case .firstTreat:
            drawFirstTreat(g)
        case .threeStarBaker:
            drawThreeStarBaker(g)
        case .rainbowFrost:
            drawRainbowFrost(g)
        case .tallCake:
            drawTallCake(g)
        case .iceCreamPro:
            drawIceCreamPro(g)
        case .smoothieStar:
            drawSmoothieStar(g)
        case .bungeoppang:
            drawBungeoppang(g)
        case .bingsu:
            drawBingsu(g)
        }
    }

    private func drawFirstTreat(_ g: GraphicsContext) {
        // Fluted cupcake wrapper
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

        // Fluffy strawberry frosting tiers
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

        // Glossy cherry on top
        var stem = Path()
        stem.move(to: CGPoint(x: 1, y: -32))
        stem.addQuadCurve(to: CGPoint(x: 11, y: -42), control: CGPoint(x: 4, y: -40))
        g.stroke(stem, with: .color(StorybookArt.color(0x69B86A)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        let cherry = Path(ellipseIn: CGRect(x: -7, y: -36, width: 15, height: 14))
        StorybookArt.fillAndStroke(g, cherry, fill: StorybookArt.color(0xF25474), stroke: StorybookArt.outline(for: 0xD13657), width: 2.4)
        StorybookArt.highlight(g, in: CGRect(x: -4, y: -33, width: 5, height: 3.5), opacity: 0.85)

        // Sprinkles & sparkles
        let sprinkles: [(CGFloat, CGFloat, UInt32)] = [(-14, 1, 0xFFE38A), (4, -12, 0x9FE3CF), (14, 0, 0x9CCBFF), (-5, -16, 0xFFE38A)]
        for (sx, sy, hex) in sprinkles {
            g.fill(Path(roundedRect: CGRect(x: sx - 3, y: sy - 1.5, width: 6, height: 3), cornerRadius: 1.5), with: .color(StorybookArt.color(hex)))
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 33, y: -14), radius: 6, color: Theme.pink)
    }

    private func drawThreeStarBaker(_ g: GraphicsContext) {
        // Puffy baker's toque crown
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

        // Hat band with golden ribbon
        let band = Path(roundedRect: CGRect(x: -26, y: 6, width: 52, height: 24), cornerRadius: 8)
        StorybookArt.fillAndStroke(g, band, fill: StorybookArt.color(0xFFF9F4), stroke: toqueOutline, width: 3.2)
        let ribbon = Path(roundedRect: CGRect(x: -25, y: 17, width: 50, height: 10), cornerRadius: 4)
        StorybookArt.fillAndStroke(g, ribbon, fill: StorybookArt.color(0xFF9EC4), stroke: StorybookArt.outline(for: 0xE876A4), width: 2.2)

        // Three shining stars arcing overhead
        let stars: [(CGFloat, CGFloat, CGFloat)] = [(-26, -28, 9), (0, -37, 11.5), (26, -28, 9)]
        for (sx, sy, sr) in stars {
            drawStar(g, at: CGPoint(x: sx, y: sy), radius: sr, fill: 0xFFE06B, outline: 0xD99622)
        }
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 22), size: 10, color: .white)
    }

    private func drawRainbowFrost(_ g: GraphicsContext) {
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

    private func drawTallCake(_ g: GraphicsContext) {
        // Cake plate
        let plate = Path(ellipseIn: CGRect(x: -36, y: 28, width: 72, height: 14))
        StorybookArt.fillAndStroke(g, plate, fill: StorybookArt.color(0xFFF9F4), stroke: StorybookArt.outline(for: 0xE6C8D6), width: 2.8)

        // Three pastel tiers
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

        // Golden birthday candle + warm flame
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

    private func drawIceCreamPro(_ g: GraphicsContext) {
        // Golden waffle cone
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

        // Wafer stick tucked behind
        var wafer = Path()
        wafer.move(to: CGPoint(x: 10, y: -10))
        wafer.addLine(to: CGPoint(x: 28, y: -32))
        g.stroke(wafer, with: .color(StorybookArt.outline(for: 0xD9964A)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        g.stroke(wafer, with: .color(StorybookArt.color(0xF5C882)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // Three stacked scoops (mint, strawberry, vanilla)
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

        // Cherry & sparkles
        let cherry = Path(ellipseIn: CGRect(x: -5.5, y: -44, width: 11, height: 11))
        StorybookArt.fillAndStroke(g, cherry, fill: StorybookArt.color(0xF25474), stroke: StorybookArt.outline(for: 0xD13657), width: 2.2)
        StorybookArt.highlight(g, in: CGRect(x: -3, y: -42, width: 3.5, height: 2.5), opacity: 0.85)
        StorybookArt.sparkle(g, at: CGPoint(x: -31, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 31, y: 12), radius: 6, color: Theme.sky)
    }

    private func drawSmoothieStar(_ g: GraphicsContext) {
        // Striped straw
        var straw = Path()
        straw.move(to: CGPoint(x: 5, y: 10))
        straw.addLine(to: CGPoint(x: 20, y: -40))
        g.stroke(straw, with: .color(StorybookArt.outline(for: 0xFF7FA8)), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))
        g.stroke(straw, with: .color(.white), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        g.stroke(straw, with: .color(StorybookArt.color(0xFF7FA8)), style: StrokeStyle(lineWidth: 5.5, lineCap: .butt, dash: [5, 5]))

        // Parfait glass silhouette
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

        // Whipped cream cloud cap
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-13, -15, 10), (13, -15, 10), (0, -21, 13)]
        let creamOutline = StorybookArt.outline(for: 0xE6D8E8)
        for (px, py, pr) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(creamOutline), lineWidth: 5.5)
        }
        for (px, py, pr) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(.white))
        }

        // Golden star badge on glass front
        drawStar(g, at: CGPoint(x: 0, y: 12), radius: 11, fill: 0xFFE378, outline: 0xD99622)
        StorybookArt.sparkle(g, at: CGPoint(x: -31, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -8), radius: 6, color: Theme.pink)
    }

    private func drawBungeoppang(_ g: GraphicsContext) {
        var fish = g
        fish.rotate(by: .degrees(-10))

        // Crispy lacy waffle flange
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

        // Plump golden fish body
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

        // Waffle diamond crosshatch on body
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

        // Sweet red-bean pat peek at mouth + smiling eye + blush
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

    private func drawBingsu(_ g: GraphicsContext) {
        // Pastel bingsu spoon tucked behind snow dome
        var spoon = Path()
        spoon.move(to: CGPoint(x: 10, y: -8))
        spoon.addLine(to: CGPoint(x: 32, y: -36))
        g.stroke(spoon, with: .color(StorybookArt.outline(for: 0xFFA6C8)), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
        g.stroke(spoon, with: .color(StorybookArt.color(0xFFC2DA)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // Fluffy shaved milk-snow dome
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

        // Creamy condensed-milk drizzle ribbon
        var drizzle = Path()
        drizzle.move(to: CGPoint(x: -18, y: -10))
        drizzle.addQuadCurve(to: CGPoint(x: -6, y: -14), control: CGPoint(x: -12, y: -2))
        drizzle.addQuadCurve(to: CGPoint(x: 6, y: -12), control: CGPoint(x: 0, y: -22))
        drizzle.addQuadCurve(to: CGPoint(x: 18, y: -8), control: CGPoint(x: 12, y: -2))
        g.stroke(drizzle, with: .color(StorybookArt.color(0xFFF3CE)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        // Red-bean pat crown + sliced strawberry + mango cube
        let bean = Path(ellipseIn: CGRect(x: -12, y: -35, width: 24, height: 15))
        StorybookArt.fillAndStroke(g, bean, fill: StorybookArt.color(0x7A3242), stroke: StorybookArt.outline(for: 0x561E2B), width: 2.2)
        StorybookArt.highlight(g, in: CGRect(x: -6, y: -32, width: 6, height: 3.5), opacity: 0.45)

        let mango = Path(roundedRect: CGRect(x: -24, y: -14, width: 12, height: 11), cornerRadius: 3)
        StorybookArt.fillAndStroke(g, mango, fill: StorybookArt.color(0xFFB838), stroke: StorybookArt.outline(for: 0xD88318), width: 1.8)
        let berry = Path(ellipseIn: CGRect(x: 11, y: -15, width: 13, height: 12))
        StorybookArt.fillAndStroke(g, berry, fill: StorybookArt.color(0xF04564), stroke: StorybookArt.outline(for: 0xB82542), width: 1.8)

        // Footed pastel celadon bingsu bowl
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
