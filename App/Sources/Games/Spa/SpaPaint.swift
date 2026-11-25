import SwiftUI

extension RGB {
    func c(_ a: Double = 1) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

private func hx(_ s: String) -> RGB { RGB(hex: s) }

/// Repeatable pseudo-random number in 0..<1 so foam blobs keep steady shapes frame to frame.
@inline(__always) func shash(_ i: Int) -> CGFloat {
    var x = UInt32(truncatingIfNeeded: i &* 747796405 &+ 2891336453)
    x = ((x >> ((x >> 28) &+ 4)) ^ x) &* 277803737
    x = (x >> 22) ^ x
    return CGFloat(x % 10000) / 10000
}

// MARK: - Full-bleed pastel bathroom backdrop

struct SpaBackdropView: View {
    var body: some View {
        Canvas(opaque: true) { ctx, size in
            let m = GameStageMap(size: size)
            var g = ctx
            g.translateBy(x: m.origin.x, y: m.origin.y)
            g.scaleBy(x: m.scale, y: m.scale)

            let v = CGRect(
                x: -m.origin.x / m.scale - 4,
                y: -m.origin.y / m.scale - 4,
                width: size.width / m.scale + 8,
                height: size.height / m.scale + 8
            )
            let floorTop: CGFloat = 614

            // Warm pastel blush-pink tiled wall
            g.fill(
                Path(CGRect(x: v.minX, y: v.minY, width: v.width, height: max(0, floorTop - v.minY))),
                with: .linearGradient(
                    Gradient(colors: [hx("#FFF0F6").c(), hx("#FCE0EC").c()]),
                    startPoint: CGPoint(x: 0, y: v.minY),
                    endPoint: CGPoint(x: 0, y: floorTop)
                )
            )

            var grout = Path()
            let tile: CGFloat = 58
            var y = (v.minY / tile).rounded(.down) * tile
            while y < floorTop {
                grout.move(to: CGPoint(x: v.minX, y: y))
                grout.addLine(to: CGPoint(x: v.maxX, y: y))
                y += tile
            }
            var x = (v.minX / tile).rounded(.down) * tile
            while x < v.maxX {
                grout.move(to: CGPoint(x: x, y: v.minY))
                grout.addLine(to: CGPoint(x: x, y: floorTop))
                x += tile
            }
            g.stroke(grout, with: .color(.white.opacity(0.75)), lineWidth: 2.8)

            // Soft mint dado band with scalloped cream molding
            let bandY: CGFloat = 556
            g.fill(Path(CGRect(x: v.minX, y: bandY, width: v.width, height: floorTop - bandY)), with: .color(hx("#C7F0E2").c()))
            g.fill(Path(CGRect(x: v.minX, y: bandY - 5, width: v.width, height: 8)), with: .color(.white.opacity(0.92)))
            g.fill(Path(CGRect(x: v.minX, y: bandY + 3, width: v.width, height: 2)), with: .color(hx("#9ED9C6").c(0.6)))

            // Soft lavender tiled bathroom floor
            g.fill(
                Path(CGRect(x: v.minX, y: floorTop, width: v.width, height: max(0, v.maxY - floorTop))),
                with: .linearGradient(
                    Gradient(colors: [hx("#ECDDF7").c(), hx("#D8C2EE").c()]),
                    startPoint: CGPoint(x: 0, y: floorTop),
                    endPoint: CGPoint(x: 0, y: v.maxY)
                )
            )
            var fl = Path()
            for k in -20...40 {
                let x0 = CGFloat(k) * 84
                fl.move(to: CGPoint(x: x0, y: floorTop))
                fl.addLine(to: CGPoint(x: x0 + (x0 - 512) * 0.55, y: v.maxY))
            }
            for yy in stride(from: floorTop + 34, to: v.maxY, by: 42) {
                fl.move(to: CGPoint(x: v.minX, y: yy))
                fl.addLine(to: CGPoint(x: v.maxX, y: yy))
            }
            g.stroke(fl, with: .color(.white.opacity(0.38)), lineWidth: 2)
            g.fill(Path(CGRect(x: v.minX, y: floorTop - 3, width: v.width, height: 6)), with: .color(hx("#CCAEE2").c()))
        }
    }
}

// MARK: - Main bathroom painter (1024 x 834 design space)

enum SpaPainter {
    static let water = hx("#9FE3F0")
    static let deep = hx("#4FB4CF")

    static func draw(_ ctx: GraphicsContext, sim: SpaSim) {
        let t = sim.time
        drawWallShelf(ctx, t: t)
        drawMirror(ctx, sim: sim)
        drawSteam(ctx, sim: sim)
        drawFaucet(ctx, sim: sim)
        drawTubBack(ctx, sim: sim)
        drawGirl(ctx, sim: sim)
        for th in sim.things where !th.held { ThingPainter.draw(ctx, th, time: t) }
        drawWater(ctx, sim: sim)
        drawFoam(ctx, sim: sim)
        drawYuzuCitrus(ctx, sim: sim)
        drawStream(ctx, sim: sim)
        drawTubFront(ctx, sim: sim)
        for th in sim.things where th.held { ThingPainter.draw(ctx, th, time: t) }
        drawDrops(ctx, sim: sim)
        drawBubbles(ctx, sim: sim)
        drawHearts(ctx, sim: sim)
        drawPops(ctx, sim: sim)
        drawHints(ctx, sim: sim)
        if let tool = sim.tool { ToolPainter.drawHeld(ctx, tool, sim: sim) }
    }

    // MARK: - Wall shelf, candles & arched vanity mirror

    static func drawWallShelf(_ ctx: GraphicsContext, t: Double) {
        // Positioned on the open right wall, clear of the doll's hair, mirror frame, top bar, and brass faucet.
        var g = ctx
        g.translateBy(x: 774, y: 12)
        let shelfY: CGFloat = 204
        let shelf = Path(roundedRect: CGRect(x: 42, y: shelfY, width: 158, height: 14), cornerRadius: 7)
        StorybookArt.fillAndStroke(g, shelf, fill: .white, stroke: StorybookArt.outline(for: 0xF0C4D8), width: 2.5)
        g.fill(Path(roundedRect: CGRect(x: 50, y: shelfY + 11, width: 142, height: 5), cornerRadius: 3), with: .color(hx("#E6B8CD").c(0.45)))

        // Folded pastel towels
        for (i, hex) in [UInt32(0xFFB3CF), 0xBFE8FF, 0xFFF0A8].enumerated() {
            let r = CGRect(x: 132, y: shelfY - CGFloat(i + 1) * 16, width: 60, height: 16)
            StorybookArt.shape(g, Path(roundedRect: r, cornerRadius: 7), hex: hex, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: r.minX + 6, y: r.minY + 3, width: 22, height: 4), opacity: 0.45)
        }

        // Cute potted fern
        var pot = Path()
        pot.move(to: CGPoint(x: 52, y: shelfY - 30))
        pot.addLine(to: CGPoint(x: 88, y: shelfY - 30))
        pot.addLine(to: CGPoint(x: 82, y: shelfY))
        pot.addLine(to: CGPoint(x: 58, y: shelfY))
        pot.closeSubpath()
        for k in 0..<5 {
            let a = -CGFloat.pi / 2 + CGFloat(k - 2) * 0.42
            let base = CGPoint(x: 70, y: shelfY - 30)
            let tip = CGPoint(x: base.x + cos(a) * 42, y: base.y + sin(a) * 42)
            var leaf = Path()
            leaf.move(to: base)
            leaf.addQuadCurve(to: tip, control: CGPoint(x: base.x + cos(a - 0.38) * 28, y: base.y + sin(a - 0.38) * 28))
            leaf.addQuadCurve(to: base, control: CGPoint(x: base.x + cos(a + 0.38) * 28, y: base.y + sin(a + 0.38) * 28))
            StorybookArt.shape(g, leaf, hex: k.isMultiple(of: 2) ? 0x7FCF8E : 0x9EDCA0, width: 2)
        }
        StorybookArt.shape(g, pot, hex: 0xFFC09F, width: 2.4)

        // Glowing spa candle
        let cx: CGFloat = 108
        let candle = Path(roundedRect: CGRect(x: cx - 11, y: shelfY - 34, width: 22, height: 34), cornerRadius: 5)
        StorybookArt.fillAndStroke(g, candle, fill: Theme.cream, stroke: StorybookArt.outline(for: 0xE8C4D4), width: 2.2)
        let fl = 1 + 0.12 * sin(t * 10) + 0.05 * sin(t * 21)
        let tip = CGPoint(x: cx + CGFloat(sin(t * 3)) * 1.4, y: shelfY - 46 - 7 * fl)
        var flame = Path()
        flame.move(to: CGPoint(x: cx - 5, y: shelfY - 37))
        flame.addQuadCurve(to: tip, control: CGPoint(x: cx - 7, y: shelfY - 46))
        flame.addQuadCurve(to: CGPoint(x: cx + 5, y: shelfY - 37), control: CGPoint(x: cx + 7, y: shelfY - 46))
        flame.closeSubpath()
        g.fill(
            Path(ellipseIn: CGRect(x: cx - 22, y: shelfY - 64, width: 44, height: 44)),
            with: .radialGradient(
                Gradient(colors: [hx("#FFE9A0").c(0.5), hx("#FFE9A0").c(0)]),
                center: CGPoint(x: cx, y: shelfY - 42),
                startRadius: 2,
                endRadius: 22
            )
        )
        g.fill(flame, with: .linearGradient(Gradient(colors: [hx("#FFF8CC").c(), hx("#FFAE45").c()]), startPoint: CGPoint(x: cx, y: shelfY - 37), endPoint: tip))
    }

    static func mirrorShape(_ r: CGRect) -> Path {
        var p = Path()
        let rad = r.width / 2
        p.move(to: CGPoint(x: r.minX, y: r.maxY - 22))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 22))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 22, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 22, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 22), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    static func drawMirror(_ g: GraphicsContext, sim: SpaSim) {
        let m = SGeo.mirror
        let frame = mirrorShape(m.insetBy(dx: -13, dy: -13))
        g.fill(
            frame,
            with: .linearGradient(
                Gradient(colors: [hx("#FFECB8").c(), hx("#F0BF68").c(), hx("#DF9F45").c()]),
                startPoint: CGPoint(x: m.minX, y: m.minY),
                endPoint: CGPoint(x: m.maxX, y: m.maxY)
            )
        )
        g.stroke(frame, with: .color(StorybookArt.outline(for: 0xD9963D)), lineWidth: 3.5)

        // Cute golden bow crest at top of arched vanity mirror
        let crest = CGPoint(x: m.midX, y: m.minY - 12)
        for side in [-1.0, 1.0] {
            let wing = Path(ellipseIn: CGRect(x: crest.x + (side < 0 ? -22 : 4), y: crest.y - 8, width: 18, height: 13))
            StorybookArt.fillAndStroke(g, wing, fill: StorybookArt.color(0xFFE394), stroke: StorybookArt.outline(for: 0xD9963D), width: 2.4)
        }
        StorybookArt.fillAndStroke(
            g,
            Path(ellipseIn: CGRect(x: crest.x - 7, y: crest.y - 7, width: 14, height: 14)),
            fill: Theme.pink,
            stroke: StorybookArt.outline(for: 0xD9963D),
            width: 2.2
        )

        let shape = mirrorShape(m)
        var mg = g
        mg.clip(to: shape)
        mg.fill(
            Path(m),
            with: .linearGradient(
                Gradient(colors: [hx("#EBF7FF").c(), hx("#FDE5F2").c()]),
                startPoint: CGPoint(x: m.minX, y: m.minY),
                endPoint: CGPoint(x: m.minX, y: m.maxY)
            )
        )
        mg.fill(Path(ellipseIn: CGRect(x: m.minX + 36, y: m.maxY - 88, width: 156, height: 120)), with: .color(hx("#F6CCE0").c(0.45)))

        var shine = Path()
        shine.move(to: CGPoint(x: m.minX + 26, y: m.minY + 136))
        shine.addLine(to: CGPoint(x: m.minX + 106, y: m.minY + 26))
        shine.addLine(to: CGPoint(x: m.minX + 136, y: m.minY + 26))
        shine.addLine(to: CGPoint(x: m.minX + 56, y: m.minY + 136))
        shine.closeSubpath()
        mg.fill(shine, with: .color(.white.opacity(0.55)))

        let cw = m.width / CGFloat(SGeo.fogCols)
        let ch = m.height / CGFloat(SGeo.fogRows)
        var paths = [Path(), Path(), Path(), Path()]
        for i in sim.fog.indices {
            let f = sim.fog[i]
            guard f > 0.08 else { continue }
            let lv = min(3, Int(f * 4))
            let c = CGPoint(
                x: m.minX + (CGFloat(i % SGeo.fogCols) + 0.5) * cw,
                y: m.minY + (CGFloat(i / SGeo.fogCols) + 0.5) * ch
            )
            let r = cw * 0.96
            paths[lv].addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        for (k, p) in paths.enumerated() {
            mg.fill(p, with: .color(.white.opacity(0.2 + Double(k) * 0.17)))
        }
        g.stroke(shape, with: .color(.white.opacity(0.7)), lineWidth: 2.2)
    }

    static func drawSteam(_ g: GraphicsContext, sim: SpaSim) {
        for s in sim.steam {
            let u = s.age / s.life
            let a = Double(sin(.pi * min(1, u)) * 0.24)
            g.fill(
                Path(ellipseIn: CGRect(x: s.p.x - s.r, y: s.p.y - s.r, width: s.r * 2, height: s.r * 2)),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(a), Color.white.opacity(0)]),
                    center: s.p,
                    startRadius: 0,
                    endRadius: s.r
                )
            )
        }
    }

    // MARK: - Chunky brass faucet

    static func drawFaucet(_ g: GraphicsContext, sim: SpaSim) {
        let brass = Gradient(colors: [hx("#FFF2BE").c(), hx("#F2C25E").c(), hx("#D49438").c(), hx("#FCE29A").c()])
        let brassOutline = StorybookArt.outline(for: 0xD49438)

        // Wall rosette plate
        let plate = Path(ellipseIn: CGRect(x: SGeo.handle.x - 40, y: SGeo.handle.y - 40, width: 80, height: 80))
        g.fill(plate, with: .radialGradient(brass, center: CGPoint(x: SGeo.handle.x - 10, y: SGeo.handle.y - 12), startRadius: 4, endRadius: 46))
        g.stroke(plate, with: .color(brassOutline), lineWidth: 3)

        // Curved brass spout arching down into the tub
        let pipeTop = SGeo.handle.y + 12
        let pipeBot = SGeo.handle.y + 34
        let spoutRimY = SGeo.spout.y - 8
        let nozzleTop = SGeo.spout.y - 12
        var pipe = Path()
        pipe.move(to: CGPoint(x: 842, y: pipeTop))
        pipe.addLine(to: CGPoint(x: 802, y: pipeTop))
        pipe.addQuadCurve(to: CGPoint(x: 794, y: spoutRimY), control: CGPoint(x: 786, y: pipeTop))
        pipe.addLine(to: CGPoint(x: 822, y: spoutRimY))
        pipe.addQuadCurve(to: CGPoint(x: 820, y: pipeBot), control: CGPoint(x: 816, y: pipeBot + 4))
        pipe.addLine(to: CGPoint(x: 842, y: pipeBot))
        pipe.closeSubpath()
        g.fill(pipe, with: .linearGradient(brass, startPoint: CGPoint(x: 790, y: pipeTop), endPoint: CGPoint(x: 842, y: SGeo.spout.y - 4)))
        g.stroke(pipe, with: .color(brassOutline), lineWidth: 2.8)

        let nozzle = Path(roundedRect: CGRect(x: 790, y: nozzleTop, width: 36, height: 13), cornerRadius: 5)
        g.fill(nozzle, with: .linearGradient(brass, startPoint: CGPoint(x: 790, y: nozzleTop), endPoint: CGPoint(x: 826, y: SGeo.spout.y + 1)))
        g.stroke(nozzle, with: .color(brassOutline), lineWidth: 2.4)

        // Chunky rotating brass cross-handle
        var h = g
        h.translateBy(x: SGeo.handle.x, y: SGeo.handle.y)
        h.rotate(by: .radians(Double(sim.handleTurn) * .pi / 2))
        for k in 0..<4 {
            var arm = h
            arm.rotate(by: .radians(Double(k) * .pi / 2))
            let r = Path(roundedRect: CGRect(x: -7, y: -38, width: 14, height: 36), cornerRadius: 7)
            arm.fill(r, with: .linearGradient(brass, startPoint: CGPoint(x: -7, y: -38), endPoint: CGPoint(x: 7, y: 0)))
            arm.stroke(r, with: .color(brassOutline), lineWidth: 2.2)
            let cap = Path(ellipseIn: CGRect(x: -10, y: -48, width: 20, height: 15))
            StorybookArt.fillAndStroke(
                arm,
                cap,
                fill: k.isMultiple(of: 2) ? Theme.pink : Theme.sky,
                stroke: brassOutline,
                width: 2.2
            )
            StorybookArt.highlight(arm, in: CGRect(x: -5, y: -45, width: 7, height: 4), opacity: 0.7)
        }
        let hub = Path(ellipseIn: CGRect(x: -15, y: -15, width: 30, height: 30))
        h.fill(hub, with: .radialGradient(brass, center: CGPoint(x: -4, y: -4), startRadius: 1, endRadius: 18))
        h.stroke(hub, with: .color(brassOutline), lineWidth: 2.6)
    }

    // MARK: - Scalloped clawfoot bathtub

    static func tubShape(_ r: CGRect, top: CGFloat, bottom: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + top, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - top, y: r.minY))
        if top > 0 { p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + top), control: CGPoint(x: r.maxX, y: r.minY)) }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - bottom))
        p.addArc(center: CGPoint(x: r.maxX - bottom, y: r.maxY - bottom), radius: bottom, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + bottom, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + bottom, y: r.maxY - bottom), radius: bottom, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + top))
        if top > 0 { p.addQuadCurve(to: CGPoint(x: r.minX + top, y: r.minY), control: CGPoint(x: r.minX, y: r.minY)) }
        p.closeSubpath()
        return p
    }

    static func tubInner() -> Path {
        tubShape(
            CGRect(x: SGeo.tubL, y: SGeo.lipY - 12, width: SGeo.tubR - SGeo.tubL, height: SGeo.tubBottom - SGeo.lipY + 12),
            top: 0,
            bottom: 58
        )
    }

    private static var tubWindowRect: CGRect {
        CGRect(x: 378, y: SGeo.lipY + 14, width: SGeo.tubR - 390, height: SGeo.tubBottom - SGeo.lipY - 26)
    }

    private static var tubWindowPath: Path {
        Path(roundedRect: tubWindowRect, cornerRadius: 42)
    }

    static func drawTubBack(_ g: GraphicsContext, sim: SpaSim) {
        let porcelainOutline = StorybookArt.outline(for: 0xF2B8CF)

        // Cozy curved porcelain slipper backrest behind her left shoulder
        var backrest = Path()
        backrest.move(to: CGPoint(x: SGeo.tubL - 16, y: SGeo.lipY + 8))
        backrest.addCurve(
            to: CGPoint(x: 392, y: SGeo.lipY),
            control1: CGPoint(x: SGeo.tubL - 10, y: SGeo.lipY - 46),
            control2: CGPoint(x: 280, y: SGeo.lipY - 40)
        )
        backrest.addLine(to: CGPoint(x: SGeo.tubR + 16, y: SGeo.lipY))
        backrest.addLine(to: CGPoint(x: SGeo.tubR + 16, y: SGeo.lipY + 26))
        backrest.addLine(to: CGPoint(x: SGeo.tubL - 16, y: SGeo.lipY + 26))
        backrest.closeSubpath()
        g.fill(
            backrest,
            with: .linearGradient(
                Gradient(colors: [hx("#FFF8FB").c(), hx("#F9DCE9").c()]),
                startPoint: CGPoint(x: 0, y: SGeo.lipY - 40),
                endPoint: CGPoint(x: 0, y: SGeo.lipY + 20)
            )
        )
        g.stroke(backrest, with: .color(porcelainOutline), lineWidth: 3.5)

        // Inner warm enamel bowl
        let inner = tubInner()
        var b = g
        b.clip(to: inner)
        b.fill(
            Path(CGRect(x: SGeo.tubL, y: SGeo.lipY, width: SGeo.tubR - SGeo.tubL, height: SGeo.tubBottom - SGeo.lipY)),
            with: .linearGradient(
                Gradient(colors: [hx("#FFF7FB").c(), hx("#F2E6F2").c()]),
                startPoint: CGPoint(x: 0, y: SGeo.lipY),
                endPoint: CGPoint(x: 0, y: SGeo.tubBottom)
            )
        )

        // Brass drain ring
        b.fill(Path(ellipseIn: CGRect(x: SGeo.drain.x - 20, y: SGeo.drain.y - 5, width: 40, height: 10)), with: .color(hx("#E0B158").c()))
        b.fill(Path(ellipseIn: CGRect(x: SGeo.drain.x - 13, y: SGeo.drain.y - 3, width: 26, height: 6)), with: .color(hx("#6B5240").c()))

        for gl in sim.glitter where gl.settled {
            glitterFleck(b, gl, t: sim.time)
        }
    }

    static func drawTubFront(_ g: GraphicsContext, sim: SpaSim) {
        let porcelainOutline = StorybookArt.outline(for: 0xF2B8CF)
        let goldOutline = StorybookArt.outline(for: 0xD49438)

        // Golden lion-paw claw feet resting on the floor
        for (fx, flip) in [(SGeo.tubL + 58, CGFloat(1)), (SGeo.tubR - 58, CGFloat(-1))] {
            drawClawFoot(g, at: CGPoint(x: fx, y: SGeo.tubBottom + 12), floorY: SGeo.floorY, flip: flip, outline: goldOutline)
        }

        // Main outer cream-pink porcelain shell (solid around the left slipper end & bottom; crystal window over the bathing pool)
        let outerRect = CGRect(
            x: SGeo.tubL - 18,
            y: SGeo.lipY - 2,
            width: SGeo.tubR - SGeo.tubL + 36,
            height: SGeo.tubBottom - SGeo.lipY + 22
        )
        let outer = tubShape(outerRect, top: 10, bottom: 70)

        // Subtle glass shine inside the rounded bath viewing window
        var winClip = g
        winClip.clip(to: tubWindowPath)
        for (x0, wd) in [(CGFloat(420), CGFloat(30)), (466, 12), (690, 24)] {
            var band = Path()
            band.move(to: CGPoint(x: x0, y: SGeo.tubBottom + 10))
            band.addLine(to: CGPoint(x: x0 + 78, y: SGeo.lipY))
            band.addLine(to: CGPoint(x: x0 + 78 + wd, y: SGeo.lipY))
            band.addLine(to: CGPoint(x: x0 + wd, y: SGeo.tubBottom + 10))
            band.closeSubpath()
            winClip.fill(band, with: .color(.white.opacity(0.16)))
        }

        // Solid warm cream-pink porcelain front (everything outside the rounded viewing window)
        var porcelain = outer
        porcelain.addPath(tubWindowPath)
        g.fill(
            porcelain,
            with: .linearGradient(
                Gradient(colors: [hx("#FFF6FA").c(), hx("#FCE0EC").c(), hx("#F4C5D9").c()]),
                startPoint: CGPoint(x: 0, y: SGeo.lipY),
                endPoint: CGPoint(x: 0, y: outerRect.maxY)
            ),
            style: FillStyle(eoFill: true)
        )
        g.stroke(outer, with: .color(porcelainOutline), lineWidth: 4)
        g.stroke(tubWindowPath, with: .color(porcelainOutline.opacity(0.75)), lineWidth: 3)
        g.stroke(Path(roundedRect: tubWindowRect.insetBy(dx: -3, dy: -3), cornerRadius: 45), with: .color(.white.opacity(0.8)), lineWidth: 2)

        // Scalloped porcelain valance along the front-left apron & base
        var scallops = Path()
        let scallopY = SGeo.lipY + 26
        var sx = SGeo.tubL - 10
        while sx < 358 {
            scallops.addArc(
                center: CGPoint(x: sx + 18, y: scallopY),
                radius: 18,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
            sx += 36
        }
        g.stroke(scallops, with: .color(porcelainOutline.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        // Embossed golden heart-shell medallion on the cozy left porcelain panel
        let medC = CGPoint(x: 242, y: 560)
        let med = Path(ellipseIn: CGRect(x: medC.x - 36, y: medC.y - 26, width: 72, height: 52))
        StorybookArt.fillAndStroke(g, med, fill: hx("#FFF2F7").c(), stroke: hx("#F2C978").c(), width: 3)
        StorybookArt.heart(g, at: medC, size: 24, color: Theme.pink.opacity(0.85))
        StorybookArt.highlight(g, in: CGRect(x: medC.x - 24, y: medC.y - 18, width: 20, height: 8), opacity: 0.7)

        // Glossy rolled porcelain lip along the top of the tub
        let lipRect = CGRect(x: SGeo.tubL - 22, y: SGeo.lipY - 2, width: SGeo.tubR - SGeo.tubL + 44, height: 18)
        let lip = Path(roundedRect: lipRect, cornerRadius: 9)
        g.fill(
            lip,
            with: .linearGradient(
                Gradient(colors: [.white, hx("#FFEBF3").c(), hx("#F6CEE0").c()]),
                startPoint: CGPoint(x: 0, y: lipRect.minY),
                endPoint: CGPoint(x: 0, y: lipRect.maxY)
            )
        )
        g.stroke(lip, with: .color(porcelainOutline), lineWidth: 3.2)
        g.fill(
            Path(roundedRect: CGRect(x: lipRect.minX + 18, y: lipRect.minY + 3, width: lipRect.width - 36, height: 5), cornerRadius: 3),
            with: .color(.white.opacity(0.85))
        )

        // Brass drain pull-chain and pink stopper
        let ring = SGeo.plugRing
        let plug = sim.plugOut
            ? CGPoint(x: ring.x - 24, y: ring.y + 92)
            : CGPoint(x: SGeo.drain.x, y: SGeo.drain.y - 8)
        var chain = Path()
        let links = 18
        for k in 0...links {
            let u = CGFloat(k) / CGFloat(links)
            let sag = sin(u * .pi) * (sim.plugOut ? 8 : 16)
            let pt = CGPoint(x: ring.x + (plug.x - ring.x) * u - sag, y: ring.y + (plug.y - ring.y) * u)
            chain.addEllipse(in: CGRect(x: pt.x - 2.4, y: pt.y - 2.4, width: 4.8, height: 4.8))
        }
        g.stroke(chain, with: .color(hx("#D8A64A").c()), lineWidth: 1.8)
        let ringP = Path(ellipseIn: CGRect(x: ring.x - 9, y: ring.y - 9, width: 18, height: 18))
        StorybookArt.fillAndStroke(g, ringP, fill: hx("#FFE6A8").c(), stroke: goldOutline, width: 2.2)
        let stopper = Path(roundedRect: CGRect(x: plug.x - 16, y: plug.y - 7, width: 32, height: 14), cornerRadius: 6)
        StorybookArt.fillAndStroke(g, stopper, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xFF8FB8), width: 2.2)
    }

    private static func drawClawFoot(_ g: GraphicsContext, at top: CGPoint, floorY: CGFloat, flip: CGFloat, outline: Color) {
        var f = g
        f.translateBy(x: top.x, y: top.y)
        f.scaleBy(x: flip, y: 1)
        let h = floorY - top.y

        let gold = Gradient(colors: [hx("#FFF0B5").c(), hx("#F0BC58").c(), hx("#D49030").c()])
        var leg = Path()
        leg.move(to: CGPoint(x: -18, y: -4))
        leg.addQuadCurve(to: CGPoint(x: -28, y: h - 4), control: CGPoint(x: -34, y: h * 0.48))
        leg.addLine(to: CGPoint(x: 24, y: h - 4))
        leg.addQuadCurve(to: CGPoint(x: 18, y: -4), control: CGPoint(x: 26, y: h * 0.4))
        leg.closeSubpath()
        f.fill(leg, with: .linearGradient(gold, startPoint: CGPoint(x: -24, y: 0), endPoint: CGPoint(x: 24, y: h)))
        f.stroke(leg, with: .color(outline), lineWidth: 3)

        // Chunky lion-paw toes clutching a little golden pearl ball
        for tx in [CGFloat(-20), -6, 9] {
            let toe = Path(ellipseIn: CGRect(x: tx - 9, y: h - 14, width: 18, height: 14))
            f.fill(toe, with: .linearGradient(gold, startPoint: CGPoint(x: tx, y: h - 14), endPoint: CGPoint(x: tx, y: h)))
            f.stroke(toe, with: .color(outline), lineWidth: 2.4)
        }
        StorybookArt.highlight(f, in: CGRect(x: -16, y: 4, width: 12, height: 6), opacity: 0.6)
    }

    static func glitterFleck(_ g: GraphicsContext, _ gl: SGlitter, t: Double) {
        let tw = 0.5 + 0.5 * sin(Double(gl.phase) * 2.3 + t * 3)
        let s: CGFloat = 2.2 + 2.2 * CGFloat(tw)
        g.fill(Twinkle().path(in: CGRect(x: gl.p.x - s, y: gl.p.y - s, width: s * 2, height: s * 2)), with: .color(gl.color.c(0.6 + 0.4 * tw)))
    }

    // MARK: - The doll (with full BeautyPainter makeup & live SpaExpression!)

    static func drawGirl(_ ctx: GraphicsContext, sim: SpaSim) {
        let expr = sim.spaExpression()
        let dollExpr = sim.expression()
        guard let allLayers = sim.layers[dollExpr] else { return }

        // Solidly clip her lower body behind the clawfoot tub front instead of fading like a ghost.
        var clipped = ctx
        clipped.clip(to: Path(CGRect(x: 0, y: 0, width: 1024, height: SGeo.lipY + 56)))

        var g = clipped
        g.translateBy(x: SGeo.dollOrigin.x, y: SGeo.dollOrigin.y + sim.bob)
        g.scaleBy(x: SGeo.dollScale, y: SGeo.dollScale)

        let customMouth = expr == .surprised || expr == .sneeze
        let drawLayers = customMouth ? allLayers.filter { $0.2.category != "mouth" } : allLayers

        var prev = -Double.infinity
        var drewMask = false
        for (layer, p, _) in drawLayers {
            let zz = Double(layer.z)
            if !drewMask && zz >= 40 {
                BeautyPainter.passes(sim.look, from: prev, to: 39.5, t: sim.time, in: g)
                prev = 39.5
                drawMask(g, sim: sim)
                drewMask = true
            }
            BeautyPainter.passes(sim.look, from: prev, to: zz, t: sim.time, in: g)
            prev = zz
            ArtPainter.draw(layer.shapes, p, in: g)
        }
        if !drewMask {
            drawMask(g, sim: sim)
        }
        BeautyPainter.passes(sim.look, from: prev, to: .infinity, t: sim.time, in: g)

        // Live expressive overlays
        drawExpressionOverlay(g, expr: expr, time: sim.time)

        // Paired cucumber slices neatly on both eyes
        if sim.cucumbersOn {
            for eye in SGeo.eyes {
                var c = g
                c.translateBy(x: eye.x, y: eye.y + 4)
                ToolPainter.cucumber(c, r: 44)
            }
        }

        // Jjimjilbang sheep-horn towel hat (양머리) wrapped snugly above her brow
        if sim.sheepTowelOn {
            drawSheepTowelHat(g, tint: sim.sheepTowelTint, time: sim.time)
        }

        // Cozy pink spa-towel wrap glow around her shoulders
        if sim.cozyActive {
            drawCozyTowelWrap(g, time: sim.time)
        }

        // Shoulder suds
        var sudBlobs: [(CGPoint, CGFloat)] = []
        for s in sim.suds {
            let w = CGFloat(sin(sim.time * 2 + Double(s.phase))) * 1.2
            sudBlobs.append((CGPoint(x: s.d.x, y: s.d.y + w), s.r))
        }
        foamBlobs(g, sudBlobs, color: RGB(1, 1, 1))

        // Bouncy silly foam puffs (crowns, bunny ears, bubble beard)
        drawFoamPuffs(g, sim: sim)

        // Water beads on her skin
        for b in sim.beads {
            let r = CGRect(x: b.d.x - b.r, y: b.d.y - b.r * 1.15, width: b.r * 2, height: b.r * 2.3)
            g.fill(Path(ellipseIn: r), with: .color(hx("#CDEFFF").c(0.38)))
            g.stroke(Path(ellipseIn: r), with: .color(.white.opacity(0.75)), lineWidth: 1.5)
            g.fill(
                Path(ellipseIn: CGRect(x: b.d.x - b.r * 0.5, y: b.d.y - b.r * 0.8, width: b.r * 0.6, height: b.r * 0.6)),
                with: .color(.white.opacity(0.95))
            )
        }
    }

    private static func drawExpressionOverlay(_ g: GraphicsContext, expr: SpaExpression, time: Double) {
        switch expr {
        case .surprised:
            let o = Path(ellipseIn: CGRect(x: SGeo.mouth.x - 13, y: SGeo.mouth.y - 12, width: 26, height: 24))
            StorybookArt.fillAndStroke(g, o, fill: hx("#FF7E9D").c(), stroke: Shades.ink.c(), width: 3.5)
            StorybookArt.highlight(g, in: CGRect(x: SGeo.mouth.x - 6, y: SGeo.mouth.y - 8, width: 7, height: 5), opacity: 0.65)
            for side in [-1.0, 1.0] {
                StorybookArt.sparkle(g, at: CGPoint(x: 300 + CGFloat(side) * 142, y: 242), radius: 12, color: Theme.sky, opacity: 0.9)
            }

        case .sneeze:
            // Cute scrunched cartoon sneeze face & rosy booped nose
            let mouth = Path(ellipseIn: CGRect(x: SGeo.mouth.x - 18, y: SGeo.mouth.y - 10, width: 36, height: 24))
            StorybookArt.fillAndStroke(g, mouth, fill: hx("#FF6E92").c(), stroke: Shades.ink.c(), width: 3.5)
            g.fill(Path(ellipseIn: CGRect(x: SGeo.nose.x - 14, y: SGeo.nose.y - 10, width: 28, height: 20)), with: .color(Theme.pink.opacity(0.55)))
            for side in [-1.0, 1.0] {
                let s = CGFloat(side)
                var puffLine = Path()
                puffLine.move(to: CGPoint(x: SGeo.nose.x + s * 22, y: SGeo.nose.y))
                puffLine.addLine(to: CGPoint(x: SGeo.nose.x + s * 46, y: SGeo.nose.y - 10))
                puffLine.move(to: CGPoint(x: SGeo.nose.x + s * 24, y: SGeo.nose.y + 8))
                puffLine.addLine(to: CGPoint(x: SGeo.nose.x + s * 48, y: SGeo.nose.y + 12))
                g.stroke(puffLine, with: .color(.white.opacity(0.92)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }

        case .zen:
            let sway = CGFloat(sin(time * 2.5)) * 6
            StorybookArt.sparkle(g, at: CGPoint(x: 158, y: 220 + sway), radius: 11, color: Theme.lemon, opacity: 0.9)
            StorybookArt.sparkle(g, at: CGPoint(x: 444, y: 230 - sway), radius: 9, color: Theme.mint, opacity: 0.9)

        case .giggle:
            for side in [-1.0, 1.0] {
                g.fill(
                    Path(ellipseIn: CGRect(x: 300 + CGFloat(side) * 78 - 22, y: 356, width: 44, height: 22)),
                    with: .color(Theme.pink.opacity(0.32))
                )
            }

        case .cozy:
            for side in [-1.0, 1.0] {
                g.fill(
                    Path(ellipseIn: CGRect(x: 300 + CGFloat(side) * 76 - 20, y: 358, width: 40, height: 20)),
                    with: .color(Theme.pink.opacity(0.38))
                )
            }

        case .happy:
            break
        }
    }

    private static func drawCozyTowelWrap(_ g: GraphicsContext, time: Double) {
        let pulse = 0.85 + 0.15 * sin(time * 4)
        g.fill(
            Path(ellipseIn: CGRect(x: 168, y: 398, width: 264, height: 112)),
            with: .radialGradient(
                Gradient(colors: [Theme.pink.opacity(0.32 * pulse), Theme.pink.opacity(0)]),
                center: CGPoint(x: 300, y: 454),
                startRadius: 20,
                endRadius: 132
            )
        )
        var wrap = Path()
        wrap.move(to: CGPoint(x: 198, y: 438))
        wrap.addQuadCurve(to: CGPoint(x: 300, y: 462), control: CGPoint(x: 246, y: 464))
        wrap.addQuadCurve(to: CGPoint(x: 402, y: 438), control: CGPoint(x: 354, y: 464))
        wrap.addLine(to: CGPoint(x: 416, y: 504))
        wrap.addLine(to: CGPoint(x: 184, y: 504))
        wrap.closeSubpath()
        StorybookArt.fillAndStroke(g, wrap, fill: hx("#FFB8D4").c(), stroke: StorybookArt.outline(for: 0xF084AE), width: 4)
        StorybookArt.highlight(g, in: CGRect(x: 214, y: 448, width: 54, height: 12), opacity: 0.45)
    }

    static func sheepTowelPalette(_ tint: FoamTint) -> (base: RGB, trim: RGB) {
        switch tint {
        case .cloud: return (hx("#FFF5EE"), hx("#FFB3CF"))
        case .berry: return (hx("#FFD0E2"), hx("#FFFFFF"))
        case .lavender: return (hx("#E3D5FF"), hx("#FFFFFF"))
        case .mint: return (hx("#C7F5E5"), hx("#FFFFFF"))
        }
    }

    private static func drawSheepTowelHat(_ g: GraphicsContext, tint: FoamTint, time: Double) {
        let (base, trim) = sheepTowelPalette(tint)
        let light = Shades.light(base)
        let shade = Shades.shade(base)
        let stroke = Shades.outline(base)
        let spiralInk = shade.mix(stroke, 0.42)

        // Two plush rolled jjimjilbang sheep-horn buns on left & right temples
        for side in [CGFloat(-1), 1] {
            var bun = g
            bun.translateBy(x: 300 + side * 144, y: 214)
            bun.rotate(by: .radians(Double(side) * 0.2))

            let outer = Path(ellipseIn: CGRect(x: -42, y: -48, width: 84, height: 96))
            bun.fill(
                outer,
                with: .linearGradient(
                    Gradient(colors: [light.c(), base.c(), shade.c()]),
                    startPoint: CGPoint(x: 0, y: -48),
                    endPoint: CGPoint(x: 0, y: 48)
                )
            )
            bun.stroke(outer, with: .color(stroke.c()), lineWidth: 4.5)

            // Rolled terry-cloth spiral rings
            var spiral = Path()
            let steps = 42
            for k in 0...steps {
                let u = CGFloat(k) / CGFloat(steps)
                let a = u * 3.8 * .pi + (side < 0 ? 0.4 : .pi - 0.4)
                let r = 4 + u * 27
                let pt = CGPoint(x: cos(a) * r * 0.92 * side, y: sin(a) * r * 1.06)
                if k == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
            }
            bun.stroke(spiral, with: .color(spiralInk.c(0.85)), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            StorybookArt.highlight(bun, in: CGRect(x: -24, y: -36, width: 22, height: 12), opacity: 0.65)
        }

        // Folded arched terry-cloth crown band across her forehead
        var band = Path()
        band.move(to: CGPoint(x: 164, y: 236))
        band.addCurve(to: CGPoint(x: 436, y: 236), control1: CGPoint(x: 222, y: 124), control2: CGPoint(x: 378, y: 124))
        band.addQuadCurve(to: CGPoint(x: 422, y: 256), control: CGPoint(x: 438, y: 252))
        band.addCurve(to: CGPoint(x: 178, y: 256), control1: CGPoint(x: 358, y: 204), control2: CGPoint(x: 242, y: 204))
        band.addQuadCurve(to: CGPoint(x: 164, y: 236), control: CGPoint(x: 162, y: 252))
        band.closeSubpath()

        g.fill(
            band,
            with: .linearGradient(
                Gradient(colors: [light.c(), base.c(), shade.c()]),
                startPoint: CGPoint(x: 300, y: 142),
                endPoint: CGPoint(x: 300, y: 254)
            )
        )
        g.stroke(band, with: .color(stroke.c()), lineWidth: 4.5)

        // Folded towel cuff stripe + terry crease
        var stripe = Path()
        stripe.move(to: CGPoint(x: 184, y: 244))
        stripe.addCurve(to: CGPoint(x: 416, y: 244), control1: CGPoint(x: 246, y: 192), control2: CGPoint(x: 354, y: 192))
        g.stroke(stripe, with: .color(trim.c(0.85)), style: StrokeStyle(lineWidth: 7, lineCap: .round))

        var crease = Path()
        crease.move(to: CGPoint(x: 196, y: 212))
        crease.addCurve(to: CGPoint(x: 404, y: 212), control1: CGPoint(x: 252, y: 162), control2: CGPoint(x: 348, y: 162))
        g.stroke(crease, with: .color(spiralInk.c(0.42)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

        StorybookArt.highlight(g, in: CGRect(x: 246, y: 158, width: 64, height: 14), opacity: 0.65)
        let tw = 0.5 + 0.5 * sin(time * 3.4)
        StorybookArt.sparkle(g, at: CGPoint(x: 368, y: 152), radius: 10, color: Theme.lemon, opacity: 0.45 + 0.45 * tw)
    }

    private static func drawFoamPuffs(_ g: GraphicsContext, sim: SpaSim) {
        guard !sim.foamPuffs.isEmpty else { return }
        for puff in sim.foamPuffs {
            let c = puff.position
            let r = puff.radius
            var blobs: [(CGPoint, CGFloat)] = [(c, r)]
            for k in 0..<4 {
                let a = CGFloat(k) * .pi * 0.5 + shash(puff.seed + k) * 1.1
                let dist = r * (0.55 + 0.25 * shash(puff.seed + k + 20))
                let sr = r * (0.45 + 0.22 * shash(puff.seed + k + 40))
                let wob = CGFloat(sin(sim.time * 2.4 + Double(puff.seed + k))) * 1.4
                blobs.append((CGPoint(x: c.x + cos(a) * dist, y: c.y + sin(a) * dist + wob), sr))
            }
            var pg = g
            if puff.flung {
                pg.opacity = Double(max(0, 1 - puff.age / 0.9))
            }
            foamBlobs(pg, blobs, color: puff.tint)
            if puff.seed.isMultiple(of: 2) {
                let tw = 0.45 + 0.55 * abs(sin(sim.time * 3 + Double(puff.seed)))
                StorybookArt.sparkle(pg, at: CGPoint(x: c.x - r * 0.45, y: c.y - r * 0.6), radius: 5.5, color: .white, opacity: tw)
            }
        }
    }

    static func drawMask(_ ctx: GraphicsContext, sim: SpaSim) {
        guard sim.maskCov.contains(where: { $0 > 0.05 }) else { return }
        var g = ctx
        var clip = Path(ellipseIn: CGRect(
            x: SGeo.headC.x - SGeo.headRX + 4,
            y: SGeo.headC.y - SGeo.headRY + 4,
            width: (SGeo.headRX - 4) * 2,
            height: (SGeo.headRY - 4) * 2
        ))
        for e in SGeo.eyes {
            clip.addEllipse(in: CGRect(x: e.x - 45, y: e.y - 38, width: 90, height: 76))
        }
        clip.addEllipse(in: CGRect(x: SGeo.mouth.x - 24, y: SGeo.mouth.y - 16, width: 48, height: 32))
        g.clip(to: clip, style: FillStyle(eoFill: true))

        let r = SGeo.maskRect
        let cw = r.width / CGFloat(SGeo.maskCols)
        for k in MaskKind.allCases {
            var body = Path(), gloss = Path(), specks = Path()
            var dry: CGFloat = 0, n: CGFloat = 0
            for i in sim.maskCov.indices where sim.maskCov[i] > 0.05 && sim.maskKind[i] == k.rawValue {
                let c = sim.maskCellCenter(i)
                let cov = sim.maskCov[i]
                let rr = cw * (0.48 + 0.6 * sqrt(cov))
                body.addEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
                dry += sim.maskDry[i]
                n += 1
                if sim.maskDry[i] < 0.7 && shash(i * 3) < 0.45 {
                    gloss.addEllipse(in: CGRect(x: c.x - rr * 0.5, y: c.y - rr * 0.6, width: rr * 0.55, height: rr * 0.35))
                }
                if shash(i * 7 + 1) < 0.45 {
                    specks.addEllipse(in: CGRect(x: c.x + (shash(i) - 0.5) * cw, y: c.y + (shash(i + 99) - 0.5) * cw, width: 2.4, height: 2.4))
                }
            }
            guard n > 0 else { continue }
            let avgDry = Double(dry / n)
            let col = k.color.mix(RGB(1, 1, 1), avgDry * 0.25)
            g.fill(body, with: .color(col.c(0.92)))
            g.fill(specks, with: .color(Shades.shade(col).c(0.45)))
            g.fill(gloss, with: .color(.white.opacity(0.55 * (1 - avgDry * 0.6))))
        }
    }

    // MARK: - Water, foam, stream, drops, bubbles, hearts, pops, hints

    static func surfacePath(_ sim: SpaSim) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: SGeo.tubL, y: sim.level + sim.h[0]))
        for i in 0..<SGeo.columns {
            p.addLine(to: CGPoint(x: SGeo.colX(i), y: sim.level + sim.h[i]))
        }
        p.addLine(to: CGPoint(x: SGeo.tubR, y: sim.level + sim.h[SGeo.columns - 1]))
        return p
    }

    static func drawWater(_ ctx: GraphicsContext, sim: SpaSim) {
        guard sim.vol > 0.3 else { return }
        var g = ctx
        g.clip(to: tubInner())
        var body = surfacePath(sim)
        body.addLine(to: CGPoint(x: SGeo.tubR, y: SGeo.tubBottom + 2))
        body.addLine(to: CGPoint(x: SGeo.tubL, y: SGeo.tubBottom + 2))
        body.closeSubpath()

        let top = sim.level - 20
        g.fill(
            body,
            with: .linearGradient(
                Gradient(colors: [water.c(0.42), deep.c(0.68)]),
                startPoint: CGPoint(x: 0, y: top),
                endPoint: CGPoint(x: 0, y: SGeo.tubBottom)
            )
        )
        if sim.soapiness > 0.02 {
            g.fill(body, with: .color(Color.white.opacity(Double(sim.soapiness) * 0.24)))
        }
        if sim.tintA.contains(where: { $0 > 0.02 }) {
            var stops: [Gradient.Stop] = []
            let n = 16
            for k in 0...n {
                let i = min(SGeo.columns - 1, k * SGeo.columns / n)
                stops.append(.init(color: sim.tint[i].c(Double(min(0.75, sim.tintA[i] * 0.88))), location: CGFloat(k) / CGFloat(n)))
            }
            g.fill(body, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: SGeo.tubL, y: 0), endPoint: CGPoint(x: SGeo.tubR, y: 0)))
        }

        var w = g
        w.clip(to: body)
        for p in sim.puffs {
            w.fill(
                Path(ellipseIn: CGRect(x: p.p.x - p.r, y: p.p.y - p.r, width: p.r * 2, height: p.r * 2)),
                with: .radialGradient(Gradient(colors: [p.color.c(Double(p.a)), p.color.c(0)]), center: p.p, startRadius: 0, endRadius: p.r)
            )
        }

        let energy = min(1, sim.hv.reduce(0) { $0 + abs($1) } / 900)
        var caustic = Path()
        let t = sim.time
        for j in 0..<24 {
            let x = SGeo.tubL + 20 + CGFloat(j) * 30 + CGFloat(sin(t * 0.8 + Double(j) * 1.7)) * 10
            let y = SGeo.tubBottom - 10 - CGFloat(j % 3) * 8
            let wv = 18 + CGFloat(sin(t * 1.3 + Double(j))) * 6
            caustic.move(to: CGPoint(x: x, y: y))
            caustic.addQuadCurve(to: CGPoint(x: x + wv, y: y + 2), control: CGPoint(x: x + wv / 2, y: y - 6 + CGFloat(sin(t * 2 + Double(j))) * 3))
        }
        w.stroke(caustic, with: .color(.white.opacity(0.2 + 0.3 * Double(energy))), lineWidth: 2.2)

        for gl in sim.glitter where !gl.settled { glitterFleck(w, gl, t: t) }

        var rims = Path(), glints = Path()
        for b in sim.air {
            let r = CGRect(x: b.p.x - b.r, y: b.p.y - b.r, width: b.r * 2, height: b.r * 2 * 0.92)
            rims.addEllipse(in: r)
            glints.addEllipse(in: CGRect(x: b.p.x - b.r * 0.55, y: b.p.y - b.r * 0.6, width: b.r * 0.6, height: b.r * 0.5))
        }
        w.fill(rims, with: .color(.white.opacity(0.18)))
        w.stroke(rims, with: .color(.white.opacity(0.75)), lineWidth: 1.1)
        w.fill(glints, with: .color(.white.opacity(0.9)))

        let s = surfacePath(sim)
        g.stroke(s, with: .color(.white.opacity(0.88)), lineWidth: 3.2)
        g.stroke(s.offsetBy(dx: 0, dy: 5), with: .color(.white.opacity(0.26)), lineWidth: 4)
        if sim.yuzuCitrus > 0.02 {
            let glowA = Double(sim.yuzuCitrus) * (0.55 + 0.15 * sin(t * 3.2))
            g.stroke(
                s.offsetBy(dx: 0, dy: 2.5),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: 0xFFF5B8).opacity(glowA),
                        Color(hex: 0xFFD24A).opacity(glowA),
                        Color(hex: 0xFFF5B8).opacity(glowA),
                    ]),
                    startPoint: CGPoint(x: SGeo.tubL, y: 0),
                    endPoint: CGPoint(x: SGeo.tubR, y: 0)
                ),
                lineWidth: 5
            )
        }

        if sim.drainFlow > 0.05 && sim.vol > 2 {
            var sw = Path()
            let c = CGPoint(x: SGeo.drain.x, y: SGeo.drain.y - 6)
            let hgt = min(sim.vol, 110)
            for k in 0..<3 {
                let ph = t * 6.5 + Double(k) * 2.1
                for q in 0..<24 {
                    let u = CGFloat(q) / 23
                    let ang = CGFloat(ph) + u * 9
                    let rad = 6 + u * 22
                    let pt = CGPoint(x: c.x + cos(ang) * rad, y: c.y - u * hgt + sin(ang) * rad * 0.25)
                    if q == 0 { sw.move(to: pt) } else { sw.addLine(to: pt) }
                }
            }
            g.stroke(sw, with: .color(.white.opacity(0.55 * Double(sim.drainFlow))), lineWidth: 2.2)
        }
    }

    static func foamBlobs(_ g: GraphicsContext, _ blobs: [(CGPoint, CGFloat)], color: RGB) {
        guard !blobs.isEmpty else { return }
        var shade = Path(), main = Path(), hi = Path(), rims = Path()
        for (k, (c, r)) in blobs.enumerated() {
            shade.addEllipse(in: CGRect(x: c.x - r, y: c.y - r + r * 0.22, width: r * 2, height: r * 2))
            main.addEllipse(in: CGRect(x: c.x - r * 0.96, y: c.y - r, width: r * 1.92, height: r * 1.9))
            hi.addEllipse(in: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.7, width: r * 0.55, height: r * 0.4))
            if k.isMultiple(of: 3) {
                rims.addEllipse(in: CGRect(x: c.x - r * 0.3, y: c.y - r * 0.1, width: r * 0.6, height: r * 0.6))
            }
        }
        g.fill(shade, with: .color(Shades.shade(color).mix(hx("#C7D4EC"), 0.38).c(0.95)))
        g.fill(main, with: .color(color.mix(RGB(1, 1, 1), 0.45).c()))
        g.stroke(rims, with: .color(Shades.shade(color).c(0.32)), lineWidth: 1)
        g.fill(hi, with: .color(.white))
    }

    static func drawYuzuCitrus(_ ctx: GraphicsContext, sim: SpaSim) {
        guard sim.yuzuCitrus > 0.02, sim.hasWater else { return }
        var g = ctx
        g.clip(to: Path(CGRect(x: SGeo.tubL + 10, y: SGeo.lipY - 40, width: SGeo.tubR - SGeo.tubL - 20, height: SGeo.tubBottom - SGeo.lipY + 42)))
        let t = sim.time
        let alpha = Double(min(1, sim.yuzuCitrus))
        let slices: [(baseX: CGFloat, radius: CGFloat, phase: Double)] = [
            (430, 17, 0.2),
            (548, 19, 1.8),
            (668, 16, 3.3),
            (772, 18, 4.9),
        ]
        let rindOutline = StorybookArt.outline(for: 0xF5B82E, factor: 0.65)
        for (idx, s) in slices.enumerated() {
            let drift = CGFloat(sin(t * 0.75 + s.phase)) * 16
            let x = max(SGeo.bodyR + 24, min(SGeo.tubR - 28, s.baseX + drift))
            let y = sim.surfaceY(x) + 1 + CGFloat(sin(t * 2.4 + s.phase)) * 2.5
            let tilt = Double(sim.slope(x)) * 0.8 + sin(t * 1.9 + s.phase) * 0.08
            let r = s.radius * CGFloat(0.6 + 0.4 * alpha)

            var c = g
            c.opacity = alpha
            c.translateBy(x: x, y: y)
            c.rotate(by: .radians(tilt))
            c.scaleBy(x: 1, y: 0.52)

            let outer = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
            StorybookArt.fillAndStroke(c, outer, fill: Color(hex: 0xFFD23E), stroke: rindOutline, width: 2.2)

            let pithR = r * 0.82
            let pith = Path(ellipseIn: CGRect(x: -pithR, y: -pithR, width: pithR * 2, height: pithR * 2))
            c.fill(pith, with: .color(Color(hex: 0xFFF9DE)))

            let pulpR = r * 0.68
            for seg in 0..<6 {
                let a0 = CGFloat(seg) / 6 * 2 * .pi + 0.14
                let a1 = CGFloat(seg + 1) / 6 * 2 * .pi - 0.14
                var wedge = Path()
                wedge.move(to: .zero)
                wedge.addArc(center: .zero, radius: pulpR, startAngle: .radians(Double(a0)), endAngle: .radians(Double(a1)), clockwise: false)
                wedge.closeSubpath()
                c.fill(wedge, with: .color(Color(hex: 0xFFE266)))
            }
            c.fill(Path(ellipseIn: CGRect(x: -2.2, y: -2.2, width: 4.4, height: 4.4)), with: .color(.white))

            if idx.isMultiple(of: 2) {
                let tw = 0.65 + 0.35 * sin(t * 4.2 + s.phase)
                StorybookArt.sparkle(g, at: CGPoint(x: x + r * 0.55, y: y - 9), radius: 5.5 * CGFloat(tw), color: Theme.lemon, opacity: alpha * tw)
            }
        }
    }

    static func drawFoam(_ ctx: GraphicsContext, sim: SpaSim) {
        guard sim.totalFoam > 0.05 else { return }
        var g = ctx
        g.clip(to: Path(CGRect(x: SGeo.tubL - 12, y: 0, width: SGeo.tubR - SGeo.tubL + 24, height: SGeo.tubBottom)))
        let t = sim.time
        let group = 10
        var start = 0
        while start < SGeo.columns {
            let end = min(SGeo.columns, start + group)
            var blobs: [(CGPoint, CGFloat)] = []
            var tr = 0.0, tg = 0.0, tb = 0.0, wsum = 0.0
            for i in start..<end {
                let f = sim.foam[i]
                guard f > 0.03 else { continue }
                let wgt = Double(f)
                tr += sim.foamTint[i].r * wgt
                tg += sim.foamTint[i].g * wgt
                tb += sim.foamTint[i].b * wgt
                wsum += wgt
                let x0 = SGeo.colX(i)
                let count = 1 + Int(min(3, f * 2.2))
                for k in 0..<count {
                    let seed = i * 7 + k
                    let x = x0 + (shash(seed) - 0.5) * 9
                    let size = (5.5 + 10.5 * shash(seed + 31)) * (0.5 + 0.5 * min(1.3, f))
                    let lift = f * 20 * shash(seed + 57)
                    let wob = CGFloat(sin(t * 1.4 + Double(seed))) * 0.8
                    let y = sim.surfaceY(x) - lift - size * 0.25 + 4 + wob
                    blobs.append((CGPoint(x: x, y: y), size))
                }
            }
            if wsum > 0 {
                foamBlobs(g, blobs, color: RGB(tr / wsum, tg / wsum, tb / wsum))
            }
            start = end
        }
    }

    static func drawStream(_ g: GraphicsContext, sim: SpaSim) {
        guard sim.flow > 0.03 else { return }
        let top = SGeo.spout
        let land = sim.streamLanding
        let w = 4 + 8 * sim.flow
        var p = Path()
        let n = 14
        var left: [CGPoint] = [], right: [CGPoint] = []
        for k in 0...n {
            let u = CGFloat(k) / CGFloat(n)
            let y = top.y + (land.y - top.y) * u
            let x = top.x + (land.x - top.x) * u * u + CGFloat(sin(sim.time * 30 + Double(k))) * 0.8 * u
            let ww = w * (1 - 0.35 * u)
            left.append(CGPoint(x: x - ww / 2, y: y))
            right.append(CGPoint(x: x + ww / 2, y: y))
        }
        p.move(to: left[0])
        for q in left.dropFirst() { p.addLine(to: q) }
        for q in right.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        g.fill(
            p,
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.9), water.c(0.75), Color.white.opacity(0.85)]),
                startPoint: CGPoint(x: top.x - w, y: 0),
                endPoint: CGPoint(x: top.x + w, y: 0)
            )
        )
        var core = Path()
        core.move(to: CGPoint(x: top.x - w * 0.15, y: top.y))
        core.addLine(to: CGPoint(x: land.x - w * 0.1, y: land.y))
        g.stroke(core, with: .color(.white.opacity(0.9)), lineWidth: 1.6)
        if sim.vol > 1 {
            var churn: [(CGPoint, CGFloat)] = []
            for k in 0..<5 {
                let seed = Int(sim.time * 20) + k * 13
                churn.append((CGPoint(x: land.x + (shash(seed) - 0.5) * 24, y: land.y + (shash(seed + 3) - 0.5) * 6), 4 + 5 * shash(seed + 9) * sim.flow))
            }
            foamBlobs(g, churn, color: RGB(0.86, 0.96, 1))
        }
    }

    static func drawDrops(_ g: GraphicsContext, sim: SpaSim) {
        var waterP = Path(), soapP = Path(), glintP = Path()
        for d in sim.drops {
            let sp = max(1, hypot(d.v.dx, d.v.dy))
            let stretch = min(2.5, 1 + sp / 900)
            let ang = atan2(d.v.dy, d.v.dx)
            let r = d.r
            var e = Path(ellipseIn: CGRect(x: -r * stretch, y: -r, width: r * 2 * stretch, height: r * 2))
            e = e.applying(CGAffineTransform(rotationAngle: ang).concatenating(CGAffineTransform(translationX: d.p.x, y: d.p.y)))
            if d.kind == .soap { soapP.addPath(e) } else { waterP.addPath(e) }
            if r > 2 { glintP.addEllipse(in: CGRect(x: d.p.x - r * 0.4, y: d.p.y - r * 0.5, width: r * 0.6, height: r * 0.6)) }
        }
        g.fill(waterP, with: .color(hx("#BDEBFF").c(0.85)))
        g.stroke(waterP, with: .color(.white.opacity(0.8)), lineWidth: 0.8)
        g.fill(soapP, with: .color(hx("#FF9EC6").c(0.95)))
        g.fill(glintP, with: .color(.white))
    }

    static func drawBubbles(_ g: GraphicsContext, sim: SpaSim) {
        let film = Gradient(colors: [
            hx("#FF9ECF").c(0.8), hx("#FFE38A").c(0.75), hx("#9FF0D8").c(0.75),
            hx("#8FC6FF").c(0.8), hx("#C9A6FF").c(0.8), hx("#FF9ECF").c(0.8),
        ])
        for b in sim.bubbles {
            let wob = 1 + 0.045 * sin(Double(b.phase) * 5 + sim.time * 7)
            let rx = b.r * CGFloat(wob), ry = b.r / CGFloat(wob)
            let rect = CGRect(x: b.p.x - rx, y: b.p.y - ry, width: rx * 2, height: ry * 2)
            let fade = Double(min(1, (b.life - b.age) / 0.6 + 0.3))
            var bg = g
            bg.opacity = fade
            if b.star {
                bg.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFEFA8).opacity(0.45), Color(hex: 0xA86CE0).opacity(0.62)]),
                    center: b.p,
                    startRadius: 2,
                    endRadius: b.r
                ))
                StorybookArt.sparkle(bg, at: b.p, radius: b.r * 0.58, color: Theme.lemon, opacity: 0.98)
            }
            bg.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(Gradient(colors: [Color.white.opacity(0.03), Color.white.opacity(0.24)]), center: b.p, startRadius: b.r * 0.35, endRadius: b.r)
            )
            bg.stroke(
                Path(ellipseIn: rect),
                with: .conicGradient(film, center: b.p, angle: .radians(Double(b.phase) + sim.time * 0.7)),
                lineWidth: max(1.8, b.r * 0.11)
            )
            bg.fill(
                Path(ellipseIn: CGRect(x: b.p.x - b.r * 0.62, y: b.p.y - b.r * 0.66, width: b.r * 0.46, height: b.r * 0.3)),
                with: .color(.white.opacity(0.92))
            )
        }
    }

    static func drawHearts(_ g: GraphicsContext, sim: SpaSim) {
        for heart in sim.hearts {
            let u = min(1, heart.age / max(0.1, heart.life))
            let pop = min(1, heart.age / 0.18)
            let alpha = Double((1 - u * u) * 0.95)
            StorybookArt.heart(g, at: heart.p, size: heart.size * (0.65 + 0.45 * pop), color: heart.color.c(), opacity: alpha)
        }
    }

    static func drawPops(_ g: GraphicsContext, sim: SpaSim) {
        for p in sim.pops {
            if p.sparkle {
                let u = p.age / 0.9
                for k in 0..<8 {
                    let a = CGFloat(k) / 8 * 2 * .pi + 0.3
                    let r = p.r * (0.4 + u * 1.1)
                    let s: CGFloat = 12 * (1 - u) + 3
                    let c = CGPoint(x: p.p.x + cos(a) * r, y: p.p.y + sin(a) * r)
                    g.fill(
                        Twinkle().path(in: CGRect(x: c.x - s, y: c.y - s, width: s * 2, height: s * 2)),
                        with: .color((k.isMultiple(of: 2) ? hx("#FFE38A") : hx("#FF9EC6")).c(Double(1 - u)))
                    )
                }
            } else {
                let u = p.age / 0.22
                let r = p.r * (1 + u * 0.6)
                g.stroke(
                    Path(ellipseIn: CGRect(x: p.p.x - r, y: p.p.y - r, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(Double(1 - u) * 0.85)),
                    style: StrokeStyle(lineWidth: 2.2, dash: [4, 6])
                )
            }
        }
    }

    static func drawHints(_ g: GraphicsContext, sim: SpaSim) {
        if sim.vol < 8 && !sim.tapOn && sim.tool == nil {
            let u = CGFloat(0.5 + 0.5 * sin(sim.time * 4))
            let r = 50 + 8 * u
            g.stroke(
                Path(ellipseIn: CGRect(x: SGeo.handle.x - r, y: SGeo.handle.y - r, width: r * 2, height: r * 2)),
                with: .color(Theme.pink.opacity(0.45 + 0.4 * Double(u))),
                lineWidth: 5
            )
        }
    }
}

// MARK: - Floating bath toys & bath bombs

enum ThingPainter {
    static func draw(_ ctx: GraphicsContext, _ t: SThing, time: Double) {
        var g = ctx
        g.translateBy(x: t.p.x, y: t.p.y)
        g.rotate(by: .radians(Double(t.a)))
        let sq = max(-0.3, min(0.3, t.squash))
        g.scaleBy(x: (1 + sq) * (t.facing < 0 ? -1 : 1), y: 1 - sq)
        switch t.kind {
        case .toy(let k):
            switch k {
            case .duck: duck(g, body: hx("#FFD84A"), scale: 0.96)
            case .goldenDuck: goldenDuck(g, scale: 0.96, time: time)
            case .boat: boat(g)
            case .whale: whale(g)
            case .turtle: turtle(g, t: time)
            }
        case .bomb(let k):
            bomb(g, k, fizz: t.fizz, fizzing: t.wetFor > 0.28, time: time)
        }
    }

    static func outline(_ c: RGB) -> Color { Shades.outline(c).c() }

    static func duck(_ g: GraphicsContext, body: RGB, scale s: CGFloat) {
        var b = Path()
        b.move(to: CGPoint(x: -44 * s, y: -2 * s))
        b.addQuadCurve(to: CGPoint(x: -30 * s, y: -12 * s), control: CGPoint(x: -46 * s, y: -20 * s))
        b.addQuadCurve(to: CGPoint(x: 30 * s, y: 0), control: CGPoint(x: 0, y: -6 * s))
        b.addQuadCurve(to: CGPoint(x: 36 * s, y: 26 * s), control: CGPoint(x: 46 * s, y: 12 * s))
        b.addQuadCurve(to: CGPoint(x: -38 * s, y: 24 * s), control: CGPoint(x: 0, y: 44 * s))
        b.addQuadCurve(to: CGPoint(x: -44 * s, y: -2 * s), control: CGPoint(x: -50 * s, y: 12 * s))
        b.closeSubpath()
        g.fill(b, with: .linearGradient(Gradient(colors: [Shades.light(body).c(), body.c(), Shades.shade(body).c()]),
                                        startPoint: CGPoint(x: 0, y: -10 * s), endPoint: CGPoint(x: 0, y: 36 * s)))
        g.stroke(b, with: .color(outline(body)), lineWidth: 3 * s)
        let head = Path(ellipseIn: CGRect(x: -2 * s, y: -40 * s, width: 44 * s, height: 42 * s))
        g.fill(head, with: .radialGradient(Gradient(colors: [Shades.light(body).c(), body.c()]), center: CGPoint(x: 14 * s, y: -30 * s), startRadius: 2, endRadius: 30 * s))
        g.stroke(head, with: .color(outline(body)), lineWidth: 3 * s)
        var beak = Path()
        beak.move(to: CGPoint(x: 36 * s, y: -20 * s))
        beak.addQuadCurve(to: CGPoint(x: 56 * s, y: -14 * s), control: CGPoint(x: 54 * s, y: -24 * s))
        beak.addQuadCurve(to: CGPoint(x: 36 * s, y: -8 * s), control: CGPoint(x: 52 * s, y: -6 * s))
        beak.closeSubpath()
        g.fill(beak, with: .color(hx("#FF9A3C").c()))
        g.stroke(beak, with: .color(hx("#D86A1E").c()), lineWidth: 2 * s)
        g.fill(Path(ellipseIn: CGRect(x: 22 * s, y: -30 * s, width: 9 * s, height: 11 * s)), with: .color(hx("#3B2A3F").c()))
        g.fill(Path(ellipseIn: CGRect(x: 24 * s, y: -28 * s, width: 3.5 * s, height: 3.5 * s)), with: .color(.white))
        g.fill(Path(ellipseIn: CGRect(x: 10 * s, y: -16 * s, width: 10 * s, height: 6 * s)), with: .color(hx("#FF8FB8").c(0.55)))
        var wing = Path()
        wing.move(to: CGPoint(x: -22 * s, y: 6 * s))
        wing.addQuadCurve(to: CGPoint(x: 14 * s, y: 10 * s), control: CGPoint(x: -4 * s, y: -6 * s))
        wing.addQuadCurve(to: CGPoint(x: -22 * s, y: 6 * s), control: CGPoint(x: -6 * s, y: 26 * s))
        g.fill(wing, with: .color(Shades.shade(body).c()))
        g.stroke(wing, with: .color(outline(body)), lineWidth: 2 * s)
        g.fill(Path(ellipseIn: CGRect(x: 4 * s, y: -36 * s, width: 14 * s, height: 8 * s)), with: .color(.white.opacity(0.7)))
    }

    static func goldenDuck(_ g: GraphicsContext, scale s: CGFloat, time: Double) {
        let gold = hx("#FFE066")
        let goldOutline = StorybookArt.outline(for: 0xE6A82E, factor: 0.62)

        // Soft royal shimmer halo behind the golden ducky
        let glowPulse = 0.32 + 0.14 * sin(time * 3.4)
        g.fill(
            Path(ellipseIn: CGRect(x: -46 * s, y: -56 * s, width: 100 * s, height: 92 * s)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF5B8).opacity(glowPulse), Color(hex: 0xFFF5B8).opacity(0)]),
                center: CGPoint(x: 4 * s, y: -12 * s),
                startRadius: 6 * s,
                endRadius: 50 * s
            )
        )

        duck(g, body: gold, scale: s)

        // Pearlescent wing highlight & rose-gold necklace ribbon
        g.fill(Path(ellipseIn: CGRect(x: -14 * s, y: 5 * s, width: 14 * s, height: 6 * s)), with: .color(.white.opacity(0.65)))
        var collar = Path()
        collar.move(to: CGPoint(x: 2 * s, y: -2 * s))
        collar.addQuadCurve(to: CGPoint(x: 32 * s, y: 1 * s), control: CGPoint(x: 18 * s, y: 8 * s))
        g.stroke(collar, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 3.4 * s, lineCap: .round))
        StorybookArt.heart(g, at: CGPoint(x: 18 * s, y: 6 * s), size: 9 * s, color: Theme.pink)

        // Royal golden crown perched on its head
        var crown = Path()
        crown.move(to: CGPoint(x: 3 * s, y: -36 * s))
        crown.addLine(to: CGPoint(x: 0 * s, y: -54 * s))
        crown.addLine(to: CGPoint(x: 10 * s, y: -45 * s))
        crown.addLine(to: CGPoint(x: 19 * s, y: -58 * s))
        crown.addLine(to: CGPoint(x: 27 * s, y: -45 * s))
        crown.addLine(to: CGPoint(x: 36 * s, y: -53 * s))
        crown.addLine(to: CGPoint(x: 33 * s, y: -36 * s))
        crown.addQuadCurve(to: CGPoint(x: 3 * s, y: -36 * s), control: CGPoint(x: 18 * s, y: -31 * s))
        crown.closeSubpath()
        g.fill(
            crown,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF7B8), Color(hex: 0xFFD242), Color(hex: 0xF2A628)]),
                startPoint: CGPoint(x: 18 * s, y: -58 * s),
                endPoint: CGPoint(x: 18 * s, y: -34 * s)
            )
        )
        g.stroke(crown, with: .color(goldOutline), style: StrokeStyle(lineWidth: 2.3 * s, lineJoin: .round))

        // Pearl crown tips & pink ruby heart gem
        for pt in [CGPoint(x: 0 * s, y: -55 * s), CGPoint(x: 19 * s, y: -60 * s), CGPoint(x: 36 * s, y: -54 * s)] {
            let pearl = Path(ellipseIn: CGRect(x: pt.x - 3 * s, y: pt.y - 3 * s, width: 6 * s, height: 6 * s))
            StorybookArt.fillAndStroke(g, pearl, fill: .white, stroke: goldOutline, width: 1.5 * s)
        }
        StorybookArt.heart(g, at: CGPoint(x: 18 * s, y: -41 * s), size: 9 * s, color: Color(hex: 0xFF5D9E))

        let tw = 0.72 + 0.28 * sin(time * 4.5)
        StorybookArt.sparkle(g, at: CGPoint(x: 34 * s, y: -58 * s), radius: 7 * s * CGFloat(tw), color: .white, opacity: tw)
        StorybookArt.sparkle(g, at: CGPoint(x: -24 * s, y: -22 * s), radius: 5.5 * s * CGFloat(1.3 - tw * 0.4), color: Theme.lemon, opacity: 0.9)
    }

    static func boat(_ g: GraphicsContext) {
        let hullC = hx("#FF758F")
        var hull = Path()
        hull.move(to: CGPoint(x: -48, y: 8))
        hull.addLine(to: CGPoint(x: 48, y: 8))
        hull.addQuadCurve(to: CGPoint(x: 30, y: 38), control: CGPoint(x: 44, y: 30))
        hull.addLine(to: CGPoint(x: -32, y: 38))
        hull.addQuadCurve(to: CGPoint(x: -48, y: 8), control: CGPoint(x: -46, y: 28))
        hull.closeSubpath()
        g.fill(hull, with: .linearGradient(Gradient(colors: [Shades.light(hullC).c(), hullC.c(), Shades.shade(hullC).c()]),
                                           startPoint: CGPoint(x: 0, y: 8), endPoint: CGPoint(x: 0, y: 38)))
        g.stroke(hull, with: .color(outline(hullC)), lineWidth: 3)
        g.fill(Path(CGRect(x: -40, y: 18, width: 80, height: 6)), with: .color(.white.opacity(0.85)))

        var mast = Path()
        mast.move(to: CGPoint(x: 0, y: 8))
        mast.addLine(to: CGPoint(x: 0, y: -44))
        g.stroke(mast, with: .color(hx("#D89D58").c()), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        var sail1 = Path()
        sail1.move(to: CGPoint(x: 3, y: -40))
        sail1.addQuadCurve(to: CGPoint(x: 36, y: 2), control: CGPoint(x: 32, y: -22))
        sail1.addLine(to: CGPoint(x: 3, y: 2))
        sail1.closeSubpath()
        StorybookArt.fillAndStroke(g, sail1, fill: .white, stroke: StorybookArt.outline(for: 0xD8D4F0), width: 2.2)

        var sail2 = Path()
        sail2.move(to: CGPoint(x: -3, y: -32))
        sail2.addQuadCurve(to: CGPoint(x: -30, y: 2), control: CGPoint(x: -26, y: -16))
        sail2.addLine(to: CGPoint(x: -3, y: 2))
        sail2.closeSubpath()
        StorybookArt.fillAndStroke(g, sail2, fill: Theme.lilac, stroke: StorybookArt.outline(for: 0xB49AE8), width: 2.2)

        var flag = Path()
        flag.move(to: CGPoint(x: 2, y: -46))
        flag.addLine(to: CGPoint(x: 20, y: -41))
        flag.addLine(to: CGPoint(x: 2, y: -36))
        flag.closeSubpath()
        g.fill(flag, with: .color(Theme.lemon))
    }

    static func whale(_ g: GraphicsContext) {
        let c = hx("#6FB6FF")
        var b = Path()
        b.move(to: CGPoint(x: 48, y: 6))
        b.addQuadCurve(to: CGPoint(x: -10, y: -32), control: CGPoint(x: 44, y: -34))
        b.addQuadCurve(to: CGPoint(x: -38, y: 4), control: CGPoint(x: -34, y: -28))
        b.addQuadCurve(to: CGPoint(x: -58, y: -20), control: CGPoint(x: -46, y: -6))
        b.addQuadCurve(to: CGPoint(x: -50, y: 18), control: CGPoint(x: -66, y: 4))
        b.addQuadCurve(to: CGPoint(x: -32, y: 22), control: CGPoint(x: -42, y: 22))
        b.addQuadCurve(to: CGPoint(x: 48, y: 6), control: CGPoint(x: 28, y: 44))
        b.closeSubpath()
        g.fill(b, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]),
                                        startPoint: CGPoint(x: 0, y: -32), endPoint: CGPoint(x: 0, y: 32)))
        g.stroke(b, with: .color(outline(c)), lineWidth: 3)
        var belly = Path()
        belly.move(to: CGPoint(x: -18, y: 18))
        belly.addQuadCurve(to: CGPoint(x: 44, y: 10), control: CGPoint(x: 16, y: 36))
        belly.addQuadCurve(to: CGPoint(x: -18, y: 18), control: CGPoint(x: 16, y: 18))
        g.fill(belly, with: .color(hx("#DFF1FF").c()))
        g.fill(Path(ellipseIn: CGRect(x: 20, y: -12, width: 8, height: 10)), with: .color(hx("#2E3A55").c()))
        g.fill(Path(ellipseIn: CGRect(x: 22, y: -10, width: 3, height: 3)), with: .color(.white))
        g.stroke(Path { p in p.move(to: CGPoint(x: 28, y: 4)); p.addQuadCurve(to: CGPoint(x: 42, y: 2), control: CGPoint(x: 36, y: 10)) },
                 with: .color(hx("#2E3A55").c()), lineWidth: 2)
        g.fill(Path(ellipseIn: CGRect(x: 28, y: -2, width: 8, height: 5)), with: .color(hx("#FF8FB8").c(0.6)))
        g.fill(Path(ellipseIn: CGRect(x: 2, y: -32, width: 8, height: 4)), with: .color(Shades.deep(c).c()))
    }

    static func turtle(_ g: GraphicsContext, t: Double) {
        let skin = hx("#8EDB8A"), shell = hx("#3FAF78")
        let pad = CGFloat(sin(t * 5)) * 3
        for (x, y) in [(-28, 14), (24, 14)] {
            g.fill(Path(ellipseIn: CGRect(x: CGFloat(x) - 10 + pad, y: CGFloat(y), width: 20, height: 12)), with: .color(skin.c()))
        }
        let head = Path(ellipseIn: CGRect(x: 30, y: -6, width: 22, height: 20))
        g.fill(head, with: .color(skin.c()))
        g.stroke(head, with: .color(outline(skin)), lineWidth: 2.2)
        g.fill(Path(ellipseIn: CGRect(x: 42, y: 0, width: 5, height: 6)), with: .color(hx("#2E3A35").c()))
        var dome = Path()
        dome.move(to: CGPoint(x: -40, y: 14))
        dome.addQuadCurve(to: CGPoint(x: 38, y: 14), control: CGPoint(x: 0, y: -44))
        dome.closeSubpath()
        g.fill(dome, with: .linearGradient(Gradient(colors: [Shades.light(shell).c(), shell.c()]), startPoint: CGPoint(x: 0, y: -22), endPoint: CGPoint(x: 0, y: 14)))
        g.stroke(dome, with: .color(outline(shell)), lineWidth: 3)
        var hexes = Path()
        for (cx, cy) in [(-15, 2), (6, -6), (22, 4), (-2, 8)] {
            hexes.addEllipse(in: CGRect(x: CGFloat(cx) - 8, y: CGFloat(cy) - 6, width: 16, height: 12))
        }
        g.fill(hexes, with: .color(Shades.light(shell).c(0.6)))
        g.fill(Path(roundedRect: CGRect(x: -42, y: 12, width: 82, height: 7), cornerRadius: 3), with: .color(Theme.lemon))
    }

    static func bomb(_ g: GraphicsContext, _ k: BombKind, fizz: CGFloat, fizzing: Bool, time: Double) {
        let r = 28 * (0.3 + 0.7 * sqrt(max(0, fizz)))
        let c = k.dye(time)
        var p = Path()
        let n = 28
        for q in 0..<n {
            let a = CGFloat(q) / CGFloat(n) * 2 * .pi
            let rough = fizzing ? 1 + 0.08 * sin(a * 7 + CGFloat(time) * 3) + 0.06 * (shash(q + Int(time * 8)) - 0.5) : 1
            let pt = CGPoint(x: cos(a) * r * rough, y: sin(a) * r * rough)
            if q == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        if k == .rainbow {
            g.fill(
                p,
                with: .conicGradient(
                    Gradient(colors: ["#FF6F91", "#FFB347", "#FFE066", "#6EE7A0", "#5EC2FF", "#B497FF", "#FF6F91"].map { hx($0).c() }),
                    center: .zero,
                    angle: .radians(time * 0.5)
                )
            )
        } else if k == .galaxy {
            g.fill(
                p,
                with: .radialGradient(
                    Gradient(colors: [hx("#C5A6FF").c(), hx("#7A52E8").c(), hx("#4D329E").c()]),
                    center: CGPoint(x: -r * 0.3, y: -r * 0.35),
                    startRadius: 1,
                    endRadius: r * 1.35
                )
            )
        } else if k == .yuzu {
            g.fill(
                p,
                with: .radialGradient(
                    Gradient(colors: [hx("#FFF6B8").c(), hx("#FFD842").c(), hx("#F5A628").c()]),
                    center: CGPoint(x: -r * 0.32, y: -r * 0.38),
                    startRadius: 1,
                    endRadius: r * 1.35
                )
            )
        } else {
            g.fill(
                p,
                with: .radialGradient(
                    Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]),
                    center: CGPoint(x: -r * 0.35, y: -r * 0.4),
                    startRadius: 1,
                    endRadius: r * 1.4
                )
            )
        }
        g.stroke(p, with: .color(Shades.outline(c).c(0.75)), lineWidth: 2.6)
        var sp = Path()
        for q in 0..<14 {
            let a = shash(q * 3 + k.rawValue.count) * 2 * .pi
            let d = sqrt(shash(q * 5 + 1)) * r * 0.78
            sp.addEllipse(in: CGRect(x: cos(a) * d - 1.6, y: sin(a) * d - 1.6, width: 3.2, height: 3.2))
        }
        g.fill(sp, with: .color(k.glitter ? hx("#FFF6C8").c() : Color.white.opacity(0.82)))
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.62, width: r * 0.5, height: r * 0.32)), with: .color(.white.opacity(0.6)))
        if k == .yuzu {
            let leafOutline = StorybookArt.outline(for: 0x62C48A, factor: 0.6)
            var leaf = Path()
            leaf.move(to: CGPoint(x: 0, y: -r * 0.88))
            leaf.addQuadCurve(to: CGPoint(x: r * 0.52, y: -r * 1.18), control: CGPoint(x: r * 0.24, y: -r * 1.24))
            leaf.addQuadCurve(to: CGPoint(x: 0, y: -r * 0.88), control: CGPoint(x: r * 0.32, y: -r * 0.84))
            leaf.closeSubpath()
            StorybookArt.fillAndStroke(g, leaf, fill: Color(hex: 0x7CE0A0), stroke: leafOutline, width: 2)
            let stem = Path(roundedRect: CGRect(x: -2.2, y: -r * 1.08, width: 4.4, height: r * 0.24), cornerRadius: 2)
            StorybookArt.fillAndStroke(g, stem, fill: Color(hex: 0xA88856), stroke: StorybookArt.outline(for: 0x8A6A3C), width: 1.4)
            StorybookArt.sparkle(g, at: CGPoint(x: -r * 0.42, y: -r * 0.92), radius: 5.5, color: .white, opacity: 0.92)
        }
    }
}

// MARK: - Held tools

enum ToolPainter {
    static func drawHeld(_ ctx: GraphicsContext, _ tool: SpaTool, sim: SpaSim) {
        var g = ctx
        let p = sim.toolP
        let over = SGeo.onHer(SGeo.toDoll(p), pad: 30) || sim.inTub(p)
        if over && tool != .soap && tool != .wand && tool != .mist {
            g.opacity = FingerLift.seeThrough + 0.25
        }
        switch tool {
        case .soap:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(sim.toolAngle)))
            soapBottle(b)
        case .wand:
            wand(g, tip: p, finger: sim.toolFinger, v: sim.toolV, t: sim.time)
        case .sponge(let tint):
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(max(-0.3, min(0.3, sim.toolV.dx / 3000)))))
            b.scaleBy(x: 1.32, y: 1.32)
            sponge(b, tint: tint, foam: sim.spongeFoam, t: sim.time)
        case .shower:
            shower(g, head: p, finger: sim.toolFinger)
        case .towel:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(max(-0.25, min(0.25, sim.toolV.dx / 4000)))))
            b.scaleBy(x: 1.25, y: 1.25)
            towel(b)
        case .sheepTowel:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(max(-0.22, min(0.22, sim.toolV.dx / 3800)))))
            b.scaleBy(x: 1.4, y: 1.4)
            sheepTowel(b, tint: sim.sheepTowelTint)
        case .mask(let k):
            maskBrush(g, tip: p, finger: sim.toolFinger, kind: k)
        case .cucumbers:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            var left = b; left.translateBy(x: -24, y: 2); cucumber(left, r: 28)
            var right = b; right.translateBy(x: 24, y: -2); cucumber(right, r: 28)
        case .mist:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(max(-0.25, min(0.25, sim.toolV.dx / 2500)))))
            mistBottle(b)
        }
    }

    static func soapBottle(_ g: GraphicsContext) {
        let c = hx("#FF9EC6")
        let body = Path(roundedRect: CGRect(x: -28, y: -34, width: 56, height: 80), cornerRadius: 20)
        g.fill(body, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]),
                                           startPoint: CGPoint(x: -28, y: 0), endPoint: CGPoint(x: 28, y: 0)))
        g.stroke(body, with: .color(Shades.outline(c).c()), lineWidth: 3)
        let neck = Path(roundedRect: CGRect(x: -11, y: -52, width: 22, height: 22), cornerRadius: 5)
        StorybookArt.fillAndStroke(g, neck, fill: .white, stroke: hx("#D9A3BF").c(), width: 2.2)
        g.fill(Path(roundedRect: CGRect(x: -6, y: -62, width: 12, height: 12), cornerRadius: 3), with: .color(Theme.lilac))
        let label = Path(roundedRect: CGRect(x: -20, y: -10, width: 40, height: 38), cornerRadius: 10)
        g.fill(label, with: .color(.white.opacity(0.92)))
        for (x, y, r) in [(-7.0, 6.0, 8.5), (8.0, 0.0, 6.0), (6.0, 16.0, 5.0)] {
            let rr = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            g.stroke(Path(ellipseIn: rr), with: .color(Theme.sky), lineWidth: 2)
        }
        g.fill(Path(roundedRect: CGRect(x: -22, y: -28, width: 7, height: 58), cornerRadius: 4), with: .color(.white.opacity(0.4)))
    }

    static func wand(_ g: GraphicsContext, tip: CGPoint, finger: CGPoint, v: CGVector, t: Double) {
        let (u, len) = FingerLift.handle(tip: tip, finger: finger, length: 145)
        let ux = u.dx, uy = u.dy
        let ringR: CGFloat = 26 * 1.45
        let stickStart = CGPoint(x: tip.x + ux * ringR, y: tip.y + uy * ringR)
        let stickEnd = CGPoint(x: tip.x + ux * max(ringR + 20, len), y: tip.y + uy * max(ringR + 20, len))
        var stick = Path()
        stick.move(to: stickStart)
        stick.addLine(to: stickEnd)
        g.stroke(stick, with: .color(hx("#9F7BEF").c()), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        g.stroke(stick, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        let ring = Path(ellipseIn: CGRect(x: tip.x - ringR, y: tip.y - ringR, width: ringR * 2, height: ringR * 2))
        let sp = hypot(v.dx, v.dy)
        let bulge = min(20, sp / 60)
        let bx = sp > 1 ? -v.dx / sp * bulge : 0, by = sp > 1 ? -v.dy / sp * bulge : 0
        let fr = CGRect(x: tip.x - ringR + min(0, bx), y: tip.y - ringR + min(0, by), width: ringR * 2 + abs(bx), height: ringR * 2 + abs(by))
        g.fill(
            Path(ellipseIn: fr),
            with: .conicGradient(
                Gradient(colors: [hx("#FF9ECF").c(0.4), hx("#FFE38A").c(0.35), hx("#9FF0D8").c(0.35), hx("#8FC6FF").c(0.4), hx("#FF9ECF").c(0.4)]),
                center: tip,
                angle: .radians(t)
            )
        )
        g.stroke(ring, with: .color(hx("#B08CFF").c()), lineWidth: 6)
        g.stroke(ring, with: .color(.white.opacity(0.55)), lineWidth: 2.2)
    }

    static func sponge(_ g: GraphicsContext, tint: FoamTint, foam: CGFloat, t: Double) {
        let c = hx("#FFE07A")
        let body = Path(roundedRect: CGRect(x: -44, y: -26, width: 88, height: 54), cornerRadius: 18)
        g.fill(body, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]),
                                           startPoint: CGPoint(x: 0, y: -26), endPoint: CGPoint(x: 0, y: 28)))
        g.stroke(body, with: .color(Shades.outline(c).c()), lineWidth: 3)
        var pores = Path()
        for q in 0..<12 {
            let x = -32 + shash(q) * 64, y = -16 + shash(q + 40) * 32, r = 2 + shash(q + 80) * 3.5
            pores.addEllipse(in: CGRect(x: x - r, y: y - r * 0.8, width: r * 2, height: r * 1.6))
        }
        g.fill(pores, with: .color(Shades.shade(c).c(0.7)))
        if foam > 0.05 {
            var blobs: [(CGPoint, CGFloat)] = []
            for q in 0..<7 {
                blobs.append((CGPoint(x: -36 + CGFloat(q) * 12, y: -26 + CGFloat(sin(t * 2 + Double(q))) * 1.2), 10 + shash(q * 3 + 2) * 7))
            }
            SpaPainter.foamBlobs(g, blobs, color: tint.color)
        }
    }

    static func shower(_ g: GraphicsContext, head: CGPoint, finger: CGPoint) {
        var hose = Path()
        hose.move(to: CGPoint(x: head.x + 22, y: head.y + 10))
        hose.addCurve(to: CGPoint(x: 1060, y: 860), control1: CGPoint(x: head.x + 90, y: head.y + 40), control2: CGPoint(x: finger.x + 40, y: 920))
        g.stroke(hose, with: .color(hx("#B8C6D6").c()), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        g.stroke(hose, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 4]))

        let chrome = Gradient(colors: [.white, hx("#D6E0EC").c(), hx("#9FB0C4").c()])
        var handle = Path()
        handle.move(to: CGPoint(x: head.x + 10, y: head.y - 6))
        handle.addLine(to: CGPoint(x: head.x + 54, y: head.y + 20))
        g.stroke(handle, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        g.stroke(handle, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 5, lineCap: .round))

        let face = CGRect(x: head.x - 34, y: head.y - 14, width: 68, height: 30)
        g.fill(Path(ellipseIn: face), with: .linearGradient(chrome, startPoint: CGPoint(x: face.minX, y: face.minY), endPoint: CGPoint(x: face.maxX, y: face.maxY)))
        g.stroke(Path(ellipseIn: face), with: .color(StorybookArt.outline(for: 0x9FB0C4)), lineWidth: 2.6)
        var holes = Path()
        for q in 0..<11 {
            let a = CGFloat(q) / 11 * 2 * .pi
            holes.addEllipse(in: CGRect(x: head.x + cos(a) * 20 - 2, y: head.y + 2 + sin(a) * 7 - 1.5, width: 4, height: 3))
        }
        g.fill(holes, with: .color(hx("#637487").c()))
    }

    static func towel(_ g: GraphicsContext) {
        let c = hx("#FFB3CF")
        var t = Path()
        t.move(to: CGPoint(x: -56, y: -28))
        for q in 0...10 {
            let x = -56 + CGFloat(q) * 11.2
            t.addQuadCurve(to: CGPoint(x: x + 11.2, y: -28), control: CGPoint(x: x + 5.6, y: -34))
        }
        t.addLine(to: CGPoint(x: 64, y: 28))
        t.addQuadCurve(to: CGPoint(x: -56, y: 28), control: CGPoint(x: 4, y: 38))
        t.closeSubpath()
        g.fill(t, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c()]), startPoint: CGPoint(x: 0, y: -28), endPoint: CGPoint(x: 0, y: 32)))
        g.stroke(t, with: .color(Shades.outline(c).c()), lineWidth: 3)
        g.fill(Path(CGRect(x: -54, y: 4, width: 116, height: 7)), with: .color(.white.opacity(0.85)))
        g.fill(Path(CGRect(x: -54, y: 15, width: 116, height: 3)), with: .color(.white.opacity(0.7)))
    }

    static func sheepTowel(_ g: GraphicsContext, tint: FoamTint = .cloud) {
        let (base, trim) = SpaPainter.sheepTowelPalette(tint)
        let light = Shades.light(base)
        let shade = Shades.shade(base)
        let stroke = Shades.outline(base)
        let spiralInk = shade.mix(stroke, 0.45)

        // Miniature left & right rolled sheep-horn buns
        for side in [CGFloat(-1), 1] {
            var bun = g
            bun.translateBy(x: side * 24, y: 4)
            bun.rotate(by: .radians(Double(side) * 0.16))
            let outer = Path(ellipseIn: CGRect(x: -13, y: -15, width: 26, height: 30))
            bun.fill(
                outer,
                with: .linearGradient(
                    Gradient(colors: [light.c(), base.c(), shade.c()]),
                    startPoint: CGPoint(x: 0, y: -15),
                    endPoint: CGPoint(x: 0, y: 15)
                )
            )
            bun.stroke(outer, with: .color(stroke.c()), lineWidth: 2.6)
            var spiral = Path()
            for k in 0...26 {
                let u = CGFloat(k) / 26
                let a = u * 3.4 * .pi
                let r = 1.5 + u * 8.2
                let pt = CGPoint(x: cos(a) * r * side, y: sin(a) * r * 1.05)
                if k == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
            }
            bun.stroke(spiral, with: .color(spiralInk.c(0.85)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }

        // Miniature folded arched towel crown
        var band = Path()
        band.move(to: CGPoint(x: -22, y: 6))
        band.addCurve(to: CGPoint(x: 22, y: 6), control1: CGPoint(x: -14, y: -26), control2: CGPoint(x: 14, y: -26))
        band.addLine(to: CGPoint(x: 18, y: 12))
        band.addCurve(to: CGPoint(x: -18, y: 12), control1: CGPoint(x: 8, y: -2), control2: CGPoint(x: -8, y: -2))
        band.closeSubpath()
        g.fill(
            band,
            with: .linearGradient(
                Gradient(colors: [light.c(), base.c(), shade.c()]),
                startPoint: CGPoint(x: 0, y: -18),
                endPoint: CGPoint(x: 0, y: 12)
            )
        )
        g.stroke(band, with: .color(stroke.c()), lineWidth: 2.6)

        var cuff = Path()
        cuff.move(to: CGPoint(x: -16, y: 8))
        cuff.addCurve(to: CGPoint(x: 16, y: 8), control1: CGPoint(x: -6, y: -4), control2: CGPoint(x: 6, y: -4))
        g.stroke(cuff, with: .color(trim.c(0.9)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        StorybookArt.highlight(g, in: CGRect(x: -10, y: -13, width: 14, height: 5), opacity: 0.7)
    }

    static func mistBottle(_ g: GraphicsContext) {
        let body = Path(roundedRect: CGRect(x: -24, y: -14, width: 48, height: 56), cornerRadius: 18)
        g.fill(body, with: .linearGradient(Gradient(colors: [hx("#E8D6FF").c(), hx("#BFA3FF").c()]),
                                           startPoint: CGPoint(x: -24, y: 0), endPoint: CGPoint(x: 24, y: 0)))
        g.stroke(body, with: .color(StorybookArt.outline(for: 0xBFA3FF)), lineWidth: 3)
        let cap = Path(roundedRect: CGRect(x: -11, y: -32, width: 22, height: 20), cornerRadius: 6)
        StorybookArt.fillAndStroke(g, cap, fill: hx("#FFE494").c(), stroke: StorybookArt.outline(for: 0xD49438), width: 2.2)
        let spray = Path(roundedRect: CGRect(x: -18, y: -42, width: 28, height: 11), cornerRadius: 5)
        StorybookArt.fillAndStroke(g, spray, fill: .white, stroke: StorybookArt.outline(for: 0xC9B6FF), width: 2.2)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: 14), radius: 13, color: Theme.lemon)
        StorybookArt.highlight(g, in: CGRect(x: -17, y: -6, width: 8, height: 34), opacity: 0.45)
    }

    static func maskBrush(_ g: GraphicsContext, tip: CGPoint, finger: CGPoint, kind: MaskKind) {
        let (u, len) = FingerLift.handle(tip: tip, finger: finger, length: 145)
        let ux = u.dx, uy = u.dy
        let a = CGPoint(x: tip.x + ux * 18 * FingerLift.spread, y: tip.y + uy * 18 * FingerLift.spread)
        let b = CGPoint(x: tip.x + ux * len, y: tip.y + uy * len)
        var stick = Path()
        stick.move(to: a)
        stick.addLine(to: b)
        g.stroke(stick, with: .color(Theme.cream), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        g.stroke(stick, with: .color(hx("#E9C9D6").c()), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        var head = g
        head.translateBy(x: tip.x, y: tip.y)
        head.rotate(by: .radians(Double(atan2(uy, ux)) - .pi / 2))
        head.scaleBy(x: FingerLift.spread, y: FingerLift.spread)
        let bristles = Path(roundedRect: CGRect(x: -15, y: 0, width: 30, height: 26), cornerRadius: 6)
        head.fill(bristles, with: .color(hx("#F4E3C8").c()))
        let blob = Path(roundedRect: CGRect(x: -17, y: -8, width: 34, height: 18), cornerRadius: 9)
        head.fill(blob, with: .color(kind.color.c()))
        head.stroke(blob, with: .color(Shades.shade(kind.color).c()), lineWidth: 2)
        head.fill(Path(roundedRect: CGRect(x: -16, y: 24, width: 32, height: 8), cornerRadius: 3), with: .color(Theme.lilac))
    }

    static func cucumber(_ g: GraphicsContext, r: CGFloat) {
        let outer = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        g.fill(outer, with: .color(hx("#3E9A4E").c()))
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.86, y: -r * 0.86, width: r * 1.72, height: r * 1.72)), with: .color(hx("#9EDC86").c()))
        g.fill(
            Path(ellipseIn: CGRect(x: -r * 0.74, y: -r * 0.74, width: r * 1.48, height: r * 1.48)),
            with: .radialGradient(Gradient(colors: [hx("#F1FBD8").c(), hx("#C9EDA8").c()]), center: .zero, startRadius: 0, endRadius: r * 0.74)
        )
        var seeds = Path()
        for q in 0..<7 {
            let a = CGFloat(q) / 7 * 2 * .pi
            let p = CGPoint(x: cos(a) * r * 0.36, y: sin(a) * r * 0.36)
            seeds.addEllipse(in: CGRect(x: p.x - r * 0.07, y: p.y - r * 0.12, width: r * 0.14, height: r * 0.24))
        }
        g.fill(seeds, with: .color(hx("#E8F6C8").c()))
        g.stroke(seeds, with: .color(hx("#B6DA94").c()), lineWidth: 1)
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.6, width: r * 0.4, height: r * 0.24)), with: .color(.white.opacity(0.7)))
    }
}

// MARK: - Pictorial icons for category tabs, dock tiles, and spa wishes

enum SpaIconPainter {
    /// Clean illustrated icons for the 4 bottom-dock category tabs (centered at 0,0 for ~56pt frame).
    static func drawCategory(_ category: SpaCategory, in g: GraphicsContext) {
        switch category {
        case .fizz:
            var a = g; a.translateBy(x: -6, y: 6); a.scaleBy(x: 0.62, y: 0.62)
            ThingPainter.bomb(a, .rainbow, fizz: 1, fizzing: false, time: 0.4)
            for (x, y, r) in [(13.0, -13.0, 7.0), (4.0, -21.0, 4.5)] {
                let b = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                StorybookArt.fillAndStroke(g, b, fill: StorybookArt.color(0xE6F8FF), stroke: StorybookArt.outline(for: 0x8FD0FF), width: 1.8)
            }
        case .wash:
            // Fluffy foam puff + chrome-pink shower drop (never a rubber duck!)
            var sg = g; sg.translateBy(x: -2, y: -4); sg.scaleBy(x: 0.56, y: 0.56)
            drawShowerIcon(sg)
            SpaPainter.foamBlobs(g, [(CGPoint(x: -14, y: 14), 8), (CGPoint(x: -4, y: 17), 7)], color: RGB(1, 1, 1))
        case .pamper:
            var j = g; j.translateBy(x: 8, y: 7); j.scaleBy(x: 0.58, y: 0.58)
            drawMaskJar(j, kind: .strawberry)
            var c = g; c.translateBy(x: -13, y: -11)
            ToolPainter.cucumber(c, r: 13)
        case .toys:
            var d = g; d.translateBy(x: -3, y: 5); d.scaleBy(x: 0.46, y: 0.46)
            ThingPainter.duck(d, body: hx("#FFD84A"), scale: 1)
        }
    }

    static func drawShowerIcon(_ c: GraphicsContext) {
        let chrome = Gradient(colors: [.white, hx("#D0DCE8").c(), hx("#94A6BA").c()])
        var h = Path()
        h.move(to: CGPoint(x: 2, y: -4))
        h.addLine(to: CGPoint(x: 34, y: 30))
        c.stroke(h, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        c.stroke(h, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        let face = CGRect(x: -36, y: -26, width: 58, height: 26)
        c.fill(Path(ellipseIn: face), with: .linearGradient(chrome, startPoint: CGPoint(x: face.minX, y: face.minY), endPoint: CGPoint(x: face.maxX, y: face.maxY)))
        c.stroke(Path(ellipseIn: face), with: .color(StorybookArt.outline(for: 0x94A6BA)), lineWidth: 2.6)
        for q in 0..<5 {
            var d = Path()
            d.move(to: CGPoint(x: -26 + CGFloat(q) * 10, y: 6))
            d.addLine(to: CGPoint(x: -30 + CGFloat(q) * 10, y: 24))
            c.stroke(d, with: .color(hx("#6AC8FF").c()), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        }
    }

    static func drawMaskJar(_ g: GraphicsContext, kind: MaskKind) {
        let jar = Path(roundedRect: CGRect(x: -28, y: -12, width: 56, height: 38), cornerRadius: 13)
        StorybookArt.fillAndStroke(g, jar, fill: .white, stroke: StorybookArt.outline(for: 0xE6C2D4), width: 2.8)
        let lid = Path(ellipseIn: CGRect(x: -24, y: -24, width: 48, height: 22))
        StorybookArt.fillAndStroke(g, lid, fill: kind.color.c(), stroke: Shades.outline(kind.color).c(), width: 2.4)
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -19, width: 14, height: 5), opacity: 0.65)
        let stripe = Path(roundedRect: CGRect(x: -18, y: 2, width: 36, height: 14), cornerRadius: 7)
        g.fill(stripe, with: .color(kind.color.c(0.55)))
    }

    static func drawWish(_ wish: SpaWish, in g: GraphicsContext) {
        switch wish {
        case .bathBomb:
            var b = g; b.scaleBy(x: 0.95, y: 0.95)
            ThingPainter.bomb(b, .rainbow, fizz: 1, fizzing: false, time: 0.5)
            StorybookArt.sparkle(g, at: CGPoint(x: 20, y: -20), radius: 7, color: Theme.lemon)
        case .foamHair:
            SpaPainter.foamBlobs(
                g,
                [(CGPoint(x: -14, y: 6), 13), (CGPoint(x: 0, y: -6), 17), (CGPoint(x: 14, y: 6), 13)],
                color: RGB(1, 1, 1)
            )
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -24), radius: 7, color: Theme.lemon)
        case .cucumbers:
            var l = g; l.translateBy(x: -13, y: 2); ToolPainter.cucumber(l, r: 16)
            var r = g; r.translateBy(x: 13, y: -2); ToolPainter.cucumber(r, r: 16)
        case .whaleToy:
            var w = g; w.translateBy(x: 2, y: 6); w.scaleBy(x: 0.52, y: 0.52)
            ThingPainter.whale(w)
            for side in [-1.0, 1.0] {
                var arc = Path()
                arc.move(to: CGPoint(x: 2, y: -10))
                arc.addQuadCurve(to: CGPoint(x: CGFloat(side) * 16, y: -22), control: CGPoint(x: CGFloat(side) * 6, y: -30))
                g.stroke(arc, with: .color(Theme.sky), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
        case .cozyTowel:
            var t = g; t.scaleBy(x: 0.45, y: 0.45)
            ToolPainter.towel(t)
            StorybookArt.heart(g, at: CGPoint(x: 18, y: -18), size: 12, color: Theme.pink)
        case .faceMask:
            var m = g; m.translateBy(x: 0, y: 4); m.scaleBy(x: 0.85, y: 0.85)
            drawMaskJar(m, kind: .strawberry)
        }
    }
}
