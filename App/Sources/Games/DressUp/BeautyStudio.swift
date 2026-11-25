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
// Every tool is held by its handle, its tip just above her finger; the glitter jar is held
// above her finger so the glitter falls onto the spot below it (see `FingerLift`).

final class BeautyWorld {
    enum Mode { case makeup, nails }
    enum Tool: String { case blush, shadow, lip, glitter, wipe, polish, remover, dryer, gem }

    var mode: Mode
    var look: Look
    var tool: Tool
    var color: String
    var gemKind = "g_round"
    var gemColor = "#E8F4FF"

    /// How far above the finger the tool's tip is (stage points): none, except the glitter jar.
    var lift: CGFloat { tool == .glitter ? FingerLift.pour : FingerLift.tool }
    /// How long a tool's handle is drawn, from its tip toward her hand.
    static let handle: CGFloat = 84
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

    var tipOnStage: CGPoint? {
        finger.map {
            FingerLift.point(
                $0,
                lift: lift,
                top: 0,
                bottom: size.height > 0 ? size.height : nil,
                width: size.width > 0 ? size.width : nil
            )
        }
    }

    var hasNailArt: Bool {
        cells.contains { $0.contains { $0 >= 0.3 } } || gems.contains { !$0.isEmpty }
    }

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
        let r: CGFloat = 20 * FingerLift.spread
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
        let r: CGFloat = 22 * FingerLift.spread
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
        // live gem hover preview under tweezers before release
        if tool == .gem, let stageTip = tipOnStage {
            let artTip = toArt(stageTip)
            let pulse = 0.88 + 0.12 * sin(now * 6)
            if let i = CloseHand.nail(at: artTip, slack: 0.05), gems[i].count < 6 {
                let (u, v) = CloseHand.toNail(i, artTip)
                let snapped = CloseHand.fromNail(i, u: max(-0.7, min(0.7, u)), v: max(0.15, min(0.85, v)))
                let gemSize = CloseHand.fingers[i].width * 0.3
                let ringR = gemSize * 0.68 * CGFloat(pulse)
                g.stroke(
                    Path(ellipseIn: CGRect(x: snapped.x - ringR, y: snapped.y - ringR, width: ringR * 2, height: ringR * 2)),
                    with: .color(.white.opacity(0.88)),
                    style: StrokeStyle(lineWidth: 2.8, dash: [5, 4])
                )
                var preview = g
                preview.opacity = 0.78
                CloseHand.drawGem(gemKind, color: RGB(hex: gemColor), at: snapped, size: gemSize, turn: 0, t: now, in: preview)
            } else {
                var ghost = g
                ghost.opacity = 0.38
                CloseHand.drawGem(gemKind, color: RGB(hex: gemColor), at: artTip, size: 22, turn: 0, t: now, in: ghost)
            }
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

    private func drawTool(at f: CGPoint, in ctx: GraphicsContext) {
        guard let tip = tipOnStage else { return }
        let dist = max(Self.handle, hypot(f.x - tip.x, f.y - tip.y))
        if tool == .glitter || tool == .wipe {
            let hand = CGPoint(x: tip.x, y: tip.y + dist)
            BeautyTools.draw(tool, color: color, gem: (gemKind, gemColor), load: load, tip: tip, finger: hand, t: now, in: ctx)
            return
        }
        let h = FingerLift.handle(tip: tip, finger: f, length: dist)
        let angle = atan2(-Double(h.dir.dx), Double(h.dir.dy))
        var g = ctx
        g.translateBy(x: tip.x, y: tip.y)
        g.rotate(by: .radians(angle))
        BeautyTools.draw(tool, color: color, gem: (gemKind, gemColor), load: load, tip: .zero, finger: CGPoint(x: 0, y: dist), t: now, in: g)
    }
}

// MARK: - Tool pictures (in the studio and on the buttons)

enum BeautyTools {
    static func draw(_ tool: BeautyWorld.Tool, color: String, gem: (String, String), load: Double, tip: CGPoint, finger f: CGPoint,
                     t: Double, in ctx: GraphicsContext) {
        let ink = Theme.ink
        let c = BeautyColors.rgb(color == "glitter" ? "#F4E9FF" : color, Int(t * 6))
        let cOut = Shades.outline(c).color
        var g = ctx
        g.addFilter(.shadow(color: ink.opacity(0.24), radius: 6, x: 0, y: 5))
        func rr(_ r: CGRect, _ rad: CGFloat) -> Path { Path(roundedRect: r, cornerRadius: rad) }
        switch tool {
        case .blush:
            let hLen = max(46, f.y - tip.y)
            var handle = Path()
            handle.move(to: CGPoint(x: tip.x - 8, y: tip.y + 38))
            handle.addQuadCurve(to: CGPoint(x: tip.x - 6, y: tip.y + 36 + hLen), control: CGPoint(x: tip.x - 9, y: tip.y + 36 + hLen * 0.5))
            handle.addQuadCurve(to: CGPoint(x: tip.x + 6, y: tip.y + 36 + hLen), control: CGPoint(x: tip.x, y: tip.y + 44 + hLen))
            handle.addQuadCurve(to: CGPoint(x: tip.x + 8, y: tip.y + 38), control: CGPoint(x: tip.x + 9, y: tip.y + 36 + hLen * 0.5))
            handle.closeSubpath()
            StorybookArt.fillAndStroke(g, handle, fill: StorybookArt.color(0xFF7FB3), stroke: StorybookArt.outline(for: 0xF45C9A), width: 2.6)
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 4.5, y: tip.y + 44, width: 3.5, height: max(18, hLen * 0.6)), opacity: 0.45)

            let ferrule = rr(CGRect(x: tip.x - 11.5, y: tip.y + 19, width: 23, height: 22), 6)
            StorybookArt.fillAndStroke(g, ferrule, fill: StorybookArt.color(0xF6D99A), stroke: StorybookArt.outline(for: 0xD9A441), width: 2.4)
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 7, y: tip.y + 22, width: 4, height: 15), opacity: 0.6)

            var puff = Path()
            puff.move(to: CGPoint(x: tip.x - 11, y: tip.y + 22))
            puff.addCurve(to: CGPoint(x: tip.x - 23, y: tip.y + 4), control1: CGPoint(x: tip.x - 20, y: tip.y + 20), control2: CGPoint(x: tip.x - 25, y: tip.y + 12))
            puff.addCurve(to: CGPoint(x: tip.x, y: tip.y - 14), control1: CGPoint(x: tip.x - 20, y: tip.y - 8), control2: CGPoint(x: tip.x - 10, y: tip.y - 14))
            puff.addCurve(to: CGPoint(x: tip.x + 23, y: tip.y + 4), control1: CGPoint(x: tip.x + 10, y: tip.y - 14), control2: CGPoint(x: tip.x + 20, y: tip.y - 8))
            puff.addCurve(to: CGPoint(x: tip.x + 11, y: tip.y + 22), control1: CGPoint(x: tip.x + 25, y: tip.y + 12), control2: CGPoint(x: tip.x + 20, y: tip.y + 20))
            puff.closeSubpath()
            StorybookArt.fillAndStroke(g, puff, fill: StorybookArt.color(0xF8EAD8), stroke: StorybookArt.outline(for: 0xDFC4A6), width: 2.6)
            var tipClip = g
            tipClip.clip(to: puff)
            tipClip.fill(Path(ellipseIn: CGRect(x: tip.x - 22, y: tip.y - 16, width: 44, height: 24)), with: .color(c.color.opacity(0.86)))
            StorybookArt.highlight(tipClip, in: CGRect(x: tip.x - 12, y: tip.y - 10, width: 12, height: 6), opacity: 0.5)

        case .shadow:
            let hLen = max(42, f.y - tip.y - 4)
            let wand = rr(CGRect(x: tip.x - 4.5, y: tip.y + 22, width: 9, height: hLen), 4.5)
            StorybookArt.fillAndStroke(g, wand, fill: StorybookArt.color(0xB394EE), stroke: StorybookArt.outline(for: 0x8B6AD0), width: 2.4)
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 2.2, y: tip.y + 28, width: 2.2, height: max(16, hLen * 0.65)), opacity: 0.5)

            var sp = Path()
            sp.move(to: CGPoint(x: tip.x, y: tip.y - 8))
            sp.addCurve(to: CGPoint(x: tip.x, y: tip.y + 26), control1: CGPoint(x: tip.x + 22, y: tip.y + 2), control2: CGPoint(x: tip.x + 15, y: tip.y + 26))
            sp.addCurve(to: CGPoint(x: tip.x, y: tip.y - 8), control1: CGPoint(x: tip.x - 15, y: tip.y + 26), control2: CGPoint(x: tip.x - 22, y: tip.y + 2))
            sp.closeSubpath()
            StorybookArt.fillAndStroke(g, sp, fill: StorybookArt.color(0x524568), stroke: StorybookArt.outline(for: 0x524568), width: 2.4)
            var spClip = g
            spClip.clip(to: sp)
            spClip.fill(Path(ellipseIn: CGRect(x: tip.x - 18, y: tip.y - 10, width: 36, height: 26)), with: .color(c.color.opacity(0.95)))
            StorybookArt.highlight(spClip, in: CGRect(x: tip.x - 8, y: tip.y - 4, width: 8, height: 5), opacity: 0.55)

        case .lip:
            let tubeH = max(36, f.y - tip.y - 22)
            let tube = rr(CGRect(x: tip.x - 15, y: tip.y + 34, width: 30, height: tubeH), 7)
            g.fill(
                tube,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFFF0B3), Color(hex: 0xF5C95B), Color(hex: 0xD9A441)]),
                    startPoint: CGPoint(x: tip.x - 15, y: 0),
                    endPoint: CGPoint(x: tip.x + 15, y: 0)
                )
            )
            g.stroke(tube, with: .color(StorybookArt.outline(for: 0xD9A441)), lineWidth: 2.6)
            let collar = rr(CGRect(x: tip.x - 12, y: tip.y + 26, width: 24, height: 11), 4)
            StorybookArt.fillAndStroke(g, collar, fill: StorybookArt.color(0xFFF3C4), stroke: StorybookArt.outline(for: 0xD9A441), width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 10, y: tip.y + 38, width: 5, height: max(12, tubeH - 12)), opacity: 0.5)

            var bullet = Path()
            bullet.move(to: CGPoint(x: tip.x - 10.5, y: tip.y + 28))
            bullet.addLine(to: CGPoint(x: tip.x - 10.5, y: tip.y + 8))
            bullet.addQuadCurve(to: CGPoint(x: tip.x + 10.5, y: tip.y - 6), control: CGPoint(x: tip.x - 5, y: tip.y - 9))
            bullet.addLine(to: CGPoint(x: tip.x + 10.5, y: tip.y + 28))
            bullet.closeSubpath()
            StorybookArt.fillAndStroke(g, bullet, fill: c.color, stroke: cOut, width: 2.4)
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 6.5, y: tip.y + 5, width: 4, height: 18), opacity: 0.55)

        case .glitter:
            let shake = CGFloat(sin(t * 30)) * 3
            let jarRect = CGRect(x: tip.x - 24 + shake, y: tip.y + 10, width: 48, height: 58)
            let jar = rr(jarRect, 14)
            StorybookArt.fillAndStroke(g, jar, fill: StorybookArt.color(0xFFFDFB, alpha: 0.92), stroke: StorybookArt.outline(for: 0xC9B6FF), width: 2.8)
            var inner = g
            inner.clip(to: rr(jarRect.insetBy(dx: 4, dy: 4), 10))
            inner.fill(Path(jarRect.insetBy(dx: 4, dy: 4)), with: .color(c.color.opacity(0.9)))
            for k in 0..<10 {
                let h = BeautyPainter.hash(k)
                inner.fill(Path(ellipseIn: CGRect(x: jarRect.minX + CGFloat(h % 38) + 5, y: jarRect.minY + CGFloat((h >> 8) % 48) + 5, width: 3.5, height: 3.5)),
                           with: .color(.white.opacity(0.9)))
            }
            StorybookArt.highlight(inner, in: CGRect(x: jarRect.minX + 7, y: jarRect.minY + 9, width: 7, height: 32), opacity: 0.55)
            let lid = rr(CGRect(x: tip.x - 21 + shake, y: tip.y - 3, width: 42, height: 16), 6)
            StorybookArt.fillAndStroke(g, lid, fill: Theme.lilac, stroke: StorybookArt.outline(for: 0xA88EE8), width: 2.6)
            for k in -1...1 {
                g.fill(Path(ellipseIn: CGRect(x: tip.x + CGFloat(k) * 10 - 2.2 + shake, y: tip.y + 2, width: 4.4, height: 4.4)), with: .color(ink.opacity(0.6)))
            }

        case .wipe:
            let pad = Path(ellipseIn: CGRect(x: tip.x - 31, y: tip.y - 27, width: 62, height: 62))
            StorybookArt.fillAndStroke(g, pad, fill: StorybookArt.color(0xFFFDFB), stroke: StorybookArt.outline(for: 0xECC4D6), width: 3)
            g.stroke(Path(ellipseIn: CGRect(x: tip.x - 24, y: tip.y - 20, width: 48, height: 48)),
                     with: .color(Theme.blush.opacity(0.75)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            for k in 0..<7 {
                let a = Double(k) * .pi * 2 / 7
                g.fill(Path(ellipseIn: CGRect(x: tip.x + CGFloat(cos(a)) * 14 - 2.2, y: tip.y + 4 + CGFloat(sin(a)) * 14 - 2.2, width: 4.4, height: 4.4)),
                       with: .color(Theme.blush))
            }
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 18, y: tip.y - 19, width: 20, height: 10), opacity: 0.75)

        case .polish:
            let glitter = color == "glitter"
            let capH = max(44, f.y - tip.y - 30)
            let capRect = CGRect(x: tip.x - 15, y: tip.y + 42, width: 30, height: capH)
            let cap = rr(capRect, 10)
            g.fill(
                cap,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x7A5A8E), Color(hex: 0x5B3A68)]),
                    startPoint: CGPoint(x: capRect.minX, y: 0),
                    endPoint: CGPoint(x: capRect.maxX, y: 0)
                )
            )
            g.stroke(cap, with: .color(StorybookArt.outline(for: 0x5B3A68)), lineWidth: 2.6)
            StorybookArt.highlight(g, in: CGRect(x: capRect.minX + 5, y: capRect.minY + 7, width: 5, height: max(14, capRect.height - 16)), opacity: 0.38)

            let stem = rr(CGRect(x: tip.x - 2.6, y: tip.y + 21, width: 5.2, height: 24), 2.5)
            StorybookArt.fillAndStroke(g, stem, fill: StorybookArt.color(0xC9C0D8), stroke: StorybookArt.outline(for: 0x9C92B0), width: 1.6)

            var bristles = Path()
            bristles.move(to: CGPoint(x: tip.x - 8.5, y: tip.y + 24))
            bristles.addQuadCurve(to: CGPoint(x: tip.x, y: tip.y - 5), control: CGPoint(x: tip.x - 9.5, y: tip.y + 4))
            bristles.addQuadCurve(to: CGPoint(x: tip.x + 8.5, y: tip.y + 24), control: CGPoint(x: tip.x + 9.5, y: tip.y + 4))
            bristles.closeSubpath()
            StorybookArt.fillAndStroke(g, bristles, fill: StorybookArt.color(0xF4E8D8), stroke: StorybookArt.outline(for: 0xD8C2A8), width: 2.2)
            if load > 0.02 {
                var wetB = g
                wetB.opacity = 0.4 + 0.6 * load
                StorybookArt.fillAndStroke(wetB, bristles, fill: glitter ? Color(hex: 0xF4E9FF) : c.color, stroke: glitter ? StorybookArt.outline(for: 0xC9B6FF) : cOut, width: 2.2)
                if glitter {
                    for k in 0..<5 {
                        BeautyPainter.fleck(at: CGPoint(x: tip.x - 4 + CGFloat(k * 2), y: tip.y + 4 + CGFloat((k * 7) % 16)), index: k + 3,
                                            color: "rainbow", t: t, scale: 1.2, in: wetB)
                    }
                }
                if load > 0.6 {
                    let r = CGFloat(2 + 3 * load)
                    wetB.fill(Path(ellipseIn: CGRect(x: tip.x + 2, y: tip.y + 14, width: r * 2, height: r * 2.3)), with: .color(glitter ? .white : c.color))
                }
                StorybookArt.highlight(g, in: CGRect(x: tip.x - 4.5, y: tip.y + 3, width: 3.4, height: 11), opacity: 0.68)
            }

        case .remover:
            let stem = rr(CGRect(x: tip.x - 3.5, y: tip.y + 10, width: 7, height: max(48, f.y - tip.y + 6)), 3.5)
            StorybookArt.fillAndStroke(g, stem, fill: StorybookArt.color(0xFFEAF2), stroke: StorybookArt.outline(for: 0xE6B8CC), width: 2)
            let topBud = Path(ellipseIn: CGRect(x: tip.x - 11.5, y: tip.y - 13, width: 23, height: 33))
            StorybookArt.fillAndStroke(g, topBud, fill: .white, stroke: StorybookArt.outline(for: 0xE6C2D4), width: 2.4)
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 6, y: tip.y - 7, width: 6, height: 12), opacity: 0.8)
            let endBud = Path(ellipseIn: CGRect(x: tip.x - 11.5, y: f.y - 6, width: 23, height: 30))
            StorybookArt.fillAndStroke(g, endBud, fill: .white, stroke: StorybookArt.outline(for: 0xE6C2D4), width: 2.4)

        case .dryer:
            let hLen = max(46, f.y - tip.y)
            let handle = rr(CGRect(x: tip.x - 10, y: tip.y + 30, width: 20, height: hLen), 10)
            StorybookArt.fillAndStroke(g, handle, fill: StorybookArt.color(0x5AC7BE), stroke: StorybookArt.outline(for: 0x46B7B0), width: 2.8)
            StorybookArt.highlight(g, in: CGRect(x: tip.x - 5.5, y: tip.y + 38, width: 4.5, height: max(18, hLen * 0.55)), opacity: 0.45)

            let headRect = CGRect(x: tip.x - 35, y: tip.y - 31, width: 70, height: 70)
            let head = Path(ellipseIn: headRect)
            StorybookArt.fillAndStroke(g, head, fill: Theme.mint, stroke: StorybookArt.outline(for: 0x46B7B0), width: 3.2)
            g.stroke(Path(ellipseIn: headRect.insetBy(dx: 4, dy: 4)), with: .color(.white.opacity(0.9)), lineWidth: 3)

            var blades = g
            blades.translateBy(x: tip.x, y: tip.y + 4)
            blades.rotate(by: .radians(t * 24))
            for k in 0..<4 {
                var b = blades
                b.rotate(by: .degrees(Double(k) * 90))
                let blade = Path(ellipseIn: CGRect(x: -6.5, y: -27, width: 13, height: 26))
                StorybookArt.fillAndStroke(b, blade, fill: .white.opacity(0.92), stroke: StorybookArt.outline(for: 0x6EC8B8), width: 1.6)
            }
            let hub = Path(ellipseIn: CGRect(x: -7, y: -7, width: 14, height: 14))
            StorybookArt.fillAndStroke(blades, hub, fill: StorybookArt.color(0x46B7B0), stroke: StorybookArt.outline(for: 0x3A9992), width: 2)

        case .gem:
            let endY = max(tip.y + 72, f.y)
            var leftArm = Path()
            leftArm.move(to: CGPoint(x: tip.x - 3, y: tip.y + 10))
            leftArm.addQuadCurve(to: CGPoint(x: tip.x - 10, y: endY), control: CGPoint(x: tip.x - 11, y: (tip.y + endY) * 0.5))
            var rightArm = Path()
            rightArm.move(to: CGPoint(x: tip.x + 3, y: tip.y + 10))
            rightArm.addQuadCurve(to: CGPoint(x: tip.x + 10, y: endY), control: CGPoint(x: tip.x + 11, y: (tip.y + endY) * 0.5))
            for arm in [leftArm, rightArm] {
                g.stroke(arm, with: .color(StorybookArt.outline(for: 0xB9B3C6)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                g.stroke(arm, with: .color(StorybookArt.color(0xE0D9EE)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                g.stroke(arm, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
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
    let cancel: () -> Void
    let done: (Look) -> Void
    @State private var world: BeautyWorld
    @State private var mode: BeautyWorld.Mode
    @State private var tick = 0

    init(look: Look, mode: BeautyWorld.Mode, cancel: @escaping () -> Void = {}, done: @escaping (Look) -> Void) {
        self.cancel = cancel
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
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
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
                    if world.mode == .nails && world.hasNailArt {
                        DressUpFind.nailArtist.unlock()
                    }
                    tick += 1
                }
        )
    }

    /// Walks evenly around a rounded rectangle's true perimeter so vanity bulbs track the frame cleanly.
    private static func roundedRectPerimeterPoint(in r: CGRect, cornerRadius: CGFloat, distance raw: CGFloat) -> CGPoint {
        let cr = min(cornerRadius, min(r.width, r.height) / 2)
        let topW = max(0, r.width - 2 * cr)
        let sideH = max(0, r.height - 2 * cr)
        let arc = (.pi / 2) * cr
        let total = 2 * topW + 2 * sideH + 4 * arc
        guard total > 0 else { return CGPoint(x: r.midX, y: r.midY) }
        var d = raw.truncatingRemainder(dividingBy: total)
        if d < 0 { d += total }

        if d < topW {
            return CGPoint(x: r.minX + cr + d, y: r.minY)
        }
        d -= topW
        if d < arc {
            let a = -CGFloat.pi / 2 + d / cr
            return CGPoint(x: r.maxX - cr + cos(a) * cr, y: r.minY + cr + sin(a) * cr)
        }
        d -= arc
        if d < sideH {
            return CGPoint(x: r.maxX, y: r.minY + cr + d)
        }
        d -= sideH
        if d < arc {
            let a = d / cr
            return CGPoint(x: r.maxX - cr + cos(a) * cr, y: r.maxY - cr + sin(a) * cr)
        }
        d -= arc
        if d < topW {
            return CGPoint(x: r.maxX - cr - d, y: r.maxY)
        }
        d -= topW
        if d < arc {
            let a = CGFloat.pi / 2 + d / cr
            return CGPoint(x: r.minX + cr + cos(a) * cr, y: r.maxY - cr + sin(a) * cr)
        }
        d -= arc
        if d < sideH {
            return CGPoint(x: r.minX, y: r.maxY - cr - d)
        }
        d -= sideH
        let a = CGFloat.pi + d / cr
        return CGPoint(x: r.minX + cr + cos(a) * cr, y: r.minY + cr + sin(a) * cr)
    }

    /// A lit vanity mirror for makeup, a manicure towel for nails.
    private func drawBackdrop(in ctx: GraphicsContext, size: CGSize, t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        if world.mode == .makeup {
            ctx.fill(Path(rect), with: .color(Color(hex: 0xF7D9E6)))
            let mirror = rect.insetBy(dx: 26, dy: 26)
            let cr: CGFloat = 200
            ctx.fill(Path(roundedRect: mirror, cornerRadius: cr),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xE9F4FF), Color(hex: 0xFFF3FA)]),
                                           startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: size.width, y: size.height)))
            var streak = Path()
            streak.move(to: CGPoint(x: mirror.minX + 70, y: mirror.minY + 140))
            streak.addLine(to: CGPoint(x: mirror.minX + 160, y: mirror.minY + 50))
            ctx.stroke(streak, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 20, lineCap: .round))
            ctx.stroke(Path(roundedRect: mirror, cornerRadius: cr), with: .color(.white), lineWidth: 14)

            let topW = max(0, mirror.width - 2 * cr)
            let sideH = max(0, mirror.height - 2 * cr)
            let per = 2 * topW + 2 * sideH + 2 * .pi * cr
            let n = 16
            for k in 0..<n {
                let d = topW / 2 + per * CGFloat(k) / CGFloat(n)
                let p = Self.roundedRectPerimeterPoint(in: mirror, cornerRadius: cr, distance: d)
                let glow = 0.75 + 0.25 * sin(t * 1.7 + Double(k))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)),
                         with: .color(Color(hex: 0xFFF1B8).opacity(0.38 * glow)))
                StorybookArt.fillAndStroke(
                    ctx,
                    Path(ellipseIn: CGRect(x: p.x - 11, y: p.y - 11, width: 22, height: 22)),
                    fill: StorybookArt.color(0xFFF9E4),
                    stroke: StorybookArt.outline(for: 0xF2C14E),
                    width: 2.2
                )
                StorybookArt.highlight(ctx, in: CGRect(x: p.x - 6, y: p.y - 6.5, width: 6, height: 4), opacity: 0.9)
            }
        } else {
            ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF3F7), Color(hex: 0xFCE1EC)]),
                                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
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
            HStack(spacing: 8) {
                modeButton(.makeup, symbol: "paintbrush.pointed.fill")
                modeButton(.nails, symbol: "hand.raised.fill")
                Spacer(minLength: 4)
                RoundButton(symbol: "arrow.uturn.backward", tint: Color(hex: 0x9B79E0), size: 54) {
                    world.undo(); tick += 1
                }
                .opacity(world.canUndo ? 1 : 0.4)
                RoundButton(symbol: "xmark", tint: Theme.pink, size: 54) {
                    Sound.shared.play(.whoosh, volume: 0.6)
                    cancel()
                }
                RoundButton(symbol: "checkmark", tint: Color(hex: 0x6CCB8B), size: 54) {
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
                            dipButton
                        }
                        Spacer()
                        Button { world.clearAll(); tick += 1 } label: { panelLabel("trash.fill", Color(hex: 0xE8475A)) }
                            .buttonStyle(Squish())
                    }
                }
                .padding(4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Theme.blush, lineWidth: 4))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
    }

    private var dipButton: some View {
        let isDry = world.load < 0.05
        return TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !isDry)) { tl in
            let dry = world.load < 0.05
            let t = tl.date.timeIntervalSinceReferenceDate
            let pulse: CGFloat = dry ? 1 + 0.13 * CGFloat(sin(t * 7)) : 1
            let activeColor = BeautyColors.rgb(world.color == "glitter" ? "#C9B6FF" : world.color).color
            Button {
                world.dip()
                Sound.shared.tap()
                tick += 1
            } label: {
                ZStack {
                    if dry {
                        Capsule()
                            .fill(Theme.lemon.opacity(0.45 + 0.35 * sin(t * 7)))
                            .frame(width: 84, height: 68)
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                        if dry {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Theme.lemon)
                        }
                    }
                    .frame(width: dry ? 74 : 64, height: 56)
                    .background(Capsule().fill(activeColor))
                    .overlay(Capsule().stroke(dry ? Theme.lemon : .white, lineWidth: dry ? 4 : 3))
                    .shadow(color: dry ? Theme.lemon.opacity(0.6) : Theme.ink.opacity(0.16), radius: dry ? 8 : 4, y: 2)
                }
                .scaleEffect(pulse)
            }
            .buttonStyle(Squish())
        }
    }

    private func panelLabel(_ symbol: String, _ tint: Color) -> some View {
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
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(world.mode == m ? .white : Theme.pink)
                .frame(width: 58, height: 54)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(world.mode == m ? Theme.pink.opacity(0.92) : Theme.blush.opacity(0.7)))
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
                    if t == .polish && world.load < 0.05 { world.dip() }
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

    @ViewBuilder private func swatch(_ hex: String, on: Bool) -> some View {
        let dryActive = world.tool == .polish && on && world.load < 0.05
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let c = BeautyColors.rgb(hex == "glitter" ? "#F4E9FF" : hex)
            let outline = hex == "glitter" ? StorybookArt.outline(for: 0xC9B6FF) : Shades.outline(c).color
            switch world.tool {
            case .polish:
                let capRect = CGRect(x: w * 0.37, y: h * 0.06, width: w * 0.26, height: h * 0.34)
                let cap = Path(roundedRect: capRect, cornerRadius: 6)
                StorybookArt.fillAndStroke(ctx, cap, fill: StorybookArt.color(0x6B4B7E), stroke: StorybookArt.outline(for: 0x5B3A68), width: 2.2)
                StorybookArt.highlight(ctx, in: CGRect(x: capRect.minX + 3, y: capRect.minY + 4, width: 3.5, height: capRect.height - 9), opacity: 0.4)

                var bottle = Path()
                bottle.move(to: CGPoint(x: w * 0.32, y: h * 0.38))
                bottle.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.38), control: CGPoint(x: w * 0.5, y: h * 0.34))
                bottle.addCurve(to: CGPoint(x: w * 0.78, y: h * 0.84), control1: CGPoint(x: w * 0.78, y: h * 0.48), control2: CGPoint(x: w * 0.8, y: h * 0.7))
                bottle.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.84), control: CGPoint(x: w * 0.5, y: h * 0.94))
                bottle.addCurve(to: CGPoint(x: w * 0.32, y: h * 0.38), control1: CGPoint(x: w * 0.2, y: h * 0.7), control2: CGPoint(x: w * 0.22, y: h * 0.48))
                bottle.closeSubpath()
                StorybookArt.fillAndStroke(ctx, bottle, fill: c.color, stroke: outline, width: 2.5)
                if hex == "glitter" {
                    var gl = ctx
                    gl.clip(to: bottle)
                    for k in 0..<12 {
                        BeautyPainter.fleck(
                            at: CGPoint(x: w * 0.26 + CGFloat(BeautyPainter.hash(k) % max(1, Int(w * 0.48))),
                                        y: h * 0.42 + CGFloat(BeautyPainter.hash(k + 99) % max(1, Int(h * 0.42)))),
                            index: k,
                            color: "rainbow",
                            t: 0,
                            scale: 1.5,
                            in: gl
                        )
                    }
                }
                StorybookArt.highlight(ctx, in: CGRect(x: w * 0.29, y: h * 0.47, width: w * 0.11, height: h * 0.26), opacity: 0.55)
            default:
                let r = min(w, h) * 0.4
                let ce = CGPoint(x: w / 2, y: h / 2)
                let ring = Path(ellipseIn: CGRect(x: ce.x - r - 5, y: ce.y - r - 5, width: r * 2 + 10, height: r * 2 + 10))
                StorybookArt.fillAndStroke(ctx, ring, fill: StorybookArt.color(0xF6EDF8), stroke: Theme.blush, width: 2)
                let pan = Path(ellipseIn: CGRect(x: ce.x - r, y: ce.y - r, width: r * 2, height: r * 2))
                if hex == "rainbow" {
                    ctx.fill(pan, with: .conicGradient(Gradient(colors: (0..<7).map { BeautyColors.rgb("rainbow", $0).color }), center: ce))
                    ctx.stroke(pan, with: .color(StorybookArt.outline(for: 0xFF8FB8)), lineWidth: 2)
                } else {
                    StorybookArt.fillAndStroke(ctx, pan, fill: c.color, stroke: outline, width: 2)
                }
                if world.tool == .glitter {
                    for k in 0..<10 {
                        let h2 = BeautyPainter.hash(k + 5)
                        BeautyPainter.fleck(at: CGPoint(x: ce.x + CGFloat(h2 % 40) - 20, y: ce.y + CGFloat((h2 >> 8) % 40) - 20), index: k,
                                            color: "#FFFFFF", t: 0, scale: 1.4, in: ctx)
                    }
                }
                StorybookArt.highlight(ctx, in: CGRect(x: ce.x - r * 0.6, y: ce.y - r * 0.7, width: r * 0.7, height: r * 0.35), opacity: 0.42)
            }
        }
        .frame(height: 76)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(on ? Theme.blush : Color(hex: 0xFFF7FA)))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(dryActive ? Theme.lemon : (on ? Theme.pink : Color(hex: 0xF5DDE8)), lineWidth: on ? 5 : 3)
        )
    }
}
