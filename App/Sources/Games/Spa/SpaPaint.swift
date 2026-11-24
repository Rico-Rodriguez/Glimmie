import SwiftUI

// MARK: - Drawing the bathroom
//
// All in design space (1024 x 834, `SMap` scales it to the screen). Things under the water are drawn first and the
// water is laid over them, so everything below the surface is tinted and softened by it, the way it looks through
// real water; the foam, the stream, the glass front and anything in the air come after.

struct SMap {
    let size: CGSize
    let ui: CGFloat
    let wideCaddy: Bool
    let s: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    init(size: CGSize) {
        self.size = size
        ui = max(0.001, min(size.width / 1024, size.height / 834))
        wideCaddy = size.width / ui >= 1300
        // On wide screens the controls have their own column. Frame the mirror through
        // the feet of the tub, using the extra height for the water and the toys.
        s = ui * (wideCaddy ? 1.10 : 1)
        ox = size.width / 2 - (wideCaddy ? 545 : 512) * s
        oy = size.height / 2 - (wideCaddy ? 438 : 417) * s
    }

    func design(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - ox) / s, y: (p.y - oy) / s) }
    func fromUI(_ point: CGPoint) -> CGPoint {
        design(CGPoint(x: size.width / 2 + (point.x - 512) * ui,
                       y: size.height / 2 + (point.y - 417) * ui))
    }

    var visible: CGRect { CGRect(x: -ox / s, y: -oy / s, width: size.width / s, height: size.height / s) }
}

extension RGB {
    func c(_ a: Double = 1) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

private func hx(_ s: String) -> RGB { RGB(hex: s) }

/// A repeatable pseudo-random number in 0..<1 for an integer (so foam blobs keep their shapes frame to frame).
@inline(__always) func shash(_ i: Int) -> CGFloat {
    var x = UInt32(truncatingIfNeeded: i &* 747796405 &+ 2891336453)
    x = ((x >> ((x >> 28) &+ 4)) ^ x) &* 277803737
    x = (x >> 22) ^ x
    return CGFloat(x % 10000) / 10000
}

enum SpaPainter {
    static let water = hx("#9FE3F0")
    static let deep = hx("#4FB4CF")

    // MARK: Backdrop (slow layer)

    static func drawBackdrop(_ ctx: GraphicsContext, map: SMap) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let v = map.visible
        // tiled wall
        g.fill(Path(v), with: .linearGradient(Gradient(colors: [hx("#FDEAF2").c(), hx("#F7D7E6").c()]),
                                              startPoint: CGPoint(x: 0, y: v.minY), endPoint: CGPoint(x: 0, y: 700)))
        var grout = Path()
        let tile: CGFloat = 58
        var y = (v.minY / tile).rounded(.down) * tile
        while y < 700 {
            grout.move(to: CGPoint(x: v.minX, y: y)); grout.addLine(to: CGPoint(x: v.maxX, y: y))
            y += tile
        }
        var x = (v.minX / tile).rounded(.down) * tile
        while x < v.maxX {
            grout.move(to: CGPoint(x: x, y: v.minY)); grout.addLine(to: CGPoint(x: x, y: 700))
            x += tile
        }
        g.stroke(grout, with: .color(.white.opacity(0.75)), lineWidth: 3)
        var gl = Path()
        x = (v.minX / tile).rounded(.down) * tile
        while x < v.maxX {
            gl.move(to: CGPoint(x: x + 6, y: v.minY)); gl.addLine(to: CGPoint(x: x + 6, y: 700))
            x += tile
        }
        g.stroke(gl, with: .color(hx("#E9B9CF").c(0.25)), lineWidth: 1.5)
        // a band of mint tiles
        g.fill(Path(CGRect(x: v.minX, y: 640, width: v.width, height: 60)), with: .color(hx("#BFEBDD").c()))
        g.fill(Path(CGRect(x: v.minX, y: 636, width: v.width, height: 6)), with: .color(.white.opacity(0.9)))
        // floor
        g.fill(Path(CGRect(x: v.minX, y: 700, width: v.width, height: v.maxY - 700)),
               with: .linearGradient(Gradient(colors: [hx("#E7D4F5").c(), hx("#D6BEEC").c()]),
                                     startPoint: CGPoint(x: 0, y: 700), endPoint: CGPoint(x: 0, y: v.maxY)))
        var fl = Path()
        for k in -20...40 {
            let x0 = CGFloat(k) * 80
            fl.move(to: CGPoint(x: x0, y: 700)); fl.addLine(to: CGPoint(x: x0 + (x0 - 512) * 0.6, y: v.maxY))
        }
        for yy in stride(from: CGFloat(730), to: v.maxY, by: 44) {
            fl.move(to: CGPoint(x: v.minX, y: yy)); fl.addLine(to: CGPoint(x: v.maxX, y: yy))
        }
        g.stroke(fl, with: .color(.white.opacity(0.35)), lineWidth: 2)
        g.fill(Path(CGRect(x: v.minX, y: 696, width: v.width, height: 6)), with: .color(hx("#C9A9DE").c()))
        // the mirror's frame
        let m = SGeo.mirror
        let frame = mirrorShape(m.insetBy(dx: -14, dy: -14))
        g.fill(frame, with: .linearGradient(Gradient(colors: [hx("#FFE6A8").c(), hx("#E9B864").c()]),
                                            startPoint: CGPoint(x: m.minX, y: m.minY), endPoint: CGPoint(x: m.maxX, y: m.maxY)))
        g.stroke(frame, with: .color(hx("#C98F45").c()), lineWidth: 3)
        // a shelf with a plant, towels and candles
        let shelf = CGRect(x: 110, y: 176, width: 230, height: 14)
        g.fill(Path(roundedRect: shelf, cornerRadius: 6), with: .color(.white))
        g.fill(Path(roundedRect: shelf.offsetBy(dx: 0, dy: 10).insetBy(dx: 6, dy: 2), cornerRadius: 5), with: .color(hx("#E7BCD0").c(0.5)))
        for (i, c) in ["#FFB3CF", "#BFE8FF", "#FFF2B0"].enumerated() {
            let r = CGRect(x: 248, y: 176 - CGFloat(i + 1) * 20, width: 80, height: 20)
            g.fill(Path(roundedRect: r, cornerRadius: 9), with: .color(hx(c).c()))
            g.stroke(Path(roundedRect: r, cornerRadius: 9), with: .color(hx(c).mul(0.8, 0.8, 0.85).c()), lineWidth: 2)
        }
        // plant
        var pot = Path()
        pot.move(to: CGPoint(x: 122, y: 136)); pot.addLine(to: CGPoint(x: 166, y: 136))
        pot.addLine(to: CGPoint(x: 160, y: 176)); pot.addLine(to: CGPoint(x: 128, y: 176)); pot.closeSubpath()
        g.fill(pot, with: .color(hx("#FFC09F").c()))
        for k in 0..<6 {
            let a = -CGFloat.pi / 2 + CGFloat(k - 3) * 0.38
            var leaf = Path()
            let base = CGPoint(x: 144, y: 136)
            let tip = CGPoint(x: base.x + cos(a) * 56, y: base.y + sin(a) * 56)
            leaf.move(to: base)
            leaf.addQuadCurve(to: tip, control: CGPoint(x: base.x + cos(a - 0.4) * 36, y: base.y + sin(a - 0.4) * 36))
            leaf.addQuadCurve(to: base, control: CGPoint(x: base.x + cos(a + 0.4) * 36, y: base.y + sin(a + 0.4) * 36))
            g.fill(leaf, with: .color(hx(k % 2 == 0 ? "#7FCF8E" : "#9EDCA0").c()))
        }
        for cx in [CGFloat(190), 222] {
            let r = CGRect(x: cx - 12, y: 140, width: 24, height: 36)
            g.fill(Path(roundedRect: r, cornerRadius: 5), with: .color(hx("#FFF7F2").c()))
            g.stroke(Path(roundedRect: r, cornerRadius: 5), with: .color(hx("#E9C9D6").c()), lineWidth: 2)
        }
        // the tap's wall plate and pipe
        let plate = CGRect(x: 718, y: 300, width: 80, height: 80)
        g.fill(Path(ellipseIn: plate), with: .radialGradient(Gradient(colors: [.white, hx("#C7D3DF").c()]), center: CGPoint(x: 740, y: 320), startRadius: 4, endRadius: 50))
    }

    static func mirrorShape(_ r: CGRect) -> Path {
        var p = Path()
        let rad = r.width / 2
        p.move(to: CGPoint(x: r.minX, y: r.maxY - 20))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        p.addArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - 20))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 20, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 20, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 20), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    // MARK: The moving scene

    static func draw(_ ctx: GraphicsContext, map: SMap, sim: SpaSim) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let t = sim.time
        drawMirror(g, sim: sim)
        drawCandles(g, t: t)
        drawSteam(g, sim: sim)
        drawFaucet(g, sim: sim)
        drawTubBack(g, sim: sim)
        drawGirl(g, sim: sim)
        for th in sim.things where !th.held { ThingPainter.draw(g, th, time: t) }
        drawWater(g, sim: sim)
        drawFoam(g, sim: sim)
        drawStream(g, sim: sim)
        drawPuddles(g, sim: sim)
        drawTubFront(g, sim: sim)
        for th in sim.things where th.held { ThingPainter.draw(g, th, time: t) }
        drawDrops(g, sim: sim)
        drawBubbles(g, sim: sim)
        drawPops(g, sim: sim)
        drawHints(g, sim: sim)
        if let tool = sim.tool { ToolPainter.drawHeld(g, tool, sim: sim) }
    }

    static func drawMirror(_ g: GraphicsContext, sim: SpaSim) {
        let m = SGeo.mirror
        let shape = mirrorShape(m)
        var mg = g
        mg.clip(to: shape)
        // a soft reflection of the room
        mg.fill(Path(m), with: .linearGradient(Gradient(colors: [hx("#E8F6FF").c(), hx("#FBE3F0").c()]),
                                               startPoint: CGPoint(x: m.minX, y: m.minY), endPoint: CGPoint(x: m.minX, y: m.maxY)))
        mg.fill(Path(ellipseIn: CGRect(x: m.minX + 40, y: m.maxY - 90, width: 150, height: 130)), with: .color(hx("#F4C9DA").c(0.5)))
        var shine = Path()
        shine.move(to: CGPoint(x: m.minX + 30, y: m.minY + 140)); shine.addLine(to: CGPoint(x: m.minX + 110, y: m.minY + 30))
        shine.addLine(to: CGPoint(x: m.minX + 140, y: m.minY + 30)); shine.addLine(to: CGPoint(x: m.minX + 60, y: m.minY + 140))
        mg.fill(shine, with: .color(.white.opacity(0.5)))
        // steam fog, in four levels so it's four fills
        let cw = m.width / CGFloat(SGeo.fogCols), ch = m.height / CGFloat(SGeo.fogRows)
        var paths = [Path(), Path(), Path(), Path()]
        for i in sim.fog.indices {
            let f = sim.fog[i]
            guard f > 0.08 else { continue }
            let lv = min(3, Int(f * 4))
            let c = CGPoint(x: m.minX + (CGFloat(i % SGeo.fogCols) + 0.5) * cw, y: m.minY + (CGFloat(i / SGeo.fogCols) + 0.5) * ch)
            let r = cw * 0.95
            paths[lv].addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        for (k, p) in paths.enumerated() { mg.fill(p, with: .color(.white.opacity(0.18 + Double(k) * 0.16))) }
    }

    static func drawCandles(_ g: GraphicsContext, t: Double) {
        for (k, cx) in [CGFloat(190), 222].enumerated() {
            let fl = 1 + 0.12 * sin(t * 11 + Double(k) * 2) + 0.06 * sin(t * 23 + Double(k))
            let tip = CGPoint(x: cx + CGFloat(sin(t * 3 + Double(k))) * 1.5, y: 120 - 8 * fl)
            var f = Path()
            f.move(to: CGPoint(x: cx - 5, y: 136))
            f.addQuadCurve(to: tip, control: CGPoint(x: cx - 7, y: 124))
            f.addQuadCurve(to: CGPoint(x: cx + 5, y: 136), control: CGPoint(x: cx + 7, y: 124))
            f.closeSubpath()
            g.fill(Path(ellipseIn: CGRect(x: cx - 22, y: 104, width: 44, height: 44)),
                   with: .radialGradient(Gradient(colors: [hx("#FFE9A0").c(0.45), hx("#FFE9A0").c(0)]), center: CGPoint(x: cx, y: 128), startRadius: 2, endRadius: 22))
            g.fill(f, with: .linearGradient(Gradient(colors: [hx("#FFF7C8").c(), hx("#FFAE45").c()]), startPoint: CGPoint(x: cx, y: 136), endPoint: tip))
            g.stroke(Path { p in p.move(to: CGPoint(x: cx, y: 140)); p.addLine(to: CGPoint(x: cx, y: 134)) }, with: .color(hx("#5B3A68").c()), lineWidth: 1.5)
        }
    }

    static func drawSteam(_ g: GraphicsContext, sim: SpaSim) {
        for s in sim.steam {
            let u = s.age / s.life
            let a = Double(sin(.pi * min(1, u)) * 0.22)
            g.fill(Path(ellipseIn: CGRect(x: s.p.x - s.r, y: s.p.y - s.r, width: s.r * 2, height: s.r * 2)),
                   with: .radialGradient(Gradient(colors: [Color.white.opacity(a), Color.white.opacity(0)]), center: s.p, startRadius: 0, endRadius: s.r))
        }
    }

    static func drawFaucet(_ g: GraphicsContext, sim: SpaSim) {
        let chrome = Gradient(colors: [.white, hx("#BFCCD9").c(), hx("#8FA0B3").c(), hx("#E4EBF2").c()])
        // the spout: out from the wall and curving down
        var pipe = Path()
        pipe.move(to: CGPoint(x: 760, y: 352))
        pipe.addLine(to: CGPoint(x: 800, y: 352))
        pipe.addQuadCurve(to: CGPoint(x: 800, y: 410), control: CGPoint(x: 826, y: 352))
        pipe.addLine(to: CGPoint(x: 772, y: 410))
        pipe.addQuadCurve(to: CGPoint(x: 776, y: 372), control: CGPoint(x: 778, y: 376))
        pipe.addLine(to: CGPoint(x: 760, y: 372))
        pipe.closeSubpath()
        g.fill(pipe, with: .linearGradient(chrome, startPoint: CGPoint(x: 760, y: 352), endPoint: CGPoint(x: 810, y: 412)))
        g.stroke(pipe, with: .color(hx("#7C8DA0").c()), lineWidth: 2)
        g.fill(Path(roundedRect: CGRect(x: 768, y: 406, width: 36, height: 14), cornerRadius: 5), with: .linearGradient(chrome, startPoint: CGPoint(x: 768, y: 406), endPoint: CGPoint(x: 804, y: 420)))
        // the cross handle, turning as the tap opens
        var h = g
        h.translateBy(x: SGeo.handle.x, y: SGeo.handle.y)
        h.rotate(by: .radians(Double(sim.handleTurn) * .pi / 2))
        for k in 0..<4 {
            var arm = h
            arm.rotate(by: .radians(Double(k) * .pi / 2))
            let r = Path(roundedRect: CGRect(x: -7, y: -38, width: 14, height: 36), cornerRadius: 7)
            arm.fill(r, with: .linearGradient(chrome, startPoint: CGPoint(x: -7, y: -38), endPoint: CGPoint(x: 7, y: 0)))
            arm.stroke(r, with: .color(hx("#7C8DA0").c()), lineWidth: 1.5)
            arm.fill(Path(ellipseIn: CGRect(x: -9, y: -46, width: 18, height: 14)), with: .color(k % 2 == 0 ? hx("#FF8FB8").c() : hx("#8FD0FF").c()))
        }
        h.fill(Path(ellipseIn: CGRect(x: -14, y: -14, width: 28, height: 28)), with: .radialGradient(chrome, center: CGPoint(x: -4, y: -4), startRadius: 1, endRadius: 16))
    }

    /// A rectangle with small top corners and big round bottom corners.
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
        tubShape(CGRect(x: SGeo.tubL, y: SGeo.lipY - 40, width: SGeo.tubR - SGeo.tubL, height: SGeo.tubBottom - SGeo.lipY + 40), top: 0, bottom: 60)
    }

    static func drawTubBack(_ g: GraphicsContext, sim: SpaSim) {
        let inner = tubInner()
        var b = g
        b.clip(to: inner)
        // the frosted back pane and the white enamel floor of the tub
        b.fill(Path(CGRect(x: SGeo.tubL, y: SGeo.lipY, width: SGeo.tubR - SGeo.tubL, height: SGeo.tubBottom - SGeo.lipY)),
               with: .linearGradient(Gradient(colors: [Color.white.opacity(0.35), hx("#DDEFF7").c(0.6)]),
                                     startPoint: CGPoint(x: 0, y: SGeo.lipY), endPoint: CGPoint(x: 0, y: SGeo.tubBottom)))
        b.stroke(Path { p in p.move(to: CGPoint(x: SGeo.tubL, y: SGeo.lipY + 2)); p.addLine(to: CGPoint(x: SGeo.tubR, y: SGeo.lipY + 2)) },
                 with: .color(.white.opacity(0.9)), lineWidth: 3)
        // the seat she sits on
        let seat = Path(roundedRect: SGeo.seat, cornerRadius: 14)
        b.fill(seat, with: .linearGradient(Gradient(colors: [Color.white, hx("#E6EEF5").c()]), startPoint: CGPoint(x: 0, y: SGeo.seat.minY), endPoint: CGPoint(x: 0, y: SGeo.seat.maxY)))
        b.stroke(seat, with: .color(hx("#C9D8E6").c()), lineWidth: 2)
        // the plug hole
        b.fill(Path(ellipseIn: CGRect(x: SGeo.drain.x - 20, y: SGeo.drain.y - 5, width: 40, height: 10)), with: .color(hx("#8FA0B3").c()))
        b.fill(Path(ellipseIn: CGRect(x: SGeo.drain.x - 13, y: SGeo.drain.y - 3, width: 26, height: 6)), with: .color(hx("#4A5868").c()))
        // glitter resting on the floor of the tub
        for gl in sim.glitter where gl.settled { glitterFleck(b, gl, t: sim.time) }
    }

    static func glitterFleck(_ g: GraphicsContext, _ gl: SGlitter, t: Double) {
        let tw = 0.5 + 0.5 * sin(Double(gl.phase) * 2.3 + t * 3)
        let s: CGFloat = 2.2 + 2.2 * CGFloat(tw)
        g.fill(Twinkle().path(in: CGRect(x: gl.p.x - s, y: gl.p.y - s, width: s * 2, height: s * 2)), with: .color(gl.color.c(0.6 + 0.4 * tw)))
    }

    // MARK: Her

    static func drawGirl(_ ctx: GraphicsContext, sim: SpaSim) {
        let e = sim.expression()
        guard let layers = sim.layers[e] else { return }
        var g = ctx
        g.translateBy(x: SGeo.dollOrigin.x, y: SGeo.dollOrigin.y + sim.bob)
        g.scaleBy(x: SGeo.dollScale, y: SGeo.dollScale)
        // her legs fade out behind the seat
        g.clipToLayer { m in
            m.fill(Path(CGRect(x: -200, y: -200, width: 1000, height: 1000)),
                   with: .linearGradient(Gradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.76),
                                                          .init(color: .clear, location: 0.84)]),
                                         startPoint: CGPoint(x: 0, y: -200), endPoint: CGPoint(x: 0, y: 800)))
        }
        let under: Set<String> = ["body", "under", "face", "hairBack", "nose", "cheeks", "makeup"]
        for (layer, p, item) in layers where under.contains(item.category) || item.id == "body" || item.id == "under" {
            ArtPainter.draw(layer.shapes, p, in: g)
        }
        drawMask(g, sim: sim)
        for (layer, p, item) in layers where !(under.contains(item.category) || item.id == "body" || item.id == "under") {
            ArtPainter.draw(layer.shapes, p, in: g)
        }
        for (i, on) in sim.cucumbers.enumerated() where on {
            var c = g
            c.translateBy(x: SGeo.eyes[i].x, y: SGeo.eyes[i].y + 2)
            ToolPainter.cucumber(c, r: 44)
        }
        // suds on her hair and shoulders
        var blobs: [(CGPoint, CGFloat)] = []
        for s in sim.suds {
            let w = CGFloat(sin(sim.time * 2 + Double(s.phase))) * 1.2
            blobs.append((CGPoint(x: s.d.x, y: s.d.y + w), s.r))
        }
        foamBlobs(g, blobs, color: RGB(1, 1, 1))
        // drops of water on her skin
        for b in sim.beads {
            let r = CGRect(x: b.d.x - b.r, y: b.d.y - b.r * 1.15, width: b.r * 2, height: b.r * 2.3)
            g.fill(Path(ellipseIn: r), with: .color(hx("#CDEFFF").c(0.35)))
            g.stroke(Path(ellipseIn: r), with: .color(.white.opacity(0.7)), lineWidth: 1.4)
            g.fill(Path(ellipseIn: CGRect(x: b.d.x - b.r * 0.5, y: b.d.y - b.r * 0.8, width: b.r * 0.6, height: b.r * 0.6)), with: .color(.white.opacity(0.95)))
        }
    }

    static func drawMask(_ ctx: GraphicsContext, sim: SpaSim) {
        guard sim.maskCov.contains(where: { $0 > 0.05 }) else { return }
        var g = ctx
        var clip = Path(ellipseIn: CGRect(x: SGeo.headC.x - SGeo.headRX + 4, y: SGeo.headC.y - SGeo.headRY + 4,
                                          width: (SGeo.headRX - 4) * 2, height: (SGeo.headRY - 4) * 2))
        for e in SGeo.eyes { clip.addEllipse(in: CGRect(x: e.x - 44, y: e.y - 38, width: 88, height: 76)) }
        clip.addEllipse(in: CGRect(x: SGeo.mouth.x - 24, y: SGeo.mouth.y - 15, width: 48, height: 30))
        g.clip(to: clip, style: FillStyle(eoFill: true))
        let r = SGeo.maskRect
        let cw = r.width / CGFloat(SGeo.maskCols)
        for k in MaskKind.allCases {
            var body = Path(), gloss = Path(), specks = Path(), cracks = Path()
            var dry: CGFloat = 0, n: CGFloat = 0
            for i in sim.maskCov.indices where sim.maskCov[i] > 0.05 && sim.maskKind[i] == k.rawValue {
                let c = sim.maskCellCenter(i)
                let cov = sim.maskCov[i]
                let rr = cw * (0.45 + 0.6 * sqrt(cov))
                body.addEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
                dry += sim.maskDry[i]; n += 1
                if sim.maskDry[i] < 0.6 && shash(i * 3) < 0.4 {
                    gloss.addEllipse(in: CGRect(x: c.x - rr * 0.5, y: c.y - rr * 0.6, width: rr * 0.55, height: rr * 0.35))
                }
                if shash(i * 7 + 1) < 0.5 {
                    specks.addEllipse(in: CGRect(x: c.x + (shash(i) - 0.5) * cw, y: c.y + (shash(i + 99) - 0.5) * cw, width: 2.4, height: 2.4))
                }
                if sim.maskDry[i] > 0.72 && cov > 0.6 && shash(i * 5 + 2) < 0.55 {
                    let a = shash(i * 11) * .pi
                    let l = cw * 0.9
                    cracks.move(to: CGPoint(x: c.x - cos(a) * l, y: c.y - sin(a) * l))
                    cracks.addLine(to: CGPoint(x: c.x + (shash(i * 13) - 0.5) * 5, y: c.y + (shash(i * 17) - 0.5) * 5))
                    cracks.addLine(to: CGPoint(x: c.x + cos(a + 0.5) * l, y: c.y + sin(a + 0.5) * l))
                }
            }
            guard n > 0 else { continue }
            let avgDry = Double(dry / n)
            let col = k.color.mix(RGB(1, 1, 1), avgDry * 0.4)
            g.fill(body, with: .color(col.c(0.95)))
            g.fill(specks, with: .color(Shades.shade(col).c(0.6)))
            g.fill(gloss, with: .color(.white.opacity(0.55 * (1 - avgDry))))
            g.stroke(cracks, with: .color(Shades.shade(k.color).c(0.75)), lineWidth: 1.6)
        }
    }

    // MARK: Water

    static func surfacePath(_ sim: SpaSim) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: SGeo.tubL, y: sim.level + sim.h[0]))
        for i in 0..<SGeo.columns { p.addLine(to: CGPoint(x: SGeo.colX(i), y: sim.level + sim.h[i])) }
        p.addLine(to: CGPoint(x: SGeo.tubR, y: sim.level + sim.h[SGeo.columns - 1]))
        return p
    }

    static func drawWater(_ ctx: GraphicsContext, sim: SpaSim) {
        guard sim.vol > 0.3 else {
            // a damp film on an empty tub
            return
        }
        var g = ctx
        g.clip(to: tubInner())
        var body = surfacePath(sim)
        body.addLine(to: CGPoint(x: SGeo.tubR, y: SGeo.tubBottom + 2))
        body.addLine(to: CGPoint(x: SGeo.tubL, y: SGeo.tubBottom + 2))
        body.closeSubpath()
        let top = sim.level - 20
        // water: clearer near the top, deeper blue lower down
        g.fill(body, with: .linearGradient(Gradient(colors: [water.c(0.32), deep.c(0.62)]),
                                           startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: SGeo.tubBottom)))
        // milky from bubble bath
        if sim.soapiness > 0.02 {
            g.fill(body, with: .color(Color.white.opacity(Double(sim.soapiness) * 0.22)))
        }
        // bath bomb color, varying along the tub
        if sim.tintA.contains(where: { $0 > 0.02 }) {
            var stops: [Gradient.Stop] = []
            let n = 16
            for k in 0...n {
                let i = min(SGeo.columns - 1, k * SGeo.columns / n)
                stops.append(.init(color: sim.tint[i].c(Double(min(0.7, sim.tintA[i] * 0.85))), location: CGFloat(k) / CGFloat(n)))
            }
            g.fill(body, with: .linearGradient(Gradient(stops: stops), startPoint: CGPoint(x: SGeo.tubL, y: 0), endPoint: CGPoint(x: SGeo.tubR, y: 0)))
        }
        var w = g
        w.clip(to: body)
        // color clouds from the bath bombs
        for p in sim.puffs {
            w.fill(Path(ellipseIn: CGRect(x: p.p.x - p.r, y: p.p.y - p.r, width: p.r * 2, height: p.r * 2)),
                   with: .radialGradient(Gradient(colors: [p.color.c(Double(p.a)), p.color.c(0)]), center: p.p, startRadius: 0, endRadius: p.r))
        }
        // light rippling on the bottom (caustics), stronger when the water moves
        let energy = min(1, sim.hv.reduce(0) { $0 + abs($1) } / 900)
        var caustic = Path()
        let t = sim.time
        for j in 0..<26 {
            let x = SGeo.tubL + 20 + CGFloat(j) * 28 + CGFloat(sin(t * 0.8 + Double(j) * 1.7)) * 10
            let y = SGeo.tubBottom - 8 - CGFloat(j % 3) * 9
            let wv = 18 + CGFloat(sin(t * 1.3 + Double(j))) * 6
            caustic.move(to: CGPoint(x: x, y: y))
            caustic.addQuadCurve(to: CGPoint(x: x + wv, y: y + 2), control: CGPoint(x: x + wv / 2, y: y - 6 + CGFloat(sin(t * 2 + Double(j))) * 3))
        }
        w.stroke(caustic, with: .color(.white.opacity(0.18 + 0.3 * Double(energy))), lineWidth: 2.2)
        // glitter drifting down
        for gl in sim.glitter where !gl.settled { glitterFleck(w, gl, t: t) }
        // air bubbles rising
        var rims = Path(), glints = Path()
        for b in sim.air {
            let r = CGRect(x: b.p.x - b.r, y: b.p.y - b.r, width: b.r * 2, height: b.r * 2 * 0.92)
            rims.addEllipse(in: r)
            glints.addEllipse(in: CGRect(x: b.p.x - b.r * 0.55, y: b.p.y - b.r * 0.6, width: b.r * 0.6, height: b.r * 0.5))
        }
        w.fill(rims, with: .color(.white.opacity(0.18)))
        w.stroke(rims, with: .color(.white.opacity(0.75)), lineWidth: 1.1)
        w.fill(glints, with: .color(.white.opacity(0.9)))
        // the shining surface
        let s = surfacePath(sim)
        g.stroke(s, with: .color(.white.opacity(0.85)), lineWidth: 3)
        g.stroke(s.offsetBy(dx: 0, dy: 5), with: .color(.white.opacity(0.25)), lineWidth: 4)
        // the plug hole swirl
        if sim.drainFlow > 0.05 && sim.vol > 2 {
            var sw = Path()
            let c = CGPoint(x: SGeo.drain.x, y: SGeo.drain.y - 6)
            let hgt = min(sim.vol, 120)
            for k in 0..<3 {
                let ph = t * 6 + Double(k) * 2.1
                for q in 0..<24 {
                    let u = CGFloat(q) / 23
                    let ang = CGFloat(ph) + u * 9
                    let rad = 6 + u * 22
                    let pt = CGPoint(x: c.x + cos(ang) * rad, y: c.y - u * hgt + sin(ang) * rad * 0.25)
                    if q == 0 { sw.move(to: pt) } else { sw.addLine(to: pt) }
                }
            }
            g.stroke(sw, with: .color(.white.opacity(0.5 * Double(sim.drainFlow))), lineWidth: 2)
        }
    }

    /// Foam: blobs with a shaded underside, a bright top and little glints.
    static func foamBlobs(_ g: GraphicsContext, _ blobs: [(CGPoint, CGFloat)], color: RGB) {
        guard !blobs.isEmpty else { return }
        var shade = Path(), main = Path(), hi = Path(), rims = Path()
        for (k, (c, r)) in blobs.enumerated() {
            shade.addEllipse(in: CGRect(x: c.x - r, y: c.y - r + r * 0.22, width: r * 2, height: r * 2))
            main.addEllipse(in: CGRect(x: c.x - r * 0.96, y: c.y - r, width: r * 1.92, height: r * 1.9))
            hi.addEllipse(in: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.7, width: r * 0.55, height: r * 0.4))
            if k % 3 == 0 { rims.addEllipse(in: CGRect(x: c.x - r * 0.3, y: c.y - r * 0.1, width: r * 0.6, height: r * 0.6)) }
        }
        g.fill(shade, with: .color(Shades.shade(color).mix(hx("#B9C9E6"), 0.4).c(0.95)))
        g.fill(main, with: .color(color.mix(RGB(1, 1, 1), 0.45).c()))
        g.stroke(rims, with: .color(Shades.shade(color).c(0.35)), lineWidth: 1)
        g.fill(hi, with: .color(.white))
    }

    static func drawFoam(_ ctx: GraphicsContext, sim: SpaSim) {
        guard sim.totalFoam > 0.05 else { return }
        var g = ctx
        g.clip(to: Path(CGRect(x: SGeo.tubL, y: 0, width: SGeo.tubR - SGeo.tubL, height: SGeo.tubBottom)))
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
                tr += sim.foamTint[i].r * wgt; tg += sim.foamTint[i].g * wgt; tb += sim.foamTint[i].b * wgt; wsum += wgt
                let x0 = SGeo.colX(i)
                let count = 1 + Int(min(3, f * 2.2))
                for k in 0..<count {
                    let seed = i * 7 + k
                    let x = x0 + (shash(seed) - 0.5) * 9
                    let size = (5 + 10 * shash(seed + 31)) * (0.5 + 0.5 * min(1.3, f))
                    let lift = f * 22 * shash(seed + 57)
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
        let top = CGPoint(x: SGeo.spout.x, y: SGeo.spout.y)
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
            left.append(CGPoint(x: x - ww / 2, y: y)); right.append(CGPoint(x: x + ww / 2, y: y))
        }
        p.move(to: left[0])
        for q in left.dropFirst() { p.addLine(to: q) }
        for q in right.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        g.fill(p, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.9), water.c(0.75), Color.white.opacity(0.85)]),
                                        startPoint: CGPoint(x: top.x - w, y: 0), endPoint: CGPoint(x: top.x + w, y: 0)))
        var core = Path()
        core.move(to: CGPoint(x: top.x - w * 0.15, y: top.y))
        core.addLine(to: CGPoint(x: land.x - w * 0.1, y: land.y))
        g.stroke(core, with: .color(.white.opacity(0.9)), lineWidth: 1.6)
        // churned white water where it lands
        if sim.vol > 1 {
            var churn: [(CGPoint, CGFloat)] = []
            for k in 0..<5 {
                let seed = Int(sim.time * 20) + k * 13
                churn.append((CGPoint(x: land.x + (shash(seed) - 0.5) * 26, y: land.y + (shash(seed + 3) - 0.5) * 6), 4 + 5 * shash(seed + 9) * sim.flow))
            }
            foamBlobs(g, churn, color: RGB(0.85, 0.96, 1))
        }
    }

    static func drawPuddles(_ g: GraphicsContext, sim: SpaSim) {
        for p in sim.puddles {
            let r = CGRect(x: p.x - p.r, y: SGeo.floorY - p.r * 0.12, width: p.r * 2, height: p.r * 0.3)
            g.fill(Path(ellipseIn: r), with: .color(hx("#B8E6FF").c(Double(p.a) * 0.55)))
            g.stroke(Path(ellipseIn: r), with: .color(.white.opacity(Double(p.a) * 0.7)), lineWidth: 1.5)
        }
    }

    static func drawTubFront(_ g: GraphicsContext, sim: SpaSim) {
        let outer = tubShape(CGRect(x: SGeo.tubL - 16, y: SGeo.lipY - 6, width: SGeo.tubR - SGeo.tubL + 32, height: SGeo.tubBottom - SGeo.lipY + 22), top: 8, bottom: 74)
        // feet
        for fx in [SGeo.tubL + 40, SGeo.tubR - 40] {
            var foot = Path()
            foot.move(to: CGPoint(x: fx - 18, y: SGeo.tubBottom + 10))
            foot.addQuadCurve(to: CGPoint(x: fx - 26, y: SGeo.floorY), control: CGPoint(x: fx - 30, y: SGeo.tubBottom + 30))
            foot.addLine(to: CGPoint(x: fx + 26, y: SGeo.floorY))
            foot.addQuadCurve(to: CGPoint(x: fx + 18, y: SGeo.tubBottom + 10), control: CGPoint(x: fx + 30, y: SGeo.tubBottom + 30))
            foot.closeSubpath()
            g.fill(foot, with: .linearGradient(Gradient(colors: [hx("#FFE6A8").c(), hx("#E0A955").c()]), startPoint: CGPoint(x: fx - 20, y: 0), endPoint: CGPoint(x: fx + 20, y: 0)))
        }
        // the glass: a faint tint, edges and reflections
        var glass = outer
        glass.addPath(tubInner())
        g.fill(glass, with: .color(hx("#DFF6FF").c(0.55)), style: FillStyle(eoFill: true))
        g.stroke(outer, with: .color(.white.opacity(0.95)), lineWidth: 3)
        g.stroke(tubInner(), with: .color(hx("#A9D9EC").c(0.6)), lineWidth: 1.5)
        var refl = g
        refl.clip(to: outer)
        for (x0, wd) in [(CGFloat(150), CGFloat(34)), (198, 12), (640, 26)] {
            var band = Path()
            band.move(to: CGPoint(x: x0, y: SGeo.tubBottom + 20))
            band.addLine(to: CGPoint(x: x0 + 90, y: SGeo.lipY - 6))
            band.addLine(to: CGPoint(x: x0 + 90 + wd, y: SGeo.lipY - 6))
            band.addLine(to: CGPoint(x: x0 + wd, y: SGeo.tubBottom + 20))
            band.closeSubpath()
            refl.fill(band, with: .color(.white.opacity(0.16)))
        }
        // the lip
        let lip = Path(roundedRect: CGRect(x: SGeo.tubL - 18, y: SGeo.lipY - 9, width: SGeo.tubR - SGeo.tubL + 36, height: 10), cornerRadius: 5)
        g.fill(lip, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.95), hx("#CFEAF5").c(0.7)]), startPoint: CGPoint(x: 0, y: SGeo.lipY - 9), endPoint: CGPoint(x: 0, y: SGeo.lipY + 1)))
        // the plug on its chain
        let ring = SGeo.plugRing
        let plug = sim.plugOut ? CGPoint(x: ring.x - 26, y: ring.y + 120) : CGPoint(x: SGeo.drain.x, y: SGeo.drain.y - 8)
        var chain = Path()
        let links = 22
        for k in 0...links {
            let u = CGFloat(k) / CGFloat(links)
            let sag = sin(u * .pi) * (sim.plugOut ? 10 : 18)
            let pt = CGPoint(x: ring.x + (plug.x - ring.x) * u - sag, y: ring.y + (plug.y - ring.y) * u)
            chain.addEllipse(in: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5))
        }
        g.stroke(chain, with: .color(hx("#9AA9B8").c()), lineWidth: 1.6)
        g.fill(Path(ellipseIn: CGRect(x: ring.x - 9, y: ring.y - 9, width: 18, height: 18)), with: .color(hx("#C7D3DF").c()))
        g.stroke(Path(ellipseIn: CGRect(x: ring.x - 9, y: ring.y - 9, width: 18, height: 18)), with: .color(hx("#7C8DA0").c()), lineWidth: 2)
        let stopper = Path(roundedRect: CGRect(x: plug.x - 17, y: plug.y - 8, width: 34, height: 16), cornerRadius: 6)
        g.fill(stopper, with: .color(hx("#FF8FB8").c()))
        g.stroke(stopper, with: .color(hx("#D9668F").c()), lineWidth: 2)
    }

    static func drawDrops(_ g: GraphicsContext, sim: SpaSim) {
        var water = Path(), soap = Path(), glint = Path()
        for d in sim.drops {
            let sp = max(1, hypot(d.v.dx, d.v.dy))
            let stretch = min(2.6, 1 + sp / 900)
            let ang = atan2(d.v.dy, d.v.dx)
            let r = d.r
            var e = Path(ellipseIn: CGRect(x: -r * stretch, y: -r, width: r * 2 * stretch, height: r * 2))
            e = e.applying(CGAffineTransform(rotationAngle: ang).concatenating(CGAffineTransform(translationX: d.p.x, y: d.p.y)))
            if d.kind == .soap { soap.addPath(e) } else { water.addPath(e) }
            if r > 2 { glint.addEllipse(in: CGRect(x: d.p.x - r * 0.4, y: d.p.y - r * 0.5, width: r * 0.6, height: r * 0.6)) }
        }
        g.fill(water, with: .color(hx("#BDEBFF").c(0.85)))
        g.stroke(water, with: .color(.white.opacity(0.8)), lineWidth: 0.8)
        g.fill(soap, with: .color(hx("#FF9EC6").c(0.95)))
        g.fill(glint, with: .color(.white))
    }

    static func drawBubbles(_ g: GraphicsContext, sim: SpaSim) {
        let film = Gradient(colors: [hx("#FF9ECF").c(0.75), hx("#FFE38A").c(0.7), hx("#9FF0D8").c(0.7), hx("#8FC6FF").c(0.75),
                                     hx("#C9A6FF").c(0.75), hx("#FF9ECF").c(0.75)])
        for b in sim.bubbles {
            let wob = 1 + 0.04 * sin(Double(b.phase) * 5 + sim.time * 7)
            let rx = b.r * CGFloat(wob), ry = b.r / CGFloat(wob)
            let rect = CGRect(x: b.p.x - rx, y: b.p.y - ry, width: rx * 2, height: ry * 2)
            let fade = Double(min(1, (b.life - b.age) / 0.6 + 0.3))
            var bg = g
            bg.opacity = fade
            if b.star {
                bg.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0x97499A).opacity(0.8)))
                bg.fill(Twinkle().path(in: rect.insetBy(dx: 15, dy: 15)), with: .color(Color(hex: 0xFFEB87)))
            }
            bg.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.02), Color.white.opacity(0.22)]),
                                                                  center: b.p, startRadius: b.r * 0.4, endRadius: b.r))
            bg.stroke(Path(ellipseIn: rect), with: .conicGradient(film, center: b.p, angle: .radians(Double(b.phase) + sim.time * 0.7)), lineWidth: max(1.4, b.r * 0.1))
            bg.fill(Path(ellipseIn: CGRect(x: b.p.x - b.r * 0.62, y: b.p.y - b.r * 0.66, width: b.r * 0.46, height: b.r * 0.3)), with: .color(.white.opacity(0.9)))
            bg.fill(Path(roundedRect: CGRect(x: b.p.x + b.r * 0.28, y: b.p.y + b.r * 0.3, width: b.r * 0.22, height: b.r * 0.16), cornerRadius: 2), with: .color(.white.opacity(0.45)))
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
                    g.fill(Twinkle().path(in: CGRect(x: c.x - s, y: c.y - s, width: s * 2, height: s * 2)),
                           with: .color((k % 2 == 0 ? hx("#FFE38A") : hx("#FF9EC6")).c(Double(1 - u))))
                }
            } else {
                let u = p.age / 0.22
                let r = p.r * (1 + u * 0.6)
                g.stroke(Path(ellipseIn: CGRect(x: p.p.x - r, y: p.p.y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(Double(1 - u) * 0.8)), style: StrokeStyle(lineWidth: 2, dash: [4, 6]))
            }
        }
    }

    static func drawHints(_ g: GraphicsContext, sim: SpaSim) {
        // an empty tub: the tap handle glows
        if sim.vol < 6 && !sim.tapOn && sim.tool == nil {
            let u = CGFloat(0.5 + 0.5 * sin(sim.time * 4))
            let r = 52 + 8 * u
            g.stroke(Path(ellipseIn: CGRect(x: SGeo.handle.x - r, y: SGeo.handle.y - r, width: r * 2, height: r * 2)),
                     with: .color(Theme.pink.opacity(0.4 + 0.4 * Double(u))), lineWidth: 5)
        }
        // a full tub with the tap still on: the overflow gurgles, so the handle glows softly
        if sim.vol >= SGeo.maxDepth - 0.5 && sim.tapOn {
            let r: CGFloat = 54
            g.stroke(Path(ellipseIn: CGRect(x: SGeo.handle.x - r, y: SGeo.handle.y - r, width: r * 2, height: r * 2)),
                     with: .color(Theme.sky.opacity(0.5 + 0.3 * sin(sim.time * 5))), lineWidth: 4)
        }
    }
}

// MARK: - Toys and bath bombs

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
            case .duck: duck(g, body: hx("#FFD84A"), scale: 1)
            case .duckling: duck(g, body: hx("#FFB3D1"), scale: 0.66)
            case .boat: boat(g)
            case .whale: whale(g)
            case .turtle: turtle(g, t: time)
            case .cucumber: ToolPainter.cucumber(g, r: 20, edge: true)
            }
        case .bomb(let k): bomb(g, k, fizz: t.fizz, fizzing: t.wetFor > 0.3, time: time)
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

    static func boat(_ g: GraphicsContext) {
        let hullC = hx("#FF6F7D")
        var hull = Path()
        hull.move(to: CGPoint(x: -50, y: 8))
        hull.addLine(to: CGPoint(x: 50, y: 8))
        hull.addQuadCurve(to: CGPoint(x: 30, y: 40), control: CGPoint(x: 46, y: 32))
        hull.addLine(to: CGPoint(x: -34, y: 40))
        hull.addQuadCurve(to: CGPoint(x: -50, y: 8), control: CGPoint(x: -48, y: 30))
        hull.closeSubpath()
        g.fill(hull, with: .linearGradient(Gradient(colors: [hullC.c(), Shades.shade(hullC).c()]), startPoint: CGPoint(x: 0, y: 8), endPoint: CGPoint(x: 0, y: 40)))
        g.stroke(hull, with: .color(outline(hullC)), lineWidth: 3)
        g.fill(Path(CGRect(x: -46, y: 16, width: 92, height: 6)), with: .color(.white))
        for k in 0..<3 { g.fill(Path(ellipseIn: CGRect(x: -26 + CGFloat(k) * 20, y: 25, width: 8, height: 8)), with: .color(hx("#BFE8FF").c())) }
        g.fill(Path(CGRect(x: -3, y: -46, width: 6, height: 54)), with: .color(hx("#C98F45").c()))
        var sail = Path()
        sail.move(to: CGPoint(x: 5, y: -42)); sail.addQuadCurve(to: CGPoint(x: 5, y: 2), control: CGPoint(x: 44, y: -10)); sail.closeSubpath()
        g.fill(sail, with: .color(.white))
        g.stroke(sail, with: .color(hx("#C9B6FF").c()), lineWidth: 2.5)
        var sail2 = Path()
        sail2.move(to: CGPoint(x: -5, y: -34)); sail2.addQuadCurve(to: CGPoint(x: -5, y: 2), control: CGPoint(x: -34, y: -6)); sail2.closeSubpath()
        g.fill(sail2, with: .color(hx("#C9B6FF").c()))
        var flag = Path()
        flag.move(to: CGPoint(x: 3, y: -46)); flag.addLine(to: CGPoint(x: 20, y: -41)); flag.addLine(to: CGPoint(x: 3, y: -36)); flag.closeSubpath()
        g.fill(flag, with: .color(hx("#FFE38A").c()))
    }

    static func whale(_ g: GraphicsContext) {
        let c = hx("#6FB6FF")
        var b = Path()
        b.move(to: CGPoint(x: 50, y: 6))
        b.addQuadCurve(to: CGPoint(x: -10, y: -34), control: CGPoint(x: 46, y: -36))
        b.addQuadCurve(to: CGPoint(x: -40, y: 4), control: CGPoint(x: -36, y: -30))
        b.addQuadCurve(to: CGPoint(x: -60, y: -22), control: CGPoint(x: -48, y: -6))
        b.addQuadCurve(to: CGPoint(x: -52, y: 18), control: CGPoint(x: -68, y: 4))
        b.addQuadCurve(to: CGPoint(x: -34, y: 22), control: CGPoint(x: -44, y: 22))
        b.addQuadCurve(to: CGPoint(x: 50, y: 6), control: CGPoint(x: 30, y: 46))
        b.closeSubpath()
        g.fill(b, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]), startPoint: CGPoint(x: 0, y: -34), endPoint: CGPoint(x: 0, y: 34)))
        g.stroke(b, with: .color(outline(c)), lineWidth: 3)
        var belly = Path()
        belly.move(to: CGPoint(x: -20, y: 18)); belly.addQuadCurve(to: CGPoint(x: 46, y: 10), control: CGPoint(x: 16, y: 38))
        belly.addQuadCurve(to: CGPoint(x: -20, y: 18), control: CGPoint(x: 16, y: 18))
        g.fill(belly, with: .color(hx("#DFF1FF").c()))
        g.fill(Path(ellipseIn: CGRect(x: 22, y: -12, width: 8, height: 10)), with: .color(hx("#2E3A55").c()))
        g.fill(Path(ellipseIn: CGRect(x: 24, y: -10, width: 3, height: 3)), with: .color(.white))
        g.stroke(Path { p in p.move(to: CGPoint(x: 30, y: 4)); p.addQuadCurve(to: CGPoint(x: 44, y: 2), control: CGPoint(x: 38, y: 10)) }, with: .color(hx("#2E3A55").c()), lineWidth: 2)
        g.fill(Path(ellipseIn: CGRect(x: 30, y: -2, width: 8, height: 5)), with: .color(hx("#FF8FB8").c(0.6)))
        g.fill(Path(ellipseIn: CGRect(x: 2, y: -34, width: 8, height: 4)), with: .color(Shades.deep(c).c()))
    }

    static func turtle(_ g: GraphicsContext, t: Double) {
        let skin = hx("#8EDB8A"), shell = hx("#3FAF78")
        let pad = CGFloat(sin(t * 5)) * 3
        for (x, y) in [(-30, 14), (26, 14)] {
            g.fill(Path(ellipseIn: CGRect(x: CGFloat(x) - 10 + pad, y: CGFloat(y), width: 20, height: 12)), with: .color(skin.c()))
        }
        g.fill(Path(ellipseIn: CGRect(x: 32, y: -6, width: 22, height: 20)), with: .color(skin.c()))
        g.stroke(Path(ellipseIn: CGRect(x: 32, y: -6, width: 22, height: 20)), with: .color(outline(skin)), lineWidth: 2)
        g.fill(Path(ellipseIn: CGRect(x: 44, y: 0, width: 5, height: 6)), with: .color(hx("#2E3A35").c()))
        var dome = Path()
        dome.move(to: CGPoint(x: -42, y: 14)); dome.addQuadCurve(to: CGPoint(x: 40, y: 14), control: CGPoint(x: 0, y: -46)); dome.closeSubpath()
        g.fill(dome, with: .linearGradient(Gradient(colors: [Shades.light(shell).c(), shell.c()]), startPoint: CGPoint(x: 0, y: -22), endPoint: CGPoint(x: 0, y: 14)))
        g.stroke(dome, with: .color(outline(shell)), lineWidth: 3)
        var hexes = Path()
        for (cx, cy) in [(-16, 2), (6, -6), (24, 4), (-2, 8)] {
            hexes.addEllipse(in: CGRect(x: CGFloat(cx) - 8, y: CGFloat(cy) - 6, width: 16, height: 12))
        }
        g.fill(hexes, with: .color(Shades.light(shell).c(0.6)))
        g.fill(Path(roundedRect: CGRect(x: -44, y: 12, width: 86, height: 7), cornerRadius: 3), with: .color(hx("#FFE38A").c()))
    }

    static func bomb(_ g: GraphicsContext, _ k: BombKind, fizz: CGFloat, fizzing: Bool, time: Double) {
        let r = 30 * (0.3 + 0.7 * sqrt(max(0, fizz)))
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
            g.fill(p, with: .conicGradient(Gradient(colors: ["#FF6F91", "#FFB347", "#FFE066", "#6EE7A0", "#5EC2FF", "#B497FF", "#FF6F91"].map { hx($0).c() }),
                                           center: .zero, angle: .radians(time * 0.5)))
        } else {
            g.fill(p, with: .radialGradient(Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]), center: CGPoint(x: -r * 0.35, y: -r * 0.4), startRadius: 1, endRadius: r * 1.4))
        }
        g.stroke(p, with: .color(Shades.outline(c).c(0.7)), lineWidth: 2.5)
        // speckles of dried petals and sparkle
        var sp = Path()
        for q in 0..<14 {
            let a = shash(q * 3 + k.rawValue.count) * 2 * .pi, d = sqrt(shash(q * 5 + 1)) * r * 0.8
            sp.addEllipse(in: CGRect(x: cos(a) * d - 1.6, y: sin(a) * d - 1.6, width: 3.2, height: 3.2))
        }
        g.fill(sp, with: .color(k.glitter ? hx("#FFF6C8").c() : Color.white.opacity(0.8)))
        g.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.62, width: r * 0.5, height: r * 0.32)), with: .color(.white.opacity(0.55)))
    }
}

// MARK: - Tools

enum ToolPainter {
    static func drawHeld(_ ctx: GraphicsContext, _ tool: SpaTool, sim: SpaSim) {
        var g = ctx
        let p = sim.toolP
        let over = SGeo.onHer(SGeo.toDoll(p), pad: 30) || sim.inTub(p)
        if over && tool != .soap && tool != .wand { g.opacity = FingerLift.seeThrough + 0.2 }
        switch tool {
        case .soap:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(sim.toolAngle)))
            soapBottle(b)
        case .wand:
            wand(g, tip: p, finger: sim.toolFinger, film: sim.wandFilm, v: sim.toolV, t: sim.time)
        case .sponge:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(max(-0.3, min(0.3, sim.toolV.dx / 3000)))))
            b.scaleBy(x: 1.4, y: 1.4)   // held by the middle: bigger than her fingertip all round
            sponge(b, wet: sim.spongeWet, foam: sim.spongeFoam, t: sim.time)
        case .shower:
            shower(g, head: p, finger: sim.toolFinger)
        case .towel:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            b.rotate(by: .radians(Double(max(-0.25, min(0.25, sim.toolV.dx / 4000)))))
            b.scaleBy(x: 1.3, y: 1.3)
            towel(b, wet: sim.towelWet)
        case .mask(let k):
            maskBrush(g, tip: p, finger: sim.toolFinger, kind: k)
        case .cucumber:
            var b = g
            b.translateBy(x: p.x, y: p.y)
            cucumber(b, r: 34)
        }
    }

    static func soapBottle(_ g: GraphicsContext) {
        let c = hx("#FF9EC6")
        let body = Path(roundedRect: CGRect(x: -30, y: -36, width: 60, height: 84), cornerRadius: 22)
        g.fill(body, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]), startPoint: CGPoint(x: -30, y: 0), endPoint: CGPoint(x: 30, y: 0)))
        g.stroke(body, with: .color(Shades.outline(c).c()), lineWidth: 3)
        let neck = Path(roundedRect: CGRect(x: -12, y: -54, width: 24, height: 22), cornerRadius: 5)
        g.fill(neck, with: .color(.white))
        g.stroke(neck, with: .color(hx("#D9A3BF").c()), lineWidth: 2)
        g.fill(Path(roundedRect: CGRect(x: -6, y: -64, width: 12, height: 12), cornerRadius: 3), with: .color(hx("#C9B6FF").c()))
        // a label of bubbles
        let label = Path(roundedRect: CGRect(x: -22, y: -10, width: 44, height: 40), cornerRadius: 10)
        g.fill(label, with: .color(.white.opacity(0.92)))
        for (x, y, r) in [(-8.0, 6.0, 9.0), (8.0, 0.0, 6.0), (6.0, 16.0, 5.0)] {
            let rr = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            g.stroke(Path(ellipseIn: rr), with: .color(hx("#8FC6FF").c()), lineWidth: 2)
            g.fill(Path(ellipseIn: CGRect(x: x - r * 0.5, y: y - r * 0.6, width: r * 0.5, height: r * 0.4)), with: .color(hx("#8FC6FF").c(0.6)))
        }
        g.fill(Path(roundedRect: CGRect(x: -24, y: -30, width: 8, height: 64), cornerRadius: 4), with: .color(.white.opacity(0.35)))
    }

    static func wand(_ g: GraphicsContext, tip: CGPoint, finger: CGPoint, film: CGFloat, v: CGVector, t: Double) {
        let (u, len) = FingerLift.handle(tip: tip, finger: finger, length: 150)
        let ux = u.dx, uy = u.dy
        // a big ring around her fingertip, the stick standing up from it
        let ringR: CGFloat = 26 * FingerLift.spread
        let stickStart = CGPoint(x: tip.x + ux * ringR, y: tip.y + uy * ringR)
        let stickEnd = CGPoint(x: tip.x + ux * max(ringR + 20, len), y: tip.y + uy * max(ringR + 20, len))
        var stick = Path(); stick.move(to: stickStart); stick.addLine(to: stickEnd)
        g.stroke(stick, with: .color(hx("#9F7BEF").c()), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        g.stroke(stick, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let ring = Path(ellipseIn: CGRect(x: tip.x - ringR, y: tip.y - ringR, width: ringR * 2, height: ringR * 2))
        if film > 0.04 {
            // the soap film bulges away from the way it moves
            let sp = hypot(v.dx, v.dy)
            let bulge = min(16 * FingerLift.spread, sp / 60)
            let bx = sp > 1 ? -v.dx / sp * bulge : 0, by = sp > 1 ? -v.dy / sp * bulge : 0
            let fr = CGRect(x: tip.x - ringR + min(0, bx), y: tip.y - ringR + min(0, by), width: ringR * 2 + abs(bx), height: ringR * 2 + abs(by))
            g.fill(Path(ellipseIn: fr), with: .conicGradient(Gradient(colors: [hx("#FF9ECF").c(0.35), hx("#9FF0D8").c(0.3), hx("#8FC6FF").c(0.35), hx("#FF9ECF").c(0.35)]),
                                                              center: tip, angle: .radians(t)))
        }
        g.stroke(ring, with: .color(hx("#B08CFF").c()), lineWidth: 6)
        g.stroke(ring, with: .color(.white.opacity(0.5)), lineWidth: 2)
    }

    static func sponge(_ g: GraphicsContext, wet: CGFloat, foam: CGFloat, t: Double) {
        let c = hx("#FFE07A").mix(hx("#F2B94B"), Double(wet) * 0.6)
        let body = Path(roundedRect: CGRect(x: -46, y: -30, width: 92, height: 60), cornerRadius: 18)
        g.fill(body, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c(), Shades.shade(c).c()]), startPoint: CGPoint(x: 0, y: -30), endPoint: CGPoint(x: 0, y: 30)))
        g.stroke(body, with: .color(Shades.outline(c).c()), lineWidth: 3)
        var pores = Path()
        for q in 0..<16 {
            let x = -36 + shash(q) * 72, y = -20 + shash(q + 40) * 40, r = 2 + shash(q + 80) * 4
            pores.addEllipse(in: CGRect(x: x - r, y: y - r * 0.8, width: r * 2, height: r * 1.6))
        }
        g.fill(pores, with: .color(Shades.shade(c).c(0.8)))
        if wet > 0.3 { g.fill(Path(roundedRect: CGRect(x: -38, y: -24, width: 30, height: 8), cornerRadius: 4), with: .color(.white.opacity(0.5 * Double(wet)))) }
        if foam > 0.05 {
            var blobs: [(CGPoint, CGFloat)] = []
            for q in 0..<Int(3 + foam * 8) {
                blobs.append((CGPoint(x: -40 + shash(q * 3) * 80, y: -28 + shash(q * 3 + 1) * 10 + CGFloat(sin(t * 2 + Double(q))) * 0.8), 6 + shash(q * 3 + 2) * 8 * foam))
            }
            SpaPainter.foamBlobs(g, blobs, color: RGB(1, 1, 1))
        }
    }

    static func shower(_ g: GraphicsContext, head: CGPoint, finger: CGPoint) {
        // the hose curls away down to the bottom right
        var hose = Path()
        hose.move(to: CGPoint(x: head.x + 22, y: head.y + 10))
        hose.addCurve(to: CGPoint(x: 1080, y: 900), control1: CGPoint(x: head.x + 90, y: head.y + 40), control2: CGPoint(x: finger.x + 40, y: 980))
        g.stroke(hose, with: .color(hx("#A9B7C6").c()), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        g.stroke(hose, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 4]))
        let chrome = Gradient(colors: [.white, hx("#BFCCD9").c(), hx("#8FA0B3").c()])
        var handle = Path()
        handle.move(to: CGPoint(x: head.x + 10, y: head.y - 6))
        handle.addLine(to: CGPoint(x: head.x + 54, y: head.y + 20))
        g.stroke(handle, with: .linearGradient(chrome, startPoint: CGPoint(x: head.x, y: head.y - 10), endPoint: CGPoint(x: head.x + 20, y: head.y + 20)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        let face = CGRect(x: head.x - 34, y: head.y - 14, width: 68, height: 30)
        g.fill(Path(ellipseIn: face), with: .linearGradient(chrome, startPoint: CGPoint(x: face.minX, y: face.minY), endPoint: CGPoint(x: face.maxX, y: face.maxY)))
        g.stroke(Path(ellipseIn: face), with: .color(hx("#7C8DA0").c()), lineWidth: 2)
        var holes = Path()
        for q in 0..<11 {
            let a = CGFloat(q) / 11 * 2 * .pi
            holes.addEllipse(in: CGRect(x: head.x + cos(a) * 20 - 2, y: head.y + 2 + sin(a) * 7 - 1.5, width: 4, height: 3))
        }
        g.fill(holes, with: .color(hx("#5A6878").c()))
    }

    static func towel(_ g: GraphicsContext, wet: CGFloat) {
        let c = hx("#FFB3CF").mix(hx("#E98FB2"), Double(wet) * 0.5)
        var t = Path()
        t.move(to: CGPoint(x: -60, y: -30))
        for q in 0...12 {
            let x = -60 + CGFloat(q) * 10
            t.addQuadCurve(to: CGPoint(x: x + 10, y: -30), control: CGPoint(x: x + 5, y: -36))
        }
        t.addLine(to: CGPoint(x: 70, y: 30))
        t.addQuadCurve(to: CGPoint(x: -60, y: 30), control: CGPoint(x: 5, y: 40))
        t.closeSubpath()
        g.fill(t, with: .linearGradient(Gradient(colors: [Shades.light(c).c(), c.c()]), startPoint: CGPoint(x: 0, y: -30), endPoint: CGPoint(x: 0, y: 34)))
        g.stroke(t, with: .color(Shades.outline(c).c()), lineWidth: 3)
        g.fill(Path(CGRect(x: -58, y: 4, width: 126, height: 7)), with: .color(.white.opacity(0.85)))
        g.fill(Path(CGRect(x: -58, y: 15, width: 126, height: 3)), with: .color(.white.opacity(0.7)))
        var loops = Path()
        for q in 0..<30 { loops.addEllipse(in: CGRect(x: -54 + shash(q) * 116, y: -24 + shash(q + 30) * 50, width: 3, height: 3)) }
        g.fill(loops, with: .color(Shades.shade(c).c(0.5)))
    }

    static func maskBrush(_ g: GraphicsContext, tip: CGPoint, finger: CGPoint, kind: MaskKind) {
        let (u, len) = FingerLift.handle(tip: tip, finger: finger, length: 150)
        let ux = u.dx, uy = u.dy
        let a = CGPoint(x: tip.x + ux * 18 * FingerLift.spread, y: tip.y + uy * 18 * FingerLift.spread)
        let b = CGPoint(x: tip.x + ux * len, y: tip.y + uy * len)
        var stick = Path(); stick.move(to: a); stick.addLine(to: b)
        g.stroke(stick, with: .color(hx("#FFF7F2").c()), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        g.stroke(stick, with: .color(hx("#E9C9D6").c()), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        // a flat brush loaded with mask
        var head = g
        head.translateBy(x: tip.x, y: tip.y)
        head.rotate(by: .radians(Double(atan2(uy, ux)) - .pi / 2))
        // a wide brush, wider than her fingertip
        head.scaleBy(x: FingerLift.spread, y: FingerLift.spread)
        let bristles = Path(roundedRect: CGRect(x: -15, y: 0, width: 30, height: 26), cornerRadius: 6)
        head.fill(bristles, with: .color(hx("#F4E3C8").c()))
        let blob = Path(roundedRect: CGRect(x: -17, y: -8, width: 34, height: 18), cornerRadius: 9)
        head.fill(blob, with: .color(kind.color.c()))
        head.stroke(blob, with: .color(Shades.shade(kind.color).c()), lineWidth: 2)
        head.fill(Path(roundedRect: CGRect(x: -16, y: 24, width: 32, height: 8), cornerRadius: 3), with: .color(hx("#C9B6FF").c()))
    }

    /// A cucumber slice, face on (or a little tipped, `edge`).
    static func cucumber(_ g: GraphicsContext, r: CGFloat, edge: Bool = false) {
        var c = g
        if edge { c.scaleBy(x: 1, y: 0.45) }
        let outer = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        c.fill(outer, with: .color(hx("#3E9A4E").c()))
        c.fill(Path(ellipseIn: CGRect(x: -r * 0.86, y: -r * 0.86, width: r * 1.72, height: r * 1.72)), with: .color(hx("#9EDC86").c()))
        c.fill(Path(ellipseIn: CGRect(x: -r * 0.74, y: -r * 0.74, width: r * 1.48, height: r * 1.48)),
               with: .radialGradient(Gradient(colors: [hx("#F1FBD8").c(), hx("#C9EDA8").c()]), center: .zero, startRadius: 0, endRadius: r * 0.74))
        var seeds = Path()
        for q in 0..<7 {
            let a = CGFloat(q) / 7 * 2 * .pi
            let p = CGPoint(x: cos(a) * r * 0.36, y: sin(a) * r * 0.36)
            seeds.addEllipse(in: CGRect(x: p.x - r * 0.07, y: p.y - r * 0.12, width: r * 0.14, height: r * 0.24))
        }
        c.fill(seeds, with: .color(hx("#E8F6C8").c()))
        c.stroke(seeds, with: .color(hx("#B6DA94").c()), lineWidth: 1)
        c.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.6, width: r * 0.4, height: r * 0.24)), with: .color(.white.opacity(0.7)))
    }
}
