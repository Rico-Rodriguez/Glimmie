import AVFoundation
import SwiftUI

// MARK: - Makeup and nails (saved on the look)
//
// Makeup is what she painted in the makeup studio: soft blush and eyeshadow strokes, lipstick inside
// the lips, and glitter flecks where they landed, all in doll art coordinates (600x900). Nails are the
// polish on each of her five fingers (both hands match): which cells of the nail she covered, its
// color, coats, a glitter top coat and any gems or stickers. Saves stay lenient: only add fields.

struct BeautyStroke: Codable, Equatable {
    /// "blush", "shadow", "lip" or "glitter" (glitter points are single flecks, not a line).
    var tool: String
    /// "#RRGGBB", or "rainbow" for glitter.
    var color: String
    /// x, y pairs in doll art coordinates.
    var pts: [Float]

    init(tool: String, color: String, pts: [Float] = []) { self.tool = tool; self.color = color; self.pts = pts }

    enum CodingKeys: String, CodingKey { case tool, color, pts }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tool = (try? c.decodeIfPresent(String.self, forKey: .tool)) ?? ""
        color = (try? c.decodeIfPresent(String.self, forKey: .color)) ?? ""
        pts = (try? c.decodeIfPresent([Float].self, forKey: .pts)) ?? []
    }

    static let tools = ["blush", "shadow", "lip", "glitter"]

    var hasPoints: Bool { pts.count >= 2 }

    var points: [CGPoint] {
        stride(from: 0, to: pts.count - 1, by: 2).map { CGPoint(x: CGFloat(pts[$0]), y: CGFloat(pts[$0 + 1])) }
    }
}

struct NailGem: Codable, Equatable {
    /// A gem ("g_round", "g_heart", "g_star", "g_pearl") with a color, or a sticker ("s_" + SF Symbol).
    var kind: String
    var color: String = "#FFFFFF"
    /// Nail coordinates: u across (-1...1), v from the cuticle (0) to the tip (1).
    var u: Float = 0
    var v: Float = 0.5
    var turn: Float = 0

    init(kind: String, color: String, u: Float, v: Float, turn: Float = 0) {
        self.kind = kind; self.color = color; self.u = u; self.v = v; self.turn = turn
    }

    enum CodingKeys: String, CodingKey { case kind, color, u, v, turn }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? ""
        color = (try? c.decodeIfPresent(String.self, forKey: .color)) ?? "#FFFFFF"
        u = (try? c.decodeIfPresent(Float.self, forKey: .u)) ?? 0
        v = (try? c.decodeIfPresent(Float.self, forKey: .v)) ?? 0.5
        turn = (try? c.decodeIfPresent(Float.self, forKey: .turn)) ?? 0
    }

    static let gems = ["g_round", "g_heart", "g_star", "g_pearl"]
    static let stickers = ["s_heart.fill", "s_star.fill", "s_sparkle", "s_moon.fill", "s_camera.macro", "s_bolt.fill"]
    static func isKnown(_ k: String) -> Bool { gems.contains(k) || stickers.contains(k) }
}

struct NailPaint: Codable, Equatable {
    var color: String?
    /// Covered cells of the nail grid, as hex bits (see `NailGrid`).
    var mask: String = ""
    var coats = 0
    var glitter = false
    var gems: [NailGem] = []

    init() {}

    enum CodingKeys: String, CodingKey { case color, mask, coats, glitter, gems }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        color = try? c.decodeIfPresent(String.self, forKey: .color)
        mask = (try? c.decodeIfPresent(String.self, forKey: .mask)) ?? ""
        coats = (try? c.decodeIfPresent(Int.self, forKey: .coats)) ?? 0
        glitter = (try? c.decodeIfPresent(Bool.self, forKey: .glitter)) ?? false
        gems = (try? c.decodeIfPresent([NailGem].self, forKey: .gems)) ?? []
    }

    var painted: Bool { color != nil && NailGrid.decode(mask).contains(true) }
    var hasArt: Bool { painted || !gems.isEmpty }
}

/// The coverage grid on a nail: `cols` across by `rows` from cuticle to tip.
enum NailGrid {
    static let cols = 8, rows = 12
    static var count: Int { cols * rows }

    static func center(_ i: Int) -> (u: Double, v: Double) {
        let c = i % cols, r = i / cols
        return (-1 + (Double(c) + 0.5) * 2 / Double(cols), (Double(r) + 0.5) / Double(rows))
    }

    /// Cells inside the rounded nail outline (the corners of the grid are outside it).
    static let inside: [Bool] = (0..<count).map { i in
        let (u, v) = center(i)
        // rounded at the cuticle and at the free edge
        let e = v < 0.3 ? (v - 0.3) / 0.3 : (v > 0.62 ? (v - 0.62) / 0.38 : 0)
        return u * u + e * e <= 1.02
    }

    static func encode(_ bits: [Bool]) -> String {
        var s = ""
        for k in stride(from: 0, to: count, by: 4) {
            var n = 0
            for j in 0..<4 where k + j < bits.count && bits[k + j] { n |= 1 << (3 - j) }
            s += String(n, radix: 16)
        }
        return s
    }

    static func decode(_ s: String) -> [Bool] {
        var out = [Bool](repeating: false, count: count)
        for (k, ch) in s.prefix(count / 4).enumerated() {
            guard let n = Int(String(ch), radix: 16) else { continue }
            for j in 0..<4 where k * 4 + j < count { out[k * 4 + j] = n & (1 << (3 - j)) != 0 }
        }
        return out
    }

    static func isMask(_ s: String) -> Bool { s.count == count / 4 && s.allSatisfy { $0.isHexDigit } }
}

// MARK: - Colors

enum BeautyColors {
    static let blush = ["#FF8FA8", "#FF9E7A", "#F56C8E", "#E58FC9", "#FFB0C4", "#D9776B"]
    static let shadow = ["#B48BE8", "#7FB8F0", "#F2C14E", "#FF8FB8", "#7DD8B5", "#A0715A", "#6E5BD0", "#F4A6E0"]
    static let lip = ["#E8475A", "#F45C9A", "#B0306A", "#FF7F66", "#D98B86", "#9B3FBF", "#FF5FA2", "#C8102E"]
    static let glitter = ["#F2C14E", "#E8E8F4", "#FF8FB8", "#8FD8FF", "rainbow"]
    static let polish = ["#E8475A", "#F45C9A", "#FF8FB8", "#FFB0C4", "#FF9E5A", "#FFE27A", "#7DD8B5", "#7FB8F0",
                         "#6E5BD0", "#B48BE8", "#2E2A3A", "#FFFFFF", "#C9A0DC", "#36B5A8"]

    static func rgb(_ hex: String, _ i: Int = 0) -> RGB {
        if hex == "rainbow" {
            let hues = ["#FF6F91", "#FFA24C", "#FFE27A", "#6CCB8B", "#6FB6F0", "#9B79E0"]
            return RGB(hex: hues[((i % hues.count) + hues.count) % hues.count])
        }
        return RGB(hex: hex)
    }

    static func isColor(_ s: String) -> Bool { s == "rainbow" || Look.isHex(s) }
}

// MARK: - Sounds

enum BeautySFX: String, CaseIterable {
    case brush = "b_brush", sponge = "b_sponge", lipstick = "b_lipstick", shake = "b_shake", tinkle = "b_tinkle"
    case wipe = "b_wipe", cap = "b_cap", dip = "b_dip", polish = "b_polish", drip = "b_drip", dryer = "b_dryer"
    case clink = "b_clink", compact = "b_compact", dry = "b_dry"
}

final class BeautySound {
    static let shared = BeautySound()
    private static let maxPoolSize = 3

    private let queue = DispatchQueue(label: "glimmie.dressup.beautySound", qos: .userInitiated)
    private var players: [BeautySFX: [AVAudioPlayer]] = [:]
    private var missing: Set<BeautySFX> = []
    private var last: [BeautySFX: Date] = [:]

    static func url(for s: BeautySFX) -> URL? {
        GameFiles.url(s.rawValue, "caf", game: "DressUp") ?? GameFiles.url(s.rawValue, "wav", game: "DressUp")
    }

    private init() {
        _ = Sound.shared
    }

    /// Plays `s`, at most once every `gap` seconds (for sounds repeated while a finger moves).
    func play(_ s: BeautySFX, volume: Float = 0.8, gap: Double = 0) {
        let now = Date()
        queue.async {
            if gap > 0, let t = self.last[s], now.timeIntervalSince(t) < gap { return }
            self.last[s] = now
            guard let p = self.player(for: s) else { return }
            p.volume = volume
            p.currentTime = 0
            p.play()
        }
    }

    private func player(for s: BeautySFX) -> AVAudioPlayer? {
        guard !missing.contains(s) else { return nil }
        let pool = players[s] ?? []
        if let idle = pool.first(where: { !$0.isPlaying }) { return idle }
        if pool.count < Self.maxPoolSize {
            if let created = makePlayer(for: s) {
                players[s] = pool + [created]
                return created
            }
            if pool.isEmpty { missing.insert(s) }
        }
        return pool.max(by: { $0.currentTime < $1.currentTime }) ?? pool.first
    }

    private func makePlayer(for s: BeautySFX) -> AVAudioPlayer? {
        guard let url = Self.url(for: s),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }
}

// MARK: - Drawing makeup and nails on the doll

enum BeautyPainter {
    /// Where each pass goes among the doll's layers: skin makeup and nails over the skin (under hair,
    /// eyes and clothes), lipstick under the mouth line, glitter over the eye makeup.
    static let skinZ = 20.5, lipZ = 40.5, glitterZ = 42.5, heldHandZ = 70.5

    static let lipsCenter = CGPoint(x: 300, y: 388)
    static let lipsSize = CGSize(width: 64, height: 30)
    static var lipsPath: Path { Path(ellipseIn: CGRect(x: lipsCenter.x - lipsSize.width / 2, y: lipsCenter.y - lipsSize.height / 2,
                                                       width: lipsSize.width, height: lipsSize.height)) }
    static let eyes = [CGPoint(x: 238, y: 326), CGPoint(x: 362, y: 326)]
    static let hands = [CGPoint(x: 221, y: 548), CGPoint(x: 379, y: 548)]

    /// Draws every pass whose place lies in (from, to].
    static func passes(_ look: Look, from a: Double, to b: Double, t: Double = 0, in ctx: GraphicsContext) {
        guard !look.makeup.isEmpty || !look.nails.isEmpty else { return }
        func hit(_ z: Double) -> Bool { a < z && z <= b }
        if hit(skinZ) {
            skin(look, in: ctx)
            dollNails(look, hands: [0, 1], in: ctx)
        }
        if hit(lipZ) { lips(look, in: ctx) }
        if hit(glitterZ) { glitter(look.makeup, t: t, in: ctx) }
        if hit(heldHandZ), look.picks["hold"] != nil { dollNails(look, hands: [1], in: ctx) }
    }

    /// Draws `layers` with the makeup and nail passes in between (what DollPainter does).
    static func interleave<T>(_ layers: [T], z: (T) -> Int, look: Look, t: Double = 0, in ctx: GraphicsContext, draw: (T) -> Void) {
        var prev = -Double.infinity
        for l in layers {
            let zz = Double(z(l))
            passes(look, from: prev, to: zz, t: t, in: ctx)
            prev = zz
            draw(l)
        }
        passes(look, from: prev, to: .infinity, t: t, in: ctx)
    }

    private static var faceClips: [String: Path] = [:]

    /// The skin of her face (head and ears), so makeup never lands on hair or the background.
    static func faceClip(_ look: Look) -> Path {
        let id = look.picks["face"] ?? "face_round"
        if let p = faceClips[id] { return p }
        var p = Path()
        for L in DressUpArt.shared.items[id]?.layers ?? [] {
            for s in L.shapes where s.fill != nil { p.addPath(s.path) }
        }
        if p.isEmpty { p = Path(ellipseIn: CGRect(x: 158, y: 150, width: 284, height: 274)) }
        faceClips[id] = p
        return p
    }

    static func smooth(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        if pts.count == 1 { p.addLine(to: CGPoint(x: first.x + 0.5, y: first.y + 0.3)); return p }
        for i in 1..<pts.count {
            if i == pts.count - 1 { p.addLine(to: pts[i]); break }
            let m = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            p.addQuadCurve(to: m, control: pts[i])
        }
        return p
    }

    static func style(_ tool: String) -> (width: CGFloat, opacity: Double, blur: CGFloat) {
        switch tool {
        case "blush": return (34, 0.26, 9)
        case "shadow": return (20, 0.5, 3.5)
        default: return (11, 0.88, 1.0)
        }
    }

    /// Blush and eyeshadow: soft, building up stroke over stroke.
    static func skin(_ look: Look, in ctx: GraphicsContext) {
        let strokes = look.makeup.filter { $0.tool == "blush" || $0.tool == "shadow" }
        guard !strokes.isEmpty else { return }
        var g = ctx
        g.clip(to: faceClip(look))
        for tool in ["blush", "shadow"] {
            let these = strokes.filter { $0.tool == tool }
            guard !these.isEmpty else { continue }
            let st = style(tool)
            g.drawLayer { l in
                l.addFilter(.blur(radius: st.blur))
                for s in these {
                    l.stroke(smooth(s.points), with: .color(RGB(hex: s.color).color.opacity(st.opacity)),
                             style: StrokeStyle(lineWidth: st.width, lineCap: .round, lineJoin: .round))
                }
            }
            if tool == "shadow" {
                // a little shimmer in the shadow
                g.drawLayer { l in
                    l.addFilter(.blur(radius: 2))
                    for s in these {
                        l.stroke(smooth(s.points), with: .color(.white.opacity(0.12)),
                                 style: StrokeStyle(lineWidth: st.width * 0.3, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
    }

    /// Lipstick: only inside the lips, satiny, with a glossy highlight where it is.
    static func lips(_ look: Look, in ctx: GraphicsContext) {
        let strokes = look.makeup.filter { $0.tool == "lip" }
        guard !strokes.isEmpty else { return }
        var g = ctx
        g.clip(to: faceClip(look))
        g.clip(to: lipsPath)
        g.drawLayer { l in
            l.addFilter(.blur(radius: 1.2))
            for s in strokes {
                let c = RGB(hex: s.color)
                l.stroke(smooth(s.points), with: .color(c.color.opacity(0.9)),
                         style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            }
            // the gloss shows only on the painted parts
            l.blendMode = .sourceAtop
            l.fill(Path(ellipseIn: CGRect(x: lipsCenter.x - 20, y: lipsCenter.y - 11, width: 22, height: 7)),
                   with: .color(.white.opacity(0.45)))
            l.fill(Path(ellipseIn: CGRect(x: lipsCenter.x + 6, y: lipsCenter.y + 4, width: 12, height: 4)),
                   with: .color(.white.opacity(0.3)))
        }
    }

    /// Glitter flecks, each its own little shape and color, twinkling over time.
    static func glitter(_ strokes: [BeautyStroke], t: Double, in ctx: GraphicsContext) {
        var n = 0
        for s in strokes where s.tool == "glitter" {
            for p in s.points {
                n += 1
                fleck(at: p, index: n, color: s.color, t: t, scale: 1, in: ctx)
            }
        }
    }

    static func fleck(at p: CGPoint, index n: Int, color: String, t: Double, scale: CGFloat, in ctx: GraphicsContext) {
        let h = hash(n)
        let size = (1.6 + 1.8 * CGFloat(h & 0xFF) / 255) * scale
        let base = BeautyColors.rgb(color, n)
        let c = base.mix(Shades.white, Double((h >> 8) & 0x3F) / 255)
        let tw = t > 0 ? 0.55 + 0.45 * sin(t * (2.5 + Double((h >> 14) & 7)) + Double(n)) : 1
        var g = ctx
        g.opacity = tw
        let kind = (h >> 4) % 3
        if kind == 0 {
            g.fill(Path(ellipseIn: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size)), with: .color(c.color))
        } else {
            let r = size * (kind == 1 ? 0.9 : 0.6)
            var star = Path()
            for k in 0..<8 {
                let a = Double(k) * .pi / 4 + Double(h & 3)
                let rr = k % 2 == 0 ? r : r * 0.35
                let q = CGPoint(x: p.x + CGFloat(cos(a)) * rr, y: p.y + CGFloat(sin(a)) * rr)
                if k == 0 { star.move(to: q) } else { star.addLine(to: q) }
            }
            star.closeSubpath()
            g.fill(star, with: .color(c.color))
        }
        if tw > 0.85 {
            g.fill(Path(ellipseIn: CGRect(x: p.x - size * 0.2, y: p.y - size * 0.2, width: size * 0.4, height: size * 0.4)),
                   with: .color(.white))
        }
    }

    static func hash(_ n: Int) -> Int {
        var x = UInt32(truncatingIfNeeded: n &* 2654435761)
        x ^= x >> 15; x = x &* 2246822519; x ^= x >> 13
        return Int(x & 0x7FFFFFFF)
    }

    /// Four tiny painted fingertips at the bottom of each little doll hand.
    static func dollNails(_ look: Look, hands which: [Int], in ctx: GraphicsContext) {
        guard look.nails.contains(where: \.painted) else { return }
        for h in which {
            let c = hands[h]
            let side: CGFloat = h == 0 ? 1 : -1
            for (k, ang) in [62.0, 84.0, 106.0, 128.0].enumerated() {
                guard let nail = look.nails[safe: k + 1], nail.painted, let hex = nail.color else { continue }
                let a = (side > 0 ? ang : 180 - ang) * .pi / 180
                let p = CGPoint(x: c.x + CGFloat(cos(a)) * 13.5, y: c.y + CGFloat(sin(a)) * 13.5)
                var g = ctx
                g.translateBy(x: p.x, y: p.y)
                g.rotate(by: .radians(a + .pi / 2))
                let col = RGB(hex: hex)
                let r = CGRect(x: -2.6, y: -3.4, width: 5.2, height: 6.8)
                g.fill(Path(ellipseIn: r), with: .color(col.color))
                g.stroke(Path(ellipseIn: r), with: .color(Shades.outline(col).color.opacity(0.6)), lineWidth: 0.8)
                g.fill(Path(ellipseIn: CGRect(x: -1.4, y: -2.4, width: 1.3, height: 2.6)), with: .color(.white.opacity(0.7)))
                if nail.glitter || !nail.gems.isEmpty {
                    g.fill(Path(ellipseIn: CGRect(x: 0.4, y: 0.6, width: 1.4, height: 1.4)), with: .color(.white))
                }
            }
        }
    }
}

// MARK: - The close-up hand (nail studio)

/// A big hand, back up, fingers spread: in its own 600x720 space.
enum CloseHand {
    static let size = CGSize(width: 600, height: 720)

    struct Finger { let base: CGPoint; let tip: CGPoint; let width: CGFloat }

    static let fingers = [
        Finger(base: CGPoint(x: 212, y: 540), tip: CGPoint(x: 112, y: 392), width: 80),
        Finger(base: CGPoint(x: 244, y: 430), tip: CGPoint(x: 214, y: 168), width: 72),
        Finger(base: CGPoint(x: 306, y: 420), tip: CGPoint(x: 306, y: 122), width: 74),
        Finger(base: CGPoint(x: 368, y: 430), tip: CGPoint(x: 396, y: 168), width: 70),
        Finger(base: CGPoint(x: 424, y: 462), tip: CGPoint(x: 478, y: 264), width: 60),
    ]
    static let palm = CGRect(x: 172, y: 380, width: 290, height: 420)

    /// Maps nail coordinates (u -1...1 across, v 0...1 cuticle to tip) into hand space.
    static func nailTransform(_ i: Int) -> CGAffineTransform {
        let f = fingers[i]
        let dx = f.tip.x - f.base.x, dy = f.tip.y - f.base.y
        let len = max(1, sqrt(dx * dx + dy * dy))
        let dir = CGPoint(x: dx / len, y: dy / len)
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let nailLen = f.width * 1.02
        let half = f.width * 0.34
        let tipIn = f.width * 0.08
        let cuticle = CGPoint(x: f.tip.x - dir.x * (nailLen + tipIn), y: f.tip.y - dir.y * (nailLen + tipIn))
        // (u, v) -> cuticle + perp*u*half + dir*v*nailLen
        return CGAffineTransform(a: perp.x * half, b: perp.y * half, c: dir.x * nailLen, d: dir.y * nailLen,
                                 tx: cuticle.x, ty: cuticle.y)
    }

    /// The nail outline in nail coordinates.
    static let nailShape: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -1, y: 0.3))
        p.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: -1, y: 0.1), control2: CGPoint(x: -0.55, y: 0))
        p.addCurve(to: CGPoint(x: 1, y: 0.3), control1: CGPoint(x: 0.55, y: 0), control2: CGPoint(x: 1, y: 0.1))
        p.addLine(to: CGPoint(x: 1, y: 0.62))
        p.addCurve(to: CGPoint(x: 0, y: 1), control1: CGPoint(x: 1, y: 0.86), control2: CGPoint(x: 0.6, y: 1))
        p.addCurve(to: CGPoint(x: -1, y: 0.62), control1: CGPoint(x: -0.6, y: 1), control2: CGPoint(x: -1, y: 0.86))
        p.closeSubpath()
        return p
    }()

    static func nailPath(_ i: Int) -> Path { nailShape.applying(nailTransform(i)) }

    /// Hand space -> nail coordinates.
    static func toNail(_ i: Int, _ p: CGPoint) -> (u: Double, v: Double) {
        let q = p.applying(nailTransform(i).inverted())
        return (Double(q.x), Double(q.y))
    }

    static func fromNail(_ i: Int, u: Double, v: Double) -> CGPoint {
        CGPoint(x: u, y: v).applying(nailTransform(i))
    }

    /// The nail under `p` (with a little slack around it).
    static func nail(at p: CGPoint, slack: Double = 0.15) -> Int? {
        for i in fingers.indices {
            let (u, v) = toNail(i, p)
            if abs(u) <= 1 + slack, v >= -slack, v <= 1 + slack { return i }
        }
        return nil
    }

    static func skinPath() -> (fingers: [Path], palm: Path) {
        let fp = fingers.map { f -> Path in
            var p = Path()
            p.move(to: f.base)
            p.addLine(to: f.tip)
            return p
        }
        return (fp, Path(roundedRect: palm, cornerRadius: 120))
    }

    /// Whether `p` is on her skin (for spills and gems that miss a nail).
    static func onSkin(_ p: CGPoint) -> Bool {
        if Path(roundedRect: palm, cornerRadius: 120).contains(p) { return true }
        for f in fingers {
            let dx = f.tip.x - f.base.x, dy = f.tip.y - f.base.y
            let len2 = dx * dx + dy * dy
            let t = max(0, min(1, ((p.x - f.base.x) * dx + (p.y - f.base.y) * dy) / len2))
            let cx = f.base.x + dx * t, cy = f.base.y + dy * t
            if (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy) <= f.width * f.width / 4 { return true }
        }
        return false
    }

    static func drawHand(skin: RGB, in ctx: GraphicsContext) {
        let (fp, palmPath) = skinPath()
        let outline = Shades.outline(skin).color
        let lw: CGFloat = 6
        // outline pass, then skin pass, so fingers and palm merge into one hand
        ctx.fill(palmPath.strokedPath(StrokeStyle(lineWidth: lw * 2)), with: .color(outline))
        for (i, p) in fp.enumerated() {
            ctx.stroke(p, with: .color(outline), style: StrokeStyle(lineWidth: fingers[i].width + lw * 2, lineCap: .round))
        }
        ctx.fill(palmPath, with: .color(skin.color))
        for (i, p) in fp.enumerated() {
            ctx.stroke(p, with: .color(skin.color), style: StrokeStyle(lineWidth: fingers[i].width, lineCap: .round))
        }
        // soft shading down one side of each finger, and knuckle creases
        let shade = Shades.shade(skin).color
        for (i, f) in fingers.enumerated() {
            var g = ctx
            g.clip(to: fp[i].strokedPath(StrokeStyle(lineWidth: f.width, lineCap: .round)))
            g.stroke(fp[i].applying(CGAffineTransform(translationX: f.width * 0.32, y: 0)), with: .color(shade.opacity(0.45)),
                     style: StrokeStyle(lineWidth: f.width * 0.3, lineCap: .round))
            for k in [0.32, 0.55] where i > 0 || k == 0.32 {
                let c = CGPoint(x: f.base.x + (f.tip.x - f.base.x) * k, y: f.base.y + (f.tip.y - f.base.y) * k)
                var crease = Path()
                crease.move(to: CGPoint(x: c.x - f.width * 0.2, y: c.y + 2))
                crease.addQuadCurve(to: CGPoint(x: c.x + f.width * 0.2, y: c.y + 2), control: CGPoint(x: c.x, y: c.y - 5))
                ctx.stroke(crease, with: .color(outline.opacity(0.35)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        // bare nails
        for i in fingers.indices {
            let p = nailPath(i)
            ctx.fill(p, with: .color(skin.mix(RGB(1, 0.82, 0.86), 0.55).mix(Shades.white, 0.2).color))
            ctx.stroke(p, with: .color(outline.opacity(0.8)), lineWidth: 3)
            // the pale half moon at the base
            var g = ctx
            g.clip(to: p)
            let m = CloseHand.fromNail(i, u: 0, v: 0.05)
            let r = fingers[i].width * 0.22
            g.fill(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.35)))
        }
    }

    /// One finished or wet nail: its polish cells, gloss, glitter and gems.
    static func drawPolish(_ i: Int, cells: [Double], colors: [RGB], coats: Int, glitter: Bool, wet: Double,
                           gems: [NailGem], t: Double, in ctx: GraphicsContext) {
        let path = nailPath(i)
        let tr = nailTransform(i)
        let f = fingers[i]
        let cellR = f.width * 0.15
        var g = ctx
        g.clip(to: path)
        let hasPaint = cells.contains { $0 > 0.05 }
        if hasPaint {
            g.drawLayer { l in
                l.addFilter(.blur(radius: f.width * 0.035))
                for k in cells.indices where cells[k] > 0.05 {
                    let (u, v) = NailGrid.center(k)
                    let c = CGPoint(x: u, y: v).applying(tr)
                    let amount = min(1, cells[k])
                    let op = (coats >= 2 ? 0.98 : 0.82) * min(1, 0.35 + amount)
                    let r = cellR * CGFloat(0.85 + 0.35 * amount)
                    l.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                           with: .color(colors[k].color.opacity(op)))
                }
            }
            if glitter {
                for k in cells.indices where cells[k] > 0.3 {
                    for j in 0..<2 {
                        let h = BeautyPainter.hash(i * 1000 + k * 7 + j)
                        let (u, v) = NailGrid.center(k)
                        let jit = CGPoint(x: u + Double(h & 0xFF) / 255 * 0.2 - 0.1, y: v + Double((h >> 8) & 0xFF) / 255 * 0.07 - 0.035)
                        BeautyPainter.fleck(at: jit.applying(tr), index: h, color: j == 0 ? "#FFFFFF" : "rainbow", t: t, scale: 1.6, in: g)
                    }
                }
            }
            // gloss: a long highlight down one side, wobbling while wet
            let wob = wet > 0 ? 0.04 * sin(t * 5 + Double(i)) * wet : 0
            var hl = Path()
            hl.move(to: CGPoint(x: -0.52 + wob, y: 0.22).applying(tr))
            hl.addLine(to: CGPoint(x: -0.46 + wob, y: 0.78).applying(tr))
            var gl = g
            gl.blendMode = .screen
            gl.stroke(hl, with: .color(.white.opacity(0.45 + 0.3 * wet)), style: StrokeStyle(lineWidth: f.width * 0.09, lineCap: .round))
            let dot = CGPoint(x: 0.45, y: 0.3).applying(tr)
            gl.fill(Path(ellipseIn: CGRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6)), with: .color(.white.opacity(0.5 + 0.3 * wet)))
            if wet > 0.02 {
                // fresh polish looks thick and wet at the edges
                g.stroke(path, with: .color(.white.opacity(0.25 * wet)), lineWidth: 4)
            }
        }
        for gem in gems {
            let p = CGPoint(x: Double(gem.u), y: Double(gem.v)).applying(tr)
            drawGem(gem.kind, color: RGB(hex: gem.color), at: p, size: f.width * 0.3, turn: Double(gem.turn), t: t, in: ctx)
        }
    }

    /// A rhinestone, pearl or tiny sticker.
    static func drawGem(_ kind: String, color: RGB, at p: CGPoint, size s: CGFloat, turn: Double, t: Double, in ctx: GraphicsContext) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        g.rotate(by: .degrees(turn))
        let r = s / 2
        if kind.hasPrefix("s_") {
            let img = g.resolve(Image(systemName: String(kind.dropFirst(2))))
            var shadow = g
            shadow.opacity = 0.9
            var w = img
            w.shading = .color(.white)
            shadow.draw(w, in: CGRect(x: -r * 1.18, y: -r * 1.18, width: r * 2.36, height: r * 2.36))
            var col = img
            col.shading = .color(color.color)
            g.draw(col, in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
            return
        }
        let outline = Shades.outline(color).color
        let shape: Path
        switch kind {
        case "g_heart": shape = heart(r)
        case "g_star": shape = star(r)
        default: shape = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        }
        g.fill(shape.applying(CGAffineTransform(translationX: 1.5, y: 2.5)), with: .color(Theme.ink.opacity(0.18)))
        if kind == "g_pearl" {
            g.fill(shape, with: .radialGradient(Gradient(colors: [.white, color.mix(Shades.white, 0.5).color, color.mul(0.85, 0.82, 0.88).color]),
                                                center: CGPoint(x: -r * 0.35, y: -r * 0.35), startRadius: 0, endRadius: r * 1.5))
        } else {
            g.fill(shape, with: .linearGradient(Gradient(colors: [color.mix(Shades.white, 0.6).color, color.color, color.mul(0.6, 0.55, 0.7).color]),
                                                startPoint: CGPoint(x: -r, y: -r), endPoint: CGPoint(x: r, y: r)))
            // facets
            var fac = Path()
            for k in 0..<6 {
                let a = Double(k) * .pi / 3
                fac.move(to: .zero)
                fac.addLine(to: CGPoint(x: cos(a) * r * 0.8, y: sin(a) * r * 0.8))
            }
            var fg = g
            fg.clip(to: shape)
            fg.stroke(fac, with: .color(.white.opacity(0.35)), lineWidth: 1)
            fg.fill(Path(ellipseIn: CGRect(x: -r * 0.35, y: -r * 0.35, width: r * 0.7, height: r * 0.7)), with: .color(color.mix(Shades.white, 0.3).color.opacity(0.8)))
        }
        g.stroke(shape, with: .color(outline.opacity(0.7)), lineWidth: 1.2)
        // a glint that flashes now and then
        let flash = 0.5 + 0.5 * sin(t * 2.2 + Double(p.x) * 0.05)
        let gr = r * CGFloat(0.35 + 0.35 * flash)
        var glint = Path()
        glint.move(to: CGPoint(x: -r * 0.35, y: -r * 0.35 - gr)); glint.addLine(to: CGPoint(x: -r * 0.35, y: -r * 0.35 + gr))
        glint.move(to: CGPoint(x: -r * 0.35 - gr, y: -r * 0.35)); glint.addLine(to: CGPoint(x: -r * 0.35 + gr, y: -r * 0.35))
        g.stroke(glint, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    static func heart(_ r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r * 0.95))
        p.addCurve(to: CGPoint(x: -r, y: -r * 0.2), control1: CGPoint(x: -r * 0.5, y: r * 0.55), control2: CGPoint(x: -r, y: r * 0.25))
        p.addCurve(to: CGPoint(x: 0, y: -r * 0.45), control1: CGPoint(x: -r, y: -r * 0.85), control2: CGPoint(x: -r * 0.2, y: -r * 0.9))
        p.addCurve(to: CGPoint(x: r, y: -r * 0.2), control1: CGPoint(x: r * 0.2, y: -r * 0.9), control2: CGPoint(x: r, y: -r * 0.85))
        p.addCurve(to: CGPoint(x: 0, y: r * 0.95), control1: CGPoint(x: r, y: r * 0.25), control2: CGPoint(x: r * 0.5, y: r * 0.55))
        p.closeSubpath()
        return p
    }

    static func star(_ r: CGFloat) -> Path {
        var p = Path()
        for k in 0..<10 {
            let a = -Double.pi / 2 + Double(k) * .pi / 5
            let rr = k % 2 == 0 ? r : r * 0.45
            let q = CGPoint(x: cos(a) * rr, y: sin(a) * rr)
            if k == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}
