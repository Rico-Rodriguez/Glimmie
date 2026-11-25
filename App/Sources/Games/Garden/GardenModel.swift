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

enum PlantKind: String, Codable, CaseIterable {
    case sunflower, tulip, daisy, lavender, carrot, tomato, strawberry, pumpkin

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

    var pulled: Bool { self == .carrot }

    var crop: Int {
        switch self {
        case .tomato: return 4
        case .strawberry: return 3
        case .pumpkin, .carrot: return 1
        case .daisy, .lavender: return 2
        case .sunflower, .tulip: return 1
        }
    }

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
        switch self {
        case .sunflower: return GRGB(0xFFC928)
        case .tulip: return [GRGB(0xFF4F7B), GRGB(0xFF9A3D), GRGB(0xC86BFF), GRGB(0xFFD23F)][abs(v) % 4]
        case .daisy: return [GRGB(0xFFFFFF), GRGB(0xFFC2DA), GRGB(0xFFF0A0)][abs(v) % 3]
        case .lavender: return GRGB(0x9C7BEA)
        case .carrot: return GRGB(0xFF8A2A)
        case .tomato: return GRGB(0xF2392C)
        case .strawberry: return GRGB(0xE8263F)
        case .pumpkin: return GRGB(0xF78A1E)
        }
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

enum HybridKind: String, CaseIterable, Codable, Equatable {
    case starlightRose
    case cottonSunflower
    case moonberryTulip
    case rainbowLavender
    case crystalPumpkin
    case sparkleBerryVine

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

    var crop: Int {
        switch self {
        case .sparkleBerryVine: return 3
        case .rainbowLavender: return 2
        default: return 1
        }
    }

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
        // Any two distinct ripe species cross-breed into a matching hybrid so exploration always delights.
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

enum BuriedSurprise: String, Codable, Equatable, CaseIterable {
    case worm, ladybug, mysteryBulb, coins

    static func random() -> BuriedSurprise {
        allCases.randomElement() ?? .coins
    }
}

enum GardenPlotState: Equatable {
    case empty(surprise: BuriedSurprise)
    case growing(Plant)
    case ripe(Plant)
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
        caughtFireflies: Int? = nil
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
    }

    private enum CodingKeys: String, CodingKey {
        case plots, soil, wet, weeds, decor, basket, weather, bouquet
        case discoveredHybrids, treehouseStage, picnicFeedCount, season, caughtFireflies
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

    static func colX(_ i: Int) -> CGFloat { bedLeft + col * CGFloat(i) + col / 2 }
    static func column(_ x: CGFloat) -> Int { Int(((x - bedLeft) / col).rounded(.down)) }
    static func inBed(_ x: CGFloat) -> Bool { x >= bedLeft && x <= bedRight }
}
