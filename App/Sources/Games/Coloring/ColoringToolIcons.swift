import SwiftUI

// MARK: - Custom StorybookArt tool icons (10 tools)

struct ColoringToolIcon: View {
    let tool: ColoringTool
    let color: PaintColor
    var stampShape: ColoringStampShape = .cycle

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: side / 100, y: side / 100)
            switch tool {
            case .fill: drawBucket(g)
            case .marker: drawMarker(g)
            case .crayon: drawCrayon(g)
            case .pencil: drawPencil(g)
            case .paint: drawWatercolorBrush(g)
            case .glitter: drawGlitterTube(g)
            case .rainbow: drawRainbowBrush(g)
            case .stamps: drawStamper(g)
            case .eraser: drawEraser(g)
            case .stickers: drawStickerTool(g)
            }
        }
    }

    private var fillColor: Color { Color(.sRGB, red: color.r, green: color.g, blue: color.b) }

    private var tintColor: Color {
        let m = color.mix(.white, 0.35)
        return Color(.sRGB, red: m.r, green: m.g, blue: m.b)
    }

    private var outlineColor: Color { Self.outline(for: color) }

    static func outline(for c: PaintColor) -> Color {
        let lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        if lum > 0.88 {
            return Theme.ink.opacity(0.48)
        }
        let k = 0.62
        return Color(
            .sRGB,
            red: min(1, max(0.18, c.r * k + 0.04)),
            green: min(1, max(0.12, c.g * k * 0.96)),
            blue: min(1, max(0.14, c.b * k * 0.92)),
            opacity: 1
        )
    }

    private func drawBucket(_ g: GraphicsContext) {
        var b = g
        b.translateBy(x: -4, y: 2)
        b.rotate(by: .degrees(26))

        // Wire bail handle
        var handle = Path()
        handle.addArc(center: CGPoint(x: 0, y: -15), radius: 22, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
        b.stroke(handle, with: .color(StorybookArt.outline(for: 0xB8C6D6)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))

        // Bucket body
        var pail = Path()
        pail.move(to: CGPoint(x: -22, y: -14))
        pail.addLine(to: CGPoint(x: 22, y: -14))
        pail.addLine(to: CGPoint(x: 17, y: 24))
        pail.addQuadCurve(to: CGPoint(x: -17, y: 24), control: CGPoint(x: 0, y: 31))
        pail.closeSubpath()
        StorybookArt.fillAndStroke(b, pail, fill: StorybookArt.color(0xEFF5FA), stroke: StorybookArt.outline(for: 0xB8C6D6), width: 3.6)

        // Colored paint stripe around bucket
        var stripe = Path()
        stripe.move(to: CGPoint(x: -20, y: 2))
        stripe.addLine(to: CGPoint(x: 20, y: 2))
        stripe.addLine(to: CGPoint(x: 18.5, y: 15))
        stripe.addQuadCurve(to: CGPoint(x: -18.5, y: 15), control: CGPoint(x: 0, y: 21))
        stripe.closeSubpath()
        StorybookArt.fillAndStroke(b, stripe, fill: fillColor, stroke: outlineColor, width: 2.2)

        // Rim & paint pool inside
        let rim = Path(ellipseIn: CGRect(x: -23, y: -21, width: 46, height: 14))
        StorybookArt.fillAndStroke(b, rim, fill: fillColor, stroke: outlineColor, width: 3.2)

        // Pouring pastel paint drip over the tilted right lip
        var drip = Path()
        drip.move(to: CGPoint(x: 10, y: -14))
        drip.addQuadCurve(to: CGPoint(x: 25, y: -10), control: CGPoint(x: 23, y: -17))
        drip.addCurve(to: CGPoint(x: 24, y: 12), control1: CGPoint(x: 31, y: -3), control2: CGPoint(x: 31, y: 12))
        drip.addCurve(to: CGPoint(x: 16, y: -2), control1: CGPoint(x: 17, y: 12), control2: CGPoint(x: 17, y: 4))
        drip.addQuadCurve(to: CGPoint(x: 7, y: -9), control: CGPoint(x: 11, y: -6))
        drip.closeSubpath()
        StorybookArt.fillAndStroke(b, drip, fill: fillColor, stroke: outlineColor, width: 2.8)
        StorybookArt.highlight(b, in: CGRect(x: 19, y: -6, width: 5, height: 9), opacity: 0.55)

        // Falling paint droplet
        var drop = Path()
        drop.move(to: CGPoint(x: 27, y: 21))
        drop.addQuadCurve(to: CGPoint(x: 33, y: 31), control: CGPoint(x: 34, y: 26))
        drop.addArc(center: CGPoint(x: 27, y: 31), radius: 6, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        drop.addQuadCurve(to: CGPoint(x: 27, y: 21), control: CGPoint(x: 20, y: 26))
        drop.closeSubpath()
        StorybookArt.fillAndStroke(g, drop, fill: fillColor, stroke: outlineColor, width: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: 24, y: 29, width: 3.5, height: 4.5), opacity: 0.6)
    }

    private func drawMarker(_ g: GraphicsContext) {
        var m = g
        m.rotate(by: .degrees(-42))

        // White chunky barrel
        let barrel = Path(roundedRect: CGRect(x: -14, y: -12, width: 46, height: 24), cornerRadius: 9)
        StorybookArt.fillAndStroke(m, barrel, fill: StorybookArt.color(0xFFFDFB), stroke: StorybookArt.outline(for: 0xCFC5D6), width: 3.4)

        // Colored back cap
        let backCap = Path(roundedRect: CGRect(x: 24, y: -12, width: 12, height: 24), cornerRadius: 6)
        StorybookArt.fillAndStroke(m, backCap, fill: fillColor, stroke: outlineColor, width: 3)

        // Colored wrap band
        let band = Path(roundedRect: CGRect(x: -4, y: -12, width: 22, height: 24), cornerRadius: 3)
        StorybookArt.fillAndStroke(m, band, fill: fillColor, stroke: outlineColor, width: 2.8)
        StorybookArt.highlight(m, in: CGRect(x: -10, y: -8, width: 30, height: 5.5), opacity: 0.55)

        // Tapered collar
        var collar = Path()
        collar.move(to: CGPoint(x: -14, y: -10))
        collar.addLine(to: CGPoint(x: -25, y: -6.5))
        collar.addLine(to: CGPoint(x: -25, y: 6.5))
        collar.addLine(to: CGPoint(x: -14, y: 10))
        collar.closeSubpath()
        StorybookArt.fillAndStroke(m, collar, fill: StorybookArt.color(0xF0EDF4), stroke: StorybookArt.outline(for: 0xCFC5D6), width: 3)

        // Chisel / bullet felt tip
        var tip = Path()
        tip.move(to: CGPoint(x: -25, y: -5.5))
        tip.addLine(to: CGPoint(x: -36, y: -3))
        tip.addQuadCurve(to: CGPoint(x: -36, y: 4.5), control: CGPoint(x: -40, y: 1))
        tip.addLine(to: CGPoint(x: -25, y: 5.5))
        tip.closeSubpath()
        StorybookArt.fillAndStroke(m, tip, fill: fillColor, stroke: outlineColor, width: 2.8)
    }

    private func drawCrayon(_ g: GraphicsContext) {
        var c = g
        c.rotate(by: .degrees(-42))

        // Wax body
        let body = Path(roundedRect: CGRect(x: -18, y: -12, width: 54, height: 24), cornerRadius: 5)
        StorybookArt.fillAndStroke(c, body, fill: fillColor, stroke: outlineColor, width: 3.4)

        // Blunt wax tip
        var tip = Path()
        tip.move(to: CGPoint(x: -18, y: -11))
        tip.addLine(to: CGPoint(x: -35, y: -5))
        tip.addQuadCurve(to: CGPoint(x: -35, y: 5), control: CGPoint(x: -39, y: 0))
        tip.addLine(to: CGPoint(x: -18, y: 11))
        tip.closeSubpath()
        StorybookArt.fillAndStroke(c, tip, fill: fillColor, stroke: outlineColor, width: 3.2)

        // Paper wrapper in a lighter pastel tint
        let paper = Path(roundedRect: CGRect(x: -11, y: -12.5, width: 38, height: 25), cornerRadius: 2)
        StorybookArt.fillAndStroke(c, paper, fill: tintColor, stroke: outlineColor, width: 2.8)

        // Classic crayon wrapper stripes + oval emblem
        for sx in [CGFloat(-6), 20] {
            var stripe = Path()
            stripe.move(to: CGPoint(x: sx, y: -11))
            stripe.addLine(to: CGPoint(x: sx, y: 11))
            c.stroke(stripe, with: .color(outlineColor), style: StrokeStyle(lineWidth: 3.4, lineCap: .butt))
        }
        let oval = Path(ellipseIn: CGRect(x: 1, y: -6.5, width: 13, height: 13))
        StorybookArt.fillAndStroke(c, oval, fill: fillColor, stroke: outlineColor, width: 2.2)
        StorybookArt.highlight(c, in: CGRect(x: -14, y: -8.5, width: 38, height: 4.5), opacity: 0.45)
    }

    private func drawPencil(_ g: GraphicsContext) {
        var p = g
        p.rotate(by: .degrees(-42))

        // Pink eraser & brass ferrule
        let eraser = Path(roundedRect: CGRect(x: 24, y: -8.5, width: 14, height: 17), cornerRadius: 6)
        StorybookArt.fillAndStroke(p, eraser, fill: StorybookArt.color(0xFFA6C8), stroke: StorybookArt.outline(for: 0xE57CA4), width: 2.8)
        let ferrule = Path(roundedRect: CGRect(x: 16, y: -9, width: 11, height: 18), cornerRadius: 2)
        StorybookArt.fillAndStroke(p, ferrule, fill: StorybookArt.color(0xFFE59C), stroke: StorybookArt.outline(for: 0xD9A238), width: 2.6)

        // Sleek colored wooden shaft
        let shaft = Path(roundedRect: CGRect(x: -18, y: -9, width: 36, height: 18), cornerRadius: 2)
        StorybookArt.fillAndStroke(p, shaft, fill: fillColor, stroke: outlineColor, width: 3)

        // Subtle facet ridge along center
        var ridge = Path()
        ridge.move(to: CGPoint(x: -16, y: 0))
        ridge.addLine(to: CGPoint(x: 14, y: 0))
        p.stroke(ridge, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        // Sharpened tan wood cone
        var cone = Path()
        cone.move(to: CGPoint(x: -18, y: -8.5))
        cone.addLine(to: CGPoint(x: -38, y: 0))
        cone.addLine(to: CGPoint(x: -18, y: 8.5))
        cone.closeSubpath()
        StorybookArt.fillAndStroke(p, cone, fill: StorybookArt.color(0xF7DFC2), stroke: StorybookArt.outline(for: 0xD4A876), width: 2.8)

        // Colored pencil lead tip
        var lead = Path()
        lead.move(to: CGPoint(x: -30, y: -3.5))
        lead.addLine(to: CGPoint(x: -38, y: 0))
        lead.addLine(to: CGPoint(x: -30, y: 3.5))
        lead.closeSubpath()
        StorybookArt.fillAndStroke(p, lead, fill: fillColor, stroke: outlineColor, width: 2.2)
    }

    private func drawWatercolorBrush(_ g: GraphicsContext) {
        // Soft watercolor wash puddle behind the brush tip
        let wash = Path(ellipseIn: CGRect(x: -34, y: 6, width: 32, height: 22))
        g.fill(wash, with: .color(fillColor.opacity(0.32)))
        g.stroke(wash, with: .color(outlineColor.opacity(0.35)), lineWidth: 2)

        var b = g
        b.rotate(by: .degrees(-42))

        // Tapered wooden handle
        var handle = Path()
        handle.move(to: CGPoint(x: 0, y: -5.5))
        handle.addCurve(to: CGPoint(x: 34, y: -7.5), control1: CGPoint(x: 14, y: -7), control2: CGPoint(x: 26, y: -8.5))
        handle.addCurve(to: CGPoint(x: 34, y: 7.5), control1: CGPoint(x: 41, y: -6), control2: CGPoint(x: 41, y: 6))
        handle.addCurve(to: CGPoint(x: 0, y: 5.5), control1: CGPoint(x: 26, y: 8.5), control2: CGPoint(x: 14, y: 7))
        handle.closeSubpath()
        StorybookArt.fillAndStroke(b, handle, fill: StorybookArt.color(0x9CD4FF), stroke: StorybookArt.outline(for: 0x62A8E5), width: 3)
        StorybookArt.highlight(b, in: CGRect(x: 8, y: -5, width: 20, height: 3.8), opacity: 0.55)

        // Golden ferrule
        let ferrule = Path(roundedRect: CGRect(x: -11, y: -6.5, width: 13, height: 13), cornerRadius: 3)
        StorybookArt.fillAndStroke(b, ferrule, fill: StorybookArt.color(0xFFE6A0), stroke: StorybookArt.outline(for: 0xD9A238), width: 2.8)

        // Fluffy teardrop bristles dipped in paint
        var bristles = Path()
        bristles.move(to: CGPoint(x: -11, y: -7.5))
        bristles.addCurve(to: CGPoint(x: -36, y: 0), control1: CGPoint(x: -22, y: -11), control2: CGPoint(x: -29, y: -4))
        bristles.addCurve(to: CGPoint(x: -11, y: 7.5), control1: CGPoint(x: -29, y: 4), control2: CGPoint(x: -22, y: 11))
        bristles.closeSubpath()
        StorybookArt.fillAndStroke(b, bristles, fill: fillColor, stroke: outlineColor, width: 3)
        StorybookArt.highlight(b, in: CGRect(x: -24, y: -4.5, width: 9, height: 4), opacity: 0.6)
    }

    private func drawGlitterTube(_ g: GraphicsContext) {
        var t = g
        t.rotate(by: .degrees(-28))

        // Pointed squeeze nozzle
        var nozzle = Path()
        nozzle.move(to: CGPoint(x: -6, y: -14))
        nozzle.addLine(to: CGPoint(x: 0, y: -36))
        nozzle.addLine(to: CGPoint(x: 6, y: -14))
        nozzle.closeSubpath()
        StorybookArt.fillAndStroke(t, nozzle, fill: StorybookArt.color(0xFFFDFB), stroke: StorybookArt.outline(for: 0xCFC5D6), width: 2.8)

        let collar = Path(roundedRect: CGRect(x: -11, y: -18, width: 22, height: 8), cornerRadius: 3.5)
        StorybookArt.fillAndStroke(t, collar, fill: StorybookArt.color(0xFFE37D), stroke: StorybookArt.outline(for: 0xDF9E2E), width: 2.6)

        // Glitter glue bottle body
        let bottle = Path(roundedRect: CGRect(x: -17, y: -11, width: 34, height: 42), cornerRadius: 12)
        StorybookArt.fillAndStroke(t, bottle, fill: fillColor, stroke: outlineColor, width: 3.4)
        StorybookArt.highlight(t, in: CGRect(x: -12, y: -6, width: 6.5, height: 28), opacity: 0.45)

        // Twinkling glitter stars inside the tube
        StorybookArt.sparkle(t, at: CGPoint(x: 3, y: 2), radius: 7, color: .white)
        StorybookArt.sparkle(t, at: CGPoint(x: -5, y: 16), radius: 5.5, color: Theme.lemon)
        StorybookArt.sparkle(t, at: CGPoint(x: 8, y: 19), radius: 4.5, color: .white)

        StorybookArt.sparkle(g, at: CGPoint(x: -27, y: -22), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 27, y: -18), radius: 6, color: Theme.pink)
    }

    private func drawRainbowBrush(_ g: GraphicsContext) {
        // Vivid pastel rainbow ribbon sweep
        let bands: [(CGFloat, UInt32)] = [
            (28, 0xFF7FA8), (22, 0xFFB078), (16, 0xFFE378), (10, 0x8CE3C0), (4, 0x82C8FF),
        ]
        let center = CGPoint(x: 0, y: 20)
        for (rad, hex) in bands {
            var arc = Path()
            arc.addArc(center: center, radius: rad, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        }
        // Soft cloud puffs at bottom corners
        for side in [-1.0, 1.0] {
            let cx = CGFloat(side) * 23
            let c1 = Path(ellipseIn: CGRect(x: cx - 10, y: 12, width: 20, height: 17))
            StorybookArt.fillAndStroke(g, c1, fill: .white, stroke: StorybookArt.outline(for: 0xA8D4FF), width: 2.6)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: -25, y: -24), radius: 8, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 26, y: -20), radius: 6.5, color: Theme.pink)
    }

    private func drawStamper(_ g: GraphicsContext) {
        // Wooden knob handle
        let knob = Path(ellipseIn: CGRect(x: -13, y: -36, width: 26, height: 22))
        StorybookArt.shape(g, knob, hex: 0xF3C28A, width: 3.2)
        StorybookArt.highlight(g, in: CGRect(x: -8, y: -32, width: 10, height: 6), opacity: 0.55)

        let neck = Path(roundedRect: CGRect(x: -7, y: -18, width: 14, height: 14), cornerRadius: 4)
        StorybookArt.shape(g, neck, hex: 0xE9B274, width: 2.8)

        // Stamp block base
        let block = Path(roundedRect: CGRect(x: -26, y: -6, width: 52, height: 15), cornerRadius: 6)
        StorybookArt.shape(g, block, hex: 0xF7DFC2, width: 3.2)

        // Colored rubber pad
        let pad = Path(roundedRect: CGRect(x: -22, y: 7, width: 44, height: 8), cornerRadius: 3.5)
        StorybookArt.fillAndStroke(g, pad, fill: fillColor, stroke: outlineColor, width: 2.8)

        // Mini stamp impression underneath reflecting the chosen stamp shape
        switch stampShape {
        case .heart:
            StorybookArt.fillAndStroke(g, VectorDrawer.heartPath(at: CGPoint(x: 0, y: 28), size: 22), fill: fillColor, stroke: outlineColor, width: 2.2)
        case .star:
            StorybookArt.fillAndStroke(g, VectorDrawer.starPath(at: CGPoint(x: 0, y: 28), outer: 12, inner: 5.8), fill: fillColor, stroke: outlineColor, width: 2.2)
        case .sparkle:
            StorybookArt.fillAndStroke(g, VectorDrawer.sparklePath(at: CGPoint(x: 0, y: 28), radius: 12), fill: fillColor, stroke: outlineColor, width: 2.2)
        case .cycle:
            StorybookArt.fillAndStroke(g, VectorDrawer.heartPath(at: CGPoint(x: -14, y: 28), size: 15), fill: fillColor, stroke: outlineColor, width: 1.8)
            StorybookArt.fillAndStroke(g, VectorDrawer.starPath(at: CGPoint(x: 0, y: 28), outer: 9, inner: 4.4), fill: fillColor, stroke: outlineColor, width: 1.8)
            StorybookArt.fillAndStroke(g, VectorDrawer.sparklePath(at: CGPoint(x: 15, y: 28), radius: 8.5), fill: fillColor, stroke: outlineColor, width: 1.8)
        }
    }

    private func drawEraser(_ g: GraphicsContext) {
        var e = g
        e.rotate(by: .degrees(-32))

        // Chunky pink rubber eraser end
        let rubber = Path(roundedRect: CGRect(x: -32, y: -15, width: 36, height: 30), cornerRadius: 8)
        StorybookArt.fillAndStroke(e, rubber, fill: StorybookArt.color(0xFFA6C9), stroke: StorybookArt.outline(for: 0xE86E9E), width: 3.4)

        // Sky-blue paper sleeve
        let sleeve = Path(roundedRect: CGRect(x: -4, y: -16, width: 36, height: 32), cornerRadius: 6)
        StorybookArt.fillAndStroke(e, sleeve, fill: StorybookArt.color(0x98D2FF), stroke: StorybookArt.outline(for: 0x5CA4E5), width: 3.4)

        // Cream band stripe on sleeve
        let stripe = Path(roundedRect: CGRect(x: 6, y: -14, width: 10, height: 28), cornerRadius: 2)
        e.fill(stripe, with: .color(.white.opacity(0.65)))
        StorybookArt.highlight(e, in: CGRect(x: -26, y: -10, width: 16, height: 6), opacity: 0.55)

        // Little clean sweep sparkles under the eraser tip
        StorybookArt.sparkle(g, at: CGPoint(x: -28, y: 26), radius: 6.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -14, y: 31), radius: 4.5, color: Theme.pink)
    }

    private func drawStickerTool(_ g: GraphicsContext) {
        let star = VectorDrawer.starPath(at: CGPoint(x: 0, y: 1), outer: 33, inner: 16.5)
        // White die-cut sticker rim
        g.stroke(star, with: .color(.white), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
        g.fill(star, with: .color(.white))
        StorybookArt.fillAndStroke(g, star, fill: StorybookArt.color(0xFFE16B), stroke: StorybookArt.outline(for: 0xE5A22E), width: 3.2)
        StorybookArt.highlight(g, in: CGRect(x: -13, y: -15, width: 12, height: 7), opacity: 0.65)

        // Cute smiling eyes & blush
        for side in [-1.0, 1.0] {
            let ex = CGFloat(side) * 8
            g.fill(Path(ellipseIn: CGRect(x: ex - 2.6, y: -4, width: 5.2, height: 6)), with: .color(Theme.ink))
            g.fill(Path(ellipseIn: CGRect(x: ex - 4.5, y: 3.5, width: 8, height: 4.5)), with: .color(Theme.pink.opacity(0.65)))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -4, y: 5))
        smile.addQuadCurve(to: CGPoint(x: 4, y: 5), control: CGPoint(x: 0, y: 10))
        g.stroke(smile, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.3, lineCap: .round))

        // Folded peel-up corner
        var peel = Path()
        peel.move(to: CGPoint(x: 13, y: 21))
        peel.addLine(to: CGPoint(x: 23, y: 14))
        peel.addLine(to: CGPoint(x: 20, y: 29))
        peel.closeSubpath()
        StorybookArt.fillAndStroke(g, peel, fill: .white, stroke: StorybookArt.outline(for: 0xE5A22E), width: 2)
    }
}

// MARK: - Unmistakable Stay-in-Lines Pictorial Toggle Icon

struct StayInLinesIcon: View {
    let active: Bool

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: side / 100, y: side / 100)

            let boxRect = CGRect(x: -24, y: -24, width: 48, height: 48)
            let box = Path(roundedRect: boxRect, cornerRadius: 12)

            if active {
                // Crisp outlined box with tidy pastel strokes staying cleanly INSIDE the lines
                g.fill(box, with: .color(.white))
                var clipped = g
                clipped.clip(to: box)
                var wave = Path()
                wave.move(to: CGPoint(x: -16, y: -10))
                wave.addCurve(to: CGPoint(x: 16, y: -10), control1: CGPoint(x: -5, y: -18), control2: CGPoint(x: 5, y: -2))
                wave.addCurve(to: CGPoint(x: -16, y: 4), control1: CGPoint(x: 18, y: 0), control2: CGPoint(x: -18, y: -2))
                wave.addCurve(to: CGPoint(x: 16, y: 12), control1: CGPoint(x: -5, y: 14), control2: CGPoint(x: 6, y: 6))
                clipped.stroke(wave, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                g.stroke(box, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))

                // Little mint lock/check shield badge at top-right corner
                let badge = Path(ellipseIn: CGRect(x: 12, y: -33, width: 22, height: 22))
                StorybookArt.fillAndStroke(g, badge, fill: Theme.mint, stroke: .white, width: 3)
                var check = Path()
                check.move(to: CGPoint(x: 18, y: -22))
                check.addLine(to: CGPoint(x: 22, y: -18))
                check.addLine(to: CGPoint(x: 29, y: -26))
                g.stroke(check, with: .color(.white), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
            } else {
                // Dashed outline box with bold colorful paint splashing freely right OUTSIDE the lines
                g.fill(box, with: .color(.white.opacity(0.9)))
                g.stroke(box, with: .color(Theme.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [7, 5]))
                var splash = Path()
                splash.move(to: CGPoint(x: -36, y: 14))
                splash.addCurve(to: CGPoint(x: 34, y: -16), control1: CGPoint(x: -14, y: -24), control2: CGPoint(x: 10, y: 26))
                g.stroke(splash, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                g.stroke(splash, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                // Stray joyful paint drops outside
                g.fill(Path(ellipseIn: CGRect(x: 27, y: 10, width: 10, height: 10)), with: .color(Theme.sky))
                g.fill(Path(ellipseIn: CGRect(x: -36, y: -22, width: 9, height: 9)), with: .color(Theme.lemon))
            }
        }
    }
}

// MARK: - Stamp shape selector icon

struct StampShapeIcon: View {
    let shape: ColoringStampShape
    let color: PaintColor

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: side / 100, y: side / 100)
            let fill = Color(.sRGB, red: color.r, green: color.g, blue: color.b)
            let stroke = ColoringToolIcon.outline(for: color)

            switch shape {
            case .heart:
                StorybookArt.fillAndStroke(g, VectorDrawer.heartPath(at: .zero, size: 58), fill: fill, stroke: stroke, width: 3.5)
            case .star:
                StorybookArt.fillAndStroke(g, VectorDrawer.starPath(at: CGPoint(x: 0, y: 2), outer: 32, inner: 15.5), fill: fill, stroke: stroke, width: 3.5)
            case .sparkle:
                StorybookArt.fillAndStroke(g, VectorDrawer.sparklePath(at: .zero, radius: 32), fill: fill, stroke: stroke, width: 3.5)
            case .cycle:
                StorybookArt.fillAndStroke(g, VectorDrawer.heartPath(at: CGPoint(x: -19, y: -12), size: 28), fill: fill, stroke: stroke, width: 2.6)
                StorybookArt.fillAndStroke(g, VectorDrawer.starPath(at: CGPoint(x: 18, y: -8), outer: 16, inner: 7.8), fill: fill, stroke: stroke, width: 2.6)
                StorybookArt.fillAndStroke(g, VectorDrawer.sparklePath(at: CGPoint(x: 0, y: 20), radius: 16), fill: fill, stroke: stroke, width: 2.6)
            }
        }
    }
}

// MARK: - Mixer & Empty State Storybook Art

struct MixerPaletteIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: side / 100, y: side / 100)

            var p = Path()
            p.move(to: CGPoint(x: -36, y: 2))
            p.addCurve(to: CGPoint(x: -2, y: -32), control1: CGPoint(x: -36, y: -22), control2: CGPoint(x: -22, y: -32))
            p.addCurve(to: CGPoint(x: 36, y: -6), control1: CGPoint(x: 20, y: -32), control2: CGPoint(x: 36, y: -22))
            p.addCurve(to: CGPoint(x: 20, y: 12), control1: CGPoint(x: 36, y: 6), control2: CGPoint(x: 28, y: 10))
            p.addCurve(to: CGPoint(x: 28, y: 29), control1: CGPoint(x: 12, y: 16), control2: CGPoint(x: 34, y: 21))
            p.addCurve(to: CGPoint(x: -4, y: 35), control1: CGPoint(x: 22, y: 36), control2: CGPoint(x: 8, y: 35))
            p.addCurve(to: CGPoint(x: -36, y: 2), control1: CGPoint(x: -24, y: 35), control2: CGPoint(x: -36, y: 22))
            p.closeSubpath()
            StorybookArt.fillAndStroke(g, p, fill: StorybookArt.color(0xFBF0DF), stroke: StorybookArt.outline(for: 0xDFB888), width: 3.4)

            let hole = Path(ellipseIn: CGRect(x: -18, y: 12, width: 13, height: 10))
            StorybookArt.fillAndStroke(g, hole, fill: .white, stroke: StorybookArt.outline(for: 0xDFB888), width: 2.2)

            let dots: [(CGFloat, CGFloat, UInt32)] = [
                (-20, -4, 0xFF7FA8), (-8, -19, 0xFFE16B), (10, -18, 0x8CE3C0), (21, -4, 0x82C8FF), (4, 2, 0xC9B6FF),
            ]
            for (x, y, hex) in dots {
                StorybookArt.shape(g, Path(ellipseIn: CGRect(x: x - 7, y: y - 6, width: 14, height: 12)), hex: hex, width: 2)
            }
        }
    }
}

struct SpongeWipeIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: side / 100, y: side / 100)

            // Sudsy white bubbles behind & around sponge
            let suds: [(CGFloat, CGFloat, CGFloat)] = [(-26, -16, 9), (26, -18, 10), (24, 18, 8), (-22, 20, 7)]
            for (bx, by, br) in suds {
                StorybookArt.fillAndStroke(
                    g,
                    Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                    fill: .white,
                    stroke: StorybookArt.outline(for: 0x9AD2FF),
                    width: 2.4
                )
            }

            var s = g
            s.rotate(by: .degrees(-18))
            // Scrubby mint top edge
            let scrub = Path(roundedRect: CGRect(x: -28, y: -18, width: 56, height: 12), cornerRadius: 6)
            StorybookArt.shape(s, scrub, hex: 0x8AE3BE, width: 3)
            // Soft sunny yellow sponge body
            let sponge = Path(roundedRect: CGRect(x: -28, y: -10, width: 56, height: 28), cornerRadius: 9)
            StorybookArt.shape(s, sponge, hex: 0xFFE378, width: 3.2)

            // Cute sponge pores
            let pores: [(CGFloat, CGFloat, CGFloat)] = [(-15, 2, 4.2), (2, 7, 3.6), (15, 1, 4.4), (-4, -1, 3)]
            for (px, py, pr) in pores {
                s.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr * 0.8, width: pr * 2, height: pr * 1.6)),
                       with: .color(StorybookArt.shade(for: 0xFFE378, factor: 0.84)))
            }
            StorybookArt.highlight(s, in: CGRect(x: -20, y: -6, width: 18, height: 4.5), opacity: 0.6)
            StorybookArt.sparkle(g, at: CGPoint(x: -30, y: -28), radius: 7, color: .white)
        }
    }
}

struct MixerEmptyHintView: View {
    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)

            // Soft pastel paint-drop placeholders hinting "drop & swirl"
            let blobs: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
                (-54, -8, 28, 0xFF9AC9),
                (54, -8, 28, 0x8FD0FF),
                (0, 32, 26, 0xFFE38A),
            ]
            for (bx, by, br, hex) in blobs {
                let c = Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2))
                g.fill(c, with: .color(StorybookArt.color(hex, alpha: 0.28)))
                g.stroke(c, with: .color(StorybookArt.outline(for: hex).opacity(0.45)),
                         style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [8, 6]))
            }

            // Gentle swirling spiral arrow in center
            var spiral = Path()
            for i in 0...32 {
                let t = CGFloat(i) / 32
                let a = -CGFloat.pi * 0.6 + t * .pi * 2.5
                let r = 8 + t * 24
                let pt = CGPoint(x: cos(a) * r, y: -2 + sin(a) * r * 0.8)
                if i == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
            }
            g.stroke(spiral, with: .color(Theme.ink.opacity(0.32)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -46), radius: 10, color: Theme.lemon, opacity: 0.85)
        }
        .allowsHitTesting(false)
    }
}

/// Cute storybook artist's easel illustration shown when the gallery has no saved drawings yet.
struct ColoringEmptyEaselView: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 260
            var g = ctx
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: s, y: s)

            // Soft pastel rug oval underneath
            g.fill(Path(ellipseIn: CGRect(x: -95, y: 78, width: 190, height: 34)), with: .color(Theme.blush.opacity(0.55)))

            let woodFill = StorybookArt.color(0xEBB986)
            let woodStroke = StorybookArt.outline(for: 0xD4985E)

            // Easel wooden tripod legs
            for (a, b) in [
                (CGPoint(x: 0, y: -96), CGPoint(x: -58, y: 92)),
                (CGPoint(x: 0, y: -96), CGPoint(x: 58, y: 92)),
                (CGPoint(x: 0, y: -102), CGPoint(x: 0, y: 80)),
            ] {
                var leg = Path()
                leg.move(to: a)
                leg.addLine(to: b)
                g.stroke(leg, with: .color(woodStroke), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                g.stroke(leg, with: .color(woodFill), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            }

            // Cream sketchbook board on the easel
            let boardRect = CGRect(x: -76, y: -72, width: 152, height: 112)
            let board = Path(roundedRect: boardRect, cornerRadius: 16)
            StorybookArt.fillAndStroke(g, board, fill: .white, stroke: StorybookArt.outline(for: 0xE2C4A0), width: 5)

            // Faint dotted rainbow & heart invitation on the blank canvas
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: 12), radius: 36, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
            g.stroke(arc, with: .color(Theme.lilac.opacity(0.65)), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [10, 8]))
            let heart = VectorDrawer.heartPath(at: CGPoint(x: 0, y: -2), size: 32)
            g.fill(heart, with: .color(Theme.blush.opacity(0.7)))
            g.stroke(heart, with: .color(Theme.pink.opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))

            // Wooden shelf ledge holding mini paint pots
            let ledge = Path(roundedRect: CGRect(x: -86, y: 34, width: 172, height: 16), cornerRadius: 8)
            StorybookArt.fillAndStroke(g, ledge, fill: woodFill, stroke: woodStroke, width: 4.5)

            let pots: [(CGFloat, UInt32)] = [(-44, 0xFF8FB8), (-16, 0xFFE16B), (12, 0x8CE3C0), (40, 0x82C8FF)]
            for (px, hex) in pots {
                let pot = Path(roundedRect: CGRect(x: px - 9, y: 18, width: 18, height: 18), cornerRadius: 5)
                StorybookArt.shape(g, pot, hex: hex, width: 3)
                StorybookArt.highlight(g, in: CGRect(x: px - 5, y: 21, width: 5, height: 4), opacity: 0.6)
            }

            StorybookArt.sparkle(g, at: CGPoint(x: -94, y: -64), radius: 13, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: 92, y: -56), radius: 11, color: Theme.pink)
            StorybookArt.sparkle(g, at: CGPoint(x: 84, y: 66), radius: 9, color: Theme.sky)
        }
        .frame(width: 260, height: 240)
    }
}
