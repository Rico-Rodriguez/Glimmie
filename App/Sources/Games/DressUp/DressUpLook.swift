import SwiftUI

// MARK: - A look (what the doll is wearing)
//
// Saved on her iPad (Application Support/Games/dressup/). Every update must still load old saves:
// only add fields, give them defaults in `init(from:)`, never rename one.

struct Look: Codable, Equatable, Identifiable {
    var id = UUID()
    var skin = 1
    var hair = 3
    var eye = 6
    /// category id -> item id. A missing optional category means nothing is worn there.
    var picks: [String: String] = [:]
    /// category id -> cloth palette index, for items colored by the player.
    var colors: [String: Int] = [:]
    /// category id -> fabric pattern name.
    var patterns: [String: String] = [:]
    var bg = "bg_bedroom"
    var saved = Date()

    init() {}

    enum CodingKeys: String, CodingKey { case id, skin, hair, eye, picks, colors, patterns, bg, saved }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Look()
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        skin = (try? c.decodeIfPresent(Int.self, forKey: .skin)) ?? d.skin
        hair = (try? c.decodeIfPresent(Int.self, forKey: .hair)) ?? d.hair
        eye = (try? c.decodeIfPresent(Int.self, forKey: .eye)) ?? d.eye
        picks = (try? c.decodeIfPresent([String: String].self, forKey: .picks)) ?? [:]
        colors = (try? c.decodeIfPresent([String: Int].self, forKey: .colors)) ?? [:]
        patterns = (try? c.decodeIfPresent([String: String].self, forKey: .patterns)) ?? [:]
        bg = (try? c.decodeIfPresent(String.self, forKey: .bg)) ?? d.bg
        saved = (try? c.decodeIfPresent(Date.self, forKey: .saved)) ?? Date()
    }

    static var starter: Look {
        var l = Look()
        l.picks = ["hairBack": "hb_long", "hairFront": "hf_classic", "eyes": "e_sparkle", "brows": "br_soft",
                   "mouth": "m_smile", "cheeks": "b_soft", "dress": "d_princess", "shoes": "sh_maryjane",
                   "socks": "s_frilly", "hat": "h_twobows"]
        l.bg = "bg_bedroom"
        return l
    }

    /// Drops anything this build doesn't know, and fills required categories.
    func sanitized(_ art: DressUpArt = .shared) -> Look {
        var l = self
        let clamp = { (v: Int, n: Int) in n == 0 ? 0 : min(max(v, 0), n - 1) }
        l.skin = clamp(l.skin, art.skin.count)
        l.hair = clamp(l.hair, art.hair.count)
        l.eye = clamp(l.eye, art.eye.count)
        for (cat, item) in l.picks where art.items[item]?.category != cat { l.picks[cat] = nil }
        for c in art.categories where c.required && c.id != "skin" && c.id != "bg" && l.picks[c.id] == nil {
            l.picks[c.id] = Look.starter.picks[c.id] ?? c.items.first
        }
        if art.items[l.bg]?.category != "bg" { l.bg = art.category("bg")?.items.first ?? l.bg }
        l.colors = l.colors.mapValues { clamp($0, art.cloth.count) }
        l.patterns = l.patterns.filter { art.patterns[$0.value] != nil }
        return l
    }

    // MARK: Changing it

    mutating func wear(_ itemID: String, in cat: String) {
        if cat == "bg" { bg = itemID; return }
        picks[cat] = itemID
        // a dress replaces a top and bottom, and the other way round
        if cat == "dress" { picks["top"] = nil; picks["bottom"] = nil }
        if cat == "top" || cat == "bottom" { picks["dress"] = nil }
    }

    mutating func takeOff(_ cat: String) { picks[cat] = nil }

    /// The palette index currently used for an item's main color.
    func colorIndex(for item: ArtItem) -> Int {
        switch item.colorSource {
        case .hair: return hair
        case .eye: return eye
        case .skin: return skin
        case .own, .noColor: return colors[item.category] ?? item.defaultColor
        }
    }

    func paints(for item: ArtItem, _ art: DressUpArt = .shared) -> PaintSet {
        let skinRGB = art.skin[safe: skin] ?? RGB(1, 0.86, 0.8)
        let main: RGB
        switch item.colorSource {
        case .hair: main = art.hair[safe: hair] ?? skinRGB
        case .eye: main = art.eye[safe: eye] ?? skinRGB
        case .skin: main = skinRGB
        case .own, .noColor: main = art.cloth[safe: colors[item.category] ?? item.defaultColor] ?? Shades.white
        }
        let pattern = item.patternable ? patterns[item.category] : nil
        return PaintSet(main: main, accent: item.accent, skin: skinRGB, pattern: pattern)
    }

    // MARK: Surprise me

    static func random(_ art: DressUpArt = .shared) -> Look {
        var l = Look()
        func pick(_ cat: String) -> String? { art.category(cat)?.items.randomElement() }
        l.skin = Int.random(in: 0..<max(1, art.skin.count))
        l.hair = Int.random(in: 0..<max(1, art.hair.count))
        l.eye = Int.random(in: 0..<max(1, art.eye.count))
        for c in ["hairBack", "hairFront", "eyes", "brows", "mouth", "cheeks"] { l.picks[c] = pick(c) }
        if Bool.random() {
            l.picks["dress"] = pick("dress")
        } else {
            l.picks["top"] = pick("top"); l.picks["bottom"] = pick("bottom")
        }
        let chances: [(String, Double)] = [("shoes", 0.95), ("socks", 0.6), ("hat", 0.6), ("glasses", 0.15),
                                            ("neck", 0.3), ("back", 0.25), ("hold", 0.35), ("outer", 0.15)]
        for (c, p) in chances where Double.random(in: 0..<1) < p { l.picks[c] = pick(c) }
        for c in ["dress", "top", "bottom", "outer", "socks", "shoes", "hat", "glasses", "neck", "back", "hold"] {
            l.colors[c] = Int.random(in: 0..<max(1, art.cloth.count))
            if Double.random(in: 0..<1) < 0.3 { l.patterns[c] = art.patternNames.randomElement() }
        }
        l.bg = pick("bg") ?? l.bg
        return l
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - Saving

final class LookStore: ObservableObject {
    static let game = "dressup"
    static let maxSaved = 60

    @Published var current: Look { didSet { scheduleSave() } }
    @Published private(set) var gallery: [Look]

    private var pending: DispatchWorkItem?

    init() {
        let art = DressUpArt.shared
        current = (GameStorage.load(Look.self, game: Self.game, file: "current.json") ?? .starter).sanitized(art)
        gallery = (GameStorage.load([Look].self, game: Self.game, file: "gallery.json") ?? []).map { $0.sanitized(art) }
    }

    private func scheduleSave() {
        pending?.cancel()
        let look = current
        let w = DispatchWorkItem { GameStorage.save(look, game: Self.game, file: "current.json") }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    func saveToGallery() {
        var l = current
        l.id = UUID()
        l.saved = Date()
        gallery.insert(l, at: 0)
        if gallery.count > Self.maxSaved { gallery.removeLast(gallery.count - Self.maxSaved) }
        GameStorage.save(gallery, game: Self.game, file: "gallery.json")
    }

    func delete(_ look: Look) {
        gallery.removeAll { $0.id == look.id }
        GameStorage.save(gallery, game: Self.game, file: "gallery.json")
    }

    func open(_ look: Look) {
        var l = look
        l.id = current.id
        current = l
    }

    func flush() {
        pending?.perform()
        pending = nil
    }
}

// MARK: - Drawing a look

enum Expression { case normal, blink, happy }

enum DollPainter {
    /// Every layer of the look, back to front.
    static func layers(_ look: Look, _ expression: Expression, art: DressUpArt = .shared) -> [(ArtLayer, PaintSet)] {
        var ids = ["body", "under"]
        for (cat, id) in look.picks where cat != "bg" {
            if cat == "eyes" && expression != .normal { continue }
            if cat == "mouth" && expression == .happy { continue }
            ids.append(id)
        }
        switch expression {
        case .normal: break
        case .blink: ids.append("eyes_closed")
        case .happy: ids.append("eyes_happy"); ids.append("m_open")
        }
        var out: [(Int, Int, ArtLayer, PaintSet)] = []
        for (n, id) in ids.sorted().enumerated() {
            guard let item = art.items[id] else { continue }
            let p = look.paints(for: item, art)
            for L in item.layers { out.append((L.z, n, L, p)) }
        }
        out.sort { ($0.0, $0.1) < ($1.0, $1.1) }
        return out.map { ($0.2, $0.3) }
    }

    static func paintDoll(_ look: Look, _ expression: Expression, box: CGRect? = nil, in ctx: inout GraphicsContext, size: CGSize) {
        let art = DressUpArt.shared
        ArtPainter.fit(&ctx, box: box ?? CGRect(origin: .zero, size: art.dollSize), into: size)
        for (layer, p) in layers(look, expression, art: art) {
            ArtPainter.draw(layer.shapes, p, in: ctx)
        }
    }

    static func paintScene(_ id: String, in ctx: inout GraphicsContext, size: CGSize) {
        let art = DressUpArt.shared
        guard let item = art.items[id] else { return }
        ArtPainter.fit(&ctx, box: CGRect(origin: .zero, size: art.sceneSize), into: size, fill: true)
        let p = PaintSet(main: Shades.white, accent: Shades.white, skin: Shades.white, pattern: nil)
        for L in item.layers { ArtPainter.draw(L.shapes, p, in: ctx) }
    }

    /// One item on its own, framed by its thumbnail box (with a bare head under face items).
    static func paintItem(_ id: String, look: Look, in ctx: inout GraphicsContext, size: CGSize) {
        let art = DressUpArt.shared
        guard let item = art.items[id] else { return }
        if item.category == "bg" { paintScene(id, in: &ctx, size: size); return }
        ArtPainter.fit(&ctx, box: item.thumb, into: size)
        let p = look.paints(for: item, art)
        if item.onHead {
            ArtPainter.draw([art.head], p, in: ctx)
        }
        for L in item.layers.sorted(by: { $0.z < $1.z }) { ArtPainter.draw(L.shapes, p, in: ctx) }
        if item.category == "hairBack" {
            // the back hair sits behind her head; show the head so the thumbnail reads as a hairstyle
            ArtPainter.draw([art.head], p, in: ctx)
        }
    }
}

struct DollView: View {
    let look: Look
    var expression: Expression = .normal
    /// Part of the doll to show, in art coordinates (nil = all of her).
    var box: CGRect? = nil

    var body: some View {
        Canvas { ctx, size in
            DollPainter.paintDoll(look, expression, box: box, in: &ctx, size: size)
        }
    }
}

struct SceneView: View {
    let bg: String
    var body: some View {
        Canvas { ctx, size in DollPainter.paintScene(bg, in: &ctx, size: size) }
    }
}

struct ItemThumb: View {
    let item: String
    let look: Look
    var body: some View {
        Canvas { ctx, size in DollPainter.paintItem(item, look: look, in: &ctx, size: size) }
    }
}
