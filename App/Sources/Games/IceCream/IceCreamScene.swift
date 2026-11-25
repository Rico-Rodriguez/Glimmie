import SwiftUI

// MARK: - Drawing the shop
//
// Two layers: the backdrop (wall, window and the street outside) only changes with the station, and the shop layer
// (counter, the machines, the treat, what she's holding, everything that moves) is drawn every frame. The customer
// stands between the two, so the window sill in the shop layer hides their legs.

/// Maps the 1024 x 834 design space onto the screen (as `DesignCanvas` does), with the shop filling any extra width.
struct ICMap {
    let size: CGSize
    let s: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    init(size: CGSize) {
        self.size = size
        let h = DesignCanvas<EmptyView>.designHeight
        let scale = max(0.1, size.height / h)
        let w = max(1024, size.width / scale)
        s = min(scale, size.width / w)
        ox = size.width / 2 - 512 * s
        oy = size.height / 2 - 417 * s
    }

    func design(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - ox) / s, y: (p.y - oy) / s) }
    var visible: CGRect { CGRect(x: -ox / s, y: -oy / s, width: size.width / s, height: size.height / s) }
}

enum ICScene {
    // MARK: Backdrop

    static func drawBackdrop(_ ctx: GraphicsContext, map: ICMap, station: ICStation) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let r = map.visible
        // striped wallpaper
        let wall = station == .bingsu ? ICColor(0xF2F9FF) : ICColor(0xFFF4EC)
        let stripe = station == .bingsu ? ICColor(0xDFF0FF) : ICColor(0xFFE2EC)
        g.fill(Path(r), with: .color(wall.color))
        var x = (r.minX / 64).rounded(.down) * 64
        while x < r.maxX {
            g.fill(Path(CGRect(x: x, y: r.minY, width: 32, height: r.height)), with: .color(stripe.color(0.7)))
            x += 64
        }
        // a scalloped awning along the top
        let awn = station == .bingsu ? ICColor(0x88CCF4) : ICColor(0xFF8FB8)
        g.fill(Path(CGRect(x: r.minX, y: r.minY, width: r.width, height: 18 - r.minY)), with: .color(awn.color))
        var sc = Path()
        var ax = (r.minX / 56).rounded(.down) * 56
        while ax < r.maxX {
            sc.addEllipse(in: CGRect(x: ax, y: -10, width: 56, height: 52))
            ax += 56
        }
        g.fill(sc, with: .color(awn.color))
        var ax2 = (r.minX / 112).rounded(.down) * 112
        while ax2 < r.maxX {
            g.fill(Path(ellipseIn: CGRect(x: ax2 + 4, y: -6, width: 48, height: 42)), with: .color(ICColor(0xFFFFFF).color(0.85)))
            ax2 += 112
        }
        // the serving window: sky, a street and a tree outside
        let w = ICGeo.window
        var out = g
        let hole = Path(roundedRect: w, cornerRadius: 26)
        out.clip(to: hole)
        out.fill(Path(w), with: .linearGradient(Gradient(colors: [ICColor(0x8FD3FF).color, ICColor(0xDDF3FF).color]),
                                                startPoint: CGPoint(x: 0, y: w.minY), endPoint: CGPoint(x: 0, y: w.maxY)))
        cloud(out, CGPoint(x: w.minX + 70, y: w.minY + 60), 1)
        cloud(out, CGPoint(x: w.maxX - 50, y: w.minY + 110), 0.7)
        out.fill(Path(CGRect(x: w.minX, y: w.minY + 230, width: w.width, height: 200)), with: .color(ICColor(0xA8E07A).color))
        out.fill(Path(CGRect(x: w.minX, y: w.minY + 262, width: w.width, height: 200)), with: .color(ICColor(0xD8CFC4).color))
        let trunk = Path(roundedRect: CGRect(x: w.minX + 200, y: w.minY + 140, width: 16, height: 100), cornerRadius: 6)
        out.fill(trunk, with: .color(ICColor(0x9A6A43).color))
        out.fill(Path(ellipseIn: CGRect(x: w.minX + 160, y: w.minY + 70, width: 96, height: 96)), with: .color(ICColor(0x6CCB6B).color))
        out.fill(Path(ellipseIn: CGRect(x: w.minX + 176, y: w.minY + 82, width: 40, height: 30)), with: .color(ICColor(0x9BE07F).color))
        // window frame
        g.stroke(hole, with: .color(ICColor(0xFFFFFF).color), lineWidth: 16)
        g.stroke(hole.offsetBy(dx: 0, dy: 0), with: .color((station == .bingsu ? ICColor(0xA8D6F0) : ICColor(0xF3B6CC)).color), lineWidth: 4)
        // shelves for the fruit bins
        if station == .smoothie {
            for y in [CGFloat(364), 484] {
                let shelf = Path(roundedRect: CGRect(x: 254, y: y, width: 276, height: 14), cornerRadius: 5)
                g.fill(shelf, with: .color(ICColor(0xD9A56A).color))
                g.stroke(shelf, with: .color(ICColor(0xA87440).color), lineWidth: 2.5)
                g.fill(Path(CGRect(x: 260, y: y + 14, width: 264, height: 6)), with: .color(ICColor(0x5B3A68).color(0.08)))
            }
        }
        // decorative frosty snowflake medallions on the bingsu wall
        if station == .bingsu {
            for (sx, sy, sr) in [(CGFloat(116), CGFloat(198), CGFloat(24)), (CGFloat(228), CGFloat(266), CGFloat(18)), (CGFloat(154), CGFloat(344), CGFloat(15))] {
                snowflake(g, at: CGPoint(x: sx, y: sy), radius: sr, color: ICColor(0xB4DDF6).color(0.55), width: 3)
            }
        }
        // a soft shadow line where the counter meets the wall
        g.fill(Path(CGRect(x: r.minX, y: ICGeo.counterY - 18, width: r.width, height: 18)),
               with: .linearGradient(Gradient(colors: [ICColor(0x5B3A68).color(0), ICColor(0x5B3A68).color(0.1)]),
                                     startPoint: CGPoint(x: 0, y: ICGeo.counterY - 18), endPoint: CGPoint(x: 0, y: ICGeo.counterY)))
    }

    private static func cloud(_ g: GraphicsContext, _ c: CGPoint, _ k: CGFloat) {
        var p = Path()
        p.addEllipse(in: CGRect(x: c.x - 40 * k, y: c.y - 12 * k, width: 80 * k, height: 30 * k))
        p.addEllipse(in: CGRect(x: c.x - 22 * k, y: c.y - 28 * k, width: 44 * k, height: 36 * k))
        g.fill(p, with: .color(.white.opacity(0.9)))
    }

    static func snowflake(_ g: GraphicsContext, at c: CGPoint, radius r: CGFloat, color: Color, width: CGFloat) {
        var p = Path()
        for k in 0..<6 {
            let a = CGFloat(k) * .pi / 3
            let end = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            p.move(to: c)
            p.addLine(to: end)
            let mid = CGPoint(x: c.x + cos(a) * r * 0.62, y: c.y + sin(a) * r * 0.62)
            for s in [-1.0, 1.0] {
                let ba = a + CGFloat(s) * 0.72
                p.move(to: mid)
                p.addLine(to: CGPoint(x: mid.x + cos(ba) * r * 0.3, y: mid.y + sin(ba) * r * 0.3))
            }
        }
        g.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    // MARK: The shop layer

    static func draw(_ ctx: GraphicsContext, map: ICMap, sim: IceSim) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let r = map.visible
        let t = CGFloat(sim.time)
        sill(g, station: sim.station)
        counter(g, r, sim)
        switch sim.station {
        case .scoop: cabinet(g, sim, t)
        case .soft: machine(g, sim, t)
        case .smoothie: smoothieBar(g, sim, t)
        case .bingsu: bingsuStation(g, sim, t)
        }
        stand(g, sim)
        ICArt.drawBuild(g, sim.build, at: sim.S, time: t)
        if sim.baseDrop != nil, sim.time - (sim.baseDrop?.start ?? 0) < 0.5 {
            sparkles(g, at: CGPoint(x: sim.S.x, y: sim.S.y + 30), t: CGFloat(sim.time - (sim.baseDrop?.start ?? 0)) / 0.5)
        }
        softStream(g, sim)
        served(g, sim, t)
        if sim.station == .smoothie || !sim.jarOnBase { jar(g, sim, t) }
        streams(g, sim)
        returning(g, sim, t)
        heldThing(g, sim, t)
        particles(g, sim)
        if sim.time - sim.sparkleAt < 0.6 {
            let top = sim.build.top(0) ?? 0
            sparkles(g, at: CGPoint(x: sim.S.x, y: sim.S.y - top), t: CGFloat(sim.time - sim.sparkleAt) / 0.6)
        }
    }

    private static func sill(_ g: GraphicsContext, station: ICStation) {
        let w = ICGeo.window
        let sill = Path(roundedRect: CGRect(x: w.minX - 14, y: w.maxY - 22, width: w.width + 28, height: 30), cornerRadius: 8)
        let c = station == .bingsu ? ICColor(0xCBEAFF) : ICColor(0xFFD3E2)
        g.fill(sill, with: .color(c.color))
        g.stroke(sill, with: .color(ICArt.outline(c)), lineWidth: 2.5)
        let wallFill = station == .bingsu ? ICColor(0xF2F9FF) : ICColor(0xFFF4EC)
        g.fill(Path(CGRect(x: w.minX - 8, y: w.maxY + 8, width: w.width + 16, height: ICGeo.counterY - w.maxY - 8)),
               with: .color(wallFill.color))
        g.fill(Path(CGRect(x: w.minX - 8, y: w.maxY + 8, width: w.width + 16, height: 10)), with: .color(ICColor(0x5B3A68).color(0.08)))
    }

    private static func counter(_ g: GraphicsContext, _ r: CGRect, _ sim: IceSim) {
        let y = ICGeo.counterY
        let top = ICColor(0xFFFFFF)
        g.fill(Path(CGRect(x: r.minX, y: y, width: r.width, height: 26)),
               with: .linearGradient(Gradient(colors: [top.color, ICColor(0xEEE6EF).color]),
                                     startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: 0, y: y + 26)))
        // marble veins
        var vein = Path()
        for k in 0..<8 {
            let x0 = r.minX + CGFloat(k) * r.width / 8
            vein.move(to: CGPoint(x: x0, y: y + 6 + icRand(k, 1) * 10))
            vein.addQuadCurve(to: CGPoint(x: x0 + 110, y: y + 4 + icRand(k, 2) * 16), control: CGPoint(x: x0 + 55, y: y + icRand(k, 3) * 24))
        }
        g.stroke(vein, with: .color(ICColor(0xD9CFE0).color(0.6)), lineWidth: 1.4)
        // the front: mint panels
        let front = CGRect(x: r.minX, y: y + 26, width: r.width, height: r.maxY - y - 26)
        g.fill(Path(front), with: .color(ICColor(0x9FE3CF).color))
        var px = (r.minX / 120).rounded(.down) * 120
        while px < r.maxX {
            let panel = Path(roundedRect: CGRect(x: px + 12, y: y + 40, width: 96, height: r.maxY - y - 56), cornerRadius: 14)
            g.stroke(panel, with: .color(ICColor(0x7CCDB6).color), lineWidth: 4)
            px += 120
        }
        g.fill(Path(CGRect(x: r.minX, y: y + 26, width: r.width, height: 8)), with: .color(ICColor(0x5B3A68).color(0.12)))
        // spills and fallen sprinkles on the counter
        for s in sim.spills {
            let a = Double(1 - icClamp((s.age - 10) / 6))
            let p = Path(ellipseIn: CGRect(x: s.x - s.w / 2, y: y + 3, width: s.w, height: min(14, s.w * 0.2 + 4)))
            g.fill(p, with: .color(s.color.color(0.9 * a)))
            g.fill(Path(ellipseIn: CGRect(x: s.x - s.w * 0.25, y: y + 5, width: s.w * 0.22, height: 3)), with: .color(.white.opacity(0.5 * a)))
        }
        for k in sim.counterBits {
            ICArt.sprinkle(g, CGPoint(x: k.dx, y: min(y + 22, k.dy)), rot: k.rot, color: ICPalette.candy[k.color % ICPalette.candy.count])
        }
    }

    // MARK: Scoop cabinet

    private static func cabinet(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        let box = Path(roundedRect: CGRect(x: 24, y: 378, width: 432, height: ICGeo.counterY - 378 + 6), cornerRadius: 22)
        let body = ICColor(0xFFFFFF)
        g.fill(box, with: .color(body.color))
        g.stroke(box, with: .color(ICColor(0xC9D3DE).color), lineWidth: 4)
        // the cold well inside
        let well = Path(roundedRect: CGRect(x: 38, y: 392, width: 404, height: 196), cornerRadius: 16)
        g.fill(well, with: .linearGradient(Gradient(colors: [ICColor(0xDCEAF4).color, ICColor(0xBFD3E2).color]),
                                           startPoint: CGPoint(x: 0, y: 392), endPoint: CGPoint(x: 0, y: 588)))
        for (i, c) in ICGeo.tubs.enumerated() {
            tub(g, sim.tubs[i], c, wanted: sim.wanted(flavor: sim.tubs[i].flavor), t: t)
        }
        // front panel with a frosty pink stripe
        let front = Path(roundedRect: CGRect(x: 24, y: 590, width: 432, height: ICGeo.counterY - 590 + 6), cornerRadius: 10)
        g.fill(front, with: .color(ICColor(0xFFFFFF).color))
        g.fill(Path(CGRect(x: 24, y: 606, width: 432, height: 16)), with: .color(ICColor(0xFF8FB8).color))
        for k in 0..<6 {
            let x = 52 + CGFloat(k) * 74
            g.fill(Path(ellipseIn: CGRect(x: x, y: 632, width: 30, height: 14)), with: .color(ICColor(0xDDEFFA).color))
        }
        // the glass sneeze guard: see-through with streaks of light
        var glass = Path()
        glass.move(to: CGPoint(x: 30, y: 588))
        glass.addLine(to: CGPoint(x: 450, y: 588))
        glass.addLine(to: CGPoint(x: 438, y: 520))
        glass.addLine(to: CGPoint(x: 42, y: 520))
        glass.closeSubpath()
        g.fill(glass, with: .color(ICColor(0xDDF3FF).color(0.18)))
        var streak = Path()
        streak.move(to: CGPoint(x: 90, y: 586))
        streak.addLine(to: CGPoint(x: 120, y: 522))
        streak.move(to: CGPoint(x: 124, y: 586))
        streak.addLine(to: CGPoint(x: 140, y: 550))
        g.stroke(streak, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        g.stroke(Path(CGRect(x: 42, y: 520, width: 396, height: 0.1)), with: .color(ICColor(0xB7C6D6).color), lineWidth: 3)
        // the dipping well: running water keeps the dipper clean
        let w = ICGeo.well
        let basin = Path(roundedRect: CGRect(x: w.x - 30, y: w.y - 14, width: 60, height: 62), cornerRadius: 12)
        g.fill(basin, with: .linearGradient(Gradient(colors: [ICColor(0xE2EAF1).color, ICColor(0xB7C6D6).color]),
                                            startPoint: CGPoint(x: w.x - 30, y: 0), endPoint: CGPoint(x: w.x + 30, y: 0)))
        g.stroke(basin, with: .color(ICColor(0x93A5B8).color), lineWidth: 3)
        let water = Path(ellipseIn: CGRect(x: w.x - 24, y: w.y - 10, width: 48, height: 12))
        g.fill(water, with: .color(ICColor(0x9CD7FF).color(0.85)))
        let ripple = 3 + sin(t * 6) * 1.5
        g.stroke(Path(ellipseIn: CGRect(x: w.x - 6 - ripple * 2, y: w.y - 6 - ripple * 0.4, width: 12 + ripple * 4, height: 4 + ripple * 0.8)),
                 with: .color(.white.opacity(0.6)), lineWidth: 1.2)
        var tap = Path()
        tap.move(to: CGPoint(x: w.x + 20, y: w.y - 40))
        tap.addQuadCurve(to: CGPoint(x: w.x + 4, y: w.y - 28), control: CGPoint(x: w.x + 20, y: w.y - 30))
        g.stroke(tap, with: .color(ICColor(0xA4B3C4).color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        g.stroke(Path(CGRect(x: w.x + 3, y: w.y - 26, width: 0.1, height: 18)), with: .color(ICColor(0xBFE6FF).color(0.8)), lineWidth: 2)
        if sim.held != .scoop && !sim.returning.contains(where: { $0.held == .scoop }) {
            var d = g
            d.translateBy(x: w.x - 2, y: w.y - 44)
            d.rotate(by: .radians(0.35))
            d.scaleBy(x: 0.75, y: 0.75)
            ICArt.dipper(d, ball: sim.ball, flavor: sim.ballFlavor, swirl: sim.ballSwirl, time: t)
        }
        // cold mist drifting up
        for k in 0..<5 {
            let ph = (t * 0.25 + CGFloat(k) * 0.2).truncatingRemainder(dividingBy: 1)
            let x = 80 + CGFloat(k) * 76 + sin(t + CGFloat(k)) * 8
            let y = 520 - ph * 120
            g.fill(Path(ellipseIn: CGRect(x: x - 24, y: y - 8, width: 48, height: 16)), with: .color(.white.opacity(Double(0.22 * sin(ph * .pi)))))
        }
    }

    private static func tub(_ g: GraphicsContext, _ tub: ICTub, _ c: CGPoint, wanted: Bool, t: CGFloat) {
        let rx = ICGeo.tubRX, ry = ICGeo.tubRY
        let steel = ICColor(0xC9D3DE)
        // the tub's side, going down into the cabinet
        let side = Path(CGRect(x: c.x - rx - 4, y: c.y, width: rx * 2 + 8, height: 56))
        g.fill(side, with: .linearGradient(Gradient(colors: [steel.shade(0.25).color, steel.color, steel.shade(-0.25).color]),
                                           startPoint: CGPoint(x: c.x - rx, y: 0), endPoint: CGPoint(x: c.x + rx, y: 0)))
        let rim = ICArt.ellipse(c, rx + 4, ry + 4)
        g.fill(rim, with: .color(steel.shade(-0.3).color))
        // the ice cream, lower as it's used
        let lv = (1 - tub.level) * 16
        let sc = CGPoint(x: c.x, y: c.y + lv)
        var inside = g
        inside.clip(to: ICArt.ellipse(c, rx, ry))
        let col = tub.flavor.color
        var surf = Path()
        let n = 28
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let lump = 1 + 0.05 * sin(a * 6 + CGFloat(tub.flavor.rawValue))
            let p = CGPoint(x: sc.x + cos(a) * rx * lump, y: sc.y + sin(a) * ry * lump + (sin(a) < 0 ? 0 : 2))
            if i == 0 { surf.move(to: p) } else { surf.addLine(to: p) }
        }
        surf.closeSubpath()
        inside.fill(Path(CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)), with: .color(steel.shade(-0.15).color))
        inside.fill(surf, with: .radialGradient(Gradient(colors: [col.shade(0.35).color, col.color, col.shade(-0.18).color]),
                                                center: CGPoint(x: sc.x - 16, y: sc.y - 6), startRadius: 0, endRadius: rx * 1.2))
        // grooves the dipper dug
        for m in tub.marks where m.count > 1 {
            var p = Path()
            p.move(to: CGPoint(x: c.x + m[0].x, y: c.y + m[0].y * 0.5 + lv))
            for q in m.dropFirst() { p.addLine(to: CGPoint(x: c.x + q.x, y: c.y + q.y * 0.5 + lv)) }
            inside.stroke(p, with: .color(col.shade(-0.22).color(0.7)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            inside.stroke(p.offsetBy(dx: 0, dy: -3), with: .color(col.shade(0.45).color(0.7)),
                          style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        if let bits = tub.flavor.bits {
            for k in 0..<10 {
                let p = CGPoint(x: c.x + (icRand(k, tub.flavor.rawValue) - 0.5) * rx * 1.6, y: sc.y + (icRand(k + 20, tub.flavor.rawValue) - 0.5) * ry * 1.4)
                inside.fill(ICArt.circle(p, tub.flavor == .vanilla ? 0.9 : 2.2), with: .color(bits.color(0.8)))
            }
        }
        g.stroke(rim, with: .color(steel.shade(-0.45).color), lineWidth: 2.5)
        g.stroke(ICArt.ellipse(CGPoint(x: c.x, y: c.y - 1.5), rx + 2, ry + 2), with: .color(.white.opacity(0.7)), lineWidth: 1.5)
        if wanted { heart(g, at: CGPoint(x: c.x + rx - 2, y: c.y - ry - 8), t: t) }
    }

    /// The little heart badge that marks what the customer wants.
    static func heart(_ g: GraphicsContext, at p: CGPoint, t: CGFloat, size: CGFloat = 13) {
        let k = size * (1 + 0.08 * sin(t * 5))
        var h = Path()
        h.move(to: CGPoint(x: p.x, y: p.y + k))
        h.addCurve(to: CGPoint(x: p.x, y: p.y - k * 0.45), control1: CGPoint(x: p.x - k * 1.5, y: p.y), control2: CGPoint(x: p.x - k * 0.8, y: p.y - k * 1.3))
        h.addCurve(to: CGPoint(x: p.x, y: p.y + k), control1: CGPoint(x: p.x + k * 0.8, y: p.y - k * 1.3), control2: CGPoint(x: p.x + k * 1.5, y: p.y))
        g.fill(ICArt.circle(p, k * 1.45), with: .color(.white))
        g.fill(h, with: .color(Theme.pink))
    }

    // MARK: Soft-serve machine

    private static func machine(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        let steel = ICColor(0xD5DEE7)
        let cream = ICColor(0xFFF7F4)
        // Wide pastel parlor dispenser: four big pull-down lever handles on the left, dispensing head & star nozzle at x = 600.
        let body = Path(roundedRect: CGRect(x: 96, y: 106, width: 604, height: 174), cornerRadius: 32)
        g.fill(body, with: .linearGradient(Gradient(colors: [cream.color, steel.shade(0.32).color, steel.color]),
                                           startPoint: CGPoint(x: 96, y: 106), endPoint: CGPoint(x: 700, y: 280)))
        g.stroke(body, with: .color(ICArt.outline(steel)), lineWidth: 3.5)

        // Pastel pink top crown with three hopper lids
        let top = Path(roundedRect: CGRect(x: 108, y: 112, width: 580, height: 38), cornerRadius: 18)
        g.fill(top, with: .color(ICColor(0xFF9EC4).color))
        for x in [CGFloat(190), 340, 490] {
            let lid = Path(ellipseIn: CGRect(x: x - 44, y: 118, width: 88, height: 24))
            g.fill(lid, with: .color(ICColor(0xFFE3EE).color))
            g.stroke(lid, with: .color(ICColor(0xE07AA4).color), lineWidth: 2.5)
        }

        // Decorative soft-serve cone emblem above the dispensing head
        var cone = Path()
        cone.move(to: CGPoint(x: 588, y: 184))
        cone.addLine(to: CGPoint(x: 612, y: 184))
        cone.addLine(to: CGPoint(x: 600, y: 214))
        cone.closeSubpath()
        g.fill(cone, with: .color(ICColor(0xDDA25C).color))
        g.fill(Path(ellipseIn: CGRect(x: 584, y: 162, width: 32, height: 24)), with: .color(ICColor(0xFFB3C9).color))

        // Dispensing head and star-ridged nozzle
        let head = Path(roundedRect: CGRect(x: 540, y: 226, width: 120, height: 48), cornerRadius: 14)
        g.fill(head, with: .color(steel.shade(-0.06).color))
        g.stroke(head, with: .color(ICArt.outline(steel)), lineWidth: 2.5)
        let n = ICGeo.nozzle
        var star = Path()
        for k in 0..<12 {
            let a = CGFloat(k) / 12 * 2 * .pi
            let rr: CGFloat = k % 2 == 0 ? 16 : 11
            let p = CGPoint(x: n.x + cos(a) * rr, y: n.y - 8 + sin(a) * rr * 0.32)
            if k == 0 { star.move(to: p) } else { star.addLine(to: p) }
        }
        star.closeSubpath()
        let spout = Path(roundedRect: CGRect(x: n.x - 15, y: 268, width: 30, height: n.y - 272), cornerRadius: 5)
        g.fill(spout, with: .color(steel.shade(-0.12).color))
        g.stroke(spout, with: .color(ICArt.outline(steel)), lineWidth: 2)
        g.fill(star, with: .color(steel.shade(-0.3).color))

        // Four big pull-down pastel lever handles: tap for a smooth 0.9s swirl burst or hold continuously.
        for (i, c) in ICGeo.softButtons.enumerated() {
            let press = sim.leverPull[i]
            let f = ICSoft(rawValue: i) ?? .vanilla
            let (a, b) = f.colors

            let slot = Path(roundedRect: CGRect(x: c.x - 12, y: 162, width: 24, height: 96), cornerRadius: 12)
            g.fill(slot, with: .color(steel.shade(-0.26).color))
            g.stroke(slot, with: .color(ICArt.outline(steel)), lineWidth: 2.2)

            let handleCenterY = c.y - 4 + press * 30
            if press > 0.05 {
                let glow = Path(roundedRect: CGRect(x: c.x - 42, y: handleCenterY - 42, width: 84, height: 84), cornerRadius: 28)
                g.stroke(glow, with: .color(Theme.lemon.opacity(Double(press) * 0.9)), lineWidth: 5)
            }

            var arm = Path()
            arm.move(to: CGPoint(x: c.x, y: 176))
            arm.addLine(to: CGPoint(x: c.x, y: handleCenterY - 22))
            g.stroke(arm, with: .color(ICArt.outline(steel)), style: StrokeStyle(lineWidth: 15, lineCap: .round))
            g.stroke(arm, with: .color(steel.shade(0.25).color), style: StrokeStyle(lineWidth: 9, lineCap: .round))

            var hg = g
            hg.translateBy(x: c.x, y: handleCenterY)
            let scale: CGFloat = 1 + 0.05 * press
            hg.scaleBy(x: scale, y: scale)
            let grip = Path(roundedRect: CGRect(x: -34, y: -34, width: 68, height: 68), cornerRadius: 24)
            hg.fill(grip.offsetBy(dx: 0, dy: 4), with: .color(Theme.ink.opacity(0.16)))
            hg.fill(grip, with: .color(a.color))
            if a != b {
                var clipped = hg
                clipped.clip(to: grip)
                var half = Path()
                half.move(to: CGPoint(x: 4, y: -38))
                half.addLine(to: CGPoint(x: 38, y: -38))
                half.addLine(to: CGPoint(x: 38, y: 38))
                half.addLine(to: CGPoint(x: -6, y: 38))
                half.closeSubpath()
                clipped.fill(half, with: .color(b.color))
            }
            hg.stroke(grip, with: .color(.white.opacity(0.9)), lineWidth: 5.5)
            hg.stroke(grip, with: .color(ICArt.outline(a.mix(b, 0.5))), lineWidth: 3)

            hg.fill(ICArt.ellipse(CGPoint(x: -12, y: -18), 12, 6), with: .color(.white.opacity(0.65)))
            var chev = Path()
            chev.move(to: CGPoint(x: -10, y: 10))
            chev.addLine(to: CGPoint(x: 0, y: 19))
            chev.addLine(to: CGPoint(x: 10, y: 10))
            hg.stroke(chev, with: .color(ICArt.outline(a.mix(b, 0.5)).opacity(0.55)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

            if sim.wanted(soft: f) {
                heart(g, at: CGPoint(x: c.x + 28, y: handleCenterY - 28), t: t, size: 13)
            }
        }
    }

    // MARK: Korean Bingsu Snow Shaver Station

    private static func bingsuStation(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        let sky = ICColor(0xA6D9F7)
        let mint = ICColor(0xA8E8D6)
        let edge = ICArt.outline(sky)

        // Left counter chilled milk-ice tray & stacked spare celadon bowls
        let tray = Path(roundedRect: CGRect(x: 56, y: 632, width: 266, height: 30), cornerRadius: 12)
        g.fill(tray, with: .linearGradient(Gradient(colors: [ICColor(0xF6D9B2).color, ICColor(0xDFB57E).color]),
                                           startPoint: CGPoint(x: 56, y: 632), endPoint: CGPoint(x: 56, y: 662)))
        g.stroke(tray, with: .color(ICArt.outline(ICColor(0xDFB57E))), lineWidth: 2.5)
        // Frosted milk-ice blocks sitting on the tray
        for (bx, by, bw, bh) in [(CGFloat(84), CGFloat(574), CGFloat(64), CGFloat(58)), (CGFloat(154), CGFloat(592), CGFloat(54), CGFloat(40))] {
            let block = Path(roundedRect: CGRect(x: bx, y: by, width: bw, height: bh), cornerRadius: 12)
            g.fill(block, with: .linearGradient(Gradient(colors: [.white, ICColor(0xEAF6FF).color, ICColor(0xCBE7FA).color]),
                                                startPoint: CGPoint(x: bx, y: by), endPoint: CGPoint(x: bx + bw, y: by + bh)))
            g.stroke(block, with: .color(ICColor(0x9BC8E4).color), lineWidth: 2.4)
            g.fill(Path(roundedRect: CGRect(x: bx + 8, y: by + 8, width: bw * 0.28, height: bh * 0.45), cornerRadius: 4),
                   with: .color(.white.opacity(0.7)))
        }
        // Two nested pastel celadon bowls on the right side of the wooden tray
        for k in 0..<2 {
            let cy = CGFloat(612 - k * 14)
            var spare = Path()
            spare.move(to: CGPoint(x: 228, y: cy))
            spare.addLine(to: CGPoint(x: 304, y: cy))
            spare.addCurve(to: CGPoint(x: 228, y: cy), control1: CGPoint(x: 296, y: cy + 32), control2: CGPoint(x: 236, y: cy + 32))
            spare.closeSubpath()
            g.fill(spare, with: .color(mint.shade(k == 1 ? 0.1 : -0.05).color))
            g.stroke(spare, with: .color(ICArt.outline(mint)), lineWidth: 2.2)
        }
        // Drifting cold mist off the milk-ice blocks
        for k in 0..<4 {
            let ph = (t * 0.26 + CGFloat(k) * 0.25).truncatingRemainder(dividingBy: 1)
            let mx = 96 + CGFloat(k) * 34 + sin(t + CGFloat(k)) * 7
            let my = 576 - ph * 80
            g.fill(ICArt.ellipse(CGPoint(x: mx, y: my), 20, 7), with: .color(.white.opacity(Double(0.26 * sin(ph * .pi)))))
        }

        // Retro pastel Korean snow-ice shaver above the stand
        let body = Path(roundedRect: CGRect(x: 364, y: 102, width: 336, height: 176), cornerRadius: 34)
        g.fill(body, with: .linearGradient(
            Gradient(colors: [sky.shade(0.35).color, sky.color, sky.shade(-0.12).color]),
            startPoint: CGPoint(x: 364, y: 102),
            endPoint: CGPoint(x: 700, y: 278)
        ))
        g.stroke(body, with: .color(edge), lineWidth: 3.5)

        // Creamy mint top crown cap
        let crown = Path(roundedRect: CGRect(x: 382, y: 94, width: 300, height: 32), cornerRadius: 16)
        g.fill(crown, with: .color(ICColor(0xFFF9F4).color))
        g.stroke(crown, with: .color(edge), lineWidth: 2.8)
        g.fill(Path(roundedRect: CGRect(x: 400, y: 102, width: 264, height: 10), cornerRadius: 5), with: .color(mint.color))

        // Translucent frosted ice cylinder chamber on the right side (over x = 600)
        let ch = ICGeo.snowChamber
        let chamber = Path(roundedRect: ch, cornerRadius: 20)
        g.fill(chamber, with: .linearGradient(
            Gradient(colors: [ICColor(0xEEF8FF).color(0.92), ICColor(0xD4ECFC).color(0.85)]),
            startPoint: CGPoint(x: ch.minX, y: ch.minY),
            endPoint: CGPoint(x: ch.maxX, y: ch.maxY)
        ))
        // Frozen milk-ice block inside chamber (lowers gently as snow is shaved)
        let iceFrac = max(0.24, 1 - sim.build.snowLevel * 0.62)
        let iceH = (ch.height - 44) * iceFrac
        let iceRect = CGRect(x: ch.minX + 18, y: ch.maxY - 24 - iceH, width: ch.width - 36, height: iceH)
        let icePath = Path(roundedRect: iceRect, cornerRadius: 12)
        g.fill(icePath, with: .linearGradient(
            Gradient(colors: [.white, ICColor(0xF6FBFF).color, ICColor(0xDDF0FD).color]),
            startPoint: CGPoint(x: iceRect.minX, y: iceRect.minY),
            endPoint: CGPoint(x: iceRect.maxX, y: iceRect.maxY)
        ))
        g.stroke(icePath, with: .color(ICColor(0xB4D6EC).color), lineWidth: 2)
        // Piston press bar resting on top of the milk-ice block
        let piston = Path(roundedRect: CGRect(x: ch.minX + 26, y: iceRect.minY - 12, width: ch.width - 52, height: 12), cornerRadius: 5)
        g.fill(piston, with: .color(ICColor(0xC9D8E6).color))
        g.stroke(piston, with: .color(ICArt.outline(ICColor(0xC9D8E6))), lineWidth: 2)
        // Spinning shaver blade bar at the bottom of the chamber
        let bladeY = ch.maxY - 14
        let bladeW = 28 + abs(cos(sim.shaveBladeAngle)) * 18
        let blade = Path(roundedRect: CGRect(x: ch.midX - bladeW, y: bladeY - 4, width: bladeW * 2, height: 8), cornerRadius: 4)
        g.fill(blade, with: .color(ICColor(0x98ACC0).color))
        // Chamber glass shine + outline
        var shine = Path()
        shine.move(to: CGPoint(x: ch.minX + 12, y: ch.minY + 18))
        shine.addLine(to: CGPoint(x: ch.minX + 12, y: ch.maxY - 22))
        g.stroke(shine, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        g.stroke(chamber, with: .color(ICColor(0x88BCDD).color), lineWidth: 3)

        // Snow chute nozzle right above the bowl
        let n = ICGeo.snowNozzle
        var chute = Path()
        chute.move(to: CGPoint(x: n.x - 36, y: 274))
        chute.addLine(to: CGPoint(x: n.x + 36, y: 274))
        chute.addLine(to: CGPoint(x: n.x + 26, y: n.y))
        chute.addLine(to: CGPoint(x: n.x - 26, y: n.y))
        chute.closeSubpath()
        g.fill(chute, with: .linearGradient(Gradient(colors: [ICColor(0xFFFDFB).color, ICColor(0xDCEAF6).color]),
                                            startPoint: CGPoint(x: n.x - 30, y: 274), endPoint: CGPoint(x: n.x + 30, y: n.y)))
        g.stroke(chute, with: .color(edge), lineWidth: 2.6)

        // Falling feathery milk-snow ribbon curtain while shaving
        if sim.isShavingSnow {
            let bowlTop = sim.S.y - (sim.build.top(0) ?? 0)
            let span = max(20, bowlTop - n.y)
            for k in -2...2 {
                let x0 = n.x + CGFloat(k) * 8
                let sway = sin(t * 14 + CGFloat(k) * 1.4) * 5
                var strand = Path()
                strand.move(to: CGPoint(x: x0, y: n.y))
                strand.addQuadCurve(
                    to: CGPoint(x: x0 + sway * 1.6, y: n.y + span),
                    control: CGPoint(x: x0 - sway, y: n.y + span * 0.52)
                )
                g.stroke(strand, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 7 - abs(CGFloat(k)), lineCap: .round))
            }
        }

        // Big tactile snowflake press button on the left face
        let bt = ICGeo.snowButton
        let r = ICGeo.snowButtonR
        let press = sim.shavePress
        if sim.build.snowLevel < 0.4 {
            let pulse = r + 10 + sin(t * 5.2) * 4.5
            g.stroke(ICArt.circle(bt, pulse), with: .color(Theme.lemon.opacity(0.8)), lineWidth: 5)
        }
        g.fill(ICArt.circle(bt, r + 8), with: .color(.white.opacity(0.92)))
        g.stroke(ICArt.circle(bt, r + 8), with: .color(edge), lineWidth: 2.6)

        var bg = g
        bg.translateBy(x: bt.x, y: bt.y + 5 * press)
        bg.scaleBy(x: 1 - 0.07 * press, y: 1 - 0.07 * press)
        let btnCol = ICColor(0x7AC8F5).mix(ICColor(0x9BE4D0), press)
        let knob = ICArt.circle(.zero, r)
        bg.fill(knob, with: .radialGradient(
            Gradient(colors: [btnCol.shade(0.32).color, btnCol.color, btnCol.shade(-0.14).color]),
            center: CGPoint(x: -r * 0.3, y: -r * 0.35),
            startRadius: 2,
            endRadius: r * 1.3
        ))
        bg.stroke(knob, with: .color(ICArt.outline(btnCol)), lineWidth: 3)
        var snowIcon = bg
        snowIcon.rotate(by: .radians(Double(sim.shaveBladeAngle * 0.12)))
        snowflake(snowIcon, at: .zero, radius: r * 0.56, color: .white, width: 4.5)

        if sim.order?.kind == .bingsu && sim.build.snowLevel < 0.4 {
            heart(g, at: CGPoint(x: bt.x + r * 0.85, y: bt.y - r * 0.8), t: t, size: 12)
        }
    }

    private static func softStream(_ g: GraphicsContext, _ sim: IceSim) {
        guard !sim.free.isEmpty else { return }
        var pts: [(p: CGPoint, f: Bool, r: CGFloat, c: Int)] = []
        let attached = sim.lever != nil && !sim.softFull
        if attached { pts.append((CGPoint(x: ICGeo.nozzle.x, y: ICGeo.nozzle.y), true, IceSim.ropeR, sim.free.last?.flavor ?? 0)) }
        for b in sim.free.reversed() {
            pts.append((b.p, true, IceSim.ropeR * 0.95, b.flavor))
        }
        // color by flavor (the twist shows both)
        let f = ICSoft(rawValue: pts.first?.c ?? 0) ?? .vanilla
        var path = Path()
        path.move(to: pts[0].p)
        for q in pts.dropFirst() { path.addLine(to: q.p) }
        if pts.count == 1 { path.addLine(to: CGPoint(x: pts[0].p.x, y: pts[0].p.y + 1)) }
        ICArt.tube(g, path, r: IceSim.ropeR * 0.92, col: f.colors.0, dim: false)
        if f == .twist {
            g.stroke(path, with: .color(f.colors.1.color), style: StrokeStyle(lineWidth: IceSim.ropeR * 0.9, lineCap: .butt, dash: [7, 9]))
        }
    }

    // MARK: Stand

    private static func stand(_ g: GraphicsContext, _ sim: IceSim) {
        let S = sim.S
        let base = sim.build.base ?? (sim.station == .bingsu ? .bowl : .waffle)
        let steel = ICColor(0xC9D3DE)
        let counterY = ICGeo.counterY
        let ringY = base.isCone ? S.y + 66 : S.y + base.depth
        let plate = Path(ellipseIn: CGRect(x: S.x - 46, y: counterY - 6, width: 92, height: 16))
        if ringY < counterY - 6 {
            let post = Path(roundedRect: CGRect(x: S.x - 7, y: ringY, width: 14, height: counterY - ringY), cornerRadius: 5)
            g.fill(post, with: .linearGradient(Gradient(colors: [steel.shade(0.4).color, steel.shade(-0.2).color]),
                                               startPoint: CGPoint(x: S.x - 7, y: 0), endPoint: CGPoint(x: S.x + 7, y: 0)))
            g.stroke(post, with: .color(ICArt.outline(steel)), lineWidth: 2)
        }
        g.fill(plate, with: .color(steel.color))
        g.stroke(plate, with: .color(ICArt.outline(steel)), lineWidth: 2.5)
        guard sim.build.base != nil else {
            // an empty holder waits for a cone
            let ring = Path(ellipseIn: CGRect(x: S.x - 32, y: ringY - 8, width: 64, height: 16))
            g.stroke(ring, with: .color(ICArt.outline(steel)), lineWidth: 7)
            g.stroke(ring, with: .color(steel.color), lineWidth: 4)
            return
        }
        if base.isCone {
            let ring = Path(ellipseIn: CGRect(x: S.x - 34, y: ringY - 9, width: 68, height: 18))
            g.stroke(ring, with: .color(ICArt.outline(steel)), lineWidth: 7)
            g.stroke(ring, with: .color(steel.color), lineWidth: 4)
        } else if ringY < counterY - 6 {
            let shelf = Path(ellipseIn: CGRect(x: S.x - 50, y: ringY - 6, width: 100, height: 14))
            g.fill(shelf, with: .color(steel.color))
            g.stroke(shelf, with: .color(ICArt.outline(steel)), lineWidth: 2.5)
        }
    }

    // MARK: Smoothie bar

    private static func smoothieBar(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        // fruit bins on the shelves
        for (i, c) in ICGeo.bins.enumerated() {
            let f = ICFruit.allCases[i]
            let crate = Path(roundedRect: CGRect(x: c.x - 34, y: c.y - 6, width: 68, height: 42), cornerRadius: 8)
            let wood = ICColor(0xE7B57A)
            // a heap of fruit sticking out of the top
            for k in 0..<6 {
                let px = c.x - 20 + CGFloat(k % 3) * 20
                let py = c.y - 4 - (k >= 3 ? 14 : 0)
                let r = f.radius * (f == .blueberry ? 1 : 0.8)
                ICArt.fruit(g, f, at: CGPoint(x: px, y: py), r: r, rot: icRand(k, i) * 2 - 1, seed: k + i * 10)
            }
            g.fill(crate, with: .color(wood.color))
            g.stroke(crate, with: .color(ICArt.outline(wood)), lineWidth: 2.5)
            g.stroke(Path(CGRect(x: c.x - 30, y: c.y + 14, width: 60, height: 0.1)), with: .color(wood.shade(-0.3).color), lineWidth: 2)
            if sim.wanted(fruit: f) { heart(g, at: CGPoint(x: c.x + 30, y: c.y - 24), t: t, size: 11) }
        }
        // the blender base
        let b = ICGeo.jarHome
        var base = Path()
        base.move(to: CGPoint(x: b.x - 62, y: b.y))
        base.addLine(to: CGPoint(x: b.x + 62, y: b.y))
        base.addLine(to: CGPoint(x: b.x + 72, y: ICGeo.counterY))
        base.addLine(to: CGPoint(x: b.x - 72, y: ICGeo.counterY))
        base.closeSubpath()
        let pink = ICColor(0xFF8FB8)
        g.fill(base, with: .linearGradient(Gradient(colors: [pink.shade(0.25).color, pink.color]),
                                           startPoint: CGPoint(x: 0, y: b.y), endPoint: CGPoint(x: 0, y: ICGeo.counterY)))
        g.stroke(base, with: .color(ICArt.outline(pink)), lineWidth: 3)
        let bt = ICGeo.blendButton
        let glow = sim.blending ? 1.0 : 0.0
        let readyToBlend = sim.jarOnBase && !sim.blending && (!sim.chunks.isEmpty || sim.jarVolume > 0.01) && sim.build.fill < 0.35
        let button = ICArt.circle(bt, 28)
        if sim.blendingToggle || readyToBlend {
            let pulse = 35 + sin(t * 7) * 3.8
            g.stroke(ICArt.circle(bt, pulse), with: .color(Theme.lemon.opacity(0.9)), lineWidth: 4.8)
        }
        g.fill(ICArt.circle(bt, 34), with: .color(.white.opacity(0.92)))
        g.fill(button, with: .color(ICColor(0x7EDB8C).mix(ICColor(0xFFE27A), CGFloat(glow)).color))
        g.stroke(button, with: .color(ICColor(0x3E9B54).color), lineWidth: 3)
        // a whirl on the button
        var whirl = Path()
        let wa = Double(sim.bladeAngle) * 0.4
        whirl.addArc(center: bt, radius: 13, startAngle: .radians(wa), endAngle: .radians(wa + 4.5), clockwise: false)
        g.stroke(whirl, with: .color(.white), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        if sim.held != .milk && sim.autoPour != .milk && !sim.returning.contains(where: { $0.held == .milk }) {
            var m = g
            m.translateBy(x: ICGeo.milkHome.x, y: ICGeo.milkHome.y)
            ICArt.milkJug(m)
        }
    }

    private static func jar(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        // shaking while it blends, heavier with more fruit in it
        let jitter = sim.motor * (1.2 + 2.6 * sim.chunkLoad())
        let o = CGPoint(x: sim.jarP.x + sin(t * 71) * jitter, y: sim.jarP.y + cos(t * 59) * jitter * 0.5)
        var w = g
        w.translateBy(x: o.x + IceSim.jarPivot.x, y: o.y + IceSim.jarPivot.y)
        w.rotate(by: .radians(Double(sim.jarTilt)))
        w.translateBy(x: -IceSim.jarPivot.x, y: -IceSim.jarPivot.y)
        let H = ICGeo.jarH, bw = ICGeo.jarBottomHW, tw = ICGeo.jarTopHW
        var inner = Path()
        inner.move(to: CGPoint(x: -bw, y: 0))
        inner.addLine(to: CGPoint(x: bw, y: 0))
        inner.addLine(to: CGPoint(x: tw, y: -H))
        inner.addLine(to: CGPoint(x: -tw, y: -H))
        inner.closeSubpath()
        var outer = Path()
        outer.move(to: CGPoint(x: -bw - 8, y: 10))
        outer.addLine(to: CGPoint(x: bw + 8, y: 10))
        outer.addLine(to: CGPoint(x: tw + 8, y: -H - 4))
        outer.addLine(to: CGPoint(x: -tw - 8, y: -H - 4))
        outer.closeSubpath()
        let edge = ICColor(0x9FC4DA)
        // handle on the left
        var handle = Path()
        handle.move(to: CGPoint(x: -tw - 4, y: -H + 40))
        handle.addCurve(to: CGPoint(x: -bw - 6, y: -40), control1: CGPoint(x: -tw - 62, y: -H + 50), control2: CGPoint(x: -bw - 60, y: -60))
        w.stroke(handle, with: .color(edge.color), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        w.stroke(handle, with: .color(ICColor(0xE9F6FF).color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        w.fill(outer, with: .color(ICColor(0xEAF6FF).color(0.4)))
        // blades
        let blade = sim.bladeAngle
        var bl = Path()
        for k in 0..<2 {
            let a = blade + CGFloat(k) * .pi
            bl.move(to: CGPoint(x: 0, y: -8))
            bl.addLine(to: CGPoint(x: cos(a) * 36, y: -8 + sin(a) * 6 - 6))
        }
        w.stroke(bl, with: .color(ICColor(0x93A5B8).color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        w.fill(ICArt.circle(CGPoint(x: 0, y: -8), 6), with: .color(ICColor(0x7B8DA0).color))
        // fruit and ice
        for c in sim.chunks {
            ICArt.fruit(w, c.fruit, at: c.p, r: c.r, rot: c.rot, seed: c.seed)
        }
        // the drink: level in the world, or a whirlpool while blending
        if sim.jarVolume > 0.002 {
            var lq = g
            lq.clip(to: inner.applying(jarTransform(o, sim.jarTilt)))
            let level = sim.jarLevel() + (o.y - sim.jarP.y)
            let col = sim.smoothieColor
            let alpha = 0.6 + 0.35 * Double(icClamp(sim.jarVolume * 3))
            var surf = Path()
            let span: CGFloat = 200
            let x0 = o.x - span, x1 = o.x + span
            let upright = abs(sim.jarTilt) < 0.2
            surf.move(to: CGPoint(x: x0, y: level))
            for k in 0...40 {
                let x = x0 + (x1 - x0) * CGFloat(k) / 40
                let u = (x - o.x) / tw
                var y = level + sin(x * 0.05 + t * 7) * sim.slosh * 2.5
                if upright { y += sim.motor * 34 * (u * u - 0.35) }
                surf.addLine(to: CGPoint(x: x, y: y))
            }
            surf.addLine(to: CGPoint(x: x1, y: o.y + 300))
            surf.addLine(to: CGPoint(x: x0, y: o.y + 300))
            surf.closeSubpath()
            lq.fill(surf, with: .linearGradient(Gradient(colors: [col.shade(0.15).color(alpha), col.color(alpha), col.shade(-0.12).color(alpha)]),
                                                startPoint: CGPoint(x: o.x - tw, y: 0), endPoint: CGPoint(x: o.x + tw, y: 0)))
            // foam and bubbles while it whirls
            if sim.motor > 0.1 {
                for k in 0..<10 {
                    let x = o.x - tw * 0.8 + icRand(k, 61) * tw * 1.6
                    let rise = (t * (1 + icRand(k, 62)) + icRand(k, 63)).truncatingRemainder(dividingBy: 1)
                    let y = level + 60 - rise * 70
                    lq.stroke(ICArt.circle(CGPoint(x: x, y: y), 2 + icRand(k, 64) * 3), with: .color(.white.opacity(0.6 * Double(sim.motor))), lineWidth: 1.4)
                }
            }
        }
        // glass front
        var hl = Path()
        hl.move(to: CGPoint(x: -tw + 16, y: -H + 20))
        hl.addLine(to: CGPoint(x: -bw + 14, y: -20))
        w.stroke(hl, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        for k in 1...4 {
            let y = -CGFloat(k) * 54
            w.stroke(Path(CGRect(x: ICGeo.jarHW(y) - 18, y: y, width: 12, height: 0.1)), with: .color(edge.color(0.8)), lineWidth: 2)
        }
        w.stroke(outer, with: .color(edge.color), lineWidth: 3.5)
        w.stroke(Path(ellipseIn: CGRect(x: -tw - 8, y: -H - 10, width: tw * 2 + 16, height: 12)), with: .color(edge.color(0.8)), lineWidth: 3)
    }

    static func jarTransform(_ o: CGPoint, _ a: CGFloat) -> CGAffineTransform {
        let p = IceSim.jarPivot
        return CGAffineTransform(translationX: -p.x, y: -p.y)
            .concatenating(CGAffineTransform(rotationAngle: a))
            .concatenating(CGAffineTransform(translationX: o.x + p.x, y: o.y + p.y))
    }

    private static func streams(_ g: GraphicsContext, _ sim: IceSim) {
        guard sim.stream.count > 1, sim.pourRate > 0.01 || sim.milkPour > 0 else { return }
        var p = Path()
        p.move(to: sim.stream[0])
        for q in sim.stream.dropFirst() { p.addLine(to: q) }
        let w = 6 + 8 * max(sim.pourRate, sim.milkPour * 0.6)
        let c = sim.streamColor
        g.stroke(p, with: .color(c.shade(-0.15).color), style: StrokeStyle(lineWidth: w + 2, lineCap: .round, lineJoin: .round))
        g.stroke(p, with: .color(c.color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        g.stroke(p.offsetBy(dx: -w * 0.2, dy: 0), with: .color(c.shade(0.5).color(0.6)), style: StrokeStyle(lineWidth: w * 0.25, lineCap: .round))
    }

    // MARK: Held and returning things

    private static func heldThing(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        if sim.autoPour == .milk {
            draw(g, .milk, at: sim.autoMilkPos, sim: sim, t: t, finger: nil, tilt: 0)
        }
        guard let h = sim.held else { return }
        let working: Bool
        switch h {
        case .scoop: working = sim.scoopIn != nil || (abs(sim.tip.x - sim.S.x) < 110 && sim.ball > 0.2)
        case .topping: working = abs(sim.tip.x - sim.S.x) < 120 && sim.tip.y < sim.S.y + 20
        default: working = false
        }
        var w = g
        if working { w.opacity = FingerLift.seeThrough + 0.15 }
        draw(w, h, at: sim.tip, sim: sim, t: t, finger: sim.finger, tilt: sim.tilt)
    }

    private static func returning(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        for r in sim.returning {
            let k = icEase(CGFloat((sim.time - r.start) / r.dur))
            let p = CGPoint(x: r.from.x + (r.to.x - r.from.x) * k, y: r.from.y + (r.to.y - r.from.y) * k - sin(k * .pi) * 40)
            if case .topping = r.held, k > 0.92 { continue }
            draw(g, r.held, at: p, sim: sim, t: t, finger: nil, tilt: r.tilt * (1 - k))
        }
    }

    private static func draw(_ g: GraphicsContext, _ h: ICHeld, at p: CGPoint, sim: IceSim, t: CGFloat, finger: CGPoint?, tilt: CGFloat) {
        var w = g
        w.translateBy(x: p.x, y: p.y)
        switch h {
        case .scoop:
            var a: Double = 0.35
            if let f = finger { a = FingerLift.turn(tip: .zero, center: CGPoint(x: 0, y: 70), finger: f, lifted: p) }
            w.rotate(by: .radians(a))
            ICArt.dipper(w, ball: sim.ball, flavor: sim.ballFlavor, swirl: sim.ballSwirl, time: t)
        case .topping(let tp):
            w.rotate(by: .radians(Double(tilt)))
            topping(w, tp, held: true)
        case .fruit(let f):
            w.rotate(by: .radians(Double(tilt)))
            for k in 0..<f.handful {
                ICArt.fruit(w, f, at: CGPoint(x: CGFloat(k) * 12 - CGFloat(f.handful - 1) * 6, y: CGFloat(k % 2) * 6),
                            r: f.radius * 1.15, rot: CGFloat(k), seed: k + 3)
            }
        case .milk:
            w.rotate(by: .radians(Double(sim.milkTilt)))
            ICArt.milkJug(w)
        case .jar:
            break
        }
    }

    /// A topping as it sits in the dock or in her hand.
    static func topping(_ g: GraphicsContext, _ t: ICTopping, held: Bool) {
        switch t {
        case .sprinkles: ICArt.shaker(g)
        case .chocoSauce, .berrySauce, .condensedMilk: ICArt.bottle(g, t)
        case .whip: ICArt.whipCan(g)
        case .cherry:
            var c = g
            c.scaleBy(x: 1.6, y: 1.6)
            ICArt.cherry(c, at: .zero, wob: 0)
        case .wafer: ICArt.wafer(g, at: CGPoint(x: 0, y: 40), angle: 0.15)
        case .straw: ICArt.straw(g, at: CGPoint(x: 0, y: 70), angle: 0.1, length: 140)
        case .redBean, .mangoCubes, .strawberries, .injeolmi:
            var c = g
            let sc: CGFloat = held ? 1.25 : 1.05
            c.scaleBy(x: sc, y: sc)
            ICArt.bingsuCluster(c, t)
        }
    }

    // MARK: Served

    private static func served(_ g: GraphicsContext, _ sim: IceSim, _ t: CGFloat) {
        guard let s = sim.served, let p = sim.servedPoint() else { return }
        var l = g
        let k: CGFloat = 0.72
        l.translateBy(x: p.x, y: p.y)
        l.scaleBy(x: k, y: k)
        l.drawLayer { layer in
            ICArt.drawBuild(layer, s.build, at: .zero, time: t)
            layer.blendMode = .destinationOut
            let top = s.build.top(0) ?? 0
            for b in 0..<sim.bites {
                let bx = CGFloat(b % 2 == 0 ? 24 : -20) + CGFloat(b) * 4
                let by = -top + CGFloat(b) * 30 - 6
                var bite = Path()
                for n in 0..<3 {
                    bite.addEllipse(in: CGRect(x: bx - 30 + CGFloat(n) * 18, y: by - 22 + CGFloat(n % 2) * 8, width: 34, height: 34))
                }
                layer.fill(bite, with: .color(.black))
            }
        }
    }

    // MARK: Particles

    private static func particles(_ g: GraphicsContext, _ sim: IceSim) {
        for q in sim.parts {
            let fade = Double(1 - icClamp((q.age - q.life * 0.7) / (q.life * 0.3)))
            switch q.kind {
            case .sprinkle:
                ICArt.sprinkle(g, q.p, rot: q.rot, color: q.color)
            case .sauce:
                g.fill(ICArt.ellipse(q.p, q.size * 0.8, q.size * 1.3), with: .color(q.color.color))
            case .snow:
                g.fill(ICArt.circle(q.p, q.size * 1.2), with: .color(ICColor(0xD8EEFF).color(0.4 * fade)))
                g.fill(ICArt.circle(q.p, q.size * 0.85), with: .color(q.color.color(0.95 * fade)))
            case .steam:
                g.fill(ICArt.circle(q.p, q.size), with: .color(.white.opacity(0.3 * fade)))
            case .sparkle:
                let r = q.size
                g.fill(Twinkle().path(in: CGRect(x: q.p.x - r, y: q.p.y - r, width: r * 2, height: r * 2)), with: .color(q.color.color(fade)))
            default:
                g.fill(ICArt.circle(q.p, q.size), with: .color(q.color.color(0.95 * fade)))
            }
        }
    }

    static func sparkles(_ g: GraphicsContext, at c: CGPoint, t: CGFloat) {
        let a = Double(1 - icClamp(t))
        for k in 0..<8 {
            let ang = CGFloat(k) / 8 * 2 * .pi + 0.3
            let d = 30 + t * 70
            let r = (12 - t * 6) * (k % 2 == 0 ? 1 : 0.7)
            let p = CGPoint(x: c.x + cos(ang) * d, y: c.y + sin(ang) * d * 0.8)
            let color = k % 3 == 0 ? Theme.lemon : (k % 3 == 1 ? Theme.pink : Color.white)
            g.fill(Twinkle().path(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(a)))
        }
    }
}
