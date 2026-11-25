import SwiftUI

// MARK: - Luminous Fluid Texture

final class PotionLiquid {
    private var buf = [UInt8](repeating: 0, count: PotionGeometry.NX * PotionGeometry.NY * 4)
    private var img: CGImage?
    private var key = -1

    func image(_ sim: PotionSim) -> CGImage? {
        if key == sim.version, let i = img { return i }
        key = sim.version
        let n = PotionGeometry.NX * PotionGeometry.NY
        let water = PotionColor.clearWater
        for k in 0..<n {
            let a = sim.da[k]
            let o = k * 4
            if sim.solid[k] && a <= 0.0001 && sim.dr[k] == 0 {
                buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0; buf[o + 3] = 0
                continue
            }
            var r = water.r
            var g = water.g
            var b = water.b
            if a > 0.002 {
                let raw = RGB(Double(sim.dr[k] / a), Double(sim.dg[k] / a), Double(sim.db[k] / a))
                let vivid = PotionColor.luminous(raw)
                let m = Double(min(1, a * 2.1))
                r += (vivid.r - r) * m
                g += (vivid.g - g) * m
                b += (vivid.b - b) * m
            }
            let op = 0.24 + 0.70 * (1 - exp(-1.7 * Double(a)))
            buf[o] = UInt8(max(0, min(1, r)) * op * 255)
            buf[o + 1] = UInt8(max(0, min(1, g)) * op * 255)
            buf[o + 2] = UInt8(max(0, min(1, b)) * op * 255)
            buf[o + 3] = UInt8(op * 255)
        }
        guard let provider = CGDataProvider(data: Data(buf) as CFData) else { return nil }
        img = CGImage(
            width: PotionGeometry.NX,
            height: PotionGeometry.NY,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: PotionGeometry.NX * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
        return img
    }
}

// MARK: - Full-Bleed Apothecary Background (for GameStage)

struct PotionBackdropView: View {
    let moonlit: Bool

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
            let n = moonlit ? 1.0 : 0.0
            let wallTop = RGB(hex: "#DEC9FA").mix(RGB(hex: "#32265E"), n)
            let wallBot = RGB(hex: "#C5A8EE").mix(RGB(hex: "#231A46"), n)

            g.fill(
                Path(CGRect(x: v.minX, y: v.minY, width: v.width, height: max(0, PotionGeometry.tableY - v.minY))),
                with: .linearGradient(
                    Gradient(colors: [wallTop.c(), wallBot.c()]),
                    startPoint: CGPoint(x: 0, y: v.minY),
                    endPoint: CGPoint(x: 0, y: PotionGeometry.tableY)
                )
            )

            var stones = Path()
            var row = 0
            var y: CGFloat = (v.minY / 60).rounded(.down) * 60
            while y < PotionGeometry.tableY {
                let off: CGFloat = row % 2 == 0 ? 0 : 60
                var x = (v.minX / 120).rounded(.down) * 120 - 120 + off
                while x < v.maxX {
                    stones.addRoundedRect(in: CGRect(x: x + 4, y: y + 4, width: 112, height: 52), cornerSize: CGSize(width: 14, height: 14))
                    x += 120
                }
                y += 60
                row += 1
            }
            g.stroke(stones, with: .color(.white.opacity(0.11 - 0.05 * n)), lineWidth: 2.5)

            let topRect = CGRect(x: v.minX, y: PotionGeometry.tableY - 4, width: v.width, height: 30)
            let woodTop = RGB(hex: "#DCA376").mix(RGB(hex: "#8F6044"), n * 0.55)
            let woodMid = RGB(hex: "#C48A62").mix(RGB(hex: "#734B36"), n * 0.55)
            g.fill(
                Path(topRect),
                with: .linearGradient(
                    Gradient(colors: [woodTop.c(), woodMid.c()]),
                    startPoint: CGPoint(x: 0, y: topRect.minY),
                    endPoint: CGPoint(x: 0, y: topRect.maxY)
                )
            )
            g.fill(Path(CGRect(x: v.minX, y: PotionGeometry.tableY - 4, width: v.width, height: 3.5)), with: .color(.white.opacity(0.32)))

            let apronRect = CGRect(x: v.minX, y: PotionGeometry.tableY + 26, width: v.width, height: max(0, v.maxY - PotionGeometry.tableY - 26))
            let apronCol = RGB(hex: "#9B6644").mix(RGB(hex: "#583728"), n * 0.6)
            g.fill(Path(apronRect), with: .color(apronCol.c()))
            var planks = Path()
            var px = (v.minX / 128).rounded(.down) * 128
            while px < v.maxX {
                planks.move(to: CGPoint(x: px, y: apronRect.minY))
                planks.addLine(to: CGPoint(x: px, y: apronRect.maxY))
                px += 128
            }
            g.stroke(planks, with: .color(.black.opacity(0.11)), lineWidth: 3)
        }
    }
}

// MARK: - Stage Painter (1024 x 834 design coordinates)

enum PotionPainter {
    static let woodHex: UInt32 = 0xC48A62
    static let woodDarkHex: UInt32 = 0x8F5C3E
    static let brassHex: UInt32 = 0xE8BC5E
    static let brassDarkHex: UInt32 = 0xAE7E32
    static let glassLine = RGB(hex: "#F2EBFF")

    static func drawStage(_ g: GraphicsContext, sim: PotionSim, liquid: PotionLiquid) {
        let t = CGFloat(sim.time)
        let n = Double(sim.night)

        drawRoom(g, night: n, t: t)
        drawAmbientLight(g, sim: sim, night: n, t: t)
        drawCushion(g, t: t)
        drawCreature(g, sim: sim, t: t)

        drawBasin(g, sim: sim)
        drawBurner(g, sim: sim, t: t)
        drawFlameDial(g, sim: sim)
        drawTripod(g, front: false)
        drawCauldron(g, sim: sim, liquid: liquid, t: t)
        drawTripod(g, front: true)
        drawDrainPipeAndValve(g, sim: sim)

        drawTastingStand(g, sim: sim, t: t)
        drawDrops(g, sim: sim)
        drawAirPieces(g, sim: sim)
        drawPourArcs(g, sim: sim, t: t)
        drawFlyers(g, sim: sim, t: t)
        drawMotes(g, sim: sim, t: t)
        drawDraggedItems(g, sim: sim, t: t)
    }

    // MARK: Open Sky Window & Apothecary Arch (Zero Shelves Above Creature!)

    private static func drawRoom(_ g: GraphicsContext, night n: Double, t: CGFloat) {
        // Open arched sky window directly behind the Left Magical Friend Nook (completely clear for floating!).
        drawArchWindow(g, rect: CGRect(x: 48, y: 112, width: 274, height: 344), night: n, t: t, showMoon: true)
        // Secondary sunlit/starlit arch behind the cauldron.
        drawArchWindow(g, rect: CGRect(x: 416, y: 114, width: 248, height: 274), night: n, t: t, showMoon: false)
        // Delicate fairy lights draped high near the ceiling.
        drawFairyLights(g, night: n, t: t)
    }

    private static func archPath(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX
        let rad = r.width / 2
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
        for k in 1...28 {
            let a = Double.pi + Double.pi * Double(k) / 28
            p.addLine(to: CGPoint(x: cx + rad * CGFloat(cos(a)), y: r.minY + rad + rad * CGFloat(sin(a))))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    private static func drawArchWindow(_ g: GraphicsContext, rect: CGRect, night n: Double, t: CGFloat, showMoon: Bool) {
        let outer = archPath(in: rect)
        let inner = archPath(in: rect.insetBy(dx: 12, dy: 12))
        StorybookArt.shape(g, outer, hex: woodHex, width: 3)

        let skyTop = RGB(hex: "#FFD2EA").mix(RGB(hex: "#18154E"), n)
        let skyBot = RGB(hex: "#C8E4FF").mix(RGB(hex: "#3E3084"), n)
        g.fill(
            inner,
            with: .linearGradient(
                Gradient(colors: [skyTop.c(), skyBot.c()]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )

        var sky = g
        sky.clip(to: inner)
        if n < 0.99 {
            var cl = sky
            cl.opacity = 1 - n
            for k in 0..<3 {
                let span = rect.width + 110
                let x = rect.minX - 40 + ((t * 7 + CGFloat(k) * (span / 3)).truncatingRemainder(dividingBy: span))
                let y = rect.minY + 62 + CGFloat(k) * 56
                var c = Path()
                c.addEllipse(in: CGRect(x: x, y: y, width: 68, height: 24))
                c.addEllipse(in: CGRect(x: x + 18, y: y - 13, width: 44, height: 32))
                c.addEllipse(in: CGRect(x: x + 42, y: y - 4, width: 46, height: 24))
                cl.fill(c, with: .color(.white.opacity(0.86)))
            }
        }
        if n > 0.01 {
            var nt = sky
            nt.opacity = n
            for k in 0..<18 {
                let x = rect.minX + 20 + CGFloat((k * 73) % Int(max(40, rect.width - 40)))
                let y = rect.minY + 24 + CGFloat((k * 47) % Int(max(40, rect.height - 48)))
                let tw = 0.5 + 0.5 * sin(Double(t) * 2.2 + Double(k) * 1.5)
                let s = 2.5 + 3.2 * CGFloat(tw)
                StorybookArt.sparkle(nt, at: CGPoint(x: x, y: y), radius: s, color: .white, opacity: 0.45 + 0.55 * tw)
            }
            if showMoon {
                let m = CGRect(x: rect.maxX - 88, y: rect.minY + 46, width: 52, height: 52)
                nt.fill(
                    Path(ellipseIn: m.insetBy(dx: -18, dy: -18)),
                    with: .radialGradient(
                        Gradient(colors: [RGB(hex: "#FFF4C4").c(0.45), .clear]),
                        center: CGPoint(x: m.midX, y: m.midY),
                        startRadius: 16,
                        endRadius: 42
                    )
                )
                var moon = Path(ellipseIn: m)
                moon.addEllipse(in: m.offsetBy(dx: 16, dy: -8))
                nt.fill(moon, with: .color(RGB(hex: "#FFF2BC").c()), style: FillStyle(eoFill: true))
            }
        }

        // Delicate window muntins and sill.
        var bars = Path()
        bars.move(to: CGPoint(x: rect.midX, y: rect.minY + 12))
        bars.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 12))
        bars.move(to: CGPoint(x: rect.minX + 12, y: rect.midY + 14))
        bars.addLine(to: CGPoint(x: rect.maxX - 12, y: rect.midY + 14))
        g.stroke(bars, with: .color(StorybookArt.color(woodHex)), lineWidth: 8)
        g.stroke(inner, with: .color(StorybookArt.outline(for: woodHex).opacity(0.65)), lineWidth: 2.5)
        let sill = Path(roundedRect: CGRect(x: rect.minX - 10, y: rect.maxY - 8, width: rect.width + 20, height: 16), cornerRadius: 6)
        StorybookArt.shape(g, sill, hex: woodHex, width: 2.5)
    }

    private static func drawFairyLights(_ g: GraphicsContext, night n: Double, t: CGFloat) {
        var wire = Path()
        var bulbs: [CGPoint] = []
        let spans: [(CGFloat, CGFloat)] = [(20, 345), (695, 1004)]
        for (a, b) in spans {
            wire.move(to: CGPoint(x: a, y: 98))
            wire.addQuadCurve(to: CGPoint(x: b, y: 98), control: CGPoint(x: (a + b) / 2, y: 132))
            let cnt = 6
            for k in 1..<cnt {
                let u = CGFloat(k) / CGFloat(cnt)
                let x = a + (b - a) * u
                let y = 98 + 68 * u * (1 - u)
                bulbs.append(CGPoint(x: x, y: y))
            }
        }
        g.stroke(wire, with: .color(Theme.ink.opacity(0.45)), lineWidth: 2)
        let cols: [RGB] = [RGB(hex: "#FFA2CE"), RGB(hex: "#FFE480"), RGB(hex: "#9EEAFF"), RGB(hex: "#CCB0FF"), RGB(hex: "#A8F0C4")]
        for (k, p) in bulbs.enumerated() {
            let c = cols[k % cols.count]
            let tw = 0.72 + 0.28 * sin(Double(t) * 2.5 + Double(k) * 1.4)
            if n > 0.05 {
                g.fill(
                    Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 12, width: 36, height: 36)),
                    with: .radialGradient(
                        Gradient(colors: [c.c(0.55 * n * tw), .clear]),
                        center: CGPoint(x: p.x, y: p.y + 6),
                        startRadius: 2,
                        endRadius: 18
                    )
                )
            }
            g.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y, width: 10, height: 13)), with: .color(c.mix(RGB(1, 1, 1), 0.25 * tw).c()))
        }
    }

    private static func drawAmbientLight(_ g: GraphicsContext, sim: PotionSim, night n: Double, t: CGFloat) {
        let (mc, ma) = sim.meanColor()
        let potionColor = PotionColor.clearWater.mix(mc, Double(min(1, ma * 2)))
        let glow = sim.cauldronGlow
        if glow > 0.04 && sim.volume > 200 {
            var lg = g
            lg.blendMode = .plusLighter
            let k = Double(glow) * (0.16 + 0.42 * n)
            let c = PotionGeometry.cauldronCenter
            lg.fill(
                Path(ellipseIn: CGRect(x: c.x - 320, y: c.y - 290, width: 640, height: 580)),
                with: .radialGradient(
                    Gradient(colors: [potionColor.c(k), potionColor.c(k * 0.35), .clear]),
                    center: c,
                    startRadius: 28,
                    endRadius: 310
                )
            )
        }
        if sim.burner != .off {
            var fg = g
            fg.blendMode = .plusLighter
            let intensity = sim.burner == .boil ? 0.22 : 0.12
            let flick = 0.03 * sin(Double(t) * 14)
            let bc = PotionGeometry.burnerCenter
            fg.fill(
                Path(ellipseIn: CGRect(x: bc.x - 170, y: bc.y - 110, width: 340, height: 180)),
                with: .radialGradient(
                    Gradient(colors: [RGB(hex: "#FFA84C").c((intensity + flick) * (0.55 + n * 0.8)), .clear]),
                    center: bc,
                    startRadius: 10,
                    endRadius: 165
                )
            )
        }
    }

    // MARK: Left Stage — Plush Starry Cushion & Magical Friend

    private static func drawCushion(_ g: GraphicsContext, t: CGFloat) {
        let c = PotionGeometry.cushionCenter
        // Soft ground shadow.
        g.fill(
            Path(ellipseIn: CGRect(x: c.x - 112, y: c.y + 18, width: 224, height: 24)),
            with: .color(Theme.ink.opacity(0.18))
        )
        // Plush tufted cushion body.
        let body = Path(roundedRect: CGRect(x: c.x - 104, y: c.y - 16, width: 208, height: 48), cornerRadius: 24)
        StorybookArt.shape(g, body, hex: 0xC6A2F8, width: 3.5)
        let top = Path(ellipseIn: CGRect(x: c.x - 94, y: c.y - 18, width: 188, height: 32))
        g.fill(top, with: .color(Color(hex: 0xDFC4FF)))
        StorybookArt.highlight(g, in: CGRect(x: c.x - 62, y: c.y - 12, width: 64, height: 10), opacity: 0.42)
        // Little gold tassels at each corner.
        for side in [-1.0, 1.0] {
            let tx = c.x + CGFloat(side) * 102
            let tassel = Path(ellipseIn: CGRect(x: tx - 9, y: c.y + 2, width: 18, height: 16))
            StorybookArt.shape(g, tassel, hex: 0xFFE07A, width: 2.5)
        }
        // Star embroidery along the front cushion rim.
        for dx in [-54, 0, 54] {
            let pulse = 0.8 + 0.2 * sin(Double(t) * 2.4 + Double(dx))
            StorybookArt.sparkle(g, at: CGPoint(x: c.x + CGFloat(dx), y: c.y + 14), radius: 7.5, color: Theme.lemon, opacity: pulse)
        }
    }

    private static func drawCreature(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        let cs = sim.creatureState
        let effect = cs.activeEffect
        let feet = CGPoint(x: PotionGeometry.creatureFeet.x, y: PotionGeometry.creatureFeet.y + cs.floatY + cs.hop)
        let k = PotionGeometry.creatureScale

        // Shadow shrinks softly as creature floats higher into the sky window.
        let lift = min(1, -(cs.floatY + cs.hop) / 160)
        let sw = 156 * (1 - lift * 0.42)
        g.fill(
            Path(ellipseIn: CGRect(x: PotionGeometry.creatureFeet.x - sw / 2, y: PotionGeometry.creatureFeet.y - 8, width: sw, height: 16)),
            with: .color(Theme.ink.opacity(0.18 * Double(1 - lift * 0.6)))
        )

        // Back-layer transformation auras (rainbow arch, sleepy cloud pillow, moonlight crescent, golden/galaxy/mermaid halo).
        drawCreatureBackEffects(g, effect: effect, feet: feet, tint: cs.tint, t: t)

        var pet = sim.creature.petLook
        pet.glitter = (effect == .galaxy || effect == .golden || effect == .rainbow || effect == .moonlight || effect == .wild)

        var pose = PetPose()
        pose.time = Double(t)
        if effect == .sleepyCloud {
            pose.eyes = "blink"
            pose.mouth = "smile"
        } else if cs.hiccupKick > 0.25 {
            pose.eyes = "wince"
            pose.mouth = "o"
        } else if effect == .love || cs.giggle > 0 {
            pose.eyes = "happy"
            pose.mouth = "grin"
        } else if effect == .frostCrown {
            pose.eyes = "wince"
            pose.mouth = "wavy"
        } else if effect?.isFloating == true {
            pose.eyes = "sparkle"
            pose.mouth = "o"
        } else if effect != nil {
            pose.eyes = "sparkle"
            pose.mouth = "grin"
        } else if cs.blink < 0 {
            pose.eyes = "blink"
        }

        let head = CGPoint(x: feet.x, y: feet.y - (PetArt.feetY - PetArt.headCenter.y) * k)
        let lx = max(-1, min(1, (cs.look.x - head.x) / 280))
        let ly = max(-1, min(1, (cs.look.y - head.y) / 280))
        pose.look = CGSize(width: lx * 7, height: ly * 5)

        let danceSquash: CGFloat = (effect == .rainbow || effect == .wild) ? 0.045 * sin(t * 7.5) : 0
        pose.squash = 1 + 0.015 * sin(t * 2.4) + danceSquash - cs.hiccupKick * 0.08 + (cs.hopV < -90 ? 0.05 : 0)

        var tilt = 0.0
        if cs.shake > 0 { tilt += sin(Double(t) * 38) * 11 * Double(min(1, cs.shake * 2)) }
        if effect == .frostCrown { tilt += sin(Double(t) * 44) * 3.2 }
        if effect == .sleepyCloud { tilt += sin(Double(t) * 1.8) * 6.5 }
        if effect == .rainbow || effect == .wild { tilt += sin(Double(t) * 6.0) * 6.0 }
        pose.tilt = tilt

        var shading: GraphicsContext.Shading?
        if effect == .rainbow {
            let rainbow = ["#FF8FB8", "#FFB27A", "#FFE27A", "#8FE0A4", "#7FC8FF", "#B89CFF"].map { RGB(hex: $0).c() }
            shading = .linearGradient(Gradient(colors: rainbow), startPoint: CGPoint(x: 120, y: 60), endPoint: CGPoint(x: 480, y: 620))
        } else if effect == .wild {
            let c1 = PotionColor.hue(t * 0.35).c()
            let c2 = PotionColor.hue(t * 0.35 + 0.33).c()
            let c3 = PotionColor.hue(t * 0.35 + 0.66).c()
            shading = .linearGradient(Gradient(colors: [c1, c2, c3]), startPoint: CGPoint(x: 120, y: 80), endPoint: CGPoint(x: 480, y: 600))
        } else if effect == .frostCrown {
            shading = .color(RGB(hex: "#B8F0FF").c())
        } else if effect == .golden {
            shading = .color(RGB(hex: "#FFD966").c())
        } else if cs.tintAmt > 0.05 {
            shading = .color(RGB(hex: "#FFF4FC").mix(cs.tint, Double(min(0.85, cs.tintAmt))).c())
        }

        let animal = PetArt.shared.animals[pet.kind]
        var pg = g
        pg.translateBy(x: feet.x, y: feet.y)
        pg.scaleBy(x: k, y: k)
        pg.translateBy(x: -300, y: -PetArt.feetY)

        PetPainter.draw(
            pet,
            pose: pose,
            furShading: shading,
            over: { ctx in
                drawCreatureHeadOverlays(ctx, effect: effect, animal: animal, hiccupKick: cs.hiccupKick, t: t)
            },
            in: pg
        )

        // Front-layer transformation effects (giant iridescent bubble, orbiting galaxy stars).
        drawCreatureFrontEffects(g, effect: effect, feet: feet, t: t)
    }

    private static func drawCreatureBackEffects(_ g: GraphicsContext, effect: TransformationEffect?, feet: CGPoint, tint: RGB, t: CGFloat) {
        guard let effect else { return }
        let bodyCenter = CGPoint(x: feet.x, y: feet.y - 102)
        switch effect {
        case .rainbow:
            let bands: [Color] = [
                Color(hex: 0xFF8FB8), Color(hex: 0xFFB87A), Color(hex: 0xFFE582),
                Color(hex: 0x9AE8B0), Color(hex: 0x86D4FF), Color(hex: 0xC6A2FF),
            ]
            for (i, col) in bands.enumerated() {
                let r = CGFloat(132 - i * 10) + sin(t * 3 + CGFloat(i)) * 2
                var arc = Path()
                arc.addArc(center: CGPoint(x: feet.x, y: feet.y - 24), radius: r, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
                g.stroke(arc, with: .color(col.opacity(0.65)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            }
        case .sleepyCloud:
            // Floating glowing cloud pillow right under the swaying friend.
            let cy = feet.y - 6 + sin(t * 2.0) * 5
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: feet.x - 106, y: cy - 28, width: 212, height: 64))
            cloud.addEllipse(in: CGRect(x: feet.x - 86, y: cy - 48, width: 88, height: 66))
            cloud.addEllipse(in: CGRect(x: feet.x - 8, y: cy - 52, width: 96, height: 70))
            g.stroke(cloud, with: .color(Color(hex: 0xC8B4FF)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            g.fill(cloud, with: .color(Color(hex: 0xFAF6FF)))
        case .moonlight:
            // Glowing crescent halo behind head.
            let c = CGPoint(x: feet.x, y: feet.y - 148)
            var gl = g
            gl.blendMode = .plusLighter
            gl.fill(
                Path(ellipseIn: CGRect(x: c.x - 125, y: c.y - 125, width: 250, height: 250)),
                with: .radialGradient(Gradient(colors: [Color(hex: 0xE6DFFF).opacity(0.55), .clear]), center: c, startRadius: 18, endRadius: 125)
            )
            let mRect = CGRect(x: c.x - 66, y: c.y - 66, width: 132, height: 132)
            var moon = Path(ellipseIn: mRect)
            moon.addEllipse(in: mRect.offsetBy(dx: 32, dy: -14))
            g.fill(moon, with: .color(Color(hex: 0xFFF4B8).opacity(0.85)), style: FillStyle(eoFill: true))
        case .golden:
            var gl = g
            gl.blendMode = .plusLighter
            let pulse = 0.42 + 0.12 * sin(Double(t) * 3.5)
            gl.fill(
                Path(ellipseIn: CGRect(x: bodyCenter.x - 148, y: bodyCenter.y - 148, width: 296, height: 296)),
                with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE27A).opacity(pulse), .clear]), center: bodyCenter, startRadius: 20, endRadius: 148)
            )
        case .galaxy:
            var gl = g
            gl.blendMode = .plusLighter
            gl.fill(
                Path(ellipseIn: CGRect(x: bodyCenter.x - 140, y: bodyCenter.y - 140, width: 280, height: 280)),
                with: .radialGradient(Gradient(colors: [Color(hex: 0x9C72FF).opacity(0.52), Color(hex: 0x5632C8).opacity(0.22), .clear]), center: bodyCenter, startRadius: 20, endRadius: 140)
            )
        case .mermaid:
            var gl = g
            gl.blendMode = .plusLighter
            gl.fill(
                Path(ellipseIn: CGRect(x: bodyCenter.x - 142, y: bodyCenter.y - 142, width: 284, height: 284)),
                with: .radialGradient(Gradient(colors: [Color(hex: 0x56F2E8).opacity(0.45), .clear]), center: bodyCenter, startRadius: 24, endRadius: 142)
            )
        case .love, .dragonFire, .frostCrown, .bubbleFloat, .wild:
            var gl = g
            gl.blendMode = .plusLighter
            gl.fill(
                Path(ellipseIn: CGRect(x: bodyCenter.x - 125, y: bodyCenter.y - 125, width: 250, height: 250)),
                with: .radialGradient(Gradient(colors: [tint.c(0.28), .clear]), center: bodyCenter, startRadius: 18, endRadius: 125)
            )
        }
    }

    private static func drawCreatureHeadOverlays(
        _ ctx: GraphicsContext,
        effect: TransformationEffect?,
        animal: PetAnimal?,
        hiccupKick: CGFloat,
        t: CGFloat
    ) {
        guard let effect else { return }
        let hat = animal?.hat ?? CGPoint(x: 300, y: 134)
        let leftEye = animal?.eyeAnchor ?? CGPoint(x: 238, y: 270)
        let rightEye = CGPoint(x: 600 - leftEye.x, y: leftEye.y)

        switch effect {
        case .love:
            // Big sparkling pink heart eyes!
            let pulse: CGFloat = 1 + 0.1 * sin(t * 7)
            for eye in [leftEye, rightEye] {
                StorybookArt.heart(ctx, at: eye, size: 58 * pulse, color: Color(hex: 0xFF4F9A))
                StorybookArt.sparkle(ctx, at: CGPoint(x: eye.x - 10, y: eye.y - 10), radius: 10, color: .white, opacity: 0.92)
            }
        case .dragonFire:
            // Puffed rosy cheeks!
            let puff: CGFloat = 1 + 0.25 * hiccupKick + 0.08 * sin(t * 8)
            for cx in [leftEye.x - 36, rightEye.x + 36] {
                let r = CGRect(x: cx - 34 * puff, y: leftEye.y + 28 - 26 * puff, width: 68 * puff, height: 52 * puff)
                ctx.fill(Path(ellipseIn: r), with: .color(Color(hex: 0xFF6B8A).opacity(0.68)))
            }
        case .frostCrown:
            // Sparkling icy snowflake tiara perched on top of the head!
            var tiara = Path()
            tiara.move(to: CGPoint(x: hat.x - 84, y: hat.y + 18))
            tiara.addLine(to: CGPoint(x: hat.x - 52, y: hat.y - 42))
            tiara.addLine(to: CGPoint(x: hat.x - 22, y: hat.y - 10))
            tiara.addLine(to: CGPoint(x: hat.x, y: hat.y - 74))
            tiara.addLine(to: CGPoint(x: hat.x + 22, y: hat.y - 10))
            tiara.addLine(to: CGPoint(x: hat.x + 52, y: hat.y - 42))
            tiara.addLine(to: CGPoint(x: hat.x + 84, y: hat.y + 18))
            tiara.closeSubpath()
            StorybookArt.shape(ctx, tiara, hex: 0x98EEFF, width: 6)
            StorybookArt.sparkle(ctx, at: CGPoint(x: hat.x, y: hat.y - 74), radius: 22, color: .white, opacity: 0.95)
        case .golden:
            // Shimmering golden royal crown!
            var crown = Path()
            crown.move(to: CGPoint(x: hat.x - 76, y: hat.y + 16))
            crown.addLine(to: CGPoint(x: hat.x - 62, y: hat.y - 52))
            crown.addLine(to: CGPoint(x: hat.x - 26, y: hat.y - 14))
            crown.addLine(to: CGPoint(x: hat.x, y: hat.y - 68))
            crown.addLine(to: CGPoint(x: hat.x + 26, y: hat.y - 14))
            crown.addLine(to: CGPoint(x: hat.x + 62, y: hat.y - 52))
            crown.addLine(to: CGPoint(x: hat.x + 76, y: hat.y + 16))
            crown.closeSubpath()
            StorybookArt.shape(ctx, crown, hex: 0xFFD44A, width: 6)
            for gx in [hat.x - 40, hat.x, hat.x + 40] {
                ctx.fill(Path(ellipseIn: CGRect(x: gx - 10, y: hat.y - 10, width: 20, height: 20)), with: .color(Color(hex: 0xFF62A8)))
            }
        default:
            break
        }
    }

    private static func drawCreatureFrontEffects(_ g: GraphicsContext, effect: TransformationEffect?, feet: CGPoint, t: CGFloat) {
        guard let effect else { return }
        let center = CGPoint(x: feet.x, y: feet.y - 104)

        if effect.isFloating {
            // Giant iridescent soap bubble floating cleanly in the open left sky!
            let r: CGFloat = 124 + sin(t * 3.2) * 3.5
            let bub = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r * 0.96, width: r * 2, height: r * 1.92))
            let tintA = effect == .mermaid ? Color(hex: 0x7CF4EC) : Color(hex: 0xBFEFFF)
            let tintB = effect == .mermaid ? Color(hex: 0xA2D4FF) : Color(hex: 0xFFC2EC)
            g.fill(
                bub,
                with: .radialGradient(
                    Gradient(colors: [.clear, tintA.opacity(0.20), tintB.opacity(0.36)]),
                    center: center,
                    startRadius: r * 0.45,
                    endRadius: r
                )
            )
            g.stroke(
                bub,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x8CF0FF).opacity(0.9), Color(hex: 0xFFB8EC).opacity(0.9), Color(hex: 0xFFE68C).opacity(0.9)]),
                    startPoint: CGPoint(x: center.x - r, y: center.y - r),
                    endPoint: CGPoint(x: center.x + r, y: center.y + r)
                ),
                lineWidth: 3.5
            )
            StorybookArt.highlight(
                g,
                in: CGRect(x: center.x - r * 0.58, y: center.y - r * 0.72, width: r * 0.44, height: r * 0.24),
                opacity: 0.72
            )
        }

        if effect == .galaxy || effect == .moonlight {
            // Orbiting glowing mini-stars!
            for i in 0..<6 {
                let a = Double(t) * 1.6 + Double(i) * (.pi / 3)
                let rx: CGFloat = 108
                let ry: CGFloat = 52
                let p = CGPoint(x: center.x + CGFloat(cos(a)) * rx, y: center.y - 26 + CGFloat(sin(a)) * ry)
                let r: CGFloat = 8 + 4 * CGFloat(0.5 + 0.5 * sin(a))
                let col: Color = i % 2 == 0 ? Theme.lemon : .white
                StorybookArt.sparkle(g, at: p, radius: r, color: col, opacity: 0.92)
            }
        }
    }

    // MARK: Center Stage — Wide-Mouth Magic Cauldron, Burner, Flame Dial & Fixed Drain Valve

    private static func drawCauldron(_ g: GraphicsContext, sim: PotionSim, liquid: PotionLiquid, t: CGFloat) {
        let C = PotionGeometry.cauldronCenter
        let R = PotionGeometry.cauldronRadius
        let hw = PotionGeometry.neckHalfWidth

        // Glass back.
        g.fill(PotionGeometry.exterior, with: .color(.white.opacity(0.14)))
        g.fill(
            PotionGeometry.interior,
            with: .radialGradient(
                Gradient(colors: [RGB(hex: "#F2EBFF").c(0.16), RGB(hex: "#5A4A8A").c(0.18)]),
                center: CGPoint(x: C.x - 36, y: C.y - 50),
                startRadius: 16,
                endRadius: R
            )
        )

        var inside = g
        inside.clip(to: PotionGeometry.interior)
        drawPaddle(g, sim: sim, t: t)

        for pc in sim.pieces where pc.state == .liquid {
            drawPiece(inside, pc, alpha: 1)
        }

        if sim.volume > 20 {
            var surf = Path()
            let x0 = C.x - R - 4
            let x1 = C.x + R + 4
            var x = x0
            surf.move(to: CGPoint(x: x0, y: sim.surfaceY(x0)))
            var topPts: [CGPoint] = []
            while x <= x1 {
                let p = CGPoint(x: x, y: sim.surfaceY(x))
                topPts.append(p)
                surf.addLine(to: p)
                x += 4
            }
            surf.addLine(to: CGPoint(x: x1, y: PotionGeometry.bottomY + 18))
            surf.addLine(to: CGPoint(x: x0, y: PotionGeometry.bottomY + 18))
            surf.closeSubpath()

            var lq = inside
            lq.clip(to: surf)
            if let img = liquid.image(sim) {
                let box = CGRect(
                    x: PotionGeometry.gx0,
                    y: PotionGeometry.gy0,
                    width: CGFloat(PotionGeometry.NX) * PotionGeometry.cell,
                    height: CGFloat(PotionGeometry.NY) * PotionGeometry.cell
                )
                lq.draw(Image(decorative: img, scale: 1).interpolation(.high), in: box)
                let glow = sim.cauldronGlow
                if glow > 0.05 {
                    var gl = lq
                    gl.blendMode = .plusLighter
                    gl.opacity = Double(glow) * (0.24 + 0.30 * Double(sim.night)) * (0.9 + 0.1 * Double(sin(t * 3)))
                    gl.draw(Image(decorative: img, scale: 1).interpolation(.high), in: box)
                }
            }

            // Soft spherical glass shading.
            lq.fill(
                Path(CGRect(x: x0, y: PotionGeometry.rimY, width: x1 - x0, height: PotionGeometry.bottomY - PotionGeometry.rimY + 10)),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.20), .clear, .black.opacity(0.14)]),
                    center: CGPoint(x: C.x - 42, y: C.y - 34),
                    startRadius: 10,
                    endRadius: R + 18
                )
            )

            // Swirling glitter inside cauldron.
            drawGlitter(lq, sim: sim, t: t)

            // Rising bubbles inside cauldron.
            var bub = Path()
            var hi = Path()
            for b in sim.bubbles {
                let r = b.r * (1 + 0.08 * sin(b.phase * 2))
                bub.addEllipse(in: CGRect(x: b.p.x - r, y: b.p.y - r, width: r * 2, height: r * 2))
                hi.addEllipse(in: CGRect(x: b.p.x - r * 0.5, y: b.p.y - r * 0.55, width: r * 0.48, height: r * 0.42))
            }
            inside.fill(bub, with: .color(.white.opacity(0.2)))
            inside.stroke(bub, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
            inside.fill(hi, with: .color(.white.opacity(0.92)))

            // Rippling glossy surface highlight.
            var surfaceLine = Path()
            surfaceLine.addLines(topPts)
            inside.stroke(surfaceLine, with: .color(.white.opacity(0.72)), lineWidth: 3)
        }

        // Front glass rim, reflections & lip.
        var ring = PotionGeometry.exterior
        ring.addPath(PotionGeometry.interior)
        g.fill(ring, with: .color(.white.opacity(0.24)), style: FillStyle(eoFill: true))
        g.stroke(PotionGeometry.exterior, with: .color(glassLine.c(0.95)), lineWidth: 3)
        g.stroke(PotionGeometry.interior, with: .color(.white.opacity(0.58)), lineWidth: 1.6)

        var refl = Path()
        for k in 0...18 {
            let a = Double.pi * (1.08 + 0.30 * Double(k) / 18)
            let p = CGPoint(x: C.x + (R - 18) * CGFloat(cos(a)), y: C.y + (R - 18) * CGFloat(sin(a)))
            if k == 0 { refl.move(to: p) } else { refl.addLine(to: p) }
        }
        g.stroke(refl, with: .color(.white.opacity(0.58)), style: StrokeStyle(lineWidth: 11, lineCap: .round))

        g.fill(
            Path(roundedRect: CGRect(x: C.x - hw + 10, y: PotionGeometry.rimY + 14, width: 8, height: max(18, PotionGeometry.joinY - PotionGeometry.rimY - 24)), cornerRadius: 4),
            with: .color(.white.opacity(0.42))
        )

        let lip = CGRect(x: C.x - hw - 16, y: PotionGeometry.rimY - 12, width: (hw + 16) * 2, height: 22)
        g.stroke(Path(ellipseIn: lip), with: .color(glassLine.c(0.96)), lineWidth: 6.5)
        g.stroke(Path(ellipseIn: lip.insetBy(dx: 3, dy: 3)), with: .color(.white.opacity(0.72)), lineWidth: 2)

        if sim.hasHeartCauldron {
            drawHeartCauldronAdornments(g, center: C, radius: R, neckHalfWidth: hw, t: t)
        }

        if let kind = sim.rare {
            Twinkles.draw(g, around: C, radius: R + 24, time: t * 1.4, count: 7, alpha: 1)
            if sim.flash > 0 {
                var fl = g
                fl.blendMode = .plusLighter
                fl.fill(PotionGeometry.interior, with: .color(kind.color.mix(RGB(1, 1, 1), 0.5).c(Double(sim.flash) * 0.72)))
            }
        }
    }

    private static func drawHeartCauldronAdornments(_ g: GraphicsContext, center C: CGPoint, radius R: CGFloat, neckHalfWidth hw: CGFloat, t: CGFloat) {
        let roseGold = Color(hex: 0xF7B2C4)
        let roseGoldLight = Color(hex: 0xFFE6C8)
        let roseGoldStroke = StorybookArt.outline(for: 0xE896A8, factor: 0.65)
        let lip = CGRect(x: C.x - hw - 16, y: PotionGeometry.rimY - 12, width: (hw + 16) * 2, height: 22)

        // Pastel rose-gold trim wrapping the cauldron rim
        g.stroke(Path(ellipseIn: lip), with: .color(roseGoldStroke), lineWidth: 9.5)
        g.stroke(
            Path(ellipseIn: lip),
            with: .linearGradient(
                Gradient(colors: [roseGoldLight, roseGold, Color(hex: 0xFFD998), roseGold]),
                startPoint: CGPoint(x: lip.minX, y: lip.midY),
                endPoint: CGPoint(x: lip.maxX, y: lip.midY)
            ),
            lineWidth: 5.5
        )
        for k in 0..<7 {
            let a = Double.pi * (0.14 + 0.72 * Double(k) / 6.0)
            let px = lip.midX + lip.width * 0.5 * CGFloat(cos(a))
            let py = lip.midY + lip.height * 0.5 * CGFloat(sin(a))
            let bead = Path(ellipseIn: CGRect(x: px - 4, y: py - 4, width: 8, height: 8))
            StorybookArt.fillAndStroke(g, bead, fill: Color(hex: 0xFFF9EE), stroke: roseGoldStroke, width: 1.6)
        }

        // Delicate rose-gold scalloped neck band
        let jy = PotionGeometry.joinY
        var collar = Path()
        collar.move(to: CGPoint(x: C.x - hw - 3, y: jy + 2))
        collar.addQuadCurve(to: CGPoint(x: C.x + hw + 3, y: jy + 2), control: CGPoint(x: C.x, y: jy + 14))
        g.stroke(collar, with: .color(roseGoldStroke), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
        g.stroke(collar, with: .color(roseGold), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))

        // Twinkling pastel-gold cauldron runes along the glass curves
        let runePoints: [(CGPoint, Bool)] = [
            (CGPoint(x: C.x - 84, y: C.y + 8), true),
            (CGPoint(x: C.x - 94, y: C.y + 44), false),
            (CGPoint(x: C.x - 66, y: C.y + 74), true),
            (CGPoint(x: C.x + 84, y: C.y + 8), true),
            (CGPoint(x: C.x + 94, y: C.y + 44), false),
            (CGPoint(x: C.x + 66, y: C.y + 74), true),
        ]
        for (idx, (pt, isStar)) in runePoints.enumerated() {
            let pulse = 0.55 + 0.45 * sin(Double(t) * 2.8 + Double(idx) * 1.1)
            if isStar {
                StorybookArt.sparkle(g, at: pt, radius: 7.5 * CGFloat(0.8 + 0.25 * pulse), color: Color(hex: 0xFFE898), opacity: 0.55 + 0.4 * pulse)
            } else {
                // Tiny glowing crescent rune
                let rRect = CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14)
                var moon = Path(ellipseIn: rRect)
                moon.addEllipse(in: rRect.offsetBy(dx: 4.5, dy: -2))
                g.fill(moon, with: .color(Color(hex: 0xFFF0B8).opacity(0.55 + 0.35 * pulse)), style: FillStyle(eoFill: true))
            }
        }

        // Glowing faceted heart gem emblem centered on the cauldron front
        let gemC = CGPoint(x: C.x, y: C.y + 44)
        let glowPulse = 0.45 + 0.2 * sin(Double(t) * 3.0)
        var halo = g
        halo.blendMode = .plusLighter
        halo.fill(
            Path(ellipseIn: CGRect(x: gemC.x - 42, y: gemC.y - 42, width: 84, height: 84)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFA6D2).opacity(glowPulse), Color(hex: 0xFFE394).opacity(glowPulse * 0.45), .clear]),
                center: gemC,
                startRadius: 6,
                endRadius: 42
            )
        )

        func heartGemPath(center: CGPoint, halfWidth s: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: center.x, y: center.y + s * 0.95))
            p.addCurve(to: CGPoint(x: center.x - s, y: center.y - s * 0.22), control1: CGPoint(x: center.x - s * 0.2, y: center.y + s * 0.72), control2: CGPoint(x: center.x - s, y: center.y + s * 0.24))
            p.addCurve(to: CGPoint(x: center.x, y: center.y - s * 0.48), control1: CGPoint(x: center.x - s, y: center.y - s * 0.74), control2: CGPoint(x: center.x - s * 0.42, y: center.y - s * 0.92))
            p.addCurve(to: CGPoint(x: center.x + s, y: center.y - s * 0.22), control1: CGPoint(x: center.x + s * 0.42, y: center.y - s * 0.92), control2: CGPoint(x: center.x + s, y: center.y - s * 0.74))
            p.addCurve(to: CGPoint(x: center.x, y: center.y + s * 0.95), control1: CGPoint(x: center.x + s, y: center.y + s * 0.24), control2: CGPoint(x: center.x + s * 0.2, y: center.y + s * 0.72))
            p.closeSubpath()
            return p
        }

        // Rose-gold filigree bezel & side scrolls
        for side in [-1.0, 1.0] as [CGFloat] {
            var scroll = Path()
            scroll.move(to: CGPoint(x: gemC.x + side * 24, y: gemC.y - 2))
            scroll.addQuadCurve(to: CGPoint(x: gemC.x + side * 42, y: gemC.y - 12), control: CGPoint(x: gemC.x + side * 38, y: gemC.y + 4))
            g.stroke(scroll, with: .color(roseGoldStroke), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
            g.stroke(scroll, with: .color(roseGoldLight), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        }

        let bezel = heartGemPath(center: gemC, halfWidth: 26)
        g.fill(
            bezel,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFF1B8), Color(hex: 0xF7B2C4), Color(hex: 0xE6A454)]),
                startPoint: CGPoint(x: gemC.x - 20, y: gemC.y - 22),
                endPoint: CGPoint(x: gemC.x + 20, y: gemC.y + 24)
            )
        )
        g.stroke(bezel, with: .color(roseGoldStroke), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))

        let jewel = heartGemPath(center: gemC, halfWidth: 19)
        g.fill(
            jewel,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xFFD4EC), Color(hex: 0xFF68AD), Color(hex: 0xD83A84)]),
                startPoint: CGPoint(x: gemC.x - 10, y: gemC.y - 16),
                endPoint: CGPoint(x: gemC.x + 12, y: gemC.y + 18)
            )
        )
        g.stroke(jewel, with: .color(StorybookArt.outline(for: 0xE04688)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

        // Inner faceted diamond cut highlight
        let facet = heartGemPath(center: CGPoint(x: gemC.x - 1, y: gemC.y - 2), halfWidth: 10)
        g.fill(facet, with: .color(.white.opacity(0.32)))
        StorybookArt.highlight(g, in: CGRect(x: gemC.x - 11, y: gemC.y - 12, width: 9, height: 6), opacity: 0.88)
        StorybookArt.sparkle(g, at: CGPoint(x: gemC.x + 15, y: gemC.y - 16), radius: 7.5, color: .white, opacity: 0.95)
        _ = R
    }

    private static func drawPaddle(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        let blade = sim.spoon
        let C = PotionGeometry.cauldronCenter
        let hw = PotionGeometry.neckHalfWidth
        let pivot = CGPoint(
            x: max(C.x - hw + 14, min(C.x + hw - 14, blade.x * 0.65 + C.x * 0.35 - (sim.spoonHeld ? 0 : 34))),
            y: PotionGeometry.rimY
        )
        let dx = pivot.x - blade.x
        let dy = pivot.y - blade.y
        let len = max(1, hypot(dx, dy))
        let ux = dx / len
        let uy = dy / len
        let total: CGFloat = max(len + 74, 275)
        let end = CGPoint(x: blade.x + ux * total, y: blade.y + uy * total)

        var shaft = Path()
        shaft.move(to: blade)
        shaft.addLine(to: end)

        if sim.hasFairyLadle {
            let pearlOutline = StorybookArt.outline(for: 0xD8A8F0, factor: 0.65)
            g.stroke(shaft, with: .color(pearlOutline), style: StrokeStyle(lineWidth: 13.5, lineCap: .round))
            g.stroke(
                shaft,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFFF5FA), Color(hex: 0xFFD4EC), Color(hex: 0xDFCCFF), Color(hex: 0xFFF5D4)]),
                    startPoint: blade,
                    endPoint: end
                ),
                style: StrokeStyle(lineWidth: 8.8, lineCap: .round)
            )
            g.stroke(shaft, with: .color(.white.opacity(0.62)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

            // Pearlescent fairy ladle scoop inside the cauldron
            var b = g
            b.translateBy(x: blade.x, y: blade.y)
            b.rotate(by: .radians(Double(atan2(uy, ux)) + .pi / 2))
            let scoop = Path(roundedRect: CGRect(x: -17, y: -30, width: 34, height: 48), cornerRadius: 16)
            b.fill(
                scoop,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFFF7FC), Color(hex: 0xFFD8EE), Color(hex: 0xDFCCFF)]),
                    startPoint: CGPoint(x: -16, y: -30),
                    endPoint: CGPoint(x: 16, y: 18)
                )
            )
            b.stroke(scoop, with: .color(pearlOutline), lineWidth: 2.8)
            StorybookArt.highlight(b, in: CGRect(x: -9, y: -22, width: 7, height: 28), opacity: 0.55)

            // Glowing golden star topper with mini pearl wings at wand handle tip
            let pulse = 0.88 + 0.12 * sin(t * 5) + min(0.22, sim.stirSpeed / 900)
            let glowR: CGFloat = 34 * pulse
            var halo = g
            halo.blendMode = .plusLighter
            halo.fill(
                Path(ellipseIn: CGRect(x: end.x - glowR, y: end.y - glowR, width: glowR * 2, height: glowR * 2)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFF3A8).opacity(0.85), Color(hex: 0xFFB8E0).opacity(0.32), .clear]),
                    center: end,
                    startRadius: 4,
                    endRadius: glowR
                )
            )

            var top = g
            top.translateBy(x: end.x, y: end.y)
            top.rotate(by: .radians(Double(atan2(uy, ux)) + .pi / 2))

            // Mini pearl fairy wings below the golden star
            for side in [-1.0, 1.0] as [CGFloat] {
                var wing = Path()
                wing.move(to: CGPoint(x: side * 6, y: 14))
                wing.addCurve(to: CGPoint(x: side * 26, y: 2), control1: CGPoint(x: side * 18, y: 20), control2: CGPoint(x: side * 28, y: 10))
                wing.addCurve(to: CGPoint(x: side * 6, y: 5), control1: CGPoint(x: side * 20, y: -4), control2: CGPoint(x: side * 12, y: 0))
                wing.closeSubpath()
                StorybookArt.fillAndStroke(top, wing, fill: .white, stroke: pearlOutline, width: 2)
            }

            var star = Path()
            for i in 0..<10 {
                let a = -Double.pi / 2 + Double(i) * Double.pi / 5
                let r: CGFloat = i.isMultiple(of: 2) ? 23 : 10.5
                let pt = CGPoint(x: CGFloat(cos(a)) * r, y: -2 + CGFloat(sin(a)) * r)
                if i == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
            }
            star.closeSubpath()
            top.fill(
                star,
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xFFFBE0), Color(hex: 0xFFD44A), Color(hex: 0xF0A628)]),
                    center: CGPoint(x: -3, y: -6),
                    startRadius: 2,
                    endRadius: 24
                )
            )
            top.stroke(star, with: .color(StorybookArt.outline(for: 0xE6A428)), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
            StorybookArt.heart(top, at: CGPoint(x: 0, y: -1), size: 11, color: Color(hex: 0xFF66A8))
            StorybookArt.sparkle(top, at: CGPoint(x: 18, y: -18), radius: 7 * pulse, color: .white, opacity: 0.95)
            StorybookArt.sparkle(top, at: CGPoint(x: -18, y: -12), radius: 5.5 * pulse, color: Theme.lemon, opacity: 0.9)
            return
        }

        g.stroke(shaft, with: .color(StorybookArt.outline(for: woodHex)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        g.stroke(shaft, with: .color(StorybookArt.color(woodHex)), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))

        // Glowing magic lavender crystal knob at handle tip.
        let knobRect = CGRect(x: end.x - 13, y: end.y - 13, width: 26, height: 26)
        StorybookArt.shape(g, Path(ellipseIn: knobRect), hex: 0xC990FF, width: 2.5)
        StorybookArt.highlight(g, in: CGRect(x: end.x - 7, y: end.y - 9, width: 8, height: 6), opacity: 0.75)

        // Flat wooden stirring blade.
        var b = g
        b.translateBy(x: blade.x, y: blade.y)
        b.rotate(by: .radians(Double(atan2(uy, ux)) + .pi / 2))
        let paddle = Path(roundedRect: CGRect(x: -16, y: -30, width: 32, height: 48), cornerRadius: 14)
        StorybookArt.shape(b, paddle, hex: woodHex, width: 3)
        StorybookArt.highlight(b, in: CGRect(x: -9, y: -22, width: 6, height: 30), opacity: 0.3)
    }

    private static func drawGlitter(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        guard !sim.glitter.isEmpty else { return }
        var shine = Path()
        for gl in sim.glitter {
            let tw = 0.5 + 0.5 * sin(gl.phase * 2.3 + t * 4.2)
            let s = gl.size * (0.7 + 0.6 * tw)
            g.fill(Path(ellipseIn: CGRect(x: gl.p.x - s, y: gl.p.y - s, width: s * 2, height: s * 2)), with: .color(gl.color.c()))
            if tw > 0.88 {
                let r = s * 2.8
                shine.addPath(Twinkle().path(in: CGRect(x: gl.p.x - r, y: gl.p.y - r, width: r * 2, height: r * 2)))
            }
        }
        g.fill(shine, with: .color(.white.opacity(0.92)))
    }

    private static func drawBurner(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        let base = PotionGeometry.burnerCenter

        // `.off` renders ZERO flames (pilot-flame bug fixed!).
        if sim.burner != .off {
            let isBoil = sim.burner == .boil
            let count = isBoil ? 5 : 3
            let offset = isBoil ? 2 : 1
            for k in 0..<count {
                let fx = base.x + CGFloat(k - offset) * (isBoil ? 14 : 16)
                let flick = sin(t * 16 + CGFloat(k) * 2.2) * 0.14 + sin(t * 27 + CGFloat(k)) * 0.06
                let centerBoost = CGFloat(offset - abs(k - offset)) * (isBoil ? 8 : 5)
                let hgt = ((isBoil ? 36 : 19) + centerBoost) * (1 + flick)
                let w: CGFloat = isBoil ? 12 : 8.5
                var f = Path()
                f.move(to: CGPoint(x: fx - w, y: base.y - 4))
                f.addQuadCurve(to: CGPoint(x: fx + sin(t * 10 + CGFloat(k)) * 4, y: base.y - 4 - hgt), control: CGPoint(x: fx - w * 1.1, y: base.y - 4 - hgt * 0.5))
                f.addQuadCurve(to: CGPoint(x: fx + w, y: base.y - 4), control: CGPoint(x: fx + w * 1.1, y: base.y - 4 - hgt * 0.5))
                f.closeSubpath()
                g.fill(
                    f,
                    with: .linearGradient(
                        Gradient(colors: [RGB(hex: "#5892FF").c(0.92), RGB(hex: "#FFB238").c(0.96), RGB(hex: "#FF5E28").c(0.15)]),
                        startPoint: CGPoint(x: fx, y: base.y - 4),
                        endPoint: CGPoint(x: fx, y: base.y - 4 - hgt)
                    )
                )
                var core = Path()
                core.move(to: CGPoint(x: fx - w * 0.45, y: base.y - 4))
                core.addQuadCurve(to: CGPoint(x: fx, y: base.y - 4 - hgt * 0.48), control: CGPoint(x: fx - w * 0.5, y: base.y - 4 - hgt * 0.22))
                core.addQuadCurve(to: CGPoint(x: fx + w * 0.45, y: base.y - 4), control: CGPoint(x: fx + w * 0.5, y: base.y - 4 - hgt * 0.22))
                g.fill(core, with: .color(RGB(hex: "#FFF4C2").c(0.88)))
            }
        }

        // Brass burner body.
        let nozzle = Path(roundedRect: CGRect(x: base.x - 32, y: base.y - 8, width: 64, height: 10), cornerRadius: 4)
        StorybookArt.shape(g, nozzle, hex: brassDarkHex, width: 2.5)
        let body = Path(roundedRect: CGRect(x: base.x - 40, y: base.y, width: 80, height: 28), cornerRadius: 10)
        StorybookArt.shape(g, body, hex: brassHex, width: 3)
        StorybookArt.highlight(g, in: CGRect(x: base.x - 30, y: base.y + 4, width: 52, height: 5), opacity: 0.42)
    }

    private static func drawFlameDial(_ g: GraphicsContext, sim: PotionSim) {
        let k = PotionGeometry.dialCenter
        let R = PotionGeometry.dialRadius

        // Outer brass bezel.
        StorybookArt.shape(g, Path(ellipseIn: CGRect(x: k.x - R - 5, y: k.y - R - 5, width: (R + 5) * 2, height: (R + 5) * 2)), hex: brassHex, width: 3)

        // Chunky pink/coral dial face.
        let dialColor: UInt32 = sim.burner == .boil ? 0xFF7048 : (sim.burner == .simmer ? 0xFFA25A : 0xFF8FB8)
        StorybookArt.shape(g, Path(ellipseIn: CGRect(x: k.x - R, y: k.y - R, width: R * 2, height: R * 2)), hex: dialColor, width: 2.5)
        StorybookArt.highlight(g, in: CGRect(x: k.x - 16, y: k.y - 20, width: 22, height: 12), opacity: 0.38)

        // 3 clear flame indicator pips around top arc: off (left), simmer (top), boil (right).
        let angles: [Double] = [-.pi * 0.82, -.pi * 0.5, -.pi * 0.18]
        for (idx, a) in angles.enumerated() {
            let p = CGPoint(x: k.x + (R + 13) * CGFloat(cos(a)), y: k.y + (R + 13) * CGFloat(sin(a)))
            let lit = idx <= sim.burner.rawValue && sim.burner != .off
            let dot = Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
            StorybookArt.fillAndStroke(
                g,
                dot,
                fill: lit ? Color(hex: 0xFFB838) : Color.white.opacity(0.85),
                stroke: StorybookArt.outline(for: lit ? 0xFF8C2A : brassHex),
                width: 2
            )
        }

        // Pointer notch pointing directly at the active step.
        let activeA = angles[sim.burner.rawValue]
        var pointer = Path()
        pointer.move(to: CGPoint(x: k.x + 8 * CGFloat(cos(activeA)), y: k.y + 8 * CGFloat(sin(activeA))))
        pointer.addLine(to: CGPoint(x: k.x + (R - 5) * CGFloat(cos(activeA)), y: k.y + (R - 5) * CGFloat(sin(activeA))))
        g.stroke(pointer, with: .color(.white), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // Flame icon centered on dial face.
        var flame = Path()
        flame.move(to: CGPoint(x: k.x - 7, y: k.y + 11))
        flame.addQuadCurve(to: CGPoint(x: k.x, y: k.y - 6), control: CGPoint(x: k.x - 10, y: k.y + 1))
        flame.addQuadCurve(to: CGPoint(x: k.x + 7, y: k.y + 11), control: CGPoint(x: k.x + 10, y: k.y + 1))
        flame.closeSubpath()
        g.fill(flame, with: .color(sim.burner == .off ? .white.opacity(0.65) : Theme.lemon))
    }

    private static func drawTripod(_ g: GraphicsContext, front: Bool) {
        let C = PotionGeometry.cauldronCenter
        let ring = CGRect(x: C.x - 84, y: C.y + 102, width: 168, height: 22)
        var half = Path()
        let n = 22
        for k in 0...n {
            let a = (front ? 0 : Double.pi) + Double.pi * Double(k) / Double(n)
            let p = CGPoint(x: ring.midX + ring.width / 2 * CGFloat(cos(a)), y: ring.midY + ring.height / 2 * CGFloat(sin(a)))
            if k == 0 { half.move(to: p) } else { half.addLine(to: p) }
        }
        g.stroke(half, with: .color(StorybookArt.outline(for: brassHex)), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))
        g.stroke(half, with: .color(StorybookArt.color(brassHex)), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        if front {
            var legs = Path()
            legs.move(to: CGPoint(x: ring.minX + 6, y: ring.midY + 4))
            legs.addLine(to: CGPoint(x: ring.minX + 14, y: PotionGeometry.tableY + 2))
            legs.move(to: CGPoint(x: ring.maxX - 6, y: ring.midY + 4))
            legs.addLine(to: CGPoint(x: ring.maxX - 14, y: PotionGeometry.tableY + 2))
            g.stroke(legs, with: .color(StorybookArt.outline(for: brassHex)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            g.stroke(legs, with: .color(StorybookArt.color(brassHex)), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        }
    }

    private static func drawDrainPipeAndValve(_ g: GraphicsContext, sim: PotionSim) {
        let v = PotionGeometry.valveCenter
        let mouth = PotionGeometry.drainMouth

        // Horizontal glass drain pipe from bottom-right of cauldron to catch basin.
        var pipe = Path()
        pipe.move(to: CGPoint(x: PotionGeometry.cauldronCenter.x + 62, y: PotionGeometry.bottomY - 8))
        pipe.addQuadCurve(to: CGPoint(x: v.x - 15, y: v.y), control: CGPoint(x: PotionGeometry.cauldronCenter.x + 76, y: v.y))
        pipe.addLine(to: CGPoint(x: mouth.x - 8, y: v.y))
        pipe.addQuadCurve(to: CGPoint(x: mouth.x, y: mouth.y + 10), control: CGPoint(x: mouth.x, y: v.y))
        g.stroke(pipe, with: .color(glassLine.c(0.92)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        g.stroke(pipe, with: .color(.white.opacity(0.38)), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
        if sim.draining && sim.volume > 10 {
            let (mc, ma) = sim.meanColor()
            let col = PotionColor.clearWater.mix(mc, Double(min(1, ma * 1.8)))
            g.stroke(pipe, with: .color(col.c(0.88)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        }

        // Brass valve hub.
        StorybookArt.shape(g, Path(ellipseIn: CGRect(x: v.x - 14, y: v.y - 14, width: 28, height: 28)), hex: brassHex, width: 3)

        var lever = g
        lever.translateBy(x: v.x, y: v.y)
        lever.rotate(by: .radians(Double(sim.valveAngle)))
        let handle = Path(roundedRect: CGRect(x: -5.5, y: -32, width: 11, height: 32), cornerRadius: 5.5)
        StorybookArt.shape(lever, handle, hex: 0x7ED8F8, width: 2.5)
        let knob = Path(ellipseIn: CGRect(x: -9, y: -47, width: 18, height: 18))
        StorybookArt.shape(lever, knob, hex: 0x7ED8F8, width: 2.5)
        StorybookArt.highlight(lever, in: CGRect(x: -5, y: -43, width: 6.5, height: 5), opacity: 0.65)
    }

    private static func drawBasin(_ g: GraphicsContext, sim: PotionSim) {
        let b = PotionGeometry.basinRect
        var body = Path()
        body.move(to: CGPoint(x: b.minX, y: b.minY))
        body.addLine(to: CGPoint(x: b.maxX, y: b.minY))
        body.addLine(to: CGPoint(x: b.maxX - 6, y: b.maxY))
        body.addLine(to: CGPoint(x: b.minX + 6, y: b.maxY))
        body.closeSubpath()
        StorybookArt.shape(g, body, hex: 0xC6926A, width: 2.5)
        let mouth = CGRect(x: b.minX, y: b.minY - 5, width: b.width, height: 10)
        g.fill(Path(ellipseIn: mouth), with: .color(Color(hex: 0x6A4230)))
        if sim.basinFill > 0.02 {
            g.fill(Path(ellipseIn: mouth.insetBy(dx: 4, dy: 2)), with: .color(sim.basinColor.c(0.55 + 0.4 * Double(sim.basinFill))))
        }
        g.stroke(Path(ellipseIn: mouth), with: .color(Color(hex: 0xECC294)), lineWidth: 2.5)
    }

    // MARK: Right Stage — Cozy 5-Slot Tasting Stand

    private static func drawTastingStand(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        let x0: CGFloat = 758
        let x1: CGFloat = 992
        let topY = PotionGeometry.standShelfTopY
        let botY = PotionGeometry.standShelfBottomY

        // Back decorative pastel arch board behind the shelves.
        let backBoard = Path(roundedRect: CGRect(x: x0 + 8, y: 342, width: x1 - x0 - 16, height: PotionGeometry.tableY - 342), cornerRadius: 26)
        StorybookArt.fillAndStroke(
            g,
            backBoard,
            fill: Color(hex: 0xEAD9FF).opacity(Double(0.52 - 0.22 * sim.night)),
            stroke: StorybookArt.outline(for: woodHex),
            width: 3.5
        )

        // Side wooden uprights.
        for ux in [x0 + 4, x1 - 18] {
            let post = Path(roundedRect: CGRect(x: ux, y: 348, width: 14, height: PotionGeometry.tableY - 348), cornerRadius: 6)
            StorybookArt.shape(g, post, hex: woodDarkHex, width: 2.5)
        }

        // Two wooden shelves.
        for sy in [topY, botY] {
            let shelf = Path(roundedRect: CGRect(x: x0 - 4, y: sy, width: x1 - x0 + 8, height: 16), cornerRadius: 6)
            StorybookArt.shape(g, shelf, hex: woodHex, width: 3)
            StorybookArt.highlight(g, in: CGRect(x: x0 + 6, y: sy + 2.5, width: x1 - x0 - 12, height: 4), opacity: 0.35)
        }

        // Recessed coaster rings for all 5 slots.
        for spot in PotionGeometry.standSlots {
            let coaster = CGRect(x: spot.x - 24, y: spot.y + 36, width: 48, height: 10)
            g.fill(Path(ellipseIn: coaster), with: .color(StorybookArt.outline(for: woodHex).opacity(0.35)))
        }

        // Filled corked bottles on the Tasting Stand.
        let hidden = sim.hiddenStandIndices
        for (i, bottle) in sim.stand.enumerated() where !hidden.contains(i) && i < PotionGeometry.standSlots.count {
            let spot = PotionGeometry.standSlots[i]
            let bob = sin(t * 2.2 + CGFloat(i) * 1.4) * 1.5
            PotionBottlePainter.draw(
                g,
                bottle: bottle,
                center: CGPoint(x: spot.x, y: spot.y + bob),
                angle: 0,
                scale: PotionGeometry.standBottleScale,
                time: t
            )
        }
    }

    // MARK: Drops, Pieces, Pour Arcs, Flyers, Motes & Dragged Items

    private static func drawDrops(_ g: GraphicsContext, sim: PotionSim) {
        for dp in sim.drops {
            let rect = CGRect(x: dp.p.x - dp.r, y: dp.p.y - dp.r * 1.25, width: dp.r * 2, height: dp.r * 2.5)
            g.fill(Path(ellipseIn: rect), with: .color(dp.color.c(0.92)))
            g.fill(Path(ellipseIn: CGRect(x: dp.p.x - dp.r * 0.4, y: dp.p.y - dp.r * 0.7, width: dp.r * 0.6, height: dp.r * 0.6)), with: .color(.white.opacity(0.75)))
        }
    }

    private static func drawAirPieces(_ g: GraphicsContext, sim: PotionSim) {
        for pc in sim.pieces where pc.state == .air {
            drawPiece(g, pc, alpha: 1)
        }
    }

    private static func drawPiece(_ g: GraphicsContext, _ pc: PPiece, alpha: Double) {
        let k = 1 - pc.dissolve * 0.65
        let a = alpha * Double(1 - pc.dissolve * 0.8)
        guard a > 0.02 else { return }
        if pc.kind == .rainbowMane {
            let pts = pc.trail.isEmpty ? [pc.p, CGPoint(x: pc.p.x + 18, y: pc.p.y + 4)] : pc.trail
            var l = g
            l.opacity = a
            for i in 0..<(pts.count - 1) {
                var s = Path()
                s.move(to: pts[i])
                s.addLine(to: pts[i + 1])
                l.stroke(s, with: .color(PotionColor.hue(CGFloat(i) / CGFloat(max(1, pts.count))).c()), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            return
        }
        var l = g
        l.translateBy(x: pc.p.x, y: pc.p.y)
        l.rotate(by: .radians(Double(pc.ang)))
        l.scaleBy(x: k * 0.42, y: k * 0.42)
        l.opacity = a
        IngredientIconPainter.drawEmblem(l, kind: pc.kind, center: .zero, radius: 26)
    }

    private static func drawPourArcs(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        for arc in sim.pourArcs {
            let (p, angle) = sim.pourArcPosition(arc)
            let fade: Double = arc.t > 0.82 ? Double(max(0, 1 - (arc.t - 0.82) / 0.18)) : 1
            var ctx = g
            ctx.opacity = fade
            ctx.translateBy(x: p.x, y: p.y)
            ctx.rotate(by: .radians(Double(angle)))
            IngredientIconPainter.drawVessel(ctx, kind: arc.kind, center: .zero, scale: 0.78, time: t)
        }
    }

    private static func drawFlyers(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        for f in sim.flyers {
            let (p, angle) = PotionSim.flyerPosition(f)
            let scale = f.pouringOnCreature ? 0.84 : (0.86 + (PotionGeometry.standBottleScale - 0.86) * f.t)
            PotionBottlePainter.draw(g, bottle: f.bottle, center: p, angle: angle, scale: scale, time: t, cork: !f.pouringOnCreature)
        }
    }

    private static func drawDraggedItems(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        if let drag = sim.draggedIngredient {
            let tilt: CGFloat = drag.pos.y < 360 ? -0.9 : 0
            var ctx = g
            ctx.translateBy(x: drag.pos.x, y: drag.pos.y)
            ctx.rotate(by: .radians(Double(tilt)))
            IngredientIconPainter.drawVessel(ctx, kind: drag.kind, center: .zero, scale: 0.86, time: t)
        }
        if let dragB = sim.draggedStandBottle, let bottle = sim.stand[safe: dragB.index] {
            PotionBottlePainter.draw(
                g,
                bottle: bottle,
                center: dragB.pos,
                angle: dragB.tilt,
                scale: 0.86,
                time: t,
                cork: abs(dragB.tilt) < 0.35
            )
        }
    }

    private static func drawMotes(_ g: GraphicsContext, sim: PotionSim, t: CGFloat) {
        let soft = sim.motes.filter { $0.kind == .steam || $0.kind == .fog }
        if !soft.isEmpty {
            g.drawLayer { l in
                l.addFilter(.blur(radius: 7))
                for m in soft {
                    let k = m.life / m.max
                    let a = (m.kind == .fog ? 0.52 : 0.34) * Double(min(1, k * 4) * (1 - k))
                    l.fill(
                        Path(ellipseIn: CGRect(x: m.p.x - m.size, y: m.p.y - m.size * 0.8, width: m.size * 2, height: m.size * 1.6)),
                        with: .color(m.color.c(a))
                    )
                }
            }
        }
        for m in sim.motes {
            let k = m.life / m.max
            let fade = Double(max(0, 1 - k))
            switch m.kind {
            case .sparkle, .starOrbit:
                StorybookArt.sparkle(g, at: m.p, radius: m.size * (1 - k * 0.45), color: m.color.c(), opacity: fade)
            case .heart:
                StorybookArt.heart(g, at: m.p, size: m.size * 1.6, color: m.color.c(), opacity: fade)
            case .fireHeart:
                // Harmless cartoon fire-heart burp!
                StorybookArt.heart(g, at: m.p, size: m.size * 1.7, color: Color(hex: 0xFF6B3D), opacity: fade)
                StorybookArt.heart(g, at: CGPoint(x: m.p.x, y: m.p.y + 2), size: m.size * 0.95, color: Theme.lemon, opacity: fade)
            case .snow:
                var s = Path()
                for a in 0..<3 {
                    let ang = CGFloat(a) * .pi / 3 + m.spin + t
                    s.move(to: CGPoint(x: m.p.x - cos(ang) * m.size, y: m.p.y - sin(ang) * m.size))
                    s.addLine(to: CGPoint(x: m.p.x + cos(ang) * m.size, y: m.p.y + sin(ang) * m.size))
                }
                g.stroke(s, with: .color(.white.opacity(fade)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            case .soap:
                let r = m.size
                let c = CGRect(x: m.p.x - r, y: m.p.y - r, width: r * 2, height: r * 2)
                g.fill(Path(ellipseIn: c), with: .color(.white.opacity(0.14 * fade)))
                g.stroke(
                    Path(ellipseIn: c),
                    with: .linearGradient(Gradient(colors: [Color(hex: 0x9FE8FF).opacity(fade), Color(hex: 0xFFB8E8).opacity(fade)]), startPoint: CGPoint(x: c.minX, y: c.minY), endPoint: CGPoint(x: c.maxX, y: c.maxY)),
                    lineWidth: 1.8
                )
                g.fill(Path(ellipseIn: CGRect(x: c.minX + r * 0.38, y: c.minY + r * 0.32, width: r * 0.5, height: r * 0.34)), with: .color(.white.opacity(0.8 * fade)))
            case .zz:
                let s = m.size
                var z = Path()
                z.move(to: CGPoint(x: m.p.x - s / 2, y: m.p.y - s / 2))
                z.addLine(to: CGPoint(x: m.p.x + s / 2, y: m.p.y - s / 2))
                z.addLine(to: CGPoint(x: m.p.x - s / 2, y: m.p.y + s / 2))
                z.addLine(to: CGPoint(x: m.p.x + s / 2, y: m.p.y + s / 2))
                g.stroke(z, with: .color(m.color.c(fade)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            case .flash:
                let r = m.size
                g.stroke(Path(ellipseIn: CGRect(x: m.p.x - r, y: m.p.y - r, width: r * 2, height: r * 2)), with: .color(m.color.c(fade * 0.9)), lineWidth: 10 * CGFloat(fade) + 1.5)
            case .drip:
                let r = m.size * 0.5
                g.fill(Path(ellipseIn: CGRect(x: m.p.x - r, y: m.p.y - r * 1.3, width: r * 2, height: r * 2.6)), with: .color(m.color.c(0.86 * fade)))
            case .confetti:
                var c = g
                c.translateBy(x: m.p.x, y: m.p.y)
                c.rotate(by: .radians(Double(t * 5 + m.spin)))
                c.fill(Path(roundedRect: CGRect(x: -m.size * 0.55, y: -m.size * 0.32, width: m.size * 1.1, height: m.size * 0.64), cornerRadius: 2.5), with: .color(m.color.c(fade)))
            case .steam, .fog:
                break
            }
        }
    }
}

// MARK: - Crisp StorybookArt Ingredient Medallions & Pouring Vessels

enum IngredientIconPainter {
    static func drawEmblem(_ g: GraphicsContext, kind: PIngredient, center c: CGPoint, radius r: CGFloat) {
        var ctx = g
        ctx.translateBy(x: c.x, y: c.y)
        let s = r / 26

        switch kind {
        case .fairyRose:
            // Lush pink rose blossom + emerald leaves.
            for side in [-1.0, 1.0] {
                let leaf = Path(ellipseIn: CGRect(x: CGFloat(side) * 10 * s - 9 * s, y: 8 * s, width: 18 * s, height: 11 * s))
                StorybookArt.shape(ctx, leaf, hex: 0x7ED88C, width: 2.2 * s)
            }
            for i in 0..<5 {
                let a = CGFloat(i) / 5 * 2 * .pi - .pi / 2
                let p = Path(ellipseIn: CGRect(x: cos(a) * 9 * s - 10 * s, y: sin(a) * 9 * s - 10 * s, width: 20 * s, height: 20 * s))
                StorybookArt.shape(ctx, p, hex: 0xFF6BB2, width: 2.2 * s)
            }
            let bud = Path(ellipseIn: CGRect(x: -9 * s, y: -9 * s, width: 18 * s, height: 18 * s))
            StorybookArt.shape(ctx, bud, hex: 0xFFA4D2, width: 2 * s)
            StorybookArt.highlight(ctx, in: CGRect(x: -5 * s, y: -6 * s, width: 6 * s, height: 4 * s), opacity: 0.65)

        case .mermaidWave:
            // Turquoise sea-shell with pearl & curling white wave crest.
            var shell = Path()
            shell.move(to: CGPoint(x: -20 * s, y: 8 * s))
            shell.addQuadCurve(to: CGPoint(x: 20 * s, y: 8 * s), control: CGPoint(x: 0, y: -34 * s))
            shell.addLine(to: CGPoint(x: 8 * s, y: 18 * s))
            shell.addLine(to: CGPoint(x: -8 * s, y: 18 * s))
            shell.closeSubpath()
            StorybookArt.shape(ctx, shell, hex: 0x36DDD0, width: 2.5 * s)
            var ribs = Path()
            for k in -2...2 {
                ribs.move(to: CGPoint(x: 0, y: 15 * s))
                ribs.addLine(to: CGPoint(x: CGFloat(k) * 7.5 * s, y: -7 * s))
            }
            ctx.stroke(ribs, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            let pearl = Path(ellipseIn: CGRect(x: -5 * s, y: 6 * s, width: 10 * s, height: 10 * s))
            StorybookArt.fillAndStroke(ctx, pearl, fill: .white, stroke: Color(hex: 0x20A6A0), width: 1.5 * s)

        case .starGlitter:
            // Bold golden 5-point star + white twinkles.
            let star = PetPainter.starPath(.zero, 23 * s)
            StorybookArt.shape(ctx, star, hex: 0xFFD44A, width: 2.6 * s)
            StorybookArt.highlight(ctx, in: CGRect(x: -8 * s, y: -11 * s, width: 10 * s, height: 7 * s), opacity: 0.65)
            StorybookArt.sparkle(ctx, at: CGPoint(x: 17 * s, y: -15 * s), radius: 7 * s, color: .white, opacity: 0.95)
            StorybookArt.sparkle(ctx, at: CGPoint(x: -18 * s, y: 14 * s), radius: 5.5 * s, color: Theme.lemon, opacity: 0.95)

        case .rainbowMane:
            // Vivid 5-band pastel rainbow arch + fluffy white cloud puffs.
            let cols: [Color] = [Color(hex: 0xFF7CB4), Color(hex: 0xFFBC6A), Color(hex: 0xFFE672), Color(hex: 0x8CE2A8), Color(hex: 0x86C8FF)]
            for (i, col) in cols.enumerated() {
                let rad = (21 - CGFloat(i) * 3.4) * s
                var arc = Path()
                arc.addArc(center: CGPoint(x: 0, y: 10 * s), radius: rad, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
                ctx.stroke(arc, with: .color(col), style: StrokeStyle(lineWidth: 4.2 * s, lineCap: .round))
            }
            for cx in [-15, 15] {
                let puff = Path(ellipseIn: CGRect(x: CGFloat(cx) * s - 9 * s, y: 4 * s, width: 18 * s, height: 13 * s))
                StorybookArt.fillAndStroke(ctx, puff, fill: .white, stroke: Color(hex: 0xC6B2EC), width: 2 * s)
            }

        case .frostFlake:
            // Crisp 6-arm crystal snowflake with icy outline.
            var arms = Path()
            for i in 0..<3 {
                let a = CGFloat(i) * .pi / 3
                let dx = cos(a) * 21 * s
                let dy = sin(a) * 21 * s
                arms.move(to: CGPoint(x: -dx, y: -dy))
                arms.addLine(to: CGPoint(x: dx, y: dy))
            }
            ctx.stroke(arms, with: .color(Color(hex: 0x4CB8E8)), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round))
            ctx.stroke(arms, with: .color(Color(hex: 0xE6FAFF)), style: StrokeStyle(lineWidth: 3.5 * s, lineCap: .round))
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3
                let tip = Path(ellipseIn: CGRect(x: cos(a) * 19 * s - 3.5 * s, y: sin(a) * 19 * s - 3.5 * s, width: 7 * s, height: 7 * s))
                StorybookArt.shape(ctx, tip, hex: 0x90E8FF, width: 1.5 * s)
            }
            let core = Path(ellipseIn: CGRect(x: -6 * s, y: -6 * s, width: 12 * s, height: 12 * s))
            StorybookArt.shape(ctx, core, hex: 0xC4F4FF, width: 2 * s)

        case .bubbleBerry:
            // Glossy cluster of 3 purple bubble berries + emerald leaf.
            var leaf = Path()
            leaf.move(to: CGPoint(x: 0, y: -12 * s))
            leaf.addQuadCurve(to: CGPoint(x: 14 * s, y: -20 * s), control: CGPoint(x: 8 * s, y: -23 * s))
            leaf.addQuadCurve(to: CGPoint(x: 0, y: -12 * s), control: CGPoint(x: 9 * s, y: -10 * s))
            StorybookArt.shape(ctx, leaf, hex: 0x76D884, width: 2 * s)
            let spots: [(CGFloat, CGFloat)] = [(-10, 4), (10, 4), (0, -6)]
            for (bx, by) in spots {
                let berry = Path(ellipseIn: CGRect(x: (bx - 11) * s, y: (by - 11) * s, width: 22 * s, height: 22 * s))
                StorybookArt.shape(ctx, berry, hex: 0x9E6BFF, width: 2.4 * s)
                StorybookArt.highlight(ctx, in: CGRect(x: (bx - 6) * s, y: (by - 7) * s, width: 7 * s, height: 5 * s), opacity: 0.72)
            }

        case .dragonChili:
            // Playful glowing coral flame emblem!
            var flame = Path()
            flame.move(to: CGPoint(x: -16 * s, y: 15 * s))
            flame.addQuadCurve(to: CGPoint(x: 0, y: -24 * s), control: CGPoint(x: -24 * s, y: -6 * s))
            flame.addQuadCurve(to: CGPoint(x: 16 * s, y: 15 * s), control: CGPoint(x: 24 * s, y: -6 * s))
            flame.addQuadCurve(to: CGPoint(x: -16 * s, y: 15 * s), control: CGPoint(x: 0, y: 24 * s))
            flame.closeSubpath()
            StorybookArt.shape(ctx, flame, hex: 0xFF6B3D, width: 2.6 * s)
            var inner = Path()
            inner.move(to: CGPoint(x: -8 * s, y: 13 * s))
            inner.addQuadCurve(to: CGPoint(x: 0, y: -6 * s), control: CGPoint(x: -12 * s, y: 3 * s))
            inner.addQuadCurve(to: CGPoint(x: 8 * s, y: 13 * s), control: CGPoint(x: 12 * s, y: 3 * s))
            inner.closeSubpath()
            ctx.fill(inner, with: .color(Theme.lemon))

        case .sleepyLavender:
            // Dreamy lilac crescent moon + tiny lavender buds + gold star!
            let mRect = CGRect(x: -19 * s, y: -19 * s, width: 38 * s, height: 38 * s)
            var moon = Path(ellipseIn: mRect)
            moon.addEllipse(in: mRect.offsetBy(dx: 13 * s, dy: -6 * s))
            ctx.fill(moon, with: .color(Color(hex: 0xB892FF)), style: FillStyle(eoFill: true))
            ctx.stroke(moon, with: .color(StorybookArt.outline(for: 0xB892FF)), lineWidth: 2.2 * s)
            StorybookArt.sparkle(ctx, at: CGPoint(x: 13 * s, y: -11 * s), radius: 8.5 * s, color: Theme.lemon, opacity: 0.98)
            StorybookArt.sparkle(ctx, at: CGPoint(x: 16 * s, y: 8 * s), radius: 5 * s, color: .white, opacity: 0.92)
        }
    }

    static func drawVessel(_ g: GraphicsContext, kind: PIngredient, center c: CGPoint, scale: CGFloat, time t: CGFloat) {
        let bottle = PotionBottle(
            id: kind.dockIndex + 1,
            r: kind.color.r,
            g: kind.color.g,
            b: kind.color.b,
            fill: 0.84,
            shape: kind.vesselShape.rawValue,
            kind: nil,
            magic: [kind.magic.rawValue: 1],
            glow: 0.35,
            sparkle: 0.6
        )
        PotionBottlePainter.draw(g, bottle: bottle, center: c, angle: 0, scale: scale, time: t, cork: false)
        // Iconic medallion badge right on the vessel belly.
        let badgeR = 19 * scale
        let badge = Path(ellipseIn: CGRect(x: c.x - badgeR, y: c.y + 12 * scale - badgeR, width: badgeR * 2, height: badgeR * 2))
        StorybookArt.fillAndStroke(g, badge, fill: Color(hex: 0xFFF9F2), stroke: StorybookArt.outline(for: kind.hex), width: 2 * scale)
        drawEmblem(g, kind: kind, center: CGPoint(x: c.x, y: c.y + 12 * scale), radius: 13 * scale)
    }
}

struct IngredientIconView: View {
    let kind: PIngredient

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) * 0.42
            IngredientIconPainter.drawEmblem(ctx, kind: kind, center: CGPoint(x: size.width / 2, y: size.height / 2), radius: r)
        }
    }
}

// MARK: - Specialty Shaped Bottles & Spoiler-Free Silhouettes

enum PotionBottlePainter {
    static func draw(
        _ g: GraphicsContext,
        bottle b: PotionBottle,
        center: CGPoint,
        angle: CGFloat,
        scale: CGFloat,
        time t: CGFloat,
        cork: Bool = true
    ) {
        let shape = b.bottleShape
        let poly = PPoly.transform(shape.outline, at: center, angle: angle, scale: scale)

        if b.glow > 0.2 {
            var gl = g
            gl.blendMode = .plusLighter
            let r = 68 * scale
            gl.fill(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .radialGradient(
                    Gradient(colors: [b.color.c(0.36 * b.glow * (0.85 + 0.15 * sin(Double(t) * 2.5))), .clear]),
                    center: center,
                    startRadius: 4,
                    endRadius: r
                )
            )
        }

        if b.fill > 0.01 {
            let lvl = PPoly.level(poly, fill: CGFloat(b.fill))
            let liq = PPoly.below(poly, lvl)
            var lp = Path()
            lp.addLines(liq)
            lp.closeSubpath()
            var inner = g
            inner.clip(to: lp)
            if b.potion == .rainbow || b.potion == .wild {
                let cols = (0..<6).map { PotionColor.hue(CGFloat($0) / 6 + (b.potion == .wild ? t * 0.12 : 0)).c(0.95) }
                inner.fill(
                    Path(lp.boundingRect.insetBy(dx: -4, dy: -4)),
                    with: .linearGradient(Gradient(colors: cols), startPoint: CGPoint(x: center.x, y: lp.boundingRect.minY), endPoint: CGPoint(x: center.x, y: lp.boundingRect.maxY))
                )
            } else {
                inner.fill(
                    Path(lp.boundingRect.insetBy(dx: -4, dy: -4)),
                    with: .linearGradient(
                        Gradient(colors: [b.color.mix(RGB(1, 1, 1), 0.25).c(0.94), b.color.mul(0.8, 0.76, 0.86).c(0.96)]),
                        startPoint: CGPoint(x: center.x, y: lvl),
                        endPoint: CGPoint(x: center.x, y: lp.boundingRect.maxY)
                    )
                )
            }
            drawBottleMagic(inner, b, center: center, scale: scale, time: t)
            if let a = liq.first(where: { abs($0.y - lvl) < 0.5 }), let z = liq.last(where: { abs($0.y - lvl) < 0.5 }) {
                var surf = Path()
                surf.move(to: a)
                surf.addLine(to: z)
                g.stroke(surf, with: .color(.white.opacity(0.65)), lineWidth: 1.5 * scale + 0.5)
            }
        }

        drawGlass(g, poly: poly, center: center, angle: angle, scale: scale, shape: shape)
        if cork { drawCork(g, shape: shape, center: center, angle: angle, scale: scale) }
        if b.potion != nil {
            Twinkles.draw(g, around: center, radius: 44 * scale, time: t + CGFloat(b.id), count: 2, alpha: 0.9)
        }
    }

    /// Spoiler-free uniform lavender mystery silhouette for unfound potions in the Picture Spellbook.
    static func mysterySilhouette(_ g: GraphicsContext, shape: PBottleShape, center: CGPoint, scale: CGFloat, time t: CGFloat) {
        let poly = PPoly.transform(shape.outline, at: center, angle: 0, scale: scale)
        var p = Path()
        p.addLines(poly)
        p.closeSubpath()
        g.fill(p, with: .color(Theme.ink.opacity(0.18)))
        g.stroke(p, with: .color(Theme.lilac.opacity(0.75)), style: StrokeStyle(lineWidth: 2.5 * scale, dash: [6 * scale, 4 * scale]))

        // Mystery cork silhouette.
        var l = g
        l.translateBy(x: center.x, y: center.y)
        l.scaleBy(x: scale, y: scale)
        let n = shape.neck
        let corkRect = CGRect(x: -n + 1, y: PBottleShape.mouthY - 15, width: n * 2 - 2, height: 17)
        l.fill(Path(roundedRect: corkRect, cornerRadius: 4), with: .color(Theme.ink.opacity(0.16)))

        // Sparkling mystery stars (zero potion color leaked!).
        StorybookArt.sparkle(g, at: CGPoint(x: center.x, y: center.y + 12 * scale), radius: 13 * scale * (0.9 + 0.12 * sin(t * 3)), color: .white, opacity: 0.88)
        StorybookArt.sparkle(g, at: CGPoint(x: center.x + 18 * scale, y: center.y - 8 * scale), radius: 7 * scale, color: Theme.lemon, opacity: 0.82)
    }

    private static func drawBottleMagic(_ g: GraphicsContext, _ b: PotionBottle, center: CGPoint, scale: CGFloat, time t: CGFloat) {
        let s = scale
        if b.sparkle > 0.2 {
            var dots = Path()
            for k in 0..<Int(5 + b.sparkle * 8) {
                let x = center.x + CGFloat((k * 37) % 56 - 28) * s
                let y = center.y + CGFloat((k * 53) % 82 - 26) * s + sin(t * 0.9 + CGFloat(k)) * 3.5 * s
                let r = (1.2 + CGFloat(k % 3) * 0.7) * s * (0.7 + 0.3 * sin(t * 4 + CGFloat(k) * 1.7))
                dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            g.fill(dots, with: .color(.white.opacity(0.9)))
        }
        switch b.potion {
        case .love?:
            for k in 0..<3 {
                let y = center.y + 38 * s - ((t * 14 + CGFloat(k) * 26).truncatingRemainder(dividingBy: 72)) * s
                let x = center.x + CGFloat(k - 1) * 15 * s
                StorybookArt.heart(g, at: CGPoint(x: x, y: y), size: 11 * s, color: .white, opacity: 0.85)
            }
        case .mermaid?, .wild?:
            var bub = Path()
            for k in 0..<5 {
                let y = center.y + 46 * s - ((t * 20 + CGFloat(k) * 18).truncatingRemainder(dividingBy: 82)) * s
                let x = center.x + CGFloat((k * 23) % 36 - 18) * s
                let r = (2 + CGFloat(k % 3)) * s
                bub.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            g.stroke(bub, with: .color(.white.opacity(0.85)), lineWidth: 1.2)
        case .frost?:
            var fl = Path()
            let c = CGPoint(x: center.x, y: center.y + 12 * s)
            for a in 0..<3 {
                let ang = CGFloat(a) * .pi / 3 + t * 0.3
                fl.move(to: CGPoint(x: c.x - cos(ang) * 11 * s, y: c.y - sin(ang) * 11 * s))
                fl.addLine(to: CGPoint(x: c.x + cos(ang) * 11 * s, y: c.y + sin(ang) * 11 * s))
            }
            g.stroke(fl, with: .color(.white.opacity(0.9)), lineWidth: 2 * s)
        case .dream?, .moonlight?:
            let c = CGPoint(x: center.x, y: center.y + 14 * s)
            var moon = Path(ellipseIn: CGRect(x: c.x - 11 * s, y: c.y - 11 * s, width: 22 * s, height: 22 * s))
            moon.addEllipse(in: CGRect(x: c.x - 5 * s, y: c.y - 15 * s, width: 22 * s, height: 22 * s))
            g.fill(moon, with: .color(RGB(hex: "#FFF2BC").c(0.92)), style: FillStyle(eoFill: true))
        case .golden?, .galaxy?:
            StorybookArt.sparkle(g, at: CGPoint(x: center.x, y: center.y + 14 * s), radius: 13 * s, color: .white, opacity: 0.92)
        default:
            break
        }
    }

    static func drawGlass(_ g: GraphicsContext, poly: [CGPoint], center: CGPoint, angle: CGFloat, scale: CGFloat, shape: PBottleShape) {
        var p = Path()
        p.addLines(poly)
        p.closeSubpath()
        g.fill(p, with: .color(.white.opacity(0.16)))
        g.stroke(p, with: .color(RGB(hex: "#8E7BC0").c(0.6)), lineWidth: 4.4 * scale)
        g.stroke(p, with: .color(.white.opacity(0.92)), lineWidth: 2.2 * scale)
        var l = g
        l.translateBy(x: center.x, y: center.y)
        l.rotate(by: .radians(Double(angle)))
        l.scaleBy(x: scale, y: scale)
        l.fill(Path(roundedRect: CGRect(x: -shape.neck - 15, y: -8, width: 7, height: 38), cornerRadius: 3.5), with: .color(.white.opacity(0.56)))
        let n = shape.neck
        let lip = Path(roundedRect: CGRect(x: -n - 4, y: PBottleShape.mouthY - 3, width: n * 2 + 8, height: 8), cornerRadius: 3)
        l.fill(lip, with: .color(.white.opacity(0.78)))
        l.stroke(lip, with: .color(RGB(hex: "#8E7BC0").c(0.55)), lineWidth: 1.5)
    }

    static func drawCork(_ g: GraphicsContext, shape: PBottleShape, center: CGPoint, angle: CGFloat, scale: CGFloat) {
        var l = g
        l.translateBy(x: center.x, y: center.y)
        l.rotate(by: .radians(Double(angle)))
        l.scaleBy(x: scale, y: scale)
        let n = shape.neck
        let r = CGRect(x: -n + 1, y: PBottleShape.mouthY - 16, width: n * 2 - 2, height: 18)
        StorybookArt.shape(l, Path(roundedRect: r, cornerRadius: 4), hex: 0xCE986A, width: 2)
        l.fill(Path(ellipseIn: CGRect(x: r.minX + 2, y: r.minY + 3, width: 4, height: 4)), with: .color(StorybookArt.outline(for: 0xCE986A).opacity(0.55)))
    }
}
