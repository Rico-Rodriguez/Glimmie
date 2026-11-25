import SwiftUI

enum GardenPainter {
    /// Full-bleed backdrop behind the 1024 x 834 garden canvas (sky, sun/moon, rainbow, hills, picket fence, lawns).
    static func drawBackdrop(_ ctx: GraphicsContext, map: GameStageMap, sim: GardenSim) {
        var g = ctx
        g.translateBy(x: map.origin.x, y: map.origin.y)
        g.scaleBy(x: map.scale, y: map.scale)
        let r = CGRect(
            x: -map.origin.x / map.scale,
            y: -map.origin.y / map.scale,
            width: map.size.width / map.scale,
            height: map.size.height / map.scale
        )
        let t = CGFloat(sim.time)
        sky(g, r, sim, t)
        hills(g, r, sim, t)
        fence(g, r, sim)
        backLawn(g, r, sim, t)
        frontLawn(g, r, sim, t)
        backdropAtmosphere(g, r, sim, t)
    }

    /// Interactive 1024 x 834 world drawn every frame over the backdrop.
    static func drawWorld(_ ctx: GraphicsContext, sim: GardenSim) {
        let g = ctx
        let t = CGFloat(sim.time)
        for d in sim.decor where !d.held {
            GardenDecorPainter.draw(g, d, time: t, night: sim.night, wind: sim.windNow)
        }
        visitors(g, sim, t, behind: true, flying: false)
        benchAndVase(g, sim, t)
        bedBackRim(g)
        soil(g, sim, t)
        worm(g, sim, t)
        plants(g, sim, t)
        visitors(g, sim, t, behind: false, flying: false)
        cedarBedFrame(g)
        frontGrass(g, sim, t)
        particles(g, sim, front: false)
        flyers(g, sim)
        bugs(g, sim, t)
        visitors(g, sim, t, behind: false, flying: true)
        surprisePops(g, sim)
        for d in sim.decor where d.held {
            GardenDecorPainter.draw(g, d, time: t, night: sim.night, wind: sim.windNow)
        }
        basket(g, sim)
        particles(g, sim, front: true)
        nightGlow(g, sim, t)
        hints(g, sim, t)
        tool(g, sim, t)
    }

    // MARK: Sky, hills, fence & lawns

    private static func sky(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        let grey = max(sim.rain, (sim.cloud - 0.12) * 0.45)
        let top = GRGB(0x74C6F5).mix(GRGB(0x7E8DA0), grey).mix(GRGB(0x263574), sim.night)
        let bottom = GRGB(0xDDF4FF).mix(GRGB(0xBAC6D2), grey).mix(GRGB(0x5E589E), sim.night)
        let rect = CGRect(x: r.minX, y: r.minY, width: r.width, height: 520 - r.minY)
        g.fill(Path(rect), with: .linearGradient(Gradient(colors: [top.color, bottom.color]),
                                                 startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: 450)))

        // Twinkling night stars and crescent moon (placed clear of the top bar).
        if sim.night > 0.01 {
            let n = Double(sim.night)
            let starA = n * Double(1 - sim.cloud * 0.7)
            var stars = [Path](repeating: Path(), count: 4)
            for i in 0..<64 {
                let x = r.minX + gdRand(i, 51) * r.width
                let y = max(r.minY + 12, 16) + gdRand(i, 52) * 320
                let tw = 0.5 + 0.5 * sin(t * (1.5 + gdRand(i, 53) * 2) + CGFloat(i))
                let s = 1.2 + gdRand(i, 54) * 1.9
                stars[min(3, Int(tw * 4))].addEllipse(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2))
            }
            for (k, p) in stars.enumerated() {
                g.fill(p, with: .color(.white.opacity(starA * (Double(k) + 0.5) / 4)))
            }
            let mc = CGPoint(x: 886, y: 162)
            g.fill(Path(ellipseIn: CGRect(x: mc.x - 104, y: mc.y - 104, width: 208, height: 208)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF8D6, alpha: 0.32 * n), Color.white.opacity(0)]),
                                         center: mc, startRadius: 18, endRadius: 104))
            var moon = Path(ellipseIn: CGRect(x: mc.x - 36, y: mc.y - 36, width: 72, height: 72))
            moon.addEllipse(in: CGRect(x: mc.x - 16, y: mc.y - 46, width: 72, height: 72))
            g.fill(moon, with: .color(Color(hex: 0xFFF6D0, alpha: n)), style: FillStyle(eoFill: true))
        }

        // Warm storybook sun with turning rays, fully visible below the top bar.
        let sunA = Double((1 - sim.rain) * (1 - sim.night) * (1 - (sim.cloud - 0.12) * 0.45))
        if sunA > 0.01 {
            let c = CGPoint(x: 886, y: 162)
            g.fill(Path(ellipseIn: CGRect(x: c.x - 150, y: c.y - 150, width: 300, height: 300)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF3B0, alpha: 0.55 * sunA), Color(hex: 0xFFF3B0, alpha: 0)]),
                                         center: c, startRadius: 28, endRadius: 150))
            var rays = Path()
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * 2 * .pi + t * 0.08
                rays.move(to: CGPoint(x: c.x + cos(a - 0.07) * 52, y: c.y + sin(a - 0.07) * 52))
                rays.addLine(to: CGPoint(x: c.x + cos(a) * 88, y: c.y + sin(a) * 88))
                rays.addLine(to: CGPoint(x: c.x + cos(a + 0.07) * 52, y: c.y + sin(a + 0.07) * 52))
                rays.closeSubpath()
            }
            g.fill(rays, with: .color(Color(hex: 0xFFE27A, alpha: 0.48 * sunA)))
            let disk = Path(ellipseIn: CGRect(x: c.x - 42, y: c.y - 42, width: 84, height: 84))
            g.fill(disk, with: .radialGradient(Gradient(colors: [Color(hex: 0xFFFBD6, alpha: sunA), Color(hex: 0xFFC93C, alpha: sunA)]),
                                               center: CGPoint(x: c.x - 10, y: c.y - 12), startRadius: 0, endRadius: 50))
            g.stroke(disk, with: .color(StorybookArt.outline(for: 0xFFC93C, factor: 0.8).opacity(0.45 * sunA)), lineWidth: 2)
        }

        // Rainbow arching gracefully across the upper sky after rain.
        let rb = sim.rainbow
        if rb > 0.01 {
            let colors: [UInt32] = [0xFF6B7B, 0xFFA64D, 0xFFE15A, 0x76D676, 0x62B8FF, 0x8585F2, 0xBC84EB]
            for (i, hex) in colors.enumerated() {
                let rad = CGFloat(456 - i * 12)
                var arc = Path()
                arc.addArc(center: CGPoint(x: 475, y: 556), radius: rad, startAngle: .degrees(196), endAngle: .degrees(344), clockwise: false)
                g.stroke(arc, with: .color(Color(hex: hex, alpha: 0.48 * Double(rb))), lineWidth: 12.5)
            }
        }

        // Fluffy drifting clouds positioned below the top chrome.
        let n = 4 + Int((sim.cloud * 5).rounded())
        let span = r.width + 500
        for i in 0..<n {
            let speed = 0.6 + 0.55 * gdRand(i, 2)
            let raw = gdRand(i, 1) * span + sim.cloudDrift * speed
            let x = r.minX - 240 + raw.truncatingRemainder(dividingBy: span)
            let y = 114 + gdRand(i, 3) * 145
            let size = (0.76 + 0.5 * gdRand(i, 4)) * (1 + sim.rain * 0.45)
            let extra = i >= 4 ? Double(min(1, max(0, sim.cloud * 5 - CGFloat(i - 4)))) : 1
            cloud(g, at: CGPoint(x: x, y: y), size: size, grey: sim.rain, night: sim.night, alpha: extra)
        }
    }

    private static func cloud(_ g: GraphicsContext, at c: CGPoint, size s: CGFloat, grey: CGFloat, night: CGFloat, alpha: Double) {
        guard alpha > 0.01 else { return }
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-54, 8, 32), (-20, -13, 42), (20, -20, 46), (58, -2, 36), (0, 11, 38), (-36, 16, 26), (38, 15, 28)]
        let top = GRGB(0xFFFFFF).mix(GRGB(0x9AA5B4), grey).mix(GRGB(0x8A8CC0), night * 0.8)
        let bottom = GRGB(0xE8F1FA).mix(GRGB(0x6E7A8C), grey).mix(GRGB(0x5E5E96), night * 0.8)
        var path = Path()
        for p in puffs {
            let rr = p.2 * s
            path.addEllipse(in: CGRect(x: c.x + p.0 * s - rr, y: c.y + p.1 * s - rr, width: rr * 2, height: rr * 2))
        }
        g.fill(path, with: .linearGradient(Gradient(colors: [top.color(alpha), bottom.color(alpha)]),
                                           startPoint: CGPoint(x: c.x, y: c.y - 64 * s), endPoint: CGPoint(x: c.x, y: c.y + 36 * s)))
    }

    private static func hills(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        let dusk = sim.night * 0.45
        let damp = sim.rain * 0.22
        var far = Path()
        far.move(to: CGPoint(x: r.minX, y: 520))
        var x = r.minX
        while x <= r.maxX + 20 {
            let y = 358 + sin(x * 0.0042 + 1) * 20 + sin(x * 0.011) * 6
            far.addLine(to: CGPoint(x: x, y: y))
            x += 16
        }
        far.addLine(to: CGPoint(x: r.maxX + 20, y: 520))
        far.closeSubpath()
        let farTop = GRGB(0xB8E6A4).mix(GRGB(0x70917B), damp).mix(GRGB(0x3D537B), dusk)
        let farBot = GRGB(0x9AD488).mix(GRGB(0x5E7E6C), damp).mix(GRGB(0x304568), dusk)
        g.fill(far, with: .linearGradient(Gradient(colors: [farTop.color, farBot.color]),
                                          startPoint: CGPoint(x: 0, y: 340), endPoint: CGPoint(x: 0, y: 440)))

        let trees: [CGFloat] = [-140, 88, 318, 604, 964, 1180]
        for (i, tx) in trees.enumerated() {
            let base = CGPoint(x: tx, y: 366 + sin(tx * 0.0042 + 1) * 20 + sin(tx * 0.011) * 6 + 6)
            let sway = sim.windNow * 9 + sin(t * 1.3 + CGFloat(i)) * 1.5
            let trunkCol = GRGB(0x9A6B45).mix(GRGB(0x473852), dusk)
            let trunk = Path(roundedRect: CGRect(x: base.x - 5, y: base.y - 44, width: 10, height: 48), cornerRadius: 4)
            g.fill(trunk, with: .color(trunkCol.color))
            let crown = GRGB(0x6DBA5C).mix(GRGB(0x4E7D5C), damp).mix(GRGB(0x33536A), dusk)
            for (k, o) in [(-17.0, -48.0, 24.0), (15.0, -52.0, 26.0), (0.0, -72.0, 28.0)].enumerated() {
                let c = CGPoint(x: base.x + CGFloat(o.0) + sway * (1 + CGFloat(k) * 0.3), y: base.y + CGFloat(o.1))
                let rr = CGFloat(o.2)
                let puff = Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2))
                g.fill(puff, with: .radialGradient(Gradient(colors: [crown.shade(0.18).color, crown.shade(-0.18).color]),
                                                   center: CGPoint(x: c.x - rr * 0.35, y: c.y - rr * 0.35), startRadius: 0, endRadius: rr * 1.3))
                g.stroke(puff, with: .color(crown.shade(-0.38).color(0.45)), lineWidth: 1.4)
            }
        }

        var near = Path()
        near.move(to: CGPoint(x: r.minX, y: 520))
        x = r.minX
        while x <= r.maxX + 20 {
            let y = 404 + sin(x * 0.006 + 2.4) * 14 + sin(x * 0.017 + 0.5) * 4.5
            near.addLine(to: CGPoint(x: x, y: y))
            x += 16
        }
        near.addLine(to: CGPoint(x: r.maxX + 20, y: 520))
        near.closeSubpath()
        let nearTop = GRGB(0xA3DC8E).mix(GRGB(0x668D72), damp).mix(GRGB(0x35506F), dusk)
        let nearBot = GRGB(0x88CB76).mix(GRGB(0x567B62), damp).mix(GRGB(0x2A435F), dusk)
        g.fill(near, with: .linearGradient(Gradient(colors: [nearTop.color, nearBot.color]),
                                           startPoint: CGPoint(x: 0, y: 390), endPoint: CGPoint(x: 0, y: 470)))
    }

    private static func fence(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim) {
        let dusk = sim.night * 0.42
        let paint = GRGB(0xFFFBF2).mix(GRGB(0x8D9AC4), dusk)
        let line = GRGB(0xD7C5B2).mix(GRGB(0x525B84), dusk)
        for y in [426.0, 456.0] as [CGFloat] {
            let rail = Path(CGRect(x: r.minX, y: y, width: r.width, height: 8))
            g.fill(rail, with: .color(paint.shade(-0.1).color))
            g.stroke(rail, with: .color(line.color(0.6)), lineWidth: 1.2)
        }
        var x = (r.minX / 30).rounded(.down) * 30
        while x < r.maxX {
            var p = Path()
            p.move(to: CGPoint(x: x, y: 478))
            p.addLine(to: CGPoint(x: x, y: 416))
            p.addLine(to: CGPoint(x: x + 9, y: GGeo.fenceTopY - 3))
            p.addLine(to: CGPoint(x: x + 18, y: 416))
            p.addLine(to: CGPoint(x: x + 18, y: 478))
            p.closeSubpath()
            g.fill(p, with: .linearGradient(Gradient(colors: [paint.color, paint.shade(-0.12).color]),
                                            startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + 18, y: 0)))
            g.stroke(p, with: .color(line.color(0.85)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            x += 30
        }
    }

    private static func backLawn(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        let dusk = sim.night * 0.44
        let damp = sim.rain * 0.2
        let top = GRGB(0x9ED976).mix(GRGB(0x6A9868), damp).mix(GRGB(0x335368), dusk)
        let bot = GRGB(0x7EC55E).mix(GRGB(0x568458), damp).mix(GRGB(0x28455C), dusk)
        g.fill(Path(CGRect(x: r.minX, y: 466, width: r.width, height: 140)),
               with: .linearGradient(Gradient(colors: [top.color, bot.color]),
                                     startPoint: CGPoint(x: 0, y: 466), endPoint: CGPoint(x: 0, y: 530)))
        grass(g, from: r.minX, to: r.maxX, y: 472, depth: 34, count: Int(r.width / 10), sim: sim, t: t, color: bot.shade(0.05), salt: 5)
    }

    private static func frontLawn(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        let dusk = sim.night * 0.45
        let damp = sim.rain * 0.2
        let top = GRGB(0x82CC5E).mix(GRGB(0x5B8A58), damp).mix(GRGB(0x2A475D), dusk)
        let bot = GRGB(0x63B148).mix(GRGB(0x467346), damp).mix(GRGB(0x1E364D), dusk)
        let rect = CGRect(x: r.minX, y: 590, width: r.width, height: max(260, r.maxY - 590))
        g.fill(Path(rect), with: .linearGradient(Gradient(colors: [top.color, bot.color]),
                                                 startPoint: CGPoint(x: 0, y: 590), endPoint: CGPoint(x: 0, y: 834)))

        // Soft clover flowers scattered across the front meadow.
        for i in 0..<18 {
            let x = r.minX + gdRand(i, 41) * r.width
            let y = 636 + gdRand(i, 42) * 184
            if abs(x - GGeo.basket.x) < 76 && y > 725 { continue }
            if abs(x - 512) < 210 && y > 716 { continue }
            let col = i % 3 == 0 ? GRGB(0xFFD1E3) : (i % 3 == 1 ? GRGB(0xFFFFFF) : GRGB(0xFFF3B8))
            GardenPlants.daisyHead(g, at: CGPoint(x: x, y: y), open: 1, color: col.mix(GRGB(0x7C84B5), dusk), size: 0.38, spin: CGFloat(i))
        }
    }

    private static func backdropAtmosphere(_ g: GraphicsContext, _ r: CGRect, _ sim: GardenSim, _ t: CGFloat) {
        if sim.rain > 0.01 {
            g.fill(Path(r), with: .color(GRGB(0x4A5566).color(0.16 * Double(sim.rain))))
            // Soft full-bleed rain streaks in the margins so wide screens stay seamless.
            var streaks = Path()
            let count = Int(32 * sim.rain)
            for i in 0..<count {
                let speed = 780 + gdRand(i, 71) * 260
                let x = r.minX + gdRand(i, 72) * r.width
                let y = r.minY + (gdRand(i, 73) * r.height + t * speed).truncatingRemainder(dividingBy: max(100, r.height))
                streaks.move(to: CGPoint(x: x, y: y))
                streaks.addLine(to: CGPoint(x: x - sim.windNow * 14 - 4, y: y - 22))
            }
            g.stroke(streaks, with: .color(GRGB(0xE4EEF8).color(0.32 * Double(sim.rain))), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    private static func grass(_ g: GraphicsContext, from x0: CGFloat, to x1: CGFloat, y: CGFloat, depth: CGFloat, count: Int,
                              sim: GardenSim, t: CGFloat, color: GRGB, salt: Int) {
        var dark = Path()
        var light = Path()
        for i in 0..<max(0, count) {
            let x = x0 + (x1 - x0) * gdRand(i, salt)
            let by = y + depth * gdRand(i, salt + 1)
            let len = 8 + 11 * gdRand(i, salt + 2)
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

    // MARK: Cedar Garden Bench & Live Bouquet Vase

    private static func benchAndVase(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let r = GGeo.benchRect
        // Soft ground shadow under the bench
        GardenPlants.shadow(g, at: CGPoint(x: r.midX, y: r.maxY + 34), width: r.width * 0.96)

        // Cedar bench legs
        let legColor: UInt32 = 0xB87946
        for lx in [r.minX + 16, r.maxX - 30] as [CGFloat] {
            let leg = Path(roundedRect: CGRect(x: lx, y: r.maxY - 2, width: 14, height: 36), cornerRadius: 4)
            StorybookArt.shape(g, leg, hex: legColor, width: 2.2)
        }
        // Lower crossbar
        let bar = Path(roundedRect: CGRect(x: r.minX + 24, y: r.maxY + 14, width: r.width - 48, height: 8), cornerRadius: 3)
        StorybookArt.shape(g, bar, hex: 0xC68752, width: 2)

        // Cedar seat planks
        let seat = Path(roundedRect: r, cornerRadius: 7)
        StorybookArt.shape(g, seat, hex: 0xDC9E64, width: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: r.minX + 10, y: r.minY + 3, width: r.width - 20, height: 4.5), opacity: 0.32)
        var slat = Path()
        slat.move(to: CGPoint(x: r.minX + 8, y: r.midY + 1))
        slat.addLine(to: CGPoint(x: r.maxX - 8, y: r.midY + 1))
        g.stroke(slat, with: .color(StorybookArt.outline(for: 0xDC9E64).opacity(0.45)), lineWidth: 1.5)

        // Bouquet Vase sitting on the cedar bench
        let vc = GGeo.vase
        var vg = g
        vg.translateBy(x: vc.x, y: vc.y)
        vg.scaleBy(x: 1 - sim.vaseBounce * 0.03, y: 1 + sim.vaseBounce * 0.05)

        GardenPlants.shadow(vg, at: CGPoint(x: 0, y: 2), width: 66)

        // Picked flowers fanned out of the vase neck
        let flowers = sim.bouquet
        let count = flowers.count
        for (idx, flower) in flowers.enumerated() {
            let spread: CGFloat = count <= 1 ? 0 : (CGFloat(idx) / CGFloat(count - 1) - 0.5) * 0.92
            let sway = sin(t * 1.9 + CGFloat(idx) * 1.1) * 0.04 + sim.windNow * 0.08
            let stemLen: CGFloat = 56 + (idx % 2 == 0 ? 12 : 0) - abs(spread) * 14
            var fg = vg
            fg.translateBy(x: spread * 14, y: -54)
            GardenPlants.drawBouquetStem(fg, kind: flower.kind, variant: flower.variant, angle: spread + sway, stemLength: stemLen)
        }

        // Glazed pastel ceramic vase body
        var vaseBody = Path()
        vaseBody.move(to: CGPoint(x: -16, y: -58))
        vaseBody.addCurve(to: CGPoint(x: -28, y: -22), control1: CGPoint(x: -14, y: -44), control2: CGPoint(x: -30, y: -38))
        vaseBody.addCurve(to: CGPoint(x: -18, y: 0), control1: CGPoint(x: -26, y: -8), control2: CGPoint(x: -22, y: 0))
        vaseBody.addLine(to: CGPoint(x: 18, y: 0))
        vaseBody.addCurve(to: CGPoint(x: 28, y: -22), control1: CGPoint(x: 22, y: 0), control2: CGPoint(x: 26, y: -8))
        vaseBody.addCurve(to: CGPoint(x: 16, y: -58), control1: CGPoint(x: 30, y: -38), control2: CGPoint(x: 14, y: -44))
        vaseBody.closeSubpath()
        let ceramicHex: UInt32 = 0xD6F1FF
        StorybookArt.fillAndStroke(vg, vaseBody, fill: StorybookArt.color(ceramicHex), stroke: StorybookArt.outline(for: ceramicHex), width: 2.6)

        // Soft glossy ceramic highlight
        StorybookArt.highlight(vg, in: CGRect(x: -20, y: -38, width: 9, height: 22), opacity: 0.65)
        // Cute pink rim & painted heart decal
        let rim = Path(roundedRect: CGRect(x: -21, y: -64, width: 42, height: 10), cornerRadius: 5)
        StorybookArt.shape(vg, rim, hex: 0xFFB0CE, width: 2.2)
        StorybookArt.heart(vg, at: CGPoint(x: 0, y: -26), size: 16, color: Theme.pink, opacity: 0.85)
    }

    // MARK: Raised Cedar Garden Bed & Soil

    private static func bedBackRim(_ g: GraphicsContext) {
        let rim = Path(roundedRect: CGRect(x: GGeo.bedLeft - 6, y: GGeo.soilY - 16, width: GGeo.bedRight - GGeo.bedLeft + 12, height: 20), cornerRadius: 6)
        StorybookArt.shape(g, rim, hex: 0xC6884E, width: 2.4)
        StorybookArt.highlight(g, in: CGRect(x: GGeo.bedLeft + 4, y: GGeo.soilY - 13, width: GGeo.bedRight - GGeo.bedLeft - 8, height: 4), opacity: 0.28)
    }

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
        g.fill(path, with: .linearGradient(Gradient(colors: [GRGB(0xAB7C50).color, GRGB(0x885B3B).color, GRGB(0x613E28).color]),
                                           startPoint: CGPoint(x: 0, y: GGeo.soilY - 24), endPoint: CGPoint(x: 0, y: GGeo.bedBottom)))
        var c = g
        c.clip(to: path)
        for k in 0..<2 {
            var band = Path()
            let y0 = GGeo.soilY + 26 + CGFloat(k) * 32
            band.move(to: CGPoint(x: GGeo.bedLeft, y: y0))
            var x = GGeo.bedLeft
            while x <= GGeo.bedRight {
                band.addLine(to: CGPoint(x: x, y: y0 + sin(x * 0.02 + CGFloat(k) * 2) * 5))
                x += 24
            }
            c.stroke(band, with: .color(Color.black.opacity(0.06)), lineWidth: 9)
        }
        var light = Path()
        var dark = Path()
        for i in 0..<260 {
            let x = GGeo.bedLeft + gdRand(i, 11) * (GGeo.bedRight - GGeo.bedLeft)
            let y = GGeo.soilY - 12 + gdRand(i, 12) * (GGeo.bedBottom - GGeo.soilY + 12)
            let s = 1.2 + gdRand(i, 13) * 2.1
            let r = CGRect(x: x, y: y, width: s, height: s * 0.8)
            if i % 2 == 0 { light.addEllipse(in: r) } else { dark.addEllipse(in: r) }
        }
        c.fill(light, with: .color(GRGB(0xD2AC80).color(0.45)))
        c.fill(dark, with: .color(GRGB(0x3E2414).color(0.38)))
        var shine = Path()
        for i in 0..<12 {
            let x = GGeo.bedLeft + 18 + gdRand(i, 21) * (GGeo.bedRight - GGeo.bedLeft - 36)
            let y = GGeo.soilY + 22 + gdRand(i, 22) * (GGeo.bedBottom - GGeo.soilY - 30)
            let w = 8 + gdRand(i, 23) * 11
            let rect = CGRect(x: x, y: y, width: w, height: w * 0.66)
            let stone = GRGB(0xB6A89B).mix(GRGB(0x908275), gdRand(i, 24))
            c.fill(Path(ellipseIn: rect), with: .color(stone.shade(-0.12).color))
            shine.addEllipse(in: CGRect(x: rect.minX + w * 0.18, y: rect.minY + w * 0.1, width: w * 0.45, height: w * 0.26))
        }
        c.fill(shine, with: .color(.white.opacity(0.28)))

        for i in sim.plots.indices {
            guard let p = sim.plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            GardenPlants.drawRoots(c, plant: p, base: CGPoint(x: x, y: sim.surface(x)), pull: sim.plots[i].pull, seed: i * 7)
        }
        for w in sim.weeds { GardenPlants.drawWeedRoot(c, weed: w, base: CGPoint(x: w.x, y: sim.surface(w.x))) }

        var soak = Path()
        soak.move(to: CGPoint(x: GGeo.bedLeft, y: sim.h[0]))
        for i in 0..<GGeo.columns { soak.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i] - 1)) }
        for i in (0..<GGeo.columns).reversed() {
            let w = min(1, sim.wet[i])
            soak.addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i] + 2 + w * 68))
        }
        soak.closeSubpath()
        c.fill(soak, with: .linearGradient(Gradient(colors: [GRGB(0x2A170C).color(0.6), GRGB(0x2A170C).color(0.24)]),
                                           startPoint: CGPoint(x: 0, y: GGeo.soilY - 12), endPoint: CGPoint(x: 0, y: GGeo.bedBottom)))

        // 6 cozy storybook soil mounds marking each plot clearly.
        for i in sim.plots.indices {
            let x = GGeo.plotX[i]
            let y = sim.surface(x)
            let w = min(1, sim.wetAt(x, span: 6))
            let pop = sim.plots[i].moundPop
            let mw: CGFloat = 76 + pop * 1.4
            let mh: CGFloat = 15 + pop * 0.8
            let moundColor = GRGB(0xB6875A).mix(GRGB(0x52311E), w * 0.85)
            let moundRect = CGRect(x: x - mw / 2, y: y - mh * 0.65, width: mw, height: mh)
            let mp = Path(ellipseIn: moundRect)
            g.fill(mp, with: .color(moundColor.color))
            g.stroke(mp, with: .color(moundColor.shade(-0.42).color(0.75)), lineWidth: 2)
        }

        let levels = 8
        var edge = [Path](repeating: Path(), count: levels)
        let seg = 4
        var i0 = 0
        while i0 < GGeo.columns - 1 {
            let i1 = min(GGeo.columns - 1, i0 + seg)
            var avg: CGFloat = 0
            for i in i0...i1 { avg += sim.wet[i] }
            avg /= CGFloat(i1 - i0 + 1)
            let level = min(levels - 1, Int((min(1, avg * 1.3) * CGFloat(levels - 1)).rounded()))
            edge[level].move(to: CGPoint(x: GGeo.colX(i0), y: sim.h[i0]))
            for i in (i0 + 1)...i1 { edge[level].addLine(to: CGPoint(x: GGeo.colX(i), y: sim.h[i])) }
            i0 = i1
        }
        for (k, line) in edge.enumerated() where !line.isEmpty {
            let col = GRGB(0xC29669).mix(GRGB(0x3D2618), CGFloat(k) / CGFloat(levels - 1))
            g.stroke(line, with: .color(col.color), style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
        }
        puddles(g, sim, t)
    }

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
            let level = deepest - min(7, 2 + extra * 36)
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
                g.fill(water, with: .linearGradient(Gradient(colors: [GRGB(0xBFE2F7).color(0.82), GRGB(0x6E9CBE).color(0.72)]),
                                                    startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: deepest)))
                var shine = Path()
                shine.move(to: CGPoint(x: GGeo.colX(i), y: level + 0.5))
                shine.addLine(to: CGPoint(x: lastX, y: level + 0.5))
                g.stroke(shine, with: .color(.white.opacity(0.7 + 0.2 * Double(sin(t * 3)))), lineWidth: 1.4)
            }
            i = j
        }
    }

    private static func worm(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let w = sim.worm
        let surf = sim.surface(w.x)
        let head = CGPoint(x: w.x, y: min(GGeo.bedBottom - 10, surf + w.depth * (1 - w.peek) - 18 * w.peek))
        let wiggleAmp: CGFloat = sim.time - w.wiggle < 1.3 ? 6 : 2.5
        var pts: [CGPoint] = []
        for j in 0..<11 {
            let k = CGFloat(j)
            let along = CGPoint(x: head.x - w.dir * k * 5.0 * (1 - w.peek * 0.85), y: head.y + k * 4.4 * w.peek)
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
        for j in stride(from: 2, to: 10, by: 2) {
            let p = pts[j]
            g.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 4, width: 3.2, height: 8)), with: .color(pink.shade(-0.25).color(0.6)))
        }
        let fx = head.x + w.dir * 1.5 * (1 - w.peek)
        for e in [-2.4, 2.4] as [CGFloat] {
            g.fill(Path(ellipseIn: CGRect(x: fx + e - 1.1, y: head.y - 2.6, width: 2.2, height: 2.6)), with: .color(GRGB(0x3A2430).color))
        }
        var smile = Path()
        smile.move(to: CGPoint(x: fx - 2, y: head.y + 1.2))
        smile.addQuadCurve(to: CGPoint(x: fx + 2, y: head.y + 1.2), control: CGPoint(x: fx, y: head.y + 3.2))
        g.stroke(smile, with: .color(GRGB(0x8A3A4A).color), lineWidth: 1)
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
            // Special rare variants glow and twinkle even as a tiny mystery sprout!
            if p.isSpecial {
                let hgt = GardenPlants.stemHeight(p)
                let center = CGPoint(x: base.x, y: base.y - max(18, hgt * 0.65))
                let auraR: CGFloat = 26 + 22 * CGFloat(p.growth)
                g.fill(Path(ellipseIn: CGRect(x: center.x - auraR, y: center.y - auraR, width: auraR * 2, height: auraR * 2)),
                       with: .radialGradient(Gradient(colors: [p.kind.specialColor.color(0.32), p.kind.specialColor.color(0)]),
                                             center: center, startRadius: 4, endRadius: auraR))
            }
            GardenPlants.draw(g, plant: p, base: base, bend: st.bend, pop: st.pop, pull: st.pull, time: t, droop: st.dry > 1.5)
            if p.isSpecial {
                let hgt = GardenPlants.stemHeight(p)
                let low = !p.kind.isFlower
                let c = low ? CGPoint(x: base.x + (p.kind == .pumpkin ? 12 : 0), y: base.y - max(24, hgt * 0.55))
                            : (sim.head(plot: i) ?? CGPoint(x: base.x, y: base.y - max(22, hgt)))
                GardenVisitorPainter.twinkles(g, around: c, radius: low ? 38 : 34, time: t + CGFloat(i), count: 3, alpha: 0.95)
            }
        }
    }

    private static func visitors(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat, behind: Bool, flying: Bool) {
        for v in sim.visitors where v.kind.behind == behind && (v.kind.flies && !v.kind.behind) == flying {
            GardenVisitorPainter.draw(g, v, time: t, night: sim.night, nowTime: sim.time)
        }
    }

    private static func cedarBedFrame(_ g: GraphicsContext) {
        let glassTop: CGFloat = GGeo.soilY - 6
        // Soft reflections on the cutaway front glass
        var sheen = Path()
        sheen.move(to: CGPoint(x: 130, y: GGeo.bedBottom))
        sheen.addLine(to: CGPoint(x: 196, y: glassTop))
        sheen.addLine(to: CGPoint(x: 234, y: glassTop))
        sheen.addLine(to: CGPoint(x: 168, y: GGeo.bedBottom))
        sheen.closeSubpath()
        sheen.move(to: CGPoint(x: 590, y: GGeo.bedBottom))
        sheen.addLine(to: CGPoint(x: 646, y: glassTop))
        sheen.addLine(to: CGPoint(x: 666, y: glassTop))
        sheen.addLine(to: CGPoint(x: 610, y: GGeo.bedBottom))
        sheen.closeSubpath()
        g.fill(sheen, with: .color(.white.opacity(0.09)))

        var edge = Path()
        edge.move(to: CGPoint(x: GGeo.bedLeft, y: glassTop))
        edge.addLine(to: CGPoint(x: GGeo.bedRight, y: glassTop))
        g.stroke(edge, with: .color(.white.opacity(0.45)), lineWidth: 2.2)

        // Storybook cedar corner posts & bottom beam with warm outlines
        let postHex: UInt32 = 0xCE8E56
        let capHex: UInt32 = 0xE2AA72
        for x in [32.0, 816.0] as [CGFloat] {
            let post = Path(roundedRect: CGRect(x: x, y: 498, width: 24, height: 122), cornerRadius: 6)
            StorybookArt.shape(g, post, hex: postHex, width: 2.6)
            StorybookArt.highlight(g, in: CGRect(x: x + 4, y: 514, width: 5, height: 90), opacity: 0.24)
            let cap = Path(roundedRect: CGRect(x: x - 4, y: 492, width: 32, height: 12), cornerRadius: 5)
            StorybookArt.shape(g, cap, hex: capHex, width: 2.4)
        }
        let beam = Path(roundedRect: CGRect(x: 32, y: GGeo.bedBottom - 6, width: 808, height: 22), cornerRadius: 7)
        StorybookArt.shape(g, beam, hex: 0xD4955C, width: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: 46, y: GGeo.bedBottom - 3, width: 780, height: 4.5), opacity: 0.28)
        var grain = Path()
        grain.move(to: CGPoint(x: 52, y: GGeo.bedBottom + 6))
        grain.addQuadCurve(to: CGPoint(x: 820, y: GGeo.bedBottom + 7), control: CGPoint(x: 436, y: GGeo.bedBottom + 3))
        g.stroke(grain, with: .color(StorybookArt.outline(for: 0xD4955C).opacity(0.38)), lineWidth: 1.3)
    }

    private static func frontGrass(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let dusk = sim.night * 0.44
        let col = GRGB(0x74C054).mix(GRGB(0x28455C), dusk)
        grass(g, from: 20, to: 1004, y: GGeo.bedBottom + 14, depth: 10, count: 130, sim: sim, t: t, color: col, salt: 31)
    }

    // MARK: Particles, flyers & surprise pops

    private static func particles(_ g: GraphicsContext, _ sim: GardenSim, front: Bool) {
        var waterThin = Path()
        var waterThick = Path()
        var rain = Path()
        var splash = Path()
        var seeds: [(color: GRGB, level: Int, body: Path, stripe: Path)] = []
        for q in sim.particles {
            let life = Double(max(0, 1 - q.age / q.life))
            switch q.kind {
            case .water where !front:
                let tail = CGPoint(x: q.p.x - q.v.dx * 0.022, y: q.p.y - q.v.dy * 0.022)
                if q.size < 4 {
                    waterThin.move(to: q.p)
                    waterThin.addLine(to: tail)
                } else {
                    waterThick.move(to: q.p)
                    waterThick.addLine(to: tail)
                }
            case .rain where front:
                rain.move(to: q.p)
                rain.addLine(to: CGPoint(x: q.p.x - q.v.dx * 0.018, y: q.p.y - q.v.dy * 0.018))
            case .splash where !front:
                splash.addEllipse(in: CGRect(x: q.p.x - q.size, y: q.p.y - q.size, width: q.size * 2, height: q.size * 2))
            case .clod where !front:
                clod(g, q)
            case .seed where !front:
                let a = q.resting ? min(1, life * 1.5) : 1
                let level = min(4, Int((a * 4).rounded()))
                guard level > 0 else { continue }
                let m = CGAffineTransform(translationX: q.p.x, y: q.p.y).rotated(by: q.rot)
                let r = CGRect(x: -q.size, y: -q.size * 0.6, width: q.size * 2, height: q.size * 1.2)
                let k: Int
                if let found = seeds.firstIndex(where: { $0.color == q.color && $0.level == level }) {
                    k = found
                } else {
                    seeds.append((q.color, level, Path(), Path()))
                    k = seeds.count - 1
                }
                seeds[k].body.addPath(Path(ellipseIn: r), transform: m)
                if q.seed == .sunflower {
                    seeds[k].stripe.addPath(Path(CGRect(x: -q.size * 0.8, y: -0.5, width: q.size * 1.6, height: 1)), transform: m)
                }
            case .dust where !front:
                let r = CGRect(x: q.p.x - q.size, y: q.p.y - q.size, width: q.size * 2, height: q.size * 2)
                g.fill(Path(ellipseIn: r), with: .color(q.color.color(0.14 * life)))
                g.fill(Path(ellipseIn: r.insetBy(dx: q.size * 0.45, dy: q.size * 0.45)), with: .color(q.color.color(0.2 * life)))
            case .ripple where !front:
                let r = CGRect(x: q.p.x - q.size * 2, y: q.p.y - q.size * 0.5, width: q.size * 4, height: q.size)
                g.stroke(Path(ellipseIn: r), with: .color(.white.opacity(0.8 * life)), lineWidth: 1)
            case .sparkle where front:
                let s = q.size * CGFloat(0.4 + 0.6 * life)
                StorybookArt.sparkle(g, at: q.p, radius: s, color: q.color.color, opacity: life)
            case .heart where front:
                let s = q.size * CGFloat(0.65 + 0.35 * sin(CGFloat(1 - life) * .pi))
                StorybookArt.heart(g, at: q.p, size: s, color: q.color.color, opacity: min(1, life * 1.5))
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
            let body = GraphicsContext.Shading.color(GRGB(0x9FD3FA).color(0.84))
            let core = GraphicsContext.Shading.color(.white.opacity(0.75))
            if !waterThin.isEmpty {
                g.stroke(waterThin, with: body, style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
                g.stroke(waterThin, with: core, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
            if !waterThick.isEmpty {
                g.stroke(waterThick, with: body, style: StrokeStyle(lineWidth: 4.6, lineCap: .round))
                g.stroke(waterThick, with: core, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
            if !splash.isEmpty { g.fill(splash, with: .color(GRGB(0xD6EEFF).color(0.85))) }
            for sd in seeds {
                let a = Double(sd.level) / 4
                g.fill(sd.body, with: .color(sd.color.color(a)))
                if !sd.stripe.isEmpty { g.fill(sd.stripe, with: .color(.white.opacity(0.7 * a))) }
            }
        } else if !rain.isEmpty {
            g.stroke(rain, with: .color(GRGB(0xE4EEF8).color(0.55)), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
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
            case .crop(let kind, let v, let giant):
                let s = 1 + 0.25 * sin(min(1, k / CGFloat(f.dur)) * .pi)
                GardenPlants.drawCrop(g, kind: kind, variant: v, at: p, size: s, rot: rot, giant: giant)
            case .flowerToVase(let kind, let v):
                let s = 1 + 0.25 * sin(min(1, k / CGFloat(f.dur)) * .pi)
                GardenPlants.drawCrop(g, kind: kind, variant: v, at: p, size: s, rot: rot)
            case .flyingSeed(let kind, _):
                var sg = g
                sg.translateBy(x: p.x, y: p.y)
                sg.rotate(by: .radians(Double(rot)))
                let r = CGRect(x: -7, y: -5, width: 14, height: 10)
                StorybookArt.fillAndStroke(sg, Path(ellipseIn: r), fill: kind.seedColor.color, stroke: kind.seedColor.shade(-0.45).color, width: 1.5)
                StorybookArt.sparkle(g, at: CGPoint(x: p.x - 10, y: p.y + 4), radius: 5, color: Theme.lemon, opacity: 0.85)
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
            }
        }
    }

    private static func surprisePops(_ g: GraphicsContext, _ sim: GardenSim) {
        for pop in sim.surprisePops {
            let u = CGFloat((sim.time - pop.start) / pop.dur)
            guard u >= 0 && u < 1 else { continue }
            let rise = gdEase(min(1, u / 0.55)) * 56
            let alpha = Double(u > 0.7 ? (1 - u) / 0.3 : min(1, u / 0.15))
            let c = CGPoint(x: pop.origin.x, y: pop.origin.y - rise)
            var pg = g
            pg.opacity = alpha
            let ring = Path(ellipseIn: CGRect(x: c.x - 22, y: c.y - 22, width: 44, height: 44))
            StorybookArt.fillAndStroke(pg, ring, fill: Theme.cream, stroke: Theme.lemon, width: 3)
            switch pop.surprise {
            case .coins:
                for ox in [-7.0, 7.0] as [CGFloat] {
                    let coin = Path(ellipseIn: CGRect(x: c.x + ox - 9, y: c.y - 9, width: 18, height: 18))
                    StorybookArt.shape(pg, coin, hex: 0xFFD042, width: 2)
                    StorybookArt.sparkle(pg, at: CGPoint(x: c.x + ox, y: c.y), radius: 5, color: .white, opacity: 0.9)
                }
            case .mysteryBulb:
                StorybookArt.sparkle(pg, at: c, radius: 14, color: Theme.pink, opacity: 1)
                StorybookArt.sparkle(pg, at: c, radius: 7, color: .white, opacity: 1)
            case .worm:
                var body = Path()
                body.move(to: CGPoint(x: c.x - 10, y: c.y + 6))
                body.addQuadCurve(to: CGPoint(x: c.x + 10, y: c.y - 4), control: CGPoint(x: c.x, y: c.y - 10))
                pg.stroke(body, with: .color(Color(hex: 0xF298A8)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            case .ladybug:
                let shell = Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 8, width: 18, height: 16))
                StorybookArt.shape(pg, shell, hex: 0xEE3A32, width: 2)
                pg.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 3, width: 3, height: 3)), with: .color(Color(hex: 0x2A2020)))
                pg.fill(Path(ellipseIn: CGRect(x: c.x + 2, y: c.y - 1, width: 3, height: 3)), with: .color(Color(hex: 0x2A2020)))
            }
        }
    }

    // MARK: Bugs

    static let wingLooks: [(GRGB, GRGB)] = [
        (GRGB(0xFF7FB0), GRGB(0xFFD6E6)),
        (GRGB(0x6FB5FF), GRGB(0xD6ECFF)),
        (GRGB(0xFFA43A), GRGB(0xFFE49A)),
        (GRGB(0xA77CFF), GRGB(0xE6DAFF)),
        (GRGB(0x4FCFAE), GRGB(0xD3F5EA)),
    ]

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

    // MARK: Woven Harvest Basket

    private static func basket(_ g: GraphicsContext, _ sim: GardenSim) {
        let c = GGeo.basket
        var b = g
        b.translateBy(x: c.x, y: c.y + 28)
        b.scaleBy(x: 1 - sim.basketBounce * 0.03, y: 1 + sim.basketBounce * 0.05)
        b.translateBy(x: 0, y: -28)
        let wicker = GRGB(0xDAA05C)
        GardenPlants.shadow(b, at: CGPoint(x: 0, y: 28), width: 126)
        var handle = Path()
        handle.move(to: CGPoint(x: -48, y: -10))
        handle.addCurve(to: CGPoint(x: 48, y: -10), control1: CGPoint(x: -44, y: -54), control2: CGPoint(x: 44, y: -54))
        b.stroke(handle, with: .color(StorybookArt.outline(for: 0xDAA05C)), style: StrokeStyle(lineWidth: 10.5, lineCap: .round))
        b.stroke(handle, with: .color(wicker.color), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        b.fill(Path(ellipseIn: CGRect(x: -56, y: -20, width: 112, height: 20)), with: .color(wicker.shade(-0.42).color))

        let items = sim.basket.suffix(12)
        for (k, name) in items.enumerated() {
            let parts = name.split(separator: ":")
            guard let kind = PlantKind(rawValue: String(parts.first ?? "")) else { continue }
            let v = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
            let row = k / 4
            let col = k % 4
            let x = -34 + CGFloat(col) * 22 + (row % 2 == 0 ? 0 : 9)
            let y = -11 - CGFloat(row) * 12
            GardenPlants.drawCrop(b, kind: kind, variant: v, at: CGPoint(x: x, y: y), size: 0.58, rot: (gdRand(k, 9) - 0.5) * 0.8)
        }

        var front = Path()
        front.move(to: CGPoint(x: -56, y: -10))
        front.addQuadCurve(to: CGPoint(x: 56, y: -10), control: CGPoint(x: 0, y: 2))
        front.addLine(to: CGPoint(x: 44, y: 28))
        front.addQuadCurve(to: CGPoint(x: -44, y: 28), control: CGPoint(x: 0, y: 36))
        front.closeSubpath()
        b.fill(front, with: .linearGradient(Gradient(colors: [wicker.shade(0.14).color, wicker.shade(-0.22).color]),
                                            startPoint: CGPoint(x: 0, y: -10), endPoint: CGPoint(x: 0, y: 32)))
        var weave = b
        weave.clip(to: front)
        for k in 0..<5 {
            var row = Path()
            let y = -3 + CGFloat(k) * 7.5
            row.move(to: CGPoint(x: -58, y: y))
            var x: CGFloat = -58
            while x < 58 {
                row.addQuadCurve(to: CGPoint(x: x + 12, y: y), control: CGPoint(x: x + 6, y: y + (k % 2 == 0 ? 3.5 : -3.5)))
                x += 12
            }
            weave.stroke(row, with: .color(wicker.shade(-0.38).color(0.55)), lineWidth: 1.4)
        }
        b.stroke(front, with: .color(StorybookArt.outline(for: 0xDAA05C)), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        let rim = Path(roundedRect: CGRect(x: -59, y: -15, width: 118, height: 9), cornerRadius: 4.5)
        StorybookArt.shape(b, rim, hex: 0xE2AA66, width: 2.2)
    }

    // MARK: Night glows & pictorial hints

    private static func nightGlow(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        guard sim.night > 0.01 else { return }
        let n = Double(sim.night)
        var glow = g
        glow.blendMode = .plusLighter
        for i in sim.plots.indices {
            guard let p = sim.plots[i].plant, p.isSpecial, p.kind == .daisy, p.growth > 0.3,
                  let c = sim.head(plot: i) else { continue }
            let r: CGFloat = 52
            glow.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                      with: .radialGradient(Gradient(colors: [p.kind.specialColor.color(0.75 * n), p.kind.specialColor.color(0)]),
                                            center: c, startRadius: 6, endRadius: r))
        }
        for d in sim.decor where d.kind == .lantern && d.lit {
            let c = CGPoint(x: d.x, y: d.y - 96)
            let a = 0.28 + 0.72 * n
            glow.fill(Path(ellipseIn: CGRect(x: c.x - 86, y: c.y - 86, width: 172, height: 172)),
                      with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC766, alpha: 0.55 * a), Color(hex: 0xFFC766, alpha: 0)]),
                                            center: c, startRadius: 4, endRadius: 86))
        }
        for d in sim.decor where d.kind == .lotus {
            let c = CGPoint(x: d.x, y: d.y - 64)
            let pulse = 0.9 + 0.1 * sin(t * 2.4 + CGFloat(d.id))
            let a = (0.34 + 0.66 * n) * Double(pulse)
            glow.fill(Path(ellipseIn: CGRect(x: c.x - 98, y: c.y - 98, width: 196, height: 196)),
                      with: .radialGradient(
                          Gradient(colors: [
                              Color(hex: 0xFFE3A8, alpha: 0.56 * a),
                              Color(hex: 0xFFB0D6, alpha: 0.34 * a),
                              Color(hex: 0xFFB0D6, alpha: 0),
                          ]),
                          center: c, startRadius: 6, endRadius: 98))
        }
        for (i, f) in sim.fireflies.enumerated() {
            let pulse = 0.5 + 0.5 * sin(f.phase * 3 + CGFloat(i))
            let a = n * Double(pulse)
            glow.fill(Path(ellipseIn: CGRect(x: f.p.x - 16, y: f.p.y - 16, width: 32, height: 32)),
                      with: .radialGradient(Gradient(colors: [Color(hex: 0xE6FF7A, alpha: 0.72 * a), Color(hex: 0xE6FF7A, alpha: 0)]),
                                            center: f.p, startRadius: 0, endRadius: 16))
            glow.fill(Path(ellipseIn: CGRect(x: f.p.x - 2.4, y: f.p.y - 2.4, width: 4.8, height: 4.8)), with: .color(Color(hex: 0xFAFFD0, alpha: a)))
        }
    }

    private static func hints(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        let pulse = 0.5 + 0.5 * sin(t * 4)
        var spots: [Int] = []
        switch sim.tool {
        case .shovel?:
            spots = sim.plots.indices.filter { sim.plots[$0].plant == nil && sim.plots[$0].surpriseReady }
        case .seeds?:
            spots = sim.plots.indices.filter { sim.plots[$0].plant == nil }
        default: break
        }
        for i in spots {
            let x = GGeo.plotX[i]
            let y = sim.surface(x)
            let r = CGRect(x: x - 32 - 5 * pulse, y: y - 9 - 2 * pulse, width: 64 + 10 * pulse, height: 18 + 4 * pulse)
            g.stroke(Path(ellipseIn: r), with: .color(.white.opacity(0.88 - 0.35 * Double(pulse))),
                     style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 6]))
        }

        for i in sim.plots.indices {
            guard let p = sim.plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let top = sim.surface(x) - GardenPlants.stemHeight(p)
            if sim.plots[i].dry > 1.5 && p.growth < 1 {
                let a = Double(min(1, (sim.plots[i].dry - 1.5) * 2))
                let c = CGPoint(x: x + 18, y: max(112, top - 32) + sin(t * 3.2 + CGFloat(i)) * 5)
                let badge = Path(ellipseIn: CGRect(x: c.x - 19, y: c.y - 19, width: 38, height: 38))
                g.fill(badge, with: .color(.white.opacity(0.92 * a)))
                g.stroke(badge, with: .color(Theme.sky.opacity(0.8 * a)), lineWidth: 2.5)
                var drop = Path()
                drop.move(to: CGPoint(x: c.x, y: c.y - 12))
                drop.addCurve(to: CGPoint(x: c.x, y: c.y + 10), control1: CGPoint(x: c.x + 5, y: c.y - 4), control2: CGPoint(x: c.x + 10, y: c.y + 10))
                drop.addCurve(to: CGPoint(x: c.x, y: c.y - 12), control1: CGPoint(x: c.x - 10, y: c.y + 10), control2: CGPoint(x: c.x - 5, y: c.y - 4))
                g.fill(drop, with: .linearGradient(Gradient(colors: [Color(hex: 0x9FD8FF, alpha: a), Color(hex: 0x3F8FE0, alpha: a)]),
                                                   startPoint: CGPoint(x: c.x, y: c.y - 12), endPoint: CGPoint(x: c.x, y: c.y + 10)))
                g.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y, width: 3.2, height: 4.8)), with: .color(.white.opacity(0.85 * a)))
            } else if p.growth >= 1 && p.left > 0 && sim.tool == nil {
                let tw = max(0, sin(t * 2.5 + CGFloat(i) * 1.7))
                if tw > 0.12 {
                    StorybookArt.sparkle(g, at: CGPoint(x: x + 22, y: top - 6), radius: 9 * tw, color: .white, opacity: 0.95)
                }
                if p.kind == .carrot && !sim.plots[i].held {
                    let liftY = top - 20 - sin(t * 3.6 + CGFloat(i)) * 5
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: x - 8, y: liftY + 6))
                    arrow.addLine(to: CGPoint(x: x, y: liftY - 4))
                    arrow.addLine(to: CGPoint(x: x + 8, y: liftY + 6))
                    g.stroke(arrow, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    // MARK: Carried tools

    private static func tool(_ g: GraphicsContext, _ sim: GardenSim, _ t: CGFloat) {
        if let tl = sim.tool {
            drawTool(g, tl, at: sim.toolP, tilt: sim.tilt, load: sim.load, time: t, hand: sim.hold)
        }
        if let r = sim.returning {
            let k = gdEase(CGFloat(sim.time - r.start) / 0.32)
            if k < 1 {
                let p = CGPoint(x: r.from.x + (r.to.x - r.from.x) * k, y: r.from.y + (r.to.y - r.from.y) * k - 56 * sin(k * .pi))
                var sg = g
                sg.opacity = Double(1 - k * 0.3)
                drawTool(sg, r.tool, at: p, tilt: r.tilt * (1 - k), load: 0, time: t)
            }
        }
    }

    static func drawTool(_ g: GraphicsContext, _ tool: GardenTool, at p: CGPoint, tilt: CGFloat, load: CGFloat, time: CGFloat,
                         hand: CGPoint? = nil) {
        var c = g
        c.translateBy(x: p.x, y: p.y)
        switch tool {
        case .shovel:
            var a: Double = 0
            if let h = hand { a = FingerLift.turn(tip: .zero, center: CGPoint(x: 0, y: -100), finger: h, lifted: p) }
            c.rotate(by: .radians(a + Double(tilt)))
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
        c.stroke(shaft, with: .color(StorybookArt.outline(for: 0xD39A62)), style: StrokeStyle(lineWidth: 11.5, lineCap: .round))
        c.stroke(shaft, with: .color(GRGB(0xD39A62).color), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        let grip = Path(roundedRect: CGRect(x: -24, y: -192, width: 48, height: 22), cornerRadius: 11)
        c.fill(grip, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFB3CF), Color(hex: 0xFF7FAE)]),
                                           startPoint: CGPoint(x: 0, y: -192), endPoint: CGPoint(x: 0, y: -170)))
        c.stroke(grip, with: .color(StorybookArt.outline(for: 0xFF7FAE)), lineWidth: 2)
        var blade = Path()
        blade.move(to: CGPoint(x: 0, y: 4))
        blade.addCurve(to: CGPoint(x: -22, y: -40), control1: CGPoint(x: -14, y: 0), control2: CGPoint(x: -24, y: -18))
        blade.addLine(to: CGPoint(x: -20, y: -58))
        blade.addQuadCurve(to: CGPoint(x: 20, y: -58), control: CGPoint(x: 0, y: -50))
        blade.addLine(to: CGPoint(x: 22, y: -40))
        blade.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: 24, y: -18), control2: CGPoint(x: 14, y: 0))
        c.fill(blade, with: .linearGradient(Gradient(colors: [Color(hex: 0xEEF3F7), Color(hex: 0xB4C0CB), Color(hex: 0x86939F)]),
                                            startPoint: CGPoint(x: -22, y: -40), endPoint: CGPoint(x: 22, y: 0)))
        c.stroke(blade, with: .color(StorybookArt.outline(for: 0x9AA8B5)), lineWidth: 2)
        var shine = Path()
        shine.move(to: CGPoint(x: -12, y: -46))
        shine.addQuadCurve(to: CGPoint(x: -6, y: -8), control: CGPoint(x: -16, y: -24))
        c.stroke(shine, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        if load > 1 {
            let s = min(1.35, sqrt(load / 550))
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
        var spout = Path()
        spout.move(to: CGPoint(x: -34, y: 70))
        spout.addLine(to: CGPoint(x: -104, y: -2))
        spout.addLine(to: CGPoint(x: -98, y: -10))
        spout.addLine(to: CGPoint(x: -30, y: 50))
        spout.closeSubpath()
        c.fill(spout, with: .linearGradient(Gradient(colors: [teal.shade(0.1).color, teal.shade(-0.28).color]),
                                            startPoint: CGPoint(x: -100, y: -10), endPoint: CGPoint(x: -96, y: 4)))
        c.stroke(spout, with: .color(StorybookArt.outline(for: 0x4FC0A8)), lineWidth: 1.8)
        var rose = c
        rose.translateBy(x: -110, y: -8)
        rose.rotate(by: .radians(-0.85))
        let face = Path(ellipseIn: CGRect(x: -6, y: -13, width: 12, height: 26))
        rose.fill(face, with: .linearGradient(Gradient(colors: [Color(hex: 0xE9EEF2), Color(hex: 0x9AA7B2)]),
                                              startPoint: CGPoint(x: 0, y: -13), endPoint: CGPoint(x: 0, y: 13)))
        rose.stroke(face, with: .color(Color(hex: 0x6D7A86)), lineWidth: 1.4)
        for k in -2...2 {
            rose.fill(Path(ellipseIn: CGRect(x: -1.4, y: CGFloat(k) * 4.4 - 1.2, width: 2.4, height: 2.4)), with: .color(Color(hex: 0x52606C)))
        }
        var handle = Path()
        handle.move(to: CGPoint(x: -26, y: 30))
        handle.addCurve(to: CGPoint(x: 40, y: 30), control1: CGPoint(x: -24, y: -14), control2: CGPoint(x: 38, y: -14))
        c.stroke(handle, with: .color(StorybookArt.outline(for: 0x4FC0A8)), style: StrokeStyle(lineWidth: 12.5, lineCap: .round))
        c.stroke(handle, with: .color(teal.color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        let body = Path(roundedRect: CGRect(x: -38, y: 26, width: 88, height: 80), cornerRadius: 18)
        c.fill(body, with: .linearGradient(Gradient(colors: [teal.shade(0.3).color, teal.color, teal.shade(-0.28).color]),
                                           startPoint: CGPoint(x: -38, y: 30), endPoint: CGPoint(x: 50, y: 100)))
        c.stroke(body, with: .color(StorybookArt.outline(for: 0x4FC0A8)), lineWidth: 2)
        c.fill(Path(roundedRect: CGRect(x: -38, y: 44, width: 88, height: 10), cornerRadius: 3), with: .color(teal.shade(-0.18).color))
        c.fill(Path(roundedRect: CGRect(x: -28, y: 60, width: 10, height: 38), cornerRadius: 5), with: .color(.white.opacity(0.35)))
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
        c.stroke(bag, with: .color(paper.shade(-0.45).color), lineWidth: 1.8)
        let window = Path(roundedRect: CGRect(x: -22, y: -28, width: 44, height: 46), cornerRadius: 10)
        c.fill(window, with: .color(.white.opacity(0.88)))
        GardenPlants.drawCrop(c, kind: kind, variant: 0, at: CGPoint(x: 0, y: -4), size: kind == .pumpkin ? 0.62 : 0.9, rot: 0)
        c.fill(Path(roundedRect: CGRect(x: -30, y: 24, width: 60, height: 10), cornerRadius: 2), with: .color(band.color))
        for k in 0..<3 {
            let r = CGRect(x: -12 + CGFloat(k) * 9, y: 26.5, width: 5, height: 4)
            c.fill(Path(ellipseIn: r), with: .color(kind.seedColor.shade(0.1).color))
        }
    }
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
        case .crystal: TreasureArt.crystals(c, glow: night)
        case .rainbow: TreasureArt.rainbow(c)
        case .unicorn: TreasureArt.unicorn(c)
        case .lotus: lotus(c, night: night, t: t)
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
            b.stroke(blade, with: .color(colors[k].shade(-0.45).color), lineWidth: 1.4)
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
        c.stroke(stem, with: .color(Color(hex: 0xC9B193)), lineWidth: 1.6)
        c.fill(Path(roundedRect: CGRect(x: -5, y: -18, width: 10, height: 18), cornerRadius: 5), with: .color(Color(hex: 0xB47A4A)))
        var cap = Path()
        cap.move(to: CGPoint(x: -38, y: -32))
        cap.addCurve(to: CGPoint(x: 38, y: -32), control1: CGPoint(x: -36, y: -82), control2: CGPoint(x: 36, y: -82))
        cap.addQuadCurve(to: CGPoint(x: -38, y: -32), control: CGPoint(x: 0, y: -24))
        cap.closeSubpath()
        c.fill(cap, with: .radialGradient(Gradient(colors: [Color(hex: 0xFF7A6B), Color(hex: 0xE23A30), Color(hex: 0xB0221C)]),
                                          center: CGPoint(x: -10, y: -62), startRadius: 0, endRadius: 50))
        c.stroke(cap, with: .color(Color(hex: 0x951A14)), lineWidth: 1.8)
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
        c.stroke(body, with: .color(pink.shade(-0.42).color(0.7)), lineWidth: 1.5)
        var wing = Path()
        wing.move(to: CGPoint(x: -14, y: -80))
        wing.addQuadCurve(to: CGPoint(x: 18, y: -74), control: CGPoint(x: 6, y: -92))
        wing.addQuadCurve(to: CGPoint(x: -14, y: -80), control: CGPoint(x: 0, y: -66))
        c.fill(wing, with: .color(pink.shade(-0.15).color))
        var neck = Path()
        neck.move(to: CGPoint(x: -18, y: -84))
        neck.addCurve(to: CGPoint(x: -14, y: -128), control1: CGPoint(x: -36, y: -100), control2: CGPoint(x: 0, y: -110))
        c.stroke(neck, with: .color(pink.shade(-0.24).color), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
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
        c.stroke(ped, with: .color(stone.shade(-0.42).color), lineWidth: 1.5)
        var bowl = Path()
        bowl.move(to: CGPoint(x: -50, y: -70))
        bowl.addQuadCurve(to: CGPoint(x: 50, y: -70), control: CGPoint(x: 0, y: -74))
        bowl.addQuadCurve(to: CGPoint(x: -50, y: -70), control: CGPoint(x: 0, y: -36))
        bowl.closeSubpath()
        c.fill(bowl, with: .linearGradient(Gradient(colors: [stone.shade(0.15).color, stone.shade(-0.3).color]),
                                           startPoint: CGPoint(x: 0, y: -72), endPoint: CGPoint(x: 0, y: -50)))
        c.stroke(bowl, with: .color(stone.shade(-0.45).color), lineWidth: 1.5)
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
        let box = Path(roundedRect: CGRect(x: -26, y: -20, width: 52, height: 46), cornerRadius: 5)
        h.fill(box, with: .linearGradient(Gradient(colors: [Color(hex: 0xAEE3FF), Color(hex: 0x78C2EE)]),
                                          startPoint: CGPoint(x: -26, y: 0), endPoint: CGPoint(x: 26, y: 0)))
        h.stroke(box, with: .color(StorybookArt.outline(for: 0x78C2EE)), lineWidth: 1.8)
        var roof = Path()
        roof.move(to: CGPoint(x: -36, y: -16))
        roof.addLine(to: CGPoint(x: 0, y: -44))
        roof.addLine(to: CGPoint(x: 36, y: -16))
        roof.closeSubpath()
        h.fill(roof, with: .linearGradient(Gradient(colors: [Color(hex: 0xFF8DA1), Color(hex: 0xE2526C)]),
                                           startPoint: CGPoint(x: 0, y: -44), endPoint: CGPoint(x: 0, y: -16)))
        h.stroke(roof, with: .color(StorybookArt.outline(for: 0xE2526C)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
        h.fill(Path(ellipseIn: CGRect(x: -10, y: -8, width: 20, height: 20)), with: .color(Color(hex: 0x2E3C4A)))
        h.fill(Path(roundedRect: CGRect(x: -2, y: 16, width: 4, height: 9), cornerRadius: 2), with: .color(Color(hex: 0x8E5A30)))
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
            ear.stroke(e, with: .color(stone.shade(-0.34).color), lineWidth: 1.3)
        }
        let body = Path(ellipseIn: CGRect(x: -24, y: -42, width: 48, height: 44))
        c.fill(body, with: .radialGradient(Gradient(colors: [stone.shade(0.3).color, stone.shade(-0.2).color]),
                                           center: CGPoint(x: -8, y: -30), startRadius: 0, endRadius: 40))
        c.stroke(body, with: .color(stone.shade(-0.36).color), lineWidth: 1.4)
        let head = Path(ellipseIn: CGRect(x: -17, y: -66, width: 34, height: 30))
        c.fill(head, with: .radialGradient(Gradient(colors: [stone.shade(0.35).color, stone.shade(-0.15).color]),
                                           center: CGPoint(x: -6, y: -58), startRadius: 0, endRadius: 26))
        c.stroke(head, with: .color(stone.shade(-0.36).color), lineWidth: 1.4)
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
        c.stroke(f, with: .color(Color(hex: 0xA275D8, alpha: 0.7)), lineWidth: 1.4)
        c.fill(Twinkle().path(in: CGRect(x: 14, y: -120, width: 16, height: 16)), with: .color(.white.opacity(0.9)))
    }

    private static func lotus(_ c: GraphicsContext, night: CGFloat, t: CGFloat) {
        let pulse = 0.88 + 0.12 * sin(t * 2.6)
        let glowStrength = Double(0.28 + 0.62 * night) * Double(pulse)

        // Warm pastel aura behind the lotus lantern, brightest at dusk/night
        c.fill(
            Path(ellipseIn: CGRect(x: -54, y: -112, width: 108, height: 96)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hex: 0xFFF2B8, alpha: 0.72 * glowStrength),
                    Color(hex: 0xFFB8DC, alpha: 0.42 * glowStrength),
                    Color(hex: 0xFFB8DC, alpha: 0),
                ]),
                center: CGPoint(x: 0, y: -64),
                startRadius: 6,
                endRadius: 54
            )
        )

        // Soft mossy garden stone pedestal
        var stone = Path()
        stone.move(to: CGPoint(x: -36, y: 0))
        stone.addQuadCurve(to: CGPoint(x: -30, y: -24), control: CGPoint(x: -40, y: -16))
        stone.addQuadCurve(to: CGPoint(x: 30, y: -24), control: CGPoint(x: 0, y: -30))
        stone.addQuadCurve(to: CGPoint(x: 36, y: 0), control: CGPoint(x: 40, y: -16))
        stone.addQuadCurve(to: CGPoint(x: -36, y: 0), control: CGPoint(x: 0, y: 4))
        stone.closeSubpath()
        let stoneCol = GRGB(0xCEC8D8)
        c.fill(
            stone,
            with: .linearGradient(
                Gradient(colors: [stoneCol.shade(0.18).color, stoneCol.color, stoneCol.shade(-0.22).color]),
                startPoint: CGPoint(x: 0, y: -28),
                endPoint: CGPoint(x: 0, y: 2)
            )
        )
        c.stroke(stone, with: .color(StorybookArt.outline(for: 0xB8B0C8)), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        StorybookArt.highlight(c, in: CGRect(x: -22, y: -16, width: 18, height: 6), opacity: 0.42)

        // Soft pastel moss tufts hugging the stone shoulder
        let mossOutline = StorybookArt.outline(for: 0x7ED89E)
        let mossTufts: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-26, -22, 11, 7), (-13, -25, 12, 7.5), (0, -26, 13, 7), (14, -25, 12, 7.5), (26, -22, 10.5, 6.8),
        ]
        var mossPath = Path()
        for (mx, my, rx, ry) in mossTufts {
            mossPath.addEllipse(in: CGRect(x: mx - rx, y: my - ry, width: rx * 2, height: ry * 2))
        }
        StorybookArt.fillAndStroke(c, mossPath, fill: Color(hex: 0x8CE2A8), stroke: mossOutline, width: 2.0)

        // Lotus pad leaves fanning beneath the lantern
        let leafOutline = StorybookArt.outline(for: 0x62C498)
        for side in [-1.0, 1.0] as [CGFloat] {
            var leaf = Path()
            leaf.move(to: CGPoint(x: 0, y: -28))
            leaf.addQuadCurve(to: CGPoint(x: side * 40, y: -38), control: CGPoint(x: side * 24, y: -22))
            leaf.addQuadCurve(to: CGPoint(x: 0, y: -36), control: CGPoint(x: side * 22, y: -48))
            leaf.closeSubpath()
            StorybookArt.fillAndStroke(c, leaf, fill: Color(hex: 0x78D8AA), stroke: leafOutline, width: 2.2)
        }

        // Golden lotus pedestal cup
        let cradle = Path(roundedRect: CGRect(x: -18, y: -36, width: 36, height: 11), cornerRadius: 5.5)
        StorybookArt.shape(c, cradle, hex: 0xFFD972, width: 2.2)

        // Helper to draw a pointed Korean lotus lantern petal
        func petalPath(tip: CGPoint, base: CGPoint, width: CGFloat) -> Path {
            let dx = tip.x - base.x
            let dy = tip.y - base.y
            let len = max(1, hypot(dx, dy))
            let nx = -dy / len
            let ny = dx / len
            let mid = CGPoint(x: base.x + dx * 0.45, y: base.y + dy * 0.45)
            var p = Path()
            p.move(to: base)
            p.addQuadCurve(to: tip, control: CGPoint(x: mid.x + nx * width, y: mid.y + ny * width))
            p.addQuadCurve(to: base, control: CGPoint(x: mid.x - nx * width, y: mid.y - ny * width))
            p.closeSubpath()
            return p
        }

        let lanternCenter = CGPoint(x: 0, y: -34)
        let backPetalOutline = StorybookArt.outline(for: 0xD6A6FF)
        let pinkOutline = StorybookArt.outline(for: 0xFF8FB8)

        // Back ring of soft lilac-rose petals
        for (dx, dy, w) in [(-34.0, -48.0, 15.0), (34.0, -48.0, 15.0), (-20.0, -58.0, 15.0), (20.0, -58.0, 15.0)] as [(CGFloat, CGFloat, CGFloat)] {
            let p = petalPath(tip: CGPoint(x: dx, y: lanternCenter.y + dy), base: lanternCenter, width: w)
            c.fill(
                p,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xF5D6FF), Color(hex: 0xFFB8DC)]),
                    startPoint: CGPoint(x: 0, y: -96),
                    endPoint: lanternCenter
                )
            )
            c.stroke(p, with: .color(backPetalOutline), style: StrokeStyle(lineWidth: 2.1, lineJoin: .round))
        }

        // Glowing warm lantern core inside the lotus blossom
        let core = Path(ellipseIn: CGRect(x: -24, y: -88, width: 48, height: 52))
        c.fill(
            core,
            with: .radialGradient(
                Gradient(colors: [
                    Color(hex: 0xFFFBE0),
                    Color(hex: 0xFFE394, alpha: 0.92),
                    Color(hex: 0xFFA6C8, alpha: 0.78),
                ]),
                center: CGPoint(x: 0, y: -64),
                startRadius: 3,
                endRadius: 30
            )
        )

        // Front pastel pink & cream upturned lotus petals
        let frontPetals: [(CGFloat, CGFloat, CGFloat, UInt32, UInt32)] = [
            (-28, -42, 14, 0xFF9AC8, 0xFFE6F2),
            (28, -42, 14, 0xFF9AC8, 0xFFE6F2),
            (-14, -56, 15, 0xFFAAD2, 0xFFF3DC),
            (14, -56, 15, 0xFFAAD2, 0xFFF3DC),
            (0, -62, 16, 0xFFB5DA, 0xFFF9E6),
        ]
        for (dx, dy, w, tipHex, baseHex) in frontPetals {
            let tip = CGPoint(x: dx, y: lanternCenter.y + dy)
            let p = petalPath(tip: tip, base: lanternCenter, width: w)
            c.fill(
                p,
                with: .linearGradient(
                    Gradient(colors: [StorybookArt.color(tipHex), StorybookArt.color(baseHex)]),
                    startPoint: tip,
                    endPoint: lanternCenter
                )
            )
            c.stroke(p, with: .color(pinkOutline), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
        }

        // Inner sunlit golden glow sheen across the petals
        c.fill(
            Path(ellipseIn: CGRect(x: -16, y: -76, width: 32, height: 32)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF9D0, alpha: 0.52 + 0.32 * Double(night)), Color(hex: 0xFFF9D0, alpha: 0)]),
                center: CGPoint(x: 0, y: -60),
                startRadius: 2,
                endRadius: 18
            )
        )

        // Golden lotus lantern crown finial & hanging pearl charm
        let cap = Path(ellipseIn: CGRect(x: -10, y: -101, width: 20, height: 9))
        StorybookArt.shape(c, cap, hex: 0xFFD966, width: 2.0)
        let finial = Path(ellipseIn: CGRect(x: -5, y: -110, width: 10, height: 11))
        StorybookArt.shape(c, finial, hex: 0xFFE68A, width: 2.0)
        StorybookArt.highlight(c, in: CGRect(x: -2.5, y: -108, width: 3.5, height: 3.5), opacity: 0.85)

        // Twinkling pastel starlight sparks around the lotus lantern
        let sparkAlpha = 0.55 + 0.45 * Double(night)
        StorybookArt.sparkle(c, at: CGPoint(x: -32, y: -92), radius: 5.5 * pulse, color: Theme.lemon, opacity: sparkAlpha)
        StorybookArt.sparkle(c, at: CGPoint(x: 32, y: -88), radius: 4.8 * pulse, color: .white, opacity: sparkAlpha)
        StorybookArt.sparkle(c, at: CGPoint(x: 0, y: -114), radius: 5.0 * pulse, color: Color(hex: 0xFFF7BE), opacity: sparkAlpha)
    }
}
