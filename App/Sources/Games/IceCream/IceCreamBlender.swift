import SwiftUI

// MARK: - The smoothie blender
//
// Fruit and ice are circles in the jar's own space (0 at the inside bottom, y down) that fall, bounce off the
// tapered walls and pile on each other. With the motor on, the blades whirl the jar into two rolling vortices
// (out along the bottom, up the walls, in across the top, down the middle), the way a real blender pulls fruit
// into its blades. A piece that passes the blades is cut smaller or split in two; what it loses becomes juice,
// which raises the level and colors the drink. Milk pours in from the jug (or splashes in automatically when
// she blends fruit alone so every smoothie pours full and creamy).
//
// The drink's surface stays level when the jar tips: the level is found from the jar's shape and how much is in
// it, and whatever rises past the spout pours out in a stream that falls into the glass (or onto the counter).

extension IceSim {
    static let jarArea: CGFloat = (ICGeo.jarBottomHW + ICGeo.jarTopHW) * ICGeo.jarH
    static let glassArea: CGFloat = 92 * 132
    static let milk = ICColor(0xFFFDF5)

    // MARK: Jar geometry

    /// The jar's pivot (its middle, in jar space).
    static let jarPivot = CGPoint(x: 0, y: -ICGeo.jarH / 2)

    /// A jar-space point in the world, for the jar at `at` tipped by `angle`.
    func jarWorld(_ p: CGPoint, at: CGPoint? = nil, angle: CGFloat? = nil) -> CGPoint {
        let o = at ?? jarP
        let a = angle ?? jarTilt
        let dx = p.x - IceSim.jarPivot.x, dy = p.y - IceSim.jarPivot.y
        let c = cos(a), s = sin(a)
        return CGPoint(x: o.x + IceSim.jarPivot.x + dx * c - dy * s, y: o.y + IceSim.jarPivot.y + dx * s + dy * c)
    }

    /// The inside of the jar, in the world.
    func jarInside() -> [CGPoint] {
        let b = ICGeo.jarBottomHW, t = ICGeo.jarTopHW, h = ICGeo.jarH
        return [CGPoint(x: -b, y: 0), CGPoint(x: b, y: 0), CGPoint(x: t, y: -h), CGPoint(x: -t, y: -h)].map { jarWorld($0) }
    }

    /// Area of a polygon below the line y = level (world, y down).
    static func areaBelow(_ poly: [CGPoint], _ level: CGFloat) -> CGFloat {
        var out: [CGPoint] = []
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let ain = a.y >= level, bin = b.y >= level
            if ain { out.append(a) }
            if ain != bin {
                let t = (level - a.y) / (b.y - a.y)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: level))
            }
        }
        guard out.count >= 3 else { return 0 }
        var s: CGFloat = 0
        for i in out.indices {
            let a = out[i], b = out[(i + 1) % out.count]
            s += a.x * b.y - b.x * a.y
        }
        return abs(s) / 2
    }

    /// The world height of the drink's level surface in the jar.
    func jarLevel() -> CGFloat {
        let poly = jarInside()
        let want = jarVolume * IceSim.jarArea
        var lo = poly.map { $0.y }.min() ?? 0, hi = poly.map { $0.y }.max() ?? 0
        let top = lo, bottom = hi
        if want <= 0 { return bottom }
        for _ in 0..<16 {
            let mid = (lo + hi) / 2
            if IceSim.areaBelow(poly, mid) > want { lo = mid } else { hi = mid }
        }
        return max(top, (lo + hi) / 2)
    }

    /// The lowest corner of the jar's open top: where the drink pours from.
    func spout() -> CGPoint {
        let l = jarWorld(CGPoint(x: -ICGeo.jarTopHW - 4, y: -ICGeo.jarH - 6))
        let r = jarWorld(CGPoint(x: ICGeo.jarTopHW + 4, y: -ICGeo.jarH - 6))
        return l.y > r.y ? l : r
    }

    func chunkLoad() -> CGFloat {
        var s: CGFloat = 0
        for c in chunks { s += c.r * c.r }
        return min(1, s / 4200)
    }

    var smoothieColor: ICColor { jarPaint.w > 0 ? jarPaint.color : IceSim.milk }

    // MARK: Fruit

    /// Is a point above the jar's mouth (so a fruit let go there falls in)?
    func overJar(_ p: CGPoint) -> Bool {
        jarOnBase && abs(p.x - jarP.x) < ICGeo.jarTopHW + 30 && p.y < jarP.y - 60
    }

    func releaseFruit(_ f: ICFruit) {
        let bin = ICGeo.bins[f.rawValue]
        if overJar(tip) {
            dropFruit(f, at: tip, v: CGVector(dx: tipV.dx * 0.15, dy: max(0, tipV.dy * 0.2)))
        } else {
            returning.append(ICReturn(held: .fruit(f), from: tip, to: bin, start: time, tilt: 0))
        }
    }

    /// A tap on a bin tosses a piece in.
    func tossFruit(_ f: ICFruit) {
        guard jarOnBase else { return }
        let x = jarP.x + CGFloat.random(in: -30...30)
        dropFruit(f, at: CGPoint(x: x, y: jarP.y - ICGeo.jarH - 50), v: CGVector(dx: 0, dy: 200))
        Sound.shared.play(.whoosh, volume: 0.35)
    }

    func dropFruit(_ f: ICFruit, at p: CGPoint, v: CGVector) {
        guard chunks.count < 40 else { return }
        for k in 0..<f.handful {
            let r = f.radius * (0.9 + 0.2 * icRand(chunkSeed, 1))
            var lp = CGPoint(x: p.x - jarP.x + CGFloat(k) * 9 - CGFloat(f.handful - 1) * 4.5, y: p.y - jarP.y - CGFloat(k) * 6)
            let hw = ICGeo.jarTopHW - r - 2
            lp.x = icClamp(lp.x, -hw, hw)
            chunks.append(ICChunk(fruit: f, p: lp, v: v, r: r, rot: icRand(chunkSeed, 2) * 6.3,
                                  spin: (icRand(chunkSeed, 3) - 0.5) * 6, seed: chunkSeed))
            chunkSeed += 1
        }
        if f == .ice { IceSound.shared.play(.clink, volume: 0.6) }
    }

    /// Adds a helpful splash of creamy milk when blending fruit with low or zero milk so it always pours full (>= 0.35).
    func ensureBlendMilk() {
        guard !chunks.isEmpty, jarVolume < 0.24 else { return }
        let splash = 0.24 - jarVolume
        jarVolume += splash
        jarPaint.add(IceSim.milk, Double(splash) * 0.45)
        sloshV += 2.6
        IceSound.shared.play(.plunk, volume: 0.4)
    }

    /// 1-tap Blend: splashes in milk if needed, runs a lively 1.6s blend, then automatically pours smoothly into the glass.
    func tapBlend() {
        guard station == .smoothie, jarOnBase else { return }
        if !chunks.isEmpty || jarVolume > 0.01 {
            ensureBlendMilk()
            blending = true
            blendingToggle = true
            blendAutoPour = true
            blendToggleTime = 0
            blendEmptyTime = 0
            IceSound.shared.play(.lever, volume: 0.5, rate: 1.3)
            Sound.shared.tap()
        } else {
            blending = true
            blendingToggle = true
            blendAutoPour = false
            blendToggleTime = 0
            blendEmptyTime = 0
            IceSound.shared.play(.lever, volume: 0.4, rate: 1.2)
            Sound.shared.tap()
        }
    }

    private func dissolveRemainingChunks() {
        guard !chunks.isEmpty else { return }
        var addVol: CGFloat = 0
        for c in chunks {
            let lost = c.r * c.r * .pi
            jarPaint.add(c.fruit.juice, Double(lost / IceSim.jarArea) * c.fruit.strength * 3)
            jarFruit[c.fruit.rawValue] += lost / IceSim.jarArea
            addVol += lost
        }
        chunks.removeAll()
        if addVol > 0 { jarVolume = min(0.95, jarVolume + addVol / IceSim.jarArea * 0.9) }
    }

    // MARK: Step

    func stepBlender(_ dt: CGFloat) {
        if blending && blendingToggle && jarOnBase {
            blendToggleTime += dt
            if chunks.isEmpty { blendEmptyTime += dt } else { blendEmptyTime = 0 }
            if blendAutoPour && blendToggleTime >= 1.6 {
                dissolveRemainingChunks()
                blending = false
                blendingToggle = false
                blendAutoPour = false
                blendToggleTime = 0
                blendEmptyTime = 0
                Sound.shared.play(.ding, volume: 0.45)
                sparkle()
                if jarVolume > 0.01 { autoPourJar() }
            } else if !blendAutoPour && ((blendEmptyTime > 0.55 && blendToggleTime > 0.6) || blendToggleTime > 9.0) {
                blending = false
                blendingToggle = false
                blendToggleTime = 0
                blendEmptyTime = 0
            }
        } else {
            blendToggleTime = 0
            blendEmptyTime = 0
        }
        let on = blending && jarOnBase
        motor += ((on ? 1 : 0) - motor) * min(1, dt * (on ? 5.0 : 1.8))
        if motor < 0.002 { motor = 0 }
        bladeAngle += motor * dt * 55
        stepAutoPour(dt)
        stepJarHome(dt)
        stepChunks(dt)
        stepPour(dt)
        sloshV += (-slosh * 90 - sloshV * 5) * dt
        slosh += sloshV * dt
        for i in spills.indices { spills[i].age += dt }
        spills.removeAll { $0.age > 16 }
    }

    /// One-tap assist: glides the milk jug over the blender jar, pours a splash, and returns.
    func autoPourMilk() {
        guard station == .smoothie, jarOnBase else { return }
        blending = false
        blendingToggle = false
        blendAutoPour = false
        held = nil
        returning.removeAll { $0.held == .milk }
        autoPour = .milk
        autoPourTime = 0
        autoMilkPos = ICGeo.milkHome
        milkTilt = 0
        milkPour = 0
        Sound.shared.play(.whoosh, volume: 0.4)
        Sound.shared.tap()
    }

    /// One-tap assist: lifts the blender jar beside the glass, tips to pour cleanly, and glides home.
    func autoPourJar() {
        guard station == .smoothie, jarVolume > 0.01 else { return }
        if build.base == nil { placeBase(.glass) }
        blending = false
        blendingToggle = false
        blendAutoPour = false
        held = nil
        jarOnBase = false
        autoPour = .jar
        autoPourTime = 0
        Sound.shared.play(.whoosh, volume: 0.45)
        Sound.shared.tap()
    }

    private func stepAutoPour(_ dt: CGFloat) {
        guard let mode = autoPour else { return }
        autoPourTime += dt
        switch mode {
        case .milk:
            let hover = CGPoint(x: jarP.x + 40, y: jarP.y - ICGeo.jarH - 34)
            autoMilkPos.x += (hover.x - autoMilkPos.x) * min(1, dt * 8)
            autoMilkPos.y += (hover.y - autoMilkPos.y) * min(1, dt * 8)
            let close = hypot(hover.x - autoMilkPos.x, hover.y - autoMilkPos.y) < 28
            let wantTilt: CGFloat = close && autoPourTime < 1.35 && jarVolume < 0.9 ? 1.35 : 0
            milkTilt += (wantTilt - milkTilt) * min(1, dt * 8)
            milkPour = close && milkTilt > 0.88 ? 1 : 0
            if milkPour > 0 {
                let room = 0.92 - jarVolume
                let dv = min(room, 0.24 * dt)
                if dv > 0 {
                    jarVolume += dv
                    jarPaint.add(IceSim.milk, Double(dv))
                    sloshV += 0.6
                }
                streamTo(from: milkSpout(at: autoMilkPos), v: CGVector(dx: 40, dy: 30), floorY: jarLevel(), color: IceSim.milk)
            } else {
                stream = []
            }
            if autoPourTime >= 1.45 || jarVolume >= 0.9 {
                autoPour = nil
                milkPour = 0
                stream = []
                returning.append(ICReturn(held: .milk, from: autoMilkPos, to: ICGeo.milkHome, start: time, tilt: milkTilt))
                milkTilt = 0
            }
        case .jar:
            var target = CGPoint(x: S.x - 148, y: S.y - 168 + ICGeo.jarH / 2)
            if pourRate > 0.01, let land = stream.last {
                jarAim += (S.x - land.x) * min(1, dt * 3.5)
                jarAim = icClamp(jarAim, -90, 90)
            } else {
                jarAim *= (1 - min(1, dt * 4))
            }
            target.x += jarAim
            jarP.x += (target.x - jarP.x) * min(1, dt * 8.5)
            jarP.y += (target.y - jarP.y) * min(1, dt * 8.5)
            let nearGlass = hypot(target.x - jarP.x, target.y - jarP.y) < 56
            let want: CGFloat = nearGlass ? 1.85 + 0.65 * (1 - icClamp(jarVolume / 0.5)) : 0.25
            jarTiltV += ((want - jarTilt) * 38 - jarTiltV * 8) * dt
            jarTilt += jarTiltV * dt
            if jarVolume <= 0.005 || build.fill >= 0.96 || autoPourTime > 3.2 {
                autoPour = nil
                releaseJar()
            }
        }
    }

    private func stepJarHome(_ dt: CGFloat) {
        guard held != .jar, autoPour != .jar, !jarOnBase else { return }
        let home = ICGeo.jarHome
        jarP.x += (home.x - jarP.x) * min(1, dt * 9)
        jarP.y += (home.y - jarP.y) * min(1, dt * 9)
        jarTilt += (0 - jarTilt) * min(1, dt * 10)
        if hypot(home.x - jarP.x, home.y - jarP.y) < 2 && abs(jarTilt) < 0.02 {
            jarP = home
            jarTilt = 0
            jarOnBase = true
            IceSound.shared.play(.tub, volume: 0.6)
            sloshV += 3
        }
    }

    private func stepChunks(_ dt: CGFloat) {
        guard !chunks.isEmpty else { return }
        let g: CGFloat = 1500
        let a = jarTilt
        let gx = g * sin(a), gy = g * cos(a)
        let levelLocal = -jarVolume * ICGeo.jarH
        var pile: CGFloat = 0
        for c in chunks { pile = min(pile, c.p.y - c.r) }
        let hc = max(90, -min(levelLocal, pile))
        let m = motor
        var chopped: CGFloat = 0
        var addVol: CGFloat = 0
        var newChunks: [ICChunk] = []
        for i in chunks.indices {
            var c = chunks[i]
            c.v.dx += gx * dt
            c.v.dy += gy * dt
            let wet = c.p.y > levelLocal
            if wet {
                c.v.dx *= (1 - 2.4 * dt)
                c.v.dy *= (1 - 2.4 * dt)
                if c.fruit == .ice { c.v.dy -= 1900 * dt * cos(a) }
            }
            if m > 0.02 {
                // two rolling vortices
                let cy = -hc * 0.45
                let right = c.p.x >= 0
                let cx = (right ? 1 : -1) * ICGeo.jarHW(cy) * 0.5
                let d = CGPoint(x: c.p.x - cx, y: c.p.y - cy)
                let k: CGFloat = 10 * m
                let vt = right ? CGVector(dx: d.y * k, dy: -d.x * k) : CGVector(dx: -d.y * k, dy: d.x * k)
                let pull = min(1, 5 * m * dt)
                c.v.dx += (vt.dx - c.v.dx) * pull + CGFloat.random(in: -1...1) * 90 * m
                c.v.dy += (vt.dy - c.v.dy) * pull + CGFloat.random(in: -1...1) * 90 * m
                // the blades
                if c.p.y > -34 && abs(c.p.x) < 48 && m > 0.35 && CGFloat.random(in: 0...1) < 14 * m * dt {
                    let r0 = c.r
                    if c.r > 8.5 {
                        c.r *= 0.69
                        var twin = c
                        twin.seed = chunkSeed
                        chunkSeed += 1
                        twin.v = CGVector(dx: -c.v.dx - 120, dy: -380 * m)
                        twin.p.x -= c.r * 0.6
                        twin.spin = -c.spin * 1.3
                        newChunks.append(twin)
                    } else {
                        c.r *= 0.78
                    }
                    let lost = max(0, r0 * r0 - c.r * c.r * (r0 > 8.5 ? 2 : 1)) * .pi
                    chopped += lost
                    jarPaint.add(c.fruit.juice, Double(lost / IceSim.jarArea) * c.fruit.strength * 3)
                    jarFruit[c.fruit.rawValue] += lost / IceSim.jarArea
                    addVol += lost
                    c.v.dx += (c.p.x >= 0 ? 1 : -1) * 260 * m
                    c.v.dy -= 420 * m
                    c.spin += CGFloat.random(in: -14...14)
                    IceSound.shared.play(c.fruit == .ice ? .clink : .chop, volume: Float(0.25 + 0.4 * m), gap: 0.06,
                                         rate: Float(0.9 + CGFloat.random(in: 0...0.3)))
                }
                // fine blending wears every piece down
                let wear = m * dt * 3.4
                let r1 = c.r
                c.r = max(0, c.r - wear)
                let lost = (r1 * r1 - c.r * c.r) * .pi
                jarPaint.add(c.fruit.juice, Double(lost / IceSim.jarArea) * c.fruit.strength * 3)
                jarFruit[c.fruit.rawValue] += lost / IceSim.jarArea
                addVol += lost
            }
            c.p.x += c.v.dx * dt
            c.p.y += c.v.dy * dt
            c.rot += c.spin * dt
            c.spin *= (1 - 1.2 * dt)
            // the jar's walls and bottom
            if c.p.y > -c.r {
                if c.v.dy > 320 {
                    IceSound.shared.play(c.fruit == .ice ? .clink : .plunk, volume: Float(min(0.8, c.v.dy / 1600)), gap: 0.05)
                    sloshV += min(4, c.v.dy / 400)
                }
                c.p.y = -c.r
                if c.v.dy > 0 { c.v.dy = -c.v.dy * 0.25 }
                c.v.dx *= 0.92
            }
            if c.p.y > -ICGeo.jarH - 30 {
                let hw = ICGeo.jarHW(c.p.y) - c.r
                if c.p.x > hw {
                    c.p.x = hw
                    if c.v.dx > 0 { c.v.dx = -c.v.dx * 0.3 }
                }
                if c.p.x < -hw {
                    c.p.x = -hw
                    if c.v.dx < 0 { c.v.dx = -c.v.dx * 0.3 }
                }
            }
            if c.inside {
                if c.p.y < -ICGeo.jarH + c.r {
                    c.p.y = -ICGeo.jarH + c.r
                    c.v.dy = abs(c.v.dy) * 0.3
                }
            } else if c.p.y > -ICGeo.jarH + c.r {
                c.inside = true
            }
            chunks[i] = c
        }
        chunks.append(contentsOf: newChunks)
        // pieces push each other apart
        let n = chunks.count
        if n > 1 {
            for _ in 0..<2 {
                for i in 0..<(n - 1) {
                    for j in (i + 1)..<n {
                        let dx = chunks[j].p.x - chunks[i].p.x
                        let dy = chunks[j].p.y - chunks[i].p.y
                        let rr = chunks[i].r + chunks[j].r
                        let d2 = dx * dx + dy * dy
                        if d2 >= rr * rr || d2 < 0.0001 { continue }
                        let d = sqrt(d2)
                        let push = (rr - d) * 0.5
                        let nx = dx / d, ny = dy / d
                        chunks[i].p.x -= nx * push
                        chunks[i].p.y -= ny * push
                        chunks[j].p.x += nx * push
                        chunks[j].p.y += ny * push
                        let rv = (chunks[j].v.dx - chunks[i].v.dx) * nx + (chunks[j].v.dy - chunks[i].v.dy) * ny
                        if rv < 0 {
                            let imp = -rv * 0.6
                            chunks[i].v.dx -= nx * imp
                            chunks[i].v.dy -= ny * imp
                            chunks[j].v.dx += nx * imp
                            chunks[j].v.dy += ny * imp
                        }
                    }
                }
            }
        }
        // what's small enough is gone into the drink
        var gone: [ICChunk] = []
        chunks.removeAll { c in
            if c.r < 3.2 { gone.append(c); return true }
            return false
        }
        for c in gone {
            let lost = c.r * c.r * .pi
            jarPaint.add(c.fruit.juice, Double(lost / IceSim.jarArea) * c.fruit.strength * 3)
            jarFruit[c.fruit.rawValue] += lost / IceSim.jarArea
            addVol += lost
        }
        if addVol > 0 { jarVolume = min(0.95, jarVolume + addVol / IceSim.jarArea * 0.9) }
        if chopped > 0 { sloshV += min(3, chopped / 300) }
    }

    // MARK: Pouring

    func stepJarHeld(_ dt: CGFloat) {
        // carried by its handle; over the glass it tips by itself (the way a grown-up would pour)
        let toGlass = build.base == .glass && tip.x > S.x - 280 && tip.x < S.x + 30 && tip.y < S.y - 30
        let want: CGFloat = toGlass ? 1.6 + 0.7 * (1 - icClamp(jarVolume / 0.5)) : tilt * 0.8
        jarTiltV += ((want - jarTilt) * 34 - jarTiltV * 8) * dt
        jarTilt += jarTiltV * dt
        // a gentle aim: while it pours, the jar drifts so the stream lands in the glass
        var target = CGPoint(x: tip.x, y: tip.y + ICGeo.jarH / 2)
        if toGlass, pourRate > 0.01, let land = stream.last {
            jarAim += (S.x - land.x) * min(1, dt * 3)
            jarAim = icClamp(jarAim, -90, 90)
        } else {
            jarAim *= (1 - min(1, dt * 4))
        }
        target.x += jarAim
        jarP = target
    }

    func resetBlender() {
        releaseJar()
        chunks.removeAll()
        jarVolume = 0
        jarPaint = ICPaint()
        jarFruit = [CGFloat](repeating: 0, count: ICFruit.allCases.count)
        jarP = ICGeo.jarHome
        jarTilt = 0
        jarOnBase = true
        blending = false
        blendingToggle = false
        blendAutoPour = false
        autoPour = nil
        autoPourTime = 0
        milkPour = 0
        milkTilt = 0
        motor = 0
        slosh = 0
        sloshV = 0
        spills.removeAll()
    }

    func releaseJar() {
        jarTiltV = 0
        pourRate = 0
        stream = []
        jarAim = 0
    }

    func stepMilk(_ dt: CGFloat) {
        let overJarMouth = jarOnBase && abs(tip.x - (jarP.x + 40)) < 90 && tip.y < jarP.y - ICGeo.jarH + 20
        let overGlass = build.base == .glass && abs(tip.x - (S.x - 40)) < 80 && tip.y < S.y - 20
        let want: CGFloat = overJarMouth || overGlass ? 1.35 : 0
        milkTilt += (want - milkTilt) * min(1, dt * 7)
        milkPour = milkTilt > 0.9 ? 1 : 0
        guard milkPour > 0 else {
            stream = held == .jar ? stream : []
            return
        }
        let spoutW = milkSpout()
        if overJarMouth {
            let room = 0.92 - jarVolume
            let dv = min(room, 0.2 * dt)
            if dv > 0 {
                jarVolume += dv
                jarPaint.add(IceSim.milk, Double(dv))
                sloshV += 0.6
            }
            streamTo(from: spoutW, v: CGVector(dx: 40, dy: 30), floorY: jarLevel(), color: IceSim.milk)
        } else if overGlass {
            addToGlass(IceSim.milk, 0.2 * dt * IceSim.jarArea / IceSim.glassArea * 0.5, fruit: nil)
            streamTo(from: spoutW, v: CGVector(dx: 40, dy: 30), floorY: S.y - glassLiquidH(), color: IceSim.milk)
        }
    }

    /// The milk jug's spout, for the jug tipped by `milkTilt` at `origin`.
    func milkSpout(at origin: CGPoint) -> CGPoint {
        let a = milkTilt
        let p = CGPoint(x: 30, y: -54)
        return CGPoint(x: origin.x + p.x * cos(a) - p.y * sin(a), y: origin.y + p.x * sin(a) + p.y * cos(a))
    }

    func milkSpout() -> CGPoint { milkSpout(at: tip) }

    func glassLiquidH() -> CGFloat {
        let b = ICBase.glass
        return b.floor + (-b.floor) * min(1, build.fill)
    }

    private func stepPour(_ dt: CGFloat) {
        guard (held == .jar || autoPour == .jar), jarVolume > 0.001 else {
            pourRate *= 0.8
            if held != .milk && autoPour != .milk { stream = [] }
            return
        }
        let poly = jarInside()
        let sp = spout()
        let capacity = IceSim.areaBelow(poly, sp.y)
        let have = jarVolume * IceSim.jarArea
        let excess = have - capacity
        guard excess > 0 else {
            pourRate *= 0.7
            stream = []
            return
        }
        // the more it's tipped past the brim, the faster it pours
        let out = min(excess, 5200 * dt * icClamp(excess / 2500 + 0.15), have)
        let frac = out / max(have, 1)
        jarVolume = max(0, jarVolume - out / IceSim.jarArea)
        pourRate = min(1, out / dt / 5200)
        // which fruit goes along, in proportion
        var fruitOut = [CGFloat](repeating: 0, count: jarFruit.count)
        for f in jarFruit.indices {
            fruitOut[f] = jarFruit[f] * frac
            jarFruit[f] -= fruitOut[f]
        }
        let color = smoothieColor
        let dir = CGVector(dx: cos(jarTilt) * 70, dy: sin(jarTilt) * 30 + 20)
        let landed = streamTo(from: sp, v: dir, floorY: nil, color: color)
        if landed {
            addToGlass(color, out / IceSim.glassArea, fruit: fruitOut)
            if Int(time * 30) % 2 == 0, let l = stream.last {
                parts.append(ICPart(kind: .splash, p: l, v: CGVector(dx: CGFloat.random(in: -80...80), dy: -CGFloat.random(in: 80...200)),
                                    life: 0.5, size: CGFloat.random(in: 2...4), color: color))
            }
        }
        if jarVolume < 0.002 {
            jarPaint = ICPaint()
            jarVolume = 0
        }
    }

    /// Traces a falling stream from `from`. Lands in the glass (true) or splashes onto the counter.
    @discardableResult
    func streamTo(from: CGPoint, v: CGVector, floorY: CGFloat?, color: ICColor) -> Bool {
        var pts: [CGPoint] = [from]
        var p = from
        var vv = v
        let g: CGFloat = 1400
        let dt: CGFloat = 1.0 / 90
        var inGlass = false
        let rimY = S.y
        let rim = (build.base?.rim ?? 0) - 4
        for _ in 0..<90 {
            vv.dy += g * dt
            let q = CGPoint(x: p.x + vv.dx * dt, y: p.y + vv.dy * dt)
            if let f = floorY, q.y >= f {
                pts.append(CGPoint(x: q.x, y: f))
                stream = pts
                streamColor = color
                return true
            }
            if floorY == nil && build.base == .glass && p.y < rimY && q.y >= rimY && abs(q.x - S.x) < rim {
                inGlass = true
            }
            if inGlass {
                let surface = S.y - glassLiquidH()
                if q.y >= surface {
                    pts.append(CGPoint(x: q.x, y: surface))
                    stream = pts
                    streamColor = color
                    return true
                }
            }
            if q.y >= ICGeo.counterY + 4 {
                pts.append(CGPoint(x: q.x, y: ICGeo.counterY + 4))
                stream = pts
                streamColor = color
                spills.append(ICSpill(x: q.x, w: 12, color: color))
                mergeSpills()
                return false
            }
            pts.append(q)
            p = q
        }
        stream = pts
        streamColor = color
        return false
    }

    /// Adds drink to the glass: a new band if its color is different (layers!), overflowing past the top.
    func addToGlass(_ color: ICColor, _ amount: CGFloat, fruit: [CGFloat]?) {
        guard build.base == .glass, amount > 0 else { return }
        var f = build.fill + amount
        if f > 1 {
            build.overflow += f - 1
            f = 1
            if Int(time * 10) % 3 == 0 {
                spills.append(ICSpill(x: S.x + CGFloat.random(in: -40...40), w: 14, color: color))
                mergeSpills()
            }
        }
        if let fr = fruit {
            for i in fr.indices where i < build.fruitIn.count { build.fruitIn[i] += fr[i] }
        }
        if let n = build.layers.indices.last, build.layers[n].color.distance(color) < 0.18 {
            let below = n > 0 ? build.layers[n - 1].top : 0
            let k = amount / max(0.01, f - below)
            build.layers[n].color = build.layers[n].color.mix(color, k)
            build.layers[n].top = f
        } else {
            build.layers.append(ICLayer(top: f, color: color))
            if build.layers.count > 7 {
                build.layers.remove(at: 0)
            }
        }
        profileDirty = true
    }
}
