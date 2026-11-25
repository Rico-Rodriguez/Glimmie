import CoreGraphics
import Foundation
import SwiftUI

enum WrapPaperStyle: String, Codable, CaseIterable, Equatable, Hashable {
    case kraft
    case blushGingham
    case mintStripes
    case starryLavender
    case buttercupDots

    var primaryHex: UInt32 {
        switch self {
        case .kraft: return 0xE6C39A
        case .blushGingham: return 0xFFD9E8
        case .mintStripes: return 0xCCF2E4
        case .starryLavender: return 0xDFD0FF
        case .buttercupDots: return 0xFFF0B5
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .kraft: return 0xC99E6E
        case .blushGingham: return 0xFF9AC0
        case .mintStripes: return 0x7ED8BC
        case .starryLavender: return 0xB394FA
        case .buttercupDots: return 0xFFD24D
        }
    }
}

enum BouquetRibbonColor: String, Codable, CaseIterable, Equatable, Hashable {
    case berryPink
    case butterYellow
    case skyBlue
    case lilac
    case mint

    var hex: UInt32 {
        switch self {
        case .berryPink: return 0xFF7CA8
        case .butterYellow: return 0xFFD654
        case .skyBlue: return 0x7EC8FF
        case .lilac: return 0xBC9CFF
        case .mint: return 0x6FDAB8
        }
    }
}

enum JamLidColor: String, Codable, CaseIterable, Equatable, Hashable {
    case strawberryGingham
    case apricotGingham
    case blueberryGingham
    case lavenderGingham
    case mintGingham

    var primaryHex: UInt32 {
        switch self {
        case .strawberryGingham: return 0xFF8CAE
        case .apricotGingham: return 0xFFB578
        case .blueberryGingham: return 0x86C5FF
        case .lavenderGingham: return 0xC6A8FF
        case .mintGingham: return 0x7CE0BC
        }
    }

    var stripeHex: UInt32 {
        switch self {
        case .strawberryGingham: return 0xFF5D8E
        case .apricotGingham: return 0xF08B42
        case .blueberryGingham: return 0x4E9BE8
        case .lavenderGingham: return 0x9B76EB
        case .mintGingham: return 0x47BC94
        }
    }
}

enum HarvestRequirement: Codable, Equatable, Hashable {
    case species(PlantKind)
    case anyFlower
    case anyFruitOrVeggie
    case anyHybrid

    var specificity: Int {
        switch self {
        case .species: return 0
        case .anyHybrid: return 1
        case .anyFlower, .anyFruitOrVeggie: return 2
        }
    }

    func matches(_ item: HarvestItem) -> Bool {
        switch self {
        case .species(let required):
            if case .plant(let kind, _, _) = item.source {
                return kind == required
            }
            return false
        case .anyFlower:
            return item.isFlower
        case .anyFruitOrVeggie:
            return item.isEdibleProduce
        case .anyHybrid:
            if case .hybrid = item.source { return true }
            return false
        }
    }
}

enum FarmstandOrderKind: String, Codable, CaseIterable, Equatable, Hashable {
    case bouquet
    case jamJar
    case farmBasket

    func accepts(_ item: HarvestItem) -> Bool {
        switch self {
        case .bouquet:
            return item.isFlower
        case .jamJar:
            return item.isJamProduce
        case .farmBasket:
            return item.isEdibleProduce
        }
    }
}

struct FarmstandOrder: Codable, Equatable, Identifiable {
    var id: UUID
    var customer: GVisitorKind
    var kind: FarmstandOrderKind
    var requirements: [HarvestRequirement]
    var preferredWrap: WrapPaperStyle?
    var preferredRibbon: BouquetRibbonColor?
    var preferredLid: JamLidColor?

    init(
        id: UUID = UUID(),
        customer: GVisitorKind,
        kind: FarmstandOrderKind,
        requirements: [HarvestRequirement],
        preferredWrap: WrapPaperStyle? = nil,
        preferredRibbon: BouquetRibbonColor? = nil,
        preferredLid: JamLidColor? = nil
    ) {
        self.id = id
        self.customer = customer
        self.kind = kind
        self.requirements = requirements
        self.preferredWrap = preferredWrap
        self.preferredRibbon = preferredRibbon
        self.preferredLid = preferredLid
    }
}

struct FarmstandDraft: Codable, Equatable {
    static let maxItems = 3

    var items: [HarvestItem] = []
    var wrap: WrapPaperStyle = .blushGingham
    var ribbon: BouquetRibbonColor = .berryPink
    var lid: JamLidColor = .strawberryGingham
    var dewSpritzed: Bool = false
    var pressProgress: CGFloat = 0

    var isFull: Bool { items.count >= FarmstandDraft.maxItems }
    var hasGiant: Bool { items.contains(where: \.isGiant) }
    var hasHybrid: Bool {
        items.contains {
            if case .hybrid = $0.source { return true }
            return false
        }
    }

    var jamColor: GRGB {
        guard !items.isEmpty else { return GRGB(0xFF7FA2) }
        var r = 0.0
        var g = 0.0
        var b = 0.0
        for item in items {
            let c = item.source.displayColor
            r += c.r
            g += c.g
            b += c.b
        }
        let n = Double(items.count)
        return GRGB(r: r / n, g: g / n, b: b / n)
    }

    /// Arranges basket items so a giant crop sits proudly in the center hero slot (index 1).
    func arrangedBasketSlots() -> [HarvestItem?] {
        var slots: [HarvestItem?] = [nil, nil, nil]
        var remaining = items
        if let giantIdx = remaining.firstIndex(where: \.isGiant) {
            slots[1] = remaining.remove(at: giantIdx)
        }
        let fillOrder: [Int] = slots[1] == nil ? [1, 0, 2] : [0, 2]
        for slotIdx in fillOrder {
            guard !remaining.isEmpty else { break }
            slots[slotIdx] = remaining.removeFirst()
        }
        return slots
    }
}

struct FarmstandCelebration: Equatable {
    var customer: GVisitorKind
    var orderKind: FarmstandOrderKind
    var servedItems: [HarvestItem]
    var wrap: WrapPaperStyle
    var ribbon: BouquetRibbonColor
    var lid: JamLidColor
    var stars: Int
    var coinsAwarded: Int
    var startedAt: Double
    var duration: Double = 2.4
}

enum FarmstandPhase: Equatable {
    case crafting(order: FarmstandOrder, draft: FarmstandDraft)
    case celebrating(FarmstandCelebration)
}

struct FarmstandMatchResult: Equatable {
    let slotMatched: [Bool]
    let matchedCount: Int
    let allMatched: Bool
}

enum FarmstandMatcher {
    static func match(requirements: [HarvestRequirement], items: [HarvestItem]) -> FarmstandMatchResult {
        var matched = Array(repeating: false, count: requirements.count)
        var usedIndices = Set<Int>()

        let orderedIndices = requirements.indices.sorted { a, b in
            let sa = requirements[a].specificity
            let sb = requirements[b].specificity
            return sa != sb ? sa < sb : a < b
        }

        for reqIdx in orderedIndices {
            let req = requirements[reqIdx]
            if let itemIdx = items.indices.first(where: { !usedIndices.contains($0) && req.matches(items[$0]) }) {
                usedIndices.insert(itemIdx)
                matched[reqIdx] = true
            }
        }

        let count = matched.filter { $0 }.count
        return FarmstandMatchResult(
            slotMatched: matched,
            matchedCount: count,
            allMatched: !requirements.isEmpty && count == requirements.count
        )
    }

    static func canFulfill(order: FarmstandOrder, with inventory: [HarvestItem]) -> Bool {
        let eligible = inventory.filter { order.kind.accepts($0) }
        return match(requirements: order.requirements, items: eligible).allMatched
    }
}

enum FarmstandScoring {
    static func evaluate(order: FarmstandOrder, draft: FarmstandDraft) -> Int {
        let match = FarmstandMatcher.match(requirements: order.requirements, items: draft.items)
        var stars = match.allMatched ? 2 : 1

        if match.allMatched {
            switch order.kind {
            case .bouquet:
                if draft.dewSpritzed || draft.hasHybrid {
                    stars += 1
                }
            case .jamJar:
                if draft.pressProgress >= 0.99 || draft.hasHybrid {
                    stars += 1
                }
            case .farmBasket:
                if draft.items.count >= FarmstandDraft.maxItems || draft.hasHybrid || draft.items.contains(where: \.isSpecial) {
                    stars += 1
                }
            }
        }

        if draft.hasGiant {
            stars += 1
        }

        return max(1, min(3, stars))
    }
}

enum FarmstandOrderGenerator {
    private static let starterFlowers: [PlantKind] = [.tulip, .daisy, .sunflower, .lavender]
    private static let starterProduce: [PlantKind] = [.strawberry, .tomato, .carrot, .pumpkin]

    static func nextOrder(
        inventory: [HarvestItem],
        servedCount: Int,
        previousCustomer: GVisitorKind? = nil,
        seed: Int = 0
    ) -> FarmstandOrder {
        let allCustomers = GVisitorKind.allCases
        let rawCustomerIdx = abs(servedCount &* 3 &+ seed) % allCustomers.count
        var customer = allCustomers[rawCustomerIdx]
        if customer == previousCustomer {
            customer = allCustomers[(rawCustomerIdx + 1) % allCustomers.count]
        }

        let flowers = inventory.filter(\.isFlower)
        let produce = inventory.filter(\.isEdibleProduce)

        let kind: FarmstandOrderKind
        if flowers.count >= 2 && produce.count < 2 {
            kind = .bouquet
        } else if produce.count >= 2 && flowers.count < 2 {
            kind = (servedCount + seed) % 2 == 0 ? .jamJar : .farmBasket
        } else {
            let cycle: [FarmstandOrderKind] = [.bouquet, .jamJar, .farmBasket]
            kind = cycle[abs(servedCount + seed) % cycle.count]
        }

        let slotCount = (servedCount >= 3 && abs(servedCount + seed) % 2 == 1) ? 3 : 2
        let requirements = buildRequirements(
            for: kind,
            slotCount: slotCount,
            flowers: flowers,
            produce: produce,
            servedCount: servedCount,
            seed: seed
        )

        let wraps = WrapPaperStyle.allCases
        let ribbons = BouquetRibbonColor.allCases
        let lids = JamLidColor.allCases
        let styleIdx = abs(servedCount &+ seed)

        return FarmstandOrder(
            customer: customer,
            kind: kind,
            requirements: requirements,
            preferredWrap: kind == .bouquet ? wraps[styleIdx % wraps.count] : nil,
            preferredRibbon: kind == .bouquet ? ribbons[(styleIdx + 1) % ribbons.count] : nil,
            preferredLid: kind == .jamJar ? lids[styleIdx % lids.count] : nil
        )
    }

    private static func buildRequirements(
        for kind: FarmstandOrderKind,
        slotCount: Int,
        flowers: [HarvestItem],
        produce: [HarvestItem],
        servedCount: Int,
        seed: Int
    ) -> [HarvestRequirement] {
        switch kind {
        case .bouquet:
            var reqs: [HarvestRequirement] = []
            let classicFlowers: [PlantKind] = flowers.compactMap { item in
                if case .plant(let pk, _, _) = item.source { return pk }
                return nil
            }
            if let firstClassic = classicFlowers.first {
                reqs.append(.species(firstClassic))
            } else {
                reqs.append(.species(starterFlowers[abs(servedCount + seed) % starterFlowers.count]))
            }
            let hasFlowerHybrid = flowers.contains {
                if case .hybrid = $0.source { return true }
                return false
            }
            if hasFlowerHybrid && slotCount >= 2 {
                reqs.append(.anyHybrid)
            } else if classicFlowers.count >= 2 && classicFlowers[1] != classicFlowers[0] {
                reqs.append(.species(classicFlowers[1]))
            } else {
                reqs.append(.anyFlower)
            }
            while reqs.count < slotCount {
                reqs.append(.anyFlower)
            }
            return reqs

        case .jamJar, .farmBasket:
            var reqs: [HarvestRequirement] = []
            let classicProduce: [PlantKind] = produce.compactMap { item in
                if case .plant(let pk, _, _) = item.source { return pk }
                return nil
            }
            if let firstProduce = classicProduce.first {
                reqs.append(.species(firstProduce))
            } else {
                let fallback = kind == .jamJar
                    ? starterProduce[abs(servedCount + seed) % 2]
                    : starterProduce[abs(servedCount + seed) % starterProduce.count]
                reqs.append(.species(fallback))
            }
            if classicProduce.count >= 2 && classicProduce[1] != classicProduce[0] {
                reqs.append(.species(classicProduce[1]))
            } else {
                reqs.append(.anyFruitOrVeggie)
            }
            while reqs.count < slotCount {
                reqs.append(.anyFruitOrVeggie)
            }
            return reqs
        }
    }
}
