import AVFoundation
import SwiftUI

// MARK: - Ice Cream & Smoothie Shop: colors, choices, orders, saves and sounds
//
// Everything is open and free. Nothing to read: every choice is a picture.

/// A stable pseudo-random number in 0..<1 for (i, salt). The shop's own, so it never depends on another game.
func icRand(_ i: Int, _ salt: Int) -> CGFloat {
    var x = UInt64(bitPattern: Int64((i &* 73_856_093) ^ (salt &* 19_349_663))) &+ 0x9E37_79B9_7F4A_7C15
    x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
    x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
    x ^= x >> 31
    return CGFloat(x % 100_000) / 100_000
}

func icClamp(_ t: CGFloat, _ lo: CGFloat = 0, _ hi: CGFloat = 1) -> CGFloat { max(lo, min(hi, t)) }

func icEase(_ t: CGFloat) -> CGFloat {
    let x = icClamp(t)
    return x * x * (3 - 2 * x)
}

/// A plain sRGB color that can be mixed and shaded.
struct ICColor: Equatable, Codable {
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

    func mix(_ o: ICColor, _ t: CGFloat) -> ICColor {
        let k = Double(icClamp(t))
        return ICColor(r: r + (o.r - r) * k, g: g + (o.g - g) * k, b: b + (o.b - b) * k)
    }

    /// k < 0 darkens toward a deeper version of the color, k > 0 lightens toward white.
    func shade(_ k: Double) -> ICColor {
        if k >= 0 { return mix(ICColor(0xFFFFFF), CGFloat(k)) }
        let d = 1 + k
        return ICColor(r: r * d * 0.95, g: g * d * 0.9, b: b * d * 0.98)
    }

    func distance(_ o: ICColor) -> Double { abs(r - o.r) + abs(g - o.g) + abs(b - o.b) }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    func color(_ a: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

/// Pigment that adds up: each pour or chopped fruit adds its color with a weight.
struct ICPaint: Equatable {
    var r: Double = 0
    var g: Double = 0
    var b: Double = 0
    var w: Double = 0

    mutating func add(_ c: ICColor, _ amount: Double) {
        guard amount > 0 else { return }
        r += c.r * amount
        g += c.g * amount
        b += c.b * amount
        w += amount
    }

    var color: ICColor {
        guard w > 0.0001 else { return ICColor(0xFFFFFF) }
        return ICColor(r: r / w, g: g / w, b: b / w)
    }
}

// MARK: Choices

enum ICStation: String, CaseIterable {
    case scoop, soft, smoothie
}

/// The scoop cabinet's tubs.
enum ICFlavor: Int, CaseIterable, Codable {
    case vanilla, chocolate, strawberry, mint, blueberry, mango

    var color: ICColor {
        switch self {
        case .vanilla: return ICColor(0xFFF0C9)
        case .chocolate: return ICColor(0x8C5536)
        case .strawberry: return ICColor(0xFFA2BE)
        case .mint: return ICColor(0xAEEBD2)
        case .blueberry: return ICColor(0xA9B8F6)
        case .mango: return ICColor(0xFFC55C)
        }
    }

    /// Little bits in it (chips, berry pieces, vanilla specks).
    var bits: ICColor? {
        switch self {
        case .vanilla: return ICColor(0x6B4A30)
        case .chocolate: return ICColor(0x5A321D)
        case .strawberry: return ICColor(0xE2385C)
        case .mint: return ICColor(0x4A2C1E)
        case .blueberry: return ICColor(0x4B4FB8)
        case .mango: return nil
        }
    }
}

/// Soft-serve handles, left to right.
enum ICSoft: Int, CaseIterable, Codable {
    case vanilla, chocolate, twist, strawberry

    var colors: (ICColor, ICColor) {
        switch self {
        case .vanilla: return (ICColor(0xFFF6DE), ICColor(0xFFF6DE))
        case .chocolate: return (ICColor(0x9A6040), ICColor(0x9A6040))
        case .twist: return (ICColor(0xFFF6DE), ICColor(0x9A6040))
        case .strawberry: return (ICColor(0xFFB3C9), ICColor(0xFFB3C9))
        }
    }
}

enum ICFruit: Int, CaseIterable, Codable {
    case strawberry, banana, blueberry, mango, kiwi, ice

    /// The color it blends into.
    var juice: ICColor {
        switch self {
        case .strawberry: return ICColor(0xEE4A6C)
        case .banana: return ICColor(0xFFE9A8)
        case .blueberry: return ICColor(0x6A5CC8)
        case .mango: return ICColor(0xFFAA2E)
        case .kiwi: return ICColor(0x9ACB48)
        case .ice: return ICColor(0xEAF6FF)
        }
    }

    /// How strongly its color shows in the blend.
    var strength: Double {
        switch self {
        case .strawberry: return 1.2
        case .banana: return 0.6
        case .blueberry: return 1.5
        case .mango: return 1.0
        case .kiwi: return 0.9
        case .ice: return 0.15
        }
    }

    /// Radius of one piece, in design points.
    var radius: CGFloat {
        switch self {
        case .strawberry: return 19
        case .banana: return 17
        case .blueberry: return 10
        case .mango: return 16
        case .kiwi: return 18
        case .ice: return 16
        }
    }

    /// Pieces that come out of the bin at once.
    var handful: Int { self == .blueberry ? 4 : 1 }
}

enum ICBase: String, CaseIterable, Codable {
    case waffle, choco, cup, glass

    /// Depth of the inside below the rim, where soft serve can sink in.
    var floor: CGFloat {
        switch self {
        case .waffle, .choco: return -8
        case .cup: return -46
        case .glass: return -132
        }
    }

    /// Inner half-width at the rim.
    var rim: CGFloat {
        switch self {
        case .waffle, .choco: return 46
        case .cup: return 52
        case .glass: return 50
        }
    }

    /// How far it reaches below the rim (where its bottom sits on the counter when standing).
    var depth: CGFloat {
        switch self {
        case .waffle, .choco: return 146
        case .cup: return 70
        case .glass: return 168
        }
    }

    var isCone: Bool { self == .waffle || self == .choco }
}

enum ICTopping: String, CaseIterable, Codable {
    case sprinkles, chocoSauce, berrySauce, whip, cherry, wafer, straw

    var sauceColor: ICColor? {
        switch self {
        case .chocoSauce: return ICColor(0x5A2F1F)
        case .berrySauce: return ICColor(0xE0305E)
        default: return nil
        }
    }
}

enum ICKind: String, Codable {
    case scoops, soft, smoothie
}

// MARK: - Orders

struct ICOrder: Equatable {
    var customer: Int
    var kind: ICKind
    var base: ICBase
    /// scoops: flavors bottom to top; soft: one ICSoft; smoothie: one or two ICFruit.
    var flavors: [Int]
    var topping: ICTopping

    enum Part: CaseIterable { case base, flavor, topping }

    static func random(customer: Int, seed: Int = Int.random(in: 0..<1_000_000)) -> ICOrder {
        var r = ICRandom(seed)
        let kinds: [ICKind] = [.scoops, .soft, .smoothie]
        let kind = kinds[r.int(3)]
        switch kind {
        case .scoops:
            let n = 1 + r.int(2)
            var f: [Int] = []
            for _ in 0..<n { f.append(r.int(ICFlavor.allCases.count)) }
            let bases: [ICBase] = [.waffle, .choco, .cup]
            let tops: [ICTopping] = [.sprinkles, .chocoSauce, .berrySauce, .cherry, .wafer, .whip]
            return ICOrder(customer: customer, kind: kind, base: bases[r.int(3)], flavors: f, topping: tops[r.int(tops.count)])
        case .soft:
            let bases: [ICBase] = [.waffle, .choco, .cup]
            let tops: [ICTopping] = [.sprinkles, .chocoSauce, .berrySauce, .cherry, .wafer]
            return ICOrder(customer: customer, kind: kind, base: bases[r.int(3)], flavors: [r.int(ICSoft.allCases.count)],
                           topping: tops[r.int(tops.count)])
        case .smoothie:
            let fruits: [ICFruit] = [.strawberry, .banana, .blueberry, .mango, .kiwi]
            let a = r.int(fruits.count)
            var f = [fruits[a].rawValue]
            if r.int(2) == 0 { f.append(fruits[(a + 1 + r.int(fruits.count - 1)) % fruits.count].rawValue) }
            let tops: [ICTopping] = [.whip, .straw, .cherry, .sprinkles]
            return ICOrder(customer: customer, kind: kind, base: .glass, flavors: f, topping: tops[r.int(tops.count)])
        }
    }

    func matches(_ p: Part, _ b: ICBuild) -> Bool {
        switch p {
        case .base:
            return b.base == base && b.kind == kind
        case .flavor:
            switch kind {
            case .scoops:
                let have = b.scoops.map { $0.flavor.rawValue }.sorted()
                return !have.isEmpty && have == flavors.sorted()
            case .soft:
                return b.softFlavor?.rawValue == flavors.first
            case .smoothie:
                let total = b.fruitIn.reduce(0, +)
                guard total > 0.5 else { return false }
                return flavors.allSatisfy { f in f < b.fruitIn.count && b.fruitIn[f] / total > 0.18 }
            }
        case .topping:
            return b.has(topping)
        }
    }

    func stars(for b: ICBuild) -> Int {
        let n = Part.allCases.filter { matches($0, b) }.count
        return n == 3 ? 3 : n == 2 ? 2 : 1
    }

    /// The treat the customer is dreaming of, for the order card.
    func picture() -> ICBuild {
        var b = ICBuild()
        b.base = base
        switch kind {
        case .scoops:
            var h: CGFloat = 0
            for (i, f) in flavors.enumerated() {
                let r: CGFloat = 44
                let s = ICScoop(id: i, flavor: ICFlavor(rawValue: f) ?? .vanilla, swirl: nil, r: r, dx: 0, h: h + r * (i == 0 ? 0.62 : 0.78))
                b.scoops.append(s)
                h = s.h + r * 0.55
            }
        case .soft:
            b.rope = ICBuild.sampleSwirl(ICSoft(rawValue: flavors.first ?? 0) ?? .vanilla, floor: base.floor)
        case .smoothie:
            var p = ICPaint()
            for f in flavors {
                let fr = ICFruit(rawValue: f) ?? .strawberry
                p.add(fr.juice, fr.strength)
                b.fruitIn[fr.rawValue] += 1
            }
            p.add(ICColor(0xFFFDF7), 0.4)
            b.layers = [ICLayer(top: 0.86, color: p.color)]
        }
        switch topping {
        case .sprinkles:
            for i in 0..<26 {
                b.sprinkles.append(ICStuck(dx: (icRand(i, 3) - 0.5) * 70, dy: 0, rot: icRand(i, 4) * 6.3, color: i % 6, onTop: true))
            }
        case .chocoSauce, .berrySauce:
            b.pictureSauce = topping
        case .whip:
            b.whip = ICBuild.sampleWhip()
        case .cherry:
            b.cherry = ICBody(dx: 0, h: 0, vx: 0, vh: 0, resting: true)
        case .wafer:
            b.wafer = ICStick(dx: 14, h: 0, angle: 0.35)
        case .straw:
            b.straw = ICStick(dx: 18, h: 0, angle: 0.22)
        }
        b.picture = true
        b.settlePicture()
        return b
    }
}

struct ICRandom {
    private var s: UInt64
    init(_ seed: Int) { s = UInt64(bitPattern: Int64(seed)) &+ 0x2545_F491_4F6C_DD1D }
    mutating func next() -> UInt64 {
        s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return s >> 33
    }
    mutating func int(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }
}

// MARK: - Saves

/// shop.json in the game's save folder.
struct ICSave: Codable, Equatable {
    var hearts: Int = 0
    var served: Int = 0
}

enum ICStorage {
    static func load() -> ICSave { GameStorage.load(ICSave.self, game: IceSim.gameID, file: "shop.json") ?? ICSave() }
    static func save(_ s: ICSave) { GameStorage.save(s, game: IceSim.gameID, file: "shop.json") }
}

// MARK: - Sounds

enum IceSFX: String, CaseIterable {
    case scrape, plop, clink, lever, soft, blend, chop, plunk, pour, splash, shake, sauce, whip, boing, crunch,
         bell, nom, yay, slurp, drip, tub, glass, door
}

/// The shop's effects and loops, from App/Resources/Games/IceCream (made by tools/icecream/sounds.py).
final class IceSound {
    static let shared = IceSound()
    static let looping: Set<IceSFX> = [.scrape, .soft, .blend, .pour, .sauce, .whip]

    private var players: [IceSFX: [AVAudioPlayer]] = [:]
    private var loops: [IceSFX: AVAudioPlayer] = [:]
    private var last: [IceSFX: Date] = [:]
    private var loopLevel: [IceSFX: Float] = [:]
    private var loopSent: [IceSFX: Float] = [:]
    private var rateSent: [IceSFX: Float] = [:]
    /// Starting and fading players can stall for milliseconds, so it happens here, never on a drawing frame.
    private let queue = DispatchQueue(label: "icecream.sound", qos: .userInitiated)

    private init() {
        _ = Sound.shared // sets up the audio session
        for s in IceSFX.allCases {
            guard let url = GameFiles.url(s.rawValue, "wav", game: "IceCream") else { continue }
            if IceSound.looping.contains(s) {
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.numberOfLoops = -1
                p?.volume = 0
                p?.enableRate = true
                p?.prepareToPlay()
                loops[s] = p
            } else {
                players[s] = (0..<3).compactMap { _ in
                    let p = try? AVAudioPlayer(contentsOf: url)
                    p?.enableRate = true
                    p?.prepareToPlay()
                    return p
                }
            }
        }
    }

    func play(_ s: IceSFX, volume: Float = 0.9, gap: Double = 0, rate: Float = 1) {
        let now = Date()
        if gap > 0, let t = last[s], now.timeIntervalSince(t) < gap { return }
        last[s] = now
        guard let pool = players[s], !pool.isEmpty else { return }
        queue.async {
            let p = pool.first(where: { !$0.isPlaying }) ?? pool[0]
            p.volume = volume
            p.rate = rate
            p.currentTime = 0
            p.play()
        }
    }

    /// Fades a loop toward `volume` (and its speed toward `rate`); it pauses when silent. Called every frame,
    /// but only reaches the player when the level has moved enough to hear.
    func setLoop(_ s: IceSFX, volume: Float, rate: Float = 1) {
        guard let p = loops[s] else { return }
        let old = loopLevel[s] ?? 0
        let v = old + (volume - old) * 0.2
        loopLevel[s] = v
        let sent = loopSent[s] ?? 0
        let on = v > 0.01
        let rs = rateSent[s] ?? 1
        let rateMoved = abs(rate - rs) > 0.04
        guard abs(v - sent) > 0.01 || (on != (sent > 0.01)) || (on && rateMoved) else { return }
        loopSent[s] = on ? v : 0
        if rateMoved { rateSent[s] = rate }
        queue.async {
            p.volume = on ? v : 0
            if rateMoved { p.rate = rate }
            if on {
                if !p.isPlaying { p.play() }
            } else if p.isPlaying {
                p.pause()
            }
        }
    }

    func stopLoops() {
        for s in loops.keys {
            loopLevel[s] = 0
            loopSent[s] = 0
        }
        let all = Array(loops.values)
        queue.async {
            for p in all {
                p.pause()
                p.volume = 0
            }
        }
    }
}
