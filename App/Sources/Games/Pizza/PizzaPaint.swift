import SwiftUI

// MARK: - Pizza drawing
//
// The counter (wood, a round board, flour dust) is drawn once in its own layer. Everything else is drawn every frame
// from `PizzaSim`: the dough (a lumpy ball or a springy disc with a puffed rim), sauce and melted cheese from their
// grids as small bitmaps (`PizzaGrids`, lit from the top left so they look wet and glossy), cheese shreds from their
// bitmap, toppings, bubbles, char spots, cuts, the oven with real-looking fire, steam, flour and the held tool.

enum PizzaPainter {
    // MARK: colors

    static let rawDough = RGB(0.96, 0.89, 0.74)
    static let bakedDough = RGB(0.89, 0.64, 0.34)
    static let rawRim = RGB(0.98, 0.92, 0.80)
    static let bakedRim = RGB(0.82, 0.52, 0.24)

    static func doughColor(_ sim: PizzaSim) -> RGB { rawDough.mix(bakedDough, sim.smooth(0.2, 1, sim.bake)) }
    static func rimColor(_ sim: PizzaSim) -> RGB { rawRim.mix(bakedRim, sim.smooth(0.2, 1, sim.bake)) }

    // MARK: - The counter (static)

    static func drawCounter(_ ctx: GraphicsContext, map: GMap) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let v = map.visible.insetBy(dx: -4, dy: -4)
        // butcher block: strips of wood
        let tones = [RGB(0.80, 0.61, 0.41), RGB(0.76, 0.56, 0.37), RGB(0.83, 0.65, 0.45), RGB(0.78, 0.58, 0.38)]
        var x = floor(v.minX / 58) * 58
        var k = 0
        var grain = Path()
        var r = SeededRandom(3)
        while x < v.maxX {
            let w: CGFloat = 58
            let c = tones[abs(k) % tones.count]
            g.fill(Path(CGRect(x: x, y: v.minY, width: w + 0.5, height: v.height)),
                   with: .linearGradient(Gradient(colors: [c.mix(RGB(1, 1, 1), 0.06).color, c.color, c.mul(0.95, 0.93, 0.92).color]),
                                         startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + w, y: 0)))
            for _ in 0..<4 {
                let gx = x + 6 + CGFloat(r.unit()) * (w - 12)
                grain.move(to: CGPoint(x: gx, y: v.minY))
                var y = v.minY
                while y < v.maxY {
                    let ny = y + 80
                    grain.addQuadCurve(to: CGPoint(x: gx + CGFloat(r.unit() - 0.5) * 5, y: ny),
                                       control: CGPoint(x: gx + CGFloat(r.unit() - 0.5) * 10, y: y + 40))
                    y = ny
                }
            }
            g.stroke(Path(CGRect(x: x, y: v.minY, width: 0.01, height: v.height)), with: .color(RGB(0.5, 0.33, 0.2).color.opacity(0.35)), lineWidth: 1.5)
            x += w
            k += 1
        }
        g.stroke(grain, with: .color(RGB(0.45, 0.28, 0.15).color.opacity(0.13)), lineWidth: 1.3)
        // the round board
        let c = PGeo.center
        let br: CGFloat = 262
        for (o, a) in [(CGFloat(14), 0.12), (CGFloat(7), 0.14)] {
            g.fill(Path(ellipseIn: CGRect(x: c.x - br + o * 0.4, y: c.y - br + o, width: br * 2, height: br * 2)), with: .color(.black.opacity(a)))
        }
        let board = Path(ellipseIn: CGRect(x: c.x - br, y: c.y - br, width: br * 2, height: br * 2))
        g.fill(board, with: .radialGradient(Gradient(colors: [RGB(0.74, 0.52, 0.31).color, RGB(0.66, 0.45, 0.26).color, RGB(0.55, 0.36, 0.2).color]),
                                            center: CGPoint(x: c.x - 60, y: c.y - 70), startRadius: 10, endRadius: br * 1.2))
        var rings = Path()
        for i in 0..<9 {
            let rr = 30 + CGFloat(i) * 27 + CGFloat(r.unit()) * 8
            rings.addEllipse(in: CGRect(x: c.x - rr * 1.02 + 6, y: c.y - rr + 4, width: rr * 2.04, height: rr * 2))
        }
        var bg = g
        bg.clip(to: board)
        bg.stroke(rings, with: .color(RGB(0.42, 0.26, 0.14).color.opacity(0.10)), lineWidth: 2)
        g.stroke(board, with: .color(RGB(0.42, 0.26, 0.14).color.opacity(0.55)), lineWidth: 4)
        g.stroke(Path(ellipseIn: CGRect(x: c.x - br + 5, y: c.y - br + 5, width: br * 2 - 10, height: br * 2 - 10)),
                 with: .color(.white.opacity(0.12)), lineWidth: 3)
        // flour dust on the board and around it
        var dust = Path()
        for _ in 0..<260 {
            let a = r.unit() * 2 * .pi
            let d = 120 + CGFloat(r.unit()) * 170
            let s = 1 + CGFloat(r.unit()) * 2.5
            dust.addEllipse(in: CGRect(x: c.x + CGFloat(cos(a)) * d, y: c.y + CGFloat(sin(a)) * d, width: s, height: s))
        }
        g.fill(dust, with: .color(.white.opacity(0.5)))
        var cloud = g
        cloud.opacity = 0.16
        for _ in 0..<7 {
            let a = r.unit() * 2 * .pi
            let d = 200 + CGFloat(r.unit()) * 70
            let s = 40 + CGFloat(r.unit()) * 40
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * d, y: c.y + CGFloat(sin(a)) * d)
            cloud.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s * 0.6, width: s * 2, height: s * 1.2)),
                       with: .radialGradient(Gradient(colors: [.white, .white.opacity(0)]), center: p, startRadius: 0, endRadius: s))
        }
        // a soft vignette
        g.fill(Path(v), with: .radialGradient(Gradient(colors: [.clear, .clear, .black.opacity(0.22)]),
                                              center: CGPoint(x: 512, y: 430), startRadius: 0, endRadius: 760))
    }

    // MARK: - Every frame

    static func draw(_ ctx: GraphicsContext, map: GMap, sim: PizzaSim, grids: PizzaGrids) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let t = sim.time
        let oven = sim.ovenSlide
        if oven < 0.999 {
            // the pizza on the board
            var pg = g
            pg.translateBy(x: PGeo.center.x, y: PGeo.center.y + CGFloat(oven) * 120)
            if oven > 0.001 {
                pg.opacity = 1 - oven
                pg.drawLayer { l in drawWholePizza(l, sim: sim, grids: grids, onBoard: true) }
            } else {
                drawWholePizza(pg, sim: sim, grids: grids, onBoard: true)
            }
        }
        if oven > 0.001 {
            if oven < 0.999 {
                var og = g
                og.opacity = oven
                og.drawLayer { l in drawOven(l, map: map, sim: sim, grids: grids) }
            } else {
                drawOven(g, map: map, sim: sim, grids: grids)
            }
        }
        drawPuffs(g, sim: sim)
        drawCustomer(g, sim: sim)
        drawCard(g, sim: sim)
        drawFalling(g, sim: sim)
        drawTool(g, sim: sim, time: t)
    }

    /// The pizza with its shadow, cuts, lifted slice and cheese strings, around (0, 0).
    static func drawWholePizza(_ ctx: GraphicsContext, sim: PizzaSim, grids: PizzaGrids, onBoard: Bool) {
        var g = ctx
        // a wiggle when she taps something that can't be served
        let w = sim.time - sim.wiggleAt
        if w < 0.4 && sim.stage == .slice { g.translateBy(x: CGFloat(sin(w * 40) * (0.4 - w) * 14), y: 0) }
        if sim.ball {
            drawBall(g, sim: sim)
            return
        }
        let h = sim.tossHeight
        if h > 0 {
            // the shadow stays on the board while the dough flies
            let rr = sim.meanR * (1 - 0.25 * h)
            g.fill(Path(ellipseIn: CGRect(x: -rr + 8, y: -rr + 14, width: rr * 2, height: rr * 2)), with: .color(.black.opacity(0.18 * Double(1 - 0.6 * h))))
            g.translateBy(x: 0, y: -h * 60)
            g.scaleBy(x: 1 + 0.32 * h, y: 1 + 0.32 * h)
            g.rotate(by: .radians(sim.spin))
        }
        let lifted = sim.lifted
        let removed: [(Double, Double)] = sim.eaten + (lifted.map { [($0.a0, $0.a1)] } ?? [])
        var clip: Path?
        if !removed.isEmpty {
            var p = Path()
            for s in sim.slices where !sim.isEaten((s.0 + s.1) / 2) {
                if let l = lifted, abs(l.a0 - s.0) < 0.0001 { continue }
                p.addPath(wedge(s.0, s.1, PGeo.maxR + 40))
            }
            clip = p
        }
        if let c = clip {
            var cg = g
            cg.clip(to: c)
            drawDisc(cg, sim: sim, grids: grids, shadow: h == 0)
        } else {
            drawDisc(g, sim: sim, grids: grids, shadow: h == 0)
        }
        if let l = lifted, let pose = sim.liftedPose() {
            drawStrings(g, sim: sim, lifted: l, pose: pose)
            var sg = g
            sg.translateBy(x: pose.cx + pose.dx, y: pose.cy + pose.dy)
            sg.scaleBy(x: pose.scale, y: pose.scale)
            sg.translateBy(x: -pose.cx, y: -pose.cy)
            // its shadow on the board below
            var sh = sg
            sh.translateBy(x: 6, y: 16 + CGFloat(pose.u) * 30)
            sh.opacity = 0.22
            sh.fill(wedge(l.a0, l.a1, sim.meanR), with: .color(.black))
            sg.clip(to: wedge(l.a0, l.a1, PGeo.maxR + 40))
            drawDisc(sg, sim: sim, grids: grids, shadow: false)
        }
    }

    static func wedge(_ a0: Double, _ a1: Double, _ r: CGFloat) -> Path {
        var p = Path()
        if a1 - a0 > 2 * .pi - 0.001 {
            p.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
            return p
        }
        p.move(to: .zero)
        p.addArc(center: .zero, radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
        p.closeSubpath()
        return p
    }

    /// The dough's outline as a smooth closed curve (pizza space).
    static func doughPath(_ sim: PizzaSim, scale k: CGFloat = 1) -> Path {
        let n = PizzaSim.n
        var pts: [CGPoint] = []
        pts.reserveCapacity(n)
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi
            pts.append(CGPoint(x: CGFloat(cos(a)) * sim.r[i] * k, y: CGFloat(sin(a)) * sim.r[i] * k))
        }
        return smoothClosed(pts)
    }

    static func smoothClosed(_ pts: [CGPoint]) -> Path {
        var p = Path()
        let n = pts.count
        guard n > 2 else { return p }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        p.move(to: mid(pts[0], pts[1]))
        for i in 1...n {
            let c = pts[i % n]
            let nx = pts[(i + 1) % n]
            p.addQuadCurve(to: mid(c, nx), control: c)
        }
        p.closeSubpath()
        return p
    }

    // MARK: the kneading ball

    static func drawBall(_ ctx: GraphicsContext, sim: PizzaSim) {
        var g = ctx
        let n = PizzaSim.n
        let rough = 1 - Double(min(sim.kneads, PGeo.knead)) / Double(PGeo.knead)
        let R = sim.ballRadius
        let sq = sim.squash
        let sx = 1 + 0.24 * sq, sy = 1 - 0.18 * sq
        // shadow
        g.fill(Path(ellipseIn: CGRect(x: -R * sx * 1.02 + 10, y: -R * sy * 0.5 + R * sy * 0.62, width: R * sx * 2.04, height: R * sy * 0.9)),
               with: .color(.black.opacity(0.2)))
        g.translateBy(x: sim.ballShift.x * 0.6, y: sim.ballShift.y * 0.6)
        g.scaleBy(x: sx, y: sy)
        var pts: [CGPoint] = []
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi
            let rr = R + sim.lumps[i] * 15
            pts.append(CGPoint(x: CGFloat(cos(a)) * rr, y: CGFloat(sin(a)) * rr))
        }
        let body = smoothClosed(pts)
        g.fill(body, with: .radialGradient(Gradient(colors: [RGB(1.0, 0.97, 0.88).color, RGB(0.96, 0.88, 0.71).color, RGB(0.84, 0.71, 0.52).color]),
                                           center: CGPoint(x: -R * 0.32, y: -R * 0.38), startRadius: 4, endRadius: R * 1.45))
        var inner = g
        inner.clip(to: body)
        // creases and floury patches while it's still shaggy
        if rough > 0.01 {
            var crease = Path()
            for i in 0..<3 {
                let a0 = Double(i) * 2.1 + Double(sim.kneads) * 0.9
                let rr = R * (0.35 + 0.18 * CGFloat(i))
                crease.addArc(center: CGPoint(x: CGFloat(cos(a0)) * 12, y: CGFloat(sin(a0)) * 12), radius: rr,
                              startAngle: .radians(a0), endAngle: .radians(a0 + 1.3), clockwise: false)
            }
            inner.stroke(crease, with: .color(RGB(0.62, 0.48, 0.32).color.opacity(0.35 * rough)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            inner.stroke(crease.offsetBy(dx: -2, dy: -3), with: .color(.white.opacity(0.4 * rough)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            var flour = Path()
            var fr = SeededRandom(17 + sim.kneads)
            for _ in 0..<7 {
                let a = fr.unit() * 2 * .pi
                let d = CGFloat(fr.unit()) * R * 0.8
                let s = 12 + CGFloat(fr.unit()) * 18
                flour.addEllipse(in: CGRect(x: CGFloat(cos(a)) * d - s, y: CGFloat(sin(a)) * d - s * 0.7, width: s * 2, height: s * 1.4))
            }
            inner.fill(flour, with: .color(.white.opacity(0.32 * rough)))
        }
        // a smooth ball gets a soft shine
        let shine = 0.18 + 0.4 * (1 - rough)
        inner.fill(Path(ellipseIn: CGRect(x: -R * 0.62, y: -R * 0.7, width: R * 0.7, height: R * 0.42)),
                   with: .radialGradient(Gradient(colors: [.white.opacity(shine), .white.opacity(0)]),
                                         center: CGPoint(x: -R * 0.27, y: -R * 0.5), startRadius: 0, endRadius: R * 0.4))
        g.stroke(body, with: .color(RGB(0.72, 0.57, 0.38).color), lineWidth: 2.5)
    }

    // MARK: the disc with everything on it

    static func drawDisc(_ ctx: GraphicsContext, sim: PizzaSim, grids: PizzaGrids, shadow: Bool) {
        let g = ctx
        let path = doughPath(sim)
        let R = sim.meanR
        let rim = PGeo.rim
        let bake = sim.bake
        if shadow {
            g.fill(path.offsetBy(dx: 5, dy: 10), with: .color(.black.opacity(0.16)))
            g.fill(path.offsetBy(dx: 2, dy: 4), with: .color(.black.opacity(0.12)))
        }
        let base = doughColor(sim)
        g.fill(path, with: .radialGradient(Gradient(colors: [base.mix(RGB(1, 1, 1), 0.12).color, base.color, base.mul(0.9, 0.86, 0.82).color]),
                                           center: CGPoint(x: -R * 0.25, y: -R * 0.3), startRadius: 0, endRadius: R * 1.2))
        var inside = g
        inside.clip(to: path)
        // the puffed rim
        let rimC = rimColor(sim)
        inside.stroke(path, with: .color(rimC.color), lineWidth: rim * 2.2)
        let innerEdge = doughPath(sim, scale: max(0.5, (R - rim * 1.05) / R))
        inside.stroke(innerEdge, with: .color(rimC.mul(0.62, 0.52, 0.45).color.opacity(0.28)), lineWidth: 5)
        let ridge = doughPath(sim, scale: max(0.5, (R - rim * 0.5) / R))
        inside.stroke(ridge.offsetBy(dx: -1.5, dy: -2.5), with: .color(.white.opacity(0.32 - 0.18 * bake)), lineWidth: 6)
        // flour dust and fingertip dimples on raw dough
        if bake < 0.9 {
            var dust = Path()
            var r = SeededRandom(29)
            for _ in 0..<90 {
                let a = r.unit() * 2 * .pi
                let d = CGFloat(sqrt(r.unit())) * (R - 6)
                let s = 1.2 + CGFloat(r.unit()) * 2.2
                dust.addEllipse(in: CGRect(x: CGFloat(cos(a)) * d, y: CGFloat(sin(a)) * d, width: s, height: s))
            }
            inside.fill(dust, with: .color(.white.opacity(0.45 * (1 - bake))))
            for d in sim.dimples {
                let e = CGRect(x: d.x - 9, y: d.y - 8, width: 18, height: 16)
                inside.fill(Path(ellipseIn: e), with: .color(RGB(0.6, 0.45, 0.3).color.opacity(0.14 * (1 - bake))))
                inside.stroke(Path(ellipseIn: e.offsetBy(dx: 1, dy: 1.5)), with: .color(.white.opacity(0.3 * (1 - bake))), lineWidth: 1.5)
            }
        }
        let box = CGRect(x: -PGeo.half, y: -PGeo.half, width: PGeo.half * 2, height: PGeo.half * 2)
        if let img = grids.sauce(sim) {
            inside.draw(Image(decorative: img, scale: 1).interpolation(.high), in: box)
        }
        let melt = sim.melt
        if sim.landed > 0 {
            if melt < 0.99, let shreds = sim.shredLayer.image {
                var sg = inside
                sg.opacity = 1 - melt
                sg.draw(Image(decorative: shreds, scale: ShredLayer.scale).interpolation(.medium), in: box)
            }
            if melt > 0.01, let img = grids.cheese(sim) {
                inside.draw(Image(decorative: img, scale: 1).interpolation(.high), in: box)
            }
        }
        // bubbles in the melting cheese
        for b in sim.bubbles {
            let u = b.age / b.life
            let s = b.size * CGFloat(sqrt(sin(.pi * min(1, u * 1.15))))
            guard s > 0.5 else { continue }
            let e = CGRect(x: b.x - s, y: b.y - s, width: s * 2, height: s * 2)
            inside.fill(Path(ellipseIn: e), with: .radialGradient(Gradient(colors: [RGB(1, 0.97, 0.78).color, RGB(0.99, 0.84, 0.46).color]),
                                                                center: CGPoint(x: b.x - s * 0.3, y: b.y - s * 0.35), startRadius: 0, endRadius: s))
            inside.stroke(Path(ellipseIn: e), with: .color(RGB(0.8, 0.56, 0.22).color.opacity(0.55)), lineWidth: 1)
            inside.fill(Path(ellipseIn: CGRect(x: b.x - s * 0.5, y: b.y - s * 0.6, width: s * 0.5, height: s * 0.4)), with: .color(.white.opacity(0.8)))
        }
        // toppings
        for tp in sim.toppings {
            drawPlaced(inside, tp, sim: sim)
        }
        // charred blisters on the rim (leopard spots)
        let brown = sim.brown
        if brown > 0.02 {
            var r = SeededRandom(41)
            var spots = Path()
            var dark = Path()
            for i in 0..<54 {
                let a = r.unit() * 2 * .pi
                let edge = sim.edge(a)
                let d = edge - CGFloat(r.unit()) * rim * 1.1 - 2
                let s = 2.5 + CGFloat(r.unit()) * 6
                let c = CGPoint(x: CGFloat(cos(a)) * d, y: CGFloat(sin(a)) * d)
                spots.addEllipse(in: CGRect(x: c.x - s, y: c.y - s * 0.8, width: s * 2, height: s * 1.6))
                if i % 3 == 0 { dark.addEllipse(in: CGRect(x: c.x - s * 0.5, y: c.y - s * 0.4, width: s, height: s * 0.8)) }
            }
            inside.fill(spots, with: .color(RGB(0.55, 0.3, 0.13).color.opacity(0.55 * brown)))
            inside.fill(dark, with: .color(RGB(0.24, 0.13, 0.07).color.opacity(0.7 * brown)))
        }
        // a soft light from the top left over the whole pizza
        inside.fill(path, with: .linearGradient(Gradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.10)]),
                                                startPoint: CGPoint(x: -R, y: -R), endPoint: CGPoint(x: R, y: R)))
        // cuts
        if !sim.cuts.isEmpty {
            var cut = Path()
            for a in sim.cuts {
                let dx = CGFloat(cos(a)) * (PGeo.maxR + 10), dy = CGFloat(sin(a)) * (PGeo.maxR + 10)
                cut.move(to: CGPoint(x: -dx, y: -dy))
                cut.addLine(to: CGPoint(x: dx, y: dy))
            }
            inside.stroke(cut, with: .color(RGB(0.35, 0.14, 0.06).color.opacity(0.55)), lineWidth: 3.2)
            inside.stroke(cut.offsetBy(dx: -1, dy: -1.6), with: .color(.white.opacity(0.22)), lineWidth: 1.2)
        }
        // the groove the cutter is rolling
        let c = PGeo.center
        if sim.stroke.count > 1 {
            var p = Path()
            p.addLines(sim.stroke.map { CGPoint(x: $0.x - c.x, y: $0.y - c.y) })
            inside.stroke(p, with: .color(RGB(0.35, 0.14, 0.06).color.opacity(0.5)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        if let gr = sim.groove, sim.time - gr.at < 0.6 {
            var p = Path()
            p.addLines(gr.pts.map { CGPoint(x: $0.x - c.x, y: $0.y - c.y) })
            inside.stroke(p, with: .color(RGB(0.35, 0.14, 0.06).color.opacity(0.5 * (1 - (sim.time - gr.at) / 0.6))),
                          style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        g.stroke(path, with: .color(base.mul(0.66, 0.55, 0.45).color.opacity(0.8)), lineWidth: 2)
    }

    static func drawPlaced(_ g: GraphicsContext, _ tp: PizzaTopping, sim: PizzaSim) {
        let c = PGeo.center
        var x = tp.x - c.x, y = tp.y - c.y
        let age = sim.time - tp.born
        var s = tp.scale
        var lift: CGFloat = 0
        if let f = tp.from, age < 0.4 {
            // flying in from the tray in a little arc
            let u = CGFloat(max(0, age) / 0.4)
            let e = u * u * (3 - 2 * u)
            x = (f.x - c.x) + (x - (f.x - c.x)) * e
            y = (f.y - c.y) + (y - (f.y - c.y)) * e
            lift = sin(.pi * e) * 70
            s *= 1 + 0.3 * (1 - e)
        } else {
            let a = age - (tp.from == nil ? 0 : 0.4)
            if a >= 0 && a < 0.5 {
                // landing squash
                s *= 1 + 0.14 * CGFloat(sin(a * 22) * exp(-a * 9))
            }
        }
        var tg = g
        tg.translateBy(x: x, y: y - lift)
        tg.rotate(by: .degrees(tp.rot))
        tg.scaleBy(x: s, y: s)
        topping(tg, tp.kind, seed: tp.seed, bake: sim.bake, lifted: lift / 70)
    }

    // MARK: - Toppings (drawn around 0,0, about 50 pt across)

    static func topping(_ ctx: GraphicsContext, _ k: ToppingKind, seed: Int, bake: Double, lifted: CGFloat = 0) {
        var g = ctx
        var r = SeededRandom(seed)
        let b = bake
        let shadowOff = 2 + lifted * 14
        let shadow = Color.black.opacity(0.2 * Double(1 - lifted * 0.5))
        switch k {
        case .pepperoni:
            let rr = 23 * (1 - 0.08 * CGFloat(b))
            let disc = Path(ellipseIn: CGRect(x: -rr, y: -rr, width: rr * 2, height: rr * 2))
            g.fill(disc.offsetBy(dx: shadowOff * 0.6, dy: shadowOff), with: .color(shadow))
            if b > 0.05 {
                let gr = rr + 5
                g.fill(Path(ellipseIn: CGRect(x: -gr, y: -gr, width: gr * 2, height: gr * 2)), with: .color(RGB(0.95, 0.5, 0.12).color.opacity(0.28 * b)))
            }
            let c1 = RGB(0.86, 0.26, 0.2).mix(RGB(0.7, 0.17, 0.1), b)
            let c2 = RGB(0.7, 0.15, 0.12).mix(RGB(0.48, 0.09, 0.06), b)
            g.fill(disc, with: .radialGradient(Gradient(colors: [c1.color, c2.color]), center: CGPoint(x: -rr * 0.3, y: -rr * 0.3), startRadius: 0, endRadius: rr * 1.3))
            var fat = Path()
            for _ in 0..<9 {
                let a = r.unit() * 2 * .pi
                let d = CGFloat(sqrt(r.unit())) * rr * 0.78
                let s = 1.4 + CGFloat(r.unit()) * 2
                fat.addEllipse(in: CGRect(x: CGFloat(cos(a)) * d - s, y: CGFloat(sin(a)) * d - s, width: s * 2, height: s * 2 * 0.8))
            }
            g.fill(fat, with: .color(RGB(0.99, 0.74, 0.66).color.opacity(0.85 - 0.35 * b)))
            g.stroke(Path(ellipseIn: CGRect(x: -rr + 1.5, y: -rr + 1.5, width: rr * 2 - 3, height: rr * 2 - 3)),
                     with: .color(RGB(0.4, 0.07, 0.04).color.opacity(0.25 + 0.55 * b)), lineWidth: 2 + 2.5 * CGFloat(b))
            // cupped and glossy when baked
            if b > 0.05 {
                g.fill(Path(ellipseIn: CGRect(x: -rr * 0.6, y: -rr * 0.68, width: rr * 0.72, height: rr * 0.42)),
                       with: .color(.white.opacity(0.4 * b)))
                g.stroke(Path(ellipseIn: CGRect(x: -rr * 0.7, y: -rr * 0.7, width: rr * 1.4, height: rr * 1.4)),
                         with: .color(.black.opacity(0.12 * b)), lineWidth: 3)
            }
        case .mushroom:
            g.scaleBy(x: 1 - 0.08 * CGFloat(b), y: 1 - 0.08 * CGFloat(b))
            var cap = Path()
            cap.move(to: CGPoint(x: -24, y: 2))
            cap.addCurve(to: CGPoint(x: 24, y: 2), control1: CGPoint(x: -24, y: -26), control2: CGPoint(x: 24, y: -26))
            cap.addQuadCurve(to: CGPoint(x: 9, y: 4), control: CGPoint(x: 16, y: 7))
            cap.addLine(to: CGPoint(x: 8, y: 18))
            cap.addQuadCurve(to: CGPoint(x: -8, y: 18), control: CGPoint(x: 0, y: 23))
            cap.addLine(to: CGPoint(x: -9, y: 4))
            cap.addQuadCurve(to: CGPoint(x: -24, y: 2), control: CGPoint(x: -16, y: 7))
            cap.closeSubpath()
            g.fill(cap.offsetBy(dx: shadowOff * 0.6, dy: shadowOff), with: .color(shadow))
            let m = RGB(0.94, 0.88, 0.77).mix(RGB(0.78, 0.63, 0.46), b)
            g.fill(cap, with: .linearGradient(Gradient(colors: [m.mix(RGB(1, 1, 1), 0.2).color, m.color]), startPoint: CGPoint(x: 0, y: -18), endPoint: CGPoint(x: 0, y: 18)))
            var gills = Path()
            for i in -3...3 {
                gills.move(to: CGPoint(x: CGFloat(i) * 2.6, y: -12 + abs(CGFloat(i)) * 1.4))
                gills.addLine(to: CGPoint(x: CGFloat(i) * 5.5, y: 1))
            }
            g.stroke(gills, with: .color(RGB(0.6, 0.46, 0.32).color.opacity(0.5)), lineWidth: 1.2)
            g.stroke(cap, with: .color(RGB(0.5, 0.36, 0.24).mix(RGB(0.35, 0.22, 0.12), b).color), lineWidth: 3)
        case .olive:
            var ring = Path(ellipseIn: CGRect(x: -12, y: -12, width: 24, height: 24))
            ring.addEllipse(in: CGRect(x: -5, y: -5, width: 10, height: 10))
            g.fill(ring.offsetBy(dx: shadowOff * 0.5, dy: shadowOff * 0.8), with: .color(shadow), style: FillStyle(eoFill: true))
            g.fill(ring, with: .radialGradient(Gradient(colors: [RGB(0.3, 0.27, 0.28).color, RGB(0.1, 0.08, 0.09).color]),
                                               center: CGPoint(x: -4, y: -4), startRadius: 0, endRadius: 14), style: FillStyle(eoFill: true))
            var hl = Path()
            hl.addArc(center: .zero, radius: 8.5, startAngle: .degrees(195), endAngle: .degrees(260), clockwise: false)
            g.stroke(hl, with: .color(.white.opacity(0.55 + 0.2 * b)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .pepper:
            var arc = Path()
            arc.addArc(center: CGPoint(x: 0, y: 10), radius: 19, startAngle: .degrees(195), endAngle: .degrees(345), clockwise: false)
            g.stroke(arc.offsetBy(dx: shadowOff * 0.6, dy: shadowOff), with: .color(shadow), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            let gr = RGB(0.22, 0.6, 0.22).mix(RGB(0.2, 0.42, 0.14), b)
            g.stroke(arc, with: .color(gr.color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            g.stroke(arc, with: .color(gr.mix(RGB(0.8, 1, 0.7), 0.45).color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            if b > 0.3 {
                var bl = Path()
                for _ in 0..<3 {
                    let a = (195 + r.unit() * 150) * .pi / 180
                    bl.addEllipse(in: CGRect(x: CGFloat(cos(a)) * 19 - 2, y: 10 + CGFloat(sin(a)) * 19 - 2, width: 4, height: 4))
                }
                g.fill(bl, with: .color(RGB(0.15, 0.2, 0.08).color.opacity(0.7 * b)))
            }
        case .pineapple:
            var w = Path()
            w.move(to: CGPoint(x: -15, y: -12))
            w.addQuadCurve(to: CGPoint(x: 15, y: -12), control: CGPoint(x: 0, y: -16))
            w.addLine(to: CGPoint(x: 10, y: 13))
            w.addQuadCurve(to: CGPoint(x: -10, y: 13), control: CGPoint(x: 0, y: 15))
            w.closeSubpath()
            g.fill(w.offsetBy(dx: shadowOff * 0.6, dy: shadowOff), with: .color(shadow))
            let y1 = RGB(1.0, 0.88, 0.38).mix(RGB(0.95, 0.72, 0.28), b)
            g.fill(w, with: .linearGradient(Gradient(colors: [y1.mix(RGB(1, 1, 0.9), 0.35).color, y1.color, y1.mul(0.92, 0.82, 0.6).color]),
                                            startPoint: CGPoint(x: 0, y: -14), endPoint: CGPoint(x: 0, y: 14)))
            var fib = Path()
            for i in -2...2 {
                fib.move(to: CGPoint(x: CGFloat(i) * 5.5, y: -11))
                fib.addLine(to: CGPoint(x: CGFloat(i) * 3.6, y: 11))
            }
            g.stroke(fib, with: .color(RGB(0.9, 0.66, 0.18).color.opacity(0.6)), lineWidth: 1)
            g.stroke(w, with: .color(RGB(0.84, 0.6, 0.16).mix(RGB(0.62, 0.35, 0.1), b).color), lineWidth: 2 + 2 * CGFloat(b))
        case .basil:
            let s = 1 - 0.14 * CGFloat(b)
            g.scaleBy(x: s, y: s)
            var leaf = Path()
            leaf.move(to: CGPoint(x: 0, y: -24))
            leaf.addQuadCurve(to: CGPoint(x: 0, y: 22), control: CGPoint(x: 22, y: -4))
            leaf.addQuadCurve(to: CGPoint(x: 0, y: -24), control: CGPoint(x: -22, y: -4))
            leaf.closeSubpath()
            g.fill(leaf.offsetBy(dx: shadowOff * 0.6, dy: shadowOff), with: .color(shadow))
            let l1 = RGB(0.3, 0.66, 0.28).mix(RGB(0.12, 0.32, 0.12), b)
            let l2 = RGB(0.16, 0.46, 0.18).mix(RGB(0.07, 0.2, 0.07), b)
            g.fill(leaf, with: .linearGradient(Gradient(colors: [l1.color, l2.color]), startPoint: CGPoint(x: -10, y: -20), endPoint: CGPoint(x: 10, y: 20)))
            var vein = Path()
            vein.move(to: CGPoint(x: 0, y: -20))
            vein.addLine(to: CGPoint(x: 0, y: 20))
            for i in 0..<3 {
                let y = -10 + CGFloat(i) * 9
                vein.move(to: CGPoint(x: 0, y: y + 4))
                vein.addLine(to: CGPoint(x: 8, y: y - 2))
                vein.move(to: CGPoint(x: 0, y: y + 4))
                vein.addLine(to: CGPoint(x: -8, y: y - 2))
            }
            g.stroke(vein, with: .color(l1.mix(RGB(1, 1, 0.85), 0.4).color.opacity(0.7)), lineWidth: 1.2)
            g.fill(Path(ellipseIn: CGRect(x: -7, y: -15, width: 6, height: 12)), with: .color(.white.opacity(0.18 + 0.15 * b)))
        case .tomato:
            let rr: CGFloat = 21 * (1 - 0.06 * CGFloat(b))
            let disc = Path(ellipseIn: CGRect(x: -rr, y: -rr, width: rr * 2, height: rr * 2))
            g.fill(disc.offsetBy(dx: shadowOff * 0.6, dy: shadowOff), with: .color(shadow))
            let t1 = RGB(0.95, 0.32, 0.22).mix(RGB(0.78, 0.2, 0.12), b)
            g.fill(disc, with: .color(t1.color))
            for i in 0..<4 {
                let a = Double(i) * .pi / 2 + 0.5
                let pc = CGPoint(x: CGFloat(cos(a)) * rr * 0.48, y: CGFloat(sin(a)) * rr * 0.48)
                var pg = g
                pg.translateBy(x: pc.x, y: pc.y)
                pg.rotate(by: .radians(a))
                pg.fill(Path(ellipseIn: CGRect(x: -7, y: -5, width: 14, height: 10)), with: .color(RGB(1.0, 0.56, 0.42).mix(RGB(0.9, 0.35, 0.2), b).color))
                pg.fill(Path(ellipseIn: CGRect(x: -3, y: -1.5, width: 2.6, height: 3)), with: .color(RGB(1, 0.9, 0.6).color))
                pg.fill(Path(ellipseIn: CGRect(x: 1, y: -1.5, width: 2.6, height: 3)), with: .color(RGB(1, 0.9, 0.6).color))
            }
            g.stroke(disc, with: .color(RGB(0.75, 0.14, 0.1).mix(RGB(0.45, 0.1, 0.05), b).color), lineWidth: 3)
            g.fill(Path(ellipseIn: CGRect(x: -rr * 0.6, y: -rr * 0.7, width: rr * 0.6, height: rr * 0.34)), with: .color(.white.opacity(0.35)))
        case .ham:
            let sq = Path(roundedRect: CGRect(x: -17, y: -15, width: 34, height: 30), cornerRadius: 7)
            g.rotate(by: .degrees(Double(r.int(20)) - 10))
            g.fill(sq.offsetBy(dx: shadowOff * 0.6, dy: shadowOff), with: .color(shadow))
            let h1 = RGB(0.98, 0.68, 0.68).mix(RGB(0.88, 0.5, 0.42), b)
            g.fill(sq, with: .linearGradient(Gradient(colors: [h1.mix(RGB(1, 1, 1), 0.2).color, h1.color]), startPoint: CGPoint(x: -15, y: -15), endPoint: CGPoint(x: 15, y: 15)))
            var fat = Path()
            fat.move(to: CGPoint(x: -14, y: -6))
            fat.addQuadCurve(to: CGPoint(x: 13, y: 4), control: CGPoint(x: 0, y: 6))
            g.stroke(fat, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            g.stroke(sq, with: .color(RGB(0.86, 0.48, 0.48).mix(RGB(0.62, 0.32, 0.2), b).color), lineWidth: 2 + 2 * CGFloat(b))
        }
    }

    // MARK: - Cheese strings

    static func drawStrings(_ g: GraphicsContext, sim: PizzaSim, lifted l: LiftedSlice, pose: (u: Double, dx: CGFloat, dy: CGFloat, scale: CGFloat, cx: CGFloat, cy: CGFloat)) {
        let cheese = RGB(1.0, 0.86, 0.45).mix(RGB(0.98, 0.78, 0.38), sim.melt)
        for s in l.strings {
            let a = s.at
            let b = CGPoint(x: pose.cx + pose.dx + (a.x - pose.cx) * pose.scale, y: pose.cy + pose.dy + (a.y - pose.cy) * pose.scale)
            let dist = hypot(b.x - a.x, b.y - a.y)
            if let br = s.broke {
                // the two broken ends spring back
                let u = CGFloat(min(1, (sim.time - br) / 0.3))
                guard u < 1 else { continue }
                let len = (1 - u) * 0.45
                var p = Path()
                p.move(to: a)
                p.addQuadCurve(to: CGPoint(x: a.x + (b.x - a.x) * len, y: a.y + (b.y - a.y) * len + 10 * (1 - u)),
                               control: CGPoint(x: a.x + (b.x - a.x) * len * 0.5, y: a.y + (b.y - a.y) * len * 0.5 + 14))
                p.move(to: b)
                p.addQuadCurve(to: CGPoint(x: b.x + (a.x - b.x) * len, y: b.y + (a.y - b.y) * len + 10 * (1 - u)),
                               control: CGPoint(x: b.x + (a.x - b.x) * len * 0.5, y: b.y + (a.y - b.y) * len * 0.5 + 14))
                g.stroke(p, with: .color(cheese.color), style: StrokeStyle(lineWidth: s.width, lineCap: .round))
                continue
            }
            let thin = max(0.35, 1 - dist / s.breakAt * 0.7)
            var p = Path()
            p.move(to: a)
            p.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + 12 + dist * 0.12))
            g.stroke(p, with: .color(cheese.mul(0.85, 0.75, 0.6).color), style: StrokeStyle(lineWidth: s.width * thin + 1, lineCap: .round))
            g.stroke(p, with: .color(cheese.color), style: StrokeStyle(lineWidth: s.width * thin, lineCap: .round))
        }
    }

    // MARK: - The oven

    static func drawOven(_ ctx: GraphicsContext, map: GMap, sim: PizzaSim, grids: PizzaGrids) {
        var g = ctx
        let t = sim.time
        let v = map.visible.insetBy(dx: -4, dy: -4)
        let flicker = 0.5 + 0.25 * sin(t * 13) + 0.15 * sin(t * 29 + 1) + 0.1 * sin(t * 7.3)
        let glow = 0.75 + 0.25 * flicker + 0.5 * sim.flare
        // the brick front of the oven
        g.fill(Path(v), with: .linearGradient(Gradient(colors: [RGB(0.62, 0.32, 0.22).color, RGB(0.5, 0.25, 0.17).color]),
                                              startPoint: CGPoint(x: 0, y: v.minY), endPoint: CGPoint(x: 0, y: v.maxY)))
        var mortar = Path()
        var row = 0
        var y = floor(v.minY / 32) * 32
        while y < v.maxY {
            mortar.move(to: CGPoint(x: v.minX, y: y))
            mortar.addLine(to: CGPoint(x: v.maxX, y: y))
            var x = floor(v.minX / 70) * 70 + (row % 2 == 0 ? 0 : 35)
            while x < v.maxX {
                mortar.move(to: CGPoint(x: x, y: y))
                mortar.addLine(to: CGPoint(x: x, y: y + 32))
                x += 70
            }
            y += 32
            row += 1
        }
        g.stroke(mortar, with: .color(RGB(0.82, 0.72, 0.62).color.opacity(0.55)), lineWidth: 3)
        // the opening
        var arch = Path()
        arch.move(to: CGPoint(x: 110, y: v.maxY + 10))
        arch.addLine(to: CGPoint(x: 110, y: 420))
        arch.addArc(center: CGPoint(x: 512, y: 430), radius: 402, startAngle: .degrees(181.4), endAngle: .degrees(358.6), clockwise: false)
        arch.addLine(to: CGPoint(x: 914, y: v.maxY + 10))
        arch.closeSubpath()
        var inside = g
        inside.clip(to: arch)
        let fire = CGPoint(x: 315, y: 300)
        inside.fill(Path(v), with: .radialGradient(Gradient(colors: [RGB(0.78, 0.36, 0.12).color, RGB(0.34, 0.13, 0.07).color, RGB(0.12, 0.05, 0.04).color]),
                                                   center: fire, startRadius: 20, endRadius: 640))
        // the dome's bricks, dimly lit
        var dome = Path()
        for i in 1..<7 {
            let rr = 70 + CGFloat(i) * 52
            dome.addArc(center: CGPoint(x: 512, y: 470), radius: rr, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
        }
        inside.stroke(dome, with: .color(.black.opacity(0.22)), lineWidth: 3)
        // the stone floor
        let floorR = CGRect(x: 512 - 470, y: 600 - 230, width: 940, height: 470)
        inside.fill(Path(ellipseIn: floorR), with: .radialGradient(Gradient(colors: [RGB(0.62, 0.42, 0.3).color, RGB(0.42, 0.27, 0.18).color, RGB(0.2, 0.12, 0.08).color]),
                                                                    center: CGPoint(x: 360, y: 420), startRadius: 10, endRadius: 560))
        var soot = Path()
        var r = SeededRandom(8)
        for _ in 0..<26 {
            let p = CGPoint(x: 140 + CGFloat(r.unit()) * 740, y: 440 + CGFloat(r.unit()) * 330)
            let s = 6 + CGFloat(r.unit()) * 20
            soot.addEllipse(in: CGRect(x: p.x - s, y: p.y - s * 0.4, width: s * 2, height: s * 0.8))
        }
        inside.fill(soot, with: .color(.black.opacity(0.12)))
        // logs and embers
        drawLogs(inside, at: CGPoint(x: 315, y: 338), time: t, glow: glow)
        // the pizza on the floor (it slides in from the front)
        var pg = inside
        pg.translateBy(x: PGeo.ovenCenter.x, y: PGeo.ovenCenter.y + CGFloat(1 - sim.ovenSlide) * 260)
        pg.scaleBy(x: PGeo.ovenScale, y: PGeo.ovenScale * PGeo.ovenSquash)
        drawWholePizza(pg, sim: sim, grids: grids, onBoard: false)
        // flames
        var fl = inside
        fl.blendMode = .plusLighter
        for f in sim.flames {
            let u = f.age / f.life
            if f.spark {
                let a = (1 - u) * (0.6 + 0.4 * sin(t * 40 + Double(f.x)))
                fl.fill(Path(ellipseIn: CGRect(x: f.x - f.size, y: f.y - f.size, width: f.size * 2, height: f.size * 2)),
                        with: .color(RGB(1, 0.8, 0.4).color.opacity(a)))
                continue
            }
            let s = f.size * CGFloat(1 - u * 0.65)
            let col: RGB = u < 0.25 ? RGB(1, 0.92, 0.62).mix(RGB(1, 0.66, 0.2), u / 0.25) : RGB(1, 0.66, 0.2).mix(RGB(0.85, 0.2, 0.05), min(1, (u - 0.25) / 0.6))
            let a = 0.55 * (u < 0.1 ? u / 0.1 : 1 - u)
            fl.fill(Path(ellipseIn: CGRect(x: f.x - s * 0.7, y: f.y - s * 1.1, width: s * 1.4, height: s * 2.2)),
                    with: .radialGradient(Gradient(colors: [col.color.opacity(a), col.color.opacity(0)]), center: CGPoint(x: f.x, y: f.y), startRadius: 0, endRadius: s * 1.1))
        }
        // fire light washing over the oven and the pizza
        fl.fill(Path(v), with: .radialGradient(Gradient(colors: [RGB(1, 0.55, 0.2).color.opacity(0.32 * glow), RGB(1, 0.45, 0.15).color.opacity(0.1 * glow), .clear]),
                                               center: fire, startRadius: 0, endRadius: 700))
        // heat shimmer: faint wavy lines rising over the pizza
        var shimmer = inside
        shimmer.opacity = 0.08 + 0.05 * sim.melt
        var wv = Path()
        for i in 0..<5 {
            let x0 = 330 + CGFloat(i) * 90
            let ph = t * 3 + Double(i)
            wv.move(to: CGPoint(x: x0, y: 560))
            for k in 1...8 {
                let yy = 560 - CGFloat(k) * 30
                wv.addLine(to: CGPoint(x: x0 + CGFloat(sin(ph + Double(k) * 0.8)) * 8, y: yy))
            }
        }
        shimmer.stroke(wv, with: .color(.white), lineWidth: 3)
        // the arch's bricks
        var ring = Path()
        ring.move(to: CGPoint(x: 110, y: v.maxY + 10))
        ring.addLine(to: CGPoint(x: 110, y: 420))
        ring.addArc(center: CGPoint(x: 512, y: 430), radius: 402, startAngle: .degrees(181.4), endAngle: .degrees(358.6), clockwise: false)
        ring.addLine(to: CGPoint(x: 914, y: v.maxY + 10))
        g.stroke(ring, with: .color(RGB(0.68, 0.36, 0.24).color), lineWidth: 46)
        g.stroke(ring, with: .color(RGB(0.84, 0.74, 0.64).color.opacity(0.8)), style: StrokeStyle(lineWidth: 46, dash: [3, 44]))
        g.stroke(ring.offsetBy(dx: 0, dy: 0), with: .color(RGB(1, 0.6, 0.3).color.opacity(0.18 * glow)), lineWidth: 8)
    }

    static func drawLogs(_ ctx: GraphicsContext, at p: CGPoint, time t: Double, glow: Double) {
        var g = ctx
        g.translateBy(x: p.x, y: p.y)
        let logs: [(CGFloat, CGFloat, Double)] = [(-40, 6, -0.25), (36, 8, 0.3), (0, -4, 0.04)]
        for (x, y, a) in logs {
            var lg = g
            lg.translateBy(x: x, y: y)
            lg.rotate(by: .radians(a))
            let body = Path(roundedRect: CGRect(x: -70, y: -14, width: 140, height: 28), cornerRadius: 14)
            lg.fill(body, with: .linearGradient(Gradient(colors: [RGB(0.32, 0.18, 0.1).color, RGB(0.16, 0.08, 0.05).color]),
                                                startPoint: CGPoint(x: 0, y: -14), endPoint: CGPoint(x: 0, y: 14)))
            lg.fill(Path(ellipseIn: CGRect(x: 56, y: -14, width: 22, height: 28)), with: .color(RGB(0.55, 0.36, 0.2).color))
            // glowing cracks of ember
            var cracks = Path()
            cracks.move(to: CGPoint(x: -50, y: 6)); cracks.addLine(to: CGPoint(x: -20, y: 2)); cracks.addLine(to: CGPoint(x: 6, y: 8))
            cracks.move(to: CGPoint(x: 14, y: -2)); cracks.addLine(to: CGPoint(x: 44, y: 4))
            var eg = lg
            eg.blendMode = .plusLighter
            eg.stroke(cracks, with: .color(RGB(1, 0.45, 0.1).color.opacity(0.5 + 0.4 * glow * (0.6 + 0.4 * sin(t * 6 + Double(x))))),
                      style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        var em = g
        em.blendMode = .plusLighter
        em.fill(Path(ellipseIn: CGRect(x: -110, y: 4, width: 220, height: 40)),
                with: .radialGradient(Gradient(colors: [RGB(1, 0.5, 0.15).color.opacity(0.7 * glow), .clear]), center: CGPoint(x: 0, y: 24), startRadius: 0, endRadius: 110))
    }

    // MARK: - Puffs, hearts, steam

    static func drawPuffs(_ g: GraphicsContext, sim: PizzaSim) {
        guard !sim.puffs.isEmpty else { return }
        let inOven = sim.ovenSlide > 0.5
        for p in sim.puffs where p.age >= 0 {
            let u = p.age / p.life
            switch p.kind {
            case .flour:
                guard !inOven else { continue }
                g.fill(Path(ellipseIn: CGRect(x: p.x - p.r, y: p.y - p.r, width: p.r * 2, height: p.r * 2)),
                       with: .radialGradient(Gradient(colors: [.white.opacity(0.55 * (1 - u)), .white.opacity(0)]), center: CGPoint(x: p.x, y: p.y), startRadius: 0, endRadius: p.r))
            case .steam, .smoke:
                let a = 0.2 * sin(.pi * u)
                g.fill(Path(ellipseIn: CGRect(x: p.x - p.r, y: p.y - p.r * 1.3, width: p.r * 2, height: p.r * 2.6)),
                       with: .radialGradient(Gradient(colors: [.white.opacity(a), .white.opacity(0)]), center: CGPoint(x: p.x, y: p.y), startRadius: 0, endRadius: p.r * 1.3))
            case .crumb:
                g.fill(Path(ellipseIn: CGRect(x: p.x - p.r, y: p.y - p.r, width: p.r * 2, height: p.r * 2)), with: .color(RGB(0.75, 0.48, 0.22).color.opacity(1 - u)))
            case .heart:
                var hg = g
                hg.translateBy(x: p.x, y: p.y)
                hg.scaleBy(x: p.r / 14 * CGFloat(0.8 + 0.3 * sin(.pi * min(1, u * 3))), y: p.r / 14 * CGFloat(0.8 + 0.3 * sin(.pi * min(1, u * 3))))
                hg.opacity = 1 - u * u
                hg.fill(heart(), with: .color(Theme.pink))
                hg.fill(Path(ellipseIn: CGRect(x: -9, y: -7, width: 6, height: 5)), with: .color(.white.opacity(0.7)))
            }
        }
    }

    static func heart() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 12))
        p.addCurve(to: CGPoint(x: -14, y: -4), control1: CGPoint(x: -6, y: 6), control2: CGPoint(x: -14, y: 3))
        p.addCurve(to: CGPoint(x: 0, y: -7), control1: CGPoint(x: -14, y: -14), control2: CGPoint(x: -3, y: -14))
        p.addCurve(to: CGPoint(x: 14, y: -4), control1: CGPoint(x: 3, y: -14), control2: CGPoint(x: 14, y: -14))
        p.addCurve(to: CGPoint(x: 0, y: 12), control1: CGPoint(x: 14, y: 3), control2: CGPoint(x: 6, y: 6))
        p.closeSubpath()
        return p
    }

    static func star(_ r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rr = i % 2 == 0 ? r : r * 0.48
            let pt = CGPoint(x: CGFloat(cos(a)) * rr, y: CGFloat(sin(a)) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    // MARK: - The customer and the order card

    static func drawCustomer(_ ctx: GraphicsContext, sim: PizzaSim) {
        var g = ctx
        let t = sim.time
        let name = PizzaOrder.customers[max(0, min(PizzaOrder.customers.count - 1, sim.order.customer))]
        let bob = CGFloat(sin(t * 2.2)) * 4
        let w = t - sim.wiggleAt
        g.translateBy(x: PGeo.customer.x, y: PGeo.customer.y + bob)
        if w < 0.5 { g.rotate(by: .radians(sin(w * 30) * 0.08 * (0.5 - w) * 2)) }
        g.scaleBy(x: 0.5, y: 0.5)
        g.translateBy(x: -200, y: -220)
        let art = BakeryArt.shared
        art.draw("cust_\(name)", in: g)
        let chewing = t < sim.chewUntil
        let happy = t < sim.happyUntil || chewing
        let blink = t.truncatingRemainder(dividingBy: 4.3) < 0.13
        art.draw(happy ? "eyes_happy" : (blink ? "eyes_blink" : "eyes_open"), in: g)
        let mouth = chewing ? (sin(t * 16) > 0 ? "mouth_chew" : "mouth_open") : (happy ? "mouth_open" : "mouth_smile")
        art.draw(mouth, in: g)
    }

    static func drawCard(_ ctx: GraphicsContext, sim: PizzaSim) {
        var g = ctx
        let c = PGeo.card
        g.translateBy(x: c.x, y: c.y)
        let card = Path(roundedRect: CGRect(x: -100, y: -78, width: 200, height: 178), cornerRadius: 28)
        var tail = Path()
        tail.move(to: CGPoint(x: -18, y: -76))
        tail.addLine(to: CGPoint(x: 0, y: -100))
        tail.addLine(to: CGPoint(x: 18, y: -76))
        tail.closeSubpath()
        g.fill(card.offsetBy(dx: 0, dy: 5), with: .color(Theme.ink.opacity(0.18)))
        g.fill(card, with: .color(.white.opacity(0.95)))
        g.fill(tail, with: .color(.white.opacity(0.95)))
        g.stroke(card, with: .color(Theme.blush), lineWidth: 4)
        // the pizza they dream of
        var pg = g
        pg.translateBy(x: 0, y: -14)
        let R: CGFloat = 54
        pg.fill(Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2)), with: .color(RGB(0.9, 0.66, 0.38).color))
        pg.fill(Path(ellipseIn: CGRect(x: -R + 8, y: -R + 8, width: R * 2 - 16, height: R * 2 - 16)), with: .color(RGB(0.82, 0.24, 0.13).color))
        var ch = Path()
        var r = SeededRandom(3)
        var pts: [CGPoint] = []
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * .pi
            let rr = (R - 14) * CGFloat(0.9 + 0.12 * r.unit())
            pts.append(CGPoint(x: CGFloat(cos(a)) * rr, y: CGFloat(sin(a)) * rr))
        }
        ch.addPath(smoothClosed(pts))
        pg.fill(ch, with: .color(RGB(0.99, 0.84, 0.45).color))
        pg.stroke(Path(ellipseIn: CGRect(x: -R, y: -R, width: R * 2, height: R * 2)), with: .color(RGB(0.62, 0.4, 0.2).color), lineWidth: 2)
        let wants = sim.order.wants
        for (j, k) in wants.enumerated() {
            for i in 0..<3 {
                let a = Double(i) * 2 * .pi / 3 + Double(j) * .pi / 3 + 0.3
                let d: CGFloat = wants.count == 1 ? 22 : (j == 0 ? 25 : 18)
                var tg = pg
                tg.translateBy(x: CGFloat(cos(a)) * d, y: CGFloat(sin(a)) * d)
                tg.scaleBy(x: 0.5, y: 0.5)
                topping(tg, k, seed: i * 7 + j, bake: 0.4)
            }
        }
        // the wanted toppings with ticks once they're on
        let n = CGFloat(wants.count)
        for (j, k) in wants.enumerated() {
            let x = (CGFloat(j) - (n - 1) / 2) * 64
            var ig = g
            ig.translateBy(x: x - 10, y: 68)
            ig.scaleBy(x: 0.7, y: 0.7)
            topping(ig, k, seed: 3, bake: 0)
            if sim.order.has(k, sim.toppings) {
                let tick = CGPoint(x: x + 16, y: 66)
                g.fill(Path(ellipseIn: CGRect(x: tick.x - 12, y: tick.y - 12, width: 24, height: 24)), with: .color(Color(hex: 0x4CC36A)))
                var tk = Path()
                tk.move(to: CGPoint(x: tick.x - 6, y: tick.y))
                tk.addLine(to: CGPoint(x: tick.x - 1.5, y: tick.y + 5))
                tk.addLine(to: CGPoint(x: tick.x + 6.5, y: tick.y - 5))
                g.stroke(tk, with: .color(.white), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            }
        }
        if let st = sim.stars {
            var sg = g
            sg.translateBy(x: 0, y: -14)
            sg.fill(Path(roundedRect: CGRect(x: -86, y: -32, width: 172, height: 64), cornerRadius: 30), with: .color(.white.opacity(0.92)))
            for i in 0..<3 {
                var s = sg
                s.translateBy(x: CGFloat(i - 1) * 54, y: i == 1 ? -6 : 2)
                let on = i < st
                s.fill(star(24), with: .color(on ? Color(hex: 0xFFC83D) : Color(hex: 0xE8DDE6)))
                s.stroke(star(24), with: .color(on ? Color(hex: 0xE09A12) : Color(hex: 0xCFC0CC)), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            }
        }
    }

    // MARK: - Falling cheese and the held tool

    static func drawFalling(_ g: GraphicsContext, sim: PizzaSim) {
        guard !sim.falling.isEmpty else { return }
        var shadows = Path()
        var bodies = Path()
        for s in sim.falling {
            let lift = s.z * 46
            let k = 1 + s.z * 0.5
            let dx = CGFloat(cos(s.ang)) * s.len / 2 * k, dy = CGFloat(sin(s.ang)) * s.len / 2 * k
            shadows.move(to: CGPoint(x: s.x - dx, y: s.y - dy))
            shadows.addLine(to: CGPoint(x: s.x + dx, y: s.y + dy))
            bodies.move(to: CGPoint(x: s.x - dx, y: s.y - dy - lift))
            bodies.addQuadCurve(to: CGPoint(x: s.x + dx, y: s.y + dy - lift), control: CGPoint(x: s.x - dy * s.curl, y: s.y + dx * s.curl - lift))
        }
        g.stroke(shadows, with: .color(.black.opacity(0.12)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        g.stroke(bodies, with: .color(RGB(0.92, 0.76, 0.36).color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        g.stroke(bodies, with: .color(RGB(1, 0.92, 0.6).color), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
    }

    static func drawTool(_ ctx: GraphicsContext, sim: PizzaSim, time t: Double) {
        guard let tool = sim.tool else { return }
        var g = ctx
        let tip = sim.tip
        let working = sim.toolDown
        switch tool {
        case .ladle:
            let a = FingerLift.turn(tip: .zero, center: CGPoint(x: 0, y: 80), finger: sim.finger, lifted: tip)
            g.translateBy(x: tip.x, y: tip.y)
            if working { g.opacity = FingerLift.seeThrough + 0.15 }
            var lg = g
            lg.rotate(by: .radians(a))
            ladle(lg, load: sim.ladleLoad)
            if working { FingerLift.drawTip(ctx, at: tip, time: t) }
        case .cutter:
            let a = FingerLift.turn(tip: .zero, center: CGPoint(x: 0, y: 90), finger: sim.finger, lifted: tip)
            g.translateBy(x: tip.x, y: tip.y)
            if working { g.opacity = FingerLift.seeThrough + 0.1 }
            var cg = g
            cg.rotate(by: .radians(a))
            cutter(cg, spin: sim.wheel)
            if working { FingerLift.drawTip(ctx, at: tip, time: t) }
        case .cheese:
            g.translateBy(x: tip.x, y: tip.y)
            g.rotate(by: .radians(working ? -0.35 + 0.06 * sin(t * 18) : 0))
            cheeseBowl(g)
        case .topping(let k):
            // her piece floats above her finger, with a shadow on the pizza
            var sg = ctx
            sg.translateBy(x: tip.x + 10, y: tip.y + 22)
            sg.opacity = 0.25
            sg.fill(Path(ellipseIn: CGRect(x: -22, y: -18, width: 44, height: 36)), with: .color(.black))
            g.translateBy(x: tip.x, y: tip.y)
            g.scaleBy(x: 1.18, y: 1.18)
            topping(g, k, seed: 11, bake: 0)
        }
    }

    /// A metal ladle, its bowl at (0, 0), handle down +y.
    static func ladle(_ g: GraphicsContext, load: CGFloat) {
        let handle = Path(roundedRect: CGRect(x: -8, y: 26, width: 16, height: 176), cornerRadius: 8)
        g.fill(handle.offsetBy(dx: 4, dy: 8), with: .color(.black.opacity(0.15)))
        g.fill(handle, with: .linearGradient(Gradient(colors: [RGB(0.92, 0.93, 0.95).color, RGB(0.64, 0.66, 0.7).color]),
                                             startPoint: CGPoint(x: -8, y: 0), endPoint: CGPoint(x: 8, y: 0)))
        g.fill(Path(ellipseIn: CGRect(x: -5, y: 182, width: 10, height: 10)), with: .color(RGB(0.45, 0.46, 0.5).color))
        let bowl = Path(ellipseIn: CGRect(x: -38, y: -34, width: 76, height: 68))
        g.fill(bowl.offsetBy(dx: 5, dy: 9), with: .color(.black.opacity(0.16)))
        g.fill(bowl, with: .radialGradient(Gradient(colors: [RGB(0.98, 0.98, 1).color, RGB(0.72, 0.74, 0.78).color, RGB(0.5, 0.52, 0.56).color]),
                                           center: CGPoint(x: -12, y: -12), startRadius: 2, endRadius: 46))
        if load > 0.02 {
            let s = 26 * sqrt(load) + 4
            g.fill(Path(ellipseIn: CGRect(x: -s, y: -s * 0.9, width: s * 2, height: s * 1.8)),
                   with: .radialGradient(Gradient(colors: [RGB(0.9, 0.3, 0.16).color, RGB(0.66, 0.12, 0.07).color]),
                                         center: CGPoint(x: -s * 0.3, y: -s * 0.3), startRadius: 0, endRadius: s * 1.2))
            g.fill(Path(ellipseIn: CGRect(x: -s * 0.55, y: -s * 0.6, width: s * 0.5, height: s * 0.3)), with: .color(.white.opacity(0.45)))
        }
        g.stroke(bowl, with: .color(RGB(0.45, 0.46, 0.5).color), lineWidth: 3)
    }

    /// A pizza wheel: the blade at (0, 0), handle down +y.
    static func cutter(_ g: GraphicsContext, spin: Double) {
        let handle = Path(roundedRect: CGRect(x: -14, y: 44, width: 28, height: 150), cornerRadius: 14)
        g.fill(handle.offsetBy(dx: 5, dy: 9), with: .color(.black.opacity(0.15)))
        let neck = Path(roundedRect: CGRect(x: -6, y: 0, width: 12, height: 56), cornerRadius: 5)
        g.fill(neck, with: .linearGradient(Gradient(colors: [RGB(0.9, 0.9, 0.93).color, RGB(0.6, 0.62, 0.66).color]),
                                           startPoint: CGPoint(x: -6, y: 0), endPoint: CGPoint(x: 6, y: 0)))
        g.fill(handle, with: .linearGradient(Gradient(colors: [Color(hex: 0xFF9CC2), Color(hex: 0xE85B93)]),
                                             startPoint: CGPoint(x: -14, y: 0), endPoint: CGPoint(x: 14, y: 0)))
        g.fill(Path(roundedRect: CGRect(x: -8, y: 54, width: 5, height: 130), cornerRadius: 2.5), with: .color(.white.opacity(0.35)))
        let wheel = Path(ellipseIn: CGRect(x: -36, y: -36, width: 72, height: 72))
        g.fill(wheel.offsetBy(dx: 4, dy: 8), with: .color(.black.opacity(0.15)))
        g.fill(wheel, with: .radialGradient(Gradient(colors: [RGB(0.98, 0.98, 1).color, RGB(0.7, 0.72, 0.76).color]),
                                            center: CGPoint(x: -10, y: -10), startRadius: 2, endRadius: 44))
        var spokes = Path()
        for i in 0..<6 {
            let a = spin + Double(i) * .pi / 3
            spokes.move(to: CGPoint(x: CGFloat(cos(a)) * 10, y: CGFloat(sin(a)) * 10))
            spokes.addLine(to: CGPoint(x: CGFloat(cos(a)) * 28, y: CGFloat(sin(a)) * 28))
        }
        g.stroke(spokes, with: .color(RGB(0.55, 0.57, 0.62).color.opacity(0.6)), lineWidth: 2)
        g.stroke(wheel, with: .color(RGB(0.45, 0.46, 0.5).color), lineWidth: 2.5)
        g.stroke(Path(ellipseIn: CGRect(x: -33, y: -33, width: 66, height: 66)), with: .color(.white.opacity(0.7)), lineWidth: 1.5)
        g.fill(Path(ellipseIn: CGRect(x: -9, y: -9, width: 18, height: 18)), with: .color(Color(hex: 0xE85B93)))
    }

    /// A wooden bowl of grated cheese, around (0, 0).
    static func cheeseBowl(_ g: GraphicsContext) {
        let bowl = Path(ellipseIn: CGRect(x: -62, y: -40, width: 124, height: 80))
        g.fill(bowl.offsetBy(dx: 5, dy: 10), with: .color(.black.opacity(0.18)))
        g.fill(bowl, with: .linearGradient(Gradient(colors: [RGB(0.72, 0.5, 0.3).color, RGB(0.5, 0.32, 0.18).color]),
                                           startPoint: CGPoint(x: 0, y: -40), endPoint: CGPoint(x: 0, y: 40)))
        let inner = Path(ellipseIn: CGRect(x: -52, y: -32, width: 104, height: 60))
        g.fill(inner, with: .color(RGB(0.42, 0.26, 0.14).color))
        var r = SeededRandom(9)
        var bodies = Path()
        for _ in 0..<44 {
            let a = r.unit() * 2 * .pi
            let d = CGFloat(sqrt(r.unit()))
            let x = CGFloat(cos(a)) * 44 * d, y = CGFloat(sin(a)) * 24 * d - 4
            let an = r.unit() * .pi
            let l: CGFloat = 8 + CGFloat(r.unit()) * 7
            bodies.move(to: CGPoint(x: x - CGFloat(cos(an)) * l / 2, y: y - CGFloat(sin(an)) * l / 2))
            bodies.addLine(to: CGPoint(x: x + CGFloat(cos(an)) * l / 2, y: y + CGFloat(sin(an)) * l / 2))
        }
        g.stroke(bodies, with: .color(RGB(0.9, 0.74, 0.34).color), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        g.stroke(bodies, with: .color(RGB(1, 0.92, 0.58).color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        g.stroke(bowl, with: .color(RGB(0.38, 0.22, 0.12).color), lineWidth: 3)
        g.stroke(Path(ellipseIn: CGRect(x: -58, y: -37, width: 116, height: 72)), with: .color(.white.opacity(0.2)), lineWidth: 2)
    }
}

// MARK: - Sauce and melted cheese as small lit bitmaps

/// Turns the sauce and cheese grids into pictures: each pixel samples the grid, is lit from the top left by the
/// slope of the surface (so thick spots look raised and wet), and gets a tiny bit of texture. Pictures are only
/// made again when their grid has changed.
final class PizzaGrids {
    static let S = 160
    private var heights = [Float](repeating: 0, count: S * S)
    private var extra = [Float](repeating: 0, count: S * S)
    private var buf = [UInt8](repeating: 0, count: S * S * 4)
    private let fleck: [Float]
    private let blotch: [Float]
    private var sauceImg: CGImage?
    private var sauceKey = ""
    private var cheeseImg: CGImage?
    private var cheeseKey = ""

    init() {
        let S = PizzaGrids.S
        var r = SeededRandom(77)
        fleck = (0..<(S * S)).map { _ in Float(r.unit()) }
        // smooth blotchy noise for browning: a coarse random grid, blended up
        let c = 18
        let coarse = (0..<(c * c)).map { _ in Float(r.unit()) }
        let fine = (0..<(c * 3 * c * 3)).map { _ in Float(r.unit()) }
        var b = [Float](repeating: 0, count: S * S)
        for y in 0..<S {
            for x in 0..<S {
                let v1 = PizzaGrids.bilinear(coarse, c, Float(x) / Float(S) * Float(c - 1), Float(y) / Float(S) * Float(c - 1))
                let v2 = PizzaGrids.bilinear(fine, c * 3, Float(x) / Float(S) * Float(c * 3 - 1), Float(y) / Float(S) * Float(c * 3 - 1))
                b[y * S + x] = v1 * 0.7 + v2 * 0.3
            }
        }
        blotch = b
    }

    static func bilinear(_ g: [Float], _ n: Int, _ fx: Float, _ fy: Float) -> Float {
        let x0 = max(0, min(n - 1, Int(fx))), y0 = max(0, min(n - 1, Int(fy)))
        let x1 = min(n - 1, x0 + 1), y1 = min(n - 1, y0 + 1)
        let tx = max(0, min(1, fx - Float(x0))), ty = max(0, min(1, fy - Float(y0)))
        let a = g[y0 * n + x0] * (1 - tx) + g[y0 * n + x1] * tx
        let b = g[y1 * n + x0] * (1 - tx) + g[y1 * n + x1] * tx
        return a * (1 - ty) + b * ty
    }

    /// Samples a sim grid at every pixel into `out`.
    private func sample(_ grid: [Float], into out: inout [Float]) {
        let S = PizzaGrids.S, G = PGeo.grid
        let k = Float(G) / Float(S)
        for y in 0..<S {
            let fy = (Float(y) + 0.5) * k - 0.5
            for x in 0..<S {
                let fx = (Float(x) + 0.5) * k - 0.5
                out[y * S + x] = PizzaGrids.bilinear(grid, G, fx, fy)
            }
        }
    }

    @inline(__always) private static func smoothstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    @inline(__always) private func put(_ i: Int, _ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        let o = i * 4
        let aa = max(0, min(1, a))
        buf[o] = UInt8(max(0, min(1, r)) * aa * 255)
        buf[o + 1] = UInt8(max(0, min(1, g)) * aa * 255)
        buf[o + 2] = UInt8(max(0, min(1, b)) * aa * 255)
        buf[o + 3] = UInt8(aa * 255)
    }

    private func makeImage() -> CGImage? {
        let S = PizzaGrids.S
        guard let provider = CGDataProvider(data: Data(buf) as CFData) else { return nil }
        return CGImage(width: S, height: S, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: S * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    func sauce(_ sim: PizzaSim) -> CGImage? {
        let bakeKey = Int(sim.bake * 40)
        let key = "\(sim.sauceVersion)-\(bakeKey)"
        if key == sauceKey { return sauceImg }
        sauceKey = key
        sample(sim.sauce, into: &heights)
        let S = PizzaGrids.S
        let roast = Float(sim.brown) * 0.35
        var any = false
        for y in 0..<S {
            for x in 0..<S {
                let i = y * S + x
                let a = heights[i]
                let alpha = PizzaGrids.smoothstep(0.1, 0.3, a)
                if alpha <= 0.001 { put(i, 0, 0, 0, 0); continue }
                any = true
                let gx = heights[y * S + min(S - 1, x + 1)] - heights[y * S + max(0, x - 1)]
                let gy = heights[min(S - 1, y + 1) * S + x] - heights[max(0, y - 1) * S + x]
                let shade = max(-0.35, min(0.4, (gx + gy) * 1.6))
                let spec = max(0, shade - 0.14) * max(0, shade - 0.14) * 4
                let t = max(0, min(1, (a - 0.25) / 1.1))
                var r = 0.88 - 0.24 * t, g = 0.28 - 0.17 * t, b = 0.13 - 0.07 * t
                r -= roast * 0.25; g -= roast * 0.1; b -= roast * 0.05
                let f = fleck[i]
                if f > 0.988 && a > 0.25 { r = 0.3; g = 0.3; b = 0.12 }          // oregano
                else if f > 0.978 && a > 0.25 { r *= 0.8; g *= 0.6; b *= 0.6 }   // a bit of tomato skin
                let edge = 1 - 0.18 * (1 - alpha)
                let l = (1 + shade * 0.8) * edge
                put(i, r * l + spec, g * l + spec * 0.85, b * l + spec * 0.8, alpha)
            }
        }
        sauceImg = any ? makeImage() : nil
        return sauceImg
    }

    func cheese(_ sim: PizzaSim) -> CGImage? {
        let key = "\(sim.cheeseVersion)-\(Int(sim.bake * 60))"
        if key == cheeseKey { return cheeseImg }
        cheeseKey = key
        sample(sim.cheese, into: &heights)
        sample(sim.browned, into: &extra)
        let S = PizzaGrids.S
        let melt = Float(sim.melt)
        let brown = Float(sim.brown)
        for y in 0..<S {
            for x in 0..<S {
                let i = y * S + x
                let a = heights[i]
                let alpha = PizzaGrids.smoothstep(0.05, 0.2, a) * melt
                if alpha <= 0.001 { put(i, 0, 0, 0, 0); continue }
                let gx = heights[y * S + min(S - 1, x + 1)] - heights[y * S + max(0, x - 1)]
                let gy = heights[min(S - 1, y + 1) * S + x] - heights[max(0, y - 1) * S + x]
                let shade = max(-0.3, min(0.45, (gx + gy) * 2.4))
                let spec = max(0, shade - 0.1) * max(0, shade - 0.1) * 5 * melt
                let thick = max(0, min(1, (a - 0.2) / 0.6))
                var r: Float = 1.0, g: Float = 0.87 - 0.06 * thick, b: Float = 0.5 - 0.12 * thick
                // browning: blotchy, more where it's thin and where bubbles popped
                var bAmt = brown * (0.15 + 0.55 * blotch[i] * blotch[i] + 0.3 * (1 - thick)) + extra[i] * brown * 0.9
                bAmt = max(0, min(1, bAmt))
                let b1 = min(1, bAmt * 1.6)
                r += (0.86 - r) * b1; g += (0.56 - g) * b1; b += (0.2 - b) * b1
                if bAmt > 0.62 {
                    let d = min(1, (bAmt - 0.62) / 0.3)
                    r += (0.6 - r) * d; g += (0.34 - g) * d; b += (0.12 - b) * d
                }
                let l = 1 + shade * 0.6
                put(i, r * l + spec, g * l + spec * 0.95, b * l + spec * 0.8, alpha * (0.85 + 0.15 * thick))
            }
        }
        cheeseImg = makeImage()
        return cheeseImg
    }
}
