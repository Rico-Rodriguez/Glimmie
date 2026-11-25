import SwiftUI
import UIKit

// MARK: - Hue

extension PaintColor {
    /// Where this color sits on the rainbow (0...1), or nil for whites, greys, blacks and browns-near-grey.
    var hue: Double? {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        guard mx > 0.2, d / mx > 0.25 else { return nil }
        var h: Double
        if mx == r { h = (g - b) / d } else if mx == g { h = 2 + (b - r) / d } else { h = 4 + (r - g) / d }
        h /= 6
        return h < 0 ? h + 1 : h
    }

    /// The bright color the hue slider gives for `h`.
    static func slider(_ h: Double) -> PaintColor { .hsb(h, 0.82, 1) }
}

/// A rainbow strip: touch or slide along it to pick any color of the rainbow.
struct ColoringHueSlider: View {
    @ObservedObject var studio: ColoringStudio
    @State private var lastTick = -1

    private static let stops: [Color] = stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
        let c = PaintColor.slider($0)
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let knobHue = studio.color.hue
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: Self.stops, startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(.white, lineWidth: 4))
                    .shadow(color: Theme.ink.opacity(0.18), radius: 3, y: 2)
                if let hh = knobHue {
                    let c = PaintColor.slider(hh)
                    Circle()
                        .fill(Color(.sRGB, red: c.r, green: c.g, blue: c.b))
                        .frame(width: h + 6, height: h + 6)
                        .overlay(Circle().stroke(.white, lineWidth: 5))
                        .overlay(Circle().stroke(Theme.ink, lineWidth: 2).padding(-2))
                        .offset(x: CGFloat(hh) * (w - h) - 3)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let hh = Double(max(0, min(1, (v.location.x - h / 2) / max(1, w - h))))
                studio.pickColor(.slider(hh))
                // A soft tick every so often as she slides, like a dial.
                let tick = Int(hh * 24)
                if tick != lastTick { lastTick = tick; Sound.shared.play(.tap, volume: 0.25) }
            })
        }
        .frame(height: 44)
    }
}

// MARK: - The paint palette

/// Wet paint on a palette. She drops blobs of color and swirls them with her finger; the paint smears
/// along with her finger and mixes like real pigment (blue and yellow make green, red and white make pink).
///
/// The palette is a grid of cells. Each cell holds how much wet paint is on it and the paint's pigment as
/// Kubelka-Munk K/S per channel (absorption over scattering). Paint mixes by averaging K/S weighted by
/// amount, which is how pigments mix, unlike averaging the colors (which mixes like light).
final class PaintWell: ObservableObject {
    static let cols = 72, rows = 48
    let cols = PaintWell.cols, rows = PaintWell.rows
    private(set) var amount: [Float]
    /// Pigment mass per cell: K/S times amount.
    private(set) var mass: [SIMD3<Float>]
    /// Bumped on every change so the palette redraws.
    @Published private(set) var version = 0

    init() {
        amount = [Float](repeating: 0, count: PaintWell.cols * PaintWell.rows)
        mass = [SIMD3<Float>](repeating: .zero, count: PaintWell.cols * PaintWell.rows)
    }

    var isEmpty: Bool { !amount.contains { $0 > 0.15 } }

    static func ks(_ c: PaintColor) -> SIMD3<Float> {
        func f(_ v: Double) -> Float { let r = Float(max(0.004, min(1, v))); return (1 - r) * (1 - r) / (2 * r) }
        return SIMD3(f(c.r), f(c.g), f(c.b))
    }

    static func color(ks k: SIMD3<Float>) -> PaintColor {
        func back(_ k: Float) -> Double { Double(max(0, min(1, 1 + k - (k * k + 2 * k).squareRoot()))) }
        return PaintColor(r: back(k.x), g: back(k.y), b: back(k.z))
    }

    /// A blob of `color` dropped with its middle at `p` (in cells).
    func drop(_ color: PaintColor, at p: CGPoint, radius: Float = 7) {
        let k = PaintWell.ks(color)
        let px = Float(p.x), py = Float(p.y)
        forCells(near: px, py, radius) { i, w in
            let add = min(1.6, amount[i] + w) - amount[i]
            guard add > 0 else { return }
            amount[i] += add
            mass[i] += k * add
        }
        version += 1
    }

    /// Her finger moved from `a` to `b` (in cells): the paint under it is dragged along and worked together.
    func smear(from a: CGPoint, to b: CGPoint, radius: Float = 6) {
        let dist = Float(hypot(b.x - a.x, b.y - a.y))
        let n = max(1, Int(dist.rounded(.up)))
        let dx = Float(b.x - a.x) / Float(n), dy = Float(b.y - a.y) / Float(n)
        for step in 1...n {
            let qx = Float(a.x) + dx * Float(step), qy = Float(a.y) + dy * Float(step)
            let oldA = amount, oldM = mass
            forCells(near: qx, qy, radius) { i, fall in
                let x = i % cols, y = i / cols
                let w = fall * 0.9
                // The paint that was just behind this spot slides into it.
                let (sa, sm) = sample(oldA, oldM, Float(x) + 0.5 - dx, Float(y) + 0.5 - dy)
                var na = oldA[i] + (sa - oldA[i]) * w
                var nm = oldM[i] + (sm - oldM[i]) * w
                // Worked paint blends with its neighbours.
                let l = y * cols + max(0, x - 1), r = y * cols + min(cols - 1, x + 1)
                let u = max(0, y - 1) * cols + x, d = min(rows - 1, y + 1) * cols + x
                let avgA = (oldA[l] + oldA[r] + oldA[u] + oldA[d]) / 4
                let avgM = (oldM[l] + oldM[r] + oldM[u] + oldM[d]) / 4
                na += (avgA - na) * 0.2 * w
                nm += (avgM - nm) * 0.2 * w
                amount[i] = na
                mass[i] = nm
            }
        }
        version += 1
    }

    /// The paint at `p` (in cells), or nil where the palette is clean.
    func color(at p: CGPoint) -> PaintColor? {
        let x = Int(p.x), y = Int(p.y)
        guard x >= 0, y >= 0, x < cols, y < rows else { return nil }
        // Look in a small circle, so a tap at the edge of a blob still picks it up.
        var a: Float = 0, m = SIMD3<Float>.zero
        forCells(near: Float(p.x), Float(p.y), 2.5) { i, w in a += amount[i] * w; m += mass[i] * w }
        guard a > 0.1, amount[y * cols + x] > 0.1 || a > 0.5 else { return nil }
        return PaintWell.color(ks: m / a)
    }

    func wipe() {
        for i in amount.indices { amount[i] = 0; mass[i] = .zero }
        version += 1
    }

    /// The palette as a small picture (one pixel per cell): paint over the white palette, thin paint see-through.
    func image() -> CGImage? {
        let n = cols * rows
        var px = [UInt32](repeating: 0, count: n)
        let paper = PaintColor.hex(0xFFFDF8)
        for i in 0..<n {
            let a = amount[i]
            guard a > 0.02 else { px[i] = paper.packed; continue }
            let c = PaintWell.color(ks: mass[i] / a)
            px[i] = paper.mix(c, Double(min(1, a * 1.5))).packed
        }
        return px.withUnsafeMutableBytes { buf -> CGImage? in
            guard let ctx = CGContext(data: buf.baseAddress, width: cols, height: rows, bitsPerComponent: 8, bytesPerRow: cols * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return nil }
            return ctx.makeImage()
        }
    }

    private func forCells(near px: Float, _ py: Float, _ radius: Float, _ body: (Int, Float) -> Void) {
        let x0 = max(0, Int(px - radius)), x1 = min(cols - 1, Int(px + radius) + 1)
        let y0 = max(0, Int(py - radius)), y1 = min(rows - 1, Int(py + radius) + 1)
        guard x0 <= x1, y0 <= y1 else { return }
        for y in y0...y1 {
            for x in x0...x1 {
                let ddx = Float(x) + 0.5 - px, ddy = Float(y) + 0.5 - py
                let d2 = (ddx * ddx + ddy * ddy) / (radius * radius)
                if d2 < 1 { body(y * cols + x, 1 - d2) }
            }
        }
    }

    private func sample(_ a: [Float], _ m: [SIMD3<Float>], _ x: Float, _ y: Float) -> (Float, SIMD3<Float>) {
        let fx = max(0, min(Float(cols) - 1.001, x - 0.5)), fy = max(0, min(Float(rows) - 1.001, y - 0.5))
        let x0 = Int(fx), y0 = Int(fy), tx = fx - Float(x0), ty = fy - Float(y0)
        let i00 = y0 * cols + x0, i10 = i00 + 1, i01 = i00 + cols, i11 = i01 + 1
        let w00 = (1 - tx) * (1 - ty), w10 = tx * (1 - ty), w01 = (1 - tx) * ty, w11 = tx * ty
        return (a[i00] * w00 + a[i10] * w10 + a[i01] * w01 + a[i11] * w11,
                m[i00] * w00 + m[i10] * w10 + m[i01] * w01 + m[i11] * w11)
    }
}

/// The paint palette, opened from the palette button: tap a color to drop a blob, swirl with a finger to
/// mix, tap the paint to pick it up, then the check mark colors with it.
struct ColoringMixer: View {
    @ObservedObject var studio: ColoringStudio
    @ObservedObject var well: PaintWell
    let close: () -> Void
    @State private var picked: PaintColor?
    @State private var last: CGPoint?
    @State private var travelled: CGFloat = 0
    @State private var dropCount = 0

    private let wellSize = CGSize(width: 432, height: 288)

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ColoringButton(icon: "xmark", tint: Theme.peach, size: 64) { close() }
                    Spacer()
                    Button {
                        well.wipe()
                        picked = nil
                        Sound.shared.play(.whoosh, volume: 0.6)
                    } label: {
                        SpongeWipeIcon()
                            .padding(8)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(Theme.sky))
                            .overlay(Circle().stroke(.white, lineWidth: 5))
                            .shadow(color: Theme.ink.opacity(0.25), radius: 6, y: 4)
                    }
                    .buttonStyle(Squish())
                    .accessibilityLabel("Wipe palette")
                    Spacer()
                    pickedDot
                    ColoringButton(icon: "checkmark", tint: Theme.mint, size: 64) {
                        if let c = picked {
                            studio.applyMixedColor(c)
                            Sound.shared.play(.sparkle, volume: 0.7)
                        }
                        close()
                    }
                    .opacity(picked == nil ? 0.5 : 1)
                }
                HStack(alignment: .top, spacing: 16) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(46), spacing: 6), count: 3), spacing: 6) {
                        ForEach(0..<ColoringPalette.colors.count, id: \.self) { i in
                            let c = ColoringPalette.colors[i]
                            Button { drop(c) } label: {
                                Circle()
                                    .fill(Color(.sRGB, red: c.r, green: c.g, blue: c.b))
                                    .frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(.white, lineWidth: 3))
                                    .shadow(color: Theme.ink.opacity(0.18), radius: 2, y: 1)
                            }
                            .buttonStyle(Squish())
                        }
                    }
                    .frame(width: 150)
                    palette
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 36).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 36).stroke(.white, lineWidth: 5))
        }
    }

    private var pickedDot: some View {
        let c = picked ?? .white
        return Circle()
            .fill(Color(.sRGB, red: c.r, green: c.g, blue: c.b))
            .frame(width: 64, height: 64)
            .overlay(Circle().stroke(.white, lineWidth: 5))
            .overlay {
                if picked == nil {
                    Image(systemName: "hand.point.up.left.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.ink.opacity(0.35))
                }
            }
            .shadow(color: Theme.ink.opacity(0.2), radius: 3, y: 2)
    }

    private var palette: some View {
        let k = CGFloat(well.cols) / wellSize.width
        return ZStack {
            if let img = well.image() {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .id(well.version)
            }
            // A soft wet shine across the paint.
            LinearGradient(colors: [.white.opacity(0.28), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                .allowsHitTesting(false)
            if well.isEmpty {
                MixerEmptyHintView()
            }
        }
        .frame(width: wellSize.width, height: wellSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color(hex: 0xE8C9A0), lineWidth: 8))
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                let p = CGPoint(x: v.location.x * k, y: v.location.y * k)
                if let l = last {
                    well.smear(from: l, to: p)
                    travelled += hypot(p.x - l.x, p.y - l.y)
                    if travelled > 14 { travelled = 0; Sound.shared.play(.bubble, volume: 0.25) }
                }
                last = p
            }
            .onEnded { v in
                let p = CGPoint(x: v.location.x * k, y: v.location.y * k)
                last = nil
                // Where her finger lifts, the brush picks up that paint.
                if let c = well.color(at: p) {
                    picked = c
                    Sound.shared.play(.pop, volume: 0.5)
                }
            })
    }

    private func drop(_ c: PaintColor) {
        // Blobs go round the palette so new colors land next to the others, ready to swirl in.
        let spots: [CGPoint] = [CGPoint(x: 26, y: 24), CGPoint(x: 46, y: 24), CGPoint(x: 36, y: 14), CGPoint(x: 36, y: 34),
                                CGPoint(x: 18, y: 14), CGPoint(x: 54, y: 34), CGPoint(x: 54, y: 14), CGPoint(x: 18, y: 34)]
        well.drop(c, at: spots[dropCount % spots.count])
        dropCount += 1
        if picked == nil { picked = c }
        Sound.shared.play(.bubble, volume: 0.6)
    }
}
