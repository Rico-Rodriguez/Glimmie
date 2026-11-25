import SwiftUI

func aqRand(_ i: Int, _ salt: Int) -> CGFloat {
    var x = UInt64(bitPattern: Int64((i &* 73_856_093) ^ (salt &* 19_349_663))) &+ 0x9E37_79B9_7F4A_7C15
    x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
    x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
    x ^= x >> 31
    return CGFloat(x % 100_000) / 100_000
}

func aqClamp(_ t: CGFloat) -> CGFloat { max(0, min(1, t)) }

func aqEase(_ t: CGFloat) -> CGFloat {
    let x = aqClamp(t)
    return x * x * (3 - 2 * x)
}

struct ARGB: Equatable {
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

    func mix(_ o: ARGB, _ t: CGFloat) -> ARGB {
        let k = Double(aqClamp(t))
        return ARGB(r: r + (o.r - r) * k, g: g + (o.g - g) * k, b: b + (o.b - b) * k)
    }

    /// k < 0 darkens toward a deeper version of the color so outlines stay soft and never turn black.
    func shade(_ k: Double) -> ARGB {
        if k >= 0 { return mix(ARGB(0xFFFFFF), CGFloat(k)) }
        let d = 1 + k
        return ARGB(r: r * d * 0.94, g: g * d * 0.92, b: b * d)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    func color(_ a: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: max(0, min(1, a))) }
}

// MARK: - Geometry

enum AGeo {
    static let left: CGFloat = 46
    static let right: CGFloat = 978
    static let hoodTop: CGFloat = 96
    static let rimY: CGFloat = 122
    static let waterY: CGFloat = 158
    static let bottomY: CGFloat = 696
    static let dockY: CGFloat = GameChromeLayout.dockY
    static let drawerY: CGFloat = 656

    static let returnBadgeCenter = CGPoint(x: 924, y: 762)
    static let returnBadgeRadius: CGFloat = 68

    static var width: CGFloat { right - left }

    static func sand(_ x: CGFloat) -> CGFloat {
        let a = 7 * sin(x * 0.0105 + 0.6) + 4 * sin(x * 0.027 + 2.1)
        let mound = 20 * exp(-pow((x - 770) / 150, 2))
        let slope = (x - 512) * 0.018
        return 624 + a - mound + slope
    }

    static var tank: CGRect { CGRect(x: left, y: rimY, width: right - left, height: bottomY - rimY) }

    static func swim(half: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat) {
        (left + half + 10, right - half - 10, waterY + 24)
    }

    static func inWater(_ p: CGPoint) -> Bool {
        p.x > left && p.x < right && p.y > waterY - 6 && p.y < sand(p.x)
    }

    static func overTank(_ p: CGPoint) -> Bool {
        p.x > left - 12 && p.x < right + 12 && p.y < bottomY && p.y > 20
    }

    static func inReturnZone(_ p: CGPoint) -> Bool {
        hypot(p.x - returnBadgeCenter.x, p.y - returnBadgeCenter.y) <= returnBadgeRadius
    }

    static let surfaceNodes = 64
    static func nodeX(_ i: Int) -> CGFloat { left + CGFloat(i) / CGFloat(surfaceNodes - 1) * (right - left) }

    /// Soft edge-hugging pastel sea-moss cloud zones so smudges frame the glass without obscuring center fish.
    static let mossPresets: [(center: CGPoint, rx: CGFloat, ry: CGFloat, rotation: CGFloat)] = [
        (CGPoint(x: 112, y: 632), 88, 56, -0.15),
        (CGPoint(x: 90, y: 514), 68, 76, 0.12),
        (CGPoint(x: 86, y: 376), 62, 68, -0.08),
        (CGPoint(x: 108, y: 248), 66, 54, 0.22),
        (CGPoint(x: 266, y: 656), 86, 44, 0.06),
        (CGPoint(x: 758, y: 652), 88, 46, -0.08),
        (CGPoint(x: 912, y: 628), 88, 58, 0.14),
        (CGPoint(x: 932, y: 504), 68, 76, -0.1),
        (CGPoint(x: 934, y: 368), 62, 68, 0.08),
        (CGPoint(x: 912, y: 246), 66, 54, -0.2),
    ]
}

struct AquaMossPatch {
    var center: CGPoint
    var rx: CGFloat
    var ry: CGFloat
    var rotation: CGFloat
    var opacity: CGFloat
    var seed: Int

    static func makeDefault(opacities: [CGFloat]? = nil) -> [AquaMossPatch] {
        AGeo.mossPresets.enumerated().map { idx, preset in
            let op: CGFloat
            if let list = opacities, idx < list.count {
                op = aqClamp(list[idx])
            } else {
                op = 0
            }
            return AquaMossPatch(
                center: preset.center,
                rx: preset.rx,
                ry: preset.ry,
                rotation: preset.rotation,
                opacity: op,
                seed: idx * 17 + 5
            )
        }
    }
}

struct BubbleHoop: Identifiable {
    var id: Int
    var p: CGPoint
    var vx: CGFloat
    var baseY: CGFloat
    var radius: CGFloat = 44
    var age: CGFloat = 0
    var life: CGFloat = 15
    var phase: CGFloat = 0
    var shimmer: CGFloat = 0
    var tricks: Int = 0
    var passedFishIDs: Set<Int> = []
}

// MARK: - Fish

enum FishKind: String, Codable, CaseIterable {
    case goldfish, clownfish, angelfish, tetra, puffer, betta, guppy, seahorse

    var length: CGFloat {
        switch self {
        case .goldfish: return 70
        case .clownfish: return 60
        case .angelfish: return 52
        case .tetra: return 30
        case .puffer: return 52
        case .betta: return 50
        case .guppy: return 32
        case .seahorse: return 30
        }
    }

    var height: CGFloat {
        switch self {
        case .goldfish: return 46
        case .clownfish: return 32
        case .angelfish: return 58
        case .tetra: return 12
        case .puffer: return 42
        case .betta: return 22
        case .guppy: return 13
        case .seahorse: return 74
        }
    }

    var tailLength: CGFloat {
        switch self {
        case .goldfish: return 46
        case .clownfish: return 20
        case .angelfish: return 26
        case .tetra: return 11
        case .puffer: return 14
        case .betta: return 50
        case .guppy: return 30
        case .seahorse: return 0
        }
    }

    var cruise: CGFloat {
        switch self {
        case .goldfish: return 46
        case .clownfish: return 58
        case .angelfish: return 34
        case .tetra: return 72
        case .puffer: return 30
        case .betta: return 34
        case .guppy: return 66
        case .seahorse: return 16
        }
    }

    var topSpeed: CGFloat {
        switch self {
        case .seahorse: return 60
        case .puffer: return 140
        case .angelfish, .betta: return 190
        default: return 260
        }
    }

    var group: Int {
        switch self {
        case .tetra: return 5
        case .guppy: return 3
        default: return 1
        }
    }

    var depth: ClosedRange<CGFloat> {
        switch self {
        case .goldfish: return 0.1...0.8
        case .clownfish: return 0.3...0.85
        case .angelfish: return 0.15...0.65
        case .tetra: return 0.3...0.7
        case .puffer: return 0.45...0.95
        case .betta: return 0.0...0.45
        case .guppy: return 0.0...0.5
        case .seahorse: return 0.4...0.9
        }
    }

    var variants: Int {
        switch self {
        case .goldfish, .betta, .guppy, .seahorse: return 3
        default: return 1
        }
    }

    var schools: Bool { self == .tetra || self == .guppy }
}

struct AquaFishSave: Codable, Equatable {
    var kind: FishKind
    var variant: Int
}

// MARK: - Decorations

enum AquaDecorKind: String, Codable, CaseIterable {
    case castle, chest, diver, bubbler, ship, rock, seaweed, coral, anemone, grass, shell, starfish
    case crystal, rainbowCoral = "coral2", unicorn, koiBridge

    var treasure: String? {
        switch self {
        case .crystal: return "aquarium/crystal"
        case .rainbowCoral: return "aquarium/coral"
        case .unicorn: return "aquarium/unicorn"
        case .koiBridge: return "aquarium/koiBridge"
        default: return nil
        }
    }

    static var available: [AquaDecorKind] {
        allCases.filter { k in k.treasure.map { Coins.shared.owns($0) } ?? true }
    }

    var size: CGSize {
        switch self {
        case .castle: return CGSize(width: 150, height: 170)
        case .chest: return CGSize(width: 96, height: 70)
        case .diver: return CGSize(width: 70, height: 128)
        case .bubbler: return CGSize(width: 64, height: 38)
        case .ship: return CGSize(width: 230, height: 150)
        case .rock: return CGSize(width: 150, height: 96)
        case .seaweed: return CGSize(width: 90, height: 250)
        case .coral: return CGSize(width: 110, height: 110)
        case .anemone: return CGSize(width: 96, height: 76)
        case .grass: return CGSize(width: 110, height: 120)
        case .shell: return CGSize(width: 54, height: 44)
        case .starfish: return CGSize(width: 60, height: 36)
        case .crystal: return TreasureArt.crystalSize
        case .rainbowCoral: return TreasureArt.coralSize
        case .unicorn: return TreasureArt.unicornSize
        case .koiBridge: return CGSize(width: 168, height: 84)
        }
    }

    var density: CGFloat {
        switch self {
        case .rock, .ship, .castle, .koiBridge: return 2.6
        case .chest, .diver, .unicorn, .crystal: return 2.2
        case .bubbler, .shell: return 2.0
        case .coral, .starfish, .rainbowCoral: return 1.6
        case .anemone: return 1.4
        case .seaweed, .grass: return 1.25
        }
    }

    var sways: Bool { self == .seaweed || self == .anemone || self == .grass || self == .rainbowCoral }

    var bubbles: Bool { self == .chest || self == .diver || self == .bubbler || self == .castle || self == .koiBridge }
}

struct AquaDecorSave: Codable, Equatable {
    var kind: AquaDecorKind
    var x: CGFloat
    var flip: Bool
}

struct AquaSave: Codable {
    var fish: [AquaFishSave]
    var decor: [AquaDecorSave]
    var moss: [Float]
    var night: Bool
    var pump: Bool

    private enum CodingKeys: String, CodingKey {
        case fish, decor, moss, algae, night, pump
    }

    private struct RawDecorSave: Decodable {
        var kind: String
        var x: CGFloat
        var flip: Bool
    }

    init(fish: [AquaFishSave], decor: [AquaDecorSave], moss: [Float], night: Bool, pump: Bool) {
        self.fish = fish
        self.decor = decor
        self.moss = moss
        self.night = night
        self.pump = pump
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fish = try c.decodeIfPresent([AquaFishSave].self, forKey: .fish) ?? []
        let rawDecor = try c.decodeIfPresent([RawDecorSave].self, forKey: .decor) ?? []
        // Silently drop retired decor kinds (e.g. legacy pillar/slate) so old aquarium.json saves migrate cleanly.
        decor = rawDecor.compactMap { raw in
            guard let kind = AquaDecorKind(rawValue: raw.kind) else { return nil }
            return AquaDecorSave(kind: kind, x: raw.x, flip: raw.flip)
        }
        if let savedMoss = try c.decodeIfPresent([Float].self, forKey: .moss), savedMoss.count == AGeo.mossPresets.count {
            moss = savedMoss
        } else if let legacyAlgae = try c.decodeIfPresent([Float].self, forKey: .algae), !legacyAlgae.isEmpty {
            let avg = min(1, max(0, legacyAlgae.reduce(0, +) / Float(legacyAlgae.count)))
            moss = (0..<AGeo.mossPresets.count).map { i in
                let weight: Float = i % 2 == 0 ? 1.1 : 0.7
                return min(1, avg * weight)
            }
        } else {
            moss = [Float](repeating: 0, count: AGeo.mossPresets.count)
        }
        night = try c.decodeIfPresent(Bool.self, forKey: .night) ?? false
        pump = try c.decodeIfPresent(Bool.self, forKey: .pump) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fish, forKey: .fish)
        try c.encode(decor, forKey: .decor)
        try c.encode(moss, forKey: .moss)
        try c.encode(night, forKey: .night)
        try c.encode(pump, forKey: .pump)
    }
}

enum AquaStorage {
    static let file = "aquarium.json"

    static func load() -> AquaSave? {
        GameStorage.load(AquaSave.self, game: AquariumSim.gameID, file: file)
    }

    static func save(_ s: AquaSave) {
        GameStorage.save(s, game: AquariumSim.gameID, file: file)
    }
}
