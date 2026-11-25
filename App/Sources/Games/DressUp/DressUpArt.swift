import SwiftUI

// MARK: - Dress-up art
//
// Dress-up vector art lives in App/Resources/Games/DressUp/dressup.json plus procedural outfits
// in DressUpOutfits.swift. Each shape names colors by role ("c" = item color, "a" = accent,
// "skin" = skin tone, with ".s" shade, ".l" light, ".d" deep, ".o" outline) or fixed "#RRGGBB".
// `Shades` matches tools/dressup/colors.py exactly.

struct RGB: Equatable {
    var r, g, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt32(s.prefix(6), radix: 16) ?? 0xFF00FF
        self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    func mix(_ o: RGB, _ t: Double) -> RGB { RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t) }
    func mul(_ a: Double, _ b2: Double, _ c: Double) -> RGB { RGB(r * a, g * b2, b * c) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var luminance: Double { 0.3 * r + 0.59 * g + 0.11 * b }

    var hexInt: Int {
        let ri = Int((max(0, min(1, r)) * 255).rounded())
        let gi = Int((max(0, min(1, g)) * 255).rounded())
        let bi = Int((max(0, min(1, b)) * 255).rounded())
        return (ri << 16) | (gi << 8) | bi
    }

    var hexString: String {
        String(format: "#%06X", hexInt)
    }
}

enum Shades {
    static let ink = RGB(hex: "#4A2C40")
    static let white = RGB(1, 1, 1)
    static func shade(_ c: RGB) -> RGB { c.mul(0.86, 0.78, 0.90) }
    static func light(_ c: RGB) -> RGB { c.mix(white, 0.55) }
    static func deep(_ c: RGB) -> RGB { c.mul(0.62, 0.52, 0.68) }
    static func outline(_ c: RGB) -> RGB { c.mul(0.56, 0.42, 0.56).mix(ink, 0.35) }
    /// The color a fabric pattern is drawn in, on top of `c`.
    static func pattern(_ c: RGB) -> RGB { c.luminance < 0.8 ? c.mix(white, 0.7) : c.mix(RGB(0.85, 0.45, 0.65), 0.35) }
}

/// One color reference in a shape.
enum Paint {
    enum Slot { case main, accent, skin }
    enum Tone { case base, shade, light, deep, outline }
    case fixed(RGB)
    case slot(Slot, Tone)

    init?(_ s: String?) {
        guard let s, !s.isEmpty else { return nil }
        if s.hasPrefix("#") { self = .fixed(RGB(hex: s)); return }
        let parts = s.split(separator: ".")
        let slot: Slot
        switch parts[0] {
        case "c": slot = .main
        case "a": slot = .accent
        case "skin": slot = .skin
        default: return nil
        }
        var tone = Tone.base
        if parts.count > 1 {
            switch parts[1] {
            case "s": tone = .shade
            case "l": tone = .light
            case "d": tone = .deep
            case "o": tone = .outline
            default: break
            }
        }
        self = .slot(slot, tone)
    }

    func resolve(_ p: PaintSet) -> RGB {
        switch self {
        case .fixed(let c): return c
        case .slot(let slot, let tone):
            let base: RGB
            switch slot {
            case .main: base = p.main
            case .accent: base = p.accent
            case .skin: base = p.skin
            }
            switch tone {
            case .base: return base
            case .shade: return Shades.shade(base)
            case .light: return Shades.light(base)
            case .deep: return Shades.deep(base)
            case .outline: return Shades.outline(base)
            }
        }
    }
}

/// The colors one item is drawn with.
struct PaintSet {
    var main: RGB
    var accent: RGB
    var skin: RGB
    var pattern: String?
}

struct ArtShape {
    let path: Path
    let bounds: CGRect
    let fill: Paint?
    let gradient: (Paint, Paint)?
    let stroke: Paint?
    let width: CGFloat
    let opacity: Double
    let patterned: Bool
}

struct ArtLayer {
    let z: Int
    let shapes: [ArtShape]
}

struct ArtItem: Identifiable {
    enum ColorSource: String { case own, hair, eye, skin, noColor = "none" }
    let id: String
    let category: String
    let colorSource: ColorSource
    let defaultColor: Int
    let accent: RGB
    let patternable: Bool
    let layers: [ArtLayer]
    let thumb: CGRect
    let onHead: Bool
}

struct ArtCategory: Identifiable {
    static let treasureItems = [
        "h_moonband": "dressup/h_moonband",
        "h_hanbokCrown": "dressup/h_hanbokCrown",
        "p_fairyWand": "dressup/p_fairyWand",
    ]
    let id: String
    let group: String
    let required: Bool
    /// "skin", "hair", "eye", "cloth" or nil: which swatches the tray shows for this category.
    let palette: String?
    let icon: String?
    let items: [String]

    var availableItems: [String] {
        items.filter { Self.treasureItems[$0].map { Coins.shared.owns($0) } ?? true }
    }
}

// MARK: - Shared single-decode dressup.json cache

/// Loads and JSON-decodes `dressup.json` once, sharing the parsed tree between `DressUpArt` and `PetArt`
/// and releasing the raw intermediate tree once both singletons have consumed it.
enum DressUpBundle {
    private static let lock = NSLock()
    private static var cached: RawDressUpFile?
    private static var dressUpConsumed = false
    private static var petsConsumed = false
    private static var decodeCountStorage = 0

    static var decodeCount: Int {
        lock.lock(); defer { lock.unlock() }
        return decodeCountStorage
    }

    static func takeForDressUp() -> RawDressUpFile? {
        lock.lock(); defer { lock.unlock() }
        let file = loadLocked()
        dressUpConsumed = true
        if dressUpConsumed && petsConsumed { cached = nil }
        return file
    }

    static func takeForPets() -> PetRawFile? {
        lock.lock(); defer { lock.unlock() }
        let pets = loadLocked()?.pets
        petsConsumed = true
        if dressUpConsumed && petsConsumed { cached = nil }
        return pets
    }

    private static func loadLocked() -> RawDressUpFile? {
        if let existing = cached { return existing }
        guard let url = GameFiles.url("dressup", "json", game: "DressUp"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RawDressUpFile.self, from: data) else {
            return nil
        }
        decodeCountStorage += 1
        cached = decoded
        return decoded
    }
}

// MARK: - Procedural fabric patterns

/// Generates the 7 Dress Up fabric patterns procedurally so `dressup.json` doesn't ship 700 KB of repeated SVG paths.
enum DressUpPatterns {
    static let orderedNames = ["dots", "stripes", "hearts", "stars", "checks", "flowers", "tinydots"]
    private static let proceduralSet = Set(orderedNames)

    static func isProcedural(_ name: String) -> Bool {
        proceduralSet.contains(name)
    }

    /// Full 600x900 canvas path for swatches and legacy callers.
    static func path(for name: String) -> Path {
        path(for: name, in: CGRect(x: -10, y: -10, width: 620, height: 920))
    }

    /// Builds only the pattern shapes overlapping `bounds`, preserving global `(0, 0)` alignment across sway bands.
    static func path(for name: String, in bounds: CGRect) -> Path {
        var p = Path()
        guard !bounds.isNull, !bounds.isEmpty else { return p }
        switch name {
        case "dots":
            addStaggeredGrid(stepX: 36, stepY: 32, maxCols: 20, maxRows: 30, pad: 7, in: bounds) { x, y in
                p.addEllipse(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12))
            }
        case "tinydots":
            addStaggeredGrid(stepX: 18, stepY: 16, maxCols: 40, maxRows: 60, pad: 3.5, in: bounds) { x, y in
                p.addEllipse(in: CGRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2))
            }
        case "stripes":
            for i in 0..<40 {
                let x = CGFloat(i * 28 - 300)
                // Diagonal stripe spans x .. x+612 across y = 0..900
                let minStripeX = x + (bounds.minY / 900) * 600
                let maxStripeX = x + 12 + (bounds.maxY / 900) * 600
                guard maxStripeX >= bounds.minX && minStripeX <= bounds.maxX else { continue }
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + 12, y: 0))
                p.addLine(to: CGPoint(x: x + 612, y: 900))
                p.addLine(to: CGPoint(x: x + 600, y: 900))
                p.closeSubpath()
            }
        case "checks":
            let firstCol = max(0, Int(floor((bounds.minX - 13) / 30)))
            let lastCol = min(23, Int(ceil(bounds.maxX / 30)))
            if firstCol <= lastCol {
                for i in firstCol...lastCol {
                    p.addRect(CGRect(x: CGFloat(i * 30), y: 0, width: 13, height: 900))
                }
            }
            let firstRow = max(0, Int(floor((bounds.minY - 13) / 30)))
            let lastRow = min(33, Int(ceil(bounds.maxY / 30)))
            if firstRow <= lastRow {
                for j in firstRow...lastRow {
                    p.addRect(CGRect(x: 0, y: CGFloat(j * 30), width: 600, height: 13))
                }
            }
        case "hearts":
            addStaggeredGrid(stepX: 50, stepY: 44, maxCols: 13, maxRows: 22, pad: 11, in: bounds) { x, y in
                p.addPath(DressUpCulturalOutfits.heartPath(center: CGPoint(x: x, y: y), halfWidth: 9))
            }
        case "stars":
            addStaggeredGrid(stepX: 50, stepY: 44, maxCols: 13, maxRows: 22, pad: 12, in: bounds) { x, y in
                p.addPath(DressUpCulturalOutfits.starPath(center: CGPoint(x: x, y: y), outer: 10, inner: 5))
            }
        case "flowers":
            addStaggeredGrid(stepX: 52, stepY: 46, maxCols: 13, maxRows: 22, pad: 15, in: bounds) { x, y in
                p.addPath(DressUpCulturalOutfits.flowerPath(center: CGPoint(x: x, y: y), radius: 13, petals: 5))
            }
        default:
            break
        }
        return p
    }

    static func fill(_ name: String, in bounds: CGRect, color: Color, into ctx: inout GraphicsContext) {
        let p = path(for: name, in: bounds)
        guard !p.isEmpty else { return }
        ctx.fill(p, with: .color(color))
    }

    private static func addStaggeredGrid(
        stepX: CGFloat,
        stepY: CGFloat,
        maxCols: Int,
        maxRows: Int,
        pad: CGFloat,
        in bounds: CGRect,
        emit: (CGFloat, CGFloat) -> Void
    ) {
        let minRow = max(0, Int(floor((bounds.minY - pad) / stepY)))
        let maxRow = min(maxRows - 1, Int(ceil((bounds.maxY + pad) / stepY)))
        guard minRow <= maxRow else { return }
        for row in minRow...maxRow {
            let offsetX: CGFloat = row % 2 == 1 ? stepX * 0.5 : 0
            let minCol = max(0, Int(floor((bounds.minX - pad - offsetX) / stepX)))
            let maxCol = min(maxCols - 1, Int(ceil((bounds.maxX + pad - offsetX) / stepX)))
            guard minCol <= maxCol else { continue }
            let y = CGFloat(row) * stepY
            for col in minCol...maxCol {
                let x = CGFloat(col) * stepX + offsetX
                emit(x, y)
            }
        }
    }
}

final class DressUpArt {
    static let shared = DressUpArt()

    let dollSize: CGSize
    let sceneSize: CGSize
    let head: ArtShape
    let skin: [RGB], hair: [RGB], eye: [RGB], cloth: [RGB]
    let patterns: [String: Path]
    let patternNames: [String]
    let categories: [ArtCategory]
    let items: [String: ArtItem]

    func category(_ id: String) -> ArtCategory? { categories.first { $0.id == id } }

    private init() {
        let file = DressUpBundle.takeForDressUp()
        guard let f = file else {
            dollSize = CGSize(width: 600, height: 900); sceneSize = CGSize(width: 1200, height: 900)
            head = DressUpArt.shape(RawShape(d: "", f: nil, s: nil, w: nil, o: nil, g: nil, pat: nil))
            skin = [RGB(1, 0.86, 0.8)]; hair = [RGB(0.4, 0.3, 0.2)]; eye = [RGB(0.3, 0.5, 0.9)]; cloth = [RGB(1, 0.6, 0.75)]
            patterns = [:]; patternNames = []; categories = []; items = [:]
            return
        }
        dollSize = CGSize(width: f.doll[0], height: f.doll[1])
        sceneSize = CGSize(width: f.scene[0], height: f.scene[1])
        head = DressUpArt.shape(f.head)
        skin = (f.palettes["skin"] ?? []).map { RGB(hex: $0) }
        hair = (f.palettes["hair"] ?? []).map { RGB(hex: $0) }
        eye = (f.palettes["eye"] ?? []).map { RGB(hex: $0) }
        cloth = (f.palettes["cloth"] ?? []).map { RGB(hex: $0) }

        var builtPatterns: [String: Path] = [:]
        for (name, raw) in f.patterns {
            if raw.isEmpty || raw.hasPrefix("procedural:") {
                let key = raw.hasPrefix("procedural:") ? String(raw.dropFirst("procedural:".count)) : name
                builtPatterns[name] = DressUpPatterns.path(for: key)
            } else {
                builtPatterns[name] = PathParser.parse(raw)
            }
        }
        patterns = builtPatterns
        patternNames = DressUpPatterns.orderedNames.filter { builtPatterns[$0] != nil }

        var all: [String: ArtItem] = [:]
        for (id, r) in f.items {
            let t = r.thumb ?? [0, 0, 600, 900]
            all[id] = ArtItem(
                id: id, category: r.cat,
                colorSource: ArtItem.ColorSource(rawValue: r.color ?? "none") ?? .noColor,
                defaultColor: r.defaultColor ?? 0,
                accent: RGB(hex: r.accent ?? "#FFFFFF"),
                patternable: r.patternable ?? false,
                layers: r.layers.map { ArtLayer(z: $0.z, shapes: $0.shapes.map(DressUpArt.shape)) },
                thumb: CGRect(x: t[0], y: t[1], width: t[2], height: t.count > 3 ? t[3] : t[2]),
                onHead: r.head ?? false)
        }

        // Register procedural Hanbok and Heart-Jewel Fairy wardrobe pieces.
        var extrasByCategory: [String: [String]] = [:]
        for extra in DressUpCulturalOutfits.items {
            all[extra.id] = extra
            extrasByCategory[extra.category, default: []].append(extra.id)
        }

        categories = f.categories.map { raw in
            let extraIDs = extrasByCategory[raw.id] ?? []
            let existing = raw.items.filter { !extraIDs.contains($0) }
            return ArtCategory(
                id: raw.id,
                group: raw.group,
                required: raw.required,
                palette: raw.palette,
                icon: raw.icon,
                items: extraIDs + existing
            )
        }
        items = all
    }

    private static func shape(_ r: RawShape) -> ArtShape {
        let path = PathParser.parse(r.d)
        var grad: (Paint, Paint)?
        if let g = r.g, g.count == 2, let a = Paint(g[0]), let b = Paint(g[1]) { grad = (a, b) }
        return ArtShape(path: path, bounds: path.boundingRect, fill: Paint(r.f), gradient: grad, stroke: Paint(r.s),
                        width: CGFloat(r.w ?? 4), opacity: r.o ?? 1, patterned: (r.pat ?? 0) != 0)
    }
}

// MARK: JSON

struct RawShape: Decodable {
    let d: String
    let f: String?
    let s: String?
    let w: Double?
    let o: Double?
    let g: [String]?
    let pat: Int?
}

struct RawLayer: Decodable {
    let z: Int
    let shapes: [RawShape]
}

struct RawItem: Decodable {
    let cat: String
    let layers: [RawLayer]
    let color: String?
    let defaultColor: Int?
    let accent: String?
    let patternable: Bool?
    let thumb: [Double]?
    let head: Bool?

    enum CodingKeys: String, CodingKey {
        case cat, layers, color, accent, patternable, thumb, head
        case defaultColor = "default"
    }
}

struct RawCategory: Decodable {
    let id: String
    let group: String
    let required: Bool
    let palette: String?
    let icon: String?
    let items: [String]
}

struct PetRawShape: Decodable {
    let d: String
    let f: String?
    let s: String?
    let w: Double?
    let o: Double?
    let pat: Int?
}

struct PetRawAnchors: Decodable {
    let hat: [Double]
    let eyes: [Double]
    let wide: Double
}

struct PetRawAnimal: Decodable {
    let back, torso, limbs, head, front, blush, brows: [PetRawShape]
    let eyes: [String: [PetRawShape]]
    let mouths: [String: [PetRawShape]]
    let eye: [Double]
    let mouth: [Double]
    let fur: String
    let anchors: PetRawAnchors
}

struct PetRawWear: Decodable {
    let slot: String
    let shapes: [PetRawShape]
    let defaultColor: Int?
    let accent: String?
    let patternable: Bool?

    enum CodingKeys: String, CodingKey {
        case slot, shapes, accent, patternable
        case defaultColor = "default"
    }
}

struct PetRawFile: Decodable {
    let size: [Double]
    let order: [String]
    let animals: [String: PetRawAnimal]
    let wear: [String: PetRawWear]
    let slots: [String]
    let thumbs: [String: [Double]]
    let props: [String: [PetRawShape]]
}

struct RawDressUpFile: Decodable {
    let doll: [Double]
    let scene: [Double]
    let head: RawShape
    let palettes: [String: [String]]
    let patterns: [String: String]
    let categories: [RawCategory]
    let items: [String: RawItem]
    let pets: PetRawFile?
}

/// Parses the absolute M/L/C/Z paths that tools/dressup writes.
enum PathParser {
    static func parse(_ s: String) -> Path {
        var p = Path()
        let b = Array(s.utf8)
        var i = 0
        func skip() { while i < b.count && (b[i] == 32 || b[i] == 44) { i += 1 } }
        func num() -> CGFloat {
            skip()
            let start = i
            if i < b.count && b[i] == 45 { i += 1 }
            while i < b.count && ((b[i] >= 48 && b[i] <= 57) || b[i] == 46) { i += 1 }
            guard i > start else { return 0 }
            return CGFloat(Double(String(decoding: b[start..<i], as: UTF8.self)) ?? 0)
        }
        func pt() -> CGPoint { let x = num(); let y = num(); return CGPoint(x: x, y: y) }
        var open = false
        while true {
            skip()
            guard i < b.count else { break }
            let c = b[i]
            i += 1
            switch c {
            case 77: // M
                p.move(to: pt()); open = true
            case 76: // L
                let q = pt()
                if open { p.addLine(to: q) } else { p.move(to: q); open = true }
            case 67: // C
                let c1 = pt(), c2 = pt(), q = pt()
                if open { p.addCurve(to: q, control1: c1, control2: c2) } else { p.move(to: q); open = true }
            case 90: // Z
                if open { p.closeSubpath() }
            default:
                break
            }
        }
        return p
    }
}

// MARK: - Drawing

enum ArtPainter {
    /// Draws shapes into `ctx`, which is already in art coordinates.
    static func draw(_ shapes: [ArtShape], _ paints: PaintSet, in ctx: GraphicsContext) {
        let art = DressUpArt.shared
        for s in shapes {
            var g = ctx
            if s.opacity < 1 { g.opacity = s.opacity }
            if let gr = s.gradient {
                g.fill(s.path, with: .linearGradient(
                    Gradient(colors: [gr.0.resolve(paints).color, gr.1.resolve(paints).color]),
                    startPoint: CGPoint(x: s.bounds.minX, y: s.bounds.minY),
                    endPoint: CGPoint(x: s.bounds.minX, y: s.bounds.maxY)))
            } else if let f = s.fill {
                g.fill(s.path, with: .color(f.resolve(paints).color))
            }
            if let st = s.stroke {
                g.stroke(s.path, with: .color(st.resolve(paints).color),
                         style: StrokeStyle(lineWidth: s.width, lineCap: .round, lineJoin: .round))
            }
            if s.patterned, let name = paints.pattern {
                let col = Shades.pattern(paints.main).color
                if DressUpPatterns.isProcedural(name) {
                    g.drawLayer { l in
                        l.clip(to: s.path)
                        if name == "checks" { l.opacity = 0.55 }
                        var layerCtx = l
                        DressUpPatterns.fill(name, in: s.bounds, color: col, into: &layerCtx)
                    }
                    if let st = s.stroke {
                        g.stroke(s.path, with: .color(st.resolve(paints).color),
                                 style: StrokeStyle(lineWidth: s.width, lineCap: .round, lineJoin: .round))
                    }
                } else if let pat = art.patterns[name] {
                    g.drawLayer { l in
                        l.clip(to: s.path)
                        if name == "checks" { l.opacity = 0.55 }
                        l.fill(pat, with: .color(col))
                    }
                    if let st = s.stroke {
                        g.stroke(s.path, with: .color(st.resolve(paints).color),
                                 style: StrokeStyle(lineWidth: s.width, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
    }

    /// Maps `box` (art coordinates) into `size`, fitting or filling, centered.
    static func fit(_ ctx: inout GraphicsContext, box: CGRect, into size: CGSize, fill: Bool = false) {
        let sx = size.width / box.width, sy = size.height / box.height
        let s = fill ? max(sx, sy) : min(sx, sy)
        ctx.translateBy(x: (size.width - box.width * s) / 2, y: (size.height - box.height * s) / 2)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -box.minX, y: -box.minY)
    }
}
