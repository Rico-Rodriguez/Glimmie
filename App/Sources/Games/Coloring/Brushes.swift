import UIKit
import QuartzCore

// MARK: - Paper texture

/// The paper's tooth: the tiny hills and valleys of its fibres. Wax and pencil catch on the hills
/// first and skip the valleys, so light strokes look speckled and pressing harder fills them in.
/// Tiles are 256x256 and repeat across the page. Values are 0 (valley) ... 1 (hill).
enum PaperTooth {
    static let size = 256

    /// Fine grain (2 to 16 px bumps): crayon, pencil, eraser, marker edges, watercolor granulation.
    static let fine: UnsafeMutablePointer<Float> = make(seed: 11, cells: [(2, 0.4), (4, 0.3), (8, 0.2), (16, 0.1)])
    /// A slow wobble (32 to 64 px): the uneven edge of a watercolor wash.
    static let soft: UnsafeMutablePointer<Float> = make(seed: 23, cells: [(32, 0.6), (64, 0.4)])

    @inline(__always) static func at(_ t: UnsafeMutablePointer<Float>, _ x: Int, _ y: Int) -> Float {
        t[(y & 255) << 8 | (x & 255)]
    }

    /// Smooth value noise from a few octaves, stretched so it uses the whole 0...1 range.
    static func make(seed: UInt64, cells: [(Int, Double)]) -> UnsafeMutablePointer<Float> {
        let n = size
        var sum = [Double](repeating: 0, count: n * n)
        var rng = PaintRandom(seed: seed)
        for (cell, weight) in cells {
            let g = n / cell
            let grid = (0..<(g * g)).map { _ in rng.next() }
            for y in 0..<n {
                let fy0 = Double(y) / Double(cell)
                let y0 = Int(fy0)
                var fy = fy0 - Double(y0)
                fy = fy * fy * (3 - 2 * fy)
                let ya = (y0 % g) * g, yb = ((y0 + 1) % g) * g
                for x in 0..<n {
                    let fx0 = Double(x) / Double(cell)
                    let x0 = Int(fx0)
                    var fx = fx0 - Double(x0)
                    fx = fx * fx * (3 - 2 * fx)
                    let xa = x0 % g, xb = (x0 + 1) % g
                    let top = grid[ya + xa] * (1 - fx) + grid[ya + xb] * fx
                    let bottom = grid[yb + xa] * (1 - fx) + grid[yb + xb] * fx
                    sum[y * n + x] += (top * (1 - fy) + bottom * fy) * weight
                }
            }
        }
        let sorted = sum.sorted()
        let lo = sorted[sorted.count / 50], hi = sorted[sorted.count * 49 / 50]
        let out = UnsafeMutablePointer<Float>.allocate(capacity: n * n)
        for i in 0..<(n * n) { out[i] = Float(max(0, min(1, (sum[i] - lo) / max(1e-9, hi - lo)))) }
        return out
    }
}

/// A repeatable 0...1 value for a pixel cell (used to place glitter specks).
@inline(__always) func paintHash(_ x: Int, _ y: Int, _ seed: UInt32) -> Float {
    var h = (UInt32(truncatingIfNeeded: x) &* 0x8DA6_B343) ^ (UInt32(truncatingIfNeeded: y) &* 0xD816_3841) ^ (seed &* 0xCB1A_B31F)
    h ^= h >> 13
    h = h &* 0x5BD1_E995
    h ^= h >> 15
    return Float(h & 0xFFFF) / 65535
}

@inline(__always) private func packRGB(_ r: Float, _ g: Float, _ b: Float) -> UInt32 {
    UInt32(max(0, min(255, r + 0.5))) | (UInt32(max(0, min(255, g + 0.5))) << 8) | (UInt32(max(0, min(255, b + 0.5))) << 16) | 0xFF00_0000
}

@inline(__always) private func clamp01(_ v: Float) -> Float { max(0, min(1, v)) }

// MARK: - Glitter

/// One flake of glitter on the page. It twinkles when its moment comes round, or when the iPad tilts.
struct GlitterFlake: Equatable {
    var x: Float, y: Float      // paper pixels
    var size: Float             // 0.6 ... 1.3
    var phase: Float            // radians
    var speed: Float            // radians per second
    var tiltX: Float, tiltY: Float   // how it answers to tilting (-1 ... 1)

    static let stride = 7

    /// Flakes as raw floats, for saving.
    static func encode(_ flakes: [GlitterFlake]) -> Data {
        var f = [Float]()
        f.reserveCapacity(flakes.count * stride)
        for k in flakes { f += [k.x, k.y, k.size, k.phase, k.speed, k.tiltX, k.tiltY] }
        return f.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func decode(_ data: Data) -> [GlitterFlake] {
        let n = data.count / (MemoryLayout<Float>.size * stride)
        guard n > 0 else { return [] }
        var f = [Float](repeating: 0, count: n * stride)
        _ = f.withUnsafeMutableBytes { data.copyBytes(to: $0, count: n * stride * MemoryLayout<Float>.size) }
        return (0..<n).map { i in
            let o = i * stride
            return GlitterFlake(x: f[o], y: f[o + 1], size: f[o + 2], phase: f[o + 3], speed: f[o + 4], tiltX: f[o + 5], tiltY: f[o + 6])
        }
    }

    /// How bright its glint is right now (0 = not glinting).
    @inline(__always) func glint(time t: Double, roll: Float, pitch: Float) -> Float {
        let s = sin(Float(t.truncatingRemainder(dividingBy: 10_000)) * speed + phase + (roll * tiltX + pitch * tiltY) * 5)
        return s > 0.965 ? (s - 0.965) / 0.035 : 0
    }
}

extension PaintRegionMask {
    @inline(__always) func contains(_ x: Int, _ y: Int) -> Bool {
        guard x >= box.minX, x <= box.maxX, y >= box.minY, y <= box.maxY else { return false }
        return bits[(y - box.minY) * box.width + (x - box.minX)] != 0
    }
}

// MARK: - Brushes
//
// Each brush copies what the real tool does on paper:
// - marker: see-through ink that stays even inside one stroke, darkens where strokes cross, mixes
//   (yellow over blue makes green), has a soft fibre edge, and blots when held still.
// - crayon: wax that catches on the paper's hills; press harder or go over it again to fill the gaps.
// - pencil: thin, grainy and light; harder pressure (Apple Pencil) is darker, tilting it shades wide and soft.
// - paint: a watercolor wash, wet and soft while painting, then it dries lighter with darker edges and
//   pigment settling in the paper's grain.
// - glitter: glitter glue, a tinted gel full of specks and flakes that keep twinkling.
// - rainbow: a marker whose ink runs through the rainbow.
// - stamps: rubber stamps, inked a little unevenly.
// - eraser: lifts color from the paper's hills first; rub more to get it all.

extension ColoringPaper {
    /// Offset added to a pixel's depth in `acc`, so 0 can mean "the stroke never came near".
    private static let depthOffset: Float = 64

    func beginStroke(at p: CGPoint, brush: PaintBrush, color: PaintColor, size: CGFloat, stayInLines: Bool,
                     pressure: CGFloat = 0.6, tilt: CGFloat = 0) {
        settle()
        // Forget the last stroke.
        if let b = strokeBox {
            for y in b.minY...b.maxY { (acc + y * w + b.minX).update(repeating: 0, count: b.width) }
        }
        strokeBox = nil
        memcpy(base, px, w * h * 4)
        self.brush = brush
        brushColor = brush == .eraser ? .white : color
        brushSize = size
        self.pressure = Float(max(0.05, min(1, pressure)))
        self.tilt = Float(max(0, min(1, tilt)))
        travelled = 0
        nextStamp = 0
        holdGrow = 0
        strokeSeed &+= 1
        last = p
        inStroke = true
        lastMoveTime = CACurrentMediaTime()
        clip = nil
        if stayInLines, let label = regions.region(near: Int(p.x), Int(p.y), radius: 6) {
            clip = mask(label)
        }
        if brush == .rainbow && tint == nil {
            tint = .allocate(capacity: w * h)
            tint!.initialize(repeating: 0, count: w * h)
        }
        segment(from: p, to: p)
    }

    func continueStroke(to p: CGPoint, pressure: CGFloat? = nil, tilt: CGFloat? = nil) {
        if let pressure { self.pressure = self.pressure * 0.6 + Float(max(0.05, min(1, pressure))) * 0.4 }
        if let tilt { self.tilt = self.tilt * 0.6 + Float(max(0, min(1, tilt))) * 0.4 }
        let d = hypot(p.x - last.x, p.y - last.y)
        guard d >= 1 else { return }
        segment(from: last, to: p)
        last = p
        holdGrow = max(0, holdGrow - Float(d) * 0.01)
        lastMoveTime = CACurrentMediaTime()
    }

    func endStroke() {
        inStroke = false
        clip = nil
        if brush == .paint, strokeBox != nil {
            drying = true
            dryStart = CACurrentMediaTime()
            dryT = 0
            dryDrawn = 0
        }
    }

    /// Dries any wet paint at once (before undo, a fill, a new stroke or saving).
    func settle() {
        guard drying else { return }
        drying = false
        dryT = 1
        if let b = strokeBox { composite(b) }
    }

    /// Call once a frame. Ink spreads while she holds the marker or brush still, and watercolor dries.
    /// Returns true when the paper changed.
    func tick(now: CFTimeInterval) -> Bool {
        var changed = false
        let dt = lastTick > 0 ? Float(min(0.05, now - lastTick)) : 0
        lastTick = now
        if inStroke, brush == .marker || brush == .paint || brush == .rainbow, now - lastMoveTime > 0.15, holdGrow < 0.55 {
            holdGrow = min(0.55, holdGrow + dt * (brush == .paint ? 0.45 : 0.3))
            segment(from: last, to: last, hold: true)
            changed = true
        }
        if drying {
            dryT = min(1, Float((now - dryStart) / 0.9))
            if dryT >= 1 || dryT - dryDrawn >= 0.1 {
                dryDrawn = dryT
                if let b = strokeBox { composite(b) }
                if dryT >= 1 { drying = false }
                changed = true
            }
        }
        return changed
    }

    // MARK: Painting a piece of the stroke

    private func segment(from a: CGPoint, to b: CGPoint, hold: Bool = false) {
        let len = hold ? 0 : hypot(b.x - a.x, b.y - a.y)
        let p = pressure
        var box: PixelBox?
        switch brush {
        case .marker:
            radius = Float(brushSize / 2) * (0.92 + 0.16 * p) * (1 + holdGrow)
            box = capsule(a, b)
        case .rainbow:
            radius = Float(brushSize / 2) * (0.92 + 0.16 * p) * (1 + holdGrow)
            let ca = rainbowColor(travelled), cb = rainbowColor(travelled + len)
            box = capsule(a, b, colorA: ca, colorB: cb)
        case .glitter:
            radius = Float(brushSize / 2)
            box = capsule(a, b)
            if !hold { addFlakes(a, b, len: len) }
        case .paint:
            radius = Float(brushSize) * 0.6 * (0.7 + 0.6 * p) * (1 + holdGrow * 0.6)
            box = capsule(a, b)
        case .crayon:
            radius = Float(brushSize) * 0.55 * (0.9 + 0.2 * p)
            box = dabs(a, b, len: len, flow: 0.7 + 0.55 * p)
        case .pencil:
            radius = Float(brushSize) * 0.22 * (0.75 + 0.5 * p) * (1 + 1.6 * tilt)
            box = dabs(a, b, len: len, flow: (0.55 + 0.6 * p) * (1 - 0.5 * tilt))
        case .eraser:
            radius = Float(brushSize) * 0.6
            box = dabs(a, b, len: len, flow: 1)
            let r = CGFloat(radius) + 2
            flakes.removeAll { distanceToSegment(CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)), a, b) < r }
        case .stamps:
            stamps(a, b, len: len)
        }
        if let box {
            strokeBox = strokeBox.map { union($0, box) } ?? box
            composite(box)
        }
        if !hold { travelled += len }
    }

    private func rainbowColor(_ distance: CGFloat) -> UInt32 { PaintColor.hsb(Double(distance / 500), 0.62, 1).packed }

    private func union(_ a: PixelBox, _ b: PixelBox) -> PixelBox {
        PixelBox(minX: min(a.minX, b.minX), minY: min(a.minY, b.minY), maxX: max(a.maxX, b.maxX), maxY: max(a.maxY, b.maxY))
    }

    private func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let vx = b.x - a.x, vy = b.y - a.y
        let l2 = vx * vx + vy * vy
        let t = l2 > 0 ? max(0, min(1, ((p.x - a.x) * vx + (p.y - a.y) * vy) / l2)) : 0
        return hypot(p.x - (a.x + t * vx), p.y - (a.y + t * vy))
    }

    /// The pixels within `reach` of a..b, cut to the paper and to the area she's staying inside.
    private func area(_ a: CGPoint, _ b: CGPoint, reach: Float) -> PixelBox? {
        let r = CGFloat(reach) + 1
        var box = PixelBox(minX: max(0, Int(floor(min(a.x, b.x) - r))), minY: max(0, Int(floor(min(a.y, b.y) - r))),
                           maxX: min(w - 1, Int(ceil(max(a.x, b.x) + r))), maxY: min(h - 1, Int(ceil(max(a.y, b.y) + r))))
        if let c = clip?.box {
            box = PixelBox(minX: max(box.minX, c.minX), minY: max(box.minY, c.minY), maxX: min(box.maxX, c.maxX), maxY: min(box.maxY, c.maxY))
        }
        return box.minX <= box.maxX && box.minY <= box.maxY ? box : nil
    }

    /// Brushes that lay down an even film (marker, rainbow, glitter, paint): each pixel keeps the
    /// deepest it has been inside the stroke, so passing over it again doesn't change it.
    private func capsule(_ a: CGPoint, _ b: CGPoint, colorA: UInt32 = 0, colorB: UInt32 = 0) -> PixelBox? {
        let r = radius
        let wet = brush == .paint
        let pad: Float = wet ? r * 0.35 + 4 : 3
        let reach = r + pad
        guard let box = area(a, b, reach: reach) else { return nil }
        let ax = Float(a.x), ay = Float(a.y), vx = Float(b.x - a.x), vy = Float(b.y - a.y)
        let l2 = max(vx * vx + vy * vy, 1e-6)
        let K = ColoringPaper.depthOffset
        let rainbow = brush == .rainbow, tintBuf = tint
        let fine = PaperTooth.fine, soft = PaperTooth.soft
        let clip = self.clip
        let cA = colorA, cB = colorB
        for y in box.minY...box.maxY {
            let fy = Float(y) + 0.5
            let row = y * w
            for x in box.minX...box.maxX {
                if let clip, !clip.contains(x, y) { continue }
                let fx = Float(x) + 0.5
                let t = max(0, min(1, ((fx - ax) * vx + (fy - ay) * vy) / l2))
                let dx = fx - (ax + t * vx), dy = fy - (ay + t * vy)
                let d = (dx * dx + dy * dy).squareRoot()
                if d > reach { continue }
                var dep = r - d
                if wet {
                    dep += (PaperTooth.at(soft, x, y) - 0.5) * r * 0.6
                } else {
                    dep += (PaperTooth.at(fine, x, y) - 0.5) * 1.3
                }
                let v = dep + K
                let i = row + x
                if v > acc[i] {
                    acc[i] = max(v, 0.001)
                    if rainbow, let tintBuf { tintBuf[i] = t < 0.5 ? cA : cB }
                }
            }
        }
        return box
    }

    /// Brushes that rub (crayon, pencil, eraser): round dabs along the line whose amounts add up,
    /// so scribbling back and forth builds the color.
    private func dabs(_ a: CGPoint, _ b: CGPoint, len: CGFloat, flow: Float) -> PixelBox? {
        let r = radius
        let sp = max(1, r * 0.3)
        let per = flow * sp / (2 * r)
        var box: PixelBox?
        var s = nextStamp
        let fine = PaperTooth.fine
        let clip = self.clip
        while s <= travelled + len {
            let t = len > 0 ? (s - travelled) / len : 0
            let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            s += CGFloat(sp)
            let reach = r * 1.12 + 1
            guard let db = area(c, c, reach: reach) else { continue }
            let cx = Float(c.x), cy = Float(c.y)
            let soft = 0.35 * r
            for y in db.minY...db.maxY {
                let fy = Float(y) + 0.5 - cy
                let row = y * w
                for x in db.minX...db.maxX {
                    if let clip, !clip.contains(x, y) { continue }
                    let fx = Float(x) + 0.5 - cx
                    let d = (fx * fx + fy * fy).squareRoot()
                    if d > reach { continue }
                    // A ragged tip: the edge wanders with the grain.
                    let rr = r * (0.82 + 0.3 * PaperTooth.at(fine, x + 19, y + 73))
                    let f = (rr - d) / soft
                    if f <= 0 { continue }
                    acc[row + x] += per * min(1, f)
                }
            }
            box = box.map { union($0, db) } ?? db
        }
        nextStamp = s
        return box
    }

    // MARK: Mixing the stroke into the paper

    /// Repaints `box` from the paper under the stroke plus the stroke itself.
    func composite(_ box: PixelBox) {
        let K = ColoringPaper.depthOffset
        let cr = Float(brushColor.r * 255), cg = Float(brushColor.g * 255), cb = Float(brushColor.b * 255)
        let fine = PaperTooth.fine
        let r = radius
        let t = drying || brush == .paint ? dryT : 0
        let wetT = inStroke ? Float(0) : t
        // Glitter speck colors: light, white, deep and a shimmer of the next hue.
        let speck: [(Float, Float, Float)] = [
            (cr * 0.45 + 140, cg * 0.45 + 140, cb * 0.45 + 140), (250, 250, 250),
            (cr * 0.86, cg * 0.86, cb * 0.86), (cb * 0.5 + 128, cr * 0.5 + 128, cg * 0.5 + 128),
        ]
        let seed = strokeSeed
        // Going over it again in a new stroke presses wax and pencil into some of the valleys the
        // last stroke skipped: the grain is shifted a few pixels per stroke so new gaps fill in.
        let sx = Int(seed &* 37 % 9), sy = Int(seed &* 53 % 9)
        for y in box.minY...box.maxY {
            let row = y * w
            for x in box.minX...box.maxX {
                let i = row + x
                let A = acc[i]
                if A <= 0 { continue }
                let b0 = base[i]
                let br = Float(b0 & 0xFF), bg = Float((b0 >> 8) & 0xFF), bb = Float((b0 >> 16) & 0xFF)
                var or = br, og = bg, ob = bb
                switch brush {
                case .marker, .rainbow:
                    let dep = A - K
                    let cov = clamp01(dep / 1.3)
                    if cov <= 0 { break }
                    var mr = cr, mg = cg, mb = cb
                    if brush == .rainbow, let tint {
                        let c = tint[i]
                        mr = Float(c & 0xFF); mg = Float((c >> 8) & 0xFF); mb = Float((c >> 16) & 0xFF)
                    }
                    // Ink pools a little at the edge of the stroke.
                    let a = (0.86 + 0.12 * exp(-max(dep, 0) / 2.2)) * cov
                    or = br * (1 - a) + (0.78 * br * mr / 255 + 0.22 * mr) * a
                    og = bg * (1 - a) + (0.78 * bg * mg / 255 + 0.22 * mg) * a
                    ob = bb * (1 - a) + (0.78 * bb * mb / 255 + 0.22 * mb) * a
                case .glitter:
                    let dep = A - K
                    let cov = clamp01(dep / 1.3)
                    if cov <= 0 { break }
                    let a = 0.42 * cov
                    or = br * (1 - a) + (0.7 * br * cr / 255 + 0.3 * cr) * a
                    og = bg * (1 - a) + (0.7 * bg * cg / 255 + 0.3 * cg) * a
                    ob = bb * (1 - a) + (0.7 * bb * cb / 255 + 0.3 * cb) * a
                    if cov > 0.5 {
                        let hsh = paintHash(x >> 1, y >> 1, seed)
                        if hsh < 0.17 {
                            let s = speck[Int(paintHash(x >> 1, y >> 1, seed &+ 7) * 3.99)]
                            or = s.0; og = s.1; ob = s.2
                        }
                    }
                case .paint:
                    // Wet: soft and even. Drying: spreads a touch, the middle lightens, the edge darkens
                    // and pigment settles into the grain.
                    let dep = A - K + 2.5 * wetT
                    let ramp = r * 0.45 * (1 - wetT) + 1.6 * wetT
                    let cov = clamp01(dep / ramp)
                    if cov <= 0 { break }
                    let dens = 0.5 * (1 - wetT) + wetT * (0.34 + 0.45 * exp(-max(dep, 0) / 3))
                    let gran = 1 + 0.45 * (0.5 - PaperTooth.at(fine, x, y)) * wetT
                    let a = min(0.95, dens * cov * gran)
                    or = br * (1 - a + a * cr / 255)
                    og = bg * (1 - a + a * cg / 255)
                    ob = bb * (1 - a + a * cb / 255)
                case .crayon:
                    let cov = clamp01((PaperTooth.at(fine, x + sx, y + sy) - (1 - A)) / 0.12)
                    let a = 0.92 * cov
                    or = br * (1 - a) + cr * a
                    og = bg * (1 - a) + cg * a
                    ob = bb * (1 - a) + cb * a
                case .pencil:
                    let cov = clamp01((PaperTooth.at(fine, x + 57 + sx, y + 101 + sy) - (1 - A)) / 0.3)
                    let a = 0.8 * cov
                    or = br * (1 - a + a * cr / 255)
                    og = bg * (1 - a + a * cg / 255)
                    ob = bb * (1 - a + a * cb / 255)
                case .eraser:
                    let e = clamp01(A * 1.8 - 0.35 * (1 - PaperTooth.at(fine, x, y)))
                    or = br + (255 - br) * e
                    og = bg + (255 - bg) * e
                    ob = bb + (255 - bb) * e
                case .stamps:
                    break
                }
                px[i] = packRGB(or, og, ob)
            }
        }
    }

    // MARK: Glitter flakes

    private func addFlakes(_ a: CGPoint, _ b: CGPoint, len: CGFloat) {
        let r = CGFloat(radius)
        var n = Double(len * r / 75)
        if len == 0 { n = 3 }
        while n > 0 {
            if n < 1 && rng.next() > n { break }
            n -= 1
            let t = CGFloat(rng.next())
            let ang = CGFloat(rng.next() * 2 * .pi), dist = r * 0.9 * CGFloat(rng.next().squareRoot())
            let x = a.x + (b.x - a.x) * t + cos(ang) * dist, y = a.y + (b.y - a.y) * t + sin(ang) * dist
            addFlake(x: Int(x), y: Int(y))
        }
    }

    private func addFlake(x: Int, y: Int) {
        guard x >= 0, y >= 0, x < w, y < h, regions.label(x, y) != -1 else { return }
        if let clip, !clip.contains(x, y) { return }
        flakes.append(GlitterFlake(x: Float(x), y: Float(y), size: Float(0.6 + 0.7 * rng.next()),
                                   phase: Float(rng.next() * 2 * .pi), speed: Float(1.2 + 3 * rng.next()),
                                   tiltX: Float(rng.next() * 2 - 1), tiltY: Float(rng.next() * 2 - 1)))
        if flakes.count > ColoringPaper.maxFlakes { flakes.removeFirst(flakes.count - ColoringPaper.maxFlakes) }
    }

    /// Scatters flakes over a glitter-filled area.
    func sprinkleFlakes(in m: PaintRegionMask) {
        let area = m.bits.reduce(0) { $0 + ($1 != 0 ? 1 : 0) }
        let n = min(2500, area / 550 + 2)
        var placed = 0, tries = 0
        while placed < n && tries < n * 6 {
            tries += 1
            let x = m.box.minX + Int(rng.next() * Double(m.box.width))
            let y = m.box.minY + Int(rng.next() * Double(m.box.height))
            guard m.contains(x, y), regions.label(x, y) != -1 else { continue }
            flakes.append(GlitterFlake(x: Float(x), y: Float(y), size: Float(0.6 + 0.7 * rng.next()),
                                       phase: Float(rng.next() * 2 * .pi), speed: Float(1.2 + 3 * rng.next()),
                                       tiltX: Float(rng.next() * 2 - 1), tiltY: Float(rng.next() * 2 - 1)))
            placed += 1
        }
        if flakes.count > ColoringPaper.maxFlakes { flakes.removeFirst(flakes.count - ColoringPaper.maxFlakes) }
    }

    // MARK: Stamps

    /// Rubber stamps: the shape inked a little unevenly, with a few gaps where the paper dips,
    /// a slightly darker rim, and one side pressed harder than the other.
    private func stamps(_ a: CGPoint, _ b: CGPoint, len: CGFloat) {
        let spacing = brushSize * 1.9
        var s = nextStamp
        while s <= travelled + len {
            let t = len > 0 ? (s - travelled) / len : 0
            let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let shape: Int
            switch stampShape {
            case .heart: shape = 0
            case .star: shape = 1
            case .sparkle: shape = 2
            case .cycle: shape = Int(s / spacing) % 3
            }
            stamp(at: c, shape: shape)
            s += spacing
        }
        nextStamp = s
    }

    private func stamp(at c: CGPoint, shape: Int) {
        let n = Int(brushSize * 2.2) + 6
        var m = [UInt8](repeating: 0, count: n * n)
        let half = CGFloat(n) / 2
        let center = CGPoint(x: half, y: half)
        let rot = CGFloat(rng.next()) * 0.6 - 0.3
        m.withUnsafeMutableBytes { buf in
            guard let g = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            g.setFillColor(gray: 1, alpha: 1)
            switch shape {
            case 0: g.addPath(PaintShapes.heart(center: center, size: brushSize * 1.6, flipY: true))
            case 1: g.addPath(PaintShapes.star(center: center, radius: brushSize * 0.85, rotation: rot))
            default: g.addPath(PaintShapes.twinkle(center: center, radius: brushSize * 0.8))
            }
            g.fillPath()
        }
        let cr = Float(brushColor.r * 255), cg = Float(brushColor.g * 255), cb = Float(brushColor.b * 255)
        let ang = rng.next() * 2 * .pi
        let gx = Float(cos(ang)), gy = Float(sin(ang))
        let ox = Int(c.x - half), oy = Int(c.y - half)
        let fine = PaperTooth.fine
        for j in 0..<n {
            // The context's rows run bottom to top.
            let y = oy + j
            guard y >= 0, y < h else { continue }
            let mrow = (n - 1 - j) * n
            for k in 0..<n {
                let x = ox + k
                guard x >= 0, x < w else { continue }
                let mv = m[mrow + k]
                if mv == 0 { continue }
                if let clip, !clip.contains(x, y) { continue }
                var cov = Float(mv) / 255
                // Darker rim: ink squeezed to the edge of the rubber.
                var edge = false
                for (dx, dy) in [(2, 0), (-2, 0), (0, 2), (0, -2)] {
                    let kk = k + dx, jj = (n - 1 - j) + dy
                    if kk < 0 || jj < 0 || kk >= n || jj >= n || m[jj * n + kk] < 128 { edge = true; break }
                }
                let tooth = PaperTooth.at(fine, x, y)
                let press = 0.82 + 0.18 * (gx * Float(k - n / 2) + gy * Float(j - n / 2)) / Float(n / 2)
                cov *= (tooth < 0.16 ? 0.3 : 0.78 + 0.22 * tooth) * press * (edge ? 1.12 : 1)
                let a = min(0.97, cov)
                let i = y * w + x
                let b0 = px[i]
                let br = Float(b0 & 0xFF), bg = Float((b0 >> 8) & 0xFF), bb = Float((b0 >> 16) & 0xFF)
                px[i] = packRGB(br * (1 - a) + (0.6 * br * cr / 255 + 0.4 * cr) * a,
                                bg * (1 - a) + (0.6 * bg * cg / 255 + 0.4 * cg) * a,
                                bb * (1 - a) + (0.6 * bb * cb / 255 + 0.4 * cb) * a)
            }
        }
    }
}
