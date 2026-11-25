import SwiftUI

enum SGeo {
    static let tubL: CGFloat = 122
    static let tubR: CGFloat = 862
    static let tubBottom: CGFloat = 648
    static let lipY: CGFloat = 472
    static let fullY: CGFloat = 492
    static var maxDepth: CGFloat { tubBottom - fullY }
    static let columns = 148
    static let colW: CGFloat = 5
    static let floorY: CGFloat = 702

    static let handle = CGPoint(x: 836, y: 332)
    static let spout = CGPoint(x: 808, y: 408)
    static let plugRing = CGPoint(x: 842, y: 472)
    static let drain = CGPoint(x: 802, y: 642)
    static let mirror = CGRect(x: 528, y: 108, width: 220, height: 224)
    static let fogCols = 22
    static let fogRows = 22
    static let wishBubbleCenter = CGPoint(x: 446, y: 184)

    // Dress Up doll (600 x 900 art) seated in the cozy left slipper end of the clawfoot tub.
    static let dollScale: CGFloat = 0.78
    static let dollOrigin = CGPoint(x: 282 - 300 * 0.78, y: 466 - 470 * 0.78)
    static let bodyL: CGFloat = 200
    static let bodyR: CGFloat = 372
    static let chinY: CGFloat = 432

    // Her face in Dress Up doll coordinates.
    static let headC = CGPoint(x: 300, y: 290)
    static let headRX: CGFloat = 140
    static let headRY: CGFloat = 134
    static let eyes = [CGPoint(x: 238, y: 326), CGPoint(x: 362, y: 326)]
    static let nose = CGPoint(x: 300, y: 362)
    static let mouth = CGPoint(x: 300, y: 388)
    static let maskRect = CGRect(x: 158, y: 196, width: 284, height: 232)
    static let maskCols = 20
    static let maskRows = 16

    static func colX(_ i: Int) -> CGFloat { tubL + (CGFloat(i) + 0.5) * colW }
    static func col(_ x: CGFloat) -> Int { max(0, min(columns - 1, Int((x - tubL) / colW))) }

    static func toDoll(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - dollOrigin.x) / dollScale, y: (p.y - dollOrigin.y) / dollScale)
    }

    static func fromDoll(_ d: CGPoint) -> CGPoint {
        CGPoint(x: dollOrigin.x + d.x * dollScale, y: dollOrigin.y + d.y * dollScale)
    }

    static func inHead(_ d: CGPoint, pad: CGFloat = 0) -> Bool {
        let x = (d.x - headC.x) / (headRX + pad)
        let y = (d.y - headC.y) / (headRY + pad)
        return x * x + y * y < 1
    }

    static func onHer(_ d: CGPoint, pad: CGFloat = 0) -> Bool {
        if inHead(d, pad: pad) { return true }
        return d.x > 196 - pad && d.x < 404 + pad && d.y > 400 && d.y < 540
    }

    /// Keeps foam puffs neatly anchored around her crown, hairline, cheeks, or chin and never across her eyes.
    static func clampFoamAnchor(_ raw: CGPoint) -> CGPoint {
        var p = CGPoint(
            x: max(144, min(456, raw.x)),
            y: max(124, min(444, raw.y))
        )
        let inEyeBand = p.y > 258 && p.y < 374 && p.x > 176 && p.x < 424
        let nearLeftEye = hypot(p.x - eyes[0].x, p.y - eyes[0].y) < 58
        let nearRightEye = hypot(p.x - eyes[1].x, p.y - eyes[1].y) < 58
        if inEyeBand || nearLeftEye || nearRightEye {
            if p.y < 332 {
                p.y = min(218, 178 + abs(p.x - 300) * 0.28)
            } else {
                p.y = 414
            }
        }
        return p
    }

    static var inside: CGRect {
        CGRect(x: tubL, y: lipY, width: tubR - tubL, height: tubBottom - lipY)
    }
}

// MARK: - Domain kinds

enum SpaCategory: String, CaseIterable, Identifiable, Codable {
    case fizz, wash, pamper, toys
    var id: String { rawValue }
}

enum BombKind: String, CaseIterable {
    case rose, sunshine, ocean, mint, galaxy, rainbow, yuzu

    var treasure: String? {
        self == .yuzu ? "spa/yuzuBomb" : nil
    }

    static var available: [BombKind] {
        allCases.filter { k in k.treasure.map { Coins.shared.owns($0) } ?? true }
    }

    var color: RGB {
        switch self {
        case .rose: return RGB(hex: "#FF7FB0")
        case .sunshine: return RGB(hex: "#FFC93C")
        case .ocean: return RGB(hex: "#5EC2FF")
        case .mint: return RGB(hex: "#5FD9A8")
        case .galaxy: return RGB(hex: "#8E6BFF")
        case .rainbow: return RGB(hex: "#FF8FB8")
        case .yuzu: return RGB(hex: "#FFD84A")
        }
    }

    var glitter: Bool { self == .sunshine || self == .galaxy || self == .rainbow || self == .yuzu }

    func dye(_ t: Double) -> RGB {
        if self == .yuzu {
            let gold = RGB(hex: "#FFE15A")
            let citrus = RGB(hex: "#FFA83A")
            let u = 0.5 + 0.5 * sin(t * 2.2)
            return gold.mix(citrus, u * 0.65)
        }
        if self == .galaxy {
            let hues = ["#7A5BFF", "#A378FF", "#5F8CFF", "#D484FF"].map { RGB(hex: $0) }
            let u = (t * 0.35).truncatingRemainder(dividingBy: 1) * Double(hues.count)
            let i = Int(u) % hues.count
            return hues[i].mix(hues[(i + 1) % hues.count], u - floor(u))
        }
        guard self == .rainbow else { return color }
        let hues = ["#FF6F91", "#FFB347", "#FFE066", "#6EE7A0", "#5EC2FF", "#B497FF"].map { RGB(hex: $0) }
        let u = (t * 0.45).truncatingRemainder(dividingBy: 1) * Double(hues.count)
        let i = Int(u) % hues.count
        return hues[i].mix(hues[(i + 1) % hues.count], u - floor(u))
    }
}

enum FoamTint: String, CaseIterable, Codable {
    case cloud, berry, lavender, mint

    var color: RGB {
        switch self {
        case .cloud: return RGB(hex: "#FFFFFF")
        case .berry: return RGB(hex: "#FFB3D1")
        case .lavender: return RGB(hex: "#D4C2FF")
        case .mint: return RGB(hex: "#B8F2DE")
        }
    }
}

enum MaskKind: Int, CaseIterable, Codable {
    case cucumber, strawberry, honey, blueberry

    var color: RGB {
        switch self {
        case .cucumber: return RGB(hex: "#9CD98F")
        case .strawberry: return RGB(hex: "#FF9EBC")
        case .honey: return RGB(hex: "#FFD166")
        case .blueberry: return RGB(hex: "#9BB8FF")
        }
    }
}

enum ToyKind: String, CaseIterable, Codable {
    case duck, boat, whale, turtle, goldenDuck

    var treasure: String? {
        self == .goldenDuck ? "spa/goldenDuck" : nil
    }

    static var available: [ToyKind] {
        allCases.filter { k in k.treasure.map { Coins.shared.owns($0) } ?? true }
    }

    var half: CGSize {
        switch self {
        case .duck: return CGSize(width: 42, height: 36)
        case .boat: return CGSize(width: 48, height: 44)
        case .whale: return CGSize(width: 52, height: 32)
        case .turtle: return CGSize(width: 42, height: 24)
        case .goldenDuck: return CGSize(width: 44, height: 42)
        }
    }

    var density: CGFloat {
        switch self {
        case .duck: return 0.42
        case .boat: return 0.32
        case .whale: return 0.50
        case .turtle: return 0.62
        case .goldenDuck: return 0.40
        }
    }
}

enum SpaTool: Equatable {
    case soap
    case sponge(FoamTint)
    case shower
    case mask(MaskKind)
    case cucumbers
    case towel
    case sheepTowel
    case mist
    case wand
}

enum ThingKind: Equatable {
    case toy(ToyKind)
    case bomb(BombKind)
}

enum SpaExpression: Equatable {
    case happy
    case zen
    case surprised
    case sneeze
    case giggle
    case cozy
}

enum SpaWish: String, CaseIterable, Codable {
    case bathBomb
    case foamHair
    case cucumbers
    case whaleToy
    case cozyTowel
    case faceMask

    var category: SpaCategory {
        switch self {
        case .bathBomb: return .fizz
        case .foamHair: return .wash
        case .cucumbers, .cozyTowel, .faceMask: return .pamper
        case .whaleToy: return .toys
        }
    }
}

// MARK: - Persistence

struct SpaToySave: Codable, Equatable {
    var kind: ToyKind
    var x: Double
    var y: Double
    var facing: Double
}

struct SpaSave: Codable, Equatable {
    var vol: Double
    var warm: Double
    var soap: Double
    var foam: [Double]
    var toys: [SpaToySave]
    var cucumbersOn: Bool
    var sheepTowelOn: Bool
    var sheepTowelTint: FoamTint
    var maskCov: [Double]
    var maskKind: [Int]
    var activeWish: SpaWish
    var wishCompletedCount: Int
    var selectedCategory: SpaCategory

    enum CodingKeys: String, CodingKey {
        case vol, warm, soap, foam, toys
        case cucumbersOn, sheepTowelOn, sheepTowelTint
        case maskCov, maskKind
        case activeWish, wishCompletedCount, selectedCategory
    }

    init(
        vol: Double,
        warm: Double,
        soap: Double,
        foam: [Double],
        toys: [SpaToySave],
        cucumbersOn: Bool,
        sheepTowelOn: Bool,
        sheepTowelTint: FoamTint,
        maskCov: [Double],
        maskKind: [Int],
        activeWish: SpaWish,
        wishCompletedCount: Int,
        selectedCategory: SpaCategory
    ) {
        self.vol = vol
        self.warm = warm
        self.soap = soap
        self.foam = foam
        self.toys = toys
        self.cucumbersOn = cucumbersOn
        self.sheepTowelOn = sheepTowelOn
        self.sheepTowelTint = sheepTowelTint
        self.maskCov = maskCov
        self.maskKind = maskKind
        self.activeWish = activeWish
        self.wishCompletedCount = wishCompletedCount
        self.selectedCategory = selectedCategory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vol = try c.decodeIfPresent(Double.self, forKey: .vol) ?? Double(SGeo.maxDepth * 0.84)
        warm = try c.decodeIfPresent(Double.self, forKey: .warm) ?? 0.9
        soap = try c.decodeIfPresent(Double.self, forKey: .soap) ?? 36
        foam = try c.decodeIfPresent([Double].self, forKey: .foam) ?? []
        toys = try c.decodeIfPresent([SpaToySave].self, forKey: .toys) ?? []
        cucumbersOn = try c.decodeIfPresent(Bool.self, forKey: .cucumbersOn) ?? false
        sheepTowelOn = try c.decodeIfPresent(Bool.self, forKey: .sheepTowelOn) ?? false
        sheepTowelTint = try c.decodeIfPresent(FoamTint.self, forKey: .sheepTowelTint) ?? .cloud
        maskCov = try c.decodeIfPresent([Double].self, forKey: .maskCov) ?? []
        maskKind = try c.decodeIfPresent([Int].self, forKey: .maskKind) ?? []
        activeWish = try c.decodeIfPresent(SpaWish.self, forKey: .activeWish) ?? .bathBomb
        wishCompletedCount = try c.decodeIfPresent(Int.self, forKey: .wishCompletedCount) ?? 0
        selectedCategory = try c.decodeIfPresent(SpaCategory.self, forKey: .selectedCategory) ?? .fizz
    }
}

enum SpaStorage {
    static let file = "spa.json"

    static func load() -> SpaSave? {
        GameStorage.load(SpaSave.self, game: SpaSim.gameID, file: file)
    }

    static func save(_ s: SpaSave) {
        GameStorage.save(s, game: SpaSim.gameID, file: file)
    }
}

// MARK: - Simulation entities

struct FoamPuff: Identifiable {
    let id: Int
    var anchor: CGPoint
    var offset: CGVector = .zero
    var vel: CGVector = .zero
    var radius: CGFloat
    var tint: RGB
    var seed: Int
    var flung: Bool = false
    var age: CGFloat = 0

    var position: CGPoint {
        CGPoint(x: anchor.x + offset.dx, y: anchor.y + offset.dy)
    }
}

struct SThing {
    var id: Int
    var kind: ThingKind
    var p: CGPoint
    var v: CGVector = .zero
    var a: CGFloat = 0
    var av: CGFloat = 0
    var held = false
    var target: CGPoint = .zero
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var fizz: CGFloat = 1
    var wetFor: CGFloat = 0
    var wasIn = false
    var facing: CGFloat = 1
    var dive: CGFloat = 0

    var half: CGSize {
        switch kind {
        case .toy(let k): return k.half
        case .bomb:
            let r = 28 * (0.3 + 0.7 * sqrt(max(0, fizz)))
            return CGSize(width: r, height: r)
        }
    }

    var density: CGFloat {
        switch kind {
        case .toy(let k): return k == .turtle && dive > 0 ? 1.45 : k.density
        case .bomb: return wetFor > 0.45 ? 0.80 : 1.48
        }
    }

    var isBomb: Bool {
        if case .bomb = kind { return true }
        return false
    }
}

enum DropKind { case water, soap, spray }

struct SDrop {
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var kind: DropKind = .water
    var age: CGFloat = 0
}

struct SAir {
    var p: CGPoint
    var r: CGFloat
    var phase: CGFloat
    var vx: CGFloat = 0
}

struct SBubble {
    var star = false
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var age: CGFloat = 0
    var life: CGFloat
    var phase: CGFloat
}

struct SPuff {
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var a: CGFloat
    var color: RGB
    var age: CGFloat = 0
}

struct SGlitter {
    var p: CGPoint
    var v: CGVector
    var color: RGB
    var phase: CGFloat
    var age: CGFloat = 0
    var settled = false
}

struct SSteam {
    var p: CGPoint
    var v: CGVector
    var r: CGFloat
    var age: CGFloat = 0
    var life: CGFloat
}

struct SPop {
    var p: CGPoint
    var r: CGFloat
    var age: CGFloat = 0
    var sparkle = false
}

struct SHeart {
    var p: CGPoint
    var v: CGVector
    var size: CGFloat
    var color: RGB
    var age: CGFloat = 0
    var life: CGFloat
    var phase: CGFloat
}

struct SBead {
    var d: CGPoint
    var r: CGFloat
    var vy: CGFloat = 0
}

struct SSud {
    var d: CGPoint
    var r: CGFloat
    var phase: CGFloat
}

enum HandMode: Equatable {
    case none, swish, wipe, girl, puff(Int), thing(Int), pop
}

// MARK: - Main simulation

final class SpaSim {
    static let gameID = "spa"
    static let starGoal = 5

    var time: Double = 0
    private var last: Date?
    var quiet = false
    var demo = false

    // Water & waves
    var vol: CGFloat = 0
    var h = [CGFloat](repeating: 0, count: SGeo.columns)
    var hv = [CGFloat](repeating: 0, count: SGeo.columns)
    var foam = [CGFloat](repeating: 0, count: SGeo.columns)
    var foamTint = [RGB](repeating: RGB(1, 1, 1), count: SGeo.columns)
    var tint = [RGB](repeating: RGB(1, 1, 1), count: SGeo.columns)
    var tintA = [CGFloat](repeating: 0, count: SGeo.columns)
    var soap: CGFloat = 0
    var tapOn = false
    var flow: CGFloat = 0
    var handleTurn: CGFloat = 0
    var plugOut = false
    var drainFlow: CGFloat = 0
    var warm: CGFloat = 0
    var yuzuCitrus: CGFloat = 0
    var fog = [CGFloat](repeating: 0, count: SGeo.fogCols * SGeo.fogRows)
    var fogCleared = [Bool](repeating: false, count: SGeo.fogCols * SGeo.fogRows)
    var mirrorFreshUntil: Double = 0

    // Interactive entities & particles
    var things: [SThing] = []
    var drops: [SDrop] = []
    var air: [SAir] = []
    var bubbles: [SBubble] = []
    var puffs: [SPuff] = []
    var glitter: [SGlitter] = []
    var steam: [SSteam] = []
    var pops: [SPop] = []
    var hearts: [SHeart] = []
    private var nextID = 1
    private var wandBlowCount = 0
    private(set) var starsPopped = 0

    // Doll state
    var look: Look
    private(set) var layers: [Expression: [(ArtLayer, PaintSet, ArtItem)]] = [:]
    var maskCov = [CGFloat](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
    var maskKind = [Int](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
    var maskDry = [CGFloat](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
    var cucumbersOn = false
    var sheepTowelOn = false
    var sheepTowelTint: FoamTint = .cloud
    var beads: [SBead] = []
    var suds: [SSud] = []
    var foamPuffs: [FoamPuff] = []
    private var nextPuffID = 1
    private var foamStyleIndex = 0

    // Reactions & timed flourishes
    var sneezeUntil: Double = -10
    var surprisedUntil: Double = -10
    var giggleUntil: Double = -10
    var cozyUntil: Double = -10
    var quickShowerUntil: Double = -10
    var blinkAt: Double = 2.4
    var bob: CGFloat = 0
    var bobV: CGFloat = 0

    // Wishes, UI & stickers
    var activeWish: SpaWish = .bathBomb
    var wishCompletedCount = 0
    var wishCelebrateUntil: Double = -10
    var selectedCategory: SpaCategory = .fizz
    private(set) var unlockedFinds: Set<SpaFind> = []
    private var lastSave: Double = 0

    // Held dock tool
    var tool: SpaTool?
    var toolP: CGPoint = .zero
    var toolTarget: CGPoint = .zero
    var toolFinger: CGPoint = .zero
    var toolV: CGVector = .zero
    var toolAngle: CGFloat = 0
    var wandFilm: CGFloat = 1
    var spongeWet: CGFloat = 0.5
    var spongeFoam: CGFloat = 1
    private var rubbing: CGFloat = 0
    private var emitCarry: CGFloat = 0

    // Bare finger gesture
    var hand: HandMode = .none
    var handP: CGPoint = .zero
    var handV: CGVector = .zero
    private var swishSound: Double = 0

    init(look: Look? = nil, save: SpaSave? = nil) {
        let base = look ?? SpaSim.herLook()
        self.look = SpaSim.bathLook(base)
        for e in [Expression.normal, .blink, .happy] {
            layers[e] = DollPainter.layers(self.look, e)
        }
        if let save {
            restore(save)
        }
    }

    func makeSave() -> SpaSave {
        let savedToys: [SpaToySave] = things.compactMap { t in
            guard case .toy(let k) = t.kind else { return nil }
            return SpaToySave(kind: k, x: Double(t.p.x), y: Double(t.p.y), facing: Double(t.facing))
        }
        return SpaSave(
            vol: Double(vol),
            warm: Double(warm),
            soap: Double(soap),
            foam: foam.map { Double($0) },
            toys: savedToys,
            cucumbersOn: cucumbersOn,
            sheepTowelOn: sheepTowelOn,
            sheepTowelTint: sheepTowelTint,
            maskCov: maskCov.map { Double($0) },
            maskKind: maskKind,
            activeWish: activeWish,
            wishCompletedCount: wishCompletedCount,
            selectedCategory: selectedCategory
        )
    }

    func restore(_ s: SpaSave) {
        vol = max(0, min(SGeo.maxDepth, CGFloat(s.vol)))
        warm = max(0, min(1, CGFloat(s.warm)))
        soap = max(0, CGFloat(s.soap))
        tapOn = false
        plugOut = false
        if s.foam.count == SGeo.columns {
            foam = s.foam.map { max(0, min(2.4, CGFloat($0))) }
        } else {
            foam = [CGFloat](repeating: 0, count: SGeo.columns)
        }
        foamTint = [RGB](repeating: RGB(1, 1, 1), count: SGeo.columns)
        cucumbersOn = s.cucumbersOn
        sheepTowelOn = s.sheepTowelOn
        sheepTowelTint = s.sheepTowelTint
        if s.maskCov.count == maskCov.count && s.maskKind.count == maskKind.count {
            maskCov = s.maskCov.map { max(0, min(1, CGFloat($0))) }
            maskKind = s.maskKind
            maskDry = maskCov.map { $0 > 0.05 ? 0.1 : 0 }
        }
        activeWish = s.activeWish
        wishCompletedCount = max(0, s.wishCompletedCount)
        selectedCategory = s.selectedCategory
        things.removeAll()
        for t in s.toys.prefix(8) {
            let hw = t.kind.half.width
            let x = max(SGeo.bodyR + hw, min(SGeo.tubR - hw, CGFloat(t.x)))
            let y = max(SGeo.lipY - 12, min(SGeo.tubBottom - t.kind.half.height, CGFloat(t.y)))
            let id = spawnThing(.toy(t.kind), at: CGPoint(x: x, y: y), held: false)
            if let idx = thingIndex(id) {
                things[idx].facing = t.facing < 0 ? -1 : 1
            }
        }
    }

    func save() {
        guard !demo && !quiet else { return }
        SpaStorage.save(makeSave())
    }

    static func herLook() -> Look {
        (GameStorage.load(Look.self, game: LookStore.game, file: "current.json") ?? .starter).sanitized()
    }

    /// Face, hair, earrings, and Dress Up makeup/nails stay; clothes and hats stay dry outside the bath.
    static func bathLook(_ l: Look) -> Look {
        var b = l
        let keep: Set<String> = ["face", "eyes", "brows", "mouth", "nose", "cheeks", "makeup", "earrings", "hairBack", "hairFront"]
        b.picks = l.picks.filter { keep.contains($0.key) }
        b.pet = nil
        b.stickers = []
        return b
    }

    /// Opens into a cozy warm bubbly bathroom ready to play right away.
    func prepareWarmBath() {
        vol = SGeo.maxDepth * 0.84
        warm = 0.9
        soap = 36
        tapOn = false
        plugOut = false
        for i in 0..<SGeo.columns {
            let x = SGeo.colX(i)
            let edge = max(0, 1 - abs(x - 520) / 360)
            foam[i] = 0.35 + edge * 0.55
            foamTint[i] = RGB(1, 1, 1)
        }
        things.removeAll()
        _ = spawnThing(.toy(.duck), at: CGPoint(x: 575, y: level - 16), held: false)
    }

    /// Top-right reset button: refreshes into a sparkling clean warm bath.
    func resetBath() {
        h = [CGFloat](repeating: 0, count: SGeo.columns)
        hv = [CGFloat](repeating: 0, count: SGeo.columns)
        tint = [RGB](repeating: RGB(1, 1, 1), count: SGeo.columns)
        tintA = [CGFloat](repeating: 0, count: SGeo.columns)
        yuzuCitrus = 0
        fog = [CGFloat](repeating: 0, count: SGeo.fogCols * SGeo.fogRows)
        fogCleared = [Bool](repeating: false, count: SGeo.fogCols * SGeo.fogRows)
        mirrorFreshUntil = 0
        maskCov = [CGFloat](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
        maskKind = [Int](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
        maskDry = [CGFloat](repeating: 0, count: SGeo.maskCols * SGeo.maskRows)
        cucumbersOn = false
        sheepTowelOn = false
        beads.removeAll()
        suds.removeAll()
        foamPuffs.removeAll()
        drops.removeAll()
        air.removeAll()
        bubbles.removeAll()
        puffs.removeAll()
        glitter.removeAll()
        pops.removeAll()
        hearts.removeAll()
        tool = nil
        quickShowerUntil = -10
        cozyUntil = -10
        sneezeUntil = -10
        surprisedUntil = -10
        prepareWarmBath()
        giggleUntil = time + 1.0
        pops.append(SPop(p: SGeo.fromDoll(CGPoint(x: 300, y: 220)), r: 44, sparkle: true))
        save()
    }

    // MARK: - Water queries

    var level: CGFloat { SGeo.tubBottom - vol }
    var hasWater: Bool { vol > 1.5 }
    var waterLevelFraction: CGFloat { vol / SGeo.maxDepth }
    var hasEnoughWaterForBomb: Bool { waterLevelFraction >= 0.25 }
    var soapiness: CGFloat { vol > 4 ? min(1, soap / max(26, vol) * 120) : 0 }
    var totalFoam: CGFloat { foam.reduce(0, +) }
    var maskCoverage: CGFloat { maskCov.reduce(0, +) / CGFloat(maskCov.count) }
    var cozyActive: Bool { time < cozyUntil }

    func surfaceY(_ x: CGFloat) -> CGFloat {
        let fx = (x - SGeo.tubL) / SGeo.colW - 0.5
        let i0 = max(0, min(SGeo.columns - 1, Int(floor(fx))))
        let i1 = min(SGeo.columns - 1, i0 + 1)
        let t = max(0, min(1, fx - CGFloat(i0)))
        return level + h[i0] * (1 - t) + h[i1] * t
    }

    func slope(_ x: CGFloat) -> CGFloat { (surfaceY(x + 7) - surfaceY(x - 7)) / 14 }

    func inTub(_ p: CGPoint) -> Bool {
        p.x > SGeo.tubL && p.x < SGeo.tubR && p.y > SGeo.lipY - 4 && p.y < SGeo.tubBottom + 2
    }

    func underWater(_ p: CGPoint) -> Bool {
        hasWater && inTub(p) && p.y > surfaceY(p.x)
    }

    func disturb(_ x: CGFloat, _ impulse: CGFloat, width: CGFloat = 12) {
        guard hasWater, x > SGeo.tubL - 10, x < SGeo.tubR + 10 else { return }
        let c = SGeo.col(x)
        let n = Int(width / SGeo.colW * 2.5) + 1
        for i in max(0, c - n)...min(SGeo.columns - 1, c + n) {
            let d = (SGeo.colX(i) - x) / width
            hv[i] += impulse * exp(-d * d * 0.5)
        }
    }

    // MARK: - Faucet & drain

    func toggleTap() {
        tapOn.toggle()
        if tapOn { plugOut = false }
        play(.turn, 0.7)
    }

    func togglePlug() {
        plugOut.toggle()
        if plugOut { tapOn = false }
        play(.plug, 0.8)
    }

    // MARK: - Stickers & wishes

    func discover(_ find: SpaFind, at point: CGPoint) {
        unlockedFinds.insert(find)
        guard !demo else { return }
        if StickerBook.shared.find(game: SpaSim.gameID, id: find.rawValue) {
            pops.append(SPop(p: point, r: 46, sparkle: true))
            spawnHearts(at: point, count: 4)
        }
    }

    func fulfillWish(_ wish: SpaWish) {
        guard activeWish == wish else { return }
        wishCompletedCount += 1
        wishCelebrateUntil = time + 1.25
        giggleUntil = max(giggleUntil, time + 1.5)
        bobV -= 75
        let origin = SGeo.wishBubbleCenter
        spawnHearts(at: origin, count: 7)
        pops.append(SPop(p: origin, r: 48, sparkle: true))
        play(.chime, 0.75, gap: 0.2)
        if !demo {
            Coins.shared.earn(3, game: SpaSim.gameID, from: origin)
        }
        let all = SpaWish.allCases
        if let idx = all.firstIndex(of: activeWish) {
            activeWish = all[(idx + 1) % all.count]
        }
    }

    func spawnHearts(at p: CGPoint, count: Int) {
        let palette = [RGB(hex: "#FF7FB0"), RGB(hex: "#FFB3CF"), RGB(hex: "#FFE066"), RGB(hex: "#C9B6FF")]
        for i in 0..<count {
            let spread = CGFloat(i - count / 2) * 14 + CGFloat.random(in: -8...8)
            hearts.append(SHeart(
                p: CGPoint(x: p.x + spread, y: p.y + CGFloat.random(in: -10...10)),
                v: CGVector(dx: spread * 1.4, dy: -CGFloat.random(in: 48...92)),
                size: CGFloat.random(in: 14...24),
                color: palette[i % palette.count],
                life: CGFloat.random(in: 1.0...1.6),
                phase: CGFloat.random(in: 0...6)
            ))
        }
        if hearts.count > 48 { hearts.removeFirst(hearts.count - 48) }
    }

    // MARK: - Stepping

    func step(_ date: Date) {
        let dt = last.map { min(1.0 / 20, max(0, date.timeIntervalSince($0))) } ?? 1.0 / 60
        last = date
        step(dt: dt)
    }

    func step(dt: Double) {
        guard dt > 0 else { return }
        time += dt
        let d = CGFloat(dt)
        stepTool(d)
        stepQuickShower(d)
        stepWaterLevel(d)
        let substeps = max(1, Int(ceil(dt * 120)))
        for _ in 0..<substeps { stepWaves(d / CGFloat(substeps)) }
        stepStream(d)
        stepFoam(d)
        stepThings(d)
        stepDrops(d)
        stepAir(d)
        stepBubbles(d)
        stepPuffs(d)
        stepSteam(d)
        stepFoamPuffs(d)
        stepHearts(d)
        stepHer(d)
        sounds()
        if !demo && !quiet && time - lastSave > 2.5 {
            lastSave = time
            save()
        }
    }

    private func stepWaterLevel(_ d: CGFloat) {
        flow += ((tapOn ? 1 : 0) - flow) * min(1, d * 3.8)
        handleTurn += ((tapOn ? 1 : 0) - handleTurn) * min(1, d * 8)
        let drainTarget: CGFloat = plugOut && vol > 0.01 ? 1 : 0
        drainFlow += (drainTarget - drainFlow) * min(1, d * 3.2)
        let before = vol
        if flow > 0.01 && vol < SGeo.maxDepth {
            vol = min(SGeo.maxDepth, vol + flow * 19 * d)
        }
        if drainFlow > 0.01 {
            vol = max(0, vol - drainFlow * (8 + 20 * sqrt(max(0, vol) / SGeo.maxDepth)) * d)
        }
        if vol < before && before > 0 {
            soap *= vol / before
        }
        if vol <= 0.01 {
            vol = 0
            soap = 0
            yuzuCitrus = max(0, yuzuCitrus - d * 1.4)
            for i in 0..<SGeo.columns {
                tintA[i] *= max(0, 1 - d * 0.9)
                h[i] = 0
                hv[i] = 0
            }
        }
        warm = max(0, min(1, warm + flow * d * 0.48 - d * 0.002))
        if vol < 10 { warm = max(0, warm - d * 0.06) }
    }

    private func stepWaves(_ d: CGFloat) {
        let N = SGeo.columns
        guard hasWater else { return }
        let c = min(280, 115 + 165 * sqrt(vol / SGeo.maxDepth))
        let k = c * c / (SGeo.colW * SGeo.colW)
        let damp: CGFloat = vol < 12 ? 6 : 0.6
        var acc = [CGFloat](repeating: 0, count: N)
        for i in 0..<N {
            let l = h[max(0, i - 1)]
            let r = h[min(N - 1, i + 1)]
            acc[i] = k * (l + r - 2 * h[i])
        }
        var sum: CGFloat = 0
        for i in 0..<N {
            hv[i] += acc[i] * d
            hv[i] *= max(0, 1 - damp * d)
            h[i] += hv[i] * d
            h[i] = max(-34, min(min(34, vol), h[i]))
            sum += h[i]
        }
        let mean = sum / CGFloat(N)
        for i in 0..<N { h[i] -= mean }
    }

    var streamLanding: CGPoint {
        let top = SGeo.spout.y
        let bottom = hasWater ? surfaceY(SGeo.spout.x - 10) : SGeo.tubBottom
        let fall = max(1, bottom - top)
        let t = sqrt(2 * fall / 1500)
        return CGPoint(x: SGeo.spout.x - 30 * t * flow, y: bottom)
    }

    private func stepStream(_ d: CGFloat) {
        guard flow > 0.03 else { return }
        let land = streamLanding
        if hasWater {
            disturb(land.x + CGFloat.random(in: -6...6), flow * 820 * d * CGFloat.random(in: 0.4...1.5), width: 9)
            if CGFloat.random(in: 0...1) < flow * d * 64 {
                let depth = min(vol * 0.78, CGFloat.random(in: 8...64) * flow)
                air.append(SAir(
                    p: CGPoint(x: land.x + CGFloat.random(in: -14...14), y: land.y + depth),
                    r: CGFloat.random(in: 1.5...5.2),
                    phase: CGFloat.random(in: 0...6)
                ))
            }
            let s = soapiness
            if s > 0.01 {
                let c = SGeo.col(land.x)
                for i in max(0, c - 4)...min(SGeo.columns - 1, c + 4) {
                    addFoam(i, s * flow * d * 1.8 * (1 - CGFloat(abs(i - c)) / 5), tint: nil)
                }
                if foam[c] > 0.85 && CGFloat.random(in: 0...1) < d * 1.4 * s {
                    spawnBubble(
                        at: CGPoint(x: land.x + CGFloat.random(in: -28...28), y: land.y - foam[c] * 18),
                        v: CGVector(dx: CGFloat.random(in: -28...28), dy: CGFloat.random(in: -66 ... -28))
                    )
                }
            }
        }
        if CGFloat.random(in: 0...1) < flow * d * (hasWater ? 12 : 34) {
            drops.append(SDrop(
                p: CGPoint(x: land.x, y: land.y - 3),
                v: CGVector(dx: CGFloat.random(in: -140...140), dy: CGFloat.random(in: -280 ... -90)),
                r: CGFloat.random(in: 1.5...3),
                kind: .spray
            ))
        }
    }

    func addFoam(_ i: Int, _ amount: CGFloat, tint: RGB?) {
        guard amount > 0, i >= 0, i < SGeo.columns else { return }
        let old = foam[i]
        foam[i] = min(2.4, old + amount)
        let t = tint ?? RGB(1, 1, 1)
        let k = amount / max(0.001, old + amount)
        foamTint[i] = foamTint[i].mix(t, Double(min(1, k)))
    }

    private func stepFoam(_ d: CGFloat) {
        let N = SGeo.columns
        var flux = [CGFloat](repeating: 0, count: N)
        for i in 0..<(N - 1) {
            let g = foam[i] - foam[i + 1]
            let m = abs(g) > 0.18 ? (g - 0.18 * (g > 0 ? 1 : -1)) * 1.6 : g * 0.12
            flux[i] = m * d
        }
        for i in 0..<(N - 1) {
            let f = flux[i]
            if f > 0 {
                let t = foamTint[i]
                foam[i] -= f
                foam[i + 1] += f
                foamTint[i + 1] = foamTint[i + 1].mix(t, Double(min(1, f / max(0.01, foam[i + 1]))))
            } else if f < 0 {
                let t = foamTint[i + 1]
                foam[i + 1] += f
                foam[i] -= f
                foamTint[i] = foamTint[i].mix(t, Double(min(1, -f / max(0.01, foam[i]))))
            }
        }
        if drainFlow > 0.05 && hasWater {
            let c = SGeo.col(SGeo.drain.x)
            for i in 0..<N where i != c {
                let dir = i < c ? 1 : -1
                let m = foam[i] * min(1, d * 0.55 * drainFlow)
                foam[i] -= m
                foam[i + dir] += m
            }
            foam[c] *= max(0, 1 - d * 0.65 * drainFlow)
        }
        let decay: CGFloat = hasWater ? 0.0035 : 0.14
        for i in 0..<N {
            foam[i] = max(0, foam[i] * (1 - decay * d) - 0.0003 * d)
            if foam[i] > 1.15 && hasWater && CGFloat.random(in: 0...1) < d * 0.01 * foam[i] {
                spawnBubble(
                    at: CGPoint(x: SGeo.colX(i), y: surfaceY(SGeo.colX(i)) - foam[i] * 20),
                    v: CGVector(dx: CGFloat.random(in: -15...15), dy: CGFloat.random(in: -48 ... -20))
                )
            }
        }
        var nt = tintA
        for i in 0..<N {
            let l = tintA[max(0, i - 1)]
            let r = tintA[min(N - 1, i + 1)]
            nt[i] = tintA[i] + (l + r - 2 * tintA[i]) * min(0.45, d * 9)
        }
        for i in 1..<(N - 1) where nt[i] > 0.01 {
            let mixK = Double(min(0.5, d * 6))
            tint[i] = tint[i].mix(tint[i - 1].mix(tint[i + 1], 0.5), mixK * 0.5)
        }
        tintA = nt
    }

    // MARK: - Bath bombs & toys

    @discardableResult
    func spawnThing(_ kind: ThingKind, at p: CGPoint, held: Bool) -> Int {
        let toys = things.filter { !$0.isBomb }
        if case .toy = kind, toys.count >= 8, let old = toys.first(where: { !$0.held }) {
            things.removeAll { $0.id == old.id }
        }
        let id = nextID
        nextID += 1
        var t = SThing(id: id, kind: kind, p: p)
        t.held = held
        t.target = p
        t.facing = Bool.random() ? 1 : -1
        things.append(t)
        return id
    }

    func dropIn(_ kind: ThingKind) {
        let x = CGFloat.random(in: 455...755)
        let id = spawnThing(kind, at: CGPoint(x: x, y: 270), held: false)
        if let i = thingIndex(id) {
            things[i].v = CGVector(dx: CGFloat.random(in: -35...35), dy: 80)
        }
        if case .bomb(let bk) = kind {
            if hasEnoughWaterForBomb {
                if bk == .rainbow {
                    discover(.rainbowBath, at: CGPoint(x: x, y: 420))
                }
                fulfillWish(.bathBomb)
            } else {
                play(.plop, 0.55, gap: 0.1)
                pops.append(SPop(p: CGPoint(x: x, y: SGeo.tubBottom - 26), r: 24, sparkle: false))
            }
        }
    }

    func squirtBubbleBath() {
        let x: CGFloat = 620
        soap += 28
        for _ in 0..<14 {
            drops.append(SDrop(
                p: CGPoint(x: x + CGFloat.random(in: -36...36), y: 360 + CGFloat.random(in: -14...14)),
                v: CGVector(dx: CGFloat.random(in: -35...35), dy: CGFloat.random(in: 120...220)),
                r: CGFloat.random(in: 3.4...5),
                kind: .soap
            ))
        }
        if hasWater {
            let c = SGeo.col(x)
            for k in -14...14 {
                let w = max(0, 1 - CGFloat(abs(k)) / 15)
                addFoam(c + k, 0.52 * w, tint: nil)
            }
            disturb(x, 380, width: 22)
        }
        play(.glug, 0.65, gap: 0.25)
    }

    func thingIndex(_ id: Int) -> Int? {
        things.firstIndex { $0.id == id }
    }

    private func stepThings(_ d: CGFloat) {
        let g: CGFloat = 1500
        for i in things.indices {
            var t = things[i]
            let hw = t.half.width
            let hh = t.half.height
            if t.held {
                let old = t.p
                let k = min(1, d * 22)
                t.p = CGPoint(x: t.p.x + (t.target.x - t.p.x) * k, y: t.p.y + (t.target.y - t.p.y) * k)
                t.v = CGVector(dx: (t.p.x - old.x) / d, dy: (t.p.y - old.y) / d)
                if abs(t.v.dx) > 40 { t.facing = t.v.dx > 0 ? 1 : -1 }
                let swing = max(-0.5, min(0.5, -t.v.dx * 0.0007))
                t.av += (swing - t.a) * 60 * d - t.av * 8 * d
                t.a += t.av * d
                t.wasIn = underWater(CGPoint(x: t.p.x, y: t.p.y + hh * 0.5))
                things[i] = t
                continue
            }
            t.v.dy += g * d
            let inside = t.p.x > SGeo.tubL - 4 && t.p.x < SGeo.tubR + 4 && t.p.y + hh > SGeo.lipY - 8
            var sub: CGFloat = 0
            if inside && hasWater {
                let surf = surfaceY(t.p.x)
                sub = max(0, min(1, (t.p.y + hh - surf) / (2 * hh)))
                if sub > 0 {
                    t.v.dy -= g * sub / t.density * d
                    let drag = 1 - min(0.9, sub * 2.6 * d)
                    t.v.dx *= drag
                    t.v.dy *= 1 - min(0.9, sub * 3.4 * d)
                    let s = slope(t.p.x)
                    t.v.dx -= s * g * 0.45 * sub * d
                    let tilt = atan(s) * 0.9
                    t.av += (tilt - t.a) * 40 * d * sub
                    if drainFlow > 0.05 {
                        t.v.dx += (SGeo.drain.x - t.p.x) * 0.65 * drainFlow * d
                    }
                    if t.isBomb && hasEnoughWaterForBomb && t.fizz > 0 && t.wetFor > 0.4 {
                        t.v.dx += CGFloat.random(in: -520...520) * d
                        t.av += CGFloat.random(in: -9...9) * d
                    }
                    let c = SGeo.col(t.p.x)
                    let w = Int(hw / SGeo.colW)
                    for j in max(0, c - w)...min(SGeo.columns - 1, c + w) {
                        hv[j] += (t.v.dy - hv[j]) * 0.015 * sub
                    }
                    if !t.wasIn && t.v.dy > 140 {
                        splash(at: CGPoint(x: t.p.x, y: surf), speed: t.v.dy, size: hw)
                        if case .bomb(let bk) = t.kind, hasEnoughWaterForBomb {
                            surprisedUntil = max(surprisedUntil, time + 0.42)
                            giggleUntil = max(giggleUntil, time + 1.55)
                            bobV -= 55
                            if bk == .rainbow {
                                discover(.rainbowBath, at: CGPoint(x: t.p.x, y: surf - 24))
                            }
                            fulfillWish(.bathBomb)
                        }
                    }
                }
            }
            let nowIn = sub > 0.05
            if nowIn && t.isBomb && hasEnoughWaterForBomb { t.wetFor += d }
            t.wasIn = nowIn
            t.av -= t.a * (sub > 0 ? 0 : 10) * d
            t.av *= max(0, 1 - 5 * d)
            t.a += t.av * d
            if abs(t.v.dx) > 25 { t.facing = t.v.dx > 0 ? 1 : -1 }
            t.p.x += t.v.dx * d
            t.p.y += t.v.dy * d
            if t.dive > 0 { t.dive -= d }

            // Gently steer anything dropped outside back into the cozy tub so toys never get lost behind the dock.
            if !inside && t.p.y > SGeo.lipY {
                if t.p.x <= SGeo.tubL {
                    t.p.x = SGeo.tubL + hw + 10
                    t.v.dx = abs(t.v.dx) * 0.3 + 40
                } else if t.p.x >= SGeo.tubR {
                    t.p.x = SGeo.tubR - hw - 10
                    t.v.dx = -abs(t.v.dx) * 0.3 - 40
                }
            }

            if t.p.y + hh > SGeo.lipY - 8 {
                if t.p.x - hw < SGeo.tubL { t.p.x = SGeo.tubL + hw; t.v.dx = abs(t.v.dx) * 0.4 }
                if t.p.x + hw > SGeo.tubR { t.p.x = SGeo.tubR - hw; t.v.dx = -abs(t.v.dx) * 0.4 }
                if t.p.y + hh > SGeo.chinY && t.p.x - hw < SGeo.bodyR {
                    t.p.x = SGeo.bodyR + hw
                    t.v.dx = abs(t.v.dx) * 0.35 + 16
                }
                if t.p.y + hh > SGeo.tubBottom {
                    t.p.y = SGeo.tubBottom - hh
                    if t.v.dy > 180 && (!hasWater || (t.isBomb && !hasEnoughWaterForBomb)) {
                        play(.plop, 0.35, gap: 0.1)
                        if t.isBomb {
                            pops.append(SPop(p: CGPoint(x: t.p.x, y: SGeo.tubBottom - 10), r: 22, sparkle: false))
                        }
                    }
                    t.v.dy = -abs(t.v.dy) * 0.25
                    t.v.dx *= max(0, 1 - 6 * d)
                    t.av -= t.a * 20 * d
                }
            }
            t.p.x = max(hw + 16, min(1008 - hw, t.p.x))
            t.squashV += (-t.squash * 260 - t.squashV * 12) * d
            t.squash += t.squashV * d
            if case .bomb(let k) = t.kind, hasEnoughWaterForBomb, t.wetFor > 0.28, t.fizz > 0 {
                fizz(&t, k, d)
            }
            things[i] = t
        }
        things.removeAll { $0.isBomb && $0.fizz <= 0 }
        if things.count > 1 {
            for i in 0..<(things.count - 1) {
                for j in (i + 1)..<things.count {
                    let a = things[i], b = things[j]
                    let ra = max(a.half.width, a.half.height) * 0.82
                    let rb = max(b.half.width, b.half.height) * 0.82
                    let dx = b.p.x - a.p.x, dy = b.p.y - a.p.y
                    let dist = hypot(dx, dy)
                    let overlap = ra + rb - dist
                    guard overlap > 0, dist > 0.01 else { continue }
                    let nx = dx / dist, ny = dy / dist
                    let pa: CGFloat = a.held ? 0 : (b.held ? 1 : 0.5)
                    let pb: CGFloat = 1 - pa
                    if !a.held { things[i].p.x -= nx * overlap * pa; things[i].p.y -= ny * overlap * pa }
                    if !b.held { things[j].p.x += nx * overlap * pb; things[j].p.y += ny * overlap * pb }
                    let rv = (b.v.dx - a.v.dx) * nx + (b.v.dy - a.v.dy) * ny
                    if rv < 0 {
                        let imp = -rv * 0.6
                        if !a.held { things[i].v.dx -= nx * imp * pa * 2; things[i].v.dy -= ny * imp * pa * 2 }
                        if !b.held { things[j].v.dx += nx * imp * pb * 2; things[j].v.dy += ny * imp * pb * 2 }
                        if imp > 140 { play(.squeak2, 0.15, gap: 0.3) }
                    }
                }
            }
        }
    }

    private func fizz(_ t: inout SThing, _ k: BombKind, _ d: CGFloat) {
        guard hasEnoughWaterForBomb else { return }
        let under = underWater(t.p)
        t.fizz -= d / 10.5
        if k == .rainbow && !unlockedFinds.contains(.rainbowBath) {
            discover(.rainbowBath, at: t.p)
        }
        if activeWish == .bathBomb {
            fulfillWish(.bathBomb)
        }
        let r = t.half.width
        let col = k.dye(time)
        let n = Int(d * 88 * (0.4 + t.fizz)) + (CGFloat.random(in: 0...1) < 0.5 ? 1 : 0)
        for _ in 0..<n {
            let a = CGFloat.random(in: 0 ... (2 * .pi))
            let p = CGPoint(x: t.p.x + cos(a) * r, y: t.p.y + sin(a) * r)
            if underWater(p) {
                air.append(SAir(p: p, r: CGFloat.random(in: 1...2.6), phase: a, vx: cos(a) * 20))
            }
        }
        if under || t.wasIn {
            if CGFloat.random(in: 0...1) < d * 10 {
                puffs.append(SPuff(
                    p: CGPoint(x: t.p.x + CGFloat.random(in: -r...r), y: t.p.y + CGFloat.random(in: 0...r)),
                    v: CGVector(dx: CGFloat.random(in: -50...50), dy: CGFloat.random(in: -10...45)),
                    r: r * CGFloat.random(in: 0.65...1.15),
                    a: 0.56,
                    color: col
                ))
            }
            let c = SGeo.col(t.p.x)
            for i in max(0, c - 4)...min(SGeo.columns - 1, c + 4) {
                let add = d * 0.2 * (1 - CGFloat(abs(i - c)) / 5)
                tint[i] = tint[i].mix(col, Double(min(1, add / max(0.02, tintA[i] + add)) * 1.5))
                tintA[i] = min(0.95, tintA[i] + add)
                addFoam(i, d * 0.42 * (1 - CGFloat(abs(i - c)) / 5), tint: col)
            }
        }
        if k == .yuzu {
            yuzuCitrus = min(1, yuzuCitrus + d * 0.55)
        }
        if k.glitter && CGFloat.random(in: 0...1) < d * (k == .yuzu ? 36 : 28) {
            let a = CGFloat.random(in: 0 ... (2 * .pi))
            let gold = RGB(hex: "#FFF2A8")
            glitter.append(SGlitter(
                p: CGPoint(x: t.p.x + cos(a) * r, y: t.p.y + sin(a) * r),
                v: CGVector(dx: cos(a) * 32, dy: sin(a) * 20 - 10),
                color: (k == .sunshine || k == .yuzu) ? gold : col.mix(RGB(1, 1, 1), 0.4),
                phase: a
            ))
        }
        if t.fizz <= 0 {
            pops.append(SPop(p: t.p, r: 42, sparkle: true))
            play(.chime, 0.3, gap: 0.4)
        }
    }

    // MARK: - Splashes, drops, air

    func splash(at p: CGPoint, speed: CGFloat, size: CGFloat) {
        let power = min(1.5, speed * size / 30000)
        disturb(p.x, speed * size / 145, width: max(10, size * 0.7))
        let n = Int(6 + power * 24)
        for _ in 0..<n {
            let side: CGFloat = Bool.random() ? 1 : -1
            drops.append(SDrop(
                p: CGPoint(x: p.x + side * CGFloat.random(in: 0...size), y: p.y - 2),
                v: CGVector(
                    dx: side * CGFloat.random(in: 35...220) * (0.5 + power),
                    dy: -CGFloat.random(in: 150...460) * (0.5 + power * 0.65)
                ),
                r: CGFloat.random(in: 1.8...4.0)
            ))
        }
        for _ in 0..<Int(4 + power * 12) {
            air.append(SAir(
                p: CGPoint(x: p.x + CGFloat.random(in: -size...size), y: p.y + CGFloat.random(in: 6...(20 + size))),
                r: CGFloat.random(in: 1.5...4.8),
                phase: CGFloat.random(in: 0...6)
            ))
        }
        if soapiness > 0.05 {
            let c = SGeo.col(p.x)
            for i in max(0, c - 5)...min(SGeo.columns - 1, c + 5) {
                addFoam(i, 0.055 * power * soapiness, tint: nil)
            }
        }
        if power > 0.6 {
            play(.bigsplash, 0.8, gap: 0.15)
        } else {
            play(.splash, 0.3 + Float(power) * 0.6, gap: 0.08)
        }
    }

    private func stepDrops(_ d: CGFloat) {
        var keep: [SDrop] = []
        keep.reserveCapacity(drops.count)
        for var dr in drops {
            let wasInTubX = dr.p.x > SGeo.tubL && dr.p.x < SGeo.tubR
            dr.v.dy += 1500 * d
            dr.p.x += dr.v.dx * d
            dr.p.y += dr.v.dy * d
            dr.age += d
            let nowInTubX = dr.p.x > SGeo.tubL && dr.p.x < SGeo.tubR
            if wasInTubX != nowInTubX && dr.p.y > SGeo.lipY {
                dr.v.dx = -dr.v.dx * 0.3
                dr.p.x = wasInTubX ? (dr.p.x <= SGeo.tubL ? SGeo.tubL + 1 : SGeo.tubR - 1)
                                   : (dr.p.x >= SGeo.tubR ? SGeo.tubR + 12 : SGeo.tubL - 12)
            }
            if dr.p.y < -40 || dr.p.x < -40 || dr.p.x > 1064 || dr.age > 5 { continue }
            if dr.v.dy > 0 {
                let dd = SGeo.toDoll(dr.p)
                if SGeo.onHer(dd) {
                    if CGFloat.random(in: 0...1) < 0.32 { addBead(dd) }
                    if dr.kind == .water || dr.kind == .spray { rinse(at: dd, amount: 0.06) }
                    if CGFloat.random(in: 0...1) < 0.6 { continue }
                }
            }
            if nowInTubX && dr.p.y > SGeo.lipY - 2 {
                if hasWater && dr.p.y > surfaceY(dr.p.x) {
                    disturb(dr.p.x, dr.r * dr.v.dy * 0.045, width: 6)
                    if dr.kind == .soap {
                        soap += 0.6
                        let c = SGeo.col(dr.p.x)
                        for i in max(0, c - 2)...min(SGeo.columns - 1, c + 2) { addFoam(i, 0.035, tint: nil) }
                        puffs.append(SPuff(
                            p: CGPoint(x: dr.p.x, y: dr.p.y + 8),
                            v: CGVector(dx: CGFloat.random(in: -20...20), dy: 35),
                            r: 10,
                            a: 0.35,
                            color: RGB(hex: "#FFB0D0")
                        ))
                        play(.drip, 0.3, gap: 0.12)
                    } else {
                        if dr.r > 3 && CGFloat.random(in: 0...1) < 0.28 { play(.drip, 0.18, gap: 0.09) }
                        if foam[SGeo.col(dr.p.x)] > 0.1 { foam[SGeo.col(dr.p.x)] *= 0.995 }
                    }
                    continue
                }
                if dr.p.y > SGeo.tubBottom {
                    if dr.kind == .soap { soap += 0.6 }
                    continue
                }
            }
            if !nowInTubX && dr.p.y > SGeo.floorY {
                continue
            }
            keep.append(dr)
        }
        if keep.count > 260 { keep.removeFirst(keep.count - 260) }
        drops = keep
    }

    private func stepAir(_ d: CGFloat) {
        var keep: [SAir] = []
        keep.reserveCapacity(air.count)
        for var b in air {
            b.phase += d * 9
            let rise = 45 + b.r * 22
            b.p.y -= rise * d
            b.vx *= max(0, 1 - d * 3)
            b.p.x += (sin(b.phase) * b.r * 6 + b.vx) * d
            guard inTub(b.p), hasWater else { continue }
            let surf = surfaceY(b.p.x)
            if b.p.y <= surf + b.r * 0.5 {
                disturb(b.p.x, -b.r * 4, width: 5)
                if soapiness > 0.05 { addFoam(SGeo.col(b.p.x), 0.004 * b.r * soapiness, tint: nil) }
                continue
            }
            keep.append(b)
        }
        if keep.count > 450 { keep.removeFirst(keep.count - 450) }
        air = keep
    }

    // MARK: - Soap bubbles & star bubbles

    func spawnBubble(at p: CGPoint, v: CGVector, r: CGFloat? = nil, star: Bool = false) {
        guard bubbles.count < 56 else { return }
        let radius = r ?? (star ? 34 : CGFloat.random(in: 14...32))
        bubbles.append(SBubble(
            star: star,
            p: p,
            v: v,
            r: radius,
            life: star ? 13 : CGFloat.random(in: 7...14),
            phase: CGFloat.random(in: 0 ... (2 * .pi))
        ))
    }

    /// 1-tap on the always-ready Rainbow Bubble Wand immediately blows shimmering giant bubbles + a star bubble!
    func blowWandBurst() {
        let origin = CGPoint(x: 560, y: 390)
        for k in 0..<6 {
            let angle = -CGFloat.pi * 0.8 + CGFloat(k) * 0.28
            let speed = CGFloat.random(in: 75...145)
            let isStar = k == 2
            spawnBubble(
                at: CGPoint(x: origin.x + CGFloat(k - 3) * 18, y: origin.y + CGFloat.random(in: -22...18)),
                v: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 35),
                r: isStar ? 35 : CGFloat.random(in: 18...34),
                star: isStar
            )
        }
        giggleUntil = max(giggleUntil, time + 0.9)
        play(.blow, 0.55, gap: 0.12)
    }

    func popBubble(_ i: Int, loud: Bool = true) {
        let b = bubbles[i]
        pops.append(SPop(p: b.p, r: b.r, sparkle: b.star))
        for _ in 0..<Int(3 + b.r / 6) {
            let a = CGFloat.random(in: 0 ... (2 * .pi))
            drops.append(SDrop(
                p: CGPoint(x: b.p.x + cos(a) * b.r, y: b.p.y + sin(a) * b.r),
                v: CGVector(dx: cos(a) * 110, dy: sin(a) * 110 - 50),
                r: 1.3,
                kind: .spray
            ))
        }
        bubbles.remove(at: i)
        if loud { play(.pop, 0.75, gap: 0.03) }
    }

    private func touchBubble(_ i: Int) {
        let bubble = bubbles[i]
        popBubble(i)
        guard bubble.star else { return }
        starsPopped += 1
        pops.append(SPop(p: bubble.p, r: 44, sparkle: true))
        spawnHearts(at: bubble.p, count: 3)
        if starsPopped >= Self.starGoal {
            starsPopped = 0
            dropIn(.bomb(.rainbow))
            discover(.starPopper, at: bubble.p)
            giggle()
            play(.chime, 0.85)
        }
    }

    private func stepBubbles(_ d: CGFloat) {
        var i = bubbles.count - 1
        while i >= 0 {
            var b = bubbles[i]
            b.age += d
            b.phase += d * 0.8
            b.v.dy -= 8 * d
            b.v.dx += sin(CGFloat(time) * 0.9 + b.phase * 3) * 14 * d
            if hand != .none {
                let dx = b.p.x - handP.x, dy = b.p.y - handP.y
                let dist = hypot(dx, dy)
                if dist < 120 {
                    b.v.dx += handV.dx * 0.5 * d * (1 - dist / 120)
                    b.v.dy += handV.dy * 0.5 * d * (1 - dist / 120)
                }
            }
            b.v.dx *= max(0, 1 - 0.9 * d)
            b.v.dy *= max(0, 1 - 0.9 * d)
            b.p.x += b.v.dx * d
            b.p.y += b.v.dy * d
            bubbles[i] = b
            var pop = b.age > b.life || b.p.y < b.r + 74 || b.p.x < b.r || b.p.x > 1024 - b.r || b.p.y > SGeo.floorY
            if !pop && hasWater && inTub(b.p) && b.p.y + b.r > surfaceY(b.p.x) {
                let f = foam[SGeo.col(b.p.x)]
                if f < 0.25 {
                    pop = true
                } else {
                    bubbles[i].v.dy = min(bubbles[i].v.dy, -4)
                    bubbles[i].p.y = surfaceY(b.p.x) - b.r
                }
            }
            if pop { popBubble(i, loud: b.age < b.life + 1) }
            i -= 1
        }
        for j in pops.indices { pops[j].age += d }
        pops.removeAll { $0.age > ($0.sparkle ? 0.9 : 0.22) }
    }

    // MARK: - Color clouds, glitter, steam, hearts

    private func stepPuffs(_ d: CGFloat) {
        for i in puffs.indices {
            var p = puffs[i]
            p.age += d
            p.r += d * (26 + p.r * 0.24)
            p.a *= max(0, 1 - d * 0.34)
            p.v.dx *= max(0, 1 - d * 0.9)
            p.v.dy *= max(0, 1 - d * 0.9)
            p.p.x += p.v.dx * d + sin(CGFloat(time) * 0.7 + CGFloat(i)) * 6 * d
            p.p.y += p.v.dy * d
            p.p.x = max(SGeo.tubL + 10, min(SGeo.tubR - 10, p.p.x))
            p.p.y = min(SGeo.tubBottom - 10, max(level + 10, p.p.y))
            puffs[i] = p
        }
        puffs.removeAll { $0.a < 0.02 || !hasWater }
        if puffs.count > 70 { puffs.removeFirst(puffs.count - 70) }
        for i in glitter.indices {
            var gl = glitter[i]
            gl.age += d
            gl.phase += d * 5
            if !gl.settled {
                gl.v.dx *= max(0, 1 - d * 2)
                gl.v.dy += (14 - gl.v.dy) * min(1, d * 2)
                gl.p.x += (gl.v.dx + sin(gl.phase) * 8) * d
                gl.p.y += gl.v.dy * d
                let b = SGeo.tubBottom - 4
                if gl.p.y > b { gl.p.y = b; gl.settled = true }
                if !underWater(gl.p) && gl.p.y < level { gl.p.y = level + 2 }
            }
            glitter[i] = gl
        }
        glitter.removeAll { !hasWater || $0.age > 36 }
        if glitter.count > 240 { glitter.removeFirst(glitter.count - 240) }
        if vol > 0.5 {
            for i in 0..<SGeo.columns { tintA[i] = max(0, tintA[i] - d * 0.0012) }
        }
    }

    private func stepSteam(_ d: CGFloat) {
        if hasWater && warm > 0.05 && CGFloat.random(in: 0...1) < d * 4.5 * warm {
            let x = CGFloat.random(in: (SGeo.tubL + 40)...(SGeo.tubR - 30))
            steam.append(SSteam(
                p: CGPoint(x: x, y: surfaceY(x) - 10),
                v: CGVector(dx: CGFloat.random(in: -8...8), dy: -CGFloat.random(in: 18...34)),
                r: CGFloat.random(in: 18...32),
                life: CGFloat.random(in: 3.5...6.5)
            ))
        }
        for i in steam.indices {
            steam[i].age += d
            steam[i].r += d * 9
            steam[i].p.x += (steam[i].v.dx + sin(CGFloat(time) * 0.6 + CGFloat(i)) * 6) * d
            steam[i].p.y += steam[i].v.dy * d
        }
        steam.removeAll { $0.age > $0.life }

        // Mirror steams up visibly within ~4 seconds of warm water; finger-drawn lines stay crisp until wiped with towel/shower or reset.
        let grow = (time >= mirrorFreshUntil && hasWater) ? warm * 0.58 : 0
        if grow > 0.001 {
            for i in fog.indices where !fogCleared[i] {
                let r = i / SGeo.fogCols
                let toward: CGFloat = 0.94 - CGFloat(r) * 0.006
                fog[i] += (toward - fog[i]) * min(1, grow * d)
            }
        }
    }

    private func stepHearts(_ d: CGFloat) {
        for i in hearts.indices {
            hearts[i].age += d
            hearts[i].p.x += (hearts[i].v.dx + sin(CGFloat(time) * 4 + hearts[i].phase) * 18) * d
            hearts[i].p.y += hearts[i].v.dy * d
            hearts[i].v.dx *= max(0, 1 - d * 1.4)
        }
        hearts.removeAll { $0.age >= $0.life }
    }

    // MARK: - Silly Foam Puffs (folded cleanly into SpaSim)

    @discardableResult
    func addFoamPuff(at dollPoint: CGPoint, tint: RGB = RGB(1, 1, 1), radius: CGFloat = 28) -> Int {
        let anchor = SGeo.clampFoamAnchor(dollPoint)
        if let existing = foamPuffs.firstIndex(where: { !$0.flung && hypot($0.anchor.x - anchor.x, $0.anchor.y - anchor.y) < 18 }) {
            foamPuffs[existing].radius = min(44, foamPuffs[existing].radius + 4)
            foamPuffs[existing].tint = foamPuffs[existing].tint.mix(tint, 0.5)
            foamPuffs[existing].vel.dy -= 65
            checkFoamMilestones()
            return foamPuffs[existing].id
        }
        if foamPuffs.count >= 28 {
            foamPuffs.removeFirst()
        }
        let id = nextPuffID
        nextPuffID += 1
        let puff = FoamPuff(
            id: id,
            anchor: anchor,
            offset: CGVector(dx: 0, dy: -8),
            vel: CGVector(dx: CGFloat.random(in: -30...30), dy: -90),
            radius: radius,
            tint: tint,
            seed: id * 17 + 7
        )
        foamPuffs.append(puff)
        checkFoamMilestones()
        return id
    }

    /// 1-tap on a Foam Puff Sponge cycles through Bubble Crown, Bunny Ears, and Bubble Beard!
    func applyNextFoamStyle(tint: FoamTint) {
        let col = tint.color
        let style = foamStyleIndex % 3
        foamStyleIndex += 1
        let preset: [(CGPoint, CGFloat)]
        switch style {
        case 0: // Bubble crown
            preset = [
                (CGPoint(x: 215, y: 186), 28),
                (CGPoint(x: 256, y: 158), 32),
                (CGPoint(x: 300, y: 142), 38),
                (CGPoint(x: 344, y: 158), 32),
                (CGPoint(x: 385, y: 186), 28),
            ]
        case 1: // Bouncy bunny ears
            preset = [
                (CGPoint(x: 226, y: 170), 30),
                (CGPoint(x: 210, y: 126), 27),
                (CGPoint(x: 202, y: 88), 23),
                (CGPoint(x: 374, y: 170), 30),
                (CGPoint(x: 390, y: 126), 27),
                (CGPoint(x: 398, y: 88), 23),
            ]
        default: // Fluffy bubble beard
            preset = [
                (CGPoint(x: 222, y: 404), 26),
                (CGPoint(x: 260, y: 428), 30),
                (CGPoint(x: 300, y: 438), 34),
                (CGPoint(x: 340, y: 428), 30),
                (CGPoint(x: 378, y: 404), 26),
            ]
        }
        for (pt, r) in preset {
            let id = nextPuffID
            nextPuffID += 1
            if foamPuffs.count >= 28 { foamPuffs.removeFirst() }
            foamPuffs.append(FoamPuff(
                id: id,
                anchor: pt,
                offset: CGVector(dx: 0, dy: -10),
                vel: CGVector(dx: (pt.x - 300) * 0.4, dy: -120),
                radius: r,
                tint: col,
                seed: id * 19 + 3
            ))
        }
        giggleUntil = max(giggleUntil, time + 1.1)
        bobV -= 50
        play(.squish, 0.55)
        checkFoamMilestones()
    }

    private func checkFoamMilestones() {
        let activeCount = foamPuffs.filter { !$0.flung }.count
        if activeCount >= 3 {
            discover(.bubbleCrown, at: SGeo.fromDoll(CGPoint(x: 300, y: 150)))
            fulfillWish(.foamHair)
        }
    }

    /// Always-active nose tap: big cartoon ACHOO! that wobbles & flings foam puffs with giggles.
    func sneezeFoam() {
        sneezeUntil = time + 0.62
        giggleUntil = max(giggleUntil, time + 1.8)
        bobV -= 115
        var flungCount = 0
        for i in foamPuffs.indices.reversed() where !foamPuffs[i].flung {
            let side: CGFloat = foamPuffs[i].anchor.x < 300 ? -1 : 1
            foamPuffs[i].vel.dx += side * CGFloat.random(in: 240...420)
            foamPuffs[i].vel.dy -= CGFloat.random(in: 240...380)
            if flungCount < 3 && (foamPuffs[i].anchor.y < 165 || abs(foamPuffs[i].anchor.x - 300) > 88) {
                foamPuffs[i].flung = true
                flungCount += 1
            }
        }
        for i in 0..<8 {
            let spread = CGFloat(i - 3) - 0.5
            spawnBubble(
                at: SGeo.fromDoll(CGPoint(x: SGeo.nose.x + spread * 10, y: SGeo.nose.y - 6)),
                v: CGVector(dx: spread * 54, dy: -110 - abs(spread) * 22),
                r: CGFloat.random(in: 7...16)
            )
        }
        pops.append(SPop(p: SGeo.fromDoll(SGeo.nose), r: 34, sparkle: true))
        spawnHearts(at: SGeo.fromDoll(CGPoint(x: 300, y: 240)), count: 3)
        discover(.sneezeGiggle, at: SGeo.fromDoll(SGeo.nose))
        play(.blow, 0.6, gap: 0.15)
        play(.pop, 0.55, gap: 0.1)
    }

    func rinseFoamPuffs(at dollPoint: CGPoint, radius: CGFloat = 70) {
        let before = foamPuffs.count
        foamPuffs.removeAll { puff in
            hypot(puff.position.x - dollPoint.x, puff.position.y - dollPoint.y) < radius + puff.radius * 0.65
        }
        if foamPuffs.count < before {
            for _ in 0..<(before - foamPuffs.count) {
                addBead(CGPoint(x: dollPoint.x + CGFloat.random(in: -22...22), y: max(220, dollPoint.y)))
            }
        }
    }

    private func stepFoamPuffs(_ d: CGFloat) {
        var heldID: Int?
        if case .puff(let id) = hand { heldID = id }
        for i in foamPuffs.indices {
            var p = foamPuffs[i]
            p.age += d
            if p.flung {
                p.vel.dy += 680 * d
                p.offset.dx += p.vel.dx * d
                p.offset.dy += p.vel.dy * d
            } else if p.id != heldID {
                let k: CGFloat = 140
                let damp: CGFloat = 8.5
                p.vel.dx += (-p.offset.dx * k - p.vel.dx * damp) * d
                p.vel.dy += (-p.offset.dy * k - p.vel.dy * damp) * d
                p.offset.dx += p.vel.dx * d
                p.offset.dy += p.vel.dy * d
            }
            foamPuffs[i] = p
        }
        foamPuffs.removeAll { $0.flung && $0.age > 0.9 }
    }

    // MARK: - Sparkling Hand Shower (1-tap quick cascade + drag)

    func triggerQuickShower() {
        quickShowerUntil = time + 1.25
        giggleUntil = max(giggleUntil, time + 1.5)
        play(.splash, 0.55)
    }

    private func stepQuickShower(_ d: CGFloat) {
        let remaining = quickShowerUntil - time
        guard remaining > 0 else { return }
        let progress = CGFloat(1 - remaining / 1.25)
        let sweepY: CGFloat = 95 + progress * 440
        for x in stride(from: CGFloat(150), through: 450, by: 46) {
            rinse(at: CGPoint(x: x, y: sweepY), amount: d * 4.2)
            wipeMask(at: CGPoint(x: x, y: sweepY), radius: 75, amount: d * 3.0)
        }
        if drops.count < 220 {
            for _ in 0..<4 {
                let start = SGeo.fromDoll(CGPoint(x: CGFloat.random(in: 170...430), y: max(70, sweepY - 45)))
                drops.append(SDrop(
                    p: start,
                    v: CGVector(dx: CGFloat.random(in: -35...35), dy: CGFloat.random(in: 300...420)),
                    r: CGFloat.random(in: 1.6...2.6),
                    kind: .spray
                ))
            }
        }
    }

    // MARK: - Doll reactions, masks, cucumbers, cozy towel, mist

    func spaExpression() -> SpaExpression {
        if time < sneezeUntil { return .sneeze }
        if cucumbersOn { return .zen }
        if time < surprisedUntil { return .surprised }
        if time < giggleUntil { return .giggle }
        if time < cozyUntil { return .cozy }
        return .happy
    }

    func expression() -> Expression {
        switch spaExpression() {
        case .sneeze, .zen:
            return .blink
        case .giggle, .cozy:
            return .happy
        case .surprised:
            return .normal
        case .happy:
            if time > blinkAt && time < blinkAt + 0.14 { return .blink }
            return .normal
        }
    }

    func giggle() {
        giggleUntil = max(giggleUntil, time + 1.45)
        bobV -= 75
        if hasWater {
            for x in [SGeo.bodyL - 12, SGeo.bodyR + 18] {
                let s = surfaceY(x)
                disturb(x, 220, width: 14)
                for _ in 0..<8 {
                    let side: CGFloat = x < 282 ? -1 : 1
                    drops.append(SDrop(
                        p: CGPoint(x: x, y: s - 2),
                        v: CGVector(dx: side * CGFloat.random(in: 30...170), dy: -CGFloat.random(in: 180...400)),
                        r: CGFloat.random(in: 1.8...3.4)
                    ))
                }
            }
            play(.slosh, 0.55, gap: 0.2)
        } else {
            play(.squeak2, 0.28, gap: 0.2)
        }
        pops.append(SPop(p: SGeo.fromDoll(CGPoint(x: 300, y: 200)), r: 30, sparkle: true))
    }

    func addBead(_ d: CGPoint) {
        guard SGeo.onHer(d), beads.count < 42 else { return }
        beads.append(SBead(d: d, r: CGFloat.random(in: 4...7.5)))
    }

    func addSud(_ d: CGPoint, r: CGFloat) {
        guard SGeo.onHer(d, pad: 20), suds.count < 52 else { return }
        suds.append(SSud(d: d, r: r, phase: CGFloat.random(in: 0...6)))
    }

    /// Shower water washes away foam puffs, suds, AND face masks cleanly.
    func rinse(at d: CGPoint, amount: CGFloat) {
        rinseFoamPuffs(at: d, radius: 56 * FingerLift.spread)
        let before = suds.count
        suds.removeAll { hypot($0.d.x - d.x, $0.d.y - d.y) < 44 * FingerLift.spread && CGFloat.random(in: 0...1) < max(0.35, amount * 6) }
        if suds.count < before {
            for _ in 0..<(before - suds.count) {
                addBead(CGPoint(x: d.x + CGFloat.random(in: -20...20), y: d.y))
            }
        }
        wipeMask(at: d, radius: 42 * FingerLift.spread, amount: amount * 1.1)
    }

    func paintMask(at d: CGPoint, kind: MaskKind, amount: CGFloat) {
        var paintedAny = false
        for (i, c) in maskCells(near: d, radius: 38 * FingerLift.spread) {
            let w = 1 - c
            maskKind[i] = kind.rawValue
            maskCov[i] = min(1, maskCov[i] + amount * w)
            maskDry[i] *= 0.6
            paintedAny = true
        }
        if paintedAny {
            if kind == .strawberry {
                discover(.strawberryMask, at: SGeo.fromDoll(CGPoint(x: 300, y: 310)))
            }
            fulfillWish(.faceMask)
        }
    }

    /// 1-tap on a Face Mask tile smoothly paints a full pastel spa mask on her cheeks & forehead.
    func applyFullMask(_ kind: MaskKind) {
        for i in maskCov.indices {
            let c = maskCellCenter(i)
            if SGeo.inHead(c, pad: -10) {
                maskCov[i] = 1
                maskKind[i] = kind.rawValue
                maskDry[i] = 0.08
            }
        }
        giggleUntil = max(giggleUntil, time + 1.0)
        pops.append(SPop(p: SGeo.fromDoll(CGPoint(x: 300, y: 300)), r: 40, sparkle: true))
        play(.squish, 0.55)
        if kind == .strawberry {
            discover(.strawberryMask, at: SGeo.fromDoll(CGPoint(x: 300, y: 310)))
        }
        fulfillWish(.faceMask)
    }

    func wipeMask(at d: CGPoint, radius: CGFloat, amount: CGFloat) {
        for (i, c) in maskCells(near: d, radius: radius) {
            maskCov[i] = max(0, maskCov[i] - amount * (1 - c * 0.45))
        }
    }

    private func maskCells(near d: CGPoint, radius: CGFloat) -> [(Int, CGFloat)] {
        let r = SGeo.maskRect
        let cw = r.width / CGFloat(SGeo.maskCols)
        let ch = r.height / CGFloat(SGeo.maskRows)
        var out: [(Int, CGFloat)] = []
        let c0 = max(0, Int((d.x - radius - r.minX) / cw))
        let c1 = min(SGeo.maskCols - 1, Int((d.x + radius - r.minX) / cw))
        let r0 = max(0, Int((d.y - radius - r.minY) / ch))
        let r1 = min(SGeo.maskRows - 1, Int((d.y + radius - r.minY) / ch))
        guard c0 <= c1, r0 <= r1 else { return [] }
        for row in r0...r1 {
            for col in c0...c1 {
                let cx = r.minX + (CGFloat(col) + 0.5) * cw
                let cy = r.minY + (CGFloat(row) + 0.5) * ch
                let dist = hypot(cx - d.x, cy - d.y)
                if dist < radius && SGeo.inHead(CGPoint(x: cx, y: cy), pad: -6) {
                    out.append((row * SGeo.maskCols + col, dist / radius))
                }
            }
        }
        return out
    }

    func maskCellCenter(_ i: Int) -> CGPoint {
        let r = SGeo.maskRect
        let cw = r.width / CGFloat(SGeo.maskCols)
        let ch = r.height / CGFloat(SGeo.maskRows)
        return CGPoint(
            x: r.minX + (CGFloat(i % SGeo.maskCols) + 0.5) * cw,
            y: r.minY + (CGFloat(i / SGeo.maskCols) + 0.5) * ch
        )
    }

    /// 1-tap or drag puts BOTH paired cucumber slices neatly over her eyes at once (zero floor clutter!).
    func putCucumbersOn() {
        cucumbersOn = true
        let p = SGeo.fromDoll(CGPoint(x: 300, y: 270))
        pops.append(SPop(p: p, r: 34, sparkle: true))
        spawnHearts(at: p, count: 3)
        play(.squish, 0.55)
        discover(.cucumberZen, at: p)
        fulfillWish(.cucumbers)
    }

    /// Pops BOTH cucumber slices cleanly off with a sparkle (never dumps loose slices on the floor!).
    func removeCucumbers() {
        guard cucumbersOn else { return }
        cucumbersOn = false
        for eye in SGeo.eyes {
            pops.append(SPop(p: SGeo.fromDoll(eye), r: 22, sparkle: false))
        }
        giggleUntil = max(giggleUntil, time + 0.85)
        play(.pop, 0.55)
    }

    func toggleCucumbers() {
        if cucumbersOn { removeCucumbers() } else { putCucumbersOn() }
    }

    /// Fluffy Pink Towel pats her dry, wraps a cozy glow around her shoulders, NEVER erases face masks!
    func applyCozyTowel() {
        beads.removeAll()
        cozyUntil = time + 4.5
        let p = SGeo.fromDoll(CGPoint(x: 300, y: 410))
        pops.append(SPop(p: p, r: 54, sparkle: true))
        spawnHearts(at: SGeo.fromDoll(CGPoint(x: 300, y: 270)), count: 5)
        play(.chime, 0.55, gap: 0.35)
        discover(.cozyWrap, at: p)
        fulfillWish(.cozyTowel)
    }

    func putSheepTowelOn(tint: FoamTint? = nil) {
        if let tint { sheepTowelTint = tint }
        sheepTowelOn = true
        cozyUntil = max(cozyUntil, time + 4.5)
        let crown = SGeo.fromDoll(CGPoint(x: 300, y: 170))
        pops.append(SPop(p: crown, r: 44, sparkle: true))
        spawnHearts(at: crown, count: 5)
        giggleUntil = max(giggleUntil, time + 1.2)
        bobV -= 65
        play(.squish, 0.55)
        play(.chime, 0.5, gap: 0.25)
        discover(.cozyWrap, at: crown)
        fulfillWish(.cozyTowel)
    }

    func removeSheepTowel() {
        guard sheepTowelOn else { return }
        sheepTowelOn = false
        for side in [-1.0, 1.0] {
            pops.append(SPop(p: SGeo.fromDoll(CGPoint(x: 300 + CGFloat(side) * 144, y: 212)), r: 24, sparkle: false))
        }
        giggleUntil = max(giggleUntil, time + 0.85)
        play(.pop, 0.55)
    }

    func toggleSheepTowel() {
        if sheepTowelOn { removeSheepTowel() } else { putSheepTowelOn() }
    }

    func cycleSheepTowelTint() {
        guard sheepTowelOn else { return }
        let all = FoamTint.allCases
        if let idx = all.firstIndex(of: sheepTowelTint) {
            sheepTowelTint = all[(idx + 1) % all.count]
        }
        let crown = SGeo.fromDoll(CGPoint(x: 300, y: 180))
        pops.append(SPop(p: crown, r: 34, sparkle: true))
        giggleUntil = max(giggleUntil, time + 0.85)
        bobV -= 45
        play(.pop, 0.55)
    }

    /// Sparkle Mist spritzes twinkling stars & floating hearts around her!
    func spritzMist(at p: CGPoint) {
        pops.append(SPop(p: p, r: 32, sparkle: true))
        spawnHearts(at: p, count: 2)
        giggleUntil = max(giggleUntil, time + 1.1)
        play(.chime, 0.4, gap: 0.25)
    }

    func spritzMistBurst() {
        let head = SGeo.fromDoll(CGPoint(x: 300, y: 280))
        for k in 0..<3 {
            let offset = CGPoint(x: head.x + CGFloat(k - 1) * 52, y: head.y + CGFloat(k % 2 == 0 ? -24 : 20))
            pops.append(SPop(p: offset, r: 38, sparkle: true))
        }
        spawnHearts(at: head, count: 6)
        giggleUntil = max(giggleUntil, time + 1.4)
        bobV -= 50
        play(.chime, 0.65, gap: 0.15)
    }

    private func stepHer(_ d: CGFloat) {
        if time > blinkAt + 0.14 { blinkAt = time + Double.random(in: 2.6...5.4) }
        bobV += (-bob * 220 - bobV * 9) * d
        bob += bobV * d
        for i in beads.indices {
            beads[i].vy += (12 + beads[i].r * 2 - beads[i].vy) * d * 0.8
            beads[i].d.y += beads[i].vy * d * (CGFloat.random(in: 0...1) < 0.3 ? 2.4 : 0.4)
        }
        let dripped = beads.filter { $0.d.y > 540 || (!SGeo.onHer($0.d) && $0.d.y > 420) }
        for b in dripped {
            drops.append(SDrop(p: SGeo.fromDoll(b.d), v: CGVector(dx: 0, dy: 30), r: b.r * 0.5))
        }
        beads.removeAll { $0.d.y > 540 || (!SGeo.onHer($0.d) && $0.d.y > 420) }
        let waterDoll = SGeo.toDoll(CGPoint(x: 282, y: level)).y
        suds.removeAll { $0.d.y > waterDoll + 6 && hasWater }
        for i in maskCov.indices where maskCov[i] > 0.05 {
            maskDry[i] = min(1, maskDry[i] + d / 14)
        }
    }

    // MARK: - Bare finger touch

    func handBegan(_ p: CGPoint) {
        handP = p
        handV = .zero
        hand = .none

        // 1. Pop a floating bubble
        if let i = bubbles.indices.reversed().first(where: {
            hypot(bubbles[$0].p.x - p.x, bubbles[$0].p.y - p.y) < bubbles[$0].r + 18
        }) {
            touchBubble(i)
            hand = .pop
            return
        }

        // 2. Pick up / tap a floating toy or bath bomb
        if let i = things.indices.reversed().first(where: {
            let t = things[$0]
            return abs(t.p.x - p.x) < t.half.width + 18 && abs(t.p.y - p.y) < t.half.height + 22
        }) {
            things[i].held = true
            things[i].target = things[i].p
            hand = .thing(things[i].id)
            Sound.shared.tap()
            return
        }

        // 3. Brass faucet handle / spout
        if hypot(p.x - SGeo.handle.x, p.y - SGeo.handle.y) < 62 ||
            hypot(p.x - SGeo.spout.x, p.y - (SGeo.spout.y - 16)) < 46 {
            toggleTap()
            return
        }

        // 4. Drain pull-chain
        if plugHit(p) {
            togglePlug()
            return
        }

        let dd = SGeo.toDoll(p)

        // 5. Always-active nose tap -> cartoon ACHOO! sneeze
        if hypot(dd.x - SGeo.nose.x, dd.y - SGeo.nose.y) < 42 {
            sneezeFoam()
            return
        }

        // 6. Tap either paired cucumber slice to pop both off cleanly
        if cucumbersOn {
            for eye in SGeo.eyes where hypot(eye.x - dd.x, eye.y - dd.y) < 68 {
                removeCucumbers()
                return
            }
        }

        // 6b. Tap either sheep-horn towel bun to cycle pastel terry colors
        if sheepTowelOn {
            for bun in [CGPoint(x: 156, y: 214), CGPoint(x: 444, y: 214)] {
                if hypot(bun.x - dd.x, bun.y - dd.y) < 54 {
                    cycleSheepTowelTint()
                    return
                }
            }
        }

        // 7. Grab & jiggle bouncy foam puffs directly
        if let puff = foamPuffs.reversed().first(where: { !$0.flung && hypot($0.position.x - dd.x, $0.position.y - dd.y) < $0.radius + 14 }) {
            hand = .puff(puff.id)
            play(.squish, 0.45, gap: 0.12)
            return
        }

        // 8. Wipe steamed vanity mirror
        if SGeo.mirror.insetBy(dx: -8, dy: -8).contains(p) {
            hand = .wipe
            wipe(p)
            return
        }

        // 9. Tickle her
        if SGeo.inHead(dd, pad: 12) {
            hand = .girl
            return
        }

        // 10. Swish in the warm bubbly water
        if inTub(p) && (!hasWater || p.y > surfaceY(p.x) - 42) {
            hand = .swish
            return
        }
        hand = .none
    }

    func plugHit(_ p: CGPoint) -> Bool {
        let a = SGeo.plugRing
        let b = plugOut ? CGPoint(x: SGeo.plugRing.x - 24, y: SGeo.plugRing.y + 92) : SGeo.drain
        let dx = b.x - a.x, dy = b.y - a.y
        let denom = max(1, dx * dx + dy * dy)
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / denom))
        let q = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        return hypot(p.x - q.x, p.y - q.y) < 36
    }

    func handMoved(_ p: CGPoint, dt: CGFloat) {
        let v = CGVector(dx: (p.x - handP.x) / dt, dy: (p.y - handP.y) / dt)
        handV = CGVector(dx: handV.dx * 0.5 + v.dx * 0.5, dy: handV.dy * 0.5 + v.dy * 0.5)
        let prev = handP
        handP = p

        if let i = bubbles.indices.reversed().first(where: {
            hypot(bubbles[$0].p.x - p.x, bubbles[$0].p.y - p.y) < bubbles[$0].r + 10
        }) {
            touchBubble(i)
        }

        switch hand {
        case .thing(let id):
            if let i = thingIndex(id) {
                let hh = things[i].half.height
                things[i].target = FingerLift.point(p, lift: FingerLift.carry(below: hh), bottom: DesignCanvas<EmptyView>.designHeight, width: 1024)
            }
        case .puff(let id):
            if let i = foamPuffs.firstIndex(where: { $0.id == id }) {
                let dd = SGeo.toDoll(p)
                let dx = max(-54, min(54, dd.x - foamPuffs[i].anchor.x))
                let dy = max(-54, min(54, dd.y - foamPuffs[i].anchor.y))
                foamPuffs[i].offset = CGVector(dx: dx, dy: dy)
                foamPuffs[i].vel = .zero
            }
        case .wipe:
            let steps = max(1, Int(hypot(p.x - prev.x, p.y - prev.y) / 6))
            for k in 0...steps {
                let frac = CGFloat(k) / CGFloat(steps)
                wipe(CGPoint(x: prev.x + (p.x - prev.x) * frac, y: prev.y + (p.y - prev.y) * frac))
            }
        case .swish, .girl, .none, .pop:
            if hand == .girl && !SGeo.inHead(SGeo.toDoll(p), pad: 28) && inTub(p) { hand = .swish }
            if hand == .none && inTub(p) && hasWater && p.y > surfaceY(p.x) - 24 { hand = .swish }
            if hand == .swish { swish(p, v: handV, dt: dt) }
        }
    }

    private func swish(_ p: CGPoint, v: CGVector, dt: CGFloat) {
        guard hasWater, inTub(p) else { return }
        let surf = surfaceY(p.x)
        guard p.y > surf - 28 else { return }
        let speed = hypot(v.dx, v.dy)
        let c = SGeo.col(p.x)
        for i in things.indices where !things[i].held && !things[i].isBomb {
            let delta = abs(things[i].p.x - p.x)
            let near = max(0, 1 - delta / 155)
            if near > 0 && abs(things[i].p.y - surf) < 70 {
                things[i].v.dx += max(-1200, min(1200, v.dx)) * near * min(dt, 0.08) * 3
            }
        }
        let dir: Int = v.dx > 0 ? 1 : -1
        let push = max(-1, min(1, v.dx / 900))
        for k in -4...4 {
            let i = c + k
            guard i >= 0, i < SGeo.columns else { continue }
            let w = 1 - CGFloat(abs(k)) / 5
            hv[i] += (k * dir > 0 ? -1 : 1) * abs(push) * 90 * w
            hv[i] += v.dy * 0.04 * w
        }
        let move = min(0.6, abs(v.dx) * dt * 0.012)
        for k in -3...3 {
            let i = c + k, j = c + k + dir
            guard i >= 0, i < SGeo.columns, j >= 0, j < SGeo.columns else { continue }
            let m = foam[i] * move
            foam[i] -= m
            foam[j] += m
            foamTint[j] = foamTint[j].mix(foamTint[i], Double(min(1, m / max(0.01, foam[j]))))
        }
        let s = soapiness
        if s > 0.02 {
            let colTint = tintA[c] > 0.15 ? tint[c] : nil
            for k in -3...3 {
                addFoam(c + k, s * min(1.5, speed / 520) * dt * 1.25, tint: colTint)
            }
        }
        if p.y > surf + 8 && speed > 120 && CGFloat.random(in: 0...1) < min(1, speed * dt / 18) {
            air.append(SAir(
                p: CGPoint(x: p.x + CGFloat.random(in: -8...8), y: p.y + CGFloat.random(in: -4...6)),
                r: CGFloat.random(in: 1.5...4.5),
                phase: CGFloat.random(in: 0...6)
            ))
        }
        if speed > 680 && abs(p.y - surf) < 30 && CGFloat.random(in: 0...1) < min(1, speed * dt / 32) {
            drops.append(SDrop(
                p: CGPoint(x: p.x, y: surf - 4),
                v: CGVector(dx: v.dx * 0.45 + CGFloat.random(in: -50...50), dy: -CGFloat.random(in: 180...340)),
                r: CGFloat.random(in: 1.6...3.5)
            ))
        }
        if speed > 280 && time > swishSound {
            swishSound = time + 0.45
            play(.slosh, min(0.8, Float(speed) / 2000 + 0.2))
        }
    }

    private func wipe(_ p: CGPoint) {
        let m = SGeo.mirror
        let cw = m.width / CGFloat(SGeo.fogCols)
        let ch = m.height / CGFloat(SGeo.fogRows)
        for r in 0..<SGeo.fogRows {
            for c in 0..<SGeo.fogCols {
                let cx = m.minX + (CGFloat(c) + 0.5) * cw
                let cy = m.minY + (CGFloat(r) + 0.5) * ch
                let dist = hypot(cx - p.x, cy - p.y)
                if dist < 26 {
                    let idx = r * SGeo.fogCols + c
                    if dist < 17 {
                        fog[idx] = 0
                        fogCleared[idx] = true
                    } else {
                        fog[idx] *= 0.35
                        if fog[idx] < 0.15 { fogCleared[idx] = true }
                    }
                }
            }
        }
    }

    func clearMirrorFog(at p: CGPoint, radius: CGFloat = 52) {
        let m = SGeo.mirror
        guard m.insetBy(dx: -radius, dy: -radius).contains(p) else { return }
        let cw = m.width / CGFloat(SGeo.fogCols)
        let ch = m.height / CGFloat(SGeo.fogRows)
        var clearedAny = false
        for r in 0..<SGeo.fogRows {
            for c in 0..<SGeo.fogCols {
                let cx = m.minX + (CGFloat(c) + 0.5) * cw
                let cy = m.minY + (CGFloat(r) + 0.5) * ch
                if hypot(cx - p.x, cy - p.y) < radius {
                    let idx = r * SGeo.fogCols + c
                    if fog[idx] > 0.02 || fogCleared[idx] { clearedAny = true }
                    fog[idx] = 0
                    fogCleared[idx] = false
                }
            }
        }
        if clearedAny {
            mirrorFreshUntil = max(mirrorFreshUntil, time + 2.0)
        }
    }

    func handEnded(_ p: CGPoint, tap: Bool) {
        switch hand {
        case .thing(let id):
            if let i = thingIndex(id) {
                things[i].held = false
                var v = things[i].v
                let sp = hypot(v.dx, v.dy)
                if sp > 1500 { v = CGVector(dx: v.dx / sp * 1500, dy: v.dy / sp * 1500) }
                things[i].v = v
                if tap { tapThing(i) }
            }
        case .girl:
            if tap { giggle() }
        default:
            break
        }
        hand = .none
        handV = .zero
    }

    func tapThing(_ i: Int) {
        things[i].squashV -= 9
        guard case .toy(let k) = things[i].kind else { return }
        giggleUntil = max(giggleUntil, time + 0.9)
        switch k {
        case .duck:
            things[i].v.dy -= 240
            play(.squeak, 0.8)
        case .goldenDuck:
            things[i].v.dy -= 265
            let top = CGPoint(x: things[i].p.x, y: things[i].p.y - things[i].half.height)
            pops.append(SPop(p: top, r: 36, sparkle: true))
            spawnHearts(at: top, count: 3)
            for k in 0..<8 {
                let a = CGFloat(k) / 8 * 2 * .pi
                glitter.append(SGlitter(
                    p: CGPoint(x: top.x + cos(a) * 14, y: top.y + sin(a) * 10),
                    v: CGVector(dx: cos(a) * 36, dy: -26 + sin(a) * 16),
                    color: RGB(hex: "#FFE88A"),
                    phase: a
                ))
            }
            play(.squeak, 0.8)
            play(.chime, 0.65, gap: 0.15)
        case .boat:
            things[i].v.dx += things[i].facing * 165
            play(.toot, 0.75)
        case .whale:
            let top = CGPoint(x: things[i].p.x + things[i].facing * 6, y: things[i].p.y - things[i].half.height)
            for _ in 0..<40 {
                drops.append(SDrop(
                    p: top,
                    v: CGVector(dx: CGFloat.random(in: -95...95), dy: -CGFloat.random(in: 420...660)),
                    r: CGFloat.random(in: 1.9...3.8)
                ))
            }
            spawnHearts(at: CGPoint(x: top.x, y: top.y - 44), count: 3)
            discover(.whaleFountain, at: CGPoint(x: top.x, y: top.y - 36))
            fulfillWish(.whaleToy)
            play(.spout, 0.85)
        case .turtle:
            things[i].dive = 1.25
            for _ in 0..<8 {
                air.append(SAir(
                    p: CGPoint(x: things[i].p.x + CGFloat.random(in: -18...18), y: things[i].p.y),
                    r: CGFloat.random(in: 2...4.5),
                    phase: CGFloat.random(in: 0...6)
                ))
            }
            play(.plop, 0.75)
        }
    }

    // MARK: - Held dock tools

    func pickUp(_ t: SpaTool, finger: CGPoint, lifted: CGPoint) {
        tool = t
        toolFinger = finger
        toolP = finger
        toolTarget = lifted
        toolV = .zero
        toolAngle = 0
        rubbing = 0
        emitCarry = 0
        if t == .wand { wandFilm = 1 }
    }

    func carry(finger: CGPoint, lifted: CGPoint) {
        toolFinger = finger
        toolTarget = lifted
    }

    func release() {
        if tool == .cucumbers {
            let d = SGeo.toDoll(toolP)
            if SGeo.inHead(d, pad: 65) {
                putCucumbersOn()
            }
        } else if tool == .sheepTowel {
            let d = SGeo.toDoll(toolP)
            if SGeo.inHead(d, pad: 75) {
                putSheepTowelOn()
            }
        }
        tool = nil
    }

    private func stepTool(_ d: CGFloat) {
        guard let t = tool else { return }
        let old = toolP
        let k = min(1, d * 26)
        toolP = CGPoint(x: toolP.x + (toolTarget.x - toolP.x) * k, y: toolP.y + (toolTarget.y - toolP.y) * k)
        let v = CGVector(dx: (toolP.x - old.x) / d, dy: (toolP.y - old.y) / d)
        toolV = CGVector(dx: toolV.dx * 0.6 + v.dx * 0.4, dy: toolV.dy * 0.6 + v.dy * 0.4)
        let speed = hypot(toolV.dx, toolV.dy)
        let wet = underWater(toolP)
        rubbing = max(0, rubbing - d * 3)

        switch t {
        case .soap:
            let overTub = toolP.x > SGeo.tubL + 10 && toolP.x < SGeo.tubR - 10 && toolP.y < (hasWater ? level : SGeo.tubBottom) - 36
            let want: CGFloat = overTub ? 2.2 : 0.15 * max(-1, min(1, -toolV.dx / 600))
            toolAngle += (want - toolAngle) * min(1, d * 7)
            if toolAngle > 1.55 {
                emitCarry += d * 34
                while emitCarry >= 1 {
                    emitCarry -= 1
                    drops.append(SDrop(
                        p: soapNozzle,
                        v: CGVector(dx: CGFloat.random(in: -10...10) + toolV.dx * 0.2, dy: 65),
                        r: CGFloat.random(in: 3.2...4.8),
                        kind: .soap
                    ))
                }
                play(.glug, 0.5, gap: 0.6)
            }

        case .wand:
            // Always ready — never runs out waiting for a hidden water dip!
            wandFilm = 1
            if !wet && speed > 58 {
                emitCarry += speed * d / 56
                while emitCarry >= 1 {
                    emitCarry -= 1
                    wandBlowCount += 1
                    let isStar = wandBlowCount % 3 == 0
                    let r = isStar ? 35 : max(14, min(38, 3000 / max(85, speed) + CGFloat.random(in: -3...6))) * 1.15
                    let dir = CGVector(dx: toolV.dx / max(1, speed), dy: toolV.dy / max(1, speed))
                    spawnBubble(
                        at: CGPoint(x: toolP.x + dir.dx * (18 + r * 0.6), y: toolP.y + dir.dy * (18 + r * 0.6)),
                        v: CGVector(dx: toolV.dx * 0.28 + CGFloat.random(in: -22...22), dy: toolV.dy * 0.28 - 28),
                        r: r,
                        star: isStar
                    )
                    play(.blow, 0.45, gap: 0.16)
                }
            }

        case .sponge(let foamTint):
            if wet {
                spongeWet = min(1, spongeWet + d * 3)
                spongeFoam = 1
                if speed > 80 {
                    disturb(toolP.x, toolV.dy * 0.02, width: 16)
                    if soapiness > 0.02 { addFoam(SGeo.col(toolP.x), soapiness * d * 0.7, tint: foamTint.color) }
                }
            } else {
                let dd = SGeo.toDoll(toolP)
                if SGeo.inHead(dd, pad: 44) && speed > 36 {
                    rubbing = 1
                    emitCarry += speed * d / 44
                    while emitCarry >= 1 {
                        emitCarry -= 1
                        addFoamPuff(at: dd, tint: foamTint.color, radius: CGFloat.random(in: 24...34))
                        play(.squish, 0.42, gap: 0.18)
                    }
                } else if SGeo.onHer(dd, pad: 24) && speed > 45 {
                    rubbing = 1
                    if CGFloat.random(in: 0...1) < speed * d / 16 {
                        addSud(CGPoint(x: dd.x + CGFloat.random(in: -24...24), y: dd.y + CGFloat.random(in: -16...16)), r: CGFloat.random(in: 10...18))
                    }
                }
            }

        case .shower:
            emitCarry += d * 165
            while emitCarry >= 1 {
                emitCarry -= 1
                let a = CGFloat.random(in: -0.35...0.35) + 0.1
                let sp = CGFloat.random(in: 400...540)
                let o = CGFloat.random(in: -18...18) * FingerLift.spread
                drops.append(SDrop(
                    p: CGPoint(x: toolP.x + o, y: toolP.y + 16),
                    v: CGVector(dx: sin(a) * sp, dy: cos(a) * sp),
                    r: CGFloat.random(in: 1.4...2.5),
                    kind: .spray
                ))
            }
            let below = CGPoint(x: toolP.x, y: toolP.y + 62)
            let dd = SGeo.toDoll(below)
            if SGeo.onHer(dd, pad: 44) {
                rinse(at: dd, amount: d * 3.2)
                wipeMask(at: dd, radius: 64 * FingerLift.spread, amount: d * 1.8)
            }
            if SGeo.mirror.insetBy(dx: -36, dy: -36).contains(below) {
                clearMirrorFog(at: below, radius: 54 * FingerLift.spread)
            }
            for i in things.indices where !things[i].held && abs(things[i].p.x - toolP.x) < 52 * FingerLift.spread && things[i].p.y > toolP.y {
                things[i].v.dy += 240 * d
                things[i].v.dx += (things[i].p.x - toolP.x) * 3 * d
            }

        case .towel:
            if SGeo.mirror.insetBy(dx: -34, dy: -34).contains(toolP) {
                clearMirrorFog(at: toolP, radius: 56 * FingerLift.spread)
                if speed > 36 { rubbing = 0.6 }
            }
            let dd = SGeo.toDoll(toolP)
            if SGeo.onHer(dd, pad: 34) && speed > 36 {
                rubbing = 0.8
                let k = FingerLift.spread
                beads.removeAll { hypot($0.d.x - dd.x, $0.d.y - dd.y) < 76 * k }
                // Towel gently pats her dry & wraps cozy warmth — NEVER erases her face mask!
                if !cozyActive || cozyUntil - time < 3.6 {
                    cozyUntil = time + 4.5
                    spawnHearts(at: SGeo.fromDoll(CGPoint(x: 300, y: 260)), count: 2)
                    discover(.cozyWrap, at: SGeo.fromDoll(CGPoint(x: 300, y: 400)))
                    fulfillWish(.cozyTowel)
                }
            }

        case .mask(let mk):
            let dd = SGeo.toDoll(toolP)
            if SGeo.inHead(dd, pad: -4) {
                paintMask(at: dd, kind: mk, amount: min(1, d * 4.5 + speed * d * 0.007))
                if speed > 35 {
                    rubbing = 0.7
                    play(.squish, 0.38, gap: 0.32)
                }
            }

        case .cucumbers, .sheepTowel:
            break

        case .mist:
            emitCarry += max(3.5, speed * 0.015) * d
            while emitCarry >= 1 {
                emitCarry -= 1
                let pt = CGPoint(x: toolP.x + CGFloat.random(in: -36...36), y: toolP.y + CGFloat.random(in: -28...28))
                spritzMist(at: pt)
            }
        }
    }

    var soapNozzle: CGPoint {
        CGPoint(x: toolP.x + sin(toolAngle) * 58, y: toolP.y - cos(toolAngle) * 58)
    }

    // MARK: - Sound

    private func play(_ s: SpaSFX, _ v: Float, gap: Double = 0) {
        guard !quiet else { return }
        SpaSound.shared.play(s, volume: v, gap: gap)
    }

    private func sounds() {
        guard !quiet else { return }
        let s = SpaSound.shared
        s.setLoop(.running, volume: Float(flow) * 0.7)
        s.setLoop(.drain, volume: Float(drainFlow) * (vol > 0.5 ? 0.55 : 0))
        let fizzing = hasEnoughWaterForBomb
            ? things.reduce(CGFloat(0)) { $0 + ($1.isBomb && $1.wetFor > 0.3 ? 0.5 + $1.fizz * 0.5 : 0) }
            : 0
        s.setLoop(.fizz, volume: Float(min(1, fizzing)) * 0.55)
        let showering = tool == .shower || quickShowerUntil > time
        s.setLoop(.shower, volume: showering ? 0.55 : 0)
        s.setLoop(.scrub, volume: Float(rubbing) * 0.5)
    }
}
