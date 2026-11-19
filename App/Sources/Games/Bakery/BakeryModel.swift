import AVFoundation
import SwiftUI

// MARK: - Colors and choices (everything is free and open)

struct Flavor {
    let color: RGB
    /// 0 none, 1 chocolate chips, 2 cookie bits (ice cream only)
    let chips: Int
    /// The topping drawn on the flavor's bottle or tub label.
    let icon: String
}

enum BakeryPalette {
    static let flavors: [Flavor] = [
        Flavor(color: RGB(hex: "#FFF0C8"), chips: 0, icon: "top_flower"),      // vanilla
        Flavor(color: RGB(hex: "#9B6146"), chips: 0, icon: "top_chocolate"),   // chocolate
        Flavor(color: RGB(hex: "#FFA8C0"), chips: 0, icon: "top_strawberry"),  // strawberry
        Flavor(color: RGB(hex: "#9DB8F5"), chips: 0, icon: "top_blueberry"),   // blueberry
        Flavor(color: RGB(hex: "#FFE27A"), chips: 0, icon: "top_banana"),      // banana
        Flavor(color: RGB(hex: "#A8E8CF"), chips: 1, icon: "top_mint"),        // mint chip
        Flavor(color: RGB(hex: "#FFB26B"), chips: 0, icon: "top_orange"),      // orange
        Flavor(color: RGB(hex: "#CDB4FF"), chips: 0, icon: "top_grapes"),      // grape
        Flavor(color: RGB(hex: "#9FD8F7"), chips: 0, icon: "top_pearl"),       // bubblegum
        Flavor(color: RGB(hex: "#E8607A"), chips: 0, icon: "top_heart"),       // red velvet
        Flavor(color: RGB(hex: "#C8E09A"), chips: 0, icon: "top_kiwi"),        // pistachio
        Flavor(color: RGB(hex: "#F3F0EC"), chips: 2, icon: "top_cookie"),      // cookies and cream
    ]

    static let frostings: [RGB] = ["#FFFFFF", "#FFF3DC", "#FFB3CC", "#FF7AAE", "#D2C0FF", "#A98BE6",
                                   "#A9D8FF", "#7FB0F0", "#A8E8CF", "#FFE27A", "#FFC2A0", "#8A5A44"].map { RGB(hex: $0) }

    static let liners: [RGB] = ["#FF9EC0", "#A9D8FF", "#FFE27A", "#A8E8CF", "#D2C0FF", "#FFC2A0",
                                "#F45C9A", "#5C9BEB", "#6CCB8B", "#FFFFFF"].map { RGB(hex: $0) }

    static let candy: [RGB] = ["#FF7AAE", "#FFB3CC", "#E8475A", "#FFA24C", "#FFE27A", "#9FE3CF",
                               "#6CCB8B", "#7EC2F2", "#5C9BEB", "#C9B6FF", "#9B79E0", "#FFFFFF"].map { RGB(hex: $0) }

    static let sauces: [RGB] = ["#6B3A2E", "#F0507A", "#D98C3A", "#6C7FE0", "#FFFFFF", "#6CCB8B"].map { RGB(hex: $0) }

    static let cones = ["waffle", "sugar", "choco", "pinkdip", "cup"]
    static let frostStyles = ["swirl", "cloud", "dome"]
    static let customers = ["bunny", "kitty", "bear", "puppy", "panda", "fox", "piggy", "frog"]

    /// Topping trays: (tray icon, toppings)
    static let trays: [(icon: String, items: [String])] = [
        ("top_strawberry", ["strawberry", "cherry", "cherries", "blueberry", "raspberry", "banana", "kiwi", "orange", "grapes", "mint"]),
        ("top_heart", ["heart", "star", "gumdrop", "gummy", "lollipop", "cane", "worm", "pearl", "mochi"]),
        ("top_macaron", ["macaron", "donut", "marshmallow", "cream", "cookie", "wafer", "chocolate", "chocheart", "chip"]),
        ("top_candle", ["candle", "crown", "horn", "butterfly", "flower", "bow", "rainbow", "cloud", "sparkle"]),
        ("bit_sprinkle", ["*sprinkle", "*nonpareil", "*confheart", "*confstar", "*curl"]),
    ]
}

// MARK: - A treat

enum TreatKind: String, Codable, CaseIterable {
    case cake, cupcake, iceCream
}

struct PlacedTopping: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Sprite name, "top_<name>" or "bit_<name>".
    var sprite: String
    var x: Double
    var y: Double
    var rot: Double = 0
    var scale: Double = 1
    var color: Int = 0
}

struct Treat: Codable, Equatable {
    var kind: TreatKind = .cake
    var flavor = 0
    var tiers = 1
    /// Frosting color, nil until frosted.
    var frosting: Int?
    var frostStyle = "swirl"
    /// Cupcake frosting: 0 (none) to 3 swirls.
    var frostStage = 0
    var liner = 0
    var cone = "waffle"
    var scoops: [Int] = []
    var sauce: Int?
    var toppings: [PlacedTopping] = []
    /// Spatula strokes in the cake frosting, as flat x, y pairs (stage units). nil in older saves.
    var swoosh: [[Int]]?

    init(kind: TreatKind = .cake) { self.kind = kind }

    var swooshPoints: [[CGPoint]] {
        (swoosh ?? []).map { s in
            stride(from: 0, to: s.count - 1, by: 2).map { CGPoint(x: CGFloat(s[$0]), y: CGFloat(s[$0 + 1])) }
        }
    }

    /// A pretty finished treat (for the wish bubble, tiles and screenshots).
    static func sample(_ kind: TreatKind, seed: Int) -> Treat {
        var t = Treat(kind: kind)
        var rng = SeededRandom(seed)
        t.flavor = rng.int(BakeryPalette.flavors.count)
        t.frosting = rng.int(BakeryPalette.frostings.count)
        t.liner = rng.int(BakeryPalette.liners.count)
        switch kind {
        case .cake:
            t.tiers = 1 + rng.int(3)
            let top = BakeryArt.shared.tiers[t.tiers - 1]
            t.toppings = [PlacedTopping(sprite: "top_strawberry", x: 300, y: Double(top.t - 22)),
                          PlacedTopping(sprite: "top_cream", x: Double(300 - top.hw * 0.55), y: Double(top.t - 4), scale: 0.7, color: 11),
                          PlacedTopping(sprite: "top_cream", x: Double(300 + top.hw * 0.55), y: Double(top.t - 4), scale: 0.7, color: 11)]
        case .cupcake:
            t.frostStyle = BakeryPalette.frostStyles[rng.int(3)]
            t.frostStage = 3
            t.toppings = [PlacedTopping(sprite: "top_cherry", x: 300, y: 196)]
        case .iceCream:
            t.cone = BakeryPalette.cones[rng.int(BakeryPalette.cones.count)]
            t.scoops = (0..<(1 + rng.int(3))).map { _ in rng.int(BakeryPalette.flavors.count) }
            t.sauce = rng.int(2) == 0 ? rng.int(BakeryPalette.sauces.count) : nil
            let top = BakeryArt.shared.scoopY0 - CGFloat(t.scoops.count - 1) * BakeryArt.shared.scoopDY
            t.toppings = [PlacedTopping(sprite: "top_cherry", x: 300, y: Double(top - 96))]
        }
        return t
    }
}

struct SeededRandom {
    private var state: UInt64
    init(_ seed: Int) { state = UInt64(truncatingIfNeeded: seed) &* 0x9E3779B97F4A7C15 &+ 0x1234567 }
    mutating func next() -> UInt64 {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return state &* 2685821657736338717
    }
    mutating func int(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }
    mutating func unit() -> Double { Double(next() % 10_000) / 10_000 }
}

// MARK: - Saved things: served treats and hearts

struct BakerySave: Codable {
    var hearts = 0
    var served: [Treat] = []
}

final class BakeryStore: ObservableObject {
    static let game = "bakery"
    static let maxServed = 60

    @Published var hearts: Int
    @Published var served: [Treat]

    init() {
        let s = GameStorage.load(BakerySave.self, game: BakeryStore.game, file: "bakery.json") ?? BakerySave()
        hearts = s.hearts
        served = s.served
    }

    func serve(_ t: Treat) {
        hearts += 1
        served.insert(t, at: 0)
        if served.count > BakeryStore.maxServed { served.removeLast(served.count - BakeryStore.maxServed) }
        save()
    }

    func save() {
        GameStorage.save(BakerySave(hearts: hearts, served: served), game: BakeryStore.game, file: "bakery.json")
    }
}

// MARK: - Sounds

/// The bakery's own effects from App/Resources/Games/Bakery (made by tools/bakery/sounds.py).
/// Effects only: no voice, never text-to-speech.
enum BakeSFX: String, CaseIterable {
    case plop, pour, swish, squeeze, shake, nom, tick, doorbell, scoop, drizzle, oven, yay, magic, freeze
    case poof, grains, glug, sizzle, smear, batter
}

final class BakerySound {
    static let shared = BakerySound()
    private var players: [BakeSFX: [AVAudioPlayer]] = [:]

    private init() {
        _ = Sound.shared  // sets up the audio session
        for s in BakeSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "Bakery") else { continue }
            players[s] = (0..<3).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                return p
            }
        }
    }

    func play(_ s: BakeSFX, volume: Float = 1) {
        guard let pool = players[s], !pool.isEmpty else { return }
        let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}

extension Treat {
    /// The drawer tile's cupcake.
    static var tile: Treat {
        var t = Treat(kind: .cupcake)
        t.liner = 0; t.flavor = 1; t.frosting = 2; t.frostStyle = "swirl"; t.frostStage = 3
        t.toppings = [PlacedTopping(sprite: "top_cherry", x: 300, y: 190)]
        let bits: [(Double, Double, Double, Int)] = [(250, 300, 30, 4), (330, 290, 120, 7), (280, 350, 70, 9), (360, 340, 160, 0),
                                                     (230, 380, 10, 5), (310, 390, 100, 3), (370, 384, 50, 10), (290, 260, 140, 8)]
        for (x, y, r, c) in bits { t.toppings.append(PlacedTopping(sprite: "bit_sprinkle", x: x, y: y, rot: r, scale: 1, color: c)) }
        return t
    }
}
