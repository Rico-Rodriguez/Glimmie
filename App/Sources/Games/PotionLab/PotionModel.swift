import SwiftUI

// MARK: - Layout & Cauldron Geometry (1024 x 834 design frame)

enum PotionGeometry {
    static let stageWidth: CGFloat = GameChromeLayout.width
    static let stageHeight: CGFloat = GameChromeLayout.height

    /// Wide-mouth glowing magic cauldron centered on stage.
    static let cauldronCenter = CGPoint(x: 540, y: 432)
    static let cauldronRadius: CGFloat = 138
    static let neckHalfWidth: CGFloat = 88
    static let rimY: CGFloat = 250
    static let glassThickness: CGFloat = 8
    static var joinY: CGFloat { cauldronCenter.y - sqrt(cauldronRadius * cauldronRadius - neckHalfWidth * neckHalfWidth) }
    static var bottomY: CGFloat { cauldronCenter.y + cauldronRadius }
    static var pourTarget: CGPoint { CGPoint(x: cauldronCenter.x, y: rimY - 46) }

    /// Left dedicated magical friend nook (open sky/window above, zero shelves).
    static let cushionCenter = CGPoint(x: 185, y: 572)
    static let creatureFeet = CGPoint(x: 185, y: 567)
    static let creatureScale: CGFloat = 0.34
    static let creatureDropZone = CGRect(x: 18, y: 118, width: 328, height: 484)
    static let creatureSwitcherCenter = CGPoint(x: 185, y: 638)
    static let waterResetCenter = CGPoint(x: 332, y: 570)

    /// Workbench countertop & controls (kept <= 650 so lifted bottom dock at y = 740 has clean separation).
    static let tableY: CGFloat = 620
    static let burnerCenter = CGPoint(x: 540, y: 604)
    static let dialCenter = CGPoint(x: 398, y: 610)
    static let dialRadius: CGFloat = 28
    static let valveCenter = CGPoint(x: 668, y: 570)
    static let basinRect = CGRect(x: 694, y: 590, width: 48, height: 32)
    static var drainMouth: CGPoint { CGPoint(x: 718, y: 576) }
    static let bottleFillCenter = CGPoint(x: 704, y: 300)

    /// Cozy 2-tier 5-slot Tasting Stand on the right stage.
    static let standCapacity = 5
    static let standBottleScale: CGFloat = 0.72
    static let standSlots: [CGPoint] = [
        CGPoint(x: 824, y: 404),
        CGPoint(x: 924, y: 404),
        CGPoint(x: 794, y: 536),
        CGPoint(x: 874, y: 536),
        CGPoint(x: 954, y: 536),
    ]
    static let standShelfTopY: CGFloat = 446
    static let standShelfBottomY: CGFloat = 578

    /// Unified bottom ingredient dock.
    static let dockY: CGFloat = GameChromeLayout.dockY
    static func dockSlotCenter(_ index: Int) -> CGPoint {
        let count = CGFloat(PIngredient.allCases.count)
        let pitch: CGFloat = 94
        let startX = stageWidth / 2 - (count - 1) * pitch / 2
        return CGPoint(x: startX + CGFloat(index) * pitch, y: dockY)
    }

    // 2D fluid grid covering the cauldron: 40 x 44 cells of 8 pt.
    static let gx0: CGFloat = 380
    static let gy0: CGFloat = 236
    static let cell: CGFloat = 8
    static let NX = 40
    static let NY = 44

    static func cellCenter(_ i: Int, _ j: Int) -> CGPoint {
        CGPoint(x: gx0 + (CGFloat(i) + 0.5) * cell, y: gy0 + (CGFloat(j) + 0.5) * cell)
    }

    static func inside(_ p: CGPoint, pad: CGFloat = 0) -> Bool {
        let dx = p.x - cauldronCenter.x
        let dy = p.y - cauldronCenter.y
        if dx * dx + dy * dy < (cauldronRadius - pad) * (cauldronRadius - pad) { return true }
        return abs(dx) < neckHalfWidth - pad && p.y >= rimY + pad && p.y <= cauldronCenter.y
    }

    static func insideCauldronTouch(_ p: CGPoint) -> Bool {
        let dx = p.x - cauldronCenter.x
        let dy = p.y - cauldronCenter.y
        if dx * dx + dy * dy < (cauldronRadius + 20) * (cauldronRadius + 20) { return true }
        return abs(dx) < neckHalfWidth + 32 && p.y >= rimY - 70 && p.y <= cauldronCenter.y
    }

    static func dialHit(_ p: CGPoint) -> Bool {
        hypot(p.x - dialCenter.x, p.y - dialCenter.y) <= dialRadius + 16
    }

    static func valveHit(_ p: CGPoint) -> Bool {
        hypot(p.x - valveCenter.x, p.y - (valveCenter.y - 12)) <= 46
    }

    static func standSlotHit(_ p: CGPoint) -> Int? {
        for (i, spot) in standSlots.enumerated() {
            if CGRect(x: spot.x - 38, y: spot.y - 54, width: 76, height: 102).contains(p) {
                return i
            }
        }
        return nil
    }

    static func halfWidth(at y: CGFloat) -> CGFloat {
        if y < rimY || y > bottomY { return 0 }
        let dy = y - cauldronCenter.y
        var w: CGFloat = 0
        if abs(dy) < cauldronRadius {
            w = sqrt(cauldronRadius * cauldronRadius - dy * dy)
        }
        if y <= cauldronCenter.y { w = max(w, neckHalfWidth) }
        return w
    }

    static let areaBelow: [CGFloat] = {
        let top = Int(rimY)
        let bottom = Int(bottomY) + 1
        var a = [CGFloat](repeating: 0, count: bottom - top + 2)
        var sum: CGFloat = 0
        var y = bottom
        while y >= top {
            sum += 2 * halfWidth(at: CGFloat(y) + 0.5)
            a[y - top] = sum
            y -= 1
        }
        return a
    }()

    static var capacity: CGFloat { areaBelow[0] }
    static var baseVolume: CGFloat { capacity * 0.46 }

    static func volume(below y: CGFloat) -> CGFloat {
        let f = max(0, min(CGFloat(areaBelow.count - 1), y - rimY))
        let i = Int(f)
        let k = f - CGFloat(i)
        let a = areaBelow[i]
        let b = areaBelow[min(areaBelow.count - 1, i + 1)]
        return a + (b - a) * k
    }

    static func level(for v: CGFloat) -> CGFloat {
        if v <= 0 { return bottomY }
        if v >= capacity { return rimY }
        var lo = rimY
        var hi = bottomY
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if volume(below: mid) > v { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    static func outline(out d: CGFloat = 0) -> [CGPoint] {
        let r = cauldronRadius + d
        let h = neckHalfWidth + d
        let jy = cauldronCenter.y - sqrt(r * r - h * h)
        var a0 = atan2(Double(jy - cauldronCenter.y), Double(-h))
        var a1 = atan2(Double(jy - cauldronCenter.y), Double(h))
        if a0 < 0 { a0 += 2 * .pi }
        if a1 < 0 { a1 += 2 * .pi }
        let end = a1 - 2 * .pi
        var pts: [CGPoint] = [
            CGPoint(x: cauldronCenter.x - h, y: rimY - (d > 0 ? 4 : 0)),
            CGPoint(x: cauldronCenter.x - h, y: jy),
        ]
        let n = 84
        for k in 1..<n {
            let a = a0 + (end - a0) * Double(k) / Double(n)
            pts.append(CGPoint(x: cauldronCenter.x + r * CGFloat(cos(a)), y: cauldronCenter.y + r * CGFloat(sin(a))))
        }
        pts.append(CGPoint(x: cauldronCenter.x + h, y: jy))
        pts.append(CGPoint(x: cauldronCenter.x + h, y: rimY - (d > 0 ? 4 : 0)))
        return pts
    }

    static func path(_ pts: [CGPoint], closed: Bool = true) -> Path {
        var p = Path()
        p.addLines(pts)
        if closed { p.closeSubpath() }
        return p
    }

    static let interior: Path = path(outline())
    static let exterior: Path = path(outline(out: glassThickness))
}

// MARK: - Switchable Magical Friends

enum LabCreature: String, CaseIterable, Codable, Identifiable {
    case unicorn
    case dragon
    case kitty
    case frog

    var id: String { rawValue }
    var petLook: PetLook { PetLook(kind: rawValue) }

    var tintHex: UInt32 {
        switch self {
        case .unicorn: return 0xFFB4DC
        case .dragon: return 0xA8E8C8
        case .kitty: return 0xFFD2A6
        case .frog: return 0xB8EC98
        }
    }

    var badgeTint: Color { Color(hex: tintHex) }
}

// MARK: - 3-Step Burner Dial

enum BurnerLevel: Int, CaseIterable, Codable {
    case off = 0
    case simmer = 1
    case boil = 2

    var next: BurnerLevel {
        switch self {
        case .off: return .simmer
        case .simmer: return .boil
        case .boil: return .off
        }
    }

    var targetTemp: CGFloat {
        switch self {
        case .off: return 0.22
        case .simmer: return 0.56
        case .boil: return 0.98
        }
    }

    static func clamped(_ raw: Int) -> BurnerLevel {
        if raw <= 0 { return .off }
        if raw == 1 { return .simmer }
        return .boil
    }
}

// MARK: - Magic Traits & 8 Iconic Ingredients

enum PMagic: String, CaseIterable, Codable {
    case love, bubble, fire, glow, sparkle, frost, rainbow, sleepy
}

enum PIngredient: String, CaseIterable, Codable, Identifiable {
    case fairyRose
    case mermaidWave
    case starGlitter
    case rainbowMane
    case frostFlake
    case bubbleBerry
    case dragonChili
    case sleepyLavender

    var id: String { rawValue }

    var isLiquid: Bool {
        switch self {
        case .fairyRose, .mermaidWave, .dragonChili: return true
        default: return false
        }
    }

    var hex: UInt32 {
        switch self {
        case .fairyRose: return 0xFF62AE
        case .mermaidWave: return 0x26D8CC
        case .starGlitter: return 0xFFD44A
        case .rainbowMane: return 0xFF88D6
        case .frostFlake: return 0x7FE4FF
        case .bubbleBerry: return 0x9F6EFF
        case .dragonChili: return 0xFF6B3D
        case .sleepyLavender: return 0xB48EFF
        }
    }

    var color: RGB {
        RGB(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    var tileTint: Color {
        StorybookArt.tint(for: hex, amount: 0.78)
    }

    var magic: PMagic {
        switch self {
        case .fairyRose: return .love
        case .mermaidWave: return .bubble
        case .starGlitter: return .sparkle
        case .rainbowMane: return .rainbow
        case .frostFlake: return .frost
        case .bubbleBerry: return .bubble
        case .dragonChili: return .fire
        case .sleepyLavender: return .sleepy
        }
    }

    var vesselShape: PBottleShape {
        switch self {
        case .fairyRose: return .heart
        case .mermaidWave: return .drop
        case .starGlitter: return .star
        case .rainbowMane: return .round
        case .frostFlake: return .tall
        case .bubbleBerry: return .round
        case .dragonChili: return .diamond
        case .sleepyLavender: return .drop
        }
    }

    var dockIndex: Int {
        PIngredient.allCases.firstIndex(of: self) ?? 0
    }

    /// Maps legacy `potionlab.json` dose keys onto the 8 streamlined ingredients.
    static func fromLegacyKey(_ key: String) -> PIngredient? {
        if let direct = PIngredient(rawValue: key) { return direct }
        switch key {
        case "nectar", "petals": return .fairyRose
        case "mermaid": return .mermaidWave
        case "stars", "night": return .starGlitter
        case "hair": return .rainbowMane
        case "frost": return .frostFlake
        case "berries": return .bubbleBerry
        case "dragon": return .dragonChili
        case "lavender", "moon": return .sleepyLavender
        default: return nil
        }
    }
}

// MARK: - Creature Transformations

enum TransformationEffect: String, CaseIterable, Codable, Equatable {
    case bubbleFloat
    case rainbow
    case dragonFire
    case frostCrown
    case sleepyCloud
    case love
    case galaxy
    case moonlight
    case golden
    case mermaid
    case wild

    var isFloating: Bool {
        self == .bubbleFloat || self == .mermaid
    }

    func unlocksStickerID(for creature: LabCreature) -> String? {
        guard creature == .unicorn else { return nil }
        switch self {
        case .bubbleFloat, .mermaid: return "floatingUnicorn"
        case .rainbow, .wild: return "rainbowUnicorn"
        default: return nil
        }
    }
}

// MARK: - 10 Secret Rare Potions & Integer Recipes

struct PotionRecipe: Equatable {
    let ingredients: [PIngredient]
    let requiresBoil: Bool
    let requiresMoonlit: Bool
    let distinctMinimum: Int?

    init(
        _ ingredients: [PIngredient],
        boil: Bool = false,
        moonlit: Bool = false,
        distinctMinimum: Int? = nil
    ) {
        self.ingredients = ingredients
        self.requiresBoil = boil
        self.requiresMoonlit = moonlit
        self.distinctMinimum = distinctMinimum
    }
}

enum PotionKind: String, CaseIterable, Codable, Identifiable {
    case love, mermaid, frost, moonlight, dream, dragon, galaxy, golden, rainbow, wild

    var id: String { rawValue }

    var recipe: PotionRecipe {
        switch self {
        case .love: return PotionRecipe([.fairyRose, .starGlitter])
        case .mermaid: return PotionRecipe([.mermaidWave, .bubbleBerry])
        case .frost: return PotionRecipe([.frostFlake, .mermaidWave])
        case .moonlight: return PotionRecipe([.sleepyLavender, .starGlitter], moonlit: true)
        case .dream: return PotionRecipe([.sleepyLavender, .bubbleBerry])
        case .dragon: return PotionRecipe([.dragonChili, .starGlitter], boil: true)
        case .galaxy: return PotionRecipe([.starGlitter, .sleepyLavender, .mermaidWave])
        case .golden: return PotionRecipe([.starGlitter, .fairyRose, .dragonChili])
        case .rainbow: return PotionRecipe([.rainbowMane, .fairyRose, .mermaidWave])
        case .wild: return PotionRecipe([.frostFlake, .dragonChili, .rainbowMane, .sleepyLavender], distinctMinimum: 4)
        }
    }

    /// Evaluates exact integer scoop counts, heat, and moonlit state in deterministic specificity order.
    static func match(
        ingredients: [PIngredient: Int],
        heat: BurnerLevel,
        moonlit: Bool
    ) -> PotionKind? {
        let present = Set(ingredients.compactMap { $0.value > 0 ? $0.key : nil })
        if present.isSuperset(of: [.rainbowMane, .fairyRose, .mermaidWave]) { return .rainbow }
        if present.isSuperset(of: [.starGlitter, .fairyRose, .dragonChili]) { return .golden }
        if present.isSuperset(of: [.starGlitter, .sleepyLavender, .mermaidWave]) { return .galaxy }
        if present.isSuperset(of: [.dragonChili, .starGlitter]), heat == .boil { return .dragon }
        if present.isSuperset(of: [.sleepyLavender, .starGlitter]), moonlit { return .moonlight }
        if present.isSuperset(of: [.fairyRose, .starGlitter]) { return .love }
        if present.isSuperset(of: [.mermaidWave, .bubbleBerry]) { return .mermaid }
        if present.isSuperset(of: [.frostFlake, .mermaidWave]) { return .frost }
        if present.isSuperset(of: [.sleepyLavender, .bubbleBerry]) { return .dream }
        if present.count >= 4 { return .wild }
        return nil
    }

    var color: RGB {
        switch self {
        case .love: return RGB(hex: "#FF529E")
        case .mermaid: return RGB(hex: "#1CD4C4")
        case .frost: return RGB(hex: "#8CE6FF")
        case .moonlight: return RGB(hex: "#DFD6FF")
        case .dream: return RGB(hex: "#A882FF")
        case .dragon: return RGB(hex: "#FF5A24")
        case .galaxy: return RGB(hex: "#5835C8")
        case .golden: return RGB(hex: "#FFC736")
        case .rainbow: return RGB(hex: "#FF8CD4")
        case .wild: return RGB(hex: "#6EE278")
        }
    }

    var glow: CGFloat {
        switch self {
        case .moonlight: return 1.0
        case .dragon, .golden: return 0.82
        case .galaxy, .rainbow, .wild: return 0.62
        default: return 0.42
        }
    }

    var sparkle: CGFloat {
        switch self {
        case .galaxy, .golden: return 1.0
        case .rainbow, .wild, .moonlight: return 0.8
        default: return 0.45
        }
    }

    var shape: PBottleShape {
        switch self {
        case .love: return .heart
        case .mermaid: return .drop
        case .frost: return .tall
        case .moonlight: return .round
        case .dream: return .drop
        case .dragon: return .square
        case .galaxy: return .star
        case .golden: return .diamond
        case .rainbow: return .star
        case .wild: return .square
        }
    }

    var magic: PMagic {
        switch self {
        case .love: return .love
        case .mermaid: return .bubble
        case .frost: return .frost
        case .moonlight: return .glow
        case .dream: return .sleepy
        case .dragon: return .fire
        case .galaxy: return .sparkle
        case .golden: return .glow
        case .rainbow: return .rainbow
        case .wild: return .rainbow
        }
    }

    var effect: TransformationEffect {
        switch self {
        case .love: return .love
        case .mermaid: return .mermaid
        case .frost: return .frostCrown
        case .moonlight: return .moonlight
        case .dream: return .sleepyCloud
        case .dragon: return .dragonFire
        case .galaxy: return .galaxy
        case .golden: return .golden
        case .rainbow: return .rainbow
        case .wild: return .wild
        }
    }
}

// MARK: - Specialty Bottle Shapes & Polygon Level Math

enum PBottleShape: Int, CaseIterable, Codable {
    case round, tall, heart, star, drop, square, diamond

    static let mouthY: CGFloat = -62
    static let bottomY: CGFloat = 58

    var outline: [CGPoint] { PBottleShape.cache[rawValue] }
    private static let cache: [[CGPoint]] = PBottleShape.allCases.map { $0.make() }

    var neck: CGFloat {
        switch self {
        case .square, .tall: return 12
        default: return 10
        }
    }

    private func make() -> [CGPoint] {
        let n = neck
        var body: [CGPoint] = []
        switch self {
        case .round:
            let c = CGPoint(x: 0, y: 16)
            let r: CGFloat = 42
            let a0 = asin(Double(n / r))
            for k in 0...40 {
                let a = -Double.pi / 2 + a0 + (2 * Double.pi - 2 * a0) * Double(k) / 40
                body.append(CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a))))
            }
        case .tall:
            body = [
                CGPoint(x: n, y: -34), CGPoint(x: 26, y: -24), CGPoint(x: 28, y: 46),
                CGPoint(x: 22, y: 56), CGPoint(x: 0, y: 58), CGPoint(x: -22, y: 56),
                CGPoint(x: -28, y: 46), CGPoint(x: -26, y: -24), CGPoint(x: -n, y: -34),
            ]
        case .heart:
            for k in 0...48 {
                let t = Double(k) / 48 * 2 * Double.pi
                let x = 16 * pow(sin(t), 3)
                let y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
                body.append(CGPoint(x: CGFloat(x) * 2.9, y: CGFloat(y) * 2.9 + 20))
            }
            body = body.filter { !($0.y < 14 && abs($0.x) < n + 2) }
        case .star:
            for k in 0..<10 {
                let a = -Double.pi / 2 + Double(k) * Double.pi / 5
                let r: CGFloat = k % 2 == 0 ? 50 : 28
                body.append(CGPoint(x: r * CGFloat(cos(a)), y: 14 + r * CGFloat(sin(a))))
            }
            var soft: [CGPoint] = []
            for k in 0..<body.count {
                let a = body[k]
                let b = body[(k + 1) % body.count]
                soft.append(CGPoint(x: a.x + (b.x - a.x) * 0.12, y: a.y + (b.y - a.y) * 0.12))
                soft.append(CGPoint(x: a.x + (b.x - a.x) * 0.88, y: a.y + (b.y - a.y) * 0.88))
            }
            body = soft.filter { $0.y > -30 || abs($0.x) > n }
        case .drop:
            for k in 0...40 {
                let t = Double(k) / 40 * 2 * Double.pi
                let x = 40 * sin(t) * (0.55 + 0.45 * (1 - cos(t)) / 2)
                let y = -44 * cos(t)
                body.append(CGPoint(x: CGFloat(x), y: CGFloat(y) + 14))
            }
            body = body.filter { !($0.y < -24 && abs($0.x) < n) }
        case .square:
            body = [
                CGPoint(x: n, y: -36), CGPoint(x: 30, y: -30), CGPoint(x: 36, y: -22),
                CGPoint(x: 36, y: 50), CGPoint(x: 30, y: 58), CGPoint(x: -30, y: 58),
                CGPoint(x: -36, y: 50), CGPoint(x: -36, y: -22), CGPoint(x: -30, y: -30),
                CGPoint(x: -n, y: -36),
            ]
        case .diamond:
            body = [
                CGPoint(x: n, y: -30), CGPoint(x: 40, y: 6), CGPoint(x: 0, y: 58),
                CGPoint(x: -40, y: 6), CGPoint(x: -n, y: -30),
            ]
        }
        guard let first = body.first, let last = body.last else { return [] }
        var pts = [CGPoint(x: n, y: PBottleShape.mouthY)]
        pts.append(CGPoint(x: n, y: min(first.y, -20)))
        pts.append(contentsOf: body)
        pts.append(CGPoint(x: -n, y: min(last.y, -20)))
        pts.append(CGPoint(x: -n, y: PBottleShape.mouthY))
        return pts
    }

    var area: CGFloat { PPoly.area(outline) }
}

enum PPoly {
    static func area(_ p: [CGPoint]) -> CGFloat {
        guard p.count > 2 else { return 0 }
        var a: CGFloat = 0
        for i in 0..<p.count {
            let q = p[i]
            let r = p[(i + 1) % p.count]
            a += q.x * r.y - r.x * q.y
        }
        return abs(a) / 2
    }

    static func below(_ p: [CGPoint], _ y: CGFloat) -> [CGPoint] {
        guard p.count > 2 else { return [] }
        var out: [CGPoint] = []
        for i in 0..<p.count {
            let a = p[i]
            let b = p[(i + 1) % p.count]
            let ina = a.y >= y
            let inb = b.y >= y
            if ina { out.append(a) }
            if ina != inb {
                let t = (y - a.y) / (b.y - a.y)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: y))
            }
        }
        return out
    }

    static func level(_ p: [CGPoint], fill: CGFloat) -> CGFloat {
        let total = area(p)
        guard total > 0, let lo0 = p.map(\.y).min(), let hi0 = p.map(\.y).max() else { return 0 }
        if fill <= 0 { return hi0 }
        if fill >= 1 { return lo0 }
        var lo = lo0
        var hi = hi0
        let want = total * fill
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            if area(below(p, mid)) > want { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    static func transform(_ p: [CGPoint], at c: CGPoint, angle: CGFloat, scale: CGFloat) -> [CGPoint] {
        let ca = cos(angle)
        let sa = sin(angle)
        return p.map { q in
            CGPoint(x: c.x + (q.x * ca - q.y * sa) * scale, y: c.y + (q.x * sa + q.y * ca) * scale)
        }
    }
}

// MARK: - Bottled Potions & Backward-Compatible Save

struct PotionBottle: Codable, Equatable, Identifiable {
    var id: Int
    var r: Double
    var g: Double
    var b: Double
    var fill: Double
    var shape: Int
    var kind: String?
    var magic: [String: Double]
    var glow: Double
    var sparkle: Double

    var color: RGB { RGB(r, g, b) }
    var potion: PotionKind? { kind.flatMap(PotionKind.init(rawValue:)) }
    var bottleShape: PBottleShape { PBottleShape(rawValue: shape) ?? .round }

    var mainMagic: PMagic? {
        if let k = potion { return k.magic }
        guard let best = magic.max(by: { $0.value < $1.value }), best.value > 0.1 else { return nil }
        return PMagic(rawValue: best.key)
    }

    var effect: TransformationEffect {
        if let k = potion { return k.effect }
        switch mainMagic {
        case .love?: return .love
        case .bubble?: return .bubbleFloat
        case .fire?: return .dragonFire
        case .frost?: return .frostCrown
        case .rainbow?: return .rainbow
        case .sleepy?: return .sleepyCloud
        case .sparkle?: return .galaxy
        case .glow?: return .golden
        case nil: return .bubbleFloat
        }
    }
}

struct PotionSave: Codable {
    var bottles: [PotionBottle] = []
    var nextID: Int = 1
    var volume: Double = 0
    var pr: Double = 0
    var pg: Double = 0
    var pb: Double = 0
    var pa: Double = 0
    var doses: [String: Double] = [:]
    var lightsOn: Bool = true
    var heat: Int = 0
    var made: Int = 0
    var ingredients: [String: Int] = [:]
    var creature: String = LabCreature.unicorn.rawValue
    var moonlit: Bool? = nil

    init(
        bottles: [PotionBottle] = [],
        nextID: Int = 1,
        volume: Double = 0,
        pr: Double = 0,
        pg: Double = 0,
        pb: Double = 0,
        pa: Double = 0,
        doses: [String: Double] = [:],
        lightsOn: Bool = true,
        heat: Int = 0,
        made: Int = 0,
        ingredients: [String: Int] = [:],
        creature: String = LabCreature.unicorn.rawValue,
        moonlit: Bool? = nil
    ) {
        self.bottles = bottles
        self.nextID = nextID
        self.volume = volume
        self.pr = pr
        self.pg = pg
        self.pb = pb
        self.pa = pa
        self.doses = doses
        self.lightsOn = lightsOn
        self.heat = heat
        self.made = made
        self.ingredients = ingredients
        self.creature = creature
        self.moonlit = moonlit
    }

    enum CodingKeys: String, CodingKey {
        case bottles, nextID, volume, pr, pg, pb, pa, doses, lightsOn, heat, made
        case ingredients, creature, moonlit
    }

    /// Decodes both redesigned saves and legacy `potionlab.json` saves cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bottles = (try? c.decodeIfPresent([PotionBottle].self, forKey: .bottles)) ?? []
        nextID = (try? c.decodeIfPresent(Int.self, forKey: .nextID)) ?? 1
        volume = (try? c.decodeIfPresent(Double.self, forKey: .volume)) ?? 0
        pr = (try? c.decodeIfPresent(Double.self, forKey: .pr)) ?? 0
        pg = (try? c.decodeIfPresent(Double.self, forKey: .pg)) ?? 0
        pb = (try? c.decodeIfPresent(Double.self, forKey: .pb)) ?? 0
        pa = (try? c.decodeIfPresent(Double.self, forKey: .pa)) ?? 0
        doses = (try? c.decodeIfPresent([String: Double].self, forKey: .doses)) ?? [:]
        lightsOn = (try? c.decodeIfPresent(Bool.self, forKey: .lightsOn)) ?? true
        heat = (try? c.decodeIfPresent(Int.self, forKey: .heat)) ?? 0
        made = (try? c.decodeIfPresent(Int.self, forKey: .made)) ?? 0
        ingredients = (try? c.decodeIfPresent([String: Int].self, forKey: .ingredients)) ?? [:]
        creature = (try? c.decodeIfPresent(String.self, forKey: .creature)) ?? LabCreature.unicorn.rawValue
        moonlit = try? c.decodeIfPresent(Bool.self, forKey: .moonlit)
    }
}

// MARK: - Luminous Color Helpers

enum PotionColor {
    static let clearWater = RGB(0.84, 0.95, 1.0)

    static func hue(_ h: CGFloat) -> RGB {
        let wrapped = h - floor(h)
        let x = Double(wrapped) * 6
        let i = Int(x) % 6
        let f = x - Double(Int(x))
        let q = 1 - f
        let base: RGB
        switch i {
        case 0: base = RGB(1, f, 0)
        case 1: base = RGB(q, 1, 0)
        case 2: base = RGB(0, 1, f)
        case 3: base = RGB(0, q, 1)
        case 4: base = RGB(f, 0, 1)
        default: base = RGB(1, 0, q)
        }
        return base.mix(RGB(1, 1, 1), 0.24)
    }

    /// Prevents multi-ingredient RGB blends from collapsing into muddy grey/brown by enforcing a luminous pastel/jewel floor.
    static func luminous(_ rgb: RGB) -> RGB {
        let r = max(0, min(1, rgb.r))
        let g = max(0, min(1, rgb.g))
        let b = max(0, min(1, rgb.b))
        let hi = max(r, max(g, b))
        let lo = min(r, min(g, b))
        let delta = hi - lo

        var h: Double = 0.82 // fallback pastel lilac-pink if completely achromatic
        if delta > 0.005 {
            if hi == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) / 6
            } else if hi == g {
                h = ((b - r) / delta + 2) / 6
            } else {
                h = ((r - g) / delta + 4) / 6
            }
            if h < 0 { h += 1 }
        }
        let rawSat = hi > 0.001 ? delta / hi : 0
        // Steer muddy olive/brown hues gently toward lively coral or berry-lilac.
        if rawSat < 0.25 { h = 0.84 }
        let sat = max(0.56, min(0.88, rawSat * 1.18 + 0.16))
        let val = max(0.76, min(1.0, hi * 0.9 + 0.22))
        return fromHSV(h: h, s: sat, v: val)
    }

    private static func fromHSV(h: Double, s: Double, v: Double) -> RGB {
        let x = (h - floor(h)) * 6
        let i = Int(x) % 6
        let f = x - Double(Int(x))
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        switch i {
        case 0: return RGB(v, t, p)
        case 1: return RGB(q, v, p)
        case 2: return RGB(p, v, t)
        case 3: return RGB(p, q, v)
        case 4: return RGB(t, p, v)
        default: return RGB(v, p, q)
        }
    }
}
