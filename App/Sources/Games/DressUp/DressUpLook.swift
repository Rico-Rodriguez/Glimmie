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
    /// The pet sitting at her feet, in its outfit (from the pet corner).
    var pet: PetLook?
    /// category id -> a color she mixed herself ("#RRGGBB"), used instead of `colors` for that item.
    var mixed: [String: String] = [:]
    /// Stickers and a frame on a gallery photo (the studio after the camera).
    var stickers: [PhotoSticker] = []
    var frame: String?
    /// What she painted in the makeup studio, and her nail polish (Beauty.swift).
    var makeup: [BeautyStroke] = []
    var nails: [NailPaint] = []

    static let maxStickers = 30
    static let maxMakeupPoints = 6000

    init() {}

    enum CodingKeys: String, CodingKey { case id, skin, hair, eye, picks, colors, patterns, bg, saved, pet, mixed, stickers, frame, makeup, nails }

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
        pet = try? c.decodeIfPresent(PetLook.self, forKey: .pet)
        mixed = (try? c.decodeIfPresent([String: String].self, forKey: .mixed)) ?? [:]
        stickers = (try? c.decodeIfPresent([PhotoSticker].self, forKey: .stickers)) ?? []
        frame = try? c.decodeIfPresent(String.self, forKey: .frame)
        makeup = (try? c.decodeIfPresent([BeautyStroke].self, forKey: .makeup)) ?? []
        nails = (try? c.decodeIfPresent([NailPaint].self, forKey: .nails)) ?? []
    }

    static var starter: Look {
        var l = Look()
        l.picks = ["hairBack": "hb_long", "hairFront": "hf_classic", "face": "face_round", "nose": "n_dot",
                   "eyes": "e_sparkle", "brows": "br_soft",
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
        // the little pets she used to hold now come from the pet corner
        if let h = l.picks["hold"], let kind = PetSave.legacy[h], art.items[h] == nil {
            l.picks["hold"] = nil
            if l.pet == nil { l.pet = PetLook(kind: kind) }
        }
        l.pet = l.pet?.sanitized(.shared, art)
        for (cat, item) in l.picks where art.items[item]?.category != cat { l.picks[cat] = nil }
        for c in art.categories where c.required && c.id != "skin" && c.id != "bg" && l.picks[c.id] == nil {
            l.picks[c.id] = Look.starter.picks[c.id] ?? c.items.first
        }
        if art.items[l.bg]?.category != "bg" { l.bg = art.category("bg")?.items.first ?? l.bg }
        l.colors = l.colors.mapValues { clamp($0, art.cloth.count) }
        l.patterns = l.patterns.filter { art.patterns[$0.value] != nil }
        l.mixed = l.mixed.filter { Look.isHex($0.value) && ($0.key == "hair" || $0.key == "eye" || art.category($0.key) != nil) }
        let unit = { (v: Double) in v.isFinite ? min(max(v, 0), 1) : 0.5 }
        l.stickers = Array(l.stickers.filter { Stickers.isKnown($0.kind) }.suffix(Look.maxStickers)).map { s in
            var s = s
            s.x = unit(s.x); s.y = unit(s.y)
            s.size = s.size.isFinite ? min(max(s.size, 0.08), 0.5) : 0.2
            s.turn = s.turn.isFinite ? s.turn.truncatingRemainder(dividingBy: 360) : 0
            return s
        }
        if let f = l.frame, !Stickers.frames.contains(f) { l.frame = nil }
        // makeup: known tools and colors, whole finite points, and not too many of them
        var budget = Look.maxMakeupPoints
        l.makeup = l.makeup.compactMap { st in
            guard BeautyStroke.tools.contains(st.tool), BeautyColors.isColor(st.color), budget > 0 else { return nil }
            var st = st
            if st.pts.count % 2 == 1 { st.pts.removeLast() }
            st.pts = st.pts.map { $0.isFinite ? min(max($0, -100), 1000) : 0 }
            if st.pts.count > budget { st.pts = Array(st.pts.prefix(budget - budget % 2)) }
            budget -= st.pts.count
            return st.pts.isEmpty ? nil : st
        }
        l.nails = Array(l.nails.prefix(5)).map { n in
            var n = n
            if let c = n.color, !Look.isHex(c) { n.color = nil }
            if !NailGrid.isMask(n.mask) { n.mask = "" }
            n.coats = min(max(n.coats, 0), 3)
            n.gems = Array(n.gems.filter { NailGem.isKnown($0.kind) && Look.isHex($0.color) }.prefix(6)).map { g in
                var g = g
                g.u = g.u.isFinite ? min(max(g.u, -1), 1) : 0
                g.v = g.v.isFinite ? min(max(g.v, 0), 1) : 0.5
                g.turn = g.turn.isFinite ? g.turn.truncatingRemainder(dividingBy: 360) : 0
                return g
            }
            return n
        }
        if l.nails.allSatisfy({ !$0.painted && $0.gems.isEmpty }) { l.nails = [] }
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

    static func isHex(_ s: String) -> Bool {
        s.count == 7 && s.hasPrefix("#") && UInt32(s.dropFirst(), radix: 16) != nil
    }

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
        case .hair: main = mixed["hair"].map(RGB.init(hex:)) ?? art.hair[safe: hair] ?? skinRGB
        case .eye: main = mixed["eye"].map(RGB.init(hex:)) ?? art.eye[safe: eye] ?? skinRGB
        case .skin: main = skinRGB
        case .own, .noColor:
            if item.colorSource == .own, let hex = mixed[item.category] {
                main = RGB(hex: hex)
            } else {
                main = art.cloth[safe: colors[item.category] ?? item.defaultColor] ?? Shades.white
            }
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
        for c in ["hairBack", "hairFront", "face", "nose", "eyes", "brows", "mouth", "cheeks"] { l.picks[c] = pick(c) }
        if Bool.random() {
            l.picks["dress"] = pick("dress")
        } else {
            l.picks["top"] = pick("top"); l.picks["bottom"] = pick("bottom")
        }
        let chances: [(String, Double)] = [("shoes", 0.95), ("socks", 0.6), ("hat", 0.6), ("glasses", 0.15),
                                            ("neck", 0.3), ("back", 0.25), ("hold", 0.35), ("outer", 0.15),
                                            ("makeup", 0.25), ("earrings", 0.3)]
        for (c, p) in chances where Double.random(in: 0..<1) < p { l.picks[c] = pick(c) }
        for c in ["dress", "top", "bottom", "outer", "socks", "shoes", "hat", "glasses", "neck", "back", "hold", "makeup", "earrings"] {
            l.colors[c] = Int.random(in: 0..<max(1, art.cloth.count))
            if Double.random(in: 0..<1) < 0.3 { l.patterns[c] = art.patternNames.randomElement() }
        }
        l.bg = pick("bg") ?? l.bg
        if Double.random(in: 0..<1) < 0.3, let kind = PetArt.shared.order.randomElement() {
            l.pet = PetLook.random(kind: kind, .shared, art)
        }
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
    /// Colors she mixed, newest first (at most 12).
    @Published var mixes: [String] { didSet { GameStorage.save(mixes, game: Self.game, file: "mixes.json") } }

    private var pending: DispatchWorkItem?

    init() {
        let art = DressUpArt.shared
        current = (GameStorage.load(Look.self, game: Self.game, file: "current.json") ?? .starter).sanitized(art)
        gallery = (GameStorage.load([Look].self, game: Self.game, file: "gallery.json") ?? []).map { $0.sanitized(art) }
        mixes = (GameStorage.load([String].self, game: Self.game, file: "mixes.json") ?? []).filter(Look.isHex)
    }

    private func scheduleSave() {
        pending?.cancel()
        let look = current
        let w = DispatchWorkItem { GameStorage.save(look, game: Self.game, file: "current.json") }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }

    @discardableResult func saveToGallery() -> Look {
        var l = current
        l.id = UUID()
        l.saved = Date()
        l.stickers = []
        l.frame = nil
        gallery.insert(l, at: 0)
        if gallery.count > Self.maxSaved { gallery.removeLast(gallery.count - Self.maxSaved) }
        GameStorage.save(gallery, game: Self.game, file: "gallery.json")
        return l
    }

    /// Puts a decorated photo back in its place in the gallery.
    func update(_ look: Look) {
        guard let i = gallery.firstIndex(where: { $0.id == look.id }) else { return }
        gallery[i] = look
        GameStorage.save(gallery, game: Self.game, file: "gallery.json")
    }

    func delete(_ look: Look) {
        gallery.removeAll { $0.id == look.id }
        GameStorage.save(gallery, game: Self.game, file: "gallery.json")
    }

    func open(_ look: Look) {
        var l = look
        l.id = current.id
        l.stickers = []
        l.frame = nil
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
    static func layers(_ look: Look, _ expression: Expression, art: DressUpArt = .shared) -> [(ArtLayer, PaintSet, ArtItem)] {
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
        var out: [(Int, Int, ArtLayer, PaintSet, ArtItem)] = []
        for (n, id) in ids.sorted().enumerated() {
            guard let item = art.items[id] else { continue }
            let p = look.paints(for: item, art)
            for L in item.layers { out.append((L.z, n, L, p, item)) }
        }
        out.sort { ($0.0, $0.1) < ($1.0, $1.1) }
        return out.map { ($0.2, $0.3, $0.4) }
    }

    static func paintDoll(_ look: Look, _ expression: Expression, box: CGRect? = nil, in ctx: inout GraphicsContext, size: CGSize,
                          t: Double = 0) {
        let art = DressUpArt.shared
        ArtPainter.fit(&ctx, box: box ?? CGRect(origin: .zero, size: art.dollSize), into: size)
        BeautyPainter.interleave(layers(look, expression, art: art), z: { $0.0.z }, look: look, t: t, in: ctx) { l in
            ArtPainter.draw(l.0.shapes, l.1, in: ctx)
        }
        if let pet = look.pet { PetPainter.drawCompanion(pet, in: ctx) }
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
