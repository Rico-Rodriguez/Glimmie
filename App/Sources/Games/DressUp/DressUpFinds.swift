import SwiftUI

enum DressUpFind: String, CaseIterable {
    case runwayStar
    case outfitSet
    case petBestie
    case nailArtist
    case glamMakeup
    case colorAlchemist
    case storyDirector
    case photoQueen

    static var stickers: [Sticker] {
        allCases.map { find in
            Sticker(id: find.rawValue) { ctx, _ in
                find.drawSticker(ctx)
            }
        }
    }

    @discardableResult
    func unlock() -> Bool {
        StickerBook.shared.find(game: LookStore.game, id: rawValue)
    }

    /// Drawn centered in a 100x100 square (-50...50).
    func drawSticker(_ g: GraphicsContext) {
        switch self {
        case .runwayStar:
            drawRunwayStar(g)
        case .outfitSet:
            drawOutfitSet(g)
        case .petBestie:
            drawPetBestie(g)
        case .nailArtist:
            drawNailArtist(g)
        case .glamMakeup:
            drawGlamMakeup(g)
        case .colorAlchemist:
            drawColorAlchemist(g)
        case .storyDirector:
            drawStoryDirector(g)
        case .photoQueen:
            drawPhotoQueen(g)
        }
    }

    private func drawRunwayStar(_ g: GraphicsContext) {
        var ribbon = Path()
        ribbon.move(to: CGPoint(x: -36, y: 20))
        ribbon.addQuadCurve(to: CGPoint(x: 36, y: 20), control: CGPoint(x: 0, y: 12))
        ribbon.addLine(to: CGPoint(x: 30, y: 34))
        ribbon.addQuadCurve(to: CGPoint(x: -30, y: 34), control: CGPoint(x: 0, y: 26))
        ribbon.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            ribbon,
            fill: StorybookArt.color(0xFF8FB8),
            stroke: StorybookArt.outline(for: 0xF45C9A),
            width: 3
        )

        var crown = Path()
        crown.move(to: CGPoint(x: -30, y: 16))
        crown.addLine(to: CGPoint(x: -34, y: -14))
        crown.addLine(to: CGPoint(x: -14, y: -2))
        crown.addLine(to: CGPoint(x: 0, y: -28))
        crown.addLine(to: CGPoint(x: 14, y: -2))
        crown.addLine(to: CGPoint(x: 34, y: -14))
        crown.addLine(to: CGPoint(x: 30, y: 16))
        crown.addQuadCurve(to: CGPoint(x: -30, y: 16), control: CGPoint(x: 0, y: 22))
        crown.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            crown,
            fill: StorybookArt.color(0xFFE066),
            stroke: StorybookArt.outline(for: 0xE6A93B),
            width: 3.2
        )
        StorybookArt.highlight(g, in: CGRect(x: -22, y: 6, width: 20, height: 6), opacity: 0.65)

        for (px, py) in [(-34.0, -16.0), (0.0, -30.0), (34.0, -16.0)] as [(CGFloat, CGFloat)] {
            let orb = Path(ellipseIn: CGRect(x: px - 5.5, y: py - 5.5, width: 11, height: 11))
            StorybookArt.fillAndStroke(
                g,
                orb,
                fill: StorybookArt.color(0xFFF4B8),
                stroke: StorybookArt.outline(for: 0xE6A93B),
                width: 2.2
            )
        }
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 5), size: 15, color: StorybookArt.color(0xF45C9A))
        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -32), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 35, y: -28), radius: 6.5, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: 26), radius: 5.5, color: Theme.sky)
    }

    private func drawOutfitSet(_ g: GraphicsContext) {
        var hook = Path()
        hook.move(to: CGPoint(x: 0, y: -25))
        hook.addCurve(to: CGPoint(x: 0, y: -38), control1: CGPoint(x: 0, y: -33), control2: CGPoint(x: 10, y: -38))
        hook.addQuadCurve(to: CGPoint(x: -7, y: -33), control: CGPoint(x: -6, y: -39))
        g.stroke(hook, with: .color(StorybookArt.outline(for: 0xE6A93B)), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))

        var hanger = Path()
        hanger.move(to: CGPoint(x: -22, y: -18))
        hanger.addQuadCurve(to: CGPoint(x: 0, y: -26), control: CGPoint(x: -10, y: -25))
        hanger.addQuadCurve(to: CGPoint(x: 22, y: -18), control: CGPoint(x: 10, y: -25))
        g.stroke(hanger, with: .color(StorybookArt.color(0xF5C257)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        var bodice = Path()
        bodice.move(to: CGPoint(x: -16, y: -18))
        bodice.addQuadCurve(to: CGPoint(x: 0, y: -12), control: CGPoint(x: -8, y: -19))
        bodice.addQuadCurve(to: CGPoint(x: 16, y: -18), control: CGPoint(x: 8, y: -19))
        bodice.addLine(to: CGPoint(x: 12, y: 0))
        bodice.addLine(to: CGPoint(x: -12, y: 0))
        bodice.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            bodice,
            fill: StorybookArt.color(0xFF9EC4),
            stroke: StorybookArt.outline(for: 0xF06E9C),
            width: 3
        )

        var skirt = Path()
        skirt.move(to: CGPoint(x: -13, y: -1))
        skirt.addCurve(to: CGPoint(x: -34, y: 31), control1: CGPoint(x: -24, y: 10), control2: CGPoint(x: -33, y: 20))
        skirt.addQuadCurve(to: CGPoint(x: -12, y: 34), control: CGPoint(x: -23, y: 39))
        skirt.addQuadCurve(to: CGPoint(x: 12, y: 34), control: CGPoint(x: 0, y: 40))
        skirt.addQuadCurve(to: CGPoint(x: 34, y: 31), control: CGPoint(x: 23, y: 39))
        skirt.addCurve(to: CGPoint(x: 13, y: -1), control1: CGPoint(x: 33, y: 20), control2: CGPoint(x: 24, y: 10))
        skirt.closeSubpath()
        g.fill(
            skirt,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFB7D5), StorybookArt.color(0xC9B6FF)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: 36)
            )
        )
        g.stroke(skirt, with: .color(StorybookArt.outline(for: 0xE67BA8)), style: StrokeStyle(lineWidth: 3.2, lineJoin: .round))
        StorybookArt.highlight(g, in: CGRect(x: -16, y: 7, width: 10, height: 18), opacity: 0.45)

        let sash = Path(roundedRect: CGRect(x: -14, y: -4, width: 28, height: 8), cornerRadius: 4)
        StorybookArt.fillAndStroke(g, sash, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 2.2)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: 18), radius: 8, color: .white)
        StorybookArt.sparkle(g, at: CGPoint(x: -30, y: -8), radius: 6.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 32, y: -6), radius: 6, color: Theme.sky)
    }

    private func drawPetBestie(_ g: GraphicsContext) {
        let pad = Path { p in
            p.move(to: CGPoint(x: 0, y: 32))
            p.addCurve(to: CGPoint(x: -25, y: 12), control1: CGPoint(x: -18, y: 34), control2: CGPoint(x: -29, y: 22))
            p.addCurve(to: CGPoint(x: 0, y: -4), control1: CGPoint(x: -22, y: -2), control2: CGPoint(x: -10, y: -4))
            p.addCurve(to: CGPoint(x: 25, y: 12), control1: CGPoint(x: 10, y: -4), control2: CGPoint(x: 22, y: -2))
            p.addCurve(to: CGPoint(x: 0, y: 32), control1: CGPoint(x: 29, y: 22), control2: CGPoint(x: 18, y: 34))
            p.closeSubpath()
        }
        StorybookArt.fillAndStroke(
            g,
            pad,
            fill: StorybookArt.color(0xFFA6C8),
            stroke: StorybookArt.outline(for: 0xF06E9C),
            width: 3.4
        )
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 14), size: 18, color: .white, opacity: 0.9)

        let toes: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
            (-26, -6, 15, 19, -24),
            (-10, -21, 16, 20, -8),
            (10, -21, 16, 20, 8),
            (26, -6, 15, 19, 24),
        ]
        for (tx, ty, tw, th, ang) in toes {
            var tg = g
            tg.translateBy(x: tx, y: ty)
            tg.rotate(by: .degrees(ang))
            let toe = Path(ellipseIn: CGRect(x: -tw / 2, y: -th / 2, width: tw, height: th))
            StorybookArt.fillAndStroke(
                tg,
                toe,
                fill: StorybookArt.color(0xFFBBD6),
                stroke: StorybookArt.outline(for: 0xF06E9C),
                width: 3
            )
            StorybookArt.highlight(tg, in: CGRect(x: -tw * 0.28, y: -th * 0.34, width: tw * 0.42, height: th * 0.28), opacity: 0.7)
        }

        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -36), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -35, y: 22), radius: 6, color: Theme.sky)
        StorybookArt.sparkle(g, at: CGPoint(x: 35, y: 20), radius: 6, color: Theme.lemon)
    }

    private func drawNailArtist(_ g: GraphicsContext) {
        let cap = Path(roundedRect: CGRect(x: -18, y: -37, width: 22, height: 28), cornerRadius: 7)
        StorybookArt.fillAndStroke(
            g,
            cap,
            fill: StorybookArt.color(0x6C4D80),
            stroke: StorybookArt.outline(for: 0x5B3A68),
            width: 3
        )
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -33, width: 5, height: 18), opacity: 0.42)

        var bottle = Path()
        bottle.move(to: CGPoint(x: -24, y: -8))
        bottle.addQuadCurve(to: CGPoint(x: -7, y: -11), control: CGPoint(x: -18, y: -11))
        bottle.addQuadCurve(to: CGPoint(x: 10, y: -8), control: CGPoint(x: 4, y: -11))
        bottle.addCurve(to: CGPoint(x: 15, y: 31), control1: CGPoint(x: 16, y: 2), control2: CGPoint(x: 17, y: 20))
        bottle.addQuadCurve(to: CGPoint(x: -7, y: 35), control: CGPoint(x: 6, y: 35))
        bottle.addQuadCurve(to: CGPoint(x: -29, y: 31), control: CGPoint(x: -20, y: 35))
        bottle.addCurve(to: CGPoint(x: -24, y: -8), control1: CGPoint(x: -31, y: 20), control2: CGPoint(x: -30, y: 2))
        bottle.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            bottle,
            fill: StorybookArt.color(0xFF7CB2),
            stroke: StorybookArt.outline(for: 0xE64B8B),
            width: 3.2
        )
        StorybookArt.highlight(g, in: CGRect(x: -22, y: 0, width: 8, height: 22), opacity: 0.65)
        StorybookArt.heart(g, at: CGPoint(x: -7, y: 14), size: 14, color: .white, opacity: 0.9)

        let nail = Path(roundedRect: CGRect(x: 14, y: -10, width: 23, height: 34), cornerRadius: 11)
        StorybookArt.fillAndStroke(
            g,
            nail,
            fill: StorybookArt.color(0x9FD8FF),
            stroke: StorybookArt.outline(for: 0x5C9BEB),
            width: 3
        )
        StorybookArt.highlight(g, in: CGRect(x: 19, y: -4, width: 5, height: 18), opacity: 0.72)
        StorybookArt.sparkle(g, at: CGPoint(x: 26, y: 12), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 26, y: -24), radius: 7, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -20), radius: 6, color: Theme.lemon)
    }

    private func drawGlamMakeup(_ g: GraphicsContext) {
        let compact = Path(ellipseIn: CGRect(x: -34, y: -16, width: 46, height: 46))
        StorybookArt.fillAndStroke(
            g,
            compact,
            fill: StorybookArt.color(0xFFB5D2),
            stroke: StorybookArt.outline(for: 0xE871A1),
            width: 3.2
        )
        let pan = Path(ellipseIn: CGRect(x: -26, y: -8, width: 30, height: 30))
        StorybookArt.fillAndStroke(
            g,
            pan,
            fill: StorybookArt.color(0xFF84A9),
            stroke: StorybookArt.outline(for: 0xD95984),
            width: 2.2
        )
        StorybookArt.highlight(g, in: CGRect(x: -21, y: -3, width: 12, height: 6), opacity: 0.6)

        let tube = Path(roundedRect: CGRect(x: 6, y: 4, width: 24, height: 30), cornerRadius: 6)
        StorybookArt.fillAndStroke(
            g,
            tube,
            fill: StorybookArt.color(0xFFE07A),
            stroke: StorybookArt.outline(for: 0xD9A441),
            width: 3
        )
        let collar = Path(roundedRect: CGRect(x: 9, y: -4, width: 18, height: 11), cornerRadius: 3)
        StorybookArt.fillAndStroke(
            g,
            collar,
            fill: StorybookArt.color(0xFFF0B5),
            stroke: StorybookArt.outline(for: 0xD9A441),
            width: 2.4
        )

        var bullet = Path()
        bullet.move(to: CGPoint(x: 11, y: -4))
        bullet.addLine(to: CGPoint(x: 11, y: -22))
        bullet.addQuadCurve(to: CGPoint(x: 25, y: -31), control: CGPoint(x: 14, y: -32))
        bullet.addLine(to: CGPoint(x: 25, y: -4))
        bullet.closeSubpath()
        StorybookArt.fillAndStroke(
            g,
            bullet,
            fill: StorybookArt.color(0xF44C7A),
            stroke: StorybookArt.outline(for: 0xC92D5A),
            width: 2.8
        )
        StorybookArt.highlight(g, in: CGRect(x: 14, y: -21, width: 4, height: 14), opacity: 0.6)

        StorybookArt.sparkle(g, at: CGPoint(x: -10, y: -28), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -24), radius: 6, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: 28), radius: 5.5, color: Theme.sky)
    }

    private func drawColorAlchemist(_ g: GraphicsContext) {
        var spoonHandle = Path()
        spoonHandle.move(to: CGPoint(x: 4, y: -4))
        spoonHandle.addQuadCurve(to: CGPoint(x: 28, y: -36), control: CGPoint(x: 18, y: -24))
        g.stroke(spoonHandle, with: .color(StorybookArt.outline(for: 0xC98A55)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        g.stroke(spoonHandle, with: .color(StorybookArt.color(0xDCA06C)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))

        let bowl = Path { p in
            p.move(to: CGPoint(x: -34, y: -2))
            p.addCurve(to: CGPoint(x: -22, y: 31), control1: CGPoint(x: -34, y: 18), control2: CGPoint(x: -29, y: 28))
            p.addQuadCurve(to: CGPoint(x: 22, y: 31), control: CGPoint(x: 0, y: 36))
            p.addCurve(to: CGPoint(x: 34, y: -2), control1: CGPoint(x: 29, y: 28), control2: CGPoint(x: 34, y: 18))
            p.closeSubpath()
        }
        StorybookArt.fillAndStroke(
            g,
            bowl,
            fill: StorybookArt.color(0xFFF6FA),
            stroke: StorybookArt.outline(for: 0xE5A6C4),
            width: 3.4
        )
        StorybookArt.highlight(g, in: CGRect(x: -25, y: 10, width: 12, height: 14), opacity: 0.7)

        let rim = Path(ellipseIn: CGRect(x: -34, y: -15, width: 68, height: 24))
        let rainbow = Gradient(colors: [
            StorybookArt.color(0xFF7FB3),
            StorybookArt.color(0xFFE38A),
            StorybookArt.color(0x88E5B8),
            StorybookArt.color(0x7EC8FF),
            StorybookArt.color(0xC9A6FF),
            StorybookArt.color(0xFF7FB3),
        ])
        g.fill(rim, with: .conicGradient(rainbow, center: CGPoint(x: 0, y: -3)))
        g.stroke(rim, with: .color(StorybookArt.outline(for: 0xE5A6C4)), lineWidth: 3.2)

        let drops: [(CGFloat, CGFloat, UInt32)] = [(-26, -28, 0xFF7FB3), (-4, -33, 0x7EC8FF), (18, -24, 0xFFE38A)]
        for (dx, dy, hex) in drops {
            let drop = Path(ellipseIn: CGRect(x: dx - 6, y: dy - 6, width: 12, height: 12))
            StorybookArt.fillAndStroke(g, drop, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: dx - 3.5, y: dy - 4, width: 4, height: 3), opacity: 0.8)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -16), radius: 6, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: 18), radius: 6, color: Theme.pink)
    }

    private func drawStoryDirector(_ g: GraphicsContext) {
        let stage = Path(roundedRect: CGRect(x: -36, y: -28, width: 72, height: 58), cornerRadius: 14)
        StorybookArt.fillAndStroke(
            g,
            stage,
            fill: StorybookArt.color(0xFFF4D6),
            stroke: StorybookArt.outline(for: 0xE6A93B),
            width: 3.4
        )

        var clipped = g
        clipped.clip(to: stage)
        for side in [-1.0, 1.0] as [CGFloat] {
            var curtain = Path()
            curtain.move(to: CGPoint(x: side * 36, y: -28))
            curtain.addLine(to: CGPoint(x: side * 8, y: -28))
            curtain.addCurve(to: CGPoint(x: side * 24, y: 30), control1: CGPoint(x: side * 12, y: -4), control2: CGPoint(x: side * 28, y: 8))
            curtain.addLine(to: CGPoint(x: side * 36, y: 30))
            curtain.closeSubpath()
            StorybookArt.fillAndStroke(
                clipped,
                curtain,
                fill: StorybookArt.color(0xFF7BA8),
                stroke: StorybookArt.outline(for: 0xE04E82),
                width: 2.6
            )
        }

        let mask = Path(ellipseIn: CGRect(x: -18, y: -12, width: 36, height: 34))
        StorybookArt.fillAndStroke(
            g,
            mask,
            fill: StorybookArt.color(0xFFFDF8),
            stroke: StorybookArt.outline(for: 0xC9B6FF),
            width: 3
        )
        for sx in [-7.0, 7.0] as [CGFloat] {
            var eye = Path()
            eye.move(to: CGPoint(x: sx - 4, y: 1))
            eye.addQuadCurve(to: CGPoint(x: sx + 4, y: 1), control: CGPoint(x: sx, y: -4))
            g.stroke(eye, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -7, y: 9))
        smile.addQuadCurve(to: CGPoint(x: 7, y: 9), control: CGPoint(x: 0, y: 17))
        g.stroke(smile, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -35), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -36, y: 26), radius: 6, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 36, y: -24), radius: 6, color: Theme.sky)
    }

    private func drawPhotoQueen(_ g: GraphicsContext) {
        let topBump = Path(roundedRect: CGRect(x: -22, y: -28, width: 22, height: 14), cornerRadius: 6)
        StorybookArt.fillAndStroke(
            g,
            topBump,
            fill: StorybookArt.color(0xFFD2E5),
            stroke: StorybookArt.outline(for: 0xE871A1),
            width: 3
        )
        let shutter = Path(roundedRect: CGRect(x: 14, y: -26, width: 14, height: 10), cornerRadius: 5)
        StorybookArt.fillAndStroke(
            g,
            shutter,
            fill: Theme.lemon,
            stroke: StorybookArt.outline(for: 0xE6A93B),
            width: 2.4
        )

        let body = Path(roundedRect: CGRect(x: -36, y: -18, width: 72, height: 50), cornerRadius: 16)
        StorybookArt.fillAndStroke(
            g,
            body,
            fill: StorybookArt.color(0xFFA6CB),
            stroke: StorybookArt.outline(for: 0xE86399),
            width: 3.4
        )
        StorybookArt.highlight(g, in: CGRect(x: -28, y: -13, width: 24, height: 7), opacity: 0.65)

        let stripe = Path(CGRect(x: -34, y: 18, width: 68, height: 8))
        var clipped = g
        clipped.clip(to: body)
        clipped.fill(stripe, with: .color(StorybookArt.color(0xFFF3F8, alpha: 0.85)))

        let outerLens = Path(ellipseIn: CGRect(x: -18, y: -10, width: 36, height: 36))
        StorybookArt.fillAndStroke(
            g,
            outerLens,
            fill: .white,
            stroke: StorybookArt.outline(for: 0xC9B6FF),
            width: 3.2
        )
        let innerLens = Path(ellipseIn: CGRect(x: -12, y: -4, width: 24, height: 24))
        StorybookArt.fillAndStroke(
            g,
            innerLens,
            fill: StorybookArt.color(0x9CCBFF),
            stroke: StorybookArt.outline(for: 0x5C9BEB),
            width: 2.2
        )
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 8), size: 12, color: Theme.pink)
        StorybookArt.highlight(g, in: CGRect(x: -8, y: -1, width: 6, height: 4), opacity: 0.85)

        StorybookArt.sparkle(g, at: CGPoint(x: 24, y: -9), radius: 6, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -32), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: 26), radius: 6, color: Theme.pink)
    }
}
