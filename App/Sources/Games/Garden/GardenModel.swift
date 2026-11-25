import Foundation
import SwiftUI

func gdRand(_ i: Int, _ salt: Int) -> CGFloat {
    var x = UInt64(bitPattern: Int64((i &* 92_837_111) ^ (salt &* 689_287_499))) &+ 0x9E37_79B9_7F4A_7C15
    x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
    x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
    x ^= x >> 31
    return CGFloat(x % 100_000) / 100_000
}

func gdEase(_ t: CGFloat) -> CGFloat {
    let x = max(0, min(1, t))
    return x * x * (3 - 2 * x)
}

func gdClamp(_ t: CGFloat) -> CGFloat { max(0, min(1, t)) }

struct GRGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func mix(_ o: GRGB, _ t: CGFloat) -> GRGB {
        let k = Double(max(0, min(1, t)))
        return GRGB(r: r + (o.r - r) * k, g: g + (o.g - g) * k, b: b + (o.b - b) * k)
    }

    func shade(_ k: Double) -> GRGB {
        if k >= 0 { return mix(GRGB(0xFFFFFF), CGFloat(k)) }
        let d = 1 + k
        return GRGB(r: r * d * 0.96, g: g * d * 0.92, b: b * d)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    func color(_ a: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

enum GardenStation: String, Codable, Equatable, CaseIterable {
    case bed
    case farmstand
}

enum HarvestMechanic: String, Codable, Equatable, CaseIterable {
    case pullUp
    case snipStem
    case shakeVine
    case waterPuff
}

enum HarvestSpecies: Codable, Equatable, Hashable {
    case classic(PlantKind)
    case hybrid(HybridKind)

    var isFlower: Bool {
        switch self {
        case .classic(let kind): return kind.isFlower
        case .hybrid(let hybrid): return hybrid.isFlower
        }
    }

    var spec: SpeciesSpec {
        SpeciesCatalog.spec(for: self)
    }
}

struct SpeciesSpec: Equatable {
    let growthDuration: Double
    let yieldCount: Int
    let harvestMechanic: HarvestMechanic
    let normalPalette: [GRGB]
}

enum SpeciesCatalog {
    static func spec(for species: HarvestSpecies) -> SpeciesSpec {
        switch species {
        case .classic(let kind):
            return classicSpec(kind)
        case .hybrid(let hybrid):
            return hybridSpec(hybrid)
        }
    }

    static func classicSpec(_ kind: PlantKind) -> SpeciesSpec {
        switch kind {
        case .carrot:
            return SpeciesSpec(
                growthDuration: 2.6,
                yieldCount: 1,
                harvestMechanic: .pullUp,
                normalPalette: [GRGB(0xFF8A2A), GRGB(0xFF7224), GRGB(0xFFA63B), GRGB(0xF0662E)]
            )
        case .daisy:
            return SpeciesSpec(
                growthDuration: 3.0,
                yieldCount: 2,
                harvestMechanic: .snipStem,
                normalPalette: [GRGB(0xFFFFFF), GRGB(0xFFC2DA), GRGB(0xFFF0A0), GRGB(0xE8D8FF)]
            )
        case .tulip:
            return SpeciesSpec(
                growthDuration: 3.4,
                yieldCount: 1,
                harvestMechanic: .snipStem,
                normalPalette: [GRGB(0xFF4F7B), GRGB(0xFF9A3D), GRGB(0xC86BFF), GRGB(0xFFD23F)]
            )
        case .strawberry:
            return SpeciesSpec(
                growthDuration: 3.8,
                yieldCount: 3,
                harvestMechanic: .shakeVine,
                normalPalette: [GRGB(0xE8263F), GRGB(0xFF4262), GRGB(0xD9204A), GRGB(0xFF5C74)]
            )
        case .lavender:
            return SpeciesSpec(
                growthDuration: 4.2,
                yieldCount: 2,
                harvestMechanic: .snipStem,
                normalPalette: [GRGB(0x9C7BEA), GRGB(0xB894FF), GRGB(0x7C6CE6), GRGB(0xC7A6FF)]
            )
        case .tomato:
            return SpeciesSpec(
                growthDuration: 4.8,
                yieldCount: 3,
                harvestMechanic: .shakeVine,
                normalPalette: [GRGB(0xF2392C), GRGB(0xFF5638), GRGB(0xE63046), GRGB(0xFF6B42)]
            )
        case .sunflower:
            return SpeciesSpec(
                growthDuration: 5.4,
                yieldCount: 1,
                harvestMechanic: .snipStem,
                normalPalette: [GRGB(0xFFC928), GRGB(0xFFAE2B), GRGB(0xFFE052), GRGB(0xF59624)]
            )
        case .pumpkin:
            return SpeciesSpec(
                growthDuration: 6.0,
                yieldCount: 1,
                harvestMechanic: .waterPuff,
                normalPalette: [GRGB(0xF78A1E), GRGB(0xFF9E32), GRGB(0xE6741A), GRGB(0xF2B138)]
            )
        }
    }

    static func hybridSpec(_ hybrid: HybridKind) -> SpeciesSpec {
        switch hybrid {
        case .starlightRose:
            return SpeciesSpec(
                growthDuration: 4.0,
                yieldCount: 1,
                harvestMechanic: .snipStem,
                normalPalette: [hybrid.primaryColor, hybrid.accentColor]
            )
        case .cottonSunflower:
            return SpeciesSpec(
                growthDuration: 5.4,
                yieldCount: 1,
                harvestMechanic: .snipStem,
                normalPalette: [hybrid.primaryColor, hybrid.accentColor]
            )
        case .moonberryTulip:
            return SpeciesSpec(
                growthDuration: 3.6,
                yieldCount: 1,
                harvestMechanic: .snipStem,
                normalPalette: [hybrid.primaryColor, hybrid.accentColor]
            )
        case .rainbowLavender:
            return SpeciesSpec(
                growthDuration: 4.2,
                yieldCount: 2,
                harvestMechanic: .snipStem,
                normalPalette: [hybrid.primaryColor, hybrid.accentColor]
            )
        case .crystalPumpkin:
            return SpeciesSpec(
                growthDuration: 6.0,
                yieldCount: 1,
                harvestMechanic: .waterPuff,
                normalPalette: [hybrid.primaryColor, hybrid.accentColor]
            )
        case .sparkleBerryVine:
            return SpeciesSpec(
                growthDuration: 4.6,
                yieldCount: 3,
                harvestMechanic: .shakeVine,
                normalPalette: [hybrid.primaryColor, hybrid.accentColor]
            )
        }
    }
}

enum PlantKind: String, Codable, CaseIterable, Hashable {
    case sunflower, tulip, daisy, lavender, carrot, tomato, strawberry, pumpkin

    var spec: SpeciesSpec { SpeciesCatalog.classicSpec(self) }

    var isFlower: Bool {
        switch self {
        case .sunflower, .tulip, .daisy, .lavender: return true
        default: return false
        }
    }

    var height: CGFloat {
        switch self {
        case .sunflower: return 232
        case .tulip: return 138
        case .daisy: return 116
        case .lavender: return 132
        case .carrot: return 90
        case .tomato: return 186
        case .strawberry: return 72
        case .pumpkin: return 88
        }
    }

    var reach: CGFloat {
        switch self {
        case .sunflower: return 48
        case .tomato: return 54
        case .pumpkin: return 64
        default: return 44
        }
    }

    var pulled: Bool { spec.harvestMechanic == .pullUp }
    var crop: Int { spec.yieldCount }
    var growthDuration: Double { spec.growthDuration }
    var harvestMechanic: HarvestMechanic { spec.harvestMechanic }

    var packet: (GRGB, GRGB) {
        switch self {
        case .sunflower: return (GRGB(0xFFD54A), GRGB(0x8A5A2B))
        case .tulip: return (GRGB(0xFF8FB8), GRGB(0x4FA35A))
        case .daisy: return (GRGB(0xFFF6D8), GRGB(0xF4C430))
        case .lavender: return (GRGB(0xC9B6FF), GRGB(0x7A5BD0))
        case .carrot: return (GRGB(0xFFB36B), GRGB(0x56A84B))
        case .tomato: return (GRGB(0xFF7A6B), GRGB(0x4E9A47))
        case .strawberry: return (GRGB(0xFF9AAE), GRGB(0xE8364F))
        case .pumpkin: return (GRGB(0xFFB45C), GRGB(0xD9731F))
        }
    }

    var seedColor: GRGB {
        switch self {
        case .sunflower: return GRGB(0x3B332C)
        case .pumpkin: return GRGB(0xF4E7C5)
        case .tomato, .strawberry: return GRGB(0xE9D9A6)
        case .lavender: return GRGB(0x4A3B2F)
        default: return GRGB(0xC79A5B)
        }
    }

    func bloom(_ v: Int) -> GRGB {
        if v >= Plant.specialVariant { return specialColor }
        let pal = spec.normalPalette
        return pal[abs(v) % pal.count]
    }

    var specialColor: GRGB {
        switch self {
        case .sunflower: return GRGB(0xFF8CC6)
        case .tulip: return GRGB(0x4FC3F7)
        case .daisy: return GRGB(0xA8F5FF)
        case .lavender: return GRGB(0xFF7EC8)
        case .carrot: return GRGB(0x8E4FD8)
        case .tomato: return GRGB(0xFFC21E)
        case .strawberry: return GRGB(0xFFF1EA)
        case .pumpkin: return GRGB(0xFF9A2E)
        }
    }
}

enum HybridKind: String, CaseIterable, Codable, Equatable, Hashable {
    case starlightRose
    case cottonSunflower
    case moonberryTulip
    case rainbowLavender
    case crystalPumpkin
    case sparkleBerryVine

    var spec: SpeciesSpec { SpeciesCatalog.hybridSpec(self) }

    var parents: (PlantKind, PlantKind) {
        switch self {
        case .starlightRose: return (.tulip, .daisy)
        case .cottonSunflower: return (.lavender, .sunflower)
        case .moonberryTulip: return (.tulip, .strawberry)
        case .rainbowLavender: return (.sunflower, .lavender)
        case .crystalPumpkin: return (.pumpkin, .daisy)
        case .sparkleBerryVine: return (.strawberry, .tomato)
        }
    }

    var isFlower: Bool {
        switch self {
        case .starlightRose, .cottonSunflower, .moonberryTulip, .rainbowLavender: return true
        case .crystalPumpkin, .sparkleBerryVine: return false
        }
    }

    var height: CGFloat {
        switch self {
        case .starlightRose: return 152
        case .cottonSunflower: return 236
        case .moonberryTulip: return 148
        case .rainbowLavender: return 146
        case .crystalPumpkin: return 96
        case .sparkleBerryVine: return 174
        }
    }

    var reach: CGFloat {
        switch self {
        case .crystalPumpkin: return 68
        case .cottonSunflower, .sparkleBerryVine: return 56
        default: return 48
        }
    }

    var crop: Int { spec.yieldCount }
    var harvestMechanic: HarvestMechanic { spec.harvestMechanic }

    var primaryColor: GRGB {
        switch self {
        case .starlightRose: return GRGB(0xFF7CB4)
        case .cottonSunflower: return GRGB(0xFFB3D9)
        case .moonberryTulip: return GRGB(0x9A6BFF)
        case .rainbowLavender: return GRGB(0x7EC8FF)
        case .crystalPumpkin: return GRGB(0x9BE5FF)
        case .sparkleBerryVine: return GRGB(0xFFD054)
        }
    }

    var accentColor: GRGB {
        switch self {
        case .starlightRose: return GRGB(0xFFE07A)
        case .cottonSunflower: return GRGB(0xA6F0E0)
        case .moonberryTulip: return GRGB(0xFFE99A)
        case .rainbowLavender: return GRGB(0xFFB0D6)
        case .crystalPumpkin: return GRGB(0xFFE799)
        case .sparkleBerryVine: return GRGB(0xFF6B9A)
        }
    }

    static func cross(from donor: PlantKind, onto target: PlantKind) -> HybridKind? {
        guard donor != target else { return nil }
        switch (donor, target) {
        case (.tulip, .daisy), (.daisy, .tulip):
            return .starlightRose
        case (.lavender, .sunflower):
            return .cottonSunflower
        case (.sunflower, .lavender):
            return .rainbowLavender
        case (.tulip, .strawberry), (.strawberry, .tulip):
            return .moonberryTulip
        case (.pumpkin, .daisy), (.daisy, .pumpkin), (.pumpkin, .tulip), (.tulip, .pumpkin):
            return .crystalPumpkin
        case (.strawberry, .tomato), (.tomato, .strawberry):
            return .sparkleBerryVine
        default:
            break
        }
        if target == .pumpkin || donor == .pumpkin { return .crystalPumpkin }
        switch target {
        case .sunflower: return .cottonSunflower
        case .lavender: return .rainbowLavender
        case .strawberry, .tomato: return .sparkleBerryVine
        case .tulip: return .moonberryTulip
        case .daisy, .carrot: return .starlightRose
        case .pumpkin: return .crystalPumpkin
        }
    }
}

enum GardenSeason: String, Codable, CaseIterable, Equatable {
    case spring, summer, autumn, winter

    var next: GardenSeason {
        let all = GardenSeason.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }

    var tint: Color {
        switch self {
        case .spring: return Color(hex: 0xFF8FB8)
        case .summer: return Color(hex: 0x58BE5A)
        case .autumn: return Color(hex: 0xF08B36)
        case .winter: return Color(hex: 0x6EBDF6)
        }
    }
}

struct Plant: Codable, Equatable {
    var kind: PlantKind
    var growth: Double = 0
    var left: Int = 0
    var variant: Int = 0
    var giant: Bool = false
    var hybrid: HybridKind? = nil
    var rainbowCharged: Bool = false

    static let specialVariant = 100
    var isSpecial: Bool { variant >= Plant.specialVariant }
    var specialTint: GRGB? { isSpecial ? kind.specialColor : nil }
    var effectiveIsFlower: Bool { hybrid?.isFlower ?? kind.isFlower }
    var effectiveReach: CGFloat { hybrid?.reach ?? kind.reach }
    var effectiveCrop: Int { hybrid?.crop ?? kind.crop }

    init(
        kind: PlantKind,
        growth: Double = 0,
        left: Int = 0,
        variant: Int = 0,
        giant: Bool = false,
        hybrid: HybridKind? = nil,
        rainbowCharged: Bool = false
    ) {
        self.kind = kind
        self.growth = growth
        self.left = left
        self.variant = variant
        self.giant = giant
        self.hybrid = hybrid
        self.rainbowCharged = rainbowCharged
    }

    private enum CodingKeys: String, CodingKey {
        case kind, growth, left, variant, giant, hybrid, rainbowCharged
    }

    // Old garden.json saves omit `giant`, `hybrid`, and `rainbowCharged`; decode cleanly with defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(PlantKind.self, forKey: .kind)
        growth = try c.decodeIfPresent(Double.self, forKey: .growth) ?? 0
        left = try c.decodeIfPresent(Int.self, forKey: .left) ?? 0
        variant = try c.decodeIfPresent(Int.self, forKey: .variant) ?? 0
        giant = try c.decodeIfPresent(Bool.self, forKey: .giant) ?? false
        hybrid = try c.decodeIfPresent(HybridKind.self, forKey: .hybrid)
        rainbowCharged = try c.decodeIfPresent(Bool.self, forKey: .rainbowCharged) ?? false
    }
}

struct GrowingPlant: Codable, Equatable {
    var kind: PlantKind
    var growth: Double
    var variant: Int
    var hybrid: HybridKind? = nil

    init(kind: PlantKind, growth: Double = 0.08, variant: Int = 0, hybrid: HybridKind? = nil) {
        self.kind = kind
        self.growth = max(0, min(0.9999, growth))
        self.variant = variant
        self.hybrid = hybrid
    }

    var species: HarvestSpecies { hybrid.map { .hybrid($0) } ?? .classic(kind) }
    var isSpecial: Bool { variant >= Plant.specialVariant }
    var effectiveIsFlower: Bool { hybrid?.isFlower ?? kind.isFlower }
    var effectiveReach: CGFloat { hybrid?.reach ?? kind.reach }
    var growthDuration: Double { species.spec.growthDuration }
}

struct RipePlant: Codable, Equatable {
    var kind: PlantKind
    var variant: Int
    var yieldLeft: Int
    var isGiant: Bool = false
    var hybrid: HybridKind? = nil
    var rainbowCharged: Bool = false
    var waterPuffProgress: CGFloat = 0
    var shakeProgress: CGFloat = 0

    init(
        kind: PlantKind,
        variant: Int = 0,
        yieldLeft: Int? = nil,
        isGiant: Bool = false,
        hybrid: HybridKind? = nil,
        rainbowCharged: Bool = false,
        waterPuffProgress: CGFloat = 0,
        shakeProgress: CGFloat = 0
    ) {
        self.kind = kind
        self.variant = variant
        let defaultYield = hybrid?.crop ?? kind.crop
        self.yieldLeft = max(1, yieldLeft ?? defaultYield)
        self.isGiant = isGiant
        self.hybrid = hybrid
        self.rainbowCharged = rainbowCharged
        self.waterPuffProgress = waterPuffProgress
        self.shakeProgress = shakeProgress
    }

    var species: HarvestSpecies { hybrid.map { .hybrid($0) } ?? .classic(kind) }
    var isSpecial: Bool { variant >= Plant.specialVariant }
    var effectiveIsFlower: Bool { hybrid?.isFlower ?? kind.isFlower }
    var effectiveReach: CGFloat { hybrid?.reach ?? kind.reach }
    var maxYield: Int { species.spec.yieldCount }
    var harvestMechanic: HarvestMechanic { species.spec.harvestMechanic }
}

enum BuriedSurprise: String, Codable, Equatable, CaseIterable {
    case worm, ladybug, mysteryBulb, coins

    static func random() -> BuriedSurprise {
        allCases.randomElement() ?? .coins
    }
}

enum PlotStage: Equatable {
    case empty(surprise: BuriedSurprise, surpriseReady: Bool)
    case growing(GrowingPlant)
    case ripe(RipePlant)
}

enum PollinationState: Equatable {
    case idle
    case carrying(donorPlot: Int, donorKind: PlantKind, point: CGPoint, tapMode: Bool)
}

enum HarvestSource: Codable, Equatable, Hashable {
    case plant(kind: PlantKind, variant: Int, isGiant: Bool)
    case hybrid(kind: HybridKind, isGiant: Bool)

    var species: HarvestSpecies {
        switch self {
        case .plant(let kind, _, _): return .classic(kind)
        case .hybrid(let kind, _): return .hybrid(kind)
        }
    }

    var isFlower: Bool { species.isFlower }

    var isGiant: Bool {
        switch self {
        case .plant(_, _, let giant): return giant
        case .hybrid(_, let giant): return giant
        }
    }

    var isSpecial: Bool {
        switch self {
        case .plant(_, let variant, _): return variant >= Plant.specialVariant
        case .hybrid: return true
        }
    }

    var displayColor: GRGB {
        switch self {
        case .plant(let kind, let variant, _): return kind.bloom(variant)
        case .hybrid(let kind, _): return kind.primaryColor
        }
    }
}

struct HarvestItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var source: HarvestSource

    init(id: UUID = UUID(), source: HarvestSource) {
        self.id = id
        self.source = source
    }

    var species: HarvestSpecies { source.species }
    var isFlower: Bool { source.isFlower }
    var isGiant: Bool { source.isGiant }
    var isSpecial: Bool { source.isSpecial }
    var isEdibleProduce: Bool { !source.isFlower }

    var isJamProduce: Bool {
        switch source {
        case .plant(let kind, _, _):
            return kind == .strawberry || kind == .tomato || kind == .carrot || kind == .pumpkin
        case .hybrid(let kind, _):
            return kind == .sparkleBerryVine || kind == .crystalPumpkin
        }
    }
}

struct BouquetFlower: Codable, Equatable {
    var kind: PlantKind
    var variant: Int
    var hybrid: HybridKind? = nil

    init(kind: PlantKind, variant: Int, hybrid: HybridKind? = nil) {
        self.kind = kind
        self.variant = variant
        self.hybrid = hybrid
    }

    private enum CodingKeys: String, CodingKey {
        case kind, variant, hybrid
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(PlantKind.self, forKey: .kind)
        variant = try c.decodeIfPresent(Int.self, forKey: .variant) ?? 0
        hybrid = try c.decodeIfPresent(HybridKind.self, forKey: .hybrid)
    }
}

enum DecorKind: String, Codable, CaseIterable {
    case pinwheel, lantern, mushroom, flamingo, birdbath, birdhouse, bunny, flag
    case crystal, rainbow, unicorn, lotus

    var treasure: String? {
        switch self {
        case .crystal, .rainbow, .unicorn, .lotus: return "garden/\(rawValue)"
        default: return nil
        }
    }

    static var available: [DecorKind] {
        allCases.filter { k in k.treasure.map { Coins.shared.owns($0) } ?? true }
    }

    var size: CGSize {
        switch self {
        case .pinwheel: return CGSize(width: 70, height: 150)
        case .lantern: return CGSize(width: 50, height: 150)
        case .mushroom: return CGSize(width: 76, height: 70)
        case .flamingo: return CGSize(width: 70, height: 140)
        case .birdbath: return CGSize(width: 104, height: 96)
        case .birdhouse: return CGSize(width: 64, height: 170)
        case .bunny: return CGSize(width: 60, height: 76)
        case .flag: return CGSize(width: 70, height: 140)
        case .crystal: return TreasureArt.crystalSize
        case .rainbow: return TreasureArt.rainbowSize
        case .unicorn: return TreasureArt.unicornSize
        case .lotus: return CGSize(width: 88, height: 112)
        }
    }
}

enum Weather: String, Codable, CaseIterable {
    case sun, rain, wind, night

    var symbol: String {
        switch self {
        case .sun: return "sun.max.fill"
        case .rain: return "cloud.rain.fill"
        case .wind: return "wind"
        case .night: return "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .sun: return Color(hex: 0xFFB300)
        case .rain: return Color(hex: 0x4F8FE0)
        case .wind: return Color(hex: 0x3FB6A8)
        case .night: return Color(hex: 0x6A5BD0)
        }
    }
}

struct WeedSave: Codable, Equatable {
    var x: Double
    var growth: Double
    var seed: Int
}

struct DecorSave: Codable, Equatable {
    var kind: DecorKind
    var x: Double
    var water: Double = 0
}

struct GardenSave: Codable, Equatable {
    var plots: [Plant?]
    var soil: [Double]
    var wet: [Double]
    var weeds: [WeedSave]
    var decor: [DecorSave]
    var basket: [String]
    var weather: Weather
    var bouquet: [BouquetFlower]? = nil
    var discoveredHybrids: [HybridKind]? = nil
    var treehouseStage: Int? = nil
    var picnicFeedCount: Int? = nil
    var season: GardenSeason? = nil
    var caughtFireflies: Int? = nil
    var harvestInventory: [HarvestItem]? = nil
    var farmstandServedCount: Int? = nil
    var activeOrder: FarmstandOrder? = nil

    init(
        plots: [Plant?],
        soil: [Double],
        wet: [Double],
        weeds: [WeedSave],
        decor: [DecorSave],
        basket: [String],
        weather: Weather,
        bouquet: [BouquetFlower]? = nil,
        discoveredHybrids: [HybridKind]? = nil,
        treehouseStage: Int? = nil,
        picnicFeedCount: Int? = nil,
        season: GardenSeason? = nil,
        caughtFireflies: Int? = nil,
        harvestInventory: [HarvestItem]? = nil,
        farmstandServedCount: Int? = nil,
        activeOrder: FarmstandOrder? = nil
    ) {
        self.plots = plots
        self.soil = soil
        self.wet = wet
        self.weeds = weeds
        self.decor = decor
        self.basket = basket
        self.weather = weather
        self.bouquet = bouquet
        self.discoveredHybrids = discoveredHybrids
        self.treehouseStage = treehouseStage
        self.picnicFeedCount = picnicFeedCount
        self.season = season
        self.caughtFireflies = caughtFireflies
        self.harvestInventory = harvestInventory
        self.farmstandServedCount = farmstandServedCount
        self.activeOrder = activeOrder
    }

    private enum CodingKeys: String, CodingKey {
        case plots, soil, wet, weeds, decor, basket, weather, bouquet
        case discoveredHybrids, treehouseStage, picnicFeedCount, season, caughtFireflies
        case harvestInventory, farmstandServedCount, activeOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plots = try c.decode([Plant?].self, forKey: .plots)
        soil = try c.decode([Double].self, forKey: .soil)
        wet = try c.decode([Double].self, forKey: .wet)
        weeds = try c.decode([WeedSave].self, forKey: .weeds)
        decor = try c.decode([DecorSave].self, forKey: .decor)
        basket = try c.decode([String].self, forKey: .basket)
        weather = try c.decode(Weather.self, forKey: .weather)
        bouquet = try c.decodeIfPresent([BouquetFlower].self, forKey: .bouquet)
        discoveredHybrids = try c.decodeIfPresent([HybridKind].self, forKey: .discoveredHybrids)
        treehouseStage = try c.decodeIfPresent(Int.self, forKey: .treehouseStage)
        picnicFeedCount = try c.decodeIfPresent(Int.self, forKey: .picnicFeedCount)
        season = try c.decodeIfPresent(GardenSeason.self, forKey: .season)
        caughtFireflies = try c.decodeIfPresent(Int.self, forKey: .caughtFireflies)
        harvestInventory = try c.decodeIfPresent([HarvestItem].self, forKey: .harvestInventory)
        farmstandServedCount = try c.decodeIfPresent(Int.self, forKey: .farmstandServedCount)
        activeOrder = try c.decodeIfPresent(FarmstandOrder.self, forKey: .activeOrder)
    }

    private struct LegacyFlowerKey: Hashable {
        var kind: PlantKind?
        var variant: Int
        var hybrid: HybridKind?
    }

    func resolvedInventory(maxCount: Int = 60) -> [HarvestItem] {
        if let typed = harvestInventory {
            return Array(typed.suffix(maxCount))
        }
        var items: [HarvestItem] = []
        var flowerCounts: [LegacyFlowerKey: Int] = [:]

        for entry in basket {
            guard let source = GardenSave.decodeLegacyBasketEntry(entry) else { continue }
            items.append(HarvestItem(source: source))
            if source.isFlower {
                let key = GardenSave.flowerKey(for: source)
                flowerCounts[key, default: 0] += 1
            }
        }

        for flower in bouquet ?? [] {
            let key = LegacyFlowerKey(
                kind: flower.hybrid == nil ? flower.kind : nil,
                variant: flower.hybrid == nil ? flower.variant : 0,
                hybrid: flower.hybrid
            )
            if let remaining = flowerCounts[key], remaining > 0 {
                flowerCounts[key] = remaining - 1
                continue
            }
            if let hybrid = flower.hybrid {
                items.append(HarvestItem(source: .hybrid(kind: hybrid, isGiant: false)))
            } else {
                items.append(HarvestItem(source: .plant(kind: flower.kind, variant: flower.variant, isGiant: false)))
            }
        }
        return Array(items.suffix(maxCount))
    }

    static func encodeLegacyBasket(_ items: [HarvestItem]) -> [String] {
        items.suffix(40).map { item in
            switch item.source {
            case .plant(let kind, let variant, _):
                return "\(kind.rawValue):\(variant)"
            case .hybrid(let kind, _):
                return "hybrid:\(kind.rawValue)"
            }
        }
    }

    static func encodeLegacyBouquet(_ items: [HarvestItem], maxCount: Int) -> [BouquetFlower]? {
        let flowers: [BouquetFlower] = items.filter(\.isFlower).suffix(maxCount).map { item in
            switch item.source {
            case .plant(let kind, let variant, _):
                return BouquetFlower(kind: kind, variant: variant)
            case .hybrid(let hybrid, _):
                return BouquetFlower(kind: hybrid.parents.0, variant: 0, hybrid: hybrid)
            }
        }
        return flowers.isEmpty ? nil : flowers
    }

    static func stage(from legacyPlant: Plant?, defaultSurprise: BuriedSurprise) -> PlotStage {
        guard let p = legacyPlant else {
            return .empty(surprise: defaultSurprise, surpriseReady: true)
        }
        if p.growth >= 1 {
            // Self-heal broken legacy plots that saved ripe growth with zero remaining yield.
            guard p.left > 0 else {
                return .empty(surprise: defaultSurprise, surpriseReady: true)
            }
            return .ripe(
                RipePlant(
                    kind: p.kind,
                    variant: p.variant,
                    yieldLeft: p.left,
                    isGiant: p.giant,
                    hybrid: p.hybrid,
                    rainbowCharged: p.rainbowCharged
                )
            )
        }
        return .growing(GrowingPlant(kind: p.kind, growth: p.growth, variant: p.variant, hybrid: p.hybrid))
    }

    private static func decodeLegacyBasketEntry(_ entry: String) -> HarvestSource? {
        let parts = entry.split(separator: ":")
        guard let head = parts.first else { return nil }
        if head == "hybrid", parts.count > 1, let hybrid = HybridKind(rawValue: String(parts[1])) {
            return .hybrid(kind: hybrid, isGiant: false)
        }
        guard let kind = PlantKind(rawValue: String(head)) else { return nil }
        let variant = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        return .plant(kind: kind, variant: variant, isGiant: false)
    }

    private static func flowerKey(for source: HarvestSource) -> LegacyFlowerKey {
        switch source {
        case .plant(let kind, let variant, _):
            return LegacyFlowerKey(kind: kind, variant: variant, hybrid: nil)
        case .hybrid(let hybrid, _):
            return LegacyFlowerKey(kind: nil, variant: 0, hybrid: hybrid)
        }
    }
}

/// Fixed coordinates in the 1024 x 834 garden design canvas.
enum GGeo {
    static let bedLeft: CGFloat = 52
    static let bedRight: CGFloat = 820
    static let soilY: CGFloat = 524
    static let bedBottom: CGFloat = 606
    static let col: CGFloat = 4
    static let columns = 192
    static let maxDepth: CGFloat = 26
    static let plotX: [CGFloat] = [116, 244, 372, 500, 628, 756]

    static let fenceTopY: CGFloat = 408
    static let yardY: CGFloat = 496
    static let yardMinX: CGFloat = 64
    static let yardMaxX: CGFloat = 956

    static let sunPos = CGPoint(x: 192, y: 154)
    static let treehouse = CGPoint(x: 874, y: 396)

    static let benchRect = CGRect(x: 842, y: 572, width: 164, height: 18)
    static let fireflyJar = CGPoint(x: 862, y: 570)
    static let vase = CGPoint(x: 916, y: 570)
    static let flowerCrownSpot = CGPoint(x: 974, y: 566)

    static let lawnY: CGFloat = 614
    static let basket = CGPoint(x: 132, y: 756)
    static let picnic = CGPoint(x: 854, y: 696)
    static let picnicSize = CGSize(width: 158, height: 74)
    static let returnBadge = CGPoint(x: 932, y: 740)
    static let dockY: CGFloat = GameChromeLayout.dockY
    static let trayY: CGFloat = 636

    enum Farmstand {
        static let counterTopY: CGFloat = 486
        static let counterRect = CGRect(x: 78, y: 486, width: 868, height: 146)
        static let customerSeat = CGPoint(x: 236, y: 468)
        static let orderBubbleCenter = CGPoint(x: 242, y: 246)
        static let craftCenter = CGPoint(x: 548, y: 438)
        static let craftDropZone = CGRect(x: 408, y: 230, width: 280, height: 266)
        static let spritzHome = CGPoint(x: 734, y: 392)
        static let plungerTopY: CGFloat = 292
        static let plungerTravelY: CGFloat = 92
        static let serveBell = CGPoint(x: 854, y: 428)
        static let serveBellRadius: CGFloat = 52

        static let bouquetSlotOffsets: [CGPoint] = [
            CGPoint(x: -44, y: -74),
            CGPoint(x: 0, y: -92),
            CGPoint(x: 44, y: -74),
        ]

        static let basketSlotOffsets: [CGPoint] = [
            CGPoint(x: -60, y: -16),
            CGPoint(x: 0, y: -26),
            CGPoint(x: 60, y: -16),
        ]

        static let wrapSwatchCenters: [CGPoint] = (0..<5).map { i in
            CGPoint(x: 344 + CGFloat(i) * 48, y: 562)
        }

        static let ribbonSwatchCenters: [CGPoint] = (0..<5).map { i in
            CGPoint(x: 612 + CGFloat(i) * 48, y: 562)
        }

        static let lidSwatchCenters: [CGPoint] = (0..<5).map { i in
            CGPoint(x: 436 + CGFloat(i) * 56, y: 562)
        }
    }

    static func colX(_ i: Int) -> CGFloat { bedLeft + col * CGFloat(i) + col / 2 }
    static func column(_ x: CGFloat) -> Int { Int(((x - bedLeft) / col).rounded(.down)) }
    static func inBed(_ x: CGFloat) -> Bool { x >= bedLeft && x <= bedRight }
}
