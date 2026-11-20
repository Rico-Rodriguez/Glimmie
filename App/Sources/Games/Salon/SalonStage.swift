import SwiftUI

// MARK: - Drawing the salon chair each frame

extension SalonWorld {
    func draw(_ ctx: GraphicsContext, size: CGSize, now: Date) {
        SalonRoom.draw(in: ctx, size: size, floorY: floorDesign, center: centerX)

        let k = SalonWorld.k
        var art = ctx
        art.translateBy(x: centerX - 300 * k, y: SalonWorld.headY - 287 * k)
        art.scaleBy(x: k, y: k)
        var client = art
        client.translateBy(x: 0, y: hop(now))

        let e = expression(now)
        let t = now.timeIntervalSinceReferenceDate

        // shadow on the floor
        art.fill(Path(ellipseIn: CGRect(x: 150, y: SalonBody.floorY - 14, width: 300, height: 30)),
                 with: .color(Theme.ink.opacity(0.1)))
        SalonFurniture.drawChairBase(in: art)
        SalonFurniture.drawChairBack(in: client)
        ClientPainter.draw(look, e, z: 0...9, in: client)
        HairPainter.drawBack(sim, in: client)
        for p in sim.pieces where !p.front { HairPainter.draw(p, in: art) }
        ClientPainter.draw(look, e, z: 10...45, in: client)
        SalonFurniture.drawCape(color: ClipPainter.clipColor(cape), in: client)
        HairPainter.drawFront(sim, in: client)
        ClientPainter.draw(look, e, z: 46...200, in: client)
        ClipPainter.drawAll(sim, in: client)
        HairPainter.drawFoam(sim, in: client)
        HairPainter.drawFlakes(sim, t: t, in: client)
        for p in sim.pieces where p.front { HairPainter.draw(p, in: art) }
        drawBits(in: art, t: t)
        drawHeld(in: ctx, art: art)
    }

    private func drawBits(in ctx: GraphicsContext, t: Double) {
        for b in bits {
            let life = max(0.001, b.life)
            let u = b.age / life
            var g = ctx
            let c = b.p.cg
            switch b.kind {
            case .drop:
                let s = b.size
                let a = atan2(Double(b.v.x), Double(b.v.y))
                g.translateBy(x: c.x, y: c.y)
                g.rotate(by: .radians(-a))
                g.opacity = 0.85
                var d = Path()
                d.move(to: CGPoint(x: 0, y: s * 1.6))
                d.addQuadCurve(to: CGPoint(x: 0, y: -s * 1.4), control: CGPoint(x: s * 1.5, y: -s * 0.2))
                d.addQuadCurve(to: CGPoint(x: 0, y: s * 1.6), control: CGPoint(x: -s * 1.5, y: -s * 0.2))
                g.fill(d, with: .color(Color(hex: 0x8FCBFF)))
                g.fill(Path(ellipseIn: CGRect(x: -s * 0.45, y: -s * 0.4, width: s * 0.5, height: s * 0.7)), with: .color(.white.opacity(0.85)))
            case .splash:
                g.opacity = 0.8 * (1 - u)
                g.fill(Path(ellipseIn: CGRect(x: c.x - b.size, y: c.y - b.size, width: b.size * 2, height: b.size * 2)),
                       with: .color(Color(hex: 0x9CD3FF)))
            case .suds:
                let r = b.size
                g.opacity = u > 0.7 ? (1 - u) / 0.3 : 1
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                g.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(Color(hex: 0xB8CFE6)))
                g.fill(Path(ellipseIn: rect), with: .color(.white))
                g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.5, y: c.y - r * 0.55, width: r * 0.4, height: r * 0.35)), with: .color(.white))
            case .bubble:
                let r = b.size
                g.opacity = 0.9 * (1 - u * 0.6)
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                g.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(0.05), Color(hex: 0xC9E6FF, alpha: 0.35), Color(hex: 0xFFC6E6, alpha: 0.6)]),
                    center: c, startRadius: 0, endRadius: r))
                g.stroke(Path(ellipseIn: rect), with: .color(Color(hex: 0xA8C8EA)), lineWidth: 1.3)
                g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.6, width: r * 0.45, height: r * 0.35)), with: .color(.white))
            case .steam:
                g.opacity = 0.45 * (1 - u)
                g.fill(Path(ellipseIn: CGRect(x: c.x - b.size, y: c.y - b.size, width: b.size * 2, height: b.size * 2)), with: .color(.white))
            case .air:
                g.opacity = 0.5 * (1 - u)
                var l = Path()
                let d = b.v.unit
                l.move(to: c)
                l.addLine(to: (b.p - d * b.size).cg)
                g.stroke(l, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            case .sparkle:
                let s = b.size * CGFloat(1 - u * 0.6)
                g.opacity = 1 - u
                g.fill(Twinkle().path(in: CGRect(x: c.x - s, y: c.y - s, width: s * 2, height: s * 2)), with: .color(b.color.color))
            case .glitter:
                let tw = 0.5 + 0.5 * sin(t * 9 + Double(b.size) * 3)
                let s = b.size * CGFloat(0.7 + 0.6 * tw)
                g.opacity = (u > 0.8 ? (1 - u) / 0.2 : 1) * (0.6 + 0.4 * tw)
                g.translateBy(x: c.x, y: c.y)
                g.rotate(by: .radians(Double(b.angle)))
                g.fill(ClipPainter.star(s, points: 4, inner: 0.35), with: .color(b.color.mix(Shades.white, tw * 0.4).color))
            case .dye:
                g.opacity = 1 - u
                g.fill(Path(ellipseIn: CGRect(x: c.x - b.size, y: c.y - b.size, width: b.size * 2, height: b.size * 2)), with: .color(b.color.color))
            case .dust:
                g.opacity = 1 - u
                g.translateBy(x: c.x, y: c.y)
                g.rotate(by: .radians(Double(b.angle)))
                var l = Path()
                l.move(to: CGPoint(x: -b.size, y: 0))
                l.addQuadCurve(to: CGPoint(x: b.size, y: 0), control: CGPoint(x: 0, y: -b.size * 0.5))
                g.stroke(l, with: .color(Shades.outline(b.color).color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            case .prop:
                guard let clip = b.clip else { continue }
                g.opacity = u > 0.8 ? (1 - u) / 0.2 : 1
                g.translateBy(x: c.x, y: c.y)
                g.rotate(by: .radians(Double(b.angle)))
                ClipPainter.draw(clip.kind, color: clip.color, in: g)
            }
        }
    }

    /// The tool in her hand, or the clip she's carrying (design space).
    private func drawHeld(in ctx: GraphicsContext, art: GraphicsContext) {
        if let c = carry, let p = carryPoint {
            var g = ctx
            let up = SalonWorld.carried(p)
            g.translateBy(x: up.x, y: up.y)
            g.scaleBy(x: SalonWorld.k * 1.15, y: SalonWorld.k * 1.15)
            g.addFilter(.shadow(color: Theme.ink.opacity(0.25), radius: 6, x: 0, y: 6))
            switch c {
            case .clip(let kind, let color): ClipPainter.draw(kind, color: color, in: g)
            case .scrunchie(let color): ClipPainter.drawScrunchie(color: color, in: g)
            }
        }
        if let m = moving, let f = finger {
            var g = ctx
            let up = SalonWorld.carried(f)
            g.translateBy(x: up.x, y: up.y)
            g.scaleBy(x: SalonWorld.k * 1.15, y: SalonWorld.k * 1.15)
            g.addFilter(.shadow(color: Theme.ink.opacity(0.25), radius: 6, x: 0, y: 6))
            ClipPainter.draw(m.kind, color: m.color, in: g)
        }
        guard let t = tool, t != .clips, let f = finger else { return }
        let tipD = tipDesign(f)
        let s: CGFloat = 1.3
        var g = ctx
        g.translateBy(x: tipD.x, y: tipD.y)
        if t == .dryer {
            let d = (SalonBody.center - toArt(tipD)).unit
            if d.x > 0 {
                g.scaleBy(x: -1, y: 1)
                g.rotate(by: .radians(-Double(atan2(d.y, d.x))))
            } else {
                g.rotate(by: .radians(Double(atan2(d.y, d.x)) - .pi))
            }
        } else if t != .shower {
            // near the bottom the tip sits beside her finger: the tool leans so it still points from her finger to its tip
            let lean = atan2(Double(tipD.y - f.y), Double(tipD.x - f.x)) + .pi / 2
            if abs(lean) > 0.01 { g.rotate(by: .radians(lean)) }
        }
        g.scaleBy(x: s, y: s)
        g.translateBy(x: -t.tip.x, y: -t.tip.y)
        // over her hair the tool turns see-through, with a ring where its tip works
        let a = toArt(tipD)
        let working = a.x > 90 && a.x < 510 && a.y > 30 && a.y < 760
        if working { g.opacity = FingerLift.seeThrough }
        g.addFilter(.shadow(color: Theme.ink.opacity(0.28), radius: 7, x: 0, y: 7))
        let dye = dyeFor(dyeColor, at: a, strandTime: 0)
        g.drawLayer { l in
            SalonToolArt.draw(t, dye: dye, open: scissorsOpen, in: l)
        }
        if working && t != .dryer && t != .shower {
            FingerLift.drawTip(ctx, at: tipD, time: Date().timeIntervalSinceReferenceDate)
        }
    }
}

// MARK: - Screenshot moments

enum SalonDemo {
    /// Sets up `name` and returns the tool to hold.
    static func run(_ name: String, in w: SalonWorld) -> SalonTool? {
        w.tool = nil
        switch name {
        case "wash":
            for x in stride(from: 190.0, through: 410.0, by: 22.0) {
                for y in [170.0, 210.0, 250.0, 330.0, 420.0] {
                    _ = w.sim.lather(HairV(CGFloat(x), CGFloat(y)), dt: 0.4)
                    _ = w.sim.lather(HairV(CGFloat(x), CGFloat(y)), dt: 0.4)
                }
            }
            for i in w.sim.strands.indices { w.sim.makeWet(i, 0.5) }
            w.tool = .shower
            hold(w, at: HairV(300, 110))
        case "dry":
            for i in w.sim.strands.indices { w.sim.makeWet(i, 0.6) }
            w.tool = .dryer
            hold(w, at: HairV(560, 330))
        case "cut":
            w.sim.settle(seconds: 1)
            _ = w.sim.cut(from: HairV(120, 520), to: HairV(480, 520))
            _ = w.sim.cut(from: HairV(200, 280), to: HairV(400, 280))
            w.sim.settle(seconds: 0.3)
            w.tool = .scissors
            hold(w, at: HairV(150, 470))
        case "curl":
            for y in stride(from: 300.0, through: 700.0, by: 16.0) {
                for x in stride(from: 100.0, through: 500.0, by: 16.0) { _ = w.sim.curlUp(HairV(CGFloat(x), CGFloat(y)), dt: 0.5) }
            }
            w.tool = .curler
            hold(w, at: HairV(170, 480))
        case "style":
            style(w, variant: 0)
            w.tool = .dye
            w.dyeColor = SalonWorld.rainbowIndex
            hold(w, at: HairV(440, 520))
        default:
            break
        }
        w.sim.settle(seconds: 1)
        return w.tool
    }

    /// A finished look for the photo wall and screenshots.
    static func style(_ w: SalonWorld, variant: Int) {
        let rainbow = variant % 3 == 0
        let curly = variant % 2 == 0
        for y in stride(from: 140.0, through: 760.0, by: 18.0) {
            for x in stride(from: 80.0, through: 520.0, by: 18.0) {
                let q = HairV(CGFloat(x), CGFloat(y))
                if curly && y > 300 { _ = w.sim.curlUp(q, dt: 0.5) }
                if rainbow {
                    _ = w.sim.dye(q, dt: 1) { p in w.dyeFor(SalonWorld.rainbowIndex, at: p, strandTime: 0) }
                } else if y > 380 {
                    let c = SalonWorld.dyeColors[(variant * 3) % SalonWorld.dyeColors.count]
                    _ = w.sim.dye(q, dt: 0.35) { _ in c }
                }
            }
        }
        for i in w.sim.strands.indices { w.sim.strands[i].tangle = 0 }
        w.sim.clips.removeAll()
        w.sim.settle(seconds: 1)
        _ = w.sim.attach(.bow, color: [4, 16, 19, 5][variant % 4], at: HairV(392, 200))
        _ = w.sim.attach(.star, color: 9, at: HairV(214, 206))
        if variant % 2 == 1 {
            _ = w.sim.tie(at: HairV(168, 410), color: 3)
            _ = w.sim.tie(at: HairV(432, 410), color: 3)
        }
        for _ in 0..<40 { _ = w.sim.sprinkleGlitter(HairV(CGFloat.random(in: 150...450), CGFloat.random(in: 160...300)), color: SalonWorld.glitterColors[0]) }
        if variant % 3 == 1 { w.wearHat("h_tiara") }
        w.sim.settle(seconds: 1.5)
    }

    private static func hold(_ w: SalonWorld, at q: HairV) {
        let d = w.toDesign(q)
        w.press(w.fingerFor(tip: d))
    }
}
