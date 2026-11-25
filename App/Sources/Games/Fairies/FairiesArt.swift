import SwiftUI

enum FairiesArt {
    static func drawScene(_ g: GraphicsContext, sim: FairiesSim) {
        switch sim.station {
        case .stage:
            drawCompactStageScene(g, sim: sim)
        case .salon:
            drawWingSalonScene(g, sim: sim)
        case .teaTable:
            drawTeaTableScene(g, sim: sim)
        }
    }

    // MARK: - Station 1: Cozy Compact Stage

    private static func isActorRenderedInsideSpot(_ actor: CompactFairyActor, spot: CompactSpot, sim: FairiesSim) -> Bool {
        if sim.draggingCompactFairy == actor.kind || actor.ridingCarousel || sim.discoPartyTimer > 0 {
            return false
        }
        if sim.isNightMode && spot != .cloudBed {
            return false
        }
        guard spot != .danceStage else { return false }
        let rest = CGPoint(x: spot.center.x + spot.fairyOffset.x, y: spot.center.y + spot.fairyOffset.y)
        let threshold: CGFloat = spot == .treatTable ? 48 : 30
        return actor.currentSpot == spot && hypot(actor.position.x - rest.x, actor.position.y - rest.y) <= threshold
    }

    private static func drawCompactStageScene(_ g: GraphicsContext, sim: FairiesSim) {
        let t = sim.time
        let openElapsed = max(0, t - sim.stationTransitionAt)
        let openScale: CGFloat = openElapsed < 0.36
            ? CGFloat(0.92 + 0.08 * sin(min(1, openElapsed / 0.36) * .pi * 0.5))
            : 1.0

        drawCompactBackdrop(g, isNightMode: sim.isNightMode, time: t)

        var room = g
        room.translateBy(x: FGeo.compactCenter.x, y: FGeo.compactCenter.y)
        room.scaleBy(x: openScale, y: openScale)
        room.translateBy(x: -FGeo.compactCenter.x, y: -FGeo.compactCenter.y)

        drawHeartCompactShell(room, sim: sim, time: t)

        if sim.hasCarousel {
            drawCompactCarousel(room, center: FGeo.carouselCenter, sim: sim, time: t)
        }

        let showTargets = sim.draggingCompactFairy != nil || sim.pendingPlacementFairy != nil
        for spot in CompactSpot.allCases {
            let hovered = sim.compactHoverSpot == spot
            drawCompactSpot(room, spot: spot, sim: sim, highlighted: showTargets, hovered: hovered)
        }

        drawActiveRainbowTrails(room, sim: sim)

        let roaming = sim.compactActors
            .filter { actor in
                guard sim.draggingCompactFairy != actor.kind, !actor.ridingCarousel else { return false }
                for spot in CompactSpot.allCases where isActorRenderedInsideSpot(actor, spot: spot, sim: sim) {
                    return false
                }
                return true
            }
            .sorted { $0.position.y < $1.position.y }

        for actor in roaming {
            drawCompactActor(room, actor: actor, sim: sim, time: t)
        }

        drawCompactPoppableBubbles(room, bubbles: sim.compactBubbles, time: t)
        drawCompactSocialHearts(room, sim: sim, time: t)
        drawCompactWishBubbles(room, sim: sim, time: t)

        if sim.hasChandelier {
            drawCompactChandelier(
                room,
                anchor: CGPoint(x: FGeo.compactCenter.x, y: FGeo.compactCenter.y - FGeo.compactHeight * 0.34 + 12),
                isNightMode: sim.isNightMode,
                time: t
            )
        }

        drawParticles(room, particles: sim.particles, time: t)

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
            drawFairy(
                d,
                kind: dragged,
                mood: .giggle,
                accessory: sim.accessories[dragged],
                wingDesign: sim.wingDesigns[dragged],
                transform: sim.activeTransforms[dragged]?.kind,
                time: t,
                scale: 1.18,
                blinkSeed: Double(dragged.hashValue % 13)
            )
        }
    }

    private static func drawActiveRainbowTrails(_ g: GraphicsContext, sim: FairiesSim) {
        let colors: [UInt32] = [0xFF8EC2, 0xFFE07D, 0x8CE6CC, 0x9CCBFF, 0xD2A8FF]
        for (kind, pts) in sim.rainbowTrails where pts.count >= 2 && sim.activeTransforms[kind]?.kind == .rainbowTrail {
            for (bandIdx, hex) in colors.enumerated() {
                let offset = CGFloat(bandIdx - 2) * 3.2
                var path = Path()
                path.move(to: CGPoint(x: pts[0].x, y: pts[0].y + offset))
                for pt in pts.dropFirst() {
                    path.addLine(to: CGPoint(x: pt.x, y: pt.y + offset))
                }
                g.stroke(
                    path,
                    with: .color(StorybookArt.color(hex, alpha: 0.56)),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private static func drawCompactActor(_ g: GraphicsContext, actor: CompactFairyActor, sim: FairiesSim, time t: Double) {
        let bobY: CGFloat = sim.discoPartyTimer > 0
            ? -abs(CGFloat(sin(t * 6.0 + actor.bobPhase))) * 14
            : CGFloat(sin(t * 3.4 + actor.bobPhase)) * 4.5
        let pos = CGPoint(x: actor.position.x, y: actor.position.y + bobY)
        let transform = sim.activeTransforms[actor.kind]?.kind

        g.fill(
            Path(ellipseIn: CGRect(x: actor.position.x - 22, y: actor.position.y + 34, width: 44, height: 11)),
            with: .color(Theme.ink.opacity(sim.isNightMode ? 0.22 : 0.1))
        )

        drawSelectionHaloIfNeeded(g, at: pos, fairy: actor.kind, sim: sim, time: t)

        var fc = g
        fc.translateBy(x: pos.x, y: pos.y)
        let lean = max(-0.18, min(0.18, Double(actor.velocity.dx) * 0.0024))
        let discoTilt = sim.discoPartyTimer > 0 ? sin(t * 6.0 + actor.bobPhase) * 0.15 : 0
        fc.rotate(by: .radians(lean + discoTilt))
        drawFairy(
            fc,
            kind: actor.kind,
            mood: actor.mood,
            accessory: sim.accessories[actor.kind],
            wingDesign: sim.wingDesigns[actor.kind],
            transform: transform,
            time: t,
            scale: 0.96,
            blinkSeed: actor.bobPhase
        )
    }

    private static func drawCompactPoppableBubbles(_ g: GraphicsContext, bubbles: [CompactBubble], time t: Double) {
        for b in bubbles {
            let fade = Double(min(1, max(0, (1 - b.age / b.maxAge) * 2.2)))
            let r = b.radius
            let wobble = CGFloat(sin(t * 4.5 + b.phase)) * 0.05
            var c = g
            c.translateBy(x: b.pos.x, y: b.pos.y)
            c.scaleBy(x: 1 + wobble, y: 1 - wobble)

            let rect = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
            let p = Path(ellipseIn: rect)
            c.fill(
                p,
                with: .radialGradient(
                    Gradient(colors: [
                        .white.opacity(0.32 * fade),
                        StorybookArt.color(b.tintHex, alpha: 0.28 * fade),
                        StorybookArt.color(0xFFB8E2, alpha: 0.45 * fade),
                    ]),
                    center: CGPoint(x: -r * 0.28, y: -r * 0.28),
                    startRadius: 2,
                    endRadius: r
                )
            )
            c.stroke(p, with: .color(.white.opacity(0.92 * fade)), lineWidth: 2.4)
            StorybookArt.highlight(c, in: CGRect(x: -r * 0.52, y: -r * 0.55, width: r * 0.44, height: r * 0.26), opacity: 0.85 * fade)
        }
    }

    private static func drawCompactSocialHearts(_ g: GraphicsContext, sim: FairiesSim, time t: Double) {
        var drawnPairs: Set<String> = []
        for actor in sim.compactActors where actor.chatTimer > 0 {
            guard let partnerKind = actor.chatPartner,
                  let partner = sim.compactActors.first(where: { $0.kind == partnerKind }) else { continue }
            let key = actor.kind.rawValue < partnerKind.rawValue
                ? "\(actor.kind.rawValue)-\(partnerKind.rawValue)"
                : "\(partnerKind.rawValue)-\(actor.kind.rawValue)"
            guard drawnPairs.insert(key).inserted else { continue }

            let mid = CGPoint(
                x: (actor.position.x + partner.position.x) * 0.5,
                y: min(actor.position.y, partner.position.y) - 44 + CGFloat(sin(t * 6)) * 5
            )
            StorybookArt.heart(g, at: CGPoint(x: mid.x - 10, y: mid.y), size: 20, color: Theme.pink)
            StorybookArt.heart(g, at: CGPoint(x: mid.x + 11, y: mid.y - 8), size: 15, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: mid.x, y: mid.y - 18), radius: 7, color: .white)
        }
    }

    private static func drawCompactWishBubbles(_ g: GraphicsContext, sim: FairiesSim, time t: Double) {
        for actor in sim.compactActors {
            guard let wish = actor.wish, sim.draggingCompactFairy != actor.kind else { continue }
            let bob = CGFloat(sin(t * 3.6 + actor.bobPhase)) * 4
            let bubbleCenter = CGPoint(
                x: max(195, min(829, actor.position.x + 34)),
                y: max(172, actor.position.y - 78 + bob)
            )
            let tailTarget = CGPoint(x: actor.position.x + 12, y: actor.position.y - 36)
            StorybookArt.thoughtBubble(g, center: bubbleCenter, radius: 31, tailToward: tailTarget)

            var ic = g
            ic.translateBy(x: bubbleCenter.x, y: bubbleCenter.y)
            drawWishIcon(ic, wish: wish, time: t)
        }
    }

    private static func drawWishIcon(_ g: GraphicsContext, wish: FairyWish, time t: Double) {
        switch wish {
        case .snack:
            drawBungeoppang(g, at: CGPoint(x: -1, y: 2), scale: 0.85)
            StorybookArt.heart(g, at: CGPoint(x: 12, y: -12), size: 10, color: Theme.pink)
        case .bubbles:
            drawBubble(g, at: CGPoint(x: -8, y: 5), radius: 10, alpha: 1)
            drawBubble(g, at: CGPoint(x: 8, y: -5), radius: 12, alpha: 1)
            StorybookArt.sparkle(g, at: CGPoint(x: -10, y: -12), radius: 5, color: Theme.lemon)
        case .swing:
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: 12), radius: 19, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            g.stroke(arc, with: .color(Theme.pink), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            var arc2 = Path()
            arc2.addArc(center: CGPoint(x: 0, y: 12), radius: 14, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            g.stroke(arc2, with: .color(Theme.lemon), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            let seat = Path(roundedRect: CGRect(x: -11, y: 5, width: 22, height: 6), cornerRadius: 3)
            StorybookArt.fillAndStroke(g, seat, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xFF8FB8), width: 1.6)
        case .dance:
            let col = Theme.pink
            g.fill(Path(ellipseIn: CGRect(x: -11, y: 3, width: 11, height: 8)), with: .color(col))
            g.fill(Path(ellipseIn: CGRect(x: 3, y: 0, width: 11, height: 8)), with: .color(Theme.lilac))
            var notes = Path()
            notes.move(to: CGPoint(x: -1, y: 6))
            notes.addLine(to: CGPoint(x: -1, y: -13))
            notes.addLine(to: CGPoint(x: 13, y: -16))
            notes.addLine(to: CGPoint(x: 13, y: 3))
            g.stroke(notes, with: .color(col), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
            StorybookArt.sparkle(g, at: CGPoint(x: -13, y: -11), radius: 5.5, color: Theme.lemon)
        case .sleep:
            var crescent = Path(ellipseIn: CGRect(x: -12, y: -12, width: 24, height: 24))
            crescent.addEllipse(in: CGRect(x: -4, y: -15, width: 22, height: 22))
            g.fill(crescent, with: .color(Theme.lemon), style: FillStyle(eoFill: true))
            StorybookArt.sparkle(g, at: CGPoint(x: 10, y: -8), radius: 6, color: Theme.lilac)
        case .carousel:
            var tent = Path()
            tent.move(to: CGPoint(x: -16, y: -2))
            tent.addLine(to: CGPoint(x: 0, y: -16))
            tent.addLine(to: CGPoint(x: 16, y: -2))
            tent.closeSubpath()
            StorybookArt.fillAndStroke(g, tent, fill: Theme.pink, stroke: StorybookArt.outline(for: 0xFF8FB8), width: 2)
            g.fill(Path(CGRect(x: -2, y: -2, width: 4, height: 14)), with: .color(Theme.lemon))
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -14, y: 10, width: 28, height: 6), cornerRadius: 3), fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE6A93B), width: 1.6)
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -18), radius: 5 + CGFloat(sin(t * 4)), color: Theme.lemon)
        case .wingSalon:
            FairyWingPainter.drawWings(
                g,
                wingCenter: .zero,
                wingHalfSpan: CGSize(width: 20, height: 16),
                baseHex: 0xFFB8DC,
                innerHex: 0xFFF2FA,
                outlineHex: 0xE678B2,
                design: nil,
                flap: CGFloat(sin(t * 6)) * 0.4,
                time: t,
                showVeins: false
            )
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -12), radius: 5.5, color: Theme.lemon)
        case .pixieTea:
            drawStationIcon(g, station: .teaTable)
        }
    }

    // MARK: - Station 2: Wing & Wand Salon

    private static func drawWingSalonScene(_ g: GraphicsContext, sim: FairiesSim) {
        let t = sim.time
        drawSalonBackdrop(g, time: t)
        drawSalonVanityMirror(g, time: t)

        let fairy = sim.selectedFairy
        let p = fairy.palette

        if sim.salonTool == .wandBuilder {
            var fc = g
            fc.translateBy(x: FGeo.salonWandFairyCenter.x, y: FGeo.salonWandFairyCenter.y + CGFloat(sin(t * 3.0)) * 5)
            drawFairy(
                fc,
                kind: fairy,
                mood: sim.wandWaveEnergy > 0.2 ? .celebrate : .happy,
                accessory: sim.accessories[fairy],
                wingDesign: sim.wingDesigns[fairy],
                transform: sim.activeTransforms[fairy]?.kind,
                time: t,
                scale: 1.65,
                blinkSeed: 0.4
            )

            let wand = sim.currentWand(for: fairy)
            let waveSway = CGFloat(sin(t * (sim.wandWaveEnergy > 0.1 ? 11.0 : 2.6))) * (12 + sim.wandWaveEnergy * 34)
            let tip: CGPoint
            let tail: CGPoint
            if let heldTip = sim.salonToolPos {
                tip = heldTip
                tail = sim.salonFingerPos ?? CGPoint(x: heldTip.x + 56, y: heldTip.y + 126)
            } else {
                tip = CGPoint(x: FGeo.salonWandCenter.x + 42 + waveSway, y: FGeo.salonWandCenter.y - 116)
                tail = CGPoint(x: FGeo.salonWandCenter.x + 12 - waveSway * 0.25, y: FGeo.salonWandCenter.y + 122)
            }
            drawWandTrail(g, trail: sim.wandTrail)
            FairyWingPainter.drawWand(
                g,
                design: wand,
                tip: tip,
                tail: tail,
                time: t,
                scale: 1.65,
                waveEnergy: sim.wandWaveEnergy
            )
            drawParticles(g, particles: sim.particles, time: t)
            return
        }

        let breath = CGFloat(sin(t * 2.5)) * 0.08
        let design = sim.wingDesigns[fairy]
        FairyWingPainter.drawWings(
            g,
            wingCenter: FGeo.salonWingCenter,
            wingHalfSpan: FGeo.salonWingHalfSpan,
            baseHex: p.wing,
            innerHex: p.wingInner,
            outlineHex: p.dressAccent,
            design: design,
            flap: breath,
            time: t,
            showVeins: true
        )

        if design?.isEmpty ?? true {
            for side in [-1.0, 1.0] as [CGFloat] {
                let pt = FairyWingPainter.toStagePoint(
                    WingPoint(u: 0.56, v: -0.36),
                    side: side,
                    wingCenter: FGeo.salonWingCenter,
                    wingHalfSpan: FGeo.salonWingHalfSpan
                )
                let pulse = 0.55 + 0.45 * sin(t * 4.2)
                StorybookArt.sparkle(g, at: pt, radius: 13 * CGFloat(pulse), color: Theme.lemon, opacity: 0.85)
            }
        }

        drawSalonFairyBackSilhouette(g, kind: fairy, accessory: sim.accessories[fairy], time: t)
        drawFallingGlitter(g, grains: sim.fallingGlitter)
        drawParticles(g, particles: sim.particles, time: t)
        drawActiveSalonCursor(g, sim: sim, time: t)
    }

    private static func drawSalonBackdrop(_ g: GraphicsContext, time t: Double) {
        let stage = CGRect(x: 0, y: 0, width: GameChromeLayout.width, height: GameChromeLayout.height)
        g.fill(
            Path(stage),
            with: .linearGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFE4F4),
                    StorybookArt.color(0xF6EAFF),
                    StorybookArt.color(0xFFF0F8),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 1024, y: 834)
            )
        )
        for i in 0..<16 {
            let x = CGFloat((i * 157 + 68) % 960) + 32
            let y = CGFloat((i * 113 + 74) % 680) + 48
            let alpha = 0.25 + 0.2 * sin(t * 1.8 + Double(i))
            StorybookArt.sparkle(g, at: CGPoint(x: x, y: y), radius: CGFloat(6 + (i % 3) * 3), color: i.isMultiple(of: 2) ? Theme.lemon : .white, opacity: alpha * 1.6)
        }
    }

    private static func drawSalonVanityMirror(_ g: GraphicsContext, time t: Double) {
        let c = FGeo.salonMirrorCenter
        let outer = Path(roundedRect: CGRect(x: c.x - 386, y: c.y - 252, width: 772, height: 504), cornerRadius: 150)
        g.fill(
            Path(roundedRect: CGRect(x: c.x - 382, y: c.y - 242, width: 764, height: 504), cornerRadius: 150),
            with: .color(Theme.ink.opacity(0.12))
        )
        g.fill(
            outer,
            with: .linearGradient(
                Gradient(colors: [StorybookArt.color(0xFFC2E2), StorybookArt.color(0xE8B8FF), StorybookArt.color(0xFFA8D6)]),
                startPoint: CGPoint(x: c.x - 380, y: c.y - 250),
                endPoint: CGPoint(x: c.x + 380, y: c.y + 250)
            )
        )
        g.stroke(outer, with: .color(StorybookArt.color(0xF6CD62)), lineWidth: 10)
        g.stroke(outer, with: .color(StorybookArt.outline(for: 0xE6A436)), lineWidth: 3)

        let glass = Path(roundedRect: CGRect(x: c.x - 356, y: c.y - 224, width: 712, height: 448), cornerRadius: 132)
        g.fill(
            glass,
            with: .radialGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFFFFF),
                    StorybookArt.color(0xFFF6FC),
                    StorybookArt.color(0xF3E6FF),
                ]),
                center: CGPoint(x: c.x, y: c.y - 30),
                startRadius: 30,
                endRadius: 390
            )
        )
        g.stroke(glass, with: .color(StorybookArt.color(0xF6D478)), lineWidth: 4.5)

        var clipped = g
        clipped.clip(to: glass)
        var sheen = Path()
        sheen.move(to: CGPoint(x: c.x - 280, y: c.y - 240))
        sheen.addLine(to: CGPoint(x: c.x - 170, y: c.y - 240))
        sheen.addLine(to: CGPoint(x: c.x - 330, y: c.y + 240))
        sheen.addLine(to: CGPoint(x: c.x - 420, y: c.y + 240))
        sheen.closeSubpath()
        clipped.fill(sheen, with: .color(.white.opacity(0.45)))

        let pearls: [CGPoint] = [
            CGPoint(x: c.x - 260, y: c.y - 238),
            CGPoint(x: c.x - 130, y: c.y - 238),
            CGPoint(x: c.x + 130, y: c.y - 238),
            CGPoint(x: c.x + 260, y: c.y - 238),
            CGPoint(x: c.x - 371, y: c.y - 60),
            CGPoint(x: c.x - 371, y: c.y + 60),
            CGPoint(x: c.x + 371, y: c.y - 60),
            CGPoint(x: c.x + 371, y: c.y + 60),
        ]
        for (idx, pt) in pearls.enumerated() {
            let glow = 0.5 + 0.5 * sin(t * 3.0 + Double(idx))
            let pearl = Path(ellipseIn: CGRect(x: pt.x - 8, y: pt.y - 8, width: 16, height: 16))
            StorybookArt.fillAndStroke(g, pearl, fill: .white, stroke: StorybookArt.color(0xE8B84E), width: 2.2)
            StorybookArt.sparkle(g, at: pt, radius: 5 * CGFloat(glow), color: Theme.lemon, opacity: 0.7)
        }

        let crownCenter = CGPoint(x: c.x, y: c.y - 242)
        StorybookArt.fillAndStroke(g, heartPath(center: crownCenter, size: 38), fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE0A030), width: 2.8)
        StorybookArt.fillAndStroke(g, heartPath(center: crownCenter, size: 24), fill: Theme.pink, stroke: StorybookArt.outline(for: 0xDE6496), width: 2)
    }

    private static func drawSalonFairyBackSilhouette(
        _ g: GraphicsContext,
        kind: FairyKind,
        accessory: FairyAccessory?,
        time t: Double
    ) {
        let p = kind.palette
        var c = g
        c.translateBy(x: FGeo.salonWingCenter.x, y: FGeo.salonWingCenter.y + 10)
        c.scaleBy(x: 1.55, y: 1.55)

        let dressOutline = StorybookArt.outline(for: p.dressAccent, factor: 0.72)
        var dress = Path()
        dress.move(to: CGPoint(x: -14, y: -14))
        dress.addCurve(to: CGPoint(x: -30, y: 42), control1: CGPoint(x: -24, y: 6), control2: CGPoint(x: -32, y: 26))
        dress.addQuadCurve(to: CGPoint(x: 30, y: 42), control: CGPoint(x: 0, y: 52))
        dress.addCurve(to: CGPoint(x: 14, y: -14), control1: CGPoint(x: 32, y: 26), control2: CGPoint(x: 24, y: 6))
        dress.closeSubpath()
        StorybookArt.fillAndStroke(c, dress, fill: StorybookArt.color(p.dress), stroke: dressOutline, width: 2.6)

        let sash = Path(roundedRect: CGRect(x: -15, y: 2, width: 30, height: 10), cornerRadius: 5)
        StorybookArt.fillAndStroke(c, sash, fill: StorybookArt.color(p.dressAccent), stroke: dressOutline, width: 2)
        for side in [-1.0, 1.0] as [CGFloat] {
            let loop = Path(ellipseIn: CGRect(x: side < 0 ? -15 : 1, y: -1, width: 14, height: 12))
            StorybookArt.fillAndStroke(c, loop, fill: StorybookArt.color(p.emblem), stroke: StorybookArt.outline(for: p.emblem), width: 1.8)
        }

        var headCtx = c
        headCtx.translateBy(x: 0, y: -32)
        drawBackHair(headCtx, kind: kind, palette: p)
        let backHead = Path(ellipseIn: CGRect(x: -24, y: -32, width: 48, height: 42))
        StorybookArt.fillAndStroke(
            headCtx,
            backHead,
            fill: StorybookArt.color(p.hair),
            stroke: StorybookArt.outline(for: p.hairShade, factor: 0.68),
            width: 2.6
        )
        StorybookArt.highlight(headCtx, in: CGRect(x: -13, y: -26, width: 16, height: 7), opacity: 0.45)
        drawFairyEmblem(headCtx, kind: kind, palette: p)
        if let accessory {
            FairyWingPainter.drawAccessoryOnHead(headCtx, accessoryID: accessory.rawValue)
        }
        StorybookArt.sparkle(c, at: CGPoint(x: 0, y: -88), radius: 5 + CGFloat(sin(t * 4)) * 1.5, color: Theme.lemon, opacity: 0.85)
    }

    private static func drawFallingGlitter(_ g: GraphicsContext, grains: [FallingGlitterGrain]) {
        for grain in grains {
            let r = max(4.5, CGFloat(grain.size) * 145)
            StorybookArt.sparkle(g, at: grain.pos, radius: r, color: StorybookArt.color(grain.colorHex), opacity: 0.95)
            StorybookArt.sparkle(g, at: grain.pos, radius: r * 0.45, color: .white, opacity: 0.95)
        }
    }

    private static func drawActiveSalonCursor(_ g: GraphicsContext, sim: FairiesSim, time t: Double) {
        guard let pos = sim.salonToolPos else { return }
        switch sim.salonTool {
        case .brush(let color):
            let finger = sim.salonFingerPos ?? CGPoint(x: pos.x + 42, y: pos.y + 84)
            let handle = FingerLift.handle(tip: pos, finger: finger, length: 92)
            let end = CGPoint(x: pos.x + handle.dir.dx * handle.length, y: pos.y + handle.dir.dy * handle.length)
            var stick = Path()
            stick.move(to: end)
            stick.addLine(to: pos)
            g.stroke(stick, with: .color(StorybookArt.outline(for: 0xFF8EC2)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            g.stroke(stick, with: .color(StorybookArt.color(0xFFD6E9)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            StorybookArt.fillAndStroke(
                g,
                Path(ellipseIn: CGRect(x: pos.x - 13, y: pos.y - 13, width: 26, height: 26)),
                fill: StorybookArt.color(color.baseHex),
                stroke: .white,
                width: 3
            )
            StorybookArt.sparkle(g, at: pos, radius: 8, color: .white)

        case .glitter(let hex):
            var sc = g
            sc.translateBy(x: pos.x, y: pos.y)
            sc.rotate(by: .radians(-0.42 + sin(t * 22) * 0.16))
            let bottle = Path(roundedRect: CGRect(x: -20, y: -28, width: 40, height: 50), cornerRadius: 14)
            StorybookArt.fillAndStroke(sc, bottle, fill: StorybookArt.color(hex, alpha: 0.85), stroke: StorybookArt.outline(for: hex), width: 3)
            let cap = Path(roundedRect: CGRect(x: -14, y: 18, width: 28, height: 12), cornerRadius: 5)
            StorybookArt.fillAndStroke(sc, cap, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE0A030), width: 2.4)
            StorybookArt.sparkle(sc, at: CGPoint(x: 0, y: -4), radius: 10, color: .white)

        case .stamp(let kind):
            var sc = g
            sc.translateBy(x: pos.x, y: pos.y)
            let halo = Path(ellipseIn: CGRect(x: -30, y: -30, width: 60, height: 60))
            sc.fill(halo, with: .color(.white.opacity(0.65)))
            sc.stroke(halo, with: .color(StorybookArt.color(kind.accentHex)), style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
            FairyWingPainter.drawStamp(sc, kind: kind, radius: 22)

        case .wipe:
            var sc = g
            sc.translateBy(x: pos.x, y: pos.y)
            let sponge = Path(roundedRect: CGRect(x: -28, y: -20, width: 56, height: 40), cornerRadius: 16)
            StorybookArt.fillAndStroke(sc, sponge, fill: StorybookArt.color(0xD8F5FF), stroke: StorybookArt.outline(for: 0x86D4F8), width: 3)
            StorybookArt.highlight(sc, in: CGRect(x: -16, y: -12, width: 22, height: 10), opacity: 0.72)

        case .wandBuilder:
            break
        }
    }

    // MARK: - Station 3: Pixie Tea Table

    private static func drawTeaTableScene(_ g: GraphicsContext, sim: FairiesSim) {
        let t = sim.time
        drawTeaBackdrop(g, hasHanbokTea: sim.hasHanbokTea, time: t)

        let session = sim.teaSession
        let fairy = session.fairy
        let wish = session.wish
        let draft = session.draft

        let fairyMood: FairyMood
        let sipProgress: CGFloat
        switch session {
        case .awaitingPour, .pouring:
            fairyMood = .happy
            sipProgress = 0
        case .ready:
            fairyMood = .giggle
            sipProgress = 0
        case .sipping(_, _, _, let p):
            fairyMood = .yum
            sipProgress = p
        case .transformed:
            fairyMood = .celebrate
            sipProgress = 0
        }

        let activeTransform: TeaTransformKind?
        if case .transformed(_, _, let tr, _) = session {
            activeTransform = tr
        } else {
            activeTransform = sim.activeTransforms[fairy]?.kind
        }

        drawTeaParlorArch(g, hasHanbokTea: sim.hasHanbokTea, time: t)

        var fc = g
        let fairyBob = CGFloat(sin(t * 3.2)) * 5 - (fairyMood == .celebrate ? abs(CGFloat(sin(t * 8))) * 12 : 0)
        fc.translateBy(x: FGeo.teaFairyCenter.x, y: FGeo.teaFairyCenter.y + fairyBob)
        drawFairy(
            fc,
            kind: fairy,
            mood: fairyMood,
            accessory: sim.accessories[fairy],
            wingDesign: sim.wingDesigns[fairy],
            transform: activeTransform,
            time: t,
            scale: 1.72,
            blinkSeed: 0.25
        )

        drawTeaWishBubble(g, wish: wish, draft: draft, time: t)
        drawTeapotShelf(g, sim: sim, time: t)
        drawTeaTableSurface(g, hasHanbokTea: sim.hasHanbokTea)
        drawTeaPlateAndTreat(g, treat: draft?.platedTreat, hasHanbokTea: sim.hasHanbokTea, time: t)

        let cupLiftX = (FGeo.teaFairyCenter.x + 12 - FGeo.teaCupCenter.x) * sin(sipProgress * .pi)
        let cupLiftY = (FGeo.teaFairyCenter.y + 18 - FGeo.teaCupCenter.y) * sin(sipProgress * .pi)
        let cupCenter = CGPoint(x: FGeo.teaCupCenter.x + cupLiftX, y: FGeo.teaCupCenter.y + cupLiftY)
        let cupReady: Bool
        if case .ready = session { cupReady = true } else { cupReady = draft?.isReadyToServe ?? false }
        drawPixieTeacup(
            g,
            center: cupCenter,
            draft: draft,
            hasHanbokTea: sim.hasHanbokTea,
            readyPulse: cupReady,
            tilt: -Double(sin(sipProgress * .pi)) * 0.24,
            time: t
        )

        if case .pouring(_, _, _, let pouringNectar) = session {
            let potPos: CGPoint
            if sim.draggingTeapot == pouringNectar {
                potPos = sim.draggingTeapotPos
            } else {
                potPos = CGPoint(x: FGeo.teaCupCenter.x + 86, y: FGeo.teaCupCenter.y - 102 + CGFloat(sin(t * 5)) * 4)
            }
            drawPouringTeapotAndStream(g, nectar: pouringNectar, potCenter: potPos, cupCenter: FGeo.teaCupCenter, time: t)
        } else if let draggedPot = sim.draggingTeapot {
            var pc = g
            pc.translateBy(x: sim.draggingTeapotPos.x, y: sim.draggingTeapotPos.y)
            pc.scaleBy(x: 1.38, y: 1.38)
            drawTeapotIcon(pc, nectar: draggedPot)
        }

        if let draggedStar = sim.draggingSugarStar {
            var sc = g
            sc.translateBy(x: sim.draggingSugarPos.x, y: sim.draggingSugarPos.y)
            sc.scaleBy(x: 1.4, y: 1.4)
            drawSugarStarIcon(sc, star: draggedStar)
        }

        if let draggedTreat = sim.draggingTeaTreat {
            var tc = g
            tc.translateBy(x: sim.draggingTeaTreatPos.x, y: sim.draggingTeaTreatPos.y)
            tc.scaleBy(x: 1.4, y: 1.4)
            drawTeaTreatIcon(tc, treat: draggedTreat)
        }

        if case .transformed(_, _, let tr, _) = session {
            drawTeaStarCelebration(g, stars: sim.lastTeaStars, transform: tr, time: t)
        }

        drawParticles(g, particles: sim.particles, time: t)
    }

    private static func drawTeaBackdrop(_ g: GraphicsContext, hasHanbokTea: Bool, time t: Double) {
        let stage = CGRect(x: 0, y: 0, width: GameChromeLayout.width, height: GameChromeLayout.height)
        g.fill(
            Path(stage),
            with: .linearGradient(
                Gradient(colors: hasHanbokTea
                    ? [StorybookArt.color(0xE8FBF4), StorybookArt.color(0xFFF3F8), StorybookArt.color(0xFFF6E8)]
                    : [StorybookArt.color(0xFFEAF6), StorybookArt.color(0xFFF5EC), StorybookArt.color(0xEBF8FF)]
                ),
                startPoint: .zero,
                endPoint: CGPoint(x: 1024, y: 834)
            )
        )
        for i in 0..<14 {
            let x = CGFloat((i * 167 + 90) % 940) + 40
            let y = CGFloat((i * 109 + 70) % 620) + 50
            let alpha = 0.28 + 0.2 * sin(t * 1.9 + Double(i))
            StorybookArt.sparkle(g, at: CGPoint(x: x, y: y), radius: CGFloat(6 + (i % 3) * 2), color: Theme.lemon, opacity: alpha * 1.6)
        }
    }

    private static func drawTeaParlorArch(_ g: GraphicsContext, hasHanbokTea: Bool, time t: Double) {
        let arch = Path(roundedRect: CGRect(x: 108, y: 122, width: 828, height: 536), cornerRadius: 120)
        g.fill(
            arch,
            with: .radialGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFFDFB),
                    hasHanbokTea ? StorybookArt.color(0xEEFCF6) : StorybookArt.color(0xFFF3F9),
                    hasHanbokTea ? StorybookArt.color(0xD8F2E8) : StorybookArt.color(0xFCE4F2),
                ]),
                center: CGPoint(x: 512, y: 340),
                startRadius: 30,
                endRadius: 460
            )
        )
        let trimHex: UInt32 = hasHanbokTea ? 0x76CEB4 : 0xFFB0D6
        g.stroke(arch, with: .color(StorybookArt.color(0xF6CE64)), lineWidth: 9)
        g.stroke(arch, with: .color(StorybookArt.outline(for: trimHex)), lineWidth: 3)

        for sx in [210.0, 420.0, 620.0, 810.0] as [CGFloat] {
            drawTinyFlower(g, at: CGPoint(x: sx, y: 124), radius: 13, petalHex: hasHanbokTea ? 0x9EE3CB : 0xFFB8DC)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: 512, y: 122), radius: 11 + CGFloat(sin(t * 3.5)) * 2, color: Theme.lemon)
    }

    private static func drawTeaWishBubble(_ g: GraphicsContext, wish: PixieTeaWish, draft: TeaCupDraft?, time t: Double) {
        let c = FGeo.teaWishBubbleCenter
        let bob = CGFloat(sin(t * 2.8)) * 4
        let center = CGPoint(x: c.x, y: c.y + bob)

        let card = Path(roundedRect: CGRect(x: center.x - 62, y: center.y - 88, width: 124, height: 186), cornerRadius: 42)
        g.fill(card, with: .color(.white.opacity(0.96)))
        g.stroke(card, with: .color(Theme.blush), lineWidth: 5)

        let dot1 = Path(ellipseIn: CGRect(x: center.x + 54, y: center.y + 44, width: 18, height: 18))
        let dot2 = Path(ellipseIn: CGRect(x: center.x + 74, y: center.y + 62, width: 12, height: 12))
        StorybookArt.fillAndStroke(g, dot1, fill: .white, stroke: Theme.blush, width: 3)
        StorybookArt.fillAndStroke(g, dot2, fill: .white, stroke: Theme.blush, width: 2.5)

        let nectarDone = draft?.nectar == wish.nectar && (draft?.fillLevel ?? 0) >= 0.85
        let starDone = draft?.sugarStars.contains(wish.sugarStar) ?? false
        let treatDone = draft?.platedTreat == wish.treat

        let slots: [(CGFloat, Bool, (GraphicsContext) -> Void)] = [
            (-52, nectarDone, { ctx in drawTeapotIcon(ctx, nectar: wish.nectar) }),
            (4, starDone, { ctx in drawSugarStarIcon(ctx, star: wish.sugarStar) }),
            (58, treatDone, { ctx in drawTeaTreatIcon(ctx, treat: wish.treat) }),
        ]

        for (dy, matched, drawIcon) in slots {
            let slotCenter = CGPoint(x: center.x, y: center.y + dy)
            let ring = Path(ellipseIn: CGRect(x: slotCenter.x - 24, y: slotCenter.y - 24, width: 48, height: 48))
            StorybookArt.fillAndStroke(
                g,
                ring,
                fill: matched ? StorybookArt.color(0xFFF6D2) : StorybookArt.color(0xFFF8FC),
                stroke: matched ? StorybookArt.color(0xFFB830) : Theme.blush,
                width: matched ? 3.5 : 2.2
            )
            var ic = g
            ic.translateBy(x: slotCenter.x, y: slotCenter.y)
            ic.scaleBy(x: 0.72, y: 0.72)
            drawIcon(ic)
            if matched {
                StorybookArt.sparkle(g, at: CGPoint(x: slotCenter.x + 20, y: slotCenter.y - 18), radius: 8, color: Theme.lemon)
            }
        }
    }

    private static func drawTeapotShelf(_ g: GraphicsContext, sim: FairiesSim, time t: Double) {
        let shelf = Path(roundedRect: CGRect(x: 680, y: 176, width: 244, height: 242), cornerRadius: 34)
        StorybookArt.fillAndStroke(g, shelf, fill: StorybookArt.color(0xFFFDF8, alpha: 0.92), stroke: Theme.blush, width: 4)

        for y in [284.0, 396.0] as [CGFloat] {
            let plank = Path(roundedRect: CGRect(x: 694, y: y, width: 216, height: 12), cornerRadius: 6)
            StorybookArt.fillAndStroke(g, plank, fill: StorybookArt.color(0xFFE6F0), stroke: StorybookArt.outline(for: 0xF0A8C8), width: 2)
        }

        for nectar in TeaNectar.allCases {
            let center = FGeo.teapotShelfCenter(for: nectar)
            let isInUse = sim.draggingTeapot == nectar || sim.autoPourNectar == nectar
            let isWished = sim.teaSession.wish.nectar == nectar && !(sim.teaSession.draft?.hasNectar ?? false)

            if isWished && !isInUse {
                let haloR: CGFloat = 46 + CGFloat(sin(t * 5)) * 4
                g.fill(
                    Path(ellipseIn: CGRect(x: center.x - haloR, y: center.y - haloR, width: haloR * 2, height: haloR * 2)),
                    with: .radialGradient(
                        Gradient(colors: [StorybookArt.color(0xFFE684, alpha: 0.52), StorybookArt.color(0xFFE684, alpha: 0)]),
                        center: center,
                        startRadius: 8,
                        endRadius: haloR
                    )
                )
            }

            if !isInUse {
                var pc = g
                pc.translateBy(x: center.x, y: center.y)
                pc.scaleBy(x: 1.24, y: 1.24)
                drawTeapotIcon(pc, nectar: nectar)
            }
        }
    }

    private static func drawTeaTableSurface(_ g: GraphicsContext, hasHanbokTea: Bool) {
        let c = FGeo.teaTableCenter
        let clothOutline = StorybookArt.outline(for: hasHanbokTea ? 0x76CEB4 : 0xF09EC2)

        let base = Path(roundedRect: CGRect(x: c.x - 74, y: c.y + 42, width: 148, height: 112), cornerRadius: 28)
        StorybookArt.fillAndStroke(g, base, fill: StorybookArt.color(0xFFF3E6), stroke: StorybookArt.outline(for: 0xE6C4A8), width: 3.4)

        let top = Path(ellipseIn: CGRect(x: c.x - 318, y: c.y - 76, width: 636, height: 158))
        g.fill(
            top,
            with: .linearGradient(
                Gradient(colors: hasHanbokTea
                    ? [StorybookArt.color(0xFFFDFB), StorybookArt.color(0xE6F9F2)]
                    : [StorybookArt.color(0xFFFDFB), StorybookArt.color(0xFFEBF4)]
                ),
                startPoint: CGPoint(x: c.x, y: c.y - 76),
                endPoint: CGPoint(x: c.x, y: c.y + 82)
            )
        )
        g.stroke(top, with: .color(clothOutline), lineWidth: 4.5)

        let lace = Path(ellipseIn: CGRect(x: c.x - 294, y: c.y - 62, width: 588, height: 130))
        g.stroke(lace, with: .color(StorybookArt.color(hasHanbokTea ? 0x9EE3CB : 0xFFC2DE)), style: StrokeStyle(lineWidth: 2.8, dash: [10, 8]))
    }

    private static func drawTeaPlateAndTreat(_ g: GraphicsContext, treat: FairyTeaTreatKind?, hasHanbokTea: Bool, time t: Double) {
        let c = FGeo.teaPlateCenter
        let rimOutline = StorybookArt.outline(for: hasHanbokTea ? 0x62B89B : 0x9CCBFF)
        let plateFill = hasHanbokTea ? StorybookArt.color(0xE2F9F0) : Color.white
        let plate = Path(ellipseIn: CGRect(x: c.x - 68, y: c.y - 24, width: 136, height: 52))
        StorybookArt.fillAndStroke(g, plate, fill: plateFill, stroke: rimOutline, width: 3.4)
        let inner = Path(ellipseIn: CGRect(x: c.x - 48, y: c.y - 15, width: 96, height: 34))
        g.stroke(inner, with: .color(StorybookArt.color(hasHanbokTea ? 0x9EE3CB : 0xFFD9E6)), lineWidth: 2)

        if let treat {
            var tc = g
            tc.translateBy(x: c.x, y: c.y - 10 + CGFloat(sin(t * 3.5)) * 1.5)
            tc.scaleBy(x: 1.55, y: 1.55)
            drawTeaTreatIcon(tc, treat: treat)
        } else {
            StorybookArt.sparkle(g, at: c, radius: 9, color: Theme.blush, opacity: 0.7)
        }
    }

    private static func drawPixieTeacup(
        _ g: GraphicsContext,
        center: CGPoint,
        draft: TeaCupDraft?,
        hasHanbokTea: Bool,
        readyPulse: Bool,
        tilt: Double,
        time t: Double
    ) {
        if readyPulse {
            let r: CGFloat = 96 + CGFloat(sin(t * 6)) * 8
            g.fill(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r * 0.72, width: r * 2, height: r * 1.44)),
                with: .radialGradient(
                    Gradient(colors: [StorybookArt.color(0xFFF2A6, alpha: 0.65), StorybookArt.color(0xFF9AC8, alpha: 0)]),
                    center: center,
                    startRadius: 16,
                    endRadius: r
                )
            )
        }

        let cupOutline = StorybookArt.outline(for: hasHanbokTea ? 0x52B096 : 0xE68BB6)
        let cupFillTop = StorybookArt.color(hasHanbokTea ? 0xCCF5E6 : 0xFFF8FC)
        let cupFillBot = StorybookArt.color(hasHanbokTea ? 0x8EDDC2 : 0xFFD6EA)

        let saucer = Path(ellipseIn: CGRect(x: center.x - 86, y: center.y + 34, width: 172, height: 32))
        StorybookArt.fillAndStroke(g, saucer, fill: cupFillTop, stroke: cupOutline, width: 3.4)

        var c = g
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .radians(tilt))

        let handle = Path(ellipseIn: CGRect(x: 48, y: -14, width: 40, height: 42))
        c.stroke(handle, with: .color(cupOutline), lineWidth: 12)
        c.stroke(handle, with: .color(cupFillBot), lineWidth: 6.5)

        var cup = Path()
        cup.move(to: CGPoint(x: -66, y: -34))
        cup.addCurve(to: CGPoint(x: -44, y: 46), control1: CGPoint(x: -64, y: 12), control2: CGPoint(x: -56, y: 40))
        cup.addLine(to: CGPoint(x: 44, y: 46))
        cup.addCurve(to: CGPoint(x: 66, y: -34), control1: CGPoint(x: 56, y: 40), control2: CGPoint(x: 64, y: 12))
        cup.closeSubpath()

        c.fill(
            cup,
            with: .linearGradient(
                Gradient(colors: [cupFillTop, cupFillBot]),
                startPoint: CGPoint(x: -36, y: -30),
                endPoint: CGPoint(x: 36, y: 46)
            )
        )
        c.stroke(cup, with: .color(cupOutline), style: StrokeStyle(lineWidth: 3.8, lineCap: .round, lineJoin: .round))

        if hasHanbokTea {
            drawTinyFlower(c, at: CGPoint(x: 0, y: 14), radius: 14, petalHex: 0xFFFFFF)
        } else {
            StorybookArt.heart(c, at: CGPoint(x: 0, y: 14), size: 28, color: Theme.pink)
        }
        StorybookArt.highlight(c, in: CGRect(x: -48, y: -14, width: 16, height: 28), opacity: 0.55)

        let rim = Path(ellipseIn: CGRect(x: -66, y: -48, width: 132, height: 28))
        StorybookArt.fillAndStroke(c, rim, fill: StorybookArt.color(0xFFFDFB), stroke: cupOutline, width: 3.4)

        if let draft, draft.fillLevel > 0.02 {
            let level = min(1, draft.fillLevel)
            let w: CGFloat = 116 * (0.68 + 0.32 * level)
            let h: CGFloat = 22 * (0.68 + 0.32 * level)
            let ly: CGFloat = -28 - level * 8
            let liquid = Path(ellipseIn: CGRect(x: -w * 0.5, y: ly - h * 0.5, width: w, height: h))
            c.fill(
                liquid,
                with: .radialGradient(
                    Gradient(colors: [StorybookArt.tint(for: draft.liquidHex, amount: 0.32), StorybookArt.color(draft.liquidHex)]),
                    center: CGPoint(x: -w * 0.16, y: ly - 2),
                    startRadius: 4,
                    endRadius: w * 0.6
                )
            )
            StorybookArt.highlight(c, in: CGRect(x: -w * 0.32, y: ly - h * 0.25, width: w * 0.3, height: h * 0.28), opacity: 0.55)

            for (idx, star) in draft.sugarStars.enumerated() {
                let sx = CGFloat(idx - 1) * 24 + CGFloat(sin(t * 4.5 + Double(idx))) * 5
                let sy = ly + CGFloat(cos(t * 3.8 + Double(idx))) * 3
                let starPath = fiveStarPath(center: CGPoint(x: sx, y: sy), outer: 9, inner: 4.5)
                StorybookArt.fillAndStroke(c, starPath, fill: StorybookArt.color(star.colorHex), stroke: .white, width: 1.5)
            }

            if draft.fizzTimer > 0 {
                for k in 0..<5 {
                    let fx = CGFloat(k - 2) * 18 + CGFloat(sin(t * 9 + Double(k))) * 6
                    let fy = ly - 10 - CGFloat((t * 3 + Double(k) * 0.2).truncatingRemainder(dividingBy: 1)) * 28
                    drawBubble(c, at: CGPoint(x: fx, y: fy), radius: CGFloat(5 + (k % 3) * 2), alpha: 0.9)
                }
            }

            for k in 0..<3 {
                let drift = CGFloat(sin(t * 2.6 + Double(k) * 2.0)) * 7
                let sx = CGFloat(k - 1) * 22
                var steam = Path()
                steam.move(to: CGPoint(x: sx, y: ly - 12))
                steam.addQuadCurve(to: CGPoint(x: sx + drift, y: ly - 52), control: CGPoint(x: sx - drift, y: ly - 32))
                c.stroke(steam, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }

    private static func drawPouringTeapotAndStream(
        _ g: GraphicsContext,
        nectar: TeaNectar,
        potCenter: CGPoint,
        cupCenter: CGPoint,
        time t: Double
    ) {
        let spoutOrigin = CGPoint(x: potCenter.x - 42, y: potCenter.y + 8)
        let cupTarget = CGPoint(x: cupCenter.x, y: cupCenter.y - 34)
        var stream = Path()
        stream.move(to: spoutOrigin)
        stream.addQuadCurve(to: cupTarget, control: CGPoint(x: cupTarget.x + 8, y: spoutOrigin.y + 18))
        g.stroke(stream, with: .color(StorybookArt.color(nectar.liquidHex, alpha: 0.92)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        g.stroke(stream, with: .color(.white.opacity(0.72)), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        var pc = g
        pc.translateBy(x: potCenter.x, y: potCenter.y)
        pc.rotate(by: .radians(-0.48 + sin(t * 9) * 0.05))
        pc.scaleBy(x: 1.5, y: 1.5)
        drawTeapotIcon(pc, nectar: nectar)
    }

    private static func drawTeaStarCelebration(_ g: GraphicsContext, stars: Int, transform: TeaTransformKind, time t: Double) {
        let clamped = max(1, min(3, stars))
        let spacing: CGFloat = 46
        let startX = FGeo.teaFairyCenter.x - CGFloat(clamped - 1) * spacing * 0.5
        let baseY = FGeo.teaFairyCenter.y - 126 + CGFloat(sin(t * 5)) * 5
        for i in 0..<clamped {
            let pt = CGPoint(x: startX + CGFloat(i) * spacing, y: baseY - (i == 1 && clamped == 3 ? 10 : 0))
            let sp = fiveStarPath(center: pt, outer: 20, inner: 9)
            StorybookArt.fillAndStroke(g, sp, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE0A030), width: 2.6)
            StorybookArt.sparkle(g, at: pt, radius: 7, color: .white)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: FGeo.teaFairyCenter.x + 76, y: FGeo.teaFairyCenter.y - 76), radius: 13, color: StorybookArt.color(transform.accentHex))
    }

    // MARK: - Compact Stage Backdrop, Shell, Furniture & Treasures

    private static func drawCompactBackdrop(_ g: GraphicsContext, isNightMode: Bool, time t: Double) {
        let stage = CGRect(x: 0, y: 0, width: GameChromeLayout.width, height: GameChromeLayout.height)
        g.fill(
            Path(stage),
            with: .linearGradient(
                Gradient(colors: isNightMode
                    ? [StorybookArt.color(0x3D3268), StorybookArt.color(0x5A478E), StorybookArt.color(0x4A3A7A)]
                    : [StorybookArt.color(0xFFE0F2), StorybookArt.color(0xF3E6FF), StorybookArt.color(0xFFEBF5)]
                ),
                startPoint: .zero,
                endPoint: CGPoint(x: 1024, y: 834)
            )
        )
        for i in 0..<18 {
            let x = CGFloat((i * 173 + 52) % 980) + 22
            let y = CGFloat((i * 139 + 64) % 720) + 40
            let r = CGFloat(12 + (i % 4) * 8)
            let alpha = (isNightMode ? 0.32 : 0.2) + 0.18 * sin(t * 1.6 + Double(i))
            if !isNightMode {
                g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha)))
            }
            if isNightMode || i % 2 == 0 {
                StorybookArt.sparkle(g, at: CGPoint(x: x, y: y), radius: isNightMode ? 8.5 : 7, color: Theme.lemon, opacity: min(1, alpha * 2.0))
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
        p.addCurve(to: CGPoint(x: cx + hw, y: center.y - height * 0.08), control1: CGPoint(x: cx + hw * 0.34, y: topY - height * 0.14), control2: CGPoint(x: cx + hw * 1.06, y: topY + height * 0.04))
        p.addCurve(to: CGPoint(x: cx, y: bottomY), control1: CGPoint(x: cx + hw * 0.96, y: center.y + height * 0.32), control2: CGPoint(x: cx + hw * 0.38, y: bottomY - height * 0.02))
        p.addCurve(to: CGPoint(x: cx - hw, y: center.y - height * 0.08), control1: CGPoint(x: cx - hw * 0.38, y: bottomY - height * 0.02), control2: CGPoint(x: cx - hw * 0.96, y: center.y + height * 0.32))
        p.addCurve(to: CGPoint(x: cx, y: topDipY), control1: CGPoint(x: cx - hw * 1.06, y: topY + height * 0.04), control2: CGPoint(x: cx - hw * 0.34, y: topY - height * 0.14))
        p.closeSubpath()
        return p
    }

    private static func drawHeartCompactShell(_ g: GraphicsContext, sim: FairiesSim, time t: Double) {
        let c = FGeo.compactCenter
        let night = sim.isNightMode

        let shadowPath = heartCompactPath(center: CGPoint(x: c.x, y: c.y + 12), width: FGeo.compactWidth + 14, height: FGeo.compactHeight + 14)
        g.fill(shadowPath, with: .color(Theme.ink.opacity(night ? 0.34 : 0.14)))

        let outer = heartCompactPath(center: c, width: FGeo.compactWidth, height: FGeo.compactHeight)
        g.fill(
            outer,
            with: .linearGradient(
                Gradient(colors: night
                    ? [StorybookArt.color(0x8D72C8), StorybookArt.color(0x7058AC), StorybookArt.color(0x5E4898)]
                    : [StorybookArt.color(0xFFB8DC), StorybookArt.color(0xFF9AC8), StorybookArt.color(0xE88BC2)]
                ),
                startPoint: CGPoint(x: c.x, y: c.y - 300),
                endPoint: CGPoint(x: c.x, y: c.y + 300)
            )
        )
        g.stroke(outer, with: .color(StorybookArt.color(0xF5CA5C)), lineWidth: 10)
        g.stroke(outer, with: .color(StorybookArt.outline(for: 0xE6A436)), lineWidth: 3.2)

        let inner = heartCompactPath(center: c, width: FGeo.compactWidth - 46, height: FGeo.compactHeight - 44)
        g.fill(
            inner,
            with: .radialGradient(
                Gradient(colors: night
                    ? [StorybookArt.color(0x634E96), StorybookArt.color(0x4E3D7C), StorybookArt.color(0x3F3068)]
                    : [StorybookArt.color(0xFFFDFB), StorybookArt.color(0xFFF2F8), StorybookArt.color(0xFCE2F2)]
                ),
                center: CGPoint(x: c.x, y: c.y - 40),
                startRadius: 30,
                endRadius: 420
            )
        )
        g.stroke(inner, with: .color(StorybookArt.color(0xF5D078)), lineWidth: 5)

        var clipped = g
        clipped.clip(to: inner)
        for sx in stride(from: c.x - 380, through: c.x + 380, by: 48) {
            clipped.fill(
                Path(CGRect(x: sx, y: c.y - 310, width: 22, height: 340)),
                with: .color(night ? StorybookArt.color(0x8B72C8, alpha: 0.18) : StorybookArt.color(0xFFD9EB, alpha: 0.22))
            )
        }

        if night {
            for k in 0..<16 {
                let sx = c.x - 300 + CGFloat((k * 97) % 600)
                let sy = c.y - 190 + CGFloat((k * 61) % 190)
                let alpha = 0.45 + 0.5 * abs(sin(t * 2.2 + Double(k)))
                StorybookArt.sparkle(clipped, at: CGPoint(x: sx, y: sy), radius: CGFloat(5.0 + Double(k % 3) * 2.5), color: Theme.lemon, opacity: alpha)
            }
        }

        clipped.fill(
            Path(CGRect(x: c.x - 420, y: c.y + 24, width: 840, height: 290)),
            with: .linearGradient(
                Gradient(colors: night
                    ? [StorybookArt.color(0x5A4786), StorybookArt.color(0x4A3A72)]
                    : [StorybookArt.color(0xFFF4E6), StorybookArt.color(0xFCE4D6)]
                ),
                startPoint: CGPoint(x: c.x, y: c.y + 24),
                endPoint: CGPoint(x: c.x, y: c.y + 300)
            )
        )
        var molding = Path()
        molding.move(to: CGPoint(x: c.x - 420, y: c.y + 24))
        molding.addLine(to: CGPoint(x: c.x + 420, y: c.y + 24))
        clipped.stroke(molding, with: .color(night ? StorybookArt.color(0x9A82D0) : StorybookArt.color(0xF0C2D8)), lineWidth: 5)

        let rug = Path(ellipseIn: CGRect(x: c.x - 148, y: c.y + 42, width: 296, height: 92))
        StorybookArt.fillAndStroke(
            clipped,
            rug,
            fill: night ? StorybookArt.color(0x7A62B2, alpha: 0.72) : StorybookArt.color(0xFFE0F0, alpha: 0.72),
            stroke: night ? StorybookArt.color(0xC9B6FF) : StorybookArt.color(0xFFB5D6),
            width: 3.5
        )

        if sim.discoPartyTimer > 0 {
            let discoColors: [UInt32] = [0xFF8FB8, 0xFFE38A, 0x9FE3CF, 0x9CCBFF, 0xD2A8FF]
            let origin = CGPoint(x: c.x, y: c.y - FGeo.compactHeight * 0.34 + 18)
            for (idx, hex) in discoColors.enumerated() {
                let sweep = sin(t * 2.8 + Double(idx) * 1.26) * 280
                let baseX = c.x + CGFloat(idx - 2) * 90 + CGFloat(sweep) * 0.65
                var beam = Path()
                beam.move(to: origin)
                beam.addLine(to: CGPoint(x: baseX - 58, y: c.y + 260))
                beam.addLine(to: CGPoint(x: baseX + 58, y: c.y + 260))
                beam.closeSubpath()
                clipped.fill(beam, with: .color(StorybookArt.color(hex, alpha: 0.24)))
            }
        }

        let claspCenter = CGPoint(x: c.x, y: c.y - FGeo.compactHeight * 0.34 - 8)
        let claspHaloR: CGFloat = night ? 42 : 30
        g.fill(
            Path(ellipseIn: CGRect(x: claspCenter.x - claspHaloR, y: claspCenter.y - claspHaloR, width: claspHaloR * 2, height: claspHaloR * 2)),
            with: .radialGradient(
                Gradient(colors: [StorybookArt.color(0xFFF3B0, alpha: night ? 0.65 : 0.35), StorybookArt.color(0xFFF3B0, alpha: 0)]),
                center: claspCenter,
                startRadius: 6,
                endRadius: claspHaloR
            )
        )
        StorybookArt.fillAndStroke(g, heartPath(center: claspCenter, size: 42), fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xDF9E2C), width: 3)
        StorybookArt.fillAndStroke(
            g,
            heartPath(center: claspCenter, size: 28),
            fill: night ? StorybookArt.color(0x7862B8) : Theme.pink,
            stroke: StorybookArt.outline(for: night ? 0x523E92 : 0xDF669A),
            width: 2
        )
        if night {
            var moon = Path(ellipseIn: CGRect(x: claspCenter.x - 6, y: claspCenter.y - 6, width: 12, height: 12))
            moon.addEllipse(in: CGRect(x: claspCenter.x - 2, y: claspCenter.y - 8, width: 11, height: 11))
            g.fill(moon, with: .color(Theme.lemon), style: FillStyle(eoFill: true))
        } else {
            StorybookArt.sparkle(g, at: claspCenter, radius: 7, color: .white)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: claspCenter.x + 20, y: claspCenter.y - 12), radius: 8 + CGFloat(sin(t * 4)) * 2, color: .white)

        let pearls: [CGPoint] = [
            CGPoint(x: c.x - 245, y: c.y - 238),
            CGPoint(x: c.x - 356, y: c.y - 146),
            CGPoint(x: c.x - 364, y: c.y + 18),
            CGPoint(x: c.x - 240, y: c.y + 162),
            CGPoint(x: c.x + 245, y: c.y - 238),
            CGPoint(x: c.x + 356, y: c.y - 146),
            CGPoint(x: c.x + 364, y: c.y + 18),
            CGPoint(x: c.x + 240, y: c.y + 162),
        ]
        for pt in pearls {
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14)), fill: .white, stroke: StorybookArt.color(0xE8B84E), width: 2.2)
        }
    }

    private static func drawCompactSpot(
        _ g: GraphicsContext,
        spot: CompactSpot,
        sim: FairiesSim,
        highlighted: Bool,
        hovered: Bool
    ) {
        let t = sim.time
        let seatedActors = sim.compactActors.filter { isActorRenderedInsideSpot($0, spot: spot, sim: sim) }
        let reactLeft = max(0, (sim.compactSpotReactUntil[spot] ?? -10) - t)
        let react = reactLeft > 0 ? CGFloat(sin(min(1, reactLeft / 0.65) * .pi)) : 0

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
            drawCloudBedSpot(g, center: spot.center, actors: seatedActors, sim: sim, time: t, react: react)
        case .rainbowSwing:
            drawRainbowSwingSpot(g, center: spot.center, actor: seatedActors.first, sim: sim, time: t, react: react)
        case .teacupBath:
            drawTeacupBathSpot(g, center: spot.center, actor: seatedActors.first, sim: sim, time: t, react: react)
        case .danceStage:
            drawDanceStageSpot(g, center: spot.center, sim: sim, time: t)
        case .treatTable:
            drawTreatTableSpot(g, center: spot.center, actors: seatedActors, sim: sim, time: t, react: react)
        }
    }

    private static func drawSelectionHaloIfNeeded(_ g: GraphicsContext, at point: CGPoint, fairy: FairyKind, sim: FairiesSim, time t: Double) {
        if sim.selectedFairy == fairy {
            let r: CGFloat = 50 + CGFloat(sin(t * 4.5)) * 3
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
        actors: [CompactFairyActor],
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        let bounce = CGFloat(sin(t * 2.2)) * 2.5 - react * 7
        StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: center.x - 56, y: center.y - 48, width: 112, height: 68), cornerRadius: 34), fill: StorybookArt.color(0xFFE9A8), stroke: StorybookArt.outline(for: 0xE6AD42), width: 3.2)
        StorybookArt.sparkle(g, at: CGPoint(x: center.x, y: center.y - 34), radius: 10, color: .white)

        let cloudOutline = StorybookArt.outline(for: 0xB8DCFF)
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-52, 8, 28), (-22, -4, 30), (22, -4, 30), (52, 8, 28), (0, 14, 34)]
        for (dx, dy, r) in puffs {
            g.stroke(Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)), with: .color(cloudOutline), lineWidth: 6)
        }
        for (dx, dy, r) in puffs {
            g.fill(Path(ellipseIn: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2)), with: .color(StorybookArt.color(0xF7FCFF)))
        }

        for actor in actors {
            let pos = CGPoint(x: actor.position.x, y: actor.position.y + bounce)
            drawSelectionHaloIfNeeded(g, at: pos, fairy: actor.kind, sim: sim, time: t)
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            drawFairy(fc, kind: actor.kind, mood: react > 0.2 ? .giggle : .sleepy, accessory: sim.accessories[actor.kind], wingDesign: sim.wingDesigns[actor.kind], transform: sim.activeTransforms[actor.kind]?.kind, time: t, scale: 0.94, blinkSeed: actor.bobPhase)
        }

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
        actor: CompactFairyActor?,
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        let archCenter = CGPoint(x: center.x, y: center.y + 48)
        let archBands: [(CGFloat, UInt32)] = [(96, 0xFF9AC8), (86, 0xFFE28A), (76, 0x9EE8D0), (66, 0xA4D4FF)]
        for (r, hex) in archBands {
            var arc = Path()
            arc.addArc(center: archCenter, radius: r, startAngle: .degrees(196), endAngle: .degrees(344), clockwise: false)
            g.stroke(arc, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        }

        let baseAmp: Double = actor != nil ? 0.22 : 0.06
        let swingAmp: Double = baseAmp + Double(sim.swingEnergy) * 0.4 + Double(react) * 0.12
        let swingAngle = sin(sim.swingPhase) * swingAmp
        let pivot = CGPoint(x: center.x, y: center.y - 36)

        var sw = g
        sw.translateBy(x: pivot.x, y: pivot.y)
        sw.rotate(by: .radians(swingAngle))

        for rx in [-28.0, 28.0] as [CGFloat] {
            var rope = Path()
            rope.move(to: CGPoint(x: rx * 0.72, y: 0))
            rope.addLine(to: CGPoint(x: rx, y: 66))
            sw.stroke(rope, with: .color(StorybookArt.color(0xE6B046)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }

        if let actor {
            let fairyLocal = CGPoint(x: 0, y: 42)
            drawSelectionHaloIfNeeded(sw, at: fairyLocal, fairy: actor.kind, sim: sim, time: t)
            var fc = sw
            fc.translateBy(x: fairyLocal.x, y: fairyLocal.y)
            drawFairy(fc, kind: actor.kind, mood: .giggle, accessory: sim.accessories[actor.kind], wingDesign: sim.wingDesigns[actor.kind], transform: sim.activeTransforms[actor.kind]?.kind, time: t, scale: 0.94, blinkSeed: actor.bobPhase)
        }

        StorybookArt.fillAndStroke(sw, Path(roundedRect: CGRect(x: -40, y: 60, width: 80, height: 18), cornerRadius: 9), fill: StorybookArt.color(0xFFB5D6), stroke: StorybookArt.outline(for: 0xEB84B4), width: 3)
        drawTinyFlower(sw, at: CGPoint(x: -32, y: 62), radius: 9, petalHex: 0xFFE38A)
        drawTinyFlower(sw, at: CGPoint(x: 32, y: 62), radius: 9, petalHex: 0xFFE38A)
    }

    private static func drawTeacupBathSpot(
        _ g: GraphicsContext,
        center: CGPoint,
        actor: CompactFairyActor?,
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        let cupOutline = StorybookArt.outline(for: 0x90CCF0)
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x - 74, y: center.y + 30, width: 148, height: 24)), fill: StorybookArt.color(0xFFF7FA), stroke: cupOutline, width: 3.2)

        let handle = Path(ellipseIn: CGRect(x: center.x - 78, y: center.y - 12, width: 34, height: 34))
        g.stroke(handle, with: .color(cupOutline), lineWidth: 10)
        g.stroke(handle, with: .color(StorybookArt.color(0xD8F2FF)), lineWidth: 5)

        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x - 58, y: center.y - 26, width: 116, height: 26)), fill: StorybookArt.color(0xA6E6FF), stroke: cupOutline, width: 3)

        if let actor {
            let bob = CGFloat(sin(t * 3.4 + actor.bobPhase)) * 3 - react * 10
            let pos = CGPoint(x: center.x, y: center.y - 24 + bob)
            drawSelectionHaloIfNeeded(g, at: pos, fairy: actor.kind, sim: sim, time: t)
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            drawFairy(fc, kind: actor.kind, mood: react > 0.2 ? .giggle : .happy, accessory: sim.accessories[actor.kind], wingDesign: sim.wingDesigns[actor.kind], transform: sim.activeTransforms[actor.kind]?.kind, time: t, scale: 0.94, blinkSeed: actor.bobPhase)
        }

        var cup = Path()
        cup.move(to: CGPoint(x: center.x - 58, y: center.y - 12))
        cup.addCurve(to: CGPoint(x: center.x - 38, y: center.y + 38), control1: CGPoint(x: center.x - 56, y: center.y + 18), control2: CGPoint(x: center.x - 48, y: center.y + 34))
        cup.addLine(to: CGPoint(x: center.x + 38, y: center.y + 38))
        cup.addCurve(to: CGPoint(x: center.x + 58, y: center.y - 12), control1: CGPoint(x: center.x + 48, y: center.y + 34), control2: CGPoint(x: center.x + 56, y: center.y + 18))
        cup.closeSubpath()
        g.fill(cup, with: .linearGradient(Gradient(colors: [StorybookArt.color(0xE8F8FF), StorybookArt.color(0xBCE8FF)]), startPoint: CGPoint(x: center.x - 30, y: center.y - 12), endPoint: CGPoint(x: center.x + 30, y: center.y + 38)))
        g.stroke(cup, with: .color(cupOutline), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
        StorybookArt.heart(g, at: CGPoint(x: center.x, y: center.y + 14), size: 22, color: Theme.pink)

        let foam: [(CGFloat, CGFloat, CGFloat)] = [(-42, -12, 16), (-22, -16, 17), (0, -14, 18), (22, -16, 17), (42, -12, 15)]
        for (dx, dy, r) in foam {
            let fy = center.y + dy + CGFloat(sin(t * 4 + Double(dx))) * 2 - react * 4
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x + dx - r, y: fy - r, width: r * 2, height: r * 2)), fill: .white, stroke: StorybookArt.color(0xBEE8FF), width: 2.2)
        }
    }

    private static func drawDanceStageSpot(_ g: GraphicsContext, center: CGPoint, sim: FairiesSim, time t: Double) {
        let partyActive = sim.discoPartyTimer > 0
        let pulse = partyActive ? CGFloat(0.6 + 0.4 * sin(t * 9)) : 0

        if partyActive {
            let glowR: CGFloat = 94 + pulse * 14
            g.fill(
                Path(ellipseIn: CGRect(x: center.x - glowR, y: center.y - glowR * 0.42 + 14, width: glowR * 2, height: glowR * 0.84)),
                with: .radialGradient(Gradient(colors: [StorybookArt.color(0xFFE38A, alpha: 0.55), StorybookArt.color(0xFF9AC8, alpha: 0)]), center: CGPoint(x: center.x, y: center.y + 16), startRadius: 12, endRadius: glowR)
            )
        }

        let goldOutline = StorybookArt.outline(for: 0xE6A93B)
        StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: center.x - 74, y: center.y + 18, width: 148, height: 30), cornerRadius: 15), fill: StorybookArt.color(partyActive ? 0xFFF099 : 0xFFE48E), stroke: goldOutline, width: 3.4)

        var kc = g
        kc.translateBy(x: center.x + 80, y: center.y + 33)
        kc.rotate(by: .radians(partyActive ? t * 5.0 : 0.2))
        StorybookArt.fillAndStroke(kc, Path(ellipseIn: CGRect(x: -5, y: -11, width: 14, height: 22)), fill: Theme.lemon, stroke: goldOutline, width: 2.4)

        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x - 74, y: center.y + 4, width: 148, height: 28)), fill: StorybookArt.color(0xFFF6D6), stroke: goldOutline, width: 3.2)
        g.fill(Path(ellipseIn: CGRect(x: center.x - 46, y: center.y + 10, width: 92, height: 16)), with: .color(StorybookArt.color(partyActive ? 0xFF8FB8 : 0xFFB8DC, alpha: partyActive ? 0.72 : 0.5)))

        for sx in [-44.0, 0.0, 44.0] as [CGFloat] {
            StorybookArt.sparkle(g, at: CGPoint(x: center.x + sx, y: center.y + 36), radius: 7 + pulse * 2.5, color: .white)
        }
    }

    private static func drawTreatTableSpot(
        _ g: GraphicsContext,
        center: CGPoint,
        actors: [CompactFairyActor],
        sim: FairiesSim,
        time t: Double,
        react: CGFloat
    ) {
        for actor in actors {
            let nibbleBob = CGFloat(sin(t * 5.2 + actor.bobPhase)) * 3.5 - react * 10
            let pos = CGPoint(x: actor.position.x, y: actor.position.y + nibbleBob)
            drawSelectionHaloIfNeeded(g, at: pos, fairy: actor.kind, sim: sim, time: t)
            var fc = g
            fc.translateBy(x: pos.x, y: pos.y)
            drawFairy(fc, kind: actor.kind, mood: react > 0.2 ? .giggle : .yum, accessory: sim.accessories[actor.kind], wingDesign: sim.wingDesigns[actor.kind], transform: sim.activeTransforms[actor.kind]?.kind, time: t, scale: 0.94, blinkSeed: actor.bobPhase)
        }

        let tableOutline = StorybookArt.outline(for: 0xF0ACC6)
        StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: center.x - 16, y: center.y + 18, width: 32, height: 34), cornerRadius: 10), fill: StorybookArt.color(0xFFEAF2), stroke: tableOutline, width: 3)
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x - 72, y: center.y - 4, width: 144, height: 38)), fill: StorybookArt.color(0xFFF9FC), stroke: tableOutline, width: 3.4)

        let hasFreshTreats = !sim.compactTableTreats.isEmpty
        let macColors: [UInt32] = hasFreshTreats ? [0xFF9AC6, 0x9FE3CF, 0xFFE38A, 0xD2A8FF] : [0xFF9AC6, 0x9FE3CF, 0xFFE38A]
        for (i, hex) in macColors.enumerated() {
            let my = center.y + 8 - CGFloat(i) * 10
            let mx = center.x - 30
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: mx - 16, y: my - 6, width: 32, height: 11), cornerRadius: 5.5), fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.2)
            g.fill(Path(CGRect(x: mx - 14, y: my - 1, width: 28, height: 2.6)), with: .color(.white.opacity(0.9)))
        }

        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x - 2, y: center.y + 4, width: 58, height: 20)), fill: .white, stroke: StorybookArt.color(0xB8DCFF), width: 2.4)
        drawBungeoppang(g, at: CGPoint(x: center.x + 26, y: center.y + 8), scale: hasFreshTreats ? 1.12 : 1.0)
        if hasFreshTreats {
            StorybookArt.heart(g, at: CGPoint(x: center.x + 26, y: center.y - 12 + CGFloat(sin(t * 5)) * 4), size: 12, color: Theme.pink, opacity: 0.85)
        }

        if sim.hasHanbokTea {
            drawHanbokTeaSet(g, center: center, pouring: sim.teaPourTimer > 0, time: t)
        }
    }

    private static func drawBungeoppang(_ g: GraphicsContext, at center: CGPoint, scale: CGFloat) {
        var c = g
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: scale, y: scale)

        let pastry = StorybookArt.color(0xF5BE5C)
        let crust = StorybookArt.outline(for: 0xD68C2E)

        var tail = Path()
        tail.move(to: CGPoint(x: 11, y: 0))
        tail.addLine(to: CGPoint(x: 24, y: -9))
        tail.addQuadCurve(to: CGPoint(x: 24, y: 9), control: CGPoint(x: 19, y: 0))
        tail.closeSubpath()
        StorybookArt.fillAndStroke(c, tail, fill: pastry, stroke: crust, width: 2.2)

        StorybookArt.fillAndStroke(c, Path(ellipseIn: CGRect(x: -18, y: -11, width: 32, height: 22)), fill: pastry, stroke: crust, width: 2.4)
        StorybookArt.highlight(c, in: CGRect(x: -11, y: -7, width: 12, height: 5), opacity: 0.48)

        for sx in [-1.0, 5.0] as [CGFloat] {
            var scaleArc = Path()
            scaleArc.addArc(center: CGPoint(x: sx, y: 0), radius: 5, startAngle: .degrees(-65), endAngle: .degrees(65), clockwise: false)
            c.stroke(scaleArc, with: .color(crust.opacity(0.65)), lineWidth: 1.6)
        }
        c.fill(Path(ellipseIn: CGRect(x: -12, y: -3, width: 3.6, height: 3.6)), with: .color(crust))
        c.fill(Path(ellipseIn: CGRect(x: -10, y: 1.5, width: 4.5, height: 2.8)), with: .color(StorybookArt.color(0xFF94B4, alpha: 0.65)))
        var smile = Path()
        smile.move(to: CGPoint(x: -15.5, y: 2.5))
        smile.addQuadCurve(to: CGPoint(x: -11.5, y: 3.5), control: CGPoint(x: -13.5, y: 5.5))
        c.stroke(smile, with: .color(crust), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private static func drawCompactChandelier(_ g: GraphicsContext, anchor: CGPoint, isNightMode: Bool, time t: Double) {
        let sway = sin(t * 1.45) * 0.055
        let goldHex: UInt32 = 0xFFD966
        let goldOutline = StorybookArt.outline(for: 0xE6A93B)

        var c = g
        c.translateBy(x: anchor.x, y: anchor.y)
        c.rotate(by: .radians(sway))

        let pulse = 0.88 + 0.12 * sin(t * 3.1)
        let haloW: CGFloat = isNightMode ? 240 : 176
        let haloH: CGFloat = isNightMode ? 156 : 112
        c.fill(
            Path(ellipseIn: CGRect(x: -haloW * 0.5, y: 0, width: haloW, height: haloH)),
            with: .radialGradient(
                Gradient(colors: [
                    StorybookArt.color(0xFFF6C4, alpha: (isNightMode ? 0.82 : 0.52) * pulse),
                    StorybookArt.color(0xFFD6EE, alpha: (isNightMode ? 0.42 : 0.24) * pulse),
                    StorybookArt.color(0xFFD6EE, alpha: 0),
                ]),
                center: CGPoint(x: 0, y: 52),
                startRadius: 8,
                endRadius: haloW * 0.5
            )
        )

        var chain = Path()
        chain.move(to: .zero)
        chain.addLine(to: CGPoint(x: 0, y: 36))
        c.stroke(chain, with: .color(goldOutline), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        c.stroke(chain, with: .color(StorybookArt.color(goldHex)), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))

        for side in [-1.0, 1.0] as [CGFloat] {
            for (reach, drop) in [(50.0, 26.0), (26.0, 32.0)] as [(CGFloat, CGFloat)] {
                var arm = Path()
                arm.move(to: CGPoint(x: 0, y: 24))
                arm.addCurve(to: CGPoint(x: side * reach, y: drop), control1: CGPoint(x: side * reach * 0.35, y: 46), control2: CGPoint(x: side * reach * 0.88, y: 44))
                c.stroke(arm, with: .color(goldOutline), style: StrokeStyle(lineWidth: 5.2, lineCap: .round))
                c.stroke(arm, with: .color(StorybookArt.color(goldHex)), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))

                let tip = CGPoint(x: side * reach, y: drop - 6)
                StorybookArt.fillAndStroke(c, Path(roundedRect: CGRect(x: tip.x - 6, y: drop - 2, width: 12, height: 6), cornerRadius: 3), fill: StorybookArt.color(goldHex), stroke: goldOutline, width: 1.6)
                let orb = Path(ellipseIn: CGRect(x: tip.x - 5.5, y: tip.y - 7.5, width: 11, height: 13))
                c.fill(orb, with: .radialGradient(Gradient(colors: [.white, StorybookArt.color(0xFFE884)]), center: CGPoint(x: tip.x, y: tip.y - 2), startRadius: 1, endRadius: 8))
                c.stroke(orb, with: .color(StorybookArt.color(0xF0B848, alpha: 0.7)), lineWidth: 1.4)

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

        let heartCenter = CGPoint(x: 0, y: 50)
        StorybookArt.fillAndStroke(c, heartPath(center: heartCenter, size: 30), fill: StorybookArt.color(goldHex), stroke: goldOutline, width: 2.2)
        StorybookArt.fillAndStroke(c, heartPath(center: heartCenter, size: 22), fill: StorybookArt.color(0xFF88BE), stroke: StorybookArt.outline(for: 0xE65C98), width: 1.8)
        StorybookArt.highlight(c, in: CGRect(x: -6, y: 42, width: 6, height: 4), opacity: 0.88)
        StorybookArt.sparkle(c, at: CGPoint(x: -36, y: 12), radius: 6.5 * CGFloat(pulse), color: .white, opacity: 0.92)
        StorybookArt.sparkle(c, at: CGPoint(x: 38, y: 16), radius: 6.0 * CGFloat(pulse), color: Theme.lemon, opacity: 0.92)
    }

    private static func drawCompactCarousel(_ g: GraphicsContext, center: CGPoint, sim: FairiesSim, time t: Double) {
        let goldHex: UInt32 = 0xFFD966
        let goldOutline = StorybookArt.outline(for: 0xE6A93B)
        let pinkOutline = StorybookArt.outline(for: 0xF08CB8)

        g.fill(Path(ellipseIn: CGRect(x: center.x - 42, y: center.y - 4, width: 84, height: 16)), with: .color(Theme.ink.opacity(0.12)))
        StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: center.x - 38, y: center.y - 12, width: 76, height: 14), cornerRadius: 7), fill: StorybookArt.color(0xFFE09E), stroke: goldOutline, width: 2.4)
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x - 38, y: center.y - 18, width: 76, height: 14)), fill: StorybookArt.color(0xFFF6FA), stroke: pinkOutline, width: 2.2)

        struct Seat {
            let index: Int
            let x: CGFloat
            let depth: CGFloat
            let y: CGFloat
        }
        let spin = sim.carouselSpinAngle
        let seats: [Seat] = (0..<4).map { i in
            let a = spin + Double(i) * (.pi / 2)
            let depth = CGFloat(sin(a))
            let x = center.x + CGFloat(cos(a)) * 27
            let bob = CGFloat(sin(t * 3.2 + Double(i) * 1.57)) * 4.5
            let y = center.y - 31 + depth * 5 + bob
            return Seat(index: i, x: x, depth: depth, y: y)
        }.sorted { $0.depth < $1.depth }

        let riders = sim.compactActors.filter { $0.ridingCarousel && sim.draggingCompactFairy != $0.kind }

        func drawSeat(_ s: Seat) {
            let scale = 0.82 + (s.depth + 1) * 0.14
            var rod = Path()
            rod.move(to: CGPoint(x: s.x, y: center.y - 60))
            rod.addLine(to: CGPoint(x: s.x, y: center.y - 11 + s.depth * 3))
            g.stroke(rod, with: .color(StorybookArt.color(0xF0C052, alpha: 0.85)), lineWidth: 2.2)

            if let rider = riders.first(where: { $0.carouselSeatIndex == s.index }) {
                var rc = g
                rc.translateBy(x: s.x, y: s.y - 12)
                drawFairy(rc, kind: rider.kind, mood: .giggle, accessory: sim.accessories[rider.kind], wingDesign: sim.wingDesigns[rider.kind], transform: sim.activeTransforms[rider.kind]?.kind, time: t, scale: 0.68 * scale, blinkSeed: rider.bobPhase)
            }

            var sc = g
            sc.translateBy(x: s.x, y: s.y)
            sc.scaleBy(x: scale, y: scale)
            if s.index.isMultiple(of: 2) {
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: -12, y: -5, width: 12, height: 10))
                cloud.addEllipse(in: CGRect(x: -6, y: -9, width: 13, height: 12))
                cloud.addEllipse(in: CGRect(x: 1, y: -5, width: 11, height: 10))
                StorybookArt.fillAndStroke(sc, cloud, fill: .white, stroke: StorybookArt.outline(for: 0xB8DCFF), width: 1.8)
            } else {
                let star = fiveStarPath(center: .zero, outer: 10, inner: 5)
                let hex: UInt32 = s.index == 1 ? 0xFFE38A : 0xD8C2FF
                StorybookArt.fillAndStroke(sc, star, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 1.8)
            }
        }

        for s in seats where s.depth < 0 { drawSeat(s) }
        StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: center.x - 4, y: center.y - 68, width: 8, height: 56), cornerRadius: 4), fill: StorybookArt.color(goldHex), stroke: goldOutline, width: 2.0)
        for s in seats where s.depth >= 0 { drawSeat(s) }

        let apex = CGPoint(x: center.x, y: center.y - 84)
        let canopyY = center.y - 56
        var tent = Path()
        tent.move(to: CGPoint(x: center.x - 40, y: canopyY))
        tent.addQuadCurve(to: apex, control: CGPoint(x: center.x - 24, y: center.y - 76))
        tent.addQuadCurve(to: CGPoint(x: center.x + 40, y: canopyY), control: CGPoint(x: center.x + 24, y: center.y - 76))
        tent.closeSubpath()
        StorybookArt.fillAndStroke(g, tent, fill: StorybookArt.color(0xFFB5D8), stroke: pinkOutline, width: 2.6)

        var stripe = Path()
        stripe.move(to: apex)
        stripe.addLine(to: CGPoint(x: center.x - 15, y: canopyY))
        stripe.addLine(to: CGPoint(x: center.x + 15, y: canopyY))
        stripe.closeSubpath()
        g.fill(stripe, with: .color(StorybookArt.color(0xFFFDF5, alpha: 0.92)))

        for k in 0..<5 {
            let sx = center.x - 32 + CGFloat(k) * 16
            let hex: UInt32 = k.isMultiple(of: 2) ? 0xFFE38A : 0xFFA6D2
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: sx - 9, y: canopyY - 6, width: 18, height: 12)), fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 1.8)
        }
        StorybookArt.sparkle(g, at: CGPoint(x: apex.x, y: apex.y - 7), radius: 10 + CGFloat(sin(t * 4)) * 1.5, color: Theme.lemon, opacity: 0.98)
    }

    private static func drawHanbokTeaSet(_ g: GraphicsContext, center: CGPoint, pouring: Bool, time t: Double) {
        let jadeHex: UInt32 = 0x90DCC4
        let jadeLight: UInt32 = 0xC8F4E6
        let jadeOutline = StorybookArt.outline(for: 0x52B096)
        let potC = CGPoint(x: center.x - 3, y: center.y - 1)
        let cupC = CGPoint(x: center.x - 44, y: center.y + 18)

        if pouring {
            var pourArc = Path()
            pourArc.move(to: CGPoint(x: potC.x - 24, y: potC.y - 11))
            pourArc.addQuadCurve(to: CGPoint(x: cupC.x, y: cupC.y - 5), control: CGPoint(x: cupC.x + 2, y: potC.y - 8))
            g.stroke(pourArc, with: .color(StorybookArt.color(0xD8F2A6, alpha: 0.92)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            g.stroke(pourArc, with: .color(.white.opacity(0.68)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }

        var potCtx = g
        if pouring {
            potCtx.translateBy(x: potC.x, y: potC.y - 6)
            potCtx.rotate(by: .radians(-0.28 + sin(t * 8) * 0.04))
            potCtx.translateBy(x: -potC.x, y: -(potC.y - 6))
        }

        var spout = Path()
        spout.move(to: CGPoint(x: potC.x - 10, y: potC.y + 1))
        spout.addQuadCurve(to: CGPoint(x: potC.x - 21, y: potC.y - 9), control: CGPoint(x: potC.x - 20, y: potC.y + 1))
        potCtx.stroke(spout, with: .color(jadeOutline), style: StrokeStyle(lineWidth: 7.2, lineCap: .round))
        potCtx.stroke(spout, with: .color(StorybookArt.color(jadeHex)), style: StrokeStyle(lineWidth: 4.0, lineCap: .round))

        let handle = Path(ellipseIn: CGRect(x: potC.x + 8, y: potC.y - 10, width: 14, height: 16))
        potCtx.stroke(handle, with: .color(jadeOutline), lineWidth: 5.5)
        potCtx.stroke(handle, with: .color(StorybookArt.color(jadeHex)), lineWidth: 2.8)

        let potBody = Path(ellipseIn: CGRect(x: potC.x - 14, y: potC.y - 11, width: 28, height: 22))
        potCtx.fill(potBody, with: .radialGradient(Gradient(colors: [StorybookArt.color(jadeLight), StorybookArt.color(jadeHex)]), center: CGPoint(x: potC.x - 4, y: potC.y - 5), startRadius: 2, endRadius: 16))
        potCtx.stroke(potBody, with: .color(jadeOutline), lineWidth: 2.2)

        StorybookArt.fillAndStroke(potCtx, Path(ellipseIn: CGRect(x: potC.x - 9, y: potC.y - 15, width: 18, height: 8)), fill: StorybookArt.color(jadeLight), stroke: jadeOutline, width: 1.8)
        StorybookArt.fillAndStroke(potCtx, Path(ellipseIn: CGRect(x: potC.x - 3.5, y: potC.y - 19, width: 7, height: 6)), fill: StorybookArt.color(0xFFE68A), stroke: StorybookArt.outline(for: 0xE0A838), width: 1.4)
        drawTinyFlower(potCtx, at: CGPoint(x: potC.x, y: potC.y + 1), radius: 5.5, petalHex: 0xFFFFFF)

        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: cupC.x - 12, y: cupC.y + 2, width: 24, height: 8)), fill: StorybookArt.color(jadeLight), stroke: jadeOutline, width: 1.6)
        var cup = Path()
        cup.move(to: CGPoint(x: cupC.x - 8, y: cupC.y - 5))
        cup.addQuadCurve(to: CGPoint(x: cupC.x - 5, y: cupC.y + 5), control: CGPoint(x: cupC.x - 8, y: cupC.y + 4))
        cup.addLine(to: CGPoint(x: cupC.x + 5, y: cupC.y + 5))
        cup.addQuadCurve(to: CGPoint(x: cupC.x + 8, y: cupC.y - 5), control: CGPoint(x: cupC.x + 8, y: cupC.y + 4))
        cup.closeSubpath()
        StorybookArt.fillAndStroke(g, cup, fill: StorybookArt.color(jadeHex), stroke: jadeOutline, width: 1.8)
        g.fill(Path(ellipseIn: CGRect(x: cupC.x - 7, y: cupC.y - 7, width: 14, height: 4.5)), with: .color(StorybookArt.color(0xD8F2A6)))
    }

    // MARK: - 12 Original Chibi Fairies

    static func drawFairy(
        _ g: GraphicsContext,
        kind: FairyKind,
        mood: FairyMood,
        accessory: FairyAccessory?,
        wingDesign: FairyWingDesign? = nil,
        transform: TeaTransformKind? = nil,
        time t: Double,
        scale: CGFloat = 1,
        blinkSeed: Double = 0
    ) {
        let effectiveScale = transform == .tinyShrink ? scale * 0.72 : scale
        var c = g
        c.scaleBy(x: effectiveScale, y: effectiveScale)

        let p = kind.palette
        if transform == .glow {
            let auraR: CGFloat = 58 + CGFloat(sin(t * 5.2)) * 5
            c.fill(
                Path(ellipseIn: CGRect(x: -auraR, y: -auraR, width: auraR * 2, height: auraR * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        StorybookArt.color(0xFFF4A8, alpha: 0.85),
                        StorybookArt.color(0xFFE07D, alpha: 0.35),
                        StorybookArt.color(0xFFE07D, alpha: 0),
                    ]),
                    center: .zero,
                    startRadius: 8,
                    endRadius: auraR
                )
            )
        } else if transform == .floatingBubbles {
            for k in 0..<3 {
                let a = t * 2.2 + Double(k) * 2.09
                drawBubble(c, at: CGPoint(x: CGFloat(cos(a)) * 42, y: CGFloat(sin(a)) * 30 - 12), radius: 8, alpha: 0.9)
            }
        }

        let flutterSpeed = mood == .sleepy ? 3.5 : (transform == .tinyShrink ? 18.0 : 13.0)
        let flutter = CGFloat(sin(t * flutterSpeed + blinkSeed)) * (mood == .sleepy ? 0.25 : 0.9)

        FairyWingPainter.drawWings(
            c,
            wingCenter: CGPoint(x: 0, y: 10),
            wingHalfSpan: CGSize(width: 46, height: 34),
            baseHex: p.wing,
            innerHex: p.wingInner,
            outlineHex: p.dressAccent,
            design: wingDesign,
            flap: flutter,
            time: t,
            showVeins: true
        )

        drawBackHair(c, kind: kind, palette: p)
        drawDressAndArms(c, kind: kind, palette: p, mood: mood, time: t)
        drawHeadAndFace(c, kind: kind, palette: p, mood: mood, time: t, blinkSeed: blinkSeed)
        drawFairyEmblem(c, kind: kind, palette: p)

        if let accessory {
            FairyWingPainter.drawAccessoryOnHead(c, accessoryID: accessory.rawValue)
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
                tail.addCurve(to: CGPoint(x: side * 34, y: 18), control1: CGPoint(x: side * 38, y: -14), control2: CGPoint(x: side * 42, y: 6))
                tail.addCurve(to: CGPoint(x: side * 16, y: 4), control1: CGPoint(x: side * 26, y: 22), control2: CGPoint(x: side * 18, y: 14))
                tail.closeSubpath()
                StorybookArt.fillAndStroke(g, tail, fill: fill, stroke: outline, width: 2.6)
            }
        case .curls:
            for (dx, dy, r) in [(-24.0, -4.0, 14.0), (24.0, -4.0, 14.0), (-20.0, 10.0, 13.0), (20.0, 10.0, 13.0), (0.0, 8.0, 16.0)] as [(CGFloat, CGFloat, CGFloat)] {
                StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: dx - r, y: dy - r, width: r * 2, height: r * 2)), fill: fill, stroke: outline, width: 2.4)
            }
        case .bob:
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -29, y: -24, width: 58, height: 42), cornerRadius: 20), fill: fill, stroke: outline, width: 2.6)
        case .braidCrown:
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -28, y: -24, width: 56, height: 38)), fill: shade, stroke: outline, width: 2.6)
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

        for sx in [-8.0, 8.0] as [CGFloat] {
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: sx - 5.5, y: 31, width: 11, height: 8)), fill: StorybookArt.color(p.dressAccent), stroke: dressOutline, width: 2)
        }

        let armLift: CGFloat = (mood == .celebrate || mood == .giggle) ? -10 - CGFloat(sin(t * 10)) * 3 : (mood == .yum ? -5 : 4)
        for side in [-1.0, 1.0] as [CGFloat] {
            var arm = Path()
            arm.move(to: CGPoint(x: side * 11, y: 12))
            arm.addQuadCurve(to: CGPoint(x: side * 21, y: 16 + armLift), control: CGPoint(x: side * 18, y: 10 + armLift * 0.5))
            g.stroke(arm, with: .color(skinOutline), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
            g.stroke(arm, with: .color(skin), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }

        if kind == .silk {
            var chima = Path()
            chima.move(to: CGPoint(x: -11, y: 12))
            chima.addCurve(to: CGPoint(x: -24, y: 34), control1: CGPoint(x: -22, y: 16), control2: CGPoint(x: -26, y: 28))
            chima.addQuadCurve(to: CGPoint(x: 24, y: 34), control: CGPoint(x: 0, y: 40))
            chima.addCurve(to: CGPoint(x: 11, y: 12), control1: CGPoint(x: 26, y: 28), control2: CGPoint(x: 22, y: 16))
            chima.closeSubpath()
            StorybookArt.fillAndStroke(g, chima, fill: dressFill, stroke: StorybookArt.outline(for: 0xEB8DA0), width: 2.6)

            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -13, y: 6, width: 26, height: 12), cornerRadius: 6), fill: StorybookArt.color(p.dressAccent), stroke: StorybookArt.outline(for: 0x6EC7A6), width: 2.2)
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

        var skirt = Path()
        skirt.move(to: CGPoint(x: -10, y: 8))
        skirt.addCurve(to: CGPoint(x: -23, y: 33), control1: CGPoint(x: -18, y: 15), control2: CGPoint(x: -24, y: 26))
        skirt.addQuadCurve(to: CGPoint(x: 0, y: 36), control: CGPoint(x: -12, y: 39))
        skirt.addQuadCurve(to: CGPoint(x: 23, y: 33), control: CGPoint(x: 12, y: 39))
        skirt.addCurve(to: CGPoint(x: 10, y: 8), control1: CGPoint(x: 24, y: 26), control2: CGPoint(x: 18, y: 15))
        skirt.closeSubpath()
        StorybookArt.fillAndStroke(g, skirt, fill: dressFill, stroke: dressOutline, width: 2.6)

        if kind == .honey {
            g.fill(Path(CGRect(x: -17, y: 21, width: 34, height: 5)), with: .color(StorybookArt.color(p.dressAccent, alpha: 0.78)))
        }
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -12, y: 6, width: 24, height: 9)), fill: .white, stroke: dressOutline, width: 2)
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -4.5, y: 10, width: 9, height: 9)), fill: StorybookArt.color(p.emblem), stroke: .white, width: 1.8)
    }

    private static func drawHeadAndFace(
        _ g: GraphicsContext,
        kind: FairyKind,
        palette p: FairyPalette,
        mood: FairyMood,
        time t: Double,
        blinkSeed: Double
    ) {
        let skinOutline = StorybookArt.outline(for: 0xE6B098)
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -24, y: -33, width: 48, height: 42)), fill: StorybookArt.color(p.skin), stroke: skinOutline, width: 2.6)

        var bangs = Path()
        bangs.move(to: CGPoint(x: -25, y: -12))
        bangs.addCurve(to: CGPoint(x: 0, y: -37), control1: CGPoint(x: -27, y: -30), control2: CGPoint(x: -14, y: -38))
        bangs.addCurve(to: CGPoint(x: 25, y: -12), control1: CGPoint(x: 14, y: -38), control2: CGPoint(x: 27, y: -30))
        bangs.addQuadCurve(to: CGPoint(x: 12, y: -19), control: CGPoint(x: 19, y: -15))
        bangs.addQuadCurve(to: CGPoint(x: 0, y: -15), control: CGPoint(x: 6, y: -22))
        bangs.addQuadCurve(to: CGPoint(x: -12, y: -19), control: CGPoint(x: -6, y: -22))
        bangs.addQuadCurve(to: CGPoint(x: -25, y: -12), control: CGPoint(x: -19, y: -15))
        bangs.closeSubpath()
        StorybookArt.fillAndStroke(g, bangs, fill: StorybookArt.color(p.hair), stroke: StorybookArt.outline(for: p.hairShade, factor: 0.68), width: 2.6)
        StorybookArt.highlight(g, in: CGRect(x: -14, y: -32, width: 16, height: 6), opacity: 0.52)

        for side in [-1.0, 1.0] as [CGFloat] {
            g.fill(Path(ellipseIn: CGRect(x: side * 13 - 5.5, y: -7, width: 11, height: 6.5)), with: .color(StorybookArt.color(p.cheek, alpha: 0.58)))
        }

        let blinkCycle = (t + blinkSeed * 1.7).truncatingRemainder(dividingBy: 4.4)
        let isBlinking = blinkCycle < 0.14

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
                let eyeOval = Path(ellipseIn: CGRect(x: ex - 5.4, y: ey - 6.4, width: 10.8, height: 12.8))
                g.fill(eyeOval, with: .linearGradient(Gradient(colors: [StorybookArt.color(p.eye), StorybookArt.tint(for: p.eye, amount: 0.36)]), startPoint: CGPoint(x: ex, y: ey - 6), endPoint: CGPoint(x: ex, y: ey + 6)))
                g.stroke(eyeOval, with: .color(Theme.ink), lineWidth: 1.6)
                g.fill(Path(ellipseIn: CGRect(x: ex - 2.6, y: ey - 5.0, width: 4.4, height: 4.4)), with: .color(.white))
                g.fill(Path(ellipseIn: CGRect(x: ex + 0.8, y: ey + 1.2, width: 2.4, height: 2.4)), with: .color(.white.opacity(0.9)))
                if mood == .celebrate || mood == .yum {
                    StorybookArt.sparkle(g, at: CGPoint(x: ex - 0.5, y: ey + 2), radius: 3.4, color: Theme.lemon)
                }
            }
        }

        switch mood {
        case .sleepy:
            g.fill(Path(ellipseIn: CGRect(x: -2.4, y: -2.6, width: 4.8, height: 4.2)), with: .color(StorybookArt.color(0xE87A96)))
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
            StorybookArt.fillAndStroke(g, heartPath(center: top, size: 22), fill: fill, stroke: outline, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: -5, y: top.y - 5, width: 5, height: 3.5), opacity: 0.78)
        case .star:
            StorybookArt.fillAndStroke(g, fiveStarPath(center: top, outer: 13, inner: 6), fill: fill, stroke: outline, width: 2.2)
        case .berry:
            StorybookArt.fillAndStroke(g, heartPath(center: CGPoint(x: 0, y: top.y + 3), size: 20), fill: fill, stroke: outline, width: 2.2)
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
                StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: side < 0 ? -18 : 2, y: top.y - 8, width: 16, height: 14)), fill: fill, stroke: outline, width: 2.2)
            }
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -5.5, y: top.y - 5.5, width: 11, height: 11)), fill: accent, stroke: outline, width: 2)
        case .moon:
            var crescent = Path(ellipseIn: CGRect(x: -11, y: top.y - 11, width: 22, height: 22))
            crescent.addEllipse(in: CGRect(x: -4, y: top.y - 14, width: 20, height: 20))
            g.fill(crescent, with: .color(fill), style: FillStyle(eoFill: true))
            StorybookArt.sparkle(g, at: CGPoint(x: 8, y: top.y - 4), radius: 5, color: .white)
        case .melody:
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -9, y: top.y - 2, width: 10, height: 8)), fill: fill, stroke: outline, width: 2)
            var stem = Path()
            stem.move(to: CGPoint(x: 0, y: top.y + 1))
            stem.addLine(to: CGPoint(x: 0, y: top.y - 14))
            stem.addQuadCurve(to: CGPoint(x: 11, y: top.y - 8), control: CGPoint(x: 9, y: top.y - 15))
            g.stroke(stem, with: .color(outline), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            g.stroke(stem, with: .color(accent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        case .peach:
            StorybookArt.fillAndStroke(g, heartPath(center: CGPoint(x: 0, y: top.y + 2), size: 21), fill: fill, stroke: outline, width: 2.2)
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: 3, y: top.y - 12, width: 10, height: 6)), fill: accent, stroke: StorybookArt.outline(for: 0x62B876), width: 1.8)
        case .dewdrop:
            var drop = Path()
            drop.move(to: CGPoint(x: 0, y: top.y - 12))
            drop.addCurve(to: CGPoint(x: 0, y: top.y + 10), control1: CGPoint(x: 12, y: top.y - 2), control2: CGPoint(x: 12, y: top.y + 10))
            drop.addCurve(to: CGPoint(x: 0, y: top.y - 12), control1: CGPoint(x: -12, y: top.y + 10), control2: CGPoint(x: -12, y: top.y - 2))
            drop.closeSubpath()
            StorybookArt.fillAndStroke(g, drop, fill: fill, stroke: outline, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: -4, y: top.y - 3, width: 4, height: 6), opacity: 0.78)
        case .honey:
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -12, y: top.y - 5, width: 24, height: 11), cornerRadius: 5), fill: fill, stroke: outline, width: 2.2)
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
            var jokduri = Path()
            jokduri.move(to: CGPoint(x: -11, y: top.y + 6))
            jokduri.addLine(to: CGPoint(x: -13, y: top.y - 4))
            jokduri.addQuadCurve(to: CGPoint(x: 13, y: top.y - 4), control: CGPoint(x: 0, y: top.y - 12))
            jokduri.addLine(to: CGPoint(x: 11, y: top.y + 6))
            jokduri.closeSubpath()
            StorybookArt.fillAndStroke(g, jokduri, fill: StorybookArt.color(0x5B527A), stroke: StorybookArt.outline(for: 0x3D3559), width: 2.2)
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -4.5, y: top.y - 4.5, width: 9, height: 9)), fill: fill, stroke: accent, width: 2)
            for sx in [-8.5, 8.5] as [CGFloat] {
                g.fill(Path(ellipseIn: CGRect(x: sx - 2.5, y: top.y - 2, width: 5, height: 5)), with: .color(.white))
            }
        }
    }

    // MARK: - Station, Tool, Wand, Tea & Accessory Icons

    static func drawAccessoryIcon(_ g: GraphicsContext, accessory: FairyAccessory) {
        let scale: CGFloat = accessory == .daenggiRibbon ? 1.05 : 1.15
        FairyWingPainter.drawAccessory(g, accessoryID: accessory.rawValue, scale: scale)
    }

    static func drawStationIcon(_ g: GraphicsContext, station: FairyStation) {
        switch station {
        case .stage:
            StorybookArt.fillAndStroke(g, heartPath(center: CGPoint(x: 0, y: 2), size: 38), fill: StorybookArt.color(0xFFA6D6), stroke: StorybookArt.outline(for: 0xE678B2), width: 2.6)
            StorybookArt.fillAndStroke(g, heartPath(center: CGPoint(x: 0, y: 2), size: 24), fill: StorybookArt.color(0xFFF6FA), stroke: Theme.lemon, width: 2)
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: 2), radius: 7, color: Theme.lemon)

        case .salon:
            FairyWingPainter.drawWings(
                g,
                wingCenter: CGPoint(x: 0, y: 2),
                wingHalfSpan: CGSize(width: 22, height: 18),
                baseHex: 0xFFA6D8,
                innerHex: 0xE2F4FF,
                outlineHex: 0xC67AE0,
                design: nil,
                flap: 0,
                time: 0,
                showVeins: false
            )
            StorybookArt.sparkle(g, at: CGPoint(x: 0, y: -11), radius: 6.5, color: Theme.lemon)
            StorybookArt.sparkle(g, at: CGPoint(x: 12, y: 8), radius: 4.5, color: .white)

        case .teaTable:
            let outline = StorybookArt.outline(for: 0x52B096)
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -18, y: 10, width: 36, height: 9)), fill: StorybookArt.color(0xE8FBF4), stroke: outline, width: 2)
            let handle = Path(ellipseIn: CGRect(x: 10, y: -4, width: 11, height: 13))
            g.stroke(handle, with: .color(outline), lineWidth: 4.5)
            g.stroke(handle, with: .color(StorybookArt.color(0x9AEAD0)), lineWidth: 2.2)
            var cup = Path()
            cup.move(to: CGPoint(x: -15, y: -7))
            cup.addQuadCurve(to: CGPoint(x: -10, y: 13), control: CGPoint(x: -14, y: 9))
            cup.addLine(to: CGPoint(x: 10, y: 13))
            cup.addQuadCurve(to: CGPoint(x: 15, y: -7), control: CGPoint(x: 14, y: 9))
            cup.closeSubpath()
            StorybookArt.fillAndStroke(g, cup, fill: StorybookArt.color(0xA6EED6), stroke: outline, width: 2.2)
            StorybookArt.heart(g, at: CGPoint(x: 0, y: -15), size: 11, color: Theme.pink)
        }
    }

    static func drawBrushToolIcon(_ g: GraphicsContext, colorHex: UInt32) {
        var c = g
        c.rotate(by: .radians(-0.65))
        var handle = Path()
        handle.move(to: CGPoint(x: 0, y: 19))
        handle.addLine(to: CGPoint(x: 0, y: -4))
        c.stroke(handle, with: .color(StorybookArt.outline(for: 0xFF8EC2)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        c.stroke(handle, with: .color(StorybookArt.color(0xFFD6E9)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        let ferrule = Path(roundedRect: CGRect(x: -4.5, y: -8, width: 9, height: 7), cornerRadius: 2)
        StorybookArt.fillAndStroke(c, ferrule, fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE0A030), width: 1.6)
        var tip = Path()
        tip.move(to: CGPoint(x: -5.5, y: -8))
        tip.addQuadCurve(to: CGPoint(x: 0, y: -22), control: CGPoint(x: -7, y: -16))
        tip.addQuadCurve(to: CGPoint(x: 5.5, y: -8), control: CGPoint(x: 7, y: -16))
        tip.closeSubpath()
        StorybookArt.fillAndStroke(c, tip, fill: StorybookArt.color(colorHex), stroke: StorybookArt.outline(for: colorHex), width: 2)
    }

    static func drawGlitterToolIcon(_ g: GraphicsContext, hex: UInt32) {
        let bottle = Path(roundedRect: CGRect(x: -11, y: -8, width: 22, height: 24), cornerRadius: 7)
        StorybookArt.fillAndStroke(g, bottle, fill: StorybookArt.color(hex), stroke: StorybookArt.outline(for: hex), width: 2.2)
        StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -8, y: -16, width: 16, height: 9), cornerRadius: 3.5), fill: Theme.lemon, stroke: StorybookArt.outline(for: 0xE0A030), width: 2)
        StorybookArt.sparkle(g, at: CGPoint(x: 0, y: 4), radius: 6.5, color: .white)
        StorybookArt.sparkle(g, at: CGPoint(x: 15, y: -14), radius: 5.5, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: -15, y: -11), radius: 4.5, color: Theme.pink)
    }

    static func drawWipeToolIcon(_ g: GraphicsContext) {
        let sponge = Path(roundedRect: CGRect(x: -17, y: -11, width: 34, height: 22), cornerRadius: 9)
        StorybookArt.fillAndStroke(g, sponge, fill: StorybookArt.color(0xC8F0FF), stroke: StorybookArt.outline(for: 0x76C8F4), width: 2.4)
        StorybookArt.highlight(g, in: CGRect(x: -10, y: -6, width: 14, height: 6), opacity: 0.72)
        drawBubble(g, at: CGPoint(x: 13, y: -13), radius: 5.5, alpha: 1)
        drawBubble(g, at: CGPoint(x: -14, y: -14), radius: 4, alpha: 1)
    }

    static func drawWandBuilderToolIcon(_ g: GraphicsContext) {
        FairyWingPainter.drawWand(
            g,
            design: FairyWandDesign(topper: .heartGem, shaft: .pearlPink, ribbon: .rainbowStream),
            tip: CGPoint(x: 8, y: -10),
            tail: CGPoint(x: -12, y: 16),
            time: 0.4,
            scale: 0.56,
            waveEnergy: 0.2
        )
    }

    static func drawWandShaftIcon(_ g: GraphicsContext, shaft: WandShaft) {
        var stick = Path()
        stick.move(to: CGPoint(x: -12, y: 14))
        stick.addLine(to: CGPoint(x: 12, y: -14))
        g.stroke(stick, with: .color(StorybookArt.outline(for: shaft.accentHex)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        g.stroke(stick, with: .color(StorybookArt.color(shaft.primaryHex)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        g.stroke(stick, with: .color(StorybookArt.color(shaft.accentHex, alpha: 0.7)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [4, 6]))
    }

    static func drawWandRibbonIcon(_ g: GraphicsContext, ribbon: WandRibbon) {
        for (idx, hex) in ribbon.colors.prefix(3).enumerated() {
            let ox = CGFloat(idx - 1) * 7
            var wave = Path()
            wave.move(to: CGPoint(x: ox, y: -14))
            wave.addCurve(to: CGPoint(x: ox + 4, y: 15), control1: CGPoint(x: ox + 10, y: -4), control2: CGPoint(x: ox - 8, y: 6))
            g.stroke(wave, with: .color(StorybookArt.outline(for: hex)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            g.stroke(wave, with: .color(StorybookArt.color(hex)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        }
    }

    static func drawTeapotIcon(_ g: GraphicsContext, nectar: TeaNectar) {
        let outline = StorybookArt.outline(for: nectar.flowerHex)
        var spout = Path()
        spout.move(to: CGPoint(x: -13, y: 2))
        spout.addQuadCurve(to: CGPoint(x: -27, y: -10), control: CGPoint(x: -26, y: 2))
        g.stroke(spout, with: .color(outline), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
        g.stroke(spout, with: .color(StorybookArt.color(nectar.potHex)), style: StrokeStyle(lineWidth: 4.8, lineCap: .round))

        let handle = Path(ellipseIn: CGRect(x: 11, y: -11, width: 16, height: 20))
        g.stroke(handle, with: .color(outline), lineWidth: 6)
        g.stroke(handle, with: .color(StorybookArt.color(nectar.potHex)), lineWidth: 3.2)

        let body = Path(ellipseIn: CGRect(x: -18, y: -13, width: 36, height: 28))
        g.fill(body, with: .radialGradient(Gradient(colors: [StorybookArt.color(nectar.highlightHex), StorybookArt.color(nectar.potHex)]), center: CGPoint(x: -5, y: -5), startRadius: 2, endRadius: 20))
        g.stroke(body, with: .color(outline), lineWidth: 2.5)

        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -11, y: -18, width: 22, height: 9)), fill: StorybookArt.color(nectar.highlightHex), stroke: outline, width: 2)
        drawTinyFlower(g, at: CGPoint(x: 0, y: -20), radius: 7.5, petalHex: nectar.flowerHex)
        drawTinyFlower(g, at: CGPoint(x: 0, y: 2), radius: 7, petalHex: nectar.flowerHex)
    }

    static func drawSugarStarIcon(_ g: GraphicsContext, star: SugarStarKind) {
        let outline = StorybookArt.outline(for: star.colorHex)
        let sp = fiveStarPath(center: .zero, outer: 18, inner: 9)
        g.fill(sp, with: .radialGradient(Gradient(colors: [.white, StorybookArt.color(star.colorHex)]), center: CGPoint(x: -4, y: -4), startRadius: 2, endRadius: 20))
        g.stroke(sp, with: .color(outline), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        StorybookArt.sparkle(g, at: CGPoint(x: -3, y: -3), radius: 6, color: .white)
        StorybookArt.sparkle(g, at: CGPoint(x: 14, y: -12), radius: 5, color: StorybookArt.color(star.fizzHex))
    }

    static func drawTeaTreatIcon(_ g: GraphicsContext, treat: FairyTeaTreatKind) {
        switch treat {
        case .macaron:
            let outline = StorybookArt.outline(for: 0xFF7EB4)
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -18, y: 2, width: 36, height: 11), cornerRadius: 5.5), fill: StorybookArt.color(0xFF9AC8), stroke: outline, width: 2.2)
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -17, y: -3, width: 34, height: 7), cornerRadius: 3.5), fill: .white, stroke: StorybookArt.color(0xFFD6EA), width: 1.8)
            StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -18, y: -13, width: 36, height: 12), cornerRadius: 6), fill: StorybookArt.color(0xFFB5DA), stroke: outline, width: 2.2)
            StorybookArt.highlight(g, in: CGRect(x: -11, y: -10, width: 14, height: 4), opacity: 0.6)

        case .bungeoppang:
            drawBungeoppang(g, at: .zero, scale: 0.96)

        case .berryTart:
            let crust = Path(roundedRect: CGRect(x: -17, y: 1, width: 34, height: 13), cornerRadius: 5)
            StorybookArt.fillAndStroke(g, crust, fill: StorybookArt.color(0xF6C87C), stroke: StorybookArt.outline(for: 0xD6963E), width: 2.2)
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -15, y: -7, width: 30, height: 13)), fill: .white, stroke: StorybookArt.color(0xFFE0EC), width: 2)
            StorybookArt.fillAndStroke(g, heartPath(center: CGPoint(x: 0, y: -8), size: 18), fill: StorybookArt.color(0xFF6B92), stroke: StorybookArt.outline(for: 0xDC446E), width: 2)
            StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -6, y: -18, width: 12, height: 5)), fill: StorybookArt.color(0x7CE09C), stroke: StorybookArt.outline(for: 0x52B474), width: 1.4)

        case .hwajeon:
            let cake = Path(ellipseIn: CGRect(x: -19, y: -11, width: 38, height: 22))
            StorybookArt.fillAndStroke(g, cake, fill: StorybookArt.color(0xFFF4DC), stroke: StorybookArt.outline(for: 0xE6C48C), width: 2.4)
            drawTinyFlower(g, at: .zero, radius: 10, petalHex: 0xFF8EB8)
        }
    }

    static func drawServeBellIcon(_ g: GraphicsContext) {
        let goldOutline = StorybookArt.outline(for: 0xE0A030)
        StorybookArt.fillAndStroke(g, Path(roundedRect: CGRect(x: -19, y: 8, width: 38, height: 7), cornerRadius: 3.5), fill: Theme.lemon, stroke: goldOutline, width: 2.2)
        var dome = Path()
        dome.move(to: CGPoint(x: -16, y: 8))
        dome.addArc(center: CGPoint(x: 0, y: 8), radius: 16, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        dome.closeSubpath()
        StorybookArt.fillAndStroke(g, dome, fill: StorybookArt.color(0xFFF2A6), stroke: goldOutline, width: 2.4)
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: -4, y: -14, width: 8, height: 8)), fill: Theme.pink, stroke: StorybookArt.outline(for: 0xDE6496), width: 1.8)
        StorybookArt.sparkle(g, at: CGPoint(x: 15, y: -11), radius: 6, color: .white)
    }

    static func drawTileIcon(_ g: GraphicsContext) {
        g.fill(
            Path(ellipseIn: CGRect(x: 34, y: 34, width: 232, height: 232)),
            with: .radialGradient(Gradient(colors: [.white.opacity(0.65), .white.opacity(0)]), center: CGPoint(x: 150, y: 150), startRadius: 20, endRadius: 118)
        )

        let outer = heartPath(center: CGPoint(x: 150, y: 162), size: 220)
        g.fill(outer, with: .linearGradient(Gradient(colors: [StorybookArt.color(0xFFC2E2), StorybookArt.color(0xFF8CC4)]), startPoint: CGPoint(x: 150, y: 50), endPoint: CGPoint(x: 150, y: 270)))
        g.stroke(outer, with: .color(StorybookArt.color(0xFFE07D)), lineWidth: 11)
        g.stroke(outer, with: .color(StorybookArt.outline(for: 0xE6A436)), lineWidth: 4.5)

        let inner = heartPath(center: CGPoint(x: 150, y: 164), size: 170)
        g.fill(inner, with: .radialGradient(Gradient(colors: [.white, StorybookArt.color(0xFFE8F4)]), center: CGPoint(x: 150, y: 146), startRadius: 10, endRadius: 96))
        g.stroke(inner, with: .color(StorybookArt.color(0xF5CA5C)), lineWidth: 5)

        var fc = g
        fc.translateBy(x: 150, y: 166)
        drawFairy(fc, kind: .heart, mood: .happy, accessory: .crown, time: 0.3, scale: 1.72, blinkSeed: 0.2)

        StorybookArt.sparkle(g, at: CGPoint(x: 54, y: 74), radius: 16, color: Theme.lemon)
        StorybookArt.sparkle(g, at: CGPoint(x: 248, y: 68), radius: 18, color: .white)
        StorybookArt.heart(g, at: CGPoint(x: 242, y: 224), size: 26, color: Theme.pink)
        StorybookArt.sparkle(g, at: CGPoint(x: 58, y: 222), radius: 12, color: Theme.lemon)
    }

    // MARK: - Shared Helpers

    private static func drawWandTrail(_ g: GraphicsContext, trail: [WandSparkle]) {
        for s in trail {
            let life = max(0, min(1, 1 - s.age / s.maxAge))
            StorybookArt.sparkle(g, at: s.pos, radius: s.size * life, color: StorybookArt.color(s.colorHex), opacity: Double(life))
            StorybookArt.sparkle(g, at: s.pos, radius: s.size * life * 0.45, color: .white, opacity: Double(life))
        }
    }

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
                c.fill(Path(ellipseIn: CGRect(x: -p.size * 0.45, y: -p.size * 0.28, width: p.size * 0.9, height: p.size * 0.56)), with: .color(StorybookArt.color(p.colorHex, alpha: alpha)))
            case .note:
                let col = StorybookArt.color(p.colorHex, alpha: alpha)
                g.fill(Path(ellipseIn: CGRect(x: p.pos.x - 5, y: p.pos.y - 3, width: 9, height: 7)), with: .color(col))
                var stem = Path()
                stem.move(to: CGPoint(x: p.pos.x + 3.5, y: p.pos.y))
                stem.addLine(to: CGPoint(x: p.pos.x + 3.5, y: p.pos.y - 13))
                stem.addQuadCurve(to: CGPoint(x: p.pos.x + 11, y: p.pos.y - 8), control: CGPoint(x: p.pos.x + 10, y: p.pos.y - 14))
                g.stroke(stem, with: .color(col), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            case .sleepyZ:
                StorybookArt.sparkle(g, at: p.pos, radius: p.size * 0.55, color: StorybookArt.color(p.colorHex), opacity: alpha)
                StorybookArt.sparkle(g, at: CGPoint(x: p.pos.x + 9, y: p.pos.y - 7), radius: p.size * 0.35, color: Theme.lemon, opacity: alpha)
            case .confetti:
                var c = g
                c.translateBy(x: p.pos.x, y: p.pos.y)
                c.rotate(by: .radians(Double(t * 5.2 + Double(p.phase))))
                c.fill(Path(roundedRect: CGRect(x: -p.size * 0.42, y: -p.size * 0.24, width: p.size * 0.84, height: p.size * 0.48), cornerRadius: 2.5), with: .color(StorybookArt.color(p.colorHex, alpha: alpha)))
            }
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

    private static func drawBubble(_ g: GraphicsContext, at center: CGPoint, radius r: CGFloat, alpha: Double) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        g.fill(Path(ellipseIn: rect), with: .color(StorybookArt.color(0xE8F8FF, alpha: 0.45 * alpha)))
        g.stroke(Path(ellipseIn: rect), with: .color(StorybookArt.color(0x9CDFFF, alpha: 0.9 * alpha)), lineWidth: 2.2)
        StorybookArt.highlight(g, in: CGRect(x: center.x - r * 0.52, y: center.y - r * 0.55, width: r * 0.48, height: r * 0.3), opacity: 0.8 * alpha)
    }

    private static func drawMiniPinStar(_ g: GraphicsContext, at center: CGPoint, radius: CGFloat) {
        StorybookArt.fillAndStroke(g, Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), fill: StorybookArt.color(0xFFF3B8), stroke: .white, width: 2.4)
        StorybookArt.fillAndStroke(g, fiveStarPath(center: center, outer: radius * 0.68, inner: radius * 0.32), fill: StorybookArt.color(0xFFB830), stroke: StorybookArt.outline(for: 0xD88C16), width: 1.6)
    }

    static func heartPath(center: CGPoint, size: CGFloat) -> Path {
        FairyWingPainter.heartPath(center: center, size: size)
    }

    static func fiveStarPath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        FairyWingPainter.fiveStarPath(center: center, outer: outer, inner: inner)
    }
}
