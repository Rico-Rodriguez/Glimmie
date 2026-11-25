import SwiftUI

// MARK: - The shop, simulated
//
// One class steps everything at the display's rate (`step`), and the painter draws whatever it holds.
//
// - Scooping: the dipper digs into a tub while she drags it across; the ice cream curls up into a ball on the dipper
//   as it goes (more dragging, bigger ball) and leaves grooves in the tub. Let go over the treat and the ball drops,
//   lands with a squash and wobbles the scoops under it. Scoops left out a while start to melt: drips creep down.
// - Soft serve (IceCreamSoft.swift): holding a handle pushes a ridged rope out of the nozzle. It falls, sways, and
//   lays down in rings on a turning stand that sinks as the swirl grows, the rings narrowing into a curl on top.
// - Smoothies (IceCreamBlender.swift): fruit pieces and ice are real circles that tumble into the jar and pile up.
//   The motor whirls them in a vortex; the blades chop them smaller until they're gone into the color of the drink.
//   Then she carries the jar to the glass, it tips, and a stream pours in (or spills on the counter, it's a shop).
// - Bingsu: holding or tapping the snow shaver flurries fine milk-snow flakes into a footed pastel bowl, then sweet
//   red bean, golden mango cubes, ruby strawberries, nutty injeolmi mochi and condensed milk crown the dome.
// - Toppings: sprinkles fly out of a shaken shaker and stick where they land, sauce runs down the treat in drips,
//   whipped cream piles up in a rosette, a cherry drops, bounces and rolls into place.

enum ICGeo {
    static let counterY: CGFloat = 662
    static let standX: CGFloat = 600
    static let nozzle = CGPoint(x: 600, y: 304)
    static let dockY: CGFloat = 740
    /// The serving window.
    static let window = CGRect(x: 748, y: 150, width: 262, height: 372)
    static let serveBell = CGPoint(x: 774, y: 520)
    static let customer = CGPoint(x: 879, y: 372)
    static let customerScale: CGFloat = 0.62
    static let handOff = CGPoint(x: 868, y: 492)
    // Scoop cabinet: tub surface centers, back row then front row.
    static let tubs: [CGPoint] = [CGPoint(x: 112, y: 432), CGPoint(x: 240, y: 432), CGPoint(x: 368, y: 432),
                                  CGPoint(x: 112, y: 548), CGPoint(x: 240, y: 548), CGPoint(x: 368, y: 548)]
    static let tubRX: CGFloat = 56
    static let tubRY: CGFloat = 21
    static let well = CGPoint(x: 476, y: 598)
    // Soft serve: four big pull-down pastel lever handles across the machine front (vanilla, chocolate, twist, strawberry).
    static let softButtons: [CGPoint] = [CGPoint(x: 162, y: 232), CGPoint(x: 262, y: 232),
                                         CGPoint(x: 362, y: 232), CGPoint(x: 462, y: 232)]
    static let softButtonR: CGFloat = 48
    // Bingsu snow shaver.
    static let snowNozzle = CGPoint(x: 600, y: 310)
    static let snowButton = CGPoint(x: 454, y: 196)
    static let snowButtonR: CGFloat = 42
    static let snowChamber = CGRect(x: 536, y: 112, width: 128, height: 162)
    static let snowIceTray = CGRect(x: 48, y: 556, width: 280, height: 112)
    // Blender.
    static let jarHome = CGPoint(x: 154, y: 566)
    static let jarH: CGFloat = 270
    static let jarBottomHW: CGFloat = 56
    static let jarTopHW: CGFloat = 80
    static let blendButton = CGPoint(x: 154, y: 616)
    static let bins: [CGPoint] = [CGPoint(x: 298, y: 326), CGPoint(x: 392, y: 326), CGPoint(x: 486, y: 326),
                                  CGPoint(x: 298, y: 446), CGPoint(x: 392, y: 446), CGPoint(x: 486, y: 446)]
    static let milkHome = CGPoint(x: 444, y: 584)

    static func jarHW(_ y: CGFloat) -> CGFloat {
        // y is jar-local, 0 at the inside bottom and negative going up
        let k = icClamp(-y / jarH)
        return jarBottomHW + (jarTopHW - jarBottomHW) * k
    }
}

enum ICHeld: Equatable {
    case scoop
    case topping(ICTopping)
    case fruit(ICFruit)
    case milk
    case jar
}

enum ICAutoPour: Equatable {
    case milk, jar
}

enum ICPartKind {
    case sprinkle, sauce, splash, drop, ice, snow, sparkle, crumb, steam
}

struct ICPart {
    var kind: ICPartKind
    var p: CGPoint
    var v: CGVector
    var age: CGFloat = 0
    var life: CGFloat
    var size: CGFloat
    var color: ICColor
    var colorIndex = 0
    var rot: CGFloat = 0
    var spin: CGFloat = 0
    var resting = false
    var bounces = 0
    var topping: ICTopping?
}

struct ICTub {
    var flavor: ICFlavor
    var level: CGFloat = 1
    /// Grooves the dipper left, in tub-local points.
    var marks: [[CGPoint]] = []
    var dent: CGFloat = 0
}

/// Something sliding back to where it lives (a tool going home, a fruit to its bin).
struct ICReturn {
    var held: ICHeld
    var from: CGPoint
    var to: CGPoint
    var start: Double
    var tilt: CGFloat
    var dur: Double = 0.32
}

/// Fruit, ice and their chopped bits in the blender jar (jar-local: 0 at the inside bottom, y down).
struct ICChunk {
    var fruit: ICFruit
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var rot: CGFloat
    var spin: CGFloat
    var seed: Int
    /// Fell in past the rim (from then on the jar holds it).
    var inside = false
}

/// A spill on the counter that slowly dries.
struct ICSpill {
    var x: CGFloat
    var w: CGFloat
    var color: ICColor
    var age: CGFloat = 0
}

final class IceSim {
    static let gameID = "icecream"
    static let gravity: CGFloat = 1800

    var station: ICStation = .scoop
    var time: Double = 0
    private var last: Date?

    // The treat on the stand
    var build = ICBuild()
    var S = CGPoint(x: ICGeo.standX, y: 520)
    var standV = CGVector.zero
    /// The turntable's angle (soft serve).
    var spin: CGFloat = 0
    var baseDrop: (base: ICBase, start: Double)?
    var nextScoopID = 1
    var profileDirty = true

    // Scoop cabinet
    var tubs: [ICTub] = ICFlavor.allCases.map { ICTub(flavor: $0) }
    var ball: CGFloat = 0
    var ballFlavor: ICFlavor?
    var ballSwirl: ICFlavor?
    var scraping: CGFloat = 0
    var scoopIn: Int?
    /// When dragging straight from a tub, locks scooping to that exact tub so FingerLift never jumps rows.
    var scoopLockedTub: Int?
    private var lastScoopTip = CGPoint.zero

    // Held thing
    var held: ICHeld?
    var finger = CGPoint.zero
    var tip = CGPoint.zero
    var tipV = CGVector.zero
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var shake: CGFloat = 0
    var returning: [ICReturn] = []
    private var lastTip = CGPoint.zero
    private var emitAcc: CGFloat = 0

    // Soft serve (IceCreamSoft.swift)
    var lever: Int?
    var leverPull: [CGFloat] = [0, 0, 0, 0]
    var softBurstTime: CGFloat = 0
    var free: [ICFreeBead] = []
    var softAcc: CGFloat = 0
    var prevTurn = 0
    var rho: CGFloat = 30
    var softFull = false
    var softSpinV: CGFloat = 0
    var whipSession: ICWhipSession?

    // Bingsu snow shaver
    var shaving = false
    var shavePress: CGFloat = 0
    var snowBurstTime: CGFloat = 0
    var shaveBladeAngle: CGFloat = 0
    var bingsuSeed = 1
    private var snowAcc: CGFloat = 0

    // Blender (IceCreamBlender.swift)
    var chunks: [ICChunk] = []
    var jarP = ICGeo.jarHome
    var jarOnBase = true
    var jarTilt: CGFloat = 0
    var jarTiltV: CGFloat = 0
    var jarVolume: CGFloat = 0
    var jarPaint = ICPaint()
    var jarFruit: [CGFloat] = [CGFloat](repeating: 0, count: ICFruit.allCases.count)
    var blending = false
    var blendingToggle = false
    var blendAutoPour = false
    var blendToggleTime: CGFloat = 0
    var blendEmptyTime: CGFloat = 0
    var autoPour: ICAutoPour?
    var autoPourTime: CGFloat = 0
    var autoMilkPos = ICGeo.milkHome
    var motor: CGFloat = 0
    var slosh: CGFloat = 0
    var sloshV: CGFloat = 0
    var pourRate: CGFloat = 0
    var stream: [CGPoint] = []
    var streamColor = ICColor(0xFFFFFF)
    var milkPour: CGFloat = 0
    var milkTilt: CGFloat = 0
    var jarAim: CGFloat = 0
    var spills: [ICSpill] = []
    var chunkSeed = 1
    var bladeAngle: CGFloat = 0

    // What the customer at the window wants (marks the tubs, handles and bins with a heart)
    var order: ICOrder?

    // Particles
    var parts: [ICPart] = []
    var counterBits: [ICStuck] = []

    // Serving
    var served: (build: ICBuild, from: CGPoint, start: Double)?
    var bites = 0
    var sparkleAt: Double = -10

    /// Screenshot and test mode.
    var demo = false
    /// Screenshot hooks freeze the shop mid-action.
    var frozen = false

    init() {
        S.y = standTarget().y
    }

    // MARK: Frame

    func step(_ now: Date) {
        let raw = last.map { now.timeIntervalSince($0) } ?? 1.0 / 60
        last = now
        step(dt: CGFloat(min(max(raw, 0), 1.0 / 30)))
    }

    func step(dt: CGFloat) {
        guard dt > 0, !frozen else { return }
        time += Double(dt)
        stepStand(dt)
        stepHeld(dt)
        stepScoops(dt)
        stepSoft(dt)
        stepBingsu(dt)
        stepWhip(dt)
        stepBlender(dt)
        stepParticles(dt)
        stepSauce(dt)
        stepCherry(dt)
        if profileDirty {
            build.rebuildProfile()
            profileDirty = false
        }
        returning.removeAll { time - $0.start > $0.dur }
        stepSound()
    }

    // MARK: Stand

    func standTarget() -> CGPoint {
        let b = build.base ?? (station == .bingsu ? .bowl : .waffle)
        if station == .soft && b != .glass && b != .bowl {
            let topH = softTop()
            return CGPoint(x: ICGeo.nozzle.x - rho, y: ICGeo.nozzle.y + 46 + topH)
        }
        return CGPoint(x: ICGeo.standX, y: ICGeo.counterY - b.depth - 4)
    }

    private func stepStand(_ dt: CGFloat) {
        let t = standTarget()
        let k: CGFloat = 140, c: CGFloat = 22
        standV.dx += ((t.x - S.x) * k - standV.dx * c) * dt
        standV.dy += ((t.y - S.y) * k - standV.dy * c) * dt
        S.x += standV.dx * dt
        S.y += standV.dy * dt
    }

    func setStation(_ s: ICStation) {
        guard s != station, held == nil else { return }
        lever = nil
        softBurstTime = 0
        shaving = false
        snowBurstTime = 0
        blending = false
        blendingToggle = false
        blendAutoPour = false
        autoPour = nil
        autoPourTime = 0
        station = s
        if s == .smoothie && build.base == nil { placeBase(.glass) }
        if s == .bingsu && build.base == nil { placeBase(.bowl) }
    }

    /// Puts or swaps a cone, cup, glass or bowl on the stand. Swapping between parlor bases preserves existing scoops/swirls.
    func placeBase(_ b: ICBase) {
        guard build.base != b else { return }
        if let old = build.base, old.isParlorBase && b.isParlorBase {
            let deltaH: CGFloat
            if !build.scoops.isEmpty {
                let oldRest = restHeight(0)
                build.base = b
                let newRest = restHeight(0)
                deltaH = newRest - oldRest
                for i in build.scoops.indices where build.scoops[i].landed {
                    build.scoops[i].h += deltaH
                }
                build.scoops[0].squashV += 1.6
            } else if !build.rope.isEmpty {
                deltaH = b.floor - old.floor
                build.base = b
            } else {
                deltaH = 0
                build.base = b
                resetSoft()
            }
            if deltaH != 0 {
                for i in build.rope.indices { build.rope[i].h += deltaH }
                for i in build.whip.indices { build.whip[i].h += deltaH }
                if build.cherry != nil { build.cherry?.h += deltaH }
                if build.wafer != nil { build.wafer?.h += deltaH }
                if build.straw != nil { build.straw?.h += deltaH }
                for i in build.sprinkles.indices where build.sprinkles[i].onTop {
                    build.sprinkles[i].dy += deltaH
                }
            }
            standV.dy -= 220
            baseDrop = (b, time)
            profileDirty = true
            Sound.shared.play(.pop, volume: 0.7)
            IceSound.shared.play(.tub, volume: 0.55)
            return
        }
        build = ICBuild()
        build.base = b
        baseDrop = (b, time)
        profileDirty = true
        resetSoft()
        Sound.shared.play(.pop, volume: 0.65)
        IceSound.shared.play(b == .glass || b == .bowl ? .glass : .tub, volume: 0.7)
    }

    /// Clears the stand to start a new treat.
    func clearStand() {
        cancelInteraction()
        build = ICBuild()
        baseDrop = nil
        parts.removeAll()
        resetSoft()
        profileDirty = true
        if station == .smoothie {
            resetBlender()
            placeBase(.glass)
        } else if station == .bingsu {
            placeBase(.bowl)
        }
    }

    // MARK: Bingsu snow shaver

    var isShavingSnow: Bool {
        station == .bingsu && (shaving || snowBurstTime > 0) && build.base == .bowl && build.snowLevel < 1
    }

    func pressShaver(_ on: Bool) {
        if on {
            guard station == .bingsu else { return }
            if build.base != .bowl { placeBase(.bowl) }
            if build.snowLevel >= 1 {
                IceSound.shared.play(.plop, volume: 0.35)
                Sound.shared.tap()
                return
            }
            shaving = true
            IceSound.shared.play(.lever, volume: 0.55, rate: 1.2)
            Sound.shared.tap()
        } else {
            shaving = false
        }
    }

    /// Quick tap gives a playful burst of falling milk-snow (>= 0.50 snowLevel) so a single tap earns the base star.
    func tapShaver() {
        guard station == .bingsu else { return }
        if build.base != .bowl { placeBase(.bowl) }
        if build.snowLevel >= 1 {
            IceSound.shared.play(.plop, volume: 0.35)
            Sound.shared.tap()
            return
        }
        snowBurstTime = max(snowBurstTime, 1.0)
        Sound.shared.tap()
    }

    private func stepBingsu(_ dt: CGFloat) {
        let active = isShavingSnow
        let target: CGFloat = active ? 1 : 0
        shavePress += (target - shavePress) * min(1, dt * 16)
        if snowBurstTime > 0 { snowBurstTime = max(0, snowBurstTime - dt) }
        guard active else { snowAcc = 0; return }

        shaveBladeAngle += dt * 30
        let prev = build.snowLevel
        build.snowLevel = min(1, build.snowLevel + dt * 0.56)
        profileDirty = true

        // Lift any toppings already on the snow so they ride on top of the rising mountain.
        if !build.bingsuPieces.isEmpty {
            for i in build.bingsuPieces.indices {
                let dx = build.bingsuPieces[i].dx
                if let surf = ICBuild.snowHeight(at: dx, level: build.snowLevel) {
                    build.bingsuPieces[i].h = max(build.bingsuPieces[i].h, surf - 10)
                }
            }
        }

        snowAcc += 52 * dt
        while snowAcc >= 1 {
            snowAcc -= 1
            let spread = CGFloat.random(in: -22...22)
            let tone = CGFloat.random(in: 0...1)
            let col = ICColor(0xFFFFFF).mix(ICColor(0xE4F4FF), tone * 0.55)
            parts.append(ICPart(
                kind: .snow,
                p: CGPoint(x: ICGeo.snowNozzle.x + spread, y: ICGeo.snowNozzle.y + CGFloat.random(in: -2...8)),
                v: CGVector(dx: spread * 1.6, dy: CGFloat.random(in: 120...210)),
                life: 1.5,
                size: CGFloat.random(in: 4.5...8.5),
                color: col,
                rot: CGFloat.random(in: 0...6.3),
                spin: CGFloat.random(in: -4...4)
            ))
        }

        if prev < 1 && build.snowLevel >= 1 {
            shaving = false
            snowBurstTime = 0
            Sound.shared.play(.sparkle, volume: 0.6)
            Sound.shared.tap()
            sparkle()
        }
    }

    func dropBingsuPieces(_ t: ICTopping, at point: CGPoint?) {
        guard t.isBingsuChunk else { return }
        if build.base == nil { placeBase(.bowl) }
        if profileDirty {
            build.rebuildProfile()
            profileDirty = false
        }
        let maxDX: CGFloat = build.snowLevel > 0.15 ? max(24, ICBuild.snowRadius(level: build.snowLevel) - 10) : 42
        let centerDX = point.map { icClamp($0.x - S.x, -maxDX, maxDX) }

        let count: Int
        switch t {
        case .redBean: count = 1
        case .strawberries: count = 3
        case .mangoCubes, .injeolmi: count = 4
        default: count = 1
        }

        for k in 0..<count {
            bingsuSeed += 1
            let s = bingsuSeed
            let dx: CGFloat
            if let cx = centerDX {
                let jitter = (icRand(s, 3) - 0.5) * (t == .redBean ? 12 : 34)
                dx = icClamp(cx + jitter, -maxDX, maxDX)
            } else if t == .redBean {
                let existing = build.bingsuPieces.filter { $0.topping == .redBean }.count
                let spots: [CGFloat] = [0, -24, 24, -14, 14]
                dx = spots[existing % spots.count]
            } else {
                let u = (CGFloat(k) + 0.5) / CGFloat(count)
                let spread = (u - 0.5) * maxDX * 1.75 + (icRand(s, 5) - 0.5) * 14
                dx = icClamp(spread, -maxDX, maxDX)
            }
            let surf = build.top(dx) ?? 12
            let inset: CGFloat
            if t == .redBean {
                inset = 2
            } else if let pt = point {
                let wantedH = S.y - pt.y
                inset = icClamp(surf - wantedH, 4, max(8, surf * 0.45))
            } else {
                inset = 6 + icRand(s, 7) * max(8, surf * 0.36)
            }
            let h = max(8, surf - inset)
            let rot: CGFloat = t == .redBean ? 0 : (icRand(s, 9) - 0.5) * 0.85
            let scale: CGFloat = t == .redBean ? (abs(dx) < 8 ? 1.05 : 0.84) : (0.88 + icRand(s, 11) * 0.24)
            build.bingsuPieces.append(ICBingsuPiece(topping: t, dx: dx, h: h, rot: rot, scale: scale, seed: s))
            if build.bingsuPieces.count > 48 { build.bingsuPieces.removeFirst() }
        }
        IceSound.shared.play(.plop, volume: 0.65)
        Sound.shared.tap()
        sparkle()
    }

    // MARK: Picking up and carrying

    func pickUp(_ h: ICHeld, at p: CGPoint) {
        held = h
        finger = p
        tip = p
        lastTip = p
        tipV = .zero
        tilt = 0
        tiltV = 0
        emitAcc = 0
        if h == .jar {
            jarOnBase = false
            blending = false
            blendingToggle = false
            if autoPour == .jar { autoPour = nil }
        }
        if h == .milk, autoPour == .milk {
            autoPour = nil
            milkPour = 0
        }
        if h == .scoop {
            IceSound.shared.play(.drip, volume: 0.4)
            for k in 0..<5 {
                parts.append(ICPart(kind: .drop, p: CGPoint(x: ICGeo.well.x + CGFloat(k - 2) * 5, y: ICGeo.well.y - 10),
                                    v: CGVector(dx: CGFloat(k - 2) * 30, dy: -80), life: 0.8, size: 3, color: ICColor(0xBFE6FF)))
            }
        }
    }

    /// Moves what she's holding toward the lifted point.
    func carry(to p: CGPoint, finger f: CGPoint) {
        finger = f
        tip = p
    }

    func release() {
        guard let h = held else { return }
        held = nil
        switch h {
        case .scoop:
            releaseScoop()
            returning.append(ICReturn(held: .scoop, from: tip, to: ICGeo.well, start: time, tilt: 0))
        case .topping(let t):
            releaseTopping(t)
        case .fruit(let f):
            releaseFruit(f)
        case .milk:
            milkPour = 0
            returning.append(ICReturn(held: .milk, from: tip, to: ICGeo.milkHome, start: time, tilt: tilt))
        case .jar:
            releaseJar()
        }
        scoopIn = nil
        scraping = 0
    }

    func cancelInteraction() {
        if held == .jar || autoPour == .jar { releaseJar() }
        held = nil
        scoopLockedTub = nil
        scoopIn = nil
        scraping = 0
        ball = 0
        ballFlavor = nil
        ballSwirl = nil
        autoPour = nil
        autoPourTime = 0
        pressLever(nil)
        softBurstTime = 0
        shaving = false
        snowBurstTime = 0
        blending = false
        blendingToggle = false
        blendAutoPour = false
        milkPour = 0
        milkTilt = 0
        stream.removeAll()
        whipSession = nil
    }

    var dockHome: [ICTopping: CGPoint] = [:]

    private func stepHeld(_ dt: CGFloat) {
        guard let h = held else {
            shake *= 0.9
            return
        }
        let v = CGVector(dx: (tip.x - lastTip.x) / dt, dy: (tip.y - lastTip.y) / dt)
        let acc = hypot(v.dx - tipV.dx, v.dy - tipV.dy)
        tipV = v
        lastTip = tip
        shake = shake * 0.86 + min(1, acc / 9000) * 0.14 * 6
        // things lean a little the way they're carried, and swing back
        let lean = icClamp(-v.dx / 2400, -0.35, 0.35)
        tiltV += ((lean - tilt) * 160 - tiltV * 14) * dt
        tilt += tiltV * dt
        switch h {
        case .scoop: stepScooping(dt)
        case .topping(let t): stepTopping(t, dt)
        case .milk: stepMilk(dt)
        case .jar: stepJarHeld(dt)
        case .fruit: break
        }
    }

    // MARK: Scooping

    /// Picks up the dipper directly from a specific tub, locking scooping to that flavor so FingerLift never shifts rows.
    func pickUpScoop(fromTub index: Int, at p: CGPoint) {
        guard tubs.indices.contains(index) else { return }
        ball = 0
        ballFlavor = nil
        ballSwirl = nil
        scoopLockedTub = index
        pickUp(.scoop, at: p)
    }

    /// 1-tap any flavor tub to drop a full bouncy scoop of that exact flavor straight onto the cone/cup.
    func tapTub(_ index: Int) {
        guard station == .scoop, tubs.indices.contains(index) else { return }
        held = nil
        scoopLockedTub = nil
        scoopIn = nil
        scraping = 0
        ball = 0
        ballFlavor = nil
        ballSwirl = nil
        if build.base == nil { placeBase(.waffle) }
        let c = ICGeo.tubs[index]
        tubs[index].marks.append([CGPoint(x: -16, y: -4), CGPoint(x: 0, y: 2), CGPoint(x: 16, y: -2)])
        if tubs[index].marks.count > 9 { tubs[index].marks.removeFirst() }
        tubs[index].level = max(0.25, tubs[index].level - 0.03)
        returning.append(ICReturn(held: .scoop, from: c, to: ICGeo.well, start: time, tilt: 0))
        dropScoop(flavor: tubs[index].flavor, swirl: nil, size: 0.95, dx: 0, fromY: max(120, S.y - 220))
        IceSound.shared.play(.clink, volume: 0.45)
        Sound.shared.tap()
    }

    /// Which tub the dipper's bowl is in, if any.
    func tub(at p: CGPoint) -> Int? {
        guard station == .scoop else { return nil }
        for (i, c) in ICGeo.tubs.enumerated() {
            let lv = (1 - tubs[i].level) * 16
            let dx = (p.x - c.x) / (ICGeo.tubRX + 8)
            let dy = (p.y - (c.y + lv)) / (ICGeo.tubRY + 22)
            if dx * dx + dy * dy <= 1 { return i }
        }
        return nil
    }

    private func stepScooping(_ dt: CGFloat) {
        let activeTub: Int?
        if let locked = scoopLockedTub {
            let inCabinet = finger.x < 460 && finger.y > 360 && finger.y < 630 && abs(tip.x - S.x) > 135
            activeTub = inCabinet ? locked : nil
        } else {
            activeTub = tub(at: tip)
        }
        guard let i = activeTub else {
            scoopIn = nil
            scraping *= 0.8
            return
        }
        let c = ICGeo.tubs[i]
        let probe = scoopLockedTub != nil ? finger : tip
        let local = CGPoint(
            x: icClamp(probe.x - c.x, -ICGeo.tubRX + 8, ICGeo.tubRX - 8),
            y: icClamp(probe.y - c.y, -ICGeo.tubRY + 4, ICGeo.tubRY - 4)
        )
        let moved = hypot(tip.x - lastScoopTip.x, tip.y - lastScoopTip.y)
        if scoopIn != i {
            // just dipped in: the groove starts here
            scoopIn = i
            tubs[i].marks.append([local])
            if tubs[i].marks.count > 9 { tubs[i].marks.removeFirst() }
            IceSound.shared.play(.clink, volume: 0.35, gap: 0.2)
            lastScoopTip = tip
            return
        } else if var m = tubs[i].marks.last, let lp = m.last, hypot(local.x - lp.x, local.y - lp.y) > 3 {
            m.append(local)
            if m.count > 40 { m.removeFirst() }
            tubs[i].marks[tubs[i].marks.count - 1] = m
        }
        lastScoopTip = tip
        let speed = hypot(tipV.dx, tipV.dy)
        scraping = scraping * 0.8 + icClamp(speed / 700) * 0.2
        guard ball < 1 else { return }
        let got = min(1 - ball, moved / 60)
        if got > 0 {
            if ballFlavor == nil { ballFlavor = tubs[i].flavor }
            else if scoopLockedTub == nil && ballFlavor != tubs[i].flavor && ballSwirl == nil && got > 0.004 { ballSwirl = tubs[i].flavor }
            ball += got
            tubs[i].level = max(0.25, tubs[i].level - got * 0.035)
            if ball >= 1 {
                IceSound.shared.play(.clink, volume: 0.6)
                Sound.shared.tap()
            }
            if Int(time * 20) % 3 == 0, got > 0.002 {
                let col = tubs[i].flavor.color
                parts.append(ICPart(kind: .crumb, p: tip, v: CGVector(dx: CGFloat.random(in: -60...60), dy: -CGFloat.random(in: 40...120)),
                                    life: 0.5, size: CGFloat.random(in: 2...4), color: col))
            }
        }
    }

    /// The radius of the ball on the dipper.
    var ballRadius: CGFloat { 26 + 22 * sqrt(icClamp(ball)) }

    private func releaseScoop() {
        defer {
            ball = 0
            ballFlavor = nil
            ballSwirl = nil
            scoopLockedTub = nil
        }
        guard ball > 0.2, let f = ballFlavor else { return }
        // Over the stand: drop the scoop, auto-placing a waffle cone if the stand is empty
        let dx = tip.x - S.x
        if abs(dx) < 135, tip.y < S.y + 60 {
            if build.base == nil { placeBase(.waffle) }
            dropScoop(flavor: f, swirl: ballSwirl, size: ball, dx: dx, fromY: tip.y)
            return
        }
        IceSound.shared.play(.plop, volume: 0.35)
    }

    /// Drops a scoop from screen height `fromY` onto the treat.
    func dropScoop(flavor: ICFlavor, swirl: ICFlavor?, size: CGFloat, dx: CGFloat, fromY: CGFloat) {
        guard build.scoops.count < 4 else {
            IceSound.shared.play(.plop, volume: 0.4)
            return
        }
        let r = 30 + 18 * sqrt(icClamp(size))
        let below = build.scoops.last
        var x = dx
        if let b = below {
            let lim = b.r * 0.34
            x = b.dx + icClamp(dx - b.dx, -lim, lim)
        } else {
            x = icClamp(dx, -12, 12)
        }
        let s = ICScoop(id: nextScoopID, flavor: flavor, swirl: swirl, r: r, dx: x, h: S.y - fromY, vh: -120, landed: false)
        nextScoopID += 1
        build.scoops.append(s)
        profileDirty = true
    }

    /// The height a scoop's center comes to rest at.
    func restHeight(_ i: Int) -> CGFloat {
        let s = build.scoops[i]
        if i > 0 {
            let b = build.scoops[i - 1]
            return b.h + (b.r + s.r) * 0.7
        }
        let base = build.base ?? .waffle
        switch base {
        case .waffle, .choco:
            let a: CGFloat = 40
            return s.r > a ? sqrt(s.r * s.r - a * a) : s.r * 0.35
        case .cup, .bowl:
            return base.floor + s.r * 0.9 + 6
        case .glass:
            let liquid = base.floor + (-base.floor) * min(1, build.fill)
            return max(base.floor + s.r, liquid - s.r * 0.25)
        }
    }

    private func stepScoops(_ dt: CGFloat) {
        guard !build.scoops.isEmpty else { return }
        for i in build.scoops.indices {
            var s = build.scoops[i]
            let rest = restHeight(i)
            if !s.landed {
                s.vh -= IceSim.gravity * dt
                s.h += s.vh * dt
                if s.h <= rest {
                    let hit = -s.vh
                    s.h = rest
                    s.vh = 0
                    s.landed = true
                    s.squashV += min(3, hit / 600)
                    IceSound.shared.play(.plop, volume: Float(min(1, 0.35 + hit / 1600)))
                    Sound.shared.tap()
                    // the scoops below take the knock
                    var k: CGFloat = 1
                    for j in stride(from: i - 1, through: 0, by: -1) {
                        let side: CGFloat = (j % 2 == 0 ? 1 : -1) * (s.dx >= 0 ? 1 : -1)
                        build.scoops[j].wobV += side * k * min(70, hit / 18)
                        build.scoops[j].squashV += k * min(1.6, hit / 900)
                        k *= 0.7
                    }
                    for n in 0..<7 {
                        let a = CGFloat(n) / 7 * .pi + .pi
                        parts.append(ICPart(kind: .crumb, p: CGPoint(x: S.x + s.dx + cos(a) * s.r, y: S.y - s.h + s.r * 0.5),
                                            v: CGVector(dx: cos(a) * 120, dy: -60 - CGFloat(n % 3) * 30), life: 0.5,
                                            size: 3, color: s.flavor.color))
                    }
                }
                profileDirty = true
            } else {
                // stays seated on what's below as that settles
                if abs(s.h - rest) > 0.1 {
                    s.h += (rest - s.h) * min(1, dt * 20)
                    profileDirty = true
                }
            }
            // squash and wobble springs
            s.squashV += (-s.squash * 260 - s.squashV * 9) * dt
            s.squash += s.squashV * dt
            s.squash = icClamp(s.squash, -0.25, 0.3)
            s.wobV += (-s.wob * 120 - s.wobV * 5) * dt
            s.wob += s.wobV * dt
            if abs(s.squash) > 0.002 { profileDirty = true }
            // melting: slow drips from the lower edge
            if s.landed && !demo {
                s.age += dt
                if s.age > s.nextDrip && s.drips.count < 4 {
                    s.nextDrip = s.age + 6 + icRand(s.id, s.drips.count) * 6
                    let side: CGFloat = icRand(s.id, s.drips.count + 7) - 0.5
                    s.drips.append(ICDrip(dx: side * s.r * 1.3, max: 14 + icRand(s.id, s.drips.count + 3) * 26,
                                          w: 6 + icRand(s.id, s.drips.count + 5) * 5))
                }
                for d in s.drips.indices where s.drips[d].len < s.drips[d].max {
                    s.drips[d].len += dt * 3 * (1 - s.drips[d].len / s.drips[d].max + 0.1)
                }
            }
            build.scoops[i] = s
        }
    }

    // MARK: Toppings

    /// Where a topping held at the tip works (the shaker's holes, the bottle's nozzle).
    private func overTreat(_ p: CGPoint) -> Bool {
        build.base != nil && abs(p.x - S.x) < 120 && p.y < S.y + 20
    }

    private func stepTopping(_ t: ICTopping, _ dt: CGFloat) {
        switch t {
        case .sprinkles:
            guard tip.y < ICGeo.dockY - 60 else { return }
            // shaking throws more out; held still, a few still trickle
            let rate = 10 + shake * 110
            emitAcc += rate * dt
            while emitAcc >= 1 {
                emitAcc -= 1
                let ci = Int.random(in: 0..<6)
                let spread = CGFloat.random(in: -14...14)
                parts.append(ICPart(kind: .sprinkle, p: CGPoint(x: tip.x + spread, y: tip.y + 4),
                                    v: CGVector(dx: spread * 6 + tipV.dx * 0.25, dy: CGFloat.random(in: 60...220) + max(0, tipV.dy * 0.3)),
                                    life: 6, size: 1, color: ICPalette.candy[ci], colorIndex: ci,
                                    rot: CGFloat.random(in: 0...6.3), spin: CGFloat.random(in: -14...14)))
            }
            if shake > 0.15 { IceSound.shared.play(.shake, volume: Float(min(1, 0.3 + shake)), gap: 0.11) }
        case .chocoSauce, .berrySauce, .condensedMilk:
            guard overTreat(tip) else { return }
            emitAcc += 60 * dt
            while emitAcc >= 1 {
                emitAcc -= 1
                parts.append(ICPart(kind: .sauce, p: CGPoint(x: tip.x + CGFloat.random(in: -1.5...1.5), y: tip.y + 6),
                                    v: CGVector(dx: tipV.dx * 0.2, dy: 260), life: 3, size: 5.5,
                                    color: t.sauceColor ?? ICColor(0x5A2F1F), topping: t))
            }
        case .whip:
            stepWhipHeld(dt)
        default:
            break
        }
    }

    private func releaseTopping(_ t: ICTopping) {
        let home = dockHome[t] ?? CGPoint(x: 512, y: ICGeo.dockY)
        switch t {
        case .cherry:
            if overTreat(tip) {
                build.cherry = ICBody(dx: tip.x - S.x, h: S.y - tip.y, vx: tipV.dx * 0.2, vh: 0, resting: false)
                profileDirty = true
                return
            }
        case .wafer, .straw:
            if overTreat(tip) {
                let dx = icClamp(tip.x - S.x, -36, 36)
                if t == .straw && build.base == .glass {
                    build.straw = ICStick(dx: dx * 0.5 + 10, h: (build.base?.floor ?? 0) + 14, angle: 0.2 + dx / 300)
                    IceSound.shared.play(.glass, volume: 0.6)
                } else {
                    let h = (build.top(dx) ?? 0) - 18
                    let stick = ICStick(dx: dx, h: h, angle: icClamp(dx / 70, -0.5, 0.5) + 0.12)
                    if t == .wafer { build.wafer = stick } else { build.straw = stick }
                    IceSound.shared.play(.crunch, volume: 0.7)
                }
                Sound.shared.tap()
                sparkle()
                return
            }
        case .redBean, .mangoCubes, .strawberries, .injeolmi:
            if overTreat(tip) {
                dropBingsuPieces(t, at: tip)
                return
            }
        case .whip:
            whipSession = nil
        default:
            break
        }
        returning.append(ICReturn(held: .topping(t), from: tip, to: home, start: time, tilt: tilt))
    }

    private func stepCherry(_ dt: CGFloat) {
        guard var c = build.cherry, !c.resting || abs(c.wobV) > 0.01 || abs(c.wob) > 0.01 else { return }
        if !c.resting {
            c.vh -= IceSim.gravity * dt
            c.dx += c.vx * dt
            c.h += c.vh * dt
            c.dx = icClamp(c.dx, -120, 120)
            let ground = (build.supportForCherry(c.dx) ?? -400) + 11
            if c.h <= ground {
                c.h = ground
                if c.vh < -160 {
                    IceSound.shared.play(.boing, volume: Float(min(1, 0.3 - c.vh / 1500)))
                    c.vh = -c.vh * 0.36
                    c.wobV += c.vx >= 0 ? 6 : -6
                } else {
                    c.vh = 0
                    // roll down a steep slope, settle in a dip
                    let l = build.supportForCherry(c.dx - 4) ?? ground
                    let r = build.supportForCherry(c.dx + 4) ?? ground
                    let slope = (r - l) / 8
                    if abs(slope) > 0.35 {
                        c.vx -= slope * 900 * dt
                    }
                    c.vx *= 0.9
                    if abs(c.vx) < 6 && abs(slope) <= 0.35 {
                        c.resting = true
                        sparkle()
                    }
                }
            }
            if c.h < -300 { build.cherry = nil; profileDirty = true; return }
            profileDirty = true
        }
        c.wobV += (-c.wob * 90 - c.wobV * 4) * dt
        c.wob += c.wobV * dt
        build.cherry = c
    }

    private func stepSauce(_ dt: CGFloat) {
        guard !build.sauces.isEmpty else { return }
        for k in build.sauces.indices {
            var s = build.sauces[k]
            // spreads to its neighbors a little, then runs down under its own weight
            var a = s.amount
            for i in 1..<(ICBuild.columns - 1) where s.amount[i] > 0.05 {
                let give = s.amount[i] * 0.6 * dt
                a[i] -= give
                a[i - 1] += give * 0.5
                a[i + 1] += give * 0.5
            }
            for i in 0..<ICBuild.columns {
                if build.profile[i] < -500 { a[i] = 0; s.run[i] = 0; continue }
                let room = build.profile[i] - build.sauceFloor(ICBuild.colDX(i))
                let wobble = 0.55 + 0.9 * icRand(i / 3, 41 + k)
                if a[i] > 0.04 && s.run[i] < room {
                    s.run[i] = min(room, s.run[i] + dt * 26 * a[i] * wobble / (1 + s.run[i] / 40))
                }
            }
            s.amount = a
            build.sauces[k] = s
        }
    }

    private func addSauce(_ t: ICTopping, at dx: CGFloat) {
        var k = build.sauces.firstIndex { $0.topping == t }
        if k == nil {
            build.sauces.append(ICSauce(topping: t, amount: [CGFloat](repeating: 0, count: ICBuild.columns),
                                        run: [CGFloat](repeating: 0, count: ICBuild.columns)))
            k = build.sauces.count - 1
        }
        guard let j = k else { return }
        let c = ICBuild.col(dx)
        for i in max(0, c - 3)...min(ICBuild.columns - 1, c + 3) {
            let w: CGFloat = 0.06 * (1 - CGFloat(abs(i - c)) / 4)
            build.sauces[j].amount[i] = min(2.2, build.sauces[j].amount[i] + w)
        }
    }

    func sparkle() { sparkleAt = time }

    func wanted(flavor f: ICFlavor) -> Bool {
        guard let o = order, o.kind == .scoops else { return false }
        return o.flavors.contains(f.rawValue)
    }

    func wanted(soft f: ICSoft) -> Bool {
        guard let o = order, o.kind == .soft else { return false }
        return o.flavors.first == f.rawValue
    }

    func wanted(fruit f: ICFruit) -> Bool {
        guard let o = order, o.kind == .smoothie else { return false }
        return o.flavors.contains(f.rawValue)
    }

    func wanted(bingsu t: ICTopping) -> Bool {
        guard let o = order, o.kind == .bingsu else { return false }
        if o.topping == t { return true }
        if let raw = o.flavors.first, let hero = ICBingsuHero(rawValue: raw), hero.topping == t { return true }
        return false
    }

    // MARK: Particles

    private func stepParticles(_ dt: CGFloat) {
        guard !parts.isEmpty else { return }
        var keep: [ICPart] = []
        keep.reserveCapacity(parts.count)
        for var q in parts {
            q.age += dt
            if q.age > q.life { continue }
            if q.resting { keep.append(q); continue }
            let gScale: CGFloat = q.kind == .steam ? -0.05 : (q.kind == .snow ? 0.16 : 1)
            q.v.dy += IceSim.gravity * gScale * dt
            if q.kind == .snow {
                q.v.dx += sin(CGFloat(time) * 7 + q.rot) * 90 * dt
                q.v.dx *= (1 - 2.2 * dt)
            } else if q.kind == .crumb || q.kind == .splash || q.kind == .drop {
                q.v.dx *= (1 - 1.5 * dt)
            }
            q.p.x += q.v.dx * dt
            q.p.y += q.v.dy * dt
            q.rot += q.spin * dt
            switch q.kind {
            case .snow:
                let dx = q.p.x - S.x
                if let t = build.top(dx), q.p.y >= S.y - t + 4 { continue }
                if q.p.y >= ICGeo.counterY + 6 { continue }
            case .sprinkle:
                let dx = q.p.x - S.x
                if let t = build.top(dx), q.p.y >= S.y - t - 1, q.v.dy > 0 {
                    // sticks where it lands on the treat
                    build.sprinkles.append(ICStuck(dx: dx, dy: S.y - q.p.y + CGFloat.random(in: -2...3), rot: q.rot,
                                                   color: q.colorIndex, onTop: true))
                    if build.sprinkles.count > 420 { build.sprinkles.removeFirst() }
                    IceSound.shared.play(.drip, volume: 0.12, gap: 0.05, rate: 1.8)
                    continue
                }
                if q.p.y >= ICGeo.counterY + 6 {
                    if q.bounces < 1 {
                        q.p.y = ICGeo.counterY + 6
                        q.v.dy = -q.v.dy * 0.3
                        q.v.dx *= 0.5
                        q.bounces += 1
                    } else {
                        counterBits.append(ICStuck(dx: q.p.x, dy: ICGeo.counterY + 6 + CGFloat.random(in: 0...14), rot: q.rot,
                                                   color: q.colorIndex, onTop: false))
                        if counterBits.count > 160 { counterBits.removeFirst() }
                        continue
                    }
                }
            case .sauce:
                let dx = q.p.x - S.x
                if let t = build.top(dx), q.p.y >= S.y - t - 2 {
                    if let tp = q.topping { addSauce(tp, at: dx) }
                    continue
                }
                if q.p.y > ICGeo.counterY + 4 {
                    spills.append(ICSpill(x: q.p.x, w: 10, color: q.color))
                    mergeSpills()
                    continue
                }
            default:
                if q.p.y > ICGeo.counterY + 14 && q.kind != .steam { continue }
            }
            keep.append(q)
        }
        parts = keep
    }

    func mergeSpills() {
        guard spills.count > 1 else { return }
        var out: [ICSpill] = []
        for s in spills.sorted(by: { $0.x < $1.x }) {
            if var l = out.last, abs(l.x - s.x) < (l.w + s.w) * 0.5 {
                let w = min(150, l.w + s.w * 0.35)
                l.color = l.color.mix(s.color, 0.2)
                l.x = (l.x * l.w + s.x * s.w * 0.35) / (l.w + s.w * 0.35)
                l.w = w
                l.age = min(l.age, s.age)
                out[out.count - 1] = l
            } else {
                out.append(s)
            }
        }
        spills = Array(out.suffix(10))
    }

    // MARK: Serving

    var canServe: Bool {
        build.hasTreat && held == nil && !blending && autoPour == nil
    }

    /// Hands the treat to the customer; it slides off the stand.
    func serve() -> ICBuild? {
        guard canServe else { return nil }
        softBurstTime = 0
        lever = nil
        snowBurstTime = 0
        shaving = false
        blendAutoPour = false
        let b = build
        served = (b, S, time)
        bites = 0
        parts.removeAll()
        baseDrop = nil
        build = ICBuild()
        resetSoft()
        profileDirty = true
        if station == .smoothie {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self, self.build.base == nil, self.station == .smoothie else { return }
                self.placeBase(.glass)
            }
        } else if station == .bingsu {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self, self.build.base == nil, self.station == .bingsu else { return }
                self.placeBase(.bowl)
            }
        }
        return b
    }

    /// Where the served treat is now (it slides to the customer's paws).
    func servedPoint() -> CGPoint? {
        guard let s = served else { return nil }
        let t = icEase(CGFloat((time - s.start) / 0.6))
        let x = s.from.x + (ICGeo.handOff.x - s.from.x) * t
        let lift = sin(t * .pi) * 60
        let toY = ICGeo.handOff.y - (s.build.base?.depth ?? 100) * 0.2
        let y = s.from.y + (toY - s.from.y) * t - lift
        return CGPoint(x: x, y: y)
    }

    // MARK: Sound

    private func stepSound() {
        let snd = IceSound.shared
        let scoopVol: Float = held == .scoop && scoopIn != nil ? Float(0.15 + scraping * 0.7) : 0
        let shaveVol: Float = isShavingSnow ? 0.52 : 0
        snd.setLoop(
            .scrape,
            volume: max(scoopVol, shaveVol),
            rate: shaveVol > scoopVol ? 1.55 : Float(0.8 + scraping * 0.5)
        )
        snd.setLoop(.soft, volume: lever != nil && !softFull && build.base != nil ? 0.7 : 0)
        snd.setLoop(.blend, volume: Float(min(1, motor * 1.2)) * 0.8, rate: Float(0.55 + motor * 0.35 + (1 - chunkLoad()) * motor * 0.3))
        snd.setLoop(.pour, volume: Float(min(1, pourRate * 1.4 + milkPour)) * 0.8)
        var sauce: Float = 0
        if case .topping(let t)? = held, t.sauceColor != nil, overTreat(tip) { sauce = 0.7 }
        snd.setLoop(.sauce, volume: sauce)
        var whip: Float = 0
        if case .topping(.whip)? = held, whipSession?.running == true { whip = 0.75 }
        snd.setLoop(.whip, volume: whip)
    }
}

enum ICPalette {
    static let candy: [ICColor] = [ICColor(0xFF6FA8), ICColor(0xFFD84A), ICColor(0x6CCBF2), ICColor(0x7EDB8C),
                                   ICColor(0xB48CFF), ICColor(0xFFFFFF)]
}
