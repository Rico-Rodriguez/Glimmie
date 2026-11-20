import SwiftUI

// MARK: - Drawing the garden
//
// One Canvas draws the whole scene every frame from `GardenSim`, back to front: sky and weather, hills, fence,
// the back lawn with its decorations, the glass-fronted bed (soil, wetness, puddles, roots, the worm), plants and
// weeds, the front lawn, then everything that moves (water, clods, seeds, petals, flyers, bugs, rain), the night
// tint and the things that glow through it, and last the tool in her hand.

/// Maps the screen to the 1024 x 834 design frame the same way `DesignCanvas` does.
struct GMap {
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

enum GardenPainter {
    static func draw(_ ctx: GraphicsContext, map: GMap, sim: GardenSim) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let r = map.visible
        let t = CGFloat(sim.time)
        sky(g, r, sim, t)
        hills(g, r, sim, t)
        fence(g, r)
        backLawn(g, r, sim, t)
        for d in sim.decor where !d.held { GardenDecorPainter.draw(g, d, time: t, night: sim.night, wind: sim.windNow) }
        soil(g, sim, t)
        worm(g, sim, t)
        plants(g, sim, t)
        glassAndFrame(g)
        frontLawn(g, r, sim, t)
        particles(g, sim, front: false)
        flyers(g, sim)
        bugs(g, sim, t)
        for d in sim.decor where d.held { GardenDecorPainter.draw(g, d, time: t, night: sim.night, wind: sim.windNow) }
        basket(g, sim, t)
        particles(g, sim, front: true)
        nightAndGlow(g, r, sim, t)
        hints(g, sim, t)
        tool(g, sim, t)
    }

    // MARK: Sky

    private static func sky(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        let grey = max(sim.rain, (sim.cloud - 0.12) * 0.45)
        let top = GRGB(0x6EC1F2).mix(GRGB(0x7E8DA0), grey).mix(GRGB(0x2A3A7A), sim.night)
        let bottom = GRGB(0xD3F0FF).mix(GRGB(0xBAC6D2), grey).mix(GRGB(0x6A64A8), sim.night)
        let rect = CGRect(x: r.minX, y: r.minY, width: r.width, height: 560 - r.minY)
        g.fill(Path(rect), with: .linearGradient(Gradient(colors: [top.color, bottom.color]),
                                                 startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: 470)))
        // Sun, with slowly turning rays.
        let sunA = Double((1 - sim.rain) * (1 - sim.night) * (1 - (sim.cloud - 0.12) * 0.5))
        if sunA > 0.01 {
            let c = CGPoint(x: 846, y: 128)
            g.fill(Path(ellipseIn: CGRect(x: c.x - 170, y: c.y - 170, width: 340, height: 340)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF3B0, alpha: 0.55 * sunA), Color(hex: 0xFFF3B0, alpha: 0)]),
                                         center: c, startRadius: 30, endRadius: 170))
            var rays = Path()
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * 2 * .pi + t * 0.08
                rays.move(to: CGPoint(x: c.x + cos(a - 0.07) * 58, y: c.y + sin(a - 0.07) * 58))
                rays.addLine(to: CGPoint(x: c.x + cos(a) * 104, y: c.y + sin(a) * 104))
                rays.addLine(to: CGPoint(x: c.x + cos(a + 0.07) * 58, y: c.y + sin(a + 0.07) * 58))
                rays.closeSubpath()
            }
            g.fill(rays, with: .color(Color(hex: 0xFFE27A, alpha: 0.45 * sunA)))
            let disk = Path(ellipseIn: CGRect(x: c.x - 46, y: c.y - 46, width: 92, height: 92))
            g.fill(disk, with: .radialGradient(Gradient(colors: [Color(hex: 0xFFFBD6, alpha: sunA), Color(hex: 0xFFC93C, alpha: sunA)]),
                                               center: CGPoint(x: c.x - 12, y: c.y - 14), startRadius: 0, endRadius: 56))
        }
        // Rainbow after the rain.
        let rb = sim.rainbow
        if rb > 0.01 {
            let colors: [UInt32] = [0xFF5A5A, 0xFFA142, 0xFFE15A, 0x6ED36E, 0x5AB8FF, 0x7A7AF0, 0xB57AE8]
            for (i, hex) in colors.enumerated() {
                let rad = CGFloat(560 - i * 13)
                var arc = Path()
                arc.addArc(center: CGPoint(x: 470, y: 640), radius: rad, startAngle: .degrees(196), endAngle: .degrees(344), clockwise: false)
                g.stroke(arc, with: .color(Color(hex: hex, alpha: 0.42 * Double(rb))), lineWidth: 13)
            }
        }
        // Clouds drift with the wind; rain makes them big and grey.
        let n = 4 + Int((sim.cloud * 5).rounded())
        let span = r.width + 520
        for i in 0..<n {
            let speed = 0.6 + 0.6 * gdRand(i, 2)
            let raw = gdRand(i, 1) * span + sim.cloudDrift * speed
            let x = r.minX - 260 + raw.truncatingRemainder(dividingBy: span)
            let y = 70 + gdRand(i, 3) * 190
            let size = (0.8 + 0.6 * gdRand(i, 4)) * (1 + sim.rain * 0.5)
            let extra = i >= 4 ? Double(min(1, max(0, sim.cloud * 5 - CGFloat(i - 4)))) : 1
            cloud(g, at: CGPoint(x: x, y: y), size: size, grey: sim.rain, night: sim.night, alpha: extra)
        }
    }

    private static func cloud(_ g: GraphicsContext, at c: CGPoint, size s: CGFloat, grey: CGFloat, night: CGFloat, alpha: Double) {
        guard alpha > 0.01 else { return }
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-58, 8, 34), (-22, -14, 44), (22, -22, 50), (62, -2, 38), (0, 12, 40), (-40, 18, 28), (40, 16, 30)]
        let top = GRGB(0xFFFFFF).mix(GRGB(0x9AA5B4), grey).mix(GRGB(0x8A8CC0), night * 0.8)
        let bottom = GRGB(0xE3ECF6).mix(GRGB(0x6E7A8C), grey).mix(GRGB(0x5E5E96), night * 0.8)
        var path = Path()
        for p in puffs {
            let rr = p.2 * s
            path.addEllipse(in: CGRect(x: c.x + p.0 * s - rr, y: c.y + p.1 * s - rr, width: rr * 2, height: rr * 2))
        }
        g.fill(path, with: .linearGradient(Gradient(colors: [top.color(alpha), bottom.color(alpha)]),
                                           startPoint: CGPoint(x: c.x, y: c.y - 70 * s), endPoint: CGPoint(x: c.x, y: c.y + 40 * s)))
    }

    private static func hills(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        var far = Path()
        far.move(to: CGPoint(x: r.minX, y: 560))
        var x = r.minX
        while x <= r.maxX + 20 {
            let y = 392 + sin(x * 0.0042 + 1) * 22 + sin(x * 0.011) * 7
            far.addLine(to: CGPoint(x: x, y: y))
            x += 16
        }
        far.addLine(to: CGPoint(x: r.maxX + 20, y: 560))
        far.closeSubpath()
        g.fill(far, with: .linearGradient(Gradient(colors: [GRGB(0xB3E2A0).color, GRGB(0x96D184).color]),
                                          startPoint: CGPoint(x: 0, y: 370), endPoint: CGPoint(x: 0, y: 470)))
        // Round trees on the far hill bend in the wind.
        let trees: [CGFloat] = [96, 330, 610, 980, -150, 1200]
        for (i, tx) in trees.enumerated() {
            let base = CGPoint(x: tx, y: 400 + sin(tx * 0.0042 + 1) * 22 + sin(tx * 0.011) * 7 + 8)
            let sway = sim.windNow * 9 + sin(t * 1.3 + CGFloat(i)) * 1.5
            let trunk = CGRect(x: base.x - 5, y: base.y - 46, width: 10, height: 50)
            g.fill(Path(roundedRect: trunk, cornerRadius: 4), with: .color(GRGB(0x9A6B45).color))
            let crown = GRGB(0x6DBA5C)
            for (k, o) in [(-18.0, -52.0, 26.0), (16.0, -56.0, 28.0), (0.0, -78.0, 30.0)].enumerated() {
                let c = CGPoint(x: base.x + CGFloat(o.0) + sway * (1 + CGFloat(k) * 0.3), y: base.y + CGFloat(o.1))
                let rr = CGFloat(o.2)
                g.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                       with: .radialGradient(Gradient(colors: [crown.shade(0.18).color, crown.shade(-0.2).color]),
                                             center: CGPoint(x: c.x - rr * 0.4, y: c.y - rr * 0.4), startRadius: 0, endRadius: rr * 1.3))
            }
        }
        var near = Path()
        near.move(to: CGPoint(x: r.minX, y: 560))
        x = r.minX
        while x <= r.maxX + 20 {
            let y = 436 + sin(x * 0.006 + 2.4) * 16 + sin(x * 0.017 + 0.5) * 5
            near.addLine(to: CGPoint(x: x, y: y))
            x += 16
        }
        near.addLine(to: CGPoint(x: r.maxX + 20, y: 560))
        near.closeSubpath()
        g.fill(near, with: .linearGradient(Gradient(colors: [GRGB(0x9ED88A).color, GRGB(0x84C873).color]),
                                           startPoint: CGPoint(x: 0, y: 420), endPoint: CGPoint(x: 0, y: 500)))
    }

    private static func fence(_ g: GraphicsContext, _ r: CGRect) {
        let paint = GRGB(0xFFFBF4)
        for y in [452.0, 486.0] as [CGFloat] {
            let rail = CGRect(x: r.minX, y: y, width: r.width, height: 9)
            g.fill(Path(rail), with: .color(paint.shade(-0.1).color))
        }
        var x = (r.minX / 30).rounded(.down) * 30
        while x < r.maxX {
            var p = Path()
            p.move(to: CGPoint(x: x, y: 512))
            p.addLine(to: CGPoint(x: x, y: 438))
            p.addLine(to: CGPoint(x: x + 9, y: 426))
            p.addLine(to: CGPoint(x: x + 18, y: 438))
            p.addLine(to: CGPoint(x: x + 18, y: 512))
            p.closeSubpath()
            g.fill(p, with: .linearGradient(Gradient(colors: [paint.color, paint.shade(-0.14).color]),
                                            startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + 18, y: 0)))
            g.stroke(p, with: .color(GRGB(0xD9CBBE).color), lineWidth: 1)
            x += 30
        }
    }

    private static func backLawn(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        let rect = CGRect(x: r.minX, y: 494, width: r.width, height: 240)
        g.fill(Path(rect), with: .linearGradient(Gradient(colors: [GRGB(0x9BD772).color, GRGB(0x79C25A).color]),
                                                 startPoint: CGPoint(x: 0, y: 494), endPoint: CGPoint(x: 0, y: 560)))
        grass(g, from: r.minX, to: r.maxX, y: 500, depth: 34, count: Int(r.width / 9), sim: sim, t: t, color: GRGB(0x84C95F), salt: 5)
    }

    private static func grass(_ g: GraphicsContext, from x0: CGFloat, to x1: CGFloat, y: CGFloat, depth: CGFloat, count: Int,
                              sim: GardenSim, t: CGFloat, color: GRGB, salt: Int) {
        var dark = Path()
        var light = Path()
        for i in 0..<count {
            let x = x0 + (x1 - x0) * gdRand(i, salt)
            let by = y + depth * gdRand(i, salt + 1)
            let len = 8 + 12 * gdRand(i, salt + 2)
            let lean = sim.windNow * 8 + sin(t * 2.2 + x * 0.05) * (1.5 + sim.wind * 3)
            let tip = CGPoint(x: x + lean + (gdRand(i, salt + 3) - 0.5) * 6, y: by - len)
            var p = Path()
            p.move(to: CGPoint(x: x - 2, y: by))
            p.addQuadCurve(to: tip, control: CGPoint(x: x - 1 + lean * 0.3, y: by - len * 0.6))
            p.addQuadCurve(to: CGPoint(x: x + 2, y: by), control: CGPoint(x: x + 1 + lean * 0.3, y: by - len * 0.6))
            if i % 3 == 0 { light.addPath(p) } else { dark.addPath(p) }
        }
        g.fill(dark, with: .color(color.shade(-0.12).color))
        g.fill(light, with: .color(color.shade(0.12).color))
    }

    // MARK: The bed

    static func soilPath(_ sim: GardenSim) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: GGeo.bedLeft, y: GGeo.bedBottom))
        p.addLine(to: CGPoint(x: GGeo.bedLeft, y: sim.h[0]))
        for i in 0..<GGeo.columns { p.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i])) }
        p.addLine(to: CGPoint(x: GGeo.bedRight, y: sim.h[GGeo.columns - 1]))
        p.addLine(to: CGPoint(x: GGeo.bedRight, y: GGeo.bedBottom))
        p.closeSubpath()
        return p
    }

    private static func soil(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let path = soilPath(sim)
        g.fill(path, with: .linearGradient(Gradient(colors: [GRGB(0xA87A4F).color, GRGB(0x87593A).color, GRGB(0x5E3C26).color]),
                                           startPoint: CGPoint(x: 0, y: GGeo.soilY - 40), endPoint: CGPoint(x: 0, y: GGeo.bedBottom)))
        var c = g
        c.clip(to: path)
        // Layers, grains and pebbles, seen through the glass.
        for k in 0..<3 {
            var band = Path()
            let y0 = GGeo.soilY + 40 + CGFloat(k) * 42
            band.move(to: CGPoint(x: GGeo.bedLeft, y: y0))
            var x = GGeo.bedLeft
            while x <= GGeo.bedRight {
                band.addLine(to: CGPoint(x: x, y: y0 + sin(x * 0.02 + CGFloat(k) * 2) * 6))
                x += 24
            }
            c.stroke(band, with: .color(Color.black.opacity(0.07)), lineWidth: 10)
        }
        var light = Path()
        var dark = Path()
        for i in 0..<360 {
            let x = GGeo.bedLeft + gdRand(i, 11) * (GGeo.bedRight - GGeo.bedLeft)
            let y = GGeo.soilY - 30 + gdRand(i, 12) * (GGeo.bedBottom - GGeo.soilY + 30)
            let s = 1.2 + gdRand(i, 13) * 2.2
            let r = CGRect(x: x, y: y, width: s, height: s * 0.8)
            if i % 2 == 0 { light.addEllipse(in: r) } else { dark.addEllipse(in: r) }
        }
        c.fill(light, with: .color(GRGB(0xD2AC80).color(0.45)))
        c.fill(dark, with: .color(GRGB(0x3E2414).color(0.4)))
        for i in 0..<16 {
            let x = GGeo.bedLeft + 20 + gdRand(i, 21) * (GGeo.bedRight - GGeo.bedLeft - 40)
            let y = GGeo.soilY + 30 + gdRand(i, 22) * (GGeo.bedBottom - GGeo.soilY - 40)
            let w = 9 + gdRand(i, 23) * 14
            let rect = CGRect(x: x, y: y, width: w, height: w * 0.66)
            let stone = GRGB(0xB2A497).mix(GRGB(0x8E8073), gdRand(i, 24))
            c.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [stone.shade(0.3).color, stone.shade(-0.3).color]),
                                                                center: CGPoint(x: rect.minX + w * 0.3, y: rect.minY + w * 0.2),
                                                                startRadius: 0, endRadius: w * 0.8))
        }
        // Roots of everything growing.
        for i in sim.plots.indices {
            guard let p = sim.plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            GardenPlants.drawRoots(c, plant: p, base: CGPoint(x: x, y: sim.surface(x)), pull: sim.plots[i].pull, seed: i * 7)
        }
        for w in sim.weeds { GardenPlants.drawWeedRoot(c, weed: w, base: CGPoint(x: w.x, y: sim.surface(w.x))) }

        // Wet soil darkens, and the soak line creeps down as more water goes in.
        var soak = Path()
        soak.move(to: CGPoint(x: GGeo.bedLeft, y: sim.h[0]))
        for i in 0..<GGeo.columns { soak.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i] - 1)) }
        for i in (0..<GGeo.columns).reversed() {
            let w = min(1, sim.wet[i])
            soak.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i] + 2 + w * 100))
        }
        soak.closeSubpath()
        c.fill(soak, with: .linearGradient(Gradient(colors: [GRGB(0x2A170C).color(0.62), GRGB(0x2A170C).color(0.28)]),
                                           startPoint: CGPoint(x: 0, y: GGeo.soilY - 20), endPoint: CGPoint(x: 0, y: GGeo.soilY + 100)))
        var top = Path()
        top.move(to: CGPoint(x: GGeo.bedLeft, y: sim.h[0]))
        for i in 0..<GGeo.columns { top.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i] - 1)) }
        for i in (0..<GGeo.columns).reversed() {
            let w = min(1, sim.wet[i])
            top.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i] + 1 + w * 16))
        }
        top.closeSubpath()
        c.fill(top, with: .color(GRGB(0x24140A).color(0.3)))

        // The surface: dusty tan when dry, dark and shiny when wet.
        let seg = 4
        var i0 = 0
        while i0 < GGeo.columns - 1 {
            let i1 = min(GGeo.columns - 1, i0 + seg)
            var avg: CGFloat = 0
            for i in i0...i1 { avg += sim.wet[i] }
            avg /= CGFloat(i1 - i0 + 1)
            var line = Path()
            line.move(to: CGPoint(x: GGeo.colX(i0), y: sim.h[i0]))
            for i in (i0 + 1)...i1 { line.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i])) }
            let col = GRGB(0xC09366).mix(GRGB(0x3A2416), min(1, avg * 1.3))
            g.stroke(line, with: .color(col.color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            if avg > 0.45 {
                g.stroke(line.offsetBy(dx: 0, dy: -1.6), with: .color(.white.opacity(Double(min(0.5, (avg - 0.45) * 0.9)))),
                         style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            i0 = i1
        }
        puddles(g, sim, t)
    }

    /// Standing water fills the low spots with a flat, shiny surface.
    private static func puddles(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        var i = 0
        let n = GGeo.columns
        while i < n {
            guard sim.wet[i] > 0.85 else { i += 1; continue }
            var j = i
            var deepest: CGFloat = 0
            var extra: CGFloat = 0
            while j < n && sim.wet[j] > 0.85 {
                deepest = max(deepest, sim.h[j])
                extra = max(extra, sim.wet[j] - 0.85)
                j += 1
            }
            let level = deepest - min(8, 2 + extra * 40)
            var water = Path()
            var started = false
            for k in i..<j where sim.h[k] > level {
                let x = GGeo.colX(k)
                if !started { water.move(to: CGPoint(x: x - 2, y: level)); started = true }
                water.addLine(to: CGPoint(x: x, y: sim.h[k] + 1))
            }
            if started {
                var lastX = GGeo.colX(i)
                for k in i..<j where sim.h[k] > level { lastX = GGeo.colX(k) }
                water.addLine(to: CGPoint(x: lastX + 2, y: level))
                water.closeSubpath()
                g.fill(water, with: .linearGradient(Gradient(colors: [GRGB(0xBFE2F7).color(0.8), GRGB(0x6E9CBE).color(0.7)]),
                                                    startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: deepest)))
                var shine = Path()
                let first = GGeo.colX(i)
                shine.move(to: CGPoint(x: first, y: level + 0.5))
                shine.addLine(to: CGPoint(x: lastX, y: level + 0.5))
                g.stroke(shine, with: .color(.white.opacity(0.7 + 0.2 * Double(sin(t * 3)))), lineWidth: 1.4)
            }
            i = j
        }
    }

    private static func worm(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let w = sim.worm
        let surf = sim.surface(w.x)
        let head = CGPoint(x: w.x, y: surf + w.depth * (1 - w.peek) - 16 * w.peek)
        let wiggleAmp: CGFloat = sim.time - w.wiggle < 1.2 ? 6 : 2.5
        var pts: [CGPoint] = []
        for j in 0..<12 {
            let k = CGFloat(j)
            let along = CGPoint(x: head.x - w.dir * k * 5.2 * (1 - w.peek * 0.85), y: head.y + k * 4.6 * w.peek)
            let wob = sin(w.phase * 2.2 - k * 0.8) * wiggleAmp
            pts.append(CGPoint(x: along.x + wob * w.peek, y: along.y + wob * (1 - w.peek)))
        }
        var body = Path()
        body.move(to: pts[0])
        for p in pts.dropFirst() { body.addLine(to: p) }
        let pink = GRGB(0xF2A0AE)
        g.stroke(body, with: .color(pink.shade(-0.4).color), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
        g.stroke(body, with: .color(pink.color), style: StrokeStyle(lineWidth: 8.6, lineCap: .round, lineJoin: .round))
        g.stroke(body.offsetBy(dx: -1, dy: -1.5), with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        for j in stride(from: 2, to: 11, by: 2) {
            let p = pts[j]
            g.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 4, width: 3.2, height: 8)), with: .color(pink.shade(-0.25).color(0.6)))
        }
        // A sweet face.
        let fx = head.x + w.dir * 1.5 * (1 - w.peek)
        for e in [-2.4, 2.4] as [CGFloat] {
            g.fill(Path(ellipseIn: CGRect(x: fx + e - 1.1, y: head.y - 2.6, width: 2.2, height: 2.6)), with: .color(GRGB(0x3A2430).color))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: fx - 2, y: head.y + 1.2))
        smile.addQuadCurve(to: CGPoint(x: fx + 2, y: head.y + 1.2), control: CGPoint(x: fx, y: head.y + 3.2))
        g.stroke(smile, with: .color(GRGB(0x8A3A4A).color), lineWidth: 0.9)
    }

    private static func plants(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        for w in sim.weeds {
            GardenPlants.drawWeed(g, weed: w, base: CGPoint(x: w.x, y: sim.surface(w.x)), time: t)
        }
        for i in sim.plots.indices {
            guard let p = sim.plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let base = CGPoint(x: x, y: sim.surface(x))
            let st = sim.plots[i]
            GardenPlants.draw(g, plant: p, base: base, bend: st.bend, pop: st.pop, pull: st.pull, time: t, droop: st.dry > 1.5)
        }
    }

    private static func glassAndFrame(_ g: GraphicsContext) {
        let top: CGFloat = 534
        // Reflections on the glass front.
        var sheen = Path()
        sheen.move(to: CGPoint(x: 150, y: GGeo.bedBottom))
        sheen.addLine(to: CGPoint(x: 250, y: top))
        sheen.addLine(to: CGPoint(x: 300, y: top))
        sheen.addLine(to: CGPoint(x: 200, y: GGeo.bedBottom))
        sheen.closeSubpath()
        sheen.move(to: CGPoint(x: 230, y: GGeo.bedBottom))
        sheen.addLine(to: CGPoint(x: 330, y: top))
        sheen.addLine(to: CGPoint(x: 342, y: top))
        sheen.addLine(to: CGPoint(x: 242, y: GGeo.bedBottom))
        sheen.closeSubpath()
        sheen.move(to: CGPoint(x: 700, y: GGeo.bedBottom))
        sheen.addLine(to: CGPoint(x: 780, y: top))
        sheen.addLine(to: CGPoint(x: 806, y: top))
        sheen.addLine(to: CGPoint(x: 726, y: GGeo.bedBottom))
        sheen.closeSubpath()
        g.fill(sheen, with: .color(.white.opacity(0.08)))
        var edge = Path()
        edge.move(to: CGPoint(x: GGeo.bedLeft, y: top))
        edge.addLine(to: CGPoint(x: GGeo.bedRight, y: top))
        g.stroke(edge, with: .color(.white.opacity(0.45)), lineWidth: 2.2)
        g.stroke(edge.offsetBy(dx: 0, dy: 2.5), with: .color(GRGB(0x9FC7D6).color(0.3)), lineWidth: 1.4)
        // Wooden posts and the bottom beam.
        let wood = Gradient(colors: [GRGB(0xD39A62).color, GRGB(0xB07642).color, GRGB(0x8E5A30).color])
        for x in [40.0, 958.0] as [CGFloat] {
            let post = CGRect(x: x, y: 512, width: 26, height: 222)
            g.fill(Path(roundedRect: post, cornerRadius: 5), with: .linearGradient(wood, startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + 26, y: 0)))
            g.fill(Path(roundedRect: CGRect(x: x - 3, y: 506, width: 32, height: 12), cornerRadius: 4), with: .color(GRGB(0xDDA874).color))
            for k in 0..<3 {
                var grain = Path()
                let gx = x + 6 + CGFloat(k) * 7
                grain.move(to: CGPoint(x: gx, y: 530))
                grain.addQuadCurve(to: CGPoint(x: gx + 1, y: 720), control: CGPoint(x: gx + 3, y: 620))
                g.stroke(grain, with: .color(GRGB(0x7A4A26).color(0.3)), lineWidth: 1)
            }
        }
        let beam = CGRect(x: 40, y: 708, width: 944, height: 26)
        g.fill(Path(roundedRect: beam, cornerRadius: 6), with: .linearGradient(wood, startPoint: CGPoint(x: 0, y: 708), endPoint: CGPoint(x: 0, y: 734)))
        var bg = Path()
        bg.move(to: CGPoint(x: 60, y: 716))
        bg.addQuadCurve(to: CGPoint(x: 960, y: 718), control: CGPoint(x: 500, y: 713))
        bg.move(to: CGPoint(x: 70, y: 726))
        bg.addQuadCurve(to: CGPoint(x: 940, y: 725), control: CGPoint(x: 500, y: 729))
        g.stroke(bg, with: .color(GRGB(0x7A4A26).color(0.3)), lineWidth: 1)
    }

    private static func frontLawn(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        var lawn = Path()
        lawn.move(to: CGPoint(x: r.minX, y: 732))
        lawn.addLine(to: CGPoint(x: r.maxX, y: 732))
        lawn.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        lawn.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        lawn.closeSubpath()
        // Lawn beside the bed, up to the back lawn.
        lawn.addRect(CGRect(x: r.minX, y: 540, width: 40 - r.minX, height: 200))
        lawn.addRect(CGRect(x: 984, y: 540, width: r.maxX - 984, height: 200))
        g.fill(lawn, with: .linearGradient(Gradient(colors: [GRGB(0x7FCB5C).color, GRGB(0x5FAE45).color]),
                                           startPoint: CGPoint(x: 0, y: 540), endPoint: CGPoint(x: 0, y: 834)))
        grass(g, from: r.minX, to: r.maxX, y: 732, depth: 12, count: Int(r.width / 6), sim: sim, t: t, color: GRGB(0x72BE52), salt: 31)
        // Clover flowers.
        for i in 0..<14 {
            let x = r.minX + gdRand(i, 41) * r.width
            let y = 760 + gdRand(i, 42) * 60
            if abs(x - GGeo.basket.x) < 70 { continue }
            GardenPlants.daisyHead(g, at: CGPoint(x: x, y: y), open: 1, color: i % 3 == 0 ? GRGB(0xFFD1E3) : GRGB(0xFFFFFF), size: 0.4, spin: CGFloat(i))
        }
    }

    // MARK: Moving things

    private static func particles(_ g: GraphicsContext, _ sim: GardenSim, front: Bool) {
        var water = Path()
        var waterCore = Path()
        var rain = Path()
        var splash = Path()
        for q in sim.particles {
            let life = Double(max(0, 1 - q.age / q.life))
            switch q.kind {
            case .water where !front:
                var p = Path()
                p.move(to: q.p)
                p.addLine(to: CGPoint(x: q.p.x - q.v.dx * 0.022, y: q.p.y - q.v.dy * 0.022))
                water.addPath(p.strokedPath(StrokeStyle(lineWidth: q.size, lineCap: .round)))
                waterCore.addPath(p.strokedPath(StrokeStyle(lineWidth: q.size * 0.35, lineCap: .round)))
            case .rain where front:
                var p = Path()
                p.move(to: q.p)
                p.addLine(to: CGPoint(x: q.p.x - q.v.dx * 0.018, y: q.p.y - q.v.dy * 0.018))
                rain.addPath(p.strokedPath(StrokeStyle(lineWidth: q.size, lineCap: .round)))
            case .splash where !front:
                splash.addEllipse(in: CGRect(x: q.p.x - q.size, y: q.p.y - q.size, width: q.size * 2, height: q.size * 2))
            case .clod where !front:
                clod(g, q)
            case .seed where !front:
                var sg = g
                sg.translateBy(x: q.p.x, y: q.p.y)
                sg.rotate(by: .radians(Double(q.rot)))
                let r = CGRect(x: -q.size, y: -q.size * 0.6, width: q.size * 2, height: q.size * 1.2)
                let a = q.resting ? life * 1.5 : 1
                sg.fill(Path(ellipseIn: r), with: .color(q.color.color(min(1, a))))
                if q.seed == .sunflower {
                    sg.fill(Path(CGRect(x: -q.size * 0.8, y: -0.5, width: q.size * 1.6, height: 1)), with: .color(.white.opacity(0.7 * min(1, a))))
                }
            case .dust:
                if front { continue }
                let r = CGRect(x: q.p.x - q.size, y: q.p.y - q.size, width: q.size * 2, height: q.size * 2)
                g.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [q.color.color(0.45 * life), q.color.color(0)]),
                                                                center: q.p, startRadius: 0, endRadius: q.size))
            case .ripple where !front:
                let r = CGRect(x: q.p.x - q.size * 2, y: q.p.y - q.size * 0.5, width: q.size * 4, height: q.size)
                g.stroke(Path(ellipseIn: r), with: .color(.white.opacity(0.8 * life)), lineWidth: 1)
            case .sparkle where front:
                let s = q.size * CGFloat(0.4 + 0.6 * life)
                var sg = g
                sg.translateBy(x: q.p.x, y: q.p.y)
                sg.rotate(by: .radians(Double(q.rot)))
                sg.fill(Twinkle().path(in: CGRect(x: -s, y: -s, width: s * 2, height: s * 2)), with: .color(q.color.color(life)))
            case .petal where front, .leaf where front:
                var sg = g
                sg.translateBy(x: q.p.x, y: q.p.y)
                sg.rotate(by: .radians(Double(q.rot)))
                let fade = min(1, life * 3)
                if q.kind == .petal {
                    let r = CGRect(x: -q.size * 0.5, y: -q.size * 0.3, width: q.size, height: q.size * 0.6)
                    sg.fill(Path(ellipseIn: r), with: .color(q.color.color(fade)))
                } else {
                    var leaf = Path()
                    leaf.move(to: CGPoint(x: -q.size, y: 0))
                    leaf.addQuadCurve(to: CGPoint(x: q.size, y: 0), control: CGPoint(x: 0, y: -q.size * 0.7))
                    leaf.addQuadCurve(to: CGPoint(x: -q.size, y: 0), control: CGPoint(x: 0, y: q.size * 0.7))
                    sg.fill(leaf, with: .color(q.color.color(fade)))
                    sg.stroke(leaf, with: .color(q.color.shade(-0.4).color(fade * 0.6)), lineWidth: 0.8)
                }
            default:
                continue
            }
        }
        if !front {
            g.fill(water, with: .color(GRGB(0x9FD3FA).color(0.8)))
            g.fill(waterCore, with: .color(.white.opacity(0.75)))
            g.fill(splash, with: .color(GRGB(0xD6EEFF).color(0.85)))
        } else {
            g.fill(rain, with: .color(GRGB(0xE4EEF8).color(0.55)))
        }
    }

    private static func clod(_ g: GraphicsContext, _ q: GParticle) {
        var sg = g
        sg.translateBy(x: q.p.x, y: q.p.y)
        sg.rotate(by: .radians(Double(q.rot)))
        var p = Path()
        let seed = Int(q.color.r * 1000) + Int(q.size * 10)
        for k in 0..<7 {
            let a = CGFloat(k) / 7 * 2 * .pi
            let rr = q.size * (0.75 + 0.35 * gdRand(k, seed))
            let pt = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        let alpha = q.resting ? Double(max(0, min(1, (q.life - q.age) / 0.6))) : 1
        sg.fill(p, with: .radialGradient(Gradient(colors: [q.color.shade(0.25).color(alpha), q.color.shade(-0.25).color(alpha)]),
                                         center: CGPoint(x: -q.size * 0.3, y: -q.size * 0.3), startRadius: 0, endRadius: q.size * 1.3))
    }

    private static func flyers(_ g: GraphicsContext, _ sim: GardenSim) {
        for f in sim.flyers {
            let p = f.pos(sim.time)
            let k = CGFloat(sim.time - f.start)
            let rot = f.spin * k
            switch f.kind {
            case .crop(let kind, let v):
                let s = 1 + 0.25 * sin(min(1, k / CGFloat(f.dur)) * .pi)
                GardenPlants.drawCrop(g, kind: kind, variant: v, at: p, size: s, rot: rot)
            case .weed(let seed):
                var wg = g
                wg.opacity = Double(max(0, min(1, (CGFloat(f.dur) - k) / 0.5)))
                wg.translateBy(x: p.x, y: p.y)
                wg.rotate(by: .radians(Double(rot)))
                GardenPlants.drawWeed(wg, weed: GWeed(x: 0, growth: 1, seed: seed, pull: 1), base: .zero, time: 0)
            case .uprooted(let plant):
                var wg = g
                wg.opacity = Double(max(0, min(1, (CGFloat(f.dur) - k) / 0.5)))
                wg.translateBy(x: p.x, y: p.y)
                wg.rotate(by: .radians(Double(rot)))
                wg.scaleBy(x: 0.7, y: 0.7)
                GardenPlants.draw(wg, plant: plant, base: .zero, bend: 0, pop: 0, pull: 0, time: 0, droop: false)
                GardenPlants.drawRoots(wg, plant: plant, base: .zero, pull: 0, seed: 3)
            case .decor:
                break
            }
        }
    }

    // MARK: Bugs

    static let wingLooks: [(GRGB, GRGB)] = [(GRGB(0xFF7FB0), GRGB(0xFFD6E6)), (GRGB(0x6FB5FF), GRGB(0xD6ECFF)),
                                             (GRGB(0xFFA43A), GRGB(0xFFE49A)), (GRGB(0xA77CFF), GRGB(0xE6DAFF)),
                                             (GRGB(0x4FCFAE), GRGB(0xD3F5EA))]

    static func butterfly(_ g: GraphicsContext, at p: CGPoint, phase: CGFloat, perched: Bool, facing: CGFloat, look: Int, scale: CGFloat = 1) {
        let open: CGFloat = perched ? 0.55 + 0.45 * sin(phase) : abs(sin(phase))
        let colors = wingLooks[abs(look) % wingLooks.count]
        var b = g
        b.translateBy(x: p.x, y: p.y)
        b.scaleBy(x: scale, y: scale)
        b.rotate(by: .radians(Double(facing * 0.25)))
        for side in [-1.0, 1.0] as [CGFloat] {
            var w = b
            w.scaleBy(x: side * (0.18 + 0.82 * open), y: 1)
            var upper = Path()
            upper.move(to: CGPoint(x: 0, y: -2))
            upper.addCurve(to: CGPoint(x: 2, y: 4), control1: CGPoint(x: 26, y: -26), control2: CGPoint(x: 30, y: 2))
            var lower = Path()
            lower.move(to: CGPoint(x: 0, y: 2))
            lower.addCurve(to: CGPoint(x: 0, y: 6), control1: CGPoint(x: 20, y: 6), control2: CGPoint(x: 14, y: 24))
            let grad = Gradient(colors: [colors.0.shade(-0.2).color, colors.0.color, colors.1.color])
            w.fill(lower, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: 18, y: 20)))
            w.fill(upper, with: .linearGradient(grad, startPoint: .zero, endPoint: CGPoint(x: 28, y: -18)))
            w.stroke(upper, with: .color(colors.0.shade(-0.55).color(0.8)), lineWidth: 1.2)
            w.stroke(lower, with: .color(colors.0.shade(-0.55).color(0.8)), lineWidth: 1.2)
            w.fill(Path(ellipseIn: CGRect(x: 14, y: -12, width: 6, height: 6)), with: .color(.white.opacity(0.8)))
            w.fill(Path(ellipseIn: CGRect(x: 8, y: 9, width: 4, height: 4)), with: .color(.white.opacity(0.7)))
        }
        let body = Path(roundedRect: CGRect(x: -2.4, y: -9, width: 4.8, height: 20), cornerRadius: 2.4)
        b.fill(body, with: .color(GRGB(0x4A3B5C).color))
        b.fill(Path(ellipseIn: CGRect(x: -3.4, y: -13, width: 6.8, height: 6.8)), with: .color(GRGB(0x4A3B5C).color))
        var ant = Path()
        ant.move(to: CGPoint(x: -1, y: -12))
        ant.addQuadCurve(to: CGPoint(x: -7, y: -22), control: CGPoint(x: -2, y: -20))
        ant.move(to: CGPoint(x: 1, y: -12))
        ant.addQuadCurve(to: CGPoint(x: 7, y: -22), control: CGPoint(x: 2, y: -20))
        b.stroke(ant, with: .color(GRGB(0x4A3B5C).color), lineWidth: 1)
    }

    private static func bugs(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        // Ladybug
        let lb = sim.ladybug
        var l = g
        l.translateBy(x: lb.p.x, y: lb.p.y)
        l.scaleBy(x: lb.dir < 0 ? -1 : 1, y: 1)
        if !lb.flying {
            for k in 0..<3 {
                let step = sin(lb.walk * 0.9 + CGFloat(k) * 2) * 1.5
                var leg = Path()
                leg.move(to: CGPoint(x: -4 + CGFloat(k) * 4, y: -1))
                leg.addLine(to: CGPoint(x: -5 + CGFloat(k) * 4 + step, y: 3))
                l.stroke(leg, with: .color(GRGB(0x2A2020).color), lineWidth: 1)
            }
        }
        if lb.open > 0.05 {
            for side in [-1.0, 1.0] as [CGFloat] {
                var wing = l
                wing.rotate(by: .radians(Double(side * 0.5 * lb.open) - 0.3))
                let wr = CGRect(x: side < 0 ? -16 : 0, y: -14, width: 16, height: 9)
                wing.fill(Path(ellipseIn: wr), with: .color(.white.opacity(0.5 * Double(lb.open))))
            }
        }
        l.fill(Path(ellipseIn: CGRect(x: 6, y: -8, width: 7, height: 7)), with: .color(GRGB(0x2A2020).color))
        let shell = Path { p in
            p.move(to: CGPoint(x: -9, y: 0))
            p.addQuadCurve(to: CGPoint(x: 9, y: 0), control: CGPoint(x: 0, y: -20))
            p.closeSubpath()
        }
        var sh = l
        if lb.open > 0.05 { sh.rotate(by: .radians(Double(-0.5 * lb.open))) }
        sh.fill(shell, with: .radialGradient(Gradient(colors: [GRGB(0xFF6A5E).color, GRGB(0xD12A22).color]),
                                             center: CGPoint(x: -3, y: -7), startRadius: 0, endRadius: 12))
        for d in [CGPoint(x: -4, y: -5), CGPoint(x: 3, y: -6), CGPoint(x: 0, y: -2.5)] {
            sh.fill(Path(ellipseIn: CGRect(x: d.x - 1.6, y: d.y - 1.6, width: 3.2, height: 3.2)), with: .color(GRGB(0x2A2020).color))
        }
        var mid = Path()
        mid.move(to: CGPoint(x: 0, y: -9.5))
        mid.addLine(to: CGPoint(x: 0, y: 0))
        sh.stroke(mid, with: .color(GRGB(0x2A2020).color), lineWidth: 0.8)

        for b in sim.butterflies {
            butterfly(g, at: b.p, phase: b.phase, perched: b.perch != nil, facing: b.v.dx >= 0 ? 1 : -1, look: b.look)
        }
        if let bee = sim.bee {
            var bg = g
            bg.translateBy(x: bee.p.x, y: bee.p.y)
            bg.scaleBy(x: bee.v.dx < 0 ? -1 : 1, y: 1)
            let flap = abs(sin(bee.phase))
            for o in [-3.0, 3.0] as [CGFloat] {
                let wr = CGRect(x: o - 5, y: -14 - 6 * flap, width: 10, height: 6 + 8 * flap)
                bg.fill(Path(ellipseIn: wr), with: .color(.white.opacity(0.75)))
                bg.stroke(Path(ellipseIn: wr), with: .color(GRGB(0x9FC0D6).color(0.6)), lineWidth: 0.8)
            }
            let body = Path(ellipseIn: CGRect(x: -11, y: -7, width: 22, height: 14))
            bg.fill(body, with: .radialGradient(Gradient(colors: [GRGB(0xFFE36A).color, GRGB(0xF2B500).color]),
                                                center: CGPoint(x: 2, y: -3), startRadius: 0, endRadius: 14))
            bg.clip(to: body)
            for x in [-4.0, 2.0] as [CGFloat] {
                bg.fill(Path(CGRect(x: x, y: -8, width: 3.2, height: 16)), with: .color(GRGB(0x3B2F2F).color))
            }
            var face = g
            face.translateBy(x: bee.p.x, y: bee.p.y)
            face.scaleBy(x: bee.v.dx < 0 ? -1 : 1, y: 1)
            face.fill(Path(ellipseIn: CGRect(x: 6, y: -3.5, width: 2.6, height: 3)), with: .color(GRGB(0x2A2020).color))
        }
    }

    // MARK: Basket

    private static func basket(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let c = GGeo.basket
        var b = g
        b.translateBy(x: c.x, y: c.y + 30)
        b.scaleBy(x: 1 - sim.basketBounce * 0.03, y: 1 + sim.basketBounce * 0.05)
        b.translateBy(x: 0, y: -30)
        let wicker = GRGB(0xD79B57)
        PlantsShadow.draw(b, at: CGPoint(x: 0, y: 30), width: 130)
        // Handle and back rim.
        var handle = Path()
        handle.move(to: CGPoint(x: -50, y: -12))
        handle.addCurve(to: CGPoint(x: 50, y: -12), control1: CGPoint(x: -46, y: -84), control2: CGPoint(x: 46, y: -84))
        b.stroke(handle, with: .color(wicker.shade(-0.3).color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        b.stroke(handle, with: .color(wicker.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        b.fill(Path(ellipseIn: CGRect(x: -60, y: -22, width: 120, height: 22)), with: .color(wicker.shade(-0.45).color))
        // What she picked, heaped up.
        let items = sim.basket.suffix(12)
        for (k, name) in items.enumerated() {
            let parts = name.split(separator: ":")
            guard let kind = PlantKind(rawValue: String(parts.first ?? "")) else { continue }
            let v = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
            let row = k / 4
            let col = k % 4
            let x = -36 + CGFloat(col) * 24 + (row % 2 == 0 ? 0 : 10)
            let y = -12 - CGFloat(row) * 13
            GardenPlants.drawCrop(b, kind: kind, variant: v, at: CGPoint(x: x, y: y), size: 0.62, rot: (gdRand(k, 9) - 0.5) * 0.8)
        }
        // Woven front.
        var front = Path()
        front.move(to: CGPoint(x: -60, y: -11))
        front.addQuadCurve(to: CGPoint(x: 60, y: -11), control: CGPoint(x: 0, y: 2))
        front.addLine(to: CGPoint(x: 46, y: 30))
        front.addQuadCurve(to: CGPoint(x: -46, y: 30), control: CGPoint(x: 0, y: 38))
        front.closeSubpath()
        b.fill(front, with: .linearGradient(Gradient(colors: [wicker.shade(0.12).color, wicker.shade(-0.25).color]),
                                            startPoint: CGPoint(x: 0, y: -10), endPoint: CGPoint(x: 0, y: 34)))
        var weave = b
        weave.clip(to: front)
        for k in 0..<5 {
            var row = Path()
            let y = -4 + CGFloat(k) * 8
            row.move(to: CGPoint(x: -62, y: y))
            var x: CGFloat = -62
            while x < 62 {
                row.addQuadCurve(to: CGPoint(x: x + 12, y: y), control: CGPoint(x: x + 6, y: y + (k % 2 == 0 ? 4 : -4)))
                x += 12
            }
            weave.stroke(row, with: .color(wicker.shade(-0.4).color(0.55)), lineWidth: 1.4)
        }
        b.stroke(front, with: .color(wicker.shade(-0.5).color), lineWidth: 1.5)
        b.fill(Path(roundedRect: CGRect(x: -62, y: -16, width: 124, height: 9), cornerRadius: 4.5), with: .color(wicker.shade(0.05).color))
    }

    // MARK: Night, glows, hints

    private static func nightAndGlow(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        if sim.rain > 0.01 { g.fill(Path(r), with: .color(GRGB(0x4A5566).color(0.18 * Double(sim.rain)))) }
        guard sim.night > 0.01 else { return }
        let n = Double(sim.night)
        g.fill(Path(r), with: .color(GRGB(0x0B1236).color(0.5 * n)))
        // Stars and the moon shine through.
        let starA = n * Double(1 - sim.cloud * 0.8)
        for i in 0..<60 {
            let x = r.minX + gdRand(i, 51) * r.width
            let y = 12 + gdRand(i, 52) * 340
            let tw = 0.5 + 0.5 * sin(t * (1.5 + gdRand(i, 53) * 2) + CGFloat(i))
            let s = 1.2 + gdRand(i, 54) * 1.8
            g.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(.white.opacity(starA * Double(tw))))
        }
        let mc = CGPoint(x: 846, y: 128)
        g.fill(Path(ellipseIn: CGRect(x: mc.x - 110, y: mc.y - 110, width: 220, height: 220)),
               with: .radialGradient(Gradient(colors: [Color.white.opacity(0.25 * n), Color.white.opacity(0)]), center: mc, startRadius: 20, endRadius: 110))
        var moon = Path(ellipseIn: CGRect(x: mc.x - 38, y: mc.y - 38, width: 76, height: 76))
        moon.addEllipse(in: CGRect(x: mc.x - 18, y: mc.y - 50, width: 76, height: 76))
        g.fill(moon, with: .color(Color(hex: 0xFFF6D0, alpha: n)), style: FillStyle(eoFill: true))
        var glow = g
        glow.blendMode = .plusLighter
        for d in sim.decor where d.kind == .lantern && d.lit {
            let c = CGPoint(x: d.x, y: d.y - 96)
            let a = 0.25 + 0.75 * n
            glow.fill(Path(ellipseIn: CGRect(x: c.x - 90, y: c.y - 90, width: 180, height: 180)),
                      with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC766, alpha: 0.55 * a), Color(hex: 0xFFC766, alpha: 0)]),
                                            center: c, startRadius: 4, endRadius: 90))
        }
        for (i, f) in sim.fireflies.enumerated() {
            let pulse = 0.5 + 0.5 * sin(f.phase * 3 + CGFloat(i))
            let a = n * Double(pulse)
            glow.fill(Path(ellipseIn: CGRect(x: f.p.x - 16, y: f.p.y - 16, width: 32, height: 32)),
                      with: .radialGradient(Gradient(colors: [Color(hex: 0xE6FF7A, alpha: 0.7 * a), Color(hex: 0xE6FF7A, alpha: 0)]),
                                            center: f.p, startRadius: 0, endRadius: 16))
            glow.fill(Path(ellipseIn: CGRect(x: f.p.x - 2.4, y: f.p.y - 2.4, width: 4.8, height: 4.8)), with: .color(Color(hex: 0xFAFFD0, alpha: a)))
        }
    }

    private static func hints(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let pulse = 0.5 + 0.5 * sin(t * 4)
        var spots: [Int] = []
        switch sim.tool {
        case .shovel?: spots = sim.plots.indices.filter { sim.plots[$0].plant == nil && !sim.hasHole(plot: $0) }
        case .seeds?: spots = sim.plots.indices.filter { sim.hasHole(plot: $0) }
        default: break
        }
        for i in spots {
            let x = GGeo.plotX[i]
            let y = sim.surface(x)
            let r = CGRect(x: x - 30 - 6 * pulse, y: y - 9 - 2 * pulse, width: 60 + 12 * pulse, height: 18 + 4 * pulse)
            g.stroke(Path(ellipseIn: r), with: .color(.white.opacity(0.85 - 0.4 * Double(pulse))),
                     style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 6]))
        }
        // Thirsty plants show a bobbing drop; ripe ones twinkle.
        for i in sim.plots.indices {
            guard let p = sim.plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let top = sim.surface(x) - GardenPlants.stemHeight(p)
            if sim.plots[i].dry > 1.5 && p.growth < 1 {
                let a = Double(min(1, (sim.plots[i].dry - 1.5) * 2))
                let c = CGPoint(x: x + 18, y: top - 34 + sin(t * 3 + CGFloat(i)) * 5)
                g.fill(Path(ellipseIn: CGRect(x: c.x - 20, y: c.y - 20, width: 40, height: 40)), with: .color(.white.opacity(0.85 * a)))
                var drop = Path()
                drop.move(to: CGPoint(x: c.x, y: c.y - 13))
                drop.addCurve(to: CGPoint(x: c.x, y: c.y + 11), control1: CGPoint(x: c.x + 5, y: c.y - 4), control2: CGPoint(x: c.x + 11, y: c.y + 11))
                drop.addCurve(to: CGPoint(x: c.x, y: c.y - 13), control1: CGPoint(x: c.x - 11, y: c.y + 11), control2: CGPoint(x: c.x - 5, y: c.y - 4))
                g.fill(drop, with: .linearGradient(Gradient(colors: [Color(hex: 0x9FD8FF, alpha: a), Color(hex: 0x3F8FE0, alpha: a)]),
                                                   startPoint: CGPoint(x: c.x, y: c.y - 13), endPoint: CGPoint(x: c.x, y: c.y + 11)))
                g.fill(Path(ellipseIn: CGRect(x: c.x - 4.5, y: c.y + 0, width: 3.5, height: 5)), with: .color(.white.opacity(0.8 * a)))
            } else if p.growth >= 1 && p.left > 0 && sim.tool == nil {
                let tw = max(0, sin(t * 2.4 + CGFloat(i) * 1.7))
                let s = 9 * tw
                if s > 1 {
                    let c = CGPoint(x: x + 22, y: top - 6)
                    g.fill(Twinkle().path(in: CGRect(x: c.x - s, y: c.y - s, width: s * 2, height: s * 2)), with: .color(.white.opacity(0.95)))
                }
            }
        }
    }

    // MARK: The tool in her hand

    private static func tool(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        if let tl = sim.tool {
            drawTool(g, tl, at: sim.toolP, tilt: sim.tilt, load: sim.load, time: t)
        }
        if let r = sim.returning {
            let k = gdEase(CGFloat(sim.time - r.start) / 0.32)
            if k < 1 {
                let p = CGPoint(x: r.from.x + (r.to.x - r.from.x) * k, y: r.from.y + (r.to.y - r.from.y) * k - 60 * sin(k * .pi))
                var sg = g
                sg.opacity = Double(1 - k * 0.3)
                drawTool(sg, r.tool, at: p, tilt: r.tilt * (1 - k), load: 0, time: t)
            }
        }
    }

    static func drawTool(_ g: GraphicsContext, _ tool: GardenTool, at p: CGPoint, tilt: CGFloat, load: CGFloat, time: CGFloat) {
        var c = g
        c.translateBy(x: p.x, y: p.y)
        switch tool {
        case .shovel:
            c.rotate(by: .radians(Double(tilt)))
            shovel(c, load: load)
        case .can:
            c.rotate(by: .radians(Double(-tilt)))
            can(c)
        case .seeds(let k):
            c.rotate(by: .radians(Double(tilt)))
            packet(c, kind: k)
        case .decor(let k):
            c.rotate(by: .radians(Double(tilt)))
            var d = GDecor(id: 0, kind: k, x: 0, y: k.size.height * 0.5)
            d.held = true
            GardenDecorPainter.draw(c, d, time: time, night: 0, wind: 0)
        }
    }

    static func shovel(_ c: GraphicsContext, load: CGFloat) {
        var shaft = Path()
        shaft.move(to: CGPoint(x: 0, y: -52))
        shaft.addLine(to: CGPoint(x: 0, y: -168))
        c.stroke(shaft, with: .color(GRGB(0x8E5A30).color), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        c.stroke(shaft, with: .color(GRGB(0xD39A62).color), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        let grip = Path(roundedRect: CGRect(x: -24, y: -192, width: 48, height: 22), cornerRadius: 11)
        c.fill(grip, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFB3CF), Color(hex: 0xFF7FAE)]),
                                           startPoint: CGPoint(x: 0, y: -192), endPoint: CGPoint(x: 0, y: -170)))
        c.stroke(grip, with: .color(Color(hex: 0xD9558A)), lineWidth: 1.5)
        var blade = Path()
        blade.move(to: CGPoint(x: 0, y: 4))
        blade.addCurve(to: CGPoint(x: -22, y: -40), control1: CGPoint(x: -14, y: 0), control2: CGPoint(x: -24, y: -18))
        blade.addLine(to: CGPoint(x: -20, y: -58))
        blade.addQuadCurve(to: CGPoint(x: 20, y: -58), control: CGPoint(x: 0, y: -50))
        blade.addLine(to: CGPoint(x: 22, y: -40))
        blade.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: 24, y: -18), control2: CGPoint(x: 14, y: 0))
        c.fill(blade, with: .linearGradient(Gradient(colors: [Color(hex: 0xEEF3F7), Color(hex: 0xB4C0CB), Color(hex: 0x86939F)]),
                                            startPoint: CGPoint(x: -22, y: -40), endPoint: CGPoint(x: 22, y: 0)))
        c.stroke(blade, with: .color(Color(hex: 0x6D7A86)), lineWidth: 1.5)
        var shine = Path()
        shine.move(to: CGPoint(x: -12, y: -46))
        shine.addQuadCurve(to: CGPoint(x: -6, y: -8), control: CGPoint(x: -16, y: -24))
        c.stroke(shine, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        if load > 1 {
            let s = min(1.4, sqrt(load / 600))
            let mound = CGRect(x: -22 * s, y: -32 - 18 * s, width: 44 * s, height: 28 * s)
            c.fill(Path(ellipseIn: mound), with: .radialGradient(Gradient(colors: [GRGB(0x9C6A42).color, GRGB(0x5E3C26).color]),
                                                                center: CGPoint(x: mound.midX - 6, y: mound.minY + 6), startRadius: 0, endRadius: 30 * s))
            for k in 0..<5 {
                let x = mound.minX + mound.width * gdRand(k, 61)
                let y = mound.minY + mound.height * 0.5 * gdRand(k, 62)
                c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 3)), with: .color(GRGB(0xB98A5E).color))
            }
        }
    }

    static func can(_ c: GraphicsContext) {
        let teal = GRGB(0x4FC0A8)
        // Spout first, it sits behind the body.
        var spout = Path()
        spout.move(to: CGPoint(x: -34, y: 70))
        spout.addLine(to: CGPoint(x: -104, y: -2))
        spout.addLine(to: CGPoint(x: -98, y: -10))
        spout.addLine(to: CGPoint(x: -30, y: 50))
        spout.closeSubpath()
        c.fill(spout, with: .linearGradient(Gradient(colors: [teal.shade(0.1).color, teal.shade(-0.3).color]),
                                            startPoint: CGPoint(x: -100, y: -10), endPoint: CGPoint(x: -96, y: 4)))
        c.stroke(spout, with: .color(teal.shade(-0.5).color), lineWidth: 1.4)
        var rose = c
        rose.translateBy(x: -110, y: -8)
        rose.rotate(by: .radians(-0.85))
        let face = Path(ellipseIn: CGRect(x: -6, y: -13, width: 12, height: 26))
        rose.fill(face, with: .linearGradient(Gradient(colors: [Color(hex: 0xE9EEF2), Color(hex: 0x9AA7B2)]),
                                              startPoint: CGPoint(x: 0, y: -13), endPoint: CGPoint(x: 0, y: 13)))
        rose.stroke(face, with: .color(Color(hex: 0x6D7A86)), lineWidth: 1.2)
        for k in -2...2 {
            rose.fill(Path(ellipseIn: CGRect(x: -1.4, y: CGFloat(k) * 4.4 - 1.2, width: 2.4, height: 2.4)), with: .color(Color(hex: 0x52606C)))
        }
        // Handle, under her finger.
        var handle = Path()
        handle.move(to: CGPoint(x: -26, y: 30))
        handle.addCurve(to: CGPoint(x: 40, y: 30), control1: CGPoint(x: -24, y: -14), control2: CGPoint(x: 38, y: -14))
        c.stroke(handle, with: .color(teal.shade(-0.45).color), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        c.stroke(handle, with: .color(teal.color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        let body = Path(roundedRect: CGRect(x: -38, y: 26, width: 88, height: 80), cornerRadius: 18)
        c.fill(body, with: .linearGradient(Gradient(colors: [teal.shade(0.3).color, teal.color, teal.shade(-0.3).color]),
                                           startPoint: CGPoint(x: -38, y: 30), endPoint: CGPoint(x: 50, y: 100)))
        c.stroke(body, with: .color(teal.shade(-0.5).color), lineWidth: 1.6)
        c.fill(Path(roundedRect: CGRect(x: -38, y: 44, width: 88, height: 10), cornerRadius: 3), with: .color(teal.shade(-0.18).color))
        c.fill(Path(roundedRect: CGRect(x: -28, y: 60, width: 10, height: 38), cornerRadius: 5), with: .color(.white.opacity(0.35)))
        // A painted flower on the side.
        GardenPlants.daisyHead(c, at: CGPoint(x: 16, y: 78), open: 1, color: GRGB(0xFFD6E6), size: 0.8, spin: 0)
    }

    static func packet(_ c: GraphicsContext, kind: PlantKind) {
        let (paper, band) = kind.packet
        var bag = Path()
        bag.move(to: CGPoint(x: -30, y: -40))
        for k in 0..<7 {
            let x = -30 + CGFloat(k + 1) * (60.0 / 7)
            bag.addLine(to: CGPoint(x: x - 4.3, y: k % 2 == 0 ? -45 : -40))
            bag.addLine(to: CGPoint(x: x, y: -40))
        }
        bag.addLine(to: CGPoint(x: 30, y: 40))
        bag.addQuadCurve(to: CGPoint(x: -30, y: 40), control: CGPoint(x: 0, y: 44))
        bag.closeSubpath()
        c.fill(bag, with: .linearGradient(Gradient(colors: [paper.shade(0.25).color, paper.color, paper.shade(-0.15).color]),
                                          startPoint: CGPoint(x: -30, y: -40), endPoint: CGPoint(x: 30, y: 40)))
        c.stroke(bag, with: .color(paper.shade(-0.45).color), lineWidth: 1.5)
        let window = Path(roundedRect: CGRect(x: -22, y: -28, width: 44, height: 46), cornerRadius: 10)
        c.fill(window, with: .color(.white.opacity(0.85)))
        GardenPlants.drawCrop(c, kind: kind, variant: 0, at: CGPoint(x: 0, y: -4), size: kind == .pumpkin ? 0.62 : 0.9, rot: 0)
        c.fill(Path(roundedRect: CGRect(x: -30, y: 24, width: 60, height: 10), cornerRadius: 2), with: .color(band.color))
        for k in 0..<3 {
            let r = CGRect(x: -12 + CGFloat(k) * 9, y: 26.5, width: 5, height: 4)
            c.fill(Path(ellipseIn: r), with: .color(kind.seedColor.shade(0.1).color))
        }
    }
}

private enum PlantsShadow {
    static func draw(_ g: GraphicsContext, at p: CGPoint, width: CGFloat) { GardenPlants.shadow(g, at: p, width: width) }
}

// MARK: - Decorations

enum GardenDecorPainter {
    static func draw(_ g: GraphicsContext, _ d: GDecor, time t: CGFloat, night: CGFloat, wind: CGFloat) {
        var c = g
        c.translateBy(x: d.x, y: d.y)
        if !d.held { GardenPlants.shadow(c, at: .zero, width: d.kind.size.width * 0.9) }
        c.rotate(by: .radians(Double(d.tilt)))
        c.scaleBy(x: 1 - d.squash * 0.08, y: 1 + d.squash * 0.12)
        switch d.kind {
        case .pinwheel: pinwheel(c, spin: d.spin)
        case .lantern: lantern(c, lit: d.lit, night: night, t: t)
        case .mushroom: mushroom(c)
        case .flamingo: flamingo(c, t: t)
        case .birdbath: birdbath(c, water: d.water, t: t)
        case .birdhouse: birdhouse(c, peek: CGFloat(Double(t) - d.poke), t: t)
        case .bunny: bunny(c)
        case .flag: flag(c, t: t, wind: wind)
        }
    }

    private static func stick(_ c: GraphicsContext, height: CGFloat, color: GRGB, width: CGFloat = 5) {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: 0, y: -height))
        c.stroke(p, with: .color(color.shade(-0.35).color), style: StrokeStyle(lineWidth: width + 2, lineCap: .round))
        c.stroke(p, with: .color(color.color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private static func pinwheel(_ c: GraphicsContext, spin: CGFloat) {
        stick(c, height: 120, color: GRGB(0xF4F0EA))
        var w = c
        w.translateBy(x: 0, y: -120)
        w.rotate(by: .radians(Double(spin)))
        let colors = [GRGB(0xFF7FAE), GRGB(0xFFD54A), GRGB(0x6FD3B0), GRGB(0x78B8FF)]
        for k in 0..<4 {
            var b = w
            b.rotate(by: .radians(Double(k) * .pi / 2))
            var blade = Path()
            blade.move(to: .zero)
            blade.addLine(to: CGPoint(x: 0, y: -34))
            blade.addQuadCurve(to: CGPoint(x: 22, y: -12), control: CGPoint(x: 24, y: -34))
            blade.closeSubpath()
            b.fill(blade, with: .linearGradient(Gradient(colors: [colors[k].shade(0.25).color, colors[k].shade(-0.15).color]),
                                                startPoint: CGPoint(x: 0, y: -34), endPoint: CGPoint(x: 20, y: -6)))
            b.stroke(blade, with: .color(colors[k].shade(-0.45).color), lineWidth: 1)
        }
        w.fill(Path(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10)), with: .color(.white))
        w.stroke(Path(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10)), with: .color(Color(hex: 0xC9B6FF)), lineWidth: 1.5)
    }

    private static func lantern(_ c: GraphicsContext, lit: Bool, night: CGFloat, t: CGFloat) {
        stick(c, height: 80, color: GRGB(0x4A4A5A), width: 5)
        var l = c
        l.translateBy(x: 0, y: -96)
        let glass = Path(roundedRect: CGRect(x: -15, y: -16, width: 30, height: 34), cornerRadius: 5)
        let flicker = 0.85 + 0.15 * sin(t * 13) * sin(t * 7.3)
        let warm = lit ? Color(hex: 0xFFE08A, alpha: 0.6 + 0.4 * Double(flicker)) : Color(hex: 0xC9D6DE, alpha: 0.6)
        l.fill(glass, with: .radialGradient(Gradient(colors: [warm, lit ? Color(hex: 0xFFAE3C, alpha: 0.85) : Color(hex: 0x9FB0BC, alpha: 0.7)]),
                                            center: CGPoint(x: 0, y: 2), startRadius: 0, endRadius: 22))
        l.stroke(glass, with: .color(Color(hex: 0x3A3A48)), lineWidth: 3)
        var bars = Path()
        bars.move(to: CGPoint(x: 0, y: -16))
        bars.addLine(to: CGPoint(x: 0, y: 18))
        l.stroke(bars, with: .color(Color(hex: 0x3A3A48)), lineWidth: 2)
        var roof = Path()
        roof.move(to: CGPoint(x: -20, y: -16))
        roof.addLine(to: CGPoint(x: 0, y: -32))
        roof.addLine(to: CGPoint(x: 20, y: -16))
        roof.closeSubpath()
        l.fill(roof, with: .color(Color(hex: 0x3A3A48)))
        l.fill(Path(ellipseIn: CGRect(x: -4, y: -40, width: 8, height: 8)), with: .color(Color(hex: 0x3A3A48)))
        l.fill(Path(roundedRect: CGRect(x: -18, y: 16, width: 36, height: 6), cornerRadius: 3), with: .color(Color(hex: 0x3A3A48)))
        if lit {
            l.fill(Path(ellipseIn: CGRect(x: -3.5, y: -4 - 2 * flicker, width: 7, height: 12 + 3 * flicker)), with: .color(Color(hex: 0xFFF6D0)))
        }
        _ = night
    }

    private static func mushroom(_ c: GraphicsContext) {
        var stem = Path()
        stem.move(to: CGPoint(x: -14, y: 0))
        stem.addQuadCurve(to: CGPoint(x: -11, y: -36), control: CGPoint(x: -18, y: -18))
        stem.addLine(to: CGPoint(x: 11, y: -36))
        stem.addQuadCurve(to: CGPoint(x: 14, y: 0), control: CGPoint(x: 18, y: -18))
        stem.closeSubpath()
        c.fill(stem, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF8EC), Color(hex: 0xE8D7BE)]),
                                           startPoint: CGPoint(x: -14, y: 0), endPoint: CGPoint(x: 14, y: 0)))
        c.stroke(stem, with: .color(Color(hex: 0xC9B193)), lineWidth: 1.2)
        // A tiny door.
        c.fill(Path(roundedRect: CGRect(x: -5, y: -18, width: 10, height: 18), cornerRadius: 5), with: .color(Color(hex: 0xB47A4A)))
        var cap = Path()
        cap.move(to: CGPoint(x: -38, y: -32))
        cap.addCurve(to: CGPoint(x: 38, y: -32), control1: CGPoint(x: -36, y: -82), control2: CGPoint(x: 36, y: -82))
        cap.addQuadCurve(to: CGPoint(x: -38, y: -32), control: CGPoint(x: 0, y: -24))
        cap.closeSubpath()
        c.fill(cap, with: .radialGradient(Gradient(colors: [Color(hex: 0xFF7A6B), Color(hex: 0xE23A30), Color(hex: 0xB0221C)]),
                                          center: CGPoint(x: -10, y: -62), startRadius: 0, endRadius: 50))
        c.stroke(cap, with: .color(Color(hex: 0x951A14)), lineWidth: 1.4)
        for d in [CGPoint(x: -20, y: -48), CGPoint(x: 4, y: -62), CGPoint(x: 22, y: -44), CGPoint(x: -4, y: -40)] {
            c.fill(Path(ellipseIn: CGRect(x: d.x - 5, y: d.y - 4, width: 10, height: 8)), with: .color(.white.opacity(0.95)))
        }
    }

    private static func flamingo(_ c: GraphicsContext, t: CGFloat) {
        let pink = GRGB(0xFF8DB4)
        var legs = Path()
        legs.move(to: CGPoint(x: -4, y: 0))
        legs.addLine(to: CGPoint(x: -2, y: -62))
        legs.move(to: CGPoint(x: 6, y: -34))
        legs.addLine(to: CGPoint(x: 16, y: -44))
        legs.addLine(to: CGPoint(x: 4, y: -62))
        c.stroke(legs, with: .color(pink.shade(-0.3).color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        let body = Path(ellipseIn: CGRect(x: -26, y: -92, width: 50, height: 34))
        c.fill(body, with: .radialGradient(Gradient(colors: [pink.shade(0.25).color, pink.color, pink.shade(-0.25).color]),
                                           center: CGPoint(x: -8, y: -82), startRadius: 0, endRadius: 34))
        var wing = Path()
        wing.move(to: CGPoint(x: -14, y: -80))
        wing.addQuadCurve(to: CGPoint(x: 18, y: -74), control: CGPoint(x: 6, y: -92))
        wing.addQuadCurve(to: CGPoint(x: -14, y: -80), control: CGPoint(x: 0, y: -66))
        c.fill(wing, with: .color(pink.shade(-0.15).color))
        var neck = Path()
        neck.move(to: CGPoint(x: -18, y: -84))
        neck.addCurve(to: CGPoint(x: -14, y: -128), control1: CGPoint(x: -36, y: -100), control2: CGPoint(x: 0, y: -110))
        c.stroke(neck, with: .color(pink.shade(-0.2).color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        c.stroke(neck, with: .color(pink.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: -22, y: -138, width: 16, height: 14)), with: .color(pink.color))
        var beak = Path()
        beak.move(to: CGPoint(x: -21, y: -131))
        beak.addQuadCurve(to: CGPoint(x: -32, y: -118), control: CGPoint(x: -32, y: -130))
        beak.addLine(to: CGPoint(x: -18, y: -127))
        beak.closeSubpath()
        c.fill(beak, with: .color(Color(hex: 0x3B2F2F)))
        let blink = sin(t * 0.7) > 0.97
        c.fill(Path(ellipseIn: CGRect(x: -14, y: -134, width: 3.2, height: blink ? 0.8 : 3.4)), with: .color(Color(hex: 0x3B2F2F)))
    }

    private static func birdbath(_ c: GraphicsContext, water: CGFloat, t: CGFloat) {
        let stone = GRGB(0xC9C4BE)
        var ped = Path()
        ped.move(to: CGPoint(x: -24, y: 0))
        ped.addLine(to: CGPoint(x: 24, y: 0))
        ped.addQuadCurve(to: CGPoint(x: 9, y: -54), control: CGPoint(x: 8, y: -16))
        ped.addLine(to: CGPoint(x: -9, y: -54))
        ped.addQuadCurve(to: CGPoint(x: -24, y: 0), control: CGPoint(x: -8, y: -16))
        ped.closeSubpath()
        c.fill(ped, with: .linearGradient(Gradient(colors: [stone.shade(0.2).color, stone.shade(-0.25).color]),
                                          startPoint: CGPoint(x: -24, y: 0), endPoint: CGPoint(x: 24, y: 0)))
        var bowl = Path()
        bowl.move(to: CGPoint(x: -50, y: -70))
        bowl.addQuadCurve(to: CGPoint(x: 50, y: -70), control: CGPoint(x: 0, y: -74))
        bowl.addQuadCurve(to: CGPoint(x: -50, y: -70), control: CGPoint(x: 0, y: -36))
        bowl.closeSubpath()
        c.fill(bowl, with: .linearGradient(Gradient(colors: [stone.shade(0.15).color, stone.shade(-0.3).color]),
                                           startPoint: CGPoint(x: 0, y: -72), endPoint: CGPoint(x: 0, y: -50)))
        c.stroke(bowl, with: .color(stone.shade(-0.45).color), lineWidth: 1.2)
        let rim = Path(ellipseIn: CGRect(x: -50, y: -77, width: 100, height: 14))
        c.fill(rim, with: .color(stone.shade(-0.35).color))
        if water > 0.02 {
            let w = 92 * (0.6 + 0.4 * water)
            let surf = Path(ellipseIn: CGRect(x: -w / 2, y: -75 + 2 * (1 - water), width: w, height: 10 * (0.6 + 0.4 * water)))
            c.fill(surf, with: .linearGradient(Gradient(colors: [Color(hex: 0xBFE6FA), Color(hex: 0x6FB2DC)]),
                                               startPoint: CGPoint(x: 0, y: -76), endPoint: CGPoint(x: 0, y: -66)))
            let gl = CGRect(x: -w * 0.3 + sin(t) * 4, y: -73, width: w * 0.25, height: 2.5)
            c.fill(Path(ellipseIn: gl), with: .color(.white.opacity(0.8)))
        }
        c.stroke(Path(ellipseIn: CGRect(x: -50, y: -77, width: 100, height: 14)), with: .color(stone.shade(0.25).color), lineWidth: 2.5)
    }

    private static func birdhouse(_ c: GraphicsContext, peek: CGFloat, t: CGFloat) {
        stick(c, height: 110, color: GRGB(0xB07642), width: 8)
        var h = c
        h.translateBy(x: 0, y: -130)
        let box = Path(roundedRect: CGRect(x: -26, y: -20, width: 52, height: 46), cornerRadius: 4)
        h.fill(box, with: .linearGradient(Gradient(colors: [Color(hex: 0xAEE3FF), Color(hex: 0x78C2EE)]),
                                          startPoint: CGPoint(x: -26, y: 0), endPoint: CGPoint(x: 26, y: 0)))
        h.stroke(box, with: .color(Color(hex: 0x4E8FBF)), lineWidth: 1.5)
        var roof = Path()
        roof.move(to: CGPoint(x: -36, y: -16))
        roof.addLine(to: CGPoint(x: 0, y: -44))
        roof.addLine(to: CGPoint(x: 36, y: -16))
        roof.closeSubpath()
        h.fill(roof, with: .linearGradient(Gradient(colors: [Color(hex: 0xFF8DA1), Color(hex: 0xE2526C)]),
                                           startPoint: CGPoint(x: 0, y: -44), endPoint: CGPoint(x: 0, y: -16)))
        h.stroke(roof, with: .color(Color(hex: 0xB43A52)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        h.fill(Path(ellipseIn: CGRect(x: -10, y: -8, width: 20, height: 20)), with: .color(Color(hex: 0x2E3C4A)))
        h.fill(Path(roundedRect: CGRect(x: -2, y: 16, width: 4, height: 9), cornerRadius: 2), with: .color(Color(hex: 0x8E5A30)))
        // A little bird pops its head out when tapped.
        if peek >= 0 && peek < 2.6 {
            let k = min(gdEase(peek / 0.25), gdEase((2.6 - peek) / 0.3))
            var b = h
            b.clip(to: Path(CGRect(x: -30, y: -60, width: 60, height: 72)))
            let y = 10 - 16 * k
            b.fill(Path(ellipseIn: CGRect(x: -9, y: y - 9, width: 18, height: 18)), with: .color(Color(hex: 0xFFC94A)))
            b.fill(Path(ellipseIn: CGRect(x: -4.5, y: y - 4, width: 3, height: 3.4)), with: .color(Color(hex: 0x2A2020)))
            b.fill(Path(ellipseIn: CGRect(x: 1.5, y: y - 4, width: 3, height: 3.4)), with: .color(Color(hex: 0x2A2020)))
            var beak = Path()
            beak.move(to: CGPoint(x: -3, y: y + 1))
            beak.addLine(to: CGPoint(x: 0, y: y + 6 + sin(t * 30) * 1.5))
            beak.addLine(to: CGPoint(x: 3, y: y + 1))
            beak.closeSubpath()
            b.fill(beak, with: .color(Color(hex: 0xFF8A3D)))
        }
    }

    private static func bunny(_ c: GraphicsContext) {
        let stone = GRGB(0xF2EEE8)
        for side in [-1.0, 1.0] as [CGFloat] {
            var ear = c
            ear.translateBy(x: side * 7, y: -58)
            ear.rotate(by: .radians(Double(side * 0.18)))
            let e = Path(ellipseIn: CGRect(x: -5, y: -28, width: 10, height: 30))
            ear.fill(e, with: .color(stone.shade(-0.05).color))
            ear.fill(Path(ellipseIn: CGRect(x: -2.5, y: -24, width: 5, height: 22)), with: .color(Color(hex: 0xFFC9D6)))
            ear.stroke(e, with: .color(stone.shade(-0.3).color), lineWidth: 1)
        }
        let body = Path(ellipseIn: CGRect(x: -24, y: -42, width: 48, height: 44))
        c.fill(body, with: .radialGradient(Gradient(colors: [stone.shade(0.3).color, stone.shade(-0.2).color]),
                                           center: CGPoint(x: -8, y: -30), startRadius: 0, endRadius: 40))
        c.stroke(body, with: .color(stone.shade(-0.35).color), lineWidth: 1)
        let head = Path(ellipseIn: CGRect(x: -17, y: -66, width: 34, height: 30))
        c.fill(head, with: .radialGradient(Gradient(colors: [stone.shade(0.35).color, stone.shade(-0.15).color]),
                                           center: CGPoint(x: -6, y: -58), startRadius: 0, endRadius: 26))
        c.stroke(head, with: .color(stone.shade(-0.35).color), lineWidth: 1)
        c.fill(Path(ellipseIn: CGRect(x: -8, y: -55, width: 3.5, height: 4)), with: .color(Color(hex: 0x3B2F2F)))
        c.fill(Path(ellipseIn: CGRect(x: 4.5, y: -55, width: 3.5, height: 4)), with: .color(Color(hex: 0x3B2F2F)))
        c.fill(Path(ellipseIn: CGRect(x: -2.5, y: -49, width: 5, height: 3.5)), with: .color(Color(hex: 0xFF9DB4)))
        c.fill(Path(ellipseIn: CGRect(x: -14, y: -50, width: 6, height: 4)), with: .color(Color(hex: 0xFFC9D6, alpha: 0.7)))
        c.fill(Path(ellipseIn: CGRect(x: 8, y: -50, width: 6, height: 4)), with: .color(Color(hex: 0xFFC9D6, alpha: 0.7)))
        c.fill(Path(ellipseIn: CGRect(x: 16, y: -16, width: 14, height: 14)), with: .color(.white))
    }

    private static func flag(_ c: GraphicsContext, t: CGFloat, wind: CGFloat) {
        stick(c, height: 130, color: GRGB(0xF4F0EA), width: 4)
        c.fill(Path(ellipseIn: CGRect(x: -5, y: -138, width: 10, height: 10)), with: .color(Color(hex: 0xFFD54A)))
        let amp = 4 + wind * 8
        let len = 56 + wind * 6
        var f = Path()
        f.move(to: CGPoint(x: 2, y: -126))
        var pts: [CGPoint] = []
        for k in 0...8 {
            let x = 2 + len * CGFloat(k) / 8
            let y = -126 + (CGFloat(k) / 8) * 16 + sin(t * (5 + wind * 5) - CGFloat(k) * 0.8) * amp * CGFloat(k) / 8
            pts.append(CGPoint(x: x, y: y))
        }
        for p in pts { f.addLine(to: p) }
        for p in pts.reversed() { f.addLine(to: CGPoint(x: p.x, y: p.y + 36 - (p.x - 2) / len * 36 * 0.85)) }
        f.closeSubpath()
        c.fill(f, with: .linearGradient(Gradient(colors: [Color(hex: 0xC9B6FF), Color(hex: 0xFF8FB8)]),
                                        startPoint: CGPoint(x: 0, y: -126), endPoint: CGPoint(x: len, y: -100)))
        c.stroke(f, with: .color(Color(hex: 0xA275D8, alpha: 0.6)), lineWidth: 1)
        c.fill(Twinkle().path(in: CGRect(x: 14, y: -120, width: 16, height: 16)), with: .color(.white.opacity(0.9)))
    }
}
