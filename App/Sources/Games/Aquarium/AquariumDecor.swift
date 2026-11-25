import SwiftUI

enum AquaDecorPainter {
    static func draw(_ ctx: GraphicsContext, _ d: AquaDecor, time t: CGFloat) {
        var g = ctx
        g.translateBy(x: d.x, y: d.y)
        let since = CGFloat(Double(t) - d.poke)
        let wobble = since >= 0 && since < 1.2 ? sin(since * 18) * 0.07 * exp(-since * 3.5) : 0
        g.rotate(by: .radians(Double(d.rot + wobble)))
        let sq = max(-0.25, min(0.3, d.squash))
        g.scaleBy(x: (d.flip ? -1 : 1) * (1 + sq * 0.5), y: 1 - sq)
        let sway = (d.flip ? -1 : 1) * d.sway
        drawKind(g, d.kind, time: t, sway: sway, open: d.open, seed: d.id, boosted: Double(t) < d.boostUntil)
    }

    static func drawKind(
        _ g: GraphicsContext,
        _ k: AquaDecorKind,
        time t: CGFloat,
        sway: CGFloat,
        open: CGFloat,
        seed: Int,
        boosted: Bool = false
    ) {
        switch k {
        case .castle: castle(g, t: t)
        case .chest: chest(g, open: open, t: t)
        case .diver: diver(g)
        case .bubbler: bubbler(g, boosted: boosted, t: t)
        case .ship: ship(g)
        case .rock: rock(g)
        case .seaweed: seaweed(g, t: t, sway: sway, seed: seed)
        case .coral: coral(g)
        case .anemone: anemone(g, t: t, sway: sway, seed: seed)
        case .grass: grass(g, t: t, sway: sway, seed: seed)
        case .shell: shell(g)
        case .starfish: starfish(g)
        case .crystal: TreasureArt.crystals(g, glow: 0.5 + 0.2 * sin(t * 1.6))
        case .rainbowCoral: TreasureArt.rainbowCoral(g, sway: sway + sin(t * 0.9 + CGFloat(seed)) * 0.3)
        case .unicorn: TreasureArt.unicorn(g)
        case .koiBridge: koiBridge(g, t: t)
        }
    }

    private static func strokeStyle(_ width: CGFloat = 2.4) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    private static func shaded(
        _ g: GraphicsContext,
        _ p: Path,
        hex: UInt32,
        top: CGFloat,
        bottom: CGFloat,
        line: CGFloat = 2.4
    ) {
        g.fill(
            p,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.tint(for: hex, amount: 0.22), StorybookArt.color(hex), StorybookArt.shade(for: hex, factor: 0.84)]),
                startPoint: CGPoint(x: 0, y: top),
                endPoint: CGPoint(x: 0, y: bottom)
            )
        )
        g.stroke(p, with: .color(StorybookArt.outline(for: hex, factor: 0.58)), style: strokeStyle(line))
    }

    private static func moss(_ g: GraphicsContext, width w: CGFloat, seed: Int) {
        var p = Path()
        for k in 0..<Int(w / 10) {
            let x = -w / 2 + CGFloat(k) * 10 + aqRand(k, seed) * 4
            let r = 4.5 + aqRand(k, seed + 1) * 4.5
            p.addEllipse(in: CGRect(x: x - r, y: -r * 1.25, width: r * 2, height: r * 1.65))
        }
        g.fill(p, with: .color(StorybookArt.color(0x6CC482, alpha: 0.72)))
        g.stroke(p, with: .color(StorybookArt.outline(for: 0x6CC482, factor: 0.62).opacity(0.45)), style: strokeStyle(1.4))
    }

    // MARK: - Free Reef Props (12)

    static func castle(_ g: GraphicsContext, t: CGFloat = 0) {
        let stoneHex: UInt32 = 0xD2C1F2
        let roofHex: UInt32 = 0xFF9AC4
        let goldHex: UInt32 = 0xFFE07D

        func tower(_ x0: CGFloat, _ x1: CGFloat, _ top: CGFloat, roofed: Bool, flagPhase: CGFloat) {
            let w = x1 - x0
            let mid = (x0 + x1) * 0.5
            let body = Path(roundedRect: CGRect(x: x0, y: top, width: w, height: -top + 2), cornerRadius: 8)
            shaded(g, body, hex: stoneHex, top: top, bottom: 0, line: 2.6)
            StorybookArt.highlight(g, in: CGRect(x: x0 + 5, y: top + 10, width: 6, height: min(36, -top * 0.4)), opacity: 0.35)

            if roofed {
                var cone = Path()
                cone.move(to: CGPoint(x: x0 - 7, y: top + 3))
                cone.addQuadCurve(to: CGPoint(x: mid, y: top - 40), control: CGPoint(x: x0 + 2, y: top - 22))
                cone.addQuadCurve(to: CGPoint(x: x1 + 7, y: top + 3), control: CGPoint(x: x1 - 2, y: top - 22))
                cone.addQuadCurve(to: CGPoint(x: x0 - 7, y: top + 3), control: CGPoint(x: mid, y: top + 9))
                cone.closeSubpath()
                shaded(g, cone, hex: roofHex, top: top - 40, bottom: top + 6, line: 2.4)
                StorybookArt.highlight(g, in: CGRect(x: mid - 9, y: top - 24, width: 6, height: 14), opacity: 0.4)

                var flag = Path()
                let wave = sin(t * 2.6 + flagPhase) * 2.5
                flag.move(to: CGPoint(x: mid, y: top - 40))
                flag.addLine(to: CGPoint(x: mid, y: top - 56))
                g.stroke(flag, with: .color(StorybookArt.outline(for: goldHex)), style: strokeStyle(2.2))

                var pennant = Path()
                pennant.move(to: CGPoint(x: mid, y: top - 55))
                pennant.addQuadCurve(to: CGPoint(x: mid + 17, y: top - 50 + wave), control: CGPoint(x: mid + 9, y: top - 57 + wave))
                pennant.addQuadCurve(to: CGPoint(x: mid, y: top - 44), control: CGPoint(x: mid + 8, y: top - 46 + wave * 0.5))
                pennant.closeSubpath()
                StorybookArt.shape(g, pennant, hex: goldHex, width: 1.8)
            } else {
                let n = 4
                let bw = w / CGFloat(n * 2 - 1)
                for k in 0..<n {
                    let merlon = Path(roundedRect: CGRect(x: x0 + CGFloat(k * 2) * bw - 1, y: top - 11, width: bw + 2, height: 14), cornerRadius: 4)
                    shaded(g, merlon, hex: stoneHex, top: top - 11, bottom: top + 3, line: 2.2)
                }
            }

            let win = Path(roundedRect: CGRect(x: mid - 6, y: top + 18, width: 12, height: 18), cornerRadius: 6)
            g.fill(win, with: .linearGradient(Gradient(colors: [StorybookArt.color(0x52C8E8), StorybookArt.color(0x2F568A)]),
                                              startPoint: CGPoint(x: mid, y: top + 18), endPoint: CGPoint(x: mid, y: top + 36)))
            g.stroke(win, with: .color(StorybookArt.outline(for: stoneHex)), style: strokeStyle(2.0))
        }

        tower(-72, -36, -124, roofed: true, flagPhase: 0)
        tower(36, 72, -110, roofed: true, flagPhase: 1.8)
        tower(-28, 28, -162, roofed: false, flagPhase: 0.9)

        let wall = Path(roundedRect: CGRect(x: -50, y: -74, width: 100, height: 76), cornerRadius: 10)
        shaded(g, wall, hex: stoneHex, top: -74, bottom: 2, line: 2.6)
        for k in 0..<5 {
            let m = Path(roundedRect: CGRect(x: -46 + CGFloat(k) * 20, y: -84, width: 12, height: 13), cornerRadius: 4)
            shaded(g, m, hex: stoneHex, top: -84, bottom: -71, line: 2.0)
        }

        var bricks = Path()
        for row in 0..<4 {
            let y = -18 - CGFloat(row) * 14
            for k in 0..<3 {
                let x = -34 + CGFloat(k) * 28 + CGFloat(row % 2) * 10
                bricks.addRoundedRect(in: CGRect(x: x, y: y, width: 14, height: 7), cornerSize: CGSize(width: 3, height: 3))
            }
        }
        g.fill(bricks, with: .color(StorybookArt.shade(for: stoneHex, factor: 0.88).opacity(0.55)))

        var door = Path()
        door.move(to: CGPoint(x: -20, y: 0))
        door.addLine(to: CGPoint(x: -20, y: -30))
        door.addArc(center: CGPoint(x: 0, y: -30), radius: 20, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        door.addLine(to: CGPoint(x: 20, y: 0))
        door.closeSubpath()
        g.fill(door, with: .linearGradient(Gradient(colors: [StorybookArt.color(0x27366B), StorybookArt.color(0x4764A6)]),
                                           startPoint: CGPoint(x: 0, y: -50), endPoint: CGPoint(x: 0, y: 0)))
        g.stroke(door, with: .color(StorybookArt.outline(for: stoneHex)), style: strokeStyle(2.8))
        moss(g, width: 136, seed: 3)
    }

    static func chest(_ g: GraphicsContext, open: CGFloat, t: CGFloat) {
        let woodHex: UInt32 = 0xC6834D
        let goldHex: UInt32 = 0xFFD25A

        if open > 0.04 {
            let glow = Double(open)
            g.fill(
                Path(ellipseIn: CGRect(x: -48, y: -74, width: 96, height: 54)),
                with: .radialGradient(
                    Gradient(colors: [StorybookArt.color(0xFFF3B0, alpha: 0.9 * glow), StorybookArt.color(0xFFF3B0, alpha: 0)]),
                    center: CGPoint(x: 0, y: -46),
                    startRadius: 2,
                    endRadius: 48
                )
            )
            var coins = Path()
            for k in 0..<8 {
                let x = -31 + CGFloat(k) * 9
                coins.addEllipse(in: CGRect(x: x - 6, y: -49 - CGFloat(k % 3) * 4.5, width: 12, height: 7.5))
            }
            g.fill(coins, with: .color(StorybookArt.color(goldHex)))
            g.stroke(coins, with: .color(StorybookArt.outline(for: goldHex)), style: strokeStyle(1.4))
            StorybookArt.sparkle(g, at: CGPoint(x: -18, y: -60 - 4 * open), radius: 5.5 * open, color: Theme.lemon, opacity: glow)
            StorybookArt.sparkle(g, at: CGPoint(x: 22, y: -58 - 6 * open), radius: 4.5 * open, color: .white, opacity: glow)
        }

        let box = Path(roundedRect: CGRect(x: -44, y: -42, width: 88, height: 42), cornerRadius: 10)
        shaded(g, box, hex: woodHex, top: -42, bottom: 0, line: 2.6)
        var planks = Path()
        for k in 1..<3 {
            planks.move(to: CGPoint(x: -42, y: -CGFloat(k) * 14))
            planks.addLine(to: CGPoint(x: 42, y: -CGFloat(k) * 14))
        }
        g.stroke(planks, with: .color(StorybookArt.outline(for: woodHex).opacity(0.45)), style: strokeStyle(1.6))

        for x in [-33, 25] as [CGFloat] {
            let band = Path(roundedRect: CGRect(x: x, y: -42, width: 8, height: 42), cornerRadius: 3)
            shaded(g, band, hex: goldHex, top: -42, bottom: 0, line: 1.8)
        }

        var lg = g
        lg.translateBy(x: -44, y: -40)
        lg.rotate(by: .radians(Double(-open * 1.08)))
        var lid = Path()
        lid.move(to: CGPoint(x: 0, y: 0))
        lid.addQuadCurve(to: CGPoint(x: 6, y: -18), control: CGPoint(x: -2, y: -12))
        lid.addQuadCurve(to: CGPoint(x: 82, y: -18), control: CGPoint(x: 44, y: -38))
        lid.addQuadCurve(to: CGPoint(x: 88, y: 0), control: CGPoint(x: 90, y: -12))
        lid.closeSubpath()
        shaded(lg, lid, hex: woodHex, top: -32, bottom: 0, line: 2.6)
        for x in [11, 69] as [CGFloat] {
            let band = Path(roundedRect: CGRect(x: x, y: -26, width: 8, height: 26), cornerRadius: 3)
            shaded(lg, band, hex: goldHex, top: -26, bottom: 0, line: 1.6)
        }
        StorybookArt.highlight(lg, in: CGRect(x: 24, y: -25, width: 34, height: 6), opacity: 0.32)

        let lock = Path(roundedRect: CGRect(x: -9, y: -47, width: 18, height: 19), cornerRadius: 6)
        shaded(g, lock, hex: goldHex, top: -47, bottom: -28, line: 2.0)
        StorybookArt.heart(g, at: CGPoint(x: 0, y: -38), size: 8, color: StorybookArt.outline(for: woodHex))
        moss(g, width: 78, seed: 9)
    }

    static func diver(_ g: GraphicsContext) {
        let brassHex: UInt32 = 0xF0BA52
        let suitHex: UInt32 = 0x8DBCE0
        let bootHex: UInt32 = 0x7A688A

        for x in [-16, 3] as [CGFloat] {
            let leg = Path(roundedRect: CGRect(x: x, y: -46, width: 14, height: 39), cornerRadius: 7)
            shaded(g, leg, hex: suitHex, top: -46, bottom: -7, line: 2.4)
            let boot = Path(roundedRect: CGRect(x: x - 3, y: -14, width: 20, height: 14), cornerRadius: 6)
            shaded(g, boot, hex: bootHex, top: -14, bottom: 0, line: 2.2)
        }

        let body = Path(roundedRect: CGRect(x: -23, y: -86, width: 46, height: 46), cornerRadius: 18)
        shaded(g, body, hex: suitHex, top: -86, bottom: -40, line: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -79, width: 10, height: 18), opacity: 0.32)

        var arms = Path()
        arms.move(to: CGPoint(x: -21, y: -76))
        arms.addQuadCurve(to: CGPoint(x: -32, y: -50), control: CGPoint(x: -35, y: -68))
        arms.move(to: CGPoint(x: 21, y: -76))
        arms.addQuadCurve(to: CGPoint(x: 34, y: -62), control: CGPoint(x: 34, y: -76))
        g.stroke(arms, with: .color(StorybookArt.outline(for: suitHex)), style: strokeStyle(14))
        g.stroke(arms, with: .color(StorybookArt.color(suitHex)), style: strokeStyle(9.5))
        for glove in [CGPoint(x: -32, y: -49), CGPoint(x: 34, y: -62)] {
            StorybookArt.shape(g, AquaShape.circle(glove, 6), hex: brassHex, width: 2.0)
        }

        let belt = Path(roundedRect: CGRect(x: -23, y: -51, width: 46, height: 9), cornerRadius: 4)
        shaded(g, belt, hex: bootHex, top: -51, bottom: -42, line: 1.8)
        StorybookArt.shape(g, Path(roundedRect: CGRect(x: -6, y: -52, width: 12, height: 11), cornerRadius: 3), hex: brassHex, width: 1.8)

        let collar = Path(roundedRect: CGRect(x: -22, y: -95, width: 44, height: 13), cornerRadius: 6)
        shaded(g, collar, hex: brassHex, top: -95, bottom: -82, line: 2.2)

        let helmet = AquaShape.circle(CGPoint(x: 0, y: -109), 23)
        g.fill(
            helmet,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.tint(for: brassHex, amount: 0.45), StorybookArt.color(brassHex), StorybookArt.shade(for: brassHex, factor: 0.78)]),
                center: CGPoint(x: -8, y: -118),
                startRadius: 2,
                endRadius: 29
            )
        )
        g.stroke(helmet, with: .color(StorybookArt.outline(for: brassHex)), style: strokeStyle(2.6))

        let window = AquaShape.circle(CGPoint(x: 4, y: -108), 11.5)
        g.fill(window, with: .linearGradient(Gradient(colors: [StorybookArt.color(0xA6ECFF), StorybookArt.color(0x3B7FA8)]),
                                             startPoint: CGPoint(x: 0, y: -119), endPoint: CGPoint(x: 0, y: -96)))
        g.stroke(window, with: .color(StorybookArt.outline(for: brassHex)), style: strokeStyle(3.0))
        StorybookArt.highlight(g, in: CGRect(x: -2, y: -116, width: 7, height: 5), opacity: 0.8)

        var bolts = Path()
        for a in stride(from: 0.0, to: 6.28, by: 1.05) {
            bolts.addEllipse(in: CGRect(x: 4 + cos(CGFloat(a)) * 15 - 1.8, y: -108 + sin(CGFloat(a)) * 15 - 1.8, width: 3.6, height: 3.6))
        }
        g.fill(bolts, with: .color(StorybookArt.outline(for: brassHex)))

        let valve = Path(roundedRect: CGRect(x: 3, y: -136, width: 10, height: 9), cornerRadius: 4)
        shaded(g, valve, hex: brassHex, top: -136, bottom: -127, line: 2.0)
    }

    static func bubbler(_ g: GraphicsContext, boosted: Bool = false, t: CGFloat = 0) {
        let stoneHex: UInt32 = 0x8EA8BF
        let glowHex: UInt32 = 0x8EE8FF

        var hose = Path()
        hose.move(to: CGPoint(x: 24, y: -8))
        hose.addQuadCurve(to: CGPoint(x: 40, y: -2), control: CGPoint(x: 36, y: -11))
        g.stroke(hose, with: .color(StorybookArt.color(0xB9E3D9, alpha: 0.78)), style: strokeStyle(4.5))

        var mound = Path()
        mound.move(to: CGPoint(x: -30, y: 0))
        mound.addQuadCurve(to: CGPoint(x: -16, y: -32), control: CGPoint(x: -28, y: -22))
        mound.addQuadCurve(to: CGPoint(x: 16, y: -32), control: CGPoint(x: 0, y: -26))
        mound.addQuadCurve(to: CGPoint(x: 30, y: 0), control: CGPoint(x: 28, y: -22))
        mound.closeSubpath()
        shaded(g, mound, hex: stoneHex, top: -32, bottom: 0, line: 2.6)

        let vent = Path(ellipseIn: CGRect(x: -15, y: -35, width: 30, height: 11))
        let ventFill = boosted
            ? StorybookArt.color(glowHex, alpha: 0.95)
            : StorybookArt.color(0x4E88A8)
        StorybookArt.fillAndStroke(g, vent, fill: ventFill, stroke: StorybookArt.outline(for: stoneHex), width: 2.2)

        if boosted {
            let pulse = 1 + 0.14 * sin(t * 14)
            g.fill(
                Path(ellipseIn: CGRect(x: -22 * pulse, y: -44 * pulse, width: 44 * pulse, height: 22 * pulse)),
                with: .radialGradient(
                    Gradient(colors: [StorybookArt.color(glowHex, alpha: 0.65), StorybookArt.color(glowHex, alpha: 0)]),
                    center: CGPoint(x: 0, y: -33),
                    startRadius: 2,
                    endRadius: 24
                )
            )
        }
        StorybookArt.highlight(g, in: CGRect(x: -18, y: -18, width: 10, height: 6), opacity: 0.32)
    }

    static func ship(_ g: GraphicsContext) {
        let woodHex: UInt32 = 0xA8704A
        let goldHex: UInt32 = 0xF0BA52
        var s = g
        s.rotate(by: .radians(-0.09))

        var mast = Path()
        mast.move(to: CGPoint(x: -6, y: -58))
        mast.addLine(to: CGPoint(x: 6, y: -146))
        s.stroke(mast, with: .color(StorybookArt.outline(for: woodHex)), style: strokeStyle(10.5))
        s.stroke(mast, with: .color(StorybookArt.tint(for: woodHex, amount: 0.12)), style: strokeStyle(6.5))

        var sail = Path()
        sail.move(to: CGPoint(x: 4, y: -134))
        sail.addQuadCurve(to: CGPoint(x: 62, y: -120), control: CGPoint(x: 40, y: -142))
        sail.addLine(to: CGPoint(x: 52, y: -98))
        sail.addLine(to: CGPoint(x: 60, y: -84))
        sail.addQuadCurve(to: CGPoint(x: 0, y: -80), control: CGPoint(x: 30, y: -90))
        sail.closeSubpath()
        StorybookArt.fillAndStroke(s, sail, fill: StorybookArt.color(0xF6EFE0, alpha: 0.88), stroke: StorybookArt.outline(for: 0xDDD0B6), width: 2.0)

        var hull = Path()
        hull.move(to: CGPoint(x: -112, y: -64))
        hull.addLine(to: CGPoint(x: 96, y: -62))
        hull.addQuadCurve(to: CGPoint(x: 116, y: -84), control: CGPoint(x: 112, y: -66))
        hull.addQuadCurve(to: CGPoint(x: 84, y: 4), control: CGPoint(x: 110, y: -16))
        hull.addLine(to: CGPoint(x: -96, y: 6))
        hull.addQuadCurve(to: CGPoint(x: -112, y: -64), control: CGPoint(x: -116, y: -24))
        hull.closeSubpath()
        shaded(s, hull, hex: woodHex, top: -84, bottom: 6, line: 2.8)

        var planks = Path()
        for k in 1..<5 {
            let y = -64 + CGFloat(k) * 14
            planks.move(to: CGPoint(x: -108 + CGFloat(k) * 3, y: y))
            planks.addLine(to: CGPoint(x: 98 - CGFloat(k) * 4, y: y))
        }
        s.stroke(planks, with: .color(StorybookArt.outline(for: woodHex).opacity(0.42)), style: strokeStyle(1.4))

        for x in [-60, -14, 32] as [CGFloat] {
            let hole = AquaShape.circle(CGPoint(x: x, y: -36), 9.5)
            s.fill(hole, with: .color(StorybookArt.color(0x23385C, alpha: 0.92)))
            s.stroke(hole, with: .color(StorybookArt.color(goldHex)), style: strokeStyle(3.2))
        }

        var rail = Path()
        for k in 0..<10 {
            let x = -100 + CGFloat(k) * 20
            rail.move(to: CGPoint(x: x, y: -64))
            rail.addLine(to: CGPoint(x: x, y: -76))
        }
        rail.move(to: CGPoint(x: -104, y: -76))
        rail.addLine(to: CGPoint(x: 90, y: -76))
        s.stroke(rail, with: .color(StorybookArt.outline(for: woodHex)), style: strokeStyle(2.8))
        moss(s, width: 170, seed: 21)
    }

    static func rock(_ g: GraphicsContext) {
        let rockHex: UInt32 = 0x95A6BC
        let pebbleHex: UInt32 = 0xB2C0D4

        var big = Path()
        big.move(to: CGPoint(x: -72, y: 0))
        big.addCurve(to: CGPoint(x: -20, y: -90), control1: CGPoint(x: -76, y: -50), control2: CGPoint(x: -56, y: -88))
        big.addCurve(to: CGPoint(x: 56, y: -52), control1: CGPoint(x: 14, y: -94), control2: CGPoint(x: 50, y: -80))
        big.addCurve(to: CGPoint(x: 70, y: 0), control1: CGPoint(x: 64, y: -30), control2: CGPoint(x: 72, y: -16))
        big.closeSubpath()
        shaded(g, big, hex: rockHex, top: -92, bottom: 0, line: 2.8)

        var arch = Path()
        arch.move(to: CGPoint(x: -30, y: 0))
        arch.addCurve(to: CGPoint(x: 26, y: 0), control1: CGPoint(x: -30, y: -56), control2: CGPoint(x: 26, y: -56))
        arch.closeSubpath()
        g.fill(arch, with: .linearGradient(Gradient(colors: [StorybookArt.color(0x234263), StorybookArt.color(0x3D6A8F)]),
                                           startPoint: CGPoint(x: 0, y: -44), endPoint: CGPoint(x: 0, y: 0)))
        g.stroke(arch, with: .color(StorybookArt.outline(for: rockHex)), style: strokeStyle(2.2))

        let small = Path(ellipseIn: CGRect(x: 40, y: -34, width: 40, height: 36))
        shaded(g, small, hex: pebbleHex, top: -34, bottom: 2, line: 2.4)
        StorybookArt.highlight(g, in: CGRect(x: -32, y: -82, width: 32, height: 10), opacity: 0.32)
        moss(g, width: 120, seed: 14)
    }

    static func seaweed(_ g: GraphicsContext, t: CGFloat, sway: CGFloat, seed: Int) {
        let greens = [ARGB(0x3FA85A), ARGB(0x58C06C), ARGB(0x2F9450), ARGB(0x6BCB7A)]
        let bases: [CGFloat] = [-26, -9, 8, 24]
        let heights: [CGFloat] = [190, 245, 210, 160]
        for i in 0..<4 {
            let hgt = heights[i], x0 = bases[i]
            let n = 12
            var left: [CGPoint] = [], right: [CGPoint] = [], mid: [CGPoint] = []
            for k in 0...n {
                let u = CGFloat(k) / CGFloat(n)
                let current = sin(t * 0.9 + CGFloat(i) * 1.3 + CGFloat(seed)) * 0.25
                let bendX = (sway + current) * pow(u, 1.6) * hgt * 0.4
                let wave = sin(t * 1.8 + u * 5 + CGFloat(i * 2)) * 7 * u
                let c = CGPoint(x: x0 + bendX + wave, y: -u * hgt * (1 - abs(sway) * 0.1 * u))
                let w = (9 - 6 * u) * (1 + 0.35 * sin(u * 11 + CGFloat(i)))
                left.append(CGPoint(x: c.x - w, y: c.y))
                right.append(CGPoint(x: c.x + w, y: c.y))
                mid.append(c)
            }
            let ribbon = AquaShape.smoothClosed(left + right.reversed())
            let col = greens[i]
            g.fill(ribbon, with: .linearGradient(Gradient(colors: [col.shade(-0.22).color, col.color, col.shade(0.22).color]),
                                                 startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: -hgt)))
            g.stroke(ribbon, with: .color(col.shade(-0.4).color(0.75)), style: strokeStyle(1.6))
            g.stroke(AquaShape.smoothOpen(mid), with: .color(col.shade(0.35).color(0.45)), style: strokeStyle(1.3))
        }
    }

    static func coral(_ g: GraphicsContext) {
        let pinkHex: UInt32 = 0xFF8FA8
        var branches = Path()
        var tips: [CGPoint] = []
        func grow(_ p: CGPoint, _ a: CGFloat, _ len: CGFloat, _ depth: Int, _ id: Int) {
            let q = CGPoint(x: p.x + cos(a) * len, y: p.y + sin(a) * len)
            branches.move(to: p)
            branches.addQuadCurve(to: q, control: CGPoint(x: (p.x + q.x) / 2 + (aqRand(id, 1) - 0.5) * 8, y: (p.y + q.y) / 2))
            if depth == 0 { tips.append(q); return }
            grow(q, a - 0.42 - aqRand(id, 2) * 0.2, len * 0.74, depth - 1, id * 2 + 1)
            grow(q, a + 0.38 + aqRand(id, 3) * 0.2, len * 0.72, depth - 1, id * 2 + 2)
        }
        grow(CGPoint(x: -8, y: 0), -.pi / 2 - 0.25, 36, 3, 1)
        grow(CGPoint(x: 10, y: 0), -.pi / 2 + 0.3, 30, 3, 9)
        g.stroke(branches, with: .color(StorybookArt.outline(for: pinkHex)), style: strokeStyle(12.5))
        g.stroke(branches, with: .color(StorybookArt.color(pinkHex)), style: strokeStyle(8.5))
        g.stroke(branches, with: .color(StorybookArt.tint(for: pinkHex, amount: 0.45).opacity(0.6)), style: strokeStyle(2.5))
        var polyps = Path()
        for p in tips { polyps.addEllipse(in: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)) }
        StorybookArt.fillAndStroke(g, polyps, fill: StorybookArt.color(0xFFDCE6), stroke: StorybookArt.outline(for: pinkHex), width: 1.4)
    }

    static func anemone(_ g: GraphicsContext, t: CGFloat, sway: CGFloat, seed: Int) {
        let baseHex: UInt32 = 0xA87CE3
        let armHex: UInt32 = 0xD2AEFF

        var stalk = Path()
        stalk.move(to: CGPoint(x: -26, y: 0))
        stalk.addQuadCurve(to: CGPoint(x: -20, y: -32), control: CGPoint(x: -30, y: -16))
        stalk.addLine(to: CGPoint(x: 20, y: -32))
        stalk.addQuadCurve(to: CGPoint(x: 26, y: 0), control: CGPoint(x: 30, y: -16))
        stalk.closeSubpath()
        shaded(g, stalk, hex: baseHex, top: -32, bottom: 0, line: 2.4)

        var arms = Path()
        var tips = Path()
        for k in 0..<16 {
            let f = CGFloat(k) / 15 * 2 - 1
            let p0 = CGPoint(x: f * 20, y: -30)
            let a = -CGFloat.pi / 2 + f * 1.1 + (sway + sin(t * 1.4 + CGFloat(k) * 0.5 + CGFloat(seed)) * 0.18)
            let len = 30 + aqRand(k, seed) * 14
            let mid = CGPoint(x: p0.x + cos(a - 0.2) * len * 0.55, y: p0.y + sin(a - 0.2) * len * 0.55)
            let tip = CGPoint(x: p0.x + cos(a) * len, y: p0.y + sin(a) * len)
            arms.move(to: p0)
            arms.addQuadCurve(to: tip, control: mid)
            tips.addEllipse(in: CGRect(x: tip.x - 4, y: tip.y - 4, width: 8, height: 8))
        }
        g.stroke(arms, with: .color(StorybookArt.outline(for: armHex)), style: strokeStyle(8.5))
        g.stroke(arms, with: .color(StorybookArt.color(armHex)), style: strokeStyle(5.5))
        g.fill(tips, with: .color(StorybookArt.color(0xFFA6DC)))
    }

    static func grass(_ g: GraphicsContext, t: CGFloat, sway: CGFloat, seed: Int) {
        var dark = Path(), light = Path()
        for k in 0..<11 {
            let x0 = -48 + CGFloat(k) * 9.5
            let h = 70 + aqRand(k, seed + 5) * 50
            let lean = (aqRand(k, seed + 6) - 0.5) * 0.8
            let current = sin(t * 1.1 + CGFloat(k) * 0.7) * 0.2
            let b = (sway + current + lean) * h * 0.5
            var blade = Path()
            blade.move(to: CGPoint(x: x0 - 3, y: 0))
            blade.addQuadCurve(to: CGPoint(x: x0 + b, y: -h), control: CGPoint(x: x0 - 3 + b * 0.2, y: -h * 0.6))
            blade.addQuadCurve(to: CGPoint(x: x0 + 3, y: 0), control: CGPoint(x: x0 + 3 + b * 0.25, y: -h * 0.55))
            blade.closeSubpath()
            if k % 2 == 0 { dark.addPath(blade) } else { light.addPath(blade) }
        }
        g.fill(dark, with: .color(StorybookArt.color(0x45A85C)))
        g.fill(light, with: .color(StorybookArt.color(0x72CF78)))
        g.stroke(dark, with: .color(StorybookArt.outline(for: 0x45A85C).opacity(0.6)), style: strokeStyle(1.3))
        g.stroke(light, with: .color(StorybookArt.outline(for: 0x72CF78).opacity(0.55)), style: strokeStyle(1.3))
    }

    static func shell(_ g: GraphicsContext) {
        let shellHex: UInt32 = 0xFFC2AB
        var fan = Path()
        fan.move(to: CGPoint(x: -6, y: -4))
        fan.addCurve(to: CGPoint(x: 0, y: -42), control1: CGPoint(x: -35, y: -10), control2: CGPoint(x: -30, y: -42))
        fan.addCurve(to: CGPoint(x: 6, y: -4), control1: CGPoint(x: 30, y: -42), control2: CGPoint(x: 35, y: -10))
        fan.closeSubpath()
        shaded(g, fan, hex: shellHex, top: -42, bottom: -4, line: 2.4)
        var ridges = Path()
        for k in 0..<7 {
            let a = -CGFloat.pi / 2 + (CGFloat(k) - 3) * 0.31
            ridges.move(to: CGPoint(x: 0, y: -6))
            ridges.addLine(to: CGPoint(x: cos(a) * 33, y: -6 + sin(a) * 33))
        }
        g.stroke(ridges, with: .color(StorybookArt.outline(for: shellHex).opacity(0.5)), style: strokeStyle(1.5))
        let hinge = Path(roundedRect: CGRect(x: -11, y: -10, width: 22, height: 10), cornerRadius: 5)
        shaded(g, hinge, hex: 0xF2AD94, top: -10, bottom: 0, line: 2.0)
        StorybookArt.highlight(g, in: CGRect(x: -12, y: -34, width: 12, height: 6), opacity: 0.45)
    }

    static func starfish(_ g: GraphicsContext) {
        let starHex: UInt32 = 0xFF9B5C
        var s = g
        s.translateBy(x: 0, y: -14)
        s.scaleBy(x: 1, y: 0.62)

        // Plump storybook starfish built from smooth rounded arms instead of sharp polygon points.
        var pts: [CGPoint] = []
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let r: CGFloat = k % 2 == 0 ? 31 : 13
            pts.append(CGPoint(x: cos(a) * r, y: sin(a) * r))
        }
        let star = AquaShape.smoothClosed(pts)
        s.fill(
            star,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.tint(for: starHex, amount: 0.32), StorybookArt.color(starHex), StorybookArt.shade(for: starHex, factor: 0.86)]),
                center: CGPoint(x: -4, y: -5),
                startRadius: 2,
                endRadius: 32
            )
        )
        s.stroke(star, with: .color(StorybookArt.outline(for: starHex)), style: strokeStyle(3.0))

        var dots = Path()
        for k in 0..<5 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi * 2 / 5
            for r in [9, 17] as [CGFloat] {
                dots.addEllipse(in: CGRect(x: cos(a) * r - 2.2, y: sin(a) * r - 2.2, width: 4.4, height: 4.4))
            }
        }
        s.fill(dots, with: .color(StorybookArt.color(0xFFF0C8, alpha: 0.9)))
        StorybookArt.highlight(s, in: CGRect(x: -8, y: -9, width: 10, height: 6), opacity: 0.4)
    }

    static func koiBridge(_ g: GraphicsContext, t: CGFloat = 0) {
        let redHex: UInt32 = 0xEE5C6E
        let darkRedHex: UInt32 = 0xD64258
        let goldHex: UInt32 = 0xFFD45A
        let stoneHex: UInt32 = 0xB8C5D4
        let redOutline = StorybookArt.outline(for: redHex, factor: 0.56)
        let goldOutline = StorybookArt.outline(for: goldHex, factor: 0.62)

        // Subtle luminous water glow & decorative gently rising arch bubbles
        g.fill(
            Path(ellipseIn: CGRect(x: -44, y: -44, width: 88, height: 42)),
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xA6F2FF, alpha: 0.42), StorybookArt.color(0xA6F2FF, alpha: 0)]),
                center: CGPoint(x: 0, y: -22),
                startRadius: 4,
                endRadius: 44
            )
        )
        for k in 0..<4 {
            let phase = (t * 0.45 + CGFloat(k) * 0.27).truncatingRemainder(dividingBy: 1)
            let bx = -20 + CGFloat(k) * 13 + sin(t * 2.2 + CGFloat(k) * 1.6) * 4
            let by = -6 - phase * 40
            let br: CGFloat = k.isMultiple(of: 2) ? 4.0 : 2.8
            let alpha = Double(sin(phase * .pi)) * 0.85
            if alpha > 0.05 {
                let b = Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2))
                g.fill(b, with: .color(StorybookArt.color(0xD8F8FF, alpha: 0.48 * alpha)))
                g.stroke(b, with: .color(.white.opacity(0.9 * alpha)), lineWidth: 1.4)
            }
        }

        // Mossy riverbank stone abutments on both sides of the arch
        for side in [-1.0, 1.0] as [CGFloat] {
            let rockRect = CGRect(x: side > 0 ? 44 : -80, y: -24, width: 36, height: 24)
            shaded(g, Path(roundedRect: rockRect, cornerRadius: 11), hex: stoneHex, top: -24, bottom: 0, line: 2.2)
            let pebble = Path(ellipseIn: CGRect(x: side > 0 ? 58 : -78, y: -14, width: 20, height: 14))
            shaded(g, pebble, hex: 0xCAD6E2, top: -14, bottom: 0, line: 1.8)
        }

        // Curved bridge arch deck (open semicircular archway underneath)
        var deck = Path()
        deck.move(to: CGPoint(x: -76, y: -12))
        deck.addQuadCurve(to: CGPoint(x: 76, y: -12), control: CGPoint(x: 0, y: -74))
        deck.addLine(to: CGPoint(x: 64, y: 0))
        deck.addQuadCurve(to: CGPoint(x: -64, y: 0), control: CGPoint(x: 0, y: -56))
        deck.closeSubpath()
        shaded(g, deck, hex: darkRedHex, top: -48, bottom: 0, line: 2.6)

        // Golden arch trim hugging the inner curve & top deck edge
        var innerGold = Path()
        innerGold.move(to: CGPoint(x: -62, y: -2))
        innerGold.addQuadCurve(to: CGPoint(x: 62, y: -2), control: CGPoint(x: 0, y: -54))
        g.stroke(innerGold, with: .color(goldOutline), style: StrokeStyle(lineWidth: 6.2, lineCap: .round))
        g.stroke(innerGold, with: .color(StorybookArt.color(goldHex)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))

        // Helper for point along the bridge deck top curve (-1...1)
        func deckY(_ u: CGFloat) -> CGFloat {
            // Quadratic Bezier P0=(-76,-12), C=(0,-74), P2=(76,-12) evaluated at t=(u+1)/2
            let s = (u + 1) * 0.5
            let inv = 1 - s
            return inv * inv * (-12) + 2 * inv * s * (-74) + s * s * (-12)
        }

        // Back railing balusters & golden horizontal mid-bar
        for k in 0..<7 {
            let u = -0.82 + CGFloat(k) * (1.64 / 6)
            let x = u * 76
            let y0 = deckY(u)
            var post = Path()
            post.move(to: CGPoint(x: x, y: y0 + 2))
            post.addLine(to: CGPoint(x: x, y: y0 - 24))
            g.stroke(post, with: .color(redOutline), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            g.stroke(post, with: .color(StorybookArt.color(redHex)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }

        var midBar = Path()
        midBar.move(to: CGPoint(x: -72, y: -26))
        midBar.addQuadCurve(to: CGPoint(x: 72, y: -26), control: CGPoint(x: 0, y: -88))
        g.stroke(midBar, with: .color(goldOutline), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        g.stroke(midBar, with: .color(StorybookArt.color(goldHex)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        // Top sweeping crimson handrail
        var topRail = Path()
        topRail.move(to: CGPoint(x: -76, y: -38))
        topRail.addQuadCurve(to: CGPoint(x: 76, y: -38), control: CGPoint(x: 0, y: -102))
        g.stroke(topRail, with: .color(redOutline), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        g.stroke(topRail, with: .color(StorybookArt.color(redHex)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        g.stroke(topRail.offsetBy(dx: 0, dy: -1.5), with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // 4 chunky bridge posts crowned with gleaming golden giboshi finials
        for u in [-0.96, -0.34, 0.34, 0.96] as [CGFloat] {
            let x = u * 76
            let yBase = deckY(u)
            let yTop = yBase - 30
            let pillar = Path(roundedRect: CGRect(x: x - 4.5, y: yTop, width: 9, height: 32), cornerRadius: 3.5)
            shaded(g, pillar, hex: redHex, top: yTop, bottom: yBase + 2, line: 2.0)

            // Golden collar & lotus-bud cap
            let collar = Path(roundedRect: CGRect(x: x - 6.5, y: yTop - 4, width: 13, height: 5.5), cornerRadius: 2.5)
            StorybookArt.fillAndStroke(g, collar, fill: StorybookArt.color(goldHex), stroke: goldOutline, width: 1.8)
            var finial = Path()
            finial.move(to: CGPoint(x: x - 5.5, y: yTop - 4))
            finial.addQuadCurve(to: CGPoint(x: x, y: yTop - 15), control: CGPoint(x: x - 7, y: yTop - 11))
            finial.addQuadCurve(to: CGPoint(x: x + 5.5, y: yTop - 4), control: CGPoint(x: x + 7, y: yTop - 11))
            finial.closeSubpath()
            StorybookArt.fillAndStroke(g, finial, fill: StorybookArt.color(0xFFE484), stroke: goldOutline, width: 1.8)
            StorybookArt.highlight(g, in: CGRect(x: x - 2.5, y: yTop - 11, width: 2.5, height: 3.5), opacity: 0.8)
        }

        moss(g, width: 146, seed: 31)
    }

    // MARK: - Tools

    static func shaker(_ g: GraphicsContext, mode: AquaTreatMode = .flakes) {
        let isPearls = mode == .pearls
        let jarHex: UInt32 = isPearls ? 0xECEBFF : 0xFFF2DE
        let capHex: UInt32 = isPearls ? 0xB898FF : 0xFF88B0
        let jar = Path(roundedRect: CGRect(x: -24, y: 8, width: 48, height: 82), cornerRadius: 14)
        g.fill(jar, with: .linearGradient(Gradient(colors: [StorybookArt.color(isPearls ? 0xF8F6FF : 0xFFF9EE, alpha: 0.96), StorybookArt.color(jarHex, alpha: 0.96)]),
                                          startPoint: CGPoint(x: -24, y: 0), endPoint: CGPoint(x: 24, y: 0)))
        if isPearls {
            var pearlsA = Path(), pearlsB = Path(), glints = Path()
            for k in 0..<14 {
                let x = -15 + aqRand(k, 51) * 30, y = 46 + aqRand(k, 52) * 36
                let r: CGFloat = 3.6 + aqRand(k, 53) * 1.4
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                if k % 2 == 0 { pearlsA.addEllipse(in: rect) } else { pearlsB.addEllipse(in: rect) }
                glints.addEllipse(in: CGRect(x: x - r * 0.45, y: y - r * 0.5, width: r * 0.65, height: r * 0.5))
            }
            g.fill(pearlsA, with: .color(StorybookArt.color(0xFFF3B8)))
            g.fill(pearlsB, with: .color(StorybookArt.color(0xFFD6F5)))
            g.fill(glints, with: .color(.white.opacity(0.9)))
        } else {
            var flakes: [Path] = [Path(), Path(), Path()]
            for k in 0..<18 {
                let x = -17 + aqRand(k, 41) * 34, y = 42 + aqRand(k, 42) * 42
                flakes[k % 3].addRoundedRect(in: CGRect(x: x, y: y, width: 5, height: 3.5), cornerSize: CGSize(width: 1.5, height: 1.5))
            }
            g.fill(flakes[0], with: .color(StorybookArt.color(0xFF7452)))
            g.fill(flakes[1], with: .color(StorybookArt.color(0xFFD052)))
            g.fill(flakes[2], with: .color(StorybookArt.color(0x74CA64)))
        }

        let label = Path(roundedRect: CGRect(x: -23, y: 20, width: 46, height: 24), cornerRadius: 6)
        g.fill(label, with: .color(StorybookArt.color(isPearls ? 0x6F7EE8 : 0x78CCF5)))
        if isPearls {
            let orb = AquaShape.circle(CGPoint(x: 0, y: 32), 7.5)
            StorybookArt.fillAndStroke(g, orb, fill: StorybookArt.color(0xFFF6D4), stroke: StorybookArt.color(0xD8B4FF), width: 1.6)
            g.fill(AquaShape.circle(CGPoint(x: -2.2, y: 29.8), 2.2), with: .color(.white))
            StorybookArt.sparkle(g, at: CGPoint(x: 11, y: 26), radius: 4.5, color: Theme.lemon, opacity: 1)
        } else {
            // Lightweight stylized orange fish silhouette on the jar label (avoids per-frame AquaBody draw at 60 FPS).
            var tail = Path()
            tail.move(to: CGPoint(x: -6, y: 32))
            tail.addLine(to: CGPoint(x: -15, y: 26))
            tail.addQuadCurve(to: CGPoint(x: -12, y: 32), control: CGPoint(x: -13, y: 29))
            tail.addQuadCurve(to: CGPoint(x: -15, y: 38), control: CGPoint(x: -13, y: 35))
            tail.closeSubpath()
            g.fill(tail, with: .color(StorybookArt.color(0xFFA048)))
            let body = Path(ellipseIn: CGRect(x: -9, y: 25, width: 23, height: 14))
            StorybookArt.shape(g, body, hex: 0xFF8A2B, width: 1.4)
            g.fill(AquaShape.circle(CGPoint(x: 8.5, y: 30.5), 2.3), with: .color(.white))
            g.fill(AquaShape.circle(CGPoint(x: 9.1, y: 30.5), 1.3), with: .color(StorybookArt.color(0x2A2238)))
        }

        g.stroke(jar, with: .color(StorybookArt.outline(for: isPearls ? 0x9C92D8 : 0xD4AE88)), style: strokeStyle(2.6))
        StorybookArt.highlight(g, in: CGRect(x: 11, y: 48, width: 6, height: 30), opacity: 0.55)

        let cap = Path(roundedRect: CGRect(x: -22, y: -7, width: 44, height: 17), cornerRadius: 7)
        shaded(g, cap, hex: capHex, top: -7, bottom: 10, line: 2.2)
        var holes = Path()
        for k in 0..<5 { holes.addEllipse(in: CGRect(x: -14 + CGFloat(k) * 6.5, y: -3.5, width: 3.2, height: 3.2)) }
        g.fill(holes, with: .color(StorybookArt.outline(for: capHex)))
    }

    /// Chunky storybook magnetic tank wiper with plush felt scrubber base and cream grip handle.
    static func wiper(_ g: GraphicsContext) {
        let bodyHex: UInt32 = 0x5DC7D8
        let feltHex: UInt32 = 0x7CE0B0
        let gripHex: UInt32 = 0xFFF7F2

        let felt = Path(roundedRect: CGRect(x: -40, y: 8, width: 80, height: 17), cornerRadius: 8)
        shaded(g, felt, hex: feltHex, top: 8, bottom: 25, line: 2.4)

        let block = Path(roundedRect: CGRect(x: -40, y: -18, width: 80, height: 32), cornerRadius: 13)
        shaded(g, block, hex: bodyHex, top: -18, bottom: 14, line: 2.8)

        let grip = Path(roundedRect: CGRect(x: -22, y: -28, width: 44, height: 16), cornerRadius: 8)
        StorybookArt.fillAndStroke(g, grip, fill: StorybookArt.color(gripHex), stroke: StorybookArt.outline(for: bodyHex), width: 2.4)

        StorybookArt.highlight(g, in: CGRect(x: -30, y: -13, width: 26, height: 6), opacity: 0.5)
        StorybookArt.sparkle(g, at: CGPoint(x: 24, y: -6), radius: 7, color: Theme.lemon, opacity: 0.95)
    }

    /// Shimmering iridescent bubble hoop toy shown on the dock and while carried.
    static func hoopIcon(_ g: GraphicsContext, time t: CGFloat) {
        let pulse = 1 + 0.05 * sin(t * 3.2)
        let r: CGFloat = 26 * pulse
        let ring = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        g.fill(ring, with: .radialGradient(Gradient(colors: [StorybookArt.color(0xA6F2FF, alpha: 0.08), StorybookArt.color(0xC9B6FF, alpha: 0.25)]),
                                           center: .zero, startRadius: r * 0.5, endRadius: r))
        g.stroke(ring, with: .color(StorybookArt.color(0x69D2F0, alpha: 0.7)), style: strokeStyle(9.5))
        g.stroke(ring, with: .linearGradient(Gradient(colors: [StorybookArt.color(0xA8F6FF), StorybookArt.color(0xFFD6F2), StorybookArt.color(0xFFF1A8), StorybookArt.color(0x9CE8FF)]),
                                             startPoint: CGPoint(x: -r, y: -r), endPoint: CGPoint(x: r, y: r)),
                 style: strokeStyle(5.5))
        var arc = Path()
        arc.addArc(center: .zero, radius: r, startAngle: .degrees(205), endAngle: .degrees(265), clockwise: false)
        g.stroke(arc, with: .color(.white.opacity(0.9)), style: strokeStyle(2.8))

        for (bx, by, br) in [(-22.0, -18.0, 5.5), (24.0, -10.0, 4.5), (-18.0, 22.0, 4.0)] as [(CGFloat, CGFloat, CGFloat)] {
            let b = AquaShape.circle(CGPoint(x: bx, y: by), br)
            g.fill(b, with: .color(.white.opacity(0.35)))
            g.stroke(b, with: .color(.white.opacity(0.9)), style: strokeStyle(1.6))
        }
        StorybookArt.sparkle(g, at: CGPoint(x: 18, y: -22), radius: 8, color: Theme.lemon, opacity: 1)
    }

    /// Back half of an underwater drifting bubble hoop, drawn behind fish so fish visibly swim straight through it.
    static func hoopBack(_ g: GraphicsContext, radius r: CGFloat, shimmer: CGFloat, time t: CGFloat) {
        let rx = r * 0.42
        let ry = r
        let glowR = r * (1.28 + shimmer * 0.22)
        g.fill(
            Path(ellipseIn: CGRect(x: -rx * 1.9, y: -glowR, width: rx * 3.8, height: glowR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    StorybookArt.color(0xB4F6FF, alpha: Double(0.22 + shimmer * 0.34)),
                    StorybookArt.color(0xFFE6FA, alpha: Double(0.08 + shimmer * 0.14)),
                    .clear,
                ]),
                center: .zero,
                startRadius: 6,
                endRadius: glowR
            )
        )

        var backArc = Path()
        var first = true
        for k in 0...20 {
            let a = -CGFloat.pi / 2 - CGFloat(k) / 20 * .pi
            let pt = CGPoint(x: cos(a) * rx, y: sin(a) * ry)
            if first { backArc.move(to: pt); first = false } else { backArc.addLine(to: pt) }
        }
        g.stroke(backArc, with: .color(StorybookArt.color(0x52BFE6, alpha: 0.55)), style: strokeStyle(11))
        g.stroke(backArc, with: .color(StorybookArt.color(0xD8F6FF, alpha: 0.72)), style: strokeStyle(6))

        for k in 0..<4 {
            let a = -CGFloat.pi / 2 - (CGFloat(k) + 0.5) / 4 * .pi + sin(t * 1.5 + CGFloat(k)) * 0.08
            let pt = CGPoint(x: cos(a) * rx, y: sin(a) * ry)
            let b = AquaShape.circle(pt, 4.2 + shimmer * 1.5)
            g.fill(b, with: .color(.white.opacity(0.45)))
            g.stroke(b, with: .color(.white.opacity(0.8)), style: strokeStyle(1.2))
        }
    }

    /// Front half of an underwater drifting bubble hoop, drawn over fish as they pass through the ring.
    static func hoopFront(_ g: GraphicsContext, radius r: CGFloat, shimmer: CGFloat, time t: CGFloat) {
        let rx = r * 0.42
        let ry = r
        var frontArc = Path()
        var first = true
        for k in 0...20 {
            let a = -CGFloat.pi / 2 + CGFloat(k) / 20 * .pi
            let pt = CGPoint(x: cos(a) * rx, y: sin(a) * ry)
            if first { frontArc.move(to: pt); first = false } else { frontArc.addLine(to: pt) }
        }
        let haloW: CGFloat = 12 + shimmer * 4
        g.stroke(frontArc, with: .color(StorybookArt.color(0x6AD8F5, alpha: 0.65 + Double(shimmer) * 0.25)), style: strokeStyle(haloW))
        g.stroke(
            frontArc,
            with: .linearGradient(
                Gradient(colors: [
                    StorybookArt.color(0xC2FAFF),
                    StorybookArt.color(0xFFE0F6),
                    StorybookArt.color(0xFFF3A8),
                    StorybookArt.color(0xA4F0FF),
                ]),
                startPoint: CGPoint(x: 0, y: -ry),
                endPoint: CGPoint(x: 0, y: ry)
            ),
            style: strokeStyle(6.5)
        )
        g.stroke(frontArc, with: .color(.white.opacity(0.85)), style: strokeStyle(2.2))

        for k in 0..<5 {
            let a = -CGFloat.pi / 2 + (CGFloat(k) + 0.5) / 5 * .pi + sin(t * 1.8 + CGFloat(k) * 1.3) * 0.08
            let pt = CGPoint(x: cos(a) * rx, y: sin(a) * ry)
            let br: CGFloat = (k % 2 == 0 ? 5.2 : 3.8) + shimmer * 2
            let b = AquaShape.circle(pt, br)
            g.fill(b, with: .color(.white.opacity(0.5)))
            g.stroke(b, with: .color(.white.opacity(0.95)), style: strokeStyle(1.4))
        }
        let sp = 6.5 + shimmer * 5 + sin(t * 5) * 1.5
        StorybookArt.sparkle(g, at: CGPoint(x: rx * 0.65, y: -ry * 0.72), radius: sp, color: Theme.lemon, opacity: 0.95)
        if shimmer > 0.05 {
            StorybookArt.sparkle(g, at: CGPoint(x: rx * 0.85, y: ry * 0.55), radius: 8 * shimmer, color: .white, opacity: Double(shimmer))
        }
    }

    static func netBack(_ g: GraphicsContext) {
        var pocket = Path()
        pocket.move(to: CGPoint(x: -34, y: 0))
        pocket.addQuadCurve(to: CGPoint(x: 34, y: 0), control: CGPoint(x: 0, y: 70))
        pocket.closeSubpath()
        g.fill(pocket, with: .color(.white.opacity(0.22)))
    }

    static func netFront(_ g: GraphicsContext) {
        var pocket = Path()
        pocket.move(to: CGPoint(x: -34, y: 0))
        pocket.addQuadCurve(to: CGPoint(x: 34, y: 0), control: CGPoint(x: 0, y: 70))
        var mesh = Path()
        for k in 1..<6 {
            let f = CGFloat(k) / 6
            let x = -34 + 68 * f
            mesh.move(to: CGPoint(x: x, y: 0))
            mesh.addQuadCurve(to: CGPoint(x: x * 0.3, y: 30 + 4 * (1 - abs(f * 2 - 1))), control: CGPoint(x: x * 0.95, y: 26))
        }
        for k in 1..<4 {
            let y = CGFloat(k) * 8
            let w = 34 * (1 - pow(CGFloat(k) / 4.4, 2))
            mesh.move(to: CGPoint(x: -w, y: y))
            mesh.addQuadCurve(to: CGPoint(x: w, y: y), control: CGPoint(x: 0, y: y + 6))
        }
        g.stroke(mesh, with: .color(.white.opacity(0.7)), style: strokeStyle(1.1))
        g.stroke(pocket, with: .color(.white.opacity(0.85)), style: strokeStyle(1.4))

        var handle = Path()
        handle.move(to: CGPoint(x: 0, y: 12))
        handle.addLine(to: CGPoint(x: 0, y: 148))
        g.stroke(handle, with: .color(StorybookArt.outline(for: 0x52C9A6)), style: strokeStyle(10))
        g.stroke(handle, with: .color(StorybookArt.color(0x63D6B4)), style: strokeStyle(6.5))

        let grip = Path(roundedRect: CGRect(x: -8, y: 110, width: 16, height: 44), cornerRadius: 8)
        shaded(g, grip, hex: 0xFF94BE, top: 110, bottom: 154, line: 2.0)

        let hoop = Path(ellipseIn: CGRect(x: -36, y: -12, width: 72, height: 24))
        g.stroke(hoop, with: .color(StorybookArt.outline(for: 0x52C9A6)), style: strokeStyle(7))
        g.stroke(hoop, with: .color(StorybookArt.color(0x7CE8C8)), style: strokeStyle(3.5))
    }

    static func bag(_ g: GraphicsContext, kind: FishKind, time t: CGFloat) {
        var bag = Path()
        bag.move(to: CGPoint(x: -6, y: -46))
        bag.addQuadCurve(to: CGPoint(x: -38, y: 18), control: CGPoint(x: -40, y: -20))
        bag.addQuadCurve(to: CGPoint(x: 38, y: 18), control: CGPoint(x: 0, y: 52))
        bag.addQuadCurve(to: CGPoint(x: 6, y: -46), control: CGPoint(x: 40, y: -20))
        bag.closeSubpath()
        var water = Path()
        water.move(to: CGPoint(x: -34, y: -8 + sin(t * 3) * 1.5))
        water.addQuadCurve(to: CGPoint(x: 34, y: -8 - sin(t * 3) * 1.5), control: CGPoint(x: 0, y: -4))
        water.addLine(to: CGPoint(x: 37, y: 16))
        water.addQuadCurve(to: CGPoint(x: -37, y: 16), control: CGPoint(x: 0, y: 48))
        water.closeSubpath()
        g.fill(bag, with: .color(.white.opacity(0.38)))
        g.fill(water, with: .linearGradient(Gradient(colors: [StorybookArt.color(0x9FE6F8, alpha: 0.78), StorybookArt.color(0x52B6E0, alpha: 0.78)]),
                                            startPoint: CGPoint(x: 0, y: -8), endPoint: CGPoint(x: 0, y: 34)))
        let n = min(3, kind.group)
        let sc: CGFloat = kind.length > 50 ? 0.5 : (kind == .seahorse ? 0.45 : 0.8)
        for k in 0..<n {
            var one = g
            one.translateBy(x: CGFloat(k - (n - 1) / 2) * 16 + sin(t * 1.5 + CGFloat(k)) * 4, y: 12 + CGFloat(k % 2) * 8)
            one.scaleBy(x: (k % 2 == 0 ? 1 : -1) * sc, y: sc)
            AquaFishPainter.drawLocal(one, kind: kind, variant: 0, phase: t * 9 + CGFloat(k), amp: 0.3, gulp: 0, puff: 0, time: t)
        }
        g.stroke(bag, with: .color(.white.opacity(0.92)), style: strokeStyle(2.2))
        StorybookArt.highlight(g, in: CGRect(x: 17, y: -16, width: 6, height: 26), opacity: 0.65)
        let ribbon = Path(ellipseIn: CGRect(x: -10, y: -55, width: 20, height: 13))
        StorybookArt.shape(g, ribbon, hex: 0xFF94BE, width: 1.8)
    }

    static func catalogIcon(_ g: GraphicsContext, time t: CGFloat) {
        var reef = g
        reef.translateBy(x: 14, y: 24)
        reef.scaleBy(x: 0.38, y: 0.38)
        coral(reef)

        var fishCtx = g
        fishCtx.translateBy(x: -6, y: -4)
        fishCtx.scaleBy(x: 0.52, y: 0.52)
        AquaFishPainter.drawLocal(fishCtx, kind: .clownfish, variant: 0, phase: t * 4, amp: 0.18, gulp: 0, puff: 0, time: t)

        var sh = g
        sh.translateBy(x: -14, y: 26)
        sh.scaleBy(x: 0.48, y: 0.48)
        shell(sh)
    }

    // MARK: - Mystery Reef Egg, Singing Clams, Yellow Glass Submarine & Treat Toggle

    static func egg(
        _ g: GraphicsContext,
        palette: AquaEggPalette,
        taps: Int,
        time t: CGFloat,
        species: FishKind? = nil
    ) {
        let pattern = species.map { AquaEggPattern.forSpecies($0) }
        let baseHex: UInt32
        let spotHex: UInt32
        let accentHex: UInt32
        if let pat = pattern {
            baseHex = pat.shellHex
            spotHex = pat.markHex
            accentHex = pat.accentHex
        } else {
            switch palette {
            case .pinkSpeckle:
                baseHex = 0xFFD4E6
                spotHex = 0xFF8AB8
                accentHex = 0xFFF3A8
            case .mintSwirl:
                baseHex = 0xC9F7E8
                spotHex = 0x6FD4B8
                accentHex = 0xFFE39E
            case .lilacStar:
                baseHex = 0xDFD0FF
                spotHex = 0xA488F2
                accentHex = 0xFFF0A6
            }
        }

        let glowAlpha = 0.24 + 0.14 * Double(sin(t * 2.8)) + Double(taps) * 0.12
        g.fill(
            Path(ellipseIn: CGRect(x: -24, y: -10, width: 48, height: 16)),
            with: .color(StorybookArt.color(accentHex, alpha: min(0.55, glowAlpha)))
        )

        var shellPath = Path()
        shellPath.move(to: CGPoint(x: 0, y: -44))
        shellPath.addCurve(to: CGPoint(x: 19, y: -14), control1: CGPoint(x: 14, y: -44), control2: CGPoint(x: 21, y: -28))
        shellPath.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: 17, y: -2), control2: CGPoint(x: 9, y: 0))
        shellPath.addCurve(to: CGPoint(x: -19, y: -14), control1: CGPoint(x: -9, y: 0), control2: CGPoint(x: -17, y: -2))
        shellPath.addCurve(to: CGPoint(x: 0, y: -44), control1: CGPoint(x: -21, y: -28), control2: CGPoint(x: -14, y: -44))
        shellPath.closeSubpath()

        shaded(g, shellPath, hex: baseHex, top: -44, bottom: 0, line: 2.5)

        var clipped = g
        clipped.clip(to: shellPath)
        if let pat = pattern {
            drawEggPattern(clipped, pat)
        } else {
            let dots: [(CGFloat, CGFloat, CGFloat)] = [
                (-8, -28, 3.4), (7, -30, 2.8), (-10, -14, 3.8),
                (6, -16, 4.2), (0, -22, 3.0), (10, -8, 2.5), (-3, -8, 2.6),
            ]
            var spotPath = Path()
            for (dx, dy, r) in dots {
                spotPath.addEllipse(in: CGRect(x: dx - r, y: dy - r, width: r * 2, height: r * 2))
            }
            clipped.fill(spotPath, with: .color(StorybookArt.color(spotHex, alpha: 0.72)))
        }
        g.stroke(shellPath, with: .color(StorybookArt.outline(for: baseHex, factor: 0.58)), style: strokeStyle(2.5))
        StorybookArt.highlight(g, in: CGRect(x: -10, y: -36, width: 7, height: 13), opacity: 0.58)

        if taps >= 1 {
            var crack = Path()
            crack.move(to: CGPoint(x: -9, y: -25))
            crack.addLine(to: CGPoint(x: -2, y: -21))
            crack.addLine(to: CGPoint(x: 3, y: -26))
            crack.addLine(to: CGPoint(x: 9, y: -20))
            if taps >= 2 {
                crack.move(to: CGPoint(x: -2, y: -21))
                crack.addLine(to: CGPoint(x: -6, y: -14))
                crack.addLine(to: CGPoint(x: 1, y: -11))
                crack.move(to: CGPoint(x: 3, y: -26))
                crack.addLine(to: CGPoint(x: 7, y: -32))
                g.stroke(crack, with: .color(StorybookArt.color(0xFFF6B0, alpha: 0.95)), style: strokeStyle(4.6))
            }
            g.stroke(crack, with: .color(StorybookArt.outline(for: baseHex, factor: 0.45)), style: strokeStyle(2.2))
        }

        let sp = 4.2 + 2.0 * sin(t * 4.2) + CGFloat(taps) * 1.4
        StorybookArt.sparkle(g, at: CGPoint(x: 14, y: -38), radius: sp, color: Theme.lemon, opacity: 0.95)
    }

    private static func drawEggPattern(_ g: GraphicsContext, _ pattern: AquaEggPattern) {
        let mark = StorybookArt.color(pattern.markHex)
        let accent = StorybookArt.color(pattern.accentHex)
        switch pattern {
        case .axolotlFrills:
            for side in [-1.0, 1.0] as [CGFloat] {
                for k in 0..<3 {
                    let y = -30 + CGFloat(k) * 7
                    let x = side * (11 + CGFloat(k == 1 ? 2 : 0))
                    g.fill(AquaShape.circle(CGPoint(x: x, y: y), 3.3), with: .color(mark.opacity(0.85)))
                }
            }
            for (dx, dy, r) in [(-4.0, -14.0, 2.5), (5.0, -18.0, 2.3), (0.0, -9.0, 2.2)] as [(CGFloat, CGFloat, CGFloat)] {
                g.fill(AquaShape.circle(CGPoint(x: dx, y: dy), r), with: .color(mark.opacity(0.6)))
            }
        case .seaBunnyDots:
            for side in [-1.0, 1.0] as [CGFloat] {
                let ear = Path(ellipseIn: CGRect(x: side * 6 - 3, y: -39, width: 6, height: 11))
                g.fill(ear, with: .color(mark.opacity(0.85)))
            }
            for (dx, dy, r) in [(-9.0, -21.0, 2.8), (2.0, -24.0, 2.4), (10.0, -17.0, 3.0), (-4.0, -10.0, 2.6), (6.0, -9.0, 2.4)] as [(CGFloat, CGFloat, CGFloat)] {
                g.fill(AquaShape.circle(CGPoint(x: dx, y: dy), r), with: .color(mark.opacity(0.82)))
            }
        case .narwhalSwirl:
            var swirl = Path()
            swirl.move(to: CGPoint(x: -14, y: -8))
            swirl.addCurve(to: CGPoint(x: 13, y: -22), control1: CGPoint(x: -4, y: -12), control2: CGPoint(x: 4, y: -24))
            swirl.move(to: CGPoint(x: -11, y: -22))
            swirl.addCurve(to: CGPoint(x: 9, y: -35), control1: CGPoint(x: -2, y: -25), control2: CGPoint(x: 3, y: -34))
            g.stroke(swirl, with: .color(mark.opacity(0.9)), style: strokeStyle(4.2))
            StorybookArt.sparkle(g, at: CGPoint(x: -4, y: -31), radius: 4.0, color: .white, opacity: 0.92)
            StorybookArt.sparkle(g, at: CGPoint(x: 6, y: -13), radius: 3.6, color: accent, opacity: 0.92)
        case .clownStripes:
            for y in [-29.0, -13.0] as [CGFloat] {
                let stripe = Path(CGRect(x: -22, y: y, width: 44, height: 7.5))
                g.fill(stripe, with: .color(mark.opacity(0.95)))
                g.stroke(stripe, with: .color(accent.opacity(0.75)), lineWidth: 1.5)
            }
        case .pufferPolka:
            for (dx, dy, r) in [(-9.0, -28.0, 3.6), (8.0, -27.0, 3.2), (0.0, -21.0, 4.0), (-11.0, -13.0, 3.8), (7.0, -12.0, 3.6), (-1.0, -6.0, 3.0)] as [(CGFloat, CGFloat, CGFloat)] {
                g.fill(AquaShape.circle(CGPoint(x: dx, y: dy), r), with: .color(mark.opacity(0.72)))
            }
        case .seahorseRings:
            var rings = Path()
            for k in 0..<4 {
                let y = -33 + CGFloat(k) * 8.5
                rings.move(to: CGPoint(x: -20, y: y))
                rings.addQuadCurve(to: CGPoint(x: 20, y: y), control: CGPoint(x: 0, y: y + 5))
            }
            g.stroke(rings, with: .color(mark.opacity(0.78)), style: strokeStyle(2.6))
        case .bettaVeil:
            var waveA = Path()
            waveA.move(to: CGPoint(x: -20, y: -16))
            waveA.addCurve(to: CGPoint(x: 20, y: -24), control1: CGPoint(x: -6, y: -32), control2: CGPoint(x: 6, y: -8))
            var waveB = Path()
            waveB.move(to: CGPoint(x: -20, y: -8))
            waveB.addCurve(to: CGPoint(x: 20, y: -14), control1: CGPoint(x: -5, y: -20), control2: CGPoint(x: 8, y: -2))
            g.stroke(waveA, with: .color(mark.opacity(0.8)), style: strokeStyle(4.2))
            g.stroke(waveB, with: .color(accent.opacity(0.75)), style: strokeStyle(3.4))
        case .goldfishScales:
            var scales = Path()
            for row in 0..<3 {
                let y = -30 + CGFloat(row) * 9.5
                for col in -1...1 {
                    let x = CGFloat(col) * 10 + (row % 2 == 1 ? 5 : 0)
                    scales.move(to: CGPoint(x: x - 4.5, y: y))
                    scales.addQuadCurve(to: CGPoint(x: x + 4.5, y: y), control: CGPoint(x: x, y: y + 5.5))
                }
            }
            g.stroke(scales, with: .color(mark.opacity(0.78)), style: strokeStyle(2.2))
        case .angelBands:
            for x in [-10.0, 0.0, 10.0] as [CGFloat] {
                let band = Path(CGRect(x: x - 2.3, y: -44, width: 4.6, height: 44))
                g.fill(band, with: .color(mark.opacity(0.5)))
            }
            g.fill(Path(ellipseIn: CGRect(x: -10, y: -44, width: 20, height: 14)), with: .color(accent.opacity(0.55)))
        case .tetraNeon:
            var neonTop = Path()
            neonTop.move(to: CGPoint(x: -20, y: -16))
            neonTop.addLine(to: CGPoint(x: 20, y: -30))
            var neonBot = Path()
            neonBot.move(to: CGPoint(x: -18, y: -8))
            neonBot.addLine(to: CGPoint(x: 18, y: -20))
            g.stroke(neonTop, with: .color(mark.opacity(0.92)), style: strokeStyle(4.6))
            g.stroke(neonBot, with: .color(accent.opacity(0.88)), style: strokeStyle(4.0))
        case .guppyConfetti:
            let confetti: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
                (-9, -29, 3.2, 0xFF7FA8), (7, -28, 3.0, 0x46A6FF), (0, -21, 3.5, 0xFFE066),
                (-10, -14, 3.4, 0x46A6FF), (9, -15, 3.2, 0xFF8A3D), (-2, -8, 3.0, 0xFF7FA8),
            ]
            for (dx, dy, r, hex) in confetti {
                g.fill(AquaShape.circle(CGPoint(x: dx, y: dy), r), with: .color(StorybookArt.color(hex, alpha: 0.85)))
            }
        }
    }

    static func singingClam(_ g: GraphicsContext, shellHex: UInt32, open: CGFloat, bounce: CGFloat, time t: CGFloat) {
        var c = g
        let sq = bounce * 0.14
        c.scaleBy(x: 1 + sq * 0.6, y: 1 - sq)
        let outline = StorybookArt.outline(for: shellHex, factor: 0.56)

        // Bottom scalloped lip
        var bottom = Path()
        bottom.move(to: CGPoint(x: -22, y: -7))
        bottom.addQuadCurve(to: CGPoint(x: 22, y: -7), control: CGPoint(x: 0, y: 5))
        bottom.addQuadCurve(to: CGPoint(x: -22, y: -7), control: CGPoint(x: 0, y: -13))
        bottom.closeSubpath()
        shaded(c, bottom, hex: shellHex, top: -12, bottom: 2, line: 2.2)

        // Cozy dark mouth interior + smiling glossy pearl revealed when singing
        if open > 0.04 {
            let mouthH = 12 * open
            let cavity = Path(ellipseIn: CGRect(x: -16, y: -11 - mouthH * 0.6, width: 32, height: mouthH + 6))
            c.fill(cavity, with: .color(StorybookArt.color(0x6E3B6E, alpha: 0.9)))

            let pr: CGFloat = 7.2 * (0.65 + 0.35 * open)
            let py = -12 - mouthH * 0.35
            let pearlCircle = AquaShape.circle(CGPoint(x: 0, y: py), pr)
            c.fill(pearlCircle, with: .color(StorybookArt.color(0xFFF9EE)))
            c.stroke(pearlCircle, with: .color(StorybookArt.color(0xE8D2F0)), lineWidth: 1.4)
            c.fill(AquaShape.circle(CGPoint(x: -pr * 0.32, y: py - pr * 0.32), pr * 0.3), with: .color(.white))
            // Tiny joyful eyes & singing 'o' mouth on the pearl
            c.fill(AquaShape.circle(CGPoint(x: -2.4, y: py - 0.5), 1.1), with: .color(StorybookArt.color(0x3D264C)))
            c.fill(AquaShape.circle(CGPoint(x: 2.4, y: py - 0.5), 1.1), with: .color(StorybookArt.color(0x3D264C)))
            c.fill(AquaShape.circle(CGPoint(x: 0, y: py + 2.3), 1.6 * open), with: .color(StorybookArt.color(0xFF7FA8)))
        }

        // Hinged scalloped upper shell lid
        var lidG = c
        lidG.translateBy(x: 0, y: -9)
        lidG.scaleBy(x: 1, y: 1 - open * 0.25)
        lidG.translateBy(x: 0, y: -open * 11)
        var fan = Path()
        fan.move(to: CGPoint(x: -22, y: 1))
        fan.addCurve(to: CGPoint(x: 0, y: -23), control1: CGPoint(x: -25, y: -14), control2: CGPoint(x: -14, y: -24))
        fan.addCurve(to: CGPoint(x: 22, y: 1), control1: CGPoint(x: 14, y: -24), control2: CGPoint(x: 25, y: -14))
        fan.addQuadCurve(to: CGPoint(x: -22, y: 1), control: CGPoint(x: 0, y: 6))
        fan.closeSubpath()
        shaded(lidG, fan, hex: shellHex, top: -24, bottom: 4, line: 2.2)

        var ridges = Path()
        for k in -2...2 {
            let xTop = CGFloat(k) * 7.2
            ridges.move(to: CGPoint(x: CGFloat(k) * 2.5, y: 2))
            ridges.addLine(to: CGPoint(x: xTop, y: -17 + abs(CGFloat(k)) * 2.2))
        }
        lidG.stroke(ridges, with: .color(outline.opacity(0.45)), style: strokeStyle(1.4))
        StorybookArt.highlight(lidG, in: CGRect(x: -9, y: -18, width: 10, height: 4.5), opacity: 0.45)

        // Sleepy cute eyes on closed shell so kids know it's alive and tappable
        if open < 0.35 {
            var eyes = Path()
            for sx in [-6.5, 6.5] as [CGFloat] {
                eyes.move(to: CGPoint(x: sx - 2.6, y: -6))
                eyes.addQuadCurve(to: CGPoint(x: sx + 2.6, y: -6), control: CGPoint(x: sx, y: -8.5))
            }
            lidG.stroke(eyes, with: .color(outline.opacity(Double(1 - open * 2.8))), style: strokeStyle(1.6))
        }
    }

    static func submarine(
        _ g: GraphicsContext,
        propPhase: CGFloat,
        facing: CGFloat,
        beamAngle: CGFloat,
        night: CGFloat,
        time t: CGFloat,
        drawBeam: Bool = true
    ) {
        var c = g
        c.scaleBy(x: facing < 0 ? -1 : 1, y: 1)

        // Warm glowing spotlight cone projecting from the nose headlight
        if drawBeam {
            var beam = Path()
            let origin = CGPoint(x: 47, y: 4)
            let len: CGFloat = 175
            let spread: CGFloat = 0.36
            let a1 = beamAngle - spread
            let a2 = beamAngle + spread
            beam.move(to: origin)
            beam.addLine(to: CGPoint(x: origin.x + cos(a1) * len, y: origin.y + sin(a1) * len))
            beam.addLine(to: CGPoint(x: origin.x + cos(a2) * len, y: origin.y + sin(a2) * len))
            beam.closeSubpath()
            let strength = Double(0.28 + 0.36 * night)
            var bg = c
            if night > 0.15 { bg.blendMode = .plusLighter }
            bg.fill(
                beam,
                with: .linearGradient(
                    Gradient(colors: [
                        StorybookArt.color(0xFFF6B8, alpha: strength),
                        StorybookArt.color(0xFFE78C, alpha: strength * 0.42),
                        StorybookArt.color(0xFFE78C, alpha: 0),
                    ]),
                    startPoint: origin,
                    endPoint: CGPoint(x: origin.x + cos(beamAngle) * len, y: origin.y + sin(beamAngle) * len)
                )
            )
        }

        let hullHex: UInt32 = 0xFFD248
        let stripeHex: UInt32 = 0xFF7A5A
        let brassHex: UInt32 = 0xF0A838

        // Rotating rear propeller
        let shaft = Path(roundedRect: CGRect(x: -59, y: -4, width: 14, height: 8), cornerRadius: 3)
        shaded(c, shaft, hex: brassHex, top: -4, bottom: 4, line: 2.0)
        let bladeScale = max(0.22, abs(sin(propPhase)))
        let topBlade = Path(ellipseIn: CGRect(x: -64, y: -19 * bladeScale, width: 8, height: 19 * bladeScale))
        let botBlade = Path(ellipseIn: CGRect(x: -64, y: 0, width: 8, height: 19 * bladeScale))
        StorybookArt.shape(c, topBlade, hex: 0x72C8F0, width: 1.8)
        StorybookArt.shape(c, botBlade, hex: 0x72C8F0, width: 1.8)
        StorybookArt.shape(c, AquaShape.circle(CGPoint(x: -60, y: 0), 4), hex: stripeHex, width: 1.6)

        // Cute periscope peeking from behind glass dome
        var peri = Path()
        peri.move(to: CGPoint(x: -8, y: -26))
        peri.addLine(to: CGPoint(x: -8, y: -41))
        peri.addQuadCurve(to: CGPoint(x: 4, y: -41), control: CGPoint(x: -8, y: -47))
        c.stroke(peri, with: .color(StorybookArt.outline(for: brassHex)), style: strokeStyle(8.5))
        c.stroke(peri, with: .color(StorybookArt.color(hullHex)), style: strokeStyle(5.0))
        StorybookArt.shape(c, AquaShape.circle(CGPoint(x: 4, y: -41), 3.8), hex: 0xA6ECFF, width: 1.6)

        // Clear glass dome cockpit + cute tiny smiling starfish captain inside!
        let dome = Path(ellipseIn: CGRect(x: -20, y: -39, width: 42, height: 38))
        c.fill(
            dome,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xE8FAFF, alpha: 0.78), StorybookArt.color(0x90DDF5, alpha: 0.56)]),
                center: CGPoint(x: -5, y: -28),
                startRadius: 2,
                endRadius: 24
            )
        )
        // Tiny cheerful pink captain silhouette inside glass dome
        let capBody = AquaShape.circle(CGPoint(x: 1, y: -17), 8)
        StorybookArt.shape(c, capBody, hex: 0xFF9AC4, width: 1.6)
        c.fill(AquaShape.circle(CGPoint(x: -1.5, y: -18.5), 1.4), with: .color(StorybookArt.color(0x2A2238)))
        c.fill(AquaShape.circle(CGPoint(x: 3.5, y: -18.5), 1.4), with: .color(StorybookArt.color(0x2A2238)))
        var capSmile = Path()
        capSmile.move(to: CGPoint(x: -1, y: -14.5))
        capSmile.addQuadCurve(to: CGPoint(x: 3.2, y: -14.5), control: CGPoint(x: 1.1, y: -12.2))
        c.stroke(capSmile, with: .color(StorybookArt.color(0x8C3A5E)), style: strokeStyle(1.3))

        c.stroke(dome, with: .color(StorybookArt.color(0xFFFFFF, alpha: 0.92)), style: strokeStyle(2.4))
        StorybookArt.highlight(c, in: CGRect(x: -13, y: -34, width: 12, height: 6), opacity: 0.72)

        // Plump curved yellow submarine hull
        let hull = Path(roundedRect: CGRect(x: -48, y: -18, width: 96, height: 40), cornerRadius: 20)
        shaded(c, hull, hex: hullHex, top: -18, bottom: 22, line: 2.8)

        // Coral racing stripe along lower hull
        let stripe = Path(roundedRect: CGRect(x: -43, y: 6, width: 86, height: 7), cornerRadius: 3.5)
        c.fill(stripe, with: .color(StorybookArt.color(stripeHex, alpha: 0.9)))

        // Three glowing portholes
        for px in [-24.0, 0.0, 24.0] as [CGFloat] {
            let hole = AquaShape.circle(CGPoint(x: px, y: -1), 7.2)
            c.fill(hole, with: .linearGradient(Gradient(colors: [StorybookArt.color(0xC2F5FF), StorybookArt.color(0x4EAEE0)]),
                                               startPoint: CGPoint(x: px, y: -8), endPoint: CGPoint(x: px, y: 6)))
            c.stroke(hole, with: .color(StorybookArt.outline(for: brassHex)), style: strokeStyle(2.4))
            c.fill(AquaShape.circle(CGPoint(x: px - 2.2, y: -3.2), 2.1), with: .color(.white.opacity(0.85)))
        }

        // Nose spotlight lamp
        let lamp = Path(roundedRect: CGRect(x: 42, y: -4, width: 11, height: 14), cornerRadius: 5)
        StorybookArt.fillAndStroke(c, lamp, fill: StorybookArt.color(0xFFF6B8), stroke: StorybookArt.outline(for: brassHex), width: 2.0)
        StorybookArt.highlight(c, in: CGRect(x: -32, y: -14, width: 34, height: 5), opacity: 0.45)
    }

    static func submarineIcon(_ g: GraphicsContext) {
        var c = g
        c.scaleBy(x: 0.56, y: 0.56)
        c.translateBy(x: 2, y: 8)
        submarine(c, propPhase: 0.9, facing: 1, beamAngle: 0.25, night: 0, time: 0, drawBeam: false)
    }

    static func hiddenSandClue(
        _ g: GraphicsContext,
        kind: AquaHiddenSpotKind,
        pop: CGFloat,
        seed: Int,
        time t: CGFloat,
        night: CGFloat
    ) {
        let fade = aqClamp(1 - pop * 1.35)
        guard fade > 0.02 else { return }

        var c = g
        c.opacity = Double(fade)

        let mound = Path(ellipseIn: CGRect(x: -16, y: -6, width: 32, height: 11))
        let moundHex: UInt32 = night > 0.5 ? 0x4E6082 : 0xE5C694
        c.fill(mound, with: .color(StorybookArt.color(moundHex, alpha: 0.85)))
        let shadow = Path(ellipseIn: CGRect(x: -10, y: -4, width: 20, height: 6))
        c.fill(shadow, with: .color(StorybookArt.color(0x4A3A50, alpha: 0.32)))

        if kind == .sunkenPearl {
            let pulse = 0.55 + 0.45 * sin(t * 2.8 + CGFloat(seed))
            c.fill(
                AquaShape.circle(CGPoint(x: 0, y: -4), 6 + 2 * pulse),
                with: .color(StorybookArt.color(0xFFF6C8, alpha: Double(0.38 * pulse)))
            )
            StorybookArt.sparkle(c, at: CGPoint(x: 0, y: -6), radius: 3.5 + 1.8 * pulse, color: Theme.lemon, opacity: Double(0.85 * pulse))
        } else {
            let cycle = (t + CGFloat(seed) * 1.13).truncatingRemainder(dividingBy: 3.2)
            let blinking = cycle > 2.95
            let peekBob = sin(t * 1.9 + CGFloat(seed)) * 1.2
            for ex in [-4.8, 4.8] as [CGFloat] {
                let ey = -4.2 + peekBob
                if blinking {
                    var lid = Path()
                    lid.move(to: CGPoint(x: ex - 2.2, y: ey))
                    lid.addLine(to: CGPoint(x: ex + 2.2, y: ey))
                    c.stroke(lid, with: .color(StorybookArt.color(0x3B2A48, alpha: 0.75)), style: strokeStyle(1.3))
                } else {
                    c.fill(AquaShape.circle(CGPoint(x: ex, y: ey), 2.7), with: .color(.white.opacity(0.95)))
                    c.fill(AquaShape.circle(CGPoint(x: ex + 0.4, y: ey), 1.45), with: .color(StorybookArt.color(0x2A2238)))
                }
            }
        }

        for k in 0..<2 {
            let u = (t * 0.45 + CGFloat(seed) * 0.37 + CGFloat(k) * 0.5).truncatingRemainder(dividingBy: 1)
            let bx = (k == 0 ? -4 : 5) + sin(u * 5 + CGFloat(seed)) * 2.5
            let by = -8 - u * 22
            let br: CGFloat = k == 0 ? 2.2 : 1.6
            let ba = Double(sin(u * .pi)) * 0.72
            if ba > 0.05 {
                let bubble = AquaShape.circle(CGPoint(x: bx, y: by), br)
                c.fill(bubble, with: .color(.white.opacity(0.28 * ba)))
                c.stroke(bubble, with: .color(.white.opacity(0.85 * ba)), lineWidth: 1.0)
            }
        }
    }

    static func hiddenSurprise(
        _ g: GraphicsContext,
        kind: AquaHiddenSpotKind,
        pop: CGFloat,
        time t: CGFloat,
        night: CGFloat,
        celebrating: Bool = false
    ) {
        guard pop > 0.02 else { return }
        var c = g
        let ease = aqEase(pop)
        let joyBounce: CGFloat = celebrating ? abs(sin(t * 16)) * 10 : 0
        let joyWiggle: CGFloat = celebrating ? sin(t * 22) * 0.16 : 0
        c.opacity = Double(ease)
        c.translateBy(x: 0, y: (1 - ease) * 16 - sin(t * 5) * 2.5 - joyBounce)
        c.rotate(by: .radians(Double(joyWiggle)))
        let sc = (0.75 + 0.25 * ease) * (celebrating ? 1.12 : 1)
        c.scaleBy(x: sc, y: sc)

        let haloR: CGFloat = celebrating ? 34 : 28
        c.fill(
            AquaShape.circle(CGPoint(x: 0, y: -14), haloR),
            with: .color(StorybookArt.color(0xFFF4B8, alpha: Double((celebrating ? 0.42 : 0.24) + 0.22 * night) * Double(ease)))
        )

        switch kind {
        case .hermitCrab:
            let spiralShell = Path(ellipseIn: CGRect(x: -18, y: -28, width: 28, height: 24))
            shaded(c, spiralShell, hex: 0xD8A8F5, top: -28, bottom: -4, line: 2.2)
            let body = Path(ellipseIn: CGRect(x: -2, y: -18, width: 20, height: 15))
            shaded(c, body, hex: 0xFF7B5C, top: -18, bottom: -3, line: 2.0)
            let wave = sin(t * (celebrating ? 18 : 9)) * (celebrating ? 5 : 3)
            let claw = AquaShape.circle(CGPoint(x: 19, y: -16 - wave), 5.5)
            StorybookArt.shape(c, claw, hex: 0xFF7B5C, width: 1.8)
            for ex in [6.0, 13.0] as [CGFloat] {
                c.fill(AquaShape.circle(CGPoint(x: ex, y: -22), 3.4), with: .color(.white))
                c.fill(AquaShape.circle(CGPoint(x: ex + 0.6, y: -22), 1.8), with: .color(StorybookArt.color(0x2A2238)))
            }
        case .glowSeahorse:
            var sg = c
            sg.translateBy(x: 0, y: -18)
            sg.scaleBy(x: 0.56, y: 0.56)
            AquaFishPainter.drawLocal(sg, kind: .seahorse, variant: AquaRare.variant, phase: t * 14, amp: 0.35, gulp: 0, puff: 0, time: t, baby: true)
        case .starfish:
            var st = c
            st.translateBy(x: 0, y: -4)
            st.scaleBy(x: 0.74, y: 0.74)
            st.rotate(by: .radians(Double(sin(t * 6) * 0.14)))
            starfish(st)
            st.fill(AquaShape.circle(CGPoint(x: -5, y: -16), 2.0), with: .color(StorybookArt.color(0x2A2238)))
            st.fill(AquaShape.circle(CGPoint(x: 5, y: -16), 2.0), with: .color(StorybookArt.color(0x2A2238)))
        case .sunkenPearl:
            AquaVisitorPainter.pearl(c, at: CGPoint(x: 0, y: -16), r: 12, glow: ease)
            StorybookArt.sparkle(c, at: CGPoint(x: 12, y: -28), radius: 6 * ease, color: Theme.lemon, opacity: Double(ease))
        }
    }

    static func floatingGift(_ g: GraphicsContext, kind: AquaFloatingGiftKind, time t: CGFloat) {
        let pulse = 1 + 0.06 * sin(t * 4.2)
        var c = g
        c.scaleBy(x: pulse, y: pulse)

        let outer = AquaShape.circle(.zero, 20)
        c.fill(
            outer,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFFF6D6, alpha: 0.38), StorybookArt.color(0xA6EEFF, alpha: 0.16), .clear]),
                center: .zero,
                startRadius: 4,
                endRadius: 20
            )
        )
        c.stroke(outer, with: .color(.white.opacity(0.88)), style: strokeStyle(2.0))
        StorybookArt.highlight(c, in: CGRect(x: -12, y: -14, width: 8, height: 5), opacity: 0.85)

        switch kind {
        case .pearl:
            AquaVisitorPainter.pearl(c, at: .zero, r: 10.5, glow: 0.9)
        case .bubbleGift:
            let box = Path(roundedRect: CGRect(x: -9, y: -7, width: 18, height: 15), cornerRadius: 4.5)
            StorybookArt.shape(c, box, hex: 0xFF9AC4, width: 1.8)
            let vRibbon = Path(CGRect(x: -2, y: -7, width: 4, height: 15))
            let hRibbon = Path(CGRect(x: -9, y: -1, width: 18, height: 4))
            c.fill(vRibbon, with: .color(Theme.lemon))
            c.fill(hRibbon, with: .color(Theme.lemon))
            StorybookArt.sparkle(c, at: CGPoint(x: 0, y: -10), radius: 5.5, color: Theme.lemon, opacity: 1)
        case .starShell:
            var s = c
            s.translateBy(x: 0, y: 12)
            s.scaleBy(x: 0.56, y: 0.56)
            shell(s)
            StorybookArt.sparkle(c, at: CGPoint(x: 8, y: -10), radius: 5.5, color: Theme.lemon, opacity: 1)
        }
    }

    static func discoveryHalo(_ g: GraphicsContext, around center: CGPoint, radius: CGFloat, time t: CGFloat) {
        let pulse = 0.85 + 0.15 * sin(t * 4.5)
        let r = radius * pulse
        let ring = AquaShape.circle(center, r)
        g.fill(
            ring,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFFF3A8, alpha: 0.24), StorybookArt.color(0xFFE07D, alpha: 0.08), .clear]),
                center: center,
                startRadius: r * 0.3,
                endRadius: r
            )
        )
        g.stroke(ring, with: .color(StorybookArt.color(0xFFE884, alpha: 0.72)), style: StrokeStyle(lineWidth: 2.2, dash: [6, 6]))
        for k in 0..<3 {
            let a = t * 1.9 + CGFloat(k) * (2 * .pi / 3)
            let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r * 0.86)
            let sp = 5.0 + 2.2 * sin(t * 6 + CGFloat(k) * 1.7)
            StorybookArt.sparkle(g, at: pt, radius: sp, color: k == 1 ? .white : Theme.lemon, opacity: 0.95)
        }
    }

    static func playWishBubble(
        _ g: GraphicsContext,
        kind: AquaPlayWishKind,
        at center: CGPoint,
        tailToward: CGPoint,
        time t: CGFloat
    ) {
        let bob = sin(t * 2.8) * 3.5
        let cx = max(AGeo.left + 48, min(AGeo.right - 48, center.x))
        let cy = max(AGeo.waterY + 42, min(AGeo.sand(cx) - 70, center.y + bob))
        let sc: CGFloat = 0.78
        let tailOffset = CGPoint(
            x: (tailToward.x - cx) / sc,
            y: (tailToward.y - cy) / sc
        )

        var bg = g
        bg.translateBy(x: cx, y: cy)
        bg.scaleBy(x: sc, y: sc)
        StorybookArt.thoughtBubble(bg, center: .zero, radius: 32, tailToward: tailOffset)

        switch kind {
        case .hoopTrick:
            var ic = bg
            ic.scaleBy(x: 0.64, y: 0.64)
            hoopIcon(ic, time: t)
        case .pearlPellet:
            var ic = bg
            ic.scaleBy(x: 1.15, y: 1.15)
            treatToggleIcon(ic, mode: .pearls, time: t)
        case .nightGlow:
            bg.fill(AquaShape.circle(.zero, 20), with: .color(StorybookArt.color(0x5A4BC4)))
            var moon = Path()
            moon.move(to: CGPoint(x: 4, y: -12))
            moon.addCurve(to: CGPoint(x: 10, y: 10), control1: CGPoint(x: -8, y: -8), control2: CGPoint(x: -6, y: 12))
            moon.addCurve(to: CGPoint(x: 4, y: -12), control1: CGPoint(x: -16, y: 14), control2: CGPoint(x: -16, y: -14))
            moon.closeSubpath()
            bg.fill(moon, with: .color(Theme.lemon))
            StorybookArt.sparkle(bg, at: CGPoint(x: 9, y: -7), radius: 5, color: .white, opacity: 1)
            StorybookArt.sparkle(bg, at: CGPoint(x: -10, y: 7), radius: 3.5, color: Theme.lemon, opacity: 0.95)
        case .glassPolish:
            var ic = bg
            ic.rotate(by: .radians(-0.18))
            ic.scaleBy(x: 0.48, y: 0.48)
            wiper(ic)
        case .ribbonDance:
            var scCtx = bg
            scCtx.translateBy(x: -4, y: 12)
            scCtx.scaleBy(x: 0.68, y: 0.68)
            singingClam(scCtx, shellHex: 0xFFB0C8, open: 0.8, bounce: 0, time: t)
            let noteHead = Path(ellipseIn: CGRect(x: 6, y: -10, width: 7, height: 5.5))
            bg.fill(noteHead, with: .color(Theme.pink))
            var stem = Path()
            stem.move(to: CGPoint(x: 12.5, y: -8))
            stem.addLine(to: CGPoint(x: 12.5, y: -20))
            stem.addQuadCurve(to: CGPoint(x: 18, y: -15), control: CGPoint(x: 18, y: -20))
            bg.stroke(stem, with: .color(Theme.pink), style: strokeStyle(2.2))
        case .decorPlay(let decorKind, _):
            var dc = bg
            let span = max(decorKind.size.width, decorKind.size.height)
            let dScale = min(0.42, 42 / max(1, span))
            dc.translateBy(x: 0, y: decorKind.size.height * dScale * 0.48)
            dc.scaleBy(x: dScale, y: dScale)
            drawKind(dc, decorKind, time: t, sway: 0, open: 0, seed: 1)
        }
    }

    static func treatToggleIcon(_ g: GraphicsContext, mode: AquaTreatMode, time t: CGFloat) {
        if mode == .pearls {
            let halo = AquaShape.circle(.zero, 17)
            g.fill(halo, with: .color(StorybookArt.color(0xD8B4FF, alpha: 0.32)))
            let orb = AquaShape.circle(.zero, 12.5)
            StorybookArt.fillAndStroke(g, orb, fill: StorybookArt.color(0xFFF6D6), stroke: StorybookArt.color(0xB898FF), width: 2.2)
            g.fill(AquaShape.circle(CGPoint(x: -4, y: -4), 3.6), with: .color(.white))
            StorybookArt.sparkle(g, at: CGPoint(x: 12, y: -12), radius: 5.5, color: Theme.lemon, opacity: 1)
        } else {
            let flakes: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
                (-8, -5, -0.35, 0xFF7452),
                (7, -6, 0.42, 0xFFD052),
                (-1, 7, -0.12, 0x74CA64),
            ]
            for (dx, dy, rot, hex) in flakes {
                var fc = g
                fc.translateBy(x: dx, y: dy)
                fc.rotate(by: .radians(Double(rot)))
                let p = Path(roundedRect: CGRect(x: -7.5, y: -4.4, width: 15, height: 8.8), cornerRadius: 3.6)
                StorybookArt.shape(fc, p, hex: hex, width: 1.8)
            }
        }
    }
}
