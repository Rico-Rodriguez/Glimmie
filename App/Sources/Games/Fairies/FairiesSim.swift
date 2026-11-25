import SwiftUI

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

enum FairyParticleKind: Equatable {
    case heart
    case star
    case bubble
    case note
    case petal
    case sleepyZ
    case confetti
}

struct WandSparkle: Equatable {
    var pos: CGPoint
    var age: CGFloat
    var maxAge: CGFloat
    var size: CGFloat
    var colorHex: UInt32
}

struct FallingGlitterGrain: Identifiable, Equatable {
    let id: Int
    var pos: CGPoint
    var vel: CGVector
    let targetY: CGFloat
    let colorHex: UInt32
    let size: Float
    var age: CGFloat
    let maxAge: CGFloat
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

struct FairiesUIState: Equatable {
    var station: FairyStation
    var selectedFairy: FairyKind
    var pinnedFairy: FairyKind?
    var accessories: [FairyKind: FairyAccessory]
    var activeCompactFairies: [FairyKind]
    var isNightMode: Bool
    var draggingCompactFairy: FairyKind?
    var compactDragStartedInRoom: Bool
    var compactReturnHovered: Bool
    var salonTool: FairySalonTool
    var canUndoWingStroke: Bool
    var wingDesignVersion: Int
    var currentWand: FairyWandDesign
    var tea: FairiesTeaUIState
    var activeTransforms: [FairyKind: TeaTransformKind]
    var hasHanbokTea: Bool
}

enum SimSideEffect: Equatable {
    case sound(SFX, Float)
    case haptic
    case coins(Int, CGPoint)
    case sticker(FairiesFind)
    case syncPinned(fairyID: String?, look: PinnedFairyLook?)
    case save
    case uiState(FairiesUIState)
}

final class FairiesSim {
    static let gameID = "fairies"
    static let saveFile = "fairies.json"
    static let wishCoinReward = 2
    static let wishCoinCooldown: Double = 8.0
    static let maxCompactFairies = FairiesSave.maxCompactFairies
    static let discoPartyDuration: Double = 6.0
    static let teaTransformDuration: Double = 30.0
    static let maxUndoDepth = 16

    private(set) var station: FairyStation = .stage
    private(set) var befriended: [FairyKind] = FairyKind.allCases
    private(set) var spotOccupants: [CompactSpot: FairyKind]
    private(set) var accessories: [FairyKind: FairyAccessory]
    private(set) var selectedFairy: FairyKind
    private(set) var pinnedFairy: FairyKind?
    private(set) var totalCatches: Int
    private(set) var teasServed: Int
    private(set) var wingDesigns: [FairyKind: FairyWingDesign]
    private(set) var wands: [FairyKind: FairyWandDesign]

    private(set) var draggingCompactFairy: FairyKind?
    private(set) var compactReturnHovered = false
    private(set) var activeCompactFairies: [FairyKind] = []
    private(set) var isNightMode = false
    private(set) var salonTool: FairySalonTool = .brush(.rosePearl)
    private(set) var teaSession: TeaSessionPhase
    private(set) var activeTransforms: [FairyKind: ActiveTeaTransform] = [:]
    private(set) var lastTeaStars: Int = 3

    var time: Double = 0
    private var lastTick: Date?
    private var inRenderStep = false
    private var nextEntityID = 1

    var particles: [FairyParticle] = []
    var compactActors: [CompactFairyActor] = []
    var compactBubbles: [CompactBubble] = []
    var compactTableTreats: [CompactTableTreat] = []
    var rainbowTrails: [FairyKind: [CGPoint]] = [:]

    var compactDragPos: CGPoint = .zero
    var compactDragOriginSpot: CompactSpot?
    var compactDragStartedInRoom = false
    var compactHoverSpot: CompactSpot?
    var compactSpotReactUntil: [CompactSpot: Double] = [:]
    var stationTransitionAt: Double = -10
    var pendingPlacementFairy: FairyKind?
    var discoPartyTimer: Double = 0
    var swingEnergy: CGFloat = 0
    var swingPhase: Double = 0
    var carouselSpinAngle: Double = 0
    var carouselBoostTimer: Double = 0
    var teaPourTimer: Double = 0
    var nextWishTimer: Double = 7.5

    var fallingGlitter: [FallingGlitterGrain] = []
    var salonToolPos: CGPoint?
    var salonFingerPos: CGPoint?
    var wandTrail: [WandSparkle] = []
    var wandWaveEnergy: CGFloat = 0
    var wandAutoWaveTimer: Double = 0
    var wandAutoWaveOrigin: CGPoint = FGeo.salonWandCenter

    var draggingTeapot: TeaNectar?
    var draggingTeapotPos: CGPoint = .zero
    var autoPourNectar: TeaNectar?
    var draggingSugarStar: SugarStarKind?
    var draggingSugarPos: CGPoint = .zero
    var draggingTeaTreat: FairyTeaTreatKind?
    var draggingTeaTreatPos: CGPoint = .zero

    var quiet = false
    var demo = false
    var deferAllEffectsForTesting = false
    var onUIStateChange: ((FairiesUIState) -> Void)?

    private(set) var lastWishCoinTime: Double = -100
    private(set) var unlockedFinds: Set<FairiesFind> = []

    var hasChandelier: Bool { Coins.shared.owns("fairies/chandelier") }
    var hasCarousel: Bool { Coins.shared.owns("fairies/carousel") }
    var hasHanbokTea: Bool { Coins.shared.owns("fairies/hanbokTea") }

    private let userDefaults: UserDefaults
    private let persist: Bool
    private let storageGameID: String
    private var outbox: [SimSideEffect] = []
    private var flushScheduled = false
    private var lastEmittedUIState: FairiesUIState?

    private var ambientTimer: Double = 0
    private var discoBeatTimer: Double = 0
    private var glitterShakeAccumulator: Double = 0
    private var wingUndoStacks: [FairyKind: [FairyWingDesign]] = [:]
    private var salonStrokeActive = false
    private var salonGestureUndoPushed = false
    private var salonDragActivated = false
    private var pendingGlitterUndo = false
    private var wingDesignVersion = 0
    private var sceneDragActor: CompactFairyActor?
    private var sceneDragStarted = false
    private var teaWishCounter = 0

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

        self.befriended = FairyKind.allCases
        self.spotOccupants = loaded.spotOccupants
        self.accessories = loaded.accessories
        let initialSelected = loaded.pinnedFairy ?? loaded.roamingFairies.first ?? .heart
        self.selectedFairy = initialSelected
        self.pinnedFairy = loaded.pinnedFairy
        self.totalCatches = loaded.totalCatches
        self.teasServed = loaded.teasServed
        self.wingDesigns = loaded.wingDesigns
        self.wands = loaded.wands

        let initialWish = Self.makeTeaWish(for: initialSelected, step: 0)
        self.teaSession = .awaitingPour(fairy: initialSelected, wish: initialWish, draft: TeaCupDraft())

        spawnInitialCompactActors(from: loaded)
        self.activeCompactFairies = compactActors.map(\.kind)

        writePinnedDefaultsDirectly()
        self.lastEmittedUIState = currentUIState()
    }

    private func allocID() -> Int {
        defer { nextEntityID += 1 }
        return nextEntityID
    }

    // MARK: - Outbox & UI Snapshot

    func currentWand(for fairy: FairyKind? = nil) -> FairyWandDesign {
        let target = fairy ?? selectedFairy
        return wands[target] ?? FairyWandDesign.starter(for: target.rawValue)
    }

    func wingDesign(for fairy: FairyKind? = nil) -> FairyWingDesign {
        let target = fairy ?? selectedFairy
        return wingDesigns[target] ?? FairyWingDesign()
    }

    func canUndoWingAction(for fairy: FairyKind? = nil) -> Bool {
        let target = fairy ?? selectedFairy
        return !(wingUndoStacks[target]?.isEmpty ?? true)
    }

    func currentUIState() -> FairiesUIState {
        let teaUI: FairiesTeaUIState
        switch teaSession {
        case .awaitingPour(_, let wish, let draft):
            teaUI = FairiesTeaUIState(
                wish: wish,
                stage: .awaitingPour,
                selectedNectar: draft.nectar ?? wish.nectar,
                cupHasLiquid: draft.fillLevel > 0.02,
                cupFilled: draft.hasNectar,
                sugarCount: draft.sugarStars.count,
                sugarStars: draft.sugarStars,
                platedTreat: draft.platedTreat,
                hasTreat: draft.platedTreat != nil,
                canServe: draft.isReadyToServe,
                transformedEffect: nil,
                earnedStars: nil
            )
        case .pouring(_, let wish, let draft, let activeNectar):
            teaUI = FairiesTeaUIState(
                wish: wish,
                stage: .pouring,
                selectedNectar: activeNectar,
                cupHasLiquid: draft.fillLevel > 0.02,
                cupFilled: draft.hasNectar,
                sugarCount: draft.sugarStars.count,
                sugarStars: draft.sugarStars,
                platedTreat: draft.platedTreat,
                hasTreat: draft.platedTreat != nil,
                canServe: draft.isReadyToServe,
                transformedEffect: nil,
                earnedStars: nil
            )
        case .ready(_, let wish, let draft):
            teaUI = FairiesTeaUIState(
                wish: wish,
                stage: .ready,
                selectedNectar: draft.nectar ?? wish.nectar,
                cupHasLiquid: true,
                cupFilled: true,
                sugarCount: draft.sugarStars.count,
                sugarStars: draft.sugarStars,
                platedTreat: draft.platedTreat,
                hasTreat: draft.platedTreat != nil,
                canServe: true,
                transformedEffect: nil,
                earnedStars: nil
            )
        case .sipping(_, let wish, let draft, _):
            teaUI = FairiesTeaUIState(
                wish: wish,
                stage: .sipping,
                selectedNectar: draft.nectar ?? wish.nectar,
                cupHasLiquid: true,
                cupFilled: true,
                sugarCount: draft.sugarStars.count,
                sugarStars: draft.sugarStars,
                platedTreat: draft.platedTreat,
                hasTreat: draft.platedTreat != nil,
                canServe: false,
                transformedEffect: nil,
                earnedStars: nil
            )
        case .transformed(_, let wish, let transform, _):
            teaUI = FairiesTeaUIState(
                wish: wish,
                stage: .transformed,
                selectedNectar: wish.nectar,
                cupHasLiquid: false,
                cupFilled: false,
                sugarCount: 0,
                sugarStars: [],
                platedTreat: nil,
                hasTreat: false,
                canServe: false,
                transformedEffect: transform,
                earnedStars: lastTeaStars
            )
        }
        let transformMap = activeTransforms.mapValues(\.kind)
        return FairiesUIState(
            station: station,
            selectedFairy: selectedFairy,
            pinnedFairy: pinnedFairy,
            accessories: accessories,
            activeCompactFairies: activeCompactFairies,
            isNightMode: isNightMode,
            draggingCompactFairy: draggingCompactFairy,
            compactDragStartedInRoom: compactDragStartedInRoom,
            compactReturnHovered: compactReturnHovered,
            salonTool: salonTool,
            canUndoWingStroke: canUndoWingAction(),
            wingDesignVersion: wingDesignVersion,
            currentWand: currentWand(),
            tea: teaUI,
            activeTransforms: transformMap,
            hasHanbokTea: hasHanbokTea
        )
    }

    private func enqueue(_ effect: SimSideEffect) {
        switch effect {
        case .save:
            outbox.removeAll { $0 == .save }
        case .uiState:
            outbox.removeAll {
                if case .uiState = $0 { return true }
                return false
            }
        case .syncPinned:
            outbox.removeAll {
                if case .syncPinned = $0 { return true }
                return false
            }
        default:
            break
        }
        outbox.append(effect)
        schedulePostFrameFlush()
    }

    private func enqueueUIStateIfChanged() {
        let snapshot = currentUIState()
        guard snapshot != lastEmittedUIState else { return }
        lastEmittedUIState = snapshot
        enqueue(.uiState(snapshot))
    }

    func schedulePostFrameFlush() {
        guard !deferAllEffectsForTesting else { return }
        if inRenderStep {
            guard !flushScheduled else { return }
            flushScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.flushPendingEffects()
            }
        }
    }

    func flushPendingEffects() {
        flushScheduled = false
        guard !outbox.isEmpty else { return }
        let pending = outbox
        outbox.removeAll(keepingCapacity: true)

        for effect in pending {
            switch effect {
            case .sound(let sfx, let vol):
                if !quiet {
                    Sound.shared.play(sfx, volume: vol)
                }
            case .haptic:
                if !quiet {
                    Sound.shared.tap()
                }
            case .coins(let amount, let point):
                if amount > 0 && (!demo || Coins.shared.demo) {
                    Coins.shared.earn(amount, game: Self.gameID, from: point)
                }
            case .sticker(let find):
                if !demo || StickerBook.shared.demo {
                    _ = StickerBook.shared.find(game: Self.gameID, id: find.rawValue)
                }
            case .syncPinned(let fairyID, let look):
                PinnedFairyCodec.write(fairyID: fairyID, look: look, to: userDefaults)
            case .save:
                saveAsync()
            case .uiState(let state):
                onUIStateChange?(state)
            }
        }
    }

    func drainEffectsForTesting() -> [SimSideEffect] {
        flushScheduled = false
        let drained = outbox
        outbox.removeAll(keepingCapacity: true)
        return drained
    }

    private func finishDirectInteraction() {
        enqueueUIStateIfChanged()
        if !inRenderStep && !deferAllEffectsForTesting {
            flushPendingEffects()
        }
    }

    // MARK: - Persistence & Dress Up Pinned Fairy Sync

    func currentSave() -> FairiesSave {
        FairiesSave(
            befriended: FairyKind.allCases,
            spotOccupants: spotOccupants,
            accessories: accessories,
            pinnedFairy: pinnedFairy,
            totalCatches: totalCatches,
            roamingFairies: compactActors.map(\.kind),
            wingDesigns: wingDesigns,
            wands: wands,
            teasServed: teasServed
        )
    }

    func save() {
        guard persist, !demo else { return }
        GameStorage.save(currentSave(), game: storageGameID, file: Self.saveFile)
    }

    private func saveAsync() {
        guard persist, !demo else { return }
        GameStorage.saveAsync(currentSave(), game: storageGameID, file: Self.saveFile)
    }

    func buildPinnedLook(for fairy: FairyKind) -> PinnedFairyLook {
        PinnedFairyLook(
            fairyID: fairy.rawValue,
            accessoryID: accessories[fairy]?.rawValue,
            wingDesign: wingDesigns[fairy] ?? FairyWingDesign(),
            wand: currentWand(for: fairy)
        )
    }

    private func writePinnedDefaultsDirectly() {
        if let pinned = pinnedFairy {
            PinnedFairyCodec.write(fairyID: pinned.rawValue, look: buildPinnedLook(for: pinned), to: userDefaults)
        } else {
            PinnedFairyCodec.write(fairyID: nil, look: nil, to: userDefaults)
        }
    }

    private func enqueuePinnedSyncIfNeeded(for fairy: FairyKind? = nil) {
        if let fairy, pinnedFairy != fairy {
            return
        }
        if let pinned = pinnedFairy {
            enqueue(.syncPinned(fairyID: pinned.rawValue, look: buildPinnedLook(for: pinned)))
        } else {
            enqueue(.syncPinned(fairyID: nil, look: nil))
        }
    }

    // MARK: - Initial Stage Spawning

    private func spawnInitialCompactActors(from save: FairiesSave) {
        compactActors.removeAll()
        var spawned: Set<FairyKind> = []

        for spot in CompactSpot.allCases {
            if let kind = save.spotOccupants[spot], !spawned.contains(kind) {
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
        for kind in save.roamingFairies where !spawned.contains(kind) {
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

    // MARK: - Station Switching

    func selectStation(_ newStation: FairyStation) {
        guard station != newStation else { return }
        cancelTransientGestures()
        station = newStation
        stationTransitionAt = time
        play(.flip, volume: 0.65)
        hapticTap()

        switch newStation {
        case .stage:
            emitBurst(.star, at: FGeo.compactCenter, count: 12, colorHex: 0xFFE38A)
        case .salon:
            emitBurst(.star, at: FGeo.salonWingCenter, count: 14, colorHex: selectedFairy.palette.emblem)
        case .teaTable:
            if teaSession.fairy != selectedFairy {
                startNextTeaOrder(for: selectedFairy, silent: true)
            }
            emitBurst(.heart, at: FGeo.teaCupCenter, count: 10, colorHex: 0xFF9AC8)
        }

        finishDirectInteraction()
    }

    func cancelTransientGestures() {
        cancelCompactDrag()
        salonStrokeActive = false
        salonGestureUndoPushed = false
        salonDragActivated = false
        pendingGlitterUndo = false
        glitterShakeAccumulator = 0
        fallingGlitter.removeAll()
        salonToolPos = nil
        salonFingerPos = nil
        draggingTeapot = nil
        draggingSugarStar = nil
        draggingTeaTreat = nil
        sceneDragActor = nil
        sceneDragStarted = false
        enqueueUIStateIfChanged()
    }

    // MARK: - Simulation Loop

    func step(_ now: Date) {
        let dt: CGFloat
        if let prev = lastTick {
            dt = CGFloat(min(1.0 / 20, max(1.0 / 240, now.timeIntervalSince(prev))))
        } else {
            dt = 1.0 / 60
        }
        lastTick = now
        inRenderStep = true
        defer { inRenderStep = false }
        step(dt: dt)
    }

    func resetClock() {
        lastTick = nil
    }

    func step(dt: CGFloat) {
        let prevRenderFlag = inRenderStep
        inRenderStep = true
        defer { inRenderStep = prevRenderFlag }

        let clamped = min(CGFloat(0.05), max(CGFloat(0.001), dt))
        time += Double(clamped)

        stepActiveTransforms(clamped)

        switch station {
        case .stage:
            stepCompactStage(clamped)
        case .salon:
            stepSalon(clamped)
        case .teaTable:
            stepTeaTable(clamped)
        }

        stepParticles(clamped)
        stepWandTrail(clamped)
        stepAmbient(clamped)
        enqueueUIStateIfChanged()
    }

    private func stepActiveTransforms(_ dt: CGFloat) {
        guard !activeTransforms.isEmpty else { return }
        var expired: [FairyKind] = []
        for (kind, existing) in activeTransforms {
            var active = existing
            active.remaining -= Double(dt)
            if active.remaining <= 0 {
                expired.append(kind)
            } else {
                activeTransforms[kind] = active
            }
        }
        for kind in expired {
            activeTransforms.removeValue(forKey: kind)
            rainbowTrails.removeValue(forKey: kind)
        }
    }

    // MARK: - Unified Scene Gestures (FingerLift Owned Inside Sim)

    private func lift(_ finger: CGPoint, by liftAmount: CGFloat) -> CGPoint {
        FingerLift.point(finger, lift: liftAmount, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }

    func handleSceneDragChanged(start: CGPoint, current: CGPoint) {
        switch station {
        case .stage:
            let moved = hypot(current.x - start.x, current.y - start.y)
            if !sceneDragStarted {
                if sceneDragActor == nil {
                    sceneDragActor = nearestCompactActor(to: start, maxRadius: 58)
                }
                guard moved >= 12, let actor = sceneDragActor else { return }
                sceneDragStarted = true
                beginCompactDrag(fairy: actor.kind, fromSpot: actor.currentSpot, at: lift(current, by: FingerLift.item), finger: current, fromRoom: true)
            } else {
                updateCompactDrag(to: lift(current, by: FingerLift.item), finger: current)
            }

        case .salon:
            handleSalonDragChanged(start: start, current: current)

        case .teaTable:
            handleTeaDragChanged(start: start, current: current)
        }
    }

    func handleSceneDragEnded(at current: CGPoint, isTap: Bool) {
        switch station {
        case .stage:
            if sceneDragStarted {
                endCompactDrag(at: lift(current, by: FingerLift.item), finger: current)
            } else {
                tapCompact(at: current)
            }
            sceneDragStarted = false
            sceneDragActor = nil

        case .salon:
            handleSalonDragEnded(at: current, isTap: isTap)

        case .teaTable:
            handleTeaDragEnded(at: current, isTap: isTap)
        }
    }

    func beginDockFairyDrag(_ fairy: FairyKind, finger: CGPoint) {
        beginCompactDrag(fairy: fairy, fromSpot: nil, at: lift(finger, by: FingerLift.item), finger: finger, fromRoom: false)
    }

    func updateDockFairyDrag(finger: CGPoint) {
        updateCompactDrag(to: lift(finger, by: FingerLift.item), finger: finger)
    }

    func endDockFairyDrag(finger: CGPoint) {
        endCompactDrag(at: lift(finger, by: FingerLift.item), finger: finger)
    }

    func beginDockSugarDrag(_ star: SugarStarKind, finger: CGPoint) {
        draggingSugarStar = star
        draggingSugarPos = lift(finger, by: FingerLift.pour)
        play(.pop, volume: 0.5)
        hapticTap()
        finishDirectInteraction()
    }

    func updateDockSugarDrag(finger: CGPoint) {
        guard draggingSugarStar != nil else { return }
        draggingSugarPos = lift(finger, by: FingerLift.pour)
    }

    func endDockSugarDrag(finger: CGPoint) {
        guard let star = draggingSugarStar else { return }
        let lifted = lift(finger, by: FingerLift.pour)
        draggingSugarStar = nil
        if lifted.y < 650 {
            _ = addSugarStar(star)
        }
        finishDirectInteraction()
    }

    func beginDockTreatDrag(_ treat: FairyTeaTreatKind, finger: CGPoint) {
        draggingTeaTreat = treat
        draggingTeaTreatPos = lift(finger, by: FingerLift.item)
        play(.pop, volume: 0.5)
        hapticTap()
        finishDirectInteraction()
    }

    func updateDockTreatDrag(finger: CGPoint) {
        guard draggingTeaTreat != nil else { return }
        draggingTeaTreatPos = lift(finger, by: FingerLift.item)
    }

    func endDockTreatDrag(finger: CGPoint) {
        guard let treat = draggingTeaTreat else { return }
        let lifted = lift(finger, by: FingerLift.item)
        draggingTeaTreat = nil
        if lifted.y < 650 {
            _ = plateTreat(treat)
        }
        finishDirectInteraction()
    }

    // MARK: - Station 2: Wing & Wand Salon

    func selectSalonTool(_ tool: FairySalonTool) {
        salonStrokeActive = false
        salonGestureUndoPushed = false
        salonDragActivated = false
        glitterShakeAccumulator = 0
        salonToolPos = nil
        salonFingerPos = nil
        salonTool = tool
        play(.pop, volume: 0.55)
        hapticTap()
        finishDirectInteraction()
    }

    private func pushWingUndoSnapshot(for fairy: FairyKind) {
        var stack = wingUndoStacks[fairy] ?? []
        stack.append(wingDesigns[fairy] ?? FairyWingDesign())
        if stack.count > Self.maxUndoDepth {
            stack.removeFirst(stack.count - Self.maxUndoDepth)
        }
        wingUndoStacks[fairy] = stack
    }

    @discardableResult
    func undoSalonAction() -> Bool {
        guard var stack = wingUndoStacks[selectedFairy], let previous = stack.popLast() else {
            return false
        }
        fallingGlitter.removeAll()
        glitterShakeAccumulator = 0
        pendingGlitterUndo = false
        wingUndoStacks[selectedFairy] = stack
        if previous.isEmpty {
            wingDesigns.removeValue(forKey: selectedFairy)
        } else {
            wingDesigns[selectedFairy] = previous
        }
        wingDesignVersion += 1
        play(.flip, volume: 0.6)
        hapticTap()
        emitBurst(.star, at: FGeo.salonWingCenter, count: 8, colorHex: 0xFFE38A)
        enqueuePinnedSyncIfNeeded(for: selectedFairy)
        enqueue(.save)
        finishDirectInteraction()
        return true
    }

    func clearCurrentWings() {
        let existing = wingDesigns[selectedFairy] ?? FairyWingDesign()
        if !existing.isEmpty {
            pushWingUndoSnapshot(for: selectedFairy)
            wingDesigns.removeValue(forKey: selectedFairy)
            wingDesignVersion += 1
            enqueuePinnedSyncIfNeeded(for: selectedFairy)
            enqueue(.save)
        }
        fallingGlitter.removeAll()
        glitterShakeAccumulator = 0
        pendingGlitterUndo = false
        play(.bubble, volume: 0.7)
        hapticTap()
        emitBurst(.bubble, at: FGeo.salonWingCenter, count: 14, colorHex: 0xBEE8FF)
        finishDirectInteraction()
    }

    func setWandTopper(_ topper: WandTopper) {
        var wand = currentWand()
        wand.topper = topper
        wands[selectedFairy] = wand
        celebrateWandEdit()
    }

    func setWandShaft(_ shaft: WandShaft) {
        var wand = currentWand()
        wand.shaft = shaft
        wands[selectedFairy] = wand
        celebrateWandEdit()
    }

    func setWandRibbon(_ ribbon: WandRibbon) {
        var wand = currentWand()
        wand.ribbon = ribbon
        wands[selectedFairy] = wand
        celebrateWandEdit()
    }

    private func celebrateWandEdit() {
        wandWaveEnergy = 1.0
        play(.sparkle, volume: 0.75)
        play(.ding, volume: 0.65)
        hapticTap()
        let wand = currentWand()
        emitBurst(.star, at: CGPoint(x: FGeo.salonWandCenter.x, y: FGeo.salonWandCenter.y - 110), count: 14, colorHex: wand.topper.gemHex)
        emitBurst(.heart, at: FGeo.salonWandCenter, count: 8, colorHex: wand.ribbon.colors.first ?? 0xFF8EC2)
        discover(.wandMagic, at: FGeo.salonWandCenter)
        if selectedFairy == .silk {
            discover(.silkFairy, at: FGeo.salonWandCenter)
        }
        enqueuePinnedSyncIfNeeded(for: selectedFairy)
        enqueue(.save)
        finishDirectInteraction()
    }

    func waveCustomWand(at point: CGPoint = FGeo.salonWandCenter) {
        wandWaveEnergy = 1.0
        wandAutoWaveTimer = 0.75
        wandAutoWaveOrigin = point
        play(.sparkle, volume: 0.8)
        play(.note4, volume: 0.7)
        hapticTap()
        let wand = currentWand()
        emitBurst(.star, at: point, count: 14, colorHex: 0xFFE38A)
        emitBurst(.heart, at: point, count: 10, colorHex: wand.topper.gemHex)
        discover(.wandMagic, at: point)
        if selectedFairy == .silk {
            discover(.silkFairy, at: point)
        }
        finishDirectInteraction()
    }

    @discardableResult
    func applyWingBrushPoint(at stagePoint: CGPoint, color: WingBrushColor, startNewStroke: Bool) -> Bool {
        guard let wp = FairyWingPainter.toCanonical(
            stagePoint: stagePoint,
            wingCenter: FGeo.salonWingCenter,
            wingHalfSpan: FGeo.salonWingHalfSpan
        ) else {
            return false
        }
        var design = wingDesigns[selectedFairy] ?? FairyWingDesign()
        if startNewStroke || design.strokes.isEmpty || design.strokes.last?.color != color {
            if !salonGestureUndoPushed {
                pushWingUndoSnapshot(for: selectedFairy)
                salonGestureUndoPushed = true
            }
            design.strokes.append(WingBrushStroke(color: color, width: 0.09, points: [wp]))
        } else if var last = design.strokes.last {
            if let prev = last.points.last {
                let du = wp.u - prev.u
                let dv = wp.v - prev.v
                guard hypot(du, dv) >= 0.025 else { return false }
            }
            last.points.append(wp)
            design.strokes[design.strokes.count - 1] = last
        }
        design.trimToBudget()
        wingDesigns[selectedFairy] = design
        emitMirroredSalonSparkle(at: wp, colorHex: color.baseHex)
        checkWingArtMilestones(at: stagePoint)
        finishDirectInteraction()
        return true
    }

    @discardableResult
    func placeWingStamp(_ kind: WingStampKind, at stagePoint: CGPoint) -> Bool {
        guard let wp = FairyWingPainter.toCanonical(
            stagePoint: stagePoint,
            wingCenter: FGeo.salonWingCenter,
            wingHalfSpan: FGeo.salonWingHalfSpan
        ) else {
            return false
        }
        pushWingUndoSnapshot(for: selectedFairy)
        var design = wingDesigns[selectedFairy] ?? FairyWingDesign()
        design.stamps.append(WingStamp(kind: kind, point: wp, scale: 1.0, tintHex: kind.accentHex))
        design.trimToBudget()
        wingDesigns[selectedFairy] = design
        wingDesignVersion += 1
        play(.ding, volume: 0.72)
        hapticTap()
        emitMirroredSalonSparkle(at: wp, colorHex: kind.accentHex, burstCount: 6)
        checkWingArtMilestones(at: stagePoint)
        enqueuePinnedSyncIfNeeded(for: selectedFairy)
        enqueue(.save)
        finishDirectInteraction()
        return true
    }

    func shakeGlitter(at shakerPoint: CGPoint, colorHex: UInt32, count: Int = 3) {
        let clampedCount = max(1, min(14, count))
        for i in 0..<clampedCount {
            let spreadX = CGFloat.random(in: -34...34)
            let startX = shakerPoint.x + spreadX
            let startY = shakerPoint.y + CGFloat.random(in: 8...22)
            let fallDist = CGFloat.random(in: 24...66)
            fallingGlitter.append(FallingGlitterGrain(
                id: allocID(),
                pos: CGPoint(x: startX, y: startY),
                vel: CGVector(dx: CGFloat.random(in: -22...22), dy: CGFloat.random(in: 140...205)),
                targetY: startY + fallDist,
                colorHex: colorHex,
                size: Float.random(in: 0.04...0.065),
                age: 0,
                maxAge: 0.85
            ))
            if i == 0 {
                play(.sparkle, volume: 0.45)
            }
        }
        if fallingGlitter.count > 72 {
            fallingGlitter.removeFirst(fallingGlitter.count - 72)
        }
    }

    @discardableResult
    func eraseWingArt(at stagePoint: CGPoint, radius: Float = 0.16) -> Bool {
        guard let wp = FairyWingPainter.toCanonical(
            stagePoint: stagePoint,
            wingCenter: FGeo.salonWingCenter,
            wingHalfSpan: FGeo.salonWingHalfSpan
        ) else {
            return false
        }
        guard var design = wingDesigns[selectedFairy], !design.isEmpty else { return false }
        let before = design

        design.glitter.removeAll { hypot($0.point.u - wp.u, $0.point.v - wp.v) <= radius }
        design.stamps.removeAll { hypot($0.point.u - wp.u, $0.point.v - wp.v) <= radius }

        var splitStrokes: [WingBrushStroke] = []
        for stroke in design.strokes {
            var segment: [WingPoint] = []
            for pt in stroke.points {
                if hypot(pt.u - wp.u, pt.v - wp.v) <= radius {
                    if !segment.isEmpty {
                        splitStrokes.append(WingBrushStroke(color: stroke.color, width: stroke.width, points: segment))
                        segment.removeAll(keepingCapacity: true)
                    }
                } else {
                    segment.append(pt)
                }
            }
            if !segment.isEmpty {
                splitStrokes.append(WingBrushStroke(color: stroke.color, width: stroke.width, points: segment))
            }
        }
        design.strokes = splitStrokes

        guard design != before else { return false }
        if !salonGestureUndoPushed {
            pushWingUndoSnapshot(for: selectedFairy)
            salonGestureUndoPushed = true
        }
        if design.isEmpty {
            wingDesigns.removeValue(forKey: selectedFairy)
        } else {
            wingDesigns[selectedFairy] = design
        }
        emitMirroredSalonSparkle(at: wp, colorHex: 0xBEE8FF)
        return true
    }

    func tapSalonQuickApply(near point: CGPoint? = nil) {
        switch salonTool {
        case .brush(let color):
            pushWingUndoSnapshot(for: selectedFairy)
            var design = wingDesigns[selectedFairy] ?? FairyWingDesign()
            let strokeVariant = design.strokes.count % 3
            let flourish: [WingPoint]
            switch strokeVariant {
            case 0:
                flourish = [
                    WingPoint(u: 0.22, v: -0.18),
                    WingPoint(u: 0.38, v: -0.44),
                    WingPoint(u: 0.58, v: -0.58),
                    WingPoint(u: 0.78, v: -0.52),
                    WingPoint(u: 0.84, v: -0.28),
                    WingPoint(u: 0.68, v: -0.14),
                ]
            case 1:
                flourish = [
                    WingPoint(u: 0.20, v: 0.26),
                    WingPoint(u: 0.38, v: 0.34),
                    WingPoint(u: 0.56, v: 0.48),
                    WingPoint(u: 0.52, v: 0.68),
                    WingPoint(u: 0.34, v: 0.72),
                ]
            default:
                flourish = [
                    WingPoint(u: 0.28, v: -0.06),
                    WingPoint(u: 0.48, v: -0.22),
                    WingPoint(u: 0.66, v: -0.34),
                    WingPoint(u: 0.76, v: -0.16),
                ]
            }
            design.strokes.append(WingBrushStroke(color: color, width: 0.095, points: flourish))
            design.trimToBudget()
            wingDesigns[selectedFairy] = design
            wingDesignVersion += 1
            play(.sparkle, volume: 0.72)
            hapticTap()
            if let mid = flourish.dropFirst(flourish.count / 2).first {
                emitMirroredSalonSparkle(at: mid, colorHex: color.baseHex, burstCount: 6)
            }
            checkWingArtMilestones(at: FGeo.salonWingCenter)
            enqueuePinnedSyncIfNeeded(for: selectedFairy)
            enqueue(.save)
            finishDirectInteraction()

        case .glitter(let hex):
            pendingGlitterUndo = true
            let targets: [WingPoint] = [
                WingPoint(u: 0.36, v: -0.34),
                WingPoint(u: 0.56, v: -0.52),
                WingPoint(u: 0.74, v: -0.38),
                WingPoint(u: 0.62, v: -0.16),
                WingPoint(u: 0.32, v: 0.36),
                WingPoint(u: 0.48, v: 0.54),
                WingPoint(u: 0.44, v: -0.14),
                WingPoint(u: 0.70, v: -0.56),
            ]
            for (idx, wp) in targets.enumerated() {
                let side: CGFloat = idx.isMultiple(of: 2) ? 1 : -1
                let land = FairyWingPainter.toStagePoint(wp, side: side, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
                fallingGlitter.append(FallingGlitterGrain(
                    id: allocID(),
                    pos: CGPoint(x: land.x, y: land.y - CGFloat.random(in: 36...58)),
                    vel: CGVector(dx: 0, dy: CGFloat.random(in: 160...210)),
                    targetY: land.y,
                    colorHex: hex,
                    size: Float.random(in: 0.044...0.066),
                    age: 0,
                    maxAge: 0.75
                ))
            }
            play(.sparkle, volume: 0.75)
            hapticTap()
            finishDirectInteraction()

        case .stamp(let kind):
            if let point, placeWingStamp(kind, at: point) {
                return
            }
            let presets: [WingPoint] = [
                WingPoint(u: 0.62, v: -0.44),
                WingPoint(u: 0.44, v: 0.48),
                WingPoint(u: 0.76, v: -0.24),
                WingPoint(u: 0.34, v: -0.26),
                WingPoint(u: 0.52, v: -0.60),
                WingPoint(u: 0.36, v: 0.66),
            ]
            let count = wingDesigns[selectedFairy]?.stamps.count ?? 0
            let chosen = presets[count % presets.count]
            let stagePt = FairyWingPainter.toStagePoint(chosen, side: 1, wingCenter: FGeo.salonWingCenter, wingHalfSpan: FGeo.salonWingHalfSpan)
            _ = placeWingStamp(kind, at: stagePt)

        case .wipe:
            let target = point ?? FairyWingPainter.toStagePoint(
                WingPoint(u: 0.55, v: -0.35),
                side: 1,
                wingCenter: FGeo.salonWingCenter,
                wingHalfSpan: FGeo.salonWingHalfSpan
            )
            if eraseWingArt(at: target, radius: 0.22) {
                salonGestureUndoPushed = false
                wingDesignVersion += 1
                play(.bubble, volume: 0.65)
                hapticTap()
                enqueuePinnedSyncIfNeeded(for: selectedFairy)
                enqueue(.save)
            } else {
                play(.tap, volume: 0.4)
                emitBurst(.bubble, at: target, count: 4, colorHex: 0xBEE8FF)
            }
            finishDirectInteraction()

        case .wandBuilder:
            waveCustomWand(at: point ?? FGeo.salonWandCenter)
        }
    }

    private func handleSalonDragChanged(start: CGPoint, current: CGPoint) {
        let moved = hypot(current.x - start.x, current.y - start.y)
        if !salonDragActivated {
            guard moved >= 12 else { return }
            salonDragActivated = true
        }
        salonFingerPos = current
        switch salonTool {
        case .brush(let color):
            let tip = lift(current, by: FingerLift.tool)
            salonToolPos = tip
            if FairyWingPainter.toCanonical(
                stagePoint: tip,
                wingCenter: FGeo.salonWingCenter,
                wingHalfSpan: FGeo.salonWingHalfSpan
            ) == nil {
                salonStrokeActive = false
                return
            }
            let started = !salonStrokeActive
            if applyWingBrushPoint(at: tip, color: color, startNewStroke: started) {
                if !salonStrokeActive {
                    salonStrokeActive = true
                    play(.sparkle, volume: 0.52)
                    hapticTap()
                }
            }

        case .glitter(let hex):
            let shaker = lift(current, by: FingerLift.pour)
            salonToolPos = shaker
            glitterShakeAccumulator += 1
            if glitterShakeAccumulator >= 3 {
                glitterShakeAccumulator = 0
                if !salonGestureUndoPushed {
                    pendingGlitterUndo = true
                    salonGestureUndoPushed = true
                }
                shakeGlitter(at: shaker, colorHex: hex, count: 2)
            }

        case .stamp:
            salonToolPos = lift(current, by: FingerLift.tool)

        case .wipe:
            let sponge = lift(current, by: FingerLift.grip)
            salonToolPos = sponge
            if eraseWingArt(at: sponge) {
                play(.bubble, volume: 0.45)
            }

        case .wandBuilder:
            let tip = lift(current, by: FingerLift.tool)
            salonToolPos = tip
            wandWaveEnergy = 1.0
            appendWandSparkle(at: tip)
            if !salonStrokeActive {
                salonStrokeActive = true
                play(.sparkle, volume: 0.65)
                hapticTap()
                discover(.wandMagic, at: tip)
            }
        }
    }

    private func handleSalonDragEnded(at current: CGPoint, isTap: Bool) {
        let wasDrag = salonDragActivated
        let hadStroke = salonStrokeActive
        let hadUndo = salonGestureUndoPushed
        let toolPos = salonToolPos
        salonDragActivated = false
        salonStrokeActive = false
        salonGestureUndoPushed = false
        salonToolPos = nil
        salonFingerPos = nil
        glitterShakeAccumulator = 0

        if isTap && !wasDrag {
            switch salonTool {
            case .stamp(let kind):
                if !placeWingStamp(kind, at: current) {
                    tapSalonQuickApply(near: current)
                }
            case .wandBuilder:
                waveCustomWand(at: current)
            default:
                tapSalonQuickApply(near: current)
            }
            return
        }

        switch salonTool {
        case .stamp(let kind):
            if let tip = toolPos {
                _ = placeWingStamp(kind, at: tip)
            }
        case .brush, .wipe:
            if hadStroke || hadUndo {
                wingDesignVersion += 1
                enqueuePinnedSyncIfNeeded(for: selectedFairy)
                enqueue(.save)
                finishDirectInteraction()
            }
        case .glitter:
            enqueuePinnedSyncIfNeeded(for: selectedFairy)
            enqueue(.save)
            finishDirectInteraction()
        case .wandBuilder:
            enqueuePinnedSyncIfNeeded(for: selectedFairy)
            finishDirectInteraction()
        }
    }

    private func stepSalon(_ dt: CGFloat) {
        wandWaveEnergy = max(0, wandWaveEnergy - dt * 1.45)

        if wandAutoWaveTimer > 0 {
            wandAutoWaveTimer = max(0, wandAutoWaveTimer - Double(dt))
            let angle = time * 12.0
            let tip = CGPoint(
                x: wandAutoWaveOrigin.x + CGFloat(cos(angle)) * 68,
                y: wandAutoWaveOrigin.y - 84 + CGFloat(sin(angle * 1.4)) * 34
            )
            appendWandSparkle(at: tip)
        }

        var stuckAnyGlitter = false
        for i in fallingGlitter.indices.reversed() {
            fallingGlitter[i].age += dt
            fallingGlitter[i].pos.x += fallingGlitter[i].vel.dx * dt
            fallingGlitter[i].pos.y += fallingGlitter[i].vel.dy * dt
            fallingGlitter[i].vel.dy += 120 * dt

            let grain = fallingGlitter[i]
            if grain.pos.y >= grain.targetY {
                if let wp = FairyWingPainter.toCanonical(
                    stagePoint: grain.pos,
                    wingCenter: FGeo.salonWingCenter,
                    wingHalfSpan: FGeo.salonWingHalfSpan
                ) {
                    if pendingGlitterUndo {
                        pushWingUndoSnapshot(for: selectedFairy)
                        pendingGlitterUndo = false
                    }
                    var design = wingDesigns[selectedFairy] ?? FairyWingDesign()
                    design.glitter.append(WingGlitterFleck(
                        point: wp,
                        colorHex: grain.colorHex,
                        size: grain.size,
                        twinklePhase: Float.random(in: 0...(2 * .pi))
                    ))
                    design.trimToBudget()
                    wingDesigns[selectedFairy] = design
                    stuckAnyGlitter = true
                    emitMirroredSalonSparkle(at: wp, colorHex: grain.colorHex)
                }
                fallingGlitter.remove(at: i)
            } else if grain.age >= grain.maxAge {
                fallingGlitter.remove(at: i)
            }
        }

        if fallingGlitter.isEmpty {
            pendingGlitterUndo = false
        }

        if stuckAnyGlitter {
            wingDesignVersion += 1
            checkWingArtMilestones(at: FGeo.salonWingCenter)
            enqueuePinnedSyncIfNeeded(for: selectedFairy)
            enqueue(.save)
        }
    }

    private func emitMirroredSalonSparkle(at wp: WingPoint, colorHex: UInt32, burstCount: Int = 2) {
        for side in [-1.0, 1.0] as [CGFloat] {
            let pt = FairyWingPainter.toStagePoint(
                wp,
                side: side,
                wingCenter: FGeo.salonWingCenter,
                wingHalfSpan: FGeo.salonWingHalfSpan
            )
            emitBurst(.star, at: pt, count: burstCount, colorHex: colorHex)
        }
    }

    private func checkWingArtMilestones(at point: CGPoint) {
        discover(.firstFairy, at: point)
        if selectedFairy == .silk {
            discover(.silkFairy, at: point)
        }
        let distinctColors = wingDesigns[selectedFairy]?.distinctBrushColors.count ?? 0
        let decoratedFairiesCount = wingDesigns.values.filter { !$0.isEmpty }.count
        if distinctColors >= 3 || decoratedFairiesCount >= 3 {
            discover(.rainbowCollection, at: point)
        }
        if let idx = compactActors.firstIndex(where: { $0.kind == selectedFairy && $0.wish == .wingSalon }) {
            _ = fulfillWish(for: compactActors[idx].kind)
        }
    }

    // MARK: - Station 3: Pixie Tea Table

    static func makeTeaWish(for fairy: FairyKind, step: Int) -> PixieTeaWish {
        let baseIdx = FairyKind.allCases.firstIndex(of: fairy) ?? 0
        let nectars = TeaNectar.allCases
        let stars = SugarStarKind.allCases
        let treats = FairyTeaTreatKind.allCases
        return PixieTeaWish(
            nectar: nectars[(baseIdx + step) % nectars.count],
            sugarStar: stars[(baseIdx * 2 + step) % stars.count],
            treat: treats[(baseIdx + step * 3) % treats.count]
        )
    }

    static func teaStars(draft: TeaCupDraft, wish: PixieTeaWish) -> Int {
        var matches = 0
        if draft.nectar == wish.nectar { matches += 1 }
        if draft.sugarStars.contains(wish.sugarStar) { matches += 1 }
        if draft.platedTreat == wish.treat { matches += 1 }
        if matches >= 3 { return 3 }
        if matches >= 1 { return 2 }
        return 1
    }

    func startNextTeaOrder(for fairy: FairyKind? = nil, silent: Bool = false) {
        let target = fairy ?? selectedFairy
        teaWishCounter += 1
        autoPourNectar = nil
        draggingTeapot = nil
        let wish = Self.makeTeaWish(for: target, step: teaWishCounter)
        teaSession = .awaitingPour(fairy: target, wish: wish, draft: TeaCupDraft())
        if !silent {
            play(.ding, volume: 0.55)
            hapticTap()
            emitBurst(.star, at: FGeo.teaWishBubbleCenter, count: 8, colorHex: 0xFFE38A)
        }
        finishDirectInteraction()
    }

    @discardableResult
    func pourTeapot(_ nectar: TeaNectar) -> Bool {
        switch teaSession {
        case .awaitingPour(let fairy, let wish, var draft),
             .pouring(let fairy, let wish, var draft, _),
             .ready(let fairy, let wish, var draft):
            draft.nectar = nectar
            draft.liquidHex = draft.sugarStars.last?.fizzHex ?? nectar.liquidHex
            if draft.fillLevel >= 0.98 {
                draft.fillLevel = 0.25
            }
            autoPourNectar = nectar
            teaSession = .pouring(fairy: fairy, wish: wish, draft: draft, activeNectar: nectar)
            play(.bubble, volume: 0.72)
            hapticTap()
            emitBurst(.bubble, at: CGPoint(x: FGeo.teaCupCenter.x, y: FGeo.teaCupCenter.y - 24), count: 6, colorHex: nectar.liquidHex)
            finishDirectInteraction()
            return true
        case .sipping, .transformed:
            return false
        }
    }

    @discardableResult
    func addSugarStar(_ star: SugarStarKind) -> Bool {
        switch teaSession {
        case .awaitingPour(let fairy, let wish, var draft):
            applySugarStar(star, to: &draft)
            teaSession = draft.isReadyToServe
                ? .ready(fairy: fairy, wish: wish, draft: draft)
                : .awaitingPour(fairy: fairy, wish: wish, draft: draft)
            finishDirectInteraction()
            return true

        case .pouring(let fairy, let wish, var draft, let activeNectar):
            applySugarStar(star, to: &draft)
            teaSession = .pouring(fairy: fairy, wish: wish, draft: draft, activeNectar: activeNectar)
            finishDirectInteraction()
            return true

        case .ready(let fairy, let wish, var draft):
            applySugarStar(star, to: &draft)
            teaSession = .ready(fairy: fairy, wish: wish, draft: draft)
            finishDirectInteraction()
            return true

        case .sipping, .transformed:
            return false
        }
    }

    private func applySugarStar(_ star: SugarStarKind, to draft: inout TeaCupDraft) {
        draft.sugarStars.append(star)
        if draft.sugarStars.count > 3 {
            draft.sugarStars.removeFirst(draft.sugarStars.count - 3)
        }
        draft.liquidHex = star.fizzHex
        draft.fizzTimer = 1.5
        play(.sparkle, volume: 0.78)
        play(.bubble, volume: 0.65)
        hapticTap()
        emitBurst(.star, at: CGPoint(x: FGeo.teaCupCenter.x, y: FGeo.teaCupCenter.y - 18), count: 10, colorHex: star.colorHex)
        emitBurst(.bubble, at: CGPoint(x: FGeo.teaCupCenter.x, y: FGeo.teaCupCenter.y - 10), count: 8, colorHex: star.fizzHex)
    }

    @discardableResult
    func plateTreat(_ treat: FairyTeaTreatKind) -> Bool {
        switch teaSession {
        case .awaitingPour(let fairy, let wish, var draft):
            draft.platedTreat = treat
            teaSession = draft.isReadyToServe
                ? .ready(fairy: fairy, wish: wish, draft: draft)
                : .awaitingPour(fairy: fairy, wish: wish, draft: draft)
            celebratePlateTreat(treat)
            return true

        case .pouring(let fairy, let wish, var draft, let activeNectar):
            draft.platedTreat = treat
            teaSession = .pouring(fairy: fairy, wish: wish, draft: draft, activeNectar: activeNectar)
            celebratePlateTreat(treat)
            return true

        case .ready(let fairy, let wish, var draft):
            draft.platedTreat = treat
            teaSession = .ready(fairy: fairy, wish: wish, draft: draft)
            celebratePlateTreat(treat)
            return true

        case .sipping, .transformed:
            return false
        }
    }

    private func celebratePlateTreat(_ treat: FairyTeaTreatKind) {
        play(.pop, volume: 0.72)
        play(.ding, volume: 0.55)
        hapticTap()
        emitBurst(.heart, at: CGPoint(x: FGeo.teaPlateCenter.x, y: FGeo.teaPlateCenter.y - 16), count: 8, colorHex: treat.accentHex)
        finishDirectInteraction()
    }

    @discardableResult
    func serveTea() -> Bool {
        switch teaSession {
        case .ready(let fairy, let wish, let draft):
            beginSipping(fairy: fairy, wish: wish, draft: draft)
            return true
        case .awaitingPour(let fairy, let wish, let draft) where draft.isReadyToServe:
            beginSipping(fairy: fairy, wish: wish, draft: draft)
            return true
        case .pouring(let fairy, let wish, var draft, _) where draft.isReadyToServe:
            autoPourNectar = nil
            draft.fillLevel = 1.0
            beginSipping(fairy: fairy, wish: wish, draft: draft)
            return true
        default:
            return false
        }
    }

    private func beginSipping(fairy: FairyKind, wish: PixieTeaWish, draft: TeaCupDraft) {
        autoPourNectar = nil
        draggingTeapot = nil
        teaSession = .sipping(fairy: fairy, wish: wish, draft: draft, progress: 0)
        play(.sparkle, volume: 0.8)
        play(.note4, volume: 0.72)
        hapticTap()
        emitBurst(.heart, at: FGeo.teaFairyCenter, count: 12, colorHex: fairy.palette.emblem)
        finishDirectInteraction()
    }

    private func handleTeaDragChanged(start: CGPoint, current: CGPoint) {
        if draggingTeapot == nil {
            for nectar in TeaNectar.allCases {
                let c = FGeo.teapotShelfCenter(for: nectar)
                if hypot(start.x - c.x, start.y - c.y) <= 58 {
                    draggingTeapot = nectar
                    autoPourNectar = nil
                    play(.pop, volume: 0.5)
                    hapticTap()
                    break
                }
            }
        }
        guard let nectar = draggingTeapot else { return }
        let lifted = lift(current, by: FingerLift.pour)
        draggingTeapotPos = lifted

        if hypot(lifted.x - FGeo.teaCupCenter.x, lifted.y - (FGeo.teaCupCenter.y - 54)) <= 136 {
            switch teaSession {
            case .awaitingPour(let fairy, let wish, var draft),
                 .pouring(let fairy, let wish, var draft, _),
                 .ready(let fairy, let wish, var draft):
                if draft.nectar == nectar && draft.fillLevel >= 1.0 {
                    break
                }
                if draft.nectar != nectar && draft.fillLevel >= 0.98 {
                    draft.fillLevel = 0.25
                }
                draft.nectar = nectar
                draft.liquidHex = draft.sugarStars.last?.fizzHex ?? nectar.liquidHex
                teaSession = .pouring(fairy: fairy, wish: wish, draft: draft, activeNectar: nectar)
            case .sipping, .transformed:
                break
            }
        }
    }

    private func handleTeaDragEnded(at current: CGPoint, isTap: Bool) {
        if let dragged = draggingTeapot {
            let lifted = lift(current, by: FingerLift.pour)
            draggingTeapot = nil
            if isTap {
                _ = pourTeapot(dragged)
                return
            }
            if hypot(lifted.x - FGeo.teaCupCenter.x, lifted.y - (FGeo.teaCupCenter.y - 36)) <= 165 {
                if let draft = teaSession.draft, draft.fillLevel < 0.92 {
                    _ = pourTeapot(dragged)
                    return
                }
            }
            settlePouringState()
            finishDirectInteraction()
            return
        }

        guard isTap else { return }

        for nectar in TeaNectar.allCases {
            let c = FGeo.teapotShelfCenter(for: nectar)
            if hypot(current.x - c.x, current.y - c.y) <= 58 {
                _ = pourTeapot(nectar)
                return
            }
        }

        if case .transformed(let fairy, _, _, _) = teaSession {
            startNextTeaOrder(for: fairy)
            return
        }

        if hypot(current.x - FGeo.teaCupCenter.x, current.y - FGeo.teaCupCenter.y) <= 102
            || hypot(current.x - FGeo.teaFairyCenter.x, current.y - FGeo.teaFairyCenter.y) <= 84 {
            if serveTea() {
                return
            }
            play(.pop, volume: 0.55)
            hapticTap()
            emitBurst(.heart, at: FGeo.teaFairyCenter, count: 6, colorHex: selectedFairy.palette.emblem)
            finishDirectInteraction()
        }
    }

    private func settlePouringState() {
        if case .pouring(let fairy, let wish, let draft, _) = teaSession {
            teaSession = draft.isReadyToServe
                ? .ready(fairy: fairy, wish: wish, draft: draft)
                : .awaitingPour(fairy: fairy, wish: wish, draft: draft)
        }
    }

    private func stepTeaTable(_ dt: CGFloat) {
        switch teaSession {
        case .awaitingPour(let fairy, let wish, var draft):
            draft.steamPhase += Double(dt) * 2.4
            if draft.fizzTimer > 0 {
                draft.fizzTimer = max(0, draft.fizzTimer - Double(dt))
            }
            teaSession = .awaitingPour(fairy: fairy, wish: wish, draft: draft)

        case .pouring(let fairy, let wish, var draft, let activeNectar):
            draft.steamPhase += Double(dt) * 3.0
            if draft.fizzTimer > 0 {
                draft.fizzTimer = max(0, draft.fizzTimer - Double(dt))
            }
            let isHoverPouring: Bool
            if let dragged = draggingTeapot, dragged == activeNectar {
                isHoverPouring = hypot(draggingTeapotPos.x - FGeo.teaCupCenter.x, draggingTeapotPos.y - (FGeo.teaCupCenter.y - 54)) <= 145
            } else {
                isHoverPouring = false
            }
            let isAutoPouring = autoPourNectar == activeNectar
            if isHoverPouring || isAutoPouring {
                let rate: CGFloat = isAutoPouring ? 1.45 : 1.15
                draft.fillLevel = min(1.0, draft.fillLevel + dt * rate)
                draft.nectar = activeNectar
                draft.liquidHex = draft.sugarStars.last?.fizzHex ?? activeNectar.liquidHex
                if draft.fillLevel >= 1.0 {
                    autoPourNectar = nil
                    play(.ding, volume: 0.6)
                    emitBurst(.star, at: CGPoint(x: FGeo.teaCupCenter.x, y: FGeo.teaCupCenter.y - 26), count: 8, colorHex: activeNectar.liquidHex)
                    teaSession = draft.isReadyToServe
                        ? .ready(fairy: fairy, wish: wish, draft: draft)
                        : .awaitingPour(fairy: fairy, wish: wish, draft: draft)
                } else {
                    teaSession = .pouring(fairy: fairy, wish: wish, draft: draft, activeNectar: activeNectar)
                }
            } else {
                teaSession = draft.isReadyToServe
                    ? .ready(fairy: fairy, wish: wish, draft: draft)
                    : .awaitingPour(fairy: fairy, wish: wish, draft: draft)
            }

        case .ready(let fairy, let wish, var draft):
            draft.steamPhase += Double(dt) * 2.8
            if draft.fizzTimer > 0 {
                draft.fizzTimer = max(0, draft.fizzTimer - Double(dt))
            }
            teaSession = .ready(fairy: fairy, wish: wish, draft: draft)

        case .sipping(let fairy, let wish, let draft, let progress):
            let nextProgress = min(1.0, progress + dt / 0.92)
            if nextProgress >= 1.0 {
                completeTeaServing(fairy: fairy, wish: wish, draft: draft)
            } else {
                teaSession = .sipping(fairy: fairy, wish: wish, draft: draft, progress: nextProgress)
            }

        case .transformed(let fairy, let wish, let transform, let remaining):
            let nextRemaining = remaining - Double(dt)
            if nextRemaining <= 0 {
                teaWishCounter += 1
                let nextWish = Self.makeTeaWish(for: fairy, step: teaWishCounter)
                teaSession = .awaitingPour(fairy: fairy, wish: nextWish, draft: TeaCupDraft())
            } else {
                teaSession = .transformed(fairy: fairy, wish: wish, transform: transform, remaining: nextRemaining)
            }
        }
    }

    private func completeTeaServing(fairy: FairyKind, wish: PixieTeaWish, draft: TeaCupDraft) {
        let stars = Self.teaStars(draft: draft, wish: wish)
        var totalReward = Coins.reward(stars: stars)
        let transform = draft.dominantTransform

        lastTeaStars = stars
        teasServed += 1
        activeTransforms[fairy] = ActiveTeaTransform(
            kind: transform,
            remaining: Self.teaTransformDuration,
            duration: Self.teaTransformDuration
        )
        teaSession = .transformed(fairy: fairy, wish: wish, transform: transform, remaining: 3.2)

        play(.fanfare, volume: 0.72)
        play(.cheer, volume: 0.5)
        hapticTap()

        emitBurst(.star, at: FGeo.teaFairyCenter, count: 16, colorHex: transform.accentHex)
        emitBurst(.heart, at: FGeo.teaFairyCenter, count: 12, colorHex: fairy.palette.emblem)
        emitBurst(.confetti, at: FGeo.teaCupCenter, count: 14, colorHex: 0xFFB8DC)

        if fairy == .silk {
            discover(.silkFairy, at: FGeo.teaFairyCenter)
        }
        if let idx = compactActors.firstIndex(where: { $0.kind == fairy && $0.wish == .pixieTea }) {
            let fulfilled = fulfillWish(for: compactActors[idx].kind, awardCoins: false)
            if fulfilled && time - lastWishCoinTime >= Self.wishCoinCooldown {
                lastWishCoinTime = time
                totalReward += Self.wishCoinReward
            }
        }
        earnCoins(totalReward, from: FGeo.teaCupCenter)
        enqueue(.save)
    }

    // MARK: - Station 1: Cozy Compact Stage Stepping

    private func stepCompactStage(_ dt: CGFloat) {
        swingPhase += Double(dt) * (2.6 + Double(swingEnergy) * 2.2)
        swingEnergy = max(0, swingEnergy - dt * 0.24)

        if carouselBoostTimer > 0 {
            carouselBoostTimer = max(0, carouselBoostTimer - Double(dt))
        }
        carouselSpinAngle += Double(dt) * (carouselBoostTimer > 0 ? 3.2 : 1.15)

        if teaPourTimer > 0 {
            teaPourTimer = max(0, teaPourTimer - Double(dt))
        }

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

        for i in compactBubbles.indices.reversed() {
            compactBubbles[i].age += dt
            if compactBubbles[i].age >= compactBubbles[i].maxAge || compactBubbles[i].pos.y < 195 {
                compactBubbles.remove(at: i)
                continue
            }
            compactBubbles[i].pos.x += compactBubbles[i].vel.dx * dt + CGFloat(sin(time * 2.8 + compactBubbles[i].phase)) * 18 * dt
            compactBubbles[i].pos.y += compactBubbles[i].vel.dy * dt
        }

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

            if activeTransforms[actor.kind]?.kind == .rainbowTrail {
                var trail = rainbowTrails[actor.kind] ?? []
                if trail.last.map({ hypot($0.x - actor.position.x, $0.y - actor.position.y) >= 8 }) ?? true {
                    trail.append(actor.position)
                    if trail.count > 18 {
                        trail.removeFirst(trail.count - 18)
                    }
                    rainbowTrails[actor.kind] = trail
                }
            }

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

            let dist = hypot(actor.target.x - actor.position.x, actor.target.y - actor.position.y)
            let speedBoost: CGFloat = activeTransforms[actor.kind]?.kind == .tinyShrink ? 1.32 : 1.0
            if dist > 6 {
                steerActor(&actor, toward: actor.target, maxSpeed: 76 * speedBoost, dt: dt)
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
        let chosenWish = preferredWish ?? pool.randomElement() ?? .wingSalon

        compactActors[idx].wish = chosenWish
        compactActors[idx].wishTimer = 24.0
        emitBurst(.star, at: CGPoint(x: compactActors[idx].position.x, y: compactActors[idx].position.y - 52), count: 5, colorHex: 0xFFE38A)
        return (compactActors[idx].kind, chosenWish)
    }

    @discardableResult
    func fulfillWish(for kind: FairyKind, awardCoins: Bool = true) -> Bool {
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

        if awardCoins && time - lastWishCoinTime >= Self.wishCoinCooldown {
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

    // MARK: - Compact Stage Management & Fairy Selection

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
            enqueue(.save)
            finishDirectInteraction()
            return true
        }

        if compactActors.count >= Self.maxCompactFairies {
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
        enqueue(.save)
        finishDirectInteraction()
        return true
    }

    func selectFairy(_ fairy: FairyKind, readyToPlace: Bool = false) {
        selectedFairy = fairy
        pendingPlacementFairy = (station == .stage && readyToPlace) ? fairy : nil
        play(.pop, volume: 0.55)
        hapticTap()

        if station == .teaTable {
            startNextTeaOrder(for: fairy, silent: true)
            emitBurst(.star, at: FGeo.teaFairyCenter, count: 8, colorHex: fairy.palette.emblem)
            finishDirectInteraction()
            return
        }

        if station == .salon {
            fallingGlitter.removeAll()
            glitterShakeAccumulator = 0
            pendingGlitterUndo = false
            emitBurst(.star, at: FGeo.salonWingCenter, count: 10, colorHex: fairy.palette.emblem)
            finishDirectInteraction()
            return
        }

        if readyToPlace && !isFairyInCompact(fairy) {
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
        finishDirectInteraction()
    }

    @discardableResult
    func placeFairy(_ fairy: FairyKind, at spot: CompactSpot) -> Bool {
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
        enqueue(.save)
        finishDirectInteraction()
        return true
    }

    func removeFairyFromCompact(_ fairy: FairyKind) {
        guard let idx = compactActors.firstIndex(where: { $0.kind == fairy }) else { return }
        compactActors.remove(at: idx)
        activeCompactFairies = compactActors.map(\.kind)
        syncSpotOccupantsFromActors()
        play(.whoosh, volume: 0.5)
        hapticTap()
        enqueue(.save)
        finishDirectInteraction()
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
        enqueuePinnedSyncIfNeeded(for: target)
        enqueue(.save)
        finishDirectInteraction()
    }

    @discardableResult
    func togglePin(_ fairy: FairyKind? = nil) -> FairyKind? {
        let target = fairy ?? selectedFairy
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
        enqueuePinnedSyncIfNeeded()
        enqueue(.save)
        finishDirectInteraction()
        return pinnedFairy
    }

    // MARK: - Interactive Compact Toys & Owned Treasures

    func triggerTeacupBubbles() {
        compactSpotReactUntil[.teacupBath] = time + 1.3
        play(.bubble, volume: 0.85)
        hapticTap()

        let base = CompactSpot.teacupBath.center
        let tints: [UInt32] = [0x9FE3FF, 0xFFB8DC, 0xC9B6FF, 0x9FE3CF, 0xFFE38A]
        for i in 0..<5 {
            compactBubbles.append(CompactBubble(
                id: allocID(),
                pos: CGPoint(x: base.x + CGFloat(i - 2) * 20 + CGFloat.random(in: -8...8), y: base.y - 24 - CGFloat(i) * 8),
                vel: CGVector(dx: CGFloat.random(in: -16...24), dy: CGFloat.random(in: -54...(-36))),
                radius: CGFloat.random(in: 22...31),
                age: 0,
                maxAge: 6.5,
                tintHex: tints[i % tints.count],
                phase: Double(i) * 1.1
            ))
        }
        if compactBubbles.count > 14 {
            compactBubbles.removeFirst(compactBubbles.count - 14)
        }

        if let wishKind = compactActors.first(where: { $0.wish == .bubbles })?.kind {
            _ = placeFairy(wishKind, at: .teacupBath)
        }
        emitBurst(.bubble, at: CGPoint(x: base.x, y: base.y - 16), count: 8, colorHex: 0xA8E4FF)
        finishDirectInteraction()
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
        finishDirectInteraction()
        return true
    }

    func pumpRainbowSwing() {
        compactSpotReactUntil[.rainbowSwing] = time + 1.5
        swingEnergy = min(1.0, swingEnergy + 0.58)
        play(.boing, volume: 0.72)
        play(.sparkle, volume: 0.5)
        hapticTap()

        let base = CompactSpot.rainbowSwing.center

        if let wishKind = compactActors.first(where: { $0.wish == .swing })?.kind {
            _ = placeFairy(wishKind, at: .rainbowSwing)
        } else if !compactActors.contains(where: { $0.currentSpot == .rainbowSwing }),
                  let riderKind = compactActors.first(where: { $0.kind == selectedFairy })?.kind ?? compactActors.first?.kind {
            _ = placeFairy(riderKind, at: .rainbowSwing)
        }

        emitBurst(.star, at: base, count: 10, colorHex: 0xFFE38A)
        emitBurst(.heart, at: base, count: 6, colorHex: 0xFF8FB8)
        finishDirectInteraction()
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
        discover(.musicChime, at: center)
        if compactActors.count >= 3 {
            discover(.compactParty, at: center)
        }
        fulfillMatchingWishes(for: .dance)
        finishDirectInteraction()
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
        finishDirectInteraction()
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
        finishDirectInteraction()
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
        finishDirectInteraction()
        return true
    }

    // MARK: - Stage Hit-Testing & Dragging

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
        for b in compactBubbles.reversed() {
            if hypot(point.x - b.pos.x, point.y - b.pos.y) <= b.radius + 18 {
                _ = popCompactBubble(id: b.id)
                return
            }
        }

        for actor in compactActors {
            guard let wish = actor.wish, let targetStation = wish.matchingStation else { continue }
            let bubbleCenter = CGPoint(
                x: max(195, min(829, actor.position.x + 34)),
                y: max(172, actor.position.y - 78)
            )
            if hypot(point.x - bubbleCenter.x, point.y - bubbleCenter.y) <= 38 {
                selectedFairy = actor.kind
                selectStation(targetStation)
                return
            }
        }

        if hypot(point.x - FGeo.chandelierCenter.x, point.y - FGeo.chandelierCenter.y) <= 68 {
            toggleNightMode()
            return
        }

        if hasCarousel && hypot(point.x - FGeo.carouselCenter.x, point.y - FGeo.carouselCenter.y + 24) <= 60 {
            _ = spinCompactCarousel()
            return
        }

        if let pending = pendingPlacementFairy, let spot = nearestCompactSpot(to: point, maxRadius: 98) {
            _ = placeFairy(pending, at: spot)
            return
        }

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
                finishDirectInteraction()
            }
            return
        }

        if let tappedActor = nearestCompactActor(to: point, maxRadius: 56),
           let idx = compactActors.firstIndex(where: { $0.kind == tappedActor.kind }) {
            selectedFairy = tappedActor.kind
            compactActors[idx].mood = .giggle
            compactActors[idx].reactionUntil = time + 1.3
            play(.pop, volume: 0.6)
            hapticTap()
            emitBurst(.heart, at: tappedActor.position, count: 8, colorHex: tappedActor.kind.palette.emblem)
            finishDirectInteraction()
            return
        }

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
        finishDirectInteraction()
    }

    private func isReturnDropTarget(liftedPoint: CGPoint, finger: CGPoint?) -> Bool {
        if let finger,
           hypot(finger.x - FGeo.returnBadgeCenter.x, finger.y - FGeo.returnBadgeCenter.y) < 58 {
            return true
        }
        return liftedPoint.y >= FGeo.returnDropY - 36
    }

    func beginCompactDrag(
        fairy: FairyKind,
        fromSpot: CompactSpot?,
        at liftedPoint: CGPoint,
        finger: CGPoint? = nil,
        fromRoom: Bool? = nil
    ) {
        let startedInRoom = fromRoom ?? (fromSpot != nil || isFairyInCompact(fairy))
        draggingCompactFairy = fairy
        compactDragOriginSpot = fromSpot
        compactDragStartedInRoom = startedInRoom
        compactDragPos = liftedPoint
        compactReturnHovered = startedInRoom && isReturnDropTarget(liftedPoint: liftedPoint, finger: finger)
        compactHoverSpot = compactReturnHovered ? nil : nearestCompactSpot(to: liftedPoint, maxRadius: 108)
        selectedFairy = fairy
        pendingPlacementFairy = nil
        play(.pop, volume: 0.5)
        hapticTap()
        finishDirectInteraction()
    }

    func updateCompactDrag(to liftedPoint: CGPoint, finger: CGPoint? = nil) {
        guard draggingCompactFairy != nil else { return }
        compactDragPos = liftedPoint
        let nextHoverReturn = compactDragStartedInRoom && isReturnDropTarget(liftedPoint: liftedPoint, finger: finger)
        let returnChanged = nextHoverReturn != compactReturnHovered
        compactReturnHovered = nextHoverReturn
        compactHoverSpot = compactReturnHovered ? nil : nearestCompactSpot(to: liftedPoint, maxRadius: 108)
        if returnChanged {
            finishDirectInteraction()
        }
    }

    func endCompactDrag(at liftedPoint: CGPoint, finger: CGPoint? = nil) {
        guard let fairy = draggingCompactFairy else { return }
        let startedInRoom = compactDragStartedInRoom
        draggingCompactFairy = nil
        compactDragOriginSpot = nil
        compactDragStartedInRoom = false
        compactHoverSpot = nil
        let returning = startedInRoom && isReturnDropTarget(liftedPoint: liftedPoint, finger: finger)
        compactReturnHovered = false

        if returning {
            removeFairyFromCompact(fairy)
            return
        }

        if hasCarousel && hypot(liftedPoint.x - FGeo.carouselCenter.x, liftedPoint.y - FGeo.carouselCenter.y + 20) <= 68 {
            _ = inviteFairyToCompact(fairy, at: FGeo.carouselCenter)
            if let idx = compactActors.firstIndex(where: { $0.kind == fairy }) {
                let takenSeats = Set(compactActors.filter { $0.ridingCarousel && $0.kind != fairy }.map(\.carouselSeatIndex))
                let chosenSeat: Int
                if let openSeat = (0..<4).first(where: { !takenSeats.contains($0) }) {
                    chosenSeat = openSeat
                } else {
                    chosenSeat = 0
                    if let evictIdx = compactActors.firstIndex(where: { $0.ridingCarousel && $0.kind != fairy && $0.carouselSeatIndex == 0 }) {
                        compactActors[evictIdx].ridingCarousel = false
                        compactActors[evictIdx].target = pickRoamingDestination(excluding: compactActors[evictIdx].kind)
                    }
                }
                compactActors[idx].ridingCarousel = true
                compactActors[idx].currentSpot = nil
                compactActors[idx].carouselSeatIndex = chosenSeat
                compactActors[idx].idleTimer = 6.0
                syncSpotOccupantsFromActors()
                if compactActors[idx].wish == .carousel {
                    _ = fulfillWish(for: fairy)
                }
            }
            carouselBoostTimer = max(carouselBoostTimer, 3.0)
            play(.note3, volume: 0.7)
            finishDirectInteraction()
            return
        }

        if let target = nearestCompactSpot(to: liftedPoint, maxRadius: 112) {
            _ = placeFairy(fairy, at: target)
            return
        }

        if liftedPoint.y < FGeo.returnDropY - 24 {
            _ = inviteFairyToCompact(fairy, at: liftedPoint)
            play(.pop, volume: 0.5)
        }
        finishDirectInteraction()
    }

    func cancelCompactDrag() {
        draggingCompactFairy = nil
        compactDragOriginSpot = nil
        compactDragStartedInRoom = false
        compactHoverSpot = nil
        compactReturnHovered = false
    }

    // MARK: - Shared Particles, Trails & Outbox Helpers

    private func stepWandTrail(_ dt: CGFloat) {
        for i in wandTrail.indices.reversed() {
            wandTrail[i].age += dt
            if wandTrail[i].age >= wandTrail[i].maxAge {
                wandTrail.remove(at: i)
            }
        }
    }

    private func appendWandSparkle(at pos: CGPoint) {
        let colors = currentWand().ribbon.colors
        let hex = colors[wandTrail.count % max(1, colors.count)]
        wandTrail.append(WandSparkle(
            pos: CGPoint(x: pos.x + CGFloat.random(in: -8...8), y: pos.y + CGFloat.random(in: -8...8)),
            age: 0,
            maxAge: 0.58,
            size: CGFloat.random(in: 8...15),
            colorHex: hex
        ))
        if wandTrail.count > 44 {
            wandTrail.removeFirst(wandTrail.count - 44)
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

        switch station {
        case .stage:
            for actor in compactActors {
                if let transform = activeTransforms[actor.kind] {
                    switch transform.kind {
                    case .glow:
                        spawnParticle(.star, at: CGPoint(x: actor.position.x + CGFloat.random(in: -22...22), y: actor.position.y + CGFloat.random(in: -26...14)), vel: CGVector(dx: CGFloat.random(in: -8...8), dy: -26), maxAge: 1.0, size: 11, colorHex: 0xFFE38A)
                    case .floatingBubbles:
                        spawnParticle(.bubble, at: CGPoint(x: actor.position.x + CGFloat.random(in: -18...18), y: actor.position.y - 10), vel: CGVector(dx: CGFloat.random(in: -10...10), dy: -36), maxAge: 1.4, size: CGFloat.random(in: 9...15), colorHex: 0x9CDFFF)
                    case .tinyShrink, .rainbowTrail:
                        break
                    }
                }
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
                spawnParticle(.star, at: CGPoint(x: FGeo.chandelierCenter.x + CGFloat.random(in: -44...44), y: FGeo.chandelierCenter.y + CGFloat.random(in: 6...34)), vel: CGVector(dx: CGFloat.random(in: -8...8), dy: 14), maxAge: 1.1, size: CGFloat.random(in: 7...11), colorHex: 0xFFE38A)
            }
            if hasCarousel && Int(time * 3) % 4 == 1 {
                spawnParticle(.star, at: CGPoint(x: FGeo.carouselCenter.x + CGFloat.random(in: -24...24), y: FGeo.carouselCenter.y - 46 + CGFloat.random(in: -10...10)), vel: CGVector(dx: CGFloat.random(in: -10...10), dy: -20), maxAge: 1.0, size: CGFloat.random(in: 7...10), colorHex: 0xFFB8E0)
            }

        case .salon:
            if Int(time * 3) % 2 == 0 {
                let x = FGeo.salonWingCenter.x + CGFloat.random(in: -220...220)
                let y = FGeo.salonWingCenter.y + CGFloat.random(in: -160...150)
                spawnParticle(.star, at: CGPoint(x: x, y: y), vel: CGVector(dx: 0, dy: -16), maxAge: 1.1, size: CGFloat.random(in: 6...10), colorHex: 0xFFE8A8)
            }

        case .teaTable:
            if let draft = teaSession.draft, draft.fizzTimer > 0 {
                spawnParticle(.bubble, at: CGPoint(x: FGeo.teaCupCenter.x + CGFloat.random(in: -26...26), y: FGeo.teaCupCenter.y - 24), vel: CGVector(dx: CGFloat.random(in: -12...12), dy: -46), maxAge: 1.0, size: CGFloat.random(in: 8...14), colorHex: draft.liquidHex)
            }
            if case .transformed(_, _, let transform, _) = teaSession {
                let kind: FairyParticleKind = transform == .floatingBubbles ? .bubble : .star
                spawnParticle(kind, at: CGPoint(x: FGeo.teaFairyCenter.x + CGFloat.random(in: -36...36), y: FGeo.teaFairyCenter.y + CGFloat.random(in: -30...16)), vel: CGVector(dx: CGFloat.random(in: -14...14), dy: -38), maxAge: 1.1, size: 12, colorHex: transform.accentHex)
            }
        }
    }

    func discover(_ find: FairiesFind, at point: CGPoint) {
        let isFirst = unlockedFinds.insert(find).inserted
        if isFirst {
            emitBurst(.star, at: point, count: 14, colorHex: 0xFFE38A)
            enqueue(.sticker(find))
        }
    }

    private func earnCoins(_ amount: Int, from point: CGPoint) {
        guard amount > 0 else { return }
        enqueue(.coins(amount, point))
    }

    private func play(_ sfx: SFX, volume: Float = 0.8) {
        enqueue(.sound(sfx, volume))
    }

    private func hapticTap() {
        enqueue(.haptic)
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
