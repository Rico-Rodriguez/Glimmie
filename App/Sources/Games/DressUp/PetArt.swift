import SwiftUI

// MARK: - Pet art
//
// The pets, their outfits and the pet-corner props are in dressup.json under "pets", made by
// tools/dressup/pets.py. Pets are drawn in a 600x660 canvas and all share one sitting body plan, so
// one outfit fits every pet: each pet has anchors that place a hat on its head, glasses on its eyes
// and garments over its body. Animal colors are fixed hex; outfit colors use the Dress Up roles.

struct PetAnimal {
    let id: String
    let back, torso, limbs, head, front, blush, brows: [ArtShape]
    let eyes: [String: [ArtShape]]
    let mouths: [String: [ArtShape]]
    let eye: CGPoint
    let mouth: CGPoint
    let fur: RGB
    /// Where the top of the head is (canonical 300, 134), its tilt in degrees and a scale for hats.
    let hat: CGPoint
    let hatTilt: Double
    let hatScale: CGFloat
    /// The left eye (canonical 238, 270).
    let eyeAnchor: CGPoint
    /// Body width (canonical 1).
    let wide: CGFloat
}

struct PetWearItem: Identifiable {
    let id: String
    let slot: String
    let shapes: [ArtShape]
    let defaultColor: Int
    let accent: RGB
    let patternable: Bool
}

final class PetArt {
    static let shared = PetArt()

    let size: CGSize
    let order: [String]
    let animals: [String: PetAnimal]
    let wear: [String: PetWearItem]
    let slots: [String]
    let bySlot: [String: [String]]
    let thumbs: [String: CGRect]
    let props: [String: [ArtShape]]

    /// Feet line and head center in pet coordinates.
    static let feetY: CGFloat = 632
    static let headCenter = CGPoint(x: 300, y: 262)

    private init() {
        var file: PetRawFile?
        if let url = GameFiles.url("dressup", "json", game: "DressUp"), let data = try? Data(contentsOf: url) {
            file = (try? JSONDecoder().decode(PetRawWrapper.self, from: data))?.pets
        }
        guard let f = file else {
            size = CGSize(width: 600, height: 660); order = []; animals = [:]; wear = [:]; slots = []; bySlot = [:]
            thumbs = [:]; props = [:]
            return
        }
        size = CGSize(width: f.size[0], height: f.size[1])
        order = f.order.filter { f.animals[$0] != nil }
        var a: [String: PetAnimal] = [:]
        for (id, r) in f.animals {
            let h = r.anchors.hat
            a[id] = PetAnimal(
                id: id, back: r.back.map(PetArt.shape), torso: r.torso.map(PetArt.shape), limbs: r.limbs.map(PetArt.shape),
                head: r.head.map(PetArt.shape), front: r.front.map(PetArt.shape), blush: r.blush.map(PetArt.shape),
                brows: r.brows.map(PetArt.shape),
                eyes: r.eyes.mapValues { $0.map(PetArt.shape) }, mouths: r.mouths.mapValues { $0.map(PetArt.shape) },
                eye: CGPoint(x: r.eye[0], y: r.eye[1]), mouth: CGPoint(x: r.mouth[0], y: r.mouth[1]), fur: RGB(hex: r.fur),
                hat: CGPoint(x: h[safe: 0] ?? 300, y: h[safe: 1] ?? 134), hatTilt: h[safe: 2] ?? 0, hatScale: CGFloat(h[safe: 3] ?? 1),
                eyeAnchor: CGPoint(x: r.anchors.eyes[safe: 0] ?? 238, y: r.anchors.eyes[safe: 1] ?? 270),
                wide: CGFloat(r.anchors.wide))
        }
        animals = a
        var w: [String: PetWearItem] = [:]
        var slotItems: [String: [String]] = [:]
        for (id, r) in f.wear {
            w[id] = PetWearItem(id: id, slot: r.slot, shapes: r.shapes.map(PetArt.shape), defaultColor: r.defaultColor ?? 3,
                                accent: RGB(hex: r.accent ?? "#FFFFFF"), patternable: r.patternable ?? false)
        }
        // keep the order the art script wrote them in (JSON objects are unordered): sort by id within a slot
        for s in f.slots { slotItems[s] = w.values.filter { $0.slot == s }.map(\.id).sorted() }
        wear = w
        slots = f.slots
        bySlot = slotItems
        thumbs = f.thumbs.mapValues { CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) }
        props = f.props.mapValues { $0.map(PetArt.shape) }
    }

    private static func shape(_ r: PetRawShape) -> ArtShape {
        let path = PathParser.parse(r.d)
        return ArtShape(path: path, bounds: path.boundingRect, fill: Paint(r.f), gradient: nil, stroke: Paint(r.s),
                        width: CGFloat(r.w ?? 4), opacity: r.o ?? 1, patterned: (r.pat ?? 0) != 0)
    }
}

private struct PetRawShape: Decodable {
    let d: String
    let f: String?
    let s: String?
    let w: Double?
    let o: Double?
    let pat: Int?
}

private struct PetRawAnchors: Decodable {
    let hat: [Double]
    let eyes: [Double]
    let wide: Double
}

private struct PetRawAnimal: Decodable {
    let back, torso, limbs, head, front, blush, brows: [PetRawShape]
    let eyes: [String: [PetRawShape]]
    let mouths: [String: [PetRawShape]]
    let eye: [Double]
    let mouth: [Double]
    let fur: String
    let anchors: PetRawAnchors
}

private struct PetRawWear: Decodable {
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

private struct PetRawFile: Decodable {
    let size: [Double]
    let order: [String]
    let animals: [String: PetRawAnimal]
    let wear: [String: PetRawWear]
    let slots: [String]
    let thumbs: [String: [Double]]
    let props: [String: [PetRawShape]]
}

private struct PetRawWrapper: Decodable {
    let pets: PetRawFile
}

// MARK: - One pet and what it wears
//
// Saved inside looks and pets.json: only add fields, with defaults in `init(from:)`.

struct PetLook: Codable, Equatable {
    var kind: String
    /// slot -> wear item id
    var wear: [String: String] = [:]
    /// slot -> cloth palette index
    var colors: [String: Int] = [:]
    /// slot -> fabric pattern name
    var patterns: [String: String] = [:]

    init(kind: String) { self.kind = kind }

    enum CodingKeys: String, CodingKey { case kind, wear, colors, patterns }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "kitty"
        wear = (try? c.decodeIfPresent([String: String].self, forKey: .wear)) ?? [:]
        colors = (try? c.decodeIfPresent([String: Int].self, forKey: .colors)) ?? [:]
        patterns = (try? c.decodeIfPresent([String: String].self, forKey: .patterns)) ?? [:]
    }

    /// Drops anything this build doesn't know. Returns nil for an unknown pet.
    func sanitized(_ art: PetArt = .shared, _ dress: DressUpArt = .shared) -> PetLook? {
        guard art.animals[kind] != nil else { return nil }
        var p = self
        p.wear = wear.filter { art.wear[$0.value]?.slot == $0.key }
        p.colors = colors.filter { p.wear[$0.key] != nil }.mapValues { min(max($0, 0), max(0, dress.cloth.count - 1)) }
        p.patterns = patterns.filter { p.wear[$0.key] != nil && dress.patterns[$0.value] != nil }
        return p
    }

    func colorIndex(_ slot: String, _ art: PetArt = .shared) -> Int {
        colors[slot] ?? wear[slot].flatMap { art.wear[$0]?.defaultColor } ?? 3
    }

    func paints(for item: PetWearItem, _ dress: DressUpArt = .shared) -> PaintSet {
        let main = dress.cloth[safe: colors[item.slot] ?? item.defaultColor] ?? Shades.white
        return PaintSet(main: main, accent: item.accent, skin: Shades.white,
                        pattern: item.patternable ? patterns[item.slot] : nil)
    }

    /// A surprise outfit: a few pieces in random colors.
    static func random(kind: String, _ art: PetArt = .shared, _ dress: DressUpArt = .shared) -> PetLook {
        var p = PetLook(kind: kind)
        let chances: [String: Double] = ["hat": 0.7, "glasses": 0.3, "neck": 0.55, "body": 0.55, "back": 0.3]
        for s in art.slots where Double.random(in: 0..<1) < (chances[s] ?? 0.4) {
            guard let id = art.bySlot[s]?.randomElement() else { continue }
            p.wear[s] = id
            p.colors[s] = Int.random(in: 0..<max(1, dress.cloth.count))
            if art.wear[id]?.patternable == true, Double.random(in: 0..<1) < 0.3 { p.patterns[s] = dress.patternNames.randomElement() }
        }
        return p
    }
}

// MARK: - Drawing a pet

/// How the pet looks right now: its face, where its eyes look, and how it's squashed or tilted.
struct PetPose {
    var eyes = "open"
    var mouth = "smile"
    /// Eye shift toward what it's looking at, in pet units (a few points at most).
    var look: CGSize = .zero
    /// 1 = still. Above 1 stretches taller, below squashes, from the feet.
    var squash: CGFloat = 1
    var tilt: Double = 0
    /// Wing flap, -1...1.
    var flap: CGFloat = 0
    var blush = true

    static let still = PetPose()
}

enum PetPainter {
    /// Draws the pet into `ctx`, which is already in pet coordinates.
    static func draw(_ pet: PetLook, pose: PetPose = .still, under: ((GraphicsContext) -> Void)? = nil,
                     over: ((GraphicsContext) -> Void)? = nil, in ctx: GraphicsContext) {
        let art = PetArt.shared
        guard let a = art.animals[pet.kind] else { return }
        var g = ctx
        let feet = CGPoint(x: 300, y: PetArt.feetY)
        g.translateBy(x: feet.x, y: feet.y)
        if pose.tilt != 0 { g.rotate(by: .degrees(pose.tilt)) }
        if pose.squash != 1 { g.scaleBy(x: 1 / sqrt(pose.squash), y: pose.squash) }
        g.translateBy(x: -feet.x, y: -feet.y)

        let plain = PaintSet(main: a.fur, accent: a.fur, skin: a.fur, pattern: nil)
        func wear(_ slot: String) {
            guard let id = pet.wear[slot], let item = art.wear[id] else { return }
            var w = g
            transform(&w, slot: slot, a, flap: pose.flap)
            ArtPainter.draw(item.shapes, pet.paints(for: item), in: w)
        }
        wear("back")
        ArtPainter.draw(a.back, plain, in: g)
        ArtPainter.draw(a.torso, plain, in: g)
        under?(g)
        wear("body")
        ArtPainter.draw(a.limbs, plain, in: g)
        ArtPainter.draw(a.head, plain, in: g)
        wear("neck")
        ArtPainter.draw(a.front, plain, in: g)
        if pose.blush { ArtPainter.draw(a.blush, plain, in: g) }
        var e = g
        if pose.look != .zero { e.translateBy(x: pose.look.width, y: pose.look.height) }
        ArtPainter.draw(a.eyes[pose.eyes] ?? a.eyes["open"] ?? [], plain, in: e)
        ArtPainter.draw(a.mouths[pose.mouth] ?? a.mouths["smile"] ?? [], plain, in: g)
        wear("glasses")
        wear("hat")
        over?(g)
    }

    /// Moves an outfit drawn on the canonical pet onto this pet.
    static func transform(_ g: inout GraphicsContext, slot: String, _ a: PetAnimal, flap: CGFloat = 0) {
        switch slot {
        case "hat":
            g.translateBy(x: a.hat.x, y: a.hat.y)
            if a.hatTilt != 0 { g.rotate(by: .degrees(a.hatTilt)) }
            if a.hatScale != 1 { g.scaleBy(x: a.hatScale, y: a.hatScale) }
            g.translateBy(x: -300, y: -134)
        case "glasses":
            let s = (300 - a.eyeAnchor.x) / 62
            g.translateBy(x: 300, y: a.eyeAnchor.y)
            g.scaleBy(x: s, y: s)
            g.translateBy(x: -300, y: -270)
        case "body":
            if a.wide != 1 {
                g.translateBy(x: 300, y: 0); g.scaleBy(x: a.wide, y: 1); g.translateBy(x: -300, y: 0)
            }
        case "back":
            let k = a.wide * (1 + 0.07 * flap)
            g.translateBy(x: 300, y: 430)
            g.scaleBy(x: k, y: 1 - 0.02 * flap)
            g.translateBy(x: -300, y: -430)
        default: break
        }
    }

    /// The pet fitted into `size`, framing `box` (pet coordinates; nil = the whole pet).
    static func paint(_ pet: PetLook, pose: PetPose = .still, box: CGRect? = nil, in ctx: inout GraphicsContext, size: CGSize) {
        ArtPainter.fit(&ctx, box: box ?? CGRect(x: 0, y: 0, width: 600, height: 660), into: size)
        draw(pet, pose: pose, in: ctx)
    }

    /// A pet at the doll's feet, in doll art coordinates (600x900).
    static let companionScale: CGFloat = 0.34
    static let companionFeet = CGPoint(x: 458, y: 768)

    static func drawCompanion(_ pet: PetLook, pose: PetPose = .still, in ctx: GraphicsContext) {
        var g = ctx
        let k = companionScale
        g.translateBy(x: companionFeet.x - 300 * k, y: companionFeet.y - PetArt.feetY * k)
        g.scaleBy(x: k, y: k)
        // a soft shadow on the floor
        g.fill(Path(ellipseIn: CGRect(x: 170, y: 606, width: 260, height: 52)), with: .color(Theme.ink.opacity(0.14)))
        draw(pet, pose: pose, in: g)
    }

    /// A prop from the pet corner (140x140 box, or pet coordinates for the bed and blanket).
    static func prop(_ name: String, at p: CGPoint, scale: CGFloat = 1, rotation: Double = 0, opacity: Double = 1,
                     center: CGPoint = CGPoint(x: 70, y: 70), in ctx: GraphicsContext) {
        guard let shapes = PetArt.shared.props[name], opacity > 0.01, scale > 0.01 else { return }
        var g = ctx
        if opacity < 1 { g.opacity = opacity }
        g.translateBy(x: p.x, y: p.y)
        if rotation != 0 { g.rotate(by: .degrees(rotation)) }
        g.scaleBy(x: scale, y: scale)
        g.translateBy(x: -center.x, y: -center.y)
        ArtPainter.draw(shapes, PaintSet(main: Shades.white, accent: Shades.white, skin: Shades.white, pattern: nil), in: g)
    }
}

/// A still picture of a pet, optionally cropped to part of it.
struct PetThumb: View {
    let pet: PetLook
    var box: CGRect? = nil
    var pose: PetPose = .still
    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            PetPainter.paint(pet, pose: pose, box: box, in: &c, size: size)
        }
    }
}

/// A pet-corner prop on its own (food, toys, tools).
struct PetPropThumb: View {
    let name: String
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 140
            PetPainter.prop(name, at: CGPoint(x: size.width / 2, y: size.height / 2), scale: s, in: ctx)
        }
    }
}
