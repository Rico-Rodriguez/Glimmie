import SwiftUI
import UIKit

/// Loads the generated PNGs in App/Resources/Art and caches them.
enum Art {
    private static var cache: [String: UIImage] = [:]

    static func ui(_ name: String) -> UIImage? {
        if let c = cache[name] { return c }
        let path = Bundle.main.path(forResource: name, ofType: "png")
            ?? Bundle.main.path(forResource: name, ofType: "png", inDirectory: "Art")
        guard let path, let img = UIImage(contentsOfFile: path) else { return nil }
        cache[name] = img
        return img
    }

    static func image(_ name: String) -> Image {
        if let u = ui(name) { return Image(uiImage: u) }
        return Image(systemName: "questionmark.square.dashed")
    }

    /// Warm the cache so the first drag doesn't hitch.
    static func preload() {
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [String: UIImage] = [:]
            let names = ["skin", "under", "eyes", "eyeshine", "happy", "face", "glim_body", "glim_face"]
                + Catalog.hairStyles + Catalog.hairStyles.map { $0 + "_shine" } + Catalog.items.map(\.id)
                + GlimmieAccessories.all.map(\.id)
            for n in names {
                for prefix in ["L_", "I_", "B_"] {
                    let key = prefix + n
                    if let p = Bundle.main.path(forResource: key, ofType: "png"), let img = UIImage(contentsOfFile: p) {
                        loaded[key] = img.preparingForDisplay() ?? img
                    }
                }
            }
            DispatchQueue.main.async { for (k, v) in loaded where cache[k] == nil { cache[k] = v } }
        }
    }
}

/// One full-canvas layer (all layers share one camera, so they stack with no offsets).
struct Layer: View {
    let name: String
    var tint: Color? = nil
    var body: some View {
        let img = Art.image("L_" + name).resizable().interpolation(.high)
        if let tint { img.colorMultiply(tint) } else { img }
    }
}

/// The player's avatar, built from stacked layers.
struct DollView: View {
    let avatar: Avatar
    let outfit: Outfit
    var happy = false
    var blinks = true

    @State private var blinking = false

    private func worn(_ c: Category) -> (String, Color?)? {
        guard let w = outfit[c], let it = Catalog.item(w.item) else { return nil }
        return (it.id, it.tintable ? Palette.clothes[w.color].color : nil)
    }

    var body: some View {
        let closed = happy || blinking
        ZStack {
            if let w = worn(.wings) { Layer(name: w.0, tint: w.1) }
            Layer(name: "skin", tint: Palette.skin[avatar.skin].color)
            Layer(name: "under")
            if closed {
                Layer(name: "happy")
            } else {
                Layer(name: "eyes", tint: Palette.eyes[avatar.eyes].color)
                Layer(name: "eyeshine")
            }
            Layer(name: "face")
            if let w = worn(.shoes) { Layer(name: w.0, tint: w.1) }
            if let w = worn(.dress) { Layer(name: w.0, tint: w.1) }
            let hair = Catalog.hairStyles[min(max(avatar.hairStyle, 0), Catalog.hairStyles.count - 1)]
            Layer(name: hair, tint: Palette.hair[avatar.hairColor].color)
            Layer(name: hair + "_shine")
            if let w = worn(.hat) { Layer(name: w.0, tint: w.1) }
            if let w = worn(.hold) { Layer(name: w.0, tint: w.1) }
        }
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
