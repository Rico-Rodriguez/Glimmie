import SwiftUI

// MARK: - Garden surprises for the sticker book
//
// Two kinds of surprise, and nothing she has to do on purpose:
// - Special plants. About one seed in four grows into a rare one: a pink sunflower, a blue tulip, a daisy that
//   glows at night, pink lavender, a purple carrot, a golden tomato, a white strawberry or a giant pumpkin.
//   It twinkles while it grows, and its sticker is hers when it blooms (or ripens).
// - Visitors. Animals drop in when the garden has something for them, stay a while, and wander off:
//   a bunny when carrots are ready, a frog and a snail in the rain, a hedgehog at night or for a ripe pumpkin,
//   a bluebird for the birdhouse or birdbath, an owl on the fence at night, a hummingbird for lavender.
//   Tapping one makes it hop, curl up or flutter. Each one's sticker is hers the first time it visits.
//
// Both go into the shared sticker book (`StickerBook`).

enum GardenFind: String, CaseIterable {
    case pinkSunflower, blueTulip, glowDaisy, pinkLavender, purpleCarrot, goldTomato, whiteStrawberry, giantPumpkin
    case bunny, frog, snail, hedgehog, bluebird, owl, hummingbird

    static func special(_ k: PlantKind) -> GardenFind {
        switch k {
        case .sunflower: return .pinkSunflower
        case .tulip: return .blueTulip
        case .daisy: return .glowDaisy
        case .lavender: return .pinkLavender
        case .carrot: return .purpleCarrot
        case .tomato: return .goldTomato
        case .strawberry: return .whiteStrawberry
        case .pumpkin: return .giantPumpkin
        }
    }

    var plant: PlantKind? { PlantKind.allCases.first { GardenFind.special($0) == self } }

    var visitor: GVisitorKind? { GVisitorKind(rawValue: rawValue) }

    static var stickers: [Sticker] {
        allCases.map { f in Sticker(id: f.rawValue) { g, _ in f.drawSticker(g) } }
    }

    /// Drawn centered in a 100-point square.
    func drawSticker(_ g: GraphicsContext) {
        if let k = plant {
            let v = Plant.specialVariant
            switch k {
            case .sunflower: GardenPlants.drawCrop(g, kind: k, variant: v, at: .zero, size: 1.55, rot: 0)
            case .tulip: GardenPlants.drawCrop(g, kind: k, variant: v, at: CGPoint(x: 0, y: -8), size: 1.9, rot: 0)
            case .daisy:
                g.fill(Path(ellipseIn: CGRect(x: -48, y: -48, width: 96, height: 96)),
                       with: .radialGradient(Gradient(colors: [k.specialColor.color(0.7), k.specialColor.color(0)]),
                                             center: .zero, startRadius: 10, endRadius: 48))
                GardenPlants.drawCrop(g, kind: k, variant: v, at: .zero, size: 1.9, rot: 0)
            case .lavender: GardenPlants.drawCrop(g, kind: k, variant: v, at: CGPoint(x: 0, y: 6), size: 1.7, rot: 0.15)
            case .carrot: GardenPlants.drawCrop(g, kind: k, variant: v, at: CGPoint(x: 0, y: -4), size: 1.45, rot: 0.35)
            case .tomato: GardenPlants.drawCrop(g, kind: k, variant: v, at: CGPoint(x: 0, y: 4), size: 2.5, rot: 0)
            case .strawberry: GardenPlants.drawCrop(g, kind: k, variant: v, at: CGPoint(x: 0, y: -4), size: 2.8, rot: 0)
            case .pumpkin: GardenPlants.drawCrop(g, kind: k, variant: v, at: CGPoint(x: 0, y: -10), size: 1.45, rot: 0)
            }
            GardenVisitorPainter.twinkles(g, around: .zero, radius: 40, time: 0.6, count: 3, alpha: 1)
        } else if let v = visitor {
            var s = g
            let k: CGFloat = 100 / v.stickerHeight
            s.translateBy(x: 0, y: v == .hummingbird ? 18 : 44)
            s.scaleBy(x: k * 0.8, y: k * 0.8)
            GardenVisitorPainter.draw(s, GVisitor(kind: v, p: .zero, facing: 1, seed: 0), time: 0.3, night: 0)
        }
    }
}

enum GVisitorKind: String, CaseIterable {
    case bunny, frog, snail, hedgehog, bluebird, owl, hummingbird

    var flies: Bool { self == .bluebird || self == .owl || self == .hummingbird }
    /// Drawn behind the bed, on the back lawn or the fence (the rest are in front, on the soil or in the air).
    var behind: Bool { self == .bunny || self == .hedgehog || self == .owl }
    /// Points a second.
    var speed: CGFloat {
        switch self {
        case .bunny: return 150
        case .frog: return 120
        case .snail: return 14
        case .hedgehog: return 60
        case .bluebird: return 260
        case .owl: return 220
        case .hummingbird: return 320
        }
    }
    var stickerHeight: CGFloat {
        switch self {
        case .bunny: return 78
        case .frog: return 40
        case .snail: return 34
        case .hedgehog: return 60
        case .bluebird: return 42
        case .owl: return 64
        case .hummingbird: return 50
        }
    }
    /// For taps, around its middle.
    var reach: CGFloat {
        switch self {
        case .snail, .hummingbird: return 44
        default: return 54
        }
    }
}

struct GVisitor {
    enum State { case arriving, staying, leaving }
    var kind: GVisitorKind
    /// Its feet (or the middle of a flier).
    var p: CGPoint
    var target = CGPoint.zero
    var state = State.arriving
    var stayUntil: Double = 0
    var facing: CGFloat
    /// Distance travelled, for hops and steps.
    var walk: CGFloat = 0
    /// When she last tapped it.
    var poked: Double = -10
    var seed = Int.random(in: 0..<1000)
    /// What it came for: a plot (bunny, hummingbird) or a decoration id (bluebird).
    var plot: Int?
    var decorID: Int?
    var moving: Bool { state != .staying }
}

// MARK: - Visitors and special plants in the simulation

extension GardenSim {
    /// How often a special plant comes up from a seed.
    static let specialChance = 0.25

    /// The seed she just planted might be a rare one.
    static func rollVariant() -> Int {
        Int.random(in: 0..<6) + (Double.random(in: 0..<1) < specialChance ? Plant.specialVariant : 0)
    }

    func discover(_ f: GardenFind, at p: CGPoint) {
        guard !demo else { return }
        if StickerBook.shared.find(game: GardenSim.gameID, id: f.rawValue) {
            sparkle(at: p, count: 18)
        }
    }

    func stepFinds(_ dt: CGFloat) {
        // Special plants are found when they bloom or ripen.
        if Int(time * 2) != Int((time - Double(dt)) * 2) {
            for i in plots.indices {
                guard let pl = plots[i].plant, pl.isSpecial, pl.growth >= 0.97 else { continue }
                if !StickerBook.shared.has(game: GardenSim.gameID, id: GardenFind.special(pl.kind).rawValue) {
                    discover(.special(pl.kind), at: head(plot: i) ?? CGPoint(x: GGeo.plotX[i], y: GGeo.soilY - 60))
                }
            }
        }
        stepVisitors(dt)
    }

    // MARK: Who might come

    private func ripe(_ k: PlantKind) -> Int? {
        plots.indices.first { plots[$0].plant?.kind == k && (plots[$0].plant?.growth ?? 0) >= 0.9 && !plots[$0].held }
    }

    /// Where a visitor of this kind would go right now, or nil if the garden has nothing for it.
    private func spot(for k: GVisitorKind) -> (CGPoint, Int?, Int?)? {
        let day = night < 0.5
        let wet = rain > 0.5
        func clampX(_ x: CGFloat) -> CGFloat { max(160, min(864, x)) }
        switch k {
        case .bunny:
            guard let i = ripe(.carrot) else { return nil }
            let x = clampX(GGeo.plotX[i] + (GGeo.plotX[i] < 512 ? 52 : -52))
            return (CGPoint(x: x, y: 526), i, nil)
        case .frog:
            let bath = decor.first { $0.kind == .birdbath && $0.water > 0.3 }
            guard wet || bath != nil else { return nil }
            if let b = bath, !wet { return (CGPoint(x: clampX(b.x + 58), y: b.baseY + 4), nil, nil) }
            let x = clampX(CGFloat.random(in: 220...800))
            return (CGPoint(x: x, y: surface(x)), nil, nil)
        case .snail:
            guard wet || wetAt(512, span: 100) > 0.55 else { return nil }
            let left = Bool.random()
            let x = left ? GGeo.bedLeft + CGFloat.random(in: 110...170) : GGeo.bedRight - CGFloat.random(in: 110...170)
            return (CGPoint(x: clampX(x), y: surface(x)), nil, nil)
        case .hedgehog:
            guard night > 0.5 || ripe(.pumpkin) != nil else { return nil }
            let x = ripe(.pumpkin).map { GGeo.plotX[$0] - 60 } ?? CGFloat.random(in: 240...780)
            return (CGPoint(x: clampX(x), y: 528), nil, nil)
        case .bluebird:
            guard day, !wet else { return nil }
            let homes = decor.filter { $0.kind == .birdhouse || $0.kind == .birdbath }
            guard let d = homes.randomElement() else { return nil }
            let top = d.kind == .birdhouse ? d.baseY - d.kind.size.height + 8 : d.baseY - 84
            return (CGPoint(x: d.x + (d.kind == .birdhouse ? 0 : 30), y: top), nil, d.id)
        case .owl:
            guard night > 0.6 else { return nil }
            // a fence post top (posts are every 30 points, 18 wide)
            let x = (CGFloat.random(in: 200...820) / 30).rounded() * 30 + 9
            return (CGPoint(x: x, y: 428), nil, nil)
        case .hummingbird:
            guard day, !wet else { return nil }
            let flowers = plots.indices.filter { i in
                guard let pl = plots[i].plant, pl.growth >= 0.95 else { return false }
                return pl.kind == .lavender || (pl.isSpecial && pl.kind.isFlower)
            }
            guard let i = flowers.randomElement(), let h = head(plot: i) else { return nil }
            return (CGPoint(x: h.x + 30, y: h.y - 10), i, nil)
        }
    }

    // MARK: Coming, staying, going

    private func stepVisitors(_ dt: CGFloat) {
        if time > nextVisit && visitors.count < 2 {
            nextVisit = time + Double.random(in: 12...24)
            let book = StickerBook.shared
            var options: [(GVisitorKind, (CGPoint, Int?, Int?))] = []
            for k in GVisitorKind.allCases where !visitors.contains(where: { $0.kind == k }) {
                guard let s = spot(for: k) else { continue }
                // ones she hasn't met yet come more often
                let n = book.has(game: GardenSim.gameID, id: k.rawValue) ? 1 : 3
                for _ in 0..<n { options.append((k, s)) }
            }
            if let o = options.randomElement() { arrive(o.0, at: o.1) }
        }
        for i in visitors.indices.reversed() {
            var v = visitors[i]
            switch v.state {
            case .arriving, .leaving:
                if v.kind == .hummingbird, v.state == .arriving, let pl = v.plot, let h = head(plot: pl) {
                    v.target = CGPoint(x: h.x + 30 * (v.target.x >= h.x ? 1 : -1), y: h.y - 10)
                }
                let dx = v.target.x - v.p.x
                let dy = v.target.y - v.p.y
                let d = hypot(dx, dy)
                let stepLen = v.kind.speed * dt
                if d <= stepLen {
                    v.p = v.target
                    if v.state == .leaving {
                        visitors.remove(at: i)
                        continue
                    }
                    v.state = .staying
                    v.stayUntil = time + Double.random(in: 10...18)
                    if v.kind == .snail { v.stayUntil += 12 }
                    if let f = GardenFind(rawValue: v.kind.rawValue) { discover(f, at: CGPoint(x: v.p.x, y: v.p.y - 30)) }
                } else {
                    v.p.x += dx / d * stepLen
                    v.p.y += dy / d * stepLen
                    v.walk += stepLen
                    if abs(dx) > 2 { v.facing = dx > 0 ? 1 : -1 }
                    if !v.kind.flies && !v.kind.behind { v.p.y = surface(v.p.x) }
                }
            case .staying:
                // Leave when its time is up, or when what it came for has gone.
                var gone = false
                if v.kind == .bunny, let pl = v.plot { gone = plots[pl].plant?.kind != .carrot }
                if v.kind == .hummingbird, let pl = v.plot { gone = plots[pl].plant == nil }
                if v.kind == .bluebird, let id = v.decorID {
                    if let d = decor.first(where: { $0.id == id }) {
                        gone = d.held
                    } else {
                        gone = true
                    }
                }
                if v.kind == .owl && night < 0.3 { gone = true }
                if v.kind == .frog || v.kind == .snail { v.p.y = surface(v.p.x) }
                if v.kind == .hummingbird, let pl = v.plot, let h = head(plot: pl) {
                    // hovers beside the flower, facing it, darting a little
                    let t = CGFloat(time)
                    let side: CGFloat = v.target.x >= h.x ? 1 : -1
                    v.facing = -side
                    v.p = CGPoint(x: h.x + 30 * side + sin(t * 1.3) * 6, y: h.y - 10 + sin(t * 2.1) * 5)
                }
                if time > v.stayUntil || gone { leave(&v) }
            }
            visitors[i] = v
        }
    }

    private func arrive(_ k: GVisitorKind, at s: (CGPoint, Int?, Int?)) {
        let fromLeft = s.0.x > 512 ? false : true
        let startX: CGFloat = fromLeft ? -90 : 1114
        var start = CGPoint(x: startX, y: s.0.y)
        if k.flies { start.y = max(120, s.0.y - 260) }
        if k == .snail { start = CGPoint(x: s.0.x < 512 ? GGeo.bedLeft - 40 : GGeo.bedRight + 40, y: s.0.y) }
        if !k.flies && !k.behind { start.y = surface(max(GGeo.bedLeft, min(GGeo.bedRight, start.x))) }
        var v = GVisitor(kind: k, p: start, facing: fromLeft ? 1 : -1)
        v.target = s.0
        v.plot = s.1
        v.decorID = s.2
        if k == .snail { v.facing = s.0.x < 512 ? 1 : -1 }
        visitors.append(v)
        if k.flies { GardenSound.shared.play(.flutter, volume: 0.6) }
    }

    private func leave(_ v: inout GVisitor) {
        v.state = .leaving
        let right = v.p.x > 512
        if v.kind == .snail {
            v.target = CGPoint(x: right ? GGeo.bedRight + 40 : GGeo.bedLeft - 40, y: v.p.y)
        } else {
            v.target = CGPoint(x: right ? 1114 : -90, y: v.kind.flies ? max(100, v.p.y - 240) : v.p.y)
        }
        v.facing = right ? 1 : -1
        if v.kind.flies { GardenSound.shared.play(.flutter, volume: 0.5) }
    }

    /// A tap on a visitor: it hops, curls up, hides or flutters. True if she tapped one.
    func tapVisitor(_ p: CGPoint) -> Bool {
        for i in visitors.indices {
            let v = visitors[i]
            let mid = v.kind.flies ? v.p : CGPoint(x: v.p.x, y: v.p.y - v.kind.stickerHeight * 0.4)
            guard hypot(mid.x - p.x, mid.y - p.y) < v.kind.reach else { continue }
            guard time - v.poked > 0.6 else { return true }
            visitors[i].poked = time
            switch v.kind {
            case .bunny, .frog: Sound.shared.play(.boing, volume: 0.6)
            case .snail, .hedgehog: GardenSound.shared.play(.squeak, volume: 0.7)
            case .bluebird, .hummingbird, .owl: GardenSound.shared.play(.chirp, volume: 0.8)
            }
            Sound.shared.tap()
            sparkle(at: mid, count: 6)
            return true
        }
        return false
    }
}

// MARK: - Drawing visitors and twinkles

enum GardenVisitorPainter {
    static func draw(_ g: GraphicsContext, _ v: GVisitor, time t: CGFloat, night: CGFloat, nowTime: Double? = nil) {
        let since = nowTime.map { CGFloat($0 - v.poked) } ?? 10
        let react = since >= 0 && since < 0.6 ? sin(since / 0.6 * .pi) : 0
        var c = g
        c.translateBy(x: v.p.x, y: v.p.y)
        c.scaleBy(x: v.facing < 0 ? -1 : 1, y: 1)
        switch v.kind {
        case .bunny: bunny(c, v, t, react)
        case .frog: frog(c, v, t, react)
        case .snail: snail(c, v, t, react)
        case .hedgehog: hedgehog(c, v, t, react)
        case .bluebird: bluebird(c, v, t, react)
        case .owl: owl(c, v, t, react)
        case .hummingbird: hummingbird(c, v, t, react)
        }
    }

    /// Little four-point stars that come and go around a special plant (see `Twinkles`).
    static func twinkles(_ g: GraphicsContext, around p: CGPoint, radius: CGFloat, time t: CGFloat, count: Int, alpha: Double) {
        Twinkles.draw(g, around: p, radius: radius, time: t, count: count, alpha: alpha)
    }

    private static func eye(_ c: GraphicsContext, _ p: CGPoint, _ r: CGFloat) {
        c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(GRGB(0x2A2020).color))
        c.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.2, y: p.y - r * 0.75, width: r * 0.6, height: r * 0.6)), with: .color(.white))
    }

    private static func oval(_ c: GraphicsContext, _ r: CGRect, _ col: GRGB, light: Bool = true) {
        if light {
            let grad = Gradient(colors: [col.shade(0.18).color, col.color, col.shade(-0.22).color])
            c.fill(Path(ellipseIn: r), with: .radialGradient(grad, center: CGPoint(x: r.midX + r.width * 0.15, y: r.minY + r.height * 0.3),
                                                             startRadius: 0, endRadius: max(r.width, r.height) * 0.75))
        } else {
            c.fill(Path(ellipseIn: r), with: .color(col.color))
        }
    }

    // MARK: The animals (each faces right, feet at the origin)

    private static func bunny(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let hop = v.moving ? abs(sin(v.walk / 22)) * 16 : 0
        c.translateBy(x: 0, y: -hop - react * 34)
        let fur = GRGB(0xC9A27E)
        let nibble = v.moving ? 0 : sin(t * 9 + CGFloat(v.seed)) * 1.4
        // tail, back foot, body
        oval(c, CGRect(x: -30, y: -30, width: 14, height: 14), GRGB(0xFFFBF4))
        oval(c, CGRect(x: -18, y: -10, width: 26, height: 10), fur.shade(-0.1))
        oval(c, CGRect(x: -24, y: -40, width: 42, height: 36), fur)
        oval(c, CGRect(x: -10, y: -26, width: 20, height: 18), GRGB(0xF3E2CF), light: false)
        oval(c, CGRect(x: 8, y: -10, width: 12, height: 9), fur.shade(-0.05))
        // ears (one flops while she stays)
        let flop = v.moving ? 0.1 : 0.18 + 0.12 * sin(t * 0.9 + CGFloat(v.seed))
        for (k, o) in [(-1.0, 0.0), (1.0, 7.0)] as [(CGFloat, CGFloat)] {
            var e = c
            e.translateBy(x: 14 + o, y: -54)
            e.rotate(by: .radians(Double(k < 0 ? -0.25 - flop : -0.05)))
            oval(e, CGRect(x: -5, y: -30, width: 11, height: 32), fur)
            e.fill(Path(ellipseIn: CGRect(x: -2.5, y: -25, width: 6, height: 23)), with: .color(GRGB(0xFFB3C7).color))
        }
        // head
        oval(c, CGRect(x: 4, y: -66 + nibble * 0.3, width: 30, height: 27), fur)
        eye(c, CGPoint(x: 24, y: -55), 3)
        c.fill(Path(ellipseIn: CGRect(x: 30, y: -48 + nibble, width: 6, height: 4.5)), with: .color(GRGB(0xFF8FB0).color))
        c.fill(Path(ellipseIn: CGRect(x: 15, y: -49, width: 7, height: 4)), with: .color(GRGB(0xFFB3C7).color(0.6)))
    }

    private static func frog(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let hop = v.moving ? abs(sin(v.walk / 26)) * 22 : 0
        c.translateBy(x: 0, y: -hop - react * 40)
        let green = GRGB(0x63BE45)
        // back leg, body, belly, front foot
        oval(c, CGRect(x: -22, y: -16, width: 22, height: 16), green.shade(-0.12))
        oval(c, CGRect(x: -20, y: -30, width: 40, height: 28), green)
        oval(c, CGRect(x: -4, y: -16, width: 22, height: 14), GRGB(0xDDF2B8), light: false)
        oval(c, CGRect(x: 8, y: -6, width: 14, height: 7), green.shade(-0.08))
        // throat puffs
        let puff = v.moving ? 0 : max(0, sin(t * 3 + CGFloat(v.seed))) * 5
        if puff > 0.5 { oval(c, CGRect(x: 6 - puff * 0.2, y: -14, width: 14 + puff, height: 9 + puff), GRGB(0xF4FAD8), light: false) }
        // eye bumps
        for x in [-4.0, 10.0] as [CGFloat] {
            oval(c, CGRect(x: x - 7, y: -40, width: 14, height: 14), green)
            c.fill(Path(ellipseIn: CGRect(x: x - 5, y: -38, width: 10, height: 10)), with: .color(.white))
            eye(c, CGPoint(x: x + 1, y: -33), 3)
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: 4, y: -20))
        mouth.addQuadCurve(to: CGPoint(x: 20, y: -22), control: CGPoint(x: 13, y: -16))
        c.stroke(mouth, with: .color(green.shade(-0.5).color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: 0, y: -22, width: 6, height: 4)), with: .color(GRGB(0xFF9AB5).color(0.6)))
    }

    private static func snail(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        let c = g
        let hide = react
        let stretch = v.moving ? 1 + 0.08 * sin(v.walk / 3) : 1
        // body (pulls in when she taps)
        let len = 40 * stretch * (1 - 0.6 * hide)
        var body = Path()
        body.move(to: CGPoint(x: -18, y: 0))
        body.addLine(to: CGPoint(x: -18 + len, y: 0))
        body.addQuadCurve(to: CGPoint(x: -18 + len - 8, y: -12), control: CGPoint(x: -18 + len + 4, y: -12))
        body.addLine(to: CGPoint(x: -12, y: -7))
        body.closeSubpath()
        c.fill(body, with: .color(GRGB(0xE6D2B0).color))
        if hide < 0.5 {
            let hx = -18 + len - 6
            for (o, l) in [(-2.0, 13.0), (3.0, 16.0)] as [(CGFloat, CGFloat)] {
                var st = Path()
                let wob = sin(t * 2 + o) * 2
                st.move(to: CGPoint(x: hx + o, y: -10))
                st.addLine(to: CGPoint(x: hx + o + 3 + wob, y: -10 - l))
                c.stroke(st, with: .color(GRGB(0xCDB58E).color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                eye(c, CGPoint(x: hx + o + 3 + wob, y: -10 - l), 2.2)
            }
            var smile = Path()
            smile.move(to: CGPoint(x: hx - 2, y: -5))
            smile.addQuadCurve(to: CGPoint(x: hx + 4, y: -5), control: CGPoint(x: hx + 1, y: -2.5))
            c.stroke(smile, with: .color(GRGB(0x8A7050).color), lineWidth: 1)
        }
        // shell with a spiral
        let shell = GRGB(0xF2A65A)
        oval(c, CGRect(x: -20, y: -34, width: 30, height: 30), shell)
        var sp = Path()
        for k in 0...40 {
            let a = CGFloat(k) / 40 * 4 * .pi
            let r = 12 * (1 - CGFloat(k) / 44)
            let pt = CGPoint(x: -5 + cos(a + .pi) * r, y: -19 + sin(a + .pi) * r)
            if k == 0 { sp.move(to: pt) } else { sp.addLine(to: pt) }
        }
        c.stroke(sp, with: .color(shell.shade(-0.45).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private static func hedgehog(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let curl = react
        let bob = v.moving ? abs(sin(v.walk / 7)) * 2 : 0
        c.translateBy(x: 0, y: -bob)
        let spikeC = GRGB(0x7A5A40)
        // spikes around the back
        var spikes = Path()
        let n = 13
        for k in 0...n * 2 {
            let a = CGFloat.pi + CGFloat(k) / CGFloat(n * 2) * (CGFloat.pi * (1 + curl * 0.9))
            let r: CGFloat = (k % 2 == 0 ? 22 : 31) * (1 - 0.15 * curl)
            let pt = CGPoint(x: -4 + cos(a) * r * 1.15, y: -16 + sin(a) * r)
            if k == 0 { spikes.move(to: pt) } else { spikes.addLine(to: pt) }
        }
        spikes.closeSubpath()
        c.fill(spikes, with: .linearGradient(Gradient(colors: [spikeC.shade(0.15).color, spikeC.shade(-0.25).color]),
                                             startPoint: CGPoint(x: 0, y: -46), endPoint: CGPoint(x: 0, y: 0)))
        if curl < 0.6 {
            // face
            var face = Path()
            face.move(to: CGPoint(x: 10, y: -28))
            face.addQuadCurve(to: CGPoint(x: 34, y: -10), control: CGPoint(x: 28, y: -26))
            face.addQuadCurve(to: CGPoint(x: 10, y: -2), control: CGPoint(x: 22, y: 0))
            face.closeSubpath()
            c.fill(face, with: .color(GRGB(0xEBD3AE).color))
            let sniff = v.moving ? 0 : sin(t * 7 + CGFloat(v.seed)) * 0.8
            c.fill(Path(ellipseIn: CGRect(x: 31 + sniff, y: -14, width: 6, height: 5)), with: .color(GRGB(0x2A2020).color))
            eye(c, CGPoint(x: 21, y: -18), 2.4)
            c.fill(Path(ellipseIn: CGRect(x: 15, y: -14, width: 6, height: 3.5)), with: .color(GRGB(0xFFA7B8).color(0.6)))
            for x in [-12.0, 8.0] as [CGFloat] {
                c.fill(Path(ellipseIn: CGRect(x: x, y: -4, width: 8, height: 5)), with: .color(GRGB(0xC9AE88).color))
            }
        }
    }

    private static func bluebird(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let flying = v.moving
        if !flying { c.translateBy(x: 0, y: -react * 12) }
        let blue = GRGB(0x4F8FE0)
        if !flying {
            for x in [-3.0, 3.0] as [CGFloat] {
                var leg = Path()
                leg.move(to: CGPoint(x: x, y: -6))
                leg.addLine(to: CGPoint(x: x, y: 0))
                c.stroke(leg, with: .color(GRGB(0xE0904A).color), lineWidth: 1.6)
            }
        }
        // tail
        var tail = Path()
        tail.move(to: CGPoint(x: -10, y: -14))
        tail.addLine(to: CGPoint(x: -26, y: -20))
        tail.addLine(to: CGPoint(x: -24, y: -10))
        tail.closeSubpath()
        c.fill(tail, with: .color(blue.shade(-0.2).color))
        oval(c, CGRect(x: -14, y: -24, width: 28, height: 19), blue)
        oval(c, CGRect(x: -4, y: -16, width: 16, height: 11), GRGB(0xFF9F5E), light: false)
        oval(c, CGRect(x: 2, y: -34, width: 18, height: 17), blue)
        eye(c, CGPoint(x: 14, y: -27), 2.2)
        var beak = Path()
        beak.move(to: CGPoint(x: 19, y: -28))
        beak.addLine(to: CGPoint(x: 26, y: -25.5))
        beak.addLine(to: CGPoint(x: 19, y: -23))
        beak.closeSubpath()
        c.fill(beak, with: .color(GRGB(0xF6B53A).color))
        // wing: flaps in the air, flicks when tapped
        let flap = flying ? sin(t * 22) : (react > 0 ? sin(t * 30) * react : 0)
        var w = c
        w.translateBy(x: -2, y: -18)
        w.rotate(by: .radians(Double(-0.2 - flap * 0.9)))
        oval(w, CGRect(x: -12, y: -5, width: 20, height: 10), blue.shade(-0.25))
    }

    private static func owl(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let flying = v.moving
        let brown = GRGB(0x9C7A58)
        if flying {
            let flap = sin(t * 9)
            for side in [-1.0, 1.0] as [CGFloat] {
                var w = c
                w.translateBy(x: side * 12, y: -30)
                w.rotate(by: .radians(Double(side * (0.4 + flap * 0.5))))
                oval(w, CGRect(x: side < 0 ? -34 : 0, y: -8, width: 34, height: 16), brown.shade(-0.18))
            }
        }
        // body, belly with little v marks
        oval(c, CGRect(x: -20, y: -54, width: 40, height: 54), brown)
        oval(c, CGRect(x: -12, y: -34, width: 24, height: 30), GRGB(0xEEDCBF), light: false)
        for (x, y) in [(-5.0, -26.0), (5.0, -26.0), (0.0, -18.0), (-6.0, -12.0), (6.0, -12.0)] as [(CGFloat, CGFloat)] {
            var m = Path()
            m.move(to: CGPoint(x: x - 3, y: y))
            m.addLine(to: CGPoint(x: x, y: y + 2.5))
            m.addLine(to: CGPoint(x: x + 3, y: y))
            c.stroke(m, with: .color(brown.shade(-0.2).color), lineWidth: 1.2)
        }
        // ear tufts
        for side in [-1.0, 1.0] as [CGFloat] {
            var tuft = Path()
            tuft.move(to: CGPoint(x: side * 8, y: -52))
            tuft.addLine(to: CGPoint(x: side * 20, y: -64))
            tuft.addLine(to: CGPoint(x: side * 18, y: -48))
            tuft.closeSubpath()
            c.fill(tuft, with: .color(brown.shade(-0.12).color))
        }
        // big eyes that blink now and then (and when she taps)
        let blink = react > 0.2 || (t + CGFloat(v.seed % 7)).truncatingRemainder(dividingBy: 4.2) < 0.15
        for side in [-1.0, 1.0] as [CGFloat] {
            let ec = CGPoint(x: side * 9, y: -40)
            c.fill(Path(ellipseIn: CGRect(x: ec.x - 9, y: ec.y - 9, width: 18, height: 18)), with: .color(GRGB(0xFFF6E0).color))
            if blink {
                var lid = Path()
                lid.move(to: CGPoint(x: ec.x - 6, y: ec.y))
                lid.addQuadCurve(to: CGPoint(x: ec.x + 6, y: ec.y), control: CGPoint(x: ec.x, y: ec.y + 4))
                c.stroke(lid, with: .color(GRGB(0x2A2020).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            } else {
                c.fill(Path(ellipseIn: CGRect(x: ec.x - 6, y: ec.y - 6, width: 12, height: 12)), with: .color(GRGB(0xFFC233).color))
                eye(c, CGPoint(x: ec.x + 1, y: ec.y), 3.6)
            }
        }
        var beak = Path()
        beak.move(to: CGPoint(x: -3, y: -33))
        beak.addLine(to: CGPoint(x: 3, y: -33))
        beak.addLine(to: CGPoint(x: 0, y: -27))
        beak.closeSubpath()
        c.fill(beak, with: .color(GRGB(0xF0A23A).color))
        if !flying {
            for x in [-8.0, 4.0] as [CGFloat] {
                c.fill(Path(roundedRect: CGRect(x: x, y: -4, width: 5, height: 5), cornerRadius: 2), with: .color(GRGB(0xF0A23A).color))
            }
        }
    }

    private static func hummingbird(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        c.translateBy(x: 0, y: -react * 10)
        c.rotate(by: .radians(-0.25))
        // wings: a fast blur
        let flap = sin(t * 60)
        for k in 0..<2 {
            var w = c
            w.translateBy(x: -2, y: -4)
            w.rotate(by: .radians(Double(-1.2 + flap * 0.7 + CGFloat(k) * 0.5)))
            w.fill(Path(ellipseIn: CGRect(x: -3, y: -26, width: 9, height: 26)), with: .color(.white.opacity(k == 0 ? 0.7 : 0.4)))
            w.stroke(Path(ellipseIn: CGRect(x: -3, y: -26, width: 9, height: 26)), with: .color(GRGB(0x9FC0D6).color(0.5)), lineWidth: 0.8)
        }
        var tail = Path()
        tail.move(to: CGPoint(x: -12, y: 0))
        tail.addLine(to: CGPoint(x: -24, y: 6))
        tail.addLine(to: CGPoint(x: -20, y: -2))
        tail.closeSubpath()
        c.fill(tail, with: .color(GRGB(0x2F9A6E).color))
        oval(c, CGRect(x: -14, y: -7, width: 24, height: 13), GRGB(0x3FC08A))
        oval(c, CGRect(x: 2, y: -2, width: 9, height: 7), GRGB(0xFF4FA6), light: false)
        oval(c, CGRect(x: 4, y: -12, width: 13, height: 12), GRGB(0x3FC08A))
        eye(c, CGPoint(x: 12, y: -7), 1.8)
        var beak = Path()
        beak.move(to: CGPoint(x: 16, y: -6))
        beak.addLine(to: CGPoint(x: 32, y: -4))
        c.stroke(beak, with: .color(GRGB(0x3A3030).color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
}
