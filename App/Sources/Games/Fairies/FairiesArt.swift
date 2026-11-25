import SwiftUI

enum FairiesArt {
    // MARK: - Main Scene Dispatch

    static func drawScene(_ g: GraphicsContext, sim: FairiesSim) {
        switch sim.mode {
        case .meadow:
            drawMeadowScene(g, sim: sim)
        case .compact:
            drawCompactScene(g, sim: sim)
        }
    }

    // MARK: - Mode A: Sparkle Meadow Scene

    private static func drawMeadowScene(_ g: GraphicsContext, sim: FairiesSim) {
        let t = sim.time
        drawMeadowBackdrop(g, time: t)
        drawChimeVineAndChimes(g, sim: sim)

        for spot in MeadowSpot.allCases {
            drawMeadowSpot(g, spot: spot, sim: sim)
        }

        if let rev = sim.revealedFairy {
            drawRevealedFairy(g, rev: rev, time: t)
        }

        if let cel = sim.celebration {
            drawCatchCelebration(g, celebration: cel, time: t)
        }

        drawParticles(g, particles: sim.particles, time: t)
        drawWandTrail(g, trail: sim.wandTrail)

        if let tip = sim.wandTip {
            let finger = sim.wandFinger ?? CGPoint(x: tip.x + 56, y: tip.y + 82)
            drawWand(g, tip: tip, finger: finger, time: t)
        }
    }

    private static func drawMeadowBackdrop(_ g: GraphicsContext, time t: Double) {
        let stage = CGRect(x: 0, y: 0, width: GameChromeLayout.width, height: GameChromeLayout.height)
        g.fill(
            Path(stage),
            with: .linearGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFE6F6),
                    StorybookArt.color(0xFFF3EC),
                    StorybookArt.color(0xE8F8FF),
                ]),
                startPoint: CGPoint(x: 512, y: 0),
                endPoint: CGPoint(x: 512, y: 480)
            )
        )

        // Soft sunlit pastel rainbow arching across the sky
        let rainbowCenter = CGPoint(x: 512, y: 465)
        let bands: [(CGFloat, UInt32)] = [
            (378, 0xFFB5D6),
            (360, 0xFFD2A6),
            (342, 0xFFF0A6),
            (324, 0xB8F0D6),
            (306, 0xB5DFFF),
            (288, 0xD9C4FF),
        ]
        for (radius, hex) in bands {
            var arc = Path()
            arc.addArc(center: rainbowCenter, radius: radius, startAngle: .degrees(192), endAngle: .degrees(348), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(hex, alpha: 0.42)), style: StrokeStyle(lineWidth: 18, lineCap: .round))
        }

        // Drifting fluffy pastel clouds
        let cloudDrift = CGFloat(sin(t * 0.25)) * 18
        drawCloud(g, at: CGPoint(x: 156 + cloudDrift, y: 174), scale: 0.95)
        drawCloud(g, at: CGPoint(x: 848 - cloudDrift * 0.8, y: 162), scale: 1.05)
        drawCloud(g, at: CGPoint(x: 318 - cloudDrift * 0.5, y: 244), scale: 0.65)
        drawCloud(g, at: CGPoint(x: 726 + cloudDrift * 0.6, y: 236), scale: 0.68)

        // Far pastel rolling hills
        var backHill = Path()
        backHill.move(to: CGPoint(x: -20, y: 472))
        backHill.addQuadCurve(to: CGPoint(x: 520, y: 446), control: CGPoint(x: 240, y: 374))
        backHill.addQuadCurve(to: CGPoint(x: 1044, y: 468), control: CGPoint(x: 790, y: 382))
        backHill.addLine(to: CGPoint(x: 1044, y: 834))
        backHill.addLine(to: CGPoint(x: -20, y: 834))
        backHill.closeSubpath()
        g.fill(
            backHill,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xCCF2D8), StorybookArt.color(0xA6E4BE)]),
                startPoint: CGPoint(x: 512, y: 390),
                endPoint: CGPoint(x: 512, y: 600)
            )
        )
        g.stroke(backHill, with: .color(StorybookArt.outline(for: 0x99D9B2, factor: 0.78)), lineWidth: 3)

        // Foreground sunlit fairy lawn
        var frontHill = Path()
        frontHill.move(to: CGPoint(x: -20, y: 506))
        frontHill.addQuadCurve(to: CGPoint(x: 512, y: 492), control: CGPoint(x: 260, y: 462))
        frontHill.addQuadCurve(to: CGPoint(x: 1044, y: 510), control: CGPoint(x: 772, y: 458))
        frontHill.addLine(to: CGPoint(x: 1044, y: 834))
        frontHill.addLine(to: CGPoint(x: -20, y: 834))
        frontHill.closeSubpath()
        g.fill(
            frontHill,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xB8EFC6), StorybookArt.color(0x8FDDA8), StorybookArt.color(0x7CCF9A)]),
                startPoint: CGPoint(x: 512, y: 470),
                endPoint: CGPoint(x: 512, y: 834)
            )
        )
        g.stroke(frontHill, with: .color(StorybookArt.outline(for: 0x80CE98, factor: 0.76)), lineWidth: 3.2)

        // Soft winding fairy stepping path
        let stones: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: 320, y: 638), 44, 18),
            (CGPoint(x: 432, y: 618), 52, 20),
            (CGPoint(x: 552, y: 626), 50, 19),
            (CGPoint(x: 672, y: 642), 46, 18),
        ]
        for (c, w, h) in stones {
            let p = Path(ellipseIn: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
            StorybookArt.fillAndStroke(g, p, fill: StorybookArt.color(0xFFF6EC), stroke: StorybookArt.outline(for: 0xE6CEBE, factor: 0.8), width: 2.4)
        }

        // Scattered tiny pastel meadow flowers
        let daisies: [(CGPoint, UInt32)] = [
            (CGPoint(x: 84, y: 610), 0xFFB0D4),
            (CGPoint(x: 266, y: 660), 0xFFE38A),
            (CGPoint(x: 504, y: 564), 0xFFFFFF),
            (CGPoint(x: 750, y: 628), 0xFFB0D4),
            (CGPoint(x: 944, y: 616), 0xD2B8FF),
            (CGPoint(x: 132, y: 674), 0xFFFFFF),
            (CGPoint(x: 890, y: 676), 0xFFE38A),
        ]
        for (pos, hex) in daisies {
            drawTinyFlower(g, at: pos, radius: 9, petalHex: hex)
        }

        // Ambient sky twinkles
        for i in 0..<7 {
            let x = CGFloat(110 + i * 135)
            let y = CGFloat(130 + (i % 3) * 44)
            let alpha = 0.35 + 0.45 * abs(sin(t * 1.4 + Double(i) * 1.1))
            StorybookArt.sparkle(g, at: CGPoint(x: x, y: y), radius: CGFloat(6 + (i % 2) * 3), color: .white, opacity: alpha)
        }
    }

    private static func drawCloud(_ g: GraphicsContext, at center: CGPoint, scale: CGFloat) {
        var c = g
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: scale, y: scale)
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-36, 8, 22), (-14, -4, 28), (16, -2, 26), (38, 9, 20), (0, 10, 26),
        ]
        for (px, py, pr) in puffs {
            c.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(.white.opacity(0.86)))
        }
    }

    private static func drawTinyFlower(_ g: GraphicsContext, at center: CGPoint, radius: CGFloat, petalHex: UInt32) {
        for k in 0..<5 {
            let a = CGFloat(k) * (2 * .pi / 5) - .pi / 2
            let px = center.x + cos(a) * radius * 0.62
            let py = center.y + sin(a) * radius * 0.62
            let pr = radius * 0.48
            g.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(StorybookArt.color(petalHex)))
        }
        let cr = radius * 0.36
        g.fill(Path(ellipseIn: CGRect(x: center.x - cr, y: center.y - cr, width: cr * 2, height: cr * 2)), with: .color(Theme.lemon))
    }

    // MARK: - 3 Glowing Musical Chimes

    private static func drawChimeVineAndChimes(_ g: GraphicsContext, sim: FairiesSim) {
        let t = sim.time
        // Delicate curved blossom branch cradling the 3 musical chimes
        var vine = Path()
        vine.move(to: CGPoint(x: 344, y: 126))
        vine.addQuadCurve(to: CGPoint(x: 512, y: 108), control: CGPoint(x: 428, y: 104))
        vine.addQuadCurve(to: CGPoint(x: 680, y: 126), control: CGPoint(x: 596, y: 104))
        g.stroke(vine, with: .color(StorybookArt.color(0x7AC78C)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        g.stroke(vine, with: .color(StorybookArt.color(0xB4E8BC)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        for lx in [CGFloat(366), 462, 562, 658] {
            let ly: CGFloat = abs(lx - 512) < 90 ? 111 : 120
            drawTinyFlower(g, at: CGPoint(x: lx, y: ly), radius: 9, petalHex: 0xFFB8D8)
        }

        for chime in MeadowChime.allCases {
            let swingLeft = max(0, (sim.chimeSwingUntil[chime] ?? -10) - t)
            let sway = sin(t * 2.1 + Double(chime.rawValue) * 1.4) * 0.05
                + (swingLeft > 0 ? sin(t * 20) * 0.34 * min(1, swingLeft) : 0)

            var c = g
            c.translateBy(x: chime.anchor.x, y: chime.anchor.y)
            c.rotate(by: .radians(sway))

            let cordLen = chime.center.y - chime.anchor.y - 24
            var cord = Path()
            cord.move(to: .zero)
            cord.addLine(to: CGPoint(x: 0, y: cordLen))
            c.stroke(cord, with: .color(StorybookArt.color(0xE8B84B)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            let bellY = cordLen + 24
            let glowBoost = swingLeft > 0 ? 0.55 : 0.28 + 0.12 * sin(t * 3 + Double(chime.rawValue))
            c.fill(
                Path(ellipseIn: CGRect(x: -36, y: bellY - 36, width: 72, height: 72)),
                with: .radialGradient(
                    Gradient(colors: [StorybookArt.color(chime.colorHex, alpha: glowBoost), StorybookArt.color(chime.colorHex, alpha: 0)]),
                    center: CGPoint(x: 0, y: bellY),
                    startRadius: 6,
                    endRadius: 36
                )
            )

            // Scalloped crystal bell dome
            var bell = Path()
            bell.move(to: CGPoint(x: -20, y: bellY + 12))
            bell.addCurve(to: CGPoint(x: 0, y: bellY - 22), control1: CGPoint(x: -22, y: bellY - 8), control2: CGPoint(x: -12, y: bellY - 22))
            bell.addCurve(to: CGPoint(x: 20, y: bellY + 12), control1: CGPoint(x: 12, y: bellY - 22), control2: CGPoint(x: 22, y: bellY - 8))
            bell.addQuadCurve(to: CGPoint(x: -20, y: bellY + 12), control: CGPoint(x: 0, y: bellY + 18))
            bell.closeSubpath()

            c.fill(
                bell,
                with: .linearGradient(
                    Gradient(colors: [StorybookArt.tint(for: chime.colorHex, amount: 0.45), StorybookArt.color(chime.colorHex)]),
                    startPoint: CGPoint(x: -14, y: bellY - 20),
                    endPoint: CGPoint(x: 16, y: bellY + 14)
                )
            )
            c.stroke(bell, with: .color(StorybookArt.outline(for: chime.colorHex)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            StorybookArt.highlight(c, in: CGRect(x: -11, y: bellY - 14, width: 10, height: 14), opacity: 0.65)

            // Hanging golden star clapper
            var clapper = Path()
            clapper.move(to: CGPoint(x: 0, y: bellY + 13))
            clapper.addLine(to: CGPoint(x: 0, y: bellY + 25))
            c.stroke(clapper, with: .color(StorybookArt.color(0xE6A93B)), lineWidth: 2.4)
            StorybookArt.sparkle(c, at: CGPoint(x: 0, y: bellY + 27), radius: 9, color: Theme.lemon)

            // Tiny music note emblem on the crystal bell
            let noteDot = Path(ellipseIn: CGRect(x: -5, y: bellY - 1, width: 8, height: 6.5))
            c.fill(noteDot, with: .color(.white.opacity(0.9)))
            var stem = Path()
            stem.move(to: CGPoint(x: 2.5, y: bellY + 1))
            stem.addLine(to: CGPoint(x: 2.5, y: bellY - 11))
            stem.addQuadCurve(to: CGPoint(x: 9, y: bellY - 6), control: CGPoint(x: 8, y: bellY - 11))
            c.stroke(stem, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    // MARK: - 4 Interactive Hiding Spots

    private static func drawMeadowSpot(_ g: GraphicsContext, spot: MeadowSpot, sim: FairiesSim) {
        let t = sim.time
        let isRustling = sim.rustlingSpots.contains(spot)
        let wiggleLeft = max(0, (sim.spotWiggleUntil[spot] ?? -10) - t)

        var wobbleAngle: Double = 0
        var squashX: CGFloat = 1
        var squashY: CGFloat = 1
        if wiggleLeft > 0 {
            wobbleAngle = sin(t * 28) * 0.1 * min(1, wiggleLeft * 1.4)
            let pop = CGFloat(sin(min(1, wiggleLeft) * .pi)) * 0.08
            squashX = 1 + pop
            squashY = 1 - pop * 0.7
        } else if isRustling {
            wobbleAngle = sin(t * 8.5 + Double(spot.center.x)) * 0.055
            let pulse = CGFloat(sin(t * 5.2 + Double(spot.center.x))) * 0.035
            squashX = 1 + pulse
            squashY = 1 - pulse * 0.6
        }

        // Shimmering aura behind rustling hiding spots
        if isRustling {
            let glowR: CGFloat = 88 + CGFloat(sin(t * 4)) * 10
            g.fill(
                Path(ellipseIn: CGRect(x: spot.center.x - glowR, y: spot.center.y - glowR * 0.9, width: glowR * 2, height: glowR * 1.8)),
                with: .radialGradient(
                    Gradient(colors: [StorybookArt.color(spot.shimmerHex, alpha: 0.44), StorybookArt.color(spot.shimmerHex, alpha: 0)]),
                    center: spot.center,
                    startRadius: 16,
                    endRadius: glowR
                )
            )
        }

        // Ground shadow
        if spot != .teacupLantern {
            g.fill(
                Path(ellipseIn: CGRect(x: spot.center.x - 68, y: spot.center.y + 44, width: 136, height: 26)),
                with: .color(StorybookArt.color(0x529970, alpha: 0.25))
            )
        }

        var c = g
        let pivot = spot == .teacupLantern
            ? CGPoint(x: spot.center.x, y: spot.center.y - 78)
            : CGPoint(x: spot.center.x, y: spot.center.y + 48)
        c.translateBy(x: pivot.x, y: pivot.y)
        c.rotate(by: .radians(wobbleAngle))
        c.scaleBy(x: squashX, y: squashY)
        c.translateBy(x: -pivot.x, y: -pivot.y)

        switch spot {
        case .blossomBush:
            drawBlossomBush(c, center: spot.center, time: t)
        case .bubbleFountain:
            drawBubbleFountain(c, center: spot.center, time: t)
        case .teacupLantern:
            drawTeacupLantern(c, center: spot.center, time: t)
        case .rainbowMushroom:
            drawRainbowMushroom(c, center: spot.center)
        }

        if isRustling {
            let phase = CGFloat(t * 2.4)
            for k in 0..<3 {
                let a = phase + CGFloat(k) * 2.1
                let sx = spot.center.x + cos(a) * 58
                let sy = spot.center.y - 26 + sin(a * 1.3) * 24
                StorybookArt.sparkle(g, at: CGPoint(x: sx, y: sy), radius: 10, color: k == 1 ? .white : Theme.lemon, opacity: 0.9)
            }
        }
    }

    private static func drawBlossomBush(_ g: GraphicsContext, center: CGPoint, time t: Double) {
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-52, 16, 40), (52, 16, 40),
            (-36, -24, 42), (36, -24, 42),
            (0, -40, 48), (0, 14, 46),
        ]
        let outline = StorybookArt.outline(for: 0x76CE98)
        for (dx, dy, r) in puffs {
            g.stroke(
                Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)),
                with: .color(outline),
                lineWidth: 7
            )
        }
        for (dx, dy, r) in puffs {
            let rect = CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)
            g.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [StorybookArt.color(0xB4F2C6), StorybookArt.color(0x7AD89E)]),
                    center: CGPoint(x: rect.midX - r * 0.25, y: rect.minY + r * 0.35),
                    startRadius: 2,
                    endRadius: r * 1.25
                )
            )
        }

        let blossoms: [(CGFloat, CGFloat, CGFloat, UInt32)] = [
            (-44, -22, 17, 0xFFB0D4),
            (38, -28, 18, 0xFFD0E6),
            (0, -46, 19, 0xFF9AC6),
            (-16, 8, 16, 0xFFE3EC),
            (46, 16, 15, 0xFFB0D4),
            (-54, 22, 14, 0xFFD0E6),
        ]
        for (dx, dy, r, hex) in blossoms {
            drawTinyFlower(g, at: CGPoint(x: center.x + dx, y: center.y + dy), radius: r, petalHex: hex)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: center.x + CGFloat(sin(t * 3)) * 8, y: center.y - 68), radius: 8, color: Theme.lemon)
    }

    private static func drawBubbleFountain(_ g: GraphicsContext, center: CGPoint, time t: Double) {
        let rimOutline = StorybookArt.outline(for: 0x9AD8F8)

        // Pedestal
        let base = Path(roundedRect: CGRect(x: center.x - 42, y: center.y + 18, width: 84, height: 34), cornerRadius: 14)
        StorybookArt.fillAndStroke(g, base, fill: StorybookArt.color(0xEBF8FF), stroke: rimOutline, width: 3.4)

        // Crystal basin
        var basin = Path()
        basin.move(to: CGPoint(x: center.x - 74, y: center.y - 4))
        basin.addQuadCurve(to: CGPoint(x: center.x - 52, y: center.y + 30), control: CGPoint(x: center.x - 72, y: center.y + 24))
        basin.addLine(to: CGPoint(x: center.x + 52, y: center.y + 30))
        basin.addQuadCurve(to: CGPoint(x: center.x + 74, y: center.y - 4), control: CGPoint(x: center.x + 72, y: center.y + 24))
        basin.closeSubpath()
        g.fill(
            basin,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xF5FBFF), StorybookArt.color(0xC8ECFF)]),
                startPoint: CGPoint(x: center.x, y: center.y - 6),
                endPoint: CGPoint(x: center.x, y: center.y + 30)
            )
        )
        g.stroke(basin, with: .color(rimOutline), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

        // Sparkling aqua water surface
        let water = Path(ellipseIn: CGRect(x: center.x - 68, y: center.y - 16, width: 136, height: 26))
        StorybookArt.fillAndStroke(g, water, fill: StorybookArt.color(0x88DAFF), stroke: rimOutline, width: 3)
        StorybookArt.highlight(g, in: CGRect(x: center.x - 44, y: center.y - 10, width: 52, height: 7), opacity: 0.72)

        // Center crystal pillar & heart crest
        let pillar = Path(roundedRect: CGRect(x: center.x - 16, y: center.y - 54, width: 32, height: 50), cornerRadius: 12)
        StorybookArt.fillAndStroke(g, pillar, fill: StorybookArt.color(0xF2FAFF), stroke: rimOutline, width: 3)
        StorybookArt.heart(g, at: CGPoint(x: center.x, y: center.y - 54), size: 34, color: Theme.pink)

        // Arching water jets
        for side in [-1.0, 1.0] as [CGFloat] {
            var jet = Path()
            jet.move(to: CGPoint(x: center.x + side * 6, y: center.y - 60))
            jet.addQuadCurve(
                to: CGPoint(x: center.x + side * 46, y: center.y - 4),
                control: CGPoint(x: center.x + side * 38, y: center.y - 84)
            )
            g.stroke(jet, with: .color(StorybookArt.color(0x9EE4FF, alpha: 0.85)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            g.stroke(jet, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }

        // Animated rising rainbow bubbles
        for i in 0..<4 {
            let phase = (t * 0.9 + Double(i) * 0.28).truncatingRemainder(dividingBy: 1)
            let bx = center.x + CGFloat(i - 1) * 24 - 12 + CGFloat(sin(t * 3 + Double(i))) * 6
            let by = center.y - 10 - CGFloat(phase) * 76
            let br = CGFloat(8 + (i % 2) * 4)
            drawBubble(g, at: CGPoint(x: bx, y: by), radius: br, alpha: 1 - phase * 0.75)
        }
    }

    private static func drawTeacupLantern(_ g: GraphicsContext, center: CGPoint, time t: Double) {
        // Curving flowering branch overhead
        var branch = Path()
        branch.move(to: CGPoint(x: center.x + 128, y: center.y - 108))
        branch.addQuadCurve(to: CGPoint(x: center.x - 42, y: center.y - 80), control: CGPoint(x: center.x + 36, y: center.y - 112))
        g.stroke(branch, with: .color(StorybookArt.color(0xA4765C)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        drawTinyFlower(g, at: CGPoint(x: center.x - 28, y: center.y - 82), radius: 13, petalHex: 0xFFB8D6)
        drawTinyFlower(g, at: CGPoint(x: center.x + 56, y: center.y - 100), radius: 14, petalHex: 0xFFE38A)

        // Golden hanging chains
        for sx in [-36.0, 36.0] as [CGFloat] {
            var chain = Path()
            chain.move(to: CGPoint(x: center.x, y: center.y - 90))
            chain.addLine(to: CGPoint(x: center.x + sx, y: center.y - 24))
            g.stroke(chain, with: .color(StorybookArt.color(0xE8B442)), style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
        }

        // Warm lantern glow from inside the teacup
        let glowPulse = 0.55 + 0.2 * sin(t * 3.4)
        g.fill(
            Path(ellipseIn: CGRect(x: center.x - 58, y: center.y - 54, width: 116, height: 74)),
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFFF3B0, alpha: glowPulse), StorybookArt.color(0xFFF3B0, alpha: 0)]),
                center: CGPoint(x: center.x, y: center.y - 18),
                startRadius: 8,
                endRadius: 58
            )
        )

        let cupOutline = StorybookArt.outline(for: 0xF5B562)
        // Curved teacup handle
        let handle = Path(ellipseIn: CGRect(x: center.x + 36, y: center.y - 14, width: 32, height: 34))
        g.stroke(handle, with: .color(cupOutline), lineWidth: 10)
        g.stroke(handle, with: .color(StorybookArt.color(0xFFE699)), lineWidth: 5)

        // Saucer
        let saucer = Path(ellipseIn: CGRect(x: center.x - 62, y: center.y + 26, width: 124, height: 22))
        StorybookArt.fillAndStroke(g, saucer, fill: StorybookArt.color(0xFFF3D4), stroke: cupOutline, width: 3.2)

        // Porcelain teacup body
        var cup = Path()
        cup.move(to: CGPoint(x: center.x - 52, y: center.y - 24))
        cup.addCurve(to: CGPoint(x: center.x - 32, y: center.y + 34), control1: CGPoint(x: center.x - 50, y: center.y + 10), control2: CGPoint(x: center.x - 44, y: center.y + 28))
        cup.addLine(to: CGPoint(x: center.x + 32, y: center.y + 34))
        cup.addCurve(to: CGPoint(x: center.x + 52, y: center.y - 24), control1: CGPoint(x: center.x + 44, y: center.y + 28), control2: CGPoint(x: center.x + 50, y: center.y + 10))
        cup.closeSubpath()
        g.fill(
            cup,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFF8D6), StorybookArt.color(0xFFDF8E)]),
                startPoint: CGPoint(x: center.x - 30, y: center.y - 20),
                endPoint: CGPoint(x: center.x + 30, y: center.y + 34)
            )
        )
        g.stroke(cup, with: .color(cupOutline), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))

        let rim = Path(ellipseIn: CGRect(x: center.x - 52, y: center.y - 34, width: 104, height: 20))
        StorybookArt.fillAndStroke(g, rim, fill: StorybookArt.color(0xFFF7BE), stroke: cupOutline, width: 3)
        StorybookArt.heart(g, at: CGPoint(x: center.x, y: center.y + 8), size: 22, color: Theme.pink)
        StorybookArt.highlight(g, in: CGRect(x: center.x - 38, y: center.y - 12, width: 14, height: 22), opacity: 0.55)
    }

    private static func drawRainbowMushroom(_ g: GraphicsContext, center: CGPoint) {
        let stemOutline = StorybookArt.outline(for: 0xE6C8B0)
        // Plump cream stem
        var stem = Path()
        stem.move(to: CGPoint(x: center.x - 30, y: center.y - 14))
        stem.addQuadCurve(to: CGPoint(x: center.x - 42, y: center.y + 50), control: CGPoint(x: center.x - 42, y: center.y + 20))
        stem.addQuadCurve(to: CGPoint(x: center.x + 42, y: center.y + 50), control: CGPoint(x: center.x, y: center.y + 58))
        stem.addQuadCurve(to: CGPoint(x: center.x + 30, y: center.y - 14), control: CGPoint(x: center.x + 42, y: center.y + 20))
        stem.closeSubpath()
        StorybookArt.fillAndStroke(g, stem, fill: StorybookArt.color(0xFFF7EC), stroke: stemOutline, width: 3.4)

        // Cute arched fairy door on the stem
        var door = Path()
        door.move(to: CGPoint(x: center.x - 16, y: center.y + 50))
        door.addLine(to: CGPoint(x: center.x - 16, y: center.y + 22))
        door.addArc(center: CGPoint(x: center.x, y: center.y + 22), radius: 16, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        door.addLine(to: CGPoint(x: center.x + 16, y: center.y + 50))
        door.closeSubpath()
        StorybookArt.fillAndStroke(g, door, fill: StorybookArt.color(0xFFD6E8), stroke: StorybookArt.outline(for: 0xF09BC2), width: 2.6)
        g.fill(Path(ellipseIn: CGRect(x: center.x + 6, y: center.y + 32, width: 6, height: 6)), with: .color(Theme.lemon))

        // Pastel rainbow mushroom cap
        var cap = Path()
        cap.move(to: CGPoint(x: center.x - 82, y: center.y - 8))
        cap.addCurve(
            to: CGPoint(x: center.x, y: center.y - 84),
            control1: CGPoint(x: center.x - 80, y: center.y - 58),
            control2: CGPoint(x: center.x - 40, y: center.y - 84)
        )
        cap.addCurve(
            to: CGPoint(x: center.x + 82, y: center.y - 8),
            control1: CGPoint(x: center.x + 40, y: center.y - 84),
            control2: CGPoint(x: center.x + 80, y: center.y - 58)
        )
        cap.addQuadCurve(to: CGPoint(x: center.x - 82, y: center.y - 8), control: CGPoint(x: center.x, y: center.y + 10))
        cap.closeSubpath()

        g.fill(
            cap,
            with: .linearGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFF9AC8),
                    StorybookArt.color(0xFFD299),
                    StorybookArt.color(0xFFF099),
                    StorybookArt.color(0x9EE8CA),
                    StorybookArt.color(0xB8C6FF),
                ]),
                startPoint: CGPoint(x: center.x - 80, y: center.y - 40),
                endPoint: CGPoint(x: center.x + 80, y: center.y - 10)
            )
        )
        g.stroke(cap, with: .color(StorybookArt.outline(for: 0xD898D0)), style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))

        let spots: [(CGFloat, CGFloat, CGFloat)] = [
            (-42, -26, 13), (-8, -54, 15), (34, -44, 12), (52, -18, 10), (8, -22, 11),
        ]
        for (dx, dy, r) in spots {
            g.fill(Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.84)))
        }
    }

    // MARK: - Revealed Meadow Fairy & Catch Celebration

    private static func drawRevealedFairy(_ g: GraphicsContext, rev: RevealedMeadowFairy, time t: Double) {
        let pos = rev.position
        let pulse = 1 + CGFloat(sin(t * 5.2)) * 0.06
        let glowR: CGFloat = 74 * pulse

        g.fill(
            Path(ellipseIn: CGRect(x: pos.x - glowR, y: pos.y - glowR, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.85),
                    StorybookArt.color(rev.kind.palette.emblem, alpha: 0.35),
                    StorybookArt.color(rev.kind.palette.emblem, alpha: 0),
                ]),
                center: pos,
                startRadius: 10,
                endRadius: glowR
            )
        )

        let ring = Path(ellipseIn: CGRect(x: pos.x - 62 * pulse, y: pos.y - 62 * pulse, width: 124 * pulse, height: 124 * pulse))
        g.stroke(ring, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 3, dash: [8, 8]))

        var c = g
        c.translateBy(x: pos.x, y: pos.y)
        drawFairy(c, kind: rev.kind, mood: .giggle, accessory: nil, time: t, scale: 1.24, blinkSeed: rev.phase)

        StorybookArt.heart(g, at: CGPoint(x: pos.x - 48, y: pos.y - 44 + CGFloat(sin(t * 4)) * 6), size: 18, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: pos.x + 52, y: pos.y - 38 + CGFloat(cos(t * 4.5)) * 6), radius: 11, color: Theme.lemon)
    }

    private static func drawCatchCelebration(_ g: GraphicsContext, celebration: CatchCelebration, time t: Double) {
        let elapsed = max(0, t - celebration.startedAt)
        let u = CGFloat(min(1, elapsed / 1.35))
        let target = CGPoint(x: 556, y: 56) // glides toward Compact icon in top bar
        let fly = max(0, (u - 0.45) / 0.55)
        let e = fly * fly * (3 - 2 * fly)

        let pos = CGPoint(
            x: celebration.startPos.x + (target.x - celebration.startPos.x) * e,
            y: celebration.startPos.y + (target.y - celebration.startPos.y) * e - sin(e * .pi) * 90
        )
        let popScale: CGFloat = u < 0.3 ? (1.2 + 0.35 * sin(u / 0.3 * .pi)) : (1.2 * (1 - 0.65 * e))

        // Heart halo explosion
        let ringR = 40 + u * 110
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * 2 * .pi + u * 2
            let hp = CGPoint(x: pos.x + cos(a) * ringR * (1 - e * 0.6), y: pos.y + sin(a) * ringR * (1 - e * 0.6))
            StorybookArt.heart(g, at: hp, size: 22 * (1 - u * 0.5), color: i.isMultiple(of: 2) ? Theme.pink : Theme.lemon, opacity: Double(1 - u))
        }

        var c = g
        c.translateBy(x: pos.x, y: pos.y)
        c.rotate(by: .radians(Double(sin(u * 14) * 0.16)))
        drawFairy(c, kind: celebration.kind, mood: .celebrate, accessory: nil, time: t, scale: popScale, blinkSeed: 1.5)
    }

    // MARK: - Heart Magic Wand

    private static func drawWandTrail(_ g: GraphicsContext, trail: [WandSparkle]) {
        for s in trail {
            let alpha = Double(max(0, 1 - s.age / s.maxAge))
            let r = s.size * (1 - s.age / s.maxAge * 0.45)
            StorybookArt.sparkle(g, at: s.pos, radius: r, color: StorybookArt.color(s.colorHex), opacity: alpha)
        }
    }

    static func drawWand(_ g: GraphicsContext, tip: CGPoint, finger: CGPoint, time t: Double) {
        let h = FingerLift.handle(tip: tip, finger: finger, length: 132)
        let end = CGPoint(x: tip.x + h.dir.dx * h.length, y: tip.y + h.dir.dy * h.length)
        let angle = atan2(Double(tip.y - end.y), Double(tip.x - end.x))

        // Handle stick
        var stick = Path()
        stick.move(to: end)
        stick.addLine(to: tip)
        g.stroke(stick, with: .color(StorybookArt.outline(for: 0xFF8FB8)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        g.stroke(stick, with: .color(StorybookArt.color(0xFFD6E9)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        g.stroke(stick, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

        // Golden pommel pearl at handle end
        let pommel = Path(ellipseIn: CGRect(x: end.x - 11, y: end.y - 11, width: 22, height: 22))
        StorybookArt.fillAndStroke(g, pommel, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 3)

        // Glowing aura at wand tip
        let glowR: CGFloat = 46 + CGFloat(sin(t * 7)) * 6
        g.fill(
            Path(ellipseIn: CGRect(x: tip.x - glowR, y: tip.y - glowR, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFFF3B0, alpha: 0.72), StorybookArt.color(0xFF9ED0, alpha: 0)]),
                center: tip,
                startRadius: 6,
                endRadius: glowR
            )
        )

        var head = g
        head.translateBy(x: tip.x, y: tip.y)
        head.rotate(by: .radians(angle + .pi / 2))

        // Twin mini pearl fairy wings on wand collar
        for side in [-1.0, 1.0] as [CGFloat] {
            var wing = Path()
            wing.move(to: CGPoint(x: side * 8, y: 12))
            wing.addCurve(
                to: CGPoint(x: side * 34, y: -4),
                control1: CGPoint(x: side * 24, y: 18),
                control2: CGPoint(x: side * 36, y: 8)
            )
            wing.addCurve(
                to: CGPoint(x: side * 8, y: 2),
                control1: CGPoint(x: side * 26, y: -12),
                control2: CGPoint(x: side * 14, y: -6)
            )
            wing.closeSubpath()
            StorybookArt.fillAndStroke(head, wing, fill: .white, stroke: StorybookArt.outline(for: 0xD8B4F2), width: 2.6)
        }

        // Golden bezel & faceted heart jewel
        let bezel = heartPath(center: CGPoint(x: 0, y: -2), size: 48)
        StorybookArt.fillAndStroke(head, bezel, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE0A030), width: 3.2)
        let gem = heartPath(center: CGPoint(x: 0, y: -2), size: 34)
        StorybookArt.fillAndStroke(head, gem, fill: StorybookArt.color(0xFF66A8), stroke: StorybookArt.outline(for: 0xE04688), width: 2.4)
        StorybookArt.highlight(head, in: CGRect(x: -10, y: -13, width: 9, height: 6), opacity: 0.85)
        StorybookArt.sparkle(head, at: CGPoint(x: 16, y: -20), radius: 8, color: .white)
    }

    // MARK: - Mode B: Heart Jewel Compact Dollhouse Scene

    private static func drawCompactScene(_ g: GraphicsContext, sim: FairiesSim) {
        let t = sim.time
        let openElapsed = max(0, t - sim.compactOpenAt)
        let openScale: CGFloat = openElapsed < 0.42
            ? CGFloat(0.86 + 0.14 * sin(min(1, openElapsed / 0.42) * .pi * 0.5) + 0.04 * sin(min(1, openElapsed / 0.42) * .pi))
            : 1.0

        drawCompactBackdrop(g, time: t)

        var room = g
        room.translateBy(x: FGeo.compactCenter.x, y: FGeo.compactCenter.y)
        room.scaleBy(x: openScale, y: openScale)
        room.translateBy(x: -FGeo.compactCenter.x, y: -FGeo.compactCenter.y)

        drawHeartCompactShell(room, time: t)

        if sim.hasCarousel {
            drawCompactCarousel(room, center: CGPoint(x: 396, y: 454), time: t)
        }

        let showTargets = sim.draggingCompactFairy != nil || sim.pendingPlacementFairy != nil
        for spot in CompactSpot.allCases {
            let hovered = sim.compactHoverSpot == spot
            drawCompactSpot(room, spot: spot, sim: sim, highlighted: showTargets, hovered: hovered)
        }

        if sim.hasChandelier {
            drawCompactChandelier(room, anchor: CGPoint(x: FGeo.compactCenter.x, y: FGeo.compactCenter.y - FGeo.compactHeight * 0.34 + 12), time: t)
        }

        drawParticles(room, particles: sim.particles, time: t)

        // Draw dragged fairy above everything
        if let dragged = sim.draggingCompactFairy {
            var d = g
            d.translateBy(x: sim.compactDragPos.x, y: sim.compactDragPos.y)
            d.fill(
                Path(ellipseIn: CGRect(x: -54, y: -54, width: 108, height: 108)),
                with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.65), .white.opacity(0)]),
                    center: .zero,
                    startRadius: 8,
                    endRadius: 54
                )
            )
            drawFairy(d, kind: dragged, mood: .giggle, accessory: sim.accessories[dragged], time: t, scale: 1.18, blinkSeed: Double(dragged.hashValue % 13))
        }
    }

    private static func drawCompactBackdrop(_ g: GraphicsContext, time t: Double) {
        let stage = CGRect(x: 0, y: 0, width: GameChromeLayout.width, height: GameChromeLayout.height)
        g.fill(
            Path(stage),
            with: .linearGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFE0F2),
                    StorybookArt.color(0xF3E6FF),
                    StorybookArt.color(0xFFEBF5),
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 1024, y: 834)
            )
        )

        // Soft dreamy starlight bokeh
        for i in 0..<14 {
            let x = CGFloat((i * 173 + 52) % 980) + 22
            let y = CGFloat((i * 139 + 64) % 720) + 40
            let r = CGFloat(14 + (i % 4) * 9)
            let alpha = 0.2 + 0.16 * sin(t * 1.4 + Double(i))
            g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha)))
            if i % 2 == 0 {
                StorybookArt.sparkle(g, at: CGPoint(x: x, y: y), radius: 7, color: Theme.lemon, opacity: alpha * 1.8)
            }
        }
    }

    private static func heartCompactPath(center: CGPoint, width: CGFloat, height: CGFloat) -> Path {
        let cx = center.x
        let topDipY = center.y - height * 0.34
        let topY = center.y - height * 0.5
        let bottomY = center.y + height * 0.5
        let hw = width * 0.5

        var p = Path()
        p.move(to: CGPoint(x: cx, y: topDipY))
        p.addCurve(
            to: CGPoint(x: cx + hw, y: center.y - height * 0.08),
            control1: CGPoint(x: cx + hw * 0.34, y: topY - height * 0.14),
            control2: CGPoint(x: cx + hw * 1.06, y: topY + height * 0.04)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: bottomY),
            control1: CGPoint(x: cx + hw * 0.96, y: center.y + height * 0.32),
            control2: CGPoint(x: cx + hw * 0.38, y: bottomY - height * 0.02)
        )
        p.addCurve(
            to: CGPoint(x: cx - hw, y: center.y - height * 0.08),
            control1: CGPoint(x: cx - hw * 0.38, y: bottomY - height * 0.02),
            control2: CGPoint(x: cx - hw * 0.96, y: center.y + height * 0.32)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: topDipY),
            control1: CGPoint(x: cx - hw * 1.06, y: topY + height * 0.04),
            control2: CGPoint(x: cx - hw * 0.34, y: topY - height * 0.14)
        )
        p.closeSubpath()
        return p
    }

    private static func drawHeartCompactShell(_ g: GraphicsContext, time t: Double) {
        let c = FGeo.compactCenter

        // Drop shadow under jewel box
        let shadowPath = heartCompactPath(center: CGPoint(x: c.x, y: c.y + 12), width: FGeo.compactWidth + 14, height: FGeo.compactHeight + 14)
        g.fill(shadowPath, with: .color(Theme.ink.opacity(0.14)))

        // Outer rose-pink & gold bezel shell
        let outer = heartCompactPath(center: c, width: FGeo.compactWidth, height: FGeo.compactHeight)
        g.fill(
            outer,
            with: .linearGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFB8DC),
                    StorybookArt.color(0xFF9AC8),
                    StorybookArt.color(0xE88BC2),
                ]),
                startPoint: CGPoint(x: c.x, y: c.y - 300),
                endPoint: CGPoint(x: c.x, y: c.y + 300)
            )
        )
        g.stroke(outer, with: .color(StorybookArt.color(0xF5CA5C)), lineWidth: 10)
        g.stroke(outer, with: .color(StorybookArt.outline(for: 0xE6A436)), lineWidth: 3.2)

        // Creamy pastel velvet room interior
        let inner = heartCompactPath(center: c, width: FGeo.compactWidth - 46, height: FGeo.compactHeight - 44)
        g.fill(
            inner,
            with: .radialGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFFDFB),
                    StorybookArt.color(0xFFF2F8),
                    StorybookArt.color(0xFCE2F2),
                ]),
                center: CGPoint(x: c.x, y: c.y - 40),
                startRadius: 30,
                endRadius: 420
            )
        )
        g.stroke(inner, with: .color(StorybookArt.color(0xF5D078)), lineWidth: 5)

        // Subtle wallpaper stripes & dollhouse floor line clipped to interior
        var clipped = g
        clipped.clip(to: inner)
        for sx in stride(from: c.x - 380, through: c.x + 380, by: 48) {
            clipped.fill(
                Path(CGRect(x: sx, y: c.y - 310, width: 22, height: 340)),
                with: .color(StorybookArt.color(0xFFD9EB, alpha: 0.22))
            )
        }
        // Cozy warm pastel dollhouse floor
        clipped.fill(
            Path(CGRect(x: c.x - 420, y: c.y + 24, width: 840, height: 290)),
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFF4E6), StorybookArt.color(0xFCE4D6)]),
                startPoint: CGPoint(x: c.x, y: c.y + 24),
                endPoint: CGPoint(x: c.x, y: c.y + 300)
            )
        )
        var molding = Path()
        molding.move(to: CGPoint(x: c.x - 420, y: c.y + 24))
        molding.addLine(to: CGPoint(x: c.x + 420, y: c.y + 24))
        clipped.stroke(molding, with: .color(StorybookArt.color(0xF0C2D8)), lineWidth: 5)

        // Scalloped heart rug in the center of the floor
        let rug = Path(ellipseIn: CGRect(x: c.x - 148, y: c.y + 42, width: 296, height: 92))
        StorybookArt.fillAndStroke(clipped, rug, fill: StorybookArt.color(0xFFE0F0, alpha: 0.72), stroke: StorybookArt.color(0xFFB5D6), width: 3.5)

        // Crown jewel clasp nestled in the heart's top center dip
        let claspCenter = CGPoint(x: c.x, y: c.y - FGeo.compactHeight * 0.34 - 8)
        let claspGem = heartPath(center: claspCenter, size: 38)
        StorybookArt.fillAndStroke(g, claspGem, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xDF9E2C), width: 3)
        let innerGem = heartPath(center: claspCenter, size: 24)
        StorybookArt.fillAndStroke(g, innerGem, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xDF669A), width: 2)
        StorybookArt.sparkle(g, at: CGPoint(x: claspCenter.x + 18, y: claspCenter.y - 12), radius: 8 + CGFloat(sin(t * 4)) * 2, color: .white)

        // Pearl studs along outer heart curve
        let pearls: [CGPoint] = [
            CGPoint(x: c.x - 245, y: c.y - 244),
            CGPoint(x: c.x - 356, y: c.y - 150),
            CGPoint(x: c.x - 364, y: c.y + 18),
            CGPoint(x: c.x - 240, y: c.y + 168),
            CGPoint(x: c.x + 245, y: c.y - 244),
            CGPoint(x: c.x + 356, y: c.y - 150),
            CGPoint(x: c.x + 364, y: c.y + 18),
            CGPoint(x: c.x + 240, y: c.y + 168),
        ]
        for pt in pearls {
            let pearl = Path(ellipseIn: CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14))
            StorybookArt.fillAndStroke(g, pearl, fill: .white, stroke: StorybookArt.color(0xE8B84E), width: 2.2)
        }
    }

    // MARK: - 5 Compact Dollhouse Furniture Spots

    private static func drawCompactSpot(
        _ g: GraphicsContext,
        spot: CompactSpot,
        sim: FairiesSim,
        highlighted: Bool,
        hovered: Bool
    ) {
        let t = sim.time
        let occupant = sim.spotOccupants[spot]
        let hideOccupant = occupant != nil && sim.draggingCompactFairy == occupant && sim.compactDragOriginSpot == spot
        let activeFairy = hideOccupant ? nil : occupant
        let reactLeft = max(0, (sim.compactSpotReactUntil[spot] ?? -10) - t)
        let react = reactLeft > 0 ? CGFloat(sin(min(1, reactLeft / 0.65) * .pi)) : 0

        // Soft placement halo when dragging or selecting a fairy to place
        if highlighted || hovered {
            let r: CGFloat = hovered ? 86 : 76
            g.fill(
                Path(ellipseIn: CGRect(x: spot.center.x - r, y: spot.center.y - r * 0.82, width: r * 2, height: r * 1.64)),
                with: .radialGradient(
                    Gradient(colors: [
                        StorybookArt.color(hovered ? 0xFFE38A : 0xFFB8DC, alpha: hovered ? 0.55 : 0.3),
                        StorybookArt.color(hovered ? 0xFFE38A : 0xFFB8DC, alpha: 0),
                    ]),
                    center: spot.center,
                    startRadius: 12,
                    endRadius: r
                )
            )
            if hovered {
                let ring = Path(ellipseIn: CGRect(x: spot.center.x - 78, y: spot.center.y - 64, width: 156, height: 128))
                g.stroke(ring, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 4, dash: [9, 7]))
            }
        }

        switch spot {
        case .cloudBed:
            drawCloudBedSpot(g, center: spot.center, fairy: activeFairy, sim: sim, time: t, react: react)
        case .rainbowSwing:
            drawRainbowSwingSpot(g, center: spot.center, fairy: activeFairy, sim: sim, time: t, react: react)
        case .teacupBath:
            drawTeacupBathSpot(g, center: spot.center, fairy: activeFairy, sim: sim, time: t, react: react)
        case .danceStage:
            drawDanceStageSpot(g, center: spot.center, fairy: activeFairy, sim: sim, time: t, react: react)
        case .treatTable:
            drawTreatTableSpot(g, center: spot.center, fairy: activeFairy, sim: sim, time: t, react: react)
        }
    }

    private static func drawSelectionHaloIfNeeded(_ g: GraphicsContext, at point: CGPoint, fairy: FairyKind, sim: FairiesSim, time t: Double) {
        if sim.selectedFairy == fairy {
            let r: CGFloat = 52 + CGFloat(sin(t * 4.5)) * 3
            let ring = Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
            g.stroke(ring, with: .color(Theme.lemon.opacity(0.9)), style: StrokeStyle(lineWidth: 3.5, dash: [7, 6]))
        }
        if sim.pinnedFairy == fairy {
            drawMiniPinStar(g, at: CGPoint(x: point.x + 36, y: point.y - 42), radius: 13)
        }
    }

    private static func drawCloudBedSpot(
        _ g: GraphicsContext,
        center: CGPoint,
        fairy: FairyKind?,
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        let bounce = CGFloat(sin(t * 2.2)) * 2.5 - react * 7
        // Golden crescent headboard
        let headRect = CGRect(x: center.x - 56, y: center.y - 48, width: 112, height: 68)
        StorybookArt.fillAndStroke(g, Path(roundedRect: headRect, cornerRadius: 34), fill: StorybookArt.color(0xFFE9A8), stroke: StorybookArt.outline(for: 0xE6AD42), width: 3.2)
        StorybookArt.sparkle(g, at: CGPoint(x: center.x, y: center.y - 34), radius: 10, color: .white)

        // Cloud pillows behind fairy
        let cloudOutline = StorybookArt.outline(for: 0xB8DCFF)
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-52, 8, 28), (-22, -4, 30), (22, -4, 30), (52, 8, 28), (0, 14, 34),
        ]
        for (dx, dy, r) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)), with: .color(cloudOutline), lineWidth: 6)
        }
        for (dx, dy, r) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)), with: .color(StorybookArt.color(0xF7FCFF)))
        }

        if let fairy {
            let pos = CGPoint(x: center.x, y: center.y - 16 + bounce)
            drawSelectionHaloIfNeeded(g, at: pos, fairy: fairy, sim: sim, time: t)
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            drawFairy(fc, kind: fairy, mood: react > 0.2 ? .giggle : .sleepy, accessory: sim.accessories[fairy], time: t, scale: 0.94, blinkSeed: 0.7)
        }

        // Cozy scalloped pastel quilt tucked over front
        let quilt = Path(roundedRect: CGRect(x: center.x - 62, y: center.y + 4 + bounce * 0.4, width: 124, height: 40), cornerRadius: 20)
        StorybookArt.fillAndStroke(g, quilt, fill: StorybookArt.color(0xDEC8FF), stroke: StorybookArt.outline(for: 0xB898F0), width: 3.2)
        let fold = Path(roundedRect: CGRect(x: center.x - 60, y: center.y + 2 + bounce * 0.4, width: 120, height: 14), cornerRadius: 7)
        StorybookArt.fillAndStroke(g, fold, fill: StorybookArt.color(0xFFE2F0), stroke: StorybookArt.outline(for: 0xE6A4C8), width: 2.2)
        StorybookArt.sparkle(g, at: CGPoint(x: center.x - 28, y: center.y + 26 + bounce * 0.4), radius: 7, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: center.x + 28, y: center.y + 26 + bounce * 0.4), radius: 7, color: Theme.lemon)
    }

    private static func drawRainbowSwingSpot(
        _ g: GraphicsContext,
        center: CGPoint,
        fairy: FairyKind?,
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        // Pastel rainbow arch frame
        let archCenter = CGPoint(x: center.x, y: center.y + 48)
        let archBands: [(CGFloat, UInt32)] = [
            (96, 0xFF9AC8),
            (86, 0xFFE28A),
            (76, 0x9EE8D0),
            (66, 0xA4D4FF),
        ]
        for (r, hex) in archBands {
            var arc = Path()
            arc.addArc(center: archCenter, radius: r, startAngle: .degrees(196), endAngle: .degrees(344), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        }

        let swingAmp: Double = fairy != nil ? (0.22 + Double(react) * 0.24) : 0.05
        let swingAngle = sin(t * 2.6) * swingAmp
        let pivot = CGPoint(x: center.x, y: center.y - 36)

        var sw = g
        sw.translateBy(x: pivot.x, y: pivot.y)
        sw.rotate(by: .radians(swingAngle))

        // Golden ropes
        for rx in [-28.0, 28.0] as [CGFloat] {
            var rope = Path()
            rope.move(to: CGPoint(x: rx * 0.72, y: 0))
            rope.addLine(to: CGPoint(x: rx, y: 66))
            sw.stroke(rope, with: .color(StorybookArt.color(0xE6B046)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }

        if let fairy {
            let fairyLocal = CGPoint(x: 0, y: 42)
            drawSelectionHaloIfNeeded(sw, at: fairyLocal, fairy: fairy, sim: sim, time: t)
            var fc = sw
            fc.translateBy(x: fairyLocal.x, y: fairyLocal.y)
            drawFairy(fc, kind: fairy, mood: .giggle, accessory: sim.accessories[fairy], time: t, scale: 0.94, blinkSeed: 2.1)
        }

        // Cushioned blush swing seat
        let seat = Path(roundedRect: CGRect(x: -40, y: 60, width: 80, height: 18), cornerRadius: 9)
        StorybookArt.fillAndStroke(sw, seat, fill: StorybookArt.color(0xFFB5D6), stroke: StorybookArt.outline(for: 0xEB84B4), width: 3)
        drawTinyFlower(sw, at: CGPoint(x: -32, y: 62), radius: 9, petalHex: 0xFFE38A)
        drawTinyFlower(sw, at: CGPoint(x: 32, y: 62), radius: 9, petalHex: 0xFFE38A)
    }

    private static func drawTeacupBathSpot(
        _ g: GraphicsContext,
        center: CGPoint,
        fairy: FairyKind?,
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        let cupOutline = StorybookArt.outline(for: 0x90CCF0)
        // Saucer
        let saucer = Path(ellipseIn: CGRect(x: center.x - 74, y: center.y + 30, width: 148, height: 24))
        StorybookArt.fillAndStroke(g, saucer, fill: StorybookArt.color(0xFFF7FA), stroke: cupOutline, width: 3.2)

        // Back teacup handle
        let handle = Path(ellipseIn: CGRect(x: center.x - 78, y: center.y - 12, width: 34, height: 34))
        g.stroke(handle, with: .color(cupOutline), lineWidth: 10)
        g.stroke(handle, with: .color(StorybookArt.color(0xD8F2FF)), lineWidth: 5)

        // Warm pastel bubbly bath rim
        let rim = Path(ellipseIn: CGRect(x: center.x - 58, y: center.y - 26, width: 116, height: 26))
        StorybookArt.fillAndStroke(g, rim, fill: StorybookArt.color(0xA6E6FF), stroke: cupOutline, width: 3)

        // Fairy sitting in the bubbly bath
        if let fairy {
            let bob = CGFloat(sin(t * 3.4)) * 3 - react * 10
            let pos = CGPoint(x: center.x, y: center.y - 24 + bob)
            drawSelectionHaloIfNeeded(g, at: pos, fairy: fairy, sim: sim, time: t)
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            drawFairy(fc, kind: fairy, mood: react > 0.2 ? .giggle : .happy, accessory: sim.accessories[fairy], time: t, scale: 0.94, blinkSeed: 3.4)
        }

        // Front porcelain teacup wall
        var cup = Path()
        cup.move(to: CGPoint(x: center.x - 58, y: center.y - 12))
        cup.addCurve(to: CGPoint(x: center.x - 38, y: center.y + 38), control1: CGPoint(x: center.x - 56, y: center.y + 18), control2: CGPoint(x: center.x - 48, y: center.y + 34))
        cup.addLine(to: CGPoint(x: center.x + 38, y: center.y + 38))
        cup.addCurve(to: CGPoint(x: center.x + 58, y: center.y - 12), control1: CGPoint(x: center.x + 48, y: center.y + 34), control2: CGPoint(x: center.x + 56, y: center.y + 18))
        cup.closeSubpath()
        g.fill(
            cup,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xE8F8FF), StorybookArt.color(0xBCE8FF)]),
                startPoint: CGPoint(x: center.x - 30, y: center.y - 12),
                endPoint: CGPoint(x: center.x + 30, y: center.y + 38)
            )
        )
        g.stroke(cup, with: .color(cupOutline), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
        StorybookArt.heart(g, at: CGPoint(x: center.x, y: center.y + 14), size: 22, color: Theme.pink)

        // Fluffy foam puffs overflowing rim
        let foam: [(CGFloat, CGFloat, CGFloat)] = [
            (-42, -12, 16), (-22, -16, 17), (0, -14, 18), (22, -16, 17), (42, -12, 15),
        ]
        for (dx, dy, r) in foam {
            let fy = center.y + dy + CGFloat(sin(t * 4 + Double(dx))) * 2 - react * 4
            let p = Path(ellipseIn: CGRect(x: center.x + dx - r, y: fy - r, width: r * 2, height: r * 2))
            StorybookArt.fillAndStroke(g, p, fill: .white, stroke: StorybookArt.color(0xBEE8FF), width: 2.2)
        }
    }

    private static func drawDanceStageSpot(
        _ g: GraphicsContext,
        center: CGPoint,
        fairy: FairyKind?,
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        // Rainbow spotlight beams when occupied
        if fairy != nil {
            let beamColors: [(CGFloat, UInt32)] = [(-44, 0xFFB0D8), (0, 0xFFF099), (44, 0xA6E6FF)]
            for (offset, hex) in beamColors {
                var beam = Path()
                beam.move(to: CGPoint(x: center.x + offset * 0.4, y: center.y - 148))
                beam.addLine(to: CGPoint(x: center.x + offset - 32, y: center.y + 32))
                beam.addLine(to: CGPoint(x: center.x + offset + 32, y: center.y + 32))
                beam.closeSubpath()
                g.fill(beam, with: .color(StorybookArt.color(hex, alpha: 0.22 + Double(react) * 0.14)))
            }
        }

        // Gilded starry pedestal stage
        let goldOutline = StorybookArt.outline(for: 0xE6A93B)
        let base = Path(roundedRect: CGRect(x: center.x - 74, y: center.y + 18, width: 148, height: 30), cornerRadius: 15)
        StorybookArt.fillAndStroke(g, base, fill: StorybookArt.color(0xFFE48E), stroke: goldOutline, width: 3.4)

        let top = Path(ellipseIn: CGRect(x: center.x - 74, y: center.y + 4, width: 148, height: 28))
        StorybookArt.fillAndStroke(g, top, fill: StorybookArt.color(0xFFF6D6), stroke: goldOutline, width: 3.2)

        let innerStar = Path(ellipseIn: CGRect(x: center.x - 46, y: center.y + 10, width: 92, height: 16))
        g.fill(innerStar, with: .color(StorybookArt.color(0xFFB8DC, alpha: 0.5)))

        for sx in [-44.0, 0.0, 44.0] as [CGFloat] {
            StorybookArt.sparkle(g, at: CGPoint(x: center.x + sx, y: center.y + 36), radius: 7, color: .white)
        }

        if let fairy {
            let hop = abs(CGFloat(sin(t * 4.4))) * 12 + react * 18
            let twirlTilt = sin(t * 4.4) * 0.14
            let pos = CGPoint(x: center.x, y: center.y - 34 - hop)
            drawSelectionHaloIfNeeded(g, at: pos, fairy: fairy, sim: sim, time: t)
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            fc.rotate(by: .radians(twirlTilt))
            drawFairy(fc, kind: fairy, mood: .celebrate, accessory: sim.accessories[fairy], time: t, scale: 1.06, blinkSeed: 4.2)
        }
    }

    private static func drawTreatTableSpot(
        _ g: GraphicsContext,
        center: CGPoint,
        fairy: FairyKind?,
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        if let fairy {
            let nibbleBob = CGFloat(sin(t * 5.2)) * 3.5 - react * 10
            let pos = CGPoint(x: center.x, y: center.y - 34 + nibbleBob)
            drawSelectionHaloIfNeeded(g, at: pos, fairy: fairy, sim: sim, time: t)
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            drawFairy(fc, kind: fairy, mood: react > 0.2 ? .giggle : .yum, accessory: sim.accessories[fairy], time: t, scale: 0.94, blinkSeed: 5.1)
        }

        let tableOutline = StorybookArt.outline(for: 0xF0ACC6)
        // Table pedestal leg
        let leg = Path(roundedRect: CGRect(x: center.x - 16, y: center.y + 18, width: 32, height: 34), cornerRadius: 10)
        StorybookArt.fillAndStroke(g, leg, fill: StorybookArt.color(0xFFEAF2), stroke: tableOutline, width: 3)

        // Round scalloped lace tablecloth top
        let cloth = Path(ellipseIn: CGRect(x: center.x - 72, y: center.y - 4, width: 144, height: 38))
        StorybookArt.fillAndStroke(g, cloth, fill: StorybookArt.color(0xFFF9FC), stroke: tableOutline, width: 3.4)

        // Pastel macaron stack on the left side of the table
        let macColors: [UInt32] = [0xFF9AC6, 0x9FE3CF, 0xFFE38A]
        for (i, hex) in macColors.enumerated() {
            let my = center.y + 8 - CGFloat(i) * 11
            let mx = center.x - 30
            let mac = Path(roundedRect: CGRect(x: mx - 16, y: my - 6, width: 32, height: 11), cornerRadius: 5.5)
            StorybookArt.fillAndStroke(g, mac, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.2)
            g.fill(Path(CGRect(x: mx - 14, y: my - 1, width: 28, height: 2.6)), with: .color(.white.opacity(0.9)))
        }

        // Porcelain dessert plate + golden Korean bungeoppang on the right side
        let plate = Path(ellipseIn: CGRect(x: center.x - 2, y: center.y + 4, width: 58, height: 20))
        StorybookArt.fillAndStroke(g, plate, fill: .white, stroke: StorybookArt.color(0xB8DCFF), width: 2.4)
        drawBungeoppang(g, at: CGPoint(x: center.x + 26, y: center.y + 8), scale: 1.0)

        if sim.hasHanbokTea {
            drawHanbokTeaSet(g, center: center, time: t)
        }
    }

    private static func drawBungeoppang(_ g: GraphicsContext, at center: CGPoint, scale: CGFloat) {
        var c = g
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: scale, y: scale)

        let pastry = StorybookArt.color(0xF5BE5C)
        let crust = StorybookArt.outline(for: 0xD68C2E)

        // Fish waffle tail fin
        var tail = Path()
        tail.move(to: CGPoint(x: 11, y: 0))
        tail.addLine(to: CGPoint(x: 24, y: -9))
        tail.addQuadCurve(to: CGPoint(x: 24, y: 9), control: CGPoint(x: 19, y: 0))
        tail.closeSubpath()
        StorybookArt.fillAndStroke(c, tail, fill: pastry, stroke: crust, width: 2.2)

        // Plump golden fish body
        let body = Path(ellipseIn: CGRect(x: -18, y: -11, width: 32, height: 22))
        StorybookArt.fillAndStroke(c, body, fill: pastry, stroke: crust, width: 2.4)
        StorybookArt.highlight(c, in: CGRect(x: -11, y: -7, width: 12, height: 5), opacity: 0.48)

        // Cute waffle scale marks & eye
        for sx in [-1.0, 5.0] as [CGFloat] {
            var scaleArc = Path()
            scaleArc.addArc(center: CGPoint(x: sx, y: 0), radius: 5, startAngle: .degrees(-65), endAngle: .degrees(65), clockwise: false)
            c.stroke(scaleArc, with: .color(crust.opacity(0.65)), lineWidth: 1.6)
        }
        c.fill(Path(ellipseIn: CGRect(x: -12, y: -3, width: 3.6, height: 3.6)), with: .color(crust))
    }

    // MARK: - Compact Room Treasures (Chandelier, Carousel, Celadon Hanbok Tea)

    private static func drawCompactChandelier(_ g: GraphicsContext, anchor: CGPoint, time t: Double) {
        let sway = sin(t * 1.45) * 0.055
        let goldHex: UInt32 = 0xFFD966
        let goldOutline = StorybookArt.outline(for: 0xE6A93B)

        var c = g
        c.translateBy(x: anchor.x, y: anchor.y)
        c.rotate(by: .radians(sway))

        // Warm pastel chandelier light halo
        let pulse = 0.88 + 0.12 * sin(t * 3.1)
        c.fill(
            Path(ellipseIn: CGRect(x: -88, y: 4, width: 176, height: 112)),
            with: .radialGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFF6C4, alpha: 0.52 * pulse),
                    StorybookArt.color(0xFFD6EE, alpha: 0.24 * pulse),
                    StorybookArt.color(0xFFD6EE, alpha: 0),
                ]),
                center: CGPoint(x: 0, y: 52),
                startRadius: 8,
                endRadius: 88
            )
        )

        // Hanging golden chain & bow collar
        var chain = Path()
        chain.move(to: .zero)
        chain.addLine(to: CGPoint(x: 0, y: 36))
        c.stroke(chain, with: .color(goldOutline), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        c.stroke(chain, with: .color(StorybookArt.color(goldHex)), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

        // Delicate curved golden chandelier arms
        for side in [-1.0, 1.0] as [CGFloat] {
            for (reach, drop) in [(50.0, 26.0), (26.0, 32.0)] as [(CGFloat, CGFloat)] {
                var arm = Path()
                arm.move(to: CGPoint(x: 0, y: 24))
                arm.addCurve(
                    to: CGPoint(x: side * reach, y: drop),
                    control1: CGPoint(x: side * reach * 0.35, y: 46),
                    control2: CGPoint(x: side * reach * 0.88, y: 44)
                )
                c.stroke(arm, with: .color(goldOutline), style: StrokeStyle(lineWidth: 5.2, lineCap: .round))
                c.stroke(arm, with: .color(StorybookArt.color(goldHex)), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))

                // Glowing pastel starlight candle orb on each arm tip
                let tip = CGPoint(x: side * reach, y: drop - 6)
                let cup = Path(roundedRect: CGRect(x: tip.x - 6, y: drop - 2, width: 12, height: 6), cornerRadius: 3)
                StorybookArt.fillAndStroke(c, cup, fill: StorybookArt.color(goldHex), stroke: goldOutline, width: 1.6)
                let orb = Path(ellipseIn: CGRect(x: tip.x - 5.5, y: tip.y - 7.5, width: 11, height: 13))
                c.fill(
                    orb,
                    with: .radialGradient(
                        Gradient(colors: [.white, StorybookArt.color(0xFFE884)]),
                        center: CGPoint(x: tip.x, y: tip.y - 2),
                        startRadius: 1,
                        endRadius: 8
                    )
                )
                c.stroke(orb, with: .color(StorybookArt.color(0xF0B848, alpha: 0.7)), lineWidth: 1.4)

                // Dangling pastel crystal teardrops underneath each arm
                let dropY = drop + 18
                var thread = Path()
                thread.move(to: CGPoint(x: tip.x, y: drop + 4))
                thread.addLine(to: CGPoint(x: tip.x, y: dropY - 5))
                c.stroke(thread, with: .color(goldOutline.opacity(0.65)), lineWidth: 1.4)

                var tear = Path()
                tear.move(to: CGPoint(x: tip.x, y: dropY - 6))
                tear.addQuadCurve(to: CGPoint(x: tip.x - 5, y: dropY + 4), control: CGPoint(x: tip.x - 6, y: dropY))
                tear.addQuadCurve(to: CGPoint(x: tip.x, y: dropY + 9), control: CGPoint(x: tip.x - 4, y: dropY + 8))
                tear.addQuadCurve(to: CGPoint(x: tip.x + 5, y: dropY + 4), control: CGPoint(x: tip.x + 4, y: dropY + 8))
                tear.addQuadCurve(to: CGPoint(x: tip.x, y: dropY - 6), control: CGPoint(x: tip.x + 6, y: dropY))
                tear.closeSubpath()
                let tearHex: UInt32 = reach > 40 ? 0xD8C6FF : 0xB8ECFF
                StorybookArt.fillAndStroke(c, tear, fill: StorybookArt.color(tearHex), stroke: StorybookArt.outline(for: tearHex), width: 1.6)
            }
        }

        // Center faceted pink heart crystal drop
        let heartCenter = CGPoint(x: 0, y: 50)
        let bezel = heartPath(center: heartCenter, size: 30)
        StorybookArt.fillAndStroke(c, bezel, fill: StorybookArt.color(goldHex), stroke: goldOutline, width: 2.2)
        let gem = heartPath(center: heartCenter, size: 22)
        StorybookArt.fillAndStroke(c, gem, fill: StorybookArt.color(0xFF88BE), stroke: StorybookArt.outline(for: 0xE65C98), width: 1.8)
        StorybookArt.highlight(c, in: CGRect(x: -6, y: 42, width: 6, height: 4), opacity: 0.88)

        StorybookArt.sparkle(c, at: CGPoint(x: -36, y: 12), radius: 6.5 * CGFloat(pulse), color: .white, opacity: 0.92)
        StorybookArt.sparkle(c, at: CGPoint(x: 38, y: 16), radius: 6.0 * CGFloat(pulse), color: Theme.lemon, opacity: 0.92)
    }

    private static func drawCompactCarousel(_ g: GraphicsContext, center: CGPoint, time t: Double) {
        let goldHex: UInt32 = 0xFFD966
        let goldOutline = StorybookArt.outline(for: 0xE6A93B)
        let pinkOutline = StorybookArt.outline(for: 0xF08CB8)

        // Ground shadow on dollhouse floor
        g.fill(
            Path(ellipseIn: CGRect(x: center.x - 42, y: center.y - 4, width: 84, height: 16)),
            with: .color(Theme.ink.opacity(0.12))
        )

        // Pastel pedestal platform
        let baseSide = Path(roundedRect: CGRect(x: center.x - 38, y: center.y - 12, width: 76, height: 14), cornerRadius: 7)
        StorybookArt.fillAndStroke(g, baseSide, fill: StorybookArt.color(0xFFE09E), stroke: goldOutline, width: 2.4)
        let baseTop = Path(ellipseIn: CGRect(x: center.x - 38, y: center.y - 18, width: 76, height: 14))
        StorybookArt.fillAndStroke(g, baseTop, fill: StorybookArt.color(0xFFF6FA), stroke: pinkOutline, width: 2.2)

        // Orbiting cloud & star seats (back half behind pole, front half in front)
        struct Seat {
            let index: Int
            let x: CGFloat
            let depth: CGFloat
            let y: CGFloat
        }
        let spin = t * 1.35
        let seats: [Seat] = (0..<4).map { i in
            let a = spin + Double(i) * (.pi / 2)
            let depth = CGFloat(sin(a))
            let x = center.x + CGFloat(cos(a)) * 27
            let bob = CGFloat(sin(t * 3.2 + Double(i) * 1.57)) * 4.5
            let y = center.y - 31 + depth * 5 + bob
            return Seat(index: i, x: x, depth: depth, y: y)
        }.sorted { $0.depth < $1.depth }

        func drawSeat(_ s: Seat) {
            let scale = 0.82 + (s.depth + 1) * 0.14
            var rod = Path()
            rod.move(to: CGPoint(x: s.x, y: center.y - 60))
            rod.addLine(to: CGPoint(x: s.x, y: center.y - 11 + s.depth * 3))
            g.stroke(rod, with: .color(StorybookArt.color(0xF0C052, alpha: 0.85)), lineWidth: 2.2)

            var sc = g
            sc.translateBy(x: s.x, y: s.y)
            sc.scaleBy(x: scale, y: scale)
            if s.index.isMultiple(of: 2) {
                // Miniature fluffy pastel cloud seat
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: -12, y: -5, width: 12, height: 10))
                cloud.addEllipse(in: CGRect(x: -6, y: -9, width: 13, height: 12))
                cloud.addEllipse(in: CGRect(x: 1, y: -5, width: 11, height: 10))
                StorybookArt.fillAndStroke(sc, cloud, fill: .white, stroke: StorybookArt.outline(for: 0xB8DCFF), width: 1.8)
            } else {
                // Miniature golden-pastel star seat
                var star = Path()
                for k in 0..<10 {
                    let a = -Double.pi / 2 + Double(k) * Double.pi / 5
                    let r: CGFloat = k.isMultiple(of: 2) ? 10 : 5
                    let pt = CGPoint(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
                    if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
                }
                star.closeSubpath()
                let hex: UInt32 = s.index == 1 ? 0xFFE38A : 0xD8C2FF
                StorybookArt.fillAndStroke(sc, star, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 1.8)
            }
        }

        for s in seats where s.depth < 0 { drawSeat(s) }

        // Center golden carousel pole
        let pole = Path(roundedRect: CGRect(x: center.x - 4, y: center.y - 68, width: 8, height: 56), cornerRadius: 4)
        StorybookArt.fillAndStroke(g, pole, fill: StorybookArt.color(goldHex), stroke: goldOutline, width: 2.0)

        for s in seats where s.depth >= 0 { drawSeat(s) }

        // Striped scalloped pastel canopy tent
        let apex = CGPoint(x: center.x, y: center.y - 84)
        let canopyY = center.y - 56
        var tent = Path()
        tent.move(to: CGPoint(x: center.x - 40, y: canopyY))
        tent.addQuadCurve(to: apex, control: CGPoint(x: center.x - 24, y: center.y - 76))
        tent.addQuadCurve(to: CGPoint(x: center.x + 40, y: canopyY), control: CGPoint(x: center.x + 24, y: center.y - 76))
        tent.closeSubpath()
        StorybookArt.fillAndStroke(g, tent, fill: StorybookArt.color(0xFFB5D8), stroke: pinkOutline, width: 2.6)

        // Cream stripes on canopy
        var stripe = Path()
        stripe.move(to: apex)
        stripe.addLine(to: CGPoint(x: center.x - 15, y: canopyY))
        stripe.addLine(to: CGPoint(x: center.x + 15, y: canopyY))
        stripe.closeSubpath()
        g.fill(stripe, with: .color(StorybookArt.color(0xFFFDF5, alpha: 0.92)))

        // Scalloped gold & pink canopy valance
        for k in 0..<5 {
            let sx = center.x - 32 + CGFloat(k) * 16
            let scallop = Path(ellipseIn: CGRect(x: sx - 9, y: canopyY - 6, width: 18, height: 12))
            let hex: UInt32 = k.isMultiple(of: 2) ? 0xFFE38A : 0xFFA6D2
            StorybookArt.fillAndStroke(g, scallop, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 1.8)
        }

        // Golden star finial perched atop the carousel
        StorybookArt.sparkle(g, at: CGPoint(x: apex.x, y: apex.y - 7), radius: 10 + CGFloat(sin(t * 4)) * 1.5, color: Theme.lemon, opacity: 0.98)
        StorybookArt.sparkle(g, at: CGPoint(x: apex.x, y: apex.y - 7), radius: 4.5, color: .white, opacity: 0.95)
    }

    private static func drawHanbokTeaSet(_ g: GraphicsContext, center: CGPoint, time t: Double) {
        let jadeHex: UInt32 = 0x90DCC4
        let jadeLight: UInt32 = 0xC8F4E6
        let jadeOutline = StorybookArt.outline(for: 0x52B096)

        // Celadon Korean teapot nestled at the top-center of the table
        let potC = CGPoint(x: center.x - 3, y: center.y - 1)
        // Soft rising steam wisps
        for k in 0..<2 {
            let drift = CGFloat(sin(t * 2.4 + Double(k) * 2.2)) * 3.5
            var steam = Path()
            steam.move(to: CGPoint(x: potC.x - 16 + CGFloat(k) * 4, y: potC.y - 12))
            steam.addQuadCurve(
                to: CGPoint(x: potC.x - 18 + drift, y: potC.y - 28),
                control: CGPoint(x: potC.x - 22 - drift, y: potC.y - 20)
            )
            g.stroke(steam, with: .color(.white.opacity(0.68)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }

        // Graceful curved spout (left) and arched handle (right)
        var spout = Path()
        spout.move(to: CGPoint(x: potC.x - 10, y: potC.y + 1))
        spout.addQuadCurve(to: CGPoint(x: potC.x - 21, y: potC.y - 9), control: CGPoint(x: potC.x - 20, y: potC.y + 1))
        g.stroke(spout, with: .color(jadeOutline), style: StrokeStyle(lineWidth: 7.2, lineCap: .round))
        g.stroke(spout, with: .color(StorybookArt.color(jadeHex)), style: StrokeStyle(lineWidth: 4.0, lineCap: .round))

        let handle = Path(ellipseIn: CGRect(x: potC.x + 8, y: potC.y - 10, width: 14, height: 16))
        g.stroke(handle, with: .color(jadeOutline), lineWidth: 5.5)
        g.stroke(handle, with: .color(StorybookArt.color(jadeHex)), lineWidth: 2.8)

        // Rounded celadon teapot body
        let potBody = Path(ellipseIn: CGRect(x: potC.x - 14, y: potC.y - 11, width: 28, height: 22))
        g.fill(
            potBody,
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(jadeLight), StorybookArt.color(jadeHex)]),
                center: CGPoint(x: potC.x - 4, y: potC.y - 5),
                startRadius: 2,
                endRadius: 16
            )
        )
        g.stroke(potBody, with: .color(jadeOutline), lineWidth: 2.2)

        // Domed celadon lid & pearl knob
        let lid = Path(ellipseIn: CGRect(x: potC.x - 9, y: potC.y - 15, width: 18, height: 8))
        StorybookArt.fillAndStroke(g, lid, fill: StorybookArt.color(jadeLight), stroke: jadeOutline, width: 1.8)
        let knob = Path(ellipseIn: CGRect(x: potC.x - 3.5, y: potC.y - 19, width: 7, height: 6))
        StorybookArt.fillAndStroke(g, knob, fill: StorybookArt.color(0xFFE68A), stroke: StorybookArt.outline(for: 0xE0A838), width: 1.4)
        // Delicate white plum blossom inlay on teapot belly
        drawTinyFlower(g, at: CGPoint(x: potC.x, y: potC.y + 1), radius: 5.5, petalHex: 0xFFFFFF)

        // Matching miniature celadon teacup on front-left of table
        let cupC = CGPoint(x: center.x - 44, y: center.y + 18)
        let cupSaucer = Path(ellipseIn: CGRect(x: cupC.x - 12, y: cupC.y + 2, width: 24, height: 8))
        StorybookArt.fillAndStroke(g, cupSaucer, fill: StorybookArt.color(jadeLight), stroke: jadeOutline, width: 1.6)
        var cup = Path()
        cup.move(to: CGPoint(x: cupC.x - 8, y: cupC.y - 5))
        cup.addQuadCurve(to: CGPoint(x: cupC.x - 5, y: cupC.y + 5), control: CGPoint(x: cupC.x - 8, y: cupC.y + 4))
        cup.addLine(to: CGPoint(x: cupC.x + 5, y: cupC.y + 5))
        cup.addQuadCurve(to: CGPoint(x: cupC.x + 8, y: cupC.y - 5), control: CGPoint(x: cupC.x + 8, y: cupC.y + 4))
        cup.closeSubpath()
        StorybookArt.fillAndStroke(g, cup, fill: StorybookArt.color(jadeHex), stroke: jadeOutline, width: 1.8)
        let teaTop = Path(ellipseIn: CGRect(x: cupC.x - 7, y: cupC.y - 7, width: 14, height: 4.5))
        g.fill(teaTop, with: .color(StorybookArt.color(0xD8F2A6)))

        // Pastel saucer with Korean flower-pressed rice cakes (hwajeon) at front-center
        let cakeC = CGPoint(x: center.x - 3, y: center.y + 22)
        let cakePlate = Path(ellipseIn: CGRect(x: cakeC.x - 24, y: cakeC.y - 7, width: 48, height: 16))
        StorybookArt.fillAndStroke(g, cakePlate, fill: StorybookArt.color(0xFFFDF8), stroke: jadeOutline, width: 1.8)

        let cakes: [(CGFloat, CGFloat, UInt32, UInt32)] = [
            (-10, -1, 0xFFF2D6, 0xFF8FB8),
            (10, -1, 0xFFD9E8, 0xFFE38A),
            (0, 3, 0xFFF7E4, 0xFFA2C9),
        ]
        for (dx, dy, cakeHex, petalHex) in cakes {
            let p = CGPoint(x: cakeC.x + dx, y: cakeC.y + dy)
            let riceCake = Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 5.5, width: 18, height: 11))
            StorybookArt.fillAndStroke(g, riceCake, fill: StorybookArt.color(cakeHex), stroke: StorybookArt.outline(for: cakeHex), width: 1.5)
            drawTinyFlower(g, at: CGPoint(x: p.x, y: p.y - 0.5), radius: 4.2, petalHex: petalHex)
        }
    }

    // MARK: - 12 Original Chibi Fairies

    static func drawFairy(
        _ g: GraphicsContext,
        kind: FairyKind,
        mood: FairyMood,
        accessory: FairyAccessory?,
        time t: Double,
        scale: CGFloat = 1,
        blinkSeed: Double = 0
    ) {
        var c = g
        c.scaleBy(x: scale, y: scale)

        let p = kind.palette
        let flutterSpeed = mood == .sleepy ? 3.5 : 13.0
        let flutter = sin(t * flutterSpeed + blinkSeed) * (mood == .sleepy ? 0.08 : 0.28)

        // 1. Fluttering iridescent fairy wings behind body
        drawWings(c, palette: p, flutter: flutter)

        // 2. Back hair layer
        drawBackHair(c, kind: kind, palette: p)

        // 3. Cute miniature pastel fairy dress & hands
        drawDressAndArms(c, kind: kind, palette: p, mood: mood, time: t)

        // 4. Expressive chibi head & face
        drawHeadAndFace(c, kind: kind, palette: p, mood: mood, time: t, blinkSeed: blinkSeed)

        // 5. Distinct theme head emblem for each of the 12 fairies
        drawFairyEmblem(c, kind: kind, palette: p)

        // 6. Optional Compact dress-up accessory
        if let accessory {
            drawAccessoryOnFairy(c, accessory: accessory)
        }
    }

    private static func drawWings(_ g: GraphicsContext, palette p: FairyPalette, flutter: Double) {
        let wingOutline = StorybookArt.outline(for: p.wing, factor: 0.72)
        for side in [-1.0, 1.0] as [CGFloat] {
            var w = g
            w.translateBy(x: side * 8, y: 6)
            w.rotate(by: .radians(Double(side) * (0.12 + flutter)))

            // Upper wing petal
            var upper = Path()
            upper.move(to: .zero)
            upper.addCurve(
                to: CGPoint(x: side * 40, y: -20),
                control1: CGPoint(x: side * 20, y: -26),
                control2: CGPoint(x: side * 42, y: -32)
            )
            upper.addCurve(
                to: CGPoint(x: side * 4, y: 8),
                control1: CGPoint(x: side * 38, y: -2),
                control2: CGPoint(x: side * 22, y: 12)
            )
            upper.closeSubpath()

            w.fill(
                upper,
                with: .linearGradient(
                    Gradient(colors: [StorybookArt.color(p.wingInner, alpha: 0.92), StorybookArt.color(p.wing, alpha: 0.85)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: side * 38, y: -18)
                )
            )
            w.stroke(upper, with: .color(wingOutline), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

            // Lower wing droplet
            var lower = Path()
            lower.move(to: CGPoint(x: side * 4, y: 8))
            lower.addCurve(
                to: CGPoint(x: side * 26, y: 24),
                control1: CGPoint(x: side * 24, y: 8),
                control2: CGPoint(x: side * 34, y: 18)
            )
            lower.addCurve(
                to: CGPoint(x: side * 2, y: 16),
                control1: CGPoint(x: side * 18, y: 28),
                control2: CGPoint(x: side * 8, y: 24)
            )
            lower.closeSubpath()
            w.fill(lower, with: .color(StorybookArt.color(p.wing, alpha: 0.8)))
            w.stroke(lower, with: .color(wingOutline), lineWidth: 2)
        }
    }

    private static func drawBackHair(_ g: GraphicsContext, kind: FairyKind, palette p: FairyPalette) {
        let fill = StorybookArt.color(p.hair)
        let shade = StorybookArt.color(p.hairShade)
        let outline = StorybookArt.outline(for: p.hairShade, factor: 0.68)

        switch kind.hairStyle {
        case .twinPuffs:
            for side in [-1.0, 1.0] as [CGFloat] {
                let puff = Path(ellipseIn: CGRect(x: side * 26 - 14, y: -32, width: 28, height: 28))
                StorybookArt.fillAndStroke(g, puff, fill: fill, stroke: outline, width: 2.6)
                StorybookArt.highlight(g, in: CGRect(x: side * 26 - 7, y: -27, width: 10, height: 6), opacity: 0.45)
            }
        case .twinTails:
            for side in [-1.0, 1.0] as [CGFloat] {
                var tail = Path()
                tail.move(to: CGPoint(x: side * 20, y: -20))
                tail.addCurve(
                    to: CGPoint(x: side * 34, y: 18),
                    control1: CGPoint(x: side * 38, y: -14),
                    control2: CGPoint(x: side * 42, y: 6)
                )
                tail.addCurve(
                    to: CGPoint(x: side * 16, y: 4),
                    control1: CGPoint(x: side * 26, y: 22),
                    control2: CGPoint(x: side * 18, y: 14)
                )
                tail.closeSubpath()
                StorybookArt.fillAndStroke(g, tail, fill: fill, stroke: outline, width: 2.6)
            }
        case .curls:
            for (dx, dy, r) in [(-24.0, -4.0, 14.0), (24.0, -4.0, 14.0), (-20.0, 10.0, 13.0), (20.0, 10.0, 13.0), (0.0, 8.0, 16.0)] as [(CGFloat, CGFloat, CGFloat)] {
                let curl = Path(ellipseIn: CGRect(x: dx - r, y: dy - r, width: r * 2, height: r * 2))
                StorybookArt.fillAndStroke(g, curl, fill: fill, stroke: outline, width: 2.4)
            }
        case .bob:
            let bob = Path(roundedRect: CGRect(x: -29, y: -24, width: 58, height: 42), cornerRadius: 20)
            StorybookArt.fillAndStroke(g, bob, fill: fill, stroke: outline, width: 2.6)
        case .braidCrown:
            // Silky hanbok updo bun + trailing pastel daenggi ribbons
            let bun = Path(ellipseIn: CGRect(x: -28, y: -24, width: 56, height: 38))
            StorybookArt.fillAndStroke(g, bun, fill: shade, stroke: outline, width: 2.6)
            for side in [-1.0, 1.0] as [CGFloat] {
                var ribbon = Path()
                ribbon.move(to: CGPoint(x: side * 12, y: -10))
                ribbon.addQuadCurve(to: CGPoint(x: side * 24, y: 26), control: CGPoint(x: side * 26, y: 8))
                ribbon.addLine(to: CGPoint(x: side * 17, y: 28))
                ribbon.addQuadCurve(to: CGPoint(x: side * 8, y: -4), control: CGPoint(x: side * 18, y: 10))
                ribbon.closeSubpath()
                StorybookArt.fillAndStroke(g, ribbon, fill: StorybookArt.color(0xFF7B9E), stroke: StorybookArt.outline(for: 0xDF527A), width: 2)
            }
        }
    }

    private static func drawDressAndArms(_ g: GraphicsContext, kind: FairyKind, palette p: FairyPalette, mood: FairyMood, time t: Double) {
        let skin = StorybookArt.color(p.skin)
        let skinOutline = StorybookArt.outline(for: 0xE6B098)
        let dressFill = StorybookArt.color(p.dress)
        let dressOutline = StorybookArt.outline(for: p.dressAccent, factor: 0.7)

        // Tiny shoes peeking underneath
        for sx in [-8.0, 8.0] as [CGFloat] {
            let shoe = Path(ellipseIn: CGRect(x: sx - 5.5, y: 31, width: 11, height: 8))
            StorybookArt.fillAndStroke(g, shoe, fill: StorybookArt.color(p.dressAccent), stroke: dressOutline, width: 2)
        }

        // Cute arms
        let armLift: CGFloat = (mood == .celebrate || mood == .giggle) ? -10 - CGFloat(sin(t * 10)) * 3 : (mood == .yum ? -5 : 4)
        for side in [-1.0, 1.0] as [CGFloat] {
            var arm = Path()
            arm.move(to: CGPoint(x: side * 11, y: 12))
            arm.addQuadCurve(to: CGPoint(x: side * 21, y: 16 + armLift), control: CGPoint(x: side * 18, y: 10 + armLift * 0.5))
            g.stroke(arm, with: .color(skinOutline), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
            g.stroke(arm, with: .color(skin), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }

        if kind == .silk {
            // Voluminous pastel blush-peach hanbok chima skirt
            var chima = Path()
            chima.move(to: CGPoint(x: -11, y: 12))
            chima.addCurve(to: CGPoint(x: -24, y: 34), control1: CGPoint(x: -22, y: 16), control2: CGPoint(x: -26, y: 28))
            chima.addQuadCurve(to: CGPoint(x: 24, y: 34), control: CGPoint(x: 0, y: 40))
            chima.addCurve(to: CGPoint(x: 11, y: 12), control1: CGPoint(x: 26, y: 28), control2: CGPoint(x: 22, y: 16))
            chima.closeSubpath()
            StorybookArt.fillAndStroke(g, chima, fill: dressFill, stroke: StorybookArt.outline(for: 0xEB8DA0), width: 2.6)

            // Celadon-mint jeogori jacket + white dongjeong collar + goreum tie
            let jeogori = Path(roundedRect: CGRect(x: -13, y: 6, width: 26, height: 12), cornerRadius: 6)
            StorybookArt.fillAndStroke(g, jeogori, fill: StorybookArt.color(p.dressAccent), stroke: StorybookArt.outline(for: 0x6EC7A6), width: 2.2)
            var collar = Path()
            collar.move(to: CGPoint(x: -6, y: 7))
            collar.addLine(to: CGPoint(x: 0, y: 13))
            collar.addLine(to: CGPoint(x: 6, y: 7))
            g.stroke(collar, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            var tie = Path()
            tie.move(to: CGPoint(x: 2, y: 13))
            tie.addLine(to: CGPoint(x: 7, y: 24))
            g.stroke(tie, with: .color(StorybookArt.color(0xFF7B9E)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            return
        }

        // Flared scalloped pastel fairy dress
        var skirt = Path()
        skirt.move(to: CGPoint(x: -10, y: 8))
        skirt.addCurve(to: CGPoint(x: -23, y: 33), control1: CGPoint(x: -18, y: 15), control2: CGPoint(x: -24, y: 26))
        skirt.addQuadCurve(to: CGPoint(x: 0, y: 36), control: CGPoint(x: -12, y: 39))
        skirt.addQuadCurve(to: CGPoint(x: 23, y: 33), control: CGPoint(x: 12, y: 39))
        skirt.addCurve(to: CGPoint(x: 10, y: 8), control1: CGPoint(x: 24, y: 26), control2: CGPoint(x: 18, y: 15))
        skirt.closeSubpath()
        StorybookArt.fillAndStroke(g, skirt, fill: dressFill, stroke: dressOutline, width: 2.6)

        if kind == .honey {
            // Cute golden bee stripe across skirt
            g.fill(Path(CGRect(x: -17, y: 21, width: 34, height: 5)), with: .color(StorybookArt.color(p.dressAccent, alpha: 0.78)))
        }

        // Ruffled collar & chest gem
        let collar = Path(ellipseIn: CGRect(x: -12, y: 6, width: 24, height: 9))
        StorybookArt.fillAndStroke(g, collar, fill: .white, stroke: dressOutline, width: 2)
        let gem = Path(ellipseIn: CGRect(x: -4.5, y: 10, width: 9, height: 9))
        StorybookArt.fillAndStroke(g, gem, fill: StorybookArt.color(p.emblem), stroke: .white, width: 1.8)
    }

    private static func drawHeadAndFace(
        _ g: GraphicsContext,
        kind: FairyKind,
        palette p: FairyPalette,
        mood: FairyMood,
        time t: Double,
        blinkSeed: Double
    ) {
        let headRect = CGRect(x: -24, y: -33, width: 48, height: 42)
        let skinOutline = StorybookArt.outline(for: 0xE6B098)
        StorybookArt.fillAndStroke(g, Path(ellipseIn: headRect), fill: StorybookArt.color(p.skin), stroke: skinOutline, width: 2.6)

        // Sculpted front hair crown & bangs
        let hairFill = StorybookArt.color(p.hair)
        let hairOutline = StorybookArt.outline(for: p.hairShade, factor: 0.68)
        var bangs = Path()
        bangs.move(to: CGPoint(x: -25, y: -12))
        bangs.addCurve(to: CGPoint(x: 0, y: -37), control1: CGPoint(x: -27, y: -30), control2: CGPoint(x: -14, y: -38))
        bangs.addCurve(to: CGPoint(x: 25, y: -12), control1: CGPoint(x: 14, y: -38), control2: CGPoint(x: 27, y: -30))
        bangs.addQuadCurve(to: CGPoint(x: 12, y: -19), control: CGPoint(x: 19, y: -15))
        bangs.addQuadCurve(to: CGPoint(x: 0, y: -15), control: CGPoint(x: 6, y: -22))
        bangs.addQuadCurve(to: CGPoint(x: -12, y: -19), control: CGPoint(x: -6, y: -22))
        bangs.addQuadCurve(to: CGPoint(x: -25, y: -12), control: CGPoint(x: -19, y: -15))
        bangs.closeSubpath()
        StorybookArt.fillAndStroke(g, bangs, fill: hairFill, stroke: hairOutline, width: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -32, width: 16, height: 6), opacity: 0.52)

        // Rosy cheeks
        for side in [-1.0, 1.0] as [CGFloat] {
            g.fill(
                Path(ellipseIn: CGRect(x: side * 13 - 5.5, y: -7, width: 11, height: 6.5)),
                with: .color(StorybookArt.color(p.cheek, alpha: 0.58))
            )
        }

        // Natural occasional blink
        let blinkCycle = (t + blinkSeed * 1.7).truncatingRemainder(dividingBy: 4.4)
        let isBlinking = blinkCycle < 0.14

        // Expressive chibi eyes
        for side in [-1.0, 1.0] as [CGFloat] {
            let ex = side * 9.5
            let ey: CGFloat = -12
            if mood == .sleepy {
                var lid = Path()
                lid.move(to: CGPoint(x: ex - 5.5, y: ey))
                lid.addQuadCurve(to: CGPoint(x: ex + 5.5, y: ey), control: CGPoint(x: ex, y: ey + 5))
                g.stroke(lid, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            } else if mood == .giggle || isBlinking {
                var arc = Path()
                arc.move(to: CGPoint(x: ex - 5.5, y: ey + 1.5))
                arc.addQuadCurve(to: CGPoint(x: ex + 5.5, y: ey + 1.5), control: CGPoint(x: ex, y: ey - 5.5))
                g.stroke(arc, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            } else {
                // Big sparkling chibi jewel eyes
                let eyeOval = Path(ellipseIn: CGRect(x: ex - 5.4, y: ey - 6.4, width: 10.8, height: 12.8))
                g.fill(
                    eyeOval,
                    with: .linearGradient(
                        Gradient(colors: [StorybookArt.color(p.eye), StorybookArt.tint(for: p.eye, amount: 0.36)]),
                        startPoint: CGPoint(x: ex, y: ey - 6),
                        endPoint: CGPoint(x: ex, y: ey + 6)
                    )
                )
                g.stroke(eyeOval, with: .color(Theme.ink), lineWidth: 1.6)
                g.fill(Path(ellipseIn: CGRect(x: ex - 2.6, y: ey - 5.0, width: 4.4, height: 4.4)), with: .color(.white))
                g.fill(Path(ellipseIn: CGRect(x: ex + 0.8, y: ey + 1.2, width: 2.4, height: 2.4)), with: .color(.white.opacity(0.9)))
                if mood == .celebrate || mood == .yum {
                    StorybookArt.sparkle(g, at: CGPoint(x: ex - 0.5, y: ey + 2), radius: 3.4, color: Theme.lemon)
                }
            }
        }

        // Smiling mouth
        switch mood {
        case .sleepy:
            let sigh = Path(ellipseIn: CGRect(x: -2.4, y: -2.6, width: 4.8, height: 4.2))
            g.fill(sigh, with: .color(StorybookArt.color(0xE87A96)))
        case .giggle, .celebrate:
            var open = Path()
            open.move(to: CGPoint(x: -5.5, y: -3.5))
            open.addQuadCurve(to: CGPoint(x: 5.5, y: -3.5), control: CGPoint(x: 0, y: -2.5))
            open.addQuadCurve(to: CGPoint(x: -5.5, y: -3.5), control: CGPoint(x: 0, y: 5.5))
            open.closeSubpath()
            StorybookArt.fillAndStroke(g, open, fill: StorybookArt.color(0xFF7B9E), stroke: Theme.ink, width: 1.8)
        case .happy, .yum:
            var smile = Path()
            smile.move(to: CGPoint(x: -4.8, y: -3.5))
            smile.addQuadCurve(to: CGPoint(x: 4.8, y: -3.5), control: CGPoint(x: 0, y: 1.8))
            g.stroke(smile, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private static func drawFairyEmblem(_ g: GraphicsContext, kind: FairyKind, palette p: FairyPalette) {
        let top = CGPoint(x: 0, y: -42)
        let fill = StorybookArt.color(p.emblem)
        let accent = StorybookArt.color(p.emblemAccent)
        let outline = StorybookArt.outline(for: p.emblem)

        switch kind {
        case .heart:
            let hp = heartPath(center: top, size: 22)
            StorybookArt.fillAndStroke(g, hp, fill: fill, stroke: outline, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: -5, y: top.y - 5, width: 5, height: 3.5), opacity: 0.78)
        case .star:
            let sp = fiveStarPath(center: top, outer: 13, inner: 6)
            StorybookArt.fillAndStroke(g, sp, fill: fill, stroke: outline, width: 2.2)
        case .berry:
            let berry = heartPath(center: CGPoint(x: 0, y: top.y + 3), size: 20)
            StorybookArt.fillAndStroke(g, berry, fill: fill, stroke: outline, width: 2.2)
            var cap = Path()
            cap.move(to: CGPoint(x: -8, y: top.y - 4))
            cap.addLine(to: CGPoint(x: 0, y: top.y - 10))
            cap.addLine(to: CGPoint(x: 8, y: top.y - 4))
            cap.addLine(to: CGPoint(x: 0, y: top.y - 1))
            cap.closeSubpath()
            g.fill(cap, with: .color(accent))
        case .cloud:
            let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-8, 2, 7.5), (0, -3, 9), (8, 2, 7.5)]
            for (dx, dy, r) in puffs {
                g.stroke(Path(ellipseIn: CGRect(x: top.x + dx - r, y: top.y + dy - r, width: r * 2, height: r * 2)), with: .color(StorybookArt.outline(for: 0x9FD8FF)), lineWidth: 4.5)
            }
            for (dx, dy, r) in puffs {
                g.fill(Path(ellipseIn: CGRect(x: top.x + dx - r, y: top.y + dy - r, width: r * 2, height: r * 2)), with: .color(.white))
            }
        case .ribbon:
            for side in [-1.0, 1.0] as [CGFloat] {
                let loop = Path(ellipseIn: CGRect(x: side < 0 ? -18 : 2, y: top.y - 8, width: 16, height: 14))
                StorybookArt.fillAndStroke(g, loop, fill: fill, stroke: outline, width: 2.2)
            }
            let knot = Path(ellipseIn: CGRect(x: -5.5, y: top.y - 5.5, width: 11, height: 11))
            StorybookArt.fillAndStroke(g, knot, fill: accent, stroke: outline, width: 2)
        case .moon:
            var crescent = Path(ellipseIn: CGRect(x: -11, y: top.y - 11, width: 22, height: 22))
            crescent.addEllipse(in: CGRect(x: -4, y: top.y - 14, width: 20, height: 20))
            g.fill(crescent, with: .color(fill), style: FillStyle(eoFill: true))
            StorybookArt.sparkle(g, at: CGPoint(x: 8, y: top.y - 4), radius: 5, color: .white)
        case .melody:
            let dot = Path(ellipseIn: CGRect(x: -9, y: top.y - 2, width: 10, height: 8))
            StorybookArt.fillAndStroke(g, dot, fill: fill, stroke: outline, width: 2)
            var stem = Path()
            stem.move(to: CGPoint(x: 0, y: top.y + 1))
            stem.addLine(to: CGPoint(x: 0, y: top.y - 14))
            stem.addQuadCurve(to: CGPoint(x: 11, y: top.y - 8), control: CGPoint(x: 9, y: top.y - 15))
            g.stroke(stem, with: .color(outline), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            g.stroke(stem, with: .color(accent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        case .peach:
            let fruit = heartPath(center: CGPoint(x: 0, y: top.y + 2), size: 21)
            StorybookArt.fillAndStroke(g, fruit, fill: fill, stroke: outline, width: 2.2)
            let leaf = Path(ellipseIn: CGRect(x: 3, y: top.y - 12, width: 10, height: 6))
            StorybookArt.fillAndStroke(g, leaf, fill: accent, stroke: StorybookArt.outline(for: 0x62B876), width: 1.8)
        case .dewdrop:
            var drop = Path()
            drop.move(to: CGPoint(x: 0, y: top.y - 12))
            drop.addCurve(to: CGPoint(x: 0, y: top.y + 10), control1: CGPoint(x: 12, y: top.y - 2), control2: CGPoint(x: 12, y: top.y + 10))
            drop.addCurve(to: CGPoint(x: 0, y: top.y - 12), control1: CGPoint(x: -12, y: top.y + 10), control2: CGPoint(x: -12, y: top.y - 2))
            drop.closeSubpath()
            StorybookArt.fillAndStroke(g, drop, fill: fill, stroke: outline, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: -4, y: top.y - 3, width: 4, height: 6), opacity: 0.78)
        case .honey:
            let cap = Path(roundedRect: CGRect(x: -12, y: top.y - 5, width: 24, height: 11), cornerRadius: 5)
            StorybookArt.fillAndStroke(g, cap, fill: fill, stroke: outline, width: 2.2)
            for side in [-1.0, 1.0] as [CGFloat] {
                var ant = Path()
                ant.move(to: CGPoint(x: side * 5, y: top.y - 5))
                ant.addQuadCurve(to: CGPoint(x: side * 11, y: top.y - 14), control: CGPoint(x: side * 6, y: top.y - 13))
                g.stroke(ant, with: .color(StorybookArt.color(p.emblemAccent)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                g.fill(Path(ellipseIn: CGRect(x: side * 11 - 3.5, y: top.y - 17, width: 7, height: 7)), with: .color(Theme.lemon))
            }
        case .blossom:
            drawTinyFlower(g, at: top, radius: 13, petalHex: p.emblem)
        case .silk:
            // Traditional pastel Korean jokduri headpiece with jewel & pearls
            var jokduri = Path()
            jokduri.move(to: CGPoint(x: -11, y: top.y + 6))
            jokduri.addLine(to: CGPoint(x: -13, y: top.y - 4))
            jokduri.addQuadCurve(to: CGPoint(x: 13, y: top.y - 4), control: CGPoint(x: 0, y: top.y - 12))
            jokduri.addLine(to: CGPoint(x: 11, y: top.y + 6))
            jokduri.closeSubpath()
            StorybookArt.fillAndStroke(g, jokduri, fill: StorybookArt.color(0x5B527A), stroke: StorybookArt.outline(for: 0x3D3559), width: 2.2)
            let jewel = Path(ellipseIn: CGRect(x: -4.5, y: top.y - 4.5, width: 9, height: 9))
            StorybookArt.fillAndStroke(g, jewel, fill: fill, stroke: accent, width: 2)
            for sx in [-8.5, 8.5] as [CGFloat] {
                g.fill(Path(ellipseIn: CGRect(x: sx - 2.5, y: top.y - 2, width: 5, height: 5)), with: .color(.white))
            }
        }
    }

    private static func drawAccessoryOnFairy(_ g: GraphicsContext, accessory: FairyAccessory) {
        var c = g
        switch accessory {
        case .bow:
            c.translateBy(x: 18, y: -32)
            c.rotate(by: .radians(0.28))
            drawBowShape(c, scale: 0.72)
        case .crown:
            c.translateBy(x: 0, y: -44)
            drawCrownShape(c, scale: 0.75)
        case .flower:
            c.translateBy(x: -19, y: -30)
            drawFlowerAccessoryShape(c, scale: 0.75)
        case .starClip:
            c.translateBy(x: 17, y: -27)
            drawStarClipShape(c, scale: 0.7)
        case .daenggiRibbon:
            c.translateBy(x: 20, y: -26)
            drawDaenggiShape(c, scale: 0.75)
        }
    }

    // MARK: - Accessory Shapes (shared by Fairy & Compact Dock Icons)

    static func drawAccessoryIcon(_ g: GraphicsContext, accessory: FairyAccessory) {
        switch accessory {
        case .bow: drawBowShape(g, scale: 1.15)
        case .crown: drawCrownShape(g, scale: 1.15)
        case .flower: drawFlowerAccessoryShape(g, scale: 1.18)
        case .starClip: drawStarClipShape(g, scale: 1.15)
        case .daenggiRibbon: drawDaenggiShape(g, scale: 1.05)
        }
    }

    private static func drawBowShape(_ g: GraphicsContext, scale: CGFloat) {
        var c = g
        c.scaleBy(x: scale, y: scale)
        let outline = StorybookArt.outline(for: 0xFF6FA8)
        for side in [-1.0, 1.0] as [CGFloat] {
            let loop = Path(ellipseIn: CGRect(x: side < 0 ? -18 : 2, y: -9, width: 16, height: 16))
            StorybookArt.fillAndStroke(c, loop, fill: StorybookArt.color(0xFF8EC2), stroke: outline, width: 2.4)
        }
        let knot = Path(ellipseIn: CGRect(x: -5.5, y: -5.5, width: 11, height: 11))
        StorybookArt.fillAndStroke(c, knot, fill: StorybookArt.color(0xFFD2E8), stroke: outline, width: 2.2)
    }

    private static func drawCrownShape(_ g: GraphicsContext, scale: CGFloat) {
        var c = g
        c.scaleBy(x: scale, y: scale)
        var crown = Path()
        crown.move(to: CGPoint(x: -16, y: 10))
        crown.addLine(to: CGPoint(x: -19, y: -7))
        crown.addLine(to: CGPoint(x: -7, y: 1))
        crown.addLine(to: CGPoint(x: 0, y: -13))
        crown.addLine(to: CGPoint(x: 7, y: 1))
        crown.addLine(to: CGPoint(x: 19, y: -7))
        crown.addLine(to: CGPoint(x: 16, y: 10))
        crown.closeSubpath()
        StorybookArt.fillAndStroke(c, crown, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 2.4)
        StorybookArt.heart(c, at: CGPoint(x: 0, y: 4), size: 9, color: Theme.pink)
    }

    private static func drawFlowerAccessoryShape(_ g: GraphicsContext, scale: CGFloat) {
        var c = g
        c.scaleBy(x: scale, y: scale)
        let outline = StorybookArt.outline(for: 0xFF8AB8)
        for k in 0..<5 {
            let a = CGFloat(k) * (2 * .pi / 5) - .pi / 2
            let pt = CGPoint(x: cos(a) * 9, y: sin(a) * 9)
            let p = Path(ellipseIn: CGRect(x: pt.x - 7.5, y: pt.y - 7.5, width: 15, height: 15))
            StorybookArt.fillAndStroke(c, p, fill: StorybookArt.color(0xFFB5D6), stroke: outline, width: 2)
        }
        let center = Path(ellipseIn: CGRect(x: -5.5, y: -5.5, width: 11, height: 11))
        StorybookArt.fillAndStroke(c, center, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 1.8)
    }

    private static func drawStarClipShape(_ g: GraphicsContext, scale: CGFloat) {
        var c = g
        c.scaleBy(x: scale, y: scale)
        let s1 = fiveStarPath(center: CGPoint(x: -6, y: -4), outer: 11, inner: 5)
        let s2 = fiveStarPath(center: CGPoint(x: 9, y: 6), outer: 9, inner: 4.2)
        StorybookArt.fillAndStroke(c, s1, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 2.2)
        StorybookArt.fillAndStroke(c, s2, fill: StorybookArt.color(0xFFB5D6), stroke: StorybookArt.outline(for: 0xE67AA8), width: 2)
    }

    private static func drawDaenggiShape(_ g: GraphicsContext, scale: CGFloat) {
        var c = g
        c.scaleBy(x: scale, y: scale)
        let outline = StorybookArt.outline(for: 0xE0567E)
        var tail = Path()
        tail.move(to: CGPoint(x: -6, y: -12))
        tail.addLine(to: CGPoint(x: 6, y: -12))
        tail.addLine(to: CGPoint(x: 9, y: 15))
        tail.addLine(to: CGPoint(x: 0, y: 10))
        tail.addLine(to: CGPoint(x: -9, y: 15))
        tail.closeSubpath()
        StorybookArt.fillAndStroke(c, tail, fill: StorybookArt.color(0xFF7B9E), stroke: outline, width: 2.2)
        let topPin = Path(ellipseIn: CGRect(x: -7, y: -17, width: 14, height: 11))
        StorybookArt.fillAndStroke(c, topPin, fill: StorybookArt.color(0x9EE3CB), stroke: StorybookArt.outline(for: 0x62B89B), width: 2)
        StorybookArt.sparkle(c, at: CGPoint(x: 0, y: 0), radius: 5, color: Theme.lemon)
    }

    // MARK: - Top Bar & Dock Icons

    static func drawMeadowModeIcon(_ g: GraphicsContext) {
        // Pastel hill + blossom + golden sparkle
        let hill = Path(ellipseIn: CGRect(x: -24, y: 4, width: 48, height: 24))
        StorybookArt.fillAndStroke(g, hill, fill: StorybookArt.color(0x9FE3B8), stroke: StorybookArt.outline(for: 0x76C795), width: 2.2)
        drawTinyFlower(g, at: CGPoint(x: -8, y: 2), radius: 10, petalHex: 0xFF9AC8)
        drawTinyFlower(g, at: CGPoint(x: 11, y: 6), radius: 8, petalHex: 0xFFE38A)
        StorybookArt.sparkle(g, at: CGPoint(x: 10, y: -12), radius: 9, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -11, y: -14), radius: 5.5, color: Theme.pink)
    }

    static func drawCompactModeIcon(_ g: GraphicsContext) {
        let outer = heartPath(center: CGPoint(x: 0, y: 2), size: 38)
        StorybookArt.fillAndStroke(g, outer, fill: StorybookArt.color(0xFFA6D6), stroke: StorybookArt.outline(for: 0xE678B2), width: 2.6)
        let inner = heartPath(center: CGPoint(x: 0, y: 2), size: 24)
        StorybookArt.fillAndStroke(g, inner, fill: StorybookArt.color(0xFFF6FA), stroke: Theme.lemon, width: 2)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: 2), radius: 7, color: Theme.lemon)
    }

    static func drawWandIcon(_ g: GraphicsContext) {
        var c = g
        c.rotate(by: .radians(-0.62))
        var stick = Path()
        stick.move(to: CGPoint(x: 0, y: 22))
        stick.addLine(to: CGPoint(x: 0, y: -6))
        c.stroke(stick, with: .color(StorybookArt.outline(for: 0xFF8FB8)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        c.stroke(stick, with: .color(StorybookArt.color(0xFFD6E9)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        let bezel = heartPath(center: CGPoint(x: 0, y: -11), size: 26)
        StorybookArt.fillAndStroke(c, bezel, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xDF9E2C), width: 2.4)
        let gem = heartPath(center: CGPoint(x: 0, y: -11), size: 17)
        StorybookArt.fillAndStroke(c, gem, fill: StorybookArt.color(0xFF66A8), stroke: StorybookArt.outline(for: 0xD84888), width: 1.8)
        StorybookArt.sparkle(c, at: CGPoint(x: 13, y: -18), radius: 6, color: Theme.lemon)
    }

    /// Drawer tile icon (300 x 300 space): Sparkly pastel heart jewel compact with a cute peeking chibi fairy!
    static func drawTileIcon(_ g: GraphicsContext) {
        // Radiant pastel starburst behind compact
        g.fill(
            Path(ellipseIn: CGRect(x: 34, y: 34, width: 232, height: 232)),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.65), .white.opacity(0)]),
                center: CGPoint(x: 150, y: 150),
                startRadius: 20,
                endRadius: 118
            )
        )

        // Open jewel compact base heart
        let outer = heartPath(center: CGPoint(x: 150, y: 162), size: 220)
        g.fill(
            outer,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFC2E2), StorybookArt.color(0xFF8CC4)]),
                startPoint: CGPoint(x: 150, y: 50),
                endPoint: CGPoint(x: 150, y: 270)
            )
        )
        g.stroke(outer, with: .color(StorybookArt.color(0xFFE07D)), lineWidth: 11)
        g.stroke(outer, with: .color(StorybookArt.outline(for: 0xE6A436)), lineWidth: 4.5)

        let inner = heartPath(center: CGPoint(x: 150, y: 164), size: 170)
        g.fill(
            inner,
            with: .radialGradient(
                Gradient(colors: [.white, StorybookArt.color(0xFFE8F4)]),
                center: CGPoint(x: 150, y: 146),
                startRadius: 10,
                endRadius: 96
            )
        )
        g.stroke(inner, with: .color(StorybookArt.color(0xF5CA5C)), lineWidth: 5)

        // Cute peeking chibi Heart Fairy inside the jewel compact
        var fc = g
        fc.translateBy(x: 150, y: 166)
        drawFairy(fc, kind: .heart, mood: .happy, accessory: .crown, time: 0.3, scale: 1.72, blinkSeed: 0.2)

        // Sparkles & floating hearts around the compact
        StorybookArt.sparkle(g, at: CGPoint(x: 54, y: 74), radius: 16, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 248, y: 68), radius: 18, color: .white)
        StorybookArt.heart(g, at: CGPoint(x: 242, y: 224), size: 26, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 58, y: 222), radius: 12, color: Theme.lemon)
    }

    // MARK: - Shared Particles & Geometry Primitives

    private static func drawParticles(_ g: GraphicsContext, particles: [FairyParticle], time t: Double) {
        for p in particles {
            let life = max(0, min(1, 1 - p.age / p.maxAge))
            let alpha = Double(min(1, life * 1.4))
            switch p.kind {
            case .heart:
                StorybookArt.heart(g, at: p.pos, size: p.size, color: StorybookArt.color(p.colorHex), opacity: alpha)
            case .star:
                StorybookArt.sparkle(g, at: p.pos, radius: p.size * 0.65, color: StorybookArt.color(p.colorHex), opacity: alpha)
            case .bubble:
                drawBubble(g, at: p.pos, radius: p.size * 0.65, alpha: alpha)
            case .petal:
                var c = g
                c.translateBy(x: p.pos.x, y: p.pos.y)
                c.rotate(by: .radians(Double(t * 2 + Double(p.phase))))
                c.fill(
                    Path(ellipseIn: CGRect(x: -p.size * 0.45, y: -p.size * 0.28, width: p.size * 0.9, height: p.size * 0.56)),
                    with: .color(StorybookArt.color(p.colorHex, alpha: alpha))
                )
            case .note:
                let col = StorybookArt.color(p.colorHex, alpha: alpha)
                let head = Path(ellipseIn: CGRect(x: p.pos.x - 5, y: p.pos.y - 3, width: 9, height: 7))
                g.fill(head, with: .color(col))
                var stem = Path()
                stem.move(to: CGPoint(x: p.pos.x + 3.5, y: p.pos.y))
                stem.addLine(to: CGPoint(x: p.pos.x + 3.5, y: p.pos.y - 13))
                stem.addQuadCurve(to: CGPoint(x: p.pos.x + 11, y: p.pos.y - 8), control: CGPoint(x: p.pos.x + 10, y: p.pos.y - 14))
                g.stroke(stem, with: .color(col), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            case .sleepyZ:
                // Drawn as a tiny dreamy crescent & sparkle (zero letters/text for pre-readers!)
                StorybookArt.sparkle(g, at: p.pos, radius: p.size * 0.55, color: StorybookArt.color(p.colorHex), opacity: alpha)
                StorybookArt.sparkle(g, at: CGPoint(x: p.pos.x + 9, y: p.pos.y - 7), radius: p.size * 0.35, color: Theme.lemon, opacity: alpha)
            }
        }
    }

    private static func drawBubble(_ g: GraphicsContext, at center: CGPoint, radius r: CGFloat, alpha: Double) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        g.fill(Path(ellipseIn: rect), with: .color(StorybookArt.color(0xE8F8FF, alpha: 0.45 * alpha)))
        g.stroke(Path(ellipseIn: rect), with: .color(StorybookArt.color(0x9CDFFF, alpha: 0.9 * alpha)), lineWidth: 2.2)
        StorybookArt.highlight(g, in: CGRect(x: center.x - r * 0.52, y: center.y - r * 0.55, width: r * 0.48, height: r * 0.3), opacity: 0.8 * alpha)
    }

    private static func drawMiniPinStar(_ g: GraphicsContext, at center: CGPoint, radius: CGFloat) {
        let bg = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        StorybookArt.fillAndStroke(g, bg, fill: StorybookArt.color(0xFFF3B8), stroke: .white, width: 2.4)
        let star = fiveStarPath(center: center, outer: radius * 0.68, inner: radius * 0.32)
        StorybookArt.fillAndStroke(g, star, fill: StorybookArt.color(0xFFB830), stroke: StorybookArt.outline(for: 0xD88C16), width: 1.6)
    }

    static func heartPath(center: CGPoint, size: CGFloat) -> Path {
        let r = size * 0.5
        let cx = center.x, cy = center.y
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - r * 0.25))
        p.addCurve(
            to: CGPoint(x: cx + r, y: cy - r * 0.15),
            control1: CGPoint(x: cx + r * 0.35, y: cy - r * 1.05),
            control2: CGPoint(x: cx + r * 1.08, y: cy - r * 0.82)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy + r * 0.88),
            control1: CGPoint(x: cx + r * 0.96, y: cy + r * 0.35),
            control2: CGPoint(x: cx + r * 0.35, y: cy + r * 0.65)
        )
        p.addCurve(
            to: CGPoint(x: cx - r, y: cy - r * 0.15),
            control1: CGPoint(x: cx - r * 0.35, y: cy + r * 0.65),
            control2: CGPoint(x: cx - r * 0.96, y: cy + r * 0.35)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy - r * 0.25),
            control1: CGPoint(x: cx - r * 1.08, y: cy - r * 0.82),
            control2: CGPoint(x: cx - r * 0.35, y: cy - r * 1.05)
        )
        p.closeSubpath()
        return p
    }

    static func fiveStarPath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        var star = Path()
        for k in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
            let rr = k.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: center.x + cos(a) * rr, y: center.y + sin(a) * rr)
            if k == 0 { star.move(to: pt) } else { star.addLine(to: pt) }
        }
        star.closeSubpath()
        return star
    }
}
