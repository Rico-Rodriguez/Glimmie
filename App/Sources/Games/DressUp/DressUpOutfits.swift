import SwiftUI

/// Procedural vector outfit collections (Pastel Hanbok & Heart-Jewel Fairy) built in 600x900 doll coordinates.
enum DressUpCulturalOutfits {
    private static let lw: CGFloat = 4.5
    private static let cx: CGFloat = 300
    private static let handR = CGPoint(x: 379, y: 548)

    static let items: [ArtItem] = [
        jeogori(),
        chima(),
        norigae(),
        jokduri(),
        daenggi(),
        jewelFairyDress(),
        heartTiara(),
        jewelWings(),
        starlightWand(),
        heartCompact(),
        hanbokCrown(),
        fairyWand(),
    ]

    static let sparklyIDs: Set<String> = [
        "h_jokduri", "h_hanbokCrown", "n_norigae", "d_jewelfairy", "h_hearttiara",
        "w_jewelwings", "p_starwand", "p_fairyWand", "p_heartcompact",
    ]

    static let wingIDs: Set<String> = ["w_jewelwings"]

    // MARK: - Pastel Hanbok Collection

    private static func jeogori() -> ArtItem {
        var shapes: [ArtShape] = []

        // Billowing curved baerae sleeves (left and mirrored right)
        for side in [-1.0, 1.0] as [CGFloat] {
            let sleeve = mirrored(
                smoothClosed([
                    CGPoint(x: 262, y: 440),
                    CGPoint(x: 242, y: 454),
                    CGPoint(x: 222, y: 492),
                    CGPoint(x: 210, y: 534),
                    CGPoint(x: 232, y: 546),
                    CGPoint(x: 254, y: 526),
                    CGPoint(x: 264, y: 492),
                ]),
                flip: side > 0
            )
            shapes.append(shape(sleeve, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw, patterned: true))

            // White silk kkeutdong cuff trim at wrist
            let cuff = mirrored(
                smoothClosed([
                    CGPoint(x: 212, y: 524),
                    CGPoint(x: 209, y: 538),
                    CGPoint(x: 231, y: 549),
                    CGPoint(x: 238, y: 536),
                ]),
                flip: side > 0
            )
            shapes.append(shape(cuff, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#CBB5C4")), width: 3.2))
        }

        // Cropped jeogori bodice with graceful curved doryeon bottom hem
        let bodice = smoothClosed([
            CGPoint(x: 270, y: 434),
            CGPoint(x: 250, y: 444),
            CGPoint(x: 244, y: 472),
            CGPoint(x: 246, y: 494),
            CGPoint(x: 274, y: 499),
            CGPoint(x: 300, y: 500),
            CGPoint(x: 326, y: 499),
            CGPoint(x: 354, y: 494),
            CGPoint(x: 356, y: 472),
            CGPoint(x: 350, y: 444),
            CGPoint(x: 330, y: 434),
            CGPoint(x: 300, y: 468),
        ])
        shapes.append(shape(bodice, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw, patterned: true))

        // Overlapping wrap lapel line (left panel folding across to right side)
        var wrapLine = Path()
        wrapLine.move(to: CGPoint(x: 272, y: 436))
        wrapLine.addQuadCurve(to: CGPoint(x: 314, y: 476), control: CGPoint(x: 294, y: 464))
        wrapLine.addQuadCurve(to: CGPoint(x: 322, y: 498), control: CGPoint(x: 320, y: 488))
        shapes.append(shape(wrapLine, stroke: .slot(.main, .outline), width: 3.5))

        // Crisp white dongjeong silk collar framing the V-neck
        let collarL = smoothClosed([
            CGPoint(x: 268, y: 434),
            CGPoint(x: 279, y: 434),
            CGPoint(x: 309, y: 472),
            CGPoint(x: 299, y: 478),
        ])
        let collarR = smoothClosed([
            CGPoint(x: 321, y: 434),
            CGPoint(x: 332, y: 434),
            CGPoint(x: 312, y: 466),
            CGPoint(x: 304, y: 460),
        ])
        shapes.append(shape(collarR, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#CBB5C4")), width: 3))
        shapes.append(shape(collarL, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#CBB5C4")), width: 3))

        // Delicate gold stitch accent along the lower jeogori hem
        var hemTrim = Path()
        hemTrim.move(to: CGPoint(x: 252, y: 491))
        hemTrim.addQuadCurve(to: CGPoint(x: 348, y: 491), control: CGPoint(x: 300, y: 498))
        shapes.append(shape(hemTrim, stroke: .fixed(RGB(hex: "#F2C14E")), width: 3.2))

        // Traditional goreum silk ribbon tails + single loop bow tied off-center right
        let tailLong = smoothClosed([
            CGPoint(x: 312, y: 480),
            CGPoint(x: 322, y: 480),
            CGPoint(x: 336, y: 544),
            CGPoint(x: 342, y: 584),
            CGPoint(x: 325, y: 580),
            CGPoint(x: 318, y: 534),
        ])
        let tailShort = smoothClosed([
            CGPoint(x: 316, y: 478),
            CGPoint(x: 328, y: 476),
            CGPoint(x: 354, y: 528),
            CGPoint(x: 360, y: 558),
            CGPoint(x: 344, y: 556),
            CGPoint(x: 332, y: 516),
        ])
        let loop = smoothClosed([
            CGPoint(x: 316, y: 476),
            CGPoint(x: 340, y: 466),
            CGPoint(x: 350, y: 478),
            CGPoint(x: 338, y: 492),
            CGPoint(x: 316, y: 482),
        ])
        let knot = Path(ellipseIn: CGRect(x: 307, y: 469, width: 17, height: 18))
        shapes.append(shape(tailShort, fill: .slot(.accent, .shade), stroke: .slot(.accent, .outline), width: 3.2))
        shapes.append(shape(tailLong, fill: .slot(.accent, .base), stroke: .slot(.accent, .outline), width: 3.2))
        shapes.append(shape(loop, fill: .slot(.accent, .base), stroke: .slot(.accent, .outline), width: 3.2))
        shapes.append(shape(knot, fill: .slot(.accent, .light), stroke: .slot(.accent, .outline), width: 3))

        return makeItem(
            id: "t_jeogori",
            category: "top",
            defaultColor: 11,
            accent: RGB(hex: "#F45C9A"),
            patternable: true,
            layers: [ArtLayer(z: 28, shapes: shapes)]
        )
    }

    private static func chima() -> ArtItem {
        var shapes: [ArtShape] = []

        // Soft layered pastel underskirt peeking beneath the billowing hem
        let under = symmetricClosed([
            CGPoint(x: 300, y: 492),
            CGPoint(x: 248, y: 492),
            CGPoint(x: 204, y: 586),
            CGPoint(x: 162, y: 726),
            CGPoint(x: 218, y: 744),
            CGPoint(x: 300, y: 748),
        ])
        shapes.append(shape(under, fill: .slot(.main, .light), stroke: .slot(.main, .outline), width: lw))

        // Main billowing dome-shaped chima overskirt starting at high empire waist
        let mainSkirt = symmetricClosed([
            CGPoint(x: 300, y: 486),
            CGPoint(x: 250, y: 486),
            CGPoint(x: 238, y: 506),
            CGPoint(x: 196, y: 598),
            CGPoint(x: 170, y: 718),
            CGPoint(x: 224, y: 734),
            CGPoint(x: 300, y: 738),
        ])
        shapes.append(shape(mainSkirt, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw, patterned: true))

        // Sheer luminous front silk sheen panel
        let sheen = symmetricClosed([
            CGPoint(x: 300, y: 502),
            CGPoint(x: 266, y: 506),
            CGPoint(x: 236, y: 616),
            CGPoint(x: 226, y: 716),
            CGPoint(x: 300, y: 724),
        ])
        shapes.append(shape(sheen, fill: .slot(.main, .light), opacity: 0.32))

        // Traditional gathered hanbok pleat lines radiating from high waist
        for k in [-0.72, -0.44, -0.16, 0.16, 0.44, 0.72] as [CGFloat] {
            var pleat = Path()
            pleat.move(to: CGPoint(x: cx + k * 48, y: 504))
            pleat.addQuadCurve(
                to: CGPoint(x: cx + k * 124, y: 722),
                control: CGPoint(x: cx + k * 96, y: 610)
            )
            shapes.append(shape(pleat, stroke: .slot(.main, .outline), width: 2.8, opacity: 0.30))
        }

        // Delicate gold geumbak hem ribbon & floral medallion accents
        var goldLineTop = Path()
        goldLineTop.move(to: CGPoint(x: 184, y: 702))
        goldLineTop.addQuadCurve(to: CGPoint(x: 416, y: 702), control: CGPoint(x: 300, y: 726))
        shapes.append(shape(goldLineTop, stroke: .slot(.accent, .base), width: 4.2))

        var goldLineBot = Path()
        goldLineBot.move(to: CGPoint(x: 178, y: 716))
        goldLineBot.addQuadCurve(to: CGPoint(x: 422, y: 716), control: CGPoint(x: 300, y: 740))
        shapes.append(shape(goldLineBot, stroke: .fixed(RGB(hex: "#FFF3B0")), width: 2.6))

        var medallions = Path()
        for i in 0..<7 {
            let u = CGFloat(i) / 6.0
            let mx = 194 + u * 212
            let centered = (u - 0.5) * 2
            let arch = 1 - centered * centered
            let my = 708 + arch * 12
            medallions.addPath(diamond(center: CGPoint(x: mx, y: my), rx: 5.5, ry: 5.5))
        }
        shapes.append(shape(medallions, fill: .fixed(RGB(hex: "#FFF5C0")), stroke: .slot(.accent, .outline), width: 1.8))

        // High empire waist band sitting cleanly under the jeogori
        let band = Path(roundedRect: CGRect(x: 246, y: 482, width: 108, height: 22), cornerRadius: 8)
        shapes.append(shape(band, fill: .slot(.main, .shade), stroke: .slot(.main, .outline), width: 3.5))

        return makeItem(
            id: "b_chima",
            category: "bottom",
            defaultColor: 3,
            accent: RGB(hex: "#F2C14E"),
            patternable: true,
            layers: [ArtLayer(z: 26, shapes: shapes)]
        )
    }

    private static func norigae() -> ArtItem {
        var shapes: [ArtShape] = []
        let ax: CGFloat = 314

        // Top silk cord looping down from the goreum / chima waist
        var cord = Path()
        cord.move(to: CGPoint(x: ax, y: 482))
        cord.addLine(to: CGPoint(x: ax, y: 516))
        shapes.append(shape(cord, stroke: .slot(.accent, .base), width: 4.5))

        // Decorative maedeup butterfly knot
        let knotL = Path(ellipseIn: CGRect(x: ax - 15, y: 506, width: 14, height: 11))
        let knotR = Path(ellipseIn: CGRect(x: ax + 1, y: 506, width: 14, height: 11))
        let knotC = Path(ellipseIn: CGRect(x: ax - 6, y: 505, width: 12, height: 12))
        shapes.append(shape(knotL, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: 2.8))
        shapes.append(shape(knotR, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: 2.8))
        shapes.append(shape(knotC, fill: .slot(.accent, .base), stroke: .slot(.accent, .outline), width: 2.4))

        // Pastel jade blossom medallion centerpiece
        let medallion = flowerPath(center: CGPoint(x: ax, y: 536), radius: 16, petals: 5)
        shapes.append(shape(medallion, fill: .fixed(RGB(hex: "#A8E8CF")), stroke: .fixed(RGB(hex: "#529E84")), width: 3))
        let centerPearl = Path(ellipseIn: CGRect(x: ax - 6, y: 530, width: 12, height: 12))
        shapes.append(shape(centerPearl, fill: .fixed(RGB(hex: "#FFF4C4")), stroke: .slot(.accent, .outline), width: 2.2))

        // Gold tassel cap
        let cap = Path(roundedRect: CGRect(x: ax - 9, y: 552, width: 18, height: 10), cornerRadius: 4)
        shapes.append(shape(cap, fill: .slot(.accent, .base), stroke: .slot(.accent, .outline), width: 2.5))

        // Flowing silk tassel
        let tassel = smoothClosed([
            CGPoint(x: ax - 8, y: 562),
            CGPoint(x: ax + 8, y: 562),
            CGPoint(x: ax + 13, y: 604),
            CGPoint(x: ax, y: 610),
            CGPoint(x: ax - 13, y: 604),
        ])
        shapes.append(shape(tassel, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: 3.2))

        for dx in [-4.5, 0.0, 4.5] as [CGFloat] {
            var thread = Path()
            thread.move(to: CGPoint(x: ax + dx * 0.7, y: 566))
            thread.addLine(to: CGPoint(x: ax + dx, y: 604))
            shapes.append(shape(thread, stroke: .slot(.main, .light), width: 2))
        }

        return makeItem(
            id: "n_norigae",
            category: "neck",
            defaultColor: 18,
            accent: RGB(hex: "#F2C14E"),
            patternable: false,
            layers: [ArtLayer(z: 32, shapes: shapes)]
        )
    }

    private static func jokduri() -> ArtItem {
        var shapes: [ArtShape] = []

        // Sculpted hexagonal satin jokduri coronet perched on crown of head
        let baseBody = smoothClosed([
            CGPoint(x: 266, y: 152),
            CGPoint(x: 256, y: 124),
            CGPoint(x: 274, y: 100),
            CGPoint(x: 300, y: 95),
            CGPoint(x: 326, y: 100),
            CGPoint(x: 344, y: 124),
            CGPoint(x: 334, y: 152),
            CGPoint(x: 300, y: 158),
        ])
        shapes.append(shape(baseBody, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw))

        // Crown top facet highlight
        let facet = smoothClosed([
            CGPoint(x: 276, y: 112),
            CGPoint(x: 300, y: 104),
            CGPoint(x: 324, y: 112),
            CGPoint(x: 318, y: 132),
            CGPoint(x: 282, y: 132),
        ])
        shapes.append(shape(facet, fill: .slot(.main, .light), opacity: 0.45))

        // Golden filigree base rim
        var rim = Path()
        rim.move(to: CGPoint(x: 265, y: 150))
        rim.addQuadCurve(to: CGPoint(x: 335, y: 150), control: CGPoint(x: 300, y: 160))
        shapes.append(shape(rim, stroke: .slot(.accent, .base), width: 6))

        // Jeweled blossom centerpiece + flanking jade & coral gems
        let blossom = flowerPath(center: CGPoint(x: 300, y: 126), radius: 13, petals: 5)
        shapes.append(shape(blossom, fill: .fixed(RGB(hex: "#FF7B9C")), stroke: .slot(.accent, .outline), width: 2.2))
        shapes.append(shape(Path(ellipseIn: CGRect(x: 294, y: 120, width: 12, height: 12)), fill: .fixed(RGB(hex: "#FFE680")), stroke: .slot(.accent, .outline), width: 1.8))

        for dx in [-22.0, 22.0] as [CGFloat] {
            let gem = Path(ellipseIn: CGRect(x: cx + dx - 6, y: 126, width: 12, height: 12))
            shapes.append(shape(gem, fill: .fixed(RGB(hex: "#9FE3CF")), stroke: .slot(.accent, .outline), width: 2))
        }

        // Pearl rim dots + twin dangling gold side ornaments
        var pearls = Path()
        for dx in [-28, -14, 0, 14, 28] as [CGFloat] {
            let py: CGFloat = 148 + (1 - abs(dx) / 30) * 5
            pearls.addEllipse(in: CGRect(x: cx + dx - 4, y: py - 4, width: 8, height: 8))
        }
        shapes.append(shape(pearls, fill: .fixed(RGB(hex: "#FFFDF8")), stroke: .fixed(RGB(hex: "#C8B8C6")), width: 1.8))

        for side in [-1.0, 1.0] as [CGFloat] {
            let x = cx + side * 38
            var drop = Path()
            drop.move(to: CGPoint(x: x - side * 5, y: 138))
            drop.addQuadCurve(to: CGPoint(x: x, y: 162), control: CGPoint(x: x + side * 4, y: 150))
            shapes.append(shape(drop, stroke: .slot(.accent, .base), width: 2.6))
            shapes.append(shape(Path(ellipseIn: CGRect(x: x - 4.5, y: 160, width: 9, height: 9)), fill: .fixed(RGB(hex: "#FFF5C4")), stroke: .slot(.accent, .outline), width: 1.8))
        }

        return makeItem(
            id: "h_jokduri",
            category: "hat",
            defaultColor: 19,
            accent: RGB(hex: "#F2C14E"),
            patternable: false,
            layers: [ArtLayer(z: 60, shapes: shapes)]
        )
    }

    private static func daenggi() -> ArtItem {
        // Flowing silk ribbon streamers hanging gracefully behind her hair
        var backShapes: [ArtShape] = []
        for side in [-1.0, 1.0] as [CGFloat] {
            let ribbon = mirrored(
                smoothClosed([
                    CGPoint(x: 266, y: 166),
                    CGPoint(x: 242, y: 180),
                    CGPoint(x: 214, y: 318),
                    CGPoint(x: 196, y: 446),
                    CGPoint(x: 222, y: 472),
                    CGPoint(x: 244, y: 438),
                    CGPoint(x: 262, y: 318),
                    CGPoint(x: 282, y: 182),
                ]),
                flip: side > 0
            )
            backShapes.append(shape(ribbon, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw))

            // Stamped gold geumbak flower & star motifs on each ribbon tail
            var stamps = Path()
            for (sx, sy) in [(236.0, 326.0), (222.0, 390.0), (216.0, 434.0)] as [(CGFloat, CGFloat)] {
                let px = side > 0 ? 2 * cx - sx : sx
                stamps.addPath(flowerPath(center: CGPoint(x: px, y: sy), radius: 9, petals: 5))
            }
            backShapes.append(shape(stamps, fill: .fixed(RGB(hex: "#FFE680")), stroke: .slot(.accent, .outline), width: 1.6))
        }

        // Front pleated crown ribbon bow resting at the top of her hair
        var frontShapes: [ArtShape] = []
        for side in [-1.0, 1.0] as [CGFloat] {
            let wing = mirrored(
                smoothClosed([
                    CGPoint(x: 294, y: 146),
                    CGPoint(x: 256, y: 122),
                    CGPoint(x: 238, y: 144),
                    CGPoint(x: 256, y: 166),
                    CGPoint(x: 294, y: 154),
                ]),
                flip: side > 0
            )
            frontShapes.append(shape(wing, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: 3.8))

            let fold = mirrored(
                Path { p in
                    p.move(to: CGPoint(x: 288, y: 148))
                    p.addQuadCurve(to: CGPoint(x: 256, y: 144), control: CGPoint(x: 272, y: 142))
                },
                flip: side > 0
            )
            frontShapes.append(shape(fold, stroke: .slot(.main, .light), width: 3))
        }
        let knot = Path(roundedRect: CGRect(x: 287, y: 136, width: 26, height: 26), cornerRadius: 9)
        frontShapes.append(shape(knot, fill: .slot(.main, .shade), stroke: .slot(.main, .outline), width: 3.4))
        let jewel = Path(ellipseIn: CGRect(x: 294, y: 143, width: 12, height: 12))
        frontShapes.append(shape(jewel, fill: .fixed(RGB(hex: "#FFE680")), stroke: .slot(.accent, .outline), width: 2))

        return makeItem(
            id: "h_daenggi",
            category: "hat",
            defaultColor: 4,
            accent: RGB(hex: "#F2C14E"),
            patternable: false,
            layers: [ArtLayer(z: 8, shapes: backShapes), ArtLayer(z: 60, shapes: frontShapes)],
            customThumb: CGRect(x: 170, y: 108, width: 260, height: 374)
        )
    }

    // MARK: - Heart-Jewel Magical Fairy / K-Pop Star Collection

    private static func jewelFairyDress() -> ArtItem {
        var shapes: [ArtShape] = []

        // Tier 1 (lowest): Iridescent pastel scalloped petticoat underskirt
        let petticoat = scallopedSkirt(topY: 506, hemY: 656, halfWidth: 126, scallop: 13, lobes: 8)
        shapes.append(shape(petticoat, gradient: (.slot(.accent, .light), .slot(.accent, .base)), stroke: .slot(.accent, .outline), width: lw))

        // Tier 2 (middle): Fluffy cream lace frill layer
        let laceTier = scallopedSkirt(topY: 504, hemY: 634, halfWidth: 112, scallop: 11, lobes: 8)
        shapes.append(shape(laceTier, fill: .fixed(RGB(hex: "#FFF6FB")), stroke: .fixed(RGB(hex: "#D9AEC8")), width: 3.8))

        // Tier 3 (top): Petal-scalloped idol overskirt (patternable)
        let overSkirt = scallopedSkirt(topY: 500, hemY: 612, halfWidth: 102, scallop: 14, lobes: 6)
        shapes.append(shape(overSkirt, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw, patterned: true))

        // Golden star charms twinkling on the overskirt petals
        var skirtStars = Path()
        for dx in [-68, -24, 24, 68] as [CGFloat] {
            let sy: CGFloat = abs(dx) > 40 ? 590 : 598
            skirtStars.addPath(starPath(center: CGPoint(x: cx + dx, y: sy), outer: 8.5, inner: 4.2))
        }
        shapes.append(shape(skirtStars, fill: .fixed(RGB(hex: "#FFE680")), stroke: .fixed(RGB(hex: "#D69A2A")), width: 1.8))

        // Puffed ruffled idol sleeves
        for side in [-1.0, 1.0] as [CGFloat] {
            let sx = cx + side * 52
            let puff = Path(ellipseIn: CGRect(x: sx - 28, y: 432, width: 56, height: 46))
            shapes.append(shape(puff, fill: .slot(.main, .light), stroke: .slot(.main, .outline), width: lw, patterned: true))
            let frill = Path(ellipseIn: CGRect(x: sx - 20, y: 466, width: 40, height: 14))
            shapes.append(shape(frill, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#D5B5C9")), width: 2.6))
        }

        // Sweetheart idol bodice
        let bodice = symmetricClosed([
            CGPoint(x: 300, y: 454),
            CGPoint(x: 278, y: 440),
            CGPoint(x: 256, y: 444),
            CGPoint(x: 243, y: 462),
            CGPoint(x: 244, y: 496),
            CGPoint(x: 246, y: 514),
            CGPoint(x: 300, y: 520),
        ])
        shapes.append(shape(bodice, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw, patterned: true))

        // White lace sweetheart collar trim
        var collar = Path()
        collar.move(to: CGPoint(x: 254, y: 448))
        collar.addQuadCurve(to: CGPoint(x: 300, y: 460), control: CGPoint(x: 276, y: 442))
        collar.addQuadCurve(to: CGPoint(x: 346, y: 448), control: CGPoint(x: 324, y: 442))
        shapes.append(shape(collar, stroke: .fixed(RGB(hex: "#FFFFFF")), width: 6.5))

        // Ribbon waist sash + flowing fairy bow tails
        let sash = Path(roundedRect: CGRect(x: 240, y: 504, width: 120, height: 18), cornerRadius: 9)
        shapes.append(shape(sash, fill: .slot(.accent, .base), stroke: .slot(.accent, .outline), width: 3.5))
        shapes.append(contentsOf: ribbonBow(center: CGPoint(x: 300, y: 513), scale: 0.82, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#D5B0C8"))))

        // Radiant central faceted Heart Brooch on chest with gold halo bezel
        let halo = heartPath(center: CGPoint(x: 300, y: 472), halfWidth: 18)
        shapes.append(shape(halo, fill: .fixed(RGB(hex: "#FFE37A")), stroke: .fixed(RGB(hex: "#C98F1E")), width: 2.8))
        let gem = heartPath(center: CGPoint(x: 300, y: 472), halfWidth: 13)
        shapes.append(shape(gem, gradient: (.fixed(RGB(hex: "#FF5D9E")), .fixed(RGB(hex: "#FFB5D6"))), stroke: .fixed(RGB(hex: "#B52B66")), width: 2))
        let glint = Path(ellipseIn: CGRect(x: 292, y: 464, width: 7, height: 5))
        shapes.append(shape(glint, fill: .fixed(RGB(hex: "#FFFFFF")), opacity: 0.88))

        return makeItem(
            id: "d_jewelfairy",
            category: "dress",
            defaultColor: 3,
            accent: RGB(hex: "#D2C0FF"),
            patternable: true,
            layers: [ArtLayer(z: 27, shapes: shapes)]
        )
    }

    private static func heartTiara() -> ArtItem {
        var shapes: [ArtShape] = []

        // Sweeping golden filigree crown arch
        var band = Path()
        band.move(to: CGPoint(x: 212, y: 174))
        band.addQuadCurve(to: CGPoint(x: 300, y: 134), control: CGPoint(x: 254, y: 140))
        band.addQuadCurve(to: CGPoint(x: 388, y: 174), control: CGPoint(x: 346, y: 140))
        shapes.append(shape(band, stroke: .fixed(RGB(hex: "#C98F1E")), width: 10))
        shapes.append(shape(band, stroke: .fixed(RGB(hex: "#FFE27A")), width: 5.5))

        // Golden filigree side loops framing the central heart gem
        for side in [-1.0, 1.0] as [CGFloat] {
            let scroll = mirrored(
                smoothClosed([
                    CGPoint(x: 284, y: 140),
                    CGPoint(x: 260, y: 118),
                    CGPoint(x: 244, y: 134),
                    CGPoint(x: 258, y: 152),
                ]),
                flip: side > 0
            )
            shapes.append(shape(scroll, stroke: .fixed(RGB(hex: "#E6AE35")), width: 4.2))
            let pearl = Path(ellipseIn: CGRect(x: cx + side * 44 - 5.5, y: 134, width: 11, height: 11))
            shapes.append(shape(pearl, fill: .fixed(RGB(hex: "#FFFDF8")), stroke: .fixed(RGB(hex: "#C99B3B")), width: 2))
            let miniStar = starPath(center: CGPoint(x: cx + side * 68, y: 148), outer: 9, inner: 4)
            shapes.append(shape(miniStar, fill: .fixed(RGB(hex: "#FFF7C2")), stroke: .fixed(RGB(hex: "#D69A2A")), width: 1.8))
        }

        // Gold winged bezel + central faceted heart gem
        let bezel = heartPath(center: CGPoint(x: 300, y: 120), halfWidth: 23)
        shapes.append(shape(bezel, fill: .fixed(RGB(hex: "#FFE066")), stroke: .fixed(RGB(hex: "#C28718")), width: 3.2))
        let gem = heartPath(center: CGPoint(x: 300, y: 120), halfWidth: 16.5)
        shapes.append(shape(gem, gradient: (.slot(.main, .light), .slot(.main, .base)), stroke: .slot(.main, .outline), width: 2.4))
        let sheen = Path(ellipseIn: CGRect(x: 290, y: 110, width: 9, height: 6))
        shapes.append(shape(sheen, fill: .fixed(RGB(hex: "#FFFFFF")), opacity: 0.9))

        return makeItem(
            id: "h_hearttiara",
            category: "hat",
            defaultColor: 4,
            accent: RGB(hex: "#FFE27A"),
            patternable: false,
            layers: [ArtLayer(z: 60, shapes: shapes)]
        )
    }

    private static func jewelWings() -> ArtItem {
        var shapes: [ArtShape] = []

        for side in [-1.0, 1.0] as [CGFloat] {
            let flip = side > 0
            // Upper sweeping scalloped fairy wing with iridescent translucent gradient
            let upper = mirrored(
                smoothClosed([
                    CGPoint(x: 288, y: 466),
                    CGPoint(x: 222, y: 368),
                    CGPoint(x: 130, y: 312),
                    CGPoint(x: 78, y: 356),
                    CGPoint(x: 92, y: 422),
                    CGPoint(x: 152, y: 468),
                    CGPoint(x: 244, y: 486),
                ]),
                flip: flip
            )
            shapes.append(shape(upper, gradient: (.slot(.main, .light), .slot(.accent, .base)), stroke: .slot(.main, .outline), width: 4, opacity: 0.80))

            // Inner iridescent sheen petal inside upper wing
            let upperInner = mirrored(
                smoothClosed([
                    CGPoint(x: 270, y: 464),
                    CGPoint(x: 214, y: 388),
                    CGPoint(x: 138, y: 344),
                    CGPoint(x: 112, y: 382),
                    CGPoint(x: 160, y: 446),
                ]),
                flip: flip
            )
            shapes.append(shape(upperInner, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#FFFFFF")), width: 2.2, opacity: 0.42))

            // Lower teardrop crystal wing
            let lower = mirrored(
                smoothClosed([
                    CGPoint(x: 286, y: 486),
                    CGPoint(x: 196, y: 506),
                    CGPoint(x: 136, y: 576),
                    CGPoint(x: 162, y: 620),
                    CGPoint(x: 226, y: 602),
                    CGPoint(x: 276, y: 534),
                ]),
                flip: flip
            )
            shapes.append(shape(lower, gradient: (.slot(.accent, .light), .slot(.main, .base)), stroke: .slot(.main, .outline), width: 4, opacity: 0.78))

            // Luminous heart gem & star sparkles perched on each wing
            let gx = flip ? 2 * cx - 134 : 134
            let hx = flip ? 2 * cx - 176 : 176
            shapes.append(shape(heartPath(center: CGPoint(x: gx, y: 378), halfWidth: 11), fill: .fixed(RGB(hex: "#FF8FC4")), stroke: .fixed(RGB(hex: "#FFFFFF")), width: 2.2, opacity: 0.92))
            shapes.append(shape(starPath(center: CGPoint(x: hx, y: 574), outer: 11, inner: 4.5), fill: .fixed(RGB(hex: "#FFF6B8")), stroke: .fixed(RGB(hex: "#FFFFFF")), width: 2, opacity: 0.92))
        }

        return makeItem(
            id: "w_jewelwings",
            category: "back",
            defaultColor: 18,
            accent: RGB(hex: "#A8E8CF"),
            patternable: false,
            layers: [ArtLayer(z: 5, shapes: shapes)]
        )
    }

    private static func starlightWand() -> ArtItem {
        var shapes: [ArtShape] = []
        let h = handR

        // Pearl-gold scepter shaft
        var shaft = Path()
        shaft.move(to: CGPoint(x: h.x - 6, y: h.y + 24))
        shaft.addLine(to: CGPoint(x: h.x + 48, y: h.y - 110))
        shapes.append(shape(shaft, stroke: .fixed(RGB(hex: "#C78E26")), width: 12))
        shapes.append(shape(shaft, stroke: .fixed(RGB(hex: "#FFF2B2")), width: 6.5))

        // Cute pastel ribbon bow tied below the wand head
        shapes.append(contentsOf: ribbonBow(center: CGPoint(x: h.x + 30, y: h.y - 66), scale: 0.72, fill: .slot(.main, .base), stroke: .slot(.main, .outline)))

        // Miniature pearl wings flanking the wand crystal
        let head = CGPoint(x: h.x + 54, y: h.y - 126)
        for side in [-1.0, 1.0] as [CGFloat] {
            let wing = smoothClosed([
                CGPoint(x: head.x + side * 12, y: head.y + 4),
                CGPoint(x: head.x + side * 44, y: head.y - 18),
                CGPoint(x: head.x + side * 48, y: head.y + 2),
                CGPoint(x: head.x + side * 32, y: head.y + 18),
            ])
            shapes.append(shape(wing, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#C9B8D8")), width: 2.8))
        }

        // Golden starlight frame + central pink heart crystal
        let outerStar = starPath(center: head, outer: 32, inner: 15)
        shapes.append(shape(outerStar, fill: .fixed(RGB(hex: "#FFE37A")), stroke: .fixed(RGB(hex: "#C98F1E")), width: 3.4))
        let crystal = heartPath(center: CGPoint(x: head.x, y: head.y + 1), halfWidth: 14)
        shapes.append(shape(crystal, gradient: (.slot(.main, .light), .slot(.main, .base)), stroke: .slot(.main, .outline), width: 2.2))

        // Orbiting twinkle sparks
        shapes.append(shape(fourPointStar(center: CGPoint(x: head.x + 38, y: head.y - 36), radius: 9), fill: .fixed(RGB(hex: "#FFFFFF"))))
        shapes.append(shape(fourPointStar(center: CGPoint(x: head.x - 36, y: head.y - 26), radius: 7), fill: .fixed(RGB(hex: "#FFF3B0"))))

        // Right hand drawn over grip
        let hand = Path(ellipseIn: CGRect(x: h.x - 18, y: h.y - 18, width: 36, height: 36))
        shapes.append(shape(hand, fill: .slot(.skin, .base), stroke: .slot(.skin, .outline), width: lw))

        return makeItem(
            id: "p_starwand",
            category: "hold",
            defaultColor: 4,
            accent: RGB(hex: "#FFE27A"),
            patternable: false,
            layers: [ArtLayer(z: 70, shapes: shapes)]
        )
    }

    private static func heartCompact() -> ArtItem {
        var shapes: [ArtShape] = []
        let h = handR
        let c = CGPoint(x: h.x + 38, y: h.y - 26)

        // Delicate gold wrist strap loop
        var strap = Path()
        strap.move(to: CGPoint(x: h.x, y: h.y + 4))
        strap.addQuadCurve(to: CGPoint(x: c.x - 14, y: c.y + 20), control: CGPoint(x: h.x + 8, y: h.y + 28))
        shapes.append(shape(strap, stroke: .fixed(RGB(hex: "#E8B03C")), width: 4))

        // Tiny magical fairy wings on the sides of the compact
        for side in [-1.0, 1.0] as [CGFloat] {
            let wing = smoothClosed([
                CGPoint(x: c.x + side * 26, y: c.y - 4),
                CGPoint(x: c.x + side * 50, y: c.y - 20),
                CGPoint(x: c.x + side * 52, y: c.y + 2),
                CGPoint(x: c.x + side * 34, y: c.y + 12),
            ])
            shapes.append(shape(wing, fill: .fixed(RGB(hex: "#FFF9FD")), stroke: .fixed(RGB(hex: "#D2B8DC")), width: 2.8))
        }

        // Gold bezel heart compact case
        let goldShell = heartPath(center: c, halfWidth: 38)
        shapes.append(shape(goldShell, fill: .fixed(RGB(hex: "#FFE066")), stroke: .fixed(RGB(hex: "#C78E1C")), width: 3.8))

        // Enamel pastel compact lid
        let enamel = heartPath(center: c, halfWidth: 31)
        shapes.append(shape(enamel, gradient: (.slot(.main, .light), .slot(.main, .base)), stroke: .slot(.main, .outline), width: 2.5))

        // Central raised heart jewel emblem + white star glint
        let gem = heartPath(center: CGPoint(x: c.x, y: c.y + 1), halfWidth: 16)
        shapes.append(shape(gem, gradient: (.fixed(RGB(hex: "#FFF5FA")), .fixed(RGB(hex: "#FF5D9E"))), stroke: .fixed(RGB(hex: "#C43572")), width: 2.2))

        var pearls = Path()
        for (dx, dy) in [(-18.0, -14.0), (18.0, -14.0), (0.0, 22.0)] as [(CGFloat, CGFloat)] {
            pearls.addEllipse(in: CGRect(x: c.x + dx - 3.5, y: c.y + dy - 3.5, width: 7, height: 7))
        }
        shapes.append(shape(pearls, fill: .fixed(RGB(hex: "#FFFFFF")), stroke: .fixed(RGB(hex: "#D69E2E")), width: 1.5))

        shapes.append(shape(fourPointStar(center: CGPoint(x: c.x - 32, y: c.y - 34), radius: 8), fill: .fixed(RGB(hex: "#FFFFFF"))))
        shapes.append(shape(fourPointStar(center: CGPoint(x: c.x + 36, y: c.y - 30), radius: 7), fill: .fixed(RGB(hex: "#FFF3B0"))))

        // Right hand cradling the compact
        let hand = Path(ellipseIn: CGRect(x: h.x - 18, y: h.y - 18, width: 36, height: 36))
        shapes.append(shape(hand, fill: .slot(.skin, .base), stroke: .slot(.skin, .outline), width: lw))

        return makeItem(
            id: "p_heartcompact",
            category: "hold",
            defaultColor: 3,
            accent: RGB(hex: "#FFE27A"),
            patternable: false,
            layers: [ArtLayer(z: 70, shapes: shapes)]
        )
    }

    // MARK: - Treasure Shop Exclusive Royal Pieces

    private static func hanbokCrown() -> ArtItem {
        var shapes: [ArtShape] = []
        let goldLight = RGB(hex: "#FFF4B0")
        let gold = RGB(hex: "#F7C948")
        let goldOutline = RGB(hex: "#B87E1E")
        let pearl = RGB(hex: "#FFFDF8")
        let pearlOutline = RGB(hex: "#CEB8CC")

        // Sweeping royal golden filigree crest arches behind the jokduri
        for side in [-1.0, 1.0] as [CGFloat] {
            let crest = mirrored(
                smoothClosed([
                    CGPoint(x: 274, y: 146),
                    CGPoint(x: 238, y: 126),
                    CGPoint(x: 246, y: 102),
                    CGPoint(x: 276, y: 112),
                ]),
                flip: side > 0
            )
            shapes.append(shape(crest, gradient: (.fixed(goldLight), .fixed(gold)), stroke: .fixed(goldOutline), width: 3.4))

            let jadeLeaf = mirrored(
                smoothClosed([
                    CGPoint(x: 280, y: 120),
                    CGPoint(x: 256, y: 110),
                    CGPoint(x: 250, y: 124),
                    CGPoint(x: 274, y: 130),
                ]),
                flip: side > 0
            )
            shapes.append(shape(jadeLeaf, fill: .fixed(RGB(hex: "#9FE3CF")), stroke: .fixed(RGB(hex: "#4C9C84")), width: 2.2))
        }

        // Tall gilded lotus-bud crest rising at the crown apex
        let spire = smoothClosed([
            CGPoint(x: 288, y: 102),
            CGPoint(x: 300, y: 74),
            CGPoint(x: 312, y: 102),
            CGPoint(x: 300, y: 110),
        ])
        shapes.append(shape(spire, gradient: (.fixed(goldLight), .fixed(gold)), stroke: .fixed(goldOutline), width: 3))
        shapes.append(shape(Path(ellipseIn: CGRect(x: 294, y: 68, width: 12, height: 12)), fill: .fixed(pearl), stroke: .fixed(goldOutline), width: 2))

        // Sculpted ceremonial royal satin jokduri body (recolorable via .main)
        let body = smoothClosed([
            CGPoint(x: 260, y: 152),
            CGPoint(x: 250, y: 120),
            CGPoint(x: 272, y: 94),
            CGPoint(x: 300, y: 88),
            CGPoint(x: 328, y: 94),
            CGPoint(x: 350, y: 120),
            CGPoint(x: 340, y: 152),
            CGPoint(x: 300, y: 160),
        ])
        shapes.append(shape(body, fill: .slot(.main, .base), stroke: .slot(.main, .outline), width: lw))

        // Golden filigree crown lattice & satin top highlight
        let facet = smoothClosed([
            CGPoint(x: 274, y: 108),
            CGPoint(x: 300, y: 98),
            CGPoint(x: 326, y: 108),
            CGPoint(x: 320, y: 132),
            CGPoint(x: 280, y: 132),
        ])
        shapes.append(shape(facet, fill: .slot(.main, .light), stroke: .fixed(gold), width: 2.6, opacity: 0.72))

        // Gleaming curved gold headband rim
        var rim = Path()
        rim.move(to: CGPoint(x: 256, y: 149))
        rim.addQuadCurve(to: CGPoint(x: 344, y: 149), control: CGPoint(x: 300, y: 163))
        shapes.append(shape(rim, stroke: .fixed(goldOutline), width: 10))
        shapes.append(shape(rim, stroke: .fixed(gold), width: 6))

        // Central royal plum blossom jewel + golden pearl center
        let outerBlossom = flowerPath(center: CGPoint(x: 300, y: 121), radius: 18, petals: 5)
        shapes.append(shape(outerBlossom, fill: .fixed(RGB(hex: "#FFB0CE")), stroke: .fixed(goldOutline), width: 2.4))
        let innerBlossom = flowerPath(center: CGPoint(x: 300, y: 121), radius: 11, petals: 5)
        shapes.append(shape(innerBlossom, fill: .fixed(RGB(hex: "#FF66A4")), stroke: .fixed(RGB(hex: "#C43572")), width: 1.8))
        shapes.append(shape(Path(ellipseIn: CGRect(x: 294, y: 115, width: 12, height: 12)), fill: .fixed(goldLight), stroke: .fixed(goldOutline), width: 1.8))

        // Flanking pearl & blossom medallions on crown rim
        var rimPearls = Path()
        for dx in [-36, -22, -10, 0, 10, 22, 36] as [CGFloat] {
            let py: CGFloat = 148 + (1 - abs(dx) / 42) * 6.5
            rimPearls.addEllipse(in: CGRect(x: cx + dx - 4.5, y: py - 4.5, width: 9, height: 9))
        }
        shapes.append(shape(rimPearls, fill: .fixed(pearl), stroke: .fixed(pearlOutline), width: 1.8))

        // Cascading twin pearl-bead side drop strands (royal tteoljam drops)
        for side in [-1.0, 1.0] as [CGFloat] {
            let xTop = cx + side * 42
            let xBot = cx + side * 49
            var cord = Path()
            cord.move(to: CGPoint(x: xTop, y: 138))
            cord.addQuadCurve(to: CGPoint(x: xBot, y: 188), control: CGPoint(x: xBot + side * 4, y: 162))
            shapes.append(shape(cord, stroke: .fixed(gold), width: 3))

            for step in 0..<4 {
                let u = CGFloat(step) / 3.0
                let bx = xTop + (xBot - xTop) * u + side * sin(u * .pi) * 2
                let by = 144 + u * 34
                let r: CGFloat = step == 3 ? 5.5 : 4.2
                shapes.append(shape(Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)), fill: .fixed(pearl), stroke: .fixed(pearlOutline), width: 1.6))
            }
            let dropBlossom = flowerPath(center: CGPoint(x: xBot, y: 190), radius: 8.5, petals: 5)
            shapes.append(shape(dropBlossom, fill: .fixed(RGB(hex: "#FF88BA")), stroke: .fixed(goldOutline), width: 1.6))
        }

        shapes.append(shape(fourPointStar(center: CGPoint(x: 262, y: 92), radius: 7.5), fill: .fixed(RGB(hex: "#FFFFFF"))))
        shapes.append(shape(fourPointStar(center: CGPoint(x: 338, y: 90), radius: 7.5), fill: .fixed(goldLight)))

        return makeItem(
            id: "h_hanbokCrown",
            category: "hat",
            defaultColor: 19,
            accent: gold,
            patternable: false,
            layers: [ArtLayer(z: 60, shapes: shapes)]
        )
    }

    private static func fairyWand() -> ArtItem {
        var shapes: [ArtShape] = []
        let h = handR
        let head = CGPoint(x: h.x + 56, y: h.y - 132)
        let goldLight = RGB(hex: "#FFF5B8")
        let gold = RGB(hex: "#FFD45A")
        let goldOutline = RGB(hex: "#C78E24")

        // Pearlescent pastel wand shaft + golden heart pommel at bottom
        var shaft = Path()
        shaft.move(to: CGPoint(x: h.x - 10, y: h.y + 32))
        shaft.addLine(to: CGPoint(x: head.x - 4, y: head.y + 12))
        shapes.append(shape(shaft, stroke: .fixed(RGB(hex: "#C888B8")), width: 13))
        shapes.append(shape(shaft, stroke: .fixed(RGB(hex: "#FFE6F4")), width: 7.5))
        shapes.append(shape(shaft, stroke: .fixed(RGB(hex: "#FFFFFF")), width: 2.6, opacity: 0.78))

        let pommel = heartPath(center: CGPoint(x: h.x - 12, y: h.y + 37), halfWidth: 11)
        shapes.append(shape(pommel, fill: .fixed(gold), stroke: .fixed(goldOutline), width: 2.4))

        // Flowing pastel ribbon bow & curling fairy streamers beneath wand head
        let bowCenter = CGPoint(x: h.x + 34, y: h.y - 74)
        for side in [-1.0, 1.0] as [CGFloat] {
            var streamer = Path()
            streamer.move(to: CGPoint(x: bowCenter.x + side * 4, y: bowCenter.y + 6))
            streamer.addCurve(
                to: CGPoint(x: bowCenter.x + side * 26, y: bowCenter.y + 52),
                control1: CGPoint(x: bowCenter.x + side * 24, y: bowCenter.y + 20),
                control2: CGPoint(x: bowCenter.x + side * 6, y: bowCenter.y + 38)
            )
            shapes.append(shape(streamer, stroke: .slot(.main, .outline), width: 8.5))
            shapes.append(shape(streamer, stroke: .slot(.main, .light), width: 4.5))
        }
        shapes.append(contentsOf: ribbonBow(center: bowCenter, scale: 0.78, fill: .slot(.main, .base), stroke: .slot(.main, .outline)))

        // Layered iridescent double fairy wings flanking the heart crystal
        for side in [-1.0, 1.0] as [CGFloat] {
            let upperWing = smoothClosed([
                CGPoint(x: head.x + side * 14, y: head.y + 4),
                CGPoint(x: head.x + side * 52, y: head.y - 32),
                CGPoint(x: head.x + side * 66, y: head.y - 8),
                CGPoint(x: head.x + side * 50, y: head.y + 14),
                CGPoint(x: head.x + side * 20, y: head.y + 12),
            ])
            shapes.append(shape(upperWing, gradient: (.fixed(RGB(hex: "#FFFFFF")), .fixed(RGB(hex: "#D6F4FF"))), stroke: .fixed(RGB(hex: "#B5A2E0")), width: 3, opacity: 0.92))

            let lowerWing = smoothClosed([
                CGPoint(x: head.x + side * 14, y: head.y + 10),
                CGPoint(x: head.x + side * 46, y: head.y + 14),
                CGPoint(x: head.x + side * 42, y: head.y + 34),
                CGPoint(x: head.x + side * 20, y: head.y + 26),
            ])
            shapes.append(shape(lowerWing, gradient: (.fixed(RGB(hex: "#FFF5FC")), .fixed(RGB(hex: "#E6D2FF"))), stroke: .fixed(RGB(hex: "#B5A2E0")), width: 2.6, opacity: 0.90))
        }

        // Golden heart halo crown enclosing a faceted heart crystal
        let crownHalo = heartPath(center: head, halfWidth: 32)
        shapes.append(shape(crownHalo, gradient: (.fixed(goldLight), .fixed(gold)), stroke: .fixed(goldOutline), width: 3.4))

        let crystal = heartPath(center: CGPoint(x: head.x, y: head.y + 1), halfWidth: 22)
        shapes.append(shape(crystal, gradient: (.slot(.main, .light), .slot(.main, .base)), stroke: .slot(.main, .outline), width: 2.6))

        let innerFacet = heartPath(center: CGPoint(x: head.x - 1, y: head.y - 1), halfWidth: 11)
        shapes.append(shape(innerFacet, fill: .fixed(RGB(hex: "#FFFFFF")), opacity: 0.36))
        shapes.append(shape(Path(ellipseIn: CGRect(x: head.x - 13, y: head.y - 12, width: 10, height: 6.5)), fill: .fixed(RGB(hex: "#FFFFFF")), opacity: 0.9))

        // Tiny golden crown crest perched above the heart crystal
        let miniStar = starPath(center: CGPoint(x: head.x, y: head.y - 31), outer: 11, inner: 5)
        shapes.append(shape(miniStar, fill: .fixed(goldLight), stroke: .fixed(goldOutline), width: 2))

        // Orbiting sparkling starlight gleams
        shapes.append(shape(fourPointStar(center: CGPoint(x: head.x + 52, y: head.y - 42), radius: 10), fill: .fixed(RGB(hex: "#FFFFFF"))))
        shapes.append(shape(fourPointStar(center: CGPoint(x: head.x - 46, y: head.y - 34), radius: 8.5), fill: .fixed(goldLight)))
        shapes.append(shape(fourPointStar(center: CGPoint(x: head.x + 54, y: head.y + 26), radius: 7), fill: .fixed(RGB(hex: "#FFD4EC"))))

        // Right hand drawn over the grip
        let hand = Path(ellipseIn: CGRect(x: h.x - 18, y: h.y - 18, width: 36, height: 36))
        shapes.append(shape(hand, fill: .slot(.skin, .base), stroke: .slot(.skin, .outline), width: lw))

        return makeItem(
            id: "p_fairyWand",
            category: "hold",
            defaultColor: 4,
            accent: gold,
            patternable: false,
            layers: [ArtLayer(z: 70, shapes: shapes)]
        )
    }

    // MARK: - Geometry Builders

    private static func shape(
        _ path: Path,
        fill: Paint? = nil,
        gradient: (Paint, Paint)? = nil,
        stroke: Paint? = nil,
        width: CGFloat = 4,
        opacity: Double = 1,
        patterned: Bool = false
    ) -> ArtShape {
        ArtShape(
            path: path,
            bounds: path.boundingRect,
            fill: fill,
            gradient: gradient,
            stroke: stroke,
            width: width,
            opacity: opacity,
            patterned: patterned
        )
    }

    private static func makeItem(
        id: String,
        category: String,
        defaultColor: Int,
        accent: RGB,
        patternable: Bool,
        layers: [ArtLayer],
        customThumb: CGRect? = nil
    ) -> ArtItem {
        var box = CGRect.null
        for layer in layers {
            for s in layer.shapes {
                let pad = s.stroke != nil ? s.width / 2 : 0
                box = box.union(s.bounds.insetBy(dx: -pad, dy: -pad))
            }
        }
        let thumb: CGRect
        if let customThumb {
            thumb = customThumb
        } else if box.isNull {
            thumb = CGRect(x: 200, y: 300, width: 200, height: 200)
        } else {
            let side = max(box.width, box.height) * 1.12
            thumb = CGRect(x: box.midX - side / 2, y: box.midY - side / 2, width: side, height: side)
        }
        return ArtItem(
            id: id,
            category: category,
            colorSource: .own,
            defaultColor: defaultColor,
            accent: accent,
            patternable: patternable,
            layers: layers,
            thumb: thumb,
            onHead: false
        )
    }

    private static func mirrored(_ path: Path, flip: Bool) -> Path {
        guard flip else { return path }
        let t = CGAffineTransform(translationX: cx, y: 0)
            .scaledBy(x: -1, y: 1)
            .translatedBy(x: -cx, y: 0)
        return path.applying(t)
    }

    private static func symmetricClosed(_ leftHalf: [CGPoint], tension: CGFloat = 1.0) -> Path {
        let right = leftHalf.dropFirst().dropLast().reversed().map { CGPoint(x: 2 * cx - $0.x, y: $0.y) }
        return smoothClosed(leftHalf + right, tension: tension)
    }

    private static func smoothClosed(_ pts: [CGPoint], tension: CGFloat = 1.0) -> Path {
        var p = Path()
        let n = pts.count
        guard n >= 3 else { return p }
        p.move(to: pts[0])
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n]
            let p1 = pts[i]
            let p2 = pts[(i + 1) % n]
            let p3 = pts[(i + 2) % n]
            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6 * tension,
                y: p1.y + (p2.y - p0.y) / 6 * tension
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6 * tension,
                y: p2.y - (p3.y - p1.y) / 6 * tension
            )
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        p.closeSubpath()
        return p
    }

    private static func scallopedSkirt(topY: CGFloat, hemY: CGFloat, halfWidth: CGFloat, scallop: CGFloat, lobes: Int) -> Path {
        var p = Path()
        let leftTop = CGPoint(x: cx - 50, y: topY)
        let rightTop = CGPoint(x: cx + 50, y: topY)
        let leftHem = CGPoint(x: cx - halfWidth, y: hemY)
        let rightHem = CGPoint(x: cx + halfWidth, y: hemY)

        p.move(to: leftTop)
        p.addQuadCurve(to: leftHem, control: CGPoint(x: cx - 56 - halfWidth * 0.35, y: (topY + hemY) * 0.5))

        let totalW = halfWidth * 2
        let step = totalW / CGFloat(lobes)
        for i in 0..<lobes {
            let x0 = leftHem.x + CGFloat(i) * step
            let x1 = x0 + step
            let midX = (x0 + x1) * 0.5
            p.addQuadCurve(to: CGPoint(x: x1, y: hemY), control: CGPoint(x: midX, y: hemY + scallop))
        }

        p.addQuadCurve(to: rightTop, control: CGPoint(x: cx + 56 + halfWidth * 0.35, y: (topY + hemY) * 0.5))
        p.closeSubpath()
        return p
    }

    private static func ribbonBow(center c: CGPoint, scale s: CGFloat, fill: Paint, stroke: Paint) -> [ArtShape] {
        var out: [ArtShape] = []
        for side in [-1.0, 1.0] as [CGFloat] {
            let tail = smoothClosed([
                CGPoint(x: c.x + side * 3 * s, y: c.y + 2 * s),
                CGPoint(x: c.x + side * 16 * s, y: c.y + 30 * s),
                CGPoint(x: c.x + side * 7 * s, y: c.y + 33 * s),
                CGPoint(x: c.x - side * 1 * s, y: c.y + 7 * s),
            ], tension: 0.6)
            out.append(shape(tail, fill: fill, stroke: stroke, width: 3))
        }
        for side in [-1.0, 1.0] as [CGFloat] {
            let wing = smoothClosed([
                c,
                CGPoint(x: c.x + side * 22 * s, y: c.y - 15 * s),
                CGPoint(x: c.x + side * 30 * s, y: c.y),
                CGPoint(x: c.x + side * 22 * s, y: c.y + 15 * s),
            ], tension: 0.9)
            out.append(shape(wing, fill: fill, stroke: stroke, width: 3.2))
        }
        let knot = Path(ellipseIn: CGRect(x: c.x - 8 * s, y: c.y - 8.5 * s, width: 16 * s, height: 17 * s))
        out.append(shape(knot, fill: fill, stroke: stroke, width: 3))
        return out
    }

    static func heartPath(center c: CGPoint, halfWidth s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + s * 0.95))
        p.addCurve(
            to: CGPoint(x: c.x - s, y: c.y - s * 0.25),
            control1: CGPoint(x: c.x - s * 0.2, y: c.y + s * 0.75),
            control2: CGPoint(x: c.x - s, y: c.y + s * 0.25)
        )
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y - s * 0.5),
            control1: CGPoint(x: c.x - s, y: c.y - s * 0.75),
            control2: CGPoint(x: c.x - s * 0.45, y: c.y - s * 0.95)
        )
        p.addCurve(
            to: CGPoint(x: c.x + s, y: c.y - s * 0.25),
            control1: CGPoint(x: c.x + s * 0.45, y: c.y - s * 0.95),
            control2: CGPoint(x: c.x + s, y: c.y - s * 0.75)
        )
        p.addCurve(
            to: CGPoint(x: c.x, y: c.y + s * 0.95),
            control1: CGPoint(x: c.x + s, y: c.y + s * 0.25),
            control2: CGPoint(x: c.x + s * 0.2, y: c.y + s * 0.75)
        )
        p.closeSubpath()
        return p
    }

    static func starPath(center c: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let a = -Double.pi / 2 + Double(i) * Double.pi / 5
            let r = i % 2 == 0 ? outer : inner
            let q = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    static func fourPointStar(center c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        let k = r * 0.24
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }

    static func flowerPath(center c: CGPoint, radius r: CGFloat, petals: Int = 5) -> Path {
        var p = Path()
        for i in 0..<petals {
            let a = -Double.pi / 2 + Double(i) * (2 * Double.pi / Double(petals))
            let px = c.x + CGFloat(cos(a)) * r * 0.52
            let py = c.y + CGFloat(sin(a)) * r * 0.52
            let rx = r * 0.48
            let ry = r * 0.34
            let ellipse = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
            let tr = CGAffineTransform(translationX: px, y: py).rotated(by: CGFloat(a))
            p.addPath(ellipse.applying(tr))
        }
        return p
    }

    private static func diamond(center c: CGPoint, rx: CGFloat, ry: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - ry))
        p.addLine(to: CGPoint(x: c.x + rx, y: c.y))
        p.addLine(to: CGPoint(x: c.x, y: c.y + ry))
        p.addLine(to: CGPoint(x: c.x - rx, y: c.y))
        p.closeSubpath()
        return p
    }
}
