import SwiftUI

struct FloatingStarHeart: Identifiable, Equatable {
    let id: Int
    var pos: CGPoint
    var vel: CGVector
    var age: CGFloat
    var maxAge: CGFloat
    let colorHex: UInt32
}

struct FlutterDashState: Equatable {
    var dashProgress: Int
    var targetCount: Int
    var perches: [CGPoint]
    var currentPerchIndex: Int
    var fromPosition: CGPoint
    var targetPosition: CGPoint
    var position: CGPoint
    var dartProgress: CGFloat
    var peekTimer: Double
    var ribbonTrail: [CGPoint]
    var starHearts: [FloatingStarHeart]
    var lastHitAt: Double
    var phase: Double
}

struct MeadowBubble: Identifiable, Equatable {
    let id: Int
    var pos: CGPoint
    var vel: CGVector
    var radius: CGFloat
    let containsFairy: Bool
    let tintHex: UInt32
    var phase: Double
}

struct BubblePopState: Equatable {
    var bubbles: [MeadowBubble]
}

struct ChimeEchoState: Equatable {
    var sequence: [MeadowChime]
    var matchedCount: Int
    var playbackIndex: Int?
    var playbackTimer: Double
    var activeDemoChime: MeadowChime?
    var idleTimer: Double
    var hintedChime: MeadowChime?
    var fairyPos: CGPoint
    var phase: Double
}

struct PlacedMeadowTreat: Identifiable, Equatable {
    let id: Int
    let kind: MeadowTreatKind
    var pos: CGPoint
    let startPos: CGPoint
    let targetPos: CGPoint
    var flightProgress: CGFloat
    var nibbled: Bool
    var nibbleProgress: CGFloat
}

struct TreatLureState: Equatable {
    var nibblesCount: Int
    var targetNibbles: Int
    var fairyPos: CGPoint
    var homePos: CGPoint
    var activeTreat: PlacedMeadowTreat?
    var ribbonSwirlPoints: [CGPoint]
    var ribbonSwirlProgress: CGFloat
    var lastSwirlPoint: CGPoint?
    var phase: Double
}

struct CatchRingState: Equatable {
    var anchor: CGPoint
    var startPos: CGPoint
    var position: CGPoint
    var catchCharge: CGFloat
    var isCharging: Bool
    var swirlAngle: Double
    var lastSwirlTip: CGPoint?
    var usedWand: Bool
    var appearedAt: Double
    var caughtAt: Double?
    var phase: Double
}

enum MeadowEncounterPhase: Equatable {
    case flutterDash(FlutterDashState)
    case bubblePop(BubblePopState)
    case chimeEcho(ChimeEchoState)
    case treatLure(TreatLureState)
    case catching(CatchRingState)
}

struct MeadowEncounter: Equatable {
    let kind: FairyKind
    let fromSpot: MeadowSpot
    let encounterKind: FairyEncounterKind
    var phase: MeadowEncounterPhase
    let startedAt: Double
    var lastInteractionAt: Double
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
    let action: Action
    var triggered: Bool = false

    enum Action: Equatable {
        case coaxSpot(MeadowSpot)
        case chaseFlutterDash
        case popBubble(Int)
        case ringChime(MeadowChime)
        case lureTreat(MeadowTreatKind)
        case chargeCatchRing
    }
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
    case confetti
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

struct CompactFairyActor: Identifiable, Equatable {
    let kind: FairyKind
    var id: FairyKind { kind }
    var position: CGPoint
    var target: CGPoint
    var velocity: CGVector
    var currentSpot: CompactSpot?
    var mood: FairyMood
    var wish: FairyWish?
    var wishTimer: Double
    var chatPartner: FairyKind?
    var chatTimer: Double
    var chatCooldownUntil: Double
    var idleTimer: Double
    var bobPhase: Double
    var reactionUntil: Double
    var ridingCarousel: Bool
    var carouselSeatIndex: Int
}

struct CompactBubble: Identifiable, Equatable {
    let id: Int
    var pos: CGPoint
    var vel: CGVector
    var radius: CGFloat
    var age: CGFloat
    var maxAge: CGFloat
    let tintHex: UInt32
    var phase: Double
}

struct CompactTableTreat: Identifiable, Equatable {
    let id: Int
    let kind: CompactTableTreatKind
    var pos: CGPoint
    var age: CGFloat
    var maxAge: CGFloat
    var nibbled: Bool
}

final class FairiesSim: ObservableObject {
    static let gameID = "fairies"
    static let saveFile = "fairies.json"
    static let catchCoinReward = 4
    static let wishCoinReward = 2
    static let repeatCoinCooldown: Double = 10.0
    static let wishCoinCooldown: Double = 8.0
    static let maxCompactFairies = FairiesSave.maxCompactFairies
    static let discoPartyDuration: Double = 6.0
    static let flutterDashTarget = 3
    static let treatLureTargetNibbles = 2

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
    @Published private(set) var activeTreatLureFairy: FairyKind?
    @Published private(set) var draggingMeadowTreat: MeadowTreatKind?
    @Published private(set) var activeCompactFairies: [FairyKind] = []
    @Published private(set) var isNightMode = false

    // 60fps simulation state stepped inside Canvas TimelineView without triggering SwiftUI layout churn.
    var time: Double = 0
    private var lastTick: Date?
    private var inCanvasStep = false
    private var nextEntityID = 1

    var rustlingSpots: Set<MeadowSpot> = []
    var spotWiggleUntil: [MeadowSpot: Double] = [:]
    var chimeSwingUntil: [MeadowChime: Double] = [:]
    var encounter: MeadowEncounter?
    var celebration: CatchCelebration?
    var wandTip: CGPoint?
    var wandFinger: CGPoint?
    var wandSweep: WandAutoSweep?
    var wandTrail: [WandSparkle] = []
    var particles: [FairyParticle] = []

    var draggingTreatPos: CGPoint = .zero
    var holdingCatchRing = false
    var holdCatchPoint: CGPoint?
    private var holdCatchStartedAt: Double = 0
    private var lastChargeSparkAt: Double = -10

    var compactActors: [CompactFairyActor] = []
    var compactBubbles: [CompactBubble] = []
    var compactTableTreats: [CompactTableTreat] = []
    var compactDragPos: CGPoint = .zero
    var compactDragOriginSpot: CompactSpot?
    var compactDragStartedInRoom = false
    var compactHoverSpot: CompactSpot?
    var compactSpotReactUntil: [CompactSpot: Double] = [:]
    var compactOpenAt: Double = -10
    var pendingPlacementFairy: FairyKind?
    var discoPartyTimer: Double = 0
    var swingEnergy: CGFloat = 0
    var swingPhase: Double = 0
    var carouselSpinAngle: Double = 0
    var carouselBoostTimer: Double = 0
    var teaPourTimer: Double = 0
    var nextWishTimer: Double = 8.5

    var quiet = false
    var demo = false
    private(set) var lastCoinAwardTime: Double = -100
    private(set) var lastWishCoinTime: Double = -100
    private(set) var unlockedFinds: Set<FairiesFind> = []

    var hasChandelier: Bool { Coins.shared.owns("fairies/chandelier") }
    var hasCarousel: Bool { Coins.shared.owns("fairies/carousel") }
    var hasHanbokTea: Bool { Coins.shared.owns("fairies/hanbokTea") }

    var availableMeadowTreats: [MeadowTreatKind] {
        if activeTreatLureFairy == .silk {
            return [.strawberry, .honeyDrop, .bungeoppang, .silkSwirl]
        }
        return [.strawberry, .honeyDrop, .bungeoppang]
    }

    var activeCatchRing: CatchRingState? {
        guard let enc = encounter, case .catching(let ring) = enc.phase else { return nil }
        return ring
    }

    private let userDefaults: UserDefaults
    private let persist: Bool
    private let storageGameID: String
    private var ambientTimer: Double = 0
    private var discoBeatTimer: Double = 0
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

        spawnInitialCompactActors(from: loaded)
        self.activeCompactFairies = compactActors.map(\.kind)

        syncPinnedFairyDefaults()
        ensureRustlingSpots()
    }

    private func allocID() -> Int {
        defer { nextEntityID += 1 }
        return nextEntityID
    }

    private func publishMutation(_ block: @escaping () -> Void) {
        if inCanvasStep {
            DispatchQueue.main.async(execute: block)
        } else {
            block()
        }
    }

    private func spawnInitialCompactActors(from save: FairiesSave) {
        compactActors.removeAll()
        var spawned: Set<FairyKind> = []

        for spot in CompactSpot.allCases {
            if let kind = save.spotOccupants[spot], save.befriended.contains(kind), !spawned.contains(kind) {
                let pos = CGPoint(x: spot.center.x + spot.fairyOffset.x, y: spot.center.y + spot.fairyOffset.y)
                compactActors.append(makeCompactActor(kind: kind, at: pos, spot: spot))
                spawned.insert(kind)
            }
        }

        let roamPresets: [CGPoint] = [
            CGPoint(x: 420, y: 344),
            CGPoint(x: 604, y: 344),
            CGPoint(x: 448, y: 492),
            CGPoint(x: 582, y: 486),
            CGPoint(x: 372, y: 392),
            CGPoint(x: 646, y: 392),
            CGPoint(x: 512, y: 318),
            CGPoint(x: 512, y: 506),
        ]
        var presetIdx = 0
        for kind in save.roamingFairies where save.befriended.contains(kind) && !spawned.contains(kind) {
            guard compactActors.count < Self.maxCompactFairies else { break }
            let pos = roamPresets[presetIdx % roamPresets.count]
            presetIdx += 1
            compactActors.append(makeCompactActor(kind: kind, at: pos, spot: nil))
            spawned.insert(kind)
        }
    }

    private func makeCompactActor(kind: FairyKind, at pos: CGPoint, spot: CompactSpot?) -> CompactFairyActor {
        CompactFairyActor(
            kind: kind,
            position: pos,
            target: pos,
            velocity: .zero,
            currentSpot: spot,
            mood: spot?.mood ?? .happy,
            wish: nil,
            wishTimer: 0,
            chatPartner: nil,
            chatTimer: 0,
            chatCooldownUntil: time + 2.0,
            idleTimer: Double.random(in: 2.5...5.5),
            bobPhase: Double.random(in: 0...(2 * .pi)),
            reactionUntil: -10,
            ridingCarousel: false,
            carouselSeatIndex: 0
        )
    }

    // MARK: - Persistence & Dress Up Pinned Fairy Sync

    func currentSave() -> FairiesSave {
        FairiesSave(
            befriended: befriended,
            spotOccupants: spotOccupants,
            accessories: accessories,
            pinnedFairy: pinnedFairy,
            totalCatches: totalCatches,
            roamingFairies: compactActors.map(\.kind)
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
        cancelMeadowTreatDrag()
        holdingCatchRing = false
        holdCatchPoint = nil
        cancelCompactDrag()
        mode = newMode
        play(.flip, volume: 0.65)
        hapticTap()
        if newMode == .compact {
            hasCompactBadge = false
            compactOpenAt = time
            emitBurst(.star, at: FGeo.compactCenter, count: 14, colorHex: 0xFFE38A)
        } else {
            if encounter == nil && celebration == nil {
                ensureRustlingSpots()
            }
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
        inCanvasStep = true
        defer { inCanvasStep = false }
        step(dt: dt)
    }

    func resetClock() {
        lastTick = nil
    }

    func step(dt: CGFloat) {
        let clamped = min(CGFloat(0.05), max(CGFloat(0.001), dt))
        time += Double(clamped)

        if mode == .meadow {
            stepMeadowEncounter(clamped)
            stepCelebration()
            stepWandSweep(clamped)
            stepWandTrail(clamped)
        } else {
            stepCompact(clamped)
        }
        stepParticles(clamped)
        stepAmbient(clamped)
    }

    // MARK: - Meadow Encounter Stepping

    private func stepMeadowEncounter(_ dt: CGFloat) {
        guard var enc = encounter else {
            if celebration == nil && rustlingSpots.isEmpty {
                ensureRustlingSpots()
            }
            return
        }

        if time - enc.lastInteractionAt > 60 {
            encounter = nil
            publishMutation { self.activeTreatLureFairy = nil }
            ensureRustlingSpots()
            return
        }

        switch enc.phase {
        case .flutterDash(var state):
            stepFlutterDash(&state, kind: enc.kind, dt: dt)
            enc.phase = .flutterDash(state)
            encounter = enc

        case .bubblePop(var state):
            stepBubblePop(&state, dt: dt)
            enc.phase = .bubblePop(state)
            encounter = enc

        case .chimeEcho(var state):
            stepChimeEcho(&state, dt: dt)
            enc.phase = .chimeEcho(state)
            encounter = enc

        case .treatLure(var state):
            let completed = stepTreatLure(&state, kind: enc.kind, dt: dt)
            if completed {
                transitionToCatchRing(for: enc.kind, from: enc.fromSpot, startPos: state.fairyPos)
            } else {
                enc.phase = .treatLure(state)
                encounter = enc
            }

        case .catching(var ring):
            if let caughtAt = ring.caughtAt {
                if time - caughtAt > 0.12 {
                    encounter = nil
                }
                return
            }
            stepCatchRing(&ring, kind: enc.kind, dt: dt)
            enc.phase = .catching(ring)
            encounter = enc
            if ring.catchCharge >= 1.0 {
                _ = befriendActiveFairy(viaWand: ring.usedWand)
            }
        }
    }

    private func stepFlutterDash(_ state: inout FlutterDashState, kind: FairyKind, dt: CGFloat) {
        if state.dartProgress < 1 {
            state.dartProgress = min(1, state.dartProgress + dt / 0.44)
            let u = state.dartProgress
            let inv = 1 - u
            let eased = 1 - inv * inv * inv
            let arcY = -sin(eased * .pi) * 52
            state.position = CGPoint(
                x: state.fromPosition.x + (state.targetPosition.x - state.fromPosition.x) * eased,
                y: state.fromPosition.y + (state.targetPosition.y - state.fromPosition.y) * eased + arcY
            )
            if state.ribbonTrail.last.map({ hypot($0.x - state.position.x, $0.y - state.position.y) >= 8 }) ?? true {
                state.ribbonTrail.append(state.position)
                if state.ribbonTrail.count > 24 {
                    state.ribbonTrail.removeFirst(state.ribbonTrail.count - 24)
                }
            }
        } else {
            state.peekTimer += Double(dt)
            let bobX = CGFloat(sin(time * 3.0 + state.phase)) * 10
            let bobY = CGFloat(sin(time * 4.4 + state.phase)) * 7
            state.position = CGPoint(x: state.targetPosition.x + bobX, y: state.targetPosition.y + bobY)

            if state.ribbonTrail.count > 1 && Int(time * 30) % 2 == 0 {
                state.ribbonTrail.removeFirst()
            }

            // Cheekily hops to a fresh perch after ~2.5s of peeking out.
            if state.peekTimer >= 2.5 {
                advanceFlutterPerch(&state, kind: kind)
            }
        }

        for i in state.starHearts.indices.reversed() {
            state.starHearts[i].age += dt
            if state.starHearts[i].age >= state.starHearts[i].maxAge {
                state.starHearts.remove(at: i)
                continue
            }
            state.starHearts[i].pos.x += state.starHearts[i].vel.dx * dt
            state.starHearts[i].pos.y += state.starHearts[i].vel.dy * dt
            state.starHearts[i].vel.dy *= (1 - 0.8 * dt)
        }
    }

    private func advanceFlutterPerch(_ state: inout FlutterDashState, kind: FairyKind) {
        let current = state.currentPerchIndex
        let farCandidates = state.perches.indices.filter { idx in
            idx != current && hypot(state.perches[idx].x - state.perches[current].x, state.perches[idx].y - state.perches[current].y) > 190
        }
        let nextIndex = (farCandidates.isEmpty ? state.perches.indices.filter { $0 != current } : farCandidates).randomElement()
            ?? ((current + 1) % max(1, state.perches.count))
        state.currentPerchIndex = nextIndex
        state.fromPosition = state.position
        state.targetPosition = state.perches[nextIndex]
        state.dartProgress = 0
        state.peekTimer = 0
        state.ribbonTrail = [state.position]
        emitBurst(.petal, at: state.position, count: 6, colorHex: kind.palette.emblem)
    }

    private func stepBubblePop(_ state: inout BubblePopState, dt: CGFloat) {
        let minX: CGFloat = 128
        let maxX: CGFloat = 896
        let minY: CGFloat = 176
        let maxY: CGFloat = 528

        for i in state.bubbles.indices {
            var b = state.bubbles[i]
            b.pos.x += b.vel.dx * dt + CGFloat(sin(time * 2.1 + b.phase)) * 12 * dt
            b.pos.y += b.vel.dy * dt + CGFloat(cos(time * 1.8 + b.phase)) * 10 * dt

            if b.pos.x - b.radius < minX {
                b.pos.x = minX + b.radius
                b.vel.dx = abs(b.vel.dx)
            } else if b.pos.x + b.radius > maxX {
                b.pos.x = maxX - b.radius
                b.vel.dx = -abs(b.vel.dx)
            }
            if b.pos.y - b.radius < minY {
                b.pos.y = minY + b.radius
                b.vel.dy = abs(b.vel.dy)
            } else if b.pos.y + b.radius > maxY {
                b.pos.y = maxY - b.radius
                b.vel.dy = -abs(b.vel.dy)
            }
            state.bubbles[i] = b
        }

        // Gentle separation so bubbles remain cleanly distinct to tap.
        for i in state.bubbles.indices {
            for j in (i + 1)..<state.bubbles.count {
                let dx = state.bubbles[j].pos.x - state.bubbles[i].pos.x
                let dy = state.bubbles[j].pos.y - state.bubbles[i].pos.y
                let dist = max(1, hypot(dx, dy))
                let minDist = state.bubbles[i].radius + state.bubbles[j].radius + 14
                if dist < minDist {
                    let push = (minDist - dist) * 0.5 * min(1, dt * 6)
                    let nx = dx / dist
                    let ny = dy / dist
                    state.bubbles[i].pos.x -= nx * push
                    state.bubbles[i].pos.y -= ny * push
                    state.bubbles[j].pos.x += nx * push
                    state.bubbles[j].pos.y += ny * push
                }
            }
        }
    }

    private func stepChimeEcho(_ state: inout ChimeEchoState, dt: CGFloat) {
        let lift = Double(state.matchedCount) * 14
        let peekX = CGFloat(512 + sin(time * 2.2 + state.phase) * 44)
        let peekY = CGFloat(254 - lift + sin(time * 3.8 + state.phase) * 7)
        state.fairyPos = CGPoint(x: peekX, y: peekY)

        if let idx = state.playbackIndex {
            state.playbackTimer += Double(dt)
            if state.playbackTimer >= 0.58 {
                state.playbackTimer = 0
                if idx < state.sequence.count {
                    let chime = state.sequence[idx]
                    chimeSwingUntil[chime] = time + 0.72
                    state.activeDemoChime = chime
                    play(chime.sfx, volume: 0.8)
                    emitBurst(.note, at: chime.center, count: 6, colorHex: chime.colorHex)
                    emitBurst(.star, at: chime.center, count: 4, colorHex: 0xFFE38A)
                    state.playbackIndex = idx + 1
                } else {
                    state.playbackIndex = nil
                    state.activeDemoChime = nil
                    state.idleTimer = 0
                }
            }
        } else {
            state.idleTimer += Double(dt)
            if state.idleTimer >= 2.2, state.matchedCount < state.sequence.count {
                state.hintedChime = state.sequence[state.matchedCount]
            }
        }
    }

    private func stepTreatLure(_ state: inout TreatLureState, kind: FairyKind, dt: CGFloat) -> Bool {
        if var treat = state.activeTreat {
            if treat.flightProgress < 1 {
                treat.flightProgress = min(1, treat.flightProgress + dt / 0.28)
                let u = treat.flightProgress
                let e = u * u * (3 - 2 * u)
                let arcY = -sin(e * .pi) * 84
                treat.pos = CGPoint(
                    x: treat.startPos.x + (treat.targetPos.x - treat.startPos.x) * e,
                    y: treat.startPos.y + (treat.targetPos.y - treat.startPos.y) * e + arcY
                )
                state.activeTreat = treat
            } else {
                // Fairy swoops happily to the picnic mat to nibble!
                let nibbleTarget = CGPoint(x: treat.targetPos.x, y: treat.targetPos.y - 44)
                let lerpK = min(1, dt * 8.5)
                state.fairyPos.x += (nibbleTarget.x - state.fairyPos.x) * lerpK
                state.fairyPos.y += (nibbleTarget.y - state.fairyPos.y) * lerpK

                treat.nibbleProgress = min(1, treat.nibbleProgress + dt / 0.56)
                state.activeTreat = treat

                if treat.nibbleProgress >= 1 {
                    state.activeTreat = nil
                    state.nibblesCount += 1
                    play(.pop, volume: 0.75)
                    play(.sparkle, volume: 0.65)
                    emitBurst(.heart, at: nibbleTarget, count: 10, colorHex: kind.palette.emblem)
                    emitBurst(.star, at: nibbleTarget, count: 6, colorHex: 0xFFE38A)
                    if state.nibblesCount >= state.targetNibbles {
                        return true
                    }
                }
            }
        } else {
            let bobX = CGFloat(sin(time * 2.4 + state.phase)) * 18
            let bobY = CGFloat(sin(time * 3.6 + state.phase)) * 10
            let dest = CGPoint(x: state.homePos.x + bobX, y: state.homePos.y + bobY)
            let lerpK = min(1, dt * 4.5)
            state.fairyPos.x += (dest.x - state.fairyPos.x) * lerpK
            state.fairyPos.y += (dest.y - state.fairyPos.y) * lerpK
        }

        if state.ribbonSwirlPoints.count > 1 && Int(time * 25) % 3 == 0 {
            state.ribbonSwirlPoints.removeFirst()
        }
        return false
    }

    private func stepCatchRing(_ ring: inout CatchRingState, kind: FairyKind, dt: CGFloat) {
        let elapsed = time - ring.appearedAt
        let popT = CGFloat(min(1, elapsed / 0.4))
        let inv = 1 - popT
        let eased = 1 - inv * inv * inv
        let bobX = CGFloat(sin(elapsed * 2.2 + ring.phase)) * 22
        let bobY = CGFloat(sin(elapsed * 3.4 + ring.phase * 1.2)) * 14
        ring.position = CGPoint(
            x: ring.startPos.x + (ring.anchor.x - ring.startPos.x) * eased + bobX * eased,
            y: ring.startPos.y + (ring.anchor.y - ring.startPos.y) * eased + bobY * eased
        )

        var activelyCharging = false
        var delta: CGFloat = 0

        if wandHeld, let tip = wandTip, hypot(tip.x - ring.position.x, tip.y - ring.position.y) <= 122 {
            activelyCharging = true
            ring.usedWand = true
            delta = dt * 1.05
            if let prev = ring.lastSwirlTip {
                let moved = hypot(tip.x - prev.x, tip.y - prev.y)
                delta += min(0.08, moved / 360)
            }
            ring.lastSwirlTip = tip
        } else {
            ring.lastSwirlTip = nil
            if holdingCatchRing, let pt = holdCatchPoint, hypot(pt.x - ring.position.x, pt.y - ring.position.y) <= 126 {
                activelyCharging = true
                delta = dt * 1.05
            }
        }

        ring.isCharging = activelyCharging
        let spinSpeed = activelyCharging ? (4.8 + Double(ring.catchCharge) * 6.0) : 1.6
        ring.swirlAngle += Double(dt) * spinSpeed

        if activelyCharging {
            ring.catchCharge = min(1.0, ring.catchCharge + delta)
            if time - lastChargeSparkAt >= 0.11 {
                lastChargeSparkAt = time
                let a = CGFloat(ring.swirlAngle)
                let sp = CGPoint(x: ring.position.x + cos(a) * 68, y: ring.position.y + sin(a) * 68)
                spawnParticle(.heart, at: sp, vel: CGVector(dx: cos(a) * 28, dy: sin(a) * 28 - 22), maxAge: 0.75, size: 12, colorHex: kind.palette.emblem)
                spawnParticle(.star, at: sp, vel: CGVector(dx: -cos(a) * 24, dy: -sin(a) * 24 - 18), maxAge: 0.65, size: 10, colorHex: 0xFFE38A)
            }
        }
    }

    private func stepCelebration() {
        guard let c = celebration else { return }
        if time - c.startedAt >= 1.65 {
            celebration = nil
            if mode == .meadow && encounter == nil {
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
            switch sweep.action {
            case .coaxSpot(let spot):
                _ = coaxSpot(spot, viaWand: true)
            case .chaseFlutterDash:
                _ = tapFlutterDash(viaWand: true)
            case .popBubble(let id):
                _ = popMeadowBubble(id: id, viaWand: true)
            case .ringChime(let chime):
                _ = ringChime(chime)
                discover(.wandMagic, at: chime.center)
            case .lureTreat(let treat):
                _ = serveMeadowTreat(treat, from: p)
                discover(.wandMagic, at: FGeo.treatMatCenter)
            case .chargeCatchRing:
                _ = chargeCatchRing(by: 0.42, viaWand: true)
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

    // MARK: - Compact Dollhouse 60fps Stepping

    private func stepCompact(_ dt: CGFloat) {
        // Swing physics & damping
        swingPhase += Double(dt) * (2.6 + Double(swingEnergy) * 2.2)
        swingEnergy = max(0, swingEnergy - dt * 0.24)

        // Carousel spin
        if carouselBoostTimer > 0 {
            carouselBoostTimer = max(0, carouselBoostTimer - Double(dt))
        }
        let carouselRate = carouselBoostTimer > 0 ? 3.2 : 1.15
        carouselSpinAngle += Double(dt) * carouselRate

        // Tea pour animation
        if teaPourTimer > 0 {
            teaPourTimer = max(0, teaPourTimer - Double(dt))
        }

        // Disco party countdown & rhythmic musical sparkles
        if discoPartyTimer > 0 {
            discoPartyTimer = max(0, discoPartyTimer - Double(dt))
            discoBeatTimer += Double(dt)
            if discoBeatTimer >= 0.42 {
                discoBeatTimer = 0
                let noteColors: [UInt32] = [0xFF8FB8, 0xFFE38A, 0x9FE3CF, 0x9CCBFF, 0xC9B6FF]
                let x = CompactSpot.danceStage.center.x + CGFloat.random(in: -140...140)
                let y = CompactSpot.danceStage.center.y + CGFloat.random(in: -80...30)
                spawnParticle(.note, at: CGPoint(x: x, y: y), vel: CGVector(dx: CGFloat.random(in: -18...18), dy: -46), maxAge: 1.35, size: 15, colorHex: noteColors.randomElement() ?? 0xFF8FB8)
                spawnParticle(.confetti, at: CGPoint(x: FGeo.compactCenter.x + CGFloat.random(in: -220...220), y: 245), vel: CGVector(dx: CGFloat.random(in: -24...24), dy: CGFloat.random(in: 42...74)), maxAge: 1.8, size: CGFloat.random(in: 9...14), colorHex: noteColors.randomElement() ?? 0xFFE38A)
            }
        }

        // Poppable teacup bubbles rising through the room
        for i in compactBubbles.indices.reversed() {
            compactBubbles[i].age += dt
            if compactBubbles[i].age >= compactBubbles[i].maxAge || compactBubbles[i].pos.y < 195 {
                compactBubbles.remove(at: i)
                continue
            }
            compactBubbles[i].pos.x += compactBubbles[i].vel.dx * dt + CGFloat(sin(time * 2.8 + compactBubbles[i].phase)) * 18 * dt
            compactBubbles[i].pos.y += compactBubbles[i].vel.dy * dt
        }

        // Table treats lifetime
        for i in compactTableTreats.indices.reversed() {
            compactTableTreats[i].age += dt
            if compactTableTreats[i].age >= compactTableTreats[i].maxAge {
                compactTableTreats.remove(at: i)
            }
        }

        stepCompactActors(dt)
        stepCompactSocialChats()
        stepCompactWishes(dt)
    }

    private func stepCompactActors(_ dt: CGFloat) {
        let count = compactActors.count
        guard count > 0 else { return }

        for i in compactActors.indices {
            var actor = compactActors[i]
            if draggingCompactFairy == actor.kind {
                continue
            }

            // Carousel riders orbit directly with the miniature cloud & star seats.
            if actor.ridingCarousel {
                if !hasCarousel || discoPartyTimer > 0 || isNightMode {
                    actor.ridingCarousel = false
                } else {
                    let a = carouselSpinAngle + Double(actor.carouselSeatIndex) * (.pi / 2)
                    let depth = CGFloat(sin(a))
                    let x = FGeo.carouselCenter.x + CGFloat(cos(a)) * 27
                    let bob = CGFloat(sin(time * 3.2 + Double(actor.carouselSeatIndex) * 1.57)) * 4.5
                    let y = FGeo.carouselCenter.y - 38 + depth * 5 + bob
                    actor.position = CGPoint(x: x, y: y)
                    actor.target = actor.position
                    actor.velocity = .zero
                    actor.mood = .giggle
                    actor.idleTimer -= Double(dt)
                    if actor.idleTimer <= 0 && carouselBoostTimer <= 0 {
                        actor.ridingCarousel = false
                        actor.idleTimer = Double.random(in: 3.0...5.5)
                        actor.target = pickRoamingDestination(excluding: actor.kind)
                    }
                    compactActors[i] = actor
                    continue
                }
            }

            // Fairy Disco Party: all fairies swoop into a joyful twirling dance circle!
            if discoPartyTimer > 0 {
                actor.chatTimer = 0
                actor.chatPartner = nil
                let angle = time * 1.35 + (Double(i) / Double(max(1, count))) * 2 * .pi
                let radius: CGFloat = count == 1 ? 0 : (count <= 4 ? 92 : 116)
                let danceCenter = CompactSpot.danceStage.center
                let dest = FGeo.clampToCompactInterior(CGPoint(
                    x: danceCenter.x + CGFloat(cos(angle)) * radius,
                    y: danceCenter.y - 12 + CGFloat(sin(angle)) * radius * 0.56
                ))
                steerActor(&actor, toward: dest, maxSpeed: 155, dt: dt)
                actor.mood = .celebrate
                compactActors[i] = actor
                continue
            }

            // Cozy Starlight Night Mode: fairies gather peacefully around the Cloud Bed with sleepy smiles!
            if isNightMode {
                actor.chatTimer = 0
                actor.chatPartner = nil
                let bedCenter = CompactSpot.cloudBed.center
                let bedOffsets: [CGPoint] = [
                    CGPoint(x: 0, y: -14),
                    CGPoint(x: -44, y: -22),
                    CGPoint(x: 44, y: -22),
                    CGPoint(x: 84, y: 24),
                    CGPoint(x: -24, y: 42),
                    CGPoint(x: 132, y: -10),
                    CGPoint(x: 48, y: 58),
                    CGPoint(x: 112, y: 56),
                ]
                let off = bedOffsets[i % bedOffsets.count]
                let dest = FGeo.clampToCompactInterior(CGPoint(x: bedCenter.x + off.x, y: bedCenter.y + off.y))
                steerActor(&actor, toward: dest, maxSpeed: 88, dt: dt)
                actor.mood = .sleepy
                compactActors[i] = actor
                continue
            }

            // Social heart-chat pause!
            if actor.chatTimer > 0 {
                actor.chatTimer = max(0, actor.chatTimer - Double(dt))
                actor.velocity = CGVector(dx: actor.velocity.dx * 0.85, dy: actor.velocity.dy * 0.85)
                actor.mood = .giggle
                if actor.chatTimer <= 0 {
                    actor.chatPartner = nil
                    actor.chatCooldownUntil = time + 6.5
                    actor.idleTimer = 0.6
                }
                compactActors[i] = actor
                continue
            }

            // Normal free-roaming & spot hopping!
            let dist = hypot(actor.target.x - actor.position.x, actor.target.y - actor.position.y)
            if dist > 6 {
                steerActor(&actor, toward: actor.target, maxSpeed: 76, dt: dt)
                if actor.reactionUntil > time {
                    actor.mood = .celebrate
                } else if !compactTableTreats.isEmpty && actor.currentSpot == .treatTable {
                    actor.mood = .yum
                } else {
                    actor.mood = .happy
                }
            } else {
                actor.position = actor.target
                actor.velocity = .zero
                if actor.reactionUntil > time {
                    actor.mood = .celebrate
                } else if let spot = actor.currentSpot {
                    actor.mood = spot.mood
                } else {
                    actor.mood = .happy
                }

                // Nearby nibbling reaction when treats sit on the table
                if actor.currentSpot == .treatTable,
                   let idx = compactTableTreats.firstIndex(where: { !$0.nibbled }) {
                    compactTableTreats[idx].nibbled = true
                    actor.mood = .yum
                    actor.reactionUntil = time + 1.4
                    emitBurst(.heart, at: CGPoint(x: actor.position.x, y: actor.position.y - 20), count: 5, colorHex: 0xFF8FB8)
                }

                actor.idleTimer -= Double(dt)
                if actor.idleTimer <= 0 {
                    assignNextRoamingTarget(&actor)
                }
            }

            compactActors[i] = actor
        }
    }

    private func steerActor(_ actor: inout CompactFairyActor, toward dest: CGPoint, maxSpeed: CGFloat, dt: CGFloat) {
        let dx = dest.x - actor.position.x
        let dy = dest.y - actor.position.y
        let dist = hypot(dx, dy)
        guard dist > 0.5 else {
            actor.position = dest
            actor.velocity = .zero
            return
        }
        let speed = min(maxSpeed, dist * 3.2)
        let desiredVx = (dx / dist) * speed
        let desiredVy = (dy / dist) * speed
        let blend = min(1, dt * 6.0)
        actor.velocity.dx += (desiredVx - actor.velocity.dx) * blend
        actor.velocity.dy += (desiredVy - actor.velocity.dy) * blend
        actor.position.x += actor.velocity.dx * dt
        actor.position.y += actor.velocity.dy * dt
        actor.position = FGeo.clampToCompactInterior(actor.position)
    }

    private func assignNextRoamingTarget(_ actor: inout CompactFairyActor) {
        let occupiedSpots = Set(compactActors.compactMap { $0.kind == actor.kind ? nil : $0.currentSpot })
        let freeSpots = CompactSpot.allCases.filter { !occupiedSpots.contains($0) && $0 != actor.currentSpot }
        let roll = Double.random(in: 0...1)

        if hasCarousel && roll < 0.14 && compactActors.filter({ $0.ridingCarousel }).count < 2 {
            let usedSeats = Set(compactActors.filter { $0.ridingCarousel && $0.kind != actor.kind }.map(\.carouselSeatIndex))
            actor.currentSpot = nil
            actor.ridingCarousel = true
            actor.carouselSeatIndex = usedSeats.contains(0) ? 2 : 0
            actor.idleTimer = Double.random(in: 4.5...6.5)
            return
        }

        if roll < 0.62, let chosenSpot = freeSpots.randomElement() {
            actor.currentSpot = chosenSpot
            actor.target = CGPoint(x: chosenSpot.center.x + chosenSpot.fairyOffset.x, y: chosenSpot.center.y + chosenSpot.fairyOffset.y)
            actor.idleTimer = Double.random(in: 4.2...7.2)
        } else {
            actor.currentSpot = nil
            actor.target = pickRoamingDestination(excluding: actor.kind)
            actor.idleTimer = Double.random(in: 2.8...5.2)
        }
    }

    private func pickRoamingDestination(excluding kind: FairyKind) -> CGPoint {
        for _ in 0..<8 {
            let candidate = FGeo.clampToCompactInterior(CGPoint(
                x: CGFloat.random(in: 256...768),
                y: CGFloat.random(in: 286...526)
            ))
            let tooClose = compactActors.contains { other in
                other.kind != kind && hypot(other.position.x - candidate.x, other.position.y - candidate.y) < 76
            }
            if !tooClose {
                return candidate
            }
        }
        return FGeo.clampToCompactInterior(CGPoint(
            x: CGFloat.random(in: 300...724),
            y: CGFloat.random(in: 310...490)
        ))
    }

    private func stepCompactSocialChats() {
        guard discoPartyTimer <= 0, !isNightMode, compactActors.count >= 2 else { return }

        for i in compactActors.indices {
            guard draggingCompactFairy != compactActors[i].kind,
                  !compactActors[i].ridingCarousel,
                  compactActors[i].chatTimer <= 0,
                  time >= compactActors[i].chatCooldownUntil else { continue }

            for j in (i + 1)..<compactActors.count {
                guard draggingCompactFairy != compactActors[j].kind,
                      !compactActors[j].ridingCarousel,
                      compactActors[j].chatTimer <= 0,
                      time >= compactActors[j].chatCooldownUntil else { continue }

                let d = hypot(
                    compactActors[i].position.x - compactActors[j].position.x,
                    compactActors[i].position.y - compactActors[j].position.y
                )
                if d <= 78 {
                    compactActors[i].chatPartner = compactActors[j].kind
                    compactActors[j].chatPartner = compactActors[i].kind
                    compactActors[i].chatTimer = 2.6
                    compactActors[j].chatTimer = 2.6
                    compactActors[i].mood = .giggle
                    compactActors[j].mood = .giggle

                    let mid = CGPoint(
                        x: (compactActors[i].position.x + compactActors[j].position.x) * 0.5,
                        y: (compactActors[i].position.y + compactActors[j].position.y) * 0.5 - 26
                    )
                    emitBurst(.heart, at: mid, count: 6, colorHex: 0xFF8FB8)
                    play(.pop, volume: 0.35)
                    break
                }
            }
        }
    }

    private func stepCompactWishes(_ dt: CGFloat) {
        guard !compactActors.isEmpty else { return }

        var anyActiveWish = false
        for i in compactActors.indices {
            if compactActors[i].wish != nil {
                anyActiveWish = true
                compactActors[i].wishTimer -= Double(dt)
                if compactActors[i].wishTimer <= 0 {
                    compactActors[i].wish = nil
                    nextWishTimer = Double.random(in: 8.0...12.0)
                }
            }
        }

        if !anyActiveWish {
            nextWishTimer -= Double(dt)
            if nextWishTimer <= 0 {
                _ = spawnCompactWish()
                nextWishTimer = Double.random(in: 8.0...12.0)
            }
        }
    }

    @discardableResult
    func spawnCompactWish(for preferredKind: FairyKind? = nil, wish preferredWish: FairyWish? = nil) -> (FairyKind, FairyWish)? {
        guard !compactActors.isEmpty else { return nil }
        let idx: Int
        if let preferredKind, let found = compactActors.firstIndex(where: { $0.kind == preferredKind }) {
            idx = found
        } else {
            let candidates = compactActors.indices.filter { compactActors[$0].wish == nil }
            guard let chosen = candidates.randomElement() else { return nil }
            idx = chosen
        }

        let pool: [FairyWish] = hasCarousel
            ? FairyWish.allCases
            : FairyWish.allCases.filter { $0 != .carousel }
        let chosenWish = preferredWish ?? pool.randomElement() ?? .dance

        compactActors[idx].wish = chosenWish
        compactActors[idx].wishTimer = 22.0
        emitBurst(.star, at: CGPoint(x: compactActors[idx].position.x, y: compactActors[idx].position.y - 52), count: 5, colorHex: 0xFFE38A)
        return (compactActors[idx].kind, chosenWish)
    }

    @discardableResult
    func fulfillWish(for kind: FairyKind) -> Bool {
        guard let idx = compactActors.firstIndex(where: { $0.kind == kind }),
              compactActors[idx].wish != nil else { return false }

        let pos = compactActors[idx].position
        compactActors[idx].wish = nil
        compactActors[idx].wishTimer = 0
        compactActors[idx].mood = .celebrate
        compactActors[idx].reactionUntil = time + 2.4
        nextWishTimer = Double.random(in: 8.0...12.0)

        play(.cheer, volume: 0.5)
        play(.sparkle, volume: 0.8)
        hapticTap()
        emitBurst(.heart, at: pos, count: 14, colorHex: kind.palette.emblem)
        emitBurst(.star, at: pos, count: 12, colorHex: 0xFFE38A)

        if time - lastWishCoinTime >= Self.wishCoinCooldown {
            lastWishCoinTime = time
            earnCoins(Self.wishCoinReward, from: pos)
        }
        return true
    }

    private func fulfillMatchingWishes(for wish: FairyWish) {
        let wishers = compactActors.filter { $0.wish == wish }.map(\.kind)
        for kind in wishers {
            _ = fulfillWish(for: kind)
        }
    }

    // MARK: - Shared Particle & Ambient Stepping

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
            case .petal, .confetti:
                particles[i].vel.dy += 22 * dt
                particles[i].pos.x += cos(CGFloat(time) * 2.7 + particles[i].phase) * 28 * dt
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
            if let enc = encounter {
                switch enc.phase {
                case .catching(let ring) where ring.caughtAt == nil:
                    spawnParticle(.heart, at: CGPoint(x: ring.position.x + CGFloat.random(in: -28...28), y: ring.position.y - 24), vel: CGVector(dx: CGFloat.random(in: -12...12), dy: -34), maxAge: 1.1, size: CGFloat.random(in: 10...15), colorHex: enc.kind.palette.emblem)
                case .treatLure(let lure) where lure.activeTreat != nil:
                    spawnParticle(.heart, at: CGPoint(x: FGeo.treatMatCenter.x + CGFloat.random(in: -28...28), y: FGeo.treatMatCenter.y - 16), vel: CGVector(dx: CGFloat.random(in: -10...10), dy: -42), maxAge: 1.2, size: 13, colorHex: 0xFF8FB8)
                default:
                    break
                }
            }
        } else {
            for actor in compactActors {
                if actor.chatTimer > 0 {
                    if Int(time * 4) % 2 == 0 {
                        spawnParticle(.heart, at: CGPoint(x: actor.position.x, y: actor.position.y - 34), vel: CGVector(dx: CGFloat.random(in: -10...10), dy: -32), maxAge: 1.0, size: 11, colorHex: 0xFF8FB8)
                    }
                    continue
                }
                if isNightMode || actor.currentSpot == .cloudBed {
                    if Int(time * 3 + actor.bobPhase) % 3 == 0 {
                        spawnParticle(.sleepyZ, at: CGPoint(x: actor.position.x + 18, y: actor.position.y - 26), vel: CGVector(dx: 8, dy: -24), maxAge: 1.4, size: 12, colorHex: 0xC9B6FF)
                    }
                } else if let spot = actor.currentSpot {
                    switch spot {
                    case .teacupBath:
                        spawnParticle(.bubble, at: CGPoint(x: actor.position.x + CGFloat.random(in: -22...22), y: actor.position.y + 8), vel: CGVector(dx: CGFloat.random(in: -8...8), dy: -36), maxAge: 1.3, size: CGFloat.random(in: 8...14), colorHex: 0xBCEEFF)
                    case .danceStage:
                        spawnParticle(.note, at: CGPoint(x: actor.position.x + CGFloat.random(in: -26...26), y: actor.position.y - 22), vel: CGVector(dx: CGFloat.random(in: -12...12), dy: -32), maxAge: 1.2, size: 13, colorHex: actor.kind.palette.emblem)
                    case .treatTable:
                        if Int(time * 4) % 2 == 0 {
                            spawnParticle(.heart, at: CGPoint(x: actor.position.x + CGFloat.random(in: -16...16), y: actor.position.y - 22), vel: CGVector(dx: 6, dy: -26), maxAge: 1.1, size: 11, colorHex: 0xFF8FB8)
                        }
                    case .rainbowSwing:
                        if Int(time * 4) % 2 == 0 {
                            spawnParticle(.star, at: CGPoint(x: actor.position.x + CGFloat.random(in: -20...20), y: actor.position.y - 18), vel: CGVector(dx: CGFloat.random(in: -10...10), dy: -20), maxAge: 1.0, size: 9, colorHex: 0xFFE38A)
                        }
                    case .cloudBed:
                        break
                    }
                }
            }
            if hasChandelier && Int(time * 3) % 3 == 0 {
                spawnParticle(
                    .star,
                    at: CGPoint(x: FGeo.chandelierCenter.x + CGFloat.random(in: -44...44), y: FGeo.chandelierCenter.y + CGFloat.random(in: 6...34)),
                    vel: CGVector(dx: CGFloat.random(in: -8...8), dy: 14),
                    maxAge: 1.1,
                    size: CGFloat.random(in: 7...11),
                    colorHex: 0xFFE38A
                )
            }
            if hasCarousel && Int(time * 3) % 4 == 1 {
                spawnParticle(
                    .star,
                    at: CGPoint(x: FGeo.carouselCenter.x + CGFloat.random(in: -24...24), y: FGeo.carouselCenter.y - 46 + CGFloat.random(in: -10...10)),
                    vel: CGVector(dx: CGFloat.random(in: -10...10), dy: -20),
                    maxAge: 1.0,
                    size: CGFloat.random(in: 7...10),
                    colorHex: 0xFFB8E0
                )
            }
        }
    }

    // MARK: - Mode A: Sparkle Meadow Encounters

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
            for spot in candidates.shuffled() where rustlingSpots.count < 2 {
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

        if let existing = encounter {
            play(spot == .bubbleFountain ? .bubble : .pop, volume: 0.55)
            hapticTap()
            return existing.kind
        }

        let shouldReveal = rustlingSpots.contains(spot) || encounter == nil
        guard shouldReveal else {
            play(spot == .bubbleFountain ? .bubble : .pop, volume: 0.65)
            hapticTap()
            return nil
        }

        let kind = pickNextFairy(for: spot)
        return startEncounter(for: kind, from: spot)
    }

    @discardableResult
    func startEncounter(
        for kind: FairyKind,
        from spot: MeadowSpot,
        chimeSequence: [MeadowChime]? = nil
    ) -> FairyKind {
        rustlingSpots.removeAll()
        spotWiggleUntil[spot] = time + 0.85
        play(spot == .bubbleFountain ? .bubble : .boing, volume: 0.6)
        play(.sparkle, volume: 0.7)
        hapticTap()
        emitBurst(.star, at: spot.popOrigin, count: 10, colorHex: kind.palette.emblem)
        emitBurst(.heart, at: spot.popOrigin, count: 6, colorHex: 0xFF8FB8)

        let phase: MeadowEncounterPhase
        switch kind.encounterKind {
        case .flutterDash:
            let perches = FGeo.flutterPerches
            let startIdx = perches.indices.max(by: {
                hypot(perches[$0].x - spot.popOrigin.x, perches[$0].y - spot.popOrigin.y)
                    < hypot(perches[$1].x - spot.popOrigin.x, perches[$1].y - spot.popOrigin.y)
            }) ?? 2
            let state = FlutterDashState(
                dashProgress: 0,
                targetCount: Self.flutterDashTarget,
                perches: perches,
                currentPerchIndex: startIdx,
                fromPosition: spot.popOrigin,
                targetPosition: perches[startIdx],
                position: spot.popOrigin,
                dartProgress: 0,
                peekTimer: 0,
                ribbonTrail: [spot.popOrigin],
                starHearts: [],
                lastHitAt: -10,
                phase: Double.random(in: 0...(2 * .pi))
            )
            phase = .flutterDash(state)
            publishMutation { self.activeTreatLureFairy = nil }

        case .bubblePop:
            let centers: [CGPoint] = [
                CGPoint(x: 215, y: 270),
                CGPoint(x: 382, y: 235),
                CGPoint(x: 545, y: 292),
                CGPoint(x: 716, y: 244),
                CGPoint(x: 822, y: 386),
                CGPoint(x: 312, y: 416),
            ]
            let fairyIndex = Int.random(in: 0..<centers.count)
            let tints: [UInt32] = [0x9FE3FF, 0xC9B6FF, 0x9FE3CF, 0xFFE38A, 0xFFB8DC, 0xB8E4FF]
            let bubbles: [MeadowBubble] = centers.enumerated().map { idx, c in
                let isFairy = idx == fairyIndex
                return MeadowBubble(
                    id: allocID(),
                    pos: c,
                    vel: CGVector(
                        dx: CGFloat.random(in: 20...34) * (idx.isMultiple(of: 2) ? 1 : -1),
                        dy: CGFloat.random(in: 12...22) * (idx % 3 == 0 ? 1 : -1)
                    ),
                    radius: isFairy ? 58 : CGFloat.random(in: 46...54),
                    containsFairy: isFairy,
                    tintHex: isFairy ? 0xFF9AC8 : tints[idx % tints.count],
                    phase: Double(idx) * 1.15
                )
            }
            phase = .bubblePop(BubblePopState(bubbles: bubbles))
            publishMutation { self.activeTreatLureFairy = nil }

        case .chimeEcho:
            let patterns: [[MeadowChime]] = totalCatches < 2
                ? [[.left, .middle], [.middle, .right], [.left, .right]]
                : [[.left, .middle, .right], [.right, .middle, .left], [.left, .right, .middle], [.middle, .left, .right]]
            let seq = (chimeSequence?.isEmpty == false ? chimeSequence! : nil) ?? patterns.randomElement() ?? [.left, .middle, .right]
            let state = ChimeEchoState(
                sequence: seq,
                matchedCount: 0,
                playbackIndex: 0,
                playbackTimer: 0.45,
                activeDemoChime: nil,
                idleTimer: 0,
                hintedChime: nil,
                fairyPos: CGPoint(x: 512, y: 256),
                phase: Double.random(in: 0...(2 * .pi))
            )
            phase = .chimeEcho(state)
            publishMutation { self.activeTreatLureFairy = nil }

        case .treatLure:
            let homePos = CGPoint(
                x: max(180, min(844, spot.popOrigin.x)),
                y: min(350, spot.popOrigin.y - 30)
            )
            let state = TreatLureState(
                nibblesCount: 0,
                targetNibbles: Self.treatLureTargetNibbles,
                fairyPos: homePos,
                homePos: homePos,
                activeTreat: nil,
                ribbonSwirlPoints: [],
                ribbonSwirlProgress: 0,
                lastSwirlPoint: nil,
                phase: Double.random(in: 0...(2 * .pi))
            )
            phase = .treatLure(state)
            publishMutation { self.activeTreatLureFairy = kind }
        }

        encounter = MeadowEncounter(
            kind: kind,
            fromSpot: spot,
            encounterKind: kind.encounterKind,
            phase: phase,
            startedAt: time,
            lastInteractionAt: time
        )
        return kind
    }

    func transitionToCatchRing(for kind: FairyKind, from spot: MeadowSpot, startPos: CGPoint) {
        let ring = CatchRingState(
            anchor: FGeo.catchCenter,
            startPos: startPos,
            position: startPos,
            catchCharge: 0,
            isCharging: false,
            swirlAngle: 0,
            lastSwirlTip: nil,
            usedWand: false,
            appearedAt: time,
            caughtAt: nil,
            phase: Double.random(in: 0...(2 * .pi))
        )
        encounter = MeadowEncounter(
            kind: kind,
            fromSpot: spot,
            encounterKind: kind.encounterKind,
            phase: .catching(ring),
            startedAt: encounter?.startedAt ?? time,
            lastInteractionAt: time
        )
        publishMutation { self.activeTreatLureFairy = nil }
        play(.sparkle, volume: 0.8)
        play(.note4, volume: 0.7)
        emitBurst(.heart, at: startPos, count: 10, colorHex: kind.palette.emblem)
        emitBurst(.star, at: startPos, count: 10, colorHex: 0xFFE38A)
    }

    @discardableResult
    func tapFlutterDash(viaWand: Bool = false) -> Bool {
        guard var enc = encounter, case .flutterDash(var state) = enc.phase else { return false }
        if viaWand && time - state.lastHitAt < 0.25 { return false }

        state.lastHitAt = time
        state.dashProgress += 1
        enc.lastInteractionAt = time

        let hitPos = state.position
        let notes: [SFX] = [.note1, .note2, .note3]
        play(notes[min(notes.count - 1, max(0, state.dashProgress - 1))], volume: 0.8)
        play(.sparkle, volume: 0.7)
        hapticTap()

        emitBurst(.heart, at: hitPos, count: 10, colorHex: enc.kind.palette.emblem)
        emitBurst(.star, at: hitPos, count: 8, colorHex: 0xFFE38A)

        state.starHearts.append(FloatingStarHeart(
            id: allocID(),
            pos: CGPoint(x: hitPos.x, y: hitPos.y - 12),
            vel: CGVector(dx: CGFloat.random(in: -22...22), dy: -46),
            age: 0,
            maxAge: 2.6,
            colorHex: enc.kind.palette.emblem
        ))

        if viaWand {
            discover(.wandMagic, at: hitPos)
        }

        if state.dashProgress >= state.targetCount {
            transitionToCatchRing(for: enc.kind, from: enc.fromSpot, startPos: hitPos)
            return true
        }

        advanceFlutterPerch(&state, kind: enc.kind)
        enc.phase = .flutterDash(state)
        encounter = enc
        return true
    }

    @discardableResult
    func popMeadowBubble(id: Int, viaWand: Bool = false) -> Bool {
        guard var enc = encounter, case .bubblePop(var state) = enc.phase,
              let idx = state.bubbles.firstIndex(where: { $0.id == id }) else { return false }

        let popped = state.bubbles.remove(at: idx)
        enc.lastInteractionAt = time
        play(.bubble, volume: 0.85)
        play(.pop, volume: 0.65)
        hapticTap()

        emitBurst(.bubble, at: popped.pos, count: 10, colorHex: popped.tintHex)
        emitBurst(.star, at: popped.pos, count: 8, colorHex: 0xFFE38A)
        if viaWand {
            discover(.wandMagic, at: popped.pos)
        }

        if popped.containsFairy {
            emitBurst(.heart, at: popped.pos, count: 14, colorHex: enc.kind.palette.emblem)
            transitionToCatchRing(for: enc.kind, from: enc.fromSpot, startPos: popped.pos)
            return true
        }

        enc.phase = .bubblePop(state)
        encounter = enc
        return true
    }

    @discardableResult
    func ringChime(_ chime: MeadowChime) -> FairyKind? {
        chimeSwingUntil[chime] = time + 1.15
        play(chime.sfx, volume: 0.85)
        hapticTap()
        emitBurst(.note, at: chime.center, count: 7, colorHex: chime.colorHex)
        emitBurst(.star, at: chime.center, count: 5, colorHex: 0xFFE38A)
        discover(.musicChime, at: chime.center)

        if var enc = encounter {
            enc.lastInteractionAt = time
            if case .chimeEcho(var state) = enc.phase {
                state.playbackIndex = nil
                state.activeDemoChime = nil
                if state.matchedCount < state.sequence.count {
                    let expected = state.sequence[state.matchedCount]
                    if chime == expected {
                        state.matchedCount += 1
                        state.idleTimer = 0
                        state.hintedChime = nil
                        emitBurst(.heart, at: state.fairyPos, count: 8, colorHex: enc.kind.palette.emblem)
                        if state.matchedCount >= state.sequence.count {
                            transitionToCatchRing(for: enc.kind, from: enc.fromSpot, startPos: state.fairyPos)
                            return enc.kind
                        }
                    } else {
                        // Zero fail state: softly highlight the next chime as a friendly cue.
                        state.hintedChime = expected
                        state.idleTimer = 0
                    }
                }
                enc.phase = .chimeEcho(state)
                encounter = enc
            }
            return enc.kind
        }

        // Idle meadow: ringing a chime calls out a musical fairy!
        let chimeFairies: [FairyKind] = FairyKind.allCases.filter { $0.encounterKind == .chimeEcho }
        let unbefriendedChime = chimeFairies.filter { !befriended.contains($0) }
        let chosen = (unbefriendedChime.isEmpty ? chimeFairies : unbefriendedChime).randomElement() ?? .melody
        return startEncounter(for: chosen, from: chosen.preferredSpot)
    }

    @discardableResult
    func serveMeadowTreat(_ treatKind: MeadowTreatKind, from startPos: CGPoint? = nil) -> Bool {
        guard var enc = encounter, case .treatLure(var state) = enc.phase else { return false }
        enc.lastInteractionAt = time

        // If a previous treat is mid-nibble, count it immediately so rapid taps feel responsive!
        if state.activeTreat != nil {
            state.activeTreat = nil
            state.nibblesCount += 1
            if state.nibblesCount >= state.targetNibbles {
                transitionToCatchRing(for: enc.kind, from: enc.fromSpot, startPos: FGeo.treatMatCenter)
                return true
            }
        }

        let origin = startPos ?? CGPoint(x: FGeo.treatMatCenter.x, y: GameChromeLayout.dockY - 24)
        let targetOffsetX: CGFloat = state.nibblesCount == 0 ? -12 : 12
        let target = CGPoint(x: FGeo.treatMatCenter.x + targetOffsetX, y: FGeo.treatMatCenter.y - 6)
        state.activeTreat = PlacedMeadowTreat(
            id: allocID(),
            kind: treatKind,
            pos: origin,
            startPos: origin,
            targetPos: target,
            flightProgress: 0,
            nibbled: false,
            nibbleProgress: 0
        )
        enc.phase = .treatLure(state)
        encounter = enc

        play(.whoosh, volume: 0.55)
        play(.sparkle, volume: 0.5)
        hapticTap()
        emitBurst(.heart, at: target, count: 6, colorHex: treatKind.accentHex)
        return true
    }

    func traceSilkRibbon(at point: CGPoint) {
        guard var enc = encounter,
              enc.kind == .silk,
              case .treatLure(var state) = enc.phase else { return }
        guard hypot(point.x - FGeo.treatMatCenter.x, point.y - FGeo.treatMatCenter.y) <= 170 else { return }

        enc.lastInteractionAt = time
        if let prev = state.lastSwirlPoint {
            let d = hypot(point.x - prev.x, point.y - prev.y)
            guard d >= 8 else { return }
            state.ribbonSwirlProgress += d / 210
        }
        state.lastSwirlPoint = point
        state.ribbonSwirlPoints.append(point)
        if state.ribbonSwirlPoints.count > 26 {
            state.ribbonSwirlPoints.removeFirst(state.ribbonSwirlPoints.count - 26)
        }
        spawnParticle(.star, at: point, vel: CGVector(dx: CGFloat.random(in: -14...14), dy: -22), maxAge: 0.7, size: 10, colorHex: 0x9EE3CB)

        if state.ribbonSwirlProgress >= 1.0 {
            state.ribbonSwirlProgress = 0
            state.lastSwirlPoint = nil
            state.nibblesCount += 1
            play(.sparkle, volume: 0.8)
            hapticTap()
            emitBurst(.heart, at: FGeo.treatMatCenter, count: 10, colorHex: FairyKind.silk.palette.emblem)
            if state.nibblesCount >= state.targetNibbles {
                transitionToCatchRing(for: enc.kind, from: enc.fromSpot, startPos: FGeo.treatMatCenter)
                return
            }
        }
        enc.phase = .treatLure(state)
        encounter = enc
    }

    @discardableResult
    func chargeCatchRing(by amount: CGFloat, viaWand: Bool = false) -> Bool {
        guard var enc = encounter,
              case .catching(var ring) = enc.phase,
              ring.caughtAt == nil else { return false }

        enc.lastInteractionAt = time
        ring.catchCharge = min(1.0, ring.catchCharge + max(0, amount))
        ring.swirlAngle += 0.9
        if viaWand {
            ring.usedWand = true
        }
        enc.phase = .catching(ring)
        encounter = enc

        let noteSFX: SFX = ring.catchCharge < 0.45 ? .note1 : (ring.catchCharge < 0.85 ? .note2 : .note4)
        play(noteSFX, volume: 0.75)
        play(.sparkle, volume: 0.65)
        hapticTap()
        emitBurst(.heart, at: ring.position, count: 8, colorHex: enc.kind.palette.emblem)
        emitBurst(.star, at: ring.position, count: 6, colorHex: 0xFFE38A)

        if ring.catchCharge >= 1.0 {
            _ = befriendActiveFairy(viaWand: ring.usedWand)
        }
        return true
    }

    @discardableResult
    func befriendActiveFairy(viaWand: Bool = false) -> FairyKind? {
        guard var enc = encounter,
              case .catching(var ring) = enc.phase,
              ring.caughtAt == nil else { return nil }

        ring.caughtAt = time
        ring.catchCharge = 1.0
        enc.phase = .catching(ring)
        encounter = enc

        let kind = enc.kind
        let pos = ring.position
        let isNew = !befriended.contains(kind)
        let shouldAwardCoins = isNew || (time - lastCoinAwardTime >= Self.repeatCoinCooldown)
        if shouldAwardCoins {
            lastCoinAwardTime = time
        }

        celebration = CatchCelebration(kind: kind, startPos: pos, startedAt: time, isNew: isNew)
        holdingCatchRing = false
        holdCatchPoint = nil

        // Welcome newly caught fairy directly into the Compact Dollhouse if room has space (< 8)!
        if !compactActors.contains(where: { $0.kind == kind }) && compactActors.count < Self.maxCompactFairies {
            let spawnPos = pickRoamingDestination(excluding: kind)
            compactActors.append(makeCompactActor(kind: kind, at: spawnPos, spot: nil))
        }
        let updatedCompactList = compactActors.map(\.kind)

        play(.fanfare, volume: 0.72)
        play(.cheer, volume: 0.48)
        hapticTap()
        emitBurst(.heart, at: pos, count: 16, colorHex: kind.palette.emblem)
        emitBurst(.star, at: pos, count: 16, colorHex: 0xFFE38A)
        emitBurst(.confetti, at: pos, count: 18, colorHex: 0xFFB8DC)

        if shouldAwardCoins {
            earnCoins(Self.catchCoinReward, from: pos)
        }

        discover(.firstFairy, at: pos)
        if viaWand || ring.usedWand {
            discover(.wandMagic, at: pos)
        }
        if kind == .silk {
            discover(.silkFairy, at: pos)
        }

        publishMutation {
            if !self.befriended.contains(kind) {
                self.befriended.append(kind)
                self.selectedFairy = kind
                self.hasCompactBadge = true
            }
            self.totalCatches += 1
            self.activeTreatLureFairy = nil
            self.activeCompactFairies = updatedCompactList
            if self.befriended.count >= 6 {
                self.discover(.rainbowCollection, at: pos)
            }
            self.save()
        }
        return kind
    }

    // MARK: - Meadow Touch & Drag Input

    func meadowTouchMoved(to point: CGPoint, isStart: Bool) {
        guard mode == .meadow else { return }
        guard let enc = encounter else { return }

        switch enc.phase {
        case .catching(let ring) where ring.caughtAt == nil:
            if hypot(point.x - ring.position.x, point.y - ring.position.y) <= 124 {
                if isStart {
                    holdCatchStartedAt = time
                }
                holdingCatchRing = true
                holdCatchPoint = point
            } else {
                holdingCatchRing = false
                holdCatchPoint = nil
            }

        case .bubblePop(let state):
            for b in state.bubbles {
                if hypot(point.x - b.pos.x, point.y - b.pos.y) <= b.radius + 22 {
                    _ = popMeadowBubble(id: b.id, viaWand: false)
                    return
                }
            }

        case .treatLure:
            if enc.kind == .silk && !isStart {
                traceSilkRibbon(at: point)
            }

        default:
            break
        }
    }

    func meadowTouchEnded(at point: CGPoint, movedDistance: CGFloat) {
        guard mode == .meadow else { return }
        let wasLongCatchHold = holdingCatchRing && (time - holdCatchStartedAt >= 0.25)
        holdingCatchRing = false
        holdCatchPoint = nil

        if var enc = encounter, case .treatLure(var lure) = enc.phase {
            lure.lastSwirlPoint = nil
            enc.phase = .treatLure(lure)
            encounter = enc
        }

        if movedDistance < 24 && !wasLongCatchHold {
            tapMeadow(at: point)
        }
    }

    func tapMeadow(at point: CGPoint) {
        if let enc = encounter {
            switch enc.phase {
            case .catching(let ring) where ring.caughtAt == nil:
                if hypot(point.x - ring.position.x, point.y - ring.position.y) <= 122 {
                    _ = chargeCatchRing(by: 0.38, viaWand: false)
                    return
                }
            case .flutterDash(var state):
                // Collect floating star-hearts for extra sparkle delight
                for i in state.starHearts.indices.reversed() {
                    if hypot(point.x - state.starHearts[i].pos.x, point.y - state.starHearts[i].pos.y) <= 44 {
                        let hp = state.starHearts.remove(at: i).pos
                        var updatedEnc = enc
                        updatedEnc.phase = .flutterDash(state)
                        encounter = updatedEnc
                        play(.ding, volume: 0.7)
                        emitBurst(.star, at: hp, count: 10, colorHex: 0xFFE38A)
                        return
                    }
                }
                if hypot(point.x - state.position.x, point.y - state.position.y) <= 94 {
                    _ = tapFlutterDash(viaWand: false)
                    return
                }
            case .bubblePop(let state):
                for b in state.bubbles {
                    if hypot(point.x - b.pos.x, point.y - b.pos.y) <= b.radius + 24 {
                        _ = popMeadowBubble(id: b.id, viaWand: false)
                        return
                    }
                }
            case .chimeEcho:
                for chime in MeadowChime.allCases {
                    if hypot(point.x - chime.center.x, point.y - chime.center.y) <= chime.hitRadius + 10 {
                        _ = ringChime(chime)
                        return
                    }
                }
            case .treatLure:
                if hypot(point.x - FGeo.treatMatCenter.x, point.y - FGeo.treatMatCenter.y) <= FGeo.treatMatRadius {
                    emitBurst(.heart, at: point, count: 5, colorHex: 0xFF8FB8)
                    play(.pop, volume: 0.45)
                    return
                }
            default:
                break
            }
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

    // MARK: - Meadow Treat Dragging

    func beginMeadowTreatDrag(_ treat: MeadowTreatKind, at liftedPoint: CGPoint) {
        draggingMeadowTreat = treat
        draggingTreatPos = liftedPoint
        play(.pop, volume: 0.5)
        hapticTap()
    }

    func updateMeadowTreatDrag(to liftedPoint: CGPoint) {
        guard draggingMeadowTreat != nil else { return }
        draggingTreatPos = liftedPoint
    }

    func endMeadowTreatDrag(at liftedPoint: CGPoint) {
        guard let treat = draggingMeadowTreat else { return }
        draggingMeadowTreat = nil
        // Generous clearing drop zone above the bottom dock!
        if liftedPoint.y < 650 {
            _ = serveMeadowTreat(treat, from: liftedPoint)
        }
    }

    func cancelMeadowTreatDrag() {
        draggingMeadowTreat = nil
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

        let start = CGPoint(x: FGeo.wandHomeCenter.x, y: FGeo.wandHomeCenter.y - 60)

        if let enc = encounter {
            switch enc.phase {
            case .catching(let ring) where ring.caughtAt == nil:
                wandSweep = WandAutoSweep(start: start, target: ring.position, startedAt: time, duration: 0.46, action: .chargeCatchRing)
                return
            case .flutterDash(let state):
                wandSweep = WandAutoSweep(start: start, target: state.position, startedAt: time, duration: 0.46, action: .chaseFlutterDash)
                return
            case .bubblePop(let state):
                if let target = state.bubbles.first(where: { $0.containsFairy }) ?? state.bubbles.first {
                    wandSweep = WandAutoSweep(start: start, target: target.pos, startedAt: time, duration: 0.48, action: .popBubble(target.id))
                    return
                }
            case .chimeEcho(let state):
                if state.matchedCount < state.sequence.count {
                    let chime = state.sequence[state.matchedCount]
                    wandSweep = WandAutoSweep(start: start, target: chime.center, startedAt: time, duration: 0.48, action: .ringChime(chime))
                    return
                }
            case .treatLure:
                let treat: MeadowTreatKind = enc.kind == .silk ? .silkSwirl : .bungeoppang
                wandSweep = WandAutoSweep(start: start, target: FGeo.treatMatCenter, startedAt: time, duration: 0.5, action: .lureTreat(treat))
                return
            default:
                break
            }
        }

        ensureRustlingSpots()
        let targetSpot = rustlingSpots.first ?? .blossomBush
        wandSweep = WandAutoSweep(start: start, target: targetSpot.center, startedAt: time, duration: 0.52, action: .coaxSpot(targetSpot))
    }

    private func checkWandInteractions(at tip: CGPoint) {
        if let enc = encounter {
            switch enc.phase {
            case .catching(let ring) where ring.caughtAt == nil:
                if hypot(tip.x - ring.position.x, tip.y - ring.position.y) <= 122 {
                    discover(.wandMagic, at: tip)
                    return
                }
            case .flutterDash(let state):
                if hypot(tip.x - state.position.x, tip.y - state.position.y) <= 92 {
                    _ = tapFlutterDash(viaWand: true)
                    return
                }
            case .bubblePop(let state):
                for b in state.bubbles {
                    if hypot(tip.x - b.pos.x, tip.y - b.pos.y) <= b.radius + 22 {
                        _ = popMeadowBubble(id: b.id, viaWand: true)
                        return
                    }
                }
            case .chimeEcho:
                for chime in MeadowChime.allCases {
                    if hypot(tip.x - chime.center.x, tip.y - chime.center.y) <= chime.hitRadius + 12 {
                        let last = wandLastChimeCheck[chime] ?? -10
                        if time - last >= 0.65 {
                            wandLastChimeCheck[chime] = time
                            discover(.wandMagic, at: chime.center)
                            _ = ringChime(chime)
                        }
                        return
                    }
                }
            case .treatLure:
                if enc.kind == .silk {
                    traceSilkRibbon(at: tip)
                }
                return
            default:
                break
            }
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

    // MARK: - Mode B: Alive Free-Roaming Heart Jewel Compact Dollhouse

    func spot(containing fairy: FairyKind) -> CompactSpot? {
        if let actor = compactActors.first(where: { $0.kind == fairy }) {
            return actor.currentSpot
        }
        return spotOccupants.first(where: { $0.value == fairy })?.key
    }

    func isFairyInCompact(_ fairy: FairyKind) -> Bool {
        compactActors.contains(where: { $0.kind == fairy })
    }

    func compactActor(for fairy: FairyKind) -> CompactFairyActor? {
        compactActors.first(where: { $0.kind == fairy })
    }

    @discardableResult
    func inviteFairyToCompact(_ fairy: FairyKind, at position: CGPoint? = nil) -> Bool {
        guard befriended.contains(fairy) else { return false }

        if let idx = compactActors.firstIndex(where: { $0.kind == fairy }) {
            if let position {
                let clamped = FGeo.clampToCompactInterior(position)
                compactActors[idx].position = clamped
                compactActors[idx].target = clamped
                compactActors[idx].currentSpot = nil
                compactActors[idx].ridingCarousel = false
            }
            compactActors[idx].reactionUntil = time + 1.1
            compactActors[idx].mood = .giggle
            selectedFairy = fairy
            syncSpotOccupantsFromActors()
            save()
            return true
        }

        if compactActors.count >= Self.maxCompactFairies {
            // Gently make room by swapping out the oldest non-selected, non-pinned fairy.
            if let evictIdx = compactActors.firstIndex(where: { $0.kind != selectedFairy && $0.kind != pinnedFairy }) ?? compactActors.indices.first {
                compactActors.remove(at: evictIdx)
            }
        }

        let spawnPos = position.map(FGeo.clampToCompactInterior) ?? pickRoamingDestination(excluding: fairy)
        var actor = makeCompactActor(kind: fairy, at: spawnPos, spot: nil)
        actor.mood = .celebrate
        actor.reactionUntil = time + 1.2
        compactActors.append(actor)
        selectedFairy = fairy
        activeCompactFairies = compactActors.map(\.kind)
        syncSpotOccupantsFromActors()

        play(.sparkle, volume: 0.7)
        hapticTap()
        emitBurst(.heart, at: spawnPos, count: 8, colorHex: fairy.palette.emblem)

        if compactActors.count >= 3 {
            discover(.compactParty, at: spawnPos)
        }
        save()
        return true
    }

    func selectFairy(_ fairy: FairyKind, readyToPlace: Bool = false) {
        guard befriended.contains(fairy) else { return }
        selectedFairy = fairy
        pendingPlacementFairy = readyToPlace ? fairy : nil
        play(.pop, volume: 0.55)
        hapticTap()

        if mode == .compact && readyToPlace && !isFairyInCompact(fairy) {
            _ = inviteFairyToCompact(fairy)
            return
        }

        if let idx = compactActors.firstIndex(where: { $0.kind == fairy }) {
            compactActors[idx].reactionUntil = time + 1.0
            compactActors[idx].mood = .giggle
            emitBurst(.star, at: compactActors[idx].position, count: 6, colorHex: 0xFFE38A)
            if let spot = compactActors[idx].currentSpot {
                compactSpotReactUntil[spot] = time + 0.8
            }
        }
    }

    @discardableResult
    func placeFairy(_ fairy: FairyKind, at spot: CompactSpot) -> Bool {
        guard befriended.contains(fairy) else { return false }

        if !isFairyInCompact(fairy) {
            if compactActors.count >= Self.maxCompactFairies,
               let evictIdx = compactActors.firstIndex(where: { $0.currentSpot == nil && $0.kind != pinnedFairy }) ?? compactActors.indices.first {
                compactActors.remove(at: evictIdx)
            }
            let pos = CGPoint(x: spot.center.x + spot.fairyOffset.x, y: spot.center.y + spot.fairyOffset.y)
            compactActors.append(makeCompactActor(kind: fairy, at: pos, spot: nil))
        }

        guard let actorIdx = compactActors.firstIndex(where: { $0.kind == fairy }) else { return false }
        let oldSpot = compactActors[actorIdx].currentSpot
        let displacedIdx = compactActors.firstIndex(where: { $0.kind != fairy && $0.currentSpot == spot })

        if let displacedIdx {
            if let old = oldSpot {
                let oldPos = CGPoint(x: old.center.x + old.fairyOffset.x, y: old.center.y + old.fairyOffset.y)
                compactActors[displacedIdx].currentSpot = old
                compactActors[displacedIdx].position = oldPos
                compactActors[displacedIdx].target = oldPos
                compactActors[displacedIdx].mood = old.mood
            } else {
                compactActors[displacedIdx].currentSpot = nil
                compactActors[displacedIdx].target = pickRoamingDestination(excluding: compactActors[displacedIdx].kind)
            }
        }

        let targetPos = CGPoint(x: spot.center.x + spot.fairyOffset.x, y: spot.center.y + spot.fairyOffset.y)
        compactActors[actorIdx].currentSpot = spot
        compactActors[actorIdx].ridingCarousel = false
        compactActors[actorIdx].position = targetPos
        compactActors[actorIdx].target = targetPos
        compactActors[actorIdx].velocity = .zero
        compactActors[actorIdx].mood = spot.mood
        compactActors[actorIdx].idleTimer = Double.random(in: 5.5...8.5)
        compactActors[actorIdx].reactionUntil = time + 1.35

        selectedFairy = fairy
        pendingPlacementFairy = nil
        compactSpotReactUntil[spot] = time + 1.35

        activeCompactFairies = compactActors.map(\.kind)
        syncSpotOccupantsFromActors()

        playCompactSpotSound(spot)
        hapticTap()
        emitCompactSpotParticles(spot, fairy: fairy)

        if let wish = compactActors[actorIdx].wish, wish.matchingSpot == spot {
            _ = fulfillWish(for: fairy)
        }

        if compactActors.count >= 3 || spotOccupants.count >= 3 {
            discover(.compactParty, at: spot.center)
        }
        save()
        return true
    }

    func removeFairyFromCompact(_ fairy: FairyKind) {
        guard let idx = compactActors.firstIndex(where: { $0.kind == fairy }) else { return }
        compactActors.remove(at: idx)
        activeCompactFairies = compactActors.map(\.kind)
        syncSpotOccupantsFromActors()
        play(.whoosh, volume: 0.5)
        hapticTap()
        save()
    }

    private func syncSpotOccupantsFromActors() {
        var next: [CompactSpot: FairyKind] = [:]
        for actor in compactActors {
            if let s = actor.currentSpot, next[s] == nil {
                next[s] = actor.kind
            }
        }
        spotOccupants = next
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
            let burstPos = compactActor(for: target)?.position ?? FGeo.compactCenter
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
            let burstPos = compactActor(for: target)?.position ?? FGeo.compactCenter
            emitBurst(.star, at: burstPos, count: 14, colorHex: 0xFFD452)
            emitBurst(.heart, at: burstPos, count: 8, colorHex: target.palette.emblem)
        }
        hapticTap()
        syncPinnedFairyDefaults()
        save()
        return pinnedFairy
    }

    // MARK: - Interactive Compact Toys & Owned Treasures

    func triggerTeacupBubbles() {
        compactSpotReactUntil[.teacupBath] = time + 1.3
        play(.bubble, volume: 0.85)
        hapticTap()

        let base = CompactSpot.teacupBath.center
        let tints: [UInt32] = [0x9FE3FF, 0xFFB8DC, 0xC9B6FF, 0x9FE3CF, 0xFFE38A]
        let spawnCount = 5
        for i in 0..<spawnCount {
            let b = CompactBubble(
                id: allocID(),
                pos: CGPoint(x: base.x + CGFloat(i - 2) * 20 + CGFloat.random(in: -8...8), y: base.y - 24 - CGFloat(i) * 8),
                vel: CGVector(dx: CGFloat.random(in: -16...24), dy: CGFloat.random(in: -54...(-36))),
                radius: CGFloat.random(in: 22...31),
                age: 0,
                maxAge: 6.5,
                tintHex: tints[i % tints.count],
                phase: Double(i) * 1.1
            )
            compactBubbles.append(b)
        }
        if compactBubbles.count > 14 {
            compactBubbles.removeFirst(compactBubbles.count - 14)
        }

        // Summon any fairy wishing for bubbles over to the teacup bath!
        if let idx = compactActors.firstIndex(where: { $0.wish == .bubbles }) {
            let bathPos = CGPoint(x: base.x + CompactSpot.teacupBath.fairyOffset.x, y: base.y + CompactSpot.teacupBath.fairyOffset.y)
            compactActors[idx].currentSpot = .teacupBath
            compactActors[idx].target = bathPos
            compactActors[idx].ridingCarousel = false
            compactActors[idx].idleTimer = 5.5
            _ = fulfillWish(for: compactActors[idx].kind)
        }
        emitBurst(.bubble, at: CGPoint(x: base.x, y: base.y - 16), count: 8, colorHex: 0xA8E4FF)
    }

    @discardableResult
    func popCompactBubble(id: Int) -> Bool {
        guard let idx = compactBubbles.firstIndex(where: { $0.id == id }) else { return false }
        let b = compactBubbles.remove(at: idx)
        play(.bubble, volume: 0.8)
        play(.pop, volume: 0.65)
        hapticTap()
        emitBurst(.bubble, at: b.pos, count: 8, colorHex: b.tintHex)
        emitBurst(.star, at: b.pos, count: 6, colorHex: 0xFFE38A)
        fulfillMatchingWishes(for: .bubbles)
        return true
    }

    func pumpRainbowSwing() {
        compactSpotReactUntil[.rainbowSwing] = time + 1.5
        swingEnergy = min(1.0, swingEnergy + 0.58)
        play(.boing, volume: 0.72)
        play(.sparkle, volume: 0.5)
        hapticTap()

        let base = CompactSpot.rainbowSwing.center
        let swingPos = CGPoint(x: base.x + CompactSpot.rainbowSwing.fairyOffset.x, y: base.y + CompactSpot.rainbowSwing.fairyOffset.y)

        // Call a wishing fairy (or selected/nearest fairy if swing is empty) onto the swing!
        if let wishIdx = compactActors.firstIndex(where: { $0.wish == .swing }) {
            compactActors[wishIdx].currentSpot = .rainbowSwing
            compactActors[wishIdx].target = swingPos
            compactActors[wishIdx].ridingCarousel = false
            compactActors[wishIdx].mood = .giggle
            compactActors[wishIdx].idleTimer = 6.0
            _ = fulfillWish(for: compactActors[wishIdx].kind)
        } else if !compactActors.contains(where: { $0.currentSpot == .rainbowSwing }),
                  let riderIdx = compactActors.firstIndex(where: { $0.kind == selectedFairy }) ?? compactActors.indices.first {
            compactActors[riderIdx].currentSpot = .rainbowSwing
            compactActors[riderIdx].target = swingPos
            compactActors[riderIdx].ridingCarousel = false
            compactActors[riderIdx].mood = .giggle
            compactActors[riderIdx].idleTimer = 6.0
        }

        emitBurst(.star, at: base, count: 10, colorHex: 0xFFE38A)
        emitBurst(.heart, at: base, count: 6, colorHex: 0xFF8FB8)
    }

    func startDiscoParty() {
        isNightMode = false
        discoPartyTimer = Self.discoPartyDuration
        discoBeatTimer = 0
        compactSpotReactUntil[.danceStage] = time + Self.discoPartyDuration
        play(.fanfare, volume: 0.68)
        play(.note4, volume: 0.75)
        hapticTap()

        for i in compactActors.indices {
            compactActors[i].ridingCarousel = false
            compactActors[i].mood = .celebrate
            compactActors[i].reactionUntil = time + Self.discoPartyDuration
        }

        let center = CompactSpot.danceStage.center
        emitBurst(.note, at: center, count: 12, colorHex: 0xFF8FB8)
        emitBurst(.star, at: center, count: 14, colorHex: 0xFFE38A)
        emitBurst(.confetti, at: center, count: 14, colorHex: 0x9FE3CF)
        fulfillMatchingWishes(for: .dance)
    }

    func serveCompactTableTreats() {
        compactSpotReactUntil[.treatTable] = time + 1.5
        let base = CompactSpot.treatTable.center

        compactTableTreats.removeAll()
        compactTableTreats.append(CompactTableTreat(
            id: allocID(),
            kind: .macaron,
            pos: CGPoint(x: base.x - 28, y: base.y + 4),
            age: 0,
            maxAge: 7.5,
            nibbled: false
        ))
        compactTableTreats.append(CompactTableTreat(
            id: allocID(),
            kind: .bungeoppang,
            pos: CGPoint(x: base.x + 26, y: base.y + 6),
            age: 0,
            maxAge: 7.5,
            nibbled: false
        ))
        if hasHanbokTea {
            teaPourTimer = 2.6
            compactTableTreats.append(CompactTableTreat(
                id: allocID(),
                kind: .celadonTea,
                pos: CGPoint(x: base.x - 4, y: base.y + 12),
                age: 0,
                maxAge: 7.5,
                nibbled: false
            ))
            play(.bubble, volume: 0.6)
        }

        play(.pop, volume: 0.75)
        play(.sparkle, volume: 0.55)
        hapticTap()
        emitBurst(.heart, at: CGPoint(x: base.x, y: base.y - 16), count: 10, colorHex: 0xFF8FB8)

        // Call up to 2 fairies (prioritizing .snack wishers!) over to nibble with rosy cheeks!
        var invited = 0
        let sortedIndices = compactActors.indices.sorted { a, b in
            let aWish = compactActors[a].wish == .snack ? 0 : 1
            let bWish = compactActors[b].wish == .snack ? 0 : 1
            if aWish != bWish { return aWish < bWish }
            let da = hypot(compactActors[a].position.x - base.x, compactActors[a].position.y - base.y)
            let db = hypot(compactActors[b].position.x - base.x, compactActors[b].position.y - base.y)
            return da < db
        }
        let tableOffsets: [CGPoint] = [CGPoint(x: -22, y: -32), CGPoint(x: 24, y: -30)]
        for idx in sortedIndices where invited < 2 {
            compactActors[idx].currentSpot = .treatTable
            compactActors[idx].ridingCarousel = false
            compactActors[idx].target = CGPoint(x: base.x + tableOffsets[invited].x, y: base.y + tableOffsets[invited].y)
            compactActors[idx].mood = .yum
            compactActors[idx].idleTimer = 5.5
            compactActors[idx].reactionUntil = time + 1.5
            invited += 1
        }
        fulfillMatchingWishes(for: .snack)
    }

    func toggleNightMode() {
        isNightMode.toggle()
        if isNightMode {
            discoPartyTimer = 0
            play(.note1, volume: 0.7)
            play(.sparkle, volume: 0.65)
            emitBurst(.sleepyZ, at: CompactSpot.cloudBed.center, count: 10, colorHex: 0xC9B6FF)
            emitBurst(.star, at: FGeo.chandelierCenter, count: 12, colorHex: 0xFFE38A)
            fulfillMatchingWishes(for: .sleep)
        } else {
            play(.ding, volume: 0.7)
            play(.sparkle, volume: 0.65)
            emitBurst(.star, at: FGeo.chandelierCenter, count: 12, colorHex: 0xFFE38A)
            for i in compactActors.indices {
                compactActors[i].mood = .giggle
                compactActors[i].reactionUntil = time + 1.0
                compactActors[i].idleTimer = 1.2
            }
        }
        hapticTap()
    }

    @discardableResult
    func spinCompactCarousel() -> Bool {
        guard hasCarousel else { return false }
        isNightMode = false
        carouselBoostTimer = 4.6
        play(.note2, volume: 0.75)
        play(.sparkle, volume: 0.7)
        hapticTap()
        emitBurst(.star, at: CGPoint(x: FGeo.carouselCenter.x, y: FGeo.carouselCenter.y - 44), count: 12, colorHex: 0xFFB8E0)

        // Hop up to 2 nearby fairies (prioritizing .carousel wishers!) onto the orbiting cloud/star seats!
        let sorted = compactActors.indices.sorted { a, b in
            let aWish = compactActors[a].wish == .carousel ? 0 : 1
            let bWish = compactActors[b].wish == .carousel ? 0 : 1
            if aWish != bWish { return aWish < bWish }
            let da = hypot(compactActors[a].position.x - FGeo.carouselCenter.x, compactActors[a].position.y - FGeo.carouselCenter.y)
            let db = hypot(compactActors[b].position.x - FGeo.carouselCenter.x, compactActors[b].position.y - FGeo.carouselCenter.y)
            return da < db
        }
        var seat = 0
        for idx in sorted where seat < 2 {
            compactActors[idx].currentSpot = nil
            compactActors[idx].ridingCarousel = true
            compactActors[idx].carouselSeatIndex = seat * 2
            compactActors[idx].mood = .giggle
            compactActors[idx].idleTimer = 5.5
            seat += 1
        }
        fulfillMatchingWishes(for: .carousel)
        return true
    }

    // MARK: - Compact Hit-Testing & Gestures

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

    func nearestCompactActor(to point: CGPoint, maxRadius: CGFloat = 58) -> CompactFairyActor? {
        var best: (CompactFairyActor, CGFloat)?
        for actor in compactActors {
            let d = hypot(point.x - actor.position.x, point.y - actor.position.y)
            if d <= maxRadius, best == nil || d < best!.1 {
                best = (actor, d)
            }
        }
        return best?.0
    }

    func tapCompact(at point: CGPoint) {
        // 1. Poppable floating soap bubbles from Teacup Bath get instant joyful tap priority!
        for b in compactBubbles.reversed() {
            if hypot(point.x - b.pos.x, point.y - b.pos.y) <= b.radius + 18 {
                _ = popCompactBubble(id: b.id)
                return
            }
        }

        // 2. Top arch / Chandelier toggles Cozy Starlight Night Mode!
        if hypot(point.x - FGeo.chandelierCenter.x, point.y - FGeo.chandelierCenter.y) <= 68 {
            toggleNightMode()
            return
        }

        // 3. Interactive Cloud Carousel (when owned)
        if hasCarousel && hypot(point.x - FGeo.carouselCenter.x, point.y - FGeo.carouselCenter.y + 24) <= 60 {
            _ = spinCompactCarousel()
            return
        }

        // 4. Pending placement from tray tap
        if let pending = pendingPlacementFairy, let spot = nearestCompactSpot(to: point, maxRadius: 98) {
            _ = placeFairy(pending, at: spot)
            return
        }

        // 5. Interactive Furniture Toys
        if let spot = nearestCompactSpot(to: point, maxRadius: 88) {
            if let actorOnSpot = compactActors.first(where: { $0.currentSpot == spot }) {
                selectedFairy = actorOnSpot.kind
            }
            switch spot {
            case .teacupBath:
                triggerTeacupBubbles()
            case .rainbowSwing:
                pumpRainbowSwing()
            case .danceStage:
                startDiscoParty()
            case .treatTable:
                serveCompactTableTreats()
            case .cloudBed:
                compactSpotReactUntil[.cloudBed] = time + 1.3
                play(.note1, volume: 0.7)
                hapticTap()
                emitBurst(.sleepyZ, at: spot.center, count: 8, colorHex: 0xC9B6FF)
                emitBurst(.star, at: spot.center, count: 6, colorHex: 0xFFE38A)
                if let wishIdx = compactActors.firstIndex(where: { $0.wish == .sleep }) {
                    _ = placeFairy(compactActors[wishIdx].kind, at: .cloudBed)
                } else if !compactActors.contains(where: { $0.currentSpot == .cloudBed }) {
                    _ = placeFairy(selectedFairy, at: .cloudBed)
                }
                fulfillMatchingWishes(for: .sleep)
            }
            return
        }

        // 6. Tapping a free-roaming fairy selects her & makes her giggle!
        if let tappedActor = nearestCompactActor(to: point, maxRadius: 56),
           let idx = compactActors.firstIndex(where: { $0.kind == tappedActor.kind }) {
            selectedFairy = tappedActor.kind
            compactActors[idx].mood = .giggle
            compactActors[idx].reactionUntil = time + 1.3
            play(.pop, volume: 0.6)
            hapticTap()
            emitBurst(.heart, at: tappedActor.position, count: 8, colorHex: tappedActor.kind.palette.emblem)
            return
        }

        // 7. Tapping the open room floor invites the selected fairy to flutter playfully over!
        if let idx = compactActors.firstIndex(where: { $0.kind == selectedFairy }) {
            let dest = FGeo.clampToCompactInterior(point)
            compactActors[idx].currentSpot = nil
            compactActors[idx].ridingCarousel = false
            compactActors[idx].target = dest
            compactActors[idx].idleTimer = 3.5
            compactActors[idx].mood = .happy
        }
        emitBurst(.star, at: point, count: 6, colorHex: 0xFFE38A)
        play(.tap, volume: 0.35)
    }

    func beginCompactDrag(fairy: FairyKind, fromSpot: CompactSpot?, at liftedPoint: CGPoint, fromRoom: Bool? = nil) {
        guard befriended.contains(fairy) else { return }
        let startedInRoom = fromRoom ?? (fromSpot != nil || isFairyInCompact(fairy))
        draggingCompactFairy = fairy
        compactDragOriginSpot = fromSpot
        compactDragStartedInRoom = startedInRoom
        compactDragPos = liftedPoint
        compactHoverSpot = nearestCompactSpot(to: liftedPoint, maxRadius: 108)
        compactReturnHovered = startedInRoom && liftedPoint.y >= FGeo.returnDropY - 36
        selectedFairy = fairy
        pendingPlacementFairy = nil
        play(.pop, volume: 0.5)
        hapticTap()
    }

    func updateCompactDrag(to liftedPoint: CGPoint) {
        guard draggingCompactFairy != nil else { return }
        compactDragPos = liftedPoint
        compactReturnHovered = compactDragStartedInRoom && liftedPoint.y >= FGeo.returnDropY - 36
        compactHoverSpot = compactReturnHovered ? nil : nearestCompactSpot(to: liftedPoint, maxRadius: 108)
    }

    func endCompactDrag(at liftedPoint: CGPoint) {
        guard let fairy = draggingCompactFairy else { return }
        let startedInRoom = compactDragStartedInRoom
        draggingCompactFairy = nil
        compactDragOriginSpot = nil
        compactDragStartedInRoom = false
        compactHoverSpot = nil
        let returning = startedInRoom && liftedPoint.y >= FGeo.returnDropY - 36
        compactReturnHovered = false

        if returning {
            removeFairyFromCompact(fairy)
            return
        }

        if hasCarousel && hypot(liftedPoint.x - FGeo.carouselCenter.x, liftedPoint.y - FGeo.carouselCenter.y + 20) <= 68 {
            _ = inviteFairyToCompact(fairy, at: FGeo.carouselCenter)
            if let idx = compactActors.firstIndex(where: { $0.kind == fairy }) {
                compactActors[idx].ridingCarousel = true
                compactActors[idx].currentSpot = nil
                compactActors[idx].carouselSeatIndex = 0
                compactActors[idx].idleTimer = 6.0
                if compactActors[idx].wish == .carousel {
                    _ = fulfillWish(for: fairy)
                }
            }
            carouselBoostTimer = max(carouselBoostTimer, 3.0)
            play(.note3, volume: 0.7)
            return
        }

        if let target = nearestCompactSpot(to: liftedPoint, maxRadius: 112) {
            _ = placeFairy(fairy, at: target)
            return
        }

        // Free-roaming placement anywhere inside the open Heart Compact!
        if liftedPoint.y < FGeo.returnDropY - 24 {
            _ = inviteFairyToCompact(fairy, at: liftedPoint)
            play(.pop, volume: 0.5)
        }
    }

    func cancelCompactDrag() {
        draggingCompactFairy = nil
        compactDragOriginSpot = nil
        compactDragStartedInRoom = false
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
            let speed = CGFloat.random(in: 36...118)
            spawnParticle(
                kind,
                at: origin,
                vel: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 30),
                maxAge: CGFloat.random(in: 0.75...1.4),
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
        if particles.count > 160 {
            particles.removeFirst(particles.count - 160)
        }
    }
}
