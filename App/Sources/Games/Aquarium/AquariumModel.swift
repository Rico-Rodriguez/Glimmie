import SwiftUI

// MARK: - Aquarium: the tank's shape, what lives in it, what decorates it, what is saved
//
// Design space is the app's 1024 x 834 iPad layout. The tank fills most of it; a wooden cabinet below holds the dock.

/// A stable pseudo-random number in 0..<1 for (i, salt). The aquarium's own, so it never depends on another game.
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

/// A plain sRGB color that can be mixed and shaded (the aquarium's own copy, like every game keeps).
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

    /// k < 0 darkens toward a deeper version of the color (outlines are never black), k > 0 lightens toward white.
    func shade(_ k: Double) -> ARGB {
        if k >= 0 { return mix(ARGB(0xFFFFFF), CGFloat(k)) }
        let d = 1 + k
        return ARGB(r: r * d * 0.94, g: g * d * 0.92, b: b * d)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    func color(_ a: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: max(0, min(1, a))) }
}

// MARK: Geometry

enum AGeo {
    /// Inside edges of the glass.
    static let left: CGFloat = 46
    static let right: CGFloat = 978
    /// Top of the glass (under the lid) and the still water line.
    static let rimY: CGFloat = 108
    static let waterY: CGFloat = 150
    /// Bottom of the glass.
    static let bottomY: CGFloat = 690
    static let dockY: CGFloat = 772

    static var width: CGFloat { right - left }

    /// The top of the sand at x: a gentle slope with a low mound on the right, like sand that was poured in and smoothed.
    static func sand(_ x: CGFloat) -> CGFloat {
        let a = 7 * sin(x * 0.0105 + 0.6) + 4 * sin(x * 0.027 + 2.1)
        let mound = 20 * exp(-pow((x - 770) / 150, 2))
        let slope = (x - 512) * 0.018
        return 618 + a - mound + slope
    }

    static var tank: CGRect { CGRect(x: left, y: rimY, width: right - left, height: bottomY - rimY) }

    /// Where fish may swim (their middle), for a fish of half-length `half`.
    static func swim(half: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat) {
        (left + half + 10, right - half - 10, waterY + 22)
    }

    static func inWater(_ p: CGPoint) -> Bool {
        p.x > left && p.x < right && p.y > waterY - 6 && p.y < sand(p.x)
    }

    static func overTank(_ p: CGPoint) -> Bool {
        p.x > left - 10 && p.x < right + 10 && p.y < bottomY && p.y > 20
    }

    // The glass, as a grid of algae cells.
    static let algaeCols = 40
    static let algaeRows = 24
    static let glassTop: CGFloat = rimY + 4
    static var cellW: CGFloat { (right - left) / CGFloat(algaeCols) }
    static var cellH: CGFloat { (bottomY - glassTop) / CGFloat(algaeRows) }

    static func cellCenter(_ c: Int, _ r: Int) -> CGPoint {
        CGPoint(x: left + (CGFloat(c) + 0.5) * cellW, y: glassTop + (CGFloat(r) + 0.5) * cellH)
    }

    // The surface, as a row of springy nodes.
    static let surfaceNodes = 64
    static func nodeX(_ i: Int) -> CGFloat { left + CGFloat(i) / CGFloat(surfaceNodes - 1) * (right - left) }
}

// MARK: Fish

enum FishKind: String, Codable, CaseIterable {
    case goldfish, clownfish, angelfish, tetra, puffer, betta, guppy, seahorse

    /// Nose to the base of the tail, in design points.
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

    /// How far its tail and fins reach behind the body, for drawing and touches.
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

    /// Easy swimming speed and top speed (design points per second).
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

    /// How many come in one bag (tetras and guppies like company).
    var group: Int {
        switch self {
        case .tetra: return 5
        case .guppy: return 3
        default: return 1
        }
    }

    /// Which part of the water it likes, 0 the top to 1 the sand.
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

    /// Colorways, picked per fish.
    var variants: Int {
        switch self {
        case .goldfish, .betta, .guppy, .seahorse: return 3
        default: return 1
        }
    }

    var schools: Bool { self == .tetra || self == .guppy }
}

/// One fish, as saved.
struct FishSave: Codable, Equatable {
    var kind: FishKind
    var variant: Int
}

// MARK: Decorations

enum AquaDecorKind: String, Codable, CaseIterable {
    case castle, chest, diver, bubbler, ship, rock, seaweed, coral, anemone, grass, shell, starfish

    /// Width and height of the drawing; its anchor is the middle of its bottom edge, on the sand.
    var size: CGSize {
        switch self {
        case .castle: return CGSize(width: 150, height: 170)
        case .chest: return CGSize(width: 96, height: 70)
        case .diver: return CGSize(width: 70, height: 128)
        case .bubbler: return CGSize(width: 50, height: 22)
        case .ship: return CGSize(width: 230, height: 150)
        case .rock: return CGSize(width: 150, height: 96)
        case .seaweed: return CGSize(width: 90, height: 250)
        case .coral: return CGSize(width: 110, height: 110)
        case .anemone: return CGSize(width: 96, height: 76)
        case .grass: return CGSize(width: 110, height: 120)
        case .shell: return CGSize(width: 54, height: 44)
        case .starfish: return CGSize(width: 58, height: 34)
        }
    }

    /// How dense it is compared with water: heavy things sink fast, plants drift down slowly.
    var density: CGFloat {
        switch self {
        case .rock, .ship, .castle: return 2.6
        case .chest, .diver: return 2.2
        case .bubbler, .shell: return 2.0
        case .coral, .starfish: return 1.6
        case .anemone: return 1.4
        case .seaweed, .grass: return 1.25
        }
    }

    /// Plants and soft things bend with the water.
    var sways: Bool { self == .seaweed || self == .anemone || self == .grass }

    /// It puffs air bubbles.
    var bubbles: Bool { self == .chest || self == .diver || self == .bubbler || self == .castle }
}

struct DecorSave: Codable, Equatable {
    var kind: AquaDecorKind
    var x: CGFloat
    var flip: Bool
}

struct AquaSave: Codable {
    var fish: [FishSave]
    var decor: [DecorSave]
    var algae: [Float]
    var night: Bool
    var pump: Bool
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
