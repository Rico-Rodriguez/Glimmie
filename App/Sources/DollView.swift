import SwiftUI
import UIKit

/// Loads the generated PNGs in App/Resources/Art and caches them.
enum Art {
    private static var cache: [String: UIImage] = [:]
    private static let lock = NSLock()

    static func ui(_ name: String) -> UIImage? {
        lock.lock(); let c = cache[name]; lock.unlock()
        if let c { return c }
        let path = Bundle.main.path(forResource: name, ofType: "png")
            ?? Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Art")
        guard let path, let img = UIImage(contentsOfFile: path) else { return nil }
        lock.lock(); cache[name] = img; lock.unlock()
        return img
    }

    static func exists(_ name: String) -> Bool { ui(name) != nil }

    static func image(_ name: String) -> Image {
        if let u = ui(name) { return Image(uiImage: u) }
        return Image(systemName: "questionmark.square.dashed")
    }

    // MARK: Cropped layers (layers.json, written by tools/process_art.py)

    private struct Layout: Decodable { let canvas: [CGFloat]; let rects: [String: [CGFloat]] }
    private static let layout: Layout? = {
        let path = Bundle.main.path(forResource: "layers", ofType: "json")
            ?? Bundle.main.path(forResource: "layers", ofType: "json", inDirectory: "Art")
        guard let path, let d = FileManager.default.contents(atPath: path) else { return nil }
        return try? JSONDecoder().decode(Layout.self, from: d)
    }()

    /// Size of the full canvas every avatar layer was rendered on.
    static var canvas: CGSize {
        guard let c = layout?.canvas, c.count == 2 else { return CGSize(width: 800, height: 1000) }
        return CGSize(width: c[0], height: c[1])
    }

    /// Where a cropped image sits in the canvas; nil means it fills the whole canvas.
    static func rect(_ name: String) -> CGRect? {
        guard let r = layout?.rects[name], r.count == 4 else { return nil }
        return CGRect(x: r[0], y: r[1], width: r[2], height: r[3])
    }

    // MARK: Ramp tinting (docs/MODEL_UPGRADE.md 1.3)

    private static let tintCache = NSCache<NSString, UIImage>()

    /// The layer with its brightness mapped through the ramp: shadow x 0.62, shadow, base, light
    /// at 0, 0.45, 0.86 and 1. Cached per layer and ramp. nil if the image can't be read.
    static func tinted(_ name: String, _ ramp: Ramp) -> UIImage? {
        let key = "\(name)|\(ramp.shadow)|\(ramp.base)|\(ramp.light)" as NSString
        if let c = tintCache.object(forKey: key) { return c }
        guard let src = ui(name)?.cgImage else { return nil }
        let w = src.width, h = src.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        let lut = lookup(ramp)
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let a = Int(px[i + 3])
            if a == 0 { continue }
            // unpremultiply, then Rec. 709 luminance of the near-white render picks the tone
            let r = Int(px[i]) * 255 / a, g = Int(px[i + 1]) * 255 / a, b = Int(px[i + 2]) * 255 / a
            let l = min(255, (r * 54 + g * 183 + b * 19) >> 8) * 3
            px[i] = UInt8(Int(lut[l]) * a / 255)
            px[i + 1] = UInt8(Int(lut[l + 1]) * a / 255)
            px[i + 2] = UInt8(Int(lut[l + 2]) * a / 255)
        }
        guard let out = ctx.makeImage() else { return nil }
        let img = UIImage(cgImage: out, scale: 1, orientation: .up)
        tintCache.setObject(img, forKey: key)
        return img
    }

    private static func lookup(_ r: Ramp) -> [UInt8] {
        func c(_ hex: UInt32, _ k: Double = 1) -> [Double] {
            [Double((hex >> 16) & 0xFF) * k, Double((hex >> 8) & 0xFF) * k, Double(hex & 0xFF) * k]
        }
        let stops: [(Double, [Double])] = [(0, c(r.shadow, 0.62)), (0.45, c(r.shadow)), (0.86, c(r.base)), (1, c(r.light))]
        var lut = [UInt8](repeating: 0, count: 256 * 3)
        for v in 0..<256 {
            let t = Double(v) / 255
            var j = 0
            while j < stops.count - 2 && t > stops[j + 1].0 { j += 1 }
            let (t0, c0) = stops[j], (t1, c1) = stops[j + 1]
            let f = max(0, min(1, (t - t0) / (t1 - t0)))
            for k in 0..<3 { lut[v * 3 + k] = UInt8(max(0, min(255, (c0[k] + (c1[k] - c0[k]) * f).rounded()))) }
        }
        return lut
    }

    /// Warm the cache with what the doll is wearing now, so the first frame doesn't hitch.
    static func preload(_ names: [String] = []) {
        DispatchQueue.global(qos: .userInitiated).async {
            let base = ["skin", "under", "eyes", "eyeshine", "happy", "face", "glim_body", "glim_face"]
            for n in base + names {
                for prefix in ["L_", "G_", "S_"] { _ = ui(prefix + n) }
            }
        }
    }
}

/// How strongly the gloss pass is screened on, per palette group (docs/MODEL_UPGRADE.md 1.2).
enum Gloss {
    static let skin = 0.35, clothes = 0.6, hair = 0.9
}

private func color(_ hex: UInt32) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

/// One avatar layer. Layers are cropped (layers.json) and placed back into the shared canvas, so they
/// stack with no offsets. A ramp swatch tints the base pass and screens the gloss pass on top; a plain
/// swatch multiplies; `shadow` draws the item's contact shadow underneath first.
struct Layer: View {
    let name: String
    var swatch: Swatch? = nil
    var gloss: Double = 0
    var shadow = false

    var body: some View {
        GeometryReader { g in
            ZStack {
                if shadow, Art.exists("S_" + name) {
                    place(Art.image("S_" + name).renderingMode(.template).resizable().interpolation(.high)
                            .foregroundColor(color(0xB9788C)), "S_" + name, g.size)
                        .blendMode(.multiply)
                }
                place(base, "L_" + name, g.size)
                if gloss > 0, let r = swatch?.ramp, Art.exists("G_" + name) {
                    place(Art.image("G_" + name).resizable().interpolation(.high)
                            .colorMultiply(glossTone(r)), "G_" + name, g.size)
                        .blendMode(.screen).opacity(gloss)
                }
            }
        }
    }

    @ViewBuilder private var base: some View {
        if let s = swatch, let r = s.ramp, let img = Art.tinted("L_" + name, r) {
            Image(uiImage: img).resizable().interpolation(.high)
        } else if let s = swatch {
            Art.image("L_" + name).resizable().interpolation(.high).colorMultiply(s.color)
        } else {
            Art.image("L_" + name).resizable().interpolation(.high)
        }
    }

    /// The light tone mixed halfway to white: highlights read as light on the colour, not a white sticker.
    private func glossTone(_ r: Ramp) -> Color {
        func ch(_ s: UInt32) -> Double { (Double((r.light >> s) & 0xFF) / 255 + 1) / 2 }
        return Color(red: ch(16), green: ch(8), blue: ch(0))
    }

    private func place<V: View>(_ v: V, _ key: String, _ size: CGSize) -> some View {
        let c = Art.canvas
        let r = Art.rect(key) ?? CGRect(origin: .zero, size: c)
        let sx = size.width / c.width, sy = size.height / c.height
        return v.frame(width: r.width * sx, height: r.height * sy)
            .position(x: r.midX * sx, y: r.midY * sy)
    }
}

/// The player's avatar, built from stacked layers.
struct DollView: View {
    let avatar: Avatar
    let outfit: Outfit
    var happy = false
    var blinks = true

    @State private var blinking = false

    /// Held items hugged in front of the hand rather than gripped by a handle.
    static let notGripped: Set<String> = ["hold_teddy"]

    private func worn(_ c: Category) -> (String, Swatch?)? {
        guard let w = outfit[c], let it = Catalog.item(w.item) else { return nil }
        return (it.id, it.tintable ? Palette.clothes[min(max(w.color, 0), Palette.clothes.count - 1)] : nil)
    }

    private func item(_ c: Category, shadow: Bool = true) -> some View {
        Group {
            if let w = worn(c) { Layer(name: w.0, swatch: w.1, gloss: w.1 == nil ? 0 : Gloss.clothes, shadow: shadow) }
        }
    }

    var body: some View {
        let closed = happy || blinking
        ZStack {
            item(.wings, shadow: false)
            Layer(name: "skin", swatch: Palette.skin[min(max(avatar.skin, 0), Palette.skin.count - 1)], gloss: Gloss.skin)
            Layer(name: "under")
            if closed {
                Layer(name: "happy")
            } else {
                Layer(name: "eyes", swatch: Palette.eyes[min(max(avatar.eyes, 0), Palette.eyes.count - 1)])
                Layer(name: "eyeshine")
            }
            Layer(name: "face")
            item(.shoes)
            item(.dress)
            let hair = Catalog.hairStyles[min(max(avatar.hairStyle, 0), Catalog.hairStyles.count - 1)]
            Layer(name: hair, swatch: Palette.hair[min(max(avatar.hairColor, 0), Palette.hair.count - 1)],
                  gloss: Gloss.hair, shadow: true)
            item(.hat)
            item(.hold)
            if let w = outfit[.hold], !Self.notGripped.contains(w.item) {
                // the right hand's fingers closed round the held item's handle
                Layer(name: "handgrip", swatch: Palette.skin[min(max(avatar.skin, 0), Palette.skin.count - 1)], gloss: Gloss.skin)
            }
        }
        .compositingGroup()   // shadows multiply and gloss screens only onto the doll, never the background
        .aspectRatio(0.8, contentMode: .fit)
        .task(id: blinks) {
            guard blinks else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.2...5.0) * 1_000_000_000))
                blinking = true
                try? await Task.sleep(nanoseconds: 140_000_000)
                blinking = false
                if Int.random(in: 0..<5) == 0 { // sometimes a double blink
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    blinking = true
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    blinking = false
                }
            }
        }
    }
}

/// A Glimmie pet: tintable body + untinted face.
struct GlimmieView: View {
    let kind: Int
    var silhouette = false
    var bob = true
    @State private var up = false

    var body: some View {
        ZStack {
            if silhouette {
                Art.image("L_glim_body").resizable().interpolation(.high)
                    .colorMultiply(Color(white: 0.55)).opacity(0.35)
                Text("?").font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundColor(.white).minimumScaleFactor(0.2)
            } else {
                Art.image("L_glim_body").resizable().interpolation(.high).colorMultiply(Glimmies.all[kind].color)
                Art.image("L_glim_face").resizable().interpolation(.high)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .offset(y: bob && up ? -8 : 4)
        .onAppear {
            guard bob, !silhouette else { return }
            withAnimation(.easeInOut(duration: Double.random(in: 1.4...1.9)).repeatForever(autoreverses: true)) { up = true }
        }
    }
}

/// A die-cut sticker: white border + item icon (tinted when the item is tintable).
struct StickerIcon: View {
    let name: String
    var tint: Color? = nil
    var body: some View {
        ZStack(alignment: .top) {
            Art.image("B_" + name).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            if let tint {
                Art.image("I_" + name).resizable().interpolation(.high).aspectRatio(contentMode: .fit).colorMultiply(tint)
            } else {
                Art.image("I_" + name).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            }
        }
        .aspectRatio(stickerAspect, contentMode: .fit)
    }
    private var stickerAspect: CGFloat {
        guard let u = Art.ui("B_" + name) else { return 1 }
        return u.size.width / max(1, u.size.height)
    }
}
