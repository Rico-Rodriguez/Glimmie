import SwiftUI

// MARK: - The treasure shop's extras
//
// Things she can buy with play coins (see `Coins`) in the treasure shop on the home screen. Each one is an extra
// for a game: it shows up in that game's tray once bought. Nothing that was free before is in here, and nothing
// here is needed to play. Prices are a few customers' worth of coins (each customer pays 3 to 5).
//
// To add one: give it an entry in `Treasures.all` (id "<game id>/<name>", the same string the game checks with
// `Coins.shared.owns`), a drawing in `TreasureArt`, and make the game show it when owned.

struct Treasure: Identifiable {
    /// "<game id>/<item>", also the id `Coins` keeps once she buys it.
    let id: String
    let game: String
    let price: Int
    /// Width and height of the drawing; it is drawn standing on the middle of its bottom edge.
    let size: CGSize
    let draw: (GraphicsContext) -> Void

    var owned: Bool { Coins.shared.owns(id) }
}

enum Treasures {
    static let all: [Treasure] = [
        Treasure(id: "garden/crystal", game: "garden", price: 8, size: TreasureArt.crystalSize) { TreasureArt.crystals($0, glow: 0.4) },
        Treasure(id: "garden/rainbow", game: "garden", price: 12, size: TreasureArt.rainbowSize) { TreasureArt.rainbow($0) },
        Treasure(id: "garden/unicorn", game: "garden", price: 15, size: TreasureArt.unicornSize) { TreasureArt.unicorn($0) },
        Treasure(id: "aquarium/crystal", game: "aquarium", price: 8, size: TreasureArt.crystalSize) { TreasureArt.crystals($0, glow: 0.4, underwater: true) },
        Treasure(id: "aquarium/coral", game: "aquarium", price: 12, size: TreasureArt.coralSize) { TreasureArt.rainbowCoral($0, sway: 0) },
        Treasure(id: "aquarium/unicorn", game: "aquarium", price: 15, size: TreasureArt.unicornSize) { TreasureArt.unicorn($0, underwater: true) },
        Treasure(id: "dressup/h_moonband", game: "dressup", price: 10, size: CGSize(width: 110, height: 78)) { TreasureArt.moonBand($0) },
    ]

    static func item(_ id: String) -> Treasure? { all.first { $0.id == id } }
}

// MARK: - Drawings
//
// Flat and cute like the rest of the app: color-derived outlines (never black), one light and one shade per color.
// Every drawing stands on (0, 0) and goes up into negative y.

enum TreasureArt {
    static let pink = Theme.pink
    static let lemon = Theme.lemon
    static let mint = Theme.mint
    static let sky = Theme.sky
    static let lilac = Theme.lilac
    static let peach = Theme.peach
    static let line = StorybookArt.outline(for: 0xC9B6FF)
    static let gold = Color(hex: 0xFFCF4A)
    static let goldLine = StorybookArt.outline(for: 0xFFCF4A)

    private static func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private static func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    private static func blob(_ g: GraphicsContext, _ p: Path, _ fill: Color, _ stroke: Color, _ w: CGFloat = 3) {
        g.fill(p, with: .color(fill))
        g.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    private static func aquaBubble(_ g: GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        let rim = StorybookArt.outline(for: 0x7EDFF4, factor: 0.72)
        blob(g, oval(cx, cy, r, r), Color(hex: 0xCFF6FF, alpha: 0.72), rim, 1.8)
        g.fill(oval(cx - r * 0.32, cy - r * 0.34, r * 0.32, r * 0.24), with: .color(.white.opacity(0.9)))
    }

    static func moonBand(_ g: GraphicsContext) {
        let band = Path { p in
            p.move(to: CGPoint(x: -51, y: -12))
            p.addQuadCurve(to: CGPoint(x: 51, y: -12), control: CGPoint(x: 0, y: -94))
        }
        let moon = Path { p in
            p.move(to: CGPoint(x: 6, y: -73))
            p.addCurve(to: CGPoint(x: 23, y: -40), control1: CGPoint(x: -10, y: -55), control2: CGPoint(x: 3, y: -37))
            p.addCurve(to: CGPoint(x: 6, y: -73), control1: CGPoint(x: 8, y: -21), control2: CGPoint(x: -30, y: -53))
            p.closeSubpath()
        }
        g.stroke(band, with: .color(StorybookArt.outline(for: 0xC9B6FF)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        g.stroke(band, with: .color(lilac), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        blob(g, moon, lemon, goldLine)
    }

    // MARK: Unicorn statue

    static let unicornSize = CGSize(width: 110, height: 140)

    /// A white unicorn with a rainbow mane and a golden horn, standing on a little lilac stone (or pearl shell underwater).
    static func unicorn(_ g: GraphicsContext, underwater: Bool = false) {
        let white = Color(hex: 0xFFFDFB)
        let shade = Color(hex: 0xEDE4FF)
        let aquaLine = StorybookArt.outline(for: 0x7AD9E8)
        if underwater {
            // Scalloped mother-of-pearl shell pedestal
            var shell = Path()
            shell.move(to: CGPoint(x: -46, y: -3))
            shell.addQuadCurve(to: CGPoint(x: -42, y: -18), control: CGPoint(x: -50, y: -12))
            for i in 0..<5 {
                let x0 = -42 + CGFloat(i) * 16.8
                let xm = x0 + 8.4
                let x1 = x0 + 16.8
                shell.addQuadCurve(to: CGPoint(x: x1, y: -18), control: CGPoint(x: xm, y: -24))
            }
            shell.addQuadCurve(to: CGPoint(x: 46, y: -3), control: CGPoint(x: 50, y: -12))
            shell.addQuadCurve(to: CGPoint(x: -46, y: -3), control: CGPoint(x: 0, y: 2))
            shell.closeSubpath()
            blob(g, shell, Color(hex: 0xE2F8FF), aquaLine, 2.8)
            for rx in [-24.0, 0.0, 24.0] as [CGFloat] {
                var ridge = Path()
                ridge.move(to: CGPoint(x: rx, y: -19))
                ridge.addLine(to: CGPoint(x: rx * 0.72, y: -4))
                g.stroke(ridge, with: .color(aquaLine.opacity(0.45)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
            for px in [-37.0, 37.0] as [CGFloat] {
                blob(g, oval(px, -17, 5, 5), Color(hex: 0xFFF2F8), Color(hex: 0xD998B8), 1.8)
                g.fill(oval(px - 1.5, -18.5, 1.8, 1.4), with: .color(.white))
            }
        } else {
            let stone = Path(roundedRect: CGRect(x: -46, y: -18, width: 92, height: 18), cornerRadius: 7)
            blob(g, stone, Color(hex: 0xDCCFF7), line)
            g.fill(Path(roundedRect: CGRect(x: -40, y: -15, width: 80, height: 5), cornerRadius: 2.5), with: .color(.white.opacity(0.55)))
        }
        // tail: three soft curls at the back
        let tailCurls: [(CGFloat, CGFloat, CGFloat, Color)] = underwater
            ? [(-38, -64, 9, Color(hex: 0x76E4F0)), (-45, -51, 8, mint), (-43, -38, 7, sky)]
            : [(-38, -64, 9, lilac), (-45, -51, 8, pink), (-43, -38, 7, lemon)]
        for (x, y, r, c) in tailCurls {
            blob(g, oval(x, y, r, r), c, underwater ? aquaLine : line, 2.5)
        }
        // legs (the far pair a little darker)
        for (x, far) in [(-18.0, true), (22.0, true), (-32.0, false), (6.0, false)] {
            let leg = Path(roundedRect: CGRect(x: x, y: -52, width: 11, height: 36), cornerRadius: 5)
            blob(g, leg, far ? shade : white, line, 2.5)
            blob(g, Path(roundedRect: CGRect(x: x - 0.5, y: -24, width: 12, height: 8), cornerRadius: 3), gold, goldLine, 2)
        }
        if underwater {
            // Swept aqua sea-fin crest behind the neck mane
            var fin = Path()
            fin.move(to: CGPoint(x: 28, y: -116))
            fin.addQuadCurve(to: CGPoint(x: 4, y: -102), control: CGPoint(x: 11, y: -120))
            fin.addQuadCurve(to: CGPoint(x: -2, y: -86), control: CGPoint(x: -7, y: -96))
            fin.addQuadCurve(to: CGPoint(x: 8, y: -68), control: CGPoint(x: -6, y: -74))
            fin.addLine(to: CGPoint(x: 24, y: -76))
            fin.closeSubpath()
            blob(g, fin, Color(hex: 0x7CE6F4), aquaLine, 2.4)
            for (sx, sy, ex, ey) in [(22.0, -108.0, 9.0, -104.0), (19.0, -94.0, 4.0, -88.0), (16.0, -80.0, 7.0, -73.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                var ray = Path()
                ray.move(to: CGPoint(x: sx, y: sy))
                ray.addLine(to: CGPoint(x: ex, y: ey))
                g.stroke(ray, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
        // ear, neck and head (the body goes over the bottom of the neck)
        blob(g, poly([CGPoint(x: 47, y: -110), CGPoint(x: 55, y: -125), CGPoint(x: 57, y: -106)]), white, line, 2.5)
        let neck = poly([CGPoint(x: 12, y: -70), CGPoint(x: 26, y: -100), CGPoint(x: 42, y: -94), CGPoint(x: 30, y: -58)])
        blob(g, neck, white, line)
        blob(g, oval(40, -102, 17, 14), white, line)
        blob(g, oval(53, -95, 11, 9), Color(hex: 0xFFE6EF), Color(hex: 0xE59AB8), 2.5)
        g.fill(oval(56, -96, 1.6, 1.6), with: .color(Color(hex: 0xC4789A)))
        g.fill(neck, with: .color(white)) // hides the head's outline where it meets the neck
        g.fill(oval(36, -96, 9, 8), with: .color(white))
        // body
        blob(g, oval(-4, -60, 36, 21), white, line)
        g.fill(oval(-6, -50, 26, 7), with: .color(shade.opacity(0.8)))
        // horn: a gold cone with stripes
        let horn = poly([CGPoint(x: 39, y: -114), CGPoint(x: 52, y: -142), CGPoint(x: 48, y: -112)])
        blob(g, horn, gold, goldLine, 2.5)
        for k in 0..<3 {
            let t = CGFloat(k + 1) / 4
            var s = Path()
            s.move(to: CGPoint(x: 39 + 13 * t, y: -114 - 28 * t))
            s.addLine(to: CGPoint(x: 48 + 4 * t, y: -112 - 30 * t))
            g.stroke(s, with: .color(goldLine.opacity(0.7)), lineWidth: 1.6)
        }
        // mane down the neck
        let mane: [(CGFloat, CGFloat, CGFloat, Color)] = underwater
            ? [(30, -112, 8, Color(hex: 0x7CE6F4)), (24, -100, 8, mint), (20, -88, 8, sky),
               (16, -76, 7.5, lilac), (13, -65, 7, pink)]
            : [(30, -112, 8, pink), (24, -100, 8, peach), (20, -88, 8, lemon),
               (16, -76, 7.5, mint), (13, -65, 7, sky)]
        for (x, y, r, c) in mane {
            blob(g, oval(x, y, r, r), c, underwater ? aquaLine : line, 2.2)
            g.fill(oval(x - r * 0.3, y - r * 0.35, r * 0.35, r * 0.25), with: .color(.white.opacity(0.6)))
        }
        // face: a closed happy eye and a blush
        var eye = Path()
        eye.move(to: CGPoint(x: 39, y: -103))
        eye.addQuadCurve(to: CGPoint(x: 47, y: -103), control: CGPoint(x: 43, y: -107))
        g.stroke(eye, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        g.fill(oval(45, -96, 4.5, 3), with: .color(pink.opacity(0.55)))
        if underwater {
            aquaBubble(g, cx: -40, cy: -98, r: 5)
            aquaBubble(g, cx: -28, cy: -114, r: 3.4)
        }
    }

    // MARK: Rainbow arch

    static let rainbowSize = CGSize(width: 150, height: 86)

    /// A rainbow that stands on two fluffy clouds.
    static func rainbow(_ g: GraphicsContext) {
        let colors = [Color(hex: 0xFF7F9E), Color(hex: 0xFFAE6B), lemon,
                      Color(hex: 0x8FE0A4), sky, lilac]
        let band: CGFloat = 7.5
        let outer: CGFloat = 62
        // a soft outline behind all the bands
        var back = Path()
        back.addArc(center: CGPoint(x: 0, y: -12), radius: outer - band * 3, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        g.stroke(back, with: .color(line.opacity(0.7)), style: StrokeStyle(lineWidth: band * 6 + 4, lineCap: .butt))
        for (k, c) in colors.enumerated() {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: -12), radius: outer - band * (CGFloat(k) + 0.5),
                       startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            g.stroke(arc, with: .color(c), style: StrokeStyle(lineWidth: band + 0.5, lineCap: .butt))
        }
        // a shine along the top
        var shine = Path()
        shine.addArc(center: CGPoint(x: 0, y: -12), radius: outer - 3, startAngle: .degrees(205), endAngle: .degrees(250), clockwise: false)
        g.stroke(shine, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        // the clouds at its feet
        for side in [-1.0, 1.0] as [CGFloat] {
            let cx = side * (outer - band * 3)
            var cloud = Path()
            for (dx, dy, r) in [(-14.0, -9.0, 11.0), (0.0, -15.0, 14.0), (14.0, -9.0, 11.0), (0.0, -6.0, 12.0)] as [(CGFloat, CGFloat, CGFloat)] {
                cloud.addEllipse(in: CGRect(x: cx + dx - r, y: dy - r, width: r * 2, height: r * 2))
            }
            g.stroke(cloud, with: .color(Color(hex: 0xBFD3F2)), lineWidth: 5)
            g.fill(cloud, with: .color(.white))
            g.fill(oval(cx - 4, -20, 6, 3.5), with: .color(Color(hex: 0xEEF4FF)))
        }
    }

    // MARK: Crystals

    static let crystalSize = CGSize(width: 84, height: 76)

    /// A cluster of three glowing crystals. `glow` 0...1 lights them up (at night).
    static func crystals(_ g: GraphicsContext, glow: CGFloat, underwater: Bool = false) {
        if glow > 0.01 {
            let halo = underwater ? Color(hex: 0xB8F3FF) : Color(hex: 0xFFD6F2)
            g.fill(oval(0, -34, 54, 44), with: .radialGradient(
                Gradient(colors: [halo.opacity(Double(glow) * 0.8), halo.opacity(0)]),
                center: CGPoint(x: 0, y: -34), startRadius: 4, endRadius: 54))
        }
        func crystal(_ x: CGFloat, _ w: CGFloat, _ h: CGFloat, _ tilt: Double, _ c: Color, _ edge: Color) {
            var p = g
            p.translateBy(x: x, y: -2)
            p.rotate(by: .degrees(tilt))
            let body = poly([CGPoint(x: -w / 2, y: 0), CGPoint(x: -w / 2, y: -h * 0.7), CGPoint(x: 0, y: -h),
                             CGPoint(x: w / 2, y: -h * 0.7), CGPoint(x: w / 2, y: 0)])
            p.fill(body, with: .color(c))
            // the light facet on the left, the shaded one on the right
            p.fill(poly([CGPoint(x: -w / 2, y: 0), CGPoint(x: -w / 2, y: -h * 0.7), CGPoint(x: 0, y: -h), CGPoint(x: -w * 0.1, y: 0)]),
                   with: .color(.white.opacity(0.45)))
            p.fill(poly([CGPoint(x: w * 0.18, y: 0), CGPoint(x: w * 0.18, y: -h * 0.78), CGPoint(x: w / 2, y: -h * 0.7), CGPoint(x: w / 2, y: 0)]),
                   with: .color(edge.opacity(0.25)))
            p.stroke(body, with: .color(edge), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
        if underwater {
            crystal(-20, 20, 42, -18, mint, StorybookArt.outline(for: 0x9FE3CF))
            crystal(22, 18, 38, 20, sky, StorybookArt.outline(for: 0x9CCBFF))
            crystal(0, 24, 66, 0, Color(hex: 0x7CE6F4), StorybookArt.outline(for: 0x7CE6F4))
            blob(g, oval(0, -3, 34, 7), Color(hex: 0xA8DCE8), StorybookArt.outline(for: 0xA8DCE8), 2.5)
            for (bx, by, br) in [(-33.0, -14.0, 5.2), (-25.0, -30.0, 3.6), (32.0, -16.0, 5.6),
                                 (25.0, -34.0, 3.8), (-12.0, -11.0, 3.2), (14.0, -10.0, 3.4)] as [(CGFloat, CGFloat, CGFloat)] {
                aquaBubble(g, cx: bx, cy: by, r: br)
            }
        } else {
            crystal(-20, 20, 42, -18, lilac, StorybookArt.outline(for: 0xC9B6FF))
            crystal(22, 18, 38, 20, sky, StorybookArt.outline(for: 0x9CCBFF))
            crystal(0, 24, 66, 0, pink, StorybookArt.outline(for: 0xFF8FB8))
            blob(g, oval(0, -3, 34, 7), Color(hex: 0xBDB1D6), StorybookArt.outline(for: 0xBDB1D6), 2.5)
        }
        // sparkles
        for (x, y, r) in [(-30.0, -52.0, 5.0), (30.0, -58.0, 4.0), (6.0, -74.0, 4.5)] as [(CGFloat, CGFloat, CGFloat)] {
            let s = Twinkle().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            g.fill(s, with: .color(Color(hex: 0xFFF4B0).opacity(0.6 + 0.4 * Double(glow))))
        }
    }

    // MARK: Rainbow coral

    static let coralSize = CGSize(width: 116, height: 104)

    /// A branching coral, each branch its own rainbow color. `sway` bends the tips with the water.
    static func rainbowCoral(_ g: GraphicsContext, sway: CGFloat) {
        let branches: [(CGFloat, CGFloat, CGFloat, Color, Color)] = [
            // angle (deg from straight up), length, start x, color, outline
            (-58, 58, -10, pink, StorybookArt.outline(for: 0xFF8FB8)),
            (-28, 80, -5, peach, StorybookArt.outline(for: 0xFFC09F)),
            (0, 96, 0, lemon, StorybookArt.outline(for: 0xFFE38A)),
            (28, 82, 5, mint, StorybookArt.outline(for: 0x9FE3CF)),
            (56, 60, 10, sky, StorybookArt.outline(for: 0x9CCBFF)),
        ]
        for (i, b) in branches.enumerated() {
            let a = (b.0 + sway * 12 * (CGFloat(i % 2) * 0.6 + 0.7)) * .pi / 180
            let start = CGPoint(x: b.2, y: -4)
            let mid = CGPoint(x: start.x + sin(a) * b.1 * 0.45, y: start.y - cos(a) * b.1 * 0.5)
            let tip = CGPoint(x: start.x + sin(a * 1.12) * b.1, y: start.y - cos(a * 1.12) * b.1)
            var p = Path()
            p.move(to: start)
            p.addQuadCurve(to: tip, control: mid)
            // a little side twig halfway up
            let twigA = a + (i % 2 == 0 ? -0.7 : 0.7)
            var twig = Path()
            twig.move(to: mid)
            twig.addLine(to: CGPoint(x: mid.x + sin(twigA) * b.1 * 0.3, y: mid.y - cos(twigA) * b.1 * 0.3))
            for (path, w) in [(p, CGFloat(13)), (twig, CGFloat(9))] {
                g.stroke(path, with: .color(b.4), style: StrokeStyle(lineWidth: w + 4, lineCap: .round))
                g.stroke(path, with: .color(b.3), style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
            g.fill(oval(tip.x - 2, tip.y + 1, 3, 3), with: .color(.white.opacity(0.65)))
        }
        blob(g, oval(0, -3, 30, 7), Color(hex: 0xF2E3C9), StorybookArt.outline(for: 0xF2E3C9), 2.5)
    }
}

// MARK: - Drawing one treasure in a square

/// A treasure drawn centered in its frame, scaled to fit.
struct TreasureArtView: View {
    let item: Treasure

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let s = min(size.width / item.size.width, size.height / item.size.height) * 0.92
            g.translateBy(x: size.width / 2, y: size.height / 2 + item.size.height * s / 2)
            g.scaleBy(x: s, y: s)
            item.draw(g)
        }
    }
}
