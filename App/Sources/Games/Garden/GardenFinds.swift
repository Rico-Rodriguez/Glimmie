import SwiftUI

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
            case .pumpkin: GardenPlants.drawCrop(g, kind: k, variant: v, at: CGPoint(x: 0, y: -10), size: 1.45, rot: 0, giant: true)
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

enum VisitorWish: Equatable {
    case plant(PlantKind)
    case anyFlower
    case raindrop
    case decor(DecorKind)
    case moon
}

enum GVisitorKind: String, CaseIterable, Codable, Equatable, Hashable {
    case bunny, frog, snail, hedgehog, bluebird, owl, hummingbird

    var flies: Bool { self == .bluebird || self == .owl || self == .hummingbird }
    var behind: Bool { self == .bunny || self == .hedgehog || self == .owl }

    var wish: VisitorWish {
        switch self {
        case .bunny: return .plant(.carrot)
        case .hedgehog: return .plant(.pumpkin)
        case .hummingbird: return .anyFlower
        case .frog, .snail: return .raindrop
        case .bluebird: return .decor(.birdhouse)
        case .owl: return .moon
        }
    }

    var speed: CGFloat {
        switch self {
        case .bunny: return 150
        case .frog: return 120
        case .snail: return 16
        case .hedgehog: return 65
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

    var reach: CGFloat {
        switch self {
        case .snail, .hummingbird: return 48
        default: return 58
        }
    }
}

struct GVisitor {
    enum State { case arriving, staying, leaving }
    var kind: GVisitorKind
    var p: CGPoint
    var target = CGPoint.zero
    var state = State.arriving
    var arrivedAt: Double = 0
    var stayUntil: Double = 0
    var facing: CGFloat
    var walk: CGFloat = 0
    var poked: Double = -10
    var seed = Int.random(in: 0..<1000)
    var plot: Int?
    var decorID: Int?
    var fulfilled = false
    var wearingCrown = false
    var crownColors: [GRGB] = []

    var pos: CGPoint { p }
    var moving: Bool { state != .staying }

    func bubbleCenter(time t: CGFloat) -> CGPoint {
        let bob = sin(t * 2.8 + CGFloat(seed)) * 4
        let lift: CGFloat = kind.flies ? 58 : kind.stickerHeight + 36
        let bx = max(110, min(914, p.x + facing * 14))
        let by = max(116, p.y - lift + bob)
        return CGPoint(x: bx, y: by)
    }
}

// MARK: - Visitors and special plants in the simulation

extension GardenSim {
    static let specialChance = 0.25

    static func rollVariant() -> Int {
        Int.random(in: 0..<6) + (Double.random(in: 0..<1) < specialChance ? Plant.specialVariant : 0)
    }

    func discover(_ f: GardenFind, at p: CGPoint) {
        guard !demo || StickerBook.shared.demo else { return }
        guard !queuedStickers.contains(f), !StickerBook.shared.has(game: GardenSim.gameID, id: f.rawValue) else { return }
        queuedStickers.insert(f)
        sparkle(at: p, count: 18)
        enqueueEffect(.discoverSticker(f, at: p))
    }

    func earnCoins(_ amount: Int, from p: CGPoint) {
        guard amount > 0 else { return }
        guard !demo || Coins.shared.demo else { return }
        enqueueEffect(.earnCoins(amount: amount, from: p))
    }

    func stepFinds(_ dt: CGFloat) {
        if Int(time * 2) != Int((time - Double(dt)) * 2) {
            for i in plots.indices {
                switch plots[i].stage {
                case .ripe(let ripe) where ripe.isSpecial && ripe.kind != .pumpkin:
                    discover(.special(ripe.kind), at: head(plot: i) ?? CGPoint(x: GGeo.plotX[i], y: GGeo.soilY - 60))
                case .growing(let growing) where growing.growth >= 0.97 && growing.isSpecial && growing.kind != .pumpkin:
                    discover(.special(growing.kind), at: head(plot: i) ?? CGPoint(x: GGeo.plotX[i], y: GGeo.soilY - 60))
                default:
                    break
                }
            }
        }
        stepVisitors(dt)
    }

    private func ripe(_ k: PlantKind) -> Int? {
        plots.indices.first { i in
            guard !plots[i].held else { return false }
            switch plots[i].stage {
            case .ripe(let r): return r.kind == k
            case .growing(let g): return g.kind == k && g.growth >= 0.9
            case .empty: return false
            }
        }
    }

    func inventoryHas(_ k: PlantKind) -> Bool {
        inventory.contains { item in
            switch item.source {
            case .plant(let kind, _, _):
                return kind == k
            case .hybrid(let hybrid, _):
                return k == .pumpkin && hybrid == .crystalPumpkin
            }
        }
    }

    func inventoryHasAnyFlower() -> Bool {
        inventory.contains(where: \.isFlower)
    }

    @discardableResult
    func consumeInventoryItem(for wish: VisitorWish) -> HarvestItem? {
        let index: Int?
        switch wish {
        case .plant(let k):
            index = inventory.firstIndex { item in
                if case .plant(let kind, _, _) = item.source { return kind == k }
                return false
            } ?? inventory.firstIndex { item in
                if case .hybrid(let hybrid, _) = item.source { return k == .pumpkin && hybrid == .crystalPumpkin }
                return false
            }
        case .anyFlower:
            index = inventory.firstIndex(where: \.isFlower)
        case .raindrop, .decor, .moon:
            return nil
        }
        guard let idx = index else { return nil }
        let removed = inventory.remove(at: idx)
        markUIStateDirty()
        return removed
    }

    private func spot(for k: GVisitorKind) -> (CGPoint, Int?, Int?)? {
        let day = night < 0.5
        let wet = rain > 0.5
        func clampLawnX(_ x: CGFloat) -> CGFloat { max(130, min(770, x)) }
        func clampBedX(_ x: CGFloat) -> CGFloat { max(GGeo.bedLeft + 70, min(GGeo.bedRight - 70, x)) }
        switch k {
        case .bunny:
            if let i = ripe(.carrot) {
                let x = clampLawnX(GGeo.plotX[i] + (GGeo.plotX[i] < 440 ? 48 : -48))
                return (CGPoint(x: x, y: GGeo.yardY + 8), i, nil)
            }
            if inventoryHas(.carrot) {
                return (CGPoint(x: clampLawnX(CGFloat.random(in: 200...680)), y: GGeo.yardY + 8), nil, nil)
            }
            return nil
        case .frog:
            let bath = decor.first { $0.kind == .birdbath && $0.water > 0.3 }
            guard wet || bath != nil else { return nil }
            if let b = bath, !wet { return (CGPoint(x: clampLawnX(b.x + 54), y: b.baseY + 4), nil, nil) }
            let x = clampBedX(CGFloat.random(in: 180...720))
            return (CGPoint(x: x, y: surface(x)), nil, nil)
        case .snail:
            guard wet || wetAt(436, span: 85) > 0.55 else { return nil }
            let left = Bool.random()
            let x = clampBedX(left ? GGeo.bedLeft + CGFloat.random(in: 90...150) : GGeo.bedRight - CGFloat.random(in: 90...150))
            return (CGPoint(x: x, y: surface(x)), nil, nil)
        case .hedgehog:
            guard night > 0.5 || ripe(.pumpkin) != nil else { return nil }
            let x = ripe(.pumpkin).map { GGeo.plotX[$0] - 54 } ?? CGFloat.random(in: 200...700)
            return (CGPoint(x: clampLawnX(x), y: GGeo.yardY + 8), nil, nil)
        case .bluebird:
            guard day, !wet else { return nil }
            let homes = decor.filter { $0.kind == .birdhouse || $0.kind == .birdbath }
            guard let d = homes.randomElement() else { return nil }
            let top = d.kind == .birdhouse ? d.baseY - d.kind.size.height + 8 : d.baseY - 84
            return (CGPoint(x: d.x + (d.kind == .birdhouse ? 0 : 28), y: top), nil, d.id)
        case .owl:
            guard night > 0.6 else { return nil }
            let x = (CGFloat.random(in: 180...760) / 30).rounded() * 30 + 9
            return (CGPoint(x: x, y: GGeo.fenceTopY), nil, nil)
        case .hummingbird:
            guard day, !wet else { return nil }
            let flowers = plots.indices.filter { i in
                guard let pl = plots[i].plant, pl.growth >= 0.95 else { return false }
                return pl.effectiveIsFlower
            }
            guard let i = flowers.randomElement(), let h = head(plot: i) else { return nil }
            return (CGPoint(x: h.x + 30, y: h.y - 8), i, nil)
        }
    }

    private func stepVisitors(_ dt: CGFloat) {
        if time > nextVisit && visitors.count < 2 {
            nextVisit = time + Double.random(in: 10...20)
            let book = StickerBook.shared
            var options: [(GVisitorKind, (CGPoint, Int?, Int?))] = []
            for k in GVisitorKind.allCases where !visitors.contains(where: { $0.kind == k }) {
                guard let s = spot(for: k) else { continue }
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
                    v.target = CGPoint(x: h.x + 30 * (v.target.x >= h.x ? 1 : -1), y: h.y - 8)
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
                    v.arrivedAt = time
                    v.stayUntil = time + Double.random(in: 12...20)
                    if v.kind == .snail { v.stayUntil += 10 }
                } else {
                    v.p.x += dx / d * stepLen
                    v.p.y += dy / d * stepLen
                    v.walk += stepLen
                    if abs(dx) > 2 { v.facing = dx > 0 ? 1 : -1 }
                    if !v.kind.flies && !v.kind.behind { v.p.y = surface(v.p.x) }
                }
            case .staying:
                var gone = false
                if v.kind == .bunny, let pl = v.plot, !v.fulfilled {
                    gone = plots[pl].plant?.kind != .carrot
                }
                if v.kind == .hummingbird, let pl = v.plot, !v.fulfilled {
                    gone = plots[pl].plant == nil
                }
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
                    let t = CGFloat(time)
                    let side: CGFloat = v.target.x >= h.x ? 1 : -1
                    v.facing = -side
                    v.p = CGPoint(x: h.x + 30 * side + sin(t * 1.3) * 6, y: h.y - 8 + sin(t * 2.1) * 5)
                }
                if time > v.stayUntil || gone { leave(&v) }
            }
            visitors[i] = v
        }
    }

    private func inventorySatisfies(_ wish: VisitorWish) -> Bool {
        switch wish {
        case .plant(let kind): return inventoryHas(kind)
        case .anyFlower: return inventoryHasAnyFlower()
        case .raindrop, .decor, .moon: return false
        }
    }

    func wishSatisfied(_ wish: VisitorWish) -> Bool {
        switch wish {
        case .plant(let kind): return inventoryHas(kind)
        case .anyFlower: return inventoryHasAnyFlower()
        case .raindrop: return weather == .rain || rain > 0.4 || wetAt(436, span: 85) > 0.5
        case .decor(let kind):
            return decor.contains { $0.kind == kind || (kind == .birdhouse && $0.kind == .birdbath) }
        case .moon: return weather == .night || night > 0.5
        }
    }

    @discardableResult
    func feedVisitorFromBasket(at p: CGPoint) -> Bool {
        guard let i = visitorHit(p) else { return false }
        let v = visitors[i]
        guard !v.fulfilled, inventorySatisfies(v.kind.wish) else { return false }
        guard consumeInventoryItem(for: v.kind.wish) != nil else { return false }
        fulfillVisitor(at: i)
        enqueueEffect(.save)
        return true
    }

    private func arrive(_ k: GVisitorKind, at s: (CGPoint, Int?, Int?)) {
        let fromLeft = s.0.x <= 460
        let startX: CGFloat = fromLeft ? -80 : 1104
        var start = CGPoint(x: startX, y: s.0.y)
        if k.flies { start.y = max(120, s.0.y - 240) }
        if k == .snail { start = CGPoint(x: s.0.x < 440 ? GGeo.bedLeft - 36 : GGeo.bedRight + 36, y: s.0.y) }
        if !k.flies && !k.behind { start.y = surface(max(GGeo.bedLeft, min(GGeo.bedRight, start.x))) }
        var v = GVisitor(kind: k, p: start, facing: fromLeft ? 1 : -1)
        v.target = s.0
        v.plot = s.1
        v.decorID = s.2
        if k == .snail { v.facing = s.0.x < 440 ? 1 : -1 }
        visitors.append(v)
        if k.flies { GardenSound.shared.play(.flutter, volume: 0.6) }
    }

    private func leave(_ v: inout GVisitor) {
        v.state = .leaving
        let right = v.p.x > 460
        if v.kind == .snail {
            v.target = CGPoint(x: right ? GGeo.bedRight + 40 : GGeo.bedLeft - 40, y: v.p.y)
        } else {
            v.target = CGPoint(x: right ? 1104 : -80, y: v.kind.flies ? max(100, v.p.y - 220) : v.p.y)
        }
        v.facing = right ? 1 : -1
        if v.kind.flies { GardenSound.shared.play(.flutter, volume: 0.5) }
    }

    func playVisitorSound(_ kind: GVisitorKind) {
        switch kind {
        case .bunny, .frog: Sound.shared.play(.boing, volume: 0.65)
        case .snail, .hedgehog: GardenSound.shared.play(.squeak, volume: 0.75)
        case .bluebird, .hummingbird, .owl: GardenSound.shared.play(.chirp, volume: 0.8)
        }
    }

    func fulfillVisitor(at index: Int) {
        guard index < visitors.count, !visitors[index].fulfilled else { return }
        visitors[index].fulfilled = true
        visitors[index].poked = time
        visitors[index].stayUntil = max(visitors[index].stayUntil, time + 3.5)
        let v = visitors[index]
        let origin = CGPoint(x: v.pos.x, y: v.pos.y - v.kind.stickerHeight * 0.45)
        playVisitorSound(v.kind)
        Sound.shared.play(.sparkle, volume: 0.45)
        enqueueEffect(.haptic)
        heartBurst(at: origin, count: 6)
        sparkle(at: origin, count: 10)
        if let f = GardenFind(rawValue: v.kind.rawValue) {
            discover(f, at: origin)
        }
        earnCoins(3, from: v.pos)
    }

    func fulfillRainVisitors() {
        for i in visitors.indices where visitors[i].state == .staying && !visitors[i].fulfilled {
            if visitors[i].kind.wish == .raindrop {
                fulfillVisitor(at: i)
            }
        }
    }

    func visitorHit(_ p: CGPoint) -> Int? {
        let t = CGFloat(time)
        for i in visitors.indices {
            let v = visitors[i]
            let mid = v.kind.flies ? v.p : CGPoint(x: v.p.x, y: v.p.y - v.kind.stickerHeight * 0.4)
            if hypot(mid.x - p.x, mid.y - p.y) < v.kind.reach { return i }
            if v.state == .staying && !v.fulfilled {
                let bc = v.bubbleCenter(time: t)
                if hypot(bc.x - p.x, bc.y - p.y) < 38 { return i }
            }
        }
        return nil
    }

    func tapVisitor(_ p: CGPoint) -> Bool {
        guard let i = visitorHit(p) else { return false }
        if hasCraftedCrown {
            return placeCrownOnVisitor(at: i)
        }
        let v = visitors[i]
        if !v.fulfilled {
            if wishSatisfied(v.kind.wish) {
                switch v.kind.wish {
                case .plant, .anyFlower:
                    guard consumeInventoryItem(for: v.kind.wish) != nil else { break }
                    fulfillVisitor(at: i)
                    enqueueEffect(.save)
                    return true
                case .raindrop, .decor, .moon:
                    fulfillVisitor(at: i)
                    return true
                }
            }
            // Playful wiggle without awarding free coins before the wish is satisfied.
            guard time - v.poked > 0.45 else { return true }
            visitors[i].poked = time
            playVisitorSound(v.kind)
            enqueueEffect(.haptic)
            return true
        }
        guard time - v.poked > 0.55 else { return true }
        visitors[i].poked = time
        let mid = v.kind.flies ? v.p : CGPoint(x: v.p.x, y: v.p.y - v.kind.stickerHeight * 0.4)
        playVisitorSound(v.kind)
        enqueueEffect(.haptic)
        heartBurst(at: mid, count: 3)
        sparkle(at: mid, count: 6)
        return true
    }
}

// MARK: - Drawing visitors, flower crowns, thought bubbles, and twinkles

enum GardenVisitorPainter {
    static func drawFlowerCrown(_ ctx: GraphicsContext, at p: CGPoint, colors: [GRGB], scale: CGFloat = 1) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.scaleBy(x: scale, y: scale)

        let palette = colors.isEmpty
            ? [GRGB(0xFF7CB4), GRGB(0xFFD24A), GRGB(0xC89EFF), GRGB(0x7FE3B0), GRGB(0xFF9AC8)]
            : colors

        // Leafy woven headband arc
        var vine = Path()
        vine.move(to: CGPoint(x: -17, y: 3))
        vine.addQuadCurve(to: CGPoint(x: 17, y: 3), control: CGPoint(x: 0, y: -7))
        g.stroke(vine, with: .color(GRGB(0x3B7C38).color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        g.stroke(vine, with: .color(GRGB(0x63BD52).color), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))

        // Tiny protruding leaves
        for (lx, ly, ang) in [(-15.0, 2.0, -2.6), (15.0, 2.0, -0.5), (-6.0, -3.5, -2.1), (6.0, -3.5, -1.0)] as [(CGFloat, CGFloat, CGFloat)] {
            GardenPlants.leaf(g, at: CGPoint(x: lx, y: ly), angle: ang, length: 9, width: 3.6, color: GRGB(0x66BD55))
        }

        // 5 plump miniature blooms across the crown
        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (-13, 1.5, 4.6), (-6.5, -2.2, 5.2), (0, -3.8, 5.8), (6.5, -2.2, 5.2), (13, 1.5, 4.6)
        ]
        for (idx, sp) in spots.enumerated() {
            let col = palette[idx % palette.count]
            let r = sp.2
            for k in 0..<5 {
                let a = CGFloat(k) / 5 * 2 * .pi
                let px = sp.0 + cos(a) * r * 0.62
                let py = sp.1 + sin(a) * r * 0.62
                let pr = r * 0.56
                let pet = Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2))
                g.fill(pet, with: .color(col.color))
                g.stroke(pet, with: .color(col.shade(-0.4).color(0.75)), lineWidth: 0.9)
            }
            let centerR = r * 0.44
            g.fill(
                Path(ellipseIn: CGRect(x: sp.0 - centerR, y: sp.1 - centerR, width: centerR * 2, height: centerR * 2)),
                with: .color(Color(hex: 0xFFE266))
            )
        }
    }

    static func drawSeatedCustomer(_ g: GraphicsContext, kind: GVisitorKind, at p: CGPoint, time t: CGFloat, cheering: Bool) {
        var v = GVisitor(kind: kind, p: p, facing: 1, seed: kind.rawValue.count * 13)
        v.state = .staying
        v.walk = 0
        v.poked = cheering ? Double(t) - 0.15 : -10
        var cg = g
        let bounce: CGFloat = cheering ? abs(sin(t * 9.5)) * 12 : sin(t * 2.4) * 2
        cg.translateBy(x: p.x, y: p.y - bounce)
        let scale: CGFloat = kind == .hummingbird ? 1.55 : (kind == .snail || kind == .frog ? 1.45 : 1.25)
        cg.scaleBy(x: scale, y: scale)
        v.p = .zero
        draw(cg, v, time: t, night: 0, nowTime: nil)
        if cheering {
            let cheekY: CGFloat = kind == .bunny ? -48 : (kind == .owl ? -34 : -20)
            let cheekX: CGFloat = kind == .owl ? 12 : 16
            cg.fill(
                Path(ellipseIn: CGRect(x: cheekX - 6, y: cheekY - 4, width: 12, height: 8)),
                with: .color(Color(hex: 0xFF7CA8, alpha: 0.78))
            )
        }
    }

    static func drawPicnicCritter(_ g: GraphicsContext, _ pc: PicnicCritter, time t: CGFloat, nowTime: Double) {
        let munching = pc.state == .munching
        let moving = pc.state == .hoppingIn || pc.state == .hoppingOut
        var v = GVisitor(kind: pc.kind, p: pc.p, facing: pc.facing, seed: pc.id * 17)
        v.state = moving ? .arriving : .staying
        v.walk = pc.walk
        v.poked = pc.poked
        v.wearingCrown = pc.wearingCrown
        v.crownColors = pc.crownColors

        var cg = g
        if munching {
            let chewBob = abs(sin(t * 7.5 + CGFloat(pc.id))) * 4.5
            cg.translateBy(x: 0, y: -chewBob)
        }
        draw(cg, v, time: t, night: 0, nowTime: nil)

        // Animated rosy munching cheeks when eating on the picnic blanket
        if munching || pc.state == .happy {
            let glow = 0.72 + 0.25 * sin(t * 9 + CGFloat(pc.id))
            let cheekY: CGFloat
            let cheekX: CGFloat
            switch pc.kind {
            case .bunny: cheekX = pc.facing * 18; cheekY = -48
            case .hedgehog: cheekX = pc.facing * 18; cheekY = -14
            case .frog: cheekX = pc.facing * 6; cheekY = -22
            case .bluebird: cheekX = pc.facing * 12; cheekY = -24
            default: cheekX = pc.facing * 10; cheekY = -28
            }
            let r: CGFloat = munching ? 6.5 : 5.2
            cg.fill(
                Path(ellipseIn: CGRect(x: pc.p.x + cheekX - r, y: pc.p.y + cheekY - r * 0.68, width: r * 2, height: r * 1.36)),
                with: .color(Color(hex: 0xFF7CA8, alpha: Double(glow)))
            )
        }
        _ = nowTime
    }

    static func draw(_ g: GraphicsContext, _ v: GVisitor, time t: CGFloat, night: CGFloat, nowTime: Double? = nil) {
        let since = nowTime.map { CGFloat($0 - v.poked) } ?? 10
        let react = since >= 0 && since < 0.65 ? sin(since / 0.65 * .pi) : 0
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
        if nowTime != nil && v.state == .staying && !v.fulfilled {
            drawWishBubble(g, for: v, time: t)
        }
    }

    private static func drawWishBubble(_ g: GraphicsContext, for v: GVisitor, time t: CGFloat) {
        let center = v.bubbleCenter(time: t)
        let tailToward = CGPoint(x: v.p.x, y: v.p.y - (v.kind.flies ? 10 : v.kind.stickerHeight * 0.72))
        StorybookArt.thoughtBubble(g, center: center, radius: 26, tailToward: tailToward)
        switch v.kind.wish {
        case .plant(let kind):
            let scale: CGFloat = kind == .pumpkin ? 0.56 : 0.62
            GardenPlants.drawCrop(g, kind: kind, variant: 0, at: CGPoint(x: center.x, y: center.y + (kind == .carrot ? 2 : 0)), size: scale, rot: kind == .carrot ? 0.35 : 0)
        case .anyFlower:
            GardenPlants.drawCrop(g, kind: .tulip, variant: 0, at: CGPoint(x: center.x, y: center.y - 2), size: 0.75, rot: 0)
        case .raindrop:
            var drop = Path()
            drop.move(to: CGPoint(x: center.x, y: center.y - 14))
            drop.addCurve(to: CGPoint(x: center.x, y: center.y + 12), control1: CGPoint(x: center.x + 6, y: center.y - 4), control2: CGPoint(x: center.x + 12, y: center.y + 12))
            drop.addCurve(to: CGPoint(x: center.x, y: center.y - 14), control1: CGPoint(x: center.x - 12, y: center.y + 12), control2: CGPoint(x: center.x - 6, y: center.y - 4))
            StorybookArt.fillAndStroke(g, drop, fill: Color(hex: 0x62B6F6), stroke: StorybookArt.outline(for: 0x62B6F6), width: 2)
            StorybookArt.highlight(g, in: CGRect(x: center.x - 5, y: center.y - 1, width: 4, height: 6), opacity: 0.75)
        case .decor:
            var roof = Path()
            roof.move(to: CGPoint(x: center.x - 14, y: center.y - 2))
            roof.addLine(to: CGPoint(x: center.x, y: center.y - 15))
            roof.addLine(to: CGPoint(x: center.x + 14, y: center.y - 2))
            roof.closeSubpath()
            let box = Path(roundedRect: CGRect(x: center.x - 10, y: center.y - 3, width: 20, height: 16), cornerRadius: 3)
            StorybookArt.shape(g, box, hex: 0x8ED4F8, width: 2)
            StorybookArt.shape(g, roof, hex: 0xFF8DA1, width: 2)
            g.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y + 1.5, width: 7, height: 7)), with: .color(Color(hex: 0x3A4A5C)))
        case .moon:
            let moon = GardenPlants.crescentMoonPath(center: center, radius: 12)
            g.fill(moon, with: .color(Theme.lemon))
            StorybookArt.sparkle(g, at: CGPoint(x: center.x + 9, y: center.y - 7), radius: 5, color: Color(hex: 0xFFB830))
        }
    }

    static func twinkles(_ g: GraphicsContext, around p: CGPoint, radius: CGFloat, time t: CGFloat, count: Int, alpha: Double) {
        Twinkles.draw(g, around: p, radius: radius, time: t, count: count, alpha: alpha)
    }

    private static func eye(_ c: GraphicsContext, _ p: CGPoint, _ r: CGFloat) {
        c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(GRGB(0x3A2630).color))
        c.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.2, y: p.y - r * 0.75, width: r * 0.6, height: r * 0.6)), with: .color(.white))
    }

    private static func oval(_ c: GraphicsContext, _ r: CGRect, _ col: GRGB, light: Bool = true, outline: Bool = true) {
        let p = Path(ellipseIn: r)
        if light {
            let grad = Gradient(colors: [col.shade(0.18).color, col.color, col.shade(-0.2).color])
            c.fill(p, with: .radialGradient(grad, center: CGPoint(x: r.midX + r.width * 0.15, y: r.minY + r.height * 0.3),
                                            startRadius: 0, endRadius: max(r.width, r.height) * 0.75))
        } else {
            c.fill(p, with: .color(col.color))
        }
        if outline {
            c.stroke(p, with: .color(col.shade(-0.44).color(0.75)), lineWidth: 1.4)
        }
    }

    private static func bunny(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let hop = v.moving ? abs(sin(v.walk / 22)) * 16 : 0
        c.translateBy(x: 0, y: -hop - react * 34)
        let fur = GRGB(0xC9A27E)
        let nibble = v.moving ? 0 : sin(t * 9 + CGFloat(v.seed)) * 1.4
        oval(c, CGRect(x: -30, y: -30, width: 14, height: 14), GRGB(0xFFFBF4))
        oval(c, CGRect(x: -18, y: -10, width: 26, height: 10), fur.shade(-0.1))
        oval(c, CGRect(x: -24, y: -40, width: 42, height: 36), fur)
        oval(c, CGRect(x: -10, y: -26, width: 20, height: 18), GRGB(0xF3E2CF), light: false, outline: false)
        oval(c, CGRect(x: 8, y: -10, width: 12, height: 9), fur.shade(-0.05))
        let flop = v.moving ? 0.1 : 0.18 + 0.12 * sin(t * 0.9 + CGFloat(v.seed))
        for (k, o) in [(-1.0, 0.0), (1.0, 7.0)] as [(CGFloat, CGFloat)] {
            var e = c
            e.translateBy(x: 14 + o, y: -54)
            e.rotate(by: .radians(Double(k < 0 ? -0.25 - flop : -0.05)))
            oval(e, CGRect(x: -5, y: -30, width: 11, height: 32), fur)
            e.fill(Path(ellipseIn: CGRect(x: -2.5, y: -25, width: 6, height: 23)), with: .color(GRGB(0xFFB3C7).color))
        }
        oval(c, CGRect(x: 4, y: -66 + nibble * 0.3, width: 30, height: 27), fur)
        eye(c, CGPoint(x: 24, y: -55), 3)
        c.fill(Path(ellipseIn: CGRect(x: 30, y: -48 + nibble, width: 6, height: 4.5)), with: .color(GRGB(0xFF8FB0).color))
        c.fill(Path(ellipseIn: CGRect(x: 15, y: -49, width: 7, height: 4)), with: .color(GRGB(0xFFB3C7).color(0.6)))
        if v.wearingCrown {
            drawFlowerCrown(c, at: CGPoint(x: 18, y: -65 + nibble * 0.3), colors: v.crownColors, scale: 0.92)
        }
    }

    private static func frog(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let hop = v.moving ? abs(sin(v.walk / 26)) * 22 : 0
        c.translateBy(x: 0, y: -hop - react * 40)
        let green = GRGB(0x63BE45)
        oval(c, CGRect(x: -22, y: -16, width: 22, height: 16), green.shade(-0.12))
        oval(c, CGRect(x: -20, y: -30, width: 40, height: 28), green)
        oval(c, CGRect(x: -4, y: -16, width: 22, height: 14), GRGB(0xDDF2B8), light: false, outline: false)
        oval(c, CGRect(x: 8, y: -6, width: 14, height: 7), green.shade(-0.08))
        let puff = v.moving ? 0 : max(0, sin(t * 3 + CGFloat(v.seed))) * 5
        if puff > 0.5 { oval(c, CGRect(x: 6 - puff * 0.2, y: -14, width: 14 + puff, height: 9 + puff), GRGB(0xF4FAD8), light: false, outline: false) }
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
        if v.wearingCrown {
            drawFlowerCrown(c, at: CGPoint(x: 3, y: -41), colors: v.crownColors, scale: 0.88)
        }
    }

    private static func snail(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        let c = g
        let hide = react
        let stretch = v.moving ? 1 + 0.08 * sin(v.walk / 3) : 1
        let len = 40 * stretch * (1 - 0.6 * hide)
        var body = Path()
        body.move(to: CGPoint(x: -18, y: 0))
        body.addLine(to: CGPoint(x: -18 + len, y: 0))
        body.addQuadCurve(to: CGPoint(x: -18 + len - 8, y: -12), control: CGPoint(x: -18 + len + 4, y: -12))
        body.addLine(to: CGPoint(x: -12, y: -7))
        body.closeSubpath()
        c.fill(body, with: .color(GRGB(0xE6D2B0).color))
        c.stroke(body, with: .color(GRGB(0xA68D6A).color(0.75)), lineWidth: 1.3)
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
        if v.wearingCrown {
            drawFlowerCrown(c, at: CGPoint(x: -5, y: -35), colors: v.crownColors, scale: 0.8)
        }
    }

    private static func hedgehog(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        let curl = react
        let bob = v.moving ? abs(sin(v.walk / 7)) * 2 : 0
        c.translateBy(x: 0, y: -bob)
        let spikeC = GRGB(0x7A5A40)
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
        c.stroke(spikes, with: .color(spikeC.shade(-0.45).color(0.7)), lineWidth: 1.2)
        if curl < 0.6 {
            var face = Path()
            face.move(to: CGPoint(x: 10, y: -28))
            face.addQuadCurve(to: CGPoint(x: 34, y: -10), control: CGPoint(x: 28, y: -26))
            face.addQuadCurve(to: CGPoint(x: 10, y: -2), control: CGPoint(x: 22, y: 0))
            face.closeSubpath()
            c.fill(face, with: .color(GRGB(0xEBD3AE).color))
            c.stroke(face, with: .color(GRGB(0xA68964).color(0.7)), lineWidth: 1.2)
            let sniff = v.moving ? 0 : sin(t * 7 + CGFloat(v.seed)) * 0.8
            c.fill(Path(ellipseIn: CGRect(x: 31 + sniff, y: -14, width: 6, height: 5)), with: .color(GRGB(0x3A2630).color))
            eye(c, CGPoint(x: 21, y: -18), 2.4)
            c.fill(Path(ellipseIn: CGRect(x: 15, y: -14, width: 6, height: 3.5)), with: .color(GRGB(0xFFA7B8).color(0.6)))
            for x in [-12.0, 8.0] as [CGFloat] {
                c.fill(Path(ellipseIn: CGRect(x: x, y: -4, width: 8, height: 5)), with: .color(GRGB(0xC9AE88).color))
            }
        }
        if v.wearingCrown {
            drawFlowerCrown(c, at: CGPoint(x: 10, y: -38), colors: v.crownColors, scale: 0.9)
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
        var tail = Path()
        tail.move(to: CGPoint(x: -10, y: -14))
        tail.addLine(to: CGPoint(x: -26, y: -20))
        tail.addLine(to: CGPoint(x: -24, y: -10))
        tail.closeSubpath()
        c.fill(tail, with: .color(blue.shade(-0.2).color))
        oval(c, CGRect(x: -14, y: -24, width: 28, height: 19), blue)
        oval(c, CGRect(x: -4, y: -16, width: 16, height: 11), GRGB(0xFF9F5E), light: false, outline: false)
        oval(c, CGRect(x: 2, y: -34, width: 18, height: 17), blue)
        eye(c, CGPoint(x: 14, y: -27), 2.2)
        var beak = Path()
        beak.move(to: CGPoint(x: 19, y: -28))
        beak.addLine(to: CGPoint(x: 26, y: -25.5))
        beak.addLine(to: CGPoint(x: 19, y: -23))
        beak.closeSubpath()
        c.fill(beak, with: .color(GRGB(0xF6B53A).color))
        let flap = flying ? sin(t * 22) : (react > 0 ? sin(t * 30) * react : 0)
        var w = c
        w.translateBy(x: -2, y: -18)
        w.rotate(by: .radians(Double(-0.2 - flap * 0.9)))
        oval(w, CGRect(x: -12, y: -5, width: 20, height: 10), blue.shade(-0.25))
        if v.wearingCrown {
            drawFlowerCrown(c, at: CGPoint(x: 11, y: -35), colors: v.crownColors, scale: 0.72)
        }
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
        oval(c, CGRect(x: -20, y: -54, width: 40, height: 54), brown)
        oval(c, CGRect(x: -12, y: -34, width: 24, height: 30), GRGB(0xEEDCBF), light: false, outline: false)
        for (x, y) in [(-5.0, -26.0), (5.0, -26.0), (0.0, -18.0), (-6.0, -12.0), (6.0, -12.0)] as [(CGFloat, CGFloat)] {
            var m = Path()
            m.move(to: CGPoint(x: x - 3, y: y))
            m.addLine(to: CGPoint(x: x, y: y + 2.5))
            m.addLine(to: CGPoint(x: x + 3, y: y))
            c.stroke(m, with: .color(brown.shade(-0.2).color), lineWidth: 1.2)
        }
        for side in [-1.0, 1.0] as [CGFloat] {
            var tuft = Path()
            tuft.move(to: CGPoint(x: side * 8, y: -52))
            tuft.addLine(to: CGPoint(x: side * 20, y: -64))
            tuft.addLine(to: CGPoint(x: side * 18, y: -48))
            tuft.closeSubpath()
            c.fill(tuft, with: .color(brown.shade(-0.12).color))
        }
        let blink = react > 0.2 || (t + CGFloat(v.seed % 7)).truncatingRemainder(dividingBy: 4.2) < 0.15
        for side in [-1.0, 1.0] as [CGFloat] {
            let ec = CGPoint(x: side * 9, y: -40)
            c.fill(Path(ellipseIn: CGRect(x: ec.x - 9, y: ec.y - 9, width: 18, height: 18)), with: .color(GRGB(0xFFF6E0).color))
            if blink {
                var lid = Path()
                lid.move(to: CGPoint(x: ec.x - 6, y: ec.y))
                lid.addQuadCurve(to: CGPoint(x: ec.x + 6, y: ec.y), control: CGPoint(x: ec.x, y: ec.y + 4))
                c.stroke(lid, with: .color(GRGB(0x3A2630).color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
        if v.wearingCrown {
            drawFlowerCrown(c, at: CGPoint(x: 0, y: -56), colors: v.crownColors, scale: 0.96)
        }
    }

    private static func hummingbird(_ g: GraphicsContext, _ v: GVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        c.translateBy(x: 0, y: -react * 10)
        c.rotate(by: .radians(-0.25))
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
        oval(c, CGRect(x: 2, y: -2, width: 9, height: 7), GRGB(0xFF4FA6), light: false, outline: false)
        oval(c, CGRect(x: 4, y: -12, width: 13, height: 12), GRGB(0x3FC08A))
        eye(c, CGPoint(x: 12, y: -7), 1.8)
        var beak = Path()
        beak.move(to: CGPoint(x: 16, y: -6))
        beak.addLine(to: CGPoint(x: 32, y: -4))
        c.stroke(beak, with: .color(GRGB(0x3A3030).color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        if v.wearingCrown {
            drawFlowerCrown(c, at: CGPoint(x: 10, y: -14), colors: v.crownColors, scale: 0.56)
        }
    }
}
