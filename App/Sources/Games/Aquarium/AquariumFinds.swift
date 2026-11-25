import SwiftUI

enum AquaRare {
    static let variant = 100
    static let chance = 0.2

    static func colors(_ k: FishKind) -> FishColors {
        switch k {
        case .goldfish: return FishColors(body: ARGB(0x7B4FE0), belly: ARGB(0xC9B6FF), fin: ARGB(0xB08CFF), finEdge: ARGB(0xFFE6FF), finAlpha: 0.8)
        case .clownfish: return FishColors(body: ARGB(0x3F8CFF), belly: ARGB(0x8FC2FF), fin: ARGB(0x4F9AFF), finEdge: ARGB(0x1E2A50), finAlpha: 0.95)
        case .angelfish: return FishColors(body: ARGB(0xFFC93A), belly: ARGB(0xFFE9A0), fin: ARGB(0xFFD45C), finEdge: ARGB(0xFFF6D8), finAlpha: 0.75)
        case .tetra: return FishColors(body: ARGB(0xFF9AD0), belly: ARGB(0xFFD6EC), fin: ARGB(0xFFC2E2), finEdge: ARGB(0xFFFFFF), finAlpha: 0.5)
        case .puffer: return FishColors(body: ARGB(0x8FE6C8), belly: ARGB(0xE6FFF6), fin: ARGB(0xB8F2DD), finEdge: ARGB(0xF2FFF9), finAlpha: 0.7)
        case .betta: return FishColors(body: ARGB(0xFFF6FB), belly: ARGB(0xFFFFFF), fin: ARGB(0xFF7EC8), finEdge: ARGB(0x7FE0FF), finAlpha: 0.85)
        case .guppy: return FishColors(body: ARGB(0xFFD34A), belly: ARGB(0xFFF0B0), fin: ARGB(0x7A4BE0), finEdge: ARGB(0xFF8AD8), finAlpha: 0.88)
        case .seahorse: return FishColors(body: ARGB(0x3FCFC0), belly: ARGB(0xA8F0E6), fin: ARGB(0xD6FFF8), finEdge: ARGB(0xFFFFFF), finAlpha: 0.7)
        case .axolotl: return FishColors(body: ARGB(0xFFE07D), belly: ARGB(0xFFF9D6), fin: ARGB(0xFF8AD8), finEdge: ARGB(0xFFE8FA), finAlpha: 0.92)
        case .seaBunny: return FishColors(body: ARGB(0xEFE4FF), belly: ARGB(0xFFFFFF), fin: ARGB(0x7B5EE0), finEdge: ARGB(0xFFE8B8), finAlpha: 0.95)
        case .narwhal: return FishColors(body: ARGB(0xFF9ED4), belly: ARGB(0xFFF0FA), fin: ARGB(0x8CE2FF), finEdge: ARGB(0xFFF3A8), finAlpha: 0.92)
        }
    }
}

enum AquaFind: String, CaseIterable {
    case galaxyGoldfish, blueClownfish, goldenAngelfish, pinkTetra, mintPuffer, opalBetta, goldenGuppy, tealSeahorse
    case crab, octopus, jellyfish, turtle, babyFish, pearl

    static func rare(_ k: FishKind) -> AquaFind? {
        switch k {
        case .goldfish: return .galaxyGoldfish
        case .clownfish: return .blueClownfish
        case .angelfish: return .goldenAngelfish
        case .tetra: return .pinkTetra
        case .puffer: return .mintPuffer
        case .betta: return .opalBetta
        case .guppy: return .goldenGuppy
        case .seahorse: return .tealSeahorse
        case .axolotl, .seaBunny, .narwhal: return nil
        }
    }

    var fish: FishKind? { FishKind.classicCases.first { AquaFind.rare($0) == self } }
    var visitor: AVisitorKind? { AVisitorKind(rawValue: rawValue) }

    static var stickers: [Sticker] {
        allCases.map { f in Sticker(id: f.rawValue) { g, _ in f.drawSticker(g) } }
    }

    func drawSticker(_ g: GraphicsContext) {
        if let k = fish {
            var s = g
            let span = max(k.length + k.tailLength, k.height * 1.15)
            let sc = 84 / span
            s.translateBy(x: k.tailLength * 0.5 * sc, y: 0)
            s.scaleBy(x: sc, y: sc)
            AquaFishPainter.drawLocal(s, kind: k, variant: AquaRare.variant, phase: 0.6, amp: 0.15, gulp: 0, puff: 0, time: 0)
            Twinkles.draw(g, around: .zero, radius: 40, time: 0.6, count: 3, alpha: 1)
        } else if self == .pearl {
            AquaVisitorPainter.pearl(g, at: .zero, r: 30, glow: 1)
            Twinkles.draw(g, around: .zero, radius: 40, time: 0.6, count: 3, alpha: 1)
        } else if let v = visitor {
            var s = g
            s.translateBy(x: 0, y: v.stickerOffset)
            s.scaleBy(x: v.stickerScale, y: v.stickerScale)
            AquaVisitorPainter.draw(s, AVisitor(kind: v, p: .zero, facing: 1, seed: 0), time: 0.4, night: 1)
        }
    }
}

enum AVisitorKind: String, CaseIterable {
    case crab, octopus, jellyfish, turtle, babyFish

    var passesBy: Bool { self == .turtle || self == .babyFish }
    var fades: Bool { self == .octopus || self == .jellyfish }

    var speed: CGFloat {
        switch self {
        case .crab: return 70
        case .octopus: return 0
        case .jellyfish: return 12
        case .turtle: return 64
        case .babyFish: return 96
        }
    }

    var reach: CGFloat {
        switch self {
        case .turtle: return 84
        case .babyFish: return 64
        default: return 54
        }
    }

    var stickerScale: CGFloat {
        switch self {
        case .crab: return 1.5
        case .octopus: return 1.15
        case .jellyfish: return 1.2
        case .turtle: return 0.78
        case .babyFish: return 1.15
        }
    }

    var stickerOffset: CGFloat {
        switch self {
        case .crab: return 22
        case .octopus: return 40
        case .jellyfish: return -6
        case .turtle, .babyFish: return 0
        }
    }
}

struct AVisitor {
    enum State { case arriving, staying, leaving }
    var kind: AVisitorKind
    var p: CGPoint
    var target = CGPoint.zero
    var state = State.arriving
    var stayUntil: Double = 0
    var facing: CGFloat
    var walk: CGFloat = 0
    var appear: CGFloat = 0
    var poked: Double = -10
    var seed = Int.random(in: 0..<1000)
    var decorID: Int?
    var found = false
}

// MARK: - Simulation hooks

extension AquariumSim {
    static func rollVariant(_ v: Int) -> Int {
        Double.random(in: 0..<1) < AquaRare.chance ? AquaRare.variant + v : v
    }

    func discover(_ f: AquaFind, at p: CGPoint) {
        guard !demo else { return }
        guard !StickerBook.shared.has(game: AquariumSim.gameID, id: f.rawValue) else { return }
        guard !pendingStickers.contains(f.rawValue) else { return }
        pendingStickers.append(f.rawValue)
        for _ in 0..<8 {
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: p.x + CGFloat.random(in: -40...40), y: p.y + CGFloat.random(in: -30...30)),
                    v: .zero,
                    life: 0.9,
                    size: 18,
                    color: ARGB(0xFFFFFF)
                )
            )
        }
        if !isStepping { flushPendingRewards() }
    }

    func stepFinds(_ dt: CGFloat) {
        if Int(time * 2) != Int((time - Double(dt)) * 2) {
            for f in fish where f.variant >= AquaRare.variant && !f.caught && AGeo.inWater(f.p) {
                if let find = AquaFind.rare(f.kind),
                   !StickerBook.shared.has(game: AquariumSim.gameID, id: find.rawValue) {
                    discover(find, at: f.p)
                }
            }
        }
        stepVisitors(dt)
        if let pl = pearl, time > pl.until { pearl = nil }
    }

    func revealChestPearl(_ i: Int) {
        guard decor.indices.contains(i) else { return }
        let d = decor[i]
        let origin = CGPoint(x: d.x, y: d.y - 44)
        pearl = (d.id, time + 2.4)
        discover(.pearl, at: origin)
        Sound.shared.play(.sparkle, volume: 0.55)
        for k in 0..<8 {
            let a = CGFloat(k) / 8 * 2 * .pi
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: origin.x + cos(a) * 28, y: origin.y + sin(a) * 22),
                    v: .zero,
                    life: 0.75,
                    size: 14,
                    color: ARGB(0xFFE69A)
                )
            )
        }
        if time - lastChestCoinAt >= AquariumSim.coinCooldown {
            lastChestCoinAt = time
            queueCoin(3, from: origin)
        }
    }

    func inviteTurtle() {
        guard !visitors.contains(where: { $0.kind == .turtle }) else { return }
        let y = CGFloat.random(in: 260...420)
        arrive(.turtle, at: (CGPoint(x: 0, y: y), nil))
    }

    func spawnBabyFish(near p: CGPoint) {
        guard !visitors.contains(where: { $0.kind == .babyFish }) else { return }
        let y = max(AGeo.waterY + 70, min(500, p.y))
        arrive(.babyFish, at: (CGPoint(x: 0, y: y), nil))
    }

    func peekOctopus(near decorIndex: Int) {
        guard decor.indices.contains(decorIndex) else { return }
        guard !visitors.contains(where: { $0.kind == .octopus }) else { return }
        let d = decor[decorIndex]
        let side: CGFloat = d.x < 512 ? 1 : -1
        let x = max(AGeo.left + 44, min(AGeo.right - 44, d.x + side * (d.kind.size.width * 0.5 + 8)))
        arrive(.octopus, at: (CGPoint(x: x, y: AGeo.sand(x) + 2), d.id))
        AquaSound.shared.play(.bloop, volume: 0.55)
    }

    private func spot(for k: AVisitorKind) -> (CGPoint, Int?)? {
        let dark = night > 0.5
        switch k {
        case .crab:
            guard dark else { return nil }
            let x = CGFloat.random(in: 220...800)
            return (CGPoint(x: x, y: AGeo.sand(x)), nil)
        case .octopus:
            let homes = decor.filter { !$0.held && !$0.falling && ($0.kind == .castle || $0.kind == .ship || $0.kind == .rock) }
            guard let d = homes.randomElement() else { return nil }
            let side: CGFloat = d.x < 512 ? 1 : -1
            let x = max(AGeo.left + 40, min(AGeo.right - 40, d.x + side * (d.kind.size.width * 0.5 + 6)))
            return (CGPoint(x: x, y: AGeo.sand(x) + 2), d.id)
        case .jellyfish:
            guard dark else { return nil }
            return (CGPoint(x: CGFloat.random(in: 240...780), y: CGFloat.random(in: 260...420)), nil)
        case .turtle:
            guard !dark, dirtiness < 0.06 else { return nil }
            return (CGPoint(x: 0, y: CGFloat.random(in: 260...440)), nil)
        case .babyFish:
            guard time - lastFed < 14, lastFed > 0, fish.count >= 3 else { return nil }
            return (CGPoint(x: 0, y: CGFloat.random(in: 300...480)), nil)
        }
    }

    private func stepVisitors(_ dt: CGFloat) {
        if time > nextVisit && visitors.count < 2 {
            nextVisit = time + Double.random(in: 12...24)
            let book = StickerBook.shared
            var options: [(AVisitorKind, (CGPoint, Int?))] = []
            for k in AVisitorKind.allCases where !visitors.contains(where: { $0.kind == k }) {
                guard let s = spot(for: k) else { continue }
                let n = book.has(game: AquariumSim.gameID, id: k.rawValue) ? 1 : 3
                for _ in 0..<n { options.append((k, s)) }
            }
            if let o = options.randomElement() { arrive(o.0, at: o.1) }
        }
        let t = CGFloat(time)
        var write = 0
        for read in 0..<visitors.count {
            var v = visitors[read]
            if v.kind.fades {
                switch v.state {
                case .arriving:
                    v.appear = min(1, v.appear + dt * 0.9)
                    if v.appear >= 1 { stay(&v) }
                case .staying:
                    var gone = time > v.stayUntil
                    if v.kind == .jellyfish && night < 0.3 { gone = true }
                    if v.kind == .octopus, let id = v.decorID {
                        gone = gone || !decor.contains { $0.id == id && !$0.held }
                    }
                    if gone { v.state = .leaving }
                case .leaving:
                    v.appear -= dt * 0.9
                    if v.appear <= 0 { continue }
                }
                if v.kind == .jellyfish {
                    let dx = v.target.x - v.p.x
                    let dy = v.target.y - v.p.y
                    let d = hypot(dx, dy)
                    if d < 6 {
                        v.target = CGPoint(
                            x: max(160, min(860, v.p.x + CGFloat.random(in: -160...160))),
                            y: max(AGeo.waterY + 80, min(470, v.p.y + CGFloat.random(in: -90...90)))
                        )
                    } else {
                        let pulse = 0.5 + 0.5 * max(0, sin(t * 2.6 + CGFloat(v.seed)))
                        v.p.x += dx / d * v.kind.speed * pulse * dt * 2
                        v.p.y += dy / d * v.kind.speed * pulse * dt * 2
                    }
                }
            } else {
                switch v.state {
                case .arriving, .leaving:
                    let dx = v.target.x - v.p.x
                    let d = abs(dx)
                    let stepLen = v.kind.speed * dt
                    if d <= stepLen {
                        v.p.x = v.target.x
                        if v.state == .leaving || v.kind.passesBy { continue }
                        stay(&v)
                    } else {
                        v.p.x += dx / d * stepLen
                        v.walk += stepLen
                        v.facing = dx > 0 ? 1 : -1
                    }
                    if v.kind == .crab { v.p.y = AGeo.sand(v.p.x) }
                    if v.kind.passesBy {
                        v.p.y = v.target.y + sin(v.walk / 60) * 14
                        if !v.found && v.p.x > 220 && v.p.x < 800 {
                            v.found = true
                            if let f = AquaFind(rawValue: v.kind.rawValue) { discover(f, at: v.p) }
                        }
                    }
                case .staying:
                    if v.kind == .crab,
                       let pelletIdx = food.indices.first(where: { food[$0].kind == .pearls && food[$0].state == .settled && abs(food[$0].p.x - v.p.x) < 42 }) {
                        let fp = food[pelletIdx].p
                        food.remove(at: pelletIdx)
                        v.poked = time
                        emitParticle(
                            AquaParticle(
                                kind: .heart,
                                p: CGPoint(x: fp.x, y: fp.y - 22),
                                v: CGVector(dx: 0, dy: -42),
                                life: 1.1,
                                size: 14,
                                color: ARGB(0xFF8FB8)
                            )
                        )
                    }
                    if time > v.stayUntil || (v.kind == .crab && night < 0.3) {
                        v.state = .leaving
                        let right = v.p.x > 512
                        v.target = CGPoint(x: right ? AGeo.right + 40 : AGeo.left - 40, y: v.p.y)
                    }
                }
            }
            visitors[write] = v
            write += 1
        }
        if write < visitors.count {
            visitors.removeSubrange(write..<visitors.count)
        }
    }

    private func stay(_ v: inout AVisitor) {
        v.state = .staying
        v.stayUntil = time + Double.random(in: 10...18)
        if !v.found {
            v.found = true
            if let f = AquaFind(rawValue: v.kind.rawValue) { discover(f, at: CGPoint(x: v.p.x, y: v.p.y - 30)) }
        }
    }

    private func arrive(_ k: AVisitorKind, at s: (CGPoint, Int?)) {
        var v = AVisitor(kind: k, p: s.0, facing: 1)
        v.decorID = s.1
        v.target = s.0
        switch k {
        case .crab:
            let fromLeft = s.0.x < 512
            v.p = CGPoint(x: fromLeft ? AGeo.left - 40 : AGeo.right + 40, y: AGeo.sand(s.0.x))
            v.facing = fromLeft ? 1 : -1
        case .turtle, .babyFish:
            let fromLeft = Bool.random()
            v.p = CGPoint(x: fromLeft ? AGeo.left - 120 : AGeo.right + 120, y: s.0.y)
            v.target = CGPoint(x: fromLeft ? AGeo.right + 120 : AGeo.left - 120, y: s.0.y)
            v.facing = fromLeft ? 1 : -1
        case .octopus:
            if let id = s.1, let d = decor.first(where: { $0.id == id }) { v.facing = d.x < v.p.x ? -1 : 1 }
        case .jellyfish:
            v.p = CGPoint(x: s.0.x, y: AGeo.waterY + 90)
        }
        visitors.append(v)
    }

    func tapVisitor(_ p: CGPoint) -> Bool {
        for i in visitors.indices {
            let v = visitors[i]
            let mid = v.kind == .crab || v.kind == .octopus ? CGPoint(x: v.p.x, y: v.p.y - 24) : v.p
            guard hypot(mid.x - p.x, mid.y - p.y) < v.kind.reach else { continue }
            if !visitors[i].found {
                visitors[i].found = true
                if let f = AquaFind(rawValue: v.kind.rawValue) { discover(f, at: mid) }
            }
            guard time - v.poked > 0.5 else { return true }
            visitors[i].poked = time
            switch v.kind {
            case .crab: AquaSound.shared.play(.tink, volume: 0.6)
            case .octopus, .jellyfish: AquaSound.shared.play(.bloop, volume: 0.6)
            case .turtle, .babyFish: AquaSound.shared.play(.blub, volume: 0.6)
            }
            for k in 0..<5 {
                addBubble(CGPoint(x: mid.x + CGFloat(k * 6 - 12), y: mid.y - 18 - CGFloat(k) * 6), r: 2.5 + CGFloat(k % 3))
            }
            emitParticle(
                AquaParticle(
                    kind: .heart,
                    p: CGPoint(x: mid.x, y: mid.y - 28),
                    v: CGVector(dx: 0, dy: -44),
                    life: 1.2,
                    size: 16,
                    color: ARGB(0xFF7FAE)
                )
            )
            return true
        }
        return false
    }
}

// MARK: - Drawing

enum AquaVisitorPainter {
    static func draw(_ g: GraphicsContext, _ v: AVisitor, time t: CGFloat, night: CGFloat, nowTime: Double? = nil) {
        let since = nowTime.map { CGFloat($0 - v.poked) } ?? 10
        let react = since >= 0 && since < 0.6 ? sin(since / 0.6 * .pi) : 0
        var c = g
        c.translateBy(x: v.p.x, y: v.p.y)
        c.scaleBy(x: v.facing < 0 ? -1 : 1, y: 1)
        if v.kind.fades { c.opacity = Double(nowTime == nil ? 1 : aqEase(v.appear)) }
        switch v.kind {
        case .crab: crab(c, v, t, react)
        case .octopus: octopus(c, v, t, react, rise: nowTime == nil ? 1 : aqEase(v.appear))
        case .jellyfish: jellyfish(c, v, t, react, night: night)
        case .turtle: turtle(c, v, t, react)
        case .babyFish: babies(c, v, t, react)
        }
    }

    static func pearl(_ g: GraphicsContext, at p: CGPoint, r: CGFloat, glow: CGFloat) {
        let halo = r * 2.2
        g.fill(
            Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: halo * 2, height: halo * 2)),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.75 * Double(glow)), Color.white.opacity(0)]),
                center: p,
                startRadius: r * 0.6,
                endRadius: halo
            )
        )
        g.fill(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                Gradient(colors: [ARGB(0xFFFFFF).color, ARGB(0xF6E8F4).color, ARGB(0xD9C6E6).color]),
                center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.35),
                startRadius: 0,
                endRadius: r * 1.4
            )
        )
        g.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.5, y: p.y - r * 0.6, width: r * 0.45, height: r * 0.32)), with: .color(.white.opacity(0.9)))
    }

    private static func oval(_ c: GraphicsContext, _ r: CGRect, _ col: ARGB) {
        let grad = Gradient(colors: [col.shade(0.2).color, col.color, col.shade(-0.25).color])
        c.fill(
            Path(ellipseIn: r),
            with: .radialGradient(
                grad,
                center: CGPoint(x: r.midX - r.width * 0.15, y: r.minY + r.height * 0.3),
                startRadius: 0,
                endRadius: max(r.width, r.height) * 0.75
            )
        )
    }

    private static func eye(_ c: GraphicsContext, _ p: CGPoint, _ r: CGFloat) {
        c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(ARGB(0x1E2030).color))
        c.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.2, y: p.y - r * 0.75, width: r * 0.6, height: r * 0.6)), with: .color(.white))
    }

    private static func crab(_ g: GraphicsContext, _ v: AVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        c.translateBy(x: 0, y: -react * 10)
        let red = ARGB(0xF2603F)
        let moving = v.state != .staying
        for side in [-1.0, 1.0] as [CGFloat] {
            for k in 0..<3 {
                let step = moving ? sin(v.walk / 5 + CGFloat(k) * 2 + (side > 0 ? 1 : 0)) * 3 : 0
                var leg = Path()
                let x0 = side * (8 + CGFloat(k) * 4)
                leg.move(to: CGPoint(x: x0, y: -10))
                leg.addLine(to: CGPoint(x: x0 + side * 9, y: -14 + step))
                leg.addLine(to: CGPoint(x: x0 + side * 14, y: 0))
                c.stroke(leg, with: .color(red.shade(-0.2).color), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        for side in [-1.0, 1.0] as [CGFloat] {
            let lift = react * 12 + (moving ? 0 : sin(t * 2 + side) * 2)
            var arm = Path()
            arm.move(to: CGPoint(x: side * 14, y: -18))
            arm.addLine(to: CGPoint(x: side * 24, y: -28 - lift))
            c.stroke(arm, with: .color(red.shade(-0.1).color), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            oval(c, CGRect(x: side * 24 - 8, y: -40 - lift, width: 16, height: 13), red)
            var nip = Path()
            nip.move(to: CGPoint(x: side * 24, y: -40 - lift))
            nip.addLine(to: CGPoint(x: side * 24, y: -32 - lift))
            c.stroke(nip, with: .color(red.shade(-0.45).color), lineWidth: 1.4)
        }
        oval(c, CGRect(x: -20, y: -26, width: 40, height: 22), red)
        for x in [-6.0, 6.0] as [CGFloat] {
            var stalk = Path()
            stalk.move(to: CGPoint(x: x, y: -24))
            stalk.addLine(to: CGPoint(x: x, y: -33))
            c.stroke(stalk, with: .color(red.shade(-0.2).color), lineWidth: 2)
            c.fill(Path(ellipseIn: CGRect(x: x - 4, y: -39, width: 8, height: 8)), with: .color(.white))
            eye(c, CGPoint(x: x + 0.5, y: -35), 2.4)
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -5, y: -15))
        smile.addQuadCurve(to: CGPoint(x: 5, y: -15), control: CGPoint(x: 0, y: -11))
        c.stroke(smile, with: .color(red.shade(-0.5).color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private static func octopus(_ g: GraphicsContext, _ v: AVisitor, _ t: CGFloat, _ react: CGFloat, rise: CGFloat) {
        var c = g
        let hues: [ARGB] = [ARGB(0xB07BEA), ARGB(0xFF8A8A), ARGB(0xFFB45C), ARGB(0x7FC8F0)]
        let u = (t * 0.12 + CGFloat(v.seed % 4)).truncatingRemainder(dividingBy: CGFloat(hues.count))
        let a = hues[Int(u) % hues.count], b = hues[(Int(u) + 1) % hues.count]
        let col = a.mix(b, u - floor(u)).mix(ARGB(0xFF6FA8), react)
        c.translateBy(x: 0, y: (1 - rise) * 30)
        for k in 0..<6 {
            let base = CGFloat(k) - 2.5
            var arm = Path()
            arm.move(to: CGPoint(x: base * 6, y: -16))
            let wave = sin(t * 2 + CGFloat(k)) * 6
            arm.addCurve(
                to: CGPoint(x: base * 14 + wave, y: -2),
                control1: CGPoint(x: base * 9, y: -6),
                control2: CGPoint(x: base * 14 - wave, y: -12)
            )
            c.stroke(arm, with: .color(col.shade(-0.1).color), style: StrokeStyle(lineWidth: 7 - abs(base), lineCap: .round))
        }
        let squish = 1 + react * 0.15
        oval(c, CGRect(x: -20 * squish, y: -52 / squish, width: 40 * squish, height: 42 / squish), col)
        for x in [-8.0, 8.0] as [CGFloat] {
            c.fill(Path(ellipseIn: CGRect(x: x - 6, y: -34, width: 12, height: 12)), with: .color(.white))
            eye(c, CGPoint(x: x + 1, y: -27), 3.6)
        }
        c.fill(Path(ellipseIn: CGRect(x: -16, y: -46, width: 8, height: 6)), with: .color(.white.opacity(0.35)))
        for x in [-14.0, 14.0] as [CGFloat] {
            c.fill(Path(ellipseIn: CGRect(x: x - 4, y: -20, width: 8, height: 4)), with: .color(ARGB(0xFF8FB8).color(0.6)))
        }
    }

    private static func jellyfish(_ g: GraphicsContext, _ v: AVisitor, _ t: CGFloat, _ react: CGFloat, night: CGFloat) {
        let c = g
        let pulse = max(0, sin(t * 2.6 + CGFloat(v.seed)))
        let w = 46 * (1 - 0.12 * pulse + 0.15 * react)
        let h = 30 * (1 + 0.1 * pulse)
        let col = ARGB(0xC9A8FF)
        let gr: CGFloat = 70
        c.fill(
            Path(ellipseIn: CGRect(x: -gr, y: -gr - 4, width: gr * 2, height: gr * 2)),
            with: .radialGradient(
                Gradient(colors: [ARGB(0xE8D8FF).color(0.55 * Double(0.4 + 0.6 * night)), ARGB(0xE8D8FF).color(0)]),
                center: CGPoint(x: 0, y: -4),
                startRadius: 6,
                endRadius: gr
            )
        )
        for k in 0..<5 {
            let x0 = (CGFloat(k) - 2) * w * 0.17
            var tp = Path()
            tp.move(to: CGPoint(x: x0, y: 0))
            for s in 1...8 {
                let y = CGFloat(s) * 6
                tp.addLine(to: CGPoint(x: x0 + sin(t * 3 + CGFloat(s) * 0.7 + CGFloat(k)) * 4, y: y))
            }
            c.stroke(tp, with: .color(col.shade(0.3).color(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        var bell = Path()
        bell.move(to: CGPoint(x: -w / 2, y: 0))
        bell.addCurve(to: CGPoint(x: w / 2, y: 0), control1: CGPoint(x: -w / 2, y: -h * 1.35), control2: CGPoint(x: w / 2, y: -h * 1.35))
        bell.addQuadCurve(to: CGPoint(x: -w / 2, y: 0), control: CGPoint(x: 0, y: 6))
        c.fill(bell, with: .linearGradient(Gradient(colors: [col.shade(0.4).color(0.95), col.color(0.85)]),
                                           startPoint: CGPoint(x: 0, y: -h), endPoint: CGPoint(x: 0, y: 0)))
        c.stroke(bell, with: .color(.white.opacity(0.6)), lineWidth: 1.4)
        for x in [-8.0, 8.0] as [CGFloat] { eye(c, CGPoint(x: x, y: -h * 0.4), 2.6) }
        var smile = Path()
        smile.move(to: CGPoint(x: -4, y: -h * 0.22))
        smile.addQuadCurve(to: CGPoint(x: 4, y: -h * 0.22), control: CGPoint(x: 0, y: -h * 0.1))
        c.stroke(smile, with: .color(ARGB(0x5A3A8A).color), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: -w * 0.32, y: -h * 0.95, width: w * 0.22, height: h * 0.3)), with: .color(.white.opacity(0.55)))
    }

    private static func turtle(_ g: GraphicsContext, _ v: AVisitor, _ t: CGFloat, _ react: CGFloat) {
        var c = g
        c.rotate(by: .radians(Double(sin(v.walk / 60) * 0.06)))
        let skin = ARGB(0x8FCB6A)
        let stroke = sin(v.walk / 22)
        for (x, front) in [(30.0, true), (-30.0, false)] as [(CGFloat, Bool)] {
            for side in [-1.0, 1.0] as [CGFloat] {
                var f = c
                f.translateBy(x: x, y: side * 14)
                f.rotate(by: .radians(Double((front ? 0.7 : 0.4) * side + stroke * 0.5 * side)))
                let len: CGFloat = front ? 34 : 20
                oval(f, CGRect(x: -len * 0.2, y: side < 0 ? -10 : 0, width: len, height: 10), skin.shade(-0.08))
            }
        }
        oval(c, CGRect(x: 44 - react * 8, y: -12, width: 26, height: 20), skin)
        eye(c, CGPoint(x: 60 - react * 8, y: -5), 2.8)
        var smile = Path()
        smile.move(to: CGPoint(x: 58 - react * 8, y: 2))
        smile.addQuadCurve(to: CGPoint(x: 66 - react * 8, y: 1), control: CGPoint(x: 63, y: 4))
        c.stroke(smile, with: .color(skin.shade(-0.5).color), lineWidth: 1.2)
        let shell = ARGB(0x5E9F5A)
        oval(c, CGRect(x: -46, y: -28, width: 92, height: 52), shell)
        c.stroke(Path(ellipseIn: CGRect(x: -46, y: -28, width: 92, height: 52)), with: .color(ARGB(0xE8D79A).color), lineWidth: 3)
        for (x, y, r) in [(0.0, -3.0, 12.0), (-22.0, -4.0, 9.0), (22.0, -4.0, 9.0), (-10.0, 12.0, 8.0), (10.0, 12.0, 8.0)] as [(CGFloat, CGFloat, CGFloat)] {
            var hex = Path()
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * 2 * .pi
                let pt = CGPoint(x: x + cos(a) * r, y: y + sin(a) * r * 0.8)
                if k == 0 { hex.move(to: pt) } else { hex.addLine(to: pt) }
            }
            hex.closeSubpath()
            c.fill(hex, with: .color(shell.shade(0.15).color))
            c.stroke(hex, with: .color(shell.shade(-0.3).color), lineWidth: 1)
        }
    }

    private static func babies(_ g: GraphicsContext, _ v: AVisitor, _ t: CGFloat, _ react: CGFloat) {
        let offsets: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: -24, y: -14), CGPoint(x: -22, y: 14),
            CGPoint(x: -46, y: 0), CGPoint(x: -44, y: -24), CGPoint(x: -48, y: 22),
        ]
        let colors: [ARGB] = [ARGB(0xFF9A45), ARGB(0xFFC531), ARGB(0xFF8A2B), ARGB(0xFFD08A), ARGB(0xFF9A45), ARGB(0xFFC531)]
        for (k, o) in offsets.enumerated() {
            var f = g
            let scatter = react * 12
            f.translateBy(
                x: o.x + 24 + sin(t * 3 + CGFloat(k)) * 2 + (o.x < 0 ? -scatter : scatter),
                y: o.y + cos(t * 2.4 + CGFloat(k)) * 3 + o.y * react * 0.6
            )
            let wag = sin(t * 14 + CGFloat(k))
            var tail = Path()
            tail.move(to: CGPoint(x: -8, y: 0))
            tail.addLine(to: CGPoint(x: -15, y: -5 + wag * 2))
            tail.addLine(to: CGPoint(x: -15, y: 5 + wag * 2))
            tail.closeSubpath()
            f.fill(tail, with: .color(colors[k].shade(0.1).color(0.85)))
            oval(f, CGRect(x: -10, y: -6, width: 20, height: 12), colors[k])
            eye(f, CGPoint(x: 5, y: -1.5), 2)
        }
    }
}
