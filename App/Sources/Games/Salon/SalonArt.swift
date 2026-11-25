import SwiftUI

// MARK: - Salon tools and the room
//
// Tool pictures are drawn in a 100 x 100 box with warm storybook fills, highlights, and
// color-derived outlines (never black). `tip` is the working point of each tool.

enum SalonTool: String, CaseIterable, Identifiable {
    case comb, shampoo, shower, towel, dryer, straightener, curler, scissors, dye, glitter, grow, clips

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .comb: return Color(hex: 0xE5F7F0)
        case .shampoo: return Color(hex: 0xFFE3EE)
        case .shower: return Color(hex: 0xDDF0FF)
        case .towel: return Color(hex: 0xE8F7EF)
        case .dryer: return Color(hex: 0xEEE6FF)
        case .straightener: return Color(hex: 0xE6EEFF)
        case .curler: return Color(hex: 0xFFE7F3)
        case .scissors: return Color(hex: 0xFFE9E0)
        case .dye: return Color(hex: 0xFFF2D9)
        case .glitter: return Color(hex: 0xFFF6CC)
        case .grow: return Color(hex: 0xF4E4FF)
        case .clips: return Color(hex: 0xFFE3EA)
        }
    }

    var tip: CGPoint {
        switch self {
        case .comb: return CGPoint(x: 42, y: 28)
        case .shampoo: return CGPoint(x: 21, y: 22)
        case .shower: return CGPoint(x: 40, y: 58)
        case .towel: return CGPoint(x: 50, y: 54)
        case .dryer: return CGPoint(x: 8, y: 36)
        case .straightener: return CGPoint(x: 50, y: 22)
        case .curler: return CGPoint(x: 36, y: 36)
        case .scissors: return CGPoint(x: 50, y: 20)
        case .dye: return CGPoint(x: 42, y: 18)
        case .glitter: return CGPoint(x: 50, y: 22)
        case .grow: return CGPoint(x: 50, y: 18)
        case .clips: return CGPoint(x: 50, y: 50)
        }
    }

    /// Tools with a tray of choices on the right.
    var hasTray: Bool { self == .dye || self == .glitter || self == .clips }
}

enum SalonToolArt {
    private static func fo(_ ctx: GraphicsContext, _ p: Path, _ c: RGB, _ w: CGFloat = 3) {
        ctx.fill(p, with: .color(c.color))
        ctx.stroke(p, with: .color(Shades.outline(c).color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    private static func shine(_ ctx: GraphicsContext, _ r: CGRect, _ c: RGB) {
        var g = ctx
        g.opacity = 0.7
        g.fill(Path(roundedRect: r, cornerRadius: min(r.width, r.height) / 2), with: .color(Shades.light(c).color))
    }

    static let chrome = RGB(0.86, 0.89, 0.94)

    /// Draws `tool` into a 100 x 100 box at the origin of `ctx`.
    static func draw(_ tool: SalonTool, dye: RGB, rainbow: Bool = false, open: CGFloat = 0, in ctx: GraphicsContext) {
        switch tool {
        case .comb:
            var g = ctx
            g.translateBy(x: 50, y: 50)
            g.rotate(by: .degrees(-36))
            let bodyHex: UInt32 = 0xFF9AC2
            let bodyOutline = StorybookArt.outline(for: bodyHex)
            let padHex: UInt32 = 0xD8F5EA

            // Ergonomic rounded paddle handle
            let handle = Path(roundedRect: CGRect(x: -9, y: 10, width: 18, height: 39), cornerRadius: 9, style: .continuous)
            StorybookArt.fillAndStroke(g, handle, fill: StorybookArt.color(bodyHex), stroke: bodyOutline, width: 3)
            StorybookArt.fillAndStroke(
                g,
                Path(ellipseIn: CGRect(x: -3.5, y: 37, width: 7, height: 7)),
                fill: .white,
                stroke: bodyOutline,
                width: 2
            )

            // Oval paddle brush back
            let head = Path(ellipseIn: CGRect(x: -24, y: -42, width: 48, height: 58))
            StorybookArt.fillAndStroke(g, head, fill: StorybookArt.color(bodyHex), stroke: bodyOutline, width: 3.2)

            // Pastel mint cushion pad
            let pad = Path(ellipseIn: CGRect(x: -17, y: -35, width: 34, height: 44))
            StorybookArt.fillAndStroke(
                g,
                pad,
                fill: StorybookArt.color(padHex),
                stroke: StorybookArt.outline(for: 0x8ED9BE),
                width: 2.2
            )

            // Cute pearl-tipped bristles across the cushion
            for row in 0..<5 {
                let py = -27 + CGFloat(row) * 7.2
                let cols = (row == 0 || row == 4) ? 3 : 4
                let span = CGFloat(cols - 1) * 7.4
                for col in 0..<cols {
                    let px = -span / 2 + CGFloat(col) * 7.4
                    let pin = Path(ellipseIn: CGRect(x: px - 2.3, y: py - 2.3, width: 4.6, height: 4.6))
                    StorybookArt.fillAndStroke(
                        g,
                        pin,
                        fill: .white,
                        stroke: StorybookArt.outline(for: 0x99D6C4),
                        width: 1.3
                    )
                }
            }

            StorybookArt.highlight(g, in: CGRect(x: -17, y: -38, width: 12, height: 5), opacity: 0.65)
            StorybookArt.heart(g, at: CGPoint(x: 0, y: 24), size: 9, color: Theme.lemon)
        case .shampoo:
            let pink = RGB(1, 0.62, 0.75)
            fo(ctx, Path(roundedRect: CGRect(x: 42, y: 26, width: 16, height: 16), cornerRadius: 4), RGB(1, 0.97, 0.9))
            var pump = Path()
            pump.addRoundedRect(in: CGRect(x: 34, y: 14, width: 30, height: 13), cornerSize: CGSize(width: 6, height: 6))
            pump.addRoundedRect(in: CGRect(x: 18, y: 17, width: 20, height: 8), cornerSize: CGSize(width: 4, height: 4))
            fo(ctx, pump, RGB(0.66, 0.85, 1))
            let body = Path(roundedRect: CGRect(x: 28, y: 38, width: 44, height: 56), cornerRadius: 15, style: .continuous)
            fo(ctx, body, pink)
            fo(ctx, Path(ellipseIn: CGRect(x: 36, y: 52, width: 28, height: 26)), RGB(1, 1, 1), 2.2)
            for (x, y, r) in [(45.0, 62.0, 5.0), (55.0, 66.0, 4.0), (51.0, 58.0, 3.0)] {
                ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color(Color(hex: 0x8CC7F2)), lineWidth: 2)
            }
            shine(ctx, CGRect(x: 33, y: 44, width: 6, height: 22), pink)
        case .shower:
            var hose = Path()
            hose.move(to: CGPoint(x: 52, y: 52))
            hose.addQuadCurve(to: CGPoint(x: 84, y: 92), control: CGPoint(x: 78, y: 58))
            ctx.stroke(hose, with: .color(Shades.outline(chrome).color), style: StrokeStyle(lineWidth: 15, lineCap: .round))
            ctx.stroke(hose, with: .color(chrome.color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            let head = Path(ellipseIn: CGRect(x: 12, y: 16, width: 56, height: 40))
            fo(ctx, head, chrome)
            fo(ctx, Path(ellipseIn: CGRect(x: 20, y: 24, width: 40, height: 26)), RGB(0.62, 0.8, 0.98), 2.2)
            var holes = Path()
            for row in 0..<3 {
                for col in 0..<4 {
                    let x = 27 + CGFloat(col) * 8.5 + (row == 1 ? 4 : 0)
                    let y = 29 + CGFloat(row) * 7
                    guard x < 56 else { continue }
                    holes.addEllipse(in: CGRect(x: x - 1.8, y: y - 1.8, width: 3.6, height: 3.6))
                }
            }
            ctx.fill(holes, with: .color(Color(hex: 0x4F7FB8)))
            shine(ctx, CGRect(x: 20, y: 19, width: 20, height: 5), chrome)
        case .towel:
            let mint = RGB(0.6, 0.86, 0.74)
            let body = Path(roundedRect: CGRect(x: 12, y: 30, width: 76, height: 46), cornerRadius: 12, style: .continuous)
            fo(ctx, body, mint)
            var stripes = ctx
            stripes.clip(to: body)
            stripes.fill(Path(CGRect(x: 12, y: 40, width: 76, height: 6)), with: .color(.white.opacity(0.85)))
            stripes.fill(Path(CGRect(x: 12, y: 62, width: 76, height: 6)), with: .color(.white.opacity(0.85)))
            var fold = Path()
            fold.move(to: CGPoint(x: 16, y: 54))
            fold.addQuadCurve(to: CGPoint(x: 84, y: 54), control: CGPoint(x: 50, y: 60))
            ctx.stroke(fold, with: .color(Shades.outline(mint).color.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            for i in 0..<9 {
                let x = 16 + CGFloat(i) * 8.5
                var f = Path()
                f.move(to: CGPoint(x: x, y: 76))
                f.addLine(to: CGPoint(x: x, y: 83))
                ctx.stroke(f, with: .color(Shades.outline(mint).color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        case .scissors:
            let a = Double(open) * 0.32
            let pink = RGB(1, 0.56, 0.72)
            for side in [-1.0, 1.0] {
                var g = ctx
                g.translateBy(x: 50, y: 56)
                g.rotate(by: .radians(side * a))
                var blade = Path()
                blade.move(to: CGPoint(x: 0, y: 0))
                blade.addQuadCurve(to: CGPoint(x: CGFloat(side) * 3, y: -48), control: CGPoint(x: CGFloat(side) * 10, y: -26))
                blade.addQuadCurve(to: CGPoint(x: CGFloat(-side) * 5, y: 0), control: CGPoint(x: CGFloat(-side) * 4, y: -22))
                blade.closeSubpath()
                fo(g, blade, chrome, 2.4)
                var handle = Path()
                handle.addEllipse(in: CGRect(x: CGFloat(-side) * 16 - 12, y: 12, width: 24, height: 26))
                g.stroke(handle, with: .color(Shades.outline(pink).color), style: StrokeStyle(lineWidth: 10))
                g.stroke(handle, with: .color(pink.color), style: StrokeStyle(lineWidth: 6))
                var arm = Path()
                arm.move(to: .zero)
                arm.addLine(to: CGPoint(x: CGFloat(-side) * 10, y: 14))
                g.stroke(arm, with: .color(Shades.outline(pink).color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                g.stroke(arm, with: .color(pink.color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            fo(ctx, Path(ellipseIn: CGRect(x: 46, y: 52, width: 8, height: 8)), RGB(1, 0.85, 0.4), 2)
        case .dryer:
            let lilac = RGB(0.76, 0.66, 0.98)
            var handle = Path()
            handle.move(to: CGPoint(x: 60, y: 48))
            handle.addLine(to: CGPoint(x: 70, y: 88))
            ctx.stroke(handle, with: .color(Shades.outline(lilac).color), style: StrokeStyle(lineWidth: 20, lineCap: .round))
            ctx.stroke(handle, with: .color(Shades.shade(lilac).color), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            fo(ctx, Path(roundedRect: CGRect(x: 4, y: 27, width: 22, height: 18), cornerRadius: 5), Shades.shade(lilac))
            let barrel = Path(roundedRect: CGRect(x: 18, y: 18, width: 66, height: 36), cornerRadius: 18, style: .continuous)
            fo(ctx, barrel, lilac)
            fo(ctx, Path(ellipseIn: CGRect(x: 66, y: 22, width: 22, height: 28)), RGB(1, 0.85, 0.92), 2.4)
            for i in 0..<3 {
                var v = Path()
                let y = 30 + CGFloat(i) * 6
                v.move(to: CGPoint(x: 72, y: y))
                v.addLine(to: CGPoint(x: 82, y: y))
                ctx.stroke(v, with: .color(Shades.outline(lilac).color.opacity(0.6)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            shine(ctx, CGRect(x: 26, y: 23, width: 30, height: 6), lilac)
            fo(ctx, Path(ellipseIn: CGRect(x: 60, y: 58, width: 9, height: 9)), RGB(1, 0.6, 0.75), 1.8)
        case .curler:
            let pink = RGB(1, 0.66, 0.82)
            var rod = Path()
            rod.move(to: CGPoint(x: 18, y: 18))
            rod.addLine(to: CGPoint(x: 64, y: 64))
            ctx.stroke(rod, with: .color(Shades.outline(chrome).color), style: StrokeStyle(lineWidth: 17, lineCap: .round))
            ctx.stroke(rod, with: .color(chrome.color), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            var clamp = Path()
            clamp.move(to: CGPoint(x: 26, y: 18))
            clamp.addLine(to: CGPoint(x: 66, y: 56))
            ctx.stroke(clamp, with: .color(Shades.outline(pink).color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            ctx.stroke(clamp, with: .color(pink.color), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            var handle = Path()
            handle.move(to: CGPoint(x: 64, y: 64))
            handle.addLine(to: CGPoint(x: 88, y: 88))
            ctx.stroke(handle, with: .color(Shades.outline(pink).color), style: StrokeStyle(lineWidth: 20, lineCap: .round))
            ctx.stroke(handle, with: .color(pink.color), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            var glow = ctx
            glow.opacity = 0.5
            glow.stroke(rod, with: .color(Color(hex: 0xFFB36B)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [5, 6]))
        case .straightener:
            let blue = RGB(0.62, 0.72, 0.98)
            for side in [-1.0, 1.0] {
                var arm = Path()
                let s = CGFloat(side)
                arm.move(to: CGPoint(x: 50 + s * 3, y: 92))
                arm.addLine(to: CGPoint(x: 50 + s * 12, y: 50))
                arm.addLine(to: CGPoint(x: 50 + s * 9, y: 10))
                ctx.stroke(arm, with: .color(Shades.outline(blue).color), style: StrokeStyle(lineWidth: 17, lineCap: .round, lineJoin: .round))
                ctx.stroke(arm, with: .color(blue.color), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                fo(ctx, Path(roundedRect: CGRect(x: 50 + s * 5 - 4, y: 8, width: 8, height: 30), cornerRadius: 3), RGB(1, 0.8, 0.6), 2)
            }
            fo(ctx, Path(ellipseIn: CGRect(x: 44, y: 84, width: 12, height: 12)), RGB(1, 0.6, 0.75), 2)
        case .dye:
            let wood = RGB(1, 0.82, 0.6)
            var handle = Path()
            handle.move(to: CGPoint(x: 52, y: 46))
            handle.addLine(to: CGPoint(x: 80, y: 90))
            ctx.stroke(handle, with: .color(Shades.outline(wood).color), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            ctx.stroke(handle, with: .color(wood.color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            fo(ctx, Path(roundedRect: CGRect(x: 36, y: 34, width: 22, height: 16), cornerRadius: 4)
                .applying(CGAffineTransform(translationX: -47, y: -42).concatenating(CGAffineTransform(rotationAngle: -0.56))
                    .concatenating(CGAffineTransform(translationX: 47, y: 42))), chrome, 2.4)
            var bristle = Path()
            bristle.move(to: CGPoint(x: 26, y: 32))
            bristle.addQuadCurve(to: CGPoint(x: 37, y: 8), control: CGPoint(x: 24, y: 15))
            bristle.addQuadCurve(to: CGPoint(x: 51, y: 30), control: CGPoint(x: 53, y: 13))
            bristle.closeSubpath()
            if rainbow {
                var clipped = ctx
                clipped.clip(to: bristle)
                let stripes: [UInt32] = [0xFF6B9D, 0xFFB85C, 0xFFE66D, 0x7CE0A3, 0x74BEFF, 0xB894FF]
                clipped.fill(
                    bristle,
                    with: .linearGradient(
                        Gradient(colors: stripes.map { Color(hex: $0) }),
                        startPoint: CGPoint(x: 24, y: 14),
                        endPoint: CGPoint(x: 50, y: 30)
                    )
                )
                ctx.stroke(bristle, with: .color(StorybookArt.outline(for: 0xFF6B9D)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            } else {
                fo(ctx, bristle, dye, 2.5)
            }
            var gloss = Path()
            gloss.move(to: CGPoint(x: 33, y: 24))
            gloss.addQuadCurve(to: CGPoint(x: 39, y: 14), control: CGPoint(x: 34, y: 18))
            ctx.stroke(gloss, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        case .glitter:
            let gold = RGB(1, 0.84, 0.4)
            let jar = Path(roundedRect: CGRect(x: 30, y: 38, width: 40, height: 54), cornerRadius: 14, style: .continuous)
            fo(ctx, jar, RGB(0.93, 0.95, 1))
            var bits = ctx
            bits.clip(to: jar)
            let cols: [UInt32] = [0xFF8FC4, 0xFFD66E, 0x9CCBFF, 0xC9B6FF, 0x9FE3CF]
            for i in 0..<26 {
                let x = 34 + CGFloat((i * 37) % 33)
                let y = 56 + CGFloat((i * 53) % 34)
                bits.fill(ClipPainter.star(3.2, points: 4, inner: 0.35).applying(CGAffineTransform(translationX: x, y: y)),
                          with: .color(Color(hex: cols[i % cols.count])))
            }
            fo(ctx, Path(roundedRect: CGRect(x: 28, y: 24, width: 44, height: 17), cornerRadius: 6), gold)
            ctx.fill(ClipPainter.star(8).applying(CGAffineTransform(translationX: 50, y: 15)), with: .color(Color(hex: 0xFFD66E)))
            ctx.stroke(ClipPainter.star(8).applying(CGAffineTransform(translationX: 50, y: 15)), with: .color(Shades.outline(gold).color), lineWidth: 2)
        case .grow:
            let potion = RGB(0.86, 0.5, 0.98)
            fo(ctx, Path(roundedRect: CGRect(x: 41, y: 8, width: 18, height: 12), cornerRadius: 4), RGB(0.82, 0.62, 0.45))
            var flask = Path()
            flask.move(to: CGPoint(x: 43, y: 18))
            flask.addLine(to: CGPoint(x: 43, y: 38))
            flask.addCurve(to: CGPoint(x: 50, y: 94), control1: CGPoint(x: 16, y: 46), control2: CGPoint(x: 18, y: 94))
            flask.addCurve(to: CGPoint(x: 57, y: 38), control1: CGPoint(x: 82, y: 94), control2: CGPoint(x: 84, y: 46))
            flask.addLine(to: CGPoint(x: 57, y: 18))
            flask.closeSubpath()
            fo(ctx, flask, RGB(0.95, 0.94, 1))
            var liquid = ctx
            liquid.clip(to: flask)
            liquid.fill(Path(CGRect(x: 0, y: 56, width: 100, height: 44)), with: .color(potion.color))
            liquid.fill(Path(ellipseIn: CGRect(x: 22, y: 51, width: 56, height: 10)), with: .color(Shades.light(potion).color))
            ctx.fill(ClipPainter.heart(9).applying(CGAffineTransform(translationX: 50, y: 74)), with: .color(.white.opacity(0.9)))
            shine(ctx, CGRect(x: 28, y: 50, width: 6, height: 20), RGB(0.95, 0.94, 1))
        case .clips:
            var g = ctx
            g.translateBy(x: 50, y: 50)
            g.scaleBy(x: 1.45, y: 1.45)
            ClipPainter.draw(.bow, color: 4, in: g)
        }
    }
}

struct SalonToolPicture: View {
    let tool: SalonTool
    var dye: RGB = RGB(1, 0.5, 0.75)
    var rainbow: Bool = false
    var open: CGFloat = 0

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.scaleBy(x: size.width / 100, y: size.height / 100)
            SalonToolArt.draw(tool, dye: dye, rainbow: rainbow, open: open, in: g)
        }
    }
}

// MARK: - The room & full-bleed backdrop

enum SalonRoom {
    static func draw(in ctx: GraphicsContext, size: CGSize, floorY: CGFloat, center: CGFloat) {
        draw(in: ctx, bounds: CGRect(origin: .zero, size: size), floorY: floorY, center: center)
    }

    /// The salon wall, arched golden vanity mirror, pastel bottle shelf, pendant lamps, and checkered floor.
    static func draw(in ctx: GraphicsContext, bounds: CGRect, floorY: CGFloat, center: CGFloat) {
        let minX = bounds.minX
        let maxX = bounds.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY

        // Soft pastel pink-lilac salon wall
        let wall = Path(CGRect(x: minX, y: minY, width: bounds.width, height: max(0, floorY - minY)))
        ctx.fill(
            wall,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFCEBFF), Color(hex: 0xF6DDF2)]),
                startPoint: CGPoint(x: 0, y: minY),
                endPoint: CGPoint(x: 0, y: floorY)
            )
        )

        // Wallpaper vertical stripes anchored cleanly to design coordinates
        let stripeStep: CGFloat = 64
        let startStripe = floor(minX / stripeStep) * stripeStep
        var stripes = Path()
        var x = startStripe
        while x < maxX {
            stripes.addRect(CGRect(x: x, y: minY, width: 26, height: max(0, floorY - minY)))
            x += stripeStep
        }
        ctx.fill(stripes, with: .color(Color(hex: 0xFFFFFF, alpha: 0.35)))

        // Tiny wallpaper hearts
        var hearts = Path()
        x = startStripe + 13
        var row = Int(round(startStripe / stripeStep))
        while x < maxX {
            var y: CGFloat = (row % 2 == 0) ? 40 : 90
            while y < floorY - 210 {
                if y >= minY - 12 {
                    hearts.addPath(ClipPainter.heart(5).applying(CGAffineTransform(translationX: x, y: y)))
                }
                y += 100
            }
            x += stripeStep
            row += 1
        }
        ctx.fill(hearts, with: .color(Color(hex: 0xF7C6E0, alpha: 0.68)))

        // Soft spotlight behind the vanity & chair
        ctx.fill(
            Path(ellipseIn: CGRect(x: center - 350, y: 50, width: 700, height: 640)),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0)]),
                center: CGPoint(x: center, y: 360),
                startRadius: 0,
                endRadius: 350
            )
        )

        // Wainscot paneling along lower wall
        let wainY = floorY - 160
        let wain = Path(CGRect(x: minX, y: wainY, width: bounds.width, height: 160))
        ctx.fill(wain, with: .color(Color(hex: 0xE9D3F4)))
        let panelStep: CGFloat = 112
        var panels = Path()
        x = floor(minX / panelStep) * panelStep + 12
        while x < maxX {
            panels.addRoundedRect(in: CGRect(x: x, y: wainY + 20, width: 96, height: 118), cornerSize: CGSize(width: 14, height: 14))
            x += panelStep
        }
        ctx.stroke(panels, with: .color(Color(hex: 0xD6B9E8)), lineWidth: 4)
        ctx.fill(Path(CGRect(x: minX, y: wainY - 6, width: bounds.width, height: 10)), with: .color(Color(hex: 0xFFFFFF, alpha: 0.82)))

        // Arched golden vanity mirror centered behind the chair
        let shelfY = wainY - 24
        drawVanityMirror(in: ctx, center: center, bottomY: shelfY)

        // Pastel salon counter shelf with storybook bottles
        drawCounterShelf(in: ctx, bounds: bounds, shelfY: shelfY, center: center)

        // Twin pink pendant lamps framing the mirror
        for lx in [center - 252, center + 252] {
            var cord = Path()
            cord.move(to: CGPoint(x: lx, y: minY))
            cord.addLine(to: CGPoint(x: lx, y: 64))
            ctx.stroke(cord, with: .color(Color(hex: 0xB9A2CC)), lineWidth: 3)
            var shade = Path()
            shade.move(to: CGPoint(x: lx - 36, y: 100))
            shade.addQuadCurve(to: CGPoint(x: lx + 36, y: 100), control: CGPoint(x: lx, y: 40))
            shade.closeSubpath()
            ctx.fill(
                Path(ellipseIn: CGRect(x: lx - 72, y: 70, width: 144, height: 122)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFF6C8, alpha: 0.72), Color(hex: 0xFFF6C8, alpha: 0)]),
                    center: CGPoint(x: lx, y: 104),
                    startRadius: 0,
                    endRadius: 72
                )
            )
            StorybookArt.fillAndStroke(ctx, shade, fill: Color(hex: 0xFFB8D6), stroke: StorybookArt.outline(for: 0xFF9AC2), width: 3)
            ctx.fill(Path(ellipseIn: CGRect(x: lx - 8, y: 96, width: 16, height: 12)), with: .color(Color(hex: 0xFFF3B0)))
        }

        // Checkered pastel salon floor
        let floorRect = CGRect(x: minX, y: floorY, width: bounds.width, height: max(0, maxY - floorY))
        ctx.fill(Path(floorRect), with: .color(Color(hex: 0xFFF6FA)))
        var tiles = Path()
        let t: CGFloat = 44
        let startTileX = floor(minX / (t * 2)) * (t * 2)
        var ty = floorY
        var r = 0
        while ty < maxY {
            var tx: CGFloat = startTileX + (r % 2 == 0 ? 0 : t)
            while tx < maxX {
                tiles.addRect(CGRect(x: tx, y: ty, width: t, height: t * 0.6))
                tx += t * 2
            }
            ty += t * 0.6
            r += 1
        }
        ctx.fill(tiles, with: .color(Color(hex: 0xF3D7EA)))
        ctx.fill(Path(CGRect(x: minX, y: floorY - 3, width: bounds.width, height: 6)), with: .color(Color(hex: 0xD9B8D8)))
    }

    private static func archedPath(centerX: CGFloat, topY: CGFloat, bottomY: CGFloat, halfW: CGFloat) -> Path {
        let archCenterY = topY + halfW
        var p = Path()
        p.move(to: CGPoint(x: centerX - halfW, y: bottomY))
        p.addLine(to: CGPoint(x: centerX - halfW, y: archCenterY))
        p.addArc(
            center: CGPoint(x: centerX, y: archCenterY),
            radius: halfW,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: centerX + halfW, y: bottomY))
        p.closeSubpath()
        return p
    }

    private static func drawVanityMirror(in ctx: GraphicsContext, center: CGFloat, bottomY: CGFloat) {
        let outerW: CGFloat = 192
        let topY: CGFloat = 94
        let goldOutline = StorybookArt.outline(for: 0xD99E34)

        // Subtle warm glow behind the vanity frame
        ctx.fill(
            Path(ellipseIn: CGRect(x: center - outerW - 22, y: topY - 18, width: (outerW + 22) * 2, height: bottomY - topY + 26)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF7D6, alpha: 0.45), Color.white.opacity(0)]),
                center: CGPoint(x: center, y: (topY + bottomY) * 0.5),
                startRadius: 80,
                endRadius: outerW + 40
            )
        )

        // Outer golden arch frame
        let outer = archedPath(centerX: center, topY: topY, bottomY: bottomY, halfW: outerW)
        ctx.fill(
            outer,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFE89E), Color(hex: 0xF2C25E), Color(hex: 0xFFE38F)]),
                startPoint: CGPoint(x: center - outerW, y: topY),
                endPoint: CGPoint(x: center + outerW, y: bottomY)
            )
        )
        ctx.stroke(outer, with: .color(goldOutline), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

        // Inner cream molding trim + pastel mirror glass
        let innerW = outerW - 18
        let innerTop = topY + 18
        let glass = archedPath(centerX: center, topY: innerTop, bottomY: bottomY - 4, halfW: innerW)
        ctx.fill(
            glass,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF9FF), Color(hex: 0xEFE6FF), Color(hex: 0xE6F2FF)]),
                startPoint: CGPoint(x: center - innerW, y: innerTop),
                endPoint: CGPoint(x: center + innerW, y: bottomY)
            )
        )

        // Diagonal glossy glass reflection streaks clipped inside mirror
        var reflect = ctx
        reflect.clip(to: glass)
        var streak1 = Path()
        streak1.move(to: CGPoint(x: center - 160, y: innerTop + 170))
        streak1.addLine(to: CGPoint(x: center + 40, y: innerTop - 20))
        streak1.addLine(to: CGPoint(x: center + 96, y: innerTop - 20))
        streak1.addLine(to: CGPoint(x: center - 104, y: innerTop + 170))
        streak1.closeSubpath()
        reflect.fill(streak1, with: .color(.white.opacity(0.55)))

        var streak2 = Path()
        streak2.move(to: CGPoint(x: center - 90, y: innerTop + 215))
        streak2.addLine(to: CGPoint(x: center + 125, y: innerTop + 10))
        streak2.addLine(to: CGPoint(x: center + 148, y: innerTop + 10))
        streak2.addLine(to: CGPoint(x: center - 67, y: innerTop + 215))
        streak2.closeSubpath()
        reflect.fill(streak2, with: .color(.white.opacity(0.42)))

        ctx.stroke(glass, with: .color(Color(hex: 0xFFF6D6)), lineWidth: 5)
        ctx.stroke(glass, with: .color(goldOutline.opacity(0.65)), lineWidth: 2)

        // Warm vanity bulbs around the gilded arch
        let archCenterY = topY + outerW
        let bulbR = outerW - 9
        for i in 0...8 {
            let deg = 185.0 - Double(i) * (190.0 / 8.0)
            let rad = deg * .pi / 180
            let bx = center + CGFloat(cos(rad)) * bulbR
            let by = archCenterY - CGFloat(sin(rad)) * bulbR
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 12, y: by - 12, width: 24, height: 24)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF6B8, alpha: 0.7), Color(hex: 0xFFF6B8, alpha: 0)]),
                                           center: CGPoint(x: bx, y: by), startRadius: 0, endRadius: 12))
            StorybookArt.fillAndStroke(
                ctx,
                Path(ellipseIn: CGRect(x: bx - 5.5, y: by - 5.5, width: 11, height: 11)),
                fill: Color(hex: 0xFFFDF0),
                stroke: goldOutline,
                width: 1.8
            )
        }

        // Storybook golden heart-crown ornament atop the mirror arch
        let crest = Path(ellipseIn: CGRect(x: center - 24, y: topY - 14, width: 48, height: 28))
        StorybookArt.fillAndStroke(ctx, crest, fill: Color(hex: 0xFFE388), stroke: goldOutline, width: 3.5)
        StorybookArt.heart(ctx, at: CGPoint(x: center, y: topY), size: 15, color: Theme.pink)
        StorybookArt.sparkle(ctx, at: CGPoint(x: center - 122, y: topY + 62), radius: 7, color: .white, opacity: 0.9)
        StorybookArt.sparkle(ctx, at: CGPoint(x: center + 114, y: topY + 94), radius: 6, color: Theme.lemon, opacity: 0.85)
    }

    private static func drawCounterShelf(in ctx: GraphicsContext, bounds: CGRect, shelfY: CGFloat, center: CGFloat) {
        let shelfOutline = StorybookArt.outline(for: 0xE4B8D8)

        // Pastel counter ledge spanning wall-to-wall behind the vanity
        let apron = Path(CGRect(x: bounds.minX, y: shelfY + 12, width: bounds.width, height: 18))
        ctx.fill(apron, with: .color(Color(hex: 0xEDD4F2)))
        ctx.stroke(apron, with: .color(shelfOutline), lineWidth: 2.5)

        let top = Path(CGRect(x: bounds.minX, y: shelfY, width: bounds.width, height: 14))
        ctx.fill(top, with: .color(Color(hex: 0xFFF7FB)))
        ctx.stroke(top, with: .color(shelfOutline), lineWidth: 3)

        // Tiny storybook bottles & salon jars arranged on both sides of the chair
        drawPerfumeBottle(in: ctx, x: center - 224, baseY: shelfY, hex: 0xFFB0D0)
        drawPumpBottle(in: ctx, x: center - 186, baseY: shelfY, hex: 0x9FE3CF, height: 50)
        drawTonicJar(in: ctx, x: center - 150, baseY: shelfY, hex: 0xC9B6FF)

        drawBrushCup(in: ctx, x: center + 162, baseY: shelfY)
        drawPumpBottle(in: ctx, x: center + 202, baseY: shelfY, hex: 0xA8D4FF, height: 54)
        drawPerfumeBottle(in: ctx, x: center + 238, baseY: shelfY, hex: 0xFFE08C)
    }

    private static func drawPumpBottle(in ctx: GraphicsContext, x: CGFloat, baseY: CGFloat, hex: UInt32, height: CGFloat) {
        let out = StorybookArt.outline(for: hex)
        let neck = Path(roundedRect: CGRect(x: x - 5, y: baseY - height - 8, width: 10, height: 10), cornerRadius: 2.5)
        StorybookArt.fillAndStroke(ctx, neck, fill: .white, stroke: out, width: 2)
        var nozzle = Path()
        nozzle.addRoundedRect(in: CGRect(x: x - 7, y: baseY - height - 15, width: 16, height: 7), cornerSize: CGSize(width: 3, height: 3))
        StorybookArt.fillAndStroke(ctx, nozzle, fill: Color(hex: 0xFFF9FB), stroke: out, width: 2)

        let body = Path(roundedRect: CGRect(x: x - 14, y: baseY - height, width: 28, height: height), cornerRadius: 9, style: .continuous)
        StorybookArt.fillAndStroke(ctx, body, fill: StorybookArt.color(hex), stroke: out, width: 2.6)
        ctx.fill(Path(roundedRect: CGRect(x: x - 9, y: baseY - height * 0.65, width: 18, height: 15), cornerRadius: 4), with: .color(.white.opacity(0.85)))
        StorybookArt.highlight(ctx, in: CGRect(x: x - 10, y: baseY - height + 5, width: 4, height: 14), opacity: 0.65)
    }

    private static func drawPerfumeBottle(in ctx: GraphicsContext, x: CGFloat, baseY: CGFloat, hex: UInt32) {
        let out = StorybookArt.outline(for: hex)
        let neck = Path(roundedRect: CGRect(x: x - 5, y: baseY - 40, width: 10, height: 10), cornerRadius: 2.5)
        StorybookArt.fillAndStroke(ctx, neck, fill: Color(hex: 0xFFE38A), stroke: StorybookArt.outline(for: 0xD89A3C), width: 2)
        // Little spritzer bulb
        let bulb = Path(ellipseIn: CGRect(x: x + 7, y: baseY - 44, width: 13, height: 10))
        StorybookArt.fillAndStroke(ctx, bulb, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xE6649B), width: 2)

        let flask = Path(ellipseIn: CGRect(x: x - 16, y: baseY - 32, width: 32, height: 32))
        StorybookArt.fillAndStroke(ctx, flask, fill: StorybookArt.color(hex), stroke: out, width: 2.6)
        StorybookArt.heart(ctx, at: CGPoint(x: x, y: baseY - 15), size: 11, color: .white.opacity(0.9))
        StorybookArt.highlight(ctx, in: CGRect(x: x - 10, y: baseY - 27, width: 8, height: 5), opacity: 0.72)
    }

    private static func drawTonicJar(in ctx: GraphicsContext, x: CGFloat, baseY: CGFloat, hex: UInt32) {
        let out = StorybookArt.outline(for: hex)
        let lid = Path(roundedRect: CGRect(x: x - 12, y: baseY - 34, width: 24, height: 8), cornerRadius: 4)
        StorybookArt.fillAndStroke(ctx, lid, fill: Color(hex: 0xFFE38A), stroke: StorybookArt.outline(for: 0xD89A3C), width: 2.2)
        let jar = Path(roundedRect: CGRect(x: x - 14, y: baseY - 27, width: 28, height: 27), cornerRadius: 9, style: .continuous)
        StorybookArt.fillAndStroke(ctx, jar, fill: StorybookArt.color(hex), stroke: out, width: 2.5)
        StorybookArt.sparkle(ctx, at: CGPoint(x: x, y: baseY - 13), radius: 6, color: .white, opacity: 0.9)
    }

    private static func drawBrushCup(in ctx: GraphicsContext, x: CGFloat, baseY: CGFloat) {
        // Tiny pink comb peeking out of a cream cup
        var comb = Path(roundedRect: CGRect(x: x - 9, y: baseY - 50, width: 11, height: 30), cornerRadius: 4)
        comb = comb.applying(CGAffineTransform(translationX: -(x - 4), y: -(baseY - 35))
            .concatenating(CGAffineTransform(rotationAngle: -0.22))
            .concatenating(CGAffineTransform(translationX: x - 4, y: baseY - 35)))
        StorybookArt.fillAndStroke(ctx, comb, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xE6649B), width: 2)

        var wand = Path(roundedRect: CGRect(x: x + 2, y: baseY - 46, width: 7, height: 26), cornerRadius: 3)
        wand = wand.applying(CGAffineTransform(translationX: -(x + 5), y: -(baseY - 33))
            .concatenating(CGAffineTransform(rotationAngle: 0.2))
            .concatenating(CGAffineTransform(translationX: x + 5, y: baseY - 33)))
        StorybookArt.fillAndStroke(ctx, wand, fill: Theme.lilac, stroke: StorybookArt.outline(for: 0x8F72D6), width: 2)

        let cup = Path(roundedRect: CGRect(x: x - 13, y: baseY - 30, width: 26, height: 30), cornerRadius: 7, style: .continuous)
        StorybookArt.fillAndStroke(ctx, cup, fill: Color(hex: 0xFFF4FA), stroke: StorybookArt.outline(for: 0xE8B4D4), width: 2.6)
        StorybookArt.heart(ctx, at: CGPoint(x: x, y: baseY - 14), size: 9, color: Theme.pink)
    }
}

struct SalonBackdropView: View {
    var body: some View {
        Canvas(opaque: true) { ctx, size in
            let m = GameStageMap(size: size)
            var g = ctx
            g.translateBy(x: m.origin.x, y: m.origin.y)
            g.scaleBy(x: m.scale, y: m.scale)

            let visible = CGRect(
                x: -m.origin.x / m.scale - 4,
                y: -m.origin.y / m.scale - 4,
                width: size.width / m.scale + 8,
                height: size.height / m.scale + 8
            )
            SalonRoom.draw(
                in: g,
                bounds: visible,
                floorY: SalonWorld.floorDesignDefault,
                center: SalonWorld.defaultCenterX
            )
        }
    }
}
