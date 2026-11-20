import SwiftUI

// MARK: - The tank, drawn
//
// Two layers, like the Garden: a slow one at 30 fps (the room, the back of the tank, light rays, the sand and its
// caustics) and a moving one at 60 fps (everything that swims, sinks, rises or sways, the surface, the glass).
// Things of one look are put into one path (all bubbles, all flakes of a color, all splash drops) so a busy tank is
// still only a few hundred fills.

struct AMap {
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

enum AquaPainter {
    // MARK: Slow layer

    static func drawBackdrop(_ ctx: GraphicsContext, map: AMap, sim: AquariumSim) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let r = map.visible
        let t = CGFloat(sim.time)
        let n = sim.night
        room(g, r, n)
        water(g, n, t)
        sand(g, n, t)
    }

    private static func room(_ g: GraphicsContext, _ r: CGRect, _ n: CGFloat) {
        let top = ARGB(0xFFE7F1).mix(ARGB(0x3C355E), n)
        let bottom = ARGB(0xF6D5E8).mix(ARGB(0x2B2647), n)
        g.fill(Path(r), with: .linearGradient(Gradient(colors: [top.color, bottom.color]),
                                              startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: r.maxY)))
        g.fill(AquaPainter.wallpaper, with: .color(.white.opacity(Double(0.22 * (1 - n)))))
        // the cabinet the tank stands on
        let wood = ARGB(0xC98B5B).mix(ARGB(0x4A3A4A), n * 0.7)
        let cab = Path(CGRect(x: 18, y: AGeo.bottomY + 8, width: 988, height: 834 - AGeo.bottomY))
        g.fill(cab, with: .linearGradient(Gradient(colors: [wood.shade(0.12).color, wood.color, wood.shade(-0.2).color]),
                                          startPoint: CGPoint(x: 0, y: AGeo.bottomY), endPoint: CGPoint(x: 0, y: 834)))
        let edge = Path(roundedRect: CGRect(x: 10, y: AGeo.bottomY + 4, width: 1004, height: 16), cornerRadius: 5)
        g.fill(edge, with: .color(wood.shade(0.22).color))
        g.stroke(edge, with: .color(wood.shade(-0.4).color(0.7)), lineWidth: 1.5)
        var lines = Path()
        lines.move(to: CGPoint(x: 512, y: AGeo.bottomY + 22)); lines.addLine(to: CGPoint(x: 512, y: 834))
        g.stroke(lines, with: .color(wood.shade(-0.35).color(0.6)), lineWidth: 2)
    }

    private static func water(_ g: GraphicsContext, _ n: CGFloat, _ t: CGFloat) {
        let tank = AGeo.tank
        let top = ARGB(0x8FE0F2).mix(ARGB(0x173E6E), n)
        let mid = ARGB(0x45B2DA).mix(ARGB(0x0F2C58), n)
        let deep = ARGB(0x1E73A6).mix(ARGB(0x081B3C), n)
        g.fill(Path(tank), with: .linearGradient(Gradient(colors: [top.color, mid.color, deep.color]),
                                                 startPoint: CGPoint(x: 0, y: AGeo.waterY), endPoint: CGPoint(x: 0, y: AGeo.bottomY)))
        // far-off plants at the back, hazy in the blue
        g.fill(AquaPainter.backPlants, with: .color(deep.mix(ARGB(0x2F8A6A), 0.5).color(0.45)))
        // light from the lamp, shifting with the ripples above
        let day = Double(1 - n)
        if day > 0.02 {
            var beams = Path()
            for k in 0..<6 {
                let x = 110 + CGFloat(k) * 160 + sin(t * 0.21 + CGFloat(k) * 1.9) * 34
                let w0: CGFloat = 26 + 10 * sin(t * 0.5 + CGFloat(k))
                let lean: CGFloat = 60
                beams.move(to: CGPoint(x: x - w0, y: AGeo.waterY))
                beams.addLine(to: CGPoint(x: x + w0, y: AGeo.waterY))
                beams.addLine(to: CGPoint(x: x + lean + w0 * 2.6, y: 640))
                beams.addLine(to: CGPoint(x: x + lean - w0 * 2.2, y: 640))
                beams.closeSubpath()
            }
            g.fill(beams, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.2 * day), Color.white.opacity(0)]),
                                                startPoint: CGPoint(x: 0, y: AGeo.waterY), endPoint: CGPoint(x: 0, y: 620)))
        } else {
            // moonlight through the lid
            var beam = Path()
            beam.move(to: CGPoint(x: 700, y: AGeo.waterY))
            beam.addLine(to: CGPoint(x: 760, y: AGeo.waterY))
            beam.addLine(to: CGPoint(x: 860, y: 640))
            beam.addLine(to: CGPoint(x: 660, y: 640))
            beam.closeSubpath()
            g.fill(beam, with: .linearGradient(Gradient(colors: [ARGB(0xBFD8FF).color(0.16), ARGB(0xBFD8FF).color(0)]),
                                               startPoint: CGPoint(x: 0, y: AGeo.waterY), endPoint: CGPoint(x: 0, y: 640)))
        }
        // the pump's air line down the back right corner
        let tube = Path(roundedRect: CGRect(x: 932, y: AGeo.rimY - 6, width: 8, height: AGeo.sand(936) - AGeo.rimY - 2), cornerRadius: 4)
        g.fill(tube, with: .color(.white.opacity(0.22)))
        g.stroke(tube, with: .color(.white.opacity(0.35)), lineWidth: 1)
    }

    private static func sand(_ g: GraphicsContext, _ n: CGFloat, _ t: CGFloat) {
        let light = ARGB(0xF4E0B6).mix(ARGB(0x3A4A6A), n * 0.8)
        let dark = ARGB(0xD6B583).mix(ARGB(0x26324F), n * 0.8)
        g.fill(AquaPainter.sandPath, with: .linearGradient(Gradient(colors: [light.color, dark.color]),
                                                           startPoint: CGPoint(x: 0, y: 590), endPoint: CGPoint(x: 0, y: AGeo.bottomY)))
        let pebbles = AquaPainter.pebbles
        let tints: [ARGB] = [ARGB(0xFFB7C9), ARGB(0xC9B6FF), ARGB(0x9FB4C8)]
        for i in 0..<3 { g.fill(pebbles[i], with: .color(tints[i].mix(ARGB(0x2A3350), n * 0.7).color(0.85))) }
        g.fill(AquaPainter.grains, with: .color(dark.shade(-0.2).color(0.4)))
        // caustics: the light that the waves above focus into a moving net on the sand
        let day = Double(1 - n * 0.8)
        var net = Path()
        for k in 0..<30 {
            let x = AGeo.left + 20 + CGFloat(k) * 31 + sin(t * 0.8 + CGFloat(k) * 1.7) * 9
            let row = CGFloat(k % 3)
            let y = AGeo.sand(x) + 8 + row * 16 + sin(t * 1.1 + CGFloat(k)) * 3
            let w = 26 + 8 * sin(t * 0.9 + CGFloat(k) * 2.3)
            net.addEllipse(in: CGRect(x: x - w / 2, y: y - 4, width: w, height: 8 + row * 2))
        }
        g.stroke(net, with: .color(.white.opacity(0.28 * day)), lineWidth: 2)
        var back = Path()
        for k in 0..<22 {
            let x = AGeo.left + 30 + CGFloat(k) * 42 + sin(t * 0.6 + CGFloat(k) * 2.1) * 12
            let y = 420 + CGFloat(k % 4) * 34 + sin(t * 0.7 + CGFloat(k)) * 6
            let w = 40 + 10 * sin(t * 0.8 + CGFloat(k) * 1.3)
            back.addEllipse(in: CGRect(x: x - w / 2, y: y - 9, width: w, height: 18))
        }
        g.stroke(back, with: .color(.white.opacity(0.07 * day)), lineWidth: 2)
    }

    // Shapes that never change, built once.
    static let wallpaper: Path = {
        var p = Path()
        for k in 0..<60 {
            let x = -700 + CGFloat(k) * 48
            p.addRect(CGRect(x: x, y: -300, width: 14, height: 1500))
        }
        return p
    }()

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
        for k in 0..<260 {
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
            let h = 120 + aqRand(k, 82) * 200
            let base = AGeo.sand(x0) + 4
            let lean = (aqRand(k, 83) - 0.5) * 50
            p.move(to: CGPoint(x: x0 - 8, y: base))
            p.addQuadCurve(to: CGPoint(x: x0 + lean, y: base - h), control: CGPoint(x: x0 - 16 + lean * 0.2, y: base - h * 0.5))
            p.addQuadCurve(to: CGPoint(x: x0 + 8, y: base), control: CGPoint(x: x0 + 14 + lean * 0.3, y: base - h * 0.45))
            p.closeSubpath()
        }
        return p
    }()

    // MARK: Moving layer

    static func draw(_ ctx: GraphicsContext, map: AMap, sim: AquariumSim) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let t = CGFloat(sim.time)
        // inside the water
        var w = g
        w.clip(to: Path(AGeo.tank))
        for d in sim.decor where !d.held { AquaDecorPainter.draw(w, d, time: t) }
        food(w, sim, under: true)
        bubbles(w, sim, back: true)
        let order = sim.fish.indices.filter { !sim.fish[$0].caught }.sorted { sim.fish[$0].z < sim.fish[$1].z }
        for i in order {
            let f = sim.fish[i]
            AquaFishPainter.draw(w, f, time: t, pitch: sim.fishPitch(f))
        }
        bubbles(w, sim, back: false)
        particlesIn(w, sim)
        food(w, sim, under: false)
        surface(w, sim, t)
        nightAndGlow(w, sim, order, t)
        snail(w, sim, t)
        algae(w, sim)
        // outside
        particlesOut(g, sim, t)
        glassAndFrame(g, sim)
        for d in sim.decor where d.held { AquaDecorPainter.draw(g, d, time: t) }
        tool(g, sim, t)
    }

    private static func food(_ g: GraphicsContext, _ sim: AquariumSim, under: Bool) {
        var paths = [Path(), Path(), Path(), Path()]
        var any = false
        for f in sim.food {
            let low = f.state == .sinking || f.state == .settled
            guard low == under else { continue }
            any = true
            let c = cos(f.rot), s = sin(f.rot)
            let w: CGFloat = 3.2, h: CGFloat = 2.2
            var p = Path()
            p.move(to: CGPoint(x: f.p.x + c * w - s * h, y: f.p.y + s * w + c * h))
            p.addLine(to: CGPoint(x: f.p.x - c * w - s * h, y: f.p.y - s * w + c * h))
            p.addLine(to: CGPoint(x: f.p.x - c * w + s * h, y: f.p.y - s * w - c * h))
            p.addLine(to: CGPoint(x: f.p.x + c * w + s * h * 0.6, y: f.p.y + s * w - c * h))
            p.closeSubpath()
            paths[f.hue].addPath(p)
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
            // a rising bubble flattens a little
            let rect = CGRect(x: b.p.x - r * 1.05, y: b.p.y - r * 0.95, width: r * 2.1, height: r * 1.9)
            rims.addEllipse(in: rect)
            lights.addEllipse(in: CGRect(x: b.p.x - r * 0.55, y: b.p.y - r * 0.6, width: r * 0.55, height: r * 0.45))
        }
        guard any else { return }
        let a = back ? 0.6 : 1.0
        g.fill(rims, with: .color(.white.opacity(0.14 * a)))
        g.stroke(rims, with: .color(.white.opacity(0.7 * a)), lineWidth: 1.1)
        g.fill(lights, with: .color(.white.opacity(0.9 * a)))
    }

    private static func particlesIn(_ g: GraphicsContext, _ sim: AquariumSim) {
        var sandP = Path(), algaeP = Path()
        for q in sim.particles {
            switch q.kind {
            case .sand:
                sandP.addEllipse(in: CGRect(x: q.p.x - q.size / 2, y: q.p.y - q.size / 2, width: q.size, height: q.size))
            case .algae:
                algaeP.addEllipse(in: CGRect(x: q.p.x - q.size / 2, y: q.p.y - q.size / 2, width: q.size, height: q.size * 0.8))
            case .poof:
                let k = Double(1 - q.age / q.life)
                g.fill(AquaShape.circle(q.p, q.size), with: .radialGradient(Gradient(colors: [q.color.color(0.4 * k), q.color.color(0)]),
                                                                           center: q.p, startRadius: 0, endRadius: q.size))
            default:
                break
            }
        }
        g.fill(sandP, with: .color(ARGB(0xE2C996).color(0.9)))
        g.fill(algaeP, with: .color(ARGB(0x6E9A47).color(0.85)))
    }

    private static func surface(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        var line = Path()
        var air = Path()
        let step: CGFloat = 14
        air.move(to: CGPoint(x: AGeo.left, y: AGeo.rimY - 4))
        air.addLine(to: CGPoint(x: AGeo.right, y: AGeo.rimY - 4))
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
        g.fill(air, with: .linearGradient(Gradient(colors: [ARGB(0xF4FBFF).color(0.85 - 0.5 * n), ARGB(0xDDF3FB).color(0.7 - 0.45 * n)]),
                                          startPoint: CGPoint(x: 0, y: AGeo.rimY), endPoint: CGPoint(x: 0, y: AGeo.waterY)))
        // the underside of the surface shines back like a mirror
        var under = g
        under.translateBy(x: 0, y: 7)
        under.stroke(line, with: .color(.white.opacity(0.22 - 0.12 * n)), lineWidth: 8)
        g.stroke(line, with: .color(.white.opacity(0.9 - 0.4 * n)), lineWidth: 2.4)
        // little glints that travel along it
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
        g.fill(Path(AGeo.tank), with: .color(ARGB(0x0A1430).color(Double(0.42 * n))))
        var glow = g
        glow.blendMode = .plusLighter
        // neon tetras' stripes really do shine in the dark
        for i in order where sim.fish[i].kind == .tetra {
            let f = sim.fish[i]
            var c = glow
            c.translateBy(x: f.p.x, y: f.p.y)
            let side: CGFloat = f.facing < 0 ? -1 : 1
            var sx = f.facing
            if abs(sx) < 0.14 { sx = 0.14 * side }
            c.rotate(by: .radians(Double(sim.fishPitch(f) * side)))
            c.scaleBy(x: sx * f.scale, y: f.scale)
            c.opacity = Double(n) * 0.8
            AquaFishPainter.neon(c, AquaFishPainter.tetraBody(phase: f.phase, amp: f.amp))
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
        // the treasure glows when a chest is open
        for d in sim.decor where d.kind == .chest && d.open > 0.05 {
            let c = CGPoint(x: d.x, y: d.y - 46)
            glow.fill(AquaShape.circle(c, 60), with: .radialGradient(Gradient(colors: [ARGB(0xFFE69A).color(0.5 * Double(n * d.open)), ARGB(0xFFE69A).color(0)]),
                                                                     center: c, startRadius: 0, endRadius: 60))
        }
    }

    private static func snail(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        let s = sim.snail
        var c = g
        c.translateBy(x: s.p.x, y: s.p.y)
        c.rotate(by: .radians(Double(s.heading)))
        let ext = 1 - s.hide
        let stretch = 1 + 0.08 * sin(s.phase * 2.2)
        // the foot, flat against the glass
        if ext > 0.05 {
            let foot = Path(roundedRect: CGRect(x: -20 * stretch, y: -9, width: 40 * stretch * ext + 4, height: 18), cornerRadius: 9)
            c.fill(foot, with: .color(ARGB(0xE8D3C0).color(0.95)))
            c.stroke(foot, with: .color(ARGB(0xB89A84).color(0.8)), lineWidth: 1.2)
            // eye stalks
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
        // the shell, a spiral
        let shell = AquaShape.circle(CGPoint(x: -4, y: 0), 15)
        c.fill(shell, with: .radialGradient(Gradient(colors: [ARGB(0xFFD08A).color, ARGB(0xD98A4A).color]),
                                            center: CGPoint(x: -8, y: -4), startRadius: 1, endRadius: 17))
        var spiral = Path()
        var first = true
        for k in 0..<30 {
            let a = CGFloat(k) * 0.42
            let r = 13 - CGFloat(k) * 0.42
            let p = CGPoint(x: -4 + cos(a) * r, y: sin(a) * r)
            if first { spiral.move(to: p); first = false } else { spiral.addLine(to: p) }
        }
        c.stroke(spiral, with: .color(ARGB(0x9A5A2E).color(0.7)), lineWidth: 1.6)
        c.stroke(shell, with: .color(ARGB(0x9A5A2E).color(0.8)), lineWidth: 1.4)
    }

    private static func algae(_ g: GraphicsContext, _ sim: AquariumSim) {
        let p = sim.algaePaths
        let c = ARGB(0x6F9E48)
        g.fill(p[0], with: .color(c.color(0.2)))
        g.fill(p[1], with: .color(c.color(0.36)))
        g.fill(p[2], with: .color(c.shade(-0.1).color(0.52)))
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
                g.stroke(Path(ellipseIn: CGRect(x: q.p.x - r, y: q.p.y - r * (q.size > 30 ? 1 : 0.35), width: r * 2, height: r * 2 * (q.size > 30 ? 1 : 0.35))),
                         with: .color(.white.opacity(Double(0.8 * (1 - k)))), lineWidth: 2)
            case .heart:
                let k = Double(1 - q.age / q.life)
                g.fill(AquaShape.heart(q.p, q.size), with: .color(q.color.color(0.95 * k)))
                g.stroke(AquaShape.heart(q.p, q.size), with: .color(.white.opacity(0.8 * k)), lineWidth: 1.4)
            case .sparkle:
                let k = q.age / q.life
                let s = q.size * sin(k * .pi)
                if s > 0.5 { g.fill(Twinkle().path(in: CGRect(x: q.p.x - s, y: q.p.y - s, width: s * 2, height: s * 2)), with: .color(.white.opacity(0.95))) }
            default:
                break
            }
        }
        g.fill(drops, with: .color(ARGB(0xE4F7FF).color(0.85)))
    }

    private static func glassAndFrame(_ g: GraphicsContext, _ sim: AquariumSim) {
        let n = Double(sim.night)
        // glare on the front glass
        var glare = Path()
        glare.move(to: CGPoint(x: 90, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 150, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 70, y: AGeo.bottomY - 10))
        glare.addLine(to: CGPoint(x: 52, y: AGeo.bottomY - 10))
        glare.closeSubpath()
        glare.move(to: CGPoint(x: 172, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 186, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 100, y: AGeo.bottomY - 10))
        glare.addLine(to: CGPoint(x: 92, y: AGeo.bottomY - 10))
        glare.closeSubpath()
        glare.move(to: CGPoint(x: 880, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 900, y: AGeo.rimY + 6))
        glare.addLine(to: CGPoint(x: 846, y: 420))
        glare.addLine(to: CGPoint(x: 834, y: 420))
        glare.closeSubpath()
        g.fill(glare, with: .color(.white.opacity(0.1 * (1 - n * 0.6))))
        // the frame: corner posts, a lid with the lamp, and the base
        let frame = ARGB(0x4E6E8C).mix(ARGB(0x2A3550), CGFloat(n) * 0.6)
        var posts = Path()
        posts.addRoundedRect(in: CGRect(x: AGeo.left - 16, y: AGeo.rimY - 18, width: 16, height: AGeo.bottomY - AGeo.rimY + 32), cornerSize: CGSize(width: 5, height: 5))
        posts.addRoundedRect(in: CGRect(x: AGeo.right, y: AGeo.rimY - 18, width: 16, height: AGeo.bottomY - AGeo.rimY + 32), cornerSize: CGSize(width: 5, height: 5))
        posts.addRect(CGRect(x: AGeo.left - 16, y: AGeo.bottomY, width: AGeo.width + 32, height: 14))
        g.fill(posts, with: .linearGradient(Gradient(colors: [frame.shade(0.2).color, frame.color, frame.shade(-0.25).color]),
                                            startPoint: CGPoint(x: 0, y: AGeo.rimY), endPoint: CGPoint(x: 0, y: AGeo.bottomY + 14)))
        let lid = Path(roundedRect: CGRect(x: AGeo.left - 22, y: AGeo.rimY - 30, width: AGeo.width + 44, height: 26), cornerRadius: 8)
        g.fill(lid, with: .linearGradient(Gradient(colors: [frame.shade(0.3).color, frame.color]),
                                          startPoint: CGPoint(x: 0, y: AGeo.rimY - 30), endPoint: CGPoint(x: 0, y: AGeo.rimY - 4)))
        g.stroke(lid, with: .color(frame.shade(-0.4).color), lineWidth: 1.5)
        g.stroke(posts, with: .color(frame.shade(-0.4).color(0.8)), lineWidth: 1.2)
        // the lamp strip under the lid
        let lamp = Path(CGRect(x: AGeo.left + 10, y: AGeo.rimY - 6, width: AGeo.width - 20, height: 4))
        g.fill(lamp, with: .color(ARGB(0xFFF6D8).mix(ARGB(0x6A7AA8), CGFloat(n)).color))
    }

    private static func tool(_ g: GraphicsContext, _ sim: AquariumSim, _ t: CGFloat) {
        if let tl = sim.tool {
            var see = g
            let working: Bool
            switch tl {
            case .sponge, .net: working = AGeo.tank.contains(sim.toolP)
            default: working = false
            }
            if working { see.opacity = tl == .sponge ? 0.75 : 0.85 }
            drawTool(see, sim, tl, at: sim.toolP, tilt: sim.tilt, t: t)
            switch tl {
            case .sponge, .net, .food:
                if AGeo.tank.contains(sim.toolP) { FingerLift.drawTip(g, at: sim.toolP, time: Double(t)) }
            default:
                break
            }
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

    static func drawTool(_ g: GraphicsContext, _ sim: AquariumSim?, _ tool: AquaTool, at p: CGPoint, tilt: CGFloat, t: CGFloat) {
        var c = g
        c.translateBy(x: p.x, y: p.y)
        switch tool {
        case .food:
            c.rotate(by: .radians(Double(tilt)))
            AquaDecorPainter.shaker(c)
        case .sponge:
            c.rotate(by: .radians(Double(tilt)))
            AquaDecorPainter.sponge(c)
        case .net:
            var a: Double = 0
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
