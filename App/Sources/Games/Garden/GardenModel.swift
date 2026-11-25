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

struct Plant: Codable, Equatable {
    var kind: PlantKind
    var growth: Double = 0
    var left: Int = 0
    var variant: Int = 0
    var giant: Bool = false

    static let specialVariant = 100
    var isSpecial: Bool { variant >= Plant.specialVariant }
    var specialTint: GRGB? { isSpecial ? kind.specialColor : nil }

    init(kind: PlantKind, growth: Double = 0, left: Int = 0, variant: Int = 0, giant: Bool = false) {
        self.kind = kind
        self.growth = growth
        self.left = left
        self.variant = variant
        self.giant = giant
    }

    private enum CodingKeys: String, CodingKey {
        case kind, growth, left, variant, giant
    }

    // Old garden.json saves omit `giant`; decode cleanly with default false.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(PlantKind.self, forKey: .kind)
        growth = try c.decodeIfPresent(Double.self, forKey: .growth) ?? 0
        left = try c.decodeIfPresent(Int.self, forKey: .left) ?? 0
        variant = try c.decodeIfPresent(Int.self, forKey: .variant) ?? 0
        giant = try c.decodeIfPresent(Bool.self, forKey: .giant) ?? false
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

    static let benchRect = CGRect(x: 838, y: 572, width: 158, height: 18)
    static let vase = CGPoint(x: 916, y: 570)

    static let lawnY: CGFloat = 614
    static let basket = CGPoint(x: 132, y: 786)
    static let returnBadge = CGPoint(x: 932, y: 766)
    static let dockY: CGFloat = GameChromeLayout.dockY
    static let trayY: CGFloat = 668

    static func colX(_ i: Int) -> CGFloat { bedLeft + col * CGFloat(i) + col / 2 }
    static func column(_ x: CGFloat) -> Int { Int(((x - bedLeft) / col).rounded(.down)) }
    static func inBed(_ x: CGFloat) -> Bool { x >= bedLeft && x <= bedRight }
}
