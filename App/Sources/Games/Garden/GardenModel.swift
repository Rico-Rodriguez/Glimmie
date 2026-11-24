import SwiftUI

// MARK: - Garden: what grows, what decorates, what is saved

/// A stable pseudo-random number in 0..<1 for (i, salt). The garden's own, so it never depends on another game.
func gdRand(_ i: Int, _ salt: Int) -> CGFloat {
    var x = UInt64(bitPattern: Int64((i &* 92_837_111) ^ (salt &* 689_287_499))) &+ 0x9E37_79B9_7F4A_7C15
    x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
    x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
    x ^= x >> 31
    return CGFloat(x % 100_000) / 100_000
}

/// 0...1 clamped smoothstep.
func gdEase(_ t: CGFloat) -> CGFloat {
    let x = max(0, min(1, t))
    return x * x * (3 - 2 * x)
}

func gdClamp(_ t: CGFloat) -> CGFloat { max(0, min(1, t)) }

/// A plain sRGB color that can be mixed and shaded.
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

    /// k < 0 darkens toward a deeper version of the color, k > 0 lightens toward white.
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

    /// How tall it gets above the soil, in design points.
    var height: CGFloat {
        switch self {
        case .sunflower: return 300
        case .tulip: return 150
        case .daisy: return 120
        case .lavender: return 140
        case .carrot: return 96
        case .tomato: return 214
        case .strawberry: return 72
        case .pumpkin: return 96
        }
    }

    /// Half the width it takes up, for touches.
    var reach: CGFloat {
        switch self {
        case .sunflower: return 48
        case .tomato: return 56
        case .pumpkin: return 66
        default: return 44
        }
    }

    /// Harvested by pulling it up out of the soil instead of tapping.
    var pulled: Bool { self == .carrot }

    /// How many to pick when it is ripe.
    var crop: Int {
        switch self {
        case .tomato: return 4
        case .strawberry: return 3
        case .pumpkin, .carrot: return 1
        case .daisy, .lavender: return 2
        case .sunflower, .tulip: return 1
        }
    }

    /// The seed packet's colors (paper, picture band).
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

    /// Petal or fruit color (variant v picks among a few for tulips and daisies).
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
}

extension PlantKind {
    /// The color of the rare special one (see GardenFinds): a pink sunflower, a blue tulip, a glowing daisy,
    /// pink lavender, a purple carrot, a golden tomato, a white strawberry and a giant pumpkin.
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
    /// 0 is a seed, 1 is in full bloom or ripe.
    var growth: Double = 0
    /// Ripe things still on the plant (fruit, blooms).
    var left: Int = 0
    /// Color variant. `specialVariant` and up is the rare special one (see GardenFinds).
    var variant: Int = 0

    static let specialVariant = 100
    var isSpecial: Bool { variant >= Plant.specialVariant }
    /// The special one's fruit color, for the painters (nil draws the usual color).
    var specialTint: GRGB? { isSpecial ? kind.specialColor : nil }
}

enum DecorKind: String, Codable, CaseIterable {
    case pinwheel, lantern, mushroom, flamingo, birdbath, birdhouse, bunny, flag
    // extras from the treasure shop (see `Treasures`): in the tray only once bought
    case crystal, rainbow, unicorn

    /// The treasure shop id for an extra, nil for the free ones.
    var treasure: String? {
        switch self {
        case .crystal, .rainbow, .unicorn: return "garden/\(rawValue)"
        default: return nil
        }
    }

    /// What the decorations tray shows: every free piece, then the extras she has bought.
    static var available: [DecorKind] {
        allCases.filter { k in k.treasure.map { Coins.shared.owns($0) } ?? true }
    }

    /// Height of the piece above the ground, for touches and the drop.
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

/// garden.json in the game's save folder.
struct GardenStamp: Codable, Equatable {
    let kind: PlantKind
    let variant: Int
    // Fractions of the printable area, so a design fits different screens.
    var x: Double
    var y: Double
}

struct GardenSave: Codable, Equatable {
    var plots: [Plant?]
    var soil: [Double]
    var wet: [Double]
    var weeds: [WeedSave]
    var decor: [DecorSave]
    var basket: [String]
    var weather: Weather
    var stamps: [GardenStamp]? = nil
    var channels: [Int]? = nil
}

/// Fixed places in the garden scene (design points, 1024 x 834).
enum GGeo {
    static let bedLeft: CGFloat = 64
    static let bedRight: CGFloat = 960
    /// Flat soil surface.
    static let soilY: CGFloat = 548
    static let bedBottom: CGFloat = 712
    static let col: CGFloat = 4
    static let columns = 224
    /// The deepest a hole can go.
    static let maxDepth: CGFloat = 54
    static let plotX: [CGFloat] = [139, 288, 437, 587, 736, 885]
    /// The lawn behind the bed, where decorations stand.
    static let yardY: CGFloat = 520
    static let yardMinX: CGFloat = 40
    static let yardMaxX: CGFloat = 984
    /// The front lawn line.
    static let lawnY: CGFloat = 736
    static let basket = CGPoint(x: 914, y: 772)
    static let dockY: CGFloat = 776

    static func colX(_ i: Int) -> CGFloat { bedLeft + col * CGFloat(i) + col / 2 }
    static func column(_ x: CGFloat) -> Int { Int(((x - bedLeft) / col).rounded(.down)) }
    static func inBed(_ x: CGFloat) -> Bool { x >= bedLeft && x <= bedRight }
}
