import SwiftUI

// MARK: - Soft serve and whipped cream
//
// Holding or tapping a handle pushes a ridged rope out of the nozzle: beads 5 points apart, chained so the hanging
// part sways and stretches under gravity. The stand turns under the nozzle like a hand turning a cone. When the lowest
// bead reaches the swirl it is laid there, on top of the bead laid one turn earlier, so the rope coils into rings.
// The rings narrow as they climb (the stand slides so the nozzle stays over the ring), the stand sinks as the
// swirl grows, and when she lets go the last bit pulls up into a curl on top. Pressing again unfurls the curl so she
// can keep layering or mixing flavors until the swirl reaches max height.
//
// The whipped-cream can lays a small rosette the same way where she holds it.

struct ICFreeBead {
    var p: CGPoint
    var v: CGVector
    var flavor: Int
}

struct ICWhipSession {
    var center: CGFloat
    var base: CGFloat
    var turn: CGFloat = 0
    var acc: CGFloat = 0
    var running = true
}

extension IceSim {
    static let softSpeed: CGFloat = 210
    static let beadGap: CGFloat = 5
    static let ropeR: CGFloat = 13
    static let maxRope = 320

    func resetSoft() {
        free = []
        prevTurn = 0
        rho = ropeStartRadius
        softFull = false
        whipSession = nil
        softAcc = 0
        lever = nil
        softBurstTime = 0
        spin = 0
    }

    var ropeStartRadius: CGFloat { build.base == .cup ? 34 : 30 }

    /// Where the rope starts: in the cone's mouth, the cup's bottom, or on top of the scoops.
    func ropeFloor() -> CGFloat {
        if !build.scoops.isEmpty, let t = build.top(0) { return t - 6 }
        return (build.base ?? .waffle).floor
    }

    /// The height of the ring being laid now (the stand sinks to keep it just under the nozzle).
    func softTop() -> CGFloat {
        build.rope.last?.h ?? ropeFloor()
    }

    private func unfurlSoftTip() {
        guard build.ropeTipped else { return }
        let trim = min(build.ropeTipCount, build.rope.count)
        if trim > 0 { build.rope.removeLast(trim) }
        build.ropeTipCount = 0
        build.ropeTipped = false
        prevTurn = min(prevTurn, max(0, build.rope.count - 1))
        profileDirty = true
    }

    /// She pressed (or let go of, with nil) a soft-serve handle. Releasing early never locks out adding more swirls.
    func pressLever(_ i: Int?) {
        if let i = i {
            guard station == .soft else { return }
            if build.base == nil { placeBase(.waffle) }
            if build.base == .glass && build.fill > 0.01 { return }
            if softFull || build.rope.count >= IceSim.maxRope {
                softFull = true
                IceSound.shared.play(.plop, volume: 0.35)
                Sound.shared.tap()
                return
            }
            unfurlSoftTip()
            softBurstTime = 0
            lever = i
            IceSound.shared.play(.lever, volume: 0.7)
            Sound.shared.tap()
            if build.ropeFlavor == nil { build.ropeFlavor = ICSoft(rawValue: i) }
        } else {
            softBurstTime = 0
            if lever != nil {
                lever = nil
                IceSound.shared.play(.lever, volume: 0.45, rate: 0.8)
            }
        }
    }

    /// 1-tap on any lever dispenses a smooth 0.9s automatic swirl layer so pre-readers can tap or hold.
    func tapLever(_ i: Int, duration: CGFloat = 0.9) {
        guard station == .soft else { return }
        if build.base == nil { placeBase(.waffle) }
        if build.base == .glass && build.fill > 0.01 { return }
        if softFull || build.rope.count >= IceSim.maxRope {
            softFull = true
            IceSound.shared.play(.plop, volume: 0.35)
            Sound.shared.tap()
            return
        }
        unfurlSoftTip()
        lever = i
        softBurstTime = max(softBurstTime, duration)
        if build.ropeFlavor == nil { build.ropeFlavor = ICSoft(rawValue: i) }
        IceSound.shared.play(.lever, volume: 0.7)
        Sound.shared.tap()
    }

    /// Keeps a freshly tapped lever flowing smoothly through a 0.9s automatic burst on release.
    func triggerSoftBurst(_ i: Int, duration: CGFloat = 0.9) {
        guard station == .soft, !softFull, build.rope.count < IceSim.maxRope else {
            pressLever(nil)
            return
        }
        unfurlSoftTip()
        lever = i
        softBurstTime = max(softBurstTime, duration)
        if build.ropeFlavor == nil { build.ropeFlavor = ICSoft(rawValue: i) }
    }

    func stepSoft(_ dt: CGFloat) {
        if softBurstTime > 0 {
            softBurstTime = max(0, softBurstTime - dt)
            if softBurstTime == 0 && lever != nil {
                lever = nil
                IceSound.shared.play(.lever, volume: 0.45, rate: 0.8)
            }
        }
        for i in 0..<leverPull.count {
            let target: CGFloat = lever == i ? 1 : 0
            leverPull[i] += (target - leverPull[i]) * min(1, dt * 16)
        }
        let flowing = lever.map { leverPull[$0] > 0.6 } ?? false
        // the turntable turns while the rope comes out, and coasts to a stop after
        let speed: CGFloat = flowing && !softFull ? IceSim.softSpeed / max(rho, 6) : 0
        softSpinV += (speed - softSpinV) * min(1, dt * (flowing ? 10 : 3))
        if softSpinV > 0.01 {
            spin += softSpinV * dt
            build.ropeSpin = spin
            profileDirty = true
        }
        guard station == .soft || !free.isEmpty else { return }
        let nozzle = ICGeo.nozzle
        if flowing && !softFull, let l = lever, build.base != nil {
            softAcc += IceSim.softSpeed * dt
            while softAcc >= IceSim.beadGap {
                softAcc -= IceSim.beadGap
                free.append(ICFreeBead(p: CGPoint(x: nozzle.x, y: nozzle.y + 6), v: CGVector(dx: 0, dy: IceSim.softSpeed), flavor: l))
            }
        }
        guard !free.isEmpty else {
            tipSwirl()
            return
        }
        // the hanging rope: gravity, a little air, then keep beads no further apart than the gap
        let sway = sin(CGFloat(time) * 2.3) * 0.6
        for k in free.indices {
            free[k].v.dy += IceSim.gravity * 0.5 * dt
            free[k].v.dx += (ICGeo.nozzle.x + sway - free[k].p.x) * 8 * dt
            free[k].v.dx *= (1 - 4 * dt)
            free[k].p.x += free[k].v.dx * dt
            free[k].p.y += free[k].v.dy * dt
        }
        let attached = flowing && !softFull
        for _ in 0..<2 {
            if attached, let n = free.indices.last {
                free[n].p = CGPoint(x: nozzle.x, y: max(free[n].p.y, nozzle.y + 4))
                free[n].p.y = min(free[n].p.y, nozzle.y + IceSim.beadGap)
            }
            var k = free.count - 2
            while k >= 0 {
                let a = free[k + 1].p
                var b = free[k].p
                let d = hypot(b.x - a.x, b.y - a.y)
                if d > IceSim.beadGap * 1.15 {
                    let f = IceSim.beadGap * 1.15 / d
                    b = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                    free[k].p = b
                    free[k].v.dy = min(free[k].v.dy, free[k + 1].v.dy + 40)
                }
                k -= 1
            }
        }
        // the lowest beads lay down on the swirl
        var laid = 0
        while let first = free.first, laid < 12 {
            let support = ringSupport()
            let landY = S.y - support
            if first.p.y < landY - IceSim.ropeR * 0.6 { break }
            layBead(first, support: support)
            free.removeFirst()
            laid += 1
        }
        if free.count > 140 { free.removeFirst(free.count - 140) }
    }

    /// The height the next bead sits at: one ring up on the bead laid a turn ago, or the floor.
    private func ringSupport() -> CGFloat {
        let rope = build.rope
        guard let first = rope.first else { return ropeFloor() }
        let want = spin - 2 * .pi
        if want < first.turn { return ropeFloor() }
        var j = min(prevTurn, rope.count - 1)
        while j + 1 < rope.count && rope[j + 1].turn <= want { j += 1 }
        prevTurn = j
        return max(rope[j].h + IceSim.ropeR * 1.5, rope.last?.h ?? ropeFloor())
    }

    private func layBead(_ f: ICFreeBead, support: CGFloat) {
        guard build.base != nil else { return }
        let flavor = ICSoft(rawValue: f.flavor) ?? .vanilla
        let stripe = flavor == .twist ? Int((spin / 0.9).rounded(.down)) % 2 : 0
        let tipBump: CGFloat = rho < 3 ? 2.5 : 0
        let h = support + tipBump
        // laid under the nozzle, stored in the turntable's own frame so it turns with the swirl
        build.rope.append(ICBead(x: rho * cos(spin), z: -rho * sin(spin), h: h, r: IceSim.ropeR * (rho < 4 ? 0.85 : 1),
                                 c: flavor.rawValue * 2 + stripe, turn: spin))
        // rings narrow as they climb
        let loops = (spin - (build.rope.first?.turn ?? spin)) / (2 * .pi)
        rho = max(0, ropeStartRadius * (1 - loops / 6.4))
        let tall = h - ropeFloor()
        if tall > 150 || (rho < 1 && loops > 6.9) || build.rope.count >= IceSim.maxRope {
            softFull = true
            lever = nil
            softBurstTime = 0
            IceSound.shared.play(.lever, volume: 0.5, rate: 0.8)
            sparkle()
        }
        profileDirty = true
    }

    /// The last of the rope pulls up into a little curl on top.
    private func tipSwirl() {
        guard lever == nil, !build.ropeTipped, build.rope.count > 10, let last = build.rope.last else { return }
        build.ropeTipped = true
        build.ropeTipCount = 4
        let c = last.c
        for k in 1...4 {
            let f = CGFloat(k)
            build.rope.append(ICBead(x: last.x * (1 - f * 0.25), z: last.z * (1 - f * 0.25), h: last.h + f * 5.5,
                                     r: IceSim.ropeR * (0.85 - f * 0.13), c: c, turn: last.turn + f * 0.3))
        }
        profileDirty = true
    }

    // MARK: Whipped cream

    func stepWhipHeld(_ dt: CGFloat) {
        guard build.base != nil, abs(tip.x - S.x) < 110, tip.y < S.y + 10 else { return }
        let cx = icClamp(tip.x - S.x, -44, 44)
        if var w = whipSession, abs(w.center - cx) > 34 {
            w.running = false
            whipSession = w
        }
        if whipSession == nil || whipSession?.running == false && abs((whipSession?.center ?? 0) - cx) > 34 {
            let base = build.top(cx) ?? 0
            whipSession = ICWhipSession(center: cx, base: base - 3)
        }
        guard var w = whipSession, w.running else { return }
        w.acc += 170 * dt
        while w.acc >= 4 && w.running {
            w.acc -= 4
            whipBead(&w)
        }
        whipSession = w
        profileDirty = true
    }

    /// Lays the next bead of a rosette: rings that narrow to a peak.
    private func whipBead(_ w: inout ICWhipSession) {
        let loops = w.turn / (2 * .pi)
        let rr = max(0, 19 * (1 - loops / 2.6))
        w.turn += 4 / max(rr, 5)
        let top: CGFloat = rr < 2 ? CGFloat(build.whip.count % 4) * 2 : 0
        build.whip.append(ICBead(x: w.center + rr * cos(w.turn), z: -rr * sin(w.turn), h: w.base + loops * 11 + top,
                                 r: 9, c: 0, turn: w.turn))
        if build.whip.count > 480 { build.whip.removeFirst(build.whip.count - 480) }
        if loops > 2.75 {
            w.running = false
            sparkle()
        }
    }

    /// A tap on a topping in the dock puts it on for her.
    func autoTopping(_ t: ICTopping) {
        if build.base == nil {
            placeBase(station == .smoothie ? .glass : station == .bingsu ? .bowl : .waffle)
        }
        if profileDirty {
            build.rebuildProfile()
            profileDirty = false
        }
        let top = build.top(0) ?? 0
        let y0 = S.y - top
        switch t {
        case .sprinkles:
            for _ in 0..<60 {
                let ci = Int.random(in: 0..<6)
                parts.append(ICPart(kind: .sprinkle, p: CGPoint(x: S.x + CGFloat.random(in: -40...40), y: y0 - 80 - CGFloat.random(in: 0...90)),
                                    v: CGVector(dx: CGFloat.random(in: -30...30), dy: CGFloat.random(in: 40...160)), life: 6, size: 1,
                                    color: ICPalette.candy[ci], colorIndex: ci, rot: CGFloat.random(in: 0...6.3), spin: CGFloat.random(in: -12...12)))
            }
            IceSound.shared.play(.shake, volume: 0.8)
        case .chocoSauce, .berrySauce, .condensedMilk:
            let col = t.sauceColor ?? ICColor(0x5A2F1F)
            let span: CGFloat = t == .condensedMilk ? 36 : 28
            for k in 0..<80 {
                let x = S.x + sin(CGFloat(k) * 0.35) * span
                parts.append(ICPart(kind: .sauce, p: CGPoint(x: x, y: y0 - 50 - CGFloat(k) * 3.5), v: CGVector(dx: 0, dy: 240),
                                    life: 4, size: 5.5, color: col, topping: t))
            }
            IceSound.shared.play(.drip, volume: 0.6)
        case .whip:
            var w = ICWhipSession(center: 0, base: top - 3)
            var n = 0
            while w.running && n < 200 {
                whipBead(&w)
                n += 1
            }
            IceSound.shared.play(.shake, volume: 0.3, rate: 0.6)
        case .cherry:
            build.cherry = ICBody(dx: 0, h: top + 150, vx: 0, vh: 0, resting: false)
        case .wafer:
            build.wafer = ICStick(dx: 16, h: (build.top(16) ?? 0) - 18, angle: 0.32)
            IceSound.shared.play(.crunch, volume: 0.7)
            sparkle()
        case .straw:
            if build.base == .glass {
                build.straw = ICStick(dx: 14, h: (build.base?.floor ?? 0) + 14, angle: 0.22)
                IceSound.shared.play(.glass, volume: 0.6)
            } else {
                build.straw = ICStick(dx: -18, h: (build.top(-18) ?? 0) - 18, angle: -0.25)
                IceSound.shared.play(.crunch, volume: 0.6)
            }
            sparkle()
        case .redBean, .mangoCubes, .strawberries, .injeolmi:
            dropBingsuPieces(t, at: nil)
            return
        }
        profileDirty = true
    }

    func stepWhip(_ dt: CGFloat) {}
}
