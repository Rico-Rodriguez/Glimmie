import SwiftUI

// MARK: - What sits on the stand
//
// A treat is built in its own space: x across (dx), height up (h) from the rim of its cone, cup or glass, and for
// the soft-serve rope also depth toward her (z). It's drawn at the stand point S as (S.x + dx, S.y - h + 0.3 z), so
// the stand can slide and sink (it does under the soft-serve nozzle) and everything on it goes along.
//
// `profile` is the treat's top edge as she sees it, in 2-point columns. Sprinkles, sauce, cherries and the whipped
// cream all land on it, so they sit on whatever is really there: a scoop, the swirl, the smoothie.

struct ICScoop: Equatable {
    var id: Int
    var flavor: ICFlavor
    /// A second flavor marbled in (she scooped from two tubs).
    var swirl: ICFlavor?
    var r: CGFloat
    var dx: CGFloat
    var h: CGFloat
    var vh: CGFloat = 0
    var landed = true
    var squash: CGFloat = 0
    var squashV: CGFloat = 0
    var wob: CGFloat = 0
    var wobV: CGFloat = 0
    var age: CGFloat = 0
    var drips: [ICDrip] = []
    var nextDrip: CGFloat = 9
}

/// A melting drip running down from a scoop's lower edge.
struct ICDrip: Equatable {
    var dx: CGFloat
    var len: CGFloat = 0
    var max: CGFloat
    var w: CGFloat
}

/// One bead of the soft-serve or whipped-cream rope.
struct ICBead: Equatable {
    var x: CGFloat
    var z: CGFloat
    var h: CGFloat
    var r: CGFloat
    /// Which of the flavor's two colors (twist).
    var c: Int
    /// Cumulative angle it was laid at (finds the bead one turn below).
    var turn: CGFloat
}

struct ICStuck: Equatable {
    var dx: CGFloat
    var dy: CGFloat
    var rot: CGFloat
    var color: Int
    /// On the treat (moves with it) or fallen onto the counter.
    var onTop: Bool
}

struct ICBody: Equatable {
    var dx: CGFloat
    var h: CGFloat
    var vx: CGFloat
    var vh: CGFloat
    var resting: Bool
    var wob: CGFloat = 0
    var wobV: CGFloat = 0
}

struct ICStick: Equatable {
    var dx: CGFloat
    var h: CGFloat
    var angle: CGFloat
}

/// A band of smoothie in the glass, from the band below up to `top` (fraction of the glass).
struct ICLayer: Equatable {
    var top: CGFloat
    var color: ICColor
}

/// Sauce that ran over the top: how much sits on each profile column and how far it has run down.
struct ICSauce: Equatable {
    var topping: ICTopping
    var amount: [CGFloat]
    var run: [CGFloat]
}

struct ICBuild: Equatable {
    static let columns = 141
    static let colW: CGFloat = 2
    static let colX0: CGFloat = -140

    var base: ICBase?
    var scoops: [ICScoop] = []
    var rope: [ICBead] = []
    var ropeFlavor: ICSoft?
    var ropeTipped = false
    var whip: [ICBead] = []
    var layers: [ICLayer] = []
    /// Fruit blended into the glass, by ICFruit raw value.
    var fruitIn: [CGFloat] = [CGFloat](repeating: 0, count: ICFruit.allCases.count)
    var sprinkles: [ICStuck] = []
    var sauces: [ICSauce] = []
    var cherry: ICBody?
    var wafer: ICStick?
    var straw: ICStick?
    /// Drawn as a still picture (the order card).
    var picture = false
    var pictureSauce: ICTopping?
    var overflow: CGFloat = 0

    var profile: [CGFloat] = [CGFloat](repeating: -999, count: ICBuild.columns)

    static func col(_ dx: CGFloat) -> Int { Int(((dx - colX0) / colW).rounded()) }
    static func colDX(_ i: Int) -> CGFloat { colX0 + colW * CGFloat(i) }

    var isEmpty: Bool { base == nil && scoops.isEmpty && rope.isEmpty }
    var hasTreat: Bool {
        !scoops.isEmpty || rope.count > 20 || fill > 0.25
    }

    var kind: ICKind {
        if base == .glass && scoops.isEmpty && rope.isEmpty { return .smoothie }
        if !rope.isEmpty && scoops.isEmpty { return .soft }
        return .scoops
    }

    var fill: CGFloat { layers.last?.top ?? 0 }

    /// The flavor most of the swirl is (beads carry flavor * 2 + stripe).
    var softFlavor: ICSoft? {
        guard rope.count > 20 else { return nil }
        var n = [Int](repeating: 0, count: ICSoft.allCases.count)
        for b in rope { n[max(0, min(n.count - 1, b.c / 2))] += 1 }
        let best = n.indices.max { n[$0] < n[$1] } ?? 0
        return ICSoft(rawValue: best)
    }

    /// The turntable's angle: the swirl turns with it.
    var ropeSpin: CGFloat = 0

    /// A rope bead's place after the turntable turned (x across, z toward her).
    func spun(_ b: ICBead) -> (x: CGFloat, z: CGFloat) {
        if ropeSpin == 0 { return (b.x, b.z) }
        let c = cos(ropeSpin), s = sin(ropeSpin)
        return (b.x * c - b.z * s, b.x * s + b.z * c)
    }

    func has(_ t: ICTopping) -> Bool {
        switch t {
        case .sprinkles: return sprinkles.filter { $0.onTop }.count >= 6 || (picture && !sprinkles.isEmpty)
        case .chocoSauce, .berrySauce:
            if pictureSauce == t { return true }
            return sauces.contains { $0.topping == t && $0.amount.reduce(0, +) > 3 }
        case .whip: return whip.count >= 12
        case .cherry: return cherry != nil
        case .wafer: return wafer != nil
        case .straw: return straw != nil
        }
    }

    /// The top of the treat at dx (height up), or nil over nothing.
    func top(_ dx: CGFloat) -> CGFloat? {
        let f = (dx - ICBuild.colX0) / ICBuild.colW
        let i0 = Int(f.rounded(.down))
        guard i0 >= 0, i0 < ICBuild.columns - 1 else { return nil }
        let a = profile[i0], b = profile[i0 + 1]
        if a < -500 && b < -500 { return nil }
        if a < -500 { return b }
        if b < -500 { return a }
        let k = f - CGFloat(i0)
        return a + (b - a) * k
    }

    /// The lowest a sauce may run at a column: a little past the rim, or to the bottom of a free-standing scoop.
    func sauceFloor(_ dx: CGFloat) -> CGFloat {
        switch base {
        case .glass?: return -14
        case .cup?: return -8
        default: return -12
        }
    }

    // MARK: Profile

    mutating func rebuildProfile() {
        var p = [CGFloat](repeating: -999, count: ICBuild.columns)
        func lift(_ i: Int, _ v: CGFloat) {
            if i >= 0 && i < ICBuild.columns && v > p[i] { p[i] = v }
        }
        if let b = base {
            let rim = b.rim
            for i in 0..<ICBuild.columns {
                let x = ICBuild.colDX(i)
                if abs(x) <= rim + 6 {
                    if b == .glass {
                        let inner = abs(x) < rim - 4
                        let liquid = b.floor + (-b.floor) * min(1, fill)
                        lift(i, inner ? (fill > 0.02 ? liquid : b.floor + 4) : 0)
                    } else if b == .cup {
                        lift(i, abs(x) < rim - 4 ? b.floor + 4 : 0)
                    } else {
                        lift(i, abs(x) < rim - 4 ? -6 : 2)
                    }
                }
            }
        }
        for s in scoops {
            let r = s.r * (1 + s.squash * 0.3)
            let lo = ICBuild.col(s.dx - r), hi = ICBuild.col(s.dx + r)
            if lo > hi { continue }
            for i in max(0, lo)...min(ICBuild.columns - 1, hi) {
                let d = ICBuild.colDX(i) - s.dx
                let q = r * r - d * d
                if q > 0 { lift(i, s.h + sqrt(q) * (1 - s.squash)) }
            }
        }
        for (n, list) in [rope, whip].enumerated() {
            for b0 in list {
                var b = b0
                if n == 0 {
                    let w = spun(b0)
                    b.x = w.x
                    b.z = w.z
                }
                let up = b.h - b.z * 0.3
                let lo = ICBuild.col(b.x - b.r), hi = ICBuild.col(b.x + b.r)
                if lo > hi { continue }
                for i in max(0, lo)...min(ICBuild.columns - 1, hi) {
                    let d = ICBuild.colDX(i) - b.x
                    let q = b.r * b.r - d * d
                    if q > 0 { lift(i, up + sqrt(q)) }
                }
            }
        }
        if let c = cherry {
            let r: CGFloat = 12
            let lo = ICBuild.col(c.dx - r), hi = ICBuild.col(c.dx + r)
            if lo <= hi {
                for i in max(0, lo)...min(ICBuild.columns - 1, hi) {
                    let d = ICBuild.colDX(i) - c.dx
                    let q = r * r - d * d
                    if q > 0 { lift(i, c.h + sqrt(q)) }
                }
            }
        }
        profile = p
    }

    /// The profile without the cherry (what the cherry itself rests on).
    func supportForCherry(_ dx: CGFloat) -> CGFloat? {
        var copy = self
        copy.cherry = nil
        copy.rebuildProfile()
        return copy.top(dx)
    }

    // MARK: Picture helpers

    /// A finished swirl, for the order card: the same laying rule the machine uses, run at once.
    static func sampleSwirl(_ f: ICSoft, floor: CGFloat) -> [ICBead] {
        var out: [ICBead] = []
        var turn: CGFloat = 0
        let r: CGFloat = 13
        var h = floor
        var rho: CGFloat = 30
        var i = 0
        while h - floor < 128 && i < 600 {
            let loops = turn / (2 * .pi)
            rho = max(0, 30 * (1 - loops / 6.4))
            let step = 5 / max(rho, 6)
            turn += step
            h = floor + loops * 19 + (rho < 3 ? CGFloat(i % 7) : 0)
            let stripe = f == .twist ? Int((turn / 0.9).rounded(.down)) % 2 : 0
            out.append(ICBead(x: rho * cos(turn), z: -rho * sin(turn), h: h, r: r * (rho < 4 ? 0.8 : 1), c: f.rawValue * 2 + stripe, turn: turn))
            i += 1
        }
        return out
    }

    static func sampleWhip() -> [ICBead] {
        var out: [ICBead] = []
        var turn: CGFloat = 0
        for i in 0..<60 {
            let loops = turn / (2 * .pi)
            let rho = max(0, 20 * (1 - loops / 2.6))
            turn += 4 / max(rho, 5)
            out.append(ICBead(x: rho * cos(turn), z: -rho * sin(turn), h: loops * 11 + (rho < 2 ? CGFloat(i % 4) * 2 : 0), r: 9, c: 0, turn: turn))
        }
        return out
    }

    /// Puts a picture's toppings onto whatever is under them.
    mutating func settlePicture() {
        let w = whip, c = cherry
        whip = []
        cherry = nil
        rebuildProfile()
        let top0 = top(0) ?? 0
        whip = w.map { (b0: ICBead) -> ICBead in
            var b = b0
            b.h += top0 - 2
            return b
        }
        rebuildProfile()
        if let pc = pictureSauce {
            var s = ICSauce(topping: pc, amount: [CGFloat](repeating: 0, count: ICBuild.columns),
                            run: [CGFloat](repeating: 0, count: ICBuild.columns))
            for i in 0..<ICBuild.columns where profile[i] > -500 && abs(ICBuild.colDX(i)) < 44 {
                s.amount[i] = 0.6
                s.run[i] = 8 + 22 * icRand(i / 4, 9)
            }
            sauces = [s]
        }
        if c != nil {
            let t = top(0) ?? 0
            cherry = ICBody(dx: 0, h: t + 10, vx: 0, vh: 0, resting: true)
        }
        if var wf = wafer {
            wf.h = (top(wf.dx) ?? 0) - 16
            wafer = wf
        }
        if var st = straw {
            st.h = (base?.floor ?? 0) + 16
            straw = st
        }
        let settled = profile
        sprinkles = sprinkles.map { (k0: ICStuck) -> ICStuck in
            var k = k0
            let f = (k.dx - ICBuild.colX0) / ICBuild.colW
            let i = max(0, min(ICBuild.columns - 1, Int(f.rounded())))
            k.dy = max(0, settled[i]) + 1
            return k
        }
        rebuildProfile()
    }

    /// Converts a served parlor treat into a Bakery `Treat` so it displays in `TreatCase`.
    func toBakeryTreat() -> Treat {
        var t = Treat(kind: .iceCream)
        switch base {
        case .choco?: t.cone = "choco"
        case .cup?: t.cone = "cup"; t.liner = 0
        case .glass?: t.cone = "cup"; t.liner = 1
        default: t.cone = "waffle"
        }

        switch kind {
        case .scoops:
            t.scoops = scoops.prefix(4).map { Self.bakeryFlavor(for: $0.flavor) }
        case .soft:
            switch softFlavor ?? .vanilla {
            case .vanilla: t.scoops = [0, 0]
            case .chocolate: t.scoops = [1, 1]
            case .twist: t.scoops = [0, 1]
            case .strawberry: t.scoops = [2, 2]
            }
        case .smoothie:
            let ranked = fruitIn.enumerated()
                .filter { $0.element > 0.005 }
                .sorted { $0.element > $1.element }
                .compactMap { ICFruit(rawValue: $0.offset) }
                .prefix(2)
                .map { Self.bakeryFlavor(for: $0) }
            t.scoops = ranked.isEmpty ? [2] : Array(ranked)
        }
        if t.scoops.isEmpty { t.scoops = [0] }

        if has(.chocoSauce) { t.sauce = 0 }
        else if has(.berrySauce) { t.sauce = 1 }

        let art = BakeryArt.shared
        let topY = art.scoopY0 - CGFloat(max(0, min(4, t.scoops.count) - 1)) * art.scoopDY
        if has(.whip) {
            t.toppings.append(PlacedTopping(sprite: "top_cream", x: 300, y: Double(topY - 68), scale: 0.9, color: 11))
        }
        if has(.cherry) {
            t.toppings.append(PlacedTopping(sprite: "top_cherry", x: 300, y: Double(topY - 94), scale: 1.05))
        }
        if has(.wafer) {
            t.toppings.append(PlacedTopping(sprite: "top_wafer", x: 344, y: Double(topY - 62), rot: 18, scale: 0.95))
        }
        if has(.straw) {
            t.toppings.append(PlacedTopping(sprite: "top_cane", x: 338, y: Double(topY - 76), rot: 14, scale: 0.95))
        }
        if has(.sprinkles) {
            let spots: [(Double, Double, Double, Int)] = [
                (268, Double(topY - 54), 25, 0), (322, Double(topY - 48), 110, 4),
                (288, Double(topY - 34), 70, 5), (336, Double(topY - 26), 145, 7),
                (258, Double(topY - 28), 15, 9), (305, Double(topY - 64), 95, 2),
            ]
            for (x, y, rot, c) in spots {
                t.toppings.append(PlacedTopping(sprite: "bit_sprinkle", x: x, y: y, rot: rot, scale: 1, color: c))
            }
        }
        return t
    }

    private static func bakeryFlavor(for f: ICFlavor) -> Int {
        switch f {
        case .vanilla: return 0
        case .chocolate: return 1
        case .strawberry: return 2
        case .blueberry: return 3
        case .mint: return 5
        case .mango: return 12
        }
    }

    private static func bakeryFlavor(for f: ICFruit) -> Int {
        switch f {
        case .strawberry: return 2
        case .banana: return 4
        case .blueberry: return 3
        case .mango: return 12
        case .kiwi: return 10
        case .ice: return 8
        }
    }
}
