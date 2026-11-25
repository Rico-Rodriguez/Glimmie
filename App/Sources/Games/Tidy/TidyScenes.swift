import SwiftUI

// MARK: - Tidy Up furniture
//
// Each scene is drawn in its own 760 x 500 space in two layers: `back` (behind the items: the cabinet,
// shelves, the inside of a drawer) and `front` (in front of placed items: lips of fridge-door bins, the
// crisper's glass, the cup that holds the toothbrushes, elastic bands in the pencil case). Slot positions
// in TidyLevels.swift are in the same space.

enum TidySceneArt {
    static let wood = TRGB(0xDDA56C)
    static let darkWood = TRGB(0xB77B4B)
    static let warmPlum = Color(hex: 0x3A2248)

    static func back(_ scene: TidyScene, _ ctx: GraphicsContext) {
        switch scene {
        case .fridge: fridgeBack(ctx)
        case .bookshelf: shelfUnit(ctx, x: 120, w: 520, shelves: [160, 320, 480], paint: wood, inside: TRGB(0xC98F5C))
        case .cupboard: cupboardBack(ctx)
        case .drawer: drawerBack(ctx, inside: TRGB(0xF3DDBF), cells: 3)
        case .bathroom: bathroomBack(ctx)
        case .pencilCase: pencilCaseBack(ctx)
        case .toys: toysBack(ctx)
        case .closet: closetBack(ctx)
        case .socks: socksBack(ctx)
        case .backpack: backpackBack(ctx)
        case .pantry: shelfUnit(ctx, x: 110, w: 540, shelves: [150, 320, 480], paint: TRGB(0xF4EBDD), inside: TRGB(0xE3D3BC))
        case .crate: crateBack(ctx)
        }
    }

    static func front(_ scene: TidyScene, _ ctx: GraphicsContext) {
        switch scene {
        case .fridge: fridgeFront(ctx)
        case .drawer, .socks: drawerFront(ctx)
        case .bathroom: bathroomFront(ctx)
        case .pencilCase: pencilCaseFront(ctx)
        case .backpack: backpackFront(ctx)
        case .crate: crateFront(ctx)
        default: break
        }
    }

    // MARK: Shared pieces

    static func plank(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: TRGB) {
        let r = CGRect(x: x, y: y, width: w, height: h)
        ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .linearGradient(
            Gradient(colors: [c.light.color, c.color, c.shade.color]), startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
        ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(c.line.color(0.7)), lineWidth: 2)
    }

    /// The soft shadow a shelf throws on the wall behind it.
    static func shelfShadow(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
        let r = CGRect(x: x, y: y, width: w, height: 26)
        ctx.fill(Path(r), with: .linearGradient(Gradient(colors: [warmPlum.opacity(0.16), .clear]),
                                                startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
    }

    static func box(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, radius: CGFloat = 16, line: CGFloat = 3) {
        let p = Path(roundedRect: r, cornerRadius: radius)
        ctx.fill(p, with: .linearGradient(Gradient(colors: [c.light.color, c.color, c.shade.color]),
                                          startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
        ctx.stroke(p, with: .color(c.line.color(0.8)), lineWidth: line)
    }

    static func inside(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, radius: CGFloat = 8) {
        let p = Path(roundedRect: r, cornerRadius: radius)
        ctx.fill(p, with: .linearGradient(Gradient(colors: [c.shade.color, c.color, c.light.color]),
                                          startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
        // Inner shadow along the top and sides.
        var c2 = ctx
        c2.clip(to: p)
        c2.stroke(p, with: .color(warmPlum.opacity(0.13)), lineWidth: 14)
    }

    static func shelfUnit(_ ctx: GraphicsContext, x: CGFloat, w: CGFloat, shelves: [CGFloat], paint: TRGB, inside c: TRGB) {
        box(ctx, CGRect(x: x, y: 0, width: w, height: 500), paint, radius: 12)
        inside(ctx, CGRect(x: x + 18, y: 16, width: w - 36, height: 464), c)
        // Wood grain on the back panel.
        for i in 0..<9 {
            let gx = x + 40 + CGFloat(i) * (w - 80) / 8
            TPaint.stroke(ctx, [CGPoint(x: gx, y: 20), CGPoint(x: gx + 6, y: 470)], c.shade.color(0.25), 2)
        }
        for y in shelves {
            shelfShadow(ctx, x + 18, y + 14, w - 36)
            plank(ctx, x + 10, y, w - 20, 16, paint)
        }
    }

    // MARK: Fridge

    static func fridgeBack(_ ctx: GraphicsContext) {
        let enamel = TRGB(0xF6F8FB)
        box(ctx, CGRect(x: 110, y: 0, width: 460, height: 500), enamel, radius: 28)
        let inner = CGRect(x: 130, y: 18, width: 420, height: 466)
        let p = Path(roundedRect: inner, cornerRadius: 14)
        ctx.fill(p, with: .linearGradient(Gradient(colors: [Color(hex: 0xF4FBFF), Color(hex: 0xD3E6F3)]),
                                          startPoint: CGPoint(x: 0, y: inner.minY), endPoint: CGPoint(x: 0, y: inner.maxY)))
        // The fridge light glowing at the top.
        ctx.fill(Path(ellipseIn: CGRect(x: 190, y: -40, width: 300, height: 160)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFFBE6, alpha: 0.95), .clear]), center: CGPoint(x: 340, y: 30),
                                       startRadius: 0, endRadius: 160))
        ctx.fill(Path(roundedRect: CGRect(x: 300, y: 24, width: 80, height: 10), cornerRadius: 5), with: .color(Color(hex: 0xFFF6CC)))
        ctx.stroke(p, with: .color(Color(hex: 0xA9BCCB)), lineWidth: 2.5)
        for y in [CGFloat(170), 310] {
            shelfShadow(ctx, 132, y + 8, 416)
            ctx.fill(Path(CGRect(x: 132, y: y, width: 416, height: 8)), with: .color(Color(hex: 0xE6F6FF, alpha: 0.75)))
            TPaint.stroke(ctx, [CGPoint(x: 132, y: y), CGPoint(x: 548, y: y)], .white, 2)
            TPaint.stroke(ctx, [CGPoint(x: 132, y: y + 8), CGPoint(x: 548, y: y + 8)], Color(hex: 0x9FC3DA), 2)
        }
        // The open door on the right.
        let door = TPaint.poly([CGPoint(x: 584, y: 6), CGPoint(x: 744, y: 34), CGPoint(x: 744, y: 470), CGPoint(x: 584, y: 496)])
        ctx.fill(door, with: .linearGradient(Gradient(colors: [Color(hex: 0xE7EEF5), Color(hex: 0xFFFFFF)]),
                                             startPoint: CGPoint(x: 584, y: 0), endPoint: CGPoint(x: 744, y: 0)))
        ctx.stroke(door, with: .color(Color(hex: 0xA9BCCB)), lineWidth: 2.5)
        let panel = TPaint.poly([CGPoint(x: 596, y: 24), CGPoint(x: 732, y: 46), CGPoint(x: 732, y: 456), CGPoint(x: 596, y: 478)])
        ctx.fill(panel, with: .color(Color(hex: 0xE4EFF7)))
        ctx.fill(Path(roundedRect: CGRect(x: 568, y: 180, width: 10, height: 120), cornerRadius: 5), with: .color(Color(hex: 0xC7D5E0)))
    }

    static func fridgeFront(_ ctx: GraphicsContext) {
        // Crisper drawer: frosted glass with a mint tint.
        let crisper = CGRect(x: 142, y: 428, width: 396, height: 48)
        let p = Path(roundedRect: crisper, cornerRadius: 12)
        ctx.fill(p, with: .linearGradient(Gradient(colors: [Color(hex: 0xDFF7EE, alpha: 0.55), Color(hex: 0xBFE6DA, alpha: 0.75)]),
                                          startPoint: CGPoint(x: 0, y: crisper.minY), endPoint: CGPoint(x: 0, y: crisper.maxY)))
        ctx.stroke(p, with: .color(.white.opacity(0.9)), lineWidth: 3)
        ctx.fill(Path(roundedRect: CGRect(x: 290, y: 438, width: 100, height: 12), cornerRadius: 6), with: .color(.white.opacity(0.8)))
        ctx.fill(Path(roundedRect: CGRect(x: 156, y: 433, width: 140, height: 5), cornerRadius: 3), with: .color(.white.opacity(0.6)))
        // Door bins: clear lips that hold the bottles and eggs.
        for y in [CGFloat(160), 300, 440] {
            let k = (y - 160) / 280
            let lip = TPaint.poly([CGPoint(x: 590, y: y - 30), CGPoint(x: 738, y: y - 26 - k * 4), CGPoint(x: 738, y: y + 4), CGPoint(x: 590, y: y + 6)])
            ctx.fill(lip, with: .color(Color(hex: 0xD9EEFF, alpha: 0.6)))
            ctx.stroke(lip, with: .color(.white), lineWidth: 2.5)
            TPaint.stroke(ctx, [CGPoint(x: 596, y: y - 24), CGPoint(x: 730, y: y - 21)], .white.opacity(0.9), 2)
        }
    }

    // MARK: Cupboard

    static func cupboardBack(_ ctx: GraphicsContext) {
        let paint = TRGB(0xBFE6DA)
        // Open doors on either side.
        let left = TPaint.poly([CGPoint(x: 140, y: 0), CGPoint(x: 60, y: 30), CGPoint(x: 60, y: 470), CGPoint(x: 140, y: 500)])
        let right = TPaint.poly([CGPoint(x: 620, y: 0), CGPoint(x: 700, y: 30), CGPoint(x: 700, y: 470), CGPoint(x: 620, y: 500)])
        for d in [left, right] {
            ctx.fill(d, with: .linearGradient(Gradient(colors: [paint.light.color, paint.shade.color]),
                                              startPoint: CGPoint(x: 60, y: 0), endPoint: CGPoint(x: 140, y: 0)))
            ctx.stroke(d, with: .color(paint.line.color(0.8)), lineWidth: 3)
        }
        let knobColor = TRGB(0xFFE39A)
        for kx in [CGFloat(76), 684] {
            let knob = Path(ellipseIn: CGRect(x: kx - 7, y: 243, width: 14, height: 14))
            TPaint.ball(ctx, knob, knobColor, CGRect(x: kx - 7, y: 243, width: 14, height: 14), line: 2)
            TPaint.gloss(ctx, CGRect(x: kx - 4, y: 246, width: 4, height: 3), 0.8)
        }
        box(ctx, CGRect(x: 140, y: 0, width: 480, height: 500), paint, radius: 10)
        inside(ctx, CGRect(x: 160, y: 18, width: 440, height: 462), TRGB(0xFFF8EE))
        // Scalloped shelf paper along each shelf with warm outlines and glossy highlights.
        let scallopColor = TidyPalette.c(7)
        for y in [CGFloat(240), 480] {
            shelfShadow(ctx, 160, y + 14, 440)
            plank(ctx, 150, y, 460, 16, paint)
            for i in 0..<15 {
                let x = 160 + CGFloat(i) * 29.3
                let rect = CGRect(x: x, y: y + 10, width: 29, height: 14)
                let sc = Path(ellipseIn: rect)
                ctx.fill(sc, with: .linearGradient(
                    Gradient(colors: [scallopColor.light.color, scallopColor.color]),
                    startPoint: CGPoint(x: x, y: rect.minY),
                    endPoint: CGPoint(x: x, y: rect.maxY)
                ))
                ctx.stroke(sc, with: .color(scallopColor.line.color(0.65)), lineWidth: 1.8)
                TPaint.gloss(ctx, CGRect(x: x + 7, y: y + 13, width: 9, height: 3.5), 0.65)
            }
        }
    }

    // MARK: Drawers seen from above

    static func drawerBack(_ ctx: GraphicsContext, inside c: TRGB, cells: Int) {
        box(ctx, CGRect(x: 130, y: 10, width: 500, height: 460), wood, radius: 18)
        inside(ctx, CGRect(x: 150, y: 30, width: 460, height: 420), c, radius: 10)
        let w = 450 / CGFloat(cells)
        for i in 1..<cells {
            let x = 155 + CGFloat(i) * w
            plank(ctx, x - 6, 30, 12, 420, wood)
        }
        // A felt liner dotted pattern.
        for i in 0..<cells {
            let cx = 155 + (CGFloat(i) + 0.5) * w
            for j in 0..<6 { TPaint.dot(ctx, cx, 60 + CGFloat(j) * 70, 3, c.shade.color(0.35)) }
        }
    }

    static func drawerFront(_ ctx: GraphicsContext) {
        let r = CGRect(x: 110, y: 448, width: 540, height: 52)
        box(ctx, r, wood, radius: 12)
        ctx.fill(Path(roundedRect: CGRect(x: 340, y: 464, width: 80, height: 18), cornerRadius: 9), with: .color(TRGB(0xFFE39A).color))
        ctx.stroke(Path(roundedRect: CGRect(x: 340, y: 464, width: 80, height: 18), cornerRadius: 9), with: .color(TRGB(0xFFE39A).line.color), lineWidth: 2)
    }

    static func socksBack(_ ctx: GraphicsContext) {
        box(ctx, CGRect(x: 130, y: 10, width: 500, height: 460), TRGB(0xF4D7E5), radius: 18)
        inside(ctx, CGRect(x: 150, y: 30, width: 460, height: 420), TRGB(0xFFF4F8), radius: 10)
        // A 4 x 3 grid of soft cubbies.
        for i in 1..<4 {
            let x = 140 + CGFloat(i) * 120
            plank(ctx, x - 5, 30, 10, 420, TRGB(0xF4D7E5))
        }
        for j in 1..<3 {
            let y = 30 + CGFloat(j) * 140
            plank(ctx, 150, y - 5, 460, 10, TRGB(0xF4D7E5))
        }
    }

    // MARK: Bathroom

    static func bathroomBack(_ ctx: GraphicsContext) {
        let tile = CGRect(x: 100, y: 0, width: 560, height: 500)
        ctx.fill(Path(roundedRect: tile, cornerRadius: 18), with: .color(Color(hex: 0xF4FFFC)))
        for i in 0..<9 {
            let x = tile.minX + CGFloat(i) * 70
            TPaint.stroke(ctx, [CGPoint(x: x, y: 0), CGPoint(x: x, y: 500)], Color(hex: 0xC9EEE8), 2)
        }
        for j in 0..<8 {
            let y = CGFloat(j) * 70
            TPaint.stroke(ctx, [CGPoint(x: tile.minX, y: y), CGPoint(x: tile.maxX, y: y)], Color(hex: 0xC9EEE8), 2)
        }
        // Round mirror above the shelf with warm wood frame outline & crisp glass rim.
        let mirror = CGRect(x: 300, y: 6, width: 160, height: 120)
        let mirrorFrame = mirror.insetBy(dx: -8, dy: -8)
        let framePath = Path(ellipseIn: mirrorFrame)
        ctx.fill(framePath, with: .linearGradient(
            Gradient(colors: [wood.light.color, wood.color, wood.shade.color]),
            startPoint: CGPoint(x: mirrorFrame.minX, y: mirrorFrame.minY),
            endPoint: CGPoint(x: mirrorFrame.maxX, y: mirrorFrame.maxY)
        ))
        ctx.stroke(framePath, with: .color(wood.line.color(0.85)), lineWidth: 3)
        let glassPath = Path(ellipseIn: mirror)
        ctx.fill(glassPath, with: .linearGradient(Gradient(colors: [Color(hex: 0xF2FAFF), Color(hex: 0xBFDDF2)]),
                                                 startPoint: CGPoint(x: 300, y: 6), endPoint: CGPoint(x: 460, y: 126)))
        ctx.stroke(glassPath, with: .color(Color(hex: 0x8DBAD4)), lineWidth: 2.2)
        TPaint.stroke(ctx, [CGPoint(x: 330, y: 70), CGPoint(x: 370, y: 30)], .white.opacity(0.85), 6)
        TPaint.stroke(ctx, [CGPoint(x: 352, y: 84), CGPoint(x: 380, y: 56)], .white.opacity(0.65), 4)
        TPaint.gloss(ctx, CGRect(x: 320, y: 18, width: 22, height: 9), 0.7)
        // Glass shelf.
        shelfShadow(ctx, 150, 198, 460)
        ctx.fill(Path(roundedRect: CGRect(x: 150, y: 190, width: 460, height: 10), cornerRadius: 4), with: .color(Color(hex: 0xD9F2FF, alpha: 0.9)))
        ctx.stroke(Path(roundedRect: CGRect(x: 150, y: 190, width: 460, height: 10), cornerRadius: 4), with: .color(Color(hex: 0x8FC3DA)), lineWidth: 2)
        // Counter with a sink.
        plank(ctx, 120, 480, 520, 20, TRGB(0xFBFAF7))
        let basin = CGRect(x: 300, y: 470, width: 140, height: 22)
        let basinPath = Path(ellipseIn: basin)
        ctx.fill(basinPath, with: .linearGradient(
            Gradient(colors: [Color(hex: 0xF2F8FC), Color(hex: 0xCADCE8)]),
            startPoint: CGPoint(x: basin.midX, y: basin.minY),
            endPoint: CGPoint(x: basin.midX, y: basin.maxY)
        ))
        ctx.stroke(basinPath, with: .color(Color(hex: 0x8BA6BA)), lineWidth: 2.4)
        TPaint.gloss(ctx, CGRect(x: 318, y: 473, width: 42, height: 5), 0.8)
        TPaint.dot(ctx, 370, 482, 4, Color(hex: 0x8D9BAE))
        let tap = Path(roundedRect: CGRect(x: 362, y: 432, width: 16, height: 44), cornerRadius: 6)
        TPaint.metal(ctx, tap, tap.boundingRect)
        let spout = Path(roundedRect: CGRect(x: 346, y: 430, width: 40, height: 12), cornerRadius: 6)
        TPaint.metal(ctx, spout, spout.boundingRect)
        // A little dish for the soap with warm outline & shine.
        let soapDishRect = CGRect(x: 440, y: 472, width: 80, height: 14)
        let soapDish = Path(ellipseIn: soapDishRect)
        let dishColor = TidyPalette.c(10)
        ctx.fill(soapDish, with: .linearGradient(
            Gradient(colors: [dishColor.light.color, dishColor.color, dishColor.shade.color]),
            startPoint: CGPoint(x: soapDishRect.midX, y: soapDishRect.minY),
            endPoint: CGPoint(x: soapDishRect.midX, y: soapDishRect.maxY)
        ))
        ctx.stroke(soapDish, with: .color(dishColor.line.color(0.85)), lineWidth: 2.2)
        TPaint.gloss(ctx, CGRect(x: 454, y: 474, width: 26, height: 4), 0.75)
    }

    static func bathroomFront(_ ctx: GraphicsContext) {
        let cup = TPaint.poly([CGPoint(x: 170, y: 420), CGPoint(x: 232, y: 420), CGPoint(x: 226, y: 480), CGPoint(x: 176, y: 480)])
        TPaint.tube(ctx, cup, TidyPalette.c(5).light, CGRect(x: 170, y: 420, width: 62, height: 60))
        ctx.fill(Path(ellipseIn: CGRect(x: 170, y: 414, width: 62, height: 12)), with: .color(TidyPalette.c(5).shade.color(0.6)))
        TPaint.emblem(ctx, 3, at: CGPoint(x: 201, y: 452), size: 18, color: .white)
    }

    // MARK: Pencil case

    static func pencilCaseBack(_ ctx: GraphicsContext) {
        let fabric = TRGB(0xC9B6FF)
        box(ctx, CGRect(x: 100, y: 30, width: 560, height: 440), fabric, radius: 48)
        // Zipper around the edge.
        let zip = Path(roundedRect: CGRect(x: 112, y: 42, width: 536, height: 416), cornerRadius: 40)
        ctx.stroke(zip, with: .color(Color(hex: 0x8C97A8)), style: StrokeStyle(lineWidth: 6, dash: [4, 3]))
        let pull = Path(roundedRect: CGRect(x: 640, y: 210, width: 20, height: 44), cornerRadius: 6)
        TPaint.metal(ctx, pull, pull.boundingRect)
        inside(ctx, CGRect(x: 134, y: 66, width: 492, height: 368), TRGB(0xF1EBFF), radius: 30)
    }

    static func pencilCaseFront(_ ctx: GraphicsContext) {
        // Elastic bands that hold the crayons and pencils.
        for y in [CGFloat(178), 346] {
            let band = CGRect(x: 150, y: y, width: 460, height: 18)
            ctx.fill(Path(roundedRect: band, cornerRadius: 6), with: .linearGradient(
                Gradient(colors: [TidyPalette.c(7).light.color, TidyPalette.c(7).color, TidyPalette.c(7).shade.color]),
                startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
            ctx.stroke(Path(roundedRect: band, cornerRadius: 6), with: .color(TidyPalette.c(7).line.color(0.6)), lineWidth: 2)
        }
    }

    // MARK: Toy cubbies

    static func toysBack(_ ctx: GraphicsContext) {
        let paint = TRGB(0xFBFAF7)
        box(ctx, CGRect(x: 120, y: 0, width: 520, height: 500), paint, radius: 14)
        let backs = [TRGB(0xFFD9E6), TRGB(0xDCEBFF), TRGB(0xFFF0C4), TRGB(0xD8F3EA), TRGB(0xE9DEFF), TRGB(0xFFE1CF)]
        for row in 0..<2 {
            for col in 0..<3 {
                let r = CGRect(x: 138 + CGFloat(col) * 166, y: 16 + CGFloat(row) * 240, width: 152, height: 224)
                inside(ctx, r, backs[row * 3 + col], radius: 10)
            }
        }
        for y in [CGFloat(240), 480] { shelfShadow(ctx, 136, y + 14, 488); plank(ctx, 128, y, 504, 16, paint) }
    }

    // MARK: Closet

    static func closetBack(_ ctx: GraphicsContext) {
        box(ctx, CGRect(x: 120, y: 0, width: 520, height: 500), wood, radius: 12)
        inside(ctx, CGRect(x: 138, y: 16, width: 484, height: 464), TRGB(0xFFF1E4))
        shelfShadow(ctx, 138, 124, 484)
        plank(ctx, 130, 110, 500, 14, wood)
        // The rail.
        let rail = Path(roundedRect: CGRect(x: 140, y: 136, width: 480, height: 9), cornerRadius: 4.5)
        TPaint.metal(ctx, rail, rail.boundingRect)
        shelfShadow(ctx, 138, 494, 484)
        plank(ctx, 130, 480, 500, 16, wood)
    }

    // MARK: Backpack

    static func backpackBack(_ ctx: GraphicsContext) {
        let c = TidyPalette.c(4)
        // Straps behind.
        for x in [CGFloat(250), 470] {
            let s = Path(roundedRect: CGRect(x: x, y: -10, width: 40, height: 120), cornerRadius: 18)
            ctx.fill(s, with: .color(c.shade.color))
        }
        let body = Path(roundedRect: CGRect(x: 180, y: 20, width: 400, height: 474), cornerRadius: 90)
        TPaint.body(ctx, body, c, CGRect(x: 180, y: 20, width: 400, height: 474), line: 3)
        inside(ctx, CGRect(x: 208, y: 120, width: 344, height: 350), c.mix(.white, 0.65), radius: 26)
        // The open flap folded back at the top.
        let flap = Path(roundedRect: CGRect(x: 206, y: 46, width: 348, height: 70), cornerRadius: 30)
        TPaint.body(ctx, flap, c.light, flap.boundingRect, line: 2.4)
        ctx.stroke(Path(roundedRect: CGRect(x: 216, y: 54, width: 328, height: 54), cornerRadius: 24), with: .color(.white.opacity(0.7)),
                   style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        // Side pocket on the right.
        let pocket = Path(roundedRect: CGRect(x: 578, y: 270, width: 76, height: 200), cornerRadius: 24)
        TPaint.body(ctx, pocket, c.shade, pocket.boundingRect, line: 2.4)
    }

    static func backpackFront(_ ctx: GraphicsContext) {
        let c = TidyPalette.c(4)
        let pocket = Path(roundedRect: CGRect(x: 214, y: 412, width: 332, height: 74), cornerRadius: 26)
        TPaint.body(ctx, pocket, c, pocket.boundingRect, line: 2.6)
        ctx.stroke(Path(roundedRect: CGRect(x: 224, y: 420, width: 312, height: 58), cornerRadius: 20), with: .color(.white.opacity(0.7)),
                   style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
        TPaint.emblem(ctx, 0, at: CGPoint(x: 380, y: 449), size: 30, color: TidyPalette.c(2).color)
        // Mesh over the side pocket.
        let mesh = CGRect(x: 582, y: 380, width: 68, height: 92)
        let m = Path(roundedRect: mesh, cornerRadius: 20)
        ctx.fill(m, with: .color(c.light.color(0.55)))
        var c2 = ctx
        c2.clip(to: m)
        for i in 0..<10 {
            let x = mesh.minX - 40 + CGFloat(i) * 16
            TPaint.stroke(c2, [CGPoint(x: x, y: mesh.minY), CGPoint(x: x + 60, y: mesh.maxY)], .white.opacity(0.6), 1.5)
            TPaint.stroke(c2, [CGPoint(x: x + 60, y: mesh.minY), CGPoint(x: x, y: mesh.maxY)], .white.opacity(0.6), 1.5)
        }
        ctx.stroke(m, with: .color(c.line.color(0.8)), lineWidth: 2.4)
    }

    // MARK: Fruit crate

    static func crateBack(_ ctx: GraphicsContext) {
        let slat = TRGB(0xE8BE85)
        box(ctx, CGRect(x: 130, y: 20, width: 500, height: 460), slat, radius: 12)
        inside(ctx, CGRect(x: 150, y: 40, width: 460, height: 420), TRGB(0xF6E2C2), radius: 6)
        for i in 0..<6 { TPaint.stroke(ctx, [CGPoint(x: 150, y: 40 + CGFloat(i) * 70), CGPoint(x: 610, y: 40 + CGFloat(i) * 70)], slat.shade.color(0.35), 2) }
        // Paper liners show what goes where, with crisp warm outlines and soft craft trim.
        let liners = [TRGB(0xFFD9D6), TRGB(0xFFE6C8), TRGB(0xFFDCE8), TRGB(0xFFF4C4)]
        for (i, c) in liners.enumerated() {
            let r = CGRect(x: 160 + CGFloat(i % 2) * 230, y: 50 + CGFloat(i / 2) * 210, width: 210, height: 190)
            let p = Path(roundedRect: r, cornerRadius: 14)
            ctx.fill(p, with: .linearGradient(
                Gradient(colors: [c.light.color(0.92), c.color(0.9)]),
                startPoint: CGPoint(x: r.minX, y: r.minY),
                endPoint: CGPoint(x: r.minX, y: r.maxY)
            ))
            ctx.stroke(p, with: .color(c.line.color(0.55)), lineWidth: 2)
            ctx.stroke(
                Path(roundedRect: r.insetBy(dx: 7, dy: 7), cornerRadius: 10),
                with: .color(.white.opacity(0.75)),
                style: StrokeStyle(lineWidth: 1.8, dash: [6, 5])
            )
            TPaint.gloss(ctx, CGRect(x: r.minX + 18, y: r.minY + 10, width: 64, height: 6), 0.55)
        }
        plank(ctx, 374, 40, 12, 420, slat)
        plank(ctx, 150, 244, 460, 12, slat)
    }

    static func crateFront(_ ctx: GraphicsContext) {
        let slat = TRGB(0xE8BE85)
        plank(ctx, 120, 470, 520, 24, slat)
    }

    // MARK: The room around the furniture

    /// Wall, skirting board and a wooden floor with a rug. Drawn across the whole screen.
    static func room(_ scene: TidyScene, _ ctx: GraphicsContext, size: CGSize, floorY: CGFloat) {
        let (a, b) = scene.wall
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [a.color, b.color]),
                                                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
        // Soft wallpaper dots.
        var row = 0
        var y: CGFloat = 30
        while y < floorY - 200 {
            var x: CGFloat = row % 2 == 0 ? 30 : 75
            while x < size.width {
                TPaint.dot(ctx, x, y, 5, b.shade.color(0.22))
                x += 90
            }
            y += 78
            row += 1
        }
        // A warm window light.
        ctx.fill(Path(ellipseIn: CGRect(x: size.width * 0.5 - 520, y: -260, width: 1040, height: 700)),
                 with: .radialGradient(Gradient(colors: [Color.white.opacity(0.45), .clear]), center: CGPoint(x: size.width * 0.5, y: 90),
                                       startRadius: 0, endRadius: 520))
        let floorTop = floorY - 190
        let boards = TRGB(0xE7B988)
        ctx.fill(Path(CGRect(x: 0, y: floorTop, width: size.width, height: size.height - floorTop)),
                 with: .linearGradient(Gradient(colors: [boards.shade.color, boards.color, boards.light.color]),
                                       startPoint: CGPoint(x: 0, y: floorTop), endPoint: CGPoint(x: 0, y: size.height)))
        for i in 0..<6 {
            let ly = floorTop + 18 + CGFloat(i * i) * 7
            TPaint.stroke(ctx, [CGPoint(x: 0, y: ly), CGPoint(x: size.width, y: ly)], boards.shade.color(0.35), 2)
        }
        plank(ctx, -4, floorTop - 14, size.width + 8, 16, TRGB(0xFBFAF7))
        // Rug.
        let rug = CGRect(x: size.width * 0.5 - 380, y: floorY - 54, width: 760, height: 66)
        ctx.fill(Path(ellipseIn: rug), with: .color(TidyPalette.c(7).light.color(0.8)))
        ctx.stroke(Path(ellipseIn: rug.insetBy(dx: 16, dy: 8)), with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
    }

    /// The cardboard moving box the items come out of.
    static func movingBox(_ ctx: GraphicsContext, _ r: CGRect, open: CGFloat) {
        let card = TRGB(0xD9A66F)
        // Flaps swing open.
        let a = Double(open) * 2.1
        for side in [-1.0, 1.0] {
            var c = ctx
            let hx = side < 0 ? r.minX : r.maxX
            c.translateBy(x: hx, y: r.minY)
            c.rotate(by: .radians(side < 0 ? -a : a))
            let w = r.width * 0.5
            let flap = Path(roundedRect: CGRect(x: side < 0 ? 0 : -w, y: -4, width: w, height: 10), cornerRadius: 3)
            c.fill(flap, with: .color(card.light.color))
            c.stroke(flap, with: .color(card.line.color(0.8)), lineWidth: 2)
        }
        ctx.fill(Path(CGRect(x: r.minX + 4, y: r.minY, width: r.width - 8, height: 14)), with: .color(card.deep.color))
        let body = Path(roundedRect: r, cornerRadius: 8)
        ctx.fill(body, with: .linearGradient(Gradient(colors: [card.light.color, card.color, card.shade.color]),
                                             startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
        ctx.stroke(body, with: .color(card.line.color(0.8)), lineWidth: 3)
        ctx.fill(Path(CGRect(x: r.midX - 14, y: r.minY, width: 28, height: r.height)), with: .color(TRGB(0xEFD2A6).color(0.9)))
        TPaint.emblem(ctx, 1, at: CGPoint(x: r.midX, y: r.midY + 10), size: 28, color: TidyPalette.c(7).color)
    }
}
