import SwiftUI
import UIKit

// MARK: - Dual-target vector drawer (SwiftUI GraphicsContext + CoreGraphics CGContext)

struct VectorDrawer {
    enum Target {
        case swiftUI(GraphicsContext)
        case cg(CGContext)
    }

    let target: Target
    let dieCut: Bool
    private static let dieCutSpread: CGFloat = 11

    func fill(_ path: Path, color: Color) {
        if dieCut {
            paintFill(path, color: .white)
            paintStroke(path, color: .white, width: Self.dieCutSpread)
        } else {
            paintFill(path, color: color)
        }
    }

    func stroke(_ path: Path, color: Color, width: CGFloat) {
        if dieCut {
            paintStroke(path, color: .white, width: width + Self.dieCutSpread)
        } else {
            paintStroke(path, color: color, width: width)
        }
    }

    func fillAndStroke(_ path: Path, fill: Color, stroke: Color, width: CGFloat = 3) {
        if dieCut {
            paintFill(path, color: .white)
            paintStroke(path, color: .white, width: width + Self.dieCutSpread)
        } else {
            paintFill(path, color: fill)
            paintStroke(path, color: stroke, width: width)
        }
    }

    func shape(_ path: Path, hex: UInt32, width: CGFloat = 3) {
        fillAndStroke(path, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: width)
    }

    /// Draws interior details (highlights, eyes, cheeks) skipped during the white die-cut silhouette pass.
    func detail(_ body: (VectorDrawer) -> Void) {
        guard !dieCut else { return }
        body(self)
    }

    func highlight(in rect: CGRect, opacity: Double = 0.52) {
        guard !dieCut else { return }
        paintFill(Path(ellipseIn: rect), color: .white.opacity(opacity))
    }

    func sparkle(at center: CGPoint, radius: CGFloat, color: Color = Theme.lemon, includeInDieCut: Bool = false) {
        let p = Self.sparklePath(at: center, radius: radius)
        if dieCut {
            guard includeInDieCut else { return }
            paintFill(p, color: .white)
            paintStroke(p, color: .white, width: Self.dieCutSpread)
        } else {
            paintFill(p, color: color)
        }
    }

    func heart(at center: CGPoint, size: CGFloat, hex: UInt32, strokeWidth: CGFloat = 0) {
        let p = Self.heartPath(at: center, size: size)
        if strokeWidth > 0 {
            shape(p, hex: hex, width: strokeWidth)
        } else {
            fill(p, color: StorybookArt.color(hex))
        }
    }

    func kawaiiFace(eyeY: CGFloat, eyeSpacing: CGFloat, mouthY: CGFloat, cheekY: CGFloat? = nil, eyeSize: CGFloat = 5.4) {
        detail { d in
            let cy = cheekY ?? (mouthY + 1)
            for side in [-1.0, 1.0] {
                let ex = CGFloat(side) * eyeSpacing
                d.fill(Path(ellipseIn: CGRect(x: ex - eyeSize / 2, y: eyeY - eyeSize * 0.55, width: eyeSize, height: eyeSize * 1.12)), color: Theme.ink)
                d.fill(Path(ellipseIn: CGRect(x: ex - eyeSize * 0.22, y: eyeY - eyeSize * 0.42, width: eyeSize * 0.4, height: eyeSize * 0.4)), color: .white)
                d.fill(Path(ellipseIn: CGRect(x: ex + CGFloat(side) * 2.5 - 4.5, y: cy - 2.4, width: 9, height: 5)), color: Theme.pink.opacity(0.6))
            }
            var smile = Path()
            smile.move(to: CGPoint(x: -4.2, y: mouthY))
            smile.addQuadCurve(to: CGPoint(x: 4.2, y: mouthY), control: CGPoint(x: 0, y: mouthY + 5.2))
            d.stroke(smile, color: Theme.ink, width: 2.3)
        }
    }

    func transformed(dx: CGFloat = 0, dy: CGFloat = 0, degrees: CGFloat = 0, scale: CGFloat = 1, _ body: (VectorDrawer) -> Void) {
        switch target {
        case .swiftUI(let g):
            var sub = g
            if dx != 0 || dy != 0 { sub.translateBy(x: dx, y: dy) }
            if degrees != 0 { sub.rotate(by: .degrees(Double(degrees))) }
            if scale != 1 { sub.scaleBy(x: scale, y: scale) }
            body(VectorDrawer(target: .swiftUI(sub), dieCut: dieCut))
        case .cg(let cg):
            cg.saveGState()
            if dx != 0 || dy != 0 { cg.translateBy(x: dx, y: dy) }
            if degrees != 0 { cg.rotate(by: degrees * .pi / 180) }
            if scale != 1 { cg.scaleBy(x: scale, y: scale) }
            body(VectorDrawer(target: .cg(cg), dieCut: dieCut))
            cg.restoreGState()
        }
    }

    private func paintFill(_ path: Path, color: Color) {
        switch target {
        case .swiftUI(let g):
            g.fill(path, with: .color(color))
        case .cg(let cg):
            cg.addPath(path.cgPath)
            cg.setFillColor(UIColor(color).cgColor)
            cg.fillPath()
        }
    }

    private func paintStroke(_ path: Path, color: Color, width: CGFloat) {
        switch target {
        case .swiftUI(let g):
            g.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        case .cg(let cg):
            cg.addPath(path.cgPath)
            cg.setStrokeColor(UIColor(color).cgColor)
            cg.setLineWidth(width)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            cg.strokePath()
        }
    }

    static func starPath(at center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int = 5, rotation: CGFloat = 0) -> Path {
        var p = Path()
        for i in 0..<(points * 2) {
            let a = rotation - .pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let r = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func heartPath(at center: CGPoint, size: CGFloat) -> Path {
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

    static func sparklePath(at center: CGPoint, radius: CGFloat) -> Path {
        var p = Path()
        let k = radius * 0.22
        p.move(to: CGPoint(x: center.x, y: center.y - radius))
        p.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + k, y: center.y - k))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + k, y: center.y + k))
        p.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - k, y: center.y + k))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - k, y: center.y - k))
        p.closeSubpath()
        return p
    }
}

// MARK: - Curated die-cut vector stickers (24 kids' favorites)

enum ColoringVectorSticker: String, CaseIterable {
    case unicorn, rainbow, star
    case heart, crown, sparkle
    case butterfly, flower, sun
    case moon, cloud, bow
    case kitty, bunny, puppy
    case paw, diamond, magicWand
    case cupcake, strawberry, lollipop
    case iceCream, balloon, musicNote
    case hanbokRibbon, fairyGem

    static let starStampTreasureID = "coloring/starStamp"
    static let rainbowBrushTreasureID = "coloring/rainbowBrush"
    static let bonusStarStampCases: [ColoringVectorSticker] = [.hanbokRibbon, .fairyGem]

    var isBonusTreasure: Bool { Self.bonusStarStampCases.contains(self) }

    /// Draws the sticker inside a centered 100x100 design square (-50...50).
    func draw(in d: VectorDrawer) {
        switch self {
        case .unicorn: drawUnicorn(d)
        case .rainbow: drawRainbow(d)
        case .star: drawStar(d)
        case .heart: drawHeart(d)
        case .crown: drawCrown(d)
        case .sparkle: drawSparkle(d)
        case .butterfly: drawButterfly(d)
        case .flower: drawFlower(d)
        case .sun: drawSun(d)
        case .moon: drawMoon(d)
        case .cloud: drawCloud(d)
        case .bow: drawBow(d)
        case .kitty: drawKitty(d)
        case .bunny: drawBunny(d)
        case .puppy: drawPuppy(d)
        case .paw: drawPaw(d)
        case .diamond: drawDiamond(d)
        case .magicWand: drawMagicWand(d)
        case .cupcake: drawCupcake(d)
        case .strawberry: drawStrawberry(d)
        case .lollipop: drawLollipop(d)
        case .iceCream: drawIceCream(d)
        case .balloon: drawBalloon(d)
        case .musicNote: drawMusicNote(d)
        case .hanbokRibbon: drawHanbokRibbon(d)
        case .fairyGem: drawFairyGem(d)
        }
    }

    private func drawUnicorn(_ d: VectorDrawer) {
        // Ears
        for side in [-1.0, 1.0] {
            let sx = CGFloat(side)
            var ear = Path()
            ear.move(to: CGPoint(x: sx * 10, y: -12))
            ear.addQuadCurve(to: CGPoint(x: sx * 24, y: -28), control: CGPoint(x: sx * 22, y: -20))
            ear.addQuadCurve(to: CGPoint(x: sx * 22, y: -4), control: CGPoint(x: sx * 27, y: -16))
            ear.closeSubpath()
            d.fillAndStroke(ear, fill: StorybookArt.color(0xFFFDFB), stroke: StorybookArt.outline(for: 0xDFC7D9), width: 2.8)
            d.detail { inner in
                var pink = Path()
                pink.move(to: CGPoint(x: sx * 14, y: -12))
                pink.addLine(to: CGPoint(x: sx * 21, y: -22))
                pink.addLine(to: CGPoint(x: sx * 20, y: -9))
                pink.closeSubpath()
                inner.fill(pink, color: StorybookArt.color(0xFFB3D3))
            }
        }

        // Golden spiral horn
        var horn = Path()
        horn.move(to: CGPoint(x: -6.5, y: -15))
        horn.addLine(to: CGPoint(x: 0, y: -39))
        horn.addLine(to: CGPoint(x: 6.5, y: -15))
        horn.closeSubpath()
        d.shape(horn, hex: 0xFFE070, width: 2.6)
        d.detail { inner in
            for y in [CGFloat(-21), -27, -32] {
                let w = (y + 39) * 0.2
                var stripe = Path()
                stripe.move(to: CGPoint(x: -w, y: y))
                stripe.addLine(to: CGPoint(x: w, y: y - 2.5))
                inner.stroke(stripe, color: StorybookArt.outline(for: 0xE6A732), width: 1.8)
            }
        }

        // Head + soft muzzle
        let head = Path(ellipseIn: CGRect(x: -24, y: -16, width: 48, height: 44))
        d.fillAndStroke(head, fill: StorybookArt.color(0xFFFDFB), stroke: StorybookArt.outline(for: 0xDFC7D9), width: 3)
        let muzzle = Path(ellipseIn: CGRect(x: -17, y: 8, width: 34, height: 22))
        d.fillAndStroke(muzzle, fill: StorybookArt.color(0xFFEAF3), stroke: StorybookArt.outline(for: 0xE8B4CB), width: 2.2)

        // Pastel mane puffs across forehead
        let mane: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (-14, -14, 9, 0xC9B6FF), (-3, -17, 10, 0xFF9AC9), (10, -14, 9, 0x9ED8FF),
        ]
        for (mx, my, mr, hex) in mane {
            d.shape(Path(ellipseIn: CGRect(x: mx - mr, y: my - mr * 0.85, width: mr * 2, height: mr * 1.7)), hex: hex, width: 2.3)
        }

        // Kawaii eyes, cheeks & tiny nostrils
        d.kawaiiFace(eyeY: 2, eyeSpacing: 11, mouthY: 18, cheekY: 10, eyeSize: 5.2)
        d.detail { inner in
            inner.fill(Path(ellipseIn: CGRect(x: -6, y: 13, width: 3, height: 2.2)), color: StorybookArt.outline(for: 0xFF8FB8))
            inner.fill(Path(ellipseIn: CGRect(x: 3, y: 13, width: 3, height: 2.2)), color: StorybookArt.outline(for: 0xFF8FB8))
        }
    }

    private func drawRainbow(_ d: VectorDrawer) {
        let bands: [(CGFloat, UInt32)] = [
            (31, 0xFF7FA8), (25.5, 0xFFB078), (20, 0xFFE378), (14.5, 0x8CE3C0), (9, 0x82C4FF),
        ]
        let c = CGPoint(x: 0, y: 15)
        for (r, hex) in bands {
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
            d.stroke(arc, color: StorybookArt.color(hex), width: 6.4)
        }
        // Soft clouds at both feet
        for side in [-1.0, 1.0] {
            let cx = CGFloat(side) * 23
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(cx - 7, 18, 7.5), (cx, 14, 9.5), (cx + 7, 18, 7.5)]
            for (px, py, pr) in puffs {
                d.fillAndStroke(
                    Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                    fill: .white,
                    stroke: StorybookArt.outline(for: 0xA8D4FF),
                    width: 2.6
                )
            }
            d.detail { inner in
                for (px, py, pr) in puffs {
                    inner.fill(Path(ellipseIn: CGRect(x: px - pr + 1, y: py - pr + 1, width: (pr - 1) * 2, height: (pr - 1) * 2)), color: .white)
                }
            }
        }
        d.sparkle(at: CGPoint(x: 0, y: -29), radius: 6, color: Theme.lemon, includeInDieCut: true)
    }

    private func drawStar(_ d: VectorDrawer) {
        let star = VectorDrawer.starPath(at: CGPoint(x: 0, y: 2), outer: 35, inner: 17.5)
        d.fillAndStroke(star, fill: StorybookArt.color(0xFFE16B), stroke: StorybookArt.outline(for: 0xE6A732), width: 3.4)
        d.highlight(in: CGRect(x: -14, y: -15, width: 13, height: 7.5), opacity: 0.65)
        d.kawaiiFace(eyeY: -1, eyeSpacing: 8.5, mouthY: 7.5, cheekY: 5.5, eyeSize: 5)
    }

    private func drawHeart(_ d: VectorDrawer) {
        let heart = VectorDrawer.heartPath(at: CGPoint(x: 0, y: 0), size: 68)
        d.fillAndStroke(heart, fill: StorybookArt.color(0xFF7EB3), stroke: StorybookArt.outline(for: 0xE8578E), width: 3.4)
        d.highlight(in: CGRect(x: -22, y: -20, width: 15, height: 9.5), opacity: 0.62)
        d.sparkle(at: CGPoint(x: 15, y: -12), radius: 5.5, color: .white)
    }

    private func drawCrown(_ d: VectorDrawer) {
        var body = Path()
        body.move(to: CGPoint(x: -31, y: 20))
        body.addLine(to: CGPoint(x: -35, y: -12))
        body.addLine(to: CGPoint(x: -15, y: 4))
        body.addLine(to: CGPoint(x: 0, y: -24))
        body.addLine(to: CGPoint(x: 15, y: 4))
        body.addLine(to: CGPoint(x: 35, y: -12))
        body.addLine(to: CGPoint(x: 31, y: 20))
        body.closeSubpath()
        d.fillAndStroke(body, fill: StorybookArt.color(0xFFDC68), stroke: StorybookArt.outline(for: 0xE5A22E), width: 3.2)

        let band = Path(roundedRect: CGRect(x: -32, y: 14, width: 64, height: 13), cornerRadius: 6)
        d.fillAndStroke(band, fill: StorybookArt.color(0xFFE78E), stroke: StorybookArt.outline(for: 0xE5A22E), width: 3)

        // Pearls on the three tips
        let pearls: [(CGFloat, CGFloat)] = [(-35, -14), (0, -27), (35, -14)]
        for (px, py) in pearls {
            d.fillAndStroke(
                Path(ellipseIn: CGRect(x: px - 5.5, y: py - 5.5, width: 11, height: 11)),
                fill: StorybookArt.color(0xFFF9FB),
                stroke: StorybookArt.outline(for: 0xE5A22E),
                width: 2.2
            )
        }
        d.detail { inner in
            inner.heart(at: CGPoint(x: 0, y: 8), size: 14, hex: 0xFF7EB3, strokeWidth: 1.6)
            inner.shape(Path(ellipseIn: CGRect(x: -22, y: 17, width: 8, height: 7)), hex: 0x82C8FF, width: 1.4)
            inner.shape(Path(ellipseIn: CGRect(x: 14, y: 17, width: 8, height: 7)), hex: 0x8CE3C0, width: 1.4)
        }
    }

    private func drawSparkle(_ d: VectorDrawer) {
        let big = VectorDrawer.sparklePath(at: CGPoint(x: -5, y: 2), radius: 31)
        d.fillAndStroke(big, fill: StorybookArt.color(0xFFE378), stroke: StorybookArt.outline(for: 0xE5A830), width: 3)
        let pink = VectorDrawer.sparklePath(at: CGPoint(x: 23, y: -19), radius: 14)
        d.fillAndStroke(pink, fill: StorybookArt.color(0xFF9AC9), stroke: StorybookArt.outline(for: 0xE5649C), width: 2.4)
        let sky = VectorDrawer.sparklePath(at: CGPoint(x: 22, y: 20), radius: 11)
        d.fillAndStroke(sky, fill: StorybookArt.color(0x8ED2FF), stroke: StorybookArt.outline(for: 0x56A6E0), width: 2.2)
        d.highlight(in: CGRect(x: -11, y: -10, width: 8, height: 8), opacity: 0.72)
    }

    private func drawButterfly(_ d: VectorDrawer) {
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            // Upper wing
            d.transformed(dx: s * 17, dy: -8, degrees: s * 18) { w in
                let upper = Path(ellipseIn: CGRect(x: -17, y: -15, width: 34, height: 28))
                w.shape(upper, hex: 0xC9B6FF, width: 3)
                w.detail { inner in
                    inner.fill(Path(ellipseIn: CGRect(x: -7, y: -7, width: 14, height: 12)), color: StorybookArt.color(0xFFE38A))
                    inner.highlight(in: CGRect(x: -10, y: -10, width: 9, height: 5), opacity: 0.65)
                }
            }
            // Lower wing
            d.transformed(dx: s * 14, dy: 14, degrees: s * -16) { w in
                let lower = Path(ellipseIn: CGRect(x: -13, y: -11, width: 26, height: 22))
                w.shape(lower, hex: 0xFF9AC9, width: 3)
                w.detail { inner in
                    inner.fill(Path(ellipseIn: CGRect(x: -5, y: -4, width: 10, height: 8)), color: StorybookArt.color(0xFFF3C4))
                }
            }
            // Antenna
            var ant = Path()
            ant.move(to: CGPoint(x: s * 3, y: -15))
            ant.addQuadCurve(to: CGPoint(x: s * 12, y: -32), control: CGPoint(x: s * 4, y: -28))
            d.stroke(ant, color: Theme.ink, width: 2.6)
            d.fill(Path(ellipseIn: CGRect(x: s * 12 - 3.2, y: -35.2, width: 6.4, height: 6.4)), color: StorybookArt.color(0xFFE38A))
        }
        // Chubby body
        let body = Path(roundedRect: CGRect(x: -6.5, y: -18, width: 13, height: 42), cornerRadius: 6.5)
        d.fillAndStroke(body, fill: StorybookArt.color(0xFFE9C2), stroke: StorybookArt.outline(for: 0xD9A96A), width: 2.8)
    }

    private func drawFlower(_ d: VectorDrawer) {
        for i in 0..<6 {
            let deg = CGFloat(i) * 60
            d.transformed(degrees: deg) { p in
                let petal = Path(ellipseIn: CGRect(x: -11.5, y: -34, width: 23, height: 26))
                p.shape(petal, hex: 0xFF9AC9, width: 2.8)
                p.highlight(in: CGRect(x: -5, y: -30, width: 7, height: 6), opacity: 0.55)
            }
        }
        let center = Path(ellipseIn: CGRect(x: -15, y: -15, width: 30, height: 30))
        d.fillAndStroke(center, fill: StorybookArt.color(0xFFE16B), stroke: StorybookArt.outline(for: 0xE5A22E), width: 3)
        d.kawaiiFace(eyeY: -2, eyeSpacing: 6, mouthY: 4, cheekY: 3, eyeSize: 4.2)
    }

    private func drawSun(_ d: VectorDrawer) {
        for i in 0..<8 {
            d.transformed(degrees: CGFloat(i) * 45) { ray in
                var tri = Path()
                tri.move(to: CGPoint(x: -6.5, y: -23))
                tri.addLine(to: CGPoint(x: 0, y: -37))
                tri.addLine(to: CGPoint(x: 6.5, y: -23))
                tri.closeSubpath()
                ray.shape(tri, hex: 0xFFB85C, width: 2.5)
            }
        }
        let disc = Path(ellipseIn: CGRect(x: -24, y: -24, width: 48, height: 48))
        d.fillAndStroke(disc, fill: StorybookArt.color(0xFFE36E), stroke: StorybookArt.outline(for: 0xE6A22E), width: 3.2)
        d.highlight(in: CGRect(x: -14, y: -17, width: 14, height: 8), opacity: 0.65)
        d.kawaiiFace(eyeY: -2, eyeSpacing: 8.5, mouthY: 7, cheekY: 5, eyeSize: 5)
    }

    private func drawMoon(_ d: VectorDrawer) {
        var crescent = Path()
        crescent.addArc(center: CGPoint(x: -2, y: 0), radius: 31, startAngle: .degrees(38), endAngle: .degrees(322), clockwise: false)
        crescent.addArc(center: CGPoint(x: 12, y: -4), radius: 24, startAngle: .degrees(302), endAngle: .degrees(58), clockwise: true)
        crescent.closeSubpath()
        d.fillAndStroke(crescent, fill: StorybookArt.color(0xFFE685), stroke: StorybookArt.outline(for: 0xE5A830), width: 3.2)
        d.highlight(in: CGRect(x: -24, y: -18, width: 10, height: 14), opacity: 0.55)

        // Cute cozy face inside crescent belly
        d.detail { inner in
            inner.fill(Path(ellipseIn: CGRect(x: -18, y: -4, width: 4.8, height: 5.5)), color: Theme.ink)
            inner.fill(Path(ellipseIn: CGRect(x: -22, y: 3, width: 7.5, height: 4.5)), color: Theme.pink.opacity(0.6))
            var smile = Path()
            smile.move(to: CGPoint(x: -17, y: 7))
            smile.addQuadCurve(to: CGPoint(x: -10, y: 7), control: CGPoint(x: -13.5, y: 11.5))
            inner.stroke(smile, color: Theme.ink, width: 2.1)
        }

        // Tiny dangling star
        let miniStar = VectorDrawer.starPath(at: CGPoint(x: 18, y: -12), outer: 11, inner: 5.2)
        d.fillAndStroke(miniStar, fill: StorybookArt.color(0xFF9AC9), stroke: StorybookArt.outline(for: 0xE5649C), width: 2.2)
    }

    private func drawCloud(_ d: VectorDrawer) {
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-21, 9, 13.5), (21, 9, 13.5), (-11, -6, 16), (11, -4, 15), (0, 10, 15.5),
        ]
        // Pass 1: strokes for clean merged outer contour
        for (px, py, pr) in puffs {
            d.fillAndStroke(
                Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                fill: StorybookArt.color(0xF6FBFF),
                stroke: StorybookArt.outline(for: 0x9ACDF8),
                width: 3.4
            )
        }
        // Pass 2: smooth interior fill hiding internal puff seams
        d.detail { inner in
            for (px, py, pr) in puffs {
                inner.fill(
                    Path(ellipseIn: CGRect(x: px - pr + 1.4, y: py - pr + 1.4, width: (pr - 1.4) * 2, height: (pr - 1.4) * 2)),
                    color: StorybookArt.color(0xF6FBFF)
                )
            }
            inner.highlight(in: CGRect(x: -20, y: -16, width: 15, height: 7), opacity: 0.9)
        }
        d.kawaiiFace(eyeY: 4, eyeSpacing: 9.5, mouthY: 12, cheekY: 10, eyeSize: 4.8)
    }

    private func drawBow(_ d: VectorDrawer) {
        // Ribbon tails
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var tail = Path()
            tail.move(to: CGPoint(x: s * 5, y: 8))
            tail.addLine(to: CGPoint(x: s * 22, y: 31))
            tail.addLine(to: CGPoint(x: s * 10, y: 26))
            tail.addLine(to: CGPoint(x: s * 6, y: 33))
            tail.addLine(to: CGPoint(x: s * 1, y: 12))
            tail.closeSubpath()
            d.shape(tail, hex: 0xFF8FB8, width: 2.8)
        }
        // Puffy bow loops
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            d.transformed(dx: s * 20, dy: -2, degrees: s * -10) { loop in
                let r = Path(roundedRect: CGRect(x: -16, y: -15, width: 32, height: 30), cornerRadius: 14)
                loop.shape(r, hex: 0xFF9AC9, width: 3)
                loop.detail { inner in
                    var crease = Path()
                    crease.move(to: CGPoint(x: s * -10, y: 0))
                    crease.addLine(to: CGPoint(x: s * -2, y: -3))
                    inner.stroke(crease, color: StorybookArt.outline(for: 0xFF7EA8), width: 2.2)
                    inner.highlight(in: CGRect(x: -8, y: -11, width: 12, height: 6), opacity: 0.55)
                }
            }
        }
        // Center knot
        let knot = Path(roundedRect: CGRect(x: -10, y: -10, width: 20, height: 22), cornerRadius: 9)
        d.shape(knot, hex: 0xFF7AA8, width: 3)
        d.highlight(in: CGRect(x: -5, y: -7, width: 7, height: 5), opacity: 0.6)
    }

    private func drawKitty(_ d: VectorDrawer) {
        // Pointy ears
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var ear = Path()
            ear.move(to: CGPoint(x: s * 7, y: -16))
            ear.addLine(to: CGPoint(x: s * 26, y: -33))
            ear.addLine(to: CGPoint(x: s * 27, y: -6))
            ear.closeSubpath()
            d.shape(ear, hex: 0xFFE5C8, width: 3)
            d.detail { inner in
                var pink = Path()
                pink.move(to: CGPoint(x: s * 13, y: -15))
                pink.addLine(to: CGPoint(x: s * 23, y: -26))
                pink.addLine(to: CGPoint(x: s * 23, y: -11))
                pink.closeSubpath()
                inner.fill(pink, color: StorybookArt.color(0xFFB3D3))
            }
        }
        // Round kitty face
        let head = Path(ellipseIn: CGRect(x: -29, y: -19, width: 58, height: 49))
        d.shape(head, hex: 0xFFE5C8, width: 3.2)
        d.highlight(in: CGRect(x: -16, y: -15, width: 15, height: 7), opacity: 0.55)

        // Forehead stripes, eyes, pink nose, w-mouth, whiskers
        d.detail { inner in
            for x in [CGFloat(-6), 0, 6] {
                var st = Path()
                st.move(to: CGPoint(x: x, y: -17))
                st.addLine(to: CGPoint(x: x, y: -10))
                inner.stroke(st, color: StorybookArt.outline(for: 0xF2B880), width: 2.6)
            }
            for side in [-1.0, 1.0] {
                let s = CGFloat(side)
                let ex = s * 11.5
                inner.fill(Path(ellipseIn: CGRect(x: ex - 3, y: -3, width: 6, height: 6.8)), color: Theme.ink)
                inner.fill(Path(ellipseIn: CGRect(x: ex - 1.3, y: -2, width: 2.2, height: 2.2)), color: .white)
                inner.fill(Path(ellipseIn: CGRect(x: ex + s * 3 - 4.5, y: 6, width: 9, height: 5)), color: Theme.pink.opacity(0.6))
                // Whiskers
                for dy in [CGFloat(3), 8.5] {
                    var wh = Path()
                    wh.move(to: CGPoint(x: s * 18, y: dy))
                    wh.addLine(to: CGPoint(x: s * 31, y: dy + (dy > 5 ? 2 : -1)))
                    inner.stroke(wh, color: Theme.ink.opacity(0.75), width: 2)
                }
            }
            var nose = Path()
            nose.move(to: CGPoint(x: -4, y: 4.5))
            nose.addLine(to: CGPoint(x: 4, y: 4.5))
            nose.addLine(to: CGPoint(x: 0, y: 8.5))
            nose.closeSubpath()
            inner.fill(nose, color: Theme.pink)

            var mouth = Path()
            mouth.move(to: CGPoint(x: -6, y: 12))
            mouth.addQuadCurve(to: CGPoint(x: 0, y: 9.5), control: CGPoint(x: -3, y: 15))
            mouth.addQuadCurve(to: CGPoint(x: 6, y: 12), control: CGPoint(x: 3, y: 15))
            inner.stroke(mouth, color: Theme.ink, width: 2.2)
        }
    }

    private func drawBunny(_ d: VectorDrawer) {
        // Tall bunny ears
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            d.transformed(dx: s * 11, dy: -22, degrees: s * 10) { ear in
                let outer = Path(ellipseIn: CGRect(x: -8.5, y: -17, width: 17, height: 34))
                ear.fillAndStroke(outer, fill: StorybookArt.color(0xFFFDFB), stroke: StorybookArt.outline(for: 0xDFC7D9), width: 3)
                ear.detail { inner in
                    inner.fill(Path(ellipseIn: CGRect(x: -4.5, y: -11, width: 9, height: 22)), color: StorybookArt.color(0xFFB8D6))
                }
            }
        }
        // Chubby cheeks face
        let head = Path(ellipseIn: CGRect(x: -26, y: -12, width: 52, height: 44))
        d.fillAndStroke(head, fill: StorybookArt.color(0xFFFDFB), stroke: StorybookArt.outline(for: 0xDFC7D9), width: 3.2)
        d.kawaiiFace(eyeY: 6, eyeSpacing: 10, mouthY: 16.5, cheekY: 13.5, eyeSize: 5.2)
        d.detail { inner in
            inner.fill(Path(ellipseIn: CGRect(x: -3.5, y: 10.5, width: 7, height: 4.5)), color: Theme.pink)
        }
    }

    private func drawPuppy(_ d: VectorDrawer) {
        // Floppy chocolate ears
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            d.transformed(dx: s * 25, dy: 2, degrees: s * 18) { ear in
                let shape = Path(roundedRect: CGRect(x: -9.5, y: -18, width: 19, height: 36), cornerRadius: 9.5)
                ear.shape(shape, hex: 0xA9724B, width: 3)
            }
        }
        // Honey-tan face
        let head = Path(ellipseIn: CGRect(x: -25, y: -21, width: 50, height: 48))
        d.shape(head, hex: 0xF3C796, width: 3.2)

        d.detail { inner in
            // Cute eye spot
            inner.fill(Path(ellipseIn: CGRect(x: -20, y: -12, width: 18, height: 16)), color: StorybookArt.color(0xC99060))
            // Cream snout
            inner.fill(Path(ellipseIn: CGRect(x: -14, y: 4, width: 28, height: 19)), color: StorybookArt.color(0xFFF4E4))
            // Happy tongue
            inner.shape(Path(roundedRect: CGRect(x: -4.5, y: 16, width: 9, height: 9), cornerRadius: 4.5), hex: 0xFF8AA8, width: 1.8)
            // Eyes
            for side in [-1.0, 1.0] {
                let ex = CGFloat(side) * 10
                inner.fill(Path(ellipseIn: CGRect(x: ex - 3, y: -6, width: 6, height: 6.8)), color: Theme.ink)
                inner.fill(Path(ellipseIn: CGRect(x: ex - 1.2, y: -5, width: 2.2, height: 2.2)), color: .white)
            }
            // Button nose + smile
            inner.fill(Path(ellipseIn: CGRect(x: -5.5, y: 4.5, width: 11, height: 7.5)), color: Theme.ink)
            var smile = Path()
            smile.move(to: CGPoint(x: -7, y: 15))
            smile.addQuadCurve(to: CGPoint(x: 0, y: 12.5), control: CGPoint(x: -3.5, y: 18))
            smile.addQuadCurve(to: CGPoint(x: 7, y: 15), control: CGPoint(x: 3.5, y: 18))
            inner.stroke(smile, color: Theme.ink, width: 2.2)
        }
    }

    private func drawPaw(_ d: VectorDrawer) {
        // Main plump heart-like pad
        let mainPad = Path(ellipseIn: CGRect(x: -21, y: -2, width: 42, height: 32))
        d.shape(mainPad, hex: 0xFF9AC9, width: 3.2)
        d.highlight(in: CGRect(x: -12, y: 3, width: 14, height: 7), opacity: 0.55)

        // Four toe beans
        let toes: [(CGFloat, CGFloat, CGFloat)] = [(-24, -10, -24), (-9, -22, -8), (9, -22, 8), (24, -10, 24)]
        for (tx, ty, deg) in toes {
            d.transformed(dx: tx, dy: ty, degrees: deg) { toe in
                toe.shape(Path(ellipseIn: CGRect(x: -8.5, y: -10.5, width: 17, height: 21)), hex: 0xFF9AC9, width: 2.8)
                toe.highlight(in: CGRect(x: -4, y: -7, width: 5, height: 4), opacity: 0.6)
            }
        }
    }

    private func drawDiamond(_ d: VectorDrawer) {
        var gem = Path()
        gem.move(to: CGPoint(x: -18, y: -26))
        gem.addLine(to: CGPoint(x: 18, y: -26))
        gem.addLine(to: CGPoint(x: 34, y: -6))
        gem.addLine(to: CGPoint(x: 0, y: 32))
        gem.addLine(to: CGPoint(x: -34, y: -6))
        gem.closeSubpath()
        d.shape(gem, hex: 0x82D8FF, width: 3.2)

        d.detail { inner in
            // Top facet
            var top = Path()
            top.move(to: CGPoint(x: -18, y: -26))
            top.addLine(to: CGPoint(x: 18, y: -26))
            top.addLine(to: CGPoint(x: 11, y: -6))
            top.addLine(to: CGPoint(x: -11, y: -6))
            top.closeSubpath()
            inner.fill(top, color: StorybookArt.color(0xC6F0FF))

            // Facet lines
            let strokeCol = StorybookArt.outline(for: 0x5AB8E8)
            var lines = Path()
            lines.move(to: CGPoint(x: -34, y: -6)); lines.addLine(to: CGPoint(x: 34, y: -6))
            lines.move(to: CGPoint(x: -18, y: -26)); lines.addLine(to: CGPoint(x: -11, y: -6)); lines.addLine(to: CGPoint(x: 0, y: 32))
            lines.move(to: CGPoint(x: 18, y: -26)); lines.addLine(to: CGPoint(x: 11, y: -6)); lines.addLine(to: CGPoint(x: 0, y: 32))
            inner.stroke(lines, color: strokeCol, width: 2.2)

            inner.sparkle(at: CGPoint(x: -14, y: -15), radius: 7, color: .white)
        }
    }

    private func drawMagicWand(_ d: VectorDrawer) {
        d.transformed(degrees: -35) { w in
            // Wand handle
            let stick = Path(roundedRect: CGRect(x: -4.5, y: -4, width: 9, height: 42), cornerRadius: 4.5)
            w.shape(stick, hex: 0xC9B6FF, width: 2.6)
            w.detail { inner in
                for y in [CGFloat(4), 14, 24] {
                    inner.fill(Path(roundedRect: CGRect(x: -3.5, y: y, width: 7, height: 4), cornerRadius: 2), color: .white.opacity(0.65))
                }
            }
            // Little bow ribbons at neck
            for side in [-1.0, 1.0] {
                let s = CGFloat(side)
                var rib = Path()
                rib.move(to: CGPoint(x: 0, y: -2))
                rib.addQuadCurve(to: CGPoint(x: s * 15, y: 12), control: CGPoint(x: s * 12, y: 0))
                w.stroke(rib, color: StorybookArt.color(0xFF8FB8), width: 3.4)
            }
            // Golden star topper
            let star = VectorDrawer.starPath(at: CGPoint(x: 0, y: -17), outer: 22, inner: 10.5)
            w.fillAndStroke(star, fill: StorybookArt.color(0xFFE16B), stroke: StorybookArt.outline(for: 0xE5A22E), width: 3)
            w.detail { inner in
                inner.heart(at: CGPoint(x: 0, y: -16), size: 11, hex: 0xFF7EB3)
                inner.highlight(in: CGRect(x: -8, y: -25, width: 7, height: 4), opacity: 0.7)
            }
        }
        d.sparkle(at: CGPoint(x: 24, y: -22), radius: 7, color: Theme.lemon, includeInDieCut: true)
        d.sparkle(at: CGPoint(x: -24, y: 8), radius: 5.5, color: Theme.pink)
    }

    private func drawCupcake(_ d: VectorDrawer) {
        // Striped paper cup
        var cup = Path()
        cup.move(to: CGPoint(x: -23, y: 5))
        cup.addLine(to: CGPoint(x: 23, y: 5))
        cup.addLine(to: CGPoint(x: 16, y: 33))
        cup.addLine(to: CGPoint(x: -16, y: 33))
        cup.closeSubpath()
        d.shape(cup, hex: 0x9ED8FF, width: 3)
        d.detail { inner in
            for x in [CGFloat(-10), 0, 10] {
                var flute = Path()
                flute.move(to: CGPoint(x: x * 1.15, y: 7))
                flute.addLine(to: CGPoint(x: x * 0.85, y: 31))
                inner.stroke(flute, color: StorybookArt.outline(for: 0x72BEFA), width: 2.2)
            }
        }

        // Swirled pastel pink frosting tiers
        let bottomSwirl = Path(roundedRect: CGRect(x: -27, y: -8, width: 54, height: 18), cornerRadius: 9)
        d.shape(bottomSwirl, hex: 0xFF9AC9, width: 3)
        let midSwirl = Path(roundedRect: CGRect(x: -20, y: -20, width: 40, height: 16), cornerRadius: 8)
        d.shape(midSwirl, hex: 0xFFB5D6, width: 2.8)
        let topSwirl = Path(ellipseIn: CGRect(x: -11, y: -28, width: 22, height: 13))
        d.shape(topSwirl, hex: 0xFFC7E0, width: 2.6)

        // Glossy cherry on top
        let cherry = Path(ellipseIn: CGRect(x: -7, y: -37, width: 14, height: 14))
        d.shape(cherry, hex: 0xFF5F7E, width: 2.5)
        d.highlight(in: CGRect(x: -4, y: -35, width: 4.5, height: 3.5), opacity: 0.75)

        // Sprinkles
        d.detail { inner in
            let sprinkles: [(CGFloat, CGFloat, UInt32)] = [
                (-15, -2, 0xFFE378), (-4, -12, 0x8CE3C0), (11, -3, 0x82C8FF), (13, -13, 0xFFE378), (-2, 1, 0xFFFFFF),
            ]
            for (sx, sy, hex) in sprinkles {
                inner.fill(Path(roundedRect: CGRect(x: sx - 3, y: sy - 1.5, width: 6, height: 3), cornerRadius: 1.5), color: StorybookArt.color(hex))
            }
        }
    }

    private func drawStrawberry(_ d: VectorDrawer) {
        var berry = Path()
        berry.move(to: CGPoint(x: 0, y: 34))
        berry.addCurve(to: CGPoint(x: -27, y: -6), control1: CGPoint(x: -21, y: 27), control2: CGPoint(x: -31, y: 9))
        berry.addCurve(to: CGPoint(x: 0, y: -21), control1: CGPoint(x: -24, y: -21), control2: CGPoint(x: -10, y: -22))
        berry.addCurve(to: CGPoint(x: 27, y: -6), control1: CGPoint(x: 10, y: -22), control2: CGPoint(x: 24, y: -21))
        berry.addCurve(to: CGPoint(x: 0, y: 34), control1: CGPoint(x: 31, y: 9), control2: CGPoint(x: 21, y: 27))
        berry.closeSubpath()
        d.shape(berry, hex: 0xFF6B8A, width: 3.2)

        // Leafy green crown
        var leaf = Path()
        leaf.move(to: CGPoint(x: -20, y: -18))
        leaf.addLine(to: CGPoint(x: -7, y: -25))
        leaf.addLine(to: CGPoint(x: 0, y: -34))
        leaf.addLine(to: CGPoint(x: 7, y: -25))
        leaf.addLine(to: CGPoint(x: 20, y: -18))
        leaf.addLine(to: CGPoint(x: 9, y: -13))
        leaf.addLine(to: CGPoint(x: 0, y: -8))
        leaf.addLine(to: CGPoint(x: -9, y: -13))
        leaf.closeSubpath()
        d.shape(leaf, hex: 0x73D285, width: 2.6)

        d.highlight(in: CGRect(x: -17, y: -11, width: 10, height: 14), opacity: 0.45)
        d.detail { inner in
            let seeds: [(CGFloat, CGFloat)] = [(-11, 2), (0, 0), (11, 2), (-7, 13), (7, 13), (0, 22)]
            for (sx, sy) in seeds {
                inner.fill(Path(ellipseIn: CGRect(x: sx - 2, y: sy - 2.8, width: 4, height: 5.6)), color: Theme.lemon)
            }
        }
    }

    private func drawLollipop(_ d: VectorDrawer) {
        // White paper stick
        let stick = Path(roundedRect: CGRect(x: -3.5, y: 8, width: 7, height: 29), cornerRadius: 3.5)
        d.fillAndStroke(stick, fill: .white, stroke: StorybookArt.outline(for: 0xD8CEDE), width: 2.5)

        // Mint bow tied on stick
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let loop = Path(ellipseIn: CGRect(x: s < 0 ? -13 : 2, y: 12, width: 11, height: 8))
            d.shape(loop, hex: 0x8EE4C4, width: 2)
        }

        // Swirled candy disc
        let disc = Path(ellipseIn: CGRect(x: -24, y: -35, width: 48, height: 48))
        d.shape(disc, hex: 0xFF8FB8, width: 3.2)

        d.detail { inner in
            // Pastel spiral inside candy
            var spiral = Path()
            let steps = 42
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let angle = t * .pi * 4.4
                let r = t * 18.5
                let pt = CGPoint(x: cos(angle) * r, y: -11 + sin(angle) * r)
                if i == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
            }
            inner.stroke(spiral, color: .white.opacity(0.92), width: 4.5)
            inner.highlight(in: CGRect(x: -14, y: -29, width: 12, height: 7), opacity: 0.65)
        }
    }

    private func drawIceCream(_ d: VectorDrawer) {
        // Golden waffle cone
        var cone = Path()
        cone.move(to: CGPoint(x: -18, y: 2))
        cone.addLine(to: CGPoint(x: 18, y: 2))
        cone.addLine(to: CGPoint(x: 0, y: 36))
        cone.closeSubpath()
        d.shape(cone, hex: 0xF3C27A, width: 3)
        d.detail { inner in
            let gridCol = StorybookArt.outline(for: 0xDF9E4C)
            var grid = Path()
            grid.move(to: CGPoint(x: -11, y: 7)); grid.addLine(to: CGPoint(x: 5, y: 24))
            grid.move(to: CGPoint(x: -3, y: 5)); grid.addLine(to: CGPoint(x: 9, y: 18))
            grid.move(to: CGPoint(x: 11, y: 7)); grid.addLine(to: CGPoint(x: -5, y: 24))
            grid.move(to: CGPoint(x: 3, y: 5)); grid.addLine(to: CGPoint(x: -9, y: 18))
            inner.stroke(grid, color: gridCol, width: 1.8)
        }

        // Bottom mint scoop
        d.shape(Path(ellipseIn: CGRect(x: -22, y: -17, width: 44, height: 28)), hex: 0x9FE3CF, width: 3)
        // Top strawberry scoop
        d.shape(Path(ellipseIn: CGRect(x: -18, y: -35, width: 36, height: 28)), hex: 0xFF9AC9, width: 3)
        d.highlight(in: CGRect(x: -11, y: -31, width: 11, height: 6), opacity: 0.65)

        d.detail { inner in
            let sprinkles: [(CGFloat, CGFloat, UInt32)] = [
                (-6, -22, 0xFFE378), (6, -24, 0x82C8FF), (0, -16, 0xFFFFFF), (-10, -6, 0xFF8FB8), (9, -6, 0xFFE378),
            ]
            for (sx, sy, hex) in sprinkles {
                inner.fill(Path(roundedRect: CGRect(x: sx - 3, y: sy - 1.5, width: 6, height: 3), cornerRadius: 1.5), color: StorybookArt.color(hex))
            }
        }
    }

    private func drawBalloon(_ d: VectorDrawer) {
        // Curly string
        var string = Path()
        string.move(to: CGPoint(x: 0, y: 14))
        string.addCurve(to: CGPoint(x: 4, y: 37), control1: CGPoint(x: -10, y: 22), control2: CGPoint(x: 11, y: 28))
        d.stroke(string, color: Theme.ink.opacity(0.75), width: 2.6)

        // Knot
        var knot = Path()
        knot.move(to: CGPoint(x: -5, y: 15))
        knot.addLine(to: CGPoint(x: 5, y: 15))
        knot.addLine(to: CGPoint(x: 0, y: 9))
        knot.closeSubpath()
        d.shape(knot, hex: 0xFF7FA8, width: 2.4)

        // Plump balloon body
        let body = Path(ellipseIn: CGRect(x: -24, y: -36, width: 48, height: 50))
        d.shape(body, hex: 0xFF8FB8, width: 3.2)
        d.highlight(in: CGRect(x: -15, y: -27, width: 11, height: 16), opacity: 0.55)
        d.detail { inner in
            inner.sparkle(at: CGPoint(x: 10, y: -19), radius: 5, color: .white)
        }
    }

    private func drawMusicNote(_ d: VectorDrawer) {
        // Stems & top beam
        var beam = Path()
        beam.move(to: CGPoint(x: -8, y: -21))
        beam.addLine(to: CGPoint(x: 24, y: -30))
        beam.addLine(to: CGPoint(x: 24, y: -17))
        beam.addLine(to: CGPoint(x: -8, y: -8))
        beam.closeSubpath()
        d.shape(beam, hex: 0xB89EFF, width: 2.8)

        let stems: [(CGFloat, CGFloat, CGFloat)] = [(-8, -19, 21), (22, -28, 13)]
        for (sx, topY, botY) in stems {
            let stem = Path(roundedRect: CGRect(x: sx - 3.5, y: topY, width: 7, height: botY - topY), cornerRadius: 3)
            d.shape(stem, hex: 0xB89EFF, width: 2.6)
        }

        // Two glossy note heads
        let heads: [(CGFloat, CGFloat, UInt32)] = [(-16, 20, 0xFF8FB8), (14, 12, 0x82C8FF)]
        for (nx, ny, hex) in heads {
            d.transformed(dx: nx, dy: ny, degrees: -18) { head in
                head.shape(Path(ellipseIn: CGRect(x: -12, y: -9, width: 24, height: 18)), hex: hex, width: 3)
                head.highlight(in: CGRect(x: -6, y: -6, width: 8, height: 4.5), opacity: 0.65)
            }
        }
        d.sparkle(at: CGPoint(x: -24, y: -16), radius: 6, color: Theme.lemon, includeInDieCut: true)
    }

    private func drawHanbokRibbon(_ d: VectorDrawer) {
        // Twin swallow-tail royal hanbok silk drapes with gold geumbak accents
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var tail = Path()
            tail.move(to: CGPoint(x: s * 3, y: -4))
            tail.addCurve(to: CGPoint(x: s * 22, y: 24), control1: CGPoint(x: s * 17, y: 2), control2: CGPoint(x: s * 22, y: 14))
            tail.addLine(to: CGPoint(x: s * 14, y: 34))
            tail.addLine(to: CGPoint(x: s * 5, y: 24))
            tail.addCurve(to: CGPoint(x: 0, y: -2), control1: CGPoint(x: s * 5, y: 12), control2: CGPoint(x: s * 2, y: 3))
            tail.closeSubpath()
            d.shape(tail, hex: side < 0 ? 0xFF7CA8 : 0xFF9AC9, width: 2.8)
            d.detail { inner in
                var trim = Path()
                trim.move(to: CGPoint(x: s * 8, y: 19))
                trim.addLine(to: CGPoint(x: s * 19, y: 18))
                inner.stroke(trim, color: StorybookArt.color(0xFFE378), width: 2.6)
                inner.fill(
                    Path(ellipseIn: CGRect(x: s * 12 - 2.5, y: 9 - 2.5, width: 5, height: 5)),
                    color: StorybookArt.color(0xFFF3B8)
                )
            }
        }
        // Center pastel jade norigae tassel drop
        var tassel = Path()
        tassel.move(to: CGPoint(x: -5, y: 12))
        tassel.addLine(to: CGPoint(x: 5, y: 12))
        tassel.addLine(to: CGPoint(x: 8, y: 34))
        tassel.addLine(to: CGPoint(x: -8, y: 34))
        tassel.closeSubpath()
        d.shape(tassel, hex: 0x9FE3CF, width: 2.4)
        d.detail { inner in
            for dx in [CGFloat(-3), 0, 3] {
                var strand = Path()
                strand.move(to: CGPoint(x: dx, y: 15))
                strand.addLine(to: CGPoint(x: dx * 1.3, y: 32))
                inner.stroke(strand, color: StorybookArt.outline(for: 0x70C9AD), width: 1.4)
            }
        }
        // Puffy hanbok bow loops
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            d.transformed(dx: s * 20, dy: -12, degrees: s * -12) { loop in
                loop.shape(Path(roundedRect: CGRect(x: -16, y: -13, width: 32, height: 26), cornerRadius: 13), hex: 0xFF8FB8, width: 3)
                loop.highlight(in: CGRect(x: -8, y: -9, width: 11, height: 5), opacity: 0.6)
            }
        }
        // Golden knot + jade medallion
        let knot = Path(roundedRect: CGRect(x: -10, y: -21, width: 20, height: 20), cornerRadius: 9)
        d.fillAndStroke(knot, fill: StorybookArt.color(0xFFE070), stroke: StorybookArt.outline(for: 0xE5A22E), width: 2.8)
        d.detail { inner in
            inner.shape(Path(ellipseIn: CGRect(x: -5.5, y: -16.5, width: 11, height: 11)), hex: 0x9FE3CF, width: 1.8)
            inner.highlight(in: CGRect(x: -3, y: -14.5, width: 4, height: 3), opacity: 0.85)
        }
        d.sparkle(at: CGPoint(x: 0, y: -33), radius: 6.5, color: Theme.lemon, includeInDieCut: true)
    }

    private func drawFairyGem(_ d: VectorDrawer) {
        // Fluttering pastel fairy wings behind the crystal heart
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            d.transformed(dx: s * 23, dy: -8, degrees: s * 22) { w in
                w.shape(Path(ellipseIn: CGRect(x: -14, y: -10, width: 28, height: 20)), hex: 0xC9E8FF, width: 2.6)
                w.highlight(in: CGRect(x: -8, y: -6, width: 11, height: 5), opacity: 0.72)
            }
            d.transformed(dx: s * 18, dy: 11, degrees: s * -18) { w in
                w.shape(Path(ellipseIn: CGRect(x: -10, y: -7.5, width: 20, height: 15)), hex: 0xDFCCFF, width: 2.4)
            }
        }
        // Scalloped golden star bezel
        let starBezel = VectorDrawer.starPath(at: CGPoint(x: 0, y: 2), outer: 27, inner: 19, points: 8)
        d.fillAndStroke(starBezel, fill: StorybookArt.color(0xFFE172), stroke: StorybookArt.outline(for: 0xE5A22E), width: 2.8)

        // Radiant pastel heart gem in the center
        let heart = VectorDrawer.heartPath(at: CGPoint(x: 0, y: 2), size: 38)
        d.fillAndStroke(heart, fill: StorybookArt.color(0xFF7EB8), stroke: StorybookArt.outline(for: 0xE55896), width: 2.8)
        d.detail { inner in
            let facet = VectorDrawer.heartPath(at: CGPoint(x: 0, y: 0), size: 20)
            inner.fill(facet, color: StorybookArt.color(0xFFC2E0))
            inner.highlight(in: CGRect(x: -10, y: -8, width: 8.5, height: 5.5), opacity: 0.85)
        }
        d.sparkle(at: CGPoint(x: 0, y: -31), radius: 7, color: Theme.lemon, includeInDieCut: true)
        d.sparkle(at: CGPoint(x: 26, y: -25), radius: 5, color: Theme.pink)
        d.sparkle(at: CGPoint(x: -26, y: 24), radius: 5, color: Theme.sky)
    }
}

// MARK: - Lookup + Shared Renderer (SwiftUI & CoreGraphics Export)

enum ColoringVectorStickers {
    /// Legacy emoji strings mapped cleanly to vector stickers (variation selectors stripped before lookup).
    private static let legacyEmojiMap: [String: ColoringVectorSticker] = [
        "⭐": .star, "🌟": .star,
        "❤": .heart, "💖": .heart, "💗": .heart, "💕": .heart, "💘": .heart, "💝": .heart,
        "🌈": .rainbow,
        "👑": .crown,
        "🌸": .flower, "🌷": .flower, "🌻": .flower, "🌼": .flower, "🌺": .flower, "🍀": .flower,
        "🦋": .butterfly,
        "☀": .sun, "🌞": .sun,
        "🌙": .moon, "🌜": .moon,
        "☁": .cloud, "❄": .cloud,
        "🦄": .unicorn,
        "🐱": .kitty, "😺": .kitty, "🐈": .kitty,
        "🐰": .bunny, "🐇": .bunny,
        "🐶": .puppy, "🐕": .puppy,
        "🎀": .bow,
        "🧁": .cupcake, "🍰": .cupcake, "🎂": .cupcake,
        "🍓": .strawberry, "🍒": .strawberry, "🍉": .strawberry,
        "🍭": .lollipop, "🍬": .lollipop,
        "🍦": .iceCream, "🍨": .iceCream,
        "💎": .diamond, "🔮": .diamond,
        "🪄": .magicWand,
        "🐾": .paw, "🐻": .paw, "🐼": .paw, "🦊": .paw,
        "🎈": .balloon, "🎉": .balloon, "🎁": .balloon,
        "🎵": .musicNote, "🎶": .musicNote,
        "✨": .sparkle, "🫧": .sparkle, "⚡": .sparkle,
    ]

    /// Maps either a modern vector sticker id (`"unicorn"`, `"star"`) or a legacy saved emoji (`"🦄"`, `"⭐️"`, `"❤️"`) to its vector sticker.
    static func sticker(for id: String) -> ColoringVectorSticker? {
        if let direct = ColoringVectorSticker(rawValue: id) { return direct }
        let cleaned = id.replacingOccurrences(of: "\u{FE0F}", with: "")
        return legacyEmojiMap[cleaned]
    }

    static func draw(_ sticker: ColoringVectorSticker, in g: GraphicsContext, size: CGSize) {
        let side = min(size.width, size.height)
        guard side > 0 else { return }
        var ctx = g
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.scaleBy(x: side / 100, y: side / 100)
        sticker.draw(in: VectorDrawer(target: .swiftUI(ctx), dieCut: true))
        sticker.draw(in: VectorDrawer(target: .swiftUI(ctx), dieCut: false))
    }

    /// Renders a die-cut vector sticker directly into a UIKit-flipped CGContext (gallery thumbnails & Photos exports).
    static func draw(_ id: String, in cg: CGContext, at center: CGPoint, size: CGFloat, angle: CGFloat) {
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: angle)

        if let kind = sticker(for: id) {
            let s = size / 100
            cg.setShadow(
                offset: CGSize(width: 0, height: max(1, 2.5 * s)),
                blur: max(1.5, 4 * s),
                color: UIColor(Theme.ink.opacity(0.24)).cgColor
            )
            cg.beginTransparencyLayer(auxiliaryInfo: nil)
            cg.scaleBy(x: s, y: s)
            kind.draw(in: VectorDrawer(target: .cg(cg), dieCut: true))
            kind.draw(in: VectorDrawer(target: .cg(cg), dieCut: false))
            cg.endTransparencyLayer()
        } else {
            let font = UIFont.systemFont(ofSize: size * 0.78)
            let str = NSAttributedString(string: id, attributes: [.font: font])
            let b = str.size()
            str.draw(at: CGPoint(x: -b.width / 2, y: -b.height / 2))
        }

        cg.restoreGState()
    }
}

/// SwiftUI view rendering any sticker id (die-cut vector art with soft paper shadow, or clean fallback for unknown custom strings).
struct ColoringStickerArtView: View {
    let id: String
    var showShadow: Bool = true

    var body: some View {
        if let kind = ColoringVectorStickers.sticker(for: id) {
            Canvas { ctx, size in
                ColoringVectorStickers.draw(kind, in: ctx, size: size)
            }
            .shadow(color: showShadow ? Theme.ink.opacity(0.22) : .clear, radius: showShadow ? 3 : 0, y: showShadow ? 2 : 0)
        } else {
            GeometryReader { geo in
                let d = min(geo.size.width, geo.size.height)
                Text(id)
                    .font(.system(size: d * 0.74))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
