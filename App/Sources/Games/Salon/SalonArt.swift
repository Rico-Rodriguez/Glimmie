import SwiftUI

// MARK: - Salon tools and the room
//
// Tool pictures are drawn in a 100 x 100 box with the same flat look as the rest of the app: a fill,
// one light, and an outline derived from the fill color (never black). `tip` is the point of the
// picture that does the work (the comb's teeth, the scissors' blades, the dryer's nozzle).

enum SalonTool: String, CaseIterable, Identifiable {
    case shampoo, shower, towel, comb, scissors, dryer, curler, straightener, dye, glitter, grow, clips

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .shampoo: return Color(hex: 0xFFE3EE)
        case .shower: return Color(hex: 0xDDF0FF)
        case .towel: return Color(hex: 0xE8F7EF)
        case .comb: return Color(hex: 0xDDF6F2)
        case .scissors: return Color(hex: 0xFFE9E0)
        case .dryer: return Color(hex: 0xEEE6FF)
        case .curler: return Color(hex: 0xFFE7F3)
        case .straightener: return Color(hex: 0xE6EEFF)
        case .dye: return Color(hex: 0xFFF2D9)
        case .glitter: return Color(hex: 0xFFF6CC)
        case .grow: return Color(hex: 0xF4E4FF)
        case .clips: return Color(hex: 0xFFE3EA)
        }
    }

    var tip: CGPoint {
        switch self {
        case .shampoo: return CGPoint(x: 21, y: 22)
        case .shower: return CGPoint(x: 40, y: 58)
        case .towel: return CGPoint(x: 50, y: 54)
        case .comb: return CGPoint(x: 50, y: 62)
        case .scissors: return CGPoint(x: 50, y: 20)
        case .dryer: return CGPoint(x: 8, y: 36)
        case .curler: return CGPoint(x: 36, y: 36)
        case .straightener: return CGPoint(x: 50, y: 22)
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
    static func draw(_ tool: SalonTool, dye: RGB, open: CGFloat = 0, in ctx: GraphicsContext) {
        switch tool {
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
        case .comb:
            let teal = RGB(0.36, 0.78, 0.74)
            var comb = Path()
            comb.addRoundedRect(in: CGRect(x: 10, y: 28, width: 80, height: 16), cornerSize: CGSize(width: 8, height: 8))
            var x: CGFloat = 15
            while x < 86 {
                comb.addRoundedRect(in: CGRect(x: x, y: 38, width: 4.2, height: 32), cornerSize: CGSize(width: 2, height: 2))
                x += 7.2
            }
            fo(ctx, comb, teal, 2.4)
            ctx.fill(Path(roundedRect: CGRect(x: 10, y: 28, width: 80, height: 14), cornerRadius: 7), with: .color(teal.color))
            shine(ctx, CGRect(x: 16, y: 31, width: 40, height: 4), teal)
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
            bristle.move(to: CGPoint(x: 28, y: 30))
            bristle.addQuadCurve(to: CGPoint(x: 38, y: 10), control: CGPoint(x: 26, y: 16))
            bristle.addQuadCurve(to: CGPoint(x: 50, y: 30), control: CGPoint(x: 52, y: 14))
            bristle.closeSubpath()
            fo(ctx, bristle, dye, 2.4)
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
    var open: CGFloat = 0

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.scaleBy(x: size.width / 100, y: size.height / 100)
            SalonToolArt.draw(tool, dye: dye, open: open, in: g)
        }
    }
}

// MARK: - The room

enum SalonRoom {
    /// The wall, a shelf of bottles and lamps, and a checkered floor starting at `floorY`.
    static func draw(in ctx: GraphicsContext, size: CGSize, floorY: CGFloat, center: CGFloat) {
        let wall = Path(CGRect(x: 0, y: 0, width: size.width, height: floorY))
        ctx.fill(wall, with: .linearGradient(Gradient(colors: [Color(hex: 0xFCEBFF), Color(hex: 0xF6DDF2)]),
                                             startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
        // wallpaper stripes
        var stripes = Path()
        var x: CGFloat = 0
        while x < size.width {
            stripes.addRect(CGRect(x: x, y: 0, width: 26, height: floorY))
            x += 64
        }
        ctx.fill(stripes, with: .color(Color(hex: 0xFFFFFF, alpha: 0.35)))
        // little hearts on the stripes
        var hearts = Path()
        x = 13
        var row = 0
        while x < size.width {
            var y: CGFloat = row % 2 == 0 ? 40 : 90
            while y < floorY - 200 {
                hearts.addPath(ClipPainter.heart(5).applying(CGAffineTransform(translationX: x, y: y)))
                y += 100
            }
            x += 64
            row += 1
        }
        ctx.fill(hearts, with: .color(Color(hex: 0xF7C6E0, alpha: 0.7)))
        // soft spotlight behind the chair
        ctx.fill(Path(ellipseIn: CGRect(x: center - 330, y: 60, width: 660, height: 620)),
                 with: .radialGradient(Gradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0)]),
                                       center: CGPoint(x: center, y: 360), startRadius: 0, endRadius: 330))
        // wainscot
        let wain = Path(CGRect(x: 0, y: floorY - 150, width: size.width, height: 150))
        ctx.fill(wain, with: .color(Color(hex: 0xE9D3F4)))
        var panels = Path()
        x = 12
        while x < size.width {
            panels.addRoundedRect(in: CGRect(x: x, y: floorY - 132, width: 96, height: 112), cornerSize: CGSize(width: 14, height: 14))
            x += 112
        }
        ctx.stroke(panels, with: .color(Color(hex: 0xD6B9E8)), lineWidth: 4)
        ctx.fill(Path(CGRect(x: 0, y: floorY - 156, width: size.width, height: 10)), with: .color(Color(hex: 0xFFFFFF, alpha: 0.8)))
        // pendant lamps
        for lx in [center - 250, center + 250] {
            var cord = Path()
            cord.move(to: CGPoint(x: lx, y: 0))
            cord.addLine(to: CGPoint(x: lx, y: 64))
            ctx.stroke(cord, with: .color(Color(hex: 0xB9A2CC)), lineWidth: 3)
            var shade = Path()
            shade.move(to: CGPoint(x: lx - 36, y: 100))
            shade.addQuadCurve(to: CGPoint(x: lx + 36, y: 100), control: CGPoint(x: lx, y: 40))
            shade.closeSubpath()
            ctx.fill(Path(ellipseIn: CGRect(x: lx - 70, y: 70, width: 140, height: 120)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF6C8, alpha: 0.7), Color(hex: 0xFFF6C8, alpha: 0)]),
                                           center: CGPoint(x: lx, y: 104), startRadius: 0, endRadius: 70))
            ctx.fill(shade, with: .color(Color(hex: 0xFFB8D6)))
            ctx.stroke(shade, with: .color(Color(hex: 0xC9789E)), lineWidth: 3)
            ctx.fill(Path(ellipseIn: CGRect(x: lx - 8, y: 96, width: 16, height: 12)), with: .color(Color(hex: 0xFFF3B0)))
        }
        // floor
        let floor = Path(CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY))
        ctx.fill(floor, with: .color(Color(hex: 0xFFF6FA)))
        var tiles = Path()
        let t: CGFloat = 44
        var ty = floorY
        var r = 0
        while ty < size.height {
            var tx: CGFloat = r % 2 == 0 ? 0 : t
            while tx < size.width {
                tiles.addRect(CGRect(x: tx, y: ty, width: t, height: t * 0.6))
                tx += t * 2
            }
            ty += t * 0.6
            r += 1
        }
        ctx.fill(tiles, with: .color(Color(hex: 0xF3D7EA)))
        ctx.fill(Path(CGRect(x: 0, y: floorY - 3, width: size.width, height: 6)), with: .color(Color(hex: 0xD9B8D8)))
    }
}
