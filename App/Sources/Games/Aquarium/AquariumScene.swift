import SwiftUI

struct AquariumRoomBackdrop: View {
    let lightsOn: Bool

    var body: some View {
        GeometryReader { geo in
            let map = GameStageMap(size: geo.size)
            let cabinetTop = map.screen(CGPoint(x: 0, y: AGeo.bottomY + 8)).y
            ZStack {
                LinearGradient(
                    colors: lightsOn
                        ? [Color(hex: 0xFFF0F6), Color(hex: 0xF8D9EA)]
                        : [Color(hex: 0x332D5A), Color(hex: 0x221E42)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Canvas { ctx, size in
                    var stripes = Path()
                    let stripeStep = max(28, 48 * map.scale)
                    let stripeW = stripeStep * 0.3
                    var x: CGFloat = 0
                    while x < size.width + stripeStep {
                        stripes.addRect(CGRect(x: x, y: 0, width: stripeW, height: cabinetTop + 8))
                        x += stripeStep
                    }
                    ctx.fill(stripes, with: .color(.white.opacity(lightsOn ? 0.24 : 0.04)))

                    if !lightsOn {
                        for k in 0..<26 {
                            let sx = aqRand(k, 31) * size.width
                            let sy = aqRand(k, 37) * max(40, cabinetTop - 20)
                            let sr = (2.5 + aqRand(k, 41) * 3.5) * map.scale
                            StorybookArt.sparkle(ctx, at: CGPoint(x: sx, y: sy), radius: sr, color: Theme.lemon, opacity: 0.35)
                        }
                    }

                    // Extend the warm wooden cabinet apron cleanly to screen edges on widescreen devices.
                    let woodTop = lightsOn ? Color(hex: 0xD89B6C) : Color(hex: 0x5B4758)
                    let woodMid = lightsOn ? Color(hex: 0xC18254) : Color(hex: 0x4A394A)
                    let woodBot = lightsOn ? Color(hex: 0x9C623B) : Color(hex: 0x392B3B)
                    let apron = CGRect(x: 0, y: cabinetTop, width: size.width, height: max(0, size.height - cabinetTop))
                    ctx.fill(
                        Path(apron),
                        with: .linearGradient(
                            Gradient(colors: [woodTop, woodMid, woodBot]),
                            startPoint: CGPoint(x: 0, y: cabinetTop),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                    let lip = CGRect(x: 0, y: cabinetTop - 2 * map.scale, width: size.width, height: 10 * map.scale)
                    ctx.fill(Path(lip), with: .color(lightsOn ? Color(hex: 0xE7B084) : Color(hex: 0x6B5469)))
                }
            }
            .animation(.easeInOut(duration: 0.55), value: lightsOn)
        }
        .ignoresSafeArea()
    }
}

enum AquaPainter {
    // MARK: - Slow layer (30 fps)

    static func drawBackdrop(_ ctx: GraphicsContext, sim: AquariumSim) {
        let t = CGFloat(sim.time)
        let n = sim.night
        cabinet(ctx, n)
        water(ctx, n, t)
        sand(ctx, n, t)
    }

    private static func cabinet(_ g: GraphicsContext, _ n: CGFloat) {
        let wood = ARGB(0xCE8E5E).mix(ARGB(0x4E3D4E), n * 0.72)
        let trim = wood.shade(-0.32)

        let bodyRect = CGRect(x: 16, y: AGeo.bottomY + 8, width: 992, height: GameChromeLayout.height - AGeo.bottomY)
        let cab = Path(roundedRect: bodyRect, cornerRadius: 6)
        g.fill(
            cab,
            with: .linearGradient(
                Gradient(colors: [wood.shade(0.14).color, wood.color, wood.shade(-0.22).color]),
                startPoint: CGPoint(x: 0, y: AGeo.bottomY + 8),
                endPoint: CGPoint(x: 0, y: GameChromeLayout.height)
            )
        )

        // Subtle carved decorative wainscoting panels flanking the dock area.
        for x in [42.0, 804.0] as [CGFloat] {
            let panel = Path(roundedRect: CGRect(x: x, y: AGeo.bottomY + 30, width: 178, height: 92), cornerRadius: 14)
            g.fill(panel, with: .color(wood.shade(-0.1).color(0.45)))
            g.stroke(panel, with: .color(trim.color(0.5)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            let inner = Path(roundedRect: CGRect(x: x + 8, y: AGeo.bottomY + 38, width: 162, height: 76), cornerRadius: 10)
            g.stroke(inner, with: .color(wood.shade(0.24).color(0.35)), lineWidth: 1.4)
        }

        // Subtle wood-grain accents.
        var grain = Path()
        for k in 0..<4 {
            let y = AGeo.bottomY + 42 + CGFloat(k) * 24
            grain.move(to: CGPoint(x: 34, y: y))
            grain.addQuadCurve(to: CGPoint(x: 990, y: y), control: CGPoint(x: 512, y: y + (k % 2 == 0 ? 5 : -5)))
        }
        g.stroke(grain, with: .color(trim.color(0.18)), lineWidth: 1.5)

        // Warm brass cabinet pulls on the flanking doors.
        for kx in [204.0, 820.0] as [CGFloat] {
            let knob = AquaShape.circle(CGPoint(x: kx, y: AGeo.bottomY + 76), 7)
            let brass = ARGB(0xF5C862).mix(ARGB(0x9C8464), n * 0.5)
            g.fill(knob, with: .radialGradient(Gradient(colors: [brass.shade(0.35).color, brass.color, brass.shade(-0.25).color]),
                                               center: CGPoint(x: kx - 2, y: AGeo.bottomY + 74), startRadius: 1, endRadius: 8))
            g.stroke(knob, with: .color(brass.shade(-0.42).color(0.8)), lineWidth: 1.6)
        }

        // Beveled tabletop overhang lip under the tank base.
        let shadow = Path(CGRect(x: 16, y: AGeo.bottomY + 18, width: 992, height: 8))
        g.fill(shadow, with: .linearGradient(Gradient(colors: [trim.color(0.36), .clear]),
                                             startPoint: CGPoint(x: 0, y: AGeo.bottomY + 18), endPoint: CGPoint(x: 0, y: AGeo.bottomY + 26)))
        let edge = Path(roundedRect: CGRect(x: 10, y: AGeo.bottomY + 2, width: 1004, height: 18), cornerRadius: 7)
        g.fill(
            edge,
            with: .linearGradient(
                Gradient(colors: [wood.shade(0.28).color, wood.shade(0.12).color]),
                startPoint: CGPoint(x: 0, y: AGeo.bottomY + 2),
                endPoint: CGPoint(x: 0, y: AGeo.bottomY + 20)
            )
        )
        g.stroke(edge, with: .color(trim.color(0.7)), lineWidth: 2)
    }

    private static func water(_ g: GraphicsContext, _ n: CGFloat, _ t: CGFloat) {
        let tank = AGeo.tank
        let top = ARGB(0x8EE2F4).mix(ARGB(0x183E72), n)
        let mid = ARGB(0x45B5DC).mix(ARGB(0x102D5A), n)
        let deep = ARGB(0x1F75A8).mix(ARGB(0x091C3E), n)
        g.fill(
            Path(tank),
            with: .linearGradient(
                Gradient(colors: [top.color, mid.color, deep.color]),
                startPoint: CGPoint(x: 0, y: AGeo.waterY),
                endPoint: CGPoint(x: 0, y: AGeo.bottomY)
            )
        )

        var clipped = g
        clipped.clip(to: Path(tank))

        // Distant soft hazy reef silhouettes in the background.
        clipped.fill(AquaPainter.backPlants, with: .color(deep.mix(ARGB(0x2F8A6A), 0.5).color(0.42)))

        // Soft translucent diagonal light-shimmer ribbons descending straight from the hood's integrated light bar.
        let day = Double(1 - n)
        let ribbonColor = day > 0.25 ? ARGB(0xFFFDF0) : ARGB(0xB8CCFF)
        let ribbonAlpha = day > 0.25 ? 0.21 * day : 0.14 * Double(n)
        for k in 0..<5 {
            let xTop = 138 + CGFloat(k) * 182 + sin(t * 0.25 + CGFloat(k) * 1.6) * 26
            let halfW: CGFloat = 24 + 8 * sin(t * 0.45 + CGFloat(k))
            let lean: CGFloat = 78
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: xTop - halfW, y: AGeo.rimY))
            ribbon.addLine(to: CGPoint(x: xTop + halfW, y: AGeo.rimY))
            ribbon.addQuadCurve(
                to: CGPoint(x: xTop + lean + halfW * 2.4, y: 632),
                control: CGPoint(x: xTop + lean * 0.5 + halfW * 1.8 + sin(t * 0.7 + CGFloat(k)) * 12, y: 390)
            )
            ribbon.addLine(to: CGPoint(x: xTop + lean - halfW * 2.1, y: 632))
            ribbon.addQuadCurve(
                to: CGPoint(x: xTop - halfW, y: AGeo.rimY),
                control: CGPoint(x: xTop + lean * 0.5 - halfW * 1.4 + sin(t * 0.7 + CGFloat(k)) * 12, y: 390)
            )
            ribbon.closeSubpath()
            clipped.fill(
                ribbon,
                with: .linearGradient(
                    Gradient(colors: [
                        ribbonColor.color(ribbonAlpha * 0.85),
                        ribbonColor.color(ribbonAlpha * 0.45),
                        ribbonColor.color(0),
                    ]),
                    startPoint: CGPoint(x: xTop, y: AGeo.rimY),
                    endPoint: CGPoint(x: xTop + lean, y: 632)
                )
            )
        }

        // Pump air line tucked down the back right corner.
        let tube = Path(roundedRect: CGRect(x: 932, y: AGeo.rimY - 2, width: 8, height: AGeo.sand(936) - AGeo.rimY), cornerRadius: 4)
        clipped.fill(tube, with: .color(.white.opacity(0.22)))
        clipped.stroke(tube, with: .color(.white.opacity(0.35)), lineWidth: 1)
    }

    private static func sand(_ g: GraphicsContext, _ n: CGFloat, _ t: CGFloat) {
        let light = ARGB(0xF6E3BC).mix(ARGB(0x3B4C6D), n * 0.78)
        let dark = ARGB(0xD8B786).mix(ARGB(0x273452), n * 0.78)
        g.fill(
            AquaPainter.sandPath,
            with: .linearGradient(
                Gradient(colors: [light.color, dark.color]),
                startPoint: CGPoint(x: 0, y: 596),
                endPoint: CGPoint(x: 0, y: AGeo.bottomY)
            )
        )
        let pebbles = AquaPainter.pebbles
        let tints: [ARGB] = [ARGB(0xFFB7C9), ARGB(0xC9B6FF), ARGB(0x9FB4C8)]
        for i in 0..<3 {
            g.fill(pebbles[i], with: .color(tints[i].mix(ARGB(0x2A3350), n * 0.7).color(0.85)))
        }
        g.fill(AquaPainter.grains, with: .color(dark.shade(-0.2).color(0.38)))

        // Soft undulating sunlit shimmer bands pooled gently along the sand crest (no harsh white ovals).
        var sandClip = g
        sandClip.clip(to: AquaPainter.sandPath)
        let shimmerAlpha = Double(1 - n * 0.75) * 0.24
        for row in 0..<2 {
            var band = Path()
            let yOff = CGFloat(row) * 20 + 10
            var x = AGeo.left
            band.move(to: CGPoint(x: x, y: AGeo.sand(x) + yOff))
            while x <= AGeo.right {
                let wave = sin(x * 0.022 + t * (0.9 + CGFloat(row) * 0.35) + CGFloat(row) * 2.1) * 5
                band.addLine(to: CGPoint(x: x, y: AGeo.sand(x) + yOff + wave))
                x += 18
            }
            sandClip.stroke(
                band,
                with: .color(ARGB(0xFFFBE6).color(shimmerAlpha * (row == 0 ? 1 : 0.6))),
                style: StrokeStyle(lineWidth: row == 0 ? 10 : 7, lineCap: .round, lineJoin: .round)
            )
        }
    }

    static let sandPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: AGeo.left, y: AGeo.bottomY))
        var x = AGeo.left
        while x <= AGeo.right {
            p.addLine(to: CGPoint(x: x, y: AGeo.sand(x)))
            x += 12
        }
        p.addLine(to: CGPoint(x: AGeo.right, y: AGeo.sand(AGeo.right)))
        p.addLine(to: CGPoint(x: AGeo.right, y: AGeo.bottomY))
        p.closeSubpath()
        return p
    }()

    static let pebbles: [Path] = {
        var ps = [Path(), Path(), Path()]
        for k in 0..<90 {
            let x = AGeo.left + 8 + aqRand(k, 61) * (AGeo.width - 16)
            let top = AGeo.sand(x) + 6
            let y = top + aqRand(k, 62) * (AGeo.bottomY - top - 6)
            let r = 2.5 + aqRand(k, 63) * 4.5
            ps[k % 3].addEllipse(in: CGRect(x: x - r, y: y - r * 0.7, width: r * 2, height: r * 1.4))
        }
        return ps
    }()

    static let grains: Path = {
        var p = Path()
        for k in 0..<240 {
            let x = AGeo.left + aqRand(k, 71) * AGeo.width
            let top = AGeo.sand(x) + 3
            let y = top + aqRand(k, 72) * (AGeo.bottomY - top)
            p.addEllipse(in: CGRect(x: x, y: y, width: 1.6, height: 1.2))
        }
        return p
    }()

    static let backPlants: Path = {
        var p = Path()
        for k in 0..<14 {
            let x0 = AGeo.left + 30 + CGFloat(k) * 68 + aqRand(k, 81) * 30
            let h = 120 + aqRand(k, 82) * 195
            let base = AGeo.sand(x0) + 4
            let lean = (aqRand(k, 83) - 0.5) * 50
            p.move(to: CGPoint(x: x0 - 8, y: base))
            p.addQuadCurve(to: CGPoint(x: x0 + lean, y: base - h), control: CGPoint(x: x0 - 16 + lean * 0.2, y: base - h * 0.5))
            p.addQuadCurve(to: CGPoint(x: x0 + 8, y: base), control: CGPoint(x: x0 + 14 + lean * 0.3, y: base - h * 0.45))
            p.closeSubpath()
        }
        return p
    }()

    // MARK: - Moving layer (60 fps)

    static func draw(_ g: GraphicsContext, sim: AquariumSim) {
        let t = CGFloat(sim.time)

        var w = g
        w.clip(to: Path(AGeo.tank))

        updraftColumns(w, sim, t)
        for d in sim.decor where !d.held { AquaDecorPainter.draw(w, d, time: t) }
        finds(w, sim, t, layer: 0)
        food(w, sim, under: true)
        bubbles(w, sim, back: true)

        // Back half of drifting bubble hoops sits behind swimming fish.
        for h in sim.hoops {
            var hc = w
            hc.translateBy(x: h.p.x, y: h.p.y)
            let fade = min(1, h.age / 0.35, (h.life - h.age) / 0.5)
            hc.opacity = Double(aqClamp(fade))
            AquaDecorPainter.hoopBack(hc, radius: h.radius, shimmer: h.shimmer, time: t)
        }

        let order = sim.fish.indices.filter { !sim.fish[$0].caught }.sorted { sim.fish[$0].z < sim.fish[$1].z }
        for i in order {
            let f = sim.fish[i]
            AquaFishPainter.draw(w, f, time: t, pitch: sim.fishPitch(f))
        }

        // Front half of drifting bubble hoops overlaps fish so they visibly pass through the ring.
        for h in sim.hoops {
            var hc = w
            hc.translateBy(x: h.p.x, y: h.p.y)
            let fade = min(1, h.age / 0.35, (h.life - h.age) / 0.5)
            hc.opacity = Double(aqClamp(fade))
            AquaDecorPainter.hoopFront(hc, radius: h.radius, shimmer: h.shimmer, time: t)
        }

        for i in order {
            AquaFishPainter.drawCrumbBubble(w, for: sim.fish[i], time: t)
        }

        finds(w, sim, t, layer: 1)
        bubbles(w, sim, back: false)
        particlesIn(w, sim)
        surface(w, sim, t)
        food(g, sim, under: false)
        nightAndGlow(w, sim, order, t)
        finds(w, sim, t, layer: 2)
        snail(w, sim, t)
        mossClouds(w, sim)

        particlesOut(g, sim, t)
        glassAndFrame(g, sim)
        for d in sim.decor where d.held { AquaDecorPainter.draw(g, d, time: t) }
        tool(g, sim, t)
        drawQuickAction(g, sim, t)
    }

    private static func updraftColumns(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        for d in sim.decor where d.kind == .bubbler && !d.held && !d.falling && sim.time < d.boostUntil {
            let remain = CGFloat(min(1, d.boostUntil - sim.time))
            let colW: CGFloat = 68 + 8 * sin(t * 7)
            let rect = CGRect(x: d.x - colW * 0.5, y: AGeo.waterY, width: colW, height: max(10, d.y - 26 - AGeo.waterY))
            g.fill(
                Path(roundedRect: rect, cornerRadius: colW * 0.45),
                with: .linearGradient(
                    Gradient(colors: [
                        StorybookArt.color(0xB8F5FF, alpha: 0.06 * Double(remain)),
                        StorybookArt.color(0x9AEBFF, alpha: 0.22 * Double(remain)),
                        StorybookArt.color(0xC8FAFF, alpha: 0.32 * Double(remain)),
                    ]),
                    startPoint: CGPoint(x: d.x, y: AGeo.waterY),
                    endPoint: CGPoint(x: d.x, y: d.y - 26)
                )
            )
        }
    }

    private static func finds(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat, layer: Int) {
        switch layer {
        case 0:
            if let pl = sim.pearl, let d = sim.decor.first(where: { $0.id == pl.id }), d.open > 0.15 {
                AquaVisitorPainter.pearl(g, at: CGPoint(x: d.x, y: d.y - 42 - 8 * d.open), r: 10 * min(1, d.open * 1.5), glow: d.open)
            }
            for v in sim.visitors where v.kind == .crab || v.kind == .octopus {
                AquaVisitorPainter.draw(g, v, time: t, night: sim.night, nowTime: sim.time)
            }
        case 1:
            for f in sim.fish where f.variant >= AquaRare.variant && !f.caught {
                Twinkles.draw(g, around: f.p, radius: (f.kind.length + f.kind.tailLength) * 0.45 * f.scale, time: t + CGFloat(f.id), count: 3, alpha: 0.9)
            }
            for v in sim.visitors where v.kind.passesBy {
                AquaVisitorPainter.draw(g, v, time: t, night: sim.night, nowTime: sim.time)
            }
        default:
            for v in sim.visitors where v.kind == .jellyfish {
                AquaVisitorPainter.draw(g, v, time: t, night: sim.night, nowTime: sim.time)
            }
        }
    }

    private static func food(_ g: GraphicsContext, _ sim: AquariumSim, under: Bool) {
        var paths = [Path(), Path(), Path(), Path()]
        var any = false
        for f in sim.food {
            let low = f.state == .sinking || f.state == .settled
            guard low == under else { continue }
            any = true
            let c = cos(f.rot), s = sin(f.rot)
            let w: CGFloat = 4.7, h: CGFloat = 3.3
            paths[f.hue].move(to: CGPoint(x: f.p.x + c * w - s * h, y: f.p.y + s * w + c * h))
            paths[f.hue].addLine(to: CGPoint(x: f.p.x - c * w - s * h, y: f.p.y - s * w + c * h))
            paths[f.hue].addLine(to: CGPoint(x: f.p.x - c * w + s * h, y: f.p.y - s * w - c * h))
            paths[f.hue].addLine(to: CGPoint(x: f.p.x + c * w + s * h * 0.6, y: f.p.y + s * w - c * h))
            paths[f.hue].closeSubpath()
        }
        guard any else { return }
        let colors: [UInt32] = [0xFF6A4A, 0xFFC94A, 0x7AC25A, 0xE8823A]
        for i in 0..<4 { g.fill(paths[i], with: .color(ARGB(colors[i]).color(0.95))) }
    }

    private static func bubbles(_ g: GraphicsContext, _ sim: AquariumSim, back: Bool) {
        var rims = Path(), lights = Path()
        var any = false
        for b in sim.bubbles where b.back == back {
            any = true
            let r = b.r
            let rect = CGRect(x: b.p.x - r * 1.05, y: b.p.y - r * 0.95, width: r * 2.1, height: r * 1.9)
            rims.addEllipse(in: rect)
            lights.addEllipse(in: CGRect(x: b.p.x - r * 0.55, y: b.p.y - r * 0.6, width: r * 0.55, height: r * 0.45))
        }
        guard any else { return }
        let a = back ? 0.6 : 1.0
        g.fill(rims, with: .color(.white.opacity(0.14 * a)))
        g.stroke(rims, with: .color(.white.opacity(0.72 * a)), lineWidth: 1.1)
        g.fill(lights, with: .color(.white.opacity(0.9 * a)))
    }

    private static func particlesIn(_ g: GraphicsContext, _ sim: AquariumSim) {
        var sandP = Path(), mossP = Path()
        for q in sim.particles {
            switch q.kind {
            case .sand:
                sandP.addEllipse(in: CGRect(x: q.p.x - q.size / 2, y: q.p.y - q.size / 2, width: q.size, height: q.size))
            case .moss:
                mossP.addEllipse(in: CGRect(x: q.p.x - q.size / 2, y: q.p.y - q.size / 2, width: q.size, height: q.size * 0.8))
            case .poof:
                let k = Double(1 - q.age / q.life)
                g.fill(
                    AquaShape.circle(q.p, q.size),
                    with: .radialGradient(
                        Gradient(colors: [q.color.color(0.4 * k), q.color.color(0)]),
                        center: q.p,
                        startRadius: 0,
                        endRadius: q.size
                    )
                )
            default:
                break
            }
        }
        g.fill(sandP, with: .color(ARGB(0xE2C996).color(0.9)))
        g.fill(mossP, with: .color(ARGB(0x7FD6A4).color(0.75)))
    }

    private static func surface(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        var line = Path()
        var air = Path()
        let step: CGFloat = 14
        air.move(to: CGPoint(x: AGeo.left, y: AGeo.rimY - 2))
        air.addLine(to: CGPoint(x: AGeo.right, y: AGeo.rimY - 2))
        var x = AGeo.right
        var first = true
        while x >= AGeo.left - 0.1 {
            let p = CGPoint(x: x, y: sim.surfaceY(x))
            air.addLine(to: p)
            if first { line.move(to: p); first = false } else { line.addLine(to: p) }
            x -= step
        }
        air.closeSubpath()
        let n = Double(sim.night)
        g.fill(
            air,
            with: .linearGradient(
                Gradient(colors: [ARGB(0xF6FCFF).color(0.84 - 0.48 * n), ARGB(0xDFF4FC).color(0.68 - 0.42 * n)]),
                startPoint: CGPoint(x: 0, y: AGeo.rimY),
                endPoint: CGPoint(x: 0, y: AGeo.waterY)
            )
        )
        var under = g
        under.translateBy(x: 0, y: 7)
        under.stroke(line, with: .color(.white.opacity(0.22 - 0.12 * n)), lineWidth: 8)
        g.stroke(line, with: .color(.white.opacity(0.9 - 0.4 * n)), lineWidth: 2.4)
        var glints = Path()
        for k in 0..<9 {
            let gx = AGeo.left + (CGFloat(k) * 113 + t * 28).truncatingRemainder(dividingBy: AGeo.width)
            let gy = sim.surfaceY(gx)
            glints.addEllipse(in: CGRect(x: gx - 9, y: gy - 1.5, width: 18, height: 3))
        }
        g.fill(glints, with: .color(.white.opacity(0.8 - 0.5 * n)))
    }

    private static func nightAndGlow(_ g: GraphicsContext, _ sim: AquariumSim, _ order: [Int], _ t: CGFloat) {
        let n = sim.night
        guard n > 0.01 else { return }
        g.fill(Path(AGeo.tank), with: .color(ARGB(0x0A1430).color(Double(0.4 * n))))
        var glow = g
        glow.blendMode = .plusLighter

        for i in order where sim.fish[i].kind == .tetra {
            let f = sim.fish[i]
            var c = glow
            c.translateBy(x: f.p.x, y: f.p.y)
            let side: CGFloat = f.facing < 0 ? -1 : 1
            var sx = f.facing
            if abs(sx) < 0.14 { sx = 0.14 * side }
            c.rotate(by: .radians(Double(sim.fishPitch(f) * side)))
            c.scaleBy(x: sx * f.scale, y: f.scale)
            c.opacity = Double(n) * 0.82
            AquaFishPainter.neon(c, AquaFishPainter.tetraBody(phase: f.phase, amp: f.amp))
        }

        // Bioluminescent bubble hoops shimmer warmly at night.
        for h in sim.hoops {
            glow.fill(
                AquaShape.circle(h.p, h.radius * 1.4),
                with: .radialGradient(
                    Gradient(colors: [ARGB(0xA6F2FF).color(0.32 * Double(n)), ARGB(0xA6F2FF).color(0)]),
                    center: h.p,
                    startRadius: 4,
                    endRadius: h.radius * 1.4
                )
            )
        }

        var specks: [Path] = [Path(), Path(), Path()]
        let palette: [ARGB] = [ARGB(0x8CF7FF), ARGB(0xB8FFC8), ARGB(0xD9B8FF)]
        for q in sim.particles where q.kind == .glow {
            let k = min(1, q.age / 0.8, (q.life - q.age) / 0.8)
            let r = q.size * (0.6 + 0.4 * k)
            let idx = palette.firstIndex(of: q.color) ?? 0
            specks[idx].addEllipse(in: CGRect(x: q.p.x - r, y: q.p.y - r, width: r * 2, height: r * 2))
        }
        for i in 0..<3 { glow.fill(specks[i], with: .color(palette[i].color(0.75 * Double(n)))) }

        for d in sim.decor where d.kind == .chest && d.open > 0.05 {
            let c = CGPoint(x: d.x, y: d.y - 46)
            glow.fill(
                AquaShape.circle(c, 64),
                with: .radialGradient(
                    Gradient(colors: [ARGB(0xFFE69A).color(0.55 * Double(n * d.open)), ARGB(0xFFE69A).color(0)]),
                    center: c,
                    startRadius: 0,
                    endRadius: 64
                )
            )
        }
    }

    private static func snail(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        let s = sim.snail
        var c = g
        c.translateBy(x: s.p.x, y: s.p.y)
        c.rotate(by: .radians(Double(s.heading)))
        let ext = 1 - s.hide
        let stretch = 1 + 0.08 * sin(s.phase * 2.2)
        if ext > 0.05 {
            let foot = Path(roundedRect: CGRect(x: -20 * stretch, y: -9, width: 40 * stretch * ext + 4, height: 18), cornerRadius: 9)
            c.fill(foot, with: .color(ARGB(0xE8D3C0).color(0.95)))
            c.stroke(foot, with: .color(ARGB(0xB89A84).color(0.8)), lineWidth: 1.4)
            var stalks = Path()
            let hx = 20 * stretch * ext
            stalks.move(to: CGPoint(x: hx - 2, y: -4)); stalks.addLine(to: CGPoint(x: hx + 10 * ext, y: -12 * ext))
            stalks.move(to: CGPoint(x: hx - 2, y: 4)); stalks.addLine(to: CGPoint(x: hx + 10 * ext, y: 12 * ext))
            c.stroke(stalks, with: .color(ARGB(0xD9BFA8).color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            var eyes = Path()
            eyes.addEllipse(in: CGRect(x: hx + 10 * ext - 2.2, y: -12 * ext - 2.2, width: 4.4, height: 4.4))
            eyes.addEllipse(in: CGRect(x: hx + 10 * ext - 2.2, y: 12 * ext - 2.2, width: 4.4, height: 4.4))
            c.fill(eyes, with: .color(ARGB(0x3A2A40).color))
        }
        let shell = AquaShape.circle(CGPoint(x: -4, y: 0), 15)
        c.fill(
            shell,
            with: .radialGradient(
                Gradient(colors: [ARGB(0xFFD08A).color, ARGB(0xD98A4A).color]),
                center: CGPoint(x: -8, y: -4),
                startRadius: 1,
                endRadius: 17
            )
        )
        var spiral = Path()
        var first = true
        for k in 0..<30 {
            let a = CGFloat(k) * 0.42
            let r = 13 - CGFloat(k) * 0.42
            let p = CGPoint(x: -4 + cos(a) * r, y: sin(a) * r)
            if first { spiral.move(to: p); first = false } else { spiral.addLine(to: p) }
        }
        c.stroke(spiral, with: .color(ARGB(0x9A5A2E).color(0.7)), lineWidth: 1.6)
        c.stroke(shell, with: .color(ARGB(0x9A5A2E).color(0.8)), lineWidth: 1.6)
    }

    /// Soft organic translucent pastel sea-moss clouds hugging the tank edges (replaces polka-dot algae grid).
    private static func mossClouds(_ g: GraphicsContext, _ sim: AquariumSim) {
        let mint = ARGB(0x88D4A6)
        let sage = ARGB(0x63B58E)
        for patch in sim.moss where patch.opacity > 0.02 {
            let alpha = Double(patch.opacity)
            var c = g
            c.translateBy(x: patch.center.x, y: patch.center.y)
            c.rotate(by: .radians(Double(patch.rotation)))

            // Layered feathered watercolor clouds for soft organic sea-moss smudges.
            let lobes: [(CGFloat, CGFloat, CGFloat, CGFloat, Double)] = [
                (0, 0, patch.rx * 1.12, patch.ry * 1.08, 0.32),
                (-patch.rx * 0.34, -patch.ry * 0.2, patch.rx * 0.72, patch.ry * 0.74, 0.26),
                (patch.rx * 0.32, patch.ry * 0.18, patch.rx * 0.68, patch.ry * 0.66, 0.24),
                (patch.rx * 0.08, -patch.ry * 0.32, patch.rx * 0.56, patch.ry * 0.52, 0.20),
            ]
            for (idx, lobe) in lobes.enumerated() {
                let col = idx % 2 == 0 ? mint : sage
                let rect = CGRect(x: lobe.0 - lobe.2, y: lobe.1 - lobe.3, width: lobe.2 * 2, height: lobe.3 * 2)
                c.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [col.color(lobe.4 * alpha), col.color(lobe.4 * 0.45 * alpha), col.color(0)]),
                        center: CGPoint(x: lobe.0, y: lobe.1),
                        startRadius: 2,
                        endRadius: max(lobe.2, lobe.3)
                    )
                )
            }

            // Delicate translucent sea-moss wisps inside the cloud.
            var wisps = Path()
            for k in 0..<4 {
                let wx = (aqRand(patch.seed + k, 1) - 0.5) * patch.rx * 0.9
                let wy = (aqRand(patch.seed + k, 2) - 0.5) * patch.ry * 0.7
                let len = 14 + aqRand(patch.seed + k, 3) * 14
                wisps.move(to: CGPoint(x: wx, y: wy + len * 0.4))
                wisps.addQuadCurve(to: CGPoint(x: wx + 8, y: wy - len * 0.6), control: CGPoint(x: wx - 6, y: wy))
            }
            c.stroke(wisps, with: .color(sage.color(0.24 * alpha)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private static func particlesOut(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        var drops = Path()
        for q in sim.particles {
            switch q.kind {
            case .splash:
                drops.addEllipse(in: CGRect(x: q.p.x - q.size, y: q.p.y - q.size * 1.3, width: q.size * 2, height: q.size * 2.6))
            case .ring:
                let k = q.age / q.life
                let r = q.size * (0.4 + k)
                let ry = r * (q.size > 30 ? 1 : 0.35)
                g.stroke(
                    Path(ellipseIn: CGRect(x: q.p.x - r, y: q.p.y - ry, width: r * 2, height: ry * 2)),
                    with: .color(.white.opacity(Double(0.8 * (1 - k)))),
                    lineWidth: 2
                )
            case .heart:
                let k = Double(1 - q.age / q.life)
                g.fill(AquaShape.heart(q.p, q.size), with: .color(q.color.color(0.95 * k)))
                g.stroke(AquaShape.heart(q.p, q.size), with: .color(.white.opacity(0.8 * k)), lineWidth: 1.4)
            case .sparkle:
                let k = q.age / q.life
                let s = q.size * sin(k * .pi)
                if s > 0.5 {
                    g.fill(Twinkle().path(in: CGRect(x: q.p.x - s, y: q.p.y - s, width: s * 2, height: s * 2)), with: .color(q.color.color(0.95)))
                }
            default:
                break
            }
        }
        g.fill(drops, with: .color(ARGB(0xE4F7FF).color(0.85)))
    }

    private static func glassAndFrame(_ g: GraphicsContext, _ sim: AquariumSim) {
        let n = sim.night
        // Subtle front-glass specular glare strips.
        var glare = Path()
        glare.move(to: CGPoint(x: 90, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 146, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 72, y: AGeo.bottomY - 12))
        glare.addLine(to: CGPoint(x: 54, y: AGeo.bottomY - 12))
        glare.closeSubpath()
        glare.move(to: CGPoint(x: 168, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 180, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 100, y: AGeo.bottomY - 12))
        glare.addLine(to: CGPoint(x: 92, y: AGeo.bottomY - 12))
        glare.closeSubpath()
        glare.move(to: CGPoint(x: 882, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 898, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 846, y: 420))
        glare.addLine(to: CGPoint(x: 836, y: 420))
        glare.closeSubpath()
        g.fill(glare, with: .color(.white.opacity(0.09 * Double(1 - n * 0.6))))

        // Side corner posts and bottom base trim.
        let frame = ARGB(0x527596).mix(ARGB(0x2D3856), n * 0.65)
        let frameOutline = frame.shade(-0.42)
        var posts = Path()
        posts.addRoundedRect(in: CGRect(x: AGeo.left - 16, y: AGeo.rimY - 6, width: 16, height: AGeo.bottomY - AGeo.rimY + 20), cornerSize: CGSize(width: 6, height: 6))
        posts.addRoundedRect(in: CGRect(x: AGeo.right, y: AGeo.rimY - 6, width: 16, height: AGeo.bottomY - AGeo.rimY + 20), cornerSize: CGSize(width: 6, height: 6))
        posts.addRoundedRect(in: CGRect(x: AGeo.left - 18, y: AGeo.bottomY, width: AGeo.width + 36, height: 15), cornerSize: CGSize(width: 5, height: 5))
        g.fill(
            posts,
            with: .linearGradient(
                Gradient(colors: [frame.shade(0.22).color, frame.color, frame.shade(-0.24).color]),
                startPoint: CGPoint(x: 0, y: AGeo.rimY),
                endPoint: CGPoint(x: 0, y: AGeo.bottomY + 15)
            )
        )
        g.stroke(posts, with: .color(frameOutline.color(0.85)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

        // Continuous full-width storybook tank hood with integrated glowing light bar.
        let hoodRect = CGRect(x: AGeo.left - 22, y: AGeo.hoodTop, width: AGeo.width + 44, height: AGeo.rimY - AGeo.hoodTop + 2)
        let hood = Path(roundedRect: hoodRect, cornerRadius: 12)
        g.fill(
            hood,
            with: .linearGradient(
                Gradient(colors: [frame.shade(0.32).color, frame.shade(0.08).color, frame.shade(-0.18).color]),
                startPoint: CGPoint(x: 0, y: AGeo.hoodTop),
                endPoint: CGPoint(x: 0, y: AGeo.rimY + 2)
            )
        )
        g.stroke(hood, with: .color(frameOutline.color(0.9)), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        StorybookArt.highlight(g, in: CGRect(x: AGeo.left + 12, y: AGeo.hoodTop + 4, width: AGeo.width - 24, height: 5), opacity: Double(0.28 * (1 - n * 0.4)))

        // Integrated glowing light bar tucked right along the underside of the continuous hood.
        let barRect = CGRect(x: AGeo.left + 14, y: AGeo.rimY - 7, width: AGeo.width - 28, height: 8)
        let barCore = ARGB(0xFFF9DC).mix(ARGB(0x9BB5FF), n)
        let barHalo = ARGB(0xFFE99A).mix(ARGB(0xB69EFF), n)
        let glowRect = CGRect(x: AGeo.left + 8, y: AGeo.rimY - 5, width: AGeo.width - 16, height: 22)
        g.fill(
            Path(roundedRect: glowRect, cornerRadius: 11),
            with: .linearGradient(
                Gradient(colors: [barHalo.color(0.55), barHalo.color(0)]),
                startPoint: CGPoint(x: 0, y: AGeo.rimY - 5),
                endPoint: CGPoint(x: 0, y: AGeo.rimY + 17)
            )
        )
        let bar = Path(roundedRect: barRect, cornerRadius: 4)
        g.fill(bar, with: .color(barCore.color))
        g.stroke(bar, with: .color(.white.opacity(0.65)), lineWidth: 1)
    }

    private static func tool(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        if let tl = sim.tool {
            var see = g
            let working: Bool
            switch tl {
            case .wiper, .net, .hoop: working = AGeo.tank.contains(sim.toolP)
            default: working = false
            }
            if working { see.opacity = tl == .wiper ? 0.82 : 0.9 }
            drawTool(see, sim, tl, at: sim.toolP, tilt: sim.tilt, t: t)
        }
        if let r = sim.returning {
            let k = aqEase(CGFloat(sim.time - r.start) / 0.32)
            if k < 1 {
                let p = CGPoint(x: r.from.x + (r.to.x - r.from.x) * k, y: r.from.y + (r.to.y - r.from.y) * k - 60 * sin(k * .pi))
                var sg = g
                sg.opacity = Double(1 - k * 0.3)
                drawTool(sg, nil, r.tool, at: p, tilt: r.tilt * (1 - k), t: t)
            }
        }
    }

    private static func drawQuickAction(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        guard let q = sim.quickAction else { return }
        let u = aqClamp(CGFloat((sim.time - q.start) / q.duration))
        guard u < 1 else { return }
        let arc = sin(u * .pi)
        switch q.kind {
        case .food:
            let pos = CGPoint(
                x: q.from.x + (q.target.x - q.from.x) * aqEase(min(1, u * 1.4)),
                y: q.from.y + (q.target.y - q.from.y) * arc - 34 * arc
            )
            let tilt = 1.9 * arc + sin(u * .pi * 6) * 0.16 * arc
            drawTool(g, nil, .food, at: pos, tilt: tilt, t: t)
        case .wiper:
            let sweepX = q.target.x + sin(u * .pi * 3) * 44
            let sweepY = q.target.y + cos(u * .pi * 2) * 28
            let pos = CGPoint(
                x: q.from.x + (sweepX - q.from.x) * sin(min(1, u * 1.35) * .pi * 0.5),
                y: q.from.y + (sweepY - q.from.y) * sin(min(1, u * 1.35) * .pi * 0.5)
            )
            var wg = g
            wg.opacity = Double(min(1, (1 - u) * 3))
            drawTool(wg, sim, .wiper, at: pos, tilt: sin(u * .pi * 3) * 0.18, t: t)
        case .net:
            let pos = sim.netScoopPosition(u: u, from: q.from, target: q.target)
            let tilt = -0.35 + sin(u * .pi * 2) * 0.45
            var ng = g
            ng.opacity = Double(min(1, min(u * 6, (1 - u) * 4)))
            drawTool(ng, nil, .net, at: pos, tilt: tilt, t: t)
        }
    }

    static func drawTool(_ g: GraphicsContext, _ sim: AquariumSim?, _ tool: AquaTool, at p: CGPoint, tilt: CGFloat, t: CGFloat) {
        var c = g
        c.translateBy(x: p.x, y: p.y)
        switch tool {
        case .food:
            c.rotate(by: .radians(Double(tilt)))
            AquaDecorPainter.shaker(c)
        case .wiper:
            c.rotate(by: .radians(Double(tilt)))
            if sim != nil { c.scaleBy(x: AquariumSim.wiperScale, y: AquariumSim.wiperScale) }
            AquaDecorPainter.wiper(c)
        case .hoop:
            c.rotate(by: .radians(Double(tilt)))
            c.scaleBy(x: 1.35, y: 1.35)
            AquaDecorPainter.hoopIcon(c, time: t)
        case .net:
            var a: Double = -0.38
            if let s = sim { a = FingerLift.turn(tip: .zero, center: CGPoint(x: 0, y: 80), finger: s.hold, lifted: s.toolP) }
            c.rotate(by: .radians(a + Double(tilt)))
            AquaDecorPainter.netBack(c)
            if let s = sim, let id = s.caught, let f = s.fish.first(where: { $0.id == id }) {
                var fc = c
                fc.translateBy(x: 0, y: 14)
                fc.scaleBy(x: 0.8 * f.dir, y: 0.8)
                AquaFishPainter.drawLocal(fc, kind: f.kind, variant: f.variant, phase: f.phase, amp: 0.5, gulp: 0.6, puff: f.puff, time: t)
            }
            AquaDecorPainter.netFront(c)
        case .fish(let k):
            c.rotate(by: .radians(Double(tilt)))
            AquaDecorPainter.bag(c, kind: k, time: t)
        case .decor(let k):
            c.rotate(by: .radians(Double(tilt)))
            var d = AquaDecor(id: 7, kind: k, x: 0, y: k.size.height * 0.5)
            d.held = true
            AquaDecorPainter.draw(c, d, time: t)
        }
    }
}
