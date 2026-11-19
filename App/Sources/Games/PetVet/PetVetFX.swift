import SwiftUI

// MARK: - Pet Vet: the physical stuff
//
// Everything here makes the tools feel real: soap foam that builds up where she scrubs and slides
// off under the shower, soap bubbles that float, wobble and pop, water that falls in drops, splashes,
// runs down the fur in little streams, leaves the fur wet and makes a puddle on the floor, a towel
// that dries it, cream that spreads and soaks in, fur that bends under the comb and springs back,
// cold mist from the ice pack, a bandage that wraps round and round, crumbs from a treat.
//
// It is all decoration: the game rules stay in `VetVisit`. `emit` is called from the game loop with
// the lifted tool; `step` and the `draw...` functions are called from the exam room's Canvas, so the
// motion runs at the screen's frame rate.

final class VetFX {
    // Patient art coordinates (they move with the patient): foam, smears, wet fur, fur strands.
    struct Foam { var p: CGPoint; var r: CGFloat; let born: Double; let life: Double; var mud: Double; var rinsed: Double?; var vy: CGFloat; let seed: Double }
    struct Smear { let a: CGPoint; let b: CGPoint; let born: Double; let color: Color; let width: CGFloat; let soak: Double }
    struct Wet { let p: CGPoint; var amount: Double; let r: CGFloat }
    struct Bead { var p: CGPoint; let r: CGFloat; let born: Double; var vy: CGFloat; let life: Double }
    struct Stream { var p: CGPoint; var trail: [CGPoint]; let born: Double; let life: Double; let mud: Bool; var vy: CGFloat; let seed: Double }
    struct Ruffle { let p: CGPoint; let dir: CGVector; let born: Double; let seed: Double }
    // Room coordinates: things that fall or float off the patient.
    struct Bubble { var p: CGPoint; var v: CGVector; let r: CGFloat; let born: Double; let life: Double; let seed: Double }
    struct Pop { let p: CGPoint; let r: CGFloat; let born: Double }
    struct Drop { var p: CGPoint; var v: CGVector; let r: CGFloat; let depth: CGFloat; let startY: CGFloat; let mud: Bool }
    struct Splash { let p: CGPoint; let born: Double; let size: CGFloat; let floor: Bool; let mud: Bool }
    struct Bit { var p: CGPoint; var v: CGVector; let born: Double; let life: Double; let size: CGFloat; let color: Color; let spin: Double; var bounced: Bool; let gravity: CGFloat; let fluff: Bool }
    struct Mist { var p: CGPoint; var v: CGVector; let born: Double; let life: Double; let r: CGFloat }

    var foam: [Foam] = []
    var smears: [Smear] = []
    var wet: [Wet] = []
    var beads: [Bead] = []
    var streams: [Stream] = []
    var ruffles: [Ruffle] = []
    var bubbles: [Bubble] = []
    var pops: [Pop] = []
    var drops: [Drop] = []
    var splashes: [Splash] = []
    var bits: [Bit] = []
    var mist: [Mist] = []
    /// Water on the floor, 0...1.
    var puddle: Double = 0
    /// Spots whose bandage wrap started, by spot id.
    var wraps: [Int: Double] = [:]
    /// Stickers being pressed on, in patient coordinates.
    var presses: [(p: CGPoint, born: Double)] = []
    /// The patient leans away from a rub a little, like a real animal would. Degrees.
    var lean: Double = 0
    private var leanV: Double = 0
    private var leanTarget: Double = 0
    private var leanUntil: Double = 0
    private var last: Double?
    private var lastBubbleSound: Double = 0

    var furColor: Color = .white
    var lineColor: Color = Color(hex: 0x774144)
    /// The patient's outline, for "did the water land on fur?".
    var silhouette = Path()

    func setUp(_ a: VetAnimal) {
        var s = Path()
        for shape in a.back + a.body where shape.stroke != nil && shape.fill != nil { s.addPath(shape.path) }
        silhouette = s
        furColor = a.body.first { $0.fill != nil }?.fill ?? .white
        lineColor = a.body.first { $0.stroke != nil }?.stroke ?? Color(hex: 0x774144)
    }

    static func now() -> Double { Date().timeIntervalSinceReferenceDate }

    // MARK: Emitting (called ~30 times a second while a tool is lifted)

    /// `tip` is in patient coordinates, `room` the same point in the room, `step` the finger motion
    /// in patient coordinates since the last call. `mud` lists mud spots that still need washing.
    func emit(_ tool: VetTool, tip: CGPoint, room: CGPoint, step: CGVector, toRoom: (CGPoint) -> CGPoint,
              mouth: CGPoint, mud: [CGPoint]) {
        let t = VetFX.now()
        let moved = hypot(step.dx, step.dy)
        let onFur = silhouette.contains(tip)
        let rubbing = moved > 1.2
        let muddy: Double = mud.map { Double(1 - min(1, hypot($0.x - tip.x, $0.y - tip.y) / 70)) }.max() ?? 0

        if onFur && rubbing && [.sponge, .comb, .brush, .towel, .feather, .cream, .swab, .tissue].contains(tool) {
            leanTarget = max(-2.2, min(2.2, Double(step.dx) * 0.12))
            leanUntil = t + 0.25
        }

        switch tool {
        case .sponge:
            guard onFur, rubbing else { break }
            for _ in 0..<(moved > 8 ? 2 : 1) {
                addFoam(CGPoint(x: tip.x + .random(in: -16...16), y: tip.y + .random(in: -12...12)),
                        r: .random(in: 8...16), life: .random(in: 9...12), mud: muddy * 0.85, t: t)
            }
            if Double.random(in: 0...1) < 0.35 { addBubble(at: CGPoint(x: room.x + .random(in: -20...20), y: room.y - 10), t: t) }
        case .toothbrush:
            guard rubbing, hypot(tip.x - mouth.x, tip.y - mouth.y) < 80 else { break }
            addFoam(CGPoint(x: tip.x + .random(in: -10...10), y: tip.y + .random(in: -6...8)),
                    r: .random(in: 4...8), life: .random(in: 3...4.5), mud: 0, t: t)
            if Double.random(in: 0...1) < 0.25 { addBubble(at: room, t: t, small: true) }
        case .cream, .swab:
            guard onFur, rubbing, let from = lastTip else { break }
            let cream = tool == .cream
            smears.append(Smear(a: from, b: tip, born: t, color: cream ? Color(hex: 0xFFF8EE) : Color(hex: 0xF2A667),
                                width: cream ? 24 : 13, soak: cream ? 5 : 3.5))
            if smears.count > 260 { smears.removeFirst(smears.count - 260) }
        case .shower:
            for _ in 0..<6 {
                let start = CGPoint(x: room.x + .random(in: -14...14), y: room.y + .random(in: -4...6))
                drops.append(Drop(p: start, v: CGVector(dx: .random(in: -70...70), dy: .random(in: 320...480)),
                                  r: .random(in: 2.2...4.2), depth: .random(in: 8...150), startY: tip.y, mud: false))
            }
            if drops.count > 220 { drops.removeFirst(drops.count - 220) }
            // the stream rinses foam below the shower head
            for i in foam.indices where foam[i].rinsed == nil {
                let f = foam[i]
                if abs(f.p.x - tip.x) < 64 && f.p.y > tip.y - 30 && f.p.y < tip.y + 220 { foam[i].rinsed = t }
            }
            for i in smears.indices.reversed() where abs(smears[i].b.x - tip.x) < 50 && smears[i].b.y > tip.y - 20 {
                if t - smears[i].born > 0.3 { smears.remove(at: i) }
            }
        case .towel:
            guard onFur, rubbing else { break }
            for i in wet.indices where hypot(wet[i].p.x - tip.x, wet[i].p.y - tip.y) < 70 { wet[i].amount -= 0.06 }
            beads.removeAll { hypot($0.p.x - tip.x, $0.p.y - tip.y) < 55 }
            streams.removeAll { hypot($0.p.x - tip.x, $0.p.y - tip.y) < 55 }
            for i in foam.indices where foam[i].rinsed == nil && hypot(foam[i].p.x - tip.x, foam[i].p.y - tip.y) < 50 {
                foam[i].rinsed = t
            }
            ruffle(tip, step, t: t)
        case .comb, .brush, .feather:
            guard onFur, rubbing else { break }
            ruffle(tip, step, t: t)
            if tool == .brush && Double.random(in: 0...1) < 0.22 {
                bits.append(Bit(p: room, v: CGVector(dx: Double(step.dx) * 6 + .random(in: -40...40), dy: .random(in: -90...(-30))),
                                born: t, life: 1.8, size: .random(in: 5...8), color: furColor, spin: .random(in: -200...200),
                                bounced: false, gravity: 120, fluff: true))
            }
        case .icepack:
            guard onFur, Double.random(in: 0...1) < 0.6 else { break }
            mist.append(Mist(p: CGPoint(x: room.x + .random(in: -24...24), y: room.y + .random(in: -6...10)),
                             v: CGVector(dx: .random(in: -24...24), dy: .random(in: 10...40)), born: t, life: .random(in: 1.0...1.6),
                             r: .random(in: 10...18)))
            if mist.count > 60 { mist.removeFirst(mist.count - 60) }
        case .spray:
            for _ in 0..<3 {
                mist.append(Mist(p: room, v: CGVector(dx: .random(in: -90...90), dy: .random(in: -60...40)), born: t,
                                 life: .random(in: 0.5...0.9), r: .random(in: 4...8)))
            }
            if mist.count > 60 { mist.removeFirst(mist.count - 60) }
        default:
            break
        }
        lastTip = tip
    }

    var lastTip: CGPoint?

    func endDrag() { lastTip = nil }

    private func addFoam(_ p: CGPoint, r: CGFloat, life: Double, mud: Double, t: Double) {
        // build up: a new blob near an old one makes the old one a little fuller instead of piling forever
        if let i = foam.lastIndex(where: { $0.rinsed == nil && hypot($0.p.x - p.x, $0.p.y - p.y) < 6 }) {
            foam[i].r = min(22, foam[i].r + 1.2)
            return
        }
        foam.append(Foam(p: p, r: r, born: t, life: life, mud: mud, rinsed: nil, vy: 0, seed: .random(in: 0...100)))
        if foam.count > 170 { foam.removeFirst(foam.count - 170) }
    }

    private func addBubble(at p: CGPoint, t: Double, small: Bool = false) {
        let r: CGFloat = small ? .random(in: 4...8) : .random(in: 7...17)
        bubbles.append(Bubble(p: p, v: CGVector(dx: .random(in: -30...30), dy: .random(in: -80...(-40))), r: r, born: t,
                              life: .random(in: 1.4...2.8), seed: .random(in: 0...100)))
        if bubbles.count > 50 { bubbles.removeFirst(bubbles.count - 50) }
    }

    private func ruffle(_ p: CGPoint, _ step: CGVector, t: Double) {
        let n = max(1, hypot(step.dx, step.dy))
        if let r = ruffles.last, t - r.born < 0.03 { return }
        ruffles.append(Ruffle(p: p, dir: CGVector(dx: step.dx / n, dy: step.dy / n), born: t, seed: .random(in: 0...100)))
        if ruffles.count > 40 { ruffles.removeFirst(ruffles.count - 40) }
    }

    /// Crumbs fall from her mouth when she eats a treat.
    func crumbs(at room: CGPoint, color: Color = Color(hex: 0xC98B4E)) {
        let t = VetFX.now()
        for _ in 0..<10 {
            bits.append(Bit(p: CGPoint(x: room.x + .random(in: -14...14), y: room.y), v: CGVector(dx: .random(in: -120...120), dy: .random(in: -160...(-40))),
                            born: t, life: 2.2, size: .random(in: 3...6), color: color, spin: .random(in: -500...500),
                            bounced: false, gravity: 900, fluff: false))
        }
    }

    func pressSticker(at p: CGPoint) {
        presses.append((p, VetFX.now()))
        if presses.count > 8 { presses.removeFirst() }
    }

    func wrap(_ spot: Int) { wraps[spot] = VetFX.now() }

    // MARK: Stepping (called every frame)

    /// `toPatient` converts room points to patient points; `floorY` is the floor line in the room.
    func step(to t: Double, toPatient: (CGPoint) -> CGPoint, toRoom: (CGPoint) -> CGPoint, floorY: CGFloat) {
        let dt = CGFloat(min(0.05, max(0, t - (last ?? t))))
        last = t
        guard dt > 0 else { return }
        let d = Double(dt)

        // lean: a soft spring back to standing straight
        let target = t < leanUntil ? leanTarget : 0
        leanV += ((target - lean) * 90 - leanV * 11) * d
        lean += leanV * d

        foam.removeAll { f in
            if let r = f.rinsed { return t - r > 0.9 }
            return t - f.born > f.life
        }
        for i in foam.indices where foam[i].rinsed != nil {
            foam[i].vy += 520 * dt
            foam[i].p.y += foam[i].vy * dt
            foam[i].p.x += CGFloat(sin(foam[i].seed + t * 6)) * 12 * dt
        }
        smears.removeAll { t - $0.born > $0.soak }
        ruffles.removeAll { t - $0.born > 0.9 }
        pops.removeAll { t - $0.born > 0.22 }
        splashes.removeAll { t - $0.born > 0.4 }
        mist.removeAll { t - $0.born > $0.life }
        bits.removeAll { t - $0.born > $0.life }
        beads.removeAll { t - $0.born > $0.life }
        streams.removeAll { t - $0.born > $0.life }

        for i in wet.indices { wet[i].amount -= 0.025 * d }
        wet.removeAll { $0.amount <= 0 }
        puddle = max(0, puddle - 0.018 * d)

        // bubbles float up with a wobble, then pop
        var keep: [Bubble] = []
        for var b in bubbles {
            if t - b.born > b.life {
                pops.append(Pop(p: b.p, r: b.r, born: t))
                if t - lastBubbleSound > 0.25 {
                    lastBubbleSound = t
                    VetSound.shared.play(.pop, volume: 0.18, gap: 0.2)
                }
                continue
            }
            b.v.dy -= 10 * dt
            b.v.dx += CGFloat(sin(t * 3 + b.seed)) * 40 * dt
            b.v.dx *= 1 - 0.8 * dt
            b.p.x += b.v.dx * dt
            b.p.y += b.v.dy * dt
            keep.append(b)
        }
        bubbles = keep

        // water drops: fall, land on fur (wet it, bead up, run down) or splash on the floor
        var still: [Drop] = []
        for var q in drops {
            q.v.dy += 1500 * dt
            q.p.x += q.v.dx * dt
            q.p.y += q.v.dy * dt
            let pp = toPatient(q.p)
            if pp.y > q.startY + q.depth && silhouette.contains(pp) {
                land(pp, room: q.p, t: t)
                continue
            }
            if q.p.y >= floorY {
                splashes.append(Splash(p: CGPoint(x: q.p.x, y: floorY + .random(in: -6...6)), born: t, size: 1, floor: true, mud: q.mud))
                puddle = min(1, puddle + 0.0035)
                continue
            }
            still.append(q)
        }
        drops = still

        for i in beads.indices { beads[i].p.y += beads[i].vy * dt }
        for i in streams.indices {
            streams[i].vy = min(90, streams[i].vy + 60 * dt)
            streams[i].p.y += streams[i].vy * dt
            streams[i].p.x += CGFloat(sin(t * 4 + streams[i].seed)) * 6 * dt
            streams[i].trail.append(streams[i].p)
            if streams[i].trail.count > 16 { streams[i].trail.removeFirst() }
            if !silhouette.contains(streams[i].p) {
                // it ran off the fur: let it fall as a drop
                let r = toRoom(streams[i].p)
                drops.append(Drop(p: r, v: CGVector(dx: 0, dy: 60), r: 3, depth: 10_000, startY: 0, mud: streams[i].mud))
                streams[i].trail.removeAll()
                streams[i].p.y = 10_000
            }
        }
        streams.removeAll { $0.p.y > 5_000 }

        for i in mist.indices {
            mist[i].p.x += mist[i].v.dx * dt
            mist[i].p.y += mist[i].v.dy * dt
            mist[i].v.dx *= 1 - 1.5 * dt
            mist[i].v.dy *= 1 - 1.5 * dt
        }

        for i in bits.indices {
            bits[i].v.dy += bits[i].gravity * dt
            if bits[i].fluff {
                bits[i].v.dx += CGFloat(sin(t * 3 + Double(i))) * 60 * dt
                bits[i].v.dx *= 1 - 1.2 * dt
                bits[i].v.dy = min(bits[i].v.dy, 60)
            }
            bits[i].p.x += bits[i].v.dx * dt
            bits[i].p.y += bits[i].v.dy * dt
            if bits[i].p.y > floorY && bits[i].v.dy > 0 {
                bits[i].p.y = floorY
                if !bits[i].bounced && !bits[i].fluff {
                    bits[i].v.dy *= -0.35
                    bits[i].v.dx *= 0.5
                    bits[i].bounced = true
                } else {
                    bits[i].v = .zero
                }
            }
        }
    }

    private func land(_ p: CGPoint, room: CGPoint, t: Double) {
        splashes.append(Splash(p: room, born: t, size: 0.6, floor: false, mud: false))
        if let i = wet.firstIndex(where: { hypot($0.p.x - p.x, $0.p.y - p.y) < 34 }) {
            wet[i].amount = min(1, wet[i].amount + 0.05)
        } else {
            wet.append(Wet(p: p, amount: 0.25, r: .random(in: 34...50)))
            if wet.count > 40 { wet.removeFirst() }
        }
        let roll = Double.random(in: 0...1)
        if roll < 0.14 {
            beads.append(Bead(p: CGPoint(x: p.x + .random(in: -8...8), y: p.y), r: .random(in: 2.5...5), born: t,
                              vy: .random(in: 2...12), life: .random(in: 4...7)))
            if beads.count > 70 { beads.removeFirst() }
        } else if roll < 0.2 {
            streams.append(Stream(p: p, trail: [p], born: t, life: .random(in: 1.2...2.2), mud: mudNear(p), vy: 20, seed: .random(in: 0...100)))
            if streams.count > 18 { streams.removeFirst() }
        }
    }

    /// Mud spots that are still dirty; set by the exam room each frame.
    var mudSpots: [CGPoint] = []
    private func mudNear(_ p: CGPoint) -> Bool { mudSpots.contains { hypot($0.x - p.x, $0.y - p.y) < 70 } }

    // MARK: Drawing on the patient (patient art coordinates)

    /// Wet fur, cream, foam, water running down: drawn over the body, under the face.
    func drawOnFur(_ c: GraphicsContext, t: Double) {
        // wet fur goes darker and glossy
        for w in wet {
            let a = min(1, w.amount)
            let rect = CGRect(x: w.p.x - w.r, y: w.p.y - w.r, width: w.r * 2, height: w.r * 2)
            c.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [Color(hex: 0x3B2A4A, alpha: 0.16 * a), Color(hex: 0x3B2A4A, alpha: 0)]),
                                                                 center: w.p, startRadius: 0, endRadius: w.r))
            var sheen = Path()
            sheen.addArc(center: w.p, radius: w.r * 0.55, startAngle: .degrees(200), endAngle: .degrees(250), clockwise: false)
            c.stroke(sheen, with: .color(.white.opacity(0.45 * a)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // cream and antiseptic: a glossy smear that soaks in
        for s in smears {
            let age = t - s.born
            let k = max(0, 1 - age / s.soak)
            var seg = Path()
            seg.move(to: s.a)
            seg.addLine(to: s.b)
            let w = s.width * CGFloat(0.55 + 0.45 * k)
            c.stroke(seg, with: .color(s.color.opacity(0.85 * k)), style: StrokeStyle(lineWidth: w, lineCap: .round))
        }
        for s in smears where t - s.born < s.soak * 0.6 {
            let k = 1 - (t - s.born) / (s.soak * 0.6)
            var seg = Path()
            seg.move(to: CGPoint(x: s.a.x - 3, y: s.a.y - s.width * 0.22))
            seg.addLine(to: CGPoint(x: s.b.x - 3, y: s.b.y - s.width * 0.22))
            c.stroke(seg, with: .color(.white.opacity(0.7 * k)), style: StrokeStyle(lineWidth: max(1.5, s.width * 0.16), lineCap: .round))
        }

        // fur strands bend the way the comb went and spring back
        for r in ruffles {
            let age = t - r.born
            let spring = CGFloat(exp(-age * 5) * cos(age * 17))
            let fade = min(1, (0.9 - age) / 0.3)
            for i in 0..<7 {
                let off = CGFloat(i - 3) * 6.5
                let jit = CGFloat(sin(r.seed + Double(i) * 1.7)) * 3
                let base = CGPoint(x: r.p.x + off, y: r.p.y - 10 + jit)
                let len: CGFloat = 15 + CGFloat(i % 3) * 3
                let bend = CGVector(dx: r.dir.dx * 13 * spring, dy: r.dir.dy * 9 * spring)
                let tip = CGPoint(x: base.x + off * 0.15 + bend.dx, y: base.y + len + bend.dy)
                var strand = Path()
                strand.move(to: base)
                strand.addQuadCurve(to: tip, control: CGPoint(x: base.x + bend.dx * 0.2, y: base.y + len * 0.55))
                c.stroke(strand, with: .color(lineColor.opacity(0.55 * fade)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        }

        // water running down the fur
        for s in streams where s.trail.count > 1 {
            let fade = min(1, (s.life - (t - s.born)) / 0.4)
            var path = Path()
            path.addLines(s.trail)
            let col = s.mud ? Color(hex: 0x8A6044) : Color(hex: 0xA8D8FF)
            c.stroke(path, with: .color(col.opacity(0.55 * fade)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            let head = CGRect(x: s.p.x - 3.6, y: s.p.y - 3, width: 7.2, height: 8)
            c.fill(Path(ellipseIn: head), with: .color(col.opacity(0.9 * fade)))
            c.fill(Path(ellipseIn: CGRect(x: s.p.x - 1.8, y: s.p.y - 1.5, width: 2.2, height: 2.6)), with: .color(.white.opacity(0.9 * fade)))
        }

        // water beads sitting on the fur
        for b in beads {
            let fade = min(1, (b.life - (t - b.born)) / 0.6)
            let rect = CGRect(x: b.p.x - b.r, y: b.p.y - b.r, width: b.r * 2, height: b.r * 2.1)
            c.fill(Path(ellipseIn: rect.offsetBy(dx: 0.6, dy: 1.4)), with: .color(Color(hex: 0x3B2A4A, alpha: 0.16 * fade)))
            c.fill(Path(ellipseIn: rect), with: .color(Color(hex: 0xDDF1FF, alpha: 0.75 * fade)))
            c.fill(Path(ellipseIn: CGRect(x: b.p.x - b.r * 0.55, y: b.p.y - b.r * 0.6, width: b.r * 0.6, height: b.r * 0.55)),
                   with: .color(.white.opacity(fade)))
        }

        drawFoam(c, t: t)
    }

    private func foamLook(_ f: Foam, t: Double) -> (CGPoint, CGFloat, Double) {
        let age = t - f.born
        var r = f.r * CGFloat(min(1, age * 8)) * CGFloat(1 + 0.035 * sin(t * 2.6 + f.seed))
        var o = 1.0
        if let rinsed = f.rinsed {
            let k = (t - rinsed) / 0.9
            o = max(0, 1 - k)
            r *= CGFloat(1 - 0.3 * k)
        } else {
            // foam settles and thins out near the end
            let left = f.life - age
            if left < 2 { o = max(0, left / 2); r *= CGFloat(0.75 + 0.25 * o) }
        }
        return (f.p, r, o)
    }

    private func drawFoam(_ c: GraphicsContext, t: Double) {
        guard !foam.isEmpty else { return }
        // three passes so the blobs merge into one foamy mass: shadow, body, then shine
        for f in foam {
            let (p, r, o) = foamLook(f, t: t)
            c.fill(Path(ellipseIn: CGRect(x: p.x - r + 1.5, y: p.y - r + 3, width: r * 2, height: r * 2)),
                   with: .color(Color(hex: 0x7C93AE, alpha: 0.32 * o)))
        }
        for f in foam {
            let (p, r, o) = foamLook(f, t: t)
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            c.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [Color.white.opacity(o), Color(hex: 0xF3F8FF, alpha: o), Color(hex: 0xD5E4F3, alpha: o)]),
                center: CGPoint(x: p.x - r * 0.3, y: p.y - r * 0.35), startRadius: 0, endRadius: r * 1.3))
            if f.mud > 0.02 {
                c.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.12, dy: r * 0.12)),
                       with: .color(Color(hex: 0xA0704C, alpha: 0.55 * f.mud * o)))
            }
        }
        for f in foam {
            let (p, r, o) = foamLook(f, t: t)
            guard r > 3 else { continue }
            c.fill(Path(ellipseIn: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.6, width: r * 0.42, height: r * 0.3)),
                   with: .color(.white.opacity(0.95 * o)))
            // a few tiny see-through bubbles in the lather, with a rainbow rim
            let k = Int(f.seed) % 3
            for j in 0..<(1 + k % 2) {
                let a = f.seed + Double(j) * 2.4
                let br = r * 0.28
                let bp = CGPoint(x: p.x + CGFloat(cos(a)) * r * 0.45, y: p.y + CGFloat(sin(a)) * r * 0.4)
                let ring = Path(ellipseIn: CGRect(x: bp.x - br, y: bp.y - br, width: br * 2, height: br * 2))
                c.stroke(ring, with: .linearGradient(Gradient(colors: [Color(hex: 0xA6D8FF, alpha: o), Color(hex: 0xFFC2E2, alpha: o), Color(hex: 0xC9F2C2, alpha: o)]),
                                                     startPoint: CGPoint(x: bp.x - br, y: bp.y - br), endPoint: CGPoint(x: bp.x + br, y: bp.y + br)),
                         lineWidth: 1.2)
            }
        }
    }

    /// A sticker that was just pressed on lands with a little squash.
    func pressScale(at p: CGPoint, t: Double) -> CGFloat {
        guard let q = presses.last(where: { hypot($0.p.x - p.x, $0.p.y - p.y) < 2 }) else { return 1 }
        let age = t - q.born
        guard age < 0.45 else { return 1 }
        if age < 0.12 { return CGFloat(1.35 - age / 0.12 * 0.45) }
        let k = (age - 0.12) / 0.33
        return CGFloat(0.9 + 0.1 * k + 0.05 * sin(k * .pi))
    }

    /// An elastic bandage wound round a sore paw, strip by strip, with the roll rolling round.
    static func drawWrap(_ c: GraphicsContext, at p: CGPoint, started: Double?, t: Double) {
        let age = started.map { t - $0 } ?? 10
        let strips = 4
        let each = 0.2
        for i in 0..<strips {
            let k = CGFloat(max(0, min(1, (age - Double(i) * each) / each)))
            guard k > 0 else { break }
            var g = c
            let y = p.y - 24 + CGFloat(i) * 15
            g.translateBy(x: p.x, y: y)
            g.rotate(by: .degrees(i % 2 == 0 ? -9 : 8))
            let w: CGFloat = 70
            let fromLeft = i % 2 == 0
            let shown = CGRect(x: fromLeft ? -w / 2 : w / 2 - w * k, y: -10, width: w * k, height: 20)
            let strip = Path(roundedRect: shown, cornerRadius: 9)
            g.fill(strip, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xF4ECF7), Color(hex: 0xE2D6EA)]),
                                                startPoint: CGPoint(x: 0, y: -10), endPoint: CGPoint(x: 0, y: 10)))
            g.stroke(strip, with: .color(Color(hex: 0xBBA9CC)), lineWidth: 3)
            // woven texture
            var weave = Path()
            var x = shown.minX + 6
            while x < shown.maxX - 4 {
                weave.move(to: CGPoint(x: x, y: -7))
                weave.addLine(to: CGPoint(x: x - 3, y: 7))
                x += 8
            }
            g.stroke(weave, with: .color(Color(hex: 0xE4DAEE)), lineWidth: 1.6)
            if k < 1 {
                // the roll, turning as it goes
                let rx = fromLeft ? shown.maxX : shown.minX
                let roll = Path(ellipseIn: CGRect(x: rx - 11, y: -12, width: 22, height: 24))
                g.fill(roll, with: .color(Color(hex: 0xFAF5FC)))
                g.stroke(roll, with: .color(Color(hex: 0xBBA9CC)), lineWidth: 3)
                var spoke = Path()
                let a = Double(k) * 9
                spoke.move(to: CGPoint(x: rx, y: 0))
                spoke.addLine(to: CGPoint(x: rx + CGFloat(cos(a)) * 7, y: CGFloat(sin(a)) * 8))
                g.stroke(spoke, with: .color(Color(hex: 0xBBA9CC)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        if age > Double(strips) * each {
            let pop = CGFloat(min(1, (age - Double(strips) * each) * 6))
            var g = c
            g.translateBy(x: p.x + 8, y: p.y - 2)
            g.scaleBy(x: pop, y: pop)
            let h = VetExamView.heart(11)
            g.fill(h, with: .color(Color(hex: 0xFF8FB8)))
            g.stroke(h, with: .color(.white), lineWidth: 2.5)
        }
    }

    // MARK: Drawing in the room

    /// Puddle on the floor, under the patient. `floor` is the floor point under the patient.
    func drawPuddle(_ c: GraphicsContext, floor: CGPoint, t: Double) {
        guard puddle > 0.01 else { return }
        let a = CGFloat(min(1, puddle * 1.6))
        let w = 140 + 300 * a, h = 22 + 18 * a
        let rect = CGRect(x: floor.x - w / 2, y: floor.y - h / 2 + 6, width: w, height: h)
        let wobble = Path(ellipseIn: rect)
        c.fill(wobble, with: .linearGradient(Gradient(colors: [Color(hex: 0xC9E9FF, alpha: 0.55 * Double(a)), Color(hex: 0x8EC5FF, alpha: 0.5 * Double(a))]),
                                             startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
        c.stroke(wobble, with: .color(Color(hex: 0x7FB6E8, alpha: 0.45 * Double(a))), lineWidth: 2)
        c.fill(Path(ellipseIn: CGRect(x: rect.minX + w * 0.18, y: rect.minY + h * 0.22, width: w * 0.22, height: h * 0.18)),
               with: .color(.white.opacity(0.6 * Double(a))))
    }

    /// Bubbles, drops, splashes, mist, crumbs: all in room coordinates.
    func drawInRoom(_ c: GraphicsContext, t: Double) {
        for m in mist {
            let age = t - m.born
            let k = age / m.life
            let r = m.r * CGFloat(1 + k * 1.4)
            let o = 0.5 * (1 - k) * min(1, age * 8)
            c.fill(Path(ellipseIn: CGRect(x: m.p.x - r, y: m.p.y - r, width: r * 2, height: r * 2)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xF4FBFF, alpha: o), Color(hex: 0xE3F2FF, alpha: 0)]),
                                         center: m.p, startRadius: 0, endRadius: r))
        }

        for s in splashes {
            let age = (t - s.born) / 0.4
            let col = s.mud ? Color(hex: 0x9C7457) : Color(hex: 0x9ED0FF)
            if s.floor {
                let rw = 8 + 30 * CGFloat(age), rh = rw * 0.3
                c.stroke(Path(ellipseIn: CGRect(x: s.p.x - rw, y: s.p.y - rh, width: rw * 2, height: rh * 2)),
                         with: .color(col.opacity(0.7 * (1 - age))), lineWidth: 1.8)
            }
            // a little crown of droplets
            for j in 0..<4 {
                let ang = Double.pi * (1.1 + Double(j) * 0.27)
                let d = CGFloat(age) * 26 * s.size
                let up = CGFloat(age * age) * 50 * s.size - CGFloat(age) * 30 * s.size
                let q = CGPoint(x: s.p.x + CGFloat(cos(ang)) * d, y: s.p.y + CGFloat(sin(ang)) * d * 0.6 + up)
                let r = 2.4 * s.size * CGFloat(1 - age * 0.6)
                c.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)), with: .color(col.opacity(0.85 * (1 - age))))
            }
        }

        for q in drops {
            var streak = Path()
            streak.move(to: q.p)
            streak.addLine(to: CGPoint(x: q.p.x - q.v.dx * 0.018, y: q.p.y - q.v.dy * 0.018))
            let col = q.mud ? Color(hex: 0x9C7457) : Color(hex: 0xAED8FF)
            c.stroke(streak, with: .color(col.opacity(0.85)), style: StrokeStyle(lineWidth: q.r * 2, lineCap: .round))
            c.fill(Path(ellipseIn: CGRect(x: q.p.x - q.r * 0.45, y: q.p.y - q.r * 0.9, width: q.r * 0.7, height: q.r * 0.9)),
                   with: .color(.white.opacity(0.9)))
        }

        for b in bubbles {
            let age = t - b.born
            let r = b.r * CGFloat(min(1, age * 6)) * CGFloat(1 + 0.06 * sin(t * 9 + b.seed))
            let squash = CGFloat(1 + 0.07 * sin(t * 7 + b.seed))
            let rect = CGRect(x: b.p.x - r * squash, y: b.p.y - r / squash, width: r * 2 * squash, height: r * 2 / squash)
            let shape = Path(ellipseIn: rect)
            c.fill(shape, with: .radialGradient(Gradient(colors: [Color.white.opacity(0.02), Color(hex: 0xDCEEFF, alpha: 0.18), Color.white.opacity(0.45)]),
                                                center: b.p, startRadius: 0, endRadius: r))
            // soap-film colours slide round the rim
            let spin = t * 1.4 + b.seed
            c.stroke(shape, with: .linearGradient(Gradient(colors: [Color(hex: 0x9FD4FF, alpha: 0.9), Color(hex: 0xFFB3DA, alpha: 0.9),
                                                                    Color(hex: 0xFFF0A6, alpha: 0.9), Color(hex: 0xB8F0C4, alpha: 0.9)]),
                                                  startPoint: CGPoint(x: b.p.x + CGFloat(cos(spin)) * r, y: b.p.y + CGFloat(sin(spin)) * r),
                                                  endPoint: CGPoint(x: b.p.x - CGFloat(cos(spin)) * r, y: b.p.y - CGFloat(sin(spin)) * r)),
                     lineWidth: max(1.2, r * 0.12))
            c.fill(Path(ellipseIn: CGRect(x: b.p.x - r * 0.55, y: b.p.y - r * 0.62, width: r * 0.42, height: r * 0.3)),
                   with: .color(.white.opacity(0.95)))
            c.fill(Path(ellipseIn: CGRect(x: b.p.x + r * 0.3, y: b.p.y + r * 0.35, width: r * 0.16, height: r * 0.12)),
                   with: .color(.white.opacity(0.7)))
        }

        for p in pops {
            let k = (t - p.born) / 0.22
            let r = p.r * CGFloat(1 + k * 0.6)
            for j in 0..<6 {
                let a = Double(j) / 6 * 2 * .pi
                var dash = Path()
                dash.move(to: CGPoint(x: p.p.x + CGFloat(cos(a)) * r * 0.8, y: p.p.y + CGFloat(sin(a)) * r * 0.8))
                dash.addLine(to: CGPoint(x: p.p.x + CGFloat(cos(a)) * r * 1.15, y: p.p.y + CGFloat(sin(a)) * r * 1.15))
                c.stroke(dash, with: .color(Color(hex: 0xBFE3FF, alpha: 1 - k)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }

        for b in bits {
            let age = t - b.born
            let fade = min(1, (b.life - age) / 0.4)
            var g = c
            g.opacity = fade
            g.translateBy(x: b.p.x, y: b.p.y)
            g.rotate(by: .degrees(b.bounced && b.v == .zero ? 0 : b.spin * age))
            if b.fluff {
                var tuft = Path()
                tuft.move(to: CGPoint(x: -b.size, y: 0))
                tuft.addQuadCurve(to: CGPoint(x: b.size, y: 0), control: CGPoint(x: 0, y: -b.size * 1.2))
                g.stroke(tuft, with: .color(lineColor.opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                var tuft2 = Path()
                tuft2.move(to: CGPoint(x: -b.size * 0.6, y: 2))
                tuft2.addQuadCurve(to: CGPoint(x: b.size * 0.8, y: 3), control: CGPoint(x: 0, y: -b.size * 0.6))
                g.stroke(tuft2, with: .color(furColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else {
                let r = CGRect(x: -b.size / 2, y: -b.size / 2, width: b.size, height: b.size * 0.8)
                g.fill(Path(roundedRect: r, cornerRadius: b.size * 0.3), with: .color(b.color))
            }
        }
    }
}

extension VetFX {
    private static let latherBlobs: [(CGFloat, CGFloat, CGFloat)] = [
        (-18, 4, 15), (4, -12, 14), (18, 8, 15), (-4, 18, 12), (-26, -14, 10), (26, -10, 9), (8, 4, 13), (-10, -2, 11),
    ]

    /// A patch of lather on a spot that still needs rinsing. `amount` 0...1, `mud` 0...1 tints it brown.
    static func drawLather(_ c: GraphicsContext, at p: CGPoint, amount: CGFloat, mud: Double, t: Double) {
        guard amount > 0.02 else { return }
        let blobs = latherBlobs.enumerated().map { i, b -> (CGPoint, CGFloat) in
            let r = b.2 * (0.5 + 0.5 * amount) * CGFloat(1 + 0.04 * sin(t * 2.4 + Double(i)))
            return (CGPoint(x: p.x + b.0 * (0.6 + 0.4 * amount), y: p.y + b.1 * (0.6 + 0.4 * amount)), r)
        }
        let o = Double(min(1, amount * 1.5))
        for (q, r) in blobs {
            c.fill(Path(ellipseIn: CGRect(x: q.x - r + 1.5, y: q.y - r + 3, width: r * 2, height: r * 2)),
                   with: .color(Color(hex: 0x7C93AE, alpha: 0.3 * o)))
        }
        for (q, r) in blobs {
            let rect = CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)
            c.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [Color.white.opacity(o), Color(hex: 0xF3F8FF, alpha: o), Color(hex: 0xD5E4F3, alpha: o)]),
                center: CGPoint(x: q.x - r * 0.3, y: q.y - r * 0.35), startRadius: 0, endRadius: r * 1.3))
            if mud > 0.02 {
                c.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.12, dy: r * 0.12)), with: .color(Color(hex: 0xA0704C, alpha: 0.55 * mud * o)))
            }
        }
        for (q, r) in blobs {
            c.fill(Path(ellipseIn: CGRect(x: q.x - r * 0.55, y: q.y - r * 0.6, width: r * 0.42, height: r * 0.3)),
                   with: .color(.white.opacity(0.95 * o)))
        }
    }
}
