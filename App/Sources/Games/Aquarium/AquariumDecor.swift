import SwiftUI

// MARK: - Decorations and tools, drawn
//
// A decoration is drawn around the middle of its bottom edge (where it sits on the sand). Plants bend with `sway`
// plus a slow current, more toward their tips.

enum AquaDecorPainter {
    static func draw(_ ctx: GraphicsContext, _ d: AquaDecor, time t: CGFloat) {
        var g = ctx
        g.translateBy(x: d.x, y: d.y)
        let since = CGFloat(Double(t) - d.poke)
        let wobble = since < 1.2 ? sin(since * 18) * 0.07 * exp(-since * 3.5) : 0
        g.rotate(by: .radians(Double(d.rot + wobble)))
        let sq = max(-0.25, min(0.3, d.squash))
        g.scaleBy(x: (d.flip ? -1 : 1) * (1 + sq * 0.5), y: 1 - sq)
        let sway = (d.flip ? -1 : 1) * d.sway
        drawKind(g, d.kind, time: t, sway: sway, open: d.open, seed: d.id)
    }

    static func drawKind(_ g: GraphicsContext, _ k: AquaDecorKind, time t: CGFloat, sway: CGFloat, open: CGFloat, seed: Int) {
        switch k {
        case .castle: castle(g)
        case .chest: chest(g, open: open, t: t)
        case .diver: diver(g)
        case .bubbler: bubbler(g)
        case .ship: ship(g)
        case .pillar, .slate: reefStone(g, slab: k == .slate, seed: seed)
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
        }
    }

    private static func outline(_ c: ARGB) -> Color { c.shade(-0.45).color(0.8) }

    private static func shaded(_ g: GraphicsContext, _ p: Path, _ c: ARGB, top: CGFloat, bottom: CGFloat, line: CGFloat = 1.6) {
        g.fill(p, with: .linearGradient(Gradient(colors: [c.shade(0.15).color, c.color, c.shade(-0.2).color]),
                                        startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
        g.stroke(p, with: .color(outline(c)), lineWidth: line)
    }

    /// Green fuzz along the bottom of things that have been underwater a while.
    private static func moss(_ g: GraphicsContext, width w: CGFloat, seed: Int) {
        var p = Path()
        for k in 0..<Int(w / 9) {
            let x = -w / 2 + CGFloat(k) * 9 + aqRand(k, seed) * 4
            let r = 4 + aqRand(k, seed + 1) * 5
            p.addEllipse(in: CGRect(x: x - r, y: -r * 1.3, width: r * 2, height: r * 1.8))
        }
        g.fill(p, with: .color(ARGB(0x5E9E4C).color(0.75)))
    }

    // MARK: Kinds

    static func castle(_ g: GraphicsContext) {
        let stone = ARGB(0xC9B8EA)
        let roof = ARGB(0xFF94BE)
        func tower(_ x0: CGFloat, _ x1: CGFloat, _ top: CGFloat, roofed: Bool) {
            let body = Path(CGRect(x: x0, y: top, width: x1 - x0, height: -top))
            shaded(g, body, stone, top: top, bottom: 0)
            if roofed {
                var cone = Path()
                cone.move(to: CGPoint(x: x0 - 6, y: top))
                cone.addLine(to: CGPoint(x: (x0 + x1) / 2, y: top - 38))
                cone.addLine(to: CGPoint(x: x1 + 6, y: top))
                cone.closeSubpath()
                shaded(g, cone, roof, top: top - 38, bottom: top)
                g.fill(AquaShape.circle(CGPoint(x: (x0 + x1) / 2, y: top - 40), 3.5), with: .color(ARGB(0xFFD86B).color))
            } else {
                var crenel = Path()
                let n = 4
                let w = (x1 - x0) / CGFloat(n * 2 - 1)
                for k in 0..<n { crenel.addRect(CGRect(x: x0 + CGFloat(k * 2) * w, y: top - 9, width: w, height: 10)) }
                shaded(g, crenel, stone, top: top - 9, bottom: top)
            }
            // a window
            let wx = (x0 + x1) / 2
            var win = Path()
            win.addRoundedRect(in: CGRect(x: wx - 5, y: top + 18, width: 10, height: 16), cornerSize: CGSize(width: 5, height: 5))
            g.fill(win, with: .color(ARGB(0x2E3A66).color(0.85)))
        }
        tower(-72, -38, -128, roofed: true)
        tower(38, 72, -112, roofed: true)
        tower(-26, 26, -168, roofed: false)
        let wall = Path(CGRect(x: -48, y: -74, width: 96, height: 74))
        shaded(g, wall, stone, top: -74, bottom: 0)
        var wallTop = Path()
        for k in 0..<6 { wallTop.addRect(CGRect(x: -48 + CGFloat(k) * 17.6, y: -82, width: 9, height: 9)) }
        shaded(g, wallTop, stone, top: -82, bottom: -74)
        // bricks
        var bricks = Path()
        for row in 0..<6 {
            let y = -12 - CGFloat(row) * 12
            bricks.move(to: CGPoint(x: -48, y: y)); bricks.addLine(to: CGPoint(x: 48, y: y))
            for k in 0..<5 {
                let x = -40 + CGFloat(k) * 20 + CGFloat(row % 2) * 10
                bricks.move(to: CGPoint(x: x, y: y)); bricks.addLine(to: CGPoint(x: x, y: y + 12))
            }
        }
        g.stroke(bricks, with: .color(stone.shade(-0.3).color(0.35)), lineWidth: 1)
        // the door: dark and arched, fish swim in and out of it in her head
        var door = Path()
        door.move(to: CGPoint(x: -18, y: 0))
        door.addLine(to: CGPoint(x: -18, y: -30))
        door.addArc(center: CGPoint(x: 0, y: -30), radius: 18, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        door.addLine(to: CGPoint(x: 18, y: 0))
        door.closeSubpath()
        g.fill(door, with: .linearGradient(Gradient(colors: [ARGB(0x1E2A52).color, ARGB(0x3A4A80).color]),
                                           startPoint: CGPoint(x: 0, y: -48), endPoint: CGPoint(x: 0, y: 0)))
        g.stroke(door, with: .color(outline(stone)), lineWidth: 2)
        moss(g, width: 140, seed: 3)
    }

    static func chest(_ g: GraphicsContext, open: CGFloat, t: CGFloat) {
        let wood = ARGB(0xA4683A)
        let gold = ARGB(0xF2C14E)
        // the treasure inside shows when the lid lifts
        if open > 0.04 {
            let glow = Double(open)
            g.fill(Path(ellipseIn: CGRect(x: -44, y: -66, width: 88, height: 46)),
                   with: .radialGradient(Gradient(colors: [ARGB(0xFFF1A8).color(0.85 * glow), ARGB(0xFFF1A8).color(0)]),
                                         center: CGPoint(x: 0, y: -42), startRadius: 0, endRadius: 46))
            var coins = Path()
            for k in 0..<7 {
                let x = -30 + CGFloat(k) * 10
                coins.addEllipse(in: CGRect(x: x - 6, y: -48 - CGFloat(k % 3) * 4, width: 12, height: 7))
            }
            g.fill(coins, with: .color(gold.color))
            g.stroke(coins, with: .color(gold.shade(-0.35).color(0.8)), lineWidth: 1)
            g.fill(AquaShape.circle(CGPoint(x: 8, y: -54), 6), with: .radialGradient(Gradient(colors: [.white, ARGB(0xF6D7FF).color]),
                                                                                       center: CGPoint(x: 6, y: -56), startRadius: 0, endRadius: 7))
        }
        let box = Path(roundedRect: CGRect(x: -44, y: -42, width: 88, height: 42), cornerRadius: 4)
        shaded(g, box, wood, top: -42, bottom: 0)
        var planks = Path()
        for k in 1..<3 { planks.move(to: CGPoint(x: -44, y: -CGFloat(k) * 14)); planks.addLine(to: CGPoint(x: 44, y: -CGFloat(k) * 14)) }
        g.stroke(planks, with: .color(wood.shade(-0.35).color(0.5)), lineWidth: 1.2)
        for x in [-32, 26] as [CGFloat] {
            let band = Path(CGRect(x: x, y: -42, width: 7, height: 42))
            shaded(g, band, gold, top: -42, bottom: 0, line: 1)
        }
        // the lid, hinged at the back
        var lg = g
        lg.translateBy(x: -44, y: -42)
        lg.rotate(by: .radians(Double(-open * 1.05)))
        var lid = Path()
        lid.move(to: CGPoint(x: 0, y: 0))
        lid.addLine(to: CGPoint(x: 0, y: -10))
        lid.addQuadCurve(to: CGPoint(x: 88, y: -10), control: CGPoint(x: 44, y: -40))
        lid.addLine(to: CGPoint(x: 88, y: 0))
        lid.closeSubpath()
        shaded(lg, lid, wood, top: -30, bottom: 0)
        for x in [12, 70] as [CGFloat] {
            var band = Path()
            band.addRect(CGRect(x: x, y: -26, width: 7, height: 26))
            lg.fill(band, with: .color(gold.color))
        }
        lg.stroke(lid, with: .color(outline(wood)), lineWidth: 1.6)
        // the lock
        let lock = Path(roundedRect: CGRect(x: -7, y: -46, width: 14, height: 16), cornerRadius: 3)
        shaded(g, lock, gold, top: -46, bottom: -30, line: 1)
        g.fill(AquaShape.circle(CGPoint(x: 0, y: -39), 2.2), with: .color(ARGB(0x5B3A28).color))
        moss(g, width: 80, seed: 9)
    }

    static func diver(_ g: GraphicsContext) {
        let brass = ARGB(0xD9A441)
        let suit = ARGB(0x8FA9BF)
        // boots and legs
        for x in [-15, 3] as [CGFloat] {
            let leg = Path(roundedRect: CGRect(x: x, y: -46, width: 13, height: 40), cornerRadius: 5)
            shaded(g, leg, suit, top: -46, bottom: -6)
            let boot = Path(roundedRect: CGRect(x: x - 3, y: -12, width: 19, height: 12), cornerRadius: 3)
            shaded(g, boot, ARGB(0x6A5A70), top: -12, bottom: 0)
        }
        let body = Path(roundedRect: CGRect(x: -22, y: -86, width: 44, height: 46), cornerRadius: 14)
        shaded(g, body, suit, top: -86, bottom: -40)
        // arms
        var arms = Path()
        arms.move(to: CGPoint(x: -20, y: -78)); arms.addQuadCurve(to: CGPoint(x: -30, y: -48), control: CGPoint(x: -32, y: -70))
        arms.move(to: CGPoint(x: 20, y: -78)); arms.addQuadCurve(to: CGPoint(x: 32, y: -56), control: CGPoint(x: 34, y: -74))
        g.stroke(arms, with: .color(suit.shade(-0.4).color), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        g.stroke(arms, with: .color(suit.color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        // a belt of weights
        let belt = Path(CGRect(x: -22, y: -50, width: 44, height: 7))
        shaded(g, belt, ARGB(0x6A5A70), top: -50, bottom: -43, line: 1)
        // the brass helmet with its round window
        let collar = Path(roundedRect: CGRect(x: -20, y: -94, width: 40, height: 12), cornerRadius: 4)
        shaded(g, collar, brass, top: -94, bottom: -82)
        let helmet = AquaShape.circle(CGPoint(x: 0, y: -108), 22)
        g.fill(helmet, with: .radialGradient(Gradient(colors: [brass.shade(0.45).color, brass.color, brass.shade(-0.25).color]),
                                             center: CGPoint(x: -7, y: -116), startRadius: 2, endRadius: 28))
        g.stroke(helmet, with: .color(outline(brass)), lineWidth: 1.6)
        let window = AquaShape.circle(CGPoint(x: 4, y: -107), 11)
        g.fill(window, with: .linearGradient(Gradient(colors: [ARGB(0x7FD3E8).color, ARGB(0x2A5A7A).color]),
                                             startPoint: CGPoint(x: 0, y: -118), endPoint: CGPoint(x: 0, y: -96)))
        g.stroke(window, with: .color(brass.shade(-0.3).color), lineWidth: 3)
        g.fill(Path(ellipseIn: CGRect(x: -2, y: -114, width: 5, height: 4)), with: .color(.white.opacity(0.8)))
        var bolts = Path()
        for a in stride(from: 0.0, to: 6.28, by: 1.05) {
            bolts.addEllipse(in: CGRect(x: 4 + cos(CGFloat(a)) * 14 - 1.5, y: -107 + sin(CGFloat(a)) * 14 - 1.5, width: 3, height: 3))
        }
        g.fill(bolts, with: .color(brass.shade(-0.3).color))
        // the air valve on top
        let valve = Path(roundedRect: CGRect(x: 4, y: -134, width: 8, height: 8), cornerRadius: 2)
        shaded(g, valve, brass, top: -134, bottom: -126, line: 1)
    }

    static func bubbler(_ g: GraphicsContext) {
        let stone = ARGB(0x9AA6B4)
        // the air line runs off to the back
        var hose = Path()
        hose.move(to: CGPoint(x: 18, y: -8))
        hose.addQuadCurve(to: CGPoint(x: 34, y: -2), control: CGPoint(x: 30, y: -10))
        g.stroke(hose, with: .color(ARGB(0xB9E3D9).color(0.7)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        let disc = Path(ellipseIn: CGRect(x: -22, y: -18, width: 44, height: 18))
        shaded(g, disc, stone, top: -18, bottom: 0)
        var pores = Path()
        for k in 0..<10 {
            let x = -15 + CGFloat(k % 5) * 7.5, y = -13 + CGFloat(k / 5) * 5
            pores.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
        }
        g.fill(pores, with: .color(stone.shade(-0.4).color(0.6)))
    }

    static func ship(_ g: GraphicsContext) {
        let wood = ARGB(0x8E5D3A)
        var s = g
        s.rotate(by: .radians(-0.1))
        // the broken mast and a torn sail
        var mast = Path()
        mast.move(to: CGPoint(x: -6, y: -58))
        mast.addLine(to: CGPoint(x: 6, y: -146))
        s.stroke(mast, with: .color(wood.shade(-0.35).color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        s.stroke(mast, with: .color(wood.shade(0.1).color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        var sail = Path()
        sail.move(to: CGPoint(x: 4, y: -134))
        sail.addQuadCurve(to: CGPoint(x: 62, y: -120), control: CGPoint(x: 40, y: -142))
        sail.addLine(to: CGPoint(x: 52, y: -98))
        sail.addLine(to: CGPoint(x: 60, y: -84))
        sail.addQuadCurve(to: CGPoint(x: 0, y: -80), control: CGPoint(x: 30, y: -90))
        sail.closeSubpath()
        s.fill(sail, with: .color(ARGB(0xEFE7D2).color(0.8)))
        s.stroke(sail, with: .color(ARGB(0xB9AC8C).color(0.8)), lineWidth: 1.2)
        s.fill(AquaShape.circle(CGPoint(x: 30, y: -108), 5), with: .color(ARGB(0x3A6A8A).color(0.6)))
        // the hull, half buried
        var hull = Path()
        hull.move(to: CGPoint(x: -112, y: -64))
        hull.addLine(to: CGPoint(x: 96, y: -62))
        hull.addQuadCurve(to: CGPoint(x: 116, y: -84), control: CGPoint(x: 112, y: -66))
        hull.addQuadCurve(to: CGPoint(x: 84, y: 4), control: CGPoint(x: 110, y: -16))
        hull.addLine(to: CGPoint(x: -96, y: 6))
        hull.addQuadCurve(to: CGPoint(x: -112, y: -64), control: CGPoint(x: -116, y: -24))
        hull.closeSubpath()
        shaded(s, hull, wood, top: -84, bottom: 6, line: 2)
        var planks = Path()
        for k in 1..<5 {
            let y = -64 + CGFloat(k) * 14
            planks.move(to: CGPoint(x: -110 + CGFloat(k) * 3, y: y))
            planks.addLine(to: CGPoint(x: 100 - CGFloat(k) * 4, y: y))
        }
        s.stroke(planks, with: .color(wood.shade(-0.4).color(0.5)), lineWidth: 1.2)
        // portholes
        for x in [-60, -14, 32] as [CGFloat] {
            let hole = AquaShape.circle(CGPoint(x: x, y: -36), 9)
            s.fill(hole, with: .color(ARGB(0x1E2D4A).color(0.9)))
            s.stroke(hole, with: .color(ARGB(0xD9A441).color), lineWidth: 3)
        }
        // the rail
        var rail = Path()
        rail.move(to: CGPoint(x: -110, y: -64))
        for k in 0..<10 {
            let x = -100 + CGFloat(k) * 20
            rail.move(to: CGPoint(x: x, y: -64)); rail.addLine(to: CGPoint(x: x, y: -76))
        }
        rail.move(to: CGPoint(x: -104, y: -76)); rail.addLine(to: CGPoint(x: 90, y: -76))
        s.stroke(rail, with: .color(wood.shade(-0.3).color), lineWidth: 2.5)
        // weed growing on it
        var weed = Path()
        for k in 0..<12 {
            let x = -90 + CGFloat(k) * 16 + aqRand(k, 21) * 6
            let r = 5 + aqRand(k, 22) * 5
            weed.addEllipse(in: CGRect(x: x - r, y: -8 - r - aqRand(k, 23) * 18, width: r * 2, height: r * 1.6))
        }
        s.fill(weed, with: .color(ARGB(0x5E9E4C).color(0.7)))
    }

    static func rock(_ g: GraphicsContext) {
        let a = ARGB(0x8E9BB0), b = ARGB(0xA7B2C4)
        var big = Path()
        big.move(to: CGPoint(x: -72, y: 0))
        big.addCurve(to: CGPoint(x: -20, y: -90), control1: CGPoint(x: -76, y: -50), control2: CGPoint(x: -56, y: -88))
        big.addCurve(to: CGPoint(x: 56, y: -52), control1: CGPoint(x: 14, y: -94), control2: CGPoint(x: 50, y: -80))
        big.addCurve(to: CGPoint(x: 70, y: 0), control1: CGPoint(x: 64, y: -30), control2: CGPoint(x: 72, y: -16))
        big.closeSubpath()
        shaded(g, big, a, top: -92, bottom: 0, line: 2)
        // the arch fish can pass through
        var arch = Path()
        arch.move(to: CGPoint(x: -30, y: 0))
        arch.addCurve(to: CGPoint(x: 26, y: 0), control1: CGPoint(x: -30, y: -56), control2: CGPoint(x: 26, y: -56))
        arch.closeSubpath()
        g.fill(arch, with: .linearGradient(Gradient(colors: [ARGB(0x24405E).color, ARGB(0x3D6688).color]),
                                           startPoint: CGPoint(x: 0, y: -44), endPoint: CGPoint(x: 0, y: 0)))
        g.stroke(arch, with: .color(outline(a)), lineWidth: 1.6)
        let small = Path(ellipseIn: CGRect(x: 40, y: -34, width: 40, height: 36))
        shaded(g, small, b, top: -34, bottom: 2)
        var cracks = Path()
        cracks.move(to: CGPoint(x: -40, y: -60)); cracks.addLine(to: CGPoint(x: -30, y: -50)); cracks.addLine(to: CGPoint(x: -34, y: -40))
        cracks.move(to: CGPoint(x: 30, y: -70)); cracks.addLine(to: CGPoint(x: 38, y: -58))
        g.stroke(cracks, with: .color(a.shade(-0.4).color(0.5)), lineWidth: 1.2)
        g.fill(Path(ellipseIn: CGRect(x: -30, y: -84, width: 30, height: 10)), with: .color(.white.opacity(0.25)))
        moss(g, width: 120, seed: 14)
    }

    /// Ribbons that bend more toward their tips and ripple in the current.
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
            g.fill(ribbon, with: .linearGradient(Gradient(colors: [col.shade(-0.25).color, col.color, col.shade(0.2).color]),
                                                 startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: -hgt)))
            g.stroke(ribbon, with: .color(col.shade(-0.4).color(0.7)), lineWidth: 1.2)
            g.stroke(AquaShape.smoothOpen(mid), with: .color(col.shade(0.35).color(0.45)), lineWidth: 1.2)
        }
    }

    static func coral(_ g: GraphicsContext) {
        let pink = ARGB(0xFF8FA6)
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
        g.stroke(branches, with: .color(pink.shade(-0.4).color), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
        g.stroke(branches, with: .color(pink.color), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
        g.stroke(branches, with: .color(pink.shade(0.35).color(0.6)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        var polyps = Path()
        for p in tips { polyps.addEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)) }
        g.fill(polyps, with: .color(ARGB(0xFFD6E0).color))
        g.stroke(polyps, with: .color(pink.shade(-0.3).color(0.6)), lineWidth: 1)
    }

    static func anemone(_ g: GraphicsContext, t: CGFloat, sway: CGFloat, seed: Int) {
        let base = ARGB(0x9B6BD6)
        let arm = ARGB(0xC9A0FF)
        var stalk = Path()
        stalk.move(to: CGPoint(x: -26, y: 0))
        stalk.addQuadCurve(to: CGPoint(x: -20, y: -32), control: CGPoint(x: -30, y: -16))
        stalk.addLine(to: CGPoint(x: 20, y: -32))
        stalk.addQuadCurve(to: CGPoint(x: 26, y: 0), control: CGPoint(x: 30, y: -16))
        stalk.closeSubpath()
        shaded(g, stalk, base, top: -32, bottom: 0)
        var arms = Path()
        var tips = Path()
        for k in 0..<18 {
            let f = CGFloat(k) / 17 * 2 - 1
            let p0 = CGPoint(x: f * 20, y: -30)
            let a = -CGFloat.pi / 2 + f * 1.1 + (sway + sin(t * 1.4 + CGFloat(k) * 0.5 + CGFloat(seed)) * 0.18)
            let len = 30 + aqRand(k, seed) * 14
            let mid = CGPoint(x: p0.x + cos(a - 0.2) * len * 0.55, y: p0.y + sin(a - 0.2) * len * 0.55)
            let tip = CGPoint(x: p0.x + cos(a) * len, y: p0.y + sin(a) * len)
            arms.move(to: p0)
            arms.addQuadCurve(to: tip, control: mid)
            tips.addEllipse(in: CGRect(x: tip.x - 3.5, y: tip.y - 3.5, width: 7, height: 7))
        }
        g.stroke(arms, with: .color(arm.shade(-0.4).color(0.8)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        g.stroke(arms, with: .color(arm.color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        g.fill(tips, with: .color(ARGB(0xFF9ED6).color))
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
        g.fill(dark, with: .color(ARGB(0x3E9C4E).color))
        g.fill(light, with: .color(ARGB(0x68C46A).color))
        g.stroke(dark, with: .color(ARGB(0x2A6E38).color(0.6)), lineWidth: 1)
        g.stroke(light, with: .color(ARGB(0x2A6E38).color(0.5)), lineWidth: 1)
    }

    static func shell(_ g: GraphicsContext) {
        let c = ARGB(0xFFBFA6)
        var fan = Path()
        fan.move(to: CGPoint(x: -5, y: -4))
        fan.addCurve(to: CGPoint(x: 0, y: -42), control1: CGPoint(x: -34, y: -10), control2: CGPoint(x: -30, y: -42))
        fan.addCurve(to: CGPoint(x: 5, y: -4), control1: CGPoint(x: 30, y: -42), control2: CGPoint(x: 34, y: -10))
        fan.closeSubpath()
        shaded(g, fan, c, top: -42, bottom: -4)
        var ridges = Path()
        for k in 0..<7 {
            let a = -CGFloat.pi / 2 + (CGFloat(k) - 3) * 0.32
            ridges.move(to: CGPoint(x: 0, y: -6))
            ridges.addLine(to: CGPoint(x: cos(a) * 34, y: -6 + sin(a) * 34))
        }
        g.stroke(ridges, with: .color(c.shade(-0.35).color(0.55)), lineWidth: 1.4)
        let hinge = Path(roundedRect: CGRect(x: -11, y: -9, width: 22, height: 9), cornerRadius: 3)
        shaded(g, hinge, c.shade(-0.1), top: -9, bottom: 0, line: 1.2)
    }

    static func starfish(_ g: GraphicsContext) {
        let c = ARGB(0xFF9248)
        var s = g
        s.translateBy(x: 0, y: -12)
        s.scaleBy(x: 1, y: 0.55)
        var star = Path()
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let r: CGFloat = k % 2 == 0 ? 28 : 11
            let p = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if k == 0 { star.move(to: p) } else { star.addLine(to: p) }
        }
        star.closeSubpath()
        s.fill(star, with: .radialGradient(Gradient(colors: [c.shade(0.3).color, c.color, c.shade(-0.15).color]),
                                           center: .zero, startRadius: 0, endRadius: 28))
        s.stroke(star, with: .color(outline(c)), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        var dots = Path()
        for k in 0..<5 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi * 2 / 5
            for r in [9, 16] as [CGFloat] {
                dots.addEllipse(in: CGRect(x: cos(a) * r - 1.8, y: sin(a) * r - 1.8, width: 3.6, height: 3.6))
            }
        }
        s.fill(dots, with: .color(ARGB(0xFFE0B8).color))
    }

    // MARK: Tools

    /// The food shaker, cap at the origin and the jar hanging below it (it's turned over to shake food out).
    static func shaker(_ g: GraphicsContext) {
        let jar = Path(roundedRect: CGRect(x: -24, y: 8, width: 48, height: 82), cornerRadius: 12)
        g.fill(jar, with: .linearGradient(Gradient(colors: [ARGB(0xFFF6E8).color(0.95), ARGB(0xFFE2C8).color(0.95)]),
                                          startPoint: CGPoint(x: -24, y: 0), endPoint: CGPoint(x: 24, y: 0)))
        // flakes inside
        var flakes: [Path] = [Path(), Path(), Path()]
        for k in 0..<24 {
            let x = -18 + aqRand(k, 41) * 36, y = 40 + aqRand(k, 42) * 46
            flakes[k % 3].addRect(CGRect(x: x, y: y, width: 4, height: 3))
        }
        g.fill(flakes[0], with: .color(ARGB(0xFF6A4A).color))
        g.fill(flakes[1], with: .color(ARGB(0xFFC94A).color))
        g.fill(flakes[2], with: .color(ARGB(0x7AC25A).color))
        // the label with a fish on it
        let label = Path(roundedRect: CGRect(x: -24, y: 20, width: 48, height: 24), cornerRadius: 3)
        g.fill(label, with: .color(ARGB(0x6EC6F0).color))
        var lf = g
        lf.translateBy(x: 0, y: 32)
        lf.scaleBy(x: 0.42, y: 0.42)
        AquaFishPainter.drawLocal(lf, kind: .goldfish, variant: 0, phase: 1, amp: 0.15, gulp: 0, puff: 0, time: 0)
        g.stroke(jar, with: .color(ARGB(0xC9A07A).color(0.9)), lineWidth: 2)
        g.fill(Path(roundedRect: CGRect(x: 12, y: 50, width: 5, height: 32), cornerRadius: 2.5), with: .color(.white.opacity(0.6)))
        // the cap, full of holes
        let cap = Path(roundedRect: CGRect(x: -22, y: -6, width: 44, height: 16), cornerRadius: 5)
        g.fill(cap, with: .linearGradient(Gradient(colors: [ARGB(0xFF8FB0).color, ARGB(0xE85A88).color]),
                                          startPoint: CGPoint(x: 0, y: -6), endPoint: CGPoint(x: 0, y: 10)))
        g.stroke(cap, with: .color(ARGB(0xB83E68).color), lineWidth: 1.5)
        var holes = Path()
        for k in 0..<5 { holes.addEllipse(in: CGRect(x: -14 + CGFloat(k) * 6.5, y: -4, width: 3, height: 3)) }
        g.fill(holes, with: .color(ARGB(0x7A2A48).color))
    }

    /// A sponge with a green scrubby side, drawn around its middle.
    static func sponge(_ g: GraphicsContext) {
        let body = Path(roundedRect: CGRect(x: -40, y: -24, width: 80, height: 48), cornerRadius: 12)
        g.fill(body, with: .linearGradient(Gradient(colors: [ARGB(0xFFE57A).color, ARGB(0xFFCB3D).color]),
                                           startPoint: CGPoint(x: 0, y: -24), endPoint: CGPoint(x: 0, y: 24)))
        var pores = Path()
        for k in 0..<16 {
            let x = -32 + aqRand(k, 51) * 64, y = -2 + aqRand(k, 52) * 22
            let r = 1.6 + aqRand(k, 53) * 2.4
            pores.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.6))
        }
        g.fill(pores, with: .color(ARGB(0xD9A021).color(0.8)))
        let scrub = Path(roundedRect: CGRect(x: -40, y: -24, width: 80, height: 16), cornerRadius: 8)
        g.fill(scrub, with: .color(ARGB(0x55B865).color))
        var fuzz = Path()
        for k in 0..<14 {
            let x = -36 + CGFloat(k) * 5.4
            fuzz.move(to: CGPoint(x: x, y: -20)); fuzz.addLine(to: CGPoint(x: x + 3, y: -12))
        }
        g.stroke(fuzz, with: .color(ARGB(0x2F8A45).color(0.6)), lineWidth: 1)
        g.stroke(body, with: .color(ARGB(0xC98F1E).color), lineWidth: 2)
    }

    /// The fishing net: hoop at the origin, handle hanging below it.
    static func netBack(_ g: GraphicsContext) {
        var pocket = Path()
        pocket.move(to: CGPoint(x: -34, y: 0))
        pocket.addQuadCurve(to: CGPoint(x: 34, y: 0), control: CGPoint(x: 0, y: 70))
        pocket.closeSubpath()
        g.fill(pocket, with: .color(.white.opacity(0.18)))
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
            mesh.move(to: CGPoint(x: -w, y: y)); mesh.addQuadCurve(to: CGPoint(x: w, y: y), control: CGPoint(x: 0, y: y + 6))
        }
        g.stroke(mesh, with: .color(.white.opacity(0.65)), lineWidth: 1)
        g.stroke(pocket, with: .color(.white.opacity(0.8)), lineWidth: 1.2)
        // handle
        var handle = Path()
        handle.move(to: CGPoint(x: 0, y: 12))
        handle.addLine(to: CGPoint(x: 0, y: 150))
        g.stroke(handle, with: .color(ARGB(0x2E8C74).color), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        g.stroke(handle, with: .color(ARGB(0x52C9A6).color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        let grip = Path(roundedRect: CGRect(x: -7, y: 112, width: 14, height: 44), cornerRadius: 7)
        g.fill(grip, with: .color(ARGB(0xFF8FB8).color))
        g.stroke(grip, with: .color(ARGB(0xD9558A).color), lineWidth: 1.4)
        // the hoop, seen a little from above
        let hoop = Path(ellipseIn: CGRect(x: -36, y: -12, width: 72, height: 24))
        g.stroke(hoop, with: .color(ARGB(0x2E8C74).color), lineWidth: 6)
        g.stroke(hoop, with: .color(ARGB(0x6FE0BE).color), lineWidth: 3)
    }

    /// A clear bag of water with a fish (or a few) in it, knotted at the top, drawn around its middle.
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
        g.fill(bag, with: .color(.white.opacity(0.35)))
        g.fill(water, with: .linearGradient(Gradient(colors: [ARGB(0x9FE2F5).color(0.75), ARGB(0x4FB4DD).color(0.75)]),
                                            startPoint: CGPoint(x: 0, y: -8), endPoint: CGPoint(x: 0, y: 34)))
        var fg = g
        let n = min(3, kind.group)
        let sc: CGFloat = kind.length > 50 ? 0.5 : (kind == .seahorse ? 0.45 : 0.8)
        for k in 0..<n {
            var one = fg
            one.translateBy(x: CGFloat(k - (n - 1) / 2) * 16 + sin(t * 1.5 + CGFloat(k)) * 4, y: 12 + CGFloat(k % 2) * 8)
            one.scaleBy(x: (k % 2 == 0 ? 1 : -1) * sc, y: sc)
            AquaFishPainter.drawLocal(one, kind: kind, variant: 0, phase: t * 9 + CGFloat(k), amp: 0.3, gulp: 0, puff: 0, time: t)
        }
        fg.opacity = 1
        g.stroke(bag, with: .color(.white.opacity(0.9)), lineWidth: 2)
        g.fill(Path(roundedRect: CGRect(x: 18, y: -16, width: 5, height: 28), cornerRadius: 2.5), with: .color(.white.opacity(0.7)))
        // the knot and a ribbon
        g.fill(Path(ellipseIn: CGRect(x: -9, y: -54, width: 18, height: 12)), with: .color(ARGB(0xFF8FB8).color))
        g.stroke(Path(ellipseIn: CGRect(x: -9, y: -54, width: 18, height: 12)), with: .color(ARGB(0xD9558A).color), lineWidth: 1.4)
    }
}
