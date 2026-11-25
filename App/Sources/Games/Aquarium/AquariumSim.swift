import SwiftUI

enum AquaTool: Equatable {
    case food, wiper, hoop, net, egg
    case fish(FishKind)
    case decor(AquaDecorKind)
}

struct AquaFish {
    var id: Int
    var kind: FishKind
    var variant: Int
    var p: CGPoint
    var v: CGVector = .zero
    /// Drawn x scale in -1...1 so turning passes smoothly through a narrow side view.
    var facing: CGFloat = 1
    var dir: CGFloat = 1
    var phase: CGFloat = 0
    var amp: CGFloat = 0.2
    var accel: CGFloat = 0
    /// Depth from 0 (back) to 1 (front glass).
    var z: CGFloat = 0.5
    var zTarget: CGFloat = 0.5
    var target: CGPoint
    var nextThink: Double = 0
    var fleeUntil: Double = -10
    var flee: CGVector = .zero
    var curious: CGPoint?
    var curiousUntil: Double = -10
    var appetite: CGFloat = 5
    var gulp: CGFloat = 0
    var happy: Double = -10
    var flipStart: Double = -10
    var hungryCue: CGFloat = 0
    var snackReadyAt: Double = 8
    var anemoneUntil: Double = -10
    var anemoneCooldown: Double = 0
    var puff: CGFloat = 0
    var puffV: CGFloat = 0
    var puffUntil: Double = -10
    var restUntil: Double = -10
    var activity: AquaFishActivity = .cruising
    var activityCooldown: Double = 0
    var swimThroughDir: CGFloat = 1
    var nextSleepZ: Double = 0
    var nextBubble: Double = 0
    var caught = false
    /// Growth stage: 0 = baby (0.55x), 1 = kid (0.78x), 2 = adult (1.0x).
    var growthStage: Int = 2
    var growthBites: Int = 0
    var grewUp: Bool = false
    /// Glowing stardust shimmer after eating a Pearl Pellet.
    var stardustUntil: Double = -10

    var growthScale: CGFloat {
        switch growthStage {
        case 0: return 0.55
        case 1: return 0.78
        default: return 1.0
        }
    }

    var scale: CGFloat { (0.8 + 0.22 * z) * growthScale }
}

enum FoodState { case air, floating, sinking, settled }

struct AquaFood {
    var p: CGPoint
    var v: CGVector
    var state: FoodState = .air
    var age: CGFloat = 0
    var floatFor: CGFloat
    var hue: Int
    var rot: CGFloat
    var spin: CGFloat
    var seed: CGFloat
    var kind: AquaTreatMode = .flakes
}

struct AquaBubble {
    var p: CGPoint
    var r: CGFloat
    var vy: CGFloat = 0
    var phase: CGFloat
    var back = false
}

enum AquaPart { case splash, sand, heart, sparkle, ring, moss, glow, poof, note, sleepZ }

struct AquaParticle {
    var kind: AquaPart
    var p: CGPoint
    var v: CGVector
    var age: CGFloat = 0
    var life: CGFloat
    var size: CGFloat
    var color: ARGB
}

struct AquaDecor {
    var id: Int
    var kind: AquaDecorKind
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var rot: CGFloat = 0
    var rotV: CGFloat = 0
    var falling = false
    var wet = true
    var held = false
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var sway: CGFloat = 0
    var swayV: CGFloat = 0
    var open: CGFloat = 0
    var openUntil: Double = -10
    var boostUntil: Double = -10
    var nextPuff: Double = 0
    var flip = false
    var poke: Double = -10
}

struct AquaSnail {
    var p: CGPoint
    var heading: CGFloat
    var target: CGPoint
    var hide: CGFloat = 0
    var hideUntil: Double = -10
    var phase: CGFloat = 0
}

struct AquaQuickAction {
    enum Kind { case food, wiper, net }
    var kind: Kind
    var from: CGPoint
    var target: CGPoint
    var start: Double
    var duration: Double
    var triggered = false
}

final class AquariumSim {
    static let gameID = "aquarium"
    static let gravity: CGFloat = 1600
    static let maxFish = 24
    static let maxParticles = 120
    static let maxEggs = 3
    static let maxFloatingGifts = 4
    static let wiperScale: CGFloat = 1.45
    static let coinCooldown: Double = 2.5

    var fish: [AquaFish] = []
    var food: [AquaFood] = []
    var bubbles: [AquaBubble] = []
    var hoops: [BubbleHoop] = []
    var particles: [AquaParticle] = []
    var decor: [AquaDecor] = []
    var eggs: [AquaEgg] = []
    var floatingGifts: [AquaFloatingGift] = []
    var activeWish: AquaActiveWish?
    var nextWishAt: Double = 8
    var submarine = AquaSubmarine()
    var hiddenSpots: [AquaHiddenSpot] = []
    var clams: [AquaSingingClam] = []
    var snail: AquaSnail
    var moss: [AquaMossPatch]
    var sh: [CGFloat]
    var sv: [CGFloat]

    var lightsOn = true
    var pump = true
    var treatMode: AquaTreatMode = .flakes
    var night: CGFloat = 0
    var time: Double = 0
    var demo = false
    var lastFed: Double = 0
    var feedEatenCount = 0
    var lastFeedRewardAt: Double = -100
    var lastHoopCoinAt: Double = -100
    var lastChestCoinAt: Double = -100
    var lastCleanCoinAt: Double = -100
    var lastSubCoinAt: Double = -100
    var lastGiftCoinAt: Double = -100
    var lastWishCoinAt: Double = -100

    var clamTapTimes: [Double] = []
    var ribbonDanceStart: Double = -100
    var ribbonDanceUntil: Double = -100
    var isRibbonDanceActive: Bool { time < ribbonDanceUntil }

    var visitors: [AVisitor] = []
    var nextVisit: Double = 8
    var pearl: (id: Int, until: Double)?

    /// Deferred side-effects queued during `step()` and flushed after Canvas render so 60 FPS draws never trigger `@Published` or disk I/O.
    var pendingCoins: [(Int, CGPoint)] = []
    var pendingStickers: [String] = []
    var needsSave = false
    var onUIStateChange: ((AquaUIState) -> Void)?
    private(set) var isStepping = false
    private var flushScheduled = false
    private var lastCueCheck: Double = -10
    private var cachedHungryFish = false
    private var cachedDirtyGlass = false
    private var lastEmittedUIState = AquaUIState()
    private var pendingUIState: AquaUIState?

    private var last: Date?
    private var lastSave: Double = 0
    private var nextID = 1
    private var wasDirty = false
    private var nextEggSpeciesCursor = 0

    // Carried tool state
    var tool: AquaTool?
    var toolP = CGPoint.zero
    var finger = CGPoint.zero
    var hold = CGPoint.zero
    var toolV = CGVector.zero
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var shake: CGFloat = 0
    var caught: Int?
    private var lastToolV = CGVector.zero
    private var foodAcc: CGFloat = 0
    private var squeakAt: Double = 0
    var returning: (tool: AquaTool, from: CGPoint, to: CGPoint, start: Double, tilt: CGFloat)?
    var quickAction: AquaQuickAction?

    // Direct hand state
    private enum Grab {
        case none
        case submarine
        case decor(id: Int)
        case maybeDecor(id: Int)
        case surface
        case water
    }
    private var grab: Grab = .none
    var isGrabbingSubmarine: Bool {
        if case .submarine = grab { return true }
        return false
    }
    var hand: CGPoint?
    private var handStart: Double = 0
    private var handStartP = CGPoint.zero
    private var handStill: Double = 0
    private var handV = CGVector.zero
    var decorTarget = CGPoint.zero

    init(save: AquaSave? = AquaStorage.load()) {
        moss = AquaMossPatch.makeDefault()
        sh = [CGFloat](repeating: 0, count: AGeo.surfaceNodes)
        sv = [CGFloat](repeating: 0, count: AGeo.surfaceNodes)
        snail = AquaSnail(p: CGPoint(x: 880, y: 560), heading: .pi, target: CGPoint(x: 700, y: 520))
        clams = Self.makeDefaultClams()
        hiddenSpots = Self.makeDefaultHiddenSpots()
        if let s = save {
            restore(s)
        } else {
            starterTank()
        }
    }

    private static func makeDefaultClams() -> [AquaSingingClam] {
        let specs: [(CGFloat, UInt32)] = [
            (188, 0xFFB0C8),
            (396, 0xFFE48F),
            (628, 0x9BE8CE),
            (842, 0xC7B4FF),
        ]
        return specs.enumerated().map { idx, spec in
            AquaSingingClam(id: idx, x: spec.0, y: AGeo.sand(spec.0) - 8, noteIndex: idx, shellHex: spec.1)
        }
    }

    private static func makeDefaultHiddenSpots() -> [AquaHiddenSpot] {
        let specs: [(AquaHiddenSpotKind, CGFloat, CGFloat)] = [
            (.hermitCrab, 245, 0),
            (.glowSeahorse, 455, -18),
            (.starfish, 695, 0),
            (.sunkenPearl, 865, 0),
        ]
        return specs.enumerated().map { idx, spec in
            AquaHiddenSpot(id: idx, kind: spec.0, p: CGPoint(x: spec.1, y: AGeo.sand(spec.1) + spec.2))
        }
    }

    private func starterTank() {
        addDecor(.seaweed, x: 120)
        addDecor(.bubbler, x: 215)
        addDecor(.castle, x: 315)
        addDecor(.grass, x: 470)
        addDecor(.starfish, x: 565)
        addDecor(.chest, x: 685)
        addDecor(.anemone, x: 810)
        addDecor(.coral, x: 910)
        addDecor(.shell, x: 168)

        let g = spawn(.goldfish, variant: 0)
        fish[g].snackReadyAt = 3.5
        spawn(.clownfish, variant: 0)
        for _ in 0..<5 { spawn(.tetra, variant: 0) }
        spawn(.puffer, variant: 0)

        // Starter shimmering mystery reef egg resting on the sand bed.
        _ = dropEgg(at: 408, y: AGeo.sand(408), species: .axolotl)

        let starterMoss: [CGFloat] = [0.68, 0.52, 0.18, 0, 0.25, 0.22, 0.64, 0.48, 0.15, 0]
        moss = AquaMossPatch.makeDefault(opacities: starterMoss)
        wasDirty = dirtiness > 0.14
        resolveSandLayout()
    }

    private func restore(_ s: AquaSave) {
        for f in s.fish {
            spawn(f.kind, variant: f.variant, growthStage: f.growthStage, growthBites: f.growthBites, grewUp: f.grewUp)
        }
        for d in s.decor {
            let i = addDecor(d.kind, x: d.x)
            decor[i].flip = d.flip
        }
        eggs = s.eggs.prefix(Self.maxEggs).map { saved in
            let cx = max(AGeo.left + 44, min(AGeo.right - 44, saved.x))
            let egg = AquaEgg(
                id: nextID,
                x: cx,
                y: AGeo.sand(cx),
                falling: false,
                taps: max(0, min(2, saved.taps)),
                palette: saved.palette,
                species: saved.species,
                shimmerPhase: CGFloat.random(in: 0...6)
            )
            nextID += 1
            return egg
        }
        moss = AquaMossPatch.makeDefault(opacities: s.moss.map { CGFloat($0) })
        wasDirty = dirtiness > 0.14
        lightsOn = !s.night
        night = s.night ? 1 : 0
        pump = s.pump
        resolveSandLayout()
    }

    func resolveSandLayout() {
        let resolved = AquaSandLayout.resolve(decor: decor, eggs: eggs, clams: clams, hiddenSpots: hiddenSpots)
        clams = resolved.clams
        hiddenSpots = resolved.hiddenSpots
    }

    func makeSave() -> AquaSave {
        AquaSave(
            fish: fish.map {
                AquaFishSave(kind: $0.kind, variant: $0.variant, growthStage: $0.growthStage, growthBites: $0.growthBites, grewUp: $0.grewUp)
            },
            decor: decor.filter { !$0.held }.map { AquaDecorSave(kind: $0.kind, x: $0.x, flip: $0.flip) },
            moss: moss.map { Float($0.opacity) },
            night: !lightsOn,
            pump: pump,
            eggs: eggs.map { AquaEggSave(x: $0.x, taps: $0.taps, palette: $0.palette, species: $0.species) }
        )
    }

    func save() {
        saveAsync()
    }

    func saveAsync() {
        guard !demo else { return }
        AquaStorage.saveAsync(makeSave())
    }

    // MARK: - Deferred Reward & Particle Helpers

    func queueCoin(_ amount: Int, from origin: CGPoint) {
        guard amount > 0 else { return }
        pendingCoins.append((amount, origin))
        if !isStepping { flushPendingRewards() }
    }

    func flushPendingRewards() {
        if !pendingCoins.isEmpty {
            let coins = pendingCoins
            pendingCoins.removeAll(keepingCapacity: true)
            for (amount, origin) in coins {
                Coins.shared.earn(amount, game: AquariumSim.gameID, from: origin)
            }
        }
        if !pendingStickers.isEmpty {
            let stickers = pendingStickers
            pendingStickers.removeAll(keepingCapacity: true)
            for id in stickers {
                _ = StickerBook.shared.find(game: AquariumSim.gameID, id: id)
            }
        }
        if needsSave {
            needsSave = false
            saveAsync()
        }
        if let next = pendingUIState {
            pendingUIState = nil
            onUIStateChange?(next)
        }
    }

    @discardableResult
    func drainEffectsForTesting() -> AquaDrainedEffects {
        let totalCoins = pendingCoins.reduce(0) { $0 + $1.0 }
        let stickers = pendingStickers
        let saved = needsSave
        flushPendingRewards()
        return AquaDrainedEffects(coins: totalCoins, stickers: stickers, saved: saved)
    }

    func schedulePostFrameFlush() {
        let hasPending = !pendingCoins.isEmpty || !pendingStickers.isEmpty || needsSave || pendingUIState != nil
        guard hasPending, !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flushScheduled = false
            self.flushPendingRewards()
        }
    }

    func emitParticle(_ particle: AquaParticle) {
        if particles.count >= Self.maxParticles {
            if particle.kind == .glow || particle.kind == .sand || particle.kind == .moss { return }
            if let idx = particles.firstIndex(where: { $0.kind == .glow || $0.kind == .sand || $0.kind == .moss || $0.kind == .splash }) {
                particles[idx] = particle
            } else {
                particles[0] = particle
            }
            return
        }
        particles.append(particle)
    }

    private func syncUIStateIfNeeded(force: Bool = false) {
        if force || time - lastCueCheck >= 1.0 {
            lastCueCheck = time
            cachedHungryFish = anyHungry
            cachedDirtyGlass = dirtiness > 0.3
        }
        let next = AquaUIState(
            hasHungryFish: cachedHungryFish,
            hasDirtyGlass: cachedDirtyGlass,
            isCarryingReturnable: isCarryingReturnable,
            isHoveringReturnZone: isHoveringReturnZone,
            submarineActive: submarine.active,
            treatMode: treatMode
        )
        if next != lastEmittedUIState {
            lastEmittedUIState = next
            pendingUIState = next
            if !isStepping { flushPendingRewards() }
        }
    }

    // MARK: - Computed UI cues

    var dirtiness: CGFloat {
        guard !moss.isEmpty else { return 0 }
        return moss.map(\.opacity).reduce(0, +) / CGFloat(moss.count)
    }

    var anyHungry: Bool {
        fish.contains { $0.hungryCue > 0.25 && !$0.caught }
    }

    var isCarryingReturnable: Bool {
        (tool == .net && caught != nil) || decor.contains { $0.held }
    }

    var isHoveringReturnZone: Bool {
        if tool == .net, caught != nil {
            return AGeo.inReturnZone(hold) || AGeo.inReturnZone(toolP)
        }
        if let d = decor.first(where: { $0.held }) {
            let center = CGPoint(x: d.x, y: d.y - d.kind.size.height * 0.5)
            return (hand.map { AGeo.inReturnZone($0) } ?? false) || AGeo.inReturnZone(center)
        }
        return false
    }

    // MARK: - Fish

    @discardableResult
    func spawn(
        _ kind: FishKind,
        variant: Int,
        at p: CGPoint? = nil,
        growthStage: Int = 2,
        growthBites: Int = 0,
        grewUp: Bool = false
    ) -> Int {
        let clampedStage = max(0, min(2, growthStage))
        let growthMult: CGFloat = clampedStage == 0 ? 0.55 : (clampedStage == 1 ? 0.78 : 1.0)
        let s: CGFloat = 0.9 * growthMult
        let half = (kind.length + kind.tailLength) * 0.5 * s
        let lim = AGeo.swim(half: half)
        let x = p?.x ?? CGFloat.random(in: lim.minX...lim.maxX)
        let y = p?.y ?? randomDepth(kind, x: x)
        let rare = variant >= AquaRare.variant ? AquaRare.variant : 0
        var f = AquaFish(
            id: nextID,
            kind: kind,
            variant: rare + (variant - rare) % max(1, kind.variants),
            p: CGPoint(x: x, y: y),
            target: CGPoint(x: x, y: y)
        )
        nextID += 1
        f.growthStage = clampedStage
        f.growthBites = max(0, growthBites)
        f.grewUp = grewUp
        f.dir = Bool.random() ? 1 : -1
        f.facing = f.dir
        f.phase = CGFloat.random(in: 0...6)
        f.z = CGFloat.random(in: 0.1...0.95)
        f.zTarget = f.z
        f.nextBubble = time + Double.random(in: 3...12)
        f.snackReadyAt = clampedStage < 2 ? time + 2.5 : time + Double.random(in: 8...26)
        f.anemoneCooldown = time + Double.random(in: 4...12)
        f.activityCooldown = time + Double.random(in: 4...10)
        fish.append(f)
        return fish.count - 1
    }

    private func randomDepth(_ kind: FishKind, x: CGFloat) -> CGFloat {
        let top = AGeo.waterY + 32
        let bottom = AGeo.sand(x) - kind.height * 0.5 - 20
        let d = CGFloat.random(in: kind.depth)
        return top + (bottom - top) * d
    }

    private func isProtectedFromEviction(_ f: AquaFish) -> Bool {
        f.caught || f.variant >= AquaRare.variant || f.grewUp || f.growthStage < 2
    }

    @discardableResult
    private func evictOneOrdinaryFish() -> Bool {
        let candidate = fish.firstIndex(where: { !isProtectedFromEviction($0) && !$0.kind.isReefBabySpecies })
            ?? fish.firstIndex(where: { !isProtectedFromEviction($0) })
        guard let j = candidate else { return false }
        bye(fish[j].p)
        fish.remove(at: j)
        return true
    }

    func addFish(_ kind: FishKind, x: CGFloat, y: CGFloat) {
        let n = kind.group
        let evictable = fish.filter { !isProtectedFromEviction($0) }.count
        guard fish.count - evictable + n <= AquariumSim.maxFish else {
            AquaSound.shared.play(.bloop, volume: 0.45)
            return
        }
        while fish.count + n > AquariumSim.maxFish {
            if !evictOneOrdinaryFish() { break }
        }
        let cx = max(AGeo.left + 70, min(AGeo.right - 70, x))
        let above = y < surfaceY(cx)
        let y0 = above ? surfaceY(cx) + 8 : min(y, AGeo.sand(cx) - 40)
        let v = AquariumSim.rollVariant((nextID * 7) % max(1, kind.variants))
        for k in 0..<n {
            let i = spawn(kind, variant: v, at: CGPoint(x: cx + CGFloat(k) * 14 - CGFloat(n - 1) * 7, y: y0 + CGFloat(k % 2) * 6))
            fish[i].v = CGVector(dx: CGFloat.random(in: -60...60), dy: above ? CGFloat.random(in: 140...220) : 40)
            fish[i].target = CGPoint(x: cx + CGFloat.random(in: -160...160), y: randomDepth(kind, x: cx))
            fish[i].nextThink = time + 2
        }
        if above {
            splash(at: cx, strength: 1)
        } else {
            AquaSound.shared.play(.blub, volume: 0.6)
        }
        for _ in 0..<10 {
            addBubble(CGPoint(x: cx + CGFloat.random(in: -24...24), y: y0 + CGFloat(Double.random(in: 0...50))), r: CGFloat.random(in: 2...6))
        }
    }

    func isFishSleeping(_ f: AquaFish) -> Bool {
        if case .sleeping = f.activity { return true }
        return false
    }

    private func wakeFish(_ f: inout AquaFish, cooldown: Double = 4.0) {
        if case .sleeping = f.activity {
            f.activity = .cruising
            f.restUntil = -10
            f.activityCooldown = max(f.activityCooldown, time + cooldown)
        } else if case .hiding = f.activity {
            f.activity = .cruising
            f.activityCooldown = max(f.activityCooldown, time + cooldown)
        }
    }

    @discardableResult
    func sendFish(_ fishIndex: Int, toDecor decorIndex: Int, role: AquaDecorAnchorRole) -> Bool {
        guard fish.indices.contains(fishIndex), decor.indices.contains(decorIndex) else { return false }
        let d = decor[decorIndex]
        guard !d.held && !d.falling, let spec = d.kind.anchorSpec(for: role) else { return false }
        switch role {
        case .swimThrough:
            fish[fishIndex].swimThroughDir = fish[fishIndex].p.x <= d.x ? 1 : -1
            fish[fishIndex].activity = .swimmingThrough(decorID: d.id, phase: 0)
            fish[fishIndex].restUntil = -10
        case .hideout:
            fish[fishIndex].activity = .hiding(decorID: d.id, peek: 0, until: time + 6.0)
            fish[fishIndex].restUntil = -10
        case .sleepBed:
            let nest = clampedNestPoint(spec.worldPoint(for: d), for: fish[fishIndex])
            let until = time + 600
            fish[fishIndex].activity = .sleeping(decorID: d.id, nest: nest, until: until)
            fish[fishIndex].restUntil = until
            fish[fishIndex].nextSleepZ = time + 1.0
        }
        return true
    }

    private func clampedNestPoint(_ raw: CGPoint, for f: AquaFish) -> CGPoint {
        let s = f.scale
        let half = (f.kind.length * 0.5 + f.kind.tailLength * 0.4) * s
        let lim = AGeo.swim(half: half)
        let x = max(lim.minX + 12, min(lim.maxX - 12, raw.x))
        let maxY = AGeo.sand(x) - f.kind.height * 0.5 * s - (f.kind == .seahorse ? 6 : 12)
        let y = max(lim.minY + 12, min(maxY, raw.y))
        return CGPoint(x: x, y: y)
    }

    private func pickSleepSpot(for f: AquaFish, index: Int) -> (decorID: Int?, nest: CGPoint) {
        let takenIDs: Set<Int> = Set(fish.compactMap { other in
            guard other.id != f.id else { return nil }
            if case .sleeping(let did, _, _) = other.activity { return did }
            return nil
        })
        let beds: [(AquaDecor, AquaDecorAnchorSpec)] = decor.compactMap { d in
            guard !d.held && !d.falling, let spec = d.kind.anchorSpec(for: .sleepBed) else { return nil }
            return (d, spec)
        }
        if let free = beds
            .filter({ !takenIDs.contains($0.0.id) })
            .min(by: { hypot($0.0.x - f.p.x, $0.0.y - f.p.y) < hypot($1.0.x - f.p.x, $1.0.y - f.p.y) }) {
            return (free.0.id, clampedNestPoint(free.1.worldPoint(for: free.0), for: f))
        }
        if let shared = beds.min(by: { hypot($0.0.x - f.p.x, $0.0.y - f.p.y) < hypot($1.0.x - f.p.x, $1.0.y - f.p.y) }) {
            let offset = CGFloat((index % 3) - 1) * 18
            let pt = CGPoint(x: shared.1.worldPoint(for: shared.0).x + offset, y: shared.1.worldPoint(for: shared.0).y - 8)
            return (shared.0.id, clampedNestPoint(pt, for: f))
        }
        let nookX = max(AGeo.left + 84, min(AGeo.right - 84, f.p.x))
        let nookY = AGeo.sand(nookX) - f.kind.height * 0.5 * f.scale - 18
        return (nil, clampedNestPoint(CGPoint(x: nookX, y: nookY), for: f))
    }

    private func assignNightSleepSpots() {
        var awakeIndices: [Int] = []
        var takenIDs: Set<Int> = []
        for i in fish.indices {
            let f = fish[i]
            guard !f.caught else { continue }
            if case .sleeping(let did, _, _) = f.activity {
                if let did { takenIDs.insert(did) }
                continue
            }
            guard time >= f.activityCooldown,
                  time >= f.fleeUntil,
                  !isRibbonDanceActive,
                  !(f.curious != nil && time < f.curiousUntil),
                  !(f.appetite >= 1 && nearestFood(to: f.p, within: f.kind == .seahorse ? 260 : 480) != nil),
                  nearestHoop(for: f, within: 360) == nil else {
                continue
            }
            awakeIndices.append(i)
        }
        guard !awakeIndices.isEmpty else { return }

        var freeBeds: [(AquaDecor, AquaDecorAnchorSpec)] = decor.compactMap { d in
            guard !d.held && !d.falling && !takenIDs.contains(d.id),
                  let spec = d.kind.anchorSpec(for: .sleepBed) else { return nil }
            return (d, spec)
        }
        var remaining = awakeIndices
        let until = time + 600

        while !remaining.isEmpty && !freeBeds.isEmpty {
            var bestPair: (fishPos: Int, bedPos: Int, dist: CGFloat)?
            for (fiPos, fi) in remaining.enumerated() {
                let fp = fish[fi].p
                for (biPos, bed) in freeBeds.enumerated() {
                    let bp = bed.1.worldPoint(for: bed.0)
                    let d = hypot(bp.x - fp.x, bp.y - fp.y)
                    if bestPair == nil || d < bestPair!.dist {
                        bestPair = (fiPos, biPos, d)
                    }
                }
            }
            guard let pair = bestPair else { break }
            let fi = remaining.remove(at: pair.fishPos)
            let bed = freeBeds.remove(at: pair.bedPos)
            let nest = clampedNestPoint(bed.1.worldPoint(for: bed.0), for: fish[fi])
            fish[fi].activity = .sleeping(decorID: bed.0.id, nest: nest, until: until)
            fish[fi].restUntil = until
            fish[fi].nextSleepZ = time + Double.random(in: 0.4...1.0)
        }

        for fi in remaining {
            let chosen = pickSleepSpot(for: fish[fi], index: fi)
            fish[fi].activity = .sleeping(decorID: chosen.decorID, nest: chosen.nest, until: until)
            fish[fi].restUntil = until
            fish[fi].nextSleepZ = time + Double.random(in: 0.4...1.0)
        }
    }

    private func tryStartDecorActivity(for f: inout AquaFish) {
        let occupiedHideouts: Set<Int> = Set(fish.compactMap { other in
            guard other.id != f.id else { return nil }
            if case .hiding(let did, _, _) = other.activity { return did }
            return nil
        })
        var choices: [(AquaDecor, AquaDecorAnchorRole)] = []
        for d in decor where !d.held && !d.falling {
            guard abs(d.x - f.p.x) < 420 else { continue }
            for spec in d.kind.anchorSpecs {
                if spec.role == .swimThrough {
                    choices.append((d, .swimThrough))
                } else if spec.role == .hideout && !occupiedHideouts.contains(d.id) {
                    choices.append((d, .hideout))
                }
            }
        }
        guard let pick = choices.randomElement() else {
            f.activityCooldown = time + Double.random(in: 5...9)
            return
        }
        if pick.1 == .swimThrough {
            f.swimThroughDir = f.p.x <= pick.0.x ? 1 : -1
            f.activity = .swimmingThrough(decorID: pick.0.id, phase: 0)
        } else {
            f.activity = .hiding(decorID: pick.0.id, peek: 0, until: time + Double.random(in: 4.5...7.5))
        }
    }

    private func stepFish(_ dt: CGFloat) {
        if !lightsOn && night > 0.45 {
            assignNightSleepSpots()
        }
        let sleepy = 1 - 0.45 * night
        var shownHungryCount = fish.filter { $0.hungryCue > 0.2 && !$0.caught }.count

        for i in fish.indices {
            if fish[i].caught {
                fish[i].phase += dt * 2 * .pi * 4.5
                fish[i].amp = 0.45
                fish[i].hungryCue = max(0, fish[i].hungryCue - dt * 4)
                continue
            }
            var f = fish[i]
            let k = f.kind
            let s = f.scale
            let half = (k.length * 0.5 + k.tailLength * 0.4) * s
            let lim = AGeo.swim(half: half)
            let floorY = AGeo.sand(f.p.x) - k.height * 0.5 * s - (k == .seahorse ? 6 : 12)
            var speed = k.cruise * sleepy
            var goal = f.target
            var urgent = false
            var feeding = false
            var isSleepingSettled = false
            var isHidingPeeking = false
            var hoopIdx: Int?
            var completedSwimThrough: (AquaDecorKind, CGPoint)?

            if lightsOn || night < 0.35 {
                if case .sleeping = f.activity {
                    f.activity = .cruising
                    f.restUntil = -10
                    f.activityCooldown = time + 2.5
                }
            }

            let eligibleHungry = time >= f.snackReadyAt && f.appetite >= 2.5 && time > f.fleeUntil && !isFishSleeping(f)
            if eligibleHungry && (f.hungryCue > 0.2 || shownHungryCount < 3) {
                if f.hungryCue <= 0.2 { shownHungryCount += 1 }
                f.hungryCue = min(1, f.hungryCue + dt * 2.2)
            } else {
                f.hungryCue = max(0, f.hungryCue - dt * 3.0)
            }

            if f.appetite >= 1, let j = nearestFood(to: f.p, within: k == .seahorse ? 260 : 480) {
                wakeFish(&f, cooldown: 6.0)
                let flake = food[j].p
                let nose = mouth(f)
                let side: CGFloat = abs(flake.x - f.p.x) > half ? (flake.x > f.p.x ? 1 : -1) : f.dir
                goal = CGPoint(x: flake.x - side * abs(nose.x - f.p.x), y: flake.y - (nose.y - f.p.y))
                if abs(flake.x - f.p.x) < half * 1.6 { f.dir = flake.x >= f.p.x ? 1 : -1 }
                speed = min(k.topSpeed, k.cruise * 2.6 + 34)
                urgent = true
                feeding = true
            } else if time < f.fleeUntil {
                wakeFish(&f, cooldown: 5.0)
                if case .swimmingThrough = f.activity { f.activity = .cruising }
                goal = CGPoint(x: f.p.x + f.flee.dx * 240, y: f.p.y + f.flee.dy * 120)
                speed = k.topSpeed
                urgent = true
            } else if isRibbonDanceActive {
                wakeFish(&f, cooldown: 5.0)
                if case .swimmingThrough = f.activity { f.activity = .cruising }
                let count = max(1, CGFloat(fish.count))
                let a = CGFloat(time - ribbonDanceStart) * 1.45 + CGFloat(i) / count * 2 * .pi
                let sA = sin(a)
                let hx = 512 + 195 * sA * sA * sA
                let hy = 368 - (120 * cos(a) - 46 * cos(2 * a) - 18 * cos(3 * a))
                goal = CGPoint(
                    x: max(lim.minX + 18, min(lim.maxX - 18, hx)),
                    y: max(lim.minY + 12, min(floorY - 12, hy))
                )
                speed = min(k.topSpeed, max(k.cruise * 1.9, 108))
                urgent = true
            } else if let hi = nearestHoop(for: f, within: 360) {
                wakeFish(&f, cooldown: 5.0)
                if case .swimmingThrough = f.activity { f.activity = .cruising }
                let hoop = hoops[hi]
                let throughDir: CGFloat = abs(f.p.x - hoop.p.x) > 14 ? (f.p.x < hoop.p.x ? 1 : -1) : f.dir
                goal = CGPoint(x: hoop.p.x + throughDir * 56, y: hoop.p.y)
                speed = min(k.topSpeed, k.cruise * 2.2 + 40)
                urgent = true
                hoopIdx = hi
            } else if submarine.active, hypot(submarine.p.x - f.p.x, submarine.p.y - f.p.y) < (isFishSleeping(f) ? 110 : 260) {
                wakeFish(&f, cooldown: 4.0)
                let wakeOffset = 68 + CGFloat(f.id % 3) * 28
                let lane = (CGFloat(f.id % 5) - 2) * 18
                goal = CGPoint(
                    x: submarine.p.x - submarine.facing * wakeOffset,
                    y: submarine.p.y + lane + sin(CGFloat(time) * 3.2 + CGFloat(f.id)) * 12
                )
                speed = min(k.topSpeed, k.cruise * 1.85 + 24)
            } else if tool == .hoop, AGeo.inWater(toolP), hypot(toolP.x - f.p.x, toolP.y - f.p.y) < 300 {
                let a = CGFloat(f.id) * 1.9
                goal = CGPoint(x: toolP.x + cos(a) * 54, y: toolP.y + sin(a) * 26)
                speed = k.cruise * 1.5
            } else if let c = f.curious, time < f.curiousUntil {
                wakeFish(&f, cooldown: 5.0)
                let a = CGFloat(f.id) * 2.4
                goal = CGPoint(x: c.x + cos(a) * (48 + CGFloat(f.id % 3) * 18), y: c.y + sin(a) * 30)
                speed = k.cruise * 1.3
                if hypot(goal.x - f.p.x, goal.y - f.p.y) < 30 {
                    f.gulp = max(f.gulp, 0.5 + 0.5 * sin(CGFloat(time) * 9 + CGFloat(f.id)))
                    if k == .seahorse || k == .puffer { f.dir = c.x > f.p.x ? 1 : -1 }
                }
            } else if !lightsOn && night > 0.45 {
                if case .sleeping(let decorID, var nest, let until) = f.activity {
                    if let did = decorID {
                        if let d = decor.first(where: { $0.id == did && !$0.held && !$0.falling }),
                           let spec = d.kind.anchorSpec(for: .sleepBed) {
                            nest = clampedNestPoint(spec.worldPoint(for: d), for: f)
                            f.activity = .sleeping(decorID: did, nest: nest, until: until)
                        } else {
                            let fresh = pickSleepSpot(for: f, index: i)
                            nest = fresh.nest
                            f.activity = .sleeping(decorID: fresh.decorID, nest: nest, until: until)
                        }
                    }
                    f.restUntil = max(f.restUntil, until)
                    goal = nest
                    let distToNest = hypot(nest.x - f.p.x, nest.y - f.p.y)
                    if distToNest > 20 {
                        speed = max(28, k.cruise * 0.9)
                    } else {
                        speed = 0
                        isSleepingSettled = true
                        if time >= f.nextSleepZ {
                            f.nextSleepZ = time + Double.random(in: 1.3...2.1)
                            emitParticle(
                                AquaParticle(
                                    kind: .sleepZ,
                                    p: CGPoint(x: f.p.x + f.facing.sign1 * 10, y: f.p.y - k.height * 0.4 * s - 8),
                                    v: CGVector(dx: CGFloat.random(in: -6...6), dy: -18),
                                    life: 2.6,
                                    size: 11,
                                    color: ARGB(0xDCE8FF)
                                )
                            )
                        }
                    }
                } else if time >= f.activityCooldown {
                    let chosen = pickSleepSpot(for: f, index: i)
                    let until = time + 600
                    f.activity = .sleeping(decorID: chosen.decorID, nest: chosen.nest, until: until)
                    f.restUntil = until
                    f.nextSleepZ = time + Double.random(in: 0.4...1.0)
                    goal = chosen.nest
                    speed = max(28, k.cruise * 0.9)
                } else {
                    f.curious = nil
                    if time > f.nextThink || hypot(goal.x - f.p.x, goal.y - f.p.y) < 24 {
                        f.target = pickTarget(f)
                        f.nextThink = time + Double.random(in: 3...8)
                        f.zTarget = CGFloat.random(in: 0.05...1)
                        goal = f.target
                    }
                    if time < f.restUntil { speed = 0 }
                }
            } else if case .swimmingThrough(let decorID, let phase) = f.activity {
                if let d = decor.first(where: { $0.id == decorID && !$0.held && !$0.falling }),
                   let spec = d.kind.anchorSpec(for: .swimThrough) {
                    let entry = clampedNestPoint(spec.worldEntry(for: d, direction: f.swimThroughDir), for: f)
                    let exit = clampedNestPoint(spec.worldExit(for: d, direction: f.swimThroughDir), for: f)
                    let mid = clampedNestPoint(spec.worldPoint(for: d), for: f)
                    if phase == 0 {
                        goal = entry
                        speed = min(k.topSpeed, k.cruise * 1.55 + 24)
                        urgent = true
                        if hypot(entry.x - f.p.x, entry.y - f.p.y) < 32 {
                            f.activity = .swimmingThrough(decorID: decorID, phase: 1)
                        }
                    } else {
                        goal = exit
                        speed = min(k.topSpeed, k.cruise * 1.75 + 28)
                        urgent = true
                        if CGFloat.random(in: 0...1) < dt * 10 {
                            addBubble(CGPoint(x: f.p.x, y: f.p.y), r: CGFloat.random(in: 1.8...3.8))
                        }
                        let passed = f.swimThroughDir > 0 ? f.p.x >= exit.x - 16 : f.p.x <= exit.x + 16
                        if passed || hypot(exit.x - f.p.x, exit.y - f.p.y) < 30 {
                            f.activity = .cruising
                            f.activityCooldown = time + Double.random(in: 8...14)
                            f.happy = time
                            f.target = pickTarget(f)
                            f.nextThink = time + 2.5
                            for b in 0..<4 {
                                addBubble(CGPoint(x: mid.x + CGFloat(b * 8 - 12), y: mid.y - CGFloat(b) * 5), r: CGFloat.random(in: 2.2...4.4))
                            }
                            emitParticle(
                                AquaParticle(
                                    kind: .sparkle,
                                    p: mid,
                                    v: CGVector(dx: 0, dy: -14),
                                    life: 0.75,
                                    size: 14,
                                    color: ARGB(0xFFE69A)
                                )
                            )
                            completedSwimThrough = (d.kind, mid)
                        }
                    }
                } else {
                    f.activity = .cruising
                }
            } else if case .hiding(let decorID, var peek, let until) = f.activity {
                if time < until,
                   let d = decor.first(where: { $0.id == decorID && !$0.held && !$0.falling }),
                   let spec = d.kind.anchorSpec(for: .hideout) {
                    let hidePoint = clampedNestPoint(spec.worldPoint(for: d), for: f)
                    let distHide = hypot(hidePoint.x - f.p.x, hidePoint.y - f.p.y)
                    goal = hidePoint
                    if distHide > 20 {
                        speed = max(34, k.cruise * 1.35)
                    } else {
                        speed = 0
                        isHidingPeeking = true
                        peek = min(1, peek + dt * 2.5)
                        f.activity = .hiding(decorID: decorID, peek: peek, until: until)
                        f.dir = d.x < 512 ? 1 : -1
                    }
                } else {
                    f.activity = .cruising
                    f.activityCooldown = time + Double.random(in: 9...16)
                    f.target = pickTarget(f)
                }
            } else if k == .clownfish, let home = decor.first(where: { $0.kind == .anemone && !$0.held && !$0.falling }) {
                if time > f.anemoneCooldown && time > f.anemoneUntil {
                    f.anemoneUntil = time + 6.5
                    f.anemoneCooldown = time + 20
                }
                if time < f.anemoneUntil {
                    let peek = sin(CGFloat(time) * 1.2 + CGFloat(f.id))
                    goal = CGPoint(x: home.x + 36 * peek, y: home.y - 46 - 14 * abs(peek))
                    speed = k.cruise * 1.35
                } else {
                    f.curious = nil
                    if time > f.nextThink || hypot(goal.x - f.p.x, goal.y - f.p.y) < 24 {
                        f.target = pickTarget(f)
                        f.nextThink = time + Double.random(in: 3...8)
                        f.zTarget = CGFloat.random(in: 0.05...1)
                        goal = f.target
                    }
                }
            } else {
                f.curious = nil
                if time >= f.activityCooldown && night < 0.45 && time >= f.restUntil {
                    tryStartDecorActivity(for: &f)
                }
                if time > f.nextThink || hypot(goal.x - f.p.x, goal.y - f.p.y) < 24 {
                    f.target = pickTarget(f)
                    f.nextThink = time + Double.random(in: 3...8)
                    f.zTarget = CGFloat.random(in: 0.05...1)
                    goal = f.target
                }
                if time < f.restUntil { speed = 0 }
            }

            var dx = goal.x - f.p.x
            var dy = goal.y - f.p.y
            let dist = max(1, hypot(dx, dy))
            let arrive = (feeding || f.activity != .cruising) ? min(1, dist / 24) : (urgent ? 1 : min(1, dist / 90))
            dx = dx / dist * speed * arrive
            let verticalFactor: CGFloat
            if k == .seahorse {
                verticalFactor = 1.0
            } else if hoopIdx != nil || f.activity != .cruising {
                verticalFactor = 0.9
            } else {
                verticalFactor = 0.6
            }
            dy = dy / dist * speed * arrive * verticalFactor

            var cx: CGFloat = 0, cy: CGFloat = 0, ax: CGFloat = 0, ay: CGFloat = 0, n: CGFloat = 0
            if !isSleepingSettled && !isHidingPeeking {
                for j in fish.indices where j != i && !fish[j].caught {
                    let o = fish[j]
                    let ox = f.p.x - o.p.x, oy = f.p.y - o.p.y
                    let d = hypot(ox, oy)
                    let room = (k.length + o.kind.length) * 0.42 * s
                    if d < room, d > 0.01 {
                        let push = (1 - d / room) * speed * 1.1
                        dx += ox / d * push
                        dy += oy / d * push * 0.7
                    }
                    if k.schools && o.kind == k && d < 220 {
                        cx += o.p.x; cy += o.p.y; ax += o.v.dx; ay += o.v.dy; n += 1
                    }
                }
            }
            if n > 0 && !urgent {
                dx += ((cx / n - f.p.x) * 0.5 + (ax / n - f.v.dx) * 0.6)
                dy += ((cy / n - f.p.y) * 0.4 + (ay / n - f.v.dy) * 0.4)
            }

            for d in decor where d.kind == .bubbler && !d.held && !d.falling && time < d.boostUntil {
                if abs(f.p.x - d.x) < 82 && f.p.y < d.y && f.p.y > AGeo.waterY + 42 {
                    dy -= 210
                    dx += sin(CGFloat(time) * 8.5 + CGFloat(f.id)) * 95
                    if time - f.happy > 0.9 {
                        f.happy = time
                        f.flipStart = time
                        addBubble(mouth(f), r: 3.5)
                    }
                }
            }

            let edge: CGFloat = 70
            if f.activity == .cruising {
                if f.p.x < lim.minX + edge { dx += (lim.minX + edge - f.p.x) * 2.2 }
                if f.p.x > lim.maxX - edge { dx -= (f.p.x - (lim.maxX - edge)) * 2.2 }
            }
            let topY = feeding ? AGeo.waterY + k.height * 0.3 * s + 2 : lim.minY
            let bottomY = feeding ? AGeo.sand(f.p.x) - k.height * 0.42 * s - 4 : floorY
            if !feeding && f.activity == .cruising {
                if f.p.y < lim.minY + 30 { dy += (lim.minY + 30 - f.p.y) * 2 }
                if f.p.y > floorY - 30 { dy -= (f.p.y - (floorY - 30)) * 2 }
            }

            let maxA = (urgent ? 2.8 : 1.4) * k.topSpeed + 60
            var sx = (dx - f.v.dx) * 3, sy = (dy - f.v.dy) * 3
            let sa = hypot(sx, sy)
            if sa > maxA { sx *= maxA / sa; sy *= maxA / sa }
            f.v.dx += sx * dt
            f.v.dy += sy * dt
            f.accel += (min(sa, maxA) - f.accel) * min(1, dt * 6)
            let sp = hypot(f.v.dx, f.v.dy)
            let cap = k.topSpeed * (f.puff > 0.5 ? 0.35 : 1)
            if sp > cap { f.v.dx *= cap / sp; f.v.dy *= cap / sp }
            let drag = exp(-dt * (isSleepingSettled || isHidingPeeking ? 4.2 : 0.6))
            f.v.dx *= drag
            f.v.dy *= drag
            f.p.x += f.v.dx * dt
            f.p.y += f.v.dy * dt
            if f.p.x < lim.minX { f.p.x = lim.minX; f.v.dx = abs(f.v.dx) * 0.3 }
            if f.p.x > lim.maxX { f.p.x = lim.maxX; f.v.dx = -abs(f.v.dx) * 0.3 }
            if f.p.y < topY { f.p.y = topY; f.v.dy = abs(f.v.dy) * 0.3 }
            if f.p.y > bottomY { f.p.y = bottomY; f.v.dy = -abs(f.v.dy) * 0.3 }

            if !isHidingPeeking && (!feeding || dist > half * 1.6) {
                if f.v.dx > 9 { f.dir = 1 } else if f.v.dx < -9 { f.dir = -1 }
            }
            f.facing += (f.dir - f.facing) * min(1, dt * (urgent ? 9 : 5.5))

            let speedNow = hypot(f.v.dx, f.v.dy)
            let hz: CGFloat = isSleepingSettled
                ? 0.55
                : ((k == .seahorse ? 5 : 1.4) + speedNow * 0.02 + f.accel * 0.002)
            f.phase += 2 * .pi * hz * dt
            let wantAmp: CGFloat = isSleepingSettled
                ? 0.05
                : ((k == .seahorse ? 0.3 : 0.13) + min(0.42, speedNow * 0.0012 + f.accel * 0.0011))
            f.amp += (wantAmp - f.amp) * min(1, dt * 4)
            f.z += (f.zTarget - f.z) * min(1, dt * 0.25)
            f.gulp = max(0, f.gulp - dt * 3)
            let appetiteRate: CGFloat = f.growthStage < 2 ? 1.0 / 2.2 : 1.0 / 9.0
            if f.appetite < 5 { f.appetite = min(5, f.appetite + dt * appetiteRate) }

            let puffWant: CGFloat = time < f.puffUntil ? 1 : 0
            f.puffV += ((puffWant - f.puff) * 90 - f.puffV * 9) * dt
            f.puff = max(0, min(1.12, f.puff + f.puffV * dt))

            if time > f.nextBubble && !isSleepingSettled {
                f.nextBubble = time + Double.random(in: 5...14)
                addBubble(mouth(f), r: CGFloat.random(in: 1.5...3))
            }

            if let hi = hoopIdx, hoops.indices.contains(hi) {
                let hoop = hoops[hi]
                if hypot(f.p.x - hoop.p.x, f.p.y - hoop.p.y) < hoop.radius * 0.85 {
                    completeHoopTrick(fish: &f, hoopIndex: hi)
                }
            }

            fish[i] = f
            if let (decorKind, mid) = completedSwimThrough {
                fulfillWishIfMatching({ wish in
                    if case .decorPlay(let wk, .swimThrough) = wish { return wk == decorKind }
                    return false
                }, at: mid)
            }
            if feeding { eat(i) }
        }
    }

    private func pickTarget(_ f: AquaFish) -> CGPoint {
        let k = f.kind
        if k == .seahorse, Bool.random(), let w = decor.first(where: { $0.kind == .seaweed || $0.kind == .grass }), !w.falling, !w.held {
            return CGPoint(x: w.x + CGFloat.random(in: -14...14), y: w.y - w.kind.size.height * CGFloat.random(in: 0.35...0.6))
        }
        let half = (k.length + k.tailLength) * 0.5
        let lim = AGeo.swim(half: half)
        let reach = CGFloat.random(in: 180...520) * (Bool.random() ? 1 : -1)
        let x = max(lim.minX + 40, min(lim.maxX - 40, f.p.x + reach))
        var y = randomDepth(k, x: x)
        y = f.p.y + (y - f.p.y) * CGFloat.random(in: 0.3...1)
        if night > 0.5 { y = max(y, AGeo.waterY + (AGeo.sand(x) - AGeo.waterY) * 0.55) }
        return CGPoint(x: x, y: y)
    }

    func mouth(_ f: AquaFish) -> CGPoint {
        let s = f.scale
        if f.kind == .seahorse {
            return CGPoint(x: f.p.x + f.dir * 22 * s, y: f.p.y - 22 * s)
        }
        let pitch = fishPitch(f)
        let r = f.kind.length * 0.5 * s * (1 + f.puff * 0.15)
        return CGPoint(x: f.p.x + f.facing.sign1 * cos(pitch) * r, y: f.p.y + sin(pitch) * r)
    }

    func fishPitch(_ f: AquaFish) -> CGFloat {
        if f.kind == .seahorse { return 0 }
        let a = atan2(f.v.dy, max(abs(f.v.dx), 20))
        return max(-0.45, min(0.45, a * 0.7))
    }

    private func nearestFood(to p: CGPoint, within: CGFloat) -> Int? {
        var best: Int?
        var bd = within * within
        for j in food.indices where food[j].state != .air {
            let maxSettledAge: CGFloat = food[j].kind == .pearls ? 18 : 10
            if food[j].state == .settled && food[j].age > maxSettledAge { continue }
            let dx = food[j].p.x - p.x, dy = food[j].p.y - p.y
            let d = dx * dx + dy * dy
            if d < bd { bd = d; best = j }
        }
        return best
    }

    private func eat(_ i: Int) {
        guard fish[i].appetite >= 1 else { return }
        let m = mouth(fish[i])
        let reach = max(14 + 10 * fish[i].scale, fish[i].kind.height * 0.45 * fish[i].scale + 8)
        guard let j = food.indices.first(where: { food[$0].state != .air && hypot(food[$0].p.x - m.x, food[$0].p.y - m.y) < reach }) else { return }
        let eaten = food[j]
        let fp = eaten.p
        let wasHungry = fish[i].hungryCue > 0.15
        food.remove(at: j)
        fish[i].appetite = max(0, fish[i].appetite - 1)
        fish[i].gulp = 1
        fish[i].happy = time
        fish[i].snackReadyAt = fish[i].growthStage < 2 ? time + 4 : time + Double.random(in: 24...42)
        fish[i].hungryCue = 0
        AquaSound.shared.play(.gulp, volume: 0.55, gap: 0.14)
        if fp.y < surfaceY(fp.x) + 26 {
            disturb(fp.x, -3, width: 2)
            AquaSound.shared.play(.bloop, volume: 0.35, gap: 0.16)
        }
        if eaten.kind == .pearls {
            fish[i].stardustUntil = time + 6.0
            for k in 0..<5 {
                let a = CGFloat(k) / 5 * 2 * .pi
                emitParticle(
                    AquaParticle(
                        kind: .sparkle,
                        p: CGPoint(x: m.x + cos(a) * 20, y: m.y + sin(a) * 16),
                        v: CGVector(dx: cos(a) * 14, dy: -16),
                        life: 0.7,
                        size: 11,
                        color: k % 2 == 0 ? ARGB(0xFFE69A) : ARGB(0xE8C8FF)
                    )
                )
            }
            fulfillWishIfMatching({ $0 == .pearlPellet }, at: m)
        }
        if wasHungry || Int.random(in: 0..<2) == 0 {
            emitParticle(
                AquaParticle(
                    kind: .heart,
                    p: CGPoint(x: m.x, y: m.y - 16),
                    v: CGVector(dx: CGFloat.random(in: -12...12), dy: -44),
                    life: 1.25,
                    size: 15,
                    color: ARGB(0xFF7FAE)
                )
            )
        }

        // Real growth loop: 3 bites grows baby (0) -> kid (1) -> shimmering full-size adult (2).
        if fish[i].growthStage < 2 {
            fish[i].growthBites += 1
            fish[i].appetite = max(2, fish[i].appetite)
            if fish[i].growthBites >= 3 {
                fish[i].growthBites = 0
                fish[i].growthStage += 1
                if fish[i].growthStage == 2 { fish[i].grewUp = true }
                fish[i].flipStart = time
                fish[i].happy = time
                AquaSound.shared.play(.chime, volume: 0.76, gap: 0.25)
                for k in 0..<8 {
                    let a = CGFloat(k) / 8 * 2 * .pi
                    emitParticle(
                        AquaParticle(
                            kind: .sparkle,
                            p: CGPoint(x: fish[i].p.x + cos(a) * 28, y: fish[i].p.y + sin(a) * 22),
                            v: CGVector(dx: cos(a) * 18, dy: -28),
                            life: 0.9,
                            size: 15,
                            color: ARGB(0xFFE066)
                        )
                    )
                }
                queueCoin(2, from: fish[i].p)
                if !demo { needsSave = true }
            }
        }

        feedEatenCount += 1
        if feedEatenCount >= 3 {
            feedEatenCount = 0
            spawnBabyFish(near: m)
            AquaSound.shared.play(.chime, volume: 0.65, gap: 0.25)
            for k in 0..<8 {
                let a = CGFloat(k) / 8 * 2 * .pi
                emitParticle(
                    AquaParticle(
                        kind: .sparkle,
                        p: CGPoint(x: m.x + cos(a) * 32, y: m.y + sin(a) * 24),
                        v: .zero,
                        life: 0.8,
                        size: 14,
                        color: ARGB(0xFFE69A)
                    )
                )
            }
            if time - lastFeedRewardAt >= 8 {
                lastFeedRewardAt = time
                queueCoin(3, from: m)
            }
        }
    }

    // MARK: - Underwater Bubble Hoops

    @discardableResult
    func spawnBubbleHoop(at p: CGPoint) -> Int {
        let x = max(AGeo.left + 90, min(AGeo.right - 90, p.x))
        let maxY = AGeo.sand(x) - 82
        let y = max(AGeo.waterY + 72, min(maxY, p.y))
        while hoops.count >= 3 {
            let old = hoops.removeFirst()
            bye(old.p)
        }
        let vx: CGFloat = x < 512 ? 24 : -24
        let hoop = BubbleHoop(
            id: nextID,
            p: CGPoint(x: x, y: y),
            vx: vx,
            baseY: y,
            phase: CGFloat.random(in: 0...6),
            shimmer: 0.7
        )
        nextID += 1
        hoops.append(hoop)
        for k in 0..<10 {
            let a = CGFloat(k) / 10 * 2 * .pi
            addBubble(CGPoint(x: x + cos(a) * 20, y: y + sin(a) * 42), r: CGFloat.random(in: 2.2...4.8))
        }
        AquaSound.shared.play(.bloop, volume: 0.6)
        AquaSound.shared.play(.chime, volume: 0.42, gap: 0.2)
        return hoops.count - 1
    }

    private func nearestHoop(for f: AquaFish, within: CGFloat) -> Int? {
        var best: Int?
        var bd = within * within
        for idx in hoops.indices {
            guard !hoops[idx].passedFishIDs.contains(f.id) else { continue }
            let dx = hoops[idx].p.x - f.p.x, dy = hoops[idx].p.y - f.p.y
            let d = dx * dx + dy * dy
            if d < bd { bd = d; best = idx }
        }
        return best
    }

    private func completeHoopTrick(fish f: inout AquaFish, hoopIndex hi: Int) {
        hoops[hi].passedFishIDs.insert(f.id)
        hoops[hi].tricks += 1
        hoops[hi].shimmer = 1
        let hp = hoops[hi].p
        f.flipStart = time
        f.happy = time
        f.gulp = 0.8
        let boostDir: CGFloat = f.v.dx == 0 ? f.dir : f.v.dx.sign1
        f.v.dx = boostDir * max(abs(f.v.dx), f.kind.cruise * 1.9)
        f.target = pickTarget(f)
        f.nextThink = time + 2.5

        for k in 0..<8 {
            let a = CGFloat(k) / 8 * 2 * .pi
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: hp.x + cos(a) * 34, y: hp.y + sin(a) * 44),
                    v: .zero,
                    life: 0.75 + CGFloat(k % 3) * 0.12,
                    size: 14,
                    color: k % 2 == 0 ? ARGB(0xFFE69A) : ARGB(0xFFFFFF)
                )
            )
        }
        for k in 0..<2 {
            emitParticle(
                AquaParticle(
                    kind: .heart,
                    p: CGPoint(x: hp.x + CGFloat(k * 22 - 11), y: hp.y - 26),
                    v: CGVector(dx: CGFloat(k * 16 - 8), dy: -48),
                    life: 1.3,
                    size: 16,
                    color: ARGB(0xFF8FB8)
                )
            )
        }
        for k in 0..<6 {
            let a = CGFloat(k) / 6 * 2 * .pi
            addBubble(CGPoint(x: hp.x + cos(a) * 18, y: hp.y + sin(a) * 36), r: CGFloat.random(in: 2.5...5.5))
        }
        AquaSound.shared.play(.chime, volume: 0.68, gap: 0.25)
        AquaSound.shared.play(.blub, volume: 0.55, gap: 0.14)
        if time - lastHoopCoinAt >= Self.coinCooldown {
            lastHoopCoinAt = time
            queueCoin(2, from: hp)
        }
        fulfillWishIfMatching({ $0 == .hoopTrick }, at: hp)
    }

    private func stepHoops(_ dt: CGFloat) {
        var write = 0
        for read in 0..<hoops.count {
            var h = hoops[read]
            h.age += dt
            if h.age >= h.life {
                bye(h.p)
                continue
            }
            h.p.x += h.vx * dt
            if h.p.x < AGeo.left + 88 { h.p.x = AGeo.left + 88; h.vx = abs(h.vx) }
            if h.p.x > AGeo.right - 88 { h.p.x = AGeo.right - 88; h.vx = -abs(h.vx) }
            let bob = sin(h.age * 1.5 + h.phase) * 14
            h.p.y = max(AGeo.waterY + 70, min(AGeo.sand(h.p.x) - 80, h.baseY + bob))
            h.shimmer = max(0, h.shimmer - dt * 1.6)
            if CGFloat.random(in: 0...1) < dt * 4 {
                let a = CGFloat.random(in: 0...(2 * .pi))
                addBubble(CGPoint(x: h.p.x + cos(a) * h.radius * 0.42, y: h.p.y + sin(a) * h.radius), r: CGFloat.random(in: 1.5...3.2))
            }
            hoops[write] = h
            write += 1
        }
        if write < hoops.count {
            hoops.removeSubrange(write..<hoops.count)
        }
    }

    private func tapBubbleHoop(_ p: CGPoint) -> Bool {
        for i in hoops.indices.reversed() {
            let h = hoops[i]
            if hypot(h.p.x - p.x, h.p.y - p.y) < h.radius + 16 {
                hoops[i].shimmer = 1
                hoops[i].passedFishIDs.removeAll()
                hoops[i].age = min(hoops[i].age, hoops[i].life * 0.4)
                for k in 0..<8 {
                    let a = CGFloat(k) / 8 * 2 * .pi
                    addBubble(CGPoint(x: h.p.x + cos(a) * 18, y: h.p.y + sin(a) * 40), r: CGFloat.random(in: 2...5))
                }
                AquaSound.shared.play(.chime, volume: 0.55)
                return true
            }
        }
        return false
    }

    // MARK: - Food

    private static let flakeLimit = 48

    func toggleTreatMode() {
        treatMode = treatMode == .flakes ? .pearls : .flakes
        Sound.shared.play(.pop, volume: 0.65)
        Sound.shared.play(.sparkle, volume: 0.45)
        syncUIStateIfNeeded()
    }

    func feed(at point: CGPoint) {
        guard point.x >= AGeo.left, point.x <= AGeo.right,
              point.y >= AGeo.rimY - 40, point.y <= AGeo.bottomY else { return }
        let x = max(AGeo.left + 24, min(AGeo.right - 24, point.x))
        let excess = food.count + 6 - Self.flakeLimit
        if excess > 0 { food.removeFirst(excess) }
        for offset in [-20, -12, -4, 4, 12, 20] {
            let dx = CGFloat(offset)
            addFlake(
                at: CGPoint(x: x + dx, y: surfaceY(x) - 10 - abs(dx) * 0.6),
                v: CGVector(dx: dx * 1.3, dy: 45),
                kind: treatMode
            )
        }
        disturb(x, 2.5, width: 2)
        AquaSound.shared.play(.shake, volume: 0.55, gap: 0.14)
    }

    func addFlake(at p: CGPoint, v: CGVector, kind: AquaTreatMode? = nil) {
        guard food.count < Self.flakeLimit else { return }
        let mode = kind ?? treatMode
        let sy = surfaceY(p.x)
        let state: FoodState = p.y >= sy ? .sinking : .air
        food.append(
            AquaFood(
                p: p,
                v: v,
                state: state,
                floatFor: mode == .pearls ? 0 : CGFloat.random(in: 0.8...2.2),
                hue: Int.random(in: 0..<4),
                rot: CGFloat.random(in: 0...6),
                spin: CGFloat.random(in: -3...3),
                seed: CGFloat.random(in: 0...6),
                kind: mode
            )
        )
        lastFed = time
    }

    private func stepFood(_ dt: CGFloat) {
        var write = 0
        for read in 0..<food.count {
            var f = food[read]
            f.age += dt
            let sy = surfaceY(f.p.x)
            switch f.state {
            case .air:
                f.v.dy += AquariumSim.gravity * dt
                f.p.x += f.v.dx * dt
                f.p.y += f.v.dy * dt
                f.rot += f.spin * dt
                if f.p.y >= sy {
                    f.age = 0
                    f.p.y = sy
                    if f.kind == .pearls {
                        // Glowing Pearl Pellets sink gently straight down to bottom swimmers & sea bunnies.
                        f.state = .sinking
                        f.v = CGVector(dx: f.v.dx * 0.12, dy: 42)
                    } else {
                        f.state = .floating
                        f.v = CGVector(dx: f.v.dx * 0.2, dy: 0)
                    }
                    disturb(f.p.x, 1.2, width: 1)
                    AquaSound.shared.play(.plop, volume: 0.25, gap: 0.14)
                }
            case .floating:
                f.p.y = sy + 1
                f.v.dx *= exp(-dt * 1.5)
                f.p.x += f.v.dx * dt + sin(CGFloat(time) * 1.3 + f.seed) * 4 * dt
                f.rot += sin(CGFloat(time) + f.seed) * dt * 0.5
                if f.age > f.floatFor { f.state = .sinking; f.v = CGVector(dx: 0, dy: 6) }
            case .sinking:
                let fall: CGFloat = f.kind == .pearls ? (54 + f.seed * 1.5) : (26 + f.seed * 2)
                f.v.dy += (fall - f.v.dy) * min(1, dt * 2.4)
                f.p.y += f.v.dy * dt
                let drift: CGFloat = f.kind == .pearls ? 6 : 12
                f.p.x += sin(f.age * 2.6 + f.seed) * drift * dt
                f.rot = sin(f.age * 2.6 + f.seed) * 0.8
                let ground = AGeo.sand(f.p.x) - 2
                if f.p.y >= ground { f.p.y = ground; f.state = .settled; f.age = 0 }
            case .settled:
                let settleLimit: CGFloat = f.kind == .pearls ? 20 : 14
                if f.age > settleLimit { continue }
            }
            f.p.x = max(AGeo.left + 4, min(AGeo.right - 4, f.p.x))
            food[write] = f
            write += 1
        }
        if write < food.count {
            food.removeSubrange(write..<food.count)
        }
    }

    // MARK: - Bubbles

    func addBubble(_ p: CGPoint, r: CGFloat, back: Bool = false) {
        guard bubbles.count < 240 else { return }
        bubbles.append(AquaBubble(p: p, r: r, vy: -10, phase: CGFloat.random(in: 0...6), back: back))
    }

    private func stepBubbles(_ dt: CGFloat) {
        var write = 0
        var pops = 0
        for read in 0..<bubbles.count {
            var b = bubbles[read]
            let rise = min(185, 34 + b.r * 13)
            b.vy += (-rise - b.vy) * min(1, dt * 3)
            b.phase += dt * (4 + 26 / max(1.5, b.r))
            b.p.x += sin(b.phase) * b.r * 2.4 * dt
            b.p.y += b.vy * dt
            b.r *= 1 + dt * 0.012
            let top = surfaceY(b.p.x)
            if b.p.y - b.r * 0.3 <= top {
                pops += 1
                disturb(b.p.x, -min(2.5, b.r * 0.22), width: 1)
                if b.r > 2.2 {
                    emitParticle(AquaParticle(kind: .ring, p: CGPoint(x: b.p.x, y: top), v: .zero, life: 0.35, size: b.r * 1.6, color: ARGB(0xFFFFFF)))
                }
                if b.r > 4.5 {
                    for _ in 0..<2 {
                        emitParticle(
                            AquaParticle(
                                kind: .splash,
                                p: CGPoint(x: b.p.x, y: top - 2),
                                v: CGVector(dx: CGFloat.random(in: -40...40), dy: CGFloat.random(in: -160 ... -70)),
                                life: 0.8,
                                size: 1.6,
                                color: ARGB(0xCFF1FF)
                            )
                        )
                    }
                }
                continue
            }
            bubbles[write] = b
            write += 1
        }
        if write < bubbles.count {
            bubbles.removeSubrange(write..<bubbles.count)
        }
        if pops > 0 { AquaSound.shared.play(.pop, volume: Float(min(0.45, 0.12 + CGFloat(pops) * 0.05)), gap: 0.14) }

        for d in decor where !d.held && !d.falling && d.kind == .bubbler {
            let boosted = time < d.boostUntil
            guard pump || boosted else { continue }
            let rate: CGFloat = boosted ? 62 : 16
            if CGFloat.random(in: 0...1) < dt * rate {
                let spread: CGFloat = boosted ? 20 : 11
                let r: CGFloat = boosted ? CGFloat.random(in: 3.0...7.2) : CGFloat.random(in: 1.8...4.4)
                addBubble(CGPoint(x: d.x + CGFloat.random(in: -spread...spread), y: d.y - 28), r: r)
            }
        }

        guard pump else { return }
        if CGFloat.random(in: 0...1) < dt * 15 {
            addBubble(CGPoint(x: 936 + CGFloat.random(in: -5...5), y: AGeo.sand(936) - 10), r: CGFloat.random(in: 1.8...5.2), back: true)
        }
    }

    // MARK: - Surface

    func surfaceY(_ x: CGFloat) -> CGFloat {
        let f = (x - AGeo.left) / AGeo.width * CGFloat(AGeo.surfaceNodes - 1)
        let i0 = max(0, min(AGeo.surfaceNodes - 1, Int(f.rounded(.down))))
        let i1 = min(AGeo.surfaceNodes - 1, i0 + 1)
        let k = max(0, min(1, f - CGFloat(i0)))
        let t = CGFloat(time)
        let calm = 1.4 * sin(x * 0.018 + t * 1.3) + 0.8 * sin(x * 0.043 - t * 2.1)
        return AGeo.waterY + sh[i0] + (sh[i1] - sh[i0]) * k + calm
    }

    func disturb(_ x: CGFloat, _ amount: CGFloat, width: Int) {
        let f = (x - AGeo.left) / AGeo.width * CGFloat(AGeo.surfaceNodes - 1)
        let c = Int(f.rounded())
        for i in max(0, c - width)...min(AGeo.surfaceNodes - 1, c + width) {
            let k = 1 - CGFloat(abs(i - c)) / CGFloat(width + 1)
            sv[i] += amount * 60 * k
        }
    }

    func splash(at x: CGFloat, strength: CGFloat) {
        disturb(x, 7 * strength, width: 3)
        let y = surfaceY(x)
        for _ in 0..<Int(10 + 12 * strength) {
            emitParticle(
                AquaParticle(
                    kind: .splash,
                    p: CGPoint(x: x + CGFloat.random(in: -16...16), y: y - 2),
                    v: CGVector(dx: CGFloat.random(in: -150...150), dy: CGFloat.random(in: -420 ... -120) * strength),
                    life: 1.2,
                    size: CGFloat.random(in: 1.6...3.6),
                    color: ARGB(0xD8F4FF)
                )
            )
        }
        AquaSound.shared.play(.splash, volume: Float(0.4 + 0.4 * min(1, strength)), gap: 0.1)
    }

    private func stepSurface(_ dt: CGFloat) {
        let n = AGeo.surfaceNodes
        let h = dt / 2
        for _ in 0..<2 {
            for i in 0..<n {
                let l = i > 0 ? sh[i - 1] : sh[i]
                let r = i < n - 1 ? sh[i + 1] : sh[i]
                let a = -30 * sh[i] + 1100 * (l + r - 2 * sh[i]) - 2.2 * sv[i]
                sv[i] += a * h
            }
            for i in 0..<n {
                sh[i] = max(-24, min(24, sh[i] + sv[i] * h))
            }
        }
    }

    // MARK: - Decorations

    @discardableResult
    func addDecor(_ kind: AquaDecorKind, x: CGFloat, falling: Bool = false, y: CGFloat? = nil) -> Int {
        let w = kind.size.width * 0.5
        let cx = max(AGeo.left + w * 0.6, min(AGeo.right - w * 0.6, x))
        var d = AquaDecor(id: nextID, kind: kind, x: cx, y: y ?? AGeo.sand(cx))
        nextID += 1
        d.falling = falling
        d.wet = !falling || (y ?? 999) - kind.size.height * 0.5 > surfaceY(cx)
        d.flip = nextID % 2 == 0
        d.nextPuff = time + Double.random(in: 2...9)
        decor.append(d)
        if !falling { resolveSandLayout() }
        return decor.count - 1
    }

    private func stepDecor(_ dt: CGFloat) {
        let t = CGFloat(time)
        var sandLayoutDirty = false
        var i = 0
        while i < decor.count {
            var d = decor[i]
            let size = d.kind.size
            if d.held {
                let px = d.x
                let follow = min(1, dt * 18)
                d.x += (decorTarget.x - d.x) * follow
                d.y += (decorTarget.y - d.y) * follow
                let vx = (d.x - px) / max(dt, 0.001)
                d.rotV += ((max(-0.6, min(0.6, vx * 0.0016)) - d.rot) * 60 - d.rotV * 9) * dt
                d.rot += d.rotV * dt
                d.swayV += (-vx * 0.03 - d.sway * 14 - d.swayV * 2) * dt
                d.sway += d.swayV * dt
                decor[i] = d
                i += 1
                continue
            }
            let halfW = size.width * 0.5
            if d.falling {
                let mid = d.y - size.height * 0.5
                let water = mid > surfaceY(d.x)
                if !d.wet && water {
                    d.wet = true
                    splash(at: d.x, strength: min(1.4, 0.4 + d.vy / 900))
                    d.vy *= 0.35
                    d.vx *= 0.5
                    for _ in 0..<6 {
                        addBubble(CGPoint(x: d.x + CGFloat.random(in: -halfW...halfW) * 0.6, y: mid), r: CGFloat.random(in: 2...6))
                    }
                }
                if water {
                    let rho = d.kind.density
                    d.vy += (900 * (1 - 1 / rho) - 2.4 * d.vy) * dt
                    d.vx *= exp(-dt * 2.5)
                    if d.kind.sways { d.rotV += sin(t * 3 + CGFloat(d.id)) * 1.2 * dt }
                    if CGFloat.random(in: 0...1) < dt * 3 {
                        addBubble(CGPoint(x: d.x + CGFloat.random(in: -halfW...halfW) * 0.4, y: d.y - size.height * 0.7), r: CGFloat.random(in: 1.5...3))
                    }
                } else {
                    d.vy += AquariumSim.gravity * dt
                }
                d.rotV += (-16 * d.rot - (water ? 4 : 0.5) * d.rotV) * dt
                d.rot += d.rotV * dt
                d.x += d.vx * dt
                d.y += d.vy * dt
                d.x = max(AGeo.left + halfW * 0.6, min(AGeo.right - halfW * 0.6, d.x))
                let ground = AGeo.sand(d.x)
                if d.y >= ground {
                    let impact = d.vy
                    d.y = ground
                    d.vy = 0
                    d.vx = 0
                    d.falling = false
                    d.squashV = min(9, impact / 40)
                    land(d, impact: impact)
                    sandLayoutDirty = true
                }
            } else {
                let ground = AGeo.sand(d.x)
                if ground > d.y + 3 { d.falling = true } else { d.y = ground }
                d.rotV += (-30 * d.rot - 8 * d.rotV) * dt
                d.rot += d.rotV * dt
            }
            d.squashV += (-260 * d.squash - 12 * d.squashV) * dt
            d.squash += d.squashV * dt

            if d.kind.sways {
                var push: CGFloat = 0
                for f in fish where !f.caught {
                    let dx = abs(f.p.x - d.x), top = d.y - size.height
                    if dx < halfW + 40 && f.p.y > top && f.p.y < d.y { push += f.v.dx * 0.05 }
                }
                if let h = hand, case .water = grab, abs(h.x - d.x) < halfW + 30, h.y > d.y - size.height, h.y < d.y {
                    push += handV.dx * 0.06
                }
                d.swayV += (push - d.sway * 9 - d.swayV * 1.6) * dt
                d.sway = max(-1.2, min(1.2, d.sway + d.swayV * dt))
            }

            if pump && !d.falling {
                if d.kind == .chest && time > d.nextPuff {
                    openChest(&d)
                    d.nextPuff = time + Double.random(in: 12...18)
                } else if d.kind == .diver && time > d.nextPuff {
                    d.nextPuff = time + Double.random(in: 2.5...4.5)
                    for k in 0..<4 {
                        addBubble(CGPoint(x: d.x + (d.flip ? -8 : 8) + CGFloat(k) * 2, y: d.y - 118 - CGFloat(k) * 9), r: CGFloat.random(in: 2...4.5))
                    }
                    AquaSound.shared.play(.bloop, volume: 0.3, gap: 0.3)
                } else if d.kind == .castle && time > d.nextPuff {
                    d.nextPuff = time + Double.random(in: 4...8)
                    addBubble(CGPoint(x: d.x + (d.flip ? 40 : -40), y: d.y - 140), r: CGFloat.random(in: 2...3.5))
                } else if d.kind == .koiBridge && time > d.nextPuff {
                    d.nextPuff = time + Double.random(in: 1.6...3.2)
                    for k in 0..<2 {
                        addBubble(
                            CGPoint(x: d.x + CGFloat.random(in: -22...22), y: d.y - 24 - CGFloat(k) * 8),
                            r: CGFloat.random(in: 2.2...4.2)
                        )
                    }
                }
            }
            let lid: CGFloat = time < d.openUntil ? 1 : 0
            d.open += (lid - d.open) * min(1, dt * (lid > 0 ? 7 : 2.5))
            decor[i] = d
            i += 1
        }
        if sandLayoutDirty { resolveSandLayout() }
    }

    private func openChest(_ d: inout AquaDecor) {
        d.openUntil = time + 2.2
        AquaSound.shared.play(.creak, volume: 0.45)
        for k in 0..<14 {
            addBubble(CGPoint(x: d.x + CGFloat.random(in: -26...26), y: d.y - 40 - CGFloat(k) * 4), r: CGFloat.random(in: 2.5...8))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { AquaSound.shared.play(.bloop, volume: 0.5) }
    }

    private func land(_ d: AquaDecor, impact: CGFloat) {
        let n = Int(min(26, 4 + impact / 12))
        let w = d.kind.size.width * 0.45
        for _ in 0..<n {
            let side: CGFloat = Bool.random() ? 1 : -1
            emitParticle(
                AquaParticle(
                    kind: .sand,
                    p: CGPoint(x: d.x + side * CGFloat.random(in: 0...w), y: d.y - 3),
                    v: CGVector(dx: side * CGFloat.random(in: 20...90), dy: CGFloat.random(in: -70 ... -15)),
                    life: CGFloat.random(in: 1.2...2.2),
                    size: CGFloat.random(in: 1.5...3),
                    color: ARGB(0xE8D2A6)
                )
            )
        }
        for k in 0..<3 {
            emitParticle(
                AquaParticle(
                    kind: .poof,
                    p: CGPoint(x: d.x + CGFloat(k - 1) * w * 0.7, y: d.y - 6),
                    v: CGVector(dx: CGFloat(k - 1) * 30, dy: -10),
                    life: 1.8,
                    size: 20 + w * 0.2,
                    color: ARGB(0xEADBB8)
                )
            )
        }
        AquaSound.shared.play(.thud, volume: Float(min(0.9, 0.2 + impact / 400)))
    }

    func decorIndex(_ id: Int) -> Int? { decor.firstIndex { $0.id == id } }

    func decorAt(_ p: CGPoint) -> Int? {
        for i in decor.indices.reversed() {
            let d = decor[i]
            let s = d.kind.size
            var w = s.width * 0.5 + 10
            var top = d.y - s.height - 6
            if d.kind == .seaweed || d.kind == .grass { w *= 0.65; top = d.y - s.height * 0.72 }
            if abs(p.x - d.x) < w && p.y > top && p.y < d.y + 16 { return i }
        }
        return nil
    }

    // MARK: - Smooth Translucent Moss & Snail

    private func stepMoss(_ dt: CGFloat) {
        let baseRate: CGFloat = lightsOn ? 0.0026 : 0.001
        for i in moss.indices {
            let weight = 0.72 + 0.56 * aqRand(i, 19)
            moss[i].opacity = min(1, moss[i].opacity + baseRate * weight * dt)
        }

        var s = snail
        s.phase += dt
        s.hide += ((time < s.hideUntil ? 1 : 0) - s.hide) * min(1, dt * 6)
        if s.hide < 0.3 {
            let dx = s.target.x - s.p.x, dy = s.target.y - s.p.y
            let d = hypot(dx, dy)
            if d < 14 {
                s.target = dirtiestMossSpot()
            } else {
                let want = atan2(dy, dx)
                var turn = want - s.heading
                while turn > .pi { turn -= 2 * .pi }
                while turn < -.pi { turn += 2 * .pi }
                s.heading += max(-0.55 * dt, min(0.55 * dt, turn))
                let sp: CGFloat = 8.5 * (1 + 0.3 * sin(s.phase * 2.2))
                s.p.x += cos(s.heading) * sp * dt
                s.p.y += sin(s.heading) * sp * dt
                s.p.x = max(AGeo.left + 20, min(AGeo.right - 20, s.p.x))
                s.p.y = max(AGeo.waterY + 24, min(AGeo.bottomY - 16, s.p.y))
                wipe(at: s.p, radius: 26, amount: 0.14 * dt, sparkle: false)
            }
        }
        snail = s
        if dirtiness > 0.14 { wasDirty = true }
    }

    private func dirtiestMossSpot() -> CGPoint {
        if let best = moss.max(by: { $0.opacity < $1.opacity }), best.opacity > 0.08 {
            return CGPoint(
                x: max(AGeo.left + 26, min(AGeo.right - 26, best.center.x)),
                y: max(AGeo.waterY + 30, min(AGeo.bottomY - 20, best.center.y))
            )
        }
        return CGPoint(x: CGFloat.random(in: 120...900), y: CGFloat.random(in: 260...640))
    }

    @discardableResult
    func wipe(at p: CGPoint, radius R: CGFloat, amount: CGFloat, sparkle: Bool) -> CGFloat {
        var off: CGFloat = 0
        for i in moss.indices {
            let before = moss[i].opacity
            guard before > 0 else { continue }
            let d = hypot(moss[i].center.x - p.x, moss[i].center.y - p.y)
            let reach = R + max(moss[i].rx, moss[i].ry) * 0.65
            guard d < reach else { continue }
            let falloff = 1 - (d / reach) * 0.55
            let next = max(0, before - amount * falloff)
            moss[i].opacity = next
            off += before - next
            if sparkle && before > 0.14 && next < 0.08 {
                for k in 0..<3 {
                    emitParticle(
                        AquaParticle(
                            kind: .sparkle,
                            p: CGPoint(x: moss[i].center.x + CGFloat(k * 18 - 18), y: moss[i].center.y + CGFloat((k % 2) * 14 - 7)),
                            v: .zero,
                            life: 0.65,
                            size: 13,
                            color: ARGB(0xFFFFFF)
                        )
                    )
                }
            }
        }
        if sparkle && off > 0 {
            checkCleanTankReward()
            if off > 0.08 || dirtiness < 0.06 {
                fulfillWishIfMatching({ $0 == .glassPolish }, at: p)
            }
        }
        return off
    }

    private func checkCleanTankReward() {
        let dirty = dirtiness
        if wasDirty && dirty < 0.03 {
            wasDirty = false
            AquaSound.shared.play(.chime, volume: 0.72, gap: 0.25)
            for k in 0..<16 {
                emitParticle(
                    AquaParticle(
                        kind: .sparkle,
                        p: CGPoint(x: 90 + CGFloat(k) * 56, y: CGFloat.random(in: 200...600)),
                        v: .zero,
                        life: 0.9 + CGFloat(k % 4) * 0.15,
                        size: 16,
                        color: ARGB(0xFFFFFF)
                    )
                )
            }
            inviteTurtle()
            if time - lastCleanCoinAt >= 10 {
                lastCleanCoinAt = time
                queueCoin(3, from: CGPoint(x: 512, y: 360))
            }
        } else if dirty > 0.14 {
            wasDirty = true
        }
    }

    // MARK: - Dock Tap Quick Actions

    func tapDockFood(from origin: CGPoint = CGPoint(x: 320, y: AGeo.dockY)) {
        let targetX = fish.first(where: { $0.hungryCue > 0.2 && !$0.caught })?.p.x
            ?? fish.first(where: { !$0.caught })?.p.x
            ?? 512
        let clampedX = max(AGeo.left + 80, min(AGeo.right - 80, targetX))
        feed(at: CGPoint(x: clampedX, y: AGeo.waterY - 12))
        quickAction = AquaQuickAction(
            kind: .food,
            from: origin,
            target: CGPoint(x: clampedX, y: AGeo.waterY - 26),
            start: time,
            duration: 0.72,
            triggered: true
        )
    }

    func tapDockWiper(from origin: CGPoint = CGPoint(x: 416, y: AGeo.dockY)) {
        let spot = moss.max(by: { $0.opacity < $1.opacity })
            .flatMap { $0.opacity > 0.04 ? $0.center : nil } ?? CGPoint(x: 512, y: 390)
        // Immediately begin polishing so single-frame tests and eager taps feel instant, while animating the wiper pass.
        wipe(at: spot, radius: 110 * FingerLift.spread, amount: 0.75, sparkle: true)
        AquaSound.shared.play(.squeak, volume: 0.55)
        quickAction = AquaQuickAction(
            kind: .wiper,
            from: origin,
            target: spot,
            start: time,
            duration: 0.85,
            triggered: true
        )
    }

    func tapDockHoop() {
        let swimmer = fish.first(where: { !$0.caught })
        let target = swimmer.map { CGPoint(x: $0.p.x + $0.dir * 80, y: $0.p.y) } ?? CGPoint(x: 512, y: 340)
        spawnBubbleHoop(at: target)
    }

    func netScoopPosition(u: CGFloat, from: CGPoint, target: CGPoint) -> CGPoint {
        let clamped = max(0, min(1, u))
        if clamped < 0.2 {
            let k = aqEase(clamped / 0.2)
            let start = CGPoint(x: target.x - 160, y: target.y - 10)
            return CGPoint(x: from.x + (start.x - from.x) * k, y: from.y + (start.y - from.y) * k)
        } else if clamped < 0.8 {
            let s = (clamped - 0.2) / 0.6
            let x = target.x - 160 + s * 320
            let y = target.y - 10 + sin(s * .pi) * 68
            return CGPoint(x: x, y: y)
        } else {
            let k = aqEase((clamped - 0.8) / 0.2)
            let end = CGPoint(x: target.x + 160, y: target.y - 10)
            return CGPoint(x: end.x + (from.x - end.x) * k, y: end.y + (from.y - end.y) * k)
        }
    }

    func tapDockNet(from origin: CGPoint = CGPoint(x: 608, y: AGeo.dockY)) {
        let target: CGPoint
        if let gift = floatingGifts.first {
            target = gift.p
            _ = collectFloatingGift(atIndex: 0)
        } else if !demo, let chestPearl = openChestPearlOrigin(), !isFindClaimed(.pearl) {
            target = chestPearl
            discover(.pearl, at: chestPearl)
            if time - lastGiftCoinAt >= Self.coinCooldown {
                lastGiftCoinAt = time
                queueCoin(2, from: chestPearl)
            }
        } else {
            coaxFloatingGiftForNet()
            if let gift = floatingGifts.first {
                target = gift.p
                _ = collectFloatingGift(atIndex: 0)
            } else {
                target = CGPoint(x: 512, y: 372)
            }
        }
        AquaSound.shared.play(.swish, volume: 0.55)
        AquaSound.shared.play(.bloop, volume: 0.5, gap: 0.1)
        for k in 0..<6 {
            let x = target.x - 110 + CGFloat(k) * 44
            let y = target.y + sin(CGFloat(k) / 5 * .pi) * 34
            addBubble(CGPoint(x: x, y: y), r: CGFloat.random(in: 2.6...5.4))
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: x, y: y - 10),
                    v: .zero,
                    life: 0.7,
                    size: 13,
                    color: k.isMultiple(of: 2) ? ARGB(0xFFFFFF) : ARGB(0xB8F5FF)
                )
            )
        }
        quickAction = AquaQuickAction(
            kind: .net,
            from: origin,
            target: target,
            start: time,
            duration: 0.92,
            triggered: true
        )
    }

    private func coaxFloatingGiftForNet() {
        if let shell = decor.first(where: { $0.kind == .shell && !$0.held && !$0.falling }) {
            spawnFloatingGift(.starShell, at: CGPoint(x: shell.x, y: shell.y - 36))
            return
        }
        if let bubbler = decor.first(where: { $0.kind == .bubbler && !$0.held && !$0.falling }) {
            spawnFloatingGift(.bubbleGift, at: CGPoint(x: bubbler.x, y: bubbler.y - 44))
            return
        }
        if let chest = decor.first(where: { $0.kind == .chest && !$0.held && !$0.falling }) {
            spawnFloatingGift(.bubbleGift, at: CGPoint(x: chest.x, y: chest.y - 54))
            return
        }
        if let clam = clams.first {
            spawnFloatingGift(.starShell, at: CGPoint(x: clam.x, y: clam.y - 32))
            return
        }
        spawnFloatingGift(.bubbleGift, at: CGPoint(x: 512, y: 420))
    }

    private func stepQuickAction(_ dt: CGFloat) {
        guard let q = quickAction else { return }
        let elapsed = time - q.start
        if elapsed >= q.duration {
            quickAction = nil
            return
        }
        let u = CGFloat(elapsed / q.duration)
        switch q.kind {
        case .wiper:
            let sweepX = q.target.x + sin(u * .pi * 3) * 44
            let sweepY = q.target.y + cos(u * .pi * 2) * 28
            wipe(at: CGPoint(x: sweepX, y: sweepY), radius: 84 * FingerLift.spread, amount: 2.2 * dt, sparkle: true)
        case .net:
            guard u >= 0.18 && u <= 0.82 else { break }
            let pos = netScoopPosition(u: u, from: q.from, target: q.target)
            if CGFloat.random(in: 0...1) < dt * 28 {
                addBubble(
                    CGPoint(x: pos.x + CGFloat.random(in: -18...18), y: pos.y + CGFloat.random(in: -12...14)),
                    r: CGFloat.random(in: 2.2...5.6)
                )
            }
            if CGFloat.random(in: 0...1) < dt * 16 {
                emitParticle(
                    AquaParticle(
                        kind: .sparkle,
                        p: CGPoint(x: pos.x + CGFloat.random(in: -22...22), y: pos.y + CGFloat.random(in: -18...18)),
                        v: .zero,
                        life: 0.6,
                        size: 12,
                        color: Bool.random() ? ARGB(0xFFFFFF) : ARGB(0xFFE69A)
                    )
                )
            }
        case .food:
            break
        }
    }

    // MARK: - Mystery Reef Eggs

    @discardableResult
    func dropEgg(at x: CGFloat, y: CGFloat? = nil, species: FishKind? = nil) -> Int? {
        guard eggs.count < Self.maxEggs else {
            if let first = eggs.indices.first {
                eggs[first].wobbleV = 10
                AquaSound.shared.play(.bloop, volume: 0.5)
            }
            return nil
        }
        let cx = max(AGeo.left + 64, min(AGeo.right - 64, x))
        let sandY = AGeo.sand(cx)
        let startY = y ?? (AGeo.waterY - 12)
        let isFalling = startY < sandY - 6
        let chosen = species ?? nextEggSpecies()
        let palette = AquaEggPalette.allCases[nextID % AquaEggPalette.allCases.count]
        let egg = AquaEgg(
            id: nextID,
            x: cx,
            y: isFalling ? startY : sandY,
            vy: isFalling ? 90 : 0,
            falling: isFalling,
            taps: 0,
            palette: palette,
            species: chosen,
            wobble: 0,
            wobbleV: isFalling ? 0 : 4,
            shimmerPhase: CGFloat.random(in: 0...6)
        )
        nextID += 1
        eggs.append(egg)
        if isFalling {
            if startY < surfaceY(cx) { splash(at: cx, strength: 0.45) }
            else { AquaSound.shared.play(.bloop, volume: 0.55) }
        } else {
            resolveSandLayout()
        }
        if !demo { needsSave = true }
        return eggs.count - 1
    }

    private func nextEggSpecies() -> FishKind {
        let present = Set(fish.map(\.kind))
        for magic in FishKind.reefBabyCases where !present.contains(magic) && !eggs.contains(where: { $0.species == magic }) {
            return magic
        }
        let pool: [FishKind] = [.axolotl, .seaBunny, .narwhal, .goldfish, .clownfish, .puffer, .seahorse, .betta]
        let pick = pool[nextEggSpeciesCursor % pool.count]
        nextEggSpeciesCursor += 1
        return pick
    }

    @discardableResult
    func tapEgg(_ p: CGPoint) -> Bool {
        for i in eggs.indices.reversed() {
            let e = eggs[i]
            if hypot(e.x - p.x, (e.y - 22) - p.y) < 44 {
                return tapEgg(atIndex: i)
            }
        }
        return false
    }

    @discardableResult
    func tapEgg(atIndex i: Int) -> Bool {
        guard eggs.indices.contains(i) else { return false }
        eggs[i].taps += 1
        eggs[i].lastTap = time
        eggs[i].wobbleV = eggs[i].taps % 2 == 0 ? -12 : 12
        let center = CGPoint(x: eggs[i].x, y: eggs[i].y - 24)
        for k in 0..<4 {
            let a = CGFloat(k) / 4 * 2 * .pi
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: center.x + cos(a) * 18, y: center.y + sin(a) * 18),
                    v: CGVector(dx: cos(a) * 18, dy: -22),
                    life: 0.6,
                    size: 11,
                    color: ARGB(0xFFF0A8)
                )
            )
            addBubble(CGPoint(x: center.x + CGFloat(k * 6 - 9), y: center.y - 8), r: CGFloat.random(in: 2...4))
        }
        if eggs[i].taps < 3 {
            Sound.shared.play(.crack, volume: 0.65)
            AquaSound.shared.play(.tink, volume: 0.45, gap: 0.1)
            if !demo { needsSave = true }
            return true
        }

        let hatched = eggs.remove(at: i)
        resolveSandLayout()
        if fish.count >= Self.maxFish {
            _ = evictOneOrdinaryFish()
        }
        let v = AquariumSim.rollVariant((nextID * 5) % max(1, hatched.species.variants))
        let spawnY = min(AGeo.sand(hatched.x) - 26, hatched.y - 26)
        let fIdx = spawn(hatched.species, variant: v, at: CGPoint(x: hatched.x, y: spawnY), growthStage: 0, growthBites: 0)
        fish[fIdx].v = CGVector(dx: CGFloat.random(in: -48...48), dy: -92)
        fish[fIdx].happy = time
        fish[fIdx].flipStart = time
        fish[fIdx].appetite = 5
        fish[fIdx].snackReadyAt = time + 2.0

        let confetti: [ARGB] = [ARGB(0xFF8FB8), ARGB(0xFFE38A), ARGB(0x9FE3CF), ARGB(0xC9B6FF), ARGB(0xFFFFFF)]
        for k in 0..<12 {
            let a = CGFloat(k) / 12 * 2 * .pi
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: center.x + cos(a) * 24, y: center.y + sin(a) * 20),
                    v: CGVector(dx: cos(a) * 44, dy: sin(a) * 32 - 36),
                    life: 0.9,
                    size: 14,
                    color: confetti[k % confetti.count]
                )
            )
        }
        emitParticle(
            AquaParticle(
                kind: .heart,
                p: CGPoint(x: center.x, y: center.y - 16),
                v: CGVector(dx: 0, dy: -52),
                life: 1.3,
                size: 18,
                color: ARGB(0xFF7FAE)
            )
        )
        for k in 0..<8 {
            addBubble(CGPoint(x: center.x + CGFloat(k * 6 - 21), y: center.y - CGFloat(k % 3) * 8), r: CGFloat.random(in: 2.5...5.5))
        }
        AquaSound.shared.play(.chime, volume: 0.8)
        Sound.shared.play(.pop, volume: 0.75)
        if !demo { needsSave = true }
        return true
    }

    private func stepEggs(_ dt: CGFloat) {
        var landedAny = false
        for i in eggs.indices {
            var e = eggs[i]
            e.shimmerPhase += dt * 2.5
            let ground = AGeo.sand(e.x)
            if e.falling {
                let inWater = e.y > surfaceY(e.x)
                if inWater {
                    e.vy += (240 - e.vy) * min(1, dt * 3.5)
                } else {
                    e.vy += AquariumSim.gravity * dt
                }
                e.y += e.vy * dt
                if e.y >= ground {
                    e.y = ground
                    e.vy = 0
                    e.falling = false
                    e.wobbleV = 6
                    landedAny = true
                    emitParticle(
                        AquaParticle(
                            kind: .poof,
                            p: CGPoint(x: e.x, y: ground - 4),
                            v: CGVector(dx: 0, dy: -8),
                            life: 1.0,
                            size: 18,
                            color: ARGB(0xEADBB8)
                        )
                    )
                    AquaSound.shared.play(.thud, volume: 0.3, gap: 0.15)
                }
            } else {
                e.y = ground
            }
            e.wobbleV += (-160 * e.wobble - 9 * e.wobbleV) * dt
            e.wobble = max(-0.45, min(0.45, e.wobble + e.wobbleV * dt))
            eggs[i] = e
        }
        if landedAny { resolveSandLayout() }
    }

    // MARK: - Interactive Yellow Submarine

    func toggleSubmarine() {
        submarine.active.toggle()
        if submarine.active {
            submarine.p = CGPoint(x: 512, y: 270)
            submarine.target = CGPoint(x: 512, y: 340)
            submarine.v = CGVector(dx: 0, dy: 70)
            splash(at: 512, strength: 0.6)
            AquaSound.shared.play(.bloop, volume: 0.65)
            AquaSound.shared.play(.chime, volume: 0.5, gap: 0.25)
        } else {
            bye(submarine.p)
            AquaSound.shared.play(.swish, volume: 0.45)
        }
        syncUIStateIfNeeded()
    }

    func isOnSubmarineHull(_ p: CGPoint) -> Bool {
        submarine.active && hypot(p.x - submarine.p.x, p.y - submarine.p.y) <= 64
    }

    func liftedSubmarineTarget(for finger: CGPoint) -> CGPoint {
        FingerLift.point(
            finger,
            lift: FingerLift.item,
            top: AGeo.waterY + 34,
            bottom: GameChromeLayout.height,
            width: GameChromeLayout.width
        )
    }

    func steerSubmarineFromFinger(_ finger: CGPoint) {
        steerSubmarine(to: liftedSubmarineTarget(for: finger))
    }

    func steerSubmarine(to point: CGPoint) {
        if !submarine.active {
            submarine.active = true
            submarine.p = CGPoint(x: max(AGeo.left + 84, min(AGeo.right - 84, point.x)), y: AGeo.waterY + 56)
            splash(at: submarine.p.x, strength: 0.5)
        }
        let cx = max(AGeo.left + 74, min(AGeo.right - 74, point.x))
        let cy = max(AGeo.waterY + 46, min(AGeo.sand(cx) - 52, point.y))
        submarine.target = CGPoint(x: cx, y: cy)
        syncUIStateIfNeeded()
    }

    private func stepSubmarine(_ dt: CGFloat) {
        for k in hiddenSpots.indices {
            let awake = time < hiddenSpots[k].awakeUntil
            let targetPop: CGFloat = awake ? 1 : 0
            hiddenSpots[k].pop += (targetPop - hiddenSpots[k].pop) * min(1, dt * (awake ? 7 : 2.5))
        }
        guard submarine.active else { return }

        var sub = submarine
        sub.bobPhase += dt * 2.4
        let dx = sub.target.x - sub.p.x
        let dy = sub.target.y - sub.p.y
        let dist = hypot(dx, dy)
        let desiredSpeed = min(240, dist * 3.0)
        let vx = dist > 1 ? dx / dist * desiredSpeed : 0
        let vy = dist > 1 ? dy / dist * desiredSpeed : 0
        sub.v.dx += (vx - sub.v.dx) * min(1, dt * 6)
        sub.v.dy += (vy - sub.v.dy) * min(1, dt * 6)
        sub.p.x += sub.v.dx * dt
        sub.p.y += sub.v.dy * dt
        sub.p.x = max(AGeo.left + 68, min(AGeo.right - 68, sub.p.x))
        sub.p.y = max(AGeo.waterY + 44, min(AGeo.sand(sub.p.x) - 46, sub.p.y))

        if abs(sub.v.dx) > 10 {
            sub.facing = sub.v.dx > 0 ? 1 : -1
        }
        let speedNow = hypot(sub.v.dx, sub.v.dy)
        sub.propPhase += dt * (8 + speedNow * 0.08)
        sub.beamAngle = 0.28 + sin(sub.bobPhase * 0.7) * 0.06

        if time >= sub.nextBubble {
            sub.nextBubble = time + (speedNow > 40 ? 0.09 : 0.28)
            addBubble(
                CGPoint(x: sub.p.x - sub.facing * 58, y: sub.p.y + CGFloat.random(in: -6...6)),
                r: CGFloat.random(in: 2.2...4.8)
            )
        }

        // Spotlight beam illuminates caves/rocks/sand and wakes hidden reef surprises!
        let lampOrigin = CGPoint(x: sub.p.x + sub.facing * 47, y: sub.p.y + 4)
        let dirX = sub.facing * cos(sub.beamAngle)
        let dirY = sin(sub.beamAngle)
        for k in hiddenSpots.indices {
            let sp = hiddenSpots[k].p
            let sx = sp.x - lampOrigin.x
            let sy = sp.y - lampOrigin.y
            let d = hypot(sx, sy)
            let directUnder = hypot(sp.x - sub.p.x, sp.y - sub.p.y) < 110
            var inBeam = directUnder
            if !inBeam && d > 1 && d < 220 {
                let dot = (sx * dirX + sy * dirY) / d
                if dot > 0.76 { inBeam = true }
            }
            if inBeam {
                let wasSleeping = time > hiddenSpots[k].awakeUntil
                hiddenSpots[k].awakeUntil = max(hiddenSpots[k].awakeUntil, time + 4.5)
                if wasSleeping {
                    for j in 0..<6 {
                        let a = CGFloat(j) / 6 * 2 * .pi
                        emitParticle(
                            AquaParticle(
                                kind: .sparkle,
                                p: CGPoint(x: sp.x + cos(a) * 20, y: sp.y - 16 + sin(a) * 16),
                                v: CGVector(dx: cos(a) * 14, dy: -20),
                                life: 0.75,
                                size: 13,
                                color: ARGB(0xFFE69A)
                            )
                        )
                    }
                    for j in 0..<4 {
                        addBubble(CGPoint(x: sp.x + CGFloat(j * 6 - 9), y: sp.y - 12), r: CGFloat.random(in: 2.2...4.4))
                    }
                    AquaSound.shared.play(.chime, volume: 0.62, gap: 0.25)
                    AquaSound.shared.play(.bloop, volume: 0.5, gap: 0.16)
                    if time - hiddenSpots[k].lastCoinAt >= 8 && time - lastSubCoinAt >= Self.coinCooldown {
                        hiddenSpots[k].lastCoinAt = time
                        lastSubCoinAt = time
                        queueCoin(2, from: CGPoint(x: sp.x, y: sp.y - 24))
                    }
                }
            }
        }
        submarine = sub
    }

    @discardableResult
    func tapHiddenSpot(_ p: CGPoint) -> Bool {
        for i in hiddenSpots.indices {
            let s = hiddenSpots[i]
            guard s.pop > 0.25 else { continue }
            guard hypot(s.p.x - p.x, (s.p.y - 16) - p.y) < 42 else { continue }
            hiddenSpots[i].awakeUntil = max(hiddenSpots[i].awakeUntil, time + 3.5)
            hiddenSpots[i].celebrateUntil = time + 1.0
            let origin = CGPoint(x: s.p.x, y: s.p.y - 20)
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * 2 * .pi
                emitParticle(
                    AquaParticle(
                        kind: .sparkle,
                        p: CGPoint(x: origin.x + cos(a) * 20, y: origin.y + sin(a) * 16),
                        v: CGVector(dx: cos(a) * 18, dy: -24),
                        life: 0.75,
                        size: 13,
                        color: k.isMultiple(of: 2) ? ARGB(0xFFE69A) : ARGB(0xFFFFFF)
                    )
                )
            }
            emitParticle(
                AquaParticle(
                    kind: .heart,
                    p: CGPoint(x: origin.x, y: origin.y - 14),
                    v: CGVector(dx: 0, dy: -42),
                    life: 1.15,
                    size: 15,
                    color: ARGB(0xFF7FAE)
                )
            )
            for k in 0..<4 {
                addBubble(CGPoint(x: origin.x + CGFloat(k * 6 - 9), y: origin.y - 4), r: CGFloat.random(in: 2.2...4.2))
            }
            AquaSound.shared.play(.chime, volume: 0.62, gap: 0.16)
            AquaSound.shared.play(.bloop, volume: 0.55, gap: 0.12)
            if time - hiddenSpots[i].lastTapCoinAt >= Self.coinCooldown {
                hiddenSpots[i].lastTapCoinAt = time
                queueCoin(1, from: origin)
            }
            return true
        }
        return false
    }

    // MARK: - Musical Singing Clams & Fish Ribbon Dance

    @discardableResult
    func tapClam(_ p: CGPoint) -> Bool {
        for i in clams.indices {
            let c = clams[i]
            if hypot(c.x - p.x, (c.y - 12) - p.y) < 32 {
                singClam(atIndex: i)
                return true
            }
        }
        return false
    }

    func singClam(atIndex i: Int) {
        guard clams.indices.contains(i) else { return }
        clams[i].openUntil = time + 1.5
        clams[i].bounceV = 9
        let notes: [SFX] = [.note1, .note2, .note3, .note4]
        let note = notes[clams[i].noteIndex % notes.count]
        Sound.shared.play(note, volume: 0.78)
        let origin = CGPoint(x: clams[i].x, y: clams[i].y - 24)
        let noteColors: [ARGB] = [ARGB(0xFF8FB8), ARGB(0xFFE07D), ARGB(0x88E8CA), ARGB(0xC5A8FF)]
        for k in 0..<2 {
            emitParticle(
                AquaParticle(
                    kind: .note,
                    p: CGPoint(x: origin.x + CGFloat(k * 14 - 7), y: origin.y - CGFloat(k) * 8),
                    v: CGVector(dx: CGFloat(k == 0 ? -12 : 12), dy: -46),
                    life: 1.4,
                    size: 16,
                    color: noteColors[clams[i].noteIndex % noteColors.count]
                )
            )
        }
        for k in 0..<3 {
            addBubble(CGPoint(x: origin.x + CGFloat(k * 6 - 6), y: origin.y - 4), r: CGFloat.random(in: 2...4))
        }
        if floatingGifts.count < Self.maxFloatingGifts && !floatingGifts.contains(where: { $0.kind == .starShell }) {
            spawnFloatingGift(.starShell, at: CGPoint(x: origin.x, y: origin.y - 12))
        }

        clamTapTimes.append(time)
        clamTapTimes.removeAll { time - $0 > 4.0 }
        if clamTapTimes.count >= 3 && !isRibbonDanceActive {
            clamTapTimes.removeAll()
            triggerRibbonDance()
        }
    }

    func triggerRibbonDance() {
        ribbonDanceStart = time
        ribbonDanceUntil = time + 7.0
        for i in clams.indices {
            clams[i].openUntil = max(clams[i].openUntil, time + 2.6)
            clams[i].bounceV = 8
        }
        Sound.shared.play(.sparkle, volume: 0.7)
        AquaSound.shared.play(.chime, volume: 0.72, gap: 0.25)
        let rainbow: [ARGB] = [ARGB(0xFF8FB8), ARGB(0xFFD25A), ARGB(0x8CE8CA), ARGB(0x8CD8FF), ARGB(0xC9B6FF)]
        for k in 0..<10 {
            let a = CGFloat(k) / 10 * 2 * .pi
            let sA = sin(a)
            let hx = 512 + 195 * sA * sA * sA
            let hy = 368 - (120 * cos(a) - 46 * cos(2 * a) - 18 * cos(3 * a))
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: hx, y: hy),
                    v: CGVector(dx: 0, dy: -12),
                    life: 1.1,
                    size: 14,
                    color: rainbow[k % rainbow.count]
                )
            )
        }
        fulfillWishIfMatching({ $0 == .ribbonDance }, at: CGPoint(x: 512, y: 340))
    }

    private func stepClams(_ dt: CGFloat) {
        for i in clams.indices {
            var c = clams[i]
            let wantOpen: CGFloat = time < c.openUntil ? 1 : 0
            c.open += (wantOpen - c.open) * min(1, dt * (wantOpen > 0 ? 11 : 4))
            c.bounceV += (-180 * c.bounce - 11 * c.bounceV) * dt
            c.bounce = max(-0.5, min(0.6, c.bounce + c.bounceV * dt))
            clams[i] = c
        }
        if isRibbonDanceActive && CGFloat.random(in: 0...1) < dt * 8 {
            let a = CGFloat(time - ribbonDanceStart) * 2.4 + CGFloat.random(in: 0...(2 * .pi))
            let sA = sin(a)
            let hx = 512 + 195 * sA * sA * sA
            let hy = 368 - (120 * cos(a) - 46 * cos(2 * a) - 18 * cos(3 * a))
            let rainbow: [ARGB] = [ARGB(0xFF8FB8), ARGB(0xFFE38A), ARGB(0x88E8CA), ARGB(0x90D4FF), ARGB(0xC9B6FF)]
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: hx, y: hy),
                    v: CGVector(dx: CGFloat.random(in: -10...10), dy: -14),
                    life: 0.75,
                    size: 12,
                    color: rainbow[Int.random(in: 0..<rainbow.count)]
                )
            )
        }
    }

    // MARK: - Floating Gifts & Pictorial Play Wishes

    @discardableResult
    func spawnFloatingGift(_ kind: AquaFloatingGiftKind, at p: CGPoint) -> Int {
        while floatingGifts.count >= Self.maxFloatingGifts {
            floatingGifts.removeFirst()
        }
        let cx = max(AGeo.left + 44, min(AGeo.right - 44, p.x))
        let cy = max(AGeo.waterY + 46, min(AGeo.sand(cx) - 24, p.y))
        let gift = AquaFloatingGift(
            id: nextID,
            kind: kind,
            p: CGPoint(x: cx, y: cy),
            vy: -20,
            phase: CGFloat.random(in: 0...6)
        )
        nextID += 1
        floatingGifts.append(gift)
        return floatingGifts.count - 1
    }

    private func stepFloatingGifts(_ dt: CGFloat) {
        var write = 0
        for read in 0..<floatingGifts.count {
            var g = floatingGifts[read]
            g.age += dt
            if g.age >= g.life { continue }
            g.phase += dt * 2.4
            let topHover = AGeo.waterY + 48
            if g.p.y > topHover {
                g.p.y = max(topHover, g.p.y + g.vy * dt)
            } else {
                g.p.y = topHover + sin(g.phase) * 5
            }
            g.p.x = max(AGeo.left + 44, min(AGeo.right - 44, g.p.x + sin(g.phase) * 14 * dt))
            floatingGifts[write] = g
            write += 1
        }
        if write < floatingGifts.count {
            floatingGifts.removeSubrange(write..<floatingGifts.count)
        }
    }

    @discardableResult
    func collectFloatingGift(atIndex i: Int) -> Bool {
        guard floatingGifts.indices.contains(i) else { return false }
        let gift = floatingGifts.remove(at: i)
        let origin = gift.p
        for k in 0..<8 {
            let a = CGFloat(k) / 8 * 2 * .pi
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: origin.x + cos(a) * 24, y: origin.y + sin(a) * 20),
                    v: CGVector(dx: cos(a) * 20, dy: -22),
                    life: 0.78,
                    size: 14,
                    color: k.isMultiple(of: 2) ? ARGB(0xFFE69A) : ARGB(0xFFFFFF)
                )
            )
        }
        for k in 0..<5 {
            addBubble(CGPoint(x: origin.x + CGFloat(k * 6 - 12), y: origin.y - CGFloat(k % 3) * 6), r: CGFloat.random(in: 2.2...4.8))
        }
        AquaSound.shared.play(.chime, volume: 0.65, gap: 0.16)
        AquaSound.shared.play(.bloop, volume: 0.55, gap: 0.12)
        if gift.kind == .pearl {
            discover(.pearl, at: origin)
        }
        if time - lastGiftCoinAt >= Self.coinCooldown {
            lastGiftCoinAt = time
            queueCoin(2, from: origin)
        }
        return true
    }

    @discardableResult
    func collectFloatingGifts(near point: CGPoint, radius: CGFloat) -> Int {
        var collected = 0
        for idx in floatingGifts.indices.reversed() {
            if hypot(floatingGifts[idx].p.x - point.x, floatingGifts[idx].p.y - point.y) <= radius {
                if collectFloatingGift(atIndex: idx) { collected += 1 }
            }
        }
        return collected
    }

    @discardableResult
    func tapFloatingGift(_ p: CGPoint) -> Bool {
        for idx in floatingGifts.indices.reversed() {
            if hypot(floatingGifts[idx].p.x - p.x, floatingGifts[idx].p.y - p.y) <= 42 {
                return collectFloatingGift(atIndex: idx)
            }
        }
        return false
    }

    func wishBearerPoint(_ bearer: AquaWishBearer) -> CGPoint? {
        switch bearer {
        case .fish(let id):
            guard let f = fish.first(where: { $0.id == id && !$0.caught }) else { return nil }
            return CGPoint(x: f.p.x, y: f.p.y - f.kind.height * 0.5 * f.scale - 22)
        case .visitor(let kind):
            guard let v = visitors.first(where: { $0.kind == kind }) else { return nil }
            return CGPoint(x: v.p.x, y: v.p.y - 42)
        }
    }

    @discardableResult
    func spawnPlayWish(kind forcedKind: AquaPlayWishKind? = nil) -> AquaActiveWish? {
        guard activeWish == nil else { return activeWish }
        let eligibleFish = fish.filter { !$0.caught && !isFishSleeping($0) }
        let bearer: AquaWishBearer
        if let f = eligibleFish.randomElement() {
            bearer = .fish(id: f.id)
        } else if let v = visitors.first(where: { $0.state == .staying }) {
            bearer = .visitor(v.kind)
        } else {
            return nil
        }

        let chosenKind: AquaPlayWishKind
        if let forcedKind {
            chosenKind = forcedKind
        } else {
            var candidates: [AquaPlayWishKind] = [.hoopTrick, .pearlPellet, .ribbonDance]
            if lightsOn { candidates.append(.nightGlow) }
            if dirtiness > 0.08 { candidates.append(.glassPolish) }
            for d in decor where !d.held && !d.falling {
                for spec in d.kind.anchorSpecs where spec.role == .swimThrough || spec.role == .hideout {
                    candidates.append(.decorPlay(d.kind, spec.role))
                }
            }
            guard let pick = candidates.randomElement() else { return nil }
            chosenKind = pick
        }

        let wish = AquaActiveWish(
            id: nextID,
            bearer: bearer,
            kind: chosenKind,
            createdAt: time,
            expiresAt: time + 26
        )
        nextID += 1
        activeWish = wish
        return wish
    }

    private func stepWishes(_ dt: CGFloat) {
        if let wish = activeWish {
            if time >= wish.expiresAt || wishBearerPoint(wish.bearer) == nil {
                activeWish = nil
                nextWishAt = time + Double.random(in: 8...14)
            } else if wish.kind == .nightGlow && night > 0.55 {
                fulfillWishIfMatching({ $0 == .nightGlow }, at: CGPoint(x: 512, y: 260))
            }
            return
        }
        if time >= nextWishAt && (!fish.isEmpty || !visitors.isEmpty) {
            if spawnPlayWish() == nil {
                nextWishAt = time + 4
            }
        }
    }

    func fulfillWishIfMatching(_ predicate: (AquaPlayWishKind) -> Bool, at fallback: CGPoint) {
        guard let wish = activeWish, predicate(wish.kind) else { return }
        let origin = wishBearerPoint(wish.bearer) ?? fallback
        if case .fish(let id) = wish.bearer, let idx = fish.firstIndex(where: { $0.id == id }) {
            fish[idx].happy = time
            fish[idx].flipStart = time
        }
        activeWish = nil
        nextWishAt = time + Double.random(in: 12...20)
        for k in 0..<8 {
            let a = CGFloat(k) / 8 * 2 * .pi
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: origin.x + cos(a) * 28, y: origin.y + sin(a) * 24),
                    v: CGVector(dx: cos(a) * 22, dy: -20),
                    life: 0.9,
                    size: 15,
                    color: k.isMultiple(of: 2) ? ARGB(0xFFE69A) : ARGB(0xFFFFFF)
                )
            )
        }
        for k in 0..<3 {
            emitParticle(
                AquaParticle(
                    kind: .heart,
                    p: CGPoint(x: origin.x + CGFloat(k * 18 - 18), y: origin.y - 10),
                    v: CGVector(dx: CGFloat(k * 10 - 10), dy: -46),
                    life: 1.3,
                    size: 16,
                    color: ARGB(0xFF7FAE)
                )
            )
        }
        AquaSound.shared.play(.chime, volume: 0.78, gap: 0.12)
        Sound.shared.play(.sparkle, volume: 0.7)
        if time - lastWishCoinAt >= Self.coinCooldown {
            lastWishCoinAt = time
            queueCoin(3, from: origin)
        }
    }

    // MARK: - Particles

    private func stepParticles(_ dt: CGFloat) {
        var write = 0
        for read in 0..<particles.count {
            var q = particles[read]
            q.age += dt
            if q.age >= q.life { continue }
            switch q.kind {
            case .splash:
                q.v.dy += AquariumSim.gravity * dt
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                if q.v.dy > 0 && q.p.y > surfaceY(q.p.x) && q.p.x > AGeo.left && q.p.x < AGeo.right {
                    disturb(q.p.x, 0.4, width: 0)
                    continue
                }
            case .sand:
                q.v.dx *= exp(-dt * 3)
                q.v.dy += (22 - q.v.dy) * min(1, dt * 2.5)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                if q.p.y > AGeo.sand(q.p.x) { continue }
            case .poof:
                q.v.dx *= exp(-dt * 2)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.size += dt * 22
            case .heart, .note:
                q.p.x += q.v.dx * dt + sin(q.age * 6) * 12 * dt
                q.p.y += q.v.dy * dt
            case .sleepZ:
                q.p.x += q.v.dx * dt + sin(q.age * 3.2) * 8 * dt
                q.p.y += q.v.dy * dt
            case .moss:
                q.v.dy += (18 - q.v.dy) * min(1, dt * 2)
                q.p.x += sin(q.age * 3 + q.size) * 10 * dt
                q.p.y += q.v.dy * dt
                if q.p.y > AGeo.sand(q.p.x) { continue }
            case .glow:
                q.p.x += q.v.dx * dt + sin(q.age * 1.3 + q.size * 3) * 6 * dt
                q.p.y += q.v.dy * dt
            case .ring, .sparkle:
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            }
            particles[write] = q
            write += 1
        }
        if write < particles.count {
            particles.removeSubrange(write..<particles.count)
        }
        if night > 0.5 && CGFloat.random(in: 0...1) < dt * 2.5 && particles.count < Self.maxParticles {
            emitParticle(
                AquaParticle(
                    kind: .glow,
                    p: CGPoint(x: CGFloat.random(in: 80...950), y: CGFloat.random(in: 200...580)),
                    v: CGVector(dx: CGFloat.random(in: -6...6), dy: CGFloat.random(in: -5...3)),
                    life: CGFloat.random(in: 4...8),
                    size: CGFloat.random(in: 1.5...3.2),
                    color: [ARGB(0x8CF7FF), ARGB(0xB8FFC8), ARGB(0xD9B8FF)][Int.random(in: 0..<3)]
                )
            )
        }
    }

    private func bye(_ p: CGPoint) {
        for k in 0..<8 {
            let a = CGFloat(k) / 8 * 2 * .pi
            emitParticle(
                AquaParticle(
                    kind: .sparkle,
                    p: CGPoint(x: p.x + cos(a) * 24, y: p.y + sin(a) * 24),
                    v: .zero,
                    life: 0.5 + CGFloat(k % 3) * 0.1,
                    size: 12,
                    color: ARGB(0xFFFFFF)
                )
            )
        }
    }

    // MARK: - Step

    func step(_ now: Date) {
        let raw = last.map { now.timeIntervalSince($0) } ?? 1.0 / 60
        last = now
        step(dt: CGFloat(min(max(raw, 0), 1.0 / 30)))
    }

    func step(dt: CGFloat) {
        guard dt > 0 else { return }
        isStepping = true
        defer { isStepping = false }

        time += Double(dt)
        night += ((lightsOn ? 0 : 1) - night) * min(1, dt * 1.6)
        stepHand(dt)
        stepTool(dt)
        stepQuickAction(dt)
        stepSurface(dt)
        stepHoops(dt)
        stepSubmarine(dt)
        stepClams(dt)
        stepEggs(dt)
        stepFloatingGifts(dt)
        stepFish(dt)
        stepFood(dt)
        stepBubbles(dt)
        stepDecor(dt)
        stepMoss(dt)
        stepParticles(dt)
        stepFinds(dt)
        stepWishes(dt)
        AquaSound.shared.setLoop(.hum, volume: 0.3)
        AquaSound.shared.setLoop(.pump, volume: pump ? 0.32 : 0)
        if time - lastSave > 20 {
            lastSave = time
            if !demo { needsSave = true }
        }
        syncUIStateIfNeeded()
    }

    func setLights(_ on: Bool) {
        lightsOn = on
        AquaSound.shared.play(.click, volume: 0.6)
        if on {
            for i in fish.indices where isFishSleeping(fish[i]) {
                fish[i].activity = .cruising
                fish[i].restUntil = -10
                fish[i].activityCooldown = time + 2.5
                fish[i].nextThink = time + 0.5
                fish[i].v.dy -= 16
            }
        } else {
            for i in fish.indices where !fish[i].caught {
                fish[i].activityCooldown = min(fish[i].activityCooldown, time)
            }
            fulfillWishIfMatching({ $0 == .nightGlow }, at: CGPoint(x: 512, y: 240))
        }
    }

    func setPump(_ on: Bool) {
        pump = on
        AquaSound.shared.play(on ? .bloop : .click, volume: 0.6)
    }

    // MARK: - Direct Hand Gestures

    private func isForegroundTarget(_ p: CGPoint) -> Bool {
        if floatingGifts.contains(where: { hypot($0.p.x - p.x, $0.p.y - p.y) <= 42 }) { return true }
        if !demo,
           !isFindClaimed(.pearl),
           let origin = openChestPearlOrigin(),
           hypot(p.x - origin.x, p.y - origin.y) < 38 {
            return true
        }
        if visitors.contains(where: { v in
            let mid = v.kind == .crab || v.kind == .octopus ? CGPoint(x: v.p.x, y: v.p.y - 24) : v.p
            return hypot(mid.x - p.x, mid.y - p.y) < v.kind.reach
        }) { return true }
        if fishAt(p) != nil { return true }
        if hoops.contains(where: { hypot($0.p.x - p.x, $0.p.y - p.y) < $0.radius + 16 }) { return true }
        if eggs.contains(where: { hypot($0.x - p.x, ($0.y - 22) - p.y) < 44 }) { return true }
        if hiddenSpots.contains(where: { $0.pop > 0.25 && hypot($0.p.x - p.x, ($0.p.y - 16) - p.y) < 42 }) { return true }
        if hypot(p.x - snail.p.x, p.y - snail.p.y) < 38 { return true }
        if clams.contains(where: { hypot($0.x - p.x, ($0.y - 12) - p.y) < 32 }) { return true }
        return false
    }

    func handBegan(_ p: CGPoint) {
        hand = p
        handStart = time
        handStill = 0
        handV = .zero
        handStartP = p
        if isOnSubmarineHull(p) {
            grab = .submarine
        } else if !isForegroundTarget(p), let i = decorAt(p) {
            grab = .maybeDecor(id: decor[i].id)
        } else if p.x > AGeo.left, p.x < AGeo.right, abs(p.y - surfaceY(p.x)) < 34 {
            grab = .surface
        } else if AGeo.tank.contains(p) {
            grab = .water
        } else {
            grab = .none
        }
    }

    func handMoved(_ p: CGPoint, dt: CGFloat) {
        guard let h = hand else { return }
        let v = CGVector(dx: (p.x - h.x) / dt, dy: (p.y - h.y) / dt)
        handV.dx += (v.dx - handV.dx) * 0.5
        handV.dy += (v.dy - handV.dy) * 0.5
        hand = p
        let moved = hypot(p.x - h.x, p.y - h.y)
        if moved > 1.5 { handStill = 0 }
        switch grab {
        case .submarine:
            if hypot(p.x - handStartP.x, p.y - handStartP.y) > 4 {
                steerSubmarineFromFinger(p)
            }
        case .maybeDecor(let id):
            if hypot(p.x - handStartP.x, p.y - handStartP.y) > 10, let i = decorIndex(id) {
                grab = .decor(id: id)
                decorTarget = CGPoint(x: decor[i].x, y: decor[i].y)
                decor[i].held = true
                decor[i].falling = false
                resolveSandLayout()
                AquaSound.shared.play(.pick, volume: 0.5)
                syncUIStateIfNeeded()
            }
        case .surface:
            let f = (p.x - AGeo.left) / AGeo.width * CGFloat(AGeo.surfaceNodes - 1)
            let c = max(0, min(AGeo.surfaceNodes - 1, Int(f.rounded())))
            sv[c] += handV.dy * 0.08 + abs(handV.dx) * 0.03
            if hypot(handV.dx, handV.dy) > 500 && CGFloat.random(in: 0...1) < 0.4 {
                emitParticle(
                    AquaParticle(
                        kind: .splash,
                        p: CGPoint(x: p.x, y: surfaceY(p.x) - 2),
                        v: CGVector(dx: handV.dx * 0.25 + CGFloat.random(in: -40...40), dy: CGFloat.random(in: -300 ... -120)),
                        life: 1,
                        size: CGFloat.random(in: 1.5...3),
                        color: ARGB(0xD8F4FF)
                    )
                )
                AquaSound.shared.play(.splish, volume: 0.35, gap: 0.18)
            }
        case .water:
            if hypot(handV.dx, handV.dy) > 700 {
                for i in fish.indices where !fish[i].caught && hypot(fish[i].p.x - p.x, fish[i].p.y - p.y) < 110 {
                    startle(i, from: p)
                }
            }
        default:
            break
        }
    }

    private func stepHand(_ dt: CGFloat) {
        guard let h = hand else { return }
        handStill += Double(dt)
        switch grab {
        case .decor(let id):
            guard decorIndex(id) != nil else { break }
            decorTarget = FingerLift.point(h, lift: FingerLift.item, top: AGeo.rimY, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
        case .water:
            if handStill > 0.35 {
                for i in fish.indices where !fish[i].caught && time > fish[i].fleeUntil {
                    if hypot(fish[i].p.x - h.x, fish[i].p.y - h.y) < 420 {
                        fish[i].curious = h
                        fish[i].curiousUntil = time + 0.6
                    }
                }
            }
        default:
            break
        }
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        defer {
            hand = nil
            grab = .none
            syncUIStateIfNeeded()
        }
        switch grab {
        case .submarine:
            if tap {
                if tapForeground(p) { return }
                for k in 0..<5 {
                    addBubble(
                        CGPoint(x: submarine.p.x - submarine.facing * 56, y: submarine.p.y - CGFloat(k) * 5),
                        r: CGFloat.random(in: 2.5...5.2)
                    )
                }
                AquaSound.shared.play(.bloop, volume: 0.6)
            }
            return
        case .decor(let id):
            guard let i = decorIndex(id) else { return }
            decor[i].held = false
            let decorMid = CGPoint(x: decor[i].x, y: decor[i].y - decor[i].kind.size.height * 0.5)
            // Only remove when explicitly dropped onto ReturnDropBadge — dropping anywhere else keeps it safely in the tank.
            if AGeo.inReturnZone(p) || AGeo.inReturnZone(decorMid) {
                bye(AGeo.returnBadgeCenter)
                AquaSound.shared.play(.swish, volume: 0.55)
                decor.remove(at: i)
                resolveSandLayout()
            } else {
                let halfW = decor[i].kind.size.width * 0.5
                decor[i].x = max(AGeo.left + halfW * 0.6, min(AGeo.right - halfW * 0.6, decor[i].x))
                decor[i].y = min(decor[i].y, AGeo.sand(decor[i].x))
                decor[i].falling = true
                decor[i].wet = decor[i].y - decor[i].kind.size.height * 0.5 > surfaceY(decor[i].x)
                decor[i].vy = handV.dy * 0.15
                decor[i].vx = handV.dx * 0.15
                AquaSound.shared.play(.swish, volume: 0.25)
            }
            return
        case .maybeDecor(let id):
            if tap {
                if tapForeground(p) { return }
                if let i = decorIndex(id) { pokeDecor(i) }
            }
            return
        default:
            break
        }
        guard tap else { return }
        if tapForeground(p) { return }
        if let i = decorAt(p) { pokeDecor(i); return }
        if AGeo.tank.contains(p) { tapGlass(p) }
    }

    private func tapForeground(_ p: CGPoint) -> Bool {
        if tapFloatingGift(p) { return true }
        if tapChestPearl(p) { return true }
        if tapVisitor(p) { return true }
        if let i = fishAt(p) {
            tapFish(i)
            return true
        }
        if tapBubbleHoop(p) { return true }
        if tapEgg(p) { return true }
        if tapHiddenSpot(p) { return true }
        if hypot(p.x - snail.p.x, p.y - snail.p.y) < 38 {
            snail.hideUntil = time + 2.8
            for k in 0..<3 {
                addBubble(CGPoint(x: snail.p.x + CGFloat(k * 5 - 5), y: snail.p.y - 12 - CGFloat(k) * 5), r: 2.2)
            }
            AquaSound.shared.play(.blub, volume: 0.45)
            return true
        }
        if tapClam(p) { return true }
        if let b = bubbles.indices.last(where: { hypot(bubbles[$0].p.x - p.x, bubbles[$0].p.y - p.y) < bubbles[$0].r + 18 && !bubbles[$0].back }) {
            let q = bubbles[b].p
            emitParticle(AquaParticle(kind: .ring, p: q, v: .zero, life: 0.3, size: bubbles[b].r * 2, color: ARGB(0xFFFFFF)))
            bubbles.remove(at: b)
            AquaSound.shared.play(.pop, volume: 0.6)
            return true
        }
        return false
    }

    func fishAt(_ p: CGPoint) -> Int? {
        var best: Int?
        var bz: CGFloat = -1
        for i in fish.indices where !fish[i].caught {
            let f = fish[i]
            let s = f.scale * (1 + f.puff * 0.3)
            let w = (f.kind.length * 0.5 + f.kind.tailLength * 0.5) * s + 16
            let h = f.kind.height * 0.5 * s + 18
            if abs(p.x - f.p.x) < w && abs(p.y - f.p.y) < h && f.z > bz { bz = f.z; best = i }
        }
        return best
    }

    func tapFish(_ i: Int) {
        guard fish.indices.contains(i) else { return }
        var poppedFromHideout = false
        if isFishSleeping(fish[i]) {
            fish[i].activity = .cruising
            fish[i].restUntil = -10
            fish[i].activityCooldown = time + 6.0
        } else if case .hiding(let decorID, _, _) = fish[i].activity {
            poppedFromHideout = true
            fish[i].activity = .cruising
            fish[i].activityCooldown = time + Double.random(in: 8...14)
            fish[i].flipStart = time
            let poppedDecor = decor.first(where: { $0.id == decorID })
            let dir: CGFloat = poppedDecor.map { fish[i].p.x <= $0.x ? -1 : 1 } ?? fish[i].dir
            fish[i].v = CGVector(dx: dir * 135, dy: -82)
            AquaSound.shared.play(.boing, volume: 0.6)
            if let d = poppedDecor {
                let dk = d.kind
                fulfillWishIfMatching({ wish in
                    if case .decorPlay(let wk, .hideout) = wish { return wk == dk }
                    return false
                }, at: fish[i].p)
            }
        }
        fish[i].happy = time
        fish[i].gulp = 1
        if !poppedFromHideout {
            fish[i].v.dx += fish[i].dir * 70
        }
        if fish[i].kind == .puffer {
            fish[i].puffUntil = time + 2.6
            AquaSound.shared.play(.puff, volume: 0.7)
        } else if !poppedFromHideout {
            AquaSound.shared.play(.blub, volume: 0.65)
        }
        if fish[i].variant >= AquaRare.variant {
            discover(AquaFind.rare(fish[i].kind), at: fish[i].p)
        }
        let m = mouth(fish[i])
        for k in 0..<3 { addBubble(CGPoint(x: m.x, y: m.y - CGFloat(k) * 7), r: 2 + CGFloat(k)) }
        emitParticle(
            AquaParticle(
                kind: .heart,
                p: CGPoint(x: fish[i].p.x, y: fish[i].p.y - 30),
                v: CGVector(dx: 0, dy: -46),
                life: 1.3,
                size: 16,
                color: ARGB(0xFF7FAE)
            )
        )
    }

    private func pokeDecor(_ i: Int) {
        guard decor.indices.contains(i) else { return }
        decor[i].poke = time
        decor[i].squashV = 5
        if decor[i].kind.sways { decor[i].swayV += 3 * (Bool.random() ? 1 : -1) }
        let pokedKind = decor[i].kind
        let pokedOrigin = CGPoint(x: decor[i].x, y: decor[i].y - decor[i].kind.size.height * 0.5)
        switch pokedKind {
        case .chest:
            var d = decor[i]
            openChest(&d)
            decor[i] = d
            revealChestPearl(i)
        case .bubbler:
            decor[i].boostUntil = time + 3.8
            for k in 0..<18 {
                addBubble(
                    CGPoint(x: decor[i].x + CGFloat.random(in: -22...22), y: decor[i].y - 26 - CGFloat(k) * 14),
                    r: CGFloat.random(in: 3...7.5)
                )
            }
            if floatingGifts.count < Self.maxFloatingGifts && !floatingGifts.contains(where: { $0.kind == .bubbleGift }) {
                spawnFloatingGift(.bubbleGift, at: CGPoint(x: decor[i].x, y: decor[i].y - 44))
            }
            AquaSound.shared.play(.bloop, volume: 0.7)
            AquaSound.shared.play(.splash, volume: 0.35, gap: 0.2)
        case .rock, .castle, .ship:
            var poppedAny = false
            for fi in fish.indices {
                if case .hiding(let hid, _, _) = fish[fi].activity, hid == decor[i].id {
                    poppedAny = true
                    fish[fi].activity = .cruising
                    fish[fi].activityCooldown = time + Double.random(in: 8...14)
                    fish[fi].happy = time
                    fish[fi].flipStart = time
                    let dir: CGFloat = fish[fi].p.x <= decor[i].x ? -1 : 1
                    fish[fi].v = CGVector(dx: dir * 135, dy: -82)
                    emitParticle(
                        AquaParticle(
                            kind: .heart,
                            p: CGPoint(x: fish[fi].p.x, y: fish[fi].p.y - 24),
                            v: CGVector(dx: 0, dy: -46),
                            life: 1.2,
                            size: 16,
                            color: ARGB(0xFF7FAE)
                        )
                    )
                }
            }
            for k in 0..<6 {
                addBubble(
                    CGPoint(x: decor[i].x + CGFloat.random(in: -20...20), y: decor[i].y - decor[i].kind.size.height * 0.7 - CGFloat(k) * 6),
                    r: CGFloat.random(in: 2...5)
                )
            }
            peekOctopus(near: i)
            AquaSound.shared.play(poppedAny ? .boing : .bloop, volume: 0.55)
            fulfillWishIfMatching({ wish in
                if case .decorPlay(let wk, _) = wish { return wk == pokedKind }
                return false
            }, at: pokedOrigin)
        case .shell, .crystal, .unicorn, .starfish:
            AquaSound.shared.play(.chime, volume: 0.45)
            for k in 0..<5 {
                let a = CGFloat(k) / 5 * 2 * .pi
                emitParticle(
                    AquaParticle(
                        kind: .sparkle,
                        p: CGPoint(x: decor[i].x + cos(a) * 20, y: decor[i].y - 26 + sin(a) * 14),
                        v: .zero,
                        life: 0.75,
                        size: 14,
                        color: ARGB(0xFFFFFF)
                    )
                )
            }
            fulfillWishIfMatching({ wish in
                if case .decorPlay(let wk, _) = wish { return wk == pokedKind }
                return false
            }, at: pokedOrigin)
        case .diver:
            for k in 0..<8 {
                addBubble(CGPoint(x: decor[i].x + CGFloat.random(in: -10...10), y: decor[i].y - 114 - CGFloat(k) * 8), r: CGFloat.random(in: 2.2...5.2))
            }
            AquaSound.shared.play(.bloop, volume: 0.55)
        case .koiBridge:
            for k in 0..<8 {
                addBubble(
                    CGPoint(x: decor[i].x + CGFloat.random(in: -26...26), y: decor[i].y - 18 - CGFloat(k) * 9),
                    r: CGFloat.random(in: 2.4...5.4)
                )
            }
            for k in 0..<4 {
                let a = CGFloat(k) / 4 * 2 * .pi
                emitParticle(
                    AquaParticle(
                        kind: .sparkle,
                        p: CGPoint(x: decor[i].x + cos(a) * 32, y: decor[i].y - 48 + sin(a) * 14),
                        v: .zero,
                        life: 0.75,
                        size: 13,
                        color: ARGB(0xFFE68A)
                    )
                )
            }
            if let swimmer = fish.indices
                .filter({ !fish[$0].caught && fish[$0].activity == .cruising })
                .min(by: { hypot(fish[$0].p.x - decor[i].x, fish[$0].p.y - decor[i].y) < hypot(fish[$1].p.x - decor[i].x, fish[$1].p.y - decor[i].y) }) {
                _ = sendFish(swimmer, toDecor: i, role: .swimThrough)
            }
            fulfillWishIfMatching({ wish in
                if case .decorPlay(let wk, _) = wish { return wk == .koiBridge }
                return false
            }, at: pokedOrigin)
            AquaSound.shared.play(.chime, volume: 0.45)
            AquaSound.shared.play(.bloop, volume: 0.5, gap: 0.16)
        default:
            AquaSound.shared.play(.boing, volume: 0.4)
            fulfillWishIfMatching({ wish in
                if case .decorPlay(let wk, _) = wish { return wk == pokedKind }
                return false
            }, at: pokedOrigin)
        }
    }

    private func tapGlass(_ p: CGPoint) {
        AquaSound.shared.play(.tink, volume: 0.6)
        emitParticle(AquaParticle(kind: .ring, p: p, v: .zero, life: 0.5, size: 34, color: ARGB(0xFFFFFF)))
        for i in fish.indices where !fish[i].caught {
            if hypot(fish[i].p.x - p.x, fish[i].p.y - p.y) < 300 { startle(i, from: p) }
        }
    }

    private func startle(_ i: Int, from p: CGPoint) {
        var f = fish[i]
        let dx = f.p.x - p.x, dy = f.p.y - p.y
        let d = max(1, hypot(dx, dy))
        f.flee = CGVector(dx: dx / d, dy: dy / d)
        f.fleeUntil = time + Double.random(in: 0.5...0.9)
        f.curious = p
        f.curiousUntil = time + Double.random(in: 3.5...5)
        if f.kind == .puffer { f.puffUntil = time + 2.4; AquaSound.shared.play(.puff, volume: 0.5, gap: 0.5) }
        fish[i] = f
    }

    // MARK: - Carried Tools

    func pickUp(_ t: AquaTool, at p: CGPoint) {
        tool = t
        finger = p
        toolP = p
        hold = p
        toolV = .zero
        lastToolV = .zero
        tilt = 0
        tiltV = 0
        shake = 0
        caught = nil
        returning = nil
        quickAction = nil
        switch t {
        case .food: AquaSound.shared.play(.shake, volume: 0.5)
        case .wiper: AquaSound.shared.play(.pick, volume: 0.5)
        case .hoop: AquaSound.shared.play(.bloop, volume: 0.5)
        case .net:
            AquaSound.shared.play(.swish, volume: 0.4)
            if AGeo.inWater(p) { scoop(at: p) }
        case .egg: AquaSound.shared.play(.pick, volume: 0.55)
        case .fish: AquaSound.shared.play(.bag, volume: 0.6)
        case .decor: AquaSound.shared.play(.pick, volume: 0.5)
        }
        syncUIStateIfNeeded()
    }

    private func scoop(at point: CGPoint) {
        if collectFloatingGifts(near: point, radius: 48) > 0 { return }
        if !demo,
           let chestPearl = openChestPearlOrigin(),
           !isFindClaimed(.pearl),
           hypot(chestPearl.x - point.x, chestPearl.y - point.y) <= 46 {
            discover(.pearl, at: chestPearl)
            if time - lastGiftCoinAt >= Self.coinCooldown {
                lastGiftCoinAt = time
                queueCoin(2, from: chestPearl)
            }
            return
        }
        guard caught == nil else { return }
        var nearest = fishAt(point)
        if nearest == nil {
            var best: CGFloat = 50 * 50
            for i in fish.indices where !fish[i].caught {
                let dx = fish[i].p.x - point.x, dy = fish[i].p.y - point.y
                let distance = dx * dx + dy * dy
                if distance < best { best = distance; nearest = i }
            }
        }
        if let i = nearest {
            fish[i].caught = true
            caught = fish[i].id
            AquaSound.shared.play(.blub, volume: 0.6)
        }
    }

    func carry(to p: CGPoint, hand h: CGPoint? = nil) {
        finger = p
        hold = h ?? CGPoint(x: p.x, y: p.y + FingerLift.tool)
    }

    func release(home: CGPoint) {
        guard let t = tool else { return }
        let over = AGeo.overTank(toolP) && finger.y < AGeo.bottomY + 40
        switch t {
        case .fish(let k) where over:
            addFish(k, x: toolP.x, y: toolP.y)
        case .egg where over:
            _ = dropEgg(at: toolP.x, y: toolP.y)
        case .decor(let k) where over:
            let i = addDecor(k, x: toolP.x, falling: true, y: min(toolP.y + k.size.height * 0.5, AGeo.sand(toolP.x)))
            decor[i].rot = tilt
            decor[i].vx = toolV.dx * 0.15
            decor[i].vy = max(0, toolV.dy * 0.2)
            AquaSound.shared.play(.swish, volume: 0.4)
        case .hoop where over:
            spawnBubbleHoop(at: toolP)
            returning = (t, toolP, home, time, tilt)
        default:
            if case .net = t, let id = caught, let i = fish.firstIndex(where: { $0.id == id }) {
                // Only remove the caught fish when explicitly dropped onto ReturnDropBadge.
                if AGeo.inReturnZone(hold) || AGeo.inReturnZone(toolP) {
                    bye(AGeo.returnBadgeCenter)
                    AquaSound.shared.play(.chime, volume: 0.45)
                    fish.remove(at: i)
                } else {
                    fish[i].caught = false
                    let safeX = max(AGeo.left + 54, min(AGeo.right - 54, toolP.x))
                    let safeY = max(surfaceY(safeX) + 22, min(AGeo.sand(safeX) - 42, toolP.y))
                    fish[i].p = CGPoint(x: safeX, y: safeY)
                    fish[i].v = CGVector(dx: fish[i].dir * 130, dy: 24)
                    fish[i].happy = time
                    if toolP.y < surfaceY(safeX) { splash(at: safeX, strength: 0.55) } else { AquaSound.shared.play(.blub, volume: 0.5) }
                }
            }
            returning = (t, toolP, home, time, tilt)
        }
        caught = nil
        tool = nil
        syncUIStateIfNeeded()
    }

    private func stepTool(_ dt: CGFloat) {
        guard let t = tool else { return }
        let prev = toolP
        let wasWet = AGeo.inWater(prev)
        let follow: CGFloat = t == .net || t == .food ? 1 : min(1, dt * 30)
        toolP.x += (finger.x - toolP.x) * follow
        toolP.y += (finger.y - toolP.y) * follow
        let vx = (toolP.x - prev.x) / dt
        let vy = (toolP.y - prev.y) / dt
        lastToolV = toolV
        toolV.dx += (vx - toolV.dx) * min(1, dt * 18)
        toolV.dy += (vy - toolV.dy) * min(1, dt * 18)
        let jerk = hypot(toolV.dx - lastToolV.dx, toolV.dy - lastToolV.dy) / dt
        shake = max(shake * exp(-dt * 4), min(3, jerk / 4000))
        let over = AGeo.overTank(toolP)
        let wet = AGeo.inWater(toolP)
        if wet != wasWet && hypot(toolV.dx, toolV.dy) > 150 && (t == .net || t == .hoop) {
            splash(at: toolP.x, strength: 0.35)
        }

        var target: CGFloat = 0
        switch t {
        case .food:
            target = over ? 1.98 + sin(CGFloat(time) * 14) * 0.06 * shake : 0
            if over {
                foodAcc += dt * (4.5 + min(1, shake) * 6)
                while foodAcc > 1 {
                    foodAcc -= 1
                    addFlake(
                        at: CGPoint(x: toolP.x + CGFloat.random(in: -6...6) * FingerLift.spread * 2, y: toolP.y + 4),
                        v: CGVector(dx: toolV.dx * 0.25 + CGFloat.random(in: -38...38), dy: max(0, toolV.dy * 0.25) + CGFloat.random(in: 24...82))
                    )
                }
                if shake > 0.3 { AquaSound.shared.play(.shake, volume: Float(min(0.6, 0.2 + shake * 0.2)), gap: 0.2) }
            }
        case .wiper:
            target = max(-0.32, min(0.32, toolV.dx * 0.0005))
            if over {
                let moved = hypot(toolP.x - prev.x, toolP.y - prev.y)
                if moved > 0.3 {
                    let off = wipe(at: toolP, radius: 56 * FingerLift.spread, amount: min(0.35, moved * 0.015), sparkle: true)
                    if off > 0.01 && CGFloat.random(in: 0...1) < min(1, off * 4) {
                        emitParticle(
                            AquaParticle(
                                kind: .moss,
                                p: CGPoint(x: toolP.x + CGFloat.random(in: -28...28) * FingerLift.spread, y: toolP.y + 22),
                                v: CGVector(dx: 0, dy: 12),
                                life: 2.5,
                                size: CGFloat.random(in: 2.2...4.0),
                                color: ARGB(0x7CD4A0)
                            )
                        )
                    }
                    let sp = hypot(toolV.dx, toolV.dy)
                    if sp > 120 && time - squeakAt > 0.2 {
                        squeakAt = time
                        AquaSound.shared.play(.squeak, volume: Float(min(0.65, 0.2 + sp / 1400)))
                    }
                }
            }
        case .hoop:
            target = max(-0.3, min(0.3, toolV.dx * 0.0005))
            if wet && CGFloat.random(in: 0...1) < dt * 8 {
                addBubble(CGPoint(x: toolP.x + CGFloat.random(in: -20...20), y: toolP.y + CGFloat.random(in: -24...24)), r: CGFloat.random(in: 2...4.5))
            }
        case .net:
            target = max(-0.5, min(0.5, toolV.dx * -0.0008))
            if wet { scoop(at: toolP) }
            if let id = caught, let i = fish.firstIndex(where: { $0.id == id }) {
                fish[i].p = CGPoint(x: toolP.x, y: toolP.y + 8)
                fish[i].v = toolV
            }
            if wet {
                for i in fish.indices where !fish[i].caught && fish[i].id != caught {
                    if hypot(fish[i].p.x - toolP.x, fish[i].p.y - toolP.y) < 110 && hypot(toolV.dx, toolV.dy) > 420 {
                        startle(i, from: toolP)
                    }
                }
            }
        case .fish, .decor, .egg:
            target = max(-0.35, min(0.35, toolV.dx * 0.0007))
        }
        tiltV += ((target - tilt) * 70 - tiltV * 11) * dt
        tilt += tiltV * dt
    }
}

extension CGFloat {
    var sign1: CGFloat { self < 0 ? -1 : 1 }
}
