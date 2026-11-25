import SwiftUI

enum PetVetFind: String, CaseIterable {
    case firstHeal
    case sparkleBath
    case gentleDoctor
    case sweetTooth
    case tummyHero
    case bowStylist
    case clinicStar
    case superVet

    static var stickers: [Sticker] {
        allCases.map { find in
            Sticker(id: find.rawValue) { ctx, _ in
                find.drawSticker(ctx)
            }
        }
    }

    static func visitUnlocks(for visit: VetVisit, totalHealed: Int, uniqueHealed: Int) -> [PetVetFind] {
        var found: [PetVetFind] = [.firstHeal]
        let ailments = Set(visit.ailments)
        if ailments.contains(.mud) { found.append(.sparkleBath) }
        if ailments.contains(.toothache) { found.append(.sweetTooth) }
        if ailments.contains(.tummy) { found.append(.tummyHero) }
        if !ailments.isDisjoint(with: [.cold, .scrape, .sprain, .thorns, .rash, .fleas, .leaves]) {
            found.append(.gentleDoctor)
        }
        if totalHealed >= 3 { found.append(.clinicStar) }
        if totalHealed >= 6 || uniqueHealed >= 5 { found.append(.superVet) }
        return found
    }

    /// Drawn centered in a 100x100 square (-50...50).
    func drawSticker(_ g: GraphicsContext) {
        switch self {
        case .firstHeal:
            drawFirstHeal(g)
        case .sparkleBath:
            drawSparkleBath(g)
        case .gentleDoctor:
            drawGentleDoctor(g)
        case .sweetTooth:
            drawSweetTooth(g)
        case .tummyHero:
            drawTummyHero(g)
        case .bowStylist:
            drawBowStylist(g)
        case .clinicStar:
            drawClinicStar(g)
        case .superVet:
            drawSuperVet(g)
        }
    }

    private func drawFirstHeal(_ g: GraphicsContext) {
        let halo = Path(ellipseIn: CGRect(x: -36, y: -36, width: 72, height: 72))
        StorybookArt.fillAndStroke(
            g,
            halo,
            fill: StorybookArt.color(0xFFF6EC),
            stroke: StorybookArt.outline(for: 0xFFD9E6),
            width: 3.4
        )

        let heart = heartPath(center: CGPoint(x: 0, y: 2), size: 54)
        StorybookArt.fillAndStroke(
            g,
            heart,
            fill: StorybookArt.color(0xFF8FB8),
            stroke: StorybookArt.outline(for: 0xFF7CA8),
            width: 3.2
        )
        StorybookArt.highlight(g, in: CGRect(x: -17, y: -15, width: 13, height: 8), opacity: 0.55)

        let crossV = Path(roundedRect: CGRect(x: -5, y: -11, width: 10, height: 26), cornerRadius: 4)
        let crossH = Path(roundedRect: CGRect(x: -13, y: -3, width: 26, height: 10), cornerRadius: 4)
        g.fill(crossV, with: .color(.white))
        g.fill(crossH, with: .color(.white))

        StorybookArt.sparkle(g, at: CGPoint(x: -33, y: -27), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -22), radius: 7, color: Theme.mint)
        StorybookArt.sparkle(g, at: CGPoint(x: 31, y: 29), radius: 6, color: Theme.lemon)
    }

    private func drawSparkleBath(_ g: GraphicsContext) {
        var sp = g
        sp.rotate(by: .degrees(-12))
        let sponge = Path(roundedRect: CGRect(x: -28, y: -10, width: 56, height: 34), cornerRadius: 12)
        StorybookArt.fillAndStroke(
            sp,
            sponge,
            fill: StorybookArt.color(0xFFE38A),
            stroke: StorybookArt.outline(for: 0xE8B94B),
            width: 3.2
        )
        let scrubLayer = Path(roundedRect: CGRect(x: -26, y: 12, width: 52, height: 10), cornerRadius: 5)
        sp.fill(scrubLayer, with: .color(StorybookArt.color(0x9FE3CF)))
        for (px, py, pr) in [(-14.0, -2.0, 3.2), (2.0, 2.0, 2.8), (15.0, -3.0, 3.5), (-4.0, -5.0, 2.2)] {
            sp.fill(
                Path(ellipseIn: CGRect(x: CGFloat(px - pr), y: CGFloat(py - pr), width: CGFloat(pr * 2), height: CGFloat(pr * 2))),
                with: .color(StorybookArt.color(0xF2C24E, alpha: 0.65))
            )
        }
        StorybookArt.highlight(sp, in: CGRect(x: -20, y: -7, width: 18, height: 5), opacity: 0.65)

        let bubbles: [(CGFloat, CGFloat, CGFloat)] = [(-22, -22, 11), (0, -28, 13), (22, -20, 10), (30, -2, 7.5)]
        for (bx, by, br) in bubbles {
            let b = Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2))
            StorybookArt.fillAndStroke(
                g,
                b,
                fill: StorybookArt.color(0xE2F6FF, alpha: 0.92),
                stroke: StorybookArt.outline(for: 0x8CCBFF),
                width: 2.4
            )
            StorybookArt.highlight(g, in: CGRect(x: bx - br * 0.55, y: by - br * 0.6, width: br * 0.55, height: br * 0.35), opacity: 0.9)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: 16), radius: 7, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -32), radius: 7, color: Theme.lemon)
    }

    private func drawGentleDoctor(_ g: GraphicsContext) {
        var tube = Path()
        tube.move(to: CGPoint(x: -18, y: -28))
        tube.addCurve(to: CGPoint(x: -24, y: 6), control1: CGPoint(x: -36, y: -14), control2: CGPoint(x: -36, y: 2))
        tube.addCurve(to: CGPoint(x: 0, y: 28), control1: CGPoint(x: -14, y: 18), control2: CGPoint(x: -6, y: 28))
        tube.addCurve(to: CGPoint(x: 24, y: 6), control1: CGPoint(x: 6, y: 28), control2: CGPoint(x: 14, y: 18))
        tube.addCurve(to: CGPoint(x: 18, y: -28), control1: CGPoint(x: 36, y: 2), control2: CGPoint(x: 36, y: -14))
        g.stroke(tube, with: .color(StorybookArt.outline(for: 0x72C7B0)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        g.stroke(tube, with: .color(StorybookArt.color(0x9FE3CF)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))

        for side in [-1.0, 1.0] {
            let ex = CGFloat(side) * 16
            let tip = Path(ellipseIn: CGRect(x: ex - 6, y: -35, width: 12, height: 12))
            StorybookArt.fillAndStroke(g, tip, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xFF7CA8), width: 2.5)
        }

        let disc = Path(ellipseIn: CGRect(x: -15, y: 14, width: 30, height: 30))
        StorybookArt.fillAndStroke(
            g,
            disc,
            fill: StorybookArt.color(0xE9F2FA),
            stroke: StorybookArt.outline(for: 0x99B2C7),
            width: 3.2
        )
        let inner = Path(ellipseIn: CGRect(x: -9, y: 20, width: 18, height: 18))
        g.fill(inner, with: .color(StorybookArt.color(0xFF9AC0)))
        StorybookArt.highlight(g, in: CGRect(x: -6, y: 22, width: 7, height: 5), opacity: 0.75)

        StorybookArt.heart(g, at: CGPoint(x: 0, y: -6), size: 20, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -24), radius: 6.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: 22), radius: 7, color: Theme.lemon)
    }

    private func drawSweetTooth(_ g: GraphicsContext) {
        var tooth = Path()
        tooth.move(to: CGPoint(x: 0, y: -22))
        tooth.addCurve(to: CGPoint(x: 24, y: -12), control1: CGPoint(x: 10, y: -30), control2: CGPoint(x: 24, y: -26))
        tooth.addCurve(to: CGPoint(x: 20, y: 18), control1: CGPoint(x: 26, y: 2), control2: CGPoint(x: 24, y: 10))
        tooth.addCurve(to: CGPoint(x: 8, y: 34), control1: CGPoint(x: 18, y: 28), control2: CGPoint(x: 14, y: 36))
        tooth.addCurve(to: CGPoint(x: 0, y: 18), control1: CGPoint(x: 4, y: 32), control2: CGPoint(x: 4, y: 18))
        tooth.addCurve(to: CGPoint(x: -8, y: 34), control1: CGPoint(x: -4, y: 18), control2: CGPoint(x: -4, y: 32))
        tooth.addCurve(to: CGPoint(x: -20, y: 18), control1: CGPoint(x: -14, y: 36), control2: CGPoint(x: -18, y: 28))
        tooth.addCurve(to: CGPoint(x: -24, y: -12), control1: CGPoint(x: -24, y: 10), control2: CGPoint(x: -26, y: 2))
        tooth.addCurve(to: CGPoint(x: 0, y: -22), control1: CGPoint(x: -24, y: -26), control2: CGPoint(x: -10, y: -30))
        tooth.closeSubpath()

        StorybookArt.fillAndStroke(
            g,
            tooth,
            fill: StorybookArt.color(0xFFFFFF),
            stroke: StorybookArt.outline(for: 0xB8D6EC),
            width: 3.4
        )
        StorybookArt.highlight(g, in: CGRect(x: -16, y: -18, width: 12, height: 8), opacity: 0.9)

        // Cute smiling face
        for side in [-1.0, 1.0] {
            let ex = CGFloat(side) * 9
            g.fill(Path(ellipseIn: CGRect(x: ex - 2.6, y: -4, width: 5.2, height: 5.2)), with: .color(Theme.ink))
            g.fill(Path(ellipseIn: CGRect(x: ex - 6, y: 3, width: 8, height: 4.5)), with: .color(Theme.pink.opacity(0.6)))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -6, y: 6))
        smile.addQuadCurve(to: CGPoint(x: 6, y: 6), control: CGPoint(x: 0, y: 12))
        g.stroke(smile, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Tiny mint sparkle swirl & stars
        StorybookArt.sparkle(g, at: CGPoint(x: -28, y: -24), radius: 8.5, color: Theme.mint)
        StorybookArt.sparkle(g, at: CGPoint(x: 29, y: -26), radius: 9, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 30, y: 14), radius: 6, color: Theme.sky)
    }

    private func drawTummyHero(_ g: GraphicsContext) {
        // Berry syrup bottle
        let neck = Path(roundedRect: CGRect(x: -10, y: -26, width: 20, height: 14), cornerRadius: 4)
        StorybookArt.fillAndStroke(
            g,
            neck,
            fill: StorybookArt.color(0xFFE0EE),
            stroke: StorybookArt.outline(for: 0xF08AB6),
            width: 2.8
        )
        let cap = Path(roundedRect: CGRect(x: -13, y: -36, width: 26, height: 13), cornerRadius: 5)
        StorybookArt.fillAndStroke(
            g,
            cap,
            fill: StorybookArt.color(0x9FE3CF),
            stroke: StorybookArt.outline(for: 0x64BFA5),
            width: 2.8
        )
        let bottle = Path(roundedRect: CGRect(x: -23, y: -14, width: 46, height: 50), cornerRadius: 14)
        StorybookArt.fillAndStroke(
            g,
            bottle,
            fill: StorybookArt.color(0xFF8FB8),
            stroke: StorybookArt.outline(for: 0xE66494),
            width: 3.2
        )
        let label = Path(roundedRect: CGRect(x: -16, y: -2, width: 32, height: 24), cornerRadius: 7)
        StorybookArt.fillAndStroke(
            g,
            label,
            fill: StorybookArt.color(0xFFF9F3),
            stroke: StorybookArt.outline(for: 0xF2C2D4),
            width: 2.2
        )
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 10), size: 15, color: Theme.pink)
        StorybookArt.highlight(g, in: CGRect(x: -18, y: -9, width: 6, height: 22), opacity: 0.5)

        // Golden spoon beside bottle
        var sp = g
        sp.translateBy(x: 24, y: 8)
        sp.rotate(by: .degrees(16))
        let stem = Path(roundedRect: CGRect(x: -3, y: -6, width: 6, height: 28), cornerRadius: 3)
        StorybookArt.fillAndStroke(sp, stem, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xDDA63B), width: 2.2)
        let bowl = Path(ellipseIn: CGRect(x: -8, y: -22, width: 16, height: 19))
        StorybookArt.fillAndStroke(sp, bowl, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xDDA63B), width: 2.4)
        sp.fill(Path(ellipseIn: CGRect(x: -5, y: -18, width: 10, height: 11)), with: .color(Theme.pink))

        StorybookArt.sparkle(g, at: CGPoint(x: -32, y: -22), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 26, y: -28), radius: 6.5, color: Theme.pink)
    }

    private func drawBowStylist(_ g: GraphicsContext) {
        // Ribbon tails
        for side in [-1.0, 1.0] {
            var tail = Path()
            tail.move(to: CGPoint(x: CGFloat(side) * 4, y: 6))
            tail.addLine(to: CGPoint(x: CGFloat(side) * 24, y: 32))
            tail.addLine(to: CGPoint(x: CGFloat(side) * 12, y: 28))
            tail.addLine(to: CGPoint(x: CGFloat(side) * 6, y: 36))
            tail.closeSubpath()
            StorybookArt.fillAndStroke(
                g,
                tail,
                fill: StorybookArt.color(0xFF9AC0),
                stroke: StorybookArt.outline(for: 0xE86C9B),
                width: 2.8
            )
        }

        // Bow loops
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var loop = Path()
            loop.move(to: CGPoint(x: 0, y: 0))
            loop.addCurve(to: CGPoint(x: s * 36, y: -16), control1: CGPoint(x: s * 10, y: -24), control2: CGPoint(x: s * 34, y: -28))
            loop.addCurve(to: CGPoint(x: s * 34, y: 12), control1: CGPoint(x: s * 40, y: -2), control2: CGPoint(x: s * 40, y: 6))
            loop.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: s * 24, y: 20), control2: CGPoint(x: s * 10, y: 14))
            loop.closeSubpath()
            StorybookArt.fillAndStroke(
                g,
                loop,
                fill: StorybookArt.color(0xFFB3D1),
                stroke: StorybookArt.outline(for: 0xE86C9B),
                width: 3.2
            )
            // Polka dots
            g.fill(Path(ellipseIn: CGRect(x: s * 20 - 3.5, y: -10, width: 7, height: 7)), with: .color(.white.opacity(0.85)))
            g.fill(Path(ellipseIn: CGRect(x: s * 26 - 3, y: 2, width: 6, height: 6)), with: .color(Theme.lemon.opacity(0.9)))
        }

        let knot = Path(roundedRect: CGRect(x: -10, y: -10, width: 20, height: 22), cornerRadius: 9)
        StorybookArt.fillAndStroke(
            g,
            knot,
            fill: StorybookArt.color(0xC9B6FF),
            stroke: StorybookArt.outline(for: 0x9B82E0),
            width: 3
        )
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 1), size: 11, color: .white)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -32), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -28), radius: 6, color: Theme.lilac)
    }

    private func drawClinicStar(_ g: GraphicsContext) {
        // Trailing ribbons
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var rib = Path()
            rib.move(to: CGPoint(x: s * 12, y: 12))
            rib.addLine(to: CGPoint(x: s * 22, y: 40))
            rib.addLine(to: CGPoint(x: s * 11, y: 34))
            rib.addLine(to: CGPoint(x: s * 2, y: 40))
            rib.closeSubpath()
            StorybookArt.fillAndStroke(
                g,
                rib,
                fill: StorybookArt.color(0xFF8FB8),
                stroke: StorybookArt.outline(for: 0xE66494),
                width: 2.6
            )
        }

        // Golden scalloped medal
        let outer = Path(ellipseIn: CGRect(x: -30, y: -34, width: 60, height: 60))
        StorybookArt.fillAndStroke(
            g,
            outer,
            fill: StorybookArt.color(0xFFD966),
            stroke: StorybookArt.outline(for: 0xD99E2B),
            width: 3.4
        )
        let inner = Path(ellipseIn: CGRect(x: -22, y: -26, width: 44, height: 44))
        StorybookArt.fillAndStroke(
            g,
            inner,
            fill: StorybookArt.color(0xFFF4C8),
            stroke: StorybookArt.outline(for: 0xE6B143),
            width: 2.2
        )

        // Cute pawprint in center
        let pad = Path(ellipseIn: CGRect(x: -9, y: -4, width: 18, height: 14))
        g.fill(pad, with: .color(Theme.pink))
        for (tx, ty) in [(-11.0, -10.0), (-4.0, -15.0), (4.0, -15.0), (11.0, -10.0)] {
            g.fill(Path(ellipseIn: CGRect(x: CGFloat(tx) - 3.6, y: CGFloat(ty) - 4.2, width: 7.2, height: 8.4)), with: .color(Theme.pink))
        }

        StorybookArt.sparkle(g, at: CGPoint(x: -34, y: -24), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 34, y: -26), radius: 8, color: Theme.mint)
    }

    private func drawSuperVet(_ g: GraphicsContext) {
        // Golden crown
        var crown = Path()
        crown.move(to: CGPoint(x: -32, y: 20))
        crown.addLine(to: CGPoint(x: -36, y: -14))
        crown.addLine(to: CGPoint(x: -16, y: 0))
        crown.addLine(to: CGPoint(x: 0, y: -26))
        crown.addLine(to: CGPoint(x: 16, y: 0))
        crown.addLine(to: CGPoint(x: 36, y: -14))
        crown.addLine(to: CGPoint(x: 32, y: 20))
        crown.closeSubpath()

        StorybookArt.fillAndStroke(
            g,
            crown,
            fill: StorybookArt.color(0xFFE074),
            stroke: StorybookArt.outline(for: 0xD99E2B),
            width: 3.4
        )
        let band = Path(roundedRect: CGRect(x: -32, y: 12, width: 64, height: 14), cornerRadius: 7)
        StorybookArt.fillAndStroke(
            g,
            band,
            fill: StorybookArt.color(0xFFCF4D),
            stroke: StorybookArt.outline(for: 0xD99E2B),
            width: 3
        )

        // Crown tip pearls
        for (px, py, col) in [(-36.0, -16.0, Theme.mint), (0.0, -28.0, Theme.pink), (36.0, -16.0, Theme.sky)] {
            let gem = Path(ellipseIn: CGRect(x: CGFloat(px) - 5.5, y: CGFloat(py) - 5.5, width: 11, height: 11))
            StorybookArt.fillAndStroke(g, gem, fill: col, stroke: StorybookArt.outline(for: 0xD99E2B), width: 2.2)
        }

        // Center heart jewel + white cross
        StorybookArt.heart(g, at: CGPoint(x: 0, y: 5), size: 22, color: Theme.pink)
        g.fill(Path(roundedRect: CGRect(x: -2, y: 0, width: 4, height: 10), cornerRadius: 1.5), with: .color(.white))
        g.fill(Path(roundedRect: CGRect(x: -5, y: 3, width: 10, height: 4), cornerRadius: 1.5), with: .color(.white))

        StorybookArt.sparkle(g, at: CGPoint(x: -26, y: -32), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 28, y: -32), radius: 7.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: 35), radius: 6, color: Theme.mint)
    }

    private func heartPath(center: CGPoint, size: CGFloat) -> Path {
        let r = size * 0.5
        let cx = center.x, cy = center.y
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - r * 0.25))
        p.addCurve(
            to: CGPoint(x: cx + r, y: cy - r * 0.15),
            control1: CGPoint(x: cx + r * 0.35, y: cy - r * 1.05),
            control2: CGPoint(x: cx + r * 1.08, y: cy - r * 0.82)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy + r * 0.88),
            control1: CGPoint(x: cx + r * 0.96, y: cy + r * 0.35),
            control2: CGPoint(x: cx + r * 0.35, y: cy + r * 0.65)
        )
        p.addCurve(
            to: CGPoint(x: cx - r, y: cy - r * 0.15),
            control1: CGPoint(x: cx - r * 0.35, y: cy + r * 0.65),
            control2: CGPoint(x: cx - r * 0.96, y: cy + r * 0.35)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy - r * 0.25),
            control1: CGPoint(x: cx - r * 1.08, y: cy - r * 0.82),
            control2: CGPoint(x: cx - r * 0.35, y: cy - r * 1.05)
        )
        p.closeSubpath()
        return p
    }
}
