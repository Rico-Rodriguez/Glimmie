import SwiftUI

// MARK: - Potion Lab: the lab's layout, the ingredients, the rare potions and the saves
//
// Everything is laid out in the 1024 x 834 design frame (wider screens just show more of the room at the sides).
// The big glass flask stands in the middle on a brass tripod over a little burner. Liquids stand on the shelves
// on the left, jars of things to shake in on the right, a crate of empty bottles at the right of the table and the
// bottled potions on the rack along the front. The unicorn sits on the table at the left.

enum PotionGeometry {
    /// The flask's round body (inside of the glass).
    static let C = CGPoint(x: 512, y: 452)
    static let R: CGFloat = 186
    /// Half the inside width of the neck, and where its rim is.
    static let hw: CGFloat = 92
    static let rimY: CGFloat = 178
    /// How thick the glass is.
    static let glass: CGFloat = 8
    static var joinY: CGFloat { C.y - sqrt(R * R - hw * hw) }
    static var bottomY: CGFloat { C.y + R }

    static let tableY: CGFloat = 700
    static let rackY: CGFloat = 822
    static let unicornFeet = CGPoint(x: 182, y: 704)
    static let unicornScale: CGFloat = 0.37
    /// Where the unicorn takes a potion (a pour landing in here reaches her).
    static var unicornBox: CGRect { CGRect(x: 86, y: 470, width: 196, height: 232) }

    /// The burner's heat knob.
    static let knob = CGPoint(x: 458, y: 684)
    static let knobRadius: CGFloat = 30
    /// The drain valve at the bottom right of the flask, its pipe and the bucket it empties into.
    static let valve = CGPoint(x: 606, y: 652)
    static let bucket = CGRect(x: 684, y: 652, width: 82, height: 48)
    static var drainMouth: CGPoint { CGPoint(x: 724, y: 652) }
    /// The crate of empty bottles.
    static let crate = CGRect(x: 790, y: 612, width: 210, height: 88)

    // The fluid grid covers the flask: 48 x 60 cells of 8 pt.
    static let gx0: CGFloat = 320
    static let gy0: CGFloat = 170
    static let cell: CGFloat = 8
    static let NX = 48
    static let NY = 60

    static func cellCenter(_ i: Int, _ j: Int) -> CGPoint {
        CGPoint(x: gx0 + (CGFloat(i) + 0.5) * cell, y: gy0 + (CGFloat(j) + 0.5) * cell)
    }

    /// Is p inside the glass (body or neck), `pad` points in from the glass?
    static func inside(_ p: CGPoint, pad: CGFloat = 0) -> Bool {
        let dx = p.x - C.x, dy = p.y - C.y
        if dx * dx + dy * dy < (R - pad) * (R - pad) { return true }
        return abs(dx) < hw - pad && p.y >= rimY + pad && p.y <= C.y
    }

    /// Is p inside the outside of the glass (or within `pad` of it)?
    static func insideOuter(_ p: CGPoint, pad: CGFloat = 0) -> Bool {
        let g = glass + pad
        let dx = p.x - C.x, dy = p.y - C.y
        if dx * dx + dy * dy < (R + g) * (R + g) { return true }
        return abs(dx) < hw + g && p.y >= rimY - 6 - pad && p.y <= C.y
    }

    /// The empty space between the two sides of the rim. A falling ingredient can enter here.
    static func aboveOpening(_ p: CGPoint, inset: CGFloat = 0) -> Bool {
        p.y < rimY + inset && abs(p.x - C.x) < hw - inset
    }

    /// Half the inside width of the flask at height y (0 above the rim or below the bottom).
    static func halfWidth(at y: CGFloat) -> CGFloat {
        if y < rimY || y > bottomY { return 0 }
        let dy = y - C.y
        var w: CGFloat = 0
        if abs(dy) < R { w = sqrt(R * R - dy * dy) }
        if y <= C.y { w = max(w, hw) }
        return w
    }

    /// The liquid's area below each whole y from the rim down (index y - rimY).
    static let areaBelow: [CGFloat] = {
        let top = Int(PotionGeometry.rimY), bottom = Int(PotionGeometry.bottomY) + 1
        var a = [CGFloat](repeating: 0, count: bottom - top + 2)
        var sum: CGFloat = 0
        var y = bottom
        while y >= top {
            sum += 2 * PotionGeometry.halfWidth(at: CGFloat(y) + 0.5)
            a[y - top] = sum
            y -= 1
        }
        return a
    }()

    static var capacity: CGFloat { areaBelow[0] }

    /// How much liquid there is below a surface at y.
    static func volume(below y: CGFloat) -> CGFloat {
        let f = max(0, min(CGFloat(areaBelow.count - 1), y - rimY))
        let i = Int(f)
        let k = f - CGFloat(i)
        let a = areaBelow[i], b = areaBelow[min(areaBelow.count - 1, i + 1)]
        return a + (b - a) * k
    }

    /// Where the surface is for a volume of liquid.
    static func level(for v: CGFloat) -> CGFloat {
        if v <= 0 { return bottomY }
        if v >= capacity { return rimY }
        var lo = rimY, hi = bottomY
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if volume(below: mid) > v { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// The inside (or, with `out`, the outside) of the glass as a closed outline, from the left of the rim around
    /// the bottom to the right of the rim.
    static func outline(out d: CGFloat = 0) -> [CGPoint] {
        let r = R + d, h = hw + d
        let jy = C.y - sqrt(r * r - h * h)
        let a0 = atan2(Double(jy - C.y), Double(-h))      // the left join (in the upper left)
        var a1 = atan2(Double(jy - C.y), Double(h))       // the right join (in the upper right)
        // go from the left join down round the bottom to the right join: increasing angle in y-down screen space
        var a0u = a0
        if a0u < 0 { a0u += 2 * .pi }
        if a1 < 0 { a1 += 2 * .pi }
        // a0u is about 3.6 rad (upper left), a1 about 5.8 rad (upper right): go the long way, decreasing from a0u
        // through pi/2 (the bottom) ... so walk from a0u down to a1 - 2 pi
        let end = a1 - 2 * .pi
        var pts: [CGPoint] = [CGPoint(x: C.x - h, y: rimY - (d > 0 ? 4 : 0))]
        pts.append(CGPoint(x: C.x - h, y: jy))
        let n = 96
        for k in 1..<n {
            let a = a0u + (end - a0u) * Double(k) / Double(n)
            pts.append(CGPoint(x: C.x + r * CGFloat(cos(a)), y: C.y + r * CGFloat(sin(a))))
        }
        pts.append(CGPoint(x: C.x + h, y: jy))
        pts.append(CGPoint(x: C.x + h, y: rimY - (d > 0 ? 4 : 0)))
        return pts
    }

    static func path(_ pts: [CGPoint], closed: Bool = true) -> Path {
        var p = Path()
        p.addLines(pts)
        if closed { p.closeSubpath() }
        return p
    }

    static let interior: Path = PotionGeometry.path(PotionGeometry.outline())
    static let exterior: Path = PotionGeometry.path(PotionGeometry.outline(out: PotionGeometry.glass))
}

// MARK: - The ingredients

enum PMagic: String, CaseIterable, Codable {
    case love, bubble, fire, glow, sparkle, frost, rainbow, sleepy
}

enum PIngredient: Int, CaseIterable {
    case water, nectar, mermaid, dragon, moon, night
    case stars, petals, berries, frost, hair, lavender

    var isLiquid: Bool { rawValue <= PIngredient.night.rawValue }
    var key: String { String(describing: self) }

    /// The color it gives the potion.
    var color: RGB {
        switch self {
        case .water: return RGB(0.86, 0.95, 1)
        case .nectar: return RGB(hex: "#FF5FAE")
        case .mermaid: return RGB(hex: "#22D0C4")
        case .dragon: return RGB(hex: "#FF6418")
        case .moon: return RGB(hex: "#EEE8FF")
        case .night: return RGB(hex: "#3A2794")
        case .stars: return RGB(hex: "#FFD44A")
        case .petals: return RGB(hex: "#FF8DBA")
        case .berries: return RGB(hex: "#4A72FF")
        case .frost: return RGB(hex: "#BDF0FF")
        case .hair: return RGB(hex: "#FF9AD6")
        case .lavender: return RGB(hex: "#A27BFF")
        }
    }

    /// How strongly it colors (pigment per unit of liquid). Water has none.
    var strength: Float {
        switch self {
        case .water: return 0
        case .moon: return 0.75
        case .night: return 1.25
        case .frost: return 0.35
        default: return 1
        }
    }

    /// Heavier liquids sink and make layers, lighter ones float on top.
    var density: Float {
        switch self {
        case .night: return 0.7
        case .nectar: return 0.25
        case .dragon: return -0.25
        case .moon: return -0.5
        default: return 0
        }
    }

    var magic: PMagic? {
        switch self {
        case .water: return nil
        case .nectar, .petals: return .love
        case .mermaid, .berries: return .bubble
        case .dragon: return .fire
        case .moon: return .glow
        case .night, .stars: return .sparkle
        case .frost: return .frost
        case .hair: return .rainbow
        case .lavender: return .sleepy
        }
    }

    /// How much of it counts as "in the potion" for the secret combos.
    var need: CGFloat {
        switch self {
        case .hair: return 0.9
        case .stars, .petals, .berries, .frost, .lavender: return 1.8
        default: return 0.8
        }
    }

    /// Where it stands on its shelf (the bottom middle of the bottle or jar).
    var shelfSpot: CGPoint {
        let i = rawValue % 6
        let col = CGFloat(i % 3), row = CGFloat(i / 3)
        let x0: CGFloat = isLiquid ? 70 : 756
        return CGPoint(x: x0 + col * 99, y: row == 0 ? 262 : 420)
    }

    /// The bottle or jar's size on the shelf.
    static let size = CGSize(width: 84, height: 124)

    var shelfRect: CGRect {
        let s = shelfSpot
        return CGRect(x: s.x - 46, y: s.y - 132, width: 92, height: 136)
    }
}

// MARK: - The rare potions

enum PotionKind: String, CaseIterable, Codable {
    case love, galaxy, mermaid, dragon, moonlight, frost, rainbow, golden, dream, wild

    /// The color the potion turns into when the combo is right.
    var color: RGB {
        switch self {
        case .love: return RGB(hex: "#FF4F9A")
        case .galaxy: return RGB(hex: "#3B1E9C")
        case .mermaid: return RGB(hex: "#15C9B8")
        case .dragon: return RGB(hex: "#FF5512")
        case .moonlight: return RGB(hex: "#E2DCFF")
        case .frost: return RGB(hex: "#9DE8FF")
        case .rainbow: return RGB(hex: "#FF8AD0")
        case .golden: return RGB(hex: "#FFC22E")
        case .dream: return RGB(hex: "#9A78FF")
        case .wild: return RGB(hex: "#7CE05A")
        }
    }

    var glow: CGFloat {
        switch self {
        case .moonlight: return 1
        case .dragon: return 0.8
        case .golden: return 0.75
        case .galaxy: return 0.45
        case .wild, .rainbow: return 0.5
        default: return 0.3
        }
    }

    var sparkle: CGFloat {
        switch self {
        case .galaxy, .golden: return 1
        case .rainbow, .wild, .moonlight: return 0.7
        default: return 0.3
        }
    }

    var shape: PBottleShape {
        switch self {
        case .love: return .heart
        case .galaxy: return .star
        case .mermaid: return .drop
        case .dragon: return .square
        case .moonlight: return .round
        case .frost: return .tall
        case .rainbow: return .star
        case .golden: return .diamond
        case .dream: return .drop
        case .wild: return .square
        }
    }

    /// The main magic, for what it does to the unicorn.
    var magic: PMagic {
        switch self {
        case .love: return .love
        case .galaxy: return .sparkle
        case .mermaid: return .bubble
        case .dragon: return .fire
        case .moonlight: return .glow
        case .frost: return .frost
        case .rainbow: return .rainbow
        case .golden: return .glow
        case .dream: return .sleepy
        case .wild: return .rainbow
        }
    }

    /// The recipe, as pictures for the hint card: ingredients, plus the burner on high or the lights off.
    var recipe: [PIngredient] {
        switch self {
        case .love: return [.nectar, .petals]
        case .galaxy: return [.night, .stars]
        case .mermaid: return [.mermaid, .berries]
        case .dragon: return [.dragon]
        case .moonlight: return [.moon]
        case .frost: return [.frost, .mermaid]
        case .rainbow: return [.hair, .nectar, .mermaid, .moon]
        case .golden: return [.stars, .dragon, .moon]
        case .dream: return [.lavender, .moon]
        case .wild: return [.nectar, .mermaid, .dragon, .night, .stars, .berries, .lavender]
        }
    }
    var needsFire: Bool { self == .dragon }
    var needsNight: Bool { self == .moonlight }
}

/// The shape of a potion bottle. Points are the inside of the glass, centered on the bottle, bottom at y = 58,
/// mouth at y = -62.
enum PBottleShape: Int, CaseIterable, Codable {
    case round, tall, heart, star, drop, square, diamond

    static let mouthY: CGFloat = -62
    static let bottomY: CGFloat = 58

    var outline: [CGPoint] { PBottleShape.cache[rawValue] }

    private static let cache: [[CGPoint]] = PBottleShape.allCases.map { $0.make() }

    /// The neck's half width.
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
            // a round body (r 42 at y 16) on a long neck
            let c = CGPoint(x: 0, y: 16), r: CGFloat = 42
            let a0 = asin(Double(n / r))
            for k in 0...40 {
                let a = -Double.pi / 2 + a0 + (2 * Double.pi - 2 * a0) * Double(k) / 40
                body.append(CGPoint(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a))))
            }
        case .tall:
            body = [CGPoint(x: n, y: -34), CGPoint(x: 26, y: -24), CGPoint(x: 28, y: 46),
                    CGPoint(x: 22, y: 56), CGPoint(x: 0, y: 58), CGPoint(x: -22, y: 56), CGPoint(x: -28, y: 46),
                    CGPoint(x: -26, y: -24), CGPoint(x: -n, y: -34)]
        case .heart:
            // a heart, point down
            for k in 0...48 {
                let t = Double(k) / 48 * 2 * Double.pi
                let x = 16 * pow(sin(t), 3)
                let y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
                body.append(CGPoint(x: CGFloat(x) * 2.9, y: CGFloat(y) * 2.9 + 20))
            }
            // it runs clockwise from the top dip: keep the neck out of it
            body = body.filter { !($0.y < 14 && abs($0.x) < n + 2) }
        case .star:
            for k in 0..<10 {
                let a = -Double.pi / 2 + Double(k) * Double.pi / 5
                let r: CGFloat = k % 2 == 0 ? 50 : 28
                body.append(CGPoint(x: r * CGFloat(cos(a)), y: 14 + r * CGFloat(sin(a))))
            }
            // round the points a little by cutting the corners
            var soft: [CGPoint] = []
            for k in 0..<body.count {
                let a = body[k], b = body[(k + 1) % body.count]
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
            body = [CGPoint(x: n, y: -36), CGPoint(x: 30, y: -30), CGPoint(x: 36, y: -22), CGPoint(x: 36, y: 50),
                    CGPoint(x: 30, y: 58), CGPoint(x: -30, y: 58), CGPoint(x: -36, y: 50), CGPoint(x: -36, y: -22),
                    CGPoint(x: -30, y: -30), CGPoint(x: -n, y: -36)]
        case .diamond:
            body = [CGPoint(x: n, y: -30), CGPoint(x: 40, y: 6), CGPoint(x: 0, y: 58), CGPoint(x: -40, y: 6),
                    CGPoint(x: -n, y: -30)]
        }
        // start at the neck's right side going down, end at its left side
        guard let first = body.first, let last = body.last else { return [] }
        var pts = [CGPoint(x: n, y: PBottleShape.mouthY)]
        pts.append(CGPoint(x: n, y: min(first.y, -20)))
        pts.append(contentsOf: body)
        pts.append(CGPoint(x: -n, y: min(last.y, -20)))
        pts.append(CGPoint(x: -n, y: PBottleShape.mouthY))
        return pts
    }

    /// The inside area of the bottle, for how much it holds.
    var area: CGFloat { PPoly.area(outline) }
}

/// Little polygon helpers for bottles that tip: the liquid in them stays level.
enum PPoly {
    static func area(_ p: [CGPoint]) -> CGFloat {
        guard p.count > 2 else { return 0 }
        var a: CGFloat = 0
        for i in 0..<p.count {
            let q = p[i], r = p[(i + 1) % p.count]
            a += q.x * r.y - r.x * q.y
        }
        return abs(a) / 2
    }

    /// The part of the polygon below the line y (screen space: larger y is lower).
    static func below(_ p: [CGPoint], _ y: CGFloat) -> [CGPoint] {
        guard p.count > 2 else { return [] }
        var out: [CGPoint] = []
        for i in 0..<p.count {
            let a = p[i], b = p[(i + 1) % p.count]
            let ina = a.y >= y, inb = b.y >= y
            if ina { out.append(a) }
            if ina != inb {
                let t = (y - a.y) / (b.y - a.y)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: y))
            }
        }
        return out
    }

    /// The height of a level surface holding `fill` (0...1) of the polygon.
    static func level(_ p: [CGPoint], fill: CGFloat) -> CGFloat {
        let total = area(p)
        guard total > 0, let lo0 = p.map(\.y).min(), let hi0 = p.map(\.y).max() else { return 0 }
        if fill <= 0 { return hi0 }
        if fill >= 1 { return lo0 }
        var lo = lo0, hi = hi0
        let want = total * fill
        for _ in 0..<20 {
            let mid = (lo + hi) / 2
            if area(below(p, mid)) > want { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    static func transform(_ p: [CGPoint], at c: CGPoint, angle: CGFloat, scale: CGFloat) -> [CGPoint] {
        let ca = cos(angle), sa = sin(angle)
        return p.map { q in
            CGPoint(x: c.x + (q.x * ca - q.y * sa) * scale, y: c.y + (q.x * sa + q.y * ca) * scale)
        }
    }
}

// MARK: - Bottled potions and the save

struct PotionBottle: Codable, Equatable {
    var id: Int
    var r: Double
    var g: Double
    var b: Double
    /// How full, 0...1.
    var fill: Double
    var shape: Int
    var kind: String?
    /// How strong each magic is in it (by `PMagic` name), 0...1.
    var magic: [String: Double]
    var glow: Double
    var sparkle: Double

    var color: RGB { RGB(r, g, b) }
    var potion: PotionKind? { kind.flatMap(PotionKind.init(rawValue:)) }
    var bottleShape: PBottleShape { PBottleShape(rawValue: shape) ?? .round }

    /// The strongest magic in it.
    var mainMagic: PMagic? {
        if let k = potion { return k.magic }
        guard let best = magic.max(by: { $0.value < $1.value }), best.value > 0.12 else { return nil }
        return PMagic(rawValue: best.key)
    }
}

struct PotionSave: Codable {
    var bottles: [PotionBottle] = []
    var nextID = 1
    var volume: Double = 0
    /// The flask's potion, mixed: pigment (premultiplied color and amount).
    var pr: Double = 0
    var pg: Double = 0
    var pb: Double = 0
    var pa: Double = 0
    var doses: [String: Double] = [:]
    var lightsOn = true
    var heat = 0
    var made = 0
}
