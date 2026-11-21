import SwiftUI

// MARK: - Potion Lab drawing
//
// Two layers like the Garden and the Aquarium: the room (wall, window, shelves, table) at 30 fps, and everything
// that moves at 60 fps. The potion is a small picture made from the fluid's pigment every frame (`PotionLiquid`),
// drawn smooth, clipped to the inside of the glass below the wavy surface. Things in the potion are drawn first
// so the potion tints them; bubbles and glitter go on top of it, then the front of the glass.

/// The design frame (1024 x 834) scaled to the screen; wider screens show more of the room at the sides.
struct PMap {
    let size: CGSize
    let s: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    init(size: CGSize) {
        self.size = size
        let h = DesignCanvas<EmptyView>.designHeight
        let scale = max(0.1, size.height / h)
        let w = max(1024, size.width / scale)
        s = min(scale, size.width / w)
        ox = size.width / 2 - 512 * s
        oy = size.height / 2 - 417 * s
    }

    func design(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - ox) / s, y: (p.y - oy) / s) }
    var visible: CGRect { CGRect(x: -ox / s, y: -oy / s, width: size.width / s, height: size.height / s) }
}

extension RGB {
    func c(_ a: Double = 1) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

/// The potion as a small picture (one pixel per fluid cell), made again only when the pigment changed.
final class PotionLiquid {
    private var buf = [UInt8](repeating: 0, count: PGeo.NX * PGeo.NY * 4)
    private var img: CGImage?
    private var key = -1

    func image(_ sim: PotionSim) -> CGImage? {
        if key == sim.version, let i = img { return i }
        key = sim.version
        let n = PGeo.NX * PGeo.NY
        let water = PIngredient.water.color
        for k in 0..<n {
            let a = sim.da[k]
            let o = k * 4
            if sim.solid[k] && a <= 0.0001 && sim.dr[k] == 0 {
                buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0; buf[o + 3] = 0
                continue
            }
            var r = water.r, g = water.g, b = water.b
            if a > 0.002 {
                let m = Double(min(1, a * 2.2))
                r += (Double(sim.dr[k] / a) - r) * m
                g += (Double(sim.dg[k] / a) - g) * m
                b += (Double(sim.db[k] / a) - b) * m
            }
            let op = 0.2 + 0.72 * (1 - exp(-1.5 * Double(a)))
            buf[o] = UInt8(max(0, min(1, r)) * op * 255)
            buf[o + 1] = UInt8(max(0, min(1, g)) * op * 255)
            buf[o + 2] = UInt8(max(0, min(1, b)) * op * 255)
            buf[o + 3] = UInt8(op * 255)
        }
        guard let provider = CGDataProvider(data: Data(buf) as CFData) else { return nil }
        img = CGImage(width: PGeo.NX, height: PGeo.NY, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: PGeo.NX * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                      provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        return img
    }
}

enum PotionPainter {
    static let wood = RGB(hex: "#B9825A")
    static let woodDark = RGB(hex: "#8A5A3C")
    static let brass = RGB(hex: "#E2B45A")
    static let brassDark = RGB(hex: "#A87A2E")
    static let glassLine = RGB(hex: "#EDE6FF")

    // MARK: - The room (slow layer)

    static func drawBackdrop(_ ctx: GraphicsContext, map: PMap, sim: PotionSim) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let r = map.visible
        let n = Double(sim.night)
        let t = CGFloat(sim.time)
        // the wall
        let top = RGB(hex: "#C7B0EC").mix(RGB(hex: "#3A2C62"), n)
        let bottom = RGB(hex: "#AE92DA").mix(RGB(hex: "#2A2048"), n)
        g.fill(Path(r), with: .linearGradient(Gradient(colors: [top.c(), bottom.c()]), startPoint: CGPoint(x: 0, y: r.minY), endPoint: CGPoint(x: 0, y: 700)))
        // soft stone blocks
        var stones = Path()
        var row = 0
        var y: CGFloat = 0
        while y < 700 {
            let off: CGFloat = row % 2 == 0 ? 0 : 60
            var x = r.minX - 120 + off
            while x < r.maxX {
                stones.addRoundedRect(in: CGRect(x: x + 3, y: y + 3, width: 114, height: 52), cornerSize: CGSize(width: 14, height: 14))
                x += 120
            }
            y += 58
            row += 1
        }
        g.stroke(stones, with: .color(.white.opacity(0.10 - 0.05 * n)), lineWidth: 3)
        window(g, n, t)
        // fairy lights along the top of the wall
        lights(g, r, n, t)
        // shelves
        for x0 in [CGFloat(14), 698] {
            for sy in [CGFloat(262), 420] {
                let board = CGRect(x: x0, y: sy, width: 312, height: 16)
                g.fill(Path(roundedRect: board, cornerRadius: 5), with: .color(wood.c()))
                g.fill(Path(CGRect(x: x0 + 4, y: sy + 12, width: 304, height: 4)), with: .color(woodDark.c(0.6)))
                g.fill(Path(roundedRect: CGRect(x: x0, y: sy, width: 312, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.25)))
                for bx in [x0 + 30, x0 + 270] {
                    var br = Path()
                    br.move(to: CGPoint(x: bx, y: sy + 16))
                    br.addLine(to: CGPoint(x: bx + 12, y: sy + 16))
                    br.addLine(to: CGPoint(x: bx + 12, y: sy + 44))
                    br.closeSubpath()
                    g.fill(br, with: .color(woodDark.c()))
                }
            }
        }
        // the table
        let tableTop = CGRect(x: r.minX, y: PGeo.tableY - 4, width: r.width, height: 30)
        g.fill(Path(tableTop), with: .linearGradient(Gradient(colors: [RGB(hex: "#D29A6C").c(), wood.c()]), startPoint: CGPoint(x: 0, y: tableTop.minY), endPoint: CGPoint(x: 0, y: tableTop.maxY)))
        g.fill(Path(CGRect(x: r.minX, y: PGeo.tableY - 4, width: r.width, height: 3)), with: .color(.white.opacity(0.3)))
        let apron = CGRect(x: r.minX, y: PGeo.tableY + 26, width: r.width, height: r.maxY - PGeo.tableY - 26)
        g.fill(Path(apron), with: .color(woodDark.c()))
        var planks = Path()
        var px = r.minX - 20
        while px < r.maxX {
            planks.move(to: CGPoint(x: px, y: apron.minY))
            planks.addLine(to: CGPoint(x: px, y: apron.maxY))
            px += 128
        }
        g.stroke(planks, with: .color(.black.opacity(0.12)), lineWidth: 3)
        // the potion rack along the front
        g.fill(Path(roundedRect: CGRect(x: r.minX, y: PGeo.rackY, width: r.width, height: 14), cornerRadius: 4), with: .color(wood.c()))
        g.fill(Path(CGRect(x: r.minX, y: PGeo.rackY, width: r.width, height: 3)), with: .color(.white.opacity(0.3)))
        // the night darkens the room a little more down low
        if n > 0.01 {
            g.fill(Path(r), with: .color(RGB(hex: "#140F2E").c(0.25 * n)))
        }
    }

    private static func arch(_ x0: CGFloat, _ x1: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
        var p = Path()
        let cx = (x0 + x1) / 2, rr = (x1 - x0) / 2
        p.move(to: CGPoint(x: x0, y: y1))
        p.addLine(to: CGPoint(x: x0, y: y0 + rr))
        for k in 1...30 {
            let a = Double.pi + Double.pi * Double(k) / 30
            p.addLine(to: CGPoint(x: cx + rr * CGFloat(cos(a)), y: y0 + rr + rr * CGFloat(sin(a))))
        }
        p.addLine(to: CGPoint(x: x1, y: y1))
        p.closeSubpath()
        return p
    }

    private static func window(_ g: GraphicsContext, _ n: Double, _ t: CGFloat) {
        let outer = arch(362, 662, 56, 362)
        let inner = arch(376, 648, 70, 350)
        g.fill(outer, with: .color(wood.c()))
        let skyTop = RGB(hex: "#FFC9E3").mix(RGB(hex: "#141142"), n)
        let skyBottom = RGB(hex: "#C5DCFF").mix(RGB(hex: "#3A2C7C"), n)
        g.fill(inner, with: .linearGradient(Gradient(colors: [skyTop.c(), skyBottom.c()]), startPoint: CGPoint(x: 0, y: 70), endPoint: CGPoint(x: 0, y: 350)))
        var sky = g
        sky.clip(to: inner)
        if n < 0.99 {
            // soft clouds drifting by
            var cl = sky
            cl.opacity = 1 - n
            for k in 0..<3 {
                let x = 380 + ((t * 6 + CGFloat(k) * 120).truncatingRemainder(dividingBy: 360)) - 40
                let y: CGFloat = 130 + CGFloat(k) * 60
                var c = Path()
                c.addEllipse(in: CGRect(x: x, y: y, width: 70, height: 26))
                c.addEllipse(in: CGRect(x: x + 22, y: y - 14, width: 46, height: 34))
                c.addEllipse(in: CGRect(x: x + 46, y: y - 4, width: 50, height: 26))
                cl.fill(c, with: .color(.white.opacity(0.85)))
            }
        }
        if n > 0.01 {
            var nt = sky
            nt.opacity = n
            // stars
            for k in 0..<26 {
                let x = 384 + CGFloat((k * 97) % 260)
                let y = 82 + CGFloat((k * 53) % 250)
                let tw = 0.5 + 0.5 * sin(Double(t) * 2 + Double(k) * 1.7)
                let s = 2 + 3 * CGFloat(tw)
                nt.fill(Twinkle().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(.white.opacity(0.5 + 0.5 * tw)))
            }
            // the moon
            let m = CGRect(x: 560, y: 108, width: 58, height: 58)
            nt.fill(Path(ellipseIn: m.insetBy(dx: -16, dy: -16)), with: .radialGradient(Gradient(colors: [RGB(hex: "#FFF4C8").c(0.45), .clear]), center: CGPoint(x: m.midX, y: m.midY), startRadius: 20, endRadius: 46))
            var moon = Path(ellipseIn: m)
            moon.addEllipse(in: m.offsetBy(dx: 18, dy: -8))
            nt.fill(moon, with: .color(RGB(hex: "#FFF1B8").c()), style: FillStyle(eoFill: true))
        }
        // the window's bars and sill
        var bars = Path()
        bars.move(to: CGPoint(x: 512, y: 70)); bars.addLine(to: CGPoint(x: 512, y: 350))
        bars.move(to: CGPoint(x: 376, y: 220)); bars.addLine(to: CGPoint(x: 648, y: 220))
        g.stroke(bars, with: .color(wood.c()), lineWidth: 10)
        g.stroke(inner, with: .color(woodDark.c(0.5)), lineWidth: 3)
        g.fill(Path(roundedRect: CGRect(x: 352, y: 350, width: 320, height: 16), cornerRadius: 5), with: .color(wood.c()))
    }

    private static func lights(_ g: GraphicsContext, _ r: CGRect, _ n: Double, _ t: CGFloat) {
        var wire = Path()
        var bulbs: [CGPoint] = []
        let spans: [(CGFloat, CGFloat)] = [(r.minX, 330), (694, r.maxX)]
        for (a, b) in spans where b > a {
            wire.move(to: CGPoint(x: a, y: 104))
            wire.addQuadCurve(to: CGPoint(x: b, y: 104), control: CGPoint(x: (a + b) / 2, y: 150))
            let cnt = max(2, Int((b - a) / 46))
            for k in 1..<cnt {
                let u = CGFloat(k) / CGFloat(cnt)
                let x = a + (b - a) * u
                let y = 104 + 92 * u * (1 - u)
                bulbs.append(CGPoint(x: x, y: y))
            }
        }
        g.stroke(wire, with: .color(RGB(hex: "#5A3D6E").c(0.7)), lineWidth: 2)
        let cols = ["#FF9EC8", "#FFE07A", "#9FE8FF", "#C5A8FF", "#A8F0C0"].map { RGB(hex: $0) }
        for (k, p) in bulbs.enumerated() {
            let c = cols[k % cols.count]
            let tw = 0.75 + 0.25 * sin(Double(t) * 2.4 + Double(k) * 1.3)
            if n > 0.05 {
                g.fill(Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 12, width: 36, height: 36)),
                       with: .radialGradient(Gradient(colors: [c.c(0.55 * n * tw), .clear]), center: CGPoint(x: p.x, y: p.y + 6), startRadius: 2, endRadius: 18))
            }
            g.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y, width: 10, height: 13)), with: .color(c.mix(RGB(1, 1, 1), 0.3 * tw).c()))
        }
    }

    // MARK: - Everything that moves

    static func draw(_ ctx: GraphicsContext, map: PMap, sim: PotionSim, liquid: PotionLiquid) {
        var g = ctx
        g.translateBy(x: map.ox, y: map.oy)
        g.scaleBy(x: map.s, y: map.s)
        let t = CGFloat(sim.time)
        let (mc, ma) = sim.meanColor()
        let potionColor = PIngredient.water.color.mix(mc, Double(min(1, ma * 2)))

        // the potion's glow on the room, stronger at night
        let glow = sim.flaskGlow
        if glow > 0.02 && sim.volume > 1 {
            var lg = g
            lg.blendMode = .plusLighter
            let k = Double(glow) * (0.18 + 0.5 * Double(sim.night))
            lg.fill(Path(ellipseIn: CGRect(x: PGeo.C.x - 460, y: PGeo.C.y - 420, width: 920, height: 840)),
                    with: .radialGradient(Gradient(colors: [potionColor.c(k), potionColor.c(k * 0.4), .clear]), center: PGeo.C, startRadius: 40, endRadius: 440))
        }
        // the fire's warm light low down
        if sim.heat > 0 {
            var fg = g
            fg.blendMode = .plusLighter
            let k = 0.08 + 0.06 * Double(sim.heat) + 0.03 * sin(Double(t) * 13)
            fg.fill(Path(ellipseIn: CGRect(x: 512 - 220, y: 560, width: 440, height: 220)),
                    with: .radialGradient(Gradient(colors: [RGB(hex: "#FFA040").c(k * (0.5 + Double(sim.night))), .clear]), center: CGPoint(x: 512, y: 670), startRadius: 10, endRadius: 200))
        }

        // the shelves
        let hidden = sim.hiddenIngredient
        for ing in PIngredient.allCases where !hidden.contains(ing.rawValue) {
            let s = ing.shelfSpot
            drawIngredient(g, ing, center: CGPoint(x: s.x, y: s.y - 62), angle: 0, scale: 1, fill: sim.shelfFill[ing] ?? 1, time: t)
        }
        crate(g, sim)
        bucket(g, sim)
        burner(g, sim, t)
        tripod(g, front: false)

        // the flask, with what's in it
        flask(g, sim, liquid: liquid, t: t)
        tripod(g, front: true)
        drain(g, sim)
        unicorn(g, sim, t)
        for p in sim.puddles {
            g.fill(Path(ellipseIn: CGRect(x: p.x - p.w / 2, y: p.y - 3, width: p.w, height: 8)), with: .color(p.color.c(Double(p.a) * 0.6)))
            g.fill(Path(ellipseIn: CGRect(x: p.x - p.w * 0.3, y: p.y - 2, width: p.w * 0.3, height: 2.5)), with: .color(.white.opacity(Double(p.a) * 0.5)))
        }
        // the potions she made
        let hiddenRack = sim.hiddenRack
        for (i, b) in sim.rack.enumerated() where !hiddenRack.contains(i) {
            let c = PotionSim.rackFly(i)
            PotionBottlePainter.draw(g, bottle: b, center: c, angle: 0, scale: PotionSim.rackScale, time: t)
        }
        // pieces in the air or on the table
        for pc in sim.pieces where pc.state != .liquid {
            PieceArt.draw(g, pc, alpha: pc.state == .table ? Double(max(0, min(1, (7 - pc.age) / 1.5))) : 1)
        }
        drops(g, sim)
        motes(g, sim, t)
        // bottles flying home
        for f in sim.flyers {
            let (p, a) = PotionSim.flyerPos(f)
            if let b = f.bottle {
                let s = PotionSim.heldScale + (PotionSim.rackScale - PotionSim.heldScale) * f.t
                PotionBottlePainter.draw(g, bottle: b, center: p, angle: a, scale: s, time: t)
            } else if let ing = f.ing {
                drawIngredient(g, ing, center: p, angle: a, scale: PotionSim.heldScale + (1 - PotionSim.heldScale) * f.t, fill: sim.shelfFill[ing] ?? 1, time: t)
            } else {
                PotionBottlePainter.empty(g, center: p, angle: a, scale: PotionSim.heldScale * (1 - 0.25 * f.t))
            }
        }
        // what she holds
        if let h = sim.held {
            switch h {
            case .ingredient(let ing):
                drawIngredient(g, ing, center: sim.heldPos, angle: sim.heldTilt, scale: PotionSim.heldScale, fill: sim.heldFill, time: t)
            case .rack(let i):
                if var b = sim.rack[safe: i] {
                    b.fill = Double(sim.heldFill)
                    PotionBottlePainter.draw(g, bottle: b, center: sim.heldPos, angle: sim.heldTilt, scale: PotionSim.heldScale, time: t, cork: false)
                }
            case .empty:
                if !sim.dipInside { dipBottle(g, sim) }
            case .spoon:
                break
            }
        }
    }

    // MARK: Flask

    private static func flask(_ g: GraphicsContext, _ sim: PotionSim, liquid: PotionLiquid, t: CGFloat) {
        // the back of the glass
        g.fill(PGeo.exterior, with: .color(.white.opacity(0.10)))
        g.fill(PGeo.interior, with: .radialGradient(Gradient(colors: [RGB(hex: "#E8E0FF").c(0.12), RGB(hex: "#5A4A8A").c(0.16)]),
                                                     center: CGPoint(x: PGeo.C.x - 40, y: PGeo.C.y - 60), startRadius: 20, endRadius: PGeo.R))
        // things inside, tinted by the potion drawn over them
        var inside = g
        inside.clip(to: PGeo.interior)
        spoon(g, sim)
        for pc in sim.pieces where pc.state == .liquid { PieceArt.draw(inside, pc, alpha: 1) }
        if sim.held == .empty && sim.dipInside { dipBottle(g, sim) }

        guard sim.volume > 1 else {
            frontGlass(g, sim, t)
            return
        }
        // the potion, below its wavy surface
        var surf = Path()
        let x0 = PGeo.C.x - PGeo.R - 4, x1 = PGeo.C.x + PGeo.R + 4
        var x = x0
        surf.move(to: CGPoint(x: x0, y: sim.surfaceY(x0)))
        var top: [CGPoint] = []
        while x <= x1 {
            let p = CGPoint(x: x, y: sim.surfaceY(x))
            top.append(p)
            surf.addLine(to: p)
            x += 4
        }
        surf.addLine(to: CGPoint(x: x1, y: PGeo.bottomY + 20))
        surf.addLine(to: CGPoint(x: x0, y: PGeo.bottomY + 20))
        surf.closeSubpath()
        var lq = inside
        lq.clip(to: surf)
        if let img = liquid.image(sim) {
            let box = CGRect(x: PGeo.gx0, y: PGeo.gy0, width: CGFloat(PGeo.NX) * PGeo.cell, height: CGFloat(PGeo.NY) * PGeo.cell)
            lq.draw(Image(decorative: img, scale: 1).interpolation(.high), in: box)
            // it glows from inside
            let glow = sim.flaskGlow
            if glow > 0.05 {
                var gl = lq
                gl.blendMode = .plusLighter
                gl.opacity = Double(glow) * (0.25 + 0.3 * Double(sim.night)) * (0.9 + 0.1 * Double(sin(t * 3)))
                gl.draw(Image(decorative: img, scale: 1).interpolation(.high), in: box)
            }
        }
        // its roundness: lighter where the window light comes through, deeper at the edges
        lq.fill(Path(CGRect(x: x0, y: PGeo.rimY, width: x1 - x0, height: PGeo.bottomY - PGeo.rimY + 10)),
                with: .radialGradient(Gradient(colors: [.white.opacity(0.16), .clear, Color.black.opacity(0.16)]),
                                      center: CGPoint(x: PGeo.C.x - 50, y: PGeo.C.y - 40), startRadius: 10, endRadius: PGeo.R + 20))
        // light rippling through it
        var caus = Path()
        for k in 0..<7 {
            let cx = PGeo.C.x - 120 + CGFloat(k) * 40 + sin(t * 0.9 + CGFloat(k)) * 10
            caus.move(to: CGPoint(x: cx, y: sim.level + 8))
            caus.addQuadCurve(to: CGPoint(x: cx - 30, y: PGeo.bottomY), control: CGPoint(x: cx + 26 * sin(t * 1.3 + CGFloat(k) * 2), y: (sim.level + PGeo.bottomY) / 2))
        }
        lq.stroke(caus, with: .color(.white.opacity(0.06)), lineWidth: 10)
        // glitter swirling in it
        glitter(lq, sim, t)
        // bubbles
        var bub = Path(), hi = Path()
        for b in sim.bubbles {
            let r = b.r * (1 + 0.08 * sin(b.phase * 2))
            bub.addEllipse(in: CGRect(x: b.p.x - r, y: b.p.y - r, width: r * 2, height: r * 2))
            hi.addEllipse(in: CGRect(x: b.p.x - r * 0.55, y: b.p.y - r * 0.6, width: r * 0.5, height: r * 0.45))
        }
        inside.fill(bub, with: .color(.white.opacity(0.16)))
        inside.stroke(bub, with: .color(.white.opacity(0.75)), lineWidth: 1.4)
        inside.fill(hi, with: .color(.white.opacity(0.9)))
        // the surface line
        var line = Path()
        line.addLines(top)
        inside.stroke(line, with: .color(.white.opacity(0.6)), lineWidth: 2.5)
        var under = inside
        under.clip(to: surf)
        under.stroke(line.offsetBy(dx: 0, dy: 5), with: .color(.white.opacity(0.14)), lineWidth: 6)
        // floating things ride the surface on top
        for pc in sim.pieces where pc.state == .liquid && pc.p.y < sim.surfaceY(pc.p.x) + 6 { PieceArt.draw(inside, pc, alpha: 0.9) }
        foam(inside, sim, t)
        frontGlass(g, sim, t)
        if let k = sim.rare {
            Twinkles.draw(g, around: CGPoint(x: PGeo.C.x, y: PGeo.C.y), radius: PGeo.R + 26, time: t * 1.3, count: 7, alpha: 1)
            if sim.flash > 0 {
                var fl = g
                fl.blendMode = .plusLighter
                fl.fill(PGeo.interior, with: .color(k.color.mix(RGB(1, 1, 1), 0.5).c(Double(sim.flash) * 0.7)))
            }
        }
    }

    private static func frontGlass(_ g: GraphicsContext, _ sim: PotionSim, _ t: CGFloat) {
        // the glass itself: a bright rim of light and soft reflections of the window
        var ring = PGeo.exterior
        ring.addPath(PGeo.interior)
        g.fill(ring, with: .color(.white.opacity(0.22)), style: FillStyle(eoFill: true))
        g.stroke(PGeo.exterior, with: .color(glassLine.c(0.9)), lineWidth: 2.5)
        g.stroke(PGeo.interior, with: .color(.white.opacity(0.55)), lineWidth: 1.5)
        var refl = Path()
        for k in 0...20 {
            let a = Double.pi * (1.08 + 0.32 * Double(k) / 20)
            let p = CGPoint(x: PGeo.C.x + (PGeo.R - 22) * CGFloat(cos(a)), y: PGeo.C.y + (PGeo.R - 22) * CGFloat(sin(a)))
            if k == 0 { refl.move(to: p) } else { refl.addLine(to: p) }
        }
        g.stroke(refl, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        var refl2 = Path()
        for k in 0...10 {
            let a = Double.pi * (1.52 + 0.08 * Double(k) / 10)
            let p = CGPoint(x: PGeo.C.x + (PGeo.R - 26) * CGFloat(cos(a)), y: PGeo.C.y + (PGeo.R - 26) * CGFloat(sin(a)))
            if k == 0 { refl2.move(to: p) } else { refl2.addLine(to: p) }
        }
        g.stroke(refl2, with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        var side = Path()
        for k in 0...14 {
            let a = Double.pi * (0.05 + 0.25 * Double(k) / 14)
            let p = CGPoint(x: PGeo.C.x + (PGeo.R - 16) * CGFloat(cos(a)), y: PGeo.C.y + (PGeo.R - 16) * CGFloat(sin(a)))
            if k == 0 { side.move(to: p) } else { side.addLine(to: p) }
        }
        g.stroke(side, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        // the neck's shine
        g.fill(Path(roundedRect: CGRect(x: PGeo.C.x - PGeo.hw + 10, y: PGeo.rimY + 16, width: 9, height: PGeo.joinY - PGeo.rimY - 30), cornerRadius: 4), with: .color(.white.opacity(0.4)))
        // the lip at the top, seen a little from above
        let lip = CGRect(x: PGeo.C.x - PGeo.hw - 16, y: PGeo.rimY - 12, width: (PGeo.hw + 16) * 2, height: 22)
        g.stroke(Path(ellipseIn: lip), with: .color(glassLine.c(0.95)), lineWidth: 6)
        g.stroke(Path(ellipseIn: lip.insetBy(dx: 3, dy: 3)), with: .color(.white.opacity(0.7)), lineWidth: 2)
    }

    private static func glitter(_ g: GraphicsContext, _ sim: PotionSim, _ t: CGFloat) {
        guard !sim.glitter.isEmpty else { return }
        var paths: [Int: (Path, RGB)] = [:]
        var shine = Path()
        for gl in sim.glitter {
            let tw = 0.5 + 0.5 * sin(gl.phase * 2.3 + t * 4)
            let s = gl.size * (0.7 + 0.6 * tw)
            let key = Int(gl.color.r * 7) * 64 + Int(gl.color.g * 7) * 8 + Int(gl.color.b * 7)
            var e = paths[key] ?? (Path(), gl.color)
            e.0.addEllipse(in: CGRect(x: gl.p.x - s, y: gl.p.y - s, width: s * 2, height: s * 2))
            paths[key] = e
            if tw > 0.9 {
                let r = s * 3
                shine.addPath(Twinkle().path(in: CGRect(x: gl.p.x - r, y: gl.p.y - r, width: r * 2, height: r * 2)))
            }
        }
        for (_, e) in paths { g.fill(e.0, with: .color(e.1.c())) }
        g.fill(shine, with: .color(.white.opacity(0.9)))
    }

    private static func foam(_ g: GraphicsContext, _ sim: PotionSim, _ t: CGFloat) {
        var blobs = Path()
        var any = false
        for i in 0..<PGeo.NX where sim.foam[i] > 1.5 {
            let x = PGeo.gx0 + (CGFloat(i) + 0.5) * PGeo.cell
            let f = sim.foam[i]
            let y = sim.surfaceY(x)
            let layers = Int(min(6, f / 8)) + 1
            for l in 0..<layers {
                let r = 4 + min(9, f / 5) * (1 - CGFloat(l) * 0.1)
                let jx = sin(CGFloat(i * 7 + l * 3) + t * 0.6) * 3
                blobs.addEllipse(in: CGRect(x: x - r + jx, y: y - CGFloat(l) * min(f, 60) / CGFloat(layers) - r, width: r * 2, height: r * 2))
            }
            any = true
        }
        guard any else { return }
        let (c, a) = sim.meanColor()
        let foamColor = RGB(1, 1, 1).mix(c, Double(min(0.35, a * 0.5)))
        g.fill(blobs, with: .color(foamColor.c(0.92)))
        g.stroke(blobs, with: .color(foamColor.mix(RGB(0.6, 0.6, 0.8), 0.3).c(0.5)), lineWidth: 1)
    }

    // MARK: The stirring paddle

    static func spoon(_ g: GraphicsContext, _ sim: PotionSim) {
        let blade = sim.spoon
        // the shaft goes up through the flask's mouth and out over the rim
        let pivot = CGPoint(x: max(PGeo.C.x - PGeo.hw + 14, min(PGeo.C.x + PGeo.hw - 14, blade.x * 0.6 + PGeo.C.x * 0.4 - (sim.spoonHeld ? 0 : 50))), y: PGeo.rimY)
        let dx = pivot.x - blade.x, dy = pivot.y - blade.y
        let len = max(1, hypot(dx, dy))
        let ux = dx / len, uy = dy / len
        let total: CGFloat = max(len + 90, 330)
        let end = CGPoint(x: blade.x + ux * total, y: blade.y + uy * total)
        var shaft = Path()
        shaft.move(to: blade)
        shaft.addLine(to: end)
        g.stroke(shaft, with: .color(woodDark.c()), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        g.stroke(shaft, with: .color(wood.c()), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        var shine = Path()
        shine.move(to: CGPoint(x: blade.x - uy * 2, y: blade.y + ux * 2))
        shine.addLine(to: CGPoint(x: end.x - uy * 2, y: end.y + ux * 2))
        g.stroke(shine, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        // the knob at the top
        g.fill(Path(ellipseIn: CGRect(x: end.x - 11, y: end.y - 11, width: 22, height: 22)), with: .color(RGB(hex: "#C990FF").c()))
        g.fill(Path(ellipseIn: CGRect(x: end.x - 6, y: end.y - 8, width: 7, height: 6)), with: .color(.white.opacity(0.7)))
        // the blade: a flat paddle turned along the shaft
        var b = g
        b.translateBy(x: blade.x, y: blade.y)
        b.rotate(by: .radians(Double(atan2(uy, ux)) + .pi / 2))
        let paddle = Path(roundedRect: CGRect(x: -17, y: -34, width: 34, height: 54), cornerRadius: 15)
        b.fill(paddle, with: .color(wood.c()))
        b.stroke(paddle, with: .color(woodDark.c()), lineWidth: 3)
        b.fill(Path(roundedRect: CGRect(x: -10, y: -26, width: 6, height: 36), cornerRadius: 3), with: .color(.white.opacity(0.25)))
    }

    // MARK: Burner, tripod, drain, crate

    private static func burner(_ g: GraphicsContext, _ sim: PotionSim, _ t: CGFloat) {
        // flames under the glass
        let h = sim.heat
        let base = CGPoint(x: 512, y: 664)
        let size: CGFloat = h == 0 ? 0.22 : 0.45 + 0.28 * CGFloat(h)
        let fl = g
        for k in 0..<5 {
            let fx = base.x + CGFloat(k - 2) * 15
            let flick = sin(t * 17 + CGFloat(k) * 2.1) * 0.12 + sin(t * 29 + CGFloat(k)) * 0.06
            let tall: CGFloat = h == 0 ? (k == 2 ? 14 : 0) : (34 + CGFloat(2 - abs(k - 2)) * 10) * size
            let hgt = tall * (1 + flick)
            guard hgt > 1 else { continue }
            let w: CGFloat = h == 0 ? 5 : 9 + 2 * CGFloat(h)
            var f = Path()
            f.move(to: CGPoint(x: fx - w, y: base.y))
            f.addQuadCurve(to: CGPoint(x: fx + sin(t * 9 + CGFloat(k)) * 4, y: base.y - hgt), control: CGPoint(x: fx - w * 1.1, y: base.y - hgt * 0.5))
            f.addQuadCurve(to: CGPoint(x: fx + w, y: base.y), control: CGPoint(x: fx + w * 1.1, y: base.y - hgt * 0.5))
            f.closeSubpath()
            fl.fill(f, with: .linearGradient(Gradient(colors: [RGB(hex: "#5A8CFF").c(0.9), RGB(hex: "#FFB03A").c(0.95), RGB(hex: "#FF6A2A").c(0.0)]),
                                             startPoint: CGPoint(x: fx, y: base.y), endPoint: CGPoint(x: fx, y: base.y - hgt)))
            var core = Path()
            core.move(to: CGPoint(x: fx - w * 0.45, y: base.y))
            core.addQuadCurve(to: CGPoint(x: fx, y: base.y - hgt * 0.45), control: CGPoint(x: fx - w * 0.5, y: base.y - hgt * 0.2))
            core.addQuadCurve(to: CGPoint(x: fx + w * 0.45, y: base.y), control: CGPoint(x: fx + w * 0.5, y: base.y - hgt * 0.2))
            fl.fill(core, with: .color(RGB(hex: "#FFF3C0").c(0.8)))
        }
        // the burner
        let body = CGRect(x: 470, y: 664, width: 84, height: 36)
        g.fill(Path(roundedRect: body, cornerRadius: 10), with: .linearGradient(Gradient(colors: [brass.c(), brassDark.c()]), startPoint: CGPoint(x: 0, y: body.minY), endPoint: CGPoint(x: 0, y: body.maxY)))
        g.fill(Path(roundedRect: CGRect(x: 480, y: 658, width: 64, height: 10), cornerRadius: 4), with: .color(brassDark.c()))
        g.fill(Path(roundedRect: CGRect(x: 476, y: 668, width: 70, height: 5), cornerRadius: 2), with: .color(.white.opacity(0.35)))
        // the knob: turn it up for a bigger fire
        let k = PGeo.knob
        let R = PGeo.knobRadius
        g.fill(Path(ellipseIn: CGRect(x: k.x - R - 4, y: k.y - R - 4, width: (R + 4) * 2, height: (R + 4) * 2)), with: .color(brassDark.c()))
        g.fill(Path(ellipseIn: CGRect(x: k.x - R, y: k.y - R, width: R * 2, height: R * 2)),
               with: .radialGradient(Gradient(colors: [RGB(hex: "#FF9AC4").c(), RGB(hex: "#E2558F").c()]), center: CGPoint(x: k.x - 8, y: k.y - 10), startRadius: 2, endRadius: R))
        // dots for each heat, lit up to the current one
        for i in 0...3 {
            let a = -Double.pi * 0.75 + Double(i) * Double.pi * 0.5
            let p = CGPoint(x: k.x + (R + 12) * CGFloat(cos(a)), y: k.y + (R + 12) * CGFloat(sin(a)))
            let on = i <= h && h > 0
            g.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(on ? RGB(hex: "#FFB03A").c() : .white.opacity(0.5)))
        }
        let a = -Double.pi * 0.75 + Double(h) * Double.pi * 0.5
        var pointer = Path()
        pointer.move(to: k)
        pointer.addLine(to: CGPoint(x: k.x + (R - 6) * CGFloat(cos(a)), y: k.y + (R - 6) * CGFloat(sin(a))))
        g.stroke(pointer, with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        // a little flame on the knob, so she knows what it does
        var icon = Path()
        icon.move(to: CGPoint(x: k.x - 7, y: k.y + 12))
        icon.addQuadCurve(to: CGPoint(x: k.x, y: k.y - 4), control: CGPoint(x: k.x - 9, y: k.y + 2))
        icon.addQuadCurve(to: CGPoint(x: k.x + 7, y: k.y + 12), control: CGPoint(x: k.x + 9, y: k.y + 2))
        icon.closeSubpath()
        g.fill(icon, with: .color(RGB(hex: "#FFE07A").c(0.9)))
    }

    private static func tripod(_ g: GraphicsContext, front: Bool) {
        let ring = CGRect(x: 384, y: 590, width: 256, height: 24)
        var half = Path()
        let n = 24
        for k in 0...n {
            let a = (front ? 0 : Double.pi) + Double.pi * Double(k) / Double(n)
            let p = CGPoint(x: ring.midX + ring.width / 2 * CGFloat(cos(a)), y: ring.midY + ring.height / 2 * CGFloat(sin(a)))
            if k == 0 { half.move(to: p) } else { half.addLine(to: p) }
        }
        g.stroke(half, with: .color(brassDark.c()), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        g.stroke(half, with: .color(brass.c()), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        if front {
            var legs = Path()
            legs.move(to: CGPoint(x: 388, y: 604)); legs.addLine(to: CGPoint(x: 364, y: PGeo.tableY))
            legs.move(to: CGPoint(x: 636, y: 604)); legs.addLine(to: CGPoint(x: 660, y: PGeo.tableY))
            g.stroke(legs, with: .color(brassDark.c()), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            g.stroke(legs, with: .color(brass.c()), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }

    private static func drain(_ g: GraphicsContext, _ sim: PotionSim) {
        // a glass pipe from the bottom of the flask, a brass tap, into the bucket
        var pipe = Path()
        pipe.move(to: CGPoint(x: 556, y: 636))
        pipe.addQuadCurve(to: CGPoint(x: 640, y: 652), control: CGPoint(x: 580, y: 652))
        pipe.addLine(to: CGPoint(x: PGeo.drainMouth.x - 8, y: 652))
        pipe.addQuadCurve(to: CGPoint(x: PGeo.drainMouth.x, y: 664), control: CGPoint(x: PGeo.drainMouth.x, y: 652))
        g.stroke(pipe, with: .color(glassLine.c(0.9)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        g.stroke(pipe, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        if sim.draining && sim.volume > 1 {
            let (c, a) = sim.colorAt(CGPoint(x: PGeo.C.x + 40, y: PGeo.bottomY - 14))
            g.stroke(pipe, with: .color(PIngredient.water.color.mix(c, Double(min(1, a * 2))).c(0.85)), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        // the tap: a big lever, sideways when shut, along the pipe when open
        let v = PGeo.valve
        g.fill(Path(ellipseIn: CGRect(x: v.x - 15, y: v.y - 15, width: 30, height: 30)), with: .color(brassDark.c()))
        g.fill(Path(ellipseIn: CGRect(x: v.x - 11, y: v.y - 11, width: 22, height: 22)), with: .color(brass.c()))
        var lever = g
        lever.translateBy(x: v.x, y: v.y)
        lever.rotate(by: .radians(sim.draining ? 0 : -.pi / 2))
        let handle = Path(roundedRect: CGRect(x: -6, y: -44, width: 12, height: 44), cornerRadius: 6)
        lever.fill(handle, with: .color(RGB(hex: "#7FD3F2").c()))
        lever.stroke(handle, with: .color(RGB(hex: "#3D8FB8").c()), lineWidth: 2.5)
        lever.fill(Path(ellipseIn: CGRect(x: -11, y: -54, width: 22, height: 22)), with: .color(RGB(hex: "#7FD3F2").c()))
        lever.stroke(Path(ellipseIn: CGRect(x: -11, y: -54, width: 22, height: 22)), with: .color(RGB(hex: "#3D8FB8").c()), lineWidth: 2.5)
    }

    private static func bucket(_ g: GraphicsContext, _ sim: PotionSim) {
        let b = PGeo.bucket
        var body = Path()
        body.move(to: CGPoint(x: b.minX, y: b.minY))
        body.addLine(to: CGPoint(x: b.maxX, y: b.minY))
        body.addLine(to: CGPoint(x: b.maxX - 8, y: b.maxY))
        body.addLine(to: CGPoint(x: b.minX + 8, y: b.maxY))
        body.closeSubpath()
        g.fill(body, with: .linearGradient(Gradient(colors: [RGB(hex: "#D9A27A").c(), RGB(hex: "#B07450").c()]), startPoint: CGPoint(x: b.minX, y: 0), endPoint: CGPoint(x: b.maxX, y: 0)))
        var bands = Path()
        bands.move(to: CGPoint(x: b.minX + 3, y: b.minY + 12)); bands.addLine(to: CGPoint(x: b.maxX - 3, y: b.minY + 12))
        bands.move(to: CGPoint(x: b.minX + 6, y: b.maxY - 10)); bands.addLine(to: CGPoint(x: b.maxX - 6, y: b.maxY - 10))
        g.stroke(bands, with: .color(brassDark.c()), lineWidth: 4)
        let mouth = CGRect(x: b.minX, y: b.minY - 6, width: b.width, height: 12)
        g.fill(Path(ellipseIn: mouth), with: .color(RGB(hex: "#6A4030").c()))
        if sim.bucketFill > 0.02 {
            g.fill(Path(ellipseIn: mouth.insetBy(dx: 5, dy: 2)), with: .color(sim.bucketColor.c(0.5 + 0.4 * Double(sim.bucketFill))))
        }
        g.stroke(Path(ellipseIn: mouth), with: .color(RGB(hex: "#E8B88A").c()), lineWidth: 3)
    }

    private static func crate(_ g: GraphicsContext, _ sim: PotionSim) {
        let c = PGeo.crate
        // three empty bottles standing in it
        for k in 0..<3 {
            let x = c.minX + 48 + CGFloat(k) * 58
            PotionBottlePainter.empty(g, center: CGPoint(x: x, y: c.minY + 34 - CGFloat(k % 2) * 4), angle: 0, scale: 0.72)
        }
        let front = CGRect(x: c.minX, y: c.minY + 34, width: c.width, height: c.height - 34)
        g.fill(Path(roundedRect: front, cornerRadius: 6), with: .color(wood.c()))
        var slats = Path()
        slats.move(to: CGPoint(x: front.minX + 6, y: front.midY)); slats.addLine(to: CGPoint(x: front.maxX - 6, y: front.midY))
        g.stroke(slats, with: .color(woodDark.c()), lineWidth: 3)
        g.stroke(Path(roundedRect: front, cornerRadius: 6), with: .color(woodDark.c()), lineWidth: 3)
        // a picture of an empty bottle on the front
        PotionBottlePainter.empty(g, center: CGPoint(x: front.midX, y: front.midY + 2), angle: 0, scale: 0.3)
    }

    // MARK: The empty bottle being dipped

    static func dipBottle(_ g: GraphicsContext, _ sim: PotionSim) {
        let s = PotionSim.heldScale
        let poly = PPoly.transform(PBottleShape.round.outline, at: sim.heldPos, angle: 0, scale: s)
        if sim.dipFill > 0.01 {
            let lvl = PPoly.level(poly, fill: sim.dipFill)
            let liq = PPoly.below(poly, lvl)
            var lp = Path()
            lp.addLines(liq)
            lp.closeSubpath()
            g.fill(lp, with: .color(sim.dipColor.c(0.9)))
        }
        PotionBottlePainter.glass(g, poly: poly, center: sim.heldPos, angle: 0, scale: s, shape: .round)
    }

    // MARK: Ingredients on the shelves (and in her hand)

    static func drawIngredient(_ g: GraphicsContext, _ ing: PIngredient, center: CGPoint, angle: CGFloat, scale: CGFloat, fill: CGFloat, time t: CGFloat) {
        if ing.isLiquid {
            let shape = PotionSimShapes.shape(ing)
            PotionBottlePainter.liquidBottle(g, shape: shape, center: center, angle: angle, scale: scale, fill: fill, color: ing.color,
                                             alpha: ing == .water ? 0.35 : 0.92, glow: ing == .moon ? 0.6 : (ing == .dragon ? 0.4 : 0), time: t)
            PotionBottlePainter.label(g, ing, center: center, angle: angle, scale: scale)
            PotionBottlePainter.cork(g, shape: shape, center: center, angle: angle, scale: scale, on: abs(angle) < 0.4)
        } else {
            jar(g, ing, center: center, angle: angle, scale: scale, time: t)
        }
    }

    static let jarOutline: [CGPoint] = {
        var p: [CGPoint] = [CGPoint(x: 26, y: -62), CGPoint(x: 26, y: -48), CGPoint(x: 36, y: -40)]
        p.append(CGPoint(x: 38, y: 48))
        for k in 0...6 {
            let a = Double.pi * Double(k) / 6
            p.append(CGPoint(x: 28 * CGFloat(cos(a)), y: 48 + 10 * CGFloat(sin(a))))
        }
        p.append(CGPoint(x: -38, y: 48))
        p.append(CGPoint(x: -36, y: -40))
        p.append(CGPoint(x: -26, y: -48))
        p.append(CGPoint(x: -26, y: -62))
        return p
    }()

    static func jar(_ g: GraphicsContext, _ ing: PIngredient, center: CGPoint, angle: CGFloat, scale: CGFloat, time t: CGFloat) {
        var l = g
        l.translateBy(x: center.x, y: center.y)
        l.rotate(by: .radians(Double(angle)))
        l.scaleBy(x: scale, y: scale)
        var body = Path()
        body.addLines(jarOutline)
        body.closeSubpath()
        l.fill(body, with: .color(.white.opacity(0.28)))
        // what's in it: a heap at the bottom (or at the lid, turned over)
        var inner = l
        inner.clip(to: body)
        let flipped = abs(angle) > 1.6
        for k in 0..<14 {
            let col = CGFloat(k % 5), row = CGFloat(k / 5)
            let x = -26 + col * 13 + (row.truncatingRemainder(dividingBy: 2)) * 6
            let y = flipped ? -40 + row * 13 : 44 - row * 13
            let pc = PPiece(kind: ing, p: CGPoint(x: x, y: y), v: .zero, ang: CGFloat(k) * 1.3, spin: 0, seed: k, trail: ing == .hair ? (0..<10).map { CGPoint(x: x - 10 + CGFloat($0) * 2.5, y: y + sin(CGFloat($0) * 0.9 + CGFloat(k)) * 5) } : [])
            if ing == .hair && k > 4 { continue }
            PieceArt.draw(inner, pc, alpha: 1)
        }
        l.fill(Path(roundedRect: CGRect(x: -30, y: -36, width: 9, height: 70), cornerRadius: 4), with: .color(.white.opacity(0.45)))
        l.stroke(body, with: .color(glassLine.c(0.95)), lineWidth: 3)
        // the lid
        let lidColor: RGB
        switch ing {
        case .stars: lidColor = RGB(hex: "#FFC93A")
        case .petals: lidColor = RGB(hex: "#FF7FAE")
        case .berries: lidColor = RGB(hex: "#4A72FF")
        case .frost: lidColor = RGB(hex: "#7FD8F2")
        case .hair: lidColor = RGB(hex: "#C58CFF")
        default: lidColor = RGB(hex: "#9C7BFF")
        }
        let lid = Path(roundedRect: CGRect(x: -30, y: -72, width: 60, height: 18), cornerRadius: 6)
        l.fill(lid, with: .color(lidColor.c()))
        l.stroke(lid, with: .color(lidColor.mul(0.7, 0.6, 0.75).c()), lineWidth: 2.5)
        l.fill(Path(roundedRect: CGRect(x: -24, y: -69, width: 48, height: 4), cornerRadius: 2), with: .color(.white.opacity(0.45)))
    }

    // MARK: The unicorn

    static let unicornLook = PetLook(kind: "unicorn")

    static func unicorn(_ g: GraphicsContext, _ sim: PotionSim, _ t: CGFloat) {
        let u = sim.uni
        let feet = CGPoint(x: PGeo.unicornFeet.x, y: PGeo.unicornFeet.y + u.floatY + u.hop)
        let k = PGeo.unicornScale
        // a soft shadow on the table
        let lift = min(1, -(u.floatY + u.hop) / 140)
        g.fill(Path(ellipseIn: CGRect(x: PGeo.unicornFeet.x - 90 * (1 - lift * 0.4), y: PGeo.unicornFeet.y - 10, width: 180 * (1 - lift * 0.4), height: 18)),
               with: .color(Theme.ink.opacity(0.16 * Double(1 - lift * 0.6))))
        // glowing
        if u.glow > 0 {
            var gl = g
            gl.blendMode = .plusLighter
            let a = Double(min(1, u.glow / 2)) * (0.35 + 0.1 * sin(Double(t) * 3))
            let c = u.tintAmt > 0.1 ? u.tint : RGB(hex: "#FFF4C8")
            gl.fill(Path(ellipseIn: CGRect(x: feet.x - 150, y: feet.y - 260, width: 300, height: 280)),
                    with: .radialGradient(Gradient(colors: [c.c(a), .clear]), center: CGPoint(x: feet.x, y: feet.y - 110), startRadius: 20, endRadius: 150))
        }
        var pet = unicornLook
        pet.glitter = u.glitter > 0
        var pose = PetPose()
        pose.time = Double(t)
        if u.sleepy > 0 {
            pose.eyes = u.sleepy > 7 ? "tired" : "blink"
            pose.mouth = u.sleepy > 7 ? "o" : "smile"
        } else if u.hicKick > 0.2 {
            pose.eyes = "wince"; pose.mouth = "o"
        } else if u.giggle > 0 || u.love > 0 {
            pose.eyes = "happy"; pose.mouth = "grin"
        } else if u.glitter > 0 || u.glow > 0 || u.rainbow > 0 {
            pose.eyes = "sparkle"; pose.mouth = "grin"
        } else if u.frost > 0 {
            pose.eyes = "wince"; pose.mouth = "wavy"
        } else if u.float > 0 {
            pose.eyes = "sparkle"; pose.mouth = "o"
        } else if u.blink < 0 {
            pose.eyes = "blink"
        }
        let head = CGPoint(x: feet.x, y: feet.y - (PetArt.feetY - PetArt.headCenter.y) * k)
        let lx = max(-1, min(1, (u.look.x - head.x) / 300)), ly = max(-1, min(1, (u.look.y - head.y) / 300))
        pose.look = CGSize(width: lx * 7, height: ly * 5)
        pose.squash = 1 + 0.012 * sin(t * 2.2) - (u.hicKick * 0.06) + (u.hopV < -100 ? 0.04 : 0)
        var tilt = 0.0
        if u.shake > 0 { tilt += sin(Double(t) * 34) * 9 * Double(min(1, u.shake * 2)) }
        if u.frost > 0 { tilt += sin(Double(t) * 50) * 2 }
        if u.sleepy > 0 { tilt += 6 * Double(min(1, u.sleepy)) }
        pose.tilt = tilt
        var shading: GraphicsContext.Shading?
        if u.rainbow > 0 {
            let rainbow = ["#FF8FB8", "#FFB27A", "#FFE27A", "#8FE0A4", "#7FC8FF", "#B89CFF"].map { RGB(hex: $0).c() }
            shading = .linearGradient(Gradient(colors: rainbow), startPoint: CGPoint(x: 120, y: 60), endPoint: CGPoint(x: 480, y: 620))
        } else if u.frost > 0 {
            shading = .color(RGB(hex: "#BFEFFF").c())
        } else if u.tintAmt > 0.03 {
            shading = .color(RGB(hex: "#FBF3FF").mix(u.tint, Double(min(1, u.tintAmt * 1.2))).c())
        }
        var pg = g
        pg.translateBy(x: feet.x, y: feet.y)
        pg.scaleBy(x: k, y: k)
        pg.translateBy(x: -300, y: -PetArt.feetY)
        PetPainter.draw(pet, pose: pose, furShading: shading, in: pg)
        // floating in a big bubble
        if u.float > 0 || u.floatY < -4 {
            let c = CGPoint(x: feet.x, y: feet.y - 112)
            let r: CGFloat = 138 + sin(t * 3) * 3
            let bub = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.96, width: r * 2, height: r * 1.92))
            let a = u.float > 0 ? 1.0 : 0.0
            g.fill(bub, with: .radialGradient(Gradient(colors: [.clear, RGB(hex: "#BFEFFF").c(0.18 * a), RGB(hex: "#FFC2EC").c(0.35 * a)]),
                                              center: c, startRadius: r * 0.5, endRadius: r))
            g.stroke(bub, with: .linearGradient(Gradient(colors: [RGB(hex: "#9FE8FF").c(0.8 * a), RGB(hex: "#FFB8E8").c(0.8 * a), RGB(hex: "#FFE38A").c(0.8 * a)]),
                                                startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)), lineWidth: 3)
            g.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.6, y: c.y - r * 0.75, width: r * 0.42, height: r * 0.26)), with: .color(.white.opacity(0.7 * a)))
        }
    }

    // MARK: Drops and streams

    private static func drops(_ g: GraphicsContext, _ sim: PotionSim) {
        var streams: [Int: [PDrop]] = [:]
        var lone = Path()
        var loneColors: [(Path, RGB)] = []
        for d in sim.drops {
            if d.stream >= 0 {
                streams[d.stream, default: []].append(d)
            } else {
                var p = Path(ellipseIn: CGRect(x: d.p.x - d.r, y: d.p.y - d.r * 1.2, width: d.r * 2, height: d.r * 2.4))
                if d.onGlass { p = Path(ellipseIn: CGRect(x: d.p.x - d.r, y: d.p.y - d.r * 1.5, width: d.r * 2, height: d.r * 3)) }
                loneColors.append((p, d.color))
                lone.addEllipse(in: CGRect(x: d.p.x - d.r * 0.4, y: d.p.y - d.r * 0.7, width: d.r * 0.6, height: d.r * 0.6))
            }
        }
        for (p, c) in loneColors { g.fill(p, with: .color(c.c(0.85))) }
        g.fill(lone, with: .color(.white.opacity(0.7)))
        for (_, list) in streams {
            guard let first = list.first else { continue }
            // newest at the mouth, oldest at the front of the stream: draw along it, breaking at gaps
            var seg: [PDrop] = []
            func flush() {
                guard seg.count > 1 else {
                    if let d = seg.first { g.fill(Path(ellipseIn: CGRect(x: d.p.x - d.r, y: d.p.y - d.r, width: d.r * 2, height: d.r * 2)), with: .color(d.color.c(0.9))) }
                    return
                }
                var p = Path()
                p.addLines(seg.map(\.p))
                let w = seg.map(\.r).reduce(0, +) / CGFloat(seg.count) * 2
                g.stroke(p, with: .color(seg[seg.count / 2].color.c(first.ing == .water ? 0.55 : 0.92)), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
                g.stroke(p.offsetBy(dx: -w * 0.2, dy: 0), with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: max(1, w * 0.22), lineCap: .round, lineJoin: .round))
            }
            for d in list {
                if let last = seg.last, hypot(d.p.x - last.p.x, d.p.y - last.p.y) > 34 {
                    flush()
                    seg = []
                }
                seg.append(d)
            }
            flush()
        }
    }

    // MARK: Motes

    private static func motes(_ g: GraphicsContext, _ sim: PotionSim, _ t: CGFloat) {
        // the soft ones in a blurred layer
        let soft = sim.motes.filter { $0.kind == .steam || $0.kind == .fog || $0.kind == .smoke }
        if !soft.isEmpty {
            g.drawLayer { l in
                l.addFilter(.blur(radius: 7))
                for m in soft {
                    let k = m.life / m.max
                    let a: Double
                    switch m.kind {
                    case .fog: a = 0.55 * Double(min(1, k * 4) * (1 - k))
                    case .smoke: a = 0.7 * Double(1 - k)
                    default: a = 0.32 * Double(min(1, k * 5) * (1 - k))
                    }
                    l.fill(Path(ellipseIn: CGRect(x: m.p.x - m.size, y: m.p.y - m.size * 0.8, width: m.size * 2, height: m.size * 1.6)), with: .color(m.color.c(a)))
                }
            }
        }
        for m in sim.motes {
            let k = m.life / m.max
            let fade = Double(max(0, 1 - k))
            switch m.kind {
            case .sparkle:
                let s = m.size * (1 - k * 0.5)
                g.fill(Twinkle().path(in: CGRect(x: m.p.x - s, y: m.p.y - s, width: s * 2, height: s * 2)), with: .color(m.color.c(fade)))
            case .heart:
                let s = m.size
                let r = CGRect(x: m.p.x - s, y: m.p.y - s, width: s * 2, height: s * 1.8)
                g.fill(PetPainter.heartPath(in: r), with: .color(m.color.c(fade)))
                g.stroke(PetPainter.heartPath(in: r), with: .color(.white.opacity(fade)), lineWidth: 2)
            case .snow:
                var s = Path()
                for a in 0..<3 {
                    let ang = CGFloat(a) * .pi / 3 + m.spin + t
                    s.move(to: CGPoint(x: m.p.x - cos(ang) * m.size, y: m.p.y - sin(ang) * m.size))
                    s.addLine(to: CGPoint(x: m.p.x + cos(ang) * m.size, y: m.p.y + sin(ang) * m.size))
                }
                g.stroke(s, with: .color(.white.opacity(fade)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            case .soap:
                let r = m.size
                let c = CGRect(x: m.p.x - r, y: m.p.y - r, width: r * 2, height: r * 2)
                g.fill(Path(ellipseIn: c), with: .color(.white.opacity(0.12 * fade)))
                g.stroke(Path(ellipseIn: c), with: .linearGradient(Gradient(colors: [RGB(hex: "#9FE8FF").c(fade), RGB(hex: "#FFB8E8").c(fade)]), startPoint: CGPoint(x: c.minX, y: c.minY), endPoint: CGPoint(x: c.maxX, y: c.maxY)), lineWidth: 1.5)
                g.fill(Path(ellipseIn: CGRect(x: c.minX + r * 0.4, y: c.minY + r * 0.35, width: r * 0.5, height: r * 0.35)), with: .color(.white.opacity(0.8 * fade)))
            case .zz:
                let s = m.size
                var z = Path()
                z.move(to: CGPoint(x: m.p.x - s / 2, y: m.p.y - s / 2))
                z.addLine(to: CGPoint(x: m.p.x + s / 2, y: m.p.y - s / 2))
                z.addLine(to: CGPoint(x: m.p.x - s / 2, y: m.p.y + s / 2))
                z.addLine(to: CGPoint(x: m.p.x + s / 2, y: m.p.y + s / 2))
                g.stroke(z, with: .color(m.color.c(fade)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            case .flash:
                let r = m.size
                g.stroke(Path(ellipseIn: CGRect(x: m.p.x - r, y: m.p.y - r, width: r * 2, height: r * 2)), with: .color(m.color.c(fade * 0.9)), lineWidth: 10 * CGFloat(fade) + 1)
            case .drip:
                let r = m.size * 0.5
                g.fill(Path(ellipseIn: CGRect(x: m.p.x - r, y: m.p.y - r * 1.3, width: r * 2, height: r * 2.6)), with: .color(m.color.c(0.8 * fade)))
            default:
                break
            }
        }
    }
}

enum PotionSimShapes {
    static func shape(_ ing: PIngredient) -> PBottleShape {
        switch ing {
        case .water: return .square
        case .nectar: return .heart
        case .mermaid: return .drop
        case .dragon: return .diamond
        case .moon: return .round
        case .night: return .tall
        default: return .square
        }
    }
}

// MARK: - Bottles

enum PotionBottlePainter {
    /// A bottled potion: the glass, the potion inside (level, even when it tips), its magic, the cork.
    static func draw(_ g: GraphicsContext, bottle b: PotionBottle, center: CGPoint, angle: CGFloat, scale: CGFloat, time t: CGFloat, cork: Bool = true) {
        let shape = b.bottleShape
        let poly = PPoly.transform(shape.outline, at: center, angle: angle, scale: scale)
        // a soft glow around glowing potions
        if b.glow > 0.2 {
            var gl = g
            gl.blendMode = .plusLighter
            let r = 70 * scale
            gl.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(Gradient(colors: [b.color.c(0.35 * b.glow * (0.85 + 0.15 * sin(Double(t) * 2.5))), .clear]), center: center, startRadius: 4, endRadius: r))
        }
        if b.fill > 0.01 {
            let lvl = PPoly.level(poly, fill: CGFloat(b.fill))
            let liq = PPoly.below(poly, lvl)
            var lp = Path()
            lp.addLines(liq)
            lp.closeSubpath()
            var inner = g
            inner.clip(to: lp)
            if b.potion == .rainbow || b.potion == .wild {
                let cols = (0..<6).map { PotionSim.hue(CGFloat($0) / 6 + (b.potion == .wild ? t * 0.1 : 0)).c(0.95) }
                inner.fill(Path(lp.boundingRect.insetBy(dx: -4, dy: -4)), with: .linearGradient(Gradient(colors: cols), startPoint: CGPoint(x: center.x, y: lp.boundingRect.minY), endPoint: CGPoint(x: center.x, y: lp.boundingRect.maxY)))
            } else {
                inner.fill(Path(lp.boundingRect.insetBy(dx: -4, dy: -4)), with: .linearGradient(Gradient(colors: [b.color.mix(RGB(1, 1, 1), 0.25).c(0.92), b.color.mul(0.8, 0.75, 0.85).c(0.95)]),
                                                                                                startPoint: CGPoint(x: center.x, y: lvl), endPoint: CGPoint(x: center.x, y: lp.boundingRect.maxY)))
            }
            magic(inner, b, center: center, scale: scale, top: lvl, time: t)
            var surface = Path()
            if let a = liq.first(where: { abs($0.y - lvl) < 0.5 }), let z = liq.last(where: { abs($0.y - lvl) < 0.5 }) {
                surface.move(to: a); surface.addLine(to: z)
                g.stroke(surface, with: .color(.white.opacity(0.6)), lineWidth: 1.5 * scale + 0.5)
            }
        }
        glass(g, poly: poly, center: center, angle: angle, scale: scale, shape: shape)
        if cork { self.cork(g, shape: shape, center: center, angle: angle, scale: scale, on: true) }
        if b.potion != nil {
            Twinkles.draw(g, around: center, radius: 46 * scale, time: t + CGFloat(b.id), count: 2, alpha: 0.9)
        }
    }

    private static func magic(_ g: GraphicsContext, _ b: PotionBottle, center: CGPoint, scale: CGFloat, top: CGFloat, time t: CGFloat) {
        let s = scale
        if b.sparkle > 0.2 {
            var dots = Path()
            for k in 0..<Int(6 + b.sparkle * 10) {
                let x = center.x + CGFloat((k * 37) % 60 - 30) * s
                let y = center.y + CGFloat((k * 53) % 90 - 30) * s + sin(t * 0.8 + CGFloat(k)) * 4 * s
                let r = (1.2 + CGFloat(k % 3) * 0.8) * s * (0.7 + 0.3 * sin(t * 4 + CGFloat(k) * 1.7))
                dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            g.fill(dots, with: .color(.white.opacity(0.9)))
        }
        switch b.potion {
        case .love?:
            for k in 0..<3 {
                let y = center.y + 40 * s - ((t * 14 + CGFloat(k) * 26).truncatingRemainder(dividingBy: 78)) * s
                let x = center.x + CGFloat(k - 1) * 16 * s
                g.fill(PetPainter.heartPath(in: CGRect(x: x - 6 * s, y: y - 6 * s, width: 12 * s, height: 11 * s)), with: .color(.white.opacity(0.8)))
            }
        case .mermaid?, .wild?:
            var bub = Path()
            for k in 0..<5 {
                let y = center.y + 50 * s - ((t * 22 + CGFloat(k) * 19).truncatingRemainder(dividingBy: 90)) * s
                let x = center.x + CGFloat((k * 23) % 40 - 20) * s + sin(t * 3 + CGFloat(k)) * 2 * s
                let r = (2 + CGFloat(k % 3)) * s
                bub.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            g.stroke(bub, with: .color(.white.opacity(0.85)), lineWidth: 1.2)
        case .dragon?:
            var em = Path()
            for k in 0..<5 {
                let y = center.y + 46 * s - ((t * 30 + CGFloat(k) * 17).truncatingRemainder(dividingBy: 80)) * s
                let x = center.x + CGFloat((k * 29) % 44 - 22) * s
                let r = 2.2 * s
                em.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            g.fill(em, with: .color(RGB(hex: "#FFE08A").c(0.95)))
        case .frost?:
            var fl = Path()
            for k in 0..<3 {
                let c = CGPoint(x: center.x + CGFloat(k - 1) * 18 * s, y: center.y + CGFloat(k % 2) * 20 * s + 6 * s)
                for a in 0..<3 {
                    let ang = CGFloat(a) * .pi / 3 + t * 0.3
                    fl.move(to: CGPoint(x: c.x - cos(ang) * 7 * s, y: c.y - sin(ang) * 7 * s))
                    fl.addLine(to: CGPoint(x: c.x + cos(ang) * 7 * s, y: c.y + sin(ang) * 7 * s))
                }
            }
            g.stroke(fl, with: .color(.white.opacity(0.9)), lineWidth: 1.6)
        case .dream?:
            let c = CGPoint(x: center.x, y: center.y + 16 * s)
            var moon = Path(ellipseIn: CGRect(x: c.x - 12 * s, y: c.y - 12 * s, width: 24 * s, height: 24 * s))
            moon.addEllipse(in: CGRect(x: c.x - 6 * s, y: c.y - 16 * s, width: 24 * s, height: 24 * s))
            g.fill(moon, with: .color(RGB(hex: "#FFF1B8").c(0.9)), style: FillStyle(eoFill: true))
        case .moonlight?, .golden?, .galaxy?:
            g.fill(Twinkle().path(in: CGRect(x: center.x - 12 * s, y: center.y + 6 * s, width: 24 * s, height: 24 * s)), with: .color(.white.opacity(0.85 + 0.15 * Double(sin(t * 3)))))
        default:
            break
        }
    }

    /// The glass of a bottle: its outline, a bright edge and a shine down one side.
    static func glass(_ g: GraphicsContext, poly: [CGPoint], center: CGPoint, angle: CGFloat, scale: CGFloat, shape: PBottleShape) {
        var p = Path()
        p.addLines(poly)
        p.closeSubpath()
        g.fill(p, with: .color(.white.opacity(0.16)))
        g.stroke(p, with: .color(RGB(hex: "#8E7BC0").c(0.55)), lineWidth: 4.5 * scale)
        g.stroke(p, with: .color(.white.opacity(0.9)), lineWidth: 2.2 * scale)
        var l = g
        l.translateBy(x: center.x, y: center.y)
        l.rotate(by: .radians(Double(angle)))
        l.scaleBy(x: scale, y: scale)
        // the shine
        l.fill(Path(roundedRect: CGRect(x: -shape.neck - 16, y: -8, width: 7, height: 40), cornerRadius: 3.5), with: .color(.white.opacity(0.55)))
        // the lip
        let n = shape.neck
        l.fill(Path(roundedRect: CGRect(x: -n - 4, y: PBottleShape.mouthY - 3, width: n * 2 + 8, height: 8), cornerRadius: 3), with: .color(.white.opacity(0.75)))
        l.stroke(Path(roundedRect: CGRect(x: -n - 4, y: PBottleShape.mouthY - 3, width: n * 2 + 8, height: 8), cornerRadius: 3), with: .color(RGB(hex: "#8E7BC0").c(0.5)), lineWidth: 1.5)
    }

    static func cork(_ g: GraphicsContext, shape: PBottleShape, center: CGPoint, angle: CGFloat, scale: CGFloat, on: Bool) {
        guard on else { return }
        var l = g
        l.translateBy(x: center.x, y: center.y)
        l.rotate(by: .radians(Double(angle)))
        l.scaleBy(x: scale, y: scale)
        let n = shape.neck
        let r = CGRect(x: -n + 1, y: PBottleShape.mouthY - 16, width: n * 2 - 2, height: 18)
        l.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(RGB(hex: "#C99466").c()))
        l.stroke(Path(roundedRect: r, cornerRadius: 4), with: .color(RGB(hex: "#8A5A3C").c()), lineWidth: 2)
        l.fill(Path(ellipseIn: CGRect(x: r.minX + 2, y: r.minY + 3, width: 4, height: 4)), with: .color(RGB(hex: "#8A5A3C").c(0.6)))
        l.fill(Path(ellipseIn: CGRect(x: r.maxX - 7, y: r.minY + 9, width: 3, height: 3)), with: .color(RGB(hex: "#8A5A3C").c(0.6)))
    }

    /// An ingredient's liquid in its bottle.
    static func liquidBottle(_ g: GraphicsContext, shape: PBottleShape, center: CGPoint, angle: CGFloat, scale: CGFloat, fill: CGFloat, color: RGB, alpha: Double, glow: Double, time t: CGFloat) {
        let poly = PPoly.transform(shape.outline, at: center, angle: angle, scale: scale)
        if glow > 0 {
            var gl = g
            gl.blendMode = .plusLighter
            let r = 66 * scale
            gl.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(Gradient(colors: [color.c(0.3 * glow), .clear]), center: center, startRadius: 4, endRadius: r))
        }
        if fill > 0.01 {
            let lvl = PPoly.level(poly, fill: fill)
            let liq = PPoly.below(poly, lvl)
            var lp = Path()
            lp.addLines(liq)
            lp.closeSubpath()
            g.fill(lp, with: .linearGradient(Gradient(colors: [color.mix(RGB(1, 1, 1), 0.25).c(alpha), color.mul(0.82, 0.78, 0.88).c(alpha)]),
                                              startPoint: CGPoint(x: center.x, y: lvl), endPoint: CGPoint(x: center.x, y: lp.boundingRect.maxY)))
            if color.luminance < 0.4 {
                // night sky: tiny stars hang in it
                var inner = g
                inner.clip(to: lp)
                var st = Path()
                for k in 0..<9 {
                    let x = center.x + CGFloat((k * 31) % 50 - 25) * scale
                    let y = center.y + CGFloat((k * 47) % 80 - 20) * scale
                    let r = (1 + CGFloat(k % 2)) * scale * CGFloat(0.7 + 0.3 * sin(Double(t) * 3 + Double(k)))
                    st.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                }
                inner.fill(st, with: .color(.white.opacity(0.9)))
            }
        }
        glass(g, poly: poly, center: center, angle: angle, scale: scale, shape: shape)
    }

    /// The picture on an ingredient's bottle, so she can tell them apart without reading.
    static func label(_ g: GraphicsContext, _ ing: PIngredient, center: CGPoint, angle: CGFloat, scale: CGFloat) {
        var l = g
        l.translateBy(x: center.x, y: center.y)
        l.rotate(by: .radians(Double(angle)))
        l.scaleBy(x: scale, y: scale)
        let c = CGPoint(x: 0, y: 18)
        let tag = Path(ellipseIn: CGRect(x: c.x - 19, y: c.y - 19, width: 38, height: 38))
        l.fill(tag, with: .color(RGB(hex: "#FFF7EA").c(0.95)))
        l.stroke(tag, with: .color(RGB(hex: "#C9A27A").c()), lineWidth: 2)
        switch ing {
        case .water:
            var drop = Path()
            drop.move(to: CGPoint(x: c.x, y: c.y - 12))
            drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y + 12), control: CGPoint(x: c.x + 16, y: c.y + 8))
            drop.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 12), control: CGPoint(x: c.x - 16, y: c.y + 8))
            l.fill(drop, with: .color(RGB(hex: "#6EC6FF").c()))
        case .nectar:
            // a flower
            var fl = Path()
            for k in 0..<5 {
                let a = CGFloat(k) / 5 * 2 * .pi
                fl.addEllipse(in: CGRect(x: c.x + cos(a) * 7 - 6, y: c.y + sin(a) * 7 - 6, width: 12, height: 12))
            }
            l.fill(fl, with: .color(RGB(hex: "#FF7FB6").c()))
            l.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(RGB(hex: "#FFD45A").c()))
        case .mermaid:
            // a shell
            var sh = Path()
            sh.move(to: CGPoint(x: c.x - 13, y: c.y + 6))
            sh.addQuadCurve(to: CGPoint(x: c.x + 13, y: c.y + 6), control: CGPoint(x: c.x, y: c.y - 24))
            sh.addLine(to: CGPoint(x: c.x + 4, y: c.y + 11))
            sh.addLine(to: CGPoint(x: c.x - 4, y: c.y + 11))
            sh.closeSubpath()
            l.fill(sh, with: .color(RGB(hex: "#38D6C8").c()))
            var ribs = Path()
            for k in -2...2 {
                ribs.move(to: CGPoint(x: c.x, y: c.y + 10))
                ribs.addLine(to: CGPoint(x: c.x + CGFloat(k) * 5, y: c.y - 5))
            }
            l.stroke(ribs, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
        case .dragon:
            var f = Path()
            f.move(to: CGPoint(x: c.x - 9, y: c.y + 11))
            f.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 13), control: CGPoint(x: c.x - 14, y: c.y - 2))
            f.addQuadCurve(to: CGPoint(x: c.x + 9, y: c.y + 11), control: CGPoint(x: c.x + 14, y: c.y - 2))
            f.closeSubpath()
            l.fill(f, with: .color(RGB(hex: "#FF7A2A").c()))
            var core = Path()
            core.move(to: CGPoint(x: c.x - 4, y: c.y + 10))
            core.addQuadCurve(to: CGPoint(x: c.x, y: c.y - 2), control: CGPoint(x: c.x - 6, y: c.y + 3))
            core.addQuadCurve(to: CGPoint(x: c.x + 4, y: c.y + 10), control: CGPoint(x: c.x + 6, y: c.y + 3))
            l.fill(core, with: .color(RGB(hex: "#FFE07A").c()))
        case .moon:
            var m = Path(ellipseIn: CGRect(x: c.x - 12, y: c.y - 12, width: 24, height: 24))
            m.addEllipse(in: CGRect(x: c.x - 5, y: c.y - 15, width: 24, height: 24))
            l.fill(m, with: .color(RGB(hex: "#C8B8FF").c()), style: FillStyle(eoFill: true))
        case .night:
            l.fill(PetPainter.starPath(c, 13), with: .color(RGB(hex: "#5A44C8").c()))
        default:
            break
        }
    }

    /// An empty bottle (in the crate, or carried).
    static func empty(_ g: GraphicsContext, center: CGPoint, angle: CGFloat, scale: CGFloat) {
        let poly = PPoly.transform(PBottleShape.round.outline, at: center, angle: angle, scale: scale)
        glass(g, poly: poly, center: center, angle: angle, scale: scale, shape: .round)
    }
}

// MARK: - Things to shake in

enum PieceArt {
    static func draw(_ g: GraphicsContext, _ pc: PPiece, alpha: Double) {
        let k = 1 - pc.dissolve * 0.65
        let a = alpha * Double(1 - pc.dissolve * 0.8)
        guard a > 0.02 else { return }
        if pc.kind == .hair {
            hair(g, pc, alpha: a)
            return
        }
        var l = g
        l.translateBy(x: pc.p.x, y: pc.p.y)
        l.rotate(by: .radians(Double(pc.ang)))
        l.scaleBy(x: k, y: k)
        l.opacity = a
        switch pc.kind {
        case .stars:
            let s = PetPainter.starPath(.zero, 10)
            l.fill(s, with: .color(RGB(hex: "#FFD44A").c()))
            l.stroke(s, with: .color(RGB(hex: "#E0A020").c()), lineWidth: 1.5)
            l.fill(Path(ellipseIn: CGRect(x: -3, y: -4, width: 4, height: 3)), with: .color(.white.opacity(0.8)))
        case .petals:
            var p = Path()
            p.move(to: CGPoint(x: 0, y: -10))
            p.addQuadCurve(to: CGPoint(x: 0, y: 10), control: CGPoint(x: 13, y: -2))
            p.addQuadCurve(to: CGPoint(x: 0, y: -10), control: CGPoint(x: -13, y: -2))
            l.fill(p, with: .color(RGB(hex: "#FF8DBA").c()))
            var vein = Path()
            vein.move(to: CGPoint(x: 0, y: -7)); vein.addLine(to: CGPoint(x: 0, y: 7))
            l.stroke(vein, with: .color(RGB(hex: "#E8609A").c(0.7)), lineWidth: 1.2)
        case .berries:
            l.fill(Path(ellipseIn: CGRect(x: -8, y: -8, width: 16, height: 16)), with: .color(RGB(hex: "#4A72FF").c()))
            l.fill(Path(ellipseIn: CGRect(x: -5, y: -5, width: 5, height: 4)), with: .color(.white.opacity(0.75)))
            var leaf = Path()
            leaf.move(to: CGPoint(x: 0, y: -8)); leaf.addQuadCurve(to: CGPoint(x: 7, y: -12), control: CGPoint(x: 4, y: -14))
            l.stroke(leaf, with: .color(RGB(hex: "#5CC46A").c()), lineWidth: 2.5)
        case .frost:
            var s = Path()
            for i in 0..<3 {
                let ang = CGFloat(i) * .pi / 3
                s.move(to: CGPoint(x: -cos(ang) * 10, y: -sin(ang) * 10))
                s.addLine(to: CGPoint(x: cos(ang) * 10, y: sin(ang) * 10))
            }
            l.stroke(s, with: .color(RGB(hex: "#7FD8F2").c()), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            l.stroke(s, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        case .lavender:
            var stem = Path()
            stem.move(to: CGPoint(x: 0, y: 12)); stem.addLine(to: CGPoint(x: 0, y: -12))
            l.stroke(stem, with: .color(RGB(hex: "#6FB86A").c()), lineWidth: 2.2)
            for i in 0..<4 {
                let y = -10 + CGFloat(i) * 5
                l.fill(Path(ellipseIn: CGRect(x: -5, y: y - 3, width: 5, height: 6)), with: .color(RGB(hex: "#A27BFF").c()))
                l.fill(Path(ellipseIn: CGRect(x: 0, y: y - 2, width: 5, height: 6)), with: .color(RGB(hex: "#8A62F0").c()))
            }
        default:
            break
        }
    }

    private static func hair(_ g: GraphicsContext, _ pc: PPiece, alpha: Double) {
        let pts = pc.trail.isEmpty ? [pc.p, CGPoint(x: pc.p.x + 20, y: pc.p.y + 4)] : pc.trail
        guard pts.count > 1 else { return }
        var l = g
        l.opacity = alpha
        // a soft wavy rainbow strand
        for i in 0..<(pts.count - 1) {
            var s = Path()
            let a = pts[i], b = pts[i + 1]
            let wob = sin(CGFloat(i) * 1.1 + CGFloat(pc.seed)) * 3
            s.move(to: CGPoint(x: a.x, y: a.y + wob))
            s.addLine(to: CGPoint(x: b.x, y: b.y - wob))
            l.stroke(s, with: .color(PotionSim.hue(CGFloat(i) / CGFloat(pts.count) + CGFloat(pc.seed) * 0.03).c()), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }
}
