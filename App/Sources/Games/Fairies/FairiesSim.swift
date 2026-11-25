import SwiftUI

struct RevealedMeadowFairy: Equatable {
    let kind: FairyKind
    let fromSpot: MeadowSpot
    let anchor: CGPoint
    var position: CGPoint
    let appearedAt: Double
    var caughtAt: Double?
    let phase: Double
}

struct CatchCelebration: Equatable {
    let kind: FairyKind
    let startPos: CGPoint
    let startedAt: Double
    let isNew: Bool
}

struct WandAutoSweep: Equatable {
    let start: CGPoint
    let target: CGPoint
    let startedAt: Double
    let duration: Double
    let targetSpot: MeadowSpot?
    let catchingFairy: Bool
    var triggered: Bool = false
}

struct WandSparkle: Equatable {
    var pos: CGPoint
    var age: CGFloat
    var maxAge: CGFloat
    var size: CGFloat
    var colorHex: UInt32
}

enum FairyParticleKind: Equatable {
    case heart
    case star
    case bubble
    case note
    case petal
    case sleepyZ
}

struct FairyParticle: Equatable {
    var kind: FairyParticleKind
    var pos: CGPoint
    var vel: CGVector
    var age: CGFloat
    var maxAge: CGFloat
    var size: CGFloat
    var colorHex: UInt32
    var phase: CGFloat
}

final class FairiesSim: ObservableObject {
    static let gameID = "fairies"
    static let saveFile = "fairies.json"
    static let catchCoinReward = 4
    static let repeatCoinCooldown: Double = 10.0

    @Published var mode: FairiesMode = .meadow
    @Published private(set) var befriended: [FairyKind]
    @Published private(set) var spotOccupants: [CompactSpot: FairyKind]
    @Published private(set) var accessories: [FairyKind: FairyAccessory]
    @Published var selectedFairy: FairyKind
    @Published private(set) var pinnedFairy: FairyKind?
    @Published private(set) var totalCatches: Int
    @Published private(set) var draggingCompactFairy: FairyKind?
    @Published private(set) var compactReturnHovered = false
    @Published private(set) var hasCompactBadge = false
    @Published private(set) var wandHeld = false

    // 60fps simulation properties stepped inside Canvas TimelineView without invalidating SwiftUI layout.
    var time: Double = 0
    private var lastTick: Date?
    var rustlingSpots: Set<MeadowSpot> = []
    var spotWiggleUntil: [MeadowSpot: Double] = [:]
    var chimeSwingUntil: [MeadowChime: Double] = [:]
    var revealedFairy: RevealedMeadowFairy?
    var celebration: CatchCelebration?
    var wandTip: CGPoint?
    var wandFinger: CGPoint?
    var wandSweep: WandAutoSweep?
    var wandTrail: [WandSparkle] = []
    var particles: [FairyParticle] = []
    var compactDragPos: CGPoint = .zero
    var compactDragOriginSpot: CompactSpot?
    var compactHoverSpot: CompactSpot?
    var compactSpotReactUntil: [CompactSpot: Double] = [:]
    var compactOpenAt: Double = -10
    var pendingPlacementFairy: FairyKind?

    var quiet = false
    var demo = false
    private(set) var lastCoinAwardTime: Double = -100
    private(set) var unlockedFinds: Set<FairiesFind> = []

    var hasChandelier: Bool { Coins.shared.owns("fairies/chandelier") }
    var hasCarousel: Bool { Coins.shared.owns("fairies/carousel") }
    var hasHanbokTea: Bool { Coins.shared.owns("fairies/hanbokTea") }

    private let userDefaults: UserDefaults
    private let persist: Bool
    private let storageGameID: String
    private var ambientTimer: Double = 0
    private var wandLastSpotCheck: [MeadowSpot: Double] = [:]
    private var wandLastChimeCheck: [MeadowChime: Double] = [:]

    init(
        persist: Bool = true,
        storageGameID: String = FairiesSim.gameID,
        userDefaults: UserDefaults = .standard
    ) {
        self.persist = persist
        self.storageGameID = storageGameID
        self.userDefaults = userDefaults

        let loaded = persist
            ? (GameStorage.load(FairiesSave.self, game: storageGameID, file: Self.saveFile) ?? .starter)
            : .starter

        self.befriended = loaded.befriended
        self.spotOccupants = loaded.spotOccupants
        self.accessories = loaded.accessories
        self.selectedFairy = loaded.pinnedFairy ?? loaded.befriended.first ?? .heart
        self.pinnedFairy = loaded.pinnedFairy
        self.totalCatches = loaded.totalCatches

        syncPinnedFairyDefaults()
        ensureRustlingSpots()
    }

    // MARK: - Persistence & Dress Up Pinned Fairy Sync

    func currentSave() -> FairiesSave {
        FairiesSave(
            befriended: befriended,
            spotOccupants: spotOccupants,
            accessories: accessories,
            pinnedFairy: pinnedFairy,
            totalCatches: totalCatches
        )
    }

    func save() {
        guard persist, !demo else { return }
        GameStorage.save(currentSave(), game: storageGameID, file: Self.saveFile)
    }

    func syncPinnedFairyDefaults() {
        if let pinned = pinnedFairy {
            userDefaults.set(pinned.rawValue, forKey: FairyKind.pinnedDefaultsKey)
        } else {
            userDefaults.removeObject(forKey: FairyKind.pinnedDefaultsKey)
        }
    }

    // MARK: - Mode Switching

    func switchMode(_ newMode: FairiesMode) {
        guard mode != newMode else { return }
        endWand()
        cancelCompactDrag()
        mode = newMode
        play(.flip, volume: 0.65)
        hapticTap()
        if newMode == .compact {
            hasCompactBadge = false
            compactOpenAt = time
            emitBurst(.star, at: FGeo.compactCenter, count: 14, colorHex: 0xFFE38A)
        } else {
            ensureRustlingSpots()
        }
    }

    // MARK: - Simulation Step

    func step(_ now: Date) {
        let dt: CGFloat
        if let prev = lastTick {
            dt = CGFloat(min(1.0 / 20, max(1.0 / 240, now.timeIntervalSince(prev))))
        } else {
            dt = 1.0 / 60
        }
        lastTick = now
        step(dt: dt)
    }

    func resetClock() {
        lastTick = nil
    }

    func step(dt: CGFloat) {
        let clamped = min(CGFloat(0.05), max(CGFloat(0.001), dt))
        time += Double(clamped)

        stepRevealedFairy()
        stepCelebration()
        stepWandSweep(clamped)
        stepWandTrail(clamped)
        stepParticles(clamped)
        stepAmbient(clamped)
    }

    private func stepRevealedFairy() {
        guard var rev = revealedFairy else {
            if mode == .meadow && celebration == nil && rustlingSpots.isEmpty {
                ensureRustlingSpots()
            }
            return
        }

        if let caughtAt = rev.caughtAt {
            if time - caughtAt > 0.25 {
                revealedFairy = nil
            }
            return
        }

        let elapsed = time - rev.appearedAt
        if elapsed > 28 {
            emitBurst(.star, at: rev.position, count: 6, colorHex: rev.kind.palette.emblem)
            revealedFairy = nil
            ensureRustlingSpots()
            return
        }

        let popT = CGFloat(min(1, elapsed / 0.42))
        let inv = 1 - popT
        let easedPop = 1 - inv * inv * inv
        let bobX = CGFloat(sin(elapsed * 2.1 + rev.phase)) * 34
        let bobY = CGFloat(sin(elapsed * 3.4 + rev.phase * 1.3)) * 18
        let startP = rev.fromSpot.popOrigin
        rev.position = CGPoint(
            x: startP.x + (rev.anchor.x - startP.x) * easedPop + bobX * easedPop,
            y: startP.y + (rev.anchor.y - startP.y) * easedPop + bobY * easedPop
        )
        revealedFairy = rev
    }

    private func stepCelebration() {
        guard let c = celebration else { return }
        if time - c.startedAt >= 1.35 {
            celebration = nil
            if mode == .meadow && revealedFairy == nil {
                ensureRustlingSpots()
            }
        }
    }

    private func stepWandSweep(_ dt: CGFloat) {
        guard var sweep = wandSweep else { return }
        let elapsed = time - sweep.startedAt
        let u = CGFloat(min(1, max(0, elapsed / sweep.duration)))
        let e = u * u * (3 - 2 * u)
        let arcY = -sin(e * .pi) * 86
        let p = CGPoint(
            x: sweep.start.x + (sweep.target.x - sweep.start.x) * e,
            y: sweep.start.y + (sweep.target.y - sweep.start.y) * e + arcY
        )
        wandTip = p
        wandFinger = CGPoint(x: p.x + 48, y: p.y + 72)
        appendWandSparkle(at: p)

        if !sweep.triggered && u >= 0.72 {
            sweep.triggered = true
            wandSweep = sweep
            if sweep.catchingFairy {
                _ = befriendRevealedFairy(viaWand: true)
            } else if let spot = sweep.targetSpot {
                _ = coaxSpot(spot, viaWand: true)
            }
        }

        if u >= 1 {
            wandSweep = nil
            if !wandHeld {
                wandTip = nil
                wandFinger = nil
            }
        }
    }

    private func stepWandTrail(_ dt: CGFloat) {
        for i in wandTrail.indices.reversed() {
            wandTrail[i].age += dt
            if wandTrail[i].age >= wandTrail[i].maxAge {
                wandTrail.remove(at: i)
            }
        }
    }

    private func stepParticles(_ dt: CGFloat) {
        for i in particles.indices.reversed() {
            particles[i].age += dt
            if particles[i].age >= particles[i].maxAge {
                particles.remove(at: i)
                continue
            }
            particles[i].pos.x += particles[i].vel.dx * dt
            particles[i].pos.y += particles[i].vel.dy * dt
            switch particles[i].kind {
            case .bubble, .sleepyZ, .note, .heart:
                particles[i].pos.x += sin(CGFloat(time) * 3.2 + particles[i].phase) * 18 * dt
            case .petal:
                particles[i].vel.dy += 16 * dt
                particles[i].pos.x += cos(CGFloat(time) * 2.5 + particles[i].phase) * 24 * dt
            case .star:
                particles[i].vel.dx *= (1 - 1.6 * dt)
                particles[i].vel.dy *= (1 - 1.6 * dt)
            }
        }
    }

    private func stepAmbient(_ dt: CGFloat) {
        ambientTimer += Double(dt)
        guard ambientTimer >= 0.28 else { return }
        ambientTimer = 0

        if mode == .meadow {
            for spot in rustlingSpots {
                let p = CGPoint(
                    x: spot.center.x + CGFloat.random(in: -36...36),
                    y: spot.center.y + CGFloat.random(in: -34...10)
                )
                spawnParticle(.star, at: p, vel: CGVector(dx: CGFloat.random(in: -8...8), dy: -26), maxAge: 1.0, size: CGFloat.random(in: 7...12), colorHex: spot.shimmerHex)
            }
            if let rev = revealedFairy, rev.caughtAt == nil {
                spawnParticle(
                    .heart,
                    at: CGPoint(x: rev.position.x + CGFloat.random(in: -24...24), y: rev.position.y - 20),
                    vel: CGVector(dx: CGFloat.random(in: -12...12), dy: -36),
                    maxAge: 1.15,
                    size: CGFloat.random(in: 10...15),
                    colorHex: rev.kind.palette.emblem
                )
            }
        } else {
            for (spot, fairy) in spotOccupants {
                let base = CGPoint(x: spot.center.x + spot.fairyOffset.x, y: spot.center.y + spot.fairyOffset.y)
                switch spot {
                case .cloudBed:
                    if Int(time * 3) % 2 == 0 {
                        spawnParticle(.sleepyZ, at: CGPoint(x: base.x + 22, y: base.y - 26), vel: CGVector(dx: 10, dy: -28), maxAge: 1.4, size: 12, colorHex: 0xC9B6FF)
                    }
                case .teacupBath:
                    spawnParticle(.bubble, at: CGPoint(x: base.x + CGFloat.random(in: -26...26), y: base.y + 8), vel: CGVector(dx: CGFloat.random(in: -8...8), dy: -36), maxAge: 1.35, size: CGFloat.random(in: 8...14), colorHex: 0xBCEEFF)
                case .danceStage:
                    spawnParticle(.note, at: CGPoint(x: base.x + CGFloat.random(in: -34...34), y: base.y - 22), vel: CGVector(dx: CGFloat.random(in: -14...14), dy: -34), maxAge: 1.25, size: 13, colorHex: fairy.palette.emblem)
                case .treatTable:
                    if Int(time * 4) % 2 == 0 {
                        spawnParticle(.heart, at: CGPoint(x: base.x + CGFloat.random(in: -18...18), y: base.y - 24), vel: CGVector(dx: 6, dy: -28), maxAge: 1.1, size: 11, colorHex: 0xFF8FB8)
                    }
                case .rainbowSwing:
                    if Int(time * 4) % 2 == 0 {
                        spawnParticle(.star, at: CGPoint(x: base.x + CGFloat.random(in: -24...24), y: base.y - 20), vel: CGVector(dx: CGFloat.random(in: -12...12), dy: -22), maxAge: 1.0, size: 9, colorHex: 0xFFE38A)
                    }
                }
            }
            if hasChandelier && Int(time * 3) % 3 == 0 {
                spawnParticle(
                    .star,
                    at: CGPoint(x: FGeo.compactCenter.x + CGFloat.random(in: -38...38), y: 274 + CGFloat.random(in: -8...12)),
                    vel: CGVector(dx: CGFloat.random(in: -8...8), dy: 14),
                    maxAge: 1.1,
                    size: CGFloat.random(in: 7...11),
                    colorHex: 0xFFE38A
                )
            }
            if hasCarousel && Int(time * 3) % 4 == 1 {
                spawnParticle(
                    .star,
                    at: CGPoint(x: 396 + CGFloat.random(in: -24...24), y: 404 + CGFloat.random(in: -10...10)),
                    vel: CGVector(dx: CGFloat.random(in: -10...10), dy: -20),
                    maxAge: 1.0,
                    size: CGFloat.random(in: 7...10),
                    colorHex: 0xFFB8E0
                )
            }
        }
    }

    // MARK: - Mode A: Sparkle Meadow

    func ensureRustlingSpots() {
        let unbefriended = FairyKind.allCases.filter { !befriended.contains($0) }
        var candidates = MeadowSpot.allCases
        if !unbefriended.isEmpty {
            let preferred = Set(unbefriended.map(\.preferredSpot))
            if !preferred.isEmpty {
                candidates = Array(preferred)
            }
        }
        if rustlingSpots.count < 2 {
            let shuffled = candidates.shuffled()
            for spot in shuffled where rustlingSpots.count < 2 {
                rustlingSpots.insert(spot)
            }
            for spot in MeadowSpot.allCases.shuffled() where rustlingSpots.count < 2 {
                rustlingSpots.insert(spot)
            }
        }
    }

    func pickNextFairy(for spot: MeadowSpot) -> FairyKind {
        let unbefriended = FairyKind.allCases.filter { !befriended.contains($0) }
        if !unbefriended.isEmpty {
            let matching = unbefriended.filter { $0.preferredSpot == spot }
            return (matching.isEmpty ? unbefriended : matching).randomElement() ?? unbefriended[0]
        }
        let matchingAll = FairyKind.allCases.filter { $0.preferredSpot == spot }
        return matchingAll.randomElement() ?? FairyKind.allCases.randomElement() ?? .heart
    }

    @discardableResult
    func coaxSpot(_ spot: MeadowSpot, viaWand: Bool = false) -> FairyKind? {
        spotWiggleUntil[spot] = time + 0.72
        emitSpotParticles(spot, count: 10)
        if viaWand {
            discover(.wandMagic, at: spot.center)
        }

        if let existing = revealedFairy, existing.caughtAt == nil, existing.fromSpot == spot {
            play(.sparkle, volume: 0.6)
            emitBurst(.heart, at: existing.position, count: 6, colorHex: existing.kind.palette.emblem)
            return existing.kind
        }

        let shouldReveal = rustlingSpots.contains(spot) || revealedFairy == nil
        guard shouldReveal else {
            play(spot == .bubbleFountain ? .bubble : .pop, volume: 0.65)
            hapticTap()
            return nil
        }

        let kind = pickNextFairy(for: spot)
        return revealFairy(kind, from: spot)
    }

    @discardableResult
    func revealFairy(_ kind: FairyKind, from spot: MeadowSpot) -> FairyKind {
        let anchorX = max(175, min(850, spot.center.x + (spot.center.x > 512 ? -24 : 24)))
        let anchorY: CGFloat = spot == .teacupLantern ? 276 : 292
        let anchor = CGPoint(x: anchorX, y: anchorY)
        revealedFairy = RevealedMeadowFairy(
            kind: kind,
            fromSpot: spot,
            anchor: anchor,
            position: spot.popOrigin,
            appearedAt: time,
            caughtAt: nil,
            phase: Double.random(in: 0...(2 * .pi))
        )
        rustlingSpots.removeAll()
        spotWiggleUntil[spot] = time + 0.85
        play(spot == .bubbleFountain ? .bubble : .boing, volume: 0.6)
        play(.sparkle, volume: 0.7)
        hapticTap()
        emitBurst(.star, at: spot.popOrigin, count: 10, colorHex: kind.palette.emblem)
        emitBurst(.heart, at: spot.popOrigin, count: 6, colorHex: 0xFF8FB8)
        return kind
    }

    @discardableResult
    func ringChime(_ chime: MeadowChime) -> FairyKind? {
        chimeSwingUntil[chime] = time + 1.15
        play(chime.sfx, volume: 0.85)
        hapticTap()
        emitBurst(.note, at: chime.center, count: 7, colorHex: chime.colorHex)
        emitBurst(.star, at: chime.center, count: 5, colorHex: 0xFFE38A)
        discover(.musicChime, at: chime.center)

        if let rev = revealedFairy, rev.caughtAt == nil {
            emitBurst(.heart, at: rev.position, count: 6, colorHex: rev.kind.palette.emblem)
            return rev.kind
        }

        ensureRustlingSpots()
        let targetSpot = rustlingSpots.first ?? MeadowSpot.allCases.randomElement() ?? .blossomBush
        let kind = pickNextFairy(for: targetSpot)
        return revealFairy(kind, from: targetSpot)
    }

    @discardableResult
    func befriendRevealedFairy(viaWand: Bool = false) -> FairyKind? {
        guard var rev = revealedFairy, rev.caughtAt == nil else { return nil }
        rev.caughtAt = time
        revealedFairy = rev

        let kind = rev.kind
        let pos = rev.position
        let isNew = !befriended.contains(kind)
        if isNew {
            befriended.append(kind)
            selectedFairy = kind
            hasCompactBadge = true
        }
        totalCatches += 1
        celebration = CatchCelebration(kind: kind, startPos: pos, startedAt: time, isNew: isNew)

        play(.fanfare, volume: 0.7)
        play(.cheer, volume: 0.45)
        hapticTap()
        emitBurst(.heart, at: pos, count: 16, colorHex: kind.palette.emblem)
        emitBurst(.star, at: pos, count: 14, colorHex: 0xFFE38A)

        if isNew || (time - lastCoinAwardTime >= Self.repeatCoinCooldown) {
            lastCoinAwardTime = time
            earnCoins(Self.catchCoinReward, from: pos)
        }

        discover(.firstFairy, at: pos)
        if viaWand {
            discover(.wandMagic, at: pos)
        }
        if befriended.count >= 6 {
            discover(.rainbowCollection, at: pos)
        }
        if kind == .silk {
            discover(.silkFairy, at: pos)
        }

        save()
        return kind
    }

    func tapMeadow(at point: CGPoint) {
        if let rev = revealedFairy, rev.caughtAt == nil,
           hypot(point.x - rev.position.x, point.y - rev.position.y) <= 78 {
            _ = befriendRevealedFairy(viaWand: false)
            return
        }

        for chime in MeadowChime.allCases {
            if hypot(point.x - chime.center.x, point.y - chime.center.y) <= chime.hitRadius {
                _ = ringChime(chime)
                return
            }
        }

        for spot in MeadowSpot.allCases {
            if hypot(point.x - spot.center.x, point.y - spot.center.y) <= spot.hitRadius {
                _ = coaxSpot(spot, viaWand: false)
                return
            }
        }

        emitBurst(.star, at: point, count: 5, colorHex: 0xFFE38A)
        play(.tap, volume: 0.4)
    }

    // MARK: - Heart Magic Wand

    func beginWand(finger: CGPoint, lifted: CGPoint) {
        wandSweep = nil
        wandHeld = true
        wandFinger = finger
        wandTip = lifted
        play(.sparkle, volume: 0.5)
        hapticTap()
        appendWandSparkle(at: lifted)
        checkWandInteractions(at: lifted)
    }

    func moveWand(finger: CGPoint, lifted: CGPoint) {
        wandFinger = finger
        wandTip = lifted
        appendWandSparkle(at: lifted)
        checkWandInteractions(at: lifted)
    }

    func endWand() {
        wandHeld = false
        if wandSweep == nil {
            wandTip = nil
            wandFinger = nil
        }
    }

    func triggerWandTapMagic() {
        guard mode == .meadow else { return }
        play(.sparkle, volume: 0.75)
        hapticTap()

        if let rev = revealedFairy, rev.caughtAt == nil {
            wandSweep = WandAutoSweep(
                start: CGPoint(x: FGeo.wandHomeCenter.x, y: FGeo.wandHomeCenter.y - 60),
                target: rev.position,
                startedAt: time,
                duration: 0.55,
                targetSpot: nil,
                catchingFairy: true
            )
            return
        }

        ensureRustlingSpots()
        let targetSpot = rustlingSpots.first ?? .blossomBush
        wandSweep = WandAutoSweep(
            start: CGPoint(x: FGeo.wandHomeCenter.x, y: FGeo.wandHomeCenter.y - 60),
            target: targetSpot.center,
            startedAt: time,
            duration: 0.58,
            targetSpot: targetSpot,
            catchingFairy: false
        )
    }

    private func checkWandInteractions(at tip: CGPoint) {
        if let rev = revealedFairy, rev.caughtAt == nil,
           hypot(tip.x - rev.position.x, tip.y - rev.position.y) <= 78 {
            _ = befriendRevealedFairy(viaWand: true)
            return
        }

        for chime in MeadowChime.allCases {
            if hypot(tip.x - chime.center.x, tip.y - chime.center.y) <= chime.hitRadius + 10 {
                let last = wandLastChimeCheck[chime] ?? -10
                if time - last >= 0.75 {
                    wandLastChimeCheck[chime] = time
                    _ = ringChime(chime)
                }
                return
            }
        }

        for spot in MeadowSpot.allCases {
            if hypot(tip.x - spot.center.x, tip.y - spot.center.y) <= spot.hitRadius + 14 {
                let last = wandLastSpotCheck[spot] ?? -10
                if time - last >= 0.9 {
                    wandLastSpotCheck[spot] = time
                    _ = coaxSpot(spot, viaWand: true)
                }
                return
            }
        }
    }

    private func appendWandSparkle(at pos: CGPoint) {
        let colors: [UInt32] = [0xFF8FB8, 0xFFE38A, 0xC9B6FF, 0x9FE3CF, 0x9CCBFF]
        let hex = colors[wandTrail.count % colors.count]
        wandTrail.append(WandSparkle(
            pos: CGPoint(x: pos.x + CGFloat.random(in: -8...8), y: pos.y + CGFloat.random(in: -8...8)),
            age: 0,
            maxAge: 0.55,
            size: CGFloat.random(in: 8...15),
            colorHex: hex
        ))
        if wandTrail.count > 44 {
            wandTrail.removeFirst(wandTrail.count - 44)
        }
    }

    // MARK: - Mode B: Heart Jewel Compact Dollhouse

    func spot(containing fairy: FairyKind) -> CompactSpot? {
        spotOccupants.first(where: { $0.value == fairy })?.key
    }

    func selectFairy(_ fairy: FairyKind, readyToPlace: Bool = false) {
        guard befriended.contains(fairy) else { return }
        selectedFairy = fairy
        pendingPlacementFairy = readyToPlace ? fairy : nil
        play(.pop, volume: 0.55)
        hapticTap()
        if let spot = spot(containing: fairy) {
            compactSpotReactUntil[spot] = time + 0.8
        }
    }

    @discardableResult
    func placeFairy(_ fairy: FairyKind, at spot: CompactSpot) -> Bool {
        guard befriended.contains(fairy) else { return false }
        let oldSpot = self.spot(containing: fairy)
        let displaced = spotOccupants[spot]

        if let old = oldSpot {
            spotOccupants.removeValue(forKey: old)
        }
        if let displaced, displaced != fairy, let old = oldSpot {
            spotOccupants[old] = displaced
        }

        spotOccupants[spot] = fairy
        selectedFairy = fairy
        pendingPlacementFairy = nil
        compactSpotReactUntil[spot] = time + 1.35

        playCompactSpotSound(spot)
        hapticTap()
        emitCompactSpotParticles(spot, fairy: fairy)

        if spotOccupants.count >= 3 {
            discover(.compactParty, at: spot.center)
        }
        save()
        return true
    }

    func removeFairyFromCompact(_ fairy: FairyKind) {
        guard let existing = spot(containing: fairy) else { return }
        spotOccupants.removeValue(forKey: existing)
        play(.whoosh, volume: 0.5)
        hapticTap()
        save()
    }

    func toggleAccessory(_ accessory: FairyAccessory, for fairy: FairyKind? = nil) {
        let target = fairy ?? selectedFairy
        guard befriended.contains(target) else { return }
        if accessories[target] == accessory {
            accessories.removeValue(forKey: target)
            play(.tap, volume: 0.55)
        } else {
            accessories[target] = accessory
            play(.ding, volume: 0.7)
            let burstPos = spot(containing: target)?.center ?? FGeo.compactCenter
            emitBurst(.star, at: burstPos, count: 10, colorHex: accessory.accentHex)
        }
        hapticTap()
        save()
    }

    @discardableResult
    func togglePin(_ fairy: FairyKind? = nil) -> FairyKind? {
        let target = fairy ?? selectedFairy
        guard befriended.contains(target) else { return pinnedFairy }
        if pinnedFairy == target {
            pinnedFairy = nil
            play(.tap, volume: 0.55)
        } else {
            pinnedFairy = target
            play(.sparkle, volume: 0.8)
            let burstPos = spot(containing: target)?.center ?? FGeo.compactCenter
            emitBurst(.star, at: burstPos, count: 14, colorHex: 0xFFD452)
            emitBurst(.heart, at: burstPos, count: 8, colorHex: target.palette.emblem)
        }
        hapticTap()
        syncPinnedFairyDefaults()
        save()
        return pinnedFairy
    }

    func nearestCompactSpot(to point: CGPoint, maxRadius: CGFloat = 104) -> CompactSpot? {
        var best: (CompactSpot, CGFloat)?
        for spot in CompactSpot.allCases {
            let d = hypot(point.x - spot.center.x, point.y - spot.center.y)
            if d <= maxRadius, best == nil || d < best!.1 {
                best = (spot, d)
            }
        }
        return best?.0
    }

    func tapCompact(at point: CGPoint) {
        guard let spot = nearestCompactSpot(to: point, maxRadius: 96) else {
            emitBurst(.star, at: point, count: 5, colorHex: 0xFFE38A)
            play(.tap, volume: 0.35)
            return
        }

        if let pending = pendingPlacementFairy {
            _ = placeFairy(pending, at: spot)
            return
        }

        if let occupant = spotOccupants[spot] {
            selectedFairy = occupant
            compactSpotReactUntil[spot] = time + 1.4
            playCompactSpotSound(spot)
            hapticTap()
            emitCompactSpotParticles(spot, fairy: occupant)
        } else {
            _ = placeFairy(selectedFairy, at: spot)
        }
    }

    func beginCompactDrag(fairy: FairyKind, fromSpot: CompactSpot?, at liftedPoint: CGPoint) {
        guard befriended.contains(fairy) else { return }
        draggingCompactFairy = fairy
        compactDragOriginSpot = fromSpot
        compactDragPos = liftedPoint
        compactHoverSpot = nearestCompactSpot(to: liftedPoint, maxRadius: 108)
        compactReturnHovered = fromSpot != nil && liftedPoint.y >= FGeo.returnDropY - 36
        selectedFairy = fairy
        pendingPlacementFairy = nil
        play(.pop, volume: 0.5)
        hapticTap()
    }

    func updateCompactDrag(to liftedPoint: CGPoint) {
        guard draggingCompactFairy != nil else { return }
        compactDragPos = liftedPoint
        compactReturnHovered = compactDragOriginSpot != nil && liftedPoint.y >= FGeo.returnDropY - 36
        compactHoverSpot = compactReturnHovered ? nil : nearestCompactSpot(to: liftedPoint, maxRadius: 108)
    }

    func endCompactDrag(at liftedPoint: CGPoint) {
        guard let fairy = draggingCompactFairy else { return }
        let origin = compactDragOriginSpot
        draggingCompactFairy = nil
        compactDragOriginSpot = nil
        compactHoverSpot = nil
        let returning = origin != nil && liftedPoint.y >= FGeo.returnDropY - 36
        compactReturnHovered = false

        if returning {
            removeFairyFromCompact(fairy)
            return
        }
        if let target = nearestCompactSpot(to: liftedPoint, maxRadius: 112) {
            _ = placeFairy(fairy, at: target)
        } else if origin != nil {
            play(.pop, volume: 0.45)
        }
    }

    func cancelCompactDrag() {
        draggingCompactFairy = nil
        compactDragOriginSpot = nil
        compactHoverSpot = nil
        compactReturnHovered = false
    }

    // MARK: - Coins, Stickers & Particles

    func discover(_ find: FairiesFind, at point: CGPoint) {
        unlockedFinds.insert(find)
        guard !demo || StickerBook.shared.demo else { return }
        if StickerBook.shared.find(game: Self.gameID, id: find.rawValue) {
            emitBurst(.star, at: point, count: 14, colorHex: 0xFFE38A)
        }
    }

    private func earnCoins(_ amount: Int, from point: CGPoint) {
        guard amount > 0 else { return }
        guard !demo || Coins.shared.demo else { return }
        Coins.shared.earn(amount, game: Self.gameID, from: point)
    }

    private func play(_ sfx: SFX, volume: Float = 0.8) {
        guard !quiet else { return }
        Sound.shared.play(sfx, volume: volume)
    }

    private func hapticTap() {
        guard !quiet else { return }
        Sound.shared.tap()
    }

    private func playCompactSpotSound(_ spot: CompactSpot) {
        switch spot {
        case .cloudBed: play(.note1, volume: 0.65)
        case .rainbowSwing: play(.boing, volume: 0.6)
        case .teacupBath: play(.bubble, volume: 0.75)
        case .danceStage: play(.note4, volume: 0.75)
        case .treatTable: play(.pop, volume: 0.7)
        }
    }

    private func emitSpotParticles(_ spot: MeadowSpot, count: Int) {
        switch spot {
        case .blossomBush:
            emitBurst(.petal, at: spot.popOrigin, count: count, colorHex: 0xFFB3D2)
        case .bubbleFountain:
            emitBurst(.bubble, at: spot.popOrigin, count: count, colorHex: 0xA8E4FF)
        case .teacupLantern:
            emitBurst(.star, at: spot.popOrigin, count: count, colorHex: 0xFFE38A)
        case .rainbowMushroom:
            emitBurst(.star, at: spot.popOrigin, count: count, colorHex: 0xD2B4FF)
        }
    }

    private func emitCompactSpotParticles(_ spot: CompactSpot, fairy: FairyKind) {
        let origin = CGPoint(x: spot.center.x + spot.fairyOffset.x, y: spot.center.y + spot.fairyOffset.y)
        switch spot {
        case .cloudBed:
            emitBurst(.sleepyZ, at: origin, count: 6, colorHex: 0xC9B6FF)
            emitBurst(.star, at: origin, count: 6, colorHex: 0xFFE38A)
        case .rainbowSwing:
            emitBurst(.heart, at: origin, count: 7, colorHex: fairy.palette.emblem)
            emitBurst(.star, at: origin, count: 7, colorHex: 0xFFE38A)
        case .teacupBath:
            emitBurst(.bubble, at: origin, count: 12, colorHex: 0xA8E4FF)
        case .danceStage:
            emitBurst(.note, at: origin, count: 8, colorHex: fairy.palette.emblem)
            emitBurst(.star, at: origin, count: 10, colorHex: 0xFFE38A)
        case .treatTable:
            emitBurst(.heart, at: origin, count: 10, colorHex: 0xFF8FB8)
        }
    }

    func emitBurst(_ kind: FairyParticleKind, at origin: CGPoint, count: Int, colorHex: UInt32) {
        for i in 0..<count {
            let angle = (CGFloat(i) / CGFloat(max(1, count))) * 2 * .pi + CGFloat.random(in: -0.25...0.25)
            let speed = CGFloat.random(in: 36...110)
            spawnParticle(
                kind,
                at: origin,
                vel: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 30),
                maxAge: CGFloat.random(in: 0.75...1.35),
                size: CGFloat.random(in: 10...18),
                colorHex: colorHex
            )
        }
    }

    private func spawnParticle(
        _ kind: FairyParticleKind,
        at pos: CGPoint,
        vel: CGVector,
        maxAge: CGFloat,
        size: CGFloat,
        colorHex: UInt32
    ) {
        particles.append(FairyParticle(
            kind: kind,
            pos: pos,
            vel: vel,
            age: 0,
            maxAge: maxAge,
            size: size,
            colorHex: colorHex,
            phase: CGFloat.random(in: 0...(2 * .pi))
        ))
        if particles.count > 120 {
            particles.removeFirst(particles.count - 120)
        }
    }
}
