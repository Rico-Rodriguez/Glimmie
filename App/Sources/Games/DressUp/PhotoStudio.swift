import SwiftUI

// MARK: - Sticker and photo studio
//
// After the camera snaps (or from the gallery), she decorates the photo: tap a sticker to stick it
// on, drag it around, tap it to make it bigger, drag it into the bin (or off the photo) to peel it off,
// and pick a frame. Stickers and the frame are saved on the gallery look and show in the gallery and
// in the picture saved to Photos.

/// One sticker on a photo. Position is a fraction of the photo (0...1), size a fraction of its width.
struct PhotoSticker: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: String
    var x = 0.5
    var y = 0.5
    var size = 0.2
    var turn = 0.0

    init(kind: String, x: Double, y: Double, size: Double = 0.2, turn: Double = 0) {
        self.kind = kind; self.x = x; self.y = y; self.size = size; self.turn = turn
    }

    enum CodingKeys: String, CodingKey { case id, kind, x, y, size, turn }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? ""
        x = (try? c.decodeIfPresent(Double.self, forKey: .x)) ?? 0.5
        y = (try? c.decodeIfPresent(Double.self, forKey: .y)) ?? 0.5
        size = (try? c.decodeIfPresent(Double.self, forKey: .size)) ?? 0.2
        turn = (try? c.decodeIfPresent(Double.self, forKey: .turn)) ?? 0
    }

    static let sizes = [0.14, 0.2, 0.28, 0.36]
}

enum Stickers {
    /// SF Symbol stickers and their colors (nil: the symbol's own colors).
    static let symbols: [(name: String, color: UInt32?)] = [
        ("heart.fill", 0xF45C9A), ("star.fill", 0xFFC93C), ("sparkles", 0xFFB23E), ("crown.fill", 0xF2B83E),
        ("moon.stars.fill", 0x9B79E0), ("sun.max.fill", 0xFFA24C), ("cloud.fill", 0x9CCBFF), ("rainbow", nil),
        ("camera.macro", 0xFF6FA8), ("leaf.fill", 0x6CCB8B), ("snowflake", 0x7FB8F0), ("pawprint.fill", 0xC98A55),
        ("music.note", 0x46B7B0), ("gift.fill", 0xE8475A), ("birthday.cake.fill", 0xFF8FB8), ("ladybug.fill", 0xE8475A),
        ("teddybear.fill", 0xC98A55), ("fish.fill", 0xFFA24C), ("face.smiling.inverse", 0xFFC93C), ("drop.fill", 0x6FB6F0),
    ]
    /// Closet pieces that make good stickers.
    static let items = ["h_crown", "h_bigbow", "h_partyhat", "h_pointy", "g_heart", "g_sun", "n_heart", "w_butterfly"]
    /// Pets (plus "mypet": the pet with her, in its outfit).
    static let pets = ["kitty", "puppy", "bunny", "unicorn", "dragon", "panda", "axolotl", "penguin"]

    static func all(for look: Look) -> [String] {
        (look.pet == nil ? [] : ["mypet"]) + symbols.map(\.name) + items.map { "item:" + $0 } + pets.map { "pet:" + $0 }
    }

    static func isKnown(_ kind: String) -> Bool {
        if kind == "mypet" { return true }
        if kind.hasPrefix("item:") { return DressUpArt.shared.items[String(kind.dropFirst(5))] != nil }
        if kind.hasPrefix("pet:") { return PetArt.shared.animals[String(kind.dropFirst(4))] != nil }
        return symbols.contains { $0.name == kind }
    }

    static let frames = ["hearts", "stars", "flowers", "rainbow", "bubbles", "gold", "polaroid"]
}

/// A sticker, drawn to fill its frame.
struct StickerView: View {
    let kind: String
    let look: Look

    var body: some View {
        content
            .shadow(color: .white, radius: 0.6)
            .shadow(color: .white, radius: 1.4)
            .shadow(color: .white, radius: 2.2)
            .shadow(color: Theme.ink.opacity(0.25), radius: 3, y: 2)
    }

    @ViewBuilder private var content: some View {
        if kind == "mypet" {
            if let p = look.pet { PetThumb(pet: p) }
        } else if kind.hasPrefix("item:") {
            ItemThumb(item: String(kind.dropFirst(5)), look: Look.starter)
        } else if kind.hasPrefix("pet:") {
            PetThumb(pet: PetLook(kind: String(kind.dropFirst(4))))
        } else if let s = Stickers.symbols.first(where: { $0.name == kind }) {
            if let c = s.color {
                Image(systemName: s.name).resizable().scaledToFit().foregroundStyle(Color(hex: c))
            } else {
                Image(systemName: s.name).resizable().scaledToFit().symbolRenderingMode(.multicolor)
            }
        }
    }
}

/// A decorative frame around the photo.
struct PhotoFrameView: View {
    let frame: String

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let t = w * 0.045
            ZStack {
                switch frame {
                case "polaroid":
                    Path { p in
                        p.addRect(CGRect(x: 0, y: 0, width: w, height: h))
                        p.addRect(CGRect(x: t, y: t, width: w - 2 * t, height: h - t * 2.6))
                    }
                    .fill(Color(hex: 0xFFFDF8), style: FillStyle(eoFill: true))
                    Image(systemName: "heart.fill").resizable().scaledToFit()
                        .foregroundStyle(Color(hex: 0xF45C9A))
                        .frame(width: t * 1.0, height: t * 1.0)
                        .position(x: w / 2, y: h - t * 0.8)
                case "rainbow":
                    border(w, h, t, AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF6F91), Color(hex: 0xFFA24C), Color(hex: 0xFFE27A),
                                                                          Color(hex: 0x6CCB8B), Color(hex: 0x6FB6F0), Color(hex: 0x9B79E0)],
                                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                    dots(w, h, t, n: 4, symbol: "sparkles", colors: [0xFFFFFF], scale: 1.8, cornersOnly: true)
                case "gold":
                    border(w, h, t, AnyShapeStyle(Color(hex: 0xF2B83E)))
                    RoundedRectangle(cornerRadius: t * 0.6).stroke(Color(hex: 0xFFE9A8), lineWidth: t * 0.25)
                        .padding(t * 1.15)
                    Image(systemName: "crown.fill").resizable().scaledToFit()
                        .foregroundStyle(Color(hex: 0xF2B83E))
                        .shadow(color: .white, radius: 1.5)
                        .frame(width: t * 3, height: t * 3)
                        .position(x: w / 2, y: t * 0.9)
                default:
                    let style = Self.styles[frame] ?? Self.styles["hearts"]!
                    border(w, h, t, AnyShapeStyle(Color(hex: style.border)))
                    dots(w, h, t, n: 22, symbol: style.symbol, colors: style.colors, scale: 1.5, cornersOnly: false)
                }
            }
            .frame(width: w, height: h)
        }
        .allowsHitTesting(false)
    }

    private static let styles: [String: (border: UInt32, symbol: String, colors: [UInt32])] = [
        "hearts": (0xFFB3CF, "heart.fill", [0xF45C9A, 0xE8475A, 0xFFFFFF]),
        "stars": (0xC9B6FF, "star.fill", [0xFFC93C, 0xFFFFFF]),
        "flowers": (0x9FE3CF, "camera.macro", [0xFF6FA8, 0xFFC93C, 0xFFFFFF]),
        "bubbles": (0x9CCBFF, "circle.fill", [0xFFFFFF, 0xDDEEFF]),
    ]

    private func border(_ w: CGFloat, _ h: CGFloat, _ t: CGFloat, _ style: AnyShapeStyle) -> some View {
        Path { p in
            p.addRect(CGRect(x: 0, y: 0, width: w, height: h))
            p.addRoundedRect(in: CGRect(x: t, y: t, width: w - 2 * t, height: h - 2 * t), cornerSize: CGSize(width: t, height: t))
        }
        .fill(style, style: FillStyle(eoFill: true))
    }

    /// Little symbols spaced evenly along the middle of the border.
    private func dots(_ w: CGFloat, _ h: CGFloat, _ t: CGFloat, n: Int, symbol: String, colors: [UInt32], scale: CGFloat,
                      cornersOnly: Bool) -> some View {
        let pts: [CGPoint] = cornersOnly
            ? [CGPoint(x: t, y: t), CGPoint(x: w - t, y: t), CGPoint(x: t, y: h - t), CGPoint(x: w - t, y: h - t)]
            : Self.around(CGRect(x: t / 2, y: t / 2, width: w - t, height: h - t), n: n)
        return ForEach(pts.indices, id: \.self) { i in
            Image(systemName: symbol).resizable().scaledToFit()
                .foregroundStyle(Color(hex: colors[i % colors.count]))
                .frame(width: t * scale, height: t * scale)
                .rotationEffect(.degrees(Double((i * 37) % 30) - 15))
                .position(pts[i])
        }
    }

    /// `n` points evenly spaced around a rectangle's edge, starting at the top left.
    static func around(_ r: CGRect, n: Int) -> [CGPoint] {
        let per = 2 * (r.width + r.height)
        return (0..<n).map { i in
            var d = per * CGFloat(i) / CGFloat(n)
            if d < r.width { return CGPoint(x: r.minX + d, y: r.minY) }
            d -= r.width
            if d < r.height { return CGPoint(x: r.maxX, y: r.minY + d) }
            d -= r.height
            if d < r.width { return CGPoint(x: r.maxX - d, y: r.maxY) }
            d -= r.width
            return CGPoint(x: r.minX, y: r.maxY - d)
        }
    }
}

/// The photo itself: the scene with her standing in it (a 2:3 portrait).
struct PhotoBase: View {
    let look: Look
    static let aspect: CGFloat = 2.0 / 3.0

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let box = DressUpView.stageBox
            ZStack(alignment: .bottom) {
                SceneView(bg: look.bg)
                DollView(look: look, box: box)
                    .frame(width: w * 0.92, height: w * 0.92 * box.height / box.width)
                    .padding(.bottom, h * 0.04)
            }
            .frame(width: w, height: h)
        }
        .clipped()
    }
}

/// The finished photo with its stickers and frame (gallery and Photos).
struct PhotoView: View {
    let look: Look

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                PhotoBase(look: look)
                ForEach(look.stickers) { s in
                    StickerView(kind: s.kind, look: look)
                        .frame(width: w * s.size, height: w * s.size)
                        .rotationEffect(.degrees(s.turn))
                        .position(x: w * s.x, y: h * s.y)
                }
                if let f = look.frame { PhotoFrameView(frame: f) }
            }
            .frame(width: w, height: h)
        }
        .clipped()
    }
}

// MARK: - The studio

struct PhotoStudio: View {
    @State var look: Look
    var cancel: (() -> Void)? = nil
    let done: (Look) -> Void

    @State private var tab = 0
    @State private var moving: (id: UUID, x: Double, y: Double)?
    /// How far the moving sticker floats above her finger (glides up as she drags, see `FingerLift`).
    @State private var stickerLift = CGSize.zero
    @State private var overBin = false
    @State private var placementIndex = 0

    private static let photoHeight: CGFloat = 760
    private var photoSize: CGSize { CGSize(width: Self.photoHeight * PhotoBase.aspect, height: Self.photoHeight) }

    var body: some View {
        ZStack {
            Color(hex: 0xFFF1F6).ignoresSafeArea()
            DrawerBackground().opacity(0.6)
            DesignCanvas {
                HStack(spacing: 24) {
                    photo
                        .padding(.leading, 30)
                    panel
                        .padding(.vertical, 22)
                        .padding(.trailing, 22)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: The photo she decorates

    private var photo: some View {
        let size = photoSize
        return ZStack {
            PhotoBase(look: look)
            ForEach(look.stickers) { s in sticker(s, in: size) }
            if let f = look.frame { PhotoFrameView(frame: f) }
            if moving != nil {
                Image(systemName: overBin ? "trash.fill" : "trash")
                    .font(.system(size: overBin ? 40 : 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 86, height: 86)
                    .background(Circle().fill(overBin ? Color(hex: 0xE8475A) : Theme.ink.opacity(0.45)))
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .position(x: size.width - 62, y: size.height - 62)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white, lineWidth: 8))
        .shadow(color: Theme.ink.opacity(0.22), radius: 14, y: 8)
    }

    private func sticker(_ s: PhotoSticker, in size: CGSize) -> some View {
        StickerView(kind: s.kind, look: look)
            .frame(width: size.width * s.size, height: size.width * s.size)
            .rotationEffect(.degrees(s.turn))
            .scaleEffect(moving?.id == s.id ? 1.12 : 1)
            .contentShape(Rectangle())
            .onTapGesture { grow(s.id) }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        guard let i = index(s.id) else { return }
                        if moving?.id != s.id {
                            moving = (s.id, look.stickers[i].x, look.stickers[i].y)
                            // bring it to the front
                            let st = look.stickers.remove(at: i)
                            look.stickers.append(st)
                            stickerLift = .zero
                            Sound.shared.play(.tap, volume: 0.6)
                        }
                        guard let m = moving, let j = index(s.id) else { return }
                        // it floats up above her finger so she can see where it goes
                        let under = CGPoint(x: CGFloat(m.x) * size.width + v.translation.width,
                                            y: CGFloat(m.y) * size.height + v.translation.height)
                        let high = max(FingerLift.item, size.width * CGFloat(s.size) * 0.5 + 30)
                        stickerLift = FingerLift.ease(stickerLift, toward: FingerLift.offset(under, lift: high, top: 0, bottom: size.height, width: size.width))
                        look.stickers[j].x = Double((under.x + stickerLift.width) / size.width)
                        look.stickers[j].y = Double((under.y + stickerLift.height) / size.height)
                        let bin = inBin(look.stickers[j], size)
                        if bin != overBin { withAnimation(.spring(response: 0.25)) { overBin = bin } }
                    }
                    .onEnded { _ in drop(s.id, size) }
            )
            .position(x: size.width * s.x, y: size.height * s.y)
    }

    private func index(_ id: UUID) -> Int? { look.stickers.firstIndex { $0.id == id } }

    private func inBin(_ s: PhotoSticker, _ size: CGSize) -> Bool {
        let dx = s.x * size.width - (size.width - 62), dy = s.y * size.height - (size.height - 62)
        return dx * dx + dy * dy < 70 * 70
    }

    private func drop(_ id: UUID, _ size: CGSize) {
        defer { withAnimation(.spring(response: 0.3)) { moving = nil; overBin = false } }
        guard let i = index(id) else { return }
        let s = look.stickers[i]
        let off = s.x < -0.02 || s.x > 1.02 || s.y < -0.02 || s.y > 1.02
        if inBin(s, size) || off {
            Sound.shared.play(.whoosh, volume: 0.7)
            _ = withAnimation(.spring(response: 0.3)) { look.stickers.remove(at: i) }
        } else {
            Sound.shared.play(.pop, volume: 0.6)
        }
    }

    private func grow(_ id: UUID) {
        guard let i = index(id) else { return }
        Sound.shared.play(.boing, volume: 0.6)
        Sound.shared.tap()
        let sizes = PhotoSticker.sizes
        let k = sizes.firstIndex { $0 > look.stickers[i].size + 0.001 } ?? 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            look.stickers[i].size = sizes[k]
        }
    }

    private func add(_ kind: String) {
        Sound.shared.play(.sparkle, volume: 0.7)
        Sound.shared.tap()
        let n = placementIndex
        placementIndex += 1
        let angle = Double(n) * 2.39996
        let radius = min(0.24, 0.055 * sqrt(Double(n)))
        let x = max(0.18, min(0.82, 0.5 + cos(angle) * radius))
        let y = max(0.18, min(0.72, 0.44 + sin(angle) * radius * 0.85))
        let turn = Double((n % 5) - 2) * 4.5
        let s = PhotoSticker(kind: kind, x: x, y: y,
                             size: kind.hasPrefix("pet:") || kind == "mypet" ? 0.28 : 0.2, turn: turn)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            look.stickers.append(s)
            if look.stickers.count > Look.maxStickers { look.stickers.removeFirst(look.stickers.count - Look.maxStickers) }
        }
    }

    // MARK: Stickers and frames

    private var panel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                tabButton(0, symbol: "star.fill", tint: Color(hex: 0xFFC93C))
                tabButton(1, symbol: "photo.artframe", tint: Color(hex: 0x9B79E0))
                Spacer()
                if let cancel {
                    RoundButton(symbol: "xmark", tint: Theme.pink, size: 60) {
                        Sound.shared.play(.whoosh, volume: 0.6)
                        cancel()
                    }
                }
                RoundButton(symbol: "checkmark", tint: Color(hex: 0x6CCB8B), size: 60) {
                    Sound.shared.play(.fanfare, volume: 0.7)
                    let saved = look.sanitized()
                    if !saved.stickers.isEmpty || saved.frame != nil {
                        DressUpFind.photoQueen.unlock()
                    }
                    done(saved)
                }
            }
            ScrollView(showsIndicators: false) {
                if tab == 0 { stickerGrid } else { frameGrid }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Theme.cream.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(Theme.blush, lineWidth: 4))
        .shadow(color: Theme.ink.opacity(0.18), radius: 16, y: 8)
    }

    private func tabButton(_ i: Int, symbol: String, tint: Color) -> some View {
        Button {
            Sound.shared.play(.tap)
            tab = i
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(tab == i ? .white : tint)
                .frame(width: 82, height: 64)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tab == i ? Theme.pink.opacity(0.9) : Theme.blush.opacity(0.7)))
        }
        .buttonStyle(Squish())
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    private var stickerGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Stickers.all(for: look), id: \.self) { kind in
                Button { add(kind) } label: {
                    StickerView(kind: kind, look: look)
                        .padding(12)
                        .frame(height: 90)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(hex: 0xFFF7FA)))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(hex: 0xF5DDE8), lineWidth: 3))
                }
                .buttonStyle(Squish())
            }
        }
        .padding(4)
    }

    private var frameGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            frameCell(nil)
            ForEach(Stickers.frames, id: \.self) { frameCell($0) }
        }
        .padding(4)
    }

    private func frameCell(_ f: String?) -> some View {
        let on = look.frame == f
        return Button {
            Sound.shared.play(f == nil ? .whoosh : .ding, volume: 0.7)
            withAnimation(.spring(response: 0.3)) { look.frame = f }
        } label: {
            ZStack {
                PhotoBase(look: look)
                if let f { PhotoFrameView(frame: f) } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.ink.opacity(0.4), radius: 3)
                }
            }
            .aspectRatio(PhotoBase.aspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(on ? Theme.pink : .white, lineWidth: on ? 6 : 3))
        }
        .buttonStyle(Squish())
    }
}
