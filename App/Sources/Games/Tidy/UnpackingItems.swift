import SwiftUI

// MARK: - Unpacking Item Vector Art

enum UnpackingItemArt {
    /// Draws any Unpacking item centered on `(0, 0)` at its `kind.size`.
    static func draw(
        _ kind: UnpackingItemKind,
        color ci: Int,
        in ctx: GraphicsContext,
        isLit: Bool = false,
        interactPhase: Double = 0,
        time: Double = 0
    ) {
        if let tidyKind = kind.tidyKind {
            let target = kind.size
            let natural = tidyKind.size
            let scale = min(target.width / max(1, natural.width), target.height / max(1, natural.height))
            var c = ctx
            c.scaleBy(x: scale, y: scale)
            TidyArt.draw(tidyKind, color: ci, in: c)
            return
        }

        let c = TidyPalette.c(ci)
        let s = kind.size
        let r = CGRect(x: -s.width / 2, y: -s.height / 2, width: s.width, height: s.height)

        switch kind {
        case .deskLamp:
            drawDeskLamp(ctx, r, c, isLit: isLit, time: time)
        case .hanbokDoll:
            drawHanbokDoll(ctx, r, c, interactPhase: interactPhase)
        case .jewelCompact:
            drawJewelCompact(ctx, r, c, interactPhase: interactPhase, time: time)
        case .familyPhoto:
            drawFamilyPhoto(ctx, r, c)
        case .piggyBank:
            drawPiggyBank(ctx, r, c)
        case .succulentPot:
            drawSucculentPot(ctx, r, c)
        case .alarmClock:
            drawAlarmClock(ctx, r, c, interactPhase: interactPhase, time: time)
        case .diaryBook:
            drawDiaryBook(ctx, r, c)
        case .plushBunny:
            drawPlushBunny(ctx, r, c, interactPhase: interactPhase)
        case .fairyLights:
            drawFairyLights(ctx, r, isLit: isLit, time: time)
        case .riceCooker:
            drawRiceCooker(ctx, r, c, interactPhase: interactPhase, time: time)
        case .kettle:
            drawKettle(ctx, r, c)
        case .teapot:
            drawTeapot(ctx, r, c)
        case .slippers:
            drawSlippers(ctx, r, c)
        case .artPoster:
            drawArtPoster(ctx, r, c, colorIndex: ci)
        case .flowerVase:
            drawFlowerVase(ctx, r, c)
        case .plushCat:
            drawPlushCat(ctx, r, c, interactPhase: interactPhase, time: time)
        case .musicBox:
            drawMusicBox(ctx, r, c, interactPhase: interactPhase, time: time)
        default:
            break
        }
    }

    // MARK: - 1. Desk Lamp (toggles warm glowing cone!)

    private static func drawDeskLamp(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, isLit: Bool, time: Double) {
        if isLit {
            let pulse = 0.92 + 0.08 * sin(time * 3.2)
            var cone = Path()
            cone.move(to: CGPoint(x: -16, y: r.minY + 34))
            cone.addLine(to: CGPoint(x: 24, y: r.minY + 34))
            cone.addLine(to: CGPoint(x: 54, y: r.maxY + 8))
            cone.addLine(to: CGPoint(x: -44, y: r.maxY + 8))
            cone.closeSubpath()
            ctx.fill(
                cone,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: 0xFFF3B0, alpha: 0.56 * pulse),
                        Color(hex: 0xFFE38A, alpha: 0.14 * pulse),
                        Color(hex: 0xFFE38A, alpha: 0)
                    ]),
                    startPoint: CGPoint(x: 4, y: r.minY + 34),
                    endPoint: CGPoint(x: 4, y: r.maxY + 8)
                )
            )
            let halo = Path(ellipseIn: CGRect(x: -36, y: r.minY - 6, width: 82, height: 76))
            ctx.fill(
                halo,
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFF8CC, alpha: 0.52 * pulse), .clear]),
                    center: CGPoint(x: 5, y: r.minY + 30),
                    startRadius: 4,
                    endRadius: 46
                )
            )
        }

        // Curved brass neck
        var arm = Path()
        arm.move(to: CGPoint(x: -8, y: r.maxY - 12))
        arm.addQuadCurve(to: CGPoint(x: -14, y: r.minY + 26), control: CGPoint(x: -24, y: r.midY + 6))
        arm.addQuadCurve(to: CGPoint(x: 4, y: r.minY + 12), control: CGPoint(x: -10, y: r.minY + 6))
        ctx.stroke(arm, with: .color(StorybookArt.outline(for: 0xDDA63B)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        ctx.stroke(arm, with: .color(Color(hex: 0xF5D06B)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // Rounded weighted base
        let baseRect = CGRect(x: -24, y: r.maxY - 16, width: 42, height: 16)
        let base = Path(roundedRect: baseRect, cornerRadius: 8)
        TPaint.body(ctx, base, c, baseRect, line: 2.2)
        TPaint.dot(ctx, 4, r.maxY - 8, 3.2, isLit ? Color(hex: 0xFFE36E) : c.light.color)

        // Glowing bulb peeking underneath shade
        let bulbRect = CGRect(x: -2, y: r.minY + 29, width: 15, height: 12)
        ctx.fill(Path(ellipseIn: bulbRect), with: .color(isLit ? Color(hex: 0xFFFBE0) : Color(hex: 0xE7E1D4)))
        ctx.stroke(Path(ellipseIn: bulbRect), with: .color(Color(hex: 0xD8B464)), lineWidth: 1.5)

        // Dome shade tilted slightly forward
        var shade = Path()
        shade.move(to: CGPoint(x: -6, y: r.minY + 12))
        shade.addCurve(to: CGPoint(x: 26, y: r.minY + 35), control1: CGPoint(x: 16, y: r.minY + 8), control2: CGPoint(x: 26, y: r.minY + 22))
        shade.addLine(to: CGPoint(x: -16, y: r.minY + 35))
        shade.addCurve(to: CGPoint(x: -6, y: r.minY + 12), control1: CGPoint(x: -18, y: r.minY + 22), control2: CGPoint(x: -14, y: r.minY + 14))
        shade.closeSubpath()
        TPaint.body(ctx, shade, c, CGRect(x: -18, y: r.minY + 10, width: 46, height: 28), line: 2.3)
        TPaint.gloss(ctx, CGRect(x: -7, y: r.minY + 16, width: 13, height: 6), 0.55)
    }

    // MARK: - 2. Pastel Korean Hanbok Doll

    private static func drawHanbokDoll(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, interactPhase: Double) {
        var g = ctx
        if interactPhase > 0.01 {
            let sway = sin(interactPhase * .pi * 3) * 0.14 * interactPhase
            g.translateBy(x: 0, y: -CGFloat(sin(interactPhase * .pi)) * 8)
            g.rotate(by: .radians(sway))
        }

        let skirtColor = c
        let jacketColor = TRGB(0xFFF1B8)
        let hairOutline = StorybookArt.outline(for: 0x4A3348)

        // Bell-shaped chima skirt
        var chima = Path()
        chima.move(to: CGPoint(x: -12, y: r.minY + 46))
        chima.addCurve(to: CGPoint(x: -28, y: r.maxY - 4), control1: CGPoint(x: -24, y: r.minY + 60), control2: CGPoint(x: -28, y: r.maxY - 16))
        chima.addQuadCurve(to: CGPoint(x: 28, y: r.maxY - 4), control: CGPoint(x: 0, y: r.maxY + 2))
        chima.addCurve(to: CGPoint(x: 12, y: r.minY + 46), control1: CGPoint(x: 28, y: r.maxY - 16), control2: CGPoint(x: 24, y: r.minY + 60))
        chima.closeSubpath()
        TPaint.body(g, chima, skirtColor, CGRect(x: -28, y: r.minY + 44, width: 56, height: 48), line: 2.2)

        // Golden embroidered skirt hem
        var hem = Path()
        hem.move(to: CGPoint(x: -24, y: r.maxY - 10))
        hem.addQuadCurve(to: CGPoint(x: 24, y: r.maxY - 10), control: CGPoint(x: 0, y: r.maxY - 5))
        g.stroke(hem, with: .color(Color(hex: 0xFFE07D)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

        // Curved sleeves & jeogori jacket
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let sleeve = Path(ellipseIn: CGRect(x: s < 0 ? -24 : 8, y: r.minY + 37, width: 16, height: 15))
            TPaint.body(g, sleeve, jacketColor, sleeve.boundingRect, line: 1.8)
            TPaint.dot(g, s * 22, r.minY + 46, 4, Color(hex: 0xFFE0CC))
        }
        let jeogoriRect = CGRect(x: -14, y: r.minY + 36, width: 28, height: 16)
        TPaint.body(g, Path(roundedRect: jeogoriRect, cornerRadius: 7), jacketColor, jeogoriRect, line: 2)

        // White dongjeong collar & pink goreum ribbon
        var collar = Path()
        collar.move(to: CGPoint(x: -7, y: r.minY + 37))
        collar.addLine(to: CGPoint(x: 0, y: r.minY + 45))
        collar.addLine(to: CGPoint(x: 7, y: r.minY + 37))
        g.stroke(collar, with: .color(.white), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        TPaint.stroke(g, [CGPoint(x: 3, y: r.minY + 46), CGPoint(x: 8, y: r.minY + 61)], Color(hex: 0xFF6BA6), 3)
        TPaint.stroke(g, [CGPoint(x: 2, y: r.minY + 46), CGPoint(x: -1, y: r.minY + 62)], Color(hex: 0xFF6BA6), 3)

        // Hair buns + daenggi ribbon
        for side in [-1.0, 1.0] {
            let bx = CGFloat(side) * 16
            let bun = Path(ellipseIn: CGRect(x: bx - 7, y: r.minY + 7, width: 14, height: 14))
            g.fill(bun, with: .color(Color(hex: 0x4E364D)))
            g.stroke(bun, with: .color(hairOutline), lineWidth: 1.8)
            TPaint.dot(g, bx, r.minY + 11, 3, Color(hex: 0xFF77B0))
        }

        // Cute head & smiling face
        let headRect = CGRect(x: -17, y: r.minY + 8, width: 34, height: 31)
        let head = Path(ellipseIn: headRect)
        g.fill(head, with: .radialGradient(
            Gradient(colors: [Color(hex: 0xFFF0E4), Color(hex: 0xFFDFC8)]),
            center: CGPoint(x: -4, y: r.minY + 18), startRadius: 2, endRadius: 20
        ))
        g.stroke(head, with: .color(StorybookArt.outline(for: 0xE6B594)), lineWidth: 2)

        // Glossy bangs
        var bangs = Path()
        bangs.move(to: CGPoint(x: -17, y: r.minY + 21))
        bangs.addCurve(to: CGPoint(x: 17, y: r.minY + 21), control1: CGPoint(x: -14, y: r.minY + 4), control2: CGPoint(x: 14, y: r.minY + 4))
        bangs.addQuadCurve(to: CGPoint(x: 0, y: r.minY + 17), control: CGPoint(x: 8, y: r.minY + 15))
        bangs.addQuadCurve(to: CGPoint(x: -17, y: r.minY + 21), control: CGPoint(x: -8, y: r.minY + 15))
        bangs.closeSubpath()
        g.fill(bangs, with: .color(Color(hex: 0x4E364D)))

        // Eyes, blush & smile
        TPaint.dot(g, -6.5, r.minY + 25, 2.3, Color(hex: 0x452A3E))
        TPaint.dot(g, 6.5, r.minY + 25, 2.3, Color(hex: 0x452A3E))
        TPaint.dot(g, -11, r.minY + 29, 3.2, Color(hex: 0xFF9EC2).opacity(0.6))
        TPaint.dot(g, 11, r.minY + 29, 3.2, Color(hex: 0xFF9EC2).opacity(0.6))
        var smile = Path()
        smile.move(to: CGPoint(x: -3.5, y: r.minY + 30))
        smile.addQuadCurve(to: CGPoint(x: 3.5, y: r.minY + 30), control: CGPoint(x: 0, y: r.minY + 33.5))
        g.stroke(smile, with: .color(Color(hex: 0x7A475C)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
    }

    // MARK: - 3. Sparkly Heart Jewel Compact

    private static func drawJewelCompact(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, interactPhase: Double, time: Double) {
        let baseRect = CGRect(x: r.minX + 3, y: r.minY + 6, width: r.width - 6, height: r.height - 6)
        let shell = TidyHeart().path(in: baseRect)
        let goldRim = CGRect(x: r.minX, y: r.minY + 3, width: r.width, height: r.height - 2)
        ctx.fill(TidyHeart().path(in: goldRim), with: .color(Color(hex: 0xFFE382)))
        ctx.stroke(TidyHeart().path(in: goldRim), with: .color(StorybookArt.outline(for: 0xDDA63B)), lineWidth: 2.2)
        TPaint.ball(ctx, shell, c, baseRect, line: 2)

        // Sparkling center gem
        let gemRect = CGRect(x: -11, y: -6, width: 22, height: 20)
        let gem = TidyHeart().path(in: gemRect)
        TPaint.ball(ctx, gem, TRGB(0x9CE8FF), gemRect, line: 1.6)
        TPaint.gloss(ctx, CGRect(x: -6, y: -2, width: 6, height: 4), 0.85)

        // Gold crown clasp at top
        let crown = Path(roundedRect: CGRect(x: -8, y: r.minY + 2, width: 16, height: 7), cornerRadius: 3)
        ctx.fill(crown, with: .color(Color(hex: 0xFFD45A)))
        ctx.stroke(crown, with: .color(StorybookArt.outline(for: 0xDDA63B)), lineWidth: 1.6)

        let twinkleAlpha = interactPhase > 0.05 ? 1.0 : (0.55 + 0.45 * sin(time * 3.5))
        StorybookArt.sparkle(ctx, at: CGPoint(x: 18, y: -12), radius: 7, color: Theme.lemon, opacity: twinkleAlpha)
        if interactPhase > 0.05 {
            StorybookArt.sparkle(ctx, at: CGPoint(x: -19, y: -10), radius: 8, color: .white, opacity: interactPhase)
        }
    }

    // MARK: - 4. Framed Family Portrait

    private static func drawFamilyPhoto(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let framePath = Path(roundedRect: r, cornerRadius: 8)
        TPaint.body(ctx, framePath, TRGB(0xDDA36B), r, line: 2.4)

        let inner = r.insetBy(dx: 8, dy: 8)
        ctx.fill(
            Path(roundedRect: inner, cornerRadius: 4),
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF5E6), Color(hex: 0xFFE3EC)]),
                startPoint: CGPoint(x: 0, y: inner.minY),
                endPoint: CGPoint(x: 0, y: inner.maxY)
            )
        )

        // Cheerful family trio: parent left, parent right, little girl center with pink bow
        let people: [(CGFloat, CGFloat, CGFloat, UInt32, UInt32)] = [
            (-17, 3, 9.5, 0x8AC7FF, 0x5B3F4C),
            (17, 2, 10, 0xFFA2C4, 0x5B3F4C),
            (0, 10, 7.5, 0xFFE07D, 0x4E364D),
        ]
        for (px, py, hr, shirtHex, hairHex) in people {
            let torso = Path(ellipseIn: CGRect(x: px - hr * 1.15, y: py + hr * 0.65, width: hr * 2.3, height: hr * 1.7))
            ctx.fill(torso, with: .color(Color(hex: shirtHex)))
            let head = Path(ellipseIn: CGRect(x: px - hr, y: py - hr, width: hr * 2, height: hr * 2))
            ctx.fill(head, with: .color(Color(hex: 0xFFE5D2)))
            ctx.stroke(head, with: .color(StorybookArt.outline(for: 0xE6B594)), lineWidth: 1.4)
            let cap = Path(ellipseIn: CGRect(x: px - hr, y: py - hr - 1.5, width: hr * 2, height: hr * 1.05))
            ctx.fill(cap, with: .color(Color(hex: hairHex)))
            TPaint.dot(ctx, px - hr * 0.35, py + 1, 1.3, Color(hex: 0x452A3E))
            TPaint.dot(ctx, px + hr * 0.35, py + 1, 1.3, Color(hex: 0x452A3E))
        }
        // Little heart overhead
        StorybookArt.heart(ctx, at: CGPoint(x: 0, y: inner.minY + 11), size: 11, color: Theme.pink)
        ctx.stroke(Path(roundedRect: inner, cornerRadius: 4), with: .color(Color(hex: 0xB87E49)), lineWidth: 1.8)
    }

    // MARK: - 5. Pastel Piggy Bank

    private static func drawPiggyBank(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let pig = TRGB(0xFFA6C8)
        // Little feet
        for fx: CGFloat in [-16, 10] {
            let leg = Path(roundedRect: CGRect(x: fx, y: r.maxY - 12, width: 10, height: 12), cornerRadius: 4)
            TPaint.body(ctx, leg, pig.shade, leg.boundingRect, line: 1.8)
        }
        // Curly tail
        var tail = Path()
        tail.move(to: CGPoint(x: 24, y: 2))
        tail.addCurve(to: CGPoint(x: 33, y: -6), control1: CGPoint(x: 34, y: 4), control2: CGPoint(x: 36, y: -3))
        ctx.stroke(tail, with: .color(pig.line.color), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

        // Plump body
        let bodyRect = CGRect(x: -28, y: -18, width: 56, height: 38)
        TPaint.ball(ctx, Path(ellipseIn: bodyRect), pig, bodyRect, line: 2.3)

        // Ear
        let ear = TPaint.poly([CGPoint(x: -16, y: -15), CGPoint(x: -8, y: -27), CGPoint(x: -2, y: -16)])
        TPaint.body(ctx, ear, pig.light, ear.boundingRect, line: 2)

        // Snout
        let snoutRect = CGRect(x: -35, y: -6, width: 15, height: 16)
        TPaint.body(ctx, Path(ellipseIn: snoutRect), pig.light, snoutRect, line: 2)
        TPaint.dot(ctx, -30, 1, 1.8, pig.line.color)
        TPaint.dot(ctx, -25, 1, 1.8, pig.line.color)

        // Eye & blush
        TPaint.dot(ctx, -16, -5, 2.8, Color(hex: 0x4A2E57))
        TPaint.dot(ctx, -15, -6, 1, .white)
        TPaint.dot(ctx, -11, 2, 3.6, Color(hex: 0xFF77AB).opacity(0.55))

        // Coin slot on back
        let slot = Path(roundedRect: CGRect(x: -4, y: -14, width: 14, height: 4), cornerRadius: 2)
        ctx.fill(slot, with: .color(Color(hex: 0x7A425D)))
        TPaint.gloss(ctx, CGRect(x: -6, y: -9, width: 18, height: 6), 0.5)
    }

    // MARK: - 6. Cozy Succulent Pot

    private static func drawSucculentPot(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let leafA = TRGB(0x7FD6A8)
        let leafB = TRGB(0x5AB88B)
        // Rosette petals radiating up
        let petals: [(CGFloat, CGFloat, Double, CGFloat, TRGB)] = [
            (-16, -6, -0.65, 22, leafB),
            (16, -6, 0.65, 22, leafB),
            (-10, -14, -0.32, 24, leafA),
            (10, -14, 0.32, 24, leafA),
            (0, -18, 0, 26, leafA.light),
        ]
        for (px, py, ang, len, col) in petals {
            var g = ctx
            g.translateBy(x: px, y: py)
            g.rotate(by: .radians(ang))
            let petal = Path(ellipseIn: CGRect(x: -8, y: -len * 0.6, width: 16, height: len))
            TPaint.ball(g, petal, col, petal.boundingRect, line: 1.8)
        }

        // Cute terracotta/pastel pot
        let potColor = c
        let body = TPaint.poly([
            CGPoint(x: -20, y: 2),
            CGPoint(x: 20, y: 2),
            CGPoint(x: 15, y: r.maxY),
            CGPoint(x: -15, y: r.maxY),
        ])
        TPaint.tube(ctx, body, potColor, CGRect(x: -20, y: 2, width: 40, height: r.maxY - 2), line: 2.2)
        let rim = Path(roundedRect: CGRect(x: -23, y: -4, width: 46, height: 10), cornerRadius: 4)
        TPaint.tube(ctx, rim, potColor.light, rim.boundingRect, line: 2)
        // Tiny smiling face on pot
        TPaint.dot(ctx, -6, 15, 1.8, potColor.line.color)
        TPaint.dot(ctx, 6, 15, 1.8, potColor.line.color)
        var smile = Path()
        smile.move(to: CGPoint(x: -3, y: 18))
        smile.addQuadCurve(to: CGPoint(x: 3, y: 18), control: CGPoint(x: 0, y: 21))
        ctx.stroke(smile, with: .color(potColor.line.color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    // MARK: - 7. Twin-Bell Alarm Clock

    private static func drawAlarmClock(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, interactPhase: Double, time: Double) {
        var g = ctx
        if interactPhase > 0.01 {
            let shake = sin(time * 42) * 0.14 * interactPhase
            g.rotate(by: .radians(shake))
        }

        // Little feet
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            TPaint.stroke(g, [CGPoint(x: s * 14, y: 20), CGPoint(x: s * 19, y: r.maxY - 2)], Color(hex: 0xDDA63B), 5)
        }

        // Twin golden bells
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var b = g
            b.translateBy(x: s * 17, y: -21)
            b.rotate(by: .radians(side * 0.52))
            let bell = Path(roundedRect: CGRect(x: -10, y: -7, width: 20, height: 14), cornerRadius: 7)
            TPaint.body(b, bell, TRGB(0xFFE074), bell.boundingRect, line: 2)
        }
        TPaint.stroke(g, [CGPoint(x: 0, y: -20), CGPoint(x: 0, y: -28)], Color(hex: 0xDDA63B), 3.5)
        TPaint.dot(g, 0, -29, 3.5, Color(hex: 0xFFE074))

        // Clock body & cream dial
        let bodyRect = CGRect(x: -24, y: -20, width: 48, height: 48)
        TPaint.ball(g, Path(ellipseIn: bodyRect), c, bodyRect, line: 2.4)
        let faceRect = bodyRect.insetBy(dx: 6.5, dy: 6.5)
        g.fill(Path(ellipseIn: faceRect), with: .color(Color(hex: 0xFFFDF8)))
        g.stroke(Path(ellipseIn: faceRect), with: .color(c.line.color(0.55)), lineWidth: 1.5)

        // Hour dots & cute hands
        for k in 0..<4 {
            let a = Double(k) * .pi / 2
            TPaint.dot(g, CGFloat(cos(a)) * 13, 4 + CGFloat(sin(a)) * 13, 1.6, c.line.color)
        }
        TPaint.stroke(g, [CGPoint(x: 0, y: 4), CGPoint(x: 0, y: -5)], Color(hex: 0x5B3A68), 2.6)
        TPaint.stroke(g, [CGPoint(x: 0, y: 4), CGPoint(x: 9, y: 1)], Theme.pink, 2.2)
        TPaint.dot(g, 0, 4, 2.5, Color(hex: 0xDDA63B))
    }

    // MARK: - 8. Ribbon Diary Book

    private static func drawDiaryBook(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        // Satin bookmark ribbon dangling slightly below
        var ribbon = Path()
        ribbon.move(to: CGPoint(x: 8, y: r.maxY - 8))
        ribbon.addLine(to: CGPoint(x: 14, y: r.maxY - 8))
        ribbon.addLine(to: CGPoint(x: 14, y: r.maxY + 4))
        ribbon.addLine(to: CGPoint(x: 11, y: r.maxY + 1))
        ribbon.addLine(to: CGPoint(x: 8, y: r.maxY + 4))
        ribbon.closeSubpath()
        ctx.fill(ribbon, with: .color(Theme.pink))

        // Cream page edge
        let pages = Path(roundedRect: CGRect(x: r.minX + 6, y: r.minY + 3, width: r.width - 7, height: r.height - 6), cornerRadius: 5)
        ctx.fill(pages, with: .color(Color(hex: 0xFFF7E8)))
        ctx.stroke(pages, with: .color(Color(hex: 0xD8C6A8)), lineWidth: 1.6)

        // Cover & spine
        let coverRect = CGRect(x: r.minX, y: r.minY, width: r.width - 5, height: r.height - 4)
        let cover = Path(roundedRect: coverRect, cornerRadius: 7)
        TPaint.body(ctx, cover, c, coverRect, line: 2.3)
        ctx.fill(Path(roundedRect: CGRect(x: r.minX, y: r.minY, width: 10, height: r.height - 4), cornerRadius: 4), with: .color(c.shade.color))

        // Heart padlock emblem
        let clasp = Path(roundedRect: CGRect(x: coverRect.maxX - 8, y: -7, width: 13, height: 14), cornerRadius: 4)
        TPaint.body(ctx, clasp, TRGB(0xFFE074), clasp.boundingRect, line: 1.6)
        StorybookArt.heart(ctx, at: CGPoint(x: -1, y: -2), size: 22, color: .white.opacity(0.92))
        StorybookArt.sparkle(ctx, at: CGPoint(x: -1, y: -2), radius: 5, color: Theme.lemon)
    }

    // MARK: - 9. Floppy-Eared Plush Bunny

    private static func drawPlushBunny(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, interactPhase: Double) {
        var g = ctx
        let earBounce = CGFloat(sin(interactPhase * .pi * 2)) * 0.22 * CGFloat(interactPhase)
        let fur = TRGB(0xFFF6F0)
        let innerEar = TRGB(0xFFB3CF)

        // Tall bunny ears
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            var e = g
            e.translateBy(x: s * 11, y: -20)
            e.rotate(by: .radians(side * 0.18 + Double(s * earBounce)))
            let earRect = CGRect(x: -8, y: -28, width: 16, height: 30)
            TPaint.ball(e, Path(ellipseIn: earRect), fur, earRect, line: 2.1)
            e.fill(Path(ellipseIn: earRect.insetBy(dx: 4, dy: 5)), with: .color(innerEar.color))
        }

        // Plump body & paws
        let bodyRect = CGRect(x: -22, y: 2, width: 44, height: 38)
        TPaint.ball(g, Path(ellipseIn: bodyRect), fur, bodyRect, line: 2.2)
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let foot = Path(ellipseIn: CGRect(x: s * 15 - 9, y: 28, width: 18, height: 13))
            TPaint.ball(g, foot, fur, foot.boundingRect, line: 2)
            g.fill(Path(ellipseIn: CGRect(x: s * 15 - 4.5, y: 31, width: 9, height: 6.5)), with: .color(innerEar.color))
        }

        // Head
        let headRect = CGRect(x: -22, y: -26, width: 44, height: 36)
        TPaint.ball(g, Path(ellipseIn: headRect), fur, headRect, line: 2.2)

        // Ribbon bow
        let lb = TPaint.poly([CGPoint(x: 0, y: 9), CGPoint(x: -11, y: 3), CGPoint(x: -11, y: 15)])
        let rb = TPaint.poly([CGPoint(x: 0, y: 9), CGPoint(x: 11, y: 3), CGPoint(x: 11, y: 15)])
        TPaint.body(g, lb, c, lb.boundingRect, line: 1.5)
        TPaint.body(g, rb, c, rb.boundingRect, line: 1.5)
        TPaint.dot(g, 0, 9, 3.2, c.shade.color)

        // Sweet face
        TPaint.dot(g, -8, -10, 2.7, Color(hex: 0x4A2E57))
        TPaint.dot(g, 8, -10, 2.7, Color(hex: 0x4A2E57))
        TPaint.dot(g, -7.2, -11, 1, .white)
        TPaint.dot(g, 8.8, -11, 1, .white)
        TPaint.dot(g, -13.5, -4, 3.5, Color(hex: 0xFF9AC2).opacity(0.6))
        TPaint.dot(g, 13.5, -4, 3.5, Color(hex: 0xFF9AC2).opacity(0.6))
        g.fill(Path(ellipseIn: CGRect(x: -3, y: -6.5, width: 6, height: 4.5)), with: .color(Color(hex: 0xFF8FB8)))
    }

    // MARK: - 10. Twinkling Fairy Lights Garland

    private static func drawFairyLights(_ ctx: GraphicsContext, _ r: CGRect, isLit: Bool, time: Double) {
        var cord = Path()
        cord.move(to: CGPoint(x: r.minX + 6, y: r.minY + 10))
        cord.addQuadCurve(to: CGPoint(x: 0, y: r.minY + 24), control: CGPoint(x: r.minX * 0.5, y: r.minY + 28))
        cord.addQuadCurve(to: CGPoint(x: r.maxX - 6, y: r.minY + 10), control: CGPoint(x: r.maxX * 0.5, y: r.minY + 28))
        ctx.stroke(cord, with: .color(Color(hex: 0xC49F6E)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        let bulbColors: [UInt32] = [0xFFE38A, 0xFFB3D1, 0xFFF5B8, 0xA8E8D8, 0xFFE38A, 0xD2BEFF, 0xFFF5B8]
        let count = bulbColors.count
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(count - 1)
            let bx = r.minX + 14 + t * (r.width - 28)
            let sag = sin(Double(t) * .pi) * 14
            let by = r.minY + 14 + CGFloat(sag)
            let twinkle = isLit ? (0.72 + 0.28 * sin(time * 4.2 + Double(i) * 1.15)) : 0.35

            if isLit {
                let glowRect = CGRect(x: bx - 17, y: by - 12, width: 34, height: 34)
                ctx.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [Color(hex: bulbColors[i], alpha: 0.55 * twinkle), .clear]),
                        center: CGPoint(x: bx, y: by + 5),
                        startRadius: 2,
                        endRadius: 17
                    )
                )
            }

            // Little brass socket & glowing star bulb
            ctx.fill(Path(roundedRect: CGRect(x: bx - 2.5, y: by - 4, width: 5, height: 5), cornerRadius: 1.5), with: .color(Color(hex: 0xC49F6E)))
            if i.isMultiple(of: 2) {
                let starRect = CGRect(x: bx - 8, y: by, width: 16, height: 16)
                let star = TidyStar5(inner: 0.5).path(in: starRect)
                ctx.fill(star, with: .color(Color(hex: bulbColors[i], alpha: isLit ? 1 : 0.7)))
                ctx.stroke(star, with: .color(StorybookArt.outline(for: bulbColors[i])), lineWidth: 1.4)
            } else {
                let bulb = Path(ellipseIn: CGRect(x: bx - 5.5, y: by + 1, width: 11, height: 13))
                ctx.fill(bulb, with: .color(Color(hex: bulbColors[i], alpha: isLit ? 1 : 0.72)))
                ctx.stroke(bulb, with: .color(StorybookArt.outline(for: bulbColors[i])), lineWidth: 1.4)
            }
            if isLit {
                TPaint.dot(ctx, bx - 1.5, by + 5, 2.2, .white.opacity(0.9 * twinkle))
            }
        }
    }

    // MARK: - 11. Cute Pastel Korean Rice Cooker

    private static func drawRiceCooker(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, interactPhase: Double, time: Double) {
        // Carry handle arch behind lid
        var handle = Path()
        handle.move(to: CGPoint(x: -28, y: -12))
        handle.addQuadCurve(to: CGPoint(x: 28, y: -12), control: CGPoint(x: 0, y: r.minY - 8))
        ctx.stroke(handle, with: .color(Color(hex: 0x9AA5B8)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        ctx.stroke(handle, with: .color(Color(hex: 0xEDF2F8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Little rubber feet
        for fx: CGFloat in [-24, 16] {
            ctx.fill(Path(roundedRect: CGRect(x: fx, y: r.maxY - 6, width: 9, height: 6), cornerRadius: 3), with: .color(Color(hex: 0x9B889E)))
        }

        // Round pastel cooker body
        let bodyRect = CGRect(x: -36, y: -18, width: 72, height: 50)
        TPaint.ball(ctx, Path(roundedRect: bodyRect, cornerRadius: 22), c, bodyRect, line: 2.4)

        // Cream domed lid + steam vent button
        let lidRect = CGRect(x: -33, y: -27, width: 66, height: 22)
        TPaint.body(ctx, Path(roundedRect: lidRect, cornerRadius: 11), TRGB(0xFFFDF8), lidRect, line: 2.2)
        let vent = Path(ellipseIn: CGRect(x: -7, y: -29, width: 14, height: 8))
        TPaint.metal(ctx, vent, vent.boundingRect)

        // Friendly digital control panel with smiling LED face
        let panelRect = CGRect(x: -22, y: -4, width: 44, height: 24)
        ctx.fill(Path(roundedRect: panelRect, cornerRadius: 8), with: .color(Color(hex: 0xFFFDF9)))
        ctx.stroke(Path(roundedRect: panelRect, cornerRadius: 8), with: .color(c.line.color(0.7)), lineWidth: 1.8)

        let ledRect = CGRect(x: -14, y: 0, width: 28, height: 10)
        ctx.fill(Path(roundedRect: ledRect, cornerRadius: 4), with: .color(Color(hex: 0x4C3D5E)))
        TPaint.dot(ctx, -5, 5, 1.5, Color(hex: 0x9FF2C8))
        TPaint.dot(ctx, 5, 5, 1.5, Color(hex: 0x9FF2C8))
        var ledSmile = Path()
        ledSmile.move(to: CGPoint(x: -3, y: 6.8))
        ledSmile.addQuadCurve(to: CGPoint(x: 3, y: 6.8), control: CGPoint(x: 0, y: 9.2))
        ctx.stroke(ledSmile, with: .color(Color(hex: 0xFFE38A)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))

        // Cook button dot
        TPaint.dot(ctx, 0, 15, 3, interactPhase > 0.05 ? Color(hex: 0xFF77AB) : Color(hex: 0x9FE3CF))
        TPaint.gloss(ctx, CGRect(x: -27, y: -12, width: 12, height: 6), 0.55)

        if interactPhase > 0.05 {
            // Cozy steam puffs rising above the vent
            for i in 0..<3 {
                let rise = CGFloat(1 - interactPhase) * 26 + CGFloat(i) * 8
                let ox = CGFloat(sin(time * 8 + Double(i) * 1.6)) * 6
                let rad = 5 + CGFloat(i) * 2.5
                ctx.fill(
                    Path(ellipseIn: CGRect(x: ox - rad, y: -34 - rise - rad, width: rad * 2, height: rad * 2)),
                    with: .color(.white.opacity(0.65 * interactPhase))
                )
            }
        }
    }

    // MARK: - 12. Pastel Enamel Kettle

    private static func drawKettle(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        // Curved spout on right
        var spout = Path()
        spout.move(to: CGPoint(x: 16, y: 4))
        spout.addCurve(to: CGPoint(x: 34, y: -14), control1: CGPoint(x: 28, y: 2), control2: CGPoint(x: 34, y: -6))
        spout.addLine(to: CGPoint(x: 26, y: -17))
        spout.addCurve(to: CGPoint(x: 13, y: -4), control1: CGPoint(x: 23, y: -10), control2: CGPoint(x: 18, y: -6))
        spout.closeSubpath()
        TPaint.body(ctx, spout, c, spout.boundingRect, line: 2)

        // Arch handle over top
        var handle = Path()
        handle.move(to: CGPoint(x: -22, y: 0))
        handle.addCurve(to: CGPoint(x: 12, y: -24), control1: CGPoint(x: -26, y: -28), control2: CGPoint(x: -6, y: -32))
        ctx.stroke(handle, with: .color(StorybookArt.outline(for: 0xC88F59)), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
        ctx.stroke(handle, with: .color(Color(hex: 0xE6B682)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

        // Rounded kettle body
        var body = Path()
        body.move(to: CGPoint(x: -18, y: -12))
        body.addLine(to: CGPoint(x: 14, y: -12))
        body.addCurve(to: CGPoint(x: 24, y: r.maxY - 4), control1: CGPoint(x: 24, y: -4), control2: CGPoint(x: 26, y: r.maxY - 10))
        body.addQuadCurve(to: CGPoint(x: -28, y: r.maxY - 4), control: CGPoint(x: -2, y: r.maxY + 2))
        body.addCurve(to: CGPoint(x: -18, y: -12), control1: CGPoint(x: -30, y: r.maxY - 10), control2: CGPoint(x: -28, y: -4))
        body.closeSubpath()
        TPaint.ball(ctx, body, c, CGRect(x: -28, y: -12, width: 52, height: 46), line: 2.3)

        // Lid + wooden knob
        let lid = Path(ellipseIn: CGRect(x: -15, y: -17, width: 26, height: 10))
        TPaint.body(ctx, lid, TRGB(0xFFFDF8), lid.boundingRect, line: 1.8)
        TPaint.ball(ctx, Path(ellipseIn: CGRect(x: -6, y: -24, width: 8, height: 8)), TRGB(0xD9A26C), CGRect(x: -6, y: -24, width: 8, height: 8), line: 1.5)
        TPaint.gloss(ctx, CGRect(x: -18, y: -2, width: 12, height: 16), 0.5)
    }

    // MARK: - 13. Floral Porcelain Teapot

    private static func drawTeapot(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        let cream = TRGB(0xFFF9F2)
        // Curved porcelain handle (left)
        let handle = Path(ellipseIn: CGRect(x: -36, y: -10, width: 22, height: 26))
        ctx.stroke(handle, with: .color(c.line.color), lineWidth: 8)
        ctx.stroke(handle, with: .color(c.color), lineWidth: 4)

        // S-curved spout (right)
        var spout = Path()
        spout.move(to: CGPoint(x: 16, y: 12))
        spout.addCurve(to: CGPoint(x: 34, y: -12), control1: CGPoint(x: 30, y: 12), control2: CGPoint(x: 26, y: -10))
        ctx.stroke(spout, with: .color(c.line.color), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))
        ctx.stroke(spout, with: .color(cream.color), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        // Plump teapot belly
        let bellyRect = CGRect(x: -23, y: -14, width: 46, height: 42)
        TPaint.ball(ctx, Path(ellipseIn: bellyRect), cream, bellyRect, line: 2.3)

        // Lid with finial
        let lid = Path(ellipseIn: CGRect(x: -15, y: -20, width: 30, height: 12))
        TPaint.body(ctx, lid, c, lid.boundingRect, line: 2)
        TPaint.ball(ctx, Path(ellipseIn: CGRect(x: -5, y: -28, width: 10, height: 9)), c.light, CGRect(x: -5, y: -28, width: 10, height: 9), line: 1.6)

        // Cute blossom decal in center
        for i in 0..<5 {
            let a = Double(i) * (2 * .pi / 5)
            TPaint.dot(ctx, CGFloat(cos(a)) * 6, 7 + CGFloat(sin(a)) * 6, 3.6, c.color)
        }
        TPaint.dot(ctx, 0, 7, 3.2, Color(hex: 0xFFE38A))
        TPaint.gloss(ctx, CGRect(x: -16, y: -6, width: 10, height: 14), 0.65)
    }

    // MARK: - 14. Cozy Bunny Slippers

    private static func drawSlippers(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        for side in [-1.0, 1.0] {
            let ox = CGFloat(side) * 21
            var g = ctx
            g.translateBy(x: ox, y: 4)

            // Tiny bunny ears sticking up
            for earSide in [-1.0, 1.0] {
                let ex = CGFloat(earSide) * 6
                let ear = Path(ellipseIn: CGRect(x: ex - 4, y: -22, width: 8, height: 15))
                TPaint.ball(g, ear, c.light, ear.boundingRect, line: 1.7)
                g.fill(Path(ellipseIn: CGRect(x: ex - 2, y: -19, width: 4, height: 9)), with: .color(Color(hex: 0xFFBCD4)))
            }

            // Soft slipper sole & toe dome
            let sole = Path(roundedRect: CGRect(x: -18, y: 6, width: 36, height: 10), cornerRadius: 5)
            TPaint.body(g, sole, TRGB(0xF5EFE8), sole.boundingRect, line: 1.8)
            let dome = Path(roundedRect: CGRect(x: -16, y: -10, width: 32, height: 20), cornerRadius: 10)
            TPaint.ball(g, dome, c, dome.boundingRect, line: 2)
            // Tiny face on toe
            TPaint.dot(g, -5, -1, 1.6, Color(hex: 0x4A2E57))
            TPaint.dot(g, 5, -1, 1.6, Color(hex: 0x4A2E57))
            TPaint.dot(g, 0, 2, 1.8, Color(hex: 0xFF8FB8))
        }
    }

    // MARK: - 15. Framed Art Poster (3 adorable variants by color index!)

    private static func drawArtPoster(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, colorIndex: Int) {
        let framePath = Path(roundedRect: r, cornerRadius: 8)
        TPaint.body(ctx, framePath, TRGB(0xE8C08E), r, line: 2.5)

        let inner = r.insetBy(dx: 8, dy: 8)
        let innerPath = Path(roundedRect: inner, cornerRadius: 4)
        ctx.fill(
            innerPath,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFFDF8), c.mix(.white, 0.72).color]),
                startPoint: CGPoint(x: 0, y: inner.minY),
                endPoint: CGPoint(x: 0, y: inner.maxY)
            )
        )

        var clipped = ctx
        clipped.clip(to: innerPath)

        switch colorIndex % 3 {
        case 0:
            // Pastel rainbow + fluffy clouds
            let bands: [UInt32] = [0xFF8FB8, 0xFFC08A, 0xFFE38A, 0x9FE3CF, 0x9CCBFF]
            for (idx, hex) in bands.enumerated() {
                let rad = 34 - CGFloat(idx) * 4.5
                let arcRect = CGRect(x: -rad, y: 12 - rad, width: rad * 2, height: rad * 2)
                clipped.stroke(Path(ellipseIn: arcRect), with: .color(Color(hex: hex)), lineWidth: 4.8)
            }
            for cx: CGFloat in [-20, 0, 20] {
                clipped.fill(Path(ellipseIn: CGRect(x: cx - 14, y: 12, width: 28, height: 18)), with: .color(.white))
            }
            StorybookArt.sparkle(clipped, at: CGPoint(x: -20, y: -26), radius: 6, color: Theme.lemon)
            StorybookArt.sparkle(clipped, at: CGPoint(x: 20, y: -22), radius: 5, color: Theme.pink)
        case 1:
            // Dreamy crescent moon & stars
            clipped.fill(innerPath, with: .color(Color(hex: 0x5B4B8A)))
            let moon = Path(ellipseIn: CGRect(x: -16, y: -24, width: 32, height: 32))
            clipped.fill(moon, with: .color(Color(hex: 0xFFE88C)))
            clipped.fill(Path(ellipseIn: CGRect(x: -6, y: -28, width: 28, height: 28)), with: .color(Color(hex: 0x5B4B8A)))
            StorybookArt.sparkle(clipped, at: CGPoint(x: 16, y: -22), radius: 6.5, color: .white)
            StorybookArt.sparkle(clipped, at: CGPoint(x: -18, y: 18), radius: 5.5, color: Theme.lemon)
            StorybookArt.sparkle(clipped, at: CGPoint(x: 15, y: 20), radius: 7, color: Theme.pink)
        default:
            // Smiling daisy bouquet
            TPaint.stroke(clipped, [CGPoint(x: 0, y: 6), CGPoint(x: 0, y: 36)], Color(hex: 0x6EC47E), 3.5)
            for i in 0..<8 {
                let a = Double(i) * (.pi / 4)
                let px = CGFloat(cos(a)) * 14
                let py = -10 + CGFloat(sin(a)) * 14
                clipped.fill(Path(ellipseIn: CGRect(x: px - 7, y: py - 7, width: 14, height: 14)), with: .color(.white))
                clipped.stroke(Path(ellipseIn: CGRect(x: px - 7, y: py - 7, width: 14, height: 14)), with: .color(Theme.blush), lineWidth: 1.5)
            }
            clipped.fill(Path(ellipseIn: CGRect(x: -10, y: -20, width: 20, height: 20)), with: .color(Theme.lemon))
            TPaint.dot(clipped, -3.5, -11, 1.5, Color(hex: 0x5B3A68))
            TPaint.dot(clipped, 3.5, -11, 1.5, Color(hex: 0x5B3A68))
        }

        ctx.stroke(innerPath, with: .color(Color(hex: 0xBE915E)), lineWidth: 1.8)
    }

    // MARK: - 16. Flower Vase

    private static func drawFlowerVase(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB) {
        // Stems & leaves
        let stems: [(CGFloat, CGFloat, UInt32)] = [
            (-14, -26, 0xFF8FB8),
            (0, -34, 0xFFE074),
            (15, -24, 0xC9B6FF),
        ]
        for (fx, fy, _) in stems {
            var st = Path()
            st.move(to: CGPoint(x: fx * 0.25, y: 4))
            st.addQuadCurve(to: CGPoint(x: fx, y: fy), control: CGPoint(x: fx * 0.7, y: -12))
            ctx.stroke(st, with: .color(Color(hex: 0x62B870)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }
        TidyArt.leaf(ctx, at: CGPoint(x: -4, y: -6), angle: -2.4, len: 18)
        TidyArt.leaf(ctx, at: CGPoint(x: 4, y: -8), angle: -0.7, len: 18)

        // Tulip/daisy blossoms
        for (fx, fy, hex) in stems {
            let col = TRGB(hex)
            let cup = Path(ellipseIn: CGRect(x: fx - 9, y: fy - 9, width: 18, height: 17))
            TPaint.ball(ctx, cup, col, cup.boundingRect, line: 1.8)
            TPaint.dot(ctx, fx, fy - 2, 3.2, Color(hex: 0xFFF7D1))
        }

        // Ceramic bud vase
        var vase = Path()
        vase.move(to: CGPoint(x: -10, y: 2))
        vase.addLine(to: CGPoint(x: 10, y: 2))
        vase.addCurve(to: CGPoint(x: 19, y: 24), control1: CGPoint(x: 11, y: 12), control2: CGPoint(x: 21, y: 16))
        vase.addQuadCurve(to: CGPoint(x: 12, y: r.maxY), control: CGPoint(x: 18, y: r.maxY))
        vase.addLine(to: CGPoint(x: -12, y: r.maxY))
        vase.addQuadCurve(to: CGPoint(x: -19, y: 24), control: CGPoint(x: -18, y: r.maxY))
        vase.addCurve(to: CGPoint(x: -10, y: 2), control1: CGPoint(x: -21, y: 16), control2: CGPoint(x: -11, y: 12))
        vase.closeSubpath()
        TPaint.ball(ctx, vase, c, CGRect(x: -19, y: 2, width: 38, height: 42), line: 2.2)
        let rim = Path(roundedRect: CGRect(x: -12, y: -1, width: 24, height: 6), cornerRadius: 3)
        TPaint.body(ctx, rim, c.light, rim.boundingRect, line: 1.8)
        TPaint.gloss(ctx, CGRect(x: -12, y: 14, width: 7, height: 14), 0.65)
    }

    // MARK: - 17. Cozy Plush Cat

    private static func drawPlushCat(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, interactPhase: Double, time: Double) {
        let fur = TRGB(0xFFE5C4)
        let stripe = TRGB(0xE8AA6F)

        // Curled wagging tail
        var tail = Path()
        let wag = CGFloat(sin(time * 7) * 5 * max(0.2, interactPhase))
        tail.move(to: CGPoint(x: 20, y: 20))
        tail.addCurve(to: CGPoint(x: 34, y: -4 + wag), control1: CGPoint(x: 34, y: 18), control2: CGPoint(x: 36, y: 6 + wag))
        ctx.stroke(tail, with: .color(fur.line.color), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        ctx.stroke(tail, with: .color(fur.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // Cozy loaf body
        let bodyRect = CGRect(x: -26, y: -4, width: 52, height: 34)
        TPaint.ball(ctx, Path(ellipseIn: bodyRect), fur, bodyRect, line: 2.2)

        // Cute pointy ears
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            let ear = TPaint.poly([
                CGPoint(x: s * 17, y: -16),
                CGPoint(x: s * 14, y: -32),
                CGPoint(x: s * 3, y: -22),
            ])
            TPaint.body(ctx, ear, fur, ear.boundingRect, line: 2)
        }

        // Round kitty head
        let headRect = CGRect(x: -22, y: -26, width: 42, height: 34)
        TPaint.ball(ctx, Path(ellipseIn: headRect), fur, headRect, line: 2.2)

        // Forehead tabby stripes
        for sx: CGFloat in [-5, 0, 5] {
            TPaint.stroke(ctx, [CGPoint(x: sx, y: -24), CGPoint(x: sx, y: -18)], stripe.color, 2.2)
        }

        // Collar & tiny bell
        var collar = Path()
        collar.move(to: CGPoint(x: -14, y: 5))
        collar.addQuadCurve(to: CGPoint(x: 12, y: 5), control: CGPoint(x: -1, y: 11))
        ctx.stroke(collar, with: .color(c.color), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        TPaint.dot(ctx, -1, 10, 4, Color(hex: 0xFFE074))

        // Happy eyes, nose & whiskers
        if interactPhase > 0.1 {
            for side in [-1.0, 1.0] {
                let cx = CGFloat(side) * 8 - 1
                var arc = Path()
                arc.move(to: CGPoint(x: cx - 3.5, y: -10))
                arc.addQuadCurve(to: CGPoint(x: cx + 3.5, y: -10), control: CGPoint(x: cx, y: -15))
                ctx.stroke(arc, with: .color(Color(hex: 0x4A2E57)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
        } else {
            TPaint.dot(ctx, -9, -11, 2.6, Color(hex: 0x4A2E57))
            TPaint.dot(ctx, 7, -11, 2.6, Color(hex: 0x4A2E57))
            TPaint.dot(ctx, -8.3, -12, 0.9, .white)
            TPaint.dot(ctx, 7.7, -12, 0.9, .white)
        }
        TPaint.dot(ctx, -1, -6.5, 2.2, Color(hex: 0xFF8FB8))
        for side in [-1.0, 1.0] {
            let s = CGFloat(side)
            TPaint.stroke(ctx, [CGPoint(x: s * 13 - 1, y: -7), CGPoint(x: s * 22 - 1, y: -9)], Color(hex: 0x7A5742), 1.3)
            TPaint.stroke(ctx, [CGPoint(x: s * 13 - 1, y: -4), CGPoint(x: s * 22 - 1, y: -3)], Color(hex: 0x7A5742), 1.3)
        }
    }

    // MARK: - 18. Twirling Star Music Box

    private static func drawMusicBox(_ ctx: GraphicsContext, _ r: CGRect, _ c: TRGB, interactPhase: Double, time: Double) {
        // Golden wind-up key on side
        TPaint.stroke(ctx, [CGPoint(x: 24, y: 18), CGPoint(x: 31, y: 18)], Color(hex: 0xDDA63B), 3.5)
        let keyLoop = Path(ellipseIn: CGRect(x: 28, y: 12, width: 7, height: 12))
        ctx.stroke(keyLoop, with: .color(Color(hex: 0xDDA63B)), lineWidth: 2.2)

        // Open back lid tilted behind
        let lidRect = CGRect(x: -24, y: -26, width: 48, height: 24)
        TPaint.body(ctx, Path(roundedRect: lidRect, cornerRadius: 8), c.light, lidRect, line: 2.1)
        ctx.fill(Path(roundedRect: lidRect.insetBy(dx: 5, dy: 4), cornerRadius: 5), with: .color(Color(hex: 0xFFF3F8)))

        // Spinning star topper inside the box
        let spin = interactPhase > 0.01 ? (time * 9.0) : (sin(time * 1.5) * 0.15)
        var dancer = ctx
        dancer.translateBy(x: 0, y: -14 - CGFloat(interactPhase) * 5)
        dancer.scaleBy(x: max(0.28, CGFloat(abs(cos(spin)))), y: 1)
        let starPath = TidyStar5(inner: 0.48).path(in: CGRect(x: -11, y: -11, width: 22, height: 22))
        TPaint.body(dancer, starPath, TRGB(0xFFE074), CGRect(x: -11, y: -11, width: 22, height: 22), line: 1.8)

        // Wooden music box base with scalloped drawer
        let boxRect = CGRect(x: -26, y: -2, width: 52, height: 36)
        TPaint.body(ctx, Path(roundedRect: boxRect, cornerRadius: 8), c, boxRect, line: 2.3)
        let drawer = Path(roundedRect: CGRect(x: -18, y: 12, width: 36, height: 16), cornerRadius: 4)
        ctx.fill(drawer, with: .color(c.light.color(0.7)))
        ctx.stroke(drawer, with: .color(c.line.color(0.7)), lineWidth: 1.6)
        TPaint.dot(ctx, 0, 20, 3.2, Color(hex: 0xFFE074))
        TPaint.emblem(ctx, 1, at: CGPoint(x: 0, y: 5), size: 10, color: .white.opacity(0.9))

        if interactPhase > 0.08 {
            let rise = CGFloat(1 - interactPhase) * 18
            StorybookArt.sparkle(ctx, at: CGPoint(x: -22, y: -24 - rise), radius: 7, color: Theme.pink, opacity: interactPhase)
            StorybookArt.sparkle(ctx, at: CGPoint(x: 22, y: -28 - rise), radius: 6.5, color: Theme.lemon, opacity: interactPhase)
        }
    }
}
