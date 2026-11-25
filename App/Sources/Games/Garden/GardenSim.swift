import Foundation
import SwiftUI

enum GardenTool: Equatable {
    case shovel
    case can
    case seeds(PlantKind)
    case decor(DecorKind)
}

enum GardenDockHint: String, Equatable {
    case shovel
    case can
    case seeds
    case decor
}

enum GardenEffect: Equatable {
    case earnCoins(amount: Int, from: CGPoint)
    case discoverSticker(GardenFind, at: CGPoint)
    case haptic
    case save
}

struct GardenUIState: Equatable {
    var station: GardenStation
    var weather: Weather
    var season: GardenSeason
    var discoveredHybrids: [HybridKind]
    var hasRecentHybridDiscovery: Bool
    var suggestedHint: GardenDockHint?
    var showReturnBadge: Bool
    var overReturnBadge: Bool
    var inventory: [HarvestItem]
    var draggedStockItem: HarvestItem?
    var activeOrder: FarmstandOrder?
    var orderReadyInInventory: Bool
    var farmstandServedCount: Int
    var treehouseStage: Int
    var draftMatchedSlots: [Bool]
    var draftItemCount: Int
    var draftCanServe: Bool
    var draftWrap: WrapPaperStyle
    var draftRibbon: BouquetRibbonColor
    var draftLid: JamLidColor
    var draftDewSpritzed: Bool
    var isCelebrating: Bool
    var celebrationStars: Int
    var isPollinatingTapMode: Bool
}

enum GPart {
    case water, splash, clod, seed, rain, petal, leaf, sparkle, dust, ripple, heart, confetti, snow, pollen
}

struct GParticle {
    var kind: GPart
    var p: CGPoint
    var v: CGVector
    var age: CGFloat = 0
    var life: CGFloat
    var size: CGFloat
    var color: GRGB
    var rot: CGFloat = 0
    var spin: CGFloat = 0
    var mass: CGFloat = 0
    var seed: PlantKind?
    var bounces = 0
    var groundY: CGFloat = 0
    var resting = false
}

enum GFlyerKind {
    case crop(HarvestItem)
    case flowerToVase(HarvestItem)
    case flyingSeed(PlantKind, Int)
    case picnicSnack(HarvestItem)
    case caughtFirefly
    case weed(Int)
    case uprooted(Plant)
}

struct GFlyer {
    var kind: GFlyerKind
    var p0: CGPoint
    var v0: CGVector
    var start: Double
    var dur: Double
    var spin: CGFloat
    var toBasket: Bool
    var toVase: Bool = false
    var toPicnic: Bool = false
    var toJar: Bool = false

    static let gravity: CGFloat = 1500

    func pos(_ t: Double) -> CGPoint {
        let s = CGFloat(t - start)
        return CGPoint(x: p0.x + v0.dx * s, y: p0.y + v0.dy * s + 0.5 * GFlyer.gravity * s * s)
    }

    static func aim(from: CGPoint, to: CGPoint, dur: Double) -> CGVector {
        let T = CGFloat(dur)
        return CGVector(dx: (to.x - from.x) / T, dy: (to.y - from.y - 0.5 * gravity * T * T) / T)
    }
}

struct SurprisePop {
    var surprise: BuriedSurprise
    var origin: CGPoint
    var start: Double
    var dur: Double = 1.3
}

struct PicnicSnack: Equatable {
    var item: HarvestItem
    var pos: CGPoint
    var placedAt: Double
}

struct PicnicCritter: Equatable {
    enum State: Equatable { case hoppingIn, munching, happy, hoppingOut }
    var id: Int
    var kind: GVisitorKind
    var p: CGPoint
    var target: CGPoint
    var state: State = .hoppingIn
    var stateAt: Double = 0
    var facing: CGFloat = -1
    var walk: CGFloat = 0
    var snackItem: HarvestItem
    var wearingCrown: Bool = false
    var crownColors: [GRGB] = []
    var poked: Double = -10
    var nextHeartAt: Double = 0
}

struct GPlot {
    var stage: PlotStage = .empty(surprise: .coins, surpriseReady: true)
    var surpriseResetAt: Double = 0
    var moundPop: CGFloat = 0
    var moundPopV: CGFloat = 0
    var bend: CGFloat = 0
    var bendV: CGFloat = 0
    var pop: CGFloat = 0
    var popV: CGFloat = 0
    var dry: CGFloat = 0
    var digWork: CGFloat = 0
    var fillUntil: Double = 0
    var pull: CGFloat = 0
    var pullV: CGFloat = 0
    var held = false
    var sad = false

    var isEmpty: Bool {
        if case .empty = stage { return true }
        return false
    }

    var surpriseReady: Bool {
        get {
            if case .empty(_, let ready) = stage { return ready }
            return false
        }
        set {
            if case .empty(let surprise, _) = stage {
                stage = .empty(surprise: surprise, surpriseReady: newValue)
            }
        }
    }

    var surprise: BuriedSurprise? {
        if case .empty(let s, _) = stage { return s }
        return nil
    }

    var plant: Plant? {
        get {
            switch stage {
            case .empty:
                return nil
            case .growing(let g):
                return Plant(kind: g.kind, growth: g.growth, left: 0, variant: g.variant, giant: false, hybrid: g.hybrid, rainbowCharged: false)
            case .ripe(let r):
                return Plant(kind: r.kind, growth: 1.0, left: r.yieldLeft, variant: r.variant, giant: r.isGiant, hybrid: r.hybrid, rainbowCharged: r.rainbowCharged)
            }
        }
        set {
            if let p = newValue {
                stage = GardenSave.stage(from: p, defaultSurprise: BuriedSurprise.random())
            } else {
                if case .empty = stage { return }
                stage = .empty(surprise: BuriedSurprise.random(), surpriseReady: true)
            }
        }
    }
}

struct GWeed {
    var x: CGFloat
    var growth: CGFloat
    var seed: Int
    var bend: CGFloat = 0
    var bendV: CGFloat = 0
    var pull: CGFloat = 0
    var pullV: CGFloat = 0
    var held = false
}

struct GDecor {
    var id: Int
    var kind: DecorKind
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat = 0
    var baseY: CGFloat = GGeo.yardY
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var spin: CGFloat = 0
    var spinV: CGFloat = 0
    var water: CGFloat = 0
    var held = false
    var poke: Double = -10
    var lit = true
}

struct GButterfly {
    var p: CGPoint
    var v: CGVector
    var target: CGPoint
    var perch: Int?
    var perchUntil: Double = 0
    var nextThink: Double = 0
    var phase: CGFloat
    var look: Int
    var leaving = false
}

struct GBee {
    var p: CGPoint
    var v: CGVector
    var target: CGPoint
    var perch: Int?
    var perchUntil: Double = 0
    var nextThink: Double = 0
    var phase: CGFloat = 0
    var leaving = false
    var flourishUntil: Double = -10
}

struct GLadybug {
    var x: CGFloat
    var dir: CGFloat
    var flying = false
    var p: CGPoint
    var v = CGVector.zero
    var open: CGFloat = 0
    var nextTurn: Double = 4
    var walk: CGFloat = 0
}

struct GWorm {
    var x: CGFloat
    var depth: CGFloat
    var dir: CGFloat
    var phase: CGFloat = 0
    var peek: CGFloat = 0
    var peekUntil: Double = 0
    var nextPeek: Double = 12
    var wiggle: Double = -10
}

struct GFirefly {
    var p: CGPoint
    var v: CGVector
    var phase: CGFloat
}

final class GardenSim {
    static let gameID = "garden"
    static let gravity: CGFloat = 1700
    static let maxBouquet = 6
    static let maxInventory = 60
    static let maxTreehouseStage = 5
    static let maxPicnicSnacks = 3
    static let maxCaughtFireflies = 10

    var station: GardenStation = .bed

    var h: [CGFloat]
    var wet: [CGFloat]

    var plots: [GPlot]
    var weeds: [GWeed] = []
    var decor: [GDecor] = []
    var particles: [GParticle] = []
    var farmstandParticles: [GParticle] = []
    var flyers: [GFlyer] = []
    var surprisePops: [SurprisePop] = []
    var butterflies: [GButterfly] = []
    var bee: GBee?
    var ladybug: GLadybug
    var worm: GWorm
    var fireflies: [GFirefly] = []
    var visitors: [GVisitor] = []
    var nextVisit: Double = 7

    var inventory: [HarvestItem] = []
    var basketBounce: CGFloat = 0
    var basketBounceV: CGFloat = 0
    var vaseBounce: CGFloat = 0
    var vaseBounceV: CGFloat = 0

    var vaseFlowers: [HarvestItem] {
        Array(inventory.filter(\.isFlower).suffix(GardenSim.maxBouquet))
    }

    var bouquet: [BouquetFlower] {
        vaseFlowers.map { item in
            switch item.source {
            case .plant(let kind, let variant, _):
                return BouquetFlower(kind: kind, variant: variant)
            case .hybrid(let hybrid, _):
                return BouquetFlower(kind: hybrid.parents.0, variant: 0, hybrid: hybrid)
            }
        }
    }

    var discoveredHybrids: [HybridKind] = []
    var lastDiscoveredHybrid: HybridKind?
    var hybridDiscoveryAt: Double = -100
    private var chimeIndex = 0
    var hasRecentHybridDiscovery: Bool { time - hybridDiscoveryAt < 5.0 }

    var pollination: PollinationState = .idle

    var farmstandServedCount: Int = 0
    var farmstandPhase: FarmstandPhase
    private var orderSeed: Int = 1
    var farmstandCraftBounce: CGFloat = 0
    var farmstandCraftBounceV: CGFloat = 0
    var farmstandBellBounce: CGFloat = 0
    var farmstandBellBounceV: CGFloat = 0
    var farmstandSpritzHeld = false
    var farmstandSpritzPos = GGeo.Farmstand.spritzHome
    var farmstandSpritzTilt: CGFloat = 0
    private var spritzEmitAcc: CGFloat = 0
    var farmstandPlungerHeld = false
    private var plungerGrabStartY: CGFloat = 0
    private var plungerStartProgress: CGFloat = 0
    private var lastJamPressMilestone: Int = 0
    var draggedStockItem: HarvestItem?
    private var draggedStockOriginalIndex: Int?
    var draggedStockPos = CGPoint.zero
    private var nextCelebrationHeartAt: Double = 0

    var activeOrder: FarmstandOrder? {
        if case .crafting(let order, _) = farmstandPhase { return order }
        return nil
    }

    var activeDraft: FarmstandDraft? {
        if case .crafting(_, let draft) = farmstandPhase { return draft }
        return nil
    }

    var picnicSnacks: [PicnicSnack] = []
    var picnicCritters: [PicnicCritter] = []
    var picnicFeedCount: Int = 0
    var treehouseStage: Int = 0
    var picnicBounce: CGFloat = 0
    var picnicBounceV: CGFloat = 0
    var treehousePoke: Double = -10
    var treehouseUpgradeAt: Double = -100
    var treehouseBounce: CGFloat = 0
    var treehouseBounceV: CGFloat = 0
    private var nextPicnicCritterID = 1
    private var picnicSpeciesCursor = 0

    var season: GardenSeason = .spring
    var weather: Weather = .sun
    var rain: CGFloat = 0
    var wind: CGFloat = 0.08
    var night: CGFloat = 0
    var cloud: CGFloat = 0.12
    var rainbowAt: Double = -100
    var windNow: CGFloat = 0
    var cloudDrift: CGFloat = 0
    var vortexCenter: CGPoint?
    var vortexUntil: Double = -10
    var caughtFireflies: Int = 0
    var jarBounce: CGFloat = 0
    var jarBounceV: CGFloat = 0

    var craftedCrownColors: [GRGB] = []
    var hasCraftedCrown: Bool { !craftedCrownColors.isEmpty }
    var crownBounce: CGFloat = 0
    var crownBounceV: CGFloat = 0

    var time: Double = 0
    private var last: Date?
    private var lastSave: Double = 0
    private var nextWeed: Double = 18
    private var nextLeaf: Double = 0
    private var nextSeasonFlake: Double = 0
    private var nextBeeSpawn: Double = 1.6
    private var rainAcc: CGFloat = 0
    private var waterAcc: CGFloat = 0
    private var nextDecorID = 1

    var tool: GardenTool?
    var toolP = CGPoint.zero
    var hold = CGPoint.zero
    var finger = CGPoint.zero
    var toolV = CGVector.zero
    var tilt: CGFloat = 0
    var tiltV: CGFloat = 0
    var load: CGFloat = 0
    var flow: CGFloat = 0
    var autoShovelActive = false
    private var lastToolP = CGPoint.zero
    private var seedTimer: CGFloat = 0
    private var digSound: Double = 0
    private var weedClearGraceUntil: Double = -10
    var returning: (tool: GardenTool, from: CGPoint, to: CGPoint, start: Double, tilt: CGFloat)?

    private enum Grab {
        case weed(Int)
        case carrot(Int)
        case decor(Int)
        case basketFeed
        case pollen(fromPlot: Int, kind: PlantKind)
        case flowerCrown
    }
    private var pickedThisStroke = Set<Int>()
    private var grab: Grab?
    private var grabStart = CGPoint.zero
    private var handP = CGPoint.zero
    private var handLast = CGPoint.zero
    var handV = CGVector.zero
    var handDown = false
    private var sceneDragActive = false

    var isDraggingDecor: Bool {
        if case .decor? = grab { return true }
        if case .decor? = tool { return true }
        return false
    }
    var overReturnBadge = false

    var dragPollenPos: CGPoint? {
        if case .carrying(_, _, let point, let tapMode) = pollination, !tapMode, handDown {
            return point
        }
        return nil
    }

    var dragPollenFromPlot: Int? {
        if case .carrying(let donorPlot, _, _, _) = pollination {
            return donorPlot
        }
        return nil
    }

    var dragPollenKind: PlantKind? {
        if case .carrying(_, let donorKind, _, _) = pollination {
            return donorKind
        }
        return nil
    }

    var isPollinatingTapMode: Bool {
        if case .carrying(_, _, _, let tapMode) = pollination { return tapMode }
        return false
    }

    var dragCrownPos: CGPoint? {
        if case .flowerCrown? = grab, handDown { return handP }
        return nil
    }

    var dragBasketPos: CGPoint? {
        if case .basketFeed? = grab, handDown { return handP }
        return nil
    }

    var dragBasketPreview: HarvestItem? {
        if case .basketFeed? = grab, handDown {
            return inventory.last(where: \.isEdibleProduce) ?? inventory.last
        }
        return nil
    }

    func isOverReturnBadge(_ p: CGPoint) -> Bool {
        hypot(p.x - GGeo.returnBadge.x, p.y - GGeo.returnBadge.y) < 76
    }

    var demo = false

    // Post-frame effect outbox and diffed UI snapshot publisher.
    private var outbox: [GardenEffect] = []
    var queuedStickers = Set<GardenFind>()
    private var flushScheduled = false
    private var uiStateDirty = true
    private var lastPublishedUIState: GardenUIState?
    var onUIStateChange: ((GardenUIState) -> Void)?

    // MARK: Setup

    init(save: GardenSave? = GardenStorage.load()) {
        let n = GGeo.columns
        h = GardenSim.flatSoil(count: n)
        wet = [CGFloat](repeating: 0.06, count: n)
        let starterSurprises: [BuriedSurprise] = [.worm, .mysteryBulb, .ladybug, .coins, .worm, .coins]
        plots = GGeo.plotX.indices.map { i in
            GPlot(stage: .empty(surprise: starterSurprises[i % starterSurprises.count], surpriseReady: true))
        }
        ladybug = GLadybug(x: 310, dir: 1, p: CGPoint(x: 310, y: GGeo.soilY))
        worm = GWorm(x: 470, depth: 52, dir: 1)
        let initialOrder = FarmstandOrderGenerator.nextOrder(inventory: [], servedCount: 0, previousCustomer: nil, seed: 0)
        farmstandPhase = .crafting(order: initialOrder, draft: GardenSim.initialDraft(for: initialOrder))
        if let s = save {
            restore(s)
        } else {
            starterGarden()
            let freshOrder = FarmstandOrderGenerator.nextOrder(inventory: inventory, servedCount: 0, previousCustomer: nil, seed: 0)
            farmstandPhase = .crafting(order: freshOrder, draft: GardenSim.initialDraft(for: freshOrder))
        }
        for i in 0..<2 { spawnButterfly(i, fromEdge: false) }
    }

    private static func initialDraft(for order: FarmstandOrder) -> FarmstandDraft {
        var draft = FarmstandDraft()
        if let wrap = order.preferredWrap { draft.wrap = wrap }
        if let ribbon = order.preferredRibbon { draft.ribbon = ribbon }
        if let lid = order.preferredLid { draft.lid = lid }
        return draft
    }

    private static func flatSoil(count n: Int) -> [CGFloat] {
        (0..<n).map { i -> CGFloat in
            let fi = CGFloat(i)
            let waveA: CGFloat = sin(fi * 0.21) * 1.1
            let waveB: CGFloat = sin(fi * 0.07 + 1.3) * 1.2
            return GGeo.soilY + waveA + waveB
        }
    }

    private func starterGarden() {
        plots[0].stage = .growing(GrowingPlant(kind: .sunflower, growth: 0.35, variant: 0))
        plots[2].stage = .growing(GrowingPlant(kind: .tomato, growth: 0.65, variant: 0))
        plots[4].stage = .ripe(RipePlant(kind: .tulip, variant: 0, yieldLeft: PlantKind.tulip.crop))
        for i in 0..<GGeo.columns {
            let x = GGeo.colX(i)
            if abs(x - GGeo.plotX[4]) < 56 { wet[i] = 0.55 }
        }
        weeds = [GWeed(x: 308, growth: 0.85, seed: 3), GWeed(x: 564, growth: 0.65, seed: 8)]
        addDecor(.pinwheel, x: 196, falling: false)
        addDecor(.birdbath, x: 724, falling: false)
    }

    private func restore(_ s: GardenSave) {
        let n = GGeo.columns
        if s.soil.count == n {
            let avg = s.soil.reduce(0, +) / Double(n)
            h = s.soil.map { val in
                let offset = CGFloat(val - avg)
                return max(GGeo.soilY - 22, min(GGeo.soilY + GGeo.maxDepth, GGeo.soilY + offset))
            }
        } else {
            h = GardenSim.flatSoil(count: n)
        }
        if s.wet.count == n {
            wet = s.wet.map { max(0, min(1.15, CGFloat($0))) }
        } else if !s.wet.isEmpty {
            wet = (0..<n).map { i in
                let idx = min(s.wet.count - 1, Int(Double(i) / Double(n) * Double(s.wet.count)))
                return max(0, min(1.15, CGFloat(s.wet[idx])))
            }
        }
        let defaultSurprises: [BuriedSurprise] = [.worm, .mysteryBulb, .ladybug, .coins, .worm, .coins]
        for i in 0..<min(plots.count, s.plots.count) {
            plots[i].stage = GardenSave.stage(from: s.plots[i], defaultSurprise: defaultSurprises[i % defaultSurprises.count])
        }
        weeds = s.weeds.map { w in
            let x = max(GGeo.bedLeft + 18, min(GGeo.bedRight - 18, CGFloat(w.x)))
            return GWeed(x: x, growth: CGFloat(w.growth), seed: w.seed)
        }
        decor = []
        for d in s.decor {
            let idx = addDecor(d.kind, x: CGFloat(d.x), falling: false)
            decor[idx].water = CGFloat(d.water)
        }
        inventory = s.resolvedInventory(maxCount: GardenSim.maxInventory)
        discoveredHybrids = s.discoveredHybrids ?? []
        picnicFeedCount = max(0, s.picnicFeedCount ?? 0)
        farmstandServedCount = max(0, s.farmstandServedCount ?? 0)
        let computedStage = (farmstandServedCount + picnicFeedCount) / 2
        treehouseStage = max(0, min(GardenSim.maxTreehouseStage, max(s.treehouseStage ?? 0, computedStage)))
        season = s.season ?? .spring
        caughtFireflies = max(0, min(GardenSim.maxCaughtFireflies, s.caughtFireflies ?? 0))
        weather = s.weather
        rain = weather == .rain ? 1 : 0
        night = weather == .night ? 1 : 0
        wind = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        cloud = weather == .rain ? 1 : (weather == .wind ? 0.45 : 0.12)
        if let savedOrder = s.activeOrder {
            farmstandPhase = .crafting(order: savedOrder, draft: GardenSim.initialDraft(for: savedOrder))
        } else {
            let fresh = FarmstandOrderGenerator.nextOrder(
                inventory: inventory,
                servedCount: farmstandServedCount,
                previousCustomer: nil,
                seed: 0
            )
            farmstandPhase = .crafting(order: fresh, draft: GardenSim.initialDraft(for: fresh))
        }
    }

    func makeSave() -> GardenSave {
        var persistedInventory = inventory
        if let draft = activeDraft {
            persistedInventory.append(contentsOf: draft.items)
        }
        if let dragged = draggedStockItem {
            persistedInventory.append(dragged)
        }
        return GardenSave(
            plots: plots.map { $0.plant },
            soil: h.map { Double($0) },
            wet: wet.map { Double($0) },
            weeds: weeds.map { WeedSave(x: Double($0.x), growth: Double($0.growth), seed: $0.seed) },
            decor: decor.map { DecorSave(kind: $0.kind, x: Double($0.x), water: Double($0.water)) },
            basket: GardenSave.encodeLegacyBasket(persistedInventory),
            weather: weather,
            bouquet: GardenSave.encodeLegacyBouquet(persistedInventory, maxCount: GardenSim.maxBouquet),
            discoveredHybrids: discoveredHybrids.isEmpty ? nil : discoveredHybrids,
            treehouseStage: treehouseStage > 0 ? treehouseStage : nil,
            picnicFeedCount: picnicFeedCount > 0 ? picnicFeedCount : nil,
            season: season,
            caughtFireflies: caughtFireflies > 0 ? caughtFireflies : nil,
            harvestInventory: persistedInventory,
            farmstandServedCount: farmstandServedCount > 0 ? farmstandServedCount : nil,
            activeOrder: activeOrder
        )
    }

    func save() {
        guard !demo else { return }
        GameStorage.flushAsyncSaves()
        GardenStorage.save(makeSave())
    }

    func saveAsync() {
        guard !demo else { return }
        GardenStorage.saveAsync(makeSave())
    }

    // MARK: Post-Frame Outbox & UI Snapshot

    func enqueueEffect(_ effect: GardenEffect) {
        outbox.append(effect)
        schedulePostFrameFlush()
    }

    func markUIStateDirty() {
        uiStateDirty = true
        schedulePostFrameFlush()
    }

    func schedulePostFrameFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingEffects()
        }
    }

    func flushPendingEffects() {
        flushScheduled = false
        if !outbox.isEmpty {
            let pending = outbox
            outbox.removeAll(keepingCapacity: true)
            var shouldSave = false
            var shouldHaptic = false
            for effect in pending {
                switch effect {
                case .earnCoins(let amount, let from):
                    if !demo || Coins.shared.demo {
                        Coins.shared.earn(amount, game: GardenSim.gameID, from: from)
                    }
                case .discoverSticker(let find, _):
                    if !demo || StickerBook.shared.demo {
                        _ = StickerBook.shared.find(game: GardenSim.gameID, id: find.rawValue)
                    }
                case .haptic:
                    shouldHaptic = true
                case .save:
                    shouldSave = true
                }
            }
            if shouldHaptic {
                Sound.shared.tap()
            }
            if shouldSave {
                saveAsync()
            }
        }
        let next = currentUIState()
        if uiStateDirty || next != lastPublishedUIState {
            uiStateDirty = false
            lastPublishedUIState = next
            onUIStateChange?(next)
        }
    }

    func drainEffectsForTesting() {
        flushPendingEffects()
    }

    func suggestedDockHint() -> GardenDockHint? {
        if plots.contains(where: {
            if case .growing = $0.stage { return $0.dry > 1.5 }
            return false
        }) {
            return .can
        }
        if plots.allSatisfy(\.isEmpty) {
            return .seeds
        }
        if !weeds.isEmpty {
            return .shovel
        }
        return nil
    }

    func currentUIState() -> GardenUIState {
        let order = activeOrder
        let draft = activeDraft
        let matchResult: FarmstandMatchResult? = {
            guard let order, let draft else { return nil }
            return FarmstandMatcher.match(requirements: order.requirements, items: draft.items)
        }()
        let readyInInventory: Bool = {
            guard let order else { return false }
            var pool = inventory + (draft?.items ?? [])
            if let dragged = draggedStockItem {
                pool.append(dragged)
            }
            return FarmstandMatcher.canFulfill(order: order, with: pool)
        }()
        let celebrating: Bool
        let celStars: Int
        if case .celebrating(let cel) = farmstandPhase {
            celebrating = true
            celStars = cel.stars
        } else {
            celebrating = false
            celStars = 0
        }
        return GardenUIState(
            station: station,
            weather: weather,
            season: season,
            discoveredHybrids: discoveredHybrids,
            hasRecentHybridDiscovery: hasRecentHybridDiscovery,
            suggestedHint: tool == nil ? suggestedDockHint() : nil,
            showReturnBadge: isDraggingDecor,
            overReturnBadge: overReturnBadge,
            inventory: inventory,
            draggedStockItem: draggedStockItem,
            activeOrder: order,
            orderReadyInInventory: readyInInventory,
            farmstandServedCount: farmstandServedCount,
            treehouseStage: treehouseStage,
            draftMatchedSlots: matchResult?.slotMatched ?? [],
            draftItemCount: draft?.items.count ?? 0,
            draftCanServe: !(draft?.items.isEmpty ?? true),
            draftWrap: draft?.wrap ?? .blushGingham,
            draftRibbon: draft?.ribbon ?? .berryPink,
            draftLid: draft?.lid ?? .strawberryGingham,
            draftDewSpritzed: draft?.dewSpritzed ?? false,
            isCelebrating: celebrating,
            celebrationStars: celStars,
            isPollinatingTapMode: isPollinatingTapMode
        )
    }

    // MARK: FingerLift Ownership & Unified Scene Gestures

    static func lift(for tool: GardenTool) -> CGFloat {
        switch tool {
        case .shovel: return FingerLift.tool
        case .can: return FingerLift.carry(below: 106)
        case .seeds: return FingerLift.carry(below: 45)
        case .decor(let k): return FingerLift.carry(below: k.size.height * 0.5)
        }
    }

    static func liftedPoint(_ finger: CGPoint, lift: CGFloat) -> CGPoint {
        FingerLift.point(finger, lift: lift, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }

    static func fingerPoint(for target: CGPoint, lift: CGFloat) -> CGPoint {
        FingerLift.finger(for: target, lift: lift, bottom: GameChromeLayout.height, width: GameChromeLayout.width)
    }

    func handleDockToolDragChanged(_ toolKind: GardenTool, finger: CGPoint) {
        if tool == nil {
            pickUp(toolKind, at: finger)
        }
        if let activeTool = tool {
            carry(to: GardenSim.liftedPoint(finger, lift: GardenSim.lift(for: activeTool)), hand: finger)
        }
    }

    func handleDockToolDragEnded(home: CGPoint) {
        release(home: home)
    }

    func handleSceneDragChanged(_ location: CGPoint, startLocation: CGPoint, dt: CGFloat) {
        switch station {
        case .bed:
            if !sceneDragActive {
                sceneDragActive = true
                handBegan(location)
            } else {
                let target: CGPoint
                switch grab {
                case .pollen?, .flowerCrown?, .basketFeed?:
                    target = GardenSim.liftedPoint(location, lift: FingerLift.item)
                case .decor(let d)?:
                    let liftAmt = d < decor.count ? FingerLift.carry(below: decor[d].kind.size.height * 0.5) : FingerLift.item
                    target = GardenSim.liftedPoint(location, lift: liftAmt)
                default:
                    target = location
                }
                handMoved(target, rawFinger: location, dt: dt)
            }
        case .farmstand:
            handleFarmstandDragChanged(location, startLocation: startLocation, dt: dt)
        }
    }

    func handleSceneDragEnded(_ location: CGPoint, startLocation: CGPoint, duration: Double) {
        let moved = hypot(location.x - startLocation.x, location.y - startLocation.y)
        let isTap = moved < 14 && duration < 0.45
        switch station {
        case .bed:
            let finalPoint: CGPoint
            if !isTap {
                switch grab {
                case .pollen?, .flowerCrown?, .basketFeed?:
                    finalPoint = GardenSim.liftedPoint(location, lift: FingerLift.item)
                case .decor(let d)?:
                    let liftAmt = d < decor.count ? FingerLift.carry(below: decor[d].kind.size.height * 0.5) : FingerLift.item
                    finalPoint = GardenSim.liftedPoint(location, lift: liftAmt)
                default:
                    finalPoint = location
                }
            } else {
                finalPoint = location
            }
            handEnded(finalPoint, rawFinger: location, tap: isTap)
            sceneDragActive = false
        case .farmstand:
            handleFarmstandDragEnded(location, tap: isTap)
            sceneDragActive = false
        }
    }

    // MARK: Soil helpers

    func surface(_ x: CGFloat) -> CGFloat {
        let f = (x - GGeo.bedLeft) / GGeo.col - 0.5
        let i0 = max(0, min(GGeo.columns - 1, Int(f.rounded(.down))))
        let i1 = min(GGeo.columns - 1, i0 + 1)
        let k = max(0, min(1, f - CGFloat(i0)))
        return h[i0] + (h[i1] - h[i0]) * k
    }

    func wetAt(_ x: CGFloat, span: Int = 4) -> CGFloat {
        let c = GGeo.column(x)
        var s: CGFloat = 0
        var n: CGFloat = 0
        for i in max(0, c - span)...min(GGeo.columns - 1, c + span) {
            s += wet[i]
            n += 1
        }
        return n > 0 ? s / n : 0
    }

    var totalSoil: CGFloat { h.reduce(0) { $0 + (GGeo.bedBottom - $1) } }

    private func deposit(_ mass: CGFloat, at x: CGFloat) {
        let c = GGeo.column(x)
        let lo = max(0, c - 2)
        let hi = min(GGeo.columns - 1, c + 2)
        guard lo <= hi else { return }
        let weights: [CGFloat] = [0.15, 0.25, 0.3, 0.2, 0.1]
        var wsum: CGFloat = 0
        for i in lo...hi { wsum += weights[i - c + 2] }
        for i in lo...hi { h[i] -= mass / GGeo.col * weights[i - c + 2] / wsum }
    }

    // MARK: Frame

    func step(_ now: Date) {
        let raw = last.map { now.timeIntervalSince($0) } ?? 1.0 / 60
        last = now
        step(dt: CGFloat(min(max(raw, 0), 1.0 / 30)))
    }

    func step(dt: CGFloat) {
        guard dt > 0 else { return }
        time += Double(dt)
        stepWeather(dt)
        stepTool(dt)
        stepSoil(dt)
        stepPlants(dt)
        stepWeeds(dt)
        stepParticles(dt)
        stepFlyers()
        stepDecor(dt)
        stepCritters(dt)
        stepPicnic(dt)
        stepFinds(dt)
        stepProps(dt)
        stepFarmstand(dt)
        stepSound()
        if time - lastSave > 20 {
            lastSave = time
            enqueueEffect(.save)
        }
        let current = currentUIState()
        if uiStateDirty || current != lastPublishedUIState {
            schedulePostFrameFlush()
        }
    }

    // MARK: Station & Farmstand Crafting Simulation

    func setStation(_ next: GardenStation) {
        guard next != station else { return }
        cancelStockItemDrag()
        farmstandSpritzHeld = false
        farmstandSpritzPos = GGeo.Farmstand.spritzHome
        farmstandSpritzTilt = 0
        farmstandPlungerHeld = false
        pollination = .idle
        grab = nil
        handDown = false
        sceneDragActive = false
        station = next
        Sound.shared.play(.flip, volume: 0.65)
        enqueueEffect(.haptic)
        markUIStateDirty()
    }

    @discardableResult
    func addStockItemToDraft(_ itemID: UUID) -> Bool {
        guard case .crafting(let order, var draft) = farmstandPhase else { return false }
        guard !draft.isFull else {
            farmstandCraftBounceV += 7
            Sound.shared.play(.boing, volume: 0.3)
            return false
        }
        guard let idx = inventory.firstIndex(where: { $0.id == itemID }) else { return false }
        let candidate = inventory[idx]
        guard order.kind.accepts(candidate) else {
            farmstandCraftBounceV += 6
            Sound.shared.play(.boing, volume: 0.35)
            return false
        }
        let item = inventory.remove(at: idx)
        draft.items.append(item)
        if order.kind == .jamJar && draft.pressProgress > 0.45 {
            draft.pressProgress = 0.45
            lastJamPressMilestone = min(lastJamPressMilestone, 1)
        }
        farmstandPhase = .crafting(order: order, draft: draft)
        farmstandCraftBounceV += 11
        let burst = CGPoint(x: GGeo.Farmstand.craftCenter.x, y: GGeo.Farmstand.craftCenter.y - 44)
        spawnFarmstandSparkles(at: burst, count: 10, color: item.source.displayColor)
        Sound.shared.play(.pop, volume: 0.65)
        enqueueEffect(.haptic)
        let match = FarmstandMatcher.match(requirements: order.requirements, items: draft.items)
        if match.allMatched {
            farmstandBellBounceV += 10
            Sound.shared.play(.ding, volume: 0.55)
        }
        markUIStateDirty()
        return true
    }

    @discardableResult
    func removeDraftItem(id itemID: UUID) -> Bool {
        guard case .crafting(let order, var draft) = farmstandPhase else { return false }
        guard let idx = draft.items.firstIndex(where: { $0.id == itemID }) else { return false }
        let item = draft.items.remove(at: idx)
        inventory.append(item)
        if draft.items.isEmpty {
            draft.dewSpritzed = false
            draft.pressProgress = 0
            lastJamPressMilestone = 0
        }
        farmstandPhase = .crafting(order: order, draft: draft)
        farmstandCraftBounceV += 7
        Sound.shared.play(.whoosh, volume: 0.45)
        enqueueEffect(.haptic)
        markUIStateDirty()
        return true
    }

    func clearDraft() {
        guard case .crafting(let order, var draft) = farmstandPhase else { return }
        guard !draft.items.isEmpty else { return }
        inventory.append(contentsOf: draft.items)
        draft.items.removeAll()
        draft.dewSpritzed = false
        draft.pressProgress = 0
        lastJamPressMilestone = 0
        farmstandPhase = .crafting(order: order, draft: draft)
        markUIStateDirty()
    }

    func selectWrap(_ wrap: WrapPaperStyle) {
        guard case .crafting(let order, var draft) = farmstandPhase, order.kind == .bouquet else { return }
        draft.wrap = wrap
        farmstandPhase = .crafting(order: order, draft: draft)
        farmstandCraftBounceV += 8
        Sound.shared.play(.pop, volume: 0.55)
        enqueueEffect(.haptic)
        markUIStateDirty()
    }

    func selectRibbon(_ ribbon: BouquetRibbonColor) {
        guard case .crafting(let order, var draft) = farmstandPhase, order.kind == .bouquet else { return }
        draft.ribbon = ribbon
        farmstandPhase = .crafting(order: order, draft: draft)
        farmstandCraftBounceV += 8
        Sound.shared.play(.pop, volume: 0.55)
        enqueueEffect(.haptic)
        markUIStateDirty()
    }

    func selectLid(_ lid: JamLidColor) {
        guard case .crafting(let order, var draft) = farmstandPhase, order.kind == .jamJar else { return }
        draft.lid = lid
        farmstandPhase = .crafting(order: order, draft: draft)
        farmstandCraftBounceV += 8
        Sound.shared.play(.pop, volume: 0.55)
        enqueueEffect(.haptic)
        markUIStateDirty()
    }

    func spritzBouquetDew(at point: CGPoint? = nil) {
        guard case .crafting(let order, var draft) = farmstandPhase, order.kind == .bouquet else { return }
        draft.dewSpritzed = true
        farmstandPhase = .crafting(order: order, draft: draft)
        farmstandCraftBounceV += 9
        let center = point ?? CGPoint(x: GGeo.Farmstand.craftCenter.x, y: GGeo.Farmstand.craftCenter.y - 72)
        for k in 0..<14 {
            let a = CGFloat(k) / 14 * 2 * .pi + CGFloat.random(in: -0.2...0.2)
            let sp = CGFloat.random(in: 55...150)
            farmstandParticles.append(GParticle(
                kind: k % 2 == 0 ? .sparkle : .splash,
                p: CGPoint(x: center.x + CGFloat.random(in: -24...24), y: center.y + CGFloat.random(in: -20...20)),
                v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 30),
                life: 0.85,
                size: k % 2 == 0 ? CGFloat.random(in: 7...11) : CGFloat.random(in: 3...5),
                color: k % 2 == 0 ? GRGB(0xFFF3A8) : GRGB(0xA6E4FF),
                spin: CGFloat.random(in: -3...3)
            ))
        }
        GardenSound.shared.play(.splash, volume: 0.55)
        Sound.shared.play(.sparkle, volume: 0.6)
        enqueueEffect(.haptic)
        markUIStateDirty()
    }

    func pressJamPlunger(increment: CGFloat = 0.35) {
        guard case .crafting(let order, let draft) = farmstandPhase, order.kind == .jamJar, !draft.items.isEmpty else {
            farmstandCraftBounceV += 6
            Sound.shared.play(.boing, volume: 0.3)
            return
        }
        let before = draft.pressProgress
        let next = min(1.0, before + increment)
        applyJamPressProgress(next, order: order, draft: draft)
    }

    func setJamPressProgress(_ progress: CGFloat) {
        guard case .crafting(let order, let draft) = farmstandPhase, order.kind == .jamJar, !draft.items.isEmpty else { return }
        let clamped = max(draft.pressProgress, min(1.0, progress))
        guard clamped > draft.pressProgress + 0.01 else { return }
        applyJamPressProgress(clamped, order: order, draft: draft)
    }

    private func applyJamPressProgress(_ next: CGFloat, order: FarmstandOrder, draft: FarmstandDraft) {
        var updated = draft
        let prevMilestone = updated.pressProgress >= 0.99 ? 4 : Int(floor(updated.pressProgress * 4))
        if prevMilestone < lastJamPressMilestone {
            lastJamPressMilestone = prevMilestone
        }
        let wasFinished = updated.pressProgress >= 0.99
        updated.pressProgress = next >= 0.96 ? 1.0 : next
        farmstandPhase = .crafting(order: order, draft: updated)

        let milestone = updated.pressProgress >= 0.99 ? 4 : Int(floor(updated.pressProgress * 4))
        guard milestone > lastJamPressMilestone else { return }
        lastJamPressMilestone = milestone

        farmstandCraftBounceV += 10
        let col = updated.jamColor
        let jarTop = CGPoint(x: GGeo.Farmstand.craftCenter.x, y: GGeo.Farmstand.craftCenter.y - 26)
        for _ in 0..<7 {
            farmstandParticles.append(GParticle(
                kind: .splash,
                p: CGPoint(x: jarTop.x + CGFloat.random(in: -26...26), y: jarTop.y),
                v: CGVector(dx: CGFloat.random(in: -110...110), dy: CGFloat.random(in: -180 ... -70)),
                life: 0.55,
                size: CGFloat.random(in: 3.5...6.5),
                color: col
            ))
        }
        Sound.shared.play(.pop, volume: 0.65)
        enqueueEffect(.haptic)
        if !wasFinished && updated.pressProgress >= 0.99 {
            spawnFarmstandSparkles(at: jarTop, count: 16, color: GRGB(0xFFE38A))
            Sound.shared.play(.ding, volume: 0.65)
            Sound.shared.play(.sparkle, volume: 0.65)
            farmstandBellBounceV += 12
            markUIStateDirty()
        }
    }

    @discardableResult
    func serveFarmstandOrder() -> Int? {
        guard case .crafting(let order, let draft) = farmstandPhase, !draft.items.isEmpty else {
            farmstandBellBounceV += 6
            Sound.shared.play(.boing, volume: 0.3)
            return nil
        }
        let stars = FarmstandScoring.evaluate(order: order, draft: draft)
        let coins = Coins.reward(stars: stars)

        farmstandServedCount += 1
        let targetStage = min(GardenSim.maxTreehouseStage, (farmstandServedCount + picnicFeedCount) / 2)
        if targetStage > treehouseStage {
            treehouseStage = targetStage
            treehouseUpgradeAt = time
            treehouseBounceV += 14
        }

        let celebration = FarmstandCelebration(
            customer: order.customer,
            orderKind: order.kind,
            servedItems: draft.items,
            wrap: draft.wrap,
            ribbon: draft.ribbon,
            lid: draft.lid,
            stars: stars,
            coinsAwarded: coins,
            startedAt: time
        )
        farmstandPhase = .celebrating(celebration)
        lastJamPressMilestone = 0
        farmstandBellBounceV += 14
        farmstandCraftBounceV += 12
        nextCelebrationHeartAt = time + 0.2

        let customerOrigin = CGPoint(x: GGeo.Farmstand.customerSeat.x, y: GGeo.Farmstand.customerSeat.y - 68)
        spawnFarmstandCelebrationBurst(at: customerOrigin, stars: stars)
        playVisitorSound(order.customer)
        Sound.shared.play(.ding, volume: 0.7)
        Sound.shared.play(.cheer, volume: 0.6)
        Sound.shared.play(.fanfare, volume: 0.55)
        enqueueEffect(.haptic)

        earnCoins(coins, from: customerOrigin)
        if let sticker = GardenFind(rawValue: order.customer.rawValue) {
            discover(sticker, at: customerOrigin)
        }
        enqueueEffect(.save)
        markUIStateDirty()
        return stars
    }

    func advanceToNextOrder(previousCustomer: GVisitorKind? = nil) {
        cancelStockItemDrag()
        orderSeed += 1
        let nextOrder = FarmstandOrderGenerator.nextOrder(
            inventory: inventory,
            servedCount: farmstandServedCount,
            previousCustomer: previousCustomer,
            seed: orderSeed
        )
        farmstandPhase = .crafting(order: nextOrder, draft: GardenSim.initialDraft(for: nextOrder))
        lastJamPressMilestone = 0
        farmstandSpritzHeld = false
        farmstandSpritzPos = GGeo.Farmstand.spritzHome
        farmstandSpritzTilt = 0
        farmstandPlungerHeld = false
        markUIStateDirty()
    }

    @discardableResult
    func beginStockItemDrag(_ itemID: UUID, finger: CGPoint) -> Bool {
        guard case .crafting(let order, let draft) = farmstandPhase, !draft.isFull else { return false }
        guard let idx = inventory.firstIndex(where: { $0.id == itemID }) else { return false }
        guard order.kind.accepts(inventory[idx]) else {
            farmstandCraftBounceV += 6
            Sound.shared.play(.boing, volume: 0.35)
            return false
        }
        draggedStockOriginalIndex = idx
        draggedStockItem = inventory.remove(at: idx)
        draggedStockPos = GardenSim.liftedPoint(finger, lift: FingerLift.item)
        enqueueEffect(.haptic)
        markUIStateDirty()
        return true
    }

    func moveStockItemDrag(finger: CGPoint) {
        guard draggedStockItem != nil else { return }
        draggedStockPos = GardenSim.liftedPoint(finger, lift: FingerLift.item)
    }

    func cancelStockItemDrag() {
        guard let item = draggedStockItem else { return }
        let idx = min(draggedStockOriginalIndex ?? inventory.count, inventory.count)
        draggedStockItem = nil
        draggedStockOriginalIndex = nil
        inventory.insert(item, at: idx)
        markUIStateDirty()
    }

    func endStockItemDrag(finger: CGPoint) {
        guard let item = draggedStockItem else { return }
        let origIdx = draggedStockOriginalIndex
        draggedStockItem = nil
        draggedStockOriginalIndex = nil
        let drop = GardenSim.liftedPoint(finger, lift: FingerLift.item)
        let targetZone = GGeo.Farmstand.craftDropZone.insetBy(dx: -44, dy: -44)
        if (targetZone.contains(drop) || targetZone.contains(finger)),
           case .crafting(let order, var draft) = farmstandPhase,
           !draft.isFull,
           order.kind.accepts(item) {
            draft.items.append(item)
            if order.kind == .jamJar && draft.pressProgress > 0.45 {
                draft.pressProgress = 0.45
                lastJamPressMilestone = min(lastJamPressMilestone, 1)
            }
            farmstandPhase = .crafting(order: order, draft: draft)
            farmstandCraftBounceV += 11
            spawnFarmstandSparkles(at: drop, count: 10, color: item.source.displayColor)
            Sound.shared.play(.pop, volume: 0.65)
            enqueueEffect(.haptic)
            if FarmstandMatcher.match(requirements: order.requirements, items: draft.items).allMatched {
                farmstandBellBounceV += 10
                Sound.shared.play(.ding, volume: 0.55)
            }
        } else {
            inventory.insert(item, at: min(origIdx ?? inventory.count, inventory.count))
            Sound.shared.play(.whoosh, volume: 0.4)
        }
        markUIStateDirty()
    }

    private func handleFarmstandDragChanged(_ location: CGPoint, startLocation: CGPoint, dt: CGFloat) {
        guard case .crafting(let order, let draft) = farmstandPhase else { return }
        if !sceneDragActive {
            sceneDragActive = true
            if order.kind == .bouquet,
               hypot(location.x - farmstandSpritzPos.x, location.y - farmstandSpritzPos.y) < 58 {
                farmstandSpritzHeld = true
                enqueueEffect(.haptic)
            } else if order.kind == .jamJar, !draft.items.isEmpty {
                let plungerY = GGeo.Farmstand.plungerTopY + draft.pressProgress * GGeo.Farmstand.plungerTravelY
                if abs(location.x - GGeo.Farmstand.craftCenter.x) < 76 && abs(location.y - plungerY) < 72 {
                    farmstandPlungerHeld = true
                    plungerGrabStartY = location.y
                    plungerStartProgress = draft.pressProgress
                    enqueueEffect(.haptic)
                }
            }
        }
        if farmstandSpritzHeld {
            let moved = hypot(location.x - startLocation.x, location.y - startLocation.y)
            if moved >= 10 {
                let lifted = GardenSim.liftedPoint(location, lift: FingerLift.pour)
                farmstandSpritzPos = lifted
                let overBouquet = hypot(lifted.x - GGeo.Farmstand.craftCenter.x, lifted.y - (GGeo.Farmstand.craftCenter.y - 70)) < 150
                farmstandSpritzTilt = overBouquet ? -0.58 : -0.15
                if overBouquet {
                    spritzEmitAcc += dt * 16
                    if spritzEmitAcc >= 1 {
                        spritzEmitAcc -= 1
                        spritzBouquetDew(at: CGPoint(x: lifted.x - 28, y: lifted.y + 34))
                    }
                }
            }
        } else if farmstandPlungerHeld {
            let dy = max(0, location.y - plungerGrabStartY)
            let next = plungerStartProgress + dy / GGeo.Farmstand.plungerTravelY
            setJamPressProgress(next)
        }
    }

    private func handleFarmstandDragEnded(_ location: CGPoint, tap: Bool) {
        let wasSpritz = farmstandSpritzHeld
        let wasPlunger = farmstandPlungerHeld
        farmstandSpritzHeld = false
        farmstandSpritzPos = GGeo.Farmstand.spritzHome
        farmstandSpritzTilt = 0
        farmstandPlungerHeld = false

        guard case .crafting(let order, let draft) = farmstandPhase else { return }

        if tap {
            if wasSpritz {
                spritzBouquetDew()
                return
            }
            if wasPlunger {
                pressJamPlunger()
                return
            }
            farmstandTap(at: location, order: order, draft: draft)
        }
    }

    private func farmstandTap(at p: CGPoint, order: FarmstandOrder, draft: FarmstandDraft) {
        if hypot(p.x - GGeo.Farmstand.serveBell.x, p.y - GGeo.Farmstand.serveBell.y) < GGeo.Farmstand.serveBellRadius + 16 {
            _ = serveFarmstandOrder()
            return
        }

        if order.kind == .bouquet {
            if hypot(p.x - GGeo.Farmstand.spritzHome.x, p.y - GGeo.Farmstand.spritzHome.y) < 58 {
                spritzBouquetDew()
                return
            }
            for (idx, center) in GGeo.Farmstand.wrapSwatchCenters.enumerated() where idx < WrapPaperStyle.allCases.count {
                if hypot(p.x - center.x, p.y - center.y) < 28 {
                    selectWrap(WrapPaperStyle.allCases[idx])
                    return
                }
            }
            for (idx, center) in GGeo.Farmstand.ribbonSwatchCenters.enumerated() where idx < BouquetRibbonColor.allCases.count {
                if hypot(p.x - center.x, p.y - center.y) < 28 {
                    selectRibbon(BouquetRibbonColor.allCases[idx])
                    return
                }
            }
            for (idx, item) in draft.items.enumerated() where idx < GGeo.Farmstand.bouquetSlotOffsets.count {
                let off = GGeo.Farmstand.bouquetSlotOffsets[idx]
                let slotPos = CGPoint(x: GGeo.Farmstand.craftCenter.x + off.x, y: GGeo.Farmstand.craftCenter.y + off.y)
                if hypot(p.x - slotPos.x, p.y - slotPos.y) < 40 {
                    _ = removeDraftItem(id: item.id)
                    return
                }
            }
        } else if order.kind == .jamJar {
            for (idx, center) in GGeo.Farmstand.lidSwatchCenters.enumerated() where idx < JamLidColor.allCases.count {
                if hypot(p.x - center.x, p.y - center.y) < 30 {
                    selectLid(JamLidColor.allCases[idx])
                    return
                }
            }
            let plungerY = GGeo.Farmstand.plungerTopY + draft.pressProgress * GGeo.Farmstand.plungerTravelY
            if abs(p.x - GGeo.Farmstand.craftCenter.x) < 82 && p.y > plungerY - 68 && p.y < GGeo.Farmstand.craftCenter.y + 44 {
                if draft.pressProgress < 0.99 && !draft.items.isEmpty {
                    pressJamPlunger()
                } else if let lastItem = draft.items.last {
                    _ = removeDraftItem(id: lastItem.id)
                }
                return
            }
        } else if order.kind == .farmBasket {
            let arranged = draft.arrangedBasketSlots()
            for (slotIdx, itemOpt) in arranged.enumerated() {
                guard let item = itemOpt else { continue }
                let off = GGeo.Farmstand.basketSlotOffsets[slotIdx]
                let slotPos = CGPoint(x: GGeo.Farmstand.craftCenter.x + off.x, y: GGeo.Farmstand.craftCenter.y + off.y)
                if hypot(p.x - slotPos.x, p.y - slotPos.y) < 42 {
                    _ = removeDraftItem(id: item.id)
                    return
                }
            }
        }

        if hypot(p.x - GGeo.Farmstand.customerSeat.x, p.y - (GGeo.Farmstand.customerSeat.y - 44)) < 76 {
            playVisitorSound(order.customer)
            enqueueEffect(.haptic)
            spawnFarmstandHearts(at: CGPoint(x: GGeo.Farmstand.customerSeat.x, y: GGeo.Farmstand.customerSeat.y - 72), count: 3)
        }
    }

    private func stepFarmstand(_ dt: CGFloat) {
        farmstandCraftBounceV += (-170 * farmstandCraftBounce - 10 * farmstandCraftBounceV) * dt
        farmstandCraftBounce += farmstandCraftBounceV * dt
        farmstandBellBounceV += (-180 * farmstandBellBounce - 10 * farmstandBellBounceV) * dt
        farmstandBellBounce += farmstandBellBounceV * dt

        if case .celebrating(let cel) = farmstandPhase {
            if time >= nextCelebrationHeartAt {
                nextCelebrationHeartAt = time + 0.45
                spawnFarmstandHearts(at: CGPoint(x: GGeo.Farmstand.customerSeat.x, y: GGeo.Farmstand.customerSeat.y - 84), count: 2)
            }
            if time - cel.startedAt >= cel.duration {
                advanceToNextOrder(previousCustomer: cel.customer)
            }
        }

        var keep: [GParticle] = []
        keep.reserveCapacity(farmstandParticles.count)
        for var q in farmstandParticles {
            q.age += dt
            if q.age > q.life { continue }
            switch q.kind {
            case .splash:
                q.v.dy += 620 * dt
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            case .sparkle:
                q.v.dx *= (1 - dt * 2.2)
                q.v.dy *= (1 - dt * 2.2)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
            case .heart:
                q.v.dx += sin(CGFloat(time) * 5 + q.rot) * 40 * dt
                q.v.dx *= (1 - dt * 1.5)
                q.v.dy += (-110 - q.v.dy) * dt * 1.6
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            case .confetti:
                q.v.dy += 260 * dt
                q.v.dx *= (1 - dt * 1.2)
                q.p.x += q.v.dx * dt + sin(CGFloat(time) * 8 + q.rot) * 24 * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
            default:
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            }
            keep.append(q)
        }
        if keep.count > 260 { keep.removeFirst(keep.count - 260) }
        farmstandParticles = keep
    }

    private func spawnFarmstandSparkles(at p: CGPoint, count: Int, color: GRGB) {
        let cols = [GRGB(0xFFFFFF), GRGB(0xFFE38A), color]
        for k in 0..<count {
            let a = CGFloat(k) / CGFloat(max(1, count)) * 2 * .pi + CGFloat.random(in: -0.25...0.25)
            let sp = CGFloat.random(in: 70...160)
            farmstandParticles.append(GParticle(
                kind: .sparkle,
                p: p,
                v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 25),
                life: 0.75,
                size: CGFloat.random(in: 7...13),
                color: cols[k % cols.count],
                spin: CGFloat.random(in: -3...3)
            ))
        }
    }

    private func spawnFarmstandHearts(at p: CGPoint, count: Int) {
        let cols = [GRGB(0xFF7CA8), GRGB(0xFF9EC2), GRGB(0xFFB3CF)]
        for k in 0..<count {
            let dx = (CGFloat(k) - CGFloat(count - 1) / 2) * 26 + CGFloat.random(in: -12...12)
            farmstandParticles.append(GParticle(
                kind: .heart,
                p: CGPoint(x: p.x + CGFloat.random(in: -16...16), y: p.y),
                v: CGVector(dx: dx, dy: CGFloat.random(in: -140 ... -80)),
                life: 1.25,
                size: CGFloat.random(in: 14...20),
                color: cols[k % cols.count],
                rot: CGFloat.random(in: 0...6)
            ))
        }
    }

    private func spawnFarmstandCelebrationBurst(at p: CGPoint, stars: Int) {
        spawnFarmstandHearts(at: p, count: 4 + stars)
        spawnFarmstandSparkles(at: p, count: 12 + stars * 4, color: GRGB(0xFFD54A))
        let colors = [GRGB(0xFF7CA8), GRGB(0xFFD54A), GRGB(0x7FE3B0), GRGB(0x88C8FF), GRGB(0xC9A8FF)]
        for k in 0..<(14 + stars * 6) {
            let a = CGFloat(k) / CGFloat(14 + stars * 6) * 2 * .pi
            let sp = CGFloat.random(in: 120...260)
            farmstandParticles.append(GParticle(
                kind: .confetti,
                p: p,
                v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 140),
                life: CGFloat.random(in: 1.3...2.1),
                size: CGFloat.random(in: 6...10),
                color: colors[k % colors.count],
                rot: CGFloat.random(in: 0...6),
                spin: CGFloat.random(in: -8...8)
            ))
        }
    }

    // MARK: Weather & 4-Season Magic

    func setSeason(_ s: GardenSeason) {
        guard s != season else { return }
        season = s
        spawnSeasonalBurst(for: s)
        Sound.shared.play(.sparkle, volume: 0.5)
        enqueueEffect(.haptic)
        enqueueEffect(.save)
        markUIStateDirty()
    }

    func cycleSeason() {
        setSeason(season.next)
    }

    private func spawnSeasonalBurst(for s: GardenSeason) {
        for i in 0..<14 {
            let x = CGFloat.random(in: 80...940)
            let y = CGFloat.random(in: 110...340)
            switch s {
            case .spring:
                let col = i % 2 == 0 ? GRGB(0xFFB3D2) : GRGB(0xFFE1EE)
                particles.append(GParticle(kind: .petal, p: CGPoint(x: x, y: y),
                                           v: CGVector(dx: CGFloat.random(in: 40...120), dy: CGFloat.random(in: 10...55)),
                                           life: 4.5, size: CGFloat.random(in: 7...11), color: col,
                                           rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -4...4)))
            case .summer:
                particles.append(GParticle(kind: .sparkle, p: CGPoint(x: x, y: y),
                                           v: CGVector(dx: CGFloat.random(in: -40...40), dy: CGFloat.random(in: -30...30)),
                                           life: 1.1, size: CGFloat.random(in: 7...12), color: GRGB(0xFFE680),
                                           spin: CGFloat.random(in: -3...3)))
            case .autumn:
                let cols = [GRGB(0xF08B36), GRGB(0xE8B44A), GRGB(0xE05A3A), GRGB(0xD97828)]
                particles.append(GParticle(kind: .leaf, p: CGPoint(x: x, y: y),
                                           v: CGVector(dx: CGFloat.random(in: 60...150), dy: CGFloat.random(in: 20...70)),
                                           life: 5.0, size: CGFloat.random(in: 9...14), color: cols[i % cols.count],
                                           rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -4...4)))
            case .winter:
                let col = i % 2 == 0 ? GRGB(0xFFFFFF) : GRGB(0xD4F0FF)
                particles.append(GParticle(kind: .snow, p: CGPoint(x: x, y: y),
                                           v: CGVector(dx: CGFloat.random(in: -20...45), dy: CGFloat.random(in: 25...65)),
                                           life: 5.5, size: CGFloat.random(in: 4...8), color: col,
                                           rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -2...2)))
            }
        }
    }

    func setWeather(_ w: Weather) {
        guard w != weather else { return }
        if weather == .rain && (w == .sun || w == .wind) {
            rainbowAt = time
            chargeRipeBloomsWithRainbow()
        }
        weather = w
        if w == .rain { fulfillRainVisitors() }
        markUIStateDirty()
    }

    func chargeRipeBloomsWithRainbow() {
        var chargedAny = false
        for i in plots.indices {
            guard case .ripe(var ripe) = plots[i].stage else { continue }
            ripe.rainbowCharged = true
            plots[i].stage = .ripe(ripe)
            plots[i].popV += 6
            let c = head(plot: i) ?? CGPoint(x: GGeo.plotX[i], y: surface(GGeo.plotX[i]) - 48)
            sparkle(at: c, count: 9)
            chargedAny = true
        }
        if chargedAny {
            Sound.shared.play(.sparkle, volume: 0.65)
        }
    }

    var rainbow: CGFloat {
        let t = CGFloat(time - rainbowAt)
        if t < 0 || t > 16 { return 0 }
        return min(gdEase(t / 2.5), gdEase((16 - t) / 3))
    }

    private func stepWeather(_ dt: CGFloat) {
        let rainT: CGFloat = weather == .rain ? 1 : 0
        let nightT: CGFloat = weather == .night ? 1 : 0
        let windT: CGFloat = weather == .wind ? 1 : (weather == .rain ? 0.35 : 0.08)
        let cloudT: CGFloat = weather == .rain ? 1 : (weather == .wind ? 0.45 : 0.12)
        let k = min(1, dt * 1.1)
        rain += (rainT - rain) * k
        night += (nightT - night) * k
        wind += (windT - wind) * k
        cloud += (cloudT - cloud) * k
        let t = CGFloat(time)
        let gust = 0.65 + 0.35 * sin(t * 0.9) + 0.18 * sin(t * 2.3 + 1)
        windNow = wind * gust + 0.03 * sin(t * 0.7)
        cloudDrift += dt * (6 + wind * 70)

        rainAcc += rain * 260 * dt
        while rainAcc >= 1 {
            rainAcc -= 1
            let x = CGFloat.random(in: -80...1104)
            let drop = GParticle(kind: .rain, p: CGPoint(x: x, y: CGFloat.random(in: -40 ... -6)),
                                 v: CGVector(dx: windNow * 240 + 25, dy: CGFloat.random(in: 980...1220)),
                                 life: 1.8, size: CGFloat.random(in: 1.2...2.2), color: GRGB(0xDDEBFA),
                                 groundY: CGFloat.random(in: 480...620))
            particles.append(drop)
        }
        if wind > 0.4 && time > nextLeaf {
            nextLeaf = time + Double.random(in: 0.25...0.85) / Double(wind)
            let colors: [GRGB]
            switch season {
            case .spring: colors = [GRGB(0xFFB3D2), GRGB(0xFFD6E8), GRGB(0x9CCB5A)]
            case .summer: colors = [GRGB(0x9CCB5A), GRGB(0x6FB04B), GRGB(0xFFE07A)]
            case .autumn: colors = [GRGB(0xF08B36), GRGB(0xE8B44A), GRGB(0xE05A3A)]
            case .winter: colors = [GRGB(0xFFFFFF), GRGB(0xD4F0FF), GRGB(0xB8E2FF)]
            }
            let kind: GPart = season == .winter ? .snow : (season == .spring ? .petal : .leaf)
            let leaf = GParticle(kind: kind, p: CGPoint(x: -60, y: CGFloat.random(in: 110...480)),
                                 v: CGVector(dx: 260, dy: 0), life: 8, size: kind == .snow ? CGFloat.random(in: 4...7) : CGFloat.random(in: 9...14),
                                 color: colors.randomElement() ?? colors[0], rot: CGFloat.random(in: 0...6),
                                 spin: CGFloat.random(in: -4...4))
            particles.append(leaf)
        }

        if time > nextSeasonFlake && rain < 0.6 {
            switch season {
            case .spring:
                nextSeasonFlake = time + Double.random(in: 0.35...0.75)
                let col = Bool.random() ? GRGB(0xFFB3D2) : GRGB(0xFFE0EE)
                particles.append(GParticle(kind: .petal,
                                           p: CGPoint(x: CGFloat.random(in: -20...980), y: CGFloat.random(in: 60...140)),
                                           v: CGVector(dx: 38 + windNow * 120, dy: CGFloat.random(in: 24...48)),
                                           life: 7.5, size: CGFloat.random(in: 6.5...10), color: col,
                                           rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -3...3)))
            case .summer:
                nextSeasonFlake = time + Double.random(in: 0.9...1.6)
                if night < 0.4 {
                    particles.append(GParticle(kind: .sparkle,
                                               p: CGPoint(x: CGFloat.random(in: 80...940), y: CGFloat.random(in: 130...430)),
                                               v: CGVector(dx: CGFloat.random(in: -12...18), dy: CGFloat.random(in: -14...10)),
                                               life: 1.4, size: CGFloat.random(in: 4.5...7.5), color: GRGB(0xFFF0A6),
                                               spin: CGFloat.random(in: -2...2)))
                }
            case .autumn:
                nextSeasonFlake = time + Double.random(in: 0.4...0.85)
                let cols = [GRGB(0xF08B36), GRGB(0xE8B44A), GRGB(0xDC5539), GRGB(0xC96A22)]
                particles.append(GParticle(kind: .leaf,
                                           p: CGPoint(x: CGFloat.random(in: -20...980), y: CGFloat.random(in: 60...140)),
                                           v: CGVector(dx: 48 + windNow * 140, dy: CGFloat.random(in: 28...58)),
                                           life: 7.5, size: CGFloat.random(in: 8...12.5), color: cols.randomElement() ?? cols[0],
                                           rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -3.5...3.5)))
            case .winter:
                nextSeasonFlake = time + Double.random(in: 0.16...0.34)
                let col = Bool.random() ? GRGB(0xFFFFFF) : GRGB(0xD8F1FF)
                particles.append(GParticle(kind: .snow,
                                           p: CGPoint(x: CGFloat.random(in: -20...1044), y: CGFloat.random(in: 50...110)),
                                           v: CGVector(dx: windNow * 80 + CGFloat.random(in: -14...14), dy: CGFloat.random(in: 34...66)),
                                           life: 8.5, size: CGFloat.random(in: 3.5...7.0), color: col,
                                           rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -2...2)))
            }
        }
    }

    // MARK: Tools

    func pickUp(_ t: GardenTool, at p: CGPoint) {
        pollination = .idle
        tool = t
        finger = p
        hold = p
        toolP = p
        lastToolP = p
        toolV = .zero
        tilt = 0
        tiltV = 0
        load = 0
        autoShovelActive = false
        digSound = 0
        weedClearGraceUntil = -10
        returning = nil
        overReturnBadge = false
        for i in plots.indices { plots[i].digWork = 0 }
        switch t {
        case .shovel: GardenSound.shared.play(.plunk, volume: 0.5)
        case .can: GardenSound.shared.play(.splash, volume: 0.4)
        case .seeds: GardenSound.shared.play(.seeds, volume: 0.6)
        case .decor: GardenSound.shared.play(.plunk, volume: 0.5)
        }
        markUIStateDirty()
    }

    func carry(to p: CGPoint, hand h: CGPoint? = nil) {
        finger = p
        hold = h ?? p
        if case .decor? = tool {
            let over = isOverReturnBadge(hold) || isOverReturnBadge(p)
            if over != overReturnBadge {
                overReturnBadge = over
                markUIStateDirty()
            }
        }
    }

    func release(home: CGPoint) {
        guard let t = tool else { return }
        if load > 1 { dropLoad(throwV: CGVector(dx: toolV.dx * 0.3, dy: 0)) }
        switch t {
        case .decor(let k):
            if isOverReturnBadge(hold) || isOverReturnBadge(toolP) {
                Sound.shared.play(.whoosh, volume: 0.5)
            } else {
                let d = addDecor(k, x: toolP.x, falling: true)
                decor[d].y = min(toolP.y + k.size.height * 0.45, decor[d].baseY)
                Sound.shared.play(.whoosh, volume: 0.5)
            }
        case .seeds(let k):
            if toolP.y < GGeo.bedBottom + 50,
               let idx = GGeo.plotX.indices.min(by: { abs(GGeo.plotX[$0] - toolP.x) < abs(GGeo.plotX[$1] - toolP.x) }),
               abs(GGeo.plotX[idx] - toolP.x) < 60,
               plots[idx].isEmpty {
                plant(k, plot: idx)
            }
            returning = (t, toolP, home, time, tilt)
        case .shovel, .can:
            returning = (t, toolP, home, time, tilt)
        }
        overReturnBadge = false
        autoShovelActive = false
        tool = nil
        flow = 0
        markUIStateDirty()
    }

    private func stepTool(_ dt: CGFloat) {
        guard let t = tool else { return }
        let prev = toolP
        let follow = min(1, dt * 30)
        toolP.x += (finger.x - toolP.x) * follow
        toolP.y += (finger.y - toolP.y) * follow
        let vx = (toolP.x - prev.x) / dt
        let vy = (toolP.y - prev.y) / dt
        toolV.dx += (vx - toolV.dx) * min(1, dt * 18)
        toolV.dy += (vy - toolV.dy) * min(1, dt * 18)
        let overGarden = toolP.y < GGeo.bedBottom + 36 && toolP.x > 20 && toolP.x < 1004

        var target: CGFloat = 0
        switch t {
        case .can: target = overGarden ? 0.95 - toolV.dx * 0.0004 : 0
        case .shovel: target = max(-0.5, min(0.5, toolV.dx * 0.0009))
        case .seeds: target = overGarden ? 2.25 + sin(CGFloat(time) * 9) * 0.12 : 0
        case .decor: target = max(-0.38, min(0.38, toolV.dx * 0.0012))
        }
        tiltV += ((target - tilt) * 140 - tiltV * 15) * dt
        tilt += tiltV * dt

        switch t {
        case .can: pour(dt)
        case .shovel: dig(dt, from: prev)
        case .seeds(let k): sow(dt, kind: k)
        case .decor: break
        }
        lastToolP = toolP
    }

    func canSpout() -> (CGPoint, CGVector) {
        let a = -tilt
        let local = CGPoint(x: -112, y: -6)
        let dir0 = CGVector(dx: -0.85, dy: -0.52)
        let c = cos(a)
        let s = sin(a)
        let p = CGPoint(x: toolP.x + local.x * c - local.y * s, y: toolP.y + local.x * s + local.y * c)
        let d = CGVector(dx: dir0.dx * c - dir0.dy * s, dy: dir0.dx * s + dir0.dy * c)
        return (p, d)
    }

    private func pour(_ dt: CGFloat) {
        flow = gdClamp((tilt - 0.35) / 0.45)
        guard flow > 0 else { return }
        let (spout, dir) = canSpout()
        waterAcc += flow * 400 * dt
        let perp = CGVector(dx: -dir.dy, dy: dir.dx)
        while waterAcc >= 1 {
            waterAcc -= 1
            let speed = CGFloat.random(in: 170...255)
            let spread = CGFloat.random(in: -1...1)
            let j = CGFloat.random(in: -7...7) * FingerLift.spread
            let v = CGVector(dx: dir.dx * speed + perp.dx * spread * 66 * FingerLift.spread + toolV.dx * 0.3,
                             dy: dir.dy * speed + perp.dy * spread * 66 * FingerLift.spread + toolV.dy * 0.3)
            let drop = GParticle(kind: .water, p: CGPoint(x: spout.x + perp.dx * j, y: spout.y + perp.dy * j), v: v,
                                 life: 2.8, size: CGFloat.random(in: 3...5), color: GRGB(0xBFE3FF))
            particles.append(drop)
        }
    }

    // MARK: Shovel & Full-Bed Unblock Protection

    private func dig(_ dt: CGFloat, from prev: CGPoint) {
        let tip = toolP
        let moved = hypot(tip.x - prev.x, tip.y - prev.y)
        if GGeo.inBed(tip.x) {
            let surf = surface(tip.x)
            if !autoShovelActive,
               tip.y > surf - 36,
               let wi = weeds.indices.min(by: { abs(weeds[$0].x - tip.x) < abs(weeds[$1].x - tip.x) }),
               abs(weeds[wi].x - tip.x) < 36 * FingerLift.spread {
                popWeed(wi, v: CGVector(dx: toolV.dx * 0.35 + CGFloat.random(in: -90...90), dy: -620))
                weedClearGraceUntil = time + 0.6
                for k in plots.indices { plots[k].digWork = 0 }
            }
            let weedNearby = weeds.contains { abs($0.x - tip.x) < 56 }
            if tip.y > surf - 8 {
                let c = GGeo.column(tip.x)
                var took: CGFloat = 0
                let floor = GGeo.soilY + GGeo.maxDepth
                let tipY = min(tip.y, floor)
                let reach = Int((5 * FingerLift.spread).rounded())
                for i in max(0, c - reach)...min(GGeo.columns - 1, c + reach) {
                    let d = CGFloat(i - c) / (5.0 * FingerLift.spread)
                    let w = exp(-d * d * 1.4)
                    let want = (tipY - 2.5 * d * d) - h[i]
                    if want > 0 {
                        let dh = min(want, 6 * w)
                        h[i] += dh
                        took += dh * GGeo.col
                    }
                }
                if took > 0 {
                    load += took
                    if time - digSound > 0.16 {
                        digSound = time
                        GardenSound.shared.play(.dig, volume: 0.7)
                        enqueueEffect(.haptic)
                    }
                    for _ in 0..<Int(min(4, took / 24)) {
                        particles.append(GParticle(kind: .dust,
                                                   p: CGPoint(x: tip.x + CGFloat.random(in: -16...16) * FingerLift.spread, y: surf),
                                                   v: CGVector(dx: CGFloat.random(in: -40...40), dy: CGFloat.random(in: -60 ... -20)),
                                                   life: 0.7, size: CGFloat.random(in: 8...14), color: GRGB(0xB08660)))
                    }
                }
                if load > 900 {
                    let spill = load - 900
                    load = 900
                    deposit(spill * 0.5, at: tip.x - 28)
                    deposit(spill * 0.5, at: tip.x + 28)
                }
                for i in plots.indices {
                    let dx = abs(GGeo.plotX[i] - tip.x)
                    if !plots[i].isEmpty && !autoShovelActive {
                        if !weedNearby && time >= weedClearGraceUntil && dx < 22 {
                            plots[i].digWork += max(moved, dt * 45)
                            plots[i].bendV += (tip.x - prev.x) * 0.025
                            if plots[i].digWork >= 28 {
                                uproot(i)
                            }
                        } else {
                            plots[i].digWork = max(0, plots[i].digWork - dt * 50)
                        }
                    } else if !autoShovelActive && plots[i].isEmpty && plots[i].surpriseReady && dx < 38 {
                        plots[i].digWork += max(moved, dt * 60)
                        if plots[i].digWork >= 10 {
                            unearthSurprise(plot: i)
                        }
                    }
                }
            } else if load > 1 && tip.y < surf - 14 && toolV.dy < -240 {
                dropLoad(throwV: CGVector(dx: toolV.dx * 0.55, dy: toolV.dy * 0.6))
                GardenSound.shared.play(.toss, volume: 0.7)
            }
        } else if load > 1 && toolV.dy < -240 {
            dropLoad(throwV: CGVector(dx: toolV.dx * 0.55, dy: toolV.dy * 0.6))
            GardenSound.shared.play(.toss, volume: 0.7)
        }
    }

    @discardableResult
    func unearthSurprise(plot i: Int) -> BuriedSurprise? {
        guard plots.indices.contains(i) else { return nil }
        guard case .empty(let surprise, let ready) = plots[i].stage, ready else { return nil }
        plots[i].stage = .empty(surprise: surprise, surpriseReady: false)
        plots[i].surpriseResetAt = time + 5.0
        plots[i].digWork = 0
        plots[i].moundPopV += 10
        let x = GGeo.plotX[i]
        let surf = surface(x)
        let origin = CGPoint(x: x, y: surf - 16)
        burstSoil(at: CGPoint(x: x, y: surf), n: 9)
        sparkle(at: origin, count: 12)
        GardenSound.shared.play(.dig, volume: 0.8)
        Sound.shared.play(.sparkle, volume: 0.55)
        enqueueEffect(.haptic)
        surprisePops.append(SurprisePop(surprise: surprise, origin: origin, start: time))
        switch surprise {
        case .worm:
            worm.x = x
            worm.peek = 0.45
            worm.peekUntil = time + 4.5
            worm.wiggle = time
            GardenSound.shared.play(.squeak, volume: 0.85)
            heartBurst(at: CGPoint(x: x, y: surf - 26), count: 4)
        case .ladybug:
            ladybug.x = x
            ladybug.p = CGPoint(x: x, y: surf - 8)
            ladybugTakeOff()
        case .coins:
            earnCoins(2, from: CGPoint(x: x, y: surf - 24))
        case .mysteryBulb:
            let kind = PlantKind.allCases.randomElement() ?? .tulip
            let rareVariant = Plant.specialVariant + Int.random(in: 0..<6)
            plant(kind, plot: i, forcedVariant: rareVariant)
            GardenSound.shared.play(.grow, volume: 0.85)
        }
        return surprise
    }

    private func uprootPriorityRank(for plotIndex: Int) -> Int {
        switch plots[plotIndex].stage {
        case .empty:
            return 99
        case .growing(let g):
            if g.hybrid != nil { return 4 }
            return g.isSpecial ? 1 : 0
        case .ripe(let r):
            if r.hybrid != nil { return 5 }
            if r.isGiant { return 3 }
            return r.isSpecial ? 2 : 0
        }
    }

    func bestFullBedUprootPlot() -> Int? {
        guard plots.allSatisfy({ !$0.isEmpty }) else { return nil }
        return plots.indices.min { a, b in
            let ra = uprootPriorityRank(for: a)
            let rb = uprootPriorityRank(for: b)
            return ra != rb ? ra < rb : a < b
        }
    }

    func bestShovelTarget() -> CGPoint {
        if let w = weeds.first {
            return CGPoint(x: w.x, y: surface(w.x) + 4)
        }
        if let i = plots.indices.first(where: { plots[$0].isEmpty && plots[$0].surpriseReady }) {
            let x = GGeo.plotX[i]
            return CGPoint(x: x, y: surface(x) + 10)
        }
        if let i = plots.indices.first(where: { plots[$0].isEmpty }) {
            let x = GGeo.plotX[i]
            return CGPoint(x: x, y: surface(x) + 10)
        }
        if let uprootIdx = bestFullBedUprootPlot() {
            let x = GGeo.plotX[uprootIdx]
            return CGPoint(x: x, y: surface(x) + 10)
        }
        return CGPoint(x: 436, y: GGeo.soilY + 6)
    }

    func bestWaterTarget() -> CGPoint {
        let growing = plots.indices.filter {
            if case .growing = plots[$0].stage { return true }
            return false
        }
        if let thirstiest = growing.max(by: { a, b in
            if abs(plots[a].dry - plots[b].dry) > 0.25 { return plots[a].dry < plots[b].dry }
            return wetAt(GGeo.plotX[a]) > wetAt(GGeo.plotX[b])
        }) {
            let x = GGeo.plotX[thirstiest]
            return CGPoint(x: x, y: surface(x) - 34)
        }
        if let puffableIdx = plots.indices.first(where: {
            if case .ripe(let r) = plots[$0].stage {
                return r.harvestMechanic == .waterPuff && !r.isGiant
            }
            return false
        }) {
            let x = GGeo.plotX[puffableIdx]
            return CGPoint(x: x, y: surface(x) - 34)
        }
        return CGPoint(x: GGeo.plotX[2], y: GGeo.soilY - 34)
    }

    func autoShovel(at spot: CGPoint) {
        if let wi = weeds.indices.min(by: { abs(weeds[$0].x - spot.x) < abs(weeds[$1].x - spot.x) }),
           abs(weeds[wi].x - spot.x) < 56 {
            popWeed(wi, v: CGVector(dx: CGFloat.random(in: -90...90), dy: -620))
            return
        }
        if let i = plots.indices.min(by: { abs(GGeo.plotX[$0] - spot.x) < abs(GGeo.plotX[$1] - spot.x) }),
           abs(GGeo.plotX[i] - spot.x) < 60,
           plots[i].isEmpty {
            if plots[i].surpriseReady {
                unearthSurprise(plot: i)
            } else {
                let x = GGeo.plotX[i]
                plots[i].moundPopV += 6
                burstSoil(at: CGPoint(x: x, y: surface(x)), n: 6)
                GardenSound.shared.play(.dig, volume: 0.7)
            }
            return
        }
        if let i = plots.indices.first(where: { plots[$0].isEmpty && plots[$0].surpriseReady }) {
            unearthSurprise(plot: i)
            return
        }
        if let uprootIdx = bestFullBedUprootPlot() {
            uproot(uprootIdx)
        }
    }

    func tapDockShovel() {
        autoShovel(at: bestShovelTarget())
    }

    private func dropLoad(throwV: CGVector) {
        let n = max(3, min(14, Int(load / 50)))
        let each = load / CGFloat(n)
        let browns = [GRGB(0x8A5A36), GRGB(0x7A4E2E), GRGB(0x9C6A42), GRGB(0x6B4428)]
        for k in 0..<n {
            let jx = CGFloat.random(in: -14...14)
            let v = CGVector(dx: throwV.dx + CGFloat.random(in: -110...110), dy: throwV.dy + CGFloat.random(in: -130...40))
            let clod = GParticle(kind: .clod, p: CGPoint(x: toolP.x + jx, y: toolP.y - 18 - CGFloat(k % 3) * 4), v: v,
                                 life: 5, size: CGFloat.random(in: 4...8), color: browns[k % browns.count],
                                 rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -9...9), mass: each)
            particles.append(clod)
        }
        load = 0
    }

    private func sow(_ dt: CGFloat, kind: PlantKind) {
        guard tilt > 1.5 else { return }
        seedTimer -= dt
        if seedTimer > 0 { return }
        seedTimer = 0.12
        let a = tilt
        let local = CGPoint(x: 0, y: -46)
        let p = CGPoint(x: toolP.x + local.x * cos(a) - local.y * sin(a), y: toolP.y + local.x * sin(a) + local.y * cos(a))
        let s = GParticle(kind: .seed, p: p, v: CGVector(dx: toolV.dx * 0.2 + CGFloat.random(in: -36...36), dy: CGFloat.random(in: 0...60)),
                          life: 4, size: kind == .pumpkin ? 5 : (kind == .sunflower ? 4.4 : 3.2), color: kind.seedColor,
                          rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -8...8), seed: kind)
        particles.append(s)
        if Int(time * 7.7) % 3 == 0 { GardenSound.shared.play(.seeds, volume: 0.35, gap: 0.25) }
    }

    // MARK: Zero-Friction Planting & Watering

    func plant(_ kind: PlantKind, plot i: Int, forcedVariant: Int? = nil) {
        guard plots.indices.contains(i), plots[i].isEmpty else { return }
        let growing = GrowingPlant(kind: kind, growth: 0.08, variant: forcedVariant ?? GardenSim.rollVariant())
        plots[i].stage = .growing(growing)
        plots[i].fillUntil = time + 0.65
        plots[i].dry = 0
        plots[i].digWork = 0
        plots[i].pop = 0
        plots[i].popV = 8
        plots[i].moundPopV += 9
        GardenSound.shared.play(.pat, volume: 0.8)
        let x = GGeo.plotX[i]
        for _ in 0..<8 {
            particles.append(GParticle(kind: .dust, p: CGPoint(x: x + CGFloat.random(in: -26...26), y: surface(x) - 4),
                                       v: CGVector(dx: CGFloat.random(in: -70...70), dy: CGFloat.random(in: -70 ... -20)),
                                       life: 0.85, size: CGFloat.random(in: 10...17), color: GRGB(0xB58C66)))
        }
        sparkle(at: CGPoint(x: x, y: surface(x) - 20), count: 7)
        markUIStateDirty()
    }

    @discardableResult
    func tossSeed(_ kind: PlantKind, from start: CGPoint) -> Int? {
        let reserved = Set(flyers.compactMap { flyer -> Int? in
            if case .flyingSeed(_, let idx) = flyer.kind { return idx }
            return nil
        })
        let open = plots.indices.filter { plots[$0].isEmpty && !reserved.contains($0) }
        guard let targetIdx = open.min(by: { abs(GGeo.plotX[$0] - start.x) < abs(GGeo.plotX[$1] - start.x) }) else {
            for i in plots.indices { plots[i].popV += 2.5 }
            Sound.shared.play(.boing, volume: 0.3)
            return nil
        }
        let x = GGeo.plotX[targetIdx]
        let dest = CGPoint(x: x, y: surface(x) - 4)
        let dur = 0.34
        flyers.append(GFlyer(kind: .flyingSeed(kind, targetIdx),
                             p0: start,
                             v0: GFlyer.aim(from: start, to: dest, dur: dur),
                             start: time, dur: dur, spin: 8, toBasket: false))
        GardenSound.shared.play(.seeds, volume: 0.7)
        enqueueEffect(.haptic)
        return targetIdx
    }

    func sowRow(_ kind: PlantKind, from a: CGPoint, to b: CGPoint) {
        for i in plots.indices where plots[i].isEmpty {
            let x = GGeo.plotX[i]
            let dx = b.x - a.x
            let t = abs(dx) < 1 ? 1 : min(1, max(0, (x - a.x) / dx))
            let px = a.x + dx * t, py = a.y + (b.y - a.y) * t
            guard abs(px - x) < 62, abs(py - surface(x)) < 90 else { continue }
            plant(kind, plot: i)
            waterBed(at: x, amount: 0.28)
        }
    }

    private func waterBed(at x: CGFloat, amount: CGFloat) {
        for offset in -5...5 {
            water(at: x + CGFloat(offset) * GGeo.col, amount: amount)
        }
    }

    func waterPlant(at point: CGPoint) {
        guard GGeo.inBed(point.x) else { return }
        guard let plot = plots.indices.min(by: { abs(GGeo.plotX[$0] - point.x) < abs(GGeo.plotX[$1] - point.x) }) else { return }
        let x = GGeo.plotX[plot]
        let ground = surface(x)
        let top = head(plot: plot)?.y ?? ground
        guard point.y >= top - 90, point.y <= ground + 90 else { return }
        waterBed(at: x, amount: 0.65)
        plots[plot].popV += 4
        plots[plot].moundPopV += 4
        for _ in 0..<14 {
            particles.append(GParticle(kind: .water, p: CGPoint(x: x + CGFloat.random(in: -22...22), y: top - 52),
                                       v: CGVector(dx: CGFloat.random(in: -20...20), dy: 180), life: 1.8, size: 3.4, color: GRGB(0x8AD8FF)))
        }
        GardenSound.shared.play(.splash, volume: 0.6, gap: 0.1)
        fulfillRainVisitors()
    }

    func uproot(_ i: Int) {
        guard plots.indices.contains(i), let p = plots[i].plant else { return }
        plots[i].stage = .empty(surprise: BuriedSurprise.random(), surpriseReady: false)
        plots[i].surpriseResetAt = time + 4.0
        plots[i].digWork = 0
        plots[i].pull = 0
        plots[i].dry = 0
        plots[i].held = false
        if case .carrying(let donor, _, _, _) = pollination, donor == i {
            pollination = .idle
        }
        let base = CGPoint(x: GGeo.plotX[i], y: surface(GGeo.plotX[i]))
        let side: CGFloat = base.x < 440 ? -1 : 1
        flyers.append(GFlyer(kind: .uprooted(p), p0: base, v0: CGVector(dx: side * 240, dy: -660), start: time, dur: 1.3,
                             spin: side * 5, toBasket: false))
        GardenSound.shared.play(.pluck)
        burstSoil(at: base, n: 8)
        markUIStateDirty()
    }

    // MARK: Manual Cross-Breeding Magic Hybrids

    func pollinatable(_ i: Int) -> Bool {
        guard plots.indices.contains(i), case .ripe(let ripe) = plots[i].stage else { return false }
        return ripe.hybrid == nil
    }

    func hasPollenPartner(for i: Int) -> Bool {
        guard pollinatable(i), case .ripe(let ripe) = plots[i].stage else { return false }
        return plots.indices.contains { j in
            guard j != i, pollinatable(j), case .ripe(let other) = plots[j].stage else { return false }
            return other.kind != ripe.kind
        }
    }

    func pollenAnchor(plot i: Int) -> CGPoint? {
        guard plots.indices.contains(i), let p = plots[i].plant else { return nil }
        let x = GGeo.plotX[i]
        let baseY = surface(x)
        if p.kind == .pumpkin {
            return CGPoint(x: x + 12, y: baseY - 52)
        }
        return head(plot: i) ?? CGPoint(x: x, y: baseY - 56)
    }

    func pollenOrbPos(plot i: Int) -> CGPoint? {
        guard hasPollenPartner(for: i), let p = plots[i].plant else { return nil }
        let x = GGeo.plotX[i]
        let baseY = surface(x)
        if p.kind == .pumpkin {
            return CGPoint(x: x + 28, y: baseY - 92)
        }
        let anchor = head(plot: i) ?? CGPoint(x: x, y: baseY - 56)
        return CGPoint(x: anchor.x + 22, y: max(116, anchor.y - 24))
    }

    private func dispatchVisualBeeFlourish(fromPlot a: Int, ontoPlot b: Int) {
        let start = pollenAnchor(plot: a) ?? CGPoint(x: GGeo.plotX[a], y: GGeo.soilY - 80)
        let dest = pollenAnchor(plot: b) ?? CGPoint(x: GGeo.plotX[b], y: GGeo.soilY - 80)
        for k in 0..<8 {
            let u = CGFloat(k) / 7
            let px = start.x + (dest.x - start.x) * u
            let py = start.y + (dest.y - start.y) * u - sin(u * .pi) * 34
            particles.append(GParticle(
                kind: .pollen,
                p: CGPoint(x: px, y: py),
                v: CGVector(dx: CGFloat.random(in: -18...18), dy: CGFloat.random(in: -22...8)),
                life: 0.75,
                size: CGFloat.random(in: 4...6.5),
                color: GRGB(0xFFE05C)
            ))
        }
        var activeBee = bee ?? GBee(p: start, v: .zero, target: dest)
        activeBee.p = start
        activeBee.target = dest
        activeBee.perch = nil
        activeBee.leaving = false
        activeBee.perchUntil = -Double(b) - 1
        activeBee.flourishUntil = time + 1.4
        bee = activeBee
    }

    @discardableResult
    func crossBreed(fromPlot a: Int, ontoPlot b: Int) -> HybridKind? {
        guard a != b, plots.indices.contains(a), plots.indices.contains(b) else { return nil }
        guard case .ripe(let donor) = plots[a].stage else { return nil }
        return crossBreed(from: donor.kind, ontoPlot: b)
    }

    @discardableResult
    func crossBreed(from donor: PlantKind, ontoPlot b: Int) -> HybridKind? {
        guard plots.indices.contains(b), case .ripe(var target) = plots[b].stage, target.hybrid == nil else { return nil }
        guard let hybrid = HybridKind.cross(from: donor, onto: target.kind) else { return nil }
        target.hybrid = hybrid
        target.yieldLeft = hybrid.crop
        plots[b].stage = .ripe(target)
        plots[b].popV += 14
        plots[b].moundPopV += 8

        let pos = pollenAnchor(plot: b) ?? CGPoint(x: GGeo.plotX[b], y: surface(GGeo.plotX[b]) - 60)
        sparkle(at: pos, count: 18)
        petals(at: pos, color: hybrid.primaryColor, n: 8)
        GardenSound.shared.play(.grow, volume: 0.9)
        Sound.shared.play(.sparkle, volume: 0.75)
        enqueueEffect(.haptic)

        if !discoveredHybrids.contains(hybrid) {
            discoveredHybrids.append(hybrid)
            lastDiscoveredHybrid = hybrid
            hybridDiscoveryAt = time
            earnCoins(5, from: pos)
            confettiBurst(at: pos, count: 24)
            Sound.shared.play(.fanfare, volume: 0.65)
            enqueueEffect(.save)
        }
        markUIStateDirty()
        return hybrid
    }

    func starlightChime(at p: CGPoint) {
        let notes: [SFX] = [.note1, .note2, .note3, .note4]
        Sound.shared.play(notes[chimeIndex % notes.count], volume: 0.6)
        chimeIndex += 1
        sparkle(at: p, count: 7)
    }

    // MARK: Critter Picnic & 5-Stage Storybook Treehouse

    func isOverPicnic(_ p: CGPoint) -> Bool {
        abs(p.x - GGeo.picnic.x) < GGeo.picnicSize.width * 0.68
            && abs(p.y - GGeo.picnic.y) < GGeo.picnicSize.height * 0.95
    }

    @discardableResult
    func servePicnicSnack(at dropPoint: CGPoint? = nil) -> Bool {
        guard let idx = inventory.lastIndex(where: \.isEdibleProduce) else { return false }
        let item = inventory.remove(at: idx)
        let plateOffsets: [CGPoint] = [
            CGPoint(x: -42, y: -4),
            CGPoint(x: 2, y: 6),
            CGPoint(x: 44, y: -6),
        ]
        let slot = picnicSnacks.count % plateOffsets.count
        let offset = plateOffsets[slot]
        let snackPos = CGPoint(x: GGeo.picnic.x + offset.x, y: GGeo.picnic.y + offset.y)
        if picnicSnacks.count >= GardenSim.maxPicnicSnacks {
            picnicSnacks.removeFirst()
        }
        picnicSnacks.append(PicnicSnack(item: item, pos: snackPos, placedAt: time))
        picnicBounceV += 10
        if dropPoint == nil {
            let start = CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 26)
            let dur = 0.45
            flyers.append(GFlyer(kind: .picnicSnack(item), p0: start,
                                 v0: GFlyer.aim(from: start, to: snackPos, dur: dur),
                                 start: time, dur: dur, spin: 5, toBasket: false, toPicnic: true))
        }
        GardenSound.shared.play(.basket, volume: 0.7)
        Sound.shared.play(.pop, volume: 0.55)
        enqueueEffect(.haptic)

        let species: [GVisitorKind] = [.bunny, .hedgehog, .frog, .bluebird]
        let kind = species[picnicSpeciesCursor % species.count]
        picnicSpeciesCursor += 1
        let seatX = max(GGeo.picnic.x - 56, min(GGeo.picnic.x + 56, snackPos.x + (slot == 0 ? 18 : -18)))
        let seat = CGPoint(x: seatX, y: GGeo.picnic.y + 8)
        let startPt = CGPoint(x: 1068, y: kind == .bluebird ? 540 : GGeo.picnic.y + 8)
        let critter = PicnicCritter(
            id: nextPicnicCritterID,
            kind: kind,
            p: startPt,
            target: seat,
            state: .hoppingIn,
            stateAt: time,
            facing: -1,
            snackItem: item
        )
        nextPicnicCritterID += 1
        if picnicCritters.count >= 3 { picnicCritters.removeFirst() }
        picnicCritters.append(critter)
        if kind == .bluebird { GardenSound.shared.play(.flutter, volume: 0.55) }

        earnCoins(3, from: GGeo.picnic)
        picnicFeedCount += 1
        let targetStage = min(GardenSim.maxTreehouseStage, (farmstandServedCount + picnicFeedCount) / 2)
        if targetStage > treehouseStage {
            treehouseStage = targetStage
            treehouseUpgradeAt = time
            treehouseBounceV += 14
            let thCenter = CGPoint(x: GGeo.treehouse.x, y: GGeo.treehouse.y - 125)
            sparkle(at: thCenter, count: 22)
            confettiBurst(at: thCenter, count: 24)
            Sound.shared.play(.fanfare, volume: 0.65)
            Sound.shared.play(.sparkle, volume: 0.75)
        }
        enqueueEffect(.save)
        markUIStateDirty()
        return true
    }

    private func stepPicnic(_ dt: CGFloat) {
        for i in picnicCritters.indices.reversed() {
            var c = picnicCritters[i]
            switch c.state {
            case .hoppingIn, .hoppingOut:
                let dx = c.target.x - c.p.x
                let dy = c.target.y - c.p.y
                let d = hypot(dx, dy)
                let speed: CGFloat = max(135, c.kind.speed * 1.1) * dt
                if d <= speed {
                    c.p = c.target
                    if c.state == .hoppingOut {
                        picnicCritters.remove(at: i)
                        continue
                    }
                    c.state = .munching
                    c.stateAt = time
                    c.nextHeartAt = time + 0.3
                    c.facing = c.p.x >= GGeo.picnic.x ? -1 : 1
                    playVisitorSound(c.kind)
                } else {
                    c.p.x += dx / d * speed
                    c.p.y += dy / d * speed
                    c.walk += speed
                    if abs(dx) > 2 { c.facing = dx > 0 ? 1 : -1 }
                }
            case .munching:
                if time >= c.nextHeartAt {
                    c.nextHeartAt = time + 0.95
                    heartBurst(at: CGPoint(x: c.p.x, y: c.p.y - 38), count: 2)
                }
                if time - c.stateAt >= 3.4 {
                    if let sIdx = picnicSnacks.firstIndex(where: { $0.item.id == c.snackItem.id }) {
                        let sPos = picnicSnacks[sIdx].pos
                        picnicSnacks.remove(at: sIdx)
                        sparkle(at: sPos, count: 7)
                    }
                    c.state = .happy
                    c.stateAt = time
                    heartBurst(at: CGPoint(x: c.p.x, y: c.p.y - 44), count: 4)
                    playVisitorSound(c.kind)
                }
            case .happy:
                let linger = c.wearingCrown ? 6.5 : 2.6
                if time - c.stateAt >= linger {
                    c.state = .hoppingOut
                    c.stateAt = time
                    c.target = CGPoint(x: 1090, y: c.kind == .bluebird ? 520 : GGeo.picnic.y + 8)
                    c.facing = 1
                }
            }
            picnicCritters[i] = c
        }
    }

    func pokeTreehouse() {
        treehousePoke = time
        treehouseBounceV += 11
        let center = CGPoint(x: GGeo.treehouse.x, y: GGeo.treehouse.y - 125)
        sparkle(at: center, count: 10)
        if treehouseStage >= 4 {
            starlightChime(at: CGPoint(x: GGeo.treehouse.x + 38, y: GGeo.treehouse.y - 96))
        } else {
            GardenSound.shared.play(.rustle, volume: 0.7)
        }
        if treehouseStage >= 5 {
            GardenSound.shared.play(.chirp, volume: 0.85)
            heartBurst(at: CGPoint(x: GGeo.treehouse.x, y: GGeo.treehouse.y - 146), count: 5)
        }
        enqueueEffect(.haptic)
        let dropCol: GRGB
        let dropKind: GPart
        switch season {
        case .spring: dropCol = GRGB(0xFFB3D2); dropKind = .petal
        case .summer: dropCol = GRGB(0x78C456); dropKind = .leaf
        case .autumn: dropCol = GRGB(0xF08B36); dropKind = .leaf
        case .winter: dropCol = GRGB(0xE8F7FF); dropKind = .snow
        }
        for _ in 0..<7 {
            particles.append(GParticle(kind: dropKind,
                                       p: CGPoint(x: GGeo.treehouse.x + CGFloat.random(in: -70...70), y: GGeo.treehouse.y - CGFloat.random(in: 120...190)),
                                       v: CGVector(dx: CGFloat.random(in: -55...55), dy: CGFloat.random(in: 15...60)),
                                       life: 3.4, size: dropKind == .snow ? 5.5 : 9, color: dropCol,
                                       rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -4...4)))
        }
    }

    // MARK: Night Firefly Lantern Jar

    @discardableResult
    func catchFirefly(at p: CGPoint) -> Bool {
        guard night > 0.35 || weather == .night else { return false }
        guard let idx = fireflies.indices.min(by: { hypot(fireflies[$0].p.x - p.x, fireflies[$0].p.y - p.y) < hypot(fireflies[$1].p.x - p.x, fireflies[$1].p.y - p.y) }) else {
            return false
        }
        let f = fireflies[idx]
        guard hypot(f.p.x - p.x, f.p.y - p.y) < 56 else { return false }
        fireflies.remove(at: idx)
        caughtFireflies = min(GardenSim.maxCaughtFireflies, caughtFireflies + 1)
        let dest = CGPoint(x: GGeo.fireflyJar.x, y: GGeo.fireflyJar.y - 22)
        let dur = 0.42
        flyers.append(GFlyer(kind: .caughtFirefly, p0: f.p,
                             v0: GFlyer.aim(from: f.p, to: dest, dur: dur),
                             start: time, dur: dur, spin: 0, toBasket: false, toJar: true))
        sparkle(at: f.p, count: 6)
        let notes: [SFX] = [.note1, .note2, .note3, .note4]
        Sound.shared.play(notes[(caughtFireflies - 1) % notes.count], volume: 0.65)
        enqueueEffect(.haptic)
        enqueueEffect(.save)
        return true
    }

    @discardableResult
    func releaseFireflyJar() -> Int {
        guard caughtFireflies > 0 else { return 0 }
        let count = caughtFireflies
        caughtFireflies = 0
        jarBounceV += 14
        let origin = CGPoint(x: GGeo.fireflyJar.x, y: GGeo.fireflyJar.y - 34)
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(max(1, count)) * 2 * .pi - .pi / 2
            let speed = CGFloat.random(in: 120...210)
            fireflies.append(GFirefly(
                p: origin,
                v: CGVector(dx: cos(angle) * speed - 40, dy: sin(angle) * speed - 120),
                phase: CGFloat(i) * 0.7
            ))
        }
        sparkle(at: origin, count: 16)
        Sound.shared.play(.sparkle, volume: 0.7)
        Sound.shared.play(.ding, volume: 0.5)
        enqueueEffect(.haptic)
        enqueueEffect(.save)
        return count
    }

    // MARK: Wearable Flower Crowns

    @discardableResult
    func weaveFlowerCrown() -> Bool {
        let flowerIndices = inventory.indices.filter { inventory[$0].isFlower }
        guard flowerIndices.count >= 3 else { return false }
        let usedIndices = Array(flowerIndices.suffix(3))
        var used: [HarvestItem] = []
        for idx in usedIndices.reversed() {
            used.insert(inventory.remove(at: idx), at: 0)
        }
        var colors: [GRGB] = []
        for item in used {
            colors.append(item.source.displayColor)
        }
        for item in used.prefix(2) {
            if case .hybrid(let h, _) = item.source {
                colors.append(h.accentColor)
            } else {
                colors.append(item.source.displayColor.shade(0.18))
            }
        }
        craftedCrownColors = colors
        vaseBounceV += 14
        crownBounceV += 16
        sparkle(at: CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 72), count: 14)
        sparkle(at: CGPoint(x: GGeo.flowerCrownSpot.x, y: GGeo.flowerCrownSpot.y - 14), count: 10)
        Sound.shared.play(.sparkle, volume: 0.65)
        Sound.shared.play(.ding, volume: 0.6)
        enqueueEffect(.haptic)
        enqueueEffect(.save)
        markUIStateDirty()
        return true
    }

    @discardableResult
    func placeCrownOnVisitor(at i: Int) -> Bool {
        guard hasCraftedCrown, visitors.indices.contains(i) else { return false }
        visitors[i].wearingCrown = true
        visitors[i].crownColors = craftedCrownColors
        visitors[i].poked = time
        visitors[i].stayUntil = max(visitors[i].stayUntil, time + 10)
        craftedCrownColors = []
        let pos = visitors[i].pos
        let origin = CGPoint(x: pos.x, y: pos.y - visitors[i].kind.stickerHeight * 0.5)
        playVisitorSound(visitors[i].kind)
        Sound.shared.play(.cheer, volume: 0.55)
        Sound.shared.play(.sparkle, volume: 0.7)
        enqueueEffect(.haptic)
        heartBurst(at: origin, count: 6)
        confettiBurst(at: origin, count: 20)
        earnCoins(3, from: pos)
        return true
    }

    @discardableResult
    func placeCrownOnPicnicCritter(at i: Int) -> Bool {
        guard hasCraftedCrown, picnicCritters.indices.contains(i) else { return false }
        picnicCritters[i].wearingCrown = true
        picnicCritters[i].crownColors = craftedCrownColors
        picnicCritters[i].poked = time
        if picnicCritters[i].state == .happy {
            picnicCritters[i].stateAt = time
        }
        craftedCrownColors = []
        let pos = picnicCritters[i].p
        let origin = CGPoint(x: pos.x, y: pos.y - 40)
        playVisitorSound(picnicCritters[i].kind)
        Sound.shared.play(.cheer, volume: 0.55)
        Sound.shared.play(.sparkle, volume: 0.7)
        enqueueEffect(.haptic)
        heartBurst(at: origin, count: 6)
        confettiBurst(at: origin, count: 20)
        earnCoins(3, from: pos)
        return true
    }

    @discardableResult
    func placeCrown(at p: CGPoint) -> Bool {
        guard hasCraftedCrown else { return false }
        if let pi = picnicCritterHit(p, radius: 85) {
            return placeCrownOnPicnicCritter(at: pi)
        }
        if let vi = visitorHit(p) {
            return placeCrownOnVisitor(at: vi)
        }
        if let vi = visitors.indices.min(by: { hypot(visitors[$0].p.x - p.x, visitors[$0].p.y - p.y) < hypot(visitors[$1].p.x - p.x, visitors[$1].p.y - p.y) }),
           hypot(visitors[vi].p.x - p.x, visitors[vi].p.y - p.y) < 88 {
            return placeCrownOnVisitor(at: vi)
        }
        return false
    }

    @discardableResult
    func placeCrownOnNearestCritter() -> Bool {
        guard hasCraftedCrown else { return false }
        if let pi = picnicCritters.indices.first(where: { !picnicCritters[$0].wearingCrown }) ?? picnicCritters.indices.first {
            return placeCrownOnPicnicCritter(at: pi)
        }
        if let vi = visitors.indices.first(where: { !visitors[$0].wearingCrown }) ?? visitors.indices.first {
            return placeCrownOnVisitor(at: vi)
        }
        return false
    }

    private func picnicCritterHit(_ p: CGPoint, radius: CGFloat = 54) -> Int? {
        for i in picnicCritters.indices {
            let c = picnicCritters[i]
            let mid = CGPoint(x: c.p.x, y: c.p.y - 30)
            if hypot(mid.x - p.x, mid.y - p.y) < radius { return i }
        }
        return nil
    }

    // MARK: Soil

    private func stepSoil(_ dt: CGFloat) {
        let n = GGeo.columns
        for _ in 0..<2 {
            for i in 0..<(n - 1) {
                let d = h[i + 1] - h[i]
                let hold = 4.5 + 2.5 * min(wet[i], wet[i + 1])
                let ad = abs(d)
                if ad > hold {
                    let t = (ad - hold) * 0.25
                    if d > 0 { h[i] += t; h[i + 1] -= t } else { h[i] -= t; h[i + 1] += t }
                }
            }
        }
        for i in plots.indices where time < plots[i].fillUntil {
            let c = GGeo.column(GGeo.plotX[i])
            let lo = max(1, c - 14)
            let hi = min(n - 2, c + 14)
            var next = h
            let k = min(0.45, 14 * dt)
            for j in lo...hi { next[j] = h[j] + k * ((h[j - 1] + h[j + 1]) * 0.5 - h[j]) }
            h = next
            if plots[i].fillUntil - time < Double(dt) * 1.5 {
                for j in max(0, c - 6)...min(n - 1, c + 6) where h[j] > GGeo.soilY + 2 { h[j] = GGeo.soilY + 2 }
            }
        }
        for i in 0..<n { h[i] = max(GGeo.soilY - 22, min(GGeo.soilY + GGeo.maxDepth, h[i])) }

        let sunny = (1 - cloud) * (1 - night)
        let dry = (0.004 + 0.012 * sunny) * (1 - rain)
        var w = wet
        let D = min(0.4, 5 * dt)
        for i in 0..<n {
            let l = wet[max(0, i - 1)]
            let r = wet[min(n - 1, i + 1)]
            w[i] = wet[i] + D * (l + r - 2 * wet[i]) - dry * dt
            w[i] = max(0, min(1.15, w[i]))
        }
        wet = w
    }

    func water(at x: CGFloat, amount: CGFloat) {
        guard GGeo.inBed(x) else { return }
        let c = max(0, min(wet.count - 1, GGeo.column(x)))
        wet[c] = min(1.15, wet[c] + amount)
        if c > 0 { wet[c - 1] = min(1.15, wet[c - 1] + amount * 0.5) }
        if c < GGeo.columns - 1 { wet[c + 1] = min(1.15, wet[c + 1] + amount * 0.5) }

        for i in plots.indices where abs(GGeo.plotX[i] - x) < 48 {
            if case .ripe(var ripe) = plots[i].stage, ripe.harvestMechanic == .waterPuff, !ripe.isGiant {
                ripe.waterPuffProgress += amount * 0.5
                if ripe.waterPuffProgress >= 0.45 {
                    ripe.isGiant = true
                    ripe.waterPuffProgress = 0
                    plots[i].stage = .ripe(ripe)
                    plots[i].popV += 14
                    let center = CGPoint(x: GGeo.plotX[i] + 12, y: surface(GGeo.plotX[i]) - 42)
                    sparkle(at: center, count: 16)
                    Sound.shared.play(.boing, volume: 0.75)
                    Sound.shared.play(.sparkle, volume: 0.55)
                    GardenSound.shared.play(.grow, volume: 0.9)
                    discover(.giantPumpkin, at: center)
                } else {
                    plots[i].stage = .ripe(ripe)
                }
            }
        }
    }

    // MARK: Plants (Species-Distinct Growth & Finite Lifecycle)

    static let stages: [Double] = [0.25, 0.5, 0.75, 1.0]

    func head(plot i: Int) -> CGPoint? {
        guard plots.indices.contains(i), let p = plots[i].plant else { return nil }
        let base = CGPoint(x: GGeo.plotX[i], y: surface(GGeo.plotX[i]))
        let hgt = GardenPlants.stemHeight(p)
        let b = plots[i].bend
        return CGPoint(x: base.x + sin(b) * hgt, y: base.y - cos(b) * hgt)
    }

    func bloomed(_ i: Int) -> Bool {
        guard plots.indices.contains(i) else { return false }
        switch plots[i].stage {
        case .ripe(let r): return r.effectiveIsFlower
        case .growing(let g): return g.effectiveIsFlower && g.growth >= 0.95
        case .empty: return false
        }
    }

    private func stepPlants(_ dt: CGFloat) {
        let t = CGFloat(time)
        for i in plots.indices {
            plots[i].moundPopV += (-160 * plots[i].moundPop - 11 * plots[i].moundPopV) * dt
            plots[i].moundPop += plots[i].moundPopV * dt
            switch plots[i].stage {
            case .empty(_, let ready):
                plots[i].bend *= 0.9
                if !ready && time >= plots[i].surpriseResetAt {
                    plots[i].stage = .empty(surprise: BuriedSurprise.random(), surpriseReady: true)
                }
                continue
            case .growing(var growing):
                let x = GGeo.plotX[i]
                let moist = wetAt(x, span: 5)
                let weedy = weeds.contains { abs($0.x - x) < 74 && $0.growth > 0.3 }
                plots[i].sad = weedy
                if moist > 0.1 {
                    var rate = 1.0 / max(1.0, growing.growthDuration)
                    if weather == .sun { rate *= 1.15 }
                    if weather == .night { rate *= 0.85 }
                    if weedy { rate *= 0.65 }
                    let before = growing.growth
                    let nextGrowth = min(1.0, before + rate * Double(dt))
                    plots[i].dry = 0
                    let c = GGeo.column(x)
                    for j in max(0, c - 6)...min(GGeo.columns - 1, c + 6) {
                        wet[j] = max(0, wet[j] - 0.014 * dt)
                    }
                    if nextGrowth >= 1.0 {
                        let ripe = RipePlant(
                            kind: growing.kind,
                            variant: growing.variant,
                            yieldLeft: growing.species.spec.yieldCount,
                            isGiant: false,
                            hybrid: growing.hybrid,
                            rainbowCharged: false
                        )
                        plots[i].stage = .ripe(ripe)
                        plots[i].popV += 8
                        let preview = Plant(kind: ripe.kind, growth: 1.0, left: ripe.yieldLeft, variant: ripe.variant, hybrid: ripe.hybrid)
                        let top = CGPoint(x: x, y: surface(x) - GardenPlants.stemHeight(preview) - 10)
                        sparkle(at: top, count: 14)
                        GardenSound.shared.play(.grow, volume: 0.9)
                        Sound.shared.play(.sparkle, volume: 0.45)
                        if ripe.isSpecial && ripe.kind != .pumpkin {
                            discover(.special(ripe.kind), at: top)
                        }
                        markUIStateDirty()
                    } else {
                        growing.growth = nextGrowth
                        plots[i].stage = .growing(growing)
                        for s in GardenSim.stages where s < 1 && before < s && nextGrowth >= s {
                            plots[i].popV += 8
                            let preview = Plant(kind: growing.kind, growth: nextGrowth, variant: growing.variant, hybrid: growing.hybrid)
                            let top = CGPoint(x: x, y: surface(x) - GardenPlants.stemHeight(preview) - 10)
                            sparkle(at: top, count: 5)
                            GardenSound.shared.play(.grow, volume: 0.5)
                        }
                    }
                } else {
                    plots[i].dry += dt
                }
            case .ripe:
                let x = GGeo.plotX[i]
                plots[i].sad = weeds.contains { abs($0.x - x) < 74 && $0.growth > 0.3 }
                plots[i].dry = 0
            }

            guard let p = plots[i].plant else { continue }
            let hgt = max(30, GardenPlants.stemHeight(p))
            let k = 30 + 2400 / hgt
            let droop: CGFloat = (plots[i].dry > 1.5 ? 0.14 : 0) + (plots[i].sad ? 0.05 : 0)
            let rest = windNow * 0.34 + sin(t * 1.7 + CGFloat(i)) * 0.025 + droop * (i % 2 == 0 ? 1 : -1)
            var f = (rest - plots[i].bend) * k - plots[i].bendV * 3.4
            if rain > 0.2 { f += CGFloat.random(in: -1...1) * rain * 8 }
            plots[i].bendV += f * dt
            plots[i].bend += plots[i].bendV * dt
            plots[i].bend = max(-1.0, min(1.0, plots[i].bend))
            plots[i].popV += (-110 * plots[i].pop - 9 * plots[i].popV) * dt
            plots[i].pop += plots[i].popV * dt
            if !plots[i].held {
                plots[i].pullV += (-150 * plots[i].pull - 13 * plots[i].pullV) * dt
                plots[i].pull += plots[i].pullV * dt
            }
        }
    }

    // MARK: Weeds

    private func stepWeeds(_ dt: CGFloat) {
        let t = CGFloat(time)
        for i in weeds.indices {
            weeds[i].growth = min(1, weeds[i].growth + dt / 14)
            let rest = windNow * 0.4 + sin(t * 2.1 + CGFloat(weeds[i].seed)) * 0.03
            weeds[i].bendV += ((rest - weeds[i].bend) * 70 - weeds[i].bendV * 4) * dt
            weeds[i].bend += weeds[i].bendV * dt
            if !weeds[i].held {
                weeds[i].pullV += (-170 * weeds[i].pull - 12 * weeds[i].pullV) * dt
                weeds[i].pull += weeds[i].pullV * dt
            }
        }
        if time > nextWeed {
            nextWeed = time + Double.random(in: 22...36)
            guard weeds.count < 3 else { return }
            for _ in 0..<12 {
                let x = CGFloat.random(in: (GGeo.bedLeft + 24)...(GGeo.bedRight - 24))
                let nearPlot = GGeo.plotX.contains { abs($0 - x) < 34 }
                let nearWeed = weeds.contains { abs($0.x - x) < 52 }
                if !nearPlot && !nearWeed {
                    weeds.append(GWeed(x: x, growth: 0.05, seed: Int.random(in: 0..<1000)))
                    GardenSound.shared.play(.grow, volume: 0.25)
                    break
                }
            }
        }
    }

    private func popWeed(_ i: Int, v: CGVector) {
        let w = weeds.remove(at: i)
        let base = CGPoint(x: w.x, y: surface(w.x))
        flyers.append(GFlyer(kind: .weed(w.seed), p0: CGPoint(x: base.x, y: base.y - 10), v0: v, start: time, dur: 1.5,
                             spin: v.dx >= 0 ? 6 : -6, toBasket: false))
        GardenSound.shared.play(.pluck)
        enqueueEffect(.haptic)
        burstSoil(at: base, n: 7)
        let c = GGeo.column(w.x)
        for j in max(0, c - 2)...min(GGeo.columns - 1, c + 2) { h[j] += 2 }
        sparkle(at: CGPoint(x: base.x, y: base.y - 26), count: 7)
        markUIStateDirty()
    }

    private func burstSoil(at p: CGPoint, n: Int) {
        let browns = [GRGB(0x8A5A36), GRGB(0x7A4E2E), GRGB(0x9C6A42)]
        for k in 0..<n {
            particles.append(GParticle(kind: .clod, p: CGPoint(x: p.x + CGFloat.random(in: -10...10), y: p.y - 4),
                                       v: CGVector(dx: CGFloat.random(in: -210...210), dy: CGFloat.random(in: -480 ... -200)),
                                       life: 3.5, size: CGFloat.random(in: 3...6), color: browns[k % 3], rot: CGFloat.random(in: 0...6),
                                       spin: CGFloat.random(in: -9...9), mass: 0))
        }
    }

    // MARK: Particles

    private func stepParticles(_ dt: CGFloat) {
        let g = GardenSim.gravity
        let vortexActive = vortexCenter != nil && time < vortexUntil
        var keep: [GParticle] = []
        keep.reserveCapacity(particles.count)
        for var q in particles {
            q.age += dt
            if q.age > q.life { continue }
            switch q.kind {
            case .water, .rain:
                q.v.dy += g * dt
                q.v.dx += windNow * (q.kind == .rain ? 40 : 30) * dt
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                if hitWater(&q) { continue }
            case .splash:
                q.v.dy += g * dt
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            case .clod, .seed:
                if q.resting {
                    if q.kind == .seed && q.age > q.life - 1 { q.size *= 0.98 }
                } else {
                    q.v.dy += g * dt
                    q.p.x += q.v.dx * dt
                    q.p.y += q.v.dy * dt
                    q.rot += q.spin * dt
                    if landSolid(&q) { continue }
                }
            case .petal, .leaf, .snow:
                let t = CGFloat(time)
                let flutter = sin(t * (q.kind == .snow ? 2.6 : 5.0) + q.rot * 3) * (q.kind == .snow ? 24 : 40)
                let push = windNow * (q.kind == .snow ? 140 : 280) + (q.kind == .snow ? 8 : 20)
                q.v.dx += (push - q.v.dx) * dt * 1.2
                q.v.dy += ((q.kind == .snow ? 44 : 70) + flutter - q.v.dy) * dt * 1.6
                if vortexActive, let vc = vortexCenter {
                    let dx = q.p.x - vc.x
                    let dy = q.p.y - vc.y
                    let dist = hypot(dx, dy)
                    if dist > 6 && dist < 170 {
                        let str = (1 - dist / 170) * 520 * dt
                        q.v.dx += (-dy / dist - dx / dist * 0.18) * str
                        q.v.dy += (dx / dist - 0.55) * str
                        q.spin += 4 * dt
                    }
                }
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
                let ground = GGeo.inBed(q.p.x) ? surface(q.p.x) : GGeo.lawnY + 20
                if q.p.y > ground {
                    q.p.y = ground
                    q.v = .zero
                    q.spin = 0
                }
                if q.p.x > 1160 { continue }
            case .confetti:
                q.v.dy += 280 * dt
                q.v.dx *= (1 - dt * 1.2)
                q.p.x += q.v.dx * dt + sin(CGFloat(time) * 8 + q.rot) * 28 * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
            case .pollen:
                q.v.dx *= (1 - dt * 2.2)
                q.v.dy += (-20 - q.v.dy) * dt * 1.6
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            case .sparkle:
                q.v.dy += 60 * dt
                q.v.dx *= (1 - dt * 2)
                q.v.dy *= (1 - dt * 2)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.rot += q.spin * dt
            case .heart:
                q.v.dx += sin(CGFloat(time) * 5 + q.rot) * 45 * dt
                q.v.dx *= (1 - dt * 1.6)
                q.v.dy += (-110 - q.v.dy) * dt * 1.8
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
            case .dust:
                q.v.dx *= (1 - dt * 3)
                q.v.dy *= (1 - dt * 3)
                q.p.x += q.v.dx * dt
                q.p.y += q.v.dy * dt
                q.size += dt * 14
            case .ripple:
                q.size += dt * 26
            }
            keep.append(q)
        }
        if keep.count > 1600 { keep.removeFirst(keep.count - 1600) }
        particles = keep
    }

    private func hitWater(_ q: inout GParticle) -> Bool {
        for i in decor.indices where decor[i].kind == .birdbath && !decor[i].held {
            let top = decor[i].y - 70
            if abs(q.p.x - decor[i].x) < 44 && q.p.y > top && q.p.y < top + 20 {
                decor[i].water = min(1, decor[i].water + (q.kind == .rain ? 0.005 : 0.012))
                if Int.random(in: 0..<5) == 0 { ripple(at: CGPoint(x: q.p.x, y: top + 4), small: true) }
                return true
            }
        }
        if q.kind == .water {
            for i in plots.indices {
                guard let p = plots[i].plant else { continue }
                let x = GGeo.plotX[i]
                let top = surface(x) - GardenPlants.stemHeight(p)
                if abs(q.p.x - x) < p.effectiveReach * 0.6 && q.p.y > top && q.p.y < top + 44 {
                    plots[i].bendV += q.v.dx * 0.0006 + CGFloat.random(in: -0.02...0.02)
                }
            }
        }
        if GGeo.inBed(q.p.x) {
            let s = surface(q.p.x)
            if q.p.y >= s {
                water(at: q.p.x, amount: q.kind == .rain ? 0.032 : 0.015)
                let c = GGeo.column(q.p.x)
                let puddle = c >= 0 && c < wet.count && wet[c] > 0.85
                if puddle && Int.random(in: 0..<(q.kind == .rain ? 6 : 3)) == 0 {
                    ripple(at: CGPoint(x: q.p.x, y: s - 1), small: q.kind == .rain)
                }
                splash(at: CGPoint(x: q.p.x, y: s - 1), v: q.v, n: q.kind == .rain ? (Int.random(in: 0..<3) == 0 ? 1 : 0) : Int.random(in: 0..<2))
                if q.kind == .water { fulfillRainVisitors() }
                return true
            }
        } else {
            let ground = q.kind == .rain ? q.groundY : GGeo.lawnY + 10
            if q.p.y >= ground {
                splash(at: CGPoint(x: q.p.x, y: ground), v: q.v, n: Int.random(in: 0..<3) == 0 ? 1 : 0)
                return true
            }
            if q.p.y > 900 { return true }
        }
        return false
    }

    private func splash(at p: CGPoint, v: CGVector, n: Int) {
        guard n > 0 else { return }
        for _ in 0..<n {
            particles.append(GParticle(kind: .splash, p: p,
                                       v: CGVector(dx: v.dx * 0.15 + CGFloat.random(in: -85...85), dy: -CGFloat.random(in: 100...240)),
                                       life: 0.35, size: CGFloat.random(in: 1.2...2.2), color: GRGB(0xD6EEFF)))
        }
    }

    private func ripple(at p: CGPoint, small: Bool) {
        particles.append(GParticle(kind: .ripple, p: p, v: .zero, life: small ? 0.45 : 0.7, size: small ? 2 : 3, color: GRGB(0xFFFFFF)))
    }

    private func landSolid(_ q: inout GParticle) -> Bool {
        let ground: CGFloat = GGeo.inBed(q.p.x) ? surface(q.p.x) - q.size * 0.4 : GGeo.lawnY + 4
        guard q.p.y >= ground else { return false }
        q.p.y = ground
        let speed = hypot(q.v.dx, q.v.dy)
        if q.kind == .seed, let k = q.seed, GGeo.inBed(q.p.x) {
            if let i = GGeo.plotX.indices.min(by: { abs(GGeo.plotX[$0] - q.p.x) < abs(GGeo.plotX[$1] - q.p.x) }),
               abs(GGeo.plotX[i] - q.p.x) < 48,
               plots[i].isEmpty {
                plant(k, plot: i)
                return true
            }
        }
        if speed > 240 && q.bounces < 2 {
            q.bounces += 1
            q.v.dy = -q.v.dy * 0.28
            q.v.dx *= 0.55
            q.spin *= 0.5
            if q.kind == .clod && speed > 500 && q.size > 5 {
                var crumb = q
                crumb.size *= 0.55
                crumb.mass *= 0.3
                q.mass *= 0.7
                crumb.v = CGVector(dx: -q.v.dx + CGFloat.random(in: -60...60), dy: q.v.dy * 0.8)
                particles.append(crumb)
            }
            return false
        }
        if q.kind == .clod {
            if GGeo.inBed(q.p.x) { deposit(q.mass, at: q.p.x) }
            if Int.random(in: 0..<2) == 0 {
                particles.append(GParticle(kind: .dust, p: q.p, v: CGVector(dx: 0, dy: -12), life: 0.5, size: q.size * 1.6, color: GRGB(0xA27A55)))
            }
            if GGeo.inBed(q.p.x) { return true }
            q.resting = true
            q.life = q.age + 1.1
            return false
        }
        q.resting = true
        q.v = .zero
        q.life = q.age + 1.2
        return false
    }

    func sparkle(at p: CGPoint, count: Int) {
        let colors = [GRGB(0xFFFFFF), GRGB(0xFFE38A), GRGB(0xFFB3CF)]
        for k in 0..<count {
            let a = CGFloat(k) / CGFloat(max(1, count)) * 2 * .pi + CGFloat.random(in: -0.3...0.3)
            let sp = CGFloat.random(in: 85...180)
            particles.append(GParticle(kind: .sparkle, p: p, v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 35), life: 0.8,
                                       size: CGFloat.random(in: 7...13), color: colors[k % 3], rot: 0,
                                       spin: CGFloat.random(in: -3...3)))
        }
    }

    func confettiBurst(at p: CGPoint, count: Int) {
        let colors = [GRGB(0xFF7CA8), GRGB(0xFFD54A), GRGB(0x7FE3B0), GRGB(0x88C8FF), GRGB(0xC9A8FF), GRGB(0xFFB085)]
        for k in 0..<count {
            let a = CGFloat(k) / CGFloat(max(1, count)) * 2 * .pi + CGFloat.random(in: -0.25...0.25)
            let sp = CGFloat.random(in: 120...280)
            particles.append(GParticle(kind: .confetti, p: p,
                                       v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 150),
                                       life: CGFloat.random(in: 1.4...2.2),
                                       size: CGFloat.random(in: 6...10),
                                       color: colors[k % colors.count],
                                       rot: CGFloat.random(in: 0...6),
                                       spin: CGFloat.random(in: -8...8)))
        }
    }

    func heartBurst(at p: CGPoint, count: Int) {
        let colors = [GRGB(0xFF7CA8), GRGB(0xFF9EC2), GRGB(0xFFB3CF)]
        for k in 0..<count {
            let dx = (CGFloat(k) - CGFloat(count - 1) / 2) * 28 + CGFloat.random(in: -14...14)
            particles.append(GParticle(kind: .heart,
                                       p: CGPoint(x: p.x + CGFloat.random(in: -14...14), y: p.y),
                                       v: CGVector(dx: dx, dy: CGFloat.random(in: -160 ... -90)),
                                       life: 1.15, size: CGFloat.random(in: 14...20),
                                       color: colors[k % colors.count], rot: CGFloat.random(in: 0...6)))
        }
    }

    // MARK: Flyers, Basket, Vase & Finite Harvest

    private func stepFlyers() {
        var keep: [GFlyer] = []
        for f in flyers {
            if time - f.start < f.dur {
                keep.append(f)
                continue
            }
            if case .flyingSeed(let kind, let idx) = f.kind {
                plant(kind, plot: idx)
            }
            if f.toBasket {
                basketBounceV += 9
                GardenSound.shared.play(.basket, volume: 0.9)
                Sound.shared.play(.ding, volume: 0.35)
                sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 30), count: 6)
            }
            if f.toVase {
                vaseBounceV += 10
                GardenSound.shared.play(.basket, volume: 0.7)
                Sound.shared.play(.ding, volume: 0.4)
                sparkle(at: CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 68), count: 8)
            }
            if f.toPicnic {
                picnicBounceV += 8
                sparkle(at: CGPoint(x: GGeo.picnic.x, y: GGeo.picnic.y - 12), count: 6)
            }
            if f.toJar {
                jarBounceV += 10
                sparkle(at: CGPoint(x: GGeo.fireflyJar.x, y: GGeo.fireflyJar.y - 26), count: 6)
            }
        }
        flyers = keep
    }

    private func stepProps(_ dt: CGFloat) {
        basketBounceV += (-160 * basketBounce - 10 * basketBounceV) * dt
        basketBounce += basketBounceV * dt
        vaseBounceV += (-170 * vaseBounce - 10 * vaseBounceV) * dt
        vaseBounce += vaseBounceV * dt
        picnicBounceV += (-160 * picnicBounce - 10 * picnicBounceV) * dt
        picnicBounce += picnicBounceV * dt
        jarBounceV += (-170 * jarBounce - 10 * jarBounceV) * dt
        jarBounce += jarBounceV * dt
        crownBounceV += (-170 * crownBounce - 10 * crownBounceV) * dt
        crownBounce += crownBounceV * dt
        treehouseBounceV += (-120 * treehouseBounce - 9 * treehouseBounceV) * dt
        treehouseBounce += treehouseBounceV * dt
        surprisePops.removeAll { time - $0.start >= $0.dur }
    }

    private func appendToInventory(_ item: HarvestItem) {
        inventory.append(item)
        let inUse = (activeDraft?.items.count ?? 0) + (draggedStockItem != nil ? 1 : 0)
        let maxShelf = max(0, GardenSim.maxInventory - inUse)
        if inventory.count > maxShelf {
            inventory.removeFirst(inventory.count - maxShelf)
        }
    }

    @discardableResult
    func harvest(_ i: Int) -> HarvestItem? {
        guard plots.indices.contains(i), case .ripe(var ripe) = plots[i].stage, ripe.yieldLeft >= 1 else { return nil }
        let x = GGeo.plotX[i]
        let base = CGPoint(x: x, y: surface(x))
        var from = head(plot: i) ?? base
        if ripe.hybrid == nil {
            switch ripe.kind {
            case .tomato:
                let spots = GardenPlants.tomatoSpots
                let s = spots[max(0, ripe.maxYield - ripe.yieldLeft) % spots.count]
                from = CGPoint(x: base.x + s.x, y: base.y - s.y)
            case .strawberry:
                let s = GardenPlants.berrySpots[max(0, ripe.maxYield - ripe.yieldLeft) % GardenPlants.berrySpots.count]
                from = CGPoint(x: base.x + s.x, y: base.y - s.y)
            case .pumpkin:
                from = CGPoint(x: base.x + 12, y: base.y - (ripe.isGiant ? 42 : 28))
            case .carrot:
                from = CGPoint(x: base.x, y: base.y + 8)
            default: break
            }
        } else if ripe.hybrid == .crystalPumpkin {
            from = CGPoint(x: base.x + 8, y: base.y - 36)
        }

        let source: HarvestSource
        if let hybrid = ripe.hybrid {
            source = .hybrid(kind: hybrid, isGiant: ripe.isGiant)
        } else {
            source = .plant(kind: ripe.kind, variant: ripe.variant, isGiant: ripe.isGiant)
        }
        let item = HarvestItem(source: source)
        appendToInventory(item)

        if item.isFlower {
            let target = CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 64)
            let dur = 0.62 + Double(abs(target.x - from.x)) / 2400
            flyers.append(GFlyer(kind: .flowerToVase(item), p0: from,
                                 v0: GFlyer.aim(from: from, to: target, dur: dur),
                                 start: time, dur: dur, spin: CGFloat.random(in: -5...5),
                                 toBasket: false, toVase: true))
            petals(at: from, color: item.source.displayColor, n: 8)
            if ripe.hybrid == .starlightRose { starlightChime(at: from) }
        } else {
            let target = CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 20)
            let dur = 0.65 + Double(abs(target.x - from.x)) / 2400
            flyers.append(GFlyer(kind: .crop(item), p0: from,
                                 v0: GFlyer.aim(from: from, to: target, dur: dur),
                                 start: time, dur: dur, spin: CGFloat.random(in: -6...6),
                                 toBasket: true, toVase: false))
            if ripe.isGiant || ripe.hybrid != nil {
                sparkle(at: from, count: 16)
                Sound.shared.play(.sparkle, volume: 0.6)
            }
        }

        if ripe.rainbowCharged {
            ripe.rainbowCharged = false
            earnCoins(2, from: from)
            sparkle(at: from, count: 14)
            Sound.shared.play(.sparkle, volume: 0.65)
        }

        GardenSound.shared.play(.pluck, volume: 0.8)
        enqueueEffect(.haptic)
        plots[i].bendV += CGFloat.random(in: -1.5...1.5)
        plots[i].popV += 5

        ripe.yieldLeft -= 1
        if ripe.yieldLeft <= 0 {
            let wasCarrot = ripe.kind == .carrot && ripe.hybrid == nil
            plots[i].stage = .empty(surprise: BuriedSurprise.random(), surpriseReady: true)
            plots[i].pull = 0
            plots[i].digWork = 0
            plots[i].dry = 0
            plots[i].held = false
            plots[i].moundPopV += 8
            burstSoil(at: base, n: 9)
            if wasCarrot {
                let c = GGeo.column(x)
                for j in max(0, c - 4)...min(GGeo.columns - 1, c + 4) { h[j] += 4 }
            }
            if case .carrying(let donor, _, _, _) = pollination, donor == i {
                pollination = .idle
            }
        } else {
            ripe.shakeProgress = 0
            plots[i].stage = .ripe(ripe)
        }

        enqueueEffect(.save)
        markUIStateDirty()
        return item
    }

    private func petals(at p: CGPoint, color: GRGB, n: Int) {
        for _ in 0..<n {
            particles.append(GParticle(kind: .petal, p: p, v: CGVector(dx: CGFloat.random(in: -80...80), dy: CGFloat.random(in: -120 ... -30)),
                                       life: 3.2, size: CGFloat.random(in: 6...9), color: color, rot: CGFloat.random(in: 0...6),
                                       spin: CGFloat.random(in: -5...5)))
        }
    }

    // MARK: Bare Hand (Bed Station)

    func plantHit(_ p: CGPoint) -> Int? {
        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            let top = base - GardenPlants.stemHeight(pl) - 38
            if abs(p.x - x) < pl.effectiveReach + 14 && p.y > top && p.y < base + 42 {
                return i
            }
        }
        return nil
    }

    private func blockingPlantHit(_ p: CGPoint) -> Int? {
        guard let i = plantHit(p) else { return nil }
        if case .ripe = plots[i].stage { return i }
        if abs(p.x - GGeo.plotX[i]) < 26 { return i }
        return nil
    }

    func handBegan(_ p: CGPoint) {
        pickedThisStroke.removeAll(keepingCapacity: true)
        handDown = true
        handP = p
        handLast = p
        handV = .zero
        grabStart = p
        grab = nil
        overReturnBadge = false

        if isPollinatingTapMode {
            return
        }

        if let w = weeds.indices.min(by: { abs(weeds[$0].x - p.x) < abs(weeds[$1].x - p.x) }) {
            let base = surface(weeds[w].x)
            let tall = 30 + 50 * weeds[w].growth
            if abs(weeds[w].x - p.x) < 38 && p.y > base - tall - 18 && p.y < base + 26 {
                grab = .weed(w)
                weeds[w].held = true
                GardenSound.shared.play(.pluck, volume: 0.25, gap: 0.2)
                return
            }
        }
        for i in plots.indices {
            guard let orb = pollenOrbPos(plot: i), case .ripe(let ripe) = plots[i].stage else { continue }
            if hypot(p.x - orb.x, p.y - orb.y) < 30 {
                grab = .pollen(fromPlot: i, kind: ripe.kind)
                pollination = .carrying(donorPlot: i, donorKind: ripe.kind, point: orb, tapMode: false)
                Sound.shared.play(.sparkle, volume: 0.45)
                enqueueEffect(.haptic)
                return
            }
        }
        for i in plots.indices {
            guard case .ripe(let ripe) = plots[i].stage, ripe.harvestMechanic == .pullUp else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            if abs(x - p.x) < 48 && p.y > base - 105 && p.y < base + 42 {
                grab = .carrot(i)
                plots[i].held = true
                return
            }
        }
        if hasCraftedCrown && hypot(p.x - GGeo.flowerCrownSpot.x, p.y - (GGeo.flowerCrownSpot.y - 16)) < 46 {
            grab = .flowerCrown
            crownBounceV += 8
            Sound.shared.play(.pop, volume: 0.5)
            enqueueEffect(.haptic)
            return
        }
        if hypot(p.x - GGeo.basket.x, p.y - (GGeo.basket.y - 10)) < 62 {
            if !inventory.isEmpty {
                grab = .basketFeed
                basketBounceV += 6
            }
            return
        }
        if blockingPlantHit(p) != nil
            || visitorHit(p) != nil
            || isOverPicnic(p)
            || hypot(p.x - GGeo.vase.x, p.y - (GGeo.vase.y - 44)) < 50
            || hypot(p.x - GGeo.fireflyJar.x, p.y - (GGeo.fireflyJar.y - 24)) < 32 {
            return
        }
        if let d = decorHit(p) {
            grab = .decor(d)
            decor[d].held = true
            decor[d].poke = time
            overReturnBadge = isOverReturnBadge(p)
            GardenSound.shared.play(.plunk, volume: 0.4)
            markUIStateDirty()
        }
    }

    func handMoved(_ p: CGPoint, rawFinger: CGPoint? = nil, dt: CGFloat = 1.0 / 60) {
        let vx = (p.x - handP.x) / max(dt, 0.001)
        let vy = (p.y - handP.y) / max(dt, 0.001)
        handV = CGVector(dx: vx, dy: vy)
        handLast = handP
        handP = p
        switch grab {
        case .weed(let w)?:
            guard w < weeds.count else { grab = nil; return }
            let up = max(0, grabStart.y - p.y)
            weeds[w].pull = up / 95
            weeds[w].bend = max(-0.6, min(0.6, (p.x - grabStart.x) / 150))
            if weeds[w].pull >= 1 {
                grab = nil
                popWeed(w, v: CGVector(dx: (p.x - grabStart.x) * 2 + CGFloat.random(in: -80...80), dy: -740))
            } else if Int(up) % 24 == 0 && up > 4 {
                GardenSound.shared.play(.pluck, volume: 0.15, gap: 0.15)
            }
        case .carrot(let i)?:
            let up = max(0, grabStart.y - p.y)
            plots[i].pull = up / 80
            plots[i].bend = max(-0.5, min(0.5, (p.x - grabStart.x) / 160))
            if plots[i].pull >= 1 {
                plots[i].held = false
                grab = nil
                _ = harvest(i)
            }
        case .decor(let d)?:
            guard d < decor.count else { grab = nil; return }
            let k = decor[d].kind
            decor[d].x = max(GGeo.yardMinX, min(GGeo.yardMaxX, p.x))
            decor[d].y = p.y + k.size.height * 0.45
            decor[d].vy = 0
            decor[d].tiltV += (p.x - handLast.x) * 0.05
            let raw = rawFinger ?? p
            let over = isOverReturnBadge(raw) || isOverReturnBadge(p)
            if over != overReturnBadge {
                overReturnBadge = over
                markUIStateDirty()
            }
        case .pollen(let fromPlot, let kind)?:
            pollination = .carrying(donorPlot: fromPlot, donorKind: kind, point: p, tapMode: false)
            if Int(time * 24) % 2 == 0 {
                particles.append(GParticle(kind: .pollen,
                                           p: CGPoint(x: p.x + CGFloat.random(in: -8...8), y: p.y + CGFloat.random(in: -8...8)),
                                           v: CGVector(dx: CGFloat.random(in: -22...22), dy: CGFloat.random(in: -24...12)),
                                           life: 0.6, size: CGFloat.random(in: 3.5...6), color: GRGB(0xFFE05C)))
            }
        case .flowerCrown?:
            if Int(time * 20) % 3 == 0, let col = craftedCrownColors.randomElement() {
                particles.append(GParticle(kind: .petal, p: p,
                                           v: CGVector(dx: CGFloat.random(in: -30...30), dy: CGFloat.random(in: -25...15)),
                                           life: 0.9, size: 6, color: col, rot: CGFloat.random(in: 0...6), spin: 3))
            }
        case .basketFeed?:
            break
        case nil:
            if !isPollinatingTapMode {
                brush(from: handLast, to: p)
            }
        }
    }

    func handEnded(_ p: CGPoint, rawFinger: CGPoint? = nil, tap: Bool) {
        handDown = false
        switch grab {
        case .weed(let w)?:
            if w < weeds.count {
                let pulled = weeds[w].pull >= 0.75
                weeds[w].held = false
                if pulled {
                    popWeed(w, v: CGVector(dx: (p.x - grabStart.x) * 2, dy: -700))
                }
            }
        case .carrot(let i)?:
            let pulled = plots[i].pull >= 0.72
            plots[i].held = false
            if pulled {
                _ = harvest(i)
            } else if tap {
                plots[i].pull = 0.55
                plots[i].pullV = 10
                plots[i].popV += 7
                _ = harvest(i)
            }
        case .decor(let d)?:
            if d < decor.count {
                decor[d].held = false
                let raw = rawFinger ?? p
                if tap {
                    decor[d].y = decor[d].baseY
                    pokeDecor(d)
                } else if isOverReturnBadge(raw) || isOverReturnBadge(p) {
                    removeDecor(d)
                } else {
                    decor[d].baseY = max(484, min(504, p.y + decor[d].kind.size.height * 0.45))
                    decor[d].y = min(decor[d].y, decor[d].baseY)
                }
            }
            overReturnBadge = false
            markUIStateDirty()
        case .pollen(let fromPlot, let kind)?:
            if tap {
                let orb = pollenOrbPos(plot: fromPlot) ?? p
                pollination = .carrying(donorPlot: fromPlot, donorKind: kind, point: orb, tapMode: true)
                sparkle(at: orb, count: 10)
                Sound.shared.play(.sparkle, volume: 0.55)
                enqueueEffect(.haptic)
                markUIStateDirty()
            } else {
                let hitPlot = plantHit(p) ?? plots.indices.min(by: { abs(GGeo.plotX[$0] - p.x) < abs(GGeo.plotX[$1] - p.x) }).flatMap { idx in
                    abs(GGeo.plotX[idx] - p.x) < 68 && p.y > 220 && p.y < GGeo.bedBottom ? idx : nil
                }
                if let targetIdx = hitPlot, targetIdx != fromPlot, pollinatable(targetIdx),
                   case .ripe(let targetRipe) = plots[targetIdx].stage, targetRipe.kind != kind {
                    dispatchVisualBeeFlourish(fromPlot: fromPlot, ontoPlot: targetIdx)
                    _ = crossBreed(fromPlot: fromPlot, ontoPlot: targetIdx)
                } else {
                    sparkle(at: p, count: 6)
                }
                pollination = .idle
                markUIStateDirty()
            }
        case .flowerCrown?:
            if tap {
                if !placeCrownOnNearestCritter() {
                    crownBounceV += 12
                    sparkle(at: CGPoint(x: GGeo.flowerCrownSpot.x, y: GGeo.flowerCrownSpot.y - 16), count: 8)
                    Sound.shared.play(.boing, volume: 0.35)
                }
            } else {
                if !placeCrown(at: p) {
                    crownBounceV += 10
                    Sound.shared.play(.whoosh, volume: 0.35)
                }
            }
        case .basketFeed?:
            if tap {
                basketBounceV += 12
                GardenSound.shared.play(.basket, volume: 0.75)
                enqueueEffect(.haptic)
                sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 40), count: 8)
            } else {
                if !feedVisitorFromBasket(at: p) && isOverPicnic(p) {
                    _ = servePicnicSnack(at: p)
                }
            }
        case nil:
            if tap {
                tapAt(p)
            } else if isPollinatingTapMode {
                pollination = .idle
                markUIStateDirty()
            }
        }
        grab = nil
    }

    private func brush(from a: CGPoint, to b: CGPoint) {
        let dx = b.x - a.x
        let moved = hypot(b.x - a.x, b.y - a.y)
        let sweep = abs(b.x - grabStart.x) > 22

        if moved > 4 && (season == .spring || season == .autumn || season == .winter) {
            vortexCenter = b
            vortexUntil = time + 0.55
            if season == .spring && Int.random(in: 0..<3) == 0 {
                let col = Bool.random() ? GRGB(0xFFB3D2) : GRGB(0xFFE0EE)
                particles.append(GParticle(kind: .petal, p: b,
                                           v: CGVector(dx: (b.x - a.x) * 3.5 + CGFloat.random(in: -30...30),
                                                       dy: (b.y - a.y) * 3.5 - 45),
                                           life: 2.8, size: CGFloat.random(in: 7...10), color: col,
                                           rot: CGFloat.random(in: 0...6), spin: CGFloat.random(in: -6...6)))
            }
        }

        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let x = GGeo.plotX[i]
            let base = surface(x)
            let top = base - GardenPlants.stemHeight(pl) - 32
            if case .ripe(var ripe) = plots[i].stage, !pickedThisStroke.contains(i) {
                let t = abs(dx) > 1 ? min(1, max(0, (x - a.x) / dx)) : 1
                let y = a.y + (b.y - a.y) * t
                let hitBox = abs(a.x + dx * t - x) < ripe.effectiveReach + 6 && y >= top && y <= base + 10
                if hitBox {
                    switch ripe.harvestMechanic {
                    case .snipStem, .waterPuff:
                        if sweep {
                            pickedThisStroke.insert(i)
                            _ = harvest(i)
                        }
                    case .shakeVine:
                        ripe.shakeProgress += abs(dx) / 28
                        plots[i].bendV += dx * 0.08
                        if sweep || ripe.shakeProgress >= 1.0 {
                            pickedThisStroke.insert(i)
                            _ = harvest(i)
                        } else {
                            plots[i].stage = .ripe(ripe)
                        }
                    case .pullUp:
                        break
                    }
                }
            }
            if abs(b.x - x) < pl.effectiveReach + 10 && b.y > top && b.y < base + 6 {
                let leverage = (base - b.y) / max(40, base - top)
                plots[i].bendV += dx * 0.05 * (0.4 + leverage)
                if pl.hybrid == .starlightRose && abs(dx) > 8, let hd = head(plot: i) {
                    starlightChime(at: hd)
                }
                if bloomed(i) && abs(dx) > 14 && Int.random(in: 0..<4) == 0, let hd = head(plot: i) {
                    petals(at: hd, color: pl.hybrid?.primaryColor ?? pl.kind.bloom(pl.variant), n: 1)
                }
                if abs(dx) > 6 { GardenSound.shared.play(.rustle, volume: 0.5, gap: 0.22) }
            }
        }
        for i in weeds.indices {
            let base = surface(weeds[i].x)
            if abs(b.x - weeds[i].x) < 30 && b.y > base - 80 && b.y < base + 4 {
                weeds[i].bendV += dx * 0.06
            }
        }
        scareBugs(near: b, radius: 70)
    }

    private func scareBugs(near p: CGPoint, radius: CGFloat) {
        for i in butterflies.indices where hypot(butterflies[i].p.x - p.x, butterflies[i].p.y - p.y) < radius {
            flee(i, from: p)
        }
        if var b = bee, hypot(b.p.x - p.x, b.p.y - p.y) < radius {
            b.perch = nil
            b.v = CGVector(dx: (b.p.x - p.x) * 6, dy: -200)
            b.nextThink = time + 0.8
            bee = b
            GardenSound.shared.play(.buzz, volume: 0.6, gap: 0.4)
        }
        if !ladybug.flying && abs(ladybug.p.x - p.x) < radius * 0.6 && abs(ladybug.p.y - p.y) < radius * 0.6 {
            ladybugTakeOff()
        }
    }

    private func flee(_ i: Int, from p: CGPoint) {
        let b = butterflies[i]
        let dx = b.p.x - p.x
        let dy = b.p.y - p.y
        let d = max(1, hypot(dx, dy))
        butterflies[i].perch = nil
        butterflies[i].v = CGVector(dx: dx / d * 260, dy: min(-120, dy / d * 260))
        butterflies[i].target = CGPoint(x: CGFloat.random(in: 100...924), y: CGFloat.random(in: 120...300))
        butterflies[i].nextThink = time + 2
        GardenSound.shared.play(.flutter, volume: 0.6, gap: 0.3)
    }

    private func tapAt(_ p: CGPoint) {
        if case .carrying(let donorPlot, let donorKind, _, let tapMode) = pollination, tapMode {
            let hitPlot = plantHit(p) ?? plots.indices.min(by: { abs(GGeo.plotX[$0] - p.x) < abs(GGeo.plotX[$1] - p.x) }).flatMap { idx in
                abs(GGeo.plotX[idx] - p.x) < 68 && p.y > 220 && p.y < GGeo.bedBottom ? idx : nil
            }
            if let targetIdx = hitPlot, targetIdx != donorPlot, pollinatable(targetIdx),
               case .ripe(let targetRipe) = plots[targetIdx].stage, targetRipe.kind != donorKind {
                dispatchVisualBeeFlourish(fromPlot: donorPlot, ontoPlot: targetIdx)
                _ = crossBreed(fromPlot: donorPlot, ontoPlot: targetIdx)
                pollination = .idle
                markUIStateDirty()
                return
            }
            pollination = .idle
            markUIStateDirty()
            if hitPlot == donorPlot { return }
        }

        if catchFirefly(at: p) { return }

        if hypot(p.x - GGeo.fireflyJar.x, p.y - (GGeo.fireflyJar.y - 24)) < 32 {
            if caughtFireflies > 0 {
                _ = releaseFireflyJar()
            } else {
                jarBounceV += 10
                Sound.shared.play(.ding, volume: 0.35)
                enqueueEffect(.haptic)
            }
            return
        }

        if hypot(p.x - GGeo.basket.x, p.y - (GGeo.basket.y - 10)) < 62 {
            basketBounceV += 12
            GardenSound.shared.play(.basket, volume: 0.75)
            enqueueEffect(.haptic)
            sparkle(at: CGPoint(x: GGeo.basket.x, y: GGeo.basket.y - 40), count: 8)
            return
        }

        if hypot(p.x - GGeo.vase.x, p.y - (GGeo.vase.y - 44)) < 50 {
            if vaseFlowers.count >= 3 && !hasCraftedCrown {
                _ = weaveFlowerCrown()
                return
            }
            vaseBounceV += 12
            Sound.shared.play(.ding, volume: 0.5)
            enqueueEffect(.haptic)
            sparkle(at: CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 72), count: 8)
            if let lastFlower = vaseFlowers.last {
                petals(at: CGPoint(x: GGeo.vase.x, y: GGeo.vase.y - 78), color: lastFlower.source.displayColor, n: 5)
            }
            return
        }

        if let pi = picnicCritterHit(p) {
            if hasCraftedCrown {
                _ = placeCrownOnPicnicCritter(at: pi)
                return
            }
            picnicCritters[pi].poked = time
            playVisitorSound(picnicCritters[pi].kind)
            heartBurst(at: CGPoint(x: picnicCritters[pi].p.x, y: picnicCritters[pi].p.y - 38), count: 4)
            enqueueEffect(.haptic)
            return
        }
        if isOverPicnic(p) {
            if !servePicnicSnack() {
                picnicBounceV += 8
                basketBounceV += 8
                Sound.shared.play(.boing, volume: 0.3)
            }
            return
        }

        if tapVisitor(p) { return }

        for i in butterflies.indices where hypot(butterflies[i].p.x - p.x, butterflies[i].p.y - p.y) < 56 {
            flee(i, from: CGPoint(x: p.x, y: p.y + 20))
            sparkle(at: butterflies[i].p, count: 5)
            return
        }
        if let b = bee, hypot(b.p.x - p.x, b.p.y - p.y) < 50 {
            scareBugs(near: p, radius: 60)
            return
        }
        if hypot(ladybug.p.x - p.x, ladybug.p.y - p.y) < 42 {
            ladybugTakeOff()
            return
        }
        let wormHead = CGPoint(x: worm.x, y: surface(worm.x) + worm.depth * (1 - worm.peek) - 14 * worm.peek)
        if hypot(wormHead.x - p.x, wormHead.y - p.y) < 50 {
            worm.wiggle = time
            GardenSound.shared.play(.squeak, volume: 0.8)
            return
        }
        if let i = plantHit(p) {
            let x = GGeo.plotX[i]
            switch plots[i].stage {
            case .ripe(let ripe):
                switch ripe.harvestMechanic {
                case .shakeVine:
                    plots[i].bendV += (plots[i].bend >= 0 ? -5.8 : 5.8)
                    plots[i].popV += 7
                    GardenSound.shared.play(.rustle, volume: 0.65)
                case .pullUp:
                    plots[i].pull = 0.55
                    plots[i].pullV = 10
                case .snipStem, .waterPuff:
                    plots[i].popV += 6
                }
                _ = harvest(i)
            case .growing(let g):
                plots[i].popV += 6
                plots[i].bendV += (p.x < x ? 1.2 : -1.2)
                if g.hybrid == .starlightRose, let hd = head(plot: i) {
                    starlightChime(at: hd)
                } else {
                    GardenSound.shared.play(.rustle, volume: 0.6)
                }
                if plots[i].dry > 1.5 {
                    Sound.shared.play(.boing, volume: 0.3)
                }
            case .empty:
                break
            }
            return
        }

        if hypot(p.x - GGeo.treehouse.x, p.y - (GGeo.treehouse.y - 125)) < 102 {
            pokeTreehouse()
            return
        }

        if GGeo.inBed(p.x) && abs(p.y - surface(p.x)) < 50 {
            let s = surface(p.x)
            for _ in 0..<5 {
                particles.append(GParticle(kind: .dust, p: CGPoint(x: p.x + CGFloat.random(in: -14...14), y: s),
                                           v: CGVector(dx: CGFloat.random(in: -50...50), dy: CGFloat.random(in: -60 ... -20)),
                                           life: 0.6, size: CGFloat.random(in: 7...12), color: GRGB(0xB08660)))
            }
            GardenSound.shared.play(.pat, volume: 0.5)
        }
    }

    // MARK: Safe Decorations

    @discardableResult
    func placeDecorOnFreeSpot(_ k: DecorKind) -> Int {
        let candidates: [CGFloat] = [180, 308, 436, 564, 692, 856, 928, 72, 212, 340, 468, 596, 724, 892]
        let bestX = candidates.max { a, b in
            scoreDecorSpot(a, for: k) < scoreDecorSpot(b, for: k)
        } ?? 856
        let idx = addDecor(k, x: bestX, falling: true)
        Sound.shared.play(.pop, volume: 0.6)
        enqueueEffect(.haptic)
        return idx
    }

    private func scoreDecorSpot(_ x: CGFloat, for k: DecorKind) -> CGFloat {
        let decorClear = min(150, decor.map { abs($0.x - x) }.min() ?? 150)
        var plantPenalty: CGFloat = 0
        for i in plots.indices {
            guard let pl = plots[i].plant else { continue }
            let dx = abs(GGeo.plotX[i] - x)
            let span = pl.effectiveReach + 14
            if dx < span {
                let tallPlant = (pl.hybrid?.height ?? pl.kind.height) >= k.size.height
                plantPenalty += tallPlant ? 240 : 120
            }
        }
        return decorClear - plantPenalty
    }

    @discardableResult
    func addDecor(_ k: DecorKind, x: CGFloat, falling: Bool) -> Int {
        if decor.count >= 14 { removeDecor(0) }
        var d = GDecor(id: nextDecorID, kind: k, x: max(GGeo.yardMinX, min(GGeo.yardMaxX, x)), y: GGeo.yardY)
        nextDecorID += 1
        d.baseY = GGeo.yardY + CGFloat(nextDecorID % 3) * 4 - 4
        d.y = falling ? d.baseY - 110 : d.baseY
        decor.append(d)
        return decor.count - 1
    }

    func removeDecor(_ i: Int) {
        guard decor.indices.contains(i) else { return }
        let d = decor.remove(at: i)
        for _ in 0..<10 {
            particles.append(GParticle(kind: .dust, p: CGPoint(x: d.x + CGFloat.random(in: -30...30), y: d.y - CGFloat.random(in: 0...60)),
                                       v: CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: -60...0)), life: 0.6,
                                       size: CGFloat.random(in: 12...20), color: GRGB(0xFFFFFF)))
        }
        Sound.shared.play(.whoosh, volume: 0.5)
    }

    func decorHit(_ p: CGPoint) -> Int? {
        for i in decor.indices.reversed() {
            let d = decor[i]
            let s = d.kind.size
            if abs(p.x - d.x) < s.width * 0.6 && p.y < d.y + 12 && p.y > d.y - s.height - 10 { return i }
        }
        return nil
    }

    private func pokeDecor(_ i: Int) {
        decor[i].poke = time
        decor[i].squashV -= 6
        switch decor[i].kind {
        case .pinwheel:
            decor[i].spinV += 22
            Sound.shared.play(.whoosh, volume: 0.4)
        case .lantern:
            decor[i].lit.toggle()
            Sound.shared.play(.sparkle, volume: 0.4)
        case .birdhouse:
            GardenSound.shared.play(.chirp, volume: 0.9)
        case .bunny:
            decor[i].vy = -400
            Sound.shared.play(.boing, volume: 0.5)
        case .mushroom:
            decor[i].squashV -= 6
            Sound.shared.play(.boing, volume: 0.5)
        case .birdbath:
            decor[i].tiltV += 3
            for _ in 0..<5 {
                splash(at: CGPoint(x: decor[i].x + CGFloat.random(in: -30...30), y: decor[i].y - 72),
                       v: .zero, n: decor[i].water > 0.1 ? 1 : 0)
            }
            GardenSound.shared.play(.splash, volume: decor[i].water > 0.1 ? 0.6 : 0.2)
        case .flamingo, .flag:
            decor[i].tiltV += 4
            Sound.shared.play(.boing, volume: 0.4)
        case .crystal, .rainbow, .unicorn:
            decor[i].tiltV += 3
            Sound.shared.play(.sparkle, volume: 0.5)
        case .lotus:
            decor[i].tiltV += 2.6
            sparkle(at: CGPoint(x: decor[i].x, y: decor[i].y - 68), count: 8)
            Sound.shared.play(.sparkle, volume: 0.55)
        }
    }

    private func stepDecor(_ dt: CGFloat) {
        for i in decor.indices {
            if !decor[i].held {
                if decor[i].y < decor[i].baseY || decor[i].vy < 0 {
                    decor[i].vy += GardenSim.gravity * dt
                    decor[i].y += decor[i].vy * dt
                    if decor[i].y >= decor[i].baseY {
                        decor[i].y = decor[i].baseY
                        if decor[i].vy > 200 {
                            decor[i].squashV -= decor[i].vy * 0.012
                            GardenSound.shared.play(.plunk, volume: Float(min(1, decor[i].vy / 900)))
                            for _ in 0..<4 {
                                particles.append(GParticle(kind: .dust, p: CGPoint(x: decor[i].x + CGFloat.random(in: -26...26), y: decor[i].y),
                                                           v: CGVector(dx: CGFloat.random(in: -50...50), dy: -20), life: 0.5,
                                                           size: CGFloat.random(in: 8...12), color: GRGB(0xCFE8B8)))
                            }
                        }
                        decor[i].vy = decor[i].vy > 260 ? -decor[i].vy * 0.2 : 0
                    }
                }
            }
            decor[i].squashV += (-240 * decor[i].squash - 11 * decor[i].squashV) * dt
            decor[i].squash += decor[i].squashV * dt
            let lean = decor[i].kind == .flag || decor[i].kind == .flamingo ? windNow * 0.12 : 0
            decor[i].tiltV += ((lean - decor[i].tilt) * 90 - decor[i].tiltV * 6) * dt
            decor[i].tilt += decor[i].tiltV * dt
            let spinRest = 1.2 + windNow * 16
            decor[i].spinV += (spinRest - decor[i].spinV) * dt * 0.8
            decor[i].spin += decor[i].spinV * dt
            if decor[i].kind == .birdbath {
                let sunny = (1 - cloud) * (1 - night)
                decor[i].water = max(0, decor[i].water - 0.004 * sunny * dt)
            }
        }
    }

    // MARK: Bugs (Decorative Bee Only — Never Auto-Breeds)

    private func spawnButterfly(_ k: Int, fromEdge: Bool) {
        let left = Bool.random()
        let p = fromEdge ? CGPoint(x: left ? -50 : 1074, y: CGFloat.random(in: 140...340))
                         : CGPoint(x: CGFloat.random(in: 180...800), y: CGFloat.random(in: 150...340))
        butterflies.append(GButterfly(p: p, v: CGVector(dx: left ? 80 : -80, dy: 0),
                                      target: CGPoint(x: CGFloat.random(in: 180...800), y: CGFloat.random(in: 150...340)),
                                      phase: CGFloat.random(in: 0...6), look: Int.random(in: 0..<5)))
    }

    func ladybugTakeOff() {
        ladybug.flying = true
        ladybug.v = CGVector(dx: CGFloat.random(in: -1...1) * 180, dy: -320)
        GardenSound.shared.play(.flutter, volume: 0.5)
    }

    private func stepCritters(_ dt: CGFloat) {
        let t = CGFloat(time)
        let outside = rain < 0.35 && night < 0.5
        let blooms = plots.indices.filter { bloomed($0) }

        let want = outside ? 2 + min(2, blooms.count) : 0
        if butterflies.filter({ !$0.leaving }).count < want && Int.random(in: 0..<200) == 0 {
            spawnButterfly(butterflies.count, fromEdge: true)
        }
        var live = butterflies.filter { !$0.leaving }.count
        for i in butterflies.indices where live > want && !butterflies[i].leaving {
            butterflies[i].leaving = true
            butterflies[i].perch = nil
            butterflies[i].target = CGPoint(x: butterflies[i].p.x < 512 ? -120 : 1144, y: 140)
            live -= 1
        }
        for i in butterflies.indices {
            var b = butterflies[i]
            if let pi = b.perch {
                if let hd = head(plot: pi), bloomed(pi), time < b.perchUntil {
                    b.p = CGPoint(x: hd.x, y: hd.y - 6)
                    b.phase += dt * 2.2
                } else {
                    b.perch = nil
                    b.v = CGVector(dx: CGFloat.random(in: -60...60), dy: -140)
                    b.nextThink = time + 1.5
                }
            } else {
                b.phase += dt * 21
                if !b.leaving && time > b.nextThink {
                    b.nextThink = time + Double.random(in: 2...4)
                    let free = blooms.filter { pi in !butterflies.contains { $0.perch == pi } }
                    if let pi = free.randomElement(), Int.random(in: 0..<10) < 6, let hd = head(plot: pi) {
                        b.target = hd
                        b.perch = nil
                        b.perchUntil = -Double(pi) - 1
                    } else {
                        b.target = CGPoint(x: CGFloat.random(in: 90...910), y: CGFloat.random(in: 120...400))
                        b.perchUntil = 0
                    }
                }
                if b.perchUntil < 0 {
                    let pi = Int(-b.perchUntil - 1)
                    if pi < plots.count, bloomed(pi), let hd = head(plot: pi) {
                        b.target = hd
                        if hypot(hd.x - b.p.x, hd.y - b.p.y) < 16 {
                            b.perch = pi
                            b.perchUntil = time + Double.random(in: 3...6)
                        }
                    } else {
                        b.perchUntil = 0
                    }
                }
                let dx = b.target.x - b.p.x
                let dy = b.target.y - b.p.y
                let d = max(1, hypot(dx, dy))
                let speed: CGFloat = b.leaving ? 200 : min(140, d * 1.5 + 30)
                let ax = (dx / d * speed - b.v.dx) * 1.8
                let ay = (dy / d * speed - b.v.dy) * 1.8 + sin(t * 6 + CGFloat(i) * 2) * 160
                b.v.dx += (ax + windNow * 90) * dt
                b.v.dy += ay * dt
                b.p.x += b.v.dx * dt
                b.p.y += b.v.dy * dt
            }
            butterflies[i] = b
        }
        butterflies.removeAll { $0.leaving && ($0.p.x < -100 || $0.p.x > 1124) }

        if outside && !blooms.isEmpty && weather != .rain {
            if bee == nil && time >= nextBeeSpawn {
                nextBeeSpawn = time + 3.5
                let firstTargetIdx = blooms.first
                let tgt = firstTargetIdx.flatMap { pollenAnchor(plot: $0) } ?? CGPoint(x: 680, y: 250)
                let fromLeft = tgt.x < 512
                let start = CGPoint(x: fromLeft ? -40 : 1060, y: max(150, tgt.y - 70))
                var fresh = GBee(p: start, v: CGVector(dx: fromLeft ? 160 : -160, dy: 0), target: tgt)
                if let idx = firstTargetIdx {
                    fresh.perchUntil = -Double(idx) - 1
                }
                bee = fresh
            }
        } else if var b = bee, !b.leaving {
            b.leaving = true
            b.perch = nil
            b.target = CGPoint(x: 1180, y: 120)
            bee = b
        }
        if var b = bee {
            b.phase += dt * 60
            if let pi = b.perch {
                if let hd = pollenAnchor(plot: pi), bloomed(pi), time < b.perchUntil {
                    b.p = CGPoint(x: hd.x + 4, y: hd.y - 10)
                } else {
                    b.perch = nil
                    b.nextThink = time + 0.3
                }
            } else {
                if !b.leaving && time > b.nextThink && time > b.flourishUntil {
                    b.nextThink = time + Double.random(in: 1.5...2.8)
                    if let pi = blooms.randomElement(), let hd = pollenAnchor(plot: pi) {
                        b.target = hd
                        b.perchUntil = -Double(pi) - 1
                    } else {
                        b.target = CGPoint(x: CGFloat.random(in: 120...860), y: CGFloat.random(in: 180...410))
                        b.perchUntil = 0
                    }
                }
                if b.perchUntil < 0 {
                    let pi = Int(-b.perchUntil - 1)
                    if pi < plots.count, let hd = pollenAnchor(plot: pi), (bloomed(pi) || time <= b.flourishUntil) {
                        b.target = hd
                        if hypot(hd.x - b.p.x, hd.y - b.p.y) < 18 {
                            b.perch = pi
                            b.perchUntil = time + Double.random(in: 1.4...2.4)
                        }
                    } else {
                        b.perchUntil = 0
                    }
                }
                let dx = b.target.x - b.p.x
                let dy = b.target.y - b.p.y
                let d = max(1, hypot(dx, dy))
                let speed: CGFloat = min(260, d * 2.4 + 45)
                let jitter: CGFloat = time <= b.flourishUntil ? 30 : 120
                b.v.dx += ((dx / d * speed - b.v.dx) * 3.4 + sin(t * 13) * jitter) * dt
                b.v.dy += ((dy / d * speed - b.v.dy) * 3.4 + cos(t * 11) * jitter) * dt
                b.p.x += b.v.dx * dt
                b.p.y += b.v.dy * dt
            }
            bee = (b.leaving && (b.p.x > 1140 || b.p.x < -120)) ? nil : b
        }

        if ladybug.flying {
            ladybug.open = min(1, ladybug.open + dt * 8)
            ladybug.v.dy += 420 * dt
            let toward = (436 - ladybug.p.x) * 0.28
            ladybug.v.dx += (toward - ladybug.v.dx * 0.2) * dt
            ladybug.p.x += ladybug.v.dx * dt
            ladybug.p.y += ladybug.v.dy * dt
            ladybug.p.y = min(ladybug.p.y, 700)
            if ladybug.v.dy > 0 && GGeo.inBed(ladybug.p.x) && ladybug.p.y >= surface(ladybug.p.x) - 4 {
                ladybug.flying = false
                ladybug.x = ladybug.p.x
                ladybug.dir = ladybug.v.dx >= 0 ? 1 : -1
                ladybug.v = .zero
            }
        } else {
            ladybug.open = max(0, ladybug.open - dt * 5)
            if time > ladybug.nextTurn {
                ladybug.nextTurn = time + Double.random(in: 3...8)
                if Bool.random() { ladybug.dir = -ladybug.dir }
            }
            let speed: CGFloat = rain > 0.5 ? 0 : 16
            ladybug.x += ladybug.dir * speed * dt
            if ladybug.x < GGeo.bedLeft + 14 { ladybug.x = GGeo.bedLeft + 14; ladybug.dir = 1 }
            if ladybug.x > GGeo.bedRight - 14 { ladybug.x = GGeo.bedRight - 14; ladybug.dir = -1 }
            ladybug.walk += dt * speed
            ladybug.p = CGPoint(x: ladybug.x, y: surface(ladybug.x) - 4)
        }

        worm.phase += dt * 3
        if worm.peek > 0.01 || time < worm.peekUntil {
            let up: CGFloat = time < worm.peekUntil ? 1 : 0
            worm.peek += (up - worm.peek) * min(1, dt * 3.5)
        } else {
            worm.x += worm.dir * 9 * dt
            worm.depth = 44 + 16 * sin(t * 0.13 + 1)
            if worm.x < GGeo.bedLeft + 38 { worm.dir = 1 }
            if worm.x > GGeo.bedRight - 38 { worm.dir = -1 }
            if time > worm.nextPeek {
                worm.nextPeek = time + Double.random(in: 8...16)
                if wetAt(worm.x, span: 6) > 0.45 || rain > 0.5 {
                    worm.peekUntil = time + Double.random(in: 3...5)
                    if rain < 0.5 { GardenSound.shared.play(.squeak, volume: 0.4) }
                }
            }
        }

        let wantFlies = night > 0.4 ? 12 : 0
        if fireflies.count < wantFlies && Int.random(in: 0..<20) == 0 {
            fireflies.append(GFirefly(p: CGPoint(x: CGFloat.random(in: 60...960), y: CGFloat.random(in: 240...540)),
                                      v: .zero, phase: CGFloat.random(in: 0...6)))
        }
        if fireflies.count > wantFlies && Int.random(in: 0..<30) == 0 { fireflies.removeFirst() }
        for i in fireflies.indices {
            var f = fireflies[i]
            f.phase += dt
            let ax = sin(f.phase * 0.9 + CGFloat(i)) * 40 + (handDown ? (handP.x - f.p.x) * 0.15 : 0)
            let ay = cos(f.phase * 0.7 + CGFloat(i) * 2) * 30 + (handDown ? (handP.y - f.p.y) * 0.15 : 0)
            f.v.dx += (ax - f.v.dx * 0.6) * dt
            f.v.dy += (ay - f.v.dy * 0.6) * dt
            f.p.x += f.v.dx * dt
            f.p.y += f.v.dy * dt
            f.p.y = max(130, min(580, f.p.y))
            f.p.x = max(20, min(1004, f.p.x))
            fireflies[i] = f
        }
    }

    // MARK: Sound loops

    private func stepSound() {
        let s = GardenSound.shared
        let onBed = station == .bed
        s.setLoop(.water, volume: onBed ? Float(flow) * 0.75 : 0)
        s.setLoop(.rain, volume: Float(rain) * (onBed ? 0.55 : 0.22))
        s.setLoop(.wind, volume: Float(max(0, wind - 0.1)) * (onBed ? 0.5 : 0.2))
        s.setLoop(.crickets, volume: Float(night) * (onBed ? 0.35 : 0.15))
        var buzz: Float = 0
        if onBed, let b = bee, b.perch == nil { buzz = 0.25 }
        s.setLoop(.buzz, volume: buzz)
    }
}

enum GardenStorage {
    static func load() -> GardenSave? { GameStorage.load(GardenSave.self, game: GardenSim.gameID, file: "garden.json") }
    static func save(_ s: GardenSave) { GameStorage.save(s, game: GardenSim.gameID, file: "garden.json") }
    static func saveAsync(_ s: GardenSave) { GameStorage.saveAsync(s, game: GardenSim.gameID, file: "garden.json") }
}
