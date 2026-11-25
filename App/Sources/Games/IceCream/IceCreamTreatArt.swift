import SwiftUI

// MARK: - Drawing treats, toppings, fruit and tools
//
// Flat cute vector like the other games: outlines are a deeper shade of each color (never black), one shade and
// one highlight per color, plus soft gradients where something is round (scoops, the soft-serve rope, cherries).

enum ICArt {
    static func outline(_ c: ICColor) -> Color { c.shade(-0.45).color }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
    }

    /// A shiny ball: light top left, deeper at the bottom.
    static func ballFill(_ g: GraphicsContext, _ p: Path, _ c: CGPoint, _ r: CGFloat, _ col: ICColor) {
        g.fill(p, with: .radialGradient(Gradient(colors: [col.shade(0.45).color, col.color, col.shade(-0.2).color]),
                                        center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.42), startRadius: 0, endRadius: r * 1.55))
    }

    // MARK: The whole treat

    /// Draws everything on the stand, with its rim center at `S`.
    static func drawBuild(_ g: GraphicsContext, _ b: ICBuild, at S: CGPoint, time t: CGFloat) {
        guard let base = b.base else { return }
        baseBack(g, base, S)
        if base == .glass { glassInside(g, b, S, t) }
        if b.snowLevel > 0.02 { bingsuSnow(g, b, S, time: t) }
        rope(g, b, S, front: false)
        for s in b.scoops {
            scoop(g, s, at: CGPoint(x: S.x + s.dx + s.wob, y: S.y - s.h), seed: s.id)
        }
        rope(g, b, S, front: true)
        baseFront(g, base, S, b)
        for sc in b.sauces { sauce(g, sc, b, S) }
        for piece in b.bingsuPieces {
            bingsuPiece(g, piece, at: CGPoint(x: S.x + piece.dx, y: S.y - piece.h))
        }
        if !b.whip.isEmpty { whip(g, b.whip, S) }
        for k in b.sprinkles where k.onTop {
            sprinkle(g, CGPoint(x: S.x + k.dx, y: S.y - k.dy), rot: k.rot, color: ICPalette.candy[k.color % ICPalette.candy.count])
        }
        if let w = b.wafer { wafer(g, at: CGPoint(x: S.x + w.dx, y: S.y - w.h), angle: w.angle) }
        if let st = b.straw, base != .glass { straw(g, at: CGPoint(x: S.x + st.dx, y: S.y - st.h), angle: st.angle, length: 150) }
        if let c = b.cherry { cherry(g, at: CGPoint(x: S.x + c.dx, y: S.y - c.h), wob: c.wob) }
        if base == .glass { glassFront(g, b, S) }
    }

    // MARK: Bases

    static func conePath(_ S: CGPoint) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: S.x - 50, y: S.y))
        p.addQuadCurve(to: CGPoint(x: S.x - 4, y: S.y + 142), control: CGPoint(x: S.x - 30, y: S.y + 80))
        p.addQuadCurve(to: CGPoint(x: S.x + 4, y: S.y + 142), control: CGPoint(x: S.x, y: S.y + 148))
        p.addQuadCurve(to: CGPoint(x: S.x + 50, y: S.y), control: CGPoint(x: S.x + 30, y: S.y + 80))
        p.closeSubpath()
        return p
    }

    static func cupPath(_ S: CGPoint) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: S.x - 56, y: S.y))
        p.addLine(to: CGPoint(x: S.x + 56, y: S.y))
        p.addLine(to: CGPoint(x: S.x + 42, y: S.y + 70))
        p.addQuadCurve(to: CGPoint(x: S.x - 42, y: S.y + 70), control: CGPoint(x: S.x, y: S.y + 76))
        p.closeSubpath()
        return p
    }

    static func bowlPath(_ S: CGPoint) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: S.x - 68, y: S.y))
        p.addLine(to: CGPoint(x: S.x + 68, y: S.y))
        p.addCurve(
            to: CGPoint(x: S.x + 30, y: S.y + 62),
            control1: CGPoint(x: S.x + 66, y: S.y + 38),
            control2: CGPoint(x: S.x + 48, y: S.y + 58)
        )
        p.addQuadCurve(to: CGPoint(x: S.x - 30, y: S.y + 62), control: CGPoint(x: S.x, y: S.y + 68))
        p.addCurve(
            to: CGPoint(x: S.x - 68, y: S.y),
            control1: CGPoint(x: S.x - 48, y: S.y + 58),
            control2: CGPoint(x: S.x - 66, y: S.y + 38)
        )
        p.closeSubpath()
        return p
    }

    static func glassPath(_ S: CGPoint, inset: CGFloat = 0) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: S.x - 54 + inset, y: S.y - 2))
        p.addLine(to: CGPoint(x: S.x + 54 - inset, y: S.y - 2))
        p.addLine(to: CGPoint(x: S.x + 42 - inset, y: S.y + 150 - inset))
        p.addQuadCurve(to: CGPoint(x: S.x - 42 + inset, y: S.y + 150 - inset), control: CGPoint(x: S.x, y: S.y + 156 - inset))
        p.closeSubpath()
        return p
    }

    private static func baseBack(_ g: GraphicsContext, _ base: ICBase, _ S: CGPoint) {
        switch base {
        case .waffle, .choco:
            g.fill(ellipse(CGPoint(x: S.x, y: S.y + 1), 46, 10), with: .color(ICColor(0x9E6630).color))
        case .cup:
            g.fill(ellipse(CGPoint(x: S.x, y: S.y), 54, 12), with: .color(ICColor(0xF7D9E4).color))
        case .glass:
            let back = glassPath(S)
            g.fill(back, with: .color(ICColor(0xE8F6FF).color(0.35)))
        case .bowl:
            g.fill(ellipse(CGPoint(x: S.x, y: S.y), 65, 14), with: .color(ICColor(0xDFF6F0).color))
            g.stroke(ellipse(CGPoint(x: S.x, y: S.y), 65, 14), with: .color(outline(ICColor(0x88D4C2)).opacity(0.6)), lineWidth: 2)
        }
    }

    private static func baseFront(_ g: GraphicsContext, _ base: ICBase, _ S: CGPoint, _ b: ICBuild) {
        switch base {
        case .waffle, .choco:
            let p = conePath(S)
            let tan = ICColor(0xDDA25C)
            g.fill(p, with: .linearGradient(Gradient(colors: [tan.shade(0.2).color, tan.color, tan.shade(-0.18).color]),
                                            startPoint: CGPoint(x: S.x - 50, y: S.y), endPoint: CGPoint(x: S.x + 50, y: S.y + 40)))
            var grid = g
            grid.clip(to: p)
            var lines = Path()
            for k in -8...8 {
                let x = S.x + CGFloat(k) * 17
                lines.move(to: CGPoint(x: x - 80, y: S.y - 10))
                lines.addLine(to: CGPoint(x: x + 80, y: S.y + 150))
                lines.move(to: CGPoint(x: x + 80, y: S.y - 10))
                lines.addLine(to: CGPoint(x: x - 80, y: S.y + 150))
            }
            grid.stroke(lines, with: .color(tan.shade(-0.32).color(0.75)), lineWidth: 3)
            grid.stroke(lines.offsetBy(dx: 1.5, dy: -1.5), with: .color(tan.shade(0.35).color(0.45)), lineWidth: 1.2)
            if base == .choco {
                var dip = Path()
                dip.move(to: CGPoint(x: S.x - 54, y: S.y - 4))
                dip.addLine(to: CGPoint(x: S.x + 54, y: S.y - 4))
                dip.addLine(to: CGPoint(x: S.x + 44, y: S.y + 30))
                for k in stride(from: 4, through: -4, by: -1) {
                    let x = S.x + CGFloat(k) * 10
                    let d: CGFloat = k % 2 == 0 ? 46 : 32
                    dip.addQuadCurve(to: CGPoint(x: x - 5, y: S.y + 30), control: CGPoint(x: x, y: S.y + d))
                }
                dip.closeSubpath()
                var cg = g
                cg.clip(to: p)
                let choc = ICColor(0x6A3A22)
                cg.fill(dip, with: .linearGradient(Gradient(colors: [choc.shade(0.2).color, choc.color]),
                                                   startPoint: CGPoint(x: S.x, y: S.y), endPoint: CGPoint(x: S.x, y: S.y + 40)))
                cg.stroke(dip.offsetBy(dx: 0, dy: -2), with: .color(choc.shade(0.45).color(0.5)), lineWidth: 2)
            }
            g.stroke(p, with: .color(outline(tan)), lineWidth: 3)
            // the rolled rim
            let rim = Path(roundedRect: CGRect(x: S.x - 53, y: S.y - 5, width: 106, height: 13), cornerRadius: 6.5)
            let rc = base == .choco ? ICColor(0x7A4428) : tan.shade(0.12)
            g.fill(rim, with: .color(rc.color))
            g.stroke(rim, with: .color(outline(rc)), lineWidth: 2.5)
            g.stroke(Path(CGRect(x: S.x - 46, y: S.y - 2, width: 92, height: 0.1)), with: .color(rc.shade(0.4).color(0.7)), lineWidth: 2)
        case .cup:
            let p = cupPath(S)
            g.fill(p, with: .color(ICColor(0xFFFFFF).color))
            var st = g
            st.clip(to: p)
            for k in -4...4 {
                var band = Path()
                let x = S.x + CGFloat(k) * 28
                band.move(to: CGPoint(x: x - 7, y: S.y))
                band.addLine(to: CGPoint(x: x + 7, y: S.y))
                band.addLine(to: CGPoint(x: x * 0.75 + S.x * 0.25 + 5, y: S.y + 76))
                band.addLine(to: CGPoint(x: x * 0.75 + S.x * 0.25 - 5, y: S.y + 76))
                band.closeSubpath()
                st.fill(band, with: .color(ICColor(0xFF8FB8).color))
            }
            st.fill(Path(CGRect(x: S.x - 60, y: S.y + 40, width: 120, height: 40)), with: .color(ICColor(0xC9558A).color(0.12)))
            g.stroke(p, with: .color(outline(ICColor(0xFF8FB8))), lineWidth: 3)
            let rim = Path(roundedRect: CGRect(x: S.x - 59, y: S.y - 5, width: 118, height: 11), cornerRadius: 5.5)
            g.fill(rim, with: .color(ICColor(0xFFE3EE).color))
            g.stroke(rim, with: .color(outline(ICColor(0xFF8FB8))), lineWidth: 2.5)
        case .bowl:
            let celadon = ICColor(0x9BE1CE)
            let edge = outline(ICColor(0x7CC5B2))
            // Ceramic pedestal foot
            let foot = Path(roundedRect: CGRect(x: S.x - 28, y: S.y + 58, width: 56, height: 18), cornerRadius: 7)
            g.fill(foot, with: .linearGradient(Gradient(colors: [celadon.color, celadon.shade(-0.18).color]),
                                               startPoint: CGPoint(x: S.x - 28, y: S.y + 58), endPoint: CGPoint(x: S.x + 28, y: S.y + 76)))
            g.stroke(foot, with: .color(edge), lineWidth: 2.6)
            // Rounded footed bingsu bowl body
            let p = bowlPath(S)
            g.fill(p, with: .linearGradient(
                Gradient(colors: [celadon.shade(0.26).color, celadon.color, celadon.shade(-0.14).color]),
                startPoint: CGPoint(x: S.x - 64, y: S.y + 6),
                endPoint: CGPoint(x: S.x + 64, y: S.y + 52)
            ))
            var inside = g
            inside.clip(to: p)
            // Subtle blush scallop trim + pastel snowflakes around bowl waist
            var trim = Path()
            for k in -3...3 {
                let cx = S.x + CGFloat(k) * 20
                trim.addEllipse(in: CGRect(x: cx - 10, y: S.y + 18, width: 20, height: 16))
            }
            inside.fill(trim, with: .color(ICColor(0xFFF6F9).color(0.75)))
            inside.fill(Path(CGRect(x: S.x - 70, y: S.y + 42, width: 140, height: 28)), with: .color(celadon.shade(-0.24).color(0.16)))
            g.stroke(p, with: .color(edge), lineWidth: 3)
            // Glossy ceramic rim + highlight
            let rim = Path(roundedRect: CGRect(x: S.x - 71, y: S.y - 5, width: 142, height: 12), cornerRadius: 6)
            g.fill(rim, with: .color(ICColor(0xDDF7EF).color))
            g.stroke(rim, with: .color(edge), lineWidth: 2.6)
            g.fill(ellipse(CGPoint(x: S.x - 36, y: S.y + 17), 16, 5), with: .color(.white.opacity(0.45)))
        case .glass:
            break
        }
    }

    // MARK: Korean Bingsu Snow & Toppings

    static let rainbowBingsuTreasureID = "bakery/rainbowBingsu"
    static var hasRainbowBingsu: Bool { Coins.shared.owns(rainbowBingsuTreasureID) }

    private static func bingsuSnow(_ g: GraphicsContext, _ b: ICBuild, _ S: CGPoint, time t: CGFloat) {
        let level = icClamp(b.snowLevel)
        let rainbow = hasRainbowBingsu
        // Pastel bingsu spoon (or sparkling rainbow-gem treasure spoon) tucked beside the snow dome once there's a fluffy mound
        if level >= 0.35 {
            var sp = g
            sp.translateBy(x: S.x + 26, y: S.y - 18)
            sp.rotate(by: .radians(0.48))
            var handle = Path()
            handle.move(to: CGPoint(x: 0, y: 12))
            handle.addLine(to: CGPoint(x: 0, y: -116))
            if rainbow {
                let goldEdge = StorybookArt.outline(for: 0xE6A92E)
                sp.stroke(handle, with: .color(goldEdge), style: StrokeStyle(lineWidth: 15, lineCap: .round))
                sp.stroke(
                    handle,
                    with: .linearGradient(
                        Gradient(colors: [Theme.pink, Theme.peach, Theme.lemon, Theme.mint, Theme.sky, Theme.lilac]),
                        startPoint: CGPoint(x: 0, y: -116),
                        endPoint: CGPoint(x: 0, y: 12)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                sp.stroke(handle.offsetBy(dx: -2, dy: 0), with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Golden bezel + faceted pastel rainbow-gem topper at the spoon tip
                let gemCenter = CGPoint(x: 0, y: -118)
                let bezel = ellipse(gemCenter, 12, 10)
                StorybookArt.fillAndStroke(sp, bezel, fill: Color(hex: 0xFFE382), stroke: goldEdge, width: 2.2)

                var gem = Path()
                gem.move(to: CGPoint(x: 0, y: -127))
                gem.addLine(to: CGPoint(x: 9, y: -118))
                gem.addLine(to: CGPoint(x: 0, y: -109))
                gem.addLine(to: CGPoint(x: -9, y: -118))
                gem.closeSubpath()
                sp.fill(
                    gem,
                    with: .linearGradient(
                        Gradient(colors: [Theme.pink, Theme.lemon, Theme.sky, Theme.lilac]),
                        startPoint: CGPoint(x: -9, y: -127),
                        endPoint: CGPoint(x: 9, y: -109)
                    )
                )
                sp.stroke(gem, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
                sp.fill(ellipse(CGPoint(x: -2.8, y: -120.5), 3.2, 2.2), with: .color(.white.opacity(0.9)))
                let gemGlint = 0.65 + 0.35 * sin(Double(t) * 4.5)
                StorybookArt.sparkle(sp, at: CGPoint(x: 11, y: -125), radius: 5.5, color: .white, opacity: gemGlint)
                StorybookArt.sparkle(sp, at: CGPoint(x: -11, y: -111), radius: 4.2, color: Theme.lemon, opacity: gemGlint)
            } else {
                let pink = ICColor(0xFFA8C9)
                sp.stroke(handle, with: .color(outline(pink)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                sp.stroke(handle, with: .color(pink.color), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))
                sp.stroke(handle.offsetBy(dx: -2, dy: 0), with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                let tip = ellipse(CGPoint(x: 0, y: -118), 9, 6)
                sp.fill(tip, with: .color(pink.shade(0.2).color))
                sp.stroke(tip, with: .color(outline(pink)), lineWidth: 2)
            }
        }

        let rx = ICBuild.snowRadius(level: level)
        let peak = ICBuild.snowPeak(level: level)
        var dome = Path()
        let steps = 28
        for i in 0...steps {
            let u = -1 + 2 * CGFloat(i) / CGFloat(steps)
            let dx = u * rx
            let h = ICBuild.snowHeight(at: dx, level: level) ?? 0
            let fluff = (i == 0 || i == steps) ? 0 : sin(CGFloat(i) * 1.9) * 2.4
            let pt = CGPoint(x: S.x + dx, y: S.y - h - fluff)
            if i == 0 { dome.move(to: pt) } else { dome.addLine(to: pt) }
        }
        dome.addLine(to: CGPoint(x: S.x + rx, y: S.y + 12))
        dome.addLine(to: CGPoint(x: S.x - rx, y: S.y + 12))
        dome.closeSubpath()

        g.fill(dome, with: .radialGradient(
            Gradient(colors: [Color.white, ICColor(0xF6FBFF).color, ICColor(0xDCECF8).color]),
            center: CGPoint(x: S.x - rx * 0.28, y: S.y - peak * 0.65),
            startRadius: 4,
            endRadius: max(rx, peak) * 1.35
        ))

        // Feathery folded nun-kkot milk-snow ribbon strokes
        var inside = g
        inside.clip(to: dome)
        if rainbow {
            // Subtle iridescent pastel snow aurora washed softly across the dome
            inside.fill(
                dome,
                with: .linearGradient(
                    Gradient(colors: [
                        Theme.pink.opacity(0.18),
                        Theme.lemon.opacity(0.14),
                        Theme.mint.opacity(0.16),
                        Theme.sky.opacity(0.18),
                        Theme.lilac.opacity(0.18),
                    ]),
                    startPoint: CGPoint(x: S.x - rx, y: S.y - peak),
                    endPoint: CGPoint(x: S.x + rx, y: S.y)
                )
            )
        }
        for k in 0..<5 {
            let frac = 0.22 + CGFloat(k) * 0.16
            let y = S.y - peak * frac
            let span = rx * (1 - frac * 0.55)
            var wisp = Path()
            wisp.move(to: CGPoint(x: S.x - span * 0.85, y: y + 6))
            wisp.addCurve(
                to: CGPoint(x: S.x + span * 0.85, y: y + 4),
                control1: CGPoint(x: S.x - span * 0.25, y: y - 10),
                control2: CGPoint(x: S.x + span * 0.3, y: y + 14)
            )
            inside.stroke(wisp, with: .color(ICColor(0xCBE3F5).color(0.48)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            inside.stroke(wisp.offsetBy(dx: 0, dy: -2.5), with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        inside.fill(ellipse(CGPoint(x: S.x - rx * 0.34, y: S.y - peak * 0.62), rx * 0.26, peak * 0.14), with: .color(.white.opacity(0.65)))
        g.stroke(dome, with: .color(ICColor(0xA6C6DF).color(0.85)), lineWidth: 2.6)

        // Tiny cool sparkle glints on the fluffy snow
        if level > 0.45 {
            let glint = 0.55 + 0.35 * sin(t * 3.4)
            StorybookArt.sparkle(g, at: CGPoint(x: S.x - rx * 0.48, y: S.y - peak * 0.58), radius: 5.5, color: .white, opacity: Double(glint))
            StorybookArt.sparkle(g, at: CGPoint(x: S.x + rx * 0.38, y: S.y - peak * 0.34), radius: 4.5, color: ICColor(0xD8F0FF).color, opacity: Double(glint))
        }

        // Gentle iridescent snow sparkles floating around the Bingsu dome
        if rainbow && level > 0.25 {
            let sparkles: [(CGFloat, CGFloat, CGFloat, Color, Double)] = [
                (-0.96, 0.48, 6.2, Theme.pink, 0.0),
                (-0.68, 0.94, 5.2, Theme.lemon, 1.1),
                (0.04, 1.08, 6.8, Theme.mint, 2.2),
                (0.76, 0.88, 5.5, Theme.sky, 3.3),
                (0.98, 0.42, 6.0, Theme.lilac, 4.4),
                (-0.22, 0.56, 4.8, .white, 5.1),
            ]
            let dt = Double(t)
            for (fx, fy, rad, col, ph) in sparkles {
                let tw = 0.5 + 0.5 * sin(dt * 3.6 + ph)
                let bob = CGFloat(sin(dt * 2.2 + ph)) * 3.0
                let pos = CGPoint(x: S.x + rx * fx, y: S.y - peak * fy + bob)
                StorybookArt.sparkle(g, at: pos, radius: rad * CGFloat(0.7 + 0.4 * tw), color: col, opacity: 0.45 + 0.5 * tw)
            }
        }
    }

    static func bingsuPiece(_ g: GraphicsContext, _ piece: ICBingsuPiece, at p: CGPoint) {
        var w = g
        w.translateBy(x: p.x, y: p.y)
        w.rotate(by: .radians(Double(piece.rot)))
        w.scaleBy(x: piece.scale, y: piece.scale)
        drawBingsuChunk(w, piece.topping, seed: piece.seed)
    }

    static func drawBingsuChunk(_ g: GraphicsContext, _ t: ICTopping, seed: Int) {
        switch t {
        case .redBean:
            let pat = ICColor(0x7B3243)
            let mound = ellipse(CGPoint(x: 0, y: 0), 21, 13)
            g.fill(mound, with: .radialGradient(
                Gradient(colors: [pat.shade(0.28).color, pat.color, pat.shade(-0.28).color]),
                center: CGPoint(x: -6, y: -5),
                startRadius: 2,
                endRadius: 24
            ))
            g.stroke(mound, with: .color(outline(pat)), lineWidth: 2.2)
            // Plump glossy whole azuki beans nestled in the sweet paste
            let beans: [(CGFloat, CGFloat, Double)] = [(-10, -2, -0.4), (0, -5, 0.2), (10, -1, 0.5), (-5, 4, 0.3), (6, 4, -0.3)]
            for (bx, by, rot) in beans {
                var bg = g
                bg.translateBy(x: bx, y: by)
                bg.rotate(by: .radians(rot))
                let bean = ellipse(.zero, 5.2, 3.4)
                bg.fill(bean, with: .color(pat.shade(-0.18).color))
                bg.stroke(bean, with: .color(outline(pat)), lineWidth: 1.1)
                bg.fill(ellipse(CGPoint(x: -1.4, y: -1.1), 1.8, 0.9), with: .color(.white.opacity(0.5)))
            }
        case .mangoCubes:
            let gold = ICColor(0xFFB62F)
            let rect = Path(roundedRect: CGRect(x: -10, y: -9, width: 20, height: 18), cornerRadius: 5)
            g.fill(rect, with: .linearGradient(
                Gradient(colors: [gold.shade(0.38).color, gold.color, gold.shade(-0.18).color]),
                startPoint: CGPoint(x: -10, y: -9),
                endPoint: CGPoint(x: 10, y: 9)
            ))
            g.stroke(rect, with: .color(outline(gold)), lineWidth: 2)
            g.fill(ellipse(CGPoint(x: -3.5, y: -4.2), 4.5, 2.2), with: .color(.white.opacity(0.6)))
        case .strawberries:
            let red = ICColor(0xED3B5B)
            var berry = Path()
            berry.move(to: CGPoint(x: 0, y: 12))
            berry.addCurve(to: CGPoint(x: 0, y: -11), control1: CGPoint(x: -15, y: 3), control2: CGPoint(x: -11, y: -14))
            berry.addCurve(to: CGPoint(x: 0, y: 12), control1: CGPoint(x: 11, y: -14), control2: CGPoint(x: 15, y: 3))
            berry.closeSubpath()
            g.fill(berry, with: .radialGradient(
                Gradient(colors: [red.shade(0.25).color, red.color, red.shade(-0.18).color]),
                center: CGPoint(x: -3, y: -4),
                startRadius: 1,
                endRadius: 15
            ))
            // Creamy pale sliced strawberry heart interior
            var core = Path()
            core.move(to: CGPoint(x: 0, y: 6))
            core.addCurve(to: CGPoint(x: 0, y: -6), control1: CGPoint(x: -7, y: 1), control2: CGPoint(x: -5, y: -7))
            core.addCurve(to: CGPoint(x: 0, y: 6), control1: CGPoint(x: 5, y: -7), control2: CGPoint(x: 7, y: 1))
            core.closeSubpath()
            g.fill(core, with: .color(ICColor(0xFFE6EC).color(0.9)))
            g.fill(ellipse(CGPoint(x: 0, y: -1), 2.5, 3.2), with: .color(ICColor(0xFF9EB4).color(0.65)))
            g.stroke(berry, with: .color(outline(red)), lineWidth: 2)
            for k in 0..<5 {
                let a = CGFloat(k) / 5 * 2 * .pi + CGFloat(seed)
                g.fill(circle(CGPoint(x: cos(a) * 6.2, y: sin(a) * 5.2), 1), with: .color(ICColor(0xFFE996).color))
            }
        case .injeolmi:
            let dust = ICColor(0xDFB674)
            let cube = Path(roundedRect: CGRect(x: -11, y: -9, width: 22, height: 18), cornerRadius: 5.5)
            g.fill(cube, with: .linearGradient(
                Gradient(colors: [dust.shade(0.32).color, dust.color, dust.shade(-0.16).color]),
                startPoint: CGPoint(x: -11, y: -9),
                endPoint: CGPoint(x: 11, y: 9)
            ))
            g.stroke(cube, with: .color(outline(dust)), lineWidth: 2)
            // Roasted soybean powder (konggaru) flecks
            for k in 0..<7 {
                let fx = (icRand(seed, k + 3) - 0.5) * 15
                let fy = (icRand(seed, k + 17) - 0.5) * 11
                g.fill(circle(CGPoint(x: fx, y: fy), 1.1), with: .color(dust.shade(-0.34).color(0.65)))
            }
            g.fill(ellipse(CGPoint(x: -3.5, y: -4.2), 4.5, 2), with: .color(ICColor(0xFFF6DF).color(0.65)))
        default:
            break
        }
    }

    static func bingsuCluster(_ g: GraphicsContext, _ t: ICTopping) {
        switch t {
        case .redBean:
            var c = g
            c.scaleBy(x: 1.25, y: 1.25)
            drawBingsuChunk(c, .redBean, seed: 3)
        case .mangoCubes, .injeolmi:
            let offsets: [(CGFloat, CGFloat, Double)] = [(-11, 7, -0.22), (11, 6, 0.25), (0, -8, 0.08)]
            for (idx, (dx, dy, rot)) in offsets.enumerated() {
                var c = g
                c.translateBy(x: dx, y: dy)
                c.rotate(by: .radians(rot))
                drawBingsuChunk(c, t, seed: idx + 5)
            }
        case .strawberries:
            let offsets: [(CGFloat, CGFloat, Double)] = [(-11, 5, -0.28), (11, 5, 0.28), (0, -7, 0)]
            for (idx, (dx, dy, rot)) in offsets.enumerated() {
                var c = g
                c.translateBy(x: dx, y: dy)
                c.rotate(by: .radians(rot))
                drawBingsuChunk(c, .strawberries, seed: idx + 9)
            }
        default:
            break
        }
    }

    private static func glassInside(_ g: GraphicsContext, _ b: ICBuild, _ S: CGPoint, _ t: CGFloat) {
        let inner = glassPath(S, inset: 6)
        var c = g
        c.clip(to: inner)
        let bottom = S.y + 148
        let full: CGFloat = 146
        var y0 = bottom
        for (i, l) in b.layers.enumerated() {
            let y1 = bottom - full * min(1, l.top)
            let rect = CGRect(x: S.x - 60, y: y1, width: 120, height: y0 - y1 + (i == 0 ? 6 : 2))
            c.fill(Path(rect), with: .linearGradient(Gradient(colors: [l.color.shade(0.08).color, l.color.color, l.color.shade(-0.12).color]),
                                                     startPoint: CGPoint(x: S.x - 50, y: 0), endPoint: CGPoint(x: S.x + 50, y: 0)))
            // seeds and bits floating in it
            for k in 0..<6 {
                let px = S.x - 36 + icRand(k + i * 7, 11) * 72
                let py = y1 + 6 + icRand(k + i * 7, 12) * max(1, y0 - y1 - 10)
                c.fill(circle(CGPoint(x: px, y: py), 1.6), with: .color(l.color.shade(-0.4).color(0.55)))
            }
            y0 = y1
        }
        if let top = b.layers.last {
            let y = bottom - full * min(1, top.top)
            let surf = top.color.shade(0.22)
            c.fill(ellipse(CGPoint(x: S.x, y: y), 52, 7), with: .color(surf.color))
            // foam bubbles on top
            for k in 0..<9 {
                let px = S.x - 40 + icRand(k, 21) * 80
                let r = 2 + icRand(k, 22) * 3
                c.stroke(circle(CGPoint(x: px, y: y + (icRand(k, 23) - 0.5) * 6), r), with: .color(.white.opacity(0.55)), lineWidth: 1.2)
            }
        }
        if let st = b.straw {
            straw(c, at: CGPoint(x: S.x + st.dx, y: S.y - st.h), angle: st.angle, length: 210)
        }
    }

    private static func glassFront(_ g: GraphicsContext, _ b: ICBuild, _ S: CGPoint) {
        let p = glassPath(S)
        let edge = ICColor(0x9FC4DA)
        // the straw above the rim, outside the glass
        if let st = b.straw {
            var top = g
            top.clip(to: Path(CGRect(x: S.x - 200, y: S.y - 300, width: 400, height: 298)))
            straw(top, at: CGPoint(x: S.x + st.dx, y: S.y - st.h), angle: st.angle, length: 210)
        }
        var hl = Path()
        hl.move(to: CGPoint(x: S.x - 40, y: S.y + 10))
        hl.addLine(to: CGPoint(x: S.x - 31, y: S.y + 136))
        g.stroke(hl, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        var hl2 = Path()
        hl2.move(to: CGPoint(x: S.x + 38, y: S.y + 20))
        hl2.addLine(to: CGPoint(x: S.x + 33, y: S.y + 70))
        g.stroke(hl2, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        g.stroke(p, with: .color(edge.color(0.9)), lineWidth: 3.5)
        g.stroke(ellipse(CGPoint(x: S.x, y: S.y - 2), 54, 8), with: .color(edge.color(0.8)), lineWidth: 3)
        // a thick glass foot
        let foot = Path(roundedRect: CGRect(x: S.x - 46, y: S.y + 146, width: 92, height: 14), cornerRadius: 7)
        g.fill(foot, with: .color(ICColor(0xDDEFFA).color(0.85)))
        g.stroke(foot, with: .color(edge.color), lineWidth: 2.5)
        // too full: it runs down the outside
        if b.overflow > 0.005 {
            let col = b.layers.last?.color ?? ICColor(0xFFFFFF)
            for k in 0..<3 {
                let side: CGFloat = k == 1 ? 1 : -1
                let x = S.x + side * (50 - CGFloat(k) * 2)
                let len = min(140, 30 + b.overflow * 900 * (0.6 + 0.3 * CGFloat(k)))
                var d = Path()
                d.move(to: CGPoint(x: x, y: S.y - 3))
                d.addLine(to: CGPoint(x: x - side * len * 0.07, y: S.y + len))
                g.stroke(d, with: .color(col.color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                g.fill(circle(CGPoint(x: x - side * len * 0.07, y: S.y + len + 3), 4.5), with: .color(col.color))
            }
        }
    }

    // MARK: Scoops

    /// A scoop of ice cream, round on top with a frilly lip at the bottom where the dipper let go of it.
    static func scoop(_ g: GraphicsContext, _ s: ICScoop, at c: CGPoint, seed: Int) {
        let rx = s.r * (1 + s.squash * 0.45)
        let ry = s.r * (1 - s.squash)
        scoopBall(g, center: c, rx: rx, ry: ry, flavor: s.flavor, swirl: s.swirl, seed: seed, ball: 1)
        // melting drips from the lip
        let col = s.flavor.color
        for d in s.drips where d.len > 1 {
            let x = c.x + d.dx
            let y0 = c.y + ry * 0.6
            var p = Path(roundedRect: CGRect(x: x - d.w / 2, y: y0 - 4, width: d.w, height: d.len + 4), cornerRadius: d.w / 2)
            p.addEllipse(in: CGRect(x: x - d.w * 0.62, y: y0 + d.len - d.w * 0.7, width: d.w * 1.24, height: d.w * 1.3))
            g.fill(p, with: .color(col.shade(-0.04).color))
            g.stroke(Path(CGRect(x: x - d.w * 0.18, y: y0, width: 0.1, height: d.len * 0.8)), with: .color(col.shade(0.5).color(0.7)), lineWidth: 1.6)
        }
    }

    static func scoopBall(_ g: GraphicsContext, center c: CGPoint, rx: CGFloat, ry: CGFloat, flavor: ICFlavor, swirl: ICFlavor?,
                          seed: Int, ball: CGFloat) {
        let col = flavor.color
        // lumpy round top
        var body = Path()
        let n = 26
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let lump = 1 + 0.035 * sin(a * 5 + CGFloat(seed)) + 0.025 * sin(a * 9 + CGFloat(seed) * 2.1)
            let p = CGPoint(x: c.x + cos(a) * rx * lump, y: c.y + sin(a) * ry * lump)
            if i == 0 { body.move(to: p) } else { body.addLine(to: p) }
        }
        body.closeSubpath()
        // the frilly lip: a ruffled band around the bottom
        var lip = Path()
        let ly = c.y + ry * 0.58
        let lw = rx * 1.02
        lip.move(to: CGPoint(x: c.x - lw, y: ly - ry * 0.1))
        let bumps = 9
        for k in 0..<bumps {
            let u0 = CGFloat(k) / CGFloat(bumps), u1 = CGFloat(k + 1) / CGFloat(bumps)
            let x0 = c.x - lw + 2 * lw * u0, x1 = c.x - lw + 2 * lw * u1
            let sag = sin(u1 * .pi) * ry * 0.16
            let jitter = (icRand(seed, k) - 0.5) * 5
            lip.addQuadCurve(to: CGPoint(x: x1, y: ly + sag - ry * 0.1 * (1 - sin(u1 * .pi))),
                             control: CGPoint(x: (x0 + x1) / 2, y: ly + sin((u0 + u1) * 0.5 * .pi) * ry * 0.34 + 8 + jitter))
        }
        lip.addLine(to: CGPoint(x: c.x + lw * 0.8, y: ly - ry * 0.4))
        lip.addLine(to: CGPoint(x: c.x - lw * 0.8, y: ly - ry * 0.4))
        lip.closeSubpath()
        g.fill(lip, with: .color(col.shade(-0.14).color))
        g.stroke(lip, with: .color(outline(col)), lineWidth: 2.5)
        ballFill(g, body, c, max(rx, ry), col)
        var inside = g
        inside.clip(to: body)
        if let sw = swirl {
            var band = Path()
            band.move(to: CGPoint(x: c.x - rx * 1.2, y: c.y + ry * 0.1))
            band.addCurve(to: CGPoint(x: c.x + rx * 1.2, y: c.y - ry * 0.3), control1: CGPoint(x: c.x - rx * 0.4, y: c.y - ry * 0.9),
                          control2: CGPoint(x: c.x + rx * 0.3, y: c.y + ry * 0.6))
            inside.stroke(band, with: .color(sw.color.color), style: StrokeStyle(lineWidth: ry * 0.36, lineCap: .round))
            inside.stroke(band.offsetBy(dx: 0, dy: -ry * 0.1), with: .color(sw.color.shade(0.4).color(0.6)), lineWidth: 3)
        }
        // curls left by the dipper
        for k in 0..<3 {
            var arc = Path()
            let rr = max(rx, ry) * (0.42 + CGFloat(k) * 0.22)
            let a0 = -2.4 + CGFloat(k) * 0.2 + (icRand(seed, 30 + k) - 0.5) * 0.4
            arc.addArc(center: CGPoint(x: c.x + rx * 0.3, y: c.y + ry * 0.25), radius: rr,
                       startAngle: .radians(Double(a0)), endAngle: .radians(Double(a0 + 1.1)), clockwise: false)
            inside.stroke(arc, with: .color(col.shade(-0.16).color(0.6)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            inside.stroke(arc.offsetBy(dx: -1, dy: -2), with: .color(col.shade(0.5).color(0.6)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        // chips, berry bits, vanilla specks
        if let bits = flavor.bits {
            let count = flavor == .vanilla ? 16 : 9
            for k in 0..<count {
                let a = icRand(seed, 50 + k) * 2 * .pi
                let d = sqrt(icRand(seed, 80 + k)) * 0.8
                let p = CGPoint(x: c.x + cos(a) * rx * d, y: c.y + sin(a) * ry * d)
                if flavor == .vanilla {
                    inside.fill(circle(p, 0.9), with: .color(bits.color(0.55)))
                } else {
                    var chip = Path()
                    let sz: CGFloat = flavor == .strawberry || flavor == .blueberry ? 3.4 : 3
                    chip.move(to: CGPoint(x: p.x - sz, y: p.y))
                    chip.addLine(to: CGPoint(x: p.x, y: p.y - sz * 0.8))
                    chip.addLine(to: CGPoint(x: p.x + sz * 0.9, y: p.y + sz * 0.3))
                    chip.addLine(to: CGPoint(x: p.x - sz * 0.2, y: p.y + sz))
                    chip.closeSubpath()
                    inside.fill(chip, with: .color(bits.color(0.9)))
                }
            }
        }
        // a frosty shine
        inside.fill(ellipse(CGPoint(x: c.x - rx * 0.36, y: c.y - ry * 0.46), rx * 0.26, ry * 0.14), with: .color(.white.opacity(0.45)))
        g.stroke(body, with: .color(outline(col)), lineWidth: 3)
    }

    // MARK: Soft serve

    /// The soft-serve rope: back half of every ring first, then the front halves over them.
    private static func rope(_ g: GraphicsContext, _ b: ICBuild, _ S: CGPoint, front: Bool) {
        guard b.rope.count > 1 else { return }
        var pts: [(p: CGPoint, f: Bool, r: CGFloat, c: Int)] = []
        pts.reserveCapacity(b.rope.count)
        for bead in b.rope {
            let w = b.spun(bead)
            pts.append((CGPoint(x: S.x + w.x, y: S.y - bead.h + w.z * 0.3), w.z > -0.5, bead.r, bead.c))
        }
        drawRuns(g, pts, front: front, color: { c in
            let f = ICSoft(rawValue: c / 2) ?? .vanilla
            return c % 2 == 0 ? f.colors.0 : f.colors.1
        })
    }

    private static func whip(_ g: GraphicsContext, _ beads: [ICBead], _ S: CGPoint) {
        var pts: [(p: CGPoint, f: Bool, r: CGFloat, c: Int)] = []
        for b in beads {
            pts.append((CGPoint(x: S.x + b.x, y: S.y - b.h + b.z * 0.3), b.z > -0.5, b.r, 0))
        }
        let cream = ICColor(0xFFFDF8)
        drawRuns(g, pts, front: false, color: { _ in cream })
        drawRuns(g, pts, front: true, color: { _ in cream })
    }

    /// Strokes a rope of beads as ridged tubes, in runs of beads on the same side and color.
    static func drawRuns(_ g: GraphicsContext, _ pts: [(p: CGPoint, f: Bool, r: CGFloat, c: Int)], front: Bool,
                         color: (Int) -> ICColor) {
        var i = 0
        while i < pts.count {
            guard pts[i].f == front else { i += 1; continue }
            var path = Path()
            path.move(to: pts[i].p)
            let c = pts[i].c
            var r = pts[i].r
            var j = i + 1
            var count = 1
            while j < pts.count && pts[j].f == front && pts[j].c == c
                    && hypot(pts[j].p.x - pts[j - 1].p.x, pts[j].p.y - pts[j - 1].p.y) < 16 {
                path.addLine(to: pts[j].p)
                r = (r * CGFloat(count) + pts[j].r) / CGFloat(count + 1)
                count += 1
                j += 1
            }
            // one bead of overlap into the next run so the rope never shows a gap
            if j < pts.count && hypot(pts[j].p.x - pts[j - 1].p.x, pts[j].p.y - pts[j - 1].p.y) < 16 {
                path.addLine(to: pts[j].p)
            }
            if count == 1 { path.addLine(to: CGPoint(x: pts[i].p.x + 0.5, y: pts[i].p.y)) }
            tube(g, path, r: r, col: color(c), dim: !front)
            i = j
        }
    }

    static func tube(_ g: GraphicsContext, _ path: Path, r: CGFloat, col: ICColor, dim: Bool) {
        let base = dim ? col.shade(-0.1) : col
        let round = StrokeStyle(lineWidth: r * 2 + 3, lineCap: .round, lineJoin: .round)
        g.stroke(path, with: .color(outline(base).opacity(0.85)), style: round)
        g.stroke(path, with: .color(base.shade(-0.1).color), style: StrokeStyle(lineWidth: r * 2, lineCap: .round, lineJoin: .round))
        g.stroke(path.offsetBy(dx: 0, dy: -r * 0.16), with: .color(base.color),
                 style: StrokeStyle(lineWidth: r * 1.55, lineCap: .round, lineJoin: .round))
        // ridges from the star nozzle
        g.stroke(path.offsetBy(dx: 0, dy: r * 0.42), with: .color(base.shade(-0.28).color(0.45)),
                 style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        g.stroke(path.offsetBy(dx: 0, dy: -r * 0.05), with: .color(base.shade(-0.2).color(0.3)),
                 style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        g.stroke(path.offsetBy(dx: 0, dy: -r * 0.52), with: .color(base.shade(0.6).color(dim ? 0.4 : 0.75)),
                 style: StrokeStyle(lineWidth: r * 0.42, lineCap: .round, lineJoin: .round))
    }

    // MARK: Toppings

    private static func sauce(_ g: GraphicsContext, _ s: ICSauce, _ b: ICBuild, _ S: CGPoint) {
        let col = s.topping.sauceColor ?? ICColor(0x5A2F1F)
        let isMilk = s.topping == .condensedMilk
        var i = 0
        let n = ICBuild.columns
        while i < n {
            guard b.profile[i] > -500, s.amount[i] > 0.03 || s.run[i] > 0.6 else { i += 1; continue }
            var j = i
            while j + 1 < n && b.profile[j + 1] > -500 && (s.amount[j + 1] > 0.03 || s.run[j + 1] > 0.6) { j += 1 }
            if j - i >= 1 {
                var top: [CGPoint] = []
                var bottom: [CGPoint] = []
                for k in i...j {
                    let x = S.x + ICBuild.colDX(k)
                    let y = S.y - b.profile[k]
                    let edge = min(CGFloat(k - i), CGFloat(j - k), 4) / 4
                    let thick = (3 + min(5, s.amount[k] * 6)) * edge
                    top.append(CGPoint(x: x, y: y - 1.5))
                    let lo = max(0, k - 1), hi = min(n - 1, k + 1)
                    let run = (s.run[lo] + s.run[k] * 2 + s.run[hi]) / 4
                    bottom.append(CGPoint(x: x, y: y + thick + run * edge))
                }
                var p = Path()
                p.move(to: top[0])
                for q in top.dropFirst() { p.addLine(to: q) }
                for q in bottom.reversed() { p.addLine(to: q) }
                p.closeSubpath()
                if isMilk {
                    g.stroke(p, with: .color(ICColor(0xE2C894).color(0.7)), lineWidth: 2)
                }
                g.fill(p, with: .color(col.color))
                // drip ends
                for k in stride(from: 1, to: bottom.count - 1, by: 1) {
                    let a = bottom[k - 1].y, m = bottom[k].y, c = bottom[k + 1].y
                    if m > a && m >= c && m - top[k].y > 14 {
                        if isMilk {
                            g.stroke(circle(CGPoint(x: bottom[k].x, y: m - 1), 3.8), with: .color(ICColor(0xE2C894).color(0.7)), lineWidth: 1.4)
                        }
                        g.fill(circle(CGPoint(x: bottom[k].x, y: m - 1), 3.6), with: .color(col.color))
                    }
                }
                var shine = Path()
                shine.move(to: CGPoint(x: top[0].x, y: top[0].y + 3))
                for q in top.dropFirst() { shine.addLine(to: CGPoint(x: q.x, y: q.y + 3)) }
                g.stroke(shine, with: .color((isMilk ? ICColor(0xFFFFFF) : col.shade(0.5)).color(isMilk ? 0.8 : 0.55)),
                         style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            i = j + 1
        }
    }

    static func sprinkle(_ g: GraphicsContext, _ p: CGPoint, rot: CGFloat, color: ICColor) {
        var s = g
        s.translateBy(x: p.x, y: p.y)
        s.rotate(by: .radians(Double(rot)))
        let r = Path(roundedRect: CGRect(x: -4, y: -1.4, width: 8, height: 2.8), cornerRadius: 1.4)
        s.fill(r, with: .color(color.color))
        s.stroke(r, with: .color(color.shade(-0.3).color(0.6)), lineWidth: 0.7)
    }

    static func cherry(_ g: GraphicsContext, at p: CGPoint, wob: CGFloat) {
        let red = ICColor(0xE5223F)
        var stem = Path()
        stem.move(to: CGPoint(x: p.x + 1, y: p.y - 9))
        stem.addQuadCurve(to: CGPoint(x: p.x + 10 + wob * 6, y: p.y - 34), control: CGPoint(x: p.x - 2, y: p.y - 26))
        g.stroke(stem, with: .color(ICColor(0x5E8B2C).color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let body = circle(p, 12)
        ballFill(g, body, p, 12, red)
        g.stroke(body, with: .color(outline(red)), lineWidth: 2.5)
        g.fill(ellipse(CGPoint(x: p.x - 4, y: p.y - 5), 3.5, 2.2), with: .color(.white.opacity(0.8)))
    }

    static func wafer(_ g: GraphicsContext, at p: CGPoint, angle: CGFloat) {
        var w = g
        w.translateBy(x: p.x, y: p.y)
        w.rotate(by: .radians(Double(angle)))
        let rect = Path(roundedRect: CGRect(x: -8, y: -86, width: 16, height: 90), cornerRadius: 7)
        let tan = ICColor(0xE9B46A)
        w.fill(rect, with: .linearGradient(Gradient(colors: [tan.shade(0.25).color, tan.color, tan.shade(-0.2).color]),
                                           startPoint: CGPoint(x: -8, y: 0), endPoint: CGPoint(x: 8, y: 0)))
        var spiral = Path()
        for k in 0..<8 {
            let y = -82 + CGFloat(k) * 11
            spiral.move(to: CGPoint(x: -8, y: y))
            spiral.addLine(to: CGPoint(x: 8, y: y + 7))
        }
        var cl = w
        cl.clip(to: rect)
        cl.stroke(spiral, with: .color(tan.shade(-0.3).color), lineWidth: 1.8)
        w.stroke(rect, with: .color(outline(tan)), lineWidth: 2.5)
        w.fill(ellipse(CGPoint(x: 0, y: -84), 7, 3), with: .color(ICColor(0x6A3A22).color))
    }

    static func straw(_ g: GraphicsContext, at p: CGPoint, angle: CGFloat, length: CGFloat) {
        var w = g
        w.translateBy(x: p.x, y: p.y)
        w.rotate(by: .radians(Double(angle)))
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -length + 26))
        path.addQuadCurve(to: CGPoint(x: 22, y: -length - 4), control: CGPoint(x: 0, y: -length - 6))
        let pink = ICColor(0xFF6FA8)
        w.stroke(path, with: .color(outline(pink)), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
        w.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        w.stroke(path, with: .color(pink.color), style: StrokeStyle(lineWidth: 9, lineCap: .butt, lineJoin: .round, dash: [9, 9]))
    }

    // MARK: Fruit

    static func fruit(_ g: GraphicsContext, _ f: ICFruit, at p: CGPoint, r: CGFloat, rot: CGFloat, seed: Int) {
        var w = g
        w.translateBy(x: p.x, y: p.y)
        w.rotate(by: .radians(Double(rot)))
        let o = CGPoint.zero
        switch f {
        case .strawberry:
            let red = ICColor(0xE8364F)
            var b = Path()
            b.move(to: CGPoint(x: 0, y: r * 1.05))
            b.addCurve(to: CGPoint(x: 0, y: -r * 0.65), control1: CGPoint(x: -r * 1.45, y: r * 0.25), control2: CGPoint(x: -r * 0.9, y: -r * 1.05))
            b.addCurve(to: CGPoint(x: 0, y: r * 1.05), control1: CGPoint(x: r * 0.9, y: -r * 1.05), control2: CGPoint(x: r * 1.45, y: r * 0.25))
            ballFill(w, b, CGPoint(x: 0, y: 0), r, red)
            w.stroke(b, with: .color(outline(red)), lineWidth: 2)
            for k in 0..<7 {
                let sx = (icRand(seed, k) - 0.5) * r * 1.2
                let sy = (icRand(seed, k + 9) - 0.4) * r * 1.2
                w.fill(ellipse(CGPoint(x: sx, y: sy), 1.2, 1.8), with: .color(ICColor(0xFFE58A).color))
            }
            if r > 12 {
                var leaf = Path()
                for k in 0..<5 {
                    let a = -CGFloat.pi / 2 + (CGFloat(k) - 2) * 0.55
                    leaf.move(to: CGPoint(x: 0, y: -r * 0.62))
                    leaf.addLine(to: CGPoint(x: cos(a) * r * 0.55, y: -r * 0.62 + sin(a) * r * 0.32 - 2))
                }
                w.stroke(leaf, with: .color(ICColor(0x4FA83F).color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        case .banana:
            let c = ICColor(0xFFF0B8)
            let disk = circle(o, r)
            w.fill(disk, with: .color(c.color))
            w.fill(circle(o, r * 0.55), with: .color(ICColor(0xFFF8DC).color))
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * 2 * .pi
                w.fill(circle(CGPoint(x: cos(a) * r * 0.32, y: sin(a) * r * 0.32), 1.1), with: .color(ICColor(0x9A7A3A).color))
            }
            w.stroke(disk, with: .color(ICColor(0xE7C25A).color), lineWidth: 2.5)
        case .blueberry:
            let c = ICColor(0x4C56B8)
            let disk = circle(o, r)
            ballFill(w, disk, o, r, c)
            w.stroke(disk, with: .color(outline(c)), lineWidth: 1.8)
            var crown = Path()
            for k in 0..<5 {
                let a = CGFloat(k) / 5 * 2 * .pi
                crown.move(to: CGPoint(x: 0, y: -r * 0.55))
                crown.addLine(to: CGPoint(x: cos(a) * r * 0.25, y: -r * 0.55 + sin(a) * r * 0.25))
            }
            w.stroke(crown, with: .color(ICColor(0x2C2F70).color), lineWidth: 1.3)
        case .mango:
            let c = ICColor(0xFFB234)
            let cube = Path(roundedRect: CGRect(x: -r * 0.85, y: -r * 0.85, width: r * 1.7, height: r * 1.7), cornerRadius: r * 0.38)
            w.fill(cube, with: .linearGradient(Gradient(colors: [c.shade(0.35).color, c.color, c.shade(-0.15).color]),
                                               startPoint: CGPoint(x: -r, y: -r), endPoint: CGPoint(x: r, y: r)))
            w.stroke(cube, with: .color(outline(c)), lineWidth: 2)
        case .kiwi:
            let c = ICColor(0x8CC43C)
            let disk = circle(o, r)
            w.fill(disk, with: .color(ICColor(0x8A6A3A).color))
            w.fill(circle(o, r * 0.86), with: .color(c.color))
            w.fill(circle(o, r * 0.32), with: .color(ICColor(0xF2F6D8).color))
            for k in 0..<10 {
                let a = CGFloat(k) / 10 * 2 * .pi
                w.fill(ellipse(CGPoint(x: cos(a) * r * 0.48, y: sin(a) * r * 0.48), 1.2, 1.8), with: .color(ICColor(0x2A2418).color))
            }
            w.stroke(disk, with: .color(ICColor(0x6A4E2A).color), lineWidth: 1.8)
        case .ice:
            let cube = Path(roundedRect: CGRect(x: -r * 0.85, y: -r * 0.85, width: r * 1.7, height: r * 1.7), cornerRadius: r * 0.3)
            w.fill(cube, with: .color(ICColor(0xE6F6FF).color(0.75)))
            w.stroke(cube, with: .color(ICColor(0x9CCFEA).color), lineWidth: 2)
            w.fill(Path(roundedRect: CGRect(x: -r * 0.55, y: -r * 0.6, width: r * 0.5, height: r * 0.25), cornerRadius: 2), with: .color(.white.opacity(0.9)))
        }
    }

    // MARK: Tools

    /// The dipper, drawn with its bowl (the tip) at the origin and its handle going down.
    static func dipper(_ g: GraphicsContext, ball: CGFloat, flavor: ICFlavor?, swirl: ICFlavor?, time t: CGFloat) {
        let steel = ICColor(0xC9D3DE)
        var neck = Path()
        neck.move(to: CGPoint(x: 0, y: 8))
        neck.addLine(to: CGPoint(x: 0, y: 70))
        g.stroke(neck, with: .color(outline(steel)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        g.stroke(neck, with: .color(steel.color), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        let grip = Path(roundedRect: CGRect(x: -11, y: 64, width: 22, height: 86), cornerRadius: 11)
        let pink = ICColor(0xFF7FB0)
        g.fill(grip, with: .linearGradient(Gradient(colors: [pink.shade(0.3).color, pink.color, pink.shade(-0.2).color]),
                                           startPoint: CGPoint(x: -11, y: 0), endPoint: CGPoint(x: 11, y: 0)))
        g.stroke(grip, with: .color(outline(pink)), lineWidth: 2.5)
        // the thumb lever
        g.fill(Path(roundedRect: CGRect(x: 8, y: 58, width: 10, height: 26), cornerRadius: 4), with: .color(steel.shade(-0.1).color))
        // the bowl
        var bowl = Path()
        bowl.addArc(center: .zero, radius: 24, startAngle: .degrees(-10), endAngle: .degrees(190), clockwise: false)
        bowl.closeSubpath()
        g.fill(bowl, with: .linearGradient(Gradient(colors: [steel.shade(0.5).color, steel.color, steel.shade(-0.25).color]),
                                           startPoint: CGPoint(x: -24, y: 0), endPoint: CGPoint(x: 24, y: 20)))
        g.stroke(bowl, with: .color(outline(steel)), lineWidth: 2.5)
        if ball > 0.02, let f = flavor {
            let r = 26 + 22 * sqrt(icClamp(ball))
            // still curling: a ribbon rolling up; full: a ball
            let rr = r * (0.55 + 0.45 * ball)
            scoopBall(g, center: CGPoint(x: 0, y: -rr * 0.45), rx: rr, ry: rr * (0.75 + 0.25 * ball), flavor: f, swirl: swirl, seed: 7, ball: ball)
            if ball < 1 {
                var curl = Path()
                curl.addArc(center: CGPoint(x: 0, y: -rr * 0.45), radius: rr * 0.62, startAngle: .degrees(200),
                            endAngle: .degrees(Double(200 + 300 * ball)), clockwise: false)
                g.stroke(curl, with: .color(f.color.shade(-0.2).color(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }

    /// Sprinkles shaker, upside down, holes (the tip) at the origin.
    static func shaker(_ g: GraphicsContext) {
        let cap = Path(roundedRect: CGRect(x: -26, y: -24, width: 52, height: 24), cornerRadius: 9)
        let pink = ICColor(0xFF8FB8)
        let body = Path(roundedRect: CGRect(x: -24, y: -116, width: 48, height: 96), cornerRadius: 14)
        g.fill(body, with: .color(ICColor(0xFFFFFF).color(0.85)))
        var inside = g
        inside.clip(to: body)
        for k in 0..<38 {
            let x = -20 + icRand(k, 1) * 40
            let y = -40 - icRand(k, 2) * 64
            sprinkle(inside, CGPoint(x: x, y: y), rot: icRand(k, 3) * 6, color: ICPalette.candy[k % 5])
        }
        g.stroke(body, with: .color(ICColor(0xB7C6D6).color), lineWidth: 2.5)
        g.stroke(Path(roundedRect: CGRect(x: -16, y: -106, width: 6, height: 70), cornerRadius: 3), with: .color(.white.opacity(0.8)), lineWidth: 3)
        g.fill(cap, with: .color(pink.color))
        g.stroke(cap, with: .color(outline(pink)), lineWidth: 2.5)
        for k in 0..<5 {
            g.fill(circle(CGPoint(x: CGFloat(k - 2) * 8, y: -4), 2.2), with: .color(pink.shade(-0.5).color))
        }
    }

    /// Squeeze bottle, upside down, nozzle (the tip) at the origin.
    static func bottle(_ g: GraphicsContext, _ t: ICTopping) {
        let isMilk = t == .condensedMilk
        let c = t.sauceColor ?? ICColor(0x5A2F1F)
        let edgeColor = isMilk ? outline(ICColor(0xD4B882)) : outline(c)
        var nozzle = Path()
        nozzle.move(to: CGPoint(x: -3, y: 0))
        nozzle.addLine(to: CGPoint(x: 3, y: 0))
        nozzle.addLine(to: CGPoint(x: 12, y: -26))
        nozzle.addLine(to: CGPoint(x: -12, y: -26))
        nozzle.closeSubpath()
        let capC = isMilk ? ICColor(0x88CCF4) : ICColor(0xFFFFFF)
        g.fill(nozzle, with: .color(capC.color))
        g.stroke(nozzle, with: .color(edgeColor), lineWidth: 2)
        let body = Path(roundedRect: CGRect(x: -27, y: -136, width: 54, height: 112), cornerRadius: 20)
        g.fill(body, with: .linearGradient(Gradient(colors: [c.shade(0.3).color, c.color, c.shade(isMilk ? -0.1 : -0.2).color]),
                                           startPoint: CGPoint(x: -27, y: 0), endPoint: CGPoint(x: 27, y: 0)))
        g.stroke(body, with: .color(edgeColor), lineWidth: 2.5)
        // label with a picture: cocoa heart, strawberry, or sweet milk droplet
        let label = Path(roundedRect: CGRect(x: -20, y: -100, width: 40, height: 44), cornerRadius: 10)
        g.fill(label, with: .color(isMilk ? ICColor(0x98D6F8).color : .white.opacity(0.92)))
        if t == .berrySauce {
            fruit(g, .strawberry, at: CGPoint(x: 0, y: -78), r: 13, rot: 0, seed: 3)
        } else if isMilk {
            var drop = Path()
            drop.move(to: CGPoint(x: 0, y: -93))
            drop.addCurve(to: CGPoint(x: 0, y: -65), control1: CGPoint(x: 15, y: -76), control2: CGPoint(x: 13, y: -65))
            drop.addCurve(to: CGPoint(x: 0, y: -93), control1: CGPoint(x: -13, y: -65), control2: CGPoint(x: -15, y: -76))
            drop.closeSubpath()
            g.fill(drop, with: .color(.white))
            g.stroke(drop, with: .color(outline(ICColor(0x88CCF4))), lineWidth: 1.8)
        } else {
            var h = Path()
            let cx: CGFloat = 0, cy: CGFloat = -80
            h.move(to: CGPoint(x: cx, y: cy + 12))
            h.addCurve(to: CGPoint(x: cx, y: cy - 6), control1: CGPoint(x: cx - 18, y: cy), control2: CGPoint(x: cx - 10, y: cy - 16))
            h.addCurve(to: CGPoint(x: cx, y: cy + 12), control1: CGPoint(x: cx + 10, y: cy - 16), control2: CGPoint(x: cx + 18, y: cy))
            g.fill(h, with: .color(ICColor(0x7A4428).color))
        }
        g.stroke(Path(roundedRect: CGRect(x: -20, y: -128, width: 6, height: 24), cornerRadius: 3), with: .color(.white.opacity(0.55)), lineWidth: 3)
    }

    /// Whipped cream can, upside down, star nozzle (the tip) at the origin.
    static func whipCan(_ g: GraphicsContext) {
        var nozzle = Path()
        for k in 0..<6 {
            let x = -9 + CGFloat(k) * 3.6
            nozzle.move(to: CGPoint(x: x, y: 0))
            nozzle.addLine(to: CGPoint(x: x * 1.3, y: -24))
        }
        let white = ICColor(0xF4F6FA)
        let n = Path(roundedRect: CGRect(x: -11, y: -26, width: 22, height: 26), cornerRadius: 5)
        g.fill(n, with: .color(white.color))
        g.stroke(nozzle, with: .color(ICColor(0xB7C2D0).color), lineWidth: 1.5)
        g.stroke(n, with: .color(ICColor(0x9AA6B6).color), lineWidth: 2)
        let body = Path(roundedRect: CGRect(x: -26, y: -150, width: 52, height: 124), cornerRadius: 14)
        let blue = ICColor(0x7EC2F2)
        g.fill(body, with: .linearGradient(Gradient(colors: [white.color, ICColor(0xD8E2EE).color]),
                                           startPoint: CGPoint(x: -26, y: 0), endPoint: CGPoint(x: 26, y: 0)))
        var band = g
        band.clip(to: body)
        band.fill(Path(CGRect(x: -30, y: -112, width: 60, height: 40)), with: .color(blue.color))
        for k in 0..<4 {
            band.fill(circle(CGPoint(x: -14 + CGFloat(k) * 9, y: -92 + CGFloat(k % 2) * 6), 5), with: .color(.white))
        }
        g.stroke(body, with: .color(outline(blue)), lineWidth: 2.5)
        g.fill(Path(roundedRect: CGRect(x: -20, y: -36, width: 40, height: 12), cornerRadius: 4), with: .color(ICColor(0xFF8FB8).color))
    }

    /// The milk jug, drawn around its middle, spout at the top right.
    static func milkJug(_ g: GraphicsContext) {
        let white = ICColor(0xFFFFFF)
        var body = Path()
        body.move(to: CGPoint(x: -24, y: -44))
        body.addLine(to: CGPoint(x: 22, y: -44))
        body.addLine(to: CGPoint(x: 32, y: -56))
        body.addLine(to: CGPoint(x: 30, y: -40))
        body.addQuadCurve(to: CGPoint(x: 28, y: 44), control: CGPoint(x: 40, y: 0))
        body.addLine(to: CGPoint(x: -28, y: 44))
        body.addQuadCurve(to: CGPoint(x: -24, y: -44), control: CGPoint(x: -38, y: 0))
        body.closeSubpath()
        var handle = Path()
        handle.move(to: CGPoint(x: -30, y: -26))
        handle.addQuadCurve(to: CGPoint(x: -32, y: 24), control: CGPoint(x: -66, y: 0))
        g.stroke(handle, with: .color(ICColor(0xA9C6DA).color), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        g.fill(body, with: .color(white.color(0.9)))
        var milk = g
        milk.clip(to: body)
        milk.fill(Path(CGRect(x: -40, y: -24, width: 80, height: 70)), with: .color(ICColor(0xFFFDF5).color))
        milk.fill(Path(CGRect(x: -40, y: -2, width: 80, height: 22)), with: .color(ICColor(0x7EC2F2).color))
        milk.fill(circle(CGPoint(x: 0, y: 9), 7), with: .color(.white))
        g.stroke(body, with: .color(ICColor(0xA9C6DA).color), lineWidth: 2.5)
    }
}
