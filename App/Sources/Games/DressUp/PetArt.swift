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
        guard let f = DressUpBundle.takeForPets() else {
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
    /// Salon: fur dye (index into `PetPainter.dyes`; the last one is rainbow), nail polish (cloth index),
    /// sparkle fur, and a cheek sticker ("heart" or "star").
    var dye: Int?
    var nails: Int?
    var glitter = false
    var cheek: String?

    init(kind: String) { self.kind = kind }

    enum CodingKeys: String, CodingKey { case kind, wear, colors, patterns, dye, nails, glitter, cheek }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? "kitty"
        wear = (try? c.decodeIfPresent([String: String].self, forKey: .wear)) ?? [:]
        colors = (try? c.decodeIfPresent([String: Int].self, forKey: .colors)) ?? [:]
        patterns = (try? c.decodeIfPresent([String: String].self, forKey: .patterns)) ?? [:]
        dye = try? c.decodeIfPresent(Int.self, forKey: .dye)
        nails = try? c.decodeIfPresent(Int.self, forKey: .nails)
        glitter = (try? c.decodeIfPresent(Bool.self, forKey: .glitter)) ?? false
        cheek = try? c.decodeIfPresent(String.self, forKey: .cheek)
    }

    /// Drops anything this build doesn't know. Returns nil for an unknown pet.
    func sanitized(_ art: PetArt = .shared, _ dress: DressUpArt = .shared) -> PetLook? {
        guard art.animals[kind] != nil else { return nil }
        var p = self
        p.wear = wear.filter { art.wear[$0.value]?.slot == $0.key }
        p.colors = colors.filter { p.wear[$0.key] != nil }.mapValues { min(max($0, 0), max(0, dress.cloth.count - 1)) }
        p.patterns = patterns.filter { p.wear[$0.key] != nil && dress.patterns[$0.value] != nil }
        if let d = dye, !(0...PetPainter.dyes.count).contains(d) { p.dye = nil }
        if let n = nails, !(0..<dress.cloth.count).contains(n) { p.nails = nil }
        if let c = cheek, !PetPainter.cheeks.contains(c) { p.cheek = nil }
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
    /// Seconds, for things that twinkle.
    var time: Double = 0

    static let still = PetPose()
}

enum PetPainter {
    /// Draws the pet into `ctx`, which is already in pet coordinates.
    /// `furShading` colors the fur like a dye would (the Potion Lab's potions use it), over the pet's own `dye`.
    static func draw(_ pet: PetLook, pose: PetPose = .still, furShading: GraphicsContext.Shading? = nil,
                     under: ((GraphicsContext) -> Void)? = nil,
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
        let dyeFill = furShading ?? dyeShading(pet.dye)
        func fur(_ shapes: [ArtShape]) {
            guard let fill = dyeFill else { ArtPainter.draw(shapes, plain, in: g); return }
            g.drawLayer { l in
                l.clipToLayer { c in ArtPainter.draw(shapes, plain, in: c) }
                ArtPainter.draw(shapes, plain, in: l)
                // keep the fur's light and shade, take the dye's color, then deepen it a little
                var c = l
                c.blendMode = .color
                c.fill(Path(CGRect(x: -100, y: -100, width: 800, height: 900)), with: fill)
                c.blendMode = .multiply
                c.opacity = 0.35
                c.fill(Path(CGRect(x: -100, y: -100, width: 800, height: 900)), with: fill)
            }
        }
        wear("back")
        fur(a.back)
        fur(a.torso)
        under?(g)
        wear("body")
        fur(a.limbs)
        if let n = pet.nails { polish(n, in: g) }
        fur(a.head)
        wear("neck")
        fur(a.front)
        if pose.blush { ArtPainter.draw(a.blush, plain, in: g) }
        if let c = pet.cheek { cheekSticker(c, a, in: g) }
        if pet.glitter { sparkleFur(time: pose.time, in: g) }
        var e = g
        if pose.look != .zero { e.translateBy(x: pose.look.width, y: pose.look.height) }
        ArtPainter.draw(a.eyes[pose.eyes] ?? a.eyes["open"] ?? [], plain, in: e)
        ArtPainter.draw(a.mouths[pose.mouth] ?? a.mouths["smile"] ?? [], plain, in: g)
        wear("glasses")
        wear("hat")
        over?(g)
    }

    // MARK: Salon

    static let dyes: [RGB] = ["#FF8FB8", "#FF8A73", "#FFD86E", "#8FE0A4", "#7FD6E8", "#7FA8FF", "#B89CFF", "#F2A6FF"].map { RGB(hex: $0) }
    static let cheeks = ["heart", "star"]

    private static func dyeShading(_ i: Int?) -> GraphicsContext.Shading? {
        guard let i else { return nil }
        if let c = dyes[safe: i] { return .color(c.color) }
        guard i == dyes.count else { return nil }
        let rainbow = ["#FF8FB8", "#FFB27A", "#FFE27A", "#8FE0A4", "#7FC8FF", "#B89CFF"].map { RGB(hex: $0).color }
        return .linearGradient(Gradient(colors: rainbow), startPoint: CGPoint(x: 120, y: 60), endPoint: CGPoint(x: 480, y: 620))
    }

    /// A dye swatch (for the salon shelf).
    static func dyeSwatch(_ i: Int) -> GraphicsContext.Shading? { dyeShading(i) }

    private static func polish(_ n: Int, in g: GraphicsContext) {
        guard let c = DressUpArt.shared.cloth[safe: n] else { return }
        let dots: [CGPoint] = [CGPoint(x: 214, y: 538), CGPoint(x: 234, y: 543), CGPoint(x: 204, y: 621), CGPoint(x: 228, y: 627), CGPoint(x: 252, y: 621)]
        for d in dots + dots.map({ CGPoint(x: 600 - $0.x, y: $0.y) }) {
            let r = CGRect(x: d.x - 8, y: d.y - 6, width: 16, height: 12)
            g.fill(Path(ellipseIn: r), with: .color(c.color))
            g.stroke(Path(ellipseIn: r), with: .color(Shades.outline(c).color), lineWidth: 2)
            g.fill(Path(ellipseIn: CGRect(x: d.x - 4, y: d.y - 4, width: 5, height: 3)), with: .color(.white.opacity(0.8)))
        }
    }

    private static func cheekSticker(_ kind: String, _ a: PetAnimal, in g: GraphicsContext) {
        let c = CGPoint(x: a.eyeAnchor.x - 44, y: a.eyeAnchor.y + 50)
        let r = CGRect(x: c.x - 17, y: c.y - 16, width: 34, height: 32)
        let path = kind == "star" ? starPath(c, 19) : heartPath(in: r)
        let col = kind == "star" ? RGB(hex: "#FFD86E") : RGB(hex: "#FF6F96")
        g.fill(path, with: .color(col.color))
        g.stroke(path, with: .color(.white), lineWidth: 4)
    }

    private static func sparkleFur(time t: Double, in g: GraphicsContext) {
        let spots: [CGPoint] = [CGPoint(x: 200, y: 200), CGPoint(x: 390, y: 180), CGPoint(x: 330, y: 300), CGPoint(x: 190, y: 330),
                                CGPoint(x: 420, y: 340), CGPoint(x: 240, y: 450), CGPoint(x: 370, y: 470), CGPoint(x: 300, y: 560),
                                CGPoint(x: 210, y: 560), CGPoint(x: 400, y: 570), CGPoint(x: 280, y: 150)]
        for (i, p) in spots.enumerated() {
            let tw = 0.55 + 0.45 * sin(t * 3 + Double(i) * 1.9)
            let s = CGFloat(14 + (i % 3) * 6) * CGFloat(0.6 + 0.4 * tw)
            var q = g
            q.opacity = 0.35 + 0.6 * tw
            q.fill(Twinkle().path(in: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)), with: .color(.white))
        }
    }

    static func heartPath(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.3), control1: CGPoint(x: r.midX - w * 0.1, y: r.maxY - h * 0.15),
                   control2: CGPoint(x: r.minX, y: r.minY + h * 0.65))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY + h * 0.22), control1: CGPoint(x: r.minX, y: r.minY - h * 0.05),
                   control2: CGPoint(x: r.midX - w * 0.05, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.3), control1: CGPoint(x: r.midX + w * 0.05, y: r.minY),
                   control2: CGPoint(x: r.maxX, y: r.minY - h * 0.05))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.minY + h * 0.65),
                   control2: CGPoint(x: r.midX + w * 0.1, y: r.maxY - h * 0.15))
        return p
    }

    static func starPath(_ c: CGPoint, _ R: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let a = -Double.pi / 2 + Double(i) * Double.pi / 5
            let r = i % 2 == 0 ? R : R * 0.48
            let q = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
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
