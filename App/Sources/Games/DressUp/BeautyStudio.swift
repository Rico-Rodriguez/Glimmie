import SwiftUI

// MARK: - The makeup and nail studio
//
// Makeup: a close-up of her face in a lit vanity mirror. Blush goes on soft and builds up, eyeshadow
// sits under her lashes (she closes her eyes when the sponge comes near), lipstick only colors her
// lips, glitter falls from the jar and sticks where it lands on her skin, and the cleansing pad wipes
// it all away.
//
// Nails: a close-up of her hand. Dip the brush and paint: polish only goes where the brush goes,
// flows and levels while wet, runs out on the brush, drips down her finger if she piles on too much,
// smears if she paints her skin, and dries glossy (faster under the fan). The remover swab cleans
// up, and gems and stickers press on (and fall if they miss).
//
// Every tool is held a little above her finger, so she can see what she paints.

final class BeautyWorld {
    enum Mode { case makeup, nails }
    enum Tool: String { case blush, shadow, lip, glitter, wipe, polish, remover, dryer, gem }

    var mode: Mode
    var look: Look
    var tool: Tool
    var color: String
    var gemKind = "g_round"
    var gemColor = "#E8F4FF"

    /// How far above the finger the tool's tip is (stage points).
    static let lift: CGFloat = 84
    static let faceBox = CGRect(x: 110, y: 104, width: 380, height: 380)
    static let handBox = CGRect(x: 40, y: 70, width: 520, height: 650)

    var size: CGSize = .zero
    private(set) var finger: CGPoint?
    private var lastTip: CGPoint?
    private var lastTime: Double?
    var now: Double = 0

    // makeup
    private var stroke: Int?
    var blinkUntil: Double = 0
    var smileUntil: Double = 0
    private var nextBlink: Double = 3

    // nails
    var cells: [[Double]]
    var tints: [[RGB]]
    var coats: [Int]
    var glitterCoat: [Bool]
    var wet: [Double]
    var gems: [[NailGem]]
    var spills: [Spill] = []
    private var drips: [Drip] = []
    /// Polish on the brush (0...1).
    var load: Double = 0
    private var coated = Set<Int>()
    private var smear: Int?
    private var lastDrip: Double = 0

    var bits: [Bit] = []
    private var undoMakeup: [[BeautyStroke]] = []
    private var undoNails: [NailSnap] = []

    struct Spill { var pts: [CGPoint]; var widths: [CGFloat]; var color: RGB; var wet: Double }
    private struct Drip { var p: CGPoint; var v: CGVector; var mass: Double; var color: RGB; var spill: Int; var trail: CGFloat = 0 }
    private struct NailSnap { var cells: [[Double]]; var tints: [[RGB]]; var coats: [Int]; var glitter: [Bool]; var gems: [[NailGem]]; var spills: [Spill] }

    struct Bit {
        enum Kind { case dust, fleck, foam, air, spark, gem, drop }
        var kind: Kind
        var p: CGPoint
        var v: CGVector
        var life: Double
        var age: Double = 0
        var size: CGFloat
        var color: RGB = Shades.white
        var hex: String = "#FFFFFF"
        var landAt: Double = 0
        var gem: String = ""
        var bounced = false
    }

    init(look: Look, mode: Mode) {
        self.look = look
        self.mode = mode
        tool = mode == .makeup ? .blush : .polish
        color = mode == .makeup ? BeautyColors.blush[0] : BeautyColors.polish[0]
        cells = Array(repeating: Array(repeating: 0, count: NailGrid.count), count: 5)
        tints = Array(repeating: Array(repeating: Shades.white, count: NailGrid.count), count: 5)
        coats = Array(repeating: 0, count: 5)
        glitterCoat = Array(repeating: false, count: 5)
        wet = Array(repeating: 0, count: 5)
        gems = Array(repeating: [], count: 5)
        for (i, n) in look.nails.prefix(5).enumerated() {
            let bits = NailGrid.decode(n.mask)
            let c = RGB(hex: n.color ?? "#FFFFFF")
            for k in 0..<NailGrid.count where bits[k] { cells[i][k] = 1; tints[i][k] = c }
            coats[i] = n.coats
            glitterCoat[i] = n.glitter
            gems[i] = n.gems
        }
        if mode == .nails { load = 1 }
    }

    // MARK: Spaces

    var box: CGRect { mode == .makeup ? Self.faceBox : Self.handBox }

    private var fit: (k: CGFloat, ox: CGFloat, oy: CGFloat) {
        let b = box
        let k = min(size.width / b.width, size.height / b.height)
        return (k, (size.width - b.width * k) / 2, (size.height - b.height * k) / 2)
    }

    /// Stage point -> art space (the face's doll coordinates, or the hand's own space).
    func toArt(_ p: CGPoint) -> CGPoint {
        let f = fit
        return CGPoint(x: (p.x - f.ox) / f.k + box.minX, y: (p.y - f.oy) / f.k + box.minY)
    }

    func apply(_ ctx: inout GraphicsContext) {
        let f = fit
        ctx.translateBy(x: f.ox, y: f.oy)
        ctx.scaleBy(x: f.k, y: f.k)
        ctx.translateBy(x: -box.minX, y: -box.minY)
    }

    var tipOnStage: CGPoint? { finger.map { CGPoint(x: $0.x, y: $0.y - Self.lift) } }

    // MARK: Fingers

    func press(_ p: CGPoint) {
        finger = p
        lastTip = nil
        guard let tip = tipOnStage.map(toArt) else { return }
        switch tool {
        case .blush, .shadow, .lip, .glitter:
            saveUndo()
            look.makeup.append(BeautyStroke(tool: tool.rawValue, color: color))
            stroke = look.makeup.count - 1
            if tool == .glitter { BeautySound.shared.play(.shake, volume: 0.6) }
        case .wipe:
            saveUndo()
        case .polish, .remover, .gem:
            saveUndo()
            coated = []
            smear = nil
        case .dryer:
            break
        }
        work(at: tip, moved: 0)
        lastTip = tip
    }

    func move(_ p: CGPoint) {
        finger = p
        guard let tip = tipOnStage.map(toArt) else { return }
        let d = lastTip.map { hypot(tip.x - $0.x, tip.y - $0.y) } ?? 0
        work(at: tip, moved: d)
        lastTip = tip
    }

    func release() {
        if tool == .gem, let tip = tipOnStage.map(toArt) { dropGem(at: tip) }
        if let s = stroke, s < look.makeup.count, look.makeup[s].pts.isEmpty { look.makeup.remove(at: s) }
        stroke = nil
        smear = nil
        finger = nil
        lastTip = nil
        syncNails()
    }

    /// The tool at work at `tip` (art space), having moved `d` since the last time.
    private func work(at tip: CGPoint, moved d: CGFloat) {
        switch tool {
        case .blush, .shadow, .lip: paintMakeup(at: tip, moved: d)
        case .glitter: if d > 0.5 { BeautySound.shared.play(.shake, volume: 0.5, gap: 0.28) }
        case .wipe: wipe(at: tip, moved: d)
        case .polish: brush(at: tip, moved: d)
        case .remover: remove(at: tip, moved: d)
        case .dryer, .gem: break
        }
    }

    // MARK: Makeup

    private func paintMakeup(at tip: CGPoint, moved d: CGFloat) {
        guard let s = stroke, s < look.makeup.count else { return }
        if tool == .lip {
            let dx = (tip.x - BeautyPainter.lipsCenter.x) / 40, dy = (tip.y - BeautyPainter.lipsCenter.y) / 22
            guard dx * dx + dy * dy <= 1 else { return }
        }
        if let last = look.makeup[s].points.last, hypot(tip.x - last.x, tip.y - last.y) < 3 { return }
        look.makeup[s].pts += [Float(tip.x), Float(tip.y)]
        trimMakeup()
        switch tool {
        case .blush:
            BeautySound.shared.play(.brush, volume: 0.55, gap: 0.22)
            if Double.random(in: 0...1) < 0.35 {
                bits.append(Bit(kind: .dust, p: CGPoint(x: tip.x + .random(in: -14...14), y: tip.y + .random(in: -8...8)),
                                v: CGVector(dx: .random(in: -14...14), dy: .random(in: -20...4)), life: 1.4, size: .random(in: 1.5...3.5),
                                color: RGB(hex: color)))
            }
        case .shadow: BeautySound.shared.play(.sponge, volume: 0.6, gap: 0.2)
        default: BeautySound.shared.play(.lipstick, volume: 0.6, gap: 0.24)
        }
    }

    /// Keeps the makeup under its size limit by letting go of the oldest strokes.
    private func trimMakeup() {
        var total = look.makeup.reduce(0) { $0 + $1.pts.count }
        while total > Look.maxMakeupPoints, look.makeup.count > 1 {
            total -= look.makeup[0].pts.count
            look.makeup.removeFirst()
            if let s = stroke { stroke = s - 1 }
        }
    }

    private func wipe(at tip: CGPoint, moved d: CGFloat) {
        let r: CGFloat = 20
        var out: [BeautyStroke] = []
        var changed = false
        for st in look.makeup {
            let pts = st.points
            if st.tool == "glitter" {
                let keep = pts.filter { hypot($0.x - tip.x, $0.y - tip.y) > r }
                if keep.count != pts.count { changed = true }
                if !keep.isEmpty { out.append(BeautyStroke(tool: st.tool, color: st.color, pts: keep.flatMap { [Float($0.x), Float($0.y)] })) }
                continue
            }
            var run: [CGPoint] = []
            for p in pts {
                if hypot(p.x - tip.x, p.y - tip.y) <= r {
                    changed = true
                    if !run.isEmpty { out.append(BeautyStroke(tool: st.tool, color: st.color, pts: run.flatMap { [Float($0.x), Float($0.y)] })) }
                    run = []
                } else { run.append(p) }
            }
            if !run.isEmpty { out.append(BeautyStroke(tool: st.tool, color: st.color, pts: run.flatMap { [Float($0.x), Float($0.y)] })) }
        }
        if changed { look.makeup = out }
        if d > 0.5 || changed {
            BeautySound.shared.play(.wipe, volume: 0.6, gap: 0.3)
            if Double.random(in: 0...1) < 0.5 {
                bits.append(Bit(kind: .foam, p: CGPoint(x: tip.x + .random(in: -16...16), y: tip.y + .random(in: -10...10)),
                                v: CGVector(dx: .random(in: -8...8), dy: .random(in: -24 ... -6)), life: 1.0, size: .random(in: 2.5...6)))
            }
            if hypot(tip.x - BeautyPainter.eyes[0].x, tip.y - BeautyPainter.eyes[0].y) < 50
                || hypot(tip.x - BeautyPainter.eyes[1].x, tip.y - BeautyPainter.eyes[1].y) < 50 {
                blinkUntil = now + 0.3
            }
        }
    }

    private func pourGlitter(_ tip: CGPoint, dt: Double) {
        let expected = dt * 46
        let n = Int(expected) + (Double.random(in: 0...1) < expected - Double(Int(expected)) ? 1 : 0)
        for _ in 0..<n {
            bits.append(Bit(kind: .fleck, p: CGPoint(x: tip.x + .random(in: -7...7), y: tip.y + .random(in: -3...3)),
                            v: CGVector(dx: .random(in: -45...45), dy: .random(in: 10...70)), life: 2.5, size: .random(in: 1.6...3.2),
                            hex: color, landAt: .random(in: 0.07...0.34)))
        }
    }

    // MARK: Nails

    private func brush(at tip: CGPoint, moved d: CGFloat) {
        guard load > 0.01 else { return }
        let isGlitter = color == "glitter"
        let step = max(0.6, Double(d) / 5)
        if let i = CloseHand.nail(at: tip, slack: 0.12) {
            let (u, v) = CloseHand.toNail(i, tip)
            if isGlitter {
                if cells[i].contains(where: { $0 > 0.3 }) && !glitterCoat[i] {
                    glitterCoat[i] = true
                    sparkle(onNail: i, count: 6)
                    BeautySound.shared.play(.tinkle, volume: 0.6, gap: 0.3)
                }
                wet[i] = max(wet[i], 0.6)
                load = max(0, load - 0.004 * step)
            } else {
                let brushColor = RGB(hex: color)
                var used = 0.0
                for k in 0..<NailGrid.count where NailGrid.inside[k] {
                    let (cu, cv) = NailGrid.center(k)
                    let du = (cu - u) / 0.5, dv = (cv - v) / 0.17
                    let w = 1 - (du * du + dv * dv)
                    guard w > 0 else { continue }
                    // a fresh coat over dry polish starts over in the new color
                    if wet[i] < 0.05 && cells[i][k] > 0.3 && !coated.contains(i) {
                        coated.insert(i)
                        coats[i] = min(3, coats[i] + 1)
                    }
                    let dep = load * 0.11 * w * step
                    let before = cells[i][k]
                    if before < 0.05 || wet[i] < 0.05 {
                        tints[i][k] = before < 0.05 ? brushColor : tints[i][k].mix(brushColor, min(1, 0.6 + w * 0.4))
                    } else {
                        tints[i][k] = tints[i][k].mix(brushColor, min(1, 0.3 * w * step))
                    }
                    cells[i][k] = before + dep
                    used += dep
                }
                if coats[i] == 0 { coats[i] = 1 }
                wet[i] = 1
                load = max(0, load - used / 120)
                if d > 0.5 { BeautySound.shared.play(.polish, volume: 0.55, gap: 0.22) }
            }
            smear = nil
        } else if CloseHand.onSkin(tip), !isGlitter, load > 0.2, d > 0.5 {
            // oops: polish on her skin
            if smear == nil {
                spills.append(Spill(pts: [], widths: [], color: RGB(hex: color), wet: 1))
                smear = spills.count - 1
            }
            if let s = smear {
                spills[s].pts.append(tip)
                spills[s].widths.append(CGFloat(6 + 8 * load))
                spills[s].wet = 1
                load = max(0, load - 0.006 * step)
            }
        }
    }

    private func remove(at tip: CGPoint, moved d: CGFloat) {
        let r: CGFloat = 22
        var hit = false
        for s in spills.indices {
            var keepP: [CGPoint] = [], keepW: [CGFloat] = []
            for (j, p) in spills[s].pts.enumerated() {
                if hypot(p.x - tip.x, p.y - tip.y) > r { keepP.append(p); keepW.append(spills[s].widths[j]) } else { hit = true }
            }
            spills[s].pts = keepP
            spills[s].widths = keepW
        }
        drips.removeAll { hypot($0.p.x - tip.x, $0.p.y - tip.y) < r }
        if let i = CloseHand.nail(at: tip, slack: 0.1) {
            let (u, v) = CloseHand.toNail(i, tip)
            for k in 0..<NailGrid.count where cells[i][k] > 0 {
                let (cu, cv) = NailGrid.center(k)
                let du = (cu - u) / 0.6, dv = (cv - v) / 0.22
                let w = 1 - (du * du + dv * dv)
                guard w > 0 else { continue }
                cells[i][k] = max(0, cells[i][k] - 0.16 * w * max(0.6, Double(d) / 5))
                hit = true
            }
            if !cells[i].contains(where: { $0 > 0.05 }) { coats[i] = 0; glitterCoat[i] = false }
            // gems pop off when rubbed
            if d > 2, let g = gems[i].firstIndex(where: { gm in
                let p = CloseHand.fromNail(i, u: Double(gm.u), v: Double(gm.v))
                return hypot(p.x - tip.x, p.y - tip.y) < 24 }) {
                let gm = gems[i].remove(at: g)
                let p = CloseHand.fromNail(i, u: Double(gm.u), v: Double(gm.v))
                bits.append(Bit(kind: .gem, p: p, v: CGVector(dx: .random(in: -80...80), dy: -140), life: 3, size: CloseHand.fingers[i].width * 0.3,
                                color: RGB(hex: gm.color), hex: gm.color, gem: gm.kind))
                BeautySound.shared.play(.clink, volume: 0.6)
            }
        }
        spills.removeAll { $0.pts.isEmpty }
        if hit || d > 1 { BeautySound.shared.play(.wipe, volume: 0.55, gap: 0.3) }
    }

    private func dropGem(at tip: CGPoint) {
        if let i = CloseHand.nail(at: tip, slack: 0.05), gems[i].count < 6 {
            let (u, v) = CloseHand.toNail(i, tip)
            gems[i].append(NailGem(kind: gemKind, color: gemColor, u: Float(max(-0.7, min(0.7, u))), v: Float(max(0.15, min(0.85, v))),
                                   turn: Float.random(in: -20...20)))
            BeautySound.shared.play(.clink, volume: 0.8)
            Sound.shared.tap()
            sparkle(onNail: i, count: 4)
        } else {
            // missed: it bounces off and falls
            bits.append(Bit(kind: .gem, p: tip, v: CGVector(dx: .random(in: -60...60), dy: -60), life: 3, size: 22,
                            color: RGB(hex: gemColor), hex: gemColor, gem: gemKind))
            BeautySound.shared.play(.clink, volume: 0.5)
        }
    }

    func dip() {
        load = 1
        BeautySound.shared.play(.dip, volume: 0.7)
    }

    private func sparkle(onNail i: Int, count: Int) {
        for _ in 0..<count {
            let p = CloseHand.fromNail(i, u: .random(in: -0.8...0.8), v: .random(in: 0.1...0.9))
            bits.append(Bit(kind: .spark, p: p, v: CGVector(dx: .random(in: -30...30), dy: .random(in: -60 ... -20)), life: 0.8,
                            size: .random(in: 5...9)))
        }
    }

    // MARK: Time

    func step(to t: Double) {
        now = t
        let dt = min(1.0 / 20, max(0, t - (lastTime ?? t)))
        lastTime = t
        guard dt > 0 else { return }
        if mode == .makeup { stepMakeup(dt) } else { stepNails(dt) }
        stepBits(dt)
    }

    private func stepMakeup(_ dt: Double) {
        if tool == .glitter, let tip = tipOnStage.map(toArt) { pourGlitter(tip, dt: dt) }
        if tool == .shadow, let tip = tipOnStage.map(toArt) {
            for e in BeautyPainter.eyes where hypot(tip.x - e.x, tip.y - e.y) < 48 { blinkUntil = now + 0.25 }
        }
        if now > nextBlink {
            blinkUntil = max(blinkUntil, now + 0.14)
            nextBlink = now + .random(in: 2.4...5)
        }
    }

    private func stepNails(_ dt: Double) {
        let dryerTip = tool == .dryer ? tipOnStage.map(toArt) : nil
        if let d = dryerTip {
            BeautySound.shared.play(.dryer, volume: 0.45, gap: 0.45)
            for _ in 0..<2 {
                bits.append(Bit(kind: .air, p: CGPoint(x: d.x + .random(in: -26...26), y: d.y - 10),
                                v: CGVector(dx: .random(in: -30...30), dy: .random(in: -340 ... -220)), life: 0.5, size: .random(in: 10...22)))
            }
        }
        for i in 0..<5 where wet[i] > 0 {
            // wet polish flows a little and levels out
            flow(i, dt: dt)
            var rate = 1.0 / 7
            if let d = dryerTip {
                let c = CloseHand.fromNail(i, u: 0, v: 0.5)
                let dx = c.x - d.x, dy = d.y - c.y
                if dy > -30, dy < 260, abs(dx) < 90 + dy * 0.4 { rate = 1.0 / 1.2 }
            }
            let before = wet[i]
            wet[i] = max(0, wet[i] - dt * rate)
            if before > 0, wet[i] == 0 { dried(i) }
            // piled-up polish runs down her finger
            if before > 0.3, now - lastDrip > 0.35, let k = cells[i].indices.max(by: { cells[i][$0] < cells[i][$1] }), cells[i][k] > 1.75 {
                let extra = cells[i][k] - 1.25
                cells[i][k] = 1.25
                let (u, v) = NailGrid.center(k)
                let p = CloseHand.fromNail(i, u: u, v: max(0, v - 0.08))
                spills.append(Spill(pts: [p], widths: [10], color: tints[i][k], wet: 1))
                drips.append(Drip(p: p, v: CGVector(dx: 0, dy: 8), mass: min(1.2, extra * 1.6), color: tints[i][k], spill: spills.count - 1))
                lastDrip = now
                BeautySound.shared.play(.drip, volume: 0.6)
            }
        }
        // drips: gravity pulls, the thick polish holds back, a trail is left behind
        var keep: [Drip] = []
        for var d in drips {
            d.v.dy += 240 * dt
            d.v.dx += CGFloat.random(in: -20...20) * dt
            let drag = CGFloat(exp(-5 * dt))
            d.v.dx *= drag; d.v.dy *= drag
            let mv = CGPoint(x: d.v.dx * dt, y: d.v.dy * dt)
            d.p.x += mv.x; d.p.y += mv.y
            let dist = hypot(mv.x, mv.y)
            d.mass -= dt * 0.12 + Double(dist) * 0.006
            d.trail += dist
            if d.trail > 2.5, d.spill < spills.count {
                d.trail = 0
                spills[d.spill].pts.append(d.p)
                spills[d.spill].widths.append(CGFloat(5 + 10 * sqrt(max(0, d.mass))))
                spills[d.spill].wet = 1
            }
            if d.mass > 0.04, d.p.y < CloseHand.size.height + 10 { keep.append(d) }
        }
        drips = keep
        for s in spills.indices { spills[s].wet = max(0, spills[s].wet - dt / 9) }
    }

    /// Wet polish spreads to its neighbors (only inside the nail).
    private func flow(_ i: Int, dt: Double) {
        let cols = NailGrid.cols, n = NailGrid.count
        let rate = 1.6 * dt * wet[i]
        var next = cells[i]
        var nextTint = tints[i]
        for k in 0..<n where NailGrid.inside[k] {
            let c = k % cols
            var sum = 0.0, cnt = 0.0
            var mixC: RGB?
            for j in [k - 1, k + 1, k - cols, k + cols] {
                guard j >= 0, j < n, NailGrid.inside[j], abs((j % cols) - c) <= 1 else { continue }
                sum += cells[i][j]; cnt += 1
                if cells[i][j] > cells[i][k] + 0.2 { mixC = tints[i][j] }
            }
            guard cnt > 0 else { continue }
            let avg = sum / cnt
            // only spreads where there is enough polish to move
            if avg > 0.15 || cells[i][k] > 0.15 {
                next[k] = cells[i][k] + (avg - cells[i][k]) * min(1, rate)
                if let m = mixC { nextTint[k] = cells[i][k] < 0.05 ? m : tints[i][k].mix(m, min(1, rate * 0.5)) }
            }
        }
        cells[i] = next
        tints[i] = nextTint
    }

    /// The polish has set: patchy bits level out into a smooth, glossy coat.
    private func dried(_ i: Int) {
        let inside = (0..<NailGrid.count).filter { NailGrid.inside[$0] }
        let covered = inside.filter { cells[i][$0] >= 0.3 }
        guard !covered.isEmpty else { return }
        var avg = RGB(0, 0, 0)
        for k in covered { avg = RGB(avg.r + tints[i][k].r, avg.g + tints[i][k].g, avg.b + tints[i][k].b) }
        avg = RGB(avg.r / Double(covered.count), avg.g / Double(covered.count), avg.b / Double(covered.count))
        let full = Double(covered.count) / Double(inside.count) >= 0.72
        for k in 0..<NailGrid.count {
            if cells[i][k] >= 0.3 || (full && NailGrid.inside[k]) {
                if cells[i][k] < 0.3 { tints[i][k] = avg }
                cells[i][k] = 1
            } else {
                cells[i][k] = 0
            }
        }
        BeautySound.shared.play(.dry, volume: 0.55)
        sparkle(onNail: i, count: 5)
        syncNails()
    }

    private func stepBits(_ dt: Double) {
        var keep: [Bit] = []
        for var b in bits {
            b.age += dt
            switch b.kind {
            case .dust:
                b.v.dy += 30 * dt
                b.v.dx *= CGFloat(exp(-2 * dt))
            case .foam:
                b.v.dy *= CGFloat(exp(-3 * dt))
            case .air, .spark:
                break
            case .fleck:
                b.v.dy += 620 * dt
                b.v.dx *= CGFloat(exp(-1.5 * dt))
                if b.landAt > 0, b.age >= b.landAt {
                    b.landAt = 0
                    let face = BeautyPainter.faceClip(look)
                    if face.contains(b.p), let s = glitterStroke(b.hex) {
                        look.makeup[s].pts += [Float(b.p.x), Float(b.p.y)]
                        trimMakeup()
                        BeautySound.shared.play(.tinkle, volume: 0.35, gap: 0.3)
                        continue
                    }
                }
            case .gem:
                b.v.dy += 900 * dt
                if b.p.y > box.maxY - 30, b.v.dy > 0 {
                    b.p.y = box.maxY - 30
                    b.v.dy *= -0.45
                    b.v.dx *= 0.7
                    if !b.bounced || abs(b.v.dy) > 60 { BeautySound.shared.play(.clink, volume: 0.4, gap: 0.08) }
                    b.bounced = true
                }
            case .drop:
                b.v.dy += 900 * dt
            }
            b.p.x += b.v.dx * dt
            b.p.y += b.v.dy * dt
            if b.age < b.life, b.p.y < box.maxY + 80 { keep.append(b) }
        }
        bits = keep
        if bits.count > 900 { bits.removeFirst(bits.count - 900) }
    }

    /// Where a landing fleck goes: the glitter stroke being poured, or the last one of its color.
    private func glitterStroke(_ hex: String) -> Int? {
        if let s = stroke, s < look.makeup.count, look.makeup[s].tool == "glitter", look.makeup[s].color == hex { return s }
        if let s = look.makeup.lastIndex(where: { $0.tool == "glitter" && $0.color == hex }) { return s }
        look.makeup.append(BeautyStroke(tool: "glitter", color: hex))
        return look.makeup.count - 1
    }

    // MARK: Saving and undo

    private func saveUndo() {
        if mode == .makeup {
            undoMakeup.append(look.makeup)
            if undoMakeup.count > 20 { undoMakeup.removeFirst() }
        } else {
            undoNails.append(NailSnap(cells: cells, tints: tints, coats: coats, glitter: glitterCoat, gems: gems, spills: spills))
            if undoNails.count > 20 { undoNails.removeFirst() }
        }
    }

    var canUndo: Bool { mode == .makeup ? !undoMakeup.isEmpty : !undoNails.isEmpty }

    func undo() {
        if mode == .makeup {
            guard let last = undoMakeup.popLast() else { return }
            look.makeup = last
        } else {
            guard let s = undoNails.popLast() else { return }
            cells = s.cells; tints = s.tints; coats = s.coats; glitterCoat = s.glitter; gems = s.gems; spills = s.spills
            drips = []
            wet = Array(repeating: 0, count: 5)
            syncNails()
        }
        BeautySound.shared.play(.wipe, volume: 0.5)
    }

    /// Takes everything off (the makeup, or the polish), with undo.
    func clearAll() {
        saveUndo()
        if mode == .makeup {
            look.makeup = []
        } else {
            cells = Array(repeating: Array(repeating: 0, count: NailGrid.count), count: 5)
            coats = Array(repeating: 0, count: 5)
            glitterCoat = Array(repeating: false, count: 5)
            wet = Array(repeating: 0, count: 5)
            gems = Array(repeating: [], count: 5)
            spills = []
            drips = []
            syncNails()
        }
        BeautySound.shared.play(.wipe, volume: 0.7)
    }

    /// Writes the nails into the look (what the doll wears).
    func syncNails() {
        var out: [NailPaint] = []
        for i in 0..<5 {
            var n = NailPaint()
            let bits = cells[i].map { $0 >= 0.3 }
            if bits.contains(true) {
                var avg = RGB(0, 0, 0), cnt = 0.0
                for k in 0..<NailGrid.count where bits[k] { avg = RGB(avg.r + tints[i][k].r, avg.g + tints[i][k].g, avg.b + tints[i][k].b); cnt += 1 }
                n.color = PaintMix.hex(RGB(avg.r / cnt, avg.g / cnt, avg.b / cnt))
                n.mask = NailGrid.encode(bits)
            }
            n.coats = n.color == nil ? 0 : max(1, coats[i])
            n.glitter = n.color != nil && glitterCoat[i]
            n.gems = gems[i]
            out.append(n)
        }
        look.nails = out
    }

    func finished() -> Look {
        for i in 0..<5 where wet[i] > 0 { wet[i] = 0; dried(i) }
        syncNails()
        return look.sanitized()
    }

    // MARK: Drawing

    func draw(in ctx: inout GraphicsContext) {
        var g = ctx
        apply(&g)
        if mode == .makeup {
            let expr: Expression = now < smileUntil ? .happy : (now < blinkUntil ? .blink : .normal)
            var d = ctx
            DollPainter.paintDoll(look, expr, box: box, in: &d, size: size, t: now)
        } else {
            drawNails(in: g)
        }
        drawBits(in: g)
        if let f = finger { drawTool(at: f, in: ctx) }
    }

    private func drawNails(in g: GraphicsContext) {
        let skin = DressUpArt.shared.skin[safe: look.skin] ?? RGB(1, 0.86, 0.8)
        CloseHand.drawHand(skin: skin, in: g)
        // spills on her skin (under the nails' own polish)
        for s in spills where !s.pts.isEmpty {
            g.drawLayer { l in
                l.addFilter(.blur(radius: 0.8))
                for (j, p) in s.pts.enumerated() {
                    let r = s.widths[j] / 2
                    l.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(s.color.color.opacity(0.92)))
                }
            }
            if let p = s.pts.last, let w = s.widths.last {
                let r = w * 0.18
                g.fill(Path(ellipseIn: CGRect(x: p.x - w * 0.25, y: p.y - w * 0.2, width: r * 2, height: r * 2)),
                       with: .color(.white.opacity(0.35 + 0.35 * s.wet)))
            }
        }
        for i in 0..<5 {
            CloseHand.drawPolish(i, cells: cells[i], colors: tints[i], coats: coats[i], glitter: glitterCoat[i], wet: wet[i],
                                 gems: gems[i], t: now, in: g)
        }
        // drips: a shiny bead at the front of each run
        for d in drips {
            let r = CGFloat(4 + 6 * sqrt(max(0, d.mass)))
            g.fill(Path(ellipseIn: CGRect(x: d.p.x - r, y: d.p.y - r * 0.8, width: r * 2, height: r * 2.1)), with: .color(d.color.color))
            g.fill(Path(ellipseIn: CGRect(x: d.p.x - r * 0.5, y: d.p.y - r * 0.5, width: r * 0.6, height: r * 0.6)), with: .color(.white.opacity(0.7)))
        }
    }

    private func drawBits(in g: GraphicsContext) {
        for b in bits {
            let fade = max(0, 1 - b.age / b.life)
            var c = g
            switch b.kind {
            case .dust:
                c.opacity = 0.5 * fade
                c.fill(Path(ellipseIn: CGRect(x: b.p.x - b.size, y: b.p.y - b.size, width: b.size * 2, height: b.size * 2)), with: .color(b.color.color))
            case .foam:
                c.opacity = fade
                let r = b.size
                c.stroke(Path(ellipseIn: CGRect(x: b.p.x - r, y: b.p.y - r, width: r * 2, height: r * 2)), with: .color(.white), lineWidth: 1)
                c.fill(Path(ellipseIn: CGRect(x: b.p.x - r, y: b.p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.35)))
            case .fleck:
                c.opacity = min(1, fade * 2)
                BeautyPainter.fleck(at: b.p, index: Int(b.size * 1000), color: b.hex, t: now, scale: 1, in: c)
            case .air:
                c.opacity = 0.35 * fade
                var p = Path()
                p.move(to: b.p)
                p.addLine(to: CGPoint(x: b.p.x - b.v.dx * 0.05, y: b.p.y - b.v.dy * 0.05))
                c.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            case .spark:
                c.opacity = fade
                let s = CloseHand.star(b.size * CGFloat(0.6 + 0.4 * fade)).applying(CGAffineTransform(translationX: b.p.x, y: b.p.y))
                c.fill(s, with: .color(Color(hex: 0xFFE27A)))
            case .gem:
                c.opacity = min(1, fade * 3)
                CloseHand.drawGem(b.gem, color: b.color, at: b.p, size: b.size, turn: b.age * 200, t: now, in: c)
            case .drop:
                c.fill(Path(ellipseIn: CGRect(x: b.p.x - b.size, y: b.p.y - b.size, width: b.size * 2, height: b.size * 2)), with: .color(b.color.color))
            }
        }
    }

    /// The tool in her hand: its tip `lift` points above her finger.
    private func drawTool(at f: CGPoint, in ctx: GraphicsContext) {
        let tip = CGPoint(x: f.x, y: f.y - Self.lift)
        BeautyTools.draw(tool, color: color, gem: (gemKind, gemColor), load: load, tip: tip, finger: f, t: now, in: ctx)
        // a soft ring where it touches
        ctx.stroke(Path(ellipseIn: CGRect(x: tip.x - 9, y: tip.y - 9, width: 18, height: 18)), with: .color(.white.opacity(0.7)), lineWidth: 2)
    }
}

// MARK: - Tool pictures (in the studio and on the buttons)

enum BeautyTools {
    static func draw(_ tool: BeautyWorld.Tool, color: String, gem: (String, String), load: Double, tip: CGPoint, finger f: CGPoint,
                     t: Double, in ctx: GraphicsContext) {
        let ink = Color(hex: 0x5B3A68)
        let c = BeautyColors.rgb(color == "glitter" ? "#F4E9FF" : color, Int(t * 6))
        var g = ctx
        g.addFilter(.shadow(color: ink.opacity(0.25), radius: 6, x: 0, y: 5))
        func rr(_ r: CGRect, _ rad: CGFloat) -> Path { Path(roundedRect: r, cornerRadius: rad) }
        switch tool {
        case .blush:
            g.fill(rr(CGRect(x: tip.x - 8, y: tip.y + 34, width: 16, height: f.y - tip.y), 8), with: .color(Color(hex: 0xF45C9A)))
            g.fill(rr(CGRect(x: tip.x - 11, y: tip.y + 20, width: 22, height: 22), 5), with: .color(Color(hex: 0xD9D4E0)))
            g.fill(Path(ellipseIn: CGRect(x: tip.x - 22, y: tip.y - 12, width: 44, height: 44)), with: .color(Color(hex: 0xF2DFC8)))
            g.fill(Path(ellipseIn: CGRect(x: tip.x - 18, y: tip.y - 10, width: 36, height: 22)), with: .color(c.color.opacity(0.85)))
        case .shadow:
            g.fill(rr(CGRect(x: tip.x - 4, y: tip.y + 22, width: 8, height: f.y - tip.y - 4), 4), with: .color(Color(hex: 0x9B79E0)))
            var sp = Path()
            sp.move(to: CGPoint(x: tip.x, y: tip.y - 6))
            sp.addCurve(to: CGPoint(x: tip.x, y: tip.y + 26), control1: CGPoint(x: tip.x + 22, y: tip.y + 4), control2: CGPoint(x: tip.x + 14, y: tip.y + 26))
            sp.addCurve(to: CGPoint(x: tip.x, y: tip.y - 6), control1: CGPoint(x: tip.x - 14, y: tip.y + 26), control2: CGPoint(x: tip.x - 22, y: tip.y + 4))
            g.fill(sp, with: .color(Color(hex: 0x3A3346)))
            g.fill(sp.applying(CGAffineTransform(translationX: 0, y: -2)).applying(.identity), with: .color(c.color.opacity(0.9)))
        case .lip:
            g.fill(rr(CGRect(x: tip.x - 15, y: tip.y + 30, width: 30, height: max(30, f.y - tip.y - 20)), 6),
                   with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE9A8), Color(hex: 0xD9A441)]),
                                         startPoint: CGPoint(x: tip.x - 15, y: 0), endPoint: CGPoint(x: tip.x + 15, y: 0)))
            var bullet = Path()
            bullet.move(to: CGPoint(x: tip.x - 11, y: tip.y + 32))
            bullet.addLine(to: CGPoint(x: tip.x - 11, y: tip.y + 8))
            bullet.addQuadCurve(to: CGPoint(x: tip.x + 11, y: tip.y - 6), control: CGPoint(x: tip.x - 6, y: tip.y - 8))
            bullet.addLine(to: CGPoint(x: tip.x + 11, y: tip.y + 32))
            bullet.closeSubpath()
            g.fill(bullet, with: .color(c.color))
            g.fill(rr(CGRect(x: tip.x - 7, y: tip.y + 6, width: 4, height: 20), 2), with: .color(.white.opacity(0.4)))
        case .glitter:
            let shake = CGFloat(sin(t * 30)) * 3
            let jar = CGRect(x: tip.x - 24 + shake, y: tip.y + 10, width: 48, height: 58)
            g.fill(rr(jar, 12), with: .color(.white.opacity(0.85)))
            var inner = g
            inner.clip(to: rr(jar.insetBy(dx: 4, dy: 4), 9))
            inner.fill(Path(jar.insetBy(dx: 4, dy: 4)), with: .color(c.color.opacity(0.9)))
            for k in 0..<10 {
                let h = BeautyPainter.hash(k)
                inner.fill(Path(ellipseIn: CGRect(x: jar.minX + CGFloat(h % 40) + 4, y: jar.minY + CGFloat((h >> 8) % 50) + 4, width: 3, height: 3)),
                           with: .color(.white.opacity(0.9)))
            }
            g.fill(rr(CGRect(x: tip.x - 20 + shake, y: tip.y - 2, width: 40, height: 16), 5), with: .color(Color(hex: 0xC9B6FF)))
            for k in -1...1 {
                g.fill(Path(ellipseIn: CGRect(x: tip.x + CGFloat(k) * 10 - 2 + shake, y: tip.y + 2, width: 4, height: 4)), with: .color(ink.opacity(0.6)))
            }
        case .wipe:
            g.fill(Path(ellipseIn: CGRect(x: tip.x - 30, y: tip.y - 26, width: 60, height: 60)), with: .color(.white))
            for k in 0..<7 {
                let a = Double(k) * .pi * 2 / 7
                g.fill(Path(ellipseIn: CGRect(x: tip.x + CGFloat(cos(a)) * 16 - 2, y: tip.y + 4 + CGFloat(sin(a)) * 16 - 2, width: 4, height: 4)),
                       with: .color(Color(hex: 0xE6D6E0)))
            }
            g.stroke(Path(ellipseIn: CGRect(x: tip.x - 30, y: tip.y - 26, width: 60, height: 60)), with: .color(Color(hex: 0xE6D6E0)), lineWidth: 2)
        case .polish:
            let glitter = color == "glitter"
            let cap = CGRect(x: tip.x - 15, y: tip.y + 44, width: 30, height: max(40, f.y - tip.y - 30))
            g.fill(rr(cap, 9), with: .linearGradient(Gradient(colors: [Color(hex: 0x4A4258), Color(hex: 0x2A2433)]),
                                                     startPoint: CGPoint(x: cap.minX, y: 0), endPoint: CGPoint(x: cap.maxX, y: 0)))
            g.fill(rr(CGRect(x: cap.minX + 5, y: cap.minY + 6, width: 5, height: cap.height - 12), 2.5), with: .color(.white.opacity(0.25)))
            g.fill(Path(CGRect(x: tip.x - 2, y: tip.y + 22, width: 4, height: 24)), with: .color(Color(hex: 0x8F8799)))
            var bristles = Path()
            bristles.move(to: CGPoint(x: tip.x - 8, y: tip.y + 24))
            bristles.addQuadCurve(to: CGPoint(x: tip.x, y: tip.y - 4), control: CGPoint(x: tip.x - 9, y: tip.y + 4))
            bristles.addQuadCurve(to: CGPoint(x: tip.x + 8, y: tip.y + 24), control: CGPoint(x: tip.x + 9, y: tip.y + 4))
            bristles.closeSubpath()
            g.fill(bristles, with: .color(Color(hex: 0xEDE4D6)))
            if load > 0.02 {
                var wetB = g
                wetB.opacity = 0.35 + 0.65 * load
                wetB.fill(bristles, with: .color(glitter ? Color(hex: 0xF4E9FF) : c.color))
                if glitter {
                    for k in 0..<5 {
                        BeautyPainter.fleck(at: CGPoint(x: tip.x - 4 + CGFloat(k * 2), y: tip.y + 4 + CGFloat((k * 7) % 16)), index: k + 3,
                                            color: "rainbow", t: t, scale: 1.2, in: wetB)
                    }
                }
                // a bead of polish waiting to fall off a loaded brush
                if load > 0.6 {
                    let r = CGFloat(2 + 3 * load)
                    wetB.fill(Path(ellipseIn: CGRect(x: tip.x + 2, y: tip.y + 14, width: r * 2, height: r * 2.3)), with: .color(glitter ? .white : c.color))
                }
                g.fill(Path(ellipseIn: CGRect(x: tip.x - 4, y: tip.y + 4, width: 3, height: 10)), with: .color(.white.opacity(0.6)))
            }
        case .remover:
            g.fill(rr(CGRect(x: tip.x - 3, y: tip.y + 10, width: 6, height: f.y - tip.y + 10), 3), with: .color(Color(hex: 0xF7F0F4)))
            g.fill(Path(ellipseIn: CGRect(x: tip.x - 11, y: tip.y - 12, width: 22, height: 32)), with: .color(.white))
            g.stroke(Path(ellipseIn: CGRect(x: tip.x - 11, y: tip.y - 12, width: 22, height: 32)), with: .color(Color(hex: 0xE6D6E0)), lineWidth: 2)
            g.fill(Path(ellipseIn: CGRect(x: tip.x - 11, y: f.y - 6, width: 22, height: 30)), with: .color(.white))
        case .dryer:
            g.fill(rr(CGRect(x: tip.x - 10, y: tip.y + 30, width: 20, height: f.y - tip.y), 9), with: .color(Color(hex: 0x46B7B0)))
            let head = CGRect(x: tip.x - 34, y: tip.y - 30, width: 68, height: 68)
            g.fill(Path(ellipseIn: head), with: .color(Color(hex: 0x9FE3CF)))
            g.stroke(Path(ellipseIn: head), with: .color(.white), lineWidth: 4)
            var blades = g
            blades.translateBy(x: tip.x, y: tip.y + 4)
            blades.rotate(by: .radians(t * 24))
            for k in 0..<4 {
                var b = blades
                b.rotate(by: .degrees(Double(k) * 90))
                b.fill(Path(ellipseIn: CGRect(x: -6, y: -27, width: 12, height: 26)), with: .color(.white.opacity(0.85)))
            }
            blades.fill(Path(ellipseIn: CGRect(x: -6, y: -6, width: 12, height: 12)), with: .color(Color(hex: 0x46B7B0)))
        case .gem:
            var tw = Path()
            tw.move(to: CGPoint(x: tip.x - 3, y: tip.y + 12)); tw.addLine(to: CGPoint(x: tip.x - 8, y: f.y))
            tw.move(to: CGPoint(x: tip.x + 3, y: tip.y + 12)); tw.addLine(to: CGPoint(x: tip.x + 8, y: f.y))
            g.stroke(tw, with: .color(Color(hex: 0xB9B3C6)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            CloseHand.drawGem(gem.0, color: RGB(hex: gem.1), at: tip, size: 26, turn: 0, t: t, in: ctx)
        }
    }
}

/// A little picture of a tool for its button.
struct BeautyToolIcon: View {
    let tool: BeautyWorld.Tool
    var color: String

    var body: some View {
        Canvas { ctx, size in
            var g = ctx
            let k = min(size.width, size.height) / 150
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: k, y: k)
            g.rotate(by: .degrees(30))
            BeautyTools.draw(tool, color: color, gem: ("g_round", "#E8F4FF"), load: 1, tip: CGPoint(x: 0, y: -38),
                             finger: CGPoint(x: 0, y: 70), t: 0, in: g)
        }
    }
}

// MARK: - The studio screen

struct BeautyStudio: View {
    let done: (Look) -> Void
    @State private var world: BeautyWorld
    @State private var mode: BeautyWorld.Mode
    @State private var tick = 0

    init(look: Look, mode: BeautyWorld.Mode, done: @escaping (Look) -> Void) {
        self.done = done
        _world = State(initialValue: BeautyWorld(look: look, mode: mode))
        _mode = State(initialValue: mode)
    }

    private static let stageSize = CGSize(width: 600, height: 790)

    var body: some View {
        let _ = tick
        ZStack {
            LinearGradient(colors: [Color(hex: 0xFFE3EE), Color(hex: 0xF3E6FF)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            DesignCanvas {
                HStack(spacing: 18) {
                    stage
                        .frame(width: Self.stageSize.width, height: Self.stageSize.height)
                        .padding(.leading, 22)
                    panel
                        .padding(.vertical, 22)
                        .padding(.trailing, 22)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: Stage

    private var stage: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                world.size = size
                world.step(to: t)
                drawBackdrop(in: ctx, size: size, t: t)
                var c = ctx
                world.draw(in: &c)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 6))
        .shadow(color: Theme.ink.opacity(0.2), radius: 14, y: 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if world.finger == nil { world.press(v.location) } else { world.move(v.location) }
                }
                .onEnded { _ in
                    world.release()
                    tick += 1
                }
        )
    }

    /// A lit vanity mirror for makeup, a manicure towel for nails.
    private func drawBackdrop(in ctx: GraphicsContext, size: CGSize, t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        if world.mode == .makeup {
            ctx.fill(Path(rect), with: .color(Color(hex: 0xF7D9E6)))
            let mirror = rect.insetBy(dx: 26, dy: 26)
            ctx.fill(Path(roundedRect: mirror, cornerRadius: 200),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xE9F4FF), Color(hex: 0xFFF3FA)]),
                                           startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height)))
            // a soft reflection streak
            var streak = Path()
            streak.move(to: CGPoint(x: mirror.minX + 70, y: mirror.minY + 140))
            streak.addLine(to: CGPoint(x: mirror.minX + 160, y: mirror.minY + 50))
            ctx.stroke(streak, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 20, lineCap: .round))
            ctx.stroke(Path(roundedRect: mirror, cornerRadius: 200), with: .color(Color(hex: 0xFFFFFF)), lineWidth: 14)
            // the bulbs around the mirror, glowing
            let n = 14
            for k in 0..<n {
                let a = Double(k) / Double(n) * 2 * .pi
                let p = CGPoint(x: size.width / 2 + CGFloat(cos(a)) * (size.width / 2 - 20), y: size.height / 2 + CGFloat(sin(a)) * (size.height / 2 - 20))
                let glow = 0.75 + 0.25 * sin(t * 1.7 + Double(k))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)), with: .color(Color(hex: 0xFFF1B8).opacity(0.35 * glow)))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)), with: .color(Color(hex: 0xFFF7DC)))
                ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)), with: .color(Color(hex: 0xF2C14E).opacity(0.6)), lineWidth: 2)
            }
        } else {
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF3F7), Color(hex: 0xFCE1EC)]),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            // a fluffy towel under her hand
            let towel = CGRect(x: 20, y: size.height * 0.58, width: size.width - 40, height: size.height * 0.5)
            ctx.fill(Path(roundedRect: towel, cornerRadius: 40), with: .color(Color(hex: 0xC9F0E4)))
            for y in stride(from: towel.minY + 24, to: towel.maxY, by: 26) {
                var line = Path()
                line.move(to: CGPoint(x: towel.minX + 20, y: y)); line.addLine(to: CGPoint(x: towel.maxX - 20, y: y))
                ctx.stroke(line, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 8]))
            }
        }
    }

    // MARK: Panel

    private var panel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                modeButton(.makeup, symbol: "paintbrush.pointed.fill")
                modeButton(.nails, symbol: "hand.raised.fill")
                Spacer()
                RoundButton(symbol: "arrow.uturn.backward", tint: Color(hex: 0x9B79E0), size: 60) {
                    world.undo(); tick += 1
                }
                .opacity(world.canUndo ? 1 : 0.4)
                RoundButton(symbol: "checkmark", tint: Color(hex: 0x6CCB8B), size: 60) {
                    Sound.shared.play(.fanfare, volume: 0.7)
                    done(world.finished())
                }
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    toolRow
                    colorGrid
                    HStack {
                        if world.mode == .nails && world.tool == .polish {
                            Button { world.dip(); tick += 1 } label: { panelLabel("drop.fill", "Dip", Color(hex: 0xF45C9A)) }
                                .buttonStyle(Squish())
                        }
                        Spacer()
                        Button { world.clearAll(); tick += 1 } label: { panelLabel("trash.fill", nil, Color(hex: 0xE8475A)) }
                            .buttonStyle(Squish())
                    }
                }
                .padding(4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(.white.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 5))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
    }

    private func panelLabel(_ symbol: String, _ text: String?, _ tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 64, height: 56)
            .background(Capsule().fill(tint))
            .overlay(Capsule().stroke(.white, lineWidth: 3))
    }

    private func modeButton(_ m: BeautyWorld.Mode, symbol: String) -> some View {
        Button {
            guard world.mode != m else { return }
            Sound.shared.play(.whoosh, volume: 0.6)
            let look = world.finished()
            world = BeautyWorld(look: look, mode: m)
            mode = m
            tick += 1
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(world.mode == m ? .white : Theme.pink)
                .frame(width: 84, height: 64)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(world.mode == m ? Theme.pink.opacity(0.9) : Theme.blush.opacity(0.7)))
        }
        .buttonStyle(Squish())
    }

    private var tools: [BeautyWorld.Tool] {
        world.mode == .makeup ? [.blush, .shadow, .lip, .glitter, .wipe] : [.polish, .remover, .dryer, .gem]
    }

    private func colors(for tool: BeautyWorld.Tool) -> [String] {
        switch tool {
        case .blush: return BeautyColors.blush
        case .shadow: return BeautyColors.shadow
        case .lip: return BeautyColors.lip
        case .glitter: return BeautyColors.glitter
        case .polish: return BeautyColors.polish + ["glitter"]
        default: return []
        }
    }

    private var toolRow: some View {
        HStack(spacing: 10) {
            ForEach(tools, id: \.rawValue) { t in
                Button {
                    Sound.shared.play(.tap)
                    BeautySound.shared.play(t == .blush || t == .shadow ? .compact : (t == .polish ? .cap : .sponge), volume: 0.6)
                    world.tool = t
                    let cs = colors(for: t)
                    if !cs.isEmpty, !cs.contains(world.color) { world.color = cs[0] }
                    tick += 1
                } label: {
                    BeautyToolIcon(tool: t, color: colors(for: t).contains(world.color) ? world.color : (colors(for: t).first ?? "#FF8FB8"))
                        .frame(width: 62, height: 70)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(world.tool == t ? Theme.blush : Color(hex: 0xFFF7FA)))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(world.tool == t ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: world.tool == t ? 5 : 3))
                }
                .buttonStyle(Squish())
            }
        }
    }

    @ViewBuilder private var colorGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        if world.tool == .gem {
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(gemChoices) { choice in
                    Button {
                        Sound.shared.play(.tap)
                        BeautySound.shared.play(.clink, volume: 0.5)
                        world.gemKind = choice.kind
                        world.gemColor = choice.color
                        tick += 1
                    } label: {
                        Canvas { ctx, size in
                            CloseHand.drawGem(choice.kind, color: RGB(hex: choice.color), at: CGPoint(x: size.width / 2, y: size.height / 2),
                                              size: min(size.width, size.height) * 0.62, turn: 0, t: 0, in: ctx)
                        }
                        .frame(height: 64)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(world.gemKind == choice.kind && world.gemColor == choice.color ? Theme.blush : Color(hex: 0xFFF7FA)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(world.gemKind == choice.kind && world.gemColor == choice.color ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: 3))
                    }
                    .buttonStyle(Squish())
                }
            }
        } else if !colors(for: world.tool).isEmpty {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(colors(for: world.tool), id: \.self) { hex in
                    Button {
                        Sound.shared.play(.tap)
                        world.color = hex
                        if world.tool == .polish {
                            BeautySound.shared.play(.cap, volume: 0.6)
                            world.dip()
                        } else {
                            BeautySound.shared.play(.compact, volume: 0.5)
                        }
                        tick += 1
                    } label: {
                        swatch(hex, on: world.color == hex)
                    }
                    .buttonStyle(Squish())
                }
            }
        }
    }

    private struct GemChoice: Identifiable { let id: String; let kind: String; let color: String }

    private var gemChoices: [GemChoice] {
        var out: [GemChoice] = []
        for kind in NailGem.gems {
            for c in ["#E8F4FF", "#FF8FB8", "#7FDBEA", "#F2C14E"] { out.append(GemChoice(id: kind + c, kind: kind, color: c)) }
        }
        for s in NailGem.stickers { out.append(GemChoice(id: s, kind: s, color: s.contains("heart") ? "#F45C9A" : "#FFFFFF")) }
        return out
    }

    /// A pan of powder, a lipstick or a polish bottle.
    @ViewBuilder private func swatch(_ hex: String, on: Bool) -> some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let c = BeautyColors.rgb(hex == "glitter" ? "#F4E9FF" : hex)
            switch world.tool {
            case .polish:
                // a little bottle with a black cap
                let body = CGRect(x: w * 0.22, y: h * 0.42, width: w * 0.56, height: h * 0.5)
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.38, y: h * 0.06, width: w * 0.24, height: h * 0.38), cornerRadius: 5), with: .color(Color(hex: 0x2E2A3A)))
                ctx.fill(Path(roundedRect: body, cornerRadius: 12), with: .color(c.color))
                if hex == "glitter" || hex == "#FFFFFF" {
                    ctx.stroke(Path(roundedRect: body, cornerRadius: 12), with: .color(Color(hex: 0xE6D6E0)), lineWidth: 2)
                }
                if hex == "glitter" {
                    for k in 0..<14 {
                        BeautyPainter.fleck(at: CGPoint(x: body.minX + CGFloat(BeautyPainter.hash(k) % Int(body.width)),
                                                        y: body.minY + CGFloat(BeautyPainter.hash(k + 99) % Int(body.height))),
                                            index: k, color: "rainbow", t: 0, scale: 1.6, in: ctx)
                    }
                }
                ctx.fill(Path(roundedRect: CGRect(x: body.minX + 6, y: body.minY + 6, width: 6, height: body.height - 12), cornerRadius: 3),
                         with: .color(.white.opacity(0.45)))
            default:
                let r = min(w, h) * 0.4
                let ce = CGPoint(x: w / 2, y: h / 2)
                ctx.fill(Path(ellipseIn: CGRect(x: ce.x - r - 5, y: ce.y - r - 5, width: r * 2 + 10, height: r * 2 + 10)), with: .color(Color(hex: 0xEDE4F2)))
                if hex == "rainbow" {
                    ctx.fill(Path(ellipseIn: CGRect(x: ce.x - r, y: ce.y - r, width: r * 2, height: r * 2)),
                             with: .conicGradient(Gradient(colors: (0..<7).map { BeautyColors.rgb("rainbow", $0).color }), center: ce))
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: ce.x - r, y: ce.y - r, width: r * 2, height: r * 2)), with: .color(c.color))
                }
                if world.tool == .glitter {
                    for k in 0..<10 {
                        let h2 = BeautyPainter.hash(k + 5)
                        BeautyPainter.fleck(at: CGPoint(x: ce.x + CGFloat(h2 % 40) - 20, y: ce.y + CGFloat((h2 >> 8) % 40) - 20), index: k,
                                            color: "#FFFFFF", t: 0, scale: 1.4, in: ctx)
                    }
                }
                ctx.fill(Path(ellipseIn: CGRect(x: ce.x - r * 0.6, y: ce.y - r * 0.7, width: r * 0.7, height: r * 0.35)), with: .color(.white.opacity(0.35)))
            }
        }
        .frame(height: 76)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? Theme.blush : Color(hex: 0xFFF7FA)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? Theme.pink : Color(hex: 0xF5DDE8), lineWidth: on ? 5 : 3))
    }
}
