import UIKit

// MARK: - Colors

/// An opaque color, stored the way the paper's pixels are: bytes R, G, B, A in memory.
struct PaintColor: Equatable, Codable {
    var r: Double, g: Double, b: Double

    var packed: UInt32 {
        let R = UInt32(max(0, min(255, (r * 255).rounded())))
        let G = UInt32(max(0, min(255, (g * 255).rounded())))
        let B = UInt32(max(0, min(255, (b * 255).rounded())))
        return R | (G << 8) | (B << 16) | 0xFF00_0000
    }

    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }

    /// Mixes toward `other` by `t` (0 = self, 1 = other).
    func mix(_ other: PaintColor, _ t: Double) -> PaintColor {
        PaintColor(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func scaled(_ k: Double) -> PaintColor { PaintColor(r: min(1, r * k), g: min(1, g * k), b: min(1, b * k)) }

    static let white = PaintColor(r: 1, g: 1, b: 1)

    static func hex(_ v: UInt32) -> PaintColor {
        PaintColor(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }

    static func hsb(_ h: Double, _ s: Double, _ v: Double) -> PaintColor {
        let hh = (h - floor(h)) * 6
        let i = Int(hh) % 6, f = hh - floor(hh)
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch i {
        case 0: return PaintColor(r: v, g: t, b: p)
        case 1: return PaintColor(r: q, g: v, b: p)
        case 2: return PaintColor(r: p, g: v, b: t)
        case 3: return PaintColor(r: p, g: q, b: v)
        case 4: return PaintColor(r: t, g: p, b: v)
        default: return PaintColor(r: v, g: p, b: q)
        }
    }
}

// MARK: - Fills

enum ColoringFill: String, CaseIterable, Codable {
    case solid, glitter, stripes, dots, hearts, stars, rainbow, ombre
}

/// Works out the color of every pixel of a fill. Patterns are small tiles repeated across the page,
/// so they line up between neighbouring areas.
struct FillPainter {
    let style: ColoringFill
    let base: PaintColor
    private var tile: [UInt32] = []
    private var tw = 1, th = 1

    init(style: ColoringFill, base: PaintColor) {
        self.style = style
        self.base = base
        switch style {
        case .solid: tile = [base.packed]
        case .glitter: makeGlitter()
        case .stripes, .dots, .hearts, .stars: makePattern()
        case .rainbow, .ombre: break
        }
    }

    /// Color for pixel (x, y) of an area whose bounding box is `box`.
    @inline(__always)
    func color(_ x: Int, _ y: Int, _ box: PixelBox) -> UInt32 {
        switch style {
        case .rainbow:
            let t = Double(x - box.minX) / Double(max(1, box.maxX - box.minX))
            return PaintColor.hsb(t * 0.83, 0.55, 1).packed
        case .ombre:
            let t = Double(y - box.minY) / Double(max(1, box.maxY - box.minY))
            return base.mix(.white, 0.75 * t).packed
        default:
            return tile[(y % th) * tw + (x % tw)]
        }
    }

    /// Rainbow and ombre are worked out per pixel; this caches a row or column of them.
    func line(for box: PixelBox) -> [UInt32]? {
        switch style {
        case .rainbow: return (box.minX...box.maxX).map { color($0, box.minY, box) }
        case .ombre: return (box.minY...box.maxY).map { color(box.minX, $0, box) }
        default: return nil
        }
    }

    private mutating func makeGlitter() {
        tw = 96; th = 96
        var rng = PaintRandom(seed: 7)
        let light = base.mix(.white, 0.65)
        tile = (0..<(tw * th)).map { _ in
            let r = rng.next()
            if r < 0.045 { return light.packed }
            if r < 0.06 { return base.mix(.white, 0.9).packed }
            if r < 0.09 { return base.scaled(0.78).packed }
            return base.scaled(0.9 + 0.2 * rng.next()).packed
        }
    }

    private mutating func makePattern() {
        let size = style == .stripes ? 32 : 56
        tw = size; th = size
        guard let ctx = ColoringPaper.makeContext(width: size, height: size) else { tile = [base.packed]; return }
        let light = base.mix(.white, 0.6)
        ctx.setFillColor(base.cg)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.setFillColor(light.cg)
        let s = CGFloat(size)
        switch style {
        case .stripes:
            // Diagonal stripes that tile seamlessly.
            for k in -2...2 {
                let o = CGFloat(k) * s
                let p = CGMutablePath()
                p.move(to: CGPoint(x: o, y: 0)); p.addLine(to: CGPoint(x: o + s / 2, y: 0))
                p.addLine(to: CGPoint(x: o + s / 2 + s, y: s)); p.addLine(to: CGPoint(x: o + s, y: s))
                p.closeSubpath()
                ctx.addPath(p)
            }
            ctx.fillPath()
        case .dots:
            for (cx, cy) in [(0.25, 0.25), (0.75, 0.75)] {
                ctx.fillEllipse(in: CGRect(x: cx * s - 8, y: cy * s - 8, width: 16, height: 16))
            }
        case .hearts:
            for (cx, cy) in [(0.27, 0.27), (0.77, 0.77)] {
                ctx.addPath(PaintShapes.heart(center: CGPoint(x: cx * s, y: cy * s), size: 20, flipY: true)); ctx.fillPath()
            }
        case .stars:
            for (cx, cy) in [(0.27, 0.27), (0.77, 0.77)] {
                ctx.addPath(PaintShapes.star(center: CGPoint(x: cx * s, y: cy * s), radius: 12)); ctx.fillPath()
            }
        default: break
        }
        tile = ColoringPaper.pixels(of: ctx)
    }
}

/// A tiny, repeatable random number generator (so glitter looks the same every time).
struct PaintRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}

enum PaintShapes {
    /// Heart centred on `center`, about `size` wide. `flipY` for contexts whose y axis points up.
    static func heart(center c: CGPoint, size: CGFloat, flipY: Bool = false) -> CGPath {
        let s = size / 2, k: CGFloat = flipY ? -1 : 1
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * s, y: c.y + k * y * s) }
        let p = CGMutablePath()
        p.move(to: pt(0, 0.9))
        p.addCurve(to: pt(-1.05, -0.35), control1: pt(-0.2, 0.7), control2: pt(-1.05, 0.15))
        p.addCurve(to: pt(0, -0.5), control1: pt(-1.05, -0.95), control2: pt(-0.25, -1.05))
        p.addCurve(to: pt(1.05, -0.35), control1: pt(0.25, -1.05), control2: pt(1.05, -0.95))
        p.addCurve(to: pt(0, 0.9), control1: pt(1.05, 0.15), control2: pt(0.2, 0.7))
        p.closeSubpath()
        return p
    }

    static func star(center c: CGPoint, radius r: CGFloat, points n: Int = 5, inner: CGFloat = 0.48, rotation: CGFloat = 0) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<(n * 2) {
            let a = rotation - .pi / 2 + CGFloat(i) * .pi / CGFloat(n)
            let rr = i % 2 == 0 ? r : r * inner
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    static func twinkle(center c: CGPoint, radius r: CGFloat) -> CGPath {
        let k = r * 0.22
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

// MARK: - PaintRegions

struct PixelBox: Equatable {
    var minX: Int, minY: Int, maxX: Int, maxY: Int
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
}

/// The closed areas of a page, found once from its line art.
/// `labels[i]` is the area of pixel i (1...count), or -1 for a line pixel.
struct PaintRegions {
    let width: Int, height: Int
    let labels: [Int32]
    let boxes: [PixelBox]   // index = label; boxes[0] unused

    var count: Int { boxes.count - 1 }

    /// A pixel is line when the line art over it is more than ~57% opaque.
    static let lineThreshold: UInt8 = 145

    /// `lineAlpha` is the line art's coverage per pixel (0 = paper, 255 = ink), row 0 at the top.
    init(lineAlpha: [UInt8], width w: Int, height h: Int) {
        width = w; height = h
        let n = w * h
        var lab = [Int32](repeating: 0, count: n)
        var boxes = [PixelBox(minX: 0, minY: 0, maxX: 0, maxY: 0)]
        lineAlpha.withUnsafeBufferPointer { a in
            lab.withUnsafeMutableBufferPointer { L in
                for i in 0..<n where a[i] >= PaintRegions.lineThreshold { L[i] = -1 }
                var stack = [Int]()
                stack.reserveCapacity(1 << 16)
                var next: Int32 = 1
                for start in 0..<n where L[start] == 0 {
                    var box = PixelBox(minX: start % w, minY: start / w, maxX: start % w, maxY: start / w)
                    L[start] = next
                    stack.append(start)
                    while let i = stack.popLast() {
                        let x = i % w, y = i / w
                        if x < box.minX { box.minX = x }
                        if x > box.maxX { box.maxX = x }
                        if y < box.minY { box.minY = y }
                        if y > box.maxY { box.maxY = y }
                        if x > 0, L[i - 1] == 0 { L[i - 1] = next; stack.append(i - 1) }
                        if x < w - 1, L[i + 1] == 0 { L[i + 1] = next; stack.append(i + 1) }
                        if y > 0, L[i - w] == 0 { L[i - w] = next; stack.append(i - w) }
                        if y < h - 1, L[i + w] == 0 { L[i + w] = next; stack.append(i + w) }
                    }
                    boxes.append(box)
                    next += 1
                }
            }
        }
        labels = lab
        self.boxes = boxes
    }

    func label(_ x: Int, _ y: Int) -> Int32 {
        guard x >= 0, y >= 0, x < width, y < height else { return -1 }
        return labels[y * width + x]
    }

    /// The area under (x, y), or the nearest one when she taps right on a line.
    func region(near x: Int, _ y: Int, radius: Int = 14) -> Int32? {
        let l = label(x, y)
        if l > 0 { return l }
        for r in 1...radius {
            for (dx, dy) in [(r, 0), (-r, 0), (0, r), (0, -r), (r, r), (-r, -r), (r, -r), (-r, r)] {
                let v = label(x + dx, y + dy)
                if v > 0 { return v }
            }
        }
        return nil
    }
}

/// One area's pixels as a mask over its bounding box, grown 2 px into the lines around it so
/// no paper shows between the color and the ink.
struct PaintRegionMask {
    let box: PixelBox
    let bits: [UInt8]   // 255 = inside, row-major over box
    let image: CGImage?

    init(regions R: PaintRegions, label: Int32) {
        let b0 = R.boxes[Int(label)]
        let pad = 3
        let box = PixelBox(minX: max(0, b0.minX - pad), minY: max(0, b0.minY - pad),
                      maxX: min(R.width - 1, b0.maxX + pad), maxY: min(R.height - 1, b0.maxY + pad))
        let bw = box.width, bh = box.height
        var m = [UInt8](repeating: 0, count: bw * bh)
        R.labels.withUnsafeBufferPointer { L in
            for y in 0..<bh {
                let row = (y + box.minY) * R.width + box.minX
                for x in 0..<bw where L[row + x] == label { m[y * bw + x] = 255 }
            }
            for pass in 0..<2 {
                let mark: UInt8 = pass == 0 ? 254 : 253
                var grown = m
                for y in 0..<bh {
                    let row = (y + box.minY) * R.width + box.minX
                    for x in 0..<bw where m[y * bw + x] == 0 && L[row + x] == -1 {
                        let i = y * bw + x
                        if (x > 0 && m[i - 1] > mark) || (x < bw - 1 && m[i + 1] > mark)
                            || (y > 0 && m[i - bw] > mark) || (y < bh - 1 && m[i + bw] > mark) {
                            grown[i] = mark
                        }
                    }
                }
                m = grown
            }
        }
        for i in 0..<m.count where m[i] != 0 { m[i] = 255 }
        self.box = box
        self.bits = m
        self.image = PaintRegionMask.makeImage(m, bw, bh)
    }

    private static func makeImage(_ bits: [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bits) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

// MARK: - ColoringPaper

enum PaintBrush: String, CaseIterable, Codable {
    case marker, crayon, glitter, rainbow, stamps, eraser
}

/// The color layer under a page's line art: a 1600x1200 bitmap she paints on.
/// Coordinates are pixels with the origin at the top left. Use it from the main thread.
final class ColoringPaper {
    static let width = 1600, height = 1200
    let w = ColoringPaper.width, h = ColoringPaper.height
    let regions: PaintRegions
    private let ctx: CGContext
    private let px: UnsafeMutablePointer<UInt32>
    private var masks: [Int32: PaintRegionMask] = [:]
    private var maskOrder: [Int32] = []

    // stroke state
    private var brush: PaintBrush = .marker
    private var brushColor = PaintColor.white
    private var brushSize: CGFloat = 20
    private var clip: PaintRegionMask?
    private var last: CGPoint = .zero
    private var travelled: CGFloat = 0
    private var nextStamp: CGFloat = 0
    private var rng = PaintRandom(seed: 42)

    /// `lineArt` nil = a blank page (one big area).
    init(lineArt: CGImage?) {
        ctx = ColoringPaper.makeContext(width: ColoringPaper.width, height: ColoringPaper.height)!
        px = ctx.data!.bindMemory(to: UInt32.self, capacity: ColoringPaper.width * ColoringPaper.height)
        regions = PaintRegions(lineAlpha: ColoringPaper.coverage(of: lineArt, ColoringPaper.width, ColoringPaper.height), width: ColoringPaper.width, height: ColoringPaper.height)
        clear()
    }

    // MARK: Pixels

    static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
    }

    static func pixels(of ctx: CGContext) -> [UInt32] {
        let n = ctx.width * ctx.height
        let p = ctx.data!.bindMemory(to: UInt32.self, capacity: n)
        return Array(UnsafeBufferPointer(start: p, count: n))
    }

    /// How much ink covers each pixel when the line art is drawn at w x h (row 0 at the top).
    static func coverage(of image: CGImage?, _ w: Int, _ h: Int) -> [UInt8] {
        var gray = [UInt8](repeating: 255, count: w * h)
        guard let image else { return [UInt8](repeating: 0, count: w * h) }
        gray.withUnsafeMutableBytes { buf in
            guard let c = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            c.setFillColor(gray: 1, alpha: 1)
            c.fill(CGRect(x: 0, y: 0, width: w, height: h))
            c.interpolationQuality = .high
            c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return gray.map { 255 - $0 }
    }

    func makeImage() -> CGImage? { ctx.makeImage() }

    func clear() {
        let white = PaintColor.white.packed
        for i in 0..<(w * h) { px[i] = white }
    }

    func snapshot() -> Data { Data(bytes: px, count: w * h * 4) }

    func restore(_ data: Data) {
        guard data.count == w * h * 4 else { return }
        data.withUnsafeBytes { raw in
            if let base = raw.baseAddress { memcpy(px, base, w * h * 4) }
        }
    }

    /// Paints a saved color layer back onto the paper.
    func load(_ image: CGImage) {
        clear()
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
    }

    func pngData() -> Data? {
        guard let img = makeImage() else { return nil }
        return UIImage(cgImage: img).pngData()
    }

    func pixel(_ x: Int, _ y: Int) -> UInt32 { px[y * w + x] }

    private func mask(_ label: Int32) -> PaintRegionMask {
        if let m = masks[label] { return m }
        let m = PaintRegionMask(regions: regions, label: label)
        masks[label] = m
        maskOrder.append(label)
        if maskOrder.count > 12 { masks[maskOrder.removeFirst()] = nil }
        return m
    }

    // MARK: Fill

    /// Fills the area under `p` (top-left pixel coordinates). Returns false when there is
    /// nothing to fill there or the area already has exactly this color.
    @discardableResult
    func fill(at p: CGPoint, style: ColoringFill, color: PaintColor) -> Bool {
        guard let label = regions.region(near: Int(p.x), Int(p.y)) else { return false }
        let m = mask(label)
        let painter = FillPainter(style: style, base: color)
        let b = m.box, bw = b.width
        let cached = painter.line(for: b)
        if style == .solid {
            // Skip when every pixel already has this color (so undo isn't wasted).
            let c = color.packed
            var same = true
            for y in 0..<b.height where same {
                for x in 0..<bw where m.bits[y * bw + x] != 0 && px[(y + b.minY) * w + x + b.minX] != c { same = false; break }
            }
            if same { return false }
        }
        m.bits.withUnsafeBufferPointer { bits in
            for y in 0..<b.height {
                let row = (y + b.minY) * w + b.minX
                for x in 0..<bw where bits[y * bw + x] != 0 {
                    let X = x + b.minX, Y = y + b.minY
                    let c: UInt32
                    if let cached {
                        c = painter.style == .rainbow ? cached[X - b.minX] : cached[Y - b.minY]
                    } else {
                        c = painter.color(X, Y, b)
                    }
                    px[row + x] = c
                }
            }
        }
        return true
    }

    // MARK: Brushes

    /// PaintBrush widths in paper pixels for the three sizes.
    static let sizes: [CGFloat] = [12, 26, 48]

    func beginStroke(at p: CGPoint, brush: PaintBrush, color: PaintColor, size: CGFloat, stayInLines: Bool) {
        self.brush = brush
        brushColor = brush == .eraser ? .white : color
        brushSize = size
        travelled = 0
        nextStamp = 0
        last = p
        clip = nil
        if stayInLines, let label = regions.region(near: Int(p.x), Int(p.y), radius: 6) {
            clip = mask(label)
        }
        segment(from: p, to: p)
    }

    func continueStroke(to p: CGPoint) {
        let d = hypot(p.x - last.x, p.y - last.y)
        guard d >= 1 else { return }
        segment(from: last, to: p)
        last = p
    }

    func endStroke() { clip = nil }

    /// Top-left pixel coordinates -> Core Graphics coordinates (origin bottom left).
    private func cg(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: CGFloat(h) - p.y) }

    private func segment(from a: CGPoint, to b: CGPoint) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        if let clip, let img = clip.image {
            let r = CGRect(x: clip.box.minX, y: h - clip.box.maxY - 1, width: clip.box.width, height: clip.box.height)
            ctx.clip(to: r, mask: img)
        }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let len = hypot(b.x - a.x, b.y - a.y)
        switch brush {
        case .marker, .eraser:
            line(a, b, brushColor.cg, brushSize)
        case .crayon:
            if let grain = ColoringPaper.grain {
                ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: h), mask: grain)
            }
            line(a, b, brushColor.cg, brushSize * 1.1)
        case .glitter:
            line(a, b, brushColor.cg, brushSize)
            let light = brushColor.mix(.white, 0.7).cg
            let n = max(1, Int(len * brushSize / 140))
            for _ in 0..<n {
                let t = CGFloat(rng.next())
                let ox = CGFloat(rng.next() - 0.5) * brushSize, oy = CGFloat(rng.next() - 0.5) * brushSize
                let c = cg(CGPoint(x: a.x + (b.x - a.x) * t + ox, y: a.y + (b.y - a.y) * t + oy))
                if rng.next() < 0.12 {
                    ctx.setFillColor(CGColor(gray: 1, alpha: 0.95))
                    ctx.addPath(PaintShapes.twinkle(center: c, radius: brushSize * CGFloat(0.18 + 0.12 * rng.next())))
                    ctx.fillPath()
                } else {
                    let r = CGFloat(1.2 + 2.2 * rng.next())
                    ctx.setFillColor(rng.next() < 0.5 ? light : CGColor(gray: 1, alpha: 0.9))
                    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                }
            }
        case .rainbow:
            // Short pieces so the hue changes smoothly along the line.
            let steps = max(1, Int(len / 4))
            var p0 = a
            for i in 1...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let p1 = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let hue = Double((travelled + len * t) / 500)
                line(p0, p1, PaintColor.hsb(hue, 0.62, 1).cg, brushSize)
                p0 = p1
            }
        case .stamps:
            let spacing = brushSize * 1.9
            var s = nextStamp
            while s <= travelled + len {
                let t = len > 0 ? (s - travelled) / len : 0
                let c = cg(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                let which = Int(s / spacing) % 3
                ctx.setFillColor(brushColor.cg)
                switch which {
                case 0: ctx.addPath(PaintShapes.heart(center: c, size: brushSize * 1.6, flipY: true))
                case 1: ctx.addPath(PaintShapes.star(center: c, radius: brushSize * 0.85, rotation: CGFloat(rng.next()) * 0.6 - 0.3))
                default: ctx.addPath(PaintShapes.twinkle(center: c, radius: brushSize * 0.8))
                }
                ctx.fillPath()
                s += spacing
            }
            nextStamp = s
        }
        travelled += len
    }

    private func line(_ a: CGPoint, _ b: CGPoint, _ color: CGColor, _ width: CGFloat) {
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.move(to: cg(a))
        ctx.addLine(to: cg(b))
        ctx.strokePath()
    }

    /// ColoringPaper grain for the crayon: white where wax sticks, black where it skips.
    static let grain: CGImage? = {
        let w = ColoringPaper.width, h = ColoringPaper.height
        var rng = PaintRandom(seed: 99)
        // Coarse noise (3x3 cells) mixed with fine noise looks like wax on paper.
        let cw = w / 3 + 1
        let coarse = (0..<(cw * (h / 3 + 1))).map { _ in rng.next() }
        var bits = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                let v = coarse[(y / 3) * cw + x / 3] * 0.6 + rng.next() * 0.4
                bits[y * w + x] = v > 0.3 ? 255 : 0
            }
        }
        guard let provider = CGDataProvider(data: Data(bits) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()
}
