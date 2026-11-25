import SwiftUI

// MARK: - Simulation Entities

struct PDrop {
    var p: CGPoint
    var v: CGVector
    var color: RGB
    var r: CGFloat
    var isDrain: Bool = false
}

struct PBubble {
    var p: CGPoint
    var r: CGFloat
    var phase: CGFloat
    var fizzy: Bool
}

struct PGlitter {
    var p: CGPoint
    var color: RGB
    var size: CGFloat
    var phase: CGFloat
}

enum PPieceState { case air, liquid }

struct PPiece {
    var kind: PIngredient
    var p: CGPoint
    var v: CGVector
    var ang: CGFloat
    var spin: CGFloat
    var state: PPieceState = .air
    var dissolve: CGFloat = 0
    var age: CGFloat = 0
    var seed: Int
    var trail: [CGPoint] = []
}

enum PMoteKind {
    case steam, fog, sparkle, fireHeart, heart, snow, soap, zz, flash, drip, confetti, starOrbit
}

struct PMote {
    var p: CGPoint
    var v: CGVector
    var life: CGFloat = 0
    var max: CGFloat
    var kind: PMoteKind
    var color: RGB
    var size: CGFloat
    var spin: CGFloat = 0
}

/// Animated ingredient vessel arcing over the cauldron mouth and pouring in.
struct PourArc {
    var kind: PIngredient
    var from: CGPoint
    var t: CGFloat = 0
    var duration: CGFloat = 0.72
    var pouredVisual: Bool = false
}

/// Animated corked potion bottle arcing from cauldron to Tasting Stand (or stand to creature).
struct PFlyer {
    var from: CGPoint
    var to: CGPoint
    var t: CGFloat = 0
    var bottle: PotionBottle
    var standIndex: Int?
    var spin: CGFloat
    var pouringOnCreature: Bool = false
}

struct CreatureState {
    var activeEffect: TransformationEffect? = nil
    var effectTimer: CGFloat = 0
    var tint = RGB(1, 1, 1)
    var tintAmt: CGFloat = 0
    var floatY: CGFloat = 0
    var floatV: CGFloat = 0
    var hop: CGFloat = 0
    var hopV: CGFloat = 0
    var shake: CGFloat = 0
    var hiccupAt: CGFloat = 0
    var hiccupKick: CGFloat = 0
    var giggle: CGFloat = 0
    var blink: CGFloat = 2.6
    var look = PotionGeometry.cauldronCenter
}

// MARK: - Potion Lab Simulation

final class PotionSim: ObservableObject {
    static let gameID = "potionlab"
    static let NX = PotionGeometry.NX
    static let NY = PotionGeometry.NY

    /// Published discrete state for declarative SwiftUI controls (never mutated per-frame).
    @Published var moonlit: Bool = false
    @Published var burner: BurnerLevel = .off
    @Published var creature: LabCreature = .unicorn
    @Published var ingredients: [PIngredient: Int] = [:]
    @Published var stand: [PotionBottle] = []
    @Published var rare: PotionKind? = nil
    @Published var draining: Bool = false
    @Published var hasActiveEffect: Bool = false

    /// Disables disk writes to `potionlab.json` during tests and screenshot demos.
    var demo = false
    /// Controls StickerBook / Coins reward dispatch (disabled only during screenshot setup).
    var trackRewards = true

    var time: Double = 0
    private var lastDate: Date?
    private var rng = SeededRandom(Int.random(in: 0..<1_000_000))

    // MARK: 2D Fluid Grid
    let solid: [Bool]
    var liquid: [Bool]
    var u: [Float]
    var v: [Float]
    var dr: [Float]
    var dg: [Float]
    var db: [Float]
    var da: [Float]
    private var t0: [Float]
    private var t1: [Float]
    private var t2: [Float]
    private var t3: [Float]
    private var pr: [Float]
    private var dv: [Float]
    private var curl: [Float]
    var version: Int = 0

    var volume: CGFloat
    var level: CGFloat
    var waveH = [CGFloat](repeating: 0, count: PotionGeometry.NX)
    var waveV = [CGFloat](repeating: 0, count: PotionGeometry.NX)
    var swirl: CGFloat = 0

    // MARK: Thermal & Lighting
    var temp: CGFloat = 0.22
    var night: CGFloat = 0
    var boiling: CGFloat { burner == .boil ? max(0.45, min(1, (temp - 0.5) / 0.45)) : max(0, min(1, (temp - 0.65) / 0.3)) }
    var basinFill: CGFloat = 0
    var basinColor = PotionColor.clearWater
    private var refilling = false

    /// Lever is perpendicular (`0`) to the horizontal drain pipe when shut, and inline (`pi/2`) when open.
    var valveAngle: CGFloat { draining ? .pi / 2 : 0 }

    // MARK: Stirring Paddle
    static let spoonRest = CGPoint(x: 492, y: 520)
    var spoon = PotionSim.spoonRest
    var spoonVel = CGVector.zero
    var spoonHeld = false
    var spoonTarget = PotionSim.spoonRest
    var stirSpeed: CGFloat = 0
    private var stirChimeAccum: CGFloat = 0
    private var stirNoteIndex = 0

    // MARK: Mixing & Discovery
    var mixProgress: CGFloat = 1
    var discoveredInBrew: Set<PotionKind> = []
    var turn: CGFloat = 0
    var flash: CGFloat = 0
    var nextID: Int = 1
    var made: Int = 0

    // MARK: Live Drag Visuals
    var draggedIngredient: (kind: PIngredient, pos: CGPoint)? = nil
    var draggedStandBottle: (index: Int, pos: CGPoint, tilt: CGFloat)? = nil

    // MARK: Particles & Creature
    var drops: [PDrop] = []
    var bubbles: [PBubble] = []
    var glitter: [PGlitter] = []
    var pieces: [PPiece] = []
    var motes: [PMote] = []
    var pourArcs: [PourArc] = []
    var flyers: [PFlyer] = []
    var creatureState = CreatureState()

    // MARK: Sound Cues
    var cues: [PotionSFX] = []
    var harpNotes: [SFX] = []
    private var cueAt: [PotionSFX: Double] = [:]

    var canBottle: Bool { !ingredients.isEmpty && !draining }

    var hiddenStandIndices: Set<Int> {
        var s = Set<Int>()
        if let drag = draggedStandBottle { s.insert(drag.index) }
        for f in flyers where !f.pouringOnCreature {
            if let i = f.standIndex { s.insert(i) }
        }
        return s
    }

    // MARK: - Init & Persistence

    init(save: PotionSave? = GameStorage.load(PotionSave.self, game: PotionSim.gameID, file: "potionlab.json")) {
        let n = PotionSim.NX * PotionSim.NY
        var s = [Bool](repeating: true, count: n)
        for j in 0..<PotionSim.NY {
            for i in 0..<PotionSim.NX where PotionGeometry.inside(PotionGeometry.cellCenter(i, j), pad: 1) {
                s[j * PotionSim.NX + i] = false
            }
        }
        solid = s
        liquid = [Bool](repeating: false, count: n)
        let z = [Float](repeating: 0, count: n)
        u = z; v = z; dr = z; dg = z; db = z; da = z
        t0 = z; t1 = z; t2 = z; t3 = z; pr = z; dv = z; curl = z
        volume = PotionGeometry.baseVolume
        level = PotionGeometry.level(for: volume)

        if let sv = save {
            stand = Array(sv.bottles.suffix(PotionGeometry.standCapacity))
            nextID = max(1, sv.nextID)
            made = max(0, sv.made)
            moonlit = sv.moonlit ?? !sv.lightsOn
            night = moonlit ? 1 : 0
            burner = BurnerLevel.clamped(sv.heat)
            temp = burner.targetTemp
            creature = LabCreature(rawValue: sv.creature) ?? .unicorn

            var restored: [PIngredient: Int] = [:]
            if !sv.ingredients.isEmpty {
                for (k, count) in sv.ingredients where count > 0 {
                    if let ing = PIngredient.fromLegacyKey(k) {
                        restored[ing, default: 0] += count
                    }
                }
            } else if !sv.doses.isEmpty {
                for (k, d) in sv.doses where d > 0.25 {
                    if let ing = PIngredient.fromLegacyKey(k) {
                        restored[ing, default: 0] += max(1, Int(d.rounded()))
                    }
                }
            }
            ingredients = restored

            let savedVol = CGFloat(sv.volume)
            volume = savedVol > 500 ? min(PotionGeometry.capacity * 0.9, savedVol) : PotionGeometry.baseVolume
            level = PotionGeometry.level(for: volume)

            if sv.pa > 0.01 {
                for k in 0..<n where !solid[k] {
                    dr[k] = Float(sv.pr)
                    dg[k] = Float(sv.pg)
                    db[k] = Float(sv.pb)
                    da[k] = Float(sv.pa)
                }
            } else if !restored.isEmpty {
                let mix = PotionSim.blendedColor(for: restored)
                for k in 0..<n where !solid[k] {
                    dr[k] = Float(mix.r) * 0.85
                    dg[k] = Float(mix.g) * 0.85
                    db[k] = Float(mix.b) * 0.85
                    da[k] = 0.85
                }
            }

            if let matched = PotionKind.match(ingredients: ingredients, heat: burner, moonlit: moonlit) {
                rare = matched
                discoveredInBrew.insert(matched)
                turn = 1
            }
        }
        updateLiquid()
    }

    func makeSave() -> PotionSave {
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, sumA = 0.0
        var cnt = 0
        for k in liquid.indices where liquid[k] {
            sumR += Double(dr[k])
            sumG += Double(dg[k])
            sumB += Double(db[k])
            sumA += Double(da[k])
            cnt += 1
        }
        let c = Double(max(1, cnt))
        var ingMap: [String: Int] = [:]
        var legacyDoses: [String: Double] = [:]
        for (k, count) in ingredients where count > 0 {
            ingMap[k.rawValue] = count
            legacyDoses[k.rawValue] = Double(count)
        }
        return PotionSave(
            bottles: stand,
            nextID: nextID,
            volume: Double(volume),
            pr: sumR / c,
            pg: sumG / c,
            pb: sumB / c,
            pa: sumA / c,
            doses: legacyDoses,
            lightsOn: !moonlit,
            heat: burner.rawValue,
            made: made,
            ingredients: ingMap,
            creature: creature.rawValue,
            moonlit: moonlit
        )
    }

    func save() {
        guard !demo else { return }
        GameStorage.save(makeSave(), game: PotionSim.gameID, file: "potionlab.json")
    }

    // MARK: - Player Actions

    /// One-motion guaranteed integer scoop add (from tap OR drag).
    func addIngredient(_ kind: PIngredient, from origin: CGPoint? = nil) {
        if draining {
            draining = false
            refilling = false
        }
        if volume < PotionGeometry.baseVolume {
            volume = PotionGeometry.baseVolume
            updateLiquid()
        }
        ingredients[kind, default: 0] += 1
        volume = min(PotionGeometry.capacity * 0.86, volume + 3600)
        updateLiquid()

        let start = origin ?? PotionGeometry.dockSlotCenter(kind.dockIndex)
        pourArcs.append(PourArc(kind: kind, from: start))

        // Inject vibrant pigment immediately so mixing & color stay responsive and deterministic.
        let hitX = PotionGeometry.cauldronCenter.x + rand(-28, 28)
        let hitY = max(level + 14, PotionGeometry.joinY + 12)
        let hit = CGPoint(x: hitX, y: hitY)
        inject(hit, color: kind.color, amount: 34, radius: 5.5)
        push(hit, CGVector(dx: rand(-70, 70), dy: 210), radius: 42)
        let col = Int((hitX - PotionGeometry.gx0) / PotionGeometry.cell)
        if col >= 0 && col < PotionSim.NX { waveV[col] += 2.2 }

        spawnIngredientEffects(kind, at: hit)
        cue(kind.isLiquid ? .glug : .shake, gap: 0.08)
        cue(.splash, gap: 0.14)

        mixProgress = min(mixProgress, 0.35)
        version += 1
        save()
    }

    private func spawnIngredientEffects(_ kind: PIngredient, at hit: CGPoint) {
        for _ in 0..<4 {
            let startP = CGPoint(x: PotionGeometry.cauldronCenter.x + rand(-24, 24), y: PotionGeometry.rimY - rand(10, 42))
            pieces.append(PPiece(
                kind: kind,
                p: startP,
                v: CGVector(dx: rand(-30, 30), dy: rand(90, 170)),
                ang: rand(0, 6.28),
                spin: rand(-4, 4),
                seed: Int(rand() * 1000)
            ))
        }
        if pieces.count > 48 { pieces.removeFirst(pieces.count - 48) }

        switch kind {
        case .starGlitter:
            for _ in 0..<18 {
                addGlitter(at: CGPoint(x: hit.x + rand(-40, 40), y: hit.y + rand(0, 50)), color: RGB(hex: "#FFE37A"), size: rand(1.6, 3.0))
            }
            cue(.fizz, gap: 0.25)
        case .rainbowMane:
            for k in 0..<14 {
                addGlitter(at: CGPoint(x: hit.x + rand(-45, 45), y: hit.y + rand(0, 60)), color: PotionColor.hue(CGFloat(k) / 14), size: rand(1.6, 2.8))
            }
        case .bubbleBerry, .mermaidWave:
            for _ in 0..<12 {
                bubbles.append(PBubble(p: CGPoint(x: hit.x + rand(-36, 36), y: hit.y + rand(8, 56)), r: rand(2.5, 6.0), phase: rand(0, 6), fizzy: true))
            }
            cue(.bloop, gap: 0.2)
        case .frostFlake:
            temp = max(0.1, temp - 0.18)
            for _ in 0..<5 {
                motes.append(PMote(
                    p: CGPoint(x: PotionGeometry.cauldronCenter.x + rand(-45, 45), y: PotionGeometry.rimY - 6),
                    v: CGVector(dx: rand(-22, 22), dy: rand(-20, -4)),
                    max: rand(2.2, 3.4),
                    kind: .fog,
                    color: RGB(0.9, 0.98, 1),
                    size: rand(16, 26)
                ))
            }
            cue(.frost, gap: 0.25)
        case .dragonChili:
            temp = min(1.0, temp + 0.14)
            sparkleBurst(at: CGPoint(x: hit.x, y: PotionGeometry.rimY - 12), color: RGB(hex: "#FF8642"), n: 8)
        case .sleepyLavender:
            for _ in 0..<3 {
                motes.append(PMote(
                    p: CGPoint(x: PotionGeometry.cauldronCenter.x + rand(-36, 36), y: PotionGeometry.rimY - 14),
                    v: CGVector(dx: rand(-10, 10), dy: -32),
                    max: 2.2,
                    kind: .zz,
                    color: RGB(hex: "#C4ACFF"),
                    size: 14,
                    spin: rand(0, 6)
                ))
            }
        case .fairyRose:
            for _ in 0..<4 {
                motes.append(PMote(
                    p: CGPoint(x: PotionGeometry.cauldronCenter.x + rand(-40, 40), y: PotionGeometry.rimY - 12),
                    v: CGVector(dx: rand(-18, 18), dy: rand(-55, -35)),
                    max: 1.8,
                    kind: .heart,
                    color: RGB(hex: "#FF72B4"),
                    size: rand(10, 15),
                    spin: rand(0, 6)
                ))
            }
        }
    }

    // MARK: Direct Finger Stirring

    func beginStir(at p: CGPoint) {
        spoonHeld = true
        spoonTarget = clampToCauldron(p)
        stirChimeAccum = 0
        cue(.tap, gap: 0.15)
        // Even a tap in the cauldron gives a lively little swirl & mixes.
        let clamped = spoonTarget
        push(clamped, CGVector(dx: rand(-120, 120), dy: rand(-60, 60)), radius: 46)
        if !ingredients.isEmpty {
            mixProgress = 1
            evaluateRecipe()
        }
    }

    func moveStir(to p: CGPoint) {
        if !spoonHeld { beginStir(at: p) }
        let clamped = clampToCauldron(p)
        let dist = hypot(clamped.x - spoonTarget.x, clamped.y - spoonTarget.y)
        spoonTarget = clamped
        stirChimeAccum += dist
        if stirChimeAccum > 78 {
            stirChimeAccum = 0
            let scale: [SFX] = [.note1, .note2, .note3, .note4]
            harpNotes.append(scale[stirNoteIndex % scale.count])
            stirNoteIndex += 1
        }
        if !ingredients.isEmpty {
            mixProgress = min(1, mixProgress + dist * 0.012 + 0.15)
            if mixProgress >= 1 { evaluateRecipe() }
        }
    }

    func endStir() {
        spoonHeld = false
    }

    private func clampToCauldron(_ p: CGPoint) -> CGPoint {
        var t = p
        t.y = max(PotionGeometry.rimY + 18, min(PotionGeometry.bottomY - 18, t.y))
        if PotionGeometry.inside(t, pad: 14) { return t }
        let c = CGPoint(x: PotionGeometry.cauldronCenter.x, y: max(PotionGeometry.rimY + 26, min(PotionGeometry.cauldronCenter.y, t.y)))
        for _ in 0..<24 {
            t = CGPoint(x: t.x + (c.x - t.x) * 0.16, y: t.y + (c.y - t.y) * 0.16)
            if PotionGeometry.inside(t, pad: 14) { break }
        }
        return t
    }

    // MARK: Burner & Moonlight & Drain

    func setBurner(_ level: BurnerLevel) {
        burner = level
        cue(.knob)
        if level != .off { cue(.whoosh, gap: 0.25) }
        if level == .boil {
            temp = max(temp, 0.82)
            if mixProgress >= 1 || !ingredients.isEmpty {
                mixProgress = 1
                evaluateRecipe()
            }
        }
        save()
    }

    func cycleBurner() {
        setBurner(burner.next)
    }

    func setMoonlit(_ on: Bool) {
        moonlit = on
        cue(.click)
        if on && !ingredients.isEmpty {
            mixProgress = 1
            evaluateRecipe()
        }
        save()
    }

    func toggleMoonlit() {
        setMoonlit(!moonlit)
    }

    func toggleDrain() {
        if draining {
            draining = false
            cue(.click)
            return
        }
        draining = true
        refilling = false
        cue(.click)
        cue(.gurgle, gap: 0.1)
    }

    // MARK: Discovery & Bottling

    @discardableResult
    func evaluateRecipe() -> PotionKind? {
        let matched = PotionKind.match(ingredients: ingredients, heat: burner, moonlit: moonlit)
        if matched != rare {
            rare = matched
            turn = 0
        }
        guard let kind = matched else { return nil }
        guard !discoveredInBrew.contains(kind) else { return kind }

        discoveredInBrew.insert(kind)
        flash = 1.0
        turn = 0
        cue(.magic, gap: 0.05)
        motes.append(PMote(
            p: CGPoint(x: PotionGeometry.cauldronCenter.x, y: PotionGeometry.cauldronCenter.y - 16),
            v: .zero,
            max: 0.65,
            kind: .flash,
            color: kind.color.mix(RGB(1, 1, 1), 0.45),
            size: 36
        ))
        sparkleBurst(at: CGPoint(x: PotionGeometry.cauldronCenter.x, y: PotionGeometry.rimY - 12), color: kind.color, n: 20)

        if trackRewards {
            StickerBook.shared.find(game: PotionSim.gameID, id: kind.rawValue)
            Coins.shared.earn(4, game: PotionSim.gameID, from: PotionGeometry.cauldronCenter)
        }
        bottleCurrentBrew(forcedKind: kind)
        return kind
    }

    @discardableResult
    func bottleCurrentBrew(forcedKind: PotionKind? = nil) -> PotionBottle? {
        let kind = forcedKind ?? rare
        guard kind != nil || !ingredients.isEmpty else { return nil }

        let bottle = makeBottleFromCurrentBrew(forcedKind: kind)
        if stand.count >= PotionGeometry.standCapacity {
            stand.removeFirst()
        }
        stand.append(bottle)
        let slotIndex = stand.count - 1
        let target = PotionGeometry.standSlots[min(slotIndex, PotionGeometry.standSlots.count - 1)]
        flyers.append(PFlyer(
            from: CGPoint(x: PotionGeometry.cauldronCenter.x + 30, y: PotionGeometry.rimY - 10),
            to: target,
            bottle: bottle,
            standIndex: slotIndex,
            spin: 0.35
        ))
        cue(.cork, gap: 0.05)
        if kind == nil { cue(.chime, gap: 0.1) }
        sparkleBurst(at: target, color: bottle.color, n: kind == nil ? 10 : 16)
        save()
        return bottle
    }

    private func makeBottleFromCurrentBrew(forcedKind: PotionKind?) -> PotionBottle {
        var mag: [String: Double] = [:]
        var total = 0
        for (ing, count) in ingredients where count > 0 {
            total += count
            mag[ing.magic.rawValue, default: 0] += Double(count)
        }
        if total > 0 {
            for (k, v) in mag { mag[k] = min(1, v / Double(total) * 1.4) }
        }

        let color: RGB
        let shape: PBottleShape
        let glow: Double
        let sparkle: Double
        if let kind = forcedKind {
            color = kind.color
            shape = kind.shape
            glow = Double(kind.glow)
            sparkle = Double(kind.sparkle)
        } else {
            let blended = PotionSim.blendedColor(for: ingredients)
            color = PotionColor.luminous(blended)
            let topIng = ingredients.max(by: { $0.value < $1.value })?.key
            shape = topIng?.vesselShape ?? .round
            glow = Double(max(0.3, cauldronGlow))
            sparkle = Double(min(1, 0.35 + CGFloat(glitter.count) / 140))
        }

        let bottle = PotionBottle(
            id: nextID,
            r: color.r,
            g: color.g,
            b: color.b,
            fill: 0.86,
            shape: shape.rawValue,
            kind: forcedKind?.rawValue,
            magic: mag,
            glow: glow,
            sparkle: sparkle
        )
        nextID += 1
        made += 1
        return bottle
    }

    // MARK: Switchable Creatures & Hilarious Reactions

    func selectCreature(_ next: LabCreature) {
        guard creature != next else {
            tapCreature()
            return
        }
        creature = next
        creatureState.hop = -1
        creatureState.hopV = -260
        creatureState.giggle = 0.8
        sparkleBurst(at: CGPoint(x: PotionGeometry.creatureFeet.x, y: PotionGeometry.creatureFeet.y - 95), color: RGB(hex: "#FFB8E4"), n: 14)
        cue(.poof, gap: 0.05)
        save()
    }

    @discardableResult
    func serveBottle(at index: Int, from origin: CGPoint? = nil) -> TransformationEffect? {
        guard let bottle = stand[safe: index] else { return nil }
        let start = origin ?? PotionGeometry.standSlots[min(index, PotionGeometry.standSlots.count - 1)]
        let overCreature = CGPoint(x: PotionGeometry.creatureFeet.x + 28, y: PotionGeometry.creatureFeet.y - 210 + creatureState.floatY)
        flyers.append(PFlyer(
            from: start,
            to: overCreature,
            bottle: bottle,
            standIndex: nil,
            spin: -1.4,
            pouringOnCreature: true
        ))
        return applyToCreature(bottle)
    }

    @discardableResult
    func applyToCreature(_ bottle: PotionBottle) -> TransformationEffect {
        let effect = bottle.effect
        creatureState.activeEffect = effect
        creatureState.effectTimer = 18
        creatureState.tint = bottle.color
        creatureState.tintAmt = 0.82
        creatureState.giggle = 1.4
        creatureState.hop = -1
        creatureState.hopV = -280
        hasActiveEffect = true

        if effect.isFloating {
            if creatureState.floatY > -10 { creatureState.floatV = -120 }
        }
        if effect == .dragonFire {
            creatureState.hiccupAt = 0.25
            creatureState.hiccupKick = 1.0
        }

        let center = CGPoint(x: PotionGeometry.creatureFeet.x, y: PotionGeometry.creatureFeet.y - 110 + creatureState.floatY)
        sparkleBurst(at: center, color: bottle.color, n: 16)
        cue(.poof, gap: 0.05)

        switch effect {
        case .bubbleFloat, .mermaid:
            cue(.boing, gap: 0.08)
        case .rainbow, .wild, .galaxy:
            cue(.magic, gap: 0.08)
        case .dragonFire:
            cue(.hiccup, gap: 0.08)
        case .frostCrown:
            cue(.frost, gap: 0.08)
        case .sleepyCloud:
            cue(.yawn, gap: 0.08)
        case .love:
            cue(.heart, gap: 0.08)
        case .golden, .moonlight:
            cue(.chime, gap: 0.08)
        }

        if trackRewards, let stickerID = effect.unlocksStickerID {
            StickerBook.shared.find(game: PotionSim.gameID, id: stickerID)
        }
        return effect
    }

    /// Tapping the creature serves the newest ready Tasting Stand bottle, or cauldron brew, or gives a giggle-hop!
    func tapCreature() {
        if let lastIndex = stand.indices.last {
            serveBottle(at: lastIndex)
            return
        }
        if !ingredients.isEmpty {
            let taste = makeBottleFromCurrentBrew(forcedKind: rare)
            applyToCreature(taste)
            return
        }
        creatureState.hop = -1
        creatureState.hopV = -290
        creatureState.giggle = 1.2
        cue(.boing, gap: 0.08)
        for k in 0..<4 {
            motes.append(PMote(
                p: CGPoint(x: PotionGeometry.creatureFeet.x + rand(-40, 40), y: PotionGeometry.creatureFeet.y - 150 + creatureState.floatY),
                v: CGVector(dx: rand(-22, 22), dy: -65 - CGFloat(k) * 10),
                max: 1.6,
                kind: .heart,
                color: RGB(hex: "#FF78B4"),
                size: 14,
                spin: rand(0, 6)
            ))
        }
    }

    /// Water-drop reset (button OR double-tap): splashes sparkling droplets and playfully shakes off active effects!
    func resetCreatureEffects() {
        creatureState.activeEffect = nil
        creatureState.effectTimer = 0
        creatureState.tintAmt = 0
        creatureState.hiccupKick = 0
        creatureState.shake = 1.15
        hasActiveEffect = false

        let center = CGPoint(x: PotionGeometry.creatureFeet.x, y: PotionGeometry.creatureFeet.y - 105 + creatureState.floatY)
        for _ in 0..<22 {
            let a = rand(0, 6.28)
            let speed = rand(120, 260)
            motes.append(PMote(
                p: CGPoint(x: center.x + cos(a) * 38, y: center.y + sin(a) * 38),
                v: CGVector(dx: cos(a) * speed, dy: sin(a) * speed * 0.7 - 90),
                max: rand(0.65, 1.05),
                kind: .drip,
                color: RGB(hex: "#72D6FF"),
                size: rand(7, 12)
            ))
        }
        sparkleBurst(at: center, color: RGB(hex: "#9EEBFF"), n: 10)
        cue(.splash, gap: 0.05)
        cue(.shakeOff, gap: 0.05)
    }

    // MARK: - Frame Stepping

    func step(_ date: Date) {
        let dt = lastDate.map { min(0.05, max(0, date.timeIntervalSince($0))) } ?? 1.0 / 60
        lastDate = date
        var left = dt
        while left > 0.0005 {
            let h = min(1.0 / 60, left)
            step(dt: h)
            left -= h
        }
    }

    func step(dt: Double) {
        let d = CGFloat(dt)
        time += dt
        night += ((moonlit ? 1 : 0) - night) * min(1, d * 3.0)
        stepHeat(d)
        stepDrain(d)
        stepPourArcs(d)
        stepSpoon(d)
        updateLiquid()
        fluidForces(d)
        fluidStep(Float(d))
        stepDrops(d)
        stepPieces(d)
        stepBubbles(d)
        stepGlitter(d)
        stepMotes(d)
        stepWaves(d)
        stepFlyers(d)
        stepCreature(d)
        stepMixAndRare(d)
        flash = max(0, flash - d * 1.6)
    }

    // MARK: Helpers & Fluid Access

    @inline(__always) static func idx(_ i: Int, _ j: Int) -> Int { j * NX + i }

    func rand() -> CGFloat { CGFloat(rng.unit()) }
    func rand(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * rand() }

    func cue(_ s: PotionSFX, gap: Double = 0.06) {
        if let t = cueAt[s], time - t < gap { return }
        cueAt[s] = time
        cues.append(s)
    }

    func surfaceY(_ x: CGFloat) -> CGFloat {
        let f = (x - PotionGeometry.gx0) / PotionGeometry.cell - 0.5
        let i = max(0, min(PotionSim.NX - 1, Int(f.rounded(.down))))
        let i1 = min(PotionSim.NX - 1, i + 1)
        let k = max(0, min(1, f - CGFloat(i)))
        let h = waveH[i] * (1 - k) + waveH[i1] * k
        let hwid = max(20, PotionGeometry.halfWidth(at: level))
        let dx = (x - PotionGeometry.cauldronCenter.x) / hwid
        let dip = swirl * max(0, 1 - dx * dx) - swirl * 0.32
        return level + h + dip
    }

    func inLiquid(_ p: CGPoint) -> Bool {
        PotionGeometry.inside(p) && p.y > surfaceY(p.x)
    }

    @inline(__always) func gridPos(_ p: CGPoint) -> (Float, Float) {
        (
            Float((p.x - PotionGeometry.gx0) / PotionGeometry.cell - 0.5),
            Float((p.y - PotionGeometry.gy0) / PotionGeometry.cell - 0.5)
        )
    }

    func cellIndex(_ p: CGPoint) -> Int? {
        let i = Int((p.x - PotionGeometry.gx0) / PotionGeometry.cell)
        let j = Int((p.y - PotionGeometry.gy0) / PotionGeometry.cell)
        guard i >= 0, j >= 0, i < PotionSim.NX, j < PotionSim.NY else { return nil }
        return PotionSim.idx(i, j)
    }

    @inline(__always) func sample(_ f: [Float], _ x: Float, _ y: Float) -> Float {
        let NX = PotionSim.NX
        let NY = PotionSim.NY
        let fx = max(0, min(Float(NX - 1) - 0.001, x))
        let fy = max(0, min(Float(NY - 1) - 0.001, y))
        let i0 = Int(fx)
        let j0 = Int(fy)
        let tx = fx - Float(i0)
        let ty = fy - Float(j0)
        let a = f[j0 * NX + i0]
        let b = f[j0 * NX + i0 + 1]
        let c = f[(j0 + 1) * NX + i0]
        let d = f[(j0 + 1) * NX + i0 + 1]
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    }

    func flow(_ p: CGPoint) -> CGVector {
        let (x, y) = gridPos(p)
        return CGVector(dx: CGFloat(sample(u, x, y)), dy: CGFloat(sample(v, x, y)))
    }

    func meanColor() -> (RGB, CGFloat) {
        var r: Float = 0, g: Float = 0, b: Float = 0, a: Float = 0
        var n = 0
        for k in liquid.indices where liquid[k] {
            r += dr[k]; g += dg[k]; b += db[k]; a += da[k]; n += 1
        }
        guard n > 0, a > 0.001 else { return (PotionColor.clearWater, 0) }
        let raw = RGB(Double(r / a), Double(g / a), Double(b / a))
        return (PotionColor.luminous(raw), CGFloat(a / Float(n)))
    }

    static func blendedColor(for counts: [PIngredient: Int]) -> RGB {
        var r = 0.0, g = 0.0, b = 0.0, total = 0.0
        for (ing, count) in counts where count > 0 {
            let w = Double(count)
            r += ing.color.r * w
            g += ing.color.g * w
            b += ing.color.b * w
            total += w
        }
        guard total > 0 else { return PotionColor.clearWater }
        return PotionColor.luminous(RGB(r / total, g / total, b / total))
    }

    var cauldronGlow: CGFloat {
        if let r = rare { return r.glow * min(1, turn + 0.4) }
        let sparkles = CGFloat(ingredients[.starGlitter] ?? 0) * 0.22
        let chili = CGFloat(ingredients[.dragonChili] ?? 0) * 0.2
        let moon = CGFloat(ingredients[.sleepyLavender] ?? 0) * (moonlit ? 0.35 : 0.14)
        return min(0.85, sparkles + chili + moon + (ingredients.isEmpty ? 0 : 0.18))
    }

    func inject(_ p: CGPoint, color: RGB, amount: Float, radius: CGFloat = 2.0) {
        let (gx, gy) = gridPos(p)
        let rr = Float(radius)
        let i0 = max(0, Int(gx - rr - 1))
        let i1 = min(PotionSim.NX - 1, Int(gx + rr + 1))
        let j0 = max(0, Int(gy - rr - 1))
        let j1 = min(PotionSim.NY - 1, Int(gy + rr + 1))
        guard i0 <= i1, j0 <= j1 else { return }
        var wsum: Float = 0
        for j in j0...j1 {
            for i in i0...i1 where !solid[PotionSim.idx(i, j)] {
                let dx = Float(i) - gx
                let dy = Float(j) - gy
                wsum += max(0, 1 - (dx * dx + dy * dy) / (rr * rr + 0.5))
            }
        }
        guard wsum > 0 else { return }
        let cr = Float(color.r), cg = Float(color.g), cb = Float(color.b)
        for j in j0...j1 {
            for i in i0...i1 {
                let k = PotionSim.idx(i, j)
                guard !solid[k] else { continue }
                let dx = Float(i) - gx
                let dy = Float(j) - gy
                let w = max(0, 1 - (dx * dx + dy * dy) / (rr * rr + 0.5)) / wsum
                guard w > 0 else { continue }
                dr[k] += cr * amount * w
                dg[k] += cg * amount * w
                db[k] += cb * amount * w
                da[k] += amount * w
            }
        }
        version += 1
    }

    func push(_ p: CGPoint, _ f: CGVector, radius: CGFloat) {
        let (gx, gy) = gridPos(p)
        let rr = Float(radius / PotionGeometry.cell)
        let i0 = max(0, Int(gx - rr))
        let i1 = min(PotionSim.NX - 1, Int(gx + rr) + 1)
        let j0 = max(0, Int(gy - rr))
        let j1 = min(PotionSim.NY - 1, Int(gy + rr) + 1)
        guard i0 <= i1, j0 <= j1 else { return }
        for j in j0...j1 {
            for i in i0...i1 {
                let k = PotionSim.idx(i, j)
                guard liquid[k] else { continue }
                let dx = Float(i) - gx
                let dy = Float(j) - gy
                let w = max(0, 1 - (dx * dx + dy * dy) / (rr * rr))
                u[k] += Float(f.dx) * w
                v[k] += Float(f.dy) * w
            }
        }
    }

    func updateLiquid() {
        level = PotionGeometry.level(for: volume)
        let NX = PotionSim.NX
        for j in 0..<PotionSim.NY {
            let y = PotionGeometry.gy0 + (CGFloat(j) + 0.5) * PotionGeometry.cell
            for i in 0..<NX {
                let k = j * NX + i
                liquid[k] = !solid[k] && y > level + 2
            }
        }
    }

    func sparkleBurst(at p: CGPoint, color: RGB, n: Int) {
        for k in 0..<n {
            let a = CGFloat(k) / CGFloat(max(1, n)) * 2 * .pi + rand(0, 0.35)
            let speed = rand(55, 165)
            motes.append(PMote(
                p: p,
                v: CGVector(dx: cos(a) * speed, dy: sin(a) * speed - 35),
                max: rand(0.55, 1.05),
                kind: .sparkle,
                color: k % 3 == 0 ? RGB(1, 1, 1) : color.mix(RGB(1, 1, 1), 0.3),
                size: rand(7, 14)
            ))
        }
    }

    // MARK: - Sub-steps

    private func stepHeat(_ d: CGFloat) {
        let rate: CGFloat = burner == .boil ? 0.85 : 0.45
        temp += (burner.targetTemp - temp) * min(1, d * rate)

        if burner == .boil && volume > 1000 {
            let spawnCount = boiling * 24 * d
            var k = spawnCount
            while k > 0 {
                if rand() < k {
                    let x = PotionGeometry.cauldronCenter.x + rand(-88, 88)
                    let y = PotionGeometry.bottomY - 12 - rand(0, 16)
                    let p = CGPoint(x: x, y: y)
                    if PotionGeometry.inside(p, pad: 4) && inLiquid(p) {
                        bubbles.append(PBubble(p: p, r: rand(3, 7.5), phase: rand(0, 6), fizzy: true))
                    }
                }
                k -= 1
            }
        }

        if temp > 0.5 && volume > 1000 && rand() < (temp - 0.42) * d * 24 {
            let (mc, ma) = meanColor()
            let steamColor = RGB(1, 1, 1).mix(mc, Double(min(0.65, ma * 0.9 + 0.15)))
            let x = PotionGeometry.cauldronCenter.x + rand(-PotionGeometry.neckHalfWidth * 0.72, PotionGeometry.neckHalfWidth * 0.72)
            motes.append(PMote(
                p: CGPoint(x: x, y: max(PotionGeometry.rimY, surfaceY(x)) - 4),
                v: CGVector(dx: rand(-12, 12), dy: rand(-62, -36)),
                max: rand(1.4, 2.4),
                kind: .steam,
                color: steamColor,
                size: rand(14, 24)
            ))
        }
    }

    private func stepDrain(_ d: CGFloat) {
        if refilling {
            volume = min(PotionGeometry.baseVolume, volume + PotionGeometry.baseVolume * 2.2 * d)
            if volume >= PotionGeometry.baseVolume - 1 {
                volume = PotionGeometry.baseVolume
                refilling = false
            }
            return
        }
        guard draining else { return }
        if volume <= 10 {
            clearCauldronClean()
            draining = false
            refilling = true
            sparkleBurst(at: PotionGeometry.cauldronCenter, color: RGB(hex: "#9EEBFF"), n: 14)
            cue(.chime, gap: 0.1)
            save()
            return
        }
        let dV = min(volume, max(36000, volume * 2.4) * d)
        let (mc, ma) = meanColor()
        let outColor = PotionColor.clearWater.mix(mc, Double(min(1, ma * 1.8)))
        volume = max(0, volume - dV)
        basinFill = min(1, basinFill + dV / 42000)
        basinColor = basinColor.mix(outColor, 0.25)
        let mouth = PotionGeometry.drainMouth
        drops.append(PDrop(
            p: CGPoint(x: mouth.x + rand(-2, 2), y: mouth.y + 4),
            v: CGVector(dx: 0, dy: 90),
            color: outColor,
            r: 5,
            isDrain: true
        ))
        cue(.glug, gap: 0.35)
    }

    private func clearCauldronClean() {
        for k in da.indices {
            dr[k] = 0; dg[k] = 0; db[k] = 0; da[k] = 0; u[k] = 0; v[k] = 0
        }
        ingredients = [:]
        discoveredInBrew = []
        rare = nil
        turn = 0
        mixProgress = 1
        glitter.removeAll()
        pieces.removeAll()
        bubbles.removeAll()
        waveH = [CGFloat](repeating: 0, count: PotionGeometry.NX)
        waveV = [CGFloat](repeating: 0, count: PotionGeometry.NX)
        swirl = 0
        version += 1
    }

    private func stepPourArcs(_ d: CGFloat) {
        var keep: [PourArc] = []
        for arc0 in pourArcs {
            var arc = arc0
            arc.t += d / arc.duration
            if arc.t > 0.36 && arc.t < 0.82 && rand() < d * 36 {
                let p = pourArcPosition(arc).0
                drops.append(PDrop(
                    p: CGPoint(x: p.x + rand(-6, 6), y: p.y + 18),
                    v: CGVector(dx: (PotionGeometry.cauldronCenter.x - p.x) * 1.8 + rand(-20, 20), dy: rand(140, 240)),
                    color: arc.kind.color,
                    r: rand(4, 7)
                ))
            }
            if arc.t < 1 { keep.append(arc) }
        }
        pourArcs = keep
    }

    func pourArcPosition(_ arc: PourArc) -> (CGPoint, CGFloat) {
        let target = PotionGeometry.pourTarget
        if arc.t < 0.35 {
            let u = arc.t / 0.35
            let e = u * u * (3 - 2 * u)
            let p = CGPoint(
                x: arc.from.x + (target.x - arc.from.x) * e,
                y: arc.from.y + (target.y - arc.from.y) * e - 70 * sin(e * .pi)
            )
            return (p, -1.7 * e)
        } else if arc.t < 0.82 {
            let hold = (arc.t - 0.35) / 0.47
            let wob = sin(hold * .pi * 4) * 5
            return (CGPoint(x: target.x + wob, y: target.y), -1.75 + sin(hold * .pi * 3) * 0.16)
        } else {
            let u = (arc.t - 0.82) / 0.18
            let e = u * u * (3 - 2 * u)
            return (CGPoint(x: target.x, y: target.y - 26 * e), -1.75 * (1 - e))
        }
    }

    private func stepSpoon(_ d: CGFloat) {
        let old = spoon
        if spoonHeld {
            let k = min(1, d * 24)
            spoon = CGPoint(x: spoon.x + (spoonTarget.x - spoon.x) * k, y: spoon.y + (spoonTarget.y - spoon.y) * k)
        } else {
            let k = min(1, d * 3.0)
            spoon = CGPoint(x: spoon.x + (PotionSim.spoonRest.x - spoon.x) * k, y: spoon.y + (PotionSim.spoonRest.y - spoon.y) * k)
        }
        let nv = CGVector(dx: (spoon.x - old.x) / max(d, 0.001), dy: (spoon.y - old.y) / max(d, 0.001))
        let smooth = min(1, d * 18)
        spoonVel = CGVector(dx: spoonVel.dx + (nv.dx - spoonVel.dx) * smooth, dy: spoonVel.dy + (nv.dy - spoonVel.dy) * smooth)
        let speed = hypot(spoonVel.dx, spoonVel.dy)
        let wet = inLiquid(spoon)
        stirSpeed += ((wet ? speed : 0) - stirSpeed) * min(1, d * 8)
        guard wet else { return }

        push(spoon, CGVector(dx: spoonVel.dx * 0.45, dy: spoonVel.dy * 0.45), radius: 34)
        let col = Int((spoon.x - PotionGeometry.gx0) / PotionGeometry.cell)
        if col >= 0 && col < PotionSim.NX && spoon.y - surfaceY(spoon.x) < 60 {
            waveV[col] += spoonVel.dy * 0.003 + abs(spoonVel.dx) * 0.0014
        }
        if speed > 220 && rand() < d * min(18, speed / 40) {
            bubbles.append(PBubble(p: CGPoint(x: spoon.x + rand(-10, 10), y: spoon.y + rand(-10, 10)), r: rand(2, 4.5), phase: rand(0, 6), fizzy: false))
        }
        if speed > 260 && rand() < d * 12 {
            let (mc, _) = meanColor()
            motes.append(PMote(
                p: CGPoint(x: spoon.x + rand(-14, 14), y: surfaceY(spoon.x) - 6),
                v: CGVector(dx: rand(-30, 30), dy: rand(-75, -35)),
                max: 0.7,
                kind: .sparkle,
                color: mc.mix(RGB(1, 1, 1), 0.5),
                size: rand(5, 10)
            ))
        }
    }

    private func fluidForces(_ d: CGFloat) {
        let NX = PotionSim.NX
        let NY = PotionSim.NY
        let heatStir = Float(boiling) * 38
        guard heatStir > 0.1 else { return }
        for j in 0..<NY {
            for i in 0..<NX {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let x = Float(i) / Float(NX - 1) - 0.5
                v[k] -= Float(d) * heatStir * (cos(x * 6.28 + Float(time) * 0.9) * 1.3)
            }
        }
    }

    func fluidStep(_ dt: Float) {
        let NX = PotionSim.NX
        let NY = PotionSim.NY
        let n = NX * NY
        for k in 0..<n where !liquid[k] { u[k] = 0; v[k] = 0 }

        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                curl[k] = liquid[k] ? 0.5 * ((v[k + 1] - v[k - 1]) - (u[k + NX] - u[k - NX])) : 0
            }
        }
        let eps: Float = 1.5
        for j in 2..<(NY - 2) {
            for i in 2..<(NX - 2) {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let gx = abs(curl[k + 1]) - abs(curl[k - 1])
                let gy = abs(curl[k + NX]) - abs(curl[k - NX])
                let len = sqrt(gx * gx + gy * gy) + 1e-5
                let w = curl[k]
                u[k] += dt * eps * (gy / len) * w
                v[k] -= dt * eps * (gx / len) * w
            }
        }

        t0 = u
        t1 = v
        let s = dt / Float(PotionGeometry.cell)
        for j in 0..<NY {
            for i in 0..<NX {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let x = Float(i) - s * t0[k]
                let y = Float(j) - s * t1[k]
                u[k] = sample(t0, x, y) * 0.992
                v[k] = sample(t1, x, y) * 0.992
            }
        }
        for k in 0..<n where !liquid[k] { u[k] = 0; v[k] = 0 }

        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                dv[k] = liquid[k] ? -0.5 * (u[k + 1] - u[k - 1] + v[k + NX] - v[k - NX]) : 0
            }
        }
        for _ in 0..<12 {
            for j in 1..<(NY - 1) {
                for i in 1..<(NX - 1) {
                    let k = j * NX + i
                    guard liquid[k] else { continue }
                    let pc = pr[k]
                    let a = liquid[k - 1] ? pr[k - 1] : pc
                    let b = liquid[k + 1] ? pr[k + 1] : pc
                    let c = liquid[k - NX] ? pr[k - NX] : pc
                    let e = liquid[k + NX] ? pr[k + NX] : pc
                    pr[k] = (dv[k] + a + b + c + e) * 0.25
                }
            }
        }
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let pc = pr[k]
                let a = liquid[k - 1] ? pr[k - 1] : pc
                let b = liquid[k + 1] ? pr[k + 1] : pc
                let c = liquid[k - NX] ? pr[k - NX] : pc
                let e = liquid[k + NX] ? pr[k + NX] : pc
                u[k] = max(-750, min(750, u[k] - 0.5 * (b - a)))
                v[k] = max(-750, min(750, v[k] - 0.5 * (e - c)))
            }
        }

        extend(&dr); extend(&dg); extend(&db); extend(&da)
        t0 = dr; t1 = dg; t2 = db; t3 = da
        for j in 0..<NY {
            for i in 0..<NX {
                let k = j * NX + i
                guard liquid[k] else { continue }
                let x = Float(i) - s * u[k]
                let y = Float(j) - s * v[k]
                dr[k] = sample(t0, x, y)
                dg[k] = sample(t1, x, y)
                db[k] = sample(t2, x, y)
                da[k] = sample(t3, x, y)
            }
        }

        let diff: Float = 0.018 + Float(temp) * 0.015
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                guard liquid[k] else { continue }
                var cnt: Float = 0
                var ar: Float = 0, ag: Float = 0, ab: Float = 0, aa: Float = 0
                for o in [k - 1, k + 1, k - NX, k + NX] where liquid[o] {
                    ar += dr[o]; ag += dg[o]; ab += db[o]; aa += da[o]; cnt += 1
                }
                guard cnt > 0 else { continue }
                dr[k] = max(0, dr[k] + (ar / cnt - dr[k]) * diff)
                dg[k] = max(0, dg[k] + (ag / cnt - dg[k]) * diff)
                db[k] = max(0, db[k] + (ab / cnt - db[k]) * diff)
                da[k] = max(0, da[k] + (aa / cnt - da[k]) * diff)
            }
        }

        for i in 0..<NX {
            var top = -1
            for j in 0..<NY where liquid[j * NX + i] { top = j; break }
            guard top > 0 else { continue }
            let src = top * NX + i
            for j in 0..<top {
                let k = j * NX + i
                if solid[k] { continue }
                dr[k] = dr[src]; dg[k] = dg[src]; db[k] = db[src]; da[k] = da[src]
            }
        }

        var spin: Float = 0
        var cnt: Float = 0
        for k in 0..<n where liquid[k] { spin += abs(u[k]); cnt += 1 }
        let sw = CGFloat(cnt > 0 ? spin / cnt : 0)
        swirl += (min(22, sw * 0.1) - swirl) * 0.06
        version += 1
    }

    private func extend(_ f: inout [Float]) {
        let NX = PotionSim.NX
        let NY = PotionSim.NY
        for j in 1..<(NY - 1) {
            for i in 1..<(NX - 1) {
                let k = j * NX + i
                guard !liquid[k] && solid[k] else { continue }
                var s: Float = 0, c: Float = 0
                if liquid[k - 1] { s += f[k - 1]; c += 1 }
                if liquid[k + 1] { s += f[k + 1]; c += 1 }
                if liquid[k - NX] { s += f[k - NX]; c += 1 }
                if liquid[k + NX] { s += f[k + NX]; c += 1 }
                if c > 0 { f[k] = s / c }
            }
        }
    }

    private func stepDrops(_ d: CGFloat) {
        var keep: [PDrop] = []
        keep.reserveCapacity(drops.count)
        for dp0 in drops {
            var dp = dp0
            dp.v.dy += 1200 * d
            dp.p.x += dp.v.dx * d
            dp.p.y += dp.v.dy * d
            if dp.isDrain {
                if dp.p.y > PotionGeometry.basinRect.minY + 14 { continue }
                keep.append(dp)
                continue
            }
            if PotionGeometry.inside(dp.p) && dp.p.y > surfaceY(dp.p.x) {
                let col = Int((dp.p.x - PotionGeometry.gx0) / PotionGeometry.cell)
                if col >= 0 && col < PotionSim.NX { waveV[col] += 0.9 }
                inject(dp.p, color: dp.color, amount: 2.2, radius: 1.6)
                continue
            }
            if dp.p.y > PotionGeometry.tableY { continue }
            keep.append(dp)
        }
        drops = keep
    }

    private func stepPieces(_ d: CGFloat) {
        var keep: [PPiece] = []
        for pc0 in pieces {
            var pc = pc0
            pc.age += d
            pc.ang += pc.spin * d
            switch pc.state {
            case .air:
                pc.v.dy += 1050 * d
                pc.p.x += pc.v.dx * d
                pc.p.y += pc.v.dy * d
                if PotionGeometry.inside(pc.p, pad: 4) && pc.p.y > surfaceY(pc.p.x) {
                    pc.state = .liquid
                    pc.v = CGVector(dx: pc.v.dx * 0.25, dy: pc.v.dy * 0.2)
                    cue(.plop, gap: 0.1)
                }
                if pc.p.y > PotionGeometry.bottomY { continue }
            case .liquid:
                let fl = flow(pc.p)
                pc.v.dx += (fl.dx - pc.v.dx) * min(1, d * 4)
                pc.v.dy += (fl.dy - pc.v.dy) * min(1, d * 4) + (pc.kind == .bubbleBerry ? 90 : -60) * d
                pc.p.x += pc.v.dx * d
                pc.p.y += pc.v.dy * d
                let surf = surfaceY(pc.p.x)
                if pc.p.y < surf + 4 { pc.p.y = surf + 4 }
                if !PotionGeometry.inside(pc.p, pad: 8) {
                    pc.p.x += (PotionGeometry.cauldronCenter.x - pc.p.x) * 0.15
                    pc.p.y = min(PotionGeometry.bottomY - 10, pc.p.y)
                }
                pc.dissolve = min(1, pc.dissolve + d * (0.38 + min(1.2, stirSpeed / 400)))
                if pc.dissolve >= 1 { continue }
            }
            if pc.kind == .rainbowMane {
                pc.trail.insert(pc.p, at: 0)
                if pc.trail.count > 10 { pc.trail.removeLast() }
            }
            keep.append(pc)
        }
        pieces = keep
    }

    private func addGlitter(at p: CGPoint, color: RGB, size: CGFloat) {
        if glitter.count > 260 { glitter.removeFirst(glitter.count - 260) }
        glitter.append(PGlitter(p: p, color: color, size: size, phase: rand(0, 6.28)))
    }

    private func stepBubbles(_ d: CGFloat) {
        var keep: [PBubble] = []
        keep.reserveCapacity(bubbles.count)
        for b0 in bubbles {
            var b = b0
            b.phase += d * 8.5
            let fl = flow(b.p)
            let rise = 44 + b.r * 15
            b.p.x += (fl.dx * 0.55 + sin(b.phase) * b.r * 2.5) * d
            b.p.y += (fl.dy * 0.35 - rise) * d
            if !PotionGeometry.inside(b.p, pad: b.r) {
                b.p.x += (PotionGeometry.cauldronCenter.x - b.p.x) * 0.1
            }
            let surf = surfaceY(b.p.x)
            if b.p.y <= surf + b.r * 0.5 {
                let col = Int((b.p.x - PotionGeometry.gx0) / PotionGeometry.cell)
                if col >= 0 && col < PotionSim.NX { waveV[col] -= b.r * 0.04 }
                if b.r > 3.2 && rand() < 0.35 { cue(.pop, gap: 0.08) }
                if b.fizzy && rand() < 0.14 {
                    motes.append(PMote(
                        p: CGPoint(x: b.p.x, y: surf - 4),
                        v: CGVector(dx: rand(-22, 22), dy: rand(-75, -35)),
                        max: 0.65,
                        kind: .sparkle,
                        color: RGB(1, 1, 1),
                        size: rand(4, 8)
                    ))
                }
                continue
            }
            keep.append(b)
        }
        bubbles = keep
        if bubbles.count > 180 { bubbles.removeFirst(bubbles.count - 180) }
    }

    private func stepGlitter(_ d: CGFloat) {
        guard !glitter.isEmpty else { return }
        for i in glitter.indices {
            var g = glitter[i]
            g.phase += d * 3.2
            let fl = flow(g.p)
            g.p.x += fl.dx * d
            g.p.y += (fl.dy + 7) * d
            if !PotionGeometry.inside(g.p, pad: 4) {
                g.p.x += (PotionGeometry.cauldronCenter.x - g.p.x) * 0.08
                g.p.y = min(PotionGeometry.bottomY - 6, g.p.y)
            }
            let s = surfaceY(g.p.x) + 4
            if g.p.y < s { g.p.y = s }
            glitter[i] = g
        }
    }

    private func stepMotes(_ d: CGFloat) {
        var keep: [PMote] = []
        keep.reserveCapacity(motes.count)
        for m0 in motes {
            var m = m0
            m.life += d
            if m.life >= m.max { continue }
            switch m.kind {
            case .steam:
                m.v.dy -= 8 * d
                m.v.dx += sin(CGFloat(time) * 2.2 + m.p.y * 0.05) * 18 * d
                m.size += d * 14
            case .fog:
                m.v.dy += 24 * d
                m.size += d * 8
                if m.p.y > PotionGeometry.tableY - 8 { m.p.y = PotionGeometry.tableY - 8; m.v.dy = 0 }
            case .sparkle:
                m.v.dy += 50 * d
                m.v.dx *= 1 - d * 1.4
            case .fireHeart:
                m.v.dx = sin(CGFloat(time) * 4 + m.spin) * 24 + 28
                m.v.dy -= 12 * d
            case .heart:
                m.v.dx = sin(CGFloat(time) * 3 + m.spin) * 26
            case .snow:
                m.v.dx = sin(CGFloat(time) * 2 + m.spin) * 18
            case .soap:
                m.v.dx = sin(CGFloat(time) * 1.6 + m.spin) * 18
                m.v.dy = max(-45, m.v.dy - 6 * d)
            case .zz:
                m.v.dx = sin(CGFloat(time) * 2 + m.spin) * 14
            case .flash:
                m.size += d * 420
            case .drip:
                m.v.dy += 760 * d
                if m.p.y > PotionGeometry.tableY + 20 { continue }
            case .confetti:
                m.v.dy += 95 * d
                m.v.dx = sin(CGFloat(time) * 5 + m.spin) * 45
            case .starOrbit:
                m.v.dy -= 16 * d
            }
            m.p.x += m.v.dx * d
            m.p.y += m.v.dy * d
            keep.append(m)
        }
        motes = keep
        if motes.count > 260 { motes.removeFirst(motes.count - 260) }
    }

    private func stepWaves(_ d: CGFloat) {
        let NX = PotionSim.NX
        let hwid = PotionGeometry.halfWidth(at: level)
        var active = [Bool](repeating: false, count: NX)
        var sum: CGFloat = 0
        var n: CGFloat = 0
        for i in 0..<NX {
            let x = PotionGeometry.gx0 + (CGFloat(i) + 0.5) * PotionGeometry.cell
            active[i] = abs(x - PotionGeometry.cauldronCenter.x) < hwid - 2 && volume > 100
            if active[i] { sum += waveH[i]; n += 1 }
        }
        let mean = n > 0 ? sum / n : 0
        let k = d * 60
        let boil = boiling
        for i in 0..<NX {
            guard active[i] else { waveH[i] = 0; waveV[i] = 0; continue }
            let l = i > 0 && active[i - 1] ? waveH[i - 1] : waveH[i]
            let r = i < NX - 1 && active[i + 1] ? waveH[i + 1] : waveH[i]
            waveV[i] += (0.28 * (l + r - 2 * waveH[i]) - 0.004 * (waveH[i] - mean)) * k
            waveV[i] *= pow(0.98, k)
            if boil > 0 && rand() < boil * d * 10 { waveV[i] += rand(-0.75, 0.75) * boil }
        }
        for i in 0..<NX where active[i] {
            waveH[i] += waveV[i] * k
            waveH[i] = max(-22, min(22, waveH[i] - mean * 0.02))
        }
    }

    private func stepFlyers(_ d: CGFloat) {
        var keep: [PFlyer] = []
        for f0 in flyers {
            var f = f0
            f.t += d / 0.5
            if f.t >= 1 {
                if !f.pouringOnCreature { cue(.clink, gap: 0.1) }
                continue
            }
            keep.append(f)
        }
        flyers = keep
    }

    static func flyerPosition(_ f: PFlyer) -> (CGPoint, CGFloat) {
        let e = f.t * f.t * (3 - 2 * f.t)
        let p = CGPoint(
            x: f.from.x + (f.to.x - f.from.x) * e,
            y: f.from.y + (f.to.y - f.from.y) * e - 85 * sin(e * .pi)
        )
        let angle = f.pouringOnCreature ? f.spin * e : f.spin * (1 - e)
        return (p, angle)
    }

    private func stepMixAndRare(_ d: CGFloat) {
        if !ingredients.isEmpty && mixProgress < 1 {
            mixProgress = min(1, mixProgress + d * 2.0)
            if mixProgress >= 1 {
                evaluateRecipe()
            }
        }
        guard let kind = rare, volume > 100 else { return }
        turn = min(1, turn + d / 1.4)
        let NX = PotionSim.NX
        let rate = Float(min(1, d * 2.2))
        for j in 0..<PotionSim.NY {
            for i in 0..<NX {
                let c = j * NX + i
                guard liquid[c] else { continue }
                var want = kind.color
                if kind == .rainbow {
                    want = PotionColor.hue(CGFloat(j) / CGFloat(PotionSim.NY) * 1.4 + 0.02 * CGFloat(i) + CGFloat(time) * 0.08)
                } else if kind == .wild {
                    want = PotionColor.hue(CGFloat(time) * 0.18 + CGFloat(i + j) * 0.02)
                } else if kind == .galaxy {
                    want = kind.color.mix(RGB(hex: "#D656FF"), Double(0.5 + 0.5 * sin(Float(i) * 0.35 + Float(j) * 0.25 + Float(time) * 0.8)))
                }
                let a = max(da[c], 0.92)
                dr[c] += (Float(want.r) * a - dr[c]) * rate
                dg[c] += (Float(want.g) * a - dg[c]) * rate
                db[c] += (Float(want.b) * a - db[c]) * rate
                da[c] += (a - da[c]) * rate
            }
        }
        if (kind == .galaxy || kind == .golden) && glitter.count < 160 && rand() < d * 18 {
            let x = PotionGeometry.cauldronCenter.x + rand(-88, 88)
            let y = rand(max(level, PotionGeometry.rimY) + 12, PotionGeometry.bottomY - 18)
            addGlitter(at: CGPoint(x: x, y: y), color: kind == .golden ? RGB(hex: "#FFE38A") : RGB(1, 1, 1), size: rand(1.6, 2.8))
        }
    }

    private func stepCreature(_ d: CGFloat) {
        creatureState.shake = max(0, creatureState.shake - d)
        creatureState.giggle = max(0, creatureState.giggle - d)
        creatureState.hiccupKick = max(0, creatureState.hiccupKick - d * 3.8)
        creatureState.blink -= d
        if creatureState.blink < -0.14 { creatureState.blink = rand(2.2, 4.8) }

        if creatureState.effectTimer > 0 {
            creatureState.effectTimer = max(0, creatureState.effectTimer - d)
            if creatureState.effectTimer <= 0 {
                if creatureState.activeEffect?.isFloating == true {
                    cue(.pop, gap: 0.1)
                }
                creatureState.activeEffect = nil
                hasActiveEffect = false
            }
        } else {
            creatureState.tintAmt = max(0, creatureState.tintAmt - d * 0.45)
        }

        let effect = creatureState.activeEffect
        let isFloating = effect?.isFloating == true

        // Bubble float levitation high into the open left sky window (zero shelf collision!).
        if isFloating {
            let target: CGFloat = -140 + sin(CGFloat(time) * 1.9) * 14
            creatureState.floatV += (target - creatureState.floatY) * 5.2 * d
            creatureState.floatV *= max(0, 1 - d * 2.1)
            creatureState.floatY += creatureState.floatV * d
        } else if creatureState.floatY < 0 {
            creatureState.floatV += 1400 * d
            creatureState.floatY += creatureState.floatV * d
            if creatureState.floatY >= 0 {
                creatureState.floatY = 0
                creatureState.floatV = 0
                creatureState.hop = -1
                creatureState.hopV = -120
                cue(.boing, gap: 0.15)
            }
        }

        // Joyful hop physics.
        if creatureState.hop < 0 || creatureState.hopV < 0 {
            creatureState.hopV += 1550 * d
            creatureState.hop += creatureState.hopV * d
            if creatureState.hop >= 0 {
                creatureState.hop = 0
                creatureState.hopV = 0
            }
        }

        let center = CGPoint(x: PotionGeometry.creatureFeet.x, y: PotionGeometry.creatureFeet.y - 110 + creatureState.floatY + creatureState.hop)
        let mouth = CGPoint(x: PotionGeometry.creatureFeet.x + 34, y: PotionGeometry.creatureFeet.y - 122 + creatureState.floatY + creatureState.hop)

        if let eff = effect {
            switch eff {
            case .dragonFire:
                creatureState.hiccupAt -= d
                if creatureState.hiccupAt <= 0 {
                    creatureState.hiccupAt = rand(0.95, 1.45)
                    creatureState.hiccupKick = 1.0
                    creatureState.hop = -1
                    creatureState.hopV = -175
                    cue(.hiccup, gap: 0.25)
                    for k in 0..<3 {
                        motes.append(PMote(
                            p: mouth,
                            v: CGVector(dx: 55 + CGFloat(k) * 14, dy: -52 - CGFloat(k) * 12),
                            max: 1.5,
                            kind: .fireHeart,
                            color: k % 2 == 0 ? RGB(hex: "#FF7B42") : RGB(hex: "#FF5E96"),
                            size: rand(12, 16),
                            spin: rand(0, 6)
                        ))
                    }
                }
            case .love:
                if rand() < d * 3.2 {
                    motes.append(PMote(
                        p: CGPoint(x: center.x + rand(-58, 58), y: center.y - 45),
                        v: CGVector(dx: 0, dy: -55),
                        max: 1.9,
                        kind: .heart,
                        color: RGB(hex: "#FF62A4"),
                        size: rand(12, 18),
                        spin: rand(0, 6)
                    ))
                }
            case .frostCrown:
                if rand() < d * 6.5 {
                    motes.append(PMote(
                        p: CGPoint(x: center.x + rand(-78, 78), y: center.y - 95),
                        v: CGVector(dx: 0, dy: 44),
                        max: 2.2,
                        kind: .snow,
                        color: RGB(1, 1, 1),
                        size: rand(6, 11),
                        spin: rand(0, 6)
                    ))
                }
            case .sleepyCloud:
                if rand() < d * 1.4 {
                    motes.append(PMote(
                        p: CGPoint(x: mouth.x + 22, y: mouth.y - 48),
                        v: CGVector(dx: 12, dy: -32),
                        max: 2.3,
                        kind: .zz,
                        color: RGB(hex: "#B49BFF"),
                        size: rand(13, 19),
                        spin: rand(0, 6)
                    ))
                }
            case .rainbow:
                if creatureState.hop == 0 && rand() < d * 1.6 {
                    creatureState.hop = -1
                    creatureState.hopV = -195
                }
                if rand() < d * 6 {
                    motes.append(PMote(
                        p: CGPoint(x: center.x + rand(-65, 65), y: center.y + rand(-50, 40)),
                        v: CGVector(dx: rand(-18, 18), dy: -42),
                        max: 1.1,
                        kind: .sparkle,
                        color: PotionColor.hue(rand()),
                        size: rand(7, 13)
                    ))
                }
            case .wild:
                if creatureState.hop == 0 && rand() < d * 2.2 {
                    creatureState.hop = -1
                    creatureState.hopV = -210
                }
                if rand() < d * 8 {
                    motes.append(PMote(
                        p: CGPoint(x: center.x + rand(-75, 75), y: center.y - 90),
                        v: CGVector(dx: rand(-40, 40), dy: 30),
                        max: 1.8,
                        kind: .confetti,
                        color: PotionColor.hue(rand()),
                        size: rand(7, 12),
                        spin: rand(0, 6)
                    ))
                }
            case .bubbleFloat, .mermaid:
                if rand() < d * 3.5 {
                    motes.append(PMote(
                        p: CGPoint(x: center.x + rand(-80, 80), y: center.y + rand(-40, 60)),
                        v: CGVector(dx: rand(-12, 12), dy: -38),
                        max: 2.4,
                        kind: .soap,
                        color: eff == .mermaid ? RGB(hex: "#7AF2E8") : RGB(1, 1, 1),
                        size: rand(8, 15),
                        spin: rand(0, 6)
                    ))
                }
            case .galaxy, .moonlight, .golden:
                if rand() < d * 4.5 {
                    let col: RGB = eff == .golden ? RGB(hex: "#FFE072") : (eff == .moonlight ? RGB(hex: "#E6E0FF") : RGB(hex: "#B8A6FF"))
                    motes.append(PMote(
                        p: CGPoint(x: center.x + rand(-72, 72), y: center.y + rand(-70, 50)),
                        v: CGVector(dx: rand(-14, 14), dy: -28),
                        max: 1.4,
                        kind: .sparkle,
                        color: col,
                        size: rand(6, 12)
                    ))
                }
            }
        }

        var lookTarget = PotionGeometry.cauldronCenter
        if let drag = draggedIngredient { lookTarget = drag.pos }
        else if let dragB = draggedStandBottle { lookTarget = dragB.pos }
        else if spoonHeld { lookTarget = spoon }
        creatureState.look = CGPoint(
            x: creatureState.look.x + (lookTarget.x - creatureState.look.x) * min(1, d * 4.5),
            y: creatureState.look.y + (lookTarget.y - creatureState.look.y) * min(1, d * 4.5)
        )
    }

    // MARK: - Screenshot / Demo Helper

    func showcase(_ mode: String) {
        demo = true
        trackRewards = false
        stand = [
            PotionBottle(id: 1, r: 1, g: 0.32, b: 0.62, fill: 0.88, shape: PBottleShape.heart.rawValue, kind: PotionKind.love.rawValue, magic: ["love": 1], glow: 0.42, sparkle: 0.5),
            PotionBottle(id: 2, r: 0.34, g: 0.21, b: 0.78, fill: 0.88, shape: PBottleShape.star.rawValue, kind: PotionKind.galaxy.rawValue, magic: ["sparkle": 1], glow: 0.62, sparkle: 1),
            PotionBottle(id: 3, r: 0.11, g: 0.83, b: 0.77, fill: 0.88, shape: PBottleShape.drop.rawValue, kind: PotionKind.mermaid.rawValue, magic: ["bubble": 1], glow: 0.42, sparkle: 0.5),
            PotionBottle(id: 4, r: 1, g: 0.78, b: 0.21, fill: 0.88, shape: PBottleShape.diamond.rawValue, kind: PotionKind.golden.rawValue, magic: ["glow": 1], glow: 0.82, sparkle: 1),
        ]
        nextID = 10
        addIngredient(.fairyRose)
        addIngredient(.mermaidWave)
        switch mode {
        case "boil":
            setBurner(.boil)
            addIngredient(.dragonChili)
            addIngredient(.starGlitter)
        case "night":
            setMoonlit(true)
            night = 1
            ingredients = [.sleepyLavender: 1, .starGlitter: 1]
            mixProgress = 1
            evaluateRecipe()
        case "unicorn", "creature":
            applyToCreature(stand[2])
        default:
            break
        }
        for _ in 0..<45 { step(dt: 1.0 / 60) }
    }
}
