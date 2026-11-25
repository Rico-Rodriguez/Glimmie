import SwiftUI

enum SalonFind: String, CaseIterable {
    case firstCut
    case rainbowStylist
    case bubbleWash
    case updoArtist
    case sparkleCrown
    case salonStar

    static var stickers: [Sticker] {
        allCases.map { find in
            Sticker(id: find.rawValue) { ctx, _ in
                find.drawSticker(ctx)
            }
        }
    }

    @discardableResult
    func unlock() -> Bool {
        StickerBook.shared.find(game: SalonGame.id, id: rawValue)
    }

    /// Drawn centered in a 100x100 square (-50...50).
    func drawSticker(_ g: GraphicsContext) {
        switch self {
        case .firstCut:
            drawFirstCut(g)
        case .rainbowStylist:
            drawRainbowStylist(g)
        case .bubbleWash:
            drawBubbleWash(g)
        case .updoArtist:
            drawUpdoArtist(g)
        case .sparkleCrown:
            drawSparkleCrown(g)
        case .salonStar:
            drawSalonStar(g)
        }
    }

    private func drawFirstCut(_ g: GraphicsContext) {
        // Snipped golden curl floating playfully to the right
        var curl = Path()
        curl.move(to: CGPoint(x: 16, y: -22))
        curl.addCurve(to: CGPoint(x: 34, y: 12), control1: CGPoint(x: 34, y: -14), control2: CGPoint(x: 16, y: 2))
        curl.addCurve(to: CGPoint(x: 20, y: 30), control1: CGPoint(x: 42, y: 22), control2: CGPoint(x: 28, y: 34))
        curl.addCurve(to: CGPoint(x: 12, y: 6), control1: CGPoint(x: 22, y: 20), control2: CGPoint(x: 24, y: 14))
        curl.addCurve(to: CGPoint(x: 16, y: -22), control1: CGPoint(x: 6, y: -4), control2: CGPoint(x: 12, y: -16))
        curl.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            curl,
            fill: StorybookArt.color(0xF6C667),
            stroke: StorybookArt.outline(for: 0xD99A3B),
            width: 2.8
        )

        // Open pink salon scissors angled cleanly
        var sc = g
        sc.translateBy(x: -8, y: 2)
        sc.rotate(by: .degrees(-24))
        let chromeFill = StorybookArt.color(0xE8EEF7)
        let chromeOut = StorybookArt.outline(for: 0xB8C4D8)
        let pinkFill = StorybookArt.color(0xFF88B8)
        let pinkOut = StorybookArt.outline(for: 0xE6649B)

        for side in [-1.0, 1.0] {
            var bladeCtx = sc
            bladeCtx.rotate(by: .radians(side * 0.28))
            var blade = Path()
            blade.move(to: CGPoint(x: 0, y: 2))
            blade.addQuadCurve(to: CGPoint(x: CGFloat(side) * 3, y: -36), control: CGPoint(x: CGFloat(side) * 9, y: -18))
            blade.addQuadCurve(to: CGPoint(x: CGFloat(-side) * 4, y: 2), control: CGPoint(x: CGFloat(-side) * 3, y: -14))
            blade.closeSubpath()
            StorybookArt.fillAndStroke(bladeCtx, blade, fill: chromeFill, stroke: chromeOut, width: 2.4)

            var stem = Path()
            stem.move(to: CGPoint(x: 0, y: 2))
            stem.addLine(to: CGPoint(x: CGFloat(-side) * 9, y: 14))
            bladeCtx.stroke(stem, with: .color(pinkOut), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            bladeCtx.stroke(stem, with: .color(pinkFill), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

            let loop = Path(ellipseIn: CGRect(x: CGFloat(-side) * 14 - 10, y: 12, width: 20, height: 22))
            bladeCtx.stroke(loop, with: .color(pinkOut), style: StrokeStyle(lineWidth: 8))
            bladeCtx.stroke(loop, with: .color(pinkFill), style: StrokeStyle(lineWidth: 4.5))
        }
        StorybookArt.fillAndStroke(
            sc,
            Path(ellipseIn: CGRect(x: -4.5, y: -2.5, width: 9, height: 9)),
            fill: Theme.lemon,
            stroke: StorybookArt.outline(for: 0xE6A93B),
            width: 2
        )

        StorybookArt.sparkle(g, at: CGPoint(x: -28, y: -28), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -24), radius: 6.5, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 2, y: -36), radius: 5, color: Theme.sky)
    }

    private func drawRainbowStylist(_ g: GraphicsContext) {
        // Pastel rainbow wave arch behind the brush
        let bands: [UInt32] = [0xFF7FA8, 0xFFB86B, 0xFFE678, 0x7FE0B0, 0x7FC8FF, 0xC49EFF]
        for (i, hex) in bands.enumerated() {
            let r: CGFloat = 35 - CGFloat(i) * 4.2
            var arc = Path()
            arc.addArc(center: CGPoint(x: -2, y: 18), radius: r, startAngle: .degrees(195), endAngle: .degrees(345), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        }

        // Dye brush with rainbow bristles
        let handle = Path { p in
            p.move(to: CGPoint(x: 4, y: 4))
            p.addLine(to: CGPoint(x: 28, y: 34))
        }
        g.stroke(handle, with: .color(StorybookArt.outline(for: 0xF0BA7A)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        g.stroke(handle, with: .color(StorybookArt.color(0xFFD59E)), style: StrokeStyle(lineWidth: 8, lineCap: .round))

        let ferrule = Path(roundedRect: CGRect(x: -10, y: -6, width: 20, height: 13), cornerRadius: 4)
            .applying(CGAffineTransform(rotationAngle: -0.65).concatenating(CGAffineTransform(translationX: 0, y: 0)))
        StorybookArt.fillAndStroke(
            g,
            ferrule,
            fill: StorybookArt.color(0xE6ECF5),
            stroke: StorybookArt.outline(for: 0xB8C4D8),
            width: 2.5
        )

        var tip = Path()
        tip.move(to: CGPoint(x: -17, y: -6))
        tip.addQuadCurve(to: CGPoint(x: -12, y: -30), control: CGPoint(x: -22, y: -22))
        tip.addQuadCurve(to: CGPoint(x: 3, y: -12), control: CGPoint(x: 2, y: -28))
        tip.closeSubpath()
        var clipped = g
        clipped.clip(to: tip)
        clipped.fill(
            tip,
            with: .linearGradient(
                Gradient(colors: bands.map { StorybookArt.color($0) }),
                startPoint: CGPoint(x: -22, y: -28),
                endPoint: CGPoint(x: 4, y: -6)
            )
        )
        g.stroke(tip, with: .color(StorybookArt.outline(for: 0xFF7FA8)), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))

        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -14), radius: 6, color: Theme.pink)
        StorybookArt.heart(g, at: CGPoint(x: -24, y: 26), size: 12, color: Theme.pink)
    }

    private func drawBubbleWash(_ g: GraphicsContext) {
        // Fluffy soap bubble halo behind bottle
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-24, 10, 14), (24, 12, 13), (-22, -14, 11), (25, -12, 12), (14, -29, 8),
        ]
        for (px, py, pr) in puffs {
            let b = Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
            StorybookArt.fillAndStroke(
                g,
                b,
                fill: StorybookArt.color(0xE8F6FF),
                stroke: StorybookArt.outline(for: 0x9CD0F8),
                width: 2.6
            )
            StorybookArt.highlight(g, in: CGRect(x: px - pr * 0.55, y: py - pr * 0.6, width: pr * 0.55, height: pr * 0.35), opacity: 0.9)
        }

        // Cute pink pump shampoo bottle
        let neck = Path(roundedRect: CGRect(x: -7, y: -22, width: 14, height: 12), cornerRadius: 3)
        StorybookArt.fillAndStroke(g, neck, fill: .white, stroke: StorybookArt.outline(for: 0xD4C2D8), width: 2.4)

        var pump = Path()
        pump.addRoundedRect(in: CGRect(x: -11, y: -33, width: 22, height: 11), cornerSize: CGSize(width: 5, height: 5))
        pump.addRoundedRect(in: CGRect(x: -24, y: -30, width: 15, height: 7), cornerSize: CGSize(width: 3.5, height: 3.5))
        StorybookArt.fillAndStroke(g, pump, fill: Theme.sky, stroke: StorybookArt.outline(for: 0x6BB2EB), width: 2.4)

        let body = Path(roundedRect: CGRect(x: -19, y: -12, width: 38, height: 46), cornerRadius: 14, style: .continuous)
        StorybookArt.fillAndStroke(
            g,
            body,
            fill: StorybookArt.color(0xFF9AC2),
            stroke: StorybookArt.outline(for: 0xEB72A4),
            width: 3
        )
        StorybookArt.fillAndStroke(
            g,
            Path(ellipseIn: CGRect(x: -12, y: 1, width: 24, height: 22)),
            fill: .white,
            stroke: StorybookArt.outline(for: 0xF0A8C4),
            width: 2
        )
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 12), size: 12, color: Theme.pink)
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -6, width: 5, height: 18), opacity: 0.65)
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -28), radius: 6.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -26), radius: 6, color: Theme.lemon)
    }

    private func drawUpdoArtist(_ g: GraphicsContext) {
        // Golden-caramel glossy salon bun
        let bun = Path(ellipseIn: CGRect(x: -26, y: -32, width: 52, height: 48))
        StorybookArt.fillAndStroke(
            g,
            bun,
            fill: StorybookArt.color(0xD98B4C),
            stroke: StorybookArt.outline(for: 0x9C5828),
            width: 3.4
        )
        var swirl = g
        swirl.opacity = 0.4
        for k in 0..<2 {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: -8), radius: CGFloat(10 + k * 8), startAngle: .radians(0.4 + Double(k)),
                       endAngle: .radians(3.8 + Double(k)), clockwise: false)
            swirl.stroke(arc, with: .color(StorybookArt.outline(for: 0x8C4B1E)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        StorybookArt.highlight(g, in: CGRect(x: -15, y: -25, width: 16, height: 9), opacity: 0.55)

        // Ruffled lilac scrunchie wrapping the base of the bun
        let puffs = 7
        for i in 0..<puffs {
            let x = -24 + CGFloat(i) * 8
            let y: CGFloat = 12 + (i % 2 == 0 ? -2 : 2)
            let p = Path(ellipseIn: CGRect(x: x - 8, y: y - 7, width: 16, height: 14))
            StorybookArt.fillAndStroke(
                g,
                p,
                fill: i % 2 == 0 ? Theme.lilac : StorybookArt.color(0xB398F5),
                stroke: StorybookArt.outline(for: 0x8F72D6),
                width: 2.4
            )
        }

        // Pink ribbon bow on the scrunchie
        for side in [-1.0, 1.0] {
            var loop = Path()
            let s = CGFloat(side)
            loop.move(to: CGPoint(x: 0, y: 18))
            loop.addCurve(to: CGPoint(x: s * 22, y: 12), control1: CGPoint(x: s * 8, y: 8), control2: CGPoint(x: s * 20, y: 6))
            loop.addCurve(to: CGPoint(x: s * 18, y: 28), control1: CGPoint(x: s * 26, y: 18), control2: CGPoint(x: s * 24, y: 28))
            loop.addCurve(to: CGPoint(x: 0, y: 18), control1: CGPoint(x: s * 10, y: 28), control2: CGPoint(x: s * 6, y: 22))
            loop.closeSubpath()
            StorybookArt.fillAndStroke(g, loop, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xE6649B), width: 2.4)
        }
        StorybookArt.fillAndStroke(
            g,
            Path(ellipseIn: CGRect(x: -6, y: 13, width: 12, height: 11)),
            fill: StorybookArt.color(0xFF74A8),
            stroke: StorybookArt.outline(for: 0xD95287),
            width: 2.2
        )

        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -16), radius: 6.5, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -40), radius: 5.5, color: Theme.sky)
    }

    private func drawSparkleCrown(_ g: GraphicsContext) {
        // Golden princess crown
        var crown = Path()
        crown.move(to: CGPoint(x: -30, y: 22))
        crown.addLine(to: CGPoint(x: -34, y: -14))
        crown.addLine(to: CGPoint(x: -15, y: 2))
        crown.addLine(to: CGPoint(x: 0, y: -26))
        crown.addLine(to: CGPoint(x: 15, y: 2))
        crown.addLine(to: CGPoint(x: 34, y: -14))
        crown.addLine(to: CGPoint(x: 30, y: 22))
        crown.closeSubpath()
        g.fill(
            crown,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFF099), StorybookArt.color(0xFFD252)]),
                startPoint: CGPoint(x: 0, y: -26),
                endPoint: CGPoint(x: 0, y: 22)
            )
        )
        g.stroke(crown, with: .color(StorybookArt.outline(for: 0xD99A2E)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))

        let band = Path(roundedRect: CGRect(x: -32, y: 14, width: 64, height: 14), cornerRadius: 7)
        StorybookArt.fillAndStroke(
            g,
            band,
            fill: StorybookArt.color(0xFFC947),
            stroke: StorybookArt.outline(for: 0xD99A2E),
            width: 3
        )

        // Pearl tips on each point
        for (px, py) in [(-34.0, -16.0), (0.0, -29.0), (34.0, -16.0)] {
            let pearl = Path(ellipseIn: CGRect(x: px - 5.5, y: py - 5.5, width: 11, height: 11))
            StorybookArt.fillAndStroke(g, pearl, fill: .white, stroke: StorybookArt.outline(for: 0xD99A2E), width: 2.2)
        }

        // Center pink heart gem + side pastel jewels
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 7), size: 16, color: Theme.pink)
        for (jx, hex) in [(-18.0, UInt32(0x7FC8FF)), (18.0, UInt32(0x88E5B8))] {
            let gem = Path(ellipseIn: CGRect(x: jx - 4.5, y: 16.5, width: 9, height: 9))
            StorybookArt.fillAndStroke(g, gem, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2)
        }

        StorybookArt.sparkle(g, at: CGPoint(x: -24, y: -32), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 26, y: -30), radius: 6.5, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -42), radius: 5.5, color: .white)
    }

    private func drawSalonStar(_ g: GraphicsContext) {
        // Tilted Polaroid salon snapshot card
        var card = g
        card.rotate(by: .degrees(-6))
        let frame = Path(roundedRect: CGRect(x: -30, y: -32, width: 60, height: 68), cornerRadius: 11, style: .continuous)
        StorybookArt.fillAndStroke(
            card,
            frame,
            fill: .white,
            stroke: StorybookArt.outline(for: 0xE6B8D6),
            width: 3.2
        )
        let inner = Path(roundedRect: CGRect(x: -23, y: -25, width: 46, height: 42), cornerRadius: 7, style: .continuous)
        card.fill(
            inner,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFE6F3), StorybookArt.color(0xE6DDFF)]),
                startPoint: CGPoint(x: 0, y: -25),
                endPoint: CGPoint(x: 0, y: 17)
            )
        )
        card.stroke(inner, with: .color(StorybookArt.outline(for: 0xDFBFE8)), lineWidth: 2)

        // Radiant golden star inside the snapshot
        var star = Path()
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let rr: CGFloat = k.isMultiple(of: 2) ? 16 : 7.5
            let pt = CGPoint(x: cos(a) * rr, y: -4 + sin(a) * rr)
            if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        StorybookArt.fillAndStroke(
            card,
            star,
            fill: StorybookArt.color(0xFFE172),
            stroke: StorybookArt.outline(for: 0xE09F2E),
            width: 2.5
        )
        StorybookArt.heart(card, at: CGPoint(x: 0, y: 26), size: 11, color: Theme.pink)

        // Cute pink mini-camera badge in bottom-right corner
        let cam = Path(roundedRect: CGRect(x: 8, y: 8, width: 28, height: 22), cornerRadius: 6, style: .continuous)
        StorybookArt.fillAndStroke(g, cam, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xD9588E), width: 2.4)
        StorybookArt.fillAndStroke(
            g,
            Path(ellipseIn: CGRect(x: 16, y: 13, width: 12, height: 12)),
            fill: StorybookArt.color(0xD8F0FF),
            stroke: .white,
            width: 2.2
        )

        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -22), radius: 7, color: Theme.pink)
    }
}
