import SwiftUI

/// Self-contained chibi pastel fairy companion shown beside the Dress Up doll when a fairy is pinned.
struct PinnedFairySpec: Equatable {
    static let defaultsKey = "glimmie.pinnedFairy"

    static let allIDs: [String] = [
        "heart", "star", "berry", "cloud", "ribbon", "moon",
        "melody", "peach", "dewdrop", "honey", "blossom", "silk",
    ]

    enum HairStyle { case twinPuffs, twinTails, curls, bob, braidCrown }

    let id: String
    let hair: UInt32
    let hairShade: UInt32
    let dress: UInt32
    let dressAccent: UInt32
    let wing: UInt32
    let wingInner: UInt32
    let emblem: UInt32
    let emblemAccent: UInt32
    let skin: UInt32
    let cheek: UInt32
    let eye: UInt32
    let hairStyle: HairStyle

    static func pinned(from defaults: UserDefaults = .standard) -> PinnedFairySpec? {
        guard let raw = defaults.string(forKey: defaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return spec(for: raw)
    }

    static func spec(for id: String) -> PinnedFairySpec? {
        switch id {
        case "heart":
            return PinnedFairySpec(
                id: id, hair: 0xFF88BA, hairShade: 0xE85C96, dress: 0xFFB5D6, dressAccent: 0xFF6FA8,
                wing: 0xFFD9EE, wingInner: 0xFFF5FA, emblem: 0xFF5D9E, emblemAccent: 0xFFF0F7,
                skin: 0xFFE9DB, cheek: 0xFF96BA, eye: 0x9C2B66, hairStyle: .twinPuffs
            )
        case "star":
            return PinnedFairySpec(
                id: id, hair: 0xFFE07D, hairShade: 0xF0B941, dress: 0xFFF0A6, dressAccent: 0xFFC547,
                wing: 0xFFF4C4, wingInner: 0xFFFFFF, emblem: 0xFFC93C, emblemAccent: 0xFFF9D6,
                skin: 0xFFEBD9, cheek: 0xFFA4A8, eye: 0x7A4B9E, hairStyle: .curls
            )
        case "berry":
            return PinnedFairySpec(
                id: id, hair: 0xFF7B9C, hairShade: 0xDE4D72, dress: 0xFF9EB5, dressAccent: 0x7CD992,
                wing: 0xFFE0EB, wingInner: 0xE6FFF0, emblem: 0xFF5C82, emblemAccent: 0x6FD486,
                skin: 0xFFECDF, cheek: 0xFF8AA8, eye: 0x8F2850, hairStyle: .bob
            )
        case "cloud":
            return PinnedFairySpec(
                id: id, hair: 0xB8E4FF, hairShade: 0x7CC2F2, dress: 0xDCF2FF, dressAccent: 0x9AD2FF,
                wing: 0xF2FAFF, wingInner: 0xD4EEFF, emblem: 0xFFFFFF, emblemAccent: 0x9FD8FF,
                skin: 0xFFEBE0, cheek: 0xFFA8C6, eye: 0x3D6BA6, hairStyle: .twinPuffs
            )
        case "ribbon":
            return PinnedFairySpec(
                id: id, hair: 0xD2A8FF, hairShade: 0xA876E8, dress: 0xE5CCFF, dressAccent: 0xFF94C8,
                wing: 0xF2E3FF, wingInner: 0xFFE6F4, emblem: 0xFF78B8, emblemAccent: 0xFFE2F2,
                skin: 0xFFEADC, cheek: 0xFF9AC0, eye: 0x6B3B9E, hairStyle: .twinTails
            )
        case "moon":
            return PinnedFairySpec(
                id: id, hair: 0xB9B4FF, hairShade: 0x837DE0, dress: 0xCFCBFF, dressAccent: 0xFFE07A,
                wing: 0xE4E2FF, wingInner: 0xFFF7D1, emblem: 0xFFE066, emblemAccent: 0xFFF9DC,
                skin: 0xFFEBE2, cheek: 0xFFA3C4, eye: 0x4A4296, hairStyle: .curls
            )
        case "melody":
            return PinnedFairySpec(
                id: id, hair: 0x8FE8D4, hairShade: 0x56C7AE, dress: 0xBFF5E8, dressAccent: 0xFFA6D2,
                wing: 0xDCFDF5, wingInner: 0xFFF2FA, emblem: 0xFF84BE, emblemAccent: 0xFFE67D,
                skin: 0xFFEADB, cheek: 0xFF9CB8, eye: 0x2B7A78, hairStyle: .twinTails
            )
        case "peach":
            return PinnedFairySpec(
                id: id, hair: 0xFFB896, hairShade: 0xED8A61, dress: 0xFFD4BE, dressAccent: 0xFF9680,
                wing: 0xFFEBE0, wingInner: 0xFFF6E8, emblem: 0xFF9E82, emblemAccent: 0x7ED692,
                skin: 0xFFE8D8, cheek: 0xFF9494, eye: 0x8C4238, hairStyle: .twinTails
            )
        case "dewdrop":
            return PinnedFairySpec(
                id: id, hair: 0x8CD4FF, hairShade: 0x52B0F0, dress: 0xBBE7FF, dressAccent: 0x7AE5DA,
                wing: 0xDDF5FF, wingInner: 0xFFFFFF, emblem: 0x5EC7FF, emblemAccent: 0xE6F8FF,
                skin: 0xFFECE2, cheek: 0xFFA3BE, eye: 0x2B6AA3, hairStyle: .bob
            )
        case "honey":
            return PinnedFairySpec(
                id: id, hair: 0xF7C96B, hairShade: 0xD99A36, dress: 0xFFE484, dressAccent: 0x9C6834,
                wing: 0xFFF7D6, wingInner: 0xFFFFFF, emblem: 0xFFB830, emblemAccent: 0x8C5828,
                skin: 0xFFE8D4, cheek: 0xFF9E94, eye: 0x78481C, hairStyle: .twinPuffs
            )
        case "blossom":
            return PinnedFairySpec(
                id: id, hair: 0xFFC2D9, hairShade: 0xED8FB2, dress: 0xFFE0EC, dressAccent: 0xFF8EB8,
                wing: 0xFFF0F6, wingInner: 0xFFE8A8, emblem: 0xFF9BC2, emblemAccent: 0xFFE378,
                skin: 0xFFEBE0, cheek: 0xFF94B4, eye: 0x8F3A62, hairStyle: .bob
            )
        case "silk":
            return PinnedFairySpec(
                id: id, hair: 0x5B527A, hairShade: 0x3D3559, dress: 0xFFC5D0, dressAccent: 0x9EE3CB,
                wing: 0xE8FBF4, wingInner: 0xFFEAF0, emblem: 0xFF7B9E, emblemAccent: 0xFFE17D,
                skin: 0xFFECDF, cheek: 0xFF9AB4, eye: 0x4A3666, hairStyle: .braidCrown
            )
        default:
            return nil
        }
    }
}

struct PinnedFairyCompanionView: View {
    let spec: PinnedFairySpec
    var paused = false
    @State private var happyUntil = Date.distantPast

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let isHappy = tl.date < happyUntil
            Canvas { ctx, size in
                PinnedFairyPainter.draw(spec, in: ctx, size: size, t: t, happy: isHappy)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            Sound.shared.play(.sparkle, volume: 0.65)
            Sound.shared.tap()
            happyUntil = Date().addingTimeInterval(0.95)
        }
    }
}

enum PinnedFairyPainter {
    static func draw(_ spec: PinnedFairySpec, in ctx: GraphicsContext, size: CGSize, t: Double, happy: Bool) {
        let s = min(size.width, size.height) / 120
        let bob = CGFloat(sin(t * 2.7)) * 5.5 + (happy ? -CGFloat(abs(sin(t * 14))) * 8 : 0)
        let sway = sin(t * 1.9) * 4.0
        let flap = CGFloat(sin(t * (happy ? 16 : 9.5)))

        var g = ctx
        g.translateBy(x: size.width / 2, y: size.height / 2 + bob)
        g.scaleBy(x: s, y: s)
        g.rotate(by: .degrees(sway))

        // Soft fairy aura glow
        let aura = Path(ellipseIn: CGRect(x: -50, y: -50, width: 100, height: 100))
        g.fill(
            aura,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(spec.wing, alpha: 0.48), .clear]),
                center: .zero,
                startRadius: 8,
                endRadius: 50
            )
        )

        // Fluttering translucent wings
        drawWings(spec, flap: flap, in: g)

        // Back hair silhouette
        drawBackHair(spec, in: g)

        // Chibi pastel dress & little feet
        let body = Path { p in
            p.move(to: CGPoint(x: -11, y: 12))
            p.addQuadCurve(to: CGPoint(x: -20, y: 38), control: CGPoint(x: -18, y: 24))
            p.addQuadCurve(to: CGPoint(x: 0, y: 42), control: CGPoint(x: -10, y: 44))
            p.addQuadCurve(to: CGPoint(x: 20, y: 38), control: CGPoint(x: 10, y: 44))
            p.addQuadCurve(to: CGPoint(x: 11, y: 12), control: CGPoint(x: 18, y: 24))
            p.closeSubpath()
        }
        StorybookArt.fillAndStroke(
            g, body,
            fill: StorybookArt.color(spec.dress),
            stroke: StorybookArt.outline(for: spec.dress),
            width: 2.6
        )
        let collar = Path(roundedRect: CGRect(x: -11, y: 12, width: 22, height: 6), cornerRadius: 3)
        StorybookArt.fillAndStroke(
            g, collar,
            fill: StorybookArt.color(spec.dressAccent),
            stroke: StorybookArt.outline(for: spec.dressAccent),
            width: 2
        )

        // Little hands
        for side in [-1.0, 1.0] as [CGFloat] {
            let handY: CGFloat = happy ? 11 : 21
            let hand = Path(ellipseIn: CGRect(x: side * 15 - 4.5, y: handY - 4.5, width: 9, height: 9))
            StorybookArt.fillAndStroke(g, hand, fill: StorybookArt.color(spec.skin), stroke: StorybookArt.outline(for: spec.skin), width: 2)
        }

        // Round chibi head
        let head = Path(ellipseIn: CGRect(x: -23, y: -27, width: 46, height: 42))
        StorybookArt.fillAndStroke(
            g, head,
            fill: StorybookArt.color(spec.skin),
            stroke: StorybookArt.outline(for: spec.skin),
            width: 2.6
        )

        // Rosy cheeks
        for side in [-1.0, 1.0] as [CGFloat] {
            let cheek = Path(ellipseIn: CGRect(x: side * 13 - 5, y: -3, width: 10, height: 6))
            g.fill(cheek, with: .color(StorybookArt.color(spec.cheek, alpha: 0.65)))
        }

        // Eyes & smile
        if happy {
            for side in [-1.0, 1.0] as [CGFloat] {
                var arc = Path()
                arc.move(to: CGPoint(x: side * 9 - 4.5, y: -6))
                arc.addQuadCurve(to: CGPoint(x: side * 9 + 4.5, y: -6), control: CGPoint(x: side * 9, y: -12))
                g.stroke(arc, with: .color(StorybookArt.color(spec.eye)), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
            }
        } else {
            for side in [-1.0, 1.0] as [CGFloat] {
                let eyeRect = CGRect(x: side * 9 - 4, y: -12, width: 8, height: 9.5)
                g.fill(Path(ellipseIn: eyeRect), with: .color(StorybookArt.color(spec.eye)))
                g.fill(Path(ellipseIn: CGRect(x: side * 9 - 2.6, y: -10.8, width: 3.4, height: 3.4)), with: .color(.white))
            }
        }
        var smile = Path()
        smile.move(to: CGPoint(x: -4, y: 3))
        smile.addQuadCurve(to: CGPoint(x: 4, y: 3), control: CGPoint(x: 0, y: happy ? 9 : 7))
        g.stroke(smile, with: .color(StorybookArt.color(spec.eye)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        // Front bangs
        let bangs = Path { p in
            p.move(to: CGPoint(x: -23, y: -8))
            p.addCurve(to: CGPoint(x: 0, y: -31), control1: CGPoint(x: -24, y: -25), control2: CGPoint(x: -12, y: -31))
            p.addCurve(to: CGPoint(x: 23, y: -8), control1: CGPoint(x: 12, y: -31), control2: CGPoint(x: 24, y: -25))
            p.addQuadCurve(to: CGPoint(x: 10, y: -16), control: CGPoint(x: 17, y: -12))
            p.addQuadCurve(to: CGPoint(x: 0, y: -11), control: CGPoint(x: 5, y: -17))
            p.addQuadCurve(to: CGPoint(x: -10, y: -16), control: CGPoint(x: -5, y: -17))
            p.addQuadCurve(to: CGPoint(x: -23, y: -8), control: CGPoint(x: -17, y: -12))
            p.closeSubpath()
        }
        StorybookArt.fillAndStroke(
            g, bangs,
            fill: StorybookArt.color(spec.hair),
            stroke: StorybookArt.outline(for: spec.hairShade),
            width: 2.6
        )

        // Unique head gem / emblem matching each of the 12 fairy IDs
        drawEmblem(spec, at: CGPoint(x: 0, y: -34), in: g)

        // Orbiting fairy sparkle dust
        let sp = 0.55 + 0.45 * sin(t * 4.2)
        StorybookArt.sparkle(g, at: CGPoint(x: -36, y: -28), radius: 6 * CGFloat(sp), color: Theme.lemon, opacity: 0.9)
        StorybookArt.sparkle(g, at: CGPoint(x: 37, y: -18), radius: 5 * CGFloat(1.1 - sp * 0.4), color: .white, opacity: 0.95)
    }

    private static func drawWings(_ spec: PinnedFairySpec, flap: CGFloat, in g: GraphicsContext) {
        let sx = 1 + 0.14 * flap
        for side in [-1.0, 1.0] as [CGFloat] {
            var wg = g
            wg.translateBy(x: side * 8, y: 12)
            wg.scaleBy(x: side * sx, y: 1 - 0.04 * flap)

            let upper = Path { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: 36, y: -20), control1: CGPoint(x: 12, y: -24), control2: CGPoint(x: 32, y: -30))
                p.addCurve(to: CGPoint(x: 12, y: 6), control1: CGPoint(x: 40, y: -8), control2: CGPoint(x: 26, y: 6))
                p.closeSubpath()
            }
            wg.fill(upper, with: .color(StorybookArt.color(spec.wing, alpha: 0.85)))
            wg.stroke(upper, with: .color(StorybookArt.outline(for: spec.dressAccent).opacity(0.65)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))

            let lower = Path { p in
                p.move(to: CGPoint(x: 2, y: 4))
                p.addCurve(to: CGPoint(x: 26, y: 20), control1: CGPoint(x: 16, y: 4), control2: CGPoint(x: 32, y: 12))
                p.addCurve(to: CGPoint(x: 4, y: 14), control1: CGPoint(x: 20, y: 28), control2: CGPoint(x: 10, y: 22))
                p.closeSubpath()
            }
            wg.fill(lower, with: .color(StorybookArt.color(spec.wingInner, alpha: 0.82)))
            wg.stroke(lower, with: .color(StorybookArt.outline(for: spec.dressAccent).opacity(0.55)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
        }
    }

    private static func drawBackHair(_ spec: PinnedFairySpec, in g: GraphicsContext) {
        let fill = StorybookArt.color(spec.hair)
        let stroke = StorybookArt.outline(for: spec.hairShade)
        switch spec.hairStyle {
        case .twinPuffs:
            for side in [-1.0, 1.0] as [CGFloat] {
                let puff = Path(ellipseIn: CGRect(x: side * 24 - 13, y: -28, width: 26, height: 26))
                StorybookArt.fillAndStroke(g, puff, fill: fill, stroke: stroke, width: 2.5)
            }
        case .twinTails:
            for side in [-1.0, 1.0] as [CGFloat] {
                let tail = Path(ellipseIn: CGRect(x: side * 25 - 10, y: -14, width: 20, height: 38))
                StorybookArt.fillAndStroke(g, tail, fill: fill, stroke: stroke, width: 2.5)
            }
        case .curls:
            for side in [-1.0, 1.0] as [CGFloat] {
                for dy in [-12.0, 2.0, 14.0] as [CGFloat] {
                    let curl = Path(ellipseIn: CGRect(x: side * 22 - 9, y: dy - 8, width: 18, height: 18))
                    StorybookArt.fillAndStroke(g, curl, fill: fill, stroke: stroke, width: 2.3)
                }
            }
        case .bob:
            let bob = Path(roundedRect: CGRect(x: -28, y: -22, width: 56, height: 34), cornerRadius: 16)
            StorybookArt.fillAndStroke(g, bob, fill: fill, stroke: stroke, width: 2.5)
        case .braidCrown:
            let crown = Path(roundedRect: CGRect(x: -24, y: -33, width: 48, height: 14), cornerRadius: 7)
            StorybookArt.fillAndStroke(g, crown, fill: fill, stroke: stroke, width: 2.4)
            let bun = Path(ellipseIn: CGRect(x: -14, y: -38, width: 28, height: 16))
            StorybookArt.fillAndStroke(g, bun, fill: fill, stroke: stroke, width: 2.4)
        }
    }

    private static func drawEmblem(_ spec: PinnedFairySpec, at c: CGPoint, in g: GraphicsContext) {
        let primary = StorybookArt.color(spec.emblem)
        let accent = StorybookArt.color(spec.emblemAccent)
        let outline = StorybookArt.outline(for: spec.emblem)

        switch spec.id {
        case "heart":
            let h = DressUpCulturalOutfits.heartPath(center: c, halfWidth: 10)
            StorybookArt.fillAndStroke(g, h, fill: primary, stroke: outline, width: 2)
        case "star":
            let st = DressUpCulturalOutfits.starPath(center: c, outer: 11, inner: 5)
            StorybookArt.fillAndStroke(g, st, fill: primary, stroke: outline, width: 2)
        case "berry":
            let berry = DressUpCulturalOutfits.heartPath(center: CGPoint(x: c.x, y: c.y + 2), halfWidth: 9)
            StorybookArt.fillAndStroke(g, berry, fill: primary, stroke: outline, width: 2)
            let leaf = Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 10, width: 14, height: 6))
            StorybookArt.fillAndStroke(g, leaf, fill: accent, stroke: StorybookArt.outline(for: spec.emblemAccent), width: 1.8)
        case "cloud":
            var cl = Path()
            cl.addEllipse(in: CGRect(x: c.x - 11, y: c.y - 4, width: 12, height: 10))
            cl.addEllipse(in: CGRect(x: c.x - 5, y: c.y - 9, width: 12, height: 12))
            cl.addEllipse(in: CGRect(x: c.x + 1, y: c.y - 4, width: 11, height: 10))
            StorybookArt.fillAndStroke(g, cl, fill: primary, stroke: accent, width: 2)
        case "ribbon":
            let bowL = Path(ellipseIn: CGRect(x: c.x - 13, y: c.y - 6, width: 12, height: 10))
            let bowR = Path(ellipseIn: CGRect(x: c.x + 1, y: c.y - 6, width: 12, height: 10))
            StorybookArt.fillAndStroke(g, bowL, fill: primary, stroke: outline, width: 2)
            StorybookArt.fillAndStroke(g, bowR, fill: primary, stroke: outline, width: 2)
            let dot = Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8))
            StorybookArt.fillAndStroke(g, dot, fill: accent, stroke: outline, width: 1.6)
        case "moon":
            var moon = Path()
            moon.addArc(center: c, radius: 9.5, startAngle: .degrees(35), endAngle: .degrees(325), clockwise: false)
            moon.addArc(center: CGPoint(x: c.x + 4, y: c.y - 1), radius: 7.5, startAngle: .degrees(310), endAngle: .degrees(50), clockwise: true)
            moon.closeSubpath()
            StorybookArt.fillAndStroke(g, moon, fill: primary, stroke: outline, width: 2)
        case "melody":
            let head = Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 2, width: 9, height: 7))
            StorybookArt.fillAndStroke(g, head, fill: primary, stroke: outline, width: 1.8)
            var stem = Path()
            stem.move(to: CGPoint(x: c.x, y: c.y))
            stem.addLine(to: CGPoint(x: c.x, y: c.y - 12))
            stem.addQuadCurve(to: CGPoint(x: c.x + 9, y: c.y - 8), control: CGPoint(x: c.x + 7, y: c.y - 13))
            g.stroke(stem, with: .color(outline), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        case "peach":
            let peach = Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 8, width: 18, height: 16))
            StorybookArt.fillAndStroke(g, peach, fill: primary, stroke: outline, width: 2)
            let leaf = Path(ellipseIn: CGRect(x: c.x + 2, y: c.y - 11, width: 8, height: 5))
            StorybookArt.fillAndStroke(g, leaf, fill: accent, stroke: StorybookArt.outline(for: spec.emblemAccent), width: 1.6)
        case "dewdrop":
            var drop = Path()
            drop.move(to: CGPoint(x: c.x, y: c.y - 11))
            drop.addQuadCurve(to: CGPoint(x: c.x + 8, y: c.y + 2), control: CGPoint(x: c.x + 8, y: c.y - 4))
            drop.addArc(center: CGPoint(x: c.x, y: c.y + 2), radius: 8, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 11), control: CGPoint(x: c.x - 8, y: c.y - 4))
            drop.closeSubpath()
            StorybookArt.fillAndStroke(g, drop, fill: primary, stroke: outline, width: 2)
        case "honey":
            let drop = Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 8, width: 18, height: 16))
            StorybookArt.fillAndStroke(g, drop, fill: primary, stroke: outline, width: 2)
            var stripe = Path()
            stripe.move(to: CGPoint(x: c.x - 7, y: c.y))
            stripe.addLine(to: CGPoint(x: c.x + 7, y: c.y))
            g.stroke(stripe, with: .color(accent), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        case "blossom":
            let fl = DressUpCulturalOutfits.flowerPath(center: c, radius: 10, petals: 5)
            StorybookArt.fillAndStroke(g, fl, fill: primary, stroke: outline, width: 1.8)
            g.fill(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)), with: .color(accent))
        default: // "silk" and any fallback
            let fl = DressUpCulturalOutfits.flowerPath(center: c, radius: 10, petals: 5)
            StorybookArt.fillAndStroke(g, fl, fill: primary, stroke: outline, width: 1.8)
            let pearl = Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8))
            StorybookArt.fillAndStroke(g, pearl, fill: accent, stroke: outline, width: 1.5)
        }
    }
}
