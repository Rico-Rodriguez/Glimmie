import SwiftUI

// MARK: - Tidy Up items
//
// Every item is drawn in code with soft gradients, a color-derived outline (never black) and a gloss
// highlight, centered on (0, 0) at its natural size (`TidyKind.size`, upright). Colors come from
// `TidyPalette`, so books, crayons, socks and blocks can be sorted by color.

/// A plain RGB color with the mixing the art needs.
struct TRGB {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    func mix(_ o: TRGB, _ t: Double) -> TRGB {
        TRGB(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    func color(_ a: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    static let white = TRGB(0xFFFFFF)
    static let ink = TRGB(0x4A2E57)
    var light: TRGB { mix(.white, 0.42) }
    var shade: TRGB { mix(.ink, 0.26) }
    var deep: TRGB { mix(.ink, 0.42) }
    var line: TRGB { mix(.ink, 0.55) }
}

enum TidyPalette {
    static let colors: [TRGB] = [
        TRGB(0xF2665F), // 0 red
        TRGB(0xFF9F4A), // 1 orange
        TRGB(0xFFD34E), // 2 yellow
        TRGB(0x72C96F), // 3 green
        TRGB(0x4CC3C0), // 4 teal
        TRGB(0x5E9BF2), // 5 blue
        TRGB(0xA77DEB), // 6 purple
        TRGB(0xFF8DC2), // 7 pink
        TRGB(0xB57D52), // 8 brown
        TRGB(0xF7F3EC), // 9 white
        TRGB(0x9FE3CF), // 10 mint
        TRGB(0xC9D2DE), // 11 silver
    ]
    static func c(_ i: Int) -> TRGB {
        let n = colors.count
        return colors[((i % n) + n) % n]
    }
}

enum TidyMaterial { case ceramic, glass, metal, wood, plush, plastic, paper, food }

enum TidyKind: String, CaseIterable, Codable {
    case plate, bowl, mug, glass, fork, spoon, knife
    case milk, juice, jam, cheese, yogurt, apple, carrot, broccoli, egg, orange, strawberry, banana, pear
    case book, plant, teddy, frame
    case toothbrush, toothpaste, soap, duck, shampoo, towel
    case crayon, pencil, eraser, ruler
    case ball, block, car, star
    case shirt, shoe, hat, sock
    case lunchbox, bottle, can, cereal, jar

    var size: CGSize {
        switch self {
        case .plate: return CGSize(width: 120, height: 20)
        case .bowl: return CGSize(width: 96, height: 44)
        case .mug: return CGSize(width: 66, height: 60)
        case .glass: return CGSize(width: 42, height: 68)
        case .fork: return CGSize(width: 22, height: 112)
        case .spoon: return CGSize(width: 26, height: 112)
        case .knife: return CGSize(width: 18, height: 112)
        case .milk: return CGSize(width: 60, height: 112)
        case .juice: return CGSize(width: 46, height: 112)
        case .jam: return CGSize(width: 52, height: 60)
        case .cheese: return CGSize(width: 72, height: 46)
        case .yogurt: return CGSize(width: 46, height: 46)
        case .apple: return CGSize(width: 54, height: 56)
        case .carrot: return CGSize(width: 26, height: 100)
        case .broccoli: return CGSize(width: 62, height: 66)
        case .egg: return CGSize(width: 32, height: 42)
        case .orange: return CGSize(width: 52, height: 52)
        case .strawberry: return CGSize(width: 36, height: 40)
        case .banana: return CGSize(width: 90, height: 40)
        case .pear: return CGSize(width: 46, height: 62)
        case .book: return CGSize(width: 34, height: 140)
        case .plant: return CGSize(width: 72, height: 96)
        case .teddy: return CGSize(width: 84, height: 92)
        case .frame: return CGSize(width: 70, height: 86)
        case .toothbrush: return CGSize(width: 18, height: 104)
        case .toothpaste: return CGSize(width: 32, height: 100)
        case .soap: return CGSize(width: 62, height: 34)
        case .duck: return CGSize(width: 66, height: 58)
        case .shampoo: return CGSize(width: 48, height: 104)
        case .towel: return CGSize(width: 120, height: 32)
        case .crayon: return CGSize(width: 22, height: 100)
        case .pencil: return CGSize(width: 16, height: 124)
        case .eraser: return CGSize(width: 46, height: 28)
        case .ruler: return CGSize(width: 26, height: 160)
        case .ball: return CGSize(width: 66, height: 66)
        case .block: return CGSize(width: 56, height: 56)
        case .car: return CGSize(width: 96, height: 56)
        case .star: return CGSize(width: 72, height: 72)
        case .shirt: return CGSize(width: 120, height: 140)
        case .shoe: return CGSize(width: 84, height: 46)
        case .hat: return CGSize(width: 96, height: 56)
        case .sock: return CGSize(width: 56, height: 56)
        case .lunchbox: return CGSize(width: 116, height: 82)
        case .bottle: return CGSize(width: 42, height: 116)
        case .can: return CGSize(width: 52, height: 66)
        case .cereal: return CGSize(width: 82, height: 124)
        case .jar: return CGSize(width: 54, height: 70)
        }
    }

    var material: TidyMaterial {
        switch self {
        case .plate, .bowl, .mug: return .ceramic
        case .glass, .jam, .jar: return .glass
        case .fork, .spoon, .knife, .can: return .metal
        case .block, .pencil, .ruler, .frame, .plant: return .wood
        case .teddy, .towel, .shirt, .sock, .star, .hat: return .plush
        case .milk, .book, .cereal: return .paper
        case .cheese, .apple, .carrot, .broccoli, .egg, .orange, .strawberry, .banana, .pear: return .food
        default: return .plastic
        }
    }

    /// The color an item gets when its slot doesn't ask for one.
    var defaultColor: Int {
        switch self {
        case .plate, .bowl: return 5
        case .mug: return 7
        case .glass: return 4
        case .fork, .spoon: return 11
        case .knife: return 6
        case .milk: return 5
        case .juice: return 1
        case .jam: return 0
        case .cheese: return 2
        case .yogurt: return 7
        case .apple: return 0
        case .egg: return 9
        case .book: return 5
        case .toothbrush: return 4
        case .toothpaste: return 5
        case .soap: return 7
        case .duck: return 2
        case .shampoo: return 6
        case .towel: return 10
        case .crayon: return 0
        case .pencil: return 2
        case .eraser: return 7
        case .ball: return 0
        case .block: return 5
        case .car: return 0
        case .star: return 2
        case .shirt: return 7
        case .shoe: return 5
        case .hat: return 2
        case .sock: return 7
        case .lunchbox: return 4
        case .bottle: return 5
        case .can: return 0
        case .cereal: return 2
        case .jar: return 7
        default: return 0
        }
    }
}

// MARK: - Paint helpers

enum TPaint {
    /// A shaded body: light top-left to shade bottom-right, then an outline in a darker shade of the same color.
    static func body(_ ctx: GraphicsContext, _ p: Path, _ c: TRGB, _ r: CGRect, line: CGFloat = 2.5) {
        let g = Gradient(stops: [
            .init(color: c.light.color, location: 0),
            .init(color: c.color, location: 0.45),
            .init(color: c.shade.color, location: 1),
        ])
        let a = CGPoint(x: r.minX, y: r.minY)
        let b = CGPoint(x: r.midX + r.width * 0.3, y: r.maxY)
        ctx.fill(p, with: .linearGradient(g, startPoint: a, endPoint: b))
        if line > 0 { ctx.stroke(p, with: .color(c.line.color), lineWidth: line) }
    }

    /// A round, soft body lit from the top left.
    static func ball(_ ctx: GraphicsContext, _ p: Path, _ c: TRGB, _ r: CGRect, line: CGFloat = 2.5) {
        let g = Gradient(stops: [
            .init(color: c.light.color, location: 0),
            .init(color: c.color, location: 0.5),
            .init(color: c.shade.color, location: 1),
        ])
        let center = CGPoint(x: r.midX - r.width * 0.22, y: r.midY - r.height * 0.25)
        let radius = max(r.width, r.height) * 0.85
        ctx.fill(p, with: .radialGradient(g, center: center, startRadius: 0, endRadius: radius))
        if line > 0 { ctx.stroke(p, with: .color(c.line.color), lineWidth: line) }
    }

    /// A cylinder-like body lit across (book spines, crayons, bottles, cans).
    static func tube(_ ctx: GraphicsContext, _ p: Path, _ c: TRGB, _ r: CGRect, line: CGFloat = 2.5) {
        let g = Gradient(stops: [
            .init(color: c.shade.color, location: 0),
            .init(color: c.light.color, location: 0.28),
            .init(color: c.color, location: 0.6),
            .init(color: c.deep.color, location: 1),
        ])
        ctx.fill(p, with: .linearGradient(g, startPoint: CGPoint(x: r.minX, y: r.midY), endPoint: CGPoint(x: r.maxX, y: r.midY)))
        if line > 0 { ctx.stroke(p, with: .color(c.line.color), lineWidth: line) }
    }

    static func metal(_ ctx: GraphicsContext, _ p: Path, _ r: CGRect) {
        let g = Gradient(stops: [
            .init(color: Color(hex: 0x8C97A8), location: 0),
            .init(color: Color(hex: 0xF4F7FB), location: 0.35),
            .init(color: Color(hex: 0xB8C2D0), location: 0.65),
            .init(color: Color(hex: 0x7E899B), location: 1),
        ])
        ctx.fill(p, with: .linearGradient(g, startPoint: CGPoint(x: r.minX, y: r.midY), endPoint: CGPoint(x: r.maxX, y: r.midY)))
        ctx.stroke(p, with: .color(Color(hex: 0x6E6A86)), lineWidth: 2)
    }

    static func gloss(_ ctx: GraphicsContext, _ r: CGRect, _ a: Double = 0.55) {
        ctx.fill(Path(ellipseIn: r), with: .color(.white.opacity(a)))
    }

    static func stroke(_ ctx: GraphicsContext, _ pts: [CGPoint], _ c: Color, _ w: CGFloat) {
        var p = Path()
        p.addLines(pts)
        ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    static func dot(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(c))
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    static func poly(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// A little shape that tells colors apart without words (star, heart, dot...).
    static func emblem(_ ctx: GraphicsContext, _ i: Int, at c: CGPoint, size s: CGFloat, color: Color) {
        let r = CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)
        switch ((i % 4) + 4) % 4 {
        case 0: ctx.fill(Twinkle().path(in: r), with: .color(color))
        case 1: ctx.fill(TidyHeart().path(in: r), with: .color(color))
        case 2: ctx.fill(Path(ellipseIn: r.insetBy(dx: s * 0.15, dy: s * 0.15)), with: .color(color))
        default: ctx.fill(TidyStar5(inner: 0.5).path(in: r), with: .color(color))
        }
    }
}

struct TidyHeart: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY + h * 0.3))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.midX + w * 0.1, y: r.minY - h * 0.05),
                   control2: CGPoint(x: r.maxX + w * 0.25, y: r.minY + h * 0.45))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY + h * 0.3), control1: CGPoint(x: r.minX - w * 0.25, y: r.minY + h * 0.45),
                   control2: CGPoint(x: r.midX - w * 0.1, y: r.minY - h * 0.05))
        p.closeSubpath()
        return p
    }
}

struct TidyStar5: Shape {
    var inner: CGFloat = 0.45
    func path(in r: CGRect) -> Path {
        var pts: [CGPoint] = []
        let R = min(r.width, r.height) / 2
        for i in 0..<10 {
            let a = -Double.pi / 2 + Double(i) * Double.pi / 5
            let rr = i % 2 == 0 ? R : R * inner
            pts.append(CGPoint(x: r.midX + CGFloat(cos(a)) * rr, y: r.midY + CGFloat(sin(a)) * rr * 1.02 + R * 0.06))
        }
        return TPaint.poly(pts)
    }
}

// MARK: - Drawing every item

enum TidyArt {
    /// Draws an item centered on (0, 0) at its natural size.
    static func draw(_ kind: TidyKind, color ci: Int, in ctx: GraphicsContext) {
        let c = TidyPalette.c(ci)
        let s = kind.size
        let r = CGRect(x: -s.width / 2, y: -s.height / 2, width: s.width, height: s.height)
        switch kind {
        case .plate: plate(ctx, r, c)
        case .bowl: bowl(ctx, r, c)
        case .mug: mug(ctx, r, c)
        case .glass: glass(ctx, r, c)
        case .fork: fork(ctx, r)
        case .spoon: spoon(ctx, r)
        case .knife: knife(ctx, r, c)
        case .milk: milk(ctx, r, c)
        case .juice: juice(ctx, r, c)
        case .jam: jam(ctx, r, c)
        case .cheese: cheese(ctx, r, c)
        case .yogurt: yogurt(ctx, r, c)
        case .apple: apple(ctx, r, c)
        case .carrot: carrot(ctx, r)
        case .broccoli: broccoli(ctx, r)
        case .egg: egg(ctx, r)
        case .orange: orange(ctx, r)
        case .strawberry: strawberry(ctx, r)
        case .banana: banana(ctx, r)
        case .pear: pear(ctx, r)
        case .book: book(ctx, r, c, ci)
        case .plant: plant(ctx, r)
        case .teddy: teddy(ctx, r, c)
        case .frame: frame(ctx, r)
        case .toothbrush: toothbrush(ctx, r, c)
        case .toothpaste: toothpaste(ctx, r, c)
        case .soap: soap(ctx, r, c)
        case .duck: duck(ctx, r, c)
        case .shampoo: shampoo(ctx, r, c)
        case .towel: towel(ctx, r, c)
        case .crayon: crayon(ctx, r, c)
        case .pencil: pencil(ctx, r, c)
        case .eraser: eraser(ctx, r, c)
        case .ruler: ruler(ctx, r)
        case .ball: ball(ctx, r, c)
        case .block: block(ctx, r, c, ci)
        case .car: car(ctx, r, c)
        case .star: star(ctx, r, c)
        case .shirt: shirt(ctx, r, c)
        case .shoe: shoe(ctx, r, c)
        case .hat: hat(ctx, r, c)
        case .sock: sock(ctx, r, c)
        case .lunchbox: lunchbox(ctx, r, c)
        case .bottle: bottle(ctx, r, c)
        case .can: can(ctx, r, c)
        case .cereal: cereal(ctx, r, c, ci)
        case .jar: jar(ctx, r, c)
        }
    }

    // MARK: Kitchen

    static func plate(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let china = TRGB(0xFBF8F4)
        let foot = Path(roundedRect: CGRect(x: r.minX + 30, y: r.maxY - 8, width: r.width - 60, height: 8), cornerRadius: 3)
        TPaint.body(ctx, foot, china, foot.boundingRect, line: 2)
        let rim = Path(ellipseIn: CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height - 4))
        TPaint.body(ctx, rim, china, r, line: 2.2)
        let band = Path(ellipseIn: CGRect(x: r.minX + 6, y: r.minY + 3, width: r.width - 12, height: r.height - 10))
        ctx.stroke(band, with: .color(c.color), lineWidth: 2.5)
        TPaint.gloss(ctx, CGRect(x: r.minX + 18, y: r.minY + 3, width: 36, height: 4), 0.8)
    }

    static func bowl(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let w = r.width, h = r.height, top = r.minY + 6
        var p = Path()
        p.move(to: TPaint.pt(-w / 2, top))
        p.addLine(to: TPaint.pt(w / 2, top))
        p.addCurve(to: TPaint.pt(w * 0.24, r.maxY - 7), control1: TPaint.pt(w / 2, h * 0.2), control2: TPaint.pt(w * 0.38, r.maxY - 7))
        p.addLine(to: TPaint.pt(w * 0.2, r.maxY))
        p.addLine(to: TPaint.pt(-w * 0.2, r.maxY))
        p.addLine(to: TPaint.pt(-w * 0.24, r.maxY - 7))
        p.addCurve(to: TPaint.pt(-w / 2, top), control1: TPaint.pt(-w * 0.38, r.maxY - 7), control2: TPaint.pt(-w / 2, h * 0.2))
        p.closeSubpath()
        TPaint.body(ctx, p, c, r)
        let inner = Path(ellipseIn: CGRect(x: r.minX + 1, y: r.minY, width: w - 2, height: 12))
        ctx.fill(inner, with: .color(c.deep.color))
        ctx.stroke(inner, with: .color(c.line.color), lineWidth: 2)
        for i in 0..<4 {
            TPaint.dot(ctx, -27 + CGFloat(i) * 18, r.minY + 22 + (i % 2 == 0 ? 0 : 3), 3.5, .white.opacity(0.85))
        }
        TPaint.gloss(ctx, CGRect(x: -w * 0.42, y: top + 6, width: 14, height: 8), 0.6)
    }

    static func mug(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let handle = Path(ellipseIn: CGRect(x: r.maxX - 30, y: r.minY + 14, width: 28, height: 30))
        ctx.stroke(handle, with: .color(c.line.color), lineWidth: 11)
        ctx.stroke(handle, with: .color(c.color), lineWidth: 6)
        let bodyR = CGRect(x: r.minX, y: r.minY, width: r.width - 14, height: r.height)
        let body = Path(roundedRect: bodyR, cornerRadius: 6)
        TPaint.tube(ctx, body, c, bodyR)
        ctx.fill(Path(ellipseIn: CGRect(x: bodyR.minX + 2, y: r.minY - 2, width: bodyR.width - 4, height: 8)), with: .color(c.deep.color))
        TPaint.emblem(ctx, 1, at: CGPoint(x: bodyR.midX, y: bodyR.midY + 4), size: 20, color: .white.opacity(0.9))
    }

    static func glass(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let p = TPaint.poly([TPaint.pt(r.minX, r.minY), TPaint.pt(r.maxX, r.minY), TPaint.pt(r.maxX - 5, r.maxY), TPaint.pt(r.minX + 5, r.maxY)])
        let water = TPaint.poly([TPaint.pt(r.minX + 3, r.minY + 26), TPaint.pt(r.maxX - 3, r.minY + 26),
                                 TPaint.pt(r.maxX - 7, r.maxY - 4), TPaint.pt(r.minX + 7, r.maxY - 4)])
        ctx.fill(p, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.55), Color(hex: 0xDDF1FF, alpha: 0.35)]),
                                          startPoint: TPaint.pt(r.minX, 0), endPoint: TPaint.pt(r.maxX, 0)))
        ctx.fill(water, with: .color(c.color(0.45)))
        ctx.fill(Path(ellipseIn: CGRect(x: r.minX + 3, y: r.minY + 22, width: r.width - 6, height: 7)), with: .color(c.light.color(0.7)))
        ctx.stroke(p, with: .color(TRGB(0x7FA9C9).color), lineWidth: 2.2)
        ctx.fill(Path(roundedRect: CGRect(x: r.minX + 7, y: r.minY + 6, width: 5, height: r.height - 16), cornerRadius: 2.5), with: .color(.white.opacity(0.85)))
    }

    static func fork(_ ctx: GraphicsContext, _ r: CGRect) {
        var p = Path()
        let top = r.minY
        p.addRoundedRect(in: CGRect(x: -11, y: top, width: 22, height: 34), cornerSize: CGSize(width: 6, height: 6))
        p.move(to: TPaint.pt(-9, top + 30))
        p.addQuadCurve(to: TPaint.pt(-4, top + 48), control: TPaint.pt(-6, top + 44))
        p.addLine(to: TPaint.pt(4, top + 48))
        p.addQuadCurve(to: TPaint.pt(9, top + 30), control: TPaint.pt(6, top + 44))
        p.addRoundedRect(in: CGRect(x: -5, y: top + 46, width: 10, height: r.maxY - top - 46), cornerSize: CGSize(width: 5, height: 5))
        for i in 0..<3 {
            p.addRect(CGRect(x: -6.5 + CGFloat(i) * 5, y: top - 1, width: 3, height: 22))
        }
        let g = Gradient(stops: [.init(color: Color(hex: 0x8C97A8), location: 0), .init(color: Color(hex: 0xF4F7FB), location: 0.4),
                                 .init(color: Color(hex: 0x9AA6B6), location: 1)])
        ctx.fill(p, with: .linearGradient(g, startPoint: TPaint.pt(-11, 0), endPoint: TPaint.pt(11, 0)), style: FillStyle(eoFill: true))
        ctx.fill(Path(roundedRect: CGRect(x: -2, y: top + 56, width: 3, height: 40), cornerRadius: 1.5), with: .color(.white.opacity(0.8)))
    }

    static func spoon(_ ctx: GraphicsContext, _ r: CGRect) {
        var p = Path()
        p.addEllipse(in: CGRect(x: -13, y: r.minY, width: 26, height: 40))
        p.addRoundedRect(in: CGRect(x: -5, y: r.minY + 36, width: 10, height: r.height - 36), cornerSize: CGSize(width: 5, height: 5))
        TPaint.metal(ctx, p, r)
        ctx.fill(Path(ellipseIn: CGRect(x: -8, y: r.minY + 6, width: 13, height: 24)), with: .color(Color(hex: 0x98A3B3, alpha: 0.6)))
        TPaint.gloss(ctx, CGRect(x: -7, y: r.minY + 7, width: 5, height: 12), 0.9)
    }

    static func knife(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        var blade = Path()
        blade.move(to: TPaint.pt(-6, r.minY + 58))
        blade.addLine(to: TPaint.pt(-6, r.minY + 10))
        blade.addQuadCurve(to: TPaint.pt(6, r.minY + 4), control: TPaint.pt(-4, r.minY - 2))
        blade.addLine(to: TPaint.pt(7, r.minY + 58))
        blade.closeSubpath()
        TPaint.metal(ctx, blade, CGRect(x: -7, y: r.minY, width: 14, height: 58))
        let h = Path(roundedRect: CGRect(x: -9, y: r.minY + 56, width: 18, height: r.height - 56), cornerRadius: 8)
        TPaint.tube(ctx, h, c, CGRect(x: -9, y: r.minY + 56, width: 18, height: r.height - 56))
        TPaint.dot(ctx, 0, r.minY + 72, 2.2, .white.opacity(0.8))
        TPaint.dot(ctx, 0, r.minY + 92, 2.2, .white.opacity(0.8))
    }

    static func milk(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let white = TRGB(0xFBFAF7)
        let fin = Path(roundedRect: CGRect(x: r.minX + 8, y: r.minY, width: r.width - 16, height: 10), cornerRadius: 2)
        TPaint.body(ctx, fin, white, fin.boundingRect, line: 2)
        let roof = TPaint.poly([TPaint.pt(r.minX, r.minY + 30), TPaint.pt(r.minX + 8, r.minY + 9), TPaint.pt(r.maxX - 8, r.minY + 9), TPaint.pt(r.maxX, r.minY + 30)])
        TPaint.body(ctx, roof, c.light, roof.boundingRect, line: 2.2)
        let bodyR = CGRect(x: r.minX, y: r.minY + 30, width: r.width, height: r.height - 30)
        let body = Path(roundedRect: bodyR, cornerRadius: 4)
        TPaint.tube(ctx, body, white, bodyR, line: 2.4)
        let band = Path(CGRect(x: bodyR.minX + 1.5, y: bodyR.minY + 34, width: bodyR.width - 3, height: 26))
        ctx.fill(band, with: .color(c.color))
        var drop = Path()
        drop.move(to: TPaint.pt(0, bodyR.minY + 12))
        drop.addQuadCurve(to: TPaint.pt(0, bodyR.minY + 30), control: TPaint.pt(12, bodyR.minY + 30))
        drop.addQuadCurve(to: TPaint.pt(0, bodyR.minY + 12), control: TPaint.pt(-12, bodyR.minY + 30))
        ctx.fill(drop, with: .color(c.color))
        TPaint.emblem(ctx, 1, at: CGPoint(x: 0, y: bodyR.minY + 47), size: 14, color: .white)
    }

    static func juice(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        var p = Path()
        let w = r.width
        p.move(to: TPaint.pt(-9, r.minY + 14))
        p.addLine(to: TPaint.pt(-9, r.minY + 24))
        p.addQuadCurve(to: TPaint.pt(-w / 2, r.minY + 46), control: TPaint.pt(-w / 2, r.minY + 28))
        p.addLine(to: TPaint.pt(-w / 2, r.maxY - 6))
        p.addQuadCurve(to: TPaint.pt(-w / 2 + 6, r.maxY), control: TPaint.pt(-w / 2, r.maxY))
        p.addLine(to: TPaint.pt(w / 2 - 6, r.maxY))
        p.addQuadCurve(to: TPaint.pt(w / 2, r.maxY - 6), control: TPaint.pt(w / 2, r.maxY))
        p.addLine(to: TPaint.pt(w / 2, r.minY + 46))
        p.addQuadCurve(to: TPaint.pt(9, r.minY + 24), control: TPaint.pt(w / 2, r.minY + 28))
        p.addLine(to: TPaint.pt(9, r.minY + 14))
        p.closeSubpath()
        TPaint.tube(ctx, p, c, r)
        let cap = Path(roundedRect: CGRect(x: -11, y: r.minY, width: 22, height: 15), cornerRadius: 3)
        TPaint.body(ctx, cap, TidyPalette.c(3), cap.boundingRect, line: 2)
        let label = Path(CGRect(x: -w / 2 + 1.5, y: r.minY + 56, width: w - 3, height: 34))
        ctx.fill(label, with: .color(.white.opacity(0.92)))
        TPaint.dot(ctx, 0, r.minY + 73, 10, c.color)
        for i in 0..<6 {
            let a = Double(i) * Double.pi / 3
            TPaint.stroke(ctx, [TPaint.pt(0, r.minY + 73), TPaint.pt(CGFloat(cos(a)) * 8, r.minY + 73 + CGFloat(sin(a)) * 8)], .white.opacity(0.8), 1.4)
        }
        ctx.fill(Path(roundedRect: CGRect(x: -w / 2 + 6, y: r.minY + 44, width: 5, height: 50), cornerRadius: 2.5), with: .color(.white.opacity(0.45)))
    }

    static func jam(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let jarR = CGRect(x: r.minX, y: r.minY + 12, width: r.width, height: r.height - 12)
        let jar = Path(roundedRect: jarR, cornerRadius: 12)
        TPaint.tube(ctx, jar, c, jarR)
        let lidR = CGRect(x: r.minX - 2, y: r.minY, width: r.width + 4, height: 16)
        let lid = Path(roundedRect: lidR, cornerRadius: 6)
        TPaint.body(ctx, lid, TRGB(0xFFFFFF).mix(c, 0.15), lidR, line: 2)
        for i in 0..<4 { TPaint.dot(ctx, r.minX + 6 + CGFloat(i) * 13.3, r.minY + 8, 3, c.color(0.8)) }
        let label = Path(roundedRect: CGRect(x: r.minX + 8, y: r.minY + 26, width: r.width - 16, height: 22), cornerRadius: 5)
        ctx.fill(label, with: .color(Color(hex: 0xFFF6E8)))
        TPaint.emblem(ctx, 1, at: CGPoint(x: 0, y: r.minY + 37), size: 13, color: c.color)
        ctx.fill(Path(roundedRect: CGRect(x: r.minX + 5, y: r.minY + 18, width: 5, height: 34), cornerRadius: 2.5), with: .color(.white.opacity(0.55)))
    }

    static func cheese(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let top = TPaint.poly([TPaint.pt(r.minX, r.maxY - 26), TPaint.pt(r.maxX - 4, r.minY), TPaint.pt(r.maxX, r.minY + 6), TPaint.pt(r.minX + 4, r.maxY - 20)])
        TPaint.body(ctx, top, c.light, top.boundingRect, line: 2)
        let front = TPaint.poly([TPaint.pt(r.minX, r.maxY - 26), TPaint.pt(r.maxX, r.minY + 6), TPaint.pt(r.maxX, r.maxY), TPaint.pt(r.minX, r.maxY)])
        TPaint.body(ctx, front, c, r, line: 2.4)
        let holes: [(CGFloat, CGFloat, CGFloat)] = [(-18, 8, 5), (6, 2, 4), (22, 12, 6), (-4, 14, 3.5), (26, -6, 3)]
        for (x, y, rr) in holes {
            ctx.fill(Path(ellipseIn: CGRect(x: x - rr, y: y - rr * 0.85, width: rr * 2, height: rr * 1.7)), with: .color(c.shade.color))
        }
    }

    static func yogurt(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let cup = TPaint.poly([TPaint.pt(r.minX, r.minY + 6), TPaint.pt(r.maxX, r.minY + 6), TPaint.pt(r.maxX - 7, r.maxY), TPaint.pt(r.minX + 7, r.maxY)])
        TPaint.tube(ctx, cup, TRGB(0xFFFDF8), r, line: 2.2)
        ctx.fill(Path(CGRect(x: r.minX + 3, y: r.minY + 18, width: r.width - 6, height: 12)), with: .color(c.color))
        TPaint.emblem(ctx, 1, at: CGPoint(x: 0, y: r.minY + 24), size: 10, color: .white)
        let lid = Path(ellipseIn: CGRect(x: r.minX - 2, y: r.minY, width: r.width + 4, height: 11))
        TPaint.body(ctx, lid, TRGB(0xDCE3EC), lid.boundingRect, line: 2)
    }

    // MARK: Food

    static func applePath(_ r: CGRect) -> Path {
        let w = r.width / 2, h = r.height / 2
        var p = Path()
        p.move(to: TPaint.pt(0, -h * 0.62))
        p.addCurve(to: TPaint.pt(w, -h * 0.15), control1: TPaint.pt(w * 0.45, -h * 1.08), control2: TPaint.pt(w, -h * 0.8))
        p.addCurve(to: TPaint.pt(0, h), control1: TPaint.pt(w, h * 0.5), control2: TPaint.pt(w * 0.5, h * 1.05))
        p.addCurve(to: TPaint.pt(-w, -h * 0.15), control1: TPaint.pt(-w * 0.5, h * 1.05), control2: TPaint.pt(-w, h * 0.5))
        p.addCurve(to: TPaint.pt(0, -h * 0.62), control1: TPaint.pt(-w, -h * 0.8), control2: TPaint.pt(-w * 0.45, -h * 1.08))
        p.closeSubpath()
        return p
    }

    static func leaf(_ ctx: GraphicsContext, at p: CGPoint, angle: Double, len: CGFloat, color: TRGB = TidyPalette.c(3)) {
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .radians(angle))
        var l = Path()
        l.move(to: .zero)
        l.addQuadCurve(to: TPaint.pt(len, 0), control: TPaint.pt(len * 0.5, -len * 0.45))
        l.addQuadCurve(to: .zero, control: TPaint.pt(len * 0.5, len * 0.45))
        TPaint.body(c, l, color, CGRect(x: 0, y: -len * 0.3, width: len, height: len * 0.6), line: 1.8)
        TPaint.stroke(c, [TPaint.pt(2, 0), TPaint.pt(len * 0.8, 0)], color.shade.color, 1.2)
    }

    static func apple(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let body = CGRect(x: r.minX, y: r.minY + 6, width: r.width, height: r.height - 6)
        var b = ctx
        b.translateBy(x: 0, y: 3)
        TPaint.ball(b, applePath(CGRect(x: -body.width / 2, y: -body.height / 2, width: body.width, height: body.height)), c,
                    CGRect(x: -body.width / 2, y: -body.height / 2, width: body.width, height: body.height))
        TPaint.stroke(ctx, [TPaint.pt(0, r.minY + 14), TPaint.pt(3, r.minY + 2)], TidyPalette.c(8).deep.color, 4)
        leaf(ctx, at: TPaint.pt(3, r.minY + 8), angle: -0.5, len: 18)
        TPaint.gloss(ctx, CGRect(x: -18, y: -8, width: 9, height: 14), 0.5)
    }

    static func carrot(_ ctx: GraphicsContext, _ r: CGRect) {
        let c = TidyPalette.c(1)
        for (a, l) in [(-2.0, 22.0), (-1.57, 26.0), (-1.1, 22.0)] {
            leaf(ctx, at: TPaint.pt(0, r.minY + 26), angle: a, len: CGFloat(l))
        }
        var p = Path()
        p.move(to: TPaint.pt(-12, r.minY + 24))
        p.addQuadCurve(to: TPaint.pt(0, r.maxY), control: TPaint.pt(-9, r.maxY - 30))
        p.addQuadCurve(to: TPaint.pt(12, r.minY + 24), control: TPaint.pt(9, r.maxY - 30))
        p.addQuadCurve(to: TPaint.pt(-12, r.minY + 24), control: TPaint.pt(0, r.minY + 18))
        TPaint.tube(ctx, p, c, CGRect(x: -12, y: r.minY + 20, width: 24, height: r.height - 20))
        for i in 0..<4 {
            let y = r.minY + 40 + CGFloat(i) * 13
            let half = 9 - CGFloat(i) * 1.6
            TPaint.stroke(ctx, [TPaint.pt(-half, y), TPaint.pt(-half + 6, y + 2)], c.deep.color, 1.6)
            TPaint.stroke(ctx, [TPaint.pt(half - 4, y + 6), TPaint.pt(half, y + 7)], c.deep.color, 1.6)
        }
    }

    static func broccoli(_ ctx: GraphicsContext, _ r: CGRect) {
        let stem = TRGB(0xA8D978)
        let s = TPaint.poly([TPaint.pt(-10, r.minY + 30), TPaint.pt(10, r.minY + 30), TPaint.pt(13, r.maxY), TPaint.pt(-13, r.maxY)])
        TPaint.tube(ctx, s, stem, CGRect(x: -13, y: r.minY + 30, width: 26, height: r.height - 30))
        let g = TRGB(0x4FA75A)
        let blobs: [(CGFloat, CGFloat, CGFloat)] = [(-18, -6, 14), (18, -6, 14), (-8, -18, 15), (10, -20, 15), (0, -4, 15)]
        for (x, y, rr) in blobs {
            let p = Path(ellipseIn: CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2))
            TPaint.ball(ctx, p, g, p.boundingRect, line: 2)
        }
        for (x, y) in [(-14.0, -12.0), (6.0, -24.0), (14.0, -10.0), (-4.0, -8.0)] {
            TPaint.dot(ctx, CGFloat(x), CGFloat(y), 2.5, g.light.color(0.8))
        }
    }

    static func egg(_ ctx: GraphicsContext, _ r: CGRect) {
        var p = Path()
        let w = r.width / 2, h = r.height / 2
        p.move(to: TPaint.pt(0, -h))
        p.addCurve(to: TPaint.pt(w, h * 0.25), control1: TPaint.pt(w * 0.6, -h), control2: TPaint.pt(w, -h * 0.25))
        p.addCurve(to: TPaint.pt(0, h), control1: TPaint.pt(w, h * 0.75), control2: TPaint.pt(w * 0.55, h))
        p.addCurve(to: TPaint.pt(-w, h * 0.25), control1: TPaint.pt(-w * 0.55, h), control2: TPaint.pt(-w, h * 0.75))
        p.addCurve(to: TPaint.pt(0, -h), control1: TPaint.pt(-w, -h * 0.25), control2: TPaint.pt(-w * 0.6, -h))
        TPaint.ball(ctx, p, TRGB(0xFFF1DC), r, line: 2)
        TPaint.gloss(ctx, CGRect(x: -9, y: -12, width: 6, height: 10), 0.85)
    }

    static func orange(_ ctx: GraphicsContext, _ r: CGRect) {
        let c = TidyPalette.c(1)
        let p = Path(ellipseIn: r.insetBy(dx: 1, dy: 1))
        TPaint.ball(ctx, p, c, r)
        for i in 0..<9 {
            let a = Double(i) * 2.4
            let d = CGFloat(8 + (i * 7) % 14)
            TPaint.dot(ctx, CGFloat(cos(a)) * d, CGFloat(sin(a)) * d, 1.3, c.shade.color(0.6))
        }
        leaf(ctx, at: TPaint.pt(0, r.minY + 3), angle: -0.4, len: 16)
        TPaint.gloss(ctx, CGRect(x: -16, y: -16, width: 10, height: 8), 0.55)
    }

    static func strawberry(_ ctx: GraphicsContext, _ r: CGRect) {
        let c = TRGB(0xF0504F)
        var p = Path()
        p.move(to: TPaint.pt(0, r.minY + 8))
        p.addCurve(to: TPaint.pt(0, r.maxY), control1: TPaint.pt(26, r.minY), control2: TPaint.pt(12, r.maxY - 6))
        p.addCurve(to: TPaint.pt(0, r.minY + 8), control1: TPaint.pt(-12, r.maxY - 6), control2: TPaint.pt(-26, r.minY))
        TPaint.ball(ctx, p, c, r)
        let xs: [CGFloat] = [-8, 0, 8, -5, 5, -9, 9, 0]
        let ys: [CGFloat] = [-4, -6, -4, 4, 4, -12, -12, 12]
        for i in 0..<8 {
            TPaint.dot(ctx, xs[i], ys[i] + 4, 1.4, TidyPalette.c(2).light.color)
        }
        for a in [-2.6, -1.57, -0.5] { leaf(ctx, at: TPaint.pt(0, r.minY + 8), angle: a + 0.0, len: 12) }
    }

    static func banana(_ ctx: GraphicsContext, _ r: CGRect) {
        let c = TidyPalette.c(2)
        var p = Path()
        p.move(to: TPaint.pt(-42, -12))
        p.addQuadCurve(to: TPaint.pt(42, -14), control: TPaint.pt(0, 46))
        p.addQuadCurve(to: TPaint.pt(-42, -12), control: TPaint.pt(0, 12))
        TPaint.body(ctx, p, c, r)
        TPaint.stroke(ctx, [TPaint.pt(-44, -12), TPaint.pt(-40, -16)], TidyPalette.c(8).deep.color, 5)
        TPaint.stroke(ctx, [TPaint.pt(42, -14), TPaint.pt(45, -18)], TidyPalette.c(8).deep.color, 4)
        var hl = Path()
        hl.move(to: TPaint.pt(-26, 0))
        hl.addQuadCurve(to: TPaint.pt(20, 2), control: TPaint.pt(-2, 18))
        ctx.stroke(hl, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    static func pear(_ ctx: GraphicsContext, _ r: CGRect) {
        let c = TRGB(0xB9D95B)
        var p = Path()
        p.move(to: TPaint.pt(0, r.minY + 8))
        p.addCurve(to: TPaint.pt(r.maxX, r.maxY - 18), control1: TPaint.pt(12, r.minY + 8), control2: TPaint.pt(r.maxX, r.minY + 30))
        p.addCurve(to: TPaint.pt(r.minX, r.maxY - 18), control1: TPaint.pt(r.maxX, r.maxY + 4), control2: TPaint.pt(r.minX, r.maxY + 4))
        p.addCurve(to: TPaint.pt(0, r.minY + 8), control1: TPaint.pt(r.minX, r.minY + 30), control2: TPaint.pt(-12, r.minY + 8))
        TPaint.ball(ctx, p, c, r)
        TPaint.stroke(ctx, [TPaint.pt(0, r.minY + 10), TPaint.pt(2, r.minY)], TidyPalette.c(8).deep.color, 3.5)
        leaf(ctx, at: TPaint.pt(2, r.minY + 5), angle: -0.3, len: 15)
        TPaint.gloss(ctx, CGRect(x: -14, y: 2, width: 8, height: 14), 0.45)
    }

    // MARK: Bedroom

    static func book(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, _ ci: Int) {
        let p = Path(roundedRect: r, cornerRadius: 5)
        TPaint.tube(ctx, p, c, r)
        let gold = TRGB(0xFFE39A).color
        for y in [r.minY + 12, r.minY + 18, r.maxY - 18, r.maxY - 12] {
            ctx.fill(Path(CGRect(x: r.minX + 2, y: y, width: r.width - 4, height: 2.5)), with: .color(gold))
        }
        ctx.fill(Path(roundedRect: CGRect(x: r.minX + 6, y: -22, width: r.width - 12, height: 44), cornerRadius: 4), with: .color(c.light.color(0.65)))
        TPaint.emblem(ctx, ci, at: .zero, size: 18, color: c.deep.color)
    }

    static func plant(_ ctx: GraphicsContext, _ r: CGRect) {
        let leaves: [(Double, CGFloat)] = [(-2.5, 40), (-2.0, 46), (-1.57, 50), (-1.15, 46), (-0.65, 40), (-1.8, 36), (-1.3, 36)]
        for (a, l) in leaves { leaf(ctx, at: TPaint.pt(0, r.maxY - 40), angle: a, len: l, color: TRGB(0x5DB86A)) }
        let pot = TRGB(0xE38B62)
        let body = TPaint.poly([TPaint.pt(-26, r.maxY - 34), TPaint.pt(26, r.maxY - 34), TPaint.pt(20, r.maxY), TPaint.pt(-20, r.maxY)])
        TPaint.tube(ctx, body, pot, CGRect(x: -26, y: r.maxY - 34, width: 52, height: 34))
        let rim = Path(roundedRect: CGRect(x: -30, y: r.maxY - 42, width: 60, height: 12), cornerRadius: 4)
        TPaint.tube(ctx, rim, pot, CGRect(x: -30, y: r.maxY - 42, width: 60, height: 12), line: 2)
        TPaint.emblem(ctx, 1, at: TPaint.pt(0, r.maxY - 16), size: 12, color: .white.opacity(0.8))
    }

    static func teddy(_ ctx: GraphicsContext, _ r: CGRect, _ c0: TRGB) {
        let c = TidyPalette.c(8)
        let light = c.light
        func blob(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: TRGB, _ line: CGFloat = 2.4) {
            let p = Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
            TPaint.ball(ctx, p, col, p.boundingRect, line: line)
        }
        blob(-26, 36, 26, 20, c); blob(26, 36, 26, 20, c)
        blob(0, 22, 56, 46, c)
        blob(0, 26, 30, 26, light, 0)
        blob(-30, 12, 18, 30, c); blob(30, 12, 18, 30, c)
        blob(-24, -38, 20, 20, c); blob(24, -38, 20, 20, c)
        blob(-24, -38, 10, 10, light, 0); blob(24, -38, 10, 10, light, 0)
        blob(0, -18, 58, 50, c)
        blob(0, -8, 24, 18, light, 0)
        TPaint.dot(ctx, -12, -22, 3.6, TRGB.ink.color)
        TPaint.dot(ctx, 12, -22, 3.6, TRGB.ink.color)
        TPaint.dot(ctx, -11, -23.5, 1.2, .white)
        TPaint.dot(ctx, 13, -23.5, 1.2, .white)
        ctx.fill(Path(ellipseIn: CGRect(x: -5, y: -13, width: 10, height: 7)), with: .color(TRGB.ink.color))
        TPaint.dot(ctx, -20, -10, 4, TidyPalette.c(7).color(0.5))
        TPaint.dot(ctx, 20, -10, 4, TidyPalette.c(7).color(0.5))
        // A bow in the item's color.
        let bow = TidyPalette.c(ci0(c0))
        let lb = TPaint.poly([TPaint.pt(0, 4), TPaint.pt(-14, -4), TPaint.pt(-14, 12)])
        let rb = TPaint.poly([TPaint.pt(0, 4), TPaint.pt(14, -4), TPaint.pt(14, 12)])
        TPaint.body(ctx, lb, bow, lb.boundingRect, line: 1.6)
        TPaint.body(ctx, rb, bow, rb.boundingRect, line: 1.6)
        TPaint.dot(ctx, 0, 4, 4, bow.shade.color)
    }
    private static func ci0(_ c: TRGB) -> Int {
        // The bow uses the teddy's palette color unless it's brown, then pink.
        for (i, p) in TidyPalette.colors.enumerated() where abs(p.r - c.r) < 0.01 && abs(p.g - c.g) < 0.01 && abs(p.b - c.b) < 0.01 {
            return i == 8 ? 7 : i
        }
        return 7
    }

    static func frame(_ ctx: GraphicsContext, _ r: CGRect) {
        let wood = TRGB(0xD79B62)
        let outer = Path(roundedRect: r, cornerRadius: 6)
        TPaint.body(ctx, outer, wood, r)
        let inner = r.insetBy(dx: 10, dy: 10)
        ctx.fill(Path(inner), with: .linearGradient(Gradient(colors: [Color(hex: 0xBFE4FF), Color(hex: 0xEAF7FF)]),
                                                    startPoint: TPaint.pt(0, inner.minY), endPoint: TPaint.pt(0, inner.maxY)))
        var hill = Path()
        hill.move(to: TPaint.pt(inner.minX, inner.maxY - 16))
        hill.addQuadCurve(to: TPaint.pt(inner.maxX, inner.maxY - 22), control: TPaint.pt(inner.midX, inner.maxY - 46))
        hill.addLine(to: TPaint.pt(inner.maxX, inner.maxY))
        hill.addLine(to: TPaint.pt(inner.minX, inner.maxY))
        hill.closeSubpath()
        ctx.fill(hill, with: .color(TidyPalette.c(3).color))
        TPaint.dot(ctx, inner.maxX - 14, inner.minY + 14, 8, TidyPalette.c(2).color)
        TPaint.emblem(ctx, 1, at: TPaint.pt(inner.minX + 16, inner.maxY - 28), size: 10, color: TidyPalette.c(7).color)
        ctx.stroke(Path(inner), with: .color(wood.line.color), lineWidth: 2)
    }

    // MARK: Bathroom

    static func toothbrush(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let bristles = Path(roundedRect: CGRect(x: -11, y: r.minY, width: 9, height: 26), cornerRadius: 2)
        ctx.fill(bristles, with: .linearGradient(Gradient(colors: [.white, Color(hex: 0xBDEBFF)]), startPoint: TPaint.pt(-11, 0), endPoint: TPaint.pt(-2, 0)))
        ctx.stroke(bristles, with: .color(Color(hex: 0x8FB7D0)), lineWidth: 1.5)
        var h = Path()
        h.addRoundedRect(in: CGRect(x: -3, y: r.minY - 2, width: 10, height: 34), cornerSize: CGSize(width: 5, height: 5))
        h.addRoundedRect(in: CGRect(x: -2, y: r.minY + 28, width: 8, height: 26), cornerSize: CGSize(width: 4, height: 4))
        h.addRoundedRect(in: CGRect(x: -4, y: r.minY + 50, width: 12, height: r.height - 50), cornerSize: CGSize(width: 6, height: 6))
        TPaint.tube(ctx, h, c, CGRect(x: -4, y: r.minY, width: 12, height: r.height), line: 2)
        ctx.fill(Path(roundedRect: CGRect(x: -1, y: r.minY + 62, width: 6, height: 30), cornerRadius: 3), with: .color(.white.opacity(0.65)))
    }

    static func toothpaste(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let cap = Path(roundedRect: CGRect(x: -10, y: r.maxY - 16, width: 20, height: 16), cornerRadius: 3)
        TPaint.tube(ctx, cap, c, cap.boundingRect, line: 2)
        let tube = TPaint.poly([TPaint.pt(-r.width / 2, r.minY + 8), TPaint.pt(r.width / 2, r.minY + 8), TPaint.pt(12, r.maxY - 16), TPaint.pt(-12, r.maxY - 16)])
        TPaint.tube(ctx, tube, TRGB(0xFBFAF7), CGRect(x: -16, y: r.minY, width: 32, height: r.height - 16))
        let crimp = Path(roundedRect: CGRect(x: -r.width / 2 - 1, y: r.minY, width: r.width + 2, height: 10), cornerRadius: 2)
        TPaint.body(ctx, crimp, TRGB(0xDDE3EA), crimp.boundingRect, line: 1.8)
        for i in 0..<5 { TPaint.stroke(ctx, [TPaint.pt(-13 + CGFloat(i) * 6.5, r.minY + 2), TPaint.pt(-13 + CGFloat(i) * 6.5, r.minY + 8)], Color(hex: 0xA9B2C0), 1) }
        let band = TPaint.poly([TPaint.pt(-15, r.minY + 30), TPaint.pt(15, r.minY + 30), TPaint.pt(14, r.minY + 56), TPaint.pt(-14, r.minY + 56)])
        ctx.fill(band, with: .color(c.color))
        TPaint.emblem(ctx, 0, at: TPaint.pt(0, r.minY + 43), size: 14, color: .white)
    }

    static func soap(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let p = Path(roundedRect: r, cornerRadius: 15)
        TPaint.ball(ctx, p, c, r)
        let inset = Path(roundedRect: r.insetBy(dx: 9, dy: 7), cornerRadius: 9)
        ctx.stroke(inset, with: .color(c.light.color(0.8)), lineWidth: 2)
        TPaint.emblem(ctx, 1, at: .zero, size: 12, color: c.light.color)
        for (x, y, rr) in [(26.0, -18.0, 6.0), (34.0, -24.0, 3.5), (18.0, -22.0, 3.0)] {
            let b = Path(ellipseIn: CGRect(x: CGFloat(x - rr), y: CGFloat(y - rr), width: CGFloat(rr * 2), height: CGFloat(rr * 2)))
            ctx.fill(b, with: .color(.white.opacity(0.35)))
            ctx.stroke(b, with: .color(Color(hex: 0x9CCBFF, alpha: 0.8)), lineWidth: 1.2)
        }
    }

    static func duck(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        var body = Path()
        body.move(to: TPaint.pt(-32, 2))
        body.addQuadCurve(to: TPaint.pt(-18, 28), control: TPaint.pt(-34, 26))
        body.addLine(to: TPaint.pt(20, 28))
        body.addQuadCurve(to: TPaint.pt(30, 0), control: TPaint.pt(34, 22))
        body.addQuadCurve(to: TPaint.pt(-32, 2), control: TPaint.pt(0, 6))
        body.closeSubpath()
        body.move(to: TPaint.pt(-36, -4))
        body.addLine(to: TPaint.pt(-30, 6))
        body.addLine(to: TPaint.pt(-22, 0))
        body.closeSubpath()
        TPaint.ball(ctx, body, c, CGRect(x: -34, y: -4, width: 66, height: 32))
        let head = Path(ellipseIn: CGRect(x: 0, y: -30, width: 32, height: 32))
        TPaint.ball(ctx, head, c, head.boundingRect)
        let beak = Path(roundedRect: CGRect(x: 24, y: -14, width: 14, height: 9), cornerRadius: 4.5)
        TPaint.body(ctx, beak, TidyPalette.c(1), beak.boundingRect, line: 1.8)
        TPaint.dot(ctx, 21, -18, 3.4, TRGB.ink.color)
        TPaint.dot(ctx, 22, -19.2, 1.1, .white)
        var wing = Path()
        wing.move(to: TPaint.pt(-12, 8))
        wing.addQuadCurve(to: TPaint.pt(12, 10), control: TPaint.pt(0, 26))
        ctx.stroke(wing, with: .color(c.shade.color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        TPaint.gloss(ctx, CGRect(x: 6, y: -26, width: 8, height: 6), 0.7)
    }

    static func shampoo(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let capR = CGRect(x: -12, y: r.minY, width: 24, height: 18)
        let bodyR = CGRect(x: r.minX, y: r.minY + 16, width: r.width, height: r.height - 16)
        let body = Path(roundedRect: bodyR, cornerRadius: 16)
        TPaint.tube(ctx, body, c, bodyR)
        let cap = Path(roundedRect: capR, cornerRadius: 5)
        TPaint.body(ctx, cap, TRGB(0xFBFAF7), capR, line: 2)
        let label = Path(roundedRect: CGRect(x: r.minX + 7, y: r.minY + 40, width: r.width - 14, height: 38), cornerRadius: 8)
        ctx.fill(label, with: .color(.white.opacity(0.9)))
        for (x, y, rr) in [(-6.0, 0.0, 7.0), (7.0, -6.0, 5.0), (4.0, 8.0, 4.0)] {
            ctx.stroke(Path(ellipseIn: CGRect(x: CGFloat(x - rr), y: r.minY + 59 + CGFloat(y - rr), width: CGFloat(rr * 2), height: CGFloat(rr * 2))),
                       with: .color(c.color), lineWidth: 2)
        }
        ctx.fill(Path(roundedRect: CGRect(x: r.minX + 6, y: r.minY + 26, width: 5, height: 60), cornerRadius: 2.5), with: .color(.white.opacity(0.4)))
    }

    static func towel(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let p = Path(roundedRect: r, cornerRadius: 10)
        TPaint.body(ctx, p, c, r)
        ctx.fill(Path(CGRect(x: r.maxX - 30, y: r.minY + 1.5, width: 9, height: r.height - 3)), with: .color(.white.opacity(0.75)))
        ctx.fill(Path(CGRect(x: r.maxX - 17, y: r.minY + 1.5, width: 4, height: r.height - 3)), with: .color(.white.opacity(0.75)))
        var fold = Path()
        fold.move(to: TPaint.pt(r.minX + 8, r.midY + 2))
        fold.addQuadCurve(to: TPaint.pt(r.maxX - 34, r.midY + 2), control: TPaint.pt(r.midX, r.midY + 6))
        ctx.stroke(fold, with: .color(c.shade.color(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        // Fluffy loops along the top edge.
        for i in 0..<10 { TPaint.dot(ctx, r.minX + 10 + CGFloat(i) * 10, r.minY + 3, 2.4, c.light.color(0.8)) }
    }

    // MARK: School

    static func crayon(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        var tip = Path()
        tip.move(to: TPaint.pt(-8, r.minY + 22))
        tip.addLine(to: TPaint.pt(-3, r.minY + 2))
        tip.addQuadCurve(to: TPaint.pt(3, r.minY + 2), control: TPaint.pt(0, r.minY - 2))
        tip.addLine(to: TPaint.pt(8, r.minY + 22))
        tip.closeSubpath()
        TPaint.tube(ctx, tip, c, CGRect(x: -8, y: r.minY, width: 16, height: 22), line: 2)
        let bodyR = CGRect(x: -r.width / 2, y: r.minY + 20, width: r.width, height: r.height - 20)
        let body = Path(roundedRect: bodyR, cornerRadius: 4)
        TPaint.tube(ctx, body, c, bodyR)
        for y in [bodyR.minY + 8, bodyR.maxY - 14] {
            ctx.fill(Path(CGRect(x: bodyR.minX + 1.5, y: y, width: bodyR.width - 3, height: 5)), with: .color(c.deep.color))
        }
        ctx.fill(Path(roundedRect: CGRect(x: bodyR.minX + 4, y: bodyR.minY + 22, width: bodyR.width - 8, height: 32), cornerRadius: 3), with: .color(c.light.color(0.7)))
        TPaint.emblem(ctx, 0, at: TPaint.pt(0, bodyR.minY + 38), size: 10, color: c.deep.color)
    }

    static func pencil(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let wood = TPaint.poly([TPaint.pt(-8, r.minY + 22), TPaint.pt(-1.5, r.minY + 3), TPaint.pt(1.5, r.minY + 3), TPaint.pt(8, r.minY + 22)])
        TPaint.body(ctx, wood, TRGB(0xF3CF9E), wood.boundingRect, line: 1.8)
        let lead = TPaint.poly([TPaint.pt(-3, r.minY + 8), TPaint.pt(0, r.minY), TPaint.pt(3, r.minY + 8)])
        ctx.fill(lead, with: .color(TRGB.ink.color))
        let bodyR = CGRect(x: -8, y: r.minY + 22, width: 16, height: r.height - 46)
        TPaint.tube(ctx, Path(bodyR), c, bodyR, line: 2)
        ctx.fill(Path(CGRect(x: -1, y: bodyR.minY, width: 2, height: bodyR.height)), with: .color(c.shade.color(0.5)))
        let ferrule = CGRect(x: -8.5, y: r.maxY - 24, width: 17, height: 10)
        TPaint.metal(ctx, Path(ferrule), ferrule)
        let eraser = CGRect(x: -8, y: r.maxY - 15, width: 16, height: 15)
        TPaint.tube(ctx, Path(roundedRect: eraser, cornerRadius: 6),
                    TidyPalette.c(7), eraser, line: 2)
    }

    static func eraser(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let p = Path(roundedRect: r, cornerRadius: 6)
        TPaint.body(ctx, p, TRGB(0xFFF2F2), r)
        let sleeveR = CGRect(x: r.minX + 14, y: r.minY, width: r.width - 14, height: r.height)
        TPaint.body(ctx, Path(roundedRect: sleeveR, cornerRadius: 6), c, sleeveR)
        TPaint.emblem(ctx, 0, at: TPaint.pt(sleeveR.midX, 0), size: 13, color: .white.opacity(0.9))
    }

    static func ruler(_ ctx: GraphicsContext, _ r: CGRect) {
        let c = TRGB(0xFFD978)
        let p = Path(roundedRect: r, cornerRadius: 4)
        TPaint.body(ctx, p, c, r)
        for i in 0..<15 {
            let y = r.minY + 10 + CGFloat(i) * 10
            let len: CGFloat = i % 5 == 0 ? 12 : 7
            TPaint.stroke(ctx, [TPaint.pt(r.minX + 2, y), TPaint.pt(r.minX + 2 + len, y)], c.line.color, 1.6)
        }
        TPaint.dot(ctx, 4, r.minY + 14, 3, c.shade.color)
    }

    // MARK: Toys

    static func ball(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let p = Path(ellipseIn: r.insetBy(dx: 1, dy: 1))
        TPaint.ball(ctx, p, c, r)
        var c2 = ctx
        c2.clip(to: p)
        var band = Path()
        band.move(to: TPaint.pt(r.minX, -6))
        band.addQuadCurve(to: TPaint.pt(r.maxX, -6), control: TPaint.pt(0, 18))
        band.addLine(to: TPaint.pt(r.maxX, 8))
        band.addQuadCurve(to: TPaint.pt(r.minX, 8), control: TPaint.pt(0, 32))
        band.closeSubpath()
        c2.fill(band, with: .color(.white.opacity(0.9)))
        TPaint.emblem(ctx, 0, at: TPaint.pt(0, -14), size: 16, color: .white.opacity(0.95))
        TPaint.gloss(ctx, CGRect(x: -22, y: -24, width: 14, height: 10), 0.6)
    }

    static func block(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, _ ci: Int) {
        let p = Path(roundedRect: r, cornerRadius: 9)
        TPaint.body(ctx, p, c, r, line: 2.6)
        let inner = r.insetBy(dx: 8, dy: 8)
        ctx.fill(Path(roundedRect: inner, cornerRadius: 6), with: .color(c.light.color(0.55)))
        ctx.stroke(Path(roundedRect: inner, cornerRadius: 6), with: .color(c.shade.color(0.6)), lineWidth: 2)
        TPaint.emblem(ctx, ci, at: .zero, size: 26, color: .white)
    }

    static func car(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        var body = Path()
        body.move(to: TPaint.pt(-46, 14))
        body.addLine(to: TPaint.pt(-46, -2))
        body.addQuadCurve(to: TPaint.pt(-34, -8), control: TPaint.pt(-46, -8))
        body.addLine(to: TPaint.pt(-20, -8))
        body.addQuadCurve(to: TPaint.pt(-4, -26), control: TPaint.pt(-14, -26))
        body.addLine(to: TPaint.pt(16, -26))
        body.addQuadCurve(to: TPaint.pt(30, -8), control: TPaint.pt(24, -26))
        body.addLine(to: TPaint.pt(40, -6))
        body.addQuadCurve(to: TPaint.pt(48, 6), control: TPaint.pt(48, -4))
        body.addLine(to: TPaint.pt(48, 14))
        body.closeSubpath()
        TPaint.body(ctx, body, c, CGRect(x: -48, y: -26, width: 96, height: 40))
        let win = TPaint.poly([TPaint.pt(-12, -10), TPaint.pt(-2, -21), TPaint.pt(5, -21), TPaint.pt(5, -10)])
        let win2 = TPaint.poly([TPaint.pt(10, -10), TPaint.pt(10, -21), TPaint.pt(15, -21), TPaint.pt(24, -10)])
        for w in [win, win2] {
            ctx.fill(w, with: .linearGradient(Gradient(colors: [Color(hex: 0xE6F6FF), Color(hex: 0x9CCBFF)]), startPoint: TPaint.pt(0, -21), endPoint: TPaint.pt(0, -10)))
        }
        TPaint.dot(ctx, 44, 2, 3.5, TidyPalette.c(2).light.color)
        for x in [-28.0, 28.0] {
            let wheel = Path(ellipseIn: CGRect(x: CGFloat(x) - 13, y: 2, width: 26, height: 26))
            ctx.fill(wheel, with: .color(Color(hex: 0x4F4560)))
            ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(x) - 6, y: 9, width: 12, height: 12)), with: .color(Color(hex: 0xDCE3EC)))
        }
        TPaint.gloss(ctx, CGRect(x: -38, y: -5, width: 20, height: 4), 0.6)
    }

    static func star(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let p = TidyStar5(inner: 0.52).path(in: r)
        TPaint.ball(ctx, p, c, r, line: 2.6)
        TPaint.dot(ctx, -9, 0, 3.4, TRGB.ink.color)
        TPaint.dot(ctx, 9, 0, 3.4, TRGB.ink.color)
        var m = Path()
        m.move(to: TPaint.pt(-5, 8))
        m.addQuadCurve(to: TPaint.pt(5, 8), control: TPaint.pt(0, 13))
        ctx.stroke(m, with: .color(TRGB.ink.color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        TPaint.dot(ctx, -16, 7, 4, TidyPalette.c(7).color(0.55))
        TPaint.dot(ctx, 16, 7, 4, TidyPalette.c(7).color(0.55))
    }

    // MARK: Clothes

    static func shirt(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let top = r.minY
        // Hanger hook and bar.
        var hook = Path()
        hook.move(to: TPaint.pt(0, top + 22))
        hook.addLine(to: TPaint.pt(0, top + 12))
        hook.addCurve(to: TPaint.pt(-8, top + 4), control1: TPaint.pt(0, top + 4), control2: TPaint.pt(-6, top))
        ctx.stroke(hook, with: .color(Color(hex: 0x8C97A8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        let bar = TPaint.poly([TPaint.pt(0, top + 20), TPaint.pt(52, top + 40), TPaint.pt(-52, top + 40)])
        ctx.stroke(bar, with: .color(TRGB(0xD79B62).color), style: StrokeStyle(lineWidth: 5, lineJoin: .round))
        var s = Path()
        s.move(to: TPaint.pt(-16, top + 30))
        s.addLine(to: TPaint.pt(-50, top + 42))
        s.addLine(to: TPaint.pt(-60, top + 76))
        s.addLine(to: TPaint.pt(-40, top + 82))
        s.addLine(to: TPaint.pt(-36, top + 70))
        s.addLine(to: TPaint.pt(-36, r.maxY))
        s.addLine(to: TPaint.pt(36, r.maxY))
        s.addLine(to: TPaint.pt(36, top + 70))
        s.addLine(to: TPaint.pt(40, top + 82))
        s.addLine(to: TPaint.pt(60, top + 76))
        s.addLine(to: TPaint.pt(50, top + 42))
        s.addLine(to: TPaint.pt(16, top + 30))
        s.addQuadCurve(to: TPaint.pt(-16, top + 30), control: TPaint.pt(0, top + 46))
        s.closeSubpath()
        TPaint.body(ctx, s, c, CGRect(x: -60, y: top + 30, width: 120, height: r.height - 30))
        var collar = Path()
        collar.move(to: TPaint.pt(-16, top + 30))
        collar.addQuadCurve(to: TPaint.pt(16, top + 30), control: TPaint.pt(0, top + 46))
        ctx.stroke(collar, with: .color(c.light.color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        TPaint.emblem(ctx, 1, at: TPaint.pt(0, top + 84), size: 26, color: .white.opacity(0.9))
        for y in [r.maxY - 12, r.maxY - 20] {
            ctx.fill(Path(CGRect(x: -34.5, y: y, width: 69, height: 3)), with: .color(c.shade.color(0.55)))
        }
    }

    static func shoe(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        var up = Path()
        up.move(to: TPaint.pt(-40, 12))
        up.addLine(to: TPaint.pt(-38, -14))
        up.addQuadCurve(to: TPaint.pt(-22, -22), control: TPaint.pt(-36, -23))
        up.addLine(to: TPaint.pt(-6, -20))
        up.addQuadCurve(to: TPaint.pt(16, -4), control: TPaint.pt(2, -6))
        up.addQuadCurve(to: TPaint.pt(42, 6), control: TPaint.pt(40, -4))
        up.addLine(to: TPaint.pt(42, 12))
        up.closeSubpath()
        TPaint.body(ctx, up, c, CGRect(x: -40, y: -22, width: 82, height: 34))
        let sole = Path(roundedRect: CGRect(x: -42, y: 10, width: 84, height: 12), cornerRadius: 6)
        TPaint.body(ctx, sole, TRGB(0xFBFAF7), sole.boundingRect, line: 2)
        for i in 0..<3 {
            let x = -8 + CGFloat(i) * 8
            TPaint.stroke(ctx, [TPaint.pt(x - 4, -12 + CGFloat(i) * 3), TPaint.pt(x + 4, -16 + CGFloat(i) * 4)], .white, 2.6)
        }
        TPaint.emblem(ctx, 0, at: TPaint.pt(-24, -2), size: 14, color: .white.opacity(0.9))
    }

    static func hat(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let brim = Path(ellipseIn: CGRect(x: r.minX, y: r.maxY - 18, width: r.width, height: 18))
        TPaint.body(ctx, brim, c, brim.boundingRect)
        var crown = Path()
        crown.move(to: TPaint.pt(-30, r.maxY - 10))
        crown.addCurve(to: TPaint.pt(30, r.maxY - 10), control1: TPaint.pt(-32, r.minY - 8), control2: TPaint.pt(32, r.minY - 8))
        crown.closeSubpath()
        TPaint.ball(ctx, crown, c, CGRect(x: -30, y: r.minY, width: 60, height: r.height - 10))
        let band = Path(roundedRect: CGRect(x: -30, y: r.maxY - 22, width: 60, height: 10), cornerRadius: 3)
        ctx.fill(band, with: .color(TidyPalette.c(7).color))
        TPaint.emblem(ctx, 3, at: TPaint.pt(18, r.maxY - 18), size: 16, color: .white)
    }

    static func sock(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let p = Path(ellipseIn: r.insetBy(dx: 1, dy: 1))
        TPaint.ball(ctx, p, c, r)
        var c2 = ctx
        c2.clip(to: p)
        for k in 0..<3 {
            let off = CGFloat(k) * 16 - 16
            var s = Path()
            s.move(to: TPaint.pt(r.minX, off - 4))
            s.addQuadCurve(to: TPaint.pt(r.maxX, off + 4), control: TPaint.pt(0, off + 14))
            c2.stroke(s, with: .color(.white.opacity(0.75)), lineWidth: 5)
        }
        let cuff = Path(roundedRect: CGRect(x: -14, y: -22, width: 28, height: 14), cornerRadius: 6)
        TPaint.body(ctx, cuff, c.light, cuff.boundingRect, line: 1.8)
        TPaint.gloss(ctx, CGRect(x: -18, y: -6, width: 8, height: 6), 0.5)
    }

    // MARK: Backpack and pantry

    static func lunchbox(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        var handle = Path()
        handle.move(to: TPaint.pt(-22, r.minY + 16))
        handle.addQuadCurve(to: TPaint.pt(22, r.minY + 16), control: TPaint.pt(0, r.minY - 14))
        ctx.stroke(handle, with: .color(c.line.color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        ctx.stroke(handle, with: .color(c.shade.color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        let bodyR = CGRect(x: r.minX, y: r.minY + 12, width: r.width, height: r.height - 12)
        TPaint.body(ctx, Path(roundedRect: bodyR, cornerRadius: 14), c, bodyR)
        ctx.fill(Path(CGRect(x: bodyR.minX + 1.5, y: bodyR.minY + 20, width: bodyR.width - 3, height: 4)), with: .color(c.shade.color))
        let latch = Path(roundedRect: CGRect(x: -8, y: bodyR.minY + 14, width: 16, height: 14), cornerRadius: 3)
        TPaint.metal(ctx, latch, latch.boundingRect)
        TPaint.emblem(ctx, 0, at: TPaint.pt(-24, bodyR.minY + 46), size: 22, color: TidyPalette.c(2).color)
        TPaint.emblem(ctx, 1, at: TPaint.pt(20, bodyR.minY + 48), size: 18, color: .white.opacity(0.9))
    }

    static func bottle(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let capR = CGRect(x: -13, y: r.minY, width: 26, height: 20)
        TPaint.tube(ctx, Path(roundedRect: capR, cornerRadius: 6), TRGB(0xFBFAF7), capR, line: 2)
        let bodyR = CGRect(x: r.minX, y: r.minY + 18, width: r.width, height: r.height - 18)
        let body = Path(roundedRect: bodyR, cornerRadius: 12)
        TPaint.tube(ctx, body, c, bodyR)
        let win = CGRect(x: -9, y: bodyR.minY + 18, width: 18, height: 56)
        ctx.fill(Path(roundedRect: win, cornerRadius: 9), with: .color(Color(hex: 0xEAF7FF)))
        ctx.fill(Path(roundedRect: CGRect(x: win.minX, y: win.minY + 22, width: win.width, height: win.height - 22), cornerRadius: 9),
                 with: .color(Color(hex: 0x9CCBFF)))
        TPaint.gloss(ctx, CGRect(x: -6, y: win.minY + 4, width: 4, height: 14), 0.9)
        TPaint.emblem(ctx, 0, at: TPaint.pt(0, bodyR.maxY - 14), size: 14, color: .white)
    }

    static func can(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let bodyR = CGRect(x: r.minX, y: r.minY + 4, width: r.width, height: r.height - 8)
        TPaint.metal(ctx, Path(roundedRect: bodyR, cornerRadius: 6), bodyR)
        let label = CGRect(x: r.minX + 1, y: r.minY + 12, width: r.width - 2, height: r.height - 24)
        TPaint.tube(ctx, Path(label), c, label, line: 0)
        ctx.fill(Path(ellipseIn: CGRect(x: -12, y: -12, width: 24, height: 24)), with: .color(.white.opacity(0.92)))
        TPaint.emblem(ctx, 1, at: .zero, size: 14, color: c.color)
        let lid = Path(ellipseIn: CGRect(x: r.minX, y: r.minY, width: r.width, height: 9))
        TPaint.metal(ctx, lid, lid.boundingRect)
    }

    static func cereal(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, _ ci: Int) {
        TPaint.body(ctx, Path(roundedRect: r, cornerRadius: 4), c, r)
        ctx.fill(Path(CGRect(x: r.minX + 1.5, y: r.minY + 1.5, width: r.width - 3, height: 22)), with: .color(.white.opacity(0.85)))
        TPaint.emblem(ctx, ci, at: TPaint.pt(0, r.minY + 12), size: 14, color: c.deep.color)
        // A bowl of cereal on the box.
        let bowlR = CGRect(x: -30, y: 14, width: 60, height: 30)
        var b = Path()
        b.move(to: TPaint.pt(bowlR.minX, bowlR.minY))
        b.addQuadCurve(to: TPaint.pt(bowlR.maxX, bowlR.minY), control: TPaint.pt(0, bowlR.maxY + 16))
        b.closeSubpath()
        for i in 0..<7 {
            let x = -22 + CGFloat(i) * 7.5
            TPaint.dot(ctx, x, bowlR.minY - 3 - CGFloat(i % 2) * 4, 6, TidyPalette.c(i % 2 == 0 ? 2 : 1).color)
        }
        TPaint.body(ctx, b, TRGB(0xFBFAF7), bowlR, line: 2)
        TPaint.emblem(ctx, 0, at: TPaint.pt(18, -20), size: 18, color: .white)
    }

    static func jar(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let bodyR = CGRect(x: r.minX, y: r.minY + 12, width: r.width, height: r.height - 12)
        let body = Path(roundedRect: bodyR, cornerRadius: 14)
        var inside = ctx
        inside.clip(to: body)
        for i in 0..<14 {
            let x = bodyR.minX + 8 + CGFloat((i * 13) % 40)
            let y = bodyR.maxY - 8 - CGFloat(i / 3) * 10
            let col = i % 3 == 0 ? c.light : (i % 3 == 1 ? c : c.shade)
            let p = Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14))
            TPaint.ball(inside, p, col, p.boundingRect, line: 1)
        }
        ctx.fill(body, with: .color(Color(hex: 0xEAF7FF, alpha: 0.25)))
        ctx.stroke(body, with: .color(TRGB(0x7FA9C9).color), lineWidth: 2.2)
        ctx.fill(Path(roundedRect: CGRect(x: bodyR.minX + 6, y: bodyR.minY + 6, width: 5, height: bodyR.height - 18), cornerRadius: 2.5), with: .color(.white.opacity(0.8)))
        let lid = CGRect(x: r.minX + 6, y: r.minY, width: r.width - 12, height: 15)
        TPaint.body(ctx, Path(roundedRect: lid, cornerRadius: 5), c, lid, line: 2)
    }
}
